import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../../core/analysis/food_repository.dart';
import '../../core/analysis/medication_repository.dart';
import '../../core/constants/baseline_cdss_rules.dart';
import '../../core/constants/local_ai_replay_scenarios.dart';
import '../../core/db/cdss_database_memory.dart';
import '../../core/models/food_item.dart';
import '../../core/models/user_profile.dart';
import '../../core/utils/qualified_value_parser.dart';
import '../entities/cdss_records.dart';
import '../entities/recommendation_benchmark_models.dart';
import '../entities/rule_registry_models.dart';
import '../entities/runtime_context.dart';
import '../entities/source_metadata.dart';
import 'algorithm_registry.dart';
import 'catalog_resolution_engine.dart';
import 'cdss_catalog_projection_service.dart';
import 'fact_conflict_engine.dart';
import 'get_food_recommendations_usecase.dart';
import 'local_ai_recommendation_adapter.dart';
import 'next_meal_recommendation_orchestrator.dart';
import 'recommendation_replay_runner.dart';
import 'rule_registry_compiler.dart';
import 'runtime_rule_engine.dart';
import 'runtime_rule_support.dart';
import 'source_authority_scorer.dart';

const int algorithmExecutableContractSchemaVersion = 1;
const String algorithmExecutableContractSchema =
    'parkinsum.algorithm-executable-contract-report/1';

enum AlgorithmExecutableContractKind {
  behavior,
  schema,
  ordering,
  provenance,
  safety,
}

enum AlgorithmExecutableContractStatus {
  pending,
  passed,
  failed,
  blocked,
  notCovered,
}

final class AlgorithmExecutableContractSpec {
  const AlgorithmExecutableContractSpec({
    required this.id,
    required this.algorithmId,
    required this.kind,
    required this.relation,
    required this.sourceRefs,
  });

  final String id;
  final String algorithmId;
  final AlgorithmExecutableContractKind kind;
  final String relation;
  final List<String> sourceRefs;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'algorithm_id': algorithmId,
    'kind': kind.name,
    'relation': relation,
    'source_refs': sourceRefs,
    'expected_observation_sha256':
        AlgorithmConfigurationIdentity.digestConfiguration(
          AlgorithmExecutableContractGate.expectedObservations[id]!,
        ),
  };
}

final class AlgorithmExecutableContractCheckResult {
  AlgorithmExecutableContractCheckResult({
    required this.spec,
    required this.status,
    required Map<String, Object?> observation,
    required this.observationSha256,
    required List<String> failureCodes,
  }) : observation = Map<String, Object?>.unmodifiable(observation),
       failureCodes = List<String>.unmodifiable(failureCodes);

  final AlgorithmExecutableContractSpec spec;
  final AlgorithmExecutableContractStatus status;
  final Map<String, Object?> observation;
  final String observationSha256;
  final List<String> failureCodes;

  Map<String, Object?> toJson() => <String, Object?>{
    'spec': spec.toJson(),
    'status': status.name,
    'observation': observation,
    'observation_sha256': observationSha256,
    'failure_codes': failureCodes,
  };
}

final class AlgorithmExecutableContractReport {
  AlgorithmExecutableContractReport({
    required this.specificationSha256,
    required this.configurationSha256,
    required this.sourceBundleSha256,
    required List<AlgorithmExecutableContractCheckResult> checks,
    required List<String> integrityFailureCodes,
  }) : checks = List<AlgorithmExecutableContractCheckResult>.unmodifiable(
         checks,
       ),
       integrityFailureCodes = List<String>.unmodifiable(integrityFailureCodes);

  static const String boundary =
      'Executable software contracts over fixed synthetic inputs only. Passing '
      'does not establish scientific truth, model quality, clinical '
      'calibration, patient-level accuracy, benefit, safety, or medical advice.';

  final String specificationSha256;
  final String configurationSha256;
  final String sourceBundleSha256;
  final List<AlgorithmExecutableContractCheckResult> checks;
  final List<String> integrityFailureCodes;

  bool get passed =>
      integrityFailureCodes.isEmpty &&
      checks.every(
        (check) => check.status == AlgorithmExecutableContractStatus.passed,
      );

  int get passedCheckCount => checks
      .where(
        (check) => check.status == AlgorithmExecutableContractStatus.passed,
      )
      .length;

  Set<String> get coveredAlgorithmIds =>
      Set<String>.unmodifiable(checks.map((check) => check.spec.algorithmId));

  AlgorithmExecutableContractStatus statusFor(String algorithmId) {
    final relevant = checks
        .where((check) => check.spec.algorithmId == algorithmId)
        .toList(growable: false);
    if (relevant.isEmpty) return AlgorithmExecutableContractStatus.notCovered;
    if (relevant.any(
      (check) => check.status == AlgorithmExecutableContractStatus.blocked,
    )) {
      return AlgorithmExecutableContractStatus.blocked;
    }
    if (relevant.any(
      (check) => check.status == AlgorithmExecutableContractStatus.failed,
    )) {
      return AlgorithmExecutableContractStatus.failed;
    }
    if (relevant.any(
      (check) => check.status == AlgorithmExecutableContractStatus.pending,
    )) {
      return AlgorithmExecutableContractStatus.pending;
    }
    return AlgorithmExecutableContractStatus.passed;
  }

  Map<String, Map<String, Object?>> get observationPayloads =>
      Map<String, Map<String, Object?>>.unmodifiable(
        <String, Map<String, Object?>>{
          for (final check in checks) check.spec.id: check.observation,
        },
      );

  Map<String, Object?> toJson(Iterable<String> registeredAlgorithmIds) {
    final registered = registeredAlgorithmIds.toSet().toList(growable: false)
      ..sort();
    return <String, Object?>{
      'schema': algorithmExecutableContractSchema,
      'schema_version': algorithmExecutableContractSchemaVersion,
      'specification_sha256': specificationSha256,
      'configuration_sha256': configurationSha256,
      'source_bundle_sha256': sourceBundleSha256,
      'boundary': boundary,
      'passed': passed,
      'passed_check_count': passedCheckCount,
      'integrity_failure_codes': integrityFailureCodes,
      'algorithm_status': <String, String>{
        for (final id in registered) id: statusFor(id).name,
      },
      'checks': checks.map((check) => check.toJson()).toList(growable: false),
    };
  }
}

/// One parameterized source/follow-up execution through the same production
/// APIs used by the fixed executable-contract gate.
///
/// The input/output maps are synthetic, canonicalizable evidence payloads. A
/// caller must still evaluate [relationObservation] independently; this class
/// deliberately does not declare whether the metamorphic relation passed.
final class AlgorithmRelationProductionExecution {
  AlgorithmRelationProductionExecution({
    required this.relationId,
    required this.partition,
    required this.seed,
    required Map<String, Object?> sourceInput,
    required Map<String, Object?> followUpInput,
    required Map<String, Object?> sourceOutput,
    required Map<String, Object?> followUpOutput,
    required Map<String, Object?> relationObservation,
    required this.sourceApiInvocationCount,
    required this.followUpApiInvocationCount,
  }) : sourceInput = Map<String, Object?>.unmodifiable(sourceInput),
       followUpInput = Map<String, Object?>.unmodifiable(followUpInput),
       sourceOutput = Map<String, Object?>.unmodifiable(sourceOutput),
       followUpOutput = Map<String, Object?>.unmodifiable(followUpOutput),
       relationObservation = Map<String, Object?>.unmodifiable(
         relationObservation,
       );

  final String relationId;
  final String partition;
  final int seed;
  final Map<String, Object?> sourceInput;
  final Map<String, Object?> followUpInput;
  final Map<String, Object?> sourceOutput;
  final Map<String, Object?> followUpOutput;
  final Map<String, Object?> relationObservation;
  final int sourceApiInvocationCount;
  final int followUpApiInvocationCount;

  int get productionApiInvocationCount =>
      sourceApiInvocationCount + followUpApiInvocationCount;
}

/// First-wave executable contracts for eight non-numerical production APIs.
///
/// The gate is diagnostic and read-only. Its async checks use an injected
/// [MockClient] loopback stand-in, so running it never opens a network socket or
/// calls a model. Mathematical and unit verification remain a separate claim.
final class AlgorithmExecutableContractGate {
  const AlgorithmExecutableContractGate();

  static const List<String> coveredAlgorithmIds = <String>[
    'runtime_rule_support',
    'catalog_resolution',
    'source_authority',
    'runtime_rule_engine',
    'rule_registry_compiler',
    'fact_conflict',
    'recommendation_orchestrator',
    'local_ai_adapter',
  ];

