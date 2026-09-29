import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/models/administration_dose_confirmation.dart';

const int medicationAssertionSchemaVersion = 2;
const Set<int> medicationAssertionAcceptedLegacyVersions = <int>{1};
const int medicationReconciliationDecisionSchemaVersion = 1;

enum MedicationAssertionEvidenceClass {
  localUserConfirmation,
  userStatement,
  caregiverStatement,
  packageDerived,
  importedStatement,
  prescriptionRequest,
  dispenseRecord,
  deviceObservation,
  formalAdministration,
}

enum MedicationAssertionActorRole {
  user,
  caregiver,
  clinician,
  pharmacist,
  device,
  importer,
  organization,
  unknown,
}

enum MedicationAssertionStatus { taken, notTaken, unknown, enteredInError }

enum MedicationAssertionLifecycle { active, superseded, retracted }

enum MedicationAssertionTimePrecision {
  exact,
  minute,
  hour,
  day,
  interval,
  unknown,
}

enum MedicationAssertionTimezoneSource {
  sourceDeclared,
  capturedOffset,
  deviceLocal,
  unknown,
}

enum MedicationReconciliationResolution {
  confirmedNoConflict,
  acknowledgedUnresolved,
  heldForReview,
}

/// One immutable source claim about a candidate medication event.
///
/// Claims are evidence, not truth. In particular, a request, dispense,
/// package, device signal, imported row, or formal-administration label is
/// never relabelled as a local user confirmation and never proves adherence.
final class MedicationAssertionNode {
  MedicationAssertionNode._({
    required this.assertionId,
    required this.assertionDigest,
    required this.ownerScopeDigest,
    required this.intakeId,
    required this.medicationId,
    required this.productIdentityDigest,
    required this.doseValue,
    required this.doseUnit,
    required this.route,
    required this.dosageForm,
    required this.releaseType,
    required this.evidenceClass,
    required this.identitySchemaVersion,
    required this.sourceDisplayLabel,
    required this.sourceArtifactId,
    required this.sourceArtifactDigest,
    required this.sourceRevisionDigest,
    required this.actorIdentityDigest,
    required this.actorRole,
    required this.derivedFromAssertionIds,
    required this.supersedesAssertionIds,
    required this.retractsAssertionIds,
    required this.effectiveStartUtc,
    required this.effectiveEndUtc,
    required this.timePrecision,
    required this.timeUncertaintyMinutes,
    required this.timezoneOffsetMinutes,
    required this.timezoneSource,
    required this.assertedAtUtc,
    required this.importedAtUtc,
    required this.recordedAtUtc,
    required this.status,
    required this.lifecycle,
    required this.localConfirmationReceiptDigest,
  });

  final String assertionId;
  final String assertionDigest;
  final String ownerScopeDigest;
  final String intakeId;
  final String medicationId;
  final String productIdentityDigest;
  final double? doseValue;
  final String? doseUnit;
  final String? route;
  final String? dosageForm;
  final String? releaseType;
  final MedicationAssertionEvidenceClass evidenceClass;
  final int identitySchemaVersion;
  final String? sourceDisplayLabel;
  final String sourceArtifactId;
  final String sourceArtifactDigest;
  final String sourceRevisionDigest;
  final String actorIdentityDigest;
  final MedicationAssertionActorRole actorRole;
  final List<String> derivedFromAssertionIds;
  final List<String> supersedesAssertionIds;
  final List<String> retractsAssertionIds;
  final DateTime? effectiveStartUtc;
  final DateTime? effectiveEndUtc;
  final MedicationAssertionTimePrecision timePrecision;
  final int timeUncertaintyMinutes;
  final int? timezoneOffsetMinutes;
  final MedicationAssertionTimezoneSource timezoneSource;
  final DateTime assertedAtUtc;
  final DateTime? importedAtUtc;
  final DateTime recordedAtUtc;
  final MedicationAssertionStatus status;
  final MedicationAssertionLifecycle lifecycle;
  final String? localConfirmationReceiptDigest;

  bool get isCurrentLocalConfirmation =>
      evidenceClass == MedicationAssertionEvidenceClass.localUserConfirmation &&
      lifecycle == MedicationAssertionLifecycle.active &&
      status == MedicationAssertionStatus.taken &&
      localConfirmationReceiptDigest != null;

