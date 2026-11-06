import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/ar_strings.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/wake_record.dart';
import '../../data/repositories/history_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late Future<List<WakeRecord>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _future = context.read<AppState>().historyRepo.recent();
  }

  Future<void> _confirmClear(AppState app) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.navySurface,
        title: const Text(S.clearHistory),
        content: const Text('${S.clearHistory}؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text(S.cancel)),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text(S.confirm)),
        ],
      ),
    );
    if (ok == true) {
      await app.clearHistory();
      setState(_reload);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(S.history),
        actions: [
          IconButton(
            onPressed: () => _confirmClear(app),
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: S.clearHistory,
          ),
        ],
      ),
      body: FutureBuilder<List<WakeRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? const <WakeRecord>[];
          if (records.isEmpty) {
            return const Center(
              child: Text(S.noHistory, style: TextStyle(color: AppColors.textSecondary)),
            );
          }
          final stats = HistoryRepository.computeStats(records);
          return RefreshIndicator(
            onRefresh: () async {
              await app.refresh();
              setState(_reload);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _statsCard(stats),
                const SizedBox(height: 8),
                for (final r in records) _recordTile(r),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statsCard(WakeStats stats) {
    return SectionCard(
      title: S.history,
      icon: Icons.insights,
      children: [
        LabeledValue(label: S.statsTotal, value: Fmt.toArabicDigits('${stats.total}')),
        LabeledValue(
          label: S.statsVerified,
          value: Fmt.toArabicDigits('${stats.verified}'),
          valueColor: AppColors.success,
        ),
        LabeledValue(
          label: S.statsEmergency,
          value: Fmt.toArabicDigits('${stats.emergency}'),
          valueColor: AppColors.error,
        ),
        LabeledValue(label: S.statsSuccessRate, value: Fmt.percent(stats.successRate)),
        LabeledValue(
          label: S.statsAvgChallenge,
          value: Fmt.durationShort(stats.averageChallenge),
        ),
      ],
    );
  }

  Widget _recordTile(WakeRecord r) {
    final color = switch (r.outcome) {
      WakeOutcome.verified => AppColors.success,
      WakeOutcome.emergencyStop => AppColors.error,
      WakeOutcome.triggered => AppColors.textSecondary,
    };
    final icon = switch (r.outcome) {
      WakeOutcome.verified => Icons.verified,
      WakeOutcome.emergencyStop => Icons.stop_circle,
      WakeOutcome.triggered => Icons.help_outline,
    };
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    r.outcome.arabicLabel,
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(Fmt.dateTime(r.triggered),
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            LabeledValue(label: S.scheduledLabel, value: Fmt.clock(r.scheduled)),
            if (r.resolved != null)
              LabeledValue(label: S.resolvedLabel, value: Fmt.clock(r.resolved!)),
            LabeledValue(label: S.durationLabel, value: Fmt.durationShort(r.challengeDuration)),
            LabeledValue(label: S.attemptsLabel, value: Fmt.toArabicDigits('${r.attempts}')),
            if (r.confidence != null)
              LabeledValue(label: 'الثقة', value: Fmt.percent(r.confidence!)),
          ],
        ),
      ),
    );
  }
}
