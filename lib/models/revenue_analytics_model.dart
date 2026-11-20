import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:skazo_admin/models/payment_record.dart';

/// Available date range presets for the Payments & Revenue Dashboard.
enum RevenueDateRangeOption {
  today,
  yesterday,
  last7Days,
  last30Days,
  thisMonth,
  previousMonth,
  thisYear,
  allTime,
  customRange,
}

extension RevenueDateRangeOptionExtension on RevenueDateRangeOption {
  String get label {
    switch (this) {
      case RevenueDateRangeOption.today:
        return 'Today';
      case RevenueDateRangeOption.yesterday:
        return 'Yesterday';
      case RevenueDateRangeOption.last7Days:
        return 'Last 7 Days';
      case RevenueDateRangeOption.last30Days:
        return 'Last 30 Days';
      case RevenueDateRangeOption.thisMonth:
        return 'This Month';
      case RevenueDateRangeOption.previousMonth:
        return 'Previous Month';
      case RevenueDateRangeOption.thisYear:
        return 'This Year';
      case RevenueDateRangeOption.allTime:
        return 'All Time';
      case RevenueDateRangeOption.customRange:
        return 'Custom Range';
    }
  }

  /// Calculates start and end DateTime boundaries for the option.
  DateTimeRange? calculateRange(DateTime? customStart, DateTime? customEnd) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    switch (this) {
      case RevenueDateRangeOption.today:
        return DateTimeRange(start: todayStart, end: todayEnd);
      case RevenueDateRangeOption.yesterday:
        final yStart = todayStart.subtract(const Duration(days: 1));
        final yEnd = DateTime(yStart.year, yStart.month, yStart.day, 23, 59, 59, 999);
        return DateTimeRange(start: yStart, end: yEnd);
      case RevenueDateRangeOption.last7Days:
        return DateTimeRange(start: todayStart.subtract(const Duration(days: 7)), end: todayEnd);
      case RevenueDateRangeOption.last30Days:
        return DateTimeRange(start: todayStart.subtract(const Duration(days: 30)), end: todayEnd);
      case RevenueDateRangeOption.thisMonth:
        return DateTimeRange(start: DateTime(now.year, now.month, 1), end: todayEnd);
      case RevenueDateRangeOption.previousMonth:
        final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final pStart = DateTime(prevMonthYear, prevMonth, 1);
        final lastDayOfPrevMonth = DateTime(now.year, now.month, 0).day;
        final pEnd = DateTime(prevMonthYear, prevMonth, lastDayOfPrevMonth, 23, 59, 59, 999);
        return DateTimeRange(start: pStart, end: pEnd);
      case RevenueDateRangeOption.thisYear:
        return DateTimeRange(start: DateTime(now.year, 1, 1), end: todayEnd);
      case RevenueDateRangeOption.allTime:
        return null;
      case RevenueDateRangeOption.customRange:
        if (customStart != null && customEnd != null) {
          final cEnd = DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999);
          return DateTimeRange(start: customStart, end: cEnd);
        }
        return null;
    }
  }
}

/// Unified filter state for all payment analytics cards, tables, and exports.
class RevenueFilter {
  final RevenueDateRangeOption dateRangeOption;
  final DateTime? customStartDate;
  final DateTime? customEndDate;
  final String? selectedCity;
  final String? selectedCategory;
  final PaymentStream? selectedStream;
  final PaymentStatus? selectedStatus;
  final ReconciliationStatus? selectedReconciliationStatus;
  final double? minAmount;
  final double? maxAmount;
  final String searchQuery;

  const RevenueFilter({
    this.dateRangeOption = RevenueDateRangeOption.allTime,
    this.customStartDate,
    this.customEndDate,
    this.selectedCity,
    this.selectedCategory,
    this.selectedStream,
    this.selectedStatus,
    this.selectedReconciliationStatus,
    this.minAmount,
    this.maxAmount,
    this.searchQuery = '',
  });

