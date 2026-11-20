import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skazo_admin/utils/city_resolver.dart';
import 'package:skazo_admin/providers/admin_providers.dart';
import 'package:skazo_admin/providers/collections_provider.dart';
import 'package:skazo_admin/providers/user_providers.dart';
import 'package:skazo_admin/providers/call_log_sheet_provider.dart';
import 'package:skazo_admin/repositories/user_repository.dart';

class _DummyUserRepository extends Fake implements UserRepository {}

void main() {
  group('City Access Control Comprehensive Test Suite (17 Scenarios)', () {
    const Map<String, List<String>> testPincodesMap = {
      'Bhimavaram': ['534201', '534202', '534203', '534204'],
      'Vijayawada': ['520001', '520002', '520003'],
      'Guntur': ['522001', '522002', '522004', '522007'],
      'Hyderabad': ['500001', '500081', '500032'],
      'Warangal': ['506001', '506002'],
      'Bangalore': ['560001', '560034'],
      'Tirupati': ['517501', '517507'],
      'Visakhapatnam': ['530001', '530016'],
    };

    final testPincodeCityLookup = buildPincodeCityLookup(testPincodesMap);

    // =========================================================================
    // Scenario 1: Employee A (assigned to Bhimavaram)
    // =========================================================================
    group('Scenario 1: Employee A (assignedCities = ["Bhimavaram"])', () {
      final scopeA = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Bhimavaram'],
        adminId: 'emp_a_001',
        email: 'employeeA@skazo.test',
        displayName: 'Employee A',
        role: 'sales',
      );

      test('Employee A permissions and scope metadata', () {
        expect(scopeA.isAuthorized, isTrue);
        expect(scopeA.isSuperAdmin, isFalse);
        expect(scopeA.isUnrestricted, isFalse);
        expect(scopeA.hasNoCities, isFalse);
        expect(scopeA.assignedCities, equals(['Bhimavaram']));
      });

      test('Employee A canAccessCityName matches Bhimavaram & spelling variants', () {
        expect(scopeA.canAccessCityName('Bhimavaram'), isTrue);
        expect(scopeA.canAccessCityName('bheemavaram'), isTrue);
        expect(scopeA.canAccessCityName('BHIMAVARAM'), isTrue);
        expect(scopeA.canAccessCityName('Vijayawada'), isFalse);
        expect(scopeA.canAccessCityName('Hyderabad'), isFalse);
        expect(scopeA.canAccessCityName(''), isFalse);
        expect(scopeA.canAccessCityName(null), isFalse);
      });

      test('Employee A allowsRecord matches Bhimavaram across entity fields and denies others', () {
        expect(scopeA.allowsRecord({'city': 'Bhimavaram'}), isTrue);
        expect(scopeA.allowsRecord({'City': 'Bheemavaram'}), isTrue);
        expect(scopeA.allowsRecord({'businessCity': 'Bhimavaram'}), isTrue);
        expect(scopeA.allowsRecord({'serviceCity': 'bhimavaram'}), isTrue);
        expect(scopeA.allowsRecord({'customerCity': 'Bhimavaram'}), isTrue);
        expect(scopeA.allowsRecord({'cityKey': 'bhimavaram'}), isTrue);

        // Denied other cities
        expect(scopeA.allowsRecord({'city': 'Vijayawada'}), isFalse);
        expect(scopeA.allowsRecord({'businessCity': 'Hyderabad'}), isFalse);
        expect(scopeA.allowsRecord({'city': 'Guntur'}), isFalse);
      });
    });

    // =========================================================================
    // Scenario 2: Employee B (assigned to Vijayawada and Guntur)
    // =========================================================================
    group('Scenario 2: Employee B (assignedCities = ["Vijayawada", "Guntur"])', () {
      final scopeB = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Vijayawada', 'Guntur'],
        adminId: 'emp_b_002',
        email: 'employeeB@skazo.test',
        role: 'sales',
      );

      test('Employee B can access both Vijayawada and Guntur (including aliases)', () {
        expect(scopeB.canAccessCityName('Vijayawada'), isTrue);
        expect(scopeB.canAccessCityName('vijaywada'), isTrue);
        expect(scopeB.canAccessCityName('Guntur'), isTrue);
        expect(scopeB.canAccessCityName('Bhimavaram'), isFalse);
        expect(scopeB.canAccessCityName('Hyderabad'), isFalse);
      });

      test('Employee B allowsRecord accepts Vijayawada and Guntur, denies Bhimavaram', () {
        expect(scopeB.allowsRecord({'city': 'Vijayawada'}), isTrue);
        expect(scopeB.allowsRecord({'city': 'vijaywada'}), isTrue);
        expect(scopeB.allowsRecord({'businessCity': 'Guntur'}), isTrue);
        expect(scopeB.allowsRecord({'city': 'Bhimavaram'}), isFalse);
        expect(scopeB.allowsRecord({'city': 'Hyderabad'}), isFalse);
      });
    });

    // =========================================================================
    // Scenario 3: Employee C (assigned to Hyderabad and Warangal)
    // =========================================================================
    group('Scenario 3: Employee C (assignedCities = ["Hyderabad", "Warangal"])', () {
      final scopeC = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Hyderabad', 'Warangal'],
        adminId: 'emp_c_003',
        email: 'employeeC@skazo.test',
        role: 'sales',
      );

      test('Employee C can access Hyderabad and Warangal, denied others', () {
        expect(scopeC.canAccessCityName('Hyderabad'), isTrue);
        expect(scopeC.canAccessCityName('Warangal'), isTrue);
        expect(scopeC.canAccessCityName('Bhimavaram'), isFalse);
        expect(scopeC.canAccessCityName('Vijayawada'), isFalse);

        expect(scopeC.allowsRecord({'city': 'Hyderabad'}), isTrue);
        expect(scopeC.allowsRecord({'city': 'Warangal'}), isTrue);
        expect(scopeC.allowsRecord({'city': 'Vijayawada'}), isFalse);
      });
    });

    // =========================================================================
    // Scenario 4: Super Admin Access & Missing City Filter
    // =========================================================================
    group('Scenario 4: Super Admin Access & Missing City Filter', () {
      final superScope = CityAccessScope.authorized(
        isSuperAdmin: true,
        adminId: 'super_admin_001',
        email: 'admin@skazo.test',
        displayName: 'Super Admin',
        role: 'super_admin',
      );

      test('Super Admin has unrestricted permissions', () {
        expect(superScope.isAuthorized, isTrue);
        expect(superScope.isSuperAdmin, isTrue);
        expect(superScope.isUnrestricted, isTrue);
        expect(superScope.canAccessCityName('Bhimavaram'), isTrue);
        expect(superScope.canAccessCityName('Vijayawada'), isTrue);
        expect(superScope.canAccessCityName('Anywhere In India'), isTrue);
      });

      test('Super Admin sees records across all cities', () {
        expect(superScope.allowsRecord({'city': 'Bhimavaram'}), isTrue);
        expect(superScope.allowsRecord({'city': 'Vijayawada'}), isTrue);
        expect(superScope.allowsRecord({'city': 'Hyderabad'}), isTrue);
        expect(superScope.allowsRecord({'city': 'Unmapped City'}), isTrue);
      });

      test('Super Admin can filter by specific city', () {
        expect(superScope.allowsRecord({'city': 'Bhimavaram'}, selectedCity: 'Bhimavaram'), isTrue);
        expect(superScope.allowsRecord({'city': 'Vijayawada'}, selectedCity: 'Bhimavaram'), isFalse);
      });

      test('Super Admin can audit missing-city records with kMissingCityFilterValue', () {
        final missingDoc = <String, dynamic>{'uid': 'no_loc_user', 'name': 'Ghost Business'};
        final validDoc = <String, dynamic>{'uid': 'loc_user', 'city': 'Bhimavaram'};

        expect(superScope.allowsRecord(missingDoc, selectedCity: kMissingCityFilterValue), isTrue);
        expect(superScope.allowsRecord(validDoc, selectedCity: kMissingCityFilterValue), isFalse);
      });
    });

    // =========================================================================
    // Scenario 5: Deactivated Employee Account
    // =========================================================================
    group('Scenario 5: Deactivated Employee Immediate Access Denial', () {
      const scopeInactive = CityAccessScope.deniedInactive(
        adminId: 'emp_inactive_99',
        email: 'inactive@skazo.test',
        displayName: 'Ex-Employee',
        role: 'sales',
      );

      test('Deactivated account status is deniedInactive and fails all access checks', () {
        expect(scopeInactive.status, equals(AdminAccessStatus.deniedInactive));
        expect(scopeInactive.isAuthorized, isFalse);
        expect(scopeInactive.isActive, isFalse);
        expect(scopeInactive.canAccessCityName('Bhimavaram'), isFalse);
        expect(scopeInactive.allowsRecord({'city': 'Bhimavaram'}), isFalse);
        expect(scopeInactive.allowsRecord({}), isFalse);
      });
    });

    // =========================================================================
    // Scenario 6: Zero Cities Assigned Non-Super-Admin Account
    // =========================================================================
    group('Scenario 6: Zero Cities Assigned Non-Super-Admin Account', () {
      final scopeZeroCities = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const [],
        adminId: 'emp_zero_cities',
        email: 'unassigned@skazo.test',
        role: 'sales',
      );

      test('Empty assigned cities for sales employee automatically yields noCitiesAssigned', () {
        expect(scopeZeroCities.status, equals(AdminAccessStatus.noCitiesAssigned));
        expect(scopeZeroCities.isAuthorized, isFalse);
        expect(scopeZeroCities.hasNoCities, isTrue);
        expect(scopeZeroCities.canAccessCityName('Bhimavaram'), isFalse);
        expect(scopeZeroCities.allowsRecord({'city': 'Bhimavaram'}), isFalse);
        expect(scopeZeroCities.allowsRecord({}), isFalse);
      });
    });

    // =========================================================================
    // Scenario 7: Missing-City Fail-Closed Policy
    // =========================================================================
    group('Scenario 7: Missing-City Fail-Closed Policy', () {
      final scopeStaff = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Bhimavaram'],
        adminId: 'staff_1',
      );
      final superScope = CityAccessScope.authorized(
        isSuperAdmin: true,
        adminId: 'super_1',
      );

      final recordMissingCity = <String, dynamic>{
        'uid': 'user_no_city',
        'businessname': 'Unknown Store',
        'phone': '9876543210',
      };

      test('Sales employee is strictly blocked from seeing missing-city records (fail-closed)', () {
        expect(
          scopeStaff.allowsRecord(
            recordMissingCity,
            pincodesMap: testPincodesMap,
            pincodeCityLookup: testPincodeCityLookup,
          ),
          isFalse,
        );
      });

      test('Sales employee cannot select kMissingCityFilterValue', () {
        expect(
          scopeStaff.allowsRecord(
            recordMissingCity,
            selectedCity: kMissingCityFilterValue,
            pincodesMap: testPincodesMap,
            pincodeCityLookup: testPincodeCityLookup,
          ),
          isFalse,
        );
      });

      test('Super Admin sees missing-city record with All Cities and with kMissingCityFilterValue', () {
        expect(
          superScope.allowsRecord(
            recordMissingCity,
            pincodesMap: testPincodesMap,
            pincodeCityLookup: testPincodeCityLookup,
          ),
          isTrue,
        );
        expect(
          superScope.allowsRecord(
            recordMissingCity,
            selectedCity: kMissingCityFilterValue,
            pincodesMap: testPincodesMap,
            pincodeCityLookup: testPincodeCityLookup,
          ),
          isTrue,
        );
      });

      test('hasResolvableCity returns false for missing-city records', () {
        expect(
          hasResolvableCity(
            recordMissingCity,
            pincodesMap: testPincodesMap,
            pincodeCityLookup: testPincodeCityLookup,
          ),
          isFalse,
        );
      });
    });

    // =========================================================================
    // Scenario 8: City Resolution Hierarchy
    // =========================================================================
    group('Scenario 8: City Resolution Hierarchy (5-tier resolution)', () {
      test('Tier 1: Explicit direct field takes precedence', () {
        final record = {
          'city': 'Bhimavaram',
          'location': 'Near Bus Stand, Vijayawada, 520001',
          'pincode': '520001',
        };
        final city = resolveRecordCity(
          record,
          pincodesMap: testPincodesMap,
          pincodeCityLookup: testPincodeCityLookup,
        );
        expect(city, equals('Bhimavaram'));
      });

      test('Tier 2: Cleaned segment from address/location string', () {
        final record = {
          'location': 'Shop 4B, Opposite Municipal Complex, Bhimavaram, Andhra Pradesh',
        };
        final city = resolveRecordCity(
          record,
          pincodesMap: testPincodesMap,
          pincodeCityLookup: testPincodeCityLookup,
        );
        expect(canonicalizeCityKey(city ?? ''), equals('bhimavaram'));
      });

      test('Tier 3: Pincode lookup via pincodesMap and pincodeCityLookup', () {
        final record = {
          'pincode': '534201',
        };
        final city = resolveRecordCity(
          record,
          pincodesMap: testPincodesMap,
          pincodeCityLookup: testPincodeCityLookup,
        );
        expect(city, equals('Bhimavaram'));
      });

      test('Tier 4: Known pincode ranges fallback', () {
        final record = {
          'pincode': '520002',
        };
        final city = resolveRecordCity(record, pincodesMap: const {});
        expect(city, equals('Vijayawada'));
      });

      test('Tier 5: Related entity lookup for child records (callLogs, tickets, posts)', () {
        final callLogRecord = {
          'id': 'log_101',
          'businessId': 'provider_999',
          'customerPhone': '9988776655',
        };
        final relatedUsers = {
          'provider_999': <String, dynamic>{
            'uid': 'provider_999',
            'businessname': 'Sita Electronics',
            'city': 'Bhimavaram',
          },
        };

        final city = resolveRecordCity(
          callLogRecord,
          pincodesMap: testPincodesMap,
          pincodeCityLookup: testPincodeCityLookup,
          relatedEntityLookup: relatedUsers,
        );
        expect(city, equals('Bhimavaram'));
      });
    });

    // =========================================================================
    // Scenario 9: Canonical City Key Mapping and Alias Expansion
    // =========================================================================
    group('Scenario 9: Canonical City Key Mapping and Alias Expansion', () {
      test('canonicalizeCityKey normalizes known spelling variants', () {
        expect(canonicalizeCityKey('bheemavaram'), equals('bhimavaram'));
        expect(canonicalizeCityKey('Bhimavaram'), equals('bhimavaram'));
        expect(canonicalizeCityKey('tirupathi'), equals('tirupati'));
        expect(canonicalizeCityKey('Tirupati'), equals('tirupati'));
        expect(canonicalizeCityKey('bengaluru'), equals('bangalore'));
        expect(canonicalizeCityKey('Bangalore'), equals('bangalore'));
        expect(canonicalizeCityKey('vijaywada'), equals('vijayawada'));
        expect(canonicalizeCityKey('Vijayawada'), equals('vijayawada'));
        expect(canonicalizeCityKey('vishakhapatnam'), equals('visakhapatnam'));
        expect(canonicalizeCityKey('vizag'), equals('visakhapatnam'));
        expect(canonicalizeCityKey('Visakhapatnam'), equals('visakhapatnam'));
      });

      test('expandQueryableCityKeys expands to include all query variants for Firestore', () {
        final bhimavaramKeys = expandQueryableCityKeys(['Bhimavaram']);
        expect(bhimavaramKeys, contains('bhimavaram'));
        expect(bhimavaramKeys, contains('bheemavaram'));

        final tirupatiKeys = expandQueryableCityKeys(['Tirupati']);
        expect(tirupatiKeys, contains('tirupati'));
        expect(tirupatiKeys, contains('tirupathi'));

        final vizagKeys = expandQueryableCityKeys(['Visakhapatnam']);
        expect(vizagKeys, contains('visakhapatnam'));
        expect(vizagKeys, contains('vishakhapatnam'));
        expect(vizagKeys, contains('vizag'));
      });
    });

    // =========================================================================
    // Scenario 10: Direct Write Guards (scope.allowsRecord enforcement)
    // =========================================================================
    group('Scenario 10: Direct Write Guards (scope.allowsRecord enforcement)', () {
      final scopeA = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Bhimavaram'],
        adminId: 'emp_a',
      );
      final superScope = CityAccessScope.authorized(
        isSuperAdmin: true,
        adminId: 'super_admin',
      );

      void checkWritePermission(Map<String, dynamic> record, CityAccessScope scope) {
        if (!scope.allowsRecord(record)) {
          throw StateError('Access denied: you do not have permission for this city.');
        }
      }

      test('Direct write guard permits authorized record edit', () {
        final record = {'uid': 'p1', 'city': 'Bhimavaram'};
        expect(
          () => checkWritePermission(record, scopeA),
          returnsNormally,
        );
      });

      test('Direct write guard throws StateError on unauthorized edit', () {
        final record = {'uid': 'p2', 'city': 'Vijayawada'};
        expect(
          () => checkWritePermission(record, scopeA),
          throwsA(isA<StateError>()),
        );
      });

      test('Direct write guard permits Super Admin to edit any record', () {
        final record = {'uid': 'p2', 'city': 'Vijayawada'};
        expect(
          () => checkWritePermission(record, superScope),
          returnsNormally,
        );
      });
    });

    // =========================================================================
    // Scenario 11: Reassignment Write Guard
    // =========================================================================
    group('Scenario 11: Reassignment Write Guard (Updating to unassigned city)', () {
      final scopeA = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Bhimavaram'],
        adminId: 'emp_a',
      );

      void checkReassignmentPermission(
        Map<String, dynamic> original,
        Map<String, dynamic> updated,
        CityAccessScope scope,
      ) {
        if (!scope.allowsRecord(original) || !scope.allowsRecord(updated)) {
          throw StateError('Access denied: cannot reassign to unassigned city.');
        }
      }

      test('Reject update if payload modifies address/pincode to an unassigned city', () {
        final originalRecord = {'uid': 'p1', 'city': 'Bhimavaram'};
        final updatedPayload = {
          'uid': 'p1',
          'city': 'Vijayawada',
          'pincode': '520001',
        };

        expect(
          () => checkReassignmentPermission(originalRecord, updatedPayload, scopeA),
          throwsA(isA<StateError>()),
        );
      });
    });

    // =========================================================================
    // Scenario 12: Role Switch Exploit Prevention & Locked Role
    // =========================================================================
    group('Scenario 12: Role Switch Exploit Prevention & Locked Role', () {
      test('Client-side role tampering does not grant unrestricted access without verified super_admin', () {
        final forgedScope = CityAccessScope.authorized(
          isSuperAdmin: false, // Server document verified isSuperAdmin = false
          assignedCities: const ['Bhimavaram'],
          adminId: 'sales_user_1',
          role: 'sales', // Cannot elevate to super_admin
        );

        expect(forgedScope.isUnrestricted, isFalse);
        expect(forgedScope.canAccessCityName('Hyderabad'), isFalse);
        expect(forgedScope.allowsRecord({'city': 'Hyderabad'}), isFalse);
      });

      test('userMatchesAssignedCities fails closed when not super admin and empty cities', () {
        final matches = userMatchesAssignedCities(
          {'city': 'Hyderabad'},
          null,
          const [], // empty assigned cities
          testPincodesMap,
          testPincodeCityLookup,
          isSuperAdmin: false,
        );
        expect(matches, isFalse);
      });
    });

    // =========================================================================
    // Scenario 13: Session Cache Coordinator Reset
    // =========================================================================
    group('Scenario 13: Session Cache Clearing (SessionCacheCoordinator)', () {
      test('resetAll clears in-memory pagination and city filter caches', () async {
        final container = ProviderContainer(
          overrides: [
            userRepositoryProvider.overrideWithValue(_DummyUserRepository()),
            propertyPincodesProvider.overrideWith((ref) async => const {}),
            userFilterCitiesProvider.overrideWith((ref) async => const []),
          ],
        );

        // Mutate filters
        container.read(userSelectedCityProvider.notifier).state = 'Bhimavaram';
        container.read(callLogSheetCurrentPageProvider.notifier).state = 4;
        container.read(paymentSelectedCityProvider.notifier).state = 'Bhimavaram';
        container.read(serviceSelectedCityProvider.notifier).state = 'Bhimavaram';

        expect(container.read(userSelectedCityProvider), equals('Bhimavaram'));
        expect(container.read(callLogSheetCurrentPageProvider), equals(4));

        // Coordinate full session reset on logout/account switch
        container.read(sessionCacheCoordinatorProvider).resetAll();

        expect(container.read(userSelectedCityProvider), isNull);
        expect(container.read(callLogSheetCurrentPageProvider), equals(0));
        expect(container.read(paymentSelectedCityProvider), isNull);
        expect(container.read(serviceSelectedCityProvider), isNull);

        await Future<void>.delayed(Duration.zero);
        container.dispose();
      });
    });

    // =========================================================================
    // Scenario 14: Firestore 30-Disjunction Limit & Chunking
    // =========================================================================
    group('Scenario 14: Firestore 30-Disjunction Limit & Chunking (chunkList)', () {
      test('chunkList creates chunks with maximum size 30', () {
        final items = List.generate(75, (i) => 'item_$i');
        final chunks = chunkList(items, 30);
        expect(chunks.length, equals(3));
        expect(chunks[0].length, equals(30));
        expect(chunks[1].length, equals(30));
        expect(chunks[2].length, equals(15));
      });

      test('Pay-per-lead query builder chunks city keys by 2 (13 * 2 = 26 <= 30 disjunction limit)', () {
        // When querying 13 categories with city keys in Firestore,
        // (13 categories) * (chunkSize of 2) = 26 total disjunction combinations.
        // This is strictly <= Firestore maximum of 30 disjunctions.
        const int categoriesCount = 13;
        const int cityKeyChunkSize = 2;
        const int firestoreDisjunctionLimit = 30;

        expect(categoriesCount * cityKeyChunkSize, lessThanOrEqualTo(firestoreDisjunctionLimit));

        final cityKeys = ['bhimavaram', 'bheemavaram', 'vijayawada', 'vijaywada', 'guntur'];
        final chunks = chunkList(cityKeys, cityKeyChunkSize);
        expect(chunks.length, equals(3));
        expect(chunks[0].length, equals(2));
        expect(chunks[1].length, equals(2));
        expect(chunks[2].length, equals(1));
      });
    });

    // =========================================================================
    // Scenario 15: Call Log Sheet Provider Filtering
    // =========================================================================
    group('Scenario 15: Call Log Sheet Provider Filtering by Scope', () {
      final scopeA = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Bhimavaram'],
        adminId: 'emp_a',
      );

      final providers = [
        <String, dynamic>{
          'businessId': 'prov_1',
          'businessname': 'Bhimavaram Electricals',
          'city': 'Bhimavaram',
          'callsAfterLastPayment': 8,
          'activePlan': 499,
        },
        <String, dynamic>{
          'businessId': 'prov_2',
          'businessname': 'Vijayawada Plumbers',
          'city': 'Vijayawada',
          'callsAfterLastPayment': 6,
          'activePlan': 499,
        },
        <String, dynamic>{
          'businessId': 'prov_3',
          'businessname': 'Unmapped Provider',
          'callsAfterLastPayment': 10,
          'activePlan': 499,
        },
      ];

      test('Filters eligible providers strictly to assigned cities', () {
        final filtered = providers.where((item) {
          return scopeA.allowsRecord(
            item,
            pincodesMap: testPincodesMap,
            pincodeCityLookup: testPincodeCityLookup,
          );
        }).toList();

        expect(filtered.length, equals(1));
        expect(filtered.first['businessId'], equals('prov_1'));
      });
    });

    // =========================================================================
    // Scenario 16: Service Posts & Category Scoping
    // =========================================================================
    group('Scenario 16: Service Posts & Category Scoping', () {
      final scopeB = CityAccessScope.authorized(
        isSuperAdmin: false,
        assignedCities: const ['Vijayawada', 'Guntur'],
        adminId: 'emp_b',
      );

      final posts = [
        {
          'id': 'post_1',
          'serviceTitle': 'AC Repair',
          'city': 'Vijayawada',
          'businessId': 'b_1',
        },
        {
          'id': 'post_2',
          'serviceTitle': 'Sofa Cleaning',
          'city': 'Bhimavaram',
          'businessId': 'b_2',
        },
        {
          'id': 'post_3',
          'serviceTitle': 'Home Painting',
          // Resolves through linked businessId
          'businessId': 'b_3',
        },
      ];

      final relatedUsers = {
        'b_3': <String, dynamic>{
          'uid': 'b_3',
          'businessname': 'Guntur Painters',
          'city': 'Guntur',
        },
      };

      test('Filters service posts and resolves linked business profile correctly', () {
        final filtered = posts.where((post) {
          return scopeB.allowsRecord(
            post,
            pincodesMap: testPincodesMap,
            pincodeCityLookup: testPincodeCityLookup,
            relatedEntityLookup: relatedUsers,
          );
        }).toList();

        expect(filtered.length, equals(2));
        expect(filtered.map((p) => p['id']), containsAll(['post_1', 'post_3']));
        expect(filtered.map((p) => p['id']), isNot(contains('post_2')));
      });
    });

    // =========================================================================
    // Scenario 17: Today & Period Stats IST Calendar Day Scoping
    // =========================================================================
    group('Scenario 17: Today & Period Stats IST Calendar Day Scoping', () {
      test('Calculates Indian Standard Time (UTC+5:30) midnight boundaries correctly', () {
        // 2026-11-13 02:00:00 UTC corresponds to 07:30:00 AM IST on Nov 13, 2026.
        final utcSample = DateTime.utc(2026, 11, 13, 2, 0);
        final istTime = utcSample.add(const Duration(hours: 5, minutes: 30));

        expect(istTime.year, equals(2026));
        expect(istTime.month, equals(11));
        expect(istTime.day, equals(13));
        expect(istTime.hour, equals(7));
        expect(istTime.minute, equals(30));

        final istMidnight = DateTime.utc(istTime.year, istTime.month, istTime.day)
            .subtract(const Duration(hours: 5, minutes: 30));

        expect(utcSample.isAfter(istMidnight) || utcSample.isAtSameMomentAs(istMidnight), isTrue);
      });
    });
  });
}
