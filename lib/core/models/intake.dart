import 'administration_dose_confirmation.dart';
import 'medication_product_pack.dart';
import '../../domain/entities/medication_assertion_reconciliation.dart';

enum IntakeDoseConfirmationIntegrity { absent, valid, invalid }

/// Intake：一次“用药/补充剂摄入”记录
class Intake {
  static const int currentSchemaVersion = 3;
  final String id;
  final String drugId;
  final DateTime takenAt;
  final String dosageNote;
  final double? doseAmount;
  final String? doseUnit;
  final String? dosageForm;
  final String? route;
  final String? releaseType;
  final MedicationProductSelection? productSelection;
  final AdministrationDoseConfirmationReceipt? doseConfirmation;
  final Map<String, Object?>? invalidDoseConfirmationEvidence;
  final List<MedicationAssertionNode> medicationAssertions;
  final List<MedicationReconciliationDecision>
  medicationReconciliationDecisions;
  final Map<String, Object?>? invalidMedicationReconciliationEvidence;

  Intake({
    required this.id,
    required this.drugId,
    required this.takenAt,
    required this.dosageNote,
    this.doseAmount,
    this.doseUnit,
    this.dosageForm,
    this.route,
    this.releaseType,
    this.productSelection,
    this.doseConfirmation,
    Map<String, Object?>? invalidDoseConfirmationEvidence,
    List<MedicationAssertionNode> medicationAssertions =
        const <MedicationAssertionNode>[],
    List<MedicationReconciliationDecision> medicationReconciliationDecisions =
        const <MedicationReconciliationDecision>[],
    Map<String, Object?>? invalidMedicationReconciliationEvidence,
  }) : invalidDoseConfirmationEvidence = invalidDoseConfirmationEvidence == null
           ? null
           : Map<String, Object?>.unmodifiable(
               Map<String, Object?>.from(invalidDoseConfirmationEvidence),
             ),
       medicationAssertions = List<MedicationAssertionNode>.unmodifiable(
         medicationAssertions,
       ),
       medicationReconciliationDecisions =
           List<MedicationReconciliationDecision>.unmodifiable(
             medicationReconciliationDecisions,
           ),
       invalidMedicationReconciliationEvidence =
           invalidMedicationReconciliationEvidence == null
           ? null
           : Map<String, Object?>.unmodifiable(
               Map<String, Object?>.from(
                 invalidMedicationReconciliationEvidence,
               ),
             ) {
    if (doseConfirmation != null && invalidDoseConfirmationEvidence != null) {
      throw ArgumentError(
        'An intake cannot carry valid and invalid dose confirmation evidence.',
      );
    }
    if (medicationAssertions.length > 64 ||
        medicationReconciliationDecisions.length > 128) {
      throw ArgumentError('Medication reconciliation history is oversized.');
    }
    if (invalidMedicationReconciliationEvidence != null &&
        (medicationAssertions.isNotEmpty ||
            medicationReconciliationDecisions.isNotEmpty)) {
      throw ArgumentError(
        'An intake cannot carry valid and invalid medication reconciliation evidence.',
      );
    }
  }

  IntakeDoseConfirmationIntegrity get doseConfirmationIntegrity =>
      doseConfirmation != null
      ? IntakeDoseConfirmationIntegrity.valid
      : invalidDoseConfirmationEvidence != null
      ? IntakeDoseConfirmationIntegrity.invalid
      : IntakeDoseConfirmationIntegrity.absent;

  /// User-facing dose text with the free-text source taking precedence.
  ///
  /// Legacy records contain only [dosageNote]. New records also persist an
  /// explicit amount/unit pair when one was unambiguously present, allowing
  /// computation without making old data disappear from the timeline.
  String get doseDisplayText {
    final note = dosageNote.trim();
    if (note.isNotEmpty) return note;
    if (doseAmount == null || doseUnit == null || doseUnit!.trim().isEmpty) {
      return '';
    }
    final amount = doseAmount! % 1 == 0
        ? doseAmount!.toInt().toString()
        : doseAmount!.toString();
    return '$amount ${doseUnit!.trim()}';
  }

