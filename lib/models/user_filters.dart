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

  const UserFilters({
    this.timeFilter = TimeFilterOption.all,
    this.verifiedOnly,
    this.city,
    this.userType = 'All',
    this.category,
    this.priority,
    this.profileComplete,
    this.businessNamePrefix,
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
    bool clearVerifiedOnly = false,
    bool clearCity = false,
    bool clearCategory = false,
    bool clearPriority = false,
    bool clearProfileComplete = false,
    bool clearBusinessNamePrefix = false,
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
    );
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
        other.businessNamePrefix == businessNamePrefix;
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
  );
}
