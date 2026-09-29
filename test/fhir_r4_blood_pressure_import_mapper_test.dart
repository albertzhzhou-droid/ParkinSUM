import 'package:flutter_test/flutter_test.dart';

import 'package:parkinsum_companion/domain/entities/fhir_r4_observation_import_preview.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_blood_pressure_import_mapper.dart';

void main() {
  const mapper = FhirR4BloodPressureImportMapper();

  FhirR4ObservationImportContext context({
    String source = 'https://ehr.example.org/fhir',
    String version = '4.0.1',
    String jurisdiction = 'CA',
    String patient = 'Patient/patient-1',
  }) => FhirR4ObservationImportContext(
    sourceFhirBase: source,
    fhirVersion: version,
    jurisdiction: jurisdiction,
    expectedPatientReference: patient,
  );

  Map<String, dynamic> coding(String code, {String? display}) => {
    'system': FhirR4ObservationImportPreview.loincSystem,
    'version': '2.83',
    'code': code,
    'display': ?display,
  };

  Map<String, dynamic> component(
    String code,
    num value, {
    String? comparator,
    String unitSystem = FhirR4ObservationImportPreview.ucumSystem,
    String unitCode = FhirR4ObservationImportPreview.bloodPressureUnitCode,
  }) => {
    'code': {
      'coding': [coding(code)],
    },
    'valueQuantity': {
      'value': value,
      'unit': 'mmHg',
      'system': unitSystem,
      'code': unitCode,
      'comparator': ?comparator,
    },
  };

  Map<String, dynamic> validObservation() => {
    'resourceType': 'Observation',
    'id': 'bp-01',
    'meta': {
      'versionId': '17',
      'source': 'https://ehr.example.org/fhir/Observation/bp-01',
      'lastUpdated': '2026-05-06T11:08:10.123Z',
    },
    'status': 'final',
    'code': {
      'coding': [coding('85354-9', display: 'Blood pressure panel')],
      'text': 'Blood pressure',
    },
    'subject': {'reference': 'Patient/patient-1'},
    'effectiveDateTime': '2026-05-06T07:08:09-04:00',
    'issued': '2026-05-06T11:08:10Z',
    'component': [component('8480-6', 120), component('8462-4', 80)],
  };

  test('previews exact R4 BP panel and retains source/version context', () {
    final preview = mapper.previewObservation(
      resource: validObservation(),
      context: context(),
    );

    expect(preview.previewable, isTrue);
    expect(preview.context.sourceFhirBase, 'https://ehr.example.org/fhir');
    expect(preview.context.fhirVersion, '4.0.1');
    expect(preview.context.jurisdiction, 'CA');
    expect(preview.resourceId, 'bp-01');
    expect(preview.resourceVersionId, '17');
    expect(
      preview.metaSource,
      'https://ehr.example.org/fhir/Observation/bp-01',
    );
    expect(preview.observationCodeVersion, '2.83');
    expect(preview.observationCodeText, 'Blood pressure');
    expect(preview.effectiveDateTimeLexical, '2026-05-06T07:08:09-04:00');
    expect(preview.effectiveAtUtc, DateTime.utc(2026, 5, 6, 11, 8, 9));
    expect(
      preview.metaLastUpdatedUtc,
      DateTime.utc(2026, 5, 6, 11, 8, 10, 123),
    );
    expect(preview.components.map((value) => value.code), ['8480-6', '8462-4']);
    expect(preview.components.map((value) => value.value), [120, 80]);
    expect(FhirR4ObservationImportPreview.persistsData, isFalse);
    expect(FhirR4ObservationImportPreview.algorithmEligible, isFalse);
  });

  test('keeps unknown and not-performed as distinct component states', () {
    final resource = validObservation();
    final components = resource['component'] as List<Map<String, dynamic>>;
    components[0].remove('valueQuantity');
    components[0]['dataAbsentReason'] = {
      'coding': [
        {
          'system': FhirR4ObservationImportPreview.dataAbsentReasonSystem,
          'version': '4.0.1',
          'code': 'unknown',
          'display': 'Unknown',
        },
      ],
    };
    components[1].remove('valueQuantity');
    components[1]['dataAbsentReason'] = {
      'coding': [
        {
          'system': FhirR4ObservationImportPreview.dataAbsentReasonSystem,
          'version': '4.0.1',
          'code': 'not-performed',
          'display': 'Not performed',
        },
      ],
    };

    final preview = mapper.previewObservation(
      resource: resource,
      context: context(),
    );

    expect(preview.previewable, isTrue);
    expect(preview.components[0].value, isNull);
    expect(preview.components[0].dataAbsentReasonCode, 'unknown');
    expect(preview.components[0].dataAbsentReasonVersion, '4.0.1');
    expect(preview.components[0].dataAbsentReasonDisplay, 'Unknown');
    expect(preview.components[1].value, isNull);
    expect(preview.components[1].dataAbsentReasonCode, 'not-performed');
    expect(preview.components[1].dataAbsentReasonDisplay, 'Not performed');
  });

  test('holds invalid source, release, jurisdiction, and patient context', () {
    final preview = mapper.previewObservation(
      resource: validObservation(),
      context: context(
        source: 'http://ehr.example.org/fhir',
        version: '5.0.0',
        jurisdiction: 'California',
        patient: 'invalid-reference',
      ),
    );

    expect(preview.previewable, isFalse);
    expect(preview.reasonCodes, contains('fhir.source_base_invalid'));
    expect(preview.reasonCodes, contains('fhir.release_unsupported'));
    expect(
      preview.reasonCodes,
      contains('fhir.jurisdiction_missing_or_invalid'),
    );
    expect(
      preview.reasonCodes,
      contains('fhir.expected_patient_reference_invalid'),
    );
    expect(preview.reasonCodes, contains('fhir.patient_reference_mismatch'));
  });

  test('holds unsupported status, component code, and LOINC drift', () {
    final resource = validObservation();
    resource['status'] = 'preliminary';
    final components = resource['component'] as List<Map<String, dynamic>>;
    components[1]['code'] = {
      'coding': [coding('99999-9')],
    };
    components[0]['code'] = {
      'coding': [coding('8480-6')..['version'] = '2.82'],
    };

    final preview = mapper.previewObservation(
      resource: resource,
      context: context(),
    );

    expect(preview.previewable, isFalse);
    expect(preview.reasonCodes, contains('fhir.observation_status_not_final'));
    expect(preview.reasonCodes, contains('fhir.bp_component_code_unsupported'));
    expect(preview.reasonCodes, contains('fhir.loinc_version_mismatch'));
  });

  test('holds partial or invalid instants and precision beyond DateTime', () {
    for (final instant in [
      '2026-05-06',
      '2026-04-31T07:08:09Z',
      '2026-05-06T07:08:09+14:01',
      '2026-05-06T07:08:09.1234567Z',
    ]) {
      final resource = validObservation()..['effectiveDateTime'] = instant;
      final preview = mapper.previewObservation(
        resource: resource,
        context: context(),
      );

      expect(preview.previewable, isFalse, reason: instant);
      expect(
        preview.reasonCodes,
        contains('fhir.effective_datetime_requires_full_offset'),
        reason: instant,
      );
    }
  });

  test(
    'holds Quantity comparator, unsupported unit, and unprojected paths',
    () {
      final resource = validObservation();
      final components = resource['component'] as List<Map<String, dynamic>>;
      components[0]['valueQuantity'] = {
        ...(components[0]['valueQuantity'] as Map<String, dynamic>),
        'comparator': '<',
        'extension': [
          {'url': 'https://example.org/extra', 'valueString': 'held'},
        ],
      };
      components[1]['valueQuantity'] = {
        ...(components[1]['valueQuantity'] as Map<String, dynamic>),
        'code': 'kPa',
      };
      resource['interpretation'] = {'text': 'outside this projection'};

      final preview = mapper.previewObservation(
        resource: resource,
        context: context(),
      );

      expect(preview.previewable, isFalse);
      expect(
        preview.reasonCodes,
        contains('fhir.quantity_comparator_unsupported'),
      );
      expect(
        preview.reasonCodes,
        contains('fhir.quantity_ucum_binding_unsupported'),
      );
      expect(preview.reasonCodes, contains('fhir.unmapped_fields'));
      expect(
        preview.unmappedPaths,
        containsAll([
          'Observation.component[0].valueQuantity.extension',
          'Observation.interpretation',
        ]),
      );
    },
  );

  test('holds unknown absent-reason concepts and conflicting value states', () {
    final resource = validObservation();
    final components = resource['component'] as List<Map<String, dynamic>>;
    components[0].remove('valueQuantity');
    components[0]['dataAbsentReason'] = {
      'coding': [
        {
          'system': FhirR4ObservationImportPreview.dataAbsentReasonSystem,
          'code': 'masked',
        },
      ],
    };
    components[1]['dataAbsentReason'] = {
      'coding': [
        {
          'system': FhirR4ObservationImportPreview.dataAbsentReasonSystem,
          'code': 'unknown',
        },
      ],
    };

    final preview = mapper.previewObservation(
      resource: resource,
      context: context(),
    );

    expect(preview.previewable, isFalse);
    expect(
      preview.reasonCodes,
      contains('fhir.data_absent_reason_unsupported'),
    );
    expect(
      preview.reasonCodes,
      contains('fhir.value_and_absent_reason_conflict'),
    );
  });

  test('holds missing or mismatched LOINC versions', () {
    for (final componentVersion in [null, '2.82']) {
      final resource = validObservation();
      final components = resource['component'] as List<Map<String, dynamic>>;
      final componentCoding = coding('8480-6');
      if (componentVersion == null) {
        componentCoding.remove('version');
      } else {
        componentCoding['version'] = componentVersion;
      }
      components[0]['code'] = {
        'coding': [componentCoding],
      };

      final preview = mapper.previewObservation(
        resource: resource,
        context: context(),
      );
      expect(preview.previewable, isFalse);
      expect(
        preview.reasonCodes,
        contains(
          componentVersion == null
              ? 'fhir.bp_component_loinc_version_missing'
              : 'fhir.loinc_version_mismatch',
        ),
      );
    }

    final missingPanelVersion = validObservation();
    final panelCoding = coding('85354-9')..remove('version');
    missingPanelVersion['code'] = {
      'coding': [panelCoding],
    };
    final preview = mapper.previewObservation(
      resource: missingPanelVersion,
      context: context(),
    );
    expect(preview.previewable, isFalse);
    expect(preview.reasonCodes, contains('fhir.loinc_version_missing'));
  });
}
