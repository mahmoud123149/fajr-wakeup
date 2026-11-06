import 'package:permission_handler/permission_handler.dart';

import '../platform/alarm_bridge.dart';

/// Centralises runtime permission requests. Exact-alarm handling is delegated to
/// the native bridge (it needs the AlarmManager API / system settings screen).
class PermissionService {
  PermissionService({AlarmBridge? bridge}) : bridge = bridge ?? AlarmBridge();

  final AlarmBridge bridge;

  Future<bool> ensureNotifications() async {
    final status = await Permission.notification.status;
    if (status.isGranted) return true;
    return (await Permission.notification.request()).isGranted;
  }

  Future<bool> ensureCamera() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;
    return (await Permission.camera.request()).isGranted;
  }

  Future<bool> ensureLocation() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;
    return (await Permission.locationWhenInUse.request()).isGranted;
  }

  Future<bool> canScheduleExactAlarms() => bridge.canScheduleExactAlarms();

  Future<void> openExactAlarmSettings() => bridge.openExactAlarmSettings();

  Future<void> openAppSettings() => bridge.openAppSettings();

  /// A quick snapshot for the home screen's status indicators.
  Future<PermissionSnapshot> snapshot() async {
    return PermissionSnapshot(
      notifications: await Permission.notification.isGranted,
      camera: await Permission.camera.isGranted,
      location: await Permission.locationWhenInUse.isGranted,
      exactAlarm: await bridge.canScheduleExactAlarms(),
    );
  }
}

class PermissionSnapshot {
  const PermissionSnapshot({
    required this.notifications,
    required this.camera,
    required this.location,
    required this.exactAlarm,
  });

  final bool notifications;
  final bool camera;
  final bool location;
  final bool exactAlarm;

  bool get allCritical => notifications && exactAlarm;
}
