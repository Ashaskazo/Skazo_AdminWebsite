import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/page_result.dart';
import 'package:skazo_admin/models/user_filters.dart';
import 'package:skazo_admin/models/user_model.dart';
import 'package:skazo_admin/utils/city_resolver.dart';
import 'package:skazo_admin/utils/time_filter.dart';

const userPageSize = 100;
const _firestoreTimeout = Duration(seconds: 45);
const _maxRetries = 2;
const _cityKeyField = 'cityKey';

/// Dashboard aggregate counts — no document downloads.
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

/// Consolidated count results returned by `fetchUserCounts`.
class UserCounts {
  final int total;
  final int customers;
  final int serviceProviders;
  final int filtered;

  const UserCounts({
    required this.total,
    required this.customers,
    required this.serviceProviders,
    required this.filtered,
  });

  factory UserCounts.zero() => const UserCounts(
        total: 0,
        customers: 0,
        serviceProviders: 0,
        filtered: 0,
      );
}

enum UserSearchMode { none, phone, uid, usernamePrefix, businessNamePrefix }

class UserSearchParams {
  final UserSearchMode mode;
  final String rawQuery;
  final String? phone;
  final List<String>? phoneVariants;

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

    // Check if query is digits-only (phone number)
    final digitsOnly = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length >= 7 && digitsOnly == trimmed.replaceAll(RegExp(r'[\s\+\-]'), '')) {
      if (digitsOnly.startsWith('91') && digitsOnly.length > 10) {
        final local = digitsOnly.substring(2);
        return UserSearchParams(
          mode: UserSearchMode.phone,
          rawQuery: trimmed,
          phone: digitsOnly,
          phoneVariants: [digitsOnly, local],
        );
      }
      final with91 = '91$digitsOnly';
      return UserSearchParams(
        mode: UserSearchMode.phone,
        rawQuery: trimmed,
        phone: digitsOnly,
        phoneVariants: [digitsOnly, with91],
      );
    }

    if (trimmed.length >= 20 && !trimmed.contains(' ')) {
      return UserSearchParams(mode: UserSearchMode.uid, rawQuery: trimmed);
    }

    return UserSearchParams(
      mode: UserSearchMode.businessNamePrefix,
      rawQuery: trimmed,
    );
  }
}

