import 'package:hive/hive.dart';

class TeacherClass {
  const TeacherClass({
    required this.id,
    required this.className,
    required this.subject,
    this.roomNumber,
    required this.createdAt,
  });

  final String id;
  final String className;
  final String subject;
  final String? roomNumber;
  final DateTime createdAt;

  TeacherClass copyWith({
    String? id,
    String? className,
    String? subject,
    String? roomNumber,
    DateTime? createdAt,
  }) {
    return TeacherClass(
      id: id ?? this.id,
      className: className ?? this.className,
      subject: subject ?? this.subject,
      roomNumber: roomNumber ?? this.roomNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class TeacherClassAdapter extends TypeAdapter<TeacherClass> {
  @override
  final int typeId = 1;

  @override
  TeacherClass read(BinaryReader reader) {
    final fields = <int, dynamic>{};
    final count = reader.readByte();
    for (var i = 0; i < count; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return TeacherClass(
      id: fields[0] as String,
      className: fields[1] as String,
      subject: fields[2] as String,
      roomNumber: fields[3] as String?,
      createdAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, TeacherClass obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.className)
      ..writeByte(2)
      ..write(obj.subject)
      ..writeByte(3)
      ..write(obj.roomNumber)
      ..writeByte(4)
      ..write(obj.createdAt);
  }
}
