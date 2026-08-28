import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/utils/city_resolver.dart';
import 'package:skazo_admin/utils/property_pincodes_cache.dart';

import '../models/user_filters.dart';
import '../repositories/user_repository.dart';
export 'package:skazo_admin/utils/city_resolver.dart' show getSmartCity;

// Generic provider for fetching data from any Firestore collection
final collectionDataProvider = FutureProvider.family<
  List<Map<String, dynamic>>,
  String
>((ref, collectionName) async {
  final searchQuery = ref.watch(userSearchQueryProvider);

  Query query = FirebaseFirestore.instance.collection(collectionName);

  if (searchQuery.isNotEmpty) {
    final phoneNum = int.tryParse(searchQuery);
    if (phoneNum != null) {
      final phoneWith91 = int.tryParse('91$searchQuery');
      if (searchQuery.startsWith('91')) {
        query = query.where('phone', isEqualTo: phoneNum);
      } else if (phoneWith91 != null) {
        query = query.where('phone', whereIn: [phoneNum, phoneWith91]);
      } else {
        query = query.where('phone', isEqualTo: phoneNum);
      }
    } else {
      query = query
          .where('name', isGreaterThanOrEqualTo: searchQuery)
          .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff');
    }
  }

  final snapshot = await query.limit(searchQuery.isNotEmpty ? 50 : 200).get();

  return snapshot.docs
      .map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)})
      .toList();
});

// Shared provider for user-related city filters across User Management and dashboard.
final userFilterCitiesProvider = FutureProvider<List<String>>((ref) async {
  final pincodesMap = await ref.watch(propertyPincodesProvider.future);
  final sortedCities = pincodesMap.keys.toList()..sort();
  return sortedCities;
});

// Backward-compatible city set provider for existing users page code.
final userCitiesProvider = FutureProvider<Set<String>>((ref) async {
  final cities = await ref.watch(allowedCitiesProvider.future);
  return cities.toSet();
});

// Payments State Providers
final paymentSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedPaymentAdminFilterProvider = StateProvider<String?>(
  (ref) => null,
);

final adminsListProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final snapshot = await FirebaseFirestore.instance.collection('admin').get();
  return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
});

class PaymentSalesStats {
  final double todaySale;
  final double yesterdaySale;
  final double thisMonthSale;
  final double totalSale;

  PaymentSalesStats({
    required this.todaySale,
    required this.yesterdaySale,
    required this.thisMonthSale,
    required this.totalSale,
  });
}

final paymentSalesStatsProvider =
    FutureProvider.family<PaymentSalesStats, String?>((
      ref,
      filterAdminId,
    ) async {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .where('totalAmount', isGreaterThan: 0)
              .get();

      double today = 0;
      double yesterday = 0;
      double thisMonth = 0;
      double total = 0;

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final senderId = data['paymentLinkSenderId']?.toString();

        // Filter by admin ID
        if (filterAdminId != null && senderId != filterAdminId) {
          continue;
        }

        final amount = (data['totalAmount'] as num?)?.toDouble() ?? 0.0;
        final paymentDateVal = data['paymentPaidAt'] ?? data['lastPaymentAt'];
        DateTime? paymentDate;
        if (paymentDateVal is Timestamp) {
          paymentDate = paymentDateVal.toDate();
        } else if (paymentDateVal is String) {
          paymentDate = DateTime.tryParse(paymentDateVal);
        } else if (paymentDateVal is int) {
          paymentDate = DateTime.fromMillisecondsSinceEpoch(paymentDateVal);
        }

        if (paymentDate != null) {
          total += amount;

          if (paymentDate.isAfter(todayStart) ||
              paymentDate.isAtSameMomentAs(todayStart)) {
            today += amount;
          } else if ((paymentDate.isAfter(yesterdayStart) ||
                  paymentDate.isAtSameMomentAs(yesterdayStart)) &&
              paymentDate.isBefore(todayStart)) {
            yesterday += amount;
          }

          if (paymentDate.isAfter(thirtyDaysAgo) ||
              paymentDate.isAtSameMomentAs(thirtyDaysAgo)) {
            thisMonth += amount;
          }
        }
      }

      return PaymentSalesStats(
        todaySale: today,
        yesterdaySale: yesterday,
        thisMonthSale: thisMonth,
        totalSale: total,
      );
    });

class PaginatedPaymentNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  PaginatedPaymentNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchInitial();
  }

  final List<DocumentSnapshot?> _pageCursors = [null];
  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalCount = 0;
  int _filteredCount = 0;

  Query _applyFilters(Query query) {
    final searchQuery = ref.read(paymentSearchQueryProvider);

    // Payments are usually for service providers, so we can filter by isuser == false and paymentLinkSend == true
    query = query
        .where('isuser', isEqualTo: false)
        .where('paymentLinkSend', isEqualTo: true);

    // Apply Admin Filter
    final isSuperAdmin = ref.read(isSuperAdminProvider);
    final adminProfile = ref.read(currentAdminProfileProvider).value;

    if (isSuperAdmin) {
      final selectedAdminId = ref.read(selectedPaymentAdminFilterProvider);
      if (selectedAdminId != null) {
        query = query.where('paymentLinkSenderId', isEqualTo: selectedAdminId);
      }
    } else {
      // Regular admin: only see their own payments
      final currentAdminId = adminProfile?['admin_id'] ?? adminProfile?['id'];
      if (currentAdminId != null) {
        query = query.where('paymentLinkSenderId', isEqualTo: currentAdminId);
      }
    }

    if (searchQuery.isNotEmpty) {
      final phoneNum = int.tryParse(searchQuery);
      if (phoneNum != null) {
        final phoneWith91 = int.tryParse('91$searchQuery');
        if (searchQuery.startsWith('91')) {
          query = query.where('phone', isEqualTo: phoneNum);
        } else if (phoneWith91 != null) {
          query = query.where('phone', whereIn: [phoneNum, phoneWith91]);
        } else {
          query = query.where('phone', isEqualTo: phoneNum);
        }
      } else {
        query = query
            .where('name', isGreaterThanOrEqualTo: searchQuery)
            .where('name', isLessThanOrEqualTo: '$searchQuery\uf8ff');
      }
    }
    return query;
  }

  Future<void> fetchInitial() async {
    _currentPage = 0;
    _pageCursors.clear();
    _pageCursors.add(null);

    try {
      Query query = FirebaseFirestore.instance.collection('users');
      query = _applyFilters(query);

      final countSnapshot = await query.count().get();
      _filteredCount = countSnapshot.count ?? 0;

      final searchQuery = ref.read(paymentSearchQueryProvider);
      if (searchQuery.isEmpty) {
        _totalCount = _filteredCount;
      }
    } catch (_) {}

    await fetchPage(0);
  }

  Future<void> fetchPage(int pageIndex) async {
    state = const AsyncValue.loading();
    try {
      Query query = FirebaseFirestore.instance.collection('users');
      query = _applyFilters(query);

      final searchQuery = ref.read(paymentSearchQueryProvider);
      if (searchQuery.isEmpty) {
        query = query.orderBy('createdAt', descending: true);
      }

      if (pageIndex < _pageCursors.length && _pageCursors[pageIndex] != null) {
        query = query.startAfterDocument(_pageCursors[pageIndex]!);
      }

      final snapshot = await query.limit(_pageSize).get();
      final users =
          snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ...(doc.data() as Map<String, dynamic>),
                },
              )
              .toList();

      if (snapshot.docs.isNotEmpty && snapshot.docs.length == _pageSize) {
        if (pageIndex + 1 == _pageCursors.length) {
          _pageCursors.add(snapshot.docs.last);
        }
      }

      _currentPage = pageIndex;
      state = AsyncValue.data(users);
    } catch (e) {
      debugPrint('Error fetching payments with ordering: $e');
      _fetchWithoutOrdering(pageIndex);
    }
  }

  Future<void> _fetchWithoutOrdering(int pageIndex) async {
    try {
      Query query = FirebaseFirestore.instance.collection('users');
      query = _applyFilters(query);

      if (pageIndex < _pageCursors.length && _pageCursors[pageIndex] != null) {
        query = query.startAfterDocument(_pageCursors[pageIndex]!);
      }

      final snapshot = await query.limit(_pageSize).get();
      final users =
          snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ...(doc.data() as Map<String, dynamic>),
                },
              )
              .toList();

      if (snapshot.docs.isNotEmpty && snapshot.docs.length == _pageSize) {
        if (pageIndex + 1 == _pageCursors.length) {
          _pageCursors.add(snapshot.docs.last);
        }
      }

      _currentPage = pageIndex;
      state = AsyncValue.data(users);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void nextPage() {
    if ((_currentPage + 1) * _pageSize < _filteredCount) {
      fetchPage(_currentPage + 1);
    }
  }

  void prevPage() {
    if (_currentPage > 0) {
      fetchPage(_currentPage - 1);
    }
  }

  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  int get totalCount => _totalCount;
  int get filteredCount => _filteredCount;
}

final paginatedPaymentProvider = StateNotifierProvider<
  PaginatedPaymentNotifier,
  AsyncValue<List<Map<String, dynamic>>>
>((ref) {
  return PaginatedPaymentNotifier(ref);
});

// Rental Property State Providers
final rentalSearchQueryProvider = StateProvider<String>((ref) => '');
final rentalSelectedCityProvider = StateProvider<String?>((ref) => null);
final rentalUnverifiedOnlyProvider = StateProvider<bool>((ref) => false);
final rentalTodayOnlyProvider = StateProvider<bool>((ref) => false);
final rentalTypeFilterProvider = StateProvider<String>((ref) => 'All');
final rentalTimeFilterProvider = StateProvider<String>((ref) => 'All Time');
final rentalSortAscendingProvider = StateProvider<bool>((ref) => false);

// Helper to extract image URLs from property map
List<String> extractPropertyImageUrls(Map<String, dynamic> prop) {
  final List<String> urls = [];

  void addValue(dynamic value) {
    if (value == null) return;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          final matches = RegExp(r'https?://[^\s",\]]+').allMatches(trimmed);
          for (var match in matches) {
            final url = match.group(0);
            if (url != null) urls.add(url);
          }
        } catch (_) {}
      } else if (trimmed.contains(',')) {
        for (var part in trimmed.split(',')) {
          final p = part.trim();
          if (p.startsWith('http://') || p.startsWith('https://')) {
            urls.add(p);
          }
        }
      } else if (trimmed.startsWith('http://') ||
          trimmed.startsWith('https://')) {
        urls.add(trimmed);
      }
    } else if (value is List) {
      for (var item in value) {
        if (item is String) {
          final trimmed = item.trim();
          if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
            urls.add(trimmed);
          }
        } else if (item != null) {
          final trimmed = item.toString().trim();
          if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
            urls.add(trimmed);
          }
        }
      }
    }
  }

  if (prop['photoUrls'] != null) addValue(prop['photoUrls']);
  if (prop['photoUrl'] != null) addValue(prop['photoUrl']);
  if (prop['image'] != null) addValue(prop['image']);
  if (prop['imageUrl'] != null) addValue(prop['imageUrl']);
  if (prop['images'] != null) addValue(prop['images']);
  if (prop['photos'] != null) addValue(prop['photos']);

  return urls.toSet().toList();
}

// Provider to gather a comprehensive list of cities for rental properties filter
final rentalCitiesProvider = FutureProvider<Set<String>>((ref) async {
  final cities = await ref.watch(allowedCitiesProvider.future);
  return cities.toSet();
});

