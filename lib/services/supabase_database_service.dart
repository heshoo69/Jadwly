import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/schedule_item.dart';
import '../models/session_type.dart';
import '../models/teacher_class.dart';

abstract class CloudDatabase {
  Future<String> currentUserId();
  Future<List<TeacherClass>> fetchTeacherClasses();
  Future<List<ScheduleItem>> fetchWeeklySchedule();
  Future<List<LessonRecord>> fetchLessonRecords();
  Future<Map<String, dynamic>?> fetchReminderSettings();
  Future<void> upsertTeacherClass(TeacherClass item, String cloudId);
  Future<void> deleteTeacherClass(String cloudId);
  Future<void> upsertScheduleItem(
    ScheduleItem item,
    String cloudId, {
    required String className,
  });
  Future<void> deleteScheduleItem(String cloudId);
  Future<void> upsertLessonRecord(
    LessonRecord record,
    String cloudId, {
    required String className,
    required String subject,
  });
  Future<void> deleteLessonRecord(String cloudId);
  Future<void> saveProfileName(String fullName);
  Future<void> saveReminderSettings({
    required bool notificationsEnabled,
    required int reminderMinutes,
  });
  Future<DateTime> scheduleCloudDataDeletion({
    Duration delay = const Duration(days: 7),
  });
  Future<void> cancelCloudDataDeletion();
  Future<void> deleteCloudDataForCurrentUser();
}

class SupabaseDatabaseService implements CloudDatabase {
  SupabaseDatabaseService({SupabaseClient? supabaseClient})
      : _client = supabaseClient ?? Supabase.instance.client;

  static const profilesTable = 'profiles';
  static const teacherClassesTable = 'teacher_classes';
  static const weeklyScheduleTable = 'weekly_schedule';
  static const lessonRecordsTable = 'lesson_records';
  static const reminderSettingsTable = 'reminder_settings';
  static const cloudDataDeletionRequestsTable = 'cloud_data_deletion_requests';

  final SupabaseClient _client;

  @override
  Future<String> currentUserId() async {
    final session = await ensureSessionReady();
    return session.user.id;
  }

  Future<Session> ensureSessionReady() async {
    final auth = _client.auth;
    var session = auth.currentSession;
    if (session == null) {
      throw const AuthException('Supabase session is missing.');
    }

    final expiresAt = session.expiresAt;
    final refreshAt =
        DateTime.now().add(const Duration(minutes: 1)).millisecondsSinceEpoch ~/
            1000;
    if (expiresAt == null || expiresAt > refreshAt) return session;

    try {
      final response =
          await auth.refreshSession().timeout(const Duration(seconds: 5));
      session = response.session;
      if (session == null) {
        throw const AuthException(
          'Supabase session refresh returned no session.',
        );
      }
      return session;
    } catch (error) {
      debugPrint('Supabase session refresh failed: $error');
      rethrow;
    }
  }

  @override
  Future<List<TeacherClass>> fetchTeacherClasses() async {
    final userId = await currentUserId();
    final rows = await _client
        .from(teacherClassesTable)
        .select()
        .eq('teacher_id', userId)
        .order('created_at')
        .timeout(const Duration(seconds: 8));

    return rows.map<TeacherClass>(_teacherClassFromRow).toList();
  }

  @override
  Future<List<ScheduleItem>> fetchWeeklySchedule() async {
    final userId = await currentUserId();
    final rows = await _client
        .from(weeklyScheduleTable)
        .select()
        .eq('teacher_id', userId)
        .order('day_of_week')
        .order('period_number')
        .timeout(const Duration(seconds: 8));

    return rows.map<ScheduleItem>(_scheduleItemFromRow).toList();
  }

  @override
  Future<List<LessonRecord>> fetchLessonRecords() async {
    final userId = await currentUserId();
    final rows = await _client
        .from(lessonRecordsTable)
        .select()
        .eq('teacher_id', userId)
        .order('lesson_date', ascending: false)
        .timeout(const Duration(seconds: 8));

    return rows.map<LessonRecord>(_lessonRecordFromRow).toList();
  }

