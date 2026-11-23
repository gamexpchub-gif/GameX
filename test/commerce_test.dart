import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamex_shop/core/storage.dart';
import 'package:gamex_shop/data/mock/mock_data.dart';
import 'package:gamex_shop/data/models/order.dart';
import 'package:gamex_shop/features/cart/providers/cart_provider.dart';
import 'package:gamex_shop/features/commerce/data/accessories.dart';
import 'package:gamex_shop/features/commerce/data/commerce_api.dart';
import 'package:gamex_shop/features/commerce/data/emi.dart';
import 'package:gamex_shop/features/commerce/data/protection.dart';
import 'package:gamex_shop/features/commerce/data/tradein.dart';
import 'package:gamex_shop/features/commerce/providers/checkout_extras.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('EMI', () {
    test('standard EMI matches the reducing-balance formula', () {
      expect(emiAmount(100000, 0.15, 12), closeTo(9025.83, 0.01));
      expect(emiAmount(12000, 0, 12), 1000);
    });

    test('no-cost EMI rules', () {
      final hdfc = kEmiBanks.first;
      expect(isNoCost(hdfc, 6, 49999), isTrue);
      expect(isNoCost(hdfc, 12, 49999), isFalse);
      expect(isNoCost(hdfc, 9, 35000), isTrue); // HDFC: 9 months above ₹30K
      expect(isNoCost(hdfc, 9, 25000), isFalse);
      expect(isNoCost(hdfc, 3, 8000), isFalse); // below ₹10K
      final p = emiPlan(hdfc, 6, 60000);
      expect(p.monthly, 10000);
      expect(p.interest, 0);
      expect(p.noCostDiscount, greaterThan(0));
      expect(bestNoCost(40000), 9);
    });

    test('pay later limits and schedule', () {
      final pay3 = kPayLater.firstWhere((p) => p.id == 'pl3');
      expect(pay3.allows(40000), isTrue);
      expect(pay3.allows(40001), isFalse);
      final s = pay3.schedule(30000, DateTime(2026, 1, 1));
      expect(s.length, 3);
      expect(s.map((e) => e.$2).reduce((a, b) => a + b), 30000);
    });
  });

  test('protection plan prices end in 99 and respect min / max', () {
    final screen = protectionById('screen')!;
    expect(screen.priceFor(10000), 699);
    expect(screen.priceFor(49999), 2299);
    expect(screen.priceFor(500000), 4999);
    expect(canProtect(kAccessoryCategory), isFalse);
  });

  group('trade-in', () {
    test('local quote matches the server quote', () {
      // Same input as the server test: 17,950.
      final q = localQuote(
        const TradeInDevice(
          brand: 'Apple',
          model: 'iPhone 13',
          storage: '256GB',
          answers: {'screen': 'Minor scratches'},
          faults: {'Camera'},
          extras: {'Original box'},
        ),
        newPhonePrice: 49999,
      )!;
      expect(q.$1, 17950);
      expect(q.$2.last.label, 'GAMEX exchange bonus');
    });

    test(
      'dead phones are worth parts only, never more than 90% of the new phone',
      () {
        final dead = localQuote(
          const TradeInDevice(
            brand: 'Apple',
            model: 'iPhone 16 Pro',
            answers: {'power': 'Does not turn on / dead'},
          ),
        )!;
        expect(dead.$1, lessThan(62000 * 0.2));
        final capped = localQuote(
          const TradeInDevice(brand: 'Apple', model: 'iPhone 16 Pro'),
          newPhonePrice: 40000,
        )!;
        expect(capped.$1, 36000);
        expect(
          localQuote(const TradeInDevice(brand: 'Apple', model: 'iPhone 3G')),
          isNull,
        );
      },
    );
  });

  test('accessories fit the phone brand', () {
    final iphone = MockData.products.firstWhere((p) => p.brand == 'Apple');
    final galaxy = MockData.products.firstWhere((p) => p.brand == 'Samsung');
    final a = accessoriesFor(iphone).map((p) => p.name).toList();
    final g = accessoriesFor(galaxy).map((p) => p.name).toList();
    expect(
      a.any((n) => n.startsWith('Clear MagSafe Case for ${iphone.name}')),
      isTrue,
    );
    expect(a.any((n) => n.contains('20W')), isTrue);
    expect(a.any((n) => n.contains('65W')), isFalse);
    expect(g.any((n) => n.contains('45W')), isTrue);
    expect(g.any((n) => n.contains('Lightning')), isFalse);
    // Two phones in the cart: shared accessories are listed once.
    final both = crossSellFor([iphone, galaxy], {});
    expect(both.map((p) => p.id).toSet().length, both.length);
  });

  test(
    'checkout totals: protection, festival, bank offer, trade-in, wallet',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [
          sharedPrefsProvider.overrideWithValue(prefs),
          promotionsProvider.overrideWith((ref) async => Promo.fallback()),
          walletProvider.overrideWith(
            (ref) async => const Wallet({'balance': 5000, 'pending': 0}),
          ),
        ],
      );
      addTearDown(c.dispose);
      await c.read(promotionsProvider.future);
      await c.read(walletProvider.future);

      final phone = MockData.products.firstWhere(
        (p) => p.price >= 40000 && !p.isFlashSale,
      );
      c.read(cartProvider.notifier).add(phone);
      final key = c.read(cartProvider).first.key;
      c.read(cartProvider.notifier).setProtection(key, 'screen');
      c
          .read(paymentChoiceProvider.notifier)
          .update(
            (p) => p.copyWith(method: PaymentMethod.card, bankId: () => 'hdfc'),
          );
      c
          .read(tradeInProvider.notifier)
          .set(
            TradeInQuote(
              device: const TradeInDevice(brand: 'Apple', model: 'iPhone 11'),
              amount: 9000,
              lines: const [],
              expiresAt: DateTime.now().add(const Duration(days: 7)),
            ),
          );
      c.read(useWalletProvider.notifier).set(true);

      final t = c.read(checkoutTotalsProvider(0));
      final plan = protectionById('screen')!.priceFor(phone.price);
      expect(t.protection, plan);
      expect(t.festival, 0); // not a flash-sale phone
      final base = phone.price + plan;
      expect(t.bank, (base * 0.1).clamp(0, 3000).roundToDouble());
      expect(t.tradeIn, 9000);
      final afterTrade = base - t.bank - 9000;
      expect(t.wallet, (afterTrade * 0.2).floorToDouble().clamp(0, 5000));
      expect(t.total, closeTo(afterTrade - t.wallet, 0.001));
      expect(
        t.orderLines.fold(0.0, (s, l) => s + l.$2),
        closeTo(t.total - phone.price, 0.001),
      );
    },
  );
}
