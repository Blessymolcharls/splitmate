import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/utils/money_formatter.dart';
import 'package:splitmate/core/utils/money_parser.dart';

void main() {
  group('MoneyFormatter', () {
    test('formats positive amounts without decimals when integer', () {
      expect(MoneyFormatter.formatPaise(2000), '₹20');
      expect(MoneyFormatter.formatPaise(125000), '₹1,250');
      expect(MoneyFormatter.formatPaise(0), '₹0');
    });

    test('formats fractional paise amounts with decimals', () {
      expect(MoneyFormatter.formatPaise(2050), '₹20.50');
      expect(MoneyFormatter.formatPaise(3334), '₹33.34');
      expect(MoneyFormatter.formatPaise(3333), '₹33.33');
      expect(MoneyFormatter.formatPaise(1), '₹0.01');
    });

    test('formats signed balances correctly', () {
      expect(MoneyFormatter.formatPaise(85000, showSign: true), '+₹850');
      expect(MoneyFormatter.formatPaise(-40000), '-₹400');
      expect(MoneyFormatter.formatPaise(-40000, showSign: true), '-₹400');
      expect(MoneyFormatter.formatPaise(-28000, showSign: true), '-₹280');
      expect(MoneyFormatter.formatPaise(0, showSign: true), '₹0');
    });

    test('round-trip parsing and formatting preserves exact value', () {
      const originalPaise = 2050;
      final formatted = MoneyFormatter.formatPaise(originalPaise);
      final parsed = MoneyParser.parseToPaise(formatted);
      expect(parsed, originalPaise);
    });

    test('toEditingString formats cleanly for inputs', () {
      expect(MoneyFormatter.toEditingString(2000), '20');
      expect(MoneyFormatter.toEditingString(2050), '20.50');
      expect(MoneyFormatter.toEditingString(125000), '1250');
    });
  });
}
