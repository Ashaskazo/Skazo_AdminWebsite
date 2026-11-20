import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skazo_admin/pages/promotion_details_page.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/utils/city_resolver.dart';

void main() {
  group('Edit Promotional Details Page - Comprehensive Test Suite', () {
    final sampleReferenceDoc = {
      'id': 'promo_test_doc_101',
      'activePlan': '999',
      'address': 'GMFG+9C8, Kanuru, 520004',
      'bannerUrl': 'https://firebasestorage.googleapis.com/test_banner.jpg',
      'brandName': 'testing ',
      'clicks': 15,
      'contactedCount': 7,
      'createdAt': Timestamp.fromDate(DateTime(2026, 11, 1, 10, 30)),
      'description': 'testing promotional description',
      'isVerified': false,
      'islocalbbaner': true,
      'location': {
        'geohash': 'tfcq5b483',
        'geopoint': const GeoPoint(16.5235138, 80.6761248),
      },
      'logoUrl': 'https://firebasestorage.googleapis.com/test_logo.png',
      'maxViews': 50000,
      'mobileNumber': '7894561230',
      'paymentDate': Timestamp.fromDate(DateTime(2026, 11, 5, 14, 0)),
      'paymentInitiated': false,
      'paymentLinkSend': true,
      'planExpiredDate': Timestamp.fromDate(DateTime(2026, 12, 5, 23, 59)),
      'socialLinks': 'https://instagram.com/testing_brand',
      'targetViews': 50000,
      'timestamp': Timestamp.fromDate(DateTime(2026, 11, 14, 16, 45)),
      'transactionId': '234',
      'uid': 'Ud6ceJ8Z4je1HYWEHYNQLzLzVcD2',
      'views': 250,
      'city': 'Vijayawada',
    };

    final scopeSuperAdmin = CityAccessScope.authorized(
      isSuperAdmin: true,
      adminId: 'super_admin_1',
      email: 'admin@skazo.test',
    );

    Widget createTestWidget(Map<String, dynamic> data) {
      return ProviderScope(
        overrides: [
          cityAccessScopeProvider.overrideWithValue(scopeSuperAdmin),
          propertyPincodesProvider.overrideWith((ref) async => const <String, List<String>>{}),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PromotionDetailsPage(promotionData: data),
          ),
        ),
      );
    }

    testWidgets('1. Displays every field from the reference document accurately', (tester) async {
      tester.view.physicalSize = const Size(1366, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(sampleReferenceDoc));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Top Header Overview
      expect(find.text('Edit Promotional Details'), findsOneWidget);
      expect(find.text('Doc ID: promo_test_doc_101'), findsOneWidget);
      expect(find.text('UID: Ud6ceJ8Z4je1HYWEHYNQLzLzVcD2'), findsOneWidget);

      // Section A: Promotion Information
      expect(find.text('A. Promotion Information'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'testing '), findsWidgets);
      expect(find.widgetWithText(TextField, '999'), findsOneWidget);
      expect(find.widgetWithText(TextField, '234'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Ud6ceJ8Z4je1HYWEHYNQLzLzVcD2'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'testing promotional description'), findsOneWidget);

      // Section B: Contact Information
      expect(find.text('B. Contact Information'), findsOneWidget);
      expect(find.widgetWithText(TextField, '7894561230'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'GMFG+9C8, Kanuru, 520004'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'https://instagram.com/testing_brand'), findsOneWidget);

      // Section C: Images and Media
      expect(find.text('C. Images and Media'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'https://firebasestorage.googleapis.com/test_banner.jpg'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'https://firebasestorage.googleapis.com/test_logo.png'), findsOneWidget);

      // Section D: Promotion Performance
      expect(find.text('D. Promotion Performance'), findsOneWidget);
      expect(find.widgetWithText(TextField, '250'), findsOneWidget); // views
      expect(find.widgetWithText(TextField, '15'), findsOneWidget);  // clicks
      expect(find.widgetWithText(TextField, '7'), findsOneWidget);   // contactedCount
      expect(find.widgetWithText(TextField, '50000'), findsNWidgets(2)); // targetViews & maxViews

      // Section E: Promotion Status
      expect(find.text('E. Promotion Status'), findsOneWidget);
      expect(find.text('Verified Promotion'), findsOneWidget);
      expect(find.text('Local Banner'), findsOneWidget);
      expect(find.text('Payment Initiated'), findsOneWidget);
      expect(find.text('Payment Link Sent'), findsOneWidget);

      // Section F: Payment and Expiry
      expect(find.text('F. Payment and Expiry Information'), findsOneWidget);
      expect(find.text('Payment Date'), findsOneWidget);
      expect(find.text('Plan Expiry Date'), findsOneWidget);

      // Section G: Location Details
      expect(find.text('G. Location Information'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'tfcq5b483'), findsOneWidget);
      expect(find.widgetWithText(TextField, '16.5235138'), findsOneWidget);
      expect(find.widgetWithText(TextField, '80.6761248'), findsOneWidget);

      // Section H: Date Information
      expect(find.text('H. Date Information'), findsOneWidget);
      expect(find.text('Created Date'), findsOneWidget);
      expect(find.text('Timestamp (Last Event/Update)'), findsOneWidget);
    });

    testWidgets('2. Gracefully handles null values and missing fields without crashing', (tester) async {
      final docWithNulls = {
        'id': 'promo_null_doc',
        'activePlan': null,
        'address': null,
        'bannerUrl': null,
        'brandName': null,
        'clicks': null,
        'contactedCount': null,
        'createdAt': null,
        'description': null,
        'isVerified': null,
        'islocalbbaner': null,
        'location': null,
        'logoUrl': null,
        'maxViews': null,
        'mobileNumber': null,
        'paymentDate': null,
        'paymentInitiated': null,
        'paymentLinkSend': null,
        'planExpiredDate': null,
        'socialLinks': null,
        'targetViews': null,
        'timestamp': null,
        'transactionId': null,
        'uid': null,
        'views': null,
      };

      tester.view.physicalSize = const Size(1366, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(docWithNulls));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Edit Promotional Details'), findsOneWidget);
      expect(find.text('Doc ID: promo_null_doc'), findsOneWidget);
      expect(find.text('Not Set (null)'), findsNWidgets(2)); // paymentDate & planExpiredDate
      expect(find.text('Not Available / Null'), findsNWidgets(2)); // createdAt & timestamp
    });

    testWidgets('3. Copy functionality is available and copies values with feedback', (tester) async {
      tester.view.physicalSize = const Size(1366, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(sampleReferenceDoc));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find copy button for Brand Name
      final copyBrandBtn = find.byTooltip('Copy Brand Name');
      expect(copyBrandBtn, findsOneWidget);

      await tester.tap(copyBrandBtn);
      await tester.pump();

      expect(find.text('Copied Brand Name to clipboard'), findsOneWidget);
    });

    testWidgets('4. Responsive rendering without RenderFlex overflow across viewports', (tester) async {
      final viewports = [
        const Size(360, 800),  // Mobile portrait
        const Size(844, 390),  // Mobile landscape
        const Size(768, 1024), // Tablet portrait
        const Size(1024, 768), // Tablet landscape
        const Size(1366, 768), // Desktop
      ];

      for (final vp in viewports) {
        tester.view.physicalSize = vp;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(createTestWidget(sampleReferenceDoc));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Edit Promotional Details'), findsOneWidget);
        expect(find.text('A. Promotion Information'), findsOneWidget);
      }
    });

    testWidgets('5. City-specific admin with matching assigned city can view and edit', (tester) async {
      final scopeVijayawada = CityAccessScope.authorized(
        isSuperAdmin: false,
        adminId: 'vijayawada_admin',
        email: 'vja@skazo.test',
        assignedCities: const ['Vijayawada'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cityAccessScopeProvider.overrideWithValue(scopeVijayawada),
            propertyPincodesProvider.overrideWith((ref) async => const <String, List<String>>{}),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PromotionDetailsPage(promotionData: sampleReferenceDoc),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Edit Promotional Details'), findsOneWidget);
      expect(find.text('A. Promotion Information'), findsOneWidget);
      expect(find.text('Access Denied'), findsNothing);
    });

    testWidgets('6. City-specific admin with unassigned city is denied access', (tester) async {
      final scopeGuntur = CityAccessScope.authorized(
        isSuperAdmin: false,
        adminId: 'guntur_admin',
        email: 'gnt@skazo.test',
        assignedCities: const ['Guntur'],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cityAccessScopeProvider.overrideWithValue(scopeGuntur),
            propertyPincodesProvider.overrideWith((ref) async => const <String, List<String>>{}),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PromotionDetailsPage(promotionData: sampleReferenceDoc), // City is Vijayawada
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Access Denied'), findsOneWidget);
      expect(find.text('A. Promotion Information'), findsNothing);
      expect(find.text('Save Changes'), findsNothing);
    });
  });
}
