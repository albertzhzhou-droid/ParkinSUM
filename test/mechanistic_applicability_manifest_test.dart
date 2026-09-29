import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

void main() {
  final validator = MedicationEntryValidator();
  const policy = MechanisticMedicationApplicabilityPolicy();

  NormalizedMedicationContext context({
    List<String> ingredients = const ['carbidopa', 'levodopa'],
    String route = 'oral',
    String form = 'tablet',
    String releaseType = 'immediate_release',
  }) {
    final result = validator.validate(
      RawMedicationEntry(
        activeIngredients: ingredients,
        drugProductVariant: 'synthetic:manifest-test',
        strength: 100,
        unit: 'mg',
        form: form,
        route: route,
        releaseType: releaseType,
        jurisdiction: 'US',
        sourceDocId: 'synthetic:manifest-test',
      ),
    );
    expect(result.eligibleForRuleEvaluation, isTrue);
    return result.normalized!;
  }

  test('manifest binds every live provider to registered predicates', () {
    final manifest = MechanisticApplicabilityManifest.current;
    final predicateIds = manifest.predicates.map((entry) => entry.id).toSet();
    final providerIds = manifest.providers
        .map((entry) => entry.providerId)
        .toSet();

    expect(
      providerIds,
      unorderedEquals(const [
        'meal_composition_normalizer',
        'gastric_emptying',
        'levodopa_absorption_opportunity',
        'amino_acid_competition',
        'mechanistic_conflict',
        'mechanistic_candidate_scorer',
      ]),
    );
    expect(
      AlgorithmObservatoryService.traceProviderContract.algorithmIds.toSet(),
      containsAll(providerIds),
    );
    expect(
      AlgorithmObservatoryService.traceProviderContract.algorithmIds
          .toSet()
          .difference(providerIds),
      {
        // These trace adapters expose validation or synthetic diagnostics;
        // they do not add providers to the six-model applicability manifest.
        'medication_entry_validator',
        'input_quality_gate',
        'time_axis_builder',
        'mechanistic_lossless_replay_capsule',
        'protein_trend',
        'dosage_note_parser',
        'gastric_structural_uncertainty_shadow_ensemble',
        'protein_distribution',
      },
    );
    expect(manifest.predicates, hasLength(10));
    for (final provider in manifest.providers) {
      expect(provider.predicateIds, isNotEmpty, reason: provider.providerId);
      expect(
        provider.predicateIds.every(predicateIds.contains),
        isTrue,
        reason: provider.providerId,
      );
      expect(provider.evidenceSourceIds, isNotEmpty);
      expect(provider.decisionInfluence, isNotEmpty);
    }
  });

  test('manifest has deterministic canonical JSON and SHA-256 identity', () {
    final manifest = MechanisticApplicabilityManifest.current;
    final encoded = jsonEncode(manifest.toJson());

    expect(manifest.sha256Digest, matches(RegExp(r'^[a-f0-9]{64}$')));
    expect(manifest.toJson()['sha256'], manifest.sha256Digest);
    expect(jsonDecode(encoded), isA<Map<String, dynamic>>());
    expect(
      manifest.sourceRef,
      '${MechanisticApplicabilityManifest.manifestId}@'
      '${MechanisticApplicabilityManifest.manifestVersion}#sha256:'
      '${manifest.sha256Digest}',
    );
    expect(
      manifest.canonicalJson,
      MechanisticApplicabilityManifest.current.canonicalJson,
    );
  });

  test('canonical algorithm identity embeds the exact manifest', () {
    final manifest = MechanisticApplicabilityManifest.current;
    final identity = AlgorithmConfigurationIdentity.defaults();
    final embedded =
        identity.canonicalConfiguration['mechanistic_applicability_manifest'];

    expect(embedded, manifest.toJson());
    expect((embedded as Map<String, dynamic>)['sha256'], manifest.sha256Digest);
  });

  test(
    'policy emits live predicate outcomes for inside and outside inputs',
    () {
      final inside = policy.evaluate(context());
      final outside = policy.evaluate(context(releaseType: 'extended_release'));
      final unknown = policy.evaluate(context(releaseType: 'unmapped-release'));

      expect(inside.predicateOutcomes, hasLength(4));
      expect(
        inside.predicateOutcomes.map((outcome) => outcome.status),
        everyElement(MechanisticApplicabilityOutcomeStatus.satisfied),
      );
      expect(
        outside.predicateOutcomes
            .singleWhere(
              (outcome) => outcome.predicateId == 'medication.release_type',
            )
            .status,
        MechanisticApplicabilityOutcomeStatus.notApplicable,
      );
      expect(
        unknown.predicateOutcomes
            .singleWhere(
              (outcome) => outcome.predicateId == 'medication.release_type',
            )
            .status,
        MechanisticApplicabilityOutcomeStatus.insufficient,
      );
      expect(
        inside.toJson()['applicability_manifest_sha256'],
        MechanisticApplicabilityManifest.current.sha256Digest,
      );
    },
  );

  test('mixed timelines conservatively aggregate predicate outcomes', () {
    final result = policy.evaluateContexts([
      context(releaseType: 'extended_release'),
      context(ingredients: const ['ferrous sulfate']),
    ]);

    expect(
      result.status,
      MechanisticMedicationApplicabilityStatus.insufficient,
    );
    expect(
      result.predicateOutcomes
          .singleWhere(
            (outcome) => outcome.predicateId == 'medication.release_type',
          )
          .status,
      MechanisticApplicabilityOutcomeStatus.notApplicable,
    );
    expect(
      result.predicateOutcomes
          .singleWhere(
            (outcome) => outcome.predicateId == 'medication.active_components',
          )
          .status,
      MechanisticApplicabilityOutcomeStatus.insufficient,
    );
  });

  test(
    'production result separates manifest identity from scientific sources',
    () {
      final snapshot = AlgorithmObservatoryService().build(
        ObservatoryScenario.mixedReference,
      );
      final sourceRef = MechanisticApplicabilityManifest.current.sourceRef;

      expect(snapshot.conflict.hasModeledOutput, isTrue);
      expect(snapshot.conflict.sourceRefs, isNot(contains(sourceRef)));
      expect(
        snapshot.conflict.explanation.sourceRefs,
        isNot(contains(sourceRef)),
      );
      expect(snapshot.conflict.applicabilityManifestRef, sourceRef);
      expect(snapshot.conflict.explanation.applicabilityManifestRef, sourceRef);
      expect(
        snapshot.conflict.perEventTraces,
        everyElement(
          predicate<MechanisticPerEventTrace>(
            (trace) =>
                !trace.sourceRefs.contains(sourceRef) &&
                trace.applicabilityManifestRef == sourceRef,
          ),
        ),
      );
      final wire = snapshot.conflict.toJson();
      expect(wire['applicability_manifest_ref'], sourceRef);
      expect(
        (wire['explanation']
            as Map<String, dynamic>)['applicability_manifest_ref'],
        sourceRef,
      );
      expect(
        (wire['per_event_traces'] as List<dynamic>).every(
          (trace) =>
              (trace as Map<String, dynamic>)['applicability_manifest_ref'] ==
              sourceRef,
        ),
        isTrue,
      );
    },
  );

  test('typed abstention binds the manifest without polluting source refs', () {
    final sourceRef = MechanisticApplicabilityManifest.current.sourceRef;
    final result = MechanisticConflictResult.insufficientContext(
      id: 'manifest-abstention',
      reason: MechanisticInteractionType.insufficientMedicationContext,
      missingInputs: const ['medication.release_type'],
      sourceRefs: const ['src.fda.sinemet-label.2024'],
    );

    expect(result.applicabilityManifestRef, sourceRef);
    expect(result.explanation.applicabilityManifestRef, sourceRef);
    expect(result.sourceRefs, isNot(contains(sourceRef)));
    expect(result.toJson()['applicability_manifest_ref'], sourceRef);
  });
}
