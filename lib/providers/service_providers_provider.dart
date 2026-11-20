import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/constants/business_categories.dart';
import 'package:skazo_admin/constants/hyderabad_area_groups.dart';
import 'package:skazo_admin/models/service_provider_overview_model.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/repositories/user_repository.dart';

/// Active tab within the Star Service Providers entity
enum StarServiceProvidersTab {
  starProviders,
  emptySlots,
}

/// Provider managing active tab selection in Star Service Providers
final starServiceProvidersActiveTabProvider =
    StateProvider<StarServiceProvidersTab>((ref) => StarServiceProvidersTab.starProviders);

/// Currently selected city for the Empty Slots tab.
final emptySlotsSelectedCityProvider = StateProvider<String?>((ref) => null);

/// Search filter for category names in the Empty Slots tab.
final emptySlotsCategorySearchProvider = StateProvider<String>((ref) => '');

/// Selected category in the horizontal quick bar for Empty Slots.
/// `null` represents 'All' (shows all vacant categories).
final emptySlotsSelectedCategoryFilterProvider = StateProvider<String?>((ref) => null);

/// Selected Hyderabad zone for the Empty Slots tab.
/// `null` means "All Zones" — include all Hyderabad providers.
/// Only relevant when emptySlotsSelectedCity == 'Hyderabad'.
final emptySlotsSelectedZoneProvider =
    StateProvider<ServiceProviderAreaGroup?>((ref) => null);

/// Maximum allowed Star Service Providers per city-category combination
const int kMaxStarProvidersPerCategory = 4;

/// Currently selected city for Service Providers feature.
/// `null` represents "All Cities" for Super Admin or auto-resolved first city.
final serviceProvidersSelectedCityProvider = StateProvider<String?>((ref) => null);

/// Currently selected date for Service Providers feature.
/// Defaults to current day in local/IST time (midnight).
final serviceProvidersSelectedDateProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
});

/// Selected category or area in the horizontal quick bar for filtering/focusing overview grid.
/// `null` represents 'All' (shows all categories or all areas).
final serviceProvidersHorizontalFilterProvider = StateProvider<String?>((ref) => null);

/// Category selected for drilldown into the dedicated Category Provider List page.
/// `null` renders the Service Providers Overview page.
/// Non-null string (e.g. "Cleaning") renders the Category Provider List page.
final serviceProvidersDrilldownCategoryProvider = StateProvider<String?>((ref) => null);

/// Hyderabad Area Group selected for drilldown into the dedicated Area Provider List page.
/// `null` when not drilled down into a Hyderabad area.
final serviceProvidersDrilldownAreaGroupProvider =
    StateProvider<ServiceProviderAreaGroup?>((ref) => null);

/// Selected Hyderabad zone for filtering providers before category aggregation.
/// `null` means "All Zones" — include all Hyderabad providers.
/// Only relevant when selectedCity == 'Hyderabad'.
final serviceProvidersSelectedZoneProvider =
    StateProvider<ServiceProviderAreaGroup?>((ref) => null);

/// Search query on the Category Provider List page.
final serviceProvidersCategorySearchQueryProvider = StateProvider<String>((ref) => '');

/// FutureProvider computing lightweight category overview statistics for Star Service Providers.
final serviceProvidersOverviewProvider = FutureProvider<ServiceProvidersOverviewData>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  final selectedCity = ref.watch(serviceProvidersSelectedCityProvider);
  final selectedZone = ref.watch(serviceProvidersSelectedZoneProvider);
  final scope = ref.watch(cityAccessScopeProvider);
  if (!scope.isAuthorized) {
    return ServiceProvidersOverviewData.empty(
      selectedCity: selectedCity,
      selectedDate: DateTime.now(),
    );
  }
  final pincodesMap = await ref.watch(propertyPincodesProvider.future);

  return repository.fetchServiceProvidersOverviewStats(
    selectedCity: selectedCity,
    assignedCities: scope.assignedCities,
    isSuperAdmin: scope.isUnrestricted,
    pincodesMap: pincodesMap,
    zonePincodes: selectedZone?.pincodes,
  );
});

