import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../core/storage.dart';
import '../../trust/presentation/widgets/trust_ui.dart';

enum HealthTest {
  display(
    'Display colours',
    Icons.palette_rounded,
    'Look for dead pixels, lines or patches on each colour',
  ),
  touch(
    'Touch screen',
    Icons.touch_app_rounded,
    'Swipe over every square until the screen is filled',
  ),
  speaker(
    'Speaker',
    Icons.volume_up_rounded,
    'Play a test tone at a comfortable volume',
  ),
  mic('Microphone', Icons.mic_rounded, 'Say "Hello GAMEX" when asked'),
  camera(
    'Cameras',
    Icons.photo_camera_rounded,
    'Check the rear and front cameras focus clearly',
  ),
  vibration(
    'Vibration',
    Icons.vibration_rounded,
    'Feel the phone vibrate in your hand',
  );

  const HealthTest(this.title, this.icon, this.hint);
  final String title;
  final IconData icon;
  final String hint;
}

/// Saved results: test name → pass (true) / fail (false).
class HealthReport extends Notifier<Map<String, bool>> {
  static const _key = 'health_report_v1';
  static const _atKey = 'health_report_at_v1';

  @override
  Map<String, bool> build() =>
      ref
          .read(localStoreProvider)
          .readJson(_key, (j) => Map<String, bool>.from(j as Map)) ??
      const {};

  DateTime? get at =>
      DateTime.tryParse(ref.read(localStoreProvider).readString(_atKey) ?? '');

  void set(HealthTest t, bool ok) {
    state = {...state, t.name: ok};
    ref.read(localStoreProvider).writeJson(_key, state);
    ref
        .read(localStoreProvider)
        .writeString(_atKey, DateTime.now().toIso8601String());
  }

  void reset() {
    state = const {};
    ref.read(localStoreProvider).remove(_key);
  }
}

final healthReportProvider = NotifierProvider<HealthReport, Map<String, bool>>(
  HealthReport.new,
);

/// Step-by-step phone health check.
class HealthCheckScreen extends ConsumerWidget {
  const HealthCheckScreen({super.key});

