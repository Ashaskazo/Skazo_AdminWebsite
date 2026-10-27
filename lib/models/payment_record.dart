import 'package:cloud_firestore/cloud_firestore.dart';

/// Internal canonical classification of SKAZO payment streams.
enum PaymentStream {
  providerSubscription,
  payPerLeadOutstanding,
  payPerLeadCollected,
  tenantContact,
  propertyListing,
  agentVerification,
  localPromotion,
  unknown,
}

extension PaymentStreamExtension on PaymentStream {
  String get displayName {
    switch (this) {
      case PaymentStream.providerSubscription:
        return 'Provider Subscription';
      case PaymentStream.payPerLeadOutstanding:
        return 'Pay-per-Lead (Outstanding)';
      case PaymentStream.payPerLeadCollected:
        return 'Pay-per-Lead (Collected)';
      case PaymentStream.tenantContact:
        return 'Tenant Property Contact';
      case PaymentStream.propertyListing:
        return 'Property Listing / Premium';
      case PaymentStream.agentVerification:
        return 'Agent Verification';
      case PaymentStream.localPromotion:
        return 'Local Promotion / Ads';
      case PaymentStream.unknown:
        return 'Unclassified Stream';
    }
  }

  String get shortName {
    switch (this) {
      case PaymentStream.providerSubscription:
        return 'Subscription';
      case PaymentStream.payPerLeadOutstanding:
        return 'PPL (Owed)';
      case PaymentStream.payPerLeadCollected:
        return 'PPL (Paid)';
      case PaymentStream.tenantContact:
        return 'Tenant Pass';
      case PaymentStream.propertyListing:
        return 'Property';
      case PaymentStream.agentVerification:
        return 'Agent';
      case PaymentStream.localPromotion:
        return 'Promotion';
      case PaymentStream.unknown:
        return 'Other';
    }
  }

  static PaymentStream fromString(String? val) {
    if (val == null) return PaymentStream.unknown;
    final v = val.toLowerCase().trim();
    if (v.contains('providersubscription') || v.contains('subscription') || v.contains('provider')) {
      return PaymentStream.providerSubscription;
    }
    if (v.contains('payperleadcollected') || v.contains('ppl_paid')) {
      return PaymentStream.payPerLeadCollected;
    }
    if (v.contains('payperlead') || v.contains('ppl') || v.contains('lead')) {
      return PaymentStream.payPerLeadOutstanding;
    }
    if (v.contains('tenant') || v.contains('userproperty')) {
      return PaymentStream.tenantContact;
    }
    if (v.contains('property') || v.contains('rental')) {
      return PaymentStream.propertyListing;
    }
    if (v.contains('agent')) {
      return PaymentStream.agentVerification;
    }
    if (v.contains('promotion') || v.contains('promo') || v.contains('ad')) {
      return PaymentStream.localPromotion;
    }
    return PaymentStream.unknown;
  }
}

/// Payment lifecycle status.
enum PaymentStatus {
  collected,
  outstanding,
  paymentAttempt,
  failedOrCancelled,
  refunded,
  partiallyRefunded,
  authorized,
  unknown,
}

extension PaymentStatusExtension on PaymentStatus {
  String get displayName {
    switch (this) {
      case PaymentStatus.collected:
        return 'Collected';
      case PaymentStatus.outstanding:
        return 'Outstanding (Owed)';
      case PaymentStatus.paymentAttempt:
        return 'Payment Attempt (Unpaid)';
      case PaymentStatus.failedOrCancelled:
        return 'Failed / Cancelled';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.partiallyRefunded:
        return 'Partially Refunded';
      case PaymentStatus.authorized:
        return 'Authorized (Pending Capture)';
      case PaymentStatus.unknown:
        return 'Unknown';
    }
  }

  static PaymentStatus fromString(String? val) {
    if (val == null) return PaymentStatus.unknown;
    final v = val.toLowerCase().trim();
    if (v == 'captured' || v == 'collected' || v == 'paid' || v == 'settled' || v == 'success') {
      return PaymentStatus.collected;
    }
    if (v == 'outstanding' || v == 'unpaid_debt' || v == 'owed') {
      return PaymentStatus.outstanding;
    }
    if (v == 'paymentattempt' || v == 'attempted' || v == 'created' || v == 'pending') {
      return PaymentStatus.paymentAttempt;
    }
    if (v == 'refunded') {
      return PaymentStatus.refunded;
    }
    if (v == 'partially_refunded' || v == 'partiallyrefunded') {
      return PaymentStatus.partiallyRefunded;
    }
    if (v == 'authorized') {
      return PaymentStatus.authorized;
    }
    if (v == 'failed' || v == 'cancelled' || v == 'canceled') {
      return PaymentStatus.failedOrCancelled;
    }
    return PaymentStatus.unknown;
  }
}

