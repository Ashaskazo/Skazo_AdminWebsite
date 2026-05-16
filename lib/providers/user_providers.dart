import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// This provider will fetch all unverified business users
final unverifiedUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    // Only query by isverified to avoid the need for a composite index
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('isverified', isEqualTo: false)
        .get();

    final allUnverified = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // Filter locally: businessname not empty
    final filtered = allUnverified.where((user) {
      final name = (user['businessname'] ?? '').toString();
      return name.trim().isNotEmpty;
    }).toList();

    // Sort by newest first locally
    filtered.sort((a, b) {
      final aDate = (a['updatedAt'] ?? a['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
      final bDate = (b['updatedAt'] ?? b['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000);
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

// This provider will fetch unverified users by category and city
final unverifiedUsersByCategoryProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      category,
    ) async {
      final selectedCity = ref.watch(dashboardSelectedCityProvider);
      
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('isuser', isEqualTo: false)
              .where('isverified', isEqualTo: false)
              .get();

      final users =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

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
          final address = (user['address'] ?? '').toString().toLowerCase();
          return address.contains(selectedCity.toLowerCase());
        }

        return true;
      }).toList();
    });

// Provider to get all unique cities from unverified users
final unverifiedCitiesProvider = FutureProvider<List<String>>((ref) async {
  final users = await ref.watch(unverifiedUsersProvider.future);
  final Set<String> cities = {};
  
  for (final user in users) {
    final address = (user['address'] ?? '').toString();
    // Simple heuristic: take the last part of the address or look for common city names
    // For now, we'll just extract what looks like a city if possible, 
    // or the user can provide a dedicated city field in Firestore.
    // Assuming 'city' field exists or extracting from address:
    if (user['city'] != null) {
      cities.add(user['city'].toString());
    } else if (address.isNotEmpty) {
      final parts = address.split(',');
      if (parts.length > 1) {
        cities.add(parts[parts.length - 2].trim());
      } else {
        cities.add(parts.last.trim());
      }
    }
  }
  
  final sortedCities = cities.toList()..sort();
  return sortedCities;
});

// This provider will calculate category counts
final categoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final users = await ref.watch(unverifiedUsersProvider.future);
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

  for (final category in categories) {
    counts[category] =
        users.where((user) {
          final userCategories = user['category'];
          if (userCategories == null) return false;
          if (userCategories is String) return userCategories == category;
          if (userCategories is List) return userCategories.contains(category);
          return false;
        }).length;
  }

  return counts;
});

// This provider will handle user verification
class UserVerificationNotifier extends StateNotifier<bool> {
  final Ref ref;
  UserVerificationNotifier(this.ref) : super(false);

  Future<bool> verifyUser(String userId) async {
    state = true;
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isverified': true,
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
}

final userVerificationProvider =
    StateNotifierProvider<UserVerificationNotifier, bool>((ref) {
      return UserVerificationNotifier(ref);
    });

// Providers for filtering
final userSearchQueryProvider = StateProvider<String>((ref) => '');
final userSelectedCityProvider = StateProvider<String?>((ref) => null);
final userVerifiedOnlyProvider = StateProvider<bool>((ref) => false);
