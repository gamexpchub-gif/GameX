abstract final class Validators {
  static final _emailRe = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');

  /// Bangladeshi mobile number: 01XXXXXXXXX (optionally +88 prefix).
  static final _bdPhoneRe = RegExp(r'^(?:\+?88)?01[3-9]\d{8}$');

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    return _emailRe.hasMatch(v.trim()) ? null : 'Enter a valid email';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    return v.length < 6 ? 'At least 6 characters' : null;
  }

  static String? phone(String? v) {
    if (v == null || v.trim().isEmpty) return 'Phone number is required';
    final cleaned = v.replaceAll(RegExp(r'[\s-]'), '');
    return _bdPhoneRe.hasMatch(cleaned)
        ? null
        : 'Enter a valid number (01XXXXXXXXX)';
  }
}
