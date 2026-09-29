import 'dart:convert';

import 'package:crypto/crypto.dart';

enum ConfigurationChangeKind { added, removed, changed }

enum ConfigurationChangeAspect {
  value,
  distribution,
  unit,
  transform,
  formula,
  provenance,
  source,
  providerBinding,
  dataset,
  split,
  estimator,
  code,
  environment,
  structuralIdentity,
  other,
}

enum ImpactReplayComparison { changed, unchanged }

enum ImpactReplayRuntimeState {
  available,
  abstained,
  failed,
  unavailable,
  explicitNull,
  adverse,
}

enum ImpactVerificationKind {
  softwareQuality,
  codeVerification,
  calculationVerification,
  scientificValidation,
  humanFactors,
  transportability,
  contextOfUseRequalification,
}

enum ImpactObligationDisposition {
  unresolved,
  satisfied,
  notApplicable,
  rejected,
}

final class AlgorithmConfigurationSemanticChange {
  const AlgorithmConfigurationSemanticChange({
    required this.path,
    required this.kind,
    required this.aspect,
    required this.previousValue,
    required this.currentValue,
    required this.affectedAlgorithmIds,
  });

  final String path;
  final ConfigurationChangeKind kind;
  final ConfigurationChangeAspect aspect;
  final Object? previousValue;
  final Object? currentValue;
  final List<String> affectedAlgorithmIds;

  Map<String, Object?> toJson() => {
    'path': path,
    'kind': kind.name,
    'aspect': aspect.name,
    'previous_value': previousValue,
    'current_value': currentValue,
    'affected_algorithm_ids': affectedAlgorithmIds,
  };
}

final class AlgorithmImpactRelationship {
  const AlgorithmImpactRelationship({
    required this.algorithmId,
    required this.outputId,
    required this.outputDescription,
    required this.replayFixtureIds,
    required this.uiDescriptorId,
    required this.sourceBundleOnly,
  });

  final String algorithmId;
  final String outputId;
  final String outputDescription;
  final List<String> replayFixtureIds;
  final String uiDescriptorId;
  final bool sourceBundleOnly;

  Map<String, Object?> toJson() => {
    'algorithm_id': algorithmId,
    'output_id': outputId,
    'output_description': outputDescription,
    'replay_fixture_ids': replayFixtureIds,
    'ui_descriptor_id': uiDescriptorId,
    'source_bundle_only': sourceBundleOnly,
  };
}

final class AlgorithmImpactReplayDelta {
  const AlgorithmImpactReplayDelta({
    required this.fixtureId,
    required this.outputId,
    required this.comparison,
    required this.runtimeState,
    required this.previousValue,
    required this.currentValue,
    required this.inputSha256,
    required this.previousConfigurationSha256,
    required this.currentConfigurationSha256,
    required this.sourceBundleSha256,
    required this.platformIdentity,
    required this.toleranceContract,
  });

  final String fixtureId;
  final String outputId;
  final ImpactReplayComparison comparison;
  final ImpactReplayRuntimeState runtimeState;
  final Object? previousValue;
  final Object? currentValue;
  final String inputSha256;
  final String previousConfigurationSha256;
  final String currentConfigurationSha256;
  final String sourceBundleSha256;
  final String platformIdentity;
  final String toleranceContract;

  Map<String, Object?> toJson() => {
    'fixture_id': fixtureId,
    'output_id': outputId,
    'comparison': comparison.name,
    'runtime_state': runtimeState.name,
    'previous_value': previousValue,
    'current_value': currentValue,
    'input_sha256': inputSha256,
    'previous_configuration_sha256': previousConfigurationSha256,
    'current_configuration_sha256': currentConfigurationSha256,
    'source_bundle_sha256': sourceBundleSha256,
    'platform_identity': platformIdentity,
    'tolerance_contract': toleranceContract,
  };
}

final class AlgorithmImpactVerificationObligation {
  const AlgorithmImpactVerificationObligation({
    required this.kind,
    required this.disposition,
    required this.reviewerAuthority,
    required this.evidenceIds,
    required this.rationale,
  });

