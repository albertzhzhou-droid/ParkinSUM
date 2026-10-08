import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../../algorithm_sdk/algorithm_parameter_provenance.dart';
import '../entities/algorithm_configuration_change_impact.dart';
import '../entities/algorithm_descriptor.dart';
import '../entities/gastric_emptying_parameters.dart';
import '../entities/mechanistic_conflict_result.dart';
import 'algorithm_observatory_service.dart';
import 'algorithm_registry.dart';
import 'mechanistic_conflict_engine.dart';
import 'mechanistic_next_meal_scorer.dart';

/// Builds a fail-closed semantic configuration difference and selective
/// requalification package. The checked-in pins are intentionally independent
/// of both identities' self-declared digests.
final class AlgorithmConfigurationChangeImpactService {
  static const String baselineFixtureSha256Pin =
      '340e05012e36fbc3a4fc8d1ee2a80e6dd2b7dbe1a2160365254f20f94f1ca942';
  static const String currentFixtureSha256Pin =
      '006082abc5d9f5aa280daeb18b83e3eff34790be7d38e077a6a2452720d9d60e';
  static const String boundary =
      'This comparison uses a manufactured, deterministic prior configuration '
      'to exercise change control. It is not repository history, clinical '
      'validation, model qualification, regulatory approval, or medical advice.';

  const AlgorithmConfigurationChangeImpactService();

  AlgorithmConfigurationChangeImpactPackage buildCurrentFixture() {
    final previousParameters = _baselineGastricParameters();
    final previousIdentity = AlgorithmConfigurationIdentity.defaults(
      gastricParameters: previousParameters,
    );
    final currentIdentity = AlgorithmConfigurationIdentity.defaults();
    final previousEngine = MechanisticConflictEngine(
      gastricEmptyingParameters: previousParameters,
    );
    final previousScorer = MechanisticNextMealScorer(engine: previousEngine);
    final previousService = AlgorithmObservatoryService(
      conflictEngine: previousEngine,
      candidateScorer: previousScorer,
      configurationIdentity: previousIdentity,
    );
    final currentService = AlgorithmObservatoryService();
    return assess(
      previousIdentity: previousIdentity,
      currentIdentity: currentIdentity,
      expectedPreviousSha256: baselineFixtureSha256Pin,
      expectedCurrentSha256: currentFixtureSha256Pin,
      previousSnapshots: {
        for (final scenario in ObservatoryScenario.values)
          scenario: previousService.build(scenario),
      },
      currentSnapshots: {
        for (final scenario in ObservatoryScenario.values)
          scenario: currentService.build(scenario),
      },
    );
  }

