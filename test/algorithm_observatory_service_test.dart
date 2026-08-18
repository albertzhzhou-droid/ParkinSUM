import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
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
      expect(snapshot.explanationTree.nodeCount, greaterThanOrEqualTo(7));
      expect(
        snapshot.explanationTree.children.map((node) => node.id),
        containsAll([
          'meal_composition_normalizer',
          'gastric_emptying',
          'levodopa_absorption_opportunity',
          'amino_acid_competition',
          'mechanistic_candidate_scorer',
        ]),
      );
      expect(snapshot.gastricParameters.all, hasLength(14));
      expect(snapshot.gastricParameters.version, '2026.08.17-v2');
      expect(snapshot.gastricParameters.lastReviewed, '2026-08-17');
      expect(
        snapshot.candidateScores.every((score) => score.sampleCount >= 5),
        isTrue,
      );
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
