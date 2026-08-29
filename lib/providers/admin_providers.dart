import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/dashboard_provider.dart';
import 'package:skazo_admin/providers/unverified_pagination_provider.dart';
import 'package:skazo_admin/providers/user_pagination_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/repositories/user_repository.dart';
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

/// Real-time StreamProvider watching the current logged-in admin's profile document in Firestore
final currentAdminProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authUser = ref.watch(authStateProvider).value;

  if (authUser == null || authUser.email == null) {
    return Stream.value(null);
  }

  final email = authUser.email!.toLowerCase().trim();

  return FirebaseFirestore.instance
      .collection('admin')
      .where('email', isEqualTo: email)
      .snapshots()
      .map((snapshot) {
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return {
      'id': doc.id,
      ...doc.data(),
    };
  });
});

/// Provider checking if current logged in admin is a Super Admin
final isSuperAdminProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(currentAdminProfileProvider);

  return profileAsync.when(
    data: (profile) {
      if (profile == null) return false;

      final level = (profile['level'] ?? '').toString().toLowerCase().trim();
      final role = (profile['role'] ?? '').toString().toLowerCase().trim();

      return level == 'super_admin' || level == 'administrator' || role == 'super_admin';
    },
    loading: () => false,
    error: (_, __) => false,
  );
});

/// Provider checking if current logged in admin account is Active
final isAdminActiveProvider = Provider<bool>((ref) {
  final profileAsync = ref.watch(currentAdminProfileProvider);

  return profileAsync.when(
    data: (profile) {
      if (profile == null) return false;
      // Default to true if isActive field is not explicitly set to false
      return profile['isActive'] != false && profile['status'] != 'inactive';
    },
    loading: () => true,
    error: (_, __) => false,
  );
});

/// Real-time provider extracting assigned cities for the current admin.
/// Returns empty list `[]` if Super Admin (meaning unrestricted access to all cities).
final currentAdminAssignedCitiesProvider = Provider<List<String>>((ref) {
  final isSuper = ref.watch(isSuperAdminProvider);
  if (isSuper) return const []; // Super Admin has unrestricted access to all cities

  final profile = ref.watch(currentAdminProfileProvider).value;
  if (profile == null) return const [];

  final dynamic rawCities = profile['assignedCities'] ?? profile['assigned_cities'];
  if (rawCities is List) {
    final list = rawCities.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
    if (list.isNotEmpty) return list;
  }
  
  final singleCity = (profile['assignedCity'] ?? profile['city'])?.toString().trim();
  if (singleCity != null && singleCity.isNotEmpty) {
    return [singleCity];
  }

  return const [];
});

/// Provider returning all cities accessible to the current admin for UI dropdowns.
/// Returns all system cities for Super Admin, or assigned cities for regular Admin.
final allowedCitiesProvider = FutureProvider<List<String>>((ref) async {
  final profileAsync = ref.watch(currentAdminProfileProvider);
  final profile = profileAsync.value;
  final isSuper = ref.watch(isSuperAdminProvider);

  if (isSuper) {
    try {
      final allCities = await ref.watch(userFilterCitiesProvider.future);
      if (allCities.isNotEmpty) return allCities;
    } catch (_) {}
    return const [
      'Vijayawada',
      'Hyderabad',
      'Guntur',
      'Bangalore',
      'Bheemavaram',
      'Tirupathi',
    ];
  }

  if (profile != null) {
    final dynamic rawCities =
        profile['assignedCities'] ?? profile['assigned_cities'];
    if (rawCities is List) {
      final list =
          rawCities
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
      if (list.isNotEmpty) return list;
    }

    final singleCity =
        (profile['assignedCity'] ?? profile['city'])?.toString().trim();
    if (singleCity != null && singleCity.isNotEmpty) {
      return [singleCity];
    }
  }

  final assigned = ref.watch(currentAdminAssignedCitiesProvider);
  return assigned;
});

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

      // Reset view to summary default
      ref.read(currentDashboardViewProvider.notifier).state =
          DashboardView.summary;
      ref.read(sidebarCollapsedProvider.notifier).state = false;

      // Reset all user management filters
      ref.read(userSearchQueryProvider.notifier).state = '';
      ref.read(userSelectedCityProvider.notifier).state = null;
      ref.read(userVerifiedOnlyProvider.notifier).state = false;
      ref.read(userDateFilterProvider.notifier).state = null;
      ref.read(userTypeFilterProvider.notifier).state = 'All';
      ref.read(userCategoryFilterProvider.notifier).state = null;
      ref.read(userPriorityFilterProvider.notifier).state = null;
      ref.read(userProfileCompleteFilterProvider.notifier).state = null;
      ref.read(userBusinessNameFilterProvider.notifier).state = null;
      ref.read(userSortAscendingProvider.notifier).state = false;

      // Reset dashboard filter state
      ref.read(dashboardSelectedCategoryProvider.notifier).state = null;
      ref.read(dashboardSelectedCityProvider.notifier).state = null;
      ref.read(dashboardSelectedDateFilterProvider.notifier).state = null;

      // Invalidate all cached data providers to release resources and prevent stale access
      final userPaginationNotifier = ref.read(userPaginationProvider.notifier);
      userPaginationNotifier.clearOptimizationCaches();
      ref.invalidate(userPaginationProvider);
      clearPropertyPincodesCache();
      ref.invalidate(propertyPincodesProvider);
      ref.invalidate(userFilterCitiesProvider);
      ref.invalidate(userCitiesProvider);
      ref.invalidate(unverifiedCitiesProvider);
      ref.invalidate(unverifiedPaginationProvider);
      ref.invalidate(unverifiedPendingCountProvider);
      ref.invalidate(categoryCountsProvider);
      ref.invalidate(userStatsProvider);
      ref.invalidate(adminsStreamProvider);
      ref.invalidate(paginatedLocalPromotionsProvider);
      ref.invalidate(paginatedRentalProvider);
      ref.invalidate(paginatedPaymentProvider);
      ref.invalidate(collectionCountProvider);
      ref.invalidate(collectionTodayCountProvider);
      ref.invalidate(collectionPeriodStatsProvider);
      ref.invalidate(collectionDateFieldInfoProvider);
      ref.invalidate(currentAdminProfileProvider);
      ref.invalidate(isSuperAdminProvider);
      ref.invalidate(currentAdminAssignedCitiesProvider);
      ref.invalidate(allowedCitiesProvider);
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