/// FutureProvider computing categories and available empty slots for a selected city.
/// Each city-category combination has a maximum of 4 Star Service Providers.
/// Available Slots = 4 - eligible existing Star Service Providers count.
/// Strictly filters to only display categories with available slots > 0.
final emptySlotsDataProvider = FutureProvider<List<EmptySlotCategoryItem>>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  final scope = ref.watch(cityAccessScopeProvider);
  if (!scope.isAuthorized) {
    return const [];
  }

  final selectedCity = ref.watch(emptySlotsSelectedCityProvider);
  final selectedZone = ref.watch(emptySlotsSelectedZoneProvider);
  if (selectedCity == null ||
      selectedCity.trim().isEmpty ||
      selectedCity == 'All' ||
      selectedCity == 'All Cities') {
    return const [];
  }

  // City-wise access security verification
  if (!scope.isUnrestricted && !scope.canAccessCityName(selectedCity)) {
    return const [];
  }

  final pincodesMap = await ref.watch(propertyPincodesProvider.future);

  final overviewData = await repository.fetchServiceProvidersOverviewStats(
    selectedCity: selectedCity,
    assignedCities: scope.assignedCities,
    isSuperAdmin: scope.isUnrestricted,
    pincodesMap: pincodesMap,
    zonePincodes: isCityHyderabad(selectedCity) ? selectedZone?.pincodes : null,
  );

  final existingCountMap = <String, int>{};
  for (final cat in overviewData.categories) {
    final name = cat.categoryName.trim();
    if (name.isNotEmpty && name != 'Uncategorized') {
      existingCountMap[name] = cat.totalCount;
    }
  }

  final allCategories = <String>{
    ...kBusinessCategories,
    ...existingCountMap.keys,
  }.toList()..sort();

  final List<EmptySlotCategoryItem> items = [];

  for (final category in allCategories) {
    final occupied = existingCountMap[category] ?? 0;
    final available = kMaxStarProvidersPerCategory - occupied;

    // Strict Rule: Only display categories with available slots greater than 0
    if (available > 0) {
      items.add(EmptySlotCategoryItem(
        categoryName: category,
        occupiedSlots: occupied,
        totalSlots: kMaxStarProvidersPerCategory,
        availableSlots: available,
      ));
    }
  }

  // Sort by available slots descending (highest vacancy first), then alphabetically by category
  items.sort((a, b) {
    final cmp = b.availableSlots.compareTo(a.availableSlots);
    if (cmp != 0) return cmp;
    return a.categoryName.compareTo(b.categoryName);
  });

  return items;
});

/// Filtered categories by horizontal category selection and search query in Empty Slots tab
final emptySlotsFilteredCategoriesProvider = Provider<List<EmptySlotCategoryItem>>((ref) {
  final rawAsync = ref.watch(emptySlotsDataProvider);
  final items = rawAsync.value ?? const [];
  final selectedCategory = ref.watch(emptySlotsSelectedCategoryFilterProvider);
  final query = ref.watch(emptySlotsCategorySearchProvider).trim().toLowerCase();

  var result = items;
  if (selectedCategory != null && selectedCategory.isNotEmpty) {
    result = result.where((item) => item.categoryName == selectedCategory).toList();
  }
  if (query.isNotEmpty) {
    result = result.where((item) {
      return item.categoryName.toLowerCase().contains(query);
    }).toList();
  }

  return result;
});

/// State for the server-side paginated category provider list.
class CategoryProvidersPaginationState {
  final List<UserModel> providers;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final int? totalCount;
  final String searchQuery;

  const CategoryProvidersPaginationState({
    this.providers = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.hasMore = true,
    this.lastDocument,
    this.totalCount,
    this.searchQuery = '',
  });

  factory CategoryProvidersPaginationState.initial() =>
      const CategoryProvidersPaginationState(loading: true);