/// Production-ready Firestore data access for the `users` collection.
class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

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
        if (kDebugMode) {
          debugPrint('[UserRepository] Retry attempt $attempt: $e');
        }
        if (attempt < _maxRetries) {
          await Future<void>.delayed(
            Duration(milliseconds: 300 * (attempt + 1)),
          );
        }
      }
    }
    Error.throwWithStackTrace(lastError!, lastStack ?? StackTrace.current);
  }

  // ── City Scope Authorization ──────────────────────────────────────────────

  String _normalizeCityKey(String city) {
    return city.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Resolves authorized city keys for the current query.
  ///
  /// Returns:
  /// - `null`: Super Admin querying "All Cities" (unrestricted).
  /// - `[cityKey]`: Single city filter (Super Admin or Normal Admin).
  /// - `[cityKey1, cityKey2, ...]`: Multi-city normal admin without specific city selected.
  /// - `[]`: Unauthorized / empty scope (admin with 0 assigned cities).
  List<String>? _resolveAuthorizedCityKeys({
    required String? selectedCity,
    required List<String> assignedCities,
    required bool isSuperAdmin,
  }) {
    if (isSuperAdmin) {
      if (selectedCity != null && selectedCity.trim().isNotEmpty) {
        return [_normalizeCityKey(selectedCity)];
      }
      return null; // Unrestricted "All Cities"
    }

    // Normal Admin:
    if (assignedCities.isEmpty) {
      return const []; // Unauthorized: 0 assigned cities
    }

    final normalizedAssigned = assignedCities.map(_normalizeCityKey).toList();

    if (selectedCity != null && selectedCity.trim().isNotEmpty) {
      final requestedKey = _normalizeCityKey(selectedCity);
      if (normalizedAssigned.contains(requestedKey)) {
        return [requestedKey];
      }
      // Requested city is outside assigned scope -> clamp to first assigned city
      return [normalizedAssigned.first];
    }

    // No city selected -> return all assigned cities (up to 30 for whereIn)
    return normalizedAssigned.take(30).toList();
  }

  // ── Unified Query Builder ──────────────────────────────────────────────────

  List<Query<Map<String, dynamic>>> _buildUsersQueries({
    required UserFilters filters,
    required UserSearchParams search,
    required String? selectedCity,
    required List<String> assignedCities,
    required bool isSuperAdmin,
    String? overrideUserType,
    bool overrideUserTypeAll = false,
  }) {
    final effectiveUserType = overrideUserType ?? (overrideUserTypeAll ? 'All' : filters.userType);
    final normSelectedCity = (selectedCity != null && selectedCity.trim().isNotEmpty)
        ? _normalizeCityKey(selectedCity)
        : null;

    final cityKeys = _resolveAuthorizedCityKeys(
      selectedCity: selectedCity,
      assignedCities: assignedCities,
      isSuperAdmin: isSuperAdmin,
    );

    // If unauthorized (e.g. normal admin with 0 assigned cities)
    if (cityKeys != null && cityKeys.isEmpty) {
      return [_users.where(FieldPath.documentId, isEqualTo: '__unauthorized__')];
    }

    final queries = <Query<Map<String, dynamic>>>[];

    // Base query builders for userType
    List<Query<Map<String, dynamic>>> applyUserTypeFilters(Query<Map<String, dynamic>> base) {
      if (effectiveUserType == 'Customers') {
        return [
          base.where('isuser', isEqualTo: true),
          base.where('isuser', isEqualTo: 1),
          base.where('isuser', isEqualTo: 'true'),
        ];
      } else if (effectiveUserType == 'Service Providers') {
        return [
          base.where('isuser', isEqualTo: false),
          base.where('isuser', isEqualTo: 0),
          base.where('isuser', isEqualTo: 'false'),
          base.where('isServiceProvider', isEqualTo: true),
        ];
      }
      return [base];
    }

    // Apply city filters
    if (normSelectedCity != null) {
      final rawCityName = selectedCity!.trim();
      final cityVariants = {rawCityName, normSelectedCity};

      // 1. cityKey query
      var qKey = _users.where(_cityKeyField, isEqualTo: normSelectedCity);
      // 2. city query
      var qCity = _users.where('city', whereIn: cityVariants.toList());
      // 3. City query
      var qCityCap = _users.where('City', whereIn: cityVariants.toList());
      // 4. serviceProviderCities query (if applicable)
      var qCities = _users.where('serviceProviderCities', arrayContains: rawCityName);

      for (final q in [qKey, qCity, qCityCap, qCities]) {
        queries.addAll(applyUserTypeFilters(q));
      }
    } else if (cityKeys != null && cityKeys.isNotEmpty) {
      // Admin assigned cities
      var qCityKeys = cityKeys.length == 1
          ? _users.where(_cityKeyField, isEqualTo: cityKeys.first)
          : _users.where(_cityKeyField, whereIn: cityKeys);
      queries.addAll(applyUserTypeFilters(qCityKeys));
    } else {
      // Unrestricted "All Cities"
      queries.addAll(applyUserTypeFilters(_users));
    }

    // Apply shared filters & ordering to all generated queries
    return queries.map((q) {
      var query = q;
      if (filters.verifiedOnly == true) {
        query = query.where('isverified', isEqualTo: true);
      }
      if (filters.category != null && filters.category!.trim().isNotEmpty) {
        query = query.where('category', arrayContains: filters.category!.trim());
      }
      if (filters.priority != null) {
        query = query.where('priority', isEqualTo: filters.priority);
      }
      if (filters.profileComplete != null) {
        query = query.where('profileComplete', isEqualTo: filters.profileComplete);
      }

      query = _applyDateFilter(query, filters.timeFilter);
      final sortByCreatedAt = filters.timeFilter != TimeFilterOption.all;

      switch (search.mode) {
        case UserSearchMode.none:
          final businessNamePrefix = filters.businessNamePrefix?.trim();
          if (businessNamePrefix != null && businessNamePrefix.isNotEmpty) {
            final businessQuery = query
                .where('businessname', isGreaterThanOrEqualTo: businessNamePrefix)
                .where('businessname', isLessThanOrEqualTo: '$businessNamePrefix\uf8ff')
                .orderBy('businessname');
            return sortByCreatedAt
                ? businessQuery.orderBy('createdAt', descending: true)
                : businessQuery;
          }
          return sortByCreatedAt
              ? query.orderBy('createdAt', descending: true)
              : query;

        case UserSearchMode.phone:
          if (search.phoneVariants != null && search.phoneVariants!.length > 1) {
            final phoneQuery = query.where('phone', whereIn: search.phoneVariants);
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
    }).toList();
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

  // ── Public Fetch & Pagination ─────────────────────────────────────────────

  /// Fetches a paginated page of users matching [filters] and [searchQuery].
  Future<PageResult<UserModel>> fetchUsers({
    required UserFilters filters,
    String searchQuery = '',
    List<String> assignedCities = const [],
    bool isSuperAdmin = true,
    Map<String, List<String>> pincodesMap = const {},
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = userPageSize,
  }) async {
    return _withRetry(() async {
      final search = UserSearchParams.fromQuery(searchQuery);
      final pincodeLookup = buildPincodeCityLookup(pincodesMap);

      final queries = _buildUsersQueries(
        filters: filters,
        search: search,
        selectedCity: filters.city,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
      );

      final seenDocIds = <String>{};
      final matchedUsers = <UserModel>[];
      DocumentSnapshot<Map<String, dynamic>>? lastDoc;

      for (final q in queries) {
        if (matchedUsers.length >= limit) break;

        try {
          var query = q.limit(limit * 2);
          if (startAfter != null) {
            query = query.startAfterDocument(startAfter);
          }

          final snapshot = await query.get();
          for (final doc in snapshot.docs) {
            if (seenDocIds.contains(doc.id)) continue;
            seenDocIds.add(doc.id);

            final data = doc.data();

            // Client-side verification for userType and city matching
            final isProvider = UserModel.isServiceProviderDoc(data);
            if (filters.userType == 'Customers' && isProvider) continue;
            if (filters.userType == 'Service Providers' && !isProvider) continue;

            if (!userMatchesAssignedCities(
              data,
              filters.city,
              assignedCities,
              pincodesMap,
              pincodeLookup,
            )) {
              continue;
            }

            final user = UserModel.fromFirestore(doc);
            matchedUsers.add(user);
            lastDoc = doc;

            if (matchedUsers.length >= limit) break;
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[UserRepository] Query variant error: $e');
          }
        }
      }

      // Fallback scan if direct query returned no items but database has unmigrated users
      if (matchedUsers.isEmpty && (filters.city != null || assignedCities.isNotEmpty)) {
        final fallbackQuery = _users.limit(limit * 3);
        final snapshot = await fallbackQuery.get();
        for (final doc in snapshot.docs) {
          if (seenDocIds.contains(doc.id)) continue;
          seenDocIds.add(doc.id);
          final data = doc.data();

          final isProvider = UserModel.isServiceProviderDoc(data);
          if (filters.userType == 'Customers' && isProvider) continue;
          if (filters.userType == 'Service Providers' && !isProvider) continue;

          if (userMatchesAssignedCities(
            data,
            filters.city,
            assignedCities,
            pincodesMap,
            pincodeLookup,
          )) {
            matchedUsers.add(UserModel.fromFirestore(doc));
            lastDoc = doc;
            if (matchedUsers.length >= limit) break;
          }
        }
      }

      return PageResult(
        items: matchedUsers,
        lastDocument: lastDoc,
        hasMore: matchedUsers.length >= limit,
      );
    });
  }

  /// Attempts username-prefix search when business-name search returns empty.
  Future<PageResult<UserModel>> fetchUsersWithSearchFallback({
    required UserFilters filters,
    required String searchQuery,
    List<String> assignedCities = const [],
    bool isSuperAdmin = true,
    Map<String, List<String>> pincodesMap = const {},
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = userPageSize,
  }) async {
    final primary = await fetchUsers(
      filters: filters,
      searchQuery: searchQuery,
      assignedCities: assignedCities,
      isSuperAdmin: isSuperAdmin,
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

    return fetchUsers(
      filters: filters.copyWith(
        searchQuery: searchQuery,
      ),
      searchQuery: searchQuery,
      assignedCities: assignedCities,
      isSuperAdmin: isSuperAdmin,
      pincodesMap: pincodesMap,
      startAfter: startAfter,
      limit: limit,
    );
  }

  // ── Count Orchestration ───────────────────────────────────────────────────

  /// Single orchestration method that computes all counts for the current scope
  /// using server-side Firestore aggregate `count()` queries.
  Future<UserCounts> fetchUserCounts({
    required UserFilters filters,
    String searchQuery = '',
    List<String> assignedCities = const [],
    bool isSuperAdmin = true,
  }) async {
    return _withRetry(() async {
      final search = UserSearchParams.fromQuery(searchQuery);

      final filteredQueries = _buildUsersQueries(
        filters: filters,
        search: search,
        selectedCity: filters.city,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
      );

      final customerQueries = _buildUsersQueries(
        filters: filters,
        search: search,
        selectedCity: filters.city,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
        overrideUserType: 'Customers',
      );

      final providerQueries = _buildUsersQueries(
        filters: filters,
        search: search,
        selectedCity: filters.city,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
        overrideUserType: 'Service Providers',
      );

      final totalQueries = _buildUsersQueries(
        filters: filters,
        search: search,
        selectedCity: filters.city,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
        overrideUserTypeAll: true,
      );

      Future<int> executeCountSum(List<Query<Map<String, dynamic>>> qList) async {
        final counts = await Future.wait(
          qList.map((q) async {
            try {
              final snap = await q.count().get();
              return snap.count ?? 0;
            } catch (_) {
              return 0;
            }
          }),
        );
        return counts.reduce((a, b) => a + b);
      }

      final results = await Future.wait([
        executeCountSum(filteredQueries),
        executeCountSum(customerQueries),
        executeCountSum(providerQueries),
        executeCountSum(totalQueries),
      ]);

      final filteredCount = results[0];
      final customersCount = results[1];
      final providersCount = results[2];
      final totalCount = results[3];

      return UserCounts(
        filtered: filteredCount,
        customers: customersCount > 0 ? customersCount : (filters.userType == 'Customers' ? filteredCount : 0),
        serviceProviders: providersCount > 0 ? providersCount : (filters.userType == 'Service Providers' ? filteredCount : 0),
        total: totalCount > 0 ? totalCount : filteredCount,
      );
    });
  }

  /// Backward-compatible countUsers method
  Future<int> countUsers({
    required UserFilters filters,
    String searchQuery = '',
    List<String> assignedCities = const [],
    bool isSuperAdmin = true,
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    final counts = await fetchUserCounts(
      filters: filters,
      searchQuery: searchQuery,
      assignedCities: assignedCities,
      isSuperAdmin: isSuperAdmin,
    );
    return counts.filtered;
  }

  /// Backward-compatible countServiceProviders method
  Future<int> countServiceProviders({
    UserFilters? filters,
    List<String> assignedCities = const [],
    bool isSuperAdmin = true,
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    final baseFilters = (filters ?? const UserFilters()).copyWith(
      userType: 'Service Providers',
    );
    return countUsers(
      filters: baseFilters,
      assignedCities: assignedCities,
      isSuperAdmin: isSuperAdmin,
      pincodesMap: pincodesMap,
    );
  }

  // ── Dashboard Unverified Pending & Category Counts ────────────────────────

  Query<Map<String, dynamic>> _buildUnverifiedQuery({
    required TimeFilterOption timeFilter,
    String? category,
    List<String>? cityKeys,
  }) {
    Query<Map<String, dynamic>> query = _users
        .where('isverified', isEqualTo: false)
        .where('isuser', isEqualTo: false);

    if (cityKeys != null) {
      if (cityKeys.isEmpty) {
        return query.where(FieldPath.documentId, isEqualTo: '__unauthorized__');
      } else if (cityKeys.length == 1) {
        query = query.where(_cityKeyField, isEqualTo: cityKeys.first);
      } else {
        query = query.where(_cityKeyField, whereIn: cityKeys);
      }
    }

    if (category != null && category.trim().isNotEmpty) {
      query = query.where('category', arrayContains: category.trim());
    }

    query = _applyDateFilter(query, timeFilter);

    return timeFilter != TimeFilterOption.all
        ? query.orderBy('createdAt', descending: true)
        : query;
  }

  Future<int> countUnverifiedPending({
    TimeFilterOption timeFilter = TimeFilterOption.all,
    String? city,
    String? category,
    List<String> assignedCities = const [],
    bool isSuperAdmin = true,
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    return _withRetry(() async {
      final cityKeys = _resolveAuthorizedCityKeys(
        selectedCity: city,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
      );

      final query = _buildUnverifiedQuery(
        timeFilter: timeFilter,
        category: category,
        cityKeys: cityKeys,
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
    bool isSuperAdmin = true,
    Map<String, List<String>> pincodesMap = const {},
    DocumentSnapshot<Map<String, dynamic>>? startAfter,
    int limit = userPageSize,
  }) async {
    return _withRetry(() async {
      final cityKeys = _resolveAuthorizedCityKeys(
        selectedCity: city,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
      );

      var query = _buildUnverifiedQuery(
        timeFilter: timeFilter,
        category: category,
        cityKeys: cityKeys,
      );

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

  /// Computes category counts for unverified businesses without blind N-query explosions.
  Future<Map<String, int>> countUnverifiedByCategories({
    required List<String> categories,
    TimeFilterOption timeFilter = TimeFilterOption.all,
    String? city,
    List<String> assignedCities = const [],
    bool isSuperAdmin = true,
    Map<String, List<String>> pincodesMap = const {},
  }) async {
    return _withRetry(() async {
      final cityKeys = _resolveAuthorizedCityKeys(
        selectedCity: city,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
      );

      // Step 1: Check total unverified count in current scope
      final totalUnverified = await countUnverifiedPending(
        timeFilter: timeFilter,
        city: city,
        assignedCities: assignedCities,
        isSuperAdmin: isSuperAdmin,
      );

      // If 0 unverified businesses exist, return 0 for all categories immediately (0 extra reads!)
      if (totalUnverified == 0) {
        return {for (final cat in categories) cat: 0};
      }

      // Step 2: For moderate counts (<= 200 documents), fetch and aggregate in 1 single read
      if (totalUnverified <= 200) {
        final query = _buildUnverifiedQuery(
          timeFilter: timeFilter,
          cityKeys: cityKeys,
        );
        final snapshot = await query.limit(250).get();

        final counts = <String, int>{for (final cat in categories) cat: 0};
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final rawCategories = data['category'];
          if (rawCategories is List) {
            for (final item in rawCategories) {
              final cat = item?.toString().trim();
              if (cat != null && counts.containsKey(cat)) {
                counts[cat] = (counts[cat] ?? 0) + 1;
              }
            }
          } else if (rawCategories is String) {
            final cat = rawCategories.trim();
            if (counts.containsKey(cat)) {
              counts[cat] = (counts[cat] ?? 0) + 1;
            }
          }
        }
        return counts;
      }

      // Step 3: For very large datasets, execute aggregate count per category in bounded batches
      final counts = <String, int>{};
      final chunks = <List<String>>[];
      for (var i = 0; i < categories.length; i += 10) {
        chunks.add(categories.sublist(i, i + 10 > categories.length ? categories.length : i + 10));
      }

      for (final chunk in chunks) {
        final results = await Future.wait(
          chunk.map((cat) async {
            final count = await countUnverifiedPending(
              timeFilter: timeFilter,
              city: city,
              category: cat,
              assignedCities: assignedCities,
              isSuperAdmin: isSuperAdmin,
            );
            return MapEntry(cat, count);
          }),
        );
        counts.addEntries(results);
      }

      return counts;
    });
  }

  // ── Global Stats & Actions ────────────────────────────────────────────────

  Future<UserStats> fetchUserStats() async {
    return _withRetry(() async {
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final todayTs = Timestamp.fromDate(todayStart);

      final results = await Future.wait([
        _users.count().get(),
        _users.where('isverified', isEqualTo: true).count().get(),
        _users.where('isverified', isEqualTo: false).count().get(),
        _users.where('createdAt', isGreaterThanOrEqualTo: todayTs).count().get(),
      ]);

      return UserStats(
        total: results[0].count ?? 0,
        verified: results[1].count ?? 0,
        unverified: results[2].count ?? 0,
        today: results[3].count ?? 0,
      );
    });
  }

  Future<void> verifyUser(String userId) async {
    await _withRetry(() {
      return _users.doc(userId).update({
        'isverified': true,
        'isactive': true,
        'isDeactivated': false,
        'verifiedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deactivateUser(String userId) async {
    await _withRetry(() {
      return _users.doc(userId).update({
        'isactive': false,
        'isDeactivated': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final repository = ref.watch(userRepositoryProvider);
  return repository.fetchUserStats();
});
