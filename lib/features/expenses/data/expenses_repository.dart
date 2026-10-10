import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../domain/expense.dart';

abstract class ExpensesRepository {
  Future<List<ExpenseWithShares>> getAllExpenses();
  Future<ExpenseWithShares?> getExpenseById(String id);
  Future<List<ExpenseWithShares>> getExpensesForPerson(String personId);
  Future<ExpenseWithShares> createExpense({
    required String title,
    required int totalPaise,
    required String payerId,
    required String splitType,
    required DateTime expenseDate,
    String? notes,
    required Map<String, int> shares,
  });
  Future<ExpenseWithShares> updateExpense({
    required String id,
    required String title,
    required int totalPaise,
    required String payerId,
    required String splitType,
    required DateTime expenseDate,
    String? notes,
    required Map<String, int> shares,
  });
  Future<void> deleteExpense(String id);
}

class SqliteExpensesRepository implements ExpensesRepository {
  final Database _db;
  final Uuid _uuid;

  SqliteExpensesRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  Future<void> _validateExpense({
    required String title,
    required int totalPaise,
    required String payerId,
    required Map<String, int> shares,
  }) async {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) {
      throw const ValidationException('Expense title cannot be empty');
    }
    if (totalPaise <= 0) {
      throw const ValidationException('Total amount must be greater than zero');
    }

    final payerCount = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM people WHERE id = ?',
      [payerId],
    )) ?? 0;
    if (payerCount == 0) {
      throw const ValidationException('Selected payer does not exist');
    }

    if (shares.isEmpty) {
      throw const ValidationException('At least one participant must be selected');
    }

    int sumShares = 0;
    for (final entry in shares.entries) {
      if (entry.value < 0) {
        throw const ValidationException('Participant share cannot be negative');
      }
      sumShares += entry.value;

      final count = Sqflite.firstIntValue(await _db.rawQuery(
        'SELECT COUNT(*) FROM people WHERE id = ?',
        [entry.key],
      )) ?? 0;
      if (count == 0) {
        throw ValidationException('Participant ${entry.key} does not exist');
      }
    }

    if (sumShares != totalPaise) {
      final diff = (totalPaise - sumShares).abs();
      final diffFormatted = (diff / 100).toStringAsFixed(2);
      if (sumShares < totalPaise) {
        throw ValidationException(
          'Total of shares is less than bill amount by ₹$diffFormatted',
        );
      } else {
        throw ValidationException(
          'Total of shares exceeds bill amount by ₹$diffFormatted',
        );
      }
    }
  }

  Future<List<ExpenseShare>> _getSharesForExpense(
    DatabaseExecutor executor,
    String expenseId,
  ) async {
    final rows = await executor.query(
      'expense_shares',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
    return rows.map(ExpenseShare.fromMap).toList();
  }

  @override
  Future<List<ExpenseWithShares>> getAllExpenses() async {
    final expenseRows = await _db.query(
      'expenses',
      orderBy: 'expense_date DESC, created_at DESC',
    );

    final results = <ExpenseWithShares>[];
    for (final row in expenseRows) {
      final expense = Expense.fromMap(row);
      final shares = await _getSharesForExpense(_db, expense.id);
      results.add(ExpenseWithShares(expense: expense, shares: shares));
    }
    return results;
  }

  @override
  Future<ExpenseWithShares?> getExpenseById(String id) async {
    final rows = await _db.query(
      'expenses',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final expense = Expense.fromMap(rows.first);
    final shares = await _getSharesForExpense(_db, expense.id);
    return ExpenseWithShares(expense: expense, shares: shares);
  }

  @override
  Future<List<ExpenseWithShares>> getExpensesForPerson(String personId) async {
    final rows = await _db.rawQuery('''
      SELECT DISTINCT e.* FROM expenses e
      LEFT JOIN expense_shares s ON e.id = s.expense_id
      WHERE e.payer_id = ? OR s.person_id = ?
      ORDER BY e.expense_date DESC, e.created_at DESC
    ''', [personId, personId]);

    final results = <ExpenseWithShares>[];
    for (final row in rows) {
      final expense = Expense.fromMap(row);
      final shares = await _getSharesForExpense(_db, expense.id);
      results.add(ExpenseWithShares(expense: expense, shares: shares));
    }
    return results;
  }

  @override
  Future<ExpenseWithShares> createExpense({
    required String title,
    required int totalPaise,
    required String payerId,
    required String splitType,
    required DateTime expenseDate,
    String? notes,
    required Map<String, int> shares,
  }) async {
    await _validateExpense(
      title: title,
      totalPaise: totalPaise,
      payerId: payerId,
      shares: shares,
    );

    final expenseId = _uuid.v4();
    final now = DateTime.now();

    final expense = Expense(
      id: expenseId,
      title: title.trim(),
      totalPaise: totalPaise,
      payerId: payerId,
      splitType: splitType,
      expenseDate: expenseDate,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final shareList = shares.entries.map((entry) {
      return ExpenseShare(
        expenseId: expenseId,
        personId: entry.key,
        sharePaise: entry.value,
      );
    }).toList();

    // Transactionally persist expense and its shares
    await _db.transaction((txn) async {
      await txn.insert('expenses', expense.toMap());
      for (final share in shareList) {
        await txn.insert('expense_shares', share.toMap());
      }
    });

    return ExpenseWithShares(expense: expense, shares: shareList);
  }

  @override
  Future<ExpenseWithShares> updateExpense({
    required String id,
    required String title,
    required int totalPaise,
    required String payerId,
    required String splitType,
    required DateTime expenseDate,
    String? notes,
    required Map<String, int> shares,
  }) async {
    await _validateExpense(
      title: title,
      totalPaise: totalPaise,
      payerId: payerId,
      shares: shares,
    );

    final existing = await getExpenseById(id);
    if (existing == null) {
      throw const NotFoundException('Expense record not found');
    }

    final now = DateTime.now();
    final updated = existing.expense.copyWith(
      title: title.trim(),
      totalPaise: totalPaise,
      payerId: payerId,
      splitType: splitType,
      expenseDate: expenseDate,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      updatedAt: now,
    );

    final newShares = shares.entries.map((entry) {
      return ExpenseShare(
        expenseId: id,
        personId: entry.key,
        sharePaise: entry.value,
      );
    }).toList();

    await _db.transaction((txn) async {
      await txn.update(
        'expenses',
        updated.toMap(),
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.delete(
        'expense_shares',
        where: 'expense_id = ?',
        whereArgs: [id],
      );
      for (final share in newShares) {
        await txn.insert('expense_shares', share.toMap());
      }
    });

    return ExpenseWithShares(expense: updated, shares: newShares);
  }

  @override
  Future<void> deleteExpense(String id) async {
    final existing = await getExpenseById(id);
    if (existing == null) {
      throw const NotFoundException('Expense record not found');
    }

    await _db.transaction((txn) async {
      await txn.delete('expenses', where: 'id = ?', whereArgs: [id]);
    });
  }
}