/// Razorpay and internal ledger reconciliation state.
enum ReconciliationStatus {
  matched,
  missingInFirebase,
  missingInRazorpay,
  amountMismatch,
  dateMismatch,
  duplicate,
  unmapped,
  needsReview,
  razorpayNotConnected,
}

extension ReconciliationStatusExtension on ReconciliationStatus {
  String get displayName {
    switch (this) {
      case ReconciliationStatus.matched:
        return 'Matched';
      case ReconciliationStatus.missingInFirebase:
        return 'Missing in Firebase';
      case ReconciliationStatus.missingInRazorpay:
        return 'Missing in Razorpay';
      case ReconciliationStatus.amountMismatch:
        return 'Amount Mismatch';
      case ReconciliationStatus.dateMismatch:
        return 'Date Mismatch';
      case ReconciliationStatus.duplicate:
        return 'Duplicate Transaction';
      case ReconciliationStatus.unmapped:
        return 'Unmapped';
      case ReconciliationStatus.needsReview:
        return 'Needs Review';
      case ReconciliationStatus.razorpayNotConnected:
        return 'Razorpay API Not Connected';
    }
  }

  static ReconciliationStatus fromString(String? val) {
    if (val == null) return ReconciliationStatus.unmapped;
    final v = val.toLowerCase().trim();
    if (v == 'matched') return ReconciliationStatus.matched;
    if (v == 'missinginfirebase' || v == 'missing_in_firebase') return ReconciliationStatus.missingInFirebase;
    if (v == 'missinginrazorpay' || v == 'missing_in_razorpay') return ReconciliationStatus.missingInRazorpay;
    if (v == 'amountmismatch' || v == 'amount_mismatch') return ReconciliationStatus.amountMismatch;
    if (v == 'datemismatch' || v == 'date_mismatch') return ReconciliationStatus.dateMismatch;
    if (v == 'duplicate') return ReconciliationStatus.duplicate;
    if (v == 'needsreview' || v == 'needs_review') return ReconciliationStatus.needsReview;
    if (v == 'razorpaynotconnected' || v == 'razorpay_not_connected') return ReconciliationStatus.razorpayNotConnected;
    return ReconciliationStatus.unmapped;
  }
}

/// Data quality and attribution confidence rating.
enum DataConfidence {
  high,
  medium,
  low,
  unknown,
}

extension DataConfidenceExtension on DataConfidence {
  String get label {
    switch (this) {
      case DataConfidence.high:
        return 'High (Direct)';
      case DataConfidence.medium:
        return 'Medium (Pincode match)';
      case DataConfidence.low:
        return 'Low (Address parse)';
      case DataConfidence.unknown:
        return 'Unknown / Unmapped';
    }
  }

  static DataConfidence fromString(String? val) {
    if (val == null) return DataConfidence.unknown;
    final v = val.toLowerCase().trim();
    if (v.contains('high')) return DataConfidence.high;
    if (v.contains('med')) return DataConfidence.medium;
    if (v.contains('low')) return DataConfidence.low;
    return DataConfidence.unknown;
  }
}

/// Data scope indicator to distinguish latest overwrite from historical transactions.
enum DataScope {
  latestOnly,
  historical,
  legacyHistorical,
}

extension DataScopeExtension on DataScope {
  String get label {
    switch (this) {
      case DataScope.latestOnly:
        return 'latest_only (Latest Doc State)';
      case DataScope.historical:
        return 'historical (Verified Ledger)';
      case DataScope.legacyHistorical:
        return 'legacy_historical (Migrated)';
    }
  }

  static DataScope fromString(String? val) {
    if (val == null) return DataScope.latestOnly;
    final v = val.toLowerCase().trim();
    if (v.contains('historical') && !v.contains('legacy')) return DataScope.historical;
    if (v.contains('legacy')) return DataScope.legacyHistorical;
    return DataScope.latestOnly;
  }
}

