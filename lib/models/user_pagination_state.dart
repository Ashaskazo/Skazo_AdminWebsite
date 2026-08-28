import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:skazo_admin/models/user_filters.dart';
import 'package:skazo_admin/models/user_model.dart';

/// State for cursor-paginated user lists.
class UserPaginationState {
  final List<UserModel> users;
  final bool loading;
  final bool loadingMore;
  final String? error;
  final bool hasMore;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final UserFilters filters;
  final String searchQuery;
  final int? filteredCount;
  final int? totalCount;
  final int? serviceProviderCount;

  const UserPaginationState({
    this.users = const [],
    this.loading = false,
    this.loadingMore = false,
    this.error,
    this.hasMore = true,
    this.lastDocument,
    this.filters = const UserFilters(),
    this.searchQuery = '',
    this.filteredCount,
    this.totalCount,
    this.serviceProviderCount,
  });

  factory UserPaginationState.initial() =>
      const UserPaginationState(loading: true);

  UserPaginationState copyWith({
    List<UserModel>? users,
    bool? loading,
    bool? loadingMore,
    String? error,
    bool? hasMore,
    DocumentSnapshot<Map<String, dynamic>>? lastDocument,
    bool clearLastDocument = false,
    UserFilters? filters,
    String? searchQuery,
    int? filteredCount,
    int? totalCount,
    int? serviceProviderCount,
    bool clearCounts = false,
    bool clearError = false,
  }) {
    return UserPaginationState(
      users: users ?? this.users,
      loading: loading ?? this.loading,
      loadingMore: loadingMore ?? this.loadingMore,
      error: clearError ? null : (error ?? this.error),
      hasMore: hasMore ?? this.hasMore,
      lastDocument:
          clearLastDocument ? null : (lastDocument ?? this.lastDocument),
      filters: filters ?? this.filters,
      searchQuery: searchQuery ?? this.searchQuery,
      filteredCount: clearCounts ? null : (filteredCount ?? this.filteredCount),
      totalCount: clearCounts ? null : (totalCount ?? this.totalCount),
      serviceProviderCount:
          clearCounts
              ? null
              : (serviceProviderCount ?? this.serviceProviderCount),
    );
  }
}
