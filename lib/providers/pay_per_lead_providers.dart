
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/repositories/user_repository.dart';

import '../services/plan_classification_service.dart';

/// Sort order for Pay Per Lead Payment Date.
enum PayPerLeadSortOrder {
  newest,
  oldest,
}

/// Read-only state for Pay Per Lead providers.
class PayPerLeadPaginationState {
  final List<UserModel> providers;

  final bool isLoading;
  final bool isLoadingPage;

  final String? errorMessage;

  final int currentPage;
  final int pageSize;

  /// Total number of providers matching the current filters.
  final int? totalCount;

  /// Total outstanding Bill Balance across ALL matching providers.
  final num? totalBillBalance;

  /// Whether another local page exists.
  final bool hasNextPage;

  final String? selectedCity;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  final PayPerLeadSortOrder sortOrder;

  const PayPerLeadPaginationState({
    this.providers = const [],
    this.isLoading = false,
    this.isLoadingPage = false,
    this.errorMessage,
    this.currentPage = 0,
    this.pageSize = 20,
    this.totalCount,
    this.totalBillBalance,
    this.hasNextPage = false,
    this.selectedCity,
    this.dateFrom,
    this.dateTo,
    this.sortOrder = PayPerLeadSortOrder.newest,
  });

  const PayPerLeadPaginationState.initial()
      : providers = const [],
        isLoading = true,
        isLoadingPage = false,
        errorMessage = null,
        currentPage = 0,
        pageSize = 20,
        totalCount = null,
        totalBillBalance = null,
        hasNextPage = false,
        selectedCity = null,
        dateFrom = null,
        dateTo = null,
        sortOrder = PayPerLeadSortOrder.newest;

  bool get sortDescending =>
      sortOrder == PayPerLeadSortOrder.newest;

  PayPerLeadPaginationState copyWith({
    List<UserModel>? providers,
    bool? isLoading,
    bool? isLoadingPage,
    String? errorMessage,
    bool clearError = false,

    int? currentPage,
    int? pageSize,

    int? totalCount,
    bool clearCounts = false,

    num? totalBillBalance,
    bool clearTotalBillBalance = false,

    bool? hasNextPage,

    String? selectedCity,
    bool clearCity = false,

    DateTime? dateFrom,
    bool clearDateFrom = false,

    DateTime? dateTo,
    bool clearDateTo = false,

    PayPerLeadSortOrder? sortOrder,
  }) {
    return PayPerLeadPaginationState(
      providers: providers ?? this.providers,

      isLoading: isLoading ?? this.isLoading,
      isLoadingPage: isLoadingPage ?? this.isLoadingPage,

      errorMessage: clearError
          ? null
          : (errorMessage ?? this.errorMessage),

      currentPage: currentPage ?? this.currentPage,
      pageSize: pageSize ?? this.pageSize,

      totalCount: clearCounts
          ? null
          : (totalCount ?? this.totalCount),

      totalBillBalance: clearTotalBillBalance
          ? null
          : (totalBillBalance ?? this.totalBillBalance),

      hasNextPage:
          hasNextPage ?? this.hasNextPage,

      selectedCity: clearCity
          ? null
          : (selectedCity ?? this.selectedCity),

      dateFrom: clearDateFrom
          ? null
          : (dateFrom ?? this.dateFrom),

      dateTo: clearDateTo
          ? null
          : (dateTo ?? this.dateTo),

      sortOrder:
          sortOrder ?? this.sortOrder,
    );
  }
}

