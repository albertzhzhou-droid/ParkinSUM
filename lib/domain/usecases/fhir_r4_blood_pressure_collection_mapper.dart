import '../entities/personal_observation.dart';
import 'blood_pressure_trend_projection.dart';
import 'fhir_r4_bundle_entry_identity.dart';
import 'fhir_r4_blood_pressure_mapper.dart';

/// Packages the timeline's bounded blood-pressure window as a FHIR R4
/// collection Bundle. This is a local JSON package, not a server transaction.
class FhirR4BloodPressureCollectionMapper {
  static const schemaUri = 'parkinsum.fhir-r4-bp-collection-mapper/3';
  static const maximumEntries =
      BloodPressureTrendProjection.maximumVisibleObservations;

  const FhirR4BloodPressureCollectionMapper();

  /// Returns a chronologically ordered, deeply immutable FHIR R4 Bundle.
  ///
  /// Every observation uses the caller's explicit Patient reference. Empty or
  /// oversized collections, duplicate local records, and unsupported observations
  /// are rejected instead of silently dropped or rewritten.
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
    for (final observation in ordered) {
      if (!ids.add(observation.id)) {
        throw const FormatException(
          'Duplicate observation ids cannot be packaged in one FHIR Bundle.',
        );
      }
    }

    const observationMapper = FhirR4BloodPressureMapper();
    final usedFullUrls = <String>{};
    final bundle = <String, dynamic>{
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': <Map<String, dynamic>>[
        for (final observation in ordered)
          _entry(
            observation,
            observationMapper,
            patientReference,
            usedFullUrls,
          ),
      ],
    };
    return _deepFreezeMap(bundle);
  }

  Map<String, dynamic> _entry(
    PersonalObservation observation,
    FhirR4BloodPressureMapper observationMapper,
    String patientReference,
    Set<String> usedFullUrls,
  ) {
    final fullUrl = newFhirBundleEntryFullUrl(usedFullUrls);
    final resourceId = fullUrl.substring('urn:uuid:'.length);
    final resource = Map<String, dynamic>.of(
      observationMapper.fromObservation(
        observation,
        patientReference: patientReference,
      ),
    )..['id'] = resourceId;
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
