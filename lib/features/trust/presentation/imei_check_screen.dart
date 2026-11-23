import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/trust_api.dart';
import 'widgets/trust_ui.dart';

/// Check an IMEI before buying: checksum, GAMEX blacklist and listing status.
class ImeiCheckScreen extends ConsumerStatefulWidget {
  const ImeiCheckScreen({super.key, this.initial});
  final String? initial;

  @override
  ConsumerState<ImeiCheckScreen> createState() => _ImeiCheckScreenState();
}

class _ImeiCheckScreenState extends ConsumerState<ImeiCheckScreen> {
  late final _imei = TextEditingController(text: widget.initial ?? '');
  ImeiResult? _result;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _imei.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final v = _imei.text.replaceAll(RegExp(r'\D'), '');
    if (v.length != 15) {
      return setState(() => _error = 'IMEI has exactly 15 digits');
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await ref.read(trustApiProvider).checkImei(v);
      if (mounted) setState(() => _result = r);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final digits = (d?.text ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 15) {
      setState(() => _imei.text = digits.substring(0, 15));
    }
  }

  Future<void> _govCheck(String imei) async {
    // Department of Telecom "Know Your Mobile": SMS "KYM <IMEI>" to 14422.
    final uri = Uri.parse('sms:14422?body=${Uri.encodeComponent('KYM $imei')}');
    final ok = await launchUrl(uri);
    if (!ok && mounted) {
      tSnack(context, 'Send SMS “KYM $imei” to 14422', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _result;
    return TrustScaffold(
      title: 'IMEI Checker',
      subtitle: 'Lost • stolen • locked • listed',
      children: [
        THero(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.fact_check_rounded, color: Colors.white, size: 30),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Check any phone before you pay',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Dial *#06# on the phone to see its IMEI. We check it against GAMEX\'s blacklist of lost, stolen and financed devices.',
                style: TextStyle(
                  color: Color(0xFFC9D2FF),
                  fontSize: 12.5,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _imei,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(15),
                ],
                onSubmitted: (_) => _check(),
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.4,
                ),
                decoration: tInput(
                  '15-digit IMEI',
                  prefix: const Icon(Icons.qr_code_2_rounded),
                  suffix: IconButton(
                    onPressed: _paste,
                    icon: const Icon(Icons.content_paste_rounded),
                    tooltip: 'Paste',
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFFB4C0),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              TButton(
                label: 'Check IMEI',
                icon: Icons.search_rounded,
                busy: _busy,
                onTap: _check,
              ),
            ],
          ),
        ),
        if (r != null) ..._resultView(r),
        if (r == null) ...[
          const TTitle('What we check'),
          const TCard(
            child: Column(
              children: [
                _What(
                  Icons.calculate_outlined,
                  'Checksum',
                  'A real IMEI passes the Luhn check digit. Fake or edited numbers fail.',
                ),
                _What(
                  Icons.gpp_bad_outlined,
                  'GAMEX blacklist',
                  'Phones reported lost, stolen or with unpaid EMI.',
                ),
                _What(
                  Icons.verified_outlined,
                  'GAMEX certificate',
                  'Whether this exact phone was inspected and certified by GAMEX.',
                  last: true,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _resultView(ImeiResult r) {
    final safe = r.safe;
    final g = r.gamex;
    return [
      const SizedBox(height: 14),
      THero(
        gradient: safe ? TX.success : TX.danger,
        child: Row(
          children: [
            Icon(
              safe ? Icons.verified_user_rounded : Icons.gpp_bad_rounded,
              color: Colors.white,
              size: 46,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    safe
                        ? 'No problems found'
                        : r.blacklisted
                        ? 'Blacklisted device'
                        : 'Invalid IMEI',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    safe
                        ? 'Not reported on GAMEX. Also confirm with the government check below.'
                        : r.blacklisted
                        ? '${r.blacklistReason}. Do not buy this phone.'
                        : 'This number fails the IMEI check digit - it may be fake or mistyped.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      TCard(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Column(
          children: [
            TRow('IMEI', r.imei, icon: Icons.qr_code_2_rounded, mono: true),
            TRow(
              'Check digit',
              r.validChecksum ? 'Valid' : 'Invalid',
              icon: Icons.calculate_outlined,
              valueColor: r.validChecksum ? TX.green : TX.red,
            ),
            TRow(
              'GAMEX blacklist',
              r.blacklisted
                  ? 'Reported${r.reportedAt == null ? '' : ' ${DateFormat('d MMM yyyy').format(r.reportedAt!)}'}'
                  : 'Clear',
              icon: Icons.gpp_maybe_outlined,
              valueColor: r.blacklisted ? TX.red : TX.green,
            ),
            TRow(
              'GAMEX certificate',
              g == null
                  ? 'Not listed on GAMEX'
                  : (g['certificate'] as String? ?? 'In QC'),
              icon: Icons.verified_outlined,
              valueColor: g?['certificate'] != null ? TX.green : TX.muted,
              last: true,
            ),
          ],
        ),
      ),
      if (g != null && g['certificate'] != null) ...[
        const SizedBox(height: 12),
        TButton(
          label: 'Open certificate',
          icon: Icons.workspace_premium_rounded,
          onTap: () => context.push('/certificate/${g['certificate']}'),
        ),
      ],
      const SizedBox(height: 12),
      TCard(
        onTap: () => _govCheck(r.imei),
        child: Row(
          children: [
            const TIcon(
              Icons.account_balance_rounded,
              gradient: LinearGradient(
                colors: [Color(0xFFFB923C), Color(0xFFEA580C)],
              ),
              size: 40,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Government check (DoT • CEIR)',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: TX.ink,
                    ),
                  ),
                  Text(
                    'Sends “KYM <IMEI>” to 14422. The reply shows if the IMEI is blocked in India.',
                    style: TextStyle(
                      fontSize: 12,
                      color: TX.muted,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.sms_outlined, color: TX.violet),
          ],
        ),
      ),
    ];
  }
}

class _What extends StatelessWidget {
  const _What(this.icon, this.title, this.text, {this.last = false});
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
        TIcon(icon, size: 36),
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
