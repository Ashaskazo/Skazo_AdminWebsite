import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/collections_provider.dart';

// Helper to parse date times statically
DateTime? _parseDateTimeStatic(dynamic val) {
  if (val == null) return null;
  if (val is DateTime) return val;
  try {
    return val.toDate();
  } catch (_) {}
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  if (val is String) {
    final p = DateTime.tryParse(val);
    if (p != null) return p;
    return _parseCustomDateTimeStatic(val);
  }
  return null;
}

DateTime? _parseCustomDateTimeStatic(String val) {
  try {
    final clean = val.trim();
    if (clean.isEmpty) return null;
    final parts = clean.split(' ');
    if (parts.length >= 5) {
      final day = int.tryParse(parts[0]);
      final monthStr = parts[1].toLowerCase();
      final year = int.tryParse(parts[2]);
      final timePart = parts[4];
      final timeParts = timePart.split(':');
      final hour = timeParts.isNotEmpty ? int.tryParse(timeParts[0]) ?? 0 : 0;
      final minute = timeParts.length > 1 ? int.tryParse(timeParts[1]) ?? 0 : 0;
      final second = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;

      final months = {
        'january': 1, 'february': 2, 'march': 3, 'april': 4, 'may': 5, 'june': 6,
        'july': 7, 'august': 8, 'september': 9, 'october': 10, 'november': 11, 'december': 12,
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'jun': 6, 'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
      };
      final month = months[monthStr];

      if (day != null && month != null && year != null) {
        if (parts.length >= 6 && parts[5].startsWith('UTC')) {
          final offsetStr = parts[5].substring(3);
          final isNegative = offsetStr.startsWith('-');
          final cleanOffset = offsetStr.replaceAll('+', '').replaceAll('-', '');
          final offsetParts = cleanOffset.split(':');
          final offsetHours = offsetParts.isNotEmpty ? int.tryParse(offsetParts[0]) ?? 0 : 0;
          final offsetMinutes = offsetParts.length > 1 ? int.tryParse(offsetParts[1]) ?? 0 : 0;
          
          final utcTime = DateTime.utc(year, month, day, hour, minute, second);
          final duration = Duration(hours: offsetHours, minutes: offsetMinutes);
          return isNegative ? utcTime.add(duration) : utcTime.subtract(duration);
        }
        return DateTime(year, month, day, hour, minute, second);
      }
    }
  } catch (_) {}
  return null;
}

// This provider will fetch all unverified business users in-memory from the shared stream
final unverifiedUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final dateFilter = ref.watch(dashboardSelectedDateFilterProvider);
  try {
    final users = await ref.watch(usersStreamProvider.future);

    var filtered = users.where((user) {
      final isVerified = user['isverified'] == true;
      final name = (user['businessname'] ?? '').toString();
      final isDeactivated = user['isDeactivated'] ?? false;
      return !isVerified && name.trim().isNotEmpty && !isDeactivated;
    }).toList();

    // Date filtering locally
    if (dateFilter != null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      filtered = filtered.where((user) {
        final dateTime = _parseDateTimeStatic(user['createdAt']);
        if (dateTime == null) return false;

        if (dateFilter == 'today') {
          return dateTime.isAfter(todayStart) || dateTime.isAtSameMomentAs(todayStart);
        } else if (dateFilter == 'yesterday') {
          final yesterdayStart = todayStart.subtract(const Duration(days: 1));
          return (dateTime.isAfter(yesterdayStart) || dateTime.isAtSameMomentAs(yesterdayStart)) &&
                 dateTime.isBefore(todayStart);
        } else if (dateFilter == 'month') {
          final monthStart = todayStart.subtract(const Duration(days: 30));
          return dateTime.isAfter(monthStart) || dateTime.isAtSameMomentAs(monthStart);
        }
        return true;
      }).toList();
    }

    // Sort by newest first locally
    filtered.sort((a, b) {
      final aDate = _parseDateTimeStatic(a['updatedAt'] ?? a['createdAt']) ?? DateTime(2000);
      final bDate = _parseDateTimeStatic(b['updatedAt'] ?? b['createdAt']) ?? DateTime(2000);
      return bDate.compareTo(aDate);
    });

    return filtered;
  } catch (e) {
    debugPrint('Error loading unverified users: $e');
    rethrow;
  }
});

// Provider to track selected category in the dashboard summary
final dashboardSelectedCategoryProvider = StateProvider<String?>((ref) => null);

// Provider to track selected city for filtering
final dashboardSelectedCityProvider = StateProvider<String?>((ref) => null);

