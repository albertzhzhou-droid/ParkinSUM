import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../entities/amino_acid_competition.dart';
import '../entities/gastric_structural_uncertainty.dart';
import '../entities/mechanistic_event_ledger.dart';
import '../entities/mechanistic_medication_applicability.dart';
import '../entities/protein_distribution.dart';
import 'algorithm_numerical_verification_oracle.dart';
import 'algorithm_observatory_service.dart';
import 'algorithm_registry.dart';
import 'amino_acid_extraction_invariant_probe.dart';
import 'catalog_candidate_projection_invariant_probe.dart';
import 'dose_input_invariant_probe.dart';
import 'gastric_emptying_model.dart';
import 'gastric_structural_uncertainty_service.dart';
import 'legacy_food_recommendation_invariant_probe.dart';
import 'medication_entry_validator.dart';

const int mechanisticModelVerificationSchemaVersion = 2;
const String mechanisticModelVerificationSchema =
    'parkinsum.mechanistic-model-verification-report/2';

const String fixedScenarioVerificationProbeId =
    'observatory.fixed-scenario-production/1';
const String independentNumericalVerificationProbeId =
    'mechanistic.independent-numerical-oracle/1';

enum AlgorithmInvariantCoverageStatus { passed, failed, notCovered }

/// Closed binding between a black-box production probe and the registered
/// algorithms that probe is permitted to attest. A specification label cannot
/// promote coverage unless the independently selected observed probe binding
/// authorizes the same algorithm IDs.
final class MechanisticVerificationProbeBinding {
  const MechanisticVerificationProbeBinding({
    required this.probeId,
    required this.algorithmIds,
    required this.method,
  });

  final String probeId;
  final List<String> algorithmIds;
  final String method;

  Map<String, Object?> toJson() => <String, Object?>{
    'probe_id': probeId,
    'algorithm_ids': algorithmIds,
    'method': method,
  };
}

/// One independently reviewable engineering invariant.
///
/// The contract names the observable and its unit before any production value
/// is inspected. It deliberately does not assign biological meaning to a
/// passing calculation.
final class MechanisticVerificationSpec {
  const MechanisticVerificationSpec({
    required this.id,
    required this.probeId,
    required this.algorithmIds,
    required this.observable,
    required this.canonicalUnit,
    required this.tolerance,
    required this.method,
    required this.sourceRefs,
  });

  final String id;
  final String probeId;
  final List<String> algorithmIds;
  final String observable;
  final String canonicalUnit;
  final double tolerance;
  final String method;
  final List<String> sourceRefs;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'probe_id': probeId,
    'algorithm_ids': algorithmIds,
    'observable': observable,
    'canonical_unit': canonicalUnit,
    'tolerance': tolerance,
    'method': method,
    'source_refs': sourceRefs,
  };
}

final class MechanisticVerificationCheckResult {
  MechanisticVerificationCheckResult({
    required this.spec,
    required bool passed,
    required this.observedProbeId,
    required this.observation,
    required List<String> failureCodes,
  }) : _calculationPassed = passed,
       _failureCodes = List<String>.unmodifiable(failureCodes);

  final MechanisticVerificationSpec spec;
  final bool _calculationPassed;
  final String observedProbeId;
  final String observation;
  final List<String> _failureCodes;

  List<String> get integrityFailureCodes {
    final failures = <String>[];
    if (observedProbeId != spec.probeId) {
      failures.add('verification.probe_id_mismatch');
    }
    final binding = MechanisticModelVerificationGate.bindingFor(
      observedProbeId,
    );
    if (binding == null) {
      failures.add('verification.unknown_probe_binding');
    }
    final claimed = spec.algorithmIds.toSet();
    if (claimed.length != spec.algorithmIds.length) {
      failures.add('verification.duplicate_algorithm_claim');
    }
    for (final algorithmId in claimed) {
      if (AlgorithmRegistry.byId(algorithmId) == null) {
        failures.add('verification.unknown_algorithm_claim.$algorithmId');
      }
      if (binding != null && !binding.algorithmIds.contains(algorithmId)) {
        failures.add('verification.probe_algorithm_mismatch.$algorithmId');
      }
    }
    return List<String>.unmodifiable(failures.toSet().toList()..sort());
  }

  Set<String> get executedAlgorithmIds => integrityFailureCodes.isEmpty
      ? Set<String>.unmodifiable(spec.algorithmIds)
      : const <String>{};

  bool get passed => _calculationPassed && integrityFailureCodes.isEmpty;

  List<String> get failureCodes => List<String>.unmodifiable(
    <String>{..._failureCodes, ...integrityFailureCodes}.toList()..sort(),
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'spec': spec.toJson(),
    'observed_probe_id': observedProbeId,
    'executed_algorithm_ids': executedAlgorithmIds.toList(growable: false)
      ..sort(),
    'passed': passed,
    'observation': observation,
    'failure_codes': failureCodes,
  };
}

final class MechanisticModelVerificationReport {
  MechanisticModelVerificationReport({
    required this.specificationDigest,
    required this.configurationDigest,
    required List<MechanisticVerificationCheckResult> checks,
    required List<String> scenarioIds,
  }) : checks = List<MechanisticVerificationCheckResult>.unmodifiable(checks),
       scenarioIds = List<String>.unmodifiable(scenarioIds);

  final String specificationDigest;
  final String configurationDigest;
  final List<MechanisticVerificationCheckResult> checks;
  final List<String> scenarioIds;

  static const String boundary =
      'Deterministic implementation and calculation verification for declared '
      'synthetic observables only. Passing does not establish biological '
      'validity, clinical accuracy, patient benefit, or medical advice.';

  int get passedCheckCount => checks.where((entry) => entry.passed).length;
  int get failedCheckCount => checks.length - passedCheckCount;
  bool get passed => failedCheckCount == 0;

  Set<String> get coveredAlgorithmIds => Set<String>.unmodifiable(
    checks.expand((entry) => entry.executedAlgorithmIds),
  );

  AlgorithmInvariantCoverageStatus statusFor(String algorithmId) {
    final relevant = checks
        .where((entry) => entry.executedAlgorithmIds.contains(algorithmId))
        .toList(growable: false);
    if (relevant.isEmpty) return AlgorithmInvariantCoverageStatus.notCovered;
    return relevant.every((entry) => entry.passed)
        ? AlgorithmInvariantCoverageStatus.passed
        : AlgorithmInvariantCoverageStatus.failed;
  }

  Map<String, Object?> toJson(Iterable<String> registeredAlgorithmIds) {
    final ids = registeredAlgorithmIds.toSet().toList(growable: false)..sort();
    return <String, Object?>{
      'schema': mechanisticModelVerificationSchema,
      'schema_version': mechanisticModelVerificationSchemaVersion,
      'specification_digest': specificationDigest,
      'configuration_digest': configurationDigest,
      'boundary': boundary,
      'scenario_ids': scenarioIds,
      'passed_check_count': passedCheckCount,
      'failed_check_count': failedCheckCount,
      'probe_bindings': MechanisticModelVerificationGate.probeBindings
          .map((entry) => entry.toJson())
          .toList(growable: false),
      'algorithm_status': <String, String>{
        for (final id in ids) id: statusFor(id).name,
      },
      'checks': checks.map((entry) => entry.toJson()).toList(growable: false),
    };
  }
}

/// Production-facing mathematical invariant and unit gate.
///
/// This reads fixed synthetic outputs from the same production providers used
/// by the Observatory. It does not participate in scoring or recommendations.
final class MechanisticModelVerificationGate {
  const MechanisticModelVerificationGate();