  static const List<AlgorithmExecutableContractSpec>
  specifications = <AlgorithmExecutableContractSpec>[
    AlgorithmExecutableContractSpec(
      id: 'runtime_rule_support.path_permutation',
      algorithmId: 'runtime_rule_support',
      kind: AlgorithmExecutableContractKind.behavior,
      relation:
          'Permuting conjuncts preserves the referenced-path set and missing-field result.',
      sourceRefs: <String>[
        'nist:metamorphic-testing-cybersecurity',
        'synthetic:runtime-rule-support-contract-v1',
      ],
    ),
    AlgorithmExecutableContractSpec(
      id: 'catalog_resolution.input_permutation',
      algorithmId: 'catalog_resolution',
      kind: AlgorithmExecutableContractKind.ordering,
      relation:
          'Permuting catalog input preserves deterministic identity ranking; empty input remains invalid.',
      sourceRefs: <String>[
        'doi:10.1109/TSE.2013.46',
        'synthetic:catalog-resolution-contract-v1',
      ],
    ),
    AlgorithmExecutableContractSpec(
      id: 'source_authority.jurisdiction_order',
      algorithmId: 'source_authority',
      kind: AlgorithmExecutableContractKind.provenance,
      relation:
          'Relevant official sources outrank out-of-jurisdiction and synthetic sources; conflicts remain visible.',
      sourceRefs: <String>[
        'fda:computational-model-credibility-guidance-2023',
        'synthetic:source-authority-contract-v1',
      ],
    ),
    AlgorithmExecutableContractSpec(
      id: 'runtime_rule_engine.jurisdiction_and_units',
      algorithmId: 'runtime_rule_engine',
      kind: AlgorithmExecutableContractKind.behavior,
      relation:
          'Database jurisdiction ordering is honored and equivalent g/mg predicates produce the same firing count.',
      sourceRefs: <String>[
        'nist:metamorphic-testing-cybersecurity',
        'synthetic:runtime-rule-engine-contract-v1',
      ],
    ),
    AlgorithmExecutableContractSpec(
      id: 'rule_registry_compiler.schema_rejection',
      algorithmId: 'rule_registry_compiler',
      kind: AlgorithmExecutableContractKind.schema,
      relation:
          'A valid registry row compiles while removal of a required identity field is rejected.',
      sourceRefs: <String>[
        'nist:metamorphic-testing-cybersecurity',
        'synthetic:rule-registry-compiler-contract-v1',
      ],
    ),
    AlgorithmExecutableContractSpec(
      id: 'fact_conflict.order_and_scope',
      algorithmId: 'fact_conflict',
      kind: AlgorithmExecutableContractKind.behavior,
      relation:
          'Unrelated-fact permutation preserves contradiction truth and a different scope remains a coexisting variant.',
      sourceRefs: <String>[
        'doi:10.1049/iet-sen.2009.0084',
        'synthetic:fact-conflict-contract-v1',
      ],
    ),
    AlgorithmExecutableContractSpec(
      id: 'recommendation_orchestrator.deterministic_fallback',
      algorithmId: 'recommendation_orchestrator',
      kind: AlgorithmExecutableContractKind.safety,
      relation:
          'Fixed scenarios preserve conservative fallback paths and never change the deterministic candidate set.',
      sourceRefs: <String>[
        'nist:metamorphic-testing-cybersecurity',
        'synthetic:recommendation-replay-contract-v1',
      ],
    ),
    AlgorithmExecutableContractSpec(
      id: 'local_ai_adapter.consent_endpoint_whitelist',
      algorithmId: 'local_ai_adapter',
      kind: AlgorithmExecutableContractKind.safety,
      relation:
          'Candidate sets are reorder-only and consent withdrawal or a non-loopback endpoint causes zero transport calls.',
      sourceRefs: <String>[
        'nist:metamorphic-testing-cybersecurity',
        'synthetic:local-ai-loopback-contract-v1',
      ],
    ),
  ];

  static final Map<String, Map<String, Object?>> expectedObservations =
      <String, Map<String, Object?>>{
        'runtime_rule_support.path_permutation': <String, Object?>{
          'forward_paths': <String>[
            'drug.active_ingredients',
            'meal.protein_g',
            'timestamps.drug_time',
            'timestamps.meal_time',
          ],
          'reversed_paths': <String>[
            'drug.active_ingredients',
            'meal.protein_g',
            'timestamps.drug_time',
            'timestamps.meal_time',
          ],
          'permutation_preserved': true,
          'forward_missing_fields': <String>['meal_time', 'time'],
          'reversed_missing_fields': <String>['meal_time', 'time'],
        },
        'catalog_resolution.input_permutation': <String, Object?>{
          'forward_top_candidate_id': 'food:synthetic.food.alpha',
          'reversed_top_candidate_id': 'food:synthetic.food.alpha',
          'forward_status': 'resolved',
          'reversed_status': 'resolved',
          'permutation_preserved': true,
          'empty_query_status': 'invalid',
        },
        'source_authority.jurisdiction_order': <String, Object?>{
          'official_exact_score': 1.0,
          'official_foreign_score': 0.6,
          'synthetic_score': 0.1,
          'strict_order': true,
          'seed_override': false,
          'cross_jurisdiction_conflict': 'differentJurisdictionConflict',
        },
        'runtime_rule_engine.jurisdiction_and_units': <String, Object?>{
          'jurisdiction_chain': <String>['US_DB', 'NORTH_AMERICA_DB', 'GLOBAL'],
          'jurisdiction_source': 'database_region_jurisdiction_map',
          'mg_rule_ids': <String>['contract.dose.mg'],
          'gram_rule_ids': <String>['contract.dose.g'],
          'equivalent_fire_count': true,
        },
        'rule_registry_compiler.schema_rejection': <String, Object?>{
          'valid_count': 1,
          'valid_rule_id': 'pd.ldopa.protein.window.v1',
          'missing_identity_rejected': true,
        },
        'fact_conflict.order_and_scope': <String, Object?>{
          'forward': 'contradiction',
          'reversed': 'contradiction',
          'permutation_preserved': true,
          'different_scope': 'coexistVariant',
        },
        'recommendation_orchestrator.deterministic_fallback': <String, Object?>{
          'case_count': 5,
          'decision_paths': <String>[
            'replay_low_risk_next_meal:hybrid_local_ai',
            'replay_medication_catalog_selection_context:hybrid_local_ai',
            'replay_missing_medication_time_or_dose:conservative_safety_gate',
            'replay_safety_gate_blocks_local_ai:conservative_safety_gate',
            'replay_source_fallback_partial_provenance:conservative_cdss',
          ],
          'ranking_pairs': <Map<String, Object?>>[
            <String, Object?>{
              'case_id': 'replay_missing_medication_time_or_dose',
              'decision_path': 'conservative_safety_gate',
              'deterministic_ranking': <String>[
                'food_oats',
                'food_banana',
                'food_apple',
              ],
              'observed_ranking': <String>[
                'food_oats',
                'food_banana',
                'food_apple',
              ],
            },
            <String, Object?>{
              'case_id': 'replay_low_risk_next_meal',
              'decision_path': 'hybrid_local_ai',
              'deterministic_ranking': <String>[
                'food_banana',
                'food_blueberry',
                'food_apple',
              ],
              'observed_ranking': <String>[
                'food_apple',
                'food_blueberry',
                'food_banana',
              ],
            },
            <String, Object?>{
              'case_id': 'replay_source_fallback_partial_provenance',
              'decision_path': 'conservative_cdss',
              'deterministic_ranking': <String>[
                'food_banana',
                'food_tofu',
                'food_brown_rice',
              ],
              'observed_ranking': <String>[
                'food_banana',
                'food_tofu',
                'food_brown_rice',
              ],
            },
            <String, Object?>{
              'case_id': 'replay_safety_gate_blocks_local_ai',
              'decision_path': 'conservative_safety_gate',
              'deterministic_ranking': <String>[
                'food_oats',
                'food_banana',
                'food_tofu',
              ],
              'observed_ranking': <String>[
                'food_oats',
                'food_banana',
                'food_tofu',
              ],
            },
            <String, Object?>{
              'case_id': 'replay_medication_catalog_selection_context',
              'decision_path': 'hybrid_local_ai',
              'deterministic_ranking': <String>[
                'food_banana',
                'food_blueberry',
                'food_apple',
              ],
              'observed_ranking': <String>[
                'food_apple',
                'food_blueberry',
                'food_banana',
              ],
            },
          ],
          'candidate_sets_preserved': true,
        },
        'local_ai_adapter.consent_endpoint_whitelist': <String, Object?>{
          'candidate_sets_preserved': true,
          'hybrid_case_count': 2,
          'hybrid_ranking_pairs': <Map<String, Object?>>[
            <String, Object?>{
              'case_id': 'replay_low_risk_next_meal',
              'deterministic_ranking': <String>[
                'food_banana',
                'food_blueberry',
                'food_apple',
              ],
              'observed_ranking': <String>[
                'food_apple',
                'food_blueberry',
                'food_banana',
              ],
            },
            <String, Object?>{
              'case_id': 'replay_medication_catalog_selection_context',
              'deterministic_ranking': <String>[
                'food_banana',
                'food_blueberry',
                'food_apple',
              ],
              'observed_ranking': <String>[
                'food_apple',
                'food_blueberry',
                'food_banana',
              ],
            },
          ],
          'consent_withdrawn_available': false,
          'consent_withdrawn_skipped': true,
          'consent_withdrawn_transport_calls': 0,
          'remote_endpoint_available': false,
          'remote_endpoint_transport_calls': 0,
        },
      };

