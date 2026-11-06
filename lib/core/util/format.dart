import 'package:intl/intl.dart';

/// Arabic-locale formatting helpers.
class Fmt {
  static final _clock = DateFormat('h:mm a', 'ar');
  static final _fullDate = DateFormat('EEEE، d MMMM', 'ar');
  static final _dateTime = DateFormat('d/M، h:mm a', 'ar');

  static String clock(DateTime dt) => _clock.format(dt);

  static String fullDate(DateTime dt) => _fullDate.format(dt);

  static String dateTime(DateTime dt) => _dateTime.format(dt);

  /// HH:MM:SS countdown with Arabic-Indic digits.
  static String countdown(Duration d) {
    if (d.isNegative) d = Duration.zero;
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return toArabicDigits('$h:$m:$s');
  }

  /// Short human duration, e.g. "٢ د ١٥ ث".
  static String durationShort(Duration? d) {
    if (d == null) return '—';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    if (m <= 0) return toArabicDigits('$s ث');
    return toArabicDigits('$m د $s ث');
  }

  static String percent(double v) =>
      toArabicDigits('${(v * 100).toStringAsFixed(0)}%');

  static String toArabicDigits(String input) {
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var out = input;
    for (var i = 0; i < western.length; i++) {
      out = out.replaceAll(western[i], arabic[i]);
    }
    return out;
  }
}
