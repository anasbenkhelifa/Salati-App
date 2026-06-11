import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_theme_provider.dart';
import '../../core/theme/app_motion.dart';

/// Ambient animated background layer: a slowly drifting field of Andalusian
/// rosettes plus soft "aurora" glows in the theme accent that breathe over
/// the ambient cycle.
///
/// Performance contract (Phase 5):
///  - the rosette lattice is BAKED once into a softened ui.Image per
///    size/theme — per-frame cost is a single drawImage, not re-stroking
///    thousands of Bézier segments (and no screen-wide BackdropFilter is
///    needed above this layer to soften it; the blur is baked in)
///  - ambient repaints are throttled to ~30fps (the drift moves ~8px/s, so
///    anything faster is invisible); parallax from [pageController] still
///    repaints at full rate during swipes for smoothness
///  - lives inside its own RepaintBoundary; repaints never go through setState
class LivingBackground extends StatefulWidget {
  /// PageController of the main PageView; used for a subtle parallax shift.
  final PageController? pageController;

  /// Optional special-occasion tint (Ramadan/Eid) blended into the auroras.
  final Color? eventTint;

  const LivingBackground({super.key, this.pageController, this.eventTint});

  @override
  State<LivingBackground> createState() => _LivingBackgroundState();
}

class _LivingBackgroundState extends State<LivingBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final _ThrottledListenable _ambient;

  ui.Image? _latticeImage;
  Size? _bakedSize;
  Color? _bakedLineColor;
  bool _baking = false;
  Size? _lastLayoutSize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppMotion.ambient)
      ..repeat();
    // 30fps is indistinguishable for an 8px/s drift; on 120Hz displays this
    // skips 3 of every 4 ambient repaints.
    _ambient = _ThrottledListenable(_controller, targetFps: 30);
    AppThemeProvider.instance.addListener(_onThemeChanged);
  }

  @override
  void didUpdateWidget(LivingBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventTint != widget.eventTint) {
      _maybeBake();
    }
  }

  void _onThemeChanged() => _maybeBake();

  @override
  void dispose() {
    AppThemeProvider.instance.removeListener(_onThemeChanged);
    _ambient.dispose();
    _controller.dispose();
    _latticeImage?.dispose();
    super.dispose();
  }

  /// (Re)bake the lattice image if the size or line color changed.
  void _maybeBake() {
    final size = _lastLayoutSize;
    if (!mounted || size == null || size.isEmpty) return;
    final lineColor = _LivingBackgroundPainter.latticeLineColor(
      widget.eventTint,
    );
    if (_latticeImage != null &&
        _bakedSize == size &&
        _bakedLineColor == lineColor) {
      return;
    }
    if (_baking) return; // in-flight bake revalidates when done
    _baking = true;

    _bakeLattice(size, lineColor).then((image) {
      if (!mounted) {
        image.dispose();
        return;
      }
      _latticeImage?.dispose();
      setState(() {
        _latticeImage = image;
        _bakedSize = size;
        _bakedLineColor = lineColor;
        _baking = false;
      });
      // Theme/size may have changed while baking — converge.
      _maybeBake();
    });
  }

  /// Render the rosette lattice once, with the softening blur BAKED IN, so
  /// no per-frame blur or path stroking is ever needed again.
  static Future<ui.Image> _bakeLattice(Size size, Color lineColor) async {
    const margin = _LivingBackgroundPainter.latticeMargin;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    // Path coordinates start at -margin; shift so they land in the image
    canvas.translate(margin, margin);

    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = lineColor
          // Replaces the old screen-wide BackdropFilter softening (sigma 3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
    canvas.drawPath(_LivingBackgroundPainter.buildLatticePath(size), paint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (size.width + 2 * margin).ceil(),
      (size.height + 2 * margin).ceil(),
    );
    picture.dispose();
    return image;
  }

  @override
  Widget build(BuildContext context) {
    final repaint =
        widget.pageController == null
            ? _ambient as Listenable
            : Listenable.merge([_ambient, widget.pageController!]);

    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          if (size.isFinite && !size.isEmpty && size != _lastLayoutSize) {
            _lastLayoutSize = size;
            WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBake());
          }
          return CustomPaint(
            painter: _LivingBackgroundPainter(
              animation: _controller,
              pageController: widget.pageController,
              eventTint: widget.eventTint,
              latticeImage: _latticeImage,
              repaint: repaint,
            ),
            size: Size.infinite,
            willChange: true,
          );
        },
      ),
    );
  }
}

