import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../data/services/adhan_playback_service.dart';
import '../../data/services/alert_mode_service.dart';
import '../../domain/providers/qibla_provider.dart';
import '../widgets/app_option_tile.dart';
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

  @override
  void initState() {
    super.initState();
    _adhanService.initialize();
    // Initialize QiblaProvider if not already
    QiblaProvider.instance?.initialize();
  }

  Future<void> _testAdhan() async {
    if (_isAdhanTesting) return;

    setState(() => _isAdhanTesting = true);
    HapticFeedback.mediumImpact();

    // Reset the trigger guard so we can test multiple times
    _adhanService.resetTriggerGuard();

    // Use 'fajr' as the test prayer (will respect its alert mode)
    final testPrayerKey = 'fajr';
    final testTime = DateTime.now();
    final isArabic = AppLocaleProvider.of(context).isArabic;

    // Get the current mode for display
    final alertModeService = AlertModeService();
    final mode = await alertModeService.getAlertMode(testPrayerKey);

    // Trigger the Adhan with localized names
    final prayerName = isArabic ? 'الفجر' : 'Fajr';
    final prayerTimeStr =
        '${testTime.hour.toString().padLeft(2, '0')}:${testTime.minute.toString().padLeft(2, '0')}';

    await _adhanService.triggerForPrayer(
      testPrayerKey,
      testTime,
      prayerName: prayerName,
      prayerTimeFormatted: prayerTimeStr,
      isArabic: isArabic,
    );

    // Determine the result message
    String message;
    Color bgColor;

    switch (mode) {
      case AlertMode.sound:
        message =
            isArabic
                ? 'تم تشغيل اختبار الأذان (صوت + اهتزاز)'
                : 'Adhan debug triggered (Sound + Vibration)';
        bgColor = Colors.green;
        break;
      case AlertMode.vibrate:
        message =
            isArabic
                ? 'تم تشغيل اختبار الأذان (اهتزاز فقط)'
                : 'Adhan debug triggered (Vibration only)';
        bgColor = Colors.orange;
        break;
      case AlertMode.silent:
        message =
            isArabic
                ? 'الوضع الصامت: لم يتم تشغيل شيء'
                : 'Silent mode: nothing played';
        bgColor = Colors.grey;
        break;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: bgColor,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    // Auto-reset after 5 seconds so repeated testing works
    await Future.delayed(const Duration(seconds: 5));
    _adhanService.resetTriggerGuard();

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
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
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
                    // Adhan Debug Section
                    _buildAdhanDebugSection(),
                    const SizedBox(height: 20),
                    // Language switcher
                    _buildLanguageSwitcher(context, localeController),
                    const SizedBox(height: 12),
                    // Controls section (groups notifications, haptics, theme)
                    AppOptionTile.navigation(
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
                      onTap: () {},
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
              AppTheme.activeGlow.withValues(alpha: 0.15),
              AppTheme.activeGlow.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.activeGlow.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.activeGlow.withValues(alpha: 0.1),
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
                    color: AppTheme.activeGlow.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.mosque_rounded,
                    color: AppTheme.activeGlow,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isArabic ? 'اختبار الأذان' : 'Adhan Debug',
                  style: const TextStyle(
                    color: AppTheme.activeGlow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              isArabic
                  ? 'اضغط لاختبار تشغيل الأذان باستخدام إعدادات صلاة الفجر'
                  : 'Tap to test Adhan playback using Fajr prayer settings',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 13,
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
                        : const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  _isAdhanTesting
                      ? (isArabic ? 'جاري التشغيل...' : 'Playing...')
                      : (isArabic ? 'تشغيل اختبار الأذان' : 'Test Adhan'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.activeGlow,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppTheme.activeGlow.withValues(
                    alpha: 0.5,
                  ),
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

  Widget _buildLanguageSwitcher(BuildContext context, dynamic controller) {
    final isArabic = controller.isArabic;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: AppTheme.glassDecoration(opacity: 0.08, borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.language,
                  color: AppTheme.activeGlow,
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                t(context, 'language'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Language toggle buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.setLocale(const Locale('ar')),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          isArabic
                              ? AppTheme.activeGlow.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            isArabic
                                ? AppTheme.activeGlow.withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t(context, 'arabic'),
                        style: TextStyle(
                          color:
                              isArabic
                                  ? AppTheme.activeGlow
                                  : AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight:
                              isArabic ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => controller.setLocale(const Locale('en')),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          !isArabic
                              ? AppTheme.activeGlow.withOpacity(0.2)
                              : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color:
                            !isArabic
                                ? AppTheme.activeGlow.withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        t(context, 'english'),
                        style: TextStyle(
                          color:
                              !isArabic
                                  ? AppTheme.activeGlow
                                  : AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight:
                              !isArabic ? FontWeight.bold : FontWeight.normal,
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
            isArabic ? 'تصميم وتطوير' : 'Designed & Developed by',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.4),
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
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Telegram icon (using send icon as telegram-like)
                    Icon(
                      Icons.send_rounded,
                      color: const Color(0xFF0088CC), // Telegram blue
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Anas',
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
