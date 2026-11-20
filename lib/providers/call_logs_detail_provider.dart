import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/constants/hyderabad_area_groups.dart';
import 'package:skazo_admin/models/call_logs_detail_item.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/repositories/call_logs_detail_repository.dart';

/// Selected City filter (`null` means "All Cities" for Super Admin or all assigned cities for sales)
final callLogsDetailSelectedCityProvider = StateProvider<String?>((ref) => null);

/// Selected Hyderabad Zone (`null` means "All Zones").
/// Active only when selected city is Hyderabad.
final callLogsDetailSelectedZoneProvider =
    StateProvider<ServiceProviderAreaGroup?>((ref) => null);

/// Selected Category filter (`null` or 'All' means all categories)
final callLogsDetailSelectedCategoryProvider = StateProvider<String?>((ref) => null);

/// Selected Date Filter option (defaults to Last 7 Days)
final callLogsDetailDateOptionProvider =
    StateProvider<CallLogsDetailDateOption>((ref) => CallLogsDetailDateOption.last7Days);

/// Custom date range when `callLogsDetailDateOptionProvider` is `.custom`
final callLogsDetailCustomDateRangeProvider = StateProvider<DateTimeRange?>((ref) => null);

/// Feedback Status filter (`null` or 'All' means all feedback statuses)
final callLogsDetailFeedbackStatusFilterProvider = StateProvider<String?>((ref) => null);

/// Search query string
final callLogsDetailSearchQueryProvider = StateProvider<String>((ref) => '');

/// Current page index for pagination (0-based)
final callLogsDetailCurrentPageProvider = StateProvider<int>((ref) => 0);

/// Page size (default 25)
final callLogsDetailPageSizeProvider = StateProvider<int>((ref) => 25);

/// Sort columns
enum CallLogsDetailSortColumn {
  slNo,
  businessName,
  callDate,
  callsAfterPayment,
  city,
  category,
}

/// Active sort column (defaults to callDate)
final callLogsDetailSortColumnProvider =
    StateProvider<CallLogsDetailSortColumn>((ref) => CallLogsDetailSortColumn.callDate);

/// Sort direction: true for ascending, false for descending (defaults to false / newest first)
final callLogsDetailSortAscendingProvider = StateProvider<bool>((ref) => false);

/// Active subview under Call & Action Logs
enum CallLogsSubView {
  crmCallLogs,
  callLogsDetails,
}

/// Provider for toggling between CRM Call Logs and Call Logs Details views
final callLogsActiveSubViewProvider =
    StateProvider<CallLogsSubView>((ref) => CallLogsSubView.crmCallLogs);

/// Raw data provider: queries Firestore `callLogs` and hydrates provider `users`
final callLogsDetailRawDataProvider = FutureProvider<List<CallLogsDetailItem>>((ref) async {
  final repository = ref.watch(callLogsDetailRepositoryProvider);
  final scope = ref.watch(cityAccessScopeProvider);
  final selectedCity = ref.watch(callLogsDetailSelectedCityProvider);
  final dateOption = ref.watch(callLogsDetailDateOptionProvider);
  final customRange = ref.watch(callLogsDetailCustomDateRangeProvider);

  if (!scope.isAuthorized) {
    return const [];
  }

  final pincodesMap = ref.watch(propertyPincodesProvider).valueOrNull ?? const {};

  return repository.fetchCallLogsDetails(
    scope: scope,
    selectedCity: selectedCity,
    dateOption: dateOption,
    customStart: customRange?.start,
    customEnd: customRange?.end,
    pincodesMap: pincodesMap,
  );
});

/// Summary statistics derived from the loaded raw call logs
class CallLogsDetailSummaryStats {
  final int totalCalls;
  final int todayCalls;
  final int uniqueProviders;
  final int convertedCalls;
  final Map<String, int> categoryCounts;
  final List<String> distinctFeedbackStatuses;

  const CallLogsDetailSummaryStats({
    required this.totalCalls,
    required this.todayCalls,
    required this.uniqueProviders,
    required this.convertedCalls,
    required this.categoryCounts,
    required this.distinctFeedbackStatuses,
  });

  factory CallLogsDetailSummaryStats.empty() {
    return const CallLogsDetailSummaryStats(
      totalCalls: 0,
      todayCalls: 0,
      uniqueProviders: 0,
      convertedCalls: 0,
      categoryCounts: {},
      distinctFeedbackStatuses: [],
    );
  }
}

