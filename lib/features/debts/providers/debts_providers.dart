import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/migrations.dart';
import '../../dashboard/domain/balance_service.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../../people/providers/people_providers.dart';
import '../../settlements/providers/settlements_providers.dart';
import '../data/debts_repository.dart';
import '../domain/manual_debt.dart';

final debtsRepositoryProvider = Provider<DebtsRepository>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  return SqliteDebtsRepository(appDb.database);
});

final balanceServiceProvider = Provider<BalanceService>((ref) {
  return const BalanceService();
});

class DebtsListNotifier extends AsyncNotifier<List<ManualDebt>> {
  @override
  Future<List<ManualDebt>> build() async {
    final repo = ref.watch(debtsRepositoryProvider);
    return repo.getAllDebts();
  }

  Future<ManualDebt> createDebt({
    required String debtorId,
    required String creditorId,
    required int amountPaise,
    required DateTime debtDate,
    String? description,
  }) async {
    final repo = ref.read(debtsRepositoryProvider);
    final debt = await repo.createDebt(
      debtorId: debtorId,
      creditorId: creditorId,
      amountPaise: amountPaise,
      debtDate: debtDate,
      description: description,
    );
    ref.invalidateSelf();
    await future;
    return debt;
  }

  Future<ManualDebt> updateDebt({
    required String id,
    required String debtorId,
    required String creditorId,
    required int amountPaise,
    required DateTime debtDate,
    String? description,
  }) async {
    final repo = ref.read(debtsRepositoryProvider);
    final debt = await repo.updateDebt(
      id: id,
      debtorId: debtorId,
      creditorId: creditorId,
      amountPaise: amountPaise,
      debtDate: debtDate,
      description: description,
    );
    ref.invalidateSelf();
    await future;
    return debt;
  }

  Future<void> deleteDebt(String id) async {
    final repo = ref.read(debtsRepositoryProvider);
    await repo.deleteDebt(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> deleteAllDebts() async {
    final repo = ref.read(debtsRepositoryProvider);
    await repo.deleteAllDebts();
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final debtsListProvider =
    AsyncNotifierProvider<DebtsListNotifier, List<ManualDebt>>(
  DebtsListNotifier.new,
);

final dashboardSummaryProvider = Provider<AsyncValue<DashboardSummary>>((ref) {
  final peopleAsync = ref.watch(peopleListProvider);
  final debtsAsync = ref.watch(debtsListProvider);
  final expensesAsync = ref.watch(expensesListProvider);
  final settlementsAsync = ref.watch(settlementsListProvider);
  final balanceService = ref.watch(balanceServiceProvider);

  if (peopleAsync.isLoading ||
      debtsAsync.isLoading ||
      expensesAsync.isLoading ||
      settlementsAsync.isLoading) {
    return const AsyncLoading();
  }

  if (peopleAsync.hasError) {
    return AsyncError(peopleAsync.error!, peopleAsync.stackTrace!);
  }
  if (debtsAsync.hasError) {
    return AsyncError(debtsAsync.error!, debtsAsync.stackTrace!);
  }
  if (expensesAsync.hasError) {
    return AsyncError(expensesAsync.error!, expensesAsync.stackTrace!);
  }
  if (settlementsAsync.hasError) {
    return AsyncError(settlementsAsync.error!, settlementsAsync.stackTrace!);
  }

  final people = peopleAsync.asData?.value ?? [];
  final debts = debtsAsync.asData?.value ?? [];
  final expenses = expensesAsync.asData?.value ?? [];
  final settlements = settlementsAsync.asData?.value ?? [];
  final self = ref.watch(selfPersonProvider);
  final selfId = self?.id ?? DatabaseMigrations.defaultSelfUserId;

  final summary = balanceService.computeDashboardSummary(
    selfId: selfId,
    people: people,
    debts: debts,
    expenses: expenses,
    settlements: settlements,
  );

  return AsyncData(summary);
});

final personDebtsProvider =
    Provider.family<AsyncValue<List<ManualDebt>>, String>((ref, personId) {
  final debtsAsync = ref.watch(debtsListProvider);
  return debtsAsync.whenData((debts) {
    return debts
        .where((d) => d.debtorId == personId || d.creditorId == personId)
        .toList();
  });
});

final personPairwiseBalanceProvider =
    Provider.family<AsyncValue<int>, String>((ref, personId) {
  final debtsAsync = ref.watch(debtsListProvider);
  final expensesAsync = ref.watch(expensesListProvider);
  final settlementsAsync = ref.watch(settlementsListProvider);
  final self = ref.watch(selfPersonProvider);
  final selfId = self?.id ?? DatabaseMigrations.defaultSelfUserId;
  final balanceService = ref.watch(balanceServiceProvider);

  if (debtsAsync.isLoading ||
      expensesAsync.isLoading ||
      settlementsAsync.isLoading) {
    return const AsyncLoading();
  }

  final debts = debtsAsync.asData?.value ?? [];
  final expenses = expensesAsync.asData?.value ?? [];
  final settlements = settlementsAsync.asData?.value ?? [];

  final balance = balanceService.computePairwiseBalance(
    personAId: selfId,
    personBId: personId,
    debts: debts,
    expenses: expenses,
    settlements: settlements,
  );

  return AsyncData(balance);
});
