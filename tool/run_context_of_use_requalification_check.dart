import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/algorithm_sdk/algorithm_configuration_identity.dart';
import 'package:parkinsum_companion/domain/entities/context_of_use_requalification.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_medication_applicability.dart';

void main() {
  final identity = AlgorithmConfigurationIdentity.defaults();
  final evidenceAsOfUtc = _resolveEvidenceAsOfUtc();
  final ledger = ContextOfUseRequalificationLedger.current(
    manifest: MechanisticApplicabilityManifest.current,
    configurationSha256: identity.sha256Digest,
    evidenceAsOfUtc: evidenceAsOfUtc,
  );
  final integrityReasons = ledger.integrityReasons;
  final pass =
      ledger.integrityVerified &&
      !ledger.canPromoteResearchTraceOnly &&
      ledger.incompleteRequiredEvidence.isNotEmpty &&
      ledger.latest.releaseDisposition ==
          CouReleaseDisposition.blockedPendingEvidence;

  final report = <String, Object?>{
    'report_type': 'parkinsum_context_of_use_requalification',
    'pass': pass,
    'ledger': ledger.toJson(),
    'not_clinically_validated': true,
    'not_regulatory_review': true,
    'not_external_approval': true,
    'safety_boundary':
        'This report verifies an explicit fail-closed change-control record. '
        'It does not validate the model or authorize medication, diet, or '
        'timing decisions.',
  };
  final markdown = <String>[
    '# Context-of-use requalification check',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Release disposition:** ${ledger.latest.releaseDisposition.name}',
    '**Research trace promotion:** '
        '${ledger.canPromoteResearchTraceOnly ? 'approved' : 'blocked'}',
    '**Manifest:** `${ledger.manifest.sha256Digest}`',
    '**Configuration:** `${identity.sha256Digest}`',
    '**Evidence status as of:** `${evidenceAsOfUtc.toIso8601String()}`',
    '**Semantic diff:** `${ledger.currentImpact.semanticDiffSha256}`',
    '**Record:** `${ledger.latest.recordSha256}`',
    '',
    '## Evidence status',
    '',
    '| Lane | Status | Boundary |',
    '| --- | --- | --- |',
    for (final decision in ledger.latest.evidenceDecisions)
      '| ${decision.kind.name} | ${decision.status.name} | '
          '${decision.boundary.replaceAll('|', r'\|')} |',
    '',
    '## Incomplete required evidence',
    '',
    if (ledger.incompleteRequiredEvidence.isEmpty)
      '- none'
    else
      for (final kind in ledger.incompleteRequiredEvidence) '- ${kind.name}',
    '',
    '## Integrity findings',
    '',
    if (integrityReasons.isEmpty)
      '- none'
    else
      for (final reason in integrityReasons) '- $reason',
    '',
    '## Boundary',
    '',
    report['safety_boundary']! as String,
    '',
  ].join('\n');

  final output = Directory('build/context_of_use_requalification')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${output.path}/latest.md').writeAsStringSync(markdown);

  stdout.writeln(
    'Context-of-use requalification: '
    '${pass ? 'pass' : 'FAILED'}; disposition='
    '${ledger.latest.releaseDisposition.name}; incomplete='
    '${ledger.incompleteRequiredEvidence.length}; integrity='
    '${integrityReasons.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}

DateTime _resolveEvidenceAsOfUtc() {
  final raw = Platform.environment['PARKINSUM_EVIDENCE_AS_OF_UTC'];
  if (raw == null || raw.trim().isEmpty) return DateTime.now().toUtc();
  final parsed = DateTime.tryParse(raw);
  if (parsed == null || !parsed.isUtc) {
    stderr.writeln(
      'PARKINSUM_EVIDENCE_AS_OF_UTC must be an ISO-8601 UTC timestamp.',
    );
    exit(2);
  }
  return parsed;
}
