import '../entities/care_medication_discussion_entry.dart';
import 'fhir_r4_blood_pressure_mapper.dart';
import 'fhir_r4_bundle_entry_identity.dart';

/// Projects account-entered, unverified medication discussion items to FHIR R4.
///
/// This is a local interoperability handoff, not a medication reconciliation
/// or verification workflow. It preserves only entered medication-name and
/// dose/schedule text and deliberately emits no terminology coding.
class FhirR4MedicationStatementCollectionMapper {
  static const schemaUri =
      'parkinsum.fhir-r4-medication-statement-collection/1';
  static const fhirVersion = FhirR4BloodPressureMapper.fhirVersion;
  static const maximumEntries = 128;

  const FhirR4MedicationStatementCollectionMapper();

  /// Returns an immutable FHIR R4 collection for records owned by [ownerId].
  ///
  /// The caller must supply the exact Patient reference. The mapper does not
  /// resolve it or infer that the account owner and Patient are the same
  /// person. Local IDs, recorder IDs, categories, ingredient labels, and
  /// questions are excluded from the Bundle.
  Map<String, dynamic> fromEntries(
    Iterable<CareMedicationDiscussionEntry> entries, {
    required String patientReference,
    required String ownerId,
  }) {
    _validatePatientReference(patientReference);
    _validateOwnerId(ownerId);

    final ordered = entries.toList()
      ..sort((a, b) {
        final timeOrder = a.recordedAt.compareTo(b.recordedAt);
        return timeOrder == 0 ? a.id.compareTo(b.id) : timeOrder;
      });
    if (ordered.isEmpty) {
      throw const FormatException('At least one medication item is required.');
    }
    if (ordered.length > maximumEntries) {
      throw FormatException(
        'A collection may contain at most $maximumEntries medication items.',
      );
    }

    final ids = <String>{};
    for (final entry in ordered) {
      if (!ids.add(entry.id)) {
        throw const FormatException(
          'Duplicate medication records cannot be packaged in one FHIR Bundle.',
        );
      }
      if (entry.recorderId != ownerId) {
        throw const FormatException(
          'Medication records must belong to the current account.',
        );
      }
      if (entry.recordedAt.year < 1 || entry.recordedAt.year > 9999) {
        throw const FormatException('Invalid medication statement time.');
      }
    }

    final usedFullUrls = <String>{};
    final bundle = <String, dynamic>{
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': <Map<String, dynamic>>[
        for (final entry in ordered)
          _bundleEntry(entry, patientReference, usedFullUrls),
      ],
    };
    return _deepFreezeMap(bundle);
  }

  Map<String, dynamic> _bundleEntry(
    CareMedicationDiscussionEntry entry,
    String patientReference,
    Set<String> usedFullUrls,
  ) {
    final fullUrl = newFhirBundleEntryFullUrl(usedFullUrls);
    final resourceId = fullUrl.substring('urn:uuid:'.length);
    final resource = <String, dynamic>{
      'resourceType': 'MedicationStatement',
      'id': resourceId,
      'status': _status(entry.reportedUse),
      'medicationCodeableConcept': <String, dynamic>{'text': entry.name},
      'subject': <String, dynamic>{'reference': patientReference},
      'dateAsserted': entry.recordedAt.toUtc().toIso8601String(),
      if (entry.doseAndScheduleText != null)
        'dosage': <Map<String, dynamic>>[
          <String, dynamic>{'text': entry.doseAndScheduleText},
        ],
    };
    return <String, dynamic>{'fullUrl': fullUrl, 'resource': resource};
  }

  String _status(CareMedicationReportedUse reportedUse) =>
      switch (reportedUse) {
        CareMedicationReportedUse.reportedCurrent => 'active',
        CareMedicationReportedUse.reportedStopped => 'stopped',
        CareMedicationReportedUse.uncertain => 'unknown',
      };

  void _validateOwnerId(String value) {
    if (value.trim().isEmpty ||
        value.length > 512 ||
        RegExp(r'[\x00-\x1F\x7F]').hasMatch(value)) {
      throw const FormatException('A valid current account is required.');
    }
  }

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
