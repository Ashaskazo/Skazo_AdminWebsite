import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/payment_record.dart';
import 'package:skazo_admin/models/revenue_analytics_model.dart';
import 'package:skazo_admin/repositories/revenue_repository.dart';
import 'package:skazo_admin/providers/collections_provider.dart';

/// Tabs available inside the Payments & Revenue Command Center.
enum RevenueDashboardTab {
  overview,
  streams,
  cities,
  categories,
  transactions,
  reconciliation,
  linkSender,
}

extension RevenueDashboardTabExtension on RevenueDashboardTab {
  String get title {
    switch (this) {
      case RevenueDashboardTab.overview:
        return 'Overview';
      case RevenueDashboardTab.streams:
        return 'Revenue Streams';
      case RevenueDashboardTab.cities:
        return 'City Wise';
      case RevenueDashboardTab.categories:
        return 'Category Wise';
      case RevenueDashboardTab.transactions:
        return 'Transactions Ledger';
      case RevenueDashboardTab.reconciliation:
        return 'Razorpay Reconciliation';
      case RevenueDashboardTab.linkSender:
        return 'Payment Link Operations';
    }
  }
}

/// Repository provider.
final revenueRepositoryProvider = Provider<RevenueRepository>((ref) {
  return RevenueRepository();
});

/// Active dashboard tab.
final revenueActiveTabProvider = StateProvider<RevenueDashboardTab>((ref) {
  return RevenueDashboardTab.overview;
});

/// Global filter provider for all payments and analytics views.
final revenueFilterProvider = StateProvider<RevenueFilter>((ref) {
  return const RevenueFilter();
});

/// Raw payment records across all 4 collections (cached in memory).
final revenueRawRecordsProvider = FutureProvider<List<PaymentRecord>>((
  ref,
) async {
  final repo = ref.watch(revenueRepositoryProvider);
  final pincodesMap = await ref.watch(propertyPincodesProvider.future);
  return repo.fetchAllPaymentRecords(pincodesMap: pincodesMap);
});

/// In-memory computed analytics data reflecting the current filter.
final revenueAnalyticsDataProvider = Provider<AsyncValue<RevenueAnalyticsData>>(
  (ref) {
    final rawAsync = ref.watch(revenueRawRecordsProvider);
    final filter = ref.watch(revenueFilterProvider);
    final repo = ref.watch(revenueRepositoryProvider);

    return rawAsync.when(
      data: (records) {
        final analytics = repo.computeAnalytics(records, filter);
        return AsyncValue.data(analytics);
      },
      loading: () => const AsyncValue.loading(),
      error: (err, stack) => AsyncValue.error(err, stack),
    );
  },
);

/// Selected payment record for detailed row-click drawer/modal inspection.
final revenueSelectedRecordForDrawerProvider = StateProvider<PaymentRecord?>(
  (ref) => null,
);

/// Page index for transaction table pagination.
final revenueTransactionPageProvider = StateProvider<int>((ref) => 0);

/// Page size for transaction table pagination.
final revenueTransactionPageSizeProvider = StateProvider<int>((ref) => 25);

// ===========================================================================
// CATEGORY WISE LOCAL STATE
// Keeps local stream/city/drilldown state inside the Category Wise tab so that
// the global RevenueFilter.selectedCategory is never set to a single value
// (which would break the category-card overview).
// ===========================================================================

/// Local state for the Category Wise Revenue tab.
class CategoryWiseLocalState {
  /// The category the user clicked to drill into (null = show all cards).
  final String? selectedCategory;

  /// Local stream filter — null means "All Streams".
  final PaymentStream? localStream;

  /// Local city filter — null means "All Cities".
  final String? localCity;

  const CategoryWiseLocalState({
    this.selectedCategory,
    this.localStream,
    this.localCity,
  });

  CategoryWiseLocalState copyWith({
    String? selectedCategory,
    bool clearCategory = false,
    PaymentStream? localStream,
    bool clearStream = false,
    String? localCity,
    bool clearCity = false,
  }) {
    return CategoryWiseLocalState(
      selectedCategory:
          clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      localStream: clearStream ? null : (localStream ?? this.localStream),
      localCity: clearCity ? null : (localCity ?? this.localCity),
    );
  }
}

/// Provider for local Category Wise tab state.
final categoryWiseLocalStateProvider = StateProvider<CategoryWiseLocalState>((
  ref,
) {
  return const CategoryWiseLocalState();
});
