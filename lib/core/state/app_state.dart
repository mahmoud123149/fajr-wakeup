import 'package:flutter/foundation.dart';

import '../../data/models/app_settings.dart';
import '../../data/repositories/history_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../platform/alarm_bridge.dart';
import '../services/location_service.dart';
import '../services/permission_service.dart';
import '../services/prayer_time_service.dart';
import '../services/scheduling_service.dart';
import '../services/wake_event_import_service.dart';

/// Single source of UI truth. Owns settings and the derived next-Fajr / schedule
/// / model / permission snapshots, and coordinates the services.
class AppState extends ChangeNotifier {
  AppState({
    SettingsRepository? settingsRepo,
    HistoryRepository? historyRepo,
    SchedulingService? scheduling,
    PrayerTimeService? prayer,
    LocationService? location,
    PermissionService? permissions,
    AlarmBridge? bridge,
    WakeEventImportService? importService,
  })  : _settingsRepo = settingsRepo ?? SettingsRepository(),
        historyRepo = historyRepo ?? HistoryRepository(),
        _scheduling = scheduling ?? SchedulingService(),
        _prayer = prayer ?? PrayerTimeService(),
        _location = location ?? LocationService(),
        permissions = permissions ?? PermissionService(),
        _bridge = bridge ?? AlarmBridge(),
        _importService = importService ?? WakeEventImportService();

  final SettingsRepository _settingsRepo;
  final HistoryRepository historyRepo;
  final SchedulingService _scheduling;
  final PrayerTimeService _prayer;
  final LocationService _location;
  final PermissionService permissions;
  final AlarmBridge _bridge;
  final WakeEventImportService _importService;

  AppSettings _settings = const AppSettings();
  AppSettings get settings => _settings;

  DateTime? _nextFajr;
  DateTime? get nextFajr => _nextFajr;

  ScheduledInfo _scheduledInfo = const ScheduledInfo();
  ScheduledInfo get scheduledInfo => _scheduledInfo;

  LabelerInfo _labelerInfo = const LabelerInfo(state: LabelerState.unknown);
  LabelerInfo get labelerInfo => _labelerInfo;

  PermissionSnapshot _permissionSnapshot = const PermissionSnapshot(
    notifications: false,
    camera: false,
    location: false,
    exactAlarm: false,
  );
  PermissionSnapshot get permissionSnapshot => _permissionSnapshot;

  bool _busy = false;
  bool get busy => _busy;

  PrayerTimeService get prayer => _prayer;

  Future<void> init() async {
    try {
      _settings = await _settingsRepo.load();
      await _importService.importPending();
      // Make sure the native side reflects the loaded settings (also handles the
      // first run after install and keeps the rolling schedule fresh).
      await _scheduling.reschedule(_settings);
      await _refreshSnapshots();
      _recomputeNextFajr();
    } catch (e, st) {
      // Never let startup wiring crash the first frame; surface a usable UI.
      debugPrint('AppState.init error: $e\n$st');
    } finally {
      notifyListeners();
    }
  }

  /// Lightweight refresh for app resume.
  Future<void> refresh() async {
    try {
      await _importService.importPending();
      await _refreshSnapshots();
      _recomputeNextFajr();
    } catch (e) {
      debugPrint('AppState.refresh error: $e');
    } finally {
      notifyListeners();
    }
  }

  Future<void> _refreshSnapshots() async {
    _scheduledInfo = await _bridge.getScheduledInfo();
    _labelerInfo = await _bridge.getLabelerInfo();
    _permissionSnapshot = await permissions.snapshot();
  }

  void _recomputeNextFajr() {
    _nextFajr = _prayer.nextFajrFromSettings(_settings);
  }

  /// Persist new settings, re-arm the schedule and refresh derived state.
  Future<void> updateSettings(AppSettings newSettings) async {
    _busy = true;
    notifyListeners();
    _settings = newSettings;
    await _settingsRepo.save(newSettings);
    await _scheduling.reschedule(newSettings);
    await _refreshSnapshots();
    _recomputeNextFajr();
    _busy = false;
    notifyListeners();
  }

  /// Detect the device location and store it. Returns true on success.
  Future<bool> detectLocation() async {
    final pos = await _location.current();
    if (pos == null) return false;
    await updateSettings(_settings.copyWith(
      latitude: pos.latitude,
      longitude: pos.longitude,
      locationName:
          '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}',
      useDeviceLocation: true,
    ));
    return true;
  }

  Future<void> setAdhanFile({required String path, required String name}) =>
      updateSettings(_settings.copyWith(adhanFilePath: path, adhanFileName: name));

  Future<void> removeAdhanFile() =>
      updateSettings(_settings.copyWith(adhanFilePath: null, adhanFileName: null));

  Future<void> scheduleTestAlarm() => _bridge.startTestAlarm(delaySeconds: 60);

  Future<void> testRecognition() => _bridge.testFaucetRecognition();

  Future<bool> requestExactAlarm() async {
    await permissions.openExactAlarmSettings();
    return true;
  }

  Future<void> clearHistory() async {
    await historyRepo.clear();
    notifyListeners();
  }
}
