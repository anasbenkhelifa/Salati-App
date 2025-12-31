import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Enum for trailing widget type
enum OptionTileTrailing { chevron, switchControl, none, custom }

/// Reusable option tile widget that handles RTL/LTR layout consistently
///
/// Layout in LTR: [Icon] [Title/Subtitle...] [Trailing]
/// Layout in RTL: [Trailing] [...Title/Subtitle] [Icon]
///
/// The Row automatically flips based on Directionality context.
class AppOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final OptionTileTrailing trailingType;
  final Widget? customTrailing;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final VoidCallback? onTap;
  final bool enabled;
  final double opacity;
  final double borderRadius;

  const AppOptionTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingType = OptionTileTrailing.chevron,
    this.customTrailing,
    this.switchValue,
    this.onSwitchChanged,
    this.onTap,
    this.enabled = true,
    this.opacity = 0.08,
    this.borderRadius = 20,
  });

  /// Factory for simple navigation item with chevron
  factory AppOptionTile.navigation({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return AppOptionTile(
      key: key,
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailingType: OptionTileTrailing.chevron,
      onTap: onTap,
    );
  }

  /// Factory for toggle item with switch
  factory AppOptionTile.toggle({
    Key? key,
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return AppOptionTile(
      key: key,
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailingType: OptionTileTrailing.switchControl,
      switchValue: value,
      onSwitchChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get the current text direction from context
    final textDirection = Directionality.of(context);

    Widget content = Container(
      // Use EdgeInsetsDirectional for RTL-aware padding
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 14,
      ),
      decoration: AppTheme.glassDecoration(
        opacity: opacity,
        borderRadius: borderRadius,
      ),
      child: Row(
        // Row respects textDirection from Directionality context
        children: [
          // Leading icon container
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.inactiveBorder,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color:
                  enabled
                      ? AppTheme.currentActiveGlow
                      : AppTheme.currentActiveGlow.withOpacity(0.5),
              size: 22,
            ),
          ),
          const SizedBox(width: 16),
          // Title and optional subtitle
          Expanded(
            child:
                subtitle != null
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            color:
                                enabled
                                    ? AppTheme.currentTextPrimary
                                    : AppTheme.currentTextPrimary.withOpacity(
                                      0.5,
                                    ),
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            color: AppTheme.currentTextSecondary.withOpacity(
                              0.6,
                            ),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    )
                    : Text(
                      title,
                      style: TextStyle(
                        color:
                            enabled
                                ? AppTheme.currentTextPrimary
                                : AppTheme.currentTextPrimary.withOpacity(0.5),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
          ),
          // Trailing widget
          _buildTrailing(context, textDirection),
        ],
      ),
    );

    // Wrap with GestureDetector for tappable tiles (except switch tiles)
    if (onTap != null && trailingType != OptionTileTrailing.switchControl) {
      content = GestureDetector(onTap: enabled ? onTap : null, child: content);
    }

    return content;
  }

  Widget _buildTrailing(BuildContext context, TextDirection textDirection) {
    switch (trailingType) {
      case OptionTileTrailing.chevron:
        // Chevron always points right visually (doesn't flip with RTL)
        // But its position moves to the trailing side
        return Icon(Icons.chevron_right, color: AppTheme.currentTextSecondary);

      case OptionTileTrailing.switchControl:
        return Switch(
          value: switchValue ?? false,
          onChanged: enabled ? onSwitchChanged : null,
          activeColor: AppTheme.currentActiveGlow,
          activeTrackColor: AppTheme.currentActiveGlow.withOpacity(0.3),
          inactiveThumbColor:
              AppTheme.isLightMode
                  ? Colors.grey.shade400
                  : Colors.white.withOpacity(0.6),
          inactiveTrackColor:
              AppTheme.isLightMode
                  ? Colors.grey.shade300
                  : Colors.white.withOpacity(0.2),
        );

      case OptionTileTrailing.custom:
        return customTrailing ?? const SizedBox.shrink();

      case OptionTileTrailing.none:
        return const SizedBox.shrink();
    }
  }
}