  AlgorithmConfigurationChangeImpactPackage assess({
    required AlgorithmConfigurationIdentity previousIdentity,
    required AlgorithmConfigurationIdentity currentIdentity,
    required String expectedPreviousSha256,
    required String expectedCurrentSha256,
    required Map<ObservatoryScenario, AlgorithmObservatorySnapshot>
    previousSnapshots,
    required Map<ObservatoryScenario, AlgorithmObservatorySnapshot>
    currentSnapshots,
    List<AlgorithmDescriptor> algorithmDescriptors = AlgorithmRegistry.all,
  }) {
    _verifyIndependentPin(
      label: 'previous',
      actual: previousIdentity.sha256Digest,
      expected: expectedPreviousSha256,
    );
    _verifyIndependentPin(
      label: 'current',
      actual: currentIdentity.sha256Digest,
      expected: expectedCurrentSha256,
    );
    if (previousIdentity.sha256Digest == currentIdentity.sha256Digest) {
      throw ArgumentError('Configuration comparison requires two identities.');
    }
    if (previousSnapshots.keys.toSet().length !=
            ObservatoryScenario.values.length ||
        currentSnapshots.keys.toSet().length !=
            ObservatoryScenario.values.length) {
      throw ArgumentError('Every Observatory scenario must be replayed twice.');
    }

    final changes = compareCanonicalConfigurations(
      previous: previousIdentity.canonicalConfiguration,
      current: currentIdentity.canonicalConfiguration,
      algorithmDescriptors: algorithmDescriptors,
    );

    final coverage = currentIdentity.configurationCoverageManifest;
    final relationships = <AlgorithmImpactRelationship>[
      for (final descriptor in algorithmDescriptors)
        AlgorithmImpactRelationship(
          algorithmId: descriptor.id,
          outputId: 'algorithm-output/${descriptor.id}',
          outputDescription: descriptor.outputs,
          replayFixtureIds: descriptor.hasLiveTrace
              ? [
                  for (final scenario in ObservatoryScenario.values)
                    'observatory.${scenario.name}',
                ]
              : const [],
          uiDescriptorId: descriptor.uiDescriptorId,
          sourceBundleOnly:
              coverage.entryFor(descriptor.id).mode ==
              AlgorithmConfigurationCoverageMode.sourceBundleOnly,
        ),
    ]..sort((left, right) => left.algorithmId.compareTo(right.algorithmId));

    final reasons = validateImpactGraph(changes, relationships);
    final replayDeltas = _buildReplayDeltas(
      previousIdentity: previousIdentity,
      currentIdentity: currentIdentity,
      previousSnapshots: previousSnapshots,
      currentSnapshots: currentSnapshots,
    );
    final obligations = _obligationsFor(changes);
    final package = AlgorithmConfigurationChangeImpactPackage(
      previousConfigurationSha256: previousIdentity.sha256Digest,
      currentConfigurationSha256: currentIdentity.sha256Digest,
      previousVersion: previousIdentity.version,
      currentVersion: currentIdentity.version,
      sourceBundleSha256:
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
      changes: List.unmodifiable(changes),
      relationships: List.unmodifiable(relationships),
      replayDeltas: List.unmodifiable(replayDeltas),
      obligations: List.unmodifiable(obligations),
      integrityReasons: List.unmodifiable(reasons),
      rollbackConfigurationSha256: previousIdentity.sha256Digest,
      comparisonBoundary: boundary,
    );
    // Critical governance flow: a green replay is deliberately not promotion.
    developer.log(
      '[AlgorithmConfigurationImpact] ${changes.length} changes, '
      '${replayDeltas.length} replay outputs, '
      '${reasons.length} graph holds, canClose=${package.canCloseImpact}',
      name: 'parkinsum.algorithm.configuration-impact',
    );
    return package;
  }

  /// Public deterministic semantic-diff primitive used by governance tools and
  /// mutation tests. Callers still need [assess] for independent digest pins,
  /// replay identities, reviewer obligations, and a closable package.
  List<AlgorithmConfigurationSemanticChange> compareCanonicalConfigurations({
    required Map<String, dynamic> previous,
    required Map<String, dynamic> current,
    List<AlgorithmDescriptor> algorithmDescriptors = AlgorithmRegistry.all,
  }) {
    final changes = <AlgorithmConfigurationSemanticChange>[];
    _diffValue(
      '',
      previous,
      current,
      changes,
      previous,
      current,
      algorithmDescriptors,
    );
    changes.sort((left, right) => left.path.compareTo(right.path));
    return List.unmodifiable(changes);
  }

  /// Graph validation remains callable independently so a removed consumer,
  /// missing replay fixture, many-to-many edge, or source-only fallback cannot
  /// be hidden by a package producer.
  List<String> validateImpactGraph(
    List<AlgorithmConfigurationSemanticChange> changes,
    List<AlgorithmImpactRelationship> relationships,
  ) => List.unmodifiable(_integrityReasons(changes, relationships));

