import 'package:skazo_admin/models/user_model.dart';

/// Represents the classification group of a provider.
enum PlanGroup {
  /// Premium categories.
  groupA,

  /// Kept for backward compatibility with existing code.
  /// No category is assigned to Group B anymore.
  groupB,

  /// Non-premium categories.
  nonPremium,
}

/// Represents a subscription plan available to a provider.
class ProviderPlan {
  final String id;
  final String name;
  final double price;
  final String duration;
  final PlanGroup group;
  final List<String> features;

  const ProviderPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    required this.group,
    this.features = const [],
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProviderPlan &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name &&
          price == other.price &&
          duration == other.duration &&
          group == other.group;

  @override
  int get hashCode =>
      id.hashCode ^
      name.hashCode ^
      price.hashCode ^
      duration.hashCode ^
      group.hashCode;
}

/// CENTRAL SINGLE SOURCE OF TRUTH
///
/// Only categories explicitly present in [premiumCategories]
/// are considered Premium.
///
/// Every other category is considered Non-Premium.
///
/// Use this service everywhere Premium / Non-Premium logic is required.
class PlanClassificationService {
  PlanClassificationService._();

  // ============================================================
  // PREMIUM CATEGORIES
  // ============================================================

  /// ONLY these categories are Premium.
  static const List<String> premiumCategories = [
    'Electricians',
    'Plumbers',
    'AC Repair',
    'Fridge Repair',
    'Washing Machine Repair',
    'CCTV',
    'Car Drivers',
    'Painters',
    'Wood Works',
    'Car Mechanic',
    'Bike Mechanic',
    'House Cleaning',
    'Packers and Movers',
  ];

  // ============================================================
  // NON-PREMIUM CATEGORIES
  // ============================================================

  /// Explicitly maintained Non-Premium categories.
  ///
  /// Any category not present in [premiumCategories] is also
  /// treated as Non-Premium.
  static const List<String> nonPremiumCategories = [
    'Water Purifier',
    'Waterproofing',
    'Pest Control',
    'Beauty Services',
    'Ceiling',
    'Tiles',
    'TV Repair',
    'Kitchen Appliances',
    'Glass Works',
    'Interior Designs',
    'Purohit',
  ];

  // ============================================================
  // BACKWARD-COMPATIBILITY ALIASES
  // ============================================================

  /// Existing code may still reference groupACategories.
  /// Keep this alias so existing functionality does not break.
  static const List<String> groupACategories = premiumCategories;

  /// Existing code may still reference groupBCategories.
  ///
  /// IMPORTANT:
  /// Group B is no longer considered Premium.
  /// This list is retained only for source compatibility.
  static const List<String> groupBCategories = [];

  // ============================================================
  // CATEGORY NORMALIZATION
  // ============================================================

  /// Normalizes category values for reliable matching.
  ///
  /// Handles:
  /// - Upper/lower case
  /// - Leading/trailing spaces
  /// - Singular/plural differences
  static String normalizeCategory(String category) {
    var clean = category.trim().toLowerCase();

    if (clean.isEmpty) return '';

    // Known aliases / naming variations.
    const aliases = {
      'cctv installation': 'cctv',
      'cctv installations': 'cctv',
      'car & bike mechanics': 'car mechanic',
      'bike mechanics': 'bike mechanic',
      'car mechanics': 'car mechanic',
      'packers & movers': 'packers and movers',
      'packers movers': 'packers and movers',
      'house cleanings': 'house cleaning',
      'water purifiers': 'water purifier',
      'pest controls': 'pest control',
      'glass design works': 'glass works',
      'interior designers': 'interior designs',
      'purohith': 'purohit',
    };

    if (aliases.containsKey(clean)) {
      return aliases[clean]!;
    }

    // Singular/plural normalization.
    if (clean.endsWith('ies') && clean.length > 3) {
      clean = '${clean.substring(0, clean.length - 3)}y';
    } else if (clean.endsWith('es') &&
        clean.length > 3 &&
        !clean.endsWith('sses')) {
      clean = clean.substring(0, clean.length - 2);
    } else if (clean.endsWith('s') &&
        clean.length > 2 &&
        !clean.endsWith('ss')) {
      clean = clean.substring(0, clean.length - 1);
    }

    return clean;
  }

  // ============================================================
  // CATEGORY MATCHING
  // ============================================================

  /// Checks whether raw category data matches any category
  /// in the supplied target list.
  static bool categoryMatchesList(
    dynamic rawCategory,
    List<String> targetCategories,
  ) {
    if (rawCategory == null) return false;

    final normalizedTargets = targetCategories.map(normalizeCategory).toSet();

    final List<String> userCatTokens = [];

    if (rawCategory is String) {
      userCatTokens.addAll(
        rawCategory.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
      );
    } else if (rawCategory is List) {
      for (final item in rawCategory) {
        if (item != null) {
          final str = item.toString().trim();

          if (str.isNotEmpty) {
            userCatTokens.addAll(
              str.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty),
            );
          }
        }
      }
    } else if (rawCategory is Map) {
      for (final key in rawCategory.keys) {
        if (key != null) {
          final str = key.toString().trim();

          if (str.isNotEmpty) {
            userCatTokens.add(str);
          }
        }
      }
    }

