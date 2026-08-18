library;

import 'algorithm_configuration_identity.dart';
import '../domain/entities/algorithm_component_identity_witness.dart';
import '../domain/entities/protein_source.dart';
import '../domain/usecases/amino_acid_competition_model.dart';
import '../domain/usecases/gastric_emptying_model.dart';
import '../domain/usecases/levodopa_absorption_opportunity_model.dart';
import '../domain/usecases/meal_composition_normalizer.dart';
import '../domain/usecases/mechanistic_conflict_engine.dart';
import '../domain/usecases/mechanistic_next_meal_scorer.dart';
import '../domain/usecases/medication_entry_validator.dart';
import '../domain/usecases/protein_distribution_model.dart';
import '../domain/usecases/time_axis_builder.dart';

/// Fail-closed binding between a resolved runtime component graph and a
/// canonical [AlgorithmConfigurationIdentity].
///
/// Exact registered runtime types are required because a subtype may override
/// result-affecting behavior while exposing the same public parameters. The
/// current identity schema has no independently governed component identities,
/// so it cannot honestly attest custom implementations yet.
abstract final class AlgorithmComponentGraphIdentityValidator {
  static void validateConflictEngine({
    required MechanisticConflictEngine engine,
    required AlgorithmConfigurationIdentity identity,
    String graphLabel = 'mechanistic conflict engine',
  }) {
    _requireExactType(
      component: engine,
      expectedType: MechanisticConflictEngine,
      componentPath: graphLabel,
    );
    _requireExactType(
      component: engine.gastricEmptyingModel,
      expectedType: GastricEmptyingModel,
      componentPath: '$graphLabel.gastricEmptyingModel',
    );
    _requireExactType(
      component: engine.absorptionModel,
      expectedType: LevodopaAbsorptionOpportunityModel,
      componentPath: '$graphLabel.absorptionModel',
    );
    _requireExactType(
      component: engine.competitionModel,
      expectedType: AminoAcidCompetitionModel,
      componentPath: '$graphLabel.competitionModel',
    );

    _requireConfigurationMatch(
      identity: identity,
      section: 'gastric_emptying',
      actual: engine.gastricEmptyingModel.parameters.toJson(),
      componentPath: '$graphLabel.gastricEmptyingModel.parameters',
    );
    _requireConfigurationMatch(
      identity: identity,
      section: 'levodopa_absorption_opportunity',
      actual: _absorptionConfiguration,
      componentPath: '$graphLabel.absorptionModel.configuration',
    );
    _requireConfigurationMatch(
      identity: identity,
      section: 'amino_acid_competition',
      actual: _competitionConfiguration,
      componentPath: '$graphLabel.competitionModel.configuration',
    );
  }

  static void validateCandidateScorer({
    required MechanisticNextMealScorer scorer,
    required AlgorithmConfigurationIdentity identity,
    String graphLabel = 'mechanistic candidate scorer',
  }) {
    _requireExactType(
      component: scorer,
      expectedType: MechanisticNextMealScorer,
      componentPath: graphLabel,
    );
    _requireExactType(
      component: scorer.normalizer,
      expectedType: MealCompositionNormalizer,
      componentPath: '$graphLabel.normalizer',
    );
    _requireExactType(
      component: scorer.proteinDistributionModel,
      expectedType: ProteinDistributionModel,
      componentPath: '$graphLabel.proteinDistributionModel',
    );
    validateConflictEngine(
      engine: scorer.engine,
      identity: identity,
      graphLabel: '$graphLabel.engine',
    );
    _requireConfigurationMatch(
      identity: identity,
      section: 'protein_distribution',
      actual: _proteinDistributionConfiguration,
      componentPath: '$graphLabel.proteinDistributionModel.configuration',
    );
    _requireConfigurationMatch(
      identity: identity,
      section: 'candidate_scoring',
      actual: {
        'weights': scorer.scoringParameters.toJson(),
        'min_sample_count': MechanisticNextMealScorer.minSampleCount,
        'max_sample_count': MechanisticNextMealScorer.maxSampleCount,
        'sample_stride_minutes': MechanisticNextMealScorer.sampleStrideMinutes,
      },
      componentPath: '$graphLabel.configuration',
    );
  }

