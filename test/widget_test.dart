// Widget tests for plugin-free UI building blocks.
// (The full app can't be pumped in a unit test — it needs Firebase and
// platform channels — so we test the reusable widgets directly.)

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adhan_app/presentation/widgets/pressable_scale.dart';
import 'package:adhan_app/presentation/widgets/crescent_loader.dart';
import 'package:adhan_app/presentation/widgets/app_sheet.dart';

void main() {
  testWidgets('PressableScale fires onTap and renders its child',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PressableScale(
            haptic: false,
            onTap: () => tapped++,
            child: const Text('tap me'),
          ),
        ),
      ),
    );

    expect(find.text('tap me'), findsOneWidget);
    await tester.tap(find.text('tap me'));
    await tester.pumpAndSettle();
    expect(tapped, 1);
  });

  testWidgets('PressableScale scales down while pressed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: PressableScale(
            haptic: false,
            onTap: () {},
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      ),
    );

    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(SizedBox)));
    await tester.pump(const Duration(milliseconds: 200));

    final animatedScale =
        tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(animatedScale.scale, lessThan(1.0));

    await gesture.up();
    await tester.pumpAndSettle();
    final settled = tester.widget<AnimatedScale>(find.byType(AnimatedScale));
    expect(settled.scale, 1.0);
  });

  testWidgets('CrescentLoader renders and animates without errors',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: CrescentLoader())),
    );

    expect(find.byType(CrescentLoader), findsOneWidget);
    // Advance a few frames of the spin — must not throw
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('StaggerIn ends fully visible at its resting position',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: StaggerIn(index: 2, child: Text('staggered')),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('staggered'), findsOneWidget);
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('staggered'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1.0);
  });
}
