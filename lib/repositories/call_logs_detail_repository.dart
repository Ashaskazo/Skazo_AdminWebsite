import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/models/call_logs_detail_item.dart';
import 'package:skazo_admin/utils/city_resolver.dart';

/// Provider for CallLogsDetailRepository
final callLogsDetailRepositoryProvider = Provider<CallLogsDetailRepository>((ref) {
  return CallLogsDetailRepository(FirebaseFirestore.instance);
});

/// Date filter options for Call Logs Details
enum CallLogsDetailDateOption {
  today,
  yesterday,
  last7Days,
  last30Days,
  custom,
}

extension CallLogsDetailDateOptionExtension on CallLogsDetailDateOption {
  String get label {
    switch (this) {
      case CallLogsDetailDateOption.today:
        return 'Today';
      case CallLogsDetailDateOption.yesterday:
        return 'Yesterday';
      case CallLogsDetailDateOption.last7Days:
        return 'Last 7 Days';
      case CallLogsDetailDateOption.last30Days:
        return 'Last 30 Days';
      case CallLogsDetailDateOption.custom:
        return 'Custom Range';
    }
  }
}

/// Computes the exact start and end timestamps for a given date option
({DateTime? start, DateTime? end}) calculateDateBounds({
  required CallLogsDetailDateOption option,
  DateTime? customStart,
  DateTime? customEnd,
}) {
  final now = DateTime.now();
  final todayStart = DateTime(now.year, now.month, now.day);
  final tomorrowStart = todayStart.add(const Duration(days: 1));

  switch (option) {
    case CallLogsDetailDateOption.today:
      return (start: todayStart, end: tomorrowStart);
    case CallLogsDetailDateOption.yesterday:
      final yesterdayStart = todayStart.subtract(const Duration(days: 1));
      return (start: yesterdayStart, end: todayStart);
    case CallLogsDetailDateOption.last7Days:
      final sevenDaysAgo = todayStart.subtract(const Duration(days: 7));
      return (start: sevenDaysAgo, end: tomorrowStart);
    case CallLogsDetailDateOption.last30Days:
      final thirtyDaysAgo = todayStart.subtract(const Duration(days: 30));
      return (start: thirtyDaysAgo, end: tomorrowStart);
    case CallLogsDetailDateOption.custom:
      if (customStart == null) return (start: null, end: null);
      final cStart = DateTime(customStart.year, customStart.month, customStart.day);
      final cEnd = customEnd != null
          ? DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999)
          : cStart.add(const Duration(days: 1));
      return (start: cStart, end: cEnd);
  }
}

/// Repository responsible for querying Firestore `callLogs` collection
/// and hydrating provider information from `users` collection.
class CallLogsDetailRepository {
  final FirebaseFirestore _firestore;

  // In-memory cache for provider documents to eliminate redundant Firestore reads
  final Map<String, Map<String, dynamic>> _userCache = {};

  CallLogsDetailRepository(this._firestore);

  static const Duration _queryTimeout = Duration(seconds: 25);
  static const int _maxQueryLimit = 1500;