// Paginated provider for the rental properties list utilizing real-time stream subscription
class PaginatedRentalNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  StreamSubscription? _subscription;
  List<Map<String, dynamic>> _allProperties = [];
  List<Map<String, dynamic>> _filteredProperties = [];

  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalCount = 0;
  int _filteredCount = 0;

  PaginatedRentalNotifier(this.ref) : super(const AsyncValue.loading()) {
    _initStream();

    // Listen to changes in filters and apply them in-memory
    ref.listen(rentalSearchQueryProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
    ref.listen(rentalSelectedCityProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
    ref.listen(rentalTypeFilterProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
    ref.listen(rentalTimeFilterProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
    ref.listen(rentalSortAscendingProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
  }

  void _initStream() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('rental_properties')
        .orderBy('createdAt', descending: true)
        .limit(2000)
        .snapshots()
        .listen(
          (snapshot) {
            _allProperties =
                snapshot.docs
                    .map((doc) => {'id': doc.id, ...doc.data()})
                    .toList();
            _applyFiltersAndNotify();
          },
          onError: (err, stack) {
            state = AsyncValue.error(err, stack);
          },
        );
  }

  List<Map<String, dynamic>> get allFilteredProperties => _filteredProperties;
  int get totalPages => (_filteredProperties.length / pageSize).ceil();

  void _applyFiltersAndNotify() {
    final searchQuery =
        ref.read(rentalSearchQueryProvider).trim().toLowerCase();
    final selectedCity = ref.read(rentalSelectedCityProvider);
    final filterType = ref.read(rentalTypeFilterProvider);
    final timeFilter = ref.read(rentalTimeFilterProvider);
    final assignedCities = ref.read(currentAdminAssignedCitiesProvider);
    final pincodesMap = ref.read(propertyPincodesProvider).value ?? {};
    final pincodeCityLookup = buildPincodeCityLookup(pincodesMap);

    _totalCount = _allProperties.length;

    List<Map<String, dynamic>> temp = List.from(_allProperties);

    // 1. Filter by City and Admin Assigned Cities Scope
    temp =
        temp.where((p) {
          return userMatchesAssignedCities(
            p,
            selectedCity,
            assignedCities,
            pincodesMap,
            pincodeCityLookup,
          );
        }).toList();

    // 2. Filter by Verification / Premium Type
    if (filterType == 'Verified') {
      temp = temp.where((p) => p['isPropertyVerified'] == true).toList();
    } else if (filterType == 'Unverified') {
      temp = temp.where((p) => p['isPropertyVerified'] != true).toList();
    } else if (filterType == 'Premium') {
      temp =
          temp.where((p) {
            final plan = p['ownerPlan']?.toString().toLowerCase() ?? '';
            final isBoosted = p['isBoosted'] == true;
            final isPremium = p['isPremium'] == true;
            return plan.contains('premium') ||
                plan == 'paid' ||
                plan == '599' ||
                isBoosted ||
                isPremium;
          }).toList();
    }

    // 3. Filter by Time
    if (timeFilter != 'All Time') {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
      final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));

      temp =
          temp.where((p) {
            final createdAtVal = p['createdAt'];
            DateTime? date;
            if (createdAtVal is Timestamp) {
              date = createdAtVal.toDate();
            } else if (createdAtVal is String) {
              date = DateTime.tryParse(createdAtVal);
            } else if (createdAtVal is int) {
              date = DateTime.fromMillisecondsSinceEpoch(createdAtVal);
            }

            if (date == null) return false;

            if (timeFilter == 'Today') {
              return date.isAfter(todayStart) ||
                  date.isAtSameMomentAs(todayStart);
            } else if (timeFilter == 'Yesterday') {
              return (date.isAfter(yesterdayStart) ||
                      date.isAtSameMomentAs(yesterdayStart)) &&
                  date.isBefore(todayStart);
            } else if (timeFilter == 'Last 7 Days') {
              return date.isAfter(sevenDaysAgo) ||
                  date.isAtSameMomentAs(sevenDaysAgo);
            } else if (timeFilter == 'Last 30 Days') {
              return date.isAfter(thirtyDaysAgo) ||
                  date.isAtSameMomentAs(thirtyDaysAgo);
            }
            return true;
          }).toList();
    }

    // 4. Filter by Search Query
    if (searchQuery.isNotEmpty) {
      temp =
          temp.where((p) {
            final name =
                (p['propertyName'] ?? p['title'] ?? p['name'])
                    ?.toString()
                    .toLowerCase() ??
                '';
            final owner = p['ownerName']?.toString().toLowerCase() ?? '';
            final city =
                (p['city'] ?? p['City'])?.toString().toLowerCase() ?? '';
            final location =
                (p['location'] ?? p['address'])?.toString().toLowerCase() ?? '';
            final type = p['type']?.toString().toLowerCase() ?? '';
            final bhk = p['bhk']?.toString().toLowerCase() ?? '';
            final landmark = p['landmark']?.toString().toLowerCase() ?? '';

            return name.contains(searchQuery) ||
                owner.contains(searchQuery) ||
                city.contains(searchQuery) ||
                location.contains(searchQuery) ||
                type.contains(searchQuery) ||
                bhk.contains(searchQuery) ||
                landmark.contains(searchQuery);
          }).toList();
    }

    final sortAscending = ref.read(rentalSortAscendingProvider);
    temp.sort((a, b) {
      final aDate =
          _parseDateTime(a['createdAt'] ?? a['timestamp']) ?? DateTime(2000);
      final bDate =
          _parseDateTime(b['createdAt'] ?? b['timestamp']) ?? DateTime(2000);
      return sortAscending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });

    _filteredProperties = temp;
    _filteredCount = temp.length;

    // Paginate
    final int start = _currentPage * _pageSize;
    if (start >= _filteredCount && _currentPage > 0) {
      _currentPage = (_filteredCount - 1) ~/ _pageSize;
    }
    if (_currentPage < 0) _currentPage = 0;

    final paginatedList =
        _filteredProperties
            .skip(_currentPage * _pageSize)
            .take(_pageSize)
            .toList();
    state = AsyncValue.data(paginatedList);
  }

  void nextPage() {
    if ((_currentPage + 1) * _pageSize < _filteredCount) {
      _currentPage++;
      _applyFiltersAndNotify();
    }
  }

  void prevPage() {
    if (_currentPage > 0) {
      _currentPage--;
      _applyFiltersAndNotify();
    }
  }

  void fetchInitial() {
    _currentPage = 0;
    _applyFiltersAndNotify();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  int get totalCount => _totalCount;
  int get filteredCount => _filteredCount;
}

final paginatedRentalProvider = StateNotifierProvider<
  PaginatedRentalNotifier,
  AsyncValue<List<Map<String, dynamic>>>
>((ref) {
  return PaginatedRentalNotifier(ref);
});

// Service Post State Providers
final serviceSearchQueryProvider = StateProvider<String>((ref) => '');
final serviceSelectedCategoryProvider = StateProvider<String?>((ref) => null);
final serviceTodayOnlyProvider = StateProvider<bool>((ref) => false);
final serviceStatusFilterProvider = StateProvider<String?>((ref) => null);

// Provider to gather a comprehensive list of categories from service posts
final serviceCategoriesProvider = FutureProvider<Set<String>>((ref) async {
  final snapshot =
      await FirebaseFirestore.instance
          .collection('service_posts')
          .limit(500)
          .get();
  final Set<String> categories = {};
  for (var doc in snapshot.docs) {
    final category = doc.data()['category']?.toString();
    if (category != null && category.isNotEmpty) categories.add(category);
  }
  return categories;
});

// Paginated provider for the service posts list
class PaginatedServicePostNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  PaginatedServicePostNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchInitial();
  }

  final List<DocumentSnapshot?> _pageCursors = [null];
  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalCount = 0;
  int _filteredCount = 0;
  int _todayCount = 0;

  Future<void> fetchInitial() async {
    _currentPage = 0;
    _pageCursors.clear();
    _pageCursors.add(null);

    try {
      final searchQuery = ref.read(serviceSearchQueryProvider);
      final selectedCategory = ref.read(serviceSelectedCategoryProvider);
      final selectedStatus = ref.read(serviceStatusFilterProvider);
      final todayOnly = ref.read(serviceTodayOnlyProvider);

      Query query = FirebaseFirestore.instance.collection('service_posts');

      if (searchQuery.isNotEmpty) {
        query = query
            .where('userName', isGreaterThanOrEqualTo: searchQuery)
            .where('userName', isLessThanOrEqualTo: '$searchQuery\uf8ff');
      } else if (selectedCategory != null) {
        query = query.where('category', isEqualTo: selectedCategory);
      }

      if (selectedStatus != null) {
        query = query.where('status', isEqualTo: selectedStatus);
      }

      if (todayOnly) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        query = query.where('timestamp', isGreaterThanOrEqualTo: todayStart);
      }

      final countSnapshot = await query.count().get();
      _filteredCount = countSnapshot.count ?? 0;

      // Calculate Today's Count separately
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todaySnapshot =
          await FirebaseFirestore.instance
              .collection('service_posts')
              .where('timestamp', isGreaterThanOrEqualTo: todayStart)
              .count()
              .get();
      _todayCount = todaySnapshot.count ?? 0;

      if (searchQuery.isEmpty &&
          selectedCategory == null &&
          selectedStatus == null &&
          !todayOnly) {
        _totalCount = _filteredCount;
      }
    } catch (_) {}

    await fetchPage(0);
  }

  Future<void> fetchPage(int pageIndex) async {
    state = const AsyncValue.loading();
    try {
      final searchQuery = ref.read(serviceSearchQueryProvider);
      final selectedCategory = ref.read(serviceSelectedCategoryProvider);
      final selectedStatus = ref.read(serviceStatusFilterProvider);
      final todayOnly = ref.read(serviceTodayOnlyProvider);

      Query query = FirebaseFirestore.instance.collection('service_posts');

      if (searchQuery.isNotEmpty) {
        query = query
            .where('userName', isGreaterThanOrEqualTo: searchQuery)
            .where('userName', isLessThanOrEqualTo: '$searchQuery\uf8ff');
      } else if (selectedCategory != null) {
        query = query.where('category', isEqualTo: selectedCategory);
      }

      if (selectedStatus != null) {
        query = query.where('status', isEqualTo: selectedStatus);
      }

      if (todayOnly) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        query = query.where('timestamp', isGreaterThanOrEqualTo: todayStart);
      }

      // Only apply ordering if no filters are active to avoid index errors
      if (searchQuery.isEmpty &&
          selectedCategory == null &&
          selectedStatus == null &&
          !todayOnly) {
        query = query.orderBy('timestamp', descending: true);
      }

      if (pageIndex < _pageCursors.length && _pageCursors[pageIndex] != null) {
        query = query.startAfterDocument(_pageCursors[pageIndex]!);
      }

      final snapshot = await query.limit(_pageSize).get();
      final posts =
          snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ...(doc.data() as Map<String, dynamic>),
                },
              )
              .toList();

      if (snapshot.docs.isNotEmpty && snapshot.docs.length == _pageSize) {
        if (pageIndex + 1 == _pageCursors.length) {
          _pageCursors.add(snapshot.docs.last);
        }
      }

      _currentPage = pageIndex;
      state = AsyncValue.data(posts);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void nextPage() {
    if ((_currentPage + 1) * _pageSize < _filteredCount) {
      fetchPage(_currentPage + 1);
    }
  }

  void prevPage() {
    if (_currentPage > 0) {
      fetchPage(_currentPage - 1);
    }
  }

  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  int get totalCount => _totalCount;
  int get filteredCount => _filteredCount;
  int get todayCount => _todayCount;
}

