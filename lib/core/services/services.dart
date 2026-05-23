import 'dart:convert';

import '../../data/datasources/local/app_local_datasource.dart';
import '../../data/models/interaction_rule_record.dart';
import '../../data/repositories_impl/app_repository_impl.dart';
import '../../domain/entities/cdss_records.dart';
import '../../domain/entities/rule_registry_models.dart';
import '../../domain/repositories/app_repository.dart';
import '../../domain/usecases/clinical_decision_support_service.dart';
import '../../domain/usecases/database_backed_meal_check_usecase.dart';
import '../../domain/usecases/cdss_catalog_projection_service.dart';
import '../../domain/usecases/fact_conflict_engine.dart';
import '../../domain/usecases/get_food_recommendations_usecase.dart';
import '../../domain/usecases/get_protein_trend_usecase.dart';
import '../../domain/usecases/knowledge_base_release_service.dart';
import '../../domain/usecases/get_timeline_usecase.dart';
import '../../domain/usecases/imported_label_rule_provider.dart';
import '../../domain/usecases/local_ai_recommendation_adapter.dart';
import '../../domain/usecases/next_meal_recommendation_orchestrator.dart';
import '../../domain/usecases/recommendation_replay_runner.dart';
import '../../domain/usecases/rule_registry_compiler.dart';
import '../../domain/usecases/runtime_rule_engine.dart';
import '../../domain/usecases/variant_resolver.dart';
import '../analysis/catalog_engine.dart';
import '../analysis/food_repository.dart';
import '../analysis/interaction_engine.dart';
import '../analysis/medication_repository.dart';
import '../analysis/nutrition_classifier.dart';
import '../db/app_database.dart';
import '../db/app_database_firestore.dart';
import '../constants/baseline_cdss_rules.dart';
import '../constants/p0_food_source_seed.dart';
import '../constants/regional_master_data.dart';
import '../db/cdss_database.dart';
import '../db/cdss_database_firestore.dart';
import '../db/cdss_database_factory.dart';
import '../../data/datasources/remote/p0_ingestion_orchestrator.dart';
import '../../data/datasources/remote/source_fetch_client.dart';
import '../models/drug_definition.dart';
import '../models/food_item.dart';
import 'auth_service.dart';
import 'firebase_backend.dart';
import 'user_clinical_audit_service.dart';
import 'user_data_service.dart';

class Services {
  final AuthService authService;
  final AppDatabase appDatabase;
  final CdssDatabase cdssDatabase;
  final AppRepository appRepository;
  final UserDataService userDataService;
  final UserClinicalAuditService userClinicalAuditService;

  final FoodRepository foodRepository;
  final MedicationRepository medicationRepository;

  final NutritionClassifier nutritionClassifier;
  final InteractionEngine interactionEngine;
  final CatalogEngine catalogEngine;

  final GetTimelineUseCase getTimelineUseCase;
  final GetFoodRecommendationsUseCase getFoodRecommendationsUseCase;
  final GetProteinTrendUseCase getProteinTrendUseCase;
  final RuleRegistryCompiler ruleRegistryCompiler;
  final ClinicalDecisionSupportService clinicalDecisionSupportService;
  final DatabaseBackedMealCheckUseCase databaseBackedMealCheckUseCase;
  final CdssCatalogProjectionService cdssCatalogProjectionService;
  final NextMealRecommendationOrchestrator nextMealRecommendationOrchestrator;
  final RecommendationReplayRunner recommendationReplayRunner;
  final P0IngestionOrchestrator p0IngestionOrchestrator;
  final KnowledgeBaseReleaseService knowledgeBaseReleaseService;
  final List<RuleRegistryEntry> compiledCdssRules;
  final Future<void> ready;

  Services._({
    required this.authService,
    required this.appDatabase,
    required this.cdssDatabase,
    required this.appRepository,
    required this.userDataService,
    required this.userClinicalAuditService,
    required this.foodRepository,
    required this.medicationRepository,
    required this.nutritionClassifier,
    required this.interactionEngine,
    required this.catalogEngine,
    required this.getTimelineUseCase,
    required this.getFoodRecommendationsUseCase,
    required this.getProteinTrendUseCase,
    required this.ruleRegistryCompiler,
    required this.clinicalDecisionSupportService,
    required this.databaseBackedMealCheckUseCase,
    required this.cdssCatalogProjectionService,
    required this.nextMealRecommendationOrchestrator,
    required this.recommendationReplayRunner,
    required this.p0IngestionOrchestrator,
    required this.knowledgeBaseReleaseService,
    required this.compiledCdssRules,
    required this.ready,
  });

