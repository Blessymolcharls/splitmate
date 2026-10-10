import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/features/people/domain/person.dart';
import 'package:splitmate/features/settlements/domain/settlement.dart';

void main() {
  group('SettlementEngine - Pure Dart Settlement Suggestion Algorithm', () {
    final now = DateTime.now();

    final personA = Person(
      id: 'user_a',
      name: 'Alice',
      isSelf: true,
      createdAt: now,
      updatedAt: now,
    );
    final personB = Person(
      id: 'user_b',
      name: 'Bob',
      isSelf: false,
      createdAt: now,
      updatedAt: now,
    );
    final personC = Person(
      id: 'user_c',
      name: 'Charlie',
      isSelf: false,
      createdAt: now,
      updatedAt: now,
    );
    final personD = Person(
      id: 'user_d',
      name: 'David',
      isSelf: false,
      createdAt: now,
      updatedAt: now,
    );

    final people = [personA, personB, personC, personD];

    test('returns empty suggestions when all net balances are zero', () {
      final netBalances = {
        'user_a': 0,
        'user_b': 0,
        'user_c': 0,
      };

      final suggestions = SettlementEngine.computeSuggestions(
        netBalances: netBalances,
        people: people,
      );

      expect(suggestions, isEmpty);
    });

    test('single debtor and creditor yields a single direct transfer', () {
      // Bob owes Alice ₹50 (5000 paise)
      // Alice is +5000, Bob is -5000
      final netBalances = {
        'user_a': 5000,
        'user_b': -5000,
      };

      final suggestions = SettlementEngine.computeSuggestions(
        netBalances: netBalances,
        people: people,
      );

      expect(suggestions.length, 1);
      expect(suggestions.first.fromPersonId, 'user_b');
      expect(suggestions.first.toPersonId, 'user_a');
      expect(suggestions.first.amountPaise, 5000);
    });

    test('multiple debtors and single creditor match deterministically', () {
      // Bob owes ₹30, Charlie owes ₹20, Alice is owed ₹50
      final netBalances = {
        'user_a': 5000,
        'user_b': -3000,
        'user_c': -2000,
      };

      final suggestions = SettlementEngine.computeSuggestions(
        netBalances: netBalances,
        people: people,
      );

      // Bob owes 3000 -> pays Alice 3000
      // Charlie owes 2000 -> pays Alice 2000
      expect(suggestions.length, 2);

      expect(suggestions[0].fromPersonId, 'user_b');
      expect(suggestions[0].toPersonId, 'user_a');
      expect(suggestions[0].amountPaise, 3000);

      expect(suggestions[1].fromPersonId, 'user_c');
      expect(suggestions[1].toPersonId, 'user_a');
      expect(suggestions[1].amountPaise, 2000);

      // Total transfers equal total credit
      final totalTransferred =
          suggestions.fold<int>(0, (prev, s) => prev + s.amountPaise);
      expect(totalTransferred, 5000);
    });

    test('multiple debtors and multiple creditors reconcile all balances to zero', () {
      // Alice: -4000 (owes ₹40)
      // Bob:   -6000 (owes ₹60)
      // Charlie: +7000 (owed ₹70)
      // David:   +3000 (owed ₹30)
      // Sum = 0
      final netBalances = {
        'user_a': -4000,
        'user_b': -6000,
        'user_c': 7000,
        'user_d': 3000,
      };

      final suggestions = SettlementEngine.computeSuggestions(
        netBalances: netBalances,
        people: people,
      );

      expect(suggestions, isNotEmpty);

      // Verify every transfer:
      // 1. Is positive
      // 2. Is from a debtor to a creditor
      // 3. Simulating the transfers clears all balances to zero
      final simulatedBalances = Map<String, int>.from(netBalances);

      for (final s in suggestions) {
        expect(s.amountPaise, greaterThan(0));
        // fromPerson had negative balance before transfer
        expect(netBalances[s.fromPersonId], lessThan(0));
        // toPerson had positive balance before transfer
        expect(netBalances[s.toPersonId], greaterThan(0));

        // Apply transfer: fromPerson pays (+), toPerson receives (-)
        simulatedBalances[s.fromPersonId] =
            simulatedBalances[s.fromPersonId]! + s.amountPaise;
        simulatedBalances[s.toPersonId] =
            simulatedBalances[s.toPersonId]! - s.amountPaise;
      }

      // After all transfers, every person's balance must be exactly 0
      for (final balance in simulatedBalances.values) {
        expect(balance, 0);
      }
    });

    test('suggestions do not mutate inputs or external state', () {
      final originalBalances = {
        'user_a': 10000,
        'user_b': -6000,
        'user_c': -4000,
      };
      final inputCopy = Map<String, int>.from(originalBalances);

      final suggestions1 = SettlementEngine.computeSuggestions(
        netBalances: inputCopy,
        people: people,
      );

      // Input map is unchanged
      expect(inputCopy, equals(originalBalances));

      final suggestions2 = SettlementEngine.computeSuggestions(
        netBalances: inputCopy,
        people: people,
      );

      // Consecutive calls produce identical results (deterministic pure function)
      expect(suggestions1.length, suggestions2.length);
      for (int i = 0; i < suggestions1.length; i++) {
        expect(suggestions1[i].fromPersonId, suggestions2[i].fromPersonId);
        expect(suggestions1[i].toPersonId, suggestions2[i].toPersonId);
        expect(suggestions1[i].amountPaise, suggestions2[i].amountPaise);
      }
    });
  });
}
