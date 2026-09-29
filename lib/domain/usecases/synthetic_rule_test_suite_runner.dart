import 'dart:async';

import '../entities/rule_test_case.dart';
import '../entities/rule_test_suite.dart';
import 'synthetic_rule_test_runner.dart';

const int ruleTestSuiteReportSchemaVersion = 1;

typedef SyntheticRuleCaseRunner =
    FutureOr<RuleTestRunReport> Function({
      required RuleTestCase testCase,
      required RuleTestRuleSet ruleSet,
      required RuleTestExecutionMode mode,
    });

typedef RuleTestSuiteProgressCallback =
    void Function({
      required int completed,
      required int total,
      required RuleTestRunReport latest,
    });

typedef RuleTestSuiteCheckpointProgressCallback =
    void Function({
      required int completed,
      required int total,
      required RuleTestRunReport latest,
      required RuleTestSuiteCheckpoint checkpoint,
      required bool replayingCheckpoint,
    });

final class RuleTestSuiteExecution {
  final RuleTestSuiteCheckpoint checkpoint;
  final RuleTestSuiteRunReport? report;
  final bool paused;

  const RuleTestSuiteExecution._({
    required this.checkpoint,
    required this.report,
    required this.paused,
  });

  bool get isComplete => report != null && !paused;
}

/// Results from running every suite case independently on one selected pack.
///
/// Cases remain bound to their own rule content. This runner never rebinds,
/// activates, persists, or promotes a pack, and it aggregates rather than
/// treating unverified or mismatched cases as passes.
final class RuleTestSuiteRunReport {
  final RuleTestSuite suite;
  final RuleTestRuleBinding selectedRuleBinding;
  final RuleTestExecutionMode mode;
  final List<RuleTestRunReport> caseReports;

  RuleTestSuiteRunReport({
    required this.suite,
    required this.selectedRuleBinding,
    required this.mode,
    required List<RuleTestRunReport> caseReports,
  }) : caseReports = List.unmodifiable(caseReports) {
    if (caseReports.length != suite.cases.length) {
      throw ArgumentError('A completed suite report must contain every case.');
    }
    for (var i = 0; i < caseReports.length; i++) {
      if (caseReports[i].testCase.caseId != suite.cases[i].caseId) {
        throw ArgumentError('Suite result order must match suite case order.');
      }
    }
  }

  int get passedCount => caseReports
      .where((report) => report.status == RuleTestRunStatus.passed)
      .length;

  int get failedCount => caseReports
      .where((report) => report.status == RuleTestRunStatus.failed)
      .length;

  int get notVerifiedCount => caseReports
      .where((report) => report.status == RuleTestRunStatus.notVerified)
      .length;

  int get bindingMismatchCount => caseReports
      .where((report) => report.status == RuleTestRunStatus.bindingMismatch)
      .length;

  bool get allCasesPassed => passedCount == caseReports.length;

  Map<String, dynamic> toJson() => {
    'schema_version': ruleTestSuiteReportSchemaVersion,
    'synthetic_only': true,
    'suite_id': suite.suiteId,
    'suite_digest': suite.contentDigest,
    'selected_rule_binding': selectedRuleBinding.toJson(),
    'execution_mode': mode.name,
    'summary': {
      'total': caseReports.length,
      'passed': passedCount,
      'failed': failedCount,
      'not_verified': notVerifiedCount,
      'binding_mismatch': bindingMismatchCount,
      'all_cases_passed': allCasesPassed,
    },
    'boundaries': {
      'case_results_are_independent': true,
      'suite_execution': 'sequential_in_process',
      'persistence': false,
      'patient_rule_activation_changed': false,
      'clinical_validation': false,
    },
    'cases': caseReports.map((report) => report.toJson()).toList(),
  };
}

final class SyntheticRuleTestSuiteRunner {
  final SyntheticRuleCaseRunner _runCase;

  SyntheticRuleTestSuiteRunner({SyntheticRuleCaseRunner? runCase})
    : _runCase = runCase ?? const SyntheticRuleTestRunner().run;

  Future<RuleTestSuiteRunReport> run({
    required RuleTestSuite suite,
    required RuleTestRuleSet ruleSet,
    RuleTestExecutionMode mode = RuleTestExecutionMode.activeOnly,
    RuleTestSuiteProgressCallback? onProgress,
  }) async => (await runResumable(
    suite: suite,
    ruleSet: ruleSet,
    mode: mode,
    onProgress: onProgress,
  )).report!;

