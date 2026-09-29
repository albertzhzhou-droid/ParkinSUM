import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
import 'package:parkinsum_companion/domain/usecases/decision_support_prompt_capture.dart';

void main() {
  const context = UnifiedRuntimeContext(
    userProfile: UserProfileRuntimeContext(
      patientId: 'owner',
      registrationRegion: 'CA',
      displayLocale: 'en',
      contentJurisdictionOverride: [],
      dietProfileRegion: null,
      timezone: 'UTC',
    ),
    drug: DrugRuntimeContext(
      id: 'drug',
      genericName: 'test',
      brandName: null,
      activeIngredients: [],
      substanceTags: [],
      formulation: 'unknown',
      dosageForm: 'unknown',
      route: 'unknown',
      releaseType: 'unknown',
      dailyDoseMg: null,
      jurisdiction: null,
    ),
    meal: null,
    coevent: null,
    enteralFeed: null,
    timestamps: TimestampRuntimeContext(
      drugTime: null,
      mealTime: null,
      coeventTime: null,
    ),
  );
  EngineRunOutput run({
    List<String> winning = const ['winner'],
    RuntimeDecisionType decision = RuntimeDecisionType.warn,
    String? version = 'actual-v2',
    bool includeTrace = true,
  }) => EngineRunOutput(
    alertsJson: {
      'snapshot': {'facts_version': 'facts-7', 'rules_version': 'requested-v1'},
      'rule_hit_trace': [
        if (includeTrace) {'rule_id': 'winner', 'rule_version': version},
      ],
    },
    humanReadableMarkdown: '',
    auditLogJsonl: '',
    alerts: [
      RuntimeAlert(
        target: 'test-target',
        decision: decision,
        severity: 'medium',
        explanation: 'Please review the missing information.',
        actions: [],
        evidenceSources: ['source-2'],
        evidenceDetails: [],
        evidenceRecords: [],
        ruleIds: ['winner', 'suppressed'],
      ),
    ],
    auditEntries: [
      RuntimeAuditEntry(
        target: 'test-target',
        decision: decision,
        winningRuleIds: winning,
        suppressedRuleIds: ['suppressed'],
        sourceDocRefs: ['source-2'],
        evidenceDetails: [],
        evidenceRecords: [],
        inputHash: 'test',
        decisionReason: 'test',
        machineActions: [],
        humanMessage: 'test',
        needsHumanReview: true,
      ),
    ],
    ruleExplanationsJson: [
      {
        'rule_id': 'winner',
        'missing_or_uncertain_inputs': ['dose'],
      },
    ],
  );
  capture(EngineRunOutput output, {DateTime? time, String meal = 'meal'}) =>
      captureDecisionSupportPrompts(
        output: output,
        context: context,
        sourceRecordId: meal,
        candidateId: 'drug',
        createdAt: time ?? DateTime.utc(2026, 9, 22),
      );

  test('captures winning actual version, provenance and missing inputs', () {
    final prompt = capture(run()).single;
    expect(prompt.ruleId, 'winner');
    expect(prompt.ruleVersion, 'actual-v2');
    expect(prompt.sourceRefs, ['source-2']);
    expect(prompt.missingInputs, ['dose']);
    expect(prompt.inputSnapshot['runtimeContext'], context.toJson());
  });
  test('allow and information outputs never become action prompts', () {
    expect(capture(run(decision: RuntimeDecisionType.allow)), isEmpty);
    expect(capture(run(decision: RuntimeDecisionType.info)), isEmpty);
  });
  test(
    'missing real rule version is not replaced with a requested or gate version',
    () {
      expect(capture(run(version: null)), isEmpty);
      expect(capture(run(includeTrace: false)), isEmpty);
    },
  );
  test(
    'a context gate without winning rules gets its explicit gate identity',
    () {
      final prompt = capture(run(winning: [], includeTrace: false)).single;
      expect(prompt.ruleId, 'runtime_context_gate');
      expect(prompt.ruleVersion, 'runtime_context_gate_v1');
    },
  );
  test(
    'same run is stable over time; new rule version and record are distinct',
    () {
      final first = capture(run()).single;
      expect(
        capture(run(), time: DateTime.utc(2026, 9, 23)).single.id,
        first.id,
      );
      expect(capture(run(version: 'actual-v3')).single.id, isNot(first.id));
      expect(capture(run(), meal: 'other-meal').single.id, isNot(first.id));
    },
  );
}
