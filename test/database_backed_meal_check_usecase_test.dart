import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/interaction_result.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_conflict_result.dart';
import 'package:parkinsum_companion/domain/entities/rule_registry_models.dart';
import 'package:parkinsum_companion/domain/entities/runtime_context.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/database_backed_meal_check_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/imported_label_rule_provider.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';
import 'package:parkinsum_companion/domain/usecases/variant_resolver.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';

class QueryBackedCdssDatabase implements CdssDatabase {
  QueryBackedCdssDatabase(this.tables);

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
  Future<void> insertDrugProductPackaging(
      DrugProductPackagingRecord record) async {}

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) async {}

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
  Future<void> insertIngestionRun(IngestionRunRecord record) async {}

  @override
  Future<void> insertSnapshotDistribution(
      SnapshotDistributionRecord record) async {}

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {}

  @override
  Future<void> clearStagingRun(String runId) async {}

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {}

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {}

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      tables[table] ?? const <Map<String, Object?>>[];
}

class RecordingMechanisticConflictEngine extends MechanisticConflictEngine {
  MealComposition? composition;
  TimeAxisConflictContext? context;

  @override
  MechanisticConflictResult evaluate({
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    String resultId = 'mechanistic_result',
    String? preferredMealId,
  }) {
    this.context = context;
    composition = mealCompositionsById.values.single;
    return super.evaluate(
      context: context,
      mealCompositionsById: mealCompositionsById,
      resultId: resultId,
      preferredMealId: preferredMealId,
    );
  }
}