  factory MedicationAssertionNode.create({
    required String ownerScope,
    required String intakeId,
    required String medicationId,
    required String productIdentityDigest,
    required double? doseValue,
    required String? doseUnit,
    required String? route,
    required String? dosageForm,
    required String? releaseType,
    required MedicationAssertionEvidenceClass evidenceClass,
    String? sourceDisplayLabel,
    required String sourceArtifactId,
    required String sourceArtifactDigest,
    required String sourceRevisionDigest,
    required String actorIdentity,
    required MedicationAssertionActorRole actorRole,
    List<String> derivedFromAssertionIds = const <String>[],
    List<String> supersedesAssertionIds = const <String>[],
    List<String> retractsAssertionIds = const <String>[],
    required DateTime? effectiveStart,
    required DateTime? effectiveEnd,
    required MedicationAssertionTimePrecision timePrecision,
    required int timeUncertaintyMinutes,
    required int? timezoneOffsetMinutes,
    required MedicationAssertionTimezoneSource timezoneSource,
    required DateTime assertedAt,
    required DateTime? importedAt,
    required DateTime recordedAt,
    required MedicationAssertionStatus status,
    MedicationAssertionLifecycle lifecycle =
        MedicationAssertionLifecycle.active,
    String? localConfirmationReceiptDigest,
  }) {
    if (sourceDisplayLabel != null && _optional(sourceDisplayLabel) == null) {
      throw const FormatException('Medication source label is empty.');
    }
    final normalizedDisplayLabel = _optional(sourceDisplayLabel);
    return MedicationAssertionNode._createWithDigestedIdentities(
      ownerScopeDigest: digestMedicationAssertionIdentity(ownerScope),
      intakeId: intakeId,
      medicationId: medicationId,
      productIdentityDigest: productIdentityDigest,
      doseValue: doseValue,
      doseUnit: doseUnit,
      route: route,
      dosageForm: dosageForm,
      releaseType: releaseType,
      evidenceClass: evidenceClass,
      identitySchemaVersion: normalizedDisplayLabel == null ? 1 : 2,
      sourceDisplayLabel: normalizedDisplayLabel,
      sourceArtifactId: sourceArtifactId,
      sourceArtifactDigest: sourceArtifactDigest,
      sourceRevisionDigest: sourceRevisionDigest,
      actorIdentityDigest: digestMedicationAssertionIdentity(actorIdentity),
      actorRole: actorRole,
      derivedFromAssertionIds: derivedFromAssertionIds,
      supersedesAssertionIds: supersedesAssertionIds,
      retractsAssertionIds: retractsAssertionIds,
      effectiveStart: effectiveStart,
      effectiveEnd: effectiveEnd,
      timePrecision: timePrecision,
      timeUncertaintyMinutes: timeUncertaintyMinutes,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      timezoneSource: timezoneSource,
      assertedAt: assertedAt,
      importedAt: importedAt,
      recordedAt: recordedAt,
      status: status,
      lifecycle: lifecycle,
      localConfirmationReceiptDigest: localConfirmationReceiptDigest,
    );
  }

  factory MedicationAssertionNode.fromLocalConfirmation({
    required AdministrationDoseConfirmationReceipt receipt,
    required String? route,
    required String? dosageForm,
    required String? releaseType,
    List<String> supersedesAssertionIds = const <String>[],
  }) => MedicationAssertionNode._createWithDigestedIdentities(
    ownerScopeDigest: receipt.ownerScopeDigest,
    intakeId: receipt.intakeId,
    medicationId: receipt.medicationId,
    productIdentityDigest: receipt.productSnapshotDigest,
    doseValue: receipt.structuredValue,
    doseUnit: receipt.structuredUnit,
    route: route,
    dosageForm: dosageForm,
    releaseType: releaseType,
    evidenceClass: MedicationAssertionEvidenceClass.localUserConfirmation,
    identitySchemaVersion: 1,
    sourceDisplayLabel: null,
    sourceArtifactId: receipt.receiptId,
    sourceArtifactDigest: receipt.receiptDigest,
    sourceRevisionDigest: receipt.receiptDigest,
    actorIdentityDigest: receipt.ownerScopeDigest,
    actorRole: MedicationAssertionActorRole.user,
    derivedFromAssertionIds: const <String>[],
    supersedesAssertionIds: supersedesAssertionIds,
    retractsAssertionIds: const <String>[],
    effectiveStart: receipt.administrationAtUtc,
    effectiveEnd: receipt.administrationAtUtc,
    timePrecision: MedicationAssertionTimePrecision.exact,
    timeUncertaintyMinutes: 0,
    timezoneOffsetMinutes: 0,
    timezoneSource: MedicationAssertionTimezoneSource.capturedOffset,
    assertedAt: receipt.confirmedAtUtc,
    importedAt: null,
    recordedAt: receipt.confirmedAtUtc,
    status: MedicationAssertionStatus.taken,
    lifecycle: MedicationAssertionLifecycle.active,
    localConfirmationReceiptDigest: receipt.receiptDigest,
  );

