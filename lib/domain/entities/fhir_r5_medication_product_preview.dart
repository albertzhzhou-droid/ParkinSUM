import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'openfda_strength_expression_source_manifest.dart';

enum FhirR5MedicationProductPreviewStatus { projected, held }

/// Development-only projection of local medication product metadata.
///
/// The source-view path keeps strength as local evidence. The separate
/// `MedicationProductPack` path may project a very small exact strength subset
/// into `Medication.ingredient.strengthQuantity`. Strength never becomes a
/// Dosage, a dose receipt, or an algorithm input. The fragment carries no
/// ingredient terminology coding or care context and is never eligible for
/// exchange or clinical use.
final class FhirR5MedicationProductPreview {
  FhirR5MedicationProductPreview._({
    required this.status,
    required this.evaluatedAtUtc,
    required Map<String, Object?>? medicationFragment,
    required Map<String, Object?> sourceProvenance,
    required List<Map<String, Object?>> productStrengthEvidence,
    required List<String> reasonCodes,
  }) : medicationFragment = medicationFragment == null
           ? null
           : _deepFreezeMap(medicationFragment),
       sourceProvenance = _deepFreezeMap(sourceProvenance),
       productStrengthEvidence = List<Map<String, Object?>>.unmodifiable(
         productStrengthEvidence.map(_deepFreezeMap),
       ),
       reasonCodes = List<String>.unmodifiable(
         reasonCodes.toSet().toList()..sort(),
       );

  static const String schemaUri =
      'parkinsum.fhir-r5-medication-product-preview/3';
  static const String profileManifestSchemaUri =
      'parkinsum.fhir-r5-medication-product-preview-profile/3';
  static const String fhirCoreVersion = '5.0.0';
  static const String ucumVersion = '2.2';
  static const String ucumLicenseVersion = '1.1';
  static const String ucumSystem = 'http://unitsofmeasure.org';
  static const String fhirMedicationDefinitionsUrl =
      'https://hl7.org/fhir/R5/medication-definitions.html';
  static const String fhirDataTypesDefinitionsUrl =
      'https://hl7.org/fhir/R5/datatypes-definitions.html#Quantity';
  static const String ucumSpecificationUrl = 'https://ucum.org/ucum';
  static const String ucumLicenseUrl = 'https://ucum.org/license';

