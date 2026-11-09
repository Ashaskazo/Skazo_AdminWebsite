import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/call_log_sheet_item.dart';
import 'package:skazo_admin/repositories/call_log_sheet_repository.dart';

/// Filter, sort and pagination state providers for Call Log Sheet
final callLogSheetSearchQueryProvider = StateProvider<String>((ref) => '');
final callLogSheetStatusFilterProvider = StateProvider<String>((ref) => 'All');
final callLogSheetSortByProvider = StateProvider<CallLogSheetSortOption>(
  (ref) => CallLogSheetSortOption.callsDesc,
);

/// Pagination controls
final callLogSheetPageSizeProvider = StateProvider<int>((ref) => 10);
final callLogSheetCurrentPageProvider = StateProvider<int>((ref) => 0);

enum CallLogSheetSortOption {
  callsDesc,
  callsAsc,
  deactivatedDateDesc,
  deactivatedDateAsc,
  convertedDesc,
  convertedAsc,
  businessNameAsc,
  businessNameDesc,
}

/// State data class holding all raw consolidated items, loading flag, and error.
class CallLogSheetState {
  final bool isLoading;
  final bool isRefreshing;
  final String? errorMessage;
  final String? warningMessage;
  final List<CallLogSheetItem> items;
  final DateTime? lastRefreshed;
  final CallLogSheetSyncMetrics? metrics;

  const CallLogSheetState({
    required this.isLoading,
    this.isRefreshing = false,
    this.errorMessage,
    this.warningMessage,
    this.items = const [],
    this.lastRefreshed,
    this.metrics,
  });

  CallLogSheetState copyWith({
    bool? isLoading,
    bool? isRefreshing,
    String? errorMessage,
    String? warningMessage,
    List<CallLogSheetItem>? items,
    DateTime? lastRefreshed,
    CallLogSheetSyncMetrics? metrics,
  }) {
    return CallLogSheetState(
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      errorMessage: errorMessage,
      warningMessage: warningMessage,
      items: items ?? this.items,
      lastRefreshed: lastRefreshed ?? this.lastRefreshed,
      metrics: metrics ?? this.metrics,
    );
  }
}

/// StateNotifier that coordinates reading and combining data from Firestore
/// collections: `users` and `callLogs`.
class CallLogSheetNotifier extends StateNotifier<CallLogSheetState> {
  final CallLogSheetRepository _repository;
  bool _isFetching = false;

  CallLogSheetNotifier(this._repository)
      : super(const CallLogSheetState(isLoading: true)) {
    fetchData();
  }

  /// Fetches eligible providers and their associated call logs.
  /// Prevents concurrent overlapping fetch operations.
  /// Preserves existing data during refresh to prevent UI flickering.
  Future<void> fetchData({bool isRefresh = false}) async {
    if (_isFetching) {
      if (kDebugMode) {
        debugPrint('[CallLogSheet] Fetch already in progress. Ignoring duplicate call.');
      }
      return;
    }

    _isFetching = true;

    // If items exist, mark as refreshing without destroying visible table
    if (state.items.isNotEmpty) {
      state = state.copyWith(
        isLoading: false,
        isRefreshing: true,
        errorMessage: null,
      );
    } else {
      state = state.copyWith(
        isLoading: true,
        isRefreshing: false,
        errorMessage: null,
        warningMessage: null,
      );
    }

    try {
      final result = await _repository.fetchEligibleProviders();
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        items: result.items,
        warningMessage: result.warningMessage,
        lastRefreshed: DateTime.now(),
        metrics: result.metrics,
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('CallLogSheet fetch error: $e\n$stack');
      }
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      _isFetching = false;
      // Guarantee loading flags are false under ANY circumstances
      if (mounted && (state.isLoading || state.isRefreshing)) {
        state = state.copyWith(isLoading: false, isRefreshing: false);
      }
    }
  }
}

/// Provider for the CallLogSheetNotifier
final callLogSheetNotifierProvider =
    StateNotifierProvider<CallLogSheetNotifier, CallLogSheetState>((ref) {
  final repository = ref.watch(callLogSheetRepositoryProvider);
  return CallLogSheetNotifier(repository);
});

