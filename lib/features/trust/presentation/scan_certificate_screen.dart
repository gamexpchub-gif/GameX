import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'widgets/trust_ui.dart';

/// Extracts a certificate number from a scanned QR payload
/// ("GAMEX-CERT|GXC-48120-1000|GXL..|imei|grade|battery") or a typed code.
String? parseCertificate(String raw) {
  final t = raw.trim();
  if (t.startsWith('GAMEX-CERT|')) {
    final parts = t.split('|');
    return parts.length > 1 && parts[1].isNotEmpty ? parts[1] : null;
  }
  final m = RegExp(r'GXC-\d+-\d+', caseSensitive: false).firstMatch(t);
  return m?.group(0)?.toUpperCase();
}

class ScanCertificateScreen extends StatefulWidget {
  const ScanCertificateScreen({super.key});

  @override
  State<ScanCertificateScreen> createState() => _ScanCertificateScreenState();
}

class _ScanCertificateScreenState extends State<ScanCertificateScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final _code = TextEditingController();
  bool _handled = false;
  bool _torch = false;

  @override
  void dispose() {
    _controller.dispose();
    _code.dispose();
    super.dispose();
  }

  void _open(String code) {
    if (_handled) return;
    _handled = true;
    HapticFeedback.mediumImpact();
    context.pushReplacement('/certificate/${Uri.encodeComponent(code)}');
  }

  void _onDetect(BarcodeCapture capture) {
    for (final b in capture.barcodes) {
      final code = parseCertificate(b.rawValue ?? '');
      if (code != null) return _open(code);
    }
  }

  void _manual() {
    final code = parseCertificate(_code.text);
    if (code == null) {
      return tSnack(
        context,
        'Enter a certificate number like GXC-48120-1000',
        error: true,
      );
    }
    _open(code);
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final box = w * 0.68;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _controller,
              onDetect: _onDetect,
              errorBuilder: (_, e) => _CameraError(
                message: e.errorDetails?.message ?? e.errorCode.name,
              ),
            ),
          ),
          // Dimmed overlay with a clear square cut-out.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(painter: _ScanOverlay(box)),
            ),
          ),
          Center(
            child: IgnorePointer(
              child: SizedBox(
                width: box,
                height: box,
                child: CustomPaint(painter: _Corners()),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _Circle(
                    icon: Icons.close_rounded,
                    onTap: () => context.pop(),
                  ),
                  const Expanded(
                    child: Text(
                      'Scan GAMEX Certificate',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  _Circle(
                    icon: _torch
                        ? Icons.flash_on_rounded
                        : Icons.flash_off_rounded,
                    onTap: () {
                      _controller.toggleTorch();
                      setState(() => _torch = !_torch);
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.sizeOf(context).height / 2 + box / 2 + 18,
            child: const Text(
              'Point at the QR code on the GAMEX certificate\nlabel inside the box',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16 + MediaQuery.paddingOf(context).bottom,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Or type the certificate number',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: TX.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          textCapitalization: TextCapitalization.characters,
                          onSubmitted: (_) => _manual(),
                          decoration: tInput(
                            'GXC-48120-1000',
                            prefix: const Icon(Icons.verified_outlined),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 92,
                        child: TButton(
                          label: 'Verify',
                          height: 50,
                          onTap: _manual,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  const _Circle({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white),
    ),
  );
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xFF14104A),
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.no_photography_outlined,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 12),
            const Text(
              'Camera not available',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Allow camera access in Settings, or type the certificate number below.\n($message)',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    ),
  );
}

class _ScanOverlay extends CustomPainter {
  _ScanOverlay(this.box);
  final double box;

  @override
  void paint(Canvas canvas, Size size) {
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: size.center(Offset.zero),
        width: box,
        height: box,
      ),
      const Radius.circular(28),
    );
    final path = Path()
      ..addRect(Offset.zero & size)
      ..addRRect(hole)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );
  }

  @override
  bool shouldRepaint(_ScanOverlay old) => old.box != box;
}

class _Corners extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF17B6FF), Color(0xFF8E3DFF)],
      ).createShader(Offset.zero & s)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    const l = 34.0;
    const r = 28.0;
    for (final (dx, dy) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)]) {
      final x = dx * s.width;
      final y = dy * s.height;
      final sx = dx == 0 ? 1 : -1;
      final sy = dy == 0 ? 1 : -1;
      final path = Path()
        ..moveTo(x, y + sy * l)
        ..lineTo(x, y + sy * r * 0.4)
        ..quadraticBezierTo(x, y, x + sx * r * 0.4, y)
        ..lineTo(x + sx * l, y);
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
