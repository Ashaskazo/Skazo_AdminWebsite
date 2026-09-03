import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/page_result.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/models/user_pagination_state.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/repositories/user_repository.dart';

const _countsCacheTtl = Duration(seconds: 60);

class _StaleDeactivatedRequestException implements Exception {
  const _StaleDeactivatedRequestException();
}

class _CachedDeactivatedCounts {
  const _CachedDeactivatedCounts({
    required this.filteredCount,
    required this.totalCount,
    required this.cachedAt,
  });

  final int filteredCount;
  final int totalCount;
  final DateTime cachedAt;

  bool get isFresh => DateTime.now().difference(cachedAt) < _countsCacheTtl;
}

// Filter State Providers for Deactivated List
final deactivatedSearchQueryProvider = StateProvider<String>((ref) => '');
final deactivatedSelectedCityProvider = StateProvider<String?>((ref) => null);
final deactivatedDateFilterProvider = StateProvider<String?>((ref) => null);
final deactivatedCustomDateRangeProvider = StateProvider<DateTimeRange?>(
  (ref) => null,
);
final deactivatedStatusFilterProvider = StateProvider<String>(
  (ref) => 'Deactivated',
);

/// Cursor-paginated deactivated users list with server-side filters and search.
class DeactivatedPaginationNotifier extends Notifier<UserPaginationState> {
  Timer? _filterDebounce;
  int _requestId = 0;
  final Map<String, _CachedDeactivatedCounts> _countCache = {};
  final Map<String, Future<_CachedDeactivatedCounts>> _countRequests = {};
  final Map<String, Future<PageResult<UserModel>>> _pageRequests = {};

  @override
  UserPaginationState build() {
    ref.onDispose(() {
      _filterDebounce?.cancel();
      _countRequests.clear();
      _pageRequests.clear();
      _countCache.clear();
    });

    ref.listen(deactivatedSearchQueryProvider, (_, __) => _scheduleRefresh());
    ref.listen(deactivatedSelectedCityProvider, (_, __) => _scheduleRefresh());
    ref.listen(deactivatedDateFilterProvider, (_, __) => _scheduleRefresh());
    ref.listen(
      deactivatedCustomDateRangeProvider,
      (_, __) => _scheduleRefresh(),
    );
    ref.listen(deactivatedStatusFilterProvider, (_, __) => _scheduleRefresh());

    ref.listen(currentAdminAssignedCitiesProvider, (_, __) {
      clearOptimizationCaches();
      _scheduleRefresh();
    });
    ref.listen(isSuperAdminProvider, (_, __) {
      clearOptimizationCaches();
      _scheduleRefresh();
    });
    ref.listen(currentAdminProfileProvider, (_, __) {
      clearOptimizationCaches();
      _scheduleRefresh();
    });

    Future.microtask(refresh);
    return UserPaginationState.initial();
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

    final searchQuery = ref.read(deactivatedSearchQueryProvider);
    final selectedCity = ref.read(deactivatedSelectedCityProvider);
    final dateFilter = ref.read(deactivatedDateFilterProvider);
    final customDateRange = ref.read(deactivatedCustomDateRangeProvider);
    final statusFilter = ref.read(deactivatedStatusFilterProvider);

    state = state.copyWith(
      loading: true,
      loadingMore: false,
      searchQuery: searchQuery,
      users: const [],
      clearLastDocument: true,
      clearError: true,
      hasMore: true,
    );

    await Future.wait([
      _fetchPage(isRefresh: true, requestId: requestId),
      _loadCounts(
        searchQuery: searchQuery,
        selectedCity: selectedCity,
        dateFilter: dateFilter,
        customDateRange: customDateRange,
        statusFilter: statusFilter,
        requestId: requestId,
      ),
    ]);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    final requestId = _requestId;
    state = state.copyWith(loadingMore: true, clearError: true);
    await _fetchPage(isRefresh: false, requestId: requestId);
  }

  Future<void> _loadCounts({
    required String searchQuery,
    required String? selectedCity,
    required String? dateFilter,
    required DateTimeRange? customDateRange,
    required String statusFilter,
    required int requestId,
  }) async {
    final cacheKey = _buildCountsKey(
      searchQuery,
      selectedCity,
      dateFilter,
      customDateRange,
      statusFilter,
    );
    final cachedCounts = _readCachedCounts(cacheKey);
    if (cachedCounts != null) {
      if (requestId == _requestId) {
        state = state.copyWith(
          filteredCount: cachedCounts.filteredCount,
          totalCount: cachedCounts.totalCount,
        );
      }
      return;
    }

    Future<_CachedDeactivatedCounts>? future;
    try {
      future =
          _countRequests[cacheKey] ??= _computeCounts(
            searchQuery: searchQuery,
            selectedCity: selectedCity,
            dateFilter: dateFilter,
            customDateRange: customDateRange,
            statusFilter: statusFilter,
            requestId: requestId,
          );
      final counts = await future;

      if (requestId != _requestId) {
        return;
      }

      state = state.copyWith(
        filteredCount: counts.filteredCount,
        totalCount: counts.totalCount,
      );
    } catch (e) {
      if (e is _StaleDeactivatedRequestException) {
        return;
      }
      if (requestId != _requestId) {
        return;
      }
      if (kDebugMode) {
        debugPrint('DeactivatedPaginationNotifier count error: ');
      }
    } finally {
      if (identical(_countRequests[cacheKey], future)) {
        _countRequests.remove(cacheKey);
      }
    }
  }

