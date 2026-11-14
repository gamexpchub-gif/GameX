import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamex_shop/core/api.dart';
import 'package:gamex_shop/core/storage.dart';
import 'package:gamex_shop/data/models/cart_item.dart';
import 'package:gamex_shop/data/models/order.dart';
import 'package:gamex_shop/features/catalog/providers/catalog_providers.dart';
import 'package:gamex_shop/features/orders/providers/orders_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Runs against a live server: GAMEX_API=http://127.0.0.1:8080 flutter test
void main() {
  final url = Platform.environment['GAMEX_API'];
  test(
    'seller listings appear in the shop and orders reach the seller',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      );
      await c.read(apiProvider).setBaseUrl(url!);

      final repo = c.read(productRepositoryProvider);
      final all = await repo.products();
      final seller = all.where((p) => p.id.startsWith('GXL')).toList();
      expect(seller, isNotEmpty);
      expect(seller.first.verified, isTrue);
      final feed = await repo.newListings(page: 0);
      expect(feed.first.id, startsWith('GXL'));
      final p = (await repo.byId(seller.first.id))!;
      expect(p.specs['Sold by'], isNotNull);

      final order = await c
          .read(ordersProvider.notifier)
          .placeOrder(
            items: [CartItem(product: p, quantity: 1)],
            address: const Address(
              fullName: 'Test Buyer',
              phone: '9876500000',
              city: 'Pune',
              area: 'Baner',
              details: 'Flat 1',
            ),
            payment: PaymentMethod.bkash,
            subtotal: p.price,
            deliveryFee: 0,
            discount: 0,
          );

      final res = await HttpClient()
          .getUrl(Uri.parse('$url/api/orders/status?ids=${order.id}'))
          .then((r) => r.close());
      final body = jsonDecode(await res.transform(utf8.decoder).join()) as List;
      expect(body.single['stage'], 'newOrder');
      c.dispose();
    },
    skip: url == null ? 'set GAMEX_API to run' : false,
  );
}
