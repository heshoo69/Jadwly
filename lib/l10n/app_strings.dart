import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/app_controller.dart';

class AppStrings {
  const AppStrings(this.languageCode);

  final String languageCode;

  static AppStrings of(BuildContext context) {
    return AppStrings(context.watch<AppController>().languageCode);
  }

  static AppStrings read(BuildContext context) {
    return AppStrings(context.read<AppController>().languageCode);
  }

  bool get isEnglish => languageCode == 'en';

  TextDirection get textDirection =>
      isEnglish ? TextDirection.ltr : TextDirection.rtl;

  String get appName => isEnglish ? 'Jadwly' : 'جدولي';
  String get today => isEnglish ? 'Today' : 'اليوم';
  String get schedule => isEnglish ? 'Schedule' : 'الجدول';
  String get classes => isEnglish ? 'Classes' : 'الفصول';
  String get settings => isEnglish ? 'Settings' : 'الإعدادات';
  String get todaysSchedule => isEnglish ? "Today's schedule" : 'جدول اليوم';
  String get upcomingClasses =>
      isEnglish ? 'Upcoming classes' : 'الحصص القادمة';
  String get periods => isEnglish ? 'classes' : 'حصص';
  String get addTodayClass => isEnglish ? 'Add today class' : 'إضافة حصة اليوم';
  String get noClassesToday =>
      isEnglish ? 'No classes today' : 'لا توجد حصص اليوم';
  String get noClassesTodayMessage => isEnglish
      ? 'Enjoy a quiet day, or add your weekly schedule from the schedule tab.'
      : 'استمتع بيوم هادئ، أو أضف جدولك الأسبوعي من تبويب الجدول.';
  String get lastLesson => isEnglish ? 'Last lesson' : 'آخر درس';
  String get noLessonRecorded =>
      isEnglish ? 'No lesson recorded yet' : 'لا يوجد درس مسجل بعد';
  String get unknownClass => isEnglish ? 'Unknown class' : 'فصل غير معروف';
  String get deletedClass => isEnglish ? 'Deleted class' : 'فصل محذوف';
  String room(String room) => isEnglish ? 'Room $room' : 'غرفة $room';

  String get addClass => isEnglish ? 'New class' : 'فصل جديد';
  String get noClasses => isEnglish ? 'No classes' : 'لا توجد فصول';
  String get noClassesMessage => isEnglish
      ? 'Add your classes to record lessons and track where you stopped.'
      : 'أضف فصولك لتسجيل الدروس ومتابعة آخر نقطة توقفت عندها.';
  String get edit => isEnglish ? 'Edit' : 'تعديل';
  String get delete => isEnglish ? 'Delete' : 'حذف';
  String get cancel => isEnglish ? 'Cancel' : 'إلغاء';
  String get save => isEnglish ? 'Save' : 'حفظ';
  String get confirmDelete => isEnglish ? 'Confirm delete' : 'تأكيد الحذف';
  String deleteClassMessage(String className) => isEnglish
      ? 'Are you sure you want to delete "$className"? The class schedule and lesson history will also be deleted.'
      : 'هل أنت متأكد من حذف الفصل "$className"؟ سيتم حذف جدول هذا الفصل وسجل الدروس المرتبط به.';

  String get newLesson => isEnglish ? 'New lesson' : 'درس جديد';
  String get lessonHistory => isEnglish ? 'Lesson history' : 'سجل الدروس';
  String get noLessons => isEnglish ? 'No lessons' : 'لا توجد دروس';
  String get noLessonsMessage => isEnglish
      ? 'Start by recording the first lesson for this class.'
      : 'ابدأ بتسجيل أول درس لهذا الفصل.';
  String get recordLesson => isEnglish ? 'Record lesson' : 'تسجيل درس';
  String get selectClass => isEnglish ? 'Select class' : 'اختر الفصل';
  String get classLabel => isEnglish ? 'Class' : 'الفصل';
  String get lessonTitle => isEnglish ? 'Lesson title' : 'عنوان الدرس';
  String get lessonTitleRequired =>
      isEnglish ? 'Lesson title is required' : 'عنوان الدرس مطلوب';
  String get editLesson => isEnglish ? 'Edit lesson' : 'تعديل الدرس';
  String get updateLesson => isEnglish ? 'Update lesson' : 'تحديث الدرس';
  String get deleteLesson => isEnglish ? 'Delete lesson' : 'حذف الدرس';
  String get deleteLessonTitle => isEnglish ? 'Delete lesson?' : 'حذف الدرس؟';
  String deleteLessonMessage(String lessonTitle) => isEnglish
      ? 'Are you sure you want to delete "$lessonTitle" from the lesson history?'
      : 'هل أنت متأكد من حذف "$lessonTitle" من سجل الدروس؟';
  String get sessionType => isEnglish ? 'Session type' : 'نوع الحصة';
  String get completionStatus =>
      isEnglish ? 'Completion status' : 'حالة الإنجاز';
  String get date => isEnglish ? 'Date' : 'التاريخ';
  String get notes => isEnglish ? 'Notes' : 'ملاحظات';
  String get saveLesson => isEnglish ? 'Save lesson' : 'حفظ الدرس';