  static MedicationAssertionNode _createWithDigestedIdentities({
    required String ownerScopeDigest,
    required String intakeId,
    required String medicationId,
    required String productIdentityDigest,
    required double? doseValue,
    required String? doseUnit,
    required String? route,
    required String? dosageForm,
    required String? releaseType,
    required MedicationAssertionEvidenceClass evidenceClass,
    required int identitySchemaVersion,
    required String? sourceDisplayLabel,
    required String sourceArtifactId,
    required String sourceArtifactDigest,
    required String sourceRevisionDigest,
    required String actorIdentityDigest,
    required MedicationAssertionActorRole actorRole,
    required List<String> derivedFromAssertionIds,
    required List<String> supersedesAssertionIds,
    required List<String> retractsAssertionIds,
    required DateTime? effectiveStart,
    required DateTime? effectiveEnd,
    required MedicationAssertionTimePrecision timePrecision,
    required int timeUncertaintyMinutes,
    required int? timezoneOffsetMinutes,
    required MedicationAssertionTimezoneSource timezoneSource,
    required DateTime assertedAt,
    required DateTime? importedAt,
    required DateTime recordedAt,
    required MedicationAssertionStatus status,
    required MedicationAssertionLifecycle lifecycle,
    required String? localConfirmationReceiptDigest,
  }) {
    final normalizedDoseUnit = _optional(doseUnit);
    final normalizedSourceDisplayLabel = _optional(sourceDisplayLabel);
    final identity = _identityPayload(
      identitySchemaVersion: identitySchemaVersion,
      ownerScopeDigest: ownerScopeDigest,
      intakeId: intakeId,
      medicationId: medicationId,
      productIdentityDigest: productIdentityDigest,
      doseValue: doseValue,
      doseUnit: normalizedDoseUnit,
      route: _optional(route),
      dosageForm: _optional(dosageForm),
      releaseType: _optional(releaseType),
      evidenceClass: evidenceClass,
      sourceDisplayLabel: normalizedSourceDisplayLabel,
      sourceArtifactId: sourceArtifactId,
      sourceArtifactDigest: sourceArtifactDigest,
      sourceRevisionDigest: sourceRevisionDigest,
      actorIdentityDigest: actorIdentityDigest,
      actorRole: actorRole,
      derivedFromAssertionIds: _orderedIds(derivedFromAssertionIds),
      supersedesAssertionIds: _orderedIds(supersedesAssertionIds),
      retractsAssertionIds: _orderedIds(retractsAssertionIds),
      effectiveStartUtc: effectiveStart?.toUtc(),
      effectiveEndUtc: effectiveEnd?.toUtc(),
      timePrecision: timePrecision,
      timeUncertaintyMinutes: timeUncertaintyMinutes,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      timezoneSource: timezoneSource,
      assertedAtUtc: assertedAt.toUtc(),
      importedAtUtc: importedAt?.toUtc(),
      recordedAtUtc: recordedAt.toUtc(),
      status: status,
      lifecycle: lifecycle,
      localConfirmationReceiptDigest: localConfirmationReceiptDigest,
    );
    final digest = _digest(identity);
    final node = MedicationAssertionNode._(
      assertionId: 'med_assert_$digest',
      assertionDigest: digest,
      ownerScopeDigest: ownerScopeDigest,
      intakeId: intakeId,
      medicationId: medicationId,
      productIdentityDigest: productIdentityDigest,
      doseValue: doseValue,
      doseUnit: normalizedDoseUnit,
      route: _optional(route),
      dosageForm: _optional(dosageForm),
      releaseType: _optional(releaseType),
      evidenceClass: evidenceClass,
      identitySchemaVersion: identitySchemaVersion,
      sourceDisplayLabel: normalizedSourceDisplayLabel,
      sourceArtifactId: sourceArtifactId,
      sourceArtifactDigest: sourceArtifactDigest,
      sourceRevisionDigest: sourceRevisionDigest,
      actorIdentityDigest: actorIdentityDigest,
      actorRole: actorRole,
      derivedFromAssertionIds: List<String>.unmodifiable(
        _orderedIds(derivedFromAssertionIds),
      ),
      supersedesAssertionIds: List<String>.unmodifiable(
        _orderedIds(supersedesAssertionIds),
      ),
      retractsAssertionIds: List<String>.unmodifiable(
        _orderedIds(retractsAssertionIds),
      ),
      effectiveStartUtc: effectiveStart?.toUtc(),
      effectiveEndUtc: effectiveEnd?.toUtc(),
      timePrecision: timePrecision,
      timeUncertaintyMinutes: timeUncertaintyMinutes,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      timezoneSource: timezoneSource,
      assertedAtUtc: assertedAt.toUtc(),
      importedAtUtc: importedAt?.toUtc(),
      recordedAtUtc: recordedAt.toUtc(),
      status: status,
      lifecycle: lifecycle,
      localConfirmationReceiptDigest: localConfirmationReceiptDigest,
    );
    node.validate();
    return node;
  }

