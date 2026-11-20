import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skazo_admin/constants/hyderabad_area_groups.dart';
import 'package:skazo_admin/models/page_result.dart';
import 'package:skazo_admin/models/service_provider_overview_model.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/service_providers_provider.dart';
import 'package:skazo_admin/repositories/user_repository.dart';
import 'package:skazo_admin/widgets/service_providers_data_view.dart';

class _FakeUserRepository extends Fake implements UserRepository {
  final Map<String, ServiceProvidersOverviewData> cityData;
  final Map<String, ServiceProvidersOverviewData> zoneData;

  _FakeUserRepository(this.cityData, [this.zoneData = const {}]);

  @override
  Future<ServiceProvidersOverviewData> fetchServiceProvidersOverviewStats({
    String? selectedCity,
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
    Map<String, List<String>> pincodesMap = const {},
    List<String>? zonePincodes,
  }) async {
    if (zonePincodes != null && zonePincodes.isNotEmpty) {
      final key = zonePincodes.join(',');
      if (zoneData.containsKey(key)) {
        return zoneData[key]!;
      }
    }
    if (selectedCity != null && cityData.containsKey(selectedCity)) {
      return cityData[selectedCity]!;
    }
    return ServiceProvidersOverviewData.empty(
      selectedCity: selectedCity,
      selectedDate: DateTime.now(),
    );
  }

  @override
  Future<PageResult<UserModel>> fetchCategoryServiceProvidersPage({
    required String category,
    List<String>? areaPincodes,
    String? selectedCity,
    String searchQuery = '',
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
    Map<String, List<String>> pincodesMap = const {},
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 10,
  }) async {
    return const PageResult(
      items: [],
      hasMore: false,
    );
  }

