// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // import 'package:skazo_admin/models/user_model.dart';
// // import 'package:skazo_admin/providers/admin_providers.dart';
// // import 'package:skazo_admin/repositories/user_repository.dart';

// // /// Sort order for Pay Per Lead Payment Date.
// // enum PayPerLeadSortOrder { newest, oldest }

// // /// State for the read-only Pay Per Lead entity.
// // class PayPerLeadPaginationState {
// //   final List<UserModel> providers;
// //   final bool isLoading;
// //   final bool isLoadingPage;
// //   final String? errorMessage;
// //   final int currentPage;
// //   final int pageSize;
// //   final int? totalCount;
// //   final bool hasNextPage;
// //   final String? selectedCity;
// //   final DateTime? dateFrom;
// //   final DateTime? dateTo;
// //   final PayPerLeadSortOrder sortOrder;

// //   const PayPerLeadPaginationState({
// //     this.providers = const [],
// //     this.isLoading = false,
// //     this.isLoadingPage = false,
// //     this.errorMessage,
// //     this.currentPage = 0,
// //     this.pageSize = 20,
// //     this.totalCount,
// //     this.hasNextPage = false,
// //     this.selectedCity,
// //     this.dateFrom,
// //     this.dateTo,
// //     this.sortOrder = PayPerLeadSortOrder.newest,
// //   });

// //   const PayPerLeadPaginationState.initial()
// //       : providers = const [],
// //         isLoading = true,
// //         isLoadingPage = false,
// //         errorMessage = null,
// //         currentPage = 0,
// //         pageSize = 20,
// //         totalCount = null,
// //         hasNextPage = false,
// //         selectedCity = null,
// //         dateFrom = null,
// //         dateTo = null,
// //         sortOrder = PayPerLeadSortOrder.newest;

// //   bool get sortDescending => sortOrder == PayPerLeadSortOrder.newest;

// //   PayPerLeadPaginationState copyWith({
// //     List<UserModel>? providers,
// //     bool? isLoading,
// //     bool? isLoadingPage,
// //     String? errorMessage,
// //     bool clearError = false,
// //     int? currentPage,
// //     int? pageSize,
// //     int? totalCount,
// //     bool clearCounts = false,
// //     bool? hasNextPage,
// //     String? selectedCity,
// //     bool clearCity = false,
// //     DateTime? dateFrom,
// //     bool clearDateFrom = false,
// //     DateTime? dateTo,
// //     bool clearDateTo = false,
// //     PayPerLeadSortOrder? sortOrder,
// //   }) {
// //     return PayPerLeadPaginationState(
// //       providers: providers ?? this.providers,
// //       isLoading: isLoading ?? this.isLoading,
// //       isLoadingPage: isLoadingPage ?? this.isLoadingPage,
// //       errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
// //       currentPage: currentPage ?? this.currentPage,
// //       pageSize: pageSize ?? this.pageSize,
// //       totalCount: clearCounts ? null : (totalCount ?? this.totalCount),
// //       hasNextPage: hasNextPage ?? this.hasNextPage,
// //       selectedCity: clearCity ? null : (selectedCity ?? this.selectedCity),
// //       dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
// //       dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
// //       sortOrder: sortOrder ?? this.sortOrder,
// //     );
// //   }
// // }

// // /// Riverpod StateNotifier for cursor-based pagination of Pay Per Lead providers.
// // /// Only providers with payperLeadcharge > 0 are returned (server-side filtered).
// // class PayPerLeadPaginationNotifier
// //     extends StateNotifier<PayPerLeadPaginationState> {
// //   final Ref ref;
// //   int _requestId = 0;
// //   final List<DocumentSnapshot<Map<String, dynamic>>?> _pageCursors = [null];

// //   PayPerLeadPaginationNotifier(this.ref)
// //       : super(const PayPerLeadPaginationState.initial()) {
// //     fetchInitial();
// //   }

// //   int get currentPage => state.currentPage;
// //   int get pageSize => state.pageSize;
// //   int get totalCount => state.totalCount ?? 0;

// //   Future<void> fetchInitial() async {
// //     await applyFilters(
// //       city: state.selectedCity,
// //       dateFrom: state.dateFrom,
// //       dateTo: state.dateTo,
// //       sortOrder: state.sortOrder,
// //     );
// //   }

// //   /// Applies city, date, and sort filters. Executes count() once for the filter
// //   /// set, resets cursors to page 0, and loads the first page.
// //   Future<void> applyFilters({
// //     String? city,
// //     DateTime? dateFrom,
// //     DateTime? dateTo,
// //     PayPerLeadSortOrder? sortOrder,
// //   }) async {
// //     _requestId++;
// //     final requestId = _requestId;

// //     _pageCursors.clear();
// //     _pageCursors.add(null);

// //     final resolvedSort = sortOrder ?? state.sortOrder;

// //     state = state.copyWith(
// //       isLoading: true,
// //       isLoadingPage: false,
// //       clearError: true,
// //       currentPage: 0,
// //       providers: const [],
// //       selectedCity: city,
// //       dateFrom: dateFrom,
// //       dateTo: dateTo,
// //       clearCounts: true,
// //       sortOrder: resolvedSort,
// //     );

// //     final repo = ref.read(userRepositoryProvider);
// //     final isSuper = ref.read(isSuperAdminProvider);
// //     final assignedCities = isSuper
// //         ? const <String>[]
// //         : ref.read(currentAdminAssignedCitiesProvider);