  final ImpactVerificationKind kind;
  final ImpactObligationDisposition disposition;
  final String reviewerAuthority;
  final List<String> evidenceIds;
  final String rationale;

  bool get closesObligation =>
      disposition == ImpactObligationDisposition.satisfied ||
      disposition == ImpactObligationDisposition.notApplicable;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'disposition': disposition.name,
    'reviewer_authority': reviewerAuthority,
    'evidence_ids': evidenceIds,
    'rationale': rationale,
  };
}

/// Content-addressed configuration comparison and selective-revalidation view.
///
/// The comparison proves only that exact inputs were compared and that impact
/// obligations were made explicit. It never promotes software checks into
/// scientific validation, clinical performance, or medical advice.
final class AlgorithmConfigurationChangeImpactPackage {
  static const String schema =
      'parkinsum.algorithm-configuration-change-impact/1';
  static const int schemaVersion = 1;

  const AlgorithmConfigurationChangeImpactPackage({
    required this.previousConfigurationSha256,
    required this.currentConfigurationSha256,
    required this.previousVersion,
    required this.currentVersion,
    required this.sourceBundleSha256,
    required this.changes,
    required this.relationships,
    required this.replayDeltas,
    required this.obligations,
    required this.integrityReasons,
    required this.rollbackConfigurationSha256,
    required this.comparisonBoundary,
  });

  final String previousConfigurationSha256;
  final String currentConfigurationSha256;
  final String previousVersion;
  final String currentVersion;
  final String sourceBundleSha256;
  final List<AlgorithmConfigurationSemanticChange> changes;
  final List<AlgorithmImpactRelationship> relationships;
  final List<AlgorithmImpactReplayDelta> replayDeltas;
  final List<AlgorithmImpactVerificationObligation> obligations;
  final List<String> integrityReasons;
  final String rollbackConfigurationSha256;
  final String comparisonBoundary;

  bool get identitiesDiffer =>
      previousConfigurationSha256 != currentConfigurationSha256;

  bool get graphComplete => integrityReasons.isEmpty;

  bool get evidenceComplete =>
      obligations.every((obligation) => obligation.closesObligation);

  bool get canCloseImpact =>
      identitiesDiffer &&
      changes.isNotEmpty &&
      graphComplete &&
      evidenceComplete;

  String get semanticDiffSha256 =>
      _digest(changes.map((change) => change.toJson()).toList(growable: false));

  String get packageSha256 => _digest(canonicalPayload);

  Map<String, Object?> get canonicalPayload => {
    r'$schema': schema,
    'schema_version': schemaVersion,
    'previous_configuration_sha256': previousConfigurationSha256,
    'current_configuration_sha256': currentConfigurationSha256,
    'previous_version': previousVersion,
    'current_version': currentVersion,
    'source_bundle_sha256': sourceBundleSha256,
    'semantic_diff_sha256': semanticDiffSha256,
    'changes': changes.map((change) => change.toJson()).toList(growable: false),
    'relationships': relationships
        .map((relationship) => relationship.toJson())
        .toList(growable: false),
    'replay_deltas': replayDeltas
        .map((delta) => delta.toJson())
        .toList(growable: false),
    'obligations': obligations
        .map((obligation) => obligation.toJson())
        .toList(growable: false),
    'integrity_reasons': integrityReasons,
    'rollback_configuration_sha256': rollbackConfigurationSha256,
    'comparison_boundary': comparisonBoundary,
    'can_close_impact': canCloseImpact,
  };

  Map<String, Object?> toJson() => {
    ...canonicalPayload,
    'package_sha256': packageSha256,
  };
}

String _digest(Object? value) =>
    sha256.convert(utf8.encode(jsonEncode(_canonicalize(value)))).toString();

Object? _canonicalize(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((key) => '$key').toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _canonicalize(value[key]),
    };
  }
  if (value is List) {
    return value.map(_canonicalize).toList(growable: false);
  }
  return value;
}
