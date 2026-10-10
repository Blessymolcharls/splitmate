import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../data/expenses_repository.dart';
import '../domain/expense.dart';

final expensesRepositoryProvider = Provider<ExpensesRepository>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  return SqliteExpensesRepository(appDb.database);
});

class ExpensesListNotifier extends AsyncNotifier<List<ExpenseWithShares>> {
  @override
  Future<List<ExpenseWithShares>> build() async {
    final repo = ref.watch(expensesRepositoryProvider);
    return repo.getAllExpenses();
  }

  Future<ExpenseWithShares> createExpense({
    required String title,
    required int totalPaise,
    required String payerId,
    required String splitType,
    required DateTime expenseDate,
    String? notes,
    required Map<String, int> shares,
  }) async {
    final repo = ref.read(expensesRepositoryProvider);
    final expense = await repo.createExpense(
      title: title,
      totalPaise: totalPaise,
      payerId: payerId,
      splitType: splitType,
      expenseDate: expenseDate,
      notes: notes,
      shares: shares,
    );
    ref.invalidateSelf();
    await future;
    return expense;
  }

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
    final repo = ref.read(expensesRepositoryProvider);
    final expense = await repo.updateExpense(
      id: id,
      title: title,
      totalPaise: totalPaise,
      payerId: payerId,
      splitType: splitType,
      expenseDate: expenseDate,
      notes: notes,
      shares: shares,
    );
    ref.invalidateSelf();
    await future;
    return expense;
  }

  Future<void> deleteExpense(String id) async {
    final repo = ref.read(expensesRepositoryProvider);
    await repo.deleteExpense(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteAllExpenses() async {
    final repo = ref.read(expensesRepositoryProvider);
    await repo.deleteAllExpenses();
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final expensesListProvider =
    AsyncNotifierProvider<ExpensesListNotifier, List<ExpenseWithShares>>(
  ExpensesListNotifier.new,
);

final personExpensesProvider =
    Provider.family<AsyncValue<List<ExpenseWithShares>>, String>(
        (ref, personId) {
  final expensesAsync = ref.watch(expensesListProvider);
  return expensesAsync.whenData((expenses) {
    return expenses.where((exp) {
      if (exp.payerId == personId) return true;
      return exp.shares.any((s) => s.personId == personId);
    }).toList();
  });
});
