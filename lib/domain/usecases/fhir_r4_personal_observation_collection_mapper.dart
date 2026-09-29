import '../entities/personal_observation.dart';
import 'blood_pressure_trend_projection.dart';
import 'fhir_r4_bundle_entry_identity.dart';
import 'fhir_r4_blood_pressure_mapper.dart';
import 'fhir_r4_symptom_motor_observation_mapper.dart';
import 'symptom_motor_observation_projection.dart';

/// Combines the timeline's bounded blood-pressure and personal symptom/motor
/// observations into one local FHIR R4 collection Bundle.
class FhirR4PersonalObservationCollectionMapper {
  static const schemaUri = 'parkinsum.fhir-r4-personal-collection/1';
  static const fhirVersion = FhirR4BloodPressureMapper.fhirVersion;
  static const maximumBloodPressureEntries =
      BloodPressureTrendProjection.maximumVisibleObservations;
  static const maximumSymptomMotorEntries =
      SymptomMotorObservationProjection.maximumVisibleObservations;
  static const maximumEntries =
      maximumBloodPressureEntries + maximumSymptomMotorEntries;

  const FhirR4PersonalObservationCollectionMapper();

  /// Returns a chronologically ordered, deeply immutable FHIR R4 Bundle.
  ///
  /// Every entry shares the explicitly supplied Patient reference, while
  /// generated Bundle/resource identities remain independent of local IDs.
  Map<String, dynamic> fromObservations(
    Iterable<PersonalObservation> observations, {
    required String patientReference,
  }) {
    final ordered = observations.toList()
      ..sort((a, b) {
        final occurred = a.occurredAt.compareTo(b.occurredAt);
        if (occurred != 0) return occurred;
        final recorded = a.recordedAt.compareTo(b.recordedAt);
        return recorded == 0 ? a.id.compareTo(b.id) : recorded;
      });
    if (ordered.isEmpty) {
      throw const FormatException('At least one observation is required.');
    }
    if (ordered.length > maximumEntries) {
      throw FormatException(
        'A collection may contain at most $maximumEntries observations.',
      );
    }

    final ids = <String>{};
    var bloodPressureCount = 0;
    var symptomMotorCount = 0;
    for (final observation in ordered) {
      if (!ids.add(observation.id)) {
        throw const FormatException(
          'Duplicate observation records cannot be packaged in one FHIR Bundle.',
        );
      }
      switch (observation.kind) {
        case PersonalObservationKind.bloodPressure:
          bloodPressureCount++;
        case PersonalObservationKind.symptom:
        case PersonalObservationKind.selfReportedMotorState:
          symptomMotorCount++;
      }
    }
    if (bloodPressureCount > maximumBloodPressureEntries ||
        symptomMotorCount > maximumSymptomMotorEntries) {
      throw const FormatException(
        'A collection may contain at most 12 blood-pressure and 12 symptom/motor observations.',
      );
    }

    final usedFullUrls = <String>{};
    final bundle = <String, dynamic>{
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': <Map<String, dynamic>>[
        for (final observation in ordered)
          _entry(observation, patientReference, usedFullUrls),
      ],
    };
    return _deepFreezeMap(bundle);
  }

  Map<String, dynamic> _entry(
    PersonalObservation observation,
    String patientReference,
    Set<String> usedFullUrls,
  ) {
    final fullUrl = newFhirBundleEntryFullUrl(usedFullUrls);
    final resourceId = fullUrl.substring('urn:uuid:'.length);
    final mapped = switch (observation.kind) {
      PersonalObservationKind.bloodPressure =>
        const FhirR4BloodPressureMapper().fromObservation(
          observation,
          patientReference: patientReference,
        ),
      PersonalObservationKind.symptom ||
      PersonalObservationKind.selfReportedMotorState =>
        const FhirR4SymptomMotorObservationMapper().fromObservation(
          observation,
          patientReference: patientReference,
        ),
    };
    final resource = Map<String, dynamic>.of(mapped)..['id'] = resourceId;
    return <String, dynamic>{'fullUrl': fullUrl, 'resource': resource};
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
