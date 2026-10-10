import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../domain/manual_debt.dart';

abstract class DebtsRepository {
  Future<List<ManualDebt>> getAllDebts();
  Future<ManualDebt?> getDebtById(String id);
  Future<List<ManualDebt>> getDebtsForPerson(String personId);
  Future<ManualDebt> createDebt({
    required String debtorId,
    required String creditorId,
    required int amountPaise,
    required DateTime debtDate,
    String? description,
  });
  Future<ManualDebt> updateDebt({
    required String id,
    required String debtorId,
    required String creditorId,
    required int amountPaise,
    required DateTime debtDate,
    String? description,
  });
  Future<void> deleteDebt(String id);
  Future<void> deleteAllDebts();
}

class SqliteDebtsRepository implements DebtsRepository {
  final Database _db;
  final Uuid _uuid;

  SqliteDebtsRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  Future<void> _validateParties(String debtorId, String creditorId) async {
    if (debtorId == creditorId) {
      throw const ValidationException(
        'Debtor and creditor cannot be the same person',
      );
    }

    final debtorCount = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM people WHERE id = ?',
      [debtorId],
    )) ?? 0;
    if (debtorCount == 0) {
      throw const ValidationException('Selected debtor does not exist');
    }

    final creditorCount = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM people WHERE id = ?',
      [creditorId],
    )) ?? 0;
    if (creditorCount == 0) {
      throw const ValidationException('Selected creditor does not exist');
    }
  }

  void _validateAmount(int amountPaise) {
    if (amountPaise <= 0) {
      throw const ValidationException('Amount must be positive');
    }
  }

  @override
  Future<List<ManualDebt>> getAllDebts() async {
    final rows = await _db.query(
      'manual_debts',
      orderBy: 'debt_date DESC, created_at DESC',
    );
    return rows.map(ManualDebt.fromMap).toList();
  }

  @override
  Future<ManualDebt?> getDebtById(String id) async {
    final rows = await _db.query(
      'manual_debts',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ManualDebt.fromMap(rows.first);
  }

  @override
  Future<List<ManualDebt>> getDebtsForPerson(String personId) async {
    final rows = await _db.query(
      'manual_debts',
      where: 'debtor_id = ? OR creditor_id = ?',
      whereArgs: [personId, personId],
      orderBy: 'debt_date DESC, created_at DESC',
    );
    return rows.map(ManualDebt.fromMap).toList();
  }

  @override
  Future<ManualDebt> createDebt({
    required String debtorId,
    required String creditorId,
    required int amountPaise,
    required DateTime debtDate,
    String? description,
  }) async {
    _validateAmount(amountPaise);
    await _validateParties(debtorId, creditorId);

    final now = DateTime.now();
    final debt = ManualDebt(
      id: _uuid.v4(),
      debtorId: debtorId,
      creditorId: creditorId,
      amountPaise: amountPaise,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      debtDate: debtDate,
      createdAt: now,
      updatedAt: now,
    );

    await _db.transaction((txn) async {
      await txn.insert('manual_debts', debt.toMap());
    });

    return debt;
  }

  @override
  Future<ManualDebt> updateDebt({
    required String id,
    required String debtorId,
    required String creditorId,
    required int amountPaise,
    required DateTime debtDate,
    String? description,
  }) async {
    _validateAmount(amountPaise);
    await _validateParties(debtorId, creditorId);

    final existing = await getDebtById(id);
    if (existing == null) {
      throw const NotFoundException('Debt record not found');
    }

    final now = DateTime.now();
    final updated = existing.copyWith(
      debtorId: debtorId,
      creditorId: creditorId,
      amountPaise: amountPaise,
      description: description?.trim().isEmpty == true ? null : description?.trim(),
      debtDate: debtDate,
      updatedAt: now,
    );

    await _db.transaction((txn) async {
      await txn.update(
        'manual_debts',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
    });

    return updated;
  }

  @override
  Future<void> deleteDebt(String id) async {
    final existing = await getDebtById(id);
    if (existing == null) {
      throw const NotFoundException('Debt record not found');
    }

    await _db.transaction((txn) async {
      await txn.delete('manual_debts', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> deleteAllDebts() async {
    await _db.transaction((txn) async {
      await txn.delete('manual_debts');
    });
  }
}
