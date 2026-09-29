import 'dart:convert';

import 'package:crypto/crypto.dart';

const int administrationDoseConfirmationSchemaVersion = 1;
const String administrationDoseConfirmationAbsentRevisionDigest =
    '5f241252bd523e3a76ad6b4c740ed6d0c3289a72edb9942de2c2453c0f6b78af';

enum AdministrationDoseAssertionSource { typed, packageDerived, imported }

/// Immutable local evidence that a user explicitly confirmed one parsed
/// administration-dose quantity for one exact Intake revision.
///
/// This is a ParkinSUM audit receipt, not a prescription, MedicationStatement,
/// MedicationAdministration, clinician signature, or proof that a dose was
/// taken. The account scope is stored only as a one-way digest so portable
/// records do not disclose an authentication identifier.
final class AdministrationDoseConfirmationReceipt {
  AdministrationDoseConfirmationReceipt._({
    required this.receiptId,
    required this.receiptDigest,
    required this.operationId,
    required this.ownerScopeDigest,
    required this.intakeId,
    required this.expectedRecordRevisionDigest,
    required this.recordBindingDigest,
    required this.medicationId,
    required this.productSnapshotDigest,
    required this.rawExpression,
    required this.parsedExpression,
    required this.grammarId,
    required this.grammarVersion,
    required this.grammarDigest,
    required this.unitSystem,
    required this.unitSystemVersion,
    required this.structuredValue,
    required this.structuredUnit,
    required this.administrationAtUtc,
    required this.confirmedAtUtc,
    required this.assertionSource,
    required this.confirmationAction,
    required this.uiContractVersion,
  });

  final String receiptId;
  final String receiptDigest;
  final String operationId;
  final String ownerScopeDigest;
  final String intakeId;
  final String expectedRecordRevisionDigest;
  final String recordBindingDigest;
  final String medicationId;
  final String productSnapshotDigest;
  final String rawExpression;
  final Map<String, Object?> parsedExpression;
  final String grammarId;
  final int grammarVersion;
  final String grammarDigest;
  final String unitSystem;
  final String unitSystemVersion;
  final double structuredValue;
  final String structuredUnit;
  final DateTime administrationAtUtc;
  final DateTime confirmedAtUtc;
  final AdministrationDoseAssertionSource assertionSource;
  final String confirmationAction;
  final String uiContractVersion;

  factory AdministrationDoseConfirmationReceipt.create({
    required String operationId,
    required String ownerScope,
    required String intakeId,
    required String expectedRecordRevisionDigest,
    required String recordBindingDigest,
    required String medicationId,
    required String productSnapshotDigest,
    required String rawExpression,
    required Map<String, Object?> parsedExpression,
    required String grammarId,
    required int grammarVersion,
    required String grammarDigest,
    required String unitSystem,
    required String unitSystemVersion,
    required double structuredValue,
    required String structuredUnit,
    required DateTime administrationAt,
    required DateTime confirmedAt,
    required AdministrationDoseAssertionSource assertionSource,
    required String confirmationAction,
    required String uiContractVersion,
  }) {
    final ownerScopeDigest = digestAccountScope(ownerScope);
    final identity = _identityPayload(
      operationId: operationId,
      ownerScopeDigest: ownerScopeDigest,
      intakeId: intakeId,
      expectedRecordRevisionDigest: expectedRecordRevisionDigest,
      recordBindingDigest: recordBindingDigest,
      medicationId: medicationId,
      productSnapshotDigest: productSnapshotDigest,
      rawExpression: rawExpression,
      parsedExpression: parsedExpression,
      grammarId: grammarId,
      grammarVersion: grammarVersion,
      grammarDigest: grammarDigest,
      unitSystem: unitSystem,
      unitSystemVersion: unitSystemVersion,
      structuredValue: structuredValue,
      structuredUnit: structuredUnit,
      administrationAtUtc: administrationAt.toUtc(),
      confirmedAtUtc: confirmedAt.toUtc(),
      assertionSource: assertionSource,
      confirmationAction: confirmationAction,
      uiContractVersion: uiContractVersion,
    );
    final digest = _sha256(_canonicalJson(identity));
    final receipt = AdministrationDoseConfirmationReceipt._(
      receiptId: 'dose_receipt_$digest',
      receiptDigest: digest,
      operationId: operationId,
      ownerScopeDigest: ownerScopeDigest,
      intakeId: intakeId,
      expectedRecordRevisionDigest: expectedRecordRevisionDigest,
      recordBindingDigest: recordBindingDigest,
      medicationId: medicationId,
      productSnapshotDigest: productSnapshotDigest,
      rawExpression: rawExpression,
      parsedExpression: _immutableMap(parsedExpression),
      grammarId: grammarId,
      grammarVersion: grammarVersion,
      grammarDigest: grammarDigest,
      unitSystem: unitSystem,
      unitSystemVersion: unitSystemVersion,
      structuredValue: structuredValue,
      structuredUnit: structuredUnit,
      administrationAtUtc: administrationAt.toUtc(),
      confirmedAtUtc: confirmedAt.toUtc(),
      assertionSource: assertionSource,
      confirmationAction: confirmationAction,
      uiContractVersion: uiContractVersion,
    );
    receipt.validate();
    return receipt;
  }

