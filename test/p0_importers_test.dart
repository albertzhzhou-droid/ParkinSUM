import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/data/datasources/remote/ciqual_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/dailymed_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/ema_p1_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/fao_fbdg_p1_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/health_canada_dpd_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/pmda_p1_importer.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_recommendation_models.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';
import 'package:parkinsum_companion/domain/usecases/get_food_recommendations_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_recommendation_orchestrator.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_ingestion_orchestrator.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_source_urls.dart';
import 'package:parkinsum_companion/data/datasources/remote/secondary_source_registry.dart';
import 'package:parkinsum_companion/data/datasources/remote/secondary_source_registry_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/seed_catalog_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/regional_seed_catalog_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/catalog_interaction_audit.dart';
import 'package:parkinsum_companion/data/datasources/remote/locale_resource_seed_importer.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/data/datasources/remote/china_cdc_food_platform_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

// Test layout:
//   - Top-level tests: per-importer parser smoke tests (existing).
//   - group('Crosswalk generation'): per-source crosswalk + raw_payload audit
//     coverage (DailyMed, DPD, EMA, PMDA, FDC, Ciqual, China CDC, FAO).
//   - group('Resumable orchestrator'): retry / resume / metadata persistence
//     for both local-bytes and remote-fetch import paths.
void main() {
  test('Ciqual importer parses xml rows into foods and observations', () {
    const importer = CiqualP0Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final bundle = importer.importFromXmlStrings(
      alimXml: '''
<root>
  <row>
    <alim_code>1001</alim_code>
    <alim_nom_fr>Pomme</alim_nom_fr>
    <alim_nom_eng>Apple</alim_nom_eng>
    <alim_grp_code>FRT</alim_grp_code>
  </row>
</root>
''',
      alimGrpXml: '''
<root>
  <row>
    <alim_grp_code>FRT</alim_grp_code>
    <alim_grp_nom_fr>fruit</alim_grp_nom_fr>
  </row>
</root>
''',
      constXml: '''
<root>
  <row><const_code>PROT</const_code><const_nom_eng>Protein</const_nom_eng><unite>g</unite></row>
  <row><const_code>CARB</const_code><const_nom_eng>Carbohydrate</const_nom_eng><unite>g</unite></row>
</root>
''',
      compoXml: '''
<root>
  <row><alim_code>1001</alim_code><const_code>PROT</const_code><teneur>0.3</teneur></row>
  <row><alim_code>1001</alim_code><const_code>CARB</const_code><teneur>14</teneur></row>
</root>
''',
      sourcesXml: '<root />',
    );

    expect(bundle.foodConcepts, isNotEmpty);
    expect(bundle.foodVariants, isNotEmpty);
    expect(bundle.observations.length, 2);
    expect(bundle.projectedFoods.single.category, FoodCategory.fruit);
  });

  test('FDC importer maps nutrient rows into projected food', () {
    const importer = FdcP0Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final bundle = importer.importFoods([
      {
        'fdcId': 123,
        'description': 'Banana, raw',
        'dataType': 'Foundation',
        'foodCategory': 'fruit',
        'foodNutrients': [
          {
            'amount': 1.1,
            'nutrient': {'number': '203', 'name': 'Protein', 'unitName': 'g'}
          },
          {
            'amount': 22.8,
            'nutrient': {
              'number': '205',
              'name': 'Carbohydrate, by difference',
              'unitName': 'g'
            }
          },
        ],
      }
    ], sourceLabel: 'test_source');

    expect(bundle.projectedFoods.single.sourceFoodCode, '123');
    expect(bundle.projectedFoods.single.proteinG, 1.1);
    expect(bundle.projectedFoods.single.textureClass, isNull);
    expect(bundle.observations.length, 2);
  });

  test('FDC importer can read foundation JSON from zip', () {
    const importer = FdcP0Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final jsonBytes = utf8.encode(jsonEncode([
      {
        'fdcId': 321,
        'description': 'Oatmeal',
        'dataType': 'Foundation',
        'foodCategory': 'cereal',
        'foodNutrients': [
          {
            'amount': 13.0,
            'nutrient': {'number': '203', 'name': 'Protein', 'unitName': 'g'}
          }
        ]
      }
    ]));
    final archive = Archive()
      ..addFile(
        ArchiveFile(
          'foundationFoods.json',
          jsonBytes.length,
          jsonBytes,
        ),
      );
    final zipBytes = ZipEncoder().encode(archive)!;
    final bundle =
        importer.importZipBytes(zipBytes, sourceLabel: 'foundation_zip');

    expect(bundle.projectedFoods.single.sourceFoodCode, '321');
    expect(bundle.projectedFoods.single.proteinG, 13.0);
  });

  test('FDC importer assigns explicit liquid texture only when cues are clear',
      () {
    const importer = FdcP0Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final bundle = importer.importFoods([
      {
        'fdcId': 555,
        'description': 'Coffee, brewed, unsweetened',
        'dataType': 'Foundation',
        'foodCategory': 'beverage',
        'foodNutrients': [
          {
            'amount': 0.1,
            'nutrient': {'number': '203', 'name': 'Protein', 'unitName': 'g'}
          },
        ],
      }
    ], sourceLabel: 'texture_source');

    expect(bundle.projectedFoods.single.textureClass, 'liquid');
    expect(bundle.projectedFoods.single.iddsiLevel, 0);
  });

  test('DailyMed importer extracts drug basics from SPL xml', () {
    const importer = DailyMedP0Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final bundle = importer.importSplXml('''
<document>
  <setId root="abc-setid" />
  <title>Example Levodopa Tablet</title>
  <ingredient><name>levodopa</name></ingredient>
  <ingredient><name>carbidopa</name></ingredient>
  <routeCode displayName="oral" />
  <formCode displayName="tablet" />
  <section>
    <title>Drug and Food Interactions</title>
    <text>High protein meals may affect absorption. Iron salts or multivitamins containing iron may interfere. The product may be taken with or without food.</text>
  </section>
  <section>
    <title>Administration</title>
    <text>Take at least 1 hour before and at least 2 hours after meals.</text>
  </section>
</document>
''');

    expect(bundle.drugConcepts.single.genericName, 'levodopa/carbidopa');
    expect(bundle.projectedDrugs.single.tags, contains(DrugTag.levodopaLike));
    expect(bundle.projectedDrugs.single.route, 'oral');
    expect(bundle.drugLabelSections, isNotEmpty);
    final payload = jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
    final labelFacts =
        (payload['label_facts'] as List).cast<Map<dynamic, dynamic>>();
    expect(
      labelFacts.any((item) => item['fact_type'] == 'high_protein_effect'),
      isTrue,
    );
    expect(
      labelFacts.any((item) => item['fact_type'] == 'iron_interaction_warning'),
      isTrue,
    );
    expect(
      labelFacts.any((item) => item['fact_type'] == 'with_or_without_food'),
      isTrue,
    );
    expect(
      labelFacts.any((item) =>
          item['fact_type'] == 'meal_window_before_after' &&
          item['payload'] is Map &&
          (item['payload'] as Map)['before_minutes'] == 60 &&
          (item['payload'] as Map)['after_minutes'] == 120),
      isTrue,
    );
  });

  test('DPD importer builds projected Canadian drug variant', () {
    const importer = HealthCanadaDpdP0Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final bundle = importer.importFromPayloads(
      drugProducts: [
        {
          'drug_code': '111',
          'drug_identification_number': '22222222',
          'brand_name': 'Madopar',
          'pharmaceutical_form_code': 'TAB',
          'route_of_administration_code': 'ORAL',
          'drug_status_code': 'M'
        }
      ],
      activeIngredients: [
        {'drug_code': '111', 'ingredient_name': 'Levodopa'},
        {'drug_code': '111', 'ingredient_name': 'Benserazide'},
      ],
      forms: [
        {
          'pharmaceutical_form_code': 'TAB',
          'pharmaceutical_form_name': 'tablet'
        }
      ],
      routes: [
        {
          'route_of_administration_code': 'ORAL',
          'route_of_administration_name': 'oral'
        }
      ],
      statuses: [
        {'drug_status_code': 'M', 'status': 'marketed'}
      ],
    );

    expect(bundle.projectedDrugs.single.jurisdiction, 'CA');
    expect(bundle.projectedDrugs.single.genericName, 'Levodopa/Benserazide');
  });

  test('DPD importer extracts structured label facts from product detail page',
      () async {
    const infoUrl =
        'https://health-products.canada.ca/dpd-bdpp/info?code=111&lang=eng';
    const importer = HealthCanadaDpdP0Importer(
      fetchClient: FakeSourceFetchClient(
        textByUrl: {
          infoUrl: '''
<html>
  <body>
    <h2>Drug interactions</h2>
    <p>Iron salts or multivitamins containing iron may reduce bioavailability.</p>
    <h2>Administration</h2>
    <p>Take at least 1 hour before meals and at least 2 hours after meals.</p>
  </body>
</html>
''',
        },
      ),
    );
    final base = importer.importFromPayloads(
      drugProducts: [
        {
          'drug_code': '111',
          'drug_identification_number': '22222222',
          'brand_name': 'Madopar',
          'pharmaceutical_form_code': 'TAB',
          'route_of_administration_code': 'ORAL',
          'drug_status_code': 'M'
        }
      ],
      activeIngredients: [
        {'drug_code': '111', 'ingredient_name': 'Levodopa'},
        {'drug_code': '111', 'ingredient_name': 'Benserazide'},
      ],
      forms: [
        {
          'pharmaceutical_form_code': 'TAB',
          'pharmaceutical_form_name': 'tablet'
        }
      ],
      routes: [
        {
          'route_of_administration_code': 'ORAL',
          'route_of_administration_name': 'oral'
        }
      ],
      statuses: [
        {'drug_status_code': 'M', 'status': 'marketed'}
      ],
    );

    final enriched = await importer.enrichWithProductDetails(base);
    final detailDoc = enriched.sourceDocuments.firstWhere(
      (doc) => doc.docType == 'product_info_html',
    );
    final payload = jsonDecode(detailDoc.rawPayload) as Map<String, dynamic>;
    final labelFacts = payload['label_facts'] as List<dynamic>;

    expect(
      labelFacts.any((item) =>
          item is Map && item['fact_type'] == 'iron_interaction_warning'),
      isTrue,
    );
    expect(
      labelFacts.any((item) =>
          item is Map &&
          item['fact_type'] == 'meal_window_before_after' &&
          item['payload'] is Map &&
          (item['payload'] as Map)['before_minutes'] == 60 &&
          (item['payload'] as Map)['after_minutes'] == 120),
      isTrue,
    );
  });

  test('FAO importer builds P1 country diet profile bundle from official page',
      () {
    const importer = FaoFbdgP1Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final bundle = importer.importCountryPage(
      countryCode: 'CN',
      url:
          'https://www.fao.org/nutrition/education/food-dietary-guidelines/regions/countries/china/en/',
      html: '''
<html>
  <body>
    <h1>China</h1>
    <div>Official name Dietary Guidelines for Chinese (2022)</div>
    <h2>Messages</h2>
    <p>1. Eat a variety of foods, with cereals as the staple.</p>
    <p>2. Eat more vegetables, fruits, dairy, and whole grains.</p>
    <p>3. Eat appropriate amounts of fish, poultry, eggs, lean meats and soybeans.</p>
    <p>4. Reduce salt, oil and sugar.</p>
    <p>5. Drink enough water.</p>
    <h2>Food guide</h2>
  </body>
</html>
''',
    );

    expect(bundle.sourceDocuments, hasLength(1));
    expect(bundle.sourceDocuments.single.dataTier, KnowledgeDataTier.p1);
    expect(
      bundle.sourceDocuments.single.ingestionStrategy,
      SourceIngestionStrategy.officialReference,
    );
    expect(bundle.countryDietProfiles, hasLength(1));
    expect(bundle.countryDietProfiles.single.countryCode, 'CN');
    expect(
      bundle.countryDietProfiles.single.guidelineSource,
      'Dietary Guidelines for Chinese (2022)',
    );
    expect(
      bundle.countryDietProfiles.single.stapleFoodsJson,
      contains('cereals'),
    );
    expect(
      bundle.countryDietProfiles.single.preferredProteinSourcesJson,
      allOf(contains('fish'), contains('soybeans')),
    );
    expect(
      bundle.countryDietProfiles.single.avoidanceNotesJson,
      allOf(contains('reduce_salt'), contains('adequate_water')),
    );
  });

  test('EMA importer builds EU drug metadata from JSON', () {
    const importer = EmaP1Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final bundle = importer.importMedicinesJson(
      jsonEncode([
        {
          'ema_product_number': 'EMEA-H-C-000001',
          'medicine_name': 'Exampledopa',
          'active_substance': 'levodopa/carbidopa',
          'atc_code_human': 'N04BA02',
          'marketing_authorisation_developer_applicant_holder':
              'Example Pharma',
          'medicine_url': 'https://www.ema.europa.eu/en/medicines/exampledopa',
          'document_url':
              'https://www.ema.europa.eu/en/documents/product-information/exampledopa_en.pdf',
          'translations_url':
              'https://www.ema.europa.eu/en/documents/leaflet/exampledopa_leaflet_en.pdf',
          'pharmaceutical_form': 'prolonged-release tablet',
        }
      ]),
      sourceLabel: 'ema_test_json',
    );

    expect(bundle.drugProductVariants, hasLength(1));
    expect(bundle.drugProductVariants.single.regulator, 'EMA');
    expect(bundle.drugProductVariants.single.jurisdiction, 'EU');
    expect(bundle.drugProductVariants.single.releaseType, 'extended_release');
    expect(bundle.drugConcepts.single.genericName, 'levodopa/carbidopa');
    expect(bundle.projectedDrugs.single.sourceSystem, 'EMA');
    expect(bundle.drugProductMedias, isNotEmpty);
  });

  test('EMA importer reads first worksheet from XLSX', () {
    const importer = EmaP1Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final xlsxBytes = _buildMinimalXlsx(
      headers: const [
        'ema_product_number',
        'medicine_name',
        'active_substance',
        'atc_code_human',
      ],
      rows: const [
        ['EMEA-H-C-000002', 'Patchmed', 'rotigotine', 'N04BC09'],
      ],
    );
    final bundle = importer.importMedicinesXlsx(
      xlsxBytes,
      sourceLabel: 'ema_test_xlsx',
    );

    expect(bundle.drugProductVariants, hasLength(1));
    expect(bundle.drugConcepts.single.genericName, 'rotigotine');
    expect(bundle.projectedDrugs.single.brandNames.single, 'Patchmed');
  });

  test(
      'EMA post-authorisation importer keeps document metadata without forcing projected drugs',
      () {
    const importer = EmaP1Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final bundle = importer.importPostAuthorisationJson(
      jsonEncode([
        {
          'ema_product_number': 'EMEA-H-C-999999',
          'medicine_name': 'Exampledopa',
          'active_substance': 'levodopa/carbidopa',
          'medicine_url': 'https://www.ema.europa.eu/en/medicines/exampledopa',
          'document_url':
              'https://www.ema.europa.eu/en/documents/variation/exampledopa-change_en.pdf',
          'procedure_type': 'II',
        }
      ]),
      sourceLabel: 'ema_post_auth_json',
    );

    expect(bundle.drugProductVariants, hasLength(1));
    expect(bundle.projectedDrugs, isEmpty);
    expect(
      bundle.drugProductMedias.any((item) => item.mediaType == 'document_link'),
      isTrue,
    );
  });

  test('PMDA importer marks english index as reference only', () {
    const importer = PmdaP1Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final bundle = importer.importEnglishReferenceIndex('''
<html>
  <head><title>English-Translated Package Inserts | PMDA</title></head>
  <body>
    <a href="/files/0001/example_insert.pdf">English translated package insert</a>
  </body>
</html>
''');

    expect(bundle.sourceDocuments.single.sourceStatus, 'reference_only');
    expect(bundle.sourceDocuments.single.dataTier, KnowledgeDataTier.p1);
    expect(
      bundle.sourceDocuments.single.ingestionStrategy,
      SourceIngestionStrategy.officialReference,
    );
    expect(bundle.drugProductMedias.single.mediaUrl,
        contains('example_insert.pdf'));
  });

  test('PMDA importer builds Japanese product metadata bundle', () {
    const importer = PmdaP1Importer(
      fetchClient: FakeSourceFetchClient(textByUrl: {}),
    );
    final bundle = importer.importJapaneseProductDetail(
      detailUrl:
          'https://www.pmda.go.jp/PmdaSearch/iyakuDetail/GeneralList/12345',
      html: '''
<html>
  <head><title>医療用医薬品 : サンプル薬</title></head>
  <body>
    <h1>サンプル薬錠 100mg</h1>
    <a href="/files/0001/package_insert.pdf">添付文書</a>
    <a href="/files/0001/interview_form.pdf">インタビューフォーム</a>
    <a href="/files/0001/rmp.pdf">RMP</a>
  </body>
</html>
''',
    );

    expect(bundle.sourceDocuments.single.language, 'ja');
    expect(bundle.drugProductVariants.single.regulator, 'PMDA');
    expect(bundle.projectedDrugs.single.sourceSystem, 'PMDA');
    expect(bundle.drugProductMedias.length, 3);
  });

  test('next meal orchestrator falls back to conservative path', () async {
    final orchestrator = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: CdssCatalogProjectionService(
        database: _FakeCdssDatabase(),
      ),
      localAiAdapter: null,
    );
    final result = await orchestrator.recommend(
      request: NextMealRecommendationRequest(
        userProfile: UserProfile.defaults(),
        history: const [],
        activeDrugs: const [],
        intakes: const [],
        now: DateTime(2026, 4, 16),
        mode: RecommendationMode.hybridLocalLlm,
        userConsentedToAi: false,
      ),
      candidateFoods: [
        FoodItem(
          id: 'banana',
          name: 'Banana',
          category: FoodCategory.fruit,
          proteinG: 1,
          carbsG: 20,
          fatG: 0,
          fiberG: 2,
          sodiumMg: 1,
        ),
      ],
    );

    expect(result.aiUsed, isFalse);
    expect(result.decisionPath, 'conservative_cdss');
    expect(result.recommendations, isNotEmpty);
  });

  test('next meal orchestrator surfaces imported official label facts',
      () async {
    final orchestrator = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: CdssCatalogProjectionService(
        database: _FakeCdssDatabase(
          tables: {
            'drug_product_variant': [
              {
                'drug_product_variant_id':
                    'DRUG_OPICAPONE#US#DAILYMED#drug_opicapone',
                'external_product_code': 'drug_opicapone',
                'jurisdiction': 'US',
              },
            ],
            'drug_label_section': [
              {
                'drug_product_variant_id':
                    'DRUG_OPICAPONE#US#DAILYMED#drug_opicapone',
                'source_doc_id': 'doc_opicapone',
                'section_key': 'dosage_administration',
                'section_title': 'Dosage and Administration',
                'section_text':
                    'Take at least 1 hour before and at least 2 hours after meals.',
              },
            ],
            'source_document': [
              {
                'source_doc_id': 'doc_opicapone',
                'title': 'Imported opicapone label fact',
                'raw_payload': jsonEncode({
                  'label_facts': [
                    {
                      'fact_type': 'meal_window_before_after',
                      'label': 'Meal separation',
                      'value_text':
                          'at least 1 hour before and 2 hours after meals',
                      'payload': {
                        'before_minutes': 60,
                        'after_minutes': 120,
                      },
                    },
                  ],
                }),
              },
            ],
          },
        ),
      ),
      localAiAdapter: null,
    );
    final result = await orchestrator.recommend(
      request: NextMealRecommendationRequest(
        userProfile: UserProfile.defaults(),
        history: const [],
        activeDrugs: [
          DrugDefinition(
            id: 'opicapone_active',
            genericName: 'Opicapone',
            brandNames: const ['Ongentys'],
            tags: const [DrugTag.comtInhibitor],
            notes: '',
            sourceSystem: 'DAILYMED',
            sourceProductCode: 'drug_opicapone',
            jurisdiction: 'US',
          ),
        ],
        intakes: const [],
        now: DateTime(2026, 4, 16),
        mode: RecommendationMode.conservativeOnly,
        userConsentedToAi: false,
      ),
      candidateFoods: [
        FoodItem(
          id: 'banana',
          name: 'Banana',
          category: FoodCategory.fruit,
          proteinG: 1,
          carbsG: 20,
          fatG: 0,
          fiberG: 2,
          sodiumMg: 1,
        ),
      ],
    );

    expect(
      result.explanations.any(
        (line) =>
            line.contains('Opicapone') &&
            line.contains('requires separation from meals'),
      ),
      isTrue,
    );
  });

  test('next meal orchestrator surfaces meal context explanations and gates',
      () async {
    final orchestrator = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: CdssCatalogProjectionService(
        database: _FakeCdssDatabase(),
      ),
      localAiAdapter: null,
    );
    final result = await orchestrator.recommend(
      request: NextMealRecommendationRequest(
        userProfile: UserProfile.defaults().copyWith(
          localAiConsentEnabled: true,
        ),
        history: [
          Meal(
            id: 'meal_ctx',
            title: 'Tube feed meal',
            eatenAt: DateTime.utc(2026, 4, 16, 8),
            coeventSubstanceTags: const ['iron_salt'],
            enteralFeedMode: 'continuous',
            enteralFeedProteinGPerDay: 82,
            nextMealWindowStart: DateTime.utc(2026, 4, 16, 12),
            nextMealWindowEnd: DateTime.utc(2026, 4, 16, 13),
            items: const [],
          ),
        ],
        activeDrugs: const [],
        intakes: const [],
        now: DateTime(2026, 4, 16),
        mode: RecommendationMode.hybridLocalLlm,
        userConsentedToAi: true,
      ),
      candidateFoods: [
        FoodItem(
          id: 'banana',
          name: 'Banana',
          category: FoodCategory.fruit,
          proteinG: 1,
          carbsG: 20,
          fatG: 0,
          fiberG: 2,
          sodiumMg: 1,
        ),
      ],
    );

    expect(
      result.explanations.any(
        (line) => line.contains('iron supplement') || line.contains('iron'),
      ),
      isTrue,
    );
    expect(
      result.explanations.any(
        (line) => line.contains('enteral feeding') || line.contains('82'),
      ),
      isTrue,
    );
    expect(
      result.gateReasons.any(
        (line) => line.contains('Continuous enteral feeding context'),
      ),
      isTrue,
    );
  });

  test('recommendation use case adds context penalties into score breakdown',
      () {
    final recommendations = GetFoodRecommendationsUseCase().call(
      history: [
        Meal(
          id: 'ctx_meal',
          title: 'Context meal',
          eatenAt: DateTime.utc(2026, 4, 16, 8),
          coeventSubstanceTags: const ['iron_salt'],
          thickenerType: 'starch_based',
          enteralFeedMode: 'continuous',
          enteralFeedProteinGPerDay: 80,
          items: const [],
        ),
      ],
      drugs: [
        DrugDefinition(
          id: 'ldopa',
          genericName: 'Levodopa/Carbidopa',
          brandNames: const ['Sinemet'],
          tags: const [DrugTag.levodopaLike],
          notes: '',
        ),
      ],
      allFoods: [
        FoodItem(
          id: 'high_protein',
          name: 'Chicken breast',
          category: FoodCategory.protein,
          sourceSystem: 'FDC',
          jurisdiction: 'US',
          proteinG: 27,
          carbsG: 0,
          fatG: 4,
          fiberG: 0,
          sodiumMg: 60,
        ),
        FoodItem(
          id: 'low_protein',
          name: 'Banana',
          category: FoodCategory.fruit,
          sourceSystem: 'FDC',
          jurisdiction: 'US',
          proteinG: 1,
          carbsG: 20,
          fatG: 0,
          fiberG: 2,
          sodiumMg: 1,
        ),
      ],
      userProfile: UserProfile.defaults(),
    );

    final highProtein =
        recommendations.firstWhere((item) => item.food.id == 'high_protein');
    expect(highProtein.scoreBreakdown['meal_context_penalty'], greaterThan(0));
    expect(
        highProtein.scoreBreakdown['context_data_gap_penalty'], greaterThan(0));
    expect(
        highProtein.scoreBreakdown['context_penalty_points'], greaterThan(0));
    expect(
      highProtein.reasons.any(
        (line) =>
            line.contains('铁') || line.contains('Iron') || line.contains('fer'),
      ),
      isTrue,
    );
    expect(
      highProtein.reasons.any(
        (line) =>
            line.contains('增稠剂') ||
            line.contains('thickener') ||
            line.contains('texture'),
      ),
      isTrue,
    );
  });

  test(
      'recommendation use case lowers texture gap penalty when structured texture exists',
      () {
    final recommendations = GetFoodRecommendationsUseCase().call(
      history: [
        Meal(
          id: 'ctx_meal_texture',
          title: 'Texture context meal',
          eatenAt: DateTime.utc(2026, 4, 16, 8),
          thickenerType: 'starch_based',
          items: const [],
        ),
      ],
      drugs: const [],
      allFoods: [
        FoodItem(
          id: 'liquid_candidate',
          name: 'Coffee',
          category: FoodCategory.beverage,
          sourceSystem: 'FDC',
          jurisdiction: 'US',
          textureClass: 'liquid',
          iddsiLevel: 0,
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          fiberG: 0,
          sodiumMg: 1,
        ),
        FoodItem(
          id: 'unknown_texture_candidate',
          name: 'Unknown food',
          category: FoodCategory.other,
          sourceSystem: 'FDC',
          jurisdiction: 'US',
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          fiberG: 0,
          sodiumMg: 1,
        ),
      ],
      userProfile: UserProfile.defaults(),
    );

    final liquid = recommendations
        .firstWhere((item) => item.food.id == 'liquid_candidate');
    final unknown = recommendations
        .firstWhere((item) => item.food.id == 'unknown_texture_candidate');

    expect(liquid.scoreBreakdown['context_data_gap_penalty'], 0.0);
    expect(unknown.scoreBreakdown['context_data_gap_penalty'], greaterThan(0));
    expect(
      liquid.reasons.any(
        (line) =>
            line.contains('结构化质地') ||
            line.contains('structured texture') ||
            line.contains('texture'),
      ),
      isTrue,
    );
  });

  test('recommendation use case penalizes candidates outside liquid-only mode',
      () {
    final recommendations = GetFoodRecommendationsUseCase().call(
      history: const [],
      drugs: const [],
      allFoods: [
        FoodItem(
          id: 'liquid_candidate',
          name: 'Coffee',
          category: FoodCategory.beverage,
          sourceSystem: 'FDC',
          jurisdiction: 'US',
          textureClass: 'liquid',
          iddsiLevel: 0,
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          fiberG: 0,
          sodiumMg: 1,
        ),
        FoodItem(
          id: 'soft_candidate',
          name: 'Tofu',
          category: FoodCategory.protein,
          sourceSystem: 'FDC',
          jurisdiction: 'US',
          textureClass: 'soft',
          iddsiLevel: 4,
          proteinG: 8,
          carbsG: 2,
          fatG: 4,
          fiberG: 1,
          sodiumMg: 5,
        ),
      ],
      userProfile: UserProfile.defaults().copyWith(
        swallowingTextureMode: 'liquid_only',
      ),
    );

    final liquid = recommendations
        .firstWhere((item) => item.food.id == 'liquid_candidate');
    final soft =
        recommendations.firstWhere((item) => item.food.id == 'soft_candidate');

    expect(liquid.score, greaterThan(soft.score));
    expect(liquid.scoreBreakdown['swallowing_texture_penalty'], 0.0);
    expect(soft.scoreBreakdown['swallowing_texture_penalty'], greaterThan(0));
    expect(
      soft.reasons.any(
        (line) =>
            line.contains('质地安全偏好') ||
            line.contains('texture safety mode') ||
            line.contains('texture'),
      ),
      isTrue,
    );
  });

  test('next meal orchestrator applies meal-template texture affinity',
      () async {
    final orchestrator = NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: CdssCatalogProjectionService(
        database: _FakeCdssDatabase(),
      ),
      localAiAdapter: null,
    );
    final result = await orchestrator.recommend(
      request: NextMealRecommendationRequest(
        userProfile: UserProfile.defaults(),
        history: [
          Meal(
            id: 'history_breakfast_template',
            title: 'Latest meal',
            eatenAt: DateTime.utc(2026, 4, 16, 6, 30),
            nextMealWindowStart: DateTime.utc(2026, 4, 16, 8, 0),
            nextMealWindowEnd: DateTime.utc(2026, 4, 16, 9, 0),
            items: const [],
          ),
        ],
        activeDrugs: const [],
        intakes: const [],
        now: DateTime.utc(2026, 4, 16, 7, 0),
        mode: RecommendationMode.conservativeOnly,
        userConsentedToAi: false,
      ),
      candidateFoods: [
        FoodItem(
          id: 'soft_breakfast',
          name: 'Oatmeal',
          category: FoodCategory.carbs,
          sourceSystem: 'LOCAL_SEED',
          jurisdiction: 'US',
          textureClass: 'soft',
          iddsiLevel: 4,
          proteinG: 5,
          carbsG: 25,
          fatG: 3,
          fiberG: 3,
          sodiumMg: 2,
        ),
        FoodItem(
          id: 'regular_breakfast',
          name: 'Toast',
          category: FoodCategory.carbs,
          sourceSystem: 'LOCAL_SEED',
          jurisdiction: 'US',
          textureClass: 'regular',
          iddsiLevel: 7,
          proteinG: 5,
          carbsG: 25,
          fatG: 3,
          fiberG: 3,
          sodiumMg: 2,
        ),
      ],
    );

    final soft = result.recommendations
        .firstWhere((item) => item.food.id == 'soft_breakfast');
    final regular = result.recommendations
        .firstWhere((item) => item.food.id == 'regular_breakfast');

    expect(result.templateCountryCode, 'US');
    expect(result.templateMealSlot, 'breakfast');
    expect(result.templateTextureLevel, 'soft');
    expect(soft.score, greaterThan(regular.score));
    expect(soft.scoreBreakdown['template_texture_affinity'], 1.0);
    expect(regular.scoreBreakdown['template_texture_affinity'], 0.2);
    expect(
      soft.reasons.any(
        (line) =>
            line.contains('模板') ||
            line.contains('meal-template') ||
            line.contains('modele de repas'),
      ),
      isTrue,
    );
  });

  group('Crosswalk generation', () {
    test('DailyMed importer emits setid + NDC + package crosswalks', () {
      const importer = DailyMedP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importSplXml(
        '''
<document>
  <setId root="abc-setid" />
  <title>Example Levodopa Tablet</title>
  <ingredient><name>levodopa</name></ingredient>
  <routeCode displayName="oral" />
  <formCode displayName="tablet" />
</document>
''',
        ndcs: const [
          {'ndc': '12345-678-90', 'package_description': '30 tablets'},
        ],
        packaging: const [
          {
            'package_ndc': '12345-678-91',
            'description': 'bottle of 100',
            'marketing_status': 'active'
          }
        ],
      );
      final systems = bundle.conceptVariantCrosswalks
          .map((row) => row.externalIdSystem)
          .toSet();
      expect(systems, contains('DailyMed setid'));
      expect(systems, contains('NDC'));
      expect(systems, contains('DailyMed package code'));
      expect(
        bundle.conceptVariantCrosswalks
            .where((row) => row.externalIdValue == '12345-678-90'),
        isNotEmpty,
      );
      final packagePayload = jsonDecode(bundle.conceptVariantCrosswalks
          .firstWhere((row) => row.externalIdSystem == 'DailyMed package code')
          .mappingPayloadJson) as Map;
      expect(packagePayload['non_promoted_fields'],
          contains('package_description_quantity_parse'));
      expect(packagePayload.containsKey('quantity'), isFalse);
      expect(packagePayload.containsKey('size'), isFalse);
      expect(packagePayload.containsKey('unit'), isFalse);
    });

    test('DPD importer emits DIN, drug_code and package crosswalks', () {
      const importer = HealthCanadaDpdP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importFromPayloads(
        drugProducts: [
          {
            'drug_code': '111',
            'drug_identification_number': '22222222',
            'brand_name': 'Madopar',
            'pharmaceutical_form_code': 'TAB',
            'route_of_administration_code': 'ORAL',
            'drug_status_code': 'M'
          }
        ],
        activeIngredients: [
          {'drug_code': '111', 'ingredient_name': 'Levodopa'},
        ],
        forms: [
          {'pharmaceutical_form_code': 'TAB', 'pharmaceutical_form_name': 'tab'}
        ],
        packaging: [
          {
            'drug_code': '111',
            'package': 'bottle of 60',
            'upc': '0123456789',
            'status': 'active',
          }
        ],
        routes: [
          {
            'route_of_administration_code': 'ORAL',
            'route_of_administration_name': 'oral'
          }
        ],
        statuses: [
          {'drug_status_code': 'M', 'status': 'marketed'}
        ],
      );
      final systems = bundle.conceptVariantCrosswalks
          .map((row) => row.externalIdSystem)
          .toSet();
      expect(systems, contains('Health Canada DIN'));
      expect(systems, contains('Health Canada DPD drug_code'));
      expect(systems, contains('Health Canada DPD UPC'));
      final upcPayload = jsonDecode(bundle.conceptVariantCrosswalks
          .firstWhere((row) => row.externalIdSystem == 'Health Canada DPD UPC')
          .mappingPayloadJson) as Map;
      expect(upcPayload['source_identifier_type'], 'package_or_portion_code');
      expect(upcPayload['confidence_reason'], contains('UPC copied'));
    });

    test('EMA importer emits product number + URL crosswalks', () {
      const importer = EmaP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importMedicinesJson(
        jsonEncode([
          {
            'ema_product_number': 'EMEA-H-C-000123',
            'medicine_name': 'Exampledopa',
            'active_substance': 'levodopa/carbidopa',
            'atc_code_human': 'N04BA02',
            'medicine_url': 'https://www.ema.europa.eu/en/medicines/x',
            'document_url':
                'https://www.ema.europa.eu/en/documents/product-information/x_en.pdf',
            'translations_url':
                'https://www.ema.europa.eu/en/documents/leaflet/x_en.pdf',
          }
        ]),
        sourceLabel: 'ema_test_json',
      );
      final systems = bundle.conceptVariantCrosswalks
          .map((row) => row.externalIdSystem)
          .toSet();
      expect(systems, contains('EMA product number'));
      expect(systems, contains('EMA ATC code'));
      expect(systems, contains('EMA medicine URL'));
      expect(systems, contains('EMA SmPC URL'));
      expect(systems, contains('EMA leaflet URL'));
      for (final row in bundle.conceptVariantCrosswalks) {
        final payload = jsonDecode(row.mappingPayloadJson) as Map;
        expect(payload.containsKey('source_identifier_type'), isTrue);
        expect(payload.containsKey('confidence_reason'), isTrue);
        expect(payload.containsKey('promoted_fields'), isTrue);
        expect(payload.containsKey('non_promoted_fields'), isTrue);
      }
    });

    test(
        'PMDA english index crosswalks are reference_only, JP detail authoritative',
        () {
      const importer = PmdaP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final englishBundle = importer.importEnglishReferenceIndex('''
<html>
  <body>
    <a href="/files/0001/example_insert.pdf">English translated package insert</a>
  </body>
</html>
''');
      expect(englishBundle.conceptVariantCrosswalks, isNotEmpty);
      expect(
        englishBundle.conceptVariantCrosswalks
            .every((row) => row.status == 'reference_only'),
        isTrue,
      );

      final japaneseBundle = importer.importJapaneseProductDetail(
        detailUrl:
            'https://www.pmda.go.jp/PmdaSearch/iyakuDetail/GeneralList/12345',
        html: '<html><h1>サンプル薬</h1></html>',
      );
      expect(
        japaneseBundle.conceptVariantCrosswalks
            .any((row) => row.externalIdSystem == 'PMDA Japanese product code'),
        isTrue,
      );
      expect(
        japaneseBundle.conceptVariantCrosswalks
            .every((row) => row.status == 'active'),
        isTrue,
      );
    });

    test(
        'FDC importer emits food code crosswalks and records portion audit gap',
        () {
      const importer = FdcP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importFoods([
        {
          'fdcId': 999,
          'description': 'Cheddar cheese',
          'dataType': 'Foundation',
          'foodCategory': 'dairy',
          'ndbNumber': '01009',
          'foodNutrients': [
            {
              'amount': 25.0,
              'nutrient': {'number': '203', 'name': 'Protein', 'unitName': 'g'}
            }
          ],
          'foodPortions': [
            {
              'amount': 1,
              'modifier': 'cup, diced',
              'gramWeight': 132.0,
              'measureUnit': {'name': 'cup'}
            }
          ],
        }
      ], sourceLabel: 'fdc_portion_test');
      final systems = bundle.conceptVariantCrosswalks
          .map((row) => row.externalIdSystem)
          .toSet();
      expect(systems, contains('FDC id'));
      expect(systems, contains('USDA NDB number'));

      final payload =
          jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      final audit = payload['food_portions_audit'] as List;
      expect(audit, isNotEmpty);
      final entry = audit.first as Map;
      expect(entry['fdc_id'], '999');
      expect(entry['field'], 'foodPortions');
      expect(entry['reason'], contains('raw_payload only'));
      // Main fact tables remain limited to nutrient observations.
      expect(bundle.observations, hasLength(1));
    });

    test('Ciqual importer emits food code crosswalks', () {
      const importer = CiqualP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importFromXmlStrings(
        alimXml: '''
<root>
  <row>
    <alim_code>1001</alim_code>
    <alim_nom_fr>Pomme</alim_nom_fr>
    <alim_nom_eng>Apple</alim_nom_eng>
    <alim_grp_code>FRT</alim_grp_code>
  </row>
</root>
''',
        alimGrpXml: '''
<root>
  <row>
    <alim_grp_code>FRT</alim_grp_code>
    <alim_grp_nom_fr>fruit</alim_grp_nom_fr>
  </row>
</root>
''',
        constXml: '''
<root>
  <row><const_code>PROT</const_code><const_nom_eng>Protein</const_nom_eng><unite>g</unite></row>
</root>
''',
        compoXml: '''
<root>
  <row><alim_code>1001</alim_code><const_code>PROT</const_code><teneur>0.3</teneur></row>
</root>
''',
        sourcesXml: '<root />',
      );
      final crosswalk = bundle.conceptVariantCrosswalks.single;
      expect(crosswalk.externalIdSystem, 'Ciqual food code');
      expect(crosswalk.externalIdValue, '1001');
      expect(crosswalk.jurisdiction, 'FR');
    });

    test('China CDC importer emits page code crosswalk with audit note', () {
      const importer = ChinaCdcFoodPlatformImporter(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importFoodPage(
        url: 'https://nlc.chinanutri.cn/fq/foodinfo/333.html',
        html: '''
<html><body>
豆腐
食物类：豆类
亚 类：豆制品
蛋白质(Protein) 8.1
脂肪(Fat) 3.7
碳水化合物(CHO) 4.2
钠(Na) 7.2
</body></html>
''',
      );
      final crosswalk = bundle.conceptVariantCrosswalks.single;
      expect(crosswalk.externalIdSystem, 'China CDC food page id');
      expect(crosswalk.externalIdValue, '333');
      expect(crosswalk.mappingPayloadJson, contains('audit_note'));
    });

    test('DailyMed adds section + media crosswalks alongside NDC', () {
      const importer = DailyMedP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importSplXml(
        '''
<document>
  <setId root="setid-deep" />
  <title>Deep Tablet</title>
  <ingredient><name>levodopa</name></ingredient>
  <routeCode displayName="oral" />
  <formCode displayName="tablet" />
  <section><title>Indications</title><text>For symptomatic relief.</text></section>
</document>
''',
        ndcs: const [
          {'ndc': '00000-0001-01', 'package_description': '30 tablets'}
        ],
        media: const [
          {
            'url': 'https://dailymed.example/media/x.png',
            'type': 'image/png',
            'name': 'label image'
          }
        ],
      );
      final domains =
          bundle.conceptVariantCrosswalks.map((row) => row.domain).toSet();
      expect(
          domains, containsAll(['drug', 'drug_label_section', 'drug_media']));
      expect(
        bundle.conceptVariantCrosswalks.any((row) =>
            row.externalIdSystem == 'DailyMed media URL' &&
            row.externalIdValue.contains('x.png')),
        isTrue,
      );
    });

    test('DPD product detail enrichment adds info URL + monograph crosswalks',
        () async {
      const infoUrl =
          'https://health-products.canada.ca/dpd-bdpp/info?code=42&lang=eng';
      const importer = HealthCanadaDpdP0Importer(
        fetchClient: FakeSourceFetchClient(
          textByUrl: {
            infoUrl: '''
<html>
  <body>
    <h2>Product details</h2>
    <a href="https://health-products.canada.ca/monograph/42.pdf">Product monograph</a>
  </body>
</html>
''',
          },
        ),
      );
      final base = importer.importFromPayloads(
        drugProducts: [
          {
            'drug_code': '42',
            'drug_identification_number': '99999999',
            'brand_name': 'DeepCheck',
            'pharmaceutical_form_code': 'TAB',
            'route_of_administration_code': 'ORAL',
            'drug_status_code': 'M'
          }
        ],
        activeIngredients: [
          {'drug_code': '42', 'ingredient_name': 'Levodopa'}
        ],
        forms: [
          {'pharmaceutical_form_code': 'TAB', 'pharmaceutical_form_name': 'tab'}
        ],
        routes: [
          {
            'route_of_administration_code': 'ORAL',
            'route_of_administration_name': 'oral'
          }
        ],
        statuses: [
          {'drug_status_code': 'M', 'status': 'marketed'}
        ],
      );
      final enriched = await importer.enrichWithProductDetails(base);
      final systems = enriched.conceptVariantCrosswalks
          .map((row) => row.externalIdSystem)
          .toSet();
      expect(systems, contains('Health Canada DPD info URL'));
      expect(systems, contains('Health Canada DPD monograph URL'));
      final monograph = enriched.conceptVariantCrosswalks.firstWhere(
          (row) => row.externalIdSystem == 'Health Canada DPD monograph URL');
      expect(monograph.domain, 'drug_monograph');
      expect(monograph.externalIdValue, contains('monograph/42.pdf'));
    });

    test('EMA importer adds explicit EPAR URL crosswalk when present', () {
      const importer = EmaP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importMedicinesJson(
        jsonEncode([
          {
            'ema_product_number': 'EMEA-H-C-EPAR-1',
            'medicine_name': 'EparMed',
            'active_substance': 'levodopa',
            'medicine_url': 'https://www.ema.europa.eu/en/medicines/eparmed',
            'epar_url':
                'https://www.ema.europa.eu/en/documents/assessment-report/eparmed_en.pdf',
          }
        ]),
        sourceLabel: 'ema_epar_test',
      );
      expect(
        bundle.conceptVariantCrosswalks.any((row) =>
            row.externalIdSystem == 'EMA EPAR URL' &&
            row.externalIdValue.endsWith('eparmed_en.pdf')),
        isTrue,
      );
    });

    test('PMDA japanese detail emits per-link document crosswalks', () {
      const importer = PmdaP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importJapaneseProductDetail(
        detailUrl:
            'https://www.pmda.go.jp/PmdaSearch/iyakuDetail/GeneralList/777',
        html: '''
<html>
  <h1>サンプル錠</h1>
  <a href="/files/0001/insert.pdf">添付文書</a>
  <a href="/files/0001/rmp.pdf">RMP</a>
</html>
''',
      );
      final docCrosswalks = bundle.conceptVariantCrosswalks
          .where((row) => row.externalIdSystem == 'PMDA Japanese document URL')
          .toList();
      expect(docCrosswalks, hasLength(2));
      expect(
        docCrosswalks.every((row) => row.domain == 'drug_monograph'),
        isTrue,
      );
    });

    test('FDC importer records dataType crosswalk with audit note', () {
      const importer = FdcP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importFoods([
        {
          'fdcId': 4242,
          'description': 'Test food',
          'dataType': 'SR Legacy',
          'foodCategory': 'other',
          'foodNutrients': const [],
        }
      ], sourceLabel: 'fdc_datatype_test');
      final dataTypeRow = bundle.conceptVariantCrosswalks
          .firstWhere((row) => row.externalIdSystem == 'FDC dataType');
      expect(dataTypeRow.externalIdValue, 'SR Legacy');
      expect(dataTypeRow.mappingPayloadJson, contains('audit_note'));
    });

    test('Ciqual source document includes provenance summary + audit note', () {
      const importer = CiqualP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importFromXmlStrings(
        alimXml: '''
<root>
  <row>
    <alim_code>2002</alim_code>
    <alim_nom_fr>Carotte</alim_nom_fr>
    <alim_grp_code>VEG</alim_grp_code>
  </row>
</root>
''',
        alimGrpXml: '''
<root><row><alim_grp_code>VEG</alim_grp_code><alim_grp_nom_fr>vegetable</alim_grp_nom_fr></row></root>
''',
        constXml: '''
<root><row><const_code>PROT</const_code><const_nom_eng>Protein</const_nom_eng><unite>g</unite></row></root>
''',
        compoXml: '''
<root><row><alim_code>2002</alim_code><const_code>PROT</const_code><teneur>0.9</teneur><source_code>S1</source_code></row></root>
''',
        sourcesXml: '''
<root><row><source_code>S1</source_code><source_nom>Methodology X</source_nom><bibliographie>Ref Y</bibliographie></row></root>
''',
      );
      final payload =
          jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      final summary = payload['provenance_summary'] as Map;
      final firstEntry = (summary['entries'] as List).first as Map;
      expect(firstEntry['source_code'], 'S1');
      expect(firstEntry['summary'], contains('Methodology X'));
      expect(summary['reason'], contains('not modeled'));
      expect(summary['first_source_titles'], isNotEmpty);
      expect(summary['parser_limitation'], contains('methodology model'));
    });

    test(
        'DailyMed audit_gaps record package_description not parsed and section ordinal exposed',
        () {
      const importer = DailyMedP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importSplXml(
        '''
<document>
  <setId root="audit-setid" />
  <title>AuditMed</title>
  <ingredient><name>levodopa</name></ingredient>
  <routeCode displayName="oral" />
  <formCode displayName="tablet" />
  <section ID="indications-spl"><title>Indications</title><text>For symptomatic relief.</text></section>
  <section><title>Dosing</title><text>Take once daily.</text></section>
</document>
''',
        ndcs: const [
          {
            'ndc': '11111-2222-33',
            'package_description': '2 boxes of 14 tablets'
          }
        ],
      );
      final payload =
          jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      final gaps = (payload['audit_gaps'] as List).cast<Map>();
      expect(
        gaps.any((row) => row['field'] == 'package_description'),
        isTrue,
      );

      final ndcCrosswalk = bundle.conceptVariantCrosswalks
          .firstWhere((row) => row.externalIdSystem == 'NDC');
      expect(ndcCrosswalk.mappingPayloadJson,
          contains('package_description_kept_as_free_text_only'));

      final sectionCrosswalks = bundle.conceptVariantCrosswalks
          .where((row) => row.domain == 'drug_label_section')
          .toList();
      expect(sectionCrosswalks, isNotEmpty);
      final firstSectionPayload =
          jsonDecode(sectionCrosswalks.first.mappingPayloadJson) as Map;
      expect(firstSectionPayload['section_ordinal'], 0);
      // Raw SPL code should be preserved when the source provides one.
      expect(
        sectionCrosswalks.any((row) =>
            (jsonDecode(row.mappingPayloadJson) as Map)['spl_section_code'] ==
            'indications-spl'),
        isTrue,
      );
    });

    test('DPD product detail audit_gaps note conservative HTML extraction',
        () async {
      const infoUrl =
          'https://health-products.canada.ca/dpd-bdpp/info?code=99&lang=eng';
      const importer = HealthCanadaDpdP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {
          infoUrl:
              '<html><body><h2>Details</h2><p>Body text only.</p></body></html>',
        }),
      );
      final base = importer.importFromPayloads(
        drugProducts: [
          {
            'drug_code': '99',
            'drug_identification_number': '88888888',
            'brand_name': 'AuditCa',
            'pharmaceutical_form_code': 'TAB',
            'route_of_administration_code': 'ORAL',
            'drug_status_code': 'M'
          }
        ],
        activeIngredients: [
          {'drug_code': '99', 'ingredient_name': 'Levodopa'}
        ],
        forms: [
          {'pharmaceutical_form_code': 'TAB', 'pharmaceutical_form_name': 'tab'}
        ],
        routes: [
          {
            'route_of_administration_code': 'ORAL',
            'route_of_administration_name': 'oral'
          }
        ],
        statuses: [
          {'drug_status_code': 'M', 'status': 'marketed'}
        ],
      );
      final enriched = await importer.enrichWithProductDetails(base);
      final detailDoc = enriched.sourceDocuments
          .firstWhere((doc) => doc.docType == 'product_info_html');
      final payload = jsonDecode(detailDoc.rawPayload) as Map;
      final gaps = (payload['audit_gaps'] as List).cast<Map>();
      expect(gaps.any((g) => g['field'] == 'product_info_html_body'), isTrue);
      expect(gaps.any((g) => g['field'] == 'linked_resources'), isTrue);
      expect(payload.containsKey('monograph_body'), isFalse);
    });

    test(
        'EMA medicines page raw_payload retains long indication/procedure text',
        () {
      const importer = EmaP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importMedicinesJson(
        jsonEncode([
          {
            'ema_product_number': 'EMEA-H-C-LONG-1',
            'medicine_name': 'LongMed',
            'active_substance': 'levodopa',
            'condition_indication':
                'Treatment of advanced Parkinson disease in adults with motor fluctuations.',
            'procedure_type': 'Centralised',
          }
        ]),
        sourceLabel: 'ema_long_text',
      );
      final medicineDoc = bundle.sourceDocuments
          .firstWhere((doc) => doc.docType == 'medicine_page');
      final payload = jsonDecode(medicineDoc.rawPayload) as Map;
      expect(payload['procedure_type'], 'Centralised');
      expect(
        '${payload['condition_indication']}',
        contains('Parkinson disease'),
      );
      final gaps = (payload['long_text_audit'] as List).cast<Map>();
      expect(gaps.any((g) => g['field'] == 'condition_indication'), isTrue);
      expect(gaps.any((g) => g['field'] == 'procedure_type'), isTrue);
    });

    test('PMDA Japanese product crosswalk explains unspecified route/dosage',
        () {
      const importer = PmdaP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importJapaneseProductDetail(
        detailUrl:
            'https://www.pmda.go.jp/PmdaSearch/iyakuDetail/GeneralList/2024',
        html: '<html><h1>サンプル</h1></html>',
      );
      final productCodeRow = bundle.conceptVariantCrosswalks.firstWhere(
          (row) => row.externalIdSystem == 'PMDA Japanese product code');
      final payload = jsonDecode(productCodeRow.mappingPayloadJson) as Map;
      expect(payload['route'], 'unspecified');
      expect(payload['dosage_form'], 'unspecified');
      expect(payload['route_dosage_audit_note'],
          contains('not expose machine-readable route'));
      expect(bundle.drugProductVariants.single.route, 'unspecified');
      expect(bundle.drugProductVariants.single.dosageForm, 'unspecified');
    });

    test('FDC portion audit_gap lists observed field names + source count', () {
      const importer = FdcP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importFoods([
        {
          'fdcId': 7777,
          'description': 'Granola bar',
          'dataType': 'Branded',
          'foodCategory': 'snack',
          'foodNutrients': const [],
          'foodPortions': [
            {
              'amount': 1,
              'modifier': 'bar',
              'gramWeight': 35.0,
              'measureUnit': {'name': 'piece'},
              'mystery_field': 'unknown'
            },
            {'unknown_only': 'value'},
          ],
        }
      ], sourceLabel: 'fdc_portion_audit_test');
      final payload =
          jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      final entry = (payload['food_portions_audit'] as List).first as Map;
      expect(entry['source_object_count'], 2);
      expect(entry['unparsed_count'], 1);
      expect(entry['observed_field_names'], contains('mystery_field'));
      expect(entry['field'], 'foodPortions');
      expect(entry['observed_count'], 2);
    });

    test('Ciqual provenance summary exposes source_count + first_source_ids',
        () {
      const importer = CiqualP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importFromXmlStrings(
        alimXml: '''
<root><row><alim_code>9001</alim_code><alim_nom_fr>Test</alim_nom_fr><alim_grp_code>X</alim_grp_code></row></root>
''',
        alimGrpXml:
            '<root><row><alim_grp_code>X</alim_grp_code><alim_grp_nom_fr>x</alim_grp_nom_fr></row></root>',
        constXml:
            '<root><row><const_code>PROT</const_code><const_nom_eng>Protein</const_nom_eng><unite>g</unite></row></root>',
        compoXml:
            '<root><row><alim_code>9001</alim_code><const_code>PROT</const_code><teneur>1.0</teneur><source_code>SRC1</source_code></row></root>',
        sourcesXml: '''
<root>
  <row><source_code>SRC1</source_code><source_nom>method one</source_nom></row>
  <row><source_code>SRC2</source_code><source_nom>method two</source_nom></row>
</root>
''',
      );
      final payload =
          jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      final summary = payload['provenance_summary'] as Map;
      expect(summary['source_count'], 2);
      expect(
          (summary['first_source_ids'] as List), containsAll(['SRC1', 'SRC2']));
      expect(summary['field'], 'sources_xml_methodology');
    });

    test(
        'China CDC + FAO crosswalks carry explicit page-id and country-only audit notes',
        () {
      const chinaImporter = ChinaCdcFoodPlatformImporter(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final chinaBundle = chinaImporter.importFoodPage(
        url: 'https://nlc.chinanutri.cn/fq/foodinfo/123.html',
        html: '<html><body>苹果 食物类：水果 亚 类：苹果</body></html>',
      );
      final chinaPayload = jsonDecode(
              chinaBundle.conceptVariantCrosswalks.single.mappingPayloadJson)
          as Map;
      expect(chinaPayload['source_identifier_type'], 'page_identifier');
      expect(chinaPayload['promotion_decision'],
          'page_identifier_only_no_promotion_to_national_code');

      const faoImporter = FaoFbdgP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final faoBundle = faoImporter.importCountryPage(
        countryCode: 'JP',
        url:
            'https://www.fao.org/nutrition/education/food-dietary-guidelines/regions/countries/japan/en/',
        html: '<html><body>Official name FBDG Japan</body></html>',
      );
      final faoPayload = jsonDecode(
          faoBundle.conceptVariantCrosswalks.single.mappingPayloadJson) as Map;
      expect(faoPayload['region_or_city_identifier'], isNull);
      expect(faoPayload['region_or_city_audit_note'],
          contains('Country-level crosswalk only'));
    });

    test('every importer-emitted crosswalk row carries the standard audit keys',
        () {
      const requiredKeys = {
        'source_identifier_type',
        'confidence_reason',
        'promoted_fields',
        'non_promoted_fields',
      };
      const dailyMed = DailyMedP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      const dpd = HealthCanadaDpdP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      const ema = EmaP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      const pmda = PmdaP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      const fdc = FdcP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      const ciqual = CiqualP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      const china = ChinaCdcFoodPlatformImporter(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      const fao = FaoFbdgP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );

      final bundles = <P0ImportBundle>[
        dailyMed.importSplXml(
          '<document><setId root="audit-all" /><title>T</title>'
          '<ingredient><name>levodopa</name></ingredient>'
          '<routeCode displayName="oral" /><formCode displayName="tablet" />'
          '<section><title>S</title><text>x</text></section></document>',
          ndcs: const [
            {'ndc': '00000-0000-01'}
          ],
          media: const [
            {'url': 'https://x/y.png', 'type': 'image/png'}
          ],
        ),
        dpd.importFromPayloads(
          drugProducts: const [
            {
              'drug_code': '1',
              'drug_identification_number': '11111111',
              'brand_name': 'AuditCa',
              'pharmaceutical_form_code': 'TAB',
              'route_of_administration_code': 'ORAL',
              'drug_status_code': 'M'
            }
          ],
          activeIngredients: const [
            {'drug_code': '1', 'ingredient_name': 'Levodopa'}
          ],
          forms: const [
            {
              'pharmaceutical_form_code': 'TAB',
              'pharmaceutical_form_name': 'tab'
            }
          ],
          packaging: const [
            {'drug_code': '1', 'package': 'box', 'upc': '0123456789'}
          ],
          routes: const [
            {
              'route_of_administration_code': 'ORAL',
              'route_of_administration_name': 'oral'
            }
          ],
          statuses: const [
            {'drug_status_code': 'M', 'status': 'marketed'}
          ],
        ),
        ema.importMedicinesJson(
          jsonEncode([
            {
              'ema_product_number': 'EMEA-AUDIT-1',
              'medicine_name': 'AuditMed',
              'active_substance': 'levodopa',
              'medicine_url': 'https://www.ema.europa.eu/en/medicines/auditmed',
              'document_url': 'https://x/smpc.pdf',
              'translations_url': 'https://x/leaflet.pdf',
              'epar_url': 'https://x/epar.pdf',
              'atc_code_human': 'N04BA02',
            }
          ]),
          sourceLabel: 'audit_consistency',
        ),
        pmda.importEnglishReferenceIndex(
          '<html><a href="/files/0001/audit.pdf">English insert</a></html>',
        ),
        pmda.importJapaneseProductDetail(
          detailUrl:
              'https://www.pmda.go.jp/PmdaSearch/iyakuDetail/GeneralList/audit',
          html: '<html><h1>監査</h1>'
              '<a href="/files/0001/audit.pdf">添付文書</a></html>',
        ),
        fdc.importFoods(const [
          {
            'fdcId': 4242,
            'description': 'Audit food',
            'dataType': 'Foundation',
            'foodCategory': 'other',
            'ndbNumber': '01000',
            'foodNutrients': [],
          }
        ], sourceLabel: 'audit_fdc'),
        ciqual.importFromXmlStrings(
          alimXml:
              '<root><row><alim_code>4242</alim_code><alim_nom_fr>x</alim_nom_fr><alim_grp_code>X</alim_grp_code></row></root>',
          alimGrpXml:
              '<root><row><alim_grp_code>X</alim_grp_code><alim_grp_nom_fr>x</alim_grp_nom_fr></row></root>',
          constXml:
              '<root><row><const_code>PROT</const_code><const_nom_eng>Protein</const_nom_eng><unite>g</unite></row></root>',
          compoXml:
              '<root><row><alim_code>4242</alim_code><const_code>PROT</const_code><teneur>0.1</teneur></row></root>',
          sourcesXml: '<root />',
        ),
        china.importFoodPage(
          url: 'https://nlc.chinanutri.cn/fq/foodinfo/4242.html',
          html: '<html>苹果 食物类：水果 亚 类：苹果</html>',
        ),
        fao.importCountryPage(
          countryCode: 'KR',
          url: 'https://www.fao.org/.../korea/en/',
          html: '<html><body>Official name FBDG Korea</body></html>',
        ),
      ];

      var totalRows = 0;
      for (final bundle in bundles) {
        for (final crosswalk in bundle.conceptVariantCrosswalks) {
          totalRows += 1;
          final payload =
              jsonDecode(crosswalk.mappingPayloadJson) as Map<String, dynamic>;
          for (final key in requiredKeys) {
            expect(
              payload.containsKey(key),
              isTrue,
              reason:
                  'crosswalk for ${crosswalk.externalIdSystem}=${crosswalk.externalIdValue} missing $key',
            );
          }
        }
      }
      expect(totalRows, greaterThan(0));
    });

    test('crosswalk source_locator is auto-derived from URL-like payload keys',
        () {
      const importer = ChinaCdcFoodPlatformImporter(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importFoodPage(
        url: 'https://nlc.chinanutri.cn/fq/foodinfo/4242.html',
        html: '<html>苹果 食物类：水果 亚 类：苹果</html>',
      );
      final payload =
          jsonDecode(bundle.conceptVariantCrosswalks.single.mappingPayloadJson)
              as Map<String, dynamic>;
      expect(payload['source_locator'],
          'https://nlc.chinanutri.cn/fq/foodinfo/4242.html');
    });

    test(
        'ingestion smoke: per-source audit metadata + conservative boundary visibility',
        () {
      // Required mapping_payload keys we expect on every importer-emitted row.
      const requiredCrosswalkKeys = {
        'source_identifier_type',
        'confidence_reason',
        'promoted_fields',
        'non_promoted_fields',
        'parser_limitation',
      };

      void assertCrosswalkAuditConsistency(
        P0ImportBundle bundle, {
        required String label,
      }) {
        expect(bundle.conceptVariantCrosswalks, isNotEmpty,
            reason: '$label should emit at least one crosswalk');
        for (final row in bundle.conceptVariantCrosswalks) {
          final payload =
              jsonDecode(row.mappingPayloadJson) as Map<String, dynamic>;
          for (final key in requiredCrosswalkKeys) {
            expect(payload.containsKey(key), isTrue,
                reason:
                    '$label crosswalk ${row.externalIdSystem}=${row.externalIdValue} missing $key');
          }
        }
      }

      // --- DailyMed: free-text package_description must remain non-promoted but
      // visible in source_document.raw_payload audit_gaps.
      const dailyMed = DailyMedP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final dailyMedBundle = dailyMed.importSplXml(
        '<document><setId root="smoke-1" /><title>SmokeMed</title>'
        '<ingredient><name>levodopa</name></ingredient>'
        '<routeCode displayName="oral" /><formCode displayName="tablet" />'
        '<section><title>S</title><text>x</text></section></document>',
        ndcs: const [
          {'ndc': '99999-0001-01', 'package_description': 'box of 30'}
        ],
      );
      assertCrosswalkAuditConsistency(dailyMedBundle, label: 'DailyMed');
      final dailyMedPayload =
          jsonDecode(dailyMedBundle.sourceDocuments.single.rawPayload) as Map;
      final dailyMedGaps = (dailyMedPayload['audit_gaps'] as List).cast<Map>();
      expect(
        dailyMedGaps.any((g) => g['field'] == 'package_description'),
        isTrue,
        reason: 'DailyMed package_description must remain visible as audit_gap',
      );

      // --- DPD: product_info_html limitation must be explicit.
      const dpd = HealthCanadaDpdP0Importer(
        fetchClient: FakeSourceFetchClient(
          textByUrl: {
            'https://health-products.canada.ca/dpd-bdpp/info?code=smoke&lang=eng':
                '<html><h2>Details</h2><p>Body.</p></html>',
          },
        ),
      );
      final dpdBase = dpd.importFromPayloads(
        drugProducts: const [
          {
            'drug_code': 'smoke',
            'drug_identification_number': '12121212',
            'brand_name': 'SmokeCa',
            'pharmaceutical_form_code': 'TAB',
            'route_of_administration_code': 'ORAL',
            'drug_status_code': 'M'
          }
        ],
        activeIngredients: const [
          {'drug_code': 'smoke', 'ingredient_name': 'Levodopa'}
        ],
        forms: const [
          {'pharmaceutical_form_code': 'TAB', 'pharmaceutical_form_name': 'tab'}
        ],
        routes: const [
          {
            'route_of_administration_code': 'ORAL',
            'route_of_administration_name': 'oral'
          }
        ],
        statuses: const [
          {'drug_status_code': 'M', 'status': 'marketed'}
        ],
      );
      assertCrosswalkAuditConsistency(dpdBase, label: 'DPD base');
      // Note: DPD product-detail enrichment is exercised in its own dedicated
      // test; the smoke pass only validates the base crosswalk envelope here.

      // --- EMA: long body text and procedure_type must remain raw.
      const ema = EmaP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final emaBundle = ema.importMedicinesJson(
        jsonEncode([
          {
            'ema_product_number': 'EMEA-SMOKE-1',
            'medicine_name': 'EmaSmoke',
            'active_substance': 'levodopa',
            'medicine_url': 'https://www.ema.europa.eu/en/medicines/emasmoke',
            'condition_indication':
                'Long indication narrative we never structure.',
            'procedure_type': 'Centralised',
          }
        ]),
        sourceLabel: 'smoke_ema',
      );
      assertCrosswalkAuditConsistency(emaBundle, label: 'EMA');
      final emaPagePayload = jsonDecode(emaBundle.sourceDocuments
          .firstWhere((d) => d.docType == 'medicine_page')
          .rawPayload) as Map;
      expect(emaPagePayload['condition_indication'],
          contains('narrative we never structure'));
      expect(emaPagePayload['procedure_type'], 'Centralised');

      // --- PMDA: English index reference_only + Japanese authoritative.
      const pmda = PmdaP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final pmdaEnBundle = pmda.importEnglishReferenceIndex(
          '<html><a href="/files/0001/x.pdf">English translated package insert</a></html>');
      assertCrosswalkAuditConsistency(pmdaEnBundle, label: 'PMDA english');
      expect(
        pmdaEnBundle.conceptVariantCrosswalks
            .every((row) => row.status == 'reference_only'),
        isTrue,
      );
      final pmdaJaBundle = pmda.importJapaneseProductDetail(
        detailUrl:
            'https://www.pmda.go.jp/PmdaSearch/iyakuDetail/GeneralList/smoke',
        html: '<html><h1>煙</h1></html>',
      );
      assertCrosswalkAuditConsistency(pmdaJaBundle, label: 'PMDA japanese');
      final pmdaProductRow = pmdaJaBundle.conceptVariantCrosswalks.firstWhere(
          (row) => row.externalIdSystem == 'PMDA Japanese product code');
      final pmdaProductPayload =
          jsonDecode(pmdaProductRow.mappingPayloadJson) as Map;
      expect(pmdaProductPayload['route'], 'unspecified');
      expect(pmdaProductPayload['dosage_form'], 'unspecified');

      // --- FDC: foodPortions kept in raw_payload audit only.
      const fdc = FdcP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final fdcBundle = fdc.importFoods(const [
        {
          'fdcId': 11111,
          'description': 'SmokeFood',
          'dataType': 'Foundation',
          'foodCategory': 'snack',
          'foodNutrients': [],
          'foodPortions': [
            {'amount': 1, 'modifier': 'piece', 'gramWeight': 10.0}
          ],
        }
      ], sourceLabel: 'smoke_fdc');
      assertCrosswalkAuditConsistency(fdcBundle, label: 'FDC');
      final fdcPayload =
          jsonDecode(fdcBundle.sourceDocuments.single.rawPayload) as Map;
      expect(fdcPayload['food_portions_audit'], isA<List>());
      expect((fdcPayload['food_portions_audit'] as List), isNotEmpty);

      // --- Ciqual: provenance summary, no methodology subtables.
      const ciqual = CiqualP0Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final ciqualBundle = ciqual.importFromXmlStrings(
        alimXml:
            '<root><row><alim_code>11111</alim_code><alim_nom_fr>x</alim_nom_fr><alim_grp_code>X</alim_grp_code></row></root>',
        alimGrpXml:
            '<root><row><alim_grp_code>X</alim_grp_code><alim_grp_nom_fr>x</alim_grp_nom_fr></row></root>',
        constXml:
            '<root><row><const_code>PROT</const_code><const_nom_eng>Protein</const_nom_eng><unite>g</unite></row></root>',
        compoXml:
            '<root><row><alim_code>11111</alim_code><const_code>PROT</const_code><teneur>0.1</teneur><source_code>S1</source_code></row></root>',
        sourcesXml:
            '<root><row><source_code>S1</source_code><source_nom>m1</source_nom></row></root>',
      );
      assertCrosswalkAuditConsistency(ciqualBundle, label: 'Ciqual');
      final ciqualPayload =
          jsonDecode(ciqualBundle.sourceDocuments.single.rawPayload) as Map;
      expect((ciqualPayload['provenance_summary'] as Map)['source_count'], 1);

      // --- China CDC: page id is NOT a national food code.
      const china = ChinaCdcFoodPlatformImporter(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final chinaBundle = china.importFoodPage(
        url: 'https://nlc.chinanutri.cn/fq/foodinfo/11111.html',
        html: '<html>苹果 食物类：水果 亚 类：苹果</html>',
      );
      assertCrosswalkAuditConsistency(chinaBundle, label: 'China CDC');
      final chinaPayload = jsonDecode(
              chinaBundle.conceptVariantCrosswalks.single.mappingPayloadJson)
          as Map;
      expect(chinaPayload['source_identifier_type'], 'page_identifier');

      // --- FAO: country-level only.
      const fao = FaoFbdgP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final faoBundle = fao.importCountryPage(
        countryCode: 'TH',
        url: 'https://www.fao.org/.../thailand/en/',
        html: '<html><body>Official name FBDG Thailand</body></html>',
      );
      assertCrosswalkAuditConsistency(faoBundle, label: 'FAO');
      final faoPayload = jsonDecode(
          faoBundle.conceptVariantCrosswalks.single.mappingPayloadJson) as Map;
      expect(faoPayload['region_or_city_identifier'], isNull);
    });

    test('ingestion smoke bundles are repeatable across two constructions', () {
      final first = _importerAuditSmokeSignature(
        _buildImporterAuditSmokeBundles(),
      );
      final second = _importerAuditSmokeSignature(
        _buildImporterAuditSmokeBundles(),
      );

      expect(second, first);
      for (final entry in first.entries) {
        expect(entry.value, isNotEmpty,
            reason: '${entry.key} should emit stable audit crosswalks');
      }
    });

    test(
        'Seed catalog importer fills projectedFoods and projectedDrugs with broad coverage',
        () {
      const importer = SeedCatalogImporter();
      final bundle = importer.importSeedCatalog();

      // Catalog must be meaningfully broader than the previous defaults.
      expect(bundle.projectedFoods.length, greaterThanOrEqualTo(60));
      expect(bundle.projectedDrugs.length, greaterThanOrEqualTo(20));

      // No duplicate IDs (the AppRepository merge dedups by id, but we keep
      // the seed list itself unique to make audits easy).
      final foodIds = bundle.projectedFoods.map((f) => f.id).toList();
      final drugIds = bundle.projectedDrugs.map((d) => d.id).toList();
      expect(foodIds.toSet().length, foodIds.length);
      expect(drugIds.toSet().length, drugIds.length);

      // Every row tagged as the seed catalog so authoritative imports remain
      // distinguishable.
      expect(
        bundle.projectedFoods
            .every((f) => f.sourceSystem == 'LOCAL_SEED_CATALOG'),
        isTrue,
      );
      expect(
        bundle.projectedDrugs
            .every((d) => d.sourceSystem == 'LOCAL_SEED_CATALOG'),
        isTrue,
      );

      // Conservative: NO observations / facts / crosswalks / concept rows.
      expect(bundle.observations, isEmpty);
      expect(bundle.resolvedFacts, isEmpty);
      expect(bundle.conceptVariantCrosswalks, isEmpty);
      expect(bundle.foodConcepts, isEmpty);
      expect(bundle.drugConcepts, isEmpty);

      // Every food category is represented at least once.
      final categories = bundle.projectedFoods.map((f) => f.category).toSet();
      expect(
          categories,
          containsAll(<FoodCategory>{
            FoodCategory.protein,
            FoodCategory.carbs,
            FoodCategory.vegetable,
            FoodCategory.fruit,
            FoodCategory.dairy,
            FoodCategory.fat,
            FoodCategory.beverage,
          }));

      // Source document records the audit gap for nutrition + interactions.
      final doc = bundle.sourceDocuments.single;
      expect(doc.sourceFamily, 'LOCAL_SEED_CATALOG');
      final payload = jsonDecode(doc.rawPayload) as Map<String, dynamic>;
      final gaps = (payload['audit_gaps'] as List).cast<Map>();
      expect(gaps.any((g) => g['field'] == 'food_nutrition_values'), isTrue);
      expect(
        gaps.any((g) => g['field'] == 'drug_interaction_summary'),
        isTrue,
        reason: 'Seed drug entries must record an interaction-summary gap',
      );
      expect(payload['parser_limitation'], isNotNull);
    });

    test(
        'Regional seed catalog importer adds region-tagged foods and comorbid drugs',
        () {
      const importer = RegionalSeedCatalogImporter();
      final bundle = importer.importRegionalSeedCatalog();

      expect(bundle.projectedFoods.length, greaterThanOrEqualTo(60));
      expect(bundle.projectedDrugs.length, greaterThanOrEqualTo(15));

      // Region coverage: every major region we declared must be present.
      final jurisdictions =
          bundle.projectedFoods.map((f) => f.jurisdiction).toSet();
      expect(
        jurisdictions,
        containsAll(<String>{
          'CN',
          'JP',
          'KR',
          'IN',
          'MED',
          'MX',
          'SEA',
          'EE',
          'MENA',
        }),
      );

      // Specific landmark foods the user called out must exist.
      final foodIds = bundle.projectedFoods.map((f) => f.id).toSet();
      expect(foodIds, contains('seed_cn_jujube'));
      expect(foodIds, contains('seed_jp_tai'));
      expect(foodIds, contains('seed_kr_kimchi'));
      expect(foodIds, contains('seed_in_dal'));
      expect(foodIds, contains('seed_med_hummus'));
      expect(foodIds, contains('seed_mx_tortilla_corn'));
      expect(foodIds, contains('seed_sea_pho'));

      // Native-language alias is searchable for at least one CN and one JP item.
      final jujube =
          bundle.projectedFoods.firstWhere((f) => f.id == 'seed_cn_jujube');
      expect(jujube.searchableText, contains('红枣'));
      final tai =
          bundle.projectedFoods.firstWhere((f) => f.id == 'seed_jp_tai');
      expect(tai.searchableText, contains('鯛'));

      // No duplicate IDs across the regional list.
      final ids = bundle.projectedFoods.map((f) => f.id).toList();
      expect(ids.toSet().length, ids.length);

      // Source-system tagging.
      expect(
        bundle.projectedFoods
            .every((f) => f.sourceSystem == 'LOCAL_SEED_CATALOG_REGIONAL'),
        isTrue,
      );
      expect(
        bundle.projectedDrugs
            .every((d) => d.sourceSystem == 'LOCAL_SEED_CATALOG_REGIONAL'),
        isTrue,
      );

      // Conservative: no observations / facts / crosswalks / concept rows.
      expect(bundle.observations, isEmpty);
      expect(bundle.resolvedFacts, isEmpty);
      expect(bundle.conceptVariantCrosswalks, isEmpty);
      expect(bundle.foodConcepts, isEmpty);
      expect(bundle.drugConcepts, isEmpty);

      // Source document records cultural-alias + nutrition + drug audit gaps.
      final doc = bundle.sourceDocuments.single;
      expect(doc.sourceFamily, 'LOCAL_SEED_CATALOG_REGIONAL');
      final payload = jsonDecode(doc.rawPayload) as Map<String, dynamic>;
      final gaps = (payload['audit_gaps'] as List).cast<Map>();
      expect(gaps.any((g) => g['field'] == 'food_nutrition_values'), isTrue);
      expect(gaps.any((g) => g['field'] == 'cultural_aliases'), isTrue);
      expect(gaps.any((g) => g['field'] == 'drug_interaction_summary'), isTrue);
    });

    test(
        'Catalog ↔ interaction-engine reconciliation: every taggable drug is tagged',
        () {
      const seed = SeedCatalogImporter();
      const regional = RegionalSeedCatalogImporter();
      final union =
          seed.importSeedCatalog().merge(regional.importRegionalSeedCatalog());
      final report = CatalogInteractionAudit.audit(
        drugs: union.projectedDrugs,
        foods: union.projectedFoods,
      );

      // Hard guarantee: anything inferDrugTag() would tag must already carry
      // that tag in the seed catalogs. The interaction engine must not miss
      // a taggable PD-relevant drug just because we forgot the tag.
      final missing = (report['missing_tag_gaps'] as List).cast<Map>();
      expect(missing, isEmpty,
          reason: 'Catalog drug entries missing inferred DrugTag: $missing');
      expect(report['missing_tag_count'], 0);

      // Iron supplement check: every "iron" / "ferrous" / "ferric" row must
      // carry mineralSupplement so the levodopa-iron rule can fire.
      final ironRows = (report['iron_supplement_check'] as List).cast<Map>();
      expect(ironRows, isNotEmpty);
      for (final row in ironRows) {
        expect(row['has_mineral_supplement_tag'], isTrue,
            reason:
                "${row['drug_id']} (${row['generic_name']}) must carry mineralSupplement");
      }
    });

    test(
        'Catalog audit surfaces schema coverage gaps for known PD-relevant interactions the DrugTag enum cannot express',
        () {
      const seed = SeedCatalogImporter();
      const regional = RegionalSeedCatalogImporter();
      final union =
          seed.importSeedCatalog().merge(regional.importRegionalSeedCatalog());
      final report = CatalogInteractionAudit.audit(
        drugs: union.projectedDrugs,
        foods: union.projectedFoods,
      );

      final gaps = (report['schema_coverage_gaps'] as List).cast<Map>();
      String? matched(String pattern) => gaps.firstWhere(
            (g) => '${g['pattern']}' == pattern,
            orElse: () => const <String, Object?>{},
          )['drug_id'] as String?;

      // Every catalog drug whose interaction class the current DrugTag enum
      // cannot express must appear in the report so reviewers see it.
      expect(matched('omeprazole'), isNotNull, reason: 'PPI must be flagged');
      expect(matched('pantoprazole'), isNotNull, reason: 'PPI must be flagged');
      expect(matched('calcium carbonate'), isNotNull,
          reason: 'Multivalent-cation antacid must be flagged');
      expect(matched('sertraline'), isNotNull, reason: 'SSRI must be flagged');
      expect(matched('mirtazapine'), isNotNull,
          reason: 'Atypical serotonergic antidepressant must be flagged');
      expect(matched('trazodone'), isNotNull,
          reason: 'Atypical serotonergic antidepressant must be flagged');
      expect(matched('tramadol'), isNotNull,
          reason: 'Serotonergic opioid must be flagged');

      // Domperidone is a peripheral D2 antagonist used to *counter* dopamine
      // agonist nausea — it must NOT be flagged as a Parkinsonism-worsening
      // dopamine antagonist.
      expect(
        gaps.any((g) =>
            '${g['generic_name']}'.toLowerCase().contains('domperidone')),
        isFalse,
        reason:
            'Peripheral D2 antagonist domperidone must not be in the schema-coverage-gap list',
      );
    });

    test('Catalog audit bundle persists report through a SourceDocumentRecord',
        () {
      const seed = SeedCatalogImporter();
      const regional = RegionalSeedCatalogImporter();
      final union =
          seed.importSeedCatalog().merge(regional.importRegionalSeedCatalog());
      final auditBundle = CatalogInteractionAudit.buildAuditBundle(
        drugs: union.projectedDrugs,
        foods: union.projectedFoods,
      );

      // Conservative: audit produces NO concept / variant / observation /
      // crosswalk / projected rows — only one SourceDocumentRecord.
      expect(auditBundle.sourceDocuments, hasLength(1));
      expect(auditBundle.projectedDrugs, isEmpty);
      expect(auditBundle.projectedFoods, isEmpty);
      expect(auditBundle.observations, isEmpty);
      expect(auditBundle.conceptVariantCrosswalks, isEmpty);

      final doc = auditBundle.sourceDocuments.single;
      expect(doc.sourceFamily, 'CATALOG_INTERACTION_AUDIT');
      final payload = jsonDecode(doc.rawPayload) as Map<String, dynamic>;
      expect(payload['drug_count_audited'], union.projectedDrugs.length);
      expect(payload['missing_tag_count'], 0);
      expect(payload['schema_coverage_gap_count'], greaterThan(0));
      final gaps = (payload['audit_gaps'] as List).cast<Map>();
      expect(gaps.any((g) => g['field'] == 'missing_tag'), isTrue);
      expect(gaps.any((g) => g['field'] == 'schema_coverage_gap'), isTrue);
      expect(payload['parser_limitation'], isNotNull);
    });

    test('Combined seed + regional catalog merges without duplicate IDs', () {
      const base = SeedCatalogImporter();
      const regional = RegionalSeedCatalogImporter();
      final merged =
          base.importSeedCatalog().merge(regional.importRegionalSeedCatalog());

      final foodIds = merged.projectedFoods.map((f) => f.id).toList();
      final drugIds = merged.projectedDrugs.map((d) => d.id).toList();
      expect(foodIds.toSet().length, foodIds.length,
          reason: 'global + regional food IDs must be globally unique');
      expect(drugIds.toSet().length, drugIds.length,
          reason: 'global + regional drug IDs must be globally unique');
      // Combined catalog covers a wide range.
      expect(merged.projectedFoods.length, greaterThanOrEqualTo(130));
      expect(merged.projectedDrugs.length, greaterThanOrEqualTo(50));
    });

    test(
        'Secondary source registry now covers KR/IN/ES/MX/SEA/TH/RU/PL/SA/EG/LATAM',
        () {
      final declared = kSecondarySources.map((s) => s.sourceFamily).toSet();
      expect(
          declared,
          containsAll(<String>{
            'KR_MFDS',
            'KR_RDA_FOOD_COMPOSITION',
            'IN_CDSCO',
            'IN_IFCT_NIN',
            'ES_AEMPS',
            'ES_BEDCA',
            'MX_COFEPRIS',
            'LATAM_INCAP',
            'ASEAN_FCDB',
            'TH_FDA',
            'RU_ROSZDRAVNADZOR',
            'RU_FRC_NUTRITION',
            'PL_NIZP_PZH',
            'SA_SFDA',
            'EG_NRC_FOOD_COMPOSITION',
          }));
      // Each new entry must declare a P1/P2/P3 tier (no P0 in the registry).
      for (final entry in kSecondarySources) {
        expect(
          <String>{
            KnowledgeDataTier.p1,
            KnowledgeDataTier.p2,
            KnowledgeDataTier.p3
          }.contains(entry.dataTier),
          isTrue,
          reason: '${entry.sourceFamily} must be tiered P1/P2/P3',
        );
        expect(entry.tierRationale, isNotEmpty);
      }
    });

    test('Locale resource seed covers KR/IN/ES/MX/SEA/EE/RU/MENA locales', () {
      const importer = LocaleResourceSeedImporter();
      final rows = importer.buildLocaleSeedBundles();

      final localeTags = rows.map((r) => r.localeTag).toSet();
      expect(
          localeTags,
          containsAll(<String>{
            'ko-KR',
            'hi-IN',
            'es-ES',
            'es-MX',
            'vi-VN',
            'th-TH',
            'id-ID',
            'ru-RU',
            'pl-PL',
            'ar-SA',
          }));

      final namespaces = rows.map((r) => r.namespace).toSet();
      expect(
          namespaces,
          containsAll(<String>{
            'food_categories',
            'meal_slots',
            'texture_classes',
          }));

      // Every locale must cover all eight FoodCategory values + breakfast/
      // lunch/dinner/snack + liquid/soft/regular.
      for (final tag in localeTags) {
        final localeRows = rows.where((r) => r.localeTag == tag).toList();
        final foodKeys = localeRows
            .where((r) => r.namespace == 'food_categories')
            .map((r) => r.key)
            .toSet();
        expect(
            foodKeys,
            containsAll(<String>{
              'protein',
              'carbs',
              'vegetable',
              'fruit',
              'dairy',
              'fat',
              'beverage',
              'other',
            }),
            reason: '$tag missing food_categories keys');
        final slotKeys = localeRows
            .where((r) => r.namespace == 'meal_slots')
            .map((r) => r.key)
            .toSet();
        expect(slotKeys,
            containsAll(<String>{'breakfast', 'lunch', 'dinner', 'snack'}),
            reason: '$tag missing meal_slots keys');
        final textureKeys = localeRows
            .where((r) => r.namespace == 'texture_classes')
            .map((r) => r.key)
            .toSet();
        expect(textureKeys, containsAll(<String>{'liquid', 'soft', 'regular'}),
            reason: '$tag missing texture_classes keys');
      }

      // Every row text must be non-empty (no untranslated placeholders).
      for (final row in rows) {
        expect(row.text.trim(), isNotEmpty,
            reason: '${row.localeTag}/${row.namespace}/${row.key} is blank');
      }

      // Spot-check a few translations to catch encoding regressions.
      final korean = rows.firstWhere(
        (r) =>
            r.localeTag == 'ko-KR' &&
            r.namespace == 'food_categories' &&
            r.key == 'protein',
      );
      expect(korean.text, '단백질');
      final hindi = rows.firstWhere(
        (r) =>
            r.localeTag == 'hi-IN' &&
            r.namespace == 'meal_slots' &&
            r.key == 'breakfast',
      );
      expect(hindi.text, 'नाश्ता');
      final arabic = rows.firstWhere(
        (r) =>
            r.localeTag == 'ar-SA' &&
            r.namespace == 'texture_classes' &&
            r.key == 'liquid',
      );
      expect(arabic.text, 'سائل');
    });

    test(
        'Locale seed includes nav / common / recommend.path namespaces for every locale',
        () {
      const importer = LocaleResourceSeedImporter();
      final rows = importer.buildLocaleSeedBundles();

      // Every locale must now serve the new UI-driving namespaces.
      const expectedNamespaces = {
        'food_categories',
        'meal_slots',
        'texture_classes',
        'nav',
        'common',
        'recommend.path',
      };
      final localeTags = rows.map((r) => r.localeTag).toSet();
      for (final tag in localeTags) {
        final perLocale = rows
            .where((r) => r.localeTag == tag)
            .map((r) => r.namespace)
            .toSet();
        expect(perLocale, containsAll(expectedNamespaces),
            reason: '$tag missing one of the new namespaces');
      }

      // nav / common / recommend.path keys must each cover the canonical
      // AppI18n flat keys so `tr('nav.home')` etc. can be served from the
      // database snapshot.
      bool hasFlatKey(String localeTag, String flat) {
        final dotIdx = flat.indexOf('.');
        // Match the importer's namespace splitter for `recommend.path.*`
        // (namespace is the literal `recommend.path`, so split on the LAST
        // dot in flat keys whose first segment is `recommend`).
        final namespace = flat.startsWith('recommend.')
            ? 'recommend.path'
            : flat.substring(0, dotIdx);
        final key = flat.startsWith('recommend.')
            ? flat.substring('recommend.path.'.length)
            : flat.substring(dotIdx + 1);
        return rows.any(
          (r) =>
              r.localeTag == localeTag &&
              r.namespace == namespace &&
              r.key == key,
        );
      }

      for (final tag in localeTags) {
        for (final flat in const [
          'nav.home',
          'nav.analytics',
          'nav.meals',
          'nav.timeline',
          'nav.meds',
          'nav.catalog',
          'common.cancel',
          'common.save',
          'common.delete',
          'common.confirm',
          'common.sign_out',
          'recommend.path.hybrid_local_ai',
          'recommend.path.conservative_safety_gate',
          'recommend.path.conservative_cdss',
        ]) {
          expect(hasFlatKey(tag, flat), isTrue, reason: '$tag missing $flat');
        }
      }

      // Spot-check actual translations to catch encoding regressions.
      final koreanHome = rows.firstWhere(
        (r) =>
            r.localeTag == 'ko-KR' && r.namespace == 'nav' && r.key == 'home',
      );
      expect(koreanHome.text, '홈');
      final arabicCancel = rows.firstWhere(
        (r) =>
            r.localeTag == 'ar-SA' &&
            r.namespace == 'common' &&
            r.key == 'cancel',
      );
      expect(arabicCancel.text, 'إلغاء');
      final russianPath = rows.firstWhere(
        (r) =>
            r.localeTag == 'ru-RU' &&
            r.namespace == 'recommend.path' &&
            r.key == 'conservative_cdss',
      );
      expect(russianPath.text, 'Консервативный путь CDSS');
    });

    test('Baseline CDSS rules now ship localized messages for new locales',
        () async {
      // Re-import baseline rules through the public entry point so any
      // composition with the translation overlay is exercised end-to-end.
      // ignore: avoid_dynamic_calls
      final rules = baselineCdssRules;
      // Pick a representative rule that we know we wrote translations for.
      final proteinWindow = rules.firstWhere(
        (r) => r['rule_id'] == 'pd.ldopa.protein.window.v1',
      );
      final messages =
          (proteinWindow['then'] as Map)['messages'] as Map<String, dynamic>;
      expect(messages['zh'], isA<String>());
      final localized = messages['localized'] as Map<String, dynamic>;
      // Every locale we seed UI strings for must also have a rule
      // translation, so users in those locales never see the fallback chain
      // for this canonical PD rule.
      for (final tag in const [
        'ko-KR',
        'hi-IN',
        'es',
        'es-MX',
        'vi-VN',
        'th-TH',
        'id-ID',
        'ru-RU',
        'pl-PL',
        'ar-SA',
      ]) {
        expect(localized.containsKey(tag), isTrue,
            reason:
                'pd.ldopa.protein.window.v1 missing localized text for $tag');
        expect((localized[tag] as String).trim(), isNotEmpty);
      }
    });

    test(
        'Locale seed audit document records translation-quality + UI-coverage gaps',
        () {
      const importer = LocaleResourceSeedImporter();
      final rows = importer.buildLocaleSeedBundles();
      final audit = importer.buildAuditSourceDocument(
        rowCount: rows.length,
        localeTags: rows.map((r) => r.localeTag).toSet(),
        namespaces: rows.map((r) => r.namespace).toSet(),
      );
      expect(audit.sourceDocuments, hasLength(1));
      final doc = audit.sourceDocuments.single;
      expect(doc.sourceFamily, 'LOCALE_RESOURCE_SEED');
      final payload = jsonDecode(doc.rawPayload) as Map<String, dynamic>;
      final gaps = (payload['audit_gaps'] as List).cast<Map>();
      expect(
          gaps.any((g) => g['field'] == 'translation_quality_review'), isTrue);
      expect(
          gaps.any((g) => g['field'] == 'ui_string_catalog_coverage'), isTrue);
      expect(gaps.any((g) => g['field'] == 'plural_rules'), isTrue);
      expect(payload['parser_limitation'],
          contains('database-backed UI enrichment for selected namespaces'));
      // Audit bundle is metadata-only.
      expect(audit.projectedFoods, isEmpty);
      expect(audit.projectedDrugs, isEmpty);
    });

    test('Combined seed + regional catalog merges without duplicate IDs', () {
      const importer = SecondarySourceRegistryImporter();
      final bundle = importer.importDeclaredCatalog();

      // Every declared source becomes exactly one source_document.
      expect(
        bundle.sourceDocuments.length,
        kSecondarySources.length,
      );

      // Every row carries one of P1 / P2 / P3 (never P0) and is tagged as an
      // official_reference (landing-page metadata only).
      const allowedTiers = {'P1', 'P2', 'P3'};
      for (final doc in bundle.sourceDocuments) {
        expect(allowedTiers.contains(doc.dataTier), isTrue,
            reason:
                '${doc.sourceFamily} must be tiered as P1/P2/P3, got ${doc.dataTier}');
        expect(doc.ingestionStrategy, 'official_reference');
        final payload = jsonDecode(doc.rawPayload) as Map<String, dynamic>;
        expect(payload['tier'], doc.dataTier);
        expect(payload['tier_rationale'], isA<String>());
        expect(payload['parser_limitation'], contains('Registry-only entry'));
        final gaps = (payload['audit_gaps'] as List).cast<Map>();
        expect(gaps.any((g) => g['field'] == 'upstream_body'), isTrue,
            reason:
                '${doc.sourceFamily} must record an upstream_body audit_gap');
      }

      // Tier coverage: at least one P1, one P2, and one P3 must be declared.
      final tiers = bundle.sourceDocuments.map((d) => d.dataTier).toSet();
      expect(tiers, containsAll(<String>{'P1', 'P2', 'P3'}));

      // Conservative: registry MUST NOT emit drug or food concept rows.
      expect(bundle.drugConcepts, isEmpty);
      expect(bundle.foodConcepts, isEmpty);
      expect(bundle.conceptVariantCrosswalks, isEmpty);
    });

    test(
        'Secondary source registry source_doc_ids are stable across two builds',
        () {
      const importer = SecondarySourceRegistryImporter();
      final first = importer
          .importDeclaredCatalog()
          .sourceDocuments
          .map((d) => d.sourceDocId)
          .toList()
        ..sort();
      final second = importer
          .importDeclaredCatalog()
          .sourceDocuments
          .map((d) => d.sourceDocId)
          .toList()
        ..sort();
      expect(second, first);
    });

    test('FAO importer emits country crosswalk for diet profile', () {
      const importer = FaoFbdgP1Importer(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importCountryPage(
        countryCode: 'CN',
        url:
            'https://www.fao.org/nutrition/education/food-dietary-guidelines/regions/countries/china/en/',
        html: '<html><body>Official name FBDG China</body></html>',
      );
      final crosswalk = bundle.conceptVariantCrosswalks.single;
      expect(crosswalk.domain, 'country_diet_profile');
      expect(crosswalk.externalIdSystem, 'FAO FBDG country code');
      expect(crosswalk.externalIdValue, 'CN');
    });
  });

  group('Resumable orchestrator', () {
    test(
        'parse failure on first attempt retries; promote failure caches bundle and resume skips re-parse',
        () async {
      final database = _CountingCdssDatabase();
      final stubCdss = _ResumeStubCdssService(database);
      final orchestrator = P0IngestionOrchestrator(
        cdssService: stubCdss,
        fetchClient: const FakeSourceFetchClient(textByUrl: {}),
      );

      // Exercise the offline path with real bytes that the FDC importer can
      // parse to a tiny bundle.
      final fdcZipBytes = utf8.encode(jsonEncode([
        {
          'fdcId': 1,
          'description': 'Tofu',
          'dataType': 'Foundation',
          'foodCategory': 'protein',
          'foodNutrients': const [],
        }
      ]));
      // Wrap into a zip so importZipBytes finds a JSON entry.
      final archive = Archive()
        ..addFile(
          ArchiveFile(
            'foundationFoods.json',
            fdcZipBytes.length,
            fdcZipBytes,
          ),
        );
      final zipBytes = ZipEncoder().encode(archive)!;

      // First call: stubCdss will fail promote on the first attempt and succeed
      // on the second attempt. Since both attempts are within one
      // _runWithDescriptor call, the parse should only happen once and the
      // cached bundle should be reused for the second promote attempt.
      stubCdss.failPromoteOnce = true;
      final reports = await orchestrator.importOfflinePackagesDetailed(
        fdcZipBytes: zipBytes,
        sourcePaths: const {'fdc': '/tmp/fdc.zip'},
      );

      expect(reports, hasLength(1));
      final fdcReport = reports.first;
      expect(fdcReport.succeeded, isTrue);
      expect(stubCdss.promoteCalls, 2,
          reason: 'promote retried after first failure');
      // Database should record both fetch_parse and promote stages.
      final stageRows = database.runs
          .map((row) => '${row['stage']}|${row['status']}')
          .toList();
      expect(
        stageRows.where((row) => row == 'fetch_parse|parsed'),
        hasLength(1),
        reason:
            'parse only succeeded once because second attempt reused cached bundle',
      );
      expect(
        stageRows.where((row) => row == 'fetch_parse|skipped_already_parsed'),
        hasLength(1),
      );
      expect(
        stageRows.where((row) => row == 'promote|completed'),
        hasLength(1),
      );

      // Trigger an explicit resume on the same token: should be a no-op
      // because the run is already promote_completed.
      final priorPromoteCalls = stubCdss.promoteCalls;
      final replay =
          await orchestrator.resumeImportTask(fdcReport.resumeToken!);
      expect(replay.succeeded, isTrue);
      expect(stubCdss.promoteCalls, priorPromoteCalls,
          reason: 'completed runs should not re-promote on resume');
    });

    test('remote imports persist URL list + etag/last_modified in notes',
        () async {
      const medicineUrl = 'https://www.ema.europa.eu/en/medicines/eparmed';
      final fakeJson = jsonEncode([
        {
          'ema_product_number': 'EMEA-RES-1',
          'medicine_name': 'ResMed',
          'active_substance': 'levodopa',
          'medicine_url': medicineUrl,
        }
      ]);
      // Provide JSON for the medicines endpoint and pretend the XLSX endpoint
      // also responds (use the same JSON bytes — the XLSX parser will throw on
      // first attempt, but our orchestrator only needs metadata to be captured
      // before the parse step, so we wire a stub bundle via a custom client).
      final fakeClient = FakeSourceFetchClient(
        textByUrl: {
          'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines_json-report_en.json':
              fakeJson,
        },
        metadataByUrl: const {
          'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines_json-report_en.json':
              {
            'etag': 'W/"abc-1"',
            'last_modified': 'Wed, 01 May 2026 10:00:00 GMT'
          },
        },
      );
      final database = _CountingCdssDatabase();
      final stubCdss = _ResumeStubCdssService(database);
      final orchestrator = P0IngestionOrchestrator(
        cdssService: stubCdss,
        fetchClient: fakeClient,
      );

      // Drive the EMA medicines path; the XLSX fetch will throw because the
      // fake client has no entry for it. We only assert that the failure is
      // captured *with* remote metadata and URL list in the notes.
      await orchestrator.importEmaMedicinesMetadataDetailed();

      final emaRows = database.runs
          .where(
              (row) => '${row['run_id']}'.startsWith('import_ema_medicines_'))
          .toList();
      expect(emaRows, isNotEmpty);
      final firstNotes =
          jsonDecode('${emaRows.first['notes_json']}') as Map<String, dynamic>;
      expect((firstNotes['remote_urls'] as List), isNotEmpty);
      // Most recent rows reflect a fetch_parse run; remote_metadata is
      // populated only after the underlying fetch client recorded it. The
      // FakeSourceFetchClient returns metadata immediately, so it should be
      // surfaced in describe() alongside source_key + input_kind.
      expect(firstNotes['source_key'], 'ema_medicines');
      expect(firstNotes['input_kind'], 'remote_fetch');
      expect(firstNotes.containsKey('checksum'), isTrue);
      expect(firstNotes['etag'], 'W/"abc-1"');
      expect(firstNotes['last_modified'], 'Wed, 01 May 2026 10:00:00 GMT');
      // last_completed_stage / cached_bundle_available appear once parse
      // succeeds; they are present in the first run with the initial running
      // state being null/false respectively.
      expect(firstNotes.containsKey('cached_bundle_available'), isTrue);
    });

    test('remote run persists etag once fetch metadata is available', () async {
      // Build a minimal in-memory chain that exercises the metadata pipeline:
      // a FakeSourceFetchClient seeded with metadata + a valid JSON body for
      // the medicines endpoint, and a no-op XLSX endpoint that returns empty
      // bytes (XLSX parser will then return an empty bundle, not throw).
      final fakeJson = jsonEncode(const <Map<String, dynamic>>[]);
      final emptyXlsx = ZipEncoder().encode(Archive())!;
      final emptyXlsxText = String.fromCharCodes(emptyXlsx);
      final fakeClient = FakeSourceFetchClient(
        textByUrl: {
          'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines_json-report_en.json':
              fakeJson,
          'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines_report_en.xlsx':
              emptyXlsxText,
          // XLSX endpoint URL the importer actually calls:
          'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines-report_en.xlsx':
              emptyXlsxText,
        },
        metadataByUrl: const {
          'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines_json-report_en.json':
              {'etag': 'W/"json-etag"'},
          'https://www.ema.europa.eu/en/documents/report/medicines-output-medicines-report_en.xlsx':
              {'last_modified': 'Wed, 01 May 2026 09:00:00 GMT'},
        },
      );
      final database = _CountingCdssDatabase();
      final stubCdss = _ResumeStubCdssService(database);
      final orchestrator = P0IngestionOrchestrator(
        cdssService: stubCdss,
        fetchClient: fakeClient,
      );

      try {
        await orchestrator.importEmaMedicinesMetadataDetailed();
      } catch (_) {
        // The empty-xlsx path may still throw inside the importer; the
        // metadata-capture assertion below only needs the descriptor to have
        // been created and a run row to be persisted.
      }

      final hasRemoteMetadata = database.runs.any((row) {
        final notes =
            jsonDecode('${row['notes_json']}') as Map<String, dynamic>;
        return notes['remote_metadata'] is Map &&
            (notes['remote_metadata'] as Map).isNotEmpty;
      });
      expect(hasRemoteMetadata, isTrue,
          reason:
              'remote_metadata should be persisted in at least one run row');
    });

    test(
        'resume notes include retry_attempt and max_attempts for local imports',
        () async {
      final database = _CountingCdssDatabase();
      final stubCdss = _ResumeStubCdssService(database);
      final orchestrator = P0IngestionOrchestrator(
        cdssService: stubCdss,
        fetchClient: const FakeSourceFetchClient(textByUrl: {}),
      );
      final fdcJsonBytes = utf8.encode(jsonEncode([
        {
          'fdcId': 1,
          'description': 'RetryFood',
          'dataType': 'Foundation',
          'foodCategory': 'protein',
          'foodNutrients': const [],
        }
      ]));
      final archive = Archive()
        ..addFile(ArchiveFile(
            'foundationFoods.json', fdcJsonBytes.length, fdcJsonBytes));
      final zipBytes = ZipEncoder().encode(archive)!;

      stubCdss.failPromoteOnce = true;
      await orchestrator.importOfflinePackagesDetailed(
        fdcZipBytes: zipBytes,
        sourcePaths: const {'fdc': '/tmp/retry/fdc.zip'},
      );

      final fdcRows = database.runs
          .where((row) => '${row['run_id']}'.startsWith('import_fdc_'))
          .toList();
      expect(fdcRows, isNotEmpty);
      final attempts = fdcRows
          .map((row) =>
              jsonDecode('${row['notes_json']}') as Map<String, dynamic>)
          .map((notes) => notes['retry_attempt'])
          .whereType<int>()
          .toSet();
      // Promote failed once and was retried, so we expect to see attempts 1 and 2.
      expect(attempts, containsAll([1, 2]));
      for (final row in fdcRows) {
        final notes =
            jsonDecode('${row['notes_json']}') as Map<String, dynamic>;
        expect(notes['max_attempts'], 2);
        expect(notes['resume_supported'], isTrue);
      }
    });

    test(
        'orchestrator notes include importer_id and source_url for both local and remote runs',
        () async {
      // --- local path ---
      final database = _CountingCdssDatabase();
      final stubCdss = _ResumeStubCdssService(database);
      final orchestrator = P0IngestionOrchestrator(
        cdssService: stubCdss,
        fetchClient: const FakeSourceFetchClient(textByUrl: {}),
      );
      final fdcJsonBytes = utf8.encode(jsonEncode([
        {
          'fdcId': 1,
          'description': 'X',
          'dataType': 'Foundation',
          'foodCategory': 'protein',
          'foodNutrients': const [],
        }
      ]));
      final archive = Archive()
        ..addFile(ArchiveFile(
            'foundationFoods.json', fdcJsonBytes.length, fdcJsonBytes));
      final zipBytes = ZipEncoder().encode(archive)!;
      await orchestrator.importOfflinePackagesDetailed(
        fdcZipBytes: zipBytes,
        sourcePaths: const {'fdc': '/tmp/audit/fdc.zip'},
      );
      final localRow = database.runs
          .firstWhere((row) => '${row['run_id']}'.startsWith('import_fdc_'));
      final localNotes =
          jsonDecode('${localRow['notes_json']}') as Map<String, dynamic>;
      expect(localNotes['importer_id'], 'fdc');
      expect(localNotes['source_url'], '/tmp/audit/fdc.zip');

      // --- remote path ---
      const medicinesUrl = P0SourceUrls.emaMedicinesJson;
      final fakeClient = FakeSourceFetchClient(
        textByUrl: {medicinesUrl: jsonEncode(const <Map<String, dynamic>>[])},
        metadataByUrl: const {},
      );
      final remoteDb = _CountingCdssDatabase();
      final remoteOrchestrator = P0IngestionOrchestrator(
        cdssService: _ResumeStubCdssService(remoteDb),
        fetchClient: fakeClient,
      );
      try {
        await remoteOrchestrator.importEmaMedicinesMetadataDetailed();
      } catch (_) {
        // Underlying XLSX endpoint is missing in fixtures; we only need an
        // ingestion_run row to be persisted.
      }
      final remoteRow = remoteDb.runs.firstWhere(
          (row) => '${row['run_id']}'.startsWith('import_ema_medicines_'));
      final remoteNotes =
          jsonDecode('${remoteRow['notes_json']}') as Map<String, dynamic>;
      expect(remoteNotes['importer_id'], 'ema_medicines');
      expect(remoteNotes['source_url'], medicinesUrl);
    });

    test(
        'unavailable remote source persists a failed audit row with checkpoint',
        () async {
      final database = _CountingCdssDatabase();
      final stubCdss = _ResumeStubCdssService(database);
      // Empty fake client: every URL fetch will throw.
      final orchestrator = P0IngestionOrchestrator(
        cdssService: stubCdss,
        fetchClient: const FakeSourceFetchClient(textByUrl: {}),
      );
      final report = await orchestrator.importEmaMedicinesMetadataDetailed();
      expect(report.succeeded, isFalse);

      final failures = database.runs
          .map((row) =>
              jsonDecode('${row['notes_json']}') as Map<String, dynamic>)
          .where((notes) => notes['checkpoint'] == 'failed_before_parse')
          .toList();
      expect(failures, isNotEmpty);
      final firstFailure = failures.first;
      expect(firstFailure['error_message'], isA<String>());
      expect(firstFailure['retry_attempt'], isA<int>());
      expect(firstFailure['max_attempts'], 2);
      expect(firstFailure['importer_id'], 'ema_medicines');
    });

    test(
        'every importer crosswalk row exposes a parser_limitation key (nullable)',
        () {
      const importer = ChinaCdcFoodPlatformImporter(
        fetchClient: FakeSourceFetchClient(textByUrl: {}),
      );
      final bundle = importer.importFoodPage(
        url: 'https://nlc.chinanutri.cn/fq/foodinfo/9001.html',
        html: '<html>苹果 食物类：水果 亚 类：苹果</html>',
      );
      for (final crosswalk in bundle.conceptVariantCrosswalks) {
        final payload =
            jsonDecode(crosswalk.mappingPayloadJson) as Map<String, dynamic>;
        expect(payload.containsKey('parser_limitation'), isTrue,
            reason:
                'parser_limitation key must be present (may be null) for ${crosswalk.externalIdSystem}');
      }
    });

    test(
        'back-to-back same-source imports on one orchestrator never collide on resume tokens',
        () async {
      final database = _CountingCdssDatabase();
      final stubCdss = _ResumeStubCdssService(database);
      final orchestrator = P0IngestionOrchestrator(
        cdssService: stubCdss,
        fetchClient: const FakeSourceFetchClient(textByUrl: {}),
      );
      final fdcJsonBytes = utf8.encode(jsonEncode([
        {
          'fdcId': 1,
          'description': 'CollideFood',
          'dataType': 'Foundation',
          'foodCategory': 'protein',
          'foodNutrients': const [],
        }
      ]));
      final archive = Archive()
        ..addFile(ArchiveFile(
            'foundationFoods.json', fdcJsonBytes.length, fdcJsonBytes));
      final zipBytes = ZipEncoder().encode(archive)!;

      final tokens = <String>{};
      for (var i = 0; i < 5; i++) {
        final reports = await orchestrator.importOfflinePackagesDetailed(
          fdcZipBytes: zipBytes,
          sourcePaths: const {'fdc': '/tmp/collide/fdc.zip'},
        );
        expect(reports.single.succeeded, isTrue);
        expect(tokens.add(reports.single.resumeToken!), isTrue,
            reason:
                'resumeToken must be unique even for back-to-back same-source imports on a single orchestrator instance');
      }
    });

    test('local imports persist source key, local path, and checksum in notes',
        () async {
      final database = _CountingCdssDatabase();
      final stubCdss = _ResumeStubCdssService(database);
      final orchestrator = P0IngestionOrchestrator(
        cdssService: stubCdss,
        fetchClient: const FakeSourceFetchClient(textByUrl: {}),
      );

      final fdcJsonBytes = utf8.encode(jsonEncode([
        {
          'fdcId': 1,
          'description': 'Tofu',
          'dataType': 'Foundation',
          'foodCategory': 'protein',
          'foodNutrients': const [],
        }
      ]));
      final archive = Archive()
        ..addFile(ArchiveFile(
            'foundationFoods.json', fdcJsonBytes.length, fdcJsonBytes));
      final zipBytes = ZipEncoder().encode(archive)!;

      await orchestrator.importOfflinePackagesDetailed(
        fdcZipBytes: zipBytes,
        sourcePaths: const {'fdc': '/tmp/local/fdc.zip'},
      );

      final fdcRows = database.runs
          .where((row) => '${row['run_id']}'.startsWith('import_fdc_'))
          .toList();
      expect(fdcRows, isNotEmpty);
      for (final row in fdcRows) {
        final notes =
            jsonDecode('${row['notes_json']}') as Map<String, dynamic>;
        expect(notes['source_key'], 'fdc');
        expect(notes['input_kind'], 'local_bytes');
        expect(notes['local_path'], '/tmp/local/fdc.zip');
        expect((notes['checksum'] as String).isNotEmpty, isTrue);
        expect(notes['resume_supported'], isTrue);
        expect(notes.containsKey('cached_bundle_available'), isTrue);
      }
    });
  });
}

Map<String, P0ImportBundle> _buildImporterAuditSmokeBundles() {
  const dailyMed = DailyMedP0Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );
  const dpd = HealthCanadaDpdP0Importer(
    fetchClient: FakeSourceFetchClient(
      textByUrl: {
        'https://health-products.canada.ca/dpd-bdpp/info?code=smoke&lang=eng':
            '<html><h2>Details</h2><p>Body.</p></html>',
      },
    ),
  );
  const ema = EmaP1Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );
  const pmda = PmdaP1Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );
  const fdc = FdcP0Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );
  const ciqual = CiqualP0Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );
  const china = ChinaCdcFoodPlatformImporter(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );
  const fao = FaoFbdgP1Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );

  return {
    'DailyMed': dailyMed.importSplXml(
      '<document><setId root="smoke-1" /><title>SmokeMed</title>'
      '<ingredient><name>levodopa</name></ingredient>'
      '<routeCode displayName="oral" /><formCode displayName="tablet" />'
      '<section><title>S</title><text>x</text></section></document>',
      ndcs: const [
        {'ndc': '99999-0001-01', 'package_description': 'box of 30'}
      ],
    ),
    'DPD base': dpd.importFromPayloads(
      drugProducts: const [
        {
          'drug_code': 'smoke',
          'drug_identification_number': '12121212',
          'brand_name': 'SmokeCa',
          'pharmaceutical_form_code': 'TAB',
          'route_of_administration_code': 'ORAL',
          'drug_status_code': 'M'
        }
      ],
      activeIngredients: const [
        {'drug_code': 'smoke', 'ingredient_name': 'Levodopa'}
      ],
      forms: const [
        {'pharmaceutical_form_code': 'TAB', 'pharmaceutical_form_name': 'tab'}
      ],
      routes: const [
        {
          'route_of_administration_code': 'ORAL',
          'route_of_administration_name': 'oral'
        }
      ],
      statuses: const [
        {'drug_status_code': 'M', 'status': 'marketed'}
      ],
    ),
    'EMA': ema.importMedicinesJson(
      jsonEncode([
        {
          'ema_product_number': 'EMEA-SMOKE-1',
          'medicine_name': 'EmaSmoke',
          'active_substance': 'levodopa',
          'medicine_url': 'https://www.ema.europa.eu/en/medicines/emasmoke',
          'condition_indication':
              'Long indication narrative we never structure.',
          'procedure_type': 'Centralised',
        }
      ]),
      sourceLabel: 'smoke_ema',
    ),
    'PMDA english': pmda.importEnglishReferenceIndex(
        '<html><a href="/files/0001/x.pdf">English translated package insert</a></html>'),
    'PMDA japanese': pmda.importJapaneseProductDetail(
      detailUrl:
          'https://www.pmda.go.jp/PmdaSearch/iyakuDetail/GeneralList/smoke',
      html: '<html><h1>煙</h1></html>',
    ),
    'FDC': fdc.importFoods(const [
      {
        'fdcId': 11111,
        'description': 'SmokeFood',
        'dataType': 'Foundation',
        'foodCategory': 'snack',
        'foodNutrients': [],
        'foodPortions': [
          {'amount': 1, 'modifier': 'piece', 'gramWeight': 10.0}
        ],
      }
    ], sourceLabel: 'smoke_fdc'),
    'Ciqual': ciqual.importFromXmlStrings(
      alimXml:
          '<root><row><alim_code>11111</alim_code><alim_nom_fr>x</alim_nom_fr><alim_grp_code>X</alim_grp_code></row></root>',
      alimGrpXml:
          '<root><row><alim_grp_code>X</alim_grp_code><alim_grp_nom_fr>x</alim_grp_nom_fr></row></root>',
      constXml:
          '<root><row><const_code>PROT</const_code><const_nom_eng>Protein</const_nom_eng><unite>g</unite></row></root>',
      compoXml:
          '<root><row><alim_code>11111</alim_code><const_code>PROT</const_code><teneur>0.1</teneur><source_code>S1</source_code></row></root>',
      sourcesXml:
          '<root><row><source_code>S1</source_code><source_nom>m1</source_nom></row></root>',
    ),
    'China CDC': china.importFoodPage(
      url: 'https://nlc.chinanutri.cn/fq/foodinfo/11111.html',
      html: '<html>苹果 食物类：水果 亚 类：苹果</html>',
    ),
    'FAO': fao.importCountryPage(
      countryCode: 'TH',
      url: 'https://www.fao.org/.../thailand/en/',
      html: '<html><body>Official name FBDG Thailand</body></html>',
    ),
  };
}

