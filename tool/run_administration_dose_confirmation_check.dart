import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';

void main() {
  final coordinator = AdministrationDoseConfirmationCoordinator();
  final base = Intake(
    id: 'dose_gate_intake',
    drugId: 'levodopa',
    takenAt: DateTime.utc(2026, 8, 27, 12),
    dosageNote: '100 mg',
    productSelection: const MedicationProductSelection(
      packId: 'dose_gate_pack',
      identifierSystem: 'din',
      identifierValue: '12345678',
      displayName: 'Synthetic package',
      labelerName: 'Synthetic labeler',
      strengthDisplay: 'levodopa 100 mg',
      packageDescription: 'Synthetic governance fixture only',
    ),
  );
  final prepared = coordinator.prepare(
    draft: base,
    current: null,
    expectedRecordRevisionDigest:
        administrationDoseConfirmationAbsentRevisionDigest,
    ownerScope: 'dose_gate_owner',
    operationId: 'dose_gate_operation',
    confirmationRequested: true,
    assertionSource: AdministrationDoseAssertionSource.typed,
    confirmationAction: 'timeline.explicit_checkbox',
    uiContractVersion: 'timeline-dose-confirmation:1',
    confirmedAt: DateTime.utc(2026, 8, 27, 12, 1),
  );
  final confirmed = prepared.intake!;

  final malformedJson = Map<String, dynamic>.from(confirmed.toJson());
  malformedJson['doseConfirmation'] = Map<String, dynamic>.from(
    malformedJson['doseConfirmation'] as Map,
  )..['receipt_digest'] = List<String>.filled(64, '0').join();
  final futureJson = Map<String, dynamic>.from(confirmed.toJson());
  futureJson['doseConfirmation'] = Map<String, dynamic>.from(
    futureJson['doseConfirmation'] as Map,
  )..['schema_version'] = administrationDoseConfirmationSchemaVersion + 1;

  final expected = <String, AdministrationDoseEvaluationStatus>{
    'confirmed': AdministrationDoseEvaluationStatus.confirmed,
    'owner_replay': AdministrationDoseEvaluationStatus.ownerMismatch,
    'raw_replacement': AdministrationDoseEvaluationStatus.rawExpressionMismatch,
    'product_swap': AdministrationDoseEvaluationStatus.productMismatch,
    'time_change':
        AdministrationDoseEvaluationStatus.administrationTimeMismatch,
    'structured_replacement':
        AdministrationDoseEvaluationStatus.structuredDoseMismatch,
    'malformed_digest': AdministrationDoseEvaluationStatus.invalidEvidence,
    'future_schema': AdministrationDoseEvaluationStatus.invalidEvidence,
  };
  final actual = <String, AdministrationDoseEvaluation>{
    'confirmed': coordinator.evaluate(confirmed, ownerScope: 'dose_gate_owner'),
    'owner_replay': coordinator.evaluate(
      confirmed,
      ownerScope: 'different_owner',
    ),
    'raw_replacement': coordinator.evaluate(
      confirmed.copyWith(dosageNote: '50 mg'),
      ownerScope: 'dose_gate_owner',
    ),
    'product_swap': coordinator.evaluate(
      confirmed.copyWith(
        productSelection: const MedicationProductSelection(
          packId: 'different_pack',
          identifierSystem: 'din',
          identifierValue: '87654321',
          displayName: 'Different synthetic package',
          labelerName: 'Synthetic labeler',
          strengthDisplay: 'levodopa 100 mg',
          packageDescription: 'Synthetic mutation only',
        ),
      ),
      ownerScope: 'dose_gate_owner',
    ),
    'time_change': coordinator.evaluate(
      confirmed.copyWith(takenAt: DateTime.utc(2026, 8, 27, 13)),
      ownerScope: 'dose_gate_owner',
    ),
    'structured_replacement': coordinator.evaluate(
      Intake(
        id: confirmed.id,
        drugId: confirmed.drugId,
        takenAt: confirmed.takenAt,
        dosageNote: confirmed.dosageNote,
        doseAmount: 50,
        doseUnit: confirmed.doseUnit,
        productSelection: confirmed.productSelection,
        doseConfirmation: confirmed.doseConfirmation,
      ),
      ownerScope: 'dose_gate_owner',
    ),
    'malformed_digest': coordinator.evaluate(
      Intake.fromJson(malformedJson),
      ownerScope: 'dose_gate_owner',
    ),
    'future_schema': coordinator.evaluate(
      Intake.fromJson(futureJson),
      ownerScope: 'dose_gate_owner',
    ),
  };

  final stale = coordinator.prepare(
    draft: base.copyWith(dosageNote: '50 mg'),
    current: confirmed,
    expectedRecordRevisionDigest:
        administrationDoseConfirmationAbsentRevisionDigest,
    ownerScope: 'dose_gate_owner',
    operationId: 'dose_gate_stale_operation',
    confirmationRequested: true,
    assertionSource: AdministrationDoseAssertionSource.typed,
    confirmationAction: 'timeline.explicit_checkbox',
    uiContractVersion: 'timeline-dose-confirmation:1',
    confirmedAt: DateTime.utc(2026, 8, 27, 12, 2),
  );
  final held = coordinator.prepare(
    draft: base.copyWith(dosageNote: '100 mg then 50 mg'),
    current: null,
    expectedRecordRevisionDigest:
        administrationDoseConfirmationAbsentRevisionDigest,
    ownerScope: 'dose_gate_owner',
    operationId: 'dose_gate_held_operation',
    confirmationRequested: true,
    assertionSource: AdministrationDoseAssertionSource.typed,
    confirmationAction: 'timeline.explicit_checkbox',
    uiContractVersion: 'timeline-dose-confirmation:1',
    confirmedAt: DateTime.utc(2026, 8, 27, 12, 2),
  );
  final unconfirmed = coordinator.prepare(
    draft: base,
    current: null,
    expectedRecordRevisionDigest:
        administrationDoseConfirmationAbsentRevisionDigest,
    ownerScope: 'dose_gate_owner',
    operationId: 'dose_gate_unconfirmed_operation',
    confirmationRequested: false,
    assertionSource: AdministrationDoseAssertionSource.typed,
    confirmationAction: 'timeline.explicit_checkbox',
    uiContractVersion: 'timeline-dose-confirmation:1',
    confirmedAt: DateTime.utc(2026, 8, 27, 12, 2),
  );

  final failures = <Map<String, Object?>>[];
  for (final entry in expected.entries) {
    final observed = actual[entry.key]!.status;
    if (observed != entry.value) {
      failures.add(<String, Object?>{
        'case': entry.key,
        'expected': entry.value.name,
        'actual': observed.name,
      });
    }
  }
  if (stale.status != AdministrationDosePreparationStatus.staleRevision) {
    failures.add(<String, Object?>{
      'case': 'stale_revision',
      'expected': AdministrationDosePreparationStatus.staleRevision.name,
      'actual': stale.status.name,
    });
  }
  if (held.status != AdministrationDosePreparationStatus.heldExpression) {
    failures.add(<String, Object?>{
      'case': 'held_expression',
      'expected': AdministrationDosePreparationStatus.heldExpression.name,
      'actual': held.status.name,
    });
  }
  if (unconfirmed.status != AdministrationDosePreparationStatus.unconfirmed ||
      unconfirmed.intake?.doseAmount != null ||
      unconfirmed.intake?.doseConfirmation != null) {
    failures.add(<String, Object?>{
      'case': 'unconfirmed_numeric_hold',
      'expected': 'unconfirmed_without_structured_dose_or_receipt',
      'actual': unconfirmed.status.name,
    });
  }
  final receiptJson = confirmed.doseConfirmation!.toJson();
  if (jsonEncode(receiptJson).contains('dose_gate_owner')) {
    failures.add(<String, Object?>{
      'case': 'owner_scope_disclosure',
      'expected': 'one_way_digest_only',
      'actual': 'raw_owner_scope_found',
    });
  }

  final cases = <Map<String, Object?>>[
    for (final entry in actual.entries)
      <String, Object?>{
        'case': entry.key,
        'status': entry.value.status.name,
        'reason_code': entry.value.reasonCode,
      },
    <String, Object?>{
      'case': 'stale_revision',
      'status': stale.status.name,
      'reason_code': stale.reasonCode,
    },
    <String, Object?>{
      'case': 'held_expression',
      'status': held.status.name,
      'reason_code': held.reasonCode,
    },
    <String, Object?>{
      'case': 'unconfirmed_numeric_hold',
      'status': unconfirmed.status.name,
      'reason_code': unconfirmed.reasonCode,
    },
  ];
  final pass = failures.isEmpty;
  final report = <String, Object?>{
    'report_type': 'parkinsum_administration_dose_confirmation',
    'schema_version': administrationDoseConfirmationSchemaVersion,
    'pass': pass,
    'case_count': cases.length,
    'receipt_digest': confirmed.doseConfirmation!.receiptDigest,
    'grammar_id': confirmed.doseConfirmation!.grammarId,
    'grammar_version': confirmed.doseConfirmation!.grammarVersion,
    'grammar_digest': confirmed.doseConfirmation!.grammarDigest,
    'cases': cases,
    'failures': failures,
    'synthetic_only': true,
    'not_fhir_conformance': true,
    'not_proof_of_administration': true,
    'safety_boundary':
        'This gate verifies local assertion binding and fail-closed '
        'reconciliation only. It does not verify a prescription, medication '
        'administration, adherence, dose safety, or clinical validity.',
  };
  final output = Directory('build/administration_dose_confirmation')
    ..createSync(recursive: true);
  File('${output.path}/latest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  final markdown = <String>[
    '# Administration-dose confirmation check',
    '',
    '**Result:** ${pass ? 'pass' : 'FAILED'}',
    '**Synthetic cases:** ${cases.length}',
    '**Receipt:** `${confirmed.doseConfirmation!.receiptDigest}`',
    '**Grammar:** `${confirmed.doseConfirmation!.grammarId}` '
        'v${confirmed.doseConfirmation!.grammarVersion}',
    '',
    '| Case | Status | Reason |',
    '| --- | --- | --- |',
    for (final item in cases)
      '| ${item['case']} | ${item['status']} | ${item['reason_code']} |',
    '',
    '## Boundary',
    '',
    report['safety_boundary']! as String,
    '',
  ].join('\n');
  File('${output.path}/latest.md').writeAsStringSync(markdown);

  stdout.writeln(
    'Administration-dose confirmation: '
    '${pass ? 'pass' : 'FAILED'}; ${cases.length} synthetic cases; '
    'failures=${failures.length}.',
  );
  stdout.writeln('Report: ${output.path}/latest.json');
  stdout.writeln('Report: ${output.path}/latest.md');
  if (!pass) exitCode = 1;
}
