import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/constants/hyderabad_area_groups.dart';
import 'package:skazo_admin/utils/city_resolver.dart';

/// Typed representation of a single Call Log record combined with its
/// associated Service Provider information from the `users` collection.
class CallLogsDetailItem {
  final String callLogId;
  final String businessId; // Provider UID / Business ID
  final String businessName;
  final String businessPhone;
  final String callerPhone;
  final String? customerName;
  final String city;
  final String category;
  final DateTime? timestamp;
  final int callsAfterPayment;
  final String? callStatus;
  final String? feedbackStatus;
  final String? pincode;
  final Map<String, dynamic> callLogRawData;
  final Map<String, dynamic>? userRawData;

  const CallLogsDetailItem({
    required this.callLogId,
    required this.businessId,
    required this.businessName,
    required this.businessPhone,
    this.callerPhone = '',
    this.customerName,
    required this.city,
    required this.category,
    this.timestamp,
    this.callsAfterPayment = 0,
    this.callStatus,
    this.feedbackStatus,
    this.pincode,
    this.callLogRawData = const {},
    this.userRawData,
  });

  /// Formatted call date (e.g. "14 Nov 2026")
  String get formattedCallDate {
    if (timestamp == null) return '--';
    try {
      return DateFormat('dd MMM yyyy').format(timestamp!.toLocal());
    } catch (_) {
      return '--';
    }
  }

  /// Formatted call time (e.g. "04:30 PM")
  String get formattedCallTime {
    if (timestamp == null) return '--';
    try {
      return DateFormat('hh:mm a').format(timestamp!.toLocal());
    } catch (_) {
      return '--';
    }
  }

  /// Display string for Calls After Payment
  String get formattedCallsAfterPayment {
    return callsAfterPayment.toString();
  }

  /// Display string for Call Status
  String get displayCallStatus {
    final status = callStatus?.trim();
    if (status == null || status.isEmpty) return '--';
    return status;
  }

  /// Display string for Feedback Status
  String get displayFeedbackStatus {
    final status = feedbackStatus?.trim();
    if (status == null || status.isEmpty) return '--';
    return status;
  }

