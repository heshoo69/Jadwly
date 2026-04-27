class ClockTime {
  const ClockTime({
    required this.hour,
    required this.minute,
  });

  final int hour;
  final int minute;
}

ClockTime? parseClockTime(String value) {
  final match = RegExp(
    r'^\s*(\d{1,2}):(\d{2})\s*([ap]m)?\s*$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) return null;

  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  final period = match.group(3)?.toUpperCase();
  if (hour == null || minute == null) return null;
  if (minute < 0 || minute > 59) return null;

  if (period != null) {
    if (hour < 1 || hour > 12) return null;
    if (period == 'AM') {
      hour = hour == 12 ? 0 : hour;
    } else {
      hour = hour == 12 ? 12 : hour + 12;
    }
  } else if (hour < 0 || hour > 23) {
    return null;
  }

  return ClockTime(hour: hour, minute: minute);
}

String formatClockTimeAmPm(int hour, int minute) {
  final period = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '${displayHour.toString().padLeft(2, '0')}:'
      '${minute.toString().padLeft(2, '0')} $period';
}

String normalizeClockTimeAmPm(String value) {
  final parsed = parseClockTime(value);
  if (parsed == null) return value;
  return formatClockTimeAmPm(parsed.hour, parsed.minute);
}

int minutesSinceMidnight(String value) {
  final parsed = parseClockTime(value);
  if (parsed == null) return 24 * 60;
  return parsed.hour * 60 + parsed.minute;
}