  factory MedicationAssertionNode.fromJson(Map<String, dynamic> json) {
    const legacyKeys = <String>{
      'schema',
      'schema_version',
      'assertion_id',
      'assertion_digest',
      'owner_scope_digest',
      'intake_id',
      'medication_id',
      'product_identity_digest',
      'dose_value',
      'dose_unit',
      'route',
      'dosage_form',
      'release_type',
      'evidence_class',
      'source_artifact_id',
      'source_artifact_digest',
      'source_revision_digest',
      'actor_identity_digest',
      'actor_role',
      'derived_from_assertion_ids',
      'supersedes_assertion_ids',
      'retracts_assertion_ids',
      'effective_start_utc',
      'effective_end_utc',
      'time_precision',
      'time_uncertainty_minutes',
      'timezone_offset_minutes',
      'timezone_source',
      'asserted_at_utc',
      'imported_at_utc',
      'recorded_at_utc',
      'status',
      'lifecycle',
      'local_confirmation_receipt_digest',
      'meaning_boundary',
    };
    const currentKeys = <String>{
      ...legacyKeys,
      'identity_schema_version',
      'source_display_label',
    };
    final isLegacy =
        json['schema'] == 'parkinsum.medication-assertion/1' &&
        json['schema_version'] == 1 &&
        medicationAssertionAcceptedLegacyVersions.contains(1);
    final isCurrent =
        json['schema'] == 'parkinsum.medication-assertion/2' &&
        json['schema_version'] == medicationAssertionSchemaVersion;
    final exactKeys = isLegacy ? legacyKeys : currentKeys;
    final rawDisplayLabel = isLegacy ? null : json['source_display_label'];
    if (json.keys.toSet().length != exactKeys.length ||
        !json.keys.toSet().containsAll(exactKeys) ||
        (!isLegacy && !isCurrent) ||
        (rawDisplayLabel != null && rawDisplayLabel is! String)) {
      throw const FormatException('Medication assertion shape is invalid.');
    }
    final rawIdentitySchemaVersion = isLegacy
        ? 1
        : json['identity_schema_version'];
    if (rawIdentitySchemaVersion is! int) {
      throw const FormatException(
        'Medication assertion identity version is invalid.',
      );
    }
    final identitySchemaVersion = rawIdentitySchemaVersion;
    if (!<int>{1, 2}.contains(identitySchemaVersion) ||
        (identitySchemaVersion == 1 && rawDisplayLabel != null)) {
      throw const FormatException(
        'Medication assertion identity version is invalid.',
      );
    }
    final node = MedicationAssertionNode._(
      assertionId: json['assertion_id'] as String,
      assertionDigest: json['assertion_digest'] as String,
      ownerScopeDigest: json['owner_scope_digest'] as String,
      intakeId: json['intake_id'] as String,
      medicationId: json['medication_id'] as String,
      productIdentityDigest: json['product_identity_digest'] as String,
      doseValue: (json['dose_value'] as num?)?.toDouble(),
      doseUnit: json['dose_unit'] as String?,
      route: json['route'] as String?,
      dosageForm: json['dosage_form'] as String?,
      releaseType: json['release_type'] as String?,
      evidenceClass: MedicationAssertionEvidenceClass.values.byName(
        json['evidence_class'] as String,
      ),
      identitySchemaVersion: identitySchemaVersion,
      sourceDisplayLabel: rawDisplayLabel as String?,
      sourceArtifactId: json['source_artifact_id'] as String,
      sourceArtifactDigest: json['source_artifact_digest'] as String,
      sourceRevisionDigest: json['source_revision_digest'] as String,
      actorIdentityDigest: json['actor_identity_digest'] as String,
      actorRole: MedicationAssertionActorRole.values.byName(
        json['actor_role'] as String,
      ),
      derivedFromAssertionIds: List<String>.unmodifiable(
        _stringList(json['derived_from_assertion_ids']),
      ),
      supersedesAssertionIds: List<String>.unmodifiable(
        _stringList(json['supersedes_assertion_ids']),
      ),
      retractsAssertionIds: List<String>.unmodifiable(
        _stringList(json['retracts_assertion_ids']),
      ),
      effectiveStartUtc: _date(json['effective_start_utc']),
      effectiveEndUtc: _date(json['effective_end_utc']),
      timePrecision: MedicationAssertionTimePrecision.values.byName(
        json['time_precision'] as String,
      ),
      timeUncertaintyMinutes: json['time_uncertainty_minutes'] as int,
      timezoneOffsetMinutes: json['timezone_offset_minutes'] as int?,
      timezoneSource: MedicationAssertionTimezoneSource.values.byName(
        json['timezone_source'] as String,
      ),
      assertedAtUtc: DateTime.parse(json['asserted_at_utc'] as String),
      importedAtUtc: _date(json['imported_at_utc']),
      recordedAtUtc: DateTime.parse(json['recorded_at_utc'] as String),
      status: MedicationAssertionStatus.values.byName(json['status'] as String),
      lifecycle: MedicationAssertionLifecycle.values.byName(
        json['lifecycle'] as String,
      ),
      localConfirmationReceiptDigest:
          json['local_confirmation_receipt_digest'] as String?,
    );
    node.validate();
    return node;
  }

