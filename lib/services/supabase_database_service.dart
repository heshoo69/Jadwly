import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/schedule_item.dart';
import '../models/session_type.dart';
import 'date_helpers.dart';

class SupabaseDatabaseService {
  SupabaseDatabaseService._();

  static const profilesTable = 'profiles';
  static const weeklyScheduleTable = 'weekly_schedule';
  static const lessonRecordsTable = 'lesson_records';
  static const reminderSettingsTable = 'reminder_settings';
  static const notificationsTable = 'notifications';
  static const deviceTokensTable = 'device_tokens';

  static SupabaseClient get _client => Supabase.instance.client;

  static String get currentUserId => _client.auth.currentUser!.id;
  static String? get currentUserIdOrNull => _client.auth.currentUser?.id;

  static const _beforeClassReminderType = 'before_class';

  static Future<Session> ensureSessionReady() async {
    final auth = _client.auth;
    var session = auth.currentSession;
    if (session == null) {
      throw const AuthException('Supabase session is missing.');
    }

    final expiresAt = session.expiresAt;
    final refreshAt =
        DateTime.now().add(const Duration(minutes: 1)).millisecondsSinceEpoch ~/
            1000;
    if (expiresAt == null || expiresAt > refreshAt) {
      return session;
    }

    debugPrint('Supabase session refresh start.');
    try {
      final response =
          await auth.refreshSession().timeout(const Duration(seconds: 5));
      session = response.session;
      if (session == null) {
        throw const AuthException(
            'Supabase session refresh returned no session.');
      }
      debugPrint('Supabase session refresh success.');
      return session;
    } on TimeoutException {
      debugPrint('Supabase session refresh timed out.');
      throw TimeoutException(
        'Supabase session refresh timed out',
        const Duration(seconds: 5),
      );
    } catch (error) {
      debugPrint('Supabase session refresh failed: $error');
      rethrow;
    }
  }

  static Future<List<ScheduleItem>> fetchWeeklySchedule() async {
    final userId = currentUserId;
    final rows = await _client
        .from(weeklyScheduleTable)
        .select()
        .eq('teacher_id', userId)
        .order('day_of_week')
        .order('period_number');

    return rows.map<ScheduleItem>(_scheduleItemFromRow).toList();
  }