/// Relays an animation's ticks at a capped frame rate. The painter listens
/// to this instead of the raw controller, halving (or quartering, on high
/// refresh displays) ambient repaint work with zero visual difference.
class _ThrottledListenable extends ChangeNotifier {
  final AnimationController _controller;
  final double _minStep;
  double _last = -1;

  _ThrottledListenable(this._controller, {required int targetFps})
    : _minStep =
          1 /
          (((_controller.duration?.inMilliseconds ?? 24000) / 1000) *
              targetFps) {
    _controller.addListener(_onTick);
  }

  void _onTick() {
    final v = _controller.value;
    // v < _last happens on loop wrap — always emit that frame
    if (v < _last || (v - _last) >= _minStep) {
      _last = v;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    super.dispose();
  }
}

class _LivingBackgroundPainter extends CustomPainter {
  final Animation<double> animation;
  final PageController? pageController;
  final Color? eventTint;
  final ui.Image? latticeImage;

  _LivingBackgroundPainter({
    required this.animation,
    required this.pageController,
    this.eventTint,
    this.latticeImage,
    required Listenable repaint,
  }) : super(repaint: repaint);

  // Fallback path cache (used only for the first frames before the baked
  // image is ready).
  static Path? _latticePath;
  static Size? _latticeSize;

  static const double _tile = 200.0;

  /// Lattice extends this far beyond every screen edge so drift + parallax
  /// never expose a border. Must match the -2-tile start in
  /// [buildLatticePath].
  static const double latticeMargin = 2 * _tile;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;

    final t = animation.value; // 0..1 looping
    _paintAurora(canvas, size, t);
    _paintLattice(canvas, size, t);
  }

  // ===== Aurora: 3 soft radial glows that drift and breathe =====
  void _paintAurora(Canvas canvas, Size size, double t) {
    final angle = t * 2 * math.pi;
    final isLight = AppTheme.isLightMode;
    final gradientColors = AppTheme.currentAccentGradient.colors;
    // Special occasions (Ramadan/Eid) warm the auroras toward the event tint
    final accentA =
        eventTint == null
            ? gradientColors.first
            : Color.lerp(gradientColors.first, eventTint, 0.65)!;
    final accentB =
        eventTint == null
            ? gradientColors.last
            : Color.lerp(gradientColors.last, eventTint, 0.65)!;

    // Auroras breathe stronger on special occasions
    final eventBoost = eventTint == null ? 1.0 : 1.3;
    final baseAlpha = (isLight ? 0.13 : 0.20) * eventBoost;
    final blobs = [
      _AuroraBlob(
        center: Offset(
          size.width * (0.20 + 0.12 * math.sin(angle)),
          size.height * (0.22 + 0.08 * math.cos(angle)),
        ),
        radius: size.width * (0.60 + 0.10 * math.sin(angle + 1.3)),
        color: accentA,
        alpha: baseAlpha,
      ),
      _AuroraBlob(
        center: Offset(
          size.width * (0.85 + 0.10 * math.cos(angle + 2.1)),
          size.height * (0.58 + 0.09 * math.sin(angle + 2.1)),
        ),
        radius: size.width * (0.55 + 0.09 * math.cos(angle)),
        color: accentB,
        alpha: baseAlpha * 0.85,
      ),
      _AuroraBlob(
        center: Offset(
          size.width * (0.45 + 0.13 * math.sin(angle + 4.2)),
          size.height * (0.95 + 0.05 * math.cos(angle + 4.2)),
        ),
        radius: size.width * 0.65,
        color: accentA,
        alpha: baseAlpha * 0.75,
      ),
    ];

    for (final blob in blobs) {
      final paint =
          Paint()
            ..shader = RadialGradient(
              colors: [
                blob.color.withValues(alpha: blob.alpha),
                blob.color.withValues(alpha: 0.0),
              ],
            ).createShader(
              Rect.fromCircle(center: blob.center, radius: blob.radius),
            );
      canvas.drawCircle(blob.center, blob.radius, paint);
    }
  }

