import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/page_result.dart';
import 'package:skazo_admin/models/user_filters.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/models/user_pagination_state.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/repositories/user_repository.dart';
import 'package:skazo_admin/utils/time_filter.dart';

const _countsCacheTtl = Duration(seconds: 60);

class _StaleUserRequestException implements Exception {
  const _StaleUserRequestException();
}

class _CachedCounts {
  final UserCounts counts;
  final DateTime cachedAt;

  const _CachedCounts({required this.counts, required this.cachedAt});

  bool get isFresh => DateTime.now().difference(cachedAt) < _countsCacheTtl;
}

/// Cursor-paginated users list with server-side filters and search.
class UserPaginationNotifier extends Notifier<UserPaginationState> {
  Timer? _filterDebounce;
  int _requestId = 0;
  final Map<String, _CachedCounts> _countCache = {};
  final Map<String, Future<UserCounts>> _countRequests = {};
  final Map<String, Future<PageResult<UserModel>>> _pageRequests = {};

  @override
  UserPaginationState build() {
    ref.onDispose(() {
      _filterDebounce?.cancel();
      _countRequests.clear();
      _pageRequests.clear();
      _countCache.clear();
    });

    ref.listen(userSearchQueryProvider, (_, __) => _scheduleRefresh());
    ref.listen(userSelectedCityProvider, (_, __) => _scheduleRefresh());
    ref.listen(userVerifiedOnlyProvider, (_, __) => _scheduleRefresh());
    ref.listen(userDateFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(userTypeFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(userCategoryFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(userPriorityFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(userProfileCompleteFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(userBusinessNameFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(userSortAscendingProvider, (_, __) => _scheduleRefresh());
    ref.listen(currentAdminAssignedCitiesProvider, (_, __) => _scheduleRefresh());
    ref.listen(isSuperAdminProvider, (_, __) => _scheduleRefresh());

    Future.microtask(refresh);
    return UserPaginationState.initial();
  }

  UserFilters _readFilters() {
    final dateFilter = ref.read(userDateFilterProvider);
    final verifiedOnly = ref.read(userVerifiedOnlyProvider);
    final category = ref.read(userCategoryFilterProvider);
    final priority = ref.read(userPriorityFilterProvider);
    final profileComplete = ref.read(userProfileCompleteFilterProvider);
    final businessName = ref.read(userBusinessNameFilterProvider);
    final sortAscending = ref.read(userSortAscendingProvider);
    final city = ref.read(userSelectedCityProvider);

    return UserFilters(
      timeFilter: timeFilterFromLegacyUserValue(dateFilter),
      verifiedOnly: verifiedOnly ? true : null,
      city: city,
      userType: ref.read(userTypeFilterProvider),
      category: category,
      priority: priority,
      profileComplete: profileComplete,
      businessNamePrefix:
          businessName?.trim().isEmpty == true ? null : businessName,
      sortAscending: sortAscending,
    );
  }

  void _scheduleRefresh() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 200), refresh);
  }

  void clearOptimizationCaches() {
    _countCache.clear();
    _countRequests.clear();
    _pageRequests.clear();
  }

  Future<void> refresh() async {
    _requestId++;
    final requestId = _requestId;
    _filterDebounce?.cancel();

    final filters = _readFilters();
    final searchQuery = ref.read(userSearchQueryProvider);

    state = state.copyWith(
      loading: true,
      loadingMore: false,
      filters: filters,
      searchQuery: searchQuery,
      users: const [],
      clearLastDocument: true,
      clearError: true,
      hasMore: true,
    );

    await _fetchPage(isRefresh: true, requestId: requestId);
    _loadCounts(filters: filters, searchQuery: searchQuery, requestId: requestId);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final requestId = _requestId;
    state = state.copyWith(loadingMore: true, clearError: true);
    await _fetchPage(isRefresh: false, requestId: requestId);
  }

  Future<void> _loadCounts({
    required UserFilters filters,
    required String searchQuery,
    required int requestId,
  }) async {
    final assignedCities = ref.read(currentAdminAssignedCitiesProvider);
    final isSuper = ref.read(isSuperAdminProvider);
    final cacheKey = filters.toCacheKey(
      assignedCities: assignedCities,
      query: searchQuery,
    );

    final cached = _readCachedCounts(cacheKey);
    if (cached != null) {
      if (requestId == _requestId) {
        state = state.copyWith(
          filteredCount: cached.filtered,
          totalCount: cached.total,
          customerCount: cached.customers,
          serviceProviderCount: cached.serviceProviders,
        );
      }
      return;
    }

    Future<UserCounts>? future;
    try {
      final repository = ref.read(userRepositoryProvider);
      future = _countRequests[cacheKey] ??= repository.fetchUserCounts(
        filters: filters,
        searchQuery: searchQuery,
        assignedCities: assignedCities,
        isSuperAdmin: isSuper,
      );

      final counts = await future;
      _countCache[cacheKey] = _CachedCounts(
        counts: counts,
        cachedAt: DateTime.now(),
      );

      if (requestId != _requestId) return;

      state = state.copyWith(
        filteredCount: counts.filtered,
        totalCount: counts.total,
        customerCount: counts.customers,
        serviceProviderCount: counts.serviceProviders,
      );
    } catch (e) {
      if (e is _StaleUserRequestException || requestId != _requestId) return;
      if (kDebugMode) {
        debugPrint('[USERS] UserPaginationNotifier count error: $e');
      }
    } finally {
      if (identical(_countRequests[cacheKey], future)) {
        _countRequests.remove(cacheKey);
      }
    }
  }

  Future<void> _fetchPage({
    required bool isRefresh,
    required int requestId,
  }) async {
    final repository = ref.read(userRepositoryProvider);
    final assignedCities = ref.read(currentAdminAssignedCitiesProvider);
    final isSuper = ref.read(isSuperAdminProvider);
    final filters = state.filters;
    final searchQuery = state.searchQuery;
    final startAfter = isRefresh ? null : state.lastDocument;
    final pageKey = '${filters.toCacheKey(assignedCities: assignedCities, query: searchQuery)}|${startAfter?.id ?? 'root'}';

    Future<PageResult<UserModel>>? requestFuture;
    try {
      _throwIfStale(requestId);
      final inFlightRequest = _pageRequests[pageKey];
      requestFuture = inFlightRequest ??
          (() async {
            _throwIfStale(requestId);
            final pincodesMap = (ref.read(propertyPincodesProvider).value) ?? const <String, List<String>>{};
            return repository.fetchUsersWithSearchFallback(
              filters: filters,
              searchQuery: searchQuery,
              assignedCities: assignedCities,
              isSuperAdmin: isSuper,
              pincodesMap: pincodesMap,
              startAfter: startAfter,
            );
          })();

      if (inFlightRequest == null) {
        _pageRequests[pageKey] = requestFuture;
      }

      final result = await requestFuture;
      if (requestId != _requestId) return;

      final updatedUsers =
          isRefresh ? result.items : [...state.users, ...result.items];

      state = state.copyWith(
        users: updatedUsers,
        loading: false,
        loadingMore: false,
        hasMore: result.hasMore,
        lastDocument: result.lastDocument,
        clearError: true,
      );
    } catch (e) {
      if (e is _StaleUserRequestException || requestId != _requestId) return;
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: e.toString(),
      );
    } finally {
      if (requestFuture != null &&
          identical(_pageRequests[pageKey], requestFuture)) {
        _pageRequests.remove(pageKey);
      }
    }
  }

  void _throwIfStale(int requestId) {
    if (requestId != _requestId) {
      throw const _StaleUserRequestException();
    }
  }

  UserCounts? _readCachedCounts(String cacheKey) {
    final cached = _countCache[cacheKey];
    if (cached == null) return null;
    if (!cached.isFresh) {
      _countCache.remove(cacheKey);
      return null;
    }
    return cached.counts;
  }

  int get filteredCount => state.filteredCount ?? state.users.length;
  int get totalCount => state.totalCount ?? 0;
  int get customerCount => state.customerCount ?? 0;
  int get serviceProviderCount => state.serviceProviderCount ?? 0;
}

final userPaginationProvider =
    NotifierProvider<UserPaginationNotifier, UserPaginationState>(
      UserPaginationNotifier.new,
    );

