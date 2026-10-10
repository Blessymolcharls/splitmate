import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/app_database.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/core/errors/app_exceptions.dart';
import 'package:splitmate/features/expenses/data/expenses_repository.dart';
import 'package:splitmate/features/people/data/people_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SqliteExpensesRepository Tests', () {
    late AppDatabase appDb;
    late SqlitePeopleRepository peopleRepo;
    late SqliteExpensesRepository expensesRepo;

    setUp(() async {
      appDb = await AppDatabase.inMemory(databaseFactory: databaseFactoryFfi);
      peopleRepo = SqlitePeopleRepository(appDb.database);
      expensesRepo = SqliteExpensesRepository(appDb.database);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('Persists expense and expense_shares in a single SQLite transaction', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final friend = await peopleRepo.addPerson('Anu');

      final expenseWithShares = await expensesRepo.createExpense(
        title: 'Lunch',
        totalPaise: 50000, // ₹500
        payerId: selfId,
        splitType: 'equal',
        expenseDate: DateTime(2026, 10, 10),
        notes: 'Great food',
        shares: {
          selfId: 25000,
          friend.id: 25000,
        },
      );

      expect(expenseWithShares.title, 'Lunch');
      expect(expenseWithShares.totalPaise, 50000);
      expect(expenseWithShares.payerId, selfId);
      expect(expenseWithShares.notes, 'Great food');
      expect(expenseWithShares.shares.length, 2);

      // Verify directly from SQLite tables
      final expRows = await appDb.database.query(
        'expenses',
        where: 'id = ?',
        whereArgs: [expenseWithShares.id],
      );
      expect(expRows.length, 1);
      expect(expRows.first['total_paise'], 50000);

      final shareRows = await appDb.database.query(
        'expense_shares',
        where: 'expense_id = ?',
        whereArgs: [expenseWithShares.id],
      );
      expect(shareRows.length, 2);
    });

    test('Rejects invalid expenses (empty title, zero amount, non-existent payer, mismatch shares)', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final friend = await peopleRepo.addPerson('Anu');

      // Empty title
      expect(
        () => expensesRepo.createExpense(
          title: '   ',
          totalPaise: 1000,
          payerId: selfId,
          splitType: 'equal',
          expenseDate: DateTime.now(),
          shares: {selfId: 1000},
        ),
        throwsA(isA<ValidationException>()),
      );

      // Non-positive amount
      expect(
        () => expensesRepo.createExpense(
          title: 'Lunch',
          totalPaise: 0,
          payerId: selfId,
          splitType: 'equal',
          expenseDate: DateTime.now(),
          shares: {selfId: 0},
        ),
        throwsA(isA<ValidationException>()),
      );

      // Non-existent payer
      expect(
        () => expensesRepo.createExpense(
          title: 'Lunch',
          totalPaise: 1000,
          payerId: 'non_existent_id',
          splitType: 'equal',
          expenseDate: DateTime.now(),
          shares: {selfId: 1000},
        ),
        throwsA(isA<ValidationException>()),
      );

      // Share sum mismatch
      expect(
        () => expensesRepo.createExpense(
          title: 'Lunch',
          totalPaise: 2000,
          payerId: selfId,
          splitType: 'equal',
          expenseDate: DateTime.now(),
          shares: {selfId: 1500, friend.id: 1000}, // 2500 != 2000
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('Database failures roll back the expense and its shares together', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;

      // Initial row counts
      final initialExpCount = Sqflite.firstIntValue(
        await appDb.database.rawQuery('SELECT COUNT(*) FROM expenses'),
      )!;
      final initialShareCount = Sqflite.firstIntValue(
        await appDb.database.rawQuery('SELECT COUNT(*) FROM expense_shares'),
      )!;

      // Attempt creating an expense with an invalid participant ID that violates foreign key constraints
      try {
        await expensesRepo.createExpense(
          title: 'Coffee',
          totalPaise: 10000,
          payerId: selfId,
          splitType: 'equal',
          expenseDate: DateTime.now(),
          shares: {
            selfId: 5000,
            'invalid_foreign_key_person': 5000,
          },
        );
        fail('Should have thrown an exception');
      } catch (_) {
        // Expected exception
      }

      // Verify rollback: no orphaned expense or shares were committed
      final finalExpCount = Sqflite.firstIntValue(
        await appDb.database.rawQuery('SELECT COUNT(*) FROM expenses'),
      )!;
      final finalShareCount = Sqflite.firstIntValue(
        await appDb.database.rawQuery('SELECT COUNT(*) FROM expense_shares'),
      )!;

      expect(finalExpCount, initialExpCount);
      expect(finalShareCount, initialShareCount);
    });

    test('Updating an expense updates details and shares atomically', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final friend1 = await peopleRepo.addPerson('Anu');
      final friend2 = await peopleRepo.addPerson('Bob');

      // Create initial expense: 2 people
      final created = await expensesRepo.createExpense(
        title: 'Initial Title',
        totalPaise: 20000,
        payerId: selfId,
        splitType: 'equal',
        expenseDate: DateTime(2026, 10, 10),
        shares: {
          selfId: 10000,
          friend1.id: 10000,
        },
      );

      // Update to 3 people and new amount
      final updated = await expensesRepo.updateExpense(
        id: created.id,
        title: 'Updated Title',
        totalPaise: 30000,
        payerId: friend1.id,
        splitType: 'custom',
        expenseDate: DateTime(2026, 10, 11),
        notes: 'Updated notes',
        shares: {
          selfId: 10000,
          friend1.id: 10000,
          friend2.id: 10000,
        },
      );

      expect(updated.title, 'Updated Title');
      expect(updated.totalPaise, 30000);
      expect(updated.payerId, friend1.id);
      expect(updated.splitType, 'custom');
      expect(updated.notes, 'Updated notes');
      expect(updated.shares.length, 3);

      // Verify fetched by ID
      final fetched = await expensesRepo.getExpenseById(created.id);
      expect(fetched, isNotNull);
      expect(fetched!.title, 'Updated Title');
      expect(fetched.shares.length, 3);
    });

    test('Deleting an expense cascades and removes its shares', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final friend = await peopleRepo.addPerson('Anu');

      final created = await expensesRepo.createExpense(
        title: 'To Delete',
        totalPaise: 10000,
        payerId: selfId,
        splitType: 'equal',
        expenseDate: DateTime.now(),
        shares: {
          selfId: 5000,
          friend.id: 5000,
        },
      );

      // Verify exists
      var fetched = await expensesRepo.getExpenseById(created.id);
      expect(fetched, isNotNull);

      // Delete
      await expensesRepo.deleteExpense(created.id);

      // Verify removed
      fetched = await expensesRepo.getExpenseById(created.id);
      expect(fetched, isNull);

      final shareCount = Sqflite.firstIntValue(
        await appDb.database.rawQuery(
          'SELECT COUNT(*) FROM expense_shares WHERE expense_id = ?',
          [created.id],
        ),
      )!;
      expect(shareCount, 0);
    });

    test('getExpensesForPerson retrieves expenses where person is payer or participant', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final friend1 = await peopleRepo.addPerson('Anu');
      final friend2 = await peopleRepo.addPerson('Bob');

      // Expense 1: selfId pays, friend1 is participant
      await expensesRepo.createExpense(
        title: 'Dinner 1',
        totalPaise: 10000,
        payerId: selfId,
        splitType: 'equal',
        expenseDate: DateTime.now(),
        shares: {selfId: 5000, friend1.id: 5000},
      );

      // Expense 2: friend1 pays, friend2 is participant (self not involved)
      await expensesRepo.createExpense(
        title: 'Dinner 2',
        totalPaise: 8000,
        payerId: friend1.id,
        splitType: 'equal',
        expenseDate: DateTime.now(),
        shares: {friend1.id: 4000, friend2.id: 4000},
      );

      // Check friend1: involved in both
      final friend1Expenses = await expensesRepo.getExpensesForPerson(friend1.id);
      expect(friend1Expenses.length, 2);

      // Check self: involved in Dinner 1 only
      final selfExpenses = await expensesRepo.getExpensesForPerson(selfId);
      expect(selfExpenses.length, 1);
      expect(selfExpenses.first.title, 'Dinner 1');
    });
  });
}
