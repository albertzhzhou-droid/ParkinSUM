/// Bridges the two explanation schemas this project carries.
///
/// [RuleExplanation] is the documented, safety-linted audit contract, but
/// until now nothing in `lib/` ever constructed one — the schema that the
/// engine actually emits is [RuntimeAuditEntry] plus the untyped
/// `rule_hit_trace` rows produced by `ClinicalDecisionSupportService`. That
/// left the readable contract unproduced and the produced record unread.
///
/// This projection closes the gap. It is a **pure, read-only derivation** over
/// values the engine has already computed: it re-evaluates nothing, changes no
/// score, severity, decision, or rule outcome, and reaches no I/O or clock.
/// Feeding it the same run twice yields byte-identical output, so it is safe
/// to golden.
///
/// One explanation is emitted **per rule in the registry**, not per fired rule.
/// A rule that did not fire is exactly the case an auditor most needs to see,
/// so `not_matched`, `suppressed`, and `not_applicable_jurisdiction` all
/// produce a row carrying `triggered: false` and the reason.
///
/// Educational prototype only; synthetic/demo data only. The copy assembled
/// here is descriptive audit metadata, never guidance.
library;

import '../entities/cdss_runtime.dart';
import '../entities/medication_entry_validation.dart';
import '../entities/rule_explanation.dart';

/// Machine-readable, locale-independent decision labels used in the audit
/// trail. These are deliberately *not* localized: an audit record should read
/// the same for every reviewer regardless of the UI locale that produced it.
///
/// They describe rule-engine bookkeeping, never a health outcome.
const Map<String, String> kRuleTraceDecisionLabels = <String, String>{
  'matched': 'educational caution shown',
  'not_matched': 'no modeled interaction',
  'suppressed': 'superseded by a more specific rule',
  'not_applicable_jurisdiction': 'rule not in scope for this jurisdiction',
  'unknown': 'rule outcome unknown; no conclusion drawn',
  'missing_input': 'required input missing; no conclusion drawn',
  'unsupported_input': 'input not supported; no conclusion drawn',
  'invalid_context': 'invalid context; no rule outcome asserted',
};

const Set<String> _nonConclusiveTraceStates = <String>{
  'unknown',
  'missing_input',
  'unsupported_input',
  'invalid_context',
};

/// Projects the engine's audit output into the documented [RuleExplanation]
/// audit contract.
///
/// [ruleHitTrace] rows come from `ClinicalDecisionSupportService._ruleHitTrace`
/// and drive the row set. [auditEntries] supply the per-target decision that a
/// winning rule produced; rows with no matching entry still get an explanation.
///
/// Output order follows [ruleHitTrace], which follows registry order — stable
/// across runs.
List<RuleExplanation> projectRuleExplanations({
  required List<RuntimeAuditEntry> auditEntries,
  required List<Map<String, dynamic>> ruleHitTrace,
}) {
  final entryByRuleId = <String, RuntimeAuditEntry>{};
  for (final entry in auditEntries) {
    for (final ruleId in entry.winningRuleIds) {
      entryByRuleId.putIfAbsent(ruleId, () => entry);
    }
  }
  return ruleHitTrace
      .map((row) => _projectRow(row, entryByRuleId[_string(row['rule_id'])]))
      .toList(growable: false);
}

RuleExplanation _projectRow(
  Map<String, dynamic> row,
  RuntimeAuditEntry? entry,
) {
  final traceDecision = _string(row['trace_decision']);
  final triggered = traceDecision == 'matched';
  final missingFields = _stringList(row['missing_fields']);
  final referencedPaths = _stringList(row['referenced_paths']);
  final sourceRefs = _stringList(row['source_refs']);
  final evidenceLevel = _string(row['evidence_level']);
  final jurisdictionMatched = row['jurisdiction_matched'] == true;
  if (!kRuleTraceDecisionLabels.containsKey(traceDecision)) {
    throw ArgumentError.value(
      traceDecision,
      'traceDecision',
      'is not in the rule-trace vocabulary',
    );
  }
  if (traceDecision == 'missing_input' && missingFields.isEmpty) {
    throw ArgumentError.value(
      traceDecision,
      'traceDecision',
      'missing_input requires at least one missing field',
    );
  }
  final resultState = _resultState(traceDecision, missingFields);

  return RuleExplanation(
    ruleId: _string(row['rule_id']),
    // Only a rule that fired has conditions that actually matched. For every
    // other outcome this stays empty, which is what makes `triggered` honest.
    triggeredConditions: triggered ? referencedPaths : const <String>[],
    inputFieldsUsed: referencedPaths,
    sourceRefs: sourceRefs,
    provenanceSummary: _provenanceSummary(
      evidenceLevel: evidenceLevel,
      sourceStatus: _string(row['source_status']),
      sourceRefCount: sourceRefs.length,
    ),
    evidenceStrength: ruleEvidenceStrengthFor(
      evidenceLevel: evidenceLevel,
      sourceRefs: sourceRefs,
    ),
    limitationText: _limitationText(
      traceDecision: traceDecision,
      resultState: resultState,
      missingFields: missingFields,
    ),
    missingOrUncertainInputs: missingFields,
    safetyBoundary: RuleExplanation.defaultSafetyBoundary,
    notAdviceText: RuleExplanation.defaultNotAdvice,
    outputType: triggered
        ? MedicationExplanationOutputType.educationalCaution
        : MedicationExplanationOutputType.educationalInfo,
    triggered: triggered,
    userFacingDecision: kRuleTraceDecisionLabels[resultState]!,
    confidenceNote: _confidenceNote(
      evidenceLevel: evidenceLevel,
      missingFields: missingFields,
      jurisdictionMatched: jurisdictionMatched,
      needsHumanReview: entry?.needsHumanReview ?? false,
      resultState: resultState,
    ),
    // Ties the displayed wording back to its origin. The rule engine is the
    // authority; a Local-AI polish pass would record itself here instead.
    copySource: triggered && entry != null
        ? 'rule_engine:${entry.decision.wireValue}'
        : 'rule_engine:not_shown',
  );
}

