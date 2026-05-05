import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// This provider will fetch all unverified business users
final unverifiedUsersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('isuser', isEqualTo: false)
      .where('isverified', isEqualTo: false)
      .get();

  return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
});

// This provider will fetch unverified users by category
final unverifiedUsersByCategoryProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, category) async {
  final snapshot = await FirebaseFirestore.instance
      .collection('users')
      .where('isuser', isEqualTo: false)
      .where('isverified', isEqualTo: false)
      .get();

  final users = snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();

  return users.where((user) {
    final userCategories = user['category'];
    if (userCategories == null) return false;

    if (userCategories is String) {
      return userCategories == category;
    } else if (userCategories is List) {
      return userCategories.contains(category);
    }
    return false;
  }).toList();
});

// This provider will calculate category counts
final categoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  final users = await ref.watch(unverifiedUsersProvider.future);
  final Map<String, int> counts = {};

  final List<String> categories = [
    'House cleaning', 'Pest control', 'Tank cleaning',
    'Electricians', 'Plumbers',
    'AC Repair', 'Fridge Repair', 'Washing Machine Repair',
    'CCTV Installation', 'Water Purifier Repair',
    'Kitchen Appliances Repair', 'TV Repair', 'Phone & System Repairs',
    'Wood Works', 'Glass Design Works', 'Interior Designers',
    'Ceiling', 'Tiles', 'Painters',
    'Purohith', 'Wedding Halls', 'Photographers', 'Catering',
    'Shamiyana', 'Bridal and Groom Makeup', 'Beauty Services',
    'Mehandi Artists', 'Other Event Services',
    'Astrologers', 'Packers and Movers',
    'Car Mechanic', 'Bike Mechanic',
    'Car Drivers', 'Car Travels', 'Autos',
    'Welders', 'Builders & Contractors',
    'Ambulance', 'Diagnostic Centers', 'Others',
  ];

  for (final category in categories) {
    counts[category] = users.where((user) {
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

final userVerificationProvider = StateNotifierProvider<UserVerificationNotifier, bool>((ref) {
  return UserVerificationNotifier(ref);
});
