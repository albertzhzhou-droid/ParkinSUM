import 'dart:convert';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../../core/db/cdss_database_memory.dart';
import '../entities/cdss_runtime.dart';
import '../entities/rule_test_case.dart';
import 'cdss_artifact_store_stub.dart';
import 'clinical_decision_support_service.dart';
import 'fact_conflict_engine.dart';
import 'rule_registry_compiler.dart';
import 'runtime_rule_engine.dart';

const ruleTestRunReportSchemaVersion = 1;

enum RuleTestRunStatus { passed, failed, notVerified, bindingMismatch }

/// Broader modes affect this isolated run only, never rule activation.
enum RuleTestExecutionMode { activeOnly, includeDraft, allStatuses }

final class RuleTestAssertion {
  final String path;
  final Object? expected;
  final Object? actual;
  final bool passed;

  RuleTestAssertion({
    required this.path,
    required Object? expected,
    required Object? actual,
    required this.passed,
  }) : expected = _freeze(expected),
       actual = _freeze(actual);

  Map<String, dynamic> toJson() => {
    'path': path,
    'expected': _copy(expected),
    'actual': _copy(actual),
    'passed': passed,
  };
}

final class RuleTestRunReport {
  final RuleTestRunStatus status;
  final RuleTestCase testCase;
  final RuleTestRuleBinding ruleBinding;
  final RuleTestExecutionMode mode;
  final String caseDigest;
  final String inputDigest;
  final String? nativeEngineInputDigest;
  final String rulesDigest;
  final String executedRulesDigest;
  final List<RuleTestAssertion> assertions;
  final EngineRunOutput? output;
  final Map<String, dynamic> engineIdentity;
  final List<Map<String, dynamic>> ruleExecution;
  final int inMemoryAuditRecordCount;

  RuleTestRunReport._({
    required this.status,
    required this.testCase,
    required this.ruleBinding,
    required this.mode,
    required this.executedRulesDigest,
    required List<RuleTestAssertion> assertions,
    required EngineRunOutput? output,
    required Map<String, dynamic> engineIdentity,
    required List<Map<String, dynamic>> ruleExecution,
    required this.inMemoryAuditRecordCount,
  }) : caseDigest = testCase.caseDigest,
       inputDigest = testCase.inputDigest,
       nativeEngineInputDigest = output?.auditEntries.firstOrNull?.inputHash,
       rulesDigest = ruleBinding.contentDigest,
       assertions = List.unmodifiable(assertions),
       output = output == null ? null : _freezeOutput(output),
       engineIdentity = _freeze(engineIdentity) as Map<String, dynamic>,
       ruleExecution = List.unmodifiable(
         ruleExecution.map((r) => _freeze(r) as Map<String, dynamic>),
       );

  Map<String, dynamic> toJson() => {
    'schema_version': ruleTestRunReportSchemaVersion,
    'synthetic_only': true,
    'status': status.name,
    'case_digest': caseDigest,
    'input_digest': inputDigest,
    'native_engine_input_digest': nativeEngineInputDigest,
    'rules_digest': rulesDigest,
    'executed_rules_digest': executedRulesDigest,
    'case': testCase.toJson(),
    'actual_rule_binding': ruleBinding.toJson(),
    'execution_mode': mode.name,
    'rule_execution': _copy(ruleExecution),
    'engine_identity': _copy(engineIdentity),
    'boundaries': {
      'current_engine_execution': true,
      'historical_executable_replay': false,
      'historical_knowledge_base_restored': false,
      'source_documents_included': false,
      'baseline_source_metadata': false,
      'source_reference_scope': 'rule_declared_references_only',
      'jurisdiction_resolution': 'current_engine_static_map',
      'clinical_validation': false,
      'patient_rule_activation_changed': false,
      'artifact_storage': 'isolated_process_memory',
      'timestamps': 'explicit_offset_normalized_to_utc',
      'canonicalization_profile': ruleTestCanonicalizationProfile,
      'portable_numeric_equality':
          'binary64_with_1_equal_1.0_and_zero_sign_normalized',
      'native_engine_input_digest_is_portable': false,
    },
    'assertions': assertions.map((a) => a.toJson()).toList(),
    'in_memory_audit_record_count': inMemoryAuditRecordCount,
    'output': output == null
        ? null
        : {
            'alerts_json': _copy(output!.alertsJson),
            'alerts': output!.alerts.map((a) => _copy(a.toJson())).toList(),
            'audit_entries': output!.auditEntries
                .map((a) => _copy(a.toJson()))
                .toList(),
            'rule_explanations': _copy(output!.ruleExplanationsJson),
            'human_readable_markdown': output!.humanReadableMarkdown,
            'audit_log_jsonl': output!.auditLogJsonl,
          },
  };

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

/// Runs pinned rule JSON on the current Dart engine. No patient service graph,
/// persistent database, source-document database, or activation API is used.
final class SyntheticRuleTestRunner {
  const SyntheticRuleTestRunner();

