import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/call_logs_detail_provider.dart';
import 'package:skazo_admin/utils/city_resolver.dart';
import 'package:skazo_admin/utils/property_pincodes_cache.dart';
import 'package:skazo_admin/utils/responsive.dart';
import 'package:skazo_admin/widgets/call_logs_detail_data_view.dart';


class CallLogsDataView extends ConsumerStatefulWidget {
  const CallLogsDataView({super.key});

  @override
  ConsumerState<CallLogsDataView> createState() => _CallLogsDataViewState();
}

class _CallLogsDataViewState extends ConsumerState<CallLogsDataView> {
  // Stream & Data State
  StreamSubscription<QuerySnapshot>? _logsSubscription;
  List<Map<String, dynamic>> _allDocs = [];
  Map<String, List<String>> _pincodesMap = {};
  Map<String, String> _pincodeCityLookup = {};
  final Map<String, Map<String, dynamic>> _businessUsersLookup = {};

  // Filters & Controllers
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _businessNameController = TextEditingController();
  final TextEditingController _customerPhoneController =
      TextEditingController();
  final TextEditingController _providerPhoneController =
      TextEditingController();
  final TextEditingController _assignedPersonController =
      TextEditingController();
  final TextEditingController _feedbackDescriptionController =
      TextEditingController();
  bool _isSavingFeedbackDescription = false;
  String? _lastLoadedFeedbackDocId;

  final int _pageSize = 10;
  String _dateFilter = 'Last 7 Days'; // Default to Last 7 Days
  String _filterCallStatus = 'All';
  String _filterPaymentStatus = 'All';
  String _filterFollowUpStatus = 'All';
  String _filterBoostSent = 'All';
  String _filterPlan = 'All';

  String? _activeSavedView;
  String get _userRole =>
      ref.read(cityAccessScopeProvider).isUnrestricted
          ? 'Super Admin'
          : 'Sales Team';

  // Loading & Data State
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 0;
  int _totalMatches = 0;
  bool _hasNextPage = false;

  List<Map<String, dynamic>> _currentPageLogs = [];
  List<Map<String, dynamic>> _filteredLogs = [];
  String? _selectedDocId;
  Map<String, dynamic>? _selectedDocData;
  bool _showMobileDetail = false;

  // Selected City Scope (null means All Cities for Super Admin, or all assigned cities)
  String? _selectedCity;

  // Header Dashboard Stats
  int _statOverallCalls = 0;
  int _statOverallLeads = 0;
  int _statTodayCalls = 0;
  int _statInterested = 0;
  int _statConverted = 0;
  int _statFollowUpsDue = 0;

  @override
  void initState() {
    super.initState();
    _resetAndLoad();
  }

