import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/errors/app_exceptions.dart';
import 'package:splitmate/features/dashboard/domain/balance_service.dart';
import 'package:splitmate/features/debts/domain/manual_debt.dart';
import 'package:splitmate/features/expenses/domain/expense.dart';
import 'package:splitmate/features/people/domain/person.dart';

void main() {
  group('Expense Splitting - Unit & Math Tests', () {
    test('₹900 shared equally by three participants yields ₹300 each (30000 paise each)', () {
      final participantIds = ['user_c', 'user_a', 'user_b'];
      const totalPaise = 90000; // ₹900.00

      final shares = ExpenseWithShares.computeEqualShares(
        totalPaise: totalPaise,
        participantIds: participantIds,
      );

      expect(shares.length, 3);
      expect(shares['user_a'], 30000);
      expect(shares['user_b'], 30000);
      expect(shares['user_c'], 30000);

      // Verify exact sum
      final sum = shares.values.fold<int>(0, (prev, val) => prev + val);
      expect(sum, totalPaise);
    });

    test('₹100 shared equally by three yields ₹33.34, ₹33.33, and ₹33.33 in deterministic order', () {
      // Regardless of insertion order, deterministic order (sorted IDs) is respected
      final participantIds = ['user_3', 'user_1', 'user_2'];
      const totalPaise = 10000; // ₹100.00

      final shares = ExpenseWithShares.computeEqualShares(
        totalPaise: totalPaise,
        participantIds: participantIds,
      );

      // Sorted order is user_1, user_2, user_3
      // 10000 ~/ 3 = 3333 paise (₹33.33)
      // 10000 % 3 = 1 remainder paise -> goes to first sorted user (user_1: 3334 paise = ₹33.34)
      expect(shares['user_1'], 3334);
      expect(shares['user_2'], 3333);
      expect(shares['user_3'], 3333);

      // Exact sum must equal 10000
      final sum = shares.values.fold<int>(0, (prev, val) => prev + val);
      expect(sum, totalPaise);
    });

    test('Custom shares that underallocate or overallocate are rejected', () {
      const totalPaise = 10000; // ₹100.00

      // Underallocation: 5000 + 4000 = 9000 != 10000
      expect(
        () => ExpenseWithShares.validateCustomShares(
          totalPaise: totalPaise,
          shares: {'p1': 5000, 'p2': 4000},
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('under-allocated'),
        )),
      );

      // Overallocation: 5000 + 6000 = 11000 != 10000
      expect(
        () => ExpenseWithShares.validateCustomShares(
          totalPaise: totalPaise,
          shares: {'p1': 5000, 'p2': 6000},
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('over-allocated'),
        )),
      );

      // Negative share
      expect(
        () => ExpenseWithShares.validateCustomShares(
          totalPaise: totalPaise,
          shares: {'p1': 12000, 'p2': -2000},
        ),
        throwsA(isA<ValidationException>()),
      );

      // Empty shares
      expect(
        () => ExpenseWithShares.validateCustomShares(
          totalPaise: totalPaise,
          shares: {},
        ),
        throwsA(isA<ValidationException>()),
      );

      // Exactly matches: 4000 + 6000 = 10000
      expect(
        () => ExpenseWithShares.validateCustomShares(
          totalPaise: totalPaise,
          shares: {'p1': 4000, 'p2': 6000},
        ),
        returnsNormally,
      );
    });

    test("A payer's full payment is credited and their own share is charged", () {
      final selfUser = Person(
        id: 'self_1',
        name: 'Blessy',
        isSelf: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final friendA = Person(
        id: 'friend_a',
        name: 'Anu',
        isSelf: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final friendB = Person(
        id: 'friend_b',
        name: 'Bob',
        isSelf: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final people = [selfUser, friendA, friendB];

      // Blessy (self) pays ₹900 (90000 paise), split equally among Blessy, Anu, Bob (30000 paise each)
      // Blessy's balance should be: +90000 (credit for paying) - 30000 (own share) = +60000 paise (+₹600)
      // Anu's balance should be: -30000 paise (-₹300)
      // Bob's balance should be: -30000 paise (-₹300)
      final expense = Expense(
        id: 'exp_1',
        title: 'Dinner',
        totalPaise: 90000,
        payerId: 'self_1',
        splitType: 'equal',
        expenseDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final shares = [
        const ExpenseShare(expenseId: 'exp_1', personId: 'self_1', sharePaise: 30000),
        const ExpenseShare(expenseId: 'exp_1', personId: 'friend_a', sharePaise: 30000),
        const ExpenseShare(expenseId: 'exp_1', personId: 'friend_b', sharePaise: 30000),
      ];
      final expenseWithShares = ExpenseWithShares(expense: expense, shares: shares);

      const balanceService = BalanceService();
      final balances = balanceService.computeNetBalances(
        people: people,
        debts: const [],
        expenses: [expenseWithShares],
      );

      expect(balances['self_1'], 60000);
      expect(balances['friend_a'], -30000);
      expect(balances['friend_b'], -30000);

      // Verify zero-sum invariant: sum of all participant balances remains exactly zero
      final netSum = balances.values.fold<int>(0, (prev, val) => prev + val);
      expect(netSum, 0);

      // Pairwise check: Anu owes Blessy 30000 paise
      final anuPairwise = balanceService.computePairwiseBalance(
        personAId: 'self_1',
        personBId: 'friend_a',
        debts: const [],
        expenses: [expenseWithShares],
      );
      expect(anuPairwise, 30000); // Blessy gets 30000 from Anu
    });

    test('The sum of all participant balances remains zero with both debts and expenses', () {
      final p1 = Person(
        id: 'p1',
        name: 'User 1',
        isSelf: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final p2 = Person(
        id: 'p2',
        name: 'User 2',
        isSelf: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final p3 = Person(
        id: 'p3',
        name: 'User 3',
        isSelf: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final people = [p1, p2, p3];

      // Debt: p2 owes p1 ₹50 (5000 paise)
      final debt = ManualDebt(
        id: 'd1',
        debtorId: 'p2',
        creditorId: 'p1',
        amountPaise: 5000,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Expense: p3 pays ₹100 (10000 paise), split 3334 (p1), 3333 (p2), 3333 (p3)
      final expense = Expense(
        id: 'e1',
        title: 'Snacks',
        totalPaise: 10000,
        payerId: 'p3',
        splitType: 'equal',
        expenseDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final shares = [
        const ExpenseShare(expenseId: 'e1', personId: 'p1', sharePaise: 3334),
        const ExpenseShare(expenseId: 'e1', personId: 'p2', sharePaise: 3333),
        const ExpenseShare(expenseId: 'e1', personId: 'p3', sharePaise: 3333),
      ];
      final expWithShares = ExpenseWithShares(expense: expense, shares: shares);

      const balanceService = BalanceService();
      final balances = balanceService.computeNetBalances(
        people: people,
        debts: [debt],
        expenses: [expWithShares],
      );

      // p1: +5000 (creditor in debt) - 3334 (share in expense) = +1666 paise
      // p2: -5000 (debtor in debt) - 3333 (share in expense) = -8333 paise
      // p3: +10000 (payer) - 3333 (own share) = +6667 paise
      expect(balances['p1'], 1666);
      expect(balances['p2'], -8333);
      expect(balances['p3'], 6667);

      // Zero-sum invariant: 1666 - 8333 + 6667 = 0
      final netSum = balances.values.fold<int>(0, (prev, val) => prev + val);
      expect(netSum, 0);
    });

    test('Editing/deleting an expense recalculates balances dynamically', () {
      final p1 = Person(
        id: 'p1',
        name: 'User 1',
        isSelf: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final p2 = Person(
        id: 'p2',
        name: 'User 2',
        isSelf: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final people = [p1, p2];

      // Initial expense: p1 pays ₹200 (20000 paise), split evenly 10000 each
      final exp1 = ExpenseWithShares(
        expense: Expense(
          id: 'e1',
          title: 'Movie',
          totalPaise: 20000,
          payerId: 'p1',
          splitType: 'equal',
          expenseDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        shares: const [
          ExpenseShare(expenseId: 'e1', personId: 'p1', sharePaise: 10000),
          ExpenseShare(expenseId: 'e1', personId: 'p2', sharePaise: 10000),
        ],
      );

      const balanceService = BalanceService();
      var balances = balanceService.computeNetBalances(
        people: people,
        debts: const [],
        expenses: [exp1],
      );
      expect(balances['p1'], 10000);
      expect(balances['p2'], -10000);

      // Edit expense: total changed to ₹400 (40000 paise), split evenly 20000 each
      final exp1Updated = ExpenseWithShares(
        expense: Expense(
          id: 'e1',
          title: 'Movie & Popcorn',
          totalPaise: 40000,
          payerId: 'p1',
          splitType: 'equal',
          expenseDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        shares: const [
          ExpenseShare(expenseId: 'e1', personId: 'p1', sharePaise: 20000),
          ExpenseShare(expenseId: 'e1', personId: 'p2', sharePaise: 20000),
        ],
      );

      balances = balanceService.computeNetBalances(
        people: people,
        debts: const [],
        expenses: [exp1Updated],
      );
      expect(balances['p1'], 20000);
      expect(balances['p2'], -20000);

      // Delete expense: list is now empty
      balances = balanceService.computeNetBalances(
        people: people,
        debts: const [],
        expenses: const [],
      );
      expect(balances['p1'], 0);
      expect(balances['p2'], 0);
    });
  });
}
