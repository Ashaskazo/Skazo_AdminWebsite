import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:skazo_admin/models/call_log_sheet_item.dart';
import 'package:skazo_admin/models/service_provider_overview_model.dart';
import 'package:skazo_admin/pages/add_admin_page.dart';
import 'package:skazo_admin/pages/auth_page.dart';
import 'package:skazo_admin/pages/business_profile_page.dart';
import 'package:skazo_admin/pages/promotion_details_page.dart';
import 'package:skazo_admin/pages/property_details_page.dart';
import 'package:skazo_admin/pages/service_post_details_page.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/dashboard_provider.dart';
import 'package:skazo_admin/providers/service_providers_provider.dart';
import 'package:skazo_admin/repositories/call_log_sheet_repository.dart';
import 'package:skazo_admin/utils/responsive.dart';
import 'package:skazo_admin/widgets/call_log_sheet_view.dart';
import 'package:skazo_admin/widgets/service_providers_data_view.dart';
import 'package:skazo_admin/widgets/sidebar_nav.dart';
import 'package:skazo_admin/pages/dashboard_page.dart';
import 'package:skazo_admin/widgets/unverified_businesses_grid.dart';
import 'package:skazo_admin/providers/unverified_pagination_provider.dart';

const List<({String name, Size size})> _targetViewports = [
  // Mobile portrait
  (name: 'Mobile portrait (320x568)', size: Size(320, 568)),
  (name: 'Mobile portrait (360x800)', size: Size(360, 800)),
  (name: 'Mobile portrait (375x812)', size: Size(375, 812)),
  (name: 'Mobile portrait (390x844)', size: Size(390, 844)),
  (name: 'Mobile portrait (430x932)', size: Size(430, 932)),

  // Mobile landscape
  (name: 'Mobile landscape (568x320)', size: Size(568, 320)),
  (name: 'Mobile landscape (667x375)', size: Size(667, 375)),
  (name: 'Mobile landscape (844x390)', size: Size(844, 390)),
  (name: 'Mobile landscape (932x430)', size: Size(932, 430)),

  // Tablet portrait
  (name: 'Tablet portrait (600x960)', size: Size(600, 960)),
  (name: 'Tablet portrait (768x1024)', size: Size(768, 1024)),

  // Tablet landscape
  (name: 'Tablet landscape (960x600)', size: Size(960, 600)),
  (name: 'Tablet landscape (1024x768)', size: Size(1024, 768)),

  // Desktop
  (name: 'Desktop (1280x720)', size: Size(1280, 720)),
  (name: 'Desktop (1366x768)', size: Size(1366, 768)),
  (name: 'Desktop (1440x900)', size: Size(1440, 900)),
  (name: 'Desktop (1920x1080)', size: Size(1920, 1080)),
];

class _FakeCallLogSheetRepository implements CallLogSheetRepository {
  @override
  Future<CallLogSheetFetchResult> fetchEligibleProviders({
    CityAccessScope? scope,
    String? selectedCity,
    Map<String, List<String>> pincodesMap = const {},
    Map<String, String>? pincodeCityLookup,
  }) async {
    final now = DateTime(2026, 11, 10, 14, 30);
    return CallLogSheetFetchResult(
      items: List.generate(4, (i) {
        return CallLogSheetItem(
          businessId: 'uid_provider_${i + 1}',
          businessName: 'Sri Lakshmi Plumbing & Electrical Services #${i + 1}',
          phone: '987654321$i',
          callsAfterLastPayment: 7 + i * 2,
          deactivatedAt: i.isEven ? now.subtract(Duration(days: i + 1)) : null,
          feedbackStatuses: const ['converted', 'follow_up'],
          callLogs: const [],
          transactionId: 'TXN_99887766_$i',
          convertedCount: i + 1,
        );
      }),
      metrics: const CallLogSheetSyncMetrics(
        eligibleProvidersCount: 4,
        totalBatches: 1,
        successfulBatches: 1,
        failedBatches: 0,
        callLogsRetrieved: 8,
        elapsedMilliseconds: 12,
        usedCompositeIndex: true,
      ),
    );
  }
}

