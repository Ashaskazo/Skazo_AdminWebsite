import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/unverified_pagination_provider.dart';
import 'package:skazo_admin/providers/user_pagination_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/utils/property_pincodes_cache.dart';

/// Provider that checks if a user's email is in the admins collection
final isAuthorizedAdminProvider = FutureProvider.family<bool, String>((ref, email) async {
  try {
    // Check the admin collection for the email
    final snapshot = await FirebaseFirestore.instance
        .collection('admin')
        .where('email', isEqualTo: email.toLowerCase().trim())
        .limit(1)
        .get();

    // If document exists with matching email, user is authorized
    return snapshot.docs.isNotEmpty;
  } catch (e) {
    // Log error and return false for safety
    debugPrint('Error checking admin status: $e');
    return false;
  }
});

/// Provider to get the current admin profile data
// final currentAdminProfileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
//   final user = FirebaseAuth.instance.currentUser;
//   if (user == null || user.email == null) return null;

//   try {
//     final snapshot = await FirebaseFirestore.instance
//         .collection('admin')
//         .where('email', isEqualTo: user.email!.toLowerCase().trim())
//         .limit(1)
//         .get();

//     if (snapshot.docs.isNotEmpty) {
//       return {
//         'id': snapshot.docs.first.id,
//         ...snapshot.docs.first.data(),
//       };
//     }
//   } catch (e) {
//     debugPrint('Error fetching admin profile: $e');
//   }
//   return null;
// });

final currentAdminProfileProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final user = ref.watch(authStateProvider).value;

  if (user == null || user.email == null) {
    return null;
  }

  final snapshot = await FirebaseFirestore.instance
      .collection('admin')
      .where('email', isEqualTo: user.email!.toLowerCase().trim())
      .limit(1)
      .get();

  if (snapshot.docs.isEmpty) return null;

  return {
    'id': snapshot.docs.first.id,
    ...snapshot.docs.first.data(),
  };
});
final isSuperAdminProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(currentAdminProfileProvider);

  return profileAsync.when(
    data: (profile) {
      if (profile == null) return false;

      final level = (profile['level'] ?? '')
          .toString()
          .toLowerCase()
          .trim();

      return level == 'super_admin';
    },
    loading: () => false,
    error: (_, __) => false,
  );
});
// final isSuperAdminProvider = Provider<bool>((ref) {
//   final profile = ref.watch(currentAdminProfileProvider).value;
//   if (profile == null) return false;

//   final level = (profile['level'] ?? '')
//       .toString()
//       .toLowerCase()
//       .trim();

//   return level == 'super_admin';
// });

/// Provider to check if current user is a super admin
// final isSuperAdminProvider = Provider<bool>((ref) {
//   final profile = ref.watch(currentAdminProfileProvider).value;
//   if (profile == null) return false;
  
//   final role = (profile['role'] ?? '').toString().toLowerCase().trim();
//   final level = (profile['level'] ?? '').toString().toLowerCase().trim();
  
//   // If role is 'admin' or level is 'staff', the user is not a super admin
//   if (role == 'admin' || role == 'staff' || level == 'staff') {
//     return false;
//   }
  
//   return role == 'super_admin' || level == 'administrator';
// });

/// StreamProvider to fetch admins collection list (cached to prevent duplicate listeners on rebuild)
final adminsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  return FirebaseFirestore.instance.collection('admin').snapshots();
});

/// Provider to watch the Firebase Auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Provider to get the current admin status
final currentAdminStatusProvider = FutureProvider<bool>((ref) async {
  final profile = await ref.watch(currentAdminProfileProvider.future);
  return profile != null;
});

/// Provider to handle logging out
class AdminAuthNotifier extends StateNotifier<bool> {
  final Ref ref;
  AdminAuthNotifier(this.ref) : super(false);

  Future<void> signOut() async {
    state = true; // Processing
    try {
      await FirebaseAuth.instance.signOut();
      
      // Invalidate all cached data providers to release resources and prevent stale access
      final selectedCategory = ref.read(dashboardSelectedCategoryProvider);
      ref.invalidate(userPaginationProvider);
      clearPropertyPincodesCache();
      ref.invalidate(propertyPincodesProvider);
      ref.invalidate(unverifiedPaginationProvider(selectedCategory));
      ref.invalidate(unverifiedPendingCountProvider);
      ref.invalidate(categoryCountsProvider);
      ref.invalidate(adminsStreamProvider);
      ref.invalidate(paginatedLocalPromotionsProvider);
      ref.invalidate(adminsStreamProvider);
      // ref.invalidate(paginatedRentalPropertiesProvider);
    } catch (e) {
      debugPrint('Error signing out: $e');
    } finally {
      state = false; // Reset state
    }
  }
}

final adminAuthProvider = StateNotifierProvider<AdminAuthNotifier, bool>((ref) {
  return AdminAuthNotifier(ref);
});
