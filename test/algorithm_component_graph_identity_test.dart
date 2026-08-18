import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/algorithm_sdk/parkinsum_algorithm_sdk.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_parameters.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_next_meal_scorer.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_replay_runner.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_scoring_parameters.dart';
import 'package:parkinsum_companion/domain/usecases/protein_distribution_model.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

void main() {
  final defaultIdentity = AlgorithmConfigurationIdentity.defaults();

  test('unified validator accepts the exact default execution graph', () {
    AlgorithmComponentGraphIdentityValidator.validateExecutionGraph(
      medicationValidator: MedicationEntryValidator(),
      normalizer: MealCompositionNormalizer(),
      timeAxisBuilder: TimeAxisBuilder(),
      conflictEngine: MechanisticConflictEngine(),
      candidateScorer: MechanisticNextMealScorer(),
      identity: defaultIdentity,
      graphLabel: 'test.defaultGraph',
    );
  });

  test('Replay requires identity for every injected top-level component', () {
    expect(
      () => MechanisticReplayRunner(normalizer: MealCompositionNormalizer()),
      throwsArgumentError,
    );
    expect(
      () => MechanisticReplayRunner(
        timeAxisBuilder: _UnattestedTimeAxisBuilder(),
        configurationIdentity: defaultIdentity,
      ),
      throwsArgumentError,
    );
  });

  test('Replay rejects an unattested scorer-internal normalizer', () {
    final scorer = MechanisticNextMealScorer(
      normalizer: _RuntimeTypeSpoofingMealCompositionNormalizer(),
    );

    expect(
      () => MechanisticReplayRunner(
        scorer: scorer,
        configurationIdentity: defaultIdentity,
      ),
      throwsArgumentError,
    );
  });

  test('Replay rejects a scorer subtype that spoofs its runtimeType', () {
    expect(
      () => MechanisticReplayRunner(
        scorer: _RuntimeTypeSpoofingScorer(),
        configurationIdentity: defaultIdentity,
      ),
      throwsArgumentError,
    );
  });

  test('Replay rejects an implements/noSuchMethod identity forgery', () {
    final scorer = MechanisticNextMealScorer(
      normalizer: _NoSuchMethodForgedNormalizer(),
    );

    expect(
      () => MechanisticReplayRunner(
        scorer: scorer,
        configurationIdentity: defaultIdentity,
      ),
      throwsArgumentError,
    );
  });

  test('Replay rejects a subtype without invoking its runtimeType getter', () {
    final scorer = MechanisticNextMealScorer(
      normalizer: _ThrowingRuntimeTypeMealCompositionNormalizer(),
    );

    expect(
      () => MechanisticReplayRunner(
        scorer: scorer,
        configurationIdentity: defaultIdentity,
      ),
      throwsArgumentError,
    );
  });

  test('Replay rejects an unattested scorer-internal protein model', () {
    final scorer = MechanisticNextMealScorer(
      proteinDistributionModel: _UnattestedProteinDistributionModel(),
    );

    expect(
      () => MechanisticReplayRunner(
        scorer: scorer,
        configurationIdentity: defaultIdentity,
      ),
      throwsArgumentError,
    );
  });

  test('Replay rejects an unattested scorer-internal engine model', () {
    final scorer = MechanisticNextMealScorer(
      engine: MechanisticConflictEngine(
        absorptionModel: _UnattestedAbsorptionModel(),
      ),
    );

    expect(
      () => MechanisticReplayRunner(
        scorer: scorer,
        configurationIdentity: defaultIdentity,
      ),
      throwsArgumentError,
    );
  });

  test('Replay rejects scorer parameters hidden behind a default identity', () {
    final changed = _gastricWithChangedSolidHalf();
    final scorer = MechanisticNextMealScorer(
      engine: MechanisticConflictEngine(gastricEmptyingParameters: changed),
    );

    expect(
      () => MechanisticReplayRunner(
        scorer: scorer,
        configurationIdentity: defaultIdentity,
      ),
      throwsArgumentError,
    );
  });

  test('Replay rejects changed scoring values behind a default identity', () {
    final scorer = MechanisticNextMealScorer(
      scoringParameters: _scoringWithChangedConflictWeight(),
    );

    expect(
      () => MechanisticReplayRunner(
        scorer: scorer,
        configurationIdentity: defaultIdentity,
      ),
      throwsArgumentError,
    );
  });

  test('Observatory requires identity for every injected component', () {
    expect(
      () => AlgorithmObservatoryService(
        conflictEngine: MechanisticConflictEngine(),
      ),
      throwsArgumentError,
    );
  });

  test(
    'Observatory accepts an exact injected graph with matching identity',
    () {
      final engine = MechanisticConflictEngine();
      final scorer = MechanisticNextMealScorer(engine: engine);
      final service = AlgorithmObservatoryService(
        conflictEngine: engine,
        candidateScorer: scorer,
        configurationIdentity: defaultIdentity,
      );

      expect(
        service.configurationIdentity.sha256Digest,
        defaultIdentity.sha256Digest,
      );
    },
  );

  test('Observatory rejects a hidden scorer-internal custom component', () {
    final scorer = MechanisticNextMealScorer(
      proteinDistributionModel: _UnattestedProteinDistributionModel(),
    );

    expect(
      () => AlgorithmObservatoryService(
        candidateScorer: scorer,
        configurationIdentity: defaultIdentity,
      ),
      throwsArgumentError,
    );
  });

  test('Observatory rejects an identity for a different resolved graph', () {
    expect(
      () => AlgorithmObservatoryService(
        configurationIdentity: AlgorithmConfigurationIdentity.defaults(
          gastricParameters: _gastricWithChangedSolidHalf(),
        ),
      ),
      throwsArgumentError,
    );
  });
}

