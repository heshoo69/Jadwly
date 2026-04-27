import 'package:hive/hive.dart';

import 'lesson_status.dart';
import 'session_type.dart';

class LessonRecord {
  const LessonRecord({
    required this.id,
    required this.classId,
    required this.lessonTitle,
    required this.sessionType,
    required this.notes,
    required this.status,
    required this.date,
    required this.createdAt,
  });

  final String id;
  final String classId;
  final String lessonTitle;
  final SessionType sessionType;
  final String notes;
  final LessonStatus status;
  final DateTime date;
  final DateTime createdAt;
}

class LessonRecordAdapter extends TypeAdapter<LessonRecord> {
  @override
  final int typeId = 3;

  @override
  LessonRecord read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final count = reader.readByte();
    for (var i = 0; i < count; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return LessonRecord(
      id: fields[0] as String,
      classId: fields[1] as String,
      lessonTitle: fields[2] as String,
      sessionType: sessionTypeFromName(fields[3] as String),
      notes: fields[4] as String,
      status: lessonStatusFromName(fields[5] as String),
      date: fields[6] as DateTime,
      createdAt: fields[7] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, LessonRecord obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.classId)
      ..writeByte(2)
      ..write(obj.lessonTitle)
      ..writeByte(3)
      ..write(obj.sessionType.name)
      ..writeByte(4)
      ..write(obj.notes)
      ..writeByte(5)
      ..write(obj.status.name)
      ..writeByte(6)
      ..write(obj.date)
      ..writeByte(7)
      ..write(obj.createdAt);
  }
}
