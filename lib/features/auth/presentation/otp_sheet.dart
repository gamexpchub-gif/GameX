import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../trust/presentation/widgets/trust_ui.dart';
import '../providers/auth_provider.dart';

/// Phone → SMS code → (name for new accounts). Returns true when logged in.
Future<bool> showOtpLogin(BuildContext context) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xFFF6F4FF),
      builder: (_) => const _OtpSheet(),
    ) ??
    false;

class _OtpSheet extends ConsumerStatefulWidget {
  const _OtpSheet();

  @override
  ConsumerState<_OtpSheet> createState() => _OtpSheetState();
}

class _OtpSheetState extends ConsumerState<_OtpSheet> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  int _step = 0; // 0 phone, 1 code, 2 name
  bool _busy = false;
  String? _error;
  String? _devCode;
  int _wait = 0;
  Timer? _t;

  @override
  void dispose() {
    _t?.cancel();
    _phone.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'\D'), '');

  Future<void> _send() async {
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(_digits)) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _devCode = await ref.read(authProvider.notifier).sendOtp(_digits);
      _code.clear();
      setState(() {
        _step = 1;
        _wait = 30;
      });
      _t?.cancel();
      _t = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted || _wait <= 0) return t.cancel();
        setState(() => _wait--);
      });
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final needsName = await ref
          .read(authProvider.notifier)
          .verifyOtp(_digits, _code.text);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      if (needsName) {
        setState(() => _step = 2);
      } else {
        Navigator.pop(context, true);
      }
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveName() async {
    final n = _name.text.trim();
    if (n.length < 2) {
      setState(() => _error = 'Please enter your name');
      return;
    }
    await ref
        .read(authProvider.notifier)
        .updateProfile(name: n, phone: ref.read(authProvider)?.phone);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          switch (_step) {
            0 => 'Login with OTP',
            1 => 'Enter the 6-digit code',
            _ => 'Welcome to GAMEX!',
          },
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: TX.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(switch (_step) {
          0 => 'We\'ll send a one-time code by SMS. No password needed.',
          1 => 'Sent to +91 ${_digits.substring(0, 5)} ${_digits.substring(5)}',
          _ => 'What should we call you?',
        }, style: const TextStyle(color: TX.muted)),
        const SizedBox(height: 16),
        if (_step == 0)
          TextField(
            controller: _phone,
            autofocus: true,
            keyboardType: TextInputType.phone,
            maxLength: 10,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            autofillHints: const [AutofillHints.telephoneNumberNational],
            onSubmitted: (_) => _send(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
            decoration: tInput(
              'Mobile number',
              prefix: const Padding(
                padding: EdgeInsets.fromLTRB(14, 14, 6, 14),
                child: Text(
                  '+91',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ).copyWith(counterText: ''),
          )
        else if (_step == 1) ...[
          TextField(
            controller: _code,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (v) {
              if (v.length == 6) _verify();
            },
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              letterSpacing: 14,
            ),
            decoration: tInput('••••••').copyWith(counterText: ''),
          ),
          if (_devCode != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Test mode: your code is $_devCode',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: TX.amber,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => setState(() => _step = 0),
                child: const Text('Change number'),
              ),
              TextButton(
                onPressed: _wait > 0 || _busy ? null : _send,
                child: Text(_wait > 0 ? 'Resend in ${_wait}s' : 'Resend code'),
              ),
            ],
          ),
        ] else
          TextField(
            controller: _name,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            onSubmitted: (_) => _saveName(),
            decoration: tInput(
              'Your full name',
              prefix: const Icon(Icons.person_outline_rounded),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: TX.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 14),
        TButton(
          label: switch (_step) {
            0 => 'Send code',
            1 => 'Verify & login',
            _ => 'Continue',
          },
          icon: switch (_step) {
            0 => Icons.sms_rounded,
            1 => Icons.verified_user_rounded,
            _ => Icons.arrow_forward_rounded,
          },
          busy: _busy,
          onTap: switch (_step) {
            0 => _send,
            1 => _verify,
            _ => _saveName,
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'By continuing you agree to the GAMEX Terms and Privacy Policy.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11.5, color: TX.faint),
        ),
      ],
    ),
  );
}
