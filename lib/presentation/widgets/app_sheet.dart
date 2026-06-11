import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_motion.dart';
import 'pressable_scale.dart';

/// Shared design system for the app's modal bottom sheets:
/// gradient glass look, glowing accent drag handle, gradient icon badge
/// header, staggered item entrances and gradient action buttons.
///
/// Deliberately NO BackdropFilter here: the living background animates
/// every frame, so a backdrop blur would re-compute continuously for as
/// long as the sheet is open (this caused visible lag). A near-opaque
/// gradient reads the same at a fraction of the cost.
class AppSheet extends StatelessWidget {
  final Widget child;

  /// Fraction of screen height the sheet may occupy.
  final double maxHeightFactor;

  const AppSheet({
    super.key,
    required this.child,
    this.maxHeightFactor = 0.75,
  });

  /// Standard way to present an [AppSheet].
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLightMode;
    final bgColors = AppTheme.currentBackgroundGradient.colors;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * maxHeightFactor,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: Container(
          decoration: BoxDecoration(
            color: isLight ? Colors.white.withValues(alpha: 0.98) : null,
            gradient: isLight
                ? null
                : LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      bgColors.first.withValues(alpha: 0.96),
                      bgColors.last.withValues(alpha: 0.99),
                    ],
                  ),
            border: Border(
              top: BorderSide(
                color: isLight
                    ? AppTheme.lightDivider
                    : AppTheme.currentActiveGlow.withValues(alpha: 0.35),
                width: 1,
              ),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SheetHandle(),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Glowing accent-gradient drag handle.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 4),
      width: 44,
      height: 5,
      decoration: BoxDecoration(
        gradient: AppTheme.currentAccentGradient,
        borderRadius: BorderRadius.circular(3),
        boxShadow: AppTheme.glowShadow(intensity: 0.6),
      ),
    );
  }
}

/// Sheet header: gradient icon badge + title + optional subtitle,
/// with an optional trailing widget (e.g. close button).
class SheetHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SheetHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppTheme.currentAccentGradient.colors
                    .map((c) => c.withValues(alpha: 0.22))
                    .toList(),
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppTheme.currentActiveGlow.withValues(alpha: 0.45),
              ),
              boxShadow: AppTheme.glowShadow(intensity: 0.4),
            ),
            child: Icon(icon, color: AppTheme.currentActiveGlow, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: AppTheme.currentTextPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      color: AppTheme.currentTextSecondary,
                      fontSize: 13,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Staggered entrance for sheet content: each item fades in and slides up,
/// [index] * [AppMotion.staggerStep] after the sheet opens. Stateless —
/// the delay is encoded as an Interval over a single tween.
class StaggerIn extends StatelessWidget {
  final int index;
  final Widget child;

  const StaggerIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delayMs = AppMotion.staggerStep.inMilliseconds * index;
    final totalMs = AppMotion.normal.inMilliseconds + delayMs;
    final start = delayMs / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Interval(start, 1.0, curve: AppMotion.enter),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

/// Selectable option tile for sheets. Selected state lights up with the
/// accent gradient and a soft glow.
class SheetTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;

  const SheetTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
    this.onLongPress,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = AppTheme.isLightMode;
    final glow = AppTheme.currentActiveGlow;

    return PressableScale(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.enter,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: AppTheme.currentAccentGradient.colors
                      .map((c) => c.withValues(alpha: isLight ? 0.10 : 0.16))
                      .toList(),
                )
              : null,
          color: selected ? null : AppTheme.inactiveBackground,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? glow.withValues(alpha: 0.65)
                : (isLight
                    ? AppTheme.lightDivider
                    : Colors.white.withValues(alpha: 0.08)),
            width: selected ? 1.5 : 1,
          ),
          boxShadow: selected ? AppTheme.glowShadow(intensity: 0.45) : null,
        ),
        child: Row(
          children: [
            // Leading icon badge
            AnimatedContainer(
              duration: AppMotion.fast,
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: selected ? AppTheme.currentAccentGradient : null,
                color: selected
                    ? null
                    : (isLight
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.08)),
                borderRadius: BorderRadius.circular(12),
                boxShadow:
                    selected ? AppTheme.glowShadow(intensity: 0.5) : null,
              ),
              child: Icon(
                icon,
                color: selected
                    ? _onGradientColor()
                    : AppTheme.currentTextSecondary,
                size: 21,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: selected ? glow : AppTheme.currentTextPrimary,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        color: AppTheme.currentTextSecondary
                            .withValues(alpha: 0.75),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
            // Animated check badge
            AnimatedScale(
              duration: AppMotion.fast,
              curve: AppMotion.pop,
              scale: selected ? 1.0 : 0.0,
              child: Container(
                margin: const EdgeInsetsDirectional.only(start: 8),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  gradient: AppTheme.currentAccentGradient,
                  shape: BoxShape.circle,
                  boxShadow: AppTheme.glowShadow(intensity: 0.5),
                ),
                child: Icon(Icons.check, color: _onGradientColor(), size: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Readable foreground on top of the accent gradient (gold needs dark).
  static Color _onGradientColor() {
    final base = AppTheme.currentAccentGradient.colors.first;
    return base.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
  }
}

/// Accent-gradient pill button with glow. The sheet's primary action.
class GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final fg = SheetTile._onGradientColor();

    return AnimatedOpacity(
      duration: AppMotion.fast,
      opacity: enabled ? 1.0 : 0.4,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.currentAccentGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: enabled ? AppTheme.glowShadow(intensity: 0.8) : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: fg, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Subtle outlined secondary button (cancel etc.).
class SheetSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const SheetSecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.isLightMode
            ? AppTheme.inactiveBackground
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.isLightMode
              ? AppTheme.lightDivider
              : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: AppTheme.currentTextSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
