import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

/// Shared look for the Help Center screens (logical pixels, large text).
abstract final class SX {
  static const bg = Color(0xFFF1F4FB);
  static const ink = Color(0xFF0B1230);
  static const muted = Color(0xFF5B6585);
  static const line = Color(0xFFE3E8F4);
  static const blue = Color(0xFF1F5BFF);
  static const violet = Color(0xFF6D3BFF);
  static const green = Color(0xFF16A34A);
  static const amber = Color(0xFFD97706);
  static const red = Color(0xFFDC2626);

  static const hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0A2A8F), Color(0xFF1F5BFF), Color(0xFF6D3BFF)],
  );

  static const h1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: ink,
    letterSpacing: -0.3,
  );
  static const h2 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w800,
    color: ink,
  );
  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: ink,
  );
  static const body = TextStyle(fontSize: 15, color: ink, height: 1.45);
  static const small = TextStyle(fontSize: 13, color: muted, height: 1.35);
}

String supportTime(DateTime t) {
  final now = DateTime.now();
  final d = now.difference(t);
  if (d.inMinutes < 1) return 'now';
  if (d.inMinutes < 60) return '${d.inMinutes}m ago';
  if (d.inHours < 24 && now.day == t.day) return DateFormat('h:mm a').format(t);
  if (d.inDays < 7) return DateFormat('EEE, h:mm a').format(t);
  return DateFormat('d MMM, h:mm a').format(t);
}

class SCard extends StatelessWidget {
  const SCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color = Colors.white,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1E2A5A).withValues(alpha: 0.06),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.label, this.color, {super.key});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w800,
        fontSize: 12.5,
      ),
    ),
  );
}

Color ticketColor(String status) => switch (status) {
  'open' => SX.blue,
  'awaiting_customer' => SX.amber,
  'resolved' => SX.green,
  _ => SX.muted,
};

class SupportAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SupportAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) => AppBar(
    backgroundColor: SX.bg,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    toolbarHeight: 64,
    titleSpacing: 0,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: SX.h2.copyWith(fontSize: 19)),
        if (subtitle != null)
          Text(subtitle!, style: SX.small.copyWith(fontSize: 12.5)),
      ],
    ),
    actions: actions,
  );
}
