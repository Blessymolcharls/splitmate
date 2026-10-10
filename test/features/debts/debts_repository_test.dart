import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/app_database.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/core/errors/app_exceptions.dart';
import 'package:splitmate/features/debts/data/debts_repository.dart';
import 'package:splitmate/features/people/data/people_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SqliteDebtsRepository Tests', () {
    late AppDatabase appDb;
    late SqlitePeopleRepository peopleRepo;
    late SqliteDebtsRepository debtsRepo;

    setUp(() async {
      appDb = await AppDatabase.inMemory(databaseFactory: databaseFactoryFfi);
      peopleRepo = SqlitePeopleRepository(appDb.database);
      debtsRepo = SqliteDebtsRepository(appDb.database);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('rejects self-debt (same debtor and creditor)', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;

      expect(
        () => debtsRepo.createDebt(
          debtorId: selfId,
          creditorId: selfId,
          amountPaise: 2000,
          debtDate: DateTime.now(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects zero, negative, and invalid amounts', () async {
      final friend = await peopleRepo.addPerson('Anu');
      final selfId = DatabaseMigrations.defaultSelfUserId;

      expect(
        () => debtsRepo.createDebt(
          debtorId: selfId,
          creditorId: friend.id,
          amountPaise: 0,
          debtDate: DateTime.now(),
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => debtsRepo.createDebt(
          debtorId: selfId,
          creditorId: friend.id,
          amountPaise: -500,
          debtDate: DateTime.now(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('rejects non-existent debtor or creditor', () async {
      final selfId = DatabaseMigrations.defaultSelfUserId;

      expect(
        () => debtsRepo.createDebt(
          debtorId: 'ghost-person-id',
          creditorId: selfId,
          amountPaise: 1000,
          debtDate: DateTime.now(),
        ),
        throwsA(isA<ValidationException>()),
      );

      expect(
        () => debtsRepo.createDebt(
          debtorId: selfId,
          creditorId: 'ghost-person-id',
          amountPaise: 1000,
          debtDate: DateTime.now(),
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('creates and retrieves manual debts cleanly', () async {
      final anu = await peopleRepo.addPerson('Anu');
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final now = DateTime.now();

      final created = await debtsRepo.createDebt(
        debtorId: selfId,
        creditorId: anu.id,
        amountPaise: 2000,
        debtDate: now,
        description: 'Snacks',
      );

      expect(created.amountPaise, 2000);
      expect(created.debtorId, selfId);
      expect(created.creditorId, anu.id);
      expect(created.description, 'Snacks');

      final all = await debtsRepo.getAllDebts();
      expect(all.length, 1);
      expect(all.first.id, created.id);

      final personDebts = await debtsRepo.getDebtsForPerson(anu.id);
      expect(personDebts.length, 1);
      expect(personDebts.first.id, created.id);
    });

    test('editing a debt updates record and persists changes', () async {
      final anu = await peopleRepo.addPerson('Anu');
      final rahul = await peopleRepo.addPerson('Rahul');
      final selfId = DatabaseMigrations.defaultSelfUserId;
      final now = DateTime.now();

      final original = await debtsRepo.createDebt(
        debtorId: selfId,
        creditorId: anu.id,
        amountPaise: 2000,
        debtDate: now,
        description: 'Snacks',
      );

      // Edit debt to change amount and creditor
      final updated = await debtsRepo.updateDebt(
        id: original.id,
        debtorId: selfId,
        creditorId: rahul.id,
        amountPaise: 5000,
        debtDate: now,
        description: 'Dinner',
      );

      expect(updated.id, original.id);
      expect(updated.creditorId, rahul.id);
      expect(updated.amountPaise, 5000);
      expect(updated.description, 'Dinner');

      final fetched = await debtsRepo.getDebtById(original.id);
      expect(fetched?.creditorId, rahul.id);
      expect(fetched?.amountPaise, 5000);
      expect(fetched?.description, 'Dinner');
    });

    test('deleting a debt removes it cleanly from database', () async {
      final anu = await peopleRepo.addPerson('Anu');
      final selfId = DatabaseMigrations.defaultSelfUserId;

      final debt = await debtsRepo.createDebt(
        debtorId: selfId,
        creditorId: anu.id,
        amountPaise: 2000,
        debtDate: DateTime.now(),
      );

      await debtsRepo.deleteDebt(debt.id);

      final all = await debtsRepo.getAllDebts();
      expect(all.isEmpty, true);

      final fetched = await debtsRepo.getDebtById(debt.id);
      expect(fetched, isNull);
    });

    test('debt records survive database reopening', () async {
      final anu = await peopleRepo.addPerson('Anu');
      final selfId = DatabaseMigrations.defaultSelfUserId;

      final debt = await debtsRepo.createDebt(
        debtorId: anu.id,
        creditorId: selfId,
        amountPaise: 15000,
        debtDate: DateTime.now(),
        description: 'Movie',
      );

      // Reopen repository with the same underlying database
      final freshDebtsRepo = SqliteDebtsRepository(appDb.database);
      final retrieved = await freshDebtsRepo.getDebtById(debt.id);

      expect(retrieved, isNotNull);
      expect(retrieved!.amountPaise, 15000);
      expect(retrieved.debtorId, anu.id);
      expect(retrieved.creditorId, selfId);
      expect(retrieved.description, 'Movie');
    });
  });
}
