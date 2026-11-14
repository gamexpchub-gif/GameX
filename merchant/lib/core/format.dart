import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

String inr(num v) => _inr.format(v);

String inrShort(num v) {
  if (v >= 1e7) return '₹${(v / 1e7).toStringAsFixed(2)}Cr';
  if (v >= 1e5) return '₹${(v / 1e5).toStringAsFixed(2)}L';
  if (v >= 1e3) return '₹${(v / 1e3).toStringAsFixed(1)}K';
  return inr(v);
}

String dateShort(DateTime d) => DateFormat('d MMM').format(d);
String dateTime(DateTime d) => DateFormat('d MMM, h:mm a').format(d);
String dateLong(DateTime d) => DateFormat('d MMM yyyy').format(d);

String ago(DateTime d) {
  final m = DateTime.now().difference(d).inMinutes;
  if (m < 1) return 'just now';
  if (m < 60) return '${m}m ago';
  if (m < 1440) return '${m ~/ 60}h ago';
  return '${m ~/ 1440}d ago';
}

/// "1h 20m" style countdown, or null once [deadline] has passed.
String? timeLeft(DateTime deadline) {
  final d = deadline.difference(DateTime.now());
  if (d.isNegative) return null;
  if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes % 60}m';
  return '${d.inMinutes}m';
}

/// Luhn check used for IMEI numbers.
bool validImei(String s) {
  if (!RegExp(r'^\d{15}$').hasMatch(s)) return false;
  var sum = 0;
  for (var i = 0; i < 15; i++) {
    var n = int.parse(s[14 - i]);
    if (i.isOdd) {
      n *= 2;
      if (n > 9) n -= 9;
    }
    sum += n;
  }
  return sum % 10 == 0;
}