// //     try {
// //       // 1. Count once per filter/sort application
// //       final countFuture = repo.countPayPerLeadProviders(
// //         selectedCity: city,
// //         dateFrom: dateFrom,
// //         dateTo: dateTo,
// //         assignedCities: assignedCities,
// //         isSuperAdmin: isSuper,
// //       );

// //       // 2. Fetch page 0 (cursor null)
// //       final pageFuture = repo.fetchPayPerLeadProviders(
// //         selectedCity: city,
// //         dateFrom: dateFrom,
// //         dateTo: dateTo,
// //         assignedCities: assignedCities,
// //         isSuperAdmin: isSuper,
// //         sortDescending: resolvedSort == PayPerLeadSortOrder.newest,
// //         startAfter: null,
// //         limit: state.pageSize,
// //       );

// //       // Run both concurrently then await each typed future.
// //       await Future.wait<void>([
// //         countFuture.then((_) {}),
// //         pageFuture.then((_) {}),
// //       ]);

// //       if (requestId != _requestId) return; // Discard stale response

// //       final totalCount = await countFuture;
// //       final pageResult = await pageFuture;

// //       if (pageResult.hasMore && pageResult.lastDocument != null) {
// //         if (_pageCursors.length == 1) {
// //           _pageCursors.add(pageResult.lastDocument);
// //         }
// //       }

// //       state = state.copyWith(
// //         isLoading: false,
// //         providers: pageResult.items,
// //         totalCount: totalCount,
// //         hasNextPage: pageResult.hasMore,
// //         currentPage: 0,
// //         clearError: true,
// //       );
// //     } catch (e) {
// //       if (requestId != _requestId) return;
// //       state = state.copyWith(
// //         isLoading: false,
// //         errorMessage: e.toString(),
// //       );
// //     }
// //   }

// //   /// Changes sort order. Resets pagination and reloads from page 0.
// //   Future<void> changeSortOrder(PayPerLeadSortOrder newOrder) async {
// //     if (newOrder == state.sortOrder) return;
// //     await applyFilters(
// //       city: state.selectedCity,
// //       dateFrom: state.dateFrom,
// //       dateTo: state.dateTo,
// //       sortOrder: newOrder,
// //     );
// //   }

// //   /// Clears all filters, resets sort to default (newest), and reloads.
// //   Future<void> clearFilters() async {
// //     await applyFilters(
// //       city: null,
// //       dateFrom: null,
// //       dateTo: null,
// //       sortOrder: PayPerLeadSortOrder.newest,
// //     );
// //   }

// //   /// Navigates to the next page using cursor. Does NOT re-run count().
// //   Future<void> nextPage() async {
// //     if (state.isLoading || state.isLoadingPage || !state.hasNextPage) return;
// //     final targetPage = state.currentPage + 1;
// //     if (targetPage >= _pageCursors.length) return;

// //     await _fetchPage(targetPage);
// //   }

// //   /// Navigates to the previous page using cursor. Does NOT re-run count().
// //   Future<void> prevPage() async {
// //     if (state.isLoading || state.isLoadingPage || state.currentPage <= 0) return;
// //     final targetPage = state.currentPage - 1;
// //     await _fetchPage(targetPage);
// //   }

// //   /// Fetches a specific page index using the recorded cursor at index [pageIndex].
// //   Future<void> _fetchPage(int pageIndex) async {
// //     _requestId++;
// //     final requestId = _requestId;

// //     state = state.copyWith(isLoadingPage: true, clearError: true);

// //     final repo = ref.read(userRepositoryProvider);
// //     final isSuper = ref.read(isSuperAdminProvider);
// //     final assignedCities = isSuper
// //         ? const <String>[]
// //         : ref.read(currentAdminAssignedCitiesProvider);

// //     final cursor =
// //         (pageIndex < _pageCursors.length) ? _pageCursors[pageIndex] : null;

// //     try {
// //       final pageResult = await repo.fetchPayPerLeadProviders(
// //         selectedCity: state.selectedCity,
// //         dateFrom: state.dateFrom,
// //         dateTo: state.dateTo,
// //         assignedCities: assignedCities,
// //         isSuperAdmin: isSuper,
// //         sortDescending: state.sortDescending,
// //         startAfter: cursor,
// //         limit: state.pageSize,
// //       );

// //       if (requestId != _requestId) return; // Discard stale response

// //       // Record cursor for the next page if not already recorded
// //       if (pageResult.hasMore && pageResult.lastDocument != null) {
// //         if (pageIndex + 1 == _pageCursors.length) {
// //           _pageCursors.add(pageResult.lastDocument);
// //         }
// //       }

// //       state = state.copyWith(
// //         isLoadingPage: false,
// //         providers: pageResult.items,
// //         currentPage: pageIndex,
// //         hasNextPage: pageResult.hasMore,
// //         clearError: true,
// //       );
// //     } catch (e) {
// //       if (requestId != _requestId) return;
// //       state = state.copyWith(
// //         isLoadingPage: false,
// //         errorMessage: e.toString(),
// //       );
// //     }
// //   }

// //   /// Reloads the current page without resetting filters, sort, or cursors.
// //   Future<void> refresh() async {
// //     await _fetchPage(state.currentPage);
// //   }
// // }

// // final payPerLeadPaginationProvider = StateNotifierProvider<
// //     PayPerLeadPaginationNotifier, PayPerLeadPaginationState>((ref) {
// //   return PayPerLeadPaginationNotifier(ref);
// // });