Map<String, List<String>> _importerAuditSmokeSignature(
  Map<String, P0ImportBundle> bundles,
) {
  return {
    for (final entry in bundles.entries)
      entry.key: (entry.value.conceptVariantCrosswalks.map((row) {
        final payload = jsonDecode(row.mappingPayloadJson) as Map;
        final keys = payload.keys.map((key) => '$key').toList()..sort();
        return [
          row.domain,
          row.conceptId,
          row.variantId,
          row.externalIdSystem,
          row.externalIdValue,
          row.status,
          payload['source_identifier_type'],
          payload['confidence_reason'],
          keys.join('|'),
        ].join('::');
      }).toList()
        ..sort()),
  };
}

class _CountingCdssDatabase implements CdssDatabase {
  final List<Map<String, Object?>> runs = <Map<String, Object?>>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) async {}

  @override
  Future<void> insertCountryDietProfile(
      CountryDietProfileRecord record) async {}

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) async {}

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) async {}

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) async {}

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) async {}

  @override
  Future<void> insertDrugProductPackaging(
      DrugProductPackagingRecord record) async {}

  @override
  Future<void> insertDrugProductVariant(
      DrugProductVariantRecord record) async {}

  @override
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) async {}

  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {}

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {}

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) async {
    runs.add({
      'run_id': record.runId,
      'stage': record.stage,
      'status': record.status,
      'notes_json': record.notesJson,
    });
  }

  @override
  Future<void> insertSnapshotDistribution(
      SnapshotDistributionRecord record) async {}

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {}

  @override
  Future<void> clearStagingRun(String runId) async {}

  @override
  Future<void> insertLocaleResourceBundle(
      LocaleResourceBundleRecord record) async {}

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) async {}

  @override
  Future<void> insertObservation(ObservationRecord record) async {}

  @override
  Future<void> insertRecommendationAuditLog(
      RecommendationAuditLogRecord record) async {}

  @override
  Future<void> insertRegionJurisdictionMap(
      RegionJurisdictionMapRecord record) async {}

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {}

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {}

  @override
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) async {}

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {}

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {}

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async => const [];
}

