import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:skazo_admin/models/payment_record.dart';
import 'package:skazo_admin/models/revenue_analytics_model.dart';
import 'package:skazo_admin/services/plan_classification_service.dart';
import 'package:skazo_admin/utils/city_resolver.dart';

/// Repository that establishes `financial_transactions` as the immutable source of truth,
/// provides Razorpay synchronization, reconciliation, legacy data migration,
/// and deterministic CEO-level financial analytics.
class RevenueRepository {
  final FirebaseFirestore? _firestore;
  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;
  static const String _cloudFunctionsBaseUrl =
      'https://asia-south1-skazo-7e5c3.cloudfunctions.net';

  RevenueRepository({FirebaseFirestore? firestore})
      : _firestore = firestore;

  /// Fetches financial transaction records.
  /// Primary Source of Truth: `financial_transactions` collection.
  /// If empty, automatically pulls from legacy collections and surfaces migration actions.
  Future<List<PaymentRecord>> fetchAllPaymentRecords({
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    try {
      // 1. Check primary ledger: `financial_transactions`
      final ledgerSnap = await _db
          .collection('financial_transactions')
          .orderBy('createdAt', descending: true)
          .limit(2000)
          .get();

      if (ledgerSnap.docs.isNotEmpty) {
        final records = ledgerSnap.docs
            .map((doc) => PaymentRecord.fromFirestore(doc))
            .toList();

        // Sort by payment date descending (or createdAt fallback)
        records.sort((a, b) {
          final aDate = a.paymentDate ?? a.createdAt ?? DateTime(2000);
          final bDate = b.paymentDate ?? b.createdAt ?? DateTime(2000);
          return bDate.compareTo(aDate);
        });

        return records;
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error querying financial_transactions: $e');
    }

    // 2. Fallback to reading legacy Firestore collections if ledger not yet initialized
    return _fetchLegacyCandidatePaymentRecords(pincodesMap: pincodesMap);
  }

  /// Watch real-time sync and connection metadata from `financial_sync_metadata/razorpay_sync`
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchSyncMetadata() {
    return _db
        .collection('financial_sync_metadata')
        .doc('razorpay_sync')
        .snapshots();
  }

  /// Fetch list of refunds from `financial_refunds`
  Future<List<RefundRecord>> fetchRefunds() async {
    try {
      final snap = await _db
          .collection('financial_refunds')
          .orderBy('refundDate', descending: true)
          .limit(100)
          .get();
      return snap.docs.map((d) => RefundRecord.fromFirestore(d)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching refunds: $e');
      return [];
    }
  }

  /// Fetch list of settlements from `financial_settlements`
  Future<List<SettlementRecord>> fetchSettlements() async {
    try {
      final snap = await _db
          .collection('financial_settlements')
          .orderBy('settlementDate', descending: true)
          .limit(100)
          .get();
      return snap.docs.map((d) => SettlementRecord.fromFirestore(d)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching settlements: $e');
      return [];
    }
  }

  /// Fetch audit logs from `audit_logs`
  Future<List<AuditLogRecord>> fetchAuditLogs() async {
    try {
      final snap = await _db
          .collection('audit_logs')
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();
      return snap.docs.map((d) => AuditLogRecord.fromFirestore(d)).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching audit logs: $e');
      return [];
    }
  }

  /// Trigger Razorpay Synchronization via backend Cloud Function
  Future<Map<String, dynamic>> triggerRazorpaySync({bool fullSync = false}) async {
    try {
      final url = Uri.parse('$_cloudFunctionsBaseUrl/syncRazorpayPaymentsHttp');
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({
          'fullSync': fullSync,
          'actor': user?.email ?? 'admin_dashboard',
        }),
      ).timeout(const Duration(seconds: 45));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(res.body);
        return {
          'status': 'error',
          'errorCode': err['errorCode'],
          'message': err['message'] ?? err['error'] ?? 'Sync failed (HTTP ${res.statusCode})'
        };
      }
    } catch (e) {
      // Record failure timestamp and error without falsely claiming in_progress
      await _db.collection('financial_sync_metadata').doc('razorpay_sync').set({
        'lastAttemptedAt': FieldValue.serverTimestamp(),
        'requestedBy': 'admin_dashboard',
        'lastError': e.toString(),
      }, SetOptions(merge: true));

      return {
        'status': 'error',
        'message': 'Razorpay sync failed. Check backend configuration or function logs.',
      };
    }
  }

  /// Trigger Historical Legacy Data Migration to `financial_transactions`
  Future<Map<String, dynamic>> triggerLegacyMigration() async {
    try {
      final url = Uri.parse('$_cloudFunctionsBaseUrl/migrateLegacyPaymentsHttp');
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final headers = {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final res = await http.post(
        url,
        headers: headers,
        body: jsonEncode({'actor': user?.email ?? 'admin_dashboard'}),
      ).timeout(const Duration(seconds: 60));

      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final err = jsonDecode(res.body);
        return {'status': 'error', 'message': err['error'] ?? 'Migration failed'};
      }
    } catch (e) {
      return {'status': 'error', 'message': e.toString()};
    }
  }

  /// Check Razorpay API connection health
  Future<Map<String, dynamic>> checkRazorpayHealth() async {
    try {
      final url = Uri.parse('$_cloudFunctionsBaseUrl/checkRazorpayHealthHttp');
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();
      final headers = {
        if (token != null) 'Authorization': 'Bearer $token',
      };

      final res = await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      }
      return {'connected': false, 'status': 'error', 'message': 'HTTP ${res.statusCode}'};
    } catch (e) {
      return {'connected': false, 'status': 'config_required', 'message': e.toString()};
    }
  }

  /// In-memory deterministic aggregation engine that computes all CEO summary cards,
  /// stream breakdowns, city breakdowns, category breakdowns, and reconciliation stats.
  RevenueAnalyticsData computeAnalytics(
    List<PaymentRecord> allRecords,
    RevenueFilter filter, {
    Map<String, dynamic>? syncMetadata,
    List<RefundRecord> refunds = const [],
    List<SettlementRecord> settlements = const [],
  }) {
    // 1. Filter records matching active filter
    final matchingRecords = allRecords.where((r) => filter.matches(r)).toList();

    // 2. Compute Summary Metrics with integer paise arithmetic
    int totalCollectedPaise = 0;
    int currentPeriodPaise = 0;
    int totalRefundedPaise = 0;
    int outstandingPPLPaise = 0;
    int providerPaise = 0;
    int propPaise = 0;
    int agentPaise = 0;
    int promoPaise = 0;
    int tenantPaise = 0;
    int successfulTransactions = 0;
    int failedPayments = 0;
    int unpaidAttempts = 0;

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final yearStart = DateTime(now.year, 1, 1);

    int todayPaise = 0;
    int thisWeekPaise = 0;
    int thisMonthPaise = 0;
    int thisYearPaise = 0;

    final streamMap = <PaymentStream, _StreamAccumulator>{};
    for (final s in PaymentStream.values) {
      if (s != PaymentStream.unknown) {
        streamMap[s] = _StreamAccumulator(s);
      }
    }

    final cityMap = <String, _CityAccumulator>{};
    final categoryMap = <String, _CategoryAccumulator>{};

    int matchedCount = 0;
    int missingInFirebaseCount = 0;
    int missingInRazorpayCount = 0;
    int amountMismatchCount = 0;
    int dateMismatchCount = 0;
    int duplicateCount = 0;
    int unmappedCount = 0;
    int needsReviewCount = 0;

    for (final record in matchingRecords) {
      final pDate = record.paymentDate ?? record.capturedAt ?? record.createdAt;

      if (record.isCollected) {
        successfulTransactions++;
        totalCollectedPaise += record.collectedAmountPaise;
        currentPeriodPaise += record.collectedAmountPaise;
        totalRefundedPaise += record.refundedAmountPaise;

        if (pDate != null) {
          if (pDate.isAfter(todayStart) || pDate.isAtSameMomentAs(todayStart)) {
            todayPaise += record.collectedAmountPaise;
          }
          if (pDate.isAfter(weekStart) || pDate.isAtSameMomentAs(weekStart)) {
            thisWeekPaise += record.collectedAmountPaise;
          }
          if (pDate.isAfter(monthStart) || pDate.isAtSameMomentAs(monthStart)) {
            thisMonthPaise += record.collectedAmountPaise;
          }
          if (pDate.isAfter(yearStart) || pDate.isAtSameMomentAs(yearStart)) {
            thisYearPaise += record.collectedAmountPaise;
          }
        }

        switch (record.stream) {
          case PaymentStream.providerSubscription:
            providerPaise += record.collectedAmountPaise;
            break;
          case PaymentStream.propertyListing:
            propPaise += record.collectedAmountPaise;
            break;
          case PaymentStream.agentVerification:
            agentPaise += record.collectedAmountPaise;
            break;
          case PaymentStream.localPromotion:
            promoPaise += record.collectedAmountPaise;
            break;
          case PaymentStream.tenantContact:
            tenantPaise += record.collectedAmountPaise;
            break;
          default:
            break;
        }
      } else if (record.isOutstanding) {
        if (record.stream == PaymentStream.payPerLeadOutstanding) {
          outstandingPPLPaise += record.outstandingAmountPaise;
        }
      } else if (record.isAttempt) {
        unpaidAttempts++;
      } else if (record.isFailed) {
        failedPayments++;
      }

      // Stream accumulator
      final streamAcc = streamMap[record.stream];
      if (streamAcc != null) {
        streamAcc.add(record);
      }

      // City accumulator
      final cName = record.city.isNotEmpty ? record.city : 'Unknown / Unmapped';
      cityMap.putIfAbsent(cName, () => _CityAccumulator(cName)).add(record);

      // Category accumulator
      final catName = record.category.isNotEmpty ? record.category : 'Unmapped';
      categoryMap.putIfAbsent(catName, () => _CategoryAccumulator(catName)).add(record);

      // Reconciliation counters
      switch (record.reconciliationStatus) {
        case ReconciliationStatus.matched:
          matchedCount++;
          break;
        case ReconciliationStatus.missingInFirebase:
          missingInFirebaseCount++;
          break;
        case ReconciliationStatus.missingInRazorpay:
          missingInRazorpayCount++;
          break;
        case ReconciliationStatus.amountMismatch:
          amountMismatchCount++;
          break;
        case ReconciliationStatus.dateMismatch:
          dateMismatchCount++;
          break;
        case ReconciliationStatus.duplicate:
          duplicateCount++;
          break;
        case ReconciliationStatus.needsReview:
          needsReviewCount++;
          break;
        default:
          unmappedCount++;
          break;
      }
    }

    final double totalCollected = totalCollectedPaise / 100.0;
    final double totalRefunded = totalRefundedPaise / 100.0;
    final double netCollected = (totalCollectedPaise - totalRefundedPaise) / 100.0;
    final double outstandingPPL = outstandingPPLPaise / 100.0;

    final double todayRev = todayPaise / 100.0;
    final double weekRev = thisWeekPaise / 100.0;
    final double monthRev = thisMonthPaise / 100.0;
    final double yearRev = thisYearPaise / 100.0;

    final int totalTxns = successfulTransactions + failedPayments + unpaidAttempts;
    final double successRate = totalTxns > 0
        ? (successfulTransactions / (successfulTransactions + failedPayments > 0 ? successfulTransactions + failedPayments : 1)) * 100.0
        : 100.0;

    // Convert Stream Breakdown
    final streamBreakdown = streamMap.values.map((s) {
      final coll = s.collectedPaise / 100.0;
      final out = s.outstandingPaise / 100.0;
      final ref = s.refundedPaise / 100.0;
      final pct = totalCollected > 0 ? (coll / totalCollected) * 100.0 : 0.0;
      return StreamBreakdownItem(
        stream: s.stream,
        transactionCount: s.transactionCount,
        collectedRevenue: coll,
        outstandingAmount: out,
        refundedAmount: ref,
        netAmount: coll - ref,
        revenuePercentage: pct,
      );
    }).toList();

    // Convert City Breakdown (sorted by collected revenue descending)
    final cityBreakdown = cityMap.values.map((c) {
      final coll = c.collectedPaise / 100.0;
      final out = c.outstandingPaise / 100.0;
      final ref = c.refundedPaise / 100.0;
      final avg = c.transactionCount > 0 ? coll / c.transactionCount : 0.0;
      return CityBreakdownItem(
        city: c.city,
        transactionCount: c.transactionCount,
        collectedRevenue: coll,
        outstandingAmount: out,
        refundedAmount: ref,
        netAmount: coll - ref,
        uniqueUsers: c.uniqueUserIds.length,
        averagePayment: avg,
      );
    }).toList()..sort((a, b) => b.collectedRevenue.compareTo(a.collectedRevenue));

    // Convert Category Breakdown (sorted by collected revenue descending)
    final categoryBreakdown = categoryMap.values.map((cat) {
      final coll = cat.collectedPaise / 100.0;
      final out = cat.outstandingPaise / 100.0;
      final ref = cat.refundedPaise / 100.0;
      return CategoryBreakdownItem(
        category: cat.category,
        transactionCount: cat.transactionCount,
        collectedRevenue: coll,
        outstandingAmount: out,
        refundedAmount: ref,
        netAmount: coll - ref,
        uniqueUsers: cat.uniqueUserIds.length,
      );
    }).toList()..sort((a, b) => b.collectedRevenue.compareTo(a.collectedRevenue));

    // Live Sync & Connection Metadata
    final bool isConfigured = syncMetadata?['isConfigured'] == true;
    final String syncStatus = syncMetadata?['syncStatus']?.toString() ?? 'idle';
    final DateTime? lastSyncTime = syncMetadata?['lastSuccessfulRazorpaySyncAt'] is Timestamp
        ? (syncMetadata!['lastSuccessfulRazorpaySyncAt'] as Timestamp).toDate()
        : null;

    final reconciliationSummary = ReconciliationSummary(
      firebaseTotal: totalCollected,
      razorpayTotal: isConfigured ? totalCollected : 0.0,
      difference: isConfigured ? 0.0 : totalCollected,
      matchedCount: matchedCount,
      missingInFirebaseCount: missingInFirebaseCount,
      missingInRazorpayCount: missingInRazorpayCount,
      amountMismatchCount: amountMismatchCount,
      dateMismatchCount: dateMismatchCount,
      duplicateCount: duplicateCount,
      unmappedCount: unmappedCount,
      needsReviewCount: needsReviewCount,
      isRazorpayConnected: isConfigured && syncStatus == 'success',
      lastSyncTime: lastSyncTime,
    );

    final warnings = <String>[];
    if (!isConfigured) {
      warnings.add(
        'Razorpay configuration required: RAZORPAY_KEY_ID & RAZORPAY_KEY_SECRET must be configured in Cloud Functions environment to enable automatic gateway sync.',
      );
    }
    if (matchingRecords.any((r) => r.dataScope == DataScope.legacyHistorical)) {
      warnings.add(
        'Legacy records present: historical payment data migrated from source collections requires Razorpay sync for official gateway verification.',
      );
    }
    if (outstandingPPL > 0) {
      warnings.add(
        'Pay-per-lead (₹${outstandingPPL.toStringAsFixed(0)}) is outstanding uncollected debt and is strictly excluded from collected revenue.',
      );
    }
    if (needsReviewCount > 0) {
      warnings.add(
        '$needsReviewCount transactions have reconciliation discrepancies and require review.',
      );
    }

    return RevenueAnalyticsData(
      totalCollectedRevenue: totalCollected,
      currentPeriodRevenue: currentPeriodPaise / 100.0,
      todayRevenue: todayRev,
      thisWeekRevenue: weekRev,
      thisMonthRevenue: monthRev,
      thisYearRevenue: yearRev,
      totalTransactions: successfulTransactions,
      outstandingPayPerLead: outstandingPPL,
      totalRefunded: totalRefunded,
      netCollectedRevenue: netCollected,
      failedPaymentsCount: failedPayments,
      paymentSuccessRate: (successRate * 10).round() / 10.0,
      providerRevenue: providerPaise / 100.0,
      propertyRevenue: propPaise / 100.0,
      agentRevenue: agentPaise / 100.0,
      localPromotionRevenue: promoPaise / 100.0,
      tenantContactRevenue: tenantPaise / 100.0,
      paymentAttemptsCount: unpaidAttempts,
      streamBreakdown: streamBreakdown,
      cityBreakdown: cityBreakdown,
      categoryBreakdown: categoryBreakdown,
      reconciliationSummary: reconciliationSummary,
      allMatchingRecords: matchingRecords,
      refunds: refunds,
      settlements: settlements,
      dataWarnings: warnings,
      computedAt: DateTime.now(),
    );
  }

  // --- Fallback legacy collector ---
  Future<List<PaymentRecord>> _fetchLegacyCandidatePaymentRecords({
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    final pincodeLookup = buildPincodeCityLookup(pincodesMap);
    final List<PaymentRecord> records = [];
    final Set<String> seenTxnIds = {};

    try {
      final usersSnap = await _db.collection('users').get();
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final uid = doc.id;
        final cityResult = _resolveUserCity(data, pincodesMap, pincodeLookup);
        final categoryResult = _resolveUserCategory(data);

        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final txnId = data['transactionId']?.toString().trim() ?? '';
        final paymentDate = _parseDate(data['paymentDate'] ?? data['lastPaymentAt']);
        final isProvider = data['isuser'] == false ||
            (data['businessname'] != null && data['businessname'].toString().trim().isNotEmpty);

        if (isProvider && (totalAmount > 0 || txnId.isNotEmpty)) {
          final recordTxnId = txnId.isNotEmpty ? txnId : 'SUB_${uid.substring(0, uid.length > 8 ? 8 : uid.length)}';
          if (!seenTxnIds.contains(recordTxnId)) {
            if (txnId.isNotEmpty) seenTxnIds.add(recordTxnId);
            records.add(PaymentRecord(
              id: 'users_sub_$uid',
              transactionId: recordTxnId,
              razorpayPaymentId: txnId.isNotEmpty ? txnId : null,
              stream: PaymentStream.providerSubscription,
              amount: totalAmount,
              collectedAmount: totalAmount,
              outstandingAmount: 0.0,
              paymentDate: paymentDate,
              status: PaymentStatus.collected,
              reconciliationStatus: ReconciliationStatus.needsReview,
              userId: uid,
              userName: data['businessname'] ?? data['name'] ?? 'Provider ($uid)',
              userPhone: data['phone'],
              city: cityResult.city,
              cityKey: cityResult.cityKey,
              cityConfidence: cityResult.confidence,
              category: categoryResult.category,
              categoryConfidence: categoryResult.confidence,
              sourceCollection: 'users',
              sourceDocumentId: uid,
              dataScope: DataScope.legacyHistorical,
              notes: 'Legacy provider subscription state in users collection.',
            ));
          }
        }

        final pplCharge = (data['payperLeadcharge'] as num?)?.toDouble() ??
            (data['payperLeadCharge'] as num?)?.toDouble() ?? 0.0;
        final isUserFlag = data['isuser'] == true || data['isUser'] == true;
        if (!isUserFlag && pplCharge > 0 && PlanClassificationService.isPremium(data)) {
          records.add(PaymentRecord(
            id: 'users_ppl_$uid',
            transactionId: 'PPL_OWED_$uid',
            stream: PaymentStream.payPerLeadOutstanding,
            amount: pplCharge,
            collectedAmount: 0.0,
            outstandingAmount: pplCharge,
            paymentDate: _parseDate(data['updatedAt']),
            status: PaymentStatus.outstanding,
            reconciliationStatus: ReconciliationStatus.unmapped,
            userId: uid,
            userName: data['businessname'] ?? data['name'] ?? 'Provider ($uid)',
            userPhone: data['phone'],
            city: cityResult.city,
            cityKey: cityResult.cityKey,
            cityConfidence: cityResult.confidence,
            category: categoryResult.category,
            categoryConfidence: categoryResult.confidence,
            sourceCollection: 'users',
            sourceDocumentId: uid,
            dataScope: DataScope.legacyHistorical,
            notes: 'Outstanding PPL debt accumulated.',
          ));
        }

        final tenantPaid = (data['userPropertyPaid'] as num?)?.toInt() ?? 0;
        final tenantTxn = data['userPropertyPaymentId']?.toString().trim();
        if (tenantPaid > 0 || (tenantTxn != null && tenantTxn.isNotEmpty)) {
          final amt = (data['userPropertyAmount'] as num?)?.toDouble() ?? 49.0;
          final recTxn = tenantTxn?.isNotEmpty == true ? tenantTxn! : 'TENANT_${uid.substring(0, uid.length > 8 ? 8 : uid.length)}';
          if (!seenTxnIds.contains(recTxn)) {
            if (tenantTxn?.isNotEmpty == true) seenTxnIds.add(recTxn);
            records.add(PaymentRecord(
              id: 'users_tenant_$uid',
              transactionId: recTxn,
              razorpayPaymentId: tenantTxn,
              stream: PaymentStream.tenantContact,
              amount: amt,
              collectedAmount: amt,
              outstandingAmount: 0.0,
              paymentDate: _parseDate(data['userPropertyPaymentDate']),
              status: PaymentStatus.collected,
              reconciliationStatus: ReconciliationStatus.needsReview,
              userId: uid,
              userName: data['name'] ?? 'Tenant ($uid)',
              userPhone: data['phone'],
              city: cityResult.city,
              cityKey: cityResult.cityKey,
              cityConfidence: cityResult.confidence,
              category: 'Tenant Membership',
              categoryConfidence: DataConfidence.high,
              sourceCollection: 'users',
              sourceDocumentId: uid,
              dataScope: DataScope.legacyHistorical,
              notes: 'Tenant contact pass.',
            ));
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Legacy users fetch error: $e');
    }

    return records;
  }

  _CityResult _resolveUserCity(
    Map<String, dynamic> data,
    Map<String, List<String>> pincodesMap,
    Map<String, String> pincodeLookup,
  ) {
    final directCity = data['city']?.toString().trim() ?? data['City']?.toString().trim();
    if (directCity != null && directCity.isNotEmpty && directCity.toLowerCase() != 'unknown') {
      return _CityResult(directCity, directCity.toLowerCase(), DataConfidence.high);
    }
    final userPin = extractUserPincode(data);
    if (userPin != null && pincodeLookup.containsKey(userPin)) {
      final resolvedCity = pincodeLookup[userPin]!;
      return _CityResult(resolvedCity, resolvedCity.toLowerCase(), DataConfidence.medium);
    }
    final fullAddr = (data['businessaddress'] ?? data['address'] ?? '').toString().toLowerCase();
    for (final cityEntry in pincodesMap.keys) {
      if (fullAddr.contains(cityEntry.toLowerCase())) {
        return _CityResult(cityEntry, cityEntry.toLowerCase(), DataConfidence.low);
      }
    }
    return const _CityResult('Unknown / Unmapped', null, DataConfidence.unknown);
  }

  _CategoryResult _resolveUserCategory(Map<String, dynamic> data) {
    final rawCategory = data['category'];
    if (rawCategory is List && rawCategory.isNotEmpty) {
      final cleaned = rawCategory
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (cleaned.isNotEmpty) {
        return _CategoryResult(cleaned.join(', '), DataConfidence.high);
      }
    } else if (rawCategory is String && rawCategory.trim().isNotEmpty) {
      return _CategoryResult(rawCategory.trim(), DataConfidence.high);
    }
    return const _CategoryResult('Unmapped', DataConfidence.unknown);
  }

  DateTime? _parseDate(dynamic val) {
    if (val == null) return null;
    if (val is Timestamp) return val.toDate();
    if (val is DateTime) return val;
    if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    if (val is String) return DateTime.tryParse(val);
    return null;
  }
}

class _CityResult {
  final String city;
  final String? cityKey;
  final DataConfidence confidence;
  const _CityResult(this.city, this.cityKey, this.confidence);
}

class _CategoryResult {
  final String category;
  final DataConfidence confidence;
  const _CategoryResult(this.category, this.confidence);
}

class _StreamAccumulator {
  final PaymentStream stream;
  int transactionCount = 0;
  int collectedPaise = 0;
  int outstandingPaise = 0;
  int refundedPaise = 0;

  _StreamAccumulator(this.stream);

  void add(PaymentRecord r) {
    if (r.isCollected) {
      transactionCount++;
      collectedPaise += r.collectedAmountPaise;
      refundedPaise += r.refundedAmountPaise;
    } else if (r.isOutstanding) {
      outstandingPaise += r.outstandingAmountPaise;
    }
  }
}

class _CityAccumulator {
  final String city;
  int transactionCount = 0;
  int collectedPaise = 0;
  int outstandingPaise = 0;
  int refundedPaise = 0;
  final Set<String> uniqueUserIds = {};

  _CityAccumulator(this.city);

  void add(PaymentRecord r) {
    if (r.userId != null) uniqueUserIds.add(r.userId!);
    if (r.isCollected) {
      transactionCount++;
      collectedPaise += r.collectedAmountPaise;
      refundedPaise += r.refundedAmountPaise;
    } else if (r.isOutstanding) {
      outstandingPaise += r.outstandingAmountPaise;
    }
  }
}

class _CategoryAccumulator {
  final String category;
  int transactionCount = 0;
  int collectedPaise = 0;
  int outstandingPaise = 0;
  int refundedPaise = 0;
  final Set<String> uniqueUserIds = {};

  _CategoryAccumulator(this.category);

  void add(PaymentRecord r) {
    if (r.userId != null) uniqueUserIds.add(r.userId!);
    if (r.isCollected) {
      transactionCount++;
      collectedPaise += r.collectedAmountPaise;
      refundedPaise += r.refundedAmountPaise;
    } else if (r.isOutstanding) {
      outstandingPaise += r.outstandingAmountPaise;
    }
  }
}
