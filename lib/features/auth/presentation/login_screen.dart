import 'package:material_ui/material_ui.dart';

import 'auth_screen.dart';

/// `/login` – the auth screen opened on the Login tab.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key, this.redirectTo});
  final String? redirectTo;

  @override
  Widget build(BuildContext context) =>
      AuthScreen(initialTab: 0, redirectTo: redirectTo);
}
