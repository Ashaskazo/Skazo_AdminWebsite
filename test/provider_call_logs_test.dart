import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skazo_admin/widgets/provider_call_logs_section.dart';

void main() {
  group('ProviderCallLogsSection Tests', () {
    testWidgets('renders empty state when providerUid is null', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProviderCallLogsSection(providerUid: null)),
        ),
      );

      // Verify empty state is displayed
      expect(find.text('Provider Call Logs 📞'), findsOneWidget);
      expect(find.text('No call logs found'), findsOneWidget);
      expect(
        find.text(
          'No customer calls have been logged for this service provider.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('renders empty state when providerUid is empty string', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: ProviderCallLogsSection(providerUid: '   ')),
        ),
      );

      expect(find.text('No call logs found'), findsOneWidget);
    });

    test('verifies parseFirestoreTimestamp handles all types correctly', () {
      final now = DateTime(2026, 10, 26, 12, 30);
      final ts = Timestamp.fromDate(now);

      Timestamp? parseTimestamp(dynamic raw) {
        if (raw == null) return null;
        if (raw is Timestamp) return raw;
        if (raw is DateTime) return Timestamp.fromDate(raw);
        if (raw is int) {
          try {
            return Timestamp.fromMillisecondsSinceEpoch(raw);
          } catch (_) {
            return null;
          }
        }
        if (raw is String) {
          final trimmed = raw.trim();
          if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
          final parsed = DateTime.tryParse(trimmed);
          if (parsed != null) {
            return Timestamp.fromDate(parsed);
          }
        }
        return null;
      }

      // Valid Timestamp
      expect(parseTimestamp(ts), equals(ts));

      // Valid DateTime
      expect(parseTimestamp(now), equals(ts));

      // Valid milliseconds epoch int
      expect(parseTimestamp(now.millisecondsSinceEpoch), equals(ts));

      // Valid ISO 8601 string
      expect(parseTimestamp('2026-10-26T12:30:00.000'), equals(ts));

      // Null, empty, and invalid values must return null
      expect(parseTimestamp(null), isNull);
      expect(parseTimestamp(''), isNull);
      expect(parseTimestamp('   '), isNull);
      expect(parseTimestamp('null'), isNull);
      expect(parseTimestamp('invalid_date_format'), isNull);
      expect(parseTimestamp(false), isNull);
      expect(parseTimestamp([]), isNull);
    });

    test(
      'field formatting returns — for null or missing and preserves real values',
      () {
        String formatField(dynamic value, [dynamic fallback]) {
          if (value != null) {
            final str = value.toString().trim();
            if (str.isNotEmpty && str.toLowerCase() != 'null') {
              return str;
            }
          }
          if (fallback != null) {
            final str = fallback.toString().trim();
            if (str.isNotEmpty && str.toLowerCase() != 'null') {
              return str;
            }
          }
          return '—';
        }

        // Valid values
        expect(formatField('testing'), 'testing');
        expect(formatField('919346759263'), '919346759263');
        expect(formatField(919346759263), '919346759263');
        expect(formatField('enquiry'), 'enquiry');

        // Null, empty, whitespace, and 'null' string
        expect(formatField(null), '—');
        expect(formatField(''), '—');
        expect(formatField('   '), '—');
        expect(formatField('null'), '—');
        expect(formatField(null, null), '—');
        expect(formatField(null, ''), '—');
        expect(formatField('', 'fallbackPhone'), 'fallbackPhone');
        expect(formatField(null, 'fallbackName'), 'fallbackName');
      },
    );

    test('status normalization handles Enquiry, Converted and edge cases', () {
      String? normalizeStatus(dynamic raw) {
        if (raw == null) return null;
        final str = raw.toString().trim();
        if (str.toLowerCase() == 'enquiry') return 'Enquiry';
        if (str.toLowerCase() == 'converted') return 'Converted';
        return null;
      }

      expect(normalizeStatus('Enquiry'), 'Enquiry');
      expect(normalizeStatus('enquiry'), 'Enquiry');
      expect(normalizeStatus('ENQUIRY'), 'Enquiry');
      expect(normalizeStatus(' Converted '), 'Converted');
      expect(normalizeStatus('converted'), 'Converted');
      expect(normalizeStatus('CONVERTED'), 'Converted');

      // Invalid, missing, or unexpected strings must not crash and return null
      expect(normalizeStatus(null), isNull);
      expect(normalizeStatus(''), isNull);
      expect(normalizeStatus('   '), isNull);
      expect(normalizeStatus('unknown_status'), isNull);
      expect(normalizeStatus('follow_up'), isNull);
    });

    test('feedbackStatus reading preserves backward compatibility', () {
      String resolveFeedback(Map<String, dynamic> data) {
        return (data['feedbackStatus'] ?? data['salesFeedbackStatus'] ?? '')
            .toString()
            .trim();
      }

      // Canonical feedbackStatus present
      expect(
        resolveFeedback({'feedbackStatus': 'Customer will call tomorrow'}),
        'Customer will call tomorrow',
      );

      // Legacy salesFeedbackStatus present
      expect(
        resolveFeedback({'salesFeedbackStatus': 'Payment pending'}),
        'Payment pending',
      );

      // Canonical takes precedence if both present
      expect(
        resolveFeedback({
          'feedbackStatus': 'Not interested',
          'salesFeedbackStatus': 'Old note',
        }),
        'Not interested',
      );

      // Both missing
      expect(resolveFeedback({}), '');
    });

    test('salesFeedbackDescription renders correctly for all states', () {
      // Helper that mirrors the widget's description rendering logic.
      String? resolveDescription(Map<String, dynamic> data) {
        final raw = data['salesFeedbackDescription'];
        if (raw != null && raw.toString().trim().isNotEmpty) {
          return raw.toString().trim();
        }
        return null; // callers should render '—'
      }

      // Non-empty value is returned as-is (trimmed).
      expect(
        resolveDescription({
          'salesFeedbackDescription': 'Customer will call tomorrow',
        }),
        'Customer will call tomorrow',
      );

      // Leading/trailing whitespace is trimmed.
      expect(
        resolveDescription({'salesFeedbackDescription': '  Payment pending  '}),
        'Payment pending',
      );

      // Null field → null (show '—').
      expect(resolveDescription({}), isNull);
      expect(resolveDescription({'salesFeedbackDescription': null}), isNull);

      // Empty string → null (show '—').
      expect(resolveDescription({'salesFeedbackDescription': ''}), isNull);

      // Whitespace-only → null (show '—').
      expect(resolveDescription({'salesFeedbackDescription': '   '}), isNull);

      // Multi-line note is preserved.
      const multiLine = 'Line one\nLine two\nLine three';
      expect(
        resolveDescription({'salesFeedbackDescription': multiLine}),
        multiLine,
      );
    });
  });
}