  static final String specificationSha256 =
      AlgorithmConfigurationIdentity.digestConfiguration(<String, Object?>{
        'schema': algorithmExecutableContractSchema,
        'specifications': specifications
            .map((spec) => spec.toJson())
            .toList(growable: false),
      });

  Future<AlgorithmExecutableContractReport> run() async {
    final observations = <String, Map<String, Object?>>{};
    final blocked = <String, String>{};
    final observers = <String, Future<Map<String, Object?>> Function()>{
      'runtime_rule_support.path_permutation': () async =>
          _observeRuntimeRuleSupport(),
      'catalog_resolution.input_permutation': () async =>
          _observeCatalogResolution(),
      'source_authority.jurisdiction_order': () async =>
          _observeSourceAuthority(),
      'runtime_rule_engine.jurisdiction_and_units': () async =>
          _observeRuntimeRuleEngine(),
      'rule_registry_compiler.schema_rejection': () async =>
          _observeRuleRegistryCompiler(),
      'fact_conflict.order_and_scope': () async => _observeFactConflict(),
    };
    for (final entry in observers.entries) {
      try {
        observations[entry.key] = await entry.value();
      } catch (error) {
        blocked[entry.key] =
            'contract.execution_blocked.${error.runtimeType.toString()}';
      }
    }
    try {
      final asyncObservations = await _observeRecommendationAndLocalAi();
      observations.addAll(asyncObservations);
    } catch (error) {
      blocked['recommendation_orchestrator.deterministic_fallback'] =
          'contract.execution_blocked.${error.runtimeType.toString()}';
      blocked['local_ai_adapter.consent_endpoint_whitelist'] =
          'contract.execution_blocked.${error.runtimeType.toString()}';
    }
    return verifyObservations(observations, blockedChecks: blocked);
  }

  /// Executes one applicable deterministic sampling case through production
  /// APIs. Missing and malformed cases are held by the sampling runner before
  /// this method is called, so accepting those partitions here would blur a
  /// precondition HOLD into a product execution.
  Future<AlgorithmRelationProductionExecution> runProductionSample({
    required String relationId,
    required String partition,
    required int seed,
  }) async {
    if (!const <String>{
      'normal',
      'boundary',
      'adversarial',
    }.contains(partition)) {
      throw ArgumentError.value(
        partition,
        'partition',
        'Only applicable production partitions may execute.',
      );
    }
    return switch (relationId) {
      'runtime_rule_support.path_permutation' => _sampleRuntimeRuleSupport(
        partition: partition,
        seed: seed,
      ),
      'catalog_resolution.input_permutation' => _sampleCatalogResolution(
        partition: partition,
        seed: seed,
      ),
      'source_authority.jurisdiction_order' => _sampleSourceAuthority(
        partition: partition,
        seed: seed,
      ),
      'runtime_rule_engine.jurisdiction_and_units' => _sampleRuntimeRuleEngine(
        partition: partition,
        seed: seed,
      ),
      'rule_registry_compiler.schema_rejection' => _sampleRuleRegistryCompiler(
        partition: partition,
        seed: seed,
      ),
      'fact_conflict.order_and_scope' => _sampleFactConflict(
        partition: partition,
        seed: seed,
      ),
      'recommendation_orchestrator.deterministic_fallback' =>
        await _sampleRecommendationOrchestrator(
          partition: partition,
          seed: seed,
        ),
      'local_ai_adapter.consent_endpoint_whitelist' =>
        await _sampleLocalAiAdapter(partition: partition, seed: seed),
      _ => throw ArgumentError.value(
        relationId,
        'relationId',
        'Unsupported production relation.',
      ),
    };
  }

  AlgorithmExecutableContractReport verifyObservations(
    Map<String, Map<String, Object?>> observations, {
    String? configurationSha256,
    String? sourceBundleSha256,
    Map<String, String> blockedChecks = const <String, String>{},
  }) {
    final configuration =
        configurationSha256 ??
        AlgorithmConfigurationIdentity.defaults().sha256Digest;
    final sourceBundle =
        sourceBundleSha256 ??
        AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256;
    final failures = <String>[];
    final registered = AlgorithmRegistry.all.map((entry) => entry.id).toSet();
    final expectedIds = specifications.map((spec) => spec.id).toSet();
    final extraIds = observations.keys.toSet().difference(expectedIds).toList()
      ..sort();
    if (extraIds.isNotEmpty) failures.add('contract.extra_observation');
    if (!_isSha256(configuration)) {
      failures.add('contract.configuration_identity_invalid');
    } else if (configuration !=
        AlgorithmConfigurationIdentity.defaults().sha256Digest) {
      failures.add('contract.configuration_identity_drift');
    }
    if (!_isSha256(sourceBundle)) {
      failures.add('contract.source_bundle_identity_invalid');
    } else if (sourceBundle !=
        AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256) {
      failures.add('contract.source_bundle_identity_drift');
    }
    if (coveredAlgorithmIds.toSet().length != coveredAlgorithmIds.length ||
        coveredAlgorithmIds.toSet().difference(registered).isNotEmpty ||
        specifications.map((spec) => spec.algorithmId).toSet().length != 8) {
      failures.add('contract.algorithm_registry_coverage_invalid');
    }

    final checks = <AlgorithmExecutableContractCheckResult>[];
    for (final spec in specifications) {
      final blockedCode = blockedChecks[spec.id];
      if (blockedCode != null) {
        checks.add(
          AlgorithmExecutableContractCheckResult(
            spec: spec,
            status: AlgorithmExecutableContractStatus.blocked,
            observation: const <String, Object?>{},
            observationSha256: 'unavailable',
            failureCodes: <String>[blockedCode],
          ),
        );
        continue;
      }
      final observation = observations[spec.id];
      if (observation == null) {
        checks.add(
          AlgorithmExecutableContractCheckResult(
            spec: spec,
            status: AlgorithmExecutableContractStatus.failed,
            observation: const <String, Object?>{},
            observationSha256: 'unavailable',
            failureCodes: const <String>['contract.observation_missing'],
          ),
        );
        continue;
      }
      final checkFailures = <String>[];
      if (_containsNonFinite(observation)) {
        checkFailures.add('contract.observation_non_finite');
      }
      final digest = checkFailures.isEmpty
          ? AlgorithmConfigurationIdentity.digestConfiguration(observation)
          : 'unavailable';
      final expectedDigest = AlgorithmConfigurationIdentity.digestConfiguration(
        expectedObservations[spec.id]!,
      );
      if (digest != expectedDigest) {
        checkFailures.add('contract.observation_digest_mismatch');
      }
      checks.add(
        AlgorithmExecutableContractCheckResult(
          spec: spec,
          status: checkFailures.isEmpty
              ? AlgorithmExecutableContractStatus.passed
              : AlgorithmExecutableContractStatus.failed,
          observation: observation,
          observationSha256: digest,
          failureCodes: checkFailures,
        ),
      );
    }
    return AlgorithmExecutableContractReport(
      specificationSha256: specificationSha256,
      configurationSha256: configuration,
      sourceBundleSha256: sourceBundle,
      checks: checks,
      integrityFailureCodes: failures,
    );
  }

