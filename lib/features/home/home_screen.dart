import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/ar_strings.dart';
import '../../core/platform/alarm_bridge.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../core/widgets/app_widgets.dart';
import '../challenge/challenge_settings_screen.dart';
import '../history/history_screen.dart';
import '../prayer_times/prayer_settings_screen.dart';
import '../settings/adhan_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _ticker;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!mounted) return;
    final next = context.read<AppState>().nextFajr;
    if (next == null) return;
    setState(() => _remaining = next.difference(DateTime.now()));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final next = app.nextFajr;

    return Scaffold(
      appBar: AppBar(title: const Text(S.appName)),
      body: RefreshIndicator(
        onRefresh: () => app.refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _nextFajrCard(next),
            if (!app.permissionSnapshot.exactAlarm)
              WarningBanner(
                message: S.exactAlarmNeeded,
                actionLabel: S.grantExactAlarm,
                onAction: () => app.requestExactAlarm(),
              ),
            if (!app.permissionSnapshot.notifications)
              WarningBanner(
                message: S.notificationsNeeded,
                actionLabel: S.grantNotifications,
                onAction: () => app.permissions.ensureNotifications(),
              ),
            _statusCard(app),
            const SizedBox(height: 8),
            _navGrid(context),
          ],
        ),
      ),
    );
  }

  Widget _nextFajrCard(DateTime? next) {
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            const Text(S.nextFajr, style: TextStyle(color: AppColors.gold, fontSize: 16)),
            const SizedBox(height: 12),
            Text(
              next == null ? '—' : Fmt.clock(next),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (next != null) ...[
              const SizedBox(height: 6),
              Text(Fmt.fullDate(next),
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 18),
              const Text(S.countdownRemaining,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              const SizedBox(height: 2),
              Text(
                Fmt.countdown(_remaining),
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w600,
                  color: AppColors.gold,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ] else
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(S.noLocation, style: TextStyle(color: AppColors.textSecondary)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusCard(AppState app) {
    final info = app.scheduledInfo;
    final active = info.active;
    return SectionCard(
      title: S.alarmStatus,
      icon: Icons.alarm,
      children: [
        LabeledValue(
          label: S.alarmStatus,
          value: active ? S.alarmActive : S.alarmInactive,
          valueColor: active ? AppColors.success : AppColors.textSecondary,
        ),
        LabeledValue(
          label: S.alarmArmedCount,
          value: Fmt.toArabicDigits('${info.count}'),
        ),
        LabeledValue(label: S.calcMethodLabel, value: app.settings.calcMethod.arabicName),
        LabeledValue(
          label: S.locationLabel,
          value: app.settings.hasLocation
              ? (app.settings.locationName.isEmpty
                  ? Fmt.toArabicDigits(
                      '${app.settings.latitude!.toStringAsFixed(3)}, ${app.settings.longitude!.toStringAsFixed(3)}')
                  : app.settings.locationName)
              : S.noLocation,
        ),
        _labelerStatusRow(app.labelerInfo),
      ],
    );
  }

  Widget _labelerStatusRow(LabelerInfo info) {
    final (text, color) = switch (info.state) {
      LabelerState.ready => (S.modelReady, AppColors.success),
      LabelerState.error => (S.modelError, AppColors.error),
      LabelerState.unknown => ('—', AppColors.textSecondary),
    };
    return LabeledValue(label: S.modelStatus, value: text, valueColor: color);
  }

  Widget _navGrid(BuildContext context) {
    final items = <(IconData, String, Widget)>[
      (Icons.schedule, S.prayerSettings, const PrayerSettingsScreen()),
      (Icons.volume_up, S.adhanSettings, const AdhanSettingsScreen()),
      (Icons.camera_alt, S.challengeSettings, const ChallengeSettingsScreen()),
      (Icons.history, S.history, const HistoryScreen()),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        for (final (icon, label, screen) in items)
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => screen),
            ),
            child: AppCard(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.gold, size: 30),
                  const SizedBox(height: 10),
                  Text(label, textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