  static List<InteractionRuleRecord> _defaultRules() {
    return const [
      InteractionRuleRecord(
        id: 'rule_levodopa_protein',
        drugId: 'drug_levodopa_carbidopa',
        ruleType: 'protein_timing',
        target: 'protein',
        severity: 2,
        weight: 0.8,
        description: '高蛋白与左旋多巴同时段时可能影响吸收。',
      ),
      InteractionRuleRecord(
        id: 'rule_maoi_tyramine',
        drugId: 'drug_selegiline',
        ruleType: 'tyramine',
        target: 'high_tyramine',
        severity: 3,
        weight: 1.0,
        description: '高酪胺食物与 MAOI 同期需谨慎。',
      ),
      InteractionRuleRecord(
        id: 'rule_mineral_dairy',
        drugId: 'drug_iron',
        ruleType: 'mineral_timing',
        target: 'dairy',
        severity: 1,
        weight: 0.5,
        description: '矿物质补充剂与乳制品时间窗口需注意。',
      ),
    ];
  }

  static List<FoodConceptRecord> _buildFoodConcepts(List<FoodItem> foods) {
    return foods
        .map(
          (food) => FoodConceptRecord(
            foodConceptId: 'FOOD_${food.id.toUpperCase()}',
            canonicalNameEn:
                food.aliases.isEmpty ? food.name : food.aliases.first,
            canonicalNameZh: food.name,
            foodGroup: food.category.name,
          ),
        )
        .toList(growable: false);
  }

  static List<FoodVariantRecord> _buildFoodVariants(List<FoodItem> foods) {
    return foods
        .map(
          (food) => FoodVariantRecord(
            foodVariantId:
                'FOOD_${food.id.toUpperCase()}#${food.jurisdiction.toUpperCase()}#${food.sourceSystem.toUpperCase()}#${food.sourceFoodCode ?? food.id}',
            foodConceptId: 'FOOD_${food.id.toUpperCase()}',
            jurisdiction: food.jurisdiction,
            sourceFamily: food.sourceSystem,
            sourceFoodCode: food.sourceFoodCode ?? food.id,
            displayNameLocal: food.name,
            isAuthoritativeForRegion: food.sourceSystem != 'LOCAL_SEED',
            isAuthoritativeFallback: food.sourceSystem == 'LOCAL_SEED',
            status: 'seeded_catalog_variant',
            fallbackChainJson: jsonEncode([food.jurisdiction, 'GLOBAL']),
          ),
        )
        .toList(growable: false);
  }

  static List<DrugConceptRecord> _buildDrugConcepts(
      List<DrugDefinition> drugs) {
    return drugs
        .map(
          (drug) => DrugConceptRecord(
            drugConceptId: 'DRUG_${drug.id.toUpperCase()}',
            genericName: drug.genericName,
            atcLikeCode: drug.tags.map((tag) => tag.name).join('_'),
          ),
        )
        .toList(growable: false);
  }

  static List<DrugProductVariantRecord> _buildDrugVariants(
      List<DrugDefinition> drugs) {
    return drugs
        .map(
          (drug) => DrugProductVariantRecord(
            drugProductVariantId:
                'DRUG_${drug.id.toUpperCase()}#${drug.jurisdiction.toUpperCase()}#${drug.sourceSystem.toUpperCase()}#${drug.sourceProductCode ?? drug.id}',
            drugConceptId: 'DRUG_${drug.id.toUpperCase()}',
            jurisdiction: drug.jurisdiction,
            regulator: drug.sourceSystem,
            externalProductCode: drug.id,
            route: drug.route,
            dosageForm: drug.dosageForm,
            releaseType: drug.releaseType,
            labelVersion: 'seed_catalog_v2',
            sourceStatus: drug.sourceSystem == 'LOCAL_SEED'
                ? 'seeded_reference'
                : 'catalog_summary',
          ),
        )
        .toList(growable: false);
  }

