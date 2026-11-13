import 'package:material_ui/material_ui.dart';

import '../theme/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({
    super.key,
    this.size = 72,
    this.showName = true,
    this.light = false,
  });

  final double size;
  final bool showName;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final mark = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: light ? null : AppColors.primaryGradient,
        color: light ? Colors.white : null,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: size * 0.4,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        Icons.shopping_bag_rounded,
        size: size * 0.55,
        color: light ? AppColors.primary : Colors.white,
      ),
    );
    if (!showName) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: size * 0.25),
        Text.rich(
          TextSpan(
            text: 'GameX',
            children: const [
              TextSpan(
                text: ' Shop',
                style: TextStyle(fontWeight: FontWeight.w400),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: light ? Colors.white : null,
          ),
        ),
      ],
    );
  }
}
