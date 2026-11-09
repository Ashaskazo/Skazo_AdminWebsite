import '../models/user_model.dart';

/// Service to classify plans and determine if a provider belongs to
/// the explicitly configured Premium categories for Pay Per Lead.
class PlanClassificationService {
  /// The explicitly configured Premium categories for Pay Per Lead.
  static const Set<String> premiumCategories = {
    'Electricians',
    'Plumbers',
    'AC Repair',
    'Fridge Repair',
    'Washing Machine Repair',
    'Painters',
    'Car Travels',
    'Car Drivers',
    'House cleaning',
    'Wood Works',
    'Packers and Movers',
    'Bike Mechanic',
    'Car Mechanic',
  };

  /// Returns true ONLY if the provider's category is one of the explicitly
  /// configured Premium categories.
  ///
  /// Plan, payment, or verification status does NOT make a non-Premium category Premium.
  static bool isPremium(UserModel provider) {
    return isPremiumCategory(provider.category);
  }

  /// Checks if a raw category (which can be a String, a List, or null) matches
  /// any of the configured Premium categories (case-insensitive and trimmed).
  static bool isPremiumCategory(dynamic category) {
    if (category == null) return false;

    if (category is List) {
      for (final item in category) {
        if (item == null) continue;
        final name = item.toString().trim();
        if (_matchesPremium(name)) {
          return true;
        }
      }
      return false;
    }

    final name = category.toString().trim();
    return _matchesPremium(name);
  }

  static bool _matchesPremium(String categoryName) {
    if (categoryName.isEmpty) return false;
    final lower = categoryName.toLowerCase();
    for (final premium in premiumCategories) {
      if (premium.toLowerCase() == lower) {
        return true;
      }
    }
    return false;
  }
}