  factory Services.createDefault() {
    final AuthService auth =
        FirebaseBackend.enabled ? FirebaseAuthService() : LocalAuthService();
    final appDatabase = FirebaseBackend.enabled
        ? FirestoreAppDatabase(authService: auth)
        : createAppDatabase();
    final cdssDatabase = FirebaseBackend.enabled
        ? FirestoreCdssDatabase(authService: auth)
        : createCdssDatabaseImpl();

    final foodRepo = FoodRepository.createDefault();
    final medRepo = MedicationRepository.createDefault();

    final localDataSource = AppLocalDataSource(database: appDatabase);
    final AppRepository appRepository =
        AppRepositoryImpl(local: localDataSource);
    final userData = UserDataService(repository: appRepository);
    final userClinicalAudit = UserClinicalAuditService(authService: auth);

    final classifier = NutritionClassifier();
    final interaction = InteractionEngine();
    final ruleCompiler = RuleRegistryCompiler();
    final compiledCdssRules = ruleCompiler.compileJsonList(
      baselineCdssRules,
      rulesVersion: 'baseline_cdss_rules_v1',
    );
    final catalog = CatalogEngine(
      foodRepo: foodRepo,
      medRepo: medRepo,
      interactionEngine: interaction,
      nutritionClassifier: classifier,
    );

    final cdssService = ClinicalDecisionSupportService(
      database: cdssDatabase,
      factConflictEngine: FactConflictEngine(),
      runtimeRuleEngine: RuntimeRuleEngine(),
    );
    final variantResolver = VariantResolver(database: cdssDatabase);
    final importedLabelRuleProvider = ImportedLabelRuleProvider(
      database: cdssDatabase,
      compiler: ruleCompiler,
    );
    final mealCheckUseCase = DatabaseBackedMealCheckUseCase(
      variantResolver: variantResolver,
      clinicalDecisionSupportService: cdssService,
      compiledRules: compiledCdssRules,
      importedLabelRuleProvider: importedLabelRuleProvider,
    );
    final cdssCatalogProjectionService =
        CdssCatalogProjectionService(database: cdssDatabase);
    final nextMealRecommendationOrchestrator =
        NextMealRecommendationOrchestrator(
      conservativeRecommender: GetFoodRecommendationsUseCase(),
      projectionService: cdssCatalogProjectionService,
      localAiAdapter: LocalAiRecommendationAdapter(),
    );
    final recommendationReplayRunner = RecommendationReplayRunner(
      hybridOrchestrator: nextMealRecommendationOrchestrator,
      deterministicOrchestrator: NextMealRecommendationOrchestrator(
        conservativeRecommender: GetFoodRecommendationsUseCase(),
        projectionService: cdssCatalogProjectionService,
        localAiAdapter: null,
      ),
      foodRepository: foodRepo,
      medicationRepository: medRepo,
    );
    final p0IngestionOrchestrator = P0IngestionOrchestrator(
      cdssService: cdssService,
      appRepository: appRepository,
      fetchClient: HttpSourceFetchClient(),
    );
    final knowledgeBaseReleaseService = KnowledgeBaseReleaseService(
      database: cdssDatabase,
      cdssService: cdssService,
    );
    final p0KnowledgeBase = buildP0FoodKnowledgeBaseSeed();

    final ready = FirebaseBackend.ensureInitialized().then((_) async {
      if (FirebaseBackend.enabled) return;
      await Future.wait([
        appRepository.initialize(
          seedFoods: foodRepo.allFoods,
          seedMedications: medRepo.allDrugs,
          seedRules: _defaultRules(),
        ),
        cdssService.initializeRegionalMasterData(
          regionMaps: regionalJurisdictionMapSeed,
          localeBundles: localeResourceBundleSeed,
          dietProfiles: countryDietProfileSeed,
          mealTemplates: mealTemplateSeed,
          foodConcepts: [
            ..._buildFoodConcepts(foodRepo.allFoods),
            ...p0KnowledgeBase.foodConcepts,
          ],
          foodVariants: [
            ..._buildFoodVariants(foodRepo.allFoods),
            ...p0KnowledgeBase.foodVariants,
          ],
          drugConcepts: _buildDrugConcepts(medRepo.allDrugs),
          drugProductVariants: _buildDrugVariants(medRepo.allDrugs),
        ),
        cdssService.initializeKnowledgeBase(
          sourceDocuments: p0KnowledgeBase.sourceDocuments,
          variantScopes: p0KnowledgeBase.variantScopes,
          observations: p0KnowledgeBase.observations,
          resolvedFacts: p0KnowledgeBase.resolvedFacts,
        ),
        cdssService.initializeRuleRegistry(
          rules: compiledCdssRules,
          rulesVersion: 'baseline_cdss_rules_v1',
        ),
      ]);
      // 初始化完成后，优先使用本地库中的目录数据覆盖内存种子，
      // 这样 UI 搜索和数据库内容就不会长期分叉。
      final persistedFoods = await appRepository.loadFoods();
      final persistedMeds = await appRepository.loadMedications();
      foodRepo.replaceAll(persistedFoods);
      medRepo.replaceAll(persistedMeds);
    });

    return Services._(
      authService: auth,
      appDatabase: appDatabase,
      cdssDatabase: cdssDatabase,
      appRepository: appRepository,
      userDataService: userData,
      userClinicalAuditService: userClinicalAudit,
      foodRepository: foodRepo,
      medicationRepository: medRepo,
      nutritionClassifier: classifier,
      interactionEngine: interaction,
      catalogEngine: catalog,
      getTimelineUseCase: GetTimelineUseCase(),
      getFoodRecommendationsUseCase: GetFoodRecommendationsUseCase(),
      getProteinTrendUseCase: GetProteinTrendUseCase(),
      ruleRegistryCompiler: ruleCompiler,
      clinicalDecisionSupportService: cdssService,
      databaseBackedMealCheckUseCase: mealCheckUseCase,
      cdssCatalogProjectionService: cdssCatalogProjectionService,
      nextMealRecommendationOrchestrator: nextMealRecommendationOrchestrator,
      recommendationReplayRunner: recommendationReplayRunner,
      p0IngestionOrchestrator: p0IngestionOrchestrator,
      knowledgeBaseReleaseService: knowledgeBaseReleaseService,
      compiledCdssRules: compiledCdssRules,
      ready: ready,
    );
  }
}
