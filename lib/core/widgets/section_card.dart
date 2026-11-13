import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';
import 'glass.dart';

/// Frosted content card used on cart, checkout and product pages.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Glass(
    radius: 22,
    color: Colors.white.withValues(alpha: 0.88),
    padding: padding,
    child: child,
  );
}

/// Icon badge + bold title (+ optional trailing widget).
class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.icon,
    required this.title,
    this.trailing,
  });
  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 18, color: AppColors.primary),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      ?trailing,
    ],
  );
}

/// White sticky bar pinned to the bottom of a page.
class StickyBottomBar extends StatelessWidget {
  const StickyBottomBar({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottom),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: Colors.white),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A3D8F).withValues(alpha: 0.12),
            blurRadius: 24,
            blurStyle: BlurStyle.outer,
          ),
        ],
      ),
      child: child,
    );
  }
}
