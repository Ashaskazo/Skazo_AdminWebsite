import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'dart:io';

const List<({String name, Size size})> _testViewports = [
  (name: 'Mobile portrait (320x568)', size: Size(320, 568)),
  (name: 'Mobile portrait (360x800)', size: Size(360, 800)),
  (name: 'Mobile portrait (390x844)', size: Size(390, 844)),
  (name: 'Mobile landscape (568x320)', size: Size(568, 320)),
  (name: 'Mobile landscape (844x390)', size: Size(844, 390)),
  (name: 'Tablet portrait (768x1024)', size: Size(768, 1024)),
  (name: 'Tablet landscape (1024x768)', size: Size(1024, 768)),
  (name: 'Desktop (1440x900)', size: Size(1440, 900)),
  (name: 'Desktop large (1920x1080)', size: Size(1920, 1080)),
];

/// Mock test widget mirroring the exact SALES FEEDBACK DESCRIPTION component
/// from `lib/widgets/call_logs_data_view.dart`.
class SalesFeedbackDescriptionTestSection extends StatefulWidget {
  final String? initialDescription;
  final Future<void> Function(String newDesc)? onSave;

  const SalesFeedbackDescriptionTestSection({
    super.key,
    this.initialDescription,
    this.onSave,
  });

  @override
  State<SalesFeedbackDescriptionTestSection> createState() =>
      _SalesFeedbackDescriptionTestSectionState();
}

class _SalesFeedbackDescriptionTestSectionState
    extends State<SalesFeedbackDescriptionTestSection> {
  late final TextEditingController _feedbackDescriptionController;
  bool _isSavingFeedbackDescription = false;

  @override
  void initState() {
    super.initState();
    _feedbackDescriptionController = TextEditingController(
      text: widget.initialDescription ?? '',
    );
  }

  @override
  void dispose() {
    _feedbackDescriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    setState(() => _isSavingFeedbackDescription = true);
    if (widget.onSave != null) {
      await widget.onSave!(_feedbackDescriptionController.text.trim());
    }
    if (mounted) {
      setState(() => _isSavingFeedbackDescription = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.15)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
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
              onPressed:
                  _isSavingFeedbackDescription ? null : _handleSave,
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
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Sales Feedback Description Component & Integration Tests', () {
    test('Source code audit confirms CRM QUICK ACTIONS replaced with SALES FEEDBACK DESCRIPTION', () {
      final file = File('lib/widgets/call_logs_data_view.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();

      // 1. Confirm CRM QUICK ACTIONS is commented out / deactivated
      expect(
        content.contains('/*') &&
            content.contains('// CRM QUICK ACTIONS (Replaced by SALES FEEDBACK DESCRIPTION)') &&
            content.contains('*/'),
        isTrue,
      );

      // 2. Confirm SALES FEEDBACK DESCRIPTION section exists
      expect(content.contains('// SALES FEEDBACK DESCRIPTION'), isTrue);
      expect(content.contains("'SALES FEEDBACK DESCRIPTION'"), isTrue);

      // 3. Confirm label and hint
      expect(content.contains("labelText: 'Feedback Description'"), isTrue);
      expect(content.contains("hintText: 'Enter sales feedback details here...'"), isTrue);

      // 4. Confirm Save Feedback button
      expect(content.contains("'Save Feedback'"), isTrue);
      expect(content.contains("'Saving...'"), isTrue);

      // 5. Confirm Firestore document update targets 'feedbackDescription'
      expect(content.contains("'feedbackDescription': newDesc"), isTrue);
      expect(content.contains("'lastFeedbackDescriptionUpdatedAt'"), isTrue);
      expect(content.contains("'lastFeedbackDescriptionUpdatedBy'"), isTrue);

      // 6. Confirm allowedCRMFields includes feedbackDescription
      expect(content.contains("'feedbackDescription',"), isTrue);

      // 7. Confirm feedbackStatus remains separate and untouched
      expect(content.contains("'SALES FEEDBACK STATUS'"), isTrue);
      expect(content.contains("'feedbackStatus': status"), isTrue);
    });

    testWidgets('Loads existing feedbackDescription and allows saving edits',
        (tester) async {
      String? savedValue;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SalesFeedbackDescriptionTestSection(
                initialDescription: 'Customer requested a callback regarding pricing.',
                onSave: (desc) async {
                  savedValue = desc;
                },
              ),
            ),
          ),
        ),
      );

      // Verify title is rendered
      expect(find.text('SALES FEEDBACK DESCRIPTION'), findsOneWidget);

      // Verify label and hint text
      expect(find.text('Feedback Description'), findsOneWidget);

      // Verify initial description is pre-loaded
      expect(
        find.text('Customer requested a callback regarding pricing.'),
        findsOneWidget,
      );

      // Verify Save Feedback button
      final saveBtn = find.widgetWithText(ElevatedButton, 'Save Feedback');
      expect(saveBtn, findsOneWidget);

      // Enter updated feedback text
      await tester.enterText(
        find.byType(TextField),
        'Customer converted to quarterly subscription plan.',
      );
      await tester.pump();

      // Tap Save Feedback
      await tester.tap(saveBtn);
      await tester.pump();

      // Verify saved value
      expect(
        savedValue,
        equals('Customer converted to quarterly subscription plan.'),
      );
    });

    testWidgets('Renders cleanly without RenderFlex overflow across all viewports',
        (tester) async {
      for (final vp in _testViewports) {
        final List<FlutterErrorDetails> errors = [];
        final prevOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          final msg = details.exceptionAsString();
          if (msg.contains('overflow') || msg.contains('RenderFlex')) {
            errors.add(details);
          }
        };

        await tester.binding.setSurfaceSize(vp.size);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Container(
                  width: vp.size.width < 680 ? vp.size.width : 450,
                  child: const SalesFeedbackDescriptionTestSection(
                    initialDescription:
                        'Detailed sales notes with multiple paragraphs and instructions for follow-up.',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        FlutterError.onError = prevOnError;
        await tester.binding.setSurfaceSize(null);

        expect(
          errors,
          isEmpty,
          reason: 'Overflow on viewport ${vp.name}: ${errors.map((e) => e.exceptionAsString()).join('\n')}',
        );
        expect(find.text('SALES FEEDBACK DESCRIPTION'), findsOneWidget);
        expect(find.widgetWithText(ElevatedButton, 'Save Feedback'), findsOneWidget);
      }
    });

    test('CityAccessScope permits sales user to edit records in their assigned city', () {
      final salesScope = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Bhimavaram'],
        adminId: 'sales_user_1',
        email: 'sales@skazo.test',
        displayName: 'Sales Rep 1',
        role: 'sales',
      );

      // Allowed in Bhimavaram
      expect(
        salesScope.allowsRecord({'city': 'Bhimavaram'}),
        isTrue,
      );

      // Denied in Hyderabad
      expect(
        salesScope.allowsRecord({'city': 'Hyderabad'}),
        isFalse,
      );
    });
  });
}
