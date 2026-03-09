import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_provider.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/qibla_provider.dart';
import '../../data/services/adhan_alarm_service.dart';
import '../widgets/app_option_tile.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import 'package:provider/provider.dart';

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
    if (mounted) {
      setState(() {
        _maxVolumeOverrideEnabled =
            prefs.getBool('max_volume_override') ?? false;
        _preAdhanEnabled = prefs.getBool('pre_adhan_enabled') ?? false;
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
                          title:
                              isArabic ? 'أقصى صوت للأذان' : 'Max Volume Adhan',
                          subtitle:
                              isArabic
                                  ? 'يشغل الأذان بأعلى صوت مهما كان مستوى الصوت'
                                  : 'Play adhan at max volume regardless of system volume',
                          value: _maxVolumeOverrideEnabled,
                          onChanged: (val) async {
                            setState(() => _maxVolumeOverrideEnabled = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('max_volume_override', val);
                          },
                        ),
                        const SizedBox(height: 12),
                        // Pre-adhan reminder toggle
                        AppOptionTile.toggle(
                          icon: Icons.notifications_active,
                          title:
                              isArabic
                                  ? 'تذكير قبل الأذان'
                                  : 'Pre-Adhan Reminder',
                          subtitle:
                              isArabic
                                  ? 'تنبيه قبل 15 دقيقة من وقت الصلاة'
                                  : 'Get notified 15 minutes before prayer',
                          value: _preAdhanEnabled,
                          onChanged: (val) async {
                            setState(() => _preAdhanEnabled = val);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setBool('pre_adhan_enabled', val);
                            // Reschedule all alarms to add/remove pre-adhan reminders
                            await AdhanAlarmService.rescheduleAllAlarms();
                          },
                        ),
                        const SizedBox(height: 12),
                        // Theme picker
                        AppOptionTile.navigation(
                          icon: Icons.palette_outlined,
                          title: t(context, 'chooseTheme'),
                          subtitle:
                              AppTheme.isLightMode
                                  ? t(context, 'lightMode')
                                  : (AppTheme.isIslamicMode
                                      ? t(context, 'islamicMode')
                                      : t(context, 'nightMode')),
                          onTap: _showThemeSelector,
                        ),
                        const SizedBox(height: 12),
                        // Prayer Calculation Method
                        _buildPrayerMethodSelector(context),
                        const SizedBox(height: 12),
                        // Battery optimization for Adhan reliability
                        AppOptionTile.navigation(
                          icon: Icons.battery_saver,
                          title:
                              isArabic
                                  ? 'تحسين البطارية'
                                  : 'Battery Optimization',
                          subtitle:
                              isArabic
                                  ? 'اختر "بدون قيود" لموثوقية الأذان'
                                  : 'Set to "Unrestricted" for Adhan reliability',
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            await AdhanAlarmService.openBatterySettings();
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
    final provider = context.watch<PrayerTimesApiProvider>();
    final isArabic = AppLocaleProvider.of(context).isArabic;

    // Determine subtitle
    String subtitle = '';
    if (!provider.isManualMethod) {
      subtitle = isArabic
          ? 'تلقائي (${provider.method.nameAr})'
          : 'Automatic (${provider.method.nameEn})';
    } else {
      subtitle = isArabic ? provider.method.nameAr : provider.method.nameEn;
    }

    return AppOptionTile.navigation(
      icon: Icons.calculate_outlined,
      title: isArabic ? 'طريقة الحساب' : 'Calculation Method',
      subtitle: subtitle,
      onTap: () => _showMethodSelector(context, provider),
    );
  }

  void _showMethodSelector(BuildContext context, PrayerTimesApiProvider provider) {
    HapticFeedback.lightImpact();
    final isArabic = AppLocaleProvider.of(context).isArabic;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: AppTheme.isLightMode
              ? Colors.white
              : (AppTheme.isIslamicMode ? AppTheme.islamicPrimaryNavy : const Color(0xFF1B263B)),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.currentTextSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Title
            Text(
              isArabic ? 'طريقة الحساب' : 'Calculation Method',
              style: TextStyle(
                color: AppTheme.currentTextPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                children: [
                  // Automatic Option
                  _buildMethodOption(
                    context: context,
                    title: isArabic ? 'تلقائي (موصى به)' : 'Automatic (Recommended)',
                    subtitle: isArabic
                        ? 'يتم اختياره حسب موقعك'
                        : 'Automatically selected based on your location',
                    isSelected: !provider.isManualMethod,
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await provider.autoDetectMethod();
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
                        isSelected: provider.isManualMethod && provider.method == method,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await provider.setMethod(method, isManual: true);
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
          color: isSelected ? AppTheme.currentActiveGlow.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppTheme.currentActiveGlow.withOpacity(0.5) : AppTheme.inactiveBorder,
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
                      color: isSelected ? AppTheme.currentActiveGlow : AppTheme.currentTextPrimary,
                      fontSize: 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
              Icon(Icons.check_circle, color: AppTheme.currentActiveGlow, size: 24),
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
        color: AppTheme.isLightMode 
            ? Colors.white 
            : (AppTheme.isIslamicSpecialMode
                ? AppTheme.islamicSpecialPrimary
                : (AppTheme.isIslamicGreenMode 
                    ? AppTheme.islamicGreenPrimary 
                    : (AppTheme.isIslamicMode ? AppTheme.islamicPrimaryNavy : const Color(0xFF1B263B)))),
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
              color: AppTheme.currentTextSecondary.withOpacity(0.3),
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
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppThemeProvider.instance.setTheme(AppThemeMode.light);
                  Navigator.pop(context);
                },
              ),
              // Islamic (Blue)
              _ThemeCard(
                title: t(context, 'islamicMode'),
                icon: Icons.mosque_outlined,
                isSelected: currentMode == AppThemeMode.islamic,
                previewGradient: AppTheme.islamicBackgroundGradient,
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
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppThemeProvider.instance.setTheme(AppThemeMode.islamicGreen);
                  Navigator.pop(context);
                },
              ),
              // Special Edition
              _ThemeCard(
                title: t(context, 'islamicSpecialMode'),
                icon: Icons.diamond_outlined, // Luxury icon
                isSelected: currentMode == AppThemeMode.islamicSpecial,
                previewGradient: AppTheme.islamicSpecialBackgroundGradient,
                onTap: () {
                  HapticFeedback.selectionClick();
                  AppThemeProvider.instance.setTheme(AppThemeMode.islamicSpecial);
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
  final VoidCallback onTap;

  const _ThemeCard({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.previewGradient,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
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
                      color: AppTheme.currentActiveGlow.withOpacity(0.3),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ]
                  : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 36,
              color:
                  previewGradient == AppTheme.lightBackgroundGradient
                      ? AppTheme.lightTextPrimary
                      : AppTheme.nightTextPrimary,
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