/// Canonical representation of a financial ledger entry.
class PaymentRecord {
  final String id;
  final String transactionId;
  final String? razorpayPaymentId;
  final String? razorpayOrderId;
  final String? razorpayLinkId;
  final PaymentStream stream;
  final double amount;
  final int amountPaise;
  final double collectedAmount;
  final int collectedAmountPaise;
  final double outstandingAmount;
  final int outstandingAmountPaise;
  final double refundedAmount;
  final int refundedAmountPaise;
  final double netCollectedAmount;
  final int netCollectedAmountPaise;
  final double razorpayFee;
  final double taxOnFee;
  final DateTime? paymentDate;
  final DateTime? capturedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final PaymentStatus status;
  final ReconciliationStatus reconciliationStatus;
  final String? paymentMethod;
  final String? settlementId;
  final String? settlementStatus;
  final String verificationStatus; // verified, unverified, failed, legacy_unverified
  final bool webhookVerified;
  final bool signatureVerified;
  final String? userId;
  final String? userName;
  final dynamic userPhone;
  final String city;
  final String? cityKey;
  final DataConfidence cityConfidence;
  final String category;
  final DataConfidence categoryConfidence;
  final String sourceCollection;
  final String sourceDocumentId;
  final DataScope dataScope;
  final String? notes;
  final Map<String, dynamic> metadata;

  PaymentRecord({
    required this.id,
    required this.transactionId,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    this.razorpayLinkId,
    required this.stream,
    required this.amount,
    int? amountPaise,
    required this.collectedAmount,
    int? collectedAmountPaise,
    required this.outstandingAmount,
    int? outstandingAmountPaise,
    this.refundedAmount = 0.0,
    int? refundedAmountPaise,
    double? netCollectedAmount,
    int? netCollectedAmountPaise,
    this.razorpayFee = 0.0,
    this.taxOnFee = 0.0,
    this.paymentDate,
    this.capturedAt,
    this.createdAt,
    this.updatedAt,
    required this.status,
    required this.reconciliationStatus,
    this.paymentMethod,
    this.settlementId,
    this.settlementStatus = 'unsettled',
    this.verificationStatus = 'unverified',
    this.webhookVerified = false,
    this.signatureVerified = false,
    this.userId,
    this.userName,
    this.userPhone,
    required this.city,
    this.cityKey,
    required this.cityConfidence,
    required this.category,
    required this.categoryConfidence,
    required this.sourceCollection,
    required this.sourceDocumentId,
    required this.dataScope,
    this.notes,
    this.metadata = const {},
  })  : amountPaise = amountPaise ?? (amount * 100).round(),
        collectedAmountPaise = collectedAmountPaise ?? (collectedAmount * 100).round(),
        outstandingAmountPaise = outstandingAmountPaise ?? (outstandingAmount * 100).round(),
        refundedAmountPaise = refundedAmountPaise ?? (refundedAmount * 100).round(),
        netCollectedAmount = netCollectedAmount ?? (collectedAmount - refundedAmount),
        netCollectedAmountPaise = netCollectedAmountPaise ??
            ((collectedAmountPaise ?? (collectedAmount * 100).round()) -
                (refundedAmountPaise ?? (refundedAmount * 100).round()));

  bool get isCollected => status == PaymentStatus.collected;
  bool get isOutstanding => status == PaymentStatus.outstanding;
  bool get isAttempt => status == PaymentStatus.paymentAttempt;
  bool get isRefunded => status == PaymentStatus.refunded || status == PaymentStatus.partiallyRefunded;
  bool get isFailed => status == PaymentStatus.failedOrCancelled;

