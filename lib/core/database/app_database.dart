import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'migrations.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('appDatabaseProvider must be initialized');
});

class AppDatabase {
  final Database _db;

  AppDatabase(this._db);

  Database get database => _db;

  static const String databaseName = 'splitmate.db';

  static Future<AppDatabase> open({
    String? path,
    DatabaseFactory? databaseFactory,
  }) async {
    final dbPath = path ?? p.join(await getDatabasesPath(), databaseName);

    final Database db;
    if (databaseFactory != null) {
      db = await databaseFactory.openDatabase(
        dbPath,
        options: OpenDatabaseOptions(
          version: DatabaseMigrations.currentVersion,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON;');
          },
          onCreate: DatabaseMigrations.onCreate,
          onUpgrade: DatabaseMigrations.onUpgrade,
        ),
      );
    } else {
      db = await openDatabase(
        dbPath,
        version: DatabaseMigrations.currentVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: DatabaseMigrations.onCreate,
        onUpgrade: DatabaseMigrations.onUpgrade,
      );
    }

    return AppDatabase(db);
  }

  /// Factory helper for creating in-memory databases (ideal for automated testing).
  static Future<AppDatabase> inMemory({DatabaseFactory? databaseFactory}) async {
    final factory = databaseFactory ?? databaseFactorySqflitePlugin;
    final db = await factory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: DatabaseMigrations.currentVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: DatabaseMigrations.onCreate,
        onUpgrade: DatabaseMigrations.onUpgrade,
      ),
    );
    return AppDatabase(db);
  }

  Future<void> close() async {
    await _db.close();
  }
}
