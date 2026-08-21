import 'package:skazo_admin/utils/time_filter.dart';

/// Server-side filter parameters applied to Firestore user queries.
class UserFilters {
  final TimeFilterOption timeFilter;
  final bool? verifiedOnly;
  final String? city;
  final String userType;
  final String? category;
  final int? priority;
  final bool? profileComplete;
  final String? businessNamePrefix;
  final String? searchQuery;
  final bool sortAscending;

  const UserFilters({
    this.timeFilter = TimeFilterOption.all,
    this.verifiedOnly,
    this.city,
    this.userType = 'All',
    this.category,
    this.priority,
    this.profileComplete,
    this.businessNamePrefix,
    this.searchQuery,
    this.sortAscending = false,
  });

  UserFilters copyWith({
    TimeFilterOption? timeFilter,
    bool? verifiedOnly,
    String? city,
    String? userType,
    String? category,
    int? priority,
    bool? profileComplete,
    String? businessNamePrefix,
    String? searchQuery,
    bool? sortAscending,
    bool clearVerifiedOnly = false,
    bool clearCity = false,
    bool clearCategory = false,
    bool clearPriority = false,
    bool clearProfileComplete = false,
    bool clearBusinessNamePrefix = false,
    bool clearSearchQuery = false,
  }) {
    return UserFilters(
      timeFilter: timeFilter ?? this.timeFilter,
      verifiedOnly: clearVerifiedOnly ? null : (verifiedOnly ?? this.verifiedOnly),
      city: clearCity ? null : (city ?? this.city),
      userType: userType ?? this.userType,
      category: clearCategory ? null : (category ?? this.category),
      priority: clearPriority ? null : (priority ?? this.priority),
      profileComplete:
          clearProfileComplete ? null : (profileComplete ?? this.profileComplete),
      businessNamePrefix: clearBusinessNamePrefix
          ? null
          : (businessNamePrefix ?? this.businessNamePrefix),
      searchQuery: clearSearchQuery
          ? null
          : (searchQuery ?? this.searchQuery),
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  /// Deterministic multi-dimensional cache key for count and page caching.
  String toCacheKey({
    List<String> assignedCities = const [],
    String query = '',
  }) {
    final effectiveQuery = (searchQuery?.trim().isNotEmpty == true
            ? searchQuery!.trim()
            : query.trim())
        .toLowerCase();

    final sortedAssigned = [...assignedCities]..sort();

    return [
      timeFilter.name,
      verifiedOnly?.toString() ?? '',
      city?.trim().toLowerCase() ?? '',
      userType,
      category?.trim().toLowerCase() ?? '',
      priority?.toString() ?? '',
      profileComplete?.toString() ?? '',
      businessNamePrefix?.trim().toLowerCase() ?? '',
      effectiveQuery,
      sortAscending ? 'asc' : 'desc',
      sortedAssigned.join(','),
    ].join('|');
  }

  @override
  bool operator ==(Object other) {
    return other is UserFilters &&
        other.timeFilter == timeFilter &&
        other.verifiedOnly == verifiedOnly &&
        other.city == city &&
        other.userType == userType &&
        other.category == category &&
        other.priority == priority &&
        other.profileComplete == profileComplete &&
        other.businessNamePrefix == businessNamePrefix &&
        other.searchQuery == searchQuery &&
        other.sortAscending == sortAscending;
  }

  @override
  int get hashCode => Object.hash(
    timeFilter,
    verifiedOnly,
    city,
    userType,
    category,
    priority,
    profileComplete,
    businessNamePrefix,
    searchQuery,
    sortAscending,
  );
}
