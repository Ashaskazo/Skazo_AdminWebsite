import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:skazo_admin/models/user_model.dart';

void main() {
  group('Pay Per Lead UserModel Tests', () {
    test('Provider with payperLeadcharge = 60 parses correctly', () {
      final data = {
        'uid': 'prov_123',
        'isuser': false,
        'businessname': 'SS Air care system',
        'phone': 916309596316,
        'businessaddress': '67-1-29/3, Vijayawada, 520010, India',
        'city': 'Vijayawada',
        'cityKey': 'vijayawada',
        'payperLeadcharge': 60,
        'lastpaymentpayperlead': Timestamp.fromDate(DateTime.utc(2026, 9, 15, 8, 30)),
        'lastpayperleadtransactionid': 'pay_Tc9NK7WxADfJfv',
        'overallpayperleadamount': 540,
        'AtivePlan': 599,
      };

      final user = UserModel.fromMap('prov_123', data);

      expect(user.uid, 'prov_123');
      expect(user.isuser, false);
      expect(user.businessname, 'SS Air care system');
      expect(user.phone, 916309596316);
      expect(user.payperLeadCharge, 60);
      expect(user.lastpaymentpayperlead?.toUtc(), DateTime.utc(2026, 9, 15, 8, 30));
      expect(user.lastpayperleadtransactionid, 'pay_Tc9NK7WxADfJfv');
      expect(user.overallpayperleadamount, 540);
      expect(user.activePlan, 599);
    });

    test('Provider with payperLeadcharge = 0 parses correctly', () {
      final data = {
        'uid': 'prov_zero',
        'isuser': false,
        'payperLeadcharge': 0,
        'lastpaymentpayperlead': Timestamp.fromDate(DateTime.utc(2026, 9, 14, 10, 0)),
        'lastpayperleadtransactionid': 'pay_ZERO12345',
      };

      final user = UserModel.fromMap('prov_zero', data);

      expect(user.payperLeadCharge, 0);
      expect(user.lastpaymentpayperlead, isNotNull);
      expect(user.lastpayperleadtransactionid, 'pay_ZERO12345');
    });

    test('Provider without PPL fields does not crash; fields are null', () {
      final data = {
        'uid': 'prov_unpaid',
        'isuser': false,
        'payperLeadcharge': 40,
        // no lastpaymentpayperlead
        // no lastpayperleadtransactionid
        // no overallpayperleadamount
      };

      final user = UserModel.fromMap('prov_unpaid', data);

      expect(user.payperLeadCharge, 40);
      expect(user.lastpaymentpayperlead, isNull);
      expect(user.lastpayperleadtransactionid, isNull);
      expect(user.overallpayperleadamount, isNull);
    });

    test('overallpayperleadamount parses from Firestore field', () {
      final data = {
        'uid': 'prov_overall',
        'isuser': false,
        'payperLeadcharge': 60,
        'overallpayperleadamount': 360,
      };
      final user = UserModel.fromMap('prov_overall', data);
      expect(user.overallpayperleadamount, 360);
    });

    test('overallpayperleadamount is null when field is absent', () {
      final data = {
        'uid': 'prov_no_overall',
        'isuser': false,
        'payperLeadcharge': 80,
      };
      final user = UserModel.fromMap('prov_no_overall', data);
      expect(user.overallpayperleadamount, isNull);
    });

    test('PPL qualification: payperLeadcharge > 0 selects, == 0 does not', () {
      final providerWithCharge = UserModel.fromMap('a', {
        'isuser': false,
        'payperLeadcharge': 60,
      });
      final providerNoCharge = UserModel.fromMap('b', {
        'isuser': false,
        'payperLeadcharge': 0,
      });
      final customer = UserModel.fromMap('c', {
        'isuser': true,
        'payperLeadcharge': 60,
      });

      // Only isuser==false AND payperLeadcharge>0 qualifies
      bool qualifies(UserModel u) =>
          !u.isuser && (u.payperLeadCharge ?? 0) > 0;

      expect(qualifies(providerWithCharge), isTrue);
      expect(qualifies(providerNoCharge), isFalse);
      expect(qualifies(customer), isFalse);
    });

    test('UserModel.toMap() excludes PPL read-only fields', () {
      final user = UserModel(
        id: 'prov_test',
        uid: 'prov_test',
        isuser: false,
        payperLeadCharge: 120,
        lastpaymentpayperlead: DateTime.utc(2026, 9, 15),
        lastpayperleadtransactionid: 'pay_ABC123',
        overallpayperleadamount: 600,
      );

      final map = user.toMap();

      // toMap must NOT include these read-only PPL fields to avoid write leakage
      expect(map.containsKey('lastpaymentpayperlead'), isFalse);
      expect(map.containsKey('lastpayperleadtransactionid'), isFalse);
      expect(map.containsKey('overallpayperleadamount'), isFalse);
    });
  });

  group('Pay Per Lead Currency Formatting Tests', () {
    String formatCurrency(num? value) {
      final intVal = (value ?? 0).toInt();
      final formatter = NumberFormat('#,##,###');
      return '₹${formatter.format(intVal)}';
    }

    test('Formats 0 as ₹0', () {
      expect(formatCurrency(0), '₹0');
    });

    test('Formats null as ₹0', () {
      expect(formatCurrency(null), '₹0');
    });

    test('Formats 40 as ₹40', () {
      expect(formatCurrency(40), '₹40');
    });

    test('Formats 60 as ₹60', () {
      expect(formatCurrency(60), '₹60');
    });

    test('Formats 1000 as ₹1,000', () {
      expect(formatCurrency(1000), '₹1,000');
    });

    test('Formats 10000 as ₹10,000', () {
      expect(formatCurrency(10000), '₹10,000');
    });
  });

  group('Pay Per Lead IST Date Range Calculation Tests', () {
    test('Calculates correct UTC boundaries for IST calendar dates', () {
      final dateFrom = DateTime(2026, 9, 10);
      final dateTo = DateTime(2026, 9, 12);

      // IST is UTC + 5:30
      final fromIstMidnight = DateTime.utc(dateFrom.year, dateFrom.month, dateFrom.day);
      final fromUtc = fromIstMidnight.subtract(const Duration(hours: 5, minutes: 30));

      final toIstNextMidnight = DateTime.utc(dateTo.year, dateTo.month, dateTo.day).add(const Duration(days: 1));
      final toExclusiveUtc = toIstNextMidnight.subtract(const Duration(hours: 5, minutes: 30));

      // 10 Sep 2026 00:00:00 IST is 9 Sep 2026 18:30:00 UTC
      expect(fromUtc, DateTime.utc(2026, 9, 9, 18, 30));

      // 13 Sep 2026 00:00:00 IST is 12 Sep 2026 18:30:00 UTC
      expect(toExclusiveUtc, DateTime.utc(2026, 9, 12, 18, 30));

      // Records on the end date (e.g. 12 Sep 2026 at 14:00 IST = 08:30 UTC) are included
      final timestampOnEndDate = DateTime.utc(2026, 9, 12, 8, 30);
      expect(!timestampOnEndDate.isBefore(fromUtc) && timestampOnEndDate.isBefore(toExclusiveUtc), isTrue);

      // Records on the next day (13 Sep 2026 at 00:01 IST) are excluded
      final timestampNextDay = DateTime.utc(2026, 9, 12, 18, 31);
      expect(timestampNextDay.isBefore(toExclusiveUtc), isFalse);
    });
  });
}