    for (final token in userCatTokens) {
      final normalizedToken = normalizeCategory(token);

      if (normalizedTargets.contains(normalizedToken)) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // PREMIUM CHECK
  // ============================================================

  /// Returns true ONLY when the provider's category is one of
  /// the explicitly defined Premium categories.
  ///
  /// IMPORTANT:
  /// Active plan, payment amount, verification, boosted status,
  /// etc. do NOT override category classification.
  static bool isPremium(dynamic input) {
    if (input == null) return false;

    dynamic category;

    if (input is UserModel) {
      category = input.category;
    } else if (input is Map) {
      category =
          input['category'] ??
          input['businessCategory'] ??
          input['serviceCategory'];
    } else if (input is String) {
      category = input;
    } else {
      return false;
    }

    return categoryMatchesList(category, premiumCategories);
  }

  // ============================================================
  // NON-PREMIUM CHECK
  // ============================================================

  /// Returns true when the category is NOT one of the Premium
  /// categories.
  ///
  /// This means any unknown/new category automatically remains
  /// Non-Premium until explicitly added to premiumCategories.
  static bool isNonPremium(dynamic input) {
    return !isPremium(input);
  }

  // ============================================================
  // PLAN GROUP
  // ============================================================

  /// Determines the PlanGroup using ONLY category classification.
  ///
  /// Premium category -> groupA
  /// Everything else -> nonPremium
  ///
  /// groupB is retained only for backward compatibility.
  static PlanGroup getPlanGroup(UserModel user) {
    if (isPremium(user)) {
      return PlanGroup.groupA;
    }

    return PlanGroup.nonPremium;
  }

  /// Flexible helper for UserModel, Firestore Map or category String.
  static PlanGroup getPlanGroupFromData(dynamic data) {
    if (data is UserModel) {
      return getPlanGroup(data);
    }

    dynamic category;

    if (data is Map) {
      category =
          data['category'] ??
          data['businessCategory'] ??
          data['serviceCategory'];
    } else {
      category = data;
    }

    if (isPremium(category)) {
      return PlanGroup.groupA;
    }

    return PlanGroup.nonPremium;
  }

  // ============================================================
  // GROUP HELPERS
  // ============================================================

  /// Returns true only for the explicitly defined Premium categories.
  static bool isGroupA(UserModel user) {
    return isPremium(user);
  }

  /// Group B is no longer a Premium classification.
  ///
  /// Kept only to prevent existing callers from breaking.
  static bool isGroupB(UserModel user) {
    return false;
  }

  // ============================================================
  // PAID VERIFICATION
  // ============================================================

  /// Kept for backward compatibility.
  ///
  /// NOTE:
  /// This does NOT make a provider Premium.
  /// Premium status is determined only by category through isPremium().
  static bool hasPaidVerification(UserModel user) {
    if (!user.isverified) return false;

    final activePlan = user.activePlan ?? 0;
    final totalAmount = user.totalAmount ?? 0;
    final paymentCount = user.paymentCount ?? 0;

    final rawPaidFlag =
        user.rawData['isPaidVerified'] == true ||
        user.rawData['paidVerification'] == true;

    return activePlan > 0 || totalAmount > 0 || paymentCount > 0 || rawPaidFlag;
  }

  // ============================================================
  // AVAILABLE PLANS
  // ============================================================

  /// Returns plans based ONLY on category classification.
  static List<ProviderPlan> getAvailablePlans(UserModel user) {
    final group = getPlanGroup(user);

    switch (group) {
      case PlanGroup.groupA:
        return const [
          ProviderPlan(
            id: 'premium_annual',
            name: 'Premium Annual Plan',
            price: 999.0,
            duration: '1 Year',
            group: PlanGroup.groupA,
            features: [
              'Priority Listing',
              'Unlimited Leads',
              'Verified Badge',
              'Dedicated Support',
            ],
          ),
          ProviderPlan(
            id: 'premium_halfyear',
            name: 'Premium Half-Year Plan',
            price: 599.0,
            duration: '6 Months',
            group: PlanGroup.groupA,
            features: ['Priority Listing', 'Standard Leads', 'Verified Badge'],
          ),
        ];

      case PlanGroup.groupB:
        // No categories currently use Group B.
        return const [];

      case PlanGroup.nonPremium:
        return const [
          ProviderPlan(
            id: 'basic_free',
            name: 'Basic Free Listing',
            price: 0.0,
            duration: 'Lifetime',
            group: PlanGroup.nonPremium,
            features: ['Standard Listing'],
          ),
        ];
    }
  }
}

/// Alias retained for existing code.
typedef ProviderPlanService = PlanClassificationService;
