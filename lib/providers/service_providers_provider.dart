import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/constants/hyderabad_area_groups.dart';
import 'package:skazo_admin/models/service_provider_overview_model.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/repositories/user_repository.dart';

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
  final isSuper = ref.watch(isSuperAdminProvider);
  final assignedCities = isSuper
      ? const <String>[]
      : ref.watch(currentAdminAssignedCitiesProvider);
  final pincodesMap = await ref.watch(propertyPincodesProvider.future);

  return repository.fetchServiceProvidersOverviewStats(
    selectedCity: selectedCity,
    assignedCities: assignedCities,
    isSuperAdmin: isSuper,
    pincodesMap: pincodesMap,
    zonePincodes: selectedZone?.pincodes,
  );
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
    final isSuper = ref.read(isSuperAdminProvider);
    final assignedCities = isSuper
        ? const <String>[]
        : ref.read(currentAdminAssignedCitiesProvider);

    try {
      final count = await repository.countCategoryServiceProviders(
        category: category,
        areaPincodes: selectedZone?.pincodes,
        selectedCity: selectedCity,
        searchQuery: searchQuery,
        assignedCities: assignedCities,
        isSuperAdmin: isSuper,
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
    final isSuper = ref.read(isSuperAdminProvider);
    final assignedCities = isSuper
        ? const <String>[]
        : ref.read(currentAdminAssignedCitiesProvider);

    try {
      final pincodesMap = await ref.read(propertyPincodesProvider.future);
      final result = await repository.fetchCategoryServiceProvidersPage(
        category: category,
        areaPincodes: selectedZone?.pincodes,
        selectedCity: selectedCity,
        searchQuery: searchQuery,
        assignedCities: assignedCities,
        isSuperAdmin: isSuper,
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
    final isSuper = ref.read(isSuperAdminProvider);
    final assignedCities = isSuper
        ? const <String>[]
        : ref.read(currentAdminAssignedCitiesProvider);

    try {
      final count = await repository.countCategoryServiceProviders(
        category: '',
        areaPincodes: _areaPincodes,
        selectedCity: selectedCity,
        searchQuery: searchQuery,
        assignedCities: assignedCities,
        isSuperAdmin: isSuper,
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
    final isSuper = ref.read(isSuperAdminProvider);
    final assignedCities = isSuper
        ? const <String>[]
        : ref.read(currentAdminAssignedCitiesProvider);

    try {
      final pincodesMap = await ref.read(propertyPincodesProvider.future);
      final result = await repository.fetchCategoryServiceProvidersPage(
        category: '',
        areaPincodes: _areaPincodes,
        selectedCity: selectedCity,
        searchQuery: searchQuery,
        assignedCities: assignedCities,
        isSuperAdmin: isSuper,
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