// // import 'package:cloud_firestore/cloud_firestore.dart';
// // import 'package:flutter_riverpod/flutter_riverpod.dart';
// // import 'package:skazo_admin/models/user_model.dart';
// // import 'package:skazo_admin/providers/admin_providers.dart';
// // import 'package:skazo_admin/repositories/user_repository.dart';

// // /// Sort order for Pay Per Lead Payment Date.
// // enum PayPerLeadSortOrder {
// //   newest,
// //   oldest,
// // }

// // /// Read-only pagination state for Pay Per Lead providers.
// // ///
// // /// Important pagination rules:
// // /// - Page 0 always uses cursor null.
// // /// - Cursor at index N is the last document of page N - 1.
// // /// - Therefore:
// // ///     page 0 -> cursor[0] = null
// // ///     page 1 -> cursor[1] = last document from page 0
// // ///     page 2 -> cursor[2] = last document from page 1
// // /// - Changing filters/sort completely resets pagination.
// // class PayPerLeadPaginationState {
// //   final List<UserModel> providers;

// //   final bool isLoading;
// //   final bool isLoadingPage;

// //   final String? errorMessage;

// //   final int currentPage;
// //   final int pageSize;

// //   final int? totalCount;
// //   final bool hasNextPage;

// //   final String? selectedCity;
// //   final DateTime? dateFrom;
// //   final DateTime? dateTo;

// //   final PayPerLeadSortOrder sortOrder;

// //   const PayPerLeadPaginationState({
// //     this.providers = const [],
// //     this.isLoading = false,
// //     this.isLoadingPage = false,
// //     this.errorMessage,
// //     this.currentPage = 0,
// //     this.pageSize = 20,
// //     this.totalCount,
// //     this.hasNextPage = false,
// //     this.selectedCity,
// //     this.dateFrom,
// //     this.dateTo,
// //     this.sortOrder = PayPerLeadSortOrder.newest,
// //   });

// //   const PayPerLeadPaginationState.initial()
// //       : providers = const [],
// //         isLoading = true,
// //         isLoadingPage = false,
// //         errorMessage = null,
// //         currentPage = 0,
// //         pageSize = 20,
// //         totalCount = null,
// //         hasNextPage = false,
// //         selectedCity = null,
// //         dateFrom = null,
// //         dateTo = null,
// //         sortOrder = PayPerLeadSortOrder.newest;

// //   bool get sortDescending =>
// //       sortOrder == PayPerLeadSortOrder.newest;

// //   PayPerLeadPaginationState copyWith({
// //     List<UserModel>? providers,
// //     bool? isLoading,
// //     bool? isLoadingPage,
// //     String? errorMessage,
// //     bool clearError = false,

// //     int? currentPage,
// //     int? pageSize,

// //     int? totalCount,
// //     bool clearCounts = false,

// //     bool? hasNextPage,

// //     String? selectedCity,
// //     bool clearCity = false,

// //     DateTime? dateFrom,
// //     bool clearDateFrom = false,

// //     DateTime? dateTo,
// //     bool clearDateTo = false,

// //     PayPerLeadSortOrder? sortOrder,
// //   }) {
// //     return PayPerLeadPaginationState(
// //       providers: providers ?? this.providers,

// //       isLoading: isLoading ?? this.isLoading,
// //       isLoadingPage: isLoadingPage ?? this.isLoadingPage,

// //       errorMessage:
// //           clearError ? null : (errorMessage ?? this.errorMessage),

// //       currentPage: currentPage ?? this.currentPage,
// //       pageSize: pageSize ?? this.pageSize,

// //       totalCount:
// //           clearCounts ? null : (totalCount ?? this.totalCount),

// //       hasNextPage:
// //           hasNextPage ?? this.hasNextPage,

// //       selectedCity:
// //           clearCity ? null : (selectedCity ?? this.selectedCity),

// //       dateFrom:
// //           clearDateFrom ? null : (dateFrom ?? this.dateFrom),

// //       dateTo:
// //           clearDateTo ? null : (dateTo ?? this.dateTo),

// //       sortOrder:
// //           sortOrder ?? this.sortOrder,
// //     );
// //   }
// // }

// // /// Cursor-based Pay Per Lead pagination.
// // ///
// // /// This notifier intentionally does NOT cache all pages.
// // /// It only stores the Firestore document cursor required
// // /// to navigate backward/forward.
// // class PayPerLeadPaginationNotifier
// //     extends StateNotifier<PayPerLeadPaginationState> {
// //   final Ref ref;

// //   /// Used to invalidate old asynchronous requests.
// //   int _requestId = 0;

// //   /// Cursor boundaries.
// //   ///
// //   /// Example:
// //   ///
// //   /// [_pageCursors[0]] = null
// //   /// [_pageCursors[1]] = last document of page 0
// //   /// [_pageCursors[2]] = last document of page 1
// //   /// [_pageCursors[3]] = last document of page 2
// //   final List<DocumentSnapshot<Map<String, dynamic>>?> _pageCursors = [
// //     null,
// //   ];

// //   bool _disposed = false;

// //   PayPerLeadPaginationNotifier(this.ref)
// //       : super(const PayPerLeadPaginationState.initial()) {
// //     fetchInitial();
// //   }

// //   int get currentPage => state.currentPage;

// //   int get pageSize => state.pageSize;

// //   int get totalCount => state.totalCount ?? 0;

// //   /// ------------------------------------------------------------
// //   /// INITIAL LOAD
// //   /// ------------------------------------------------------------

