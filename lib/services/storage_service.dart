import 'package:hive_flutter/hive_flutter.dart';

import '../models/lesson_record.dart';
import '../models/schedule_item.dart';
import '../models/teacher_class.dart';

class StorageService {
  StorageService._();

  static const classesBoxName = 'teacher_classes';
  static const scheduleBoxName = 'schedule_items';
  static const lessonsBoxName = 'lesson_records';
  static const settingsBoxName = 'settings';

  static late Box<TeacherClass> classesBox;
  static late Box<ScheduleItem> scheduleBox;
  static late Box<LessonRecord> lessonsBox;
  static late Box settingsBox;

  static Future<void> init({String? testPath}) async {
    if (testPath == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(testPath);
    }

    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(TeacherClassAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(ScheduleItemAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(LessonRecordAdapter());
    }

    classesBox = await Hive.openBox<TeacherClass>(classesBoxName);
    scheduleBox = await Hive.openBox<ScheduleItem>(scheduleBoxName);
    lessonsBox = await Hive.openBox<LessonRecord>(lessonsBoxName);
    settingsBox = await Hive.openBox(settingsBoxName);
  }

  static Future<void> clearAll() async {
    await classesBox.clear();
    await scheduleBox.clear();
    await lessonsBox.clear();
    await settingsBox.clear();
  }
}