/// A trace that did not match while required values were unavailable is
/// incomplete, not a defensible negative result. Keep the raw trace decision
/// in the source trace and use this conservative interpretation for display.
String _resultState(String traceDecision, List<String> missingFields) {
  if (traceDecision == 'not_matched' && missingFields.isNotEmpty) {
    return 'unknown';
  }
  return traceDecision;
}

/// Maps the rule registry's `evidence_level` vocabulary onto the documented
/// [RuleEvidenceStrength] labels.
///
/// A rule carrying no resolvable source reference is [RuleEvidenceStrength
/// .insufficient] regardless of its declared level — an unsourced claim cannot
/// outrank a sourced one just because its metadata says so.
RuleEvidenceStrength ruleEvidenceStrengthFor({
  required String evidenceLevel,
  required List<String> sourceRefs,
}) {
  if (sourceRefs.isEmpty) return RuleEvidenceStrength.insufficient;
  switch (evidenceLevel) {
    case 'official_label':
    case 'official_database':
      return RuleEvidenceStrength.label;
    case 'primary_study':
    case 'review':
      return RuleEvidenceStrength.mechanism;
    case 'case_report':
      return RuleEvidenceStrength.analogy;
    default:
      return RuleEvidenceStrength.insufficient;
  }
}

String _provenanceSummary({
  required String evidenceLevel,
  required String sourceStatus,
  required int sourceRefCount,
}) {
  if (sourceRefCount == 0) {
    return 'No source reference is attached to this rule, so it carries no '
        'documented authority.';
  }
  final level = evidenceLevel.isEmpty ? 'unspecified' : evidenceLevel;
  final status = sourceStatus.isEmpty ? 'unspecified' : sourceStatus;
  return 'Declared evidence level "$level" ($status) with $sourceRefCount '
      'source reference(s). Not calibrated for real care.';
}

String _limitationText({
  required String traceDecision,
  required String resultState,
  required List<String> missingFields,
}) {
  final buffer = StringBuffer();
  switch (resultState) {
    case 'matched':
      buffer.write(
        'This is an educational prototype output from a deterministic rule. ',
      );
    case 'not_matched':
      buffer.write('This rule did not match the synthetic demo inputs. ');
    case 'suppressed':
      buffer.write(
        'A more specific rule covered the same target, so this rule did not '
        'produce the shown wording. ',
      );
    case 'not_applicable_jurisdiction':
      buffer.write(
        'This rule is scoped to jurisdictions outside the current chain and '
        'was not evaluated for an outcome. ',
      );
    case 'unknown':
      buffer.write(
        'The available trace does not establish whether this rule matched. '
        'Do not interpret this as a negative result. ',
      );
    case 'missing_input':
      buffer.write(
        'A required input was missing, so this rule has no conclusive result. ',
      );
    case 'unsupported_input':
      buffer.write(
        'An input is outside this rule engine\'s supported scope, so no '
        'conclusion is asserted. ',
      );
    case 'invalid_context':
      buffer.write(
        'The input context was invalid, so no rule outcome was evaluated. ',
      );
    default:
      throw ArgumentError.value(
        traceDecision,
        'traceDecision',
        'is not in the rule-trace vocabulary',
      );
  }
  if (missingFields.isNotEmpty) {
    buffer.write(
      'Some inputs were unavailable (${missingFields.join(", ")}), so the '
      'result is incomplete. ',
    );
  }
  buffer.write('Review with a qualified clinician before making decisions.');
  return buffer.toString();
}

String _confidenceNote({
  required String evidenceLevel,
  required List<String> missingFields,
  required bool jurisdictionMatched,
  required bool needsHumanReview,
  required String resultState,
}) {
  final qualifiers = <String>[
    if (evidenceLevel.isNotEmpty) 'evidence=$evidenceLevel',
    if (!jurisdictionMatched) 'jurisdiction=out_of_scope',
    if (missingFields.isNotEmpty) 'missing_inputs=${missingFields.length}',
    if (_nonConclusiveTraceStates.contains(resultState))
      'result_state=$resultState',
    if (needsHumanReview) 'flagged_for_human_review',
  ];
  final band =
      missingFields.isNotEmpty ||
          !jurisdictionMatched ||
          _nonConclusiveTraceStates.contains(resultState)
      ? 'low'
      : (evidenceLevel == 'official_label' ? 'moderate' : 'low');
  final detail = qualifiers.isEmpty ? 'no qualifiers' : qualifiers.join('; ');
  return '$band — educational only ($detail)';
}

String _string(Object? value) => value is String ? value : '';

List<String> _stringList(Object? value) {
  if (value is! List) return const <String>[];
  return value
      .map((item) => item?.toString() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