  @override
  void dispose() {
    _logsSubscription?.cancel();
    _searchController.dispose();
    _cityController.dispose();
    _categoryController.dispose();
    _businessNameController.dispose();
    _customerPhoneController.dispose();
    _providerPhoneController.dispose();
    _assignedPersonController.dispose();
    _feedbackDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _hydrateBusinessUsersLookup(
    List<Map<String, dynamic>> docs,
  ) async {
    final idsToFetch = <String>{};
    for (final log in docs) {
      final raw = (log['rawData'] as Map<String, dynamic>?) ?? const {};
      if (resolveRecordCity(
            raw,
            pincodesMap: _pincodesMap,
            pincodeCityLookup: _pincodeCityLookup,
          ) ==
          null) {
        for (final id in extractAssociatedEntityIds(raw)) {
          if (!_businessUsersLookup.containsKey(id)) {
            idsToFetch.add(id);
          }
        }
      }
    }
    if (idsToFetch.isEmpty) return;

    final chunks = chunkList<String>(idsToFetch.toList(), 30);
    for (final chunk in chunks) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          _businessUsersLookup[doc.id] = {'id': doc.id, ...doc.data()};
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error hydrating business users lookup: $e');
        }
      }
    }
  }

  Future<void> _resetAndLoad() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 0;
      _currentPageLogs = [];
      _filteredLogs = [];
      _totalMatches = 0;
      _hasNextPage = false;
      _selectedDocId = null;
      _selectedDocData = null;
      _statOverallCalls = 0;
      _statOverallLeads = 0;
      _statTodayCalls = 0;
      _statInterested = 0;
      _statConverted = 0;
      _statFollowUpsDue = 0;
    });

    await _loadPincodesMap();
    try {
      await _fetchDashboardStats();
      _subscribeToLogs();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error initializing call logs: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadPincodesMap() async {
    try {
      final map = await loadPropertyPincodes();
      if (mounted) {
        setState(() {
          _pincodesMap = map;
          _pincodeCityLookup = buildPincodeCityLookup(map);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading pincodes in call logs: $e');
      }
    }
  }

  ({DateTime startUtc, DateTime endUtc}) _getIstTodayRange() {
    final nowUtc = DateTime.now().toUtc();
    final nowIst = nowUtc.add(const Duration(hours: 5, minutes: 30));
    final istMidnight = DateTime.utc(nowIst.year, nowIst.month, nowIst.day);
    final istTomorrowMidnight = istMidnight.add(const Duration(days: 1));

    final startUtc = istMidnight.subtract(
      const Duration(hours: 5, minutes: 30),
    );
    final endUtc = istTomorrowMidnight.subtract(
      const Duration(hours: 5, minutes: 30),
    );

    return (startUtc: startUtc, endUtc: endUtc);
  }

  Future<void> _fetchDashboardStats() async {
    final scope = ref.read(cityAccessScopeProvider);
    if (!scope.isAuthorized || !scope.isUnrestricted) {
      // Non-Super-Admin or unauthorized accounts derive stats strictly from city-scoped docs.
      return;
    }

    final range = _getIstTodayRange();
    final todayStart = range.startUtc;
    final tomorrowStart = range.endUtc;

    try {
      final baseCol = FirebaseFirestore.instance.collection('callLogs');

      // Total count
      final totalSnap = await baseCol.count().get();
      _statOverallCalls = totalSnap.count ?? 0;
      _statOverallLeads = _statOverallCalls;

      // Today calls
      final todaySnap =
          await baseCol
              .where(
                'timestamp',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
              )
              .where('timestamp', isLessThan: Timestamp.fromDate(tomorrowStart))
              .count()
              .get();
      _statTodayCalls = todaySnap.count ?? 0;

      // Interested (salesStatus == 'interested')
      final interestedSnap =
          await baseCol
              .where('salesStatus', isEqualTo: 'interested')
              .count()
              .get();
      _statInterested = interestedSnap.count ?? 0;

      // Converted (feedbackStatus == 'converted')
      final convertedSnap =
          await baseCol
              .where('feedbackStatus', isEqualTo: 'converted')
              .count()
              .get();
      _statConverted = convertedSnap.count ?? 0;

      // Follow-ups Due today/overdue
      final followUpSnap =
          await baseCol
              .where('salesStatus', isEqualTo: 'follow_up')
              .where(
                'followUpDate',
                isLessThan: Timestamp.fromDate(tomorrowStart),
              )
              .count()
              .get();
      _statFollowUpsDue = followUpSnap.count ?? 0;

      setState(() {});
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error fetching stats: $e');
      }
    }
  }

  DateTime? _getDateFilterDate() {
    final range = _getIstTodayRange();
    final todayStart = range.startUtc;

    if (_dateFilter == 'Today') {
      return todayStart;
    }
    if (_dateFilter == 'Yesterday') {
      return todayStart.subtract(const Duration(days: 1));
    }
    if (_dateFilter == 'Last 7 Days') {
      return todayStart.subtract(const Duration(days: 7));
    }
    if (_dateFilter == 'Last 30 Days') {
      return todayStart.subtract(const Duration(days: 30));
    }
    return null;
  }

  /// Sets up a real-time Firestore stream for call logs, respecting the active
  /// date filter. Whenever new documents arrive, in-memory filtering is
  /// re-applied so the UI updates instantly without manual refresh.
  void _subscribeToLogs() {
    _logsSubscription?.cancel();

    try {
      final baseQuery = FirebaseFirestore.instance
          .collection('callLogs')
          .orderBy('timestamp', descending: true);

      final dateFilterDate = _getDateFilterDate();
      Query query = baseQuery;

      if (dateFilterDate != null) {
        query = query.where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateFilterDate),
        );
      }

      _logsSubscription = query.snapshots().listen(
        (snapshot) async {
          final docs = snapshot.docs.map((doc) => _buildCallLogRow(doc)).toList();
          await _hydrateBusinessUsersLookup(docs);
          if (!mounted) return;
          _allDocs = docs;
          _applyFilters();
        },
        onError: (e) {
          if (mounted) {
            setState(() {
              _errorMessage = e.toString();
              _isLoading = false;
            });
          }
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error subscribing to call logs: $e');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Applies all active in-memory filters to [_allDocs] and updates the
  /// paginated view. Called whenever the stream delivers new data or
  /// a filter is changed by the user.
  void _applyFilters() {
    if (!mounted) return;

    final scope = ref.read(cityAccessScopeProvider);
    if (!scope.isAuthorized) {
      setState(() {
        _filteredLogs = [];
        _currentPageLogs = [];
        _totalMatches = 0;
        _hasNextPage = false;
        _selectedDocId = null;
        _selectedDocData = null;
        _statOverallCalls = 0;
        _statOverallLeads = 0;
        _statTodayCalls = 0;
        _statInterested = 0;
        _statConverted = 0;
        _statFollowUpsDue = 0;
        _isLoading = false;
      });
      return;
    }

    final cityFilter = _selectedCity ?? _cityController.text.trim();
    final effectiveCityFilter =
        (cityFilter.isNotEmpty &&
                cityFilter != 'All Cities' &&
                cityFilter != 'All')
            ? cityFilter
            : null;

    // 0. Filter by City Scope (Employee assigned cities OR Super Admin selected city)
    final cityScopedDocs =
        _allDocs.where((log) {
          final raw = (log['rawData'] as Map<String, dynamic>?) ?? {};
          final rawWithResolvedCity = <String, dynamic>{
            ...raw,
            if ((log['city']?.toString().trim().isNotEmpty ?? false) &&
                (raw['city']?.toString().trim().isEmpty ?? true))
              'city': log['city'],
          };
          return scope.allowsRecord(
            rawWithResolvedCity,
            selectedCity: effectiveCityFilter,
            pincodesMap: _pincodesMap,
            pincodeCityLookup: _pincodeCityLookup,
            relatedEntityLookup: _businessUsersLookup,
          );
        }).toList();

    // Update Header Dashboard Stats to match selected city and active date scope
    _statOverallCalls = cityScopedDocs.length;

    final uniqueLeadKeys = <String>{};
    int todayCount = 0;
    int interestedCount = 0;
    int convertedCount = 0;
    int followUpsDueCount = 0;

    final range = _getIstTodayRange();
    final todayStartUtc = range.startUtc;
    final todayEndUtc = range.endUtc;

    for (final log in cityScopedDocs) {
      final raw = log['rawData'] ?? {};
      final ts = log['timestamp'];

      // Unique lead calculation (caller/customer phone or fallback to doc ID)
      final phone = (log['phone'] ?? '').toString().trim();
      final leadKey = phone.isNotEmpty ? phone : log['id'].toString();
      uniqueLeadKeys.add(leadKey);

      // Today calls (IST calendar day)
      if (ts is DateTime) {
        final tsUtc = ts.toUtc();
        if (!tsUtc.isBefore(todayStartUtc) && tsUtc.isBefore(todayEndUtc)) {
          todayCount++;
        }
      }

      // Converted count: strictly feedbackStatus == 'converted'
      final feedbackStatus =
          (raw['feedbackStatus'] ?? '').toString().toLowerCase().trim();
      if (feedbackStatus == 'converted') {
        convertedCount++;
      }

      // Sales Status stats
      final salesStatus = (raw['salesStatus'] ?? '').toString().toLowerCase();
      if (salesStatus == 'interested') {
        interestedCount++;
      } else if (salesStatus == 'follow_up') {
        if (raw['followUpDate'] is Timestamp) {
          final followUpDt =
              (raw['followUpDate'] as Timestamp).toDate().toUtc();
          if (followUpDt.isBefore(todayEndUtc)) {
            followUpsDueCount++;
          }
        }
      }
    }

    _statOverallLeads = uniqueLeadKeys.length;
    _statTodayCalls = todayCount;
    _statInterested = interestedCount;
    _statConverted = convertedCount;
    _statFollowUpsDue = followUpsDueCount;

    _filteredLogs =
        cityScopedDocs.where((log) {
          final raw = log['rawData'] ?? {};

          // 1. Quick search
          if (_searchController.text.trim().isNotEmpty) {
            final sQuery = _searchController.text.trim().toLowerCase();
            final deepSearchStr = _getDeepSearchString(raw, log['id']);
            if (!deepSearchStr.contains(sQuery)) return false;
          }

          // 2. Additional text city filter if different from selected city
          if (_cityController.text.trim().isNotEmpty && _selectedCity == null) {
            final filterCity = _cityController.text.trim();
            final matchesCity = userMatchesCity(
              raw,
              filterCity,
              _pincodesMap,
              _pincodeCityLookup,
            );
            final cityVal = _normalizeString(log['city']);
            final fallbackMatches = cityVal.contains(filterCity.toLowerCase());
            if (!matchesCity && !fallbackMatches) {
              return false;
            }
          }

          // 3. Category filter
          if (_categoryController.text.trim().isNotEmpty) {
            final catVal = _normalizeString(raw['category']);
            if (!catVal.contains(
              _categoryController.text.trim().toLowerCase(),
            )) {
              return false;
            }
          }

          // 4. Business name filter
          if (_businessNameController.text.trim().isNotEmpty) {
            final bNameVal = _normalizeString(log['businessName']);
            if (!bNameVal.contains(
              _businessNameController.text.trim().toLowerCase(),
            )) {
              return false;
            }
          }

          // 5. Customer Phone filter
          if (_customerPhoneController.text.trim().isNotEmpty) {
            final cPhone = _normalizeString(
              log['customerNumber'] ?? log['callerPhone'],
            );
            if (!cPhone.contains(_customerPhoneController.text.trim())) {
              return false;
            }
          }

          // 6. Provider Phone filter
          if (_providerPhoneController.text.trim().isNotEmpty) {
            final pPhone = _normalizeString(log['businessNumber']);
            if (!pPhone.contains(_providerPhoneController.text.trim())) {
              return false;
            }
          }

          // 12. Plan Type
          if (_filterPlan != 'All') {
            final plan = _normalizeString(raw['plan']);
            if (plan != _filterPlan.toLowerCase()) return false;
          }

          // Apply Saved Views
          if (_activeSavedView != null) {
            switch (_activeSavedView) {
              case 'Today Calls':
                final logDate = log['timestamp'] as DateTime;
                final tsUtc = logDate.toUtc();
                if (tsUtc.isBefore(todayStartUtc) ||
                    !tsUtc.isBefore(todayEndUtc)) {
                  return false;
                }
                break;
              case 'Pending Follow-ups':
                if (raw['salesStatus'] != 'follow_up') return false;
                break;
              case 'Interested Leads':
                if (raw['salesStatus'] != 'interested') return false;
                break;
              case 'Converted':
                final fStatus =
                    (raw['feedbackStatus'] ?? '')
                        .toString()
                        .toLowerCase()
                        .trim();
                final sStatus =
                    (raw['salesStatus'] ?? '').toString().toLowerCase().trim();
                if (fStatus != 'converted' && sStatus != 'converted')
                  return false;
                break;
              case 'Paid Providers':
                final plan = _normalizeString(raw['plan']);
                if (plan != 'paid' && plan != '599' && plan != 'premium') {
                  return false;
                }
                break;
              case 'City-wise Leads':
                if (_normalizeString(log['city']).isEmpty) return false;
                break;
            }
          }

          return true;
        }).toList();

    _totalMatches = _filteredLogs.length;
    _hasNextPage = (_currentPage + 1) * _pageSize < _totalMatches;

    final startIndex = _currentPage * _pageSize;
    _currentPageLogs = _filteredLogs.skip(startIndex).take(_pageSize).toList();

    if (_currentPageLogs.isNotEmpty) {
      final found = _currentPageLogs.any((log) => log['id'] == _selectedDocId);
      if (!found) {
        _selectedDocId = _currentPageLogs.first['id'];
        _selectedDocData = _currentPageLogs.first;
      } else {
        _selectedDocData = _currentPageLogs.firstWhere(
          (log) => log['id'] == _selectedDocId,
        );
      }
    } else {
      _selectedDocId = null;
      _selectedDocData = null;
    }

    _syncFeedbackDescriptionWithSelectedDoc();

    setState(() {
      _isLoading = false;
      _errorMessage = null;
    });
  }

  String _normalizeString(dynamic value) {
    if (value == null) return '';
    return value.toString().trim().toLowerCase();
  }

  String _getDeepSearchString(Map<String, dynamic> data, String docId) {
    final List<String> values = [docId.toLowerCase()];

    void helper(dynamic val) {
      if (val == null) return;
      if (val is Map) {
        val.values.forEach(helper);
      } else if (val is List) {
        val.forEach(helper);
      } else if (val is Timestamp) {
        values.add(val.toDate().toString().toLowerCase());
      } else {
        values.add(val.toString().trim().toLowerCase());
      }
    }

    data.values.forEach(helper);

    // Add explicit values
    final address = data['businessAddress'] ?? data['customerAddress'] ?? '';
    final explicitCity =
        data['city'] ?? data['businessCity'] ?? data['customerCity'];
    final city =
        _normalizeString(explicitCity ?? '').isNotEmpty
            ? explicitCity.toString()
            : (resolveUserCityName(data, _pincodesMap, _pincodeCityLookup) ??
                _extractCityFromAddress(address));
    values.add(city.toLowerCase());

    return values.join(' ');
  }

  String _extractCityFromAddress(String address) {
    final cleaned = address.trim();
    if (cleaned.isEmpty) return '';

    final parts =
        cleaned
            .split(',')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();
    if (parts.isEmpty) return '';

    final pincodeRegex = RegExp(r'^\d{5,6}$');
    final ignoredWords = {
      'india',
      'usa',
      'united states',
      'uk',
      'united kingdom',
      'state',
      'pincode',
      'zip',
    };

    for (int i = parts.length - 1; i >= 0; i--) {
      final part = parts[i];
      final normalized = part.toLowerCase();

      if (ignoredWords.contains(normalized)) {
        continue;
      }
      if (pincodeRegex.hasMatch(part) ||
          normalized.contains(RegExp(r'\b\d{5,6}\b'))) {
        continue;
      }
      if (part.contains('+') && i > 0) {
        continue;
      }
      return part;
    }
    return parts.first;
  }

  Map<String, dynamic> _buildCallLogRow(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final businessName = data['businessName'] ?? data['businessname'] ?? '';
    final customerName = data['customerName'] ?? data['callerName'] ?? '';
    final callerPhone = data['callerPhone']?.toString() ?? '';
    final customerNumber = data['customerNumber']?.toString() ?? '';
    final businessNumber = data['businessNumber']?.toString() ?? '';
    final phone =
        customerNumber.isNotEmpty
            ? customerNumber
            : callerPhone.isNotEmpty
            ? callerPhone
            : businessNumber;

    final timestamp =
        data['timestamp'] is Timestamp
            ? (data['timestamp'] as Timestamp).toDate()
            : DateTime.now();
    final address = data['businessAddress'] ?? data['customerAddress'] ?? '';
    final explicitCity =
        data['city'] ?? data['businessCity'] ?? data['customerCity'];
    final city =
        _normalizeString(explicitCity ?? '').isNotEmpty
            ? explicitCity.toString()
            : (resolveUserCityName(data, _pincodesMap, _pincodeCityLookup) ??
                _extractCityFromAddress(address));

    return {
      'id': doc.id,
      'businessName': businessName,
      'customerName': customerName,
      'phone': phone,
      'callerPhone': callerPhone,
      'customerNumber': customerNumber,
      'businessNumber': businessNumber,
      'timestamp': timestamp,
      'city': city,
      'rawData': data,
    };
  }

  String _formatTimestamp(dynamic rawTimestamp) {
    if (rawTimestamp is Timestamp) {
      print("************************************************************");
      print('Formatting Timestamp: $rawTimestamp');
      print(
        "rawTimestamp.toDate().toLocal(): ${rawTimestamp.toDate().toLocal()}",
      );
      return '${rawTimestamp.toDate().toLocal()}'.split('.').first;
    }
    return rawTimestamp?.toString() ?? '-';
  }

  Future<void> _writeAuditLog({
    required String docId,
    required String fieldName,
    required dynamic oldValue,
    required dynamic newValue,
  }) async {
    final email = FirebaseAuth.instance.currentUser?.email ?? 'admin@skazo.com';
    try {
      await FirebaseFirestore.instance.collection('admin_audit_logs').add({
        'collection': 'callLogs',
        'documentId': docId,
        'fieldName': fieldName,
        'oldValue': oldValue?.toString() ?? 'null',
        'newValue': newValue?.toString() ?? 'null',
        'editedBy': email,
        'editedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Failed to write audit log: $e');
      }
    }
  }

  bool _canEditField(String fieldName) {
    if (ref.read(cityAccessScopeProvider).isUnrestricted) return true;

    final allowedCRMFields = {
      'salesStatus',
      'salesRemark',
      'followUpDate',
      'assignedTo',
      'leadQuality',
      'paymentInterest',
      'calledBySales',
      'feedbackStatus',
      'feedbackDescription',
    };
    return allowedCRMFields.contains(fieldName);
  }

  bool _verifySelectedDocEditable() {
    if (_selectedDocId == null || _selectedDocData == null) return false;
    final scope = ref.read(cityAccessScopeProvider);
    final raw =
        (_selectedDocData!['rawData'] as Map<String, dynamic>?) ?? const {};
    final allowed =
        scope.isAuthorized &&
        scope.allowsRecord(
          raw,
          pincodesMap: _pincodesMap,
          pincodeCityLookup: _pincodeCityLookup,
          relatedEntityLookup: _businessUsersLookup,
        );
    if (!allowed && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Access denied: record belongs to an unassigned city.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
    return allowed;
  }

  Future<void> _changeCRMStatus(String status) async {
    if (_selectedDocId == null || !_verifySelectedDocEditable()) return;

    final raw = _selectedDocData!['rawData'] ?? {};
    final oldStatus = raw['salesStatus'];
    final email = FirebaseAuth.instance.currentUser?.email ?? 'admin@skazo.com';

    try {
      await FirebaseFirestore.instance
          .collection('callLogs')
          .doc(_selectedDocId)
          .update({
            'salesStatus': status,
            'lastSalesUpdatedAt': FieldValue.serverTimestamp(),
            'lastSalesUpdatedBy': email,
          });

      await _writeAuditLog(
        docId: _selectedDocId!,
        fieldName: 'salesStatus',
        oldValue: oldStatus,
        newValue: status,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Status updated to ${status.toUpperCase()}'),
          backgroundColor: Colors.green,
        ),
      );

      _applyFilters();
      _fetchDashboardStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _updateFeedbackStatus(String status) async {
    if (_selectedDocId == null || !_verifySelectedDocEditable()) return;

    final raw = _selectedDocData!['rawData'] ?? {};
    final oldFeedbackStatus = raw['feedbackStatus'];
    final email = FirebaseAuth.instance.currentUser?.email ?? 'sales@skazo.com';

    try {
      await FirebaseFirestore.instance
          .collection('callLogs')
          .doc(_selectedDocId)
          .update({
            'feedbackStatus': status,
            'lastFeedbackUpdatedAt': FieldValue.serverTimestamp(),
            'lastFeedbackUpdatedBy': email,
          });

      await _writeAuditLog(
        docId: _selectedDocId!,
        fieldName: 'feedbackStatus',
        oldValue: oldFeedbackStatus,
        newValue: status,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Feedback status set to "$status"'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

      setState(() {
        if (_selectedDocData != null && _selectedDocData!['rawData'] != null) {
          (_selectedDocData!['rawData']
                  as Map<String, dynamic>)['feedbackStatus'] =
              status;
        }
      });

      _applyFilters();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update feedback status: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _syncFeedbackDescriptionWithSelectedDoc() {
    if (_selectedDocId == null) {
      if (_lastLoadedFeedbackDocId != null) {
        _lastLoadedFeedbackDocId = null;
        _feedbackDescriptionController.clear();
      }
      return;
    }

    if (_lastLoadedFeedbackDocId != _selectedDocId) {
      _lastLoadedFeedbackDocId = _selectedDocId;
      final raw =
          (_selectedDocData?['rawData'] as Map<String, dynamic>?) ?? const {};
      final existingDesc = (raw['feedbackDescription'] ?? '').toString();
      _feedbackDescriptionController.value = TextEditingValue(
        text: existingDesc,
        selection: TextSelection.collapsed(offset: existingDesc.length),
      );
    }
  }

  Future<void> _saveFeedbackDescription() async {
    if (_selectedDocId == null || !_verifySelectedDocEditable()) return;

    final raw =
        (_selectedDocData?['rawData'] as Map<String, dynamic>?) ?? const {};
    final oldDesc = raw['feedbackDescription'];
    final newDesc = _feedbackDescriptionController.text.trim();
    final email =
        FirebaseAuth.instance.currentUser?.email ?? 'sales@skazo.com';

    setState(() {
      _isSavingFeedbackDescription = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('callLogs')
          .doc(_selectedDocId)
          .update({
            'feedbackDescription': newDesc,
            'lastFeedbackDescriptionUpdatedAt': FieldValue.serverTimestamp(),
            'lastFeedbackDescriptionUpdatedBy': email,
          });

      await _writeAuditLog(
        docId: _selectedDocId!,
        fieldName: 'feedbackDescription',
        oldValue: oldDesc,
        newValue: newDesc,
      );

      if (mounted) {
        setState(() {
          if (_selectedDocData != null && _selectedDocData!['rawData'] != null) {
            (_selectedDocData!['rawData']
                as Map<String, dynamic>)['feedbackDescription'] = newDesc;
          }
          for (final doc in _allDocs) {
            if (doc['id'] == _selectedDocId && doc['rawData'] != null) {
              (doc['rawData'] as Map<String, dynamic>)['feedbackDescription'] =
                  newDesc;
              break;
            }
          }
          _isSavingFeedbackDescription = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Feedback description saved successfully'),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSavingFeedbackDescription = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save feedback description: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _setCRMFollowUp() async {
    if (_selectedDocId == null || !_verifySelectedDocEditable()) return;

    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (date == null) return;

    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (time == null) return;

    final finalDateTime = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    final raw = _selectedDocData!['rawData'] ?? {};
    final oldStatus = raw['salesStatus'];
    final oldFollowUp = raw['followUpDate'];
    final email = FirebaseAuth.instance.currentUser?.email ?? 'admin@skazo.com';

    try {
      await FirebaseFirestore.instance
          .collection('callLogs')
          .doc(_selectedDocId)
          .update({
            'salesStatus': 'follow_up',
            'followUpDate': Timestamp.fromDate(finalDateTime),
            'lastSalesUpdatedAt': FieldValue.serverTimestamp(),
            'lastSalesUpdatedBy': email,
          });

      await _writeAuditLog(
        docId: _selectedDocId!,
        fieldName: 'salesStatus',
        oldValue: oldStatus,
        newValue: 'follow_up',
      );

      await _writeAuditLog(
        docId: _selectedDocId!,
        fieldName: 'followUpDate',
        oldValue: oldFollowUp,
        newValue: Timestamp.fromDate(finalDateTime),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Follow-up scheduled successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      _applyFilters();
      _fetchDashboardStats();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to schedule follow-up: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditFieldDialog(String fieldName, dynamic currentValue) {
    if (!_verifySelectedDocEditable()) return;
    if (!_canEditField(fieldName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Editing this field is restricted to Super Admin only.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return _EditFieldDialog(
          fieldName: fieldName,
          currentValue: currentValue,
          onSave: (newValue) async {
            if (!_verifySelectedDocEditable()) return;
            try {
              await FirebaseFirestore.instance
                  .collection('callLogs')
                  .doc(_selectedDocId)
                  .update({fieldName: newValue});

              await _writeAuditLog(
                docId: _selectedDocId!,
                fieldName: fieldName,
                oldValue: currentValue,
                newValue: newValue,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Successfully updated $fieldName'),
                  backgroundColor: Colors.green,
                ),
              );

              _applyFilters();
              _fetchDashboardStats();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to update field: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
      },
    );
  }

  void _showAddFieldDialog() {
    if (!_verifySelectedDocEditable()) return;
    if (!ref.read(cityAccessScopeProvider).isUnrestricted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Adding fields is restricted to Super Admin only.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return _AddFieldDialog(
          onSave: (fieldName, value) async {
            try {
              await FirebaseFirestore.instance
                  .collection('callLogs')
                  .doc(_selectedDocId)
                  .update({fieldName: value});

              await _writeAuditLog(
                docId: _selectedDocId!,
                fieldName: fieldName,
                oldValue: null,
                newValue: value,
              );

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Successfully added field: $fieldName'),
                  backgroundColor: Colors.green,
                ),
              );

              _applyFilters();
              _fetchDashboardStats();
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Failed to add field: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
        );
      },
    );
  }

  // --- UI Panels ---

  void _openFiltersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filters & Saved Views',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: Text(
                          'Done',
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(child: _buildLeftPanel()),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeftPanel() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section: Saved Views
          Text(
            'SAVED VIEWS',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color.fromARGB(255, 223, 8, 108),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          _buildSavedViewButton('Today Calls', Icons.calendar_today),
          _buildSavedViewButton('Pending Follow-ups', Icons.timer),
          _buildSavedViewButton('Interested Leads', Icons.star),
          // _buildSavedViewButton('Not Interested Leads', Icons.star),

          // _buildSavedViewButton('Not Called', Icons.phone_callback),
          _buildSavedViewButton('Converted', Icons.check_circle),
          // _buildSavedViewButton('Boost Calls', Icons.bolt),
          // _buildSavedViewButton('Paid Providers', Icons.payment),
          // _buildSavedViewButton('City-wise Leads', Icons.location_city),
          // const SizedBox(height: 24),

          // Section: Follow-up Reminders
          // Text(
          //   'REMINDERS',
          //   style: GoogleFonts.poppins(
          //     fontSize: 11,
          //     fontWeight: FontWeight.w700,
          //     color: const Color(0xFF64748B),
          //     letterSpacing: 1.1,
          //   ),
          // ),
          // const SizedBox(height: 8),
          // _buildReminderChip(
          //   'Follow-up Today',
          //   _countFollowUpToday,
          //   Colors.purple,
          // ),
          // _buildReminderChip(
          //   'Overdue Follow-ups',
          //   _countFollowUpOverdue,
          //   Colors.red,
          // ),
          // _buildReminderChip(
          //   'Tomorrow Follow-ups',
          //   _countFollowUpTomorrow,
          //   Colors.orange,
          // ),
          // const SizedBox(height: 24),

          // Section: Smart Filters
          Text(
            'CRM FILTERS',
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color.fromARGB(255, 223, 8, 108),
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          _buildLeftDropdownFilter(
            'Date Range',
            _dateFilter,
            ['All', 'Today', 'Yesterday', 'Last 7 Days', 'Last 30 Days'],
            (val) {
              setState(() {
                _dateFilter = val;
                _currentPage = 0;
              });
              _subscribeToLogs();
            },
          ),
          if (ref.watch(isSuperAdminProvider)) ...[
            ref
                .watch(allowedCitiesProvider)
                .when(
                  data: (cities) {
                    final dropdownCities = ['All Cities', ...cities];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'City Scope 🌆',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withValues(alpha: 0.2),
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedCity ?? 'All Cities',
                              isExpanded: true,
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: const Color(0xFF0F172A),
                              ),
                              items:
                                  dropdownCities.map((city) {
                                    return DropdownMenuItem(
                                      value: city,
                                      child: Text(
                                        city,
                                        style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          fontWeight:
                                              (city == _selectedCity ||
                                                      (_selectedCity == null &&
                                                          city == 'All Cities'))
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedCity =
                                      (val == null || val == 'All Cities')
                                          ? null
                                          : val;
                                  _currentPage = 0;
                                });
                                _applyFilters();
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    );
                  },
                  loading:
                      () => const SizedBox(
                        height: 20,
                        child: LinearProgressIndicator(),
                      ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
          ] else ...[
            Builder(
              builder: (context) {
                final assigned = ref.watch(currentAdminAssignedCitiesProvider);
                if (assigned.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assigned City 🌆',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on,
                            size: 16,
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              assigned.join(', '),
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                );
              },
            ),
          ],
          _buildLeftSearchTextField(
            'Category',
            _categoryController,
            Icons.category,
          ),
          const SizedBox(height: 12),
          _buildLeftSearchTextField(
            'Business Name',
            _businessNameController,
            Icons.business,
          ),
          const SizedBox(height: 12),
          _buildLeftSearchTextField(
            'Customer Phone',
            _customerPhoneController,
            Icons.person_outline,
          ),
          const SizedBox(height: 12),
          _buildLeftSearchTextField(
            'Provider Phone',
            _providerPhoneController,
            Icons.phone_android,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _searchController.clear();
                _cityController.clear();
                _selectedCity = null;
                _categoryController.clear();
                _businessNameController.clear();
                _customerPhoneController.clear();
                _providerPhoneController.clear();
                _assignedPersonController.clear();
                _dateFilter = 'All';
                _filterPlan = 'All';
                _activeSavedView = null;
                _currentPage = 0;
              });
              _subscribeToLogs();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF1F5F9),
              foregroundColor: const Color(0xFF475569),
              elevation: 0,
              minimumSize: const Size(double.infinity, 40),
            ),
            child: Text(
              'Reset Filters',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavedViewButton(String label, IconData icon) {
    final isSelected = _activeSavedView == label;
    return InkWell(
      onTap: () {
        setState(() {
          _activeSavedView = isSelected ? null : label;
          _currentPage = 0;
        });
        _applyFilters();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color:
                  isSelected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      isSelected
                          ? const Color(0xFF1E40AF)
                          : const Color(0xFF334155),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReminderChip(String label, int count, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftSearchTextField(
    String label,
    TextEditingController controller,
    IconData icon,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search $label...',
            prefixIcon: Icon(icon, size: 16),
            isDense: true,
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.withOpacity(0.2)),
            ),
          ),
          style: GoogleFonts.poppins(fontSize: 13),
          onChanged: (_) {
            setState(() {
              _currentPage = 0;
            });
            _applyFilters();
          },
        ),
      ],
    );
  }

  Widget _buildLeftDropdownFilter(
    String label,
    String value,
    List<String> items,
    Function(String) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: const Color(0xFF475569),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              items:
                  items.map((item) {
                    return DropdownMenuItem(value: item, child: Text(item));
                  }).toList(),
              onChanged: (val) {
                if (val != null) onChanged(val);
              },
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF0F172A),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMiddlePanel({bool showFilterButton = false}) {
    if (_errorMessage != null) {
      return Center(child: Text('Error: $_errorMessage'));
    }

    return Column(
      children: [
        // Quick search box (+ Filters button on tablet/mobile)
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Quick search (ID, customer, phone)...',
                    prefixIcon: const Icon(Icons.search, size: 18),
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: Colors.grey.withOpacity(0.2),
                      ),
                    ),
                  ),
                  style: GoogleFonts.poppins(fontSize: 13),
                  onChanged: (_) {
                    setState(() {
                      _currentPage = 0;
                    });
                    _applyFilters();
                  },
                ),
              ),
              if (showFilterButton) ...[
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: _openFiltersSheet,
                  icon: const Icon(Icons.tune_rounded, size: 16),
                  label: Text(
                    'Filters',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2563EB),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _cityController.text.trim().isNotEmpty
                      ? 'Calls for "${_cityController.text.trim()}": $_totalMatches'
                      : 'Matching Calls: $_totalMatches',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (_totalMatches > 0) ...[
                const SizedBox(width: 8),
                Text(
                  'Showing ${_currentPageLogs.length} of $_totalMatches',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),

        // List
        Expanded(
          child:
              _isLoading && _currentPageLogs.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : _currentPageLogs.isEmpty
                  ? Center(
                    child: Text(
                      'No matching logs found',
                      style: GoogleFonts.poppins(color: Colors.grey),
                    ),
                  )
                  : ListView.separated(
                    itemCount: _currentPageLogs.length,
                    separatorBuilder:
                        (context, index) => const Divider(height: 1),
                    itemBuilder:
                        (context, index) =>
                            _buildCallLogCard(_currentPageLogs[index]),
                  ),
        ),

        const Divider(height: 1),
        // Pagination
        _buildListPaginationControls(),
      ],
    );
  }

  Widget _buildCallLogCard(Map<String, dynamic> log) {
    final docId = log['id'];
    final isSelected = docId == _selectedDocId;
    final bName = log['businessName'] ?? '';
    final cName = log['customerName'] ?? '';
    final phone = log['phone'] ?? '';
    final city = log['city'] ?? '';
    final timeStr = _formatTimestamp(log['timestamp']);

    final raw = log['rawData'] ?? {};

    // final salesStatus = raw['salesStatus'] ?? 'new';
    final leadQuality = raw['leadQuality'];
    // final plan = raw['plan'] ?? 'free';

    return InkWell(
      onTap: () {
        setState(() {
          _selectedDocId = docId;
          _selectedDocData = log;
          _showMobileDetail = true;
          _syncFeedbackDescriptionWithSelectedDoc();
        });
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
          border: Border(
            left: BorderSide(
              color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
              width: 4,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    docId,
                    style: GoogleFonts.sourceCodePro(
                      fontSize: 11,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color:
                          isSelected
                              ? const Color(0xFF1E40AF)
                              : const Color(0xFF475569),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  timeStr.toString(),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color.fromARGB(255, 218, 13, 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              bName.isNotEmpty ? bName : 'No Business Name',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: const Color(0xFF0F172A),
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (cName.isNotEmpty)
              Text(
                'Customer: $cName',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                ),
              ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.phone, size: 12, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      phone,
                      style: GoogleFonts.sourceCodePro(
                        fontSize: 12,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                if (city.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      city,
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                if (raw['feedbackStatus'] != null &&
                    raw['feedbackStatus'].toString().isNotEmpty)
                  _buildBadge(
                    'FEEDBACK: ${raw['feedbackStatus'].toString().toUpperCase()}',
                    _getFeedbackStatusColor(raw['feedbackStatus'].toString()),
                  ),
                if (leadQuality != null)
                  _buildBadge(
                    '${leadQuality.toString().toUpperCase()} LEAD',
                    _getLeadQualityColor(leadQuality),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getFeedbackStatusColor(String status) {
    final norm = status.trim().toLowerCase();
    if (norm == 'converted') return const Color(0xFF10B981);
    if (norm == 'not converted' || norm == 'not converetd')
      return const Color(0xFFEF4444);
    return const Color(0xFF64748B);
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getSalesStatusColor(dynamic status) {
    switch (status?.toString().toLowerCase()) {
      case 'interested':
        return Colors.teal;
      case 'converted':
        return Colors.green;
      case 'not_interested':
        return Colors.grey[600]!;
      case 'follow_up':
        return Colors.purple;
      case 'called':
        return Colors.blue;
      case 'new':
      default:
        return Colors.blueGrey;
    }
  }

  Color _getLeadQualityColor(dynamic quality) {
    switch (quality?.toString().toLowerCase()) {
      case 'hot':
        return Colors.red;
      case 'warm':
        return Colors.orange;
      case 'cold':
      default:
        return Colors.blue;
    }
  }

  Color _getPlanColor(dynamic plan) {
    switch (plan?.toString().toLowerCase()) {
      case 'premium':
        return Colors.amber[700]!;
      case '599':
        return Colors.orange;
      case 'paid':
        return Colors.green;
      case 'free':
      default:
        return Colors.grey;
    }
  }

  Widget _buildListPaginationControls() {
    final totalPages = (_totalMatches / _pageSize).ceil();
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Page ${_currentPage + 1} of $totalPages',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF475569),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed:
                        _currentPage == 0 || _isLoading
                            ? null
                            : () {
                              setState(() {
                                _currentPage -= 1;
                              });
                              _applyFilters();
                            },
                    icon: const Icon(Icons.chevron_left, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed:
                        !_hasNextPage || _isLoading
                            ? null
                            : () {
                              setState(() {
                                _currentPage += 1;
                              });
                              _applyFilters();
                            },
                    icon: const Icon(Icons.chevron_right, size: 20),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _buildPageButtons(totalPages),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageButtons(int totalPages) {
    List<Widget> buttons = [];
    int start = _currentPage - 2;
    int end = _currentPage + 2;

    if (start < 0) {
      end += (0 - start);
      start = 0;
    }
    if (end >= totalPages) {
      start -= (end - totalPages + 1);
      if (start < 0) start = 0;
      end = totalPages - 1;
    }

    if (start > 0) {
      buttons.add(_buildPageButton(0, '1'));
      if (start > 1) {
        buttons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: Text('...'),
          ),
        );
      }
    }

    for (int i = start; i <= end; i++) {
      buttons.add(_buildPageButton(i, '${i + 1}'));
    }

    if (end < totalPages - 1) {
      if (end < totalPages - 2) {
        buttons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.0),
            child: Text('...'),
          ),
        );
      }
      buttons.add(_buildPageButton(totalPages - 1, '$totalPages'));
    }

    return buttons;
  }

  Widget _buildPageButton(int pageIndex, String label) {
    final isSelected = pageIndex == _currentPage;
    return InkWell(
      onTap:
          _isLoading
              ? null
              : () {
                setState(() {
                  _currentPage = pageIndex;
                });
                _applyFilters();
              },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color:
                isSelected
                    ? const Color(0xFF2563EB)
                    : Colors.grey.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: isSelected ? Colors.white : const Color(0xFF0F172A),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildRightPanel({
    bool showBackButton = false,
    bool useScrollableBody = false,
  }) {
    if (_selectedDocId == null) {
      if (_lastLoadedFeedbackDocId != null) {
        _lastLoadedFeedbackDocId = null;
        _feedbackDescriptionController.clear();
      }
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'Select a document to view details',
              style: GoogleFonts.poppins(fontSize: 15, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    _syncFeedbackDescriptionWithSelectedDoc();

    final screenHeight = MediaQuery.of(context).size.height;
    final isShortScreen = screenHeight < 600;
    final bool effectiveUseScrollableBody = useScrollableBody || isShortScreen;

    final rawData = _selectedDocData!['rawData'] as Map<String, dynamic>? ?? {};
    final sortedKeys = rawData.keys.toList()..sort();

    final backBar = showBackButton
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
              ),
            ),
            child: InkWell(
              onTap: () => setState(() => _showMobileDetail = false),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Back to Call Logs',
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
        : const SizedBox.shrink();

    final fieldsList = sortedKeys.isEmpty
        ? Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Text(
                'No fields in this document',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
          )
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            shrinkWrap: effectiveUseScrollableBody,
            physics: effectiveUseScrollableBody
                ? const NeverScrollableScrollPhysics()
                : null,
            itemCount: sortedKeys.length,
            separatorBuilder: (context, index) => const Divider(height: 12),
            itemBuilder: (context, index) {
              final key = sortedKeys[index];
              final val = rawData[key];
              return CollapsibleFieldView(
                label: key,
                value: val,
                onEdit: () => _showEditFieldDialog(key, val),
              );
            },
          );

    final docHeaderAndControls = <Widget>[
      // Doc Header
      Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DOCUMENT PATH',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF64748B),
                      letterSpacing: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'callLogs / ',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _selectedDocId!,
                          style: GoogleFonts.sourceCodePro(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF0F172A),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(
                Icons.copy,
                size: 18,
                color: Color(0xFF2563EB),
              ),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _selectedDocId!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Document ID copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              tooltip: 'Copy ID',
            ),
          ],
        ),
      ),

      /*
      // CRM QUICK ACTIONS (Replaced by SALES FEEDBACK DESCRIPTION)
      Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CRM QUICK ACTIONS',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildActionButton(
                  'Mark Interested',
                  Icons.star,
                  Colors.teal,
                  () => _changeCRMStatus('interested'),
                ),
                _buildActionButton(
                  'Mark Not Interested',
                  Icons.star_border,
                  Colors.grey,
                  () => _changeCRMStatus('not_interested'),
                ),
                _buildActionButton(
                  'Set Follow-up',
                  Icons.alarm,
                  Colors.purple,
                  _setCRMFollowUp,
                ),
                _buildActionButton(
                  'Mark Converted',
                  Icons.check_circle_outline,
                  Colors.green,
                  () => _changeCRMStatus('converted'),
                ),
              ],
            ),
          ],
        ),
      ),
      */

      // SALES FEEDBACK DESCRIPTION
      Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.rate_review_outlined,
                  color: Color(0xFF2563EB),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'SALES FEEDBACK DESCRIPTION',
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF2563EB),
                      letterSpacing: 1.1,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _feedbackDescriptionController,
              maxLines: 4,
              minLines: 3,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: const Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                labelText: 'Feedback Description',
                labelStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF64748B),
                ),
                hintText: 'Enter sales feedback details here...',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF94A3B8),
                ),
                alignLabelWithHint: true,
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                    color: Color(0xFF2563EB),
                    width: 1.5,
                  ),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: _isSavingFeedbackDescription
                    ? null
                    : _saveFeedbackDescription,
                icon: _isSavingFeedbackDescription
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: Text(
                  _isSavingFeedbackDescription
                      ? 'Saving...'
                      : 'Save Feedback',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Sales Feedback Status Dropdown
      Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          border: Border(
            bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.rate_review_rounded,
                  color: Color(0xFF6366F1),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Text(
                  'SALES FEEDBACK STATUS',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF6366F1),
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: () {
                    final current =
                        rawData['feedbackStatus']
                            ?.toString()
                            .toLowerCase()
                            .trim();
                    if (current == 'converted') return 'converted';
                    if (current == 'not converted' ||
                        current == 'not converetd') {
                      return 'not converted';
                    }
                    if (current == 'skip') return 'skip';
                    return 'skip';
                  }(),
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Color(0xFF6366F1),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'converted',
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: Color(0xFF10B981),
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'converted',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'not converted',
                      child: Row(
                        children: [
                          Icon(
                            Icons.cancel_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'not converted',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'skip',
                      child: Row(
                        children: [
                          Icon(
                            Icons.redo_rounded,
                            color: Color(0xFF64748B),
                            size: 18,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'skip',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (newStatus) {
                    if (newStatus != null) {
                      _updateFeedbackStatus(newStatus);
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),

      // Add Field Row (Preceded by Add field)
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFFF1F5F9),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FIELDS',
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF64748B),
                letterSpacing: 1.1,
              ),
            ),
            if (_userRole == 'Super Admin')
              TextButton.icon(
                icon: const Icon(
                  Icons.add,
                  size: 16,
                  color: Color(0xFF2563EB),
                ),
                label: Text(
                  'Add field',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF2563EB),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: _showAddFieldDialog,
              ),
          ],
        ),
      ),
    ];

    if (effectiveUseScrollableBody) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showBackButton) backBar,
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...docHeaderAndControls,
                  fieldsList,
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showBackButton) backBar,
        ...docHeaderAndControls,
        // Fields list
        Expanded(child: fieldsList),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        textStyle: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: BorderSide(color: color.withOpacity(0.2)),
        ),
      ),
    );
  }

  Widget _buildTopHeader(CallLogsSubView activeSubView) {
    final isMobile = ResponsiveBreakpoints.isMobile(context);

    final titleAndRole = Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'CRM Call Logs',
          style: GoogleFonts.poppins(
            fontSize: isMobile ? 19 : 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        _buildSubViewToggle(activeSubView),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            _userRole,
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF475569),
            ),
          ),
        ),
      ],
    );

    final statsWrap = Wrap(
      spacing: isMobile ? 8 : 14,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildStatBadge(
          'Overall Calls',
          _statOverallCalls,
          const Color(0xFF3B82F6),
          const Color(0xFFEFF6FF),
        ),
        // _buildStatBadge(
        //   'Overall Leads',
        //   _statOverallLeads,
        //   const Color(0xFF0284C7),
        //   const Color(0xFFE0F2FE),
        // ),
        _buildStatBadge(
          'Converted',
          _statConverted,
          const Color(0xFF10B981),
          const Color(0xFFECFDF5),
        ),
        _buildStatBadge(
          'Today Calls',
          _statTodayCalls,
          const Color(0xFFF59E0B),
          const Color(0xFFFFFBEB),
        ),
        _buildStatBadge(
          'Interested',
          _statInterested,
          const Color(0xFF8B5CF6),
          const Color(0xFFF5F3FF),
        ),
        _buildStatBadge(
          'Follow-ups Due',
          _statFollowUpsDue,
          const Color(0xFFEC4899),
          const Color(0xFFFDF2F8),
        ),
        IconButton(
          icon: const Icon(Icons.refresh, color: Color(0xFF475569)),
          onPressed: _resetAndLoad,
          tooltip: 'Reload all data',
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: isMobile ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withOpacity(0.15)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 940) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleAndRole,
                if (activeSubView == CallLogsSubView.crmCallLogs) ...[
                  const SizedBox(height: 10),
                  statsWrap,
                ],
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              titleAndRole,
              if (activeSubView == CallLogsSubView.crmCallLogs) ...[
                const SizedBox(width: 16),
                Flexible(child: statsWrap),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Toggle switcher between CRM Call Logs and Call Logs Details
  Widget _buildSubViewToggle(CallLogsSubView activeSubView) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSubViewButton(
            title: 'CRM Call Logs',
            icon: Icons.support_agent_rounded,
            isSelected: activeSubView == CallLogsSubView.crmCallLogs,
            onTap: () {
              if (activeSubView != CallLogsSubView.crmCallLogs) {
                ref.read(callLogsActiveSubViewProvider.notifier).state =
                    CallLogsSubView.crmCallLogs;
              }
            },
          ),
          const SizedBox(width: 4),
          _buildSubViewButton(
            title: 'Call Logs Details',
            icon: Icons.table_chart_rounded,
            isSelected: activeSubView == CallLogsSubView.callLogsDetails,
            onTap: () {
              if (activeSubView != CallLogsSubView.callLogsDetails) {
                ref.read(callLogsActiveSubViewProvider.notifier).state =
                    CallLogsSubView.callLogsDetails;
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSubViewButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(
    String label,
    int value,
    Color textColor,
    Color bgColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: textColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: textColor.withOpacity(0.8),
            ),
          ),
          Text(
            value.toString(),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSubView = ref.watch(callLogsActiveSubViewProvider);
    ref.watch(cityAccessScopeProvider);
    ref.listen(cityAccessScopeProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyFilters();
      });
    });
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildTopHeader(activeSubView),
          Expanded(
            child: IndexedStack(
              index: activeSubView == CallLogsSubView.crmCallLogs ? 0 : 1,
              children: [
                _buildCrmLogsContent(),
                const CallLogsDetailDataView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCrmLogsContent() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Desktop (>= 1060px content width): preserve 3-pane workspace
        if (constraints.maxWidth >= 1060) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Column 1: Filters & Saved Views
              Container(
                width: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(
                      color: Colors.grey.withOpacity(0.15),
                    ),
                  ),
                ),
                child: _buildLeftPanel(),
              ),

              // Column 2: Call Logs List
              Container(
                width: 380,
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    right: BorderSide(
                      color: Colors.grey.withOpacity(0.15),
                    ),
                  ),
                ),
                child: _buildMiddlePanel(),
              ),

              // Column 3: Document Details
              Expanded(
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  child: _buildRightPanel(),
                ),
              ),
            ],
          );
        }

        // Tablet / Compact Split (680-1059px): Filter sheet + 2 panes
        if (constraints.maxWidth >= 680) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      right: BorderSide(
                        color: Colors.grey.withOpacity(0.15),
                      ),
                    ),
                  ),
                  child: _buildMiddlePanel(showFilterButton: true),
                ),
              ),
              Expanded(
                flex: 5,
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  child: _buildRightPanel(),
                ),
              ),
            ],
          );
        }

        // Mobile (< 680px): 1-pane Master -> Detail navigation
        if (_showMobileDetail && _selectedDocId != null) {
          return Container(
            color: const Color(0xFFF8FAFC),
            child: _buildRightPanel(
              showBackButton: true,
              useScrollableBody: true,
            ),
          );
        }

        return Container(
          color: Colors.white,
          child: _buildMiddlePanel(showFilterButton: true),
        );
      },
    );
  }
}