  /// Runs or resumes a bounded suite with a portable, synthetic-only
  /// checkpoint. A resumed run replays the completed prefix and compares each
  /// report digest before it evaluates any remaining case.
  Future<RuleTestSuiteExecution> runResumable({
    required RuleTestSuite suite,
    required RuleTestRuleSet ruleSet,
    RuleTestExecutionMode mode = RuleTestExecutionMode.activeOnly,
    RuleTestSuiteCheckpoint? checkpoint,
    bool Function()? shouldPause,
    RuleTestSuiteProgressCallback? onProgress,
    RuleTestSuiteCheckpointProgressCallback? onCheckpointProgress,
  }) async {
    final activeCheckpoint =
        checkpoint ??
        RuleTestSuiteCheckpoint(
          suiteId: suite.suiteId,
          suiteDigest: suite.contentDigest,
          selectedRuleBinding: ruleSet.binding,
          executionMode: mode.name,
          completedCases: const [],
        );
    _validateCheckpoint(
      activeCheckpoint,
      suite: suite,
      ruleSet: ruleSet,
      mode: mode,
    );

    final reports = <RuleTestRunReport>[];
    final checkpointPrefixLength = activeCheckpoint.completedCases.length;

    void emitProgress({
      required RuleTestRunReport report,
      required RuleTestSuiteCheckpoint progressCheckpoint,
      required bool replayingCheckpoint,
    }) {
      onProgress?.call(
        completed: reports.length,
        total: suite.cases.length,
        latest: report,
      );
      onCheckpointProgress?.call(
        completed: reports.length,
        total: suite.cases.length,
        latest: report,
        checkpoint: progressCheckpoint,
        replayingCheckpoint: replayingCheckpoint,
      );
    }

    for (var i = 0; i < checkpointPrefixLength; i++) {
      final report = await _runCase(
        testCase: suite.cases[i],
        ruleSet: ruleSet,
        mode: mode,
      );
      final actualDigest = _caseReportDigest(report);
      if (actualDigest != activeCheckpoint.completedCases[i].reportDigest) {
        throw FormatException(
          'Checkpoint replay changed case ${suite.cases[i].caseId}.',
        );
      }
      reports.add(report);
      emitProgress(
        report: report,
        progressCheckpoint: activeCheckpoint,
        replayingCheckpoint: true,
      );
      if (shouldPause?.call() ?? false) {
        return RuleTestSuiteExecution._(
          checkpoint: activeCheckpoint,
          report: null,
          paused: true,
        );
      }
    }

    var progressCheckpoint = activeCheckpoint;
    for (var i = checkpointPrefixLength; i < suite.cases.length; i++) {
      final report = await _runCase(
        testCase: suite.cases[i],
        ruleSet: ruleSet,
        mode: mode,
      );
      reports.add(report);
      progressCheckpoint = _checkpointFor(
        suite: suite,
        ruleSet: ruleSet,
        mode: mode,
        reports: reports,
      );
      emitProgress(
        report: report,
        progressCheckpoint: progressCheckpoint,
        replayingCheckpoint: false,
      );
      if (shouldPause?.call() ?? false) {
        return RuleTestSuiteExecution._(
          checkpoint: progressCheckpoint,
          report: null,
          paused: true,
        );
      }
    }

    return RuleTestSuiteExecution._(
      checkpoint: progressCheckpoint,
      report: RuleTestSuiteRunReport(
        suite: suite,
        selectedRuleBinding: ruleSet.binding,
        mode: mode,
        caseReports: reports,
      ),
      paused: false,
    );
  }
}

void _validateCheckpoint(
  RuleTestSuiteCheckpoint checkpoint, {
  required RuleTestSuite suite,
  required RuleTestRuleSet ruleSet,
  required RuleTestExecutionMode mode,
}) {
  if (checkpoint.suiteId != suite.suiteId ||
      checkpoint.suiteDigest != suite.contentDigest) {
    throw const FormatException(
      'Checkpoint does not match the selected suite content.',
    );
  }
  if (!checkpoint.selectedRuleBinding.matches(ruleSet.binding)) {
    throw const FormatException(
      'Checkpoint does not match the selected rule-pack binding.',
    );
  }
  if (checkpoint.executionMode != mode.name) {
    throw const FormatException(
      'Checkpoint does not match the selected execution mode.',
    );
  }
  if (checkpoint.completedCases.length > suite.cases.length) {
    throw const FormatException(
      'Checkpoint has more completed cases than the selected suite.',
    );
  }
  for (var i = 0; i < checkpoint.completedCases.length; i++) {
    if (checkpoint.completedCases[i].caseId != suite.cases[i].caseId) {
      throw const FormatException(
        'Checkpoint completed cases must be an ordered suite prefix.',
      );
    }
  }
}

RuleTestSuiteCheckpoint _checkpointFor({
  required RuleTestSuite suite,
  required RuleTestRuleSet ruleSet,
  required RuleTestExecutionMode mode,
  required List<RuleTestRunReport> reports,
}) => RuleTestSuiteCheckpoint(
  suiteId: suite.suiteId,
  suiteDigest: suite.contentDigest,
  selectedRuleBinding: ruleSet.binding,
  executionMode: mode.name,
  completedCases: [
    for (final report in reports)
      RuleTestSuiteCheckpointCase(
        caseId: report.testCase.caseId,
        reportDigest: _caseReportDigest(report),
      ),
  ],
);

String _caseReportDigest(RuleTestRunReport report) =>
    ruleTestJsonDigest('synthetic-rule-suite-case-report-v1', report.toJson());