  void validate() {
    if (!_safeId.hasMatch(intakeId) ||
        !_safeId.hasMatch(medicationId) ||
        !_safeId.hasMatch(sourceArtifactId) ||
        !_digestPattern.hasMatch(assertionDigest) ||
        !_digestPattern.hasMatch(ownerScopeDigest) ||
        !_digestPattern.hasMatch(productIdentityDigest) ||
        !_digestPattern.hasMatch(sourceArtifactDigest) ||
        !_digestPattern.hasMatch(sourceRevisionDigest) ||
        !_digestPattern.hasMatch(actorIdentityDigest) ||
        !<int>{1, 2}.contains(identitySchemaVersion) ||
        (identitySchemaVersion == 1 && sourceDisplayLabel != null) ||
        !_optionalBounded(sourceDisplayLabel, 240) ||
        assertionId != 'med_assert_$assertionDigest' ||
        (doseValue == null) != (doseUnit == null) ||
        (doseValue != null &&
            (!doseValue!.isFinite ||
                doseValue! <= 0 ||
                doseValue! > 1000000)) ||
        (doseUnit != null && !_bounded(doseUnit, 48)) ||
        !_optionalBounded(route, 80) ||
        !_optionalBounded(dosageForm, 80) ||
        !_optionalBounded(releaseType, 80) ||
        !_validIdList(derivedFromAssertionIds) ||
        !_validIdList(supersedesAssertionIds) ||
        !_validIdList(retractsAssertionIds) ||
        timeUncertaintyMinutes < 0 ||
        timeUncertaintyMinutes > 525600 ||
        (timezoneOffsetMinutes != null &&
            (timezoneOffsetMinutes! < -840 || timezoneOffsetMinutes! > 840)) ||
        !assertedAtUtc.isUtc ||
        !recordedAtUtc.isUtc ||
        (importedAtUtc != null && !importedAtUtc!.isUtc) ||
        (effectiveStartUtc != null && !effectiveStartUtc!.isUtc) ||
        (effectiveEndUtc != null && !effectiveEndUtc!.isUtc) ||
        ((effectiveStartUtc == null || effectiveEndUtc == null) &&
            timePrecision != MedicationAssertionTimePrecision.unknown) ||
        (effectiveStartUtc != null &&
            effectiveEndUtc != null &&
            effectiveEndUtc!.isBefore(effectiveStartUtc!)) ||
        (timePrecision == MedicationAssertionTimePrecision.unknown &&
            (effectiveStartUtc != null || effectiveEndUtc != null)) ||
        (localConfirmationReceiptDigest != null &&
            !_digestPattern.hasMatch(localConfirmationReceiptDigest!)) ||
        (evidenceClass ==
                MedicationAssertionEvidenceClass.localUserConfirmation &&
            localConfirmationReceiptDigest == null) ||
        (evidenceClass !=
                MedicationAssertionEvidenceClass.localUserConfirmation &&
            localConfirmationReceiptDigest != null)) {
      throw const FormatException('Medication assertion value is invalid.');
    }
    final expected = _digest(
      _identityPayload(
        identitySchemaVersion: identitySchemaVersion,
        ownerScopeDigest: ownerScopeDigest,
        intakeId: intakeId,
        medicationId: medicationId,
        productIdentityDigest: productIdentityDigest,
        doseValue: doseValue,
        doseUnit: doseUnit,
        route: route,
        dosageForm: dosageForm,
        releaseType: releaseType,
        evidenceClass: evidenceClass,
        sourceDisplayLabel: sourceDisplayLabel,
        sourceArtifactId: sourceArtifactId,
        sourceArtifactDigest: sourceArtifactDigest,
        sourceRevisionDigest: sourceRevisionDigest,
        actorIdentityDigest: actorIdentityDigest,
        actorRole: actorRole,
        derivedFromAssertionIds: derivedFromAssertionIds,
        supersedesAssertionIds: supersedesAssertionIds,
        retractsAssertionIds: retractsAssertionIds,
        effectiveStartUtc: effectiveStartUtc,
        effectiveEndUtc: effectiveEndUtc,
        timePrecision: timePrecision,
        timeUncertaintyMinutes: timeUncertaintyMinutes,
        timezoneOffsetMinutes: timezoneOffsetMinutes,
        timezoneSource: timezoneSource,
        assertedAtUtc: assertedAtUtc,
        importedAtUtc: importedAtUtc,
        recordedAtUtc: recordedAtUtc,
        status: status,
        lifecycle: lifecycle,
        localConfirmationReceiptDigest: localConfirmationReceiptDigest,
      ),
    );
    if (expected != assertionDigest) {
      throw const FormatException('Medication assertion digest is invalid.');
    }
  }