  factory AdministrationDoseConfirmationReceipt.fromJson(
    Map<String, dynamic> json,
  ) {
    const requiredKeys = <String>{
      'schema_version',
      'receipt_id',
      'receipt_digest',
      'operation_id',
      'owner_scope_digest',
      'intake_id',
      'expected_record_revision_digest',
      'record_binding_digest',
      'medication_id',
      'product_snapshot_digest',
      'raw_expression',
      'parsed_expression',
      'grammar_id',
      'grammar_version',
      'grammar_digest',
      'unit_system',
      'unit_system_version',
      'structured_value',
      'structured_unit',
      'administration_at_utc',
      'confirmed_at_utc',
      'assertion_source',
      'confirmation_action',
      'ui_contract_version',
      'meaning_boundary',
    };
    if (json.keys.toSet().length != requiredKeys.length ||
        !json.keys.toSet().containsAll(requiredKeys) ||
        json['schema_version'] != administrationDoseConfirmationSchemaVersion) {
      throw const FormatException(
        'Dose confirmation receipt shape is invalid.',
      );
    }
    final parsedRaw = json['parsed_expression'];
    if (parsedRaw is! Map) {
      throw const FormatException('Dose confirmation expression is invalid.');
    }
    final AdministrationDoseAssertionSource source;
    final DateTime administrationAt;
    final DateTime confirmedAt;
    try {
      source = AdministrationDoseAssertionSource.values.byName(
        json['assertion_source'] as String,
      );
      administrationAt = DateTime.parse(
        json['administration_at_utc'] as String,
      );
      confirmedAt = DateTime.parse(json['confirmed_at_utc'] as String);
    } on Object {
      throw const FormatException('Dose confirmation enum or time is invalid.');
    }
    final value = json['structured_value'];
    if (value is! num) {
      throw const FormatException('Dose confirmation value is invalid.');
    }
    final receipt = AdministrationDoseConfirmationReceipt._(
      receiptId: json['receipt_id'] as String,
      receiptDigest: json['receipt_digest'] as String,
      operationId: json['operation_id'] as String,
      ownerScopeDigest: json['owner_scope_digest'] as String,
      intakeId: json['intake_id'] as String,
      expectedRecordRevisionDigest:
          json['expected_record_revision_digest'] as String,
      recordBindingDigest: json['record_binding_digest'] as String,
      medicationId: json['medication_id'] as String,
      productSnapshotDigest: json['product_snapshot_digest'] as String,
      rawExpression: json['raw_expression'] as String,
      parsedExpression: _immutableMap(Map<String, Object?>.from(parsedRaw)),
      grammarId: json['grammar_id'] as String,
      grammarVersion: json['grammar_version'] as int,
      grammarDigest: json['grammar_digest'] as String,
      unitSystem: json['unit_system'] as String,
      unitSystemVersion: json['unit_system_version'] as String,
      structuredValue: value.toDouble(),
      structuredUnit: json['structured_unit'] as String,
      administrationAtUtc: administrationAt,
      confirmedAtUtc: confirmedAt,
      assertionSource: source,
      confirmationAction: json['confirmation_action'] as String,
      uiContractVersion: json['ui_contract_version'] as String,
    );
    receipt.validate();
    return receipt;
  }

