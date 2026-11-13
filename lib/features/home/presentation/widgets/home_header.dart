import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/glass.dart';
import 'design_scale.dart';

/// GAMEX wordmark with gradient + tagline.
class GamexLogo extends StatelessWidget {
  const GamexLogo({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 277 * k,
          height: 50 * k,
          child: FittedBox(
            fit: BoxFit.fill,
            child: ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (r) => AppColors.logoGradient.createShader(r),
              child: const Text(
                'GAMEX',
                style: TextStyle(
                  fontSize: 64,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 7 * k),
        Padding(
          padding: EdgeInsets.only(left: 37 * k),
          child: Text(
            'Buy Smart. Sell Smart.',
            style: TextStyle(
              fontSize: 21 * k,
              height: 1,
              fontWeight: FontWeight.w500,
              color: dark ? Colors.white : HomeColors.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.notifications,
    required this.onBell,
  });

  final int notifications;
  final VoidCallback onBell;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.fromLTRB(48 * k, 18 * k, 35 * k, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const GamexLogo(),
          const Spacer(),
          GestureDetector(
            onTap: onBell,
            child: SizedBox(
              width: 82 * k,
              height: 82 * k,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: 0,
                    top: 4 * k,
                    child: Glass(
                      radius: 39 * k,
                      opacity: 0.7,
                      child: SizedBox(
                        width: 78 * k,
                        height: 78 * k,
                        child: Icon(
                          Icons.notifications_none_rounded,
                          size: 44 * k,
                          color: dark ? Colors.white : HomeColors.ink,
                        ),
                      ),
                    ),
                  ),
                  if (notifications > 0)
                    Positioned(
                      right: -4 * k,
                      top: -6 * k,
                      child: Container(
                        width: 34 * k,
                        height: 34 * k,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: HomeColors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2.5 * k,
                          ),
                        ),
                        child: Text(
                          '$notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17 * k,
                            height: 1,
                            fontWeight: FontWeight.w700,
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
    );
  }
}

class HomeSearchBar extends StatelessWidget {
  const HomeSearchBar({super.key, required this.onScan});
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    final k = context.k;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 36 * k),
      child: Glass(
        radius: 38 * k,
        opacity: 0.66,
        child: SizedBox(
          height: 76 * k,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => context.push('/search'),
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(38 * k),
                  ),
                  child: Row(
                    children: [
                      SizedBox(width: 30 * k),
                      Icon(
                        Icons.search_rounded,
                        size: 42 * k,
                        color: dark ? Colors.white : HomeColors.ink,
                      ),
                      SizedBox(width: 18 * k),
                      Expanded(
                        child: Text(
                          'Search for your dream mobile...',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 22.5 * k,
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
                height: 36 * k,
                color: const Color(0xFF7C8DC4).withValues(alpha: 0.7),
              ),
              InkWell(
                onTap: onScan,
                customBorder: const CircleBorder(),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(22 * k, 14 * k, 30 * k, 14 * k),
                  child: Icon(
                    Icons.center_focus_weak_rounded,
                    size: 42 * k,
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