  bool belongsToScope(String ownerScope) =>
      ownerScopeDigest == digestMedicationAssertionIdentity(ownerScope);

  Map<String, Object?> toJson() => <String, Object?>{
    ..._identityPayload(
      identitySchemaVersion: identitySchemaVersion,
      ownerScopeDigest: ownerScopeDigest,
      intakeId: intakeId,
      medicationId: medicationId,
      productIdentityDigest: productIdentityDigest,
      doseValue: doseValue,
      doseUnit: doseUnit,
      route: route,
      dosageForm: dosageForm,
      releaseType: releaseType,
      evidenceClass: evidenceClass,
      sourceDisplayLabel: sourceDisplayLabel,
      sourceArtifactId: sourceArtifactId,
      sourceArtifactDigest: sourceArtifactDigest,
      sourceRevisionDigest: sourceRevisionDigest,
      actorIdentityDigest: actorIdentityDigest,
      actorRole: actorRole,
      derivedFromAssertionIds: derivedFromAssertionIds,
      supersedesAssertionIds: supersedesAssertionIds,
      retractsAssertionIds: retractsAssertionIds,
      effectiveStartUtc: effectiveStartUtc,
      effectiveEndUtc: effectiveEndUtc,
      timePrecision: timePrecision,
      timeUncertaintyMinutes: timeUncertaintyMinutes,
      timezoneOffsetMinutes: timezoneOffsetMinutes,
      timezoneSource: timezoneSource,
      assertedAtUtc: assertedAtUtc,
      importedAtUtc: importedAtUtc,
      recordedAtUtc: recordedAtUtc,
      status: status,
      lifecycle: lifecycle,
      localConfirmationReceiptDigest: localConfirmationReceiptDigest,
    ),
    'schema': 'parkinsum.medication-assertion/2',
    'schema_version': medicationAssertionSchemaVersion,
    'identity_schema_version': identitySchemaVersion,
    'source_display_label': sourceDisplayLabel,
    'assertion_id': assertionId,
    'assertion_digest': assertionDigest,
    'meaning_boundary':
        'Source assertion only. Not prescription validation, adherence proof, clinical reconciliation, or medical advice.',
  };

  static Map<String, Object?> _identityPayload({
    required int identitySchemaVersion,
    required String ownerScopeDigest,
    required String intakeId,
    required String medicationId,
    required String productIdentityDigest,
    required double? doseValue,
    required String? doseUnit,
    required String? route,
    required String? dosageForm,
    required String? releaseType,
    required MedicationAssertionEvidenceClass evidenceClass,
    required String? sourceDisplayLabel,
    required String sourceArtifactId,
    required String sourceArtifactDigest,
    required String sourceRevisionDigest,
    required String actorIdentityDigest,
    required MedicationAssertionActorRole actorRole,
    required List<String> derivedFromAssertionIds,
    required List<String> supersedesAssertionIds,
    required List<String> retractsAssertionIds,
    required DateTime? effectiveStartUtc,
    required DateTime? effectiveEndUtc,
    required MedicationAssertionTimePrecision timePrecision,
    required int timeUncertaintyMinutes,
    required int? timezoneOffsetMinutes,
    required MedicationAssertionTimezoneSource timezoneSource,
    required DateTime assertedAtUtc,
    required DateTime? importedAtUtc,
    required DateTime recordedAtUtc,
    required MedicationAssertionStatus status,
    required MedicationAssertionLifecycle lifecycle,
    required String? localConfirmationReceiptDigest,
  }) => <String, Object?>{
    'schema': 'parkinsum.medication-assertion/$identitySchemaVersion',
    'schema_version': identitySchemaVersion,
    'owner_scope_digest': ownerScopeDigest,
    'intake_id': intakeId,
    'medication_id': medicationId,
    'product_identity_digest': productIdentityDigest,
    'dose_value': doseValue,
    'dose_unit': doseUnit,
    'route': route,
    'dosage_form': dosageForm,
    'release_type': releaseType,
    'evidence_class': evidenceClass.name,
    if (identitySchemaVersion >= 2) 'source_display_label': sourceDisplayLabel,
    'source_artifact_id': sourceArtifactId,
    'source_artifact_digest': sourceArtifactDigest,
    'source_revision_digest': sourceRevisionDigest,
    'actor_identity_digest': actorIdentityDigest,
    'actor_role': actorRole.name,
    'derived_from_assertion_ids': _orderedIds(derivedFromAssertionIds),
    'supersedes_assertion_ids': _orderedIds(supersedesAssertionIds),
    'retracts_assertion_ids': _orderedIds(retractsAssertionIds),
    'effective_start_utc': effectiveStartUtc?.toUtc().toIso8601String(),
    'effective_end_utc': effectiveEndUtc?.toUtc().toIso8601String(),
    'time_precision': timePrecision.name,
    'time_uncertainty_minutes': timeUncertaintyMinutes,
    'timezone_offset_minutes': timezoneOffsetMinutes,
    'timezone_source': timezoneSource.name,
    'asserted_at_utc': assertedAtUtc.toUtc().toIso8601String(),
    'imported_at_utc': importedAtUtc?.toUtc().toIso8601String(),
    'recorded_at_utc': recordedAtUtc.toUtc().toIso8601String(),
    'status': status.name,
    'lifecycle': lifecycle.name,
    'local_confirmation_receipt_digest': localConfirmationReceiptDigest,
  };
}

