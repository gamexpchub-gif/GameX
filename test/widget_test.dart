import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamex_shop/core/storage.dart';
import 'package:gamex_shop/data/mock/mock_data.dart';
import 'package:gamex_shop/features/cart/providers/cart_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
  });

  tearDown(() => container.dispose());

  test('cart merges same product and computes totals', () {
    final phone = MockData.products.first;
    final cart = container.read(cartProvider.notifier);
    cart.add(phone);
    cart.add(phone, quantity: 2);

    expect(container.read(cartProvider), hasLength(1));
    expect(container.read(cartCountProvider), 3);
    expect(container.read(cartSubtotalProvider), phone.price * 3);
  });

  test('promo code applies discount and free delivery threshold', () {
    final cheap = MockData.products.firstWhere((p) => p.price < 5000);
    container.read(cartProvider.notifier).add(cheap);
    var summary = container.read(cartSummaryProvider);
    expect(summary.deliveryFee, CartSummary.standardDelivery);

    expect(container.read(promoProvider.notifier).apply('gamex10'), isTrue);
    summary = container.read(cartSummaryProvider);
    expect(summary.discount, (cheap.price * 0.10).roundToDouble());
    expect(container.read(promoProvider.notifier).apply('NOPE'), isFalse);
  });

  test('cart persists across containers', () async {
    container.read(cartProvider.notifier).add(MockData.products[1]);
    final prefs = await SharedPreferences.getInstance();
    final second = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    addTearDown(second.dispose);
    expect(second.read(cartProvider), hasLength(1));
  });
}
