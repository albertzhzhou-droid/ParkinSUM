import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/evidence_currency.dart';
import 'package:parkinsum_companion/domain/entities/evidence_synthesis.dart';

void main() {
  final asOf = _resolveAsOfUtc();
  final currency = EvidenceCurrencyRegistry.current.assess(asOfUtc: asOf);
  final registry = EvidenceSynthesisRegistry.current;
  final assessment = registry.assess(
    asOfUtc: asOf,
    currencyAssessment: currency,
  );
  final allowed = assessment.adjudications.where(
    (entry) =>
        entry.disposition ==
        EvidenceSynthesisDisposition.allowResearchTraceOnly,
  );
  final pass =
      assessment.integrityReasons.isEmpty &&
      assessment.blockedBodies.isEmpty &&
      assessment.heldBodies.length == registry.bodies.length &&
      allowed.isEmpty;
  final report = <String, Object?>{
    'report_type': 'parkinsum_claim_evidence_synthesis',
    'pass': pass,
    'registry_schema': EvidenceSynthesisRegistry.schema,
    'registry_version': EvidenceSynthesisRegistry.registryVersion,
    'assessment': assessment.toJson(),
    'not_automatic_grade': true,
    'not_scientific_validation': true,
    'not_clinical_validation': true,
    'not_regulatory_review': true,
    'boundary':
        'This gate verifies a deterministic, source-bound contradiction and '
        'review matrix. The current bodies are intentionally held pending '
        'independent review. Passing the gate does not establish a favorable '
        'effect, causal certainty, clinical validity, or regulatory acceptance.',
  };
  final markdown = <String>[
    '# Claim evidence contradiction and synthesis check',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Registry:** `${assessment.registrySha256}`',
    '**Snapshot:** `${assessment.snapshotSha256}`',
    '**As of:** `${assessment.asOfUtc.toIso8601String()}`',
    '**Held:** `${assessment.heldBodies.length}`',
    '**Blocked:** `${assessment.blockedBodies.length}`',
    '**Allowed for research trace:** `${allowed.length}`',
    '',
    '| Claim | Disposition | Independent families | Directions |',
    '| --- | --- | ---: | --- |',
    for (final entry in assessment.adjudications)
      '| `${entry.body.claimId}` | ${entry.disposition.name} | '
          '${entry.independentFamilyCount} | '
          '${entry.directionCounts.entries.where((item) => item.value > 0).map((item) => '${item.key.name}:${item.value}').join(', ')} |',
    '',
    '## Integrity findings',
    '',
    if (assessment.integrityReasons.isEmpty)
      '- none'
    else
      for (final reason in assessment.integrityReasons) '- $reason',
    '',
    '## Boundary',
    '',
    report['boundary']! as String,
    '',
  ].join('\n');

  final output = Directory('build/evidence_synthesis')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${output.path}/latest.md').writeAsStringSync(markdown);

  stdout.writeln(
    'Evidence synthesis: ${pass ? 'pass' : 'FAILED'}; '
    'registry=${assessment.registrySha256}; '
    'held=${assessment.heldBodies.length}; '
    'blocked=${assessment.blockedBodies.length}; '
    'integrity=${assessment.integrityReasons.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}

DateTime _resolveAsOfUtc() {
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
