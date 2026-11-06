import 'package:fajr_wakeup/core/platform/alarm_bridge.dart';
import 'package:fajr_wakeup/core/services/scheduling_service.dart';
import 'package:fajr_wakeup/data/models/app_settings.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.fajrwakeup.app/alarm');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'getScheduledInfo') {
        return <String, dynamic>{'nextTriggerMillis': null, 'count': 0, 'active': false, 'label': ''};
      }
      return true;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  const located = AppSettings(latitude: 21.4225, longitude: 39.8262, scheduleBufferDays: 7);
  final from = DateTime(2026, 1, 15, 10, 0);

  test('computeTriggers yields bufferDays strictly increasing future millis', () {
    final svc = SchedulingService(bridge: AlarmBridge(channel: channel));
    final triggers = svc.computeTriggers(located, from: from);
    expect(triggers.length, 7);
    for (var i = 1; i < triggers.length; i++) {
      expect(triggers[i] > triggers[i - 1], isTrue);
    }
    expect(triggers.first > from.millisecondsSinceEpoch, isTrue);
  });

  test('reschedule pushes config and schedules exactly once (idempotent call)', () async {
    final svc = SchedulingService(bridge: AlarmBridge(channel: channel));
    final triggers = await svc.reschedule(located, from: from);

    expect(triggers.length, 7);
    expect(calls.where((c) => c.method == 'setPlaybackConfig').length, 1);
    expect(calls.where((c) => c.method == 'setChallengeConfig').length, 1);

    final scheduleCalls = calls.where((c) => c.method == 'scheduleFajrAlarms').toList();
    expect(scheduleCalls.length, 1);
    final args = scheduleCalls.single.arguments as Map;
    expect((args['triggers'] as List).length, 7);
    expect(args['label'], 'Fajr');
  });

  test('no location cancels alarms and returns empty', () async {
    final svc = SchedulingService(bridge: AlarmBridge(channel: channel));
    const noLoc = AppSettings();
    final triggers = await svc.reschedule(noLoc, from: from);

    expect(triggers, isEmpty);
    expect(calls.any((c) => c.method == 'cancelFajrAlarms'), isTrue);
    expect(calls.any((c) => c.method == 'scheduleFajrAlarms'), isFalse);
  });
}
