import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/i18n/i18n.dart';
import 'core/router/app_router.dart';
import 'core/storage.dart';
import 'core/theme/app_theme.dart';
import 'features/commerce/services/notification_service.dart';
import 'features/profile/providers/theme_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const GameXShopApp(),
    ),
  );
}

class GameXShopApp extends ConsumerWidget {
  const GameXShopApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NotificationsHost(
      child: MaterialApp.router(
        title: 'GameX Shop',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ref.watch(themeModeProvider),
        routerConfig: appRouter,
        locale: Locale(ref.watch(localeProvider)),
        supportedLocales: const [Locale('en'), Locale('hi'), Locale('bn')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
      ),
    );
  }
}
