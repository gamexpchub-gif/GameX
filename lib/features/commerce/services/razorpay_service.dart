import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../../../core/api.dart';
import '../../../data/models/order.dart';
import '../../auth/providers/auth_provider.dart';

/// Thrown when the buyer closes the payment screen or it fails.
class PaymentCancelled implements Exception {
  const PaymentCancelled(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Opens Razorpay Checkout for [amount] and verifies the payment on the
/// GAMEX server. Returns the Razorpay payment id.
class RazorpayService {
  RazorpayService(this._ref);
  final Ref _ref;

  Future<String> pay({
    required String keyId,
    required String orderId,
    required double amount,
    required PaymentMethod method,
    String description = 'GAMEX order',
  }) async {
    final api = _ref.read(apiProvider);
    final user = _ref.read(authProvider);
    final o = await api.post('/payments/razorpay/order', {
      'orderId': orderId,
      'amount': amount,
      'customerId': user?.id,
    }) as Map;
    if (o['demo'] == true) {
      throw const PaymentCancelled('Payments are in demo mode');
    }

    final rzp = Razorpay();
    final done = Completer<PaymentSuccessResponse>();
    rzp.on(Razorpay.EVENT_PAYMENT_SUCCESS, (PaymentSuccessResponse r) {
      if (!done.isCompleted) done.complete(r);
    });
    rzp.on(Razorpay.EVENT_PAYMENT_ERROR, (PaymentFailureResponse r) {
      if (!done.isCompleted) {
        done.completeError(
          PaymentCancelled(
            r.code == Razorpay.PAYMENT_CANCELLED
                ? 'Payment cancelled'
                : r.message ?? 'Payment failed',
          ),
        );
      }
    });
    rzp.on(Razorpay.EVENT_EXTERNAL_WALLET, (_) {});
    try {
      rzp.open({
        'key': o['keyId'] ?? keyId,
        'order_id': o['rzpOrderId'],
        'amount': o['amount'],
        'currency': 'INR',
        'name': 'GAMEX',
        'description': description,
        'prefill': {
          'contact': user?.phone ?? '',
          'email': user?.email ?? '',
          'name': user?.name ?? '',
        },
        'theme': {'color': '#3B5BFF'},
        // Open on the method the buyer picked.
        'config': {
          'display': {
            'preferences': {'show_default_blocks': true},
            'sequence': [
              switch (method) {
                PaymentMethod.bkash => 'block.upi',
                PaymentMethod.nagad => 'block.wallet',
                PaymentMethod.emi => 'block.emi',
                PaymentMethod.payLater => 'block.paylater',
                _ => 'block.card',
              },
            ],
            'blocks': {
              'block.upi': {
                'name': 'UPI',
                'instruments': [
                  {'method': 'upi'},
                ],
              },
              'block.wallet': {
                'name': 'Wallets',
                'instruments': [
                  {'method': 'wallet'},
                ],
              },
              'block.emi': {
                'name': 'EMI',
                'instruments': [
                  {'method': 'emi'},
                  {'method': 'cardless_emi'},
                ],
              },
              'block.paylater': {
                'name': 'Pay Later',
                'instruments': [
                  {'method': 'paylater'},
                ],
              },
              'block.card': {
                'name': 'Cards',
                'instruments': [
                  {'method': 'card'},
                ],
              },
            },
          },
        },
      });
      final r = await done.future;
      await api.post('/payments/razorpay/verify', {
        'rzpOrderId': r.orderId,
        'paymentId': r.paymentId,
        'signature': r.signature,
      });
      return r.paymentId!;
    } finally {
      rzp.clear();
    }
  }
}

final razorpayServiceProvider = Provider<RazorpayService>(RazorpayService.new);
