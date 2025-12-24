import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/qibla_provider.dart';

/// Controls screen with full-screen notification, compass haptics, and theme settings
class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  bool _fullScreenNotification = true;

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);
    final isArabic = localeController.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0D1B2A), Color(0xFF1B263B)],
            ),
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
                        // Full screen notification toggle
                        _buildSettingToggle(
                          icon: Icons.fullscreen,
                          title: t(context, 'fullScreenNotification'),
                          value: _fullScreenNotification,
                          onChanged: (val) {
                            setState(() => _fullScreenNotification = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        // Compass haptics toggle
                        _buildSettingToggle(
                          icon: Icons.vibration,
                          title: t(context, 'compassHaptics'),
                          value:
                              QiblaProvider.instance?.compassHapticsEnabled ??
                              true,
                          onChanged: (val) {
                            QiblaProvider.instance?.setCompassHaptics(val);
                            setState(() {});
                          },
                        ),
                        const SizedBox(height: 12),
                        // Theme picker
                        _buildSettingItem(
                          icon: Icons.palette_outlined,
                          title: t(context, 'chooseTheme'),
                          onTap: () {
                            // TODO: Open theme picker
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
              color: AppTheme.textPrimary,
            ),
          ),
          // Title
          Expanded(
            child: Center(
              child: Text(
                t(context, 'controlsTitle'),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
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

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
      ),
    );
  }
}
