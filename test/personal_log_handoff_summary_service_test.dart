import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/personal_log_handoff_document_service.dart';
import 'package:parkinsum_companion/domain/entities/medication_assertion_reconciliation.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/administration_dose_confirmation_coordinator.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_handoff_summary_service.dart';

void main() {
  const service = PersonalLogHandoffSummaryService();
  final options = PersonalLogHandoffOptions(
    startDate: DateTime.utc(2026, 8, 1),
    endDateInclusive: DateTime.utc(2026, 8, 31),
    sections: PersonalLogHandoffSection.values
        .where(
          (section) =>
              section != PersonalLogHandoffSection.personalObservations,
        )
        .toSet(),
    redaction: PersonalLogHandoffRedaction.detailed,
  );

  test('creates a deterministic bounded truth-preserving handoff', () {
    final snapshot = _snapshot();
    final artifact = service.create(
      snapshot: snapshot,
      options: options,
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );

    expect(artifact.recordCounts, <String, int>{
      'currentMedications': 1,
      'historicalMedications': 1,
      'intakes': 2,
      'meals': 1,
      'personalObservations': 0,
      'mealItems': 2,
    });
    expect(artifact.plainText, contains('Current medication selections'));
    expect(artifact.plainText, contains('Historical-only medications'));
    expect(artifact.plainText, contains('Active medicine'));
    expect(artifact.semanticDocument['schemaVersion'], 3);
    final semanticDocument =
        artifact.semanticDocument['document']! as Map<String, Object?>;
    expect(
      semanticDocument['format'],
      'parkinsum_personal_log_semantic_document',
    );
    expect(semanticDocument['schemaVersion'], 1);
    expect(semanticDocument['language'], 'en');
    expect(semanticDocument['direction'], 'auto');
    expect(
      artifact.documentBlocks.first,
      isA<PersonalLogHandoffHeadingBlock>(),
    );
    expect(
      artifact.documentBlocks,
      contains(isA<PersonalLogHandoffListBlock>()),
    );
    expect(artifact.plainText, contains('Historical medicine'));
    expect(artifact.plainText, contains('original dose=0.25 g'));
    expect(artifact.plainText, contains('dose expression=parseable'));
    expect(artifact.plainText, contains('result-use status=result-eligible'));
    expect(artifact.plainText, contains('canonical dose=250 mg'));
    expect(artifact.plainText, contains('original dose=unknown'));
    expect(artifact.plainText, contains('timezone=unknown'));
    expect(artifact.plainText, contains('protein=0 g'));
    expect(artifact.plainText, contains('protein=unknown'));
    expect(artifact.plainText, contains('source=TEST_FOOD'));
    expect(artifact.plainText, contains('USER-ENTERED PERSONAL LOG'));
    expect(artifact.plainText, contains('CLINICALLY VERIFIED'));
    expect(artifact.plainText, contains('no algorithm rank'));
    expect(artifact.plainText, isNot(contains('outside-range-note')));
    expect(artifact.plainText, isNot(contains('owner@example.test')));
    expect(artifact.plainText, isNot(contains('patient@example.test')));
    expect(artifact.pages, isNotEmpty);
    expect(
      artifact.pages.length,
      lessThanOrEqualTo(personalLogHandoffMaxPages),
    );

    final reordered = service.create(
      snapshot: _snapshot(reverseInputs: true),
      options: options,
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );
    expect(reordered.sourceRevisionSha256, artifact.sourceRevisionSha256);
    expect(reordered.contentSha256, artifact.contentSha256);
    expect(reordered.plainText, artifact.plainText);
  });

  test('semantic HTML preserves structure and escapes all user text', () {
    final artifact = PersonalLogHandoffArtifact(
      artifactId: 'artifact',
      ownerBindingSha256: 'owner',
      sourceRevisionSha256: 'source',
      contentSha256: 'content<unsafe>',
      fileName: 'parkinsum-personal-log-test.pdf',
      plainText: 'User-entered handoff',
      documentBlocks: <PersonalLogHandoffDocumentBlock>[
        const PersonalLogHandoffHeadingBlock(
          level: 1,
          text: 'Handoff & review',
        ),
        const PersonalLogHandoffParagraphBlock(
          text: '<img src=x onerror="alert(1)">',
        ),
        const PersonalLogHandoffParagraphBlock(
          text: 'Not clinically verified.',
          warning: true,
        ),
        PersonalLogHandoffListBlock(
          items: <PersonalLogHandoffListItem>[
            PersonalLogHandoffListItem(
              text: '</li><script>alert(1)</script>',
              details: const <String>['dose & source'],
            ),
          ],
        ),
      ],
      pages: const <PersonalLogHandoffDocumentPage>[],
      recordCounts: const <String, int>{},
      unsupportedFields: const <String>[],
      semanticDocument: const <String, Object?>{},
    );

    final html = utf8.decode(
      const PersonalLogHandoffHtmlSerializer().render(artifact),
    );
    expect(html, contains('<html lang="en" dir="auto">'));
    expect(html, contains('parkinsum-document-schema" content="1"'));
    expect(
      html,
      contains('<h1 id="document-title" dir="auto">Handoff &amp; review</h1>'),
    );
    expect(html, contains('<ul>'));
    expect(html, contains('<li dir="auto">'));
    expect(html, contains('class="boundary"'));
    expect(html, contains('&lt;img src=x onerror=&quot;alert(1)&quot;&gt;'));
    expect(html, contains('&lt;/li&gt;&lt;script&gt;alert(1)&lt;/script&gt;'));
    expect(html, contains('dose &amp; source'));
    expect(html, contains('content&lt;unsafe&gt;'));
    expect(html, isNot(contains('<script')));
    expect(html, isNot(contains('<img')));
    expect(html, isNot(contains('@import')));
    expect(html, isNot(contains('https://')));
    expect(artifact.htmlFileName, 'parkinsum-personal-log-test.html');
  });

  test(
    'handoff separates parseable input from result-eligible canonical dose',
    () {
      final unconfirmed = Intake(
        id: 'intake_unconfirmed',
        drugId: 'drug_active',
        takenAt: DateTime.utc(2026, 8, 5, 12),
        dosageNote: '0.25 g',
        doseAmount: 0.25,
        doseUnit: 'g',
      );
      final artifact = service.create(
        snapshot: _snapshot(intakesOverride: <Intake>[unconfirmed]),
        options: options,
        generatedAt: DateTime.utc(2026, 8, 18, 12),
      );
      final doseTruth = _doseTruth(artifact);
      final normalizedText = artifact.plainText.replaceAll(RegExp(r'\s+'), ' ');

      expect(artifact.plainText, contains('dose expression=parseable'));
      expect(normalizedText, contains('parsed quantity=0.25 g'));
      expect(artifact.plainText, contains('result-use status=held'));
      expect(artifact.plainText, contains('canonical dose=unavailable'));
      expect(artifact.plainText, isNot(contains('canonical dose=250 mg')));
      expect(doseTruth['parseableExpressionCount'], 1);
      expect(doseTruth['resultEligibleQuantityCount'], 0);
      expect(
        _heldReasons(doseTruth),
        containsPair('dose_confirmation.absent', 1),
      );
    },
  );

  test('stale confirmed dose is retained but never canonicalized', () {
    final confirmed = _confirmedIntake(
      id: 'intake_stale',
      note: '0.25 g',
      confirmedAt: DateTime.utc(2026, 8, 5, 12, 1),
    );
    final stale = confirmed.copyWith(doseAmount: 0.5);
    final artifact = service.create(
      snapshot: _snapshot(intakesOverride: <Intake>[stale]),
      options: options,
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );
    final reasons = _heldReasons(_doseTruth(artifact));

    expect(artifact.plainText, contains('dose expression=parseable'));
    expect(artifact.plainText, contains('result-use status=held'));
    expect(artifact.plainText, contains('canonical dose=unavailable'));
    expect(artifact.plainText, isNot(contains('canonical dose=500 mg')));
    expect(
      reasons.keys,
      containsAll(<String>[
        'dose_confirmation.structured_mismatch',
        'assertion_graph.local_confirmation_drift',
      ]),
    );
  });

  test('conflicted confirmed dose is never canonicalized', () {
    final confirmed = _confirmedIntake(
      id: 'intake_conflict',
      note: '0.25 g',
      confirmedAt: DateTime.utc(2026, 8, 5, 12, 1),
    );
    final conflicted = confirmed.copyWith(
      medicationAssertions: <MedicationAssertionNode>[
        ...confirmed.medicationAssertions,
        _externalAssertion(
          intake: confirmed,
          doseValue: 0.5,
          doseUnit: 'g',
          assertedAt: DateTime.utc(2026, 8, 5, 12, 2),
          sourceId: 'conflicting_import',
        ),
      ],
    );
    final artifact = service.create(
      snapshot: _snapshot(intakesOverride: <Intake>[conflicted]),
      options: options,
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );

    expect(artifact.plainText, contains('result-use status=held'));
    expect(artifact.plainText, contains('canonical dose=unavailable'));
    expect(artifact.plainText, isNot(contains('canonical dose=250 mg')));
    expect(
      _heldReasons(_doseTruth(artifact)),
      containsPair('assertion_graph.unresolved_conflict', 1),
    );
  });

  test('future confirmation evidence cannot enter an earlier handoff', () {
    final futureConfirmed = _confirmedIntake(
      id: 'intake_future',
      note: '0.25 g',
      confirmedAt: DateTime.utc(2026, 8, 18, 13),
    );
    final artifact = service.create(
      snapshot: _snapshot(intakesOverride: <Intake>[futureConfirmed]),
      options: options,
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );
    final reasons = _heldReasons(_doseTruth(artifact));

    expect(artifact.plainText, contains('result-use status=held'));
    expect(artifact.plainText, contains('canonical dose=unavailable'));
    expect(artifact.plainText, isNot(contains('canonical dose=250 mg')));
    expect(
      reasons.keys,
      containsAll(<String>[
        'dose_confirmation.confirmed_after_observation',
        'assertion_graph.evidence_after_observation',
      ]),
    );
  });

  test('future corroborating assertion holds an otherwise eligible dose', () {
    final confirmed = _confirmedIntake(
      id: 'intake_future_assertion',
      note: '0.25 g',
      confirmedAt: DateTime.utc(2026, 8, 5, 12, 1),
    );
    final withFutureEvidence = confirmed.copyWith(
      medicationAssertions: <MedicationAssertionNode>[
        ...confirmed.medicationAssertions,
        _externalAssertion(
          intake: confirmed,
          doseValue: 0.25,
          doseUnit: 'g',
          assertedAt: DateTime.utc(2026, 8, 18, 13),
          sourceId: 'future_corroboration',
        ),
      ],
    );
    final artifact = service.create(
      snapshot: _snapshot(intakesOverride: <Intake>[withFutureEvidence]),
      options: options,
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );

    expect(artifact.plainText, contains('result-use status=held'));
    expect(artifact.plainText, contains('canonical dose=unavailable'));
    expect(
      _heldReasons(_doseTruth(artifact)),
      containsPair('assertion_graph.evidence_after_observation', 1),
    );
  });

  test('counts-only redaction omits names, notes and source codes', () {
    final artifact = service.create(
      snapshot: _snapshot(),
      options: PersonalLogHandoffOptions(
        startDate: options.startDate,
        endDateInclusive: options.endDateInclusive,
        sections: options.sections,
        redaction: PersonalLogHandoffRedaction.countsOnly,
      ),
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );

    expect(artifact.plainText, contains('Redaction: countsOnly'));
    expect(artifact.plainText, contains('- Count: 1'));
    expect(artifact.plainText, contains('- Meals: 1'));
    expect(artifact.plainText, isNot(contains('Active medicine')));
    expect(artifact.plainText, isNot(contains('sensitive dose note')));
    expect(artifact.plainText, isNot(contains('FOOD-CODE-ZERO')));
  });

  test(
    'selected observations are date-bounded and preserve raw fields only',
    () {
      final observations = <PersonalObservation>[
        _symptomObservation(),
        _motorObservation(),
        _bloodPressureObservation(),
        _symptomObservation(
          id: 'observation_fatigue',
          occurredAt: DateTime.utc(2026, 8, 9),
          symptomLabel: 'Fatigue',
          severity: null,
          status: PersonalObservationStatus.notMeasured,
          notes: null,
        ),
        _symptomObservation(
          id: 'observation_outside',
          occurredAt: DateTime.utc(2026, 9, 2),
          symptomLabel: 'outside-range-symptom',
        ),
      ];
      final selected = PersonalLogHandoffOptions(
        startDate: options.startDate,
        endDateInclusive: options.endDateInclusive,
        sections: <PersonalLogHandoffSection>{
          ...options.sections,
          PersonalLogHandoffSection.personalObservations,
        },
        redaction: PersonalLogHandoffRedaction.detailed,
      );
      final artifact = service.create(
        snapshot: _snapshot(observationsOverride: observations),
        options: selected,
        generatedAt: DateTime.utc(2026, 8, 18, 12),
      );

      expect(artifact.recordCounts['personalObservations'], 4);
      expect(artifact.plainText, contains('## Personal observations'));
      expect(artifact.plainText, contains('Tremor'));
      expect(artifact.plainText, contains('severity=7/10'));
      expect(artifact.plainText, contains('private observation note'));
      expect(artifact.plainText, contains('recorded motor state=unknown'));
      expect(artifact.plainText, contains('120.5 / 80.0 mm[Hg]'));
      expect(artifact.plainText, contains('posture=standing'));
      expect(artifact.plainText, contains('status=notMeasured'));
      expect(artifact.plainText, contains('status=unknown'));
      expect(artifact.plainText, contains('interpretation'));
      expect(artifact.plainText, isNot(contains('outside-range-symptom')));
      expect(artifact.plainText, isNot(contains('observation_symptom')));
      expect(artifact.plainText, isNot(contains('recorder_private')));
      final standardArtifact = service.create(
        snapshot: _snapshot(observationsOverride: observations),
        options: PersonalLogHandoffOptions(
          startDate: selected.startDate,
          endDateInclusive: selected.endDateInclusive,
          sections: selected.sections,
          redaction: PersonalLogHandoffRedaction.standard,
        ),
        generatedAt: DateTime.utc(2026, 8, 18, 12),
      );
      expect(standardArtifact.plainText, contains('Tremor'));
      expect(
        standardArtifact.plainText,
        isNot(contains('private observation note')),
      );
      expect(
        artifact.plainText.indexOf('Tremor'),
        lessThan(artifact.plainText.indexOf('recorded motor state')),
      );
      expect(
        artifact.plainText.indexOf('recorded motor state'),
        lessThan(artifact.plainText.indexOf('120.5 / 80.0')),
      );
    },
  );

  test('counts-only observations reveal counts but omit entered content', () {
    final selected = PersonalLogHandoffOptions(
      startDate: options.startDate,
      endDateInclusive: options.endDateInclusive,
      sections: const <PersonalLogHandoffSection>{
        PersonalLogHandoffSection.personalObservations,
      },
      redaction: PersonalLogHandoffRedaction.countsOnly,
    );
    final artifact = service.create(
      snapshot: _snapshot(
        observationsOverride: <PersonalObservation>[
          _symptomObservation(),
          _motorObservation(),
          _bloodPressureObservation(),
          _symptomObservation(
            id: 'observation_fatigue',
            symptomLabel: 'Fatigue',
            severity: null,
            status: PersonalObservationStatus.notMeasured,
            notes: null,
          ),
        ],
      ),
      options: selected,
      generatedAt: DateTime.utc(2026, 8, 18, 12),
    );

    expect(artifact.plainText, contains('Count: 4'));
    expect(artifact.plainText, contains('recorded=2'));
    expect(artifact.plainText, contains('notMeasured=1'));
    expect(artifact.plainText, contains('unknown=1'));
    expect(artifact.plainText, isNot(contains('Tremor')));
    expect(artifact.plainText, isNot(contains('Fatigue')));
    expect(artifact.plainText, isNot(contains('120.5')));
    expect(artifact.plainText, isNot(contains('private observation note')));
    expect(artifact.plainText, isNot(contains('recorder_private')));
  });

  test(
    'observation revisions bind only when the optional section is selected',
    () {
      final originalObservations = <PersonalObservation>[_symptomObservation()];
      final changedObservations = <PersonalObservation>[
        _symptomObservation(severity: 8),
      ];
      final omittedDigest = service.sourceRevisionDigest(
        snapshot: _snapshot(observationsOverride: originalObservations),
        options: options,
      );
      final omittedAfterEdit = service.sourceRevisionDigest(
        snapshot: _snapshot(observationsOverride: changedObservations),
        options: options,
      );
      final selectedOptions = PersonalLogHandoffOptions(
        startDate: options.startDate,
        endDateInclusive: options.endDateInclusive,
        sections: <PersonalLogHandoffSection>{
          ...options.sections,
          PersonalLogHandoffSection.personalObservations,
        },
        redaction: options.redaction,
      );
      final selectedDigest = service.sourceRevisionDigest(
        snapshot: _snapshot(observationsOverride: originalObservations),
        options: selectedOptions,
      );
      final selectedAfterEdit = service.sourceRevisionDigest(
        snapshot: _snapshot(observationsOverride: changedObservations),
        options: selectedOptions,
      );

      expect(omittedAfterEdit, omittedDigest);
      expect(selectedAfterEdit, isNot(selectedDigest));
    },
  );

  test(
    'same-id content, options, and range changes rotate source revision',
    () {
      final original = service.sourceRevisionDigest(
        snapshot: _snapshot(),
        options: options,
      );
      final changed = service.sourceRevisionDigest(
        snapshot: _snapshot(intakeDoseAmount: 0.5),
        options: options,
      );
      final fewerSections = service.sourceRevisionDigest(
        snapshot: _snapshot(),
        options: PersonalLogHandoffOptions(
          startDate: options.startDate,
          endDateInclusive: options.endDateInclusive,
          sections: const <PersonalLogHandoffSection>{
            PersonalLogHandoffSection.intakeLog,
          },
          redaction: options.redaction,
        ),
      );
      final shorterRange = service.sourceRevisionDigest(
        snapshot: _snapshot(),
        options: PersonalLogHandoffOptions(
          startDate: DateTime.utc(2026, 8, 2),
          endDateInclusive: options.endDateInclusive,
          sections: options.sections,
          redaction: options.redaction,
        ),
      );

      expect(changed, isNot(original));
      expect(fewerSections, isNot(original));
      expect(shorterRange, isNot(original));
    },
  );

  test('invalid inputs fail closed before an artifact exists', () {
    expect(
      () => service.create(
        snapshot: _snapshot(),
        options: PersonalLogHandoffOptions(
          startDate: DateTime.utc(2026, 8, 2),
          endDateInclusive: DateTime.utc(2026, 8, 1),
          sections: const <PersonalLogHandoffSection>{
            PersonalLogHandoffSection.intakeLog,
          },
          redaction: PersonalLogHandoffRedaction.standard,
        ),
        generatedAt: DateTime.utc(2026, 8, 18),
      ),
      throwsFormatException,
    );
    expect(
      () => service.create(
        snapshot: _snapshot(duplicateIntake: true),
        options: options,
        generatedAt: DateTime.utc(2026, 8, 18),
      ),
      throwsFormatException,
    );
    expect(
      () => service.create(
        snapshot: _snapshot(intakeDoseAmount: double.nan),
        options: options,
        generatedAt: DateTime.utc(2026, 8, 18),
      ),
      throwsFormatException,
    );
    expect(
      () => service.create(
        snapshot: _snapshot(),
        options: PersonalLogHandoffOptions(
          startDate: DateTime.utc(2025, 1, 1),
          endDateInclusive: DateTime.utc(2026, 8, 31),
          sections: const <PersonalLogHandoffSection>{
            PersonalLogHandoffSection.intakeLog,
          },
          redaction: PersonalLogHandoffRedaction.standard,
        ),
        generatedAt: DateTime.utc(2026, 8, 18),
      ),
      throwsFormatException,
    );
  });
}

