import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single call log document from Firestore `callLogs` collection.
class CallLogItemData {
  final String id;
  final String? businessId;
  final String? businessName;
  final String? businessPhone;
  final String? feedbackStatus;
  final DateTime? timestamp;
  final Map<String, dynamic> rawData;

  const CallLogItemData({
    required this.id,
    this.businessId,
    this.businessName,
    this.businessPhone,
    this.feedbackStatus,
    this.timestamp,
    this.rawData = const {},
  });

  factory CallLogItemData.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return CallLogItemData.fromMap(doc.id, data);
  }

  factory CallLogItemData.fromMap(String id, Map<String, dynamic> data) {
    DateTime? parsedTs;
    final rawTs = data['timestamp'] ?? data['createdAt'];
    if (rawTs is Timestamp) {
      parsedTs = rawTs.toDate();
    } else if (rawTs is DateTime) {
      parsedTs = rawTs;
    } else if (rawTs is int) {
      parsedTs = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else if (rawTs is String) {
      parsedTs = DateTime.tryParse(rawTs);
    }

    final bId = (data['businessId'] ??
            data['business_id'] ??
            data['providerId'] ??
            data['provider_id'] ??
            data['uid'])
        ?.toString()
        .trim();

    final bName = (data['businessName'] ?? data['businessname'])
        ?.toString()
        .trim();

    final bPhone = (data['businessPhone'] ??
            data['businessNumber'] ??
            data['phone'])
        ?.toString()
        .trim();

    final fStatus = (data['feedbackStatus'] ??
            data['salesFeedbackStatus'] ??
            data['salesStatus'])
        ?.toString()
        .trim();

    return CallLogItemData(
      id: id,
      businessId: bId,
      businessName: bName,
      businessPhone: bPhone,
      feedbackStatus: fStatus,
      timestamp: parsedTs,
      rawData: data,
    );
  }
}

/// Consolidated entity representing one service provider row in the Call Log Sheet.
/// Combines fields from `callLogs` and `users` Firestore collections.
class CallLogSheetItem {
  final String businessId; // Provider UID (primary mapping key)
  final String businessName; // callLogs.businessName (fallback: users.businessname)
  final String phone; // callLogs.businessPhone (fallback: users.phone)
  final int callsAfterLastPayment; // users.callsAfterLastPayment (> 5)
  final DateTime? deactivatedAt; // users.deactivatedAt
  final List<String> feedbackStatuses; // Distinct callLogs.feedbackStatus values
  final List<CallLogItemData> callLogs; // Grouped call log docs for this provider
  final String? transactionId; // users.transactionId
  final int convertedCount; // users.convertedCount (source of truth)
  final Map<String, dynamic> userRawData;
  final String? callLogsFetchError; // Distinguishes retrieval failures from missing data

  const CallLogSheetItem({
    required this.businessId,
    required this.businessName,
    required this.phone,
    required this.callsAfterLastPayment,
    this.deactivatedAt,
    required this.feedbackStatuses,
    required this.callLogs,
    this.transactionId,
    required this.convertedCount,
    this.userRawData = const {},
    this.callLogsFetchError,
  });

  /// Whether call logs retrieval encountered an error for this provider
  bool get hasFetchError => callLogsFetchError != null;

  /// Primary feedback status for quick display (most recent call log, or first distinct)
  String get primaryFeedbackStatus {
    if (feedbackStatuses.isEmpty) return 'N/A';
    return feedbackStatuses.first;
  }
}
