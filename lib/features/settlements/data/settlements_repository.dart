import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../../../core/utils/money_formatter.dart';
import '../../dashboard/domain/balance_service.dart';
import '../../debts/data/debts_repository.dart';
import '../../expenses/data/expenses_repository.dart';
import '../domain/settlement.dart';

abstract class SettlementsRepository {
  Future<List<Settlement>> getAllSettlements();
  Future<Settlement?> getSettlementById(String id);
  Future<List<Settlement>> getSettlementsForPerson(String personId);
  Future<Settlement> createSettlement({
    required String payerId,
    required String receiverId,
    required int amountPaise,
    required DateTime settlementDate,
    String? notes,
  });
  Future<void> deleteSettlement(String id);
  Future<void> deleteAllSettlements();
}

class SqliteSettlementsRepository implements SettlementsRepository {
  final Database _db;
  final Uuid _uuid;
  final BalanceService _balanceService;

  SqliteSettlementsRepository(
    this._db, {
    Uuid? uuid,
    BalanceService? balanceService,
  })  : _uuid = uuid ?? const Uuid(),
        _balanceService = balanceService ?? const BalanceService();

  @override
  Future<List<Settlement>> getAllSettlements() async {
    final rows = await _db.query(
      'settlements',
      orderBy: 'settlement_date DESC, created_at DESC',
    );
    return rows.map(Settlement.fromMap).toList();
  }

  @override
  Future<Settlement?> getSettlementById(String id) async {
    final rows = await _db.query(
      'settlements',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return Settlement.fromMap(rows.first);
  }

  @override
  Future<List<Settlement>> getSettlementsForPerson(String personId) async {
    final rows = await _db.query(
      'settlements',
      where: 'payer_id = ? OR receiver_id = ?',
      whereArgs: [personId, personId],
      orderBy: 'settlement_date DESC, created_at DESC',
    );
    return rows.map(Settlement.fromMap).toList();
  }

  @override
  Future<Settlement> createSettlement({
    required String payerId,
    required String receiverId,
    required int amountPaise,
    required DateTime settlementDate,
    String? notes,
  }) async {
    if (payerId.trim().isEmpty || receiverId.trim().isEmpty) {
      throw const ValidationException('Payer and receiver must be selected');
    }

    if (payerId == receiverId) {
      throw const ValidationException(
        'Payer and receiver cannot be the same person',
      );
    }

    if (amountPaise <= 0) {
      throw const ValidationException('Repayment amount must be greater than zero');
    }

    // Verify both people exist
    final payerCount = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM people WHERE id = ?',
      [payerId],
    )) ?? 0;
    if (payerCount == 0) {
      throw const ValidationException('Selected payer does not exist');
    }

    final receiverCount = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM people WHERE id = ?',
      [receiverId],
    )) ?? 0;
    if (receiverCount == 0) {
      throw const ValidationException('Selected receiver does not exist');
    }

    // Validate against current outstanding obligation from combined ledger
    // computePairwiseBalance(personAId: receiverId, personBId: payerId) returns how much payer owes receiver.
    final debtsRepo = SqliteDebtsRepository(_db);
    final expensesRepo = SqliteExpensesRepository(_db);

    final allDebts = await debtsRepo.getAllDebts();
    final allExpenses = await expensesRepo.getAllExpenses();
    final allSettlements = await getAllSettlements();

    final currentOutstandingDebt = _balanceService.computePairwiseBalance(
      personAId: receiverId,
      personBId: payerId,
      debts: allDebts,
      expenses: allExpenses,
      settlements: allSettlements,
    );

    if (currentOutstandingDebt <= 0) {
      throw const ValidationException(
        'Cannot record repayment: Payer does not owe any money to receiver. '
        'The current net balance is settled or in the opposite direction.',
      );
    }

    if (amountPaise > currentOutstandingDebt) {
      final formattedMax = MoneyFormatter.formatPaise(currentOutstandingDebt);
      throw ValidationException(
        'Repayment amount exceeds the current outstanding debt of $formattedMax. '
        'Repayments cannot overpay an outstanding obligation.',
      );
    }

    final now = DateTime.now();
    final settlement = Settlement(
      id: _uuid.v4(),
      payerId: payerId,
      receiverId: receiverId,
      amountPaise: amountPaise,
      settlementDate: settlementDate,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: now,
    );

    await _db.transaction((txn) async {
      await txn.insert('settlements', settlement.toMap());
    });

    return settlement;
  }

  @override
  Future<void> deleteSettlement(String id) async {
    await _db.delete('settlements', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<void> deleteAllSettlements() async {
    await _db.delete('settlements');
  }
}