  /// Fetches call logs matching the active date range and city scope,
  /// hydrates provider details from `users`, and returns typed `CallLogsDetailItem`s.
  Future<List<CallLogsDetailItem>> fetchCallLogsDetails({
    required CityAccessScope scope,
    String? selectedCity,
    required CallLogsDetailDateOption dateOption,
    DateTime? customStart,
    DateTime? customEnd,
    Map<String, List<String>> pincodesMap = const {},
    Map<String, String>? pincodeCityLookup,
  }) async {
    // 1. Strict Fail-Closed Security Boundary:
    // Unauthorized, unauthenticated, inactive, or unassigned admins get 0 records.
    if (!scope.isAuthorized) {
      return const [];
    }

    // 2. City Verification for non-Super-Admin:
    // If a specific city is selected, ensure it is in the employee's assigned cities.
    if (!scope.isSuperAdmin && selectedCity != null && selectedCity.isNotEmpty && selectedCity != 'All Cities') {
      if (!scope.canAccessCityName(selectedCity)) {
        if (kDebugMode) {
          debugPrint('Security warning: Unauthorized city access attempt: $selectedCity');
        }
        return const [];
      }
    }

    final effectiveLookup = pincodeCityLookup ?? buildPincodeCityLookup(pincodesMap);
    final dateBounds = calculateDateBounds(
      option: dateOption,
      customStart: customStart,
      customEnd: customEnd,
    );

    // 3. Build and execute Firestore query on `callLogs`
    List<QueryDocumentSnapshot<Map<String, dynamic>>> callLogSnapshots = [];
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('callLogs')
          .orderBy('timestamp', descending: true);

      if (dateBounds.start != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateBounds.start!),
        );
      }
      if (dateBounds.end != null) {
        query = query.where(
          'timestamp',
          isLessThanOrEqualTo: Timestamp.fromDate(dateBounds.end!),
        );
      }

      query = query.limit(_maxQueryLimit);

      final snap = await query.get().timeout(_queryTimeout);
      callLogSnapshots = snap.docs;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('CallLogs query error ($e), attempting fallback query...');
      }
      // Fallback: If composite index fails or timeout occurs, try fallback query on timestamp
      try {
        Query<Map<String, dynamic>> fallbackQuery = _firestore
            .collection('callLogs')
            .orderBy('timestamp', descending: true)
            .limit(500);

        if (dateBounds.start != null) {
          fallbackQuery = fallbackQuery.where(
            'timestamp',
            isGreaterThanOrEqualTo: Timestamp.fromDate(dateBounds.start!),
          );
        }
        final fallbackSnap = await fallbackQuery.get().timeout(_queryTimeout);
        callLogSnapshots = fallbackSnap.docs;
      } catch (fallbackError) {
        if (kDebugMode) {
          debugPrint('CallLogs fallback query error: $fallbackError');
        }
        rethrow;
      }
    }

    if (callLogSnapshots.isEmpty) {
      return const [];
    }

    // 4. Hydrate missing provider `users` documents in batches
    await _hydrateProviderUsers(callLogSnapshots);

    // 5. Build items and enforce City-Wise Admin Access permissions
    final effectiveCityFilter = (selectedCity != null &&
            selectedCity.isNotEmpty &&
            selectedCity != 'All Cities' &&
            selectedCity != 'All')
        ? selectedCity
        : null;

    final List<CallLogsDetailItem> items = [];
    final Set<String> seenCallLogIds = {};

    for (final doc in callLogSnapshots) {
      // Prevent duplicate documents
      if (!seenCallLogIds.add(doc.id)) continue;

      final data = doc.data();
      final providerId = (data['businessId'] ??
              data['business_id'] ??
              data['providerId'] ??
              data['provider_id'] ??
              data['uid'])
          ?.toString()
          .trim();

      final userData = (providerId != null && providerId.isNotEmpty) ? _userCache[providerId] : null;

      // Prepare record with city information for scope evaluation
      final rawWithResolvedCity = <String, dynamic>{
        ...data,
        if (userData != null) ...{
          if (data['city'] == null && userData['city'] != null) 'city': userData['city'],
          if (data['businessCity'] == null && userData['businessCity'] != null)
            'businessCity': userData['businessCity'],
          if (data['pincode'] == null && userData['pincode'] != null) 'pincode': userData['pincode'],
        },
      };

      // City Access Permission Evaluation:
      // Verifies against the admin's assigned cities and selected city filter
      final isPermitted = scope.allowsRecord(
        rawWithResolvedCity,
        selectedCity: effectiveCityFilter,
        pincodesMap: pincodesMap,
        pincodeCityLookup: effectiveLookup,
        relatedEntityLookup: _userCache,
      );

      if (!isPermitted) continue;

      final item = CallLogsDetailItem.fromFirestore(
        doc: doc,
        userData: userData,
        pincodesMap: pincodesMap,
        pincodeCityLookup: effectiveLookup,
      );

      items.add(item);
    }

    return items;
  }

  /// Batches uncached provider IDs and fetches corresponding `users` documents
  Future<void> _hydrateProviderUsers(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> callLogSnapshots,
  ) async {
    final idsToFetch = <String>{};

    for (final doc in callLogSnapshots) {
      final data = doc.data();
      final pId = (data['businessId'] ??
              data['business_id'] ??
              data['providerId'] ??
              data['provider_id'] ??
              data['uid'])
          ?.toString()
          .trim();

      if (pId != null && pId.isNotEmpty && !pId.contains('/') && !_userCache.containsKey(pId)) {
        idsToFetch.add(pId);
      }

      // Also check associated entity IDs from city_resolver
      for (final associatedId in extractAssociatedEntityIds(data)) {
        final cleanId = associatedId.trim();
        if (cleanId.isNotEmpty && !cleanId.contains('/') && !_userCache.containsKey(cleanId)) {
          idsToFetch.add(cleanId);
        }
      }
    }

    if (idsToFetch.isEmpty) return;

    final chunks = chunkList<String>(idsToFetch.toList(), 30);
    await Future.wait(chunks.map((chunk) async {
      try {
        final snap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get()
            .timeout(const Duration(seconds: 15));

        for (final doc in snap.docs) {
          _userCache[doc.id] = {'id': doc.id, ...doc.data()};
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error hydrating users in CallLogsDetailRepository: $e');
        }
      }
    }));
  }

  /// Clears in-memory provider cache if explicitly requested
  void clearCache() {
    _userCache.clear();
  }
}
