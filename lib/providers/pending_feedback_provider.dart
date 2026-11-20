import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// SAFE TIMESTAMP PARSER HELPER
// ---------------------------------------------------------------------------

/// Safely converts any Firestore timestamp representation to a Dart [DateTime].
///
/// Supports:
/// - Firestore [Timestamp] (`.toDate()`)
/// - Dart [DateTime]
/// - Valid ISO-8601 strings (via [DateTime.tryParse])
/// - Numeric milliseconds or seconds timestamps (e.g. Unix epochs)
/// - Stringified Timestamp representations (e.g. 'Timestamp(seconds=..., ...)')
/// - Null, missing, empty, or malformed values (returns `null` safely without throwing)
DateTime? parseSafeDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();

  if (value is int) {
    // If value > 100,000,000,000 (roughly Sep 1973 in ms), it's milliseconds
    if (value > 100000000000) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value > 0) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    }
    return null;
  }

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;

    // Handle stringified Firestore Timestamp: "Timestamp(seconds=1729000000, nanoseconds=...)"
    if (trimmed.contains('seconds=')) {
      final tsMatch = RegExp(r'seconds=(\d+)').firstMatch(trimmed);
      if (tsMatch != null) {
        final seconds = int.tryParse(tsMatch.group(1)!);
        if (seconds != null) {
          return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
    }

    // Pure numeric string
    final numeric = int.tryParse(trimmed);
    if (numeric != null) {
      return parseSafeDateTime(numeric);
    }

    // Direct ISO-8601 tryParse with year sanity guard (1970 - 2100)
    final parsed = DateTime.tryParse(trimmed);
    if (parsed != null && parsed.year >= 1970 && parsed.year <= 2100) {
      return parsed;
    }
  }

  return null;
}

// ---------------------------------------------------------------------------
// MODEL
// ---------------------------------------------------------------------------

/// A single de-duplicated service provider row for the Pending Provider
/// Feedback table. Sourced from callLogs (primary) and users (secondary).
class PendingFeedbackProvider {
  const PendingFeedbackProvider({
    required this.businessId,
    required this.name,
    required this.phone,
    required this.businessName,
    required this.cusName,
    required this.cusPhone,
    required this.timestamp,
  });

  /// The unique key — the provider's Firestore document ID in `users`.
  final String businessId;

  /// Provider's personal name (from `users` doc).
  final String name;

  /// Provider's phone (from `users` doc, fallback to callLog `businessPhone`).
  final String phone;

  /// Provider's business name (from callLog, fallback to `users` doc).
  final String businessName;

  /// Customer's name (from callLog).
  final String cusName;

  /// Customer's phone (from callLog).
  final String cusPhone;

  /// Timestamp of the pending feedback (from callLog).
  final DateTime? timestamp;
}

// ---------------------------------------------------------------------------
// STATE
// ---------------------------------------------------------------------------

class PendingFeedbackState {
  const PendingFeedbackState({
    this.providers = const [],
    this.isLoading = true,
    this.error,
    this.searchQuery = '',
  });

  final List<PendingFeedbackProvider> providers;
  final bool isLoading;
  final String? error;
  final String searchQuery;