  AlgorithmRelationProductionExecution _sampleRuntimeRuleSupport({
    required String partition,
    required int seed,
  }) {
    const support = RuntimeRuleSupport();
    final token = _sampleToken(seed);
    final ruleJson = Map<String, dynamic>.from(baselineCdssRules.first);
    final conditions = Map<String, dynamic>.from(ruleJson['when'] as Map);
    final baselineChildren = (conditions['all'] as List<dynamic>)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList(growable: false);
    final duplicateCount = switch (partition) {
      'boundary' => 1,
      'adversarial' => 2,
      _ => 0,
    };
    final sourceChildren = <Map<String, dynamic>>[
      ..._rotate(baselineChildren, token % baselineChildren.length),
      for (var index = 0; index < duplicateCount; index += 1)
        Map<String, dynamic>.from(baselineChildren[index]),
    ];
    final followUpChildren = sourceChildren.reversed
        .map(Map<String, dynamic>.from)
        .toList(growable: false);
    final sourceRuleJson = Map<String, dynamic>.from(ruleJson)
      ..['when'] = <String, dynamic>{'all': sourceChildren};
    final followUpRuleJson = Map<String, dynamic>.from(ruleJson)
      ..['when'] = <String, dynamic>{'all': followUpChildren};
    final sourcePaths =
        support
            .collectReferencedPaths(
              sourceRuleJson['when'] as Map<String, dynamic>,
            )
            .toList()
          ..sort();
    final followUpPaths =
        support
            .collectReferencedPaths(
              followUpRuleJson['when'] as Map<String, dynamic>,
            )
            .toList()
          ..sort();
    final compiler = RuleRegistryCompiler();
    final sourceRule = compiler.compileJson(
      sourceRuleJson,
      rulesVersion: 'production-sample-$token',
    );
    final followUpRule = compiler.compileJson(
      followUpRuleJson,
      rulesVersion: 'production-sample-$token',
    );
    final context = _runtimeContext(dailyDoseMg: null);
    final sourceMissing =
        support
            .missingFieldsForRule(context: context, rule: sourceRule)
            .toList()
          ..sort();
    final followUpMissing =
        support
            .missingFieldsForRule(context: context, rule: followUpRule)
            .toList()
          ..sort();
    final sourceOutput = <String, Object?>{
      'paths': sourcePaths,
      'missing_fields': sourceMissing,
    };
    final followUpOutput = <String, Object?>{
      'paths': followUpPaths,
      'missing_fields': followUpMissing,
    };
    return AlgorithmRelationProductionExecution(
      relationId: 'runtime_rule_support.path_permutation',
      partition: partition,
      seed: seed,
      sourceInput: <String, Object?>{
        'when': sourceRuleJson['when'],
        'daily_dose_mg': null,
      },
      followUpInput: <String, Object?>{
        'when': followUpRuleJson['when'],
        'daily_dose_mg': null,
      },
      sourceOutput: sourceOutput,
      followUpOutput: followUpOutput,
      relationObservation: <String, Object?>{
        'forward_paths': sourcePaths,
        'reversed_paths': followUpPaths,
        'permutation_preserved':
            _sameStrings(sourcePaths, followUpPaths) &&
            _sameStrings(sourceMissing, followUpMissing),
        'forward_missing_fields': sourceMissing,
        'reversed_missing_fields': followUpMissing,
      },
      sourceApiInvocationCount: 3,
      followUpApiInvocationCount: 3,
    );
  }

  AlgorithmRelationProductionExecution _sampleCatalogResolution({
    required String partition,
    required int seed,
  }) {
    const engine = CatalogResolutionEngine();
    final token = _sampleToken(seed);
    final targetName = switch (partition) {
      'boundary' => 'A $token',
      'adversarial' => 'Alpha-meal-$token',
      _ => 'Alpha meal $token',
    };
    final alpha = _contractFood('synthetic.food.alpha.$token', targetName);
    final beta = _contractFood(
      'synthetic.food.beta.$token',
      'Beta meal $token',
    );
    final gamma = _contractFood(
      'synthetic.food.gamma.$token',
      'Gamma meal $token',
    );
    final sourceFoods = <FoodItem>[alpha, beta, gamma];
    final followUpFoods = sourceFoods.reversed.toList(growable: false);
    final query = partition == 'boundary' ? '  $targetName  ' : targetName;
    final source = engine.resolve(query: query, foods: sourceFoods);
    final followUp = engine.resolve(query: query, foods: followUpFoods);
    final empty = engine.resolve(query: '   ', foods: sourceFoods);
    final sourceOutput = <String, Object?>{
      'top_candidate_id': source.bestCandidate?.candidateId,
      'status': source.status,
    };
    final followUpOutput = <String, Object?>{
      'top_candidate_id': followUp.bestCandidate?.candidateId,
      'status': followUp.status,
      'empty_query_status': empty.status,
    };
    return AlgorithmRelationProductionExecution(
      relationId: 'catalog_resolution.input_permutation',
      partition: partition,
      seed: seed,
      sourceInput: <String, Object?>{
        'query': query,
        'food_ids': sourceFoods.map((entry) => entry.id).toList(),
      },
      followUpInput: <String, Object?>{
        'query': query,
        'food_ids': followUpFoods.map((entry) => entry.id).toList(),
        'empty_query': '   ',
      },
      sourceOutput: sourceOutput,
      followUpOutput: followUpOutput,
      relationObservation: <String, Object?>{
        'forward_top_candidate_id': source.bestCandidate?.candidateId,
        'reversed_top_candidate_id': followUp.bestCandidate?.candidateId,
        'forward_status': source.status,
        'reversed_status': followUp.status,
        'permutation_preserved':
            source.bestCandidate?.candidateId ==
                followUp.bestCandidate?.candidateId &&
            source.status == followUp.status,
        'empty_query_status': empty.status,
      },
      sourceApiInvocationCount: 1,
      followUpApiInvocationCount: 2,
    );
  }

  AlgorithmRelationProductionExecution _sampleSourceAuthority({
    required String partition,
    required int seed,
  }) {
    final scorer = SourceAuthorityScorer();
    final token = _sampleToken(seed);
    final foreignJurisdictions = <String>['JP', 'FR', 'GB', 'DE'];
    final foreignJurisdiction =
        foreignJurisdictions[token % foreignJurisdictions.length];
    final exact = _sampleSource(
      id: 'synthetic.official.us.$token',
      jurisdiction: 'US',
      tier: SourceAuthorityTier.officialLabelInJurisdiction,
    );
    final foreign = _sampleSource(
      id: 'synthetic.official.foreign.$token',
      jurisdiction: foreignJurisdiction,
      tier: SourceAuthorityTier.officialLabelInJurisdiction,
    );
    final synthetic = _sampleSource(
      id: 'synthetic.seed.us.$token',
      jurisdiction: 'US',
      tier: SourceAuthorityTier.syntheticDemo,
    );
    final sourceOrder = _rotate(<SourceDocumentMetadata>[
      exact,
      foreign,
      synthetic,
    ], token % 3);
    final followUpOrder = sourceOrder.reversed.toList(growable: false);
    final chain = <String>['US', 'GLOBAL'];
    Map<String, double> scoreAll(List<SourceDocumentMetadata> sources) => {
      for (final source in sources)
        source.sourceDocId: scorer.score(source, userJurisdictionChain: chain),
    };
    final sourceScores = scoreAll(sourceOrder);
    final followUpScores = scoreAll(followUpOrder);
    final exactScore = sourceScores[exact.sourceDocId]!;
    final foreignScore = sourceScores[foreign.sourceDocId]!;
    final syntheticScore = sourceScores[synthetic.sourceDocId]!;
    return AlgorithmRelationProductionExecution(
      relationId: 'source_authority.jurisdiction_order',
      partition: partition,
      seed: seed,
      sourceInput: <String, Object?>{
        'source_ids': sourceOrder.map((entry) => entry.sourceDocId).toList(),
        'jurisdiction_chain': chain,
      },
      followUpInput: <String, Object?>{
        'source_ids': followUpOrder.map((entry) => entry.sourceDocId).toList(),
        'jurisdiction_chain': chain,
      },
      sourceOutput: <String, Object?>{'scores': sourceScores},
      followUpOutput: <String, Object?>{'scores': followUpScores},
      relationObservation: <String, Object?>{
        'official_exact_score': exactScore,
        'official_foreign_score': foreignScore,
        'synthetic_score': syntheticScore,
        'strict_order':
            exactScore > foreignScore && foreignScore > syntheticScore,
        'seed_override': scorer.seedMayOverride(synthetic, exact),
        'cross_jurisdiction_conflict': scorer
            .classifyConflict(a: exact, b: foreign, valuesAgree: false)
            .name,
      },
      sourceApiInvocationCount: 3,
      followUpApiInvocationCount: 5,
    );
  }

