import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../notification_manager.dart';
import '../../data/services/notification_service.dart';

/// Settings screen with glass setting cards and language switcher
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _fullScreenNotification = true;
  bool _notificationPermission = false;
  String _notificationStatus = 'Checking...';

  @override
  void initState() {
    super.initState();
    _checkNotificationPermission();
  }

  Future<void> _checkNotificationPermission() async {
    final service = NotificationService();
    final granted = await service.areNotificationsEnabled();
    if (mounted) {
      setState(() {
        _notificationPermission = granted;
        _notificationStatus = granted ? 'Enabled ✓' : 'Disabled ✗';
      });
    }
  }

  Future<void> _testNotification() async {
    final manager = NotificationManager.of(context);
    if (manager == null) {
      debugPrint('[Settings] NotificationManager not found');
      return;
    }

    final success = await manager.testNotification();
    if (success) {
      // Start live notification after test
      await manager.startLiveNotification();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Test notification sent! Check your notification tray.',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to send notification. Please grant permission.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
    await _checkNotificationPermission();
  }

  Future<void> _requestPermission() async {
    final manager = NotificationManager.of(context);
    if (manager == null) return;

    final granted = await manager.requestPermission();
    await _checkNotificationPermission();

    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable notifications in system settings.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);

    return SafeArea(
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
                  // Notification Debug Section
                  _buildNotificationDebugSection(),
                  const SizedBox(height: 20),
                  // Language switcher
                  _buildLanguageSwitcher(context, localeController),
                  const SizedBox(height: 12),
                  // Toggle setting
                  _buildSettingToggle(
                    icon: Icons.fullscreen,
                    title: t(context, 'fullScreenNotification'),
                    value: _fullScreenNotification,
                    onChanged: (val) {
                      setState(() => _fullScreenNotification = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  // Theme
                  _buildSettingItem(
                    icon: Icons.palette_outlined,
                    title: t(context, 'chooseTheme'),
                  ),
                  const SizedBox(height: 12),
                  // Share
                  _buildSettingItem(
                    icon: Icons.share_outlined,
                    title: t(context, 'shareApp'),
                  ),
                  const SizedBox(height: 12),
                  // Rate
                  _buildSettingItem(
                    icon: Icons.star_outline,
                    title: t(context, 'rateApp'),
                  ),
                  const SizedBox(height: 12),
                  // About
                  _buildSettingItem(
                    icon: Icons.info_outline,
                    title: t(context, 'aboutApp'),
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
    );
  }

  Widget _buildNotificationDebugSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Notification Debug',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status
          Row(
            children: [
              const Text(
                'Permission: ',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              Text(
                _notificationStatus,
                style: TextStyle(
                  color: _notificationPermission ? Colors.green : Colors.red,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testNotification,
                  icon: const Icon(Icons.notifications_active, size: 18),
                  label: const Text('Test Notification'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.activeGlow,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!_notificationPermission)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _requestPermission,
                    icon: const Icon(Icons.security, size: 18),
                    label: const Text('Grant'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

  Widget _buildSettingItem({required IconData icon, required String title}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: AppTheme.glassDecoration(opacity: 0.08, borderRadius: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.activeGlow, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.4)),
        ],
      ),
    );
  }

  Widget _buildSettingToggle({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: AppTheme.glassDecoration(opacity: 0.08, borderRadius: 20),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.activeGlow, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppTheme.activeGlow,
            activeTrackColor: AppTheme.activeGlow.withOpacity(0.3),
            inactiveThumbColor: Colors.white.withOpacity(0.6),
            inactiveTrackColor: Colors.white.withOpacity(0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Column(
        children: [
          Text(
            'Designed & Developed by',
            style: TextStyle(
              color: AppTheme.textSecondary.withOpacity(0.4),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.code,
                color: AppTheme.textSecondary.withOpacity(0.5),
                size: 18,
              ),
              const SizedBox(width: 8),
              Text(
                'Your Name Here',
                style: TextStyle(
                  color: AppTheme.textSecondary.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
