import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';

// ═══════════════════════════════════════════════════════════════════
//   ONBOARDING SCREEN — Premium Spiritual First-Launch Experience
// ═══════════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Permission states
  bool _locationGranted = false;
  bool _notificationGranted = false;

  // Breathing animation for the CTA button
  late AnimationController _breatheController;
  late Animation<double> _breatheAnimation;

  // Content entry animations
  late AnimationController _contentEntryController;
  late Animation<double> _titleSlide;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _heroFade;

  // Celebration bounce for Get Started
  late AnimationController _celebrationController;
  late Animation<double> _celebrationScale;

  @override
  void initState() {
    super.initState();

    // Breathing pulse: 1.0 → 1.04 → 1.0 over 2s
    _breatheController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _breatheAnimation = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _breatheController, curve: Curves.easeInOut),
    );
    _breatheController.repeat(reverse: true);

    // Content entry: staggered fade+slide
    _contentEntryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _titleSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _contentEntryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _titleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentEntryController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    _subtitleSlide = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _contentEntryController,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOut),
      ),
    );
    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentEntryController,
        curve: const Interval(0.15, 0.65, curve: Curves.easeOut),
      ),
    );
    _heroFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _contentEntryController,
        curve: const Interval(0.25, 0.85, curve: Curves.easeOut),
      ),
    );

    // Celebration bounce
    _celebrationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _celebrationScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.08), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.08, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(
      parent: _celebrationController,
      curve: Curves.easeInOut,
    ));

    // Play entry animation for first slide
    _contentEntryController.forward();
  }

  @override
  void dispose() {
    _breatheController.dispose();
    _contentEntryController.dispose();
    _celebrationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    HapticFeedback.selectionClick();
    // Reset and replay content entry animation
    _contentEntryController.reset();
    _contentEntryController.forward();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        setState(() => _locationGranted = true);
        HapticFeedback.mediumImpact();
        if (_locationGranted) {
          _celebrationController.forward(from: 0);
        }
      }
    } catch (_) {}
  }

  Future<void> _requestNotifications() async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      final android = plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        setState(() => _notificationGranted = granted ?? false);
        if (_notificationGranted) HapticFeedback.mediumImpact();
      }
    } catch (_) {
      // Fallback: mark as granted if API isn't available
      setState(() => _notificationGranted = true);
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_complete', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Layer 0: App background
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.currentBackgroundGradient,
              image: AppTheme.currentBackgroundImage,
            ),
          ),

          // Layer 1: Background particles (continuous, atmospheric)
          const _BackgroundParticles(),

          // Layer 2: PageView with parallax
          PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: 4,
            itemBuilder: (context, index) {
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double parallax = 0;
                  if (_pageController.position.haveDimensions) {
                    parallax = (_pageController.page ?? 0) - index;
                  }
                  return Transform.translate(
                    offset: Offset(parallax * -30, 0),
                    child: Opacity(
                      opacity: (1 - parallax.abs()).clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: _buildSlide(index),
              );
            },
          ),

          // Layer 3: Bottom controls (indicator + buttons)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Page indicator
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: 4,
                      effect: SwapEffect(
                        activeDotColor: Colors.white,
                        dotColor: Colors.white24,
                        dotHeight: 8,
                        dotWidth: 8,
                        spacing: 12,
                        type: SwapType.yRotation,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // CTA Button
                    _currentPage == 3
                        ? _buildGetStartedButton()
                        : _buildNextButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(int index) {
    final slides = [
      _SlideData(
        arabicTitle: 'مرحباً بك في صلاتي',
        englishSubtitle: 'Your personal, offline prayer companion',
        glowColor: const Color(0xFFF5C842),
        heroBuilder: (anim) => _WelcomeHero(animation: anim),
      ),
      _SlideData(
        arabicTitle: 'مواقيت دقيقة بدون إنترنت',
        englishSubtitle: 'Accurate prayer times calculated entirely on your device',
        glowColor: const Color(0xFF4CAF82),
        heroBuilder: (anim) => _PrayerTimesHero(animation: anim),
      ),
      _SlideData(
        arabicTitle: 'اتجاه القبلة في أي مكان',
        englishSubtitle: 'Find the Qibla direction from anywhere in the world',
        glowColor: const Color(0xFF4A90D9),
        heroBuilder: (anim) => _QiblaHero(animation: anim),
      ),
      _SlideData(
        arabicTitle: 'نحتاج إذنك',
        englishSubtitle: 'We need a few permissions to serve you best',
        glowColor: const Color(0xFF9B6FD4),
        heroBuilder: (anim) => _PermissionsHero(animation: anim),
      ),
    ];

    final slide = slides[index];

    return AnimatedBuilder(
      animation: _contentEntryController,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 60),

              // Arabic Title
              Transform.translate(
                offset: Offset(0, _currentPage == index ? _titleSlide.value : 0),
                child: Opacity(
                  opacity: _currentPage == index ? _titleFade.value : 1,
                  child: Text(
                    slide.arabicTitle,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: GoogleFonts.tajawal(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // English Subtitle
              Transform.translate(
                offset: Offset(0, _currentPage == index ? _subtitleSlide.value : 0),
                child: Opacity(
                  opacity: _currentPage == index ? _subtitleFade.value : 1,
                  child: Text(
                    slide.englishSubtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white60,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Hero Animation with Radial Glow
              Opacity(
                opacity: _currentPage == index ? _heroFade.value : 1,
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.38,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Radial glow
                      Container(
                        width: 280,
                        height: 280,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              slide.glowColor.withOpacity(0.25),
                              slide.glowColor.withOpacity(0.08),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      ),
                      // Hero content
                      slide.heroBuilder(_contentEntryController),
                    ],
                  ),
                ),
              ),

              // Permission controls only on slide 4
              if (index == 3) ...[
                const SizedBox(height: 20),
                _buildPermissionControls(),
              ],

              const SizedBox(height: 100),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPermissionControls() {
    return Column(
      children: [
        // Location permission
        _PermissionRow(
          icon: Icons.location_on_rounded,
          label: 'Location Access',
          arabicLabel: 'إذن الموقع',
          reason: 'To calculate accurate prayer times',
          granted: _locationGranted,
          onRequest: _requestLocation,
        ),
        const SizedBox(height: 16),
        // Notification permission
        _PermissionRow(
          icon: Icons.notifications_active_rounded,
          label: 'Notifications',
          arabicLabel: 'الإشعارات',
          reason: 'To remind you before each prayer',
          granted: _notificationGranted,
          onRequest: _requestNotifications,
        ),
      ],
    );
  }

  Widget _buildNextButton() {
    return AnimatedBuilder(
      animation: _breatheAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _breatheAnimation.value,
          child: child,
        );
      },
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _nextPage,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white.withOpacity(0.15),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.white.withOpacity(0.2)),
            ),
            elevation: 0,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'التالي',
                style: GoogleFonts.tajawal(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '/ Next',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGetStartedButton() {
    final enabled = _locationGranted;

    return Column(
      children: [
        AnimatedBuilder(
          animation: _celebrationScale,
          builder: (context, child) {
            return Transform.scale(
              scale: _celebrationScale.value,
              child: child,
            );
          },
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: enabled ? _completeOnboarding : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: enabled
                    ? const Color(0xFF4CAF82)
                    : Colors.white.withOpacity(0.08),
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.white.withOpacity(0.08),
                disabledForegroundColor: Colors.white38,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: enabled
                        ? const Color(0xFF4CAF82).withOpacity(0.6)
                        : Colors.white.withOpacity(0.1),
                  ),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'ابدأ الآن',
                    style: GoogleFonts.tajawal(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '/ Get Started',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: enabled ? Colors.white70 : Colors.white30,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_locationGranted) ...[
          const SizedBox(height: 12),
          Text(
            'Location is required to calculate prayer times',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: Colors.white38,
            ),
          ),
        ],
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  DATA CLASS
// ═══════════════════════════════════════════════════════════════════

class _SlideData {
  final String arabicTitle;
  final String englishSubtitle;
  final Color glowColor;
  final Widget Function(AnimationController) heroBuilder;

  const _SlideData({
    required this.arabicTitle,
    required this.englishSubtitle,
    required this.glowColor,
    required this.heroBuilder,
  });
}

// ═══════════════════════════════════════════════════════════════════
//  PERMISSION ROW WIDGET
// ═══════════════════════════════════════════════════════════════════

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String arabicLabel;
  final String reason;
  final bool granted;
  final VoidCallback onRequest;

  const _PermissionRow({
    required this.icon,
    required this.label,
    required this.arabicLabel,
    required this.reason,
    required this.granted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(granted ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: granted
              ? const Color(0xFF4CAF82).withOpacity(0.4)
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          // Status icon
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              granted ? Icons.check_circle_rounded : icon,
              key: ValueKey(granted),
              color: granted ? const Color(0xFF4CAF82) : Colors.white54,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          // Labels
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$arabicLabel / $label',
                  style: GoogleFonts.tajawal(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  reason,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white54,
                  ),
                ),
              ],
            ),
          ),
          // Action button
          if (!granted)
            TextButton(
              onPressed: onRequest,
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.1),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              child: Text(
                'Allow',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  BACKGROUND PARTICLES — Floating Islamic geometric dots
// ═══════════════════════════════════════════════════════════════════

class _BackgroundParticles extends StatefulWidget {
  const _BackgroundParticles();

  @override
  State<_BackgroundParticles> createState() => _BackgroundParticlesState();
}

class _BackgroundParticlesState extends State<_BackgroundParticles>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _particles = List.generate(18, (_) => _Particle(rng));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ParticlePainter(_particles, _controller.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _Particle {
  final double x; // 0..1
  final double startY; // 0..1
  final double speed; // 0..1
  final double size;
  final double opacity;

  _Particle(Random rng)
      : x = rng.nextDouble(),
        startY = rng.nextDouble(),
        speed = 0.3 + rng.nextDouble() * 0.7,
        size = 1.5 + rng.nextDouble() * 2.5,
        opacity = 0.08 + rng.nextDouble() * 0.07;
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double t;

  _ParticlePainter(this.particles, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final y = (p.startY - t * p.speed) % 1.0;
      final paint = Paint()
        ..color = Colors.white.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(
        Offset(p.x * size.width, y * size.height),
        p.size,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

// ═══════════════════════════════════════════════════════════════════
//  HERO ANIMATIONS — Custom built for each slide
// ═══════════════════════════════════════════════════════════════════

// ──── Slide 1: Crescent Moon & Star ────
class _WelcomeHero extends StatefulWidget {
  final AnimationController animation;
  const _WelcomeHero({required this.animation});

  @override
  State<_WelcomeHero> createState() => _WelcomeHeroState();
}

class _WelcomeHeroState extends State<_WelcomeHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _loopController;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(220, 220),
          painter: _CrescentMoonPainter(_loopController.value),
        );
      },
    );
  }
}

class _CrescentMoonPainter extends CustomPainter {
  final double t;
  _CrescentMoonPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.35;

    // Gentle floating motion
    final floatY = sin(t * 2 * pi) * 6;
    final moonCenter = Offset(center.dx, center.dy + floatY);

    // Outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFFF5C842).withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30);
    canvas.drawCircle(moonCenter, radius + 20, glowPaint);

    // Moon circle
    final moonPaint = Paint()
      ..color = const Color(0xFFF5C842).withOpacity(0.85)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(moonCenter, radius, moonPaint);

    // Crescent cutout (inner shadow)
    final cutoutPaint = Paint()
      ..color = const Color(0xFF0B1B3A)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(moonCenter.dx + radius * 0.35, moonCenter.dy - radius * 0.1),
      radius * 0.75,
      cutoutPaint,
    );

    // Star
    final starAngle = t * 2 * pi * 0.3;
    final starCenter = Offset(
      moonCenter.dx + radius * 0.8,
      moonCenter.dy - radius * 0.7,
    );
    final starPaint = Paint()
      ..color = const Color(0xFFF5C842).withOpacity(0.9);

    // Draw 4-pointed star
    final starSize = 8.0 + sin(t * 2 * pi * 2) * 2;
    _drawStar(canvas, starCenter, starSize, starPaint, starAngle);

    // Additional twinkle stars
    for (int i = 0; i < 5; i++) {
      final angle = (i * 72 + t * 360 * 0.1) * pi / 180;
      final dist = radius * (1.2 + i * 0.15);
      final pos = Offset(
        center.dx + cos(angle) * dist,
        center.dy + sin(angle) * dist + floatY * 0.5,
      );
      final twinkleSize = 2.0 + sin(t * 2 * pi * 3 + i) * 1.5;
      final twinkleOpacity = 0.3 + sin(t * 2 * pi * 2 + i * 1.2).abs() * 0.5;
      final twinklePaint = Paint()
        ..color = Colors.white.withOpacity(twinkleOpacity);
      _drawStar(canvas, pos, twinkleSize, twinklePaint, 0);
    }

    // App name
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'صلاتي',
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: Colors.white.withOpacity(0.9),
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.rtl,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy + radius + 30 + floatY,
      ),
    );
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint, double rotation) {
    final path = Path();
    for (int i = 0; i < 4; i++) {
      final angle = rotation + i * pi / 2;
      path.moveTo(center.dx, center.dy);
      path.lineTo(
        center.dx + cos(angle) * size,
        center.dy + sin(angle) * size,
      );
    }
    canvas.drawPath(path, paint..strokeWidth = 1.5..style = PaintingStyle.stroke);
    canvas.drawCircle(center, size * 0.3, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant _CrescentMoonPainter old) => true;
}

// ──── Slide 2: Prayer Times Card ────
class _PrayerTimesHero extends StatefulWidget {
  final AnimationController animation;
  const _PrayerTimesHero({required this.animation});

  @override
  State<_PrayerTimesHero> createState() => _PrayerTimesHeroState();
}

class _PrayerTimesHeroState extends State<_PrayerTimesHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _loopController;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(240, 240),
          painter: _PrayerCardPainter(_loopController.value),
        );
      },
    );
  }
}

