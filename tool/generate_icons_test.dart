// Manual tool — renders the launcher-icon SVGs to PNG.
// Run explicitly (not picked up by `flutter test`):
//   flutter test tool/generate_icons_test.dart
// Then: flutter pub run flutter_launcher_icons

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _render(String inPath, String outPath, int size) async {
  final svg = await File(inPath).readAsString();
  final info = await vg.loadPicture(SvgStringLoader(svg), null);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final scale = size / info.size.width;
  canvas.scale(scale, scale);
  canvas.drawPicture(info.picture);

  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(outPath).writeAsBytes(bytes!.buffer.asUint8List());
  info.picture.dispose();
  // ignore: avoid_print
  print('Wrote $outPath (${size}x$size)');
}

/// Adaptive foreground: the icon's mark (background rect stripped) drawn
/// transparent, centered in the 66% safe zone of a 108-unit canvas.
/// (The hand-made foreground SVG used a nested <svg>, which flutter_svg
/// renders as nothing — so we derive it from the main icon instead.)
Future<void> _renderForeground(
  String inPath,
  String outPath,
  int size,
) async {
  var svg = await File(inPath).readAsString();
  svg = svg.replaceFirst(
    RegExp(r'<rect width="96" height="96"[^>]*></rect>'),
    '',
  );
  final info = await vg.loadPicture(SvgStringLoader(svg), null);

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  // 72/108 of the canvas is the adaptive-icon safe zone
  final content = size * 72 / 108;
  final offset = (size - content) / 2;
  canvas.translate(offset, offset);
  canvas.scale(content / info.size.width);
  canvas.drawPicture(info.picture);

  final image = await recorder.endRecording().toImage(size, size);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(outPath).writeAsBytes(bytes!.buffer.asUint8List());
  info.picture.dispose();
  // ignore: avoid_print
  print('Wrote $outPath (${size}x$size, foreground)');
}

void main() {
  testWidgets('generate launcher icon PNGs from SVGs', (tester) async {
    await tester.runAsync(() async {
      await _render(
        'assets/icon_source/salati-icon-512.svg',
        'assets/icon_source/salati_icon_1024.png',
        1024,
      );
      await _renderForeground(
        'assets/icon_source/salati-icon-512.svg',
        'assets/icon_source/salati_adaptive_fg_1024.png',
        1024,
      );
    });
  });
}
