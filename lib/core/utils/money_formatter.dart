import 'package:intl/intl.dart';

class MoneyFormatter {
  MoneyFormatter._();

  /// Formats an integer amount in paise into a clean INR string (e.g., ₹1,250 or ₹33.34).
  ///
  /// Examples:
  /// - `2000` -> `₹20`
  /// - `2050` -> `₹20.50`
  /// - `125000` -> `₹1,250`
  /// - `-40000` with showSign -> `-₹400`
  /// - `85000` with showSign -> `+₹850`
  static String formatPaise(
    int paise, {
    bool showSign = false,
    bool alwaysDecimals = false,
  }) {
    final isNegative = paise < 0;
    final absPaise = paise.abs();
    final rupees = absPaise ~/ 100;
    final fractionalPaise = absPaise % 100;

    final numberFormat = NumberFormat('#,##,###', 'en_IN');
    final formattedRupees = numberFormat.format(rupees);

    String amountString;
    if (alwaysDecimals || fractionalPaise > 0) {
      final paddedFraction = fractionalPaise.toString().padLeft(2, '0');
      amountString = '$formattedRupees.$paddedFraction';
    } else {
      amountString = formattedRupees;
    }

    if (isNegative) {
      return '-₹$amountString';
    } else if (showSign && paise > 0) {
      return '+₹$amountString';
    } else {
      return '₹$amountString';
    }
  }

  /// Formats paise into plain decimal string for text editing inputs (e.g., 20 or 20.50).
  static String toEditingString(int paise) {
    final absPaise = paise.abs();
    final rupees = absPaise ~/ 100;
    final fraction = absPaise % 100;
    if (fraction == 0) {
      return '$rupees';
    }
    return '$rupees.${fraction.toString().padLeft(2, '0')}';
  }
}
