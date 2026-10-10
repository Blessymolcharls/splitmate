import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import '../../../core/errors/app_exceptions.dart';
import '../domain/person.dart';

abstract class PeopleRepository {
  Future<List<Person>> getAllPeople({bool includeArchived = false});
  Future<Person?> getPersonById(String id);
  Future<Person?> findPersonByName(String name, {bool includeArchived = true});
  Future<Person> getSelfPerson();
  Future<Person> addPerson(String name);
  Future<Person> getOrCreatePerson(String name);
  Future<Person> updatePersonName(String id, String newName);
  Future<void> archivePerson(String id);
  Future<void> unarchivePerson(String id);
  Future<bool> hasTransactionHistory(String personId);
  Future<void> deleteOrArchivePerson(String id);
}

class SqlitePeopleRepository implements PeopleRepository {
  final Database _db;
  final Uuid _uuid;

  SqlitePeopleRepository(this._db, [Uuid? uuid]) : _uuid = uuid ?? const Uuid();

  static String validateName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationException('Name cannot be empty');
    }
    return trimmed;
  }

  @override
  Future<List<Person>> getAllPeople({bool includeArchived = false}) async {
    final whereClause = includeArchived ? null : 'is_archived = 0';
    final rows = await _db.query(
      'people',
      where: whereClause,
      orderBy: 'is_self DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(Person.fromMap).toList();
  }

  @override
  Future<Person?> getPersonById(String id) async {
    final rows = await _db.query(
      'people',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Person.fromMap(rows.first);
  }

  @override
  Future<Person?> findPersonByName(String name, {bool includeArchived = true}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    final whereClause = includeArchived
        ? 'LOWER(name) = LOWER(?)'
        : 'LOWER(name) = LOWER(?) AND is_archived = 0';
    final rows = await _db.query(
      'people',
      where: whereClause,
      whereArgs: [trimmed],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Person.fromMap(rows.first);
  }

  @override
  Future<Person> getSelfPerson() async {
    final rows = await _db.query(
      'people',
      where: 'is_self = 1',
      limit: 1,
    );
    if (rows.isEmpty) {
      throw const NotFoundException('Self profile not found in database');
    }
    return Person.fromMap(rows.first);
  }

  @override
  Future<Person> addPerson(String name) async {
    final validName = validateName(name);

    // Reuse existing contact (case-insensitive) if one already exists
    final existing = await findPersonByName(validName, includeArchived: true);
    if (existing != null) {
      if (existing.isArchived) {
        await unarchivePerson(existing.id);
        return existing.copyWith(isArchived: false);
      }
      return existing;
    }

    final now = DateTime.now();
    final person = Person(
      id: _uuid.v4(),
      name: validName,
      isSelf: false,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
    );

    await _db.insert('people', person.toMap());
    return person;
  }

  @override
  Future<Person> getOrCreatePerson(String name) => addPerson(name);

  @override
  Future<Person> updatePersonName(String id, String newName) async {
    final validName = validateName(newName);
    final existing = await getPersonById(id);
    if (existing == null) {
      throw const NotFoundException('Person not found');
    }

    final now = DateTime.now();
    await _db.update(
      'people',
      {
        'name': validName,
        'updated_at': now.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return existing.copyWith(
      name: validName,
      updatedAt: now,
    );
  }

  @override
  Future<void> archivePerson(String id) async {
    final person = await getPersonById(id);
    if (person == null) {
      throw const NotFoundException('Person not found');
    }

    if (person.isSelf) {
      throw const BusinessRuleException('Cannot archive the self profile');
    }

    final now = DateTime.now().toIso8601String();
    await _db.update(
      'people',
      {
        'is_archived': 1,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<void> unarchivePerson(String id) async {
    final person = await getPersonById(id);
    if (person == null) {
      throw const NotFoundException('Person not found');
    }

    final now = DateTime.now().toIso8601String();
    await _db.update(
      'people',
      {
        'is_archived': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<bool> hasTransactionHistory(String personId) async {
    final expenses = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM expenses WHERE payer_id = ?',
      [personId],
    )) ?? 0;
    if (expenses > 0) return true;

    final shares = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM expense_shares WHERE person_id = ?',
      [personId],
    )) ?? 0;
    if (shares > 0) return true;

    final debts = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM manual_debts WHERE debtor_id = ? OR creditor_id = ?',
      [personId, personId],
    )) ?? 0;
    if (debts > 0) return true;

    final settlements = Sqflite.firstIntValue(await _db.rawQuery(
      'SELECT COUNT(*) FROM settlements WHERE payer_id = ? OR receiver_id = ?',
      [personId, personId],
    )) ?? 0;
    return settlements > 0;
  }

  @override
  Future<void> deleteOrArchivePerson(String id) async {
    final person = await getPersonById(id);
    if (person == null) {
      throw const NotFoundException('Person not found');
    }

    if (person.isSelf) {
      throw const BusinessRuleException('Cannot remove the self profile');
    }

    final hasHistory = await hasTransactionHistory(id);
    if (hasHistory) {
      // Historical references exist -> preserve data integrity via archival
      await archivePerson(id);
    } else {
      // Safe to delete cleanly without orphaned references
      await _db.delete('people', where: 'id = ?', whereArgs: [id]);
    }
  }
}