///
/// Pay Per Lead pagination.
///
/// IMPORTANT ARCHITECTURE:
///
/// Firestore is queried ONCE when filters are applied.
///
/// All matching providers are stored privately in [_allProviders].
///
/// UI receives only 20 records through [state.providers].
///
/// Pagination after the initial load is LOCAL.
/// Therefore:
///
/// Page 1 -> Firestore read
/// Page 2 -> NO Firestore read
/// Page 3 -> NO Firestore read
/// ...
///
/// This also allows us to calculate the overall Bill Balance
/// across every matching provider without using Firestore
/// aggregation queries.
///
class PayPerLeadPaginationNotifier
    extends StateNotifier<PayPerLeadPaginationState> {
  final Ref ref;

  int _requestId = 0;

  bool _disposed = false;

  /// Complete filtered dataset currently loaded in memory.
  ///
  /// Example:
  /// 260 matching providers
  /// -> _allProviders contains all 260
  /// -> state.providers contains only 20
  final List<UserModel> _allProviders = <UserModel>[];

  PayPerLeadPaginationNotifier(this.ref)
      : super(
          const PayPerLeadPaginationState.initial(),
        ) {
    fetchInitial();
  }

  // ------------------------------------------------------------
  // INITIAL LOAD
  // ------------------------------------------------------------

  Future<void> fetchInitial() async {
    await applyFilters(
      city: state.selectedCity,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      sortOrder: state.sortOrder,
    );
  }

  // ------------------------------------------------------------
  // APPLY FILTERS
  // ------------------------------------------------------------

  Future<void> applyFilters({
    String? city,
    DateTime? dateFrom,
    DateTime? dateTo,
    PayPerLeadSortOrder? sortOrder,
  }) async {
    if (_disposed) {
      return;
    }

    final int requestId = ++_requestId;

    final PayPerLeadSortOrder resolvedSort =
        sortOrder ?? state.sortOrder;

    // ----------------------------------------------------------
    // CLEAR OLD MEMORY DATA
    // ----------------------------------------------------------

    _allProviders.clear();

    // ----------------------------------------------------------
    // RESET STATE
    // ----------------------------------------------------------

    state = state.copyWith(
      isLoading: true,
      isLoadingPage: false,
      clearError: true,

      currentPage: 0,

      providers: const [],

      selectedCity: city,
      dateFrom: dateFrom,
      dateTo: dateTo,

      clearCounts: true,
      clearTotalBillBalance: true,

      hasNextPage: false,

      sortOrder: resolvedSort,
    );

    final UserRepository repo =
        ref.read(userRepositoryProvider);

    final scope = ref.read(cityAccessScopeProvider);
    if (!scope.isAuthorized) {
      _allProviders.clear();
      state = state.copyWith(
        isLoading: false,
        isLoadingPage: false,
        providers: const [],
        totalCount: 0,
        totalBillBalance: 0,
        currentPage: 0,
        hasNextPage: false,
        clearError: true,
      );
      return;
    }

    try {
      final List<UserModel> fetchedProviders =
          await repo.fetchAllPayPerLeadProviders(
        selectedCity: city,
        dateFrom: dateFrom,
        dateTo: dateTo,
        assignedCities: scope.assignedCities,
        isSuperAdmin: scope.isUnrestricted,
        sortDescending:
            resolvedSort ==
                PayPerLeadSortOrder.newest,
      );

/// ------------------------------------------------------------
/// PREMIUM CATEGORY FILTER
/// ------------------------------------------------------------
///
/// Pay Per Lead is shown ONLY for Premium categories.
///
/// Required conditions:
/// 1. Provider must already satisfy the repository's
///    Pay Per Lead condition (isuser == false + charge > 0).
/// 2. Provider category must be one of the explicitly
///    configured Premium categories.
///
/// Plan/payment/verification status must NOT make a
/// non-Premium category Premium.
final List<UserModel> allProviders =
    fetchedProviders.where((provider) {
  final hasCharge = (provider.payperLeadCharge ?? 0) > 0;
  return hasCharge && PlanClassificationService.isPremium(provider);
}).toList();

      // Ensure in-memory sorting by payment date according to resolvedSort
      allProviders.sort((a, b) {
        final aDate = a.lastpaymentpayperlead;
        final bDate = b.lastpaymentpayperlead;
        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;
        return resolvedSort == PayPerLeadSortOrder.newest
            ? bDate.compareTo(aDate)
            : aDate.compareTo(bDate);
      });

      if (_disposed ||
          requestId != _requestId) {
        return;
      }

      // --------------------------------------------------------
      // STORE COMPLETE DATASET
      // --------------------------------------------------------

      _allProviders
        ..clear()
        ..addAll(allProviders);

      // --------------------------------------------------------
      // CALCULATE TOTAL BILL BALANCE
      // --------------------------------------------------------
      //
      // This happens entirely in Flutter memory.
      //
      // No Firestore aggregate query.
      // No additional Firestore read.
      //
      num totalBillBalance = 0;

      for (final UserModel provider in _allProviders) {
        totalBillBalance +=
            provider.payperLeadCharge ?? 0;
      }

      // --------------------------------------------------------
      // FIRST PAGE
      // --------------------------------------------------------

      final List<UserModel> firstPage =
          _getPage(0);

      final bool hasNext =
          _hasPage(1);

      // --------------------------------------------------------
      // UPDATE STATE
      // --------------------------------------------------------

      state = state.copyWith(
        isLoading: false,
        isLoadingPage: false,

        providers: firstPage,

        totalCount: _allProviders.length,

        totalBillBalance: totalBillBalance,

        currentPage: 0,

        hasNextPage: hasNext,

        clearError: true,
      );
    } catch (e) {
      if (_disposed ||
          requestId != _requestId) {
        return;
      }

      _allProviders.clear();

      state = state.copyWith(
        isLoading: false,
        isLoadingPage: false,
        errorMessage: _cleanError(e),
      );
    }
  }

  // ------------------------------------------------------------
  // SORT
  // ------------------------------------------------------------

  Future<void> changeSortOrder(
    PayPerLeadSortOrder newOrder,
  ) async {
    if (_disposed) {
      return;
    }

    if (newOrder == state.sortOrder) {
      return;
    }

    await applyFilters(
      city: state.selectedCity,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      sortOrder: newOrder,
    );
  }

  // ------------------------------------------------------------
  // CLEAR FILTERS
  // ------------------------------------------------------------

  Future<void> clearFilters() async {
    await applyFilters(
      city: null,
      dateFrom: null,
      dateTo: null,
      sortOrder: PayPerLeadSortOrder.newest,
    );
  }

  // ------------------------------------------------------------
  // NEXT PAGE
  // ------------------------------------------------------------

  Future<void> nextPage() async {
    if (_disposed) {
      return;
    }

    if (state.isLoading ||
        state.isLoadingPage) {
      return;
    }

    final int nextPage =
        state.currentPage + 1;

    if (!_hasPage(nextPage)) {
      return;
    }

    await _showLocalPage(nextPage);
  }

  // ------------------------------------------------------------
  // PREVIOUS PAGE
  // ------------------------------------------------------------

  Future<void> prevPage() async {
    if (_disposed) {
      return;
    }

    if (state.isLoading ||
        state.isLoadingPage) {
      return;
    }

    if (state.currentPage <= 0) {
      return;
    }

    final int previousPage =
        state.currentPage - 1;

    await _showLocalPage(previousPage);
  }

  // ------------------------------------------------------------
  // LOCAL PAGE
  // ------------------------------------------------------------

  Future<void> _showLocalPage(
    int pageIndex,
  ) async {
    if (_disposed) {
      return;
    }

    final int requestId = ++_requestId;

    if (pageIndex < 0) {
      return;
    }

    if (!_hasPage(pageIndex)) {
      return;
    }

    // ----------------------------------------------------------
    // Keep existing page visible while changing page.
    // ----------------------------------------------------------

    state = state.copyWith(
      isLoadingPage: true,
      clearError: true,
    );

    // ----------------------------------------------------------
    // No Firestore call here.
    // ----------------------------------------------------------

    await Future<void>.delayed(
      Duration.zero,
    );

    if (_disposed ||
        requestId != _requestId) {
      return;
    }

    final List<UserModel> page =
        _getPage(pageIndex);

    state = state.copyWith(
      isLoadingPage: false,

      providers: page,

      currentPage: pageIndex,

      hasNextPage:
          _hasPage(pageIndex + 1),

      clearError: true,
    );
  }

  // ------------------------------------------------------------
  // GET PAGE FROM MEMORY
  // ------------------------------------------------------------

  List<UserModel> _getPage(
    int pageIndex,
  ) {
    if (pageIndex < 0) {
      return const <UserModel>[];
    }

    final int start =
        pageIndex * state.pageSize;

    if (start >= _allProviders.length) {
      return const <UserModel>[];
    }

    final int end =
        (start + state.pageSize)
            .clamp(
              0,
              _allProviders.length,
            );

    return List<UserModel>.unmodifiable(
      _allProviders.sublist(start, end),
    );
  }

  // ------------------------------------------------------------
  // CHECK PAGE
  // ------------------------------------------------------------

  bool _hasPage(int pageIndex) {
    final int start =
        pageIndex * state.pageSize;

    return start < _allProviders.length;
  }

  // ------------------------------------------------------------
  // REFRESH
  // ------------------------------------------------------------

  Future<void> reloadForScopeChange() async {
    if (_disposed) {
      return;
    }
    await applyFilters(
      city: state.selectedCity,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      sortOrder: state.sortOrder,
    );
  }

  Future<void> refresh() async {
    if (_disposed) {
      return;
    }

    if (state.isLoading ||
        state.isLoadingPage) {
      return;
    }

    // ----------------------------------------------------------
    // Refresh means reload the FILTERED DATASET.
    //
    // This is intentional because Bill Balance may have changed.
    // ----------------------------------------------------------

    await applyFilters(
      city: state.selectedCity,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      sortOrder: state.sortOrder,
    );
  }

  // ------------------------------------------------------------
  // UPDATE FEEDBACK IN MEMORY
  // ------------------------------------------------------------

  void updateProviderFeedback(String userId, String feedback) {
    final trimmed = feedback.trim();

    // Update in the complete in-memory list
    final allIdx = _allProviders.indexWhere((u) => u.id == userId);
    if (allIdx != -1) {
      _allProviders[allIdx] = _allProviders[allIdx].copyWith(
        payPerLeadFeedback: trimmed,
      );
    }

    // Update in current page items
    final stateIdx = state.providers.indexWhere((u) => u.id == userId);
    if (stateIdx != -1) {
      final updatedList = List<UserModel>.from(state.providers);
      updatedList[stateIdx] = updatedList[stateIdx].copyWith(
        payPerLeadFeedback: trimmed,
      );
      state = state.copyWith(providers: updatedList);
    }
  }

  // ------------------------------------------------------------
  // ERROR CLEANUP
  // ------------------------------------------------------------

  String _cleanError(Object error) {
    final String message =
        error.toString().trim();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ------------------------------------------------------------
  // DISPOSE
  // ------------------------------------------------------------

  @override
  void dispose() {
    _disposed = true;

    _requestId++;

    _allProviders.clear();

    super.dispose();
  }
}

// --------------------------------------------------------------
// RIVERPOD PROVIDER
// --------------------------------------------------------------

final payPerLeadPaginationProvider =
    StateNotifierProvider<
        PayPerLeadPaginationNotifier,
        PayPerLeadPaginationState>(
  (ref) {
    final notifier = PayPerLeadPaginationNotifier(ref);
    ref.listen(cityAccessScopeProvider, (_, __) {
      notifier.reloadForScopeChange();
    });
    return notifier;
  },
);