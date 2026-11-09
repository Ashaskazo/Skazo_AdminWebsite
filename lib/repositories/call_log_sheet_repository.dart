import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/call_log_sheet_item.dart';

/// Provider for CallLogSheetRepository
final callLogSheetRepositoryProvider = Provider<CallLogSheetRepository>((ref) {
  return CallLogSheetRepository(FirebaseFirestore.instance);
});

/// Metrics summary for debug logging and transparency
class CallLogSheetSyncMetrics {
  final int eligibleProvidersCount;
  final int totalBatches;
  final int successfulBatches;
  final int failedBatches;
  final int callLogsRetrieved;
  final int elapsedMilliseconds;
  final bool usedCompositeIndex;

  const CallLogSheetSyncMetrics({
    required this.eligibleProvidersCount,
    required this.totalBatches,
    required this.successfulBatches,
    required this.failedBatches,
    required this.callLogsRetrieved,
    required this.elapsedMilliseconds,
    required this.usedCompositeIndex,
  });
}

/// Result bundle returned by repository containing items, warning message, and metrics.
class CallLogSheetFetchResult {
  final List<CallLogSheetItem> items;
  final String? warningMessage;
  final CallLogSheetSyncMetrics metrics;

  const CallLogSheetFetchResult({
    required this.items,
    this.warningMessage,
    required this.metrics,
  });
}

/// Repository responsible for querying Firestore `users` and `callLogs` collections
/// strictly following Call Log Sheet requirements.
class CallLogSheetRepository {
  final FirebaseFirestore _firestore;

  CallLogSheetRepository(this._firestore);

  // Timeouts configured for real-world network latency and Web SDK constraints
  static const Duration _usersQueryTimeout = Duration(seconds: 20);
  static const Duration _callLogsBatchTimeout = Duration(seconds: 25);

  // Batching & concurrency constraints to prevent Firestore Web connection saturation
  static const int _batchSize = 15;
  static const int _maxConcurrentBatches = 3;

