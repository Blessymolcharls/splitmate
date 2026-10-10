import 'package:flutter_test/flutter_test.dart';
import 'package:splitmate/core/database/app_database.dart';
import 'package:splitmate/core/database/migrations.dart';
import 'package:splitmate/core/errors/app_exceptions.dart';
import 'package:splitmate/features/people/data/people_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
  });

  group('SqlitePeopleRepository Tests', () {
    late AppDatabase appDb;
    late SqlitePeopleRepository repository;

    setUp(() async {
      appDb = await AppDatabase.inMemory(databaseFactory: databaseFactoryFfi);
      repository = SqlitePeopleRepository(appDb.database);
    });

    tearDown(() async {
      await appDb.close();
    });

    test('initial state contains default self profile You', () async {
      final people = await repository.getAllPeople();
      expect(people.length, 1);
      final self = people.first;
      expect(self.id, DatabaseMigrations.defaultSelfUserId);
      expect(self.name, 'You');
      expect(self.isSelf, true);
      expect(self.isArchived, false);
    });

    test('addPerson adds contacts and lists them in alphabetical order with self on top', () async {
      final rahul = await repository.addPerson('Rahul');
      final anu = await repository.addPerson('Anu');

      expect(rahul.name, 'Rahul');
      expect(rahul.isSelf, false);
      expect(anu.name, 'Anu');
      expect(anu.isSelf, false);

      final all = await repository.getAllPeople();
      expect(all.length, 3);
      // Self profile is always first
      expect(all[0].name, 'You');
      expect(all[0].isSelf, true);
      // Remaining friends ordered alphabetically
      expect(all[1].name, 'Anu');
      expect(all[2].name, 'Rahul');
    });

    test('rejects blank or whitespace-only names', () async {
      expect(
        () => repository.addPerson(''),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => repository.addPerson('   '),
        throwsA(isA<ValidationException>()),
      );
      expect(
        () => repository.updatePersonName(
          DatabaseMigrations.defaultSelfUserId,
          '  ',
        ),
        throwsA(isA<ValidationException>()),
      );
    });

    test('preserve a person ID when renaming (both self and friend)', () async {
      // Rename self
      final originalSelfId = DatabaseMigrations.defaultSelfUserId;
      final updatedSelf = await repository.updatePersonName(
        originalSelfId,
        'Blessy Thomas',
      );
      expect(updatedSelf.id, originalSelfId);
      expect(updatedSelf.name, 'Blessy Thomas');
      expect(updatedSelf.isSelf, true);

      // Verify DB fetch
      final fetchedSelf = await repository.getPersonById(originalSelfId);
      expect(fetchedSelf?.name, 'Blessy Thomas');
      expect(fetchedSelf?.id, originalSelfId);

      // Rename friend
      final friend = await repository.addPerson('Rahul');
      final originalFriendId = friend.id;
      final updatedFriend = await repository.updatePersonName(
        originalFriendId,
        'Rahul Sharma',
      );
      expect(updatedFriend.id, originalFriendId);
      expect(updatedFriend.name, 'Rahul Sharma');

      final fetchedFriend = await repository.getPersonById(originalFriendId);
      expect(fetchedFriend?.name, 'Rahul Sharma');
      expect(fetchedFriend?.id, originalFriendId);
    });

    test('prevent archival and deletion of self profile', () async {
      expect(
        () => repository.archivePerson(DatabaseMigrations.defaultSelfUserId),
        throwsA(isA<BusinessRuleException>()),
      );
      expect(
        () => repository.deleteOrArchivePerson(
          DatabaseMigrations.defaultSelfUserId,
        ),
        throwsA(isA<BusinessRuleException>()),
      );
    });

    test('archives contact without breaking references or orphaning data', () async {
      final friend = await repository.addPerson('Rahul');

      // Archive Rahul
      await repository.archivePerson(friend.id);

      // Active list excludes archived contacts
      final active = await repository.getAllPeople();
      expect(active.any((p) => p.id == friend.id), false);

      // Full list includes archived contacts
      final all = await repository.getAllPeople(includeArchived: true);
      final archivedRahul = all.firstWhere((p) => p.id == friend.id);
      expect(archivedRahul.isArchived, true);

      // Unarchive
      await repository.unarchivePerson(friend.id);
      final restored = await repository.getAllPeople();
      expect(restored.any((p) => p.id == friend.id), true);
    });

    test('deleteOrArchivePerson deletes if no transactions, archives if transactions exist', () async {
      final friendClean = await repository.addPerson('Clean Friend');
      final friendWithDebt = await repository.addPerson('Debt Friend');

      // Add a manual debt referencing friendWithDebt
      await appDb.database.insert('manual_debts', {
        'id': 'debt-test-1',
        'debtor_id': DatabaseMigrations.defaultSelfUserId,
        'creditor_id': friendWithDebt.id,
        'amount_paise': 5000,
        'debt_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // friendClean has no transactions -> completely deleted
      await repository.deleteOrArchivePerson(friendClean.id);
      expect(await repository.getPersonById(friendClean.id), isNull);

      // friendWithDebt has transactions -> archived to protect ledger integrity
      await repository.deleteOrArchivePerson(friendWithDebt.id);
      final archived = await repository.getPersonById(friendWithDebt.id);
      expect(archived, isNotNull);
      expect(archived!.isArchived, true);
    });

    test('verify persistence after reopening database', () async {
      final friend = await repository.addPerson('Priya');
      await repository.updatePersonName(
        DatabaseMigrations.defaultSelfUserId,
        'Blessy Kurian',
      );

      // Simulate app restart / reopen with the same underlying DB instance
      final freshRepo = SqlitePeopleRepository(appDb.database);
      final people = await freshRepo.getAllPeople();

      expect(people.length, 2);
      expect(people[0].name, 'Blessy Kurian');
      expect(people[1].name, 'Priya');
      expect(people[1].id, friend.id);
    });
  });
}
