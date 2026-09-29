import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/features/catalog/catalog_detail_pages.dart';

import 'helpers/page_test_harness.dart';

const _storedPayload = '{"fdcId":123,"description":"source payload"}';
const _payloadDigest =
    'ac624b67035e202924e904c4073d0790a7ec95c07be1a429715d4bdf04b60b0b';

FoodItem _foodWithProvenance() => FoodItem(
  id: 'food_fdc_123',
  name: 'Evidence food',
  category: FoodCategory.other,
  sourceSystem: 'USDA_FDC',
  sourceFoodCode: '123',
  jurisdiction: 'US',
  proteinG: 12,
  carbsG: 0,
  fatG: 0,
  fiberG: 0,
  sodiumMg: 0,
  missingNutrientFields: const <String>{'carbsG', 'energyKcal'},
  nutrientObservationEvidence: const <NutrientObservationEvidence>[
    NutrientObservationEvidence(
      observationId: 'obs_protein',
      domain: 'food',
      entityType: 'food_variant',
      entityKey: 'variant_123',
      attributeCode: 'protein_g',
      valueType: 'numeric_interval',
      valueNum: 12,
      low: 12,
      high: 12,
      qualifierKind: 'exact',
      rawValueText: '12',
      unit: 'g',
      basisType: 'per_100g_edible_part',
      basisAmount: 100,
      scopeHash: 'scope_123',
      sourceDocId: 'doc_fdc_123',
      recordLocator: '123:protein_g',
      methodCode: 'analytical_method_1',
      extractionConfidence: 0.95,
      selectedForLegacyPointProjection: true,
    ),
    NutrientObservationEvidence(
      observationId: 'obs_iron_lt',
      domain: 'food',
      entityType: 'food_variant',
      entityKey: 'variant_123',
      attributeCode: 'iron_mg',
      valueType: 'numeric_interval',
      valueNum: null,
      low: 0,
      high: 0.2,
      qualifierKind: 'lt',
      rawValueText: '<0.2',
      unit: 'mg',
      basisType: 'per_100g_edible_part',
      basisAmount: 100,
      scopeHash: 'scope_123',
      sourceDocId: 'doc_fdc_123',
      recordLocator: '123:iron_mg',
      methodCode: 'analytical_method_1',
      extractionConfidence: 0.95,
      selectedForLegacyPointProjection: false,
    ),
  ],
  catalogProvenanceEvidence: const FoodCatalogProvenanceEvidence(
    sourceDocuments: <FoodSourceDocumentEvidence>[
      FoodSourceDocumentEvidence(
        sourceDocId: 'doc_fdc_123',
        resolutionStatus: 'resolved',
        sourceFamily: 'USDA_FDC',
        dataTier: 'p0',
        ingestionStrategy: 'authoritative_direct',
        organization: 'USDA FoodData Central',
        jurisdiction: 'US',
        docType: 'catalog_import',
        title: 'Foundation Foods record 123',
        originUrl: 'https://fdc.nal.usda.gov/food-details/123',
        publishedAtEpochMs: 1735689600000,
        effectiveAtEpochMs: 1735689600000,
        language: 'en',
        licenseNote: 'US government work; terms retained',
        sourceRegistryChecksum: 'deadbeef',
        payloadSha256: _payloadDigest,
        storedPayloadPresent: true,
        sourceStatus: 'active',
      ),
      FoodSourceDocumentEvidence(
        sourceDocId: 'doc_missing',
        resolutionStatus: 'missing_source_document_row',
        sourceFamily: null,
        dataTier: null,
        ingestionStrategy: null,
        organization: null,
        jurisdiction: null,
        docType: null,
        title: null,
        originUrl: null,
        publishedAtEpochMs: null,
        effectiveAtEpochMs: null,
        language: null,
        licenseNote: null,
        sourceRegistryChecksum: null,
        payloadSha256: null,
        storedPayloadPresent: false,
        sourceStatus: null,
      ),
    ],
    variantScopes: <FoodVariantScopeEvidence>[
      FoodVariantScopeEvidence(
        scopeHash: 'scope_123',
        resolutionStatus: 'resolved',
        jurisdiction: 'US',
        brand: 'Example brand',
        preparationState: 'raw',
        cookingState: 'uncooked',
        plantPart: 'whole',
        cultivar: 'example cultivar',
        samplingFrame: 'Foundation Foods',
        dosageForm: null,
        releaseType: null,
        saltForm: null,
        route: null,
      ),
      FoodVariantScopeEvidence(
        scopeHash: 'scope_missing',
        resolutionStatus: 'missing_variant_scope_row',
        jurisdiction: null,
        brand: null,
        preparationState: null,
        cookingState: null,
        plantPart: null,
        cultivar: null,
        samplingFrame: null,
        dosageForm: null,
        releaseType: null,
        saltForm: null,
        route: null,
      ),
    ],
    conceptVariantMatches: <FoodConceptVariantMatchEvidence>[
      FoodConceptVariantMatchEvidence(
        crosswalkId: 'cw_fdc_123',
        domain: 'food',
        appEntityId: 'food_fdc_123',
        conceptId: 'food_123',
        variantId: 'variant_123',
        externalIdSystem: 'USDA_FDC',
        externalIdValue: '123',
        jurisdiction: 'US',
        sourceDocId: 'doc_fdc_123',
        importRunId: 'run_1',
        recordedConfidence: 0.91,
        status: 'active',
        mappingPayloadJson: '{"reason":"exact source code"}',
        createdAtEpochMs: 1735689600000,
        selectedForProjectedFoodId: true,
      ),
    ],
  ),
);

