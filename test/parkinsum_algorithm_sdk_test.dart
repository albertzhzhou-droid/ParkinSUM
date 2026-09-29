import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/algorithm_sdk/parkinsum_algorithm_sdk.dart';
import 'package:parkinsum_companion/domain/entities/absorption_opportunity.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_parameters.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_registry.dart';
import 'package:parkinsum_companion/domain/usecases/dosage_note_parser.dart';
import 'package:parkinsum_companion/domain/usecases/get_protein_trend_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_scoring_parameters.dart';

void main() {
  test('SDK emits a versioned UI-independent evaluation envelope', () {
    final sdk = ParkinSumAlgorithmSdk();
    final envelope = sdk.evaluateConflict(
      evaluationId: 'sdk_no_meal',
      context: TimeAxisConflictContext(
        referenceMinute: 100,
        medicationEvents: [
          MedicationTimelineEvent(
            id: 'dose_1',
            minute: 100,
            context: const NormalizedMedicationContext(
              drugProductVariant: 'levodopa_ir_100',
              activeIngredients: ['levodopa'],
              strength: 100,
              unit: 'mg',
              form: 'tablet',
              route: 'oral',
              releaseType: 'immediate',
              jurisdiction: 'CA',
              sourceDocId: 'label_1',
              labelSection: 'Dosage forms and strengths',
              extractionConfidence: 1,
              limitationText: 'Synthetic SDK contract fixture.',
            ),
          ),
        ],
        mealEvents: const [],
        userDefinedWindow: null,
      ),
      mealCompositionsById: const <String, MealComposition>{},
    );

    final json = envelope.toJson();
    expect(json[r'$schema'], 'parkinsum.algorithm-evaluation/4');
    expect(json['engine_version'], ParkinSumAlgorithmSdk.defaultEngineVersion);
    expect(
      json['configuration_manifest_schema'],
      'parkinsum.algorithm-configuration/6',
    );
    expect(json['configuration_digest'], matches(RegExp(r'^[a-f0-9]{64}$')));
    final parameterSet = json['parameter_set'] as Map<String, dynamic>;
    expect(parameterSet['id'], 'gastric_emptying_population_sensitivity');
    expect(parameterSet['version'], '2026.09.02-v3');
    expect(parameterSet['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
    final configuration =
        json['configuration_identity'] as Map<String, dynamic>;
    expect(configuration[r'$schema'], 'parkinsum.algorithm-configuration/6');
    expect(configuration['id'], 'parkinsum-default-algorithm-stack');
    expect(configuration['sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
    final sections = configuration['configuration'] as Map<String, dynamic>;
    expect(
      sections.keys,
      containsAll([
        'gastric_emptying',
        'levodopa_absorption_opportunity',
        'amino_acid_competition',
        'protein_distribution',
        'candidate_scoring',
        'legacy_food_recommendations',
        'runtime_rule_logic',
        'legacy_nutrition_thresholds',
        'algorithm_manifest',
        'parameter_provenance_manifest',
        'registered_algorithm_source_bundle_sha256',
        'implementation_source_sha256',
      ]),
    );
    expect((json['result'] as Map<String, dynamic>)['id'], 'sdk_no_meal');
  });

  test('SDK rejects identifiers that could reshape storage paths', () {
    final sdk = ParkinSumAlgorithmSdk();

    expect(
      () => sdk.evaluateConflict(
        evaluationId: 'unsafe/private',
        context: TimeAxisConflictContext(
          referenceMinute: 0,
          medicationEvents: [],
          mealEvents: [],
          userDefinedWindow: null,
        ),
        mealCompositionsById: const {},
      ),
      throwsArgumentError,
    );
  });

  test('SDK blocks malformed or internally inconsistent meal structures', () {
    final sdk = ParkinSumAlgorithmSdk();
    final malformed = [
      _sdkMealComposition(proteinGrams: double.infinity),
      _sdkMealComposition(portionGrams: -1),
      _sdkMealComposition(compositionCompleteness: 1.1),
    ];
    for (var index = 0; index < malformed.length; index++) {
      final envelope = sdk.evaluateConflict(
        evaluationId: 'sdk_malformed_meal_$index',
        context: _sdkMealContext(),
        mealCompositionsById: {'sdk_meal_composition': malformed[index]},
      );
      expect(
        envelope.result.availability,
        MechanisticResultAvailability.blockedIntegrity,
        reason: '$index',
      );
      expect(envelope.result.hasModeledOutput, isFalse, reason: '$index');
      expect(
        envelope.result.toJson()['interaction_score'],
        isNull,
        reason: '$index',
      );
    }
  });

  test(
    'injected engines require explicit version and configuration identity',
    () {
      expect(
        () => ParkinSumAlgorithmSdk(engine: MechanisticConflictEngine()),
        throwsArgumentError,
      );
      expect(
        () => ParkinSumAlgorithmSdk(
          engine: MechanisticConflictEngine(),
          engineVersion: 'test-engine/v1',
        ),
        throwsArgumentError,
      );
      final injected = MechanisticConflictEngine();
      expect(
        ParkinSumAlgorithmSdk(
          engine: injected,
          engineVersion: 'test-engine/v1',
          configurationIdentity: AlgorithmConfigurationIdentity.defaults(
            gastricParameters: injected.gastricEmptyingModel.parameters,
          ),
        ).engineVersion,
        'test-engine/v1',
      );
    },
  );

  test('parameter digest changes when a selected value changes', () {
    final defaults = GastricEmptyingParameterSet.literatureInformedDefault();
    final changed = GastricEmptyingParameterSet(
      id: defaults.id,
      version: 'test-double-half-time-v1',
      lastReviewed: '2026-08-17',
      solidLagMinutes: defaults.solidLagMinutes,
      solidHalfMinutes: GastricEmptyingParameter<double>(
        id: defaults.solidHalfMinutes.id,
        label: defaults.solidHalfMinutes.label,
        value: defaults.solidHalfMinutes.value * 2,
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
    final baseline = ParkinSumAlgorithmSdk().evaluateConflict(
      evaluationId: 'baseline',
      context: _noMealContext(),
      mealCompositionsById: const {},
    );
    final changedEngine = MechanisticConflictEngine(
      gastricEmptyingParameters: changed,
    );
    final altered =
        ParkinSumAlgorithmSdk(
          engine: changedEngine,
          engineVersion: 'test-engine/double-half-v1',
          configurationIdentity: AlgorithmConfigurationIdentity.defaults(
            gastricParameters: changed,
          ),
        ).evaluateConflict(
          evaluationId: 'altered',
          context: _noMealContext(),
          mealCompositionsById: const {},
        );

    expect(altered.parameterSetVersion, 'test-double-half-time-v1');
    expect(altered.parameterSetDigest, isNot(baseline.parameterSetDigest));
    expect(altered.configurationDigest, isNot(baseline.configurationDigest));
  });

  test('absorption instance parameters require their exact identity', () {
    final defaults =
        LevodopaAbsorptionOpportunityParameterSet.prototypeDefault();
    final changed = defaults.copyWith(
      version: 'test-tail-openness-v1',
      irTailOpenness: 0.2,
    );
    final engine = MechanisticConflictEngine(
      absorptionModel: LevodopaAbsorptionOpportunityModel(parameters: changed),
    );
    final matchingIdentity = AlgorithmConfigurationIdentity.defaults(
      absorptionParameters: changed,
    );

    expect(
      ParkinSumAlgorithmSdk(
        engine: engine,
        engineVersion: 'test-engine/absorption-tail-v1',
        configurationIdentity: matchingIdentity,
      ).configurationIdentity.sha256Digest,
      matchingIdentity.sha256Digest,
    );
    expect(
      matchingIdentity.sha256Digest,
      isNot(AlgorithmConfigurationIdentity.defaults().sha256Digest),
    );
    expect(
      () => ParkinSumAlgorithmSdk(
        engine: engine,
        engineVersion: 'test-engine/absorption-tail-mismatch',
        configurationIdentity: AlgorithmConfigurationIdentity.defaults(),
      ),
      throwsArgumentError,
    );
  });

  test('SDK rejects a configuration identity that mismatches its engine', () {
    final defaults = GastricEmptyingParameterSet.literatureInformedDefault();
    final changed = GastricEmptyingParameterSet(
      id: defaults.id,
      version: 'mismatch-fixture',
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

    expect(
      () => ParkinSumAlgorithmSdk(
        engine: MechanisticConflictEngine(gastricEmptyingParameters: changed),
        engineVersion: 'test-engine/mismatched-config',
        configurationIdentity: AlgorithmConfigurationIdentity.defaults(),
      ),
      throwsArgumentError,
    );
  });

  test(
    'SDK validates the resolved default engine against a supplied identity',
    () {
      final changed = _gastricWithChangedSolidHalf(
        version: 'identity-only-mismatch',
        valueDelta: 1,
      );

      expect(
        () => ParkinSumAlgorithmSdk(
          configurationIdentity: AlgorithmConfigurationIdentity.defaults(
            gastricParameters: changed,
          ),
        ),
        throwsArgumentError,
      );
    },
  );

  test(
    'SDK rejects result-changing model subtypes with a default identity',
    () {
      expect(
        () => ParkinSumAlgorithmSdk(
          engine: MechanisticConflictEngine(
            absorptionModel: _ShiftedAbsorptionOpportunityModel(),
          ),
          engineVersion: 'test-engine/forged-default-identity',
          configurationIdentity: AlgorithmConfigurationIdentity.defaults(),
        ),
        throwsArgumentError,
      );
    },
  );

  test('canonical digest is independent of map insertion order', () {
    final identity = AlgorithmConfigurationIdentity.defaults();
    final reversed = _reverseMapOrder(identity.canonicalConfiguration);

    expect(
      AlgorithmConfigurationIdentity.digestConfiguration(reversed),
      identity.sha256Digest,
    );
  });

  test('captured canonical configuration is deeply immutable', () {
    final configuration =
        AlgorithmConfigurationIdentity.defaults().canonicalConfiguration;
    expect(
      () => configuration['new_section'] = const {},
      throwsUnsupportedError,
    );
    final gastric = configuration['gastric_emptying'] as Map<String, dynamic>;
    final gastricParameters = gastric['parameters'] as Map<String, dynamic>;
    expect(
      () => gastricParameters['parameter_set_id'] = 'changed',
      throwsUnsupportedError,
    );
    final doseContract =
        configuration['dose_expression_grammar'] as Map<String, dynamic>;
    expect(doseContract['id'], DosageNoteParser.grammarId);
    expect(doseContract['version'], DosageNoteParser.grammarVersion);
    expect(doseContract['sha256'], DosageNoteParser.grammarDigest);
    expect(doseContract['unit_system'], DosageNoteParser.localUnitSystem);
    expect(doseContract['unit_version'], DosageNoteParser.localUnitVersion);
  });

  test('configuration identity deep-copies caller-owned rule collections', () {
    final defaultRules =
        AlgorithmConfigurationIdentity.defaults()
                .canonicalConfiguration['runtime_rule_logic']
            as List<Object?>;
    final callerRules = (jsonDecode(jsonEncode(defaultRules)) as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final identity = AlgorithmConfigurationIdentity.defaults(
      runtimeRules: callerRules,
    );
    final beforeJson = jsonEncode(identity.toJson());
    final beforeDigest = identity.sha256Digest;

    callerRules.first['caller_only'] = true;
    final then = callerRules.first['then'] as Map<String, dynamic>;
    (then['actions'] as List<dynamic>).add({
      'type': 'caller_only',
      'params': <String, dynamic>{},
    });

    expect(jsonEncode(identity.toJson()), beforeJson);
    expect(identity.sha256Digest, beforeDigest);
    final capturedRules =
        identity.canonicalConfiguration['runtime_rule_logic'] as List<Object?>;
    expect(() => capturedRules.add(const {}), throwsUnsupportedError);
    final capturedThen =
        (capturedRules.first as Map<String, dynamic>)['then']
            as Map<String, dynamic>;
    expect(
      () => (capturedThen['actions'] as List<Object?>).add(const {}),
      throwsUnsupportedError,
    );
  });

  test('scoring source refs are defensively copied and digest-stable', () {
    final defaults = NextMealScoringParameterSet.literatureInformedDefault();
    final sourceRefs = <String>['src.internal.prototype.heuristic'];
    final copiedWeight = ScoringWeight(
      id: defaults.conflictOverlap.id,
      label: defaults.conflictOverlap.label,
      value: defaults.conflictOverlap.value,
      sourceRefs: sourceRefs,
      evidenceLevel: defaults.conflictOverlap.evidenceLevel,
      limitation: defaults.conflictOverlap.limitation,
    );
    final scoring = NextMealScoringParameterSet(
      id: 'next_meal_scoring.alias-mutation-fixture',
      conflictOverlap: copiedWeight,
      proteinRedistribution: defaults.proteinRedistribution,
      nutritionAdequacy: defaults.nutritionAdequacy,
      metadataCompleteness: defaults.metadataCompleteness,
      sourceAuthority: defaults.sourceAuthority,
      jurisdictionMatch: defaults.jurisdictionMatch,
      provenanceQuality: defaults.provenanceQuality,
      uncertaintyPenalty: defaults.uncertaintyPenalty,
    );
    final beforeJson = jsonEncode(scoring.toJson());
    final beforeDigest = AlgorithmConfigurationIdentity.defaults(
      scoringParameters: scoring,
    ).sha256Digest;

    sourceRefs.add('src.dailymed.sinemet.label');
    expect(
      () => copiedWeight.sourceRefs.add('src.dailymed.sinemet.label'),
      throwsUnsupportedError,
    );
    expect(
      () => (copiedWeight.toJson()['source_refs'] as List<String>).add(
        'src.dailymed.sinemet.label',
      ),
      throwsUnsupportedError,
    );
    expect(() => scoring.all.add(copiedWeight), throwsUnsupportedError);

    expect(jsonEncode(scoring.toJson()), beforeJson);
    expect(
      AlgorithmConfigurationIdentity.defaults(
        scoringParameters: scoring,
      ).sha256Digest,
      beforeDigest,
    );
  });

  test('provenance collection inputs and getters are deeply immutable', () {
    final allowedNestedList = <Object?>['alpha'];
    final allowedNestedMap = <Object?, Object?>{'items': allowedNestedList};
    final allowedInput = <Object?>[allowedNestedMap];
    final support = AlgorithmParameterSupport.allowedValues(allowedInput);

    final distributionInput = <String, double>{
      'mean': 0.5,
      'standard_deviation': 0.1,
      'lower_bound': 0,
      'upper_bound': 1,
    };
    final distribution = AlgorithmParameterDistribution(
      familyId: 'normal/1',
      parameters: distributionInput,
    );

    final diagnosticInput = <String, double>{'held_out_rmse': 0.125};
    final fitted = _fitIdentity(
      splitId: 'split.train-80_test-20',
      diagnostics: diagnosticInput,
    );
    final originalNestedList = <Object?>['original'];
    final canonicalNestedList = <Object?>['canonical'];
    final originalValue = <Object?, Object?>{'items': originalNestedList};
    final canonicalValue = <Object?, Object?>{'items': canonicalNestedList};
    final sourceIds = <String>['src.internal.prototype.heuristic'];
    final record = AlgorithmParameterProvenanceRecord(
      parameterId: 'test.deep-freeze',
      algorithmIds: const ['algorithm_configuration_identity'],
      displayName: 'Deep freeze fixture',
      semanticId: 'test.semantic.deep-freeze',
      formulaId: 'test.formula/1',
      originalUnit: 'canonical_json',
      canonicalUnit: 'canonical_json',
      originalValue: originalValue,
      canonicalValue: canonicalValue,
      supportedDomain: AlgorithmParameterSupport.schema(
        'test.deep-freeze-schema/1',
      ),
      transformId: 'identity-json/1',
      provenanceStatus: AlgorithmParameterProvenanceStatus.fitted,
      sourceIds: sourceIds,
      reviewDate: '2026-08-17',
      fittedIdentity: fitted,
      limitation: 'Contract fixture only.',
    );
    final manifestInput = <AlgorithmParameterProvenanceRecord>[record];
    final manifest = AlgorithmParameterProvenanceManifest(manifestInput);
    String snapshot() => jsonEncode({
      'support': support.toJson(),
      'distribution': distribution.toJson(),
      'fitted': fitted.toJson(),
      'manifest': manifest.toJson(),
    });

    final beforeJson = snapshot();
    final beforeDigest = AlgorithmConfigurationIdentity.digestConfiguration({
      'support': support.toJson(),
      'distribution': distribution.toJson(),
      'fitted': fitted.toJson(),
      'manifest': manifest.toJson(),
    });

    allowedNestedList.add('caller-mutation');
    allowedNestedMap['new_key'] = 'caller-mutation';
    allowedInput.add('caller-mutation');
    distributionInput['mean'] = 0.75;
    diagnosticInput['held_out_rmse'] = 0.25;
    originalNestedList.add('caller-mutation');
    canonicalNestedList.add('caller-mutation');
    originalValue['new_key'] = 'caller-mutation';
    canonicalValue['new_key'] = 'caller-mutation';
    sourceIds.add('src.dailymed.sinemet.label');
    manifestInput.add(record);

    expect(() => support.allowedValues.add('blocked'), throwsUnsupportedError);
    final frozenAllowed = support.allowedValues.single as Map<String, Object?>;
    expect(() => frozenAllowed['blocked'] = true, throwsUnsupportedError);
    expect(
      () => (frozenAllowed['items'] as List<Object?>).add('blocked'),
      throwsUnsupportedError,
    );
    expect(() => distribution.parameters['mean'] = 0.9, throwsUnsupportedError);
    expect(
      () =>
          (distribution.toJson()['parameters'] as Map<String, double>)['mean'] =
              0.9,
      throwsUnsupportedError,
    );
    expect(
      () => fitted.diagnostics['held_out_rmse'] = 0.9,
      throwsUnsupportedError,
    );
    expect(
      () =>
          (fitted.toJson()['diagnostics']
                  as Map<String, double>)['held_out_rmse'] =
              0.9,
      throwsUnsupportedError,
    );
    expect(() => record.sourceIds.add('blocked'), throwsUnsupportedError);
    expect(
      () => (record.originalValue as Map<String, Object?>)['blocked'] = true,
      throwsUnsupportedError,
    );
    expect(
      () =>
          ((record.canonicalValue as Map<String, Object?>)['items']
                  as List<Object?>)
              .add('blocked'),
      throwsUnsupportedError,
    );
    expect(() => manifest.records.add(record), throwsUnsupportedError);
    expect(
      () => (record.toJson()['source_ids'] as List<String>).add('blocked'),
      throwsUnsupportedError,
    );

    expect(snapshot(), beforeJson);
    expect(
      AlgorithmConfigurationIdentity.digestConfiguration({
        'support': support.toJson(),
        'distribution': distribution.toJson(),
        'fitted': fitted.toJson(),
        'manifest': manifest.toJson(),
      }),
      beforeDigest,
    );
  });

  test('changing any canonical configuration leaf changes the digest', () {
    final identity = AlgorithmConfigurationIdentity.defaults();
    final baseline = identity.sha256Digest;
    final paths = <List<Object>>[];
    _collectLeafPaths(identity.canonicalConfiguration, const [], paths);
    expect(paths, isNotEmpty);

    for (final path in paths) {
      final clone = jsonDecode(jsonEncode(identity.canonicalConfiguration));
      _replaceLeaf(clone, path);
      expect(
        AlgorithmConfigurationIdentity.digestConfiguration(clone),
        isNot(baseline),
        reason: 'digest did not change for ${path.join('/')}',
      );
    }
  });

  test('default parameter provenance is complete, ordered, and explicit', () {
    final identity = AlgorithmConfigurationIdentity.defaults();
    final manifest = identity.parameterProvenanceManifest;

    expect(manifest.records, hasLength(121));
    expect(
      manifest.records.map((record) => record.parameterId),
      orderedEquals(
        manifest.records.map((record) => record.parameterId).toList()..sort(),
      ),
    );
    expect(
      manifest.records.map((record) => record.semanticId).toSet().length,
      manifest.records.length,
    );
    for (final record in manifest.records) {
      expect(record.formulaId, isNotEmpty, reason: record.parameterId);
      expect(record.originalUnit, isNotEmpty, reason: record.parameterId);
      expect(record.canonicalUnit, isNotEmpty, reason: record.parameterId);
      expect(record.transformId, isNotEmpty, reason: record.parameterId);
      expect(record.sourceIds, isNotEmpty, reason: record.parameterId);
      expect(record.reviewDate, matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
      expect(record.limitation, isNotEmpty, reason: record.parameterId);
      expect(
        record.provenanceStatus,
        AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        reason:
            'No default coefficient is measured or fitted; do not overstate ${record.parameterId}.',
      );
    }
    expect(
      manifest.records.map((record) => record.parameterId),
      containsAll([
        'absorption.openness.ir_peak',
        'competition.lnaa_factor.dairy',
        'legacy_nutrition.high_sodium_meal_threshold_mg',
        'legacy_food.score.weight.safety',
        'legacy_food.structure.tie_break_policy',
        'score.conflict_overlap',
        GastricEmptyingParameterIds.generatorStructure,
        GastricEmptyingParameterIds.outputIntegrityContract,
        'trace_provider.gastric_emptying',
        'protein_trend.aggregation_contract',
      ]),
    );
    final proteinTrend = manifest.records.singleWhere(
      (record) => record.parameterId == 'protein_trend.aggregation_contract',
    );
    expect(proteinTrend.algorithmIds, ['protein_trend']);
    expect(
      proteinTrend.formulaId,
      'protein-trend.effective-time-series-and-mean/1',
    );
    expect(proteinTrend.originalUnit, 'canonical_json');
    expect(proteinTrend.canonicalUnit, 'canonical_json');
    expect(
      proteinTrend.originalValue,
      GetProteinTrendUseCase.configurationIdentity,
    );
    expect(
      proteinTrend.canonicalValue,
      GetProteinTrendUseCase.configurationIdentity,
    );
    expect(
      proteinTrend.supportedDomain.schemaId,
      'parkinsum.protein-trend-aggregation/1',
    );
    expect(
      identity.configurationCoverageManifest
          .entryFor('protein_trend')
          .fieldRecordIds,
      contains('protein_trend.aggregation_contract'),
    );
  });

  test(
    'configuration coverage partitions the registry and proves both exact reviewed model boundaries',
    () {
      final identity = AlgorithmConfigurationIdentity.defaults();
      final coverage = identity.configurationCoverageManifest;

      expect(coverage.entries, hasLength(AlgorithmRegistry.all.length));
      expect(coverage.entries, hasLength(65));
      expect(coverage.fieldAndSourceBoundCount, 17);
      expect(coverage.sourceBundleOnlyCount, 48);
      expect(
        coverage.entries.map((entry) => entry.algorithmId),
        orderedEquals(
          coverage.entries.map((entry) => entry.algorithmId).toList()..sort(),
        ),
      );
      expect(
        coverage.entries.map((entry) => entry.algorithmId).toSet(),
        AlgorithmRegistry.all.map((descriptor) => descriptor.id).toSet(),
      );

      final gastric = coverage.entryFor('gastric_emptying');
      expect(
        gastric.mode,
        AlgorithmConfigurationCoverageMode.fieldAndSourceBound,
      );
      expect(gastric.fieldRecordIds, contains('ge.solid.lag_minutes'));
      expect(
        gastric.fieldRecordIds.toSet(),
        GastricEmptyingParameterIds.completeCoverage,
      );
      expect(gastric.toJson()['complete_per_field_coverage_proven'], isTrue);
      expect(gastric.completenessWitness, isNotNull);
      expect(
        gastric.completenessWitness!.ownedSourceSha256.keys.toSet(),
        AlgorithmRegistry.all
            .singleWhere((descriptor) => descriptor.id == 'gastric_emptying')
            .sourcePaths
            .toSet(),
      );
      expect(
        gastric.completenessWitness!.requiredResultSinks,
        containsAll(const [
          'availability',
          'component_profiles',
          'remaining_fraction_curve',
          'emptied_fraction_curve',
          'intestinal_arrival_rate_curve',
          'sensitivity_envelope',
          'wire_representation',
          'trace_provider_binding',
        ]),
      );
      expect(
        gastric.completenessWitness!.dependencyContractSha256.keys.toSet(),
        const {
          'meal_composition_normalizer',
          'runtime_model_applicability_abstention_gate',
        },
      );
      final absorption = coverage.entryFor('levodopa_absorption_opportunity');
      expect(absorption.completePerFieldCoverageProven, isTrue);
      expect(
        absorption.fieldRecordIds.toSet(),
        LevodopaAbsorptionOpportunityParameterIds.completeCoverage,
      );
      expect(absorption.completenessWitness, isNotNull);
      expect(
        absorption.completenessWitness!.ownedSourceSha256.keys.toSet(),
        AlgorithmRegistry.all
            .singleWhere(
              (descriptor) =>
                  descriptor.id == 'levodopa_absorption_opportunity',
            )
            .sourcePaths
            .toSet(),
      );
      expect(
        absorption.completenessWitness!.requiredResultSinks,
        containsAll(const [
          'window',
          'availability',
          'openness_profile',
          'wire_representation',
          'trace_provider_binding',
        ]),
      );
      final parser = coverage.entryFor('dosage_note_parser');
      expect(
        parser.mode,
        AlgorithmConfigurationCoverageMode.fieldAndSourceBound,
      );
      expect(
        parser.fieldRecordIds,
        contains('medication_dose.grammar_identity'),
      );
      expect(parser.completePerFieldCoverageProven, isFalse);
      final parserRecord = identity.parameterProvenanceManifest.records
          .singleWhere(
            (record) =>
                record.parameterId == 'medication_dose.grammar_identity',
          );
      expect(
        parserRecord.canonicalValue,
        identity.canonicalConfiguration['dose_expression_grammar'],
      );
      expect(
        parserRecord.provenanceStatus,
        AlgorithmParameterProvenanceStatus.prototypeHeuristic,
      );
      expect(parser.limitation, contains('unlisted branches'));
      final legacy = coverage.entryFor('legacy_food_recommendations');
      final legacyParameters =
          LegacyFoodRecommendationParameterSet.prototypeDefault();
      expect(
        legacy.mode,
        AlgorithmConfigurationCoverageMode.fieldAndSourceBound,
      );
      expect(legacy.fieldRecordIds.toSet(), {
        ...legacyParameters.allParameterIds,
        LegacyFoodRecommendationProvenancePolicy.parameterId,
      });
      expect(legacy.fieldRecordIds, hasLength(35));
      expect(legacy.toJson()['complete_per_field_coverage_proven'], isFalse);

      for (final record in identity.parameterProvenanceManifest.records) {
        for (final algorithmId in record.algorithmIds) {
          expect(
            coverage.entryFor(algorithmId).fieldRecordIds,
            contains(record.parameterId),
          );
        }
      }
      final json = coverage.toJson();
      expect(json[r'$schema'], AlgorithmConfigurationCoverageManifest.schema);
      expect(json['complete_per_field_coverage_count'], 2);
      expect(json['boundary'], contains('declared configuration boundary'));
    },
  );

  test(
    'custom gastric configuration removes only the gastric exact-default witness',
    () {
      final custom = _gastricWithChangedSolidHalf(
        version: 'custom-gastric-half-time-v1',
        valueDelta: 1,
      );
      final identity = AlgorithmConfigurationIdentity.defaults(
        gastricParameters: custom,
      );
      final coverage = identity.configurationCoverageManifest;
      final gastric = coverage.entryFor('gastric_emptying');
      final absorption = coverage.entryFor('levodopa_absorption_opportunity');

      expect(gastric.completenessWitness, isNull);
      expect(gastric.completePerFieldCoverageProven, isFalse);
      expect(absorption.completenessWitness, isNotNull);
      expect(coverage.completePerFieldCoverageCount, 1);
      expect(
        absorption
            .completenessWitness!
            .dependencyContractSha256['gastric_emptying'],
        AlgorithmConfigurationIdentity.digestConfiguration(
          identity.canonicalConfiguration['gastric_emptying'],
        ),
      );
    },
  );

  test(
    'configuration completion witness fails closed on set or digest drift',
    () {
      final identity = AlgorithmConfigurationIdentity.defaults();
      final coverage = identity.configurationCoverageManifest;
      final valid = coverage
          .entryFor('levodopa_absorption_opportunity')
          .completenessWitness!;

      AlgorithmConfigurationCompletenessWitness copyWitness({
        Iterable<String>? fieldRecordIds,
        Map<String, Iterable<String>>? sinksByField,
        Map<String, String>? sourceDigests,
        Map<String, String>? dependencyDigests,
      }) => AlgorithmConfigurationCompletenessWitness(
        witnessId: valid.witnessId,
        algorithmId: valid.algorithmId,
        reviewedAt: valid.reviewedAt,
        fieldRecordIds: fieldRecordIds ?? valid.fieldRecordIds,
        affectedResultSinksByFieldId:
            sinksByField ?? valid.affectedResultSinksByFieldId,
        requiredResultSinks: valid.requiredResultSinks,
        ownedSourceSha256: sourceDigests ?? valid.ownedSourceSha256,
        configurationSectionSha256: valid.configurationSectionSha256,
        registeredSourceBundleSha256: valid.registeredSourceBundleSha256,
        dependencyContractSha256:
            dependencyDigests ?? valid.dependencyContractSha256,
        reviewEvidenceIds: valid.reviewEvidenceIds,
        completionBoundary: valid.completionBoundary,
        limitation: valid.limitation,
      );

      final missingFields = valid.fieldRecordIds
          .where(
            (id) =>
                id !=
                LevodopaAbsorptionOpportunityParameterIds.referenceIrLagMinutes,
          )
          .toList(growable: false);
      final missingSinks = <String, Iterable<String>>{
        for (final id in missingFields)
          id: valid.affectedResultSinksByFieldId[id]!,
      };
      expect(
        () => AlgorithmConfigurationCoverageManifest.fromRegistry(
          algorithmDescriptors: AlgorithmRegistry.all,
          parameterManifest: identity.parameterProvenanceManifest,
          registeredSourceBundleSha256: AlgorithmConfigurationIdentity
              .registeredAlgorithmSourceBundleSha256,
          dependencyContractSha256ByAlgorithm: {
            valid.algorithmId: valid.dependencyContractSha256,
          },
          completionWitnesses: [
            copyWitness(
              fieldRecordIds: missingFields,
              sinksByField: missingSinks,
            ),
          ],
          configurationSectionSha256ByAlgorithm: {
            valid.algorithmId: valid.configurationSectionSha256,
          },
          implementationSourceSha256:
              AlgorithmConfigurationIdentity.defaultImplementationSourceDigests,
        ),
        throwsArgumentError,
      );

      final staleSources = Map<String, String>.from(valid.ownedSourceSha256);
      staleSources[staleSources.keys.first] =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
      expect(
        () => AlgorithmConfigurationCoverageManifest.fromRegistry(
          algorithmDescriptors: AlgorithmRegistry.all,
          parameterManifest: identity.parameterProvenanceManifest,
          registeredSourceBundleSha256: AlgorithmConfigurationIdentity
              .registeredAlgorithmSourceBundleSha256,
          dependencyContractSha256ByAlgorithm: {
            valid.algorithmId: valid.dependencyContractSha256,
          },
          completionWitnesses: [copyWitness(sourceDigests: staleSources)],
          configurationSectionSha256ByAlgorithm: {
            valid.algorithmId: valid.configurationSectionSha256,
          },
          implementationSourceSha256:
              AlgorithmConfigurationIdentity.defaultImplementationSourceDigests,
        ),
        throwsArgumentError,
      );

      final staleDependencies = Map<String, String>.from(
        valid.dependencyContractSha256,
      );
      staleDependencies[staleDependencies.keys.first] =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
      expect(
        () => AlgorithmConfigurationCoverageManifest.fromRegistry(
          algorithmDescriptors: AlgorithmRegistry.all,
          parameterManifest: identity.parameterProvenanceManifest,
          registeredSourceBundleSha256: AlgorithmConfigurationIdentity
              .registeredAlgorithmSourceBundleSha256,
          dependencyContractSha256ByAlgorithm: {
            valid.algorithmId: valid.dependencyContractSha256,
          },
          completionWitnesses: [
            copyWitness(dependencyDigests: staleDependencies),
          ],
          configurationSectionSha256ByAlgorithm: {
            valid.algorithmId: valid.configurationSectionSha256,
          },
          implementationSourceSha256:
              AlgorithmConfigurationIdentity.defaultImplementationSourceDigests,
        ),
        throwsArgumentError,
      );

      final missingDependencies = Map<String, String>.from(
        valid.dependencyContractSha256,
      )..remove(valid.dependencyContractSha256.keys.first);
      expect(
        () => AlgorithmConfigurationCoverageManifest.fromRegistry(
          algorithmDescriptors: AlgorithmRegistry.all,
          parameterManifest: identity.parameterProvenanceManifest,
          registeredSourceBundleSha256: AlgorithmConfigurationIdentity
              .registeredAlgorithmSourceBundleSha256,
          dependencyContractSha256ByAlgorithm: {
            valid.algorithmId: valid.dependencyContractSha256,
          },
          completionWitnesses: [
            copyWitness(dependencyDigests: missingDependencies),
          ],
          configurationSectionSha256ByAlgorithm: {
            valid.algorithmId: valid.configurationSectionSha256,
          },
          implementationSourceSha256:
              AlgorithmConfigurationIdentity.defaultImplementationSourceDigests,
        ),
        throwsArgumentError,
      );

      final extraDependencies = Map<String, String>.from(
        valid.dependencyContractSha256,
      )..['mechanistic_conflict'] = valid.dependencyContractSha256.values.first;
      expect(
        () => AlgorithmConfigurationCoverageManifest.fromRegistry(
          algorithmDescriptors: AlgorithmRegistry.all,
          parameterManifest: identity.parameterProvenanceManifest,
          registeredSourceBundleSha256: AlgorithmConfigurationIdentity
              .registeredAlgorithmSourceBundleSha256,
          dependencyContractSha256ByAlgorithm: {
            valid.algorithmId: valid.dependencyContractSha256,
          },
          completionWitnesses: [
            copyWitness(dependencyDigests: extraDependencies),
          ],
          configurationSectionSha256ByAlgorithm: {
            valid.algorithmId: valid.configurationSectionSha256,
          },
          implementationSourceSha256:
              AlgorithmConfigurationIdentity.defaultImplementationSourceDigests,
        ),
        throwsArgumentError,
      );
    },
  );

  test('configuration coverage rejects orphan parameter ownership', () {
    expect(
      () => _parameterRecord(
        parameterId: 'test.no-owner',
        semanticId: 'test.semantic.no-owner',
        algorithmIds: const [],
      ),
      throwsArgumentError,
    );
    expect(
      () => _parameterRecord(
        parameterId: 'test.duplicate-owner',
        semanticId: 'test.semantic.duplicate-owner',
        algorithmIds: const [
          'algorithm_configuration_identity',
          'algorithm_configuration_identity',
        ],
      ),
      throwsArgumentError,
    );
    final orphan = _parameterRecord(
      parameterId: 'test.orphan',
      semanticId: 'test.semantic.orphan',
      algorithmIds: const ['not_registered'],
    );
    expect(
      () => AlgorithmConfigurationCoverageManifest.fromRegistry(
        algorithmDescriptors: AlgorithmRegistry.all,
        parameterManifest: AlgorithmParameterProvenanceManifest([orphan]),
        registeredSourceBundleSha256: AlgorithmConfigurationIdentity
            .registeredAlgorithmSourceBundleSha256,
        dependencyContractSha256ByAlgorithm: const {},
      ),
      throwsArgumentError,
    );
    final descriptor = AlgorithmRegistry.all.first;
    final validRecord = _parameterRecord(
      parameterId: 'test.duplicate-registry',
      semanticId: 'test.semantic.duplicate-registry',
      algorithmIds: [descriptor.id],
    );
    final manifest = AlgorithmParameterProvenanceManifest([validRecord]);
    expect(
      () => AlgorithmConfigurationCoverageManifest.fromRegistry(
        algorithmDescriptors: [descriptor, descriptor],
        parameterManifest: manifest,
        registeredSourceBundleSha256: AlgorithmConfigurationIdentity
            .registeredAlgorithmSourceBundleSha256,
        dependencyContractSha256ByAlgorithm: const {},
      ),
      throwsArgumentError,
    );
    expect(
      () => AlgorithmConfigurationCoverageManifest.fromRegistry(
        algorithmDescriptors: [descriptor],
        parameterManifest: manifest,
        registeredSourceBundleSha256: 'not-a-digest',
        dependencyContractSha256ByAlgorithm: const {},
      ),
      throwsArgumentError,
    );
  });

  test('IR-only absorption identity has no dormant ER claims', () {
    final identity = AlgorithmConfigurationIdentity.defaults();
    final absorption =
        identity.canonicalConfiguration['levodopa_absorption_opportunity']
            as Map<String, dynamic>;
    final absorptionParameters =
        absorption['parameters'] as Map<String, dynamic>;
    const retiredConfigurationKeys = {
      'reference_er_lag_minutes',
      'reference_er_duration_minutes',
      'er_peak_openness',
      'er_tail_openness',
    };
    expect(
      absorptionParameters.keys.toSet().intersection(retiredConfigurationKeys),
      isEmpty,
    );

    const retiredParameterIds = {
      'absorption.er.reference_lag_minutes',
      'absorption.er.reference_duration_minutes',
      'absorption.openness.er_peak',
      'absorption.openness.er_tail',
    };
    final absorptionRecords = identity.parameterProvenanceManifest.records
        .where((record) => record.parameterId.startsWith('absorption.'))
        .toList(growable: false);
    expect(
      absorptionRecords
          .map((record) => record.parameterId)
          .toSet()
          .intersection(retiredParameterIds),
      isEmpty,
    );
    const retiredSources = {
      'src.dailymed.sinemet.extended.label',
      'src.crevoisier.dualrelease.food.2003',
      'src.contin.levodopa.pk.2010',
    };
    expect(
      absorptionRecords
          .expand((record) => record.sourceIds)
          .toSet()
          .intersection(retiredSources),
      isEmpty,
    );
    expect(
      absorptionRecords.map((record) => record.formulaId).toSet(),
      containsAll({
        'levodopa.absorption.ir-window/1',
        'levodopa.absorption.ir-openness/1',
      }),
    );
  });

  test(
    'every explicitly modeled configuration field has a provenance record',
    () {
      final identity = AlgorithmConfigurationIdentity.defaults();
      final config = identity.canonicalConfiguration;
      final records = {
        for (final record in identity.parameterProvenanceManifest.records)
          record.parameterId: record,
      };
      void expectRecordValue(String id, Object? value) {
        final record = records[id];
        expect(record, isNotNull, reason: 'missing provenance record for $id');
        expect(
          AlgorithmConfigurationIdentity.digestConfiguration(
            record!.canonicalValue,
          ),
          AlgorithmConfigurationIdentity.digestConfiguration(value),
          reason: 'provenance value drift for $id',
        );
      }

      final gastric = GastricEmptyingParameterSet.literatureInformedDefault();
      for (final parameter in gastric.all) {
        expectRecordValue(parameter.id, parameter.value);
      }
      final gastricConfiguration =
          config['gastric_emptying'] as Map<String, dynamic>;
      expect(
        gastricConfiguration[r'$schema'],
        'parkinsum.gastric-emptying-configuration/1',
      );
      expectRecordValue(
        GastricEmptyingParameterIds.generatorStructure,
        gastricConfiguration['generator_structure'],
      );
      expectRecordValue(
        GastricEmptyingParameterIds.outputIntegrityContract,
        gastricConfiguration['output_integrity_contract'],
      );
      final absorption =
          config['levodopa_absorption_opportunity'] as Map<String, dynamic>;
      final absorptionParameters =
          absorption['parameters'] as Map<String, dynamic>;
      const absorptionIds = <String, String>{
        'reference_ir_lag_minutes': 'absorption.ir.reference_lag_minutes',
        'reference_ir_duration_minutes':
            'absorption.ir.reference_duration_minutes',
        'illustrative_meal_delay_minutes':
            'absorption.meal.illustrative_delay_minutes',
        'high_residual_threshold': 'absorption.meal.high_residual_threshold',
        'moderate_residual_threshold':
            'absorption.meal.moderate_residual_threshold',
        'high_residual_end_delay_multiplier':
            'absorption.meal.high_end_delay_multiplier',
        'moderate_residual_shift_divisor':
            'absorption.meal.moderate_shift_divisor',
        'peak_offset_duration_divisor':
            'absorption.ir.peak_offset_duration_divisor',
        'openness_sample_stride_minutes':
            'absorption.openness.sample_stride_minutes',
        'ir_peak_openness': 'absorption.openness.ir_peak',
        'ir_tail_openness': 'absorption.openness.ir_tail',
      };
      for (final entry in absorptionIds.entries) {
        expectRecordValue(entry.value, absorptionParameters[entry.key]);
      }
      expectRecordValue(
        LevodopaAbsorptionOpportunityParameterIds.generatorStructure,
        absorption['generator_structure'],
      );
      expectRecordValue(
        LevodopaAbsorptionOpportunityParameterIds.outputIntegrityContract,
        absorption['output_integrity_contract'],
      );

      final competition =
          config['amino_acid_competition'] as Map<String, dynamic>;
      expectRecordValue(
        'competition.reference_protein_g',
        competition['reference_protein_g'],
      );
      expectRecordValue(
        'competition.sample_stride_minutes',
        competition['sample_stride_minutes'],
      );
      for (final factor
          in (competition['protein_source_lnaa_factors'] as List).cast<Map>()) {
        expectRecordValue(
          'competition.lnaa_factor.${factor['source_type']}',
          factor['load_factor'],
        );
      }

      final distribution =
          config['protein_distribution'] as Map<String, dynamic>;
      for (final entry in distribution.entries) {
        expectRecordValue('protein_distribution.${entry.key}', entry.value);
      }
      final scoring = config['candidate_scoring'] as Map<String, dynamic>;
      final weights = scoring['weights'] as Map<String, dynamic>;
      for (final value in weights.values.whereType<Map>()) {
        expectRecordValue(value['id'] as String, value['value']);
      }
      expectRecordValue(
        'candidate_score.min_sample_count',
        scoring['min_sample_count'],
      );
      expectRecordValue(
        'candidate_score.max_sample_count',
        scoring['max_sample_count'],
      );
      expectRecordValue(
        'candidate_score.sample_stride_minutes',
        scoring['sample_stride_minutes'],
      );
      final legacy =
          config['legacy_nutrition_thresholds'] as Map<String, dynamic>;
      for (final entry in legacy.entries) {
        expectRecordValue('legacy_nutrition.${entry.key}', entry.value);
      }
      final legacyFood =
          config['legacy_food_recommendations'] as Map<String, dynamic>;
      final expectedLegacy =
          LegacyFoodRecommendationParameterSet.prototypeDefault();
      expect(
        AlgorithmConfigurationIdentity.digestConfiguration(legacyFood),
        AlgorithmConfigurationIdentity.digestConfiguration(
          expectedLegacy.toJson(),
        ),
      );
      final legacyRecords = identity.parameterProvenanceManifest.records
          .where(
            (record) =>
                record.algorithmIds.length == 1 &&
                record.algorithmIds.single == 'legacy_food_recommendations',
          )
          .toList(growable: false);
      expect(legacyRecords.map((record) => record.parameterId).toSet(), {
        ...expectedLegacy.allParameterIds,
        LegacyFoodRecommendationProvenancePolicy.parameterId,
      });
      for (final parameter in expectedLegacy.parameters) {
        expectRecordValue(parameter.id, parameter.value);
        final record = legacyRecords.singleWhere(
          (candidate) => candidate.parameterId == parameter.id,
        );
        expect(record.formulaId, parameter.formulaId);
        expect(record.canonicalUnit, parameter.unit);
        expect(record.sourceIds, parameter.sourceRefs);
        expect(record.reviewDate, expectedLegacy.lastReviewed);
        expect(record.limitation, contains('not fitted'));
      }
      expectRecordValue(
        LegacyFoodRecommendationParameterIds.tieBreakPolicy,
        expectedLegacy.tieBreakPolicy,
      );
      expectRecordValue(
        LegacyFoodRecommendationProvenancePolicy.parameterId,
        LegacyFoodRecommendationProvenancePolicy.canonicalValue,
      );
      for (final rule in (config['runtime_rule_logic'] as List).cast<Map>()) {
        expectRecordValue('runtime_rule.${rule['rule_id']}.logic', rule);
      }
      for (final descriptor
          in (config['algorithm_manifest'] as List).cast<Map>()) {
        final provider = descriptor['trace_provider_id'];
        if (provider != null) {
          expectRecordValue('trace_provider.${descriptor['id']}', provider);
        }
      }
    },
  );

  test('parameter provenance rejects duplicate and malformed declarations', () {
    final first = _parameterRecord(
      parameterId: 'test.alpha',
      semanticId: 'test.semantic.alpha',
    );
    final duplicateParameter = _parameterRecord(
      parameterId: 'test.alpha',
      semanticId: 'test.semantic.beta',
    );
    final duplicateSemantic = _parameterRecord(
      parameterId: 'test.beta',
      semanticId: 'test.semantic.alpha',
    );

    expect(
      () => AlgorithmParameterProvenanceManifest([first, duplicateParameter]),
      throwsArgumentError,
    );
    expect(
      () => AlgorithmParameterProvenanceManifest([first, duplicateSemantic]),
      throwsArgumentError,
    );
    expect(
      () => _parameterRecord(
        parameterId: 'test.nan',
        semanticId: 'test.semantic.nan',
        value: double.nan,
      ),
      throwsArgumentError,
    );
    expect(
      () => _fitIdentity(
        splitId: 'split.train-80_test-20',
        diagnostics: const {'participant_001_error': 0.25},
      ),
      throwsArgumentError,
    );
    expect(
      () => _parameterRecord(
        parameterId: 'test.out-of-range',
        semanticId: 'test.semantic.out-of-range',
        value: 1.1,
      ),
      throwsArgumentError,
    );
    expect(
      () => _parameterRecord(
        parameterId: 'test.bad-date',
        semanticId: 'test.semantic.bad-date',
        reviewDate: '2026-02-30',
      ),
      throwsArgumentError,
    );
    expect(
      () => AlgorithmConfigurationIdentity.digestConfiguration({
        'bad': double.infinity,
      }),
      throwsArgumentError,
    );
    expect(
      () => AlgorithmConfigurationIdentity.digestConfiguration({
        'unordered': <String>{'a', 'b'},
      }),
      throwsArgumentError,
    );
    expect(
      () => AlgorithmParameterProvenanceRecord(
        parameterId: 'test.bad-source',
        algorithmIds: const ['algorithm_configuration_identity'],
        displayName: 'Bad source fixture',
        semanticId: 'test.semantic.bad-source',
        formulaId: 'test.formula/1',
        originalUnit: 'ratio_0_1',
        canonicalUnit: 'ratio_0_1',
        originalValue: 0.5,
        canonicalValue: 0.5,
        supportedDomain: AlgorithmParameterSupport.numericRange(
          minimum: 0,
          maximum: 1,
        ),
        transformId: 'identity/1',
        provenanceStatus: AlgorithmParameterProvenanceStatus.prototypeHeuristic,
        sourceIds: const [
          'src.internal.prototype.heuristic',
          'src.internal.prototype.heuristic',
        ],
        reviewDate: '2026-08-17',
        limitation: 'Fixture only.',
      ),
      throwsArgumentError,
    );
  });

  test('fitted provenance is bidirectionally fail-closed', () {
    final fit = _fitIdentity(splitId: 'split.train-80_test-20');
    expect(
      fit.toJson(),
      containsPair(
        r'$schema',
        'parkinsum.algorithm-fitted-parameter-identity/1',
      ),
    );
    expect(
      fit.toJson()['calibration_dataset_content_sha256'],
      matches(RegExp(r'^[a-f0-9]{64}$')),
    );
    expect(
      fit.toJson()['split_manifest_sha256'],
      matches(RegExp(r'^[a-f0-9]{64}$')),
    );
    expect(
      () => _parameterRecord(
        parameterId: 'test.fitted.missing',
        semanticId: 'test.semantic.fitted-missing',
        status: AlgorithmParameterProvenanceStatus.fitted,
      ),
      throwsArgumentError,
    );
    expect(
      () => _parameterRecord(
        parameterId: 'test.not-fitted.with-fit',
        semanticId: 'test.semantic.not-fitted',
        fittedIdentity: fit,
      ),
      throwsArgumentError,
    );

    String digestFit(AlgorithmFittedParameterIdentity identity) =>
        AlgorithmConfigurationIdentity.digestConfiguration({
          'parameter_provenance_manifest':
              AlgorithmParameterProvenanceManifest([
                _parameterRecord(
                  parameterId: 'test.fitted',
                  semanticId: 'test.semantic.fitted',
                  status: AlgorithmParameterProvenanceStatus.fitted,
                  fittedIdentity: identity,
                ),
              ]).toJson(),
        });

    final baselineDigest = digestFit(fit);
    for (final changed in [
      _fitIdentity(
        splitId: 'split.train-80_test-20',
        datasetId: 'dataset.synthetic-calibration-v2',
      ),
      _fitIdentity(
        splitId: 'split.train-80_test-20',
        datasetContentHash: List.filled(64, '9').join(),
      ),
      _fitIdentity(splitId: 'split.site-held-out'),
      _fitIdentity(
        splitId: 'split.train-80_test-20',
        splitManifestHash: List.filled(64, 'a').join(),
      ),
      _fitIdentity(
        splitId: 'split.train-80_test-20',
        estimatorId: 'estimator.bayesian-v2',
      ),
      _fitIdentity(
        splitId: 'split.train-80_test-20',
        codeHash: List.filled(64, '4').join(),
      ),
      _fitIdentity(
        splitId: 'split.train-80_test-20',
        environmentHash: List.filled(64, '5').join(),
      ),
      _fitIdentity(
        splitId: 'split.train-80_test-20',
        lineageHash: List.filled(64, '6').join(),
      ),
      _fitIdentity(
        splitId: 'split.train-80_test-20',
        diagnostics: const {'held_out_rmse': 0.25},
      ),
    ]) {
      expect(digestFit(changed), isNot(baselineDigest));
    }

    expect(
      () => _fitIdentity(
        splitId: 'split.train-80_test-20',
        datasetContentHash: 'not-a-sha256',
      ),
      throwsArgumentError,
    );
    expect(
      () => _fitIdentity(
        splitId: 'split.train-80_test-20',
        splitManifestHash: List.filled(64, 'z').join(),
      ),
      throwsArgumentError,
    );
  });

  test(
    'distribution provenance rejects missing, inverted, and nonfinite bounds',
    () {
      expect(
        () => AlgorithmParameterDistribution(
          familyId: 'normal/1',
          parameters: const {'mean': 0.5, 'standard_deviation': 0.1},
        ),
        throwsArgumentError,
      );
      expect(
        () => AlgorithmParameterDistribution(
          familyId: 'normal/1',
          parameters: const {
            'mean': 2,
            'standard_deviation': 0.1,
            'lower_bound': 0,
            'upper_bound': 1,
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => AlgorithmParameterDistribution(
          familyId: 'normal/1',
          parameters: const {
            'mean': 0.5,
            'standard_deviation': 0,
            'lower_bound': 0,
            'upper_bound': 1,
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => AlgorithmParameterDistribution(
          familyId: 'normal/1',
          parameters: const {
            'mean': 0.5,
            'standard_deviation': 0.1,
            'lower_bound': 1,
            'upper_bound': 0,
          },
        ),
        throwsArgumentError,
      );
      expect(
        () => AlgorithmParameterDistribution(
          familyId: 'normal/1',
          parameters: {
            'mean': 0.5,
            'standard_deviation': double.nan,
            'lower_bound': 0,
            'upper_bound': 1,
          },
        ),
        throwsArgumentError,
      );
      final distribution = AlgorithmParameterDistribution(
        familyId: 'normal/1',
        parameters: const {
          'mean': 0.5,
          'standard_deviation': 0.1,
          'lower_bound': 0,
          'upper_bound': 2,
        },
      );
      expect(
        () => AlgorithmParameterProvenanceRecord(
          parameterId: 'test.distribution',
          algorithmIds: const ['algorithm_configuration_identity'],
          displayName: 'Distribution fixture',
          semanticId: 'test.semantic.distribution',
          formulaId: 'test.formula/1',
          originalUnit: 'ratio_0_1',
          canonicalUnit: 'ratio_0_1',
          distribution: distribution,
          supportedDomain: AlgorithmParameterSupport.numericRange(
            minimum: 0,
            maximum: 1,
          ),
          transformId: 'identity/1',
          provenanceStatus: AlgorithmParameterProvenanceStatus.fitted,
          sourceIds: const ['src.internal.prototype.heuristic'],
          reviewDate: '2026-08-17',
          fittedIdentity: _fitIdentity(splitId: 'split.train-80_test-20'),
          limitation: 'Fixture only.',
        ),
        throwsArgumentError,
      );
    },
  );

  test('identity-bearing value objects stay final at library boundaries', () {
    const declarationsByPath = <String, List<String>>{
      'lib/algorithm_sdk/algorithm_configuration_identity.dart': [
        'final class AlgorithmConfigurationIdentity',
      ],
      'lib/algorithm_sdk/algorithm_parameter_provenance.dart': [
        'final class AlgorithmParameterSupport',
        'final class AlgorithmParameterDistribution',
        'final class AlgorithmFittedParameterIdentity',
        'final class AlgorithmParameterProvenanceRecord',
        'final class AlgorithmParameterProvenanceManifest',
        'final class AlgorithmConfigurationCompletenessWitness',
        'final class AlgorithmConfigurationCoverageEntry',
        'final class AlgorithmConfigurationCoverageManifest',
      ],
      'lib/domain/entities/gastric_emptying_parameters.dart': [
        'abstract final class GastricEmptyingParameterIds',
        'final class GastricEmptyingParameter<T extends num>',
        'final class GastricEmptyingParameterSet',
      ],
      'lib/domain/entities/gastric_emptying_profile.dart': [
        'abstract final class GastricEmptyingOutputContract',
      ],
      'lib/domain/entities/levodopa_absorption_opportunity_parameters.dart': [
        'final class LevodopaAbsorptionOpportunityParameterSet',
      ],
      'lib/domain/usecases/next_meal_scoring_parameters.dart': [
        'final class ScoringWeight',
        'final class NextMealScoringParameterSet',
      ],
      'lib/domain/usecases/legacy_food_recommendation_parameters.dart': [
        'final class LegacyFoodRecommendationScalar',
        'final class LegacyFoodRecommendationParameterSet',
      ],
    };

    for (final entry in declarationsByPath.entries) {
      final source = File(entry.key).readAsStringSync();
      for (final declaration in entry.value) {
        expect(
          source,
          contains(declaration),
          reason:
              '$declaration must remain non-implementable outside its library; '
              'otherwise getters and toJson can be spoofed independently.',
        );
      }
    }
  });

  test('implementation fingerprints match every production source file', () {
    for (final entry
        in AlgorithmConfigurationIdentity
            .defaultImplementationSourceDigests
            .entries) {
      final file = File(entry.key);
      expect(file.existsSync(), isTrue, reason: entry.key);
      final actual = sha256.convert(file.readAsBytesSync()).toString();
      expect(
        actual,
        entry.value,
        reason:
            '${entry.key} changed. Review whether its result-affecting '
            'configuration changed, then update the canonical identity.',
      );
    }
  });

  test('registered algorithm source bundle matches the full manifest', () {
    final paths =
        AlgorithmRegistry.all
            .expand((descriptor) => descriptor.sourcePaths)
            .where(
              (path) =>
                  path !=
                  'lib/algorithm_sdk/algorithm_configuration_identity.dart',
            )
            .toSet()
            .toList()
          ..sort();
    final payload = StringBuffer();
    for (final path in paths) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: path);
      final fileDigest = sha256.convert(file.readAsBytesSync());
      payload.writeln('$path:$fileDigest');
    }
    final bundleDigest = sha256
        .convert(utf8.encode(payload.toString()))
        .toString();
    expect(
      bundleDigest,
      AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
      reason:
          'A registered algorithm source changed. Review the result/config '
          'impact and update the canonical source-bundle identity.',
    );
  });
}

AlgorithmParameterProvenanceRecord _parameterRecord({
  required String parameterId,
  required String semanticId,
  List<String> algorithmIds = const ['algorithm_configuration_identity'],
  double value = 0.5,
  AlgorithmParameterProvenanceStatus status =
      AlgorithmParameterProvenanceStatus.prototypeHeuristic,
  AlgorithmFittedParameterIdentity? fittedIdentity,
  String reviewDate = '2026-08-17',
}) => AlgorithmParameterProvenanceRecord(
  parameterId: parameterId,
  algorithmIds: algorithmIds,
  displayName: 'Parameter fixture',
  semanticId: semanticId,
  formulaId: 'test.formula/1',
  originalUnit: 'ratio_0_1',
  canonicalUnit: 'ratio_0_1',
  originalValue: value,
  canonicalValue: value,
  supportedDomain: AlgorithmParameterSupport.numericRange(
    minimum: 0,
    maximum: 1,
  ),
  transformId: 'identity/1',
  provenanceStatus: status,
  sourceIds: const ['src.internal.prototype.heuristic'],
  reviewDate: reviewDate,
  fittedIdentity: fittedIdentity,
  limitation: 'Contract fixture only.',
);

AlgorithmFittedParameterIdentity _fitIdentity({
  required String splitId,
  String datasetId = 'dataset.synthetic-calibration-v1',
  String? datasetContentHash,
  String? splitManifestHash,
  String estimatorId = 'estimator.robust-regression-v1',
  String? codeHash,
  String? environmentHash,
  String? lineageHash,
  Map<String, double> diagnostics = const {'held_out_rmse': 0.125},
}) => AlgorithmFittedParameterIdentity(
  calibrationDatasetId: datasetId,
  calibrationDatasetContentSha256:
      datasetContentHash ?? List.filled(64, '7').join(),
  splitId: splitId,
  splitManifestSha256: splitManifestHash ?? List.filled(64, '8').join(),
  estimatorId: estimatorId,
  estimatorCodeSha256: codeHash ?? List.filled(64, '1').join(),
  environmentLockSha256: environmentHash ?? List.filled(64, '2').join(),
  rawToAnalysisLineageSha256: lineageHash ?? List.filled(64, '3').join(),
  diagnostics: diagnostics,
);

GastricEmptyingParameterSet _gastricWithChangedSolidHalf({
  required String version,
  required double valueDelta,
}) {
  final defaults = GastricEmptyingParameterSet.literatureInformedDefault();
  return GastricEmptyingParameterSet(
    id: defaults.id,
    version: version,
    lastReviewed: defaults.lastReviewed,
    solidLagMinutes: defaults.solidLagMinutes,
    solidHalfMinutes: GastricEmptyingParameter<double>(
      id: defaults.solidHalfMinutes.id,
      label: defaults.solidHalfMinutes.label,
      value: defaults.solidHalfMinutes.value + valueDelta,
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

Object? _reverseMapOrder(Object? value) {
  if (value is Map) {
    final keys = value.keys.toList().reversed;
    return <String, dynamic>{
      for (final key in keys) key.toString(): _reverseMapOrder(value[key]),
    };
  }
  if (value is List) {
    return value.map(_reverseMapOrder).toList(growable: false);
  }
  return value;
}

void _collectLeafPaths(
  Object? value,
  List<Object> prefix,
  List<List<Object>> output,
) {
  if (value is Map) {
    for (final entry in value.entries) {
      _collectLeafPaths(entry.value, [...prefix, entry.key.toString()], output);
    }
    return;
  }
  if (value is List) {
    for (var index = 0; index < value.length; index++) {
      _collectLeafPaths(value[index], [...prefix, index], output);
    }
    return;
  }
  output.add(prefix);
}

void _replaceLeaf(Object? root, List<Object> path) {
  Object? parent = root;
  for (final segment in path.take(path.length - 1)) {
    parent = segment is int
        ? (parent as List<dynamic>)[segment]
        : (parent as Map<String, dynamic>)[segment];
  }
  final last = path.last;
  final current = last is int
      ? (parent as List<dynamic>)[last]
      : (parent as Map<String, dynamic>)[last];
  final replacement = switch (current) {
    bool value => !value,
    int value => value + 1,
    double value => value + 0.125,
    String value => '$value#changed',
    null => '__was_null__',
    _ => throw StateError('Unexpected configuration leaf: $current'),
  };
  if (last is int) {
    (parent as List<dynamic>)[last] = replacement;
  } else {
    (parent as Map<String, dynamic>)[last as String] = replacement;
  }
}

TimeAxisConflictContext _noMealContext() => TimeAxisConflictContext(
  referenceMinute: 100,
  medicationEvents: [
    MedicationTimelineEvent(
      id: 'dose_1',
      minute: 100,
      context: const NormalizedMedicationContext(
        drugProductVariant: 'levodopa_ir_100',
        activeIngredients: ['levodopa'],
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'CA',
        sourceDocId: 'label_1',
        labelSection: 'Dosage forms and strengths',
        extractionConfidence: 1,
        limitationText: 'Synthetic SDK contract fixture.',
      ),
    ),
  ],
  mealEvents: const [],
  userDefinedWindow: null,
);

TimeAxisConflictContext _sdkMealContext() => TimeAxisConflictContext(
  referenceMinute: 0,
  medicationEvents: [
    MedicationTimelineEvent(
      id: 'sdk_dose',
      minute: 30,
      context: NormalizedMedicationContext(
        drugProductVariant: 'synthetic:carbidopa-levodopa-ir',
        activeIngredients: ['carbidopa', 'levodopa'],
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'CA',
        sourceDocId: 'synthetic:sdk-contract',
        labelSection: 'Synthetic SDK contract fixture',
        extractionConfidence: 1,
        limitationText: 'Synthetic SDK contract fixture.',
      ),
    ),
  ],
  mealEvents: [
    MealTimelineEvent(
      id: 'sdk_meal',
      minute: 0,
      compositionId: 'sdk_meal_composition',
      physicalForm: MealPhysicalForm.solid,
    ),
  ],
);

MealComposition _sdkMealComposition({
  double proteinGrams = 20,
  double portionGrams = 100,
  double compositionCompleteness = 1,
}) => MealComposition(
  id: 'sdk_meal_composition',
  totalCalories: 250,
  proteinGrams: proteinGrams,
  fatGrams: 5,
  fiberGrams: 2,
  carbohydrateGrams: 30,
  liquidFraction: 0,
  mealPhysicalForm: MealPhysicalForm.solid,
  portionSizeBand: PortionSizeBand.medium,
  proteinAmountBand: AmountBand.high,
  fatAmountBand: AmountBand.moderate,
  fiberAmountBand: AmountBand.low,
  calorieBand: AmountBand.moderate,
  compositionCompleteness: compositionCompleteness,
  missingFields: const [],
  foodComponents: [
    FoodComponent(
      id: 'sdk_food',
      name: 'SDK meal fixture',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: 20,
      fatGrams: 5,
      fiberGrams: 2,
      carbohydrateGrams: 30,
      calories: 250,
      portionGrams: portionGrams,
      sourceDocId: 'synthetic:sdk-contract',
    ),
  ],
);

/// A deliberately result-changing subtype that retains all default public
/// constants. Parameter-only identity checks cannot distinguish it.
class _ShiftedAbsorptionOpportunityModel
    extends LevodopaAbsorptionOpportunityModel {
  @override
  AbsorptionOpportunityWindow build({
    required MedicationTimelineEvent medication,
    GastricEmptyingProfile? overlappingMealProfile,
  }) {
    final base = super.build(
      medication: medication,
      overlappingMealProfile: overlappingMealProfile,
    );
    return AbsorptionOpportunityWindow(
      medicationEventId: base.medicationEventId,
      window: TimelineWindow(
        startMinute: base.window.startMinute + 60,
        endMinute: base.window.endMinute + 60,
      ),
      peakMinute: base.peakMinute + 60,
      delayedArrivalLikelihood: base.delayedArrivalLikelihood,
      uncertaintyBand: base.uncertaintyBand,
      assumptions: base.assumptions,
      missingInputs: base.missingInputs,
      sourceRefs: base.sourceRefs,
      opennessProfile: [
        for (final sample in base.opennessProfile)
          AbsorptionOpennessSample(
            minute: sample.minute + 60,
            openness: sample.openness,
          ),
      ],
    );
  }
}
