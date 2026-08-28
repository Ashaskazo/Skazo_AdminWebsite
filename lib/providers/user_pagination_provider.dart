import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/page_result.dart';
import 'package:skazo_admin/models/user_filters.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/models/user_pagination_state.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/repositories/user_repository.dart';
import 'package:skazo_admin/utils/time_filter.dart';

const _countsCacheTtl = Duration(seconds: 60);

class _StaleUserRequestException implements Exception {
  const _StaleUserRequestException();
}

class _CachedUserCounts {
  const _CachedUserCounts({
    required this.filteredCount,
    required this.totalCount,
    required this.cachedAt,
    this.serviceProviderCount,
  });

  final int filteredCount;
  final int totalCount;
  final int? serviceProviderCount;
  final DateTime cachedAt;

  bool get isFresh => DateTime.now().difference(cachedAt) < _countsCacheTtl;
}

/// Cursor-paginated users list with server-side filters and search.
class UserPaginationNotifier extends Notifier<UserPaginationState> {
  Timer? _filterDebounce;
  int _requestId = 0;
  final Map<String, _CachedUserCounts> _countCache = {};
  final Map<String, Future<_CachedUserCounts>> _countRequests = {};
  final Map<String, Future<PageResult<UserModel>>> _pageRequests = {};

  @override
  UserPaginationState build() {
    ref.onDispose(() {
      _filterDebounce?.cancel();
      _countRequests.clear();
      _pageRequests.clear();
    });

    ref.listen(userSearchQueryProvider, (_, __) => _scheduleRefresh());
    ref.listen(userSelectedCityProvider, (_, __) => _scheduleRefresh());
    ref.listen(userVerifiedOnlyProvider, (_, __) => _scheduleRefresh());
    ref.listen(userDateFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(userTypeFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(userCategoryFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(userPriorityFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(
      userProfileCompleteFilterProvider,
      (_, __) => _scheduleRefresh(),
    );
    ref.listen(userBusinessNameFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(userSortAscendingProvider, (_, __) => _scheduleRefresh());
    ref.listen(currentAdminAssignedCitiesProvider, (_, __) => _scheduleRefresh());

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

    return UserFilters(
      timeFilter: timeFilterFromLegacyUserValue(dateFilter),
      verifiedOnly: verifiedOnly ? true : null,
      city: ref.read(userSelectedCityProvider),
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
    _filterDebounce = Timer(const Duration(milliseconds: 250), refresh);
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

    await Future.wait([
      _fetchPage(isRefresh: true, requestId: requestId),
      _loadCounts(filters: filters, searchQuery: searchQuery, requestId: requestId),
    ]);
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
    final cacheKey = _buildCountsKey(filters, searchQuery);
    final cachedCounts = _readCachedCounts(cacheKey);
    if (cachedCounts != null) {
      if (requestId == _requestId) {
        state = state.copyWith(
          filteredCount: cachedCounts.filteredCount,
          totalCount: cachedCounts.totalCount,
          serviceProviderCount: cachedCounts.serviceProviderCount,
        );
      }
      return;
    }

    Future<_CachedUserCounts>? future;
    try {
      future =
          _countRequests[cacheKey] ??= _computeCounts(
            filters: filters,
            searchQuery: searchQuery,
            requestId: requestId,
          );
      final counts = await future;

      if (requestId != _requestId) {
        return;
      }

      state = state.copyWith(
        filteredCount: counts.filteredCount,
        totalCount: counts.totalCount,
        serviceProviderCount: counts.serviceProviderCount,
      );
    } catch (e) {
      if (e is _StaleUserRequestException) {
        return;
      }
      if (requestId != _requestId) {
        return;
      }
      if (kDebugMode) {
        debugPrint('UserPaginationNotifier count error: $e');
      }
    } finally {
      if (identical(_countRequests[cacheKey], future)) {
        _countRequests.remove(cacheKey);
      }
    }
  }

  bool _filtersAreDefault(UserFilters filters) {
    return filters == const UserFilters();
  }

  Future<void> _fetchPage({
    required bool isRefresh,
    required int requestId,
  }) async {
    final repository = ref.read(userRepositoryProvider);
    final assignedCities = ref.read(currentAdminAssignedCitiesProvider);
    final filters = state.filters;
    final searchQuery = state.searchQuery;
    final startAfter = isRefresh ? null : state.lastDocument;
    final pageKey = _buildPageKey(filters, searchQuery, startAfter);

    Future<PageResult<UserModel>>? requestFuture;
    try {
      _throwIfStale(requestId);
      final inFlightRequest = _pageRequests[pageKey];
      requestFuture =
          inFlightRequest ??
          (() async {
            _throwIfStale(requestId);
            return repository.fetchUsersWithSearchFallback(
              filters: filters,
              searchQuery: searchQuery,
              assignedCities: assignedCities,
              pincodesMap: const {},
              startAfter: startAfter,
            );
          })();

      if (inFlightRequest == null) {
        _pageRequests[pageKey] = requestFuture;
      }

      if (requestId != _requestId) {
        return;
      }

      final result = await requestFuture;
      if (requestId != _requestId) {
        return;
      }

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
      if (e is _StaleUserRequestException) {
        return;
      }
      if (requestId != _requestId) {
        return;
      }
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

  Future<_CachedUserCounts> _computeCounts({
    required UserFilters filters,
    required String searchQuery,
    required int requestId,
  }) async {
    final repository = ref.read(userRepositoryProvider);
    final assignedCities = ref.read(currentAdminAssignedCitiesProvider);
    _throwIfStale(requestId);
    final filteredCount = await repository.countUsers(
      filters: filters,
      searchQuery: searchQuery,
      assignedCities: assignedCities,
      pincodesMap: const {},
    );
    _throwIfStale(requestId);
    final serviceProviderCount =
        searchQuery.isEmpty
            ? (filters.userType == 'Service Providers'
                ? filteredCount
                : await repository.countServiceProviders(
                  filters: filters,
                  assignedCities: assignedCities,
                  pincodesMap: const {},
                ))
            : null;
    _throwIfStale(requestId);
    final totalCount =
        searchQuery.isEmpty && _filtersAreDefault(filters)
            ? filteredCount
            : await repository.countUsers(
              filters: const UserFilters(),
              searchQuery: '',
              assignedCities: assignedCities,
              pincodesMap: const {},
            );
    _throwIfStale(requestId);

    final counts = _CachedUserCounts(
      filteredCount: filteredCount,
      totalCount: totalCount,
      serviceProviderCount: serviceProviderCount,
      cachedAt: DateTime.now(),
    );
    _countCache[_buildCountsKey(filters, searchQuery)] = counts;
    return counts;
  }

  void _throwIfStale(int requestId) {
    if (requestId != _requestId) {
      throw const _StaleUserRequestException();
    }
  }

  _CachedUserCounts? _readCachedCounts(String cacheKey) {
    final cached = _countCache[cacheKey];
    if (cached == null) {
      return null;
    }
    if (!cached.isFresh) {
      _countCache.remove(cacheKey);
      return null;
    }
    return cached;
  }

  String _buildCountsKey(UserFilters filters, String searchQuery) {
    return [
      filters.timeFilter.name,
      filters.verifiedOnly?.toString() ?? '',
      filters.city?.trim().toLowerCase() ?? '',
      filters.userType,
      filters.category?.trim() ?? '',
      filters.priority?.toString() ?? '',
      filters.profileComplete?.toString() ?? '',
      filters.businessNamePrefix?.trim() ?? '',
      searchQuery.trim(),
    ].join('|');
  }

  String _buildPageKey(
    UserFilters filters,
    String searchQuery,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
  ) {
    return '${_buildCountsKey(filters, searchQuery)}|${startAfter?.id ?? 'root'}';
  }

  int get filteredCount => state.filteredCount ?? state.users.length;
  int get totalCount => state.totalCount ?? 0;
  int get serviceProviderCount => state.serviceProviderCount ?? 0;
}

final userPaginationProvider =
    NotifierProvider<UserPaginationNotifier, UserPaginationState>(
      UserPaginationNotifier.new,
    );
