import '../../core/models/medication_product_pack.dart';
import '../entities/fhir_inspired_medication_knowledge_view.dart';
import '../entities/fhir_r5_medication_product_preview.dart';
import '../entities/openfda_strength_expression_source_manifest.dart';

/// Builds an offline FHIR R5 Medication text fragment from the existing
/// provenance-only product view. It never reads an Intake or dose receipt.
final class FhirR5MedicationProductPreviewService {
  const FhirR5MedicationProductPreviewService();

  FhirR5MedicationProductPreview project(
    FhirInspiredMedicationKnowledgeView product, {
    required DateTime observedAt,
  }) {
    final strengthEvidence = _strengthEvidence(product);
    final sourceProvenance = _sourceProvenance(product);
    final productName = product.productName?.trim();
    final doseForm = _usableText(product.doseForm);
    final componentNames = product.combinationComponents
        .map((component) => component.ingredientName.trim())
        .toList(growable: false);
    final ingredientNames = product.combinationComponents.isNotEmpty
        ? componentNames
        : product.activeIngredients.map((name) => name.trim()).toList();

    if (productName != null && !_isSafeText(productName, maxLength: 512)) {
      return FhirR5MedicationProductPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'medication.fhir_r5.product_display_invalid',
        ],
        sourceProvenance: sourceProvenance,
        productStrengthEvidence: strengthEvidence,
      );
    }
    if (product.combinationComponents.any(
          (component) =>
              !_isSafeText(component.ingredientName.trim(), maxLength: 256),
        ) ||
        product.activeIngredients.any(
          (name) => !_isSafeText(name.trim(), maxLength: 256),
        )) {
      return FhirR5MedicationProductPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'medication.fhir_r5.ingredient_display_invalid',
        ],
        sourceProvenance: sourceProvenance,
        productStrengthEvidence: strengthEvidence,
      );
    }
    if (doseForm != null && !_isSafeText(doseForm, maxLength: 256)) {
      return FhirR5MedicationProductPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'medication.fhir_r5.dose_form_display_invalid',
        ],
        sourceProvenance: sourceProvenance,
        productStrengthEvidence: strengthEvidence,
      );
    }

    if (productName == null && ingredientNames.isEmpty) {
      return FhirR5MedicationProductPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'medication.fhir_r5.product_identity_missing',
        ],
        sourceProvenance: sourceProvenance,
        productStrengthEvidence: strengthEvidence,
      );
    }

    final fragment = <String, Object?>{
      'resourceType': 'Medication',
      if (productName != null) 'code': <String, Object?>{'text': productName},
      if (doseForm != null) 'doseForm': <String, Object?>{'text': doseForm},
      if (ingredientNames.isNotEmpty)
        'ingredient': <Map<String, Object?>>[
          for (final name in ingredientNames)
            <String, Object?>{
              'item': <String, Object?>{
                'concept': <String, Object?>{'text': name},
              },
            },
        ],
    };

    return FhirR5MedicationProductPreview.projected(
      evaluatedAt: observedAt,
      medicationFragment: fragment,
      sourceProvenance: sourceProvenance,
      productStrengthEvidence: strengthEvidence,
    );
  }

  /// Projects a host-checked product snapshot into a development-only
  /// Medication fragment. Only an exact positive mass lexeme with a UCUM
  /// code in the local g/mg/ug subset, an exact `tablet` form, and no
  /// denominator or a unitless numeric denominator of one can populate the
  /// R5 strengthQuantity choice. This method never reads an intake or receipt.
  FhirR5MedicationProductPreview projectProductPack(
    MedicationProductPack product, {
    required DateTime observedAt,
    OpenFdaStrengthExpressionSourceManifest? sourceManifest,
  }) {
    final sourceProvenance = _packSourceProvenance(
      product,
      sourceManifest: sourceManifest,
    );
    final hostSourceIdentityValid = _hasSupportedSourceIdentity(product);
    final sourceRowBindingRequired = product.sourceSystem == 'OPENFDA_NDC';
    final strengthEvidence = <Map<String, Object?>>[
      for (var index = 0; index < product.ingredients.length; index++)
        (() {
          final ingredient = product.ingredients[index];
          final sourceRow = _matchOpenFdaSourceRow(
            product,
            ingredient,
            index,
            sourceManifest,
          );
          return _packStrengthEvidence(
            product,
            ingredient,
            index,
            hostSourceIdentityValid: hostSourceIdentityValid,
            sourceRowBindingRequired: sourceRowBindingRequired,
            sourceRow: sourceRow,
          );
        })(),
    ];
    final productName = product.primaryDisplayName.trim();
    final doseForm = _usableText(product.dosageForm);
    final ingredientNames = product.ingredients
        .map((ingredient) => ingredient.ingredientName.trim())
        .toList(growable: false);

    if (!_isSafeText(productName, maxLength: 512)) {
      return FhirR5MedicationProductPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'medication.fhir_r5.product_display_invalid',
        ],
        sourceProvenance: sourceProvenance,
        productStrengthEvidence: strengthEvidence,
      );
    }
    if (ingredientNames.any((name) => !_isSafeText(name, maxLength: 256))) {
      return FhirR5MedicationProductPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'medication.fhir_r5.ingredient_display_invalid',
        ],
        sourceProvenance: sourceProvenance,
        productStrengthEvidence: strengthEvidence,
      );
    }
    if (doseForm != null && !_isSafeText(doseForm, maxLength: 256)) {
      return FhirR5MedicationProductPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'medication.fhir_r5.dose_form_display_invalid',
        ],
        sourceProvenance: sourceProvenance,
        productStrengthEvidence: strengthEvidence,
      );
    }
    if (product.ingredients.isEmpty) {
      return FhirR5MedicationProductPreview.held(
        evaluatedAt: observedAt,
        reasonCodes: const <String>[
          'medication.fhir_r5.product_ingredient_identity_missing',
        ],
        sourceProvenance: sourceProvenance,
        productStrengthEvidence: strengthEvidence,
      );
    }

    final fragment = <String, Object?>{
      'resourceType': 'Medication',
      'code': <String, Object?>{'text': productName},
      if (doseForm != null) 'doseForm': <String, Object?>{'text': doseForm},
      'ingredient': <Map<String, Object?>>[
        for (var index = 0; index < product.ingredients.length; index++)
          <String, Object?>{
            'item': <String, Object?>{
              'concept': <String, Object?>{'text': ingredientNames[index]},
            },
            if (strengthEvidence[index]['fhir_strength_quantity']
                case final Map<String, Object?> strength)
              'strengthQuantity': strength,
          },
      ],
    };

    return FhirR5MedicationProductPreview.projected(
      evaluatedAt: observedAt,
      medicationFragment: fragment,
      sourceProvenance: sourceProvenance,
      productStrengthEvidence: strengthEvidence,
    );
  }

  List<Map<String, Object?>> _strengthEvidence(
    FhirInspiredMedicationKnowledgeView product,
  ) {
    final components = product.combinationComponents;
    if (components.isEmpty) {
      return List<Map<String, Object?>>.unmodifiable(
        product.activeIngredients.map(
          (name) => <String, Object?>{
            'ingredient_display': name,
            'source_value': null,
            'source_unit_display': null,
            'strength_basis':
                FhirInspiredMedicationKnowledgeView.kStrengthIsProductMetadata,
            'evidence_state': 'missing',
            'reason_code': 'medication.fhir_r5.source_strength_missing',
            'source_refs': const <String>[],
            'fhir_strength_path_projected': false,
            'algorithm_eligible': false,
          },
        ),
      );
    }
    return List<Map<String, Object?>>.unmodifiable(
      components.map((component) {
        final unit = _usableText(component.strengthUnit);
        final value = component.strengthValue;
        final finitePositive = value != null && value.isFinite && value > 0;
        final complete = finitePositive && unit != null;
        return <String, Object?>{
          'ingredient_display': component.ingredientName,
          'source_value': finitePositive ? value : null,
          'source_unit_display': unit,
          'strength_basis': component.strengthBasis,
          'evidence_state': complete
              ? 'product_metadata_only'
              : value == null && unit == null
              ? 'missing'
              : 'incomplete_or_invalid',
          'reason_code': complete
              ? 'medication.fhir_r5.strength_denominator_unresolved'
              : 'medication.fhir_r5.source_strength_missing_or_invalid',
          'source_refs': _sortedReferences(component.sourceRefs),
          'fhir_strength_path_projected': false,
          'algorithm_eligible': false,
        };
      }),
    );
  }

  Map<String, Object?> _packStrengthEvidence(
    MedicationProductPack product,
    MedicationIngredientStrength ingredient,
    int index, {
    required bool hostSourceIdentityValid,
    required bool sourceRowBindingRequired,
    required OpenFdaStrengthExpressionSourceRow? sourceRow,
  }) {
    final rawStrength = ingredient.rawStrength;
    final match = _exactStrengthPattern.firstMatch(rawStrength);
    final numeratorLexeme = match?.group(1);
    final numeratorUnitLexeme = match?.group(2);
    final denominatorLexeme = match?.group(3);
    final rawDenominatorUnitLexeme = match?.group(4);
    final denominatorUnitLexeme =
        rawDenominatorUnitLexeme == null || rawDenominatorUnitLexeme.isEmpty
        ? null
        : rawDenominatorUnitLexeme;
    final numeratorValue = numeratorLexeme == null
        ? null
        : double.tryParse(numeratorLexeme);
    final denominatorValue = denominatorLexeme == null
        ? null
        : double.tryParse(denominatorLexeme);
    final sourceNumerator = ingredient.numeratorValue;
    final sourceDenominator = ingredient.denominatorValue;
    final numeratorExact =
        numeratorValue != null &&
        numeratorValue.isFinite &&
        numeratorValue > 0 &&
        numeratorLexeme!.replaceAll('.', '').length <= 15 &&
        sourceNumerator != null &&
        sourceNumerator.isFinite &&
        sourceNumerator == numeratorValue &&
        ingredient.numeratorUnit?.trim() == numeratorUnitLexeme;
    final denominatorExact = denominatorLexeme == null
        ? sourceDenominator == null && ingredient.denominatorUnit == null
        : denominatorValue != null &&
              denominatorValue.isFinite &&
              denominatorValue > 0 &&
              denominatorLexeme.replaceAll('.', '').length <= 15 &&
              sourceDenominator != null &&
              sourceDenominator.isFinite &&
              sourceDenominator == denominatorValue &&
              ingredient.denominatorUnit?.trim() == denominatorUnitLexeme;
    final implicitOneTabletBasis =
        denominatorExact &&
        denominatorUnitLexeme == null &&
        (denominatorLexeme == null || denominatorValue == 1);
    final ucumCode = switch (numeratorUnitLexeme) {
      'g' || 'mg' || 'ug' => numeratorUnitLexeme,
      _ => null,
    };
    final exactTabletForm = product.dosageForm.trim().toLowerCase() == 'tablet';
    final sourceIdentityValid =
        hostSourceIdentityValid &&
        (!sourceRowBindingRequired || sourceRow != null);
    final projectStrength =
        sourceIdentityValid &&
        exactTabletForm &&
        numeratorExact &&
        denominatorExact &&
        implicitOneTabletBasis &&
        ucumCode != null;
    final reasonCode = projectStrength
        ? 'medication.fhir_r5.strength_quantity_projected_with_one_tablet_basis'
        : !hostSourceIdentityValid
        ? 'medication.fhir_r5.product_source_identity_unverified'
        : sourceRowBindingRequired && sourceRow == null
        ? 'medication.fhir_r5.product_source_row_binding_missing_or_ambiguous'
        : !exactTabletForm
        ? 'medication.fhir_r5.strength_tablet_basis_not_established'
        : !numeratorExact || !denominatorExact
        ? 'medication.fhir_r5.raw_strength_lexeme_mismatch_or_invalid'
        : ucumCode == null
        ? 'medication.fhir_r5.strength_unit_outside_reviewed_subset'
        : 'medication.fhir_r5.strength_denominator_unresolved';
    final evidence = <String, Object?>{
      'source_ingredient_index': index,
      'ingredient_display': ingredient.ingredientName,
      'source_raw_strength': rawStrength,
      'source_numerator_lexeme': numeratorLexeme,
      'source_value':
          sourceNumerator != null &&
              sourceNumerator.isFinite &&
              sourceNumerator > 0
          ? sourceNumerator
          : null,
      'source_unit_display': ingredient.numeratorUnit,
      'source_denominator_lexeme': denominatorLexeme,
      'source_denominator_value':
          sourceDenominator != null && sourceDenominator.isFinite
          ? sourceDenominator
          : null,
      'source_denominator_unit_display': ingredient.denominatorUnit,
      'denominator_basis': implicitOneTabletBasis
          ? denominatorLexeme == null
                ? 'assumed_one_tablet_from_fhir_quantity_semantics'
                : 'source_numeric_one_unitless_assumed_one_tablet'
          : 'unresolved',
      'evidence_state': projectStrength
          ? 'exact_source_strength_quantity'
          : 'held_product_metadata_only',
      'reason_code': reasonCode,
      'source_identity_checked': sourceIdentityValid,
      'source_row_binding_required': sourceRowBindingRequired,
      'source_row_binding_state': sourceRow != null
          ? 'exact_unique_local_snapshot_row_match'
          : sourceRowBindingRequired
          ? 'missing_ambiguous_or_mismatched'
          : 'not_required_for_source_system',
      if (sourceRow != null)
        'source_row_identity': <String, Object?>{
          'source_asset_sha256': sourceRow.sourceAssetSha256,
          'product_ndc': sourceRow.productNdc,
          'product_id': sourceRow.productId,
          'spl_id': sourceRow.splId,
          'ingredient_index': sourceRow.ingredientIndex,
          'ingredient_name': sourceRow.ingredientName,
          'parser_result_sha256': sourceRow.parseResult.sha256,
          'row_sha256': sourceRow.sha256,
        },
      'fhir_strength_path_projected': projectStrength,
      if (projectStrength)
        'fhir_strength_quantity': <String, Object?>{
          'value': numeratorValue,
          'unit': numeratorUnitLexeme,
          'system': FhirR5MedicationProductPreview.ucumSystem,
          'code': ucumCode,
        },
      'algorithm_eligible': false,
    };
    return evidence;
  }

  static final RegExp _exactStrengthPattern = RegExp(
    r'^\s*([0-9]+(?:\.[0-9]+)?)\s*([A-Za-z]+)'
    r'(?:\s*/\s*([0-9]+(?:\.[0-9]+)?)\s*([A-Za-z]*))?\s*$',
  );

  bool _hasSupportedSourceIdentity(MedicationProductPack product) {
    if (product.id.trim().isEmpty ||
        product.identifiers.every(
          (identifier) => identifier.value.trim().isEmpty,
        )) {
      return false;
    }
    final uri = Uri.tryParse(product.sourceUrl.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort) {
      return false;
    }
    return switch (product.sourceSystem) {
      'OPENFDA_NDC' =>
        product.jurisdiction == 'US' &&
            product.identifiers.any(
              (identifier) =>
                  identifier.system == MedicationIdentifierSystem.ndcProduct ||
                  identifier.system == MedicationIdentifierSystem.ndcPackage,
            ) &&
            uri.host == 'api.fda.gov' &&
            uri.path == '/drug/ndc.json',
      'HEALTH_CANADA_DPD' =>
        product.jurisdiction == 'CA' &&
            product.identifiers.any(
              (identifier) =>
                  identifier.system == MedicationIdentifierSystem.din,
            ) &&
            uri.host == 'health-products.canada.ca' &&
            uri.path.startsWith('/api/drug/'),
      _ => false,
    };
  }

  Map<String, Object?> _packSourceProvenance(
    MedicationProductPack product, {
    OpenFdaStrengthExpressionSourceManifest? sourceManifest,
  }) => <String, Object?>{
    'source_system': product.sourceSystem,
    'jurisdiction': product.jurisdiction,
    'source_url': product.sourceUrl,
    'source_retrieved_at_utc': product.retrievedAt?.toUtc().toIso8601String(),
    'retrieval_timestamp_state': product.retrievedAt == null
        ? 'not_supplied_by_importer'
        : 'importer_timestamp_preserved',
    'product_pack_id': product.id,
    'identifiers': product.identifiers
        .map((identifier) => identifier.toJson())
        .toList(growable: false),
    'full_source_response_hash_state': 'not_supplied_by_importer',
    'source_verification_state':
        'official_host_checked_only_not_independently_verified',
    if (sourceManifest != null &&
        product.sourceSystem ==
            OpenFdaStrengthExpressionSourceManifest.sourceSystem)
      'local_source_manifest': <String, Object?>{
        'schema_uri': OpenFdaStrengthExpressionSourceManifest.schemaUri,
        'source_system': OpenFdaStrengthExpressionSourceManifest.sourceSystem,
        'source_asset_path':
            OpenFdaStrengthExpressionSourceManifest.sourceAssetPath,
        'source_asset_sha256': sourceManifest.sourceAssetSha256,
        'source_url': sourceManifest.sourceUrl,
        'source_retrieved_at': sourceManifest.retrievedAt,
        'source_record_count': sourceManifest.sourceRecordCount,
        'ingredient_strength_row_count': sourceManifest.rows.length,
        'manifest_sha256': sourceManifest.sha256,
        'fda_data_verified': false,
        'clinical_or_algorithm_eligible': false,
      },
  };

  OpenFdaStrengthExpressionSourceRow? _matchOpenFdaSourceRow(
    MedicationProductPack product,
    MedicationIngredientStrength ingredient,
    int ingredientIndex,
    OpenFdaStrengthExpressionSourceManifest? sourceManifest,
  ) {
    if (sourceManifest == null ||
        product.sourceSystem !=
            OpenFdaStrengthExpressionSourceManifest.sourceSystem ||
        sourceManifest.sourceUrl != product.sourceUrl ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(sourceManifest.sourceAssetSha256)) {
      return null;
    }
    final productNdcs = product.identifiers
        .where(
          (identifier) =>
              identifier.system == MedicationIdentifierSystem.ndcProduct &&
              identifier.level == MedicationIdentifierLevel.product,
        )
        .map((identifier) => identifier.value.trim())
        .where((value) => value.isNotEmpty)
        .toSet();
    if (productNdcs.length != 1) return null;
    final candidates = sourceManifest.rows
        .where(
          (row) =>
              row.sourceAssetSha256 == sourceManifest.sourceAssetSha256 &&
              row.productNdc == productNdcs.single &&
              row.ingredientIndex == ingredientIndex &&
              row.ingredientName == ingredient.ingredientName &&
              row.parseResult.rawSourceValue == ingredient.rawStrength,
        )
        .toList(growable: false);
    return candidates.length == 1 ? candidates.single : null;
  }

  Map<String, Object?> _sourceProvenance(
    FhirInspiredMedicationKnowledgeView product,
  ) {
    final sourceRefs = <String>{
      ...product.sourceRefs,
      for (final component in product.combinationComponents)
        ...component.sourceRefs,
      for (final section in product.labelSectionRefs) ...section.sourceRefs,
    };
    return <String, Object?>{
      'view_type': FhirInspiredMedicationKnowledgeView.kViewType,
      'source_system': product.sourceSystem,
      'jurisdiction': product.jurisdiction,
      'language': product.language,
      'source_document': <String, Object?>{
        'id': product.sourceDocument.sourceDocId,
        'version': product.sourceDocument.sourceDocVersion,
        'effective_date': product.sourceDocument.effectiveDate,
      },
      'source_refs': _sortedReferences(sourceRefs),
      'metadata_completeness': product.metadataCompleteness,
    };
  }

  List<String> _sortedReferences(Iterable<String> references) =>
      List<String>.unmodifiable(references.toSet().toList()..sort());

  String? _usableText(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    if (const <String>{
      'unknown',
      'unspecified',
      'n/a',
    }.contains(value.toLowerCase())) {
      return null;
    }
    return value;
  }

  bool _isSafeText(String value, {required int maxLength}) =>
      value.isNotEmpty &&
      value.length <= maxLength &&
      !RegExp(r'[\u0000-\u001F\u007F]').hasMatch(value);
}
