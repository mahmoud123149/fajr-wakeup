import 'package:sqflite/sqflite.dart';

import '../../core/storage/app_database.dart';
import '../models/wake_record.dart';

/// Reads/writes the `wake_history` table and derives statistics.
class HistoryRepository {
  HistoryRepository({Future<Database> Function()? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  final Future<Database> Function() _dbProvider;

  /// Insert a record, ignoring duplicates (same scheduled + recorded_at).
  Future<void> insert(WakeRecord record) async {
    final db = await _dbProvider();
    await db.insert(
      'wake_history',
      record.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<WakeRecord>> recent({int limit = 200}) async {
    final db = await _dbProvider();
    final rows = await db.query(
      'wake_history',
      orderBy: 'triggered_millis DESC',
      limit: limit,
    );
    return rows.map(WakeRecord.fromMap).toList();
  }

  Future<List<WakeRecord>> since(DateTime from) async {
    final db = await _dbProvider();
    final rows = await db.query(
      'wake_history',
      where: 'triggered_millis >= ?',
      whereArgs: [from.millisecondsSinceEpoch],
      orderBy: 'triggered_millis DESC',
    );
    return rows.map(WakeRecord.fromMap).toList();
  }

  Future<WakeStats> stats() async => computeStats(await recent(limit: 1000));

  Future<void> clear() async {
    final db = await _dbProvider();
    await db.delete('wake_history');
  }

  /// Pure, testable aggregation.
  static WakeStats computeStats(List<WakeRecord> records) {
    if (records.isEmpty) {
      return const WakeStats(total: 0, verified: 0, emergency: 0, averageChallenge: null);
    }
    var verified = 0;
    var emergency = 0;
    var durationSum = Duration.zero;
    var durationCount = 0;
    for (final r in records) {
      switch (r.outcome) {
        case WakeOutcome.verified:
          verified++;
          break;
        case WakeOutcome.emergencyStop:
          emergency++;
          break;
        case WakeOutcome.triggered:
          break;
      }
      final d = r.challengeDuration;
      if (d != null) {
        durationSum += d;
        durationCount++;
      }
    }
    final avg = durationCount == 0
        ? null
        : Duration(milliseconds: durationSum.inMilliseconds ~/ durationCount);
    return WakeStats(
      total: records.length,
      verified: verified,
      emergency: emergency,
      averageChallenge: avg,
    );
  }
}
