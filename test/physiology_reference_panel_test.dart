import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/usecases/physiology_reference_trace_provider.dart';
import 'package:parkinsum_companion/features/algorithm_observatory/physiology_reference_panel.dart';

void main() {
  final provider = PhysiologyReferenceTraceProvider(draws: 20);

  Future<void> pumpPanel(WidgetTester tester, Brightness brightness) async {
    await tester.binding.setSurfaceSize(const Size(900, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: SingleChildScrollView(
            child: PhysiologyReferencePanel(provider: provider),
          ),
        ),
      ),
    );
  }

  for (final brightness in Brightness.values) {
    testWidgets('renders unit charts and the band table ($brightness)', (
      tester,
    ) async {
      await pumpPanel(tester, brightness);
      expect(
        find.byKey(const Key('chart-panel-physiology-reference')),
        findsOneWidget,
      );
      for (final id in ['levodopa', 'lnaa', 'brain-entry']) {
        expect(
          find.byKey(Key('physiology-reference-chart-$id')),
          findsOneWidget,
        );
      }
      expect(find.text('Plasma levodopa (mg/L)'), findsOneWidget);
      expect(find.textContaining('(µmol/L)'), findsOneWidget);
      expect(
        find.text('Peak gastric energy delivery (kcal/min)'),
        findsOneWidget,
      );
      final table = find.byKey(const Key('physiology-reference-band-table'));
      for (final label in [
        'no meal',
        'meal 60 min before dose',
        'meal with dose',
        'meal 60 min after dose',
      ]) {
        expect(
          find.descendant(of: table, matching: find.text(label)),
          findsOneWidget,
        );
      }
      expect(
        find.descendant(of: table, matching: find.text('reference')),
        findsOneWidget,
      );
      expect(find.textContaining('still marked "verify"'), findsOneWidget);
      expect(
        find.textContaining('not a prediction for any person'),
        findsOneWidget,
      );
      // Descriptive only: no ranking or recommended time.
      expect(
        find.textContaining(
          RegExp('best|recommended|optimal', caseSensitive: false),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('reflows at 320 px with 200% text', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 4000),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(
            body: SingleChildScrollView(
              child: PhysiologyReferencePanel(provider: provider),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('physiology-reference-band-table')),
      findsOneWidget,
    );
  });
}