  static void _verifyIndependentPin({
    required String label,
    required String actual,
    required String expected,
  }) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expected) || actual != expected) {
      throw StateError(
        '$label configuration identity rejected: expected $expected, actual $actual',
      );
    }
  }

  static void _diffValue(
    String path,
    Object? previous,
    Object? current,
    List<AlgorithmConfigurationSemanticChange> changes,
    Map<String, dynamic> previousRoot,
    Map<String, dynamic> currentRoot,
    List<AlgorithmDescriptor> descriptors,
  ) {
    if (previous is Map && current is Map) {
      final keys = <String>{
        ...previous.keys.map((key) => '$key'),
        ...current.keys.map((key) => '$key'),
      }.toList()..sort();
      for (final key in keys) {
        _diffValue(
          path.isEmpty ? key : '$path.$key',
          previous[key],
          current[key],
          changes,
          previousRoot,
          currentRoot,
          descriptors,
        );
      }
      return;
    }
    if (previous is List && current is List) {
      final length = previous.length > current.length
          ? previous.length
          : current.length;
      for (var index = 0; index < length; index += 1) {
        _diffValue(
          '$path[$index]',
          index < previous.length ? previous[index] : null,
          index < current.length ? current[index] : null,
          changes,
          previousRoot,
          currentRoot,
          descriptors,
        );
      }
      return;
    }
    if (_canonicalJson(previous) == _canonicalJson(current)) return;
    final affected = _affectedAlgorithms(
      path,
      previousRoot,
      currentRoot,
      descriptors,
    );
    changes.add(
      AlgorithmConfigurationSemanticChange(
        path: path,
        kind: previous == null
            ? ConfigurationChangeKind.added
            : current == null
            ? ConfigurationChangeKind.removed
            : ConfigurationChangeKind.changed,
        aspect: _aspectFor(path),
        previousValue: previous,
        currentValue: current,
        affectedAlgorithmIds: affected,
      ),
    );
  }

  static List<String> _affectedAlgorithms(
    String path,
    Map<String, dynamic> previous,
    Map<String, dynamic> current,
    List<AlgorithmDescriptor> descriptors,
  ) {
    final found = <String>{};
    void addRecordAlgorithms(Map<String, dynamic> root, String listName) {
      final match = RegExp('$listName\\[(\\d+)\\]').firstMatch(path);
      if (match == null) return;
      final configuration = root['parameter_provenance_manifest'];
      final records = configuration is Map ? configuration['records'] : null;
      final index = int.parse(match.group(1)!);
      if (records is List && index < records.length && records[index] is Map) {
        final ids = (records[index] as Map)['algorithm_ids'];
        if (ids is List) found.addAll(ids.map((id) => '$id'));
      }
    }

    addRecordAlgorithms(previous, 'parameter_provenance_manifest\\.records');
    addRecordAlgorithms(current, 'parameter_provenance_manifest\\.records');
    final coverageEntryMatch = RegExp(
      r'algorithm_configuration_coverage_manifest\.entries\[(\d+)\]',
    ).firstMatch(path);
    void addCoverageEntryAlgorithm(Map<String, dynamic> root) {
      if (coverageEntryMatch == null) return;
      final manifest = root['algorithm_configuration_coverage_manifest'];
      final entries = manifest is Map ? manifest['entries'] : null;
      final index = int.parse(coverageEntryMatch.group(1)!);
      if (entries is! List ||
          index >= entries.length ||
          entries[index] is! Map) {
        return;
      }
      final algorithmId = (entries[index] as Map)['algorithm_id'];
      if (algorithmId is String && algorithmId.isNotEmpty) {
        found.add(algorithmId);
      }
    }

    addCoverageEntryAlgorithm(previous);
    addCoverageEntryAlgorithm(current);
    final coverageSummaryMatch = RegExp(
      r'^algorithm_configuration_coverage_manifest\.(algorithm_count|field_and_source_bound_count|source_bundle_only_count|complete_per_field_coverage_count)$',
    ).firstMatch(path);
    Map<String, bool> coverageMembership(Map<String, dynamic> root) {
      if (coverageSummaryMatch == null) return const {};
      final manifest = root['algorithm_configuration_coverage_manifest'];
      final entries = manifest is Map ? manifest['entries'] : null;
      if (entries is! List) return const {};
      final summaryField = coverageSummaryMatch.group(1)!;
      return <String, bool>{
        for (final entry in entries.whereType<Map>())
          if (entry['algorithm_id'] is String)
            entry['algorithm_id'] as String: switch (summaryField) {
              'algorithm_count' => true,
              'field_and_source_bound_count' =>
                entry['mode'] == 'fieldAndSourceBound',
              'source_bundle_only_count' => entry['mode'] == 'sourceBundleOnly',
              'complete_per_field_coverage_count' =>
                entry['complete_per_field_coverage_proven'] == true,
              _ => false,
            },
      };
    }

    final previousCoverage = coverageMembership(previous);
    final currentCoverage = coverageMembership(current);
    for (final algorithmId in <String>{
      ...previousCoverage.keys,
      ...currentCoverage.keys,
    }) {
      if (previousCoverage[algorithmId] != currentCoverage[algorithmId]) {
        found.add(algorithmId);
      }
    }
    const directOwners = <String, List<String>>{
      'gastric_emptying': ['gastric_emptying'],
      'levodopa_absorption_opportunity': ['levodopa_absorption_opportunity'],
      'amino_acid_competition': ['amino_acid_competition'],
      'protein_distribution': ['protein_distribution'],
      'candidate_scoring': ['mechanistic_candidate_scorer'],
      'runtime_rule_logic': ['runtime_rule_engine'],
      'legacy_nutrition_thresholds': ['legacy_nutrition_classifier'],
      'dose_expression_grammar': ['dosage_note_parser'],
    };
    for (final entry in directOwners.entries) {
      if (path == entry.key || path.startsWith('${entry.key}.')) {
        found.addAll(entry.value);
      }
    }
    for (final descriptor in descriptors) {
      // Inside a coverage entry, the entry's algorithm_id is authoritative.
      // Nested dependency IDs and owned source paths describe that algorithm's
      // witness; substring matching them would manufacture a second owner.
      if (coverageEntryMatch == null &&
          descriptor.sourcePaths.any(path.contains)) {
        found.add(descriptor.id);
      }
      if (coverageEntryMatch == null && path.contains(descriptor.id)) {
        found.add(descriptor.id);
      }
    }
    final sorted = found.toList()..sort();
    return List.unmodifiable(sorted);
  }

  static ConfigurationChangeAspect _aspectFor(String path) {
    final lower = path.toLowerCase();
    if (lower.contains('distribution')) {
      return ConfigurationChangeAspect.distribution;
    }
    if (lower.contains('unit')) return ConfigurationChangeAspect.unit;
    if (lower.contains('transform')) return ConfigurationChangeAspect.transform;
    if (lower.contains('formula')) return ConfigurationChangeAspect.formula;
    if (lower.contains('provenance') || lower.contains('review_date')) {
      return ConfigurationChangeAspect.provenance;
    }
    if (lower.contains('source_id') || lower.contains('source_ref')) {
      return ConfigurationChangeAspect.source;
    }
    if (lower.contains('provider') || lower.contains('algorithm_ids')) {
      return ConfigurationChangeAspect.providerBinding;
    }
    if (lower.contains('dataset')) return ConfigurationChangeAspect.dataset;
    if (lower.contains('split')) return ConfigurationChangeAspect.split;
    if (lower.contains('estimator')) return ConfigurationChangeAspect.estimator;
    if (lower.contains('code_sha') || lower.contains('implementation_source')) {
      return ConfigurationChangeAspect.code;
    }
    if (lower.contains('environment') || lower.contains('lock_sha')) {
      return ConfigurationChangeAspect.environment;
    }
    if (lower.contains('structural') || lower.contains('source_bundle_sha')) {
      return ConfigurationChangeAspect.structuralIdentity;
    }
    if (lower.endsWith('.original') ||
        lower.endsWith('.canonical') ||
        lower.endsWith('.value')) {
      return ConfigurationChangeAspect.value;
    }
    return ConfigurationChangeAspect.other;
  }

  static List<String> _integrityReasons(
    List<AlgorithmConfigurationSemanticChange> changes,
    List<AlgorithmImpactRelationship> relationships,
  ) {
    final byAlgorithm = {
      for (final relationship in relationships)
        relationship.algorithmId: relationship,
    };
    final reasons = <String>{};
    for (final change in changes) {
      if (change.affectedAlgorithmIds.isEmpty) {
        reasons.add('impact.unknown_consumer:${change.path}');
      }
      if (change.affectedAlgorithmIds.length > 1) {
        reasons.add('impact.many_to_many_review:${change.path}');
      }
      for (final id in change.affectedAlgorithmIds) {
        final relationship = byAlgorithm[id];
        if (relationship == null) {
          reasons.add('impact.orphan_algorithm:$id');
        } else {
          if (relationship.replayFixtureIds.isEmpty) {
            reasons.add('impact.replay_fixture_missing:$id');
          }
          if (relationship.sourceBundleOnly) {
            reasons.add('impact.source_bundle_only:$id');
          }
          if (relationship.uiDescriptorId.trim().isEmpty) {
            reasons.add('impact.ui_consumer_missing:$id');
          }
        }
      }
    }
    return reasons.toList()..sort();
  }

  static List<AlgorithmImpactReplayDelta> _buildReplayDeltas({
    required AlgorithmConfigurationIdentity previousIdentity,
    required AlgorithmConfigurationIdentity currentIdentity,
    required Map<ObservatoryScenario, AlgorithmObservatorySnapshot>
    previousSnapshots,
    required Map<ObservatoryScenario, AlgorithmObservatorySnapshot>
    currentSnapshots,
  }) {
    final deltas = <AlgorithmImpactReplayDelta>[];
    for (final scenario in ObservatoryScenario.values) {
      final previous = previousSnapshots[scenario]!;
      final current = currentSnapshots[scenario]!;
      final values = <String, (Object?, Object?)>{
        'mechanistic_conflict.availability': (
          previous.conflict.availability.name,
          current.conflict.availability.name,
        ),
        'mechanistic_conflict.interaction_score': (
          previous.conflict.modeledInteractionScore,
          current.conflict.modeledInteractionScore,
        ),
        'mechanistic_conflict.severity': (
          previous.conflict.modeledSeverityBand?.name,
          current.conflict.modeledSeverityBand?.name,
        ),
        'mechanistic_conflict.gastric_profile_sha256': (
          _digest(previous.conflict.primaryEmptyingProfile?.toJson()),
          _digest(current.conflict.primaryEmptyingProfile?.toJson()),
        ),
        'mechanistic_candidate_scorer.outputs_sha256': (
          _digest(
            previous.candidateScores.map((score) => score.toJson()).toList(),
          ),
          _digest(
            current.candidateScores.map((score) => score.toJson()).toList(),
          ),
        ),
      };
      final inputSha = _digest(current.context.toJson());
      for (final entry in values.entries) {
        final previousValue = entry.value.$1;
        final currentValue = entry.value.$2;
        deltas.add(
          AlgorithmImpactReplayDelta(
            fixtureId: 'observatory.${scenario.name}',
            outputId: entry.key,
            comparison:
                _canonicalJson(previousValue) == _canonicalJson(currentValue)
                ? ImpactReplayComparison.unchanged
                : ImpactReplayComparison.changed,
            runtimeState: _runtimeState(
              outputId: entry.key,
              value: currentValue,
              conflict: current.conflict,
            ),
            previousValue: previousValue,
            currentValue: currentValue,
            inputSha256: inputSha,
            previousConfigurationSha256: previousIdentity.sha256Digest,
            currentConfigurationSha256: currentIdentity.sha256Digest,
            sourceBundleSha256: AlgorithmConfigurationIdentity
                .registeredAlgorithmSourceBundleSha256,
            platformIdentity: 'dart-deterministic-runtime/1',
            toleranceContract: entry.key.contains('score')
                ? 'exact-null-or-absolute-1e-12'
                : 'exact-canonical-json',
          ),
        );
      }
    }
    return deltas;
  }

  static ImpactReplayRuntimeState _runtimeState({
    required String outputId,
    required Object? value,
    required MechanisticConflictResult conflict,
  }) {
    if (value == null) return ImpactReplayRuntimeState.explicitNull;
    if (!conflict.hasModeledOutput) return ImpactReplayRuntimeState.abstained;
    if (outputId.endsWith('.severity') &&
        (value == SeverityBand.high.name ||
            value == SeverityBand.moderate.name)) {
      return ImpactReplayRuntimeState.adverse;
    }
    return ImpactReplayRuntimeState.available;
  }

  static List<AlgorithmImpactVerificationObligation> _obligationsFor(
    List<AlgorithmConfigurationSemanticChange> changes,
  ) => [
    for (final kind in ImpactVerificationKind.values)
      AlgorithmImpactVerificationObligation(
        kind: kind,
        disposition: ImpactObligationDisposition.unresolved,
        reviewerAuthority: _reviewerFor(kind),
        evidenceIds: const [],
        rationale: _rationaleFor(kind, changes),
      ),
  ];

  static String _reviewerFor(ImpactVerificationKind kind) => switch (kind) {
    ImpactVerificationKind.softwareQuality ||
    ImpactVerificationKind.codeVerification => 'independent-software-reviewer',
    ImpactVerificationKind.calculationVerification =>
      'independent-model-verification-reviewer',
    ImpactVerificationKind.scientificValidation =>
      'independent-domain-scientist',
    ImpactVerificationKind.humanFactors => 'independent-human-factors-reviewer',
    ImpactVerificationKind.transportability =>
      'independent-transportability-reviewer',
    ImpactVerificationKind.contextOfUseRequalification =>
      'delegated-context-of-use-authority',
  };

  static String _rationaleFor(
    ImpactVerificationKind kind,
    List<AlgorithmConfigurationSemanticChange> changes,
  ) {
    final aspects = changes.map((change) => change.aspect.name).toSet().toList()
      ..sort();
    return '${kind.name} remains unresolved for changed aspects: '
        '${aspects.join(', ')}. A green replay cannot close this obligation.';
  }

  static GastricEmptyingParameterSet _baselineGastricParameters() {
    final current = GastricEmptyingParameterSet.literatureInformedDefault();
    return GastricEmptyingParameterSet(
      id: current.id,
      version: '2026.08.27-impact-baseline-fixture-v1',
      lastReviewed: current.lastReviewed,
      solidLagMinutes: current.solidLagMinutes,
      solidHalfMinutes: GastricEmptyingParameter<double>(
        id: current.solidHalfMinutes.id,
        label: current.solidHalfMinutes.label,
        value: 85,
        sourceRefs: current.solidHalfMinutes.sourceRefs,
        confidence: current.solidHalfMinutes.confidence,
        limitation: current.solidHalfMinutes.limitation,
      ),
      liquidLagMinutes: current.liquidLagMinutes,
      liquidHalfMinutes: current.liquidHalfMinutes,
      referenceMealCalories: current.referenceMealCalories,
      fatSlowdownMultiplier: current.fatSlowdownMultiplier,
      fatFractionThreshold: current.fatFractionThreshold,
      fiberSlowdownMultiplier: current.fiberSlowdownMultiplier,
      mixedMealUncertaintyBoost: current.mixedMealUncertaintyBoost,
      overlapUncertaintyBoost: current.overlapUncertaintyBoost,
      fatUncertaintyBoost: current.fatUncertaintyBoost,
      highCalorieUncertaintyBoost: current.highCalorieUncertaintyBoost,
      highCalorieFractionThreshold: current.highCalorieFractionThreshold,
      timeScaleSensitivityFraction: current.timeScaleSensitivityFraction,
    );
  }
}

String _digest(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) => jsonEncode(_canonicalize(value));

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
  if (value is Set) {
    final values = value.map(_canonicalize).toList()
      ..sort((left, right) => jsonEncode(left).compareTo(jsonEncode(right)));
    return values;
  }
  return value;
}
