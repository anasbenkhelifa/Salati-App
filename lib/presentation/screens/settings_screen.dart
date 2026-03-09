import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_provider.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../core/tour/tour_key_registry.dart';
import '../../core/tour/app_tour_service.dart';
import '../../data/services/adhan_playback_service.dart';
import '../../domain/providers/qibla_provider.dart';
import '../widgets/app_option_tile.dart';
import '../widgets/glass_container.dart';
import '../navigation/app_shell.dart';
import 'controls_screen.dart';

/// Settings screen with glass setting cards and language switcher
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Adhan debug state
  final AdhanPlaybackService _adhanService = AdhanPlaybackService();
  bool _isAdhanTesting = false;
  int _selectedPrayerIndex = 0; // 0=Fajr, 1=Dhuhr, 2=Asr, 3=Maghrib, 4=Isha

  @override
  void initState() {
    super.initState();
    _adhanService.initialize();
    // Initialize QiblaProvider if not already
    QiblaProvider.instance?.initialize();
    // Listen to theme changes to rebuild when theme switches
    AppThemeProvider.instance.addListener(_onThemeChange);
  }

  @override
  void dispose() {
    AppThemeProvider.instance.removeListener(_onThemeChange);
    super.dispose();
  }

  void _onThemeChange() {
    if (mounted) setState(() {});
  }

  Future<void> _testAdhan() async {
    if (_isAdhanTesting) return;

    setState(() => _isAdhanTesting = true);
    HapticFeedback.mediumImpact();

    final isArabic = AppLocaleProvider.of(context).isArabic;

    // Get prayer info
    final prayerNamesEn = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
    final prayerNamesAr = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    final prayerName =
        isArabic
            ? prayerNamesAr[_selectedPrayerIndex]
            : prayerNamesEn[_selectedPrayerIndex];
    final now = DateTime.now();
    final prayerTimeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Show countdown snackbar
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabic
                ? 'سيبدأ الأذان خلال 5 ثوان...'
                : 'Adhan will start in 5 seconds...',
          ),
          backgroundColor: AppTheme.currentActiveGlow,
          duration: const Duration(seconds: 5),
        ),
      );
    }

    // Schedule test via native AlarmManager (works even if app is closed)
    const channel = MethodChannel('com.example.adhan_app/alarm');
    try {
      await channel.invokeMethod('scheduleTestAdhan', {
        'prayerIndex': _selectedPrayerIndex,
        'prayerName': prayerName,
        'prayerTime': prayerTimeStr,
      });
    } catch (e) {
      debugPrint('Error scheduling test adhan: $e');
    }

    // Auto-reset after 10 seconds so repeated testing works
    await Future.delayed(const Duration(seconds: 10));

    if (mounted) {
      setState(() => _isAdhanTesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);
    final isArabic = localeController.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Title
              Center(
                child: Text(
                  t(context, 'settings'),
                  style: TextStyle(
                    color: AppTheme.currentTextPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // Settings list
              Expanded(
                child: ListView(
                  children: [
                    // Adhan Debug Section (only in debug mode)
                    if (kDebugMode) _buildAdhanDebugSection(),
                    if (kDebugMode) const SizedBox(height: 20),
                    // Language switcher
                    _buildLanguageSwitcher(context, localeController, key: TourKeyRegistry.instance.languageTileKey),
                    const SizedBox(height: 12),
                    // Controls section (groups notifications, haptics, theme)
                    AppOptionTile.navigation(
                      key: TourKeyRegistry.instance.controlsTileKey,
                      icon: Icons.tune,
                      title: t(context, 'controlsTitle'),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ControlsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 12),
                    // Share
                    AppOptionTile.navigation(
                      icon: Icons.share_outlined,
                      title: t(context, 'shareApp'),
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    // Rate
                    AppOptionTile.navigation(
                      icon: Icons.star_outline,
                      title: t(context, 'rateApp'),
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    // About
                    AppOptionTile.navigation(
                      icon: Icons.info_outline,
                      title: t(context, 'aboutApp'),
                      onTap: () => _showAboutDialog(context),
                    ),
                    const SizedBox(height: 40),
                    // Footer
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAdhanDebugSection() {
    final isArabic = AppLocaleProvider.of(context).isArabic;

    return GestureDetector(
      onTapDown: (_) => HapticFeedback.lightImpact(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.currentActiveGlow.withValues(alpha: 0.15),
              AppTheme.currentActiveGlow.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.currentActiveGlow.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.currentActiveGlow.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.currentActiveGlow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.mosque_rounded,
                    color: AppTheme.currentActiveGlow,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isArabic ? 'اختبار الأذان' : 'Adhan Debug',
                  style: TextStyle(
                    color: AppTheme.currentActiveGlow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Prayer selection dropdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color:
                    AppTheme.isLightMode
                        ? Colors.grey.shade100
                        : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.currentDivider),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  value: _selectedPrayerIndex,
                  isExpanded: true,
                  dropdownColor:
                      AppTheme.isLightMode
                          ? Colors.white
                          : AppTheme.nightPrimaryNavy,
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: AppTheme.currentTextSecondary,
                  ),
                  items: List.generate(5, (index) {
                    final prayerNamesEn = [
                      'Fajr',
                      'Dhuhr',
                      'Asr',
                      'Maghrib',
                      'Isha',
                    ];
                    final prayerNamesAr = [
                      'الفجر',
                      'الظهر',
                      'العصر',
                      'المغرب',
                      'العشاء',
                    ];
                    return DropdownMenuItem<int>(
                      value: index,
                      child: Text(
                        isArabic ? prayerNamesAr[index] : prayerNamesEn[index],
                        style: TextStyle(
                          color: AppTheme.currentTextPrimary,
                          fontSize: 15,
                        ),
                      ),
                    );
                  }),
                  onChanged:
                      _isAdhanTesting
                          ? null
                          : (value) {
                            if (value != null) {
                              setState(() => _selectedPrayerIndex = value);
                            }
                          },
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Description
            Text(
              isArabic
                  ? 'اضغط للاختبار كأن وقت الصلاة قد حان'
                  : 'Tap to simulate as if prayer time has arrived',
              style: TextStyle(
                color: AppTheme.currentTextSecondary.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            // Test button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isAdhanTesting ? null : _testAdhan,
                icon:
                    _isAdhanTesting
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  _isAdhanTesting
                      ? (isArabic ? 'جاري التشغيل...' : 'Playing...')
                      : (isArabic ? 'تشغيل اختبار الأذان' : 'Test Adhan'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.currentActiveGlow,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.currentActiveGlow
                      .withValues(alpha: 0.5),
                  disabledForegroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSwitcher(BuildContext context, dynamic controller, {Key? key}) {
    final isArabic = controller.isArabic;

    return GlassContainer(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.inactiveBorder,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.language,
                  color: AppTheme.currentActiveGlow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                t(context, 'language'),
                style: TextStyle(
                  color: AppTheme.currentTextPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Language toggle buttons (3 languages)
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.setLocale(const Locale('ar')),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          controller.locale.languageCode == 'ar'
                              ? AppTheme.currentActiveGlow.withOpacity(0.2)
                              : AppTheme.inactiveBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            controller.locale.languageCode == 'ar'
                                ? AppTheme.currentActiveGlow.withOpacity(0.5)
                                : AppTheme.inactiveBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t(context, 'arabic'),
                        style: TextStyle(
                          color:
                              controller.locale.languageCode == 'ar'
                                  ? AppTheme.currentActiveGlow
                                  : AppTheme.currentTextSecondary,
                          fontSize: 15,
                          fontWeight:
                              controller.locale.languageCode == 'ar' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.setLocale(const Locale('fr')),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          controller.locale.languageCode == 'fr'
                              ? AppTheme.currentActiveGlow.withOpacity(0.2)
                              : AppTheme.inactiveBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            controller.locale.languageCode == 'fr'
                                ? AppTheme.currentActiveGlow.withOpacity(0.5)
                                : AppTheme.inactiveBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t(context, 'french'),
                        style: TextStyle(
                          color:
                              controller.locale.languageCode == 'fr'
                                  ? AppTheme.currentActiveGlow
                                  : AppTheme.currentTextSecondary,
                          fontSize: 15,
                          fontWeight:
                              controller.locale.languageCode == 'fr' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.setLocale(const Locale('en')),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          controller.locale.languageCode == 'en'
                              ? AppTheme.currentActiveGlow.withOpacity(0.2)
                              : AppTheme.inactiveBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            controller.locale.languageCode == 'en'
                                ? AppTheme.currentActiveGlow.withOpacity(0.5)
                                : AppTheme.inactiveBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t(context, 'english'),
                        style: TextStyle(
                          color:
                              controller.locale.languageCode == 'en'
                                  ? AppTheme.currentActiveGlow
                                  : AppTheme.currentTextSecondary,
                          fontSize: 15,
                          fontWeight:
                              controller.locale.languageCode == 'en' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final isArabic = AppLocaleProvider.of(context).isArabic;

    return Center(
      child: Column(
        children: [
          Text(
            t(context, 'designedBy'),
            style: TextStyle(
              color: AppTheme.currentTextSecondary.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          // Clickable Telegram link
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () async {
                final uri = Uri.parse('https://t.me/anassbkk');
                final ok = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t(context, 'couldNotOpenLink'),
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Directionality(
                  // Force LTR so icon is always on left of "Anas"
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Telegram icon from assets
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: Image.asset(
                          'assets/icons/telegram.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Name stays constant (not localized)
                      Text(
                        'Anas',
                        style: TextStyle(
                          color: AppTheme.currentTextSecondary.withOpacity(0.6),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color:
                  AppTheme.isLightMode ? Colors.white : const Color(0xFF1E1E2E),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App icon placeholder
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.currentActiveGlow,
                          AppTheme.currentActiveGlow.withOpacity(0.7),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.currentActiveGlow.withOpacity(0.4),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mosque_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // App name
                  Text(
                    t(context, 'aboutApp'),
                    style: TextStyle(
                      color: AppTheme.currentTextPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Version
                  Text(
                    t(context, 'appVersion'),
                    style: TextStyle(
                      color: AppTheme.currentTextSecondary.withOpacity(0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Description
                  Text(
                    t(context, 'openSourceNotice'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.currentTextSecondary,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Features
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.currentActiveGlow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        _aboutFeatureRow(
                          Icons.wifi_off_rounded,
                          t(context, 'aboutFeatureOffline'),
                        ),
                        const SizedBox(height: 8),
                        _aboutFeatureRow(
                          Icons.blur_on_rounded,
                          t(context, 'aboutFeature1'),
                        ),
                        const SizedBox(height: 8),
                        _aboutFeatureRow(
                          Icons.access_time_filled,
                          t(context, 'aboutFeature2'),
                        ),
                        const SizedBox(height: 8),
                        _aboutFeatureRow(
                          Icons.notifications_active,
                          t(context, 'aboutFeature3'),
                        ),
                        const SizedBox(height: 8),
                        _aboutFeatureRow(
                          Icons.explore,
                          t(context, 'aboutFeature4'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Divider
                  Container(
                    height: 1,
                    color: AppTheme.currentTextSecondary.withOpacity(0.1),
                  ),
                  const SizedBox(height: 20),

                  // Developer credit
                  Text(
                    t(context, 'developedByHeart'),
                    style: TextStyle(
                      color: AppTheme.currentTextSecondary.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Clickable developer credit with Telegram link
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      final url = Uri.parse('https://t.me/anassbkk');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.currentActiveGlow.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.currentActiveGlow.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Telegram icon
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: Image.asset(
                              'assets/icons/telegram.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Anas Benkhelifa',
                            style: TextStyle(
                              color: AppTheme.currentTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.currentActiveGlow,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        t(context, 'gotIt'),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  Widget _aboutFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.currentActiveGlow),
        const SizedBox(width: 12),
        Text(
          text,
          style: TextStyle(color: AppTheme.currentTextPrimary, fontSize: 14),
        ),
      ],
    );
  }
}
