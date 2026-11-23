import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/widgets/brand_marks.dart';
import '../../cart/providers/cart_provider.dart';
import '../../discover/presentation/filter_sheet.dart' show FChip;
import '../../service/presentation/repair_screen.dart' show showSellPickupSheet;
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/commerce_api.dart';
import '../data/tradein.dart';
import '../providers/checkout_extras.dart';

/// Exchange / trade-in: model + condition → instant quote → used as credit
/// at checkout. The old phone is collected when the new one is delivered.
class TradeInScreen extends ConsumerStatefulWidget {
  const TradeInScreen({super.key, this.newPhonePrice = 0, this.sell = false});

  /// "Sell to GAMEX": no new phone, pickup + payout instead of a credit.
  final bool sell;

  /// Price of the phone being bought (unlocks the exchange bonus).
  final double newPhonePrice;

  @override
  ConsumerState<TradeInScreen> createState() => _TradeInScreenState();
}

class _TradeInScreenState extends ConsumerState<TradeInScreen> {
  int _step = 0;
  String? _brand;
  String? _model;
  String _storage = '128GB';
  final _answers = <String, String>{};
  final _faults = <String>{};
  final _extras = <String>{};
  String _q = '';
  TradeInQuote? _quote;
  bool _busy = false;
  String? _error;

  static const _steps = 4;

  double get _price {
    if (widget.sell) return 0;
    if (widget.newPhonePrice > 0) return widget.newPhonePrice;
    return ref.read(selectedCartProvider).fold(0.0, (s, i) => s + i.total);
  }

  TradeInDevice get _device => TradeInDevice(
    brand: _brand ?? '',
    model: _model ?? '',
    storage: _storage,
    answers: Map.of(_answers),
    faults: Set.of(_faults),
    extras: Set.of(_extras),
  );

  /// Live estimate while answering (local rules).
  double? get _estimate =>
      _model == null ? null : localQuote(_device, newPhonePrice: _price)?.$1;

  void _go(int s) {
    HapticFeedback.selectionClick();
    setState(() => _step = s);
  }

  void _back() {
    if (_step == 0 || _quote != null && _step == _steps) {
      if (_quote != null && _step == _steps) {
        setState(() {
          _quote = null;
          _step = 3;
        });
        return;
      }
      context.canPop() ? context.pop() : context.go('/home');
    } else {
      setState(() => _step--);
    }
  }