final paginatedServicePostProvider = StateNotifierProvider<
  PaginatedServicePostNotifier,
  AsyncValue<List<Map<String, dynamic>>>
>((ref) {
  return PaginatedServicePostNotifier(ref);
});

final collectionCountProvider = FutureProvider.family<int, String>((
  ref,
  collectionName,
) async {
  final isSuper = ref.watch(isSuperAdminProvider);
  final assignedCities =
      isSuper
          ? const <String>[]
          : ref.watch(currentAdminAssignedCitiesProvider);

  if (!isSuper && assignedCities.isNotEmpty) {
    if (collectionName == 'users') {
      final repo = ref.watch(userRepositoryProvider);
      return repo.countUsers(
        filters: const UserFilters(),
        assignedCities: assignedCities,
      );
    }
    Query query = FirebaseFirestore.instance.collection(collectionName);
    if (assignedCities.length == 1) {
      final snap =
          await query
              .where('city', isEqualTo: assignedCities.first)
              .count()
              .get();
      if ((snap.count ?? 0) > 0) return snap.count!;
      final snapKey =
          await query
              .where(
                'cityKey',
                isEqualTo: assignedCities.first.trim().toLowerCase(),
              )
              .count()
              .get();
      return snapKey.count ?? 0;
    } else if (assignedCities.length <= 30) {
      final snap =
          await query.where('city', whereIn: assignedCities).count().get();
      if ((snap.count ?? 0) > 0) return snap.count!;
      final snapKey =
          await query
              .where(
                'cityKey',
                whereIn:
                    assignedCities.map((c) => c.trim().toLowerCase()).toList(),
              )
              .count()
              .get();
      return snapKey.count ?? 0;
    }
  }

  final snapshot =
      await FirebaseFirestore.instance.collection(collectionName).count().get();
  return snapshot.count ?? 0;
});

