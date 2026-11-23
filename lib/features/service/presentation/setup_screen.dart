import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../discover/presentation/filter_sheet.dart' show FChip;
import '../../trust/presentation/widgets/trust_ui.dart';
import 'health_check_screen.dart';

/// "Set up your phone": health check, data transfer and hand-over checklist.
class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(healthReportProvider);
    return TrustScaffold(
      title: 'Phone setup & check',
      subtitle: 'Everything for your new phone',
      children: [
        THero(
          child: Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Got your new phone?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Check it in 2 minutes, move your data and prepare your old phone.',
                      style: TextStyle(
                        color: Color(0xFFC9D2FF),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.phonelink_setup_rounded,
                  color: Color(0xFFFFC542),
                  size: 34,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _Big(
          icon: Icons.health_and_safety_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFF2DD4BF), Color(0xFF0F766E)],
          ),
          title: 'Phone health check',
          text: r.isEmpty
              ? 'Display, touch, speaker, mic, cameras and vibration'
              : '${r.values.where((v) => v).length} of ${HealthTest.values.length} tests passed',
          onTap: () => context.push('/setup/check'),
        ),
        const SizedBox(height: 10),
        _Big(
          icon: Icons.swap_horizontal_circle_rounded,
          gradient: TX.chip,
          title: 'Move data from your old phone',
          text: 'Contacts, photos, WhatsApp, apps: step-by-step for iPhone and Android',
          onTap: () => context.push('/setup/transfer'),
        ),
        const SizedBox(height: 10),
        _Big(
          icon: Icons.build_circle_rounded,
          gradient: const LinearGradient(
            colors: [Color(0xFFFB7185), Color(0xFFE11D48)],
          ),
          title: 'Something not right?',
          text: 'Book a repair or raise a warranty claim',
          onTap: () => context.push('/repair'),
        ),
        const TTitle('Before giving away your old phone'),
        const TCard(
          child: Column(
            children: [
              _Check('Back up photos, chats and contacts'),
              _Check('Sign out of iCloud (Find My) or your Google account'),
              _Check('Unpair your smartwatch and earbuds'),
              _Check('Remove the SIM and memory card'),
              _Check(
                'Factory reset: Settings → General → Transfer or Reset (iPhone) / System → Reset (Android)',
                last: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TGhost(
          label: 'Sell or exchange your old phone',
          icon: Icons.sell_rounded,
          color: TX.violet,
          onTap: () => context.push('/sell'),
        ),
      ],
    );
  }
}

class _Big extends StatelessWidget {
  const _Big({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.text,
    required this.onTap,
  });
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => TCard(
    onTap: onTap,
    padding: const EdgeInsets.all(14),
    child: Row(
      children: [
        TIcon(icon, gradient: gradient, size: 50),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15.5,
                  color: TX.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                text,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: TX.muted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: TX.faint),
      ],
    ),
  );
}

class _Check extends StatelessWidget {
  const _Check(this.text, {this.last = false});
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.check_circle_rounded, color: TX.green, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: TX.ink, height: 1.35),
          ),
        ),
      ],
    ),
  );
}

// ───────────────────────────── Data transfer ─────────────────────────────

enum _Os { android, iphone }

class _Guide {
  const _Guide(this.title, this.time, this.steps, {this.tip});
  final String title;
  final String time;
  final List<String> steps;
  final String? tip;
}

