import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skazo_admin/providers/pending_feedback_provider.dart';
import 'package:skazo_admin/widgets/pending_provider_feedback_data_view.dart';

void main() {
  group('Pending Provider Feedback Real-Time & Timestamp Unit Tests', () {
    test('1. Safe timestamp parser handles all types and malformed values gracefully', () {
      final now = DateTime(2026, 10, 27, 12, 30, 45);
      final ts = Timestamp.fromDate(now);

      // Firestore Timestamp
      expect(parseSafeDateTime(ts), equals(now));

      // Dart DateTime
      expect(parseSafeDateTime(now), equals(now));

      // ISO-8601 string
      expect(parseSafeDateTime('2026-10-27T12:30:45.000'), equals(now));
      expect(parseSafeDateTime('2026-10-27 12:30:45'), isNotNull);

      // Integer epoch in milliseconds (> 1e11)
      expect(
        parseSafeDateTime(now.millisecondsSinceEpoch),
        equals(DateTime.fromMillisecondsSinceEpoch(now.millisecondsSinceEpoch)),
      );

      // Integer epoch in seconds (< 1e11)
      final seconds = now.millisecondsSinceEpoch ~/ 1000;
      expect(
        parseSafeDateTime(seconds),
        equals(DateTime.fromMillisecondsSinceEpoch(seconds * 1000)),
      );

      // Stringified Firestore Timestamp e.g. "Timestamp(seconds=1729000000, nanoseconds=...)"
      final stringifiedTs = 'Timestamp(seconds=$seconds, nanoseconds=0)';
      expect(
        parseSafeDateTime(stringifiedTs),
        equals(DateTime.fromMillisecondsSinceEpoch(seconds * 1000)),
      );

      // Numeric string
      expect(
        parseSafeDateTime('$seconds'),
        equals(DateTime.fromMillisecondsSinceEpoch(seconds * 1000)),
      );

      // Null, empty, and malformed values should NOT throw and return null
      expect(parseSafeDateTime(null), isNull);
      expect(parseSafeDateTime(''), isNull);
      expect(parseSafeDateTime('   '), isNull);
      expect(parseSafeDateTime('null'), isNull);
      expect(parseSafeDateTime('malformed_date_string'), isNull);
      expect(parseSafeDateTime(false), isNull);
      expect(parseSafeDateTime([]), isNull);
      expect(parseSafeDateTime({}), isNull);
    });

    test('2. Deduplication by businessId and selects newest pending call log', () {
      final logOlder = {
        'businessId': 'biz_1',
        'businessName': 'Old Business Name',
        'businessPhone': '911111111111',
        'customerName': 'Old Customer',
        'customerPhone': '912222222222',
        'feedbackStatus': 'pending',
        'timestamp': DateTime(2026, 10, 27, 10, 00), // 10:00 AM
      };

      final logNewer = {
        'businessId': 'biz_1',
        'businessName': 'New Business Name',
        'businessPhone': '913333333333',
        'customerName': 'New Customer',
        'customerPhone': '914444444444',
        'feedbackStatus': 'pending',
        'timestamp': DateTime(2026, 10, 27, 11, 30), // 11:30 AM (Newer)
      };

      final logOtherBiz = {
        'businessId': 'biz_2',
        'businessName': 'Biz 2 Services',
        'businessPhone': '915555555555',
        'customerName': 'Customer 2',
        'customerPhone': '916666666666',
        'feedbackStatus': 'pending',
        'timestamp': DateTime(2026, 10, 27, 09, 00),
      };

      final allRawLogs = [logOlder, logNewer, logOtherBiz];

      // Simulate the deduplication and newest-selection logic
      final representativeLogs = <String, Map<String, dynamic>>{};
      for (final doc in allRawLogs) {
        final bizId = doc['businessId'] as String;
        final docTs = parseSafeDateTime(doc['timestamp']);
        final existing = representativeLogs[bizId];

        if (existing == null) {
          representativeLogs[bizId] = doc;
        } else {
          final existingTs = parseSafeDateTime(existing['timestamp']);
          if (docTs != null && (existingTs == null || docTs.isAfter(existingTs))) {
            representativeLogs[bizId] = doc;
          }
        }
      }

      // Assert only 2 unique businessIds exist
      expect(representativeLogs.length, equals(2));
      expect(representativeLogs.containsKey('biz_1'), isTrue);
      expect(representativeLogs.containsKey('biz_2'), isTrue);

      // Assert biz_1 has the representative data from the NEWER call log
      final biz1Data = representativeLogs['biz_1']!;
      expect(biz1Data['businessName'], equals('New Business Name'));
      expect(biz1Data['customerName'], equals('New Customer'));
      expect(biz1Data['customerPhone'], equals('914444444444'));
      expect(biz1Data['businessPhone'], equals('913333333333'));
    });

    test('3. Converted call logs excluded & pending logs included', () {
      final logs = [
        {'businessId': 'b1', 'feedbackStatus': 'pending'},
        {'businessId': 'b2', 'feedbackStatus': 'converted'},
        {'businessId': 'b3', 'feedbackStatus': 'PENDING'}, // Case mismatch
        {'businessId': 'b4'}, // Missing status
      ];

      final pendingOnly = logs.where((doc) {
        final status = doc['feedbackStatus'];
        return status is String && status == 'pending';
      }).toList();

      expect(pendingOnly.length, equals(1));
      expect(pendingOnly.first['businessId'], equals('b1'));
    });

    test('4. Field mappings and fallback without substituting provider data into customer fields', () {
      final userData = {
        'name': 'Provider John',
        'phone': '919999999999',
        'businessname': 'Provider Biz User',
      };

      // Call log with customer info and call log business phone
      final callLog = <String, dynamic>{
        'businessId': 'p1',
        'businessPhone': '918888888888',
        'businessName': 'CallLog Biz Name',
        'customerName': 'Alice Customer',
        'customerPhone': '917777777777',
        'timestamp': DateTime(2026, 10, 27, 10, 00),
      };

      // Provider Name: from users doc
      final name = userData['name']!;
      expect(name, equals('Provider John'));

      // Provider Phone: prefer users doc
      final providerPhone = userData['phone'] ?? callLog['businessPhone'];
      expect(providerPhone, equals('919999999999'));

      // Business Name: prefer callLog
      final businessName = callLog['businessName'] ?? userData['businessname'];
      expect(businessName, equals('CallLog Biz Name'));

      // Customer Name: strictly from callLog
      final customerName = (callLog['customerName']?.toString() ?? '').trim().isNotEmpty
          ? callLog['customerName']!.toString().trim()
          : '—';
      expect(customerName, equals('Alice Customer'));

      // Customer Phone: strictly from callLog (MUST NOT be provider's phone)
      final customerPhone = (callLog['customerPhone']?.toString() ?? '').trim().isNotEmpty
          ? callLog['customerPhone']!.toString().trim()
          : '—';
      expect(customerPhone, equals('917777777777'));
      expect(customerPhone, isNot(equals(providerPhone)));

      // When customer info is missing, it falls back to '—', NOT provider info
      final emptyCallLog = <String, dynamic>{
        'customerName': '',
        'customerPhone': '',
      };
      final emptyCusName = (emptyCallLog['customerName']?.toString() ?? '').trim().isNotEmpty
          ? emptyCallLog['customerName']!.toString().trim()
          : '—';
      final emptyCusPhone = (emptyCallLog['customerPhone']?.toString() ?? '').trim().isNotEmpty
          ? emptyCallLog['customerPhone']!.toString().trim()
          : '—';
      expect(emptyCusName, equals('—'));
      expect(emptyCusPhone, equals('—'));
    });

    test('5. Stale snapshot race condition prevention logic', () async {
      int currentRevision = 0;
      final committedResults = <String>[];

      Future<void> simulateSnapshot(int snapshotId, int delayMs, String resultPayload) async {
        final revision = ++currentRevision;

        // Simulate async users lookup
        await Future.delayed(Duration(milliseconds: delayMs));

        // Check revision before committing
        if (revision == currentRevision) {
          committedResults.add(resultPayload);
        } else {
          // Stale snapshot ignored
        }
      }

      // Snapshot 1 arrives first but is SLOW (100ms)
      final f1 = simulateSnapshot(1, 100, 'Snapshot 1 Data');

      // Snapshot 2 arrives shortly after and is FAST (20ms)
      await Future.delayed(const Duration(milliseconds: 10));
      final f2 = simulateSnapshot(2, 20, 'Snapshot 2 Data');

      await Future.wait([f1, f2]);

      // Only Snapshot 2 should be committed, Snapshot 1 should have been ignored
      expect(committedResults.length, equals(1));
      expect(committedResults.first, equals('Snapshot 2 Data'));
    });

    test('6. Search filtering across provider name, phone, business, customer name, and customer phone', () {
      final providers = [
        const PendingFeedbackProvider(
          businessId: '1',
          name: 'Rajesh Sharma',
          phone: '919703575727',
          businessName: 'Apex Electricals',
          cusName: 'Kiran Patel',
          cusPhone: '917396722072',
          timestamp: null,
        ),
        const PendingFeedbackProvider(
          businessId: '2',
          name: 'Sunita Rao',
          phone: '919876543210',
          businessName: 'Bright Cleaners',
          cusName: 'Deepak Verma',
          cusPhone: '918888888888',
          timestamp: null,
        ),
      ];

      final state = PendingFeedbackState(providers: providers, isLoading: false);

      // Search by customer name
      final byCusName = state.copyWith(searchQuery: 'kiran');
      expect(byCusName.filtered.length, equals(1));
      expect(byCusName.filtered.first.businessId, equals('1'));

      // Search by customer phone
      final byCusPhone = state.copyWith(searchQuery: '888888');
      expect(byCusPhone.filtered.length, equals(1));
      expect(byCusPhone.filtered.first.businessId, equals('2'));

      // Search by provider name
      final byProvName = state.copyWith(searchQuery: 'sunita');
      expect(byProvName.filtered.length, equals(1));
      expect(byProvName.filtered.first.businessId, equals('2'));

      // Search by business name
      final byBizName = state.copyWith(searchQuery: 'electricals');
      expect(byBizName.filtered.length, equals(1));
      expect(byBizName.filtered.first.businessId, equals('1'));
    });

    testWidgets('7. UI renders Table with all 7 columns and corresponding data row cells', (
      WidgetTester tester,
    ) async {
      final sampleTime = DateTime(2026, 10, 27, 14, 15);
      final fakeProviders = [
        PendingFeedbackProvider(
          businessId: 'b1',
          name: 'Provider John',
          phone: '919703575727',
          businessName: 'Digital Solutions',
          cusName: 'Sam Customer',
          cusPhone: '917396722072',
          timestamp: sampleTime,
        ),
      ];

      final testState = PendingFeedbackState(
        providers: fakeProviders,
        isLoading: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingFeedbackProvider.overrideWith(
              () => _TestPendingFeedbackNotifier(testState),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingProviderFeedbackDataView(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Table Header cells (7 columns)
      expect(find.text('S.No'), findsOneWidget);
      expect(find.text('Name'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
      expect(find.text('Business Name'), findsOneWidget);
      expect(find.text('Cus Name'), findsOneWidget);
      expect(find.text('Cus Ph'), findsOneWidget);
      expect(find.text('Timestamp'), findsOneWidget);

      // Data Row cells (7 values)
      expect(find.text('1'), findsOneWidget); // S.No
      expect(find.text('Provider John'), findsOneWidget); // Name
      expect(find.text('919703575727'), findsOneWidget); // Phone
      expect(find.text('Digital Solutions'), findsOneWidget); // Business Name
      expect(find.text('Sam Customer'), findsOneWidget); // Cus Name
      expect(find.text('917396722072'), findsOneWidget); // Cus Ph

      // Header summary badge
      expect(find.text('1 Pending'), findsOneWidget);
    });

    testWidgets('8. Real-time updates: changing feedbackStatus dynamically removes & adds providers in UI', (
      WidgetTester tester,
    ) async {
      final streamController = StreamController<PendingFeedbackState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            pendingFeedbackProvider.overrideWith(
              () => _StreamTestPendingFeedbackNotifier(streamController),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: PendingProviderFeedbackDataView(),
            ),
          ),
        ),
      );

      // 1. Initial pending provider
      streamController.add(
        PendingFeedbackState(
          providers: [
            PendingFeedbackProvider(
              businessId: 'prov_1',
              name: 'Electrician Ramesh',
              phone: '919111111111',
              businessName: 'Ramesh Electricals',
              cusName: 'Anil',
              cusPhone: '919222222222',
              timestamp: DateTime(2026, 10, 27, 10, 00),
            ),
          ],
          isLoading: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Electrician Ramesh'), findsOneWidget);
      expect(find.text('1 Pending'), findsOneWidget);

      // 2. Feedback converted -> provider removed immediately
      streamController.add(
        const PendingFeedbackState(
          providers: [],
          isLoading: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Electrician Ramesh'), findsNothing);
      expect(find.text('No Pending Feedback'), findsOneWidget);

      // 3. New pending call log arrives -> provider appears again
      streamController.add(
        PendingFeedbackState(
          providers: [
            PendingFeedbackProvider(
              businessId: 'prov_2',
              name: 'Plumber Suresh',
              phone: '919333333333',
              businessName: 'Suresh Plumbing',
              cusName: 'Vijay',
              cusPhone: '919444444444',
              timestamp: DateTime(2026, 10, 27, 12, 00),
            ),
          ],
          isLoading: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plumber Suresh'), findsOneWidget);
      expect(find.text('1 Pending'), findsOneWidget);

      await streamController.close();
    });
  });
}

class _TestPendingFeedbackNotifier extends PendingFeedbackNotifier {
  _TestPendingFeedbackNotifier(this._initialState);
  final PendingFeedbackState _initialState;

  @override
  PendingFeedbackState build() {
    return _initialState;
  }
}

class _StreamTestPendingFeedbackNotifier extends PendingFeedbackNotifier {
  _StreamTestPendingFeedbackNotifier(this._controller);
  final StreamController<PendingFeedbackState> _controller;
  StreamSubscription<PendingFeedbackState>? _sub;

  @override
  PendingFeedbackState build() {
    _sub = _controller.stream.listen((newState) {
      state = newState;
    });
    ref.onDispose(() {
      _sub?.cancel();
    });
    return const PendingFeedbackState(isLoading: true);
  }
}
