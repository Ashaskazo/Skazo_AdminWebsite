import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/widgets/provider_call_logs_section.dart';

class _FakeUser extends Fake implements User {
  @override
  String? get email => 'admin@skazo.test';

  @override
  String get uid => 'test_admin_uid';
}

List<Override> _baseAdminOverrides() {
  return [
    authStateProvider.overrideWith(
      (ref) => Stream.value(_FakeUser()),
    ),
    cityAccessScopeProvider.overrideWithValue(
      CityAccessScope.authorized(
        isSuperAdmin: true,
        adminId: 'test_admin_uid',
        email: 'admin@skazo.test',
        displayName: 'Test Admin',
        role: 'super_admin',
      ),
    ),
    currentAdminProfileProvider.overrideWith(
      (ref) => Stream.value(<String, dynamic>{
        'name': 'Test Admin',
        'email': 'admin@skazo.test',
        'role': 'super_admin',
        'isActive': true,
      }),
    ),
  ];
}

void main() {
  group('ProviderCallLogItem Model Tests', () {
    test('1. Parses fields from Firestore map accurately', () {
      final sampleData = {
        'businessId': 'prov_123',
        'customerName': 'Ramesh Kumar',
        'customerPhone': '9876543210',
        'feedbackStatus': 'completed',
        'status': 'won',
        'timestamp': DateTime(2026, 11, 16, 14, 30),
      };

      final item = ProviderCallLogItem.fromMap('log_doc_1', sampleData);

      expect(item.id, 'log_doc_1');
      expect(item.businessId, 'prov_123');
      expect(item.customerName, 'Ramesh Kumar');
      expect(item.customerPhone, '+91 98765 43210');
      expect(item.rawCustomerPhone, '9876543210');
      expect(item.feedbackStatus, 'completed');
      expect(item.salesStatus, 'won');
      expect(item.timestamp, isNotNull);
    });

    test('2. Missing or null fields gracefully fallback to N/A', () {
      final emptyData = <String, dynamic>{
        'businessId': 'prov_123',
      };

      final item = ProviderCallLogItem.fromMap('log_doc_2', emptyData);

      expect(item.customerName, 'N/A');
      expect(item.customerPhone, 'N/A');
      expect(item.feedbackStatus, 'N/A');
      expect(item.salesStatus, 'N/A');
      expect(item.timestamp, isNull);
    });

    test('3. Formats readable phone numbers correctly', () {
      expect(
        ProviderCallLogItem.formatReadablePhoneNumber('9876543210'),
        '+91 98765 43210',
      );
      expect(
        ProviderCallLogItem.formatReadablePhoneNumber('+919876543210'),
        '+91 98765 43210',
      );
      expect(
        ProviderCallLogItem.formatReadablePhoneNumber('919876543210'),
        '+91 98765 43210',
      );
      expect(
        ProviderCallLogItem.formatReadablePhoneNumber(null),
        'N/A',
      );
      expect(
        ProviderCallLogItem.formatReadablePhoneNumber(''),
        'N/A',
      );
      expect(
        ProviderCallLogItem.formatReadablePhoneNumber('040-23456789'),
        '040-23456789',
      );
    });
  });

  group('ProviderCallLogsSection Widget Tests', () {
    final sampleLogsProviderA = [
      ProviderCallLogItem(
        id: 'log_a_1',
        businessId: 'provider_A',
        customerName: 'Ananya Sharma',
        customerPhone: '+91 98480 12345',
        rawCustomerPhone: '9848012345',
        feedbackStatus: 'converted',
        salesStatus: 'won',
        timestamp: DateTime(2026, 11, 17, 10, 0),
      ),
      ProviderCallLogItem(
        id: 'log_a_2',
        businessId: 'provider_A',
        customerName: 'Karthik Rao',
        customerPhone: '+91 98480 67890',
        rawCustomerPhone: '9848067890',
        feedbackStatus: 'pending',
        salesStatus: 'contacted',
        timestamp: DateTime(2026, 11, 16, 15, 30),
      ),
    ];

    final sampleLogsProviderB = [
      ProviderCallLogItem(
        id: 'log_b_1',
        businessId: 'provider_B',
        customerName: 'Vikram Seth',
        customerPhone: '+91 99000 11223',
        rawCustomerPhone: '9900011223',
        feedbackStatus: 'completed',
        salesStatus: 'closed',
        timestamp: DateTime(2026, 11, 17, 11, 15),
      ),
    ];

    Widget buildTestWidget({
      required String providerId,
      Stream<List<ProviderCallLogItem>>? stream,
      Size surfaceSize = const Size(1200, 800),
    }) {
      return MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(size: surfaceSize),
          child: Scaffold(
            body: SingleChildScrollView(
              child: ProviderCallLogsSection(
                providerId: providerId,
                callLogsStream: stream,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('1. Opening Provider A displays only Provider A logs', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'provider_A',
          stream: Stream.value(sampleLogsProviderA),
        ),
      );
      await tester.pumpAndSettle();

      // Provider A records must be visible
      expect(find.text('Ananya Sharma'), findsOneWidget);
      expect(find.text('Karthik Rao'), findsOneWidget);
      expect(find.text('+91 98480 12345'), findsOneWidget);
      expect(find.text('converted'), findsOneWidget);
      expect(find.text('won'), findsOneWidget);

      // Provider B records MUST NOT be visible
      expect(find.text('Vikram Seth'), findsNothing);
      expect(find.text('+91 99000 11223'), findsNothing);
    });

    testWidgets('2. Opening Provider B displays only Provider B logs', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'provider_B',
          stream: Stream.value(sampleLogsProviderB),
        ),
      );
      await tester.pumpAndSettle();

      // Provider B records must be visible
      expect(find.text('Vikram Seth'), findsOneWidget);
      expect(find.text('+91 99000 11223'), findsOneWidget);
      expect(find.text('completed'), findsOneWidget);
      expect(find.text('closed'), findsOneWidget);

      // Provider A records MUST NOT be visible
      expect(find.text('Ananya Sharma'), findsNothing);
      expect(find.text('Karthik Rao'), findsNothing);
    });

    testWidgets('3. Renders all 5 required table columns on desktop', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'provider_A',
          stream: Stream.value(sampleLogsProviderA),
        ),
      );
      await tester.pumpAndSettle();

      // Verify the 5 required columns
      expect(find.text('Sl No'), findsOneWidget);
      expect(find.text('Customer Name'), findsOneWidget);
      expect(find.text('Customer Phone'), findsOneWidget);
      expect(find.text('Feedback Status'), findsOneWidget);
      expect(find.text('Sales Status'), findsOneWidget);

      // Verify Sl No values
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('4. Displays proper empty state when provider has no call logs', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'provider_C',
          stream: Stream.value([]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('provider_call_logs_empty_state')), findsOneWidget);
      expect(find.text('No Call Logs Found'), findsOneWidget);
      expect(
        find.text('There are no call log records associated with this provider yet.'),
        findsOneWidget,
      );
    });

    testWidgets('5. Displays error state on stream failure', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final controller = StreamController<List<ProviderCallLogItem>>();
      controller.addError('Firestore permission denied');

      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'provider_D',
          stream: controller.stream,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('provider_call_logs_error_state')), findsOneWidget);
      expect(find.text('Error Loading Provider Call Logs'), findsOneWidget);
      expect(find.textContaining('Firestore permission denied'), findsOneWidget);

      await controller.close();
    });

    testWidgets('6. Responsive mobile cards render without overflow on 360px screen', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(360, 640));
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'provider_A',
          stream: Stream.value(sampleLogsProviderA),
          surfaceSize: const Size(360, 640),
        ),
      );
      await tester.pumpAndSettle();

      // Mobile cards rendered
      expect(find.text('#1'), findsOneWidget);
      expect(find.text('#2'), findsOneWidget);
      expect(find.text('Ananya Sharma'), findsOneWidget);
      expect(find.text('Karthik Rao'), findsOneWidget);

      // Verify no RenderFlex overflow
      expect(tester.takeException(), isNull);
    });

    testWidgets('7. Real-time stream updates reflect in UI without page reload', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1200, 800));
      final controller = StreamController<List<ProviderCallLogItem>>();

      await tester.pumpWidget(
        buildTestWidget(
          providerId: 'provider_A',
          stream: controller.stream,
        ),
      );
      await tester.pump();

      // Initially loading
      expect(find.byKey(const ValueKey('provider_call_logs_loading_state')), findsOneWidget);

      // Emit initial item with pending status
      controller.add([
        ProviderCallLogItem(
          id: 'log_live_1',
          businessId: 'provider_A',
          customerName: 'Sunil Verma',
          customerPhone: '+91 98111 22334',
          rawCustomerPhone: '9811122334',
          feedbackStatus: 'pending',
          salesStatus: 'contacted',
          timestamp: DateTime(2026, 11, 17, 12, 0),
        ),
      ]);
      await tester.pumpAndSettle();

      expect(find.text('Sunil Verma'), findsOneWidget);
      expect(find.text('pending'), findsOneWidget);
      expect(find.text('contacted'), findsOneWidget);

      // Real-time update: status changed to 'completed' and 'won'
      controller.add([
        ProviderCallLogItem(
          id: 'log_live_1',
          businessId: 'provider_A',
          customerName: 'Sunil Verma',
          customerPhone: '+91 98111 22334',
          rawCustomerPhone: '9811122334',
          feedbackStatus: 'completed',
          salesStatus: 'won',
          timestamp: DateTime(2026, 11, 17, 12, 0),
        ),
      ]);
      await tester.pumpAndSettle();

      // Statuses updated dynamically
      expect(find.text('completed'), findsOneWidget);
      expect(find.text('won'), findsOneWidget);

      await controller.close();
    });
  });

  group('BusinessProfilePage Integration Tests', () {
    final sampleProviderDoc = {
      'id': 'test_provider_999',
      'uid': 'test_provider_999',
      'businessname': 'Apex Electrical Services',
      'firstname': 'Suresh',
      'lastname': 'Patel',
      'phone': '9876543210',
      'email': 'suresh@apex.com',
      'city': 'Hyderabad',
      'category': 'Electricians',
      'totalCallLogs': 4,
      'totalCallsGenerated': 4,
      'callsAfterLastPayment': 2,
    };

    testWidgets('BusinessProfilePage renders Provider Call Logs section', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(const Size(1366, 3000));
      tester.view.physicalSize = const Size(1366, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ..._baseAdminOverrides(),
            propertyPincodesProvider.overrideWith((ref) async => const <String, List<String>>{}),
          ],
          child: MaterialApp(
            home: BusinessProfilePage(businessData: sampleProviderDoc),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));

      // Verify the new section header and widget exist
      expect(find.text('Provider Call Logs 📞'), findsOneWidget);
      expect(
        find.text('All call log records associated with this provider, customer details, and feedback status'),
        findsOneWidget,
      );
      expect(find.byType(ProviderCallLogsSection), findsOneWidget);
    });
  });
}
