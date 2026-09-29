import '../../core/models/intake.dart';
import 'fhir_r4_blood_pressure_mapper.dart';

/// Projects one local timeline intake into a narrow FHIR R4 MedicationStatement.
///
/// The event is an owner-entered report, not verified administration. Medication
/// identity remains display text, the required status is `unknown`, and local
/// timestamps without a retained offset are reduced to calendar-date precision.
class FhirR4MedicationIntakeStatementMapper {
  static const schemaUri = 'parkinsum.fhir-r4-medication-intake-statement/1';
  static const fhirVersion = FhirR4BloodPressureMapper.fhirVersion;
  static const maximumMedicationNameLength = 512;
  static const maximumDosageNoteLength = 4096;

  const FhirR4MedicationIntakeStatementMapper();

  /// Returns an immutable FHIR R4 MedicationStatement for one saved intake.
  ///
  /// The caller must verify that [intake] belongs to the current account and
  /// provide the exact Patient reference used by the receiving system. Local
  /// record identifiers, dose receipts, terminology codes, and product details
  /// are deliberately excluded.
  Map<String, dynamic> fromIntake(
    Intake intake, {
    required String medicationDisplayName,
    required String patientReference,
  }) {
    _validatePatientReference(patientReference);
    final medicationName = medicationDisplayName.trim();
    if (medicationName.isEmpty ||
        medicationName.length > maximumMedicationNameLength ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(medicationName)) {
      throw const FormatException(
        'A valid medication display name is required.',
      );
    }
    final takenAt = intake.takenAt;
    if (takenAt.year < 1 || takenAt.year > 9999) {
      throw const FormatException('Invalid medication intake time.');
    }
    final dosageNote = intake.dosageNote;
    if (dosageNote.length > maximumDosageNoteLength ||
        RegExp(r'[\x00\x7F]').hasMatch(dosageNote)) {
      throw const FormatException(
        'The medication note is too large or invalid.',
      );
    }

    final localTimeOffsetWasUnavailable = !takenAt.isUtc;
    final statement = <String, dynamic>{
      'resourceType': 'MedicationStatement',
      'status': 'unknown',
      'medicationCodeableConcept': <String, dynamic>{'text': medicationName},
      'subject': <String, dynamic>{'reference': patientReference},
      'effectiveDateTime': localTimeOffsetWasUnavailable
          ? _dateOnly(takenAt)
          : takenAt.toIso8601String(),
      'note': <Map<String, dynamic>>[
        <String, dynamic>{
          'text': localTimeOffsetWasUnavailable
              ? 'ParkinSUM user-entered timeline log; medication identity and use are not independently verified. Original time-zone offset was not retained; effectiveDateTime is date-only.'
              : 'ParkinSUM user-entered timeline log; medication identity and use are not independently verified.',
        },
      ],
      if (dosageNote.trim().isNotEmpty)
        'dosage': <Map<String, dynamic>>[
          <String, dynamic>{'text': dosageNote},
        ],
    };
    return _deepFreezeMap(statement);
  }

  String _dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  void _validatePatientReference(String value) {
    if (value.trim() != value ||
        value.isEmpty ||
        value.length > 512 ||
        RegExp(r'[\x00-\x20\x7F]').hasMatch(value)) {
      throw const FormatException(
        'Provide an explicit relative Patient/id or absolute Patient reference.',
      );
    }
    const id = r'[A-Za-z0-9.-]{1,64}';
    if (RegExp('^Patient/$id\$').hasMatch(value)) return;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException(
        'Provide an explicit relative Patient/id or absolute Patient reference.',
      );
    }
    final segments = uri.pathSegments;
    if (segments.length < 2 ||
        segments[segments.length - 2] != 'Patient' ||
        !RegExp('^$id\$').hasMatch(segments.last)) {
      throw const FormatException(
        'Provide an explicit relative Patient/id or absolute Patient reference.',
      );
    }
  }

  Map<String, dynamic> _deepFreezeMap(Map<String, dynamic> source) =>
      Map<String, dynamic>.unmodifiable({
        for (final entry in source.entries) entry.key: _deepFreeze(entry.value),
      });

  Object? _deepFreeze(Object? value) => switch (value) {
    Map<String, dynamic> map => _deepFreezeMap(map),
    List<dynamic> list => List<Object?>.unmodifiable(list.map(_deepFreeze)),
    _ => value,
  };
}
