import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_provider.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/localization/app_locale_provider.dart';
import 'presentation/navigation/app_shell.dart';
import 'package:provider/provider.dart';
import 'notification_manager.dart';
import 'data/services/adhan_selection_service.dart';
import 'domain/providers/prayer_times_api_provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'data/services/analytics_service.dart';
import 'data/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  // Initialize Firebase First
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Log app open and set user properties for analytics segmentation
  AnalyticsService.instance.logAppOpened();
  AnalyticsService.instance.setUserProperties();

  // Register the device for push notifications (FCM) — non-blocking.
  PushNotificationService.instance.initialize();

  // Initialize date formatting and theme in parallel
  await Future.wait([
    initializeDateFormatting('ar'),
    initializeDateFormatting('en'),
    initializeDateFormatting('fr'),
    AppThemeProvider.instance.initialize(),
    AdhanSelectionService.instance.initialize(),
  ]);

  // Initialize PrayerTimes centrally
  await PrayerTimesApiProvider.instance.initialize();

  runApp(
    ChangeNotifierProvider.value(
      value: PrayerTimesApiProvider.instance,
      child: const AdhanApp(),
    ),
  );
}

class AdhanApp extends StatefulWidget {
  const AdhanApp({super.key});

  @override
  State<AdhanApp> createState() => _AdhanAppState();
}

class _AdhanAppState extends State<AdhanApp> {
  final AppLocaleController _localeController = AppLocaleController();

  @override
  void initState() {
    super.initState();
    // Initialize locale from saved preference (ensures native code gets correct language)
    _localeController.initialize();
    // Listen to theme changes
    AppThemeProvider.instance.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    AppThemeProvider.instance.removeListener(_onThemeChange);
    _localeController.dispose();
    super.dispose();
  }

  void _onThemeChange() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AppLocaleProvider(
      controller: _localeController,
      child: AnimatedBuilder(
        animation: _localeController,
        builder: (context, child) {
          return MaterialApp(
            title: 'أذان',
            debugShowCheckedModeBanner: false,

            // Locale from controller
            locale: _localeController.locale,
            supportedLocales: const [Locale('ar'), Locale('en'), Locale('fr')],

            // Localization delegates for proper MaterialLocalizations
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],

            // Safe builder: just wrap child with Directionality, don't break inheritance
            builder: (context, child) {
              return Directionality(
                textDirection: _localeController.textDirection,
                child: child ?? const SizedBox.shrink(),
              );
            },

            // Theme - uses current mode
            theme: AppTheme.currentTheme,

            // Home with notification manager
            home: const NotificationManager(child: AppShell()),
          );
        },
      ),
    );
  }
}
