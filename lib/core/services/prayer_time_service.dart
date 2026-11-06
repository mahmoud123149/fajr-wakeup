import 'package:adhan/adhan.dart' as adhan;

import '../../data/models/app_settings.dart';
import '../../data/models/calc_method.dart';

/// Pure, offline Fajr calculation built on the `adhan` package.
///
/// Prayer times are astronomical *instants*; their absolute value
/// (millisecondsSinceEpoch) is independent of timezone/DST, which is what the
/// native scheduler uses. We build each day's date with DateTime(y, m, d + i) so
/// calendar rollover stays correct across DST boundaries.
class PrayerTimeService {
  /// Fajr for the local calendar [date].
  DateTime fajrFor({
    required double latitude,
    required double longitude,
    required CalcMethod method,
    required MadhabPref madhab,
    required int adjustmentMinutes,
    required DateTime date,
  }) {
    final coords = adhan.Coordinates(latitude, longitude);
    final params = _toParams(method)
      ..madhab = madhab == MadhabPref.hanafi ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    params.adjustments.fajr = adjustmentMinutes;

    final dc = adhan.DateComponents.from(date);
    final times = adhan.PrayerTimes(coords, dc, params);
    return times.fajr;
  }

  /// The next Fajr strictly after [from] (defaults to now).
  DateTime nextFajr({
    required double latitude,
    required double longitude,
    required CalcMethod method,
    required MadhabPref madhab,
    required int adjustmentMinutes,
    DateTime? from,
  }) {
    final now = from ?? DateTime.now();
    final today = fajrFor(
      latitude: latitude,
      longitude: longitude,
      method: method,
      madhab: madhab,
      adjustmentMinutes: adjustmentMinutes,
      date: now,
    );
    if (today.isAfter(now)) return today;
    return fajrFor(
      latitude: latitude,
      longitude: longitude,
      method: method,
      madhab: madhab,
      adjustmentMinutes: adjustmentMinutes,
      date: DateTime(now.year, now.month, now.day + 1),
    );
  }

  /// A rolling buffer of the next [days] Fajr instants strictly after [from].
  List<DateTime> upcoming({
    required double latitude,
    required double longitude,
    required CalcMethod method,
    required MadhabPref madhab,
    required int adjustmentMinutes,
    required int days,
    DateTime? from,
  }) {
    final now = from ?? DateTime.now();
    final result = <DateTime>[];
    var i = 0;
    // Scan a couple of extra days in case today's Fajr already passed.
    while (result.length < days && i < days + 2) {
      final f = fajrFor(
        latitude: latitude,
        longitude: longitude,
        method: method,
        madhab: madhab,
        adjustmentMinutes: adjustmentMinutes,
        date: DateTime(now.year, now.month, now.day + i),
      );
      if (f.isAfter(now)) result.add(f);
      i++;
    }
    return result;
  }

  // Convenience overloads taking AppSettings (location must be present).
  DateTime? nextFajrFromSettings(AppSettings s, {DateTime? from}) {
    if (!s.hasLocation) return null;
    return nextFajr(
      latitude: s.latitude!,
      longitude: s.longitude!,
      method: s.calcMethod,
      madhab: s.madhab,
      adjustmentMinutes: s.fajrAdjustmentMinutes,
      from: from,
    );
  }

  List<DateTime> upcomingFromSettings(AppSettings s, {DateTime? from}) {
    if (!s.hasLocation) return const [];
    return upcoming(
      latitude: s.latitude!,
      longitude: s.longitude!,
      method: s.calcMethod,
      madhab: s.madhab,
      adjustmentMinutes: s.fajrAdjustmentMinutes,
      days: s.scheduleBufferDays,
      from: from,
    );
  }

  adhan.CalculationParameters _toParams(CalcMethod m) {
    switch (m) {
      case CalcMethod.muslimWorldLeague:
        return adhan.CalculationMethod.muslim_world_league.getParameters();
      case CalcMethod.egyptian:
        return adhan.CalculationMethod.egyptian.getParameters();
      case CalcMethod.karachi:
        return adhan.CalculationMethod.karachi.getParameters();
      case CalcMethod.ummAlQura:
        return adhan.CalculationMethod.umm_al_qura.getParameters();
      case CalcMethod.dubai:
        return adhan.CalculationMethod.dubai.getParameters();
      case CalcMethod.qatar:
        return adhan.CalculationMethod.qatar.getParameters();
      case CalcMethod.kuwait:
        return adhan.CalculationMethod.kuwait.getParameters();
      case CalcMethod.moonsightingCommittee:
        return adhan.CalculationMethod.moon_sighting_committee.getParameters();
      case CalcMethod.singapore:
        return adhan.CalculationMethod.singapore.getParameters();
      case CalcMethod.northAmerica:
        return adhan.CalculationMethod.north_america.getParameters();
      case CalcMethod.turkey:
        return adhan.CalculationMethod.turkey.getParameters();
      case CalcMethod.tehran:
        return adhan.CalculationMethod.tehran.getParameters();
      case CalcMethod.other:
        return adhan.CalculationMethod.other.getParameters();
    }
  }
}
