import 'package:material_ui/material_ui.dart';

/// Design tokens for the "New Listing" flow (light 3D / liquid look).
abstract final class LX {
  static const ink = Color(0xFF0D1030);
  static const muted = Color(0xFF5E6484);
  static const line = Color(0xFFE4E3F6);
  static const violet = Color(0xFF7B3DF5);
  static const purple = Color(0xFF9B5CFF);
  static const blue = Color(0xFF2F6BFF);
  static const cyan = Color(0xFF16B4FF);
  static const green = Color(0xFF16A34A);
  static const red = Color(0xFFE5283B);

  /// Main CTA gradient (cyan → blue → violet).
  static const cta = LinearGradient(
    colors: [Color(0xFF17B6FF), Color(0xFF3B5BFF), Color(0xFF8E3DFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  /// Selected chip gradient (blue → violet).
  static const chip = LinearGradient(
    colors: [Color(0xFF2F6BFF), Color(0xFF8E3DFF)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  static const title = LinearGradient(
    colors: [Color(0xFF6A3DF5), Color(0xFFA63DF5)],
  );

  static const bg = LinearGradient(
    colors: [Color(0xFFF6F3FF), Color(0xFFF0F4FF), Color(0xFFF7F2FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> soft([double a = 0.10]) => [
    BoxShadow(
      color: const Color(0xFF5B4BD6).withValues(alpha: a),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Soft lavender page background with two blurred colour blobs.
class LxBackground extends StatelessWidget {
  const LxBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: LX.bg),
      child: Stack(
        children: [
          const Positioned(
            top: -120,
            right: -90,
            child: _Blob(color: Color(0x33A78BFA), size: 320),
          ),
          const Positioned(
            top: 380,
            left: -140,
            child: _Blob(color: Color(0x2238BDF8), size: 300),
          ),
          Positioned.fill(child: child),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
      ),
    ),
  );
}

/// Frosted white card (no blur; translucent fill + white rim + soft shadow).
class LxCard extends StatelessWidget {
  const LxCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 22,
    this.color,
    this.borderColor,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: LX.soft(0.07),
      ),
      child: Material(
        color: color ?? Colors.white.withValues(alpha: 0.86),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: borderColor ?? Colors.white, width: 1.4),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Gradient text (used for the second word of each page title).
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.style});
  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.srcIn,
    shaderCallback: (r) => LX.title.createShader(r),
    child: Text(text, style: style),
  );
}

/// Page title "Add **Product Photos**" with subtitle and a 3D illustration.
class LxHero extends StatelessWidget {
  const LxHero({
    super.key,
    required this.lead,
    required this.accent,
    required this.subtitle,
    required this.image,
    this.leadingImage,
  });
  final String lead;
  final String accent;
  final String subtitle;
  final String image;
  final String? leadingImage;

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final hasLead = leadingImage != null;
    final imgW = w * (hasLead ? 0.34 : 0.42);
    final accentPaint = Paint()
      ..shader = LX.title.createShader(const Rect.fromLTWH(0, 0, 220, 30));
    const base = TextStyle(
      fontSize: 26,
      height: 1.12,
      fontWeight: FontWeight.w900,
      color: LX.ink,
      letterSpacing: -0.6,
    );
    return SizedBox(
      height: 128,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -14,
            top: -4,
            bottom: 4,
            child: _Fade(
              child: Image.asset(
                'assets/img/listing/$image.png',
                width: imgW,
                fit: BoxFit.contain,
                alignment: Alignment.centerRight,
              ),
            ),
          ),
          Row(
            children: [
              if (hasLead) ...[
                _Fade(
                  child: Image.asset(
                    'assets/img/listing/$leadingImage.png',
                    width: 70,
                  ),
                ),
                const SizedBox(width: 4),
              ],
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: imgW * (image == 'hero_price' ? 0.85 : 0.62),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: '$lead '),
                            TextSpan(
                              text: accent,
                              style: base.copyWith(
                                color: null,
                                foreground: accentPaint,
                              ),
                            ),
                          ],
                        ),
                        style: base,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        maxLines: 3,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: LX.muted,
                        ),
                      ),
                    ],
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

/// Fades an illustration's square edges into the page background.
class _Fade extends StatelessWidget {
  const _Fade({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (r) => const RadialGradient(
      radius: 0.75,
      colors: [Colors.black, Colors.black, Colors.transparent],
      stops: [0, 0.72, 1],
    ).createShader(r),
    child: child,
  );
}

/// Section heading inside a card: icon, title (+ red asterisk), trailing.
class LxSection extends StatelessWidget {
  const LxSection({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.required = false,
    this.trailing,
    this.optional = false,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool required;
  final bool optional;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (r) => LX.chip.createShader(r),
            child: Icon(icon, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: title,
                    children: [
                      if (required)
                        const TextSpan(
                          text: ' *',
                          style: TextStyle(color: LX.red),
                        ),
                      if (optional)
                        const TextSpan(
                          text: ' (Optional)',
                          style: TextStyle(
                            color: LX.muted,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    color: LX.ink,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(fontSize: 12.5, color: LX.muted),
                  ),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Selectable pill: gradient + check when selected, white otherwise.
class LxPill extends StatelessWidget {
  const LxPill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.leading,
    this.dense = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget? leading;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: dense ? 36 : 42,
        padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 12),
        decoration: BoxDecoration(
          gradient: selected ? LX.chip : null,
          color: selected ? null : Colors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? Colors.transparent : LX.line,
            width: 1.2,
          ),
          boxShadow: selected ? LX.soft(0.28) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 6)],
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: dense ? 13.5 : 14.5,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : LX.ink,
                  ),
                ),
              ),
            ),
            if (selected && !dense) ...[
              const SizedBox(width: 6),
              Container(
                width: dense ? 16 : 18,
                height: dense ? 16 : 18,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: dense ? 12 : 13,
                  color: LX.violet,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Big gradient call-to-action button.
class LxButton extends StatelessWidget {
  const LxButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.trailingIcon,
    this.busy = false,
    this.height = 58,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final IconData? trailingIcon;
  final bool busy;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: LX.cta,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B4BFF).withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Colors.white.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(height / 2),
            onTap: enabled ? onTap : null,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.6,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 24),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (trailingIcon != null) ...[
                          const SizedBox(width: 10),
                          Icon(trailingIcon, color: Colors.white, size: 24),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// White pill outline button ("Back", "Save Draft").
class LxGhostButton extends StatelessWidget {
  const LxGhostButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.height = 58,
    this.color = LX.ink,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: LX.soft(0.08),
      ),
      child: Material(
        color: Colors.white,
        shape: StadiumBorder(side: BorderSide(color: LX.line)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: height > 50 ? 18 : 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Header: back button, GAMEX Seller logo + subtitle, Save Draft.
class LxHeader extends StatelessWidget {
  const LxHeader({
    super.key,
    required this.subtitle,
    required this.onBack,
    required this.onSaveDraft,
  });
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback? onSaveDraft;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: LX.soft(0.10),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: LX.ink),
          ),
        ),
        const SizedBox(width: 10),
        Image.asset('assets/img/g_logo.png', width: 40, height: 40),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'GAMEX ',
                        style: TextStyle(
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      TextSpan(
                        text: 'Seller',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  style: TextStyle(fontSize: 20, color: LX.ink, height: 1.1),
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 14, color: LX.muted),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onSaveDraft,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE6DDFE)),
              boxShadow: LX.soft(0.10),
            ),
            child: const Row(
              children: [
                Icon(Icons.description_outlined, color: LX.violet, size: 19),
                SizedBox(width: 5),
                Text(
                  'Save Draft',
                  style: TextStyle(
                    color: LX.violet,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// 5-step progress: done = blue check, current = violet icon + label pill.
class LxStepper extends StatelessWidget {
  const LxStepper({super.key, required this.step, required this.onTap});
  final int step;
  final ValueChanged<int> onTap;

  static const labels = ['Photos', 'Details', 'Condition', 'Price', 'Review'];
  static const icons = [
    Icons.image_outlined,
    Icons.sell_outlined,
    Icons.verified_user_outlined,
    Icons.savings_outlined,
    Icons.check_circle_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 76,
      child: Stack(
        children: [
          // Connecting line behind the circles.
          Positioned(
            left: 0,
            right: 0,
            top: 21,
            child: LayoutBuilder(
              builder: (_, c) {
                final seg = c.maxWidth / 5;
                return Stack(
                  children: [
                    Container(
                      margin: EdgeInsets.symmetric(horizontal: seg / 2),
                      height: 3,
                      color: LX.line,
                    ),
                    Container(
                      margin: EdgeInsets.only(left: seg / 2),
                      width: seg * step,
                      height: 3,
                      decoration: const BoxDecoration(gradient: LX.chip),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: i < step ? () => onTap(i) : null,
                    child: Column(
                      children: [
                        _dot(i),
                        const SizedBox(height: 6),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: i == step
                                ? LX.violet.withValues(alpha: 0.12)
                                : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              labels[i],
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: i == step
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                color: i == step ? LX.violet : LX.ink,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dot(int i) {
    if (i < step) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF3B82F6), Color(0xFF2F5BFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: LX.soft(0.25),
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
      );
    }
    if (i == step) {
      return Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF9B5CFF), Color(0xFF6A3DF5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: LX.violet.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icons[i], color: Colors.white, size: 22),
      );
    }
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: LX.line, width: 1.4),
        boxShadow: LX.soft(0.06),
      ),
      child: Icon(icons[i], color: LX.muted, size: 20),
    );
  }
}

/// Small coloured switch matching the design.
class LxSwitch extends StatelessWidget {
  const LxSwitch({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) => Transform.scale(
    scale: 0.82,
    child: Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: Colors.white,
      activeTrackColor: LX.blue,
      inactiveThumbColor: Colors.white,
      inactiveTrackColor: const Color(0xFFD5D7E6),
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

/// Dashed rounded rectangle (photo drop zone).
class DashedBox extends StatelessWidget {
  const DashedBox({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: CustomPaint(painter: _DashPainter(), child: child),
  );
}

class _DashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(18),
    );
    final path = Path()..addRRect(rr);
    final p = Paint()
      ..color = const Color(0xFFB9B2F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 7), p);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

/// Brand → logo asset (null when we only have a text label).
String? brandLogo(String brand) => switch (brand) {
  'Apple' => 'apple',
  'Samsung' => 'samsung',
  'Google' => 'google',
  'OnePlus' => 'oneplus',
  'vivo' => 'vivo',
  'Xiaomi' => 'xiaomi',
  'Realme' => 'realme',
  'Nothing' => 'nothing',
  'Motorola' => 'motorola',
  _ => null,
};

/// Colour name → swatch.
const kColours = <(String, Color)>[
  ('Black', Color(0xFF151515)),
  ('White', Color(0xFFF2F2F2)),
  ('Blue', Color(0xFF2F7BEF)),
  ('Purple', Color(0xFF8B55E8)),
  ('Green', Color(0xFF3DAA5C)),
  ('Red', Color(0xFFE53935)),
  ('Gold', Color(0xFFE2C08D)),
];