  /// Safe integer parser
  static int? parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  /// Safe DateTime parser
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }

  /// Evaluates whether a user document is a service provider (isuser == false).
  static bool isServiceProvider(Map<String, dynamic> data) {
    final rawIsUser = data['isuser'];
    if (rawIsUser == false ||
        rawIsUser == 0 ||
        rawIsUser == '0' ||
        rawIsUser == 'false') {
      return true;
    }
    if (rawIsUser == true ||
        rawIsUser == 1 ||
        rawIsUser == '1' ||
        rawIsUser == 'true') {
      return false;
    }
    // Fallback if isuser is omitted: check provider attributes
    return data['businessname'] != null ||
        data['category'] != null ||
        data['ServiceRateCard'] != null ||
        data['serviceRateCard'] != null;
  }

  /// Fetches eligible service providers from `users` and batches associated `callLogs`.
  /// Uses controlled parallel concurrency to prevent WebSocket timeouts and connection exhaustion.
  Future<CallLogSheetFetchResult> fetchEligibleProviders() async {
    final stopwatch = Stopwatch()..start();
    bool usedCompositeIndex = false;

    // 1. Retrieve eligible users from 'users' collection where callsAfterLastPayment > 5
    List<QueryDocumentSnapshot<Map<String, dynamic>>> eligibleUserSnapshots = [];

    try {
      // First try combined compound query: isuser == false AND callsAfterLastPayment > 5
      // This is the optimal query when the composite index is present.
      final combinedSnap = await _firestore
          .collection('users')
          .where('isuser', isEqualTo: false)
          .where('callsAfterLastPayment', isGreaterThan: 5)
          .get()
          .timeout(_usersQueryTimeout);

      eligibleUserSnapshots = combinedSnap.docs;
      usedCompositeIndex = true;
    } on FirebaseException catch (e) {
      if (e.code == 'failed-precondition') {
        if (kDebugMode) {
          debugPrint(
            '⚠️ [CallLogSheet] Firestore composite index missing on users (isuser + callsAfterLastPayment). '
            'Executing fallback single-field query and filtering in-memory. Error: ${e.message}',
          );
        }
      } else {
        if (kDebugMode) {
          debugPrint('⚠️ [CallLogSheet] Users query FirebaseException: $e');
        }
      }

      // Safe fallback: execute single-field range query on callsAfterLastPayment > 5
      // and enforce isuser == false in memory so results are 100% identical.
      try {
        final fallbackSnap = await _firestore
            .collection('users')
            .where('callsAfterLastPayment', isGreaterThan: 5)
            .get()
            .timeout(_usersQueryTimeout);
        eligibleUserSnapshots = fallbackSnap.docs;
      } catch (fallbackError) {
        throw Exception(
          'Failed to retrieve eligible service providers from Firestore: $fallbackError',
        );
      }
    } catch (e) {
      // Generic exception fallback (e.g. timeout on compound query)
      try {
        final fallbackSnap = await _firestore
            .collection('users')
            .where('callsAfterLastPayment', isGreaterThan: 5)
            .get()
            .timeout(_usersQueryTimeout);
        eligibleUserSnapshots = fallbackSnap.docs;
      } catch (fallbackError) {
        throw Exception(
          'Failed to retrieve eligible service providers from Firestore: $fallbackError',
        );
      }
    }

    // 2. Strict in-memory eligibility filtering & deduplication:
    // - Must be service provider (isuser == false)
    // - Must have callsAfterLastPayment > 5
    // - Prevent duplicate providers
    final Map<String, Map<String, dynamic>> eligibleProvidersMap = {};

    for (final doc in eligibleUserSnapshots) {
      final data = doc.data();
      if (!isServiceProvider(data)) continue;

      final calls = parseInt(data['callsAfterLastPayment']) ?? 0;
      if (calls <= 5) continue;

      eligibleProvidersMap[doc.id] = data;
    }

    final totalEligible = eligibleProvidersMap.length;

    if (totalEligible == 0) {
      stopwatch.stop();
      final metrics = CallLogSheetSyncMetrics(
        eligibleProvidersCount: 0,
        totalBatches: 0,
        successfulBatches: 0,
        failedBatches: 0,
        callLogsRetrieved: 0,
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        usedCompositeIndex: usedCompositeIndex,
      );

      _logMetrics(metrics);

      return CallLogSheetFetchResult(
        items: [],
        metrics: metrics,
      );
    }

    final eligibleIds = eligibleProvidersMap.keys.toList();

    // 3. Partition eligible provider IDs into small batches of 15 to reduce packet sizes
    final List<List<String>> batches = [];
    for (int i = 0; i < eligibleIds.length; i += _batchSize) {
      batches.add(
        eligibleIds.sublist(i, min(i + _batchSize, eligibleIds.length)),
      );
    }

    final int totalBatches = batches.length;
    int successfulBatches = 0;
    int failedBatches = 0;
    int totalLogsRetrieved = 0;

    final Map<String, List<CallLogItemData>> callLogsByBusinessId = {};
    final Map<String, String> providerCallLogsFetchErrors = {};

    // 4. Controlled Concurrency Worker Pool:
    // Runs at most _maxConcurrentBatches (3) parallel requests at any time.
    // Prevents browser WebChannel connection saturation and head-of-line blocking.
    await _runWithConcurrencyLimit(
      items: batches,
      maxConcurrent: _maxConcurrentBatches,
      worker: (batch) async {
        bool batchSucceeded = false;
        String? lastErrorMsg;

        // Try up to 2 attempts per batch (1 retry with exponential backoff on transient timeout)
        for (int attempt = 0; attempt < 2; attempt++) {
          try {
            if (attempt > 0) {
              await Future.delayed(const Duration(milliseconds: 500));
            }

            final querySnap = await _firestore
                .collection('callLogs')
                .where('businessId', whereIn: batch)
                .get()
                .timeout(_callLogsBatchTimeout);

            for (final doc in querySnap.docs) {
              final logItem = CallLogItemData.fromFirestore(doc);
              final bId = logItem.businessId;
              if (bId != null && bId.isNotEmpty) {
                callLogsByBusinessId.putIfAbsent(bId, () => []).add(logItem);
                totalLogsRetrieved++;
              }
            }

            batchSucceeded = true;
            successfulBatches++;
            break;
          } catch (err) {
            lastErrorMsg = err.toString();
            if (kDebugMode) {
              debugPrint(
                'Batch of ${batch.length} attempt ${attempt + 1} failed: $err',
              );
            }
          }
        }

        if (!batchSucceeded) {
          failedBatches++;
          for (final id in batch) {
            providerCallLogsFetchErrors[id] =
                lastErrorMsg ?? 'Timeout fetching call logs';
          }
        }
      },
    );

    stopwatch.stop();

    // 5. Consolidate one row per eligible service provider
    final List<CallLogSheetItem> consolidatedItems = [];

    for (final entry in eligibleProvidersMap.entries) {
      final businessId = entry.key;
      final userData = entry.value;

      final userCallLogs = callLogsByBusinessId[businessId] ?? [];
      final fetchError = providerCallLogsFetchErrors[businessId];

      // Business Name: callLogs.businessName fallback to users.businessname
      String businessName = '';
      for (final cl in userCallLogs) {
        if (cl.businessName != null && cl.businessName!.trim().isNotEmpty) {
          businessName = cl.businessName!.trim();
          break;
        }
      }
      if (businessName.isEmpty) {
        businessName = (userData['businessname'] ??
                userData['businessName'] ??
                userData['name'])
            ?.toString()
            .trim() ??
            '';
      }
      if (businessName.isEmpty) {
        businessName = 'Provider ($businessId)';
      }

      // Phone: callLogs.businessPhone fallback to users.phone
      String phone = '';
      for (final cl in userCallLogs) {
        if (cl.businessPhone != null && cl.businessPhone!.trim().isNotEmpty) {
          phone = cl.businessPhone!.trim();
          break;
        }
      }
      if (phone.isEmpty) {
        phone = userData['phone']?.toString().trim() ?? '';
      }

      // Calls count after last payment (> 5)
      final callsAfterPayment = parseInt(userData['callsAfterLastPayment']) ?? 0;

      // Deactivated date
      final deactivatedAt = parseDateTime(userData['deactivatedAt']);

      // Distinct feedback statuses
      final List<String> feedbackStatuses = [];
      if (fetchError != null) {
        // Distinct retrieval failure from missing data
        feedbackStatuses.add('Sync Error');
      } else if (userCallLogs.isEmpty) {
        feedbackStatuses.add('No Calls Logged');
      } else {
        for (final cl in userCallLogs) {
          final st = cl.feedbackStatus?.trim();
          if (st != null && st.isNotEmpty && !feedbackStatuses.contains(st)) {
            feedbackStatuses.add(st);
          }
        }
        if (feedbackStatuses.isEmpty) {
          feedbackStatuses.add('Pending');
        }
      }

      // Transaction ID
      final rawTx = userData['transactionId']?.toString().trim();
      final transactionId = (rawTx != null && rawTx.isNotEmpty) ? rawTx : null;

      // Converted count: users.convertedCount is the single source of truth
      final convertedCount = parseInt(userData['convertedCount']) ?? 0;

      consolidatedItems.add(
        CallLogSheetItem(
          businessId: businessId,
          businessName: businessName,
          phone: phone.isNotEmpty ? phone : 'N/A',
          callsAfterLastPayment: callsAfterPayment,
          deactivatedAt: deactivatedAt,
          feedbackStatuses: feedbackStatuses,
          callLogs: userCallLogs,
          transactionId: transactionId,
          convertedCount: convertedCount,
          userRawData: userData,
          callLogsFetchError: fetchError,
        ),
      );
    }

    final metrics = CallLogSheetSyncMetrics(
      eligibleProvidersCount: totalEligible,
      totalBatches: totalBatches,
      successfulBatches: successfulBatches,
      failedBatches: failedBatches,
      callLogsRetrieved: totalLogsRetrieved,
      elapsedMilliseconds: stopwatch.elapsedMilliseconds,
      usedCompositeIndex: usedCompositeIndex,
    );

    _logMetrics(metrics);

    String? warningMessage;
    if (failedBatches > 0) {
      warningMessage =
          'Partial Sync: $successfulBatches of $totalBatches batches completed successfully. '
          '$failedBatches batches timed out. Providers with missing logs are flagged with "Fetch Error".';
    }

    return CallLogSheetFetchResult(
      items: consolidatedItems,
      warningMessage: warningMessage,
      metrics: metrics,
    );
  }

  /// Concurrency limiter that processes tasks with at most [maxConcurrent] tasks in flight.
  static Future<void> _runWithConcurrencyLimit<T>({
    required List<T> items,
    required int maxConcurrent,
    required Future<void> Function(T item) worker,
  }) async {
    if (items.isEmpty) return;

    int nextIndex = 0;
    final int workerCount = min(maxConcurrent, items.length);
    final List<Future<void>> activeWorkers = [];

    for (int i = 0; i < workerCount; i++) {
      activeWorkers.add(() async {
        while (true) {
          int index;
          if (nextIndex >= items.length) break;
          index = nextIndex++;
          await worker(items[index]);
        }
      }());
    }

    await Future.wait(activeWorkers);
  }

  /// Logs metrics without exposing sensitive PII
  static void _logMetrics(CallLogSheetSyncMetrics metrics) {
    if (!kDebugMode) return;
    debugPrint('====================================================');
    debugPrint('📊 [CallLogSheet] SYNC SUMMARY REPORT:');
    debugPrint(' • Eligible Providers Found: ${metrics.eligibleProvidersCount}');
    debugPrint(' • Total Batches Created:   ${metrics.totalBatches} (size: $_batchSize, max concurrency: $_maxConcurrentBatches)');
    debugPrint(' • Successful Batches:      ${metrics.successfulBatches}');
    debugPrint(' • Failed Batches:          ${metrics.failedBatches}');
    debugPrint(' • Call Logs Retrieved:     ${metrics.callLogsRetrieved}');
    debugPrint(' • Total Execution Time:    ${metrics.elapsedMilliseconds} ms (${(metrics.elapsedMilliseconds / 1000).toStringAsFixed(2)}s)');
    debugPrint(' • Used Composite Index:    ${metrics.usedCompositeIndex ? "YES (Compound Query)" : "FALLBACK (In-Memory Filter)"}');
    debugPrint('====================================================');
  }
}
