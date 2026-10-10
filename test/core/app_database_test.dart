import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/app_database.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('AppDatabase Foundation & Schema', () {
    late AppDatabase appDb;

    setUp(() async {
      appDb = await AppDatabase.inMemory(databaseFactory: databaseFactoryFfi);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('initializes schema and seeds default self user (You)', () async {
      final db = appDb.database;
      final people = await db.query('people');

      expect(people.length, 1);
      expect(people.first['id'], DatabaseMigrations.defaultSelfUserId);
      expect(people.first['name'], 'You');
      expect(people.first['is_self'], 1);
      expect(people.first['is_archived'], 0);
    });

    test('enforces single self-profile uniqueness constraint', () async {
      final db = appDb.database;
      final now = DateTime.now().toIso8601String();

      expect(
        () async => await db.insert('people', {
          'id': 'second-self-user',
          'name': 'Duplicate Blessy',
          'is_self': 1,
          'is_archived': 0,
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('enforces foreign key constraints', () async {
      final db = appDb.database;
      final now = DateTime.now().toIso8601String();

      // Attempt inserting debt referencing non-existent person
      expect(
        () async => await db.insert('manual_debts', {
          'id': 'debt-1',
          'debtor_id': DatabaseMigrations.defaultSelfUserId,
          'creditor_id': 'non-existent-friend-id',
          'amount_paise': 2000,
          'debt_date': now,
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('enforces debtor <> creditor constraint on manual_debts', () async {
      final db = appDb.database;
      final now = DateTime.now().toIso8601String();

      expect(
        () async => await db.insert('manual_debts', {
          'id': 'self-debt-1',
          'debtor_id': DatabaseMigrations.defaultSelfUserId,
          'creditor_id': DatabaseMigrations.defaultSelfUserId,
          'amount_paise': 5000,
          'debt_date': now,
          'created_at': now,
          'updated_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('enforces payer <> receiver constraint on settlements', () async {
      final db = appDb.database;
      final now = DateTime.now().toIso8601String();

      expect(
        () async => await db.insert('settlements', {
          'id': 'self-settle-1',
          'payer_id': DatabaseMigrations.defaultSelfUserId,
          'receiver_id': DatabaseMigrations.defaultSelfUserId,
          'amount_paise': 1000,
          'settlement_date': now,
          'created_at': now,
        }),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
