import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/gastric_structural_uncertainty.dart';
import 'package:parkinsum_companion/domain/entities/protein_distribution.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';

void main() {
  final service = AlgorithmObservatoryService();

  test(
    'observatory uses complete production traces, not static chart data',
    () {
      final snapshot = service.build(ObservatoryScenario.mixedReference);
      expect(snapshot.conflict.primaryEmptyingProfile, isNotNull);
      expect(snapshot.conflict.absorptionOpportunityWindow, isNotNull);
      expect(snapshot.conflict.competitionTimeline, isNotNull);
      expect(
        snapshot.conflict.absorptionOpportunityWindow!.opennessProfile,
        isNotEmpty,
      );
      expect(snapshot.conflict.competitionTimeline!.samples, isNotEmpty);
      expect(snapshot.candidateScores, hasLength(2));
      expect(snapshot.explanationTree.nodeCount, greaterThanOrEqualTo(12));
      expect(
        snapshot.explanationTree.children.map((node) => node.id),
        containsAll([
          'meal_composition_normalizer',
          'input_quality_gate',
          'medication_entry_validator',
          'dosage_note_parser',
          'gastric_emptying',
          'levodopa_absorption_opportunity',
          'amino_acid_competition',
          'mechanistic_candidate_scorer',
          'protein_trend',
          'protein_distribution',
        ]),
      );
      expect(snapshot.gastricParameters.all, hasLength(14));
      expect(snapshot.gastricParameters.version, '2026.09.02-v3');
      expect(snapshot.gastricParameters.lastReviewed, '2026-09-02');
      expect(
        snapshot.candidateScores.every((score) => score.sampleCount >= 5),
        isTrue,
      );
    },
  );

  test('protein distribution trace projects only production scorer outputs', () {
    for (final scenario in ObservatoryScenario.values) {
      final snapshot = service.build(scenario);
      final node = snapshot.explanationTree.children.singleWhere(
        (candidate) => candidate.id == 'protein_distribution',
      );
      final encoded = jsonEncode(node.toJson());
      final modeled = snapshot.candidateScores
          .map((score) => score.modeledProteinDistribution)
          .whereType<ProteinDistributionTrace>()
          .where((result) => result.optimizationActive)
          .toList(growable: false);

      expect(node.algorithmId, 'protein_distribution', reason: scenario.name);
      expect(
        node.providerId,
        AlgorithmObservatoryService.traceProviderContract.providerId,
        reason: scenario.name,
      );
      expect(node.children, hasLength(modeled.length), reason: scenario.name);
      for (var index = 0; index < modeled.length; index++) {
        final result = modeled[index];
        expect(
          node.children[index].output,
          'role ${result.windowRole.name}; '
          'redistribution ${(result.redistributionScore * 100).toStringAsFixed(1)}%; '
          'adequacy contribution ${(result.nutritionAdequacyContribution * 100).toStringAsFixed(1)}%',
          reason: scenario.name,
        );
      }
      expect(node.limitation, contains('does not alter scores or ranking'));
      for (final withheldValue in const [
        'Oats and fruit fixture',
        'Yogurt fixture',
        'synthetic:observatory',
        'oats_component',
        'yogurt_component',
      ]) {
        expect(encoded, isNot(contains(withheldValue)), reason: scenario.name);
      }
    }
  });

  test(
    'protein trend trace runs the production use case on synthetic meals',
    () {
      for (final scenario in ObservatoryScenario.values) {
        final node = service
            .build(scenario)
            .explanationTree
            .children
            .singleWhere((candidate) => candidate.id == 'protein_trend');
        final encoded = jsonEncode(node.toJson());

        expect(node.algorithmId, 'protein_trend');
        expect(
          node.providerId,
          AlgorithmObservatoryService.traceProviderContract.providerId,
        );
        expect(
          node.output,
          '3 chronologically sorted point(s); relative series '
          '0d:10.0g → 1d:20.0g → 2d:30.0g; arithmetic mean 20.0 g per meal',
        );
        expect(
          node.inputs,
          contains(
            'effective time precedence: occurredAt → range start → eatenAt',
          ),
        );
        expect(node.sourceRefs, isEmpty);
        expect(node.limitation, contains('fixed synthetic inputs'));
        for (final withheldValue in const [
          'synthetic:protein-trend',
          'Synthetic protein trend fixture',
          'synthetic fixture item',
          '2026-01-01',
        ]) {
          expect(encoded, isNot(contains(withheldValue)));
        }
      }
    },
  );

  test(
    'dose parser trace runs fixed syntax cases without exposing text or values',
    () {
      for (final scenario in ObservatoryScenario.values) {
        final node = service
            .build(scenario)
            .explanationTree
            .children
            .singleWhere((candidate) => candidate.id == 'dosage_note_parser');
        final encoded = jsonEncode(node.toJson());

        expect(node.algorithmId, 'dosage_note_parser');
        expect(
          node.providerId,
          AlgorithmObservatoryService.traceProviderContract.providerId,
        );
        expect(
          node.output,
          'grammar v4; 5 cases; accepted 1, empty 1, held 3; reason counts '
          'dose.empty=1, dose.multiple_numeric_tokens=1, '
          'dose.non_exact_comparator=1, dose.range_not_supported=1',
        );
        expect(
          node.inputs,
          contains(
            'standalone parser probe; not the medication context used by other traces',
          ),
        );
        expect(node.limitation, contains('not medication identity'));
        expect(
          node.limitation,
          contains('does not feed the other Observatory traces'),
        );
        for (final hiddenValue in const [
          '7 mg',
          '2-4 mg',
          '~7 mg',
          '1 mg and 2 mg',
          '2026-01-01',
        ]) {
          expect(encoded, isNot(contains(hiddenValue)));
        }
      }
    },
  );

  test(
    'input quality trace binds the real gate and identifies product-strength-only input',
    () {
      for (final scenario in ObservatoryScenario.values) {
        final snapshot = service.build(scenario);
        final node = snapshot.explanationTree.children.singleWhere(
          (candidate) => candidate.id == 'input_quality_gate',
        );
        final encodedNode = jsonEncode(node.toJson());

        expect(node.algorithmId, 'input_quality_gate', reason: scenario.name);
        expect(
          node.providerId,
          AlgorithmObservatoryService.traceProviderContract.providerId,
          reason: scenario.name,
        );
        expect(node.output, contains('gate held'), reason: scenario.name);
        expect(
          node.inputs,
          contains('product strength treated as metadata, not an intake dose'),
          reason: scenario.name,
        );
        expect(node.limitation, contains('not used to authorize or veto'));
        expect(node.sourceRefs, isEmpty, reason: scenario.name);
        for (final withheldValue in const [
          'carbidopa',
          'levodopa',
          'synthetic:observatory',
          'clinical_pharmacology',
          'observatory-ir',
        ]) {
          expect(
            encodedNode,
            isNot(contains(withheldValue)),
            reason: '${scenario.name} exposed a source value',
          );
        }
      }
    },
  );

  test(
    'medication validation trace is provider-bound and omits synthetic source values',
    () {
      for (final scenario in ObservatoryScenario.values) {
        final snapshot = service.build(scenario);
        final node = snapshot.explanationTree.children.singleWhere(
          (candidate) => candidate.id == 'medication_entry_validator',
        );
        final encodedNode = jsonEncode(node.toJson());

        expect(
          node.algorithmId,
          'medication_entry_validator',
          reason: scenario.name,
        );
        expect(
          node.providerId,
          AlgorithmObservatoryService.traceProviderContract.providerId,
          reason: scenario.name,
        );
        expect(node.output, contains('valid;'), reason: scenario.name);
        expect(
          node.output,
          contains('eligible for educational model input'),
          reason: scenario.name,
        );
        expect(
          node.inputs,
          contains(
            '2 ingredient token(s); strength/unit, product variant, form, route, and release type present',
          ),
          reason: scenario.name,
        );
        for (final withheldValue in const [
          'carbidopa',
          'levodopa',
          'synthetic:observatory-ir',
          'clinical_pharmacology',
        ]) {
          expect(
            encodedNode,
            isNot(contains(withheldValue)),
            reason: '${scenario.name} exposed a source value',
          );
        }
      }
    },
  );

  test(
    'structural uncertainty trace is provider-bound and explicitly reports unavailable scenarios',
    () {
      var executedReportCount = 0;
      for (final scenario in ObservatoryScenario.values) {
        final snapshot = service.build(scenario);
        final node = snapshot.explanationTree.children.singleWhere(
          (candidate) =>
              candidate.id == 'gastric_structural_uncertainty_shadow_ensemble',
        );
        expect(
          node.algorithmId,
          'gastric_structural_uncertainty_shadow_ensemble',
          reason: scenario.name,
        );
        expect(
          node.providerId,
          AlgorithmObservatoryService.traceProviderContract.providerId,
          reason: scenario.name,
        );
        final report = snapshot.gastricStructuralUncertainty;
        if (report == null) {
          expect(
            node.inputs,
            contains('production gastric profile unavailable'),
            reason: scenario.name,
          );
          expect(
            node.output,
            contains('no shadow trajectory was generated'),
            reason: scenario.name,
          );
          expect(node.sourceRefs, isEmpty, reason: scenario.name);
          continue;
        }

        executedReportCount++;
        final comparableCount = report.trajectories
            .where(
              (trajectory) =>
                  trajectory.availability ==
                  GastricTrajectoryAvailability.available,
            )
            .length;
        expect(report.integrityReasons, isEmpty, reason: scenario.name);
        expect(
          report.productionOutputDigestBefore,
          report.productionOutputDigestAfter,
        );
        expect(node.sourceRefs, isNotEmpty, reason: scenario.name);
        expect(
          node.output,
          contains(
            '$comparableCount/${report.trajectories.length} '
            'observable-matched structures',
          ),
          reason: scenario.name,
        );
        expect(
          node.output,
          contains(report.sha256Digest.substring(0, 12)),
          reason: scenario.name,
        );
        expect(
          node.inputs,
          contains('production output unchanged'),
          reason: scenario.name,
        );
        expect(
          node.limitation,
          contains('not an ensemble accuracy gain'),
          reason: scenario.name,
        );
      }
      expect(executedReportCount, greaterThan(0));
    },
  );

  test(
    'trace display and export use event-relative minutes without epoch leakage',
    () {
      for (final scenario in const [
        ObservatoryScenario.mixedReference,
        ObservatoryScenario.highFatProtein,
      ]) {
        final snapshot = service.build(scenario);
        final emptying = snapshot.conflict.primaryEmptyingProfile!;
        final absorption = snapshot.conflict.absorptionOpportunityWindow!;
        final mealMinute = snapshot.context.mealEvents
            .firstWhere((event) => event.id == emptying.mealId)
            .minute;
        final doseMinute = snapshot.context.medicationEvents
            .firstWhere((event) => event.id == absorption.medicationEventId)
            .minute;
        final gastricNode = snapshot.explanationTree.children.firstWhere(
          (node) => node.id == 'gastric_emptying',
        );
        final absorptionNode = snapshot.explanationTree.children.firstWhere(
          (node) => node.id == 'levodopa_absorption_opportunity',
        );

        expect(
          gastricNode.output,
          'mostly-emptied window '
          '${emptying.mostlyEmptiedWindow.startMinute - mealMinute}–'
          '${emptying.mostlyEmptiedWindow.endMinute - mealMinute} '
          'min after meal start',
          reason: scenario.name,
        );
        expect(
          absorptionNode.output,
          contains(
            'opportunity window '
            '${absorption.window.startMinute - doseMinute}–'
            '${absorption.window.endMinute - doseMinute} min after dose',
          ),
          reason: scenario.name,
        );
        expect(
          absorptionNode.output,
          contains('peak ${absorption.peakMinute - doseMinute} min after dose'),
          reason: scenario.name,
        );

        // The production engine keeps canonical absolute minutes for stable
        // ordering. Only the provider's display/export projection is relative.
        expect(emptying.mostlyEmptiedWindow.startMinute, greaterThan(1000000));
        expect(absorption.peakMinute, greaterThan(1000000));
        final exportedTrace = jsonEncode(snapshot.explanationTree.toJson());
        for (final rawEpochMinute in <int>{
          mealMinute,
          doseMinute,
          emptying.mostlyEmptiedWindow.startMinute,
          emptying.mostlyEmptiedWindow.endMinute,
          absorption.window.startMinute,
          absorption.window.endMinute,
          absorption.peakMinute,
        }) {
          expect(
            exportedTrace,
            isNot(contains('$rawEpochMinute')),
            reason: '${scenario.name} leaked UTC epoch minute $rawEpochMinute',
          );
        }
      }
    },
  );

  test(
    'time-axis trace binds the production builder and exports relative offsets only',
    () {
      for (final scenario in ObservatoryScenario.values) {
        final snapshot = service.build(scenario);
        final node = snapshot.explanationTree.children.singleWhere(
          (candidate) => candidate.id == 'time_axis_builder',
        );
        final mealMinute = snapshot.context.mealEvents.first.minute;
        final medicationMinute = snapshot.context.medicationEvents.first.minute;
        final relativeDose = medicationMinute - mealMinute;
        final doseOffset = relativeDose > 0
            ? '+$relativeDose min'
            : '$relativeDose min';
        final encodedTree = jsonEncode(snapshot.explanationTree.toJson());

        expect(node.algorithmId, 'time_axis_builder', reason: scenario.name);
        expect(
          node.providerId,
          AlgorithmObservatoryService.traceProviderContract.providerId,
          reason: scenario.name,
        );
        expect(node.inputs, contains('1 meal event(s)'), reason: scenario.name);
        expect(
          node.inputs,
          contains('1 medication event(s)'),
          reason: scenario.name,
        );
        expect(
          node.output,
          contains('meals 0 min; medications $doseOffset'),
          reason: scenario.name,
        );
        expect(
          node.output,
          contains('caller window +120 min to +210 min'),
          reason: scenario.name,
        );
        expect(
          encodedTree,
          isNot(contains('${snapshot.context.referenceMinute}')),
          reason: '${scenario.name} must not export absolute UTC minutes',
        );
        expect(
          encodedTree,
          isNot(contains('observatory_meal_event')),
          reason: '${scenario.name} must not export event identifiers',
        );
        expect(
          encodedTree,
          isNot(contains('observatory_dose')),
          reason: '${scenario.name} must not export medication event IDs',
        );
      }
    },
  );

  test(
    'every visible parameter carries evidence and an uncertainty boundary',
    () {
      final snapshot = service.build(ObservatoryScenario.mixedReference);

      for (final parameter in snapshot.gastricParameters.all) {
        expect(parameter.sourceRefs, isNotEmpty, reason: parameter.id);
        expect(parameter.limitation, isNotEmpty, reason: parameter.id);
      }
      expect(
        snapshot.gastricParameters.all.any(
          (parameter) => parameter.isPrototypeHeuristic,
        ),
        isTrue,
        reason: 'Illustrative magnitudes must remain visibly classified.',
      );
    },
  );

  test('snapshot carries canonical per-parameter provenance identity', () {
    final snapshot = service.build(ObservatoryScenario.mixedReference);
    final manifest = snapshot.configurationIdentity.parameterProvenanceManifest;

    expect(manifest.records.length, greaterThan(50));
    expect(snapshot.configurationIdentity.sha256Digest, hasLength(64));
    expect(
      manifest.records.any(
        (record) => record.parameterId == 'absorption.openness.ir_peak',
      ),
      isTrue,
    );
    expect(
      manifest.records.every(
        (record) => record.sourceIds.isNotEmpty && record.limitation.isNotEmpty,
      ),
      isTrue,
    );
  });

  test(
    'high-fat high-protein scenario changes residence and conflict trace',
    () {
      final reference = service.build(ObservatoryScenario.mixedReference);
      final high = service.build(ObservatoryScenario.highFatProtein);
      final referenceProfile = reference.conflict.primaryEmptyingProfile!;
      final highProfile = high.conflict.primaryEmptyingProfile!;
      expect(
        highProfile.mostlyEmptiedWindow.endMinute,
        greaterThan(referenceProfile.mostlyEmptiedWindow.endMinute),
      );
      final referencePressure =
          reference.conflict.competitionTimeline!.peakPressure;
      final highPressure = high.conflict.competitionTimeline!.peakPressure;
      expect(
        referencePressure,
        greaterThan(0.1),
        reason: 'The displayed LNAA curve must not collapse to visual zero.',
      );
      expect(
        highPressure,
        greaterThan(referencePressure),
        reason: 'A higher protein load must create a stronger pressure trace.',
      );
      expect(
        high.conflict.interactionScore,
        isNot(reference.conflict.interactionScore),
      );
    },
  );

  test('missing data abstains without fabricating a zero or model curve', () {
    final incomplete = service.build(ObservatoryScenario.incompleteData);
    expect(incomplete.composition.totalCalories, isNull);
    expect(incomplete.composition.fatGrams, isNull);
    expect(incomplete.composition.missingFields, contains('total_calories'));
    expect(incomplete.conflict.hasModeledOutput, isFalse);
    expect(incomplete.conflict.modeledInteractionScore, isNull);
    expect(incomplete.conflict.primaryEmptyingProfile, isNull);
    expect(incomplete.conflict.absorptionOpportunityWindow, isNull);
    expect(incomplete.conflict.competitionTimeline, isNull);
    expect(incomplete.conflict.toJson()['interaction_score'], isNull);
    expect(
      incomplete.explanationTree.output,
      contains('status insufficient; no modeled output'),
    );
  });
}
