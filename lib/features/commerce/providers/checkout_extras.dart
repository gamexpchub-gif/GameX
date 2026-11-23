import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage.dart';
import '../../../data/models/cart_item.dart';
import '../../../data/models/order.dart';
import '../../cart/providers/cart_provider.dart';
import '../data/commerce_api.dart';
import '../data/emi.dart';
import '../data/protection.dart';
import '../data/tradein.dart';

// ───────────────────────────── Trade-in ─────────────────────────────

/// The trade-in quote the buyer chose to use on their next order.
class TradeInNotifier extends Notifier<TradeInQuote?> {
  static const _key = 'trade_in_quote_v1';

  @override
  TradeInQuote? build() {
    final q = ref
        .read(localStoreProvider)
        .readJson(
          _key,
          (j) => TradeInQuote.fromJson(j as Map<String, dynamic>),
        );
    return q == null || q.expired ? null : q;
  }

  void set(TradeInQuote? q) {
    state = q;
    final store = ref.read(localStoreProvider);
    q == null ? store.remove(_key) : store.writeJson(_key, q.toJson());
  }
}

final tradeInProvider = NotifierProvider<TradeInNotifier, TradeInQuote?>(
  TradeInNotifier.new,
);

// ───────────────────────────── Payment choices ─────────────────────────

class PaymentChoice {
  const PaymentChoice({
    this.method = PaymentMethod.cashOnDelivery,
    this.bankId,
    this.months = 6,
    this.payLaterId = 'pl15',
  });
  final PaymentMethod method;

  /// Card / EMI bank (see [kEmiBanks]).
  final String? bankId;
  final int months;
  final String payLaterId;

  EmiBank? get bank => kEmiBanks.where((b) => b.id == bankId).firstOrNull;
  PayLaterOption get payLater => kPayLater.firstWhere(
    (p) => p.id == payLaterId,
    orElse: () => kPayLater.first,
  );

  PaymentChoice copyWith({
    PaymentMethod? method,
    String? Function()? bankId,
    int? months,
    String? payLaterId,
  }) => PaymentChoice(
    method: method ?? this.method,
    bankId: bankId == null ? this.bankId : bankId(),
    months: months ?? this.months,
    payLaterId: payLaterId ?? this.payLaterId,
  );
}

class PaymentChoiceNotifier extends Notifier<PaymentChoice> {
  @override
  PaymentChoice build() => const PaymentChoice();
  void update(PaymentChoice Function(PaymentChoice) f) => state = f(state);
}

final paymentChoiceProvider =
    NotifierProvider<PaymentChoiceNotifier, PaymentChoice>(
      PaymentChoiceNotifier.new,
    );

class _Flag extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool v) => state = v;
}

/// "Use wallet balance" toggle at checkout.
final useWalletProvider = NotifierProvider<_Flag, bool>(_Flag.new);

// ───────────────────────────── Totals ─────────────────────────────

class CheckoutTotals {
  const CheckoutTotals({
    required this.summary,
    required this.delivery,
    required this.protection,
    required this.festival,
    required this.bank,
    required this.bankOffer,
    required this.tradeIn,
    required this.wallet,
    required this.walletAvailable,
    required this.walletCap,
  });

  final CartSummary summary;

  /// Delivery fee including express.
  final double delivery;
  final double protection;
  final double festival;
  final double bank;
  final BankOffer? bankOffer;
  final double tradeIn;
  final double wallet;
  final double walletAvailable;

  /// Most the wallet may pay on this order.
  final double walletCap;

  double get beforeCredits =>
      summary.subtotal + delivery + protection - summary.discount - festival;

  double get total =>
      (beforeCredits - bank - tradeIn - wallet).clamp(0, double.infinity);

  double get savings => summary.totalSavings + festival + bank + wallet;

  /// Extra order lines saved on the [Order] (negative = discount).
  List<(String, double)> get orderLines => [
    if (protection > 0) ('Protection plans', protection),
    if (festival > 0) ('Festival sale discount', -festival),
    if (bank > 0) ('${bankOffer?.bank ?? 'Bank'} offer', -bank),
    if (tradeIn > 0) ('Trade-in credit', -tradeIn),
    if (wallet > 0) ('GAMEX wallet', -wallet),
  ];
}

double protectionTotal(Iterable<CartItem> items) => items.fold(
  0.0,
  (s, i) =>
      s +
      (protectionById(i.protection)?.priceFor(i.product.price) ?? 0) *
          i.quantity,
);

/// Everything the buyer pays at checkout. [delivery] is the fee for the
/// chosen delivery speed.
final checkoutTotalsProvider = Provider.family<CheckoutTotals, double>((
  ref,
  delivery,
) {
  final items = ref.watch(selectedCartProvider);
  final summary = ref.watch(cartSummaryProvider);
  final promo = ref.watch(promotionsProvider).asData?.value ?? Promo.fallback();
  final pay = ref.watch(paymentChoiceProvider);
  final trade = ref.watch(tradeInProvider);
  final useWallet = ref.watch(useWalletProvider);
  final walletBal = ref.watch(walletProvider).asData?.value?.balance ?? 0;

  final protection = protectionTotal(items);
  final flashValue = items
      .where((i) => i.product.isFlashSale && i.offerId == null)
      .fold(0.0, (s, i) => s + i.total);
  final festival = promo.sale.discountOn(flashValue);
  final base =
      summary.subtotal + delivery + protection - summary.discount - festival;

  // Bank offer: card or EMI paid with a bank that has an offer.
  BankOffer? offer;
  var bank = 0.0;
  final emi = pay.method == PaymentMethod.emi;
  if ((pay.method == PaymentMethod.card || emi) && pay.bank != null) {
    for (final o in promo.bankOffers) {
      if (o.bank.split(' ').first != pay.bank!.name.split(' ').first) continue;
      if (!o.appliesTo(emi: emi)) continue;
      final d = o.discountOn(base);
      if (d > bank) {
        bank = d;
        offer = o;
      }
    }
  }
  final tradeIn = trade == null || summary.itemCount == 0
      ? 0.0
      : trade.amount.clamp(0, (base - bank) * 0.9).toDouble();
  final afterTrade = base - bank - tradeIn;
  final cap = (afterTrade * promo.walletMaxPercent / 100).floorToDouble();
  final wallet = useWallet ? walletBal.clamp(0, cap).toDouble() : 0.0;
  return CheckoutTotals(
    summary: summary,
    delivery: delivery,
    protection: protection,
    festival: festival,
    bank: bank,
    bankOffer: offer,
    tradeIn: tradeIn,
    wallet: wallet,
    walletAvailable: walletBal,
    walletCap: cap,
  );
});