  static Future<ScheduleItem> upsertScheduleItem(
    ScheduleItem item, {
    String? className,
    bool isNew = false,
  }) async {
    debugPrint('Supabase session check start: ${item.id}');
    final session = await ensureSessionReady();
    debugPrint('Supabase session check success: ${item.id}');
    final userId = session.user.id;
    final body = _scheduleItemToRow(
      item,
      userId,
      className: className,
      isNew: isNew,
    );

    try {
      debugPrint('weekly_schedule upsert start: ${item.id}');
      await _client
          .from(weeklyScheduleTable)
          .upsert(body, onConflict: 'id')
          .timeout(const Duration(seconds: 8));
      debugPrint('weekly_schedule upsert success: ${item.id}');
      return item;
    } on PostgrestException catch (error, stackTrace) {
      _logScheduleSaveFailure(error, body);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  static Future<void> deleteScheduleItem(String id) async {
    if (!isUuid(id)) return;
    final userId = currentUserId;
    await _client
        .from(weeklyScheduleTable)
        .delete()
        .eq('id', id)
        .eq('teacher_id', userId);
  }

  static Future<List<LessonRecord>> fetchLessonRecords() async {
    final userId = currentUserId;
    final rows = await _client
        .from(lessonRecordsTable)
        .select()
        .eq('teacher_id', userId)
        .order('lesson_date', ascending: false);

    return rows.map<LessonRecord>(_lessonRecordFromRow).toList();
  }

  static Future<void> upsertLessonRecord(
    LessonRecord record, {
    required String className,
    required String subject,
  }) async {
    debugPrint('Supabase session check start: ${record.id}');
    final session = await ensureSessionReady();
    debugPrint('Supabase session check success: ${record.id}');
    final userId = session.user.id;
    try {
      debugPrint('lesson_records upsert start: ${record.id}');
      await _client
          .from(lessonRecordsTable)
          .upsert(
            _lessonRecordToRow(
              record,
              userId,
              className: className,
              subject: subject,
            ),
            onConflict: 'id',
          )
          .timeout(const Duration(seconds: 8));
      debugPrint('lesson_records upsert success: ${record.id}');
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('lesson_records upsert failed: ${record.id}');
      debugPrint('Supabase error message: ${error.message}');
      debugPrint('Supabase error details: ${error.details}');
      Error.throwWithStackTrace(error, stackTrace);
    } catch (error) {
      debugPrint('lesson_records upsert failed: ${record.id} $error');
      rethrow;
    }
  }

  static Future<void> deleteLessonRecord(String id) async {
    if (!isUuid(id)) return;
    final userId = currentUserId;
    await _client
        .from(lessonRecordsTable)
        .delete()
        .eq('id', id)
        .eq('teacher_id', userId);
  }

  static Future<Map<String, dynamic>?> fetchReminderSettings() async {
    final userId = currentUserId;
    final row = await _client
        .from(reminderSettingsTable)
        .select()
        .eq('teacher_id', userId)
        .eq('reminder_type', _beforeClassReminderType)
        .maybeSingle();
    return row;
  }

  static Future<void> saveReminderSettings({
    required bool notificationsEnabled,
    required int reminderMinutes,
    required int weekStartDay,
    required bool showWeekends,
    required String scheduleViewMode,
  }) async {
    final userId = currentUserId;
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from(reminderSettingsTable).upsert(
      {
        'id': userId,
        'teacher_id': userId,
        'reminder_type': _beforeClassReminderType,
        'is_enabled': notificationsEnabled,
        'minutes_offset': reminderMinutes,
        'created_at': now,
        'updated_at': now,
      },
      onConflict: 'id',
    );
  }

  static Future<void> saveProfileName(String fullName) async {
    final userId = currentUserId;
    await _client.from(profilesTable).upsert(
      {
        'id': userId,
        'full_name': fullName.trim(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'id',
    );
  }

  static Map<String, dynamic> _scheduleItemToRow(
    ScheduleItem item,
    String userId, {
    String? className,
    bool isNew = false,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final body = {
      'id': item.id,
      'teacher_id': userId,
      'day_of_week': weekdayNumberToSupabase(item.dayOfWeek),
      'period_number': item.periodNumber,
      'start_time': _toPostgresTime(item.startTime),
      'end_time': _toPostgresTime(item.endTime),
      'class_name': (className == null || className.trim().isEmpty)
          ? item.classId
          : className.trim(),
      'subject': item.subject,
      'room': item.roomNumber,
      'is_active': true,
      'updated_at': now,
    };
    if (isNew) body['created_at'] = now;
    return body;
  }

  static ScheduleItem _scheduleItemFromRow(Map<String, dynamic> row) {
    final className = row['class_name'] as String? ?? '';
    return ScheduleItem(
      id: row['id'] as String,
      dayOfWeek: supabaseWeekdayToNumber(row['day_of_week']),
      periodNumber: row['period_number'] as int? ?? 0,
      startTime: _fromPostgresTime(row['start_time']),
      endTime: _fromPostgresTime(row['end_time']),
      subject: row['subject'] as String,
      classId: className,
      roomNumber: row['room'] as String?,
      teacherId: row['teacher_id'] as String?,
    );
  }

  static Map<String, dynamic> _lessonRecordToRow(
    LessonRecord record,
    String userId, {
    required String className,
    required String subject,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    return {
      'id': record.id,
      'teacher_id': userId,
      'class_name': className,
      'subject': subject,
      'lesson_title': record.lessonTitle,
      'lesson_type': record.sessionType.name,
      'lesson_date': _dateOnly(record.date),
      'notes': record.notes,
      'created_at': record.createdAt.toUtc().toIso8601String(),
      'updated_at': now,
    };
  }

  static LessonRecord _lessonRecordFromRow(Map<String, dynamic> row) {
    return LessonRecord(
      id: row['id'] as String,
      classId: row['class_name'] as String? ?? '',
      lessonTitle: row['lesson_title'] as String,
      sessionType: sessionTypeFromName(row['lesson_type'] as String? ?? ''),
      notes: row['notes'] as String? ?? '',
      status: LessonStatus.completed,
      date: _parseDate(row['lesson_date']),
      createdAt: _parseDate(row['created_at']),
      teacherId: row['teacher_id'] as String?,
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

  static void _logScheduleSaveFailure(
    PostgrestException error,
    Map<String, dynamic> body,
  ) {
    debugPrint('Failed to save weekly_schedule row.');
    debugPrint('Supabase error message: ${error.message}');
    debugPrint('Supabase error details: ${error.details}');
    debugPrint('weekly_schedule payload: $body');
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