  RevenueFilter copyWith({
    RevenueDateRangeOption? dateRangeOption,
    DateTime? customStartDate,
    DateTime? customEndDate,
    String? selectedCity,
    bool clearCity = false,
    String? selectedCategory,
    bool clearCategory = false,
    PaymentStream? selectedStream,
    bool clearStream = false,
    PaymentStatus? selectedStatus,
    bool clearStatus = false,
    ReconciliationStatus? selectedReconciliationStatus,
    bool clearReconciliation = false,
    double? minAmount,
    double? maxAmount,
    String? searchQuery,
  }) {
    return RevenueFilter(
      dateRangeOption: dateRangeOption ?? this.dateRangeOption,
      customStartDate: customStartDate ?? this.customStartDate,
      customEndDate: customEndDate ?? this.customEndDate,
      selectedCity: clearCity ? null : (selectedCity ?? this.selectedCity),
      selectedCategory: clearCategory ? null : (selectedCategory ?? this.selectedCategory),
      selectedStream: clearStream ? null : (selectedStream ?? this.selectedStream),
      selectedStatus: clearStatus ? null : (selectedStatus ?? this.selectedStatus),
      selectedReconciliationStatus: clearReconciliation
          ? null
          : (selectedReconciliationStatus ?? this.selectedReconciliationStatus),
      minAmount: minAmount ?? this.minAmount,
      maxAmount: maxAmount ?? this.maxAmount,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }

  bool matches(PaymentRecord record) {
    // 1. Date Range
    final range = dateRangeOption.calculateRange(customStartDate, customEndDate);
    if (range != null) {
      if (record.paymentDate == null) return false;
      if (record.paymentDate!.isBefore(range.start) || record.paymentDate!.isAfter(range.end)) {
        return false;
      }
    }

    // 2. City
    if (selectedCity != null && selectedCity!.isNotEmpty) {
      if (record.city.toLowerCase() != selectedCity!.toLowerCase()) {
        return false;
      }
    }

    // 3. Category
    if (selectedCategory != null && selectedCategory!.isNotEmpty) {
      if (!record.category.toLowerCase().contains(selectedCategory!.toLowerCase())) {
        return false;
      }
    }

    // 4. Stream
    if (selectedStream != null && record.stream != selectedStream) {
      return false;
    }

    // 5. Status
    if (selectedStatus != null && record.status != selectedStatus) {
      return false;
    }

    // 6. Reconciliation Status
    if (selectedReconciliationStatus != null &&
        record.reconciliationStatus != selectedReconciliationStatus) {
      return false;
    }

    // 7. Amount Range
    if (minAmount != null && record.amount < minAmount!) return false;
    if (maxAmount != null && record.amount > maxAmount!) return false;

    // 8. Search query
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      final matchTxn = record.transactionId.toLowerCase().contains(q);
      final matchRazorpay = record.razorpayPaymentId?.toLowerCase().contains(q) ?? false;
      final matchOrder = record.razorpayOrderId?.toLowerCase().contains(q) ?? false;
      final matchUser = record.userName?.toLowerCase().contains(q) ?? false;
      final matchPhone = record.userPhone?.toString().contains(q) ?? false;
      final matchCity = record.city.toLowerCase().contains(q);
      final matchCategory = record.category.toLowerCase().contains(q);
      final matchDoc = record.sourceDocumentId.toLowerCase().contains(q);
      if (!matchTxn && !matchRazorpay && !matchOrder && !matchUser && !matchPhone && !matchCity && !matchCategory && !matchDoc) {
        return false;
      }
    }

    return true;
  }
}

/// Breakdown per payment stream.
class StreamBreakdownItem {
  final PaymentStream stream;
  final int transactionCount;
  final double collectedRevenue;
  final double outstandingAmount;
  final double refundedAmount;
  final double netAmount;
  final double revenuePercentage;

