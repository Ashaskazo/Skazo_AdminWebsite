import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/call_log_sheet_provider.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/dashboard_provider.dart';
import 'package:skazo_admin/providers/deactivated_pagination_provider.dart';
import 'package:skazo_admin/providers/pay_per_lead_providers.dart';
import 'package:skazo_admin/providers/service_providers_provider.dart';
import 'package:skazo_admin/providers/unverified_pagination_provider.dart';
import 'package:skazo_admin/providers/user_pagination_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/repositories/user_repository.dart';
import 'package:skazo_admin/utils/city_resolver.dart';
import 'package:skazo_admin/utils/property_pincodes_cache.dart';

export 'package:skazo_admin/utils/city_resolver.dart'
    show AdminAccessStatus, CityAccessScope;

List<String> _extractAssignedCitiesFromProfile(Map<String, dynamic>? profile) {
  if (profile == null) return const [];

  final dynamic rawCities =
      profile['assignedCities'] ?? profile['assigned_cities'];
  final cities = <String>[];
  final seen = <String>{};

  void addCity(dynamic raw) {
    final trimmed = raw?.toString().trim() ?? '';
    final key = canonicalizeCityKey(trimmed);
    if (trimmed.isNotEmpty && seen.add(key)) {
      cities.add(trimmed);
    }
  }

  if (rawCities is List) {
    for (final item in rawCities) {
      addCity(item);
    }
    if (cities.isNotEmpty) return cities;
  }

  final singleCity = profile['assignedCity'] ?? profile['city'];
  addCity(singleCity);
  return cities;
}

bool _isProfileSuperAdmin(Map<String, dynamic>? profile) {
  if (profile == null) return false;
  final level = (profile['level'] ?? '').toString().toLowerCase().trim();
  final role = (profile['role'] ?? '').toString().toLowerCase().trim();
  return level == 'super_admin' ||
      level == 'administrator' ||
      role == 'super_admin';
}

bool _isProfileActive(Map<String, dynamic>? profile) {
  if (profile == null) return false;
  final status = (profile['status'] ?? '').toString().toLowerCase().trim();
  return profile['isActive'] != false && status != 'inactive';
}

/// Provider that checks if a user's email is in the admins collection and active.
final isAuthorizedAdminProvider = FutureProvider.family<bool, String>((ref, email) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('admin')
        .where('email', isEqualTo: email.toLowerCase().trim())
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return false;
    return _isProfileActive(snapshot.docs.first.data());
  } catch (e) {
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

/// Centralized real-time access scope for the current session.
/// Fails closed while loading, on errors, when inactive, or when assignedCities is empty.
final cityAccessScopeProvider = Provider<CityAccessScope>((ref) {
  final authAsync = ref.watch(authStateProvider);
  if (authAsync.isLoading) {
    return const CityAccessScope.loading();
  }
  if (authAsync.hasError) {
    return CityAccessScope.deniedUnauthorized(
      errorMessage: authAsync.error.toString(),
    );
  }

  final authUser = authAsync.value;
  if (authUser == null || authUser.email == null) {
    return const CityAccessScope.unauthenticated();
  }

  final email = authUser.email!.toLowerCase().trim();
  final profileAsync = ref.watch(currentAdminProfileProvider);

  return profileAsync.when(
    data: (profile) {
      if (profile == null) {
        return CityAccessScope.deniedUnauthorized(email: email);
      }
      final adminId = (profile['admin_id'] ?? profile['id'])?.toString();
      final displayName = profile['name']?.toString();
      final role = (profile['role'] ?? profile['level'])?.toString();

      if (!_isProfileActive(profile)) {
        return CityAccessScope.deniedInactive(
          email: email,
          adminId: adminId,
          displayName: displayName,
          role: role,
        );
      }

      final isSuper = _isProfileSuperAdmin(profile);
      if (isSuper) {
        return CityAccessScope.authorized(
          isSuperAdmin: true,
          adminId: adminId,
          email: email,
          displayName: displayName,
          role: role,
        );
      }

      final cities = _extractAssignedCitiesFromProfile(profile);
      return CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: cities,
        adminId: adminId,
        email: email,
        displayName: displayName,
        role: role,
      );
    },
    loading: () => CityAccessScope.loading(email: email),
    error: (err, _) => CityAccessScope.deniedUnauthorized(
      email: email,
      errorMessage: err.toString(),
    ),
  );
});

