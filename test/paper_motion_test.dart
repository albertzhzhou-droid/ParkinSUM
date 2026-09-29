import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/theme/paper_theme.dart';

/// Motion contract for the Paper design system: entrance animations are
/// finite (nothing keeps scheduling frames), and the platform's
/// reduced-motion setting turns them off entirely.
void main() {
  Widget host({required bool reduceMotion, required Widget child}) =>
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: child),
        ),
      );

  testWidgets('reveal plays once and settles', (tester) async {
    await tester.pumpWidget(
      host(
        reduceMotion: false,
        child: const PaperReveal(order: 2, child: Text('entry')),
      ),
    );
    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(PaperReveal),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, lessThan(1));

    await tester.pumpAndSettle();
    expect(fade.opacity.value, 1);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('reduced motion shows content without any entrance', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        reduceMotion: true,
        child: const Column(
          children: [
            PaperReveal(child: Text('entry')),
            SizedBox(
              height: 40,
              child: PaperGrowBar(
                factor: 0.5,
                child: ColoredBox(key: ValueKey('bar'), color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
    expect(
      find.descendant(
        of: find.byType(PaperReveal),
        matching: find.byType(FadeTransition),
      ),
      findsNothing,
    );
    expect(
      Paper.motion(tester.element(find.text('entry')), Paper.motionLong),
      Duration.zero,
    );
    // Bars are already at their final size on the first frame.
    expect(tester.getSize(find.byKey(const ValueKey('bar'))).height, 20);
  });

  testWidgets('grow bars ease to a new value and stop', (tester) async {
    var factor = 0.2;
    late StateSetter update;
    await tester.pumpWidget(
      host(
        reduceMotion: false,
        child: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return SizedBox(
              height: 100,
              child: PaperGrowBar(
                factor: factor,
                child: const ColoredBox(
                  key: ValueKey('bar'),
                  color: Colors.red,
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('bar'))).height, 20);

    update(() => factor = 0.8);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final mid = tester.getSize(find.byKey(const ValueKey('bar'))).height;
    expect(mid, greaterThan(20));
    expect(mid, lessThan(80));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byKey(const ValueKey('bar'))).height, 80);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
