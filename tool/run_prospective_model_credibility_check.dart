import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';
import 'package:parkinsum_companion/domain/entities/prospective_model_credibility_plan.dart';

void main() {
  final configuration = AlgorithmConfigurationIdentity.defaults();
  final plan = ProspectiveModelCredibilityPlan.current(
    manifest: MechanisticApplicabilityManifest.current,
    configurationSha256: configuration.sha256Digest,
  );
  final pass =
      plan.integrityVerified &&
      !plan.canExecuteGovernedStudy &&
      !plan.canPromoteResearchTraceOnly &&
      plan.incompleteGoals.isNotEmpty &&
      plan.prospectiveDecision.disposition ==
          CredibilityAdequacyDisposition.blocked &&
      plan.postStudyDecision.disposition ==
          CredibilityAdequacyDisposition.notAssessed;
  final report = <String, Object?>{
    'report_type': 'parkinsum_prospective_model_credibility',
    'pass': pass,
    'plan': plan.toJson(),
    'not_scientific_validation': true,
    'not_model_qualification': true,
    'not_regulatory_review': true,
    'not_external_approval': true,
    'safety_boundary':
        'This gate verifies a fail-closed prospective governance contract. '
        'It does not validate the model or authorize medication, diet, timing, '
        'or other patient-specific decisions.',
  };
  final markdown = <String>[
    '# Prospective model credibility gate',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Plan integrity:** ${plan.integrityVerified ? 'verified' : 'FAILED'}',
    '**Prospective decision:** ${plan.prospectiveDecision.disposition.name}',
    '**Post-study decision:** ${plan.postStudyDecision.disposition.name}',
    '**Governed study execution:** ${plan.canExecuteGovernedStudy ? 'allowed' : 'blocked'}',
    '**Research-trace promotion:** ${plan.canPromoteResearchTraceOnly ? 'allowed' : 'blocked'}',
    '**Plan:** `${plan.planSha256}`',
    '**Manifest:** `${plan.manifestSha256}`',
    '**Configuration:** `${plan.configurationSha256}`',
    '',
    '## Credibility factors',
    '',
    '| Factor | Target | Status | Dataset / independence |',
    '| --- | --- | --- | --- |',
    for (final goal in plan.goals)
      '| ${goal.factor.name} | ${goal.targetGradation} | ${goal.status.name} | '
          '${goal.datasetManifestId} / ${goal.independenceGroupId} |',
    '',
    '## Integrity findings',
    '',
    if (plan.integrityReasons.isEmpty)
      '- none'
    else
      for (final reason in plan.integrityReasons) '- $reason',
    '',
    '## Boundary',
    '',
    report['safety_boundary']! as String,
    '',
  ].join('\n');

  final output = Directory('build/prospective_model_credibility')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${output.path}/latest.md').writeAsStringSync(markdown);

  stdout.writeln(
    'Prospective model credibility: ${pass ? 'pass' : 'FAILED'}; '
    'prospective=${plan.prospectiveDecision.disposition.name}; '
    'post-study=${plan.postStudyDecision.disposition.name}; '
    'incomplete=${plan.incompleteGoals.length}; '
    'integrity=${plan.integrityReasons.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}
