import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/features/debts/data/debts_repository.dart';
import 'package:splitmate/features/debts/domain/manual_debt.dart';
import 'package:splitmate/features/debts/presentation/add_debt_screen.dart';
import 'package:splitmate/features/debts/providers/debts_providers.dart';
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
  }) async {
    final index = debts.indexWhere((d) => d.id == id);
    final updated = debts[index].copyWith(
      debtorId: debtorId,
      creditorId: creditorId,
      amountPaise: amountPaise,
      debtDate: debtDate,
      description: description,
      updatedAt: DateTime.now(),
    );
    debts[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteDebt(String id) async {
    debts.removeWhere((d) => d.id == id);
  }
}

void main() {
  group('AddDebtScreen Widget Tests', () {
    late FakePeopleRepo fakePeople;
    late FakeDebtsRepo fakeDebts;

    setUp(() {
      fakePeople = FakePeopleRepo();
      fakeDebts = FakeDebtsRepo();
    });

    Widget createTestWidget({
      String? prefilledDebtor,
      String? prefilledCreditor,
    }) {
      return ProviderScope(
        overrides: [
          peopleRepositoryProvider.overrideWithValue(fakePeople),
          debtsRepositoryProvider.overrideWithValue(fakeDebts),
        ],
        child: MaterialApp(
          home: AddDebtScreen(
            prefilledDebtorId: prefilledDebtor,
            prefilledCreditorId: prefilledCreditor,
          ),
        ),
      );
    }

    testWidgets('renders preview, input fields, and validates amount', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(
        prefilledDebtor: DatabaseMigrations.defaultSelfUserId,
        prefilledCreditor: 'friend-anu-id',
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Check header and preview
      expect(find.text('Add Debt'), findsOneWidget);
      expect(find.text('TRANSACTION PREVIEW'), findsOneWidget);
      expect(find.text('Record Debt'), findsOneWidget);

      // Enter amount 20
      final amountField = find.widgetWithText(TextFormField, '0.00');
      await tester.enterText(amountField, '20');
      await tester.pumpAndSettle();

      // Verify live preview updates to "You (Blessy) owes Anu ₹20"
      expect(find.text('You (Blessy) owes Anu ₹20'), findsOneWidget);

      // Tap Record Debt
      await tester.tap(find.widgetWithText(ElevatedButton, 'Record Debt'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      // Verify debt was created in repository
      expect(fakeDebts.debts.length, 1);
      final debt = fakeDebts.debts.first;
      expect(debt.amountPaise, 2000);
      expect(debt.debtorId, DatabaseMigrations.defaultSelfUserId);
      expect(debt.creditorId, 'friend-anu-id');
    });

    testWidgets('rejects invalid submission when debtor equals creditor', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(createTestWidget(
        prefilledDebtor: DatabaseMigrations.defaultSelfUserId,
        prefilledCreditor: DatabaseMigrations.defaultSelfUserId,
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      final amountField = find.widgetWithText(TextFormField, '0.00');
      await tester.enterText(amountField, '50');
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Record Debt'));
      await tester.pumpAndSettle();

      // Check error displayed
      expect(
        find.text('Debtor and creditor cannot be the same person'),
        findsWidgets,
      );
      expect(fakeDebts.debts.isEmpty, true);
    });
  });
}
