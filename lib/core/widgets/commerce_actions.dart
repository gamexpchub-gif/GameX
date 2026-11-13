import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../data/models/product.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/cart/providers/cart_provider.dart';
import 'common.dart';

/// Adds [product] to the cart and shows a confirmation with a VIEW action.
void addToCart(
  BuildContext context,
  WidgetRef ref,
  Product product, {
  int quantity = 1,
}) {
  HapticFeedback.mediumImpact();
  ref.read(cartProvider.notifier).add(product, quantity: quantity);
  showAppSnack(
    context,
    '${product.name} added to cart',
    action: 'VIEW',
    onAction: () => context.push('/cart'),
  );
}

/// Adds [product] and goes straight to checkout (sign-in first if needed).
void buyNow(
  BuildContext context,
  WidgetRef ref,
  Product product, {
  int quantity = 1,
}) {
  HapticFeedback.mediumImpact();
  ref.read(cartProvider.notifier).add(product, quantity: quantity);
  if (ref.read(authProvider) == null) {
    context.push('/login?from=${Uri.encodeComponent('/checkout')}');
  } else {
    context.push('/checkout');
  }
}