/// Append-only user acknowledgement of one exact graph revision.
///
/// Acknowledging a conflict never rewrites a claim and never makes a blocking
/// conflict result-safe. It only records what was shown and what the user chose
/// to do next.
final class MedicationReconciliationDecision {
  MedicationReconciliationDecision._({
    required this.decisionId,
    required this.decisionDigest,
    required this.ownerScopeDigest,
    required this.intakeId,
    required this.graphDigest,
    required this.acknowledgedAssertionIds,
    required this.acknowledgedBlockingEdgeIds,
    required this.resolution,
    required this.reasonCode,
    required this.decidedAtUtc,
  });

  final String decisionId;
  final String decisionDigest;
  final String ownerScopeDigest;
  final String intakeId;
  final String graphDigest;
  final List<String> acknowledgedAssertionIds;
  final List<String> acknowledgedBlockingEdgeIds;
  final MedicationReconciliationResolution resolution;
  final String reasonCode;
  final DateTime decidedAtUtc;

  factory MedicationReconciliationDecision.create({
    required String ownerScope,
    required String intakeId,
    required String graphDigest,
    required List<String> acknowledgedAssertionIds,
    required List<String> acknowledgedBlockingEdgeIds,
    required MedicationReconciliationResolution resolution,
    required String reasonCode,
    required DateTime decidedAt,
  }) {
    final ownerScopeDigest = digestMedicationAssertionIdentity(ownerScope);
    final identity = _identityPayload(
      ownerScopeDigest: ownerScopeDigest,
      intakeId: intakeId,
      graphDigest: graphDigest,
      acknowledgedAssertionIds: _orderedIds(acknowledgedAssertionIds),
      acknowledgedBlockingEdgeIds: _orderedIds(acknowledgedBlockingEdgeIds),
      resolution: resolution,
      reasonCode: reasonCode,
      decidedAtUtc: decidedAt.toUtc(),
    );
    final digest = _digest(identity);
    final decision = MedicationReconciliationDecision._(
      decisionId: 'med_reconcile_$digest',
      decisionDigest: digest,
      ownerScopeDigest: ownerScopeDigest,
      intakeId: intakeId,
      graphDigest: graphDigest,
      acknowledgedAssertionIds: List<String>.unmodifiable(
        _orderedIds(acknowledgedAssertionIds),
      ),
      acknowledgedBlockingEdgeIds: List<String>.unmodifiable(
        _orderedIds(acknowledgedBlockingEdgeIds),
      ),
      resolution: resolution,
      reasonCode: reasonCode,
      decidedAtUtc: decidedAt.toUtc(),
    );
    decision.validate();
    return decision;
  }

  factory MedicationReconciliationDecision.fromJson(Map<String, dynamic> json) {
    const exactKeys = <String>{
      'schema',
      'schema_version',
      'decision_id',
      'decision_digest',
      'owner_scope_digest',
      'intake_id',
      'graph_digest',
      'acknowledged_assertion_ids',
      'acknowledged_blocking_edge_ids',
      'resolution',
      'reason_code',
      'decided_at_utc',
      'meaning_boundary',
    };
    if (json.keys.toSet().length != exactKeys.length ||
        !json.keys.toSet().containsAll(exactKeys) ||
        json['schema'] != 'parkinsum.medication-reconciliation-decision/1' ||
        json['schema_version'] !=
            medicationReconciliationDecisionSchemaVersion) {
      throw const FormatException('Medication decision shape is invalid.');
    }
    final decision = MedicationReconciliationDecision._(
      decisionId: json['decision_id'] as String,
      decisionDigest: json['decision_digest'] as String,
      ownerScopeDigest: json['owner_scope_digest'] as String,
      intakeId: json['intake_id'] as String,
      graphDigest: json['graph_digest'] as String,
      acknowledgedAssertionIds: List<String>.unmodifiable(
        _stringList(json['acknowledged_assertion_ids']),
      ),
      acknowledgedBlockingEdgeIds: List<String>.unmodifiable(
        _stringList(json['acknowledged_blocking_edge_ids']),
      ),
      resolution: MedicationReconciliationResolution.values.byName(
        json['resolution'] as String,
      ),
      reasonCode: json['reason_code'] as String,
      decidedAtUtc: DateTime.parse(json['decided_at_utc'] as String),
    );
    decision.validate();
    return decision;
  }

