import 'package:flutter/services.dart';

/// Typed wrapper around the native alarm/AI MethodChannel.
///
/// The channel name and method names must stay in sync with the Kotlin side
/// (android/.../bridge/AlarmBridge.kt and Constants.kt).
class AlarmBridge {
  AlarmBridge({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.fajrwakeup.app/alarm');

  final MethodChannel _channel;

  /// Replace the whole rolling schedule with [triggerMillis] (epoch millis).
  /// Native arms the soonest and keeps the rest; idempotent (no duplicates).
  Future<bool> scheduleFajrAlarms(List<int> triggerMillis, String label) async {
    final ok = await _channel.invokeMethod<bool>('scheduleFajrAlarms', {
      'triggers': triggerMillis,
      'label': label,
    });
    return ok ?? false;
  }

  Future<bool> cancelFajrAlarms() async =>
      await _channel.invokeMethod<bool>('cancelFajrAlarms') ?? false;

  Future<bool> canScheduleExactAlarms() async =>
      await _channel.invokeMethod<bool>('canScheduleExactAlarms') ?? false;

  Future<void> openExactAlarmSettings() async =>
      _channel.invokeMethod<void>('openExactAlarmSettings');

  Future<void> openAppSettings() async =>
      _channel.invokeMethod<void>('openAppSettings');

  Future<ScheduledInfo> getScheduledInfo() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('getScheduledInfo');
    return ScheduledInfo.fromMap(map ?? const {});
  }

  /// Dev test: fire a one-off alarm after [delaySeconds] without touching the
  /// real schedule.
  Future<bool> startTestAlarm({int delaySeconds = 60}) async =>
      await _channel.invokeMethod<bool>('startTestAlarm', {'delaySeconds': delaySeconds}) ?? false;

  Future<bool> stopAlarm({String reason = 'manual'}) async =>
      await _channel.invokeMethod<bool>('stopAlarm', {'reason': reason}) ?? false;

  Future<bool> isAlarmActive() async =>
      await _channel.invokeMethod<bool>('isAlarmActive') ?? false;

  Future<bool> setPlaybackConfig({
    required int repeatIntervalSeconds,
    String? adhanFilePath,
  }) async =>
      await _channel.invokeMethod<bool>('setPlaybackConfig', {
        'repeatIntervalSeconds': repeatIntervalSeconds,
        'adhanFilePath': adhanFilePath,
      }) ??
      false;

  Future<bool> setChallengeConfig({
    required double confidenceThreshold,
    required bool saveDiagnosticImages,
  }) async =>
      await _channel.invokeMethod<bool>('setChallengeConfig', {
        'confidenceThreshold': confidenceThreshold,
        'saveDiagnosticImages': saveDiagnosticImages,
      }) ??
      false;

  Future<LabelerInfo> getLabelerInfo() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('getLabelerInfo');
    return LabelerInfo.fromMap(map ?? const {});
  }

  /// Launches the native camera test-recognition screen. The result (and the
  /// detected labels/confidences) is shown on that screen; it does not return a
  /// value here.
  Future<void> testFaucetRecognition() async =>
      _channel.invokeMethod<void>('testFaucetRecognition');
}

class ScheduledInfo {
  const ScheduledInfo({
    this.nextTriggerMillis,
    this.count = 0,
    this.active = false,
    this.label = '',
  });

  final int? nextTriggerMillis;
  final int count;
  final bool active;
  final String label;

  DateTime? get nextTrigger => nextTriggerMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(nextTriggerMillis!);

  factory ScheduledInfo.fromMap(Map<String, dynamic> map) => ScheduledInfo(
        nextTriggerMillis: (map['nextTriggerMillis'] as num?)?.toInt(),
        count: (map['count'] as num?)?.toInt() ?? 0,
        active: map['active'] as bool? ?? false,
        label: map['label'] as String? ?? '',
      );
}

/// Status of the bundled ML Kit image labeler (no custom model file involved).
enum LabelerState {
  ready,
  error,
  unknown;

  static LabelerState parse(String? name) {
    switch (name) {
      case 'LABELER_READY':
        return LabelerState.ready;
      case 'LABELER_ERROR':
        return LabelerState.error;
      default:
        return LabelerState.unknown;
    }
  }
}

class LabelerInfo {
  const LabelerInfo({required this.state, this.detail});

  final LabelerState state;
  final String? detail;

  bool get isReady => state == LabelerState.ready;

  factory LabelerInfo.fromMap(Map<String, dynamic> map) => LabelerInfo(
        state: LabelerState.parse(map['state'] as String?),
        detail: map['detail'] as String?,
      );
}