  AlgorithmRelationProductionExecution _sampleRuntimeRuleEngine({
    required String partition,
    required int seed,
  }) {
    final compiler = RuleRegistryCompiler();
    final engine = RuntimeRuleEngine();
    final token = _sampleToken(seed);
    final thresholdMg = 50.0 + (token % 450);
    final doseMg = switch (partition) {
      'boundary' => thresholdMg,
      'adversarial' => thresholdMg + 0.001,
      _ => thresholdMg + 25,
    };
    final context = _runtimeContext(dailyDoseMg: doseMg);
    final rows = <Map<String, Object?>>[
      <String, Object?>{
        'region_code': 'US',
        'jurisdiction_chain_json': jsonEncode(<String>[
          'US_DB',
          'SYNTHETIC_REGION_$token',
          'GLOBAL',
        ]),
      },
    ];
    final mgId = 'contract.sample.$token.mg';
    final gramId = 'contract.sample.$token.g';
    final mgRule = compiler.compileJson(
      _doseRule(id: mgId, value: thresholdMg, unit: 'mg'),
      rulesVersion: 'production-sample-$token',
    );
    final gramRule = compiler.compileJson(
      _doseRule(id: gramId, value: thresholdMg / 1000, unit: 'g'),
      rulesVersion: 'production-sample-$token',
    );
    final source = engine.evaluateCandidates(
      context: context,
      rules: <RuleRegistryEntry>[mgRule],
    );
    final followUp = engine.evaluateCandidates(
      context: context,
      rules: <RuleRegistryEntry>[gramRule],
    );
    final chain = engine.resolveJurisdictionChain(
      context,
      regionJurisdictionRows: rows,
    );
    final jurisdictionSource = engine.regionJurisdictionMapSource(
      context,
      regionJurisdictionRows: rows,
    );
    final sourceIds = source.map((entry) => entry.rule.ruleId).toList();
    final followUpIds = followUp.map((entry) => entry.rule.ruleId).toList();
    return AlgorithmRelationProductionExecution(
      relationId: 'runtime_rule_engine.jurisdiction_and_units',
      partition: partition,
      seed: seed,
      sourceInput: <String, Object?>{
        'daily_dose_mg': doseMg,
        'threshold': <String, Object?>{'value': thresholdMg, 'unit': 'mg'},
        'jurisdiction_rows': rows,
      },
      followUpInput: <String, Object?>{
        'daily_dose_mg': doseMg,
        'threshold': <String, Object?>{
          'value': thresholdMg / 1000,
          'unit': 'g',
        },
        'jurisdiction_rows': rows,
      },
      sourceOutput: <String, Object?>{'rule_ids': sourceIds},
      followUpOutput: <String, Object?>{'rule_ids': followUpIds},
      relationObservation: <String, Object?>{
        'jurisdiction_chain': chain,
        'jurisdiction_source': jurisdictionSource,
        'mg_rule_ids': sourceIds,
        'gram_rule_ids': followUpIds,
        'equivalent_fire_count': source.length == followUp.length,
      },
      sourceApiInvocationCount: 3,
      followUpApiInvocationCount: 3,
    );
  }

  AlgorithmRelationProductionExecution _sampleRuleRegistryCompiler({
    required String partition,
    required int seed,
  }) {
    final compiler = RuleRegistryCompiler();
    final token = _sampleToken(seed);
    final ruleId = 'contract.sample.compiler.$token';
    final validJson = _doseRule(
      id: ruleId,
      value: 50.0 + (token % 450),
      unit: 'mg',
    );
    if (partition == 'adversarial') {
      validJson['unrecognized_synthetic_metadata'] = <String, Object?>{
        'token': token,
      };
    }
    final valid = compiler.compileJsonList(<Map<String, dynamic>>[
      validJson,
    ], rulesVersion: 'production-sample-$token');
    final invalid = jsonDecode(jsonEncode(validJson)) as Map<String, dynamic>
      ..remove('rule_id');
    var rejected = false;
    String? rejectionType;
    try {
      compiler.compileJson(invalid, rulesVersion: 'production-sample-$token');
    } on RuleValidationException catch (error) {
      rejected = true;
      rejectionType = error.runtimeType.toString();
    }
    return AlgorithmRelationProductionExecution(
      relationId: 'rule_registry_compiler.schema_rejection',
      partition: partition,
      seed: seed,
      sourceInput: <String, Object?>{'rule': validJson},
      followUpInput: <String, Object?>{'rule': invalid},
      sourceOutput: <String, Object?>{
        'valid_count': valid.length,
        'valid_rule_id': valid.single.ruleId,
      },
      followUpOutput: <String, Object?>{
        'rejected': rejected,
        'rejection_type': rejectionType,
      },
      relationObservation: <String, Object?>{
        'valid_count': valid.length,
        'valid_rule_id': valid.single.ruleId,
        'missing_identity_rejected': rejected,
      },
      sourceApiInvocationCount: 1,
      followUpApiInvocationCount: 1,
    );
  }

  AlgorithmRelationProductionExecution _sampleFactConflict({
    required String partition,
    required int seed,
  }) {
    final engine = FactConflictEngine();
    final token = _sampleToken(seed);
    final observationValue = switch (partition) {
      'boundary' => '10.0001',
      'adversarial' => '999.999',
      _ => '${10 + (token % 20)}',
    };
    final conflictingValue = partition == 'boundary' ? '10' : '1';
    final scope = 'scope.synthetic.$token';
    final observation = _observation(scope: scope, value: observationValue);
    final conflicting = _fact(
      id: 'fact.conflicting.$token',
      entityKey: observation.entityKey,
      scope: scope,
      value: conflictingValue,
    );
    final unrelated = _fact(
      id: 'fact.unrelated.$token',
      entityKey: 'OTHER#SYNTHETIC#$token',
      scope: 'scope.other.$token',
      value: '3',
    );
    final sourceFacts = <ResolvedFactRecord>[unrelated, conflicting];
    final followUpFacts = sourceFacts.reversed.toList(growable: false);
    final source = engine.classify(
      observation: observation,
      existingFacts: sourceFacts,
    );
    final followUp = engine.classify(
      observation: observation,
      existingFacts: followUpFacts,
    );
    final differentScope = engine.classify(
      observation: _observation(
        scope: 'scope.alternate.$token',
        value: observationValue,
      ),
      existingFacts: <ResolvedFactRecord>[conflicting],
    );
    return AlgorithmRelationProductionExecution(
      relationId: 'fact_conflict.order_and_scope',
      partition: partition,
      seed: seed,
      sourceInput: <String, Object?>{
        'observation_id': observation.observationId,
        'fact_ids': sourceFacts.map((entry) => entry.factId).toList(),
      },
      followUpInput: <String, Object?>{
        'observation_id': observation.observationId,
        'fact_ids': followUpFacts.map((entry) => entry.factId).toList(),
        'alternate_scope': 'scope.alternate.$token',
      },
      sourceOutput: <String, Object?>{'classification': source.type.name},
      followUpOutput: <String, Object?>{
        'classification': followUp.type.name,
        'different_scope': differentScope.type.name,
      },
      relationObservation: <String, Object?>{
        'forward': source.type.name,
        'reversed': followUp.type.name,
        'permutation_preserved': source.type == followUp.type,
        'different_scope': differentScope.type.name,
      },
      sourceApiInvocationCount: 1,
      followUpApiInvocationCount: 2,
    );
  }

  Future<AlgorithmRelationProductionExecution>
  _sampleRecommendationOrchestrator({
    required String partition,
    required int seed,
  }) async {
    final token = _sampleToken(seed);
    final rotation = switch (partition) {
      'boundary' => 2,
      'adversarial' => 3,
      _ => 1,
    };
    final dataset = RecommendationBenchmarkDataset(
      version: '${localAiReplayScenarioDataset.version}.sample.$token',
      cases: _rotate(
        localAiReplayScenarioDataset.cases,
        token % localAiReplayScenarioDataset.cases.length,
      ),
    );
    final observations = await _observeRecommendationAndLocalAi(
      dataset: dataset,
      rerankRotation: rotation,
    );
    final observation =
        observations['recommendation_orchestrator.deterministic_fallback']!;
    final pairs = (observation['ranking_pairs']! as List<Object?>)
        .cast<Map<String, Object?>>();
    final sourceRankings = <String, Object?>{
      for (final pair in pairs)
        pair['case_id']! as String: pair['deterministic_ranking'],
    };
    final followUpRankings = <String, Object?>{
      for (final pair in pairs)
        pair['case_id']! as String: pair['observed_ranking'],
    };
    return AlgorithmRelationProductionExecution(
      relationId: 'recommendation_orchestrator.deterministic_fallback',
      partition: partition,
      seed: seed,
      sourceInput: <String, Object?>{
        'dataset_version': dataset.version,
        'case_ids': dataset.cases.map((entry) => entry.caseId).toList(),
        'mode': 'conservativeOnly',
      },
      followUpInput: <String, Object?>{
        'dataset_version': dataset.version,
        'case_ids': dataset.cases.map((entry) => entry.caseId).toList(),
        'mode': 'hybridLocalLlm',
        'loopback_rerank_rotation': rotation,
      },
      sourceOutput: <String, Object?>{'rankings_by_case': sourceRankings},
      followUpOutput: <String, Object?>{
        'rankings_by_case': followUpRankings,
        'decision_paths': observation['decision_paths'],
      },
      relationObservation: observation,
      sourceApiInvocationCount: dataset.cases.length,
      followUpApiInvocationCount: dataset.cases.length + 2,
    );
  }