  Future<void> _getQuote() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final q = await ref
          .read(commerceApiProvider)
          .quote(_device, newPhonePrice: _price);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _quote = q;
        _step = _steps;
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      0 => 'Which brand?',
      1 => 'Which ${_brand ?? ''} model?',
      2 => 'Condition of your $_model',
      3 => 'Anything not working?',
      _ => 'Your instant quote',
    };
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (did, _) {
        if (!did) _back();
      },
      child: TrustScaffold(
        title: widget.sell ? 'Sell your phone' : 'Exchange your phone',
        subtitle: _step < _steps
            ? 'Step ${_step + 1} of $_steps'
            : 'Valid for 7 days',
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        bottom: _bottom(),
        children: [
          if (_step < _steps) ...[
            _progress(),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: TX.ink,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 14),
          ],
          ...switch (_step) {
            0 => _brands(),
            1 => _models(),
            2 => _condition(),
            3 => _faultsStep(),
            _ => _result(),
          },
        ],
      ),
    );
  }

  Widget _progress() => Row(
    children: [
      for (var i = 0; i < _steps; i++)
        Expanded(
          child: Container(
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              gradient: i <= _step ? TX.cta : null,
              color: i <= _step ? null : TX.line,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ),
    ],
  );

  Widget? _bottom() {
    final est = _estimate;
    if (_step == 2 || _step == 3) {
      final ready =
          _step == 3 || kTradeQuestions.every((q) => _answers[q.id] != null);
      return Row(
        children: [
          if (est != null)
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Estimated value',
                    style: TextStyle(fontSize: 12, color: TX.muted),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: est),
                    duration: const Duration(milliseconds: 350),
                    builder: (_, v, _) => Text(
                      formatPrice(v),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: TX.green,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: 180,
            child: TButton(
              label: _step == 2 ? 'Next' : 'Get final quote',
              icon: _step == 2
                  ? Icons.arrow_forward_rounded
                  : Icons.bolt_rounded,
              busy: _busy,
              onTap: !ready
                  ? null
                  : _step == 2
                  ? () => _go(3)
                  : _getQuote,
            ),
          ),
        ],
      );
    }
    if (_step == _steps && _quote != null && widget.sell) {
      return TButton(
        label: 'Sell for ${formatPrice(_quote!.amount)} • schedule pickup',
        icon: Icons.local_shipping_rounded,
        gradient: TX.success,
        onTap: () => showSellPickupSheet(context, _quote!),
      );
    }
    if (_step == _steps && _quote != null) {
      final cart = ref.watch(cartCountProvider);
      return TButton(
        label: cart > 0
            ? 'Use ${formatPrice(_quote!.amount)} at checkout'
            : 'Save quote for my order',
        icon: Icons.check_circle_rounded,
        onTap: () {
          ref.read(tradeInProvider.notifier).set(_quote);
          HapticFeedback.heavyImpact();
          tSnack(
            context,
            'Trade-in added. ${formatPrice(_quote!.amount)} will be taken off your order.',
          );
          if (cart > 0) {
            context.pushReplacement('/checkout');
          } else {
            context.canPop() ? context.pop() : context.go('/home');
          }
        },
      );
    }
    return null;
  }

  List<Widget> _brands() => [
    _Promise(sell: widget.sell),
    const SizedBox(height: 16),
    GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.15,
      children: [
        for (final b in kTradeInModels.keys)
          TCard(
            padding: const EdgeInsets.all(8),
            onTap: () {
              setState(() {
                _brand = b;
                _model = null;
                _q = '';
              });
              _go(1);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 34,
                  child: Center(child: BrandMark(b.toLowerCase(), size: 26)),
                ),
                const SizedBox(height: 6),
                Text(
                  b,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TX.ink,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  ];

  List<Widget> _models() {
    final all = kTradeInModels[_brand] ?? const {};
    final list = all.entries
        .where((e) => e.key.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return [
      TextField(
        onChanged: (v) => setState(() => _q = v.trim()),
        decoration: tInput(
          'Search ${_brand ?? ''} models',
          prefix: const Icon(Icons.search_rounded),
        ),
      ),
      const SizedBox(height: 12),
      for (final e in list) ...[
        TCard(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          onTap: () {
            setState(() {
              _model = e.key;
              _answers.clear();
              _faults.clear();
              _extras.clear();
            });
            _go(2);
          },
          child: Row(
            children: [
              const TIcon(Icons.smartphone_rounded, size: 36),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  e.key,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TX.ink,
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'up to',
                    style: TextStyle(fontSize: 11, color: TX.muted),
                  ),
                  Text(
                    formatPrice(e.value * 1.22),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      color: TX.green,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.chevron_right_rounded, color: TX.faint),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 6),
      const Text(
        'Don\'t see your phone? We are adding more models every week.',
        style: TextStyle(fontSize: 12, color: TX.muted),
      ),
    ];
  }

  Widget _question(TradeQuestion q) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            q.title,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              color: TX.ink,
              fontSize: 15,
            ),
          ),
          Text(q.hint, style: const TextStyle(fontSize: 12, color: TX.muted)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (label, _) in q.options)
                FChip(label, _answers[q.id] == label, () {
                  HapticFeedback.selectionClick();
                  setState(() => _answers[q.id] = label);
                }),
            ],
          ),
        ],
      ),
    ),
  );

  List<Widget> _condition() {
    final dead = _device.dead;
    return [
      TCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Storage',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: TX.ink,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in kTradeInStorage.keys)
                  FChip(s, _storage == s, () => setState(() => _storage = s)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      for (final q in kTradeQuestions)
        if (!dead || q.id == 'power') _question(q),
    ];
  }

  List<Widget> _faultsStep() {
    if (_device.dead) {
      return [
        const TCard(
          child: Text(
            'Dead phones are bought for parts. Skip this step and get your quote.',
            style: TextStyle(color: TX.muted),
          ),
        ),
      ];
    }
    Widget pick(
      String label,
      bool on,
      VoidCallback onTap, {
      bool good = false,
    }) => GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: on
              ? (good ? TX.green : TX.red).withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: on ? (good ? TX.green : TX.red) : TX.line),
        ),
        child: Row(
          children: [
            Icon(
              on
                  ? (good ? Icons.check_circle_rounded : Icons.cancel_rounded)
                  : Icons.radio_button_unchecked_rounded,
              color: on ? (good ? TX.green : TX.red) : TX.faint,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: TX.ink,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return [
      const Text(
        'Tick anything that does NOT work. Leave empty if all is fine.',
        style: TextStyle(color: TX.muted),
      ),
      const SizedBox(height: 10),
      for (final f in kTradeFaults.keys)
        pick(f, _faults.contains(f), () {
          setState(
            () => _faults.contains(f) ? _faults.remove(f) : _faults.add(f),
          );
        }),
      const TTitle('You also have (adds value)'),
      for (final e in kTradeExtras.keys)
        pick(e, _extras.contains(e), () {
          setState(
            () => _extras.contains(e) ? _extras.remove(e) : _extras.add(e),
          );
        }, good: true),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(_error!, style: const TextStyle(color: TX.red)),
        ),
    ];
  }

  List<Widget> _result() {
    final q = _quote!;
    return [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: TX.success,
          borderRadius: BorderRadius.circular(28),
          boxShadow: TX.soft(0.25),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.verified_rounded, color: Colors.white),
                const SizedBox(width: 6),
                const Text(
                  'GAMEX GUARANTEED QUOTE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.3,
                  ),
                ),
                const Spacer(),
                if (q.serverId != null)
                  Text(
                    q.serverId!,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '${q.device.model} • ${q.device.storage}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              formatPrice(q.amount),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: -1,
              ),
            ),
            Text(
              widget.sell
                  ? 'Paid to your UPI / bank • valid till ${DateFormat('d MMM').format(q.expiresAt)}'
                  : 'Off your new phone • valid till ${DateFormat('d MMM').format(q.expiresAt)}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
      const TTitle('How we priced it'),
      TCard(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          children: [
            for (final (i, l) in q.lines.indexed)
              TRow(
                l.label,
                '${l.amount < 0
                    ? '−'
                    : i == 0
                    ? ''
                    : '+'}${formatPrice(l.amount.abs())}',
                valueColor: l.amount < 0
                    ? TX.red
                    : i == 0
                    ? TX.ink
                    : TX.green,
              ),
            TRow(
              'You get',
              formatPrice(q.amount),
              valueColor: TX.violet,
              last: true,
            ),
          ],
        ),
      ),
      const TTitle('What happens next'),
      TCard(
        child: Column(
          children: [
            if (widget.sell) ...const [
              _StepRow(
                Icons.event_available_rounded,
                'Pick a pickup time',
                'Free doorstep pickup at a time that suits you.',
              ),
              _StepRow(
                Icons.fact_check_rounded,
                '2-minute check at your door',
                'The agent confirms the condition and IMEI, then takes the phone.',
              ),
              _StepRow(
                Icons.payments_rounded,
                'Get paid',
                'Money in your UPI or bank account within 24 hours.',
              ),
            ] else ...const [
              _StepRow(
                Icons.shopping_bag_rounded,
                'Order your new phone',
                'The quote is taken off your bill at checkout.',
              ),
              _StepRow(
                Icons.local_shipping_rounded,
                'Swap at your door',
                'Our delivery partner hands over the new phone and collects the old one after a 2-minute check.',
              ),
            ],
            _StepRow(
              Icons.delete_sweep_rounded,
              'We wipe your data',
              'Certified data erasure. Remember to sign out of iCloud / Google first.',
              last: true,
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      const Text(
        'If the phone\'s condition at pickup differs from your answers, the value is re-quoted on the spot. You can cancel the exchange anytime before pickup.',
        style: TextStyle(fontSize: 11.5, color: TX.faint, height: 1.35),
      ),
    ];
  }
}

class _Promise extends StatelessWidget {
  const _Promise({this.sell = false});
  final bool sell;

  @override
  Widget build(BuildContext context) => THero(
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sell ? 'Sell to GAMEX in 60 seconds' : 'Old phone, new deal',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sell
                    ? 'Instant price • Free doorstep pickup • Paid to UPI or bank within 24 hours'
                    : 'Instant price • Off your bill • Pickup at delivery • +₹1,000 exchange bonus on phones above ₹30K',
                style: const TextStyle(
                  color: Color(0xFFC9D2FF),
                  fontSize: 12.5,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(
            Icons.currency_exchange_rounded,
            color: Color(0xFFFFC542),
            size: 34,
          ),
        ),
      ],
    ),
  );
}

class _StepRow extends StatelessWidget {
  const _StepRow(this.icon, this.title, this.text, {this.last = false});
  final IconData icon;
  final String title;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TIcon(icon, size: 34),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: TX.ink,
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: TX.muted,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
