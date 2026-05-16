import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/user_providers.dart';

String getSmartCity(Map<String, dynamic> user) {
  final cityField = (user['City'] ?? user['city'])?.toString();
  final address = user['businessaddress']?.toString() ?? '';
  
  // Extract 6-digit pincode
  final pinMatch = RegExp(r'\d{6}').firstMatch(address);
  final pincode = pinMatch?.group(0);

  if (pincode != null) {
    final pin = int.tryParse(pincode) ?? 0;
    
    // Vijayawada: 520001 to 520099
    if (pin >= 520001 && pin <= 520099) return 'Vijayawada';
    // Hyderabad: 500001 to 500096
    if (pin >= 500001 && pin <= 500096) return 'Hyderabad';
    // Bheemavaram: 534201 to 534299
    if (pin >= 534201 && pin <= 534299) return 'Bheemavaram';
    // Bangalore: 560001 to 560111, or 562XXX
    if ((pin >= 560001 && pin <= 560111) || (pin >= 562000 && pin <= 562999)) return 'Bangalore';
    // Tirupathi: 517501 to 517599
    if (pin >= 517501 && pin <= 517599) return 'Tirupathi';
    // Guntur: 522001, 522007
    if (pin == 522001 || pin == 522007) return 'Guntur';
  }

  if (cityField != null && cityField.isNotEmpty) return cityField;
  
  if (address.contains('Machilipatnam')) return 'Machilipatnam';
  if (address.contains('Vijayawada')) return 'Vijayawada';
  if (address.contains('Hyderabad')) return 'Hyderabad';
  if (address.contains('Bangalore')) return 'Bangalore';
  
  return cityField ?? 'Unknown';
}

// Generic provider for fetching data from any Firestore collection
final collectionDataProvider = FutureProvider.family<
  List<Map<String, dynamic>>,
  String
>((ref, collectionName) async {
  final searchQuery = ref.watch(userSearchQueryProvider);
  final selectedCity = ref.watch(userSelectedCityProvider);

  Query query = FirebaseFirestore.instance.collection(collectionName);

  if (searchQuery.isNotEmpty) {
    final phoneNum = int.tryParse(searchQuery);
    if (phoneNum != null) {
      query = query.where('phone', isEqualTo: phoneNum);
    } else {
      query = query.where('phone', isEqualTo: searchQuery);
    }
  } else if (selectedCity != null) {
    query = query.where('City', isEqualTo: selectedCity);
  }

  final snapshot = await query.limit(searchQuery.isNotEmpty ? 50 : 200).get();

  return snapshot.docs
      .map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)})
      .toList();
});

// Provider to gather a comprehensive list of cities from the database
final userCitiesProvider = FutureProvider<Set<String>>((ref) async {
  // We fetch a larger batch of users once to gather city names
  final snapshot = await FirebaseFirestore.instance.collection('users').limit(1000).get();
  final Set<String> cities = {};
  for (var doc in snapshot.docs) {
    final data = doc.data();
    final city = (data['City'] ?? data['city'])?.toString();
    if (city != null && city.isNotEmpty) cities.add(city);

    // Also extract from address to populate the dropdown
    final address = data['businessaddress']?.toString() ?? '';
    if (address.contains('Machilipatnam')) cities.add('Machilipatnam');
    if (address.contains('Vijayawada')) cities.add('Vijayawada');
    if (address.contains('Hyderabad')) cities.add('Hyderabad');
    if (address.contains('Bangalore')) cities.add('Bangalore');
    if (address.contains('Tirupathi')) cities.add('Tirupathi');
    if (address.contains('Guntur')) cities.add('Guntur');
    if (address.contains('Bheemavaram')) cities.add('Bheemavaram');
  }
  return cities;
});

