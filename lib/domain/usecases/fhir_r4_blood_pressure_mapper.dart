import '../entities/personal_observation.dart';

/// Projects one local blood-pressure observation to the small FHIR R4
/// Observation/BP profile surface used by the CDSS interoperability spike.
///
/// The caller must supply the exact Patient reference already known to the
/// receiving system. This mapper never creates a Patient, translates recorder
/// IDs into Practitioner/RelatedPerson references, or guesses terminology.
class FhirR4BloodPressureMapper {
  static const schemaUri = 'parkinsum.fhir-r4-bp-mapper/2';
  static const fhirVersion = '4.0.1';
  static const loincVersion = '2.83';
  static const ucumSpecificationVersion = '2.2';
  static const bloodPressureProfile =
      'http://hl7.org/fhir/StructureDefinition/bp';
  static const _loincSystem = 'http://loinc.org';
  static const _ucumSystem = 'http://unitsofmeasure.org';
  static const _dataAbsentReasonSystem =
      'http://terminology.hl7.org/CodeSystem/data-absent-reason';

  const FhirR4BloodPressureMapper();

  /// Returns an immutable FHIR JSON resource for a blood-pressure entry.
  ///
  /// FHIR `Observation.status` is set to `preliminary` because this export
  /// carries user-entered observations without a separate verification step.
  /// A non-recorded observation keeps its missingness at both the resource and
  /// component levels through the standard `dataAbsentReason` code.
  Map<String, dynamic> fromObservation(
    PersonalObservation observation, {
    required String patientReference,
  }) {
    if (observation.kind != PersonalObservationKind.bloodPressure) {
      throw const FormatException(
        'Only blood-pressure observations are supported by this FHIR profile.',
      );
    }
    if (!RegExp(r'^[A-Za-z0-9.-]{1,64}$').hasMatch(observation.id)) {
      throw const FormatException(
        'Observation id is not a valid FHIR resource id; it will not be rewritten.',
      );
    }
    if (!_isExplicitPatientReference(patientReference)) {
      throw const FormatException(
        'Provide an explicit relative Patient/id or absolute Patient reference.',
      );
    }
    if (observation.unit != PersonalObservation.bloodPressureUnit) {
      throw const FormatException(
        'Blood-pressure unit is not the supported UCUM mm[Hg] code.',
      );
    }

    final reason = switch (observation.status) {
      PersonalObservationStatus.recorded => null,
      PersonalObservationStatus.notMeasured => 'not-performed',
      PersonalObservationStatus.unknown => 'unknown',
    };
    final components = <Map<String, dynamic>>[
      _component(
        code: '8480-6',
        display: 'Systolic blood pressure',
        value: observation.systolic,
        missingReason: reason,
      ),
      _component(
        code: '8462-4',
        display: 'Diastolic blood pressure',
        value: observation.diastolic,
        missingReason: reason,
      ),
    ];

    final resource = <String, dynamic>{
      'resourceType': 'Observation',
      'id': observation.id,
      'meta': <String, dynamic>{
        'profile': <String>[bloodPressureProfile],
      },
      'status': 'preliminary',
      'category': <Map<String, dynamic>>[
        <String, dynamic>{
          'coding': <Map<String, dynamic>>[
            <String, dynamic>{
              'system':
                  'http://terminology.hl7.org/CodeSystem/observation-category',
              'code': 'vital-signs',
            },
          ],
        },
      ],
      'code': <String, dynamic>{
        'coding': <Map<String, dynamic>>[
          <String, dynamic>{
            'system': _loincSystem,
            'version': loincVersion,
            'code': '85354-9',
            'display': 'Blood pressure panel with all children optional',
          },
        ],
      },
      'subject': <String, dynamic>{'reference': patientReference},
      'effectiveDateTime': observation.occurredAt.toUtc().toIso8601String(),
      'issued': observation.recordedAt.toUtc().toIso8601String(),
      'component': components,
      // Retain locally available source and original timezone as plain context.
      // Free-text notes and internal recorder IDs are deliberately not exported.
      'note': <Map<String, dynamic>>[
        <String, dynamic>{
          'text':
              'ParkinSUM source=${observation.source.name}; '
              'originalTimezone=${observation.originalTimezone}; '
              'posture=${observation.posture!.name}',
        },
      ],
    };
    if (reason != null) {
      resource['dataAbsentReason'] = _absentReason(reason);
    }
    return _deepFreezeMap(resource);
  }

  Map<String, dynamic> _component({
    required String code,
    required String display,
    required double? value,
    required String? missingReason,
  }) {
    final component = <String, dynamic>{
      'code': <String, dynamic>{
        'coding': <Map<String, dynamic>>[
          <String, dynamic>{
            'system': _loincSystem,
            'version': loincVersion,
            'code': code,
            'display': display,
          },
        ],
      },
    };
    if (value != null) {
      component['valueQuantity'] = <String, dynamic>{
        'value': value,
        'unit': 'mmHg',
        'system': _ucumSystem,
        'code': PersonalObservation.bloodPressureUnit,
      };
    } else if (missingReason != null) {
      component['dataAbsentReason'] = _absentReason(missingReason);
    }
    return component;
  }

  Map<String, dynamic> _absentReason(String code) => <String, dynamic>{
    'coding': <Map<String, dynamic>>[
      <String, dynamic>{'system': _dataAbsentReasonSystem, 'code': code},
    ],
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
