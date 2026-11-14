import 'package:intl/intl.dart';

final _taka = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Formats an amount in Indian Rupees, e.g. ₹1,25,000.
String formatPrice(num amount) => _taka.format(amount);

String formatDate(DateTime date) =>
    DateFormat('d MMM yyyy, h:mm a').format(date);