  static const List<MechanisticVerificationProbeBinding>
  probeBindings = <MechanisticVerificationProbeBinding>[
    MechanisticVerificationProbeBinding(
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>[
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
      ],
      method:
          'Three fixed synthetic snapshots produced through the Observatory production component graph.',
    ),
    MechanisticVerificationProbeBinding(
      probeId: independentNumericalVerificationProbeId,
      algorithmIds: <String>[
        'meal_composition_normalizer',
        'gastric_emptying',
        'levodopa_absorption_opportunity',
        'amino_acid_competition',
        'mechanistic_conflict',
        'mechanistic_candidate_scorer',
      ],
      method:
          'Separately authored manufactured truth vectors over production observations.',
    ),
    MechanisticVerificationProbeBinding(
      probeId: DoseInputInvariantProbe.probeId,
      algorithmIds: <String>[
        'dosage_note_parser',
        'intake_dose_context',
        'package_dose_calculator',
        'metadata_completeness_gate',
        'input_quality_gate',
        'administration_dose_confirmation_reconciliation',
        'medication_assertion_source_temporal_reconciliation',
      ],
      method:
          'Manufactured observations captured by direct dose-input production API calls.',
    ),
    MechanisticVerificationProbeBinding(
      probeId: LegacyFoodRecommendationInvariantProbe.probeId,
      algorithmIds: <String>['legacy_food_recommendations'],
      method:
          'Manufactured score, threshold, bound, top-five, and permutation observations from the production scorer.',
    ),
    MechanisticVerificationProbeBinding(
      probeId: AminoAcidExtractionInvariantProbe.probeId,
      algorithmIds: <String>['amino_acid_extraction'],
      method:
          'Manufactured FDC-shaped unit, missingness, invalid-domain, duplicate, identity, and ordering observations from the production extractor.',
    ),
    MechanisticVerificationProbeBinding(
      probeId: CatalogCandidateProjectionInvariantProbe.probeId,
      algorithmIds: <String>['catalog_candidate_projection'],
      method:
          'Manufactured catalog and meal records projected through the production candidate adapters.',
    ),
  ];

  static MechanisticVerificationProbeBinding? bindingFor(String probeId) {
    for (final binding in probeBindings) {
      if (binding.probeId == probeId) return binding;
    }
    return null;
  }

  static const List<MechanisticVerificationSpec>
  specifications = <MechanisticVerificationSpec>[
    MechanisticVerificationSpec(
      id: 'normalizer.missingness_and_bounds',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>['meal_composition_normalizer'],
      observable: 'normalized nutrient values and explicit missingness',
      canonicalUnit: 'kcal | g | fraction',
      tolerance: 1e-12,
      method: 'three-scenario structural and finite-range metamorphic check',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'ledger.dimension_and_unit_identity',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>[
        'meal_composition_normalizer',
        'time_axis_builder',
      ],
      observable: 'event measurements and dimensionally equivalent values',
      canonicalUnit: 'mg | kcal | min | fraction',
      tolerance: 1e-12,
      method: 'closed-dimension canonical-unit and conversion identity check',
      sourceRefs: <String>['src.bipm.si-brochure.9', 'src.ucum.specification'],
    ),
    MechanisticVerificationSpec(
      id: 'gastric.normalized_mass_and_monotonicity',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>['gastric_emptying'],
      observable: 'normalized gastric retention and emptied complement',
      canonicalUnit: 'fraction',
      tolerance: 1e-10,
      method: 'one-minute grid over 0..1440 min',
      sourceRefs: <String>[
        'src.hou.gastric.modelcomparison.2010',
        'src.burmen.gastric.pellets.2009',
      ],
    ),
    MechanisticVerificationSpec(
      id: 'gastric.arrival_rate_integration',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>['gastric_emptying'],
      observable: 'intestinal arrival rate integral versus emptied mass',
      canonicalUnit: 'fraction/min and fraction',
      tolerance: 0.01,
      method: 'discrete one-minute quadrature over 0..1440 min',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'gastric.sensitivity_envelope_order',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>['gastric_emptying'],
      observable: 'faster, central, and slower retention curves',
      canonicalUnit: 'fraction',
      tolerance: 1e-10,
      method: 'ordered structural sensitivity envelope on one-minute grid',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'absorption.openness_structure_and_bounds',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>['levodopa_absorption_opportunity'],
      observable: 'small-intestinal opportunity openness trace',
      canonicalUnit: 'unitless proxy',
      tolerance: 1e-12,
      method: 'sample ordering, range, window, peak, and abstention check',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'competition.pressure_threshold_identity',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>['amino_acid_competition'],
      observable: 'LNAA pressure, overlap, and ordinal band',
      canonicalUnit: 'unitless proxy',
      tolerance: 1e-12,
      method: 'sample/peak bounds and exact production band identity',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'conflict_and_candidate.output_coherence',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>[
        'mechanistic_conflict',
        'mechanistic_candidate_scorer',
      ],
      observable: 'conflict and candidate score structures',
      canonicalUnit: 'unitless ordinal score',
      tolerance: 1e-9,
      method: 'bounded output and internal structural-coherence check',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'stack.unknown_is_not_zero',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>[
        'meal_composition_normalizer',
        'gastric_emptying',
        'levodopa_absorption_opportunity',
        'amino_acid_competition',
        'mechanistic_conflict',
      ],
      observable: 'incomplete primary-conflict abstention shape',
      canonicalUnit: 'typed missing state',
      tolerance: 0,
      method: 'fixed incomplete scenario fail-closed check',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'stack.independent_truth_vectors',
      probeId: independentNumericalVerificationProbeId,
      algorithmIds: <String>[
        'meal_composition_normalizer',
        'gastric_emptying',
        'levodopa_absorption_opportunity',
        'amino_acid_competition',
        'mechanistic_conflict',
        'mechanistic_candidate_scorer',
      ],
      observable: '19 separately authored manufactured truth vectors',
      canonicalUnit: 'declared per vector',
      tolerance: 0,
      method: 'independent analytic vector comparison',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'medication.normalization_and_applicability_identity',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>[
        'medication_entry_validator',
        'runtime_model_applicability_abstention_gate',
      ],
      observable:
          'normalized medication identity and model-applicability predicates',
      canonicalUnit: 'coded medication context',
      tolerance: 0,
      method:
          'validator round trip plus exact four-predicate applicability check',
      sourceRefs: <String>[
        'src.fda.spl.standard',
        'src.hl7.fhir.r5',
        'src.fda.cms.credibility.guidance',
      ],
    ),
    MechanisticVerificationSpec(
      id: 'protein.redistribution_structure_and_bounds',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>['protein_distribution'],
      observable:
          'candidate protein-redistribution and nutrition-adequacy trace',
      canonicalUnit: 'unitless proxy',
      tolerance: 1e-9,
      method: 'modeled-output presence, range, identity, and abstention check',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'configuration.cross_scenario_identity',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>['algorithm_configuration_identity'],
      observable:
          'canonical configuration, source bundle, and parameter provenance identity',
      canonicalUnit: 'SHA-256 content identity',
      tolerance: 0,
      method:
          'cross-scenario digest equality and embedded-manifest consistency check',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'gastric.structural_observable_domain_invariants',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>['gastric_structural_uncertainty_shadow_ensemble'],
      observable:
          'normalized tracer retention, absolute MRI volume, and pellet retention as separate measurement domains',
      canonicalUnit: 'fraction | mL | fraction',
      tolerance: 1e-10,
      method:
          'all six declared structures on a 10-minute grid with observable-specific bounds and monotonicity',
      sourceRefs: <String>[
        'src.tougas.gastric.scintigraphy.2000',
        'src.bertoli.gastric.linearexp.2023',
        'src.burmen.gastric.pellets.2009',
      ],
    ),
    MechanisticVerificationSpec(
      id: 'gastric.structural_fit_authority_and_production_isolation',
      probeId: fixedScenarioVerificationProbeId,
      algorithmIds: <String>['gastric_structural_uncertainty_shadow_ensemble'],
      observable:
          'fit authorization, production-output identity, and held-domain numeric absence',
      canonicalUnit: 'typed authorization state | SHA-256',
      tolerance: 0,
      method:
          'synthetic circularity, observable-match, production digest, and held-trajectory fail-closed check',
      sourceRefs: <String>[
        'src.ogungbenro.gastric.identifiability.2011',
        'src.raue.profilelikelihood.2009',
        'src.fda.cms.credibility.guidance',
      ],
    ),
    MechanisticVerificationSpec(
      id: 'dose.typed_expression_and_intake_separation',
      probeId: DoseInputInvariantProbe.probeId,
      algorithmIds: <String>['dosage_note_parser', 'intake_dose_context'],
      observable:
          'typed administration-dose quantity, canonical dimension, and intake-bound formulation context',
      canonicalUnit: 'mg | g | mcg | mL | typed missing state',
      tolerance: 1e-12,
      method:
          'black-box exact-value, unit-equivalence, ambiguity, and package-context separation vectors',
      sourceRefs: <String>[
        'src.hl7.fhir.r5',
        'src.ucum.specification',
        'src.bipm.si-brochure.9',
      ],
    ),
    MechanisticVerificationSpec(
      id: 'dose.package_strength_multiplication_and_bounds',
      probeId: DoseInputInvariantProbe.probeId,
      algorithmIds: <String>['package_dose_calculator'],
      observable:
          'ingredient amount derived from an explicitly confirmed package-unit quantity',
      canonicalUnit: 'declared ingredient mass unit | package unit',
      tolerance: 1e-12,
      method:
          'combination-pack identity, multiplication, ratio hold, finite-domain, overflow, and quantity-bound vectors',
      sourceRefs: <String>['src.hl7.fhir.r5', 'src.ucum.specification'],
    ),
    MechanisticVerificationSpec(
      id: 'dose.metadata_completeness_numeric_domain',
      probeId: DoseInputInvariantProbe.probeId,
      algorithmIds: <String>['metadata_completeness_gate'],
      observable:
          'dose-metadata completeness state and monotone bounded scoring weight',
      canonicalUnit: 'ordinal completeness state | fraction',
      tolerance: 1e-12,
      method:
          'complete, missing-unit, non-finite, non-positive, and ordinal-weight vectors',
      sourceRefs: <String>['src.hl7.fhir.r5', 'src.ucum.specification'],
    ),
    MechanisticVerificationSpec(
      id: 'dose.input_quality_fail_closed_separation',
      probeId: DoseInputInvariantProbe.probeId,
      algorithmIds: <String>['input_quality_gate'],
      observable:
          'dose-input eligibility, blocker identity, and product-strength versus administration-dose separation',
      canonicalUnit: 'typed eligibility and blocker state',
      tolerance: 0,
      method:
          'non-finite administration value and product-metadata-only fail-closed vectors',
      sourceRefs: <String>['src.hl7.fhir.r5', 'src.ucum.specification'],
    ),
    MechanisticVerificationSpec(
      id: 'dose.confirmation_assertion_and_as_of_result_gate',
      probeId: DoseInputInvariantProbe.probeId,
      algorithmIds: <String>[
        'administration_dose_confirmation_reconciliation',
        'medication_assertion_source_temporal_reconciliation',
      ],
      observable:
          'confirmation receipt, assertion graph, and as-of eligibility for result-affecting administration dose',
      canonicalUnit: 'typed eligibility | mg | g | mL | typed missing state',
      tolerance: 1e-12,
      method:
          'unconfirmed, exact 100 mg, conflicting assertion, future evidence, mass conversion, and volume-without-concentration mass-projection hold vectors',
      sourceRefs: <String>['src.hl7.fhir.r5', 'src.ucum.specification'],
    ),
    MechanisticVerificationSpec(
      id: 'recommendation.legacy_score_bounds_thresholds_and_order',
      probeId: LegacyFoodRecommendationInvariantProbe.probeId,
      algorithmIds: <String>['legacy_food_recommendations'],
      observable:
          'bounded heuristic score, threshold neighborhoods, descending top-five order, and input-permutation identity',
      canonicalUnit: '0..100 heuristic ranking points | ordered food ids',
      tolerance: 1e-12,
      method:
          'black-box exact-value, threshold-neighborhood, bound, ordering, and permutation vectors',
      sourceRefs: <String>['src.fda.cms.credibility.guidance'],
    ),
    MechanisticVerificationSpec(
      id: 'nutrition.amino_acid_extraction_units_missingness_and_determinism',
      probeId: AminoAcidExtractionInvariantProbe.probeId,
      algorithmIds: <String>['amino_acid_extraction'],
      observable:
          'canonical amino-acid grams, explicit missingness, invalid and duplicate hold state, nutrient identity, and permutation-stable output',
      canonicalUnit: 'g per declared basis | typed missing state',
      tolerance: 1e-12,
      method:
          'black-box g/mg equivalence, zero-versus-missing, fail-closed domain, duplicate-permutation, nutrient-number priority, and canonical-order vectors',
      sourceRefs: <String>[
        'src.fdc.api.amino_acid_fields',
        'src.ucum.specification',
        'src.bipm.si-brochure.9',
      ],
    ),
    MechanisticVerificationSpec(
      id: 'nutrition.catalog_candidate_basis_missingness_and_portion_scaling',
      probeId: CatalogCandidateProjectionInvariantProbe.probeId,
      algorithmIds: <String>['catalog_candidate_projection'],
      observable:
          'candidate nutrient missingness and amino-acid amount projected from a declared per-100g basis to logged serving grams',
      canonicalUnit: 'g | kcal | typed missing state | declared basis',
      tolerance: 1e-12,
      method:
          'black-box missing-marker precedence, true-zero, 100g-to-serving scaling, incompatible-basis, invalid-portion, and invalid-source vectors',
      sourceRefs: <String>[
        'src.fdc.foundation.nutrient-and-portion-basis',
        'src.fdc.branded.100-unit-and-missingness',
        'src.bipm.si-brochure.9',
      ],
    ),
  ];

