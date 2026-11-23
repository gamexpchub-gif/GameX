import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../../trust/presentation/widgets/trust_ui.dart';

/// Opens the voice search sheet and returns what the buyer said.
Future<String?> showVoiceSearch(BuildContext context) {
  HapticFeedback.mediumImpact();
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _VoiceSheet(),
  );
}

final _speech = SpeechToText();

class _VoiceSheet extends StatefulWidget {
  const _VoiceSheet();

  @override
  State<_VoiceSheet> createState() => _VoiceSheetState();
}

class _VoiceSheetState extends State<_VoiceSheet>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  String _text = '';
  String? _error;
  bool _listening = false;
  double _level = 0;
  Timer? _done;

  static const _examples = [
    'iPhone under 40k',
    '5G Samsung with good camera',
    'gaming phone 8GB RAM',
    'battery valo phone 25 hazar er niche',
  ];

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _error = null;
      _text = '';
    });
    try {
      final ok = await _speech.initialize(
        onError: (e) {
          if (mounted) {
            setState(() {
              _listening = false;
              _error = e.errorMsg == 'error_no_match'
                  ? 'Didn\'t catch that. Tap the mic and try again.'
                  : 'Voice search stopped. Tap the mic to retry.';
            });
          }
        },
        onStatus: (s) {
          if (!mounted) return;
          if (s == 'done' || s == 'notListening') {
            setState(() => _listening = false);
          }
        },
      );
      if (!ok) {
        setState(
          () => _error = 'Voice search is not available. Allow microphone access in Settings.',
        );
        return;
      }
      setState(() => _listening = true);
      await _speech.listen(
        onResult: _onResult,
        onSoundLevelChange: (l) {
          if (mounted) setState(() => _level = l);
        },
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_IN',
          partialResults: true,
          listenMode: ListenMode.search,
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _listening = false;
          _error = 'Voice search is not available on this device.';
        });
      }
    }
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!mounted) return;
    setState(() => _text = r.recognizedWords);
    if (r.finalResult && _text.trim().isNotEmpty) {
      HapticFeedback.lightImpact();
      _done = Timer(const Duration(milliseconds: 450), () {
        if (mounted) Navigator.pop(context, _text.trim());
      });
    }
  }

  @override
  void dispose() {
    _done?.cancel();
    _pulse.dispose();
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        14,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        gradient: TX.night,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            _error != null
                ? 'Hmm…'
                : _listening
                ? 'Listening…'
                : _text.isEmpty
                ? 'Tap to speak'
                : 'Got it',
            style: const TextStyle(
              color: Color(0xFFC9D2FF),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Center(
              child: Text(
                _error ??
                    (_text.isEmpty ? 'Say what phone you want' : '"$_text"'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _error != null ? 15 : 22,
                  fontWeight: FontWeight.w800,
                  height: 1.25,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _listening ? () => _speech.stop() : _start,
            child: SizedBox(
              width: 150,
              height: 150,
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, _) => CustomPaint(
                  painter: _Rings(
                    _listening ? _pulse.value : -1,
                    (_level.clamp(-2, 10) + 2) / 12,
                  ),
                  child: Center(
                    child: Container(
                      width: 78,
                      height: 78,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: _listening
                            ? const LinearGradient(
                                colors: [Color(0xFFFF5F8F), Color(0xFFE11D48)],
                              )
                            : TX.cta,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 18,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        _listening ? Icons.stop_rounded : Icons.mic_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Try saying',
            style: TextStyle(color: Color(0xFFC9D2FF), fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final e in _examples)
                GestureDetector(
                  onTap: () => Navigator.pop(context, e),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      e,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Rings extends CustomPainter {
  _Rings(this.t, this.level);

  /// Pulse phase 0..1, or -1 when idle.
  final double t;
  final double level;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    if (t < 0) return;
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final r = 40 + p * (32 + level * 10);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = const Color(0xFFFF7EA5).withValues(alpha: (1 - p) * 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 2 * math.sin(p * math.pi),
      );
    }
  }

  @override
  bool shouldRepaint(_Rings old) => old.t != t || old.level != level;
}
