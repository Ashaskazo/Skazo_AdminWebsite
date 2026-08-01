import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/unverified_pagination_provider.dart';
import 'package:skazo_admin/providers/user_pagination_provider.dart';
import 'package:skazo_admin/repositories/user_repository.dart';

// Provider to track selected category in the dashboard summary
final dashboardSelectedCategoryProvider = StateProvider<String?>((ref) => null);

// Provider to track selected city for filtering
final dashboardSelectedCityProvider = StateProvider<String?>((ref) => null);

// Provider to track selected date filter for the dashboard unverified businesses
final dashboardSelectedDateFilterProvider = StateProvider<String?>(
  (ref) => null,
);

// Provider to get all unique cities from property_pincodes collection
final unverifiedCitiesProvider = FutureProvider<List<String>>((ref) async {
  return ref.watch(userFilterCitiesProvider.future);
});

class UserVerificationNotifier extends StateNotifier<bool> {
  final Ref ref;
  UserVerificationNotifier(this.ref) : super(false);

  void _invalidateUserData() {
    ref.invalidate(categoryCountsProvider);
    ref.invalidate(unverifiedPendingCountProvider);
    ref.invalidate(userStatsProvider);
    final selectedCategory = ref.read(dashboardSelectedCategoryProvider);
    ref.invalidate(unverifiedPaginationProvider(selectedCategory));
    final paginationNotifier = ref.read(userPaginationProvider.notifier);
    paginationNotifier.clearOptimizationCaches();
    paginationNotifier.refresh();
  }

  Future<bool> verifyUser(String userId) async {
    state = true;
    try {
      await ref.read(userRepositoryProvider).verifyUser(userId);

      _invalidateUserData();
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
      await ref.read(userRepositoryProvider).deactivateUser(userId);

      _invalidateUserData();
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

// Filter state — all consumed by UserPaginationNotifier for Firestore queries
final userSearchQueryProvider = StateProvider<String>((ref) => '');
final userSelectedCityProvider = StateProvider<String?>((ref) => null);
final userVerifiedOnlyProvider = StateProvider<bool>((ref) => false);
final userDateFilterProvider = StateProvider<String?>((ref) => null);
final userTypeFilterProvider = StateProvider<String>((ref) => 'All');
final userCategoryFilterProvider = StateProvider<String?>((ref) => null);
final userPriorityFilterProvider = StateProvider<int?>((ref) => null);
final userProfileCompleteFilterProvider = StateProvider<bool?>((ref) => null);
final userBusinessNameFilterProvider = StateProvider<String?>((ref) => null);
final userSortAscendingProvider = StateProvider<bool>((ref) => false);
