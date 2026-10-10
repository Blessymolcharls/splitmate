import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/features/expenses/data/expenses_repository.dart';
import 'package:splitmate/features/expenses/domain/expense.dart';
import 'package:splitmate/features/expenses/presentation/add_expense_screen.dart';
import 'package:splitmate/features/expenses/providers/expenses_providers.dart';
import 'package:splitmate/features/people/data/people_repository.dart';
import 'package:splitmate/features/people/domain/person.dart';
import 'package:splitmate/features/people/providers/people_providers.dart';

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
    Person(
      id: 'friend-bob-id',
      name: 'Bob',
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

class FakeExpensesRepo implements ExpensesRepository {
  final List<ExpenseWithShares> expenses = [];

  @override
  Future<List<ExpenseWithShares>> getAllExpenses() async => List.from(expenses);

  @override
  Future<ExpenseWithShares?> getExpenseById(String id) async =>
      expenses.where((e) => e.id == id).firstOrNull;

  @override
  Future<List<ExpenseWithShares>> getExpensesForPerson(String personId) async =>
      expenses
          .where((e) =>
              e.payerId == personId ||
              e.shares.any((s) => s.personId == personId))
          .toList();

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
      id: 'exp-${expenses.length + 1}',
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
    final withShares = ExpenseWithShares(expense: exp, shares: shareList);
    expenses.add(withShares);
    return withShares;
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
    final index = expenses.indexWhere((e) => e.id == id);
    final exp = Expense(
      id: id,
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
    final withShares = ExpenseWithShares(expense: exp, shares: shareList);
    expenses[index] = withShares;
    return withShares;
  }

  @override
  Future<void> deleteExpense(String id) async {
    expenses.removeWhere((e) => e.id == id);
  }
}

void main() {
  group('AddExpenseScreen Widget Tests', () {
    late FakePeopleRepo fakePeople;
    late FakeExpensesRepo fakeExpenses;

    setUp(() {
      fakePeople = FakePeopleRepo();
      fakeExpenses = FakeExpensesRepo();
    });

    Widget createTestWidget({String? expenseId}) {
      return ProviderScope(
        overrides: [
          peopleRepositoryProvider.overrideWithValue(fakePeople),
          expensesRepositoryProvider.overrideWithValue(fakeExpenses),
        ],
        child: MaterialApp(
          home: AddExpenseScreen(expenseId: expenseId),
        ),
      );
    }

    testWidgets('renders all fields and defaults to equal split', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('Add Expense'), findsOneWidget);
      expect(find.text('Expense Title'), findsOneWidget);
      expect(find.text('Total Amount (₹)'), findsOneWidget);
      expect(find.text('Paid By'), findsOneWidget);
      expect(find.text('Equal Split'), findsOneWidget);
      expect(find.text('Custom Split'), findsOneWidget);
      expect(find.text('Save Expense'), findsOneWidget);

      // Verify save button is initially disabled (empty title and amount)
      final saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('save_expense_button')),
      );
      expect(saveButton.onPressed, isNull);
    });

    testWidgets('equal split calculates shares live and enables save when valid', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter Title
      await tester.enterText(
        find.byKey(const Key('expense_title_input')),
        'Team Dinner',
      );
      await tester.pumpAndSettle();

      // Enter Amount ₹900
      await tester.enterText(
        find.byKey(const Key('expense_amount_input')),
        '900',
      );
      await tester.pumpAndSettle();

      // All 3 participants are selected by default. 900 / 3 = 300 each (₹300)
      expect(find.text('₹300'), findsWidgets);

      // Save button should now be enabled
      final saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('save_expense_button')),
      );
      expect(saveButton.onPressed, isNotNull);

      // Tap save
      await tester.tap(find.byKey(const Key('save_expense_button')));
      await tester.pumpAndSettle();

      // Verify expense was persisted
      expect(fakeExpenses.expenses.length, 1);
      final saved = fakeExpenses.expenses.first;
      expect(saved.title, 'Team Dinner');
      expect(saved.totalPaise, 90000);
      expect(saved.splitType, 'equal');
      expect(saved.shares.length, 3);
      for (final share in saved.shares) {
        expect(share.sharePaise, 30000);
      }
    });

    testWidgets('custom split validates share sum equals total', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Enter Title and Amount ₹100
      await tester.enterText(
        find.byKey(const Key('expense_title_input')),
        'Snacks',
      );
      await tester.enterText(
        find.byKey(const Key('expense_amount_input')),
        '100',
      );
      await tester.pumpAndSettle();

      // Switch to Custom split tab
      await tester.tap(find.text('Custom Split'));
      await tester.pumpAndSettle();

      // Verify breakdown is displayed
      expect(find.textContaining('Allocated:'), findsOneWidget);

      // Deliberately modify shares to mismatch total (e.g. 50 + 20 + 20 = 90)
      await tester.enterText(
        find.byKey(Key('custom_share_input_${DatabaseMigrations.defaultSelfUserId}')),
        '50',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom_share_input_friend-anu-id')),
        '20',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom_share_input_friend-bob-id')),
        '20',
      );
      await tester.pumpAndSettle();

      // 90 != 100 -> Save should be disabled
      var saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('save_expense_button')),
      );
      expect(saveButton.onPressed, isNull);
      expect(find.text('Remaining: ₹10.00'), findsOneWidget);

      // Fix share to match exactly 100: 40 + 30 + 30 = 100
      await tester.enterText(
        find.byKey(Key('custom_share_input_${DatabaseMigrations.defaultSelfUserId}')),
        '40',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom_share_input_friend-anu-id')),
        '30',
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('custom_share_input_friend-bob-id')),
        '30',
      );
      await tester.pumpAndSettle();

      // Now exactly allocated
      expect(find.text('✓ Exactly Allocated'), findsOneWidget);

      // Save button should now be enabled
      saveButton = tester.widget<ElevatedButton>(
        find.byKey(const Key('save_expense_button')),
      );
      expect(saveButton.onPressed, isNotNull);

      // Tap save
      await tester.tap(find.byKey(const Key('save_expense_button')));
      await tester.pumpAndSettle();

      expect(fakeExpenses.expenses.length, 1);
      final saved = fakeExpenses.expenses.first;
      expect(saved.title, 'Snacks');
      expect(saved.totalPaise, 10000);
      expect(saved.splitType, 'custom');
      final sum = saved.shares.fold<int>(0, (prev, s) => prev + s.sharePaise);
      expect(sum, 10000);
    });
  });
}
