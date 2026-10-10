import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../debts/providers/debts_providers.dart';
import '../../expenses/providers/expenses_providers.dart';
import '../../people/providers/people_providers.dart';
import '../data/settlements_repository.dart';
import '../domain/settlement.dart';

final settlementsRepositoryProvider = Provider<SettlementsRepository>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  return SqliteSettlementsRepository(appDb.database);
});

final settlementsListProvider =
    AsyncNotifierProvider<SettlementsListNotifier, List<Settlement>>(
  SettlementsListNotifier.new,
);

class SettlementsListNotifier extends AsyncNotifier<List<Settlement>> {
  @override
  Future<List<Settlement>> build() async {
    final repo = ref.watch(settlementsRepositoryProvider);
    return repo.getAllSettlements();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(settlementsRepositoryProvider);
      return repo.getAllSettlements();
    });
  }

  Future<Settlement> recordSettlement({
    required String payerId,
    required String receiverId,
    required int amountPaise,
    required DateTime settlementDate,
    String? notes,
  }) async {
    final repo = ref.read(settlementsRepositoryProvider);
    final settlement = await repo.createSettlement(
      payerId: payerId,
      receiverId: receiverId,
      amountPaise: amountPaise,
      settlementDate: settlementDate,
      notes: notes,
    );
    await refresh();
    return settlement;
  }

  Future<void> deleteSettlement(String id) async {
    final repo = ref.read(settlementsRepositoryProvider);
    await repo.deleteSettlement(id);
    await refresh();
  }

  Future<void> deleteAllSettlements() async {
    final repo = ref.read(settlementsRepositoryProvider);
    await repo.deleteAllSettlements();
    await refresh();
  }
}

/// Provider of pure Dart calculated settlement suggestions based on the current ledger balances.
final settlementSuggestionsProvider =
    Provider<List<SettlementSuggestion>>((ref) {
  final peopleAsync = ref.watch(peopleListProvider);
  final debtsAsync = ref.watch(debtsListProvider);
  final expensesAsync = ref.watch(expensesListProvider);
  final settlementsAsync = ref.watch(settlementsListProvider);
  final balanceService = ref.watch(balanceServiceProvider);

  final people = peopleAsync.asData?.value ?? [];
  final debts = debtsAsync.asData?.value ?? [];
  final expenses = expensesAsync.asData?.value ?? [];
  final settlements = settlementsAsync.asData?.value ?? [];

  if (people.isEmpty) return const [];

  final netBalances = balanceService.computeNetBalances(
    people: people,
    debts: debts,
    expenses: expenses,
    settlements: settlements,
  );

  return SettlementEngine.computeSuggestions(
    netBalances: netBalances,
    people: people,
  );
});
