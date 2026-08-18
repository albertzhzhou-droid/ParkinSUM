import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_descriptor.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_trace_node.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_candidate_score.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';
import 'package:parkinsum_companion/features/algorithm_observatory/algorithm_observatory_page.dart';

void main() {
  testWidgets('renders live mechanism panels and scenario interaction', (
    tester,
  ) async {
    final snapshot = AlgorithmObservatoryService().build(
      ObservatoryScenario.mixedReference,
    );
    final rawMostlyEmptiedStart = snapshot
        .conflict
        .primaryEmptyingProfile!
        .mostlyEmptiedWindow
        .startMinute;
    final rawAbsorptionPeak =
        snapshot.conflict.absorptionOpportunityWindow!.peakMinute;
    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pump();
    final outerScrollable = find.byType(Scrollable).first;

    expect(find.text('Algorithm Observatory'), findsOneWidget);
    final comparisonTable = find.byKey(
      const Key('observatory-sensitivity-comparison-table'),
    );
    expect(comparisonTable, findsOneWidget);
    for (final label in [
      'Mixed reference',
      'High fat + protein',
      'Missing data',
    ]) {
      expect(
        find.descendant(of: comparisonTable, matching: find.text(label)),
        findsOneWidget,
      );
    }

    await tester.tap(
      find.byKey(const Key('observatory-scenario-highFatProtein')),
    );
    await tester.pump();
    expect(find.textContaining('High fat + protein'), findsWidgets);

    await tester.scrollUntilVisible(
      find.byKey(const Key('chart-panel-gastric-emptying')),
      400,
      scrollable: outerScrollable,
    );
    await tester.drag(find.byType(ListView).first, const Offset(0, -360));
    await tester.pump();
    expect(find.text('1 · Gastric emptying model'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('chart-data-table-gastric-emptying')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    final chartTable = find.descendant(
      of: find.byKey(const Key('chart-data-table-gastric-emptying')),
      matching: find.byType(DataTable),
    );
    expect(chartTable, findsOneWidget);
    final chartScrollbar = tester.widget<Scrollbar>(
      find.byKey(const Key('chart-data-scrollbar-gastric-emptying')),
    );
    expect(chartScrollbar.thumbVisibility, isTrue);
    expect(chartScrollbar.trackVisibility, isTrue);
    expect(chartScrollbar.scrollbarOrientation, ScrollbarOrientation.bottom);
    final chartSemantics = tester.widget<Semantics>(
      find.byKey(const Key('chart-data-semantics-gastric-emptying')),
    );
    expect(
      chartSemantics.properties.label,
      'Equivalent point-by-point data table for this chart',
    );
    expect(
      find.descendant(of: chartTable, matching: find.text('Meal remaining')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chartTable, matching: find.text('100.0%')),
      findsWidgets,
    );
    expect(
      find.descendant(
        of: chartTable,
        matching: find.textContaining('fraction/min'),
      ),
      findsWidgets,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('chart-panel-absorption-competition')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.byKey(const Key('chart-panel-absorption-competition')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-conflict-panel')),
      260,
      scrollable: outerScrollable,
    );
    expect(find.byKey(const Key('observatory-conflict-panel')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-explanation-tree')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.byKey(const Key('trace-node-mechanistic_conflict')),
      findsOneWidget,
    );
    expect(find.textContaining('min after meal start'), findsOneWidget);
    expect(find.textContaining('min after dose'), findsOneWidget);
    expect(find.textContaining('$rawMostlyEmptiedStart'), findsNothing);
    expect(find.textContaining('$rawAbsorptionPeak'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-parameter-evidence')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.byKey(const Key('parameter-ge.solid.lag_minutes')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('parameter-absorption.openness.ir_peak')),
      findsOneWidget,
    );
    expect(find.textContaining('replay identity only'), findsOneWidget);
    await tester.ensureVisible(
      find.byKey(const Key('parameter-absorption.openness.ir_peak')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('parameter-absorption.openness.ir_peak')),
    );
    await tester.pump();
    expect(find.textContaining('Supported engineering domain'), findsWidgets);
    expect(find.textContaining('not a clinical reference range'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-numerical-oracle')),
      260,
      scrollable: outerScrollable,
    );
    expect(find.text('7 · Independent numerical truth gate'), findsOneWidget);
    expect(find.text('19 / 19 vectors passed'), findsOneWidget);
    expect(
      find.textContaining('not biology, clinical accuracy'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-mechanistic-event-ledger')),
      260,
      scrollable: outerScrollable,
    );
    expect(find.text('8 · Unit-aware immutable event ledger'), findsOneWidget);
    expect(find.text('3 ordered events'), findsOneWidget);
    expect(find.textContaining('Canonical replay SHA-256:'), findsOneWidget);
    final doseEvent = find.byKey(
      const Key('mechanistic-ledger-event-observatory_dose'),
    );
    expect(doseEvent, findsOneWidget);
    await tester.ensureVisible(doseEvent);
    await tester.tap(doseEvent);
    await tester.pump();
    expect(find.textContaining('100.0 mg → 100.0 mg'), findsOneWidget);
    expect(find.textContaining('syntheticFixture'), findsWidgets);
  });

  testWidgets('mobile sensitivity cards expose every field without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pump();

    expect(
      find.byKey(const Key('observatory-sensitivity-comparison-table')),
      findsNothing,
    );
    const fields = ['scenario', 'completeness', 'lag', 'overlap', 'bands'];
    for (final scenario in [
      'mixedReference',
      'highFatProtein',
      'incompleteData',
    ]) {
      expect(
        find.byKey(Key('observatory-comparison-card-$scenario')),
        findsOneWidget,
      );
      for (final field in fields) {
        final fieldFinder = find.byKey(
          Key('observatory-comparison-$scenario-$field'),
        );
        expect(fieldFinder, findsOneWidget);
        final rect = tester.getRect(fieldFinder);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(390));
      }
    }

    final lastField = find.byKey(
      const Key('observatory-comparison-incompleteData-bands'),
    );
    await tester.scrollUntilVisible(
      lastField,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    final visibleRect = tester.getRect(lastField);
    expect(visibleRect.top, greaterThanOrEqualTo(0));
    expect(visibleRect.bottom, lessThanOrEqualTo(844));
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop sensitivity comparison retains five-column table', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pump();

    final tableFinder = find.byKey(
      const Key('observatory-sensitivity-comparison-table'),
    );
    expect(tableFinder, findsOneWidget);
    final table = tester.widget<DataTable>(tableFinder);
    expect(table.columns, hasLength(5));
    expect(table.rows, hasLength(3));
    expect(
      find.byKey(const Key('observatory-comparison-card-mixedReference')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('every registered algorithm renders a card', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 32000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pump();

    for (final descriptor in AlgorithmRegistry.all) {
      expect(
        find.byKey(Key('algorithm-card-${descriptor.id}')),
        findsOneWidget,
        reason: '${descriptor.id} has no rendered UI representation',
      );
      expect(
        find.byKey(Key('algorithm-visual-${descriptor.id}')),
        findsOneWidget,
        reason: '${descriptor.id} has no rendered visualization contract',
      );
      expect(
        find.byKey(Key(descriptor.staticVisual.contractId)),
        findsOneWidget,
        reason: '${descriptor.id} has no algorithm-specific static visual',
      );
      expect(
        find.byKey(Key('algorithm-oracle-status-${descriptor.id}')),
        findsOneWidget,
        reason: '${descriptor.id} has no numerical-oracle status',
      );
      expect(
        find.byKey(Key('algorithm-static-visual-title-${descriptor.id}')),
        findsOneWidget,
        reason: '${descriptor.id} static visual has no unique transform label',
      );
      final traceStatus = find.byKey(
        Key('algorithm-trace-status-${descriptor.id}'),
      );
      expect(traceStatus, findsOneWidget, reason: descriptor.id);
      expect(
        find.descendant(
          of: traceStatus,
          matching: find.text(
            descriptor.hasLiveTrace
                ? 'Production-engine-derived fixed-scenario trace available'
                : 'Static algorithm contract; no production scenario trace',
          ),
        ),
        findsOneWidget,
        reason: descriptor.id,
      );
    }
  });

  testWidgets('live filter exposes only production-engine snapshot traces', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 32000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('algorithm-live-trace-filter')));
    await tester.pump();

    final liveAlgorithms = AlgorithmRegistry.all
        .where((descriptor) => descriptor.hasLiveTrace)
        .toList(growable: false);
    expect(liveAlgorithms, hasLength(6));
    expect(
      find.text(
        'Showing ${liveAlgorithms.length} of ${AlgorithmRegistry.all.length} algorithms',
      ),
      findsOneWidget,
    );
    for (final descriptor in AlgorithmRegistry.all) {
      expect(
        find.byKey(Key('algorithm-card-${descriptor.id}')),
        descriptor.hasLiveTrace ? findsOneWidget : findsNothing,
        reason: descriptor.id,
      );
    }
  });

  testWidgets('static curve cards are labeled as contracts, not live data', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pump();

    final search = find.byKey(const Key('algorithm-atlas-search'));
    await tester.scrollUntilVisible(
      search,
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(search, 'protein_trend');
    await tester.pump();

    final card = find.byKey(const Key('algorithm-card-protein_trend'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('curve contract')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('live curve')),
      findsNothing,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text(
          'Static algorithm contract; no production scenario trace',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('algorithm atlas is searchable and filterable', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(900, 1500);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pump();

    final search = find.byKey(const Key('algorithm-atlas-search'));
    await tester.scrollUntilVisible(
      search,
      360,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(search, 'dosage_note_parser');
    await tester.pump();

    expect(
      find.text('Showing 1 of ${AlgorithmRegistry.all.length} algorithms'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('algorithm-card-dosage_note_parser')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('algorithm-visual-dosage_note_parser')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('algorithm-card-gastric_emptying')),
      findsNothing,
    );

    await tester.tap(find.byKey(const Key('algorithm-atlas-clear')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('algorithm-stage-filter-model')));
    await tester.pump();

    final modeledCount = AlgorithmRegistry.all
        .where((item) => item.stage == AlgorithmStage.model)
        .length;
    expect(
      find.text(
        'Showing $modeledCount of ${AlgorithmRegistry.all.length} algorithms',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('algorithm-card-gastric_emptying')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('algorithm-card-dosage_note_parser')),
      findsNothing,
    );
  });

  testWidgets('uses the active app locale for the observatory shell', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh', 'CN'),
        supportedLocales: [Locale('en', 'US'), Locale('zh', 'CN')],
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AlgorithmObservatoryPage(),
      ),
    );
    await tester.pump();

    expect(find.text('算法观测台'), findsOneWidget);
    expect(find.text('回放敏感度场景'), findsOneWidget);
    expect(find.text('高脂肪 + 高蛋白'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('chart-panel-gastric-emptying')),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('1 · 胃排空模型'), findsOneWidget);
  });

  testWidgets(
    'abstained observatory shows status and dashes without zero charts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 5000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AlgorithmObservatoryPage(
            service: _AbstainingObservatoryService(),
          ),
        ),
      );
      await tester.pump();

      for (final scenario in ObservatoryScenario.values) {
        final overlap = find.byKey(
          Key('observatory-comparison-${scenario.name}-overlap'),
        );
        final bands = find.byKey(
          Key('observatory-comparison-${scenario.name}-bands'),
        );
        expect(
          find.descendant(of: overlap, matching: find.text('—')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: bands, matching: find.text('not applicable')),
          findsOneWidget,
        );
      }

      expect(
        find.byKey(const Key('model-output-unavailable-gastric-emptying')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key('model-output-unavailable-absorption-competition'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('chart-panel-gastric-emptying')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('chart-panel-absorption-competition')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('observatory-conflict-overlap-unavailable')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('observatory-candidate-scores-unavailable')),
        findsOneWidget,
      );
      expect(find.text('severity unknown'), findsNothing);
      expect(find.text('confidence insufficient'), findsNothing);
      expect(find.textContaining('Interaction overlap: 0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'candidate panel preserves not-applicable status without numeric bars',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 5000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: AlgorithmObservatoryPage(
            service: _CandidateAbstainingObservatoryService(),
          ),
        ),
      );
      await tester.pump();
      await tester.scrollUntilVisible(
        find.text('Status: not applicable'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Modeled candidate score: —'), findsOneWidget);
      expect(find.text('Status: not applicable'), findsOneWidget);
      expect(find.text('Status: insufficient data'), findsNothing);
      expect(find.text('Final compatibility'), findsNothing);
      expect(find.textContaining('0 points'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}

class _AbstainingObservatoryService extends AlgorithmObservatoryService {
  @override
  AlgorithmObservatorySnapshot build(ObservatoryScenario scenario) {
    final base = super.build(scenario);
    final result = MechanisticConflictResult.notApplicable(
      id: 'observatory_${scenario.name}_not_applicable',
      reason: MechanisticInteractionType.insufficientMedicationContext,
      reasonCodes: const ['mechanistic_applicability.route_not_supported'],
      sourceRefs: const ['src.dailymed.sinemet.label'],
    );
    return AlgorithmObservatorySnapshot(
      scenario: scenario,
      context: base.context,
      composition: base.composition,
      conflict: result,
      candidateScores: const [],
      gastricParameters: base.gastricParameters,
      configurationIdentity: base.configurationIdentity,
      eventLedger: base.eventLedger,
      explanationTree: AlgorithmTraceNode(
        id: 'mechanistic_conflict',
        label: 'Mechanistic conflict composition',
        inputs: const ['unsupported synthetic route'],
        output: 'status notApplicable; no modeled output',
        sourceRefs: result.sourceRefs,
        limitation: result.limitationText,
      ),
    );
  }
}

class _CandidateAbstainingObservatoryService
    extends AlgorithmObservatoryService {
  @override
  AlgorithmObservatorySnapshot build(ObservatoryScenario scenario) {
    final base = super.build(scenario);
    final template = base.candidateScores.first;
    final candidate = MechanisticCandidateScore.abstention(
      candidateFoodId: template.candidateFoodId,
      candidateName: template.candidateName,
      regionalFoodLibraryRef: template.regionalFoodLibraryRef,
      userDefinedWindow: template.userDefinedWindow,
      availability: MechanisticResultAvailability.notApplicable,
      explanation: const ['Known outside the supported candidate domain.'],
      sourceRefs: template.sourceRefs,
      safetyBoundary: template.safetyBoundary,
      notAdviceText: template.notAdviceText,
      sourceSystem: template.sourceSystem,
      jurisdiction: template.jurisdiction,
      scoringParameterSetId: template.scoringParameterSetId,
    );
    return AlgorithmObservatorySnapshot(
      scenario: scenario,
      context: base.context,
      composition: base.composition,
      conflict: base.conflict,
      candidateScores: [candidate],
      gastricParameters: base.gastricParameters,
      configurationIdentity: base.configurationIdentity,
      eventLedger: base.eventLedger,
      explanationTree: base.explanationTree,
    );
  }
}