Map<String, Object?> _doseTruth(PersonalLogHandoffArtifact artifact) =>
    Map<String, Object?>.from(
      artifact.semanticDocument['doseTruthBoundary']! as Map,
    );

Map<String, int> _heldReasons(Map<String, Object?> doseTruth) =>
    Map<String, int>.from(doseTruth['heldReasonCounts']! as Map);

PersonalObservation _symptomObservation({
  String id = 'observation_symptom',
  DateTime? occurredAt,
  String symptomLabel = 'Tremor',
  int? severity = 7,
  PersonalObservationStatus status = PersonalObservationStatus.recorded,
  String? notes = 'private observation note',
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.symptom,
  occurredAt: occurredAt ?? DateTime.utc(2026, 8, 1, 8),
  recordedAt: DateTime.utc(2026, 8, 1, 12),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: 'recorder_private',
  status: status,
  symptomLabel: symptomLabel,
  severity: severity,
  notes: notes,
);

PersonalObservation _motorObservation() => PersonalObservation.create(
  id: 'observation_motor',
  kind: PersonalObservationKind.selfReportedMotorState,
  occurredAt: DateTime.utc(2026, 8, 10, 8),
  recordedAt: DateTime.utc(2026, 8, 10, 8, 5),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.caregiverReported,
  recorderId: 'recorder_private',
  status: PersonalObservationStatus.unknown,
);

PersonalObservation _bloodPressureObservation() => PersonalObservation.create(
  id: 'observation_bp',
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: DateTime.utc(2026, 8, 31, 23, 59),
  recordedAt: DateTime.utc(2026, 9, 1),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.deviceManual,
  recorderId: 'recorder_private',
  status: PersonalObservationStatus.recorded,
  systolic: 120.5,
  diastolic: 80,
  unit: PersonalObservation.bloodPressureUnit,
  posture: BloodPressurePosture.standing,
);

Intake _confirmedIntake({
  required String id,
  required String note,
  required DateTime confirmedAt,
  DateTime? takenAt,
}) {
  final coordinator = AdministrationDoseConfirmationCoordinator();
  final prepared = coordinator.prepare(
    draft: Intake(
      id: id,
      drugId: 'drug_active',
      takenAt: takenAt ?? DateTime.parse('2026-08-05T08:00:00-04:00'),
      dosageNote: note,
      dosageForm: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
    ),
    current: null,
    expectedRecordRevisionDigest:
        administrationDoseConfirmationAbsentRevisionDigest,
    ownerScope: 'owner@example.test',
    operationId: 'handoff_fixture_$id',
    confirmationRequested: true,
    assertionSource: AdministrationDoseAssertionSource.typed,
    confirmationAction: 'handoff_test.explicit_confirmation',
    uiContractVersion: 'handoff-test:1',
    confirmedAt: confirmedAt,
  );
  expect(prepared.status, AdministrationDosePreparationStatus.confirmed);
  return prepared.intake!;
}

MedicationAssertionNode _externalAssertion({
  required Intake intake,
  required double doseValue,
  required String doseUnit,
  required DateTime assertedAt,
  required String sourceId,
}) => MedicationAssertionNode.create(
  ownerScope: 'owner@example.test',
  intakeId: intake.id,
  medicationId: intake.drugId,
  productIdentityDigest:
      intake.medicationAssertions.single.productIdentityDigest,
  doseValue: doseValue,
  doseUnit: doseUnit,
  route: intake.route,
  dosageForm: intake.dosageForm,
  releaseType: intake.releaseType,
  evidenceClass: MedicationAssertionEvidenceClass.importedStatement,
  sourceArtifactId: sourceId,
  sourceArtifactDigest: medicationAssertionSnapshotDigest(sourceId),
  sourceRevisionDigest: medicationAssertionSnapshotDigest('$sourceId:v1'),
  actorIdentity: 'handoff_fixture_importer',
  actorRole: MedicationAssertionActorRole.importer,
  effectiveStart: intake.takenAt,
  effectiveEnd: intake.takenAt,
  timePrecision: MedicationAssertionTimePrecision.exact,
  timeUncertaintyMinutes: 0,
  timezoneOffsetMinutes: 0,
  timezoneSource: MedicationAssertionTimezoneSource.sourceDeclared,
  assertedAt: assertedAt,
  importedAt: null,
  recordedAt: assertedAt,
  status: MedicationAssertionStatus.taken,
);

PersonalLogHandoffSnapshot _snapshot({
  bool reverseInputs = false,
  bool duplicateIntake = false,
  double intakeDoseAmount = 0.25,
  Iterable<Intake>? intakesOverride,
  Iterable<PersonalObservation> observationsOverride = const [],
}) {
  final active = DrugDefinition(
    id: 'drug_active',
    genericName: 'Active medicine',
    brandNames: const <String>[],
    tags: const <DrugTag>[DrugTag.unknown],
    notes: '',
    sourceSystem: 'TEST_DRUG',
    sourceProductCode: 'ACTIVE-CODE',
    route: 'oral',
    dosageForm: 'tablet',
    releaseType: 'immediate',
  );
  final historical = DrugDefinition(
    id: 'drug_old',
    genericName: 'Historical medicine',
    brandNames: const <String>[],
    tags: const <DrugTag>[DrugTag.unknown],
    notes: '',
    sourceSystem: 'TEST_DRUG',
    sourceProductCode: 'HISTORICAL-CODE',
    route: 'oral',
    dosageForm: 'tablet',
    releaseType: 'immediate',
  );
  final firstIntake = intakeDoseAmount.isFinite && intakeDoseAmount > 0
      ? _confirmedIntake(
          id: 'intake_a',
          note: '$intakeDoseAmount g',
          confirmedAt: DateTime.parse('2026-08-05T08:01:00-04:00'),
        )
      : Intake(
          id: 'intake_a',
          drugId: 'drug_active',
          takenAt: DateTime.parse('2026-08-05T08:00:00-04:00'),
          dosageNote: '$intakeDoseAmount g',
          doseAmount: intakeDoseAmount,
          doseUnit: 'g',
          dosageForm: 'tablet',
          route: 'oral',
          releaseType: 'immediate',
        );
  final defaultIntakes = <Intake>[
    firstIntake,
    Intake(
      id: duplicateIntake ? 'intake_a' : 'intake_b',
      drugId: 'drug_old',
      takenAt: DateTime.parse('2026-08-06T08:00:00-04:00'),
      dosageNote: '',
    ),
    Intake(
      id: 'intake_outside',
      drugId: 'drug_active',
      takenAt: DateTime.utc(2026, 7, 1),
      dosageNote: 'outside-range-note',
    ),
  ];
  final intakes = intakesOverride?.toList(growable: false) ?? defaultIntakes;
  final zeroFood = FoodItem(
    id: 'food_zero',
    name: 'Known zero food',
    category: FoodCategory.other,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    fiberG: 0,
    sodiumMg: 0,
    sourceSystem: 'TEST_FOOD',
    sourceFoodCode: 'FOOD-CODE-ZERO',
    basisType: 'per_100g',
    qualifierKind: 'analytical',
  );
  final missingFood = FoodItem(
    id: 'food_missing',
    name: 'Unknown nutrient food',
    category: FoodCategory.other,
    proteinG: 0,
    carbsG: 0,
    fatG: 0,
    fiberG: 0,
    sodiumMg: 0,
    missingNutrientFields: const <String>{
      'proteinG',
      'carbsG',
      'fatG',
      'fiberG',
      'sodiumMg',
    },
    sourceSystem: 'TEST_FOOD',
  );
  final meal = Meal(
    id: 'meal_a',
    eatenAt: DateTime.parse('2026-08-07T12:00:00-04:00'),
    occurredAt: DateTime.parse('2026-08-07T12:00:00-04:00'),
    timeSource: 'user_entered',
    timePrecision: 'exact',
    title: 'Lunch',
    items: <MealItem>[
      MealItem.fromFood(food: zeroFood, quantityFactor: 1),
      MealItem.fromFood(food: missingFood, quantityFactor: 1),
    ],
  );
  return PersonalLogHandoffSnapshot(
    ownerScope: 'owner@example.test',
    profile: UserProfile.defaults().copyWith(
      patientId: 'patient@example.test',
      timezone: 'America/Toronto',
    ),
    activeDrugIds: const <String>['drug_active'],
    intakes: reverseInputs ? intakes.reversed : intakes,
    meals: <Meal>[meal],
    observations: observationsOverride,
    medicationCatalog: reverseInputs
        ? <DrugDefinition>[historical, active]
        : <DrugDefinition>[active, historical],
    foodCatalog: reverseInputs
        ? <FoodItem>[missingFood, zeroFood]
        : <FoodItem>[zeroFood, missingFood],
  );
}
