import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:skazo_admin/models/payment_record.dart';
import 'package:url_launcher/url_launcher.dart';

/// Web-safe CSV exporter for payment transactions.
class CsvExportHelper {
  static Future<bool> downloadPaymentRecordsCsv(
    List<PaymentRecord> records, {
    String filenamePrefix = 'skazo_payments',
  }) async {
    if (records.isEmpty) return false;

    final buffer = StringBuffer();

    // CSV Header row
    buffer.writeln([
      'Date',
      'Transaction ID',
      'Razorpay Payment ID',
      'Payment Stream',
      'Amount (INR)',
      'Status',
      'User ID',
      'User Name',
      'Phone',
      'Category',
      'City',
      'City Confidence',
      'Source Collection',
      'Data Scope',
      'Notes',
    ].join(','));

    // Data rows
    for (final r in records) {
      final dateStr = r.paymentDate != null
          ? DateFormat('yyyy-MM-dd HH:mm').format(r.paymentDate!)
          : 'N/A';

      final amountStr = r.isCollected
          ? r.collectedAmount.toStringAsFixed(2)
          : (r.isOutstanding ? r.outstandingAmount.toStringAsFixed(2) : r.amount.toStringAsFixed(2));

      buffer.writeln([
        _csvEscape(dateStr),
        _csvEscape(r.transactionId),
        _csvEscape(r.razorpayPaymentId ?? ''),
        _csvEscape(r.stream.displayName),
        _csvEscape(amountStr),
        _csvEscape(r.status.displayName),
        _csvEscape(r.userId ?? ''),
        _csvEscape(r.userName ?? ''),
        _csvEscape(r.userPhone?.toString() ?? ''),
        _csvEscape(r.category),
        _csvEscape(r.city),
        _csvEscape(r.cityConfidence.label),
        _csvEscape(r.sourceCollection),
        _csvEscape(r.dataScope.label),
        _csvEscape(r.notes ?? ''),
      ].join(','));
    }

    try {
      final bytes = utf8.encode(buffer.toString());
      final base64String = base64Encode(bytes);
      final uri = Uri.parse('data:text/csv;charset=utf-8;base64,$base64String');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static String _csvEscape(String val) {
    if (val.contains(',') || val.contains('"') || val.contains('\n') || val.contains('\r')) {
      return '"${val.replaceAll('"', '""')}"';
    }
    return val;
  }
}
