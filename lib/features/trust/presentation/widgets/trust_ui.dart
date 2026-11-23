import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// Design tokens for the GAMEX Trust screens (light 3D / liquid glass).
abstract final class TX {
  static const ink = Color(0xFF0D1030);
  static const muted = Color(0xFF5E6484);
  static const faint = Color(0xFF9AA0B8);
  static const line = Color(0xFFE4E3F6);
  static const violet = Color(0xFF7B3DF5);
  static const blue = Color(0xFF2F6BFF);
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFE11D48);

  static const cta = LinearGradient(
    colors: [Color(0xFF17B6FF), Color(0xFF3B5BFF), Color(0xFF8E3DFF)],
  );
  static const chip = LinearGradient(
    colors: [Color(0xFF2F6BFF), Color(0xFF8E3DFF)],
  );
  static const night = LinearGradient(
    colors: [Color(0xFF14104A), Color(0xFF3B23B8), Color(0xFF2F6BFF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const success = LinearGradient(
    colors: [Color(0xFF0F9F6E), Color(0xFF16A34A), Color(0xFF22C55E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const danger = LinearGradient(
    colors: [Color(0xFF9F1239), Color(0xFFE11D48), Color(0xFFFB7185)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static List<BoxShadow> soft([double a = 0.08]) => [
    BoxShadow(
      color: const Color(0xFF5B4BD6).withValues(alpha: a),
      blurRadius: 22,
      offset: const Offset(0, 10),
    ),
  ];
}

/// Page shell: lavender background, back button, title and subtitle.
class TrustScaffold extends StatelessWidget {
  const TrustScaffold({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
    this.bottom,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 6, 16, 28),
  });
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final Widget? bottom;
  final Widget? trailing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F2FF),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF6F3FF), Color(0xFFF0F4FF), Color(0xFFF7F2FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, top + 10, 16, 8),
              child: Row(
                children: [
                  TrustRoundButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () =>
                        context.canPop() ? context.pop() : context.go('/home'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            color: TX.ink,
                            letterSpacing: -0.4,
                          ),
                        ),
                        if (subtitle != null)
                          Text(
                            subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: TX.muted,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            Expanded(
              child: ListView(padding: padding, children: children),
            ),
            if (bottom != null)
              Container(
                padding: EdgeInsets.fromLTRB(
                  16,
                  10,
                  16,
                  12 + MediaQuery.paddingOf(context).bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  boxShadow: TX.soft(0.06),
                ),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }
}

class TrustRoundButton extends StatelessWidget {
  const TrustRoundButton({super.key, required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: TX.soft(0.12),
      ),
      child: Icon(icon, color: TX.ink),
    ),
  );
}

/// Glass card.
class TCard extends StatelessWidget {
  const TCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.border,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? border;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(22),
      boxShadow: TX.soft(0.07),
    ),
    child: Material(
      color: color ?? Colors.white.withValues(alpha: 0.9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: border ?? Colors.white, width: 1.4),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

/// Big gradient hero card with glossy highlight.
class THero extends StatelessWidget {
  const THero({
    super.key,
    required this.child,
    this.gradient = TX.night,
    this.padding = const EdgeInsets.all(18),
  });
  final Widget child;
  final Gradient gradient;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(26),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF3B23B8).withValues(alpha: 0.3),
          blurRadius: 26,
          offset: const Offset(0, 12),
        ),
      ],
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(26),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.14),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -50,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.16),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    ),
  );
}

/// Gradient icon tile.
class TIcon extends StatelessWidget {
  const TIcon(this.icon, {super.key, this.gradient = TX.chip, this.size = 42});
  final IconData icon;
  final Gradient gradient;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: gradient,
      borderRadius: BorderRadius.circular(size * 0.32),
      boxShadow: [
        BoxShadow(
          color: TX.violet.withValues(alpha: 0.28),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    foregroundDecoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * 0.32),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: 0.3),
          Colors.white.withValues(alpha: 0),
        ],
      ),
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.52),
  );
}

/// Section title with gradient accent bar.
class TTitle extends StatelessWidget {
  const TTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
    child: Row(
      children: [
        Container(
          width: 5,
          height: 19,
          decoration: BoxDecoration(
            gradient: TX.chip,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 17.5,
              fontWeight: FontWeight.w900,
              color: TX.ink,
              letterSpacing: -0.3,
            ),
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

/// Primary gradient pill button.
class TButton extends StatelessWidget {
  const TButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.height = 54,
    this.gradient = TX.cta,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool busy;
  final double height;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !busy;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(height / 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5B4BFF).withValues(alpha: 0.32),
              blurRadius: 16,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.center,
            colors: [
              Colors.white.withValues(alpha: 0.26),
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
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 21),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Outlined pill button.
class TGhost extends StatelessWidget {
  const TGhost({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.color = TX.ink,
    this.height = 54,
  });
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Material(
      color: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: color == TX.ink ? TX.line : color.withValues(alpha: 0.4),
          width: 1.3,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 7),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Small coloured status pill.
class TPill extends StatelessWidget {
  const TPill(this.text, {super.key, required this.color, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon ?? Icons.circle, size: icon == null ? 7 : 14, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w800,
            fontSize: 12,
          ),
        ),
      ],
    ),
  );
}

/// Label/value row.
class TRow extends StatelessWidget {
  const TRow(
    this.label,
    this.value, {
    super.key,
    this.icon,
    this.valueColor,
    this.mono = false,
    this.last = false,
  });
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final bool mono;
  final bool last;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      border: last
          ? null
          : const Border(bottom: BorderSide(color: Color(0xFFEFEEF8))),
    ),
    child: Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 18, color: TX.muted),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(label, style: const TextStyle(color: TX.muted)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: valueColor ?? TX.ink,
              fontFeatures: mono ? const [FontFeature.tabularFigures()] : null,
              letterSpacing: mono ? 0.6 : null,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Text field styled for the trust screens.
InputDecoration tInput(String hint, {Widget? prefix, Widget? suffix}) {
  final r = BorderRadius.circular(18);
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: TX.faint, fontWeight: FontWeight.w500),
    filled: true,
    fillColor: Colors.white,
    isDense: true,
    prefixIcon: prefix,
    suffixIcon: suffix,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: r,
      borderSide: const BorderSide(color: TX.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: const BorderSide(color: TX.line),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: r,
      borderSide: const BorderSide(color: TX.violet, width: 1.6),
    ),
  );
}

void tSnack(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? const Color(0xFF9F1239) : TX.ink,
        content: Row(
          children: [
            Icon(
              error ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg)),
          ],
        ),
      ),
    );
}
