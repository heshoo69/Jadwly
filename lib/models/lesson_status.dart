enum LessonStatus {
  completed,
  needsContinuation,
}

extension LessonStatusLabels on LessonStatus {
  String label(String languageCode) {
    if (languageCode == 'en') {
      switch (this) {
        case LessonStatus.completed:
          return 'Completed';
        case LessonStatus.needsContinuation:
          return 'Needs continuation';
      }
    }
    return arabicLabel;
  }

  String get arabicLabel {
    switch (this) {
      case LessonStatus.completed:
        return 'مكتمل';
      case LessonStatus.needsContinuation:
        return 'يحتاج استكمال';
    }
  }
}

LessonStatus lessonStatusFromName(String name) {
  return LessonStatus.values.firstWhere(
    (status) => status.name == name,
    orElse: () => LessonStatus.completed,
  );
}
