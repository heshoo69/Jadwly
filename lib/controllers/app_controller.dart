import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/schedule_item.dart';
import '../models/session_type.dart';
import '../models/teacher_class.dart';
import '../l10n/app_strings.dart';
import '../services/analytics_service.dart';
import '../services/app_feedback_service.dart';
import '../services/auth_service.dart';
import '../services/backup_service.dart';
import '../services/cloud_sync_service.dart';
import '../services/date_helpers.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/time_helpers.dart';

class AppController extends ChangeNotifier {
  AppController() {
    _load();
    _authService = AuthService.instanceOrNull;
    _localReviewSignedIn =
        StorageService.settingsBox.get(_localReviewSignedInKey) == true;
    _signedInUserEmail = _authService?.currentUser?.email;
    _authSubscription = _authService?.authStateChanges.listen((event) {
      if (_localReviewSignedIn) return;
      _signedInUserEmail = event.session?.user.email;
      if (event.session == null) {
        _cloudDeletionScheduledFor = null;
      }
      notifyListeners();
      if (event.session != null) {
        unawaited(refreshCloudDeletionRequest());
        unawaited(syncLocalDataToCloud(silent: true));
        if (notificationsEnabled) {
          unawaited(_registerFcmTokenForCurrentUser());
        }
      }
    });
    if (_signedInUserEmail != null) {
      unawaited(refreshCloudDeletionRequest());
      if (notificationsEnabled) {
        unawaited(_registerFcmTokenForCurrentUser());
      }
    }
  }

  AuthService? _authService;
  StreamSubscription<AuthState>? _authSubscription;
  bool _syncingCloud = false;
  bool _localReviewSignedIn = false;
  String? _signedInUserEmail;
  DateTime? _lastCloudSyncAt;
  DateTime? _cloudDeletionScheduledFor;
  String? _cloudSyncError;

  static const localReviewEmail = 'review@jadwly.app';
  static const localReviewOtp = '246810';
  static const _localReviewSignedInKey = 'localReviewSignedIn';
  static const _localReviewEmailKey = 'localReviewEmail';
  static const _localReviewLastResetAtKey = 'localReviewLastResetAt';

  List<TeacherClass> classes = [];
  List<ScheduleItem> schedule = [];
  List<LessonRecord> lessons = [];
  String teacherName = '';
  String languageCode = 'ar';
  bool notificationsEnabled = false;
  int reminderMinutes = 10;
  int weekStartDay = DateTime.sunday;
  bool showWeekends = false;
  String scheduleViewMode = 'weeklyGrid';

  DateTime? get lastBackupDate => BackupService.getLastBackupDate();
  bool get automaticBackupFailed => BackupService.automaticBackupFailed;
  String get lastBackupError => BackupService.lastBackupError;
  String getBackupStatusLabel() =>
      BackupService.backupStatusLabel(languageCode);
  bool get isSignedIn => _localReviewSignedIn || _signedInUserEmail != null;
  bool get isCloudSignedIn =>
      !_localReviewSignedIn && _signedInUserEmail != null;
  bool get isLocalReviewSignedIn => _localReviewSignedIn;
  bool get isSyncingCloud => _syncingCloud;
  String? get signedInUserEmail =>
      _localReviewSignedIn ? localReviewEmail : _signedInUserEmail;
  DateTime? get lastCloudSyncAt => _lastCloudSyncAt;
  DateTime? get cloudDeletionScheduledFor => _cloudDeletionScheduledFor;
  String? get cloudSyncError => _cloudSyncError;

  void refreshAuthState() {
    if (_localReviewSignedIn) {
      notifyListeners();
      return;
    }
    final email = _authService?.currentUser?.email;
    if (_signedInUserEmail == email) return;
    _signedInUserEmail = email;
    if (email != null) {
      notifyListeners();
      unawaited(refreshCloudDeletionRequest());
      if (notificationsEnabled) {
        unawaited(_registerFcmTokenForCurrentUser());
      }
    } else {
      _cloudDeletionScheduledFor = null;
      notifyListeners();
    }
  }