  static const List<Map<String, String>>
  fhirMedicationPathCoverage = <Map<String, String>>[
    <String, String>{
      'path': 'Medication.batch',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.batch.expirationDate',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.batch.lotNumber',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.code',
      'disposition': 'partial_text_only',
    },
    <String, String>{
      'path': 'Medication.contained',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.definition',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.doseForm',
      'disposition': 'partial_text_only',
    },
    <String, String>{
      'path': 'Medication.ingredient',
      'disposition': 'partial_known_components_only',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].extension',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].id',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].isActive',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].item',
      'disposition': 'partial_concept_text_only',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].item.concept.text',
      'disposition': 'mapped_text_only',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].item.reference',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].modifierExtension',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].strength[x]',
      'disposition': 'partial_exact_one_unit_quantity_subset',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].strengthCodeableConcept',
      'disposition': 'not_projected_no_terminology',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].strengthQuantity',
      'disposition': 'partial_exact_one_unit_ucum_quantity_subset',
    },
    <String, String>{
      'path': 'Medication.ingredient[*].strengthRatio',
      'disposition': 'not_projected_no_denominator_or_unit_system',
    },
    <String, String>{
      'path': 'Medication.identifier',
      'disposition': 'not_projected',
    },
    <String, String>{'path': 'Medication.id', 'disposition': 'not_projected'},
    <String, String>{
      'path': 'Medication.implicitRules',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.language',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.marketingAuthorizationHolder',
      'disposition': 'not_projected',
    },
    <String, String>{'path': 'Medication.meta', 'disposition': 'not_projected'},
    <String, String>{
      'path': 'Medication.extension',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.modifierExtension',
      'disposition': 'not_projected',
    },
    <String, String>{
      'path': 'Medication.status',
      'disposition': 'not_projected',
    },
    <String, String>{'path': 'Medication.text', 'disposition': 'not_projected'},
    <String, String>{
      'path': 'Medication.totalVolume',
      'disposition': 'not_projected_package_amount_unresolved',
    },
  ];

  static List<Map<String, String>> get serializedFhirMedicationPathCoverage =>
      List<Map<String, String>>.unmodifiable(
        fhirMedicationPathCoverage
            .map((entry) => Map<String, String>.unmodifiable(entry))
            .toList()
          ..sort((a, b) => a['path']!.compareTo(b['path']!)),
      );

  static const Map<String, Object?> profileManifest = <String, Object?>{
    'manifest_schema': profileManifestSchemaUri,
    'fhir_core_package': 'hl7.fhir.core#5.0.0',
    'fhir_medication_definition': fhirMedicationDefinitionsUrl,
    'fhir_quantity_definition': fhirDataTypesDefinitionsUrl,
    'ucum_system': ucumSystem,
    'ucum_specification': ucumSpecificationUrl,
    'ucum_version': ucumVersion,
    'ucum_license': ucumLicenseUrl,
    'ucum_license_version': ucumLicenseVersion,
    'ucum_license_disposition':
        'reference_only_no_full_table_parser_or_redistribution_clearance',
    'projected_ucum_code_subset': <String>['g', 'mg', 'ug'],
    'openfda_source_row_schema_uri':
        OpenFdaStrengthExpressionSourceManifest.schemaUri,
    'target_resource': 'Medication',
    'path_ledger_scope':
        'Development-only projection of a product display, dose-form display, '
        'known ingredient names, and a bounded exact strengthQuantity subset '
        'from MedicationProductPack. The FhirInspiredMedicationKnowledgeView '
        'path remains text-only. Package quantity, ingredient terminology '
        'codes, batch, status, authorization holder, and care-context fields '
        'are not projected. This is not a complete FHIR resource/profile or '
        'nested datatype validation.',
    'strength_boundary':
        'Only exact source lexemes with a supported mass code, a recognized '
        'exact tablet form, and an absent or numeric-one '
        'unitless denominator can become Medication.ingredient.strengthQuantity '
        'through the MedicationProductPack path. All source strengths remain '
        'separate evidence; projected strength never becomes Dosage, a '
        'confirmation receipt, or an algorithm input. Other strengths remain '
        'held evidence.',
    'source_provenance_boundary':
        'Source references and source-document identity are carried outside '
        'the Medication fragment and included in the preview digest. When an '
        'openFDA local source manifest is supplied, the preview also binds the '
        'exact snapshot digest and uniquely matched product NDC, product ID, '
        'SPL ID, ingredient index, ingredient name, parser-result digest, and '
        'row digest. This records local byte identity only; it does not verify '
        'FDA source truth or currentness.',
    'fhir_medication_path_coverage': fhirMedicationPathCoverage,
    'resource_or_exchange_eligible': false,
    'algorithm_eligible': false,
  };

  static String get profileManifestSha256 =>
      _sha256(_canonicalJson(profileManifest));

  final FhirR5MedicationProductPreviewStatus status;
  final DateTime evaluatedAtUtc;
  final Map<String, Object?>? medicationFragment;
  final Map<String, Object?> sourceProvenance;
  final List<Map<String, Object?>> productStrengthEvidence;
  final List<String> reasonCodes;

  bool get projected =>
      status == FhirR5MedicationProductPreviewStatus.projected &&
      medicationFragment != null;

  factory FhirR5MedicationProductPreview.projected({
    required DateTime evaluatedAt,
    required Map<String, Object?> medicationFragment,
    required Map<String, Object?> sourceProvenance,
    required List<Map<String, Object?>> productStrengthEvidence,
  }) => FhirR5MedicationProductPreview._(
    status: FhirR5MedicationProductPreviewStatus.projected,
    evaluatedAtUtc: evaluatedAt.toUtc(),
    medicationFragment: medicationFragment,
    sourceProvenance: sourceProvenance,
    productStrengthEvidence: productStrengthEvidence,
    reasonCodes: const <String>[
      'medication.fhir_r5.partial_product_metadata_fragment',
      'medication.fhir_r5.product_strength_not_administration_dose',
    ],
  );

  factory FhirR5MedicationProductPreview.held({
    required DateTime evaluatedAt,
    required List<String> reasonCodes,
    required Map<String, Object?> sourceProvenance,
    required List<Map<String, Object?>> productStrengthEvidence,
  }) => FhirR5MedicationProductPreview._(
    status: FhirR5MedicationProductPreviewStatus.held,
    evaluatedAtUtc: evaluatedAt.toUtc(),
    medicationFragment: null,
    sourceProvenance: sourceProvenance,
    productStrengthEvidence: productStrengthEvidence,
    reasonCodes: reasonCodes,
  );

  Map<String, Object?> toJson() {
    final payload = <String, Object?>{
      'schema': schemaUri,
      'status': status.name,
      'fhir_core_version': fhirCoreVersion,
      'evaluated_at_utc': evaluatedAtUtc.toIso8601String(),
      'profile_manifest_sha256': profileManifestSha256,
      'profile_manifest': profileManifest,
      'medication_fragment': medicationFragment,
      'source_provenance': sourceProvenance,
      'product_strength_evidence': productStrengthEvidence,
      'reason_codes': reasonCodes,
      'fhir_medication_path_coverage': serializedFhirMedicationPathCoverage,
      'resource_or_exchange_eligible': false,
      'algorithm_eligible': false,
      'boundary':
          'This is an offline FHIR R5 Medication text fragment and separate '
          'product-strength evidence. It performs no RxNorm mapping, '
          'profile validation, export, network exchange, dose derivation, '
          'prescription verification, or clinical interpretation.',
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
  if (value is List) return '[${value.map(_canonicalJson).join(',')}]';
  return jsonEncode(value);
}

String _sha256(String value) => sha256.convert(utf8.encode(value)).toString();
