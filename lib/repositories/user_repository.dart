import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/page_result.dart';

import 'package:skazo_admin/models/service_provider_overview_model.dart';
import 'package:skazo_admin/models/user_filters.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/utils/city_resolver.dart';
import 'package:skazo_admin/utils/property_pincodes_cache.dart';
import 'package:skazo_admin/utils/time_filter.dart';

const userPageSize = 100;
const _firestoreTimeout = Duration(seconds: 120);
const _maxRetries = 3;
const _customerIsUserValues = [true, 1, '1', 'true'];
const _serviceProviderIsUserValues = [false, 0, '0', 'false'];
const _maxCityFilterScanBatchSize = 300;
const _cityKeyField = 'cityKey';

/// Dashboard aggregate counts — no document downloads.
///
class PayPerLeadPageResult {
  final List<UserModel> items;
  final DocumentSnapshot<Map<String, dynamic>>? lastDocument;
  final bool hasMore;

  const PayPerLeadPageResult({
    required this.items,
    required this.lastDocument,
    required this.hasMore,
  });
}

class UserStats {
  final int total;
  final int verified;
  final int unverified;
  final int today;

  const UserStats({
    required this.total,
    required this.verified,
    required this.unverified,
    required this.today,
  });
}

enum UserSearchMode { none, phone, uid, usernamePrefix, businessNamePrefix }

class UserSearchParams {
  final UserSearchMode mode;
  final String rawQuery;
  final int? phone;
  final List<int>? phoneVariants;

  const UserSearchParams({
    required this.mode,
    required this.rawQuery,
    this.phone,
    this.phoneVariants,
  });

  factory UserSearchParams.fromQuery(String query) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return const UserSearchParams(mode: UserSearchMode.none, rawQuery: '');
    }

    final phoneNum = int.tryParse(trimmed);
    if (phoneNum != null) {
      if (trimmed.startsWith('91') && trimmed.length > 10) {
        return UserSearchParams(
          mode: UserSearchMode.phone,
          rawQuery: trimmed,
          phone: phoneNum,
        );
      }
      final with91 = int.tryParse('91$trimmed');
      return UserSearchParams(
        mode: UserSearchMode.phone,
        rawQuery: trimmed,
        phone: phoneNum,
        phoneVariants: with91 != null ? [phoneNum, with91] : [phoneNum],
      );
    }

    if (trimmed.length >= 20) {
      return UserSearchParams(mode: UserSearchMode.uid, rawQuery: trimmed);
    }

    return UserSearchParams(
      mode: UserSearchMode.businessNamePrefix,
      rawQuery: trimmed,
    );
  }
}