// Collapsible Field Item (Firebase inspector style)
class CollapsibleFieldView extends StatefulWidget {
  final String label;
  final dynamic value;
  final VoidCallback onEdit;

  const CollapsibleFieldView({
    super.key,
    required this.label,
    required this.value,
    required this.onEdit,
  });

  @override
  State<CollapsibleFieldView> createState() => _CollapsibleFieldViewState();
}

class _CollapsibleFieldViewState extends State<CollapsibleFieldView> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final isMap = value is Map;
    final isList = value is List;

    if (!isMap && !isList) {
      return _buildLeafNode();
    }

    final childCount = isMap ? value.length : value.length;
    final labelText =
        '${widget.label} (${isMap ? "Map" : "Array"}, $childCount items)';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: Icon(
                _isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                size: 20,
                color: Colors.grey[600],
              ),
              onPressed: () {
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                labelText,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: const Color(0xFF475569),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              isMap ? '{ }' : '[ ]',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(
                Icons.copy_rounded,
                size: 14,
                color: Color(0xFF64748B),
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                String copyText;
                try {
                  copyText = jsonEncode(widget.value);
                } catch (_) {
                  copyText = widget.value.toString();
                }
                Clipboard.setData(ClipboardData(text: copyText));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied "${widget.label}" JSON to clipboard'),
                    duration: const Duration(seconds: 1),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              tooltip: 'Copy JSON',
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 14, color: Colors.blue),
              onPressed: widget.onEdit,
              tooltip: 'Edit JSON',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24.0, top: 4.0),
            child: _buildNestedContainer(value),
          ),
      ],
    );
  }

  Widget _buildNestedContainer(dynamic val) {
    if (val is Map) {
      final sortedKeys = val.keys.toList()..sort();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            sortedKeys.map((key) {
              final subVal = val[key];
              return CollapsibleFieldView(
                label: key.toString(),
                value: subVal,
                onEdit: widget.onEdit, // edits parent JSON
              );
            }).toList(),
      );
    } else if (val is List) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(val.length, (index) {
          final subVal = val[index];
          return CollapsibleFieldView(
            label: '[$index]',
            value: subVal,
            onEdit: widget.onEdit,
          );
        }),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildLeafNode() {
    Widget valueWidget;
    String typeLabel = '';
    Color typeColor = Colors.grey;
    IconData typeIcon = Icons.help_outline;

    final val = widget.value;
    if (val is String) {
      typeLabel = 'string';
      typeColor = Colors.green[700]!;
      typeIcon = Icons.title;
      valueWidget = Text(
        '"$val"',
        style: GoogleFonts.sourceCodePro(
          color: Colors.green[800],
          fontSize: 12,
        ),
      );
    } else if (val is num) {
      typeLabel = 'number';
      typeColor = Colors.orange[800]!;
      typeIcon = Icons.pin;
      valueWidget = Text(
        val.toString(),
        style: GoogleFonts.sourceCodePro(
          color: Colors.orange[800],
          fontSize: 12,
        ),
      );
    } else if (val is bool) {
      typeLabel = 'boolean';
      typeColor = Colors.purple[700]!;
      typeIcon = Icons.toggle_on;
      valueWidget = Text(
        val.toString(),
        style: GoogleFonts.sourceCodePro(
          color: Colors.purple[800],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    } else if (val is Timestamp) {
      typeLabel = 'timestamp';
      typeColor = Colors.red[700]!;
      typeIcon = Icons.calendar_today;
      valueWidget = Text(
        _formatDetailedTimestamp(val),
        style: GoogleFonts.sourceCodePro(color: Colors.red[800], fontSize: 12),
      );
    } else if (val == null) {
      typeLabel = 'null';
      typeColor = Colors.grey[600]!;
      typeIcon = Icons.block;
      valueWidget = Text(
        'null',
        style: GoogleFonts.sourceCodePro(
          color: Colors.grey[600],
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    } else {
      typeLabel = val.runtimeType.toString().toLowerCase();
      typeIcon = Icons.info_outline;
      valueWidget = Text(
        val.toString(),
        style: GoogleFonts.sourceCodePro(fontSize: 12),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Tooltip(
            message: typeLabel,
            child: Icon(typeIcon, size: 14, color: typeColor.withOpacity(0.7)),
          ),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 145),
            child: Text(
              '${widget.label}:',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: const Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: valueWidget),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(
              Icons.copy_rounded,
              size: 14,
              color: Color(0xFF64748B),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              final val = widget.value;
              final strVal =
                  val is Timestamp
                      ? _formatDetailedTimestamp(val)
                      : (val?.toString() ?? '');
              Clipboard.setData(ClipboardData(text: strVal));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Copied "${widget.label}" value to clipboard'),
                  duration: const Duration(seconds: 1),
                  backgroundColor: const Color(0xFF10B981),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            tooltip: 'Copy value',
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.edit, size: 14, color: Colors.blue),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: widget.onEdit,
            tooltip: 'Edit field',
          ),
        ],
      ),
    );
  }

  String _formatDetailedTimestamp(Timestamp timestamp) {
    final dateTime = timestamp.toDate();
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final month = months[dateTime.month - 1];
    final day = dateTime.day.toString().padLeft(2, '0');
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final second = dateTime.second.toString().padLeft(2, '0');

    final timezoneOffset = dateTime.timeZoneOffset;
    final offsetSign = timezoneOffset.isNegative ? '-' : '+';
    final offsetHours = timezoneOffset.inHours.abs().toString().padLeft(2, '0');
    final offsetMinutes = (timezoneOffset.inMinutes.abs() % 60)
        .toString()
        .padLeft(2, '0');
    final offsetStr = 'UTC$offsetSign$offsetHours:$offsetMinutes';

    return '$day $month $year at $hour:$minute:$second $offsetStr';
  }
}