  Future<AlgorithmRelationProductionExecution> _sampleLocalAiAdapter({
    required String partition,
    required int seed,
  }) async {
    final token = _sampleToken(seed);
    final rotation = switch (partition) {
      'boundary' => 2,
      'adversarial' => 3,
      _ => 1,
    };
    final dataset = RecommendationBenchmarkDataset(
      version: '${localAiReplayScenarioDataset.version}.sample.$token',
      cases: _rotate(
        localAiReplayScenarioDataset.cases,
        (token + 1) % localAiReplayScenarioDataset.cases.length,
      ),
    );
    final observations = await _observeRecommendationAndLocalAi(
      dataset: dataset,
      rerankRotation: rotation,
    );
    final observation =
        observations['local_ai_adapter.consent_endpoint_whitelist']!;
    return AlgorithmRelationProductionExecution(
      relationId: 'local_ai_adapter.consent_endpoint_whitelist',
      partition: partition,
      seed: seed,
      sourceInput: <String, Object?>{
        'dataset_version': dataset.version,
        'case_ids': dataset.cases.map((entry) => entry.caseId).toList(),
        'loopback_rerank_rotation': rotation,
        'consent': true,
        'endpoint_class': 'loopback',
      },
      followUpInput: <String, Object?>{
        'consent_withdrawn_probe': true,
        'remote_endpoint_probe': Uri.https(
          'example.invalid',
          '/api/chat',
        ).toString(),
      },
      sourceOutput: <String, Object?>{
        'candidate_sets_preserved': observation['candidate_sets_preserved'],
        'hybrid_case_count': observation['hybrid_case_count'],
        'hybrid_ranking_pairs': observation['hybrid_ranking_pairs'],
      },
      followUpOutput: <String, Object?>{
        'consent_withdrawn_available':
            observation['consent_withdrawn_available'],
        'consent_withdrawn_skipped': observation['consent_withdrawn_skipped'],
        'consent_withdrawn_transport_calls':
            observation['consent_withdrawn_transport_calls'],
        'remote_endpoint_available': observation['remote_endpoint_available'],
        'remote_endpoint_transport_calls':
            observation['remote_endpoint_transport_calls'],
      },
      relationObservation: observation,
      sourceApiInvocationCount: dataset.cases.length * 2,
      followUpApiInvocationCount: 2,
    );
  }

  Map<String, Object?> _observeRuntimeRuleSupport() {
    const support = RuntimeRuleSupport();
    final ruleJson = Map<String, dynamic>.from(baselineCdssRules.first);
    final conditions = Map<String, dynamic>.from(ruleJson['when'] as Map);
    final children = (conditions['all'] as List<dynamic>)
        .map((entry) => Map<String, dynamic>.from(entry as Map))
        .toList(growable: false);
    final forward = support.collectReferencedPaths(<String, dynamic>{
      'all': children,
    }).toList()..sort();
    final reversed = support.collectReferencedPaths(<String, dynamic>{
      'all': children.reversed.toList(growable: false),
    }).toList()..sort();
    final compiler = RuleRegistryCompiler();
    final rule = compiler.compileJson(ruleJson, rulesVersion: 'contract-v1');
    final reversedRuleJson = Map<String, dynamic>.from(ruleJson)
      ..['when'] = <String, dynamic>{
        'all': children.reversed.toList(growable: false),
      };
    final reversedRule = compiler.compileJson(
      reversedRuleJson,
      rulesVersion: 'contract-v1',
    );
    final forwardMissing =
        support
            .missingFieldsForRule(
              context: _runtimeContext(dailyDoseMg: null),
              rule: rule,
            )
            .toList()
          ..sort();
    final reversedMissing =
        support
            .missingFieldsForRule(
              context: _runtimeContext(dailyDoseMg: null),
              rule: reversedRule,
            )
            .toList()
          ..sort();
    return <String, Object?>{
      'forward_paths': forward,
      'reversed_paths': reversed,
      'permutation_preserved':
          _sameStrings(forward, reversed) &&
          _sameStrings(forwardMissing, reversedMissing),
      'forward_missing_fields': forwardMissing,
      'reversed_missing_fields': reversedMissing,
    };
  }

  Map<String, Object?> _observeCatalogResolution() {
    const engine = CatalogResolutionEngine();
    final alpha = _contractFood('synthetic.food.alpha', 'Alpha meal');
    final beta = _contractFood('synthetic.food.beta', 'Beta meal');
    final first = engine.resolve(
      query: 'Alpha meal',
      foods: <FoodItem>[alpha, beta],
    );
    final second = engine.resolve(
      query: 'Alpha meal',
      foods: <FoodItem>[beta, alpha],
    );
    final empty = engine.resolve(query: '   ', foods: <FoodItem>[alpha, beta]);
    return <String, Object?>{
      'forward_top_candidate_id': first.bestCandidate?.candidateId,
      'reversed_top_candidate_id': second.bestCandidate?.candidateId,
      'forward_status': first.status,
      'reversed_status': second.status,
      'permutation_preserved':
          first.bestCandidate?.candidateId ==
              second.bestCandidate?.candidateId &&
          first.status == second.status,
      'empty_query_status': empty.status,
    };
  }

  Map<String, Object?> _observeSourceAuthority() {
    final scorer = SourceAuthorityScorer();
    const officialExact = _ContractSources.officialUs;
    const officialForeign = _ContractSources.officialJp;
    const synthetic = _ContractSources.syntheticUs;
    final exactScore = scorer.score(
      officialExact,
      userJurisdictionChain: const <String>['US', 'GLOBAL'],
    );
    final foreignScore = scorer.score(
      officialForeign,
      userJurisdictionChain: const <String>['US', 'GLOBAL'],
    );
    final syntheticScore = scorer.score(
      synthetic,
      userJurisdictionChain: const <String>['US', 'GLOBAL'],
    );
    return <String, Object?>{
      'official_exact_score': exactScore,
      'official_foreign_score': foreignScore,
      'synthetic_score': syntheticScore,
      'strict_order':
          exactScore > foreignScore && foreignScore > syntheticScore,
      'seed_override': scorer.seedMayOverride(synthetic, officialExact),
      'cross_jurisdiction_conflict': scorer
          .classifyConflict(
            a: officialExact,
            b: officialForeign,
            valuesAgree: false,
          )
          .name,
    };
  }

  Map<String, Object?> _observeRuntimeRuleEngine() {
    final compiler = RuleRegistryCompiler();
    final engine = RuntimeRuleEngine();
    final context = _runtimeContext(dailyDoseMg: 250);
    const rows = <Map<String, Object?>>[
      <String, Object?>{
        'region_code': 'US',
        'jurisdiction_chain_json': '["US_DB","NORTH_AMERICA_DB","GLOBAL"]',
      },
    ];
    final mgRule = compiler.compileJson(
      _doseRule(id: 'contract.dose.mg', value: 200, unit: 'mg'),
      rulesVersion: 'contract-v1',
    );
    final gramRule = compiler.compileJson(
      _doseRule(id: 'contract.dose.g', value: 0.2, unit: 'g'),
      rulesVersion: 'contract-v1',
    );
    final mg = engine.evaluateCandidates(
      context: context,
      rules: <RuleRegistryEntry>[mgRule],
    );
    final grams = engine.evaluateCandidates(
      context: context,
      rules: <RuleRegistryEntry>[gramRule],
    );
    return <String, Object?>{
      'jurisdiction_chain': engine.resolveJurisdictionChain(
        context,
        regionJurisdictionRows: rows,
      ),
      'jurisdiction_source': engine.regionJurisdictionMapSource(
        context,
        regionJurisdictionRows: rows,
      ),
      'mg_rule_ids': mg
          .map((entry) => entry.rule.ruleId)
          .toList(growable: false),
      'gram_rule_ids': grams
          .map((entry) => entry.rule.ruleId)
          .toList(growable: false),
      'equivalent_fire_count': mg.length == grams.length,
    };
  }