/// Provider checking if current logged in admin is a Super Admin
final isSuperAdminProvider = Provider<bool>((ref) {
  return ref.watch(cityAccessScopeProvider).isUnrestricted;
});

/// Provider checking if current logged in admin account is Active.
/// Returns false while loading or on error to enforce fail-closed access.
final isAdminActiveProvider = Provider<bool>((ref) {
  final scope = ref.watch(cityAccessScopeProvider);
  return scope.isAuthorized && scope.isActive;
});

/// Real-time provider extracting assigned cities for the current admin.
/// Note: Always pair with `isSuperAdminProvider` or prefer `cityAccessScopeProvider`,
/// because empty list may mean either Super Admin OR unauthorized/no cities assigned.
final currentAdminAssignedCitiesProvider = Provider<List<String>>((ref) {
  final scope = ref.watch(cityAccessScopeProvider);
  if (!scope.isAuthorized || scope.isSuperAdmin) return const [];
  return scope.assignedCities;
});

/// Provider returning all cities accessible to the current admin for UI dropdowns.
/// Returns all system cities for Super Admin, or assigned cities for regular Admin.
final allowedCitiesProvider = FutureProvider<List<String>>((ref) async {
  final scope = ref.watch(cityAccessScopeProvider);
  if (!scope.isAuthorized) return const [];

  if (scope.isSuperAdmin) {
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

  return scope.assignedCities;
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
  return _isProfileActive(profile);
});

/// Centralized session & cache reset coordinator for logout and account switching.
class SessionCacheCoordinator {
  final Ref _ref;
  SessionCacheCoordinator(this._ref);

  void resetAll({bool includeAuthProfile = true}) {
    // Reset view to summary default
    _ref.read(currentDashboardViewProvider.notifier).state =
        DashboardView.summary;
    _ref.read(sidebarCollapsedProvider.notifier).state = false;

    // Reset all entity filter providers
    _ref.read(userSearchQueryProvider.notifier).state = '';
    _ref.read(userSelectedCityProvider.notifier).state = null;
    _ref.read(userVerifiedOnlyProvider.notifier).state = false;
    _ref.read(userDateFilterProvider.notifier).state = null;
    _ref.read(userTypeFilterProvider.notifier).state = 'All';
    _ref.read(userCategoryFilterProvider.notifier).state = null;
    _ref.read(userPriorityFilterProvider.notifier).state = null;
    _ref.read(userProfileCompleteFilterProvider.notifier).state = null;
    _ref.read(userBusinessNameFilterProvider.notifier).state = null;
    _ref.read(userSortAscendingProvider.notifier).state = false;

    _ref.read(dashboardSelectedCategoryProvider.notifier).state = null;
    _ref.read(dashboardSelectedCityProvider.notifier).state = null;
    _ref.read(dashboardSelectedDateFilterProvider.notifier).state = null;

    _ref.read(deactivatedSearchQueryProvider.notifier).state = '';
    _ref.read(deactivatedSelectedCityProvider.notifier).state = null;
    _ref.read(deactivatedDateFilterProvider.notifier).state = null;
    _ref.read(deactivatedCustomDateRangeProvider.notifier).state = null;
    _ref.read(deactivatedStatusFilterProvider.notifier).state = 'Deactivated';

    _ref.read(rentalSearchQueryProvider.notifier).state = '';
    _ref.read(rentalSelectedCityProvider.notifier).state = null;
    _ref.read(rentalTypeFilterProvider.notifier).state = 'All';
    _ref.read(rentalTimeFilterProvider.notifier).state = 'All Time';
    _ref.read(rentalSortAscendingProvider.notifier).state = false;

    _ref.read(localPromotionsSearchQueryProvider.notifier).state = '';
    _ref.read(localPromotionsSelectedCityProvider.notifier).state = null;
    _ref.read(localPromotionsTypeFilterProvider.notifier).state = 'All';
    _ref.read(localPromotionsTimeFilterProvider.notifier).state = 'All Time';
    _ref.read(localPromotionsSortAscendingProvider.notifier).state = false;

    _ref.read(serviceSearchQueryProvider.notifier).state = '';
    _ref.read(serviceSelectedCategoryProvider.notifier).state = null;
    _ref.read(serviceStatusFilterProvider.notifier).state = null;
    _ref.read(serviceTodayOnlyProvider.notifier).state = false;
    _ref.read(serviceSelectedCityProvider.notifier).state = null;

    _ref.read(paymentSearchQueryProvider.notifier).state = '';
    _ref.read(selectedPaymentAdminFilterProvider.notifier).state = null;
    _ref.read(paymentSelectedCityProvider.notifier).state = null;

    _ref.read(serviceProvidersSelectedCityProvider.notifier).state = null;
    _ref.read(serviceProvidersSelectedZoneProvider.notifier).state = null;
    _ref.read(serviceProvidersCategorySearchQueryProvider.notifier).state = '';

    _ref.read(callLogSheetSearchQueryProvider.notifier).state = '';
    _ref.read(callLogSheetStatusFilterProvider.notifier).state = 'All';
    _ref.read(callLogSheetSelectedCityProvider.notifier).state = null;
    _ref.read(callLogSheetCurrentPageProvider.notifier).state = 0;

    clearPropertyPincodesCache();

    // Invalidate all data providers across every entity
    _ref.invalidate(userPaginationProvider);
    _ref.invalidate(deactivatedPaginationProvider);
    _ref.invalidate(propertyPincodesProvider);
    _ref.invalidate(userFilterCitiesProvider);
    _ref.invalidate(userCitiesProvider);
    _ref.invalidate(unverifiedCitiesProvider);
    _ref.invalidate(unverifiedPaginationProvider);
    _ref.invalidate(unverifiedPendingCountProvider);
    _ref.invalidate(categoryCountsProvider);
    _ref.invalidate(userStatsProvider);
    _ref.invalidate(adminsStreamProvider);
    _ref.invalidate(adminsListProvider);
    _ref.invalidate(paginatedLocalPromotionsProvider);
    _ref.invalidate(paginatedRentalProvider);
    _ref.invalidate(paginatedServicePostProvider);
    _ref.invalidate(serviceCategoriesProvider);
    _ref.invalidate(paginatedPaymentProvider);
    _ref.invalidate(paymentSalesStatsProvider);
    _ref.invalidate(payPerLeadPaginationProvider);
    _ref.invalidate(serviceProvidersOverviewProvider);
    _ref.invalidate(categoryProvidersPaginationProvider);
    _ref.invalidate(areaProvidersPaginationProvider);
    _ref.invalidate(callLogSheetNotifierProvider);
    _ref.invalidate(collectionDataProvider);
    _ref.invalidate(collectionCountProvider);
    _ref.invalidate(collectionTodayCountProvider);
    _ref.invalidate(collectionPeriodStatsProvider);
    _ref.invalidate(collectionDateFieldInfoProvider);

    if (includeAuthProfile) {
      _ref.invalidate(currentAdminProfileProvider);
      _ref.invalidate(cityAccessScopeProvider);
      _ref.invalidate(isSuperAdminProvider);
      _ref.invalidate(currentAdminAssignedCitiesProvider);
      _ref.invalidate(allowedCitiesProvider);
    }
  }
}

final sessionCacheCoordinatorProvider = Provider<SessionCacheCoordinator>((
  ref,
) {
  return SessionCacheCoordinator(ref);
});

/// Provider to handle logging out
class AdminAuthNotifier extends StateNotifier<bool> {
  final Ref ref;
  AdminAuthNotifier(this.ref) : super(false);

  Future<void> signOut() async {
    state = true; // Processing
    try {
      await FirebaseAuth.instance.signOut();
      ref.read(sessionCacheCoordinatorProvider).resetAll();
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