class CollectionDateFieldInfo {
  final String fieldName;
  final String
  fieldType; // 'Timestamp', 'String', 'int_ms', 'int_sec', 'unknown'

  CollectionDateFieldInfo({required this.fieldName, required this.fieldType});
}

class CollectionPeriodStats {
  final int today;
  final int yesterday;
  final int last7Days;
  final int last30Days;

  CollectionPeriodStats({
    required this.today,
    required this.yesterday,
    required this.last7Days,
    required this.last30Days,
  });
}

void _logToWorkspace(String message) {
  if (kDebugMode) {
    debugPrint('Workspace Log: $message');
  }
}

Future<CollectionDateFieldInfo?> _detectDateField(String collectionName) async {
  try {
    _logToWorkspace('Detecting date field for collection: $collectionName');

    // Retrieve up to 20 documents to find one with date fields
    final snapshot =
        await FirebaseFirestore.instance
            .collection(collectionName)
            .limit(20)
            .get();

    if (snapshot.docs.isEmpty) {
      _logToWorkspace('Collection $collectionName has no documents');
      return null;
    }

    _logToWorkspace(
      'Retrieved ${snapshot.docs.length} documents for $collectionName',
    );

    final firstDoc = snapshot.docs.first;
    final firstDocData = firstDoc.data();
    final fieldsWithTypes = firstDocData.entries
        .map((e) => '${e.key} (${e.value?.runtimeType})')
        .join(', ');
    _logToWorkspace(
      'First doc ID in $collectionName: ${firstDoc.id}, Fields & Types: $fieldsWithTypes',
    );

    for (final field in [
      'createdAt',
      'timestamp',
      'date',
      'updatedAt',
      'created_at',
      'registeredAt',
    ]) {
      if (firstDocData.containsKey(field)) {
        _logToWorkspace(
          '$collectionName first doc $field value: ${firstDocData[field]} (type: ${firstDocData[field]?.runtimeType})',
        );
      }
    }

    // Ordered by preference
    final candidateFields = [
      'createdAt',
      'timestamp',
      'date',
      'updatedAt',
      'time',
      'datetime',
      'created_at',
      'joinedAt',
      'registeredAt',
      'registerDate',
      'creationTime',
      'created',
    ];

    // 1. Try candidate fields in all retrieved docs
    for (final doc in snapshot.docs) {
      final data = doc.data();
      for (final field in candidateFields) {
        if (data.containsKey(field) && data[field] != null) {
          final val = data[field];
          if (val is Timestamp) {
            _logToWorkspace(
              'Detected date field "$field" of type "Timestamp" for collection "$collectionName"',
            );
            return CollectionDateFieldInfo(
              fieldName: field,
              fieldType: 'Timestamp',
            );
          } else if (val is String) {
            String type = 'String';
            if (val.length == 10) {
              type = 'String_date'; // yyyy-MM-dd
            } else if (val.contains(' ')) {
              type = 'String_datetime_space'; // yyyy-MM-dd HH:mm:ss
            } else if (val.contains('T')) {
              type = 'String_datetime_T'; // yyyy-MM-ddTHH:mm:ss
            }
            _logToWorkspace(
              'Detected date field "$field" of type "$type" (sample: "$val") for collection "$collectionName"',
            );
            return CollectionDateFieldInfo(fieldName: field, fieldType: type);
          } else if (val is int) {
            if (val > 100000000000) {
              _logToWorkspace(
                'Detected date field "$field" of type "int_ms" for collection "$collectionName"',
              );
              return CollectionDateFieldInfo(
                fieldName: field,
                fieldType: 'int_ms',
              );
            } else {
              _logToWorkspace(
                'Detected date field "$field" of type "int_sec" for collection "$collectionName"',
              );
              return CollectionDateFieldInfo(
                fieldName: field,
                fieldType: 'int_sec',
              );
            }
          }
        }
      }
    }

    // 2. Fallback: Search for ANY field of type Timestamp
    for (final doc in snapshot.docs) {
      final data = doc.data();
      for (final entry in data.entries) {
        if (entry.value is Timestamp) {
          _logToWorkspace(
            'Fallback detected date field "${entry.key}" of type "Timestamp" for collection "$collectionName"',
          );
          return CollectionDateFieldInfo(
            fieldName: entry.key,
            fieldType: 'Timestamp',
          );
        }
      }
    }
  } catch (e) {
    _logToWorkspace('Error detecting date field for $collectionName: $e');
  }
  return null;
}

dynamic _convertDateTimeToQueryValue(DateTime dateTime, String fieldType) {
  final y = dateTime.year.toString().padLeft(4, '0');
  final m = dateTime.month.toString().padLeft(2, '0');
  final d = dateTime.day.toString().padLeft(2, '0');
  final hh = dateTime.hour.toString().padLeft(2, '0');
  final mm = dateTime.minute.toString().padLeft(2, '0');
  final ss = dateTime.second.toString().padLeft(2, '0');

  switch (fieldType) {
    case 'Timestamp':
      return Timestamp.fromDate(dateTime);
    case 'String_date':
      return '$y-$m-$d';
    case 'String_datetime_space':
      return '$y-$m-$d $hh:$mm:$ss';
    case 'String_datetime_T':
      return '$y-$m-${d}T$hh:$mm:$ss';
    case 'String':
      return dateTime.toIso8601String();
    case 'int_ms':
      return dateTime.millisecondsSinceEpoch;
    case 'int_sec':
      return dateTime.millisecondsSinceEpoch ~/ 1000;
    default:
      return dateTime;
  }
}

