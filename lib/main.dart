import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/localization/app_locale_provider.dart';
import 'presentation/navigation/app_shell.dart';
import 'notification_manager.dart';
import 'data/services/hijri_date_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting for Arabic and English
  await initializeDateFormatting('ar');
  await initializeDateFormatting('en');

  // Clear stale Hijri cache and fetch fresh date
  await _refreshHijriCache();

  runApp(const AdhanApp());
}

/// Refresh Hijri cache from API if online, otherwise keep existing cache
Future<void> _refreshHijriCache() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final hijriService = HijriDateService();
    final today = DateTime.now();

    // Try to fetch fresh Hijri date from API
    final hijriDate = await hijriService.getHijriDate(today);

    if (hijriDate != null) {
      // API succeeded - we have fresh data (getHijriDate already cached it)
      debugPrint('[Main] Fresh Hijri cached: ${hijriDate.formatEnglish()}');

      // Clear any old stale component keys that might have wrong values
      await prefs.remove('cached_hijri_day');
      await prefs.remove('cached_hijri_month');
      await prefs.remove('cached_hijri_year');
      await prefs.remove('cached_hijri_month_ar');
      await prefs.remove('cached_hijri_month_en');
    } else {
      // API failed (offline) - keep using existing cache
      debugPrint('[Main] Offline - using existing Hijri cache');
    }
  } catch (e) {
    debugPrint('[Main] Error refreshing Hijri: $e');
  }
}

class AdhanApp extends StatefulWidget {
  const AdhanApp({super.key});

  @override
  State<AdhanApp> createState() => _AdhanAppState();
}

class _AdhanAppState extends State<AdhanApp> {
  final AppLocaleController _localeController = AppLocaleController();

  @override
  void dispose() {
    _localeController.dispose();
    super.dispose();
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

            // Apply text direction based on locale
            builder: (context, child) {
              return Directionality(
                textDirection: _localeController.textDirection,
                child: child!,
              );
            },

            // Theme
            theme: AppTheme.darkTheme,

            // Home with notification manager
            home: const NotificationManager(child: AppShell()),
          );
        },
      ),
    );
  }
}
