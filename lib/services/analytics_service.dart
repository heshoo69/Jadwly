import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';

class AnalyticsService {
  AnalyticsService._();

  static FirebaseAnalytics get analytics => FirebaseAnalytics.instance;
  static FirebaseAnalyticsObserver get observer =>
      FirebaseAnalyticsObserver(analytics: analytics);

  static Future<void> logDebugAppOpened() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'debug_app_opened');
  }

  static Future<void> logScreenView({required String screenName}) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logScreenView(screenName: screenName);
  }

  static Future<void> logLogin({required String method}) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logLogin(loginMethod: method);
  }

  static Future<void> logTeacherClassSaved({required bool isEditing}) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: isEditing ? 'teacher_class_updated' : 'teacher_class_created',
    );
  }

  static Future<void> logTeacherClassDeleted({
    required int deletedScheduleCount,
    required int deletedLessonCount,
  }) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'teacher_class_deleted',
      parameters: {
        'deleted_schedule_count': deletedScheduleCount,
        'deleted_lesson_count': deletedLessonCount,
      },
    );
  }

  static Future<void> logScheduleItemSaved({required bool isEditing}) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: isEditing ? 'schedule_item_updated' : 'schedule_item_created',
    );
  }

  static Future<void> logScheduleItemDeleted() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'schedule_item_deleted');
  }

  static Future<void> logLessonSaved({required bool isEditing}) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: isEditing ? 'lesson_updated' : 'lesson_created',
    );
  }

  static Future<void> logLessonDeleted() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'lesson_deleted');
  }

  static Future<void> logTeacherNameUpdated() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'teacher_name_updated');
  }

  static Future<void> logLanguageChanged({required String languageCode}) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'language_changed',
      parameters: {'language_code': languageCode},
    );
  }

  static Future<void> logSettingsChanged({
    required String setting,
    String? value,
    int? numericValue,
    bool? enabled,
  }) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'settings_changed',
      parameters: {
        'setting': setting,
        if (value != null) 'value': value,
        if (numericValue != null) 'numeric_value': numericValue,
        if (enabled != null) 'enabled': enabled ? 1 : 0,
      },
    );
  }

  static Future<void> logLocalDataCleared() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'local_data_cleared');
  }

  static Future<void> logDemoDataAdded() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'demo_data_added');
  }

  static Future<void> logBackupExported() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'backup_exported');
  }

  static Future<void> logBackupActionCompleted({required String action}) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'backup_action_completed',
      parameters: {'action': action},
    );
  }

  static Future<void> logCloudSync({required bool isAutomatic}) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'cloud_sync_completed',
      parameters: {'is_automatic': isAutomatic ? 1 : 0},
    );
  }

  static Future<void> logCloudDataRestoreCompleted() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'cloud_data_restore_completed');
  }

  static Future<void> logCloudDataDeletionScheduled() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'cloud_data_deletion_scheduled');
  }

  static Future<void> logCloudDataDeletionCancelled() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'cloud_data_deletion_cancelled');
  }

  static Future<void> logSignOut() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'sign_out');
  }

  static Future<void> logAdvancedOptionsOpened() {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(name: 'advanced_options_opened');
  }

  static Future<void> logSupportActionOpened({
    required String source,
    required String target,
    required bool opened,
  }) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'support_action_opened',
      parameters: {
        'source': source,
        'target': target,
        'opened': opened ? 1 : 0,
      },
    );
  }

  static Future<void> logUiAction({
    required String screen,
    required String action,
  }) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'ui_action',
      parameters: {
        'screen': screen,
        'action': action,
      },
    );
  }

  static Future<void> logFormOpened({
    required String form,
    required String mode,
  }) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'form_opened',
      parameters: {
        'form': form,
        'mode': mode,
      },
    );
  }

  static Future<void> logFormFieldChanged({
    required String form,
    required String field,
  }) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'form_field_changed',
      parameters: {
        'form': form,
        'field': field,
      },
    );
  }

  static Future<void> logDialogAction({
    required String dialog,
    required String action,
  }) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'dialog_action',
      parameters: {
        'dialog': dialog,
        'action': action,
      },
    );
  }

  static Future<void> logAuthAction({
    required String action,
    required bool success,
  }) {
    if (!_isFirebaseReady) return Future<void>.value();
    return analytics.logEvent(
      name: 'auth_action',
      parameters: {
        'action': action,
        'success': success ? 1 : 0,
      },
    );
  }

  static bool get _isFirebaseReady => Firebase.apps.isNotEmpty;
}