// This provider will fetch unverified users by category and city in-memory
// This provider will fetch unverified users by category and city in-memory
final unverifiedUsersByCategoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      category,
    ) async {
      final users = await ref.watch(unverifiedUsersProvider.future);
      final selectedCity = ref.watch(dashboardSelectedCityProvider);
      
      // Load city pincodes map
      final pincodesMap = ref.watch(propertyPincodesProvider).value ?? {};
      
      return users.where((user) {
        // Category check
        final userCategories = user['category'];
        bool matchesCategory = false;
        if (userCategories != null) {
          if (userCategories is String) {
            matchesCategory = userCategories == category;
          } else if (userCategories is List) {
            matchesCategory = userCategories.contains(category);
          }
        }
        
        if (!matchesCategory) return false;

        // City check
        if (selectedCity != null) {
          final address = (user['businessaddress'] ?? user['address'] ?? '').toString().toLowerCase();
          final userCity = (user['city'] ?? user['City'] ?? '').toString().toLowerCase();
          
          // Match by property pincode array
          final cityPins = pincodesMap[selectedCity];
          if (cityPins != null && cityPins.isNotEmpty) {
            final pinMatch = RegExp(r'\b\d{6}\b').firstMatch(address);
            final userPin = pinMatch?.group(0);
            if (userPin != null && cityPins.contains(userPin)) {
              return true;
            }
          }
          
          // Fallback to substring matching if pincode not matched or not found
          if (!address.contains(selectedCity.toLowerCase()) && !userCity.contains(selectedCity.toLowerCase())) {
            return false;
          }
        }

        return true;
      }).toList();
    });

// Provider to get all unique cities from property_pincodes collection
final unverifiedCitiesProvider = FutureProvider<List<String>>((ref) async {
  final pincodesMap = await ref.watch(propertyPincodesProvider.future);
  final sortedCities = pincodesMap.keys.toList()..sort();
  return sortedCities;
});

// This provider will calculate category counts
final categoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final users = await ref.watch(unverifiedUsersProvider.future);
  final selectedCity = ref.watch(dashboardSelectedCityProvider);
  final pincodesMap = ref.watch(propertyPincodesProvider).value ?? {};
  
  final Map<String, int> counts = {};

  final List<String> categories = [
    'House cleaning',
    'Pest control',
    'Tank cleaning',
    'Electricians',
    'Plumbers',
    'AC Repair',
    'Fridge Repair',
    'Washing Machine Repair',
    'CCTV Installation',
    'Water Purifier Repair',
    'Kitchen Appliances Repair',
    'TV Repair',
    'Phone & System Repairs',
    'Wood Works',
    'Glass Design Works',
    'Interior Designers',
    'Ceiling',
    'Tiles',
    'Painters',
    'Purohith',
    'Wedding Halls',
    'Photographers',
    'Catering',
    'Shamiyana',
    'Bridal and Groom Makeup',
    'Beauty Services',
    'Mehandi Artists',
    'Other Event Services',
    'Astrologers',
    'Packers and Movers',
    'Car Mechanic',
    'Bike Mechanic',
    'Car Drivers',
    'Car Travels',
    'Autos',
    'Welders',
    'Builders & Contractors',
    'Ambulance',
    'Diagnostic Centers',
    'Others',
  ];

  // Helper to check if user matches selected city
  bool matchesCity(Map<String, dynamic> user) {
    if (selectedCity == null) return true;
    final address = (user['businessaddress'] ?? user['address'] ?? '').toString().toLowerCase();
    final userCity = (user['city'] ?? user['City'] ?? '').toString().toLowerCase();
    
    // Check property pincode array
    final cityPins = pincodesMap[selectedCity];
    if (cityPins != null && cityPins.isNotEmpty) {
      final pinMatch = RegExp(r'\b\d{6}\b').firstMatch(address);
      final userPin = pinMatch?.group(0);
      if (userPin != null && cityPins.contains(userPin)) {
        return true;
      }
    }
    
    return address.contains(selectedCity.toLowerCase()) || userCity.contains(selectedCity.toLowerCase());
  }

  for (final category in categories) {
    counts[category] =
        users.where((user) {
          if (!matchesCity(user)) return false;
          
          final userCategories = user['category'];
          if (userCategories == null) return false;
          if (userCategories is String) return userCategories == category;
          if (userCategories is List) return userCategories.contains(category);
          return false;
        }).length;
  }

  return counts;
});

// This provider will handle user verification and deactivation
class UserVerificationNotifier extends StateNotifier<bool> {
  final Ref ref;
  UserVerificationNotifier(this.ref) : super(false);

  Future<bool> verifyUser(String userId) async {
    state = true;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isverified': true,
        'isactive': true,
        'isDeactivated': false,
        'verifiedAt': FieldValue.serverTimestamp(),
      });

      ref.invalidate(unverifiedUsersProvider);
      ref.invalidate(categoryCountsProvider);

      state = false;
      return true;
    } catch (e) {
      state = false;
      return false;
    }
  }

  Future<bool> deactivateUser(String userId) async {
    state = true;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isactive': false,
        'isDeactivated': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      ref.invalidate(unverifiedUsersProvider);
      ref.invalidate(categoryCountsProvider);

      state = false;
      return true;
    } catch (e) {
      state = false;
      return false;
    }
  }
}

final userVerificationProvider =
    StateNotifierProvider<UserVerificationNotifier, bool>((ref) {
      return UserVerificationNotifier(ref);
    });

// Providers for filtering
final userSearchQueryProvider = StateProvider<String>((ref) => '');
final userSelectedCityProvider = StateProvider<String?>((ref) => null);
final userVerifiedOnlyProvider = StateProvider<bool>((ref) => false);
final userDateFilterProvider = StateProvider<String?>((ref) => null);
final userTypeFilterProvider = StateProvider<String>((ref) => 'All');

// Provider to track selected date filter for the dashboard unverified businesses
final dashboardSelectedDateFilterProvider = StateProvider<String?>((ref) => null);
