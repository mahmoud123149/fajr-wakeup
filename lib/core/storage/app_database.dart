import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Owns the single SQLite database. Flutter is the sole owner of this DB; the
/// native side never opens it (it hands events off via a JSONL file instead).
class AppDatabase {
  AppDatabase._();

  static const _dbName = 'fajr_wakeup.db';
  static const _dbVersion = 1;

  static Database? _db;

  static Future<Database> instance() async {
    final existing = _db;
    if (existing != null) return existing;
    final db = await _open();
    _db = db;
    return db;
  }

  static Future<Database> _open() async {
    final basePath = await getDatabasesPath();
    final path = p.join(basePath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: _onCreate,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
    // Key/value settings (app config stored as one JSON row; extensible).
    await db.execute('''
      CREATE TABLE settings (
        key   TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Combined alarm + verification history.
    await db.execute('''
      CREATE TABLE wake_history (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        scheduled_millis INTEGER NOT NULL,
        triggered_millis INTEGER NOT NULL,
        resolved_millis  INTEGER,
        outcome          TEXT    NOT NULL,
        confidence       REAL,
        attempts         INTEGER NOT NULL DEFAULT 0,
        recorded_at      INTEGER NOT NULL
      )
    ''');

    // Guards against importing the same native event twice.
    await db.execute('''
      CREATE UNIQUE INDEX idx_wake_dedupe
      ON wake_history (scheduled_millis, recorded_at)
    ''');
  }

  /// For tests: inject an in-memory / ffi database.
  static void overrideForTest(Database db) => _db = db;

  static Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
