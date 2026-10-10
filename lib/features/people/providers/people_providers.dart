import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../data/people_repository.dart';
import '../domain/person.dart';

final peopleRepositoryProvider = Provider<PeopleRepository>((ref) {
  final appDb = ref.watch(appDatabaseProvider);
  return SqlitePeopleRepository(appDb.database);
});

class PeopleListNotifier extends AsyncNotifier<List<Person>> {
  @override
  Future<List<Person>> build() async {
    final repo = ref.watch(peopleRepositoryProvider);
    return repo.getAllPeople();
  }

  Future<Person> addPerson(String name) async {
    final repo = ref.read(peopleRepositoryProvider);
    final newPerson = await repo.addPerson(name);
    ref.invalidateSelf();
    await future;
    return newPerson;
  }

  Future<Person> getOrCreatePerson(String name) async {
    final repo = ref.read(peopleRepositoryProvider);
    final person = await repo.getOrCreatePerson(name);
    ref.invalidateSelf();
    await future;
    return person;
  }

  Future<Person> updatePersonName(String id, String newName) async {
    final repo = ref.read(peopleRepositoryProvider);
    final updated = await repo.updatePersonName(id, newName);
    ref.invalidateSelf();
    await future;
    return updated;
  }

  Future<void> deleteOrArchivePerson(String id) async {
    final repo = ref.read(peopleRepositoryProvider);
    await repo.deleteOrArchivePerson(id);
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final peopleListProvider =
    AsyncNotifierProvider<PeopleListNotifier, List<Person>>(
  PeopleListNotifier.new,
);

class PeopleSearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final peopleSearchQueryProvider =
    NotifierProvider<PeopleSearchQueryNotifier, String>(
  PeopleSearchQueryNotifier.new,
);

final filteredPeopleProvider = Provider<AsyncValue<List<Person>>>((ref) {
  final peopleAsync = ref.watch(peopleListProvider);
  final query = ref.watch(peopleSearchQueryProvider).trim().toLowerCase();

  return peopleAsync.whenData((people) {
    if (query.isEmpty) return people;
    return people.where((p) => p.name.toLowerCase().contains(query)).toList();
  });
});

final selfPersonProvider = Provider<Person?>((ref) {
  final peopleAsync = ref.watch(peopleListProvider);
  final list = peopleAsync.asData?.value;
  if (list == null) return null;
  for (final p in list) {
    if (p.isSelf) return p;
  }
  return null;
});

final personDetailProvider =
    Provider.family<AsyncValue<Person?>, String>((ref, id) {
  final peopleAsync = ref.watch(peopleListProvider);
  return peopleAsync.whenData((people) {
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  });
});
