import 'dart:math';

const arabicWeekDays = <int, String>{
  DateTime.saturday: 'السبت',
  DateTime.sunday: 'الأحد',
  DateTime.monday: 'الاثنين',
  DateTime.tuesday: 'الثلاثاء',
  DateTime.wednesday: 'الأربعاء',
  DateTime.thursday: 'الخميس',
  DateTime.friday: 'الجمعة',
};

const englishWeekDays = <int, String>{
  DateTime.saturday: 'Saturday',
  DateTime.sunday: 'Sunday',
  DateTime.monday: 'Monday',
  DateTime.tuesday: 'Tuesday',
  DateTime.wednesday: 'Wednesday',
  DateTime.thursday: 'Thursday',
  DateTime.friday: 'Friday',
};

const orderedWeekDays = <int>[
  DateTime.sunday,
  DateTime.monday,
  DateTime.tuesday,
  DateTime.wednesday,
  DateTime.thursday,
  DateTime.friday,
  DateTime.saturday,
];

String arabicDayName(int dayOfWeek) => arabicWeekDays[dayOfWeek] ?? '';

String localizedDayName(int dayOfWeek, String languageCode) {
  if (languageCode == 'en') return englishWeekDays[dayOfWeek] ?? '';
  return arabicDayName(dayOfWeek);
}

String formatArabicDate(DateTime date) {
  final dayName = arabicDayName(date.weekday);
  return '$dayName ${date.day}/${date.month}/${date.year}';
}

String formatLocalizedDate(DateTime date, String languageCode) {
  final dayName = localizedDayName(date.weekday, languageCode);
  return '$dayName ${date.day}/${date.month}/${date.year}';
}

final _uuidRandom = Random.secure();

String newId() {
  final bytes = List<int>.generate(16, (_) => _uuidRandom.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex =
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20)}';
}

bool isUuid(String value) {
  return RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    caseSensitive: false,
  ).hasMatch(value);
}