class _ResumeStubCdssService extends ClinicalDecisionSupportService {
  int promoteCalls = 0;
  bool failPromoteOnce = false;

  _ResumeStubCdssService(CdssDatabase db)
      : super(
          database: db,
          factConflictEngine: FactConflictEngine(),
          runtimeRuleEngine: RuntimeRuleEngine(),
        );

  @override
  Future<CdssImportReport> importBundle(P0ImportBundle bundle) async {
    promoteCalls += 1;
    if (failPromoteOnce) {
      failPromoteOnce = false;
      throw StateError('promote boom');
    }
    return CdssImportReport(
      runId: 'stub_run_$promoteCalls',
      sourceFamily: bundle.sourceDocuments.isEmpty
          ? 'STUB'
          : bundle.sourceDocuments.first.sourceFamily,
      stagingSnapshotId: 'staging_stub',
      promotedSnapshotId: 'promoted_stub',
      sourceDocumentCount: bundle.sourceDocuments.length,
      foodCount: bundle.foodVariants.length,
      drugCount: bundle.drugProductVariants.length,
      observationCount: bundle.observations.length,
      ruleRegistryCount: bundle.ruleRegistryRows.length,
      runtimeEventCount: bundle.runtimeEvents.length,
      completedAt: DateTime.now(),
    );
  }
}

