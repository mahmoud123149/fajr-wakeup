import 'package:fajr_wakeup/data/models/app_settings.dart';
import 'package:fajr_wakeup/data/models/calc_method.dart';
import 'package:fajr_wakeup/data/models/wake_record.dart';
import 'package:fajr_wakeup/data/repositories/history_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppSettings', () {
    test('JSON round-trip preserves values', () {
      const s = AppSettings(
        latitude: 21.4,
        longitude: 39.8,
        locationName: 'Mecca',
        calcMethod: CalcMethod.ummAlQura,
        madhab: MadhabPref.hanafi,
        fajrAdjustmentMinutes: -3,
        repeatIntervalSeconds: 30,
        adhanFilePath: '/data/adhan.mp3',
        adhanFileName: 'adhan.mp3',
        confidenceThreshold: 0.9,
        saveDiagnosticImages: true,
        scheduleBufferDays: 10,
      );
      final restored = AppSettings.fromJson(s.toJson());
      expect(restored.latitude, 21.4);
      expect(restored.calcMethod, CalcMethod.ummAlQura);
      expect(restored.madhab, MadhabPref.hanafi);
      expect(restored.fajrAdjustmentMinutes, -3);
      expect(restored.adhanFilePath, '/data/adhan.mp3');
      expect(restored.confidenceThreshold, 0.9);
      expect(restored.saveDiagnosticImages, isTrue);
      expect(restored.scheduleBufferDays, 10);
    });

    test('copyWith can clear the adhan file path', () {
      const s = AppSettings(adhanFilePath: '/x.mp3', adhanFileName: 'x.mp3');
      final cleared = s.copyWith(adhanFilePath: null, adhanFileName: null);
      expect(cleared.adhanFilePath, isNull);
      expect(cleared.adhanFileName, isNull);
    });

    test('copyWith without adhan args keeps existing path', () {
      const s = AppSettings(adhanFilePath: '/x.mp3');
      final same = s.copyWith(repeatIntervalSeconds: 5);
      expect(same.adhanFilePath, '/x.mp3');
      expect(same.repeatIntervalSeconds, 5);
    });

    test('hasLocation reflects lat/long presence', () {
      expect(const AppSettings().hasLocation, isFalse);
      expect(const AppSettings(latitude: 1, longitude: 2).hasLocation, isTrue);
    });
  });

  group('WakeRecord', () {
    test('parses native JSON and computes duration', () {
      final json = {
        'scheduledTimeMillis': DateTime(2026, 1, 15, 5, 0).millisecondsSinceEpoch,
        'triggeredTimeMillis': DateTime(2026, 1, 15, 5, 0, 2).millisecondsSinceEpoch,
        'resolvedTimeMillis': DateTime(2026, 1, 15, 5, 2, 2).millisecondsSinceEpoch,
        'outcome': 'VERIFIED',
        'confidence': 0.93,
        'attempts': 2,
        'recordedAt': DateTime(2026, 1, 15, 5, 2, 2).millisecondsSinceEpoch,
      };
      final r = WakeRecord.fromNativeJson(json);
      expect(r.outcome, WakeOutcome.verified);
      expect(r.succeeded, isTrue);
      expect(r.attempts, 2);
      expect(r.challengeDuration, const Duration(minutes: 2));
      expect(r.confidence, 0.93);
    });

    test('map round-trip', () {
      final r = WakeRecord(
        scheduled: DateTime(2026, 1, 15, 5),
        triggered: DateTime(2026, 1, 15, 5),
        outcome: WakeOutcome.emergencyStop,
        attempts: 1,
        recordedAt: DateTime(2026, 1, 15, 5),
      );
      final back = WakeRecord.fromMap(r.toMap());
      expect(back.outcome, WakeOutcome.emergencyStop);
      expect(back.attempts, 1);
    });
  });

  group('HistoryRepository.computeStats', () {
    WakeRecord rec(WakeOutcome o, {Duration? dur}) => WakeRecord(
          scheduled: DateTime(2026, 1, 15, 5),
          triggered: DateTime(2026, 1, 15, 5),
          resolved: dur == null ? null : DateTime(2026, 1, 15, 5).add(dur),
          outcome: o,
          recordedAt: DateTime(2026, 1, 15, 5),
        );

    test('empty list yields zeroes', () {
      final stats = HistoryRepository.computeStats([]);
      expect(stats.total, 0);
      expect(stats.successRate, 0);
      expect(stats.averageChallenge, isNull);
    });

    test('aggregates outcomes and average duration', () {
      final stats = HistoryRepository.computeStats([
        rec(WakeOutcome.verified, dur: const Duration(minutes: 2)),
        rec(WakeOutcome.verified, dur: const Duration(minutes: 4)),
        rec(WakeOutcome.emergencyStop),
      ]);
      expect(stats.total, 3);
      expect(stats.verified, 2);
      expect(stats.emergency, 1);
      expect(stats.successRate, closeTo(2 / 3, 1e-9));
      expect(stats.averageChallenge, const Duration(minutes: 3));
    });
  });
}