/// Computes summary header metrics and category counts for the horizontal bar
final callLogsDetailSummaryStatsProvider = Provider<CallLogsDetailSummaryStats>((ref) {
  final rawAsync = ref.watch(callLogsDetailRawDataProvider);
  return rawAsync.maybeWhen(
    data: (items) {
      if (items.isEmpty) return CallLogsDetailSummaryStats.empty();

      final selectedCity = ref.watch(callLogsDetailSelectedCityProvider);
      final selectedZone = ref.watch(callLogsDetailSelectedZoneProvider);
      final isHyderabad = isCityHyderabad(selectedCity);
      final effectiveZone = isHyderabad ? selectedZone : null;

      final scopedItems = effectiveZone != null
          ? items.where((it) => it.matchesZone(effectiveZone)).toList()
          : items;

      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final tomorrowMidnight = todayMidnight.add(const Duration(days: 1));

      final uniqueProviders = <String>{};
      final categoryCounts = <String, int>{};
      final distinctStatuses = <String>{};
      int todayCount = 0;
      int convertedCount = 0;

      for (final item in scopedItems) {
        if (item.businessId.isNotEmpty && item.businessId != '--') {
          uniqueProviders.add(item.businessId);
        }

        // Today call check
        if (item.timestamp != null) {
          final local = item.timestamp!.toLocal();
          if (!local.isBefore(todayMidnight) && local.isBefore(tomorrowMidnight)) {
            todayCount++;
          }
        }

        // Converted feedback check
        final fStatus = item.feedbackStatus?.trim().toLowerCase();
        if (fStatus == 'converted') {
          convertedCount++;
        }
        if (item.feedbackStatus != null && item.feedbackStatus!.trim().isNotEmpty) {
          distinctStatuses.add(item.feedbackStatus!.trim());
        }

        // Category count aggregation
        final cat = item.category.trim();
        if (cat.isNotEmpty && cat != '--') {
          // If comma-separated, increment for each
          final parts = cat.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty);
          for (final part in parts) {
            categoryCounts[part] = (categoryCounts[part] ?? 0) + 1;
          }
        }
      }

      final sortedStatuses = distinctStatuses.toList()..sort();

      return CallLogsDetailSummaryStats(
        totalCalls: scopedItems.length,
        todayCalls: todayCount,
        uniqueProviders: uniqueProviders.length,
        convertedCalls: convertedCount,
        categoryCounts: categoryCounts,
        distinctFeedbackStatuses: sortedStatuses,
      );
    },
    orElse: () => CallLogsDetailSummaryStats.empty(),
  );
});

/// Evaluates if a record's category matches the user-selected category.
/// Normalizes strings, handles pluralization (e.g. Electrician vs Electricians),
/// and supports comma-separated categories.
bool _matchesCategory(String recordCategory, String? selectedCategory) {
  if (selectedCategory == null ||
      selectedCategory.isEmpty ||
      selectedCategory == 'All' ||
      selectedCategory == 'All Categories') {
    return true;
  }

  final recNorm = recordCategory.toLowerCase().trim();
  final selNorm = selectedCategory.toLowerCase().trim();

  if (recNorm == selNorm) return true;
  if (recNorm.contains(selNorm)) return true;

  // Pluralization / singular check (e.g. Electrician vs Electricians, Plumber vs Plumbers)
  final selSingular = selNorm.endsWith('s') ? selNorm.substring(0, selNorm.length - 1) : selNorm;
  final recSingular = recNorm.endsWith('s') ? recNorm.substring(0, recNorm.length - 1) : recNorm;
  if (recSingular.contains(selSingular) || selSingular.contains(recSingular)) {
    return true;
  }

  // Also check individual comma-separated parts
  final parts = recNorm.split(',').map((p) => p.trim());
  for (final part in parts) {
    if (part == selNorm || part.contains(selNorm) || part.contains(selSingular)) {
      return true;
    }
  }

  return false;
}

/// Evaluates if a record matches the user-selected feedback status filter.
bool _matchesFeedbackStatus(String? recordStatus, String? selectedStatus) {
  if (selectedStatus == null ||
      selectedStatus.isEmpty ||
      selectedStatus == 'All' ||
      selectedStatus == 'All Statuses') {
    return true;
  }
  final rec = recordStatus?.trim().toLowerCase() ?? '';
  final sel = selectedStatus.trim().toLowerCase();
  return rec == sel;
}