  @override
  Future<int> countCategoryServiceProviders({
    required String category,
    List<String>? areaPincodes,
    String? selectedCity,
    String searchQuery = '',
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    return 0;
  }
}

void main() {
  group('EmptySlotCategoryItem Model Tests', () {
    test('Correctly computes slot availability and vacancy flag', () {
      const itemVacant = EmptySlotCategoryItem(
        categoryName: 'Electricians',
        occupiedSlots: 1,
        totalSlots: 4,
        availableSlots: 3,
      );
      expect(itemVacant.categoryName, 'Electricians');
      expect(itemVacant.occupiedSlots, 1);
      expect(itemVacant.totalSlots, 4);
      expect(itemVacant.availableSlots, 3);
      expect(itemVacant.hasVacantSlots, isTrue);

      const itemFull = EmptySlotCategoryItem(
        categoryName: 'Plumbers',
        occupiedSlots: 4,
        totalSlots: 4,
        availableSlots: 0,
      );
      expect(itemFull.availableSlots, 0);
      expect(itemFull.hasVacantSlots, isFalse);
    });
  });

  group('Empty Slots Business Logic & Provider Tests', () {
    final hyderabadOverview = ServiceProvidersOverviewData(
      selectedCity: 'Hyderabad',
      selectedDate: DateTime(2026, 11, 16),
      totalProviders: 10,
      totalCategories: 4,
      categories: const [
        ServiceProviderCategoryStats(
          categoryName: 'Electricians',
          totalCount: 3, // 4 - 3 = 1 available slot
        ),
        ServiceProviderCategoryStats(
          categoryName: 'Plumbers',
          totalCount: 4, // 4 - 4 = 0 available slots -> MUST BE EXCLUDED!
        ),
        ServiceProviderCategoryStats(
          categoryName: 'AC Repair',
          totalCount: 2, // 4 - 2 = 2 available slots
        ),
        ServiceProviderCategoryStats(
          categoryName: 'Painters',
          totalCount: 1, // 4 - 1 = 3 available slots
        ),
      ],
    );

    final fakeRepo = _FakeUserRepository({
      'Hyderabad': hyderabadOverview,
    });

    final superAdminScope = CityAccessScope.authorized(
      isSuperAdmin: true,
      adminId: 'super_admin_1',
      email: 'admin@skazo.test',
    );

    test('Computes 4 - occupied slots and STRICTLY excludes categories with 0 available slots', () async {
      final container = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWithValue(fakeRepo),
          cityAccessScopeProvider.overrideWithValue(superAdminScope),
          emptySlotsSelectedCityProvider.overrideWith((ref) => 'Hyderabad'),
          propertyPincodesProvider.overrideWith((ref) async => const {'Hyderabad': ['500001']}),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(emptySlotsDataProvider.future);

      // Check Plumbers (4 occupied = 0 available) is EXCLUDED
      final plumberItem = items.where((i) => i.categoryName == 'Plumbers').firstOrNull;
      expect(plumberItem, isNull, reason: 'Categories with 0 available slots must be excluded');

      // Check Electricians (3 occupied = 1 available)
      final electricianItem = items.firstWhere((i) => i.categoryName == 'Electricians');
      expect(electricianItem.occupiedSlots, 3);
      expect(electricianItem.availableSlots, 1);
      expect(electricianItem.totalSlots, 4);

      // Check AC Repair (2 occupied = 2 available)
      final acItem = items.firstWhere((i) => i.categoryName == 'AC Repair');
      expect(acItem.occupiedSlots, 2);
      expect(acItem.availableSlots, 2);

      // Check Painters (1 occupied = 3 available)
      final painterItem = items.firstWhere((i) => i.categoryName == 'Painters');
      expect(painterItem.occupiedSlots, 1);
      expect(painterItem.availableSlots, 3);

      // Check a category from canonical kBusinessCategories with 0 providers has 4 available slots
      final woodWorksItem = items.firstWhere((i) => i.categoryName == 'Wood Works');
      expect(woodWorksItem.occupiedSlots, 0);
      expect(woodWorksItem.availableSlots, 4);

      // Verify sorting: highest available slots first
      for (int i = 0; i < items.length - 1; i++) {
        expect(
          items[i].availableSlots >= items[i + 1].availableSlots,
          isTrue,
          reason: 'Items should be sorted by availableSlots descending',
        );
      }
    });

    test('Returns empty list when selectedCity is null or All Cities', () async {
      final container = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWithValue(fakeRepo),
          cityAccessScopeProvider.overrideWithValue(superAdminScope),
          emptySlotsSelectedCityProvider.overrideWith((ref) => null),
          propertyPincodesProvider.overrideWith((ref) async => const {'Hyderabad': ['500001']}),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(emptySlotsDataProvider.future);
      expect(items, isEmpty);
    });

    test('Restricts city access for individual City Admins', () async {
      final vijayawadaScope = CityAccessScope.authorized(
        isSuperAdmin: false,
        adminId: 'vja_admin_1',
        email: 'vja@skazo.test',
        assignedCities: const ['Vijayawada'],
      );

      // Vijayawada admin trying to view Hyderabad -> blocked / returns empty
      final container = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWithValue(fakeRepo),
          cityAccessScopeProvider.overrideWithValue(vijayawadaScope),
          emptySlotsSelectedCityProvider.overrideWith((ref) => 'Hyderabad'),
          propertyPincodesProvider.overrideWith((ref) async => const {'Hyderabad': ['500001']}),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(emptySlotsDataProvider.future);
      expect(items, isEmpty, reason: 'Vijayawada admin must not access Hyderabad slots');
    });

    test('In-memory category search filtering works correctly', () async {
      final container = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWithValue(fakeRepo),
          cityAccessScopeProvider.overrideWithValue(superAdminScope),
          emptySlotsSelectedCityProvider.overrideWith((ref) => 'Hyderabad'),
          propertyPincodesProvider.overrideWith((ref) async => const {'Hyderabad': ['500001']}),
          emptySlotsCategorySearchProvider.overrideWith((ref) => 'Electric'),
        ],
      );
      addTearDown(container.dispose);

      // Wait for future provider
      await container.read(emptySlotsDataProvider.future);
      final filtered = container.read(emptySlotsFilteredCategoriesProvider);

      expect(filtered.length, 1);
      expect(filtered.first.categoryName, 'Electricians');
    });

    test('Hyderabad zone selection passes zone pincodes to repository and recalculates available slots', () async {
      final jubileeZone = kHyderabadAreaGroups.firstWhere((z) => z.displayName == 'Jubilee Hills');
      final jubileeKey = jubileeZone.pincodes.join(',');

      final jubileeOverview = ServiceProvidersOverviewData(
        selectedCity: 'Hyderabad',
        selectedDate: DateTime(2026, 11, 16),
        totalProviders: 1,
        totalCategories: 1,
        categories: const [
          ServiceProviderCategoryStats(
            categoryName: 'Electricians',
            totalCount: 1, // 4 - 1 = 3 available in Jubilee Hills
          ),
        ],
      );

      final repoWithZone = _FakeUserRepository(
        {'Hyderabad': hyderabadOverview},
        {jubileeKey: jubileeOverview},
      );

      final container = ProviderContainer(
        overrides: [
          userRepositoryProvider.overrideWithValue(repoWithZone),
          cityAccessScopeProvider.overrideWithValue(superAdminScope),
          emptySlotsSelectedCityProvider.overrideWith((ref) => 'Hyderabad'),
          emptySlotsSelectedZoneProvider.overrideWith((ref) => jubileeZone),
          propertyPincodesProvider.overrideWith((ref) async => const {'Hyderabad': ['500001']}),
        ],
      );
      addTearDown(container.dispose);

      final items = await container.read(emptySlotsDataProvider.future);
      final electricianItem = items.firstWhere((i) => i.categoryName == 'Electricians');
      // In Hyderabad overall, it was 3 occupied (1 available). But in Jubilee Hills zone, it is 1 occupied (3 available)!
      expect(electricianItem.occupiedSlots, 1);
      expect(electricianItem.availableSlots, 3);
    });
  });

  group('Star Service Providers Tab Switching & Empty Slots UI Widget Tests', () {
    final hyderabadOverview = ServiceProvidersOverviewData(
      selectedCity: 'Hyderabad',
      selectedDate: DateTime(2026, 11, 16),
      totalProviders: 10,
      totalCategories: 4,
      categories: const [
        ServiceProviderCategoryStats(categoryName: 'Electricians', totalCount: 3),
        ServiceProviderCategoryStats(categoryName: 'Plumbers', totalCount: 4), // full
        ServiceProviderCategoryStats(categoryName: 'AC Repair', totalCount: 2),
        ServiceProviderCategoryStats(categoryName: 'Painters', totalCount: 1),
      ],
    );

    final fakeRepo = _FakeUserRepository({
      'Hyderabad': hyderabadOverview,
    });

    final superAdminScope = CityAccessScope.authorized(
      isSuperAdmin: true,
      adminId: 'super_admin_1',
      email: 'admin@skazo.test',
    );

    Widget createTestWidget({
      StarServiceProvidersTab initialTab = StarServiceProvidersTab.starProviders,
      String? initialCity,
    }) {
      return ProviderScope(
        overrides: [
          userRepositoryProvider.overrideWithValue(fakeRepo),
          cityAccessScopeProvider.overrideWithValue(superAdminScope),
          isSuperAdminProvider.overrideWithValue(true),
          currentAdminAssignedCitiesProvider.overrideWithValue(const []),
          allowedCitiesProvider.overrideWith((ref) async => ['Hyderabad', 'Vijayawada', 'Guntur']),
          propertyPincodesProvider.overrideWith((ref) async => const {'Hyderabad': ['500001']}),
          starServiceProvidersActiveTabProvider.overrideWith((ref) => initialTab),
          emptySlotsSelectedCityProvider.overrideWith((ref) => initialCity),
          serviceProvidersOverviewProvider.overrideWith((ref) async => hyderabadOverview),
        ],
        child: const MaterialApp(
          home: ServiceProvidersDataView(),
        ),
      );
    }

    testWidgets('Tab switcher renders both tabs and switches to Empty Slots view', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Check tab switcher is present
      expect(find.byKey(const ValueKey('star_service_providers_tab_switcher')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_star_providers')), findsOneWidget);
      expect(find.byKey(const ValueKey('tab_empty_slots')), findsOneWidget);

      // Click Empty Slots tab
      await tester.tap(find.byKey(const ValueKey('tab_empty_slots')));
      await tester.pumpAndSettle();

      // Should now render _EmptySlotsView
      expect(find.byKey(const ValueKey('empty_slots_view')), findsOneWidget);
    });

    testWidgets('Empty Slots displays prompt when no city is selected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      await tester.pumpWidget(createTestWidget(
        initialTab: StarServiceProvidersTab.emptySlots,
        initialCity: null,
      ));
      await tester.pumpAndSettle();

      // Expect city prompt
      expect(find.text('Please select a city'), findsOneWidget);
    });

    testWidgets('Empty Slots displays category cards grid and horizontal quick bar when city is selected', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 3000));
      await tester.pumpWidget(createTestWidget(
        initialTab: StarServiceProvidersTab.emptySlots,
        initialCity: 'Hyderabad',
      ));
      await tester.pumpAndSettle();

      // Verify Plumbers (4 occupied, 0 available) is NOT displayed
      expect(find.text('Plumbers'), findsNothing, reason: 'Plumbers has 0 available slots and must be excluded');

      // Verify Horizontal Category Quick Bar pills are present
      expect(find.textContaining('All ('), findsOneWidget);
      expect(find.textContaining('Electricians ('), findsOneWidget);
      expect(find.textContaining('AC Repair ('), findsOneWidget);
      expect(find.textContaining('Painters ('), findsOneWidget);

      // Verify Category Overview Cards are rendered in the Chess Grid
      expect(find.byKey(const ValueKey('empty_slot_card_Electricians')), findsOneWidget);
      expect(find.byKey(const ValueKey('empty_slot_card_AC Repair')), findsOneWidget);
      expect(find.byKey(const ValueKey('empty_slot_card_Painters')), findsOneWidget);

      // Verify slots available badges and View Providers text on cards
      expect(find.text('1'), findsWidgets);
      expect(find.text('Slot Available'), findsWidgets);
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);
      expect(find.text('Slots Available'), findsWidgets);
      expect(find.text('View Providers'), findsWidgets);

      // Verify clicking a category card drills down to Star Providers tab
      await tester.tap(find.byKey(const ValueKey('empty_slot_card_Electricians')));
      await tester.pumpAndSettle();

      // Should have switched back to Star Providers tab (empty_slots_view gone)
      expect(find.byKey(const ValueKey('empty_slots_view')), findsNothing);
    });

    testWidgets('Empty Slots horizontal bar and view mode toggle work correctly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      await tester.pumpWidget(createTestWidget(
        initialTab: StarServiceProvidersTab.emptySlots,
        initialCity: 'Hyderabad',
      ));
      await tester.pumpAndSettle();

      // Toggle to Table View
      expect(find.byKey(const ValueKey('empty_slots_view_mode_table')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('empty_slots_view_mode_table')));
      await tester.pumpAndSettle();

      // DataTable should now be rendered
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('1 Available'), findsOneWidget);

      // Toggle back to Grid View
      expect(find.byKey(const ValueKey('empty_slots_view_mode_grid')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('empty_slots_view_mode_grid')));
      await tester.pumpAndSettle();

      // Cards should be rendered again
      expect(find.byKey(const ValueKey('empty_slot_card_Electricians')), findsOneWidget);
    });

    testWidgets('Hyderabad zone filter bar renders in Empty Slots and selecting zone updates header', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 3000));
      await tester.pumpWidget(createTestWidget(
        initialTab: StarServiceProvidersTab.emptySlots,
        initialCity: 'Hyderabad',
      ));
      await tester.pumpAndSettle();

      // Check Zone filter bar is present
      expect(find.text('Zone'), findsOneWidget);
      expect(find.text('All Zones'), findsOneWidget);

      // Verify Hyderabad zones are displayed
      expect(find.text('Abids'), findsOneWidget);
      expect(find.text('Old City'), findsOneWidget);
      expect(find.text('Kukatpally'), findsOneWidget);

      // Select Abids
      await tester.tap(find.text('Abids'));
      await tester.pumpAndSettle();

      // Subtitle should show Abids
      expect(find.textContaining('(Abids)'), findsOneWidget);
    });

    testWidgets('Non-Hyderabad city hides the zone filter bar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      await tester.pumpWidget(createTestWidget(
        initialTab: StarServiceProvidersTab.emptySlots,
        initialCity: 'Vijayawada',
      ));
      await tester.pumpAndSettle();

      // Zone filter bar should NOT be rendered
      expect(find.text('Zone'), findsNothing);
      expect(find.text('All Zones'), findsNothing);
    });

    testWidgets('Cities bar in Empty Slots is horizontally scrollable with Scrollbar', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 1200));
      await tester.pumpWidget(createTestWidget(
        initialTab: StarServiceProvidersTab.emptySlots,
        initialCity: 'Hyderabad',
      ));
      await tester.pumpAndSettle();

      // Verify Scrollbars are present
      expect(find.byType(Scrollbar), findsWidgets);

      // Verify city pills are rendered
      expect(find.text('Hyderabad'), findsWidgets);
      expect(find.text('Vijayawada'), findsWidgets);
      expect(find.text('Guntur'), findsWidgets);
    });
  });
}