// //   Future<void> fetchInitial() async {
// //     await applyFilters(
// //       city: state.selectedCity,
// //       dateFrom: state.dateFrom,
// //       dateTo: state.dateTo,
// //       sortOrder: state.sortOrder,
// //     );
// //   }

// //   /// ------------------------------------------------------------
// //   /// APPLY FILTERS
// //   /// ------------------------------------------------------------

// //   Future<void> applyFilters({
// //     String? city,
// //     DateTime? dateFrom,
// //     DateTime? dateTo,
// //     PayPerLeadSortOrder? sortOrder,
// //   }) async {
// //     final int requestId = ++_requestId;

// //     final resolvedSort =
// //         sortOrder ?? state.sortOrder;

// //     /// Completely reset pagination.
// //     _pageCursors
// //       ..clear()
// //       ..add(null);

// //     state = state.copyWith(
// //       isLoading: true,
// //       isLoadingPage: false,
// //       clearError: true,
// //       currentPage: 0,

// //       /// Clear old results ONLY when applying a new filter.
// //       providers: const [],

// //       selectedCity: city,
// //       dateFrom: dateFrom,
// //       dateTo: dateTo,

// //       clearCounts: true,

// //       hasNextPage: false,

// //       sortOrder: resolvedSort,
// //     );

// //     final repo = ref.read(userRepositoryProvider);

// //     final bool isSuperAdmin =
// //         ref.read(isSuperAdminProvider);

// //     final List<String> assignedCities =
// //         isSuperAdmin
// //             ? const <String>[]
// //             : ref.read(currentAdminAssignedCitiesProvider);

// //     try {
// //       /// Count and first page can execute concurrently.
// //       final countFuture =
// //           repo.countPayPerLeadProviders(
// //         selectedCity: city,
// //         dateFrom: dateFrom,
// //         dateTo: dateTo,
// //         assignedCities: assignedCities,
// //         isSuperAdmin: isSuperAdmin,
// //       );

// //       final pageFuture =
// //           repo.fetchPayPerLeadProviders(
// //         selectedCity: city,
// //         dateFrom: dateFrom,
// //         dateTo: dateTo,
// //         assignedCities: assignedCities,
// //         isSuperAdmin: isSuperAdmin,
// //         sortDescending:
// //             resolvedSort == PayPerLeadSortOrder.newest,
// //         startAfter: null,
// //         limit: state.pageSize,
// //       );

// //       final results =
// //           await Future.wait<dynamic>([
// //         countFuture,
// //         pageFuture,
// //       ]);

// //       if (_disposed || requestId != _requestId) {
// //         return;
// //       }

// //       final int totalCount =
// //           results[0] as int;

// //       final pageResult =
// //           results[1];

// //       /// Save cursor for page 1.
// //       ///
// //       /// pageCursors[1] = last document of page 0.
// //       if (pageResult.hasMore &&
// //           pageResult.lastDocument != null) {
// //         _setCursor(
// //           pageIndex: 1,
// //           cursor: pageResult.lastDocument,
// //         );
// //       }

// //       if (_disposed || requestId != _requestId) {
// //         return;
// //       }

// //       state = state.copyWith(
// //         isLoading: false,
// //         isLoadingPage: false,

// //         providers: pageResult.items,

// //         totalCount: totalCount,

// //         currentPage: 0,

// //         hasNextPage: pageResult.hasMore,

// //         clearError: true,
// //       );
// //     } catch (e) {
// //       if (_disposed || requestId != _requestId) {
// //         return;
// //       }

// //       state = state.copyWith(
// //         isLoading: false,
// //         isLoadingPage: false,
// //         errorMessage: _cleanError(e),
// //       );
// //     }
// //   }

// //   /// ------------------------------------------------------------
// //   /// SORT
// //   /// ------------------------------------------------------------

// //   Future<void> changeSortOrder(
// //     PayPerLeadSortOrder newOrder,
// //   ) async {
// //     if (newOrder == state.sortOrder) {
// //       return;
// //     }

// //     await applyFilters(
// //       city: state.selectedCity,
// //       dateFrom: state.dateFrom,
// //       dateTo: state.dateTo,
// //       sortOrder: newOrder,
// //     );
// //   }

// //   /// ------------------------------------------------------------
// //   /// CLEAR FILTERS
// //   /// ------------------------------------------------------------

// //   Future<void> clearFilters() async {
// //     await applyFilters(
// //       city: null,
// //       dateFrom: null,
// //       dateTo: null,
// //       sortOrder: PayPerLeadSortOrder.newest,
// //     );
// //   }

// //   /// ------------------------------------------------------------
// //   /// NEXT PAGE
// //   /// ------------------------------------------------------------

// //   Future<void> nextPage() async {
// //     if (_disposed) {
// //       return;
// //     }

// //     /// Never allow another page request while one is running.
// //     if (state.isLoading ||
// //         state.isLoadingPage) {
// //       return;
// //     }

// //     if (!state.hasNextPage) {
// //       return;
// //     }

// //     final int targetPage =
// //         state.currentPage + 1;

// //     /// We must have the cursor for this page.
// //     if (targetPage >= _pageCursors.length) {
// //       return;
// //     }

// //     await _fetchPage(targetPage);
// //   }

// //   /// ------------------------------------------------------------
// //   /// PREVIOUS PAGE
// //   /// ------------------------------------------------------------

// //   Future<void> prevPage() async {
// //     if (_disposed) {
// //       return;
// //     }

