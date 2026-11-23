import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/utils/formatters.dart';
import '../../discover/presentation/filter_sheet.dart' show FChip;
import '../../trust/presentation/widgets/trust_ui.dart';
import '../data/emi.dart';

/// Bank chips + tenure table. Used by the EMI calculator and checkout.
class EmiPlanPicker extends StatelessWidget {
  const EmiPlanPicker({
    super.key,
    required this.price,
    required this.bankId,
    required this.months,
    required this.onChanged,
  });
  final double price;
  final String bankId;
  final int months;
  final void Function(String bankId, int months) onChanged;

  @override
  Widget build(BuildContext context) {
    final bank = kEmiBanks.firstWhere(
      (b) => b.id == bankId,
      orElse: () => kEmiBanks.first,
    );
    final plans = plansFor(bank, price);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final b in kEmiBanks)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FChip(
                    b.name,
                    b.id == bank.id,
                    () => onChanged(b.id, months),
                    icon: Icons.account_balance_rounded,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(flex: 3, child: _H('Tenure')),
              Expanded(flex: 4, child: _H('Monthly')),
              Expanded(flex: 4, child: _H('Interest')),
              Expanded(flex: 4, child: _H('Total', end: true)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        for (final p in plans)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(bank.id, p.months);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
              decoration: BoxDecoration(
                color: p.months == months
                    ? TX.violet.withValues(alpha: 0.07)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: p.months == months ? TX.violet : TX.line,
                  width: p.months == months ? 1.6 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      '${p.months} mo',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: TX.ink,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      formatPrice(p.monthly.ceilToDouble()),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: TX.blue,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 4,
                    child: p.noCost
                        ? Container(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: TX.success,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'No cost',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          )
                        : Text(
                            formatPrice(p.interest.roundToDouble()),
                            style: const TextStyle(color: TX.muted),
                          ),
                  ),
                  Expanded(
                    flex: 4,
                    child: Text(
                      formatPrice(p.total.roundToDouble()),
                      textAlign: TextAlign.end,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: TX.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Text(
          price < kNoCostMinOrder
              ? 'No-cost EMI is available on orders above ${formatPrice(kNoCostMinOrder)}.'
              : 'No-cost EMI: the bank\'s interest is given back to you as an instant discount. ${bank.name} charges ${(bank.rate * 100).toStringAsFixed(0)}% p.a. on other tenures, plus a processing fee of up to ${formatPrice(kEmiProcessingFee)} + GST.',
          style: const TextStyle(fontSize: 11.5, color: TX.muted, height: 1.35),
        ),
      ],
    );
  }
}

class _H extends StatelessWidget {
  const _H(this.text, {this.end = false});
  final String text;
  final bool end;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: end ? TextAlign.end : TextAlign.start,
    style: const TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w800,
      color: TX.muted,
    ),
  );
}

/// EMI calculator + Pay Later options.
class EmiScreen extends StatefulWidget {
  const EmiScreen({super.key, this.price = 0, this.name});
  final double price;
  final String? name;

  @override
  State<EmiScreen> createState() => _EmiScreenState();
}

class _EmiScreenState extends State<EmiScreen> {
  late double _price = widget.price > 0 ? widget.price : 49999;
  String _bank = kEmiBanks.first.id;
  int _months = 6;

  @override
  Widget build(BuildContext context) {
    final plan = emiPlan(
      kEmiBanks.firstWhere((b) => b.id == _bank),
      _months,
      _price,
    );
    final noCost = bestNoCost(_price);
    return TrustScaffold(
      title: 'EMI & Pay Later',
      subtitle: widget.name ?? 'Calculate your monthly payment',
      children: [
        THero(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                plan.noCost ? 'NO-COST EMI' : 'YOUR EMI',
                style: const TextStyle(
                  color: Color(0xFFC9D2FF),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatPrice(plan.monthly.ceilToDouble()),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 7, left: 4),
                    child: Text(
                      '/month',
                      style: TextStyle(color: Color(0xFFC9D2FF)),
                    ),
                  ),
                ],
              ),
              Text(
                '${plan.months} months • ${plan.bank.name} • ${plan.noCost ? 'you pay exactly ${formatPrice(_price)}' : 'total ${formatPrice(plan.total.roundToDouble())}'}',
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
              if (plan.noCost) ...[
                const SizedBox(height: 6),
                Text(
                  'Interest of ${formatPrice(plan.noCostDiscount.roundToDouble())} waived as an instant discount',
                  style: const TextStyle(
                    color: Color(0xFF86EFAC),
                    fontSize: 12,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (widget.price <= 0) ...[
          const TTitle('Phone price'),
          TCard(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 4),
            child: Column(
              children: [
                Text(
                  formatPrice(_price),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: TX.ink,
                  ),
                ),
                Slider(
                  value: _price,
                  min: 5000,
                  max: 160000,
                  divisions: 155,
                  onChanged: (v) =>
                      setState(() => _price = (v / 1000).round() * 1000 - 1),
                ),
              ],
            ),
          ),
        ],
        TTitle(
          'Card EMI',
          trailing: noCost == null
              ? null
              : TPill('No-cost up to $noCost mo', color: TX.green),
        ),
        EmiPlanPicker(
          price: _price,
          bankId: _bank,
          months: _months,
          onChanged: (b, m) => setState(() {
            _bank = b;
            _months = m;
          }),
        ),
        const TTitle('Pay Later'),
        for (final o in kPayLater) ...[
          _PayLaterCard(option: o, amount: _price),
          const SizedBox(height: 10),
        ],
        const Text(
          'EMI is offered by the bank on your credit card. Pay Later and Cardless EMI need a quick KYC and are subject to approval by the lending partner.',
          style: TextStyle(fontSize: 11.5, color: TX.faint, height: 1.35),
        ),
      ],
    );
  }
}

class _PayLaterCard extends StatelessWidget {
  const _PayLaterCard({required this.option, required this.amount});
  final PayLaterOption option;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final ok = option.allows(amount);
    final f = DateFormat('d MMM');
    final sched = option.schedule(amount, DateTime.now());
    return Opacity(
      opacity: ok ? 1 : 0.55,
      child: TCard(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                TIcon(
                  option.parts == 1
                      ? Icons.schedule_rounded
                      : option.id == 'cardless'
                      ? Icons.credit_card_off_rounded
                      : Icons.pie_chart_rounded,
                  size: 38,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFDBA74), Color(0xFFEA580C)],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: TX.ink,
                        ),
                      ),
                      Text(
                        ok
                            ? option.subtitle
                            : 'Available up to ${formatPrice(option.limit)}',
                        style: const TextStyle(fontSize: 12, color: TX.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (ok) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final (i, (d, a)) in sched.take(3).indexed)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF4E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${option.parts == 1
                            ? 'Due'
                            : i == 0
                            ? 'Today'
                            : f.format(d)}${option.parts == 1 ? ' ${f.format(d)}' : ''}: ${formatPrice(a.ceilToDouble())}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF9A3412),
                        ),
                      ),
                    ),
                  if (sched.length > 3)
                    Text(
                      '+${sched.length - 3} more',
                      style: const TextStyle(fontSize: 12, color: TX.muted),
                    ),
                ],
              ),
              if (option.fee > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'One-time convenience fee ${formatPrice(option.fee)}',
                    style: const TextStyle(fontSize: 11.5, color: TX.muted),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
