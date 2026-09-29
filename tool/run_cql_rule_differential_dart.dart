import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/rule_registry_models.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_support.dart';

Future<void> main(List<String> args) async {
  if (args.length != 1) {
    stderr.writeln(
      'Usage: dart run tool/run_cql_rule_differential_dart.dart <corpus.json>',
    );
    exitCode = 64;
    return;
  }
  final decoded = jsonDecode(await File(args.single).readAsString()) as Map;
  if (decoded['schemaVersion'] != 2 ||
      decoded['scope'] != 'synthetic-engineering-comparison') {
    throw const FormatException('Unsupported differential corpus contract.');
  }
  final cases = (decoded['cases'] as List).cast<Map<String, dynamic>>();
  final compiler = RuleRegistryCompiler();
  final engine = RuntimeRuleEngine();
  const support = RuntimeRuleSupport();
  const rulesVersion = 'cql_differential_1';
  final output = <Map<String, Object?>>[];

  for (final testCase in cases) {
    final input = Map<String, dynamic>.from(testCase['input'] as Map);
    final context = _context(input);
    final rule = compiler.compileJson(<String, dynamic>{
      'rule_id': 'cql-diff.${testCase['id']}',
      'version': '1.0.0',
      'status': 'active',
      'rule_type': 'soft_rule',
      'priority_band': 5,
      'specificity_band': 5,
      'jurisdiction': <String>['GLOBAL'],
      'applies_to': <String, Object?>{
        'subject_types': <String>['drug'],
      },
      'when': Map<String, dynamic>.from(testCase['when'] as Map),
      'then': <String, Object?>{
        'decision': 'INFO',
        'severity': 'low',
        'messages': <String, String>{'zh': 'synthetic comparison'},
        'actions': <Object?>[],
        'output_tags': <String>[],
      },
      'provenance': <String, Object?>{
        'evidence_level': 'review',
        'source_refs': <String>['fixture:cql-rule-differential'],
      },
    }, rulesVersion: rulesVersion);
    final candidates = engine.evaluateCandidates(
      context: context,
      rules: <RuleRegistryEntry>[rule],
    );
    final missing =
        support.missingFieldsForRule(context: context, rule: rule).toList()
          ..sort();
    output.add(<String, Object?>{
      'id': testCase['id'],
      'ruleVersion': rule.version,
      'rulePackVersion': rulesVersion,
      'runtimeMatched': candidates.any(
        (candidate) => candidate.rule.ruleId == rule.ruleId,
      ),
      'missingFields': missing,
      'reviewRecommended': missing.isNotEmpty,
    });
  }
  stdout.writeln(jsonEncode(output));
}

UnifiedRuntimeContext _context(Map<String, dynamic> input) {
  DateTime? instant(String field) {
    final value = input[field];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('$field must be an ISO timestamp or null.');
    }
    return DateTime.parse(value);
  }

  final dailyDose = input['dailyDoseMg'];
  if (dailyDose != null && dailyDose is! num) {
    throw const FormatException('dailyDoseMg must be numeric or null.');
  }
  return UnifiedRuntimeContext(
    userProfile: const UserProfileRuntimeContext(
      patientId: 'synthetic-cql-differential',
      registrationRegion: 'US',
      displayLocale: 'en-US',
      contentJurisdictionOverride: <String>[],
      dietProfileRegion: 'US',
      timezone: 'UTC',
    ),
    drug: DrugRuntimeContext(
      id: 'synthetic-dose',
      genericName: 'synthetic',
      brandName: null,
      activeIngredients: const <String>[],
      substanceTags: const <String>[],
      formulation: 'unknown',
      dosageForm: 'unknown',
      route: 'unknown',
      releaseType: 'unknown',
      administrationDoseValue: null,
      administrationDoseUnit: null,
      dailyDoseMg: (dailyDose as num?)?.toDouble(),
      jurisdiction: 'US',
    ),
    meal: null,
    coevent: null,
    enteralFeed: null,
    timestamps: TimestampRuntimeContext(
      drugTime: instant('drugTime'),
      mealTime: instant('mealTime'),
      coeventTime: null,
    ),
  );
}