/// Filtered & Sorted Call Log Sheet items provider (full result set matching filter)
final filteredCallLogSheetItemsProvider =
    Provider<List<CallLogSheetItem>>((ref) {
  final sheetState = ref.watch(callLogSheetNotifierProvider);
  final query = ref.watch(callLogSheetSearchQueryProvider).trim().toLowerCase();
  final statusFilter =
      ref.watch(callLogSheetStatusFilterProvider).trim().toLowerCase();
  final sortBy = ref.watch(callLogSheetSortByProvider);

  var items = List<CallLogSheetItem>.from(sheetState.items);

  // 1. Search Query (business name, phone, transaction ID, business ID)
  if (query.isNotEmpty) {
    items = items.where((item) {
      final nameMatches = item.businessName.toLowerCase().contains(query);
      final phoneMatches = item.phone.toLowerCase().contains(query) ||
          item.phone.replaceAll(RegExp(r'[^\d]'), '').contains(query);
      final txMatches =
          item.transactionId?.toLowerCase().contains(query) ?? false;
      final idMatches = item.businessId.toLowerCase().contains(query);
      return nameMatches || phoneMatches || txMatches || idMatches;
    }).toList();
  }

  // 2. Status Filter
  if (statusFilter != 'all') {
    items = items.where((item) {
      return item.feedbackStatuses.any(
        (st) => st.toLowerCase() == statusFilter,
      );
    }).toList();
  }

  // 3. Sorting
  switch (sortBy) {
    case CallLogSheetSortOption.callsDesc:
      items.sort(
        (a, b) => b.callsAfterLastPayment.compareTo(a.callsAfterLastPayment),
      );
      break;
    case CallLogSheetSortOption.callsAsc:
      items.sort(
        (a, b) => a.callsAfterLastPayment.compareTo(b.callsAfterLastPayment),
      );
      break;
    case CallLogSheetSortOption.deactivatedDateDesc:
      items.sort((a, b) {
        if (a.deactivatedAt == null && b.deactivatedAt == null) return 0;
        if (a.deactivatedAt == null) return 1;
        if (b.deactivatedAt == null) return -1;
        return b.deactivatedAt!.compareTo(a.deactivatedAt!);
      });
      break;
    case CallLogSheetSortOption.deactivatedDateAsc:
      items.sort((a, b) {
        if (a.deactivatedAt == null && b.deactivatedAt == null) return 0;
        if (a.deactivatedAt == null) return 1;
        if (b.deactivatedAt == null) return -1;
        return a.deactivatedAt!.compareTo(b.deactivatedAt!);
      });
      break;
    case CallLogSheetSortOption.convertedDesc:
      items.sort((a, b) => b.convertedCount.compareTo(a.convertedCount));
      break;
    case CallLogSheetSortOption.convertedAsc:
      items.sort((a, b) => a.convertedCount.compareTo(b.convertedCount));
      break;
    case CallLogSheetSortOption.businessNameAsc:
      items.sort(
        (a, b) => a.businessName.toLowerCase().compareTo(
              b.businessName.toLowerCase(),
            ),
      );
      break;
    case CallLogSheetSortOption.businessNameDesc:
      items.sort(
        (a, b) => b.businessName.toLowerCase().compareTo(
              a.businessName.toLowerCase(),
            ),
      );
      break;
  }

  return items;
});

/// Extracted unique sales feedback statuses from current dataset for the filter dropdown
final callLogSheetAvailableStatusesProvider = Provider<List<String>>((ref) {
  final sheetState = ref.watch(callLogSheetNotifierProvider);
  final Set<String> statuses = {'All'};

  for (final item in sheetState.items) {
    for (final st in item.feedbackStatuses) {
      if (st.trim().isNotEmpty) {
        statuses.add(st.trim());
      }
    }
  }

  final list = statuses.toList();
  // Keep 'All' at index 0, sort the rest
  final rest = list.sublist(1)..sort();
  return ['All', ...rest];
});

/// Pagination view data class
class CallLogSheetPaginationData {
  final int totalItems;
  final int pageSize;
  final int currentPage;
  final int totalPages;
  final int startRow;
  final int endRow;
  final List<CallLogSheetItem> pageItems;
  final bool hasPreviousPage;
  final bool hasNextPage;

  const CallLogSheetPaginationData({
    required this.totalItems,
    required this.pageSize,
    required this.currentPage,
    required this.totalPages,
    required this.startRow,
    required this.endRow,
    required this.pageItems,
    required this.hasPreviousPage,
    required this.hasNextPage,
  });
}

/// Provider computing paginated slice of filtered items
final callLogSheetPaginationProvider =
    Provider<CallLogSheetPaginationData>((ref) {
  final filteredItems = ref.watch(filteredCallLogSheetItemsProvider);
  final pageSize = ref.watch(callLogSheetPageSizeProvider);
  final rawCurrentPage = ref.watch(callLogSheetCurrentPageProvider);

  final totalItems = filteredItems.length;
  final totalPages = max(1, (totalItems / pageSize).ceil());

  // Clamp current page safely to prevent pointing to an invalid page
  final safePage = rawCurrentPage.clamp(0, totalPages - 1);

  final startOffset = safePage * pageSize;
  final pageItems = totalItems == 0
      ? <CallLogSheetItem>[]
      : filteredItems.skip(startOffset).take(pageSize).toList();

  final startRow = totalItems == 0 ? 0 : startOffset + 1;
  final endRow = totalItems == 0 ? 0 : min(startOffset + pageSize, totalItems);

  return CallLogSheetPaginationData(
    totalItems: totalItems,
    pageSize: pageSize,
    currentPage: safePage,
    totalPages: totalPages,
    startRow: startRow,
    endRow: endRow,
    pageItems: pageItems,
    hasPreviousPage: safePage > 0,
    hasNextPage: safePage < totalPages - 1,
  );
});
