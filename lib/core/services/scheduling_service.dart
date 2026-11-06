import '../../data/models/app_settings.dart';
import '../platform/alarm_bridge.dart';
import 'prayer_time_service.dart';

/// Bridges prayer-time computation and the native rolling scheduler, and keeps
/// the native playback/challenge config in sync with [AppSettings].
class SchedulingService {
  SchedulingService({
    PrayerTimeService? prayer,
    AlarmBridge? bridge,
  })  : prayer = prayer ?? PrayerTimeService(),
        bridge = bridge ?? AlarmBridge();

  final PrayerTimeService prayer;
  final AlarmBridge bridge;

  /// Pure computation: the list of epoch-millis triggers for [settings].
  /// Testable without any platform channel.
  List<int> computeTriggers(AppSettings settings, {DateTime? from}) {
    return prayer
        .upcomingFromSettings(settings, from: from)
        .map((t) => t.millisecondsSinceEpoch)
        .toList();
  }

  /// Recompute and (re)arm the schedule, pushing playback + challenge config.
  /// Idempotent on the native side (replaces, never duplicates).
  Future<List<int>> reschedule(AppSettings settings, {DateTime? from}) async {
    // Always keep native config current.
    await bridge.setPlaybackConfig(
      repeatIntervalSeconds: settings.repeatIntervalSeconds,
      adhanFilePath: settings.adhanFilePath,
    );
    await bridge.setChallengeConfig(
      confidenceThreshold: settings.confidenceThreshold,
      saveDiagnosticImages: settings.saveDiagnosticImages,
    );

    if (!settings.hasLocation) {
      await bridge.cancelFajrAlarms();
      return const [];
    }

    final triggers = computeTriggers(settings, from: from);
    if (triggers.isEmpty) {
      await bridge.cancelFajrAlarms();
      return const [];
    }
    await bridge.scheduleFajrAlarms(triggers, 'Fajr');
    return triggers;
  }

  Future<void> cancel() => bridge.cancelFajrAlarms();
}