List<int> _buildMinimalXlsx({
  required List<String> headers,
  required List<List<String>> rows,
}) {
  final sharedStrings = <String>[
    ...headers,
    ...rows.expand((row) => row),
  ];
  final contentTypesBytes = utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
  <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
  <Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>
</Types>
''');
  final workbookBytes = utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheets><sheet name="Sheet1" sheetId="1" r:id="rId1" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"/></sheets>
</workbook>
''');
  final sharedStringsBytes = utf8.encode('''
<?xml version="1.0" encoding="UTF-8"?>
<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="${sharedStrings.length}" uniqueCount="${sharedStrings.length}">
${sharedStrings.map((value) => '<si><t>${_escapeXml(value)}</t></si>').join()}
</sst>
''');
  final worksheetBytes =
      utf8.encode(_buildSheetXml(headers.length, rows.length));
  final archive = Archive()
    ..addFile(
      ArchiveFile(
        '[Content_Types].xml',
        contentTypesBytes.length,
        contentTypesBytes,
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/workbook.xml',
        workbookBytes.length,
        workbookBytes,
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/sharedStrings.xml',
        sharedStringsBytes.length,
        sharedStringsBytes,
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/worksheets/sheet1.xml',
        worksheetBytes.length,
        worksheetBytes,
      ),
    );
  return ZipEncoder().encode(archive)!;
}

