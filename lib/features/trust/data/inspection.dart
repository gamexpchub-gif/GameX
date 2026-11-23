import 'package:material_ui/material_ui.dart';

import '../../../data/models/product.dart';

enum CheckResult { pass, minor, fail }

class InspectionItem {
  const InspectionItem(this.name, this.result, [this.note]);
  final String name;
  final CheckResult result;
  final String? note;
}

class InspectionGroup {
  const InspectionGroup(this.title, this.icon, this.items);
  final String title;
  final IconData icon;
  final List<InspectionItem> items;

  int get passed => items.where((i) => i.result == CheckResult.pass).length;
  bool get hasIssue => items.any((i) => i.result != CheckResult.pass);
}

class InspectionReport {
  const InspectionReport({
    required this.groups,
    required this.grade,
    required this.battery,
    required this.defects,
  });
  final List<InspectionGroup> groups;
  final String grade;
  final int battery;
  final List<PhotoDefect> defects;

  int get total => groups.fold(0, (s, g) => s + g.items.length);
  int get passed => groups.fold(0, (s, g) => s + g.passed);
  int get minor => groups.fold(
    0,
    (s, g) => s + g.items.where((i) => i.result == CheckResult.minor).length,
  );
  int get failed => groups.fold(
    0,
    (s, g) => s + g.items.where((i) => i.result == CheckResult.fail).length,
  );

  /// 0-100 score: fails cost more than cosmetic notes.
  int get score => (100 - minor * 2 - failed * 8).clamp(0, 100);
}

/// Normalised grade key from a product condition ("Excellent Condition").
String gradeKey(String? condition) {
  final c = (condition ?? '').toLowerCase();
  if (c.contains('like')) return 'likeNew';
  if (c.contains('good')) return 'good';
  if (c.contains('fair')) return 'fair';
  return 'excellent';
}

const gradeLabels = {
  'likeNew': 'Like New',
  'excellent': 'Excellent',
  'good': 'Good',
  'fair': 'Fair',
};

/// Builds the 32-point report from what the seller declared and GAMEX QC
/// verified (function checks, grade, battery health and marked defects).
InspectionReport buildInspection({
  required String grade,
  required int battery,
  Map<String, bool> checks = const {},
  List<PhotoDefect> defects = const [],
}) {
  bool ok(String key) => checks.isEmpty || (checks[key] ?? true);
  CheckResult f(bool v) => v ? CheckResult.pass : CheckResult.fail;

  // Cosmetic results follow the grade.
  final cosmetic = switch (grade) {
    'likeNew' => (CheckResult.pass, CheckResult.pass, CheckResult.pass),
    'excellent' => (CheckResult.pass, CheckResult.pass, CheckResult.minor),
    'good' => (CheckResult.minor, CheckResult.minor, CheckResult.minor),
    _ => (CheckResult.minor, CheckResult.minor, CheckResult.minor),
  };
  final glass = grade == 'fair' ? CheckResult.minor : CheckResult.pass;
  final display = ok('Display & touch');
  final face = ok('Face ID / Fingerprint');
  final cams = ok('Front & rear cameras');
  final audio = ok('Speakers & microphone');
  final radio = ok('Wi-Fi, Bluetooth & SIM');
  final port = ok('Charging port');
  final buttons = ok('Buttons & vibration');
  final unlocked = ok('No iCloud / Google lock');
  final bat = battery >= 85
      ? CheckResult.pass
      : battery >= 78
      ? CheckResult.minor
      : CheckResult.fail;

  return InspectionReport(
    grade: grade,
    battery: battery,
    defects: defects,
    groups: [
      InspectionGroup('Display', Icons.smartphone_rounded, [
        InspectionItem('Touch response', f(display)),
        InspectionItem('Dead pixels / lines', f(display)),
        InspectionItem('Brightness & colours', f(display)),
        InspectionItem('Screen burn-in', f(display)),
        InspectionItem(
          'Screen glass',
          glass,
          glass == CheckResult.minor ? 'Visible marks' : null,
        ),
      ]),
      InspectionGroup('Body & frame', Icons.crop_portrait_rounded, [
        InspectionItem(
          'Frame & edges',
          cosmetic.$1,
          cosmetic.$1 == CheckResult.minor ? 'Light signs of use' : null,
        ),
        InspectionItem(
          'Back panel',
          cosmetic.$2,
          cosmetic.$2 == CheckResult.minor ? 'Light scratches' : null,
        ),
        InspectionItem(
          'Camera glass',
          cosmetic.$3,
          cosmetic.$3 == CheckResult.minor ? 'Micro-scratches' : null,
        ),
        InspectionItem('Ports & speaker grills', f(port)),
      ]),
      InspectionGroup('Battery', Icons.battery_charging_full_rounded, [
        InspectionItem('Battery health', bat, '$battery% of original capacity'),
        InspectionItem('Charging', f(port)),
        InspectionItem('No swelling', CheckResult.pass),
      ]),
      InspectionGroup('Cameras', Icons.photo_camera_outlined, [
        InspectionItem('Rear camera', f(cams)),
        InspectionItem('Front camera', f(cams)),
        InspectionItem('Autofocus & zoom', f(cams)),
        InspectionItem('Flash / torch', f(cams)),
      ]),
      InspectionGroup('Audio & haptics', Icons.volume_up_outlined, [
        InspectionItem('Earpiece', f(audio)),
        InspectionItem('Loudspeaker', f(audio)),
        InspectionItem('Microphones', f(audio)),
        InspectionItem('Vibration motor', f(buttons)),
      ]),
      InspectionGroup('Connectivity', Icons.wifi_rounded, [
        InspectionItem('SIM & mobile network', f(radio)),
        InspectionItem('Wi-Fi', f(radio)),
        InspectionItem('Bluetooth', f(radio)),
        InspectionItem('GPS', f(radio)),
        InspectionItem('NFC', f(radio)),
      ]),
      InspectionGroup('Sensors & security', Icons.fingerprint_rounded, [
        InspectionItem('Face ID / fingerprint', f(face)),
        InspectionItem('Proximity sensor', f(display)),
        InspectionItem('Gyro & compass', CheckResult.pass),
        InspectionItem('Buttons', f(buttons)),
      ]),
      InspectionGroup('Software & locks', Icons.lock_open_rounded, [
        InspectionItem('No iCloud / Google lock', f(unlocked)),
        InspectionItem('Factory reset done', f(unlocked)),
        InspectionItem('IMEI matches body & box', CheckResult.pass),
      ]),
    ],
  );
}

InspectionReport inspectionFor(Product p) => buildInspection(
  grade: gradeKey(p.condition),
  battery: p.batteryHealth == 0 ? 90 : p.batteryHealth,
  checks: p.checks,
  defects: p.defects,
);
