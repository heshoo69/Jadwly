import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../models/lesson_record.dart';
import '../models/lesson_status.dart';
import '../models/schedule_item.dart';
import '../models/session_type.dart';
import '../models/teacher_class.dart';
import 'storage_service.dart';

enum BackupStatus {
  automaticSaved,
  localSaved,
  iCloudUnavailable,
  androidSystemDependent,
  failed,
}

class BackupValidationException implements Exception {
  const BackupValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class BackupShareFile {
  const BackupShareFile({
    required this.bytes,
    required this.fileName,
  });

  final Uint8List bytes;
  final String fileName;
}

class BackupService {
  BackupService._();

  static const appName = 'Jadwly';
  static const backupVersion = 1;
  static const maxAutomaticBackups = 5;

  static const _backupDirectoryName = 'automatic_backups';
  static const _filePrefix = 'jadwly_automatic_';
  static const _fileExtension = '.json';
  static const _lastBackupDateKey = 'backup.lastBackupDate';
  static const _backupStatusKey = 'backup.status';
  static const _backupFailedKey = 'backup.failed';
  static const _backupErrorKey = 'backup.error';
  static const _iCloudChannel = MethodChannel(
    'com.hafdev.jadwly/icloud_backups',
  );

  static Directory? _testBackupDirectory;
  static bool? _testIsIOS;

  static void setTestBackupDirectory(Directory? directory) {
    _testBackupDirectory = directory;
  }

  static void setTestIsIOS(bool? isIOS) {
    _testIsIOS = isIOS;
  }

  static Future<Map<String, dynamic>> createBackupJson() async {
    final now = DateTime.now().toUtc();
    return {
      'appName': appName,
      'backupVersion': backupVersion,
      'createdAt': now.toIso8601String(),
      'backupType': 'automatic',
      'platform': _platformName(),
      'classes': StorageService.classesBox.values
          .map(_teacherClassToJson)
          .toList(growable: false),
      'scheduleItems': StorageService.scheduleBox.values
          .map(_scheduleItemToJson)
          .toList(growable: false),
      'lessonRecords': StorageService.lessonsBox.values
          .map(_lessonRecordToJson)
          .toList(growable: false),
      'settings': _settingsToJson(),
    };
  }

  static Future<File?> createAutomaticBackup() async {
    try {
      final backupJson = await createBackupJson();
      final file = await saveLocalAutomaticBackup(backupJson);
      await deleteOldAutomaticBackupsIfNeeded();

      var status = BackupStatus.localSaved;
      if (_isIOS) {
        final savedToICloud = await trySaveICloudBackupIfAvailable(backupJson);
        status = savedToICloud
            ? BackupStatus.automaticSaved
            : BackupStatus.iCloudUnavailable;
      } else if (Platform.isAndroid) {
        await enableOrRespectAndroidAutoBackup();
        status = BackupStatus.androidSystemDependent;
      }

      await _markBackupSuccess(
        createdAt: DateTime.parse(backupJson['createdAt'] as String),
        status: status,
      );
      return file;
    } catch (error) {
      await _markBackupFailure(error);
      return null;
    }
  }

