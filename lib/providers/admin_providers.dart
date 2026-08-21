import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/unverified_pagination_provider.dart';
import 'package:skazo_admin/providers/user_pagination_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/utils/property_pincodes_cache.dart';

// ── Models ────────────────────────────────────────────────────────────────────

enum AdminAccessStatus {
  loading,
  unauthenticated,
  unauthorized,
  authorized,
  error,
}

class AdminProfile {
  final String id;
  final String email;
  final String name;
  final String role;
  final String level;
  final List<String> assignedCities;
  final bool isSuperAdmin;
  final bool isActive;
  final Map<String, dynamic> rawData;

  const AdminProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.level,
    required this.assignedCities,
    required this.isSuperAdmin,
    required this.isActive,
    required this.rawData,
  });

  factory AdminProfile.fromDoc(String id, Map<String, dynamic> data) {
    final email = (data['email'] ?? '').toString().toLowerCase().trim();
    final name = (data['name'] ?? data['username'] ?? 'Admin').toString().trim();
    final role = (data['role'] ?? '').toString().toLowerCase().trim();
    final level = (data['level'] ?? '').toString().toLowerCase().trim();

    final isSuper = level == 'super_admin' ||
        level == 'administrator' ||
        role == 'super_admin' ||
        role == 'administrator';

    final bool active = data['isActive'] != false &&
        data['isactive'] != false &&
        data['status'] != 'inactive' &&
        data['status'] != 'disabled';

    List<String> cities = const [];
    if (!isSuper) {
      final dynamic rawCities = data['assignedCities'] ?? data['assigned_cities'];
      if (rawCities is List) {
        cities = rawCities
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (cities.isEmpty) {
        final singleCity = (data['assignedCity'] ?? data['city'] ?? data['City'])?.toString().trim();
        if (singleCity != null && singleCity.isNotEmpty) {
          cities = [singleCity];
        }
      }
    }

    return AdminProfile(
      id: id,
      email: email,
      name: name.isNotEmpty ? name : 'Admin',
      role: role,
      level: level,
      assignedCities: cities,
      isSuperAdmin: isSuper,
      isActive: active,
      rawData: data,
    );
  }
}

class AdminAccessState {
  final AdminAccessStatus status;
  final AdminProfile? profile;
  final String? errorMessage;

  const AdminAccessState._({
    required this.status,
    this.profile,
    this.errorMessage,
  });

  const AdminAccessState.loading()
      : this._(status: AdminAccessStatus.loading);

  const AdminAccessState.unauthenticated()
      : this._(status: AdminAccessStatus.unauthenticated);

  const AdminAccessState.unauthorized([String? reason])
      : this._(
          status: AdminAccessStatus.unauthorized,
          errorMessage: reason ?? 'Unauthorized admin account',
        );

  const AdminAccessState.authorized(AdminProfile profile)
      : this._(status: AdminAccessStatus.authorized, profile: profile);

  const AdminAccessState.error(String message)
      : this._(status: AdminAccessStatus.error, errorMessage: message);

  bool get isLoading => status == AdminAccessStatus.loading;
  bool get isAuthorized => status == AdminAccessStatus.authorized;
  bool get isUnauthorized => status == AdminAccessStatus.unauthorized;
  bool get isUnauthenticated => status == AdminAccessStatus.unauthenticated;
  bool get hasError => status == AdminAccessStatus.error;
}

// ── Providers ─────────────────────────────────────────────────────────────────

/// Provider to watch the Firebase Auth state
final authStateProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
});

/// Real-time StreamProvider watching the current logged-in admin's profile document in Firestore
final currentAdminProfileProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return authAsync.when(
    data: (authUser) {
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
    },
    loading: () => const Stream.empty(),
    error: (e, _) => Stream.error(e),
  );
});

/// Comprehensive Admin Access State Provider
///
/// Guarantees that auth and profile loading states NEVER flash "Access Denied".
final adminAccessStateProvider = Provider<AdminAccessState>((ref) {
  final authAsync = ref.watch(authStateProvider);

  return authAsync.when(
    data: (user) {
      if (user == null) {
        if (kDebugMode) debugPrint('[ADMIN] Auth state: unauthenticated');
        return const AdminAccessState.unauthenticated();
      }

      final profileAsync = ref.watch(currentAdminProfileProvider);

      return profileAsync.when(
        data: (rawProfile) {
          if (rawProfile == null) {
            if (kDebugMode) {
              debugPrint('[ADMIN] Unauthorized: ${user.email} not found in admin collection');
            }
            return const AdminAccessState.unauthorized(
              'Your email is not authorized as an administrator.',
            );
          }

          final profile = AdminProfile.fromDoc(
            rawProfile['id']?.toString() ?? '',
            rawProfile,
          );

          if (!profile.isActive) {
            if (kDebugMode) {
              debugPrint('[ADMIN] Unauthorized: Account ${profile.email} is inactive/disabled');
            }
            return const AdminAccessState.unauthorized(
              'Your administrator account has been deactivated.',
            );
          }

          if (kDebugMode) {
            debugPrint(
              '[ADMIN] Resolved Authorized Profile: email=${profile.email}, isSuper=${profile.isSuperAdmin}, assignedCities=${profile.assignedCities}',
            );
          }

          return AdminAccessState.authorized(profile);
        },
        loading: () => const AdminAccessState.loading(),
        error: (err, _) {
          if (kDebugMode) debugPrint('[ADMIN] Profile load error: $err');
          return AdminAccessState.error(err.toString());
        },
      );
    },
    loading: () => const AdminAccessState.loading(),
    error: (err, _) {
      if (kDebugMode) debugPrint('[ADMIN] Auth error: $err');
      return AdminAccessState.error(err.toString());
    },
  );
});

