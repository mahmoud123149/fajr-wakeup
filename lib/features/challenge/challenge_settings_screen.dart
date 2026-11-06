import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/ar_strings.dart';
import '../../core/platform/alarm_bridge.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../core/widgets/app_widgets.dart';

class ChallengeSettingsScreen extends StatefulWidget {
  const ChallengeSettingsScreen({super.key});

  @override
  State<ChallengeSettingsScreen> createState() => _ChallengeSettingsScreenState();
}

class _ChallengeSettingsScreenState extends State<ChallengeSettingsScreen> {
  late double _threshold;
  late bool _saveDiag;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _threshold = s.confidenceThreshold;
    _saveDiag = s.saveDiagnosticImages;
  }

  Future<void> _persist(AppState app) async {
    await app.updateSettings(app.settings.copyWith(
      confidenceThreshold: _threshold,
      saveDiagnosticImages: _saveDiag,
    ));
    await app.refresh();
  }

  (String, Color) _stateLabel(LabelerState state) => switch (state) {
        LabelerState.ready => (S.modelReady, AppColors.success),
        LabelerState.error => (S.modelError, AppColors.error),
        LabelerState.unknown => ('—', AppColors.textSecondary),
      };

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final info = app.labelerInfo;
    final (stateText, stateColor) = _stateLabel(info.state);

    return Scaffold(
      appBar: AppBar(title: const Text(S.challengeSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: S.modelStatus,
            icon: Icons.memory,
            children: [
              LabeledValue(label: S.modelStatus, value: stateText, valueColor: stateColor),
              if (info.detail != null)
                LabeledValue(label: 'تفاصيل', value: info.detail!),
              const SizedBox(height: 8),
              const Text(S.modelAbout,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          SectionCard(
            title: S.confidenceThreshold,
            icon: Icons.speed,
            children: [
              Row(
                children: [
                  Text(Fmt.percent(_threshold),
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _threshold.clamp(0.5, 0.99).toDouble(),
                      min: 0.5,
                      max: 0.99,
                      divisions: 49,
                      label: Fmt.percent(_threshold),
                      onChanged: (v) => setState(() => _threshold = v),
                      onChangeEnd: (_) => _persist(app),
                    ),
                  ),
                ],
              ),
              const Text(S.confidenceNote,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          SectionCard(
            title: S.testRecognition,
            icon: Icons.camera_alt,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(S.saveDiagnostics),
                subtitle: const Text(S.diagnosticsNote,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                value: _saveDiag,
                onChanged: (v) {
                  setState(() => _saveDiag = v);
                  _persist(app);
                },
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: () => app.testRecognition(),
                icon: const Icon(Icons.center_focus_strong),
                label: const Text(S.testRecognition),
              ),
            ],
          ),
          const SectionCard(
            title: 'ملاحظة',
            icon: Icons.info_outline,
            children: [
              Text(S.recognitionHonesty,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }
}
