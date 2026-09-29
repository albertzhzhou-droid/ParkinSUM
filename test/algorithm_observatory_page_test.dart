import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/db/app_database_memory.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_descriptor.dart';
import 'package:parkinsum_companion/domain/entities/algorithm_trace_node.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_parameters.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_candidate_score.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';
import 'package:parkinsum_companion/domain/usecases/legacy_food_recommendation_parameters.dart';
import 'package:parkinsum_companion/features/algorithm_observatory/algorithm_observatory_page.dart';

Finder get _observatoryList => find.byKey(const Key('observatory-scroll-list'));

Finder get _observatoryScrollable => find
    .descendant(of: _observatoryList, matching: find.byType(Scrollable))
    .first;

Future<void> _scrollLazyListUntilBuilt(
  WidgetTester tester,
  Finder target,
) async {
  final list = _observatoryList;
  for (var attempt = 0; attempt < 120 && target.evaluate().isEmpty; attempt++) {
    await tester.drag(list, const Offset(0, -700));
    await tester.pump();
  }
  expect(target, findsOneWidget);
  await tester.ensureVisible(target);
  await tester.pump();
}

void main() {
  test('dependency closure copy is complete across shipped languages', () {
    const keys = <String>{
      'observatory.dependency_closure.title',
      'observatory.dependency_closure.loading',
      'observatory.dependency_closure.unavailable',
      'observatory.dependency_closure.loading_semantics',
      'observatory.dependency_closure.unavailable_semantics',
      'observatory.dependency_closure.semantics',
      'observatory.dependency_closure.summary',
      'observatory.dependency_closure.identity',
      'observatory.dependency_closure.registry_chip',
      'observatory.dependency_closure.edge_chip',
      'observatory.dependency_closure.closure_chip',
      'observatory.dependency_closure.details',
      'observatory.dependency_closure.details_subtitle',
      'observatory.dependency_closure.table_semantics',
      'observatory.dependency_closure.column_algorithm',
      'observatory.dependency_closure.column_root',
      'observatory.dependency_closure.column_sink',
      'observatory.dependency_closure.column_uri',
      'observatory.dependency_closure.boundary',
    };
    final english = AppI18n.translationDictionary['en']!;
    Set<String> placeholders(String value) => RegExp(
      r'\{([^{}]+)\}',
    ).allMatches(value).map((match) => match.group(1)!).toSet();

    for (final family in AppI18n.translationFamilies) {
      final translations = AppI18n.translationDictionary[family]!;
      for (final key in keys) {
        expect(
          translations[key],
          isNotNull,
          reason: '$family must not fall through to English for $key',
        );
        expect(
          placeholders(translations[key]!),
          placeholders(english[key]!),
          reason: '$family must preserve placeholders for $key',
        );
      }
    }
  });

  test('replay save copy is complete across shipped languages', () {
    const keys = <String>{
      'observatory.replay_capsule.save_action',
      'observatory.replay_capsule.save_already_saved',
      'observatory.replay_capsule.saved_count',
      'observatory.replay_capsule.save_disclosure',
      'observatory.replay_capsule.save_failure',
      'observatory.replay_capsule.save_saving',
    };
    final english = AppI18n.translationDictionary['en']!;
    Set<String> placeholders(String value) => RegExp(
      r'\{([^{}]+)\}',
    ).allMatches(value).map((match) => match.group(1)!).toSet();

    for (final family in AppI18n.translationFamilies) {
      final translations = AppI18n.translationDictionary[family]!;
      for (final key in keys) {
        expect(translations[key], isNotNull, reason: '$family is missing $key');
        expect(
          placeholders(translations[key]!),
          placeholders(english[key]!),
          reason: '$family has placeholder drift for $key',
        );
      }
    }
  });

  testWidgets('saving a replay capsule requires an explicit user action', (
    tester,
  ) async {
    final database = InMemoryAppDatabase();
    final capsule = AlgorithmObservatoryService()
        .build(ObservatoryScenario.mixedReference)
        .replayCapsule;
    var savedCount = 0;
    var alreadySaved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: MechanisticReplayCapsuleSaveControl(
              onSave: () async {
                await database.saveMechanisticReplayCapsule(capsule);
                final stored = await database.loadMechanisticReplayCapsules();
                setState(() {
                  savedCount = stored.length;
                  alreadySaved = stored.any(
                    (entry) => entry.capsuleSha256 == capsule.capsuleSha256,
                  );
                });
              },
              saving: false,
              savedCount: savedCount,
              alreadySaved: alreadySaved,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saveButton = find.byKey(
      const Key('observatory-save-synthetic-replay-capsule'),
    );
    expect(await database.loadMechanisticReplayCapsules(), isEmpty);
    expect(find.text('Saved synthetic replays: 0'), findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    final stored = await database.loadMechanisticReplayCapsules();
    expect(stored, hasLength(1));
    expect(stored.single.canonicalJson, contains('synthetic:observatory'));
    expect(find.text('Saved synthetic replays: 1'), findsOneWidget);
    expect(find.text('This synthetic replay is saved'), findsOneWidget);
  });

  testWidgets('shows stable result roots while dependency closure stays held', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('observatory-dependency-closure-readiness')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-dependency-closure-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('65 / 65 stable roots'), findsOneWidget);
    expect(
      find.textContaining('declared Analyzer target 14.1.0'),
      findsOneWidget,
    );
    expect(find.textContaining('transitive closure HOLD'), findsOneWidget);
    expect(find.text('registry mapping: structurally valid'), findsOneWidget);
    expect(
      find.textContaining('held_pending_full_result_dependency_closure'),
      findsOneWidget,
    );

    final details = find.byKey(
      const Key('observatory-dependency-root-details'),
    );
    await tester.ensureVisible(details);
    await tester.pump();
    await tester.tap(details);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('observatory-dependency-root-table')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dependency-root-gastric_emptying')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('dependency-root-algorithm_visual_projection')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-dependency-closure-boundary')),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Offline Analyzer compatibility evidence is not bundled or executed',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('exact-lock reviewed'), findsNothing);
    final semantics = tester.widget<Semantics>(
      find.byKey(const Key('observatory-dependency-root-table-semantics')),
    );
    expect(
      semantics.properties.label,
      contains('Stable algorithm roots table'),
    );
  });

  testWidgets(
    'shows the read-only synthetic gastric structure-sensitivity diagnostic',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 8000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: AlgorithmObservatoryPage()),
      );
      await tester.pumpAndSettle();

      final node = find.byKey(
        const Key('trace-node-gastric_structural_uncertainty_shadow_ensemble'),
      );
      await _scrollLazyListUntilBuilt(tester, node);
      expect(
        find.text('Synthetic gastric structure-sensitivity diagnostic'),
        findsOneWidget,
      );
      expect(
        find.textContaining('observable-matched structures'),
        findsOneWidget,
      );

      await tester.tap(node);
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Boundary: Read-only model-form sensitivity'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('shows the production protein distribution trace', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 8000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pumpAndSettle();

    final node = find.byKey(const Key('trace-node-protein_distribution'));
    await _scrollLazyListUntilBuilt(tester, node);
    expect(
      find.text('Inspect protein redistribution model outputs'),
      findsOneWidget,
    );
    expect(find.textContaining('mean redistribution'), findsOneWidget);

    await tester.tap(node);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Boundary: This read-only projection'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

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
    final outerScrollable = _observatoryScrollable;

    expect(find.text('Algorithm Observatory'), findsOneWidget);
    expect(
      find.byKey(const Key('observatory-trace-surface-manifest')),
      findsOneWidget,
    );
    expect(find.textContaining('14 / 65'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('observatory-trace-surface-details')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(find.text('observatory.production-snapshot/1'), findsOneWidget);
    expect(
      find.textContaining('algorithm-observatory-snapshot/1'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-trace-surface-boundary')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const Key('observatory-trace-surface-details')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('observatory-trace-surface-details')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-sensitivity-comparison-table')),
      240,
      scrollable: outerScrollable,
    );
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
    await tester.drag(_observatoryList, const Offset(0, -360));
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
    expect(
      find.byKey(const Key('trace-node-time_axis_builder')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('trace-node-input_quality_gate')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('trace-node-medication_entry_validator')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('trace-node-gastric_structural_uncertainty_shadow_ensemble'),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('trace-node-protein_distribution')),
      findsOneWidget,
    );
    expect(find.textContaining('min after meal start'), findsOneWidget);
    expect(find.textContaining('min after dose'), findsOneWidget);
    expect(find.textContaining('$rawMostlyEmptiedStart'), findsNothing);
    expect(find.textContaining('$rawAbsorptionPeak'), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-configuration-coverage')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.byKey(const Key('observatory-configuration-coverage-summary')),
      findsOneWidget,
    );
    final coverageSummary = tester.widget<Text>(
      find.byKey(const Key('observatory-configuration-coverage-summary')),
    );
    expect(coverageSummary.data, contains('65 registered'));
    expect(coverageSummary.data, contains('17 field + source bound'));
    expect(coverageSummary.data, contains('48 source-bundle only'));
    expect(
      coverageSummary.data,
      contains('2 reviewed declared-scope witnesses'),
    );
    expect(coverageSummary.data, contains('not scientific validation'));
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-configuration-coverage-details')),
      120,
      scrollable: outerScrollable,
    );
    await tester.drag(outerScrollable, const Offset(0, 160));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('observatory-configuration-coverage-details')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(
      find.byKey(const Key('configuration-coverage-gastric_emptying')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('configuration-coverage-dosage_note_parser')),
      findsOneWidget,
    );
    final identity = AlgorithmConfigurationIdentity.defaults();
    for (final algorithmId in const [
      'gastric_emptying',
      'levodopa_absorption_opportunity',
    ]) {
      final coverageEntry = find.byKey(
        Key('configuration-coverage-$algorithmId'),
      );
      expect(coverageEntry, findsOneWidget);
      final witness = identity.configurationCoverageManifest
          .entryFor(algorithmId)
          .completenessWitness!;
      for (final evidence in [
        'REVIEWED WITNESS FOR DECLARED CONFIGURATION SCOPE',
        witness.witnessId,
        witness.sha256Digest,
        witness.reviewedAt,
        witness.completionBoundary,
        witness.limitation,
        ...witness.reviewEvidenceIds,
        witness.configurationSectionSha256,
        witness.registeredSourceBundleSha256,
        ...witness.ownedSourceSha256.values,
        ...witness.dependencyContractSha256.values,
        ...witness.fieldRecordIds,
        ...witness.requiredResultSinks,
        for (final entry in witness.affectedResultSinksByFieldId.entries)
          '${entry.key}=[${entry.value.join(',')}]',
      ]) {
        expect(
          find.descendant(
            of: coverageEntry,
            matching: find.textContaining(evidence),
          ),
          findsOneWidget,
          reason:
              '$algorithmId witness evidence must remain inspectable: $evidence',
        );
      }
    }
    expect(find.textContaining('fieldAndSourceBound'), findsWidgets);
    expect(find.textContaining('sourceBundleOnly'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-configuration-change-impact')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.byKey(const Key('configuration-change-impact-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('10 semantic changes'), findsOneWidget);
    expect(find.textContaining('15 replay outputs'), findsWidgets);
    expect(
      find.byKey(const Key('configuration-impact-pin-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('configuration-impact-promotion-status')),
      findsOneWidget,
    );
    expect(find.text('PROMOTION BLOCKED'), findsWidgets);
    expect(
      find.byKey(const Key('configuration-obligation-scientificValidation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('configuration-impact-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-configuration-baseline-registry')),
      260,
      scrollable: outerScrollable,
    );
    await tester.pump();
    expect(
      find.byKey(const Key('configuration-baseline-summary')),
      findsOneWidget,
    );
    expect(find.textContaining('candidate held'), findsOneWidget);
    expect(
      find.byKey(const Key('configuration-baseline-chain-status')),
      findsOneWidget,
    );
    expect(find.text('ACTIVATION BLOCKED'), findsOneWidget);
    expect(
      find.byKey(const Key('configuration-baseline-decision')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('configuration-baseline-boundary')),
      findsOneWidget,
    );
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
    expect(
      find.textContaining('121 result-affecting parameter/structure records'),
      findsOneWidget,
    );
    final legacyRecords = AlgorithmConfigurationIdentity.defaults()
        .parameterProvenanceManifest
        .records
        .where(
          (record) =>
              record.algorithmIds.contains('legacy_food_recommendations'),
        )
        .toList(growable: false);
    expect(legacyRecords, hasLength(35));
    expect(legacyRecords.map((record) => record.parameterId).toSet(), {
      ...LegacyFoodRecommendationParameterSet.prototypeDefault()
          .allParameterIds,
      LegacyFoodRecommendationProvenancePolicy.parameterId,
    });
    for (final record in legacyRecords) {
      expect(
        find.byKey(Key('parameter-${record.parameterId}')),
        findsOneWidget,
        reason: record.parameterId,
      );
    }
    for (final parameterId in const [
      LegacyFoodRecommendationParameterIds.safetyWeight,
      LegacyFoodRecommendationParameterIds.minimumScore,
      LegacyFoodRecommendationParameterIds.safetyCautionProteinG,
      LegacyFoodRecommendationParameterIds.maximumCandidates,
      LegacyFoodRecommendationParameterIds.tieBreakPolicy,
    ]) {
      final row = find.byKey(Key('parameter-$parameterId'));
      expect(
        find.descendant(
          of: row,
          matching: find.textContaining('prototype-heuristic'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.textContaining('not clinical')),
        findsOneWidget,
      );
    }
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
    await tester.ensureVisible(
      find.byKey(const Key('parameter-absorption.structure.generator_policy')),
    );
    await tester.pump();
    await tester.tap(
      find.byKey(const Key('parameter-absorption.structure.generator_policy')),
    );
    await tester.pump();
    final generatorStructure = find.byKey(
      const Key('parameter-structure-absorption.structure.generator_policy'),
    );
    expect(generatorStructure, findsOneWidget);
    expect(
      tester.widget<Text>(generatorStructure).data,
      contains('high_strict_gt_then_moderate'),
    );
    for (final record in const <(String, String)>[
      (
        GastricEmptyingParameterIds.generatorStructure,
        'missing_without_positive_reference',
      ),
      (
        GastricEmptyingParameterIds.outputIntegrityContract,
        'aggregate_coherence',
      ),
    ]) {
      final row = find.byKey(Key('parameter-${record.$1}'));
      await tester.ensureVisible(row);
      await tester.pump();
      await tester.tap(row);
      await tester.pump();
      final structure = find.byKey(Key('parameter-structure-${record.$1}'));
      expect(structure, findsOneWidget);
      expect(tester.widget<Text>(structure).data, contains(record.$2));
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-applicability-manifest')),
      260,
      scrollable: outerScrollable,
    );
    expect(find.text('Model applicability manifest'), findsOneWidget);
    expect(find.textContaining('TRACE ONLY'), findsOneWidget);
    expect(find.text('Fail-closed predicate matrix'), findsOneWidget);
    for (final providerId in const [
      'meal_composition_normalizer',
      'gastric_emptying',
      'levodopa_absorption_opportunity',
      'amino_acid_competition',
      'mechanistic_conflict',
      'mechanistic_candidate_scorer',
    ]) {
      expect(
        find.byKey(Key('applicability-provider-$providerId')),
        findsOneWidget,
      );
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-evidence-currency')),
      260,
      scrollable: outerScrollable,
    );
    expect(find.text('Evidence currency and sunset gate'), findsOneWidget);
    expect(find.textContaining('STATUS REVIEW CURRENT · 5'), findsOneWidget);
    expect(
      find.byKey(const Key('observatory-evidence-currency-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('evidence-currency-claim.meal_delay_direction.nutt_1984'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('does not establish validity'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-evidence-synthesis')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text('Claim evidence contradiction and synthesis'),
      findsOneWidget,
    );
    expect(find.textContaining('INDEPENDENT REVIEW HOLD · 5'), findsOneWidget);
    expect(
      find.byKey(const Key('observatory-evidence-synthesis-status')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key('evidence-synthesis-claim.meal_delay_direction.nutt_1984'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Citation count never creates'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-cou-requalification-ledger')),
      260,
      scrollable: outerScrollable,
    );
    expect(find.text('Context-of-use requalification ledger'), findsOneWidget);
    expect(find.textContaining('PROMOTION BLOCKED'), findsOneWidget);
    expect(
      find.byKey(const Key('observatory-cou-integrity-status')),
      findsOneWidget,
    );
    expect(find.textContaining('LEDGER DRIFT · 4 findings'), findsOneWidget);
    expect(
      find.textContaining('ledger.current_configuration_identity_mismatch'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'ledger.evidence_synthesis_registry_identity_mismatch',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('ledger.latest_configuration_mismatch'),
      findsOneWidget,
    );
    expect(
      find.textContaining('ledger.latest_evidence_synthesis_registry_mismatch'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('cou-evidence-implementationVerification')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('cou-evidence-scientificValidation')),
      findsOneWidget,
    );
    expect(
      find.textContaining('scientificValidation: missing'),
      findsOneWidget,
    );
    expect(find.textContaining('modelQualification: missing'), findsOneWidget);
    expect(
      find.byKey(const Key('observatory-cou-incomplete-evidence')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-prospective-credibility-plan')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        'Prospective model credibility plan and post-study adequacy gate',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('STUDY + PROMOTION BLOCKED'), findsOneWidget);
    expect(find.textContaining('PLAN INTEGRITY VERIFIED'), findsOneWidget);
    expect(
      find.byKey(const Key('credibility-factor-softwareQualityAssurance')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('credibility-factor-scientificValidation')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('credibility-factor-humanFactors')),
      findsOneWidget,
    );
    expect(
      find.textContaining('post-study adequacy: notAssessed'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-evidence-execution-attestation')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text('Credibility-evidence execution attestation and leakage gate'),
      findsOneWidget,
    );
    expect(find.textContaining('mechanicallyObserved'), findsWidgets);
    expect(
      find.textContaining('scientific credibility use blocked'),
      findsOneWidget,
    );
    for (final split in const [
      'fit',
      'tune',
      'calibration',
      'comparator',
      'lockedTest',
    ]) {
      expect(find.byKey(Key('evidence-split-$split')), findsOneWidget);
    }
    for (final dimension in const [
      'subject',
      'relatedSubject',
      'site',
      'acquisition',
      'device',
      'sourceRow',
      'time',
      'preprocessing',
      'accessOrder',
      'outcomeCompleteness',
    ]) {
      expect(
        find.byKey(Key('evidence-independence-$dimension')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const Key('observatory-evidence-access-order')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-protocol-transparency-ledger')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        'Protocol amendment, deviation, and result-transparency ledger',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('mechanicallyObserved'), findsWidgets);
    expect(
      find.textContaining('GCP conformance claim blocked'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-protocol-transparency-status')),
      findsOneWidget,
    );
    for (final event in const [
      '1-initialProtocol',
      '2-amendment',
      '3-datasetLockTransition',
      '4-resultUpdate',
      '5-correction',
    ]) {
      expect(find.byKey(Key('protocol-timeline-$event')), findsOneWidget);
    }
    for (final status in const [
      'planned',
      'reported',
      'postHoc',
      'withdrawn',
      'notCollected',
      'unavailable',
      'omitted',
    ]) {
      expect(
        find.byKey(Key('protocol-outcome-status-$status')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const Key('observatory-protocol-transparency-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-blinded-replication')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        'Blinded independent replication capsule and discrepancy adjudication',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-blinded-replication-status')),
      findsOneWidget,
    );
    expect(find.textContaining('mechanicallyObserved'), findsWidgets);
    for (final lane in const [
      'capsule',
      'blinding',
      'independentResponse',
      'environmentMatch',
      'comparison',
      'adjudication',
    ]) {
      expect(find.byKey(Key('replication-lane-$lane')), findsOneWidget);
    }
    for (final status in const [
      'reported',
      'nullResult',
      'failed',
      'adverse',
      'missing',
    ]) {
      expect(find.byKey(Key('replication-outcome-$status')), findsOneWidget);
    }
    expect(
      find.byKey(const Key('observatory-replication-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-statistical-governance')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        'Statistical analysis, error control, and uncertainty governance',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-statistical-governance-status')),
      findsOneWidget,
    );
    for (final lane in const [
      'design',
      'estimand',
      'estimate',
      'uncertainty',
      'errorControl',
      'sensitivity',
      'deviations',
    ]) {
      expect(find.byKey(Key('statistical-lane-$lane')), findsOneWidget);
    }
    for (final status in const [
      'reported',
      'nullResult',
      'inconclusive',
      'failed',
      'contradictory',
      'adverse',
      'missing',
    ]) {
      expect(find.byKey(Key('statistical-outcome-$status')), findsOneWidget);
    }
    expect(
      find.byKey(const Key('observatory-statistical-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-randomization-interim')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        'Randomization, allocation concealment, and interim-access firewall',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-randomization-interim-status')),
      findsOneWidget,
    );
    for (final lane in const [
      'randomizationIdentity',
      'concealment',
      'roleSeparation',
      'accessHistory',
      'interimBoundaries',
      'committeeRecommendation',
      'adjudication',
    ]) {
      expect(find.byKey(Key('randomization-lane-$lane')), findsOneWidget);
    }
    expect(
      find.byKey(const Key('observatory-randomization-concealment-boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-randomization-interim-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-adaptive-simulation')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        'Adaptive-design operating characteristics and decision-rule calibration',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-adaptive-simulation-status')),
      findsOneWidget,
    );
    expect(
      find.textContaining('700000 deterministic simulations'),
      findsOneWidget,
    );
    for (final lane in const [
      'designIdentity',
      'scenarioCoverage',
      'monteCarloPrecision',
      'errorControl',
      'powerAndBias',
      'sampleSizeAndSelection',
      'oracleAndAdjudication',
    ]) {
      expect(find.byKey(Key('adaptive-lane-$lane')), findsOneWidget);
    }
    expect(
      find.byKey(const Key('observatory-adaptive-simulation-precision')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-adaptive-simulation-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-bayesian-borrowing')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        'Bayesian prior, external borrowing conflict, and posterior-decision calibration',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-bayesian-borrowing-status')),
      findsOneWidget,
    );
    expect(
      find.textContaining('400000 deterministic simulations'),
      findsOneWidget,
    );
    for (final lane in const [
      'priorProvenance',
      'externalDataSuitability',
      'borrowing',
      'priorDataConflict',
      'computation',
      'posteriorDecision',
      'frequentistCalibration',
      'oracleAndAdjudication',
    ]) {
      expect(find.byKey(Key('bayesian-lane-$lane')), findsOneWidget);
    }
    expect(
      find.byKey(const Key('observatory-bayesian-borrowing-conflict')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-bayesian-borrowing-calibration')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-bayesian-draft-boundary')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-bayesian-borrowing-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-bayesian-multisource')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        'Bayesian multi-source transportability, exchangeability, and model criticism',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-bayesian-multisource-status')),
      findsOneWidget,
    );
    expect(find.textContaining('120000 simulations'), findsOneWidget);
    for (final lane in const [
      'sourceDiscovery',
      'dependency',
      'transportability',
      'exchangeability',
      'biasAdjustment',
      'priorPredictiveCriticism',
      'posteriorPredictiveCriticism',
      'sensitivityAndNegativeControls',
      'computation',
      'independentReplication',
    ]) {
      expect(find.byKey(Key('multisource-lane-$lane')), findsOneWidget);
    }
    expect(
      find.byKey(const Key('observatory-bayesian-multisource-ledger')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-bayesian-multisource-criticism')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-bayesian-multisource-operating')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-bayesian-multisource-independent')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-bayesian-multisource-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-target-transportability')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        'Target-population causal transportability, positivity, and doubly robust estimation',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-target-transportability-status')),
      findsOneWidget,
    );
    expect(find.textContaining('70000 repetitions'), findsOneWidget);
    for (final lane in const [
      'identification',
      'overlap',
      'weighting',
      'outcomeModeling',
      'estimatorAgreement',
      'sensitivity',
      'operatingCharacteristics',
      'independentReplication',
      'unresolvedLimitations',
    ]) {
      expect(find.byKey(Key('transport-lane-$lane')), findsOneWidget);
    }
    for (final key in const [
      'observatory-target-transportability-identification',
      'observatory-target-transportability-overlap',
      'observatory-target-transportability-estimators',
      'observatory-target-transportability-sensitivity',
      'observatory-target-transportability-operating',
      'observatory-target-transportability-independent',
      'observatory-target-transportability-boundary',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-transport-sensitivity')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        'Target-transportability bias functions, global sensitivity, and partial identification',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-transport-sensitivity-status')),
      findsOneWidget,
    );
    expect(find.textContaining('80000 repetitions'), findsOneWidget);
    for (final lane in const [
      'assumptions',
      'elicitation',
      'parameterSpace',
      'localSensitivity',
      'globalSensitivity',
      'partialIdentification',
      'tippingRegion',
      'operatingCharacteristics',
      'independentReplication',
      'unresolvedLimitations',
    ]) {
      expect(find.byKey(Key('sensitivity-lane-$lane')), findsOneWidget);
    }
    for (final key in const [
      'observatory-transport-sensitivity-assumptions',
      'observatory-transport-sensitivity-elicitation',
      'observatory-transport-sensitivity-parameter-space',
      'observatory-transport-sensitivity-local',
      'observatory-transport-sensitivity-global',
      'observatory-transport-sensitivity-bounds',
      'observatory-transport-sensitivity-tipping',
      'observatory-transport-sensitivity-operating',
      'observatory-transport-sensitivity-independent',
      'observatory-transport-sensitivity-boundary',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-dose-expression-grammar')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text('Input contract · Versioned dose-expression grammar'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-dose-expression-identity')),
      findsOneWidget,
    );
    for (var index = 0; index < 4; index++) {
      expect(
        find.byKey(Key('observatory-dose-expression-example-$index')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const Key('observatory-dose-expression-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-dose-confirmation-reconciliation')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.byKey(const Key('observatory-dose-confirmation-identity')),
      findsOneWidget,
    );
    for (var index = 0; index < 4; index++) {
      expect(
        find.byKey(Key('observatory-dose-confirmation-case-$index')),
        findsOneWidget,
      );
    }
    expect(
      find.byKey(const Key('observatory-dose-confirmation-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-invariant-gate')),
      260,
      scrollable: outerScrollable,
    );
    expect(find.text('7 · Mathematical invariant + unit gate'), findsOneWidget);
    expect(find.text('23 / 23 checks passed'), findsOneWidget);
    expect(
      find.text('22 / 65 algorithms under executable gate'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'observatory-invariant-check-gastric.normalized_mass_and_monotonicity',
        ),
      ),
      findsOneWidget,
    );
    for (final key in <String>[
      'observatory-invariant-check-medication.normalization_and_applicability_identity',
      'observatory-invariant-check-protein.redistribution_structure_and_bounds',
      'observatory-invariant-check-configuration.cross_scenario_identity',
      'observatory-invariant-check-gastric.structural_observable_domain_invariants',
      'observatory-invariant-check-gastric.structural_fit_authority_and_production_isolation',
      'observatory-invariant-check-dose.typed_expression_and_intake_separation',
      'observatory-invariant-check-dose.package_strength_multiplication_and_bounds',
      'observatory-invariant-check-dose.metadata_completeness_numeric_domain',
      'observatory-invariant-check-dose.input_quality_fail_closed_separation',
      'observatory-invariant-check-dose.confirmation_assertion_and_as_of_result_gate',
      'observatory-invariant-check-recommendation.legacy_score_bounds_thresholds_and_order',
      'observatory-invariant-check-nutrition.amino_acid_extraction_units_missingness_and_determinism',
      'observatory-invariant-check-nutrition.catalog_candidate_basis_missingness_and_portion_scaling',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-executable-contract-gate')),
      260,
      scrollable: outerScrollable,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('8 · Executable contracts for non-numerical algorithms'),
      findsOneWidget,
    );
    expect(find.text('8 / 8 contracts passed'), findsOneWidget);
    expect(find.text('Combined coverage 30 / 65 algorithms'), findsOneWidget);
    expect(find.text('35 algorithms remain uncovered'), findsOneWidget);
    for (final id in <String>[
      'runtime_rule_support.path_permutation',
      'catalog_resolution.input_permutation',
      'source_authority.jurisdiction_order',
      'runtime_rule_engine.jurisdiction_and_units',
      'rule_registry_compiler.schema_rejection',
      'fact_conflict.order_and_scope',
      'recommendation_orchestrator.deterministic_fallback',
      'local_ai_adapter.consent_endpoint_whitelist',
    ]) {
      expect(
        find.byKey(Key('observatory-executable-check-$id')),
        findsOneWidget,
      );
    }
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-independent-contract-oracle')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text('9 · Independent cross-runtime relation gate'),
      findsOneWidget,
    );
    expect(find.text('8 / 8 relations passed'), findsOneWidget);
    expect(find.text('16 / 16 mutations detected'), findsOneWidget);
    expect(find.text('0 surviving mutations'), findsOneWidget);
    expect(find.text('6 / 6 async orderings passed'), findsOneWidget);
    expect(
      find.byKey(const Key('observatory-independent-contract-identities')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-independent-contract-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-relation-domain-sampling')),
      260,
      scrollable: outerScrollable,
    );
    expect(
      find.text(
        '10 · Relation-domain sampling and defective-relation diagnostics',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('schema-v2 locked fixture gate runs paired'),
      findsOneWidget,
    );
    expect(find.text('160 cases · 8 relations'), findsOneWidget);
    expect(find.text('64 precondition HOLDs'), findsOneWidget);
    expect(
      find.text('96 / 96 production samples passed independent evaluation'),
      findsOneWidget,
    );
    expect(find.text('624 production API invocations'), findsOneWidget);
    expect(
      find.text('64 production samples held before execution'),
      findsOneWidget,
    );
    expect(find.text('32 / 32 sampled mutations detected'), findsOneWidget);
    expect(find.text('0 sampled mutation survivors'), findsOneWidget);
    expect(
      find.byKey(const Key('observatory-relation-domain-false-alarms')),
      findsOneWidget,
    );
    expect(
      find.textContaining('diagnostic exposures: 96 / 128 (75.0%)'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'those relations can be rejected, not a production false-positive estimate',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-relation-domain-production-boundary')),
      findsOneWidget,
    );
    expect(
      find.textContaining('Per-case production API executions: 96'),
      findsOneWidget,
    );
    expect(
      find.textContaining('independent relation evaluations: 96'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-relation-domain-boundary')),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-numerical-oracle')),
      260,
      scrollable: outerScrollable,
    );
    expect(find.text('11 · Independent numerical truth gate'), findsOneWidget);
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
    expect(find.text('12 · Unit-aware immutable event ledger'), findsOneWidget);
    expect(find.text('3 ordered events'), findsOneWidget);
    expect(find.textContaining('Canonical replay SHA-256:'), findsOneWidget);
    expect(
      find.byKey(const Key('observatory-mechanistic-ledger-authorization')),
      findsOneWidget,
    );
    expect(
      find.textContaining('PRODUCTION INPUT LEDGER AUTHORIZED'),
      findsOneWidget,
    );
    expect(find.textContaining('Complete input binding:'), findsOneWidget);
    final doseEvent = find.byKey(
      const Key('mechanistic-ledger-event-observatory_dose'),
    );
    expect(doseEvent, findsOneWidget);
    await tester.scrollUntilVisible(
      doseEvent,
      180,
      scrollable: outerScrollable,
    );
    await tester.pumpAndSettle();
    await tester.tap(doseEvent);
    await tester.pumpAndSettle();
    expect(find.textContaining('100.0 mg → 100.0 mg'), findsOneWidget);
    expect(find.textContaining('syntheticFixture'), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-mechanistic-lossless-replay-capsule')),
      220,
      scrollable: outerScrollable,
    );
    expect(
      find.text('13 · Lossless mechanistic input replay capsule'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('observatory-lossless-replay-verified')),
      findsOneWidget,
    );
    expect(
      find.textContaining('LOSSLESS PRODUCTION INPUT REPLAY VERIFIED'),
      findsOneWidget,
    );
    expect(find.textContaining('Capsule SHA-256:'), findsOneWidget);
    expect(
      find.textContaining('capsule has no global timezone identity'),
      findsOneWidget,
    );
    expect(find.textContaining('explicit resolution receipt'), findsOneWidget);
  });

  testWidgets(
    'legacy parameter evidence remains reachable at 320px and 200% text',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: const AlgorithmObservatoryPage(),
        ),
      );
      await tester.pump();

      final panel = find.byKey(const Key('observatory-parameter-evidence'));
      await _scrollLazyListUntilBuilt(tester, panel);
      final safetyRow = find.byKey(
        const Key('parameter-legacy_food.score.weight.safety'),
      );
      await tester.scrollUntilVisible(
        safetyRow,
        320,
        scrollable: _observatoryScrollable,
      );
      await tester.pump();
      final safetyRect = tester.getRect(safetyRow);
      expect(safetyRect.left, greaterThanOrEqualTo(0));
      expect(safetyRect.right, lessThanOrEqualTo(320));
      expect(
        find.bySemanticsLabel(
          RegExp(r'Safety-feature weight.*prototype-heuristic.*Not clinical'),
        ),
        findsOneWidget,
      );

      final tieRow = find.byKey(
        const Key('parameter-legacy_food.structure.tie_break_policy'),
      );
      await tester.scrollUntilVisible(
        tieRow,
        320,
        scrollable: _observatoryScrollable,
      );
      await tester.pump();
      final tieRect = tester.getRect(tieRow);
      expect(tieRect.left, greaterThanOrEqualTo(0));
      expect(tieRect.right, lessThanOrEqualTo(320));
      expect(tester.takeException(), isNull);
      semantics.dispose();
    },
  );

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
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('observatory-sensitivity-comparison-table')),
      findsNothing,
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('observatory-comparison-card-mixedReference')),
      240,
      scrollable: _observatoryScrollable,
    );
    await tester.pump();
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
      scrollable: _observatoryScrollable,
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
    // Keep the full atlas mounted after adding the production dose grammar and
    // confirmation panels; the assertion verifies every registry card.
    tester.view.physicalSize = const Size(1200, 80000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pump();

    for (final surfaceKey
        in AlgorithmObservatoryService
            .traceProviderContract
            .uiSurfaceKeysByAlgorithm
            .values
            .toSet()) {
      expect(
        find.byKey(Key(surfaceKey)),
        findsOneWidget,
        reason: '$surfaceKey is not mounted for its production trace provider',
      );
    }

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
        find.byKey(Key('algorithm-invariant-status-${descriptor.id}')),
        findsOneWidget,
        reason: '${descriptor.id} has no mathematical-invariant status',
      );
      expect(
        find.byKey(Key('algorithm-executable-status-${descriptor.id}')),
        findsOneWidget,
        reason: '${descriptor.id} has no non-numerical executable status',
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

  testWidgets(
    'legacy food recommendations show passed invariant without claiming a production trace',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 80000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: AlgorithmObservatoryPage()),
      );
      await tester.pump();

      final invariantStatus = find.byKey(
        const Key('algorithm-invariant-status-legacy_food_recommendations'),
      );
      expect(invariantStatus, findsOneWidget);
      expect(
        find.descendant(
          of: invariantStatus,
          matching: find.text('Mathematical invariant and unit checks passed'),
        ),
        findsOneWidget,
      );

      final traceStatus = find.byKey(
        const Key('algorithm-trace-status-legacy_food_recommendations'),
      );
      expect(traceStatus, findsOneWidget);
      expect(
        find.descendant(
          of: traceStatus,
          matching: find.text(
            'Static algorithm contract; no production scenario trace',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'amino-acid extraction shows production-backed invariant coverage',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 80000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: AlgorithmObservatoryPage()),
      );
      await tester.pump();

      final invariantStatus = find.byKey(
        const Key('algorithm-invariant-status-amino_acid_extraction'),
      );
      expect(invariantStatus, findsOneWidget);
      expect(
        find.descendant(
          of: invariantStatus,
          matching: find.text('Mathematical invariant and unit checks passed'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'observatory-invariant-check-nutrition.amino_acid_extraction_units_missingness_and_determinism',
          ),
        ),
        findsOneWidget,
      );

      final traceStatus = find.byKey(
        const Key('algorithm-trace-status-amino_acid_extraction'),
      );
      expect(traceStatus, findsOneWidget);
      expect(
        find.descendant(
          of: traceStatus,
          matching: find.text(
            'Static algorithm contract; no production scenario trace',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'catalog candidate projection filter exposes invariant, static trace, and bounded specification',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 80000);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: AlgorithmObservatoryPage()),
      );
      await tester.pump();

      final search = find.byKey(const Key('algorithm-atlas-search'));
      await _scrollLazyListUntilBuilt(tester, search);
      await tester.enterText(search, 'catalog_candidate_projection');
      await tester.pump();

      expect(
        find.text('Showing 1 of ${AlgorithmRegistry.all.length} algorithms'),
        findsOneWidget,
      );
      final card = find.byKey(
        const Key('algorithm-card-catalog_candidate_projection'),
      );
      expect(card, findsOneWidget);
      expect(
        find.byKey(const Key('algorithm-card-amino_acid_extraction')),
        findsNothing,
      );

      final invariantStatus = find.byKey(
        const Key('algorithm-invariant-status-catalog_candidate_projection'),
      );
      expect(invariantStatus, findsOneWidget);
      expect(
        find.descendant(
          of: invariantStatus,
          matching: find.text('Mathematical invariant and unit checks passed'),
        ),
        findsOneWidget,
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
      expect(
        find.descendant(
          of: card,
          matching: find.text(
            'Boundary: Projection preserves source data and does not infer missing nutrients.',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const Key(
            'observatory-invariant-check-nutrition.catalog_candidate_basis_missingness_and_portion_scaling',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('observatory-invariant-gate')),
          matching: find.text(
            'Passing shows mathematical consistency only for declared synthetic observables under fixed engineering checks—not biological validity, clinical accuracy, patient benefit, or medical advice.',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('live filter exposes only production-engine snapshot traces', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 60000);
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
    expect(liveAlgorithms, hasLength(14));
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

  testWidgets(
    'protein trend card distinguishes its contract thumbnail from its trace',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(900, 1500);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(home: AlgorithmObservatoryPage()),
      );
      await tester.pump();

      final search = find.byKey(const Key('algorithm-atlas-search'));
      await _scrollLazyListUntilBuilt(tester, search);
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
            'Production-engine-derived fixed-scenario trace available',
          ),
        ),
        findsOneWidget,
      );
    },
  );

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
    await _scrollLazyListUntilBuilt(tester, search);
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
      scrollable: _observatoryScrollable,
    );
    expect(find.text('1 · 胃排空模型'), findsOneWidget);
  });

  testWidgets(
    'every complex chart has short semantics, visible detail, and a data table',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      for (final id in AlgorithmObservatoryPage.complexChartIds) {
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('complex-chart-contract-$id'),
            home: const AlgorithmObservatoryPage(),
          ),
        );
        await tester.pump();
        final panel = find.byKey(Key('chart-panel-$id'));
        await _scrollLazyListUntilBuilt(tester, panel);

        final image = tester.widget<Semantics>(
          find.byKey(Key('chart-image-$id')),
        );
        expect(image.properties.image, isTrue);
        expect(image.properties.label, isNotEmpty);
        expect(find.byKey(Key('chart-long-description-$id')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(Key('chart-long-description-$id')),
            matching: find.text('Detailed chart description'),
          ),
          findsOneWidget,
        );

        final tableTile = find.byKey(Key('chart-data-table-$id'));
        expect(tableTile, findsOneWidget);
        for (
          var attempt = 0;
          attempt < 20 && tableTile.hitTestable().evaluate().isEmpty;
          attempt++
        ) {
          await tester.drag(_observatoryList, const Offset(0, -240));
          await tester.pump();
        }
        expect(
          tableTile.hitTestable(),
          findsOneWidget,
          reason: '$id data-table control was not reachable by scrolling',
        );
        await tester.tap(tableTile.hitTestable());
        await tester.pumpAndSettle();
        expect(
          find.descendant(of: tableTile, matching: find.byType(DataTable)),
          findsOneWidget,
        );
      }

      expect(
        find.byType(CustomPaint),
        findsWidgets,
        reason: 'the narrow 320-pixel-equivalent view lost chart content',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'abstained observatory shows status and dashes without zero charts',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      // Keep every abstention surface mounted after the trace-manifest panel.
      tester.view.physicalSize = const Size(390, 6500);
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
      await _scrollLazyListUntilBuilt(
        tester,
        find.byKey(const Key('observatory-candidate-scores-unavailable')),
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
        scrollable: _observatoryScrollable,
      );

      expect(find.text('Modeled candidate score: —'), findsOneWidget);
      expect(find.text('Status: not applicable'), findsOneWidget);
      expect(find.text('Status: insufficient data'), findsNothing);
      expect(find.text('Final compatibility'), findsNothing);
      expect(find.textContaining('0 points'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  // Regression: web release builds rendered the error widget because the
  // change-impact pins were VM-only digests. Run with `--platform chrome` too.
  testWidgets('builds with verified configuration pins on this runtime', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: AlgorithmObservatoryPage()),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(ErrorWidget), findsNothing);
    await _scrollLazyListUntilBuilt(
      tester,
      find.byKey(const Key('configuration-impact-pin-status')),
    );
    expect(find.text('TWO EXTERNAL DIGEST PINS VERIFIED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
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
      ledgerAuthorization: base.ledgerAuthorization,
      replayCapsule: base.replayCapsule,
      gastricStructuralUncertainty: base.gastricStructuralUncertainty,
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
      ledgerAuthorization: base.ledgerAuthorization,
      replayCapsule: base.replayCapsule,
      gastricStructuralUncertainty: base.gastricStructuralUncertainty,
      explanationTree: base.explanationTree,
    );
  }
}