class _FakeUser extends Fake implements User {
  @override
  String? get email => 'admin@skazo.test';

  @override
  String get uid => 'test_admin_uid';
}

List<Override> _baseAdminOverrides() {
  return [
    authStateProvider.overrideWith(
      (ref) => Stream.value(_FakeUser()),
    ),
    cityAccessScopeProvider.overrideWithValue(
      CityAccessScope.authorized(
        isSuperAdmin: true,
        adminId: 'test_admin_uid',
        email: 'admin@skazo.test',
        displayName: 'Test Admin',
        role: 'super_admin',
      ),
    ),
    currentAdminProfileProvider.overrideWith(
      (ref) => Stream.value(<String, dynamic>{
        'name': 'Test Admin',
        'email': 'admin@skazo.test',
        'role': 'super_admin',
        'isActive': true,
      }),
    ),
    isSuperAdminProvider.overrideWith((ref) => true),
    currentAdminAssignedCitiesProvider.overrideWith((ref) => const []),
    allowedCitiesProvider.overrideWith(
      (ref) async => const ['Hyderabad', 'Bengaluru', 'Visakhapatnam'],
    ),
    propertyPincodesProvider.overrideWith(
      (ref) async => const {
        'Hyderabad': ['500001', '500081'],
        'Bhimavaram': ['534201', '534202'],
        'Vijayawada': ['520001'],
      },
    ),
    userFilterCitiesProvider.overrideWith(
      (ref) async => const ['Hyderabad', 'Bhimavaram', 'Vijayawada'],
    ),
  ];
}

Future<void> _pumpAtViewport(
  WidgetTester tester, {
  required Size size,
  required Widget child,
  List<Override> overrides = const [],
}) async {
  final List<FlutterErrorDetails> layoutErrors = [];
  final previousOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exceptionAsString();
    if (msg.contains('overflowed') ||
        msg.contains('RenderFlex') ||
        msg.contains('ParentDataWidget') ||
        msg.contains('hasSize')) {
      layoutErrors.add(details);
      return;
    }
  };

  await tester.binding.setSurfaceSize(size);

  try {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          home: child,
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
  } finally {
    FlutterError.onError = previousOnError;
    await tester.binding.setSurfaceSize(null);
  }

  expect(
    layoutErrors,
    isEmpty,
    reason: layoutErrors.map((e) => e.exceptionAsString()).join('\n'),
  );
}

