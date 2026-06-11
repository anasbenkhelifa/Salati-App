import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_provider.dart';
import '../widgets/pressable_scale.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../core/tour/tour_key_registry.dart';
import '../../core/tour/app_tour_service.dart';
import '../../domain/providers/qibla_provider.dart';
import '../../domain/providers/live_notification_provider.dart';
import '../../data/services/adhan_alarm_service.dart';
import '../widgets/app_option_tile.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import '../navigation/app_shell.dart';
import '../../notification_manager.dart';
import 'package:provider/provider.dart';
import '../../data/services/analytics_service.dart';

/// Controls screen with full-screen notification, compass haptics, and theme settings
class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  bool _compassHapticsEnabled = true;
  bool _maxVolumeOverrideEnabled = false;
  bool _preAdhanEnabled = false;
  bool _showSunriseEnabled = true;
  bool _isDisposed = false;

  // Live Notification Mode
  // 0: Disabled, 1: Static, 2: Dynamic
  int _liveNotifMode = 1;

  @override
  void initState() {
    super.initState();
    // Load initial state from provider
    _loadSettings();
    // Listen to provider changes
    QiblaProvider.instance?.addListener(_onProviderChange);
    AppThemeProvider.instance.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    _isDisposed = true;
    QiblaProvider.instance?.removeListener(_onProviderChange);
    AppThemeProvider.instance.removeListener(_onThemeChange);
    super.dispose();
  }

  void _loadSettings() async {
    // Load compass haptics from provider (or default to true)
    final provider = QiblaProvider.instance;
    if (provider != null) {
      _compassHapticsEnabled = provider.compassHapticsEnabled;
    }

    // Load max volume override setting
    final prefs = await SharedPreferences.getInstance();
    if (_isDisposed) return;
    if (mounted) {
      setState(() {
        _maxVolumeOverrideEnabled =
            prefs.getBool('max_volume_override') ?? false;
        _preAdhanEnabled = prefs.getBool('pre_adhan_enabled') ?? true;
        _showSunriseEnabled = prefs.getBool('show_sunrise') ?? true;
        _liveNotifMode = prefs.getInt('live_notification_mode') ?? 1;
      });
    }
  }

  void _onProviderChange() {
    // Update local state when provider changes
    if (mounted) {
      final provider = QiblaProvider.instance;
      if (provider != null &&
          _compassHapticsEnabled != provider.compassHapticsEnabled) {
        setState(() {
          _compassHapticsEnabled = provider.compassHapticsEnabled;
        });
      }
    }
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  void _setCompassHaptics(bool enabled) {
    // Update local state immediately for responsive UI
    setState(() {
      _compassHapticsEnabled = enabled;
    });
    // Update provider (which will persist)
    final provider = QiblaProvider.instance;
    if (provider != null) {
      provider.setCompassHaptics(enabled);
    } else {
      debugPrint('[ControlsScreen] Warning: QiblaProvider.instance is null');
    }
    AnalyticsService.instance.logCompassHapticsToggled(enabled);
  }

  void _showThemeSelector() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _ThemeSelectorSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);
    final isArabic = localeController.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.currentBackgroundGradient,
            image: AppTheme.currentBackgroundImage,
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Header with back button and title
                _buildHeader(context, isArabic),
                const SizedBox(height: 24),
                // Settings list
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ListView(
                      children: [
                        // Compass haptics toggle
                        AppOptionTile.toggle(
                          icon: Icons.vibration,
                          title: t(context, 'compassHaptics'),
                          value: _compassHapticsEnabled,
                          onChanged: _setCompassHaptics,
                        ),
                        const SizedBox(height: 12),
                        // Max volume override toggle
                        AppOptionTile.toggle(
                          icon: Icons.volume_up,
                          title: t(context, 'maxVolumeAdhan'),
                          subtitle: t(context, 'maxVolumeAdhanDesc'),
                          value: _maxVolumeOverrideEnabled,
                          onChanged: (val) async {
                            setState(() => _maxVolumeOverrideEnabled = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('max_volume_override', val);
                            AnalyticsService.instance.logMaxVolumeToggled(val);
                          },
                        ),
                        const SizedBox(height: 12),
                        // Pre-adhan reminder toggle
                        AppOptionTile.toggle(
                          icon: Icons.notifications_active,
                          title: t(context, 'preAdhanReminder'),
                          subtitle: t(context, 'preAdhanReminderDesc'),
                          value: _preAdhanEnabled,
                          onChanged: (val) async {
                            setState(() => _preAdhanEnabled = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('pre_adhan_enabled', val);
                            // Reschedule all alarms to add/remove pre-adhan reminders
                            await AdhanAlarmService.rescheduleAllAlarms();
                            AnalyticsService.instance.logPreAdhanToggled(val);
                          },
                        ),
                        const SizedBox(height: 12),
                        // Sunrise (Shuruq) row on the Prayer Times screen
                        AppOptionTile.toggle(
                          icon: Icons.wb_twilight,
                          title: t(context, 'showSunrise'),
                          value: _showSunriseEnabled,
                          onChanged: (val) async {
                            setState(() => _showSunriseEnabled = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('show_sunrise', val);
                          },
                        ),
                        const SizedBox(height: 12),
                        // Live Notification Mode
                        AppOptionTile.navigation(
                          icon: Icons.notifications_active_outlined,
                          title: t(context, 'liveNotificationMode'),
                          subtitle: _getLiveNotifModeString(context),
                          onTap: _showLiveNotifModeSelector,
                        ),
                        const SizedBox(height: 12),
                        // Theme picker
                        AppOptionTile.navigation(
                          key: TourKeyRegistry.instance.themeTileKey,
                          icon: Icons.palette_outlined,
                          title: t(context, 'chooseTheme'),
                          subtitle: _getThemeSubtitle(context),
                          onTap: _showThemeSelector,
                        ),
                        const SizedBox(height: 12),
                        // Prayer Calculation Method
                        _buildPrayerMethodSelector(context),
                        const SizedBox(height: 12),
                        // Battery optimization for Adhan reliability
                        AppOptionTile.navigation(
                          icon: Icons.battery_saver,
                          title: t(context, 'batteryOpt'),
                          subtitle: t(context, 'batteryOptDesc'),
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await AdhanAlarmService.openBatterySettings();
                          },
                        ),
                        const SizedBox(height: 12),
                        // Replay Tour
                        AppOptionTile.navigation(
                          icon: Icons.school_outlined,
                          title: t(context, 'replayTour'),
                          onTap: () {
                            // Pop back to AppShell first
                            Navigator.of(context).pop();
                            // Wait for frame to settle, then use AppShell's persistent context
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              final ctx = AppShell.activeContext;
                              final pc = AppShell.activePageController;
                              if (ctx != null && ctx.mounted && pc != null) {
                                AppTourService.replayTour(ctx, pc);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getLiveNotifModeString(BuildContext context) {
    switch (_liveNotifMode) {
      case 0:
        return t(context, 'lnDisabled');
      case 2:
        return t(context, 'lnDynamic');
      case 1:
      default:
        return t(context, 'lnStatic');
    }
  }

  void _showLiveNotifModeSelector() {
    HapticFeedback.lightImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder:
          (context) => StatefulBuilder(
            builder: (context, setModalState) {
              return Container(
                decoration: BoxDecoration(
                  color:
                      AppTheme.isLightMode
                          ? Colors.white
                          : (AppTheme.isIslamicMode
                              ? AppTheme.islamicPrimaryNavy
                              : const Color(0xFF1B263B)),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 16),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.currentTextSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t(context, 'liveNotificationMode'),
                        style: TextStyle(
                          color: AppTheme.currentTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildModeOption(
                        0,
                        t(context, 'lnDisabled'),
                        Icons.notifications_off_outlined,
                        setModalState,
                      ),
                      _buildModeOption(
                        1,
                        t(context, 'lnStatic'),
                        Icons.notifications_active,
                        setModalState,
                      ),
                      _buildModeOption(
                        2,
                        t(context, 'lnDynamic'),
                        Icons.auto_awesome,
                        setModalState,
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
    );
  }

  Widget _buildModeOption(
    int mode,
    String label,
    IconData icon,
    StateSetter setModalState,
  ) {
    final isSelected = _liveNotifMode == mode;
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        setModalState(() => _liveNotifMode = mode);
        setState(() => _liveNotifMode = mode);

        Future.delayed(const Duration(milliseconds: 150), () async {
          if (!mounted) return;
          Navigator.pop(context);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('live_notification_mode', mode);
          AnalyticsService.instance.logLiveNotifModeChanged(mode);

          if (mounted) {
            NotificationManager.instance?.provider.refreshMode();
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        color:
            isSelected
                ? AppTheme.currentActiveGlow.withValues(alpha: 0.1)
                : Colors.transparent,
        child: Row(
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? AppTheme.currentActiveGlow
                      : AppTheme.currentTextSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color:
                      isSelected
                          ? AppTheme.currentActiveGlow
                          : AppTheme.currentTextPrimary,
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: AppTheme.currentActiveGlow),
          ],
        ),
      ),
    );
  }

  String _getThemeSubtitle(BuildContext context) {
    if (AppTheme.isLightMode) return t(context, 'lightMode');
    if (AppTheme.isNightMode) return t(context, 'nightMode');
    if (AppTheme.isIslamicGreenMode) return t(context, 'islamicGreenMode');
    if (AppTheme.isIslamicSpecialMode) return t(context, 'islamicSpecialMode');
    if (AppTheme.isIslamicMode) return t(context, 'islamicMode');
    return t(context, 'nightMode');
  }

  Widget _buildHeader(BuildContext context, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // Back button
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              isArabic ? Icons.arrow_forward_ios : Icons.arrow_back_ios,
              color: AppTheme.currentTextPrimary,
            ),
          ),
          // Title
          Expanded(
            child: Center(
              child: Text(
                t(context, 'controlsTitle'),
                style: TextStyle(
                  color: AppTheme.currentTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Spacer to balance the back button
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildPrayerMethodSelector(BuildContext context) {
    final provider = PrayerTimesApiProvider.instance;
    final isArabic = AppLocaleProvider.of(context).isArabic;

    // Determine subtitle
    String subtitle = '';
    if (!provider.isManualMethod) {
      final methodName =
          isArabic ? provider.method.nameAr : provider.method.nameEn;
      subtitle = t(
        context,
        'calcMethodAuto',
      ).replaceAll('{method}', methodName);
    } else {
      subtitle = isArabic ? provider.method.nameAr : provider.method.nameEn;
    }

    return AppOptionTile.navigation(
      icon: Icons.calculate_outlined,
      title: t(context, 'calcMethod'),
      subtitle: subtitle,
      onTap: () => _showMethodSelector(context, provider),
    );
  }

  void _showMethodSelector(
    BuildContext context,
    PrayerTimesApiProvider provider,
  ) {
    HapticFeedback.lightImpact();
    final isArabic = AppLocaleProvider.of(context).isArabic;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: BoxDecoration(
              color:
                  AppTheme.isLightMode
                      ? Colors.white
                      : (AppTheme.isIslamicMode
                          ? AppTheme.islamicPrimaryNavy
                          : const Color(0xFF1B263B)),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.currentTextSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                // Title
                Text(
                  t(context, 'calcMethod'),
                  style: TextStyle(
                    color: AppTheme.currentTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    children: [
                      // Automatic Option
                      _buildMethodOption(
                        context: context,
                        title: t(
                          context,
                          'calcMethodAuto',
                        ).replaceAll(' ({method})', ''),
                        subtitle: t(context, 'calcMethodAutoDesc'),
                        isSelected: !provider.isManualMethod,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await provider.autoDetectMethod();
                          AnalyticsService.instance.logCalculationMethodChanged('auto');
                          if (context.mounted) Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 12),
                      Divider(color: AppTheme.currentDivider),
                      const SizedBox(height: 12),
                      // Manual Options
                      ...CalculationMethodId.values.map((method) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: _buildMethodOption(
                            context: context,
                            title: isArabic ? method.nameAr : method.nameEn,
                            isSelected:
                                provider.isManualMethod &&
                                provider.method == method,
                            onTap: () async {
                              HapticFeedback.lightImpact();
                              await provider.setMethod(method, isManual: true);
                              AnalyticsService.instance.logCalculationMethodChanged(method.nameEn);
                              if (context.mounted) Navigator.pop(context);
                            },
                          ),
                        );
                      }),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildMethodOption({
    required BuildContext context,
    required String title,
    String? subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.currentActiveGlow.withValues(alpha: 0.1)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected
                    ? AppTheme.currentActiveGlow.withValues(alpha: 0.5)
                    : AppTheme.inactiveBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color:
                          isSelected
                              ? AppTheme.currentActiveGlow
                              : AppTheme.currentTextPrimary,
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.currentTextSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.currentActiveGlow,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}

/// Theme selector bottom sheet with Apple-style cards
class _ThemeSelectorSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocaleProvider.of(context).isArabic;
    final currentMode = AppThemeProvider.instance.mode;

    return Container(
      decoration: BoxDecoration(
        color:
            AppTheme.isLightMode
                ? Colors.white
                : (AppTheme.isIslamicSpecialMode
                    ? AppTheme.islamicSpecialPrimary
                    : (AppTheme.isIslamicGreenMode
                        ? AppTheme.islamicGreenPrimary
                        : (AppTheme.isIslamicMode
                            ? AppTheme.islamicPrimaryNavy
                            : const Color(0xFF1B263B)))),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.currentTextSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Title
          Text(
            t(context, 'chooseTheme'),
            style: TextStyle(
              color: AppTheme.currentTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          // Theme cards
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.5,
            children: [
              // Night Mode
              _ThemeCard(
                title: t(context, 'nightMode'),
                icon: Icons.dark_mode_rounded,
                isSelected: currentMode == AppThemeMode.night,
                previewGradient: AppTheme.nightBackgroundGradient,
                accent: AppTheme.nightActiveGlow,
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppThemeProvider.instance.setTheme(AppThemeMode.night);
                  Navigator.pop(context);
                },
              ),
              // Light Mode
              _ThemeCard(
                title: t(context, 'lightMode'),
                icon: Icons.light_mode_rounded,
                isSelected: currentMode == AppThemeMode.light,
                previewGradient: AppTheme.lightBackgroundGradient,
                accent: AppTheme.lightAccentBlue,
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppThemeProvider.instance.setTheme(AppThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              // Islamic (Blue) — Andalusian lapis & gold
              _ThemeCard(
                title: t(context, 'islamicMode'),
                icon: Icons.mosque_outlined,
                isSelected: currentMode == AppThemeMode.islamic,
                previewGradient: AppTheme.islamicBackgroundGradient,
                accent: AppTheme.islamicActiveGlow,
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppThemeProvider.instance.setTheme(AppThemeMode.islamic);
                  Navigator.pop(context);
                },
              ),
              // Islamic (Green)
              _ThemeCard(
                title: t(context, 'islamicGreenMode'),
                icon: Icons.mosque_outlined,
                isSelected: currentMode == AppThemeMode.islamicGreen,
                previewGradient: AppTheme.islamicGreenBackgroundGradient,
                accent: AppTheme.islamicGreenActiveGlow,
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppThemeProvider.instance.setTheme(AppThemeMode.islamicGreen);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Individual theme selection card
class _ThemeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final LinearGradient previewGradient;
  final Color accent;
  final VoidCallback onTap;

  const _ThemeCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.previewGradient,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          gradient: previewGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.currentActiveGlow : Colors.transparent,
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: AppTheme.currentActiveGlow.withValues(alpha: 0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                  : null,
        ),
        child: Column(
          children: [
            // Icon tinted in the theme's accent so each card telegraphs
            // its palette (gold for Islamic, cyan for Night, ...)
            Icon(
              icon,
              size: 36,
              color: accent,
              shadows: [Shadow(color: accent.withValues(alpha: 0.6), blurRadius: 12)],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color:
                    previewGradient == AppTheme.lightBackgroundGradient
                        ? AppTheme.lightTextPrimary
                        : AppTheme.nightTextPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            // Checkmark
            AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isSelected ? 1.0 : 0.0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppTheme.currentActiveGlow,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, size: 16, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