  Intake copyWith({
    String? id,
    String? drugId,
    DateTime? takenAt,
    String? dosageNote,
    double? doseAmount,
    String? doseUnit,
    String? dosageForm,
    String? route,
    String? releaseType,
    MedicationProductSelection? productSelection,
    List<MedicationAssertionNode>? medicationAssertions,
    List<MedicationReconciliationDecision>? medicationReconciliationDecisions,
  }) {
    return Intake(
      id: id ?? this.id,
      drugId: drugId ?? this.drugId,
      takenAt: takenAt ?? this.takenAt,
      dosageNote: dosageNote ?? this.dosageNote,
      doseAmount: doseAmount ?? this.doseAmount,
      doseUnit: doseUnit ?? this.doseUnit,
      dosageForm: dosageForm ?? this.dosageForm,
      route: route ?? this.route,
      releaseType: releaseType ?? this.releaseType,
      productSelection: productSelection ?? this.productSelection,
      doseConfirmation: doseConfirmation,
      invalidDoseConfirmationEvidence: invalidDoseConfirmationEvidence,
      medicationAssertions: medicationAssertions ?? this.medicationAssertions,
      medicationReconciliationDecisions:
          medicationReconciliationDecisions ??
          this.medicationReconciliationDecisions,
      invalidMedicationReconciliationEvidence:
          invalidMedicationReconciliationEvidence,
    );
  }

  Intake withDoseConfirmation(AdministrationDoseConfirmationReceipt receipt) =>
      Intake(
        id: id,
        drugId: drugId,
        takenAt: takenAt,
        dosageNote: dosageNote,
        doseAmount: doseAmount,
        doseUnit: doseUnit,
        dosageForm: dosageForm,
        route: route,
        releaseType: releaseType,
        productSelection: productSelection,
        doseConfirmation: receipt,
        medicationAssertions: medicationAssertions,
        medicationReconciliationDecisions: medicationReconciliationDecisions,
        invalidMedicationReconciliationEvidence:
            invalidMedicationReconciliationEvidence,
      );

  Intake withMedicationReconciliation({
    required List<MedicationAssertionNode> assertions,
    required List<MedicationReconciliationDecision> decisions,
  }) => Intake(
    id: id,
    drugId: drugId,
    takenAt: takenAt,
    dosageNote: dosageNote,
    doseAmount: doseAmount,
    doseUnit: doseUnit,
    dosageForm: dosageForm,
    route: route,
    releaseType: releaseType,
    productSelection: productSelection,
    doseConfirmation: doseConfirmation,
    invalidDoseConfirmationEvidence: invalidDoseConfirmationEvidence,
    medicationAssertions: assertions,
    medicationReconciliationDecisions: decisions,
  );

  Intake withoutDoseConfirmation({bool clearStructuredDose = false}) => Intake(
    id: id,
    drugId: drugId,
    takenAt: takenAt,
    dosageNote: dosageNote,
    doseAmount: clearStructuredDose ? null : doseAmount,
    doseUnit: clearStructuredDose ? null : doseUnit,
    dosageForm: dosageForm,
    route: route,
    releaseType: releaseType,
    productSelection: productSelection,
    medicationAssertions: medicationAssertions,
    medicationReconciliationDecisions: medicationReconciliationDecisions,
    invalidMedicationReconciliationEvidence:
        invalidMedicationReconciliationEvidence,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': currentSchemaVersion,
    'id': id,
    'drugId': drugId,
    'takenAt': takenAt.toIso8601String(),
    'dosageNote': dosageNote,
    if (doseAmount != null) 'doseAmount': doseAmount,
    if (doseUnit != null) 'doseUnit': doseUnit,
    if (dosageForm != null) 'dosageForm': dosageForm,
    if (route != null) 'route': route,
    if (releaseType != null) 'releaseType': releaseType,
    if (productSelection != null)
      'productSelection': productSelection!.toJson(),
    if (doseConfirmation != null)
      'doseConfirmation': doseConfirmation!.toJson()
    else if (invalidDoseConfirmationEvidence != null)
      'doseConfirmation': invalidDoseConfirmationEvidence,
    if (invalidMedicationReconciliationEvidence != null)
      'medicationReconciliation': invalidMedicationReconciliationEvidence
    else if (medicationAssertions.isNotEmpty ||
        medicationReconciliationDecisions.isNotEmpty)
      'medicationReconciliation': <String, Object?>{
        'schema': 'parkinsum.medication-reconciliation-envelope/1',
        'schemaVersion': 1,
        'assertions': medicationAssertions
            .map((assertion) => assertion.toJson())
            .toList(growable: false),
        'decisions': medicationReconciliationDecisions
            .map((decision) => decision.toJson())
            .toList(growable: false),
        'meaningBoundary':
            'Source-conflict history only; not proof of administration, adherence, or clinical reconciliation.',
      },
  };

