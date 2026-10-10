import 'package:sqflite/sqflite.dart';

class DatabaseMigrations {
  DatabaseMigrations._();

  static const int currentVersion = 1;
  static const String defaultSelfUserId = '00000000-0000-0000-0000-000000000001';
  static const String defaultSelfUserName = 'Blessy';

  static Future<void> onCreate(Database db, int version) async {
    final now = DateTime.now().toIso8601String();

    await db.execute('''
      CREATE TABLE people (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_self INTEGER NOT NULL DEFAULT 0,
        is_archived INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE UNIQUE INDEX idx_people_single_self ON people(is_self) WHERE is_self = 1;
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        total_paise INTEGER NOT NULL CHECK(total_paise > 0),
        payer_id TEXT NOT NULL REFERENCES people(id),
        split_type TEXT NOT NULL CHECK(split_type IN ('equal', 'custom')),
        expense_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_expenses_payer ON expenses(payer_id);
    ''');
    await db.execute('''
      CREATE INDEX idx_expenses_date ON expenses(expense_date);
    ''');

    await db.execute('''
      CREATE TABLE expense_shares (
        expense_id TEXT NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
        person_id TEXT NOT NULL REFERENCES people(id),
        share_paise INTEGER NOT NULL CHECK(share_paise >= 0),
        PRIMARY KEY(expense_id, person_id)
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_expense_shares_person ON expense_shares(person_id);
    ''');

    await db.execute('''
      CREATE TABLE manual_debts (
        id TEXT PRIMARY KEY,
        debtor_id TEXT NOT NULL REFERENCES people(id),
        creditor_id TEXT NOT NULL REFERENCES people(id),
        amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
        description TEXT,
        debt_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        CHECK(debtor_id <> creditor_id)
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_manual_debts_debtor ON manual_debts(debtor_id);
    ''');
    await db.execute('''
      CREATE INDEX idx_manual_debts_creditor ON manual_debts(creditor_id);
    ''');
    await db.execute('''
      CREATE INDEX idx_manual_debts_date ON manual_debts(debt_date);
    ''');

    await db.execute('''
      CREATE TABLE settlements (
        id TEXT PRIMARY KEY,
        payer_id TEXT NOT NULL REFERENCES people(id),
        receiver_id TEXT NOT NULL REFERENCES people(id),
        amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
        settlement_date TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        CHECK(payer_id <> receiver_id)
      );
    ''');

    await db.execute('''
      CREATE INDEX idx_settlements_payer ON settlements(payer_id);
    ''');
    await db.execute('''
      CREATE INDEX idx_settlements_receiver ON settlements(receiver_id);
    ''');
    await db.execute('''
      CREATE INDEX idx_settlements_date ON settlements(settlement_date);
    ''');

    // Seed default self profile (Blessy)
    await db.insert('people', {
      'id': defaultSelfUserId,
      'name': defaultSelfUserName,
      'is_self': 1,
      'is_archived': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  static Future<void> onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    // Migration logic for future versions (e.g. if v1 to v2)
  }
}