  static final String specificationDigest = sha256
      .convert(
        utf8.encode(
          _canonicalJson(<String, Object?>{
            'schema': mechanisticModelVerificationSchema,
            'schema_version': mechanisticModelVerificationSchemaVersion,
            'probe_bindings': probeBindings
                .map((entry) => entry.toJson())
                .toList(growable: false),
            'specifications': specifications
                .map((entry) => entry.toJson())
                .toList(growable: false),
          }),
        ),
      )
      .toString();

  MechanisticModelVerificationReport run({
    AlgorithmObservatoryService? service,
    DoseInputInvariantProbe? doseInputProbe,
    LegacyFoodRecommendationInvariantProbe? legacyRecommendationProbe,
    AminoAcidExtractionInvariantProbe? aminoAcidExtractionProbe,
    CatalogCandidateProjectionInvariantProbe? catalogCandidateProjectionProbe,
  }) {
    final resolved = service ?? AlgorithmObservatoryService();
    final snapshots = <ObservatoryScenario, AlgorithmObservatorySnapshot>{
      for (final scenario in ObservatoryScenario.values)
        scenario: resolved.build(scenario),
    };
    final oracle = const AlgorithmNumericalVerificationOracle().run(
      service: resolved,
    );
    return verify(
      snapshots: snapshots,
      oracleReport: oracle,
      doseInputProbe: doseInputProbe,
      legacyRecommendationProbe: legacyRecommendationProbe,
      aminoAcidExtractionProbe: aminoAcidExtractionProbe,
      catalogCandidateProjectionProbe: catalogCandidateProjectionProbe,
    );
  }

