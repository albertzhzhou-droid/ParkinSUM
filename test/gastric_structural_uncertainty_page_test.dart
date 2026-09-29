import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/theme/paper_theme.dart';
import 'package:parkinsum_companion/domain/entities/gastric_structural_uncertainty.dart';
import 'package:parkinsum_companion/features/algorithm_observatory/algorithm_observatory_page.dart';

void main() {
  testWidgets(
    'observatory exposes every gastric structure and truth boundary',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 1600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          theme: Paper.themeData(),
          home: const AlgorithmObservatoryPage(),
        ),
      );
      await tester.pump();

      final contracts = find.byKey(
        const Key('gastric-structural-uncertainty-contracts'),
      );
      await tester.scrollUntilVisible(
        contracts,
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const Key('observatory-scroll-list')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(contracts, findsOneWidget);
      expect(
        find.byKey(const Key('chart-panel-gastric-structural-uncertainty')),
        findsOneWidget,
      );
      expect(find.text('6 structures'), findsOneWidget);
      expect(find.text('4 comparable'), findsOneWidget);
      expect(find.text('2 observable-held'), findsOneWidget);
      for (final kind in GastricStructureKind.values) {
        expect(
          find.byKey(Key('gastric-structure-card-${kind.name}')),
          findsOneWidget,
        );
      }

      final linearCard = find.byKey(
        const Key('gastric-structure-card-linearExponentialVolume'),
      );
      await tester.ensureVisible(linearCard);
      await tester.pumpAndSettle();
      await tester.tap(linearCard);
      await tester.pumpAndSettle();
      expect(find.textContaining('V(t)=V0'), findsOneWidget);
      expect(find.textContaining('absoluteGastricVolume'), findsWidgets);
      expect(find.textContaining('magneticResonanceImaging'), findsWidgets);
      expect(find.textContaining('observable_mismatch'), findsWidgets);

      expect(
        find.byKey(const Key('gastric-structural-boundary')),
        findsOneWidget,
      );
      expect(find.textContaining('not an ensemble'), findsWidgets);
      expect(find.textContaining('clinical validation'), findsWidgets);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );
}
