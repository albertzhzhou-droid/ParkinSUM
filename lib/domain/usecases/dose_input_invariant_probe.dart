import '../../core/models/administration_dose_confirmation.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import '../../core/models/medication_product_pack.dart';
import '../entities/dose_expression.dart';
import '../entities/input_quality.dart';
import '../entities/medication_assertion_reconciliation.dart';
import '../entities/source_metadata.dart';
import 'administration_dose_confirmation_coordinator.dart';
import 'dosage_note_parser.dart';
import 'input_quality_gate.dart';
import 'intake_dose_context_builder.dart';
import 'medication_entry_validator.dart';
import 'medication_package_dose_calculator.dart';
import 'metadata_completeness_gate.dart';

/// Black-box observations from the production dose-input algorithms.
///
/// Expected values deliberately live in the independent verification gate,
/// not here. This probe only executes manufactured inputs through production
/// code and records primitive outputs so mutation tests can alter one
/// observation without replacing the production implementation.
final class DoseInputInvariantProbe {
  static const int probeVersion = 1;
  static const String probeId = 'dose-input.black-box-production/1';

  DoseInputInvariantProbe({required Map<String, Object?> observations})
    : observations = Map<String, Object?>.unmodifiable(observations);

  factory DoseInputInvariantProbe.capture() {
    final parser = DosageNoteParser();
    final gram = parser.inspect(' 1 g ');
    final microgram = parser.inspect('1000 mcg');
    final volume = parser.inspect('1 mL');
    final range = parser.inspect('25-100 mg');
    final ratio = parser.inspect('25 mg / 100 mg');
    final rate = parser.inspect('2 mg/kg');
    final scientific = parser.inspect('1e3 mg');
    final comma = parser.inspect('1,5 mg');
    final leadingDecimal = parser.inspect('.5 mg');
    final unicodeMinus = parser.inspect('−5 mg');
    final zero = parser.inspect('0 mg');

    final drug = DrugDefinition(
      id: 'synthetic-levodopa-ir',
      genericName: 'synthetic levodopa',
      brandNames: const [],
      tags: const [DrugTag.levodopaLike],
      notes: 'Manufactured verification fixture only.',
      route: 'oral',
      dosageForm: 'tablet',
      releaseType: 'immediate',
    );
    final builder = IntakeDoseContextBuilder(dosageNoteParser: parser);
    final explicit = builder.build(
      id: 'synthetic-explicit-dose',
      drugId: drug.id,
      takenAt: DateTime.utc(2026, 8, 30, 12),
      dosageNote: ' 100 milligrams ',
      drug: drug,
    );
    final ambiguous = builder.build(
      id: 'synthetic-ambiguous-dose',
      drugId: drug.id,
      takenAt: DateTime.utc(2026, 8, 30, 12),
      dosageNote: '25 mg / 100 mg',
      drug: drug,
    );
    final selectedPackage = explicit.copyWith(
      productSelection: const MedicationProductSelection(
        packId: 'synthetic-package-without-formulation-snapshot',
        identifierSystem: 'ndcPackage',
        identifierValue: '00000-0000-00',
        displayName: 'Synthetic selected package',
        labelerName: 'synthetic',
        strengthDisplay: '25 mg + 100 mg',
        packageDescription: 'Manufactured fixture',
      ),
    );
    final selectedFormulation = resolveIntakeMechanisticFormulation(
      intake: selectedPackage,
      drug: drug,
    );

    const packageCalculator = MedicationPackageDoseCalculator();
    final package = _package(<MedicationIngredientStrength>[
      const MedicationIngredientStrength(
        ingredientName: 'CARBIDOPA',
        numeratorValue: 25,
        numeratorUnit: 'mg',
        denominatorValue: 1,
        denominatorUnit: null,
        rawStrength: '25 mg/1',
      ),
      const MedicationIngredientStrength(
        ingredientName: 'LEVODOPA',
        numeratorValue: 100,
        numeratorUnit: 'mg',
        denominatorValue: 1,
        denominatorUnit: null,
        rawStrength: '100 mg/1',
      ),
    ]);
    final halfUnit = packageCalculator.fromConfirmedQuantity(package, 0.5);
    final unrelated = packageCalculator.fromConfirmedQuantity(
      _package(const <MedicationIngredientStrength>[
        MedicationIngredientStrength(
          ingredientName: 'A',
          numeratorValue: 10,
          numeratorUnit: 'mg',
          denominatorValue: 1,
          denominatorUnit: null,
          rawStrength: '10 mg/1',
        ),
        MedicationIngredientStrength(
          ingredientName: 'B',
          numeratorValue: 20,
          numeratorUnit: 'mg',
          denominatorValue: 1,
          denominatorUnit: null,
          rawStrength: '20 mg/1',
        ),
      ]),
      1,
    );
    bool packageRejected(double strength, double quantity) =>
        packageCalculator.fromConfirmedQuantity(
          _package(<MedicationIngredientStrength>[
            MedicationIngredientStrength(
              ingredientName: 'LEVODOPA',
              numeratorValue: strength,
              numeratorUnit: 'mg',
              denominatorValue: 1,
              denominatorUnit: null,
              rawStrength: '$strength mg/1',
            ),
          ]),
          quantity,
        ) ==
        null;
    final ratioStrengthRejected =
        packageCalculator.fromConfirmedQuantity(
          _package(const <MedicationIngredientStrength>[
            MedicationIngredientStrength(
              ingredientName: 'LEVODOPA',
              numeratorValue: 10,
              numeratorUnit: 'mg',
              denominatorValue: 1,
              denominatorUnit: 'mL',
              rawStrength: '10 mg/mL',
            ),
          ]),
          1,
        ) ==
        null;

    final metadataGate = MetadataCompletenessGate();
    final completeMetadata = _medicationMetadata(strength: 100);
    final completeScore = metadataGate.scoreMedicationContext(completeMetadata);
    final missingUnitScore = metadataGate.scoreMedicationContext(
      _medicationMetadata(strength: 100, unit: ' '),
    );
    final nonFiniteScore = metadataGate.scoreMedicationContext(
      _medicationMetadata(strength: double.nan),
    );
    final nonPositiveScore = metadataGate.scoreMedicationContext(
      _medicationMetadata(strength: 0),
    );

    final qualityGate = InputQualityGate();
    final nonFiniteQuality = qualityGate.evaluate(
      InputQualityGateInput(
        medicationEntry: _rawMedication(strength: double.nan),
      ),
    );
    final nonFiniteDoseDimension = nonFiniteQuality.dimension(
      InputQualityDimension.medicationDosage,
    );
    final packageOnlyQuality = qualityGate.evaluate(
      InputQualityGateInput(
        medicationEntry: _rawMedication(strength: 100),
        productStrengthMetadataOnly: true,
      ),
    );
    final packageOnlyDoseDimension = packageOnlyQuality.dimension(
      InputQualityDimension.medicationDosage,
    );

    const resultGateOwner = 'synthetic-dose-invariant-owner';
    final resultGateEventAt = DateTime.utc(2026, 8, 30, 12);
    final resultGateObservedAt = resultGateEventAt.add(
      const Duration(hours: 1),
    );
    final resultGateCoordinator = AdministrationDoseConfirmationCoordinator(
      parser: parser,
    );
    Intake draftForResultGate({required String id, required String note}) =>
        Intake(
          id: id,
          drugId: drug.id,
          takenAt: resultGateEventAt,
          dosageNote: note,
          route: 'oral',
          dosageForm: 'tablet',
          releaseType: 'immediate',
        );
    Intake confirmForResultGate({
      required String id,
      required String note,
      DateTime? confirmedAt,
    }) {
      final prepared = resultGateCoordinator.prepare(
        draft: draftForResultGate(id: id, note: note),
        current: null,
        expectedRecordRevisionDigest:
            administrationDoseConfirmationAbsentRevisionDigest,
        ownerScope: resultGateOwner,
        operationId: 'synthetic-result-gate-$id',
        confirmationRequested: true,
        assertionSource: AdministrationDoseAssertionSource.typed,
        confirmationAction: 'verification.explicit_confirmation',
        uiContractVersion: 'dose-invariant-probe:1',
        confirmedAt:
            confirmedAt ?? resultGateEventAt.add(const Duration(minutes: 1)),
      );
      if (prepared.status != AdministrationDosePreparationStatus.confirmed ||
          prepared.intake == null) {
        throw StateError('Manufactured result-gate dose was not confirmed.');
      }
      return prepared.intake!;
    }

    final unconfirmedResultGate = resultGateCoordinator.evaluateForResultUse(
      draftForResultGate(id: 'result-gate-unconfirmed', note: '100 mg'),
      ownerScope: resultGateOwner,
      observedAt: resultGateObservedAt,
    );
    final confirmedIntake = confirmForResultGate(
      id: 'result-gate-confirmed',
      note: '100 mg',
    );
    final confirmedResultGate = resultGateCoordinator.evaluateForResultUse(
      confirmedIntake,
      ownerScope: resultGateOwner,
      observedAt: resultGateObservedAt,
    );
    final conflictingAssertion = MedicationAssertionNode.create(
      ownerScope: resultGateOwner,
      intakeId: confirmedIntake.id,
      medicationId: confirmedIntake.drugId,
      productIdentityDigest:
          confirmedIntake.medicationAssertions.single.productIdentityDigest,
      doseValue: 50,
      doseUnit: 'mg',
      route: confirmedIntake.route,
      dosageForm: confirmedIntake.dosageForm,
      releaseType: confirmedIntake.releaseType,
      evidenceClass: MedicationAssertionEvidenceClass.importedStatement,
      sourceArtifactId: 'synthetic-conflicting-dose',
      sourceArtifactDigest: medicationAssertionSnapshotDigest(
        'synthetic-conflicting-dose',
      ),
      sourceRevisionDigest: medicationAssertionSnapshotDigest(
        'synthetic-conflicting-dose-revision',
      ),
      actorIdentity: 'synthetic-dose-invariant-importer',
      actorRole: MedicationAssertionActorRole.importer,
      effectiveStart: resultGateEventAt,
      effectiveEnd: resultGateEventAt,
      timePrecision: MedicationAssertionTimePrecision.exact,
      timeUncertaintyMinutes: 0,
      timezoneOffsetMinutes: 0,
      timezoneSource: MedicationAssertionTimezoneSource.sourceDeclared,
      assertedAt: resultGateEventAt.add(const Duration(minutes: 2)),
      importedAt: resultGateEventAt.add(const Duration(minutes: 3)),
      recordedAt: resultGateEventAt.add(const Duration(minutes: 4)),
      status: MedicationAssertionStatus.taken,
    );
    final conflictedResultGate = resultGateCoordinator.evaluateForResultUse(
      confirmedIntake.copyWith(
        medicationAssertions: <MedicationAssertionNode>[
          ...confirmedIntake.medicationAssertions,
          conflictingAssertion,
        ],
      ),
      ownerScope: resultGateOwner,
      observedAt: resultGateObservedAt,
    );
    final futureResultGate = resultGateCoordinator.evaluateForResultUse(
      confirmForResultGate(
        id: 'result-gate-future',
        note: '100 mg',
        confirmedAt: resultGateObservedAt.add(const Duration(hours: 1)),
      ),
      ownerScope: resultGateOwner,
      observedAt: resultGateObservedAt,
    );
    final massResultGate = resultGateCoordinator.evaluateForResultUse(
      confirmForResultGate(id: 'result-gate-mass', note: '0.5 g'),
      ownerScope: resultGateOwner,
      observedAt: resultGateObservedAt,
    );
    final volumeResultGate = resultGateCoordinator.evaluateForResultUse(
      confirmForResultGate(id: 'result-gate-volume', note: '5 mL'),
      ownerScope: resultGateOwner,
      observedAt: resultGateObservedAt,
    );

    return DoseInputInvariantProbe(
      observations: <String, Object?>{
        'probe.version': probeVersion,
        'parser.gram.status': gram.status.name,
        'parser.gram.raw_preserved': gram.rawText == ' 1 g ',
        'parser.gram.normalized_text': gram.normalizedText,
        'parser.gram.unit': gram.expression?.unit.code,
        'parser.gram.dimension': gram.expression?.unit.dimension.name,
        'parser.gram.milligrams': parser.milligrams('1 g'),
        'parser.microgram.status': microgram.status.name,
        'parser.microgram.unit': microgram.expression?.unit.code,
        'parser.microgram.milligrams': parser.milligrams('1000 mcg'),
        'parser.volume.status': volume.status.name,
        'parser.volume.unit': volume.expression?.unit.code,
        'parser.volume.dimension': volume.expression?.unit.dimension.name,
        'parser.volume.milligrams': parser.milligrams('1 mL'),
        'parser.range.reason': _singleReason(range),
        'parser.ratio.reason': _singleReason(ratio),
        'parser.rate.reason': _singleReason(rate),
        'parser.scientific.reason': _singleReason(scientific),
        'parser.comma.reason': _singleReason(comma),
        'parser.leading_decimal.reason': _singleReason(leadingDecimal),
        'parser.unicode_minus.reason': _singleReason(unicodeMinus),
        'parser.zero.reason': _singleReason(zero),
        'builder.explicit.note': explicit.dosageNote,
        'builder.explicit.amount': explicit.doseAmount,
        'builder.explicit.unit': explicit.doseUnit,
        'builder.explicit.form': explicit.dosageForm,
        'builder.explicit.route': explicit.route,
        'builder.explicit.release': explicit.releaseType,
        'builder.ambiguous.amount': ambiguous.doseAmount,
        'builder.ambiguous.unit': ambiguous.doseUnit,
        'builder.selected_package.form': selectedFormulation.dosageForm,
        'builder.selected_package.route': selectedFormulation.route,
        'builder.selected_package.release': selectedFormulation.releaseType,
        'package.half.ingredient': halfUnit?.ingredientName,
        'package.half.amount': halfUnit?.amount,
        'package.half.unit': halfUnit?.unit,
        'package.half.quantity': halfUnit?.packageUnitQuantity,
        'package.half.label': halfUnit?.packageUnitLabel,
        'package.unrelated_multi_ingredient_rejected': unrelated == null,
        'package.negative_strength_rejected': packageRejected(-100, 1),
        'package.nan_strength_rejected': packageRejected(double.nan, 1),
        'package.infinite_strength_rejected': packageRejected(
          double.infinity,
          1,
        ),
        'package.overflow_rejected': packageRejected(double.maxFinite, 10),
        'package.ratio_strength_rejected': ratioStrengthRejected,
        'package.zero_quantity_rejected':
            packageCalculator.fromConfirmedQuantity(package, 0) == null,
        'package.excess_quantity_rejected':
            packageCalculator.fromConfirmedQuantity(package, 11) == null,
        'metadata.complete.status': completeScore.name,
        'metadata.missing_unit.status': missingUnitScore.name,
        'metadata.nonfinite.status': nonFiniteScore.name,
        'metadata.nonpositive.status': nonPositiveScore.name,
        'metadata.weights': <double>[
          for (final status in MetadataCompletenessScore.values)
            metadataGate.toWeight(status),
        ],
        'input_quality.nonfinite.status': nonFiniteDoseDimension?.status,
        'input_quality.nonfinite.has_blocker':
            nonFiniteDoseDimension?.findings.any(
              (finding) =>
                  finding.severity == InputQualitySeverity.blocker &&
                  finding.findingId == 'dosage_invalid_shape',
            ) ??
            false,
        'input_quality.nonfinite.eligible':
            nonFiniteQuality.mechanisticPrimaryEligible,
        'input_quality.package_only.status': packageOnlyDoseDimension?.status,
        'input_quality.package_only.has_blocker':
            packageOnlyDoseDimension?.findings.any(
              (finding) =>
                  finding.severity == InputQualitySeverity.blocker &&
                  finding.findingId == 'dosage_product_strength_only',
            ) ??
            false,
        'input_quality.package_only.eligible':
            packageOnlyQuality.mechanisticPrimaryEligible,
        'result_gate.unconfirmed.confirmation_status':
            unconfirmedResultGate.confirmation.status.name,
        'result_gate.unconfirmed.assertion_eligible':
            unconfirmedResultGate.assertionGraph.resultAffectingDoseEligible,
        'result_gate.unconfirmed.eligible': unconfirmedResultGate.eligible,
        'result_gate.unconfirmed.value': unconfirmedResultGate.value,
        'result_gate.unconfirmed.has_absent_reason': unconfirmedResultGate
            .reasonCodes
            .contains('dose_confirmation.absent'),
        'result_gate.unconfirmed.has_local_receipt_reason':
            unconfirmedResultGate.reasonCodes.contains(
              'assertion_graph.local_receipt_absent',
            ),
        'result_gate.confirmed.confirmation_status':
            confirmedResultGate.confirmation.status.name,
        'result_gate.confirmed.assertion_eligible':
            confirmedResultGate.assertionGraph.resultAffectingDoseEligible,
        'result_gate.confirmed.eligible': confirmedResultGate.eligible,
        'result_gate.confirmed.value': confirmedResultGate.value,
        'result_gate.confirmed.unit': confirmedResultGate.unit,
        'result_gate.confirmed.milligrams': confirmedResultGate.milligrams,
        'result_gate.confirmed.reason_count':
            confirmedResultGate.reasonCodes.length,
        'result_gate.conflict.assertion_eligible':
            conflictedResultGate.assertionGraph.resultAffectingDoseEligible,
        'result_gate.conflict.has_unresolved_graph':
            conflictedResultGate.assertionGraph.hasUnresolvedConflict,
        'result_gate.conflict.eligible': conflictedResultGate.eligible,
        'result_gate.conflict.value': conflictedResultGate.value,
        'result_gate.conflict.has_unresolved_reason': conflictedResultGate
            .reasonCodes
            .contains('assertion_graph.unresolved_conflict'),
        'result_gate.future.eligible': futureResultGate.eligible,
        'result_gate.future.value': futureResultGate.value,
        'result_gate.future.has_future_confirmation_reason': futureResultGate
            .reasonCodes
            .contains('dose_confirmation.confirmed_after_observation'),
        'result_gate.future.has_future_evidence_reason': futureResultGate
            .reasonCodes
            .contains('assertion_graph.evidence_after_observation'),
        'result_gate.mass.eligible': massResultGate.eligible,
        'result_gate.mass.value': massResultGate.value,
        'result_gate.mass.unit': massResultGate.unit,
        'result_gate.mass.milligrams': massResultGate.milligrams,
        'result_gate.volume.eligible': volumeResultGate.eligible,
        'result_gate.volume.value': volumeResultGate.value,
        'result_gate.volume.unit': volumeResultGate.unit,
        'result_gate.volume.milligrams': volumeResultGate.milligrams,
      },
    );
  }