  void validate() {
    final digest = RegExp(r'^[a-f0-9]{64}$');
    final safeId = RegExp(r'^[A-Za-z0-9._:-]{1,180}$');
    if (!safeId.hasMatch(operationId) ||
        !safeId.hasMatch(intakeId) ||
        !safeId.hasMatch(medicationId) ||
        !safeId.hasMatch(grammarId) ||
        !safeId.hasMatch(unitSystem) ||
        !safeId.hasMatch(unitSystemVersion) ||
        !safeId.hasMatch(confirmationAction) ||
        !safeId.hasMatch(uiContractVersion) ||
        !digest.hasMatch(receiptDigest) ||
        !digest.hasMatch(ownerScopeDigest) ||
        !digest.hasMatch(expectedRecordRevisionDigest) ||
        !digest.hasMatch(recordBindingDigest) ||
        !digest.hasMatch(productSnapshotDigest) ||
        !digest.hasMatch(grammarDigest) ||
        receiptId != 'dose_receipt_$receiptDigest' ||
        grammarVersion < 1 ||
        !structuredValue.isFinite ||
        structuredValue <= 0 ||
        structuredUnit.trim().isEmpty ||
        rawExpression.isEmpty ||
        rawExpression.length > 256 ||
        !administrationAtUtc.isUtc ||
        !confirmedAtUtc.isUtc ||
        administrationAtUtc.year < 2020 ||
        confirmedAtUtc.year < 2020) {
      throw const FormatException(
        'Dose confirmation receipt values are invalid.',
      );
    }
    final expected = _sha256(
      _canonicalJson(
        _identityPayload(
          operationId: operationId,
          ownerScopeDigest: ownerScopeDigest,
          intakeId: intakeId,
          expectedRecordRevisionDigest: expectedRecordRevisionDigest,
          recordBindingDigest: recordBindingDigest,
          medicationId: medicationId,
          productSnapshotDigest: productSnapshotDigest,
          rawExpression: rawExpression,
          parsedExpression: parsedExpression,
          grammarId: grammarId,
          grammarVersion: grammarVersion,
          grammarDigest: grammarDigest,
          unitSystem: unitSystem,
          unitSystemVersion: unitSystemVersion,
          structuredValue: structuredValue,
          structuredUnit: structuredUnit,
          administrationAtUtc: administrationAtUtc,
          confirmedAtUtc: confirmedAtUtc,
          assertionSource: assertionSource,
          confirmationAction: confirmationAction,
          uiContractVersion: uiContractVersion,
        ),
      ),
    );
    if (expected != receiptDigest) {
      throw const FormatException('Dose confirmation receipt digest mismatch.');
    }
  }

