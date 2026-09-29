import 'dart:convert';

import 'package:crypto/crypto.dart';

enum FhirR5DoseQuantityPreviewStatus { projected, held }

final class FhirR5UcumCodeBinding {
  const FhirR5UcumCodeBinding({
    required this.localCode,
    required this.ucumCode,
  });

  final String localCode;
  final String ucumCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'local_code': localCode,
    'ucum_code': ucumCode,
  };
}

/// Development-only preview of one confirmed local administration quantity
/// as the FHIR R5 Dosage doseQuantity fragment.
///
/// This is not a FHIR resource, a validator, a prescription, or an exchange
/// artifact. It deliberately carries a narrow UCUM code subset and lists all
/// dose and medication semantics that this fragment does not project.
final class FhirR5DoseQuantityPreview {
  FhirR5DoseQuantityPreview._({
    required this.status,
    required this.evaluatedAtUtc,
    required Map<String, Object?>? dosageFragment,
    required Map<String, Object?>? sourceUnitMapping,
    required List<String> reasonCodes,
    required List<String> unmappedLocalFields,
  }) : dosageFragment = dosageFragment == null
           ? null
           : _deepFreezeMap(dosageFragment),
       sourceUnitMapping = sourceUnitMapping == null
           ? null
           : _deepFreezeMap(sourceUnitMapping),
       reasonCodes = List<String>.unmodifiable(
         reasonCodes.toSet().toList()..sort(),
       ),
       unmappedLocalFields = List<String>.unmodifiable(
         unmappedLocalFields.toSet().toList()..sort(),
       );

  static const String schemaUri = 'parkinsum.fhir-r5-dose-quantity-preview/2';
  static const String profileManifestSchemaUri =
      'parkinsum.fhir-r5-dose-quantity-preview-profile/2';
  static const String fhirCoreVersion = '5.0.0';
  static const String ucumVersion = '2.2';
  static const String ucumLicenseVersion = '1.1';
  static const String ucumSystem = 'http://unitsofmeasure.org';

  static const List<FhirR5UcumCodeBinding> unitCodeBindings =
      <FhirR5UcumCodeBinding>[
        FhirR5UcumCodeBinding(localCode: 'mg', ucumCode: 'mg'),
        FhirR5UcumCodeBinding(localCode: 'g', ucumCode: 'g'),
        FhirR5UcumCodeBinding(localCode: 'mcg', ucumCode: 'ug'),
        FhirR5UcumCodeBinding(localCode: 'mL', ucumCode: 'mL'),
      ];