  /// Rows visible after applying the in-memory search filter.
  List<PendingFeedbackProvider> get filtered {
    if (searchQuery.trim().isEmpty) return providers;
    final q = searchQuery.trim().toLowerCase();
    return providers.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.phone.toLowerCase().contains(q) ||
          p.businessName.toLowerCase().contains(q) ||
          p.cusName.toLowerCase().contains(q) ||
          p.cusPhone.toLowerCase().contains(q);
    }).toList();
  }

  PendingFeedbackState copyWith({
    List<PendingFeedbackProvider>? providers,
    bool? isLoading,
    String? error,
    bool clearError = false,
    String? searchQuery,
  }) {
    return PendingFeedbackState(
      providers: providers ?? this.providers,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

// ---------------------------------------------------------------------------
// INTERNAL HELPER STRUCT
// ---------------------------------------------------------------------------

class _RepresentativeCallLog {
  const _RepresentativeCallLog({
    required this.businessId,
    required this.callLogPhone,
    required this.callLogBusinessName,
    required this.customerName,
    required this.customerPhone,
    required this.timestamp,
  });

  final String businessId;
  final String callLogPhone;
  final String callLogBusinessName;
  final String customerName;
  final String customerPhone;
  final DateTime? timestamp;
}

// ---------------------------------------------------------------------------
// NOTIFIER
// ---------------------------------------------------------------------------

class PendingFeedbackNotifier extends Notifier<PendingFeedbackState> {
  StreamSubscription<QuerySnapshot>? _subscription;

  /// Monotonically increasing revision to detect and discard stale asynchronous user lookups.
  int _currentRevision = 0;

  /// Flag to prevent state updates if the notifier has been disposed.
  bool _isDisposed = false;

  @override
  PendingFeedbackState build() {
    _isDisposed = false;
    ref.onDispose(() {
      _isDisposed = true;
      _subscription?.cancel();
      _subscription = null;
    });
    Future.microtask(_subscribe);
    return const PendingFeedbackState();
  }

  // -------------------------------------------------------------------------
  // Public API
  // -------------------------------------------------------------------------

  /// Re-fetch from Firestore (cancel + re-subscribe).
  void refresh() {
    _subscription?.cancel();
    _subscription = null;
    state = state.copyWith(isLoading: true, clearError: true);
    _subscribe();
  }

  /// Update the search filter; no Firestore round-trip needed.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  // -------------------------------------------------------------------------
  // Internal
  // -------------------------------------------------------------------------

  /// Subscribes to the real-time stream of callLogs where feedbackStatus == "pending".
  ///
  /// Changes in Firestore (status updated to "converted", status changed back to
  /// "pending", or new logs added) trigger immediate snapshot events that reactively
  /// update Riverpod state and the UI.
  void _subscribe() {
    _subscription?.cancel();
    _subscription = FirebaseFirestore.instance
        .collection('callLogs')
        .where('feedbackStatus', isEqualTo: 'pending')
        .snapshots()
        .listen(_onData, onError: _onError);
  }

  Future<void> _onData(QuerySnapshot snapshot) async {
    final revision = ++_currentRevision;

    // --- Step 1: Collect unique businessIds, selecting the newest pending call log ---
    final representativeLogs = <String, _RepresentativeCallLog>{};

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final businessId =
          (data['businessId'] ?? data['providerId'] ?? data['uid'])
              ?.toString()
              .trim() ??
          '';
      if (businessId.isEmpty) continue;

      // Safe timestamp parsing that never throws
      final docTimestamp = parseSafeDateTime(
        data['timestamp'] ?? data['createdAt'],
      );

      final callLogPhone =
          (data['businessPhone'] ??
                  data['businessNumber'] ??
                  data['providerPhone'] ??
                  '')
              .toString()
              .trim();

      final callLogBusinessName =
          (data['businessName'] ?? data['businessname'] ?? '')
              .toString()
              .trim();

      final customerName =
          (data['customerName'] ?? data['callerName'] ?? '').toString().trim();

      final customerPhone =
          (data['customerPhone'] ??
                  data['customerNumber'] ??
                  data['callerPhone'] ??
                  '')
              .toString()
              .trim();

      final existing = representativeLogs[businessId];
      if (existing == null) {
        representativeLogs[businessId] = _RepresentativeCallLog(
          businessId: businessId,
          callLogPhone: callLogPhone,
          callLogBusinessName: callLogBusinessName,
          customerName: customerName,
          customerPhone: customerPhone,
          timestamp: docTimestamp,
        );
      } else {
        // If multiple pending call logs exist for this businessId,
        // choose the log with the newest timestamp.
        bool isNewer = false;
        if (docTimestamp != null) {
          if (existing.timestamp == null) {
            isNewer = true;
          } else if (docTimestamp.isAfter(existing.timestamp!)) {
            isNewer = true;
          }
        }

        if (isNewer) {
          representativeLogs[businessId] = _RepresentativeCallLog(
            businessId: businessId,
            callLogPhone:
                callLogPhone.isNotEmpty ? callLogPhone : existing.callLogPhone,
            callLogBusinessName:
                callLogBusinessName.isNotEmpty
                    ? callLogBusinessName
                    : existing.callLogBusinessName,
            customerName:
                customerName.isNotEmpty
                    ? customerName
                    : existing.customerName,
            customerPhone:
                customerPhone.isNotEmpty
                    ? customerPhone
                    : existing.customerPhone,
            timestamp: docTimestamp,
          );
        }
      }
    }

    if (representativeLogs.isEmpty) {
      if (_isDisposed || revision != _currentRevision) return;
      state = state.copyWith(
        providers: const [],
        isLoading: false,
        clearError: true,
      );
      return;
    }

    // Sort descending by timestamp so newest pending items appear at the top
    final sortedEntries = representativeLogs.values.toList()
      ..sort((a, b) {
        if (a.timestamp == null && b.timestamp == null) return 0;
        if (a.timestamp == null) return 1;
        if (b.timestamp == null) return -1;
        return b.timestamp!.compareTo(a.timestamp!);
      });

    // --- Step 2: Batch-fetch user documents by businessId ---
    final allIds = sortedEntries.map((e) => e.businessId).toList();
    final userDocs = await _batchFetchUsers(allIds);

    // Guard against stale snapshots or disposed notifier
    if (_isDisposed || revision != _currentRevision) {
      return;
    }

    // --- Step 3: Build the final provider list with correct fallbacks ---
    final providers = <PendingFeedbackProvider>[];
    for (final entry in sortedEntries) {
      final userData = userDocs[entry.businessId];

      // Name: from users doc (name -> firstname -> username -> '—')
      final name = _pickName(userData);

      // Provider Phone: prefer users doc, fallback to callLog businessPhone
      final phone = _pickPhone(userData, entry.callLogPhone);

      // Business name: prefer callLog, fallback to users doc
      final businessName =
          entry.callLogBusinessName.isNotEmpty
              ? entry.callLogBusinessName
              : _pickBusinessName(userData);

      // Customer name: from callLog, fallback '—' (never use provider info)
      final customerName =
          entry.customerName.isNotEmpty ? entry.customerName : '—';

      // Customer phone: from callLog, fallback '—' (never substitute provider phone)
      final customerPhone =
          entry.customerPhone.isNotEmpty ? entry.customerPhone : '—';

      providers.add(
        PendingFeedbackProvider(
          businessId: entry.businessId,
          name: name,
          phone: phone,
          businessName: businessName,
          cusName: customerName,
          cusPhone: customerPhone,
          timestamp: entry.timestamp,
        ),
      );
    }

    if (_isDisposed || revision != _currentRevision) {
      return;
    }

    state = state.copyWith(
      providers: providers,
      isLoading: false,
      clearError: true,
    );
  }

  void _onError(Object error) {
    if (_isDisposed) return;
    if (kDebugMode) {
      debugPrint('PendingFeedbackNotifier stream error: $error');
    }
    state = state.copyWith(isLoading: false, error: error.toString());
  }

  // -------------------------------------------------------------------------
  // Firestore batch helpers
  // -------------------------------------------------------------------------

  /// Fetches user documents whose IDs are in [ids] using batched
  /// `whereIn` queries (max 30 per request as per Firestore limits).
  Future<Map<String, Map<String, dynamic>>> _batchFetchUsers(
    List<String> ids,
  ) async {
    const chunkSize = 30;
    final result = <String, Map<String, dynamic>>{};
    final chunks = <List<String>>[];

    for (var i = 0; i < ids.length; i += chunkSize) {
      chunks.add(
        ids.sublist(
          i,
          i + chunkSize > ids.length ? ids.length : i + chunkSize,
        ),
      );
    }

    final futures = chunks.map((chunk) async {
      try {
        final snap =
            await FirebaseFirestore.instance
                .collection('users')
                .where(FieldPath.documentId, whereIn: chunk)
                .get();
        for (final doc in snap.docs) {
          result[doc.id] = doc.data();
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('PendingFeedback: users batch fetch error: $e');
        }
      }
    });

    await Future.wait(futures);
    return result;
  }

  // -------------------------------------------------------------------------
  // Field extraction helpers
  // -------------------------------------------------------------------------

  String _pickName(Map<String, dynamic>? data) {
    if (data == null) return '—';
    final name = data['name']?.toString().trim() ?? '';
    if (name.isNotEmpty) return name;
    final firstname = data['firstname']?.toString().trim() ?? '';
    final lastname = data['lastname']?.toString().trim() ?? '';
    if (firstname.isNotEmpty) {
      return lastname.isNotEmpty ? '$firstname $lastname' : firstname;
    }
    final username = data['username']?.toString().trim() ?? '';
    if (username.isNotEmpty) return username;
    return '—';
  }

  String _pickPhone(Map<String, dynamic>? data, String callLogPhone) {
    if (data != null) {
      final raw = data['phone'];
      if (raw != null) {
        final phoneStr = raw.toString().trim();
        if (phoneStr.isNotEmpty && phoneStr != '0') return phoneStr;
      }
    }
    return callLogPhone.isNotEmpty ? callLogPhone : '—';
  }

  String _pickBusinessName(Map<String, dynamic>? data) {
    if (data == null) return '—';
    final bn =
        (data['businessname'] ?? data['businessName'] ?? '').toString().trim();
    return bn.isNotEmpty ? bn : '—';
  }
}

// ---------------------------------------------------------------------------
// PROVIDERS
// ---------------------------------------------------------------------------

final pendingFeedbackProvider =
    NotifierProvider<PendingFeedbackNotifier, PendingFeedbackState>(
      PendingFeedbackNotifier.new,
    );
