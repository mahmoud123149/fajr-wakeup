import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/ar_strings.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../core/widgets/app_widgets.dart';

class AdhanSettingsScreen extends StatefulWidget {
  const AdhanSettingsScreen({super.key});

  @override
  State<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends State<AdhanSettingsScreen> {
  final AudioPlayer _preview = AudioPlayer();
  late int _interval;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _interval = context.read<AppState>().settings.repeatIntervalSeconds;
  }

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  Future<void> _import(AppState app) async {
    setState(() => _importing = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        withData: false,
      );
      final picked = result?.files.single;
      if (picked?.path == null) return;

      // Copy into app-private storage so playback never depends on an external URI.
      final docs = await getApplicationDocumentsDirectory();
      final ext = p.extension(picked!.name).isEmpty ? '.mp3' : p.extension(picked.name);
      final dest = File(p.join(docs.path, 'adhan$ext'));
      await File(picked.path!).copy(dest.path);

      await app.setAdhanFile(path: dest.path, name: picked.name);
      if (!mounted) return;
      _snack(S.adhanImported);
    } catch (_) {
      if (!mounted) return;
      _snack(S.locationFailed);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _togglePreview(AppState app) async {
    final path = app.settings.adhanFilePath;
    if (path == null) {
      _snack(S.defaultAdhan);
      return;
    }
    if (_preview.playing) {
      await _preview.stop();
      setState(() {});
      return;
    }
    try {
      await _preview.setFilePath(path);
      await _preview.play();
      setState(() {});
    } catch (_) {
      _snack(S.locationFailed);
    }
  }

  Future<void> _saveInterval(AppState app) async {
    await app.updateSettings(app.settings.copyWith(repeatIntervalSeconds: _interval));
    if (!mounted) return;
    _snack(S.saved);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final s = app.settings;

    return Scaffold(
      appBar: AppBar(title: const Text(S.adhanSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: S.currentAdhan,
            icon: Icons.audiotrack,
            children: [
              LabeledValue(
                label: S.currentAdhan,
                value: s.adhanFileName ?? S.defaultAdhan,
              ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _importing ? null : () => _import(app),
                icon: _importing
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.file_upload),
                label: const Text(S.importAdhan),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _togglePreview(app),
                      icon: Icon(_preview.playing ? Icons.stop : Icons.play_arrow),
                      label: Text(_preview.playing ? S.stopPreview : S.previewAudio),
                    ),
                  ),
                  if (s.adhanFilePath != null) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () => app.removeAdhanFile(),
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      tooltip: S.removeAdhan,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              const Text(S.adhanCopyright,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            ],
          ),
          SectionCard(
            title: S.repeatInterval,
            icon: Icons.repeat,
            children: [
              Row(
                children: [
                  Text(Fmt.toArabicDigits('$_interval ${S.seconds}'),
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _interval.clamp(0, 120).toDouble(),
                      min: 0,
                      max: 120,
                      divisions: 24,
                      label: '$_interval',
                      onChanged: (v) => setState(() => _interval = v.round()),
                      onChangeEnd: (_) => _saveInterval(app),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SectionCard(
            title: S.testAlarm,
            icon: Icons.alarm_on,
            children: [
              const Text(S.volumeNote,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () async {
                  await app.scheduleTestAlarm();
                  if (!context.mounted) return;
                  _snack(S.testAlarmScheduled);
                },
                icon: const Icon(Icons.play_circle),
                label: const Text(S.testAlarm),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