final Map<String, CollectionDateFieldInfo> _knownCollectionDateFields = {
  'users': CollectionDateFieldInfo(
    fieldName: 'createdAt',
    fieldType: 'Timestamp',
  ),
  'rental_properties': CollectionDateFieldInfo(
    fieldName: 'createdAt',
    fieldType: 'Timestamp',
  ),
  'service_posts': CollectionDateFieldInfo(
    fieldName: 'timestamp',
    fieldType: 'Timestamp',
  ),
  'local_promotions': CollectionDateFieldInfo(
    fieldName: 'createdAt',
    fieldType: 'Timestamp',
  ),
  'callLogs': CollectionDateFieldInfo(
    fieldName: 'timestamp',
    fieldType: 'Timestamp',
  ),
};

final collectionDateFieldInfoProvider =
    FutureProvider.family<CollectionDateFieldInfo?, String>((
      ref,
      collectionName,
    ) async {
      if (_knownCollectionDateFields.containsKey(collectionName)) {
        return _knownCollectionDateFields[collectionName];
      }
      return _detectDateField(collectionName);
    });

final collectionTodayCountProvider = FutureProvider.family<int, String>((
  ref,
  collectionName,
) async {
  final isSuper = ref.watch(isSuperAdminProvider);
  final assignedCities =
      isSuper
          ? const <String>[]
          : ref.watch(currentAdminAssignedCitiesProvider);

  final dateFieldInfo = await ref.watch(
    collectionDateFieldInfoProvider(collectionName).future,
  );

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  if (dateFieldInfo != null) {
    final fieldName = dateFieldInfo.fieldName;
    final fieldType = dateFieldInfo.fieldType;
    final todayVal = _convertDateTimeToQueryValue(todayStart, fieldType);

    Query query = FirebaseFirestore.instance.collection(collectionName);
    if (!isSuper && assignedCities.isNotEmpty) {
      if (collectionName == 'users') {
        if (assignedCities.length == 1) {
          query = query.where(
            'cityKey',
            isEqualTo: assignedCities.first.trim().toLowerCase(),
          );
        } else if (assignedCities.length <= 30) {
          query = query.where(
            'cityKey',
            whereIn: assignedCities.map((c) => c.trim().toLowerCase()).toList(),
          );
        }
      } else {
        if (assignedCities.length == 1) {
          query = query.where('city', isEqualTo: assignedCities.first);
        } else if (assignedCities.length <= 30) {
          query = query.where('city', whereIn: assignedCities);
        }
      }
    }

    final snapshot =
        await query
            .where(fieldName, isGreaterThanOrEqualTo: todayVal)
            .count()
            .get();
    return snapshot.count ?? 0;
  }

  return 0;
});

final collectionPeriodStatsProvider = FutureProvider.family<
  CollectionPeriodStats,
  String
>((ref, collectionName) async {
  final isSuper = ref.watch(isSuperAdminProvider);
  final assignedCities =
      isSuper
          ? const <String>[]
          : ref.watch(currentAdminAssignedCitiesProvider);

  final dateFieldInfo = await ref.watch(
    collectionDateFieldInfoProvider(collectionName).future,
  );

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final yesterdayStart = todayStart.subtract(const Duration(days: 1));
  final sevenDaysAgoStart = todayStart.subtract(const Duration(days: 7));
  final thirtyDaysAgoStart = todayStart.subtract(const Duration(days: 30));

  Future<CollectionPeriodStats?> queryStats(
    String fieldName,
    String fieldType,
  ) async {
    final todayVal = _convertDateTimeToQueryValue(todayStart, fieldType);
    final yesterdayVal = _convertDateTimeToQueryValue(
      yesterdayStart,
      fieldType,
    );
    final sevenDaysAgoVal = _convertDateTimeToQueryValue(
      sevenDaysAgoStart,
      fieldType,
    );
    final thirtyDaysAgoVal = _convertDateTimeToQueryValue(
      thirtyDaysAgoStart,
      fieldType,
    );

    try {
      Query baseQuery = FirebaseFirestore.instance.collection(collectionName);
      if (!isSuper && assignedCities.isNotEmpty) {
        if (collectionName == 'users') {
          if (assignedCities.length == 1) {
            baseQuery = baseQuery.where(
              'cityKey',
              isEqualTo: assignedCities.first.trim().toLowerCase(),
            );
          } else if (assignedCities.length <= 30) {
            baseQuery = baseQuery.where(
              'cityKey',
              whereIn:
                  assignedCities.map((c) => c.trim().toLowerCase()).toList(),
            );
          }
        } else {
          if (assignedCities.length == 1) {
            baseQuery = baseQuery.where(
              'city',
              isEqualTo: assignedCities.first,
            );
          } else if (assignedCities.length <= 30) {
            baseQuery = baseQuery.where('city', whereIn: assignedCities);
          }
        }
      }

      final todaySnap =
          await baseQuery
              .where(fieldName, isGreaterThanOrEqualTo: todayVal)
              .count()
              .get();
      final todayCount = todaySnap.count ?? 0;

      final yesterdaySnap =
          await baseQuery
              .where(fieldName, isGreaterThanOrEqualTo: yesterdayVal)
              .where(fieldName, isLessThan: todayVal)
              .count()
              .get();
      final yesterdayCount = yesterdaySnap.count ?? 0;

      final sevenDaysSnap =
          await baseQuery
              .where(fieldName, isGreaterThanOrEqualTo: sevenDaysAgoVal)
              .count()
              .get();
      final sevenDaysCount = sevenDaysSnap.count ?? 0;

      final thirtyDaysSnap =
          await baseQuery
              .where(fieldName, isGreaterThanOrEqualTo: thirtyDaysAgoVal)
              .count()
              .get();
      final thirtyDaysCount = thirtyDaysSnap.count ?? 0;

      final stats = CollectionPeriodStats(
        today: todayCount,
        yesterday: yesterdayCount,
        last7Days: sevenDaysCount,
        last30Days: thirtyDaysCount,
      );
      _logToWorkspace(
        'Successful queryStats for $collectionName using field $fieldName ($fieldType): Today=${stats.today}, Yesterday=${stats.yesterday}, 7d=${stats.last7Days}, 30d=${stats.last30Days}',
      );
      return stats;
    } catch (e) {
      _logToWorkspace(
        'Error querying stats for $collectionName on field $fieldName: $e',
      );
      debugPrint(
        'Error querying stats for $collectionName on field $fieldName: $e',
      );
      return null;
    }
  }

  // 1. Try with detected field
  if (dateFieldInfo != null) {
    _logToWorkspace(
      'Attempting queryStats using detected field: ${dateFieldInfo.fieldName}',
    );
    final stats = await queryStats(
      dateFieldInfo.fieldName,
      dateFieldInfo.fieldType,
    );
    if (stats != null) return stats;
  } else {
    _logToWorkspace(
      'No date field detected for $collectionName. Proceeding to fallback fields.',
    );
  }

  // 2. Fallback: try common fields sequentially as Timestamp
  final fallbackFields = ['createdAt', 'timestamp', 'date', 'updatedAt'];
  for (final field in fallbackFields) {
    _logToWorkspace('Attempting fallback queryStats using field: $field');
    final stats = await queryStats(field, 'Timestamp');
    if (stats != null &&
        (stats.today > 0 ||
            stats.yesterday > 0 ||
            stats.last7Days > 0 ||
            stats.last30Days > 0)) {
      _logToWorkspace(
        'Fallback succeeded for $collectionName using field $field: Today=${stats.today}, Yesterday=${stats.yesterday}, 7d=${stats.last7Days}, 30d=${stats.last30Days}',
      );
      return stats;
    }
  }

  _logToWorkspace(
    'All queries and fallbacks returned zero or failed for $collectionName',
  );

  return CollectionPeriodStats(
    today: 0,
    yesterday: 0,
    last7Days: 0,
    last30Days: 0,
  );
});