  bool belongsToScope(String ownerScope) =>
      ownerScopeDigest == digestAccountScope(ownerScope);

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_version': administrationDoseConfirmationSchemaVersion,
    'receipt_id': receiptId,
    'receipt_digest': receiptDigest,
    'operation_id': operationId,
    'owner_scope_digest': ownerScopeDigest,
    'intake_id': intakeId,
    'expected_record_revision_digest': expectedRecordRevisionDigest,
    'record_binding_digest': recordBindingDigest,
    'medication_id': medicationId,
    'product_snapshot_digest': productSnapshotDigest,
    'raw_expression': rawExpression,
    'parsed_expression': parsedExpression,
    'grammar_id': grammarId,
    'grammar_version': grammarVersion,
    'grammar_digest': grammarDigest,
    'unit_system': unitSystem,
    'unit_system_version': unitSystemVersion,
    'structured_value': structuredValue,
    'structured_unit': structuredUnit,
    'administration_at_utc': administrationAtUtc.toIso8601String(),
    'confirmed_at_utc': confirmedAtUtc.toIso8601String(),
    'assertion_source': assertionSource.name,
    'confirmation_action': confirmationAction,
    'ui_contract_version': uiContractVersion,
    'meaning_boundary':
        'User-confirmed local assertion only; not a prescription, clinician '
        'verification, digital signature, or proof of administration.',
  };

  static String digestAccountScope(String ownerScope) {
    final normalized = ownerScope.trim();
    if (normalized.isEmpty || normalized.length > 320) {
      throw const FormatException('Dose confirmation owner scope is invalid.');
    }
    return _sha256('parkinsum-dose-owner-scope/1\n$normalized');
  }

  static String digestSnapshot(Object? snapshot) =>
      _sha256(_canonicalJson(snapshot));

  static Map<String, Object?> _identityPayload({
    required String operationId,
    required String ownerScopeDigest,
    required String intakeId,
    required String expectedRecordRevisionDigest,
    required String recordBindingDigest,
    required String medicationId,
    required String productSnapshotDigest,
    required String rawExpression,
    required Map<String, Object?> parsedExpression,
    required String grammarId,
    required int grammarVersion,
    required String grammarDigest,
    required String unitSystem,
    required String unitSystemVersion,
    required double structuredValue,
    required String structuredUnit,
    required DateTime administrationAtUtc,
    required DateTime confirmedAtUtc,
    required AdministrationDoseAssertionSource assertionSource,
    required String confirmationAction,
    required String uiContractVersion,
  }) => <String, Object?>{
    'schema_version': administrationDoseConfirmationSchemaVersion,
    'operation_id': operationId,
    'owner_scope_digest': ownerScopeDigest,
    'intake_id': intakeId,
    'expected_record_revision_digest': expectedRecordRevisionDigest,
    'record_binding_digest': recordBindingDigest,
    'medication_id': medicationId,
    'product_snapshot_digest': productSnapshotDigest,
    'raw_expression': rawExpression,
    'parsed_expression': parsedExpression,
    'grammar_id': grammarId,
    'grammar_version': grammarVersion,
    'grammar_digest': grammarDigest,
    'unit_system': unitSystem,
    'unit_system_version': unitSystemVersion,
    'structured_value': structuredValue,
    'structured_unit': structuredUnit,
    'administration_at_utc': administrationAtUtc.toIso8601String(),
    'confirmed_at_utc': confirmedAtUtc.toIso8601String(),
    'assertion_source': assertionSource.name,
    'confirmation_action': confirmationAction,
    'ui_contract_version': uiContractVersion,
  };
}

String administrationDoseRecordBindingDigest({
  required String intakeId,
  required String medicationId,
  required DateTime takenAt,
  required String dosageNote,
  required double? doseAmount,
  required String? doseUnit,
  required String? dosageForm,
  required String? route,
  required String? releaseType,
  required Map<String, Object?>? productSelection,
}) => AdministrationDoseConfirmationReceipt.digestSnapshot(<String, Object?>{
  'schema': 'parkinsum.administration-dose-record-binding/1',
  'intake_id': intakeId,
  'medication_id': medicationId,
  'taken_at_utc': takenAt.toUtc().toIso8601String(),
  'raw_expression': dosageNote,
  'structured_value': doseAmount,
  'structured_unit': doseUnit,
  'dosage_form': dosageForm,
  'route': route,
  'release_type': releaseType,
  'product_selection': productSelection,
});

Map<String, Object?> _immutableMap(Map<String, Object?> input) =>
    Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final entry in input.entries)
        entry.key: _immutableValue(entry.value),
    });

Object? _immutableValue(Object? value) {
  if (value is Map) {
    return _immutableMap(Map<String, Object?>.from(value));
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_immutableValue));
  }
  return value;
}

String _canonicalJson(Object? value) {
  Object? normalize(Object? current) {
    if (current == null || current is String || current is bool) return current;
    if (current is num) {
      if (!current.isFinite) {
        throw const FormatException(
          'Non-finite value cannot be canonicalized.',
        );
      }
      return current;
    }
    if (current is List) return current.map(normalize).toList(growable: false);
    if (current is Map) {
      final entries = current.entries.toList()
        ..sort((left, right) => '${left.key}'.compareTo('${right.key}'));
      return <String, Object?>{
        for (final entry in entries) '${entry.key}': normalize(entry.value),
      };
    }
    throw FormatException(
      'Unsupported canonical value: ${current.runtimeType}',
    );
  }

  return jsonEncode(normalize(value));
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();
