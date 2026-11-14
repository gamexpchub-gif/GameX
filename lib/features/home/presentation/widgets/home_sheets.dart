import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/formatters.dart';

Future<void> _sheet(BuildContext context, Widget child) =>
    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: child,
        ),
      ),
    );

Widget _title(BuildContext context, String text, [String? sub]) => Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
      text,
      style: Theme.of(context).textTheme.titleLarge
          ?.copyWith(fontWeight: FontWeight.w800),
    ),
    if (sub != null) ...[
      const SizedBox(height: 4),
      Text(sub, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
    ],
    const SizedBox(height: 16),
  ],
);

/// Shown for the three trust cards (Verified, Battery, Support).
void showFeatureSheet(BuildContext context, int index) {
  const data = [
    (
      Icons.verified_user_rounded,
      '100% Verified Phones',
      [
        '52-point hardware & software inspection',
        'IMEI & ownership verified, no blacklisted devices',
        'Original parts only, factory reset & sanitised',
      ],
    ),
    (
      Icons.battery_full_rounded,
      'Long Life Battery',
      [
        'Minimum 85% battery health guaranteed',
        'Battery health shown on every listing',
        'Replaced with genuine cells when below standard',
      ],
    ),
    (
      Icons.headset_mic_rounded,
      '24/7 Customer Support',
      [
        'Call, chat or WhatsApp anytime',
        '7-day easy return, no questions asked',
        'Warranty claims handled within 48 hours',
      ],
    ),
  ];
  final (icon, title, points) = data[index];
  _sheet(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(icon, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(child: _title(context, title)),
          ],
        ),
        for (final p in points)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: AppColors.success,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(p)),
              ],
            ),
          ),
      ],
    ),
  );
}

void showNotificationsSheet(BuildContext context) {
  const items = [
    (
      Icons.local_offer_rounded,
      'Flash deal is live',
      'iPhone 14 Pro now 29% off. Ends at midnight.',
    ),
    (
      Icons.sync_rounded,
      'Trade-in bonus',
      'Get extra ₹2,000 when you exchange this week.',
    ),
    (
      Icons.verified_user_rounded,
      'New certified stock',
      '35 new GAMEX Certified phones just arrived.',
    ),
  ];
  _sheet(
    context,
    Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(context, 'Notifications'),
        for (final (icon, title, body) in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(body),
          ),
      ],
    ),
  );
}

void showEmiSheet(BuildContext context) =>
    _sheet(context, const _EmiCalculator());

class _EmiCalculator extends StatefulWidget {
  const _EmiCalculator();

  @override
  State<_EmiCalculator> createState() => _EmiCalculatorState();
}

class _EmiCalculatorState extends State<_EmiCalculator> {
  double _price = 49999;
  int _months = 12;

  @override
  Widget build(BuildContext context) {
    final monthly = _price / _months;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          context,
          'Smart EMI calculator',
          '0% interest on selected bank cards',
        ),
        Text(
          'Phone price: ${formatPrice(_price)}',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        Slider(
          value: _price,
          min: 12000,
          max: 150000,
          divisions: 138,
          onChanged: (v) =>
              setState(() => _price = (v / 1000).round() * 1000 - 1),
        ),
        const SizedBox(height: 8),
        const Text('Tenure', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 3, label: Text('3 mo')),
            ButtonSegment(value: 6, label: Text('6 mo')),
            ButtonSegment(value: 12, label: Text('12 mo')),
            ButtonSegment(value: 18, label: Text('18 mo')),
          ],
          selected: {_months},
          onSelectionChanged: (s) => setState(() => _months = s.first),
        ),
        const SizedBox(height: 20),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your monthly payment',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 4),
              Text(
                '${formatPrice(monthly)} /mo',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'for $_months months • No hidden charges',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

void showTradeInSheet(BuildContext context) =>
    _sheet(context, const _TradeIn());

class _TradeIn extends StatefulWidget {
  const _TradeIn();

  @override
  State<_TradeIn> createState() => _TradeInState();
}

class _TradeInState extends State<_TradeIn> {
  static const _models = <String, double>{
    'iPhone 13 Pro': 15000,
    'iPhone 12': 11000,
    'iPhone 11': 8000,
    'Galaxy S22': 9000,
    'Pixel 7': 7500,
    'OnePlus 10 Pro': 7000,
  };
  static const _conditions = <String, double>{
    'Like New': 1,
    'Good': 0.8,
    'Fair': 0.55,
  };

  String _model = _models.keys.first;
  String _condition = 'Like New';
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    final value = _models[_model]! * _conditions[_condition]!;
    if (_done) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: AppColors.success,
            size: 64,
          ),
          const SizedBox(height: 12),
          Text(
            'Pickup requested!',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Our agent will call you within 2 hours to schedule a free pickup for your $_model.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(
          context,
          'Trade-in your old phone',
          'Instant quote • Free doorstep pickup',
        ),
        DropdownButtonFormField<String>(
          initialValue: _model,
          decoration: const InputDecoration(labelText: 'Your phone'),
          items: [
            for (final m in _models.keys)
              DropdownMenuItem(value: m, child: Text(m)),
          ],
          onChanged: (v) => setState(() => _model = v ?? _model),
        ),
        const SizedBox(height: 16),
        const Text('Condition', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final c in _conditions.keys)
              ChoiceChip(
                label: Text(c),
                selected: _condition == c,
                onSelected: (_) => setState(() => _condition = c),
              ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            const Text('Estimated value'),
            const Spacer(),
            Text(
              formatPrice(value),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => setState(() => _done = true),
          child: const Text('Request Free Pickup'),
        ),
      ],
    );
  }
}