  void validate() {
    if (!_safeId.hasMatch(intakeId) ||
        !_safeId.hasMatch(reasonCode) ||
        !_digestPattern.hasMatch(decisionDigest) ||
        !_digestPattern.hasMatch(ownerScopeDigest) ||
        !_digestPattern.hasMatch(graphDigest) ||
        decisionId != 'med_reconcile_$decisionDigest' ||
        !_validIdList(acknowledgedAssertionIds) ||
        !_validIdList(acknowledgedBlockingEdgeIds) ||
        !decidedAtUtc.isUtc) {
      throw const FormatException('Medication decision value is invalid.');
    }
    final expected = _digest(
      _identityPayload(
        ownerScopeDigest: ownerScopeDigest,
        intakeId: intakeId,
        graphDigest: graphDigest,
        acknowledgedAssertionIds: acknowledgedAssertionIds,
        acknowledgedBlockingEdgeIds: acknowledgedBlockingEdgeIds,
        resolution: resolution,
        reasonCode: reasonCode,
        decidedAtUtc: decidedAtUtc,
      ),
    );
    if (expected != decisionDigest) {
      throw const FormatException('Medication decision digest is invalid.');
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    ..._identityPayload(
      ownerScopeDigest: ownerScopeDigest,
      intakeId: intakeId,
      graphDigest: graphDigest,
      acknowledgedAssertionIds: acknowledgedAssertionIds,
      acknowledgedBlockingEdgeIds: acknowledgedBlockingEdgeIds,
      resolution: resolution,
      reasonCode: reasonCode,
      decidedAtUtc: decidedAtUtc,
    ),
    'decision_id': decisionId,
    'decision_digest': decisionDigest,
    'meaning_boundary':
        'Acknowledgement only. It does not erase evidence, infer adherence, or constitute clinical reconciliation.',
  };

  static Map<String, Object?> _identityPayload({
    required String ownerScopeDigest,
    required String intakeId,
    required String graphDigest,
    required List<String> acknowledgedAssertionIds,
    required List<String> acknowledgedBlockingEdgeIds,
    required MedicationReconciliationResolution resolution,
    required String reasonCode,
    required DateTime decidedAtUtc,
  }) => <String, Object?>{
    'schema': 'parkinsum.medication-reconciliation-decision/1',
    'schema_version': medicationReconciliationDecisionSchemaVersion,
    'owner_scope_digest': ownerScopeDigest,
    'intake_id': intakeId,
    'graph_digest': graphDigest,
    'acknowledged_assertion_ids': _orderedIds(acknowledgedAssertionIds),
    'acknowledged_blocking_edge_ids': _orderedIds(acknowledgedBlockingEdgeIds),
    'resolution': resolution.name,
    'reason_code': reasonCode,
    'decided_at_utc': decidedAtUtc.toUtc().toIso8601String(),
  };
}

String digestMedicationAssertionIdentity(String value) =>
    AdministrationDoseConfirmationReceipt.digestAccountScope(value);

String medicationAssertionSnapshotDigest(Object? value) => _digest(value);

final RegExp _safeId = RegExp(r'^[A-Za-z0-9._:-]{1,220}$');
final RegExp _digestPattern = RegExp(r'^[a-f0-9]{64}$');

String? _optional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.parse(value as String);

List<String> _stringList(Object? value) {
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Expected a string list.');
  }
  return List<String>.from(value);
}

List<String> _orderedIds(Iterable<String> values) {
  final result = values.toSet().toList()..sort();
  return result;
}

bool _validIdList(List<String> values) =>
    values.length <= 64 &&
    values.toSet().length == values.length &&
    values.every(_safeId.hasMatch) &&
    _orderedIds(values).join('\u0000') == values.join('\u0000');

bool _bounded(String? value, int max) =>
    value != null && value.isNotEmpty && value.length <= max;

bool _optionalBounded(String? value, int max) =>
    value == null || _bounded(value, max);

String _digest(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) {
  if (value == null || value is num || value is bool || value is String) {
    return jsonEncode(value);
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map) {
    final keys = value.keys.map((key) => key.toString()).toList()..sort();
    return '{${keys.map((key) => '${jsonEncode(key)}:${_canonicalJson(value[key])}').join(',')}}';
  }
  throw ArgumentError.value(value, 'value', 'Unsupported canonical value.');
}
