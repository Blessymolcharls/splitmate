import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/features/dashboard/presentation/dashboard_screen.dart';
import 'package:splitmate/features/debts/data/debts_repository.dart';
import 'package:splitmate/features/debts/domain/manual_debt.dart';
import 'package:splitmate/features/debts/providers/debts_providers.dart';
import 'package:splitmate/features/expenses/data/expenses_repository.dart';
import 'package:splitmate/features/expenses/domain/expense.dart';
import 'package:splitmate/features/expenses/providers/expenses_providers.dart';
import 'package:splitmate/features/people/data/people_repository.dart';
import 'package:splitmate/features/people/domain/person.dart';
import 'package:splitmate/features/people/providers/people_providers.dart';
import 'package:splitmate/features/settlements/data/settlements_repository.dart';
import 'package:splitmate/features/settlements/domain/settlement.dart';
import 'package:splitmate/features/settlements/providers/settlements_providers.dart';

class _FakePeopleRepo implements PeopleRepository {
  final List<Person> people = [
    Person(
      id: DatabaseMigrations.defaultSelfUserId,
      name: 'You',
      isSelf: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Person>> getAllPeople({bool includeArchived = false}) async =>
      List.from(people);

  @override
  Future<Person?> getPersonById(String id) async =>
      people.where((p) => p.id == id).firstOrNull;

  @override
  Future<Person?> findPersonByName(String name, {bool includeArchived = true}) async =>
      people.where((p) => p.name.toLowerCase() == name.trim().toLowerCase()).firstOrNull;

  @override
  Future<Person> getOrCreatePerson(String name) async =>
      (await findPersonByName(name)) ?? (await addPerson(name));

  @override
  Future<Person> getSelfPerson() async => people.first;

  @override
  Future<Person> addPerson(String name) async => throw UnimplementedError();

  @override
  Future<Person> updatePersonName(String id, String newName) async =>
      throw UnimplementedError();

  @override
  Future<void> archivePerson(String id) async => throw UnimplementedError();

  @override
  Future<void> unarchivePerson(String id) async => throw UnimplementedError();

  @override
  Future<bool> hasTransactionHistory(String personId) async => false;

  @override
  Future<void> deleteOrArchivePerson(String id) async =>
      throw UnimplementedError();
}

class _FakeDebtsRepo implements DebtsRepository {
  final List<ManualDebt> debts = [];

  @override
  Future<List<ManualDebt>> getAllDebts() async => List.from(debts);

  @override
  Future<ManualDebt?> getDebtById(String id) async =>
      debts.where((d) => d.id == id).firstOrNull;

  @override
  Future<List<ManualDebt>> getDebtsForPerson(String personId) async => [];

  @override
  Future<ManualDebt> createDebt({
    required String debtorId,
    required String creditorId,
    required int amountPaise,
    required DateTime debtDate,
    String? description,
  }) async =>
      throw UnimplementedError();

  @override
  Future<ManualDebt> updateDebt({
    required String id,
    required String debtorId,
    required String creditorId,
    required int amountPaise,
    required DateTime debtDate,
    String? description,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteDebt(String id) async {}

  @override
  Future<void> deleteAllDebts() async {
    debts.clear();
  }
}

class _FakeExpensesRepo implements ExpensesRepository {
  final List<ExpenseWithShares> expenses = [];

  @override
  Future<List<ExpenseWithShares>> getAllExpenses() async => List.from(expenses);

  @override
  Future<ExpenseWithShares?> getExpenseById(String id) async =>
      expenses.where((e) => e.id == id).firstOrNull;

  @override
  Future<List<ExpenseWithShares>> getExpensesForPerson(String personId) async => [];

  @override
  Future<ExpenseWithShares> createExpense({
    required String title,
    required int totalPaise,
    required String payerId,
    required String splitType,
    required DateTime expenseDate,
    String? notes,
    required Map<String, int> shares,
  }) async =>
      throw UnimplementedError();

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
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteExpense(String id) async {}

  @override
  Future<void> deleteAllExpenses() async {
    expenses.clear();
  }
}

class _FakeSettlementsRepo implements SettlementsRepository {
  final List<Settlement> settlements = [];

  @override
  Future<List<Settlement>> getAllSettlements() async => List.from(settlements);

  @override
  Future<Settlement?> getSettlementById(String id) async =>
      settlements.where((s) => s.id == id).firstOrNull;

  @override
  Future<List<Settlement>> getSettlementsForPerson(String personId) async => [];

  @override
  Future<Settlement> createSettlement({
    required String payerId,
    required String receiverId,
    required int amountPaise,
    required DateTime settlementDate,
    String? notes,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteSettlement(String id) async {}

  @override
  Future<void> deleteAllSettlements() async {
    settlements.clear();
  }
}

void main() {
  testWidgets('DashboardScreen renders net balance card and quick action buttons', (
    WidgetTester tester,
  ) async {
    final fakePeople = _FakePeopleRepo();
    final fakeDebts = _FakeDebtsRepo();
    final fakeExpenses = _FakeExpensesRepo();
    final fakeSettlements = _FakeSettlementsRepo();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          peopleRepositoryProvider.overrideWithValue(fakePeople),
          debtsRepositoryProvider.overrideWithValue(fakeDebts),
          expensesRepositoryProvider.overrideWithValue(fakeExpenses),
          settlementsRepositoryProvider.overrideWithValue(fakeSettlements),
        ],
        child: const MaterialApp(
          home: DashboardScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();

    // Verify app title and dashboard cards
    expect(find.text('SplitMate'), findsOneWidget);
    expect(find.text('Net Balance'), findsOneWidget);
    expect(find.text('You Get Back'), findsOneWidget);
    expect(find.text('You Owe'), findsOneWidget);
    expect(find.text('Add Debt'), findsWidgets);
    expect(find.text('Add Expense'), findsWidgets);
    expect(find.text('Repay'), findsOneWidget);
    expect(find.text('Recent Transactions'), findsOneWidget);
  });
}
