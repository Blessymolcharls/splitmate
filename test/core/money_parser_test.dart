import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/errors/app_exceptions.dart';
import 'package:splitmate/core/utils/money_parser.dart';

void main() {
  group('MoneyParser', () {
    test('converts whole rupees correctly (₹20 -> 2000 paise)', () {
      expect(MoneyParser.parseToPaise('20'), 2000);
      expect(MoneyParser.parseToPaise('₹20'), 2000);
      expect(MoneyParser.parseToPaise('₹ 20'), 2000);
      expect(MoneyParser.parseToPaise('1250'), 125000);
    });

    test('converts decimal rupees correctly (₹20.50 -> 2050 paise)', () {
      expect(MoneyParser.parseToPaise('20.5'), 2050);
      expect(MoneyParser.parseToPaise('20.50'), 2050);
      expect(MoneyParser.parseToPaise('₹20.50'), 2050);
      expect(MoneyParser.parseToPaise('1,250.75'), 125075);
    });

    test('converts minimum unit (₹0.01 -> 1 paise)', () {
      expect(MoneyParser.parseToPaise('0.01'), 1);
      expect(MoneyParser.parseToPaise('₹0.01'), 1);
    });

    test('rejects negative values', () {
      expect(
        () => MoneyParser.parseToPaise('-20'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => MoneyParser.parseToPaise('-0.50'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects excessively precise values', () {
      expect(
        () => MoneyParser.parseToPaise('20.555'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => MoneyParser.parseToPaise('10.1234'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects malformed and empty values', () {
      expect(
        () => MoneyParser.parseToPaise(''),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => MoneyParser.parseToPaise('abc'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => MoneyParser.parseToPaise('20.2.2'),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects zero unless allowZero is explicitly true', () {
      expect(
        () => MoneyParser.parseToPaise('0'),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => MoneyParser.parseToPaise('0.00'),
        throwsA(isA<ValidationException>()),
      );
      expect(MoneyParser.parseToPaise('0', allowZero: true), 0);
      expect(MoneyParser.parseToPaise('0.00', allowZero: true), 0);
    });

    test('tryParseToPaise returns null for invalid input', () {
      expect(MoneyParser.tryParseToPaise('invalid'), isNull);
      expect(MoneyParser.tryParseToPaise('-10'), isNull);
      expect(MoneyParser.tryParseToPaise('10.999'), isNull);
      expect(MoneyParser.tryParseToPaise('100.50'), 10050);
    });
  });
}
