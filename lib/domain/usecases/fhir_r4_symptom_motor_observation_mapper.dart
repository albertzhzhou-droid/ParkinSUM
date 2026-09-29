import '../entities/personal_observation.dart';
import 'fhir_r4_bundle_entry_identity.dart';
import 'symptom_motor_observation_projection.dart';

/// Maps account-entered symptom and movement-state observations to a bounded
/// FHIR R4 representation. The local code system is illustrative, not a
/// standard clinical terminology or a constrained implementation profile.
class FhirR4SymptomMotorObservationMapper {
  static const schemaUri = 'parkinsum.fhir-r4-symptom-motor-mapper/1';
  static const fhirVersion = '4.0.1';
  static const codeSystem =
      'https://github.com/albertzhzhou-droid/ParkinSUM/fhir/CodeSystem/parkinsum-personal-observation';
  static const codeSystemVersion = '1.0.0';
  static const _dataAbsentReasonSystem =
      'http://terminology.hl7.org/CodeSystem/data-absent-reason';

  const FhirR4SymptomMotorObservationMapper();

  Map<String, dynamic> fromObservation(
    PersonalObservation observation, {
    required String patientReference,
  }) {
    if (observation.kind != PersonalObservationKind.symptom &&
        observation.kind != PersonalObservationKind.selfReportedMotorState) {
      throw const FormatException(
        'Only symptom and motor-state observations are supported.',
      );
    }
    if (!_isExplicitPatientReference(patientReference)) {
      throw const FormatException(
        'Provide an explicit relative Patient/id or absolute Patient reference.',
      );
    }

    final isSymptom = observation.kind == PersonalObservationKind.symptom;
    final resource = <String, dynamic>{
      'resourceType': 'Observation',
      // Preliminary distinguishes these owner-entered records from an
      // independently verified result. No internal record or recorder ID is
      // exported.
      'status': 'preliminary',
      'code': <String, dynamic>{
        'coding': <Map<String, dynamic>>[
          _coding(
            code: isSymptom ? 'symptom' : 'self-reported-motor-state',
            display: isSymptom
                ? 'User-entered symptom observation'
                : 'User-entered motor-state observation',
          ),
        ],
        if (isSymptom) 'text': observation.symptomLabel,
      },
      'subject': <String, dynamic>{'reference': patientReference},
      'effectiveDateTime': observation.occurredAt.toUtc().toIso8601String(),
      'issued': observation.recordedAt.toUtc().toIso8601String(),
      'method': <String, dynamic>{
        'coding': <Map<String, dynamic>>[
          _coding(
            code: _sourceCode(observation.source),
            display: _sourceDisplay(observation.source),
          ),
        ],
      },
      // This is generated metadata, not the user's private free-text note.
      'note': <Map<String, dynamic>>[
        <String, dynamic>{
          'text': 'Original timezone: ${observation.originalTimezone}',
        },
      ],
    };

    switch (observation.status) {
      case PersonalObservationStatus.unknown:
        resource['dataAbsentReason'] = _absentReason('unknown');
      case PersonalObservationStatus.notMeasured:
        resource['dataAbsentReason'] = _absentReason('not-performed');
      case PersonalObservationStatus.recorded:
        if (isSymptom && observation.severity != null) {
          resource['component'] = <Map<String, dynamic>>[
            <String, dynamic>{
              'code': <String, dynamic>{
                'coding': <Map<String, dynamic>>[
                  _coding(
                    code: 'owner-entered-severity-0-10',
                    display:
                        'Owner-entered severity (0-10; scale not clinically validated)',
                  ),
                ],
              },
              'valueInteger': observation.severity,
            },
          ];
        } else if (!isSymptom) {
          final state = observation.motorState!;
          resource['valueCodeableConcept'] = <String, dynamic>{
            'coding': <Map<String, dynamic>>[
              _coding(
                code: state.name,
                display: switch (state) {
                  SelfReportedMotorState.on => 'ON',
                  SelfReportedMotorState.off => 'OFF',
                  SelfReportedMotorState.uncertain => 'Uncertain',
                },
              ),
            ],
            'text': switch (state) {
              SelfReportedMotorState.on => 'ON',
              SelfReportedMotorState.off => 'OFF',
              SelfReportedMotorState.uncertain => 'Uncertain',
            },
          };
        }
    }

    return _deepFreezeMap(resource);
  }

  Map<String, dynamic> _coding({
    required String code,
    required String display,
  }) => <String, dynamic>{
    'system': codeSystem,
    'version': codeSystemVersion,
    'code': code,
    'display': display,
  };

  Map<String, dynamic> _absentReason(String code) => <String, dynamic>{
    'coding': <Map<String, dynamic>>[
      <String, dynamic>{'system': _dataAbsentReasonSystem, 'code': code},
    ],
  };

  String _sourceCode(PersonalObservationSource source) => switch (source) {
    PersonalObservationSource.selfReported => 'self-reported',
    PersonalObservationSource.deviceManual => 'device-reading-entered-manually',
    PersonalObservationSource.caregiverReported =>
      'caregiver-reported-by-account-holder',
  };

  String _sourceDisplay(PersonalObservationSource source) => switch (source) {
    PersonalObservationSource.selfReported => 'Self-reported',
    PersonalObservationSource.deviceManual => 'Device reading entered manually',
    PersonalObservationSource.caregiverReported =>
      'Caregiver-reported by account holder',
  };

  bool _isExplicitPatientReference(String value) {
    if (value.trim() != value || value.isEmpty || value.length > 512) {
      return false;
    }
    const id = r'[A-Za-z0-9.-]{1,64}';
    if (RegExp('^Patient/$id\$').hasMatch(value)) return true;
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return false;
    }
    final segments = uri.pathSegments;
    return segments.length >= 2 &&
        segments[segments.length - 2] == 'Patient' &&
        RegExp('^$id\$').hasMatch(segments.last);
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

/// Packages the latest bounded symptom and motor-state observations without
/// exposing local IDs or recorder identity.
class FhirR4SymptomMotorObservationCollectionMapper {
  static const schemaUri = 'parkinsum.fhir-r4-symptom-motor-collection/2';
  static const maximumEntries =
      SymptomMotorObservationProjection.maximumVisibleObservations;

  const FhirR4SymptomMotorObservationCollectionMapper();

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
      if (observation.kind != PersonalObservationKind.symptom &&
          observation.kind != PersonalObservationKind.selfReportedMotorState) {
        throw const FormatException(
          'Only symptom and motor-state observations are supported.',
        );
      }
      if (!ids.add(observation.id)) {
        throw const FormatException(
          'Duplicate observation records cannot be packaged in one FHIR Bundle.',
        );
      }
    }

    const mapper = FhirR4SymptomMotorObservationMapper();
    final usedFullUrls = <String>{};
    return Map<String, dynamic>.unmodifiable({
      'resourceType': 'Bundle',
      'type': 'collection',
      'entry': List<Map<String, dynamic>>.unmodifiable([
        for (final observation in ordered)
          Map<String, dynamic>.unmodifiable({
            'fullUrl': newFhirBundleEntryFullUrl(usedFullUrls),
            'resource': mapper.fromObservation(
              observation,
              patientReference: patientReference,
            ),
          }),
      ]),
    });
  }
}
