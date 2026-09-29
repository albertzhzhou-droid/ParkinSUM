import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/domain/entities/evidence_currency.dart';

void main() {
  final asOf = _resolveAsOfUtc();
  final registry = EvidenceCurrencyRegistry.current;
  final assessment = registry.assess(asOfUtc: asOf);
  final pass =
      assessment.integrityReasons.isEmpty &&
      !assessment.requiresRequalification;
  final report = <String, Object?>{
    'report_type': 'parkinsum_evidence_currency',
    'pass': pass,
    'registry': registry.toJson(asOfUtc: asOf),
    'not_scientific_validation': true,
    'not_clinical_validation': true,
    'not_regulatory_review': true,
    'boundary':
        'This gate records whether a governed evidence-status review is '
        'current. It does not establish validity, certainty, causality, '
        'clinical effectiveness, regulatory acceptance, or medical advice.',
  };
  final markdown = <String>[
    '# Evidence currency, correction, retraction and sunset check',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Registry:** `${assessment.registrySha256}`',
    '**Snapshot:** `${assessment.snapshotSha256}`',
    '**As of:** `${assessment.asOfUtc.toIso8601String()}`',
    '**Requalification required:** `${assessment.requiresRequalification}`',
    '',
    '| Claim | Recorded | Effective | Action | Review by |',
    '| --- | --- | --- | --- | --- |',
    for (final record in registry.records)
      '| `${record.claimId}` | ${record.status.name} | '
          '${record.effectiveStatusAt(asOf).name} | '
          '${record.dispositionAt(asOf).name} | '
          '${record.reviewByUtc} |',
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

  final output = Directory('build/evidence_currency')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${output.path}/latest.md').writeAsStringSync(markdown);

  stdout.writeln(
    'Evidence currency: ${pass ? 'pass' : 'FAILED'}; '
    'registry=${assessment.registrySha256}; '
    'held=${assessment.heldRecords.length}; '
    'blocked=${assessment.blockedRecords.length}; '
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
