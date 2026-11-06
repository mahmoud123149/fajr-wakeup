import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../core/storage/app_database.dart';
import '../models/app_settings.dart';

/// Loads/saves [AppSettings] as a single JSON row in the `settings` table.
class SettingsRepository {
  SettingsRepository({Future<Database> Function()? dbProvider})
      : _dbProvider = dbProvider ?? AppDatabase.instance;

  final Future<Database> Function() _dbProvider;

  static const _key = 'app_settings';

  Future<AppSettings> load() async {
    final db = await _dbProvider();
    final rows = await db.query('settings', where: 'key = ?', whereArgs: [_key], limit: 1);
    if (rows.isEmpty) return const AppSettings();
    try {
      final json = jsonDecode(rows.first['value'] as String) as Map<String, dynamic>;
      return AppSettings.fromJson(json);
    } catch (_) {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings settings) async {
    final db = await _dbProvider();
    await db.insert(
      'settings',
      {'key': _key, 'value': jsonEncode(settings.toJson())},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