/// Typed AdminProfile Provider (null when not authorized)
final currentAdminModelProvider = Provider<AdminProfile?>((ref) {
  return ref.watch(adminAccessStateProvider).profile;
});

/// Provider checking if current logged in admin is a Super Admin
final isSuperAdminProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentAdminModelProvider);
  return profile?.isSuperAdmin ?? false;
});

/// Provider checking if current logged in admin account is Active
final isAdminActiveProvider = Provider<bool>((ref) {
  final profile = ref.watch(currentAdminModelProvider);
  return profile?.isActive ?? false;
});

/// Real-time provider extracting assigned cities for the current admin.
/// Returns empty list `[]` if Super Admin (meaning unrestricted access to all cities).
final currentAdminAssignedCitiesProvider = Provider<List<String>>((ref) {
  final profile = ref.watch(currentAdminModelProvider);
  if (profile == null || profile.isSuperAdmin) return const [];
  return profile.assignedCities;
});

/// Deterministic default city for the current admin.
///
/// Rules:
/// - Super Admin: returns `null` ("All Cities" by default).
/// - Normal Admin with exactly ONE assigned city: returns that city (e.g. "Hyderabad").
/// - Normal Admin with multiple assigned cities: returns the first assigned city.
final adminDefaultCityProvider = Provider<String?>((ref) {
  final isSuper = ref.watch(isSuperAdminProvider);
  if (isSuper) return null;

  final assigned = ref.watch(currentAdminAssignedCitiesProvider);
  if (assigned.isNotEmpty) {
    return assigned.first;
  }
  return null;
});

/// Provider returning all cities accessible to the current admin for UI dropdowns.
/// Returns all system cities for Super Admin, or assigned cities for regular Admin.
final allowedCitiesProvider = FutureProvider<List<String>>((ref) async {
  final isSuper = ref.watch(isSuperAdminProvider);
  if (isSuper) {
    final allCities = await ref.watch(userFilterCitiesProvider.future);
    return allCities;
  }
  final assigned = ref.watch(currentAdminAssignedCitiesProvider);
  return assigned;
});

/// StreamProvider to fetch admins collection list (cached)
final adminsStreamProvider = StreamProvider<QuerySnapshot>((ref) {
  return FirebaseFirestore.instance.collection('admin').snapshots();
});

/// Provider checking if a user's email is in the admins collection
final isAuthorizedAdminProvider = FutureProvider.family<bool, String>((ref, email) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('admin')
        .where('email', isEqualTo: email.toLowerCase().trim())
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  } catch (e) {
    debugPrint('Error checking admin status: $e');
    return false;
  }
});

/// Provider to handle logging out and invalidating cache
class AdminAuthNotifier extends StateNotifier<bool> {
  final Ref ref;
  AdminAuthNotifier(this.ref) : super(false);

  Future<void> signOut() async {
    state = true;
    try {
      await FirebaseAuth.instance.signOut();
      
      final selectedCategory = ref.read(dashboardSelectedCategoryProvider);
      ref.invalidate(userPaginationProvider);
      clearPropertyPincodesCache();
      ref.invalidate(propertyPincodesProvider);
      ref.invalidate(unverifiedPaginationProvider(selectedCategory));
      ref.invalidate(unverifiedPendingCountProvider);
      ref.invalidate(categoryCountsProvider);
      ref.invalidate(adminsStreamProvider);
      ref.invalidate(paginatedLocalPromotionsProvider);
      ref.invalidate(collectionCountProvider);
      ref.invalidate(collectionTodayCountProvider);
      ref.invalidate(collectionPeriodStatsProvider);
    } catch (e) {
      debugPrint('Error signing out: $e');
    } finally {
      state = false;
    }
  }
}

final adminAuthProvider = StateNotifierProvider<AdminAuthNotifier, bool>((ref) {
  return AdminAuthNotifier(ref);
});

