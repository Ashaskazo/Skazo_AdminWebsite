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
}

/// Payment lifecycle status.
enum PaymentStatus {
  collected,
  outstanding,
  paymentAttempt,
  failedOrCancelled,
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
        return 'Not Available in Source';
      case PaymentStatus.unknown:
        return 'Unknown';
    }
  }
}

/// Razorpay and internal ledger reconciliation state.
enum ReconciliationStatus {
  matched,
  missingInFirebase,
  missingInRazorpay,
  amountMismatch,
  dateMismatch,
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
      case ReconciliationStatus.unmapped:
        return 'Unmapped';
      case ReconciliationStatus.needsReview:
        return 'Needs Review';
      case ReconciliationStatus.razorpayNotConnected:
        return 'Razorpay API Not Connected';
    }
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
}

/// Data scope indicator to distinguish latest overwrite from historical transactions.
enum DataScope {
  latestOnly,
  historical,
}

extension DataScopeExtension on DataScope {
  String get label {
    switch (this) {
      case DataScope.latestOnly:
        return 'latest_only (Latest Doc State)';
      case DataScope.historical:
        return 'historical (Transaction Ledger)';
    }
  }
}

/// Canonical internal representation of a payment or revenue entry.
class PaymentRecord {
  final String id;
  final String transactionId;
  final String? razorpayPaymentId;
  final PaymentStream stream;
  final double amount;
  final double collectedAmount;
  final double outstandingAmount;
  final DateTime? paymentDate;
  final PaymentStatus status;
  final ReconciliationStatus reconciliationStatus;
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

  const PaymentRecord({
    required this.id,
    required this.transactionId,
    this.razorpayPaymentId,
    required this.stream,
    required this.amount,
    required this.collectedAmount,
    required this.outstandingAmount,
    this.paymentDate,
    required this.status,
    required this.reconciliationStatus,
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
  });

  bool get isCollected => status == PaymentStatus.collected;
  bool get isOutstanding => status == PaymentStatus.outstanding;
  bool get isAttempt => status == PaymentStatus.paymentAttempt;
}
