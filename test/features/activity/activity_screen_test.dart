import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/features/activity/presentation/activity_screen.dart';
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
      name: 'Blessy',
      isSelf: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Person(
      id: 'friend-anu',
      name: 'Anu',
      isSelf: false,
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
  Future<void> deleteDebt(String id) async {
    debts.removeWhere((d) => d.id == id);
  }

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
  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
  }

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
  Future<void> deleteSettlement(String id) async {
    settlements.removeWhere((s) => s.id == id);
  }

  @override
  Future<void> deleteAllSettlements() async {
    settlements.clear();
  }
}

void main() {
  group('ActivityScreen Widget Tests', () {
    late _FakePeopleRepo fakePeople;
    late _FakeDebtsRepo fakeDebts;
    late _FakeExpensesRepo fakeExpenses;
    late _FakeSettlementsRepo fakeSettlements;

    setUp(() {
      fakePeople = _FakePeopleRepo();
      fakeDebts = _FakeDebtsRepo();
      fakeExpenses = _FakeExpensesRepo();
      fakeSettlements = _FakeSettlementsRepo();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          peopleRepositoryProvider.overrideWithValue(fakePeople),
          debtsRepositoryProvider.overrideWithValue(fakeDebts),
          expensesRepositoryProvider.overrideWithValue(fakeExpenses),
          settlementsRepositoryProvider.overrideWithValue(fakeSettlements),
        ],
        child: const MaterialApp(
          home: ActivityScreen(),
        ),
      );
    }

    testWidgets('renders activity items, type filter pills, and secondary filters', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed 1 debt and 1 settlement
      fakeDebts.debts.add(ManualDebt(
        id: 'd1',
        debtorId: 'friend-anu',
        creditorId: DatabaseMigrations.defaultSelfUserId,
        amountPaise: 2500,
        debtDate: DateTime.now(),
        description: 'Snacks',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      fakeSettlements.settlements.add(Settlement(
        id: 's1',
        payerId: 'friend-anu',
        receiverId: DatabaseMigrations.defaultSelfUserId,
        amountPaise: 1000,
        settlementDate: DateTime.now(),
        notes: 'UPI',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Activity'), findsOneWidget);
      expect(find.text('All Transactions'), findsOneWidget);
      expect(find.text('Direct Debts'), findsOneWidget);
      expect(find.text('Expenses'), findsOneWidget);
      expect(find.text('Repayments'), findsOneWidget);
      expect(find.byKey(const Key('activity_person_filter')), findsOneWidget);
      expect(find.byKey(const Key('activity_date_filter')), findsOneWidget);

      // Verify both items are rendered
      expect(find.textContaining('Anu owes You'), findsOneWidget);
      expect(find.textContaining('Anu repaid You'), findsOneWidget);

      // Tap "Direct Debts" filter pill
      await tester.tap(find.text('Direct Debts'));
      await tester.pumpAndSettle();

      // Only direct debt should be shown
      expect(find.textContaining('Anu owes You'), findsOneWidget);
      expect(find.textContaining('Anu repaid You'), findsNothing);

      // Tap "Repayments" filter pill
      await tester.tap(find.text('Repayments'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Anu owes You'), findsNothing);
      expect(find.textContaining('Anu repaid You'), findsOneWidget);
    });

    testWidgets('tapping settlement opens SettlementDetailSheet and deletes repayment', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      fakeSettlements.settlements.add(Settlement(
        id: 's1',
        payerId: 'friend-anu',
        receiverId: DatabaseMigrations.defaultSelfUserId,
        amountPaise: 1500,
        settlementDate: DateTime.now(),
        notes: 'Cash transfer',
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap settlement card
      await tester.tap(find.textContaining('Anu repaid You'));
      await tester.pumpAndSettle();

      // Verify SettlementDetailSheet appears
      expect(find.text('Repayment Details'), findsOneWidget);
      expect(find.text('₹15'), findsOneWidget);
      expect(find.byKey(const Key('delete_settlement_btn')), findsOneWidget);

      // Tap Delete Repayment button
      await tester.tap(find.byKey(const Key('delete_settlement_btn')));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Delete Repayment?'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);

      // Tap Delete in dialog
      await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
      await tester.pumpAndSettle();

      // Settlement is deleted
      expect(fakeSettlements.settlements, isEmpty);
    });

    testWidgets('export CSV button opens CSV preview and export sheet', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Export CSV icon
      await tester.tap(find.byKey(const Key('export_csv_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Export Transactions'), findsOneWidget);
      expect(find.byKey(const Key('save_pdf_file_btn')), findsOneWidget);
      expect(find.byKey(const Key('copy_csv_clipboard_btn')), findsOneWidget);
      expect(find.byKey(const Key('save_csv_file_btn')), findsOneWidget);
    });

    testWidgets('export PDF button opens export sheet with Save as PDF button', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tap Export PDF icon
      await tester.tap(find.byKey(const Key('export_pdf_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Export Transactions'), findsOneWidget);
      expect(find.byKey(const Key('save_pdf_file_btn')), findsOneWidget);

      // Tap Save as PDF
      await tester.tap(find.byKey(const Key('save_pdf_file_btn')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('delete history button clears all debts, expenses, and settlements with confirmation', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed items in fake repos
      fakeDebts.debts.add(ManualDebt(
        id: 'd1',
        debtorId: 'friend-anu',
        creditorId: DatabaseMigrations.defaultSelfUserId,
        amountPaise: 2500,
        debtDate: DateTime.now(),
        description: 'Snacks',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      fakeExpenses.expenses.add(ExpenseWithShares(
        expense: Expense(
          id: 'e1',
          title: 'Dinner',
          totalPaise: 3000,
          payerId: DatabaseMigrations.defaultSelfUserId,
          splitType: 'equal',
          expenseDate: DateTime.now(),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
        shares: [
          ExpenseShare(
            expenseId: 'e1',
            personId: 'friend-anu',
            sharePaise: 1500,
          ),
        ],
      ));
      fakeSettlements.settlements.add(Settlement(
        id: 'set1',
        payerId: 'friend-anu',
        receiverId: DatabaseMigrations.defaultSelfUserId,
        amountPaise: 1000,
        settlementDate: DateTime.now(),
        createdAt: DateTime.now(),
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Initially records exist
      expect(fakeDebts.debts, isNotEmpty);
      expect(fakeExpenses.expenses, isNotEmpty);
      expect(fakeSettlements.settlements, isNotEmpty);

      // Tap Delete History button in AppBar
      await tester.tap(find.byKey(const Key('delete_history_btn')));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear
      expect(find.text('Clear All History?'), findsOneWidget);
      expect(find.byKey(const Key('confirm_delete_history_btn')), findsOneWidget);

      // Tap Delete All
      await tester.tap(find.byKey(const Key('confirm_delete_history_btn')));
      await tester.pumpAndSettle();

      // All history is cleared
      expect(fakeDebts.debts, isEmpty);
      expect(fakeExpenses.expenses, isEmpty);
      expect(fakeSettlements.settlements, isEmpty);
    });
  });
}
