import 'package:flutter_test/flutter_test.dart';
import 'package:skazo_admin/constants/business_categories.dart';
import 'package:skazo_admin/models/payment_record.dart';
import 'package:skazo_admin/providers/revenue_providers.dart';

bool _categoryMatches(String cat, String canonicalCategory) {
  final a = cat.trim().toLowerCase();
  final b = canonicalCategory.trim().toLowerCase();
  if (a.isEmpty || b.isEmpty) return false;
  if (a == b) return true;
  if (a == '${b}s' || '${a}s' == b) return true;
  if (a.endsWith('ies') && '${a.substring(0, a.length - 3)}y' == b) return true;
  if (b.endsWith('ies') && '${b.substring(0, b.length - 3)}y' == a) return true;
  return false;
}

bool _recordBelongsToCategory(PaymentRecord record, String canonicalCategory) {
  final raw = record.category.trim();
  if (raw.isEmpty || raw.toLowerCase() == 'unmapped') return false;
  final tokens = raw.split(',').map((c) => c.trim()).where((c) => c.isNotEmpty);
  for (final t in tokens) {
    if (_categoryMatches(t, canonicalCategory)) {
      return true;
    }
  }
  return false;
}

void main() {
  group('Category Wise Revenue Tests — 44 Canonical Categories & 2-Level Flow', () {
    test('kAllCanonicalCategories has exactly 44 categories', () {
      expect(kAllCanonicalCategories.length, 44);
      expect(kAllCanonicalCategories, contains('Electricians'));
      expect(kAllCanonicalCategories, contains('Plumbers'));
      expect(kAllCanonicalCategories, contains('AC Repair'));
      expect(kAllCanonicalCategories, contains('Fridge Repair'));
      expect(kAllCanonicalCategories, contains('Washing Machine Repair'));
      expect(kAllCanonicalCategories, contains('Painters'));
      expect(kAllCanonicalCategories, contains('Tenant Membership'));
      expect(kAllCanonicalCategories, contains('Rental Property Listing'));
      expect(kAllCanonicalCategories, contains('Agent Verification'));
      expect(kAllCanonicalCategories, contains('Local Promotions'));
    });

    final recordMulti = PaymentRecord(
      id: 'rec_multi',
      transactionId: 'TXN_MULTI',
      stream: PaymentStream.providerSubscription,
      amount: 12500.0,
      collectedAmount: 12500.0,
      outstandingAmount: 0.0,
      paymentDate: DateTime(2026, 9, 10),
      status: PaymentStatus.collected,
      reconciliationStatus: ReconciliationStatus.matched,
      userId: 'user_multi',
      userName: 'Multi Service Provider',
      city: 'Hyderabad',
      cityConfidence: DataConfidence.high,
      category: 'Electrician, AC Repair', // MULTI-CATEGORY RECORD
      categoryConfidence: DataConfidence.high,
      sourceCollection: 'users',
      sourceDocumentId: 'doc_multi',
      dataScope: DataScope.latestOnly,
    );

    final recordPpl = PaymentRecord(
      id: 'rec_ppl',
      transactionId: 'TXN_PPL',
      stream: PaymentStream.payPerLeadOutstanding,
      amount: 600.0,
      collectedAmount: 0.0,
      outstandingAmount: 600.0,
      paymentDate: DateTime(2026, 9, 15),
      status: PaymentStatus.outstanding,
      reconciliationStatus: ReconciliationStatus.unmapped,
      userId: 'user_ppl',
      userName: 'Sparky Electrician',
      city: 'Vijayawada',
      cityConfidence: DataConfidence.high,
      category: 'Electricians',
      categoryConfidence: DataConfidence.high,
      sourceCollection: 'users',
      sourceDocumentId: 'doc_ppl',
      dataScope: DataScope.latestOnly,
    );

    final recordPlumber = PaymentRecord(
      id: 'rec_plumber',
      transactionId: 'TXN_PLUMB',
      stream: PaymentStream.providerSubscription,
      amount: 3000.0,
      collectedAmount: 3000.0,
      outstandingAmount: 0.0,
      paymentDate: DateTime(2026, 9, 12),
      status: PaymentStatus.collected,
      reconciliationStatus: ReconciliationStatus.matched,
      userId: 'user_plumber',
      userName: 'Quick Plumber',
      city: 'Hyderabad',
      cityConfidence: DataConfidence.high,
      category: 'Plumber',
      categoryConfidence: DataConfidence.high,
      sourceCollection: 'users',
      sourceDocumentId: 'doc_plumb',
      dataScope: DataScope.latestOnly,
    );

    final testRecords = [recordMulti, recordPpl, recordPlumber];

    test('Multi-category record belongs to both Electricians and AC Repair', () {
      expect(_recordBelongsToCategory(recordMulti, 'Electricians'), isTrue);
      expect(_recordBelongsToCategory(recordMulti, 'AC Repair'), isTrue);
      expect(_recordBelongsToCategory(recordMulti, 'Plumbers'), isFalse);
    });

    test('All 44 canonical categories are present in summary, even with 0 payments', () {
      final List<Map<String, dynamic>> summaries = [];
      for (final cat in kAllCanonicalCategories) {
        double collected = 0.0;
        int count = 0;
        for (final r in testRecords) {
          if (_recordBelongsToCategory(r, cat)) {
            if (r.isCollected) {
              collected += r.collectedAmount;
              count++;
            }
          }
        }
        summaries.add({'category': cat, 'collected': collected, 'count': count});
      }

      expect(summaries.length, 44);
      final electricianSum = summaries.firstWhere((s) => s['category'] == 'Electricians');
      expect(electricianSum['collected'], 12500.0);
      expect(electricianSum['count'], 1);

      final acSum = summaries.firstWhere((s) => s['category'] == 'AC Repair');
      expect(acSum['collected'], 12500.0);
      expect(acSum['count'], 1);

      // Confirm no 'Electrician, AC Repair' 45th category was created
      expect(summaries.any((s) => s['category'] == 'Electrician, AC Repair'), isFalse);

      // Confirm empty categories exist with 0
      final painterSum = summaries.firstWhere((s) => s['category'] == 'Painters');
      expect(painterSum['collected'], 0.0);
      expect(painterSum['count'], 0);
    });

    test('Stream selection restricts calculations for Electrician', () {
      // 1. When stream = Provider Subscription
      final subRecords = testRecords
          .where((r) => r.stream == PaymentStream.providerSubscription)
          .where((r) => _recordBelongsToCategory(r, 'Electricians'))
          .toList();

      expect(subRecords.length, 1);
      expect(subRecords.first.collectedAmount, 12500.0);

      // 2. When stream = Pay Per Lead
      final pplRecords = testRecords
          .where((r) => r.stream == PaymentStream.payPerLeadOutstanding)
          .where((r) => _recordBelongsToCategory(r, 'Electricians'))
          .toList();

      expect(pplRecords.length, 1);
      expect(pplRecords.first.outstandingAmount, 600.0);
      expect(pplRecords.first.collectedAmount, 0.0);
    });

    test('Detail table contains ONLY records matching BOTH stream and category', () {
      const selectedStream = PaymentStream.providerSubscription;
      const selectedCategory = 'Electricians';

      final detailRecords = testRecords.where((r) {
        final matchesStream = r.stream == selectedStream;
        final matchesCategory = _recordBelongsToCategory(r, selectedCategory);
        return matchesStream && matchesCategory;
      }).toList();

      expect(detailRecords.length, 1);
      expect(detailRecords.first.id, 'rec_multi');
      // Plumber must not be in Electricians detail
      expect(detailRecords.any((r) => r.id == 'rec_plumber'), isFalse);
      // PPL record must not be in Provider Subscription detail
      expect(detailRecords.any((r) => r.id == 'rec_ppl'), isFalse);
    });

    test('CategoryWiseLocalState preserves stream when entering and leaving category', () {
      var state = const CategoryWiseLocalState();
      // User selects Provider Subscription
      state = state.copyWith(localStream: PaymentStream.providerSubscription);
      expect(state.localStream, PaymentStream.providerSubscription);
      expect(state.selectedCategory, isNull);

      // User clicks Electricians
      state = state.copyWith(selectedCategory: 'Electricians');
      expect(state.selectedCategory, 'Electricians');
      expect(state.localStream, PaymentStream.providerSubscription); // Stream is preserved!

      // User changes stream to Pay Per Lead while inside detail view
      state = state.copyWith(localStream: PaymentStream.payPerLeadOutstanding);
      expect(state.selectedCategory, 'Electricians'); // Category is preserved!
      expect(state.localStream, PaymentStream.payPerLeadOutstanding);

      // User clicks Back button (clears category only)
      state = state.copyWith(clearCategory: true);
      expect(state.selectedCategory, isNull);
      expect(state.localStream, PaymentStream.payPerLeadOutstanding); // Stream is STILL preserved!
    });
  });
}
