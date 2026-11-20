import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skazo_admin/models/call_logs_detail_item.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/call_logs_detail_provider.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/dashboard_provider.dart';
import 'package:skazo_admin/repositories/call_logs_detail_repository.dart';
import 'package:skazo_admin/widgets/call_logs_data_view.dart';
import 'package:skazo_admin/widgets/sidebar_nav.dart';

class _FakeCallLogsDetailRepository implements CallLogsDetailRepository {
  final List<CallLogsDetailItem> items;

  _FakeCallLogsDetailRepository(this.items);

  @override
  Future<List<CallLogsDetailItem>> fetchCallLogsDetails({
    required CityAccessScope scope,
    String? selectedCity,
    required CallLogsDetailDateOption dateOption,
    DateTime? customStart,
    DateTime? customEnd,
    Map<String, List<String>> pincodesMap = const {},
    Map<String, String>? pincodeCityLookup,
  }) async {
    if (!scope.isAuthorized) return const [];
    return items.where((item) {
      if (selectedCity != null &&
          selectedCity.isNotEmpty &&
          selectedCity != 'All Cities' &&
          selectedCity != 'All') {
        if (!item.city.toLowerCase().contains(selectedCity.toLowerCase())) {
          return false;
        }
      }
      return scope.allowsRecord({'city': item.city});
    }).toList();
  }

  @override
  void clearCache() {}
}

void main() {
  group('Call & Action Logs - Integrated Navigation & Subviews Test Suite', () {
    final sampleItems = [
      CallLogsDetailItem(
        callLogId: 'log_vja_1',
        businessId: 'prov_vja_101',
        businessName: 'Krishna Electrical Works',
        businessPhone: '9876543210',
        city: 'Vijayawada',
        category: 'Electricians',
        timestamp: DateTime(2026, 11, 14, 10, 30),
        callsAfterPayment: 15,
        callStatus: 'Completed',
        feedbackStatus: 'Converted',
      ),
      CallLogsDetailItem(
        callLogId: 'log_bvr_1',
        businessId: 'prov_bvr_201',
        businessName: 'Godavari Plumbing Solutions',
        businessPhone: '9123456789',
        city: 'Bhimavaram',
        category: 'Plumbers',
        timestamp: DateTime(2026, 11, 14, 11, 45),
        callsAfterPayment: 4,
        callStatus: 'Completed',
        feedbackStatus: 'Interested',
      ),
    ];

    final scopeSuperAdmin = CityAccessScope.authorized(
      isSuperAdmin: true,
      adminId: 'super_admin_1',
      email: 'admin@skazo.test',
    );

    final scopeBhimavaram = CityAccessScope.authorized(
      isSuperAdmin: false,
      adminId: 'bhimavaram_admin',
      email: 'bvr@skazo.test',
      assignedCities: const ['Bhimavaram'],
    );

    Widget createTestWidget({
      CityAccessScope? scope,
      CallLogsSubView initialSubView = CallLogsSubView.crmCallLogs,
    }) {
      return ProviderScope(
        overrides: [
          cityAccessScopeProvider.overrideWithValue(scope ?? scopeSuperAdmin),
          propertyPincodesProvider.overrideWith((ref) async => const <String, List<String>>{}),
          callLogsActiveSubViewProvider.overrideWith((ref) => initialSubView),
          callLogsDetailRepositoryProvider.overrideWithValue(
            _FakeCallLogsDetailRepository(sampleItems),
          ),
          allowedCitiesProvider.overrideWith((ref) async => ['Bhimavaram', 'Vijayawada', 'Guntur']),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CallLogsDataView(),
          ),
        ),
      );
    }

    testWidgets('1. CRM Call Logs is the default selected subview on opening', (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Heading and Two Toggle Buttons exist beside each other
      expect(find.text('CRM Call Logs'), findsWidgets); // Heading + Toggle button
      expect(find.text('Call Logs Details'), findsOneWidget); // Toggle button

      // CRM stats badges exist in CRM Call Logs view
      expect(find.text('Overall Calls'), findsOneWidget);
      expect(find.text('Converted'), findsWidgets);
    });

    testWidgets('2. Clicking "Call Logs Details" switches to Call Logs Details interface without page reload', (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap "Call Logs Details" toggle button
      final detailsBtn = find.widgetWithText(InkWell, 'Call Logs Details');
      expect(detailsBtn, findsOneWidget);

      await tester.tap(detailsBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Header Banner for Call Logs Details appears
      expect(find.text('CALL LOGS DETAILS'), findsOneWidget);
      expect(find.text('CITY & CATEGORY WISE'), findsOneWidget);

      // Category and City bars are present
      expect(find.text('City:'), findsOneWidget);

      // Data is displayed in Call Logs Details table
      expect(find.text('Krishna Electrical Works'), findsOneWidget);
      expect(find.text('Godavari Plumbing Solutions'), findsOneWidget);

      // Switching back to CRM Call Logs works immediately
      final crmBtn = find.widgetWithText(InkWell, 'CRM Call Logs');
      expect(crmBtn, findsOneWidget);

      await tester.tap(crmBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Returns to CRM Call Logs
      expect(find.text('Overall Calls'), findsOneWidget);
    });

    testWidgets('3. Sidebar has "Call & Action Logs" and does NOT have separate "Call Logs Details"', (tester) async {
      tester.view.physicalSize = const Size(1366, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cityAccessScopeProvider.overrideWithValue(scopeSuperAdmin),
            isSuperAdminProvider.overrideWith((ref) => true),
            currentAdminProfileProvider.overrideWith((ref) => Stream.value({'role': 'super_admin'})),
            currentDashboardViewProvider.overrideWith((ref) => DashboardView.logs),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Row(
                children: [
                  SidebarNav(),
                  Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // "Call & Action Logs" is present in sidebar
      expect(find.text('Call & Action Logs'), findsOneWidget);

      // Separate "Call Logs Details" is NOT in sidebar nav
      expect(find.text('Call Logs Details'), findsNothing);
    });

    testWidgets('4. City-wise admin access restriction is respected in Call Logs Details subview', (tester) async {
      tester.view.physicalSize = const Size(1366, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(
        scope: scopeBhimavaram,
        initialSubView: CallLogsSubView.callLogsDetails,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Bhimavaram admin should ONLY see Bhimavaram records
      expect(find.text('Godavari Plumbing Solutions'), findsOneWidget);
      expect(find.text('Krishna Electrical Works'), findsNothing);
    });
  });
}