  /// Safe parser for DateTime from dynamic Firestore values
  static DateTime? parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value.trim());
    return null;
  }

  /// Safe parser for integer values
  static int parseInt(dynamic value, [int defaultValue = 0]) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? defaultValue;
    return defaultValue;
  }

  /// Resolves the canonical category string from call log data and user doc data
  static String resolveCategoryString(
    Map<String, dynamic> callLogData,
    Map<String, dynamic>? userData,
  ) {
    // 1. Check direct call log category
    final directCategory = callLogData['category'] ?? callLogData['businessCategory'];
    if (directCategory is String && directCategory.trim().isNotEmpty) {
      return directCategory.trim();
    }
    if (directCategory is List && directCategory.isNotEmpty) {
      return directCategory.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).join(', ');
    }

    // 2. Check user doc category
    if (userData != null) {
      final userCat = userData['category'] ?? userData['businessCategory'];
      if (userCat is String && userCat.trim().isNotEmpty) {
        return userCat.trim();
      }
      if (userCat is List && userCat.isNotEmpty) {
        return userCat.map((e) => e.toString().trim()).where((s) => s.isNotEmpty).join(', ');
      }
    }

    return '--';
  }

  /// Factory constructor to parse from Firestore QueryDocumentSnapshot and optional hydrated user document.
  factory CallLogsDetailItem.fromFirestore({
    required DocumentSnapshot<Map<String, dynamic>> doc,
    Map<String, dynamic>? userData,
    Map<String, List<String>> pincodesMap = const {},
    Map<String, String>? pincodeCityLookup,
  }) {
    final data = doc.data() ?? {};
    final id = doc.id;

    // Provider UID / Business ID
    final rawBId = (data['businessId'] ??
            data['business_id'] ??
            data['providerId'] ??
            data['provider_id'] ??
            data['uid'])
        ?.toString()
        .trim();
    final businessId = (rawBId != null && rawBId.isNotEmpty)
        ? rawBId
        : (userData?['uid'] ?? userData?['id'] ?? '--').toString();

    // Business Name
    final rawBName = (data['businessName'] ?? data['businessname'])?.toString().trim();
    final userBName = (userData?['businessname'] ?? userData?['name'] ?? userData?['username'])?.toString().trim();
    final businessName = (rawBName != null && rawBName.isNotEmpty)
        ? rawBName
        : ((userBName != null && userBName.isNotEmpty) ? userBName : '--');

    // Business Phone
    final rawBPhone = (data['businessPhone'] ?? data['businessNumber'] ?? data['phone'])?.toString().trim();
    final userPhone = userData?['phone']?.toString().trim();
    final businessPhone = (rawBPhone != null && rawBPhone.isNotEmpty)
        ? rawBPhone
        : ((userPhone != null && userPhone.isNotEmpty) ? userPhone : '--');

    // Caller / Customer Phone
    final callerPhone = (data['callerPhone'] ?? data['customerNumber'] ?? data['customerPhone'] ?? '')
        .toString()
        .trim();

    // Customer Name
    final customerName = (data['customerName'] ?? data['callerName'])?.toString().trim();

    // City Resolution:
    // Check callLog direct city -> check pincode/address -> check user doc city
    String resolvedCity = '';
    final directCity = (data['city'] ?? data['businessCity'] ?? data['customerCity'] ?? data['serviceCity'])
        ?.toString()
        .trim();
    if (directCity != null && directCity.isNotEmpty) {
      resolvedCity = directCity;
    } else {
      final recordCity = resolveRecordCity(
        data,
        pincodesMap: pincodesMap,
        pincodeCityLookup: pincodeCityLookup,
      );
      if (recordCity != null && recordCity.isNotEmpty) {
        resolvedCity = recordCity;
      } else if (userData != null) {
        final userCity = resolveUserCityName(userData, pincodesMap, pincodeCityLookup);
        if (userCity != null && userCity.isNotEmpty) {
          resolvedCity = userCity;
        }
      }
    }
    if (resolvedCity.isEmpty) {
      resolvedCity = '--';
    }

    // Category
    final category = resolveCategoryString(data, userData);

    // Timestamp
    final parsedTs = parseDateTime(data['timestamp'] ?? data['createdAt']);

    // Calls After Payment (from users doc: callsAfterLastPayment / callsAfterPayment)
    final callsAfterPayment = parseInt(
      userData?['callsAfterLastPayment'] ??
          userData?['callsAfterPayment'] ??
          data['callsAfterLastPayment'] ??
          data['callsAfterPayment'],
      0,
    );

    // Call Status
    final callStatus = (data['callStatus'] ?? data['call_status'] ?? data['status'])?.toString().trim();

    // Feedback Status
    final feedbackStatus = (data['feedbackStatus'] ?? data['salesFeedbackStatus'] ?? data['salesStatus'])
        ?.toString()
        .trim();

    // Pincode resolution (check user doc -> check call log doc)
    final userPin = userData != null ? extractUserPincode(userData) : null;
    final recordPin = extractUserPincode(data);
    final pincode = userPin ?? recordPin;

    return CallLogsDetailItem(
      callLogId: id,
      businessId: businessId,
      businessName: businessName,
      businessPhone: businessPhone,
      callerPhone: callerPhone,
      customerName: customerName,
      city: resolvedCity,
      category: category,
      timestamp: parsedTs,
      callsAfterPayment: callsAfterPayment,
      callStatus: callStatus,
      feedbackStatus: feedbackStatus,
      pincode: pincode,
      callLogRawData: data,
      userRawData: userData,
    );
  }

  /// Checks whether this record matches a selected Hyderabad area group (zone).
  /// Reuses the exact PIN-code matching logic from Star Service Providers.
  bool matchesZone(ServiceProviderAreaGroup? zone) {
    if (zone == null) return true;

    // 1. Direct explicit zone/area string match if available in raw data
    final rawZone = (userRawData?['zone'] ??
            userRawData?['area'] ??
            userRawData?['areaGroup'] ??
            userRawData?['division'] ??
            callLogRawData['zone'] ??
            callLogRawData['area'] ??
            callLogRawData['areaGroup'] ??
            callLogRawData['division'])
        ?.toString()
        .trim();
    if (rawZone != null && rawZone.isNotEmpty) {
      if (rawZone.toLowerCase() == zone.displayName.toLowerCase()) {
        return true;
      }
    }

    // 2. Exact PIN-code matching (Star Service Providers reference implementation)
    final pin = pincode ??
        (userRawData != null ? extractUserPincode(userRawData!) : null) ??
        extractUserPincode(callLogRawData);
    if (pin != null && zone.matchesPincode(pin)) {
      return true;
    }

    return false;
  }

  CallLogsDetailItem copyWith({
    String? callLogId,
    String? businessId,
    String? businessName,
    String? businessPhone,
    String? callerPhone,
    String? customerName,
    String? city,
    String? category,
    DateTime? timestamp,
    int? callsAfterPayment,
    String? callStatus,
    String? feedbackStatus,
    String? pincode,
    Map<String, dynamic>? callLogRawData,
    Map<String, dynamic>? userRawData,
  }) {
    return CallLogsDetailItem(
      callLogId: callLogId ?? this.callLogId,
      businessId: businessId ?? this.businessId,
      businessName: businessName ?? this.businessName,
      businessPhone: businessPhone ?? this.businessPhone,
      callerPhone: callerPhone ?? this.callerPhone,
      customerName: customerName ?? this.customerName,
      city: city ?? this.city,
      category: category ?? this.category,
      timestamp: timestamp ?? this.timestamp,
      callsAfterPayment: callsAfterPayment ?? this.callsAfterPayment,
      callStatus: callStatus ?? this.callStatus,
      feedbackStatus: feedbackStatus ?? this.feedbackStatus,
      pincode: pincode ?? this.pincode,
      callLogRawData: callLogRawData ?? this.callLogRawData,
      userRawData: userRawData ?? this.userRawData,
    );
  }
}