  static Future<File> saveLocalAutomaticBackup(
    Map<String, dynamic> backupJson,
  ) async {
    final directory = await _automaticBackupsDirectory();
    final createdAt = DateTime.parse(backupJson['createdAt'] as String);
    final safeTimestamp = createdAt
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-')
        .replaceAll('.', '-');
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      '$_filePrefix$safeTimestamp$_fileExtension',
    );
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(backupJson),
      flush: true,
    );
    return file;
  }

  static Future<bool> trySaveICloudBackupIfAvailable(
    Map<String, dynamic> backupJson,
  ) async {
    if (!_isIOS) return false;
    try {
      final createdAt = DateTime.parse(backupJson['createdAt'] as String);
      final fileName = 'Jadwly_backup_${_fileNameTimestamp(createdAt)}'
          '$_fileExtension';
      final contents = const JsonEncoder.withIndent('  ').convert(backupJson);
      final saved = await _iCloudChannel.invokeMethod<bool>('saveBackup', {
        'fileName': fileName,
        'contents': contents,
      });
      return saved == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> enableOrRespectAndroidAutoBackup() async {
    // Android Auto Backup is enabled in AndroidManifest.xml. It depends on the
    // user's device backup settings and may restore app data automatically when
    // the app is installed on a new Android device. Without Google Sign-In and
    // Google Drive API permissions, this app cannot directly create a visible
    // Google Drive backup file.
  }

  static Future<File?> getLatestAutomaticBackup() async {
    final backups = await getAutomaticBackups();
    return backups.isEmpty ? null : backups.first;
  }

  static Future<File?> getLatestAutomaticBackupOrCreate() async {
    final latestBackup = await getLatestAutomaticBackup();
    if (latestBackup != null) return latestBackup;
    return createAutomaticBackup();
  }

  static Future<String> exportFileNameForBackup(File backup) async {
    var createdAt = await backup.lastModified();
    try {
      final decoded = jsonDecode(await backup.readAsString());
      if (decoded is Map<String, dynamic>) {
        final value = decoded['createdAt'];
        if (value is String) {
          createdAt = DateTime.parse(value).toLocal();
        }
      }
    } catch (_) {
      // Keep the file modification date fallback when the JSON cannot be read.
    }
    return 'Jadwly_backup_${_fileNameTimestamp(createdAt)}$_fileExtension';
  }

  static Future<BackupShareFile?> latestAutomaticBackupShareFile() async {
    final backup = await getLatestAutomaticBackupOrCreate();
    if (backup == null) return null;
    return BackupShareFile(
      bytes: await backup.readAsBytes(),
      fileName: await exportFileNameForBackup(backup),
    );
  }

  static Future<List<File>> getAutomaticBackups() async {
    final directory = await _automaticBackupsDirectory(create: false);
    if (!await directory.exists()) return [];
    final files = await directory
        .list()
        .where((entity) =>
            entity is File &&
            entity.path.split(Platform.pathSeparator).last.startsWith(
                  _filePrefix,
                ) &&
            entity.path.endsWith(_fileExtension))
        .cast<File>()
        .toList();
    files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
    return files;
  }

  static Future<void> deleteOldAutomaticBackupsIfNeeded() async {
    final backups = await getAutomaticBackups();
    if (backups.length <= maxAutomaticBackups) return;
    for (final file in backups.skip(maxAutomaticBackups)) {
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  static Future<void> restoreLatestAutomaticBackup() async {
    final file = await getLatestAutomaticBackup();
    if (file == null) {
      throw const BackupValidationException('ملف النسخة الاحتياطية غير صالح');
    }
    final contents = await file.readAsString();
    final decoded = jsonDecode(contents);
    if (decoded is! Map<String, dynamic>) {
      throw const BackupValidationException('ملف النسخة الاحتياطية غير صالح');
    }
    validateBackupJson(decoded);
    await applyBackupToLocalStorage(decoded);
  }

  static void validateBackupJson(Map<String, dynamic> backupJson) {
    if (backupJson['appName'] != appName) {
      throw const BackupValidationException('ملف النسخة الاحتياطية غير صالح');
    }
    if (backupJson['backupVersion'] != backupVersion) {
      throw const BackupValidationException(
        'إصدار النسخة الاحتياطية غير مدعوم',
      );
    }
    if (backupJson['classes'] is! List ||
        backupJson['scheduleItems'] is! List ||
        backupJson['lessonRecords'] is! List ||
        backupJson['settings'] is! Map) {
      throw const BackupValidationException('ملف النسخة الاحتياطية غير صالح');
    }
  }

  static Future<void> applyBackupToLocalStorage(
    Map<String, dynamic> backupJson,
  ) async {
    try {
      final backupMetadata = backupMetadataSnapshot();
      final classes = (backupJson['classes'] as List)
          .map((item) => _teacherClassFromJson(_asMap(item)))
          .toList();
      final scheduleItems = (backupJson['scheduleItems'] as List)
          .map((item) => _scheduleItemFromJson(_asMap(item)))
          .toList();
      final lessonRecords = (backupJson['lessonRecords'] as List)
          .map((item) => _lessonRecordFromJson(_asMap(item)))
          .toList();
      final settings = Map<String, dynamic>.from(
        backupJson['settings'] as Map,
      );

      await StorageService.classesBox.clear();
      await StorageService.scheduleBox.clear();
      await StorageService.lessonsBox.clear();
      await StorageService.settingsBox.clear();

      await StorageService.classesBox.putAll({
        for (final item in classes) item.id: item,
      });
      await StorageService.scheduleBox.putAll({
        for (final item in scheduleItems) item.id: item,
      });
      await StorageService.lessonsBox.putAll({
        for (final item in lessonRecords) item.id: item,
      });
      await StorageService.settingsBox.putAll(settings);
      await restoreBackupMetadataSnapshot(backupMetadata);
    } catch (_) {
      throw const BackupValidationException('تعذر استعادة البيانات');
    }
  }

  static DateTime? getLastBackupDate() {
    final value = StorageService.settingsBox.get(_lastBackupDateKey);
    if (value is String) return DateTime.tryParse(value)?.toLocal();
    return null;
  }

  static BackupStatus getBackupStatus() {
    final value = StorageService.settingsBox.get(_backupStatusKey);
    return BackupStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => BackupStatus.localSaved,
    );
  }

  static bool get automaticBackupFailed =>
      StorageService.settingsBox.get(_backupFailedKey, defaultValue: false)
          as bool;

  static String get lastBackupError =>
      StorageService.settingsBox.get(_backupErrorKey, defaultValue: '')
          as String;

  static Map<String, Object?> backupMetadataSnapshot() {
    return {
      _lastBackupDateKey: StorageService.settingsBox.get(_lastBackupDateKey),
      _backupStatusKey: StorageService.settingsBox.get(_backupStatusKey),
      _backupFailedKey: StorageService.settingsBox.get(_backupFailedKey),
      _backupErrorKey: StorageService.settingsBox.get(_backupErrorKey),
    }..removeWhere((key, value) => value == null);
  }

  static Future<void> restoreBackupMetadataSnapshot(
    Map<String, Object?> snapshot,
  ) async {
    if (snapshot.isEmpty) return;
    await StorageService.settingsBox.putAll(snapshot);
  }

  static String backupStatusLabel(String languageCode) {
    final status = getBackupStatus();
    if (languageCode == 'en') {
      switch (status) {
        case BackupStatus.automaticSaved:
          return 'Saved to iCloud';
        case BackupStatus.localSaved:
          return 'Saved locally';
        case BackupStatus.iCloudUnavailable:
          return 'Saved locally; iCloud unavailable';
        case BackupStatus.androidSystemDependent:
          return 'System backup depends on device settings';
        case BackupStatus.failed:
          return 'Automatic backup failed';
      }
    }
    switch (status) {
      case BackupStatus.automaticSaved:
        return 'محفوظة في iCloud';
      case BackupStatus.localSaved:
        return 'محفوظة محليًا';
      case BackupStatus.iCloudUnavailable:
        return 'محفوظة محليًا؛ iCloud غير متاح';
      case BackupStatus.androidSystemDependent:
        return 'النسخ الاحتياطي للنظام يعتمد على إعدادات الجهاز';
      case BackupStatus.failed:
        return 'تعذر إنشاء النسخة الاحتياطية تلقائيًا';
    }
  }

  static Future<Directory> _automaticBackupsDirectory({
    bool create = true,
  }) async {
    final baseDirectory = _testBackupDirectory ?? await _appStorageDirectory();
    final directory = Directory(
      '${baseDirectory.path}${Platform.pathSeparator}$_backupDirectoryName',
    );
    if (create && !await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static Future<Directory> _appStorageDirectory() async {
    try {
      return await getApplicationSupportDirectory();
    } on MissingPluginException {
      return Directory.systemTemp.createTemp('jadwly_backups_');
    }
  }

  static Future<void> _markBackupSuccess({
    required DateTime createdAt,
    required BackupStatus status,
  }) async {
    await StorageService.settingsBox.putAll({
      _lastBackupDateKey: createdAt.toUtc().toIso8601String(),
      _backupStatusKey: status.name,
      _backupFailedKey: false,
      _backupErrorKey: '',
    });
  }

  static Future<void> _markBackupFailure(Object error) async {
    await StorageService.settingsBox.putAll({
      _backupStatusKey: BackupStatus.failed.name,
      _backupFailedKey: true,
      _backupErrorKey: error.toString(),
    });
  }

  static String _platformName() {
    if (_isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem;
  }

  static bool get _isIOS => _testIsIOS ?? Platform.isIOS;

  static String _fileNameTimestamp(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$year-$month-${day}_$hour-$minute';
  }

  static Map<String, dynamic> _teacherClassToJson(TeacherClass item) => {
        'id': item.id,
        'className': item.className,
        'subject': item.subject,
        'roomNumber': item.roomNumber,
        'createdAt': item.createdAt.toUtc().toIso8601String(),
      };

  static TeacherClass _teacherClassFromJson(Map<String, dynamic> json) {
    return TeacherClass(
      id: json['id'] as String,
      className: json['className'] as String,
      subject: json['subject'] as String,
      roomNumber: json['roomNumber'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  static Map<String, dynamic> _scheduleItemToJson(ScheduleItem item) => {
        'id': item.id,
        'dayOfWeek': item.dayOfWeek,
        'periodNumber': item.periodNumber,
        'startTime': item.startTime,
        'endTime': item.endTime,
        'subject': item.subject,
        'classId': item.classId,
        'roomNumber': item.roomNumber,
      };

  static ScheduleItem _scheduleItemFromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      periodNumber: json['periodNumber'] as int,
      startTime: json['startTime'] as String,
      endTime: json['endTime'] as String,
      subject: json['subject'] as String,
      classId: json['classId'] as String,
      roomNumber: json['roomNumber'] as String?,
    );
  }

  static Map<String, dynamic> _lessonRecordToJson(LessonRecord item) => {
        'id': item.id,
        'classId': item.classId,
        'lessonTitle': item.lessonTitle,
        'sessionType': item.sessionType.name,
        'notes': item.notes,
        'status': item.status.name,
        'date': item.date.toUtc().toIso8601String(),
        'createdAt': item.createdAt.toUtc().toIso8601String(),
      };

  static LessonRecord _lessonRecordFromJson(Map<String, dynamic> json) {
    return LessonRecord(
      id: json['id'] as String,
      classId: json['classId'] as String,
      lessonTitle: json['lessonTitle'] as String,
      sessionType: sessionTypeFromName(json['sessionType'] as String),
      notes: json['notes'] as String,
      status: lessonStatusFromName(json['status'] as String),
      date: DateTime.parse(json['date'] as String).toLocal(),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  static Map<String, dynamic> _settingsToJson() {
    final settings = <String, dynamic>{};
    for (final key in StorageService.settingsBox.keys) {
      final stringKey = key.toString();
      if (stringKey.startsWith('backup.')) continue;
      final value = StorageService.settingsBox.get(key);
      if (value is String || value is num || value is bool || value == null) {
        settings[stringKey] = value;
      }
    }
    return settings;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const BackupValidationException('ملف النسخة الاحتياطية غير صالح');
  }
}