// //     if (state.isLoading ||
// //         state.isLoadingPage) {
// //       return;
// //     }

// //     if (state.currentPage <= 0) {
// //       return;
// //     }

// //     final int targetPage =
// //         state.currentPage - 1;

// //     await _fetchPage(targetPage);
// //   }

// //   /// ------------------------------------------------------------
// //   /// FETCH PAGE
// //   /// ------------------------------------------------------------

// //   Future<void> _fetchPage(
// //     int pageIndex,
// //   ) async {
// //     if (_disposed) {
// //       return;
// //     }

// //     final int requestId = ++_requestId;

// //     /// Cursor must already exist.
// //     if (pageIndex >= _pageCursors.length) {
// //       return;
// //     }

// //     final cursor =
// //         _pageCursors[pageIndex];

// //     /// IMPORTANT:
// //     ///
// //     /// We DO NOT clear providers here.
// //     ///
// //     /// This keeps the current page visible while the next
// //     /// page is loading.
// //     state = state.copyWith(
// //       isLoadingPage: true,
// //       clearError: true,
// //     );

// //     final repo =
// //         ref.read(userRepositoryProvider);

// //     final bool isSuperAdmin =
// //         ref.read(isSuperAdminProvider);

// //     final List<String> assignedCities =
// //         isSuperAdmin
// //             ? const <String>[]
// //             : ref.read(currentAdminAssignedCitiesProvider);

// //     try {
// //       final pageResult =
// //           await repo.fetchPayPerLeadProviders(
// //         selectedCity: state.selectedCity,
// //         dateFrom: state.dateFrom,
// //         dateTo: state.dateTo,
// //         assignedCities: assignedCities,
// //         isSuperAdmin: isSuperAdmin,
// //         sortDescending: state.sortDescending,

// //         /// THIS is the critical pagination value.
// //         ///
// //         /// Page 0 -> null
// //         /// Page 1 -> last doc of page 0
// //         /// Page 2 -> last doc of page 1
// //         startAfter: cursor,

// //         limit: state.pageSize,
// //       );

// //       if (_disposed || requestId != _requestId) {
// //         return;
// //       }

// //       /// Save cursor for the following page.
// //       ///
// //       /// Example:
// //       /// pageIndex = 1
// //       /// lastDocument = last document of page 1
// //       ///
// //       /// Therefore:
// //       /// _pageCursors[2] = last document of page 1
// //       if (pageResult.hasMore &&
// //           pageResult.lastDocument != null) {
// //         _setCursor(
// //           pageIndex: pageIndex + 1,
// //           cursor: pageResult.lastDocument,
// //         );
// //       }

// //       if (_disposed || requestId != _requestId) {
// //         return;
// //       }

// //       state = state.copyWith(
// //         isLoadingPage: false,

// //         /// Replace results ONLY after the new page has
// //         /// successfully arrived.
// //         providers: pageResult.items,

// //         currentPage: pageIndex,

// //         hasNextPage: pageResult.hasMore,

// //         clearError: true,
// //       );
// //     } catch (e) {
// //       if (_disposed || requestId != _requestId) {
// //         return;
// //       }

// //       /// Keep the current page visible on error.
// //       state = state.copyWith(
// //         isLoadingPage: false,
// //         errorMessage: _cleanError(e),
// //       );
// //     }
// //   }

// //   /// ------------------------------------------------------------
// //   /// REFRESH
// //   /// ------------------------------------------------------------

// //   Future<void> refresh() async {
// //     if (_disposed) {
// //       return;
// //     }

// //     if (state.isLoadingPage) {
// //       return;
// //     }

// //     /// Reload current page.
// //     ///
// //     /// We intentionally do NOT reset filters.
// //     /// We intentionally do NOT run count().
// //     ///
// //     /// However, when refreshing page 0, we need null.
// //     /// When refreshing page N, we use cursor[N].
// //     await _fetchPage(
// //       state.currentPage,
// //     );
// //   }

// //   /// ------------------------------------------------------------
// //   /// CURSOR MANAGEMENT
// //   /// ------------------------------------------------------------

// //   void _setCursor({
// //     required int pageIndex,
// //     required DocumentSnapshot<Map<String, dynamic>>? cursor,
// //   }) {
// //     if (cursor == null) {
// //       return;
// //     }

// //     /// Make sure the list is large enough.
// //     while (_pageCursors.length <= pageIndex) {
// //       _pageCursors.add(null);
// //     }

// //     _pageCursors[pageIndex] = cursor;
// //   }

// //   /// ------------------------------------------------------------
// //   /// ERROR CLEANUP
// //   /// ------------------------------------------------------------

// //   String _cleanError(Object error) {
// //     final message = error.toString();

// //     if (message.startsWith('Exception: ')) {
// //       return message.substring(
// //         'Exception: '.length,
// //       );
// //     }

// //     return message;
// //   }

// //   /// ------------------------------------------------------------
// //   /// DISPOSE
// //   /// ------------------------------------------------------------

// //   @override
// //   void dispose() {
// //     _disposed = true;
// //     _requestId++;
// //     super.dispose();
// //   }
// // }

// // /// Riverpod provider.
// // final payPerLeadPaginationProvider =
// //     StateNotifierProvider<
// //         PayPerLeadPaginationNotifier,
// //         PayPerLeadPaginationState>(
// //   (ref) {
// //     return PayPerLeadPaginationNotifier(ref);
// //   },
// // );

// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:skazo_admin/models/user_model.dart';
// import 'package:skazo_admin/providers/admin_providers.dart';
// import 'package:skazo_admin/repositories/user_repository.dart';

// import '../models/page_result.dart';

// /// Sort order for Pay Per Lead Payment Date.
// enum PayPerLeadSortOrder {
//   newest,
//   oldest,
// }

// /// Read-only pagination state for Pay Per Lead providers.
// class PayPerLeadPaginationState {
//   final List<UserModel> providers;

//   /// Initial/filter loading.
//   final bool isLoading;

//   /// Next/previous/refresh page loading.
//   final bool isLoadingPage;

//   final String? errorMessage;

//   final int currentPage;
//   final int pageSize;

//   final int? totalCount;

//   /// True when another page is available.
//   final bool hasNextPage;

//   final String? selectedCity;
//   final DateTime? dateFrom;
//   final DateTime? dateTo;

//   final PayPerLeadSortOrder sortOrder;

//   const PayPerLeadPaginationState({
//     this.providers = const [],
//     this.isLoading = false,
//     this.isLoadingPage = false,
//     this.errorMessage,
//     this.currentPage = 0,
//     this.pageSize = 20,
//     this.totalCount,
//     this.hasNextPage = false,
//     this.selectedCity,
//     this.dateFrom,
//     this.dateTo,
//     this.sortOrder = PayPerLeadSortOrder.newest,
//   });

//   const PayPerLeadPaginationState.initial()
//       : providers = const [],
//         isLoading = true,
//         isLoadingPage = false,
//         errorMessage = null,
//         currentPage = 0,
//         pageSize = 20,
//         totalCount = null,
//         hasNextPage = false,
//         selectedCity = null,
//         dateFrom = null,
//         dateTo = null,
//         sortOrder = PayPerLeadSortOrder.newest;

//   bool get sortDescending =>
//       sortOrder == PayPerLeadSortOrder.newest;

//   PayPerLeadPaginationState copyWith({
//     List<UserModel>? providers,
//     bool? isLoading,
//     bool? isLoadingPage,
//     String? errorMessage,
//     bool clearError = false,

//     int? currentPage,
//     int? pageSize,

//     int? totalCount,
//     bool clearCounts = false,

//     bool? hasNextPage,

//     String? selectedCity,
//     bool clearCity = false,

//     DateTime? dateFrom,
//     bool clearDateFrom = false,

//     DateTime? dateTo,
//     bool clearDateTo = false,

//     PayPerLeadSortOrder? sortOrder,
//   }) {
//     return PayPerLeadPaginationState(
//       providers: providers ?? this.providers,

//       isLoading: isLoading ?? this.isLoading,
//       isLoadingPage: isLoadingPage ?? this.isLoadingPage,

//       errorMessage:
//           clearError
//               ? null
//               : (errorMessage ?? this.errorMessage),

//       currentPage:
//           currentPage ?? this.currentPage,

//       pageSize:
//           pageSize ?? this.pageSize,

//       totalCount:
//           clearCounts
//               ? null
//               : (totalCount ?? this.totalCount),

//       hasNextPage:
//           hasNextPage ?? this.hasNextPage,

//       selectedCity:
//           clearCity
//               ? null
//               : (selectedCity ?? this.selectedCity),

//       dateFrom:
//           clearDateFrom
//               ? null
//               : (dateFrom ?? this.dateFrom),

//       dateTo:
//           clearDateTo
//               ? null
//               : (dateTo ?? this.dateTo),

//       sortOrder:
//           sortOrder ?? this.sortOrder,
//     );
//   }
// }

// /// Cursor-based PPL pagination.
// ///
// /// Cursor rules:
// ///
// /// page 0 -> cursor[0] = null
// /// page 1 -> cursor[1] = last scanned document from page 0
// /// page 2 -> cursor[2] = last scanned document from page 1
// ///
// /// We store cursors rather than loading every page into memory.
// class PayPerLeadPaginationNotifier
//     extends StateNotifier<PayPerLeadPaginationState> {
//   final Ref ref;

//   int _requestId = 0;

//   final List<
//       DocumentSnapshot<Map<String, dynamic>>?
//   > _pageCursors = <DocumentSnapshot<Map<String, dynamic>>?>[
//     null,
//   ];

//   bool _disposed = false;

//   PayPerLeadPaginationNotifier(this.ref)
//       : super(
//           const PayPerLeadPaginationState.initial(),
//         ) {
//     fetchInitial();
//   }

//   // ------------------------------------------------------------
//   // INITIAL LOAD
//   // ------------------------------------------------------------

//   Future<void> fetchInitial() async {
//     await applyFilters(
//       city: state.selectedCity,
//       dateFrom: state.dateFrom,
//       dateTo: state.dateTo,
//       sortOrder: state.sortOrder,
//     );
//   }

//   // ------------------------------------------------------------
//   // APPLY FILTERS
//   // ------------------------------------------------------------

//   Future<void> applyFilters({
//     String? city,
//     DateTime? dateFrom,
//     DateTime? dateTo,
//     PayPerLeadSortOrder? sortOrder,
//   }) async {
//     if (_disposed) {
//       return;
//     }

//     final int requestId = ++_requestId;

//     final PayPerLeadSortOrder resolvedSort =
//         sortOrder ?? state.sortOrder;

//     // ----------------------------------------------------------
//     // RESET CURSORS
//     // ----------------------------------------------------------

//     _pageCursors
//       ..clear()
//       ..add(null);