  const StreamBreakdownItem({
    required this.stream,
    required this.transactionCount,
    required this.collectedRevenue,
    required this.outstandingAmount,
    this.refundedAmount = 0.0,
    double? netAmount,
    required this.revenuePercentage,
  }) : netAmount = netAmount ?? (collectedRevenue - refundedAmount);
}

/// Breakdown per city.
class CityBreakdownItem {
  final String city;
  final int transactionCount;
  final double collectedRevenue;
  final double outstandingAmount;
  final double refundedAmount;
  final double netAmount;
  final int uniqueUsers;
  final double averagePayment;

  const CityBreakdownItem({
    required this.city,
    required this.transactionCount,
    required this.collectedRevenue,
    required this.outstandingAmount,
    this.refundedAmount = 0.0,
    double? netAmount,
    required this.uniqueUsers,
    required this.averagePayment,
  }) : netAmount = netAmount ?? (collectedRevenue - refundedAmount);
}

/// Breakdown per category.
class CategoryBreakdownItem {
  final String category;
  final int transactionCount;
  final double collectedRevenue;
  final double outstandingAmount;
  final double refundedAmount;
  final double netAmount;
  final int uniqueUsers;

  const CategoryBreakdownItem({
    required this.category,
    required this.transactionCount,
    required this.collectedRevenue,
    required this.outstandingAmount,
    this.refundedAmount = 0.0,
    double? netAmount,
    required this.uniqueUsers,
  }) : netAmount = netAmount ?? (collectedRevenue - refundedAmount);
}

/// Record representing a refund.
class RefundRecord {
  final String id;
  final String refundId;
  final String paymentId;
  final double amount;
  final String status;
  final DateTime? refundDate;
  final String? customerName;
  final String? reason;
  final String source;

  const RefundRecord({
    required this.id,
    required this.refundId,
    required this.paymentId,
    required this.amount,
    required this.status,
    this.refundDate,
    this.customerName,
    this.reason,
    required this.source,
  });

  factory RefundRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return RefundRecord(
      id: doc.id,
      refundId: d['refundId']?.toString() ?? doc.id,
      paymentId: d['paymentId']?.toString() ?? '',
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      status: d['status']?.toString() ?? 'processed',
      refundDate: parseDate(d['refundDate'] ?? d['createdAt']),
      customerName: d['customerName']?.toString(),
      reason: d['reason']?.toString(),
      source: d['source']?.toString() ?? 'razorpay',
    );
  }
}

/// Record representing a Razorpay settlement.
class SettlementRecord {
  final String id;
  final String settlementId;
  final double amount;
  final double fees;
  final double tax;
  final double netSettlement;
  final String utr;
  final String status;
  final DateTime? settlementDate;

  const SettlementRecord({
    required this.id,
    required this.settlementId,
    required this.amount,
    required this.fees,
    required this.tax,
    required this.netSettlement,
    required this.utr,
    required this.status,
    this.settlementDate,
  });

  factory SettlementRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return SettlementRecord(
      id: doc.id,
      settlementId: d['settlementId']?.toString() ?? doc.id,
      amount: (d['amount'] as num?)?.toDouble() ?? 0.0,
      fees: (d['fees'] as num?)?.toDouble() ?? 0.0,
      tax: (d['tax'] as num?)?.toDouble() ?? 0.0,
      netSettlement: (d['netSettlement'] as num?)?.toDouble() ?? 0.0,
      utr: d['utr']?.toString() ?? '',
      status: d['status']?.toString() ?? 'processed',
      settlementDate: parseDate(d['settlementDate'] ?? d['createdAt']),
    );
  }
}

/// Audit log entry.
class AuditLogRecord {
  final String id;
  final String actor;
  final String action;
  final String? transactionId;
  final DateTime? timestamp;
  final Map<String, dynamic> previousState;
  final Map<String, dynamic> newState;