  Future<RuleTestRunReport> run({
    required RuleTestCase testCase,
    required RuleTestRuleSet ruleSet,
    RuleTestExecutionMode mode = RuleTestExecutionMode.activeOnly,
  }) async {
    final selected = ruleSet.rawRules
        .where((rule) => _included(rule['status'] as String, mode))
        .toList(growable: false);
    final executedDigest = ruleTestJsonDigest('synthetic-executed-rules-v1', {
      'mode': mode.name,
      'rules': selected,
    });
    final identity = AlgorithmConfigurationIdentity.defaults(
      runtimeRules: selected,
    );
    final engineIdentity = <String, dynamic>{
      'id': identity.id,
      'version': identity.version,
      'configuration_sha256': identity.sha256Digest,
      'registered_source_bundle_sha256':
          AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
      'identity_scope': 'declared_current_algorithm_configuration',
    };
    final matches = testCase.binding.matches(ruleSet.binding);
    List<Map<String, dynamic>> execution({required bool ran}) => [
      for (final rule in ruleSet.rawRules)
        {
          'rule_id': rule['rule_id'],
          'rule_version': rule['version'],
          'declared_status': rule['status'],
          'included_by_mode': _included(rule['status'] as String, mode),
          'executed': ran && _included(rule['status'] as String, mode),
        },
    ];
    if (!matches) {
      return RuleTestRunReport._(
        status: RuleTestRunStatus.bindingMismatch,
        testCase: testCase,
        ruleBinding: ruleSet.binding,
        mode: mode,
        executedRulesDigest: executedDigest,
        assertions: [
          RuleTestAssertion(
            path: 'binding',
            expected: testCase.binding.toJson(),
            actual: ruleSet.binding.toJson(),
            passed: false,
          ),
        ],
        output: null,
        engineIdentity: engineIdentity,
        ruleExecution: execution(ran: false),
        inMemoryAuditRecordCount: 0,
      );
    }

    for (final rule in selected) {
      _validateInputUnits(rule['when'] as Map<String, dynamic>, testCase);
    }
    final database = InMemoryCdssDatabase();
    final service = ClinicalDecisionSupportService(
      database: database,
      artifactStore: InlineCdssArtifactStore(),
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final output = await service.run(
      context: testCase.context,
      rules: RuleRegistryCompiler().compileJsonList(
        selected,
        rulesVersion: ruleSet.bundleVersion,
      ),
      factsVersion: 'synthetic_empty_facts_v1',
      rulesVersion: ruleSet.bundleVersion,
    );
    final assertions = <RuleTestAssertion>[];
    final expectedTargets = testCase.expected.targets;
    if (expectedTargets != null) {
      final actualTargets = output.auditEntries.map((e) => e.target).toList()
        ..sort();
      final expectedNames = expectedTargets.map((e) => e.target).toList()
        ..sort();
      assertions.add(_compare('targets', expectedNames, actualTargets));
      for (final expected in expectedTargets) {
        final found = output.auditEntries
            .where((entry) => entry.target == expected.target)
            .toList();
        final actual = found.length == 1 ? found.single : null;
        assertions.add(
          _compare(
            'targets.${expected.target}.decision',
            expected.decision.wireValue,
            actual?.decision.wireValue,
          ),
        );
        assertions.add(
          _compare(
            'targets.${expected.target}.winning_rule_ids',
            [...expected.winningRuleIds]..sort(),
            actual == null ? null : ([...actual.winningRuleIds]..sort()),
          ),
        );
      }
    }
    final trace = (output.alertsJson['rule_hit_trace'] as List)
        .cast<Map<String, dynamic>>();
    for (final expected in testCase.expected.missingFieldsByRule.entries) {
      final found = trace
          .where((row) => row['rule_id'] == expected.key)
          .toList();
      // Absent (including excluded-by-mode) is not an evaluated empty set.
      final actual = found.length == 1
          ? (List<String>.from(found.single['missing_fields'] as List)..sort())
          : null;
      assertions.add(
        _compare(
          'missing_fields_by_rule.${expected.key}',
          [...expected.value]..sort(),
          actual,
        ),
      );
    }
    final status = assertions.isEmpty
        ? RuleTestRunStatus.notVerified
        : assertions.every((a) => a.passed)
        ? RuleTestRunStatus.passed
        : RuleTestRunStatus.failed;
    return RuleTestRunReport._(
      status: status,
      testCase: testCase,
      ruleBinding: ruleSet.binding,
      mode: mode,
      executedRulesDigest: executedDigest,
      assertions: assertions,
      output: output,
      engineIdentity: engineIdentity,
      ruleExecution: execution(ran: true),
      inMemoryAuditRecordCount: database.conflictAuditLog.length,
    );
  }
}

void _validateInputUnits(Map<String, dynamic> node, RuleTestCase testCase) {
  for (final operator in ['all', 'any']) {
    if (node.containsKey(operator)) {
      for (final child in node[operator] as List) {
        _validateInputUnits(child as Map<String, dynamic>, testCase);
      }
    }
  }
  if (node.containsKey('not')) {
    _validateInputUnits(node['not'] as Map<String, dynamic>, testCase);
  }
  final dose = node['dose_band'];
  if (dose is Map && dose['path'] == 'drug.administration_dose_value') {
    final unit = testCase.context.drug.administrationDoseUnit;
    if (unit != null && unit != 'mg') {
      throw const FormatException(
        'Unsupported dose semantics: an administration dose rule requires '
        'an explicitly supplied mg input or a missing unit; no conversion is applied.',
      );
    }
  }
}

bool _included(String status, RuleTestExecutionMode mode) => switch (mode) {
  RuleTestExecutionMode.activeOnly => status == 'active',
  RuleTestExecutionMode.includeDraft => status == 'active' || status == 'draft',
  RuleTestExecutionMode.allStatuses => true,
};

RuleTestAssertion _compare(String path, Object? expected, Object? actual) =>
    RuleTestAssertion(
      path: path,
      expected: expected,
      actual: actual,
      passed: jsonEncode(expected) == jsonEncode(actual),
    );

EngineRunOutput _freezeOutput(EngineRunOutput output) => EngineRunOutput(
  alertsJson: _freeze(output.alertsJson) as Map<String, dynamic>,
  humanReadableMarkdown: output.humanReadableMarkdown,
  auditLogJsonl: output.auditLogJsonl,
  ruleExplanationsJson: List.unmodifiable(
    output.ruleExplanationsJson.map(
      (row) => _freeze(row) as Map<String, dynamic>,
    ),
  ),
  alerts: List.unmodifiable(
    output.alerts.map(
      (a) => RuntimeAlert(
        target: a.target,
        decision: a.decision,
        severity: a.severity,
        explanation: a.explanation,
        actions: List.unmodifiable(
          a.actions.map((m) => _freeze(m) as Map<String, dynamic>),
        ),
        evidenceSources: List.unmodifiable(a.evidenceSources),
        evidenceDetails: List.unmodifiable(a.evidenceDetails),
        evidenceRecords: List.unmodifiable(a.evidenceRecords),
        ruleIds: List.unmodifiable(a.ruleIds),
      ),
    ),
  ),
  auditEntries: List.unmodifiable(
    output.auditEntries.map(
      (a) => RuntimeAuditEntry(
        target: a.target,
        decision: a.decision,
        winningRuleIds: List.unmodifiable(a.winningRuleIds),
        suppressedRuleIds: List.unmodifiable(a.suppressedRuleIds),
        sourceDocRefs: List.unmodifiable(a.sourceDocRefs),
        evidenceDetails: List.unmodifiable(a.evidenceDetails),
        evidenceRecords: List.unmodifiable(a.evidenceRecords),
        inputHash: a.inputHash,
        decisionReason: a.decisionReason,
        machineActions: List.unmodifiable(
          a.machineActions.map((m) => _freeze(m) as Map<String, dynamic>),
        ),
        humanMessage: a.humanMessage,
        needsHumanReview: a.needsHumanReview,
      ),
    ),
  ),
);

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final e in value.entries) e.key as String: _freeze(e.value),
    });
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}

Object? _copy(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final e in value.entries) e.key as String: _copy(e.value),
    };
  }
  if (value is List) return value.map(_copy).toList();
  return value;
}
