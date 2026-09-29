import 'dart:convert';

import 'rule_test_case.dart';

const int ruleTestSuiteSchemaVersion = 1;
const int ruleTestSuiteMaxCases = 16;
const int ruleTestSuiteCheckpointSchemaVersion = 1;

/// A bounded collection of independent synthetic rule cases.
///
/// The suite never grants activation or persistence authority. Each case keeps
/// its own pinned rule binding and explicit expectations, so a mismatched case
/// remains a mismatch instead of being silently rebound to the selected pack.
final class RuleTestSuite {
  final String suiteId;
  final String title;
  final List<RuleTestCase> cases;

  RuleTestSuite._({
    required this.suiteId,
    required this.title,
    required List<RuleTestCase> cases,
  }) : cases = List.unmodifiable(cases);

  factory RuleTestSuite({
    required String suiteId,
    required String title,
    required List<RuleTestCase> cases,
  }) => RuleTestSuite.fromJson({
    'schema_version': ruleTestSuiteSchemaVersion,
    'synthetic_only': true,
    'suite_id': suiteId,
    'title': title,
    'cases': cases.map((testCase) => testCase.toJson()).toList(),
  });

  factory RuleTestSuite.decode(String source) {
    if (utf8.encode(source).length > ruleTestMaxJsonBytes) {
      throw const FormatException('Rule test suite exceeds the size limit.');
    }
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Rule test suite must be a JSON object.');
    }
    return RuleTestSuite.fromJson(value);
  }

  factory RuleTestSuite.fromJson(Map<String, dynamic> json) {
    const expectedKeys = {
      'schema_version',
      'synthetic_only',
      'suite_id',
      'title',
      'cases',
    };
    if (json.keys.toSet().difference(expectedKeys).isNotEmpty ||
        expectedKeys.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'Rule test suite has unknown or missing fields.',
      );
    }
    if (json['schema_version'] != ruleTestSuiteSchemaVersion ||
        json['synthetic_only'] != true) {
      throw const FormatException(
        'Only schema version 1 and synthetic_only=true are supported.',
      );
    }

    final suiteId = _suiteText(json['suite_id'], 'suite_id');
    final title = _suiteText(json['title'], 'title');
    final rawCases = json['cases'];
    if (rawCases is! List ||
        rawCases.isEmpty ||
        rawCases.length > ruleTestSuiteMaxCases) {
      throw FormatException(
        'A suite must contain 1 to $ruleTestSuiteMaxCases cases.',
      );
    }

    final cases = <RuleTestCase>[];
    final caseIds = <String>{};
    for (final value in rawCases) {
      if (value is! Map) {
        throw const FormatException('Every suite case must be a JSON object.');
      }
      final testCase = RuleTestCase.fromJson(Map<String, dynamic>.from(value));
      if (!caseIds.add(testCase.caseId)) {
        throw FormatException('Duplicate suite case ID: ${testCase.caseId}.');
      }
      cases.add(testCase);
    }

    final suite = RuleTestSuite._(suiteId: suiteId, title: title, cases: cases);
    if (utf8.encode(jsonEncode(suite.toJson())).length > ruleTestMaxJsonBytes) {
      throw const FormatException('Rule test suite exceeds the size limit.');
    }
    return suite;
  }

  Map<String, dynamic> toJson() => {
    'schema_version': ruleTestSuiteSchemaVersion,
    'synthetic_only': true,
    'suite_id': suiteId,
    'title': title,
    'cases': cases.map((testCase) => testCase.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());

  String get contentDigest =>
      ruleTestJsonDigest('synthetic-rule-suite-v1', toJson());
}

/// Portable progress metadata for the disposable synthetic rule workbench.
///
/// It binds progress to the exact suite, selected rule pack, and execution
/// mode. Completed cases are re-executed and their report digests are checked
/// before a resumed run advances, so this checkpoint is never treated as a
/// stored test result or an approval record.
final class RuleTestSuiteCheckpoint {
  final String suiteId;
  final String suiteDigest;
  final RuleTestRuleBinding selectedRuleBinding;
  final String executionMode;
  final List<RuleTestSuiteCheckpointCase> completedCases;

  RuleTestSuiteCheckpoint._({
    required this.suiteId,
    required this.suiteDigest,
    required this.selectedRuleBinding,
    required this.executionMode,
    required List<RuleTestSuiteCheckpointCase> completedCases,
  }) : completedCases = List.unmodifiable(completedCases);

  factory RuleTestSuiteCheckpoint({
    required String suiteId,
    required String suiteDigest,
    required RuleTestRuleBinding selectedRuleBinding,
    required String executionMode,
    required List<RuleTestSuiteCheckpointCase> completedCases,
  }) => RuleTestSuiteCheckpoint.fromJson({
    'schema_version': ruleTestSuiteCheckpointSchemaVersion,
    'synthetic_only': true,
    'suite_id': suiteId,
    'suite_digest': suiteDigest,
    'selected_rule_binding': selectedRuleBinding.toJson(),
    'execution_mode': executionMode,
    'completed_cases': completedCases.map((item) => item.toJson()).toList(),
  });