class _PrayerCardPainter extends CustomPainter {
  final double t;
  _PrayerCardPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final floatY = sin(t * 2 * pi) * 4;

    // Glass card background
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(center.dx, center.dy + floatY), width: 180, height: 200),
      const Radius.circular(20),
    );
    final cardPaint = Paint()
      ..color = Colors.white.withOpacity(0.08);
    canvas.drawRRect(cardRect, cardPaint);

    // Card border
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(cardRect, borderPaint);

    // Prayer name rows that build in
    final prayers = ['الفجر', 'الظهر', 'العصر', 'المغرب', 'العشاء'];
    final times = ['05:12', '12:30', '15:45', '18:28', '20:00'];
    final rowHeight = 28.0;
    final startY = center.dy - 70 + floatY;

    for (int i = 0; i < prayers.length; i++) {
      // Stagger appearance with looping pulse
      final delay = i * 0.12;
      final localT = ((t - delay) % 1.0).clamp(0.0, 1.0);
      final opacity = (localT < 0.15)
          ? (localT / 0.15).clamp(0.0, 1.0)
          : 1.0;
      final activeIndex = ((t * 5) % 5).floor();
      final isActive = i == activeIndex;

      // Active glow
      if (isActive) {
        final glowRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            center.dx - 75,
            startY + i * rowHeight - 2,
            150,
            rowHeight - 4,
          ),
          const Radius.circular(8),
        );
        final activePaint = Paint()
          ..color = const Color(0xFF4CAF82).withOpacity(0.15);
        canvas.drawRRect(glowRect, activePaint);
      }

      // Prayer name (right-aligned)
      final namePainter = TextPainter(
        text: TextSpan(
          text: prayers[i],
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
            color: Colors.white.withOpacity(opacity * (isActive ? 1.0 : 0.6)),
          ),
        ),
        textDirection: TextDirection.rtl,
      );
      namePainter.layout();
      namePainter.paint(canvas, Offset(center.dx + 55, startY + i * rowHeight));

      // Time (left-aligned)
      final timePainter = TextPainter(
        text: TextSpan(
          text: times[i],
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: Colors.white.withOpacity(opacity * (isActive ? 0.9 : 0.4)),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      timePainter.layout();
      timePainter.paint(canvas, Offset(center.dx - 75, startY + i * rowHeight + 1));
    }

    // Title at top of card
    final titlePainter = TextPainter(
      text: TextSpan(
        text: 'مواقيت اليوم',
        style: TextStyle(
          fontFamily: 'Tajawal',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.white.withOpacity(0.85),
        ),
      ),
      textDirection: TextDirection.rtl,
    );
    titlePainter.layout();
    titlePainter.paint(
      canvas,
      Offset(center.dx - titlePainter.width / 2, startY - 35),
    );
  }

  @override
  bool shouldRepaint(covariant _PrayerCardPainter old) => true;
}