// Field editor modal
class _EditFieldDialog extends StatefulWidget {
  final String fieldName;
  final dynamic currentValue;
  final Function(dynamic newValue) onSave;

  const _EditFieldDialog({
    required this.fieldName,
    required this.currentValue,
    required this.onSave,
  });

  @override
  State<_EditFieldDialog> createState() => _EditFieldDialogState();
}

class _EditFieldDialogState extends State<_EditFieldDialog> {
  late dynamic _value;
  final _textController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _jsonError;
  late DateTime _selectedDateTime;

  @override
  void initState() {
    super.initState();
    _value = widget.currentValue;
    if (_value is! bool && _value is! Timestamp && _value != null) {
      if (_value is Map || _value is List) {
        _textController.text = const JsonEncoder.withIndent(
          '  ',
        ).convert(_value);
      } else {
        _textController.text = _value.toString();
      }
    } else if (_value is Timestamp) {
      _selectedDateTime = (_value as Timestamp).toDate();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: ResponsiveBreakpoints.dialogInsetPadding(context),
      title: Text(
        'Edit Field: ${widget.fieldName}',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveBreakpoints.dialogMaxWidth(
            context,
            desktopMaxWidth: 460,
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Type: ${_getFieldTypeLabel()}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInputWidget(),
                if (_jsonError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _jsonError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: Colors.grey[700]),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_validateAndSave()) {
              widget.onSave(_value);
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Save',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  String _getFieldTypeLabel() {
    if (widget.currentValue is String) return 'String';
    if (widget.currentValue is num) return 'Number';
    if (widget.currentValue is bool) return 'Boolean';
    if (widget.currentValue is Timestamp) return 'Timestamp';
    if (widget.currentValue is Map) return 'Map';
    if (widget.currentValue is List) return 'Array';
    return 'String';
  }

  Widget _buildInputWidget() {
    if (widget.currentValue is bool) {
      return Row(
        children: [
          Text('Value: ', style: GoogleFonts.poppins()),
          Switch(
            value: _value as bool,
            onChanged: (val) {
              setState(() {
                _value = val;
              });
            },
            activeThumbColor: const Color(0xFF2563EB),
          ),
          Text(
            _value.toString(),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    if (widget.currentValue is Timestamp) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Date & Time (Local):',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedDateTime.toLocal().toString().split('.').first,
              style: GoogleFonts.sourceCodePro(fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Pick Date'),
                onPressed: _pickDate,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 16),
                label: const Text('Pick Time'),
                onPressed: _pickTime,
              ),
            ],
          ),
        ],
      );
    }

    final isJSON = widget.currentValue is Map || widget.currentValue is List;
    return TextFormField(
      controller: _textController,
      maxLines: isJSON ? 8 : 2,
      minLines: isJSON ? 4 : 1,
      keyboardType:
          widget.currentValue is num
              ? TextInputType.number
              : TextInputType.multiline,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: isJSON ? 'Enter valid JSON' : 'Enter value',
        labelText: 'Value',
      ),
      style:
          isJSON
              ? GoogleFonts.sourceCodePro(fontSize: 13)
              : GoogleFonts.poppins(),
      validator: (val) {
        if (val == null || val.isEmpty) {
          return 'Value cannot be empty';
        }
        if (widget.currentValue is num) {
          if (double.tryParse(val) == null) {
            return 'Please enter a valid number';
          }
        }
        return null;
      },
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
          _selectedDateTime.second,
        );
        _value = Timestamp.fromDate(_selectedDateTime);
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          time.hour,
          time.minute,
        );
        _value = Timestamp.fromDate(_selectedDateTime);
      });
    }
  }

  bool _validateAndSave() {
    setState(() {
      _jsonError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (widget.currentValue is bool) {
      return true;
    }

    if (widget.currentValue is Timestamp) {
      return true;
    }

    final textVal = _textController.text.trim();
    if (widget.currentValue is num) {
      _value = num.parse(textVal);
      return true;
    }

    if (widget.currentValue is Map || widget.currentValue is List) {
      try {
        _value = jsonDecode(textVal);
        return true;
      } catch (e) {
        setState(() {
          _jsonError = 'Invalid JSON: $e';
        });
        return false;
      }
    }

    _value = textVal;
    return true;
  }
}

// Field adder modal
class _AddFieldDialog extends StatefulWidget {
  final Function(String fieldName, dynamic value) onSave;

  const _AddFieldDialog({required this.onSave});

  @override
  State<_AddFieldDialog> createState() => _AddFieldDialogState();
}

class _AddFieldDialogState extends State<_AddFieldDialog> {
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'string';
  bool _boolValue = false;
  DateTime _selectedDateTime = DateTime.now();
  String? _jsonError;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: ResponsiveBreakpoints.dialogInsetPadding(context),
      title: Text(
        'Add Field',
        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: ResponsiveBreakpoints.dialogMaxWidth(
            context,
            desktopMaxWidth: 460,
          ),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Field name',
                    hintText: 'e.g. salesRemark',
                  ),
                  style: GoogleFonts.poppins(),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Field name cannot be empty';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedType,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    labelText: 'Type',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'string', child: Text('string')),
                    DropdownMenuItem(value: 'number', child: Text('number')),
                    DropdownMenuItem(value: 'boolean', child: Text('boolean')),
                    DropdownMenuItem(
                      value: 'timestamp',
                      child: Text('timestamp'),
                    ),
                    DropdownMenuItem(value: 'map', child: Text('map')),
                    DropdownMenuItem(value: 'array', child: Text('array')),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedType = val;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                _buildValueInput(),
                if (_jsonError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      _jsonError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: Colors.grey[700]),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            if (_validateAndSave()) {
              final fieldName = _nameController.text.trim();
              dynamic val;
              if (_selectedType == 'boolean') {
                val = _boolValue;
              } else if (_selectedType == 'timestamp') {
                val = Timestamp.fromDate(_selectedDateTime);
              } else if (_selectedType == 'number') {
                val = num.parse(_valueController.text.trim());
              } else if (_selectedType == 'map' || _selectedType == 'array') {
                val = jsonDecode(_valueController.text.trim());
              } else {
                val = _valueController.text.trim();
              }
              widget.onSave(fieldName, val);
              Navigator.of(context).pop();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Add',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildValueInput() {
    if (_selectedType == 'boolean') {
      return Row(
        children: [
          Text('Value: ', style: GoogleFonts.poppins()),
          Switch(
            value: _boolValue,
            onChanged: (val) {
              setState(() {
                _boolValue = val;
              });
            },
            activeThumbColor: const Color(0xFF2563EB),
          ),
          Text(
            _boolValue.toString(),
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    if (_selectedType == 'timestamp') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Date & Time (Local):',
            style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.3)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _selectedDateTime.toLocal().toString().split('.').first,
              style: GoogleFonts.sourceCodePro(fontSize: 14),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Pick Date'),
                onPressed: _pickDate,
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.access_time, size: 16),
                label: const Text('Pick Time'),
                onPressed: _pickTime,
              ),
            ],
          ),
        ],
      );
    }

    final isJSON = _selectedType == 'map' || _selectedType == 'array';
    return TextFormField(
      controller: _valueController,
      maxLines: isJSON ? 6 : 2,
      minLines: isJSON ? 3 : 1,
      keyboardType:
          _selectedType == 'number'
              ? TextInputType.number
              : TextInputType.multiline,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText:
            isJSON
                ? (_selectedType == 'map'
                    ? 'e.g. {"key": "value"}'
                    : 'e.g. ["item1", "item2"]')
                : 'Enter field value',
        labelText: 'Value',
      ),
      style:
          isJSON
              ? GoogleFonts.sourceCodePro(fontSize: 13)
              : GoogleFonts.poppins(),
      validator: (val) {
        if (_selectedType != 'boolean' && _selectedType != 'timestamp') {
          if (val == null || val.trim().isEmpty) {
            return 'Value cannot be empty';
          }
          if (_selectedType == 'number') {
            if (double.tryParse(val) == null) {
              return 'Please enter a valid number';
            }
          }
        }
        return null;
      },
    );
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (date != null) {
      setState(() {
        _selectedDateTime = DateTime(
          date.year,
          date.month,
          date.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
          _selectedDateTime.second,
        );
      });
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  bool _validateAndSave() {
    setState(() {
      _jsonError = null;
    });

    if (!_formKey.currentState!.validate()) {
      return false;
    }

    if (_selectedType == 'map' || _selectedType == 'array') {
      try {
        final textVal = _valueController.text.trim();
        final decoded = jsonDecode(textVal);
        if (_selectedType == 'map' && decoded is! Map) {
          setState(() {
            _jsonError = 'Value must be a valid JSON object (Map)';
          });
          return false;
        }
        if (_selectedType == 'array' && decoded is! List) {
          setState(() {
            _jsonError = 'Value must be a valid JSON array (List)';
          });
          return false;
        }
      } catch (e) {
        setState(() {
          _jsonError = 'Invalid JSON: $e';
        });
        return false;
      }
    }

    return true;
  }
}