void main() {
  test('variant resolver prefers jurisdiction-specific variants', () async {
    final db = QueryBackedCdssDatabase({
      'region_jurisdiction_map': [
        {
          'region_code': 'US',
          'jurisdiction_chain_json': '["US","NA","GLOBAL"]',
          'food_source_priority_json': '["USDA_FDC","GLOBAL"]',
          'drug_source_priority_json': '["DAILYMED","GLOBAL"]',
        },
      ],
      'food_variant': [
        {
          'food_variant_id': 'FOOD_BANANA#GLOBAL#LOCAL#food_banana',
          'food_concept_id': 'FOOD_BANANA',
          'jurisdiction': 'GLOBAL',
          'source_family': 'GLOBAL',
          'source_food_code': 'food_banana',
          'is_authoritative_for_region': 0,
        },
        {
          'food_variant_id': 'FOOD_BANANA#US#USDA_FDC#food_banana',
          'food_concept_id': 'FOOD_BANANA',
          'jurisdiction': 'US',
          'source_family': 'USDA_FDC',
          'source_food_code': 'food_banana',
          'is_authoritative_for_region': 1,
        },
      ],
      'drug_product_variant': [
        {
          'drug_product_variant_id':
              'DRUG_LDOPA#GLOBAL#LOCAL#drug_levodopa_carbidopa',
          'drug_concept_id': 'DRUG_LDOPA',
          'jurisdiction': 'GLOBAL',
          'regulator': 'GLOBAL',
          'external_product_code': 'drug_levodopa_carbidopa',
          'route': 'oral',
          'dosage_form': 'tablet',
          'release_type': 'immediate',
        },
        {
          'drug_product_variant_id':
              'DRUG_LDOPA#US#DAILYMED#drug_levodopa_carbidopa',
          'drug_concept_id': 'DRUG_LDOPA',
          'jurisdiction': 'US',
          'regulator': 'DAILYMED',
          'external_product_code': 'drug_levodopa_carbidopa',
          'route': 'oral',
          'dosage_form': 'tablet',
          'release_type': 'immediate',
        },
      ],
    });

    final resolver = VariantResolver(database: db);
    const profile = UserProfileRuntimeContext(
      patientId: 'patient_1',
      registrationRegion: 'US',
      displayLocale: 'en-US',
      contentJurisdictionOverride: [],
      dietProfileRegion: 'US',
      timezone: 'America/Toronto',
    );

    final foodVariant = await resolver.resolveFoodVariant(
      foodId: 'food_banana',
      userProfile: profile,
    );
    final drugVariant = await resolver.resolveDrugVariant(
      drugId: 'drug_levodopa_carbidopa',
      userProfile: profile,
    );

    expect(
        foodVariant.selectedVariantId, 'FOOD_BANANA#US#USDA_FDC#food_banana');
    expect(foodVariant.fallbackUsed, isFalse);
    expect(drugVariant.selectedVariantId,
        'DRUG_LDOPA#US#DAILYMED#drug_levodopa_carbidopa');
    expect(drugVariant.fallbackUsed, isFalse);
  });

  test(
      'database-backed meal check uses resolved variants without fallback note',
      () async {
    final db = QueryBackedCdssDatabase({
      'region_jurisdiction_map': [
        {
          'region_code': 'US',
          'jurisdiction_chain_json': '["US","NA","GLOBAL"]',
          'food_source_priority_json': '["USDA_FDC","GLOBAL"]',
          'drug_source_priority_json': '["DAILYMED","GLOBAL"]',
        },
      ],
      'food_variant': [
        {
          'food_variant_id': 'FOOD_CHICKEN#US#USDA_FDC#food_chicken_breast',
          'food_concept_id': 'FOOD_CHICKEN',
          'jurisdiction': 'US',
          'source_family': 'USDA_FDC',
          'source_food_code': 'food_chicken_breast',
          'is_authoritative_for_region': 1,
        },
      ],
      'observation': [
        {
          'observation_id': 'obs_chicken_protein',
          'entity_key': 'FOOD_CHICKEN#US#USDA_FDC#food_chicken_breast',
          'attribute_code': 'protein_g',
          'qualifier_kind': 'exact',
          'value_num': 31.0,
        },
        {
          'observation_id': 'obs_chicken_carbs',
          'entity_key': 'FOOD_CHICKEN#US#USDA_FDC#food_chicken_breast',
          'attribute_code': 'carbohydrate_g',
          'qualifier_kind': 'exact',
          'value_num': 0.0,
        },
        {
          'observation_id': 'obs_chicken_fat',
          'entity_key': 'FOOD_CHICKEN#US#USDA_FDC#food_chicken_breast',
          'attribute_code': 'fat_g',
          'qualifier_kind': 'exact',
          'value_num': 3.6,
        },
      ],
      'drug_product_variant': [
        {
          'drug_product_variant_id':
              'DRUG_LDOPA#US#DAILYMED#drug_levodopa_carbidopa',
          'drug_concept_id': 'DRUG_LDOPA',
          'jurisdiction': 'US',
          'regulator': 'DAILYMED',
          'external_product_code': 'drug_levodopa_carbidopa',
          'route': 'oral',
          'dosage_form': 'tablet',
          'release_type': 'immediate',
        },
      ],
      'source_document': [
        {
          'source_doc_id': 'fda-dhivy-high-protein',
          'title': 'DHIVY label food effect reference',
          'origin_url':
              'https://www.accessdata.fda.gov/drugsatfda_docs/label/2022/214829s000lbl.pdf',
          'raw_payload': '{"pmid":"35730414"}',
        },
      ],
    });

    final compiler = RuleRegistryCompiler();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final useCase = DatabaseBackedMealCheckUseCase(
      variantResolver: VariantResolver(database: db),
      clinicalDecisionSupportService: service,
      compiledRules: compiler.compileJsonList(
        baselineCdssRules,
        rulesVersion: 'test_rules',
      ),
    );

    final result = await useCase(
      meal: Meal(
        id: 'meal_1',
        eatenAt: DateTime.utc(2026, 1, 1, 9),
        title: 'Breakfast',
        items: [
          MealItem(
            foodId: 'food_chicken_breast',
            foodName: '鸡胸肉',
            foodCategory: FoodCategory.protein,
            quantityFactor: 1,
            foodTags: const [],
            proteinPer100g: 5,
            carbsPer100g: 0,
            fatPer100g: 3.6,
            fiberPer100g: 0,
            sodiumPer100g: 70,
          ),
        ],
      ),
      activeDrugs: [
        DrugDefinition(
          id: 'drug_levodopa_carbidopa',
          genericName: 'Levodopa/Carbidopa',
          brandNames: ['Sinemet'],
          tags: [DrugTag.levodopaLike],
          notes: '',
        ),
      ],
      intakes: [
        Intake(
          id: 'intake_1',
          drugId: 'drug_levodopa_carbidopa',
          takenAt: DateTime.utc(2026, 1, 1, 8),
          dosageNote: '300 mg/day',
        ),
      ],
      userProfile: UserProfile.defaults(),
    );

    expect(result.status, InteractionStatus.warning);
    expect(result.score, greaterThanOrEqualTo(70));
    expect(
      result.scoreFactors.map((factor) => factor.code),
      containsAll([
        'levodopa_interference_weight',
        'protein_timing_penalty',
        'rule_decision_weight',
      ]),
    );
    expect(result.analysisText, contains('weighted'));
    expect(result.issues, isNotEmpty);
    expect(result.issues.first.detail.contains('回退链'), isFalse);
    expect(
      result.issues.first.detail,
      contains('database food variants'),
    );
    expect(result.issues.first.evidence, isNotEmpty);
    expect(
      result.issues.first.evidence.first.title,
      'DHIVY label food effect reference',
    );
    expect(result.issues.first.evidence.first.pmid, '35730414');
    expect(result.keyFindings, isNotEmpty);
    expect(result.nextActions, isNotEmpty);
    expect(
      result.dataNotes.any((note) => note.contains('database')),
      isTrue,
    );
    expect(
      result.dataNotes
          .any((note) => note.contains('fallback_variant_resolution')),
      isFalse,
    );
  });

  test(
      'database-backed meal check can fire imported official label rules from source_document facts',
      () async {
    final db = QueryBackedCdssDatabase({
      'region_jurisdiction_map': [
        {
          'region_code': 'US',
          'jurisdiction_chain_json': '["US","NA","GLOBAL"]',
          'food_source_priority_json': '["USDA_FDC","GLOBAL"]',
          'drug_source_priority_json': '["DAILYMED","GLOBAL"]',
        },
      ],
      'food_variant': [
        {
          'food_variant_id': 'FOOD_SOUP#US#USDA_FDC#food_soup',
          'food_concept_id': 'FOOD_SOUP',
          'jurisdiction': 'US',
          'source_family': 'USDA_FDC',
          'source_food_code': 'food_soup',
          'is_authoritative_for_region': 1,
        },
      ],
      'observation': [
        {
          'observation_id': 'obs_soup_protein',
          'entity_key': 'FOOD_SOUP#US#USDA_FDC#food_soup',
          'attribute_code': 'protein_g',
          'qualifier_kind': 'exact',
          'value_num': 2.0,
        },
        {
          'observation_id': 'obs_soup_carbs',
          'entity_key': 'FOOD_SOUP#US#USDA_FDC#food_soup',
          'attribute_code': 'carbohydrate_g',
          'qualifier_kind': 'exact',
          'value_num': 8.0,
        },
      ],
      'drug_product_variant': [
        {
          'drug_product_variant_id':
              'DRUG_OPICAPONE#US#DAILYMED#drug_opicapone',
          'drug_concept_id': 'DRUG_OPICAPONE',
          'jurisdiction': 'US',
          'regulator': 'DAILYMED',
          'external_product_code': 'drug_opicapone',
          'route': 'oral',
          'dosage_form': 'capsule',
          'release_type': 'immediate',
        },
      ],
      'drug_label_section': [
        {
          'section_id': 'section_1',
          'drug_product_variant_id':
              'DRUG_OPICAPONE#US#DAILYMED#drug_opicapone',
          'source_doc_id': 'doc_opicapone',
          'section_key': 'administration',
          'section_title': 'Administration',
          'section_text':
              'Take at least 1 hour before and at least 2 hours after meals.',
        },
      ],
      'source_document': [
        {
          'source_doc_id': 'doc_opicapone',
          'title': 'Imported opicapone label fact',
          'origin_url': 'https://example.test/opicapone',
          'source_family': 'DAILYMED',
          'raw_payload': '''
{
  "label_facts": [
    {
      "fact_type": "meal_window_before_after",
      "label": "Meal timing window",
      "value_text": "60 min before meal / 120 min after meal",
      "payload": {
        "before_minutes": 60,
        "after_minutes": 120
      }
    }
  ]
}
''',
        },
      ],
    });

    final compiler = RuleRegistryCompiler();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final useCase = DatabaseBackedMealCheckUseCase(
      variantResolver: VariantResolver(database: db),
      clinicalDecisionSupportService: service,
      compiledRules: const <RuleRegistryEntry>[],
      importedLabelRuleProvider: ImportedLabelRuleProvider(
        database: db,
        compiler: compiler,
      ),
    );

    final result = await useCase(
      meal: Meal(
        id: 'meal_2',
        eatenAt: DateTime.utc(2026, 1, 1, 8, 30),
        title: 'Soup',
        items: [
          MealItem(
            foodId: 'food_soup',
            foodName: 'Soup',
            foodCategory: FoodCategory.other,
            quantityFactor: 1,
            foodTags: const [],
            proteinPer100g: 2,
            carbsPer100g: 8,
            fatPer100g: 1,
            fiberPer100g: 0,
            sodiumPer100g: 100,
          ),
        ],
      ),
      activeDrugs: [
        DrugDefinition(
          id: 'drug_opicapone',
          genericName: 'Opicapone',
          brandNames: ['Ongentys'],
          tags: const [DrugTag.comtInhibitor],
          notes: '',
        ),
      ],
      intakes: [
        Intake(
          id: 'intake_2',
          drugId: 'drug_opicapone',
          takenAt: DateTime.utc(2026, 1, 1, 8, 0),
          dosageNote: '50 mg',
        ),
      ],
      userProfile: UserProfile.defaults(),
    );

    expect(result.issues, isNotEmpty);
    expect(
      result.issues.first.detail,
      contains('official label requires separation from meals'),
    );
    expect(
      result.issues.first.evidence.first.title,
      'Imported opicapone label fact',
    );
    expect(
      result.keyFindings.any(
        (line) =>
            line.contains('Official source') &&
            line.contains('Imported opicapone label fact'),
      ),
      isTrue,
    );
    expect(
      result.analysisText,
      contains('official label or a registered evidence source'),
    );
  });

  test('meal iron coevent triggers imported official label warn rule',
      () async {
    final db = QueryBackedCdssDatabase({
      'region_jurisdiction_map': [
        {
          'region_code': 'US',
          'jurisdiction_chain_json': '["US","NA","GLOBAL"]',
          'food_source_priority_json': '["USDA_FDC","GLOBAL"]',
          'drug_source_priority_json': '["DAILYMED","GLOBAL"]',
        },
      ],
      'food_variant': [
        {
          'food_variant_id': 'FOOD_TOAST#US#USDA_FDC#food_toast',
          'food_concept_id': 'FOOD_TOAST',
          'jurisdiction': 'US',
          'source_family': 'USDA_FDC',
          'source_food_code': 'food_toast',
          'is_authoritative_for_region': 1,
        },
      ],
      'drug_product_variant': [
        {
          'drug_product_variant_id':
              'DRUG_LDOPA#US#DAILYMED#drug_levodopa_carbidopa',
          'drug_concept_id': 'DRUG_LDOPA',
          'jurisdiction': 'US',
          'regulator': 'DAILYMED',
          'external_product_code': 'drug_levodopa_carbidopa',
          'route': 'oral',
          'dosage_form': 'tablet',
          'release_type': 'immediate',
        },
      ],
      'drug_label_section': [
        {
          'section_id': 'iron_section',
          'drug_product_variant_id':
              'DRUG_LDOPA#US#DAILYMED#drug_levodopa_carbidopa',
          'source_doc_id': 'doc_ldopa_iron',
          'section_key': 'drug_interactions',
          'section_title': 'Drug Interactions',
          'section_text':
              'Iron salts or multivitamins containing iron may reduce bioavailability.',
        },
      ],
      'source_document': [
        {
          'source_doc_id': 'doc_ldopa_iron',
          'title': 'Imported levodopa iron label fact',
          'origin_url': 'https://example.test/ldopa-iron',
          'raw_payload': '''
{
  "label_facts": [
    {
      "fact_type": "iron_interaction_warning",
      "label": "Iron-containing products may interfere with absorption"
    }
  ]
}
''',
        },
      ],
    });

    final compiler = RuleRegistryCompiler();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final useCase = DatabaseBackedMealCheckUseCase(
      variantResolver: VariantResolver(database: db),
      clinicalDecisionSupportService: service,
      compiledRules: const <RuleRegistryEntry>[],
      importedLabelRuleProvider: ImportedLabelRuleProvider(
        database: db,
        compiler: compiler,
      ),
    );

    final result = await useCase(
      meal: Meal(
        id: 'meal_iron',
        eatenAt: DateTime.utc(2026, 1, 1, 8, 30),
        coeventSubstanceTags: const ['iron_salt'],
        coeventTime: DateTime.utc(2026, 1, 1, 8, 30),
        title: 'Toast',
        items: [
          MealItem(
            foodId: 'food_toast',
            foodName: 'Toast',
            foodCategory: FoodCategory.carbs,
            quantityFactor: 1,
            foodTags: const [],
            proteinPer100g: 7,
            carbsPer100g: 45,
            fatPer100g: 2,
            fiberPer100g: 3,
            sodiumPer100g: 250,
          ),
        ],
      ),
      activeDrugs: [
        DrugDefinition(
          id: 'drug_levodopa_carbidopa',
          genericName: 'carbidopa/levodopa',
          brandNames: ['Sinemet'],
          tags: const [DrugTag.levodopaLike],
          notes: '',
        ),
      ],
      intakes: const [],
      userProfile: UserProfile.defaults(),
    );

    expect(result.score, greaterThanOrEqualTo(30));
    expect(
      result.scoreFactors.map((factor) => factor.code),
      contains('iron_levodopa_modifier'),
    );
    expect(
      result.issues.any(
        (issue) =>
            issue.detail.contains('iron salts') ||
            issue.detail.contains('Iron salts'),
      ),
      isTrue,
    );
    expect(
      result.keyFindings.any(
        (line) => line.contains('Imported levodopa iron label fact'),
      ),
      isTrue,
    );
  });

  test('meal coevent fields trigger imported starch thickener block rule',
      () async {
    final db = QueryBackedCdssDatabase({
      'region_jurisdiction_map': [
        {
          'region_code': 'US',
          'jurisdiction_chain_json': '["US","NA","GLOBAL"]',
          'food_source_priority_json': '["USDA_FDC","GLOBAL"]',
          'drug_source_priority_json': '["DAILYMED","GLOBAL"]',
        },
      ],
      'food_variant': [
        {
          'food_variant_id': 'FOOD_SOUP#US#USDA_FDC#food_soup',
          'food_concept_id': 'FOOD_SOUP',
          'jurisdiction': 'US',
          'source_family': 'USDA_FDC',
          'source_food_code': 'food_soup',
          'is_authoritative_for_region': 1,
        },
      ],
      'drug_product_variant': [
        {
          'drug_product_variant_id': 'DRUG_PEG#US#DAILYMED#drug_peg_3350',
          'drug_concept_id': 'DRUG_PEG',
          'jurisdiction': 'US',
          'regulator': 'DAILYMED',
          'external_product_code': 'drug_peg_3350',
          'route': 'oral',
          'dosage_form': 'powder',
          'release_type': 'immediate',
        },
      ],
      'drug_label_section': [
        {
          'section_id': 'peg_section',
          'drug_product_variant_id': 'DRUG_PEG#US#DAILYMED#drug_peg_3350',
          'source_doc_id': 'doc_peg',
          'section_key': 'administration',
          'section_title': 'Administration',
          'section_text':
              'Do not mix this product with starch-based thickeners.',
        },
      ],
      'source_document': [
        {
          'source_doc_id': 'doc_peg',
          'title': 'Imported PEG label fact',
          'origin_url': 'https://example.test/peg',
          'raw_payload': '''
{
  "label_facts": [
    {
      "fact_type": "starch_thickener_incompatibility",
      "label": "Starch thickener incompatibility",
      "value_text": "starch_based"
    }
  ]
}
''',
        },
      ],
    });

    final compiler = RuleRegistryCompiler();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final useCase = DatabaseBackedMealCheckUseCase(
      variantResolver: VariantResolver(database: db),
      clinicalDecisionSupportService: service,
      compiledRules: const <RuleRegistryEntry>[],
      importedLabelRuleProvider: ImportedLabelRuleProvider(
        database: db,
        compiler: compiler,
      ),
    );

    final result = await useCase(
      meal: Meal(
        id: 'meal_peg',
        eatenAt: DateTime.utc(2026, 1, 1, 8, 30),
        coeventTime: DateTime.utc(2026, 1, 1, 8, 35),
        thickenerType: 'starch_based',
        title: 'Soup',
        items: [
          MealItem(
            foodId: 'food_soup',
            foodName: 'Soup',
            foodCategory: FoodCategory.other,
            quantityFactor: 1,
            foodTags: const [],
            proteinPer100g: 2,
            carbsPer100g: 8,
            fatPer100g: 1,
            fiberPer100g: 0,
            sodiumPer100g: 100,
          ),
        ],
      ),
      activeDrugs: [
        DrugDefinition(
          id: 'drug_peg_3350',
          genericName: 'peg 3350',
          brandNames: ['PEG'],
          tags: const [DrugTag.laxative],
          notes: '',
        ),
      ],
      intakes: const [],
      userProfile: UserProfile.defaults(),
    );

    expect(result.score, greaterThanOrEqualTo(95));
    expect(
      result.scoreFactors.map((factor) => factor.code),
      contains('rule_decision_weight'),
    );
    expect(
      result.issues.any((issue) => issue.severity == InteractionSeverity.high),
      isTrue,
    );
    expect(
      result.keyFindings
          .any((line) => line.contains('Imported PEG label fact')),
      isTrue,
    );
  });

  test('meal enteral feed fields trigger imported manual review rule',
      () async {
    final db = QueryBackedCdssDatabase({
      'region_jurisdiction_map': [
        {
          'region_code': 'US',
          'jurisdiction_chain_json': '["US","NA","GLOBAL"]',
          'food_source_priority_json': '["USDA_FDC","GLOBAL"]',
          'drug_source_priority_json': '["DAILYMED","GLOBAL"]',
        },
      ],
      'food_variant': [
        {
          'food_variant_id': 'FOOD_SHAKE#US#USDA_FDC#food_shake',
          'food_concept_id': 'FOOD_SHAKE',
          'jurisdiction': 'US',
          'source_family': 'USDA_FDC',
          'source_food_code': 'food_shake',
          'is_authoritative_for_region': 1,
        },
      ],
      'drug_product_variant': [
        {
          'drug_product_variant_id':
              'DRUG_LDOPA#US#DAILYMED#drug_levodopa_carbidopa',
          'drug_concept_id': 'DRUG_LDOPA',
          'jurisdiction': 'US',
          'regulator': 'DAILYMED',
          'external_product_code': 'drug_levodopa_carbidopa',
          'route': 'oral',
          'dosage_form': 'tablet',
          'release_type': 'immediate',
        },
      ],
      'drug_label_section': [
        {
          'section_id': 'enteral_section',
          'drug_product_variant_id':
              'DRUG_LDOPA#US#DAILYMED#drug_levodopa_carbidopa',
          'source_doc_id': 'doc_enteral',
          'section_key': 'warning',
          'section_title': 'Warnings',
          'section_text':
              'Continuous enteral feeding may require manual review.',
        },
      ],
      'source_document': [
        {
          'source_doc_id': 'doc_enteral',
          'title': 'Imported enteral feeding review fact',
          'origin_url': 'https://example.test/enteral',
          'raw_payload': '''
{
  "label_facts": [
    {
      "fact_type": "enteral_feed_review",
      "label": "Continuous enteral feeding requires review",
      "value_text": "continuous"
    }
  ]
}
''',
        },
      ],
    });

    final compiler = RuleRegistryCompiler();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final useCase = DatabaseBackedMealCheckUseCase(
      variantResolver: VariantResolver(database: db),
      clinicalDecisionSupportService: service,
      compiledRules: const <RuleRegistryEntry>[],
      importedLabelRuleProvider: ImportedLabelRuleProvider(
        database: db,
        compiler: compiler,
      ),
    );

    final result = await useCase(
      meal: Meal(
        id: 'meal_enteral',
        eatenAt: DateTime.utc(2026, 1, 1, 8, 30),
        enteralFeedMode: 'continuous',
        enteralFeedFormula: 'high protein polymeric',
        enteralFeedProteinGPerDay: 82,
        title: 'Tube feed',
        items: [
          MealItem(
            foodId: 'food_shake',
            foodName: 'Nutrition shake',
            foodCategory: FoodCategory.other,
            quantityFactor: 1,
            foodTags: const [],
            proteinPer100g: 8,
            carbsPer100g: 20,
            fatPer100g: 4,
            fiberPer100g: 1,
            sodiumPer100g: 120,
          ),
        ],
      ),
      activeDrugs: [
        DrugDefinition(
          id: 'drug_levodopa_carbidopa',
          genericName: 'carbidopa/levodopa',
          brandNames: ['Sinemet'],
          tags: const [DrugTag.levodopaLike],
          notes: '',
        ),
      ],
      intakes: const [],
      userProfile: UserProfile.defaults(),
    );

    expect(result.score, greaterThanOrEqualTo(85));
    expect(
      result.scoreFactors.map((factor) => factor.code),
      contains('continuous_enteral_feed_modifier'),
    );
    expect(
      result.keyFindings.any(
        (line) => line.contains('Imported enteral feeding review fact'),
      ),
      isTrue,
    );
  });

  test(
      'flags near-simultaneous levodopa intake with moderate protein even when a later dose exists',
      () async {
    final db = QueryBackedCdssDatabase({
      'region_jurisdiction_map': [
        {
          'region_code': 'US',
          'jurisdiction_chain_json': '["US","GLOBAL"]',
          'food_source_priority_json': '["USDA_FDC","GLOBAL"]',
          'drug_source_priority_json': '["DAILYMED","GLOBAL"]',
        },
      ],
      'food_variant': [
        {
          'food_variant_id': 'FOOD_SALMON#US#USDA_FDC#food_salmon',
          'food_concept_id': 'FOOD_SALMON',
          'jurisdiction': 'US',
          'source_family': 'USDA_FDC',
          'source_food_code': 'food_salmon',
          'is_authoritative_for_region': 1,
        },
      ],
      'drug_product_variant': [
        {
          'drug_product_variant_id':
              'DRUG_LDOPA#US#DAILYMED#drug_levodopa_carbidopa',
          'drug_concept_id': 'DRUG_LDOPA',
          'jurisdiction': 'US',
          'regulator': 'DAILYMED',
          'external_product_code': 'drug_levodopa_carbidopa',
          'route': 'oral',
          'dosage_form': 'tablet',
          'release_type': 'immediate',
        },
      ],
    });

    final compiler = RuleRegistryCompiler();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final useCase = DatabaseBackedMealCheckUseCase(
      variantResolver: VariantResolver(database: db),
      clinicalDecisionSupportService: service,
      compiledRules: compiler.compileJsonList(
        baselineCdssRules,
        rulesVersion: 'test_rules',
      ),
    );
    final mealTime = DateTime.utc(2026, 4, 28, 17, 44);

    final result = await useCase(
      meal: Meal(
        id: 'meal_same_time_protein',
        eatenAt: mealTime,
        recordedAt: mealTime,
        occurredAt: mealTime,
        timeSource: 'user_exact',
        title: 'Protein meal',
        items: [
          MealItem(
            foodId: 'food_salmon',
            foodName: 'Salmon',
            foodCategory: FoodCategory.protein,
            quantityFactor: 1,
            foodTags: const [],
            proteinPer100g: 13.5,
            carbsPer100g: 0.5,
            fatPer100g: 8.6,
            fiberPer100g: 0,
            sodiumPer100g: 70,
          ),
        ],
      ),
      activeDrugs: [
        DrugDefinition(
          id: 'drug_levodopa_carbidopa',
          genericName: 'carbidopa/levodopa',
          brandNames: ['Sinemet'],
          tags: const [DrugTag.levodopaLike],
          notes: '',
        ),
      ],
      intakes: [
        Intake(
          id: 'near_intake',
          drugId: 'drug_levodopa_carbidopa',
          takenAt: mealTime.add(const Duration(seconds: 30)),
          dosageNote: '',
        ),
        Intake(
          id: 'later_intake',
          drugId: 'drug_levodopa_carbidopa',
          takenAt: mealTime.add(const Duration(days: 1)),
          dosageNote: '',
        ),
      ],
      userProfile: UserProfile.defaults(),
    );

    expect(result.status, InteractionStatus.warning);
    expect(result.issues, isNotEmpty);
    expect(
      result.scoreFactors.map((factor) => factor.code),
      containsAll([
        'rule_decision_weight',
        'levodopa_interference_weight',
        'protein_timing_penalty',
      ]),
    );
  });

  test(
      'historical meals outside the active digestion window do not create current high risk',
      () async {
    final db = QueryBackedCdssDatabase({
      'region_jurisdiction_map': [
        {
          'region_code': 'US',
          'jurisdiction_chain_json': '["US","NA","GLOBAL"]',
          'food_source_priority_json': '["USDA_FDC","GLOBAL"]',
          'drug_source_priority_json': '["DAILYMED","GLOBAL"]',
        },
      ],
      'food_variant': [
        {
          'food_variant_id': 'FOOD_SALMON#US#USDA_FDC#food_salmon',
          'food_concept_id': 'FOOD_SALMON',
          'jurisdiction': 'US',
          'source_family': 'USDA_FDC',
          'source_food_code': 'food_salmon',
          'is_authoritative_for_region': 1,
        },
      ],
      'drug_product_variant': [
        {
          'drug_product_variant_id':
              'DRUG_LDOPA#US#DAILYMED#drug_levodopa_carbidopa',
          'drug_concept_id': 'DRUG_LDOPA',
          'jurisdiction': 'US',
          'regulator': 'DAILYMED',
          'external_product_code': 'drug_levodopa_carbidopa',
          'route': 'oral',
          'dosage_form': 'tablet',
          'release_type': 'immediate',
        },
      ],
    });

    final compiler = RuleRegistryCompiler();
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final useCase = DatabaseBackedMealCheckUseCase(
      variantResolver: VariantResolver(database: db),
      clinicalDecisionSupportService: service,
      compiledRules: compiler.compileJsonList(
        baselineCdssRules,
        rulesVersion: 'test_rules',
      ),
    );
    final now = DateTime.utc(2026, 4, 27, 19, 7);

    final result = await useCase(
      meal: Meal(
        id: 'meal_old_salmon',
        eatenAt: now.subtract(const Duration(hours: 27)),
        recordedAt: now,
        occurredAt: now.subtract(const Duration(hours: 27)),
        timeSource: 'user_exact',
        title: 'Old salmon meal',
        items: [
          MealItem(
            foodId: 'food_salmon',
            foodName: 'Salmon',
            foodCategory: FoodCategory.protein,
            quantityFactor: 1,
            foodTags: const [],
            proteinPer100g: 27.4,
            carbsPer100g: 39.0,
            fatPer100g: 14.6,
            fiberPer100g: 0,
            sodiumPer100g: 70,
          ),
        ],
      ),
      activeDrugs: [
        DrugDefinition(
          id: 'drug_levodopa_carbidopa',
          genericName: 'carbidopa/levodopa',
          brandNames: ['Sinemet'],
          tags: const [DrugTag.levodopaLike],
          notes: '',
        ),
      ],
      intakes: const [],
      userProfile: UserProfile.defaults(),
      now: now,
    );

    expect(result.status, InteractionStatus.ok);
    expect(result.score, 0);
    expect(result.issues, isEmpty);
    expect(result.summary, contains('outside'));
    expect(result.analysisText, contains('historical meal'));
  });

  test('meal check trace componentizes history with catalog enrichment',
      () async {
    final db = QueryBackedCdssDatabase(const {});
    final service = ClinicalDecisionSupportService(
      database: db,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final foodRepository = FoodRepository.createDefault()
      ..replaceAll([
        FoodItem(
          id: 'food_enriched',
          name: 'Enriched tofu',
          category: FoodCategory.protein,
          textureClass: 'solid',
          proteinG: 10,
          carbsG: 3,
          fatG: 4,
          fiberG: 2,
          sodiumMg: 15,
          energyKcal: 120,
          aminoAcidProfile: const AminoAcidProfile(
            leucine: 2,
            valine: 1,
            basis: 'per_100g',
          ),
        ),
      ]);
    final engine = RecordingMechanisticConflictEngine();
    final useCase = DatabaseBackedMealCheckUseCase(
      variantResolver: VariantResolver(database: db),
      clinicalDecisionSupportService: service,
      compiledRules: const [],
      foodRepository: foodRepository,
      mechanisticEngine: engine,
    );
    final mealTime = DateTime.utc(2026, 1, 1, 8, 30);

    final result = await useCase(
      meal: Meal(
        id: 'meal_componentized',
        eatenAt: mealTime,
        title: 'Mixed history meal',
        items: [
          MealItem(
            foodId: 'food_enriched',
            foodName: 'Enriched tofu',
            foodCategory: FoodCategory.protein,
            quantityFactor: 1.5,
            foodTags: const [],
            proteinPer100g: 10,
            carbsPer100g: 3,
            fatPer100g: 4,
            fiberPer100g: 2,
            sodiumPer100g: 15,
          ),
          MealItem(
            foodId: 'food_uncatalogued',
            foodName: 'Uncatalogued side',
            foodCategory: FoodCategory.other,
            quantityFactor: 0.5,
            foodTags: const [],
            proteinPer100g: 2,
            carbsPer100g: 8,
            fatPer100g: 1,
            fiberPer100g: 1,
            sodiumPer100g: 10,
          ),
        ],
      ),
      activeDrugs: [
        DrugDefinition(
          id: 'drug_levodopa_carbidopa',
          genericName: 'carbidopa/levodopa',
          brandNames: const ['Sinemet'],
          tags: const [DrugTag.levodopaLike],
          notes: '',
        ),
      ],
      intakes: [
        Intake(
          id: 'intake_componentized',
          drugId: 'drug_levodopa_carbidopa',
          takenAt: DateTime.utc(2026, 1, 1, 8),
          dosageNote: '100 mg',
        ),
      ],
      userProfile: UserProfile.defaults(),
    );

    final components = engine.composition!.foodComponents;
    expect(result.mechanisticTraceJson, isNotNull);
    expect(components, hasLength(2));
    expect(components.first.portionGrams, 150);
    expect(components.first.calories, 180);
    expect(components.first.physicalForm, MealPhysicalForm.solid);
    expect(components.first.aminoAcidProfile!.leucine, 3);
    expect(components.last.portionGrams, 50);
    expect(components.last.calories, isNull);
    expect(components.last.physicalForm, MealPhysicalForm.unknown);
    expect(components.last.aminoAcidProfile, isNull);
    expect(
        engine.context!.mealEvents.single.physicalForm, MealPhysicalForm.solid);
  });
}