  String get addScheduleItem => isEnglish ? 'New period' : 'حصة جديدة';
  String get weeklySchedule =>
      isEnglish ? 'Weekly schedule' : 'الجدول الأسبوعي';
  String get dailySchedule => isEnglish ? 'Daily list' : 'الشكل الخطي';
  String get weeklyGridView => isEnglish ? 'Weekly grid' : 'الشكل الأسبوعي';
  String get switchToDaily => isEnglish ? 'Show daily list' : 'عرض الشكل الخطي';
  String get switchToWeekly =>
      isEnglish ? 'Show weekly grid' : 'عرض الشكل الأسبوعي';
  String get emptyGridNote => isEnglish
      ? 'Periods without a number appear in the daily list only.'
      : 'الحصص بدون رقم تظهر في الشكل الخطي فقط.';
  String get addPeriod => isEnglish ? 'Add period' : 'إضافة حصة';
  String get editPeriod => isEnglish ? 'Edit period' : 'تعديل حصة';
  String get noPeriods => isEnglish ? 'No periods' : 'لا توجد حصص';
  String noPeriodsForDay(String day) => isEnglish
      ? 'Add periods for $day using the add button.'
      : 'أضف حصص يوم $day من زر الإضافة.';
  String periodNumber(int number) =>
      isEnglish ? 'Period $number' : 'حصة $number';
  String get period => isEnglish ? 'Period' : 'حصة';
  String get thisPeriod => isEnglish ? 'this period' : 'هذه الحصة';
  String get day => isEnglish ? 'Day' : 'اليوم';
  String get periodNumberOptional =>
      isEnglish ? 'Period number (optional)' : 'رقم الحصة (اختياري)';
  String get invalidNumber =>
      isEnglish ? 'Enter a valid number' : 'أدخل رقماً صحيحاً';
  String get startTime => isEnglish ? 'Start time' : 'وقت البداية';
  String get endTime => isEnglish ? 'End time' : 'وقت النهاية';
  String get startTimeRequired =>
      isEnglish ? 'Start time is required' : 'وقت البداية مطلوب';
  String get endTimeRequired =>
      isEnglish ? 'End time is required' : 'وقت النهاية مطلوب';
  String get subject => isEnglish ? 'Subject' : 'المادة';
  String get className => isEnglish ? 'Class name' : 'اسم الفصل';
  String get classNameRequired =>
      isEnglish ? 'Class name is required' : 'اسم الفصل مطلوب';
  String get subjectRequired =>
      isEnglish ? 'Subject is required' : 'اسم المادة مطلوب';
  String get roomOptional =>
      isEnglish ? 'Room number (optional)' : 'رقم الغرفة (اختياري)';
  String deletePeriodMessage(String itemLabel) => isEnglish
      ? 'Are you sure you want to delete $itemLabel from the schedule?'
      : 'هل أنت متأكد من حذف $itemLabel من الجدول؟';

