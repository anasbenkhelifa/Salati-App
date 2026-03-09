import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_theme_provider.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/localization/app_locale_provider.dart';
import 'presentation/navigation/app_shell.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'package:provider/provider.dart';
import 'notification_manager.dart';
import 'data/services/adhan_selection_service.dart';
import 'domain/providers/prayer_times_api_provider.dart';
import 'package:timezone/data/latest.dart' as tz_data;

/// Whether the onboarding has been completed (checked once at startup)
late final bool _onboardingComplete;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  // Initialize date formatting and theme in parallel
  await Future.wait([
    initializeDateFormatting('ar'),
    initializeDateFormatting('en'),
    AppThemeProvider.instance.initialize(),
    AdhanSelectionService.instance.initialize(),
  ]);

  // Check onboarding status
  final prefs = await SharedPreferences.getInstance();
  _onboardingComplete = prefs.getBool('onboarding_complete') ?? false;

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
            supportedLocales: const [Locale('ar'), Locale('en')],

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

            // Home: Onboarding on first launch, or main app
            home: _onboardingComplete
                ? const NotificationManager(child: AppShell())
                : _OnboardingWrapper(),
          );
        },
      ),
    );
  }
}

/// Wrapper that shows onboarding and navigates to main app on completion
class _OnboardingWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      onComplete: () {
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const NotificationManager(child: AppShell()),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 600),
          ),
          (route) => false,
        );
      },
    );
  }
}