  factory RuleTestSuiteCheckpoint.decode(String source) {
    if (utf8.encode(source).length > ruleTestMaxJsonBytes) {
      throw const FormatException('Suite checkpoint exceeds the size limit.');
    }
    final value = jsonDecode(source);
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Suite checkpoint must be a JSON object.');
    }
    return RuleTestSuiteCheckpoint.fromJson(value);
  }

  factory RuleTestSuiteCheckpoint.fromJson(Map<String, dynamic> json) {
    const expectedKeys = {
      'schema_version',
      'synthetic_only',
      'suite_id',
      'suite_digest',
      'selected_rule_binding',
      'execution_mode',
      'completed_cases',
    };
    if (json.keys.toSet().difference(expectedKeys).isNotEmpty ||
        expectedKeys.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'Suite checkpoint has unknown or missing fields.',
      );
    }
    if (json['schema_version'] != ruleTestSuiteCheckpointSchemaVersion ||
        json['synthetic_only'] != true) {
      throw const FormatException(
        'Only schema version 1 and synthetic_only=true are supported.',
      );
    }

    final rawBinding = json['selected_rule_binding'];
    if (rawBinding is! Map) {
      throw const FormatException('selected_rule_binding must be an object.');
    }
    final rawCompleted = json['completed_cases'];
    if (rawCompleted is! List || rawCompleted.length > ruleTestSuiteMaxCases) {
      throw FormatException(
        'completed_cases must contain at most $ruleTestSuiteMaxCases entries.',
      );
    }
    final completedCases = <RuleTestSuiteCheckpointCase>[];
    final seenIds = <String>{};
    for (final value in rawCompleted) {
      if (value is! Map) {
        throw const FormatException('Every completed case must be an object.');
      }
      final item = RuleTestSuiteCheckpointCase.fromJson(
        Map<String, dynamic>.from(value),
      );
      if (!seenIds.add(item.caseId)) {
        throw FormatException('Duplicate completed case ID: ${item.caseId}.');
      }
      completedCases.add(item);
    }

    final suiteDigest = json['suite_digest'];
    if (suiteDigest is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(suiteDigest)) {
      throw const FormatException('suite_digest must be a SHA-256 digest.');
    }
    const supportedModes = {'activeOnly', 'includeDraft', 'allStatuses'};
    final executionMode = json['execution_mode'];
    if (executionMode is! String || !supportedModes.contains(executionMode)) {
      throw const FormatException('Unsupported suite execution mode.');
    }
    final checkpoint = RuleTestSuiteCheckpoint._(
      suiteId: _suiteText(json['suite_id'], 'suite_id'),
      suiteDigest: suiteDigest,
      selectedRuleBinding: RuleTestRuleBinding.fromJson(
        Map<String, dynamic>.from(rawBinding),
      ),
      executionMode: executionMode,
      completedCases: completedCases,
    );
    if (utf8.encode(jsonEncode(checkpoint.toJson())).length >
        ruleTestMaxJsonBytes) {
      throw const FormatException('Suite checkpoint exceeds the size limit.');
    }
    return checkpoint;
  }

  Map<String, dynamic> toJson() => {
    'schema_version': ruleTestSuiteCheckpointSchemaVersion,
    'synthetic_only': true,
    'suite_id': suiteId,
    'suite_digest': suiteDigest,
    'selected_rule_binding': selectedRuleBinding.toJson(),
    'execution_mode': executionMode,
    'completed_cases': completedCases.map((item) => item.toJson()).toList(),
  };

  String encode() => jsonEncode(toJson());
}

final class RuleTestSuiteCheckpointCase {
  final String caseId;
  final String reportDigest;

  RuleTestSuiteCheckpointCase({
    required this.caseId,
    required this.reportDigest,
  }) {
    if (caseId.trim().isEmpty || caseId.length > 160) {
      throw const FormatException(
        'case_id must be non-empty text of at most 160 characters.',
      );
    }
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(reportDigest)) {
      throw const FormatException('report_digest must be a SHA-256 digest.');
    }
  }

  factory RuleTestSuiteCheckpointCase.fromJson(Map<String, dynamic> json) {
    const expectedKeys = {'case_id', 'report_digest'};
    if (json.keys.toSet().difference(expectedKeys).isNotEmpty ||
        expectedKeys.difference(json.keys.toSet()).isNotEmpty) {
      throw const FormatException(
        'Completed-case checkpoint has unknown or missing fields.',
      );
    }
    final caseId = json['case_id'];
    final reportDigest = json['report_digest'];
    if (caseId is! String || reportDigest is! String) {
      throw const FormatException(
        'Completed-case checkpoint fields must be strings.',
      );
    }
    return RuleTestSuiteCheckpointCase(
      caseId: caseId,
      reportDigest: reportDigest,
    );
  }

  Map<String, dynamic> toJson() => {
    'case_id': caseId,
    'report_digest': reportDigest,
  };
}

String _suiteText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty || value.length > 160) {
    throw FormatException(
      '$field must be non-empty text of at most 160 characters.',
    );
  }
  return value;
}