  Future<void> _run(BuildContext context, WidgetRef ref, HealthTest t) async {
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => switch (t) {
          HealthTest.display => const _DisplayTest(),
          HealthTest.touch => const _TouchTest(),
          HealthTest.speaker => const _SpeakerTest(),
          HealthTest.mic => const _MicTest(),
          HealthTest.camera => const _CameraTest(),
          HealthTest.vibration => const _VibrationTest(),
        },
      ),
    );
    if (ok != null) ref.read(healthReportProvider.notifier).set(t, ok);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = ref.watch(healthReportProvider);
    final done = r.length;
    final passed = r.values.where((v) => v).length;
    final next = HealthTest.values
        .where((t) => !r.containsKey(t.name))
        .firstOrNull;
    final at = ref.read(healthReportProvider.notifier).at;
    return TrustScaffold(
      title: 'Phone health check',
      subtitle: 'Test your phone in 2 minutes',
      trailing: done == 0
          ? null
          : TextButton(
              onPressed: () => ref.read(healthReportProvider.notifier).reset(),
              child: const Text('Reset'),
            ),
      bottom: next == null
          ? null
          : TButton(
              label: done == 0 ? 'Start health check' : 'Next: ${next.title}',
              icon: Icons.play_arrow_rounded,
              onTap: () => _run(context, ref, next),
            ),
      children: [
        THero(
          child: Row(
            children: [
              SizedBox(
                width: 84,
                height: 84,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: done / HealthTest.values.length,
                        strokeWidth: 8,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation(
                          passed == done
                              ? const Color(0xFF4ADE80)
                              : const Color(0xFFFFC542),
                        ),
                      ),
                    ),
                    Text(
                      '$done/${HealthTest.values.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      done == 0
                          ? 'Is everything working?'
                          : done < HealthTest.values.length
                          ? '$passed passed so far'
                          : passed == done
                          ? 'Your phone is healthy'
                          : '${done - passed} test(s) need attention',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      at == null
                          ? 'Run these checks within 7 days of delivery. Problems are covered by returns or warranty.'
                          : 'Last checked ${DateFormat('d MMM, h:mm a').format(at)}',
                      style: const TextStyle(
                        color: Color(0xFFC9D2FF),
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
        const SizedBox(height: 14),
        for (final t in HealthTest.values) ...[
          TCard(
            onTap: () => _run(context, ref, t),
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            child: Row(
              children: [
                TIcon(t.icon, size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: TX.ink,
                        ),
                      ),
                      Text(
                        t.hint,
                        style: const TextStyle(fontSize: 12, color: TX.muted),
                      ),
                    ],
                  ),
                ),
                switch (r[t.name]) {
                  true => const TPill(
                    'Passed',
                    color: TX.green,
                    icon: Icons.check_rounded,
                  ),
                  false => const TPill(
                    'Problem',
                    color: TX.red,
                    icon: Icons.error_rounded,
                  ),
                  null => const Icon(
                    Icons.chevron_right_rounded,
                    color: TX.faint,
                  ),
                },
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (r.values.contains(false))
          TCard(
            child: Row(
              children: [
                const Icon(Icons.support_agent_rounded, color: TX.violet),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Something not working? Request a return or raise a warranty claim from your order.',
                    style: TextStyle(fontSize: 12.5, color: TX.ink),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Orders'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Pass / fail footer shared by the tests.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.question, this.dark = false});
  final String question;
  final bool dark;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            question,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: dark ? Colors.white : TX.ink,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TGhost(
                  label: 'Problem',
                  icon: Icons.close_rounded,
                  color: TX.red,
                  height: 48,
                  onTap: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TButton(
                  label: 'Works fine',
                  icon: Icons.check_rounded,
                  height: 48,
                  gradient: TX.success,
                  onTap: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────────── Display ─────────────────────────────

class _DisplayTest extends StatefulWidget {
  const _DisplayTest();

  @override
  State<_DisplayTest> createState() => _DisplayTestState();
}

class _DisplayTestState extends State<_DisplayTest> {
  static const _colors = [
    Colors.red,
    Colors.green,
    Colors.blue,
    Colors.white,
    Colors.black,
    Color(0xFF808080),
  ];
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final last = _i == _colors.length - 1;
    return Scaffold(
      backgroundColor: _colors[_i],
      body: GestureDetector(
        onTap: last ? null : () => setState(() => _i++),
        child: SizedBox.expand(
          child: last
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      color: Colors.white,
                      child: const _Verdict(
                        question: 'Did every colour look even, with no dead pixels or lines?',
                      ),
                    ),
                  ],
                )
              : Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Colour ${_i + 1}/${_colors.length} • tap for next',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Touch ─────────────────────────────

class _TouchTest extends StatefulWidget {
  const _TouchTest();

  @override
  State<_TouchTest> createState() => _TouchTestState();
}

class _TouchTestState extends State<_TouchTest> {
  static const _cols = 7;
  static const _rows = 13;
  final _hit = <int>{};

  void _touch(Offset p, Size s) {
    final c = (p.dx / s.width * _cols).floor().clamp(0, _cols - 1);
    final r = (p.dy / s.height * _rows).floor().clamp(0, _rows - 1);
    if (_hit.add(r * _cols + c)) {
      setState(() {});
      if (_hit.length == _cols * _rows) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFF0D1030),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Swipe to fill every square (${_hit.length}/${_cols * _rows})',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Some squares won\'t fill',
                    style: TextStyle(color: Color(0xFFFB7185)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) => GestureDetector(
                onPanDown: (d) => _touch(d.localPosition, c.biggest),
                onPanUpdate: (d) => _touch(d.localPosition, c.biggest),
                child: GridView.count(
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: _cols,
                  childAspectRatio:
                      (c.maxWidth / _cols) / (c.maxHeight / _rows),
                  children: [
                    for (var i = 0; i < _cols * _rows; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.all(1.5),
                        decoration: BoxDecoration(
                          color: _hit.contains(i)
                              ? const Color(0xFF22C55E)
                              : Colors.white10,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ───────────────────────────── Speaker ─────────────────────────────

/// 16-bit mono WAV with a short two-tone chime.
Uint8List toneWav({int ms = 1800, int rate = 22050}) {
  final n = rate * ms ~/ 1000;
  final data = ByteData(44 + n * 2);
  void str(int o, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(o + i, s.codeUnitAt(i));
    }
  }

  str(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  str(8, 'WAVE');
  str(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  str(36, 'data');
  data.setUint32(40, n * 2, Endian.little);
  for (var i = 0; i < n; i++) {
    final t = i / rate;
    final f = t < ms / 2000 ? 660.0 : 880.0;
    final env = math.min(1.0, math.min(t * 20, (ms / 1000 - t) * 20));
    final v = (math.sin(2 * math.pi * f * t) * 0.6 * env * 32767).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

class _SpeakerTest extends StatefulWidget {
  const _SpeakerTest();

  @override
  State<_SpeakerTest> createState() => _SpeakerTestState();
}

class _SpeakerTestState extends State<_SpeakerTest> {
  final _player = AudioPlayer();
  bool _played = false;
  String? _error;

  Future<void> _play() async {
    try {
      await _player.play(BytesSource(toneWav(), mimeType: 'audio/wav'));
      setState(() => _played = true);
    } catch (e) {
      setState(() => _error = 'Could not play sound on this device');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TestScaffold(
    test: HealthTest.speaker,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _play,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: TX.cta,
              shape: BoxShape.circle,
              boxShadow: TX.soft(0.3),
            ),
            child: const Icon(
              Icons.volume_up_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _error ?? (_played ? 'Tap to play again' : 'Tap to play a test tone'),
          style: TextStyle(
            color: _error != null ? TX.red : TX.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
    footer: _played
        ? const _Verdict(question: 'Was the sound clear and without crackling?')
        : null,
  );
}

// ───────────────────────────── Microphone ─────────────────────────────

class _MicTest extends StatefulWidget {
  const _MicTest();

  @override
  State<_MicTest> createState() => _MicTestState();
}

class _MicTestState extends State<_MicTest> {
  final _stt = SpeechToText();
  String _heard = '';
  double _level = 0;
  bool _listening = false;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _error = null;
      _heard = '';
    });
    try {
      final ok = await _stt.initialize();
      if (!ok) {
        setState(() => _error = 'Allow microphone access to run this test');
        return;
      }
      setState(() => _listening = true);
      await _stt.listen(
        onResult: (r) {
          setState(() => _heard = r.recognizedWords);
          if (r.finalResult && mounted) {
            setState(() => _listening = false);
            if (_heard.toLowerCase().contains('hello') ||
                _heard.toLowerCase().contains('game')) {
              HapticFeedback.heavyImpact();
              Future.delayed(const Duration(milliseconds: 700), () {
                if (mounted) Navigator.pop(context, true);
              });
            }
          }
        },
        onSoundLevelChange: (l) => setState(() => _level = l),
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 8),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      setState(() {
        _listening = false;
        _error = 'Microphone test is not available on this device';
      });
    }
  }

  @override
  void dispose() {
    _stt.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _TestScaffold(
    test: HealthTest.mic,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _listening ? null : _start,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 130 + (_listening ? (_level.clamp(-2, 10) + 2) * 4 : 0),
            height: 130 + (_listening ? (_level.clamp(-2, 10) + 2) * 4 : 0),
            decoration: BoxDecoration(
              gradient: _listening
                  ? const LinearGradient(
                      colors: [Color(0xFFFF5F8F), Color(0xFFE11D48)],
                    )
                  : TX.cta,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic_rounded, color: Colors.white, size: 60),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _error ??
              (_listening
                  ? 'Say "Hello GAMEX"'
                  : _heard.isEmpty
                  ? 'Tap the mic and say "Hello GAMEX"'
                  : 'We heard: "$_heard"'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _error != null ? TX.red : TX.ink,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
      ],
    ),
    footer: _heard.isNotEmpty && !_listening
        ? const _Verdict(question: 'Did we hear you correctly?')
        : null,
  );
}

// ───────────────────────────── Camera ─────────────────────────────

class _CameraTest extends StatefulWidget {
  const _CameraTest();

  @override
  State<_CameraTest> createState() => _CameraTestState();
}

class _CameraTestState extends State<_CameraTest> {
  final _c = MobileScannerController(formats: const [BarcodeFormat.qrCode]);
  bool _front = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: Stack(
      children: [
        Positioned.fill(
          child: MobileScanner(
            controller: _c,
            errorBuilder: (_, e) => const Center(
              child: Text(
                'Camera not available. Allow camera access in Settings.',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () async {
                    await _c.switchCamera();
                    setState(() => _front = !_front);
                  },
                  icon: const Icon(Icons.cameraswitch_rounded),
                  label: Text(_front ? 'Rear camera' : 'Front camera'),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            color: Colors.black54,
            child: const _Verdict(
              question: 'Are both cameras clear and in focus?',
              dark: true,
            ),
          ),
        ),
      ],
    ),
  );
}

// ───────────────────────────── Vibration ─────────────────────────────

class _VibrationTest extends StatefulWidget {
  const _VibrationTest();

  @override
  State<_VibrationTest> createState() => _VibrationTestState();
}

class _VibrationTestState extends State<_VibrationTest> {
  bool _done = false;

  Future<void> _buzz() async {
    for (var i = 0; i < 3; i++) {
      await HapticFeedback.vibrate();
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    setState(() => _done = true);
  }

  @override
  Widget build(BuildContext context) => _TestScaffold(
    test: HealthTest.vibration,
    body: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _buzz,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              gradient: TX.cta,
              shape: BoxShape.circle,
              boxShadow: TX.soft(0.3),
            ),
            child: const Icon(
              Icons.vibration_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Hold the phone and tap the button',
          style: TextStyle(color: TX.muted, fontWeight: FontWeight.w700),
        ),
      ],
    ),
    footer: _done
        ? const _Verdict(question: 'Did you feel 3 vibrations?')
        : null,
  );
}

class _TestScaffold extends StatelessWidget {
  const _TestScaffold({required this.test, required this.body, this.footer});
  final HealthTest test;
  final Widget body;
  final Widget? footer;

  @override
  Widget build(BuildContext context) => TrustScaffold(
    title: test.title,
    subtitle: test.hint,
    bottom: footer,
    children: [
      const SizedBox(height: 90),
      Center(child: body),
    ],
  );
}
