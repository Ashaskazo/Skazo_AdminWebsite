import 'package:skazo_admin/constants/hyderabad_area_groups.dart';

/// Represents the aggregated statistics for a single business category on a given date and city.
class ServiceProviderCategoryStats {
  final String categoryName;
  final int totalCount;
  final int activeCount;
  final int inactiveCount;
  final int verifiedCount;
  final int unverifiedCount;

  const ServiceProviderCategoryStats({
    required this.categoryName,
    required this.totalCount,
    this.activeCount = 0,
    this.inactiveCount = 0,
    this.verifiedCount = 0,
    this.unverifiedCount = 0,
  });

  ServiceProviderCategoryStats copyWith({
    String? categoryName,
    int? totalCount,
    int? activeCount,
    int? inactiveCount,
    int? verifiedCount,
    int? unverifiedCount,
  }) {
    return ServiceProviderCategoryStats(
      categoryName: categoryName ?? this.categoryName,
      totalCount: totalCount ?? this.totalCount,
      activeCount: activeCount ?? this.activeCount,
      inactiveCount: inactiveCount ?? this.inactiveCount,
      verifiedCount: verifiedCount ?? this.verifiedCount,
      unverifiedCount: unverifiedCount ?? this.unverifiedCount,
    );
  }
}

/// Aggregated statistics for a specific Hyderabad area group.
class ServiceProviderAreaStats {
  final ServiceProviderAreaGroup areaGroup;
  final int totalCount;

  const ServiceProviderAreaStats({
    required this.areaGroup,
    required this.totalCount,
  });

  String get displayName => areaGroup.displayName;
  List<String> get pincodes => areaGroup.pincodes;
}

/// Lightweight overview dataset returned by the overview query.
/// Contains ONLY aggregated statistics and category breakdowns — no full document lists.
class ServiceProvidersOverviewData {
  final String? selectedCity;
  final DateTime selectedDate;
  final int totalProviders;
  final int totalCategories;
  final List<ServiceProviderCategoryStats> categories;
  final List<ServiceProviderAreaStats>? areaGroups;

  const ServiceProvidersOverviewData({
    required this.selectedCity,
    required this.selectedDate,
    required this.totalProviders,
    required this.totalCategories,
    required this.categories,
    this.areaGroups,
  });

  /// True when the selected city is Hyderabad and 10 area groups are populated.
  bool get isHyderabadAreaView =>
      selectedCity != null &&
      isCityHyderabad(selectedCity) &&
      areaGroups != null &&
      areaGroups!.isNotEmpty;

  factory ServiceProvidersOverviewData.empty({
    String? selectedCity,
    required DateTime selectedDate,
  }) {
    return ServiceProvidersOverviewData(
      selectedCity: selectedCity,
      selectedDate: selectedDate,
      totalProviders: 0,
      totalCategories: 0,
      categories: const [],
      areaGroups: null,
    );
  }
}