  MechanisticModelVerificationReport verify({
    required Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
    required AlgorithmNumericalOracleReport oracleReport,
    DoseInputInvariantProbe? doseInputProbe,
    LegacyFoodRecommendationInvariantProbe? legacyRecommendationProbe,
    AminoAcidExtractionInvariantProbe? aminoAcidExtractionProbe,
    CatalogCandidateProjectionInvariantProbe? catalogCandidateProjectionProbe,
  }) {
    final resolvedDoseInputProbe =
        doseInputProbe ?? DoseInputInvariantProbe.capture();
    final resolvedLegacyRecommendationProbe =
        legacyRecommendationProbe ??
        LegacyFoodRecommendationInvariantProbe.capture();
    final resolvedAminoAcidExtractionProbe =
        aminoAcidExtractionProbe ?? AminoAcidExtractionInvariantProbe.capture();
    final resolvedCatalogCandidateProjectionProbe =
        catalogCandidateProjectionProbe ??
        CatalogCandidateProjectionInvariantProbe.capture();
    final checks = <MechanisticVerificationCheckResult>[
      _result(
        specifications[0],
        _normalizerViolations(snapshots),
        'Known synthetic nutrients stay finite and incomplete fields remain missing.',
      ),
      _result(
        specifications[1],
        _unitViolations(snapshots),
        'All known ledger values use their declared canonical dimension and unit.',
      ),
      _result(
        specifications[2],
        _gastricCurveViolations(snapshots),
        'Retention is finite, bounded, monotone, normalized, and mass-complementary.',
      ),
      _result(
        specifications[3],
        _gastricArrivalViolations(snapshots),
        'Arrival-rate quadrature agrees with cumulative emptied fraction within 0.01.',
      ),
      _result(
        specifications[4],
        _gastricEnvelopeViolations(snapshots),
        'Faster retention stays below central, which stays below slower retention.',
      ),
      _result(
        specifications[5],
        _absorptionViolations(snapshots),
        'Openness traces are finite, bounded, ordered, peak-consistent, or explicitly absent.',
      ),
      _result(
        specifications[6],
        _competitionViolations(snapshots),
        'Pressure traces, overlap, peak, and the ordinal band remain coherent.',
      ),
      _result(
        specifications[7],
        _compositeViolations(snapshots),
        'Conflict and candidate outputs remain finite, bounded, and internally coherent.',
      ),
      _result(
        specifications[8],
        _abstentionViolations(snapshots),
        'The incomplete scenario exposes typed missingness and no modeled numeric output.',
      ),
      _result(
        specifications[9],
        _oracleViolations(oracleReport),
        '${oracleReport.passedCaseCount} of ${oracleReport.cases.length} independent vectors passed.',
      ),
      _result(
        specifications[10],
        _medicationApplicabilityViolations(snapshots),
        'Validated medication contexts round-trip and remain inside the exact declared applicability manifest.',
      ),
      _result(
        specifications[11],
        _proteinDistributionViolations(snapshots),
        'Modeled protein-distribution traces stay present, bounded, identity-consistent, and absent on abstention.',
      ),
      _result(
        specifications[12],
        _configurationIdentityViolations(snapshots),
        'All scenarios bind one canonical configuration, source bundle, parameter manifest, and gastric parameter set.',
      ),
      _result(
        specifications[13],
        _gastricStructuralObservableViolations(snapshots),
        'All six shadow equations satisfy the invariant declared for their own measured observable without cross-modality conflation.',
      ),
      _result(
        specifications[14],
        _gastricStructuralAuthorityViolations(snapshots),
        'Synthetic production-derived observations remain fit-ineligible, held domains emit no curve, and production output identity is unchanged.',
      ),
      _result(
        specifications[15],
        _doseExpressionAndContextViolations(resolvedDoseInputProbe),
        'Mass units convert only within the declared dimension, ambiguous expressions remain held, and package selection never invents formulation context.',
      ),
      _result(
        specifications[16],
        _packageDoseViolations(resolvedDoseInputProbe),
        'A confirmed half package unit produces the exact declared levodopa component amount while invalid metadata, ratios, overflow, and out-of-range quantities remain held.',
      ),
      _result(
        specifications[17],
        _metadataCompletenessViolations(resolvedDoseInputProbe),
        'Complete metadata is distinct from missing, non-finite, and non-positive strength, and ordinal weights remain bounded and monotone.',
      ),
      _result(
        specifications[18],
        _inputQualityDoseViolations(resolvedDoseInputProbe),
        'Non-finite values and package-strength-only context produce explicit dose blockers and never become mechanistic-primary eligible.',
      ),
      _result(
        specifications[19],
        _resultUseDoseViolations(resolvedDoseInputProbe),
        'Only an as-of-valid confirmation with one conflict-free local assertion can publish a typed administration dose; future evidence and dose disagreement remain held, and volume never becomes mass without concentration.',
      ),
      _result(
        specifications[20],
        _legacyRecommendationViolations(resolvedLegacyRecommendationProbe),
        'The production legacy scorer matches exact manufactured points, changes only at declared protein thresholds, clamps an otherwise 101.09-point case to 100, returns a descending top five, and is invariant to non-tied input order.',
      ),
      _result(
        specifications[21],
        _aminoAcidExtractionViolations(resolvedAminoAcidExtractionProbe),
        'The production extractor normalizes g and mg, preserves zero versus missing, holds ambiguous or invalid values and duplicate conflicts, prioritizes nutrient numbers, and emits canonical metadata and nutrient order.',
      ),
      _result(
        specifications[22],
        _catalogCandidateProjectionViolations(
          resolvedCatalogCandidateProjectionProbe,
        ),
        'The production catalog projection gives explicit missing markers precedence, scales per-100g amino-acid values by logged serving grams, preserves true zero, and holds unrelated bases or invalid inputs.',
      ),
    ];
    final scenarioIds = snapshots.keys.map((entry) => entry.name).toList()
      ..sort();
    final configurationDigests = snapshots.values
        .map((entry) => entry.configurationIdentity.sha256Digest)
        .toSet();
    final configurationDigest = configurationDigests.length == 1
        ? configurationDigests.single
        : 'inconsistent';
    return MechanisticModelVerificationReport(
      specificationDigest: specificationDigest,
      configurationDigest: configurationDigest,
      checks: checks,
      scenarioIds: scenarioIds,
    );
  }
}

List<String> _doseExpressionAndContextViolations(
  DoseInputInvariantProbe probe,
) => _probeViolations(
  probe.observations,
  'dose.expression',
  const <String, Object?>{
    'probe.version': 1,
    'parser.gram.status': 'accepted',
    'parser.gram.raw_preserved': true,
    'parser.gram.normalized_text': '1 g',
    'parser.gram.unit': 'g',
    'parser.gram.dimension': 'mass',
    'parser.gram.milligrams': 1000.0,
    'parser.microgram.status': 'accepted',
    'parser.microgram.unit': 'mcg',
    'parser.microgram.milligrams': 1.0,
    'parser.volume.status': 'accepted',
    'parser.volume.unit': 'mL',
    'parser.volume.dimension': 'volume',
    'parser.volume.milligrams': null,
    'parser.range.reason': 'dose.range_not_supported',
    'parser.ratio.reason': 'dose.combination_or_ratio',
    'parser.rate.reason': 'dose.rate_not_supported',
    'parser.scientific.reason': 'dose.scientific_notation',
    'parser.comma.reason': 'dose.locale_decimal_ambiguous',
    'parser.leading_decimal.reason': 'dose.leading_decimal_not_supported',
    'parser.unicode_minus.reason': 'dose.signed_value',
    'parser.zero.reason': 'dose.value_invalid',
    'builder.explicit.note': '100 milligrams',
    'builder.explicit.amount': 100.0,
    'builder.explicit.unit': 'mg',
    'builder.explicit.form': 'tablet',
    'builder.explicit.route': 'oral',
    'builder.explicit.release': 'immediate',
    'builder.ambiguous.amount': null,
    'builder.ambiguous.unit': null,
    'builder.selected_package.form': 'unspecified',
    'builder.selected_package.route': 'unspecified',
    'builder.selected_package.release': 'unspecified',
  },
);

List<String> _packageDoseViolations(DoseInputInvariantProbe probe) =>
    _probeViolations(
      probe.observations,
      'dose.package',
      const <String, Object?>{
        'package.half.ingredient': 'LEVODOPA',
        'package.half.amount': 50.0,
        'package.half.unit': 'mg',
        'package.half.quantity': 0.5,
        'package.half.label': 'TABLET',
        'package.unrelated_multi_ingredient_rejected': true,
        'package.negative_strength_rejected': true,
        'package.nan_strength_rejected': true,
        'package.infinite_strength_rejected': true,
        'package.overflow_rejected': true,
        'package.ratio_strength_rejected': true,
        'package.zero_quantity_rejected': true,
        'package.excess_quantity_rejected': true,
      },
    );

