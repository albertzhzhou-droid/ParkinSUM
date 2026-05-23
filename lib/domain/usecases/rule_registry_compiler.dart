import 'dart:convert';

import 'package:yaml/yaml.dart';

import '../../core/constants/cdss_rule_schema.dart';
import '../entities/cdss_runtime.dart';
import '../entities/rule_registry_models.dart';

class RuleValidationException implements Exception {
  final String message;

  RuleValidationException(this.message);

  @override
  String toString() => 'RuleValidationException: $message';
}

class RuleRegistryCompiler {
  List<RuleRegistryEntry> compileJsonList(
    List<Map<String, dynamic>> input, {
    required String rulesVersion,
  }) {
    return input
        .map((json) => compileJson(json, rulesVersion: rulesVersion))
        .toList(growable: false);
  }

  RuleRegistryEntry compileYaml(
    String yamlText, {
    required String rulesVersion,
  }) {
    final yaml = loadYaml(yamlText);
    final mapped = jsonDecode(jsonEncode(yaml)) as Map<String, dynamic>;
    return compileJson(mapped, rulesVersion: rulesVersion);
  }

  RuleRegistryEntry compileJson(
    Map<String, dynamic> json, {
    required String rulesVersion,
  }) {
    _validateAgainstJsonSchema(json, pdrJsonSchema);

    final thenJson = Map<String, dynamic>.from(json['then'] as Map);
    final messagesJson = Map<String, dynamic>.from(thenJson['messages'] as Map);
    final provenanceJson = Map<String, dynamic>.from(json['provenance'] as Map);

    return RuleRegistryEntry(
      ruleId: json['rule_id'] as String,
      version: (json['version'] as String?) ?? rulesVersion,
      status: json['status'] as String,
      ruleType: _parseRuleType(json['rule_type'] as String),
      priorityBand: (json['priority_band'] as num).toInt(),
      specificityBand: (json['specificity_band'] as num?)?.toInt() ?? 50,
      jurisdictions: (json['jurisdiction'] as List<dynamic>)
          .map((value) => value.toString())
          .toList(growable: false),
      appliesTo: Map<String, dynamic>.from(
        json['applies_to'] as Map? ?? const <String, dynamic>{},
      ),
      conditions: Map<String, dynamic>.from(json['when'] as Map),
      thenClause: RuleThenClause(
        decision: _parseDecision(thenJson['decision'] as String),
        severity: thenJson['severity'] as String,
        messages: RuleMessageSet(
          zh: messagesJson['zh'] as String,
          en: messagesJson['en'] as String?,
          // Optional `localized` map: any locale tag (`ko-KR`, `es-MX`, ...)
          // → text. New rules can ship full multi-locale strings; old rules
          // continue to work with only zh/en.
          localized: _parseLocalizedMessages(messagesJson),
        ),
        actions: (thenJson['actions'] as List<dynamic>? ?? const [])
            .map((value) => Map<String, dynamic>.from(value as Map))
            .toList(growable: false),
        outputTags: (thenJson['output_tags'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
      ),
      provenance: RuleProvenance(
        evidenceLevel: provenanceJson['evidence_level'] as String,
        sourceRefs:
            (provenanceJson['source_refs'] as List<dynamic>? ?? const [])
                .map((value) => value.toString())
                .toList(growable: false),
        effectiveFrom: DateTime.tryParse(
            provenanceJson['effective_from']?.toString() ?? ''),
        effectiveTo:
            DateTime.tryParse(provenanceJson['effective_to']?.toString() ?? ''),
      ),
      override: json['override'] == null
          ? null
          : Map<String, dynamic>.from(json['override'] as Map),
    );
  }

  void _validateAgainstJsonSchema(
    Map<String, dynamic> input,
    Map<String, dynamic> schema,
  ) {
    final required = (schema['required'] as List<dynamic>).cast<String>();
    for (final field in required) {
      if (!input.containsKey(field)) {
        throw RuleValidationException('Missing required field: $field');
      }
    }

    final properties = Map<String, dynamic>.from(schema['properties'] as Map);
    for (final entry in properties.entries) {
      if (!input.containsKey(entry.key)) continue;
      final descriptor = Map<String, dynamic>.from(entry.value as Map);
      final value = input[entry.key];
      final type = descriptor['type'];
      if (type == 'string' && value is! String) {
        throw RuleValidationException('Field ${entry.key} must be a string');
      }
      if (type == 'integer' && value is! int && value is! num) {
        throw RuleValidationException('Field ${entry.key} must be an integer');
      }
      if (type == 'object' && value is! Map) {
        throw RuleValidationException('Field ${entry.key} must be an object');
      }
      if (type == 'array' && value is! List) {
        throw RuleValidationException('Field ${entry.key} must be an array');
      }
      if (descriptor.containsKey('enum') &&
          !(descriptor['enum'] as List<dynamic>).contains(value)) {
        throw RuleValidationException(
          'Field ${entry.key} has invalid enum value: $value',
        );
      }
    }

    final thenJson = Map<String, dynamic>.from(input['then'] as Map);
    if (!thenJson.containsKey('messages') ||
        thenJson['messages'] is! Map ||
        !(thenJson['messages'] as Map).containsKey('zh')) {
      throw RuleValidationException('Rule then.messages.zh is required.');
    }
  }

  RuleType _parseRuleType(String value) {
    switch (value) {
      case 'hard_constraint':
        return RuleType.hardConstraint;
      case 'soft_rule':
        return RuleType.softRule;
      case 'temporal_rule':
        return RuleType.temporalRule;
      case 'dose_dependent_rule':
        return RuleType.doseDependentRule;
      case 'jurisdiction_override':
        return RuleType.jurisdictionOverride;
      case 'source_resolution_rule':
        return RuleType.sourceResolutionRule;
      case 'escalation_rule':
        return RuleType.escalationRule;
      default:
        throw RuleValidationException('Unsupported rule_type: $value');
    }
  }

  RuntimeDecisionType _parseDecision(String value) {
    switch (value) {
      case 'BLOCK':
        return RuntimeDecisionType.block;
      case 'REQUIRE_REVIEW':
        return RuntimeDecisionType.requireReview;
      case 'DISCOURAGE':
        return RuntimeDecisionType.discourage;
      case 'WARN':
        return RuntimeDecisionType.warn;
      case 'INFO':
        return RuntimeDecisionType.info;
      case 'ALLOW':
        return RuntimeDecisionType.allow;
      case 'DEFER':
        return RuntimeDecisionType.defer;
      default:
        throw RuleValidationException('Unsupported decision: $value');
    }
  }

  /// Pull every locale-tagged string out of the rule's `messages` JSON,
  /// excluding the legacy `zh` / `en` fields (those are still required and
  /// captured separately on `RuleMessageSet`).
  ///
  /// Accepted shapes:
  /// - flat: `{"zh": "...", "en": "...", "ko-KR": "...", "es": "..."}`
  /// - nested: `{"zh": "...", "en": "...", "localized": {"ko-KR": "...", ...}}`
  Map<String, String> _parseLocalizedMessages(Map<String, dynamic> json) {
    final out = <String, String>{};
    final nested = json['localized'];
    if (nested is Map) {
      for (final entry in nested.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is String && value.trim().isNotEmpty) {
          out[key] = value;
        }
      }
    }
    for (final entry in json.entries) {
      final key = entry.key.toString();
      if (key == 'zh' || key == 'en' || key == 'localized') continue;
      final value = entry.value;
      if (value is String && value.trim().isNotEmpty) {
        out[key] = value;
      }
    }
    return out;
  }
}
