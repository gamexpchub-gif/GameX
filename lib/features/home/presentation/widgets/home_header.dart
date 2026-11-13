import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/widgets/glass.dart';
import 'design_scale.dart';

/// Logo + bell. The block spans design y 100…192.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.notifications,
    required this.onBell,
    this.onAvatar,
  });

  final int notifications;
  final VoidCallback onBell;

  /// When set, a profile avatar is shown right of the bell (Category page).
  final VoidCallback? onAvatar;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final avatar = onAvatar != null;
    return SizedBox(
      height: 92 * k,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 42 * k,
            top: 0,
            child: Image.asset(
              'assets/images/home/logo_gamex.png',
              width: 292 * k,
              height: 92 * k,
              filterQuality: FilterQuality.medium,
              color: dark ? Colors.white : null,
              colorBlendMode: dark ? BlendMode.srcIn : null,
            ),
          ),
          // Bell: centre (778, 143) on Home; (686, 137) d72 next to the avatar.
          Positioned(
            left: (avatar ? 650 : 739) * k,
            top: (avatar ? 1 : 4) * k,
            child: GestureDetector(
              onTap: onBell,
              child: Glass(
                radius: 39 * k,
                color: Colors.white.withValues(alpha: 0.6),
                child: SizedBox(
                  width: (avatar ? 72 : 78) * k,
                  height: (avatar ? 72 : 78) * k,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 46 * k,
                    color: dark ? Colors.white : HomeColors.ink,
                  ),
                ),
              ),
            ),
          ),
          if (notifications > 0)
            Positioned(
              left: (avatar ? 690 : 783) * k,
              top: (avatar ? -2 : 4) * k,
              child: IgnorePointer(
                child: Container(
                  width: 34 * k,
                  height: 34 * k,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: HomeColors.red,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5 * k),
                  ),
                  child: Text(
                    '$notifications',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18 * k,
                      height: 1,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          if (avatar)
            Positioned(
              left: 752 * k,
              top: 1 * k,
              child: GestureDetector(
                onTap: onAvatar,
                child: Container(
                  width: 72 * k,
                  height: 72 * k,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFF1B2F6E), Color(0xFF060B1E)],
                      center: Alignment(-0.3, -0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0B1A4A).withValues(alpha: 0.3),
                        blurRadius: 12 * k,
                        offset: Offset(0, 5 * k),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: ShaderMask(
                    blendMode: BlendMode.srcIn,
                    shaderCallback: (r) => const LinearGradient(
                      colors: [Color(0xFF7FB2FF), Color(0xFF1F5BFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(r),
                    child: Text(
                      'G',
                      style: TextStyle(
                        fontSize: 44 * k,
                        height: 1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({
    super.key,
    required this.onScan,
    this.height = 76,
    this.side = 36,
  });
  final VoidCallback onScan;

  /// Design-px height and side margin (Home 76/36, Category 67/30).
  final double height;
  final double side;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side * k),
      child: Glass(
        radius: height / 2 * k,
        color: dark ? null : const Color(0xFFE2EAFE),
        child: SizedBox(
          height: height * k,
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push('/search'),
                  child: Row(
                    children: [
                      SizedBox(width: 30 * k),
                      Icon(
                        Icons.search_rounded,
                        size: 44 * k,
                        color: dark ? Colors.white : HomeColors.ink,
                      ),
                      SizedBox(width: 18 * k),
                      Expanded(
                        child: Text(
                          'Search for your dream mobile...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22 * k,
                            color: dark ? Colors.white70 : HomeColors.hint,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                width: 2.2 * k,
                height: 38 * k,
                color: const Color(0xFF6E86D6).withValues(alpha: 0.8),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onScan,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22 * k, 14 * k, 30 * k, 14 * k),
                  child: Icon(
                    Icons.center_focus_weak_rounded,
                    size: 44 * k,
                    color: HomeColors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