  final Map<String, Object?> observations;

  DoseInputInvariantProbe withObservation(String key, Object? value) {
    return DoseInputInvariantProbe(
      observations: <String, Object?>{...observations, key: value},
    );
  }

  DoseInputInvariantProbe withoutObservation(String key) {
    return DoseInputInvariantProbe(
      observations: <String, Object?>{...observations}..remove(key),
    );
  }
}

String? _singleReason(DoseExpressionParseResult result) {
  final reasons = result.reasonCodes;
  return reasons.length == 1 ? reasons.single : null;
}

MedicationProductPack _package(List<MedicationIngredientStrength> strengths) {
  return MedicationProductPack(
    id: 'synthetic-package',
    genericName: 'synthetic combination',
    brandName: null,
    labelerName: 'synthetic',
    jurisdiction: 'US',
    identifiers: const <MedicationProductIdentifier>[
      MedicationProductIdentifier(
        system: MedicationIdentifierSystem.ndcPackage,
        level: MedicationIdentifierLevel.package,
        value: '00000-000-01',
      ),
    ],
    ingredients: strengths,
    dosageForm: 'TABLET',
    routes: const <String>['ORAL'],
    packageDescription: 'Manufactured invariant fixture',
    marketingStartDate: null,
    marketingEndDate: null,
    sourceSystem: 'SYNTHETIC',
    sourceUrl: 'urn:parkinsum:synthetic-dose-invariant',
    retrievedAt: null,
  );
}

DrugProductVariantMetadata _medicationMetadata({
  required double strength,
  String unit = 'mg',
}) {
  return DrugProductVariantMetadata(
    drugProductVariantId: 'synthetic-variant',
    sourceSystem: 'SYNTHETIC',
    jurisdiction: 'US',
    language: 'en',
    genericName: 'synthetic levodopa',
    brandName: null,
    activeIngredients: const <String>['levodopa'],
    strengthValue: strength,
    strengthUnit: unit,
    doseForm: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    productIdentifier: 'synthetic-product',
    labelSection: 'synthetic-label',
    translationStatus: ReferenceTranslationStatus.notTranslation,
    extractionConfidence: 1,
    sourceRefs: const <String>['src.synthetic.dose-invariant'],
    limitationText: 'Manufactured verification fixture only.',
  );
}

RawMedicationEntry _rawMedication({required double strength}) {
  return RawMedicationEntry(
    activeIngredient: 'levodopa',
    drugProductVariant: 'synthetic-variant',
    form: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    strength: strength,
    unit: 'mg',
    jurisdiction: 'US',
    sourceDocId: 'src.synthetic.dose-invariant',
  );
}