  @override
  Future<Map<String, dynamic>?> fetchReminderSettings() async {
    final userId = await currentUserId();
    final row = await _client
        .from(reminderSettingsTable)
        .select()
        .eq('teacher_id', userId)
        .eq('reminder_type', 'before_class')
        .maybeSingle()
        .timeout(const Duration(seconds: 8));
    return row;
  }

  @override
  Future<void> upsertTeacherClass(TeacherClass item, String cloudId) async {
    final userId = await currentUserId();
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from(teacherClassesTable).upsert(
      {
        'id': cloudId,
        'teacher_id': userId,
        'class_name': item.className.trim(),
        'subject': item.subject.trim(),
        'room': item.roomNumber,
        'created_at': item.createdAt.toUtc().toIso8601String(),
        'updated_at': now,
      },
      onConflict: 'id',
    ).timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> deleteTeacherClass(String cloudId) async {
    final userId = await currentUserId();
    await _client
        .from(teacherClassesTable)
        .delete()
        .eq('id', cloudId)
        .eq('teacher_id', userId)
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> upsertScheduleItem(
    ScheduleItem item,
    String cloudId, {
    required String className,
  }) async {
    final userId = await currentUserId();
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from(weeklyScheduleTable).upsert(
      {
        'id': cloudId,
        'teacher_id': userId,
        'day_of_week': weekdayNumberToSupabase(item.dayOfWeek),
        'period_number': item.periodNumber,
        'start_time': _toPostgresTime(item.startTime),
        'end_time': _toPostgresTime(item.endTime),
        'class_name': className.trim().isEmpty ? item.classId : className,
        'subject': item.subject,
        'room': item.roomNumber,
        'is_active': true,
        'updated_at': now,
      },
      onConflict: 'id',
    ).timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> deleteScheduleItem(String cloudId) async {
    final userId = await currentUserId();
    await _client
        .from(weeklyScheduleTable)
        .delete()
        .eq('id', cloudId)
        .eq('teacher_id', userId)
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> upsertLessonRecord(
    LessonRecord record,
    String cloudId, {
    required String className,
    required String subject,
  }) async {
    final userId = await currentUserId();
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from(lessonRecordsTable).upsert(
      {
        'id': cloudId,
        'teacher_id': userId,
        'class_name': className.trim().isEmpty ? record.classId : className,
        'subject': subject,
        'lesson_title': record.lessonTitle,
        'lesson_type': record.sessionType.name,
        'lesson_date': _dateOnly(record.date),
        'notes': record.notes,
        'created_at': record.createdAt.toUtc().toIso8601String(),
        'updated_at': now,
      },
      onConflict: 'id',
    ).timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> deleteLessonRecord(String cloudId) async {
    final userId = await currentUserId();
    await _client
        .from(lessonRecordsTable)
        .delete()
        .eq('id', cloudId)
        .eq('teacher_id', userId)
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> saveProfileName(String fullName) async {
    final userId = await currentUserId();
    await _client.from(profilesTable).upsert(
      {
        'id': userId,
        'full_name': fullName.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'id',
    ).timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> saveReminderSettings({
    required bool notificationsEnabled,
    required int reminderMinutes,
  }) async {
    final userId = await currentUserId();
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from(reminderSettingsTable).upsert(
      {
        'id': userId,
        'teacher_id': userId,
        'reminder_type': 'before_class',
        'is_enabled': notificationsEnabled,
        'minutes_offset': reminderMinutes,
        'created_at': now,
        'updated_at': now,
      },
      onConflict: 'id',
    ).timeout(const Duration(seconds: 8));
  }

  @override
  Future<DateTime> scheduleCloudDataDeletion({
    Duration delay = const Duration(days: 7),
  }) async {
    final userId = await currentUserId();
    final now = DateTime.now().toUtc();
    final scheduledFor = now.add(delay);
    await _client.from(cloudDataDeletionRequestsTable).upsert(
      {
        'teacher_id': userId,
        'scheduled_for': scheduledFor.toIso8601String(),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      },
      onConflict: 'teacher_id',
    ).timeout(const Duration(seconds: 8));
    return scheduledFor;
  }

  @override
  Future<void> cancelCloudDataDeletion() async {
    final userId = await currentUserId();
    await _client
        .from(cloudDataDeletionRequestsTable)
        .delete()
        .eq('teacher_id', userId)
        .timeout(const Duration(seconds: 8));
  }

  @override
  Future<void> deleteCloudDataForCurrentUser() async {
    final userId = await currentUserId();
    for (final table in [
      weeklyScheduleTable,
      lessonRecordsTable,
      teacherClassesTable,
    ]) {
      await _client
          .from(table)
          .delete()
          .eq('teacher_id', userId)
          .timeout(const Duration(seconds: 8));
    }
    await cancelCloudDataDeletion();
  }

  static String weekdayNumberToSupabase(int day) {
    switch (day) {
      case DateTime.monday:
        return 'monday';
      case DateTime.tuesday:
        return 'tuesday';
      case DateTime.wednesday:
        return 'wednesday';
      case DateTime.thursday:
        return 'thursday';
      case DateTime.friday:
        return 'friday';
      case DateTime.saturday:
        return 'saturday';
      case DateTime.sunday:
        return 'sunday';
      default:
        throw ArgumentError('Invalid weekday number: $day');
    }
  }

  static int supabaseWeekdayToNumber(dynamic value) {
    switch (value.toString()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      default:
        throw ArgumentError('Invalid Supabase weekday: $value');
    }
  }

  static TeacherClass _teacherClassFromRow(Map<String, dynamic> row) {
    return TeacherClass(
      id: row['id'] as String,
      className: row['class_name'] as String? ?? '',
      subject: row['subject'] as String? ?? '',
      roomNumber: row['room'] as String?,
      createdAt: _parseDate(row['created_at']),
    );
  }

  static ScheduleItem _scheduleItemFromRow(Map<String, dynamic> row) {
    final className = row['class_name'] as String? ?? '';
    return ScheduleItem(
      id: row['id'] as String,
      dayOfWeek: supabaseWeekdayToNumber(row['day_of_week']),
      periodNumber: row['period_number'] as int? ?? 0,
      startTime: _fromPostgresTime(row['start_time']),
      endTime: _fromPostgresTime(row['end_time']),
      subject: row['subject'] as String? ?? '',
      classId: className,
      roomNumber: row['room'] as String?,
    );
  }

  static LessonRecord _lessonRecordFromRow(Map<String, dynamic> row) {
    return LessonRecord(
      id: row['id'] as String,
      classId: row['class_name'] as String? ?? '',
      lessonTitle: row['lesson_title'] as String? ?? '',
      sessionType: sessionTypeFromName(row['lesson_type'] as String? ?? ''),
      notes: row['notes'] as String? ?? '',
      status: LessonStatus.completed,
      date: _parseDate(row['lesson_date']),
      createdAt: _parseDate(row['created_at']),
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value is DateTime) return value;
    if (value is String && value.isNotEmpty) return DateTime.parse(value);
    return DateTime.now();
  }

  static String _dateOnly(DateTime date) {
    return date.toIso8601String().split('T').first;
  }

  static String _toPostgresTime(String value) {
    final text = value.trim();
    final amPmMatch = RegExp(
      r'^(\d{1,2}):(\d{2})\s*([AP]M)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (amPmMatch != null) {
      var hour = int.parse(amPmMatch.group(1)!);
      final minute = int.parse(amPmMatch.group(2)!);
      final period = amPmMatch.group(3)!.toUpperCase();
      if (period == 'PM' && hour != 12) hour += 12;
      if (period == 'AM' && hour == 12) hour = 0;
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}:00';
    }

    final timeMatch =
        RegExp(r'^(\d{1,2}):(\d{2})(?::(\d{2}))?$').firstMatch(text);
    if (timeMatch != null) {
      final hour = int.parse(timeMatch.group(1)!);
      final minute = int.parse(timeMatch.group(2)!);
      final second = int.tryParse(timeMatch.group(3) ?? '0') ?? 0;
      return '${hour.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')}:'
          '${second.toString().padLeft(2, '0')}';
    }

    return text;
  }

  static String _fromPostgresTime(Object? value) {
    final text = value?.toString() ?? '';
    final match =
        RegExp(r'^(\d{1,2}):(\d{2})(?::\d{2}(?:\.\d+)?)?$').firstMatch(text);
    if (match == null) return text;

    final hour24 = int.parse(match.group(1)!);
    final minute = match.group(2)!;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '${hour12.toString().padLeft(2, '0')}:$minute $period';
  }
}