  Future<_CachedDeactivatedCounts> _computeCounts({
    required String searchQuery,
    required String? selectedCity,
    required String? dateFilter,
    required DateTimeRange? customDateRange,
    required String statusFilter,
    required int requestId,
  }) async {
    final repository = ref.read(userRepositoryProvider);
    final assignedCities = ref.read(currentAdminAssignedCitiesProvider);

    final filteredCountFuture = repository.countDeactivatedUsers(
      searchQuery: searchQuery,
      selectedCity: selectedCity,
      dateFilter: dateFilter,
      customDateRange: customDateRange,
      statusFilter: statusFilter,
      assignedCities: assignedCities,
    );

    final totalCountFuture = repository.countDeactivatedUsers(
      searchQuery: '',
      selectedCity: null,
      dateFilter: null,
      customDateRange: null,
      statusFilter: 'Deactivated',
      assignedCities: assignedCities,
    );

    final results = await Future.wait([
      filteredCountFuture,
      totalCountFuture,
    ]);

    if (requestId != _requestId) {
      throw const _StaleDeactivatedRequestException();
    }

    final counts = _CachedDeactivatedCounts(
      filteredCount: results[0],
      totalCount: results[1],
      cachedAt: DateTime.now(),
    );

    final cacheKey = _buildCountsKey(
      searchQuery,
      selectedCity,
      dateFilter,
      customDateRange,
      statusFilter,
    );
    _countCache[cacheKey] = counts;
    return counts;
  }

  Future<void> _fetchPage({
    required bool isRefresh,
    required int requestId,
  }) async {
    final repository = ref.read(userRepositoryProvider);
    final assignedCities = ref.read(currentAdminAssignedCitiesProvider);
    final searchQuery = ref.read(deactivatedSearchQueryProvider);
    final selectedCity = ref.read(deactivatedSelectedCityProvider);
    final dateFilter = ref.read(deactivatedDateFilterProvider);
    final customDateRange = ref.read(deactivatedCustomDateRangeProvider);
    final statusFilter = ref.read(deactivatedStatusFilterProvider);

    final startAfter = isRefresh ? null : state.lastDocument;
    final pageKey = _buildPageKey(
      searchQuery,
      selectedCity,
      dateFilter,
      customDateRange,
      statusFilter,
      startAfter?.id,
    );

    Future<PageResult<UserModel>>? future;
    try {
      future =
          _pageRequests[pageKey] ??= repository.fetchDeactivatedUsers(
            searchQuery: searchQuery,
            selectedCity: selectedCity,
            dateFilter: dateFilter,
            customDateRange: customDateRange,
            statusFilter: statusFilter,
            assignedCities: assignedCities,
            startAfter: startAfter,
          );

      final result = await future;
      if (requestId != _requestId) {
        return;
      }

      final nextUsers =
          isRefresh ? result.items : [...state.users, ...result.items];

      state = state.copyWith(
        users: nextUsers,
        lastDocument: result.lastDocument,
        hasMore: result.hasMore,
        loading: false,
        loadingMore: false,
        clearError: true,
      );
    } catch (e) {
      if (requestId != _requestId) {
        return;
      }
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: e.toString(),
      );
    } finally {
      if (identical(_pageRequests[pageKey], future)) {
        _pageRequests.remove(pageKey);
      }
    }
  }

  _CachedDeactivatedCounts? _readCachedCounts(String key) {
    final cached = _countCache[key];
    if (cached == null) return null;
    if (!cached.isFresh) {
      _countCache.remove(key);
      return null;
    }
    return cached;
  }

  String _buildCountsKey(
    String searchQuery,
    String? selectedCity,
    String? dateFilter,
    DateTimeRange? customDateRange,
    String statusFilter,
  ) {
    final customStr =
        customDateRange != null
            ? '${customDateRange.start.toIso8601String()}_${customDateRange.end.toIso8601String()}'
            : '';
    return '$searchQuery|$selectedCity|$dateFilter|$customStr|$statusFilter';
  }

  String _buildPageKey(
    String searchQuery,
    String? selectedCity,
    String? dateFilter,
    DateTimeRange? customDateRange,
    String statusFilter,
    String? cursorId,
  ) {
    final countsKey = _buildCountsKey(
      searchQuery,
      selectedCity,
      dateFilter,
      customDateRange,
      statusFilter,
    );
    return '$countsKey|$cursorId';
  }
}

final deactivatedPaginationProvider =
    NotifierProvider<DeactivatedPaginationNotifier, UserPaginationState>(
      DeactivatedPaginationNotifier.new,
    );