void main() {
  testWidgets('food details show source, scope, mapping and nutrient evidence', (
    tester,
  ) async {
    final food = _foodWithProvenance();
    await pumpFeaturePage(
      tester,
      FoodDetailPage(food: food, future: Future<ProjectedFoodDetail?>.value()),
      settle: true,
    );

    expect(find.text('Food catalog provenance'), findsOneWidget);
    expect(find.textContaining('USDA FoodData Central'), findsOneWidget);
    expect(find.textContaining('License note as recorded'), findsOneWidget);
    expect(find.textContaining(_payloadDigest), findsOneWidget);
    expect(
      find.textContaining('sampling frame Foundation Foods'),
      findsOneWidget,
    );
    expect(find.textContaining('not validated match accuracy'), findsOneWidget);
    expect(
      find.textContaining('selected for the current projected food ID'),
      findsOneWidget,
    );
    expect(find.textContaining('raw value 12'), findsOneWidget);
    expect(find.textContaining('qualifier exact'), findsOneWidget);
    expect(
      find.text('Selected for the current legacy point-value projection'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Evidence only; not selected for the legacy point-value projection',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Nutrients with no source value (unknown, not zero): carbsG, energyKcal',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Source uses a less-than qualifier: iron_mg = <0.2 (lt); no exact value is inferred.',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Linked record not found locally: doc_missing'),
      findsOneWidget,
    );
    expect(find.textContaining('scope_missing'), findsOneWidget);
    expect(
      find.textContaining('upstream release and query are not pinned'),
      findsOneWidget,
    );
    expect(find.textContaining(_storedPayload), findsNothing);
    expectNoWidgetErrors();
  });

  test('food provenance copy resolves in every shipped language family', () {
    const translationKeys = <String>[
      'detail.food_catalog_provenance_title',
      'detail.food_missing_nutrient_fields',
      'detail.food_nutrient_less_than_boundary',
      'detail.food_catalog_provenance_unavailable',
      'detail.food_catalog_source_documents',
      'detail.food_catalog_document_summary',
      'detail.food_catalog_license',
      'detail.food_catalog_source_dates',
      'detail.food_catalog_source_url',
      'detail.food_catalog_payload_digest',
      'detail.food_catalog_scopes',
      'detail.food_catalog_scope_summary',
      'detail.food_catalog_mappings',
      'detail.food_catalog_mapping_summary',
      'detail.food_catalog_mapping_selected',
      'detail.food_catalog_mapping_not_selected',
      'detail.food_catalog_mapping_payload',
      'detail.food_nutrient_observation_evidence',
      'detail.food_nutrient_observation_line',
      'detail.food_nutrient_projection_selected',
      'detail.food_nutrient_projection_evidence_only',
      'detail.food_catalog_unresolved',
      'detail.food_catalog_provenance_boundary',
    ];
    const parameters = <String, String>{
      'id': 'id',
      'fields': 'carbsG, energyKcal',
      'title': 'title',
      'organization': 'organization',
      'family': 'family',
      'type': 'type',
      'tier': 'tier',
      'jurisdiction': 'jurisdiction',
      'status': 'status',
      'value': 'value',
      'published': 'published',
      'effective': 'effective',
      'digest': 'digest',
      'hash': 'hash',
      'brand': 'brand',
      'preparation': 'preparation',
      'cooking': 'cooking',
      'plant': 'plant',
      'cultivar': 'cultivar',
      'sampling': 'sampling',
      'system': 'system',
      'externalId': 'externalId',
      'appId': 'appId',
      'confidence': 'confidence',
      'selection': 'selection',
      'attribute': 'attribute',
      'raw': 'raw',
      'qualifier': 'qualifier',
      'unit': 'unit',
      'basis': 'basis',
      'low': 'low',
      'high': 'high',
      'method': 'method',
      'source': 'source',
    };
    for (final family in AppI18n.translationFamilies) {
      final i18n = AppI18n.fromLocaleTag(family);
      for (final key in translationKeys) {
        final resolved = i18n.tr(key, parameters);
        expect(resolved, isNot(key), reason: '$family is missing $key');
        expect(resolved, isNot(contains(RegExp(r'\{[A-Za-z0-9_]+\}'))));
      }
    }
  });
}