// ──── Slide 3: Compass ────
class _QiblaHero extends StatefulWidget {
  final AnimationController animation;
  const _QiblaHero({required this.animation});

  @override
  State<_QiblaHero> createState() => _QiblaHeroState();
}

class _QiblaHeroState extends State<_QiblaHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _loopController;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(220, 220),
          painter: _CompassPainter(_loopController.value),
        );
      },
    );
  }
}

class _CompassPainter extends CustomPainter {
  final double t;
  _CompassPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.38;

    // Outer ring
    final ringPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius, ringPaint);

    // Inner ring
    canvas.drawCircle(center, radius * 0.75, ringPaint..color = Colors.white.withOpacity(0.06));

    // Tick marks
    for (int i = 0; i < 36; i++) {
      final angle = i * pi / 18;
      final isMajor = i % 9 == 0;
      final innerR = radius * (isMajor ? 0.85 : 0.92);
      final outerR = radius * 0.98;
      final tickPaint = Paint()
        ..color = Colors.white.withOpacity(isMajor ? 0.5 : 0.15)
        ..strokeWidth = isMajor ? 2 : 1;
      canvas.drawLine(
        Offset(center.dx + cos(angle) * innerR, center.dy + sin(angle) * innerR),
        Offset(center.dx + cos(angle) * outerR, center.dy + sin(angle) * outerR),
        tickPaint,
      );
    }

    // Compass needle — spins then locks
    // First 60% of time: spinning; last 40%: locked at ~45°
    final needleAngle = t < 0.6
        ? t / 0.6 * 2 * pi * 1.5 // Spinning
        : pi / 4 + sin((t - 0.6) / 0.4 * pi) * 0.05; // Locked with subtle oscillation

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(needleAngle - pi / 2);

    // North (red ) needle
    final northPath = Path()
      ..moveTo(0, -radius * 0.6)
      ..lineTo(-6, 0)
      ..lineTo(6, 0)
      ..close();
    canvas.drawPath(northPath, Paint()..color = const Color(0xFF4A90D9).withOpacity(0.9));

    // South needle
    final southPath = Path()
      ..moveTo(0, radius * 0.4)
      ..lineTo(-5, 0)
      ..lineTo(5, 0)
      ..close();
    canvas.drawPath(southPath, Paint()..color = Colors.white.withOpacity(0.3));

    canvas.restore();

    // Center dot
    canvas.drawCircle(center, 5, Paint()..color = Colors.white.withOpacity(0.8));
    canvas.drawCircle(center, 3, Paint()..color = const Color(0xFF4A90D9));

    // Qibla label
    if (t > 0.6) {
      final labelOpacity = ((t - 0.6) / 0.1).clamp(0.0, 1.0);
      final qiblaAngle = pi / 4 - pi / 2;
      final labelPos = Offset(
        center.dx + cos(qiblaAngle) * (radius + 20),
        center.dy + sin(qiblaAngle) * (radius + 20),
      );
      final labelPainter = TextPainter(
        text: TextSpan(
          text: 'القبلة',
          style: TextStyle(
            fontFamily: 'Tajawal',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4A90D9).withOpacity(labelOpacity),
          ),
        ),
        textDirection: TextDirection.rtl,
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(labelPos.dx - labelPainter.width / 2, labelPos.dy - labelPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) => true;
}

