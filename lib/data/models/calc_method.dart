/// Prayer calculation method, decoupled from the `adhan` package enum so it can
/// be stored and shown in the UI. Mapping to the library lives in
/// PrayerTimeService._toParams.
enum CalcMethod {
  muslimWorldLeague('muslim_world_league', 'رابطة العالم الإسلامي'),
  egyptian('egyptian', 'الهيئة المصرية العامة للمساحة'),
  karachi('karachi', 'جامعة العلوم الإسلامية - كراتشي'),
  ummAlQura('umm_al_qura', 'أم القرى - مكة المكرمة'),
  dubai('dubai', 'دبي'),
  qatar('qatar', 'قطر'),
  kuwait('kuwait', 'الكويت'),
  moonsightingCommittee('moonsighting_committee', 'لجنة رؤية الهلال'),
  singapore('singapore', 'سنغافورة'),
  northAmerica('north_america', 'أمريكا الشمالية (ISNA)'),
  turkey('turkey', 'تركيا (ديانت)'),
  tehran('tehran', 'طهران'),
  other('other', 'أخرى / مخصّص');

  const CalcMethod(this.key, this.arabicName);

  final String key;
  final String arabicName;

  static CalcMethod fromKey(String? key) => CalcMethod.values.firstWhere(
        (m) => m.key == key,
        orElse: () => CalcMethod.muslimWorldLeague,
      );
}

/// Asr calculation school; affects nothing for Fajr itself but is part of the
/// calculation parameters and is kept for completeness.
enum MadhabPref {
  shafi('shafi', 'شافعي / مالكي / حنبلي'),
  hanafi('hanafi', 'حنفي');

  const MadhabPref(this.key, this.arabicName);

  final String key;
  final String arabicName;

  static MadhabPref fromKey(String? key) => MadhabPref.values.firstWhere(
        (m) => m.key == key,
        orElse: () => MadhabPref.shafi,
      );
}
