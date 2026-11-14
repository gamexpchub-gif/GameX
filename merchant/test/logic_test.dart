import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamex_merchant/core/format.dart';
import 'package:gamex_merchant/core/storage.dart';
import 'package:gamex_merchant/data/models.dart';
import 'package:gamex_merchant/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
  );
}

void main() {
  test('IMEI Luhn validation', () {
    expect(validImei('490154203237518'), isTrue);
    expect(validImei('490154203237519'), isFalse);
    expect(validImei('12345'), isFalse);
  });

  test('fees and payout', () {
    // 8% of 50,000 = 4,000; + 49 = 4,049; + 18% GST = 4,777.82
    expect(Fees.totalFees(50000), closeTo(4777.82, 0.01));
    expect(Fees.payout(50000), closeTo(45222.18, 0.01));
  });

  test('order flow: accept → pack → ship → deliver', () async {
    final c = await _container();
    final n = c.read(ordersProvider.notifier);
    final o = c.read(ordersProvider).firstWhere((e) => e.stage == OrderStage.newOrder);
    n.accept(o.id);
    expect(c.read(orderByIdProvider(o.id))!.stage, OrderStage.accepted);
    n.pack(o.id);
    expect(c.read(orderByIdProvider(o.id))!.imeiVerified, isTrue);
    n.ship(o.id, 'Delhivery', DateTime.now());
    final shipped = c.read(orderByIdProvider(o.id))!;
    expect(shipped.stage, OrderStage.shipped);
    expect(shipped.awb, startsWith('DE'));
    n.deliver(o.id);
    expect(c.read(orderByIdProvider(o.id))!.stage, OrderStage.delivered);
  });

  test('stock 0 marks listing sold out and restock reactivates', () async {
    final c = await _container();
    final n = c.read(listingsProvider.notifier);
    final l = c.read(listingsProvider).firstWhere((e) => e.status == ListingStatus.active);
    n.setStock(l.id, 0);
    expect(c.read(listingByIdProvider(l.id))!.status, ListingStatus.soldOut);
    n.setStock(l.id, 2);
    expect(c.read(listingByIdProvider(l.id))!.status, ListingStatus.active);
  });

  test('withdraw empties the available balance', () async {
    final c = await _container();
    final before = c.read(earningsProvider).available;
    expect(before, greaterThan(0));
    c.read(payoutsProvider.notifier).add(
      Payout(id: 'X', amount: before, orders: 1, at: DateTime.now(), utr: 'U'),
    );
    expect(c.read(earningsProvider).available, 0);
  });
}