class _RuntimeTypeSpoofingMealCompositionNormalizer
    extends MealCompositionNormalizer {
  @override
  Type get runtimeType => MealCompositionNormalizer;
}

class _RuntimeTypeSpoofingScorer extends MechanisticNextMealScorer {
  @override
  Type get runtimeType => MechanisticNextMealScorer;
}

class _NoSuchMethodForgedNormalizer implements MealCompositionNormalizer {
  @override
  Type get runtimeType => MealCompositionNormalizer;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _ThrowingRuntimeTypeMealCompositionNormalizer
    extends MealCompositionNormalizer {
  @override
  Type get runtimeType => throw StateError('must not be invoked');
}

class _UnattestedProteinDistributionModel extends ProteinDistributionModel {}

class _UnattestedAbsorptionModel extends LevodopaAbsorptionOpportunityModel {}

class _UnattestedTimeAxisBuilder extends TimeAxisBuilder {}

GastricEmptyingParameterSet _gastricWithChangedSolidHalf() {
  final defaults = GastricEmptyingParameterSet.literatureInformedDefault();
  return GastricEmptyingParameterSet(
    id: defaults.id,
    version: 'hidden-scorer-parameters',
    lastReviewed: defaults.lastReviewed,
    solidLagMinutes: defaults.solidLagMinutes,
    solidHalfMinutes: GastricEmptyingParameter<double>(
      id: defaults.solidHalfMinutes.id,
      label: defaults.solidHalfMinutes.label,
      value: defaults.solidHalfMinutes.value + 1,
      sourceRefs: defaults.solidHalfMinutes.sourceRefs,
      confidence: defaults.solidHalfMinutes.confidence,
      limitation: defaults.solidHalfMinutes.limitation,
    ),
    liquidLagMinutes: defaults.liquidLagMinutes,
    liquidHalfMinutes: defaults.liquidHalfMinutes,
    referenceMealCalories: defaults.referenceMealCalories,
    fatSlowdownMultiplier: defaults.fatSlowdownMultiplier,
    fatFractionThreshold: defaults.fatFractionThreshold,
    fiberSlowdownMultiplier: defaults.fiberSlowdownMultiplier,
    mixedMealUncertaintyBoost: defaults.mixedMealUncertaintyBoost,
    overlapUncertaintyBoost: defaults.overlapUncertaintyBoost,
    fatUncertaintyBoost: defaults.fatUncertaintyBoost,
    highCalorieUncertaintyBoost: defaults.highCalorieUncertaintyBoost,
    highCalorieFractionThreshold: defaults.highCalorieFractionThreshold,
    timeScaleSensitivityFraction: defaults.timeScaleSensitivityFraction,
  );
}

NextMealScoringParameterSet _scoringWithChangedConflictWeight() {
  final defaults = NextMealScoringParameterSet.literatureInformedDefault();
  return NextMealScoringParameterSet(
    id: 'next_meal_scoring.changed-conflict-weight',
    conflictOverlap: ScoringWeight(
      id: defaults.conflictOverlap.id,
      label: defaults.conflictOverlap.label,
      value: defaults.conflictOverlap.value + 0.01,
      sourceRefs: defaults.conflictOverlap.sourceRefs,
      evidenceLevel: defaults.conflictOverlap.evidenceLevel,
      limitation: defaults.conflictOverlap.limitation,
    ),
    proteinRedistribution: ScoringWeight(
      id: defaults.proteinRedistribution.id,
      label: defaults.proteinRedistribution.label,
      value: defaults.proteinRedistribution.value - 0.01,
      sourceRefs: defaults.proteinRedistribution.sourceRefs,
      evidenceLevel: defaults.proteinRedistribution.evidenceLevel,
      limitation: defaults.proteinRedistribution.limitation,
    ),
    nutritionAdequacy: defaults.nutritionAdequacy,
    metadataCompleteness: defaults.metadataCompleteness,
    sourceAuthority: defaults.sourceAuthority,
    jurisdictionMatch: defaults.jurisdictionMatch,
    provenanceQuality: defaults.provenanceQuality,
    uncertaintyPenalty: defaults.uncertaintyPenalty,
  );
}
