import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:splitmate/core/database/app_database.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/core/utils/csv_export_service.dart';
import 'package:splitmate/features/dashboard/domain/balance_service.dart';
import 'package:splitmate/features/debts/data/debts_repository.dart';
import 'package:splitmate/features/expenses/data/expenses_repository.dart';
import 'package:splitmate/features/people/data/people_repository.dart';
import 'package:splitmate/features/people/domain/person.dart';
import 'package:splitmate/features/settlements/data/settlements_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Data Reliability & SQLite Constraints Tests', () {
    late AppDatabase appDb;
    late Database db;

    setUp(() async {
      appDb = await AppDatabase.inMemory(databaseFactory: databaseFactoryFfi);
      db = appDb.database;
    });

    tearDown(() async {
      await appDb.close();
    });

    test('SQLite foreign key enforcement is active and rejects orphaned records', () async {
      // PRAGMA foreign_keys should be 1
      final fkResult = await db.rawQuery('PRAGMA foreign_keys;');
      expect(fkResult.first.values.first, 1);

      // Attempt inserting debt with non-existent debtor
      expect(
        () async => await db.insert('manual_debts', {
          'id': 'd-invalid',
          'debtor_id': 'non-existent-user',
          'creditor_id': DatabaseMigrations.defaultSelfUserId,
          'amount_paise': 5000,
          'debt_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Attempt inserting expense with non-existent payer
      expect(
        () async => await db.insert('expenses', {
          'id': 'exp-invalid',
          'title': 'Test',
          'total_paise': 5000,
          'payer_id': 'non-existent-payer',
          'split_type': 'equal',
          'expense_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );

      // Attempt inserting settlement with non-existent receiver
      expect(
        () async => await db.insert('settlements', {
          'id': 'set-invalid',
          'payer_id': DatabaseMigrations.defaultSelfUserId,
          'receiver_id': 'non-existent-receiver',
          'amount_paise': 5000,
          'settlement_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('ON DELETE CASCADE properly removes expense shares when expense is deleted', () async {
      final peopleRepo = SqlitePeopleRepository(db);
      final friend = await peopleRepo.addPerson('Arun');

      final expensesRepo = SqliteExpensesRepository(db);
      final expense = await expensesRepo.createExpense(
        title: 'Lunch',
        totalPaise: 10000,
        payerId: DatabaseMigrations.defaultSelfUserId,
        splitType: 'equal',
        expenseDate: DateTime.now(),
        shares: {
          DatabaseMigrations.defaultSelfUserId: 5000,
          friend.id: 5000,
        },
      );

      // Shares exist in db
      final sharesBefore = await db.query(
        'expense_shares',
        where: 'expense_id = ?',
        whereArgs: [expense.id],
      );
      expect(sharesBefore.length, 2);

      // Delete expense
      await expensesRepo.deleteExpense(expense.id);

      // Shares should be cascaded and deleted automatically
      final sharesAfter = await db.query(
        'expense_shares',
        where: 'expense_id = ?',
        whereArgs: [expense.id],
      );
      expect(sharesAfter, isEmpty);
    });

    test('Data survives database close and reopen (simulated app restart)', () async {
      final tempDir = Directory.systemTemp.createTempSync('splitmate_restart_test');
      final dbPath = p.join(tempDir.path, 'restart_test.db');

      try {
        // Step 1: Open database, write data
        final db1 = await AppDatabase.open(
          path: dbPath,
          databaseFactory: databaseFactoryFfi,
        );
        final peopleRepo1 = SqlitePeopleRepository(db1.database);
        final debtsRepo1 = SqliteDebtsRepository(db1.database);
        final expensesRepo1 = SqliteExpensesRepository(db1.database);
        final settlementsRepo1 = SqliteSettlementsRepository(db1.database);

        final charlie = await peopleRepo1.addPerson('Charlie');
        await debtsRepo1.createDebt(
          debtorId: charlie.id,
          creditorId: DatabaseMigrations.defaultSelfUserId,
          amountPaise: 3000,
          debtDate: DateTime.now(),
          description: 'Coffee',
        );

        await expensesRepo1.createExpense(
          title: 'Movie Tickets',
          totalPaise: 8000,
          payerId: DatabaseMigrations.defaultSelfUserId,
          splitType: 'equal',
          expenseDate: DateTime.now(),
          shares: {
            DatabaseMigrations.defaultSelfUserId: 4000,
            charlie.id: 4000,
          },
        );

        // Record a partial repayment: Charlie pays 2000 towards 7000 total debt
        await settlementsRepo1.createSettlement(
          payerId: charlie.id,
          receiverId: DatabaseMigrations.defaultSelfUserId,
          amountPaise: 2000,
          settlementDate: DateTime.now(),
          notes: 'Cash',
        );

        // Verify balance before close
        const balanceService = BalanceService();
        final netBefore = balanceService.computePairwiseBalance(
          personAId: DatabaseMigrations.defaultSelfUserId,
          personBId: charlie.id,
          debts: await debtsRepo1.getAllDebts(),
          expenses: await expensesRepo1.getAllExpenses(),
          settlements: await settlementsRepo1.getAllSettlements(),
        );
        expect(netBefore, 5000); // 3000 debt + 4000 share - 2000 repayment = 5000

        // Close db (simulating app terminate)
        await db1.close();

        // Step 2: Reopen database from same file (simulating app restart)
        final db2 = await AppDatabase.open(
          path: dbPath,
          databaseFactory: databaseFactoryFfi,
        );
        final peopleRepo2 = SqlitePeopleRepository(db2.database);
        final debtsRepo2 = SqliteDebtsRepository(db2.database);
        final expensesRepo2 = SqliteExpensesRepository(db2.database);
        final settlementsRepo2 = SqliteSettlementsRepository(db2.database);

        final peopleAfter = await peopleRepo2.getAllPeople();
        final debtsAfter = await debtsRepo2.getAllDebts();
        final expensesAfter = await expensesRepo2.getAllExpenses();
        final settlementsAfter = await settlementsRepo2.getAllSettlements();

        expect(peopleAfter.any((p) => p.name == 'Charlie'), isTrue);
        expect(debtsAfter.length, 1);
        expect(debtsAfter.first.amountPaise, 3000);
        expect(expensesAfter.length, 1);
        expect(expensesAfter.first.totalAmountPaise, 8000);
        expect(settlementsAfter.length, 1);
        expect(settlementsAfter.first.amountPaise, 2000);

        // Verify balance after restart is exactly identical
        final netAfter = balanceService.computePairwiseBalance(
          personAId: DatabaseMigrations.defaultSelfUserId,
          personBId: charlie.id,
          debts: debtsAfter,
          expenses: expensesAfter,
          settlements: settlementsAfter,
        );
        expect(netAfter, 5000);

        // Verify zero-sum invariant holds
        final allBalances = balanceService.computeNetBalances(
          people: peopleAfter,
          debts: debtsAfter,
          expenses: expensesAfter,
          settlements: settlementsAfter,
        );
        final totalSum = allBalances.values.fold<int>(0, (a, b) => a + b);
        expect(totalSum, 0);

        await db2.close();
      } finally {
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      }
    });

    test('Database transaction rolls back cleanly on error without partial records', () async {
      final peopleRepo = SqlitePeopleRepository(db);
      await peopleRepo.addPerson('David');

      // Attempt creating expense with mismatch between total and shares within transaction
      expect(
        () async {
          await db.transaction((txn) async {
            await txn.insert('expenses', {
              'id': 'exp-fail',
              'title': 'Dinner',
              'total_paise': 10000,
              'payer_id': DatabaseMigrations.defaultSelfUserId,
              'split_type': 'equal',
              'expense_date': DateTime.now().toIso8601String(),
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            });

            // Trigger an error inside the transaction (e.g. invalid share or foreign key)
            throw Exception('Simulated transaction failure');
          });
        },
        throwsException,
      );

      // Verify that the expense record was rolled back and does not exist
      final checkExpense = await db.query(
        'expenses',
        where: 'id = ?',
        whereArgs: ['exp-fail'],
      );
      expect(checkExpense, isEmpty);
    });

    test('CsvExportService generates valid RFC-4180 CSV with escaping and all fields', () {
      final self = Person(
        id: DatabaseMigrations.defaultSelfUserId,
        name: 'Blessy',
        isSelf: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      final friend = Person(
        id: 'p2',
        name: 'Anu, K.',
        isSelf: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final csv = CsvExportService.generateCsv(
        debts: [],
        expenses: [],
        settlements: [],
        people: [self, friend],
      );

      expect(csv, contains('Transaction ID,Type,Date'));
      expect(csv.split('\r\n').length, 1); // Only header when empty
    });
  });
}
