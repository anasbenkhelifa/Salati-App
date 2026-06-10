import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/alert_mode_service.dart';

/// Animated button to toggle prayer alert mode (Sound/Vibrate/Silent)
class PrayerAlertModeButton extends StatefulWidget {
  final AlertMode mode;
  final VoidCallback onTap;

  const PrayerAlertModeButton({
    super.key,
    required this.mode,
    required this.onTap,
  });

  @override
  State<PrayerAlertModeButton> createState() => _PrayerAlertModeButtonState();
}

class _PrayerAlertModeButtonState extends State<PrayerAlertModeButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    setState(() => _isPressed = true);
    _scaleController.forward();
  }

  void _onTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    _scaleController.reverse().then((_) {
      // Small bounce effect
      _scaleController
          .animateTo(0.5, duration: const Duration(milliseconds: 80))
          .then((_) => _scaleController.reverse());
    });
    HapticFeedback.lightImpact();
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() => _isPressed = false);
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getBackgroundColor(),
            boxShadow: _getBoxShadow(),
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: Icon(
                _getIcon(),
                key: ValueKey(widget.mode),
                color: _getIconColor(),
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (widget.mode) {
      case AlertMode.sound:
        return Icons.volume_up_rounded;
      case AlertMode.vibrate:
        return Icons.vibration_rounded;
      case AlertMode.silent:
        return Icons.volume_off_rounded;
    }
  }

  Color _getIconColor() {
    switch (widget.mode) {
      case AlertMode.sound:
        return AppTheme.currentActiveGlow;
      case AlertMode.vibrate:
        return AppTheme.currentActiveGlow.withValues(alpha: 0.8);
      case AlertMode.silent:
        // Use gray that's visible in both light and dark modes
        return AppTheme.isLightMode
            ? Colors.grey.shade500
            : Colors.white.withValues(alpha: 0.4);
    }
  }

  Color _getBackgroundColor() {
    switch (widget.mode) {
      case AlertMode.sound:
        return AppTheme.currentActiveGlow.withValues(alpha: 0.15);
      case AlertMode.vibrate:
        return AppTheme.currentActiveGlow.withValues(alpha: 0.10);
      case AlertMode.silent:
        // Use gray background visible in both light and dark modes
        return AppTheme.isLightMode
            ? Colors.grey.shade200
            : Colors.white.withValues(alpha: 0.05);
    }
  }

  List<BoxShadow>? _getBoxShadow() {
    if (widget.mode == AlertMode.silent) return null;

    return [
      BoxShadow(
        color: AppTheme.currentActiveGlow.withValues(
          alpha: widget.mode == AlertMode.sound ? 0.3 : 0.15,
        ),
        blurRadius: widget.mode == AlertMode.sound ? 12 : 8,
        spreadRadius: widget.mode == AlertMode.sound ? 1 : 0,
      ),
    ];
  }
}
