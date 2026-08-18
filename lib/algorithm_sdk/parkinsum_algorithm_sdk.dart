library;

export 'algorithm_configuration_identity.dart';
export 'algorithm_component_graph_identity.dart';
export 'algorithm_parameter_provenance.dart';

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'algorithm_component_graph_identity.dart';
import 'algorithm_configuration_identity.dart';
import '../domain/entities/meal_composition.dart';
import '../domain/entities/mechanistic_conflict_result.dart';
import '../domain/entities/time_axis_events.dart';
import '../domain/usecases/mechanistic_conflict_engine.dart';

/// Stable, UI-independent entry point for consumers of the deterministic core.
///
/// The Flutter feature layer may render this envelope, but it does not own the
/// formula or schema. This mirrors the SDK/core separation used by mature open
/// health platforms and prevents a UI refactor from silently changing results.
class ParkinSumAlgorithmSdk {
  static const String evaluationSchema = 'parkinsum.algorithm-evaluation/4';
  static const String defaultEngineVersion =
      'mechanistic-conflict/2026.08.17-v2';

  final MechanisticConflictEngine engine;
  final String engineVersion;
  final AlgorithmConfigurationIdentity configurationIdentity;

  ParkinSumAlgorithmSdk({
    MechanisticConflictEngine? engine,
    String? engineVersion,
    AlgorithmConfigurationIdentity? configurationIdentity,
  }) : engine = engine ?? MechanisticConflictEngine(),
       engineVersion = _resolveEngineVersion(engine, engineVersion),
       configurationIdentity = _resolveConfigurationIdentity(
         engine,
         configurationIdentity,
       ) {
    // Validate the resolved engine, not only the nullable constructor input.
    // Otherwise a caller could omit [engine], supply an identity for different
    // parameters, and bind that identity to the actual default engine.
    AlgorithmComponentGraphIdentityValidator.validateConflictEngine(
      engine: this.engine,
      identity: this.configurationIdentity,
      graphLabel: 'sdk.engine',
    );
  }

  AlgorithmEvaluationEnvelope evaluateConflict({
    required String evaluationId,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    String? preferredMealId,
  }) {
    if (!_safeId.hasMatch(evaluationId)) {
      throw ArgumentError.value(
        evaluationId,
        'evaluationId',
        'must be a safe, non-sensitive identifier',
      );
    }
    final result = engine.evaluate(
      context: context,
      mealCompositionsById: mealCompositionsById,
      resultId: evaluationId,
      preferredMealId: preferredMealId,
    );
    final parameters = engine.gastricEmptyingModel.parameters;
    final gastricParameterSetDigest = sha256
        .convert(utf8.encode(jsonEncode(parameters.toJson())))
        .toString();
    return AlgorithmEvaluationEnvelope(
      schema: evaluationSchema,
      engineVersion: engineVersion,
      parameterSetId: parameters.id,
      parameterSetVersion: parameters.version,
      parameterSetDigest: gastricParameterSetDigest,
      configurationIdentity: configurationIdentity,
      result: result,
    );
  }

  static String _resolveEngineVersion(
    MechanisticConflictEngine? injectedEngine,
    String? requestedVersion,
  ) {
    final version = requestedVersion?.trim();
    if (injectedEngine != null && (version == null || version.isEmpty)) {
      throw ArgumentError(
        'An injected algorithm engine requires an explicit engineVersion.',
      );
    }
    if (version != null && version.isNotEmpty) {
      if (!_safeVersion.hasMatch(version)) {
        throw ArgumentError.value(
          requestedVersion,
          'engineVersion',
          'must be a safe version identifier',
        );
      }
      return version;
    }
    return defaultEngineVersion;
  }

  static AlgorithmConfigurationIdentity _resolveConfigurationIdentity(
    MechanisticConflictEngine? injectedEngine,
    AlgorithmConfigurationIdentity? requestedIdentity,
  ) {
    if (injectedEngine != null && requestedIdentity == null) {
      throw ArgumentError(
        'An injected algorithm engine requires an explicit '
        'AlgorithmConfigurationIdentity.',
      );
    }
    return requestedIdentity ?? AlgorithmConfigurationIdentity.defaults();
  }

  static final RegExp _safeId = RegExp(r'^[A-Za-z0-9._:-]{1,160}$');
  static final RegExp _safeVersion = RegExp(r'^[A-Za-z0-9._:/-]{1,160}$');
}

class AlgorithmEvaluationEnvelope {
  final String schema;
  final String engineVersion;
  final String parameterSetId;
  final String parameterSetVersion;
  final String parameterSetDigest;
  final AlgorithmConfigurationIdentity configurationIdentity;
  final MechanisticConflictResult result;

  const AlgorithmEvaluationEnvelope({
    required this.schema,
    required this.engineVersion,
    required this.parameterSetId,
    required this.parameterSetVersion,
    required this.parameterSetDigest,
    required this.configurationIdentity,
    required this.result,
  });

  String get configurationDigest => configurationIdentity.sha256Digest;
  String get configurationId => configurationIdentity.id;
  String get configurationVersion => configurationIdentity.version;

  Map<String, dynamic> toJson() => {
    r'$schema': schema,
    'engine_version': engineVersion,
    'configuration_manifest_schema': AlgorithmConfigurationIdentity.schema,
    'configuration_digest': configurationDigest,
    'parameter_set': {
      'id': parameterSetId,
      'version': parameterSetVersion,
      'sha256': parameterSetDigest,
    },
    'configuration_identity': configurationIdentity.toJson(),
    'result': result.toJson(),
  };
}
