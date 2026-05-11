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
    this.teacherId,
  });

  final String id;
  final String classId;
  final String lessonTitle;
  final SessionType sessionType;
  final String notes;
  final LessonStatus status;
  final DateTime date;
  final DateTime createdAt;
  final String? teacherId;

  LessonRecord copyWith({
    String? id,
    String? classId,
    String? lessonTitle,
    SessionType? sessionType,
    String? notes,
    LessonStatus? status,
    DateTime? date,
    DateTime? createdAt,
    String? teacherId,
  }) {
    return LessonRecord(
      id: id ?? this.id,
      classId: classId ?? this.classId,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      sessionType: sessionType ?? this.sessionType,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
      teacherId: teacherId ?? this.teacherId,
    );
  }
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
      teacherId: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LessonRecord obj) {
    writer
      ..writeByte(9)
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
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.teacherId);
  }
}