List<String> _metadataCompletenessViolations(DoseInputInvariantProbe probe) =>
    _probeViolations(
      probe.observations,
      'dose.metadata',
      const <String, Object?>{
        'metadata.complete.status': 'complete',
        'metadata.missing_unit.status': 'insufficient',
        'metadata.nonfinite.status': 'insufficient',
        'metadata.nonpositive.status': 'insufficient',
        'metadata.weights': <double>[1.0, 0.8, 0.5, 0.25, 0.0],
      },
    );

List<String> _inputQualityDoseViolations(DoseInputInvariantProbe probe) =>
    _probeViolations(
      probe.observations,
      'dose.input_quality',
      const <String, Object?>{
        'input_quality.nonfinite.status': 'invalid',
        'input_quality.nonfinite.has_blocker': true,
        'input_quality.nonfinite.eligible': false,
        'input_quality.package_only.status': 'insufficient',
        'input_quality.package_only.has_blocker': true,
        'input_quality.package_only.eligible': false,
      },
    );

List<String> _resultUseDoseViolations(DoseInputInvariantProbe probe) =>
    _probeViolations(
      probe.observations,
      'dose.result_gate',
      const <String, Object?>{
        'result_gate.unconfirmed.confirmation_status': 'absent',
        'result_gate.unconfirmed.assertion_eligible': false,
        'result_gate.unconfirmed.eligible': false,
        'result_gate.unconfirmed.value': null,
        'result_gate.unconfirmed.has_absent_reason': true,
        'result_gate.unconfirmed.has_local_receipt_reason': true,
        'result_gate.confirmed.confirmation_status': 'confirmed',
        'result_gate.confirmed.assertion_eligible': true,
        'result_gate.confirmed.eligible': true,
        'result_gate.confirmed.value': 100.0,
        'result_gate.confirmed.unit': 'mg',
        'result_gate.confirmed.milligrams': 100.0,
        'result_gate.confirmed.reason_count': 0,
        'result_gate.conflict.assertion_eligible': false,
        'result_gate.conflict.has_unresolved_graph': true,
        'result_gate.conflict.eligible': false,
        'result_gate.conflict.value': null,
        'result_gate.conflict.has_unresolved_reason': true,
        'result_gate.future.eligible': false,
        'result_gate.future.value': null,
        'result_gate.future.has_future_confirmation_reason': true,
        'result_gate.future.has_future_evidence_reason': true,
        'result_gate.mass.eligible': true,
        'result_gate.mass.value': 0.5,
        'result_gate.mass.unit': 'g',
        'result_gate.mass.milligrams': 500.0,
        'result_gate.volume.eligible': true,
        'result_gate.volume.value': 5.0,
        'result_gate.volume.unit': 'mL',
        'result_gate.volume.milligrams': null,
      },
    );

List<String> _legacyRecommendationViolations(
  LegacyFoodRecommendationInvariantProbe probe,
) => _probeViolations(
  probe.observations,
  'recommendation.legacy',
  const <String, Object?>{
    'probe.version': 1,
    'probe.invocation_count': 10,
    'baseline.score': 95.25,
    'baseline.unbounded_score': 95.25,
    'baseline.bound_applied': false,
    'baseline.decision': 'ALLOW',
    'threshold.14_999.score': 87.55,
    'threshold.14_999.safety': 0.95,
    'threshold.14_999.schedule': 0.82,
    'threshold.14_999.timing_sensitivity': 0.35,
    'threshold.14_999.decision': 'ALLOW',
    'threshold.15_0.score': 74.15,
    'threshold.15_0.safety': 0.65,
    'threshold.15_0.schedule': 0.82,
    'threshold.15_0.timing_sensitivity': 0.7,
    'threshold.15_0.decision': 'ALLOW',
    'threshold.19_999.score': 74.15,
    'threshold.19_999.safety': 0.65,
    'threshold.19_999.schedule': 0.82,
    'threshold.19_999.timing_sensitivity': 0.7,
    'threshold.19_999.decision': 'ALLOW',
    'threshold.20_0.score': 68.15,
    'threshold.20_0.safety': 0.65,
    'threshold.20_0.schedule': 0.5,
    'threshold.20_0.timing_sensitivity': 1.0,
    'threshold.20_0.decision': 'WARN',
    'threshold.24_999.score': 68.15,
    'threshold.24_999.safety': 0.65,
    'threshold.24_999.schedule': 0.5,
    'threshold.24_999.timing_sensitivity': 1.0,
    'threshold.24_999.decision': 'WARN',
    'threshold.25_0.score': 58.15,
    'threshold.25_0.safety': 0.4,
    'threshold.25_0.schedule': 0.5,
    'threshold.25_0.timing_sensitivity': 1.0,
    'threshold.25_0.decision': 'WARN',
    'bounds.unbounded_score': 101.09,
    'bounds.score': 100.0,
    'bounds.bound_applied': true,
    'ranking.count': 5,
    'ranking.descending': true,
    'ranking.permutation_invariant': true,
    'ranking.unique': true,
    'scores.finite_and_bounded': true,
  },
);

List<String> _aminoAcidExtractionViolations(
  AminoAcidExtractionInvariantProbe probe,
) => _probeViolations(
  probe.observations,
  'amino_acid.extraction',
  const <String, Object?>{
    'probe.version': 1,
    'probe.invocation_count': 12,
    'units.grams.leucine_g': 2.1,
    'units.milligrams.leucine_g': 2.1,
    'units.equivalent': true,
    'units.canonical_unit': 'g',
    'zero.profile_present': true,
    'zero.leucine_g': 0.0,
    'missing.profile_absent': true,
    'unit.missing.held': true,
    'unit.missing.partial': true,
    'unit.missing.competing_g': 0.3,
    'unit.unknown.held': true,
    'unit.unknown.partial': true,
    'unit.unknown.competing_g': 0.3,
    'invalid.profile_partial': true,
    'invalid.negative.held': true,
    'invalid.nan.held': true,
    'invalid.infinity.held': true,
    'invalid.non_numeric.held': true,
    'invalid.competing_g': 0.3,
    'held_only.profile_present': true,
    'held_only.field_null': true,
    'held_only.partial': true,
    'held_only.competing_g': null,
    'duplicate.forward.held': true,
    'duplicate.reverse.held': true,
    'duplicate.profile_partial': true,
    'duplicate.permutation_stable': true,
    'identity.number_priority.leucine_g': 2.0,
    'identity.number_priority.valine_missing': true,
    'ordering.nutrient_ids': <String>['501', '503', '504', '508', '509', '510'],
    'metadata.basis': 'per_100g',
    'metadata.data_type': 'Foundation',
  },
);

List<String> _catalogCandidateProjectionViolations(
  CatalogCandidateProjectionInvariantProbe probe,
) => _probeViolations(
  probe.observations,
  'catalog.candidate_projection',
  const <String, Object?>{
    'probe.version': 1,
    'probe.invocation_count': 14,
    'catalog.missing.protein_null': true,
    'catalog.missing.carbs_null': true,
    'catalog.missing.fat_null': true,
    'catalog.missing.fiber_null': true,
    'catalog.missing.energy_null': true,
    'catalog.zero.protein_g': 0.0,
    'catalog.zero.energy_kcal': 0.0,
    'catalog.zero.source_ref': 'USDA_FDC',
    'portion.half.grams': 50.0,
    'portion.half.protein_g': 10.0,
    'portion.half.basis': 'per_serving',
    'portion.half.leucine_g': 1.0,
    'portion.half.competing_lnaa_g': 3.05,
    'portion.half.nutrient_ids': <String>[
      '501',
      '503',
      '504',
      '508',
      '509',
      '510',
    ],
    'portion.half.source_refs': <String>['FDC:synthetic'],
    'portion.zero.profile_present': true,
    'portion.zero.basis': 'per_serving',
    'portion.zero.leucine_g': 0.0,
    'portion.zero.competing_lnaa_g': 0.0,
    'catalog.meal_missing.energy_null': true,
    'basis.per_serving.held': true,
    'basis.unknown.held': true,
    'unit.unknown.held': true,
    'portion.negative.held': true,
    'portion.nan.held': true,
    'portion.infinity.held': true,
    'source.negative.held': true,
    'source.nan.held': true,
    'source.infinity.held': true,
  },
);