// Paginated provider for the users list with explicit page navigation
class PaginatedUserNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  PaginatedUserNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchInitial();
  }

  final List<DocumentSnapshot?> _pageCursors = [null];
  int _currentPage = 0;
  final int _pageSize = 100;
  int _totalCount = 0;
  int _filteredCount = 0;
  int _verifiedCount = 0;

  Future<void> fetchInitial() async {
    _currentPage = 0;
    _pageCursors.clear();
    _pageCursors.add(null);
    _filteredCount = 0;
    _verifiedCount = 0;

    try {
      final searchQuery = ref.read(userSearchQueryProvider);
      final selectedCity = ref.read(userSelectedCityProvider);

      Query query = FirebaseFirestore.instance.collection('users');
      final verifiedOnly = ref.read(userVerifiedOnlyProvider);

      if (searchQuery.isNotEmpty) {
        if (verifiedOnly) {
          // Search by business address using starts-with query
          query = query.where('businessaddress', isGreaterThanOrEqualTo: searchQuery)
                       .where('businessaddress', isLessThanOrEqualTo: '$searchQuery\uf8ff');
        } else {
          final phoneNum = int.tryParse(searchQuery);
          query = query.where('phone', isEqualTo: phoneNum ?? searchQuery);
        }
      } else if (selectedCity != null) {
        query = query.where('City', isGreaterThanOrEqualTo: selectedCity)
                     .where('City', isLessThanOrEqualTo: '$selectedCity\uf8ff');
      }

      // Base filtered count
      var countSnapshot = await query.count().get();
      _filteredCount = countSnapshot.count ?? 0;

      // Fallback for lowercase 'city' field if needed
      if (_filteredCount == 0 && selectedCity != null && searchQuery.isEmpty) {
        query = FirebaseFirestore.instance.collection('users')
                     .where('city', isGreaterThanOrEqualTo: selectedCity)
                     .where('city', isLessThanOrEqualTo: '$selectedCity\uf8ff');
        countSnapshot = await query.count().get();
        _filteredCount = countSnapshot.count ?? 0;
      }

      // Service Provider count
      final verifiedSnapshot = await query.where('isverified', isEqualTo: true).count().get();
      _verifiedCount = verifiedSnapshot.count ?? 0;

      if (searchQuery.isEmpty && selectedCity == null) {
        _totalCount = _filteredCount;
      }
    } catch (_) {}

    await fetchPage(0);
  }

  Future<void> fetchPage(int pageIndex) async {
    state = const AsyncValue.loading();
    try {
      final searchQuery = ref.read(userSearchQueryProvider);
      final selectedCity = ref.read(userSelectedCityProvider);
      final verifiedOnly = ref.read(userVerifiedOnlyProvider);

      Query query = FirebaseFirestore.instance.collection('users');

      if (searchQuery.isNotEmpty) {
        if (verifiedOnly) {
          // Search by business address using starts-with query
          query = query.where('businessaddress', isGreaterThanOrEqualTo: searchQuery)
                       .where('businessaddress', isLessThanOrEqualTo: '$searchQuery\uf8ff');
        } else {
          final phoneNum = int.tryParse(searchQuery);
          query = query.where('phone', isEqualTo: phoneNum ?? searchQuery);
        }
      } else if (selectedCity != null) {
        // Use a range query to catch variations (e.g., "Vijayawada Rural")
        query = query.where('City', isGreaterThanOrEqualTo: selectedCity)
                     .where('City', isLessThanOrEqualTo: '$selectedCity\uf8ff');
      }

      if (verifiedOnly) {
        query = query.where('isverified', isEqualTo: true);
      }

      if (searchQuery.isEmpty && selectedCity == null && !verifiedOnly) {
        query = query.orderBy(FieldPath.documentId);
      }

      if (pageIndex < _pageCursors.length && _pageCursors[pageIndex] != null) {
        query = query.startAtDocument(_pageCursors[pageIndex]!);
      }

      final snapshot = await query.limit(_pageSize).get();

      if (snapshot.docs.isNotEmpty) {
        final users =
            snapshot.docs
                .map(
                  (doc) => {
                    'id': doc.id,
                    ...(doc.data() as Map<String, dynamic>),
                  },
                )
                .toList();

        if (pageIndex + 1 == _pageCursors.length &&
            snapshot.docs.length == _pageSize) {
          _pageCursors.add(snapshot.docs.last);
        }

        _currentPage = pageIndex;
        state = AsyncValue.data(users);
      } else {
        if (selectedCity != null && searchQuery.isEmpty) {
          return _fetchWithLowercaseCity(pageIndex, selectedCity);
        }
        state = const AsyncValue.data([]);
      }
    } catch (e, stack) {
      _fetchWithoutOrdering(pageIndex);
    }
  }

  Future<void> _fetchWithLowercaseCity(int pageIndex, String selectedCity) async {
    try {
      final verifiedOnly = ref.read(userVerifiedOnlyProvider);
      Query query = FirebaseFirestore.instance.collection('users').where('city', isEqualTo: selectedCity);
      if (verifiedOnly) {
        query = query.where('isverified', isEqualTo: true);
      }
      if (pageIndex < _pageCursors.length && _pageCursors[pageIndex] != null) {
        query = query.startAtDocument(_pageCursors[pageIndex]!);
      }
      final snapshot = await query.limit(_pageSize).get();
      final users = snapshot.docs.map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)}).toList();
      state = AsyncValue.data(users);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _fetchWithoutOrdering(int pageIndex) async {
    try {
      final searchQuery = ref.read(userSearchQueryProvider);
      final selectedCity = ref.read(userSelectedCityProvider);
      final verifiedOnly = ref.read(userVerifiedOnlyProvider);
      
      Query query = FirebaseFirestore.instance.collection('users');
      if (searchQuery.isNotEmpty) {
        if (verifiedOnly) {
          query = query.where('businessaddress', isGreaterThanOrEqualTo: searchQuery)
                       .where('businessaddress', isLessThanOrEqualTo: '$searchQuery\uf8ff');
        } else {
          final phoneNum = int.tryParse(searchQuery);
          query = query.where('phone', isEqualTo: phoneNum ?? searchQuery);
        }
      } else if (selectedCity != null) {
        query = query.where('City', isEqualTo: selectedCity);
      }
      
      if (verifiedOnly) {
        query = query.where('isverified', isEqualTo: true);
      }
      
      if (pageIndex < _pageCursors.length && _pageCursors[pageIndex] != null) {
        query = query.startAtDocument(_pageCursors[pageIndex]!);
      }
      final snapshot = await query.limit(_pageSize).get();
      final users = snapshot.docs.map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)}).toList();
      state = AsyncValue.data(users);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void nextPage() {
    final count = ref.read(userVerifiedOnlyProvider) ? _verifiedCount : _filteredCount;
    if ((_currentPage + 1) * _pageSize < count) {
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
  int get verifiedCount => _verifiedCount;
}

final paginatedUserProvider = StateNotifierProvider<
    PaginatedUserNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return PaginatedUserNotifier(ref);
});

