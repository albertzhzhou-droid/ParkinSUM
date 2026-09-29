import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_extraction_invariant_probe.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_numerical_verification_oracle.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_candidate_projection_invariant_probe.dart';
import 'package:parkinsum_companion/domain/usecases/dose_input_invariant_probe.dart';
import 'package:parkinsum_companion/domain/usecases/legacy_food_recommendation_invariant_probe.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_model_verification_gate.dart';

void main() {
  const gate = MechanisticModelVerificationGate();

  test(
    'production-facing invariant and unit report passes fixed scenarios',
    () {
      final report = gate.run();

      expect(report.passed, isTrue, reason: _describe(report));
      expect(report.passedCheckCount, 23);
      expect(report.failedCheckCount, 0);
      expect(report.scenarioIds, <String>[
        'highFatProtein',
        'incompleteData',
        'mixedReference',
      ]);
      expect(report.configurationDigest, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(report.specificationDigest, matches(RegExp(r'^[a-f0-9]{64}$')));
      expect(
        report.coveredAlgorithmIds,
        containsAll(<String>{
          'meal_composition_normalizer',
          'time_axis_builder',
          'gastric_emptying',
          'levodopa_absorption_opportunity',
          'amino_acid_competition',
          'mechanistic_conflict',
          'mechanistic_candidate_scorer',
          'medication_entry_validator',
          'runtime_model_applicability_abstention_gate',
          'protein_distribution',
          'algorithm_configuration_identity',
          'gastric_structural_uncertainty_shadow_ensemble',
          'dosage_note_parser',
          'intake_dose_context',
          'package_dose_calculator',
          'metadata_completeness_gate',
          'input_quality_gate',
          'administration_dose_confirmation_reconciliation',
          'medication_assertion_source_temporal_reconciliation',
          'legacy_food_recommendations',
          'amino_acid_extraction',
          'catalog_candidate_projection',
        }),
      );
      expect(AlgorithmRegistry.all, hasLength(65));
      expect(report.coveredAlgorithmIds, hasLength(22));
      expect(
        AlgorithmRegistry.all
            .where(
              (entry) =>
                  report.statusFor(entry.id) ==
                  AlgorithmInvariantCoverageStatus.notCovered,
            )
            .toList(growable: false),
        hasLength(43),
      );
      expect(
        report.statusFor('gastric_emptying'),
        AlgorithmInvariantCoverageStatus.passed,
      );
      expect(
        report.statusFor('runtime_model_applicability_abstention_gate'),
        AlgorithmInvariantCoverageStatus.passed,
      );
      expect(
        report.statusFor('runtime_rule_engine'),
        AlgorithmInvariantCoverageStatus.notCovered,
      );
      expect(
        report.statusFor('package_dose_calculator'),
        AlgorithmInvariantCoverageStatus.passed,
      );
      expect(
        report.statusFor('administration_dose_confirmation_reconciliation'),
        AlgorithmInvariantCoverageStatus.passed,
      );
      expect(
        report.statusFor('medication_assertion_source_temporal_reconciliation'),
        AlgorithmInvariantCoverageStatus.passed,
      );
      expect(
        report.statusFor('legacy_food_recommendations'),
        AlgorithmInvariantCoverageStatus.passed,
      );
      expect(
        report.statusFor('amino_acid_extraction'),
        AlgorithmInvariantCoverageStatus.passed,
      );
      expect(
        report.statusFor('catalog_candidate_projection'),
        AlgorithmInvariantCoverageStatus.passed,
      );
    },
  );

  test('specification is finite, unique, explicit, and digest-bound', () {
    final specs = MechanisticModelVerificationGate.specifications;
    final bindings = MechanisticModelVerificationGate.probeBindings;

    expect(specs, hasLength(23));
    expect(specs.map((entry) => entry.id).toSet(), hasLength(specs.length));
    expect(
      bindings.map((entry) => entry.probeId).toSet(),
      hasLength(bindings.length),
    );
    for (final binding in bindings) {
      expect(binding.probeId.trim(), isNotEmpty);
      expect(binding.method.trim(), isNotEmpty, reason: binding.probeId);
      expect(binding.algorithmIds, isNotEmpty, reason: binding.probeId);
      expect(
        binding.algorithmIds.toSet(),
        hasLength(binding.algorithmIds.length),
        reason: '${binding.probeId} repeats an algorithm identity',
      );
      for (final algorithmId in binding.algorithmIds) {
        expect(
          AlgorithmRegistry.byId(algorithmId),
          isNotNull,
          reason: '${binding.probeId} authorizes unknown $algorithmId',
        );
        expect(
          specs.any(
            (spec) =>
                spec.probeId == binding.probeId &&
                spec.algorithmIds.contains(algorithmId),
          ),
          isTrue,
          reason:
              '${binding.probeId} authorizes unclaimed algorithm $algorithmId',
        );
      }
    }
    for (final spec in specs) {
      expect(spec.id.trim(), isNotEmpty);
      expect(spec.probeId.trim(), isNotEmpty, reason: spec.id);
      expect(spec.algorithmIds, isNotEmpty, reason: spec.id);
      expect(spec.observable.trim(), isNotEmpty, reason: spec.id);
      expect(spec.canonicalUnit.trim(), isNotEmpty, reason: spec.id);
      expect(spec.method.trim(), isNotEmpty, reason: spec.id);
      expect(spec.sourceRefs, isNotEmpty, reason: spec.id);
      expect(spec.tolerance.isFinite, isTrue, reason: spec.id);
      expect(spec.tolerance, greaterThanOrEqualTo(0), reason: spec.id);
      for (final algorithmId in spec.algorithmIds) {
        expect(
          AlgorithmRegistry.byId(algorithmId),
          isNotNull,
          reason: '${spec.id} references unknown $algorithmId',
        );
        expect(
          MechanisticModelVerificationGate.bindingFor(
            spec.probeId,
          )?.algorithmIds,
          contains(algorithmId),
          reason: '${spec.id} is not authorized by ${spec.probeId}',
        );
      }
    }
    expect(MechanisticModelVerificationGate.specificationDigest, hasLength(64));
  });

  test(
    'dose-input probe mutations fail their exact visible specifications',
    () {
      final service = AlgorithmObservatoryService();
      final snapshots = <ObservatoryScenario, AlgorithmObservatorySnapshot>{
        for (final scenario in ObservatoryScenario.values)
          scenario: service.build(scenario),
      };
      final oracle = const AlgorithmNumericalVerificationOracle().run(
        service: service,
      );
      final baseline = DoseInputInvariantProbe.capture();
      final cases =
          <
            ({
              DoseInputInvariantProbe probe,
              String specificationId,
              String failureCode,
            })
          >[
            (
              probe: baseline.withObservation('parser.gram.milligrams', 1.0),
              specificationId: 'dose.typed_expression_and_intake_separation',
              failureCode: 'dose.expression.mismatch.parser.gram.milligrams',
            ),
            (
              probe: baseline.withObservation(
                'package.overflow_rejected',
                false,
              ),
              specificationId:
                  'dose.package_strength_multiplication_and_bounds',
              failureCode: 'dose.package.mismatch.package.overflow_rejected',
            ),
            (
              probe: baseline.withObservation(
                'metadata.nonfinite.status',
                'complete',
              ),
              specificationId: 'dose.metadata_completeness_numeric_domain',
              failureCode: 'dose.metadata.mismatch.metadata.nonfinite.status',
            ),
            (
              probe: baseline.withObservation(
                'input_quality.nonfinite.status',
                'complete',
              ),
              specificationId: 'dose.input_quality_fail_closed_separation',
              failureCode:
                  'dose.input_quality.mismatch.input_quality.nonfinite.status',
            ),
            (
              probe: baseline.withObservation(
                'result_gate.confirmed.eligible',
                false,
              ),
              specificationId:
                  'dose.confirmation_assertion_and_as_of_result_gate',
              failureCode:
                  'dose.result_gate.mismatch.result_gate.confirmed.eligible',
            ),
            (
              probe: baseline.withoutObservation('parser.range.reason'),
              specificationId: 'dose.typed_expression_and_intake_separation',
              failureCode: 'dose.expression.missing.parser.range.reason',
            ),
          ];

      for (final mutation in cases) {
        final report = gate.verify(
          snapshots: snapshots,
          oracleReport: oracle,
          doseInputProbe: mutation.probe,
        );
        final check = report.checks.singleWhere(
          (entry) => entry.spec.id == mutation.specificationId,
        );
        expect(check.passed, isFalse, reason: mutation.failureCode);
        expect(check.failureCodes, contains(mutation.failureCode));
      }
    },
  );

  test(
    'legacy recommendation probe mutations fail only its bound specification',
    () {
      final service = AlgorithmObservatoryService();
      final snapshots = <ObservatoryScenario, AlgorithmObservatorySnapshot>{
        for (final scenario in ObservatoryScenario.values)
          scenario: service.build(scenario),
      };
      final oracle = const AlgorithmNumericalVerificationOracle().run(
        service: service,
      );
      final doseProbe = DoseInputInvariantProbe.capture();
      final baseline = LegacyFoodRecommendationInvariantProbe.capture();
      final mutations = <LegacyFoodRecommendationInvariantProbe>[
        baseline.withObservation('baseline.score', 94.25),
        baseline.withObservation('bounds.score', 101.09),
        baseline.withObservation('ranking.permutation_invariant', false),
      ];

      for (final mutation in mutations) {
        final report = gate.verify(
          snapshots: snapshots,
          oracleReport: oracle,
          doseInputProbe: doseProbe,
          legacyRecommendationProbe: mutation,
        );
        final check = report.checks.singleWhere(
          (entry) =>
              entry.spec.id ==
              'recommendation.legacy_score_bounds_thresholds_and_order',
        );
        expect(check.passed, isFalse);
        expect(
          report.statusFor('legacy_food_recommendations'),
          AlgorithmInvariantCoverageStatus.failed,
        );
        expect(
          report.statusFor('gastric_emptying'),
          AlgorithmInvariantCoverageStatus.passed,
        );
      }
    },
  );

  test(
    'amino-acid extraction probe mutations fail only its bound specification',
    () {
      final service = AlgorithmObservatoryService();
      final snapshots = <ObservatoryScenario, AlgorithmObservatorySnapshot>{
        for (final scenario in ObservatoryScenario.values)
          scenario: service.build(scenario),
      };
      final oracle = const AlgorithmNumericalVerificationOracle().run(
        service: service,
      );
      final doseProbe = DoseInputInvariantProbe.capture();
      final recommendationProbe =
          LegacyFoodRecommendationInvariantProbe.capture();
      final baseline = AminoAcidExtractionInvariantProbe.capture();
      final mutations = <(AminoAcidExtractionInvariantProbe, String)>[
        (
          baseline.withObservation('unit.missing.held', false),
          'amino_acid.extraction.mismatch.unit.missing.held',
        ),
        (
          baseline.withObservation('invalid.negative.held', false),
          'amino_acid.extraction.mismatch.invalid.negative.held',
        ),
        (
          baseline.withObservation('held_only.profile_present', false),
          'amino_acid.extraction.mismatch.held_only.profile_present',
        ),
        (
          baseline.withObservation('duplicate.forward.held', false),
          'amino_acid.extraction.mismatch.duplicate.forward.held',
        ),
        (
          baseline.withObservation('duplicate.permutation_stable', false),
          'amino_acid.extraction.mismatch.duplicate.permutation_stable',
        ),
        (
          baseline.withObservation('zero.leucine_g', null),
          'amino_acid.extraction.mismatch.zero.leucine_g',
        ),
        (
          baseline.withoutObservation('ordering.nutrient_ids'),
          'amino_acid.extraction.missing.ordering.nutrient_ids',
        ),
      ];

      for (final mutation in mutations) {
        final report = gate.verify(
          snapshots: snapshots,
          oracleReport: oracle,
          doseInputProbe: doseProbe,
          legacyRecommendationProbe: recommendationProbe,
          aminoAcidExtractionProbe: mutation.$1,
        );
        final check = report.checks.singleWhere(
          (entry) =>
              entry.spec.id ==
              'nutrition.amino_acid_extraction_units_missingness_and_determinism',
        );
        expect(check.passed, isFalse, reason: mutation.$2);
        expect(check.failureCodes, contains(mutation.$2));
        expect(report.failedCheckCount, 1, reason: mutation.$2);
        expect(
          report.statusFor('amino_acid_extraction'),
          AlgorithmInvariantCoverageStatus.failed,
        );
        expect(
          report.statusFor('legacy_food_recommendations'),
          AlgorithmInvariantCoverageStatus.passed,
        );
      }
    },
  );

  test('catalog projection probe mutations fail only its bound specification', () {
    final service = AlgorithmObservatoryService();
    final snapshots = <ObservatoryScenario, AlgorithmObservatorySnapshot>{
      for (final scenario in ObservatoryScenario.values)
        scenario: service.build(scenario),
    };
    final oracle = const AlgorithmNumericalVerificationOracle().run(
      service: service,
    );
    final baseline = CatalogCandidateProjectionInvariantProbe.capture();
    final mutations = <(CatalogCandidateProjectionInvariantProbe, String)>[
      (
        baseline.withObservation('catalog.missing.energy_null', false),
        'catalog.candidate_projection.mismatch.catalog.missing.energy_null',
      ),
      (
        baseline.withObservation('portion.zero.leucine_g', 2.0),
        'catalog.candidate_projection.mismatch.portion.zero.leucine_g',
      ),
      (
        baseline.withObservation('basis.per_serving.held', false),
        'catalog.candidate_projection.mismatch.basis.per_serving.held',
      ),
      (
        baseline.withObservation('unit.unknown.held', false),
        'catalog.candidate_projection.mismatch.unit.unknown.held',
      ),
      (
        baseline.withObservation('catalog.meal_missing.energy_null', false),
        'catalog.candidate_projection.mismatch.catalog.meal_missing.energy_null',
      ),
      (
        baseline.withObservation('portion.nan.held', false),
        'catalog.candidate_projection.mismatch.portion.nan.held',
      ),
      (
        baseline.withObservation('source.infinity.held', false),
        'catalog.candidate_projection.mismatch.source.infinity.held',
      ),
      (
        baseline.withoutObservation('portion.half.nutrient_ids'),
        'catalog.candidate_projection.missing.portion.half.nutrient_ids',
      ),
    ];

    for (final mutation in mutations) {
      final report = gate.verify(
        snapshots: snapshots,
        oracleReport: oracle,
        catalogCandidateProjectionProbe: mutation.$1,
      );
      final check = report.checks.singleWhere(
        (entry) =>
            entry.spec.id ==
            'nutrition.catalog_candidate_basis_missingness_and_portion_scaling',
      );
      expect(check.passed, isFalse, reason: mutation.$2);
      expect(check.failureCodes, contains(mutation.$2));
      expect(report.failedCheckCount, 1, reason: mutation.$2);
      expect(
        report.statusFor('catalog_candidate_projection'),
        AlgorithmInvariantCoverageStatus.failed,
      );
      expect(
        report.statusFor('amino_acid_extraction'),
        AlgorithmInvariantCoverageStatus.passed,
      );
    }
  });

  test('a relabelled spec cannot manufacture algorithm coverage', () {
    final relabelled = MechanisticVerificationCheckResult(
      spec: const MechanisticVerificationSpec(
        id: 'synthetic.relabel_attempt',
        probeId: fixedScenarioVerificationProbeId,
        algorithmIds: <String>['legacy_food_recommendations'],
        observable: 'manufactured relabel attempt',
        canonicalUnit: 'none',
        tolerance: 0,
        method: 'must fail before coverage promotion',
        sourceRefs: <String>['src.fda.cms.credibility.guidance'],
      ),
      passed: true,
      observedProbeId: fixedScenarioVerificationProbeId,
      observation: 'A passing label without an authorized production probe.',
      failureCodes: const <String>[],
    );

    expect(relabelled.passed, isFalse);
    expect(relabelled.executedAlgorithmIds, isEmpty);
    expect(
      relabelled.failureCodes,
      contains(
        'verification.probe_algorithm_mismatch.legacy_food_recommendations',
      ),
    );
  });

  test(
    'amino-acid probe binding cannot be relabelled to another algorithm',
    () {
      final relabelled = MechanisticVerificationCheckResult(
        spec: const MechanisticVerificationSpec(
          id: 'synthetic.amino_acid_probe_relabel_attempt',
          probeId: AminoAcidExtractionInvariantProbe.probeId,
          algorithmIds: <String>['legacy_food_recommendations'],
          observable: 'manufactured relabel attempt',
          canonicalUnit: 'none',
          tolerance: 0,
          method: 'must fail before coverage promotion',
          sourceRefs: <String>['src.fdc.api.amino_acid_fields'],
        ),
        passed: true,
        observedProbeId: AminoAcidExtractionInvariantProbe.probeId,
        observation: 'A passing extraction probe with an unauthorized label.',
        failureCodes: const <String>[],
      );

      expect(relabelled.passed, isFalse);
      expect(relabelled.executedAlgorithmIds, isEmpty);
      expect(
        relabelled.failureCodes,
        contains(
          'verification.probe_algorithm_mismatch.legacy_food_recommendations',
        ),
      );
    },
  );

  test('an independent truth-vector mismatch fails the unified gate', () {
    final service = AlgorithmObservatoryService();
    final snapshots = <ObservatoryScenario, AlgorithmObservatorySnapshot>{
      for (final scenario in ObservatoryScenario.values)
        scenario: service.build(scenario),
    };
    const oracle = AlgorithmNumericalVerificationOracle();
    final baseline = oracle.run(service: service);
    final observations = Map<String, double>.from(baseline.observations)
      ..['gastric.remaining_fraction_minute_110'] = -1;
    final mismatch = oracle.verifyObservations(
      observations,
      configurationDigest: baseline.configurationDigest,
    );

    final report = gate.verify(snapshots: snapshots, oracleReport: mismatch);

    expect(report.passed, isFalse);
    expect(report.failedCheckCount, 1);
    expect(
      report.statusFor('gastric_emptying'),
      AlgorithmInvariantCoverageStatus.failed,
    );
    expect(
      report.checks
          .singleWhere(
            (check) => check.spec.id == 'stack.independent_truth_vectors',
          )
          .failureCodes,
      contains('oracle.value_mismatch'),
    );
  });

  test('report exports every algorithm status and its evidence boundary', () {
    final report = gate.run();
    final json = report.toJson(AlgorithmRegistry.all.map((entry) => entry.id));
    final statuses = json['algorithm_status'] as Map<String, String>;

    expect(json['schema'], mechanisticModelVerificationSchema);
    expect(json['schema_version'], mechanisticModelVerificationSchemaVersion);
    expect(statuses, hasLength(AlgorithmRegistry.all.length));
    expect(json['probe_bindings'], hasLength(6));
    final legacyCheck = (json['checks'] as List<dynamic>)
        .cast<Map<String, Object?>>()
        .singleWhere(
          (entry) =>
              ((entry['spec'] as Map<String, Object?>)['id']) ==
              'recommendation.legacy_score_bounds_thresholds_and_order',
        );
    expect(
      legacyCheck['observed_probe_id'],
      LegacyFoodRecommendationInvariantProbe.probeId,
    );
    expect(legacyCheck['executed_algorithm_ids'], <String>[
      'legacy_food_recommendations',
    ]);
    final extractionCheck = (json['checks'] as List<dynamic>)
        .cast<Map<String, Object?>>()
        .singleWhere(
          (entry) =>
              ((entry['spec'] as Map<String, Object?>)['id']) ==
              'nutrition.amino_acid_extraction_units_missingness_and_determinism',
        );
    expect(
      extractionCheck['observed_probe_id'],
      AminoAcidExtractionInvariantProbe.probeId,
    );
    expect(extractionCheck['executed_algorithm_ids'], <String>[
      'amino_acid_extraction',
    ]);
    final projectionCheck = (json['checks'] as List<dynamic>)
        .cast<Map<String, Object?>>()
        .singleWhere(
          (entry) =>
              ((entry['spec'] as Map<String, Object?>)['id']) ==
              'nutrition.catalog_candidate_basis_missingness_and_portion_scaling',
        );
    expect(
      projectionCheck['observed_probe_id'],
      CatalogCandidateProjectionInvariantProbe.probeId,
    );
    expect(projectionCheck['executed_algorithm_ids'], <String>[
      'catalog_candidate_projection',
    ]);
    expect(json['boundary'], contains('does not establish biological'));
    expect(jsonEncode(json), isNot(contains('NaN')));
  });

  test(
    'out-of-scope medication context fails the visible applicability gate',
    () {
      final service = AlgorithmObservatoryService();
      final snapshots = <ObservatoryScenario, AlgorithmObservatorySnapshot>{
        for (final scenario in ObservatoryScenario.values)
          scenario: service.build(scenario),
      };
      final original = snapshots[ObservatoryScenario.mixedReference]!;
      final originalEvent = original.context.medicationEvents.single;
      final context = originalEvent.context;
      final mutatedMedication = NormalizedMedicationContext(
        drugProductVariant: context.drugProductVariant,
        activeIngredients: context.activeIngredients,
        form: context.form,
        route: 'intravenous',
        releaseType: context.releaseType,
        strength: context.strength,
        unit: context.unit,
        jurisdiction: context.jurisdiction,
        sourceDocId: context.sourceDocId,
        labelSection: context.labelSection,
        extractionConfidence: context.extractionConfidence,
        limitationText: context.limitationText,
        metadata: context.metadata,
      );
      final mutatedContext = TimeAxisConflictContext(
        referenceMinute: original.context.referenceMinute,
        medicationEvents: [
          MedicationTimelineEvent(
            id: originalEvent.id,
            minute: originalEvent.minute,
            context: mutatedMedication,
          ),
        ],
        mealEvents: original.context.mealEvents,
        foodComponentEvents: original.context.foodComponentEvents,
        userDefinedWindow: original.context.userDefinedWindow,
        missingFields: original.context.missingFields,
      );
      snapshots[ObservatoryScenario.mixedReference] = _copySnapshot(
        original,
        context: mutatedContext,
      );
      final oracle = const AlgorithmNumericalVerificationOracle().run(
        service: service,
      );

      final report = gate.verify(snapshots: snapshots, oracleReport: oracle);

      expect(report.passed, isFalse);
      expect(
        report.checks
            .singleWhere(
              (check) =>
                  check.spec.id ==
                  'medication.normalization_and_applicability_identity',
            )
            .failureCodes,
        contains('medication.applicability_not_satisfied.mixedReference'),
      );
      expect(
        report.statusFor('runtime_model_applicability_abstention_gate'),
        AlgorithmInvariantCoverageStatus.failed,
      );
    },
  );

  test('cross-scenario configuration drift fails only the identity check', () {
    final service = AlgorithmObservatoryService();
    final snapshots = <ObservatoryScenario, AlgorithmObservatorySnapshot>{
      for (final scenario in ObservatoryScenario.values)
        scenario: service.build(scenario),
    };
    final original = snapshots[ObservatoryScenario.highFatProtein]!;
    snapshots[ObservatoryScenario.highFatProtein] = _copySnapshot(
      original,
      configurationIdentity: AlgorithmConfigurationIdentity.defaults(
        runtimeRules: const [],
      ),
    );
    final oracle = const AlgorithmNumericalVerificationOracle().run(
      service: service,
    );

    final report = gate.verify(snapshots: snapshots, oracleReport: oracle);

    expect(report.passed, isFalse);
    expect(report.configurationDigest, 'inconsistent');
    expect(
      report.checks
          .singleWhere(
            (check) => check.spec.id == 'configuration.cross_scenario_identity',
          )
          .failureCodes,
      contains('verification.configuration_digest_mismatch'),
    );
    expect(
      report.statusFor('algorithm_configuration_identity'),
      AlgorithmInvariantCoverageStatus.failed,
    );
    expect(
      report.statusFor('mechanistic_conflict'),
      AlgorithmInvariantCoverageStatus.passed,
    );
  });

  test(
    'missing modeled structural report fails both visible gastric checks',
    () {
      final service = AlgorithmObservatoryService();
      final snapshots = <ObservatoryScenario, AlgorithmObservatorySnapshot>{
        for (final scenario in ObservatoryScenario.values)
          scenario: service.build(scenario),
      };
      final original = snapshots[ObservatoryScenario.mixedReference]!;
      snapshots[ObservatoryScenario.mixedReference] = _copySnapshot(
        original,
        removeGastricStructuralUncertainty: true,
      );
      final oracle = const AlgorithmNumericalVerificationOracle().run(
        service: service,
      );

      final report = gate.verify(snapshots: snapshots, oracleReport: oracle);

      expect(report.passed, isFalse);
      expect(
        report.checks
            .singleWhere(
              (check) =>
                  check.spec.id ==
                  'gastric.structural_observable_domain_invariants',
            )
            .failureCodes,
        contains('gastric.structural_report_missing.mixedReference'),
      );
      expect(
        report.statusFor('gastric_structural_uncertainty_shadow_ensemble'),
        AlgorithmInvariantCoverageStatus.failed,
      );
    },
  );
}

AlgorithmObservatorySnapshot _copySnapshot(
  AlgorithmObservatorySnapshot source, {
  TimeAxisConflictContext? context,
  AlgorithmConfigurationIdentity? configurationIdentity,
  bool removeGastricStructuralUncertainty = false,
}) => AlgorithmObservatorySnapshot(
  scenario: source.scenario,
  context: context ?? source.context,
  composition: source.composition,
  conflict: source.conflict,
  candidateScores: source.candidateScores,
  gastricParameters: source.gastricParameters,
  configurationIdentity: configurationIdentity ?? source.configurationIdentity,
  explanationTree: source.explanationTree,
  eventLedger: source.eventLedger,
  ledgerAuthorization: source.ledgerAuthorization,
  replayCapsule: source.replayCapsule,
  gastricStructuralUncertainty: removeGastricStructuralUncertainty
      ? null
      : source.gastricStructuralUncertainty,
);

String _describe(MechanisticModelVerificationReport report) => report.checks
    .where((entry) => !entry.passed)
    .map((entry) => '${entry.spec.id}: ${entry.failureCodes.join(', ')}')
    .join('\n');