List<String> _probeViolations(
  Map<String, Object?> observations,
  String failurePrefix,
  Map<String, Object?> expected,
) {
  final failures = <String>[];
  for (final entry in expected.entries) {
    if (!observations.containsKey(entry.key)) {
      failures.add('$failurePrefix.missing.${entry.key}');
      continue;
    }
    final actual = observations[entry.key];
    final target = entry.value;
    if (actual is num && target is num) {
      if (!actual.isFinite ||
          (actual.toDouble() - target.toDouble()).abs() > 1e-12) {
        failures.add('$failurePrefix.mismatch.${entry.key}');
      }
      continue;
    }
    try {
      if (_canonicalJson(actual) != _canonicalJson(target)) {
        failures.add('$failurePrefix.mismatch.${entry.key}');
      }
    } on ArgumentError {
      failures.add('$failurePrefix.nonfinite.${entry.key}');
    }
  }
  return failures;
}

List<String> _gastricStructuralObservableViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  const evaluator = GastricStructuralUncertaintyService();
  var modeledReportCount = 0;
  for (final snapshot in snapshots.values) {
    final report = snapshot.gastricStructuralUncertainty;
    final productionProfile = snapshot.conflict.primaryEmptyingProfile;
    if (report == null || productionProfile == null) {
      if (snapshot.conflict.hasModeledOutput) {
        failures.add(
          'gastric.structural_report_missing.${snapshot.scenario.name}',
        );
      }
      continue;
    }
    modeledReportCount++;
    if (report.trajectories.length != GastricStructureKind.values.length) {
      failures.add(
        'gastric.structure_set_incomplete.${snapshot.scenario.name}',
      );
      continue;
    }
    for (final trajectory in report.trajectories) {
      final contract = trajectory.structure;
      var previous = double.infinity;
      for (var minute = 0; minute <= 480; minute += 10) {
        final value = evaluator.evaluateDeclaredStructure(
          contract: contract,
          minute: minute,
          productionProfile: productionProfile,
        );
        if (!value.isFinite || value < 0) {
          failures.add(
            'gastric.structure_nonfinite_or_negative.${contract.kind.name}',
          );
          break;
        }
        final fractionLike =
            contract.observable ==
                GastricMeasuredObservable.normalizedIntragastricRetention ||
            contract.observable == GastricMeasuredObservable.pelletRetention;
        if (fractionLike && value > 1 + 1e-10) {
          failures.add(
            'gastric.structure_fraction_bounds.${contract.kind.name}',
          );
          break;
        }
        if (fractionLike && value > previous + 1e-10) {
          failures.add(
            'gastric.structure_fraction_nonmonotonic.${contract.kind.name}',
          );
          break;
        }
        previous = value;
      }
      final atOrigin = evaluator.evaluateDeclaredStructure(
        contract: contract,
        minute: 0,
        productionProfile: productionProfile,
      );
      if (contract.observable ==
          GastricMeasuredObservable.absoluteGastricVolume) {
        final v0 = contract.parameters
            .singleWhere((parameter) => parameter.id == 'linexp.v0')
            .value;
        if ((atOrigin - v0).abs() > 1e-10 || atOrigin <= 1) {
          failures.add('gastric.absolute_volume_origin_invalid');
        }
      } else if ((atOrigin - 1).abs() > 1e-10) {
        failures.add('gastric.fraction_origin_invalid.${contract.kind.name}');
      }
    }
  }
  if (modeledReportCount != 2) {
    failures.add('gastric.modeled_structural_report_count');
  }
  return failures;
}

List<String> _gastricStructuralAuthorityViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  for (final snapshot in snapshots.values) {
    final report = snapshot.gastricStructuralUncertainty;
    if (report == null) continue;
    if (report.productionOutputDigestBefore !=
        report.productionOutputDigestAfter) {
      failures.add('gastric.shadow_changed_production_output');
    }
    if (!report.observationSeries.synthetic ||
        !report.observationSeries.derivedFromProduction) {
      failures.add('gastric.shadow_fixture_circularity_not_declared');
    }
    for (final trajectory in report.trajectories) {
      final matches =
          trajectory.structure.observable ==
              report.observationSeries.observable &&
          trajectory.structure.modality == report.observationSeries.modality;
      if (!matches &&
          (trajectory.availability !=
                  GastricTrajectoryAvailability.observableMismatch ||
              trajectory.points.isNotEmpty ||
              trajectory.fitAuthorization.disposition !=
                  GastricFitDisposition.blocked)) {
        failures.add(
          'gastric.held_domain_numeric_or_authorized.${trajectory.structure.kind.name}',
        );
      }
      if (trajectory.fitAuthorization.disposition ==
          GastricFitDisposition.eligibleForResearchFit) {
        failures.add(
          'gastric.synthetic_fit_authorized.${trajectory.structure.kind.name}',
        );
      }
    }
  }
  return failures;
}

MechanisticVerificationCheckResult _result(
  MechanisticVerificationSpec spec,
  List<String> failures,
  String observation,
) => MechanisticVerificationCheckResult(
  spec: spec,
  passed: failures.isEmpty,
  observedProbeId: _observedProbeIdForCheck(spec.id),
  observation: observation,
  failureCodes: List<String>.unmodifiable(failures.toSet().toList()..sort()),
);

String _observedProbeIdForCheck(String specificationId) {
  if (specificationId == 'stack.independent_truth_vectors') {
    return independentNumericalVerificationProbeId;
  }
  if (specificationId.startsWith('dose.')) {
    return DoseInputInvariantProbe.probeId;
  }
  if (specificationId ==
      'recommendation.legacy_score_bounds_thresholds_and_order') {
    return LegacyFoodRecommendationInvariantProbe.probeId;
  }
  if (specificationId ==
      'nutrition.amino_acid_extraction_units_missingness_and_determinism') {
    return AminoAcidExtractionInvariantProbe.probeId;
  }
  if (specificationId ==
      'nutrition.catalog_candidate_basis_missingness_and_portion_scaling') {
    return CatalogCandidateProjectionInvariantProbe.probeId;
  }
  return fixedScenarioVerificationProbeId;
}

List<String> _shapeViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = <String>[];
  if (snapshots.length != ObservatoryScenario.values.length ||
      !snapshots.keys.toSet().containsAll(ObservatoryScenario.values)) {
    failures.add('verification.scenario_set_incomplete');
  }
  for (final entry in snapshots.entries) {
    if (entry.value.scenario != entry.key) {
      failures.add('verification.scenario_identity_mismatch.${entry.key.name}');
    }
  }
  return failures;
}

List<String> _normalizerViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  for (final entry in snapshots.entries) {
    final composition = entry.value.composition;
    final numeric = <double?>[
      composition.totalCalories,
      composition.proteinGrams,
      composition.fatGrams,
      composition.fiberGrams,
      composition.carbohydrateGrams,
      composition.liquidFraction,
      composition.compositionCompleteness,
    ];
    for (final value in numeric.whereType<double>()) {
      if (!value.isFinite || value < 0) {
        failures.add('normalizer.nonfinite_or_negative.${entry.key.name}');
      }
    }
    if (composition.compositionCompleteness < 0 ||
        composition.compositionCompleteness > 1) {
      failures.add('normalizer.completeness_out_of_range.${entry.key.name}');
    }
  }
  final incomplete = snapshots[ObservatoryScenario.incompleteData]?.composition;
  if (incomplete == null ||
      incomplete.totalCalories != null ||
      incomplete.fatGrams != null ||
      !incomplete.missingFields.contains('total_calories') ||
      !incomplete.missingFields.contains('fat_grams')) {
    failures.add('normalizer.incomplete_missingness_collapsed');
  }
  return failures;
}

