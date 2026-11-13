import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/storage.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../auth/providers/auth_provider.dart';

/// Key set once the user has signed in or chosen "Continue as guest".
const onboardedKey = 'onboarded_v1';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1600), _next);
  }

  void _next() {
    if (!mounted) return;
    final loggedIn = ref.read(authProvider) != null;
    final onboarded =
        ref.read(localStoreProvider).readString(onboardedKey) != null;
    context.go(loggedIn || onboarded ? '/home' : '/login');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curve = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
        alignment: Alignment.center,
        child: FadeTransition(
          opacity: _c,
          child: ScaleTransition(
            scale: Tween(begin: 0.7, end: 1.0).animate(curve),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                BrandLogo(size: 88, light: true),
                SizedBox(height: 8),
                Text(
                  'Shop smarter. Live better.',
                  style: TextStyle(color: Colors.white70, letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