//     // ----------------------------------------------------------
//     // RESET STATE
//     // ----------------------------------------------------------

//     state = state.copyWith(
//       isLoading: true,
//       isLoadingPage: false,
//       clearError: true,

//       currentPage: 0,

//       providers: const [],

//       selectedCity: city,
//       dateFrom: dateFrom,
//       dateTo: dateTo,

//       clearCounts: true,

//       hasNextPage: false,

//       sortOrder: resolvedSort,
//     );

//     final UserRepository repo =
//         ref.read(userRepositoryProvider);

//     final bool isSuperAdmin =
//         ref.read(isSuperAdminProvider);

//     final List<String> assignedCities =
//         isSuperAdmin
//             ? const <String>[]
//             : ref.read(
//                 currentAdminAssignedCitiesProvider,
//               );

//     try {
//       // --------------------------------------------------------
//       // RUN COUNT + FIRST PAGE IN PARALLEL
//       // --------------------------------------------------------

//       final Future<int> countFuture =
//           repo.countPayPerLeadProviders(
//         selectedCity: city,
//         dateFrom: dateFrom,
//         dateTo: dateTo,
//         assignedCities: assignedCities,
//         isSuperAdmin: isSuperAdmin,
//       );

//       final Future<PageResult<UserModel>> pageFuture =
//           repo.fetchPayPerLeadProviders(
//         selectedCity: city,
//         dateFrom: dateFrom,
//         dateTo: dateTo,
//         assignedCities: assignedCities,
//         isSuperAdmin: isSuperAdmin,
//         sortDescending:
//             resolvedSort ==
//                 PayPerLeadSortOrder.newest,
//         startAfter: null,
//         limit: state.pageSize,
//       );

//       final List<dynamic> results =
//           await Future.wait<dynamic>([
//         countFuture,
//         pageFuture,
//       ]);

//       if (_disposed ||
//           requestId != _requestId) {
//         return;
//       }

//       final int totalCount =
//           results[0] as int;

//       final PageResult<UserModel> pageResult =
//           results[1] as PageResult<UserModel>;

//       // --------------------------------------------------------
//       // SAVE CURSOR FOR PAGE 1
//       // --------------------------------------------------------

//       if (pageResult.hasMore &&
//           pageResult.lastDocument != null) {
//         _setCursor(
//           pageIndex: 1,
//           cursor: pageResult.lastDocument,
//         );
//       }

//       if (_disposed ||
//           requestId != _requestId) {
//         return;
//       }

//       state = state.copyWith(
//         isLoading: false,
//         isLoadingPage: false,

//         providers: pageResult.items,

//         totalCount: totalCount,

//         currentPage: 0,

//         hasNextPage: pageResult.hasMore,

//         clearError: true,
//       );
//     } catch (e) {
//       if (_disposed ||
//           requestId != _requestId) {
//         return;
//       }

//       state = state.copyWith(
//         isLoading: false,
//         isLoadingPage: false,
//         errorMessage: _cleanError(e),
//       );
//     }
//   }

//   // ------------------------------------------------------------
//   // SORT
//   // ------------------------------------------------------------

//   Future<void> changeSortOrder(
//     PayPerLeadSortOrder newOrder,
//   ) async {
//     if (_disposed) {
//       return;
//     }

//     if (newOrder == state.sortOrder) {
//       return;
//     }

//     await applyFilters(
//       city: state.selectedCity,
//       dateFrom: state.dateFrom,
//       dateTo: state.dateTo,
//       sortOrder: newOrder,
//     );
//   }

//   // ------------------------------------------------------------
//   // CLEAR FILTERS
//   // ------------------------------------------------------------

//   Future<void> clearFilters() async {
//     await applyFilters(
//       city: null,
//       dateFrom: null,
//       dateTo: null,
//       sortOrder: PayPerLeadSortOrder.newest,
//     );
//   }

//   // ------------------------------------------------------------
//   // NEXT PAGE
//   // ------------------------------------------------------------

//   Future<void> nextPage() async {
//     if (_disposed) {
//       return;
//     }

//     if (state.isLoading ||
//         state.isLoadingPage) {
//       return;
//     }

//     if (!state.hasNextPage) {
//       return;
//     }

//     final int targetPage =
//         state.currentPage + 1;

//     // Cursor must exist.
//     if (targetPage >= _pageCursors.length) {
//       return;
//     }

//     await _fetchPage(targetPage);
//   }

//   // ------------------------------------------------------------
//   // PREVIOUS PAGE
//   // ------------------------------------------------------------

//   Future<void> prevPage() async {
//     if (_disposed) {
//       return;
//     }

//     if (state.isLoading ||
//         state.isLoadingPage) {
//       return;
//     }

//     if (state.currentPage <= 0) {
//       return;
//     }

//     final int targetPage =
//         state.currentPage - 1;

//     if (targetPage >= _pageCursors.length) {
//       return;
//     }

//     await _fetchPage(targetPage);
//   }

//   // ------------------------------------------------------------
//   // FETCH PAGE
//   // ------------------------------------------------------------

//   Future<void> _fetchPage(
//     int pageIndex,
//   ) async {
//     if (_disposed) {
//       return;
//     }

//     if (pageIndex < 0) {
//       return;
//     }

//     if (pageIndex >= _pageCursors.length) {
//       return;
//     }

//     final int requestId = ++_requestId;

//     final DocumentSnapshot<
//         Map<String, dynamic>>? cursor =
//         _pageCursors[pageIndex];

