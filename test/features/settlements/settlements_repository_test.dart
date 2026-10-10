import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/app_database.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/core/errors/app_exceptions.dart';
import 'package:splitmate/features/dashboard/domain/balance_service.dart';
import 'package:splitmate/features/debts/data/debts_repository.dart';
import 'package:splitmate/features/expenses/data/expenses_repository.dart';
import 'package:splitmate/features/people/data/people_repository.dart';
import 'package:splitmate/features/settlements/data/settlements_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SqliteSettlementsRepository Tests', () {
    late AppDatabase appDb;
    late SqlitePeopleRepository peopleRepo;
    late SqliteDebtsRepository debtsRepo;
    late SqliteExpensesRepository expensesRepo;
    late SqliteSettlementsRepository settlementsRepo;
    const balanceService = BalanceService();

    setUp(() async {
      appDb = await AppDatabase.inMemory(databaseFactory: databaseFactoryFfi);
      peopleRepo = SqlitePeopleRepository(appDb.database);
      debtsRepo = SqliteDebtsRepository(appDb.database);
      expensesRepo = SqliteExpensesRepository(appDb.database);
      settlementsRepo = SqliteSettlementsRepository(appDb.database);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('Partial repayment reduces the outstanding debt correctly', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final friend = await peopleRepo.addPerson('Anu');

      // Anu owes Blessy ₹100 (10000 paise) via manual debt
      await debtsRepo.createDebt(
        debtorId: friend.id,
        creditorId: selfId,
        amountPaise: 10000,
        debtDate: DateTime(2026, 10, 10),
      );

      // Check balance before repayment: Anu owes Blessy 10000 paise
      var pairwise = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: friend.id,
        debts: await debtsRepo.getAllDebts(),
        expenses: await expensesRepo.getAllExpenses(),
        settlements: await settlementsRepo.getAllSettlements(),
      );
      expect(pairwise, 10000);

      // Anu partially repays ₹40 (4000 paise)
      final settlement = await settlementsRepo.createSettlement(
        payerId: friend.id,
        receiverId: selfId,
        amountPaise: 4000,
        settlementDate: DateTime(2026, 10, 11),
        notes: 'Partial repayment via UPI',
      );

      expect(settlement.amountPaise, 4000);
      expect(settlement.payerId, friend.id);
      expect(settlement.receiverId, selfId);

      // Check balance after repayment: Anu now owes Blessy ₹60 (6000 paise)
      pairwise = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: friend.id,
        debts: await debtsRepo.getAllDebts(),
        expenses: await expensesRepo.getAllExpenses(),
        settlements: await settlementsRepo.getAllSettlements(),
      );
      expect(pairwise, 6000);

      // Zero-sum invariant holds
      final people = await peopleRepo.getAllPeople();
      final netBalances = balanceService.computeNetBalances(
        people: people,
        debts: await debtsRepo.getAllDebts(),
        expenses: await expensesRepo.getAllExpenses(),
        settlements: await settlementsRepo.getAllSettlements(),
      );
      expect(balanceService.verifyZeroSumInvariant(netBalances), isTrue);

      // History is preserved: manual debt still exists in SQLite!
      final allDebts = await debtsRepo.getAllDebts();
      expect(allDebts.length, 1);
      expect(allDebts.first.amountPaise, 10000);
    });

    test('Full repayment clears the corresponding net obligation to zero', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final friend = await peopleRepo.addPerson('Bob');

      // Blessy pays for lunch ₹200 (20000 paise), split evenly 10000 each
      await expensesRepo.createExpense(
        title: 'Lunch',
        totalPaise: 20000,
        payerId: selfId,
        splitType: 'equal',
        expenseDate: DateTime(2026, 10, 10),
        shares: {selfId: 10000, friend.id: 10000},
      );

      // Bob owes Blessy ₹100 (10000 paise)
      var pairwise = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: friend.id,
        debts: await debtsRepo.getAllDebts(),
        expenses: await expensesRepo.getAllExpenses(),
        settlements: await settlementsRepo.getAllSettlements(),
      );
      expect(pairwise, 10000);

      // Bob makes full repayment of ₹100 (10000 paise)
      await settlementsRepo.createSettlement(
        payerId: friend.id,
        receiverId: selfId,
        amountPaise: 10000,
        settlementDate: DateTime(2026, 10, 11),
      );

      // Balance is now exactly zero (settled!)
      pairwise = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: friend.id,
        debts: await debtsRepo.getAllDebts(),
        expenses: await expensesRepo.getAllExpenses(),
        settlements: await settlementsRepo.getAllSettlements(),
      );
      expect(pairwise, 0);

      // Original expense still exists in SQLite!
      final allExpenses = await expensesRepo.getAllExpenses();
      expect(allExpenses.length, 1);
      expect(allExpenses.first.totalPaise, 20000);
    });

    test('Overpayment and wrong-direction repayment are rejected', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final friend = await peopleRepo.addPerson('Charlie');

      // Charlie owes Blessy ₹50 (5000 paise)
      await debtsRepo.createDebt(
        debtorId: friend.id,
        creditorId: selfId,
        amountPaise: 5000,
        debtDate: DateTime(2026, 10, 10),
      );

      // 1. Overpayment: Charlie attempts to repay ₹60 (6000 paise) when only ₹50 is owed
      expect(
        () => settlementsRepo.createSettlement(
          payerId: friend.id,
          receiverId: selfId,
          amountPaise: 6000,
          settlementDate: DateTime(2026, 10, 11),
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('exceeds the current outstanding debt'),
        )),
      );

      // 2. Wrong-direction repayment: Blessy attempts to repay Charlie, but Blessy owes Charlie nothing!
      expect(
        () => settlementsRepo.createSettlement(
          payerId: selfId,
          receiverId: friend.id,
          amountPaise: 2000,
          settlementDate: DateTime(2026, 10, 11),
        ),
        throwsA(isA<ValidationException>().having(
          (e) => e.message,
          'message',
          contains('Payer does not owe any money to receiver'),
        )),
      );

      // 3. Same person payment
      expect(
        () => settlementsRepo.createSettlement(
          payerId: selfId,
          receiverId: selfId,
          amountPaise: 1000,
          settlementDate: DateTime(2026, 10, 11),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Combined netting of multiple historical obligations is respected', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final friend = await peopleRepo.addPerson('David');

      // 1. Direct debt: David owes Blessy ₹100
      await debtsRepo.createDebt(
        debtorId: friend.id,
        creditorId: selfId,
        amountPaise: 10000,
        debtDate: DateTime(2026, 10, 1),
      );

      // 2. Direct debt: Blessy owes David ₹30
      await debtsRepo.createDebt(
        debtorId: selfId,
        creditorId: friend.id,
        amountPaise: 3000,
        debtDate: DateTime(2026, 10, 2),
      );

      // 3. Shared expense: David paid ₹40, split equally (Blessy share ₹20)
      await expensesRepo.createExpense(
        title: 'Coffee',
        totalPaise: 4000,
        payerId: friend.id,
        splitType: 'equal',
        expenseDate: DateTime(2026, 10, 3),
        shares: {selfId: 2000, friend.id: 2000},
      );

      // Current net balance:
      // David owes Blessy: +100 - 30 - 20 = +50 (5000 paise)
      var netDebt = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: friend.id,
        debts: await debtsRepo.getAllDebts(),
        expenses: await expensesRepo.getAllExpenses(),
        settlements: await settlementsRepo.getAllSettlements(),
      );
      expect(netDebt, 5000);

      // Attempting to repay ₹60 is rejected (exceeds net balance)
      expect(
        () => settlementsRepo.createSettlement(
          payerId: friend.id,
          receiverId: selfId,
          amountPaise: 6000,
          settlementDate: DateTime(2026, 10, 4),
        ),
        throwsA(isA<ValidationException>()),
      );

      // Repaying exactly ₹50 succeeds and clears the net obligation
      await settlementsRepo.createSettlement(
        payerId: friend.id,
        receiverId: selfId,
        amountPaise: 5000,
        settlementDate: DateTime(2026, 10, 4),
      );

      netDebt = balanceService.computePairwiseBalance(
        personAId: selfId,
        personBId: friend.id,
        debts: await debtsRepo.getAllDebts(),
        expenses: await expensesRepo.getAllExpenses(),
        settlements: await settlementsRepo.getAllSettlements(),
      );
      expect(netDebt, 0);
    });
  });
}