  String get account => isEnglish ? 'Account' : 'الحساب';
  String get teacherName => isEnglish ? 'Teacher name' : 'اسم المعلم';
  String get saveName => isEnglish ? 'Save name' : 'حفظ الاسم';
  String get preferences => isEnglish ? 'Preferences' : 'التفضيلات';
  String get weekSettings => isEnglish ? 'Week settings' : 'إعدادات الأسبوع';
  String get weekStart => isEnglish ? 'Week starts on' : 'بداية الأسبوع';
  String get showWeekends =>
      isEnglish ? 'Show weekend days' : 'إظهار أيام الويكند';
  String get showWeekendsHelp => isEnglish
      ? 'Friday and Saturday will appear in the weekly schedule.'
      : 'ستظهر الجمعة والسبت في الجدول الأسبوعي.';
  String get developedBy =>
      isEnglish ? 'Developed by HAF-DEV' : 'تم تطوير التطبيق من قبل HAF-DEV';
  String get openDeveloperSite =>
      isEnglish ? 'Open haf-dev.com' : 'فتح haf-dev.com';
  String get supportAndContact =>
      isEnglish ? 'Support & Contact' : 'الدعم والتواصل';
  String get whatsappSupport =>
      isEnglish ? 'WhatsApp Support' : 'الدعم عبر واتساب';
  String get supportEmail => isEnglish ? 'Support Email' : 'بريد الدعم';
  String get website => isEnglish ? 'Website' : 'الموقع الإلكتروني';
  String get openInWhatsapp =>
      isEnglish ? 'Open in WhatsApp' : 'فتح عبر واتساب';
  String get openEmailApp => isEnglish ? 'Open email app' : 'فتح تطبيق البريد';
  String get openWebsite => isEnglish ? 'Open website' : 'فتح الموقع';
  String get settingsFooterCopyright => '© 2026 HAF-DEV';
  String get language => isEnglish ? 'Language' : 'اللغة';
  String get arabic => isEnglish ? 'Arabic' : 'العربية';
  String get english => isEnglish ? 'English' : 'English';
  String get chooseLanguage => isEnglish ? 'Choose language' : 'اختر اللغة';
  String get notifications => isEnglish ? 'Notifications' : 'الإشعارات';
  String get enableClassReminders =>
      isEnglish ? 'Enable class reminders' : 'تفعيل تنبيهات الحصص';
  String get remindersHelp => isEnglish
      ? 'A reminder will show before class with the last lesson and status.'
      : 'سيظهر تنبيه قبل الحصة يتضمن آخر درس وحالة الإنجاز.';
  String get reminderTime =>
      isEnglish ? 'Reminder time before class' : 'وقت التذكير قبل الحصة';
  String minutes(int value) => isEnglish ? '$value minutes' : '$value دقائق';
  String get data => isEnglish ? 'Data' : 'البيانات';
  String get addDemoData =>
      isEnglish ? 'Add demo data' : 'إضافة بيانات تجريبية';
  String get demoDataAdded =>
      isEnglish ? 'Demo data has been added.' : 'تمت إضافة البيانات التجريبية.';
  String get clearLocalData =>
      isEnglish ? 'Clear all local data' : 'مسح كل البيانات المحلية';
  String get notificationsDenied => isEnglish
      ? 'Notifications were not enabled because permission was not granted.'
      : 'لم يتم تفعيل الإشعارات لأن صلاحية التنبيه غير ممنوحة.';
  String get clearDataTitle => isEnglish ? 'Clear data?' : 'مسح البيانات؟';
  String get clearDataMessage => isEnglish
      ? 'Classes, schedule, and lesson history will be deleted from this device.'
      : 'سيتم حذف الفصول والجدول وسجل الدروس من هذا الجهاز.';
  String get clear => isEnglish ? 'Clear' : 'مسح';
  String get backup => isEnglish ? 'Backup' : 'النسخ الاحتياطي';
  String get backupDescription => isEnglish
      ? 'A backup is saved automatically after every change.'
      : 'يتم حفظ نسخة احتياطية تلقائيًا بعد كل تعديل.';
  String get lastBackup => isEnglish ? 'Last backup:' : 'آخر نسخة احتياطية:';
  String get noBackupYet =>
      isEnglish ? 'No automatic backup yet' : 'لا توجد نسخة احتياطية بعد';
  String get automaticBackupFailed => isEnglish
      ? 'Automatic backup could not be created'
      : 'تعذر إنشاء النسخة الاحتياطية تلقائيًا';
  String get saveBackupNow => isEnglish ? 'Save a copy now' : 'حفظ نسخة الآن';
  String get restoreLatestAutomaticBackup => isEnglish
      ? 'Restore latest automatic backup'
      : 'استعادة آخر نسخة تلقائية';
  String get restoreBackupTitle =>
      isEnglish ? 'Restore backup?' : 'استعادة النسخة الاحتياطية؟';
  String get restoreBackupMessage => isEnglish
      ? 'Restoring the backup will replace the current data inside the app. Do you want to continue?'
      : 'استعادة النسخة الاحتياطية ستستبدل البيانات الحالية داخل التطبيق.\nهل تريد المتابعة؟';
  String get restore => isEnglish ? 'Restore' : 'استعادة';
  String get backupRestored => isEnglish
      ? 'Backup has been restored.'
      : 'تمت استعادة النسخة الاحتياطية.';
  String get backupSaved =>
      isEnglish ? 'Backup has been saved.' : 'تم حفظ النسخة الاحتياطية.';
  String get invalidBackupFile => isEnglish
      ? 'The backup file is invalid'
      : 'ملف النسخة الاحتياطية غير صالح';
  String get unsupportedBackupVersion => isEnglish
      ? 'The backup version is not supported'
      : 'إصدار النسخة الاحتياطية غير مدعوم';
  String get restoreBackupFailed =>
      isEnglish ? 'Could not restore data' : 'تعذر استعادة البيانات';
  String get advancedOptions =>
      isEnglish ? 'Advanced options' : 'خيارات متقدمة';
  String get restoreFromFile =>
      isEnglish ? 'Restore from file' : 'استعادة من ملف';
  String get exportBackupFile =>
      isEnglish ? 'Share backup file' : 'مشاركة ملف النسخة الاحتياطية';
  String get backupFileReady =>
      isEnglish ? 'Backup file is ready.' : 'تم تجهيز ملف النسخة الاحتياطية';
  String get exportBackupFailed => isEnglish
      ? 'Could not export the backup file'
      : 'تعذر تصدير ملف النسخة الاحتياطية';
  String get saveBackupToFiles =>
      isEnglish ? 'Save to Files' : 'حفظ في الملفات';
  String get backupFileSaved => isEnglish
      ? 'Backup file has been saved.'
      : 'تم حفظ ملف النسخة الاحتياطية';
  String get saveBackupFileFailed => isEnglish
      ? 'Could not save the backup file'
      : 'تعذر حفظ ملف النسخة الاحتياطية';

  String get addClassTitle => isEnglish ? 'Add class' : 'إضافة فصل';
  String get editClassTitle => isEnglish ? 'Edit class' : 'تعديل فصل';
}
