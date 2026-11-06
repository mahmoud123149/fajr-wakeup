import 'calc_method.dart';

/// All persisted user configuration. Serialised as a single JSON row in the
/// `settings` table (key = 'app_settings').
class AppSettings {
  const AppSettings({
    this.latitude,
    this.longitude,
    this.locationName = '',
    this.useDeviceLocation = true,
    this.calcMethod = CalcMethod.muslimWorldLeague,
    this.madhab = MadhabPref.shafi,
    this.fajrAdjustmentMinutes = 0,
    this.repeatIntervalSeconds = 20,
    this.adhanFilePath,
    this.adhanFileName,
    this.confidenceThreshold = 0.70,
    this.saveDiagnosticImages = false,
    this.scheduleBufferDays = 14,
  });

  final double? latitude;
  final double? longitude;
  final String locationName;
  final bool useDeviceLocation;

  final CalcMethod calcMethod;
  final MadhabPref madhab;

  /// Manual Fajr adjustment in minutes (may be negative).
  final int fajrAdjustmentMinutes;

  /// Gap (seconds) after a complete Adhan before it repeats.
  final int repeatIntervalSeconds;

  /// Imported Adhan audio copied into app-private storage (null => device alarm tone).
  final String? adhanFilePath;
  final String? adhanFileName;

  /// AI acceptance threshold. PLACEHOLDER (0.80) until set from model evaluation.
  final double confidenceThreshold;

  /// Keep challenge photos for debugging (off by default; images are deleted).
  final bool saveDiagnosticImages;

  /// How many days of Fajr triggers to precompute and hand to the native scheduler.
  final int scheduleBufferDays;

  bool get hasLocation => latitude != null && longitude != null;

  AppSettings copyWith({
    double? latitude,
    double? longitude,
    String? locationName,
    bool? useDeviceLocation,
    CalcMethod? calcMethod,
    MadhabPref? madhab,
    int? fajrAdjustmentMinutes,
    int? repeatIntervalSeconds,
    Object? adhanFilePath = _unset,
    Object? adhanFileName = _unset,
    double? confidenceThreshold,
    bool? saveDiagnosticImages,
    int? scheduleBufferDays,
  }) {
    return AppSettings(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      useDeviceLocation: useDeviceLocation ?? this.useDeviceLocation,
      calcMethod: calcMethod ?? this.calcMethod,
      madhab: madhab ?? this.madhab,
      fajrAdjustmentMinutes: fajrAdjustmentMinutes ?? this.fajrAdjustmentMinutes,
      repeatIntervalSeconds: repeatIntervalSeconds ?? this.repeatIntervalSeconds,
      adhanFilePath:
          adhanFilePath == _unset ? this.adhanFilePath : adhanFilePath as String?,
      adhanFileName:
          adhanFileName == _unset ? this.adhanFileName : adhanFileName as String?,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      saveDiagnosticImages: saveDiagnosticImages ?? this.saveDiagnosticImages,
      scheduleBufferDays: scheduleBufferDays ?? this.scheduleBufferDays,
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'locationName': locationName,
        'useDeviceLocation': useDeviceLocation,
        'calcMethod': calcMethod.key,
        'madhab': madhab.key,
        'fajrAdjustmentMinutes': fajrAdjustmentMinutes,
        'repeatIntervalSeconds': repeatIntervalSeconds,
        'adhanFilePath': adhanFilePath,
        'adhanFileName': adhanFileName,
        'confidenceThreshold': confidenceThreshold,
        'saveDiagnosticImages': saveDiagnosticImages,
        'scheduleBufferDays': scheduleBufferDays,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        locationName: json['locationName'] as String? ?? '',
        useDeviceLocation: json['useDeviceLocation'] as bool? ?? true,
        calcMethod: CalcMethod.fromKey(json['calcMethod'] as String?),
        madhab: MadhabPref.fromKey(json['madhab'] as String?),
        fajrAdjustmentMinutes: (json['fajrAdjustmentMinutes'] as num?)?.toInt() ?? 0,
        repeatIntervalSeconds: (json['repeatIntervalSeconds'] as num?)?.toInt() ?? 20,
        adhanFilePath: json['adhanFilePath'] as String?,
        adhanFileName: json['adhanFileName'] as String?,
        confidenceThreshold:
            (json['confidenceThreshold'] as num?)?.toDouble() ?? 0.70,
        saveDiagnosticImages: json['saveDiagnosticImages'] as bool? ?? false,
        scheduleBufferDays: (json['scheduleBufferDays'] as num?)?.toInt() ?? 14,
      );

  static const _unset = Object();
}
