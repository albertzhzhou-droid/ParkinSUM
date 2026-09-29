/// Pure projection of one synthetic rule explanation to a CDS Hooks v2
/// information-only card. The caller must supply synthetic data only. The
/// input digest is stable and unsalted, so it is pseudonymous, not anonymous.
library;

import '../entities/rule_explanation.dart';

const String cdsHooksRuleTraceExtensionName = 'org.parkinsum.cdss-rule-trace';

const Set<String> _supportedTraceDecisions = <String>{
  'matched',
  'not_matched',
  'suppressed',
  'not_applicable_jurisdiction',
  'unknown',
  'missing_input',
  'unsupported_input',
  'invalid_context',
};

final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');

Map<String, dynamic> projectSyntheticRuleExplanationCard({
  required RuleExplanation explanation,
  required Map<String, dynamic> ruleTrace,
  required String rulePackVersion,
  String? rulePackDigest,
  required String inputDigest,
}) {
  final ruleId = _requiredText(explanation.ruleId, 'rule_id');
  if (ruleTrace['rule_id'] != ruleId) {
    throw const FormatException('Explanation and trace rule ids disagree.');
  }
  final ruleVersion = _requiredText(ruleTrace['rule_version'], 'rule_version');
  final traceDecision = _requiredText(
    ruleTrace['trace_decision'],
    'trace_decision',
  );
  if (!_supportedTraceDecisions.contains(traceDecision)) {
    throw FormatException('Unsupported rule trace state: $traceDecision');
  }
  final missingFields = _requiredTextList(
    ruleTrace['missing_fields'],
    'missing_fields',
  );
  if (traceDecision == 'missing_input' && missingFields.isEmpty) {
    throw const FormatException(
      'A missing_input trace requires at least one missing field.',
    );
  }
  if ((traceDecision == 'matched') != explanation.triggered) {
    throw const FormatException('Explanation and trace outcome disagree.');
  }

  final sourceRefs = _requiredTextList(ruleTrace['source_refs'], 'source_refs');
  if (!_sameList(sourceRefs, explanation.sourceRefs) ||
      !_sameList(missingFields, explanation.missingOrUncertainInputs)) {
    throw const FormatException(
      'Explanation provenance does not match the source rule trace.',
    );
  }

  final resolvedPackVersion = _requiredText(
    rulePackVersion,
    'rule_pack_version',
  );
  final resolvedInputDigest = _requiredDigest(inputDigest, 'input_digest');
  if (rulePackDigest != null) {
    _requiredDigest(rulePackDigest, 'rule_pack_digest');
  }
  final resultState = _resultState(traceDecision, missingFields);
  final detail = <String>[
    'Rule trace: $traceDecision',
    'Result interpretation: $resultState',
    explanation.limitationText,
    'Evidence provenance: ${explanation.provenanceSummary}',
    explanation.safetyBoundary,
    explanation.notAdviceText,
  ].join('\n\n');
  if (explanation.notAdviceText.trim().isEmpty ||
      explanation.provenanceSummary.trim().isEmpty ||
      explanation.safetyBoundary.trim().isEmpty ||
      explanation.limitationText.trim().isEmpty ||
      findBannedSubstrings(detail).isNotEmpty) {
    throw const FormatException('Rule explanation copy is not display-safe.');
  }

  return <String, dynamic>{
    'cards': <Map<String, dynamic>>[
      <String, dynamic>{
        'summary':
            'Synthetic educational rule trace; inputs may be incomplete.',
        'detail': detail,
        'indicator': 'info',
        'source': <String, dynamic>{
          'label': 'ParkinSUM synthetic rule explanation',
        },
        'extension': <String, dynamic>{
          cdsHooksRuleTraceExtensionName: <String, dynamic>{
            'schemaVersion': '1.0.0',
            'ruleId': ruleId,
            'ruleVersion': ruleVersion,
            'rulePackVersion': resolvedPackVersion,
            'rulePackDigest': ?rulePackDigest,
            'inputDigest': resolvedInputDigest,
            'traceDecision': traceDecision,
            'resultState': resultState,
            'inputCompleteness': missingFields.isEmpty
                ? 'complete'
                : 'incomplete',
            'inputFieldsUsed': _safeExplanationList(
              explanation.inputFieldsUsed,
              'input_fields_used',
            ),
            'sourceRefs': sourceRefs,
            'missingOrUncertainInputs': missingFields,
            'evidenceStrength': explanation.evidenceStrength.name,
            'outputType': explanation.outputType.name,
            'displayCopySource': ?(explanation.copySource.trim().isEmpty
                ? null
                : explanation.copySource),
          },
        },
      },
    ],
  };
}

String _resultState(String traceDecision, List<String> missingFields) {
  if (traceDecision == 'not_matched' && missingFields.isNotEmpty) {
    return 'unknown';
  }
  return traceDecision;
}

String _requiredDigest(Object? value, String field) {
  final text = _requiredText(value, field);
  if (!_sha256Pattern.hasMatch(text)) {
    throw FormatException('$field must be a lowercase SHA-256 digest.');
  }
  return text;
}

String _requiredText(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field is required.');
  }
  return value;
}

List<String> _requiredTextList(Object? value, String field) {
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('$field must be a list of strings.');
  }
  return value.cast<String>().toList(growable: false);
}

List<String> _safeExplanationList(List<String> value, String field) {
  if (value.any((item) => item.trim().isEmpty)) {
    throw FormatException('$field cannot contain empty entries.');
  }
  return List<String>.unmodifiable(value);
}

bool _sameList(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
