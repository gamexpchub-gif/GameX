import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../data/models/product.dart';
import '../../../trust/presentation/widgets/trust_ui.dart';
import '../../data/pincode.dart';
import '../../providers/discover_providers.dart';

/// "Check delivery": PIN code → delivery date, COD, open-box & express.
class DeliveryCheckCard extends ConsumerStatefulWidget {
  const DeliveryCheckCard({super.key, required this.product, this.price});
  final Product product;
  final double? price;

  @override
  ConsumerState<DeliveryCheckCard> createState() => _DeliveryCheckCardState();
}

class _DeliveryCheckCardState extends ConsumerState<DeliveryCheckCard> {
  final _ctrl = TextEditingController();
  bool _editing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(deliveryPinProvider);
    _ctrl.text = saved ?? '';
    _editing = saved == null;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _check() {
    final pin = _ctrl.text.trim();
    final place = lookupPin(pin);
    if (place == null) {
      setState(
        () => _error = pin.length != 6
            ? 'Enter a 6-digit PIN code'
            : 'We could not find this PIN code',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    HapticFeedback.selectionClick();
    ref.read(deliveryPinProvider.notifier).set(place.pin);
    setState(() {
      _error = null;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pin = ref.watch(deliveryPinProvider);
    final place = pin == null || _editing ? null : lookupPin(pin);
    return TCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const TIcon(Icons.local_shipping_rounded, size: 36),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Delivery & COD',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: TX.ink,
                  ),
                ),
              ),
              if (place != null)
                GestureDetector(
                  onTap: () => setState(() => _editing = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: TX.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_location_alt_rounded,
                          size: 14,
                          color: TX.blue,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          place.pin,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: TX.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (place == null)
            _input()
          else
            _result(quoteFor(widget.product, place, price: widget.price)),
        ],
      ),
    );
  }

  Widget _input() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onSubmitted: (_) => _check(),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                letterSpacing: 2,
                color: TX.ink,
              ),
              decoration: tInput(
                'Enter PIN code',
                prefix: const Icon(Icons.pin_drop_outlined, color: TX.muted),
              ).copyWith(counterText: '', errorText: _error),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 96,
            child: TButton(label: 'Check', height: 50, onTap: _check),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Text(
        'See the delivery date, Cash on Delivery and open-box delivery for your area.',
        style: TextStyle(fontSize: 12, color: TX.muted, height: 1.3),
      ),
    ],
  );

  Widget _result(DeliveryQuote q) {
    final f = DateFormat('EEE, d MMM');
    final when = q.minDays == 1 && q.maxDays == 1
        ? 'Tomorrow, ${DateFormat('d MMM').format(q.earliest)}'
        : q.minDays == q.maxDays
        ? f.format(q.earliest)
        : '${f.format(q.earliest)} – ${f.format(q.latest)}';
    Widget row(IconData icon, Color c, String title, String sub) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: c),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: TX.ink,
                    fontSize: 13.5,
                  ),
                ),
                Text(
                  sub,
                  style: const TextStyle(fontSize: 12, color: TX.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                TX.green.withValues(alpha: 0.12),
                TX.blue.withValues(alpha: 0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delivery to ${q.place.label}',
                style: const TextStyle(fontSize: 12, color: TX.muted),
              ),
              const SizedBox(height: 2),
              Text(
                'Get it by $when',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: TX.green,
                ),
              ),
              Text(
                'Ships from ${q.from}',
                style: const TextStyle(fontSize: 12, color: TX.muted),
              ),
            ],
          ),
        ),
        row(
          q.cod ? Icons.payments_rounded : Icons.money_off_rounded,
          q.cod ? TX.green : TX.amber,
          q.cod
              ? 'Cash on Delivery available'
              : 'Cash on Delivery not available',
          q.codNote,
        ),
        row(
          Icons.inventory_2_rounded,
          q.openBox ? TX.green : TX.faint,
          q.openBox ? 'Open-box delivery' : 'Standard delivery',
          q.openBox
              ? 'Check the phone before you share the OTP'
              : 'Open-box check is not available in this area yet',
        ),
        if (q.express)
          row(
            Icons.bolt_rounded,
            TX.violet,
            'Same-day express available',
            'Order before 2 PM at checkout',
          ),
      ],
    );
  }
}