String _buildSheetXml(int headerCount, int rowCount) {
  final rows = <String>[];
  rows.add(_buildRowXml(1, List<int>.generate(headerCount, (index) => index)));
  var sharedIndex = headerCount;
  for (var rowIndex = 0; rowIndex < rowCount; rowIndex++) {
    rows.add(
      _buildRowXml(
        rowIndex + 2,
        List<int>.generate(headerCount, (_) => sharedIndex++),
      ),
    );
  }
  return '''
<?xml version="1.0" encoding="UTF-8"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
  <sheetData>
    ${rows.join()}
  </sheetData>
</worksheet>
''';
}

String _buildRowXml(int rowNumber, List<int> sharedIndexes) {
  final cells = <String>[];
  for (var index = 0; index < sharedIndexes.length; index++) {
    final column = String.fromCharCode('A'.codeUnitAt(0) + index);
    cells.add(
        '<c r="$column$rowNumber" t="s"><v>${sharedIndexes[index]}</v></c>');
  }
  return '<row r="$rowNumber">${cells.join()}</row>';
}

String _escapeXml(String input) {
  return input
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}

class _FakeCdssDatabase implements CdssDatabase {
  _FakeCdssDatabase({this.tables = const {}});

  final Map<String, List<Map<String, Object?>>> tables;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) async {}

  @override
  Future<void> insertCountryDietProfile(
      CountryDietProfileRecord record) async {}

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) async {}

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) async {}

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) async {}

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) async {}

  @override
  Future<void> insertDrugProductPackaging(
      DrugProductPackagingRecord record) async {}

  @override
  Future<void> insertDrugProductVariant(
      DrugProductVariantRecord record) async {}

  @override
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) async {}

  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {}

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {}

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) async {}

  @override
  Future<void> insertSnapshotDistribution(
      SnapshotDistributionRecord record) async {}

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {}

  @override
  Future<void> clearStagingRun(String runId) async {}

  @override
  Future<void> insertLocaleResourceBundle(
      LocaleResourceBundleRecord record) async {}

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) async {}

  @override
  Future<void> insertObservation(ObservationRecord record) async {}

  @override
  Future<void> insertRecommendationAuditLog(
      RecommendationAuditLogRecord record) async {}

  @override
  Future<void> insertRegionJurisdictionMap(
      RegionJurisdictionMapRecord record) async {}

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {}

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {}

  @override
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) async {}

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {}

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {}

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      tables[table] ?? const [];
}
