import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';

class NavItem {
  const NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating frosted bottom bar matching the design. Static (no animation,
/// no live blur) so tab switches are instant and scrolling stays smooth.
///
/// Sizes are in the design's 852-px grid scaled to the device width.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  /// Height the bar occupies including its bottom margin.
  static double occupiedHeight(double width, double bottomInset) {
    final k = width / 852;
    return 114 * k + math.max(bottomInset, 14 * k) + 10 * k;
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final k = mq.size.width / 852;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final barH = 114 * k;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        12 * k,
        0,
        12 * k,
        math.max(mq.padding.bottom, 14 * k),
      ),
      child: Container(
        height: barH,
        decoration: BoxDecoration(
          color: dark ? const Color(0xF21B2133) : const Color(0xF5F8FAFF),
          borderRadius: BorderRadius.circular(barH / 2),
          border: Border.all(
            color: dark ? Colors.white10 : Colors.white,
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2A3D8F)
                  .withValues(alpha: dark ? 0.4 : 0.08),
              blurRadius: 24,
              blurStyle: BlurStyle.outer,
            ),
          ],
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: _NavButton(
                  item: items[i],
                  selected: i == currentIndex,
                  k: k,
                  dark: dark,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTap(i);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.selected,
    required this.k,
    required this.dark,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final double k;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final idle = dark ? const Color(0xFFD5DAEA) : const Color(0xFF151A2B);
    final color = selected ? AppColors.primary : idle;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: Container(
            width: 153 * k,
            height: 97 * k,
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(48 * k),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: dark
                          ? const [Color(0xFF2E3A63), Color(0xFF253055)]
                          : const [Color(0xFFEFF3FF), Color(0xFFDEE7FF)],
                    ),
                    border: Border.all(
                      color: dark ? Colors.white10 : Colors.white,
                      width: 1.2,
                    ),
                  )
                : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? item.activeIcon : item.icon,
                  size: 46 * k,
                  color: color,
                ),
                SizedBox(height: 5 * k),
                Text(
                  item.label,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 19 * k,
                    height: 1.1,
                    color: color,
                    fontWeight: FontWeight.w500,
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