  /// Accent-tinted zellige line color so the pattern reads as part of the
  /// theme, not noise. The Islamic Blue/Green themes lean on the pattern as
  /// their identity, so it runs stronger there; Special still has its image
  /// underneath, so the procedural layer stays soft to not fight it.
  /// During Ramadan/Eid the rosettes warm toward the event tint too.
  static Color latticeLineColor(Color? eventTint) {
    final hasPatternImage = AppTheme.currentBackgroundImage != null;
    final isLight = AppTheme.isLightMode;
    final isOrnate = AppTheme.isIslamicMode || AppTheme.isIslamicGreenMode;
    var accent = AppTheme.currentAccentGradient.colors.first;
    if (eventTint != null) {
      accent = Color.lerp(accent, eventTint, 0.5)!;
    }
    return isLight
        ? Color.lerp(
          AppTheme.lightTextPrimary,
          accent,
          0.65,
        )!.withValues(alpha: 0.11)
        : Color.lerp(
          Colors.white,
          accent,
          isOrnate ? 0.70 : 0.55,
        )!.withValues(alpha: hasPatternImage ? 0.07 : (isOrnate ? 0.15 : 0.11));
  }

  // ===== Rosette field: baked image translated per frame =====
  void _paintLattice(Canvas canvas, Size size, double t) {
    // Seamless diagonal drift: one full tile per ambient cycle.
    final drift = t * _tile;

    // Parallax: shift ~15% of swipe distance, centered on the Home page (1).
    double parallax = 0;
    final pc = pageController;
    if (pc != null && pc.hasClients && pc.position.haveDimensions) {
      parallax = ((pc.page ?? 1.0) - 1.0) * size.width * 0.15;
    }

    final image = latticeImage;
    if (image != null) {
      // Fast path: one image draw per frame. Image pixel (0,0) corresponds
      // to lattice coordinate (-latticeMargin, -latticeMargin).
      canvas.drawImage(
        image,
        Offset(-latticeMargin - drift - parallax, -latticeMargin - drift),
        Paint()..filterQuality = FilterQuality.low,
      );
      return;
    }

    // Fallback for the first frames while the bake is in flight: stroke the
    // path directly (same as the pre-Phase-5 behavior).
    if (_latticePath == null || _latticeSize != size) {
      _latticePath = buildLatticePath(size);
      _latticeSize = size;
    }
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3
          ..color = latticeLineColor(eventTint);

    canvas.save();
    canvas.translate(-drift - parallax, -drift);
    canvas.drawPath(_latticePath!, paint);
    canvas.restore();
  }

  /// Builds one big path of curved Andalusian rosettes on a square grid:
  /// a full rosette (curved 8-point frame, ring of almond petals, lotus
  /// heart) at every grid node and a small lotus at every tile heart.
  /// All curves — no straight-edged geometry. Covers the screen plus a
  /// [latticeMargin] on every side so the drift never exposes an edge.
  static Path buildLatticePath(Size size) {
    final path = Path();
    final cols = (size.width / _tile).ceil() + 4;
    final rows = (size.height / _tile).ceil() + 4;

    // Start at -2 so drift + parallax (either direction) never exposes an edge
    for (int row = -2; row < rows; row++) {
      for (int col = -2; col < cols; col++) {
        final node = Offset(col * _tile, row * _tile);
        final heart = Offset(node.dx + _tile / 2, node.dy + _tile / 2);

        _addRosette(path, node, _tile * 0.40);
        _addPetalStar(
          path,
          heart,
          points: 8,
          outer: _tile * 0.13,
          inner: _tile * 0.055,
          rotation: math.pi / 8,
        );
      }
    }
    return path;
  }

