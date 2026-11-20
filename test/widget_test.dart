import 'package:flutter_test/flutter_test.dart';
import 'package:skazo_admin/models/payment_record.dart';

void main() {
  test('PaymentStream enum names and display labels', () {
    expect(PaymentStream.providerSubscription.displayName, 'Provider Subscription');
    expect(PaymentStream.payPerLeadOutstanding.displayName, 'Pay-per-Lead (Outstanding)');
    expect(PaymentStream.payPerLeadCollected.displayName, 'Pay-per-Lead (Collected)');
    expect(PaymentStream.tenantContact.displayName, 'Tenant Property Contact');
    expect(PaymentStream.propertyListing.displayName, 'Property Listing / Premium');
    expect(PaymentStream.agentVerification.displayName, 'Agent Verification');
    expect(PaymentStream.localPromotion.displayName, 'Local Promotion / Ads');
  });

  test('PaymentStatus enum displays accurately', () {
    expect(PaymentStatus.collected.displayName, 'Collected');
    expect(PaymentStatus.outstanding.displayName, 'Outstanding (Owed)');
    expect(PaymentStatus.refunded.displayName, 'Refunded');
    expect(PaymentStatus.partiallyRefunded.displayName, 'Partially Refunded');
  });
}