  CategoryProvidersPaginationState copyWith({
    List<UserModel>? providers,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    int? totalCount,
    String? searchQuery,
    bool clearLastDocument = false,
    bool clearError = false,
  }) {
    return CategoryProvidersPaginationState(
      providers: providers ?? this.providers,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      lastDocument: clearLastDocument ? null : (lastDocument ?? this.lastDocument),
      totalCount: totalCount ?? this.totalCount,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

/// Server-side cursor pagination notifier for category-specific providers.
class CategoryProvidersPaginationNotifier
    extends FamilyNotifier<CategoryProvidersPaginationState, String> {
  Timer? _searchDebounce;

  @override
  CategoryProvidersPaginationState build(String category) {
    ref.onDispose(() {
      _searchDebounce?.cancel();
    });

    ref.listen(serviceProvidersSelectedCityProvider, (_, __) => refresh());
    ref.listen(serviceProvidersSelectedZoneProvider, (_, __) => refresh());
    ref.listen(cityAccessScopeProvider, (_, __) => refresh());
    ref.listen(serviceProvidersCategorySearchQueryProvider, (_, query) {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), refresh);
    });

    Future.microtask(refresh);
    return CategoryProvidersPaginationState.initial();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      loading: true,
      loadingMore: false,
      providers: const [],
      clearLastDocument: true,
      clearError: true,
      hasMore: true,
    );
    await Future.wait([
      _fetchPage(isRefresh: true),
      _loadCount(),
    ]);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true, clearError: true);
    await _fetchPage(isRefresh: false);
  }

  Future<void> _loadCount() async {
    final repository = ref.read(userRepositoryProvider);
    final category = arg;
    final selectedCity = ref.read(serviceProvidersSelectedCityProvider);
    final selectedZone = ref.read(serviceProvidersSelectedZoneProvider);
    final searchQuery = ref.read(serviceProvidersCategorySearchQueryProvider);
    final scope = ref.read(cityAccessScopeProvider);
    if (!scope.isAuthorized) {
      state = state.copyWith(totalCount: 0);
      return;
    }

    try {
      final count = await repository.countCategoryServiceProviders(
        category: category,
        areaPincodes: selectedZone?.pincodes,
        selectedCity: selectedCity,
        searchQuery: searchQuery,
        assignedCities: scope.assignedCities,
        isSuperAdmin: scope.isUnrestricted,
      );
      state = state.copyWith(totalCount: count);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CategoryProvidersPaginationNotifier count error: $e');
      }
    }
  }

  Future<void> _fetchPage({required bool isRefresh}) async {
    final repository = ref.read(userRepositoryProvider);
    final category = arg;
    final selectedCity = ref.read(serviceProvidersSelectedCityProvider);
    final selectedZone = ref.read(serviceProvidersSelectedZoneProvider);
    final searchQuery = ref.read(serviceProvidersCategorySearchQueryProvider);
    final scope = ref.read(cityAccessScopeProvider);
    if (!scope.isAuthorized) {
      state = state.copyWith(
        providers: const [],
        loading: false,
        loadingMore: false,
        hasMore: false,
        clearLastDocument: true,
        clearError: true,
      );
      return;
    }

    try {
      final pincodesMap = await ref.read(propertyPincodesProvider.future);
      final result = await repository.fetchCategoryServiceProvidersPage(
        category: category,
        areaPincodes: selectedZone?.pincodes,
        selectedCity: selectedCity,
        searchQuery: searchQuery,
        assignedCities: scope.assignedCities,
        isSuperAdmin: scope.isUnrestricted,
        pincodesMap: pincodesMap,
        startAfter: isRefresh ? null : state.lastDocument,
        limit: 20,
      );

      final updatedProviders = isRefresh
          ? result.items
          : [...state.providers, ...result.items];

      state = state.copyWith(
        providers: updatedProviders,
        loading: false,
        loadingMore: false,
        hasMore: result.hasMore,
        lastDocument: result.lastDocument,
        searchQuery: searchQuery,
        clearError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CategoryProvidersPaginationNotifier fetch error: $e');
      }
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: e.toString(),
      );
    }
  }
}

final categoryProvidersPaginationProvider = NotifierProvider.family<
    CategoryProvidersPaginationNotifier,
    CategoryProvidersPaginationState,
    String>(CategoryProvidersPaginationNotifier.new);