List<String> _unitViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  const canonicalUnits = <MechanisticLedgerDimension, String>{
    MechanisticLedgerDimension.mass: 'mg',
    MechanisticLedgerDimension.energy: 'kcal',
    MechanisticLedgerDimension.duration: 'min',
    MechanisticLedgerDimension.fraction: 'fraction',
  };
  for (final snapshot in snapshots.values) {
    for (final event in snapshot.eventLedger.events) {
      for (final measurement in event.measurements) {
        if (measurement.dimension == MechanisticLedgerDimension.categorical) {
          failures.add('unit.categorical_numeric_measurement');
          continue;
        }
        if (measurement.canonicalUnit !=
            canonicalUnits[measurement.dimension]) {
          failures.add('unit.canonical_unit_mismatch.${measurement.id}');
        }
        if (measurement.state == MechanisticLedgerValueState.known &&
            (measurement.canonicalValue == null ||
                !measurement.canonicalValue!.isFinite)) {
          failures.add('unit.known_value_nonfinite.${measurement.id}');
        }
        if (measurement.state != MechanisticLedgerValueState.known &&
            (measurement.originalValue != null ||
                measurement.canonicalValue != null)) {
          failures.add('unit.unknown_value_not_null.${measurement.id}');
        }
      }
    }
  }
  bool close(double left, double right) => (left - right).abs() <= 1e-12;
  if (!close(
        MechanisticUnitConverter.convert(
          value: 1,
          fromUnit: 'g',
          toUnit: 'mg',
          dimension: MechanisticLedgerDimension.mass,
        ),
        1000,
      ) ||
      !close(
        MechanisticUnitConverter.convert(
          value: 1,
          fromUnit: 'h',
          toUnit: 'min',
          dimension: MechanisticLedgerDimension.duration,
        ),
        60,
      ) ||
      !close(
        MechanisticUnitConverter.convert(
          value: 100,
          fromUnit: '%',
          toUnit: 'fraction',
          dimension: MechanisticLedgerDimension.fraction,
        ),
        1,
      )) {
    failures.add('unit.equivalent_conversion_mismatch');
  }
  try {
    MechanisticUnitConverter.convert(
      value: 1,
      fromUnit: 'h',
      toUnit: 'mg',
      dimension: MechanisticLedgerDimension.mass,
    );
    failures.add('unit.dimension_mismatch_accepted');
  } on ArgumentError {
    // Expected fail-closed behavior.
  }
  return failures;
}

Iterable<AlgorithmObservatorySnapshot> _modeledSnapshots(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) => snapshots.values.where((entry) => entry.conflict.hasModeledOutput);

List<String> _gastricCurveViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  for (final snapshot in _modeledSnapshots(snapshots)) {
    final profile = snapshot.conflict.primaryEmptyingProfile;
    if (profile == null || !profile.hasModeledOutput) {
      failures.add('gastric.profile_missing.${snapshot.scenario.name}');
      continue;
    }
    failures.addAll(
      profile.structuralIntegrityReasons.map(
        (reason) => '$reason.${snapshot.scenario.name}',
      ),
    );
    var previous = double.infinity;
    for (var minute = 0; minute <= 1440; minute++) {
      final remaining = profile.remainingFractionAt(minute);
      final emptied = profile.emptiedFractionAt(minute);
      if (!remaining.isFinite || remaining < 0 || remaining > 1) {
        failures.add('gastric.remaining_bounds.${snapshot.scenario.name}');
        break;
      }
      if (!emptied.isFinite || emptied < 0 || emptied > 1) {
        failures.add('gastric.emptied_bounds.${snapshot.scenario.name}');
        break;
      }
      if (remaining > previous + 1e-10) {
        failures.add(
          'gastric.remaining_nonmonotonic.${snapshot.scenario.name}',
        );
        break;
      }
      if ((remaining + emptied - 1).abs() > 1e-10) {
        failures.add(
          'gastric.mass_not_complementary.${snapshot.scenario.name}',
        );
        break;
      }
      previous = remaining;
    }
  }
  return failures;
}

List<String> _gastricArrivalViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  for (final snapshot in _modeledSnapshots(snapshots)) {
    final profile = snapshot.conflict.primaryEmptyingProfile;
    if (profile == null || !profile.hasModeledOutput) continue;
    var integrated = 0.0;
    for (var minute = 0; minute <= 1440; minute++) {
      final rate = profile.intestinalArrivalRateAt(minute);
      if (!rate.isFinite || rate < 0 || rate > 1) {
        failures.add('gastric.arrival_rate_bounds.${snapshot.scenario.name}');
        break;
      }
      integrated += rate;
    }
    final cumulative =
        profile.emptiedFractionAt(1440) - profile.emptiedFractionAt(0);
    if ((integrated - cumulative).abs() > 0.01) {
      failures.add(
        'gastric.arrival_integral_mismatch.${snapshot.scenario.name}',
      );
    }
  }
  return failures;
}

List<String> _gastricEnvelopeViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  for (final snapshot in _modeledSnapshots(snapshots)) {
    final profile = snapshot.conflict.primaryEmptyingProfile;
    if (profile == null || !profile.hasModeledOutput) continue;
    var previousFast = double.infinity;
    var previousSlow = double.infinity;
    for (var minute = 0; minute <= 1440; minute++) {
      final central = profile.remainingFractionAt(minute);
      final envelope = profile.sensitivityEnvelopeAt(minute);
      if (!envelope.fasterRemaining.isFinite ||
          !envelope.slowerRemaining.isFinite ||
          envelope.fasterRemaining > central + 1e-10 ||
          central > envelope.slowerRemaining + 1e-10 ||
          envelope.fasterRemaining > previousFast + 1e-10 ||
          envelope.slowerRemaining > previousSlow + 1e-10) {
        failures.add('gastric.envelope_order.${snapshot.scenario.name}');
        break;
      }
      previousFast = envelope.fasterRemaining;
      previousSlow = envelope.slowerRemaining;
    }
  }
  return failures;
}

List<String> _absorptionViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  for (final snapshot in _modeledSnapshots(snapshots)) {
    final profile = snapshot.conflict.absorptionOpportunityWindow;
    if (profile == null || !profile.hasModeledOutput) {
      failures.add('absorption.profile_missing.${snapshot.scenario.name}');
      continue;
    }
    failures.addAll(
      profile.structuralIntegrityReasons.map(
        (reason) => '$reason.${snapshot.scenario.name}',
      ),
    );
  }
  return failures;
}

List<String> _competitionViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  for (final snapshot in _modeledSnapshots(snapshots)) {
    final timeline = snapshot.conflict.competitionTimeline;
    if (timeline == null || !timeline.hasModeledOutput) {
      failures.add('competition.profile_missing.${snapshot.scenario.name}');
      continue;
    }
    failures.addAll(
      timeline.structuralIntegrityReasons.map(
        (reason) => '$reason.${snapshot.scenario.name}',
      ),
    );
    if (timeline.competitionBand !=
        competitionBandForOverlap(timeline.overlapWithAbsorptionWindow)) {
      failures.add(
        'competition.band_threshold_mismatch.${snapshot.scenario.name}',
      );
    }
  }
  return failures;
}

