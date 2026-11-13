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

  /// Card number with Luhn checksum (13–19 digits).
  static String? cardNumber(String? v) {
    final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
    if (d.length < 13 || d.length > 19) return 'Enter a valid card number';
    var sum = 0;
    for (var i = 0; i < d.length; i++) {
      var n = int.parse(d[d.length - 1 - i]);
      if (i.isOdd) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      sum += n;
    }
    return sum % 10 == 0 ? null : 'Card number is not valid';
  }

  /// MM/YY in the future.
  static String? cardExpiry(String? v) {
    final m = RegExp(r'^(\d{2})/(\d{2})$').firstMatch(v ?? '');
    if (m == null) return 'MM/YY';
    final month = int.parse(m.group(1)!);
    final year = 2000 + int.parse(m.group(2)!);
    if (month < 1 || month > 12) return 'Invalid month';
    final now = DateTime.now();
    if (DateTime(year, month + 1).isBefore(DateTime(now.year, now.month))) {
      return 'Card expired';
    }
    return null;
  }

  static String? cvv(String? v) =>
      RegExp(r'^\d{3,4}$').hasMatch(v ?? '') ? null : 'Invalid CVV';
}