  const AuditLogRecord({
    required this.id,
    required this.actor,
    required this.action,
    this.transactionId,
    this.timestamp,
    this.previousState = const {},
    this.newState = const {},
  });

  factory AuditLogRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    DateTime? parseDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    return AuditLogRecord(
      id: doc.id,
      actor: d['actor']?.toString() ?? 'system',
      action: d['action']?.toString() ?? 'ACTION',
      transactionId: d['transactionId']?.toString(),
      timestamp: parseDate(d['timestamp'] ?? d['createdAt']),
      previousState: d['previousState'] is Map ? Map<String, dynamic>.from(d['previousState']) : {},
      newState: d['newState'] is Map ? Map<String, dynamic>.from(d['newState']) : {},
    );
  }
}

/// Summary of reconciliation against Razorpay.
class ReconciliationSummary {
  final double firebaseTotal;
  final double razorpayTotal;
  final double difference;
  final int matchedCount;
  final int missingInFirebaseCount;
  final int missingInRazorpayCount;
  final int amountMismatchCount;
  final int dateMismatchCount;
  final int duplicateCount;
  final int unmappedCount;
  final int needsReviewCount;
  final bool isRazorpayConnected;
  final DateTime? lastSyncTime;

  const ReconciliationSummary({
    required this.firebaseTotal,
    required this.razorpayTotal,
    required this.difference,
    required this.matchedCount,
    required this.missingInFirebaseCount,
    required this.missingInRazorpayCount,
    required this.amountMismatchCount,
    required this.dateMismatchCount,
    this.duplicateCount = 0,
    required this.unmappedCount,
    required this.needsReviewCount,
    required this.isRazorpayConnected,
    this.lastSyncTime,
  });
}

/// Top-level computed data holding all dashboard metrics and records.
class RevenueAnalyticsData {
  final double totalCollectedRevenue;
  final double currentPeriodRevenue;
  final double todayRevenue;
  final double thisWeekRevenue;
  final double thisMonthRevenue;
  final double thisYearRevenue;
  final int totalTransactions;
  final double outstandingPayPerLead;
  final double totalRefunded;
  final double netCollectedRevenue;
  final int failedPaymentsCount;
  final double paymentSuccessRate;

  final double providerRevenue;
  final double propertyRevenue;
  final double agentRevenue;
  final double localPromotionRevenue;
  final double tenantContactRevenue;
  final int paymentAttemptsCount;

  final List<StreamBreakdownItem> streamBreakdown;
  final List<CityBreakdownItem> cityBreakdown;
  final List<CategoryBreakdownItem> categoryBreakdown;
  final ReconciliationSummary reconciliationSummary;
  final List<PaymentRecord> allMatchingRecords;
  final List<RefundRecord> refunds;
  final List<SettlementRecord> settlements;
  final List<String> dataWarnings;
  final DateTime computedAt;

  const RevenueAnalyticsData({
    required this.totalCollectedRevenue,
    required this.currentPeriodRevenue,
    this.todayRevenue = 0.0,
    this.thisWeekRevenue = 0.0,
    this.thisMonthRevenue = 0.0,
    this.thisYearRevenue = 0.0,
    required this.totalTransactions,
    required this.outstandingPayPerLead,
    this.totalRefunded = 0.0,
    double? netCollectedRevenue,
    this.failedPaymentsCount = 0,
    this.paymentSuccessRate = 100.0,
    required this.providerRevenue,
    required this.propertyRevenue,
    required this.agentRevenue,
    required this.localPromotionRevenue,
    required this.tenantContactRevenue,
    required this.paymentAttemptsCount,
    required this.streamBreakdown,
    required this.cityBreakdown,
    required this.categoryBreakdown,
    required this.reconciliationSummary,
    required this.allMatchingRecords,
    this.refunds = const [],
    this.settlements = const [],
    required this.dataWarnings,
    required this.computedAt,
  }) : netCollectedRevenue = netCollectedRevenue ?? (totalCollectedRevenue - totalRefunded);
}
