import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';

import 'controllers/app_controller.dart';
import 'firebase_options.dart';
import 'l10n/app_strings.dart';
import 'screens/splash_screen.dart';
import 'services/analytics_service.dart';
import 'services/app_feedback_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseAnalytics.instance.setAnalyticsCollectionEnabled(true);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await SupabaseService.initialize();
  await StorageService.init();
  await NotificationService.init();
  runApp(const JadwaliApp());
}

class JadwaliApp extends StatelessWidget {
  const JadwaliApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppController(),
      child: Consumer<AppController>(
        builder: (context, controller, _) {
          final strings = AppStrings(controller.languageCode);
          return MaterialApp(
            scaffoldMessengerKey: AppFeedbackService.scaffoldMessengerKey,
            title: strings.appName,
            debugShowCheckedModeBanner: false,
            locale: Locale(controller.languageCode),
            supportedLocales: const [Locale('ar'), Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            builder: (context, child) {
              return Directionality(
                textDirection: strings.textDirection,
                child: child ?? const SizedBox.shrink(),
              );
            },
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            navigatorObservers: [AnalyticsService.observer],
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
