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

String newId() => DateTime.now().microsecondsSinceEpoch.toString();