  static Intake fromJson(Map<String, dynamic> json) {
    final confirmation = _doseConfirmationFromJson(json['doseConfirmation']);
    final reconciliation = _medicationReconciliationFromJson(
      json['medicationReconciliation'],
    );
    return Intake(
      id: json['id'] as String,
      drugId: json['drugId'] as String,
      takenAt: DateTime.parse(json['takenAt'] as String),
      dosageNote: (json['dosageNote'] as String?) ?? '',
      doseAmount: _positiveDouble(json['doseAmount']),
      doseUnit: _optionalString(json['doseUnit']),
      dosageForm: _optionalString(json['dosageForm']),
      route: _optionalString(json['route']),
      releaseType: _optionalString(json['releaseType']),
      productSelection: MedicationProductSelection.fromJson(
        json['productSelection'],
      ),
      doseConfirmation: confirmation.receipt,
      invalidDoseConfirmationEvidence: confirmation.invalidEvidence,
      medicationAssertions: reconciliation.assertions,
      medicationReconciliationDecisions: reconciliation.decisions,
      invalidMedicationReconciliationEvidence: reconciliation.invalidEvidence,
    );
  }

  static ({
    List<MedicationAssertionNode> assertions,
    List<MedicationReconciliationDecision> decisions,
    Map<String, Object?>? invalidEvidence,
  })
  _medicationReconciliationFromJson(Object? raw) {
    if (raw == null) {
      return (
        assertions: const <MedicationAssertionNode>[],
        decisions: const <MedicationReconciliationDecision>[],
        invalidEvidence: null,
      );
    }
    if (raw is! Map) {
      return (
        assertions: const <MedicationAssertionNode>[],
        decisions: const <MedicationReconciliationDecision>[],
        invalidEvidence: <String, Object?>{
          'invalid_payload_type': raw.runtimeType.toString(),
        },
      );
    }
    final json = Map<String, dynamic>.from(raw);
    try {
      const exactKeys = <String>{
        'schema',
        'schemaVersion',
        'assertions',
        'decisions',
        'meaningBoundary',
      };
      if (json.keys.toSet().length != exactKeys.length ||
          !json.keys.toSet().containsAll(exactKeys) ||
          json['schema'] != 'parkinsum.medication-reconciliation-envelope/1' ||
          json['schemaVersion'] != 1 ||
          json['assertions'] is! List ||
          json['decisions'] is! List) {
        throw const FormatException(
          'Medication reconciliation envelope is invalid.',
        );
      }
      final assertions = (json['assertions'] as List<dynamic>)
          .map(
            (item) => MedicationAssertionNode.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
      final decisions = (json['decisions'] as List<dynamic>)
          .map(
            (item) => MedicationReconciliationDecision.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
      if (assertions.length > 64 || decisions.length > 128) {
        throw const FormatException(
          'Medication reconciliation envelope is oversized.',
        );
      }
      return (
        assertions: assertions,
        decisions: decisions,
        invalidEvidence: null,
      );
    } on Object {
      return (
        assertions: const <MedicationAssertionNode>[],
        decisions: const <MedicationReconciliationDecision>[],
        invalidEvidence: Map<String, Object?>.from(json),
      );
    }
  }

  static ({
    AdministrationDoseConfirmationReceipt? receipt,
    Map<String, Object?>? invalidEvidence,
  })
  _doseConfirmationFromJson(Object? raw) {
    if (raw == null) return (receipt: null, invalidEvidence: null);
    if (raw is! Map) {
      return (
        receipt: null,
        invalidEvidence: <String, Object?>{
          'invalid_payload_type': raw.runtimeType.toString(),
        },
      );
    }
    final evidence = Map<String, Object?>.from(raw);
    try {
      return (
        receipt: AdministrationDoseConfirmationReceipt.fromJson(
          Map<String, dynamic>.from(evidence),
        ),
        invalidEvidence: null,
      );
    } on Object {
      return (receipt: null, invalidEvidence: evidence);
    }
  }

  static double? _positiveDouble(Object? raw) {
    if (raw is! num) return null;
    final value = raw.toDouble();
    return value.isFinite && value > 0 ? value : null;
  }

  static String? _optionalString(Object? raw) {
    if (raw is! String) return null;
    final value = raw.trim();
    return value.isEmpty ? null : value;
  }
}