  Future<void> refreshCloudDeletionRequest() async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      final scheduledFor =
          await CloudSyncService().fetchCloudDataDeletionScheduledFor();
      _cloudDeletionScheduledFor = scheduledFor;
      notifyListeners();
    } catch (error) {
      _cloudSyncError = error.toString();
      notifyListeners();
    }
  }

  void _load() {
    classes = StorageService.classesBox.values.toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    schedule = StorageService.scheduleBox.values.toList()
      ..sort((a, b) {
        final day = a.dayOfWeek.compareTo(b.dayOfWeek);
        if (day != 0) return day;
        if (a.periodNumber > 0 && b.periodNumber > 0) {
          return a.periodNumber.compareTo(b.periodNumber);
        }
        return minutesSinceMidnight(a.startTime)
            .compareTo(minutesSinceMidnight(b.startTime));
      });
    lessons = StorageService.lessonsBox.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    teacherName = StorageService.settingsBox
        .get('teacherName', defaultValue: '') as String;
    languageCode = StorageService.settingsBox
        .get('languageCode', defaultValue: 'ar') as String;
    notificationsEnabled = StorageService.settingsBox
        .get('notificationsEnabled', defaultValue: false) as bool;
    reminderMinutes = StorageService.settingsBox
        .get('reminderMinutes', defaultValue: 10) as int;
    weekStartDay = StorageService.settingsBox
        .get('weekStartDay', defaultValue: DateTime.sunday) as int;
    showWeekends = StorageService.settingsBox
        .get('showWeekends', defaultValue: false) as bool;
    scheduleViewMode = StorageService.settingsBox
        .get('scheduleViewMode', defaultValue: 'weeklyGrid') as String;
  }

  TeacherClass? classById(String id) {
    for (final item in classes) {
      if (item.id == id) return item;
    }
    return null;
  }

  List<ScheduleItem> scheduleForDay(int dayOfWeek) {
    return schedule.where((item) => item.dayOfWeek == dayOfWeek).toList()
      ..sort((a, b) {
        if (a.periodNumber > 0 && b.periodNumber > 0) {
          return a.periodNumber.compareTo(b.periodNumber);
        }
        return minutesSinceMidnight(a.startTime)
            .compareTo(minutesSinceMidnight(b.startTime));
      });
  }

  bool hasSchedulePeriodConflict({
    required int dayOfWeek,
    required int periodNumber,
    String? excludeId,
  }) {
    return schedule.any((item) =>
        item.dayOfWeek == dayOfWeek &&
        item.periodNumber == periodNumber &&
        item.id != excludeId);
  }

  List<int> get visibleWeekDays {
    final ordered = <int>[];
    for (var offset = 0; offset < 7; offset++) {
      final day = ((weekStartDay - 1 + offset) % 7) + 1;
      if (!showWeekends &&
          (day == DateTime.friday || day == DateTime.saturday)) {
        continue;
      }
      ordered.add(day);
    }
    return ordered;
  }

  List<LessonRecord> lessonsForClass(String classId) {
    return lessons.where((lesson) => lesson.classId == classId).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  LessonRecord? latestLessonForClass(String classId) {
    final records = lessonsForClass(classId);
    return records.isEmpty ? null : records.first;
  }

  Future<void> saveTeacherClass(TeacherClass item) async {
    final isEditing = StorageService.classesBox.containsKey(item.id);
    await StorageService.classesBox.put(item.id, item);
    _load();
    await _syncClassReminders();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logTeacherClassSaved(isEditing: isEditing));
    unawaited(_syncTeacherClassToCloud(item));
  }

  Future<void> deleteTeacherClass(String id) async {
    final deletedScheduleIds = schedule
        .where((entry) => entry.classId == id)
        .map((entry) => entry.id)
        .toList();
    final deletedLessonIds = lessons
        .where((entry) => entry.classId == id)
        .map((entry) => entry.id)
        .toList();
    await StorageService.classesBox.delete(id);
    for (final item
        in schedule.where((entry) => entry.classId == id).toList()) {
      await StorageService.scheduleBox.delete(item.id);
    }
    for (final item in lessons.where((entry) => entry.classId == id).toList()) {
      await StorageService.lessonsBox.delete(item.id);
    }
    _load();
    await _syncClassReminders();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logTeacherClassDeleted(
      deletedScheduleCount: deletedScheduleIds.length,
      deletedLessonCount: deletedLessonIds.length,
    ));
    unawaited(_deleteClassTreeFromCloud(
      id,
      scheduleIds: deletedScheduleIds,
      lessonIds: deletedLessonIds,
    ));
  }

  Future<void> saveScheduleItem(ScheduleItem item) async {
    final isEditing = StorageService.scheduleBox.containsKey(item.id);
    await StorageService.scheduleBox.put(item.id, item);
    _load();
    await _syncClassReminders();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logScheduleItemSaved(isEditing: isEditing));
    unawaited(_syncScheduleItemToCloud(item));
  }

  Future<void> deleteScheduleItem(String id) async {
    await StorageService.scheduleBox.delete(id);
    _load();
    await _syncClassReminders();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logScheduleItemDeleted());
    unawaited(_deleteScheduleItemFromCloud(id));
  }

  Future<void> addLesson(LessonRecord record) async {
    await StorageService.lessonsBox.put(record.id, record);
    _load();
    await _syncClassReminders();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logLessonSaved(isEditing: false));
    unawaited(_syncLessonRecordToCloud(record));
  }

  Future<void> updateLesson(LessonRecord record) async {
    await StorageService.lessonsBox.put(record.id, record);
    _load();
    await _syncClassReminders();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logLessonSaved(isEditing: true));
    unawaited(_syncLessonRecordToCloud(record));
  }

  Future<void> deleteLesson(String id) async {
    await StorageService.lessonsBox.delete(id);
    _load();
    await _syncClassReminders();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logLessonDeleted());
    unawaited(_deleteLessonRecordFromCloud(id));
  }

  Future<void> saveTeacherName(String name) async {
    final trimmedName = name.trim();
    await StorageService.settingsBox.put('teacherName', trimmedName);
    _load();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logTeacherNameUpdated());
    unawaited(_saveProfileNameToCloud(trimmedName));
  }

  Future<void> saveLanguageCode(String code) async {
    await StorageService.settingsBox.put('languageCode', code);
    _load();
    await _syncClassReminders();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logLanguageChanged(languageCode: code));
    unawaited(AnalyticsService.logSettingsChanged(
      setting: 'language',
      value: code,
    ));
  }

  Future<void> clearAllData() async {
    final backupMetadata = BackupService.backupMetadataSnapshot();
    final preservedSettings = <String, Object>{
      'languageCode': languageCode,
      'notificationsEnabled': notificationsEnabled,
      'reminderMinutes': reminderMinutes,
      'weekStartDay': weekStartDay,
      'showWeekends': showWeekends,
      'scheduleViewMode': scheduleViewMode,
    };

    await NotificationService.cancelAllClassReminders();
    await StorageService.clearAll();
    await StorageService.settingsBox.putAll(preservedSettings);
    await BackupService.restoreBackupMetadataSnapshot(backupMetadata);
    _load();
    notifyListeners();
    unawaited(AnalyticsService.logLocalDataCleared());
  }

  Future<bool> setNotificationsEnabled(bool enabled) async {
    if (!enabled) {
      await StorageService.settingsBox.put('notificationsEnabled', false);
      await NotificationService.cancelAllClassReminders();
      unawaited(_deleteFcmTokenForCurrentUser());
      _load();
      await _createAutomaticBackup();
      notifyListeners();
      unawaited(AnalyticsService.logSettingsChanged(
        setting: 'notifications',
        enabled: false,
      ));
      unawaited(_saveReminderSettingsToCloud());
      return true;
    }

    final granted = await NotificationService.requestPermission();
    await StorageService.settingsBox.put('notificationsEnabled', granted);
    _load();
    if (granted) {
      await _registerFcmTokenForCurrentUser();
      await _syncClassReminders();
    } else {
      await NotificationService.cancelAllClassReminders();
    }
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logSettingsChanged(
      setting: 'notifications',
      enabled: granted,
    ));
    unawaited(_saveReminderSettingsToCloud());
    return granted;
  }

  Future<void> setReminderMinutes(int minutes) async {
    await StorageService.settingsBox.put('reminderMinutes', minutes);
    _load();
    await _syncClassReminders();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logSettingsChanged(
      setting: 'reminder_minutes',
      numericValue: minutes,
    ));
    unawaited(_saveReminderSettingsToCloud());
  }

  Future<void> setWeekStartDay(int day) async {
    await StorageService.settingsBox.put('weekStartDay', day);
    _load();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logSettingsChanged(
      setting: 'week_start_day',
      numericValue: day,
    ));
  }

  Future<void> setShowWeekends(bool value) async {
    await StorageService.settingsBox.put('showWeekends', value);
    _load();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logSettingsChanged(
      setting: 'show_weekends',
      enabled: value,
    ));
  }

  Future<void> setScheduleViewMode(String mode) async {
    await StorageService.settingsBox.put('scheduleViewMode', mode);
    _load();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logSettingsChanged(
      setting: 'schedule_view_mode',
      value: mode,
    ));
  }

  Future<bool> addDemoData() async {
    if (classes.isNotEmpty || schedule.isNotEmpty || lessons.isNotEmpty) {
      return false;
    }

    await _seedDemoData();
    return true;
  }

  Future<void> _seedDemoData() async {
    final now = DateTime.now();
    final classOneId = newId();
    final classTwoId = '${classOneId}_2';
    final scheduleOneId = '${classOneId}_schedule_1';
    final scheduleTwoId = '${classOneId}_schedule_2';
    final lessonId = '${classOneId}_lesson_1';
    final classOne = TeacherClass(
      id: classOneId,
      className: 'أول متوسط / 1',
      subject: 'المهارات الرقمية',
      roomNumber: '201',
      createdAt: now,
    );
    final classTwo = TeacherClass(
      id: classTwoId,
      className: 'أول متوسط / 2',
      subject: 'المهارات الرقمية',
      roomNumber: '202',
      createdAt: now,
    );
    await StorageService.classesBox.put(classOne.id, classOne);
    await StorageService.classesBox.put(classTwo.id, classTwo);
    await StorageService.scheduleBox.put(
      scheduleOneId,
      ScheduleItem(
        id: scheduleOneId,
        dayOfWeek: now.weekday,
        periodNumber: 1,
        startTime: '07:30 AM',
        endTime: '08:15 AM',
        subject: classOne.subject,
        classId: classOne.id,
        roomNumber: classOne.roomNumber,
      ),
    );
    await StorageService.scheduleBox.put(
      scheduleTwoId,
      ScheduleItem(
        id: scheduleTwoId,
        dayOfWeek: now.weekday,
        periodNumber: 2,
        startTime: '08:20 AM',
        endTime: '09:05 AM',
        subject: classTwo.subject,
        classId: classTwo.id,
        roomNumber: classTwo.roomNumber,
      ),
    );
    await StorageService.lessonsBox.put(
      lessonId,
      LessonRecord(
        id: lessonId,
        classId: classOne.id,
        lessonTitle: 'التعامل مع الملفات',
        sessionType: SessionType.practical,
        notes: 'تطبيق عملي على إنشاء المجلدات وتنظيم الملفات.',
        status: LessonStatus.needsContinuation,
        date: now.subtract(const Duration(days: 1)),
        createdAt: now,
      ),
    );
    _load();
    await _syncClassReminders();
    await _createAutomaticBackup();
    notifyListeners();
    unawaited(AnalyticsService.logDemoDataAdded());
  }

  Future<void> signInLocalReviewAccount() async {
    try {
      await _authService?.signOut();
    } catch (_) {
      // A local review session must not depend on Supabase availability.
    }

    _signedInUserEmail = null;
    _localReviewSignedIn = true;
    await StorageService.settingsBox.put(_localReviewSignedInKey, true);
    await StorageService.settingsBox
        .put(_localReviewEmailKey, localReviewEmail);

    final lastReset = _localReviewLastResetAt;
    final now = DateTime.now();
    if (lastReset == null ||
        now.difference(lastReset) >= const Duration(days: 1)) {
      await _resetLocalReviewData(now);
    } else {
      _load();
      notifyListeners();
    }
  }

  DateTime? get _localReviewLastResetAt {
    final value = StorageService.settingsBox.get(_localReviewLastResetAtKey);
    return value is DateTime ? value : null;
  }

  Future<void> _resetLocalReviewData(DateTime resetAt) async {
    final preservedSettings = <String, Object>{
      'languageCode': languageCode,
      'notificationsEnabled': notificationsEnabled,
      'reminderMinutes': reminderMinutes,
      'weekStartDay': weekStartDay,
      'showWeekends': showWeekends,
      'scheduleViewMode': scheduleViewMode,
      'teacherName': 'معلم التجربة',
      _localReviewSignedInKey: true,
      _localReviewEmailKey: localReviewEmail,
      _localReviewLastResetAtKey: resetAt,
    };

    await NotificationService.cancelAllClassReminders();
    await StorageService.classesBox.clear();
    await StorageService.scheduleBox.clear();
    await StorageService.lessonsBox.clear();
    await StorageService.settingsBox.putAll(preservedSettings);
    _load();
    await _seedDemoData();
  }

  Future<bool> retryAutomaticBackup({Rect? sharePositionOrigin}) async {
    final file = await BackupService.createAutomaticBackup();
    _load();
    notifyListeners();
    if (file != null) {
      unawaited(AnalyticsService.logBackupActionCompleted(
        action: 'retry_success',
      ));
      return true;
    }

    final shareFile = await BackupService.latestAutomaticBackupShareFile();
    if (shareFile != null) {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              shareFile.bytes,
              mimeType: 'application/json',
              name: shareFile.fileName,
            ),
          ],
          fileNameOverrides: [shareFile.fileName],
          text: 'Jadwly backup',
          sharePositionOrigin: sharePositionOrigin,
        ),
      );
    }
    return false;
  }

  Future<bool> exportLatestAutomaticBackup({Rect? sharePositionOrigin}) async {
    final shareFile = await BackupService.latestAutomaticBackupShareFile();
    _load();
    notifyListeners();
    if (shareFile == null) return false;

    await SharePlus.instance.share(
      ShareParams(
        files: [
          XFile.fromData(
            shareFile.bytes,
            mimeType: 'application/json',
            name: shareFile.fileName,
          ),
        ],
        fileNameOverrides: [shareFile.fileName],
        text: 'Jadwly backup',
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
    unawaited(AnalyticsService.logBackupExported());
    unawaited(AnalyticsService.logBackupActionCompleted(action: 'export'));
    return true;
  }

  Future<bool?> saveLatestAutomaticBackupToFiles() async {
    final backup = await BackupService.getLatestAutomaticBackupOrCreate();
    _load();
    notifyListeners();
    if (backup == null) return false;

    final savedPath = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Jadwly backup',
      fileName: await BackupService.exportFileNameForBackup(backup),
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: await backup.readAsBytes(),
    );
    final saved = savedPath != null;
    if (saved) {
      unawaited(AnalyticsService.logBackupActionCompleted(
        action: 'save_to_files',
      ));
    }
    return savedPath == null ? null : true;
  }

  Future<void> restoreLatestAutomaticBackup() async {
    await BackupService.restoreLatestAutomaticBackup();
    _load();
    await _syncClassReminders();
    notifyListeners();
    unawaited(AnalyticsService.logBackupActionCompleted(
      action: 'restore_latest',
    ));
    unawaited(_replaceCloudWithRestoredLocalData());
  }

  Future<bool> restoreBackupFromFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return false;

    final pickedFile = result.files.single;
    final bytes = pickedFile.bytes;
    final path = pickedFile.path;
    final contents = bytes != null
        ? utf8.decode(bytes)
        : path == null
            ? null
            : await XFile(path).readAsString();
    if (contents == null) {
      throw const BackupValidationException('ملف النسخة الاحتياطية غير صالح');
    }
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const BackupValidationException('ملف النسخة الاحتياطية غير صالح');
    }
    BackupService.validateBackupJson(decoded);
    await BackupService.applyBackupToLocalStorage(decoded);
    _load();
    await _syncClassReminders();
    notifyListeners();
    unawaited(AnalyticsService.logBackupActionCompleted(
      action: 'restore_from_file',
    ));
    unawaited(_replaceCloudWithRestoredLocalData());
    return true;
  }

  Future<void> syncLocalDataToCloud({bool silent = false}) async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    if (_syncingCloud) return;
    _syncingCloud = true;
    _cloudSyncError = null;
    notifyListeners();
    try {
      await CloudSyncService().uploadLocalData();
      _lastCloudSyncAt = DateTime.now();
      unawaited(AnalyticsService.logCloudSync(isAutomatic: silent));
      if (!silent) {
        AppFeedbackService.showSnackBar(
          AppStrings(languageCode).cloudSyncComplete,
        );
      }
    } catch (error) {
      _cloudSyncError = error.toString();
      if (!silent) {
        AppFeedbackService.showSnackBar(
          AppStrings(languageCode).cloudSyncFailed,
        );
      }
    } finally {
      _syncingCloud = false;
      notifyListeners();
    }
  }

  Future<void> _replaceCloudWithRestoredLocalData() async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    if (_syncingCloud) return;
    _syncingCloud = true;
    _cloudSyncError = null;
    notifyListeners();
    try {
      await CloudSyncService().replaceCloudWithLocalData();
      _cloudDeletionScheduledFor = null;
      _lastCloudSyncAt = DateTime.now();
      unawaited(AnalyticsService.logCloudDataRestoreCompleted());
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).restoredBackupSyncedToCloud,
      );
    } catch (error) {
      _cloudSyncError = error.toString();
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).restoredBackupCloudSyncFailed,
      );
    } finally {
      _syncingCloud = false;
      notifyListeners();
    }
  }

  Future<void> restoreCloudDataReplaceLocal() async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    if (_syncingCloud) return;
    _syncingCloud = true;
    _cloudSyncError = null;
    notifyListeners();
    try {
      await CloudSyncService().restoreCloudDataReplaceLocal();
      _cloudDeletionScheduledFor = null;
      _lastCloudSyncAt = DateTime.now();
      _load();
      await _syncClassReminders();
      notifyListeners();
      unawaited(AnalyticsService.logCloudDataRestoreCompleted());
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).cloudDataRestored,
      );
    } catch (error) {
      _cloudSyncError = error.toString();
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).restoreCloudDataFailed,
      );
    } finally {
      _syncingCloud = false;
      notifyListeners();
    }
  }

  Future<bool> scheduleCloudDataDeletion() async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return false;
    try {
      _cloudDeletionScheduledFor =
          await CloudSyncService().scheduleCloudDataDeletion();
      notifyListeners();
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).cloudDeletionScheduled,
      );
      unawaited(AnalyticsService.logCloudDataDeletionScheduled());
      return true;
    } catch (error) {
      _cloudSyncError = error.toString();
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).cloudDeletionFailed,
      );
      return false;
    }
  }

  Future<void> cancelCloudDataDeletion() async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    if (_syncingCloud) return;
    _syncingCloud = true;
    _cloudSyncError = null;
    notifyListeners();
    try {
      await CloudSyncService().restoreCloudDataReplaceLocal();
      _cloudDeletionScheduledFor = null;
      _lastCloudSyncAt = DateTime.now();
      _load();
      await _syncClassReminders();
      notifyListeners();
      unawaited(AnalyticsService.logCloudDataDeletionCancelled());
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).cloudDeletionCancelled,
      );
    } catch (error) {
      _cloudSyncError = error.toString();
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).cloudDeletionCancelFailed,
      );
    } finally {
      _syncingCloud = false;
      notifyListeners();
    }
  }

  Future<bool> signOut() async {
    if (_localReviewSignedIn) {
      _localReviewSignedIn = false;
      _signedInUserEmail = null;
      await StorageService.settingsBox.put(_localReviewSignedInKey, false);
      await StorageService.settingsBox.delete(_localReviewEmailKey);
      notifyListeners();
      unawaited(AnalyticsService.logSignOut());
      AppFeedbackService.showSnackBar(AppStrings(languageCode).signOutMessage);
      return true;
    }

    final authService = _authService;
    if (authService == null) return false;
    try {
      await _deleteFcmTokenForCurrentUser();
      await authService.signOut();
      _signedInUserEmail = null;
      notifyListeners();
      unawaited(AnalyticsService.logSignOut());
      AppFeedbackService.showSnackBar(AppStrings(languageCode).signOutMessage);
      return true;
    } catch (_) {
      AppFeedbackService.showSnackBar(AppStrings(languageCode).signOutFailed);
      return false;
    }
  }

  Future<void> _syncTeacherClassToCloud(TeacherClass item) async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      await CloudSyncService().uploadTeacherClass(item);
      _lastCloudSyncAt = DateTime.now();
    } catch (error) {
      _cloudSyncError = error.toString();
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).classSavedLocallySyncFailed,
      );
    }
  }

  Future<void> _deleteClassTreeFromCloud(
    String id, {
    required List<String> scheduleIds,
    required List<String> lessonIds,
  }) async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      final sync = CloudSyncService();
      for (final scheduleId in scheduleIds) {
        await sync.deleteScheduleItem(scheduleId);
      }
      for (final lessonId in lessonIds) {
        await sync.deleteLessonRecord(lessonId);
      }
      await sync.deleteTeacherClass(id);
      _lastCloudSyncAt = DateTime.now();
    } catch (error) {
      _cloudSyncError = error.toString();
      AppFeedbackService.showSnackBar(AppStrings(languageCode).cloudSyncFailed);
    }
  }

  Future<void> _syncScheduleItemToCloud(ScheduleItem item) async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      final className = classById(item.classId)?.className ?? item.classId;
      await CloudSyncService().uploadScheduleItem(
        item,
        className: className,
      );
      _lastCloudSyncAt = DateTime.now();
    } catch (error) {
      _cloudSyncError = error.toString();
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).periodSavedLocallySyncFailed,
      );
    }
  }

  Future<void> _deleteScheduleItemFromCloud(String id) async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      await CloudSyncService().deleteScheduleItem(id);
      _lastCloudSyncAt = DateTime.now();
    } catch (error) {
      _cloudSyncError = error.toString();
      AppFeedbackService.showSnackBar(AppStrings(languageCode).cloudSyncFailed);
    }
  }

  Future<void> _syncLessonRecordToCloud(LessonRecord record) async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      final teacherClass = classById(record.classId);
      await CloudSyncService().uploadLessonRecord(
        record,
        className: teacherClass?.className ?? record.classId,
        subject: teacherClass?.subject ?? '',
      );
      _lastCloudSyncAt = DateTime.now();
    } catch (error) {
      _cloudSyncError = error.toString();
      AppFeedbackService.showSnackBar(
        AppStrings(languageCode).lessonSavedLocallySyncFailed,
      );
    }
  }

  Future<void> _deleteLessonRecordFromCloud(String id) async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      await CloudSyncService().deleteLessonRecord(id);
      _lastCloudSyncAt = DateTime.now();
    } catch (error) {
      _cloudSyncError = error.toString();
      AppFeedbackService.showSnackBar(AppStrings(languageCode).cloudSyncFailed);
    }
  }

  Future<void> _saveProfileNameToCloud(String name) async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      await CloudSyncService().saveProfileName(name);
      _lastCloudSyncAt = DateTime.now();
    } catch (error) {
      _cloudSyncError = error.toString();
    }
  }

  Future<void> _saveReminderSettingsToCloud() async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      await CloudSyncService().saveReminderSettings(
        notificationsEnabled: notificationsEnabled,
        reminderMinutes: reminderMinutes,
      );
      _lastCloudSyncAt = DateTime.now();
    } catch (error) {
      _cloudSyncError = error.toString();
    }
  }

  Future<void> _registerFcmTokenForCurrentUser() async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      await NotificationService.registerCurrentDeviceToken();
    } catch (error) {
      _cloudSyncError = error.toString();
    }
  }

  Future<void> _deleteFcmTokenForCurrentUser() async {
    if (_localReviewSignedIn || _authService?.currentUser == null) return;
    try {
      await NotificationService.deleteCurrentDeviceToken();
    } catch (error) {
      _cloudSyncError = error.toString();
    }
  }

  Future<void> _syncClassReminders() async {
    if (!notificationsEnabled) return;
    await NotificationService.rescheduleWeeklyClassReminders(
      schedule: schedule,
      classes: classes,
      lessons: lessons,
      reminderMinutes: reminderMinutes,
      languageCode: languageCode,
    );
  }

  Future<void> _createAutomaticBackup() async {
    await BackupService.createAutomaticBackup();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