  /// Full Andalusian rosette: concave-curved 8-point outer frame, a ring
  /// of eight almond petals offset 22.5°, and an 8-petal lotus heart.
  static void _addRosette(Path path, Offset c, double r) {
    _addCurvedStar(path, c, points: 8, outer: r, valley: r * 0.52, rotation: 0);
    _addPetalRing(
      path,
      c,
      count: 8,
      inner: r * 0.18,
      outer: r * 0.68,
      bulge: r * 0.42,
      rotation: math.pi / 8,
    );
    _addPetalStar(
      path,
      c,
      points: 8,
      outer: r * 0.34,
      inner: r * 0.13,
      rotation: 0,
    );
  }

  static Offset _polar(Offset c, double radius, double angle) =>
      Offset(c.dx + radius * math.cos(angle), c.dy + radius * math.sin(angle));

  /// Star whose sides sweep inward as concave curves (the outer frame of
  /// the reference rosette).
  static void _addCurvedStar(
    Path path,
    Offset c, {
    required int points,
    required double outer,
    required double valley,
    required double rotation,
  }) {
    final step = 2 * math.pi / points;
    final a0 = rotation - math.pi / 2;
    final start = _polar(c, outer, a0);
    path.moveTo(start.dx, start.dy);
    for (int k = 1; k <= points; k++) {
      final ctrl = _polar(c, valley, a0 + step * (k - 0.5));
      final next = _polar(c, outer, a0 + step * k);
      path.quadraticBezierTo(ctrl.dx, ctrl.dy, next.dx, next.dy);
    }
  }

  /// Lotus: petals with pointed tips and gently bowed sides meeting at
  /// inner cusps (the heart of the reference rosette).
  static void _addPetalStar(
    Path path,
    Offset c, {
    required int points,
    required double outer,
    required double inner,
    required double rotation,
  }) {
    final step = 2 * math.pi / points;
    final base = rotation - math.pi / 2;
    final start = _polar(c, inner, base - step / 2);
    path.moveTo(start.dx, start.dy);
    for (int k = 0; k < points; k++) {
      final aTip = base + k * step;
      final tip = _polar(c, outer, aTip);
      final cusp = _polar(c, inner, aTip + step / 2);
      final ctrlIn = _polar(c, outer * 0.72, aTip - step * 0.30);
      final ctrlOut = _polar(c, outer * 0.72, aTip + step * 0.30);
      path.quadraticBezierTo(ctrlIn.dx, ctrlIn.dy, tip.dx, tip.dy);
      path.quadraticBezierTo(ctrlOut.dx, ctrlOut.dy, cusp.dx, cusp.dy);
    }
  }

  /// Ring of almond-shaped petals radiating between the lotus heart and
  /// the outer frame.
  static void _addPetalRing(
    Path path,
    Offset c, {
    required int count,
    required double inner,
    required double outer,
    required double bulge,
    required double rotation,
  }) {
    final step = 2 * math.pi / count;
    for (int k = 0; k < count; k++) {
      final a = rotation - math.pi / 2 + k * step;
      final pIn = _polar(c, inner, a);
      final pOut = _polar(c, outer, a);
      final ctrlL = _polar(c, bulge, a - step * 0.32);
      final ctrlR = _polar(c, bulge, a + step * 0.32);
      path.moveTo(pIn.dx, pIn.dy);
      path.quadraticBezierTo(ctrlL.dx, ctrlL.dy, pOut.dx, pOut.dy);
      path.quadraticBezierTo(ctrlR.dx, ctrlR.dy, pIn.dx, pIn.dy);
    }
  }

  @override
  bool shouldRepaint(covariant _LivingBackgroundPainter oldDelegate) =>
      oldDelegate.latticeImage != latticeImage;
}

class _AuroraBlob {
  final Offset center;
  final double radius;
  final Color color;
  final double alpha;

  const _AuroraBlob({
    required this.center,
    required this.radius,
    required this.color,
    required this.alpha,
  });
}
