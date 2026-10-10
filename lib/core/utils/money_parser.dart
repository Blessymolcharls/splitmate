import '../errors/app_exceptions.dart';

class MoneyParser {
  MoneyParser._();

  /// Parses a user-inputted string in ₹ into integer paise.
  ///
  /// Accepted formats:
  /// - `20` -> 2000 paise
  /// - `20.5` -> 2050 paise
  /// - `20.50` -> 2050 paise
  /// - `0.01` -> 1 paise
  /// - `₹20.50` or `₹ 20.50` -> 2050 paise
  /// - `1,250.00` -> 125000 paise
  ///
  /// Rejects:
  /// - Negative values (e.g. `-20`)
  /// - More than 2 decimal places (e.g. `20.555`)
  /// - Zero if `allowZero` is false (default is false)
  /// - Malformed or empty strings
  static int parseToPaise(
    String? input, {
    bool allowZero = false,
  }) {
    if (input == null) {
      throw const ValidationException('Amount cannot be empty');
    }

    // Strip symbol, commas, and whitespace
    var sanitized = input
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .trim();

    if (sanitized.isEmpty) {
      throw const ValidationException('Please enter an amount');
    }

    if (sanitized.startsWith('-')) {
      throw const ValidationException('Amount must be positive');
    }

    // Check pattern: digits with optional . followed by 1 or 2 digits
    final regex = RegExp(r'^\d+(\.\d{1,2})?$');
    if (!regex.hasMatch(sanitized)) {
      if (sanitized.contains('.') && sanitized.split('.')[1].length > 2) {
        throw const ValidationException(
          'Amount cannot have more than 2 decimal places',
        );
      }
      throw const ValidationException('Invalid amount format');
    }

    final parts = sanitized.split('.');
    final rupees = int.parse(parts[0]);
    int paise = rupees * 100;

    if (parts.length > 1) {
      final fractionPart = parts[1];
      if (fractionPart.length == 1) {
        paise += int.parse(fractionPart) * 10;
      } else {
        paise += int.parse(fractionPart);
      }
    }

    if (paise == 0 && !allowZero) {
      throw const ValidationException('Amount must be greater than zero');
    }

    return paise;
  }

  /// Try-parse helper that returns null on error instead of throwing.
  static int? tryParseToPaise(String? input, {bool allowZero = false}) {
    try {
      return parseToPaise(input, allowZero: allowZero);
    } catch (_) {
      return null;
    }
  }
}
