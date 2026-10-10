import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/features/people/data/people_repository.dart';
import 'package:splitmate/features/people/domain/person.dart';
import 'package:splitmate/features/people/presentation/people_screen.dart';
import 'package:splitmate/features/people/presentation/widgets/add_edit_person_dialog.dart';
import 'package:splitmate/features/people/providers/people_providers.dart';

class FakePeopleRepository implements PeopleRepository {
  final List<Person> _people = [
    Person(
      id: DatabaseMigrations.defaultSelfUserId,
      name: DatabaseMigrations.defaultSelfUserName,
      isSelf: true,
      isArchived: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  ];

  @override
  Future<List<Person>> getAllPeople({bool includeArchived = false}) async {
    final list = includeArchived
        ? _people
        : _people.where((p) => !p.isArchived).toList();
    list.sort((a, b) {
      if (a.isSelf != b.isSelf) return a.isSelf ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return List.from(list);
  }

  @override
  Future<Person?> getPersonById(String id) async {
    return _people.where((p) => p.id == id).firstOrNull;
  }

  @override
  Future<Person?> findPersonByName(String name, {bool includeArchived = true}) async {
    final list = includeArchived
        ? _people
        : _people.where((p) => !p.isArchived).toList();
    return list
        .where((p) => p.name.toLowerCase() == name.trim().toLowerCase())
        .firstOrNull;
  }

  @override
  Future<Person> getOrCreatePerson(String name) async {
    final existing = await findPersonByName(name);
    if (existing != null) return existing;
    return addPerson(name);
  }

  @override
  Future<Person> getSelfPerson() async {
    return _people.firstWhere((p) => p.isSelf);
  }

  @override
  Future<Person> addPerson(String name) async {
    final validName = SqlitePeopleRepository.validateName(name);
    final now = DateTime.now();
    final person = Person(
      id: 'person-${_people.length + 1}',
      name: validName,
      isSelf: false,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );
    _people.add(person);
    return person;
  }

  @override
  Future<Person> updatePersonName(String id, String newName) async {
    final validName = SqlitePeopleRepository.validateName(newName);
    final index = _people.indexWhere((p) => p.id == id);
    if (index == -1) throw Exception('Not found');
    final updated = _people[index].copyWith(
      name: validName,
      updatedAt: DateTime.now(),
    );
    _people[index] = updated;
    return updated;
  }

  @override
  Future<void> archivePerson(String id) async {
    final index = _people.indexWhere((p) => p.id == id);
    if (index != -1) {
      _people[index] = _people[index].copyWith(
        isArchived: true,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<void> unarchivePerson(String id) async {
    final index = _people.indexWhere((p) => p.id == id);
    if (index != -1) {
      _people[index] = _people[index].copyWith(
        isArchived: false,
        updatedAt: DateTime.now(),
      );
    }
  }

  @override
  Future<bool> hasTransactionHistory(String personId) async {
    return false;
  }

  @override
  Future<void> deleteOrArchivePerson(String id) async {
    _people.removeWhere((p) => p.id == id);
  }
}

void main() {
  group('PeopleScreen Widget Tests', () {
    late FakePeopleRepository fakeRepo;

    setUp(() {
      fakeRepo = FakePeopleRepository();
    });

    Widget createTestWidget() {
      return ProviderScope(
        overrides: [
          peopleRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: const MaterialApp(
          home: PeopleScreen(),
        ),
      );
    }

    testWidgets('renders self profile and empty friends state initially', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // "You" profile is visible
      expect(find.text('You'), findsWidgets);
      expect(find.text('YOUR PROFILE'), findsOneWidget);

      // Empty friends state is visible
      expect(find.text('No friends added yet'), findsOneWidget);
      expect(find.text('Add Friend'), findsWidgets);
    });

    testWidgets('adds a new friend via AddEditPersonDialog and updates UI', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // Tap Add Friend action button in AppBar
      await tester.tap(find.byIcon(Icons.person_add_rounded).first);
      await tester.pumpAndSettle();

      // Verify dialog is open
      expect(find.byType(AddEditPersonDialog), findsOneWidget);
      expect(find.text('Enter name of your friend'), findsOneWidget);

      // Enter friend name "Anu"
      await tester.enterText(find.byType(TextFormField), 'Anu');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      // Verify dialog dismissed and Anu appears in list
      expect(find.byType(AddEditPersonDialog), findsNothing);
      expect(find.text('Anu'), findsOneWidget);
      expect(find.text('FRIENDS (1)'), findsOneWidget);
    });

    testWidgets('search filters people list correctly', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump();
      await tester.pumpAndSettle();

      // Add two friends: Anu and Rahul
      await tester.tap(find.byIcon(Icons.person_add_rounded).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Anu');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.person_add_rounded).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Rahul');
      await tester.tap(find.byKey(const Key('add_person_submit_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Anu'), findsOneWidget);
      expect(find.text('Rahul'), findsOneWidget);

      // Search for "rah"
      await tester.enterText(find.byType(TextField).first, 'rah');
      await tester.pumpAndSettle();

      // Rahul matches, Anu does not
      expect(find.text('Rahul'), findsOneWidget);
      expect(find.text('Anu'), findsNothing);

      // Search for non-existent "Zara"
      await tester.enterText(find.byType(TextField).first, 'Zara');
      await tester.pumpAndSettle();
      expect(find.text('No results for "Zara"'), findsOneWidget);

      // Tap clear search
      await tester.tap(find.text('Clear Search'));
      await tester.pumpAndSettle();
      expect(find.text('Anu'), findsOneWidget);
      expect(find.text('Rahul'), findsOneWidget);
    });
  });
}