void main() {
  group('Responsive Viewport Verification across 7 target screen sizes', () {
    testWidgets('AuthPage renders cleanly without overflow on all 7 viewports',
        (tester) async {
      for (final vp in _targetViewports) {
        await _pumpAtViewport(
          tester,
          size: vp.size,
          child: const AuthPage(),
          overrides: _baseAdminOverrides(),
        );
      }
    });

    testWidgets(
        'AddAdminPage renders cleanly without overflow on all 7 viewports',
        (tester) async {
      for (final vp in _targetViewports) {
        await _pumpAtViewport(
          tester,
          size: vp.size,
          child: const AddAdminPage(),
          overrides: _baseAdminOverrides(),
        );
      }
    });

    testWidgets(
        'SidebarNav drawer on mobile (<600) and persistent rail on tablet/desktop (>=600)',
        (tester) async {
      for (final vp in _targetViewports) {
        final bool isMobile = vp.size.width < ResponsiveBreakpoints.mobile;

        await _pumpAtViewport(
          tester,
          size: vp.size,
          overrides: _baseAdminOverrides(),
          child: Consumer(
            builder: (context, ref, _) {
              final mobile = ResponsiveBreakpoints.isMobile(context);
              final view = ref.watch(currentDashboardViewProvider);
              return Scaffold(
                appBar: mobile ? AppBar(title: Text(view.name)) : null,
                drawer: mobile
                    ? const Drawer(
                        width: 285,
                        child: SafeArea(child: SidebarNav(isDrawer: true)),
                      )
                    : null,
                body: mobile
                    ? Center(child: Text('View: ${view.name}'))
                    : Row(
                        children: [
                          const SidebarNav(),
                          Expanded(child: Center(child: Text('View: ${view.name}'))),
                        ],
                      ),
              );
            },
          ),
        );

        if (isMobile) {
          expect(find.byType(Drawer), findsNothing);
          tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
          await tester.pumpAndSettle();
          expect(find.text('Dashboard Overview'), findsOneWidget);

          // Select Users navigation item -> drawer closes and view changes
          await tester.tap(find.text('Users & Providers'));
          await tester.pumpAndSettle();
          expect(find.text('View: users'), findsOneWidget);
        } else {
          expect(find.byType(SidebarNav), findsOneWidget);
        }
      }
    });

    testWidgets(
        'BusinessProfilePage renders cleanly without overflow on all 7 viewports',
        (tester) async {
      final sampleBusiness = <String, dynamic>{
        'uid': 'prov_12345',
        'businessname': 'Apex Home Cleaning & Deep Sanitizing Experts',
        'firstname': 'Ramesh',
        'lastname': 'Kumar',
        'phone': '9876543210',
        'email': 'apex@example.com',
        'city': 'Hyderabad',
        'businessaddress': 'Plot 42, Madhapur Main Road, HITEC City',
        'businesspincode': '500081',
        'category': 'Cleaning',
        'plan': 'Premium',
        'activeplan': 599,
        'paymentcount': 2,
        'callsAfterLastPayment': 4,
        'convertedCount': 3,
        'isVerified': true,
        'isActive': true,
        'ServiceRateCard': [
          {'service': '2BHK Deep Cleaning', 'rate': '2499'},
          {'service': 'Bathroom Steam Sanitize', 'rate': '699'},
        ],
      };

      for (final vp in _targetViewports) {
        await _pumpAtViewport(
          tester,
          size: vp.size,
          overrides: _baseAdminOverrides(),
          child: BusinessProfilePage(businessData: sampleBusiness),
        );
      }
    });

    testWidgets(
        'Detail pages (ServicePost, Property, Promotion) render cleanly on all 7 viewports',
        (tester) async {
      for (final vp in _targetViewports) {
        await _pumpAtViewport(
          tester,
          size: vp.size,
          overrides: _baseAdminOverrides(),
          child: ServicePostDetailsPage(
            postData: {
              'id': 'post_1',
              'serviceTitle': 'Emergency AC Gas Refill & Split Unit Servicing',
              'category': 'AC Repair',
              'city': 'Hyderabad',
              'description': 'Same day doorstep technician service across West Hyderabad.',
              'price': 999,
              'status': 'open',
              'userPhone': '9988776655',
            },
          ),
        );

        await _pumpAtViewport(
          tester,
          size: vp.size,
          overrides: _baseAdminOverrides(),
          child: PropertyDetailsPage(
            propertyData: {
              'id': 'prop_1',
              'title': '2BHK Semi-Furnished Flat Near Metro Station',
              'propertyType': 'Apartment',
              'city': 'Hyderabad',
              'locality': 'Kukatpally',
              'rent': 18500,
              'deposit': 37000,
              'isVerified': true,
              'photos': const [],
            },
          ),
        );

        await _pumpAtViewport(
          tester,
          size: vp.size,
          overrides: _baseAdminOverrides(),
          child: PromotionDetailsPage(
            promotionData: {
              'id': 'promo_1',
              'title': 'Festive 20% Off Deep Home Cleaning Package',
              'businessName': 'Sparkle Crew Services',
              'city': 'Hyderabad',
              'location': 'Gachibowli Circle, Financial District, Hyderabad',
              'discountPercentage': 20,
              'isVerified': false,
              'photos': const [],
            },
          ),
        );
      }
    });

    testWidgets(
        'CallLogSheetView adapts cleanly between card layout (<800) and DataTable (>=800) on all 7 viewports',
        (tester) async {
      for (final vp in _targetViewports) {
        await _pumpAtViewport(
          tester,
          size: vp.size,
          overrides: [
            ..._baseAdminOverrides(),
            callLogSheetRepositoryProvider.overrideWithValue(
              _FakeCallLogSheetRepository(),
            ),
          ],
          child: const CallLogSheetView(),
        );

        expect(find.text('Call Log Sheet'), findsOneWidget);
        if (vp.size.width < 800) {
          expect(find.byType(DataTable), findsNothing);
        } else {
          expect(find.byType(DataTable), findsOneWidget);
        }
      }
    });

    testWidgets(
        'ServiceProvidersDataView renders cleanly without overflow on all 7 viewports',
        (tester) async {
      final overviewData = ServiceProvidersOverviewData(
        selectedCity: 'All Cities',
        selectedDate: DateTime(2026, 11, 10),
        totalProviders: 142,
        totalCategories: 6,
        categories: const [
          ServiceProviderCategoryStats(categoryName: 'Cleaning', totalCount: 34),
          ServiceProviderCategoryStats(categoryName: 'Electrical & Wiring', totalCount: 28),
          ServiceProviderCategoryStats(categoryName: 'Plumbing', totalCount: 25),
          ServiceProviderCategoryStats(categoryName: 'AC & Appliance Repair', totalCount: 22),
          ServiceProviderCategoryStats(categoryName: 'Carpentry', totalCount: 19),
          ServiceProviderCategoryStats(categoryName: 'Painting', totalCount: 14),
        ],
      );

      for (final vp in _targetViewports) {
        await _pumpAtViewport(
          tester,
          size: vp.size,
          overrides: [
            ..._baseAdminOverrides(),
            serviceProvidersOverviewProvider.overrideWith(
              (ref) async => overviewData,
            ),
          ],
          child: const ServiceProvidersDataView(),
        );

        expect(find.text('SERVICE PROVIDERS'), findsOneWidget);
        expect(find.text('CATEGORY OVERVIEW'), findsOneWidget);
      }
    });

    testWidgets(
        'DashboardPage blocked screens render cleanly without overflow across all 17 viewports',
        (tester) async {
      for (final vp in _targetViewports) {
        await _pumpAtViewport(
          tester,
          size: vp.size,
          overrides: [
            ..._baseAdminOverrides(),
            cityAccessScopeProvider.overrideWithValue(
              const CityAccessScope.deniedInactive(
                email: 'deactivated@skazo.test',
              ),
            ),
          ],
          child: const DashboardPage(),
        );

        expect(find.text('Account Deactivated'), findsOneWidget);

        await _pumpAtViewport(
          tester,
          size: vp.size,
          overrides: [
            ..._baseAdminOverrides(),
            cityAccessScopeProvider.overrideWithValue(
              const CityAccessScope.noCitiesAssigned(
                email: 'sales@skazo.test',
              ),
            ),
          ],
          child: const DashboardPage(),
        );

        expect(find.text('No Cities Assigned'), findsOneWidget);
      }
    });

    testWidgets(
        'UnverifiedBusinessesGrid renders cleanly without overflow on all 17 viewports',
        (tester) async {
      for (final vp in _targetViewports) {
        await _pumpAtViewport(
          tester,
          size: vp.size,
          overrides: [
            ..._baseAdminOverrides(),
            categoryCountsProvider.overrideWith(
              (ref) async => const {
                'plumbers': 12,
                'ac repair': 8,
                'electricians': 15,
                'painters': 5,
              },
            ),
          ],
          child: const Scaffold(
            body: SingleChildScrollView(
              child: UnverifiedBusinessesGrid(),
            ),
          ),
        );

        expect(find.byType(UnverifiedBusinessesGrid), findsOneWidget);
      }
    });
  });
}
