import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/tour/tour_key_registry.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/western_digits.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/qibla_provider.dart';
import '../widgets/glass_container.dart';

/// Qibla compass screen with smooth animated rotation and on-target glow
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final QiblaProvider _provider = QiblaProvider();
  double _currentDialTurns = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeQibla();
  }

  Future<void> _initializeQibla() async {
    await _provider.initialize();
    _provider.addListener(_onProviderUpdate);

    // If no location was cached on first try, the Prayer Times provider might
    // still be loading. Retry after a short delay.
    if (_provider.state == QiblaDataState.noLocationCached ||
        _provider.state == QiblaDataState.loading) {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted &&
          (_provider.state == QiblaDataState.noLocationCached ||
              _provider.state == QiblaDataState.loading)) {
        debugPrint('[QiblaScreen] Retrying initialization...');
        await _provider.initialize();
        if (mounted) setState(() {});
      }
    }
  }

  void _onProviderUpdate() {
    if (mounted) {
      setState(() {
        _currentDialTurns = _provider.dialRotationRadians / (2 * math.pi);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Notify provider about app lifecycle changes
    _provider.onAppLifecycleChanged(state);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.removeListener(_onProviderUpdate);
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);
    final isArabic = localeController.isArabic;

    return SafeArea(
      child: Column(
        children: [
          const SizedBox(height: 24),
          Text(
            t(context, 'qibla'),
            style: TextStyle(
              color: AppTheme.currentTextPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            t(context, 'qiblaDirectionSubtitle'),
            style: TextStyle(
              color: AppTheme.currentTextSecondary.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          Expanded(child: _buildContent(context, isArabic)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, bool isArabic) {
    switch (_provider.state) {
      case QiblaDataState.loading:
        return _buildLoadingState(isArabic);
      case QiblaDataState.noLocationCached:
        return _buildNoLocationState(context, isArabic);
      case QiblaDataState.noQiblaCached:
        return _buildNoQiblaState(context, isArabic);
      case QiblaDataState.error:
        return _buildErrorState(context, isArabic);
      case QiblaDataState.noCompass:
      case QiblaDataState.success:
        return _buildSuccessState(context, isArabic);
    }
  }

  Widget _buildLoadingState(bool isArabic) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.currentActiveGlow),
          const SizedBox(height: 16),
          Text(
            t(context, 'loading'),
            style: TextStyle(
              color: AppTheme.currentTextSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  /// No location cached - user needs to set up via Prayer Times
  Widget _buildNoLocationState(BuildContext context, bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: AppTheme.iconSecondary),
            const SizedBox(height: 16),
            Text(
              t(context, 'locationNotSet'),
              style: TextStyle(
                color: AppTheme.currentTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(context, 'locationNotSetDesc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.currentTextSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Location cached but no qibla cached (offline)
  Widget _buildNoQiblaState(BuildContext context, bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off, size: 64, color: AppTheme.iconSecondary),
            const SizedBox(height: 16),
            Text(
              t(context, 'noConnection'),
              style: TextStyle(
                color: AppTheme.currentTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t(context, 'noConnectionDesc'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.currentTextSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isArabic) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppTheme.iconSecondary),
            const SizedBox(height: 16),
            Text(
              t(context, 'error'),
              style: const TextStyle(
                color: Colors.red,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _provider.errorMessage ?? t(context, 'error'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.currentTextSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context, bool isArabic) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildAnimatedCompass(context, isArabic),
                const SizedBox(height: 24),
                if (!_provider.hasCompass) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            isArabic
                                ? 'البوصلة غير متوفرة. الاتجاه المعروض ثابت.'
                                : 'Compass not available. Showing static bearing.',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Text(
                    isArabic
                        ? 'حرّك الهاتف بشكل ∞ للمعايرة'
                        : 'Move phone in figure-8 to calibrate',
                    style: TextStyle(
                      color: AppTheme.currentTextSecondary.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnimatedCompass(BuildContext context, bool isArabic) {
    final qiblaBearing = _provider.qiblaBearing ?? 0;
    final isAligned = _provider.isAligned;
    final headingDeg = _provider.headingDegrees;

    return SizedBox(
      key: TourKeyRegistry.instance.compassDialKey,
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // On-target glow (only when aligned)
          if (isAligned)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.currentActiveGlow.withOpacity(0.4),
                    blurRadius: 40,
                    spreadRadius: 15,
                  ),
                  BoxShadow(
                    color: AppTheme.currentActiveGlow.withOpacity(0.2),
                    blurRadius: 60,
                    spreadRadius: 25,
                  ),
                ],
              ),
            ),
          // Animated rotating compass dial
          AnimatedRotation(
            turns: _currentDialTurns,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            child: _buildCompassDial(qiblaBearing, isAligned),
          ),
          // Fixed red pointer at top
          Positioned(
            top: 0,
            child: Transform.translate(
              offset: const Offset(0, -5),
              child: CustomPaint(
                size: const Size(24, 18),
                painter: _TrianglePainter(isAligned: isAligned),
              ),
            ),
          ),
          // Center: LIVE delta angle (true centering - degrees centered, ° positioned)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isAligned
                      ? AppTheme.currentActiveGlow.withOpacity(0.15)
                      : Colors.transparent,
            ),
            child: Builder(
              builder: (context) {
                // Define degree style once for measurement and rendering
                final degreeStyle = TextStyle(
                  color:
                      isAligned
                          ? AppTheme.currentActiveGlow
                          : AppTheme.currentTextPrimary,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                );
                final degreeText = westernDigits('$headingDeg');

                // Measure the actual width of the degrees text
                final textPainter = TextPainter(
                  text: TextSpan(text: degreeText, style: degreeStyle),
                  textDirection: TextDirection.ltr,
                )..layout();

                // Gap between number and degree symbol
                const gap = 4.0;
                final symbolOffset = (textPainter.width / 2) + gap;

                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Centered degrees number (anchor)
                    Text(degreeText, style: degreeStyle),
                    // Degree symbol positioned right after the number
                    Transform.translate(
                      offset: Offset(symbolOffset, -8),
                      child: Text(
                        '°',
                        style: TextStyle(
                          color: (isAligned
                                  ? AppTheme.currentActiveGlow
                                  : AppTheme.currentTextPrimary)
                              .withOpacity(0.7),
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompassDial(double qiblaBearing, bool isAligned) {
    return GlassContainer(
      width: 280,
      height: 280,
      shape: BoxShape.circle,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Tick marks
          ...List.generate(72, (index) {
            final angle = (index * 5) * math.pi / 180;
            final isMajor = index % 6 == 0;
            final isCardinal = index % 18 == 0;
            return Transform.rotate(
              angle: angle,
              child: Align(
                alignment: Alignment.topCenter,
                child: Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: isCardinal ? 3 : (isMajor ? 2 : 1),
                  height: isCardinal ? 20 : (isMajor ? 16 : 8),
                  color:
                      isCardinal
                          ? AppTheme.currentTextPrimary
                          : (isMajor
                              ? AppTheme.currentTextPrimary.withOpacity(0.8)
                              : AppTheme.currentTextSecondary.withOpacity(0.4)),
                ),
              ),
            );
          }),
          // North indicator
          const Positioned(
            top: 38,
            child: Text(
              'N',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Kaaba icon at Qibla position
          Transform.rotate(
            angle: qiblaBearing * math.pi / 180,
            child: Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 55),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.currentActiveGlow,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.currentActiveGlow.withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(Icons.mosque, color: Colors.white, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final bool isAligned;

  _TrianglePainter({this.isAligned = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = isAligned ? AppTheme.currentActiveGlow : Colors.red
          ..style = PaintingStyle.fill;

    final path =
        Path()
          ..moveTo(size.width / 2, size.height)
          ..lineTo(0, 0)
          ..lineTo(size.width, 0)
          ..close();

    canvas.drawPath(path, paint);

    // Add glow when aligned
    if (isAligned) {
      final glowPaint =
          Paint()
            ..color = AppTheme.currentActiveGlow.withOpacity(0.5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(path, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.isAligned != isAligned;
  }
}