/// Server-side cursor pagination notifier for Hyderabad area-specific providers.
class AreaProvidersPaginationNotifier
    extends FamilyNotifier<CategoryProvidersPaginationState, String> {
  Timer? _searchDebounce;

  @override
  CategoryProvidersPaginationState build(String areaDisplayName) {
    ref.onDispose(() {
      _searchDebounce?.cancel();
    });

    ref.listen(cityAccessScopeProvider, (_, __) => refresh());
    ref.listen(serviceProvidersCategorySearchQueryProvider, (_, query) {
      _searchDebounce?.cancel();
      _searchDebounce = Timer(const Duration(milliseconds: 300), refresh);
    });

    Future.microtask(refresh);
    return CategoryProvidersPaginationState.initial();
  }

  Future<void> refresh() async {
    state = state.copyWith(
      loading: true,
      loadingMore: false,
      providers: const [],
      clearLastDocument: true,
      clearError: true,
      hasMore: true,
    );
    await Future.wait([
      _fetchPage(isRefresh: true),
      _loadCount(),
    ]);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true, clearError: true);
    await _fetchPage(isRefresh: false);
  }

  List<String> get _areaPincodes {
    final areaDisplayName = arg;
    final group = kHyderabadAreaGroups.firstWhere(
      (g) => g.displayName.toLowerCase() == areaDisplayName.toLowerCase(),
      orElse: () => ServiceProviderAreaGroup(
        displayName: areaDisplayName,
        pincodes: const [],
      ),
    );
    return group.pincodes;
  }

  Future<void> _loadCount() async {
    final repository = ref.read(userRepositoryProvider);
    final selectedCity = ref.read(serviceProvidersSelectedCityProvider);
    final searchQuery = ref.read(serviceProvidersCategorySearchQueryProvider);
    final scope = ref.read(cityAccessScopeProvider);
    if (!scope.isAuthorized) {
      state = state.copyWith(totalCount: 0);
      return;
    }

    try {
      final count = await repository.countCategoryServiceProviders(
        category: '',
        areaPincodes: _areaPincodes,
        selectedCity: selectedCity,
        searchQuery: searchQuery,
        assignedCities: scope.assignedCities,
        isSuperAdmin: scope.isUnrestricted,
      );
      state = state.copyWith(totalCount: count);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AreaProvidersPaginationNotifier count error: $e');
      }
    }
  }

  Future<void> _fetchPage({required bool isRefresh}) async {
    final repository = ref.read(userRepositoryProvider);
    final selectedCity = ref.read(serviceProvidersSelectedCityProvider);
    final searchQuery = ref.read(serviceProvidersCategorySearchQueryProvider);
    final scope = ref.read(cityAccessScopeProvider);
    if (!scope.isAuthorized) {
      state = state.copyWith(
        providers: const [],
        loading: false,
        loadingMore: false,
        hasMore: false,
        clearLastDocument: true,
        clearError: true,
      );
      return;
    }

    try {
      final pincodesMap = await ref.read(propertyPincodesProvider.future);
      final result = await repository.fetchCategoryServiceProvidersPage(
        category: '',
        areaPincodes: _areaPincodes,
        selectedCity: selectedCity,
        searchQuery: searchQuery,
        assignedCities: scope.assignedCities,
        isSuperAdmin: scope.isUnrestricted,
        pincodesMap: pincodesMap,
        startAfter: isRefresh ? null : state.lastDocument,
        limit: 20,
      );

      final updatedProviders = isRefresh
          ? result.items
          : [...state.providers, ...result.items];

      state = state.copyWith(
        providers: updatedProviders,
        loading: false,
        loadingMore: false,
        hasMore: result.hasMore,
        lastDocument: result.lastDocument,
        searchQuery: searchQuery,
        clearError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('AreaProvidersPaginationNotifier fetch error: $e');
      }
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: e.toString(),
      );
    }
  }
}

final areaProvidersPaginationProvider = NotifierProvider.family<
    AreaProvidersPaginationNotifier,
    CategoryProvidersPaginationState,
    String>(AreaProvidersPaginationNotifier.new);