  Map<String, Object?> _observeRuleRegistryCompiler() {
    final compiler = RuleRegistryCompiler();
    final valid = compiler.compileJsonList(<Map<String, dynamic>>[
      Map<String, dynamic>.from(baselineCdssRules.first),
    ], rulesVersion: 'contract-v1');
    final invalid =
        jsonDecode(jsonEncode(baselineCdssRules.first)) as Map<String, dynamic>;
    invalid.remove('rule_id');
    var rejected = false;
    try {
      compiler.compileJson(invalid, rulesVersion: 'contract-v1');
    } on RuleValidationException {
      rejected = true;
    }
    return <String, Object?>{
      'valid_count': valid.length,
      'valid_rule_id': valid.single.ruleId,
      'missing_identity_rejected': rejected,
    };
  }

  Map<String, Object?> _observeFactConflict() {
    final engine = FactConflictEngine();
    final observation = _observation(scope: 'scope.us', value: '10');
    final conflicting = _fact(
      id: 'fact.conflicting',
      entityKey: observation.entityKey,
      scope: 'scope.us',
      value: '1',
    );
    final unrelated = _fact(
      id: 'fact.unrelated',
      entityKey: 'OTHER#US#1',
      scope: 'scope.other',
      value: '3',
    );
    final forward = engine.classify(
      observation: observation,
      existingFacts: <ResolvedFactRecord>[unrelated, conflicting],
    );
    final reversed = engine.classify(
      observation: observation,
      existingFacts: <ResolvedFactRecord>[conflicting, unrelated],
    );
    final differentScope = engine.classify(
      observation: _observation(scope: 'scope.fr', value: '0.25'),
      existingFacts: <ResolvedFactRecord>[conflicting],
    );
    return <String, Object?>{
      'forward': forward.type.name,
      'reversed': reversed.type.name,
      'permutation_preserved': forward.type == reversed.type,
      'different_scope': differentScope.type.name,
    };
  }

  Future<Map<String, Map<String, Object?>>> _observeRecommendationAndLocalAi({
    RecommendationBenchmarkDataset dataset = localAiReplayScenarioDataset,
    int? rerankRotation,
  }) async {
    final runner = _buildReplayRunner(rerankRotation: rerankRotation);
    final replay = await runner.run(dataset: dataset);
    final paths =
        replay.cases
            .map(
              (entry) => '${entry.benchmarkCase.caseId}:${entry.decisionPath}',
            )
            .toList(growable: false)
          ..sort();
    final hybridCount = replay.cases
        .where((entry) => entry.decisionPath == 'hybrid_local_ai')
        .length;
    final rankingPairs = replay.cases
        .map(
          (entry) => <String, Object?>{
            'case_id': entry.benchmarkCase.caseId,
            'decision_path': entry.decisionPath,
            'deterministic_ranking': entry.deterministicRanking,
            'observed_ranking': entry.aiRanking,
          },
        )
        .toList(growable: false);
    final hybridRankingPairs = replay.cases
        .where((entry) => entry.decisionPath == 'hybrid_local_ai')
        .map(
          (entry) => <String, Object?>{
            'case_id': entry.benchmarkCase.caseId,
            'deterministic_ranking': entry.deterministicRanking,
            'observed_ranking': entry.aiRanking,
          },
        )
        .toList(growable: false);

    var withdrawnCalls = 0;
    final withdrawnAdapter = LocalAiRecommendationAdapter(
      client: MockClient((_) async {
        withdrawnCalls += 1;
        return http.Response('{}', 200);
      }),
    );
    final withdrawn = await withdrawnAdapter.probe(
      userProfile: UserProfile.defaults()
          .copyWith(localAiProviderPreference: LocalAiProviders.ollama)
          .withLocalAiConsentDecision(
            enabled: false,
            recordedAt: DateTime.utc(2026, 8, 31),
            source: 'executable_contract_fixture',
          ),
    );

    var remoteCalls = 0;
    final remoteAdapter = LocalAiRecommendationAdapter(
      client: MockClient((_) async {
        remoteCalls += 1;
        return http.Response('{}', 200);
      }),
    );
    final remote = await remoteAdapter.probe(
      userProfile: UserProfile.defaults()
          .copyWith(
            localAiProviderPreference: LocalAiProviders.ollama,
            localAiOllamaEndpoint: Uri(
              scheme: 'https',
              host: 'example.invalid',
              path: '/api/chat',
            ).toString(),
          )
          .withLocalAiConsentDecision(
            enabled: true,
            recordedAt: DateTime.utc(2026, 8, 31),
            source: 'executable_contract_fixture',
          ),
    );
    return <String, Map<String, Object?>>{
      'recommendation_orchestrator.deterministic_fallback': <String, Object?>{
        'case_count': replay.cases.length,
        'decision_paths': paths,
        'ranking_pairs': rankingPairs,
        'candidate_sets_preserved': replay.allPreservedCandidateSet,
      },
      'local_ai_adapter.consent_endpoint_whitelist': <String, Object?>{
        'candidate_sets_preserved': replay.allPreservedCandidateSet,
        'hybrid_case_count': hybridCount,
        'hybrid_ranking_pairs': hybridRankingPairs,
        'consent_withdrawn_available': withdrawn.available,
        'consent_withdrawn_skipped': withdrawn.skipped,
        'consent_withdrawn_transport_calls': withdrawnCalls,
        'remote_endpoint_available': remote.available,
        'remote_endpoint_transport_calls': remoteCalls,
      },
    };
  }