  /// Creates a PaymentRecord from a Firestore document.
  factory PaymentRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return PaymentRecord.fromMap(data, doc.id);
  }

  /// Creates a PaymentRecord from a generic Map.
  factory PaymentRecord.fromMap(Map<String, dynamic> data, String docId) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    final double amount = (data['amount'] as num?)?.toDouble() ??
        ((data['amountPaise'] as num?)?.toDouble() ?? 0.0) / 100.0;
    final int amountPaise = (data['amountPaise'] as num?)?.toInt() ?? (amount * 100).round();

    final status = PaymentStatusExtension.fromString(data['status']?.toString());
    final isCollectedStatus = status == PaymentStatus.collected;
    final isOutstandingStatus = status == PaymentStatus.outstanding;

    final double collected = (data['collectedAmount'] as num?)?.toDouble() ??
        (isCollectedStatus ? amount : 0.0);
    final int collectedPaise = (data['collectedAmountPaise'] as num?)?.toInt() ??
        (collected * 100).round();

    final double outstanding = (data['outstandingAmount'] as num?)?.toDouble() ??
        (isOutstandingStatus ? amount : 0.0);
    final int outstandingPaise = (data['outstandingAmountPaise'] as num?)?.toInt() ??
        (outstanding * 100).round();

    final double refunded = (data['refundedAmount'] as num?)?.toDouble() ??
        ((data['refundedAmountPaise'] as num?)?.toDouble() ?? 0.0) / 100.0;
    final int refundedPaise = (data['refundedAmountPaise'] as num?)?.toInt() ??
        (refunded * 100).round();

    final double netCollected = (data['netCollectedAmount'] as num?)?.toDouble() ??
        (collected - refunded);
    final int netCollectedPaise = (data['netCollectedAmountPaise'] as num?)?.toInt() ??
        (collectedPaise - refundedPaise);

    final txnId = data['transactionId']?.toString().trim() ?? docId;
    final rzpId = data['razorpayPaymentId']?.toString().trim();

    return PaymentRecord(
      id: docId,
      transactionId: txnId.isNotEmpty ? txnId : docId,
      razorpayPaymentId: (rzpId != null && rzpId.isNotEmpty) ? rzpId : null,
      razorpayOrderId: data['razorpayOrderId']?.toString(),
      razorpayLinkId: data['razorpayLinkId']?.toString(),
      stream: PaymentStreamExtension.fromString(data['stream']?.toString()),
      amount: amount,
      amountPaise: amountPaise,
      collectedAmount: collected,
      collectedAmountPaise: collectedPaise,
      outstandingAmount: outstanding,
      outstandingAmountPaise: outstandingPaise,
      refundedAmount: refunded,
      refundedAmountPaise: refundedPaise,
      netCollectedAmount: netCollected,
      netCollectedAmountPaise: netCollectedPaise,
      razorpayFee: (data['razorpayFee'] as num?)?.toDouble() ?? 0.0,
      taxOnFee: (data['taxOnFee'] as num?)?.toDouble() ?? 0.0,
      paymentDate: parseDate(data['paymentDate'] ?? data['capturedAt'] ?? data['createdAt']),
      capturedAt: parseDate(data['capturedAt']),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
      status: status,
      reconciliationStatus: ReconciliationStatusExtension.fromString(
        data['reconciliationStatus']?.toString(),
      ),
      paymentMethod: data['paymentMethod']?.toString(),
      settlementId: data['settlementId']?.toString(),
      settlementStatus: data['settlementStatus']?.toString() ?? 'unsettled',
      verificationStatus: data['verificationStatus']?.toString() ?? 'unverified',
      webhookVerified: data['webhookVerified'] == true,
      signatureVerified: data['signatureVerified'] == true,
      userId: data['userId']?.toString(),
      userName: data['userName']?.toString(),
      userPhone: data['userPhone'],
      city: data['city']?.toString() ?? 'Unknown / Unmapped',
      cityKey: data['cityKey']?.toString(),
      cityConfidence: DataConfidenceExtension.fromString(data['cityConfidence']?.toString()),
      category: data['category']?.toString() ?? 'Unclassified',
      categoryConfidence: DataConfidenceExtension.fromString(data['categoryConfidence']?.toString()),
      sourceCollection: data['sourceCollection']?.toString() ?? 'financial_transactions',
      sourceDocumentId: data['sourceDocumentId']?.toString() ?? docId,
      dataScope: DataScopeExtension.fromString(data['dataScope']?.toString()),
      notes: data['notes']?.toString(),
      metadata: data['metadata'] is Map ? Map<String, dynamic>.from(data['metadata'] as Map) : {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'razorpayPaymentId': razorpayPaymentId,
      'razorpayOrderId': razorpayOrderId,
      'razorpayLinkId': razorpayLinkId,
      'stream': stream.name,
      'amount': amount,
      'amountPaise': amountPaise,
      'collectedAmount': collectedAmount,
      'collectedAmountPaise': collectedAmountPaise,
      'outstandingAmount': outstandingAmount,
      'outstandingAmountPaise': outstandingAmountPaise,
      'refundedAmount': refundedAmount,
      'refundedAmountPaise': refundedAmountPaise,
      'netCollectedAmount': netCollectedAmount,
      'netCollectedAmountPaise': netCollectedAmountPaise,
      'razorpayFee': razorpayFee,
      'taxOnFee': taxOnFee,
      'paymentDate': paymentDate != null ? Timestamp.fromDate(paymentDate!) : null,
      'capturedAt': capturedAt != null ? Timestamp.fromDate(capturedAt!) : null,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'status': status.name,
      'reconciliationStatus': reconciliationStatus.name,
      'paymentMethod': paymentMethod,
      'settlementId': settlementId,
      'settlementStatus': settlementStatus,
      'verificationStatus': verificationStatus,
      'webhookVerified': webhookVerified,
      'signatureVerified': signatureVerified,
      'userId': userId,
      'userName': userName,
      'userPhone': userPhone,
      'city': city,
      'cityKey': cityKey,
      'cityConfidence': cityConfidence.name,
      'category': category,
      'categoryConfidence': categoryConfidence.name,
      'sourceCollection': sourceCollection,
      'sourceDocumentId': sourceDocumentId,
      'dataScope': dataScope.name,
      'notes': notes,
      'metadata': metadata,
    };
  }
}