// Rental Property State Providers
final rentalSearchQueryProvider = StateProvider<String>((ref) => '');
final rentalSelectedCityProvider = StateProvider<String?>((ref) => null);
final rentalUnverifiedOnlyProvider = StateProvider<bool>((ref) => false);
final rentalTodayOnlyProvider = StateProvider<bool>((ref) => false);

// Provider to gather a comprehensive list of cities from rental properties
final rentalCitiesProvider = FutureProvider<Set<String>>((ref) async {
  final snapshot = await FirebaseFirestore.instance.collection('rental_properties').limit(500).get();
  final Set<String> cities = {};
  for (var doc in snapshot.docs) {
    final data = doc.data();
    final city = (data['city'] ?? data['City'])?.toString();
    if (city != null && city.isNotEmpty) cities.add(city);
  }
  return cities;
});

// Paginated provider for the rental properties list
class PaginatedRentalNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final Ref ref;
  PaginatedRentalNotifier(this.ref) : super(const AsyncValue.loading()) {
    fetchInitial();
  }

  final List<DocumentSnapshot?> _pageCursors = [null];
  int _currentPage = 0;
  final int _pageSize = 50;
  int _totalCount = 0;
  int _filteredCount = 0;
  int _unverifiedCount = 0;

  Future<void> fetchInitial() async {
    _currentPage = 0;
    _pageCursors.clear();
    _pageCursors.add(null);

    try {
      final searchQuery = ref.read(rentalSearchQueryProvider);
      final selectedCity = ref.read(rentalSelectedCityProvider);
      final unverifiedOnly = ref.read(rentalUnverifiedOnlyProvider);
      final todayOnly = ref.read(rentalTodayOnlyProvider);

      Query query = FirebaseFirestore.instance.collection('rental_properties');

      if (searchQuery.isNotEmpty) {
        query = query.where('propertyName', isGreaterThanOrEqualTo: searchQuery)
                     .where('propertyName', isLessThanOrEqualTo: '$searchQuery\uf8ff');
      } else if (selectedCity != null) {
        query = query.where('city', isEqualTo: selectedCity);
      }

      if (unverifiedOnly) {
        query = query.where('isPropertyVerified', isEqualTo: false);
      }

      if (todayOnly) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        query = query.where('createdAt', isGreaterThanOrEqualTo: todayStart);
      }

      final countSnapshot = await query.count().get();
      _filteredCount = countSnapshot.count ?? 0;

      if (searchQuery.isEmpty && selectedCity == null && !unverifiedOnly && !todayOnly) {
        _totalCount = _filteredCount;
      }
    } catch (_) {}

    await fetchPage(0);
  }

  Future<void> fetchPage(int pageIndex) async {
    state = const AsyncValue.loading();
    try {
      final searchQuery = ref.read(rentalSearchQueryProvider);
      final selectedCity = ref.read(rentalSelectedCityProvider);
      final unverifiedOnly = ref.read(rentalUnverifiedOnlyProvider);
      final todayOnly = ref.read(rentalTodayOnlyProvider);

      Query query = FirebaseFirestore.instance.collection('rental_properties');

      if (searchQuery.isNotEmpty) {
        query = query.where('propertyName', isGreaterThanOrEqualTo: searchQuery)
                     .where('propertyName', isLessThanOrEqualTo: '$searchQuery\uf8ff');
      } else if (selectedCity != null) {
        query = query.where('city', isEqualTo: selectedCity);
      }

      if (unverifiedOnly) {
        query = query.where('isPropertyVerified', isEqualTo: false);
      }

      if (todayOnly) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        query = query.where('createdAt', isGreaterThanOrEqualTo: todayStart);
      }

      // Only apply ordering if no filters are active to avoid index errors
      if (searchQuery.isEmpty && selectedCity == null && !unverifiedOnly && !todayOnly) {
        query = query.orderBy('createdAt', descending: true);
      }

      if (pageIndex < _pageCursors.length && _pageCursors[pageIndex] != null) {
        query = query.startAfterDocument(_pageCursors[pageIndex]!);
      }

      final snapshot = await query.limit(_pageSize).get();
      final properties = snapshot.docs.map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)}).toList();

      if (snapshot.docs.isNotEmpty && snapshot.docs.length == _pageSize) {
        if (pageIndex + 1 == _pageCursors.length) {
          _pageCursors.add(snapshot.docs.last);
        }
      }

      _currentPage = pageIndex;
      state = AsyncValue.data(properties);
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