const _guides = <(_Os, _Os), _Guide>{
  (_Os.iphone, _Os.iphone): _Guide(
    'Quick Start (iPhone to iPhone)',
    '15-30 min',
    [
      'Charge both phones and connect to the same Wi-Fi. Turn on Bluetooth.',
      'Switch on the new iPhone and keep it next to your old iPhone.',
      'Your old iPhone shows "Set Up New iPhone". Tap Continue.',
      'Scan the animation on the new iPhone with the old one.',
      'Enter your old iPhone passcode on the new iPhone.',
      'Choose "Transfer from iPhone". Keep both phones close until it finishes.',
    ],
    tip: 'No old iPhone with you? Restore from your latest iCloud backup during setup.',
  ),
  (_Os.android, _Os.android): _Guide(
    'Copy your data (Android to Android)',
    '20-40 min',
    [
      'On the old phone: Settings → Google → Backup → Back up now.',
      'Switch on the new phone and connect to Wi-Fi.',
      'On "Copy apps & data" tap Next and choose "A backup from an Android phone".',
      'Connect with a USB-C cable for the fastest transfer, or follow the wireless steps.',
      'Sign in with the same Google account and pick what to copy.',
    ],
    tip: 'Samsung? Use the Smart Switch app on both phones.',
  ),
  (_Os.android, _Os.iphone): _Guide(
    'Move to iOS (Android to iPhone)',
    '30-60 min',
    [
      'Install "Move to iOS" from the Play Store on your Android phone.',
      'Switch on the iPhone and choose "Move Data from Android" on the Apps & Data screen.',
      'Enter the 6-digit code shown on the iPhone into the Android app.',
      'Pick contacts, messages, photos, calendars and Google account data.',
      'Keep both phones charging and near each other until it finishes.',
    ],
    tip: 'WhatsApp chats can be moved in the same step on newer versions.',
  ),
  (_Os.iphone, _Os.android): _Guide(
    'Switch to Android (iPhone to Android)',
    '30-60 min',
    [
      'On the iPhone, turn off iMessage and FaceTime (Settings → Messages / FaceTime).',
      'Switch on the Android phone and connect to Wi-Fi.',
      'Choose "Copy apps & data" → "An iPhone device".',
      'Connect with a USB-C to Lightning cable, or use the Switch to Android app on the iPhone.',
      'Select contacts, photos, messages and apps to copy.',
    ],
    tip: 'Photos in iCloud? Turn on "Download and Keep Originals" first.',
  ),
};

class TransferGuideScreen extends StatefulWidget {
  const TransferGuideScreen({super.key});

  @override
  State<TransferGuideScreen> createState() => _TransferGuideScreenState();
}

class _TransferGuideScreenState extends State<TransferGuideScreen> {
  _Os _from = _Os.android;
  _Os _to = _Os.android;

  @override
  Widget build(BuildContext context) {
    final g = _guides[(_from, _to)]!;
    String name(_Os o) => o == _Os.iphone ? 'iPhone' : 'Android';
    return TrustScaffold(
      title: 'Move your data',
      subtitle: 'Step-by-step transfer guide',
      children: [
        TCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Old phone',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: TX.muted,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in _Os.values)
                    FChip(
                      name(o),
                      _from == o,
                      () => setState(() => _from = o),
                      icon: o == _Os.iphone
                          ? Icons.apple
                          : Icons.android_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'New phone',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: TX.muted,
                  fontSize: 12.5,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final o in _Os.values)
                    FChip(
                      name(o),
                      _to == o,
                      () => setState(() => _to = o),
                      icon: o == _Os.iphone
                          ? Icons.apple
                          : Icons.android_rounded,
                    ),
                ],
              ),
            ],
          ),
        ),
        TTitle(
          g.title,
          trailing: TPill(
            g.time,
            color: TX.violet,
            icon: Icons.schedule_rounded,
          ),
        ),
        for (final (i, s) in g.steps.indexed) ...[
          TCard(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: TX.chip,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s,
                    style: const TextStyle(color: TX.ink, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (g.tip != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF7E6),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.lightbulb_rounded, color: TX.amber),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    g.tip!,
                    style: const TextStyle(color: TX.ink, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        const TTitle('WhatsApp chats'),
        const TCard(
          child: Text(
            'Same type of phone: WhatsApp → Settings → Chats → Chat backup, then restore on the new phone with the same number.\n'
            'Switching between iPhone and Android: use WhatsApp → Settings → Chats → Transfer chats, or the "Move to iOS" / "Copy apps & data" step above.',
            style: TextStyle(color: TX.ink, height: 1.45, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
