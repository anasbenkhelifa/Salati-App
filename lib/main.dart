import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_locale_controller.dart';
import 'core/localization/app_locale_provider.dart';
import 'presentation/navigation/app_shell.dart';
import 'notification_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize date formatting in parallel (not sequentially)
  await Future.wait([
    initializeDateFormatting('ar'),
    initializeDateFormatting('en'),
  ]);

  // NOTE: Hijri cache refresh moved to NotificationManager (non-blocking)
  // This prevents slow network from blocking app startup

  runApp(const AdhanApp());
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
