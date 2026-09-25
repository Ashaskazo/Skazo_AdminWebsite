import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:skazo_admin/models/payment_record.dart';
import 'package:skazo_admin/models/revenue_analytics_model.dart';
import 'package:skazo_admin/utils/city_resolver.dart';

/// Repository that fetches raw payment data across Firestore collections
/// and builds deduplicated, canonically classified PaymentRecords.
class RevenueRepository {
  final FirebaseFirestore _firestore;

  RevenueRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Fetches all candidate payment documents across all 4 source collections:
  /// 1. `users` (Provider subscription, Pay-per-lead, Tenant pass)
  /// 2. `rental_properties` (Property listing / premium)
  /// 3. `agents` (Agent verification)
  /// 4. `local_promotions` (Local ads)
  ///
  /// Normalizes them into [PaymentRecord] objects with strict deduplication
  /// and explicit data quality/confidence flags.
  Future<List<PaymentRecord>> fetchAllPaymentRecords({
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    final pincodeLookup = buildPincodeCityLookup(pincodesMap);
    final List<PaymentRecord> records = [];
    final Set<String> seenTransactionIds = {};

    // 1. Fetch from 'users' collection (Providers, Pay-per-lead, Tenant passes)
    try {
      final usersSnap = await _firestore.collection('users').get();
      for (final doc in usersSnap.docs) {
        final data = doc.data();
        final uid = doc.id;

        // Resolve City & Confidence
        final cityResult = _resolveUserCity(data, pincodesMap, pincodeLookup);

        // Resolve Category & Confidence
        final categoryResult = _resolveUserCategory(data);

        // A. Stream 1: Provider Subscription / Verification
        final totalAmount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final txnId = data['transactionId']?.toString().trim() ?? '';
        final paymentCount = (data['paymentCount'] as num?)?.toInt() ?? 0;
        final paymentDate = _parseDate(data['paymentDate'] ?? data['paymentPaidAt'] ?? data['lastPaymentAt']);
        final paymentLinkSend = data['paymentLinkSend'] == true || data['paymentLinkSend'] == 'true';
        final isProvider = data['isuser'] == false || (data['businessname'] != null && data['businessname'].toString().trim().isNotEmpty);

        if (isProvider && (totalAmount > 0 || txnId.isNotEmpty || paymentCount > 0 || paymentLinkSend)) {
          final isPaid = totalAmount > 0 || txnId.isNotEmpty || paymentCount > 0;
          final recordTxnId = txnId.isNotEmpty ? txnId : 'SUB_${uid.substring(0, uid.length > 8 ? 8 : uid.length)}';

          // Prevent duplicate counting of same transaction ID
          if (!seenTransactionIds.contains(recordTxnId) || txnId.isEmpty) {
            if (txnId.isNotEmpty) seenTransactionIds.add(recordTxnId);

            records.add(PaymentRecord(
              id: 'users_sub_$uid',
              transactionId: recordTxnId,
              razorpayPaymentId: txnId.isNotEmpty ? txnId : null,
              stream: PaymentStream.providerSubscription,
              amount: totalAmount > 0 ? totalAmount : 0.0,
              collectedAmount: isPaid ? totalAmount : 0.0,
              outstandingAmount: 0.0,
              paymentDate: paymentDate,
              status: isPaid ? PaymentStatus.collected : PaymentStatus.paymentAttempt,
              reconciliationStatus: isPaid ? ReconciliationStatus.razorpayNotConnected : ReconciliationStatus.unmapped,
              userId: uid,
              userName: data['businessname'] ?? data['name'] ?? data['firstname'] ?? 'Provider ($uid)',
              userPhone: data['phone'],
              city: cityResult.city,
              cityKey: cityResult.cityKey,
              cityConfidence: cityResult.confidence,
              category: categoryResult.category,
              categoryConfidence: categoryResult.confidence,
              sourceCollection: 'users',
              sourceDocumentId: uid,
              dataScope: DataScope.latestOnly,
              notes: 'Latest provider checkout state (users.totalAmount). Historical multi-payment transactions reside in Google Sheets.',
              metadata: {
                'plan': data['AtivePlan'] ?? data['ActivePlan'],
                'planDuration': data['paymentPlanDuration'],
                'paymentCount': paymentCount,
                'senderId': data['paymentLinkSenderId'],
                'senderName': data['paymentLinkSenderName'],
                'overaltotalamount': data['overaltotalamount'],
              },
            ));
          }
        }

        // B. Stream 2: Pay-per-Lead (Outstanding Accumulated Amount)
        // CRITICAL BUSINESS RULE: payperLeadcharge is OUTSTANDING, NOT collected revenue!
        final payPerLeadCharge = (data['payperLeadcharge'] as num?)?.toDouble() ??
            (data['payperLeadCharge'] as num?)?.toDouble() ??
            (data['payPerLeadCharge'] as num?)?.toDouble() ??
            0.0;

        if (payPerLeadCharge > 0) {
          records.add(PaymentRecord(
            id: 'users_ppl_$uid',
            transactionId: 'PPL_OWED_$uid',
            stream: PaymentStream.payPerLeadOutstanding,
            amount: payPerLeadCharge,
            collectedAmount: 0.0, // STRICTLY ZERO COLLECTED
            outstandingAmount: payPerLeadCharge,
            paymentDate: _parseDate(data['lastpaymentpayperlead'] ?? data['updatedAt']),
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
            dataScope: DataScope.latestOnly,
            notes: 'Outstanding bill balance accumulated from converted leads. Not yet collected in checkout.',
            metadata: {
              'overallpayperleadamount': data['overallpayperleadamount'],
              'lastpayperleadtransactionid': data['lastpayperleadtransactionid'],
              'payPerLeadFeedback': data['payPerLeadFeedback'],
            },
          ));
        }

        // C. Stream 3: Tenant Property Contact Membership
        final userPropertyPaidVal = data['userPropertyPaid'];
        final tenantPaymentId = data['userPropertyPaymentId']?.toString().trim();
        final tenantPaidInt = (userPropertyPaidVal as num?)?.toInt() ?? 0;
        final tenantPaymentDate = _parseDate(data['userPropertyPaymentDate'] ?? data['userPropertyValidTill']);

        if (tenantPaidInt > 0 || (tenantPaymentId != null && tenantPaymentId.isNotEmpty)) {
          // Standard active implementation is ₹49, legacy is ₹29.
          // We check for recorded amount or flag legacy based on date or explicit field.
          final recordedTenantAmount = (data['userPropertyAmount'] as num?)?.toDouble();
          final isLegacy29 = (recordedTenantAmount == 29.0) ||
              (data['userPropertyPlan']?.toString().contains('29') ?? false) ||
              (tenantPaymentDate != null && tenantPaymentDate.isBefore(DateTime(2024, 6, 1)));
          final tenantAmount = recordedTenantAmount ?? (isLegacy29 ? 29.0 : 49.0);

          final tenantTxnId = (tenantPaymentId != null && tenantPaymentId.isNotEmpty)
              ? tenantPaymentId
              : 'TENANT_${uid.substring(0, uid.length > 8 ? 8 : uid.length)}';

          if (!seenTransactionIds.contains(tenantTxnId)) {
            if (tenantPaymentId != null && tenantPaymentId.isNotEmpty) {
              seenTransactionIds.add(tenantTxnId);
            }

            records.add(PaymentRecord(
              id: 'users_tenant_$uid',
              transactionId: tenantTxnId,
              razorpayPaymentId: tenantPaymentId,
              stream: PaymentStream.tenantContact,
              amount: tenantAmount,
              collectedAmount: tenantAmount,
              outstandingAmount: 0.0,
              paymentDate: tenantPaymentDate,
              status: PaymentStatus.collected,
              reconciliationStatus: ReconciliationStatus.razorpayNotConnected,
              userId: uid,
              userName: data['name'] ?? data['firstname'] ?? 'Tenant User ($uid)',
              userPhone: data['phone'],
              city: cityResult.city,
              cityKey: cityResult.cityKey,
              cityConfidence: cityResult.confidence,
              category: 'Tenant Membership',
              categoryConfidence: DataConfidence.high,
              sourceCollection: 'users',
              sourceDocumentId: uid,
              dataScope: DataScope.latestOnly,
              notes: isLegacy29 ? 'Legacy Tenant Contact Pass (₹29 recorded)' : 'Active Tenant Contact Membership (₹49 standard)',
              metadata: {
                'userPropertyPaid': userPropertyPaidVal,
                'userPropertyValidTill': data['userPropertyValidTill'],
                'userPropertyPaymentId': tenantPaymentId,
              },
            ));
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching users for payments: $e');
    }

    // 2. Fetch from 'rental_properties' collection (Stream 4: Property Listing / Premium)
    try {
      final propertiesSnap = await _firestore.collection('rental_properties').get();
      for (final doc in propertiesSnap.docs) {
        final data = doc.data();
        final propId = doc.id;

        final ownerPlan = data['ownerPlan']?.toString().toLowerCase() ?? '';
        final txnId = data['transactionId']?.toString().trim() ?? '';
        final paymentDate = _parseDate(data['paymentDate'] ?? data['paymentPaidAt'] ?? data['createdAt']);
        final paymentPropertyLinkSend = data['paymentPropertyLinkSend'] == true || data['paymentPropertyLinkSend'] == 'true';

        final isPaidPlan = ownerPlan.contains('premium') ||
            ownerPlan == 'paid' ||
            ownerPlan == '599' ||
            data['isPremium'] == true ||
            data['isBoosted'] == true;

        if (txnId.isNotEmpty || isPaidPlan || paymentPropertyLinkSend) {
          // Check for recorded amount or fallback to standard listing fee of ₹599
          final recordedAmount = (data['amount'] as num?)?.toDouble() ??
              (data['paymentAmount'] as num?)?.toDouble() ??
              (data['listingFee'] as num?)?.toDouble() ??
              (ownerPlan.contains('599') ? 599.0 : null);
          final listingAmount = recordedAmount ?? 599.0;
          final isPaid = txnId.isNotEmpty || isPaidPlan;

          final recordTxnId = txnId.isNotEmpty ? txnId : 'PROP_${propId.substring(0, propId.length > 8 ? 8 : propId.length)}';

          if (!seenTransactionIds.contains(recordTxnId) || txnId.isEmpty) {
            if (txnId.isNotEmpty) seenTransactionIds.add(recordTxnId);

            final propCity = data['city']?.toString().trim() ?? data['City']?.toString().trim() ?? 'Unknown / Unmapped';
            final hasCity = propCity.isNotEmpty && propCity.toLowerCase() != 'unknown';

            records.add(PaymentRecord(
              id: 'prop_$propId',
              transactionId: recordTxnId,
              razorpayPaymentId: txnId.isNotEmpty ? txnId : null,
              stream: PaymentStream.propertyListing,
              amount: listingAmount,
              collectedAmount: isPaid ? listingAmount : 0.0,
              outstandingAmount: 0.0,
              paymentDate: paymentDate,
              status: isPaid ? PaymentStatus.collected : PaymentStatus.paymentAttempt,
              reconciliationStatus: isPaid ? ReconciliationStatus.razorpayNotConnected : ReconciliationStatus.unmapped,
              userId: data['ownerId']?.toString(),
              userName: data['ownerName']?.toString() ?? data['propertyName']?.toString() ?? 'Property ($propId)',
              userPhone: data['ownerPhone'] ?? data['phone'],
              city: hasCity ? propCity : 'Unknown / Unmapped',
              cityKey: hasCity ? propCity.toLowerCase() : null,
              cityConfidence: hasCity ? DataConfidence.high : DataConfidence.unknown,
              category: 'Rental Property Listing',
              categoryConfidence: DataConfidence.high,
              sourceCollection: 'rental_properties',
              sourceDocumentId: propId,
              dataScope: DataScope.latestOnly,
              notes: 'Property premium listing payment (SKAZO fee, not rental price).',
              metadata: {
                'ownerPlan': ownerPlan,
                'propertyName': data['propertyName'],
                'area': data['area'],
                'location': data['location'],
                'paymentCount': data['paymentCount'],
              },
            ));
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching rental properties for payments: $e');
    }

    // 3. Fetch from 'agents' collection (Stream 5: Agent Verification / Premium)
    try {
      final agentsSnap = await _firestore.collection('agents').get();
      for (final doc in agentsSnap.docs) {
        final data = doc.data();
        final agentId = doc.id;

        final txnId = data['transactionId']?.toString().trim() ?? '';
        final agentPlan = data['agentPlan']?.toString() ?? data['agentplan']?.toString() ?? '';
        final isApproved = data['isApproved'] == true || data['isApproved'] == 'true';
        final hasLink = data['agentPaymentLink'] != null && data['agentPaymentLink'].toString().isNotEmpty;

        if (txnId.isNotEmpty || agentPlan.isNotEmpty || isApproved || hasLink) {
          final isPaid = txnId.isNotEmpty || isApproved;
          // Standard agent verification fee in SKAZO architecture is ₹999
          final agentFee = (data['amount'] as num?)?.toDouble() ?? 999.0;
          final paymentDate = _parseDate(data['paymentDate'] ?? data['approvedAt'] ?? data['createdAt']);

          final recordTxnId = txnId.isNotEmpty ? txnId : 'AGENT_${agentId.substring(0, agentId.length > 8 ? 8 : agentId.length)}';

          if (!seenTransactionIds.contains(recordTxnId) || txnId.isEmpty) {
            if (txnId.isNotEmpty) seenTransactionIds.add(recordTxnId);

            final agentCity = data['city']?.toString().trim() ?? 'Unknown / Unmapped';
            final hasCity = agentCity.isNotEmpty && agentCity.toLowerCase() != 'unknown';

            records.add(PaymentRecord(
              id: 'agent_$agentId',
              transactionId: recordTxnId,
              razorpayPaymentId: txnId.isNotEmpty ? txnId : null,
              stream: PaymentStream.agentVerification,
              amount: agentFee,
              collectedAmount: isPaid ? agentFee : 0.0,
              outstandingAmount: 0.0,
              paymentDate: paymentDate,
              status: isPaid ? PaymentStatus.collected : PaymentStatus.paymentAttempt,
              reconciliationStatus: isPaid ? ReconciliationStatus.razorpayNotConnected : ReconciliationStatus.unmapped,
              userId: agentId,
              userName: data['name'] ?? data['agentName'] ?? 'Agent ($agentId)',
              userPhone: data['phone'],
              city: hasCity ? agentCity : 'Unknown / Unmapped',
              cityKey: hasCity ? agentCity.toLowerCase() : null,
              cityConfidence: hasCity ? DataConfidence.high : DataConfidence.unknown,
              category: 'Agent Verification',
              categoryConfidence: DataConfidence.high,
              sourceCollection: 'agents',
              sourceDocumentId: agentId,
              dataScope: DataScope.latestOnly,
              notes: 'Agent verification charge (₹999 standard SKAZO revenue). Commission earned is not SKAZO revenue.',
              metadata: {
                'agentPlan': agentPlan,
                'isApproved': isApproved,
              },
            ));
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching agents for payments: $e');
    }

    // 4. Fetch from 'local_promotions' collection (Stream 6: Local Promotions / Ads)
    try {
      final promoSnap = await _firestore.collection('local_promotions').get();
      for (final doc in promoSnap.docs) {
        final data = doc.data();
        final promoId = doc.id;

        final txnId = data['transactionId']?.toString().trim() ?? '';
        final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
        final paymentDate = _parseDate(data['paymentDate'] ?? data['createdAt']);
        final paymentInitiated = data['paymentInitiated'] == true || data['paymentInitiated'] == 'true';
        final paymentLinkSend = data['paymentLinkSend'] == true || data['paymentLinkSend'] == 'true';
        final activePlan = data['activePlan'];

        if (txnId.isNotEmpty || amount > 0 || paymentInitiated || paymentLinkSend || activePlan != null) {
          final isPaid = txnId.isNotEmpty || (amount > 0 && activePlan != null);
          final promoAmount = amount > 0 ? amount : 0.0;

          final recordTxnId = txnId.isNotEmpty ? txnId : 'PROMO_${promoId.substring(0, promoId.length > 8 ? 8 : promoId.length)}';

          if (!seenTransactionIds.contains(recordTxnId) || txnId.isEmpty) {
            if (txnId.isNotEmpty) seenTransactionIds.add(recordTxnId);

            final promoCity = data['city']?.toString().trim() ?? 'Unknown / Unmapped';
            final hasCity = promoCity.isNotEmpty && promoCity.toLowerCase() != 'unknown';

            records.add(PaymentRecord(
              id: 'promo_$promoId',
              transactionId: recordTxnId,
              razorpayPaymentId: txnId.isNotEmpty ? txnId : null,
              stream: PaymentStream.localPromotion,
              amount: promoAmount,
              collectedAmount: isPaid ? promoAmount : 0.0,
              outstandingAmount: 0.0,
              paymentDate: paymentDate,
              status: isPaid ? PaymentStatus.collected : PaymentStatus.paymentAttempt,
              reconciliationStatus: isPaid ? ReconciliationStatus.razorpayNotConnected : ReconciliationStatus.unmapped,
              userId: data['userId']?.toString() ?? promoId,
              userName: data['businessName'] ?? data['title'] ?? data['name'] ?? 'Local Promo ($promoId)',
              userPhone: data['phone'],
              city: hasCity ? promoCity : 'Unknown / Unmapped',
              cityKey: hasCity ? promoCity.toLowerCase() : null,
              cityConfidence: hasCity ? DataConfidence.high : DataConfidence.low,
              category: 'Local Promotions',
              categoryConfidence: DataConfidence.high,
              sourceCollection: 'local_promotions',
              sourceDocumentId: promoId,
              dataScope: DataScope.latestOnly,
              notes: 'Local business promotion ad payment.',
              metadata: {
                'activePlan': activePlan,
                'planExpiredDate': data['planExpiredDate'],
                'address': data['address'],
                'location': data['location'],
              },
            ));
          }
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error fetching local promotions for payments: $e');
    }

    // Sort all records by payment date descending (or latest first)
    records.sort((a, b) {
      final aDate = a.paymentDate ?? DateTime(2000);
      final bDate = b.paymentDate ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return records;
  }

  /// In-memory aggregation engine that computes all summary cards, stream breakdown,
  /// city breakdown, category breakdown, and reconciliation stats.
  RevenueAnalyticsData computeAnalytics(
    List<PaymentRecord> allRecords,
    RevenueFilter filter,
  ) {
    // 1. Filter records matching active filter
    final matchingRecords = allRecords.where((r) => filter.matches(r)).toList();

    // 2. Compute Summary Metrics
    double totalCollected = 0.0;
    double currentPeriodRevenue = 0.0;
    int successfulTransactions = 0;
    double outstandingPPL = 0.0;
    double providerRev = 0.0;
    double propRev = 0.0;
    double agentRev = 0.0;
    double promoRev = 0.0;
    double tenantRev = 0.0;
    int unpaidAttempts = 0;

    final streamMap = <PaymentStream, _StreamAccumulator>{};
    for (final s in PaymentStream.values) {
      if (s != PaymentStream.unknown && s != PaymentStream.payPerLeadCollected) {
        streamMap[s] = _StreamAccumulator(s);
      }
    }

    final cityMap = <String, _CityAccumulator>{};
    final categoryMap = <String, _CategoryAccumulator>{};

    for (final record in matchingRecords) {
      if (record.isCollected) {
        totalCollected += record.collectedAmount;
        currentPeriodRevenue += record.collectedAmount;
        successfulTransactions++;

        switch (record.stream) {
          case PaymentStream.providerSubscription:
            providerRev += record.collectedAmount;
            break;
          case PaymentStream.propertyListing:
            propRev += record.collectedAmount;
            break;
          case PaymentStream.agentVerification:
            agentRev += record.collectedAmount;
            break;
          case PaymentStream.localPromotion:
            promoRev += record.collectedAmount;
            break;
          case PaymentStream.tenantContact:
            tenantRev += record.collectedAmount;
            break;
          default:
            break;
        }
      } else if (record.isOutstanding) {
        if (record.stream == PaymentStream.payPerLeadOutstanding) {
          outstandingPPL += record.outstandingAmount;
        }
      } else if (record.isAttempt) {
        unpaidAttempts++;
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
    }

    // Convert Stream Breakdown
    final streamBreakdown = streamMap.values.map((s) {
      final pct = totalCollected > 0 ? (s.collectedRevenue / totalCollected) * 100.0 : 0.0;
      return StreamBreakdownItem(
        stream: s.stream,
        transactionCount: s.transactionCount,
        collectedRevenue: s.collectedRevenue,
        outstandingAmount: s.outstandingAmount,
        revenuePercentage: pct,
      );
    }).toList();

    // Convert City Breakdown (sorted by collected revenue descending)
    final cityBreakdown = cityMap.values.map((c) {
      final avg = c.transactionCount > 0 ? c.collectedRevenue / c.transactionCount : 0.0;
      return CityBreakdownItem(
        city: c.city,
        transactionCount: c.transactionCount,
        collectedRevenue: c.collectedRevenue,
        outstandingAmount: c.outstandingAmount,
        uniqueUsers: c.uniqueUserIds.length,
        averagePayment: avg,
      );
    }).toList()
      ..sort((a, b) => b.collectedRevenue.compareTo(a.collectedRevenue));

    // Convert Category Breakdown (sorted by collected revenue descending)
    final categoryBreakdown = categoryMap.values.map((cat) {
      return CategoryBreakdownItem(
        category: cat.category,
        transactionCount: cat.transactionCount,
        collectedRevenue: cat.collectedRevenue,
        outstandingAmount: cat.outstandingAmount,
        uniqueUsers: cat.uniqueUserIds.length,
      );
    }).toList()
      ..sort((a, b) => b.collectedRevenue.compareTo(a.collectedRevenue));

    // Reconciliation Summary
    final reconciliationSummary = ReconciliationSummary(
      firebaseTotal: totalCollected,
      razorpayTotal: 0.0, // Razorpay API not directly connected
      difference: totalCollected,
      matchedCount: 0,
      missingInFirebaseCount: 0,
      missingInRazorpayCount: successfulTransactions,
      amountMismatchCount: 0,
      dateMismatchCount: 0,
      unmappedCount: matchingRecords.where((r) => r.reconciliationStatus == ReconciliationStatus.unmapped).length,
      needsReviewCount: matchingRecords.where((r) => r.reconciliationStatus == ReconciliationStatus.needsReview).length,
      isRazorpayConnected: false,
    );

    final warnings = <String>[
      'Dedicated Firestore transactions collection does not exist in backend; data represents latest document state (dataScope: latest_only).',
      'Pay-per-lead (₹${outstandingPPL.toStringAsFixed(0)}) is outstanding uncollected debt and is strictly separated from collected revenue.',
      'Google Sheets revenue history is separate from Firebase and not connected via server API in this client.',
      'Razorpay direct API is not connected. All transactions are marked "Razorpay Not Connected" rather than claiming confirmation.',
    ];

    return RevenueAnalyticsData(
      totalCollectedRevenue: totalCollected,
      currentPeriodRevenue: currentPeriodRevenue,
      totalTransactions: successfulTransactions,
      outstandingPayPerLead: outstandingPPL,
      providerRevenue: providerRev,
      propertyRevenue: propRev,
      agentRevenue: agentRev,
      localPromotionRevenue: promoRev,
      tenantContactRevenue: tenantRev,
      paymentAttemptsCount: unpaidAttempts,
      streamBreakdown: streamBreakdown,
      cityBreakdown: cityBreakdown,
      categoryBreakdown: categoryBreakdown,
      reconciliationSummary: reconciliationSummary,
      allMatchingRecords: matchingRecords,
      dataWarnings: warnings,
      computedAt: DateTime.now(),
    );
  }

  // --- Helper resolution routines ---

  _CityResult _resolveUserCity(
    Map<String, dynamic> data,
    Map<String, List<String>> pincodesMap,
    Map<String, String> pincodeLookup,
  ) {
    // 1. Direct explicit city
    final directCity = data['city']?.toString().trim() ?? data['City']?.toString().trim();
    if (directCity != null && directCity.isNotEmpty && directCity.toLowerCase() != 'unknown') {
      return _CityResult(directCity, directCity.toLowerCase(), DataConfidence.high);
    }

    // 2. Pincode lookup match
    final userPin = extractUserPincode(data);
    if (userPin != null && pincodeLookup.containsKey(userPin)) {
      final resolvedCity = pincodeLookup[userPin]!;
      return _CityResult(resolvedCity, resolvedCity.toLowerCase(), DataConfidence.medium);
    }

    // 3. Fallback to business location or address string match
    final fullAddr = (data['businessaddress'] ?? data['address'] ?? data['businessLocation'] ?? '')
        .toString()
        .toLowerCase();
    for (final cityEntry in pincodesMap.keys) {
      if (fullAddr.contains(cityEntry.toLowerCase())) {
        return _CityResult(cityEntry, cityEntry.toLowerCase(), DataConfidence.low);
      }
    }

    return _CityResult('Unknown / Unmapped', null, DataConfidence.unknown);
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
    return _CategoryResult('Unmapped', DataConfidence.unknown);
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
  double collectedRevenue = 0.0;
  double outstandingAmount = 0.0;

  _StreamAccumulator(this.stream);

  void add(PaymentRecord r) {
    if (r.isCollected) {
      transactionCount++;
      collectedRevenue += r.collectedAmount;
    } else if (r.isOutstanding) {
      outstandingAmount += r.outstandingAmount;
    }
  }
}

class _CityAccumulator {
  final String city;
  int transactionCount = 0;
  double collectedRevenue = 0.0;
  double outstandingAmount = 0.0;
  final Set<String> uniqueUserIds = {};

  _CityAccumulator(this.city);

  void add(PaymentRecord r) {
    if (r.userId != null) uniqueUserIds.add(r.userId!);
    if (r.isCollected) {
      transactionCount++;
      collectedRevenue += r.collectedAmount;
    } else if (r.isOutstanding) {
      outstandingAmount += r.outstandingAmount;
    }
  }
}

class _CategoryAccumulator {
  final String category;
  int transactionCount = 0;
  double collectedRevenue = 0.0;
  double outstandingAmount = 0.0;
  final Set<String> uniqueUserIds = {};

  _CategoryAccumulator(this.category);

  void add(PaymentRecord r) {
    if (r.userId != null) uniqueUserIds.add(r.userId!);
    if (r.isCollected) {
      transactionCount++;
      collectedRevenue += r.collectedAmount;
    } else if (r.isOutstanding) {
      outstandingAmount += r.outstandingAmount;
    }
  }
}
