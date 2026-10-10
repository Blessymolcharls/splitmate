import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:splitmate/core/database/app_database.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/core/errors/app_exceptions.dart';
import 'package:splitmate/features/dashboard/domain/balance_service.dart';
import 'package:splitmate/features/debts/data/debts_repository.dart';
import 'package:splitmate/features/debts/domain/manual_debt.dart';
import 'package:splitmate/features/debts/presentation/add_debt_screen.dart';
import 'package:splitmate/features/debts/providers/debts_providers.dart';
import 'package:splitmate/features/expenses/data/expenses_repository.dart';
import 'package:splitmate/features/expenses/domain/expense.dart';
import 'package:splitmate/features/expenses/presentation/add_expense_screen.dart';
import 'package:splitmate/features/expenses/providers/expenses_providers.dart';
import 'package:splitmate/features/people/data/people_repository.dart';
import 'package:splitmate/features/people/domain/person.dart';
import 'package:splitmate/features/people/presentation/widgets/add_edit_person_dialog.dart';
import 'package:splitmate/features/people/providers/people_providers.dart';
import 'package:splitmate/features/settlements/data/settlements_repository.dart';
import 'package:splitmate/features/settlements/domain/settlement.dart';
import 'package:splitmate/features/settlements/providers/settlements_providers.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class _InMemoryPeopleRepo implements PeopleRepository {
  final List<Person> people = [
    Person(
      id: DatabaseMigrations.defaultSelfUserId,
      name: 'Blessy',
      isSelf: true,
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Person>> getAllPeople({bool includeArchived = false}) async {
    final list = includeArchived
        ? people
        : people.where((p) => !p.isArchived).toList();
    list.sort((a, b) {
      if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.from(list);
  }

  @override
  Future<Person?> getPersonById(String id) async =>
      people.where((p) => p.id == id).firstOrNull;

  @override
  Future<Person?> findPersonByName(String name, {bool includeArchived = true}) async {
    final list = includeArchived
        ? people
        : people.where((p) => !p.isArchived).toList();
    return list
        .where((p) => p.name.trim().toLowerCase() == name.trim().toLowerCase())
        .firstOrNull;
  }

  @override
  Future<Person> getSelfPerson() async => people.firstWhere((p) => p.isSelf);

  @override
  Future<Person> addPerson(String name) async {
    final validName = SqlitePeopleRepository.validateName(name);
    final existing = await findPersonByName(validName);
    if (existing != null) return existing;
    final person = Person(
      id: 'person-${people.length + 1}',
      name: validName,
      isSelf: false,
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    people.add(person);
    return person;
  }

  @override
  Future<Person> getOrCreatePerson(String name) async =>
      (await findPersonByName(name)) ?? (await addPerson(name));

  @override
  Future<Person> updatePersonName(String id, String newName) async {
    final validName = SqlitePeopleRepository.validateName(newName);
    final index = people.indexWhere((p) => p.id == id);
    if (index == -1) throw const NotFoundException('Not found');
    final updated = people[index].copyWith(name: validName);
    people[index] = updated;
    return updated;
  }

  @override
  Future<void> archivePerson(String id) async {
    final index = people.indexWhere((p) => p.id == id);
    if (index != -1) people[index] = people[index].copyWith(isArchived: true);
  }

  @override
  Future<void> unarchivePerson(String id) async {
    final index = people.indexWhere((p) => p.id == id);
    if (index != -1) people[index] = people[index].copyWith(isArchived: false);
  }

  @override
  Future<bool> hasTransactionHistory(String personId) async => false;

  @override
  Future<void> deleteOrArchivePerson(String id) async {
    people.removeWhere((p) => p.id == id);
  }
}

class _InMemoryDebtsRepo implements DebtsRepository {
  final List<ManualDebt> debts = [];

  @override
  Future<List<ManualDebt>> getAllDebts() async => List.from(debts);

  @override
  Future<ManualDebt?> getDebtById(String id) async =>
      debts.where((d) => d.id == id).firstOrNull;

  @override
  Future<List<ManualDebt>> getDebtsForPerson(String personId) async =>
      debts.where((d) => d.debtorId == personId || d.creditorId == personId).toList();

  @override
  Future<ManualDebt> createDebt({
    required String debtorId,
    required String creditorId,
    required int amountPaise,
    required DateTime debtDate,
    String? description,
  }) async {
    final debt = ManualDebt(
      id: 'debt-${debts.length + 1}',
      debtorId: debtorId,
      creditorId: creditorId,
      amountPaise: amountPaise,
      debtDate: debtDate,
      description: description,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    debts.add(debt);
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
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteDebt(String id) async {
    debts.removeWhere((d) => d.id == id);
  }
}

class _InMemoryExpensesRepo implements ExpensesRepository {
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
  }) async {
    final exp = Expense(
      id: 'expense-${expenses.length + 1}',
      title: title,
      totalPaise: totalPaise,
      payerId: payerId,
      splitType: splitType,
      expenseDate: expenseDate,
      notes: notes,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final shareList = shares.entries
        .map((e) => ExpenseShare(
              expenseId: exp.id,
              personId: e.key,
              sharePaise: e.value,
            ))
        .toList();
    final expense = ExpenseWithShares(expense: exp, shares: shareList);
    expenses.add(expense);
    return expense;
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
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
  }
}

class _InMemorySettlementsRepo implements SettlementsRepository {
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
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Add People Directly in Debt and Expense Forms', () {
    late _InMemoryPeopleRepo peopleRepo;
    late _InMemoryDebtsRepo debtsRepo;
    late _InMemoryExpensesRepo expensesRepo;
    late _InMemorySettlementsRepo settlementsRepo;

    setUp(() {
      peopleRepo = _InMemoryPeopleRepo();
      debtsRepo = _InMemoryDebtsRepo();
      expensesRepo = _InMemoryExpensesRepo();
      settlementsRepo = _InMemorySettlementsRepo();
    });

    Widget createAddDebtApp() {
      return ProviderScope(
        overrides: [
          peopleRepositoryProvider.overrideWithValue(peopleRepo),
          debtsRepositoryProvider.overrideWithValue(debtsRepo),
        ],
        child: const MaterialApp(
          home: AddDebtScreen(),
        ),
      );
    }

    Widget createAddExpenseApp() {
      return ProviderScope(
        overrides: [
          peopleRepositoryProvider.overrideWithValue(peopleRepo),
          expensesRepositoryProvider.overrideWithValue(expensesRepo),
          debtsRepositoryProvider.overrideWithValue(debtsRepo),
          settlementsRepositoryProvider.overrideWithValue(settlementsRepo),
        ],
        child: const MaterialApp(
          home: AddExpenseScreen(),
        ),
      );
    }

    testWidgets('1. Adding a person from the Add Debt creditor selector', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAddDebtApp());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Add Debt'), findsOneWidget);
      expect(find.byKey(const Key('add_creditor_person_btn')), findsOneWidget);

      // Tap 'Add new person' under Creditor selector
      await tester.tap(find.byKey(const Key('add_creditor_person_btn')));
      await tester.pumpAndSettle();

      // Add Person Dialog appears
      expect(find.byType(AddEditPersonDialog), findsOneWidget);
      expect(find.byKey(const Key('person_name_input')), findsOneWidget);

      // Enter Anu and submit
      await tester.enterText(find.byKey(const Key('person_name_input')), 'Anu');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      // Person Anu created
      final anu = await peopleRepo.findPersonByName('Anu');
      expect(anu, isNotNull);

      // Preview updates to reflect Anu as creditor
      final amountField = find.widgetWithText(TextFormField, '0.00');
      await tester.enterText(amountField, '20');
      await tester.pumpAndSettle();

      expect(find.text('You (Blessy) owes Anu ₹20'), findsOneWidget);

      // Record debt
      await tester.tap(find.widgetWithText(ElevatedButton, 'Record Debt'));
      await tester.pumpAndSettle();

      final debts = await debtsRepo.getAllDebts();
      expect(debts.length, 1);
      expect(debts.first.debtorId, DatabaseMigrations.defaultSelfUserId);
      expect(debts.first.creditorId, anu!.id);
      expect(debts.first.amountPaise, 2000);
    });

    testWidgets('2. Adding a person from the Add Debt debtor selector', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAddDebtApp());
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap 'Add new person' under Debtor selector
      await tester.tap(find.byKey(const Key('add_debtor_person_btn')));
      await tester.pumpAndSettle();

      // Enter Rahul and submit
      await tester.enterText(find.byKey(const Key('person_name_input')), 'Rahul');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      final rahul = await peopleRepo.findPersonByName('Rahul');
      expect(rahul, isNotNull);

      // Select Blessy as creditor
      await tester.tap(find.byKey(const Key('creditor_dropdown')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blessy (You)').last);
      await tester.pumpAndSettle();

      // Preview shows Rahul owes You (Blessy)
      final amountField = find.byKey(const Key('debt_amount_input'));
      await tester.enterText(amountField, '50');
      await tester.pumpAndSettle();

      expect(find.text('Rahul owes You (Blessy) ₹50'), findsOneWidget);
    });

    testWidgets('3. Adding a participant directly from Add Expense', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAddExpenseApp());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_participant_btn')), findsOneWidget);

      // Tap Add Person in Participants section
      await tester.tap(find.byKey(const Key('add_participant_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('person_name_input')), 'Anu');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      final anu = await peopleRepo.findPersonByName('Anu');
      expect(anu, isNotNull);

      // Participant list includes Anu and is selected
      expect(find.text('Anu'), findsOneWidget);
      expect(find.text('PARTICIPANTS (2)'), findsOneWidget);
    });

    testWidgets('4 & 11. Adding multiple participants without losing entered expense details', (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAddExpenseApp());
      await tester.pump();
      await tester.pumpAndSettle();

      // 1. Enter expense title: Dinner
      final titleField = find.byKey(const Key('expense_title_input'));
      await tester.enterText(titleField, 'Dinner');
      await tester.pumpAndSettle();

      // 2. Enter total: 500
      final totalField = find.byKey(const Key('expense_amount_input'));
      await tester.enterText(totalField, '500');
      await tester.pumpAndSettle();

      // 3. Enter optional note
      final notesField = find.widgetWithText(TextFormField, 'Notes (optional)');
      await tester.enterText(notesField, 'Great evening food');
      await tester.pumpAndSettle();

      // 4. Open dialog and cancel: form details must be preserved
      await tester.tap(find.byKey(const Key('add_participant_btn')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('cancel_add_person_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('Great evening food'), findsOneWidget);

      // 5. Add participant 1: Anu
      await tester.tap(find.byKey(const Key('add_participant_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('person_name_input')), 'Anu');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('Great evening food'), findsOneWidget);

      // 6. Add participant 2: Rahul
      await tester.tap(find.byKey(const Key('add_participant_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('person_name_input')), 'Rahul');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      // Details still completely preserved
      expect(find.text('Dinner'), findsOneWidget);
      expect(find.text('500'), findsOneWidget);
      expect(find.text('Great evening food'), findsOneWidget);
      expect(find.text('PARTICIPANTS (3)'), findsOneWidget);
    });

    testWidgets('5. Newly created people appear in payer and participant selectors', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAddExpenseApp());
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('add_payer_btn')), findsOneWidget);
      await tester.tap(find.byKey(const Key('add_payer_btn')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const Key('person_name_input')), 'Kavya');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('payer_dropdown')), findsOneWidget);
      expect(find.text('Kavya'), findsWidgets);
    });

    test('6. Newly created people remain available after app restart (SQLite persistence)', () async {
      final tempDir = Directory.systemTemp.createTempSync('splitmate_restart_test');
      final dbPath = p.join(tempDir.path, 'restart_test.db');

      try {
        var sessionDb = await AppDatabase.open(path: dbPath, databaseFactory: databaseFactoryFfi);
        var sessionRepo = SqlitePeopleRepository(sessionDb.database);

        final newPerson = await sessionRepo.addPerson('Vikram');
        expect(newPerson.name, 'Vikram');
        await sessionDb.close();

        var reopenedDb = await AppDatabase.open(path: dbPath, databaseFactory: databaseFactoryFfi);
        var reopenedRepo = SqlitePeopleRepository(reopenedDb.database);

        final all = await reopenedRepo.getAllPeople();
        expect(all.any((p) => p.name == 'Vikram' && p.id == newPerson.id), isTrue);
        await reopenedDb.close();
      } finally {
        tempDir.deleteSync(recursive: true);
      }
    });

    testWidgets('7. Rejecting blank names', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAddDebtApp());
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_creditor_person_btn')));
      await tester.pumpAndSettle();

      // Submit with empty string
      await tester.enterText(find.byKey(const Key('person_name_input')), '');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a name'), findsOneWidget);

      // Submit with whitespace only
      await tester.enterText(find.byKey(const Key('person_name_input')), '   ');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a name'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.byKey(const Key('cancel_add_person_btn')));
      await tester.pumpAndSettle();
      expect(find.byType(AddEditPersonDialog), findsNothing);
    });

    testWidgets('8. Handling duplicate names', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final existingAnu = await peopleRepo.addPerson('Anu');

      await tester.pumpWidget(createAddDebtApp());
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('add_creditor_person_btn')));
      await tester.pumpAndSettle();

      // Enter duplicate name 'anu'
      await tester.enterText(find.byKey(const Key('person_name_input')), 'anu');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.textContaining('already exists'), findsOneWidget);
      expect(find.byKey(const Key('use_existing_person_btn')), findsOneWidget);

      // Tap 'Use existing contact: Anu'
      await tester.tap(find.byKey(const Key('use_existing_person_btn')));
      await tester.pumpAndSettle();

      final all = await peopleRepo.getAllPeople();
      expect(all.where((p) => p.name.toLowerCase() == 'anu').length, 1);
      expect(all.firstWhere((p) => p.name.toLowerCase() == 'anu').id, existingAnu.id);
    });

    testWidgets('9. Preventing a self-debt', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            peopleRepositoryProvider.overrideWithValue(peopleRepo),
            debtsRepositoryProvider.overrideWithValue(debtsRepo),
          ],
          child: const MaterialApp(
            home: AddDebtScreen(
              prefilledDebtorId: DatabaseMigrations.defaultSelfUserId,
              prefilledCreditorId: DatabaseMigrations.defaultSelfUserId,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final amountField = find.byKey(const Key('debt_amount_input'));
      await tester.enterText(amountField, '100');
      await tester.pumpAndSettle();

      expect(find.text('Debtor and creditor cannot be the same person'), findsWidgets);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Record Debt'));
      await tester.pumpAndSettle();

      final debts = await debtsRepo.getAllDebts();
      expect(debts.isEmpty, isTrue);
    });

    testWidgets('10. Correct equal and custom splitting after adding participants', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createAddExpenseApp());
      await tester.pump();
      await tester.pumpAndSettle();

      final titleField = find.byKey(const Key('expense_title_input'));
      await tester.enterText(titleField, 'Dinner');
      final totalField = find.byKey(const Key('expense_amount_input'));
      await tester.enterText(totalField, '500');
      await tester.pumpAndSettle();

      // Add Anu
      await tester.tap(find.byKey(const Key('add_participant_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('person_name_input')), 'Anu');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      // Add Rahul
      await tester.tap(find.byKey(const Key('add_participant_btn')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('person_name_input')), 'Rahul');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      // ₹500 split 3 ways: ₹166.67, ₹166.67, ₹166.66
      expect(find.text('₹166.67'), findsNWidgets(2));
      expect(find.text('₹166.66'), findsOneWidget);

      await tester.tap(find.byKey(const Key('save_expense_button')));
      await tester.pumpAndSettle();

      final expenses = await expensesRepo.getAllExpenses();
      expect(expenses.length, 1);
      final exp = expenses.first;
      expect(exp.totalPaise, 50000);
      expect(exp.shares.length, 3);
      final shareSum = exp.shares.fold<int>(0, (sum, s) => sum + s.sharePaise);
      expect(shareSum, 50000);
    });

    test('12. Preserving existing transactions and balances', () async {
      final appDb = await AppDatabase.inMemory(databaseFactory: databaseFactoryFfi);
      try {
        final peopleDbRepo = SqlitePeopleRepository(appDb.database);
        final debtsDbRepo = SqliteDebtsRepository(appDb.database);
        final expensesDbRepo = SqliteExpensesRepository(appDb.database);
        final settlementsDbRepo = SqliteSettlementsRepository(appDb.database);
        const balanceService = BalanceService();
        final selfId = DatabaseMigrations.defaultSelfUserId;

        // 1. Create a person Anu and a debt of ₹100
        final anu = await peopleDbRepo.addPerson('Anu');
        await debtsDbRepo.createDebt(
          debtorId: anu.id,
          creditorId: selfId,
          amountPaise: 10000,
          debtDate: DateTime.now(),
        );

        // Initial net balance: +₹100
        var people = await peopleDbRepo.getAllPeople();
        var debts = await debtsDbRepo.getAllDebts();
        var expenses = await expensesDbRepo.getAllExpenses();
        var settlements = await settlementsDbRepo.getAllSettlements();
        var summary = balanceService.computeDashboardSummary(
          selfId: selfId,
          people: people,
          debts: debts,
          expenses: expenses,
          settlements: settlements,
        );
        expect(summary.netBalancePaise, 10000);

        // 2. Add another person directly via shared people service
        final rahul = await peopleDbRepo.getOrCreatePerson('Rahul');
        expect(rahul.name, 'Rahul');

        // 3. Verify existing transactions and balances remain intact
        people = await peopleDbRepo.getAllPeople();
        debts = await debtsDbRepo.getAllDebts();
        expenses = await expensesDbRepo.getAllExpenses();
        settlements = await settlementsDbRepo.getAllSettlements();
        summary = balanceService.computeDashboardSummary(
          selfId: selfId,
          people: people,
          debts: debts,
          expenses: expenses,
          settlements: settlements,
        );
        expect(summary.netBalancePaise, 10000);
        expect(debts.length, 1);
        expect(debts.first.amountPaise, 10000);
      } finally {
        await appDb.close();
      }
    });
  });
}
