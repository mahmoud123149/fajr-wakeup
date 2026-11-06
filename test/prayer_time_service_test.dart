import 'package:fajr_wakeup/core/services/prayer_time_service.dart';
import 'package:fajr_wakeup/data/models/calc_method.dart';
import 'package:flutter_test/flutter_test.dart';

/// These assertions are deliberately timezone-invariant (they compare absolute
/// instants), so they pass regardless of the machine's local timezone.
void main() {
  final svc = PrayerTimeService();

  // Mecca.
  const lat = 21.4225;
  const lng = 39.8262;

  DateTime fajr(DateTime date, {int adj = 0, CalcMethod method = CalcMethod.ummAlQura}) =>
      svc.fajrFor(
        latitude: lat,
        longitude: lng,
        method: method,
        madhab: MadhabPref.shafi,
        adjustmentMinutes: adj,
        date: date,
      );

  test('manual adjustment shifts Fajr by exactly the given minutes', () {
    final base = fajr(DateTime(2026, 1, 15));
    final plus10 = fajr(DateTime(2026, 1, 15), adj: 10);
    final minus5 = fajr(DateTime(2026, 1, 15), adj: -5);
    expect(plus10.difference(base).inMinutes, 10);
    expect(minus5.difference(base).inMinutes, -5);
  });

  test('consecutive days are roughly 24h apart', () {
    final d1 = fajr(DateTime(2026, 1, 15));
    final d2 = fajr(DateTime(2026, 1, 16));
    final diff = d2.difference(d1).inMinutes;
    expect(diff, inInclusiveRange(23 * 60, 25 * 60));
  });

  test('different calculation methods give different Fajr instants', () {
    final mwl = fajr(DateTime(2026, 1, 15), method: CalcMethod.muslimWorldLeague);
    final uaq = fajr(DateTime(2026, 1, 15), method: CalcMethod.ummAlQura);
    expect(mwl.millisecondsSinceEpoch == uaq.millisecondsSinceEpoch, isFalse);
  });

  test('nextFajr is strictly in the future', () {
    final from = DateTime(2026, 1, 15, 10, 0);
    final next = svc.nextFajr(
      latitude: lat,
      longitude: lng,
      method: CalcMethod.ummAlQura,
      madhab: MadhabPref.shafi,
      adjustmentMinutes: 0,
      from: from,
    );
    expect(next.isAfter(from), isTrue);
  });

  test('upcoming returns N strictly increasing future instants', () {
    final from = DateTime(2026, 1, 15, 10, 0);
    final list = svc.upcoming(
      latitude: lat,
      longitude: lng,
      method: CalcMethod.ummAlQura,
      madhab: MadhabPref.shafi,
      adjustmentMinutes: 0,
      days: 14,
      from: from,
    );
    expect(list.length, 14);
    expect(list.first.isAfter(from), isTrue);
    for (var i = 1; i < list.length; i++) {
      expect(list[i].isAfter(list[i - 1]), isTrue);
    }
  });
}