//     // ----------------------------------------------------------
//     // KEEP CURRENT PAGE VISIBLE
//     // ----------------------------------------------------------

//     state = state.copyWith(
//       isLoadingPage: true,
//       clearError: true,
//     );

//     final UserRepository repo =
//         ref.read(userRepositoryProvider);

//     final bool isSuperAdmin =
//         ref.read(isSuperAdminProvider);

//     final List<String> assignedCities =
//         isSuperAdmin
//             ? const <String>[]
//             : ref.read(
//                 currentAdminAssignedCitiesProvider,
//               );

//     try {
//       final PageResult<UserModel> pageResult =
//           await repo.fetchPayPerLeadProviders(
//         selectedCity: state.selectedCity,
//         dateFrom: state.dateFrom,
//         dateTo: state.dateTo,
//         assignedCities: assignedCities,
//         isSuperAdmin: isSuperAdmin,
//         sortDescending: state.sortDescending,

//         // IMPORTANT:
//         // page 0 = null
//         // page 1 = cursor after page 0
//         // page 2 = cursor after page 1
//         startAfter: cursor,

//         limit: state.pageSize,
//       );

//       if (_disposed ||
//           requestId != _requestId) {
//         return;
//       }

//       // --------------------------------------------------------
//       // SAVE CURSOR FOR NEXT PAGE
//       // --------------------------------------------------------

//       if (pageResult.hasMore &&
//           pageResult.lastDocument != null) {
//         _setCursor(
//           pageIndex: pageIndex + 1,
//           cursor: pageResult.lastDocument,
//         );
//       }

//       if (_disposed ||
//           requestId != _requestId) {
//         return;
//       }

//       state = state.copyWith(
//         isLoadingPage: false,

//         providers: pageResult.items,

//         currentPage: pageIndex,

//         hasNextPage: pageResult.hasMore,

//         clearError: true,
//       );
//     } catch (e) {
//       if (_disposed ||
//           requestId != _requestId) {
//         return;
//       }

//       // --------------------------------------------------------
//       // IMPORTANT:
//       //
//       // DO NOT remove the current page on error.
//       // This allows the footer to remain visible.
//       // --------------------------------------------------------

//       state = state.copyWith(
//         isLoadingPage: false,
//         errorMessage: _cleanError(e),
//       );
//     }
//   }

//   // ------------------------------------------------------------
//   // REFRESH
//   // ------------------------------------------------------------

//   Future<void> refresh() async {
//     if (_disposed) {
//       return;
//     }

//     if (state.isLoading ||
//         state.isLoadingPage) {
//       return;
//     }

//     final int page = state.currentPage;

//     // ----------------------------------------------------------
//     // For page 0, simply reload from beginning.
//     //
//     // For another page, use its existing cursor.
//     // ----------------------------------------------------------

//     if (page == 0) {
//       await _fetchPage(0);
//       return;
//     }

//     if (page >= _pageCursors.length) {
//       return;
//     }

//     await _fetchPage(page);
//   }

//   // ------------------------------------------------------------
//   // CURSOR MANAGEMENT
//   // ------------------------------------------------------------

//   void _setCursor({
//     required int pageIndex,
//     required DocumentSnapshot<
//         Map<String, dynamic>>? cursor,
//   }) {
//     if (_disposed) {
//       return;
//     }

//     if (cursor == null) {
//       return;
//     }

//     while (_pageCursors.length <= pageIndex) {
//       _pageCursors.add(null);
//     }

//     _pageCursors[pageIndex] = cursor;
//   }

//   // ------------------------------------------------------------
//   // ERROR CLEANUP
//   // ------------------------------------------------------------

//   String _cleanError(Object error) {
//     final String message =
//         error.toString().trim();

//     if (message.startsWith('Exception: ')) {
//       return message.substring(
//         'Exception: '.length,
//       );
//     }

//     return message;
//   }

//   // ------------------------------------------------------------
//   // DISPOSE
//   // ------------------------------------------------------------

//   @override
//   void dispose() {
//     _disposed = true;
//     _requestId++;

//     _pageCursors.clear();

//     super.dispose();
//   }
// }

// // --------------------------------------------------------------
// // RIVERPOD PROVIDER
// // --------------------------------------------------------------

// final payPerLeadPaginationProvider =
//     StateNotifierProvider<
//         PayPerLeadPaginationNotifier,
//         PayPerLeadPaginationState>(
//   (ref) {
//     return PayPerLeadPaginationNotifier(ref);
//   },
// );

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/repositories/user_repository.dart';

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

    final bool isSuperAdmin =
        ref.read(isSuperAdminProvider);

    final List<String> assignedCities =
        isSuperAdmin
            ? const <String>[]
            : ref.read(
                currentAdminAssignedCitiesProvider,
              );

    try {
      // --------------------------------------------------------
      // ONE FIRESTORE DATA LOAD
      // --------------------------------------------------------
      //
      // We intentionally do NOT call:
      //
      // count()
      //
      // because the full filtered list already gives us:
      //
      // 1. total provider count
      // 2. total Bill Balance
      // 3. all records needed for local pagination
      //
      final List<UserModel> allProviders =
          await repo.fetchAllPayPerLeadProviders(
        selectedCity: city,
        dateFrom: dateFrom,
        dateTo: dateTo,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
        sortDescending:
            resolvedSort ==
                PayPerLeadSortOrder.newest,
      );

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
    return PayPerLeadPaginationNotifier(ref);
  },
);