// ──── Slide 4: Location & Notification ────
class _PermissionsHero extends StatefulWidget {
  final AnimationController animation;
  const _PermissionsHero({required this.animation});

  @override
  State<_PermissionsHero> createState() => _PermissionsHeroState();
}

class _PermissionsHeroState extends State<_PermissionsHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _loopController;

  @override
  void initState() {
    super.initState();
    _loopController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _loopController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _loopController,
      builder: (context, _) {
        return CustomPaint(
          size: const Size(220, 180),
          painter: _PermissionsIconPainter(_loopController.value),
        );
      },
    );
  }
}

class _PermissionsIconPainter extends CustomPainter {
  final double t;
  _PermissionsIconPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // Location pin
    final pinCenter = Offset(center.dx - 40, center.dy);
    // Pin drop animation (first 30% of loop)
    final dropProgress = t < 0.3 ? t / 0.3 : 1.0;
    final pinY = pinCenter.dy - 30 * (1 - Curves.bounceOut.transform(dropProgress));
    final pinOpacity = dropProgress.clamp(0.0, 1.0);

    // Pin body
    final pinPath = Path();
    final pinTop = Offset(pinCenter.dx, pinY - 25);
    pinPath.addOval(Rect.fromCircle(center: Offset(pinCenter.dx, pinY - 12), radius: 18));
    // Pin point
    pinPath.moveTo(pinCenter.dx - 12, pinY);
    pinPath.quadraticBezierTo(pinCenter.dx, pinY + 28, pinCenter.dx + 12, pinY);