/// Filtered and sorted call log items based on all active UI filters.
final callLogsDetailFilteredItemsProvider = Provider<List<CallLogsDetailItem>>((ref) {
  final rawAsync = ref.watch(callLogsDetailRawDataProvider);
  final items = rawAsync.value ?? const [];
  if (items.isEmpty) return const [];

  final selectedCity = ref.watch(callLogsDetailSelectedCityProvider);
  final selectedZone = ref.watch(callLogsDetailSelectedZoneProvider);
  final isHyderabad = isCityHyderabad(selectedCity);
  final effectiveZone = isHyderabad ? selectedZone : null;

  final selectedCategory = ref.watch(callLogsDetailSelectedCategoryProvider);
  final selectedFeedback = ref.watch(callLogsDetailFeedbackStatusFilterProvider);
  final searchQuery = ref.watch(callLogsDetailSearchQueryProvider).trim().toLowerCase();
  final sortColumn = ref.watch(callLogsDetailSortColumnProvider);
  final sortAscending = ref.watch(callLogsDetailSortAscendingProvider);

  // 1. Filter
  final filtered = items.where((item) {
    // Hyderabad Zone Filter (applied only when Hyderabad is selected and zone is chosen)
    if (effectiveZone != null && !item.matchesZone(effectiveZone)) {
      return false;
    }

    // Category Filter
    if (!_matchesCategory(item.category, selectedCategory)) {
      return false;
    }

    // Feedback Status Filter
    if (!_matchesFeedbackStatus(item.feedbackStatus, selectedFeedback)) {
      return false;
    }

    // Search Filter (Business name, phone number, provider UID / business ID)
    if (searchQuery.isNotEmpty) {
      final name = item.businessName.toLowerCase();
      final phone = item.businessPhone.toLowerCase();
      final caller = item.callerPhone.toLowerCase();
      final bId = item.businessId.toLowerCase();
      final city = item.city.toLowerCase();
      final cat = item.category.toLowerCase();

      final matches = name.contains(searchQuery) ||
          phone.contains(searchQuery) ||
          caller.contains(searchQuery) ||
          bId.contains(searchQuery) ||
          city.contains(searchQuery) ||
          cat.contains(searchQuery);

      if (!matches) return false;
    }

    return true;
  }).toList();

  // 2. Sort
  filtered.sort((a, b) {
    int comparison = 0;
    switch (sortColumn) {
      case CallLogsDetailSortColumn.callDate:
        final aTs = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTs = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        comparison = aTs.compareTo(bTs);
        break;
      case CallLogsDetailSortColumn.businessName:
        comparison = a.businessName.toLowerCase().compareTo(b.businessName.toLowerCase());
        break;
      case CallLogsDetailSortColumn.callsAfterPayment:
        comparison = a.callsAfterPayment.compareTo(b.callsAfterPayment);
        break;
      case CallLogsDetailSortColumn.city:
        comparison = a.city.toLowerCase().compareTo(b.city.toLowerCase());
        break;
      case CallLogsDetailSortColumn.category:
        comparison = a.category.toLowerCase().compareTo(b.category.toLowerCase());
        break;
      case CallLogsDetailSortColumn.slNo:
        comparison = 0;
        break;
    }
    return sortAscending ? comparison : -comparison;
  });

  return filtered;
});

/// Pagination bundle containing current page slice and paging metadata
class CallLogsDetailPaginationData {
  final List<CallLogsDetailItem> pageItems;
  final int totalItems;
  final int totalPages;
  final int currentPage;
  final int pageSize;
  final int startIndex;
  final int endIndex;

  const CallLogsDetailPaginationData({
    required this.pageItems,
    required this.totalItems,
    required this.totalPages,
    required this.currentPage,
    required this.pageSize,
    required this.startIndex,
    required this.endIndex,
  });

  bool get hasPreviousPage => currentPage > 0;
  bool get hasNextPage => currentPage < totalPages - 1;
}

/// Provides paginated slice of filtered call logs
final callLogsDetailPaginationProvider = Provider<CallLogsDetailPaginationData>((ref) {
  final filteredItems = ref.watch(callLogsDetailFilteredItemsProvider);
  final pageSize = ref.watch(callLogsDetailPageSizeProvider);
  final requestedPage = ref.watch(callLogsDetailCurrentPageProvider);

  final totalItems = filteredItems.length;
  final totalPages = max(1, (totalItems / pageSize).ceil());
  final currentPage = requestedPage.clamp(0, totalPages - 1);

  final start = currentPage * pageSize;
  final end = min(start + pageSize, totalItems);

  final pageItems = (totalItems > 0 && start < totalItems)
      ? filteredItems.sublist(start, end)
      : <CallLogsDetailItem>[];

  return CallLogsDetailPaginationData(
    pageItems: pageItems,
    totalItems: totalItems,
    totalPages: totalPages,
    currentPage: currentPage,
    pageSize: pageSize,
    startIndex: totalItems > 0 ? start + 1 : 0,
    endIndex: end,
  );
});