  /// Validates the complete resolved graph shared by replay and Observatory.
  static void validateExecutionGraph({
    required MedicationEntryValidator medicationValidator,
    required MealCompositionNormalizer normalizer,
    required TimeAxisBuilder timeAxisBuilder,
    required MechanisticConflictEngine conflictEngine,
    required MechanisticNextMealScorer candidateScorer,
    required AlgorithmConfigurationIdentity identity,
    required String graphLabel,
  }) {
    _requireExactType(
      component: medicationValidator,
      expectedType: MedicationEntryValidator,
      componentPath: '$graphLabel.medicationValidator',
    );
    _requireExactType(
      component: normalizer,
      expectedType: MealCompositionNormalizer,
      componentPath: '$graphLabel.normalizer',
    );
    _requireExactType(
      component: timeAxisBuilder,
      expectedType: TimeAxisBuilder,
      componentPath: '$graphLabel.timeAxisBuilder',
    );
    validateConflictEngine(
      engine: conflictEngine,
      identity: identity,
      graphLabel: '$graphLabel.conflictEngine',
    );
    validateCandidateScorer(
      scorer: candidateScorer,
      identity: identity,
      graphLabel: '$graphLabel.candidateScorer',
    );
  }

  static void _requireConfigurationMatch({
    required AlgorithmConfigurationIdentity identity,
    required String section,
    required Object? actual,
    required String componentPath,
  }) {
    final declared = identity.canonicalConfiguration[section];
    final declaredDigest = AlgorithmConfigurationIdentity.digestConfiguration(
      declared,
    );
    final actualDigest = AlgorithmConfigurationIdentity.digestConfiguration(
      actual,
    );
    if (declaredDigest != actualDigest) {
      throw ArgumentError(
        'Algorithm configuration identity section "$section" does not match '
        'the resolved component at $componentPath.',
      );
    }
  }

  static void _requireExactType({
    required Object component,
    required Type expectedType,
    required String componentPath,
  }) {
    if (!hasExactRegisteredAlgorithmComponentType(
      component: component,
      expectedType: expectedType,
    )) {
      throw ArgumentError(
        'Algorithm configuration identity cannot attest custom component '
        'at $componentPath. Expected the exact registered type $expectedType; '
        'add a governed component identity before injecting a custom '
        'implementation.',
      );
    }
  }

  static Map<String, dynamic> get _absorptionConfiguration => {
    'reference_ir_lag_minutes':
        LevodopaAbsorptionOpportunityModel.referenceIrLagMinutes,
    'reference_ir_duration_minutes':
        LevodopaAbsorptionOpportunityModel.referenceIrDurationMinutes,
    'illustrative_meal_delay_minutes':
        LevodopaAbsorptionOpportunityModel.illustrativeMealDelayMinutes,
    'openness_sample_stride_minutes':
        LevodopaAbsorptionOpportunityModel.opennessSampleStrideMinutes,
    'ir_peak_openness': LevodopaAbsorptionOpportunityModel.irPeakOpenness,
    'ir_tail_openness': LevodopaAbsorptionOpportunityModel.irTailOpenness,
  };

  static Map<String, dynamic> get _competitionConfiguration {
    final factors = ProteinSourceLnaaRegistry.all()
      ..sort(
        (left, right) => left.sourceType.name.compareTo(right.sourceType.name),
      );
    return {
      'reference_protein_g': AminoAcidCompetitionModel.referenceProteinG,
      'sample_stride_minutes': AminoAcidCompetitionModel.sampleStrideMinutes,
      'protein_source_lnaa_factors': [
        for (final factor in factors) factor.toJson(),
      ],
    };
  }

  static Map<String, dynamic> get _proteinDistributionConfiguration => {
    'high_overlap_threshold': ProteinDistributionModel.highOverlapThreshold,
    'low_overlap_threshold': ProteinDistributionModel.lowOverlapThreshold,
    'evening_hour_start': ProteinDistributionModel.eveningHourStart,
    'adequacy_reference_protein_g':
        ProteinDistributionModel.adequacyReferenceProteinG,
  };
}
