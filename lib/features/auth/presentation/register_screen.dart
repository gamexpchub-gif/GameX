import 'package:material_ui/material_ui.dart';

import 'auth_screen.dart';

/// `/register` – the auth screen opened on the Create Account tab.
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key, this.redirectTo});
  final String? redirectTo;

  @override
  Widget build(BuildContext context) =>
      AuthScreen(initialTab: 1, redirectTo: redirectTo);
}