// Local Promotions State Providers
final localPromotionsSearchQueryProvider = StateProvider<String>((ref) => '');
final localPromotionsSelectedCityProvider = StateProvider<String?>(
  (ref) => null,
);
final localPromotionsTypeFilterProvider = StateProvider<String>((ref) => 'All');
final localPromotionsTimeFilterProvider = StateProvider<String>(
  (ref) => 'All Time',
);
final localPromotionsSortAscendingProvider = StateProvider<bool>(
  (ref) => false,
);

// Helper to extract image URLs from promotion map
List<String> extractPromotionImageUrls(Map<String, dynamic> promo) {
  final List<String> urls = [];

  void addValue(dynamic value) {
    if (value == null) return;
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return;
      if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
        try {
          final matches = RegExp(r'https?://[^\s",\]]+').allMatches(trimmed);
          for (var match in matches) {
            final url = match.group(0);
            if (url != null) urls.add(url);
          }
        } catch (_) {}
      } else if (trimmed.contains(',')) {
        for (var part in trimmed.split(',')) {
          final p = part.trim();
          if (p.startsWith('http://') || p.startsWith('https://')) {
            urls.add(p);
          }
        }
      } else if (trimmed.startsWith('http://') ||
          trimmed.startsWith('https://')) {
        urls.add(trimmed);
      }
    } else if (value is List) {
      for (var item in value) {
        if (item is String) {
          final trimmed = item.trim();
          if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
            urls.add(trimmed);
          }
        } else if (item != null) {
          final trimmed = item.toString().trim();
          if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
            urls.add(trimmed);
          }
        }
      }
    }
  }

  if (promo['imageUrl'] != null) addValue(promo['imageUrl']);
  if (promo['image'] != null) addValue(promo['image']);
  if (promo['photoUrl'] != null) addValue(promo['photoUrl']);
  if (promo['photoUrls'] != null) addValue(promo['photoUrls']);
  if (promo['photos'] != null) addValue(promo['photos']);
  if (promo['images'] != null) addValue(promo['images']);
  if (promo['bannerUrl'] != null) addValue(promo['bannerUrl']);
  if (promo['logoUrl'] != null) addValue(promo['logoUrl']);

  return urls.toSet().toList();
}

// Provider to gather a comprehensive list of cities for local promotions filter
final localPromotionsCitiesProvider = FutureProvider<Set<String>>((ref) async {
  final cities = await ref.watch(allowedCitiesProvider.future);
  return cities.toSet();
});