List<String> _compositeViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  for (final snapshot in _modeledSnapshots(snapshots)) {
    final result = snapshot.conflict;
    failures.addAll(
      result.structuralIntegrityReasons.map(
        (reason) => '$reason.${snapshot.scenario.name}',
      ),
    );
    final score = result.modeledInteractionScore;
    if (score == null || !score.isFinite || score < 0 || score > 1) {
      failures.add('conflict.score_bounds.${snapshot.scenario.name}');
    }
    if (snapshot.candidateScores.isEmpty) {
      failures.add('candidate.scores_missing.${snapshot.scenario.name}');
    }
    for (final candidate in snapshot.candidateScores) {
      failures.addAll(
        candidate.structuralIntegrityReasons.map(
          (reason) => '$reason.${snapshot.scenario.name}',
        ),
      );
      final candidateScore = candidate.modeledFinalCandidateScore;
      if (candidateScore == null ||
          !candidateScore.isFinite ||
          candidateScore < 0 ||
          candidateScore > 1) {
        failures.add('candidate.score_bounds.${snapshot.scenario.name}');
      }
    }
  }
  return failures;
}

List<String> _abstentionViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  final snapshot = snapshots[ObservatoryScenario.incompleteData];
  if (snapshot == null) return failures;
  final result = snapshot.conflict;
  if (result.hasModeledOutput) {
    failures.add('stack.incomplete_conflict_available');
  }
  if (result.modeledInteractionScore != null ||
      result.modeledSeverityBand != null) {
    failures.add('stack.incomplete_conflict_numeric_present');
  }
  if (result.primaryEmptyingProfile != null ||
      result.absorptionOpportunityWindow != null ||
      result.competitionTimeline != null) {
    failures.add('stack.incomplete_conflict_layer_present');
  }
  final wire = result.toJson();
  if (wire['interaction_score'] != null ||
      wire['primary_emptying_profile'] != null ||
      wire['absorption_opportunity_window'] != null ||
      wire['competition_timeline'] != null) {
    failures.add('stack.incomplete_wire_collapsed_to_numeric');
  }
  return failures;
}

List<String> _oracleViolations(AlgorithmNumericalOracleReport report) {
  final failures = <String>[];
  if (report.blockReasonCode != null) {
    failures.add(report.blockReasonCode!);
  }
  for (final entry in report.cases.where((entry) => !entry.passed)) {
    failures.add(entry.reasonCode ?? 'oracle.unknown_failure');
  }
  return failures;
}

List<String> _medicationApplicabilityViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  final expectedManifest = MechanisticApplicabilityManifest.current;
  final validator = MedicationEntryValidator();
  const policy = MechanisticMedicationApplicabilityPolicy();
  for (final snapshot in snapshots.values) {
    final events = snapshot.context.medicationEvents;
    if (events.isEmpty) {
      failures.add(
        'medication.normalized_event_missing.${snapshot.scenario.name}',
      );
      continue;
    }
    for (final event in events) {
      final context = event.context;
      final roundTrip = validator.validate(
        RawMedicationEntry(
          activeIngredients: context.activeIngredients,
          drugProductVariant: context.drugProductVariant,
          form: context.form,
          route: context.route,
          releaseType: context.releaseType,
          strength: context.strength,
          unit: context.unit,
          jurisdiction: context.jurisdiction,
          sourceDocId: context.sourceDocId,
          labelSection: context.labelSection,
          extractionConfidence: context.extractionConfidence,
          medicationMetadata: context.metadata,
        ),
      );
      if (!roundTrip.eligibleForRuleEvaluation ||
          _canonicalJson(roundTrip.normalized?.toJson()) !=
              _canonicalJson(context.toJson())) {
        failures.add(
          'medication.validator_round_trip_mismatch.${snapshot.scenario.name}',
        );
      }
      final eventApplicability = policy.evaluate(context);
      if (!eventApplicability.applicable ||
          eventApplicability.releaseProfile !=
              MechanisticReleaseProfile.immediate ||
          eventApplicability.predicateOutcomes.length != 4) {
        failures.add(
          'medication.event_applicability_not_satisfied.${snapshot.scenario.name}',
        );
      }
    }
    final applicability = policy.evaluateContexts(
      events.map((event) => event.context),
    );
    if (!applicability.applicable ||
        applicability.releaseProfile != null ||
        applicability.predicateOutcomes.length != 4 ||
        applicability.predicateOutcomes.any(
          (outcome) =>
              outcome.status !=
                  MechanisticApplicabilityOutcomeStatus.satisfied ||
              outcome.reasonCodes.isNotEmpty,
        )) {
      failures.add(
        'medication.applicability_not_satisfied.${snapshot.scenario.name}',
      );
    }
    final result = snapshot.conflict;
    if (result.applicabilityManifestRef != expectedManifest.sourceRef ||
        result.explanation.applicabilityManifestRef !=
            expectedManifest.sourceRef ||
        result.perEventTraces.any(
          (trace) =>
              trace.applicabilityManifestRef != expectedManifest.sourceRef,
        )) {
      failures.add(
        'medication.applicability_manifest_identity_mismatch.${snapshot.scenario.name}',
      );
    }
    if (!applicability.applicable && result.hasModeledOutput) {
      failures.add(
        'medication.out_of_scope_modeled_output.${snapshot.scenario.name}',
      );
    }
  }
  return failures;
}

List<String> _proteinDistributionViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  var modeledTraceCount = 0;
  for (final snapshot in snapshots.values) {
    for (final candidate in snapshot.candidateScores) {
      final trace = candidate.modeledProteinDistribution;
      if (!candidate.hasModeledOutput) {
        if (trace != null ||
            candidate.modeledProteinRedistributionScore != null) {
          failures.add(
            'protein.abstention_numeric_present.${snapshot.scenario.name}',
          );
        }
        continue;
      }
      modeledTraceCount++;
      final redistribution = candidate.modeledProteinRedistributionScore;
      final adequacy = candidate.modeledNutritionAdequacyContribution;
      if (trace == null ||
          !trace.optimizationActive ||
          trace.windowRole == ProteinWindowRole.unknownWindowRole ||
          trace.objectiveDescription.trim().isEmpty ||
          redistribution == null ||
          adequacy == null ||
          !redistribution.isFinite ||
          !adequacy.isFinite ||
          redistribution < 0 ||
          redistribution > 1 ||
          adequacy < 0 ||
          adequacy > 1 ||
          (trace.redistributionScore - redistribution).abs() > 1e-9 ||
          (trace.nutritionAdequacyContribution - adequacy).abs() > 1e-9) {
        failures.add('protein.trace_invalid.${snapshot.scenario.name}');
      }
    }
  }
  if (modeledTraceCount == 0) {
    failures.add('protein.modeled_trace_set_empty');
  }
  return failures;
}

List<String> _configurationIdentityViolations(
  Map<ObservatoryScenario, AlgorithmObservatorySnapshot> snapshots,
) {
  final failures = _shapeViolations(snapshots);
  final digests = snapshots.values
      .map((snapshot) => snapshot.configurationIdentity.sha256Digest)
      .toSet();
  if (digests.length != 1) {
    failures.add('verification.configuration_digest_mismatch');
  }
  for (final snapshot in snapshots.values) {
    final identity = snapshot.configurationIdentity;
    final configuration = identity.canonicalConfiguration;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(identity.sha256Digest) ||
        identity.id.trim().isEmpty ||
        identity.version.trim().isEmpty ||
        configuration['registered_algorithm_source_bundle_sha256'] !=
            AlgorithmConfigurationIdentity
                .registeredAlgorithmSourceBundleSha256 ||
        configuration['mechanistic_applicability_manifest'] == null ||
        configuration['parameter_provenance_manifest'] == null ||
        configuration['algorithm_manifest'] is! List ||
        (configuration['algorithm_manifest'] as List).length !=
            AlgorithmRegistry.all.length ||
        _canonicalJson(configuration['gastric_emptying']) !=
            _canonicalJson(
              GastricEmptyingModel(
                parameters: snapshot.gastricParameters,
              ).configuration,
            )) {
      failures.add(
        'verification.configuration_payload_mismatch.${snapshot.scenario.name}',
      );
    }
  }
  return failures;
}

String _canonicalJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is num && !value.isFinite) {
    throw ArgumentError('Verification specification values must be finite.');
  }
  return jsonEncode(value);
}