    canvas.drawPath(
      pinPath,
      Paint()..color = const Color(0xFF9B6FD4).withOpacity(0.8 * pinOpacity),
    );
    // Inner circle
    canvas.drawCircle(
      Offset(pinCenter.dx, pinY - 12),
      7,
      Paint()..color = Colors.white.withOpacity(0.7 * pinOpacity),
    );

    // Glow ring around pin (pulses)
    final pulseRadius = 25.0 + sin(t * 2 * pi * 2) * 8;
    final pulsePaint = Paint()
      ..color = const Color(0xFF9B6FD4).withOpacity(0.1 + sin(t * 2 * pi * 2).abs() * 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(Offset(pinCenter.dx, pinY - 12), pulseRadius, pulsePaint);

    // Notification bell (right side)
    final bellCenter = Offset(center.dx + 40, center.dy - 10);
    // Bell ring animation (between 50-70% of loop)
    final bellRing = t > 0.5 && t < 0.7
        ? sin((t - 0.5) / 0.2 * pi * 4) * 0.15
        : 0.0;

    canvas.save();
    canvas.translate(bellCenter.dx, bellCenter.dy);
    canvas.rotate(bellRing);

    // Bell shape
    final bellPath = Path();
    bellPath.moveTo(-15, 0);
    bellPath.quadraticBezierTo(-15, -20, -5, -28);
    bellPath.lineTo(-3, -32);
    bellPath.quadraticBezierTo(0, -35, 3, -32);
    bellPath.lineTo(5, -28);
    bellPath.quadraticBezierTo(15, -20, 15, 0);
    bellPath.close();

    canvas.drawPath(
      bellPath,
      Paint()..color = const Color(0xFFF5C842).withOpacity(0.8),
    );

    // Bell clapper
    canvas.drawCircle(
      const Offset(0, 5),
      4,
      Paint()..color = const Color(0xFFF5C842).withOpacity(0.9),
    );

    canvas.restore();

    // Sound waves from bell (appear during ring)
    if (t > 0.5 && t < 0.8) {
      final waveProgress = (t - 0.5) / 0.3;
      for (int i = 0; i < 3; i++) {
        final waveRadius = 20.0 + i * 12 + waveProgress * 15;
        final waveOpacity = (0.3 - waveProgress * 0.3 - i * 0.08).clamp(0.0, 1.0);
        final wavePaint = Paint()
          ..color = const Color(0xFFF5C842).withOpacity(waveOpacity)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawArc(
          Rect.fromCircle(center: Offset(bellCenter.dx + 10, bellCenter.dy - 15), radius: waveRadius),
          -pi / 4,
          pi / 2,
          false,
          wavePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PermissionsIconPainter old) => true;
}
