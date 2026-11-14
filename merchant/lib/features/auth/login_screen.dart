import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../data/models.dart';
import '../../data/store.dart';

const _cities = [
  'Mumbai',
  'Delhi',
  'Bengaluru',
  'Hyderabad',
  'Chennai',
  'Kolkata',
  'Pune',
  'Ahmedabad',
  'Jaipur',
  'Lucknow',
];

/// Seller sign-in: mobile number → OTP → store setup.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  int _step = 0;
  bool _busy = false;
  String? _error;
  final _phone = TextEditingController();
  final _otp = TextEditingController();
  final _store = TextEditingController();
  final _owner = TextEditingController();
  final _gst = TextEditingController();
  String _city = 'Mumbai';
  bool _agree = true;

  @override
  void dispose() {
    for (final c in [_phone, _otp, _store, _owner, _gst]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _next() async {
    setState(() => _error = null);
    if (_step == 0) {
      if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_phone.text)) {
        return setState(() => _error = 'Enter a valid 10-digit mobile number');
      }
    } else if (_step == 1) {
      if (_otp.text != '123456') {
        return setState(() => _error = 'Incorrect OTP. Use 123456 for demo.');
      }
    } else {
      if (_store.text.trim().length < 3) {
        return setState(() => _error = 'Enter your store name');
      }
      if (_owner.text.trim().length < 3) {
        return setState(() => _error = 'Enter the owner name');
      }
      final gst = _gst.text.trim().toUpperCase();
      if (gst.isNotEmpty &&
          !RegExp(r'^\d{2}[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$')
              .hasMatch(gst)) {
        return setState(() => _error = 'GSTIN format looks wrong');
      }
      if (!_agree) {
        return setState(() => _error = 'Please accept the seller agreement');
      }
    }
    setState(() => _busy = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() => _busy = false);
    if (_step < 2) {
      HapticFeedback.lightImpact();
      setState(() => _step++);
      return;
    }
    await ref
        .read(sellerProvider.notifier)
        .signIn(
          Seller(
            phone: '+91 ${_phone.text}',
            ownerName: _owner.text.trim(),
            storeName: _store.text.trim(),
            city: _city,
            gstin: _gst.text.trim().toUpperCase(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      ('Sell on GAMEX', 'Reach lakhs of buyers looking for certified phones.'),
      ('Verify your number', 'We sent a 6-digit code to +91 ${_phone.text}'),
      ('Set up your store', 'This is what buyers see on your listings.'),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          children: [
            Row(
              children: [
                if (_step > 0)
                  IconButton(
                    onPressed: () => setState(() {
                      _step--;
                      _error = null;
                    }),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Image.asset('assets/img/logo_gamex.png', height: 30),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    gradient: C.brandGradient,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'SELLER',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (_step == 0) const _Hero(),
            const SizedBox(height: 22),
            Row(
              children: List.generate(
                3,
                (i) => Expanded(
                  child: Container(
                    height: 4,
                    margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                    decoration: BoxDecoration(
                      color: i <= _step ? C.primary : C.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              titles[_step].$1,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: C.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(titles[_step].$2, style: const TextStyle(color: C.muted)),
            const SizedBox(height: 20),
            ..._fields(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: C.red,
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: C.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 22),
            GradientButton(
              label: ['Get OTP', 'Verify & continue', 'Open my store'][_step],
              icon: [
                Icons.sms_rounded,
                Icons.verified_rounded,
                Icons.storefront_rounded,
              ][_step],
              busy: _busy,
              onPressed: _next,
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Secured with 256-bit encryption',
                style: TextStyle(color: C.faint, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields() => switch (_step) {
    0 => [
      TextField(
        controller: _phone,
        autofocus: false,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(
          counterText: '',
          labelText: 'Mobile number',
          prefixIcon: Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 8, 14),
            child: Text(
              '+91',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        onSubmitted: (_) => _next(),
      ),
    ],
    1 => [
      TextField(
        controller: _otp,
        autofocus: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        textAlign: TextAlign.center,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontSize: 28,
          letterSpacing: 14,
          fontWeight: FontWeight.w800,
        ),
        decoration: const InputDecoration(counterText: '', hintText: '••••••'),
        onSubmitted: (_) => _next(),
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: C.primary, size: 18),
            SizedBox(width: 8),
            Text(
              'Demo OTP: 123456',
              style: TextStyle(color: C.primary, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ],
    _ => [
      TextField(
        controller: _store,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Store name',
          hintText: 'e.g. Mobile Point Andheri',
          prefixIcon: Icon(Icons.storefront_outlined),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _owner,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Owner name',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: _city,
        decoration: const InputDecoration(
          labelText: 'Pickup city',
          prefixIcon: Icon(Icons.location_city_rounded),
        ),
        items: [
          for (final c in _cities) DropdownMenuItem(value: c, child: Text(c)),
        ],
        onChanged: (v) => setState(() => _city = v ?? _city),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _gst,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(
          labelText: 'GSTIN (optional)',
          hintText: '27ABCDE1234F1Z5',
          prefixIcon: Icon(Icons.receipt_outlined),
        ),
      ),
      const SizedBox(height: 8),
      CheckboxListTile(
        value: _agree,
        onChanged: (v) => setState(() => _agree = v ?? false),
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        title: const Text(
          'I agree to the GAMEX Seller Agreement & 8% commission',
          style: TextStyle(fontSize: 13.5),
        ),
      ),
    ],
  };
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    Widget stat(String v, String l) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            l,
            style: const TextStyle(color: Color(0xFFB9C2FF), fontSize: 11.5),
          ),
        ],
      ),
    );
    return Container(
      height: 190,
      decoration: BoxDecoration(
        gradient: C.nightGradient,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Turn your stock\ninto sales — fast.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: Row(
                    children: [
                      stat('12.5L+', 'Buyers'),
                      stat('7 days', 'Payouts'),
                      stat('8%', 'Commission'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