// Paginated provider for the local promotions list utilizing real-time stream subscription
class PaginatedLocalPromotionsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  StreamSubscription? _subscription;
  List<Map<String, dynamic>> _allPromotions = [];
  List<Map<String, dynamic>> _filteredPromotions = [];

  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalCount = 0;
  int _filteredCount = 0;

  PaginatedLocalPromotionsNotifier(this.ref)
    : super(const AsyncValue.loading()) {
    _initStream();

    // Listen to changes in filters and apply them in-memory
    ref.listen(localPromotionsSearchQueryProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
    ref.listen(localPromotionsSelectedCityProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
    ref.listen(currentAdminAssignedCitiesProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
    ref.listen(localPromotionsTypeFilterProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
    ref.listen(localPromotionsTimeFilterProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
    ref.listen(localPromotionsSortAscendingProvider, (prev, next) {
      _currentPage = 0;
      _applyFiltersAndNotify();
    });
  }

  void _initStream() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('local_promotions')
        .snapshots()
        .listen(
          (snapshot) {
            _allPromotions =
                snapshot.docs
                    .map((doc) => {'id': doc.id, ...doc.data()})
                    .toList();

            // Sort by createdAt descending in memory
            _allPromotions.sort((a, b) {
              final aDate =
                  _parseDateTime(a['createdAt'] ?? a['timestamp']) ??
                  DateTime(2000);
              final bDate =
                  _parseDateTime(b['createdAt'] ?? b['timestamp']) ??
                  DateTime(2000);
              return bDate.compareTo(aDate);
            });

            _applyFiltersAndNotify();
          },
          onError: (err, stack) {
            state = AsyncValue.error(err, stack);
          },
        );
  }

  void _applyFiltersAndNotify() {
    final searchQuery =
        ref.read(localPromotionsSearchQueryProvider).trim().toLowerCase();
    final selectedCity = ref.read(localPromotionsSelectedCityProvider);
    final filterType = ref.read(localPromotionsTypeFilterProvider);
    final timeFilter = ref.read(localPromotionsTimeFilterProvider);
    final assignedCities = ref.read(currentAdminAssignedCitiesProvider);
    final pincodesMap = ref.read(propertyPincodesProvider).value ?? {};
    final pincodeCityLookup = buildPincodeCityLookup(pincodesMap);

    _totalCount = _allPromotions.length;

    List<Map<String, dynamic>> temp = List.from(_allPromotions);

    // 1. Filter by City and Admin Assigned Cities Scope
    temp =
        temp.where((p) {
          return userMatchesAssignedCities(
            p,
            selectedCity,
            assignedCities,
            pincodesMap,
            pincodeCityLookup,
          );
        }).toList();

    // 2. Filter by Verification Status Type
    if (filterType == 'Verified') {
      temp =
          temp
              .where(
                (p) =>
                    p['isVerified'] == true ||
                    p['isPropertyVerified'] == true ||
                    p['status'] == 'live',
              )
              .toList();
    } else if (filterType == 'Unverified') {
      temp =
          temp
              .where(
                (p) =>
                    p['isVerified'] != true &&
                    p['isPropertyVerified'] != true &&
                    p['status'] != 'live',
              )
              .toList();
    }

    // 3. Filter by Time
    if (timeFilter != 'All Time') {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
      final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));

      temp =
          temp.where((p) {
            final date = _parseDateTime(p['createdAt'] ?? p['timestamp']);
            if (date == null) return false;

            if (timeFilter == 'Today') {
              return date.isAfter(todayStart) ||
                  date.isAtSameMomentAs(todayStart);
            } else if (timeFilter == 'Yesterday') {
              return (date.isAfter(yesterdayStart) ||
                      date.isAtSameMomentAs(yesterdayStart)) &&
                  date.isBefore(todayStart);
            } else if (timeFilter == 'Last 7 Days') {
              return date.isAfter(sevenDaysAgo) ||
                  date.isAtSameMomentAs(sevenDaysAgo);
            } else if (timeFilter == 'Last 30 Days') {
              return date.isAfter(thirtyDaysAgo) ||
                  date.isAtSameMomentAs(thirtyDaysAgo);
            }
            return true;
          }).toList();
    }

    // 4. Filter by Search Query
    if (searchQuery.isNotEmpty) {
      temp =
          temp.where((p) {
            final title =
                (p['brandName'] ??
                        p['title'] ??
                        p['propertyName'] ??
                        p['name'] ??
                        p['businessName'])
                    ?.toString()
                    .toLowerCase() ??
                '';
            final desc =
                (p['description'] ?? p['desc'] ?? p['content'] ?? p['bio'])
                    ?.toString()
                    .toLowerCase() ??
                '';
            final address = p['address']?.toString().toLowerCase() ?? '';
            final city =
                (p['city'] ?? p['City'])?.toString().toLowerCase() ?? '';

            return title.contains(searchQuery) ||
                desc.contains(searchQuery) ||
                address.contains(searchQuery) ||
                city.contains(searchQuery);
          }).toList();
    }

    final sortAscending = ref.read(localPromotionsSortAscendingProvider);
    temp.sort((a, b) {
      final aDate =
          _parseDateTime(a['createdAt'] ?? a['timestamp']) ?? DateTime(2000);
      final bDate =
          _parseDateTime(b['createdAt'] ?? b['timestamp']) ?? DateTime(2000);
      return sortAscending ? aDate.compareTo(bDate) : bDate.compareTo(aDate);
    });

    _filteredPromotions = temp;
    _filteredCount = temp.length;

    // Paginate
    final int start = _currentPage * _pageSize;
    if (start >= _filteredCount && _currentPage > 0) {
      _currentPage = (_filteredCount - 1) ~/ _pageSize;
    }
    if (_currentPage < 0) _currentPage = 0;

    final paginatedList =
        _filteredPromotions
            .skip(_currentPage * _pageSize)
            .take(_pageSize)
            .toList();
    state = AsyncValue.data(paginatedList);
  }

  void nextPage() {
    if ((_currentPage + 1) * _pageSize < _filteredCount) {
      _currentPage++;
      _applyFiltersAndNotify();
    }
  }

  void prevPage() {
    if (_currentPage > 0) {
      _currentPage--;
      _applyFiltersAndNotify();
    }
  }

  void fetchInitial() {
    _currentPage = 0;
    _applyFiltersAndNotify();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  int get currentPage => _currentPage;
  int get pageSize => _pageSize;
  int get totalCount => _totalCount;
  int get filteredCount => _filteredCount;
}

final paginatedLocalPromotionsProvider = StateNotifierProvider<
  PaginatedLocalPromotionsNotifier,
  AsyncValue<List<Map<String, dynamic>>>
>((ref) {
  return PaginatedLocalPromotionsNotifier(ref);
});

// Provider that fetches city to pincode lists mapping from Firestore 'property_pincodes' collection
final propertyPincodesProvider = FutureProvider<Map<String, List<String>>>((
  ref,
) async {
  ref.keepAlive();
  return loadPropertyPincodes();
});

DateTime? _parseDateTime(dynamic val) {
  if (val == null) return null;
  if (val is DateTime) return val;
  try {
    return val.toDate();
  } catch (_) {}
  if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
  if (val is String) {
    final p = DateTime.tryParse(val);
    if (p != null) return p;
    return _parseCustomDateTime(val);
  }
  return null;
}

DateTime? _parseCustomDateTime(String val) {
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
        'january': 1,
        'february': 2,
        'march': 3,
        'april': 4,
        'may': 5,
        'june': 6,
        'july': 7,
        'august': 8,
        'september': 9,
        'october': 10,
        'november': 11,
        'december': 12,
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final month = months[monthStr];

      if (day != null && month != null && year != null) {
        if (parts.length >= 6 && parts[5].startsWith('UTC')) {
          final offsetStr = parts[5].substring(3);
          final isNegative = offsetStr.startsWith('-');
          final cleanOffset = offsetStr.replaceAll('+', '').replaceAll('-', '');
          final offsetParts = cleanOffset.split(':');
          final offsetHours =
              offsetParts.isNotEmpty ? int.tryParse(offsetParts[0]) ?? 0 : 0;
          final offsetMinutes =
              offsetParts.length > 1 ? int.tryParse(offsetParts[1]) ?? 0 : 0;

          final utcTime = DateTime.utc(year, month, day, hour, minute, second);
          final duration = Duration(hours: offsetHours, minutes: offsetMinutes);
          return isNegative
              ? utcTime.add(duration)
              : utcTime.subtract(duration);
        }
        return DateTime(year, month, day, hour, minute, second);
      }
    }
  } catch (_) {}
  return null;
}
