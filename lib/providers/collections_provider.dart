import 'dart:io';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/providers/admin_providers.dart';

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
    if ((pin >= 560001 && pin <= 560111) || (pin >= 562000 && pin <= 562999))
      return 'Bangalore';
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
  final snapshot =
      await FirebaseFirestore.instance.collection('users').limit(1000).get();
  final Set<String> cities = {};

  String normalizeCityName(String name) {
    final trimmed = name.trim().toLowerCase();
    if (trimmed == 'vijayawada') return 'Vijayawada';
    if (trimmed == 'hyderabad') return 'Hyderabad';
    if (trimmed == 'bheemavaram') return 'Bheemavaram';
    if (trimmed == 'bangalore' || trimmed == 'bengaluru') return 'Bangalore';
    if (trimmed == 'tirupathi' || trimmed == 'tirupati') return 'Tirupathi';
    if (trimmed == 'guntur') return 'Guntur';
    if (trimmed == 'machilipatnam') return 'Machilipatnam';

    if (trimmed.isEmpty) return '';
    return trimmed.split(' ').map((word) {
      if (word.isEmpty) return '';
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');
  }

  for (var doc in snapshot.docs) {
    final data = doc.data();
    final city = (data['City'] ?? data['city'])?.toString();
    if (city != null && city.trim().isNotEmpty) {
      cities.add(normalizeCityName(city));
    }

    // Also extract from address to populate the dropdown
    final address = data['businessaddress']?.toString() ?? '';
    if (address.contains('Machilipatnam')) cities.add('Machilipatnam');
    if (address.contains('Vijayawada')) cities.add('Vijayawada');
    if (address.contains('Hyderabad')) cities.add('Hyderabad');
    if (address.contains('Bangalore') || address.contains('Bengaluru')) cities.add('Bangalore');
    if (address.contains('Tirupathi') || address.contains('Tirupati')) cities.add('Tirupathi');
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

  Query _applyFilters(Query query) {
    final searchQuery = ref.read(userSearchQueryProvider).trim();
    final selectedCity = ref.read(userSelectedCityProvider);
    final verifiedOnly = ref.read(userVerifiedOnlyProvider);
    final dateFilter = ref.read(userDateFilterProvider);

    if (searchQuery.isNotEmpty) {
      if (verifiedOnly) {
        query = query
            .where('businessaddress', isGreaterThanOrEqualTo: searchQuery)
            .where('businessaddress', isLessThanOrEqualTo: '$searchQuery\uf8ff');
      } else {
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

      if (verifiedOnly) {
        query = query.where('isverified', isEqualTo: true);
      }
      
      return query;
    }

    if (selectedCity != null) {
      query = query
          .where('City', isGreaterThanOrEqualTo: selectedCity)
          .where('City', isLessThanOrEqualTo: '$selectedCity\uf8ff');
    }

    if (verifiedOnly) {
      query = query.where('isverified', isEqualTo: true);
    }

    if (dateFilter != null) {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      if (dateFilter == 'today') {
        query = query.where('createdAt', isGreaterThanOrEqualTo: todayStart);
      } else if (dateFilter == 'yesterday') {
        final yesterdayStart = todayStart.subtract(const Duration(days: 1));
        query = query
            .where('createdAt', isGreaterThanOrEqualTo: yesterdayStart)
            .where('createdAt', isLessThan: todayStart);
      } else if (dateFilter == 'month') {
        final thirtyDaysAgoStart = todayStart.subtract(const Duration(days: 30));
        query = query.where('createdAt', isGreaterThanOrEqualTo: thirtyDaysAgoStart);
      }
    }

    return query;
  }

  Future<void> fetchInitial({bool forceRefresh = false}) async {
    _currentPage = 0;
    _pageCursors.clear();
    _pageCursors.add(null);
    _filteredCount = 0;
    _verifiedCount = 0;

    try {
      final searchQuery = ref.read(userSearchQueryProvider).trim();
      final selectedCity = ref.read(userSelectedCityProvider);
      final dateFilter = ref.read(userDateFilterProvider);

      Query query = FirebaseFirestore.instance.collection('users');
      query = _applyFilters(query);

      // Base filtered count
      var countSnapshot = await query.count().get();
      _filteredCount = countSnapshot.count ?? 0;

      // Fallback for lowercase 'city' field if needed
      if (_filteredCount == 0 && selectedCity != null && searchQuery.isEmpty) {
        final lowercaseCity = selectedCity.toLowerCase();
        query = FirebaseFirestore.instance
            .collection('users')
            .where('city', isGreaterThanOrEqualTo: lowercaseCity)
            .where('city', isLessThanOrEqualTo: '$lowercaseCity\uf8ff');
        if (dateFilter != null) {
          final now = DateTime.now();
          final todayStart = DateTime(now.year, now.month, now.day);
          if (dateFilter == 'today') {
            query = query.where('createdAt', isGreaterThanOrEqualTo: todayStart);
          } else if (dateFilter == 'yesterday') {
            final yesterdayStart = todayStart.subtract(const Duration(days: 1));
            query = query
                .where('createdAt', isGreaterThanOrEqualTo: yesterdayStart)
                .where('createdAt', isLessThan: todayStart);
          } else if (dateFilter == 'month') {
            query = query.where('createdAt', isGreaterThanOrEqualTo: todayStart.subtract(const Duration(days: 30)));
          }
        }
        countSnapshot = await query.count().get();
        _filteredCount = countSnapshot.count ?? 0;
      }

      // Service Provider count
      final verifiedSnapshot =
          await query.where('isverified', isEqualTo: true).count().get();
      _verifiedCount = verifiedSnapshot.count ?? 0;

      if (searchQuery.isEmpty && selectedCity == null && dateFilter == null) {
        _totalCount = _filteredCount;
      }
    } catch (_) {}

    await fetchPage(0);
  }

  Future<void> fetchPage(int pageIndex) async {
    state = const AsyncValue.loading();
    try {
      final searchQuery = ref.read(userSearchQueryProvider).trim();
      final selectedCity = ref.read(userSelectedCityProvider);
      final verifiedOnly = ref.read(userVerifiedOnlyProvider);
      final dateFilter = ref.read(userDateFilterProvider);

      Query query = FirebaseFirestore.instance.collection('users');
      query = _applyFilters(query);

      if (dateFilter != null) {
        query = query.orderBy('createdAt', descending: true);
      } else if (searchQuery.isEmpty && selectedCity == null && !verifiedOnly) {
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

  Future<void> _fetchWithLowercaseCity(
    int pageIndex,
    String selectedCity,
  ) async {
    try {
      final verifiedOnly = ref.read(userVerifiedOnlyProvider);
      final dateFilter = ref.read(userDateFilterProvider);
      final lowercaseCity = selectedCity.toLowerCase();
      
      Query query = FirebaseFirestore.instance
          .collection('users')
          .where('city', isGreaterThanOrEqualTo: lowercaseCity)
          .where('city', isLessThanOrEqualTo: '$lowercaseCity\uf8ff');
          
      if (verifiedOnly) {
        query = query.where('isverified', isEqualTo: true);
      }
      
      if (dateFilter != null) {
        final now = DateTime.now();
        final todayStart = DateTime(now.year, now.month, now.day);
        if (dateFilter == 'today') {
          query = query.where('createdAt', isGreaterThanOrEqualTo: todayStart);
        } else if (dateFilter == 'yesterday') {
          final yesterdayStart = todayStart.subtract(const Duration(days: 1));
          query = query
              .where('createdAt', isGreaterThanOrEqualTo: yesterdayStart)
              .where('createdAt', isLessThan: todayStart);
        } else if (dateFilter == 'month') {
          query = query.where('createdAt', isGreaterThanOrEqualTo: todayStart.subtract(const Duration(days: 30)));
        }
        query = query.orderBy('createdAt', descending: true);
      }
      
      if (pageIndex < _pageCursors.length && _pageCursors[pageIndex] != null) {
        query = query.startAtDocument(_pageCursors[pageIndex]!);
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
              
      if (pageIndex + 1 == _pageCursors.length &&
          snapshot.docs.length == _pageSize) {
        _pageCursors.add(snapshot.docs.last);
      }
      
      _currentPage = pageIndex;
      state = AsyncValue.data(users);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> _fetchWithoutOrdering(int pageIndex) async {
    try {
      final searchQuery = ref.read(userSearchQueryProvider).trim();
      final selectedCity = ref.read(userSelectedCityProvider);

      Query query = FirebaseFirestore.instance.collection('users');
      query = _applyFilters(query);

      if (pageIndex < _pageCursors.length && _pageCursors[pageIndex] != null) {
        query = query.startAtDocument(_pageCursors[pageIndex]!);
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
      state = AsyncValue.data(users);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void nextPage() {
    final count =
        ref.read(userVerifiedOnlyProvider) ? _verifiedCount : _filteredCount;
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
  PaginatedUserNotifier,
  AsyncValue<List<Map<String, dynamic>>>
>((ref) {
  return PaginatedUserNotifier(ref);
});

// Payments State Providers
final paymentSearchQueryProvider = StateProvider<String>((ref) => '');
final selectedPaymentAdminFilterProvider = StateProvider<String?>((ref) => null);

final adminsListProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final snapshot = await FirebaseFirestore.instance.collection('admin').get();
  return snapshot.docs.map((doc) => {
    'id': doc.id,
    ...doc.data(),
  }).toList();
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

final paymentSalesStatsProvider = FutureProvider.family<PaymentSalesStats, String?>((ref, filterAdminId) async {
  final snapshot = await FirebaseFirestore.instance
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

      if (paymentDate.isAfter(todayStart) || paymentDate.isAtSameMomentAs(todayStart)) {
        today += amount;
      } else if ((paymentDate.isAfter(yesterdayStart) || paymentDate.isAtSameMomentAs(yesterdayStart)) &&
          paymentDate.isBefore(todayStart)) {
        yesterday += amount;
      }

      if (paymentDate.isAfter(thirtyDaysAgo) || paymentDate.isAtSameMomentAs(thirtyDaysAgo)) {
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
    query = query.where('isuser', isEqualTo: false).where('paymentLinkSend', isEqualTo: true);

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
      } else if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
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

// Provider to gather a comprehensive list of cities from rental properties
final rentalCitiesProvider = FutureProvider<Set<String>>((ref) async {
  final snapshot =
      await FirebaseFirestore.instance
          .collection('rental_properties')
          .limit(500)
          .get();
  final Set<String> cities = {};
  for (var doc in snapshot.docs) {
    final data = doc.data();
    final city = (data['city'] ?? data['City'])?.toString();
    if (city != null && city.isNotEmpty) cities.add(city);
  }
  return cities;
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
  }

  void _initStream() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('rental_properties')
        .orderBy('createdAt', descending: true)
        .limit(2000)
        .snapshots()
        .listen((snapshot) {
          _allProperties = snapshot.docs.map((doc) => {
            'id': doc.id,
            ...doc.data(),
          }).toList();
          _applyFiltersAndNotify();
        }, onError: (err, stack) {
          state = AsyncValue.error(err, stack);
        });
  }

  void _applyFiltersAndNotify() {
    final searchQuery = ref.read(rentalSearchQueryProvider).trim().toLowerCase();
    final selectedCity = ref.read(rentalSelectedCityProvider);
    final filterType = ref.read(rentalTypeFilterProvider);
    final timeFilter = ref.read(rentalTimeFilterProvider);

    _totalCount = _allProperties.length;

    List<Map<String, dynamic>> temp = List.from(_allProperties);

    // 1. Filter by City
    if (selectedCity != null) {
      temp = temp.where((p) {
        final city = (p['city'] ?? p['City'])?.toString().toLowerCase();
        return city == selectedCity.toLowerCase();
      }).toList();
    }

    // 2. Filter by Verification / Premium Type
    if (filterType == 'Verified') {
      temp = temp.where((p) => p['isPropertyVerified'] == true).toList();
    } else if (filterType == 'Unverified') {
      temp = temp.where((p) => p['isPropertyVerified'] != true).toList();
    } else if (filterType == 'Premium') {
      temp = temp.where((p) {
        final plan = p['ownerPlan']?.toString().toLowerCase() ?? '';
        final isBoosted = p['isBoosted'] == true;
        final isPremium = p['isPremium'] == true;
        return plan.contains('premium') || plan == 'paid' || plan == '599' || isBoosted || isPremium;
      }).toList();
    }

    // 3. Filter by Time
    if (timeFilter != 'All Time') {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
      final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));

      temp = temp.where((p) {
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
          return date.isAfter(todayStart) || date.isAtSameMomentAs(todayStart);
        } else if (timeFilter == 'Yesterday') {
          return (date.isAfter(yesterdayStart) || date.isAtSameMomentAs(yesterdayStart)) && date.isBefore(todayStart);
        } else if (timeFilter == 'Last 7 Days') {
          return date.isAfter(sevenDaysAgo) || date.isAtSameMomentAs(sevenDaysAgo);
        } else if (timeFilter == 'Last 30 Days') {
          return date.isAfter(thirtyDaysAgo) || date.isAtSameMomentAs(thirtyDaysAgo);
        }
        return true;
      }).toList();
    }

    // 4. Filter by Search Query
    if (searchQuery.isNotEmpty) {
      temp = temp.where((p) {
        final name = (p['propertyName'] ?? p['title'] ?? p['name'])?.toString().toLowerCase() ?? '';
        final owner = p['ownerName']?.toString().toLowerCase() ?? '';
        final city = (p['city'] ?? p['City'])?.toString().toLowerCase() ?? '';
        final location = (p['location'] ?? p['address'])?.toString().toLowerCase() ?? '';
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

    _filteredProperties = temp;
    _filteredCount = temp.length;

    // Paginate
    final int start = _currentPage * _pageSize;
    if (start >= _filteredCount && _currentPage > 0) {
      _currentPage = (_filteredCount - 1) ~/ _pageSize;
    }
    if (_currentPage < 0) _currentPage = 0;

    final paginatedList = _filteredProperties.skip(_currentPage * _pageSize).take(_pageSize).toList();
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
  debugPrint('Workspace Log: $message');
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
            debugPrint(
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
            debugPrint(
              'Detected date field "$field" of type "$type" (sample: "$val") for collection "$collectionName"',
            );
            _logToWorkspace(
              'Detected date field "$field" of type "$type" (sample: "$val") for collection "$collectionName"',
            );
            return CollectionDateFieldInfo(fieldName: field, fieldType: type);
          } else if (val is int) {
            if (val > 100000000000) {
              debugPrint(
                'Detected date field "$field" of type "int_ms" for collection "$collectionName"',
              );
              return CollectionDateFieldInfo(
                fieldName: field,
                fieldType: 'int_ms',
              );
            } else {
              debugPrint(
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
          debugPrint(
            'Fallback detected date field "${entry.key}" of type "Timestamp" for collection "$collectionName"',
          );
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
    debugPrint('Error detecting date field for $collectionName: $e');
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
  final dateFieldInfo = await ref.watch(
    collectionDateFieldInfoProvider(collectionName).future,
  );

  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);

  if (dateFieldInfo != null) {
    final fieldName = dateFieldInfo.fieldName;
    final fieldType = dateFieldInfo.fieldType;
    final todayVal = _convertDateTimeToQueryValue(todayStart, fieldType);

    final snapshot = await FirebaseFirestore.instance
        .collection(collectionName)
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
      final todaySnap =
          await FirebaseFirestore.instance
              .collection(collectionName)
              .where(fieldName, isGreaterThanOrEqualTo: todayVal)
              .count()
              .get();
      final todayCount = todaySnap.count ?? 0;

      final yesterdaySnap =
          await FirebaseFirestore.instance
              .collection(collectionName)
              .where(fieldName, isGreaterThanOrEqualTo: yesterdayVal)
              .where(fieldName, isLessThan: todayVal)
              .count()
              .get();
      final yesterdayCount = yesterdaySnap.count ?? 0;

      final sevenDaysSnap =
          await FirebaseFirestore.instance
              .collection(collectionName)
              .where(fieldName, isGreaterThanOrEqualTo: sevenDaysAgoVal)
              .count()
              .get();
      final sevenDaysCount = sevenDaysSnap.count ?? 0;

      final thirtyDaysSnap =
          await FirebaseFirestore.instance
              .collection(collectionName)
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
