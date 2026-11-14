import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gamex_merchant/core/api.dart';
import 'package:gamex_merchant/core/format.dart';
import 'package:gamex_merchant/core/storage.dart';
import 'package:gamex_merchant/data/models.dart';
import 'package:gamex_merchant/data/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

SellerOrder _order(OrderStage stage, DateTime placed, List<OrderEvent> ev) =>
    SellerOrder(
      id: 'O${placed.millisecondsSinceEpoch}',
      listingId: 'L',
      item: 'Phone',
      variant: '',
      photo: '',
      price: 50000,
      buyer: 'B',
      phone: '',
      address: '',
      city: '',
      pincode: '',
      payment: 'UPI',
      stage: stage,
      placedAt: placed,
      events: ev,
    );

String _imei(String body) {
  var sum = 0;
  for (var i = 0; i < 14; i++) {
    var n = int.parse(body[13 - i]);
    if (i.isEven) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
  }
  return '$body${(10 - sum % 10) % 10}';
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

  test('earnings: settled after 7 days, cleared by payout', () {
    final now = DateTime(2026, 11, 14);
    final old = now.subtract(const Duration(days: 12));
    final recent = now.subtract(const Duration(days: 2));
    final orders = [
      _order(OrderStage.delivered, old, [
        OrderEvent('Delivered', old.add(const Duration(days: 2))),
      ]),
      _order(OrderStage.delivered, recent, [OrderEvent('Delivered', recent)]),
      _order(OrderStage.newOrder, now, [OrderEvent('Placed', now)]),
    ];
    final e = computeEarnings(orders, const [], now);
    expect(e.available, closeTo(Fees.payout(50000), 0.01));
    expect(e.pending, closeTo(Fees.payout(50000) * 2, 0.01));
    final after = computeEarnings(orders, [
      Payout(id: 'P', amount: 1, orders: 1, at: now, utr: 'U'),
    ], now);
    expect(after.available, 0);
  });

  test('server JSON parses into seller data', () {
    final d = SellerData.fromJson({
      'listings': [
        {
          'id': 'GXL1',
          'brand': 'Apple',
          'model': 'iPhone 15',
          'ram': '6GB',
          'storage': '128GB',
          'color': 'Blue',
          'grade': 'likeNew',
          'battery': 91,
          'imei': '490154203237518',
          'price': 54999,
          'mrp': 69900,
          'stock': 2,
          'warranty': 6,
          'photos': ['/img/deal_iphone_blue.png'],
          'status': 'active',
          'createdAt': '2026-11-01T10:00:00.000Z',
          'featured': true,
          'certificate': 'GXC-1',
          'qc': {'by': 'Priya'},
        },
      ],
      'notifications': [
        {
          'id': 'N1',
          'title': 'Hi',
          'body': '',
          'kind': 'promo',
          'at': '2026-11-01T10:00:00.000Z',
          'read': false,
        },
      ],
      'insights': {
        'demand': [
          {'name': 'Apple iPhone 15', 'orders': 5},
        ],
        'pricing': [],
      },
    });
    expect(d.listings.single.certificate, 'GXC-1');
    expect(d.listings.single.grade, Grade.likeNew);
    expect(d.notices.single.isAnnouncement, isTrue);
    expect(d.insights.demand.single.orders, 5);
  });

  // End-to-end against a running server: GAMEX_API=http://127.0.0.1:8080
  final url = Platform.environment['GAMEX_API'];
  test('live server: login, sync, QC submit, accept order', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
    );
    await c.read(apiProvider).setBaseUrl(url!);
    final seller = await c.read(authApiProvider).login('9876543210');
    expect(seller!.storeName, 'Mobile Point Andheri');
    await c.read(sellerProvider.notifier).set(seller);
    c.read(syncProvider);
    await c.read(syncProvider.notifier).refresh();
    final data = c.read(syncProvider);
    expect(data.error, isNull);
    expect(data.listings, isNotEmpty);

    final l = data.listings.first.copyWith(
      id: newListingId(),
      imei: _imei(
        '35${DateTime.now().microsecondsSinceEpoch}'.substring(0, 14),
      ),
    );
    final saved = await c
        .read(syncProvider.notifier)
        .saveListing(l, submit: true);
    expect(saved.status, ListingStatus.inReview);

    final o = data.orders.firstWhere((o) => o.stage == OrderStage.newOrder);
    await c.read(syncProvider.notifier).accept(o.id);
    await c.read(syncProvider.notifier).refresh();
    expect(c.read(orderByIdProvider(o.id))!.stage, OrderStage.accepted);
    c.dispose();
  }, skip: url == null ? 'set GAMEX_API to run' : false);
}