  RecommendationReplayRunner _buildReplayRunner({int? rerankRotation}) {
    final projection = CdssCatalogProjectionService(
      database: InMemoryCdssDatabase(),
    );
    final hybrid = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: projection,
      localAiAdapter: LocalAiRecommendationAdapter(
        client: _contractLoopbackClient(rerankRotation: rerankRotation),
      ),
    );
    final deterministic = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: projection,
      localAiAdapter: null,
    );
    return RecommendationReplayRunner(
      hybridOrchestrator: hybrid,
      deterministicOrchestrator: deterministic,
      foodRepository: FoodRepository.createDefault(),
      medicationRepository: MedicationRepository.createDefault(),
    );
  }

  MockClient _contractLoopbackClient({int? rerankRotation}) => MockClient((
    request,
  ) async {
    if (request.method == 'GET' && request.url.path == '/api/tags') {
      return http.Response(
        jsonEncode(<String, Object?>{
          'models': <Object?>[
            <String, Object?>{'name': 'gemma3n:e2b', 'model': 'gemma3n:e2b'},
            <String, Object?>{
              'name': LocalAiRecommendedModels.medGemmaText,
              'model': LocalAiRecommendedModels.medGemmaText,
            },
          ],
        }),
        200,
      );
    }
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final prompt = ((body['messages'] as List<dynamic>).first as Map)['content']
        .toString();
    if (prompt.contains('reply with {"ok":true}')) {
      return _ollamaContent(<String, Object?>{'ok': true});
    }
    if (prompt.contains('polishing ParkinSUM next-meal')) {
      final ids = _jsonArrayAfter(prompt, 'Allowed food_id keys JSON: ');
      return _ollamaContent(<String, Object?>{
        'summary': 'Synthetic copy-only polish.',
        'candidate_notes': <String, String>{
          for (final id in ids) id: 'Synthetic bounded note for $id.',
        },
      });
    }
    if (prompt.contains('reranking already-safe')) {
      final ids = _jsonArrayAfter(prompt, 'Allowed candidate_ids JSON: ');
      final reordered = rerankRotation == null
          ? ids.reversed.toList(growable: false)
          : _rotate(ids, rerankRotation);
      return _ollamaContent(<String, Object?>{
        'candidate_ids': reordered,
        'summary': 'Synthetic whitelist-only reorder.',
        'safety_checks': <String>['No candidate added or removed.'],
        'ranking_rationale': <String>['Used fixed synthetic features.'],
      });
    }
    return _ollamaContent(<String, Object?>{});
  });

  http.Response _ollamaContent(Map<String, Object?> payload) => http.Response(
    jsonEncode(<String, Object?>{
      'message': <String, Object?>{'content': jsonEncode(payload)},
    }),
    200,
  );

  List<String> _jsonArrayAfter(String prompt, String marker) {
    final start = prompt.indexOf(marker);
    if (start < 0) return const <String>[];
    final rest = prompt.substring(start + marker.length);
    final open = rest.indexOf('[');
    final close = rest.indexOf(']');
    if (open < 0 || close < open) return const <String>[];
    return (jsonDecode(rest.substring(open, close + 1)) as List<dynamic>)
        .map((entry) => entry.toString())
        .toList(growable: false);
  }

  static FoodItem _contractFood(String id, String name) => FoodItem(
    id: id,
    name: name,
    category: FoodCategory.carbs,
    sourceSystem: 'synthetic_demo',
    sourceFoodCode: id,
    jurisdiction: 'GLOBAL',
    basisType: 'per_100g',
    proteinG: 1,
    carbsG: 10,
    fatG: 1,
    fiberG: 1,
    sodiumMg: 1,
  );

  static UnifiedRuntimeContext _runtimeContext({
    required double? dailyDoseMg,
  }) => UnifiedRuntimeContext(
    userProfile: const UserProfileRuntimeContext(
      patientId: 'synthetic.contract',
      registrationRegion: 'US',
      displayLocale: 'en-US',
      contentJurisdictionOverride: <String>[],
      dietProfileRegion: 'US',
      timezone: 'America/Toronto',
    ),
    drug: DrugRuntimeContext(
      id: 'synthetic.drug',
      genericName: 'levodopa',
      brandName: null,
      activeIngredients: const <String>['levodopa'],
      substanceTags: const <String>['levodopa'],
      formulation: 'tablet',
      dosageForm: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      dailyDoseMg: dailyDoseMg,
      jurisdiction: 'US',
    ),
    meal: const MealRuntimeContext(
      id: 'synthetic.meal',
      totalProteinG: 10,
      tyramineMgEstimate: 0,
      highFatHighCalorie: false,
      itemIds: <String>['synthetic.food.alpha'],
    ),
    coevent: null,
    enteralFeed: null,
    timestamps: const TimestampRuntimeContext(
      drugTime: null,
      mealTime: null,
      coeventTime: null,
    ),
  );

  static Map<String, dynamic> _doseRule({
    required String id,
    required double value,
    required String unit,
  }) => <String, dynamic>{
    'rule_id': id,
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'soft_rule',
    'priority_band': 5,
    'specificity_band': 5,
    'jurisdiction': <String>['GLOBAL'],
    'applies_to': <String, Object?>{
      'subject_types': <String>['drug'],
    },
    'when': <String, Object?>{
      'dose_band': <String, Object?>{
        'path': 'drug.daily_dose_mg',
        'threshold': <String, Object?>{'value': value, 'unit': unit},
        'op': 'gte',
      },
    },
    'then': <String, Object?>{
      'decision': 'INFO',
      'severity': 'low',
      'messages': <String, Object?>{'zh': '合成契约夹具。'},
      'actions': <Object?>[],
      'output_tags': <Object?>[],
    },
    'provenance': <String, Object?>{
      'evidence_level': 'official_database',
      'source_refs': <String>['synthetic:runtime-rule-engine-contract-v1'],
    },
  };

  static ObservationRecord _observation({
    required String scope,
    required String value,
  }) => ObservationRecord(
    observationId: 'synthetic.observation.$scope',
    domain: 'food',
    entityType: 'food_variant',
    entityKey: 'SYNTHETIC_FOOD#US#1',
    attributeCode: 'protein_g',
    valueType: 'numeric_interval',
    value: parseQualifiedValue(value),
    unit: 'g',
    basisType: 'per_100g_edible_part',
    basisAmount: 100,
    scopeHash: scope,
    sourceDocId: 'synthetic:fact-conflict-contract-v1',
    recordLocator: 'fixture',
    methodCode: null,
    extractionConfidence: 1,
  );

  static ResolvedFactRecord _fact({
    required String id,
    required String entityKey,
    required String scope,
    required String value,
  }) => ResolvedFactRecord(
    factId: id,
    entityKey: entityKey,
    attributeCode: 'protein_g',
    scopeHash: scope,
    resolutionStatus: 'resolved',
    chosenObservationId: '$id.observation',
    resolvedValue: parseQualifiedValue(value),
    resolvedUnit: 'g',
    resolutionPolicyId: 'synthetic.contract.policy',
    snapshotId: 'synthetic.contract.snapshot',
    factVersion: 'contract-v1',
    manualOverride: false,
  );

  static SourceDocumentMetadata _sampleSource({
    required String id,
    required String jurisdiction,
    required SourceAuthorityTier tier,
  }) => SourceDocumentMetadata(
    sourceDocId: id,
    sourceSystem: 'synthetic_production_sample',
    jurisdiction: jurisdiction,
    language: 'en',
    sourceOwner: 'synthetic',
    docType: tier == SourceAuthorityTier.syntheticDemo ? 'seed' : 'label',
    authorityTier: tier,
    translationStatus: ReferenceTranslationStatus.notTranslation,
    publishedAt: '2026-01-01',
    effectiveAt: '2026-01-01',
    lastUpdated: '2026-01-01',
    licenseOrUseLimitations: 'Synthetic production-sampling fixture only.',
    sourceRefs: const <String>['synthetic:relation-production-sampling-v1'],
    limitationText: 'Synthetic authority-order production sample.',
  );

  static int _sampleToken(int seed) {
    var state = seed & 0xffffffff;
    state ^= (state << 13) & 0xffffffff;
    state ^= state >> 17;
    state ^= (state << 5) & 0xffffffff;
    return state & 0xffffffff;
  }

  static List<T> _rotate<T>(List<T> values, int amount) {
    if (values.length < 2) return List<T>.of(values, growable: false);
    final offset = amount % values.length;
    return <T>[...values.skip(offset), ...values.take(offset)];
  }

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static bool _containsNonFinite(Object? value) {
    if (value is double) return !value.isFinite;
    if (value is List) return value.any(_containsNonFinite);
    if (value is Map) return value.values.any(_containsNonFinite);
    return false;
  }

  static bool _isSha256(String value) =>
      RegExp(r'^[a-f0-9]{64}$').hasMatch(value);
}

abstract final class _ContractSources {
  static const officialUs = SourceDocumentMetadata(
    sourceDocId: 'synthetic.official.us',
    sourceSystem: 'synthetic_contract',
    jurisdiction: 'US',
    language: 'en',
    sourceOwner: 'synthetic',
    docType: 'label',
    authorityTier: SourceAuthorityTier.officialLabelInJurisdiction,
    translationStatus: ReferenceTranslationStatus.notTranslation,
    publishedAt: '2026-01-01',
    effectiveAt: '2026-01-01',
    lastUpdated: '2026-01-01',
    licenseOrUseLimitations: 'Synthetic fixture only.',
    sourceRefs: <String>['synthetic:source-authority-contract-v1'],
    limitationText: 'Synthetic authority-order fixture.',
  );

  static const officialJp = SourceDocumentMetadata(
    sourceDocId: 'synthetic.official.jp',
    sourceSystem: 'synthetic_contract',
    jurisdiction: 'JP',
    language: 'ja',
    sourceOwner: 'synthetic',
    docType: 'label',
    authorityTier: SourceAuthorityTier.officialLabelInJurisdiction,
    translationStatus: ReferenceTranslationStatus.notTranslation,
    publishedAt: '2026-01-01',
    effectiveAt: '2026-01-01',
    lastUpdated: '2026-01-01',
    licenseOrUseLimitations: 'Synthetic fixture only.',
    sourceRefs: <String>['synthetic:source-authority-contract-v1'],
    limitationText: 'Synthetic authority-order fixture.',
  );

  static const syntheticUs = SourceDocumentMetadata(
    sourceDocId: 'synthetic.seed.us',
    sourceSystem: 'synthetic_contract',
    jurisdiction: 'US',
    language: 'en',
    sourceOwner: 'synthetic',
    docType: 'seed',
    authorityTier: SourceAuthorityTier.syntheticDemo,
    translationStatus: ReferenceTranslationStatus.notTranslation,
    publishedAt: '2026-01-01',
    effectiveAt: '2026-01-01',
    lastUpdated: '2026-01-01',
    licenseOrUseLimitations: 'Synthetic fixture only.',
    sourceRefs: <String>['synthetic:source-authority-contract-v1'],
    limitationText: 'Synthetic authority-order fixture.',
  );
}