/// Firestore data access for the users collection.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  bool? _supportsDirectCityKeyQueriesCache;
  Future<bool>? _supportsDirectCityKeyQueriesFuture;

  CollectionReference<Map<String, dynamic>> get _users =>
      _firestore.collection('users');

  Future<T> _withRetry<T>(Future<T> Function() action) async {
    Object? lastError;
    StackTrace? lastStack;
    for (var attempt = 0; attempt <= _maxRetries; attempt++) {
      try {
        return await action().timeout(_firestoreTimeout);
      } catch (e, stack) {
        lastError = e;
        lastStack = stack;
        debugPrint('UserRepository retry $attempt: $e');
        if (attempt < _maxRetries) {
          await Future<void>.delayed(
            Duration(milliseconds: 300 * (attempt + 1)),
          );
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack ?? StackTrace.current);
  }

  Future<PageResult<UserModel>> fetchUsers({
    required UserFilters filters,
    String searchQuery = '',
    List<String> assignedCities = const [],
    Map<String, List<String>> pincodesMap = const {},
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = userPageSize,
  }) async {
    final cityFilter = filters.city?.trim();
    if (_shouldUseDerivedCityFiltering(cityFilter, assignedCities)) {
      final selectedCity = cityFilter;
      final filtersWithoutCity = filters.copyWith(clearCity: true);
      final search = UserSearchParams.fromQuery(searchQuery);
      final effectiveCity =
          selectedCity ??
          (assignedCities.length == 1 ? assignedCities.first : null);

      if (effectiveCity != null) {
        final cityKeyResult = await _tryFetchUsersByCityKey(
          filters: filtersWithoutCity,
          search: search,
          selectedCity: effectiveCity,
          startAfter: startAfter,
          limit: limit,
        );
        if (cityKeyResult != null) {
          return cityKeyResult;
        }
      }

      final effectivePincodesMap = await _resolvePincodesMap(pincodesMap);

      return _fetchCityFilteredPage(
        selectedCity: selectedCity,
        assignedCities: assignedCities,
        pincodesMap: effectivePincodesMap,
        startAfter: startAfter,
        limit: limit,
        queryBuilder:
            () => _buildUsersQuery(filters: filtersWithoutCity, search: search),
      );
    }

    return _withRetry(() async {
      final search = UserSearchParams.fromQuery(searchQuery);
      Query<Map<String, dynamic>> query = _buildUsersQuery(
        filters: filters,
        search: search,
      );

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.limit(limit).get();
      final items = snapshot.docs.map(UserModel.fromFirestore).toList();
      final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;

      return PageResult(
        items: items,
        lastDocument: lastDoc,
        hasMore: snapshot.docs.length == limit,
      );
    });
  }

  Future<int> countUsers({
    required UserFilters filters,
    String searchQuery = '',
    List<String> assignedCities = const [],
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    final cityFilter = filters.city?.trim();
    if (_shouldUseDerivedCityFiltering(cityFilter, assignedCities)) {
      final selectedCity = cityFilter;
      final effectiveCity =
          selectedCity ??
          (assignedCities.length == 1 ? assignedCities.first : null);

      if (effectiveCity != null) {
        final cityKeyCount = await _tryCountUsersByCityKey(
          filters: filters.copyWith(clearCity: true),
          search: UserSearchParams.fromQuery(searchQuery),
          selectedCity: effectiveCity,
        );
        if (cityKeyCount != null) {
          return cityKeyCount;
        }
      }

      final effectivePincodesMap = await _resolvePincodesMap(pincodesMap);

      return _countCityFilteredUsers(
        selectedCity: cityFilter,
        assignedCities: assignedCities,
        pincodesMap: effectivePincodesMap,
        queryBuilder:
            () => _buildUsersQuery(
              filters: filters.copyWith(clearCity: true),
              search: UserSearchParams.fromQuery(searchQuery),
            ),
      );
    }

    return _withRetry(() async {
      final search = UserSearchParams.fromQuery(searchQuery);
      final query = _buildUsersQuery(filters: filters, search: search);

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }

  Future<UserStats> fetchUserStats({
    List<String> assignedCities = const [],
  }) async {
    return _withRetry(() async {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayTs = Timestamp.fromDate(todayStart);

      if (assignedCities.isNotEmpty) {
        final cityKeys =
            assignedCities.map(_normalizeQueryableCityKey).toList();
        Query<Map<String, dynamic>> baseQuery = _users;
        if (cityKeys.length == 1) {
          baseQuery = baseQuery.where('cityKey', isEqualTo: cityKeys.first);
        } else if (cityKeys.length <= 30) {
          baseQuery = baseQuery.where('cityKey', whereIn: cityKeys);
        }

        final results = await Future.wait([
          baseQuery.count().get(),
          baseQuery.where('isverified', isEqualTo: true).count().get(),
          baseQuery.where('isverified', isEqualTo: false).count().get(),
          baseQuery
              .where('createdAt', isGreaterThanOrEqualTo: todayTs)
              .count()
              .get(),
        ]);

        return UserStats(
          total: results[0].count ?? 0,
          verified: results[1].count ?? 0,
          unverified: results[2].count ?? 0,
          today: results[3].count ?? 0,
        );
      }

      final results = await Future.wait([
        _users.count().get(),
        _users.where('isverified', isEqualTo: true).count().get(),
        _users.where('isverified', isEqualTo: false).count().get(),
        _users
            .where('createdAt', isGreaterThanOrEqualTo: todayTs)
            .count()
            .get(),
      ]);

      return UserStats(
        total: results[0].count ?? 0,
        verified: results[1].count ?? 0,
        unverified: results[2].count ?? 0,
        today: results[3].count ?? 0,
      );
    });
  }

  Future<int> countServiceProviders({
    UserFilters? filters,
    List<String> assignedCities = const [],
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    final baseFilters = (filters ?? const UserFilters()).copyWith(
      userType: 'Service Providers',
    );
    return countUsers(
      filters: baseFilters,
      assignedCities: assignedCities,
      pincodesMap: pincodesMap,
    );
  }

  Future<int> countUnverifiedPending({
    TimeFilterOption timeFilter = TimeFilterOption.all,
    String? city,
    String? category,
    List<String> assignedCities = const [],
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    final selectedCity = city?.trim();
    if (_shouldUseDerivedCityFiltering(selectedCity, assignedCities)) {
      final effectiveCity =
          selectedCity ??
          (assignedCities.length == 1 ? assignedCities.first : null);
      if (effectiveCity != null) {
        final directCount = await _tryCountUnverifiedByCityKey(
          timeFilter: timeFilter,
          selectedCity: effectiveCity,
          category: category,
        );
        if (directCount != null) {
          return directCount;
        }
      }

      final effectivePincodesMap = await _resolvePincodesMap(pincodesMap);
      return _countCityFilteredUsers(
        selectedCity: selectedCity,
        assignedCities: assignedCities,
        pincodesMap: effectivePincodesMap,
        queryBuilder:
            () => _buildUnverifiedBaseQuery(
              timeFilter: timeFilter,
              category: category,
            ),
      );
    }

    return _withRetry(() async {
      var query = _buildUnverifiedBaseQuery(
        timeFilter: timeFilter,
        category: category,
      );
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }

  Future<PageResult<UserModel>> fetchUnverifiedUsers({
    TimeFilterOption timeFilter = TimeFilterOption.all,
    String? city,
    String? category,
    List<String> assignedCities = const [],
    Map<String, List<String>> pincodesMap = const {},
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = userPageSize,
  }) async {
    final selectedCity = city?.trim();
    if (_shouldUseDerivedCityFiltering(selectedCity, assignedCities)) {
      final effectiveCity =
          selectedCity ??
          (assignedCities.length == 1 ? assignedCities.first : null);
      if (effectiveCity != null) {
        final cityKeyResult = await _tryFetchUnverifiedByCityKey(
          timeFilter: timeFilter,
          category: category,
          selectedCity: effectiveCity,
          startAfter: startAfter,
          limit: limit,
        );
        if (cityKeyResult != null) {
          return cityKeyResult;
        }
      }

      final effectivePincodesMap = await _resolvePincodesMap(pincodesMap);

      return _fetchCityFilteredPage(
        selectedCity: selectedCity,
        assignedCities: assignedCities,
        pincodesMap: effectivePincodesMap,
        startAfter: startAfter,
        limit: limit,
        queryBuilder:
            () => _buildUnverifiedBaseQuery(
              timeFilter: timeFilter,
              category: category,
            ),
      );
    }

    return _withRetry(() async {
      var query = _buildUnverifiedBaseQuery(
        timeFilter: timeFilter,
        category: category,
      );

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.limit(limit).get();
      final items = snapshot.docs.map(UserModel.fromFirestore).toList();
      final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;

      return PageResult(
        items: items,
        lastDocument: lastDoc,
        hasMore: snapshot.docs.length == limit,
      );
    });
  }

  Future<Map<String, int>> countUnverifiedByCategories({
    required List<String> categories,
    TimeFilterOption timeFilter = TimeFilterOption.all,
    String? city,
    List<String> assignedCities = const [],
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    final selectedCity = city?.trim();
    final effectiveCity =
        selectedCity ??
        (assignedCities.length == 1 ? assignedCities.first : null);
    final effectivePincodesMap = await _resolvePincodesMap(pincodesMap);
    final pincodeCityLookup = buildPincodeCityLookup(effectivePincodesMap);

    return _withRetry(() async {
      final counts = <String, int>{
        for (final category in categories) category: 0,
      };

      String? directCityKey;
      if (effectiveCity != null && await _supportsDirectCityKeyQueries()) {
        directCityKey = _normalizeQueryableCityKey(effectiveCity);
      }

      var query = _buildUnverifiedBaseQuery(
        timeFilter: timeFilter,
        category: null,
        directCityKey: directCityKey,
      );

      var snapshot = await query.get();
      if (snapshot.docs.isEmpty && directCityKey != null) {
        query = _buildUnverifiedBaseQuery(
          timeFilter: timeFilter,
          category: null,
        );
        snapshot = await query.get();
      }

      for (final doc in snapshot.docs) {
        final userData = doc.data();
        if (_shouldUseDerivedCityFiltering(selectedCity, assignedCities)) {
          if (!userMatchesAssignedCities(
            userData,
            selectedCity,
            assignedCities,
            effectivePincodesMap,
            pincodeCityLookup,
          )) {
            continue;
          }
        }

        final userCategories = userData['category'];
        if (userCategories is List) {
          for (final value in userCategories) {
            final catStr = value?.toString();
            if (catStr != null && counts.containsKey(catStr)) {
              counts[catStr] = (counts[catStr] ?? 0) + 1;
            }
          }
        } else if (userCategories is String &&
            counts.containsKey(userCategories)) {
          counts[userCategories] = (counts[userCategories] ?? 0) + 1;
        }
      }

      return counts;
    });
  }

  Future<void> verifyUser(String userId) async {
    await _withRetry(() {
      return _users.doc(userId).update({
        'isverified': true,
        'isactive': true,
        // 'isDeactivated': false,
        'isProviderTemperoryDeactivatedStatus': false,
      });
    });
  }

  Future<void> deactivateUser(String userId, {String? reason}) async {
    await _withRetry(() {
      final updateData = <String, dynamic>{
        'isactive': false,
        // 'isDeactivated': true,
        'isProviderTemperoryDeactivatedStatus': true,
        'deactivatedAt': FieldValue.serverTimestamp(),
        // 'updatedAt': FieldValue.serverTimestamp(),
      };
      if (reason != null && reason.trim().isNotEmpty) {
        updateData['deactivationReason'] = reason.trim();
      }
      return _users.doc(userId).update(updateData);
    });
  }

  Future<void> activateUser(String userId) async {
    await _withRetry(() {
      return _users.doc(userId).update({
        'isactive': true,
        // 'isDeactivated': false,
        'isProviderTemperoryDeactivatedStatus': false,
        // 'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<PageResult<UserModel>> fetchDeactivatedUsers({
    String searchQuery = '',
    String? selectedCity,
    String? dateFilter,
    DateTimeRange? customDateRange,
    String? statusFilter,
    List<String> assignedCities = const [],
    Map<String, List<String>> pincodesMap = const {},
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = userPageSize,
  }) async {
    final cityFilter = selectedCity?.trim();
    if (_shouldUseDerivedCityFiltering(cityFilter, assignedCities)) {
      final effectiveCity =
          cityFilter ??
          (assignedCities.length == 1 ? assignedCities.first : null);
      if (effectiveCity != null) {
        final directResult = await _tryFetchDeactivatedByCityKey(
          searchQuery: searchQuery,
          dateFilter: dateFilter,
          customDateRange: customDateRange,
          statusFilter: statusFilter,
          selectedCity: effectiveCity,
          startAfter: startAfter,
          limit: limit,
        );
        if (directResult != null) {
          return directResult;
        }
      }

      final effectivePincodesMap = await _resolvePincodesMap(pincodesMap);
      return _fetchCityFilteredPage(
        selectedCity: cityFilter,
        assignedCities: assignedCities,
        pincodesMap: effectivePincodesMap,
        startAfter: startAfter,
        limit: limit,
        queryBuilder:
            () => _buildDeactivatedQuery(
              searchQuery: searchQuery,
              dateFilter: dateFilter,
              customDateRange: customDateRange,
              statusFilter: statusFilter,
            ),
      );
    }

    return _withRetry(() async {
      var query = _buildDeactivatedQuery(
        searchQuery: searchQuery,
        dateFilter: dateFilter,
        customDateRange: customDateRange,
        statusFilter: statusFilter,
      );

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.limit(limit).get();
      final items = snapshot.docs.map(UserModel.fromFirestore).toList();
      final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;

      return PageResult(
        items: items,
        lastDocument: lastDoc,
        hasMore: snapshot.docs.length == limit,
      );
    });
  }

  Future<int> countDeactivatedUsers({
    String searchQuery = '',
    String? selectedCity,
    String? dateFilter,
    DateTimeRange? customDateRange,
    String? statusFilter,
    List<String> assignedCities = const [],
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    final cityFilter = selectedCity?.trim();
    if (_shouldUseDerivedCityFiltering(cityFilter, assignedCities)) {
      final effectiveCity =
          cityFilter ??
          (assignedCities.length == 1 ? assignedCities.first : null);
      if (effectiveCity != null) {
        final directCount = await _tryCountDeactivatedByCityKey(
          searchQuery: searchQuery,
          dateFilter: dateFilter,
          customDateRange: customDateRange,
          statusFilter: statusFilter,
          selectedCity: effectiveCity,
        );
        if (directCount != null) {
          return directCount;
        }
      }

      final effectivePincodesMap = await _resolvePincodesMap(pincodesMap);
      return _countCityFilteredUsers(
        selectedCity: cityFilter,
        assignedCities: assignedCities,
        pincodesMap: effectivePincodesMap,
        queryBuilder:
            () => _buildDeactivatedQuery(
              searchQuery: searchQuery,
              dateFilter: dateFilter,
              customDateRange: customDateRange,
              statusFilter: statusFilter,
            ),
      );
    }

    return _withRetry(() async {
      final query = _buildDeactivatedQuery(
        searchQuery: searchQuery,
        dateFilter: dateFilter,
        customDateRange: customDateRange,
        statusFilter: statusFilter,
      );
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }

  Query<Map<String, dynamic>> _applyDeactivatedDateFilter(
    Query<Map<String, dynamic>> query,
    String? dateFilter,
    DateTimeRange? customRange,
  ) {
    if (dateFilter == null || dateFilter == 'all' || dateFilter == 'All Time') {
      return query;
    }

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final yesterdayStart = todayStart.subtract(const Duration(days: 1));

    if (dateFilter == 'today' || dateFilter == 'Today') {
      return query.where(
        'deactivatedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
      );
    }

    if (dateFilter == 'yesterday' || dateFilter == 'Yesterday') {
      return query
          .where(
            'deactivatedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(yesterdayStart),
          )
          .where('deactivatedAt', isLessThan: Timestamp.fromDate(todayStart));
    }

    if (dateFilter == 'week' || dateFilter == 'Last 7 Days') {
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      return query.where(
        'deactivatedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo),
      );
    }

    if (dateFilter == 'month' || dateFilter == 'Last 30 Days') {
      final thirtyDaysAgo = now.subtract(const Duration(days: 30));
      return query.where(
        'deactivatedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo),
      );
    }

    if ((dateFilter == 'custom' || dateFilter == 'Custom Date Range') &&
        customRange != null) {
      final start = DateTime(
        customRange.start.year,
        customRange.start.month,
        customRange.start.day,
        0,
        0,
        0,
      );
      final end = DateTime(
        customRange.end.year,
        customRange.end.month,
        customRange.end.day,
        23,
        59,
        59,
        999,
      );
      return query
          .where(
            'deactivatedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          )
          .where('deactivatedAt', isLessThanOrEqualTo: Timestamp.fromDate(end));
    }

    return query;
  }

  Query<Map<String, dynamic>> _buildDeactivatedQuery({
    String? searchQuery,
    String? dateFilter,
    DateTimeRange? customDateRange,
    String? statusFilter,
    String? directCityKey,
  }) {
    Query<Map<String, dynamic>> query = _users;

    // Base condition: Strictly isProviderTemperoryDeactivatedStatus == true
    query = query.where(
      'isProviderTemperoryDeactivatedStatus',
      isEqualTo: true,
    );

    if (directCityKey != null && directCityKey.isNotEmpty) {
      query = query.where(_cityKeyField, isEqualTo: directCityKey);
    }

    query = _applyDeactivatedDateFilter(query, dateFilter, customDateRange);

    final search = UserSearchParams.fromQuery(searchQuery ?? '');
    switch (search.mode) {
      case UserSearchMode.none:
        return query.orderBy('deactivatedAt', descending: true);
      case UserSearchMode.phone:
        if (search.phoneVariants != null && search.phoneVariants!.length > 1) {
          return query
              .where('phone', whereIn: search.phoneVariants)
              .orderBy('deactivatedAt', descending: true);
        }
        return query
            .where('phone', isEqualTo: search.phone)
            .orderBy('deactivatedAt', descending: true);
      case UserSearchMode.uid:
        return query
            .where('uid', isEqualTo: search.rawQuery)
            .orderBy('deactivatedAt', descending: true);
      case UserSearchMode.usernamePrefix:
        final prefix = search.rawQuery;
        return query
            .where('username', isGreaterThanOrEqualTo: prefix)
            .where('username', isLessThanOrEqualTo: '$prefix\uf8ff')
            .orderBy('username')
            .orderBy('deactivatedAt', descending: true);
      case UserSearchMode.businessNamePrefix:
        final prefix = search.rawQuery;
        return query
            .where('businessname', isGreaterThanOrEqualTo: prefix)
            .where('businessname', isLessThanOrEqualTo: '$prefix\uf8ff')
            .orderBy('businessname')
            .orderBy('deactivatedAt', descending: true);
    }
  }

  Future<PageResult<UserModel>?> _tryFetchDeactivatedByCityKey({
    required String searchQuery,
    String? dateFilter,
    DateTimeRange? customDateRange,
    String? statusFilter,
    required String selectedCity,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    required int limit,
  }) async {
    if (!await _supportsDirectCityKeyQueries()) {
      return null;
    }

    return _withRetry(() async {
      var query = _buildDeactivatedQuery(
        searchQuery: searchQuery,
        dateFilter: dateFilter,
        customDateRange: customDateRange,
        statusFilter: statusFilter,
        directCityKey: _normalizeQueryableCityKey(selectedCity),
      );

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.limit(limit).get();
      final items = snapshot.docs.map(UserModel.fromFirestore).toList();
      return PageResult(
        items: items,
        lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
        hasMore: snapshot.docs.length == limit,
      );
    });
  }

  Future<int?> _tryCountDeactivatedByCityKey({
    required String searchQuery,
    String? dateFilter,
    DateTimeRange? customDateRange,
    String? statusFilter,
    required String selectedCity,
  }) async {
    if (!await _supportsDirectCityKeyQueries()) {
      return null;
    }

    return _withRetry(() async {
      final query = _buildDeactivatedQuery(
        searchQuery: searchQuery,
        dateFilter: dateFilter,
        customDateRange: customDateRange,
        statusFilter: statusFilter,
        directCityKey: _normalizeQueryableCityKey(selectedCity),
      );
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }

  Query<Map<String, dynamic>> _buildUsersQuery({
    required UserFilters filters,
    required UserSearchParams search,
    String? directCityKey,
  }) {
    var query = _applySharedFilters(_users, filters);
    query = _applyDateFilter(query, filters.timeFilter);
    final sortByCreatedAt = _shouldSortByCreatedAt(filters.timeFilter);
    query = _applyUserTypeFilter(
      query,
      filters.userType,
      useLegacyValues:
          search.mode != UserSearchMode.phone ||
          search.phoneVariants == null ||
          search.phoneVariants!.length <= 1,
    );
    if (directCityKey != null && directCityKey.isNotEmpty) {
      query = query.where(_cityKeyField, isEqualTo: directCityKey);
    }

    switch (search.mode) {
      case UserSearchMode.none:
        final businessNamePrefix = filters.businessNamePrefix?.trim();
        if (businessNamePrefix != null && businessNamePrefix.isNotEmpty) {
          final businessQuery = _applyBusinessNamePrefixFilter(
            query,
            businessNamePrefix,
          ).orderBy('businessname');
          return sortByCreatedAt
              ? businessQuery.orderBy('createdAt', descending: true)
              : businessQuery;
        }
        return sortByCreatedAt
            ? query.orderBy('createdAt', descending: true)
            : query;
      case UserSearchMode.phone:
        if (search.phoneVariants != null && search.phoneVariants!.length > 1) {
          final phoneQuery = query.where(
            'phone',
            whereIn: search.phoneVariants,
          );
          return sortByCreatedAt
              ? phoneQuery.orderBy('createdAt', descending: true)
              : phoneQuery;
        }
        final phoneQuery = query.where('phone', isEqualTo: search.phone);
        return sortByCreatedAt
            ? phoneQuery.orderBy('createdAt', descending: true)
            : phoneQuery;
      case UserSearchMode.uid:
        final uidQuery = query.where('uid', isEqualTo: search.rawQuery);
        return sortByCreatedAt
            ? uidQuery.orderBy('createdAt', descending: true)
            : uidQuery;
      case UserSearchMode.usernamePrefix:
        final prefix = search.rawQuery;
        final usernameQuery = query
            .where('username', isGreaterThanOrEqualTo: prefix)
            .where('username', isLessThanOrEqualTo: '$prefix\uf8ff')
            .orderBy('username');
        return sortByCreatedAt
            ? usernameQuery.orderBy('createdAt', descending: true)
            : usernameQuery;
      case UserSearchMode.businessNamePrefix:
        final prefix = search.rawQuery;
        final businessQuery = query
            .where('businessname', isGreaterThanOrEqualTo: prefix)
            .where('businessname', isLessThanOrEqualTo: '$prefix\uf8ff')
            .orderBy('businessname');
        return sortByCreatedAt
            ? businessQuery.orderBy('createdAt', descending: true)
            : businessQuery;
    }
  }

  Query<Map<String, dynamic>> _applySharedFilters(
    Query<Map<String, dynamic>> query,
    UserFilters filters,
  ) {
    if (filters.verifiedOnly == true) {
      query = query.where('isverified', isEqualTo: true);
    }

    if (filters.category != null) {
      query = query.where('category', arrayContains: filters.category);
    }

    if (filters.priority != null) {
      query = query.where('priority', isEqualTo: filters.priority);
    }

    if (filters.profileComplete != null) {
      query = query.where(
        'profileComplete',
        isEqualTo: filters.profileComplete,
      );
    }

    return query;
  }

  Query<Map<String, dynamic>> _applyUserTypeFilter(
    Query<Map<String, dynamic>> query,
    String userType, {
    required bool useLegacyValues,
  }) {
    if (userType == 'Customers') {
      return useLegacyValues
          ? query.where('isuser', whereIn: _customerIsUserValues)
          : query.where('isuser', isEqualTo: true);
    }

    if (userType == 'Service Providers') {
      return useLegacyValues
          ? query.where('isuser', whereIn: _serviceProviderIsUserValues)
          : query.where('isuser', isEqualTo: false);
    }

    return query;
  }

  Query<Map<String, dynamic>> _applyDateFilter(
    Query<Map<String, dynamic>> query,
    TimeFilterOption timeFilter,
  ) {
    final start = timeFilterQueryStart(timeFilter);
    final end = timeFilterQueryEndExclusive(timeFilter);

    if (start != null) {
      query = query.where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(start),
      );
    }

    if (end != null) {
      query = query.where('createdAt', isLessThan: Timestamp.fromDate(end));
    }

    return query;
  }

  Query<Map<String, dynamic>> _applyBusinessNamePrefixFilter(
    Query<Map<String, dynamic>> query,
    String? businessNamePrefix,
  ) {
    if (businessNamePrefix == null || businessNamePrefix.isEmpty) {
      return query;
    }

    return query
        .where('businessname', isGreaterThanOrEqualTo: businessNamePrefix)
        .where(
          'businessname',
          isLessThanOrEqualTo: '$businessNamePrefix\uf8ff',
        );
  }

  Future<PageResult<UserModel>> _fetchCityFilteredPage({
    required String? selectedCity,
    List<String> assignedCities = const [],
    required Map<String, List<String>> pincodesMap,
    required Query<Map<String, dynamic>> Function() queryBuilder,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = userPageSize,
  }) async {
    return _withRetry(() async {
      final startTime = DateTime.now();
      final matched = <UserModel>[];
      final pincodeCityLookup = buildPincodeCityLookup(pincodesMap);
      final queryBatchSize = _cityFilterQueryBatchSize(limit);
      DocumentSnapshot<Map<String, dynamic>>? cursor = startAfter;
      var hasMore = true;

      while (matched.length < limit && hasMore) {
        // Safety check to avoid overall timeout
        if (DateTime.now().difference(startTime) >
            _firestoreTimeout - const Duration(seconds: 10)) {
          break;
        }

        var query = queryBuilder();
        if (cursor != null) {
          query = query.startAfterDocument(cursor);
        }

        final snapshot = await query.limit(queryBatchSize).get();
        if (snapshot.docs.isEmpty) {
          hasMore = false;
          break;
        }

        var reachedLimit = false;
        for (final doc in snapshot.docs) {
          final userData = doc.data();
          cursor = doc;
          if (!userMatchesAssignedCities(
            userData,
            selectedCity,
            assignedCities,
            pincodesMap,
            pincodeCityLookup,
          )) {
            continue;
          }

          final user = UserModel.fromMap(doc.id, userData);
          matched.add(user);
          if (matched.length == limit) {
            reachedLimit = true;
            break;
          }
        }

        hasMore = reachedLimit || snapshot.docs.length == queryBatchSize;
        if (!reachedLimit && snapshot.docs.isNotEmpty) {
          cursor = snapshot.docs.last;
        }
      }

      return PageResult(items: matched, lastDocument: cursor, hasMore: hasMore);
    });
  }

  Future<int> _countCityFilteredUsers({
    required String? selectedCity,
    List<String> assignedCities = const [],
    required Map<String, List<String>> pincodesMap,
    required Query<Map<String, dynamic>> Function() queryBuilder,
  }) async {
    return _withRetry(() async {
      final startTime = DateTime.now();
      var total = 0;
      final pincodeCityLookup = buildPincodeCityLookup(pincodesMap);
      final queryBatchSize = _maxCityFilterScanBatchSize;
      DocumentSnapshot<Map<String, dynamic>>? cursor;
      var hasMore = true;

      while (hasMore) {
        // Safety check to avoid overall timeout
        if (DateTime.now().difference(startTime) >
            _firestoreTimeout - const Duration(seconds: 10)) {
          break;
        }

        var query = queryBuilder();
        if (cursor != null) {
          query = query.startAfterDocument(cursor);
        }

        final snapshot = await query.limit(queryBatchSize).get();
        if (snapshot.docs.isEmpty) {
          break;
        }

        for (final doc in snapshot.docs) {
          if (userMatchesAssignedCities(
            doc.data(),
            selectedCity,
            assignedCities,
            pincodesMap,
            pincodeCityLookup,
          )) {
            total++;
          }
        }

        cursor = snapshot.docs.last;
        hasMore = snapshot.docs.length == queryBatchSize;
      }

      return total;
    });
  }


  Query<Map<String, dynamic>> _buildUnverifiedBaseQuery({
    required TimeFilterOption timeFilter,
    String? category,
    String? directCityKey,
  }) {
    Query<Map<String, dynamic>> query = _users.where(
      'isverified',
      isEqualTo: false,
    );
    query = _applyUserTypeFilter(
      query,
      'Service Providers',
      useLegacyValues: true,
    );

    if (category != null) {
      query = query.where('category', arrayContains: category);
    }

    query = _applyDateFilter(query, timeFilter);
    if (directCityKey != null && directCityKey.isNotEmpty) {
      query = query.where(_cityKeyField, isEqualTo: directCityKey);
    }
    return _shouldSortByCreatedAt(timeFilter)
        ? query.orderBy('createdAt', descending: true)
        : query;
  }

  /// Attempts username-prefix search when business-name search returns empty.
  Future<PageResult<UserModel>> fetchUsersWithSearchFallback({
    required UserFilters filters,
    required String searchQuery,
    List<String> assignedCities = const [],
    Map<String, List<String>> pincodesMap = const {},
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = userPageSize,
  }) async {
    final primary = await fetchUsers(
      filters: filters,
      searchQuery: searchQuery,
      assignedCities: assignedCities,
      pincodesMap: pincodesMap,
      startAfter: startAfter,
      limit: limit,
    );

    if (primary.items.isNotEmpty ||
        startAfter != null ||
        UserSearchParams.fromQuery(searchQuery).mode !=
            UserSearchMode.businessNamePrefix) {
      return primary;
    }

    final usernameSearch = UserSearchParams(
      mode: UserSearchMode.usernamePrefix,
      rawQuery: searchQuery.trim(),
    );

    final cityFilter = filters.city?.trim();
    if (_shouldUseDerivedCityFiltering(cityFilter, assignedCities)) {
      final selectedCity = cityFilter;
      final effectiveCity =
          selectedCity ??
          (assignedCities.length == 1 ? assignedCities.first : null);
      if (effectiveCity != null) {
        final directResult = await _tryFetchUsersByCityKey(
          filters: filters.copyWith(clearCity: true),
          search: usernameSearch,
          selectedCity: effectiveCity,
          startAfter: startAfter,
          limit: limit,
        );
        if (directResult != null) {
          return directResult;
        }
      }

      final effectivePincodesMap = await _resolvePincodesMap(pincodesMap);

      return _fetchCityFilteredPage(
        selectedCity: selectedCity,
        assignedCities: assignedCities,
        pincodesMap: effectivePincodesMap,
        startAfter: startAfter,
        limit: limit,
        queryBuilder:
            () => _buildUsersQuery(
              filters: filters.copyWith(clearCity: true),
              search: usernameSearch,
            ),
      );
    }

    return _withRetry(() async {
      var query = _buildUsersQuery(filters: filters, search: usernameSearch);
      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }
      final snapshot = await query.limit(limit).get();
      final items = snapshot.docs.map(UserModel.fromFirestore).toList();
      return PageResult(
        items: items,
        lastDocument: snapshot.docs.isEmpty ? null : snapshot.docs.last,
        hasMore: snapshot.docs.length == limit,
      );
    });
  }

  bool _shouldUseDerivedCityFiltering(
    String? selectedCity, [
    List<String> assignedCities = const [],
  ]) {
    return (selectedCity != null && selectedCity.isNotEmpty) ||
        assignedCities.isNotEmpty;
  }

  Future<Map<String, List<String>>> _resolvePincodesMap(
    Map<String, List<String>> pincodesMap,
  ) async {
    if (pincodesMap.isNotEmpty) {
      return pincodesMap;
    }
    return loadPropertyPincodes();
  }

  String _normalizeQueryableCityKey(String city) {
    return city.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<bool> _supportsDirectCityKeyQueries() async {
    final cached = _supportsDirectCityKeyQueriesCache;
    if (cached != null) {
      return cached;
    }

    final existingFuture = _supportsDirectCityKeyQueriesFuture;
    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _withRetry(() async {
      final snapshot =
          await _users
              .where(_cityKeyField, isGreaterThanOrEqualTo: '')
              .limit(1)
              .get();
      return snapshot.docs.isNotEmpty;
    });
    _supportsDirectCityKeyQueriesFuture = future;

    try {
      final supported = await future;
      _supportsDirectCityKeyQueriesCache = supported;
      return supported;
    } catch (e) {
      debugPrint('UserRepository cityKey probe failed: $e');
      return false;
    } finally {
      if (identical(_supportsDirectCityKeyQueriesFuture, future)) {
        _supportsDirectCityKeyQueriesFuture = null;
      }
    }
  }

  Future<PageResult<UserModel>?> _tryFetchUsersByCityKey({
    required UserFilters filters,
    required UserSearchParams search,
    required String selectedCity,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    required int limit,
  }) async {
    if (!await _supportsDirectCityKeyQueries()) {
      return null;
    }

    return _withRetry(() async {
      var query = _buildUsersQuery(
        filters: filters,
        search: search,
        directCityKey: _normalizeQueryableCityKey(selectedCity),
      );

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.limit(limit).get();
      final items = snapshot.docs.map(UserModel.fromFirestore).toList();
      return PageResult(
        items: items,
        lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
        hasMore: snapshot.docs.length == limit,
      );
    });
  }

  Future<int?> _tryCountUsersByCityKey({
    required UserFilters filters,
    required UserSearchParams search,
    required String selectedCity,
  }) async {
    if (!await _supportsDirectCityKeyQueries()) {
      return null;
    }

    return _withRetry(() async {
      final query = _buildUsersQuery(
        filters: filters,
        search: search,
        directCityKey: _normalizeQueryableCityKey(selectedCity),
      );
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }

  Future<PageResult<UserModel>?> _tryFetchUnverifiedByCityKey({
    required TimeFilterOption timeFilter,
    required String selectedCity,
    String? category,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    required int limit,
  }) async {
    if (!await _supportsDirectCityKeyQueries()) {
      return null;
    }

    return _withRetry(() async {
      var query = _buildUnverifiedBaseQuery(
        timeFilter: timeFilter,
        category: category,
        directCityKey: _normalizeQueryableCityKey(selectedCity),
      );

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.limit(limit).get();
      final items = snapshot.docs.map(UserModel.fromFirestore).toList();
      return PageResult(
        items: items,
        lastDocument: snapshot.docs.isEmpty ? startAfter : snapshot.docs.last,
        hasMore: snapshot.docs.length == limit,
      );
    });
  }

  Future<int?> _tryCountUnverifiedByCityKey({
    required TimeFilterOption timeFilter,
    required String selectedCity,
    String? category,
  }) async {
    if (!await _supportsDirectCityKeyQueries()) {
      return null;
    }

    return _withRetry(() async {
      final query = _buildUnverifiedBaseQuery(
        timeFilter: timeFilter,
        category: category,
        directCityKey: _normalizeQueryableCityKey(selectedCity),
      );
      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }

  bool _shouldSortByCreatedAt(TimeFilterOption timeFilter) {
    return timeFilter != TimeFilterOption.all;
  }

  int _cityFilterQueryBatchSize(int requestedLimit) {
    const defaultScanBatch = 250;
    if (requestedLimit <= 0) return defaultScanBatch;
    final desiredBatchSize = requestedLimit * 15;
    if (desiredBatchSize < defaultScanBatch) {
      return defaultScanBatch;
    }
    if (desiredBatchSize > _maxCityFilterScanBatchSize) {
      return _maxCityFilterScanBatchSize;
    }
    return desiredBatchSize;
  }

  /// Allowed categories for the Pay Per Lead feature.
  /// Only providers whose `category` array contains at least one of these
  /// values qualify for Pay Per Lead listing.
  ///
  /// Uses exact stored values from Firestore / business_categories.dart.
  /// NOTE: 'Electricians' (plural), 'House cleaning' (lowercase c).
  static const List<String> _kPplAllowedCategories = [
    'Electricians',
    'Plumbers',
    'AC Repair',
    'Fridge Repair',
    'Washing Machine Repair',
    'Painters',
    'Car Travels',
    'Car Drivers',
    'House cleaning',
    'Wood Works',
    'Packers and Movers',
    'Bike Mechanic',
    'Car Mechanic',
  ];

  Query<Map<String, dynamic>> _buildPayPerLeadBaseQuery({
    String? selectedCity,
    DateTime? dateFrom,
    DateTime? dateTo,
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
    bool sortDescending = true,
    bool applyOrdering = true,
  }) {
    Query<Map<String, dynamic>> query = _users
        .where('isuser', isEqualTo: false)
        .where('payperLeadcharge', isGreaterThan: 0)
        .where('category', arrayContainsAny: _kPplAllowedCategories);

    // ------------------------------------------------------------
    // CITY / ADMIN AUTHORIZATION
    // ------------------------------------------------------------

    final city = selectedCity?.trim();

    final hasSpecificCity =
        city != null &&
        city.isNotEmpty &&
        city != 'All' &&
        city != 'All Cities';

    if (isSuperAdmin) {
      if (hasSpecificCity) {
        query = query.where(
          'cityKey',
          isEqualTo: _normalizeQueryableCityKey(city),
        );
      }
    } else {
      // Normal admin must NEVER see data outside assigned cities.
      if (assignedCities.isEmpty) {
        return query.where('cityKey', isEqualTo: '__UNAUTHORIZED__');
      }

      final normalizedAssigned =
          assignedCities
              .map(_normalizeQueryableCityKey)
              .where((value) => value.isNotEmpty)
              .toSet()
              .toList();

      if (normalizedAssigned.isEmpty) {
        return query.where('cityKey', isEqualTo: '__UNAUTHORIZED__');
      }

      if (hasSpecificCity) {
        final normalizedSelected = _normalizeQueryableCityKey(city);

        // If selected city is not assigned to this admin,
        // deliberately return zero results.
        if (!normalizedAssigned.contains(normalizedSelected)) {
          return query.where('cityKey', isEqualTo: '__UNAUTHORIZED__');
        }

        query = query.where('cityKey', isEqualTo: normalizedSelected);
      } else {
        if (normalizedAssigned.length == 1) {
          query = query.where('cityKey', isEqualTo: normalizedAssigned.first);
        } else if (normalizedAssigned.length <= 30) {
          query = query.where('cityKey', whereIn: normalizedAssigned);
        } else {
          // Fail closed.
          return query.where(
            'cityKey',
            isEqualTo: '__TOO_MANY_ASSIGNED_CITIES__',
          );
        }
      }
    }

    // ------------------------------------------------------------
    // OPTIONAL DATE FILTER
    // ------------------------------------------------------------

    final hasDateFrom = dateFrom != null;
    final hasDateTo = dateTo != null;

    if (hasDateFrom) {
      final fromIstMidnight = DateTime.utc(
        dateFrom.year,
        dateFrom.month,
        dateFrom.day,
      );

      final fromUtc = fromIstMidnight.subtract(
        const Duration(hours: 5, minutes: 30),
      );

      query = query.where(
        'lastpaymentpayperlead',
        isGreaterThanOrEqualTo: Timestamp.fromDate(fromUtc),
      );
    }

    if (hasDateTo) {
      final toIstNextMidnight = DateTime.utc(
        dateTo.year,
        dateTo.month,
        dateTo.day,
      ).add(const Duration(days: 1));

      final toExclusiveUtc = toIstNextMidnight.subtract(
        const Duration(hours: 5, minutes: 30),
      );

      query = query.where(
        'lastpaymentpayperlead',
        isLessThan: Timestamp.fromDate(toExclusiveUtc),
      );
    }

    // ------------------------------------------------------------
    // ORDERING
    // ------------------------------------------------------------

    if (applyOrdering) {
      if (hasDateFrom || hasDateTo) {
        query = query.orderBy(
          'lastpaymentpayperlead',
          descending: sortDescending,
        );
      } else {
        query = query.orderBy(
          'payperLeadcharge',
          descending: sortDescending,
        );
      }
    }

    return query;
  }

  Future<PageResult<UserModel>> fetchPayPerLeadProviders({
    String? selectedCity,
    DateTime? dateFrom,
    DateTime? dateTo,
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
    bool sortDescending = true,
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    return _withRetry(() async {
      Query<Map<String, dynamic>> query = _buildPayPerLeadBaseQuery(
        selectedCity: selectedCity,
        dateFrom: dateFrom,
        dateTo: dateTo,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
        sortDescending: sortDescending,
        applyOrdering: true,
      );

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.limit(limit).get();
      final items = snapshot.docs.map(UserModel.fromFirestore).toList();
      final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;

      return PageResult<UserModel>(
        items: items,
        lastDocument: lastDoc,
        hasMore: snapshot.docs.length == limit,
      );
    });
  }

  /// Fetches ALL matching Pay Per Lead providers in one query for in-memory
  /// aggregation and local pagination.
  /// Uses the EXACT same UserModel.fromFirestore conversion.
  Future<List<UserModel>> fetchAllPayPerLeadProviders({
    String? selectedCity,
    DateTime? dateFrom,
    DateTime? dateTo,
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
    bool sortDescending = true,
  }) async {
    return _withRetry(() async {
      final Query<Map<String, dynamic>> query = _buildPayPerLeadBaseQuery(
        selectedCity: selectedCity,
        dateFrom: dateFrom,
        dateTo: dateTo,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
        sortDescending: sortDescending,
        applyOrdering: true,
      );

      final snapshot = await query.get();
      return snapshot.docs.map(UserModel.fromFirestore).toList();
    });
  }

  /// Saves or updates the feedback for a provider on their users document.
  Future<void> savePayPerLeadFeedback({
    required String userId,
    required String feedback,
  }) async {
    await _withRetry(() {
      return _users.doc(userId).update({
        'payPerLeadFeedback': feedback.trim(),
        'payPerLeadFeedbackUpdatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  /// Count does not require ordering. Uses the same filter predicates as fetch
  /// but skips orderBy to avoid unnecessary composite index requirements.
  Future<int> countPayPerLeadProviders({
    String? selectedCity,
    DateTime? dateFrom,
    DateTime? dateTo,
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
  }) async {
    return _withRetry(() async {
      final query = _buildPayPerLeadBaseQuery(
        selectedCity: selectedCity,
        dateFrom: dateFrom,
        dateTo: dateTo,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
        applyOrdering: false,
      );

      final snapshot = await query.count().get();

      return snapshot.count ?? 0;
    });
  }

  /// Builds the base query for Star Service Providers.
  /// Strictly enforces: isuser == false and StarServiceprovider == '1'.
  Query<Map<String, dynamic>> _buildStarServiceProvidersQuery({
    String? selectedCity,
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
    String? category,
  }) {
    Query<Map<String, dynamic>> query = _users
        .where('isuser', isEqualTo: false)
        .where('StarServiceprovider', isEqualTo: '1');

    if (category != null && category.trim().isNotEmpty) {
      query = query.where('category', arrayContains: category.trim());
    }

    // City filter & Admin permission boundary
    final city = selectedCity?.trim();
    final hasSpecificCity =
        city != null &&
        city.isNotEmpty &&
        city != 'All' &&
        city != 'All Cities';

    if (isSuperAdmin) {
      if (hasSpecificCity) {
        query = query.where(
          'cityKey',
          isEqualTo: _normalizeQueryableCityKey(city),
        );
      }
    } else {
      if (assignedCities.isEmpty) {
        return query.where('cityKey', isEqualTo: '__UNAUTHORIZED__');
      }

      final normalizedAssigned =
          assignedCities.map(_normalizeQueryableCityKey).toList();

      if (hasSpecificCity) {
        final normalizedSelected = _normalizeQueryableCityKey(city);
        if (normalizedAssigned.contains(normalizedSelected)) {
          query = query.where('cityKey', isEqualTo: normalizedSelected);
        } else {
          query = query.where('cityKey', isEqualTo: normalizedAssigned.first);
        }
      } else {
        if (normalizedAssigned.length == 1) {
          query = query.where('cityKey', isEqualTo: normalizedAssigned.first);
        } else if (normalizedAssigned.length <= 30) {
          query = query.where('cityKey', whereIn: normalizedAssigned);
        }
      }
    }

    return query;
  }

  /// Fetches lightweight aggregated category statistics for Star Service Providers in the selected city.
  /// Does NOT return raw provider documents, minimizing memory usage and UI rebuild weight.
  Future<ServiceProvidersOverviewData> fetchServiceProvidersOverviewStats({
    String? selectedCity,
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
    Map<String, List<String>> pincodesMap = const {},
    List<String>? zonePincodes,
  }) async {
    return _withRetry(() async {
      final effectivePincodesMap = await _resolvePincodesMap(pincodesMap);
      final pincodeCityLookup = buildPincodeCityLookup(effectivePincodesMap);

      // Normalize zone pincodes for O(1) lookup.
      final normalizedZonePins =
          (zonePincodes != null && zonePincodes.isNotEmpty)
              ? zonePincodes.map((p) => p.trim()).toSet()
              : null;

      final query = _buildStarServiceProvidersQuery(
        selectedCity: selectedCity,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
      );

      final snapshot = await query.get();

      final categoryCountMap = <String, int>{};
      int totalUniqueProviders = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // City authorization check (derived pincode filtering).
        if (_shouldUseDerivedCityFiltering(selectedCity, assignedCities)) {
          if (!userMatchesAssignedCities(
            data,
            selectedCity,
            assignedCities,
            effectivePincodesMap,
            pincodeCityLookup,
          )) {
            continue;
          }
        }

        // Zone pincode filter — applied when a specific zone is selected.
        // When null (All Zones), all city-matching providers are included.
        if (normalizedZonePins != null) {
          final userPin = extractUserPincode(data);
          if (userPin == null || !normalizedZonePins.contains(userPin)) {
            continue;
          }
        }

        totalUniqueProviders++;

        // Always group by category regardless of city.
        final rawCategories = data['category'];
        final providerCategories = <String>{};

        if (rawCategories is List) {
          for (final item in rawCategories) {
            final catStr = item?.toString().trim();
            if (catStr != null && catStr.isNotEmpty) {
              providerCategories.add(catStr);
            }
          }
        } else if (rawCategories is String &&
            rawCategories.trim().isNotEmpty) {
          providerCategories.add(rawCategories.trim());
        }

        if (providerCategories.isEmpty) {
          providerCategories.add('Uncategorized');
        }

        for (final cat in providerCategories) {
          categoryCountMap[cat] = (categoryCountMap[cat] ?? 0) + 1;
        }
      }

      final categoryList =
          categoryCountMap.entries.map((entry) {
            return ServiceProviderCategoryStats(
              categoryName: entry.key,
              totalCount: entry.value,
            );
          }).toList();

      categoryList.sort((a, b) {
        final cmp = b.totalCount.compareTo(a.totalCount);
        if (cmp != 0) return cmp;
        return a.categoryName.compareTo(b.categoryName);
      });

      return ServiceProvidersOverviewData(
        selectedCity: selectedCity,
        selectedDate: DateTime.now(),
        totalProviders: totalUniqueProviders,
        totalCategories: categoryList.length,
        categories: categoryList,
        areaGroups: null, // Zone is a pre-filter; result grouping is always category-wise.
      );
    });
  }

  /// Fetches a server-side paginated list of Star Service Providers for a specific category.
  Future<PageResult<UserModel>> fetchCategoryServiceProvidersPage({
    required String category,
    List<String>? areaPincodes,
    String? selectedCity,
    String searchQuery = '',
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
    Map<String, List<String>> pincodesMap = const {},
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = 20,
  }) async {
    return _withRetry(() async {
      final effectivePincodesMap = await _resolvePincodesMap(pincodesMap);
      final pincodeCityLookup = buildPincodeCityLookup(effectivePincodesMap);
      final normalizedAreaPins =
          (areaPincodes != null && areaPincodes.isNotEmpty)
              ? areaPincodes.map((p) => p.trim()).toSet()
              : null;

      final isCategoryFilter =
          category.trim().isNotEmpty &&
          category != 'All' &&
          category != 'Uncategorized';

      Query<Map<String, dynamic>> query = _buildStarServiceProvidersQuery(
        selectedCity: selectedCity,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
        category: isCategoryFilter ? category : null,
      );

      final search = UserSearchParams.fromQuery(searchQuery);
      switch (search.mode) {
        case UserSearchMode.none:
          query = query.orderBy('createdAt', descending: true);
          break;
        case UserSearchMode.phone:
          if (search.phoneVariants != null &&
              search.phoneVariants!.length > 1) {
            query = query
                .where('phone', whereIn: search.phoneVariants)
                .orderBy('createdAt', descending: true);
          } else {
            query = query
                .where('phone', isEqualTo: search.phone)
                .orderBy('createdAt', descending: true);
          }
          break;
        case UserSearchMode.uid:
          query = query
              .where('uid', isEqualTo: search.rawQuery)
              .orderBy('createdAt', descending: true);
          break;
        case UserSearchMode.usernamePrefix:
          final prefix = search.rawQuery;
          query = query
              .where('username', isGreaterThanOrEqualTo: prefix)
              .where('username', isLessThanOrEqualTo: '$prefix\uf8ff')
              .orderBy('username')
              .orderBy('createdAt', descending: true);
          break;
        case UserSearchMode.businessNamePrefix:
          final prefix = search.rawQuery;
          query = query
              .where('businessname', isGreaterThanOrEqualTo: prefix)
              .where('businessname', isLessThanOrEqualTo: '$prefix\uf8ff')
              .orderBy('businessname')
              .orderBy('createdAt', descending: true);
          break;
      }

      // If filtering by area pincodes, scan in batches until 'limit' matched items are found
      if (normalizedAreaPins != null && normalizedAreaPins.isNotEmpty) {
        final matched = <UserModel>[];
        DocumentSnapshot<Map<String, dynamic>>? cursor = startAfter;
        var hasMore = true;
        const batchSize = 100;

        while (matched.length < limit && hasMore) {
          var pQuery = query;
          if (cursor != null) {
            pQuery = pQuery.startAfterDocument(cursor);
          }

          final snapshot = await pQuery.limit(batchSize).get();
          if (snapshot.docs.isEmpty) {
            hasMore = false;
            break;
          }

          var reachedLimit = false;
          for (final doc in snapshot.docs) {
            cursor = doc;
            final data = doc.data();

            if (_shouldUseDerivedCityFiltering(selectedCity, assignedCities)) {
              if (!userMatchesAssignedCities(
                data,
                selectedCity,
                assignedCities,
                effectivePincodesMap,
                pincodeCityLookup,
              )) {
                continue;
              }
            }

            final userPin = extractUserPincode(data);
            if (userPin == null || !normalizedAreaPins.contains(userPin)) {
              continue;
            }

            matched.add(UserModel.fromFirestore(doc));
            if (matched.length == limit) {
              reachedLimit = true;
              break;
            }
          }

          hasMore = reachedLimit || snapshot.docs.length == batchSize;
        }

        return PageResult(
          items: matched,
          lastDocument: cursor,
          hasMore: hasMore,
        );
      }

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.limit(limit).get();
      final matched = <UserModel>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        if (_shouldUseDerivedCityFiltering(selectedCity, assignedCities)) {
          if (!userMatchesAssignedCities(
            data,
            selectedCity,
            assignedCities,
            effectivePincodesMap,
            pincodeCityLookup,
          )) {
            continue;
          }
        }
        matched.add(UserModel.fromFirestore(doc));
      }

      final lastDoc = snapshot.docs.isEmpty ? null : snapshot.docs.last;

      return PageResult(
        items: matched,
        lastDocument: lastDoc,
        hasMore: snapshot.docs.length == limit,
      );
    });
  }

  /// Counts the total number of Star Service Providers for a specific category or area group.
  Future<int> countCategoryServiceProviders({
    required String category,
    List<String>? areaPincodes,
    String? selectedCity,
    String searchQuery = '',
    List<String> assignedCities = const [],
    bool isSuperAdmin = false,
  }) async {
    return _withRetry(() async {
      final isCategoryFilter =
          category.trim().isNotEmpty &&
          category != 'All' &&
          category != 'Uncategorized';

      var query = _buildStarServiceProvidersQuery(
        selectedCity: selectedCity,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
        category: isCategoryFilter ? category : null,
      );

      final search = UserSearchParams.fromQuery(searchQuery);
      switch (search.mode) {
        case UserSearchMode.none:
          break;
        case UserSearchMode.phone:
          if (search.phoneVariants != null &&
              search.phoneVariants!.length > 1) {
            query = query.where('phone', whereIn: search.phoneVariants);
          } else {
            query = query.where('phone', isEqualTo: search.phone);
          }
          break;
        case UserSearchMode.uid:
          query = query.where('uid', isEqualTo: search.rawQuery);
          break;
        case UserSearchMode.usernamePrefix:
          final prefix = search.rawQuery;
          query = query
              .where('username', isGreaterThanOrEqualTo: prefix)
              .where('username', isLessThanOrEqualTo: '$prefix\uf8ff');
          break;
        case UserSearchMode.businessNamePrefix:
          final prefix = search.rawQuery;
          query = query
              .where('businessname', isGreaterThanOrEqualTo: prefix)
              .where('businessname', isLessThanOrEqualTo: '$prefix\uf8ff');
          break;
      }

      if (areaPincodes != null && areaPincodes.isNotEmpty) {
        final snapshot = await query.get();
        final normalizedAreaPins = areaPincodes.map((p) => p.trim()).toSet();
        int count = 0;
        for (final doc in snapshot.docs) {
          final pin = extractUserPincode(doc.data());
          if (pin != null && normalizedAreaPins.contains(pin)) {
            count++;
          }
        }
        return count;
      }

      final snapshot = await query.count().get();
      return snapshot.count ?? 0;
    });
  }
} // end UserRepository

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  final isSuper = ref.watch(isSuperAdminProvider);
  final assignedCities =
      isSuper
          ? const <String>[]
          : ref.watch(currentAdminAssignedCitiesProvider);
  return repository.fetchUserStats(assignedCities: assignedCities);
});