  static const List<Map<String, String>>
  fhirDosagePathCoverage = <Map<String, String>>[
    <String, String>{
      'path': 'Dosage.additionalInstruction',
      'disposition': 'not_projected',
    },
    <String, String>{'path': 'Dosage.asNeeded', 'disposition': 'not_projected'},
    <String, String>{
      'path': 'Dosage.asNeededFor',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate',
      'disposition': 'partial_single_entry_only',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].doseQuantity',
      'disposition': 'partial_exact_quantity_only',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].doseQuantity.code',
      'disposition': 'mapped',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].doseQuantity.comparator',
      'disposition': 'unsupported',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].doseQuantity.system',
      'disposition': 'mapped',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].doseQuantity.unit',
      'disposition': 'mapped',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].doseQuantity.value',
      'disposition': 'mapped',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].doseRange',
      'disposition': 'unsupported',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].extension',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].id',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].modifierExtension',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].rateQuantity',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].rateRange',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].rateRatio',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[0].type',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.doseAndRate[1..*]',
      'disposition': 'unsupported',
    },
    <String, String>{
      'path': 'Dosage.extension',
      'disposition': 'not_projected',
    },
    <String, String>{'path': 'Dosage.id', 'disposition': 'not_projected'},
    <String, String>{
      'path': 'Dosage.maxDosePerAdministration',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.maxDosePerLifetime',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.maxDosePerPeriod',
      'disposition': 'not_projected',
    },
    <String, String>{'path': 'Dosage.method', 'disposition': 'not_projected'},
    <String, String>{
      'path': 'Dosage.modifierExtension',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Dosage.patientInstruction',
      'disposition': 'not_projected',
    },
    <String, String>{'path': 'Dosage.route', 'disposition': 'not_projected'},
    <String, String>{'path': 'Dosage.sequence', 'disposition': 'not_projected'},
    <String, String>{'path': 'Dosage.site', 'disposition': 'not_projected'},
    <String, String>{
      'path': 'Dosage.text',
      'disposition': 'partial_dose_token_not_full_sig',
    },
    <String, String>{'path': 'Dosage.timing', 'disposition': 'not_projected'},
  ];

  static const List<String> otherUnmappedSemanticPaths = <String>[
    'Intake source and confirmation provenance',
    'Medication identity and coding',
    'Medication.form',
    'Medication.ingredient.strength[x]',
  ];

  static List<Map<String, String>> get serializedFhirDosagePathCoverage =>
      List<Map<String, String>>.unmodifiable(
        fhirDosagePathCoverage
            .map((entry) => Map<String, String>.unmodifiable(entry))
            .toList()
          ..sort((a, b) => a['path']!.compareTo(b['path']!)),
      );

  static List<String> get mappedFhirPaths => List<String>.unmodifiable(
    serializedFhirDosagePathCoverage
        .where((entry) => entry['disposition'] == 'mapped')
        .map((entry) => entry['path']!),
  );

  static List<String> get partiallyProjectedFhirPaths =>
      List<String>.unmodifiable(
        serializedFhirDosagePathCoverage
            .where((entry) => entry['disposition']!.startsWith('partial_'))
            .map((entry) => entry['path']!),
      );

  static List<String> get notProjectedFhirPaths => List<String>.unmodifiable(
    <String>{
      ...serializedFhirDosagePathCoverage
          .where(
            (entry) =>
                entry['disposition'] == 'not_projected' ||
                entry['disposition'] == 'unsupported',
          )
          .map((entry) => entry['path']!),
      ...otherUnmappedSemanticPaths,
    }.toList()..sort(),
  );

  static const String fhirDosageDefinitionsUrl =
      'https://hl7.org/fhir/R5/dosage-definitions.html';

  static Map<String, Object?> get profileManifest => <String, Object?>{
    'manifest_schema': profileManifestSchemaUri,
    'fhir_core_package': 'hl7.fhir.core#5.0.0',
    'fhir_dosage_definition': fhirDosageDefinitionsUrl,
    'fhir_quantity_definition':
        'https://hl7.org/fhir/R5/datatypes-definitions.html#Quantity',
    'ucum_source_id': 'src.ucum.specification',
    'target_path': 'Dosage.doseAndRate.dose[x]',
    'wire_json_path': 'Dosage.doseAndRate[0].doseQuantity',
    'quantity_system': ucumSystem,
    'ucum_specification_version': ucumVersion,
    'ucum_license_version': ucumLicenseVersion,
    'ucum_license_url': 'https://ucum.org/license',
    'ucum_disposition':
        'Interoperability preview for four exact unit-code identifiers only. '
        'No UCUM table, parser, or unit descriptions are copied or redistributed. '
        'This is not a legal-clearance determination or general UCUM conformance.',
    'unit_code_bindings': <Map<String, Object?>>[
      for (final binding in unitCodeBindings) binding.toJson(),
    ],
    'path_ledger_scope':
        'FHIR R5 Dosage element paths for the bounded fragment, with choice '
        'and cardinality limits stated explicitly; not a complete FHIR '
        'resource/profile or nested datatype validation.',
    'fhir_dosage_path_coverage': serializedFhirDosagePathCoverage,
    'not_projected_fhir_paths': notProjectedFhirPaths,
    'other_unmapped_semantic_paths': otherUnmappedSemanticPaths,
    'resource_or_exchange_eligible': false,
  };

  static String get profileManifestSha256 =>
      _sha256(_canonicalJson(profileManifest));

  final FhirR5DoseQuantityPreviewStatus status;
  final DateTime evaluatedAtUtc;
  final Map<String, Object?>? dosageFragment;
  final Map<String, Object?>? sourceUnitMapping;
  final List<String> reasonCodes;
  final List<String> unmappedLocalFields;

  bool get projected =>
      status == FhirR5DoseQuantityPreviewStatus.projected &&
      dosageFragment != null;

  factory FhirR5DoseQuantityPreview.projected({
    required DateTime evaluatedAt,
    required Map<String, Object?> dosageFragment,
    required Map<String, Object?> sourceUnitMapping,
    required List<String> unmappedLocalFields,
  }) => FhirR5DoseQuantityPreview._(
    status: FhirR5DoseQuantityPreviewStatus.projected,
    evaluatedAtUtc: evaluatedAt.toUtc(),
    dosageFragment: dosageFragment,
    sourceUnitMapping: sourceUnitMapping,
    reasonCodes: <String>[
      'dose.fhir_r5.partial_quantity_fragment',
      if (unmappedLocalFields.isNotEmpty)
        'dose.fhir_r5.local_fields_not_projected',
    ],
    unmappedLocalFields: unmappedLocalFields,
  );

  factory FhirR5DoseQuantityPreview.held({
    required DateTime evaluatedAt,
    required List<String> reasonCodes,
    required List<String> unmappedLocalFields,
  }) => FhirR5DoseQuantityPreview._(
    status: FhirR5DoseQuantityPreviewStatus.held,
    evaluatedAtUtc: evaluatedAt.toUtc(),
    dosageFragment: null,
    sourceUnitMapping: null,
    reasonCodes: reasonCodes,
    unmappedLocalFields: unmappedLocalFields,
  );

  Map<String, Object?> toJson() {
    final payload = <String, Object?>{
      'schema': schemaUri,
      'status': status.name,
      'fhir_core_version': fhirCoreVersion,
      'ucum_specification_version': ucumVersion,
      'evaluated_at_utc': evaluatedAtUtc.toIso8601String(),
      'profile_manifest_sha256': profileManifestSha256,
      'profile_manifest': profileManifest,
      'dosage_fragment': dosageFragment,
      'source_unit_mapping': sourceUnitMapping,
      'reason_codes': reasonCodes,
      'fhir_dosage_path_coverage': serializedFhirDosagePathCoverage,
      'mapped_paths': projected ? mappedFhirPaths : const <String>[],
      'partially_projected_paths': projected
          ? partiallyProjectedFhirPaths
          : const <String>[],
      'not_projected_fhir_paths': notProjectedFhirPaths,
      'unmapped_local_fields': unmappedLocalFields,
      'resource_or_exchange_eligible': false,
      'boundary':
          'A confirmed local administration quantity is projected only as a '
          'FHIR R5 Dosage fragment. No Medication resource, FHIR profile '
          'validation, export, network exchange, prescription verification, '
          'administration proof, or clinical interpretation is produced.',
    };
    return <String, Object?>{
      ...payload,
      'preview_sha256': _sha256(_canonicalJson(payload)),
    };
  }
}

Map<String, Object?> _deepFreezeMap(Map<String, Object?> value) =>
    Map<String, Object?>.unmodifiable(<String, Object?>{
      for (final entry in value.entries) entry.key: _deepFreeze(entry.value),
    });

Object? _deepFreeze(Object? value) => switch (value) {
  Map<String, Object?> map => _deepFreezeMap(map),
  Map map => Map<Object?, Object?>.unmodifiable(<Object?, Object?>{
    for (final entry in map.entries) entry.key: _deepFreeze(entry.value),
  }),
  List<dynamic> list => List<Object?>.unmodifiable(list.map(_deepFreeze)),
  _ => value,
};

String _canonicalJson(Object? value) {
  if (value is Map) {
    final entries = value.entries.toList()
      ..sort((a, b) => a.key.toString().compareTo(b.key.toString()));
    return '{${entries.map((entry) => '${jsonEncode(entry.key.toString())}:${_canonicalJson(entry.value)}').join(',')}}';
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  return jsonEncode(value);
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();