final paginatedRentalProvider = StateNotifierProvider<
    PaginatedRentalNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return PaginatedRentalNotifier(ref);
});

// Service Post State Providers
final serviceSearchQueryProvider = StateProvider<String>((ref) => '');
final serviceSelectedCategoryProvider = StateProvider<String?>((ref) => null);
final serviceTodayOnlyProvider = StateProvider<bool>((ref) => false);
final serviceStatusFilterProvider = StateProvider<String?>((ref) => null);

// Provider to gather a comprehensive list of categories from service posts
final serviceCategoriesProvider = FutureProvider<Set<String>>((ref) async {
  final snapshot = await FirebaseFirestore.instance.collection('service_posts').limit(500).get();
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
        query = query.where('userName', isGreaterThanOrEqualTo: searchQuery)
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
      final todaySnapshot = await FirebaseFirestore.instance.collection('service_posts')
          .where('timestamp', isGreaterThanOrEqualTo: todayStart).count().get();
      _todayCount = todaySnapshot.count ?? 0;

      if (searchQuery.isEmpty && selectedCategory == null && selectedStatus == null && !todayOnly) {
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
        query = query.where('userName', isGreaterThanOrEqualTo: searchQuery)
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
      if (searchQuery.isEmpty && selectedCategory == null && selectedStatus == null && !todayOnly) {
        query = query.orderBy('timestamp', descending: true);
      }

      if (pageIndex < _pageCursors.length && _pageCursors[pageIndex] != null) {
        query = query.startAfterDocument(_pageCursors[pageIndex]!);
      }

      final snapshot = await query.limit(_pageSize).get();
      final posts = snapshot.docs.map((doc) => {'id': doc.id, ...(doc.data() as Map<String, dynamic>)}).toList();

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
    PaginatedServicePostNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  return PaginatedServicePostNotifier(ref);
});

final collectionCountProvider =
    FutureProvider.family<int, String>((ref, collectionName) async {
  final snapshot = await FirebaseFirestore.instance
      .collection(collectionName)
      .count()
      .get();
  return snapshot.count ?? 0;
});

final collectionTodayCountProvider =
    FutureProvider.family<int, String>((ref, collectionName) async {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  
  // Try common timestamp field names
  final fields = ['createdAt', 'timestamp', 'date', 'updatedAt'];
  
  int totalCount = 0;
  
  // Since we don't know the exact field name and Firestore doesn't support OR for different fields easily without complex queries,
  // and we want to keep it simple, we will try to query by each field until we find one that works or just check all of them.
  // However, most collections in this app seem to use 'createdAt'.
  
  // For users, it's createdAt/updatedAt
  // For service_posts, let's assume createdAt
  
  // Actually, a better way is to just try 'createdAt' first as it's the standard.
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
        .where('createdAt', isGreaterThanOrEqualTo: todayStart)
        .count()
        .get();
    totalCount = snapshot.count ?? 0;
    
    // If count is 0, it might be because the field name is different or actually 0.
    // To be safe, if 'createdAt' returns 0, we could try 'timestamp'.
    if (totalCount == 0) {
      final snapshotAlt = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('timestamp', isGreaterThanOrEqualTo: todayStart)
          .count()
          .get();
      totalCount = snapshotAlt.count ?? 0;
    }

    if (totalCount == 0) {
      final snapshotAlt = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('date', isGreaterThanOrEqualTo: todayStart)
          .count()
          .get();
      totalCount = snapshotAlt.count ?? 0;
    }

    if (totalCount == 0) {
      final snapshotAlt = await FirebaseFirestore.instance
          .collection(collectionName)
          .where('updatedAt', isGreaterThanOrEqualTo: todayStart)
          .count()
          .get();
      totalCount = snapshotAlt.count ?? 0;
    }
  } catch (e) {
    // If 'createdAt' query fails (e.g. no index or field doesn't exist in a way that breaks), return 0
    return 0;
  }
  
  return totalCount;
});
