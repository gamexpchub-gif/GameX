import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api.dart';

/// Which live services the GAMEX server has switched on (GET /config).
class AppConfig {
  const AppConfig(this.j);
  final Map<String, dynamic> j;

  /// msg91 | twilio | dev | off
  String get otp => j['otp'] as String? ?? 'off';
  bool get otpLogin => otp != 'off';

  /// razorpay | demo
  bool get razorpay => j['payments'] == 'razorpay' && razorpayKey != null;
  String? get razorpayKey => j['razorpayKey'] as String?;
  bool get push => j['push'] == true;
  bool get courier => j['courier'] == true;

  Map get _cod => j['cod'] as Map? ?? const {};
  bool get codEnabled => _cod['enabled'] != false;
  double get codNewLimit =>
      (_cod['newAccountLimit'] as num?)?.toDouble() ?? 15000;
  int get codMaxOpen => (_cod['maxOpen'] as num?)?.toInt() ?? 2;

  static const offline = AppConfig({});
}

final appConfigProvider = FutureProvider<AppConfig>((ref) async {
  try {
    return AppConfig(
      await ref.watch(apiProvider).get('/config') as Map<String, dynamic>,
    );
  } catch (_) {
    return AppConfig.offline;
  }
});
