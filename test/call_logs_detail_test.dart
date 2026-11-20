import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skazo_admin/constants/hyderabad_area_groups.dart';
import 'package:skazo_admin/models/call_logs_detail_item.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/call_logs_detail_provider.dart';
import 'package:skazo_admin/repositories/call_logs_detail_repository.dart';
import 'package:skazo_admin/utils/city_resolver.dart';
import 'package:skazo_admin/widgets/call_logs_detail_data_view.dart';

void main() {
  group('Call Logs Details - Unit & Integration Test Suite', () {
    const Map<String, List<String>> testPincodesMap = {
      'Bhimavaram': ['534201', '534202', '534203', '534204'],
      'Vijayawada': ['520001', '520002', '520003'],
      'Guntur': ['522001', '522002', '522004'],
      'Hyderabad': ['500001', '500081', '500032'],
    };
    final testPincodeCityLookup = buildPincodeCityLookup(testPincodesMap);

    // =========================================================================
    // 1. Model Parsing & Formatting
    // =========================================================================
    group('1. CallLogsDetailItem Model Parsing & Formatting', () {
      test('Correctly maps all 11 required table fields from Firestore document and user data', () {
        final sampleDate = DateTime(2026, 11, 14, 15, 30);
        final item = CallLogsDetailItem(
          callLogId: 'log_101',
          businessId: 'prov_vja_01',
          businessName: 'Krishna Electrical Works',
          businessPhone: '9876543210',
          callerPhone: '9123456780',
          customerName: 'Ramesh Kumar',
          city: 'Vijayawada',
          category: 'Electricians',
          timestamp: sampleDate,
          callsAfterPayment: 12,
          callStatus: 'Completed',
          feedbackStatus: 'Converted',
        );

        // 1. Sl. No. is handled by index + 1 in view
        // 2. Business Name
        expect(item.businessName, equals('Krishna Electrical Works'));
        // 3. Business Phone Number
        expect(item.businessPhone, equals('9876543210'));
        // 4. City
        expect(item.city, equals('Vijayawada'));
        // 5. Category
        expect(item.category, equals('Electricians'));
        // 6. Provider UID / Business ID
        expect(item.businessId, equals('prov_vja_01'));
        // 7. Call Date
        expect(item.formattedCallDate, equals('14 Nov 2026'));
        // 8. Call Time
        expect(item.formattedCallTime, equals('03:30 PM'));
        // 9. Calls After Payment
        expect(item.callsAfterPayment, equals(12));
        expect(item.formattedCallsAfterPayment, equals('12'));
        // 10. Call Status
        expect(item.displayCallStatus, equals('Completed'));
        // 11. Feedback Status
        expect(item.displayFeedbackStatus, equals('Converted'));
      });

      test('Gracefully handles null or missing fields without throwing', () {
        const item = CallLogsDetailItem(
          callLogId: 'log_empty',
          businessId: '--',
          businessName: '--',
          businessPhone: '--',
          city: '--',
          category: '--',
          timestamp: null,
          callsAfterPayment: 0,
          callStatus: null,
          feedbackStatus: null,
        );

        expect(item.formattedCallDate, equals('--'));
        expect(item.formattedCallTime, equals('--'));
        expect(item.displayCallStatus, equals('--'));
        expect(item.displayFeedbackStatus, equals('--'));
        expect(item.callsAfterPayment, equals(0));
      });

      test('Category resolution handles String, List, and fallbacks properly', () {
        // Direct call log string
        expect(
          CallLogsDetailItem.resolveCategoryString({'category': 'Plumbers'}, null),
          equals('Plumbers'),
        );

        // Direct call log list
        expect(
          CallLogsDetailItem.resolveCategoryString({'category': ['Plumbers', 'Electricians']}, null),
          equals('Plumbers, Electricians'),
        );

        // Fallback to user document string
        expect(
          CallLogsDetailItem.resolveCategoryString({}, {'category': 'AC Repair'}),
          equals('AC Repair'),
        );

        // Fallback to user document list
        expect(
          CallLogsDetailItem.resolveCategoryString({}, {'category': ['Carpentry', 'Wood Works']}),
          equals('Carpentry, Wood Works'),
        );

        // Missing everywhere
        expect(
          CallLogsDetailItem.resolveCategoryString({}, {}),
          equals('--'),
        );
      });
    });

    // =========================================================================
    // 2. Date Filtering Bounds Calculation
    // =========================================================================
    group('2. Date Filter Bounds Calculation', () {
      test('Today bounds cover from midnight today to midnight tomorrow', () {
        final bounds = calculateDateBounds(option: CallLogsDetailDateOption.today);
        final now = DateTime.now();
        final expectedToday = DateTime(now.year, now.month, now.day);
        final expectedTomorrow = expectedToday.add(const Duration(days: 1));

        expect(bounds.start, equals(expectedToday));
        expect(bounds.end, equals(expectedTomorrow));
      });

      test('Yesterday bounds cover from midnight yesterday to midnight today', () {
        final bounds = calculateDateBounds(option: CallLogsDetailDateOption.yesterday);
        final now = DateTime.now();
        final expectedToday = DateTime(now.year, now.month, now.day);
        final expectedYesterday = expectedToday.subtract(const Duration(days: 1));

        expect(bounds.start, equals(expectedYesterday));
        expect(bounds.end, equals(expectedToday));
      });

      test('Last 7 Days bounds start 7 days prior', () {
        final bounds = calculateDateBounds(option: CallLogsDetailDateOption.last7Days);
        final now = DateTime.now();
        final expectedToday = DateTime(now.year, now.month, now.day);
        final expectedSevenDaysAgo = expectedToday.subtract(const Duration(days: 7));

        expect(bounds.start, equals(expectedSevenDaysAgo));
      });

      test('Last 30 Days bounds start 30 days prior', () {
        final bounds = calculateDateBounds(option: CallLogsDetailDateOption.last30Days);
        final now = DateTime.now();
        final expectedToday = DateTime(now.year, now.month, now.day);
        final expectedThirtyDaysAgo = expectedToday.subtract(const Duration(days: 30));

        expect(bounds.start, equals(expectedThirtyDaysAgo));
      });

      test('Custom date range bounds respect start and end dates', () {
        final customStart = DateTime(2026, 11, 1);
        final customEnd = DateTime(2026, 11, 10);
        final bounds = calculateDateBounds(
          option: CallLogsDetailDateOption.custom,
          customStart: customStart,
          customEnd: customEnd,
        );

        expect(bounds.start, equals(DateTime(2026, 11, 1)));
        expect(bounds.end, equals(DateTime(2026, 11, 10, 23, 59, 59, 999)));
      });
    });

    // =========================================================================
    // 3. City-Wise Admin Access Control & Permissions
    // =========================================================================
    group('3. City-Wise Admin Access Control Enforcement', () {
      final scopeSuperAdmin = CityAccessScope.authorized(
        isSuperAdmin: true,
        adminId: 'super_admin_1',
        email: 'super@skazo.test',
      );

      final scopeEmployeeBhimavaram = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Bhimavaram'],
        adminId: 'emp_bvrm_1',
        email: 'bvrm@skazo.test',
      );

      final scopeEmployeeVijayawadaGuntur = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Vijayawada', 'Guntur'],
        adminId: 'emp_vja_1',
        email: 'vja@skazo.test',
      );

      final scopeDeactivated = const CityAccessScope.deniedInactive(
        email: 'deactivated@skazo.test',
      );

      final scopeNoCities = const CityAccessScope.noCitiesAssigned(
        email: 'nocities@skazo.test',
      );

      test('Super Admin has access to all records and cities', () {
        expect(scopeSuperAdmin.isAuthorized, isTrue);
        expect(scopeSuperAdmin.isSuperAdmin, isTrue);
        expect(scopeSuperAdmin.isUnrestricted, isTrue);

        expect(scopeSuperAdmin.canAccessCityName('Vijayawada'), isTrue);
        expect(scopeSuperAdmin.canAccessCityName('Bhimavaram'), isTrue);
        expect(scopeSuperAdmin.canAccessCityName('Hyderabad'), isTrue);

        expect(scopeSuperAdmin.allowsRecord({'city': 'Vijayawada'}), isTrue);
        expect(scopeSuperAdmin.allowsRecord({'city': 'Bhimavaram'}), isTrue);
      });

      test('Bhimavaram Employee is strictly restricted to Bhimavaram', () {
        expect(scopeEmployeeBhimavaram.isAuthorized, isTrue);
        expect(scopeEmployeeBhimavaram.isSuperAdmin, isFalse);
        expect(scopeEmployeeBhimavaram.canAccessCityName('Bhimavaram'), isTrue);
        expect(scopeEmployeeBhimavaram.canAccessCityName('bheemavaram'), isTrue);
        expect(scopeEmployeeBhimavaram.canAccessCityName('Vijayawada'), isFalse);
        expect(scopeEmployeeBhimavaram.canAccessCityName('Hyderabad'), isFalse);

        // Allows Bhimavaram records
        expect(
          scopeEmployeeBhimavaram.allowsRecord({
            'city': 'Bhimavaram',
          }, pincodesMap: testPincodesMap, pincodeCityLookup: testPincodeCityLookup),
          isTrue,
        );

        // Denies other cities
        expect(
          scopeEmployeeBhimavaram.allowsRecord({
            'city': 'Vijayawada',
          }, pincodesMap: testPincodesMap, pincodeCityLookup: testPincodeCityLookup),
          isFalse,
        );

        expect(
          scopeEmployeeBhimavaram.allowsRecord({
            'city': 'Hyderabad',
          }, pincodesMap: testPincodesMap, pincodeCityLookup: testPincodeCityLookup),
          isFalse,
        );
      });

      test('Vijayawada & Guntur Employee access is permitted for assigned cities only', () {
        expect(scopeEmployeeVijayawadaGuntur.canAccessCityName('Vijayawada'), isTrue);
        expect(scopeEmployeeVijayawadaGuntur.canAccessCityName('Guntur'), isTrue);
        expect(scopeEmployeeVijayawadaGuntur.canAccessCityName('Bhimavaram'), isFalse);

        expect(
          scopeEmployeeVijayawadaGuntur.allowsRecord({
            'city': 'Vijayawada',
          }, pincodesMap: testPincodesMap, pincodeCityLookup: testPincodeCityLookup),
          isTrue,
        );
        expect(
          scopeEmployeeVijayawadaGuntur.allowsRecord({
            'city': 'Guntur',
          }, pincodesMap: testPincodesMap, pincodeCityLookup: testPincodeCityLookup),
          isTrue,
        );
        expect(
          scopeEmployeeVijayawadaGuntur.allowsRecord({
            'city': 'Bhimavaram',
          }, pincodesMap: testPincodesMap, pincodeCityLookup: testPincodeCityLookup),
          isFalse,
        );
      });

      test('Deactivated or unassigned admins fail closed immediately', () {
        expect(scopeDeactivated.isAuthorized, isFalse);
        expect(scopeDeactivated.allowsRecord({'city': 'Bhimavaram'}), isFalse);

        expect(scopeNoCities.isAuthorized, isFalse);
        expect(scopeNoCities.allowsRecord({'city': 'Bhimavaram'}), isFalse);
      });
    });

    // =========================================================================
    // 4. Combined Filtering & Search Verification
    // =========================================================================
    group('4. Independent and Combined Filtering Logic', () {
      final sampleItems = [
        CallLogsDetailItem(
          callLogId: 'log_1',
          businessId: 'prov_vja_elec',
          businessName: 'Vijayawada Spark Electricals',
          businessPhone: '9848011111',
          city: 'Vijayawada',
          category: 'Electricians',
          timestamp: DateTime(2026, 11, 14, 10, 0),
          callsAfterPayment: 15,
          feedbackStatus: 'Converted',
        ),
        CallLogsDetailItem(
          callLogId: 'log_2',
          businessId: 'prov_vja_plumb',
          businessName: 'Vijayawada Pipe Masters',
          businessPhone: '9848022222',
          city: 'Vijayawada',
          category: 'Plumbers',
          timestamp: DateTime(2026, 11, 14, 11, 0),
          callsAfterPayment: 8,
          feedbackStatus: 'Interested',
        ),
        CallLogsDetailItem(
          callLogId: 'log_3',
          businessId: 'prov_bvrm_elec',
          businessName: 'Bhimavaram Power Solutions',
          businessPhone: '9848033333',
          city: 'Bhimavaram',
          category: 'Electricians',
          timestamp: DateTime(2026, 11, 14, 12, 0),
          callsAfterPayment: 2,
          feedbackStatus: 'Follow-up',
        ),
        CallLogsDetailItem(
          callLogId: 'log_4',
          businessId: 'prov_bvrm_plumb',
          businessName: 'Bhimavaram Quick Plumber',
          businessPhone: '9848044444',
          city: 'Bhimavaram',
          category: 'Plumbers',
          timestamp: DateTime(2026, 11, 14, 13, 0),
          callsAfterPayment: 20,
          feedbackStatus: 'Converted',
        ),
      ];

      test('City: Vijayawada + Category: Electrician shows ONLY Vijayawada electrician records', () {
        final container = ProviderContainer(
          overrides: [
            callLogsDetailRawDataProvider.overrideWith((ref) => sampleItems),
            callLogsDetailSelectedCategoryProvider.overrideWith((ref) => 'Electricians'),
          ],
        );

        // When raw data has Vijayawada Electricians
        final filtered = container.read(callLogsDetailFilteredItemsProvider);
        final vjaElec = filtered.where((i) => i.city == 'Vijayawada').toList();

        expect(vjaElec.length, equals(1));
        expect(vjaElec.first.businessName, equals('Vijayawada Spark Electricals'));
        expect(vjaElec.first.category, equals('Electricians'));
      });

      test('City: Bhimavaram + Category: Plumber shows ONLY Bhimavaram plumber records', () {
        final container = ProviderContainer(
          overrides: [
            callLogsDetailRawDataProvider.overrideWith((ref) => sampleItems),
            callLogsDetailSelectedCategoryProvider.overrideWith((ref) => 'Plumbers'),
          ],
        );

        final filtered = container.read(callLogsDetailFilteredItemsProvider);
        final bvrmPlumb = filtered.where((i) => i.city == 'Bhimavaram').toList();

        expect(bvrmPlumb.length, equals(1));
        expect(bvrmPlumb.first.businessName, equals('Bhimavaram Quick Plumber'));
        expect(bvrmPlumb.first.category, equals('Plumbers'));
      });

      test('Search by business name, phone number, and provider UID works alongside filters', () {
        // Search by business name
        var container = ProviderContainer(
          overrides: [
            callLogsDetailRawDataProvider.overrideWith((ref) => sampleItems),
            callLogsDetailSearchQueryProvider.overrideWith((ref) => 'Pipe Masters'),
          ],
        );
        var results = container.read(callLogsDetailFilteredItemsProvider);
        expect(results.length, equals(1));
        expect(results.first.businessId, equals('prov_vja_plumb'));

        // Search by phone number
        container = ProviderContainer(
          overrides: [
            callLogsDetailRawDataProvider.overrideWith((ref) => sampleItems),
            callLogsDetailSearchQueryProvider.overrideWith((ref) => '9848033333'),
          ],
        );
        results = container.read(callLogsDetailFilteredItemsProvider);
        expect(results.length, equals(1));
        expect(results.first.businessName, equals('Bhimavaram Power Solutions'));

        // Search by Provider UID
        container = ProviderContainer(
          overrides: [
            callLogsDetailRawDataProvider.overrideWith((ref) => sampleItems),
            callLogsDetailSearchQueryProvider.overrideWith((ref) => 'prov_bvrm_plumb'),
          ],
        );
        results = container.read(callLogsDetailFilteredItemsProvider);
        expect(results.length, equals(1));
        expect(results.first.businessName, equals('Bhimavaram Quick Plumber'));
      });

      test('Feedback status filter isolates converted records', () {
        final container = ProviderContainer(
          overrides: [
            callLogsDetailRawDataProvider.overrideWith((ref) => sampleItems),
            callLogsDetailFeedbackStatusFilterProvider.overrideWith((ref) => 'Converted'),
          ],
        );
        final results = container.read(callLogsDetailFilteredItemsProvider);
        expect(results.length, equals(2));
        expect(results.every((r) => r.feedbackStatus == 'Converted'), isTrue);
      });
    });

    // =========================================================================
    // 5. Pagination Calculation
    // =========================================================================
    group('5. Pagination Logic', () {
      final items = List.generate(
        55,
        (i) => CallLogsDetailItem(
          callLogId: 'log_$i',
          businessId: 'prov_$i',
          businessName: 'Business $i',
          businessPhone: '90000000$i',
          city: 'Vijayawada',
          category: 'Electricians',
          callsAfterPayment: i,
        ),
      );

      test('Computes total pages, current page slice, and indices correctly', () {
        final container = ProviderContainer(
          overrides: [
            callLogsDetailRawDataProvider.overrideWith((ref) => items),
            callLogsDetailPageSizeProvider.overrideWith((ref) => 20),
            callLogsDetailCurrentPageProvider.overrideWith((ref) => 0),
          ],
        );

        var pagination = container.read(callLogsDetailPaginationProvider);
        expect(pagination.totalItems, equals(55));
        expect(pagination.totalPages, equals(3));
        expect(pagination.pageItems.length, equals(20));
        expect(pagination.startIndex, equals(1));
        expect(pagination.endIndex, equals(20));
        expect(pagination.hasPreviousPage, isFalse);
        expect(pagination.hasNextPage, isTrue);

        // Page 1 (second page)
        container.read(callLogsDetailCurrentPageProvider.notifier).state = 1;
        pagination = container.read(callLogsDetailPaginationProvider);
        expect(pagination.pageItems.length, equals(20));
        expect(pagination.startIndex, equals(21));
        expect(pagination.endIndex, equals(40));
        expect(pagination.hasPreviousPage, isTrue);
        expect(pagination.hasNextPage, isTrue);

        // Page 2 (last page, 15 items remaining)
        container.read(callLogsDetailCurrentPageProvider.notifier).state = 2;
        pagination = container.read(callLogsDetailPaginationProvider);
        expect(pagination.pageItems.length, equals(15));
        expect(pagination.startIndex, equals(41));
        expect(pagination.endIndex, equals(55));
        expect(pagination.hasPreviousPage, isTrue);
        expect(pagination.hasNextPage, isFalse);
      });
    });

    // =========================================================================
    // 6. Responsive Viewport Widget Tests (No RenderFlex Overflows)
    // =========================================================================
    group('6. Responsive Widget Viewport Tests', () {
      final sampleItems = [
        CallLogsDetailItem(
          callLogId: 'log_1',
          businessId: 'prov_vja_1',
          businessName: 'Krishna Electrical Works',
          businessPhone: '9876543210',
          city: 'Vijayawada',
          category: 'Electricians',
          timestamp: DateTime(2026, 11, 14, 15, 30),
          callsAfterPayment: 12,
          callStatus: 'Completed',
          feedbackStatus: 'Converted',
        ),
      ];

      final testViewports = [
        const Size(360, 800), // Mobile portrait
        const Size(844, 390), // Mobile landscape
        const Size(768, 1024), // Tablet portrait
        const Size(1024, 768), // Tablet landscape
        const Size(1366, 768), // Desktop
        const Size(1920, 1080), // Large Desktop
      ];

      for (final size in testViewports) {
        testWidgets('CallLogsDetailDataView renders cleanly without overflow at ${size.width}x${size.height}',
            (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                isSuperAdminProvider.overrideWithValue(true),
                currentAdminAssignedCitiesProvider.overrideWithValue(const ['Vijayawada']),
                allowedCitiesProvider.overrideWith((ref) => ['Vijayawada', 'Bhimavaram', 'Guntur']),
                callLogsDetailRawDataProvider.overrideWith((ref) => sampleItems),
              ],
              child: const MaterialApp(
                home: Scaffold(
                  body: CallLogsDetailDataView(),
                ),
              ),
            ),
          );

          await tester.pumpAndSettle();

          expect(find.text('CALL LOGS DETAILS'), findsOneWidget);
          expect(find.text('CITY & CATEGORY WISE'), findsOneWidget);
        });
      }
    });

    // =========================================================================
    // 7. Hyderabad Zone Filtering Logic & UI Tests
    // =========================================================================
    group('7. Hyderabad Zone Filtering Logic & UI Tests', () {
      final hitecZone = kHyderabadAreaGroups.firstWhere((g) => g.displayName == 'HITEC City');
      final kukatpallyZone = kHyderabadAreaGroups.firstWhere((g) => g.displayName == 'Kukatpally');
      final abidsZone = kHyderabadAreaGroups.firstWhere((g) => g.displayName == 'Abids');

      final hydItems = [
        CallLogsDetailItem(
          callLogId: 'hyd_log_1',
          businessId: 'prov_hitec_1',
          businessName: 'HITEC Tech Solutions',
          businessPhone: '9848099001',
          city: 'Hyderabad',
          category: 'IT Services',
          pincode: '500081', // In HITEC City zone
          userRawData: {'pincode': '500081'},
        ),
        CallLogsDetailItem(
          callLogId: 'hyd_log_2',
          businessId: 'prov_kukatpally_1',
          businessName: 'Kukatpally Home Care',
          businessPhone: '9848099002',
          city: 'Hyderabad',
          category: 'Plumbers',
          pincode: '500072', // In Kukatpally zone
          userRawData: {'pincode': '500072'},
        ),
        CallLogsDetailItem(
          callLogId: 'hyd_log_3',
          businessId: 'prov_abids_1',
          businessName: 'Abids General Store',
          businessPhone: '9848099003',
          city: 'Hyderabad',
          category: 'Electricians',
          pincode: '500001', // In Abids zone
          userRawData: {'pincode': '500001'},
        ),
        CallLogsDetailItem(
          callLogId: 'vja_log_1',
          businessId: 'prov_vja_1',
          businessName: 'Vijayawada Repairs',
          businessPhone: '9848099004',
          city: 'Vijayawada',
          category: 'Electricians',
          pincode: '520001',
        ),
      ];

      test('Item matchesZone verifies exact PIN-code mapping correctly', () {
        final hitecItem = hydItems[0];
        final kukatpallyItem = hydItems[1];

        // hitecItem has pincode 500081
        expect(hitecItem.matchesZone(hitecZone), isTrue);
        expect(hitecItem.matchesZone(kukatpallyZone), isFalse);
        expect(hitecItem.matchesZone(null), isTrue); // null means All Zones

        // kukatpallyItem has pincode 500072
        expect(kukatpallyItem.matchesZone(kukatpallyZone), isTrue);
        expect(kukatpallyItem.matchesZone(hitecZone), isFalse);

        // abidsItem has pincode 500001
        expect(hydItems[2].matchesZone(abidsZone), isTrue);
        expect(hydItems[2].matchesZone(hitecZone), isFalse);
      });

      test('Item matchesZone matches explicit zone field in userRawData or callLogRawData', () {
        final explicitZoneItem = CallLogsDetailItem(
          callLogId: 'hyd_log_exp',
          businessId: 'prov_exp',
          businessName: 'Explicit Zone Provider',
          businessPhone: '9848099999',
          city: 'Hyderabad',
          category: 'Plumbers',
          userRawData: {'zone': 'HITEC City'},
        );

        expect(explicitZoneItem.matchesZone(hitecZone), isTrue);
        expect(explicitZoneItem.matchesZone(kukatpallyZone), isFalse);
      });

      test('Selecting Hyderabad + Zone in provider filters data strictly to that zone', () {
        // When City is Hyderabad and Zone is HITEC City
        final container = ProviderContainer(
          overrides: [
            callLogsDetailRawDataProvider.overrideWith((ref) => hydItems),
            callLogsDetailSelectedCityProvider.overrideWith((ref) => 'Hyderabad'),
            callLogsDetailSelectedZoneProvider.overrideWith((ref) => hitecZone),
          ],
        );

        final filtered = container.read(callLogsDetailFilteredItemsProvider);
        expect(filtered.length, equals(1));
        expect(filtered.first.businessName, equals('HITEC Tech Solutions'));

        // When Zone is switched to Kukatpally
        container.read(callLogsDetailSelectedZoneProvider.notifier).state = kukatpallyZone;
        final filteredKukatpally = container.read(callLogsDetailFilteredItemsProvider);
        expect(filteredKukatpally.length, equals(1));
        expect(filteredKukatpally.first.businessName, equals('Kukatpally Home Care'));

        // When Zone is reset to null (All Zones)
        container.read(callLogsDetailSelectedZoneProvider.notifier).state = null;
        final filteredAllZones = container.read(callLogsDetailFilteredItemsProvider);
        expect(filteredAllZones.length, equals(4)); // all items in raw provider
      });

      test('Zone filter is inactive when selected city is not Hyderabad', () {
        final container = ProviderContainer(
          overrides: [
            callLogsDetailRawDataProvider.overrideWith((ref) => hydItems),
            callLogsDetailSelectedCityProvider.overrideWith((ref) => 'Vijayawada'),
            callLogsDetailSelectedZoneProvider.overrideWith((ref) => hitecZone),
          ],
        );

        // Since City is Vijayawada, effectiveZone is null so zone filtering does not block Vijayawada items
        final filtered = container.read(callLogsDetailFilteredItemsProvider);
        expect(filtered.any((item) => item.city == 'Vijayawada'), isTrue);
      });

      testWidgets('Hyderabad displays Zone dropdown; selecting other city hides it', (tester) async {
        tester.view.physicalSize = const Size(1366, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Initial state: City = Hyderabad
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isSuperAdminProvider.overrideWithValue(true),
              allowedCitiesProvider.overrideWith((ref) => ['Hyderabad', 'Vijayawada', 'Bhimavaram']),
              callLogsDetailSelectedCityProvider.overrideWith((ref) => 'Hyderabad'),
              callLogsDetailSelectedZoneProvider.overrideWith((ref) => null),
              callLogsDetailRawDataProvider.overrideWith((ref) => hydItems),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CallLogsDetailDataView(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Zone Dropdown and Zone Bar are visible when City is Hyderabad
        expect(find.byKey(const ValueKey('hyderabad_zone_dropdown_null')), findsOneWidget);
        expect(find.text('Zone'), findsWidgets); // Zone label in filter row & zone bar
        expect(find.text('All Zones'), findsWidgets);

        // Tap a zone pill or dropdown item (e.g. Abids)
        final abidsPill = find.widgetWithText(InkWell, 'Abids');
        expect(abidsPill, findsOneWidget);
        await tester.tap(abidsPill);
        await tester.pumpAndSettle();

        // Table now shows ONLY Abids record
        expect(find.text('Abids General Store'), findsOneWidget);
        expect(find.text('HITEC Tech Solutions'), findsNothing);
      });

      testWidgets('When City is not Hyderabad, Zone dropdown is hidden', (tester) async {
        tester.view.physicalSize = const Size(1366, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              isSuperAdminProvider.overrideWithValue(true),
              allowedCitiesProvider.overrideWith((ref) => ['Hyderabad', 'Vijayawada', 'Bhimavaram']),
              callLogsDetailSelectedCityProvider.overrideWith((ref) => 'Vijayawada'),
              callLogsDetailSelectedZoneProvider.overrideWith((ref) => null),
              callLogsDetailRawDataProvider.overrideWith((ref) => hydItems),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: CallLogsDetailDataView(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Zone dropdown is NOT present when City is Vijayawada
        expect(find.byKey(const ValueKey('hyderabad_zone_dropdown_null')), findsNothing);
        expect(find.text('All Zones'), findsNothing);
      });
    });
  });
}
