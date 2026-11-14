import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/storage.dart';
import '../../../data/mock/mock_data.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/order.dart';

class OrdersNotifier extends Notifier<List<Order>> {
  static const _seededKey = 'demo_orders_seeded_v1';

  @override
  List<Order> build() {
    final store = ref.read(localStoreProvider);
    final saved = store.readJson(
      LocalStore.orders,
      (json) => (json as List)
          .map((e) => Order.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
    if (saved != null) return saved;
    // First launch: show a few sample orders so the Orders and Account
    // pages demonstrate every status. Remove once the backend is live.
    if (store.readString(_seededKey) == null) {
      final demo = _demoOrders();
      store.writeString(_seededKey, '1');
      store.writeJson(LocalStore.orders, demo.map((o) => o.toJson()).toList());
      return demo;
    }
    return const [];
  }

  static String newOrderId(DateTime t) =>
      'GMX${DateFormat('yyyyMMdd').format(t)}${Random().nextInt(900) + 100}';

  List<Order> _demoOrders() {
    final now = DateTime.now();
    const address = Address(
      fullName: 'GAMEX Customer',
      phone: '9876543210',
      city: 'Mumbai',
      area: 'Andheri West',
      details: 'Flat 12, Sea View Towers',
    );
    Order make(
      String pid,
      int daysAgo,
      OrderStatus status,
      PaymentMethod pay,
      int seq,
    ) {
      final p = MockData.byId(pid)!;
      final at = now.subtract(Duration(days: daysAgo, hours: 3));
      return Order(
        id: 'GMX${DateFormat('yyyyMMdd').format(at)}${seq.toString().padLeft(3, '0')}',
        items: [CartItem(product: p, quantity: 1)],
        address: address,
        paymentMethod: pay,
        subtotal: p.price,
        deliveryFee: 0,
        discount: 0,
        createdAt: at,
        status: status,
      );
    }

    return [
      make('p1', 2, OrderStatus.delivered, PaymentMethod.bkash, 1),
      make('p5', 1, OrderStatus.shipped, PaymentMethod.card, 2),
      make('p11', 0, OrderStatus.confirmed, PaymentMethod.cashOnDelivery, 3),
      make('p8', 9, OrderStatus.delivered, PaymentMethod.bkash, 4),
      make('p2', 3, OrderStatus.shipped, PaymentMethod.nagad, 5),
      make('p13', 15, OrderStatus.cancelled, PaymentMethod.card, 6),
    ];
  }

  Future<Order> placeOrder({
    required List<CartItem> items,
    required Address address,
    required PaymentMethod payment,
    required double subtotal,
    required double deliveryFee,
    required double discount,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final order = Order(
      id: newOrderId(DateTime.now()),
      items: items,
      address: address,
      paymentMethod: payment,
      subtotal: subtotal,
      deliveryFee: deliveryFee,
      discount: discount,
      createdAt: DateTime.now(),
      status: payment == PaymentMethod.cashOnDelivery
          ? OrderStatus.pending
          : OrderStatus.confirmed,
    );
    state = [order, ...state];
    await ref
        .read(localStoreProvider)
        .writeJson(LocalStore.orders, state.map((o) => o.toJson()).toList());
    return order;
  }

  Order? byId(String id) {
    for (final o in state) {
      if (o.id == id) return o;
    }
    return null;
  }
}

final ordersProvider = NotifierProvider<OrdersNotifier, List<Order>>(
  OrdersNotifier.new,
);

/// Last used delivery address, pre-filled at checkout.
final savedAddressProvider = Provider<Address?>((ref) {
  final orders = ref.watch(ordersProvider);
  return orders.isEmpty ? null : orders.first.address;
});
