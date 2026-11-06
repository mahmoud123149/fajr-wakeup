import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/ar_strings.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/app_theme.dart';
import '../../core/util/format.dart';
import '../../core/widgets/app_widgets.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/calc_method.dart';

class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  late TextEditingController _lat;
  late TextEditingController _lng;
  late CalcMethod _method;
  late MadhabPref _madhab;
  late int _adjustment;
  late bool _useDevice;
  bool _detecting = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppState>().settings;
    _lat = TextEditingController(text: s.latitude?.toString() ?? '');
    _lng = TextEditingController(text: s.longitude?.toString() ?? '');
    _method = s.calcMethod;
    _madhab = s.madhab;
    _adjustment = s.fajrAdjustmentMinutes;
    _useDevice = s.useDeviceLocation;
  }

  @override
  void dispose() {
    _lat.dispose();
    _lng.dispose();
    super.dispose();
  }

  AppSettings _formToSettings(AppSettings base) {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    return base.copyWith(
      latitude: lat,
      longitude: lng,
      useDeviceLocation: _useDevice,
      calcMethod: _method,
      madhab: _madhab,
      fajrAdjustmentMinutes: _adjustment,
      locationName: lat != null && lng != null
          ? '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}'
          : base.locationName,
    );
  }

  DateTime? _previewFajr(AppState app, {int addDays = 0}) {
    final lat = double.tryParse(_lat.text.trim());
    final lng = double.tryParse(_lng.text.trim());
    if (lat == null || lng == null) return null;
    final now = DateTime.now();
    return app.prayer.fajrFor(
      latitude: lat,
      longitude: lng,
      method: _method,
      madhab: _madhab,
      adjustmentMinutes: _adjustment,
      date: DateTime(now.year, now.month, now.day + addDays),
    );
  }

  Future<void> _detect(AppState app) async {
    setState(() => _detecting = true);
    final ok = await app.detectLocation();
    setState(() {
      _detecting = false;
      if (ok) {
        _lat.text = app.settings.latitude?.toString() ?? _lat.text;
        _lng.text = app.settings.longitude?.toString() ?? _lng.text;
      }
    });
    if (!mounted) return;
    _snack(ok ? S.locationDetected : S.locationFailed);
  }

  Future<void> _save(AppState app) async {
    await app.updateSettings(_formToSettings(app.settings));
    if (!mounted) return;
    _snack(S.saved);
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final todayFajr = _previewFajr(app);
    final tomorrowFajr = _previewFajr(app, addDays: 1);

    return Scaffold(
      appBar: AppBar(title: const Text(S.prayerSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SectionCard(
            title: S.locationLabel,
            icon: Icons.location_on,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(S.useDeviceLocation),
                value: _useDevice,
                onChanged: (v) => setState(() => _useDevice = v),
              ),
              ElevatedButton.icon(
                onPressed: _detecting ? null : () => _detect(app),
                icon: _detecting
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.my_location),
                label: const Text(S.detectLocation),
              ),
              const SizedBox(height: 12),
              const Text(S.manualLocation, style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: _numField(_lat, S.latitude)),
                  const SizedBox(width: 12),
                  Expanded(child: _numField(_lng, S.longitude)),
                ],
              ),
            ],
          ),
          SectionCard(
            title: S.calcMethodLabel,
            icon: Icons.calculate,
            children: [
              _dropdown<CalcMethod>(
                value: _method,
                items: CalcMethod.values,
                labelOf: (m) => m.arabicName,
                onChanged: (m) => setState(() => _method = m),
              ),
              const SizedBox(height: 16),
              const Text(S.madhab, style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              _dropdown<MadhabPref>(
                value: _madhab,
                items: MadhabPref.values,
                labelOf: (m) => m.arabicName,
                onChanged: (m) => setState(() => _madhab = m),
              ),
            ],
          ),
          SectionCard(
            title: S.fajrAdjustment,
            icon: Icons.tune,
            children: [
              Row(
                children: [
                  Text(Fmt.toArabicDigits('$_adjustment ${S.minutes}'),
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Slider(
                      value: _adjustment.clamp(-30, 30).toDouble(),
                      min: -30,
                      max: 30,
                      divisions: 60,
                      label: '$_adjustment',
                      onChanged: (v) => setState(() => _adjustment = v.round()),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SectionCard(
            title: S.preview,
            icon: Icons.visibility,
            children: [
              LabeledValue(
                label: 'الفجر اليوم',
                value: todayFajr == null ? '—' : Fmt.clock(todayFajr),
              ),
              LabeledValue(
                label: 'الفجر غداً',
                value: tomorrowFajr == null ? '—' : Fmt.clock(tomorrowFajr),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ElevatedButton(onPressed: () => _save(app), child: const Text(S.save)),
        ],
      ),
    );
  }

  Widget _dropdown<T>({
    required T value,
    required List<T> items,
    required String Function(T) labelOf,
    required void Function(T) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.navySurfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          dropdownColor: AppColors.navySurfaceAlt,
          items: [
            for (final item in items)
              DropdownMenuItem<T>(value: item, child: Text(labelOf(item))),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }

  Widget _numField(TextEditingController c, String label) => TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9\.\-]'))],
        decoration: InputDecoration(labelText: label),
        onChanged: (_) => setState(() {}),
      );
}
