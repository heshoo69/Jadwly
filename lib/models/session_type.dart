enum SessionType {
  theoretical,
  practical,
  review,
  exam,
}

extension SessionTypeLabels on SessionType {
  String label(String languageCode) {
    if (languageCode == 'en') {
      switch (this) {
        case SessionType.theoretical:
          return 'Theoretical';
        case SessionType.practical:
          return 'Practical';
        case SessionType.review:
          return 'Review';
        case SessionType.exam:
          return 'Exam';
      }
    }
    return arabicLabel;
  }

  String get arabicLabel {
    switch (this) {
      case SessionType.theoretical:
        return 'نظري';
      case SessionType.practical:
        return 'عملي';
      case SessionType.review:
        return 'مراجعة';
      case SessionType.exam:
        return 'اختبار';
    }
  }
}

SessionType sessionTypeFromName(String name) {
  return SessionType.values.firstWhere(
    (type) => type.name == name,
    orElse: () => SessionType.theoretical,
  );
}
