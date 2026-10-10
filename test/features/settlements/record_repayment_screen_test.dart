import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/migrations.dart';
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
import 'package:splitmate/features/settlements/presentation/record_repayment_screen.dart';
import 'package:splitmate/features/settlements/providers/settlements_providers.dart';

class FakePeopleRepo implements PeopleRepository {
  final List<Person> people = [
    Person(
      id: DatabaseMigrations.defaultSelfUserId,
      name: 'Blessy',
      isSelf: true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
    Person(
      id: 'friend-anu-id',
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

class FakeDebtsRepo implements DebtsRepository {
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
}

class FakeExpensesRepo implements ExpensesRepository {
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
}

class FakeSettlementsRepo implements SettlementsRepository {
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
  }) async {
    final s = Settlement(
      id: 'settlement-${settlements.length + 1}',
      payerId: payerId,
      receiverId: receiverId,
      amountPaise: amountPaise,
      settlementDate: settlementDate,
      notes: notes,
      createdAt: DateTime.now(),
    );
    settlements.add(s);
    return s;
  }

  @override
  Future<void> deleteSettlement(String id) async {
    settlements.removeWhere((s) => s.id == id);
  }
}

void main() {
  group('RecordRepaymentScreen Widget Tests', () {
    late FakePeopleRepo fakePeople;
    late FakeDebtsRepo fakeDebts;
    late FakeExpensesRepo fakeExpenses;
    late FakeSettlementsRepo fakeSettlements;

    setUp(() {
      fakePeople = FakePeopleRepo();
      fakeDebts = FakeDebtsRepo();
      fakeExpenses = FakeExpensesRepo();
      fakeSettlements = FakeSettlementsRepo();
    });

    Widget createTestWidget({
      String? prefilledDebtorId,
      String? prefilledCreditorId,
      int? prefilledAmountPaise,
    }) {
      return ProviderScope(
        overrides: [
          peopleRepositoryProvider.overrideWithValue(fakePeople),
          debtsRepositoryProvider.overrideWithValue(fakeDebts),
          expensesRepositoryProvider.overrideWithValue(fakeExpenses),
          settlementsRepositoryProvider.overrideWithValue(fakeSettlements),
        ],
        child: MaterialApp(
          home: RecordRepaymentScreen(
            prefilledDebtorId: prefilledDebtorId,
            prefilledCreditorId: prefilledCreditorId,
            prefilledAmountPaise: prefilledAmountPaise,
          ),
        ),
      );
    }

    testWidgets('renders screen and displays live outstanding obligation', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed a debt: Anu owes Blessy ₹50 (5000 paise)
      fakeDebts.debts.add(ManualDebt(
        id: 'd1',
        debtorId: 'friend-anu-id',
        creditorId: DatabaseMigrations.defaultSelfUserId,
        amountPaise: 5000,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await tester.pumpWidget(createTestWidget(
        prefilledDebtorId: 'friend-anu-id',
        prefilledCreditorId: DatabaseMigrations.defaultSelfUserId,
      ));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AppBar, 'Record Repayment'), findsOneWidget);
      expect(find.byKey(const Key('repayment_payer_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('repayment_receiver_dropdown')), findsOneWidget);
      expect(find.byKey(const Key('repayment_amount_input')), findsOneWidget);

      // Verify outstanding obligation card is displayed
      expect(find.textContaining('Anu owes You: ₹50'), findsOneWidget);
      expect(find.byKey(const Key('pay_full_amount_btn')), findsOneWidget);

      // Tap Pay Full button
      await tester.tap(find.byKey(const Key('pay_full_amount_btn')));
      await tester.pumpAndSettle();

      // Amount input should now have 50
      expect(find.text('50'), findsOneWidget);
      expect(find.text('✓ This will completely settle the debt!'), findsOneWidget);

      // Save button should be enabled
      final saveBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('save_repayment_button')),
      );
      expect(saveBtn.onPressed, isNotNull);
    });

    testWidgets('disables save button on overpayment', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Anu owes Blessy ₹20 (2000 paise)
      fakeDebts.debts.add(ManualDebt(
        id: 'd1',
        debtorId: 'friend-anu-id',
        creditorId: DatabaseMigrations.defaultSelfUserId,
        amountPaise: 2000,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await tester.pumpWidget(createTestWidget(
        prefilledDebtorId: 'friend-anu-id',
        prefilledCreditorId: DatabaseMigrations.defaultSelfUserId,
      ));
      await tester.pumpAndSettle();

      // Enter ₹30 (exceeds ₹20)
      await tester.enterText(
        find.byKey(const Key('repayment_amount_input')),
        '30',
      );
      await tester.pumpAndSettle();

      // Save button must be disabled
      final saveBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('save_repayment_button')),
      );
      expect(saveBtn.onPressed, isNull);
      expect(find.textContaining('Exceeds debt by ₹10.00'), findsOneWidget);
    });

    testWidgets('settlement suggestions panel applies suggestion to form', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Anu owes Blessy ₹75 (7500 paise)
      fakeDebts.debts.add(ManualDebt(
        id: 'd1',
        debtorId: 'friend-anu-id',
        creditorId: DatabaseMigrations.defaultSelfUserId,
        amountPaise: 7500,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Suggestions banner shows
      expect(find.textContaining('Suggested Settlements'), findsOneWidget);
      expect(find.text('Anu pays You'), findsOneWidget);
      expect(find.text('₹75'), findsOneWidget);

      // Tap Apply on suggestion
      await tester.tap(find.byKey(const Key('apply_suggestion_0')));
      await tester.pumpAndSettle();

      // Verify form is populated with ₹75
      expect(find.text('75'), findsOneWidget);

      // Save repayment
      await tester.tap(find.byKey(const Key('save_repayment_button')));
      await tester.pumpAndSettle();

      expect(fakeSettlements.settlements.length, 1);
      final s = fakeSettlements.settlements.first;
      expect(s.payerId, 'friend-anu-id');
      expect(s.receiverId, DatabaseMigrations.defaultSelfUserId);
      expect(s.amountPaise, 7500);
    });

    testWidgets('opening form leaves payer and receiver null with placeholders and neutral helper message', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Dropdown placeholders are shown
      expect(find.text('Select who is paying'), findsOneWidget);
      expect(find.text('Select who is receiving'), findsOneWidget);

      // Neutral helper message is shown before selection
      expect(
        find.text('Select both payer and receiver to calculate the outstanding balance and record a repayment.'),
        findsOneWidget,
      );

      // Save button is disabled
      final saveBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('save_repayment_button')),
      );
      expect(saveBtn.onPressed, isNull);

      // Swap button is inactive (onPressed == null)
      final swapBtn = tester.widget<IconButton>(
        find.byKey(const Key('swap_parties_btn')),
      );
      expect(swapBtn.onPressed, isNull);
    });

    testWidgets('swap button is inactive until both people selected, and swaps them correctly', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Select payer only
      await tester.tap(find.byKey(const Key('repayment_payer_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anu').last);
      await tester.pumpAndSettle();

      // Swap button still inactive because receiver is null
      var swapBtn = tester.widget<IconButton>(find.byKey(const Key('swap_parties_btn')));
      expect(swapBtn.onPressed, isNull);

      // Select receiver
      await tester.tap(find.byKey(const Key('repayment_receiver_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blessy (You)').last);
      await tester.pumpAndSettle();

      // Swap button is now active
      swapBtn = tester.widget<IconButton>(find.byKey(const Key('swap_parties_btn')));
      expect(swapBtn.onPressed, isNotNull);

      // Tap swap button
      await tester.tap(find.byKey(const Key('swap_parties_btn')));
      await tester.pumpAndSettle();

      // Now payer is Blessy and receiver is Anu
      expect(find.text('Blessy (You)'), findsOneWidget);
      expect(find.text('Anu'), findsOneWidget);
    });

    testWidgets('resetting the form restores placeholders and clears inputs', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Seed a debt: Anu owes Blessy ₹50
      fakeDebts.debts.add(ManualDebt(
        id: 'd1',
        debtorId: 'friend-anu-id',
        creditorId: DatabaseMigrations.defaultSelfUserId,
        amountPaise: 5000,
        debtDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Apply suggestion to populate form
      await tester.tap(find.byKey(const Key('apply_suggestion_0')));
      await tester.pumpAndSettle();

      expect(find.text('50'), findsOneWidget);
      expect(find.text('Select who is paying'), findsNothing);

      // Tap reset button in AppBar
      await tester.tap(find.byKey(const Key('reset_repayment_form_btn')));
      await tester.pumpAndSettle();

      // Placeholders restored
      expect(find.text('Select who is paying'), findsOneWidget);
      expect(find.text('Select who is receiving'), findsOneWidget);
      expect(find.text('50'), findsNothing);

      // Save button disabled
      final saveBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('save_repayment_button')),
      );
      expect(saveBtn.onPressed, isNull);
    });

    testWidgets('shows warning when debtor equals creditor and keeps save disabled', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Select Anu as payer
      await tester.tap(find.byKey(const Key('repayment_payer_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anu').last);
      await tester.pumpAndSettle();

      // Select Anu as receiver also
      await tester.tap(find.byKey(const Key('repayment_receiver_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anu').last);
      await tester.pumpAndSettle();

      // Warning displayed
      expect(find.text('Payer and receiver cannot be the same person.'), findsOneWidget);

      final saveBtn = tester.widget<ElevatedButton>(
        find.byKey(const Key('save_repayment_button')),
      );
      expect(saveBtn.onPressed, isNull);
    });
  });
}
