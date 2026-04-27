import 'package:hive/hive.dart';

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.dayOfWeek,
    required this.periodNumber,
    required this.startTime,
    required this.endTime,
    required this.subject,
    required this.classId,
    this.roomNumber,
  });

  final String id;
  final int dayOfWeek;
  final int periodNumber;
  final String startTime;
  final String endTime;
  final String subject;
  final String classId;
  final String? roomNumber;

  ScheduleItem copyWith({
    String? id,
    int? dayOfWeek,
    int? periodNumber,
    String? startTime,
    String? endTime,
    String? subject,
    String? classId,
    String? roomNumber,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      periodNumber: periodNumber ?? this.periodNumber,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      subject: subject ?? this.subject,
      classId: classId ?? this.classId,
      roomNumber: roomNumber ?? this.roomNumber,
    );
  }
}

class ScheduleItemAdapter extends TypeAdapter<ScheduleItem> {
  @override
  final int typeId = 2;

  @override
  ScheduleItem read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final count = reader.readByte();
    for (var i = 0; i < count; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return ScheduleItem(
      id: fields[0] as String,
      dayOfWeek: fields[1] as int,
      periodNumber: fields[2] as int,
      startTime: fields[3] as String,
      endTime: fields[4] as String,
      subject: fields[5] as String,
      classId: fields[6] as String,
      roomNumber: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleItem obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dayOfWeek)
      ..writeByte(2)
      ..write(obj.periodNumber)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.endTime)
      ..writeByte(5)
      ..write(obj.subject)
      ..writeByte(6)
      ..write(obj.classId)
      ..writeByte(7)
      ..write(obj.roomNumber);
  }
}
