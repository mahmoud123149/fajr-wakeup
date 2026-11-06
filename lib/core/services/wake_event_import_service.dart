import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/models/wake_record.dart';
import '../../data/repositories/history_repository.dart';

/// Drains the native JSONL hand-off file into the SQLite history table.
///
/// The native alarm stack appends one JSON object per line to
/// `<filesDir>/pending_wake_events.jsonl`. On Android, path_provider's
/// getApplicationSupportDirectory() maps to that same filesDir.
class WakeEventImportService {
  WakeEventImportService({HistoryRepository? history})
      : history = history ?? HistoryRepository();

  final HistoryRepository history;

  static const _fileName = 'pending_wake_events.jsonl';

  Future<int> importPending() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File(p.join(dir.path, _fileName));
      if (!await file.exists()) return 0;

      final lines = await file.readAsLines();
      var imported = 0;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        try {
          final json = jsonDecode(trimmed) as Map<String, dynamic>;
          await history.insert(WakeRecord.fromNativeJson(json));
          imported++;
        } catch (_) {
          // Skip malformed lines rather than losing the whole batch.
        }
      }
      // Truncate so events are imported exactly once.
      await file.writeAsString('');
      return imported;
    } catch (_) {
      return 0;
    }
  }
}
