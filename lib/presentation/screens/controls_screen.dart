import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/qibla_provider.dart';
import '../widgets/app_option_tile.dart';

/// Controls screen with full-screen notification, compass haptics, and theme settings
class ControlsScreen extends StatefulWidget {
  const ControlsScreen({super.key});

  @override
  State<ControlsScreen> createState() => _ControlsScreenState();
}

class _ControlsScreenState extends State<ControlsScreen> {
  bool _fullScreenNotification = true;
  bool _compassHapticsEnabled = true;

  @override
  void initState() {
    super.initState();
    // Load initial state from provider
    _loadSettings();
    // Listen to provider changes
    QiblaProvider.instance?.addListener(_onProviderChange);
  }

  @override
  void dispose() {
    QiblaProvider.instance?.removeListener(_onProviderChange);
    super.dispose();
  }

  void _loadSettings() {
    // Load compass haptics from provider (or default to true)
    final provider = QiblaProvider.instance;
    if (provider != null) {
      _compassHapticsEnabled = provider.compassHapticsEnabled;
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
                        AppOptionTile.toggle(
                          icon: Icons.fullscreen,
                          title: t(context, 'fullScreenNotification'),
                          value: _fullScreenNotification,
                          onChanged: (val) {
                            setState(() => _fullScreenNotification = val);
                          },
                        ),
                        const SizedBox(height: 12),
                        // Compass haptics toggle
                        AppOptionTile.toggle(
                          icon: Icons.vibration,
                          title: t(context, 'compassHaptics'),
                          value: _compassHapticsEnabled,
                          onChanged: _setCompassHaptics,
                        ),
                        const SizedBox(height: 12),
                        // Theme picker
                        AppOptionTile.navigation(
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
}
