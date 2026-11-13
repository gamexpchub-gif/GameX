import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/order.dart';

class OrdersNotifier extends Notifier<List<Order>> {
  @override
  List<Order> build() {
    return ref
            .read(localStoreProvider)
            .readJson(
              LocalStore.orders,
              (json) => (json as List)
                  .map((e) => Order.fromJson(e as Map<String, dynamic>))
                  .toList(),
            ) ??
        const [];
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
      id:
          'GX${DateTime.now().millisecondsSinceEpoch % 100000000}'
          '${Random().nextInt(90) + 10}',
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
