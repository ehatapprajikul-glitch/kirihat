import 'package:intl/intl.dart';

class CurrencyHelper {
  static final NumberFormat _indianCurrencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _indianCurrencyFormatWhole = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 0,
  );

  /// Formats the given [amount] using Indian currency format.
  /// [amount] can be int, double, or String.
  /// Returns '₹0' if formatting fails or amount is null/zero.
  static String format(dynamic amount) {
    if (amount == null) return '₹0';
    try {
      double value;
      if (amount is int) {
        value = amount.toDouble();
      } else if (amount is double) {
        value = amount;
      } else if (amount is String) {
        value = double.parse(amount);
      } else {
        return '₹0';
      }

      // Check if it's a whole number (or close enough for floating point)
      if (value % 1 == 0) {
        return _indianCurrencyFormatWhole.format(value);
      } else {
        return _indianCurrencyFormat.format(value);
      }
    } catch (e) {
      return '₹0';
    }
  }
}
