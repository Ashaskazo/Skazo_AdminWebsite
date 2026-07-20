import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/constants/business_categories.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/repositories/user_repository.dart';
import 'package:skazo_admin/utils/time_filter.dart';

/// Paginated unverified users for dashboard category drill-down.
class UnverifiedPaginationState {
  final List<UserModel> users;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;

  const UnverifiedPaginationState({
    this.users = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.hasMore = true,
    this.lastDocument,
  });

  factory UnverifiedPaginationState.initial() =>
      const UnverifiedPaginationState(loading: true);

  UnverifiedPaginationState copyWith({
    List<UserModel>? users,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    bool clearLastDocument = false,
    bool clearError = false,
  }) {
    return UnverifiedPaginationState(
      users: users ?? this.users,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      lastDocument: clearLastDocument ? null : (lastDocument ?? this.lastDocument),
    );
  }
}

class UnverifiedPaginationNotifier extends FamilyNotifier<
    UnverifiedPaginationState,
    String?> {
  @override
  UnverifiedPaginationState build(String? category) {
    ref.listen(dashboardSelectedDateFilterProvider, (_, __) => refresh());
    ref.listen(dashboardSelectedCityProvider, (_, __) => refresh());
    Future.microtask(refresh);
    return UnverifiedPaginationState.initial();
  }

  TimeFilterOption get _timeFilter {
    final dateFilter = ref.read(dashboardSelectedDateFilterProvider);
    return timeFilterFromLegacyUserValue(dateFilter);
  }

  String? get _city => ref.read(dashboardSelectedCityProvider);

  Future<void> refresh() async {
    state = state.copyWith(
      loading: true,
      loadingMore: false,
      users: const [],
      clearLastDocument: true,
      clearError: true,
      hasMore: true,
    );
    await _fetchPage(isRefresh: true);
  }

  Future<void> loadMore() async {
    if (state.loading || state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true, clearError: true);
    await _fetchPage(isRefresh: false);
  }

  Future<void> _fetchPage({required bool isRefresh}) async {
    final repository = ref.read(userRepositoryProvider);
    final category = arg;

    try {
      final pincodesMap = await ref.read(propertyPincodesProvider.future);
      final result = await repository.fetchUnverifiedUsers(
        timeFilter: _timeFilter,
        city: _city,
        category: category,
        pincodesMap: pincodesMap,
        startAfter: isRefresh ? null : state.lastDocument,
      );

      final updatedUsers = isRefresh
          ? result.items
          : [...state.users, ...result.items];

      state = state.copyWith(
        users: updatedUsers,
        loading: false,
        loadingMore: false,
        hasMore: result.hasMore,
        lastDocument: result.lastDocument,
        clearError: true,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('UnverifiedPaginationNotifier error: $e');
      }
      state = state.copyWith(
        loading: false,
        loadingMore: false,
        error: e.toString(),
      );
    }
  }
}

final unverifiedPaginationProvider = NotifierProvider.family<
    UnverifiedPaginationNotifier,
    UnverifiedPaginationState,
    String?>(UnverifiedPaginationNotifier.new);

final categoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.keepAlive();
  final repository = ref.watch(userRepositoryProvider);
  final dateFilter = ref.watch(dashboardSelectedDateFilterProvider);
  final city = ref.watch(dashboardSelectedCityProvider);
  final timeFilter = timeFilterFromLegacyUserValue(dateFilter);
  final pincodesMap = await ref.watch(propertyPincodesProvider.future);

  return repository.countUnverifiedByCategories(
    categories: kBusinessCategories,
    timeFilter: timeFilter,
    city: city,
    pincodesMap: pincodesMap,
  );
});

final unverifiedPendingCountProvider = FutureProvider<int>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  final dateFilter = ref.watch(dashboardSelectedDateFilterProvider);
  final city = ref.watch(dashboardSelectedCityProvider);
  final timeFilter = timeFilterFromLegacyUserValue(dateFilter);
  final pincodesMap = await ref.watch(propertyPincodesProvider.future);

  return repository.countUnverifiedPending(
    timeFilter: timeFilter,
    city: city,
    pincodesMap: pincodesMap,
  );
});
