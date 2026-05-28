import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

import '../analysis/catalog_engine.dart';
import '../i18n/app_i18n.dart';
import '../analysis/food_repository.dart';
import '../analysis/medication_repository.dart';
import '../models/drug_definition.dart';
import '../models/intake.dart';
import '../models/interaction_result.dart';
import '../models/meal.dart';
import '../models/user_profile.dart';
import '../services/services.dart';
import '../services/auth_service.dart';
import '../services/firebase_backend.dart';
import '../../domain/entities/food_recommendation.dart';
import '../models/food_item.dart';
import '../../domain/entities/next_meal_recommendation_models.dart';
import '../../domain/entities/time_axis_events.dart'
    show UserDefinedMealWindow, TimelineWindow, dateTimeToMinute;
import '../../domain/entities/protein_trend_point.dart';
import '../../domain/entities/cdss_records.dart';
import '../../domain/entities/recommendation_replay_models.dart';
import '../../domain/entities/timeline_event.dart';
import '../../domain/entities/runtime_context.dart';
import '../../domain/usecases/knowledge_base_release_service.dart';
import '../../domain/usecases/local_ai_recommendation_adapter.dart';
import '../../data/datasources/remote/p0_import_models.dart';
import '../../data/datasources/remote/p0_ingestion_orchestrator.dart';
import '../utils/local_p0_import_locator.dart';

void _debugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class ImportTaskResult {
  final bool succeeded;
  final String summary;
  final Map<String, String> resolvedPaths;
  final List<ImportStepResult> steps;
  final DateTime completedAt;

  const ImportTaskResult({
    required this.succeeded,
    required this.summary,
    required this.resolvedPaths,
    this.steps = const <ImportStepResult>[],
    required this.completedAt,
  });

  int get sourceDocumentCount =>
      steps.fold(0, (sum, step) => sum + (step.sourceDocumentCount ?? 0));
  int get foodCount =>
      steps.fold(0, (sum, step) => sum + (step.foodCount ?? 0));
  int get drugCount =>
      steps.fold(0, (sum, step) => sum + (step.drugCount ?? 0));
  int get observationCount =>
      steps.fold(0, (sum, step) => sum + (step.observationCount ?? 0));
}

class ImportStepResult {
  final String sourceKey;
  final String sourceLabel;
  final bool succeeded;
  final String sourceFamily;
  final String? runId;
  final String? promotedSnapshotId;
  final int? sourceDocumentCount;
  final int? foodCount;
  final int? drugCount;
  final int? observationCount;
  final String? errorMessage;
  final int attempts;
  final String? checkpoint;
  final String? resumeToken;
  final List<ImportRunDrilldown> runs;
  final List<ImportSourceDocumentDrilldown> sourceDocuments;
  final DateTime completedAt;

  const ImportStepResult({
    required this.sourceKey,
    required this.sourceLabel,
    required this.succeeded,
    required this.sourceFamily,
    required this.completedAt,
    this.runId,
    this.promotedSnapshotId,
    this.sourceDocumentCount,
    this.foodCount,
    this.drugCount,
    this.observationCount,
    this.errorMessage,
    this.attempts = 0,
    this.checkpoint,
    this.resumeToken,
    this.runs = const <ImportRunDrilldown>[],
    this.sourceDocuments = const <ImportSourceDocumentDrilldown>[],
  });
}

class ImportRunDrilldown {
  final String runId;
  final String stage;
  final String status;
  final String snapshotId;
  final String? parentSnapshotId;
  final String notesJson;
  final int? sourceDocumentCount;
  final int? observationCount;
  final int? resolvedFactCount;
  final String? errorMessage;
  final int? retryAttempt;
  final int? maxAttempts;
  final String? checkpoint;
  final String? resumeToken;
  final DateTime createdAt;
  final DateTime? completedAt;

  const ImportRunDrilldown({
    required this.runId,
    required this.stage,
    required this.status,
    required this.snapshotId,
    required this.parentSnapshotId,
    required this.notesJson,
    required this.sourceDocumentCount,
    required this.observationCount,
    required this.resolvedFactCount,
    required this.errorMessage,
    required this.retryAttempt,
    required this.maxAttempts,
    required this.checkpoint,
    required this.resumeToken,
    required this.createdAt,
    required this.completedAt,
  });
}

class ImportSourceDocumentDrilldown {
  final String sourceDocId;
  final String sourceFamily;
  final String dataTier;
  final String ingestionStrategy;
  final String docType;
  final String title;
  final String originUrl;
  final String sourceStatus;

  const ImportSourceDocumentDrilldown({
    required this.sourceDocId,
    required this.sourceFamily,
    required this.dataTier,
    required this.ingestionStrategy,
    required this.docType,
    required this.title,
    required this.originUrl,
    required this.sourceStatus,
  });
}

class AppState extends ChangeNotifier {
  final Services services;

  AppState({required this.services}) {
    _authSubscription = services.authService.authStateChanges.listen(
      _handleAuthUserChanged,
    );
  }

  StreamSubscription<AuthUser?>? _authSubscription;

  bool _isBootstrapping = true;
  bool _isOnboarded = false;
  bool _isAuthBusy = false;
  String? _authError;
  String? _authUserId;
  String? _authUserEmail;
  UserProfile _userProfile = UserProfile.defaults();

  List<String> _activeDrugIds = [];
  List<Meal> _meals = [];
  List<Intake> _intakes = [];
  List<FoodRecommendation> _recommendations = [];
  Map<String, InteractionResult> _mealCheckCache = {};
  bool _isImportingP0 = false;
  ImportTaskResult? _latestImportTask;
  Map<String, String> _lastImportRequest = {};
  String _recommendationDecisionPath = 'conservative_cdss';
  List<String> _recommendationExplanations = const [];
  List<String> _recommendationGateReasons = const [];
  bool _recommendationAiUsed = false;
  String? _recommendationTemplateCountryCode;
  String? _recommendationTemplateMealSlot;
  String? _recommendationTemplateTextureLevel;
  LocalAiAvailability? _localAiAvailability;
  bool _isRunningReplayBenchmark = false;
  RecommendationReplayRunReport? _latestReplayBenchmarkReport;
  String? _latestReplayBenchmarkError;
  List<SnapshotOperationalSummary> _snapshotSummaries =
      const <SnapshotOperationalSummary>[];
  List<ImportOperationalSummary> _importMonitorSummaries =
      const <ImportOperationalSummary>[];
  List<SnapshotDistributionRecord> _snapshotDistributions =
      const <SnapshotDistributionRecord>[];
  List<HumanReviewTicketRecord> _reviewTickets =
      const <HumanReviewTicketRecord>[];
  bool _isRunningSnapshotOperation = false;
  String? _lastSnapshotOperationMessage;

  bool get isBootstrapping => _isBootstrapping;
  bool get isOnboarded => _isOnboarded;
  bool get requiresFirebaseSignIn =>
      FirebaseBackend.enabled && _authUserId == null;
  bool get isSignedIn => _authUserId != null;
  bool get isAuthBusy => _isAuthBusy;
  String? get authError => _authError;
  String? get currentUserId => _authUserId;
  String? get currentUserEmail => _authUserEmail;
  UserProfile get userProfile => _userProfile;

  List<Meal> get meals => List.unmodifiable(_meals);
  List<Intake> get intakes => List.unmodifiable(_intakes);
  bool get isImportingP0 => _isImportingP0;
  ImportTaskResult? get latestImportTask => _latestImportTask;
  String get recommendationDecisionPath => _recommendationDecisionPath;
  List<String> get recommendationExplanations =>
      List.unmodifiable(_recommendationExplanations);
  List<String> get recommendationGateReasons =>
      List.unmodifiable(_recommendationGateReasons);
  bool get recommendationAiUsed => _recommendationAiUsed;
  String? get recommendationTemplateCountryCode =>
      _recommendationTemplateCountryCode;
  String? get recommendationTemplateMealSlot => _recommendationTemplateMealSlot;
  String? get recommendationTemplateTextureLevel =>
      _recommendationTemplateTextureLevel;
  LocalAiAvailability? get localAiAvailability => _localAiAvailability;
  bool get isRunningReplayBenchmark => _isRunningReplayBenchmark;
  RecommendationReplayRunReport? get latestReplayBenchmarkReport =>
      _latestReplayBenchmarkReport;
  String? get latestReplayBenchmarkError => _latestReplayBenchmarkError;
  List<SnapshotOperationalSummary> get snapshotSummaries =>
      List.unmodifiable(_snapshotSummaries);
  List<ImportOperationalSummary> get importMonitorSummaries =>
      List.unmodifiable(_importMonitorSummaries);
  List<SnapshotDistributionRecord> get snapshotDistributions =>
      List.unmodifiable(_snapshotDistributions);
  List<HumanReviewTicketRecord> get reviewTickets =>
      List.unmodifiable(_reviewTickets);
  bool get isRunningSnapshotOperation => _isRunningSnapshotOperation;
  String? get lastSnapshotOperationMessage => _lastSnapshotOperationMessage;

  FoodRepository get foodRepo => services.foodRepository;
  MedicationRepository get medRepo => services.medicationRepository;
  CatalogEngine get catalogEngine => services.catalogEngine;

  List<DrugDefinition> get activeDrugs {
    final defs = <DrugDefinition>[];
    for (final id in _activeDrugIds) {
      final d = medRepo.getById(id);
      if (d != null) defs.add(d);
    }
    return defs;
  }

  List<DrugDefinition> _drugsForMealCheck() {
    final ids = <String>{
      ..._activeDrugIds,
      ..._intakes.map((intake) => intake.drugId),
    };
    final defs = <DrugDefinition>[];
    for (final id in ids) {
      final drug = medRepo.getById(id);
      if (drug != null) {
        defs.add(drug);
      }
    }
    return defs;
  }

  Future<void> bootstrap() async {
    _debugLog('[AppState] bootstrap:start');
    _isBootstrapping = true;
    _authError = null;
    notifyListeners();

    await services.ready;

    if (FirebaseBackend.enabled && services.authService.currentUserId == null) {
      _clearVisiblePatientData();
      _isBootstrapping = false;
      _debugLog('[AppState] bootstrap:waiting_for_firebase_sign_in');
      notifyListeners();
      return;
    }

    final uid = await services.authService.ensureUser();
    _authUserId = uid;
    _authUserEmail = services.authService.currentUserEmail;

    _isOnboarded = await services.userDataService.loadOnboarded();
    _userProfile = await services.userDataService.loadUserProfile();
    // Pull every locale_resource_bundle row into AppI18n. Importer-side
    // `LocaleResourceSeedImporter` writes ko/hi/es/vi/th/id/ru/pl/ar
    // translations into this table; loading them here means `AppI18n.tr()`
    // can serve those locales without redeploying the app binary. Existing
    // zh / en / ja / fr translations remain unaffected because the
    // hardcoded `_strings` map is only consulted when a runtime override
    // is missing for a given key.
    await _refreshLocaleResourceOverrides();
    final catalogFoods = await services.appRepository.loadFoods();
    final catalogDrugs = await services.appRepository.loadMedications();
    services.foodRepository.replaceAll(catalogFoods);
    services.medicationRepository.replaceAll(catalogDrugs);
    // Best-effort: extend the food repository with CDSS-projected foods so
    // the mechanistic next-meal scorer can rank real catalog-backed
    // candidates (not only synthetic replay scenarios). Failures here are
    // swallowed because the seed/persisted catalog already provides a
    // working baseline.
    await _augmentFoodRepoFromProjection();
    _activeDrugIds = await services.userDataService.loadActiveDrugIdsCompat();
    _meals = await services.userDataService.loadMeals();
    _intakes = await services.userDataService.loadIntakes();
    await _refreshRecommendations();
    await _refreshMealChecks();
    await refreshLocalAiAvailability();
    await refreshCdssOpsOverview();

    _isBootstrapping = false;
    _debugLog(
      '[AppState] bootstrap:done meals=${_meals.length} intakes=${_intakes.length} drugs=${_activeDrugIds.length}',
    );
    notifyListeners();
  }

  Future<void> registerWithEmail({
    required String email,
    required String password,
  }) async {
    await _runAuthTask(
      () => services.authService.registerWithEmail(
        email: email,
        password: password,
      ),
    );
  }

  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _runAuthTask(
      () => services.authService.signInWithEmail(
        email: email,
        password: password,
      ),
    );
  }

  Future<void> signOut() async {
    _isAuthBusy = true;
    _authError = null;
    notifyListeners();
    try {
      await services.authService.signOut();
      _clearVisiblePatientData();
    } catch (error) {
      _authError = '$error';
    } finally {
      _isAuthBusy = false;
      notifyListeners();
    }
  }

  Future<void> _runAuthTask(Future<String> Function() task) async {
    _isAuthBusy = true;
    _authError = null;
    notifyListeners();
    try {
      await task();
      await bootstrap();
    } catch (error) {
      _authError = '$error';
      notifyListeners();
    } finally {
      _isAuthBusy = false;
      notifyListeners();
    }
  }

  Future<void> _handleAuthUserChanged(AuthUser? user) async {
    final previousUid = _authUserId;
    _authUserId = user?.uid;
    _authUserEmail = user?.email;
    if (user == null) {
      _clearVisiblePatientData();
      notifyListeners();
      return;
    }
    if (FirebaseBackend.enabled &&
        previousUid != null &&
        previousUid != user.uid) {
      await bootstrap();
    } else {
      notifyListeners();
    }
  }

  void _clearVisiblePatientData() {
    _isOnboarded = false;
    _userProfile = UserProfile.defaults();
    _activeDrugIds = [];
    _meals = [];
    _intakes = [];
    _recommendations = [];
    _mealCheckCache = {};
    _recommendationDecisionPath = 'conservative_cdss';
    _recommendationExplanations = const [];
    _recommendationGateReasons = const [];
    _recommendationAiUsed = false;
    _recommendationTemplateCountryCode = null;
    _recommendationTemplateMealSlot = null;
    _recommendationTemplateTextureLevel = null;
    _localAiAvailability = null;
  }

  Future<void> completeOnboarding({
    UserProfile? profile,
    List<String>? activeDrugIds,
    Intake? initialIntake,
  }) async {
    if (profile != null) {
      final scopedProfile = FirebaseBackend.enabled && _authUserId != null
          ? profile.copyWith(patientId: _authUserId)
          : profile;
      _userProfile = scopedProfile;
      await services.userDataService.saveUserProfile(scopedProfile);
    }
    if (activeDrugIds != null) {
      _activeDrugIds = List<String>.from(activeDrugIds);
      await services.userDataService.saveActiveDrugIds(_activeDrugIds);
    }
    if (initialIntake != null) {
      _intakes = [
        initialIntake,
        ..._intakes.where((intake) => intake.id != initialIntake.id),
      ];
      await services.userDataService.saveIntakes(_intakes);
    }
    _isOnboarded = true;
    await services.userDataService.saveOnboarded(true);
    await _refreshRecommendations();
    await _refreshMealChecks();
    await refreshLocalAiAvailability();
    notifyListeners();
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final scopedProfile = FirebaseBackend.enabled && _authUserId != null
        ? profile.copyWith(patientId: _authUserId)
        : profile;
    _userProfile = scopedProfile;
    await services.userDataService.saveUserProfile(scopedProfile);
    await _refreshRecommendations();
    await _refreshMealChecks();
    await refreshLocalAiAvailability();
    _debugLog(
      '[AppState] saveUserProfile:done region=${scopedProfile.registrationRegion} locale=${scopedProfile.displayLocale}',
    );
    notifyListeners();
  }

  Future<void> setLocalAiConsent(bool enabled) async {
    await saveUserProfile(
      _userProfile.copyWith(localAiConsentEnabled: enabled),
    );
  }

  Future<void> saveLocalAiSettings({
    required String providerPreference,
    required String model,
    required String medicalModel,
    required String ollamaEndpoint,
    required String openAiCompatEndpoint,
    required int timeoutMs,
  }) async {
    await saveUserProfile(
      _userProfile.copyWith(
        localAiProviderPreference: providerPreference,
        localAiModel: model,
        localAiMedicalModel: medicalModel,
        localAiOllamaEndpoint: ollamaEndpoint,
        localAiOpenAiCompatEndpoint: openAiCompatEndpoint,
        localAiTimeoutMs: timeoutMs,
      ),
    );
  }

  Future<void> refreshLocalAiAvailability() async {
    final adapter = services.nextMealRecommendationOrchestrator.localAiAdapter;
    if (adapter == null) {
      _localAiAvailability = null;
      notifyListeners();
      return;
    }
    _localAiAvailability = await adapter.probe(userProfile: _userProfile);
    notifyListeners();
  }

  Future<void> setActiveDrugIds(List<String> ids) async {
    _activeDrugIds = List<String>.from(ids);
    await services.userDataService.saveActiveDrugIds(ids);
    await _refreshRecommendations();
    await _refreshMealChecks();
    notifyListeners();
  }

  Future<void> addMeal(Meal meal) async {
    _debugLog('[AppState] addMeal:start items=${meal.items.length}');
    _meals = [meal, ..._meals];
    await services.userDataService.saveMeals(_meals);
    await _refreshRecommendations();
    await _refreshMealChecks();
    _debugLog('[AppState] addMeal:saved totalMeals=${_meals.length}');
    notifyListeners();
  }

  Future<void> updateMeal(Meal meal) async {
    _debugLog('[AppState] updateMeal:start items=${meal.items.length}');
    _meals = _meals.map((m) => m.id == meal.id ? meal : m).toList();
    await services.userDataService.saveMeals(_meals);
    await _refreshRecommendations();
    await _refreshMealChecks();
    _debugLog('[AppState] updateMeal:saved totalMeals=${_meals.length}');
    notifyListeners();
  }

  Future<void> deleteMeal(String mealId) async {
    _meals = _meals.where((m) => m.id != mealId).toList();
    await services.userDataService.saveMeals(_meals);
    await _refreshRecommendations();
    _mealCheckCache.remove(mealId);
    notifyListeners();
  }

  Future<void> addIntake(Intake intake) async {
    _debugLog('[AppState] addIntake:start');
    _intakes = [intake, ..._intakes];
    await services.userDataService.saveIntakes(_intakes);
    await _refreshRecommendations();
    await _refreshMealChecks();
    _debugLog('[AppState] addIntake:saved totalIntakes=${_intakes.length}');
    notifyListeners();
  }

  Future<void> updateIntake(Intake intake) async {
    _debugLog('[AppState] updateIntake:start');
    _intakes =
        _intakes.map((item) => item.id == intake.id ? intake : item).toList();
    await services.userDataService.saveIntakes(_intakes);
    await _refreshRecommendations();
    await _refreshMealChecks();
    _debugLog('[AppState] updateIntake:saved totalIntakes=${_intakes.length}');
    notifyListeners();
  }

  Future<void> deleteIntake(String intakeId) async {
    _debugLog('[AppState] deleteIntake:start');
    _intakes = _intakes.where((item) => item.id != intakeId).toList();
    await services.userDataService.saveIntakes(_intakes);
    await _refreshRecommendations();
    await _refreshMealChecks();
    _debugLog('[AppState] deleteIntake:saved totalIntakes=${_intakes.length}');
    notifyListeners();
  }

  Future<InteractionResult> checkMeal(Meal meal) async {
    _debugLog('[AppState] checkMeal:start items=${meal.items.length}');
    final rawResult = await services.databaseBackedMealCheckUseCase(
      meal: meal,
      activeDrugs: _drugsForMealCheck(),
      intakes: _intakes,
      userProfile: _userProfile,
    );
    final adapter = services.nextMealRecommendationOrchestrator.localAiAdapter;
    final result = adapter == null
        ? rawResult
        : await adapter.polishInteractionResult(
            userProfile: _userProfile,
            meal: meal,
            result: rawResult,
            activeDrugs: _drugsForMealCheck(),
            intakes: _intakes,
          );
    _mealCheckCache = {
      ..._mealCheckCache,
      meal.id: result,
    };
    await services.userClinicalAuditService.recordMealCheck(
      meal: meal,
      result: result,
      userProfile: _userProfile,
      activeDrugIds: _activeDrugIds,
      intakes: _intakes,
    );
    notifyListeners();
    return result;
  }

  InteractionResult cachedMealCheck(Meal meal) {
    return _mealCheckCache[meal.id] ??
        services.interactionEngine.evaluateMealWithDrugs(
          meal: meal,
          drugs: _drugsForMealCheck(),
          // 旧引擎只作为缓存未命中时的兜底，也需要跟随用户当前语言。
          localeTag: _userProfile.displayLocale,
        );
  }

  List<TimelineEvent> get timeline {
    return services.getTimelineUseCase(
      meals: _meals,
      intakes: _intakes,
      medications: services.medicationRepository.allDrugs,
    );
  }

  List<FoodRecommendation> get recommendations {
    return List.unmodifiable(_recommendations);
  }

  List<ProteinTrendPoint> get proteinTrend {
    return services.getProteinTrendUseCase(_meals);
  }

  double get averageProtein {
    return services.getProteinTrendUseCase.averageProtein(_meals);
  }

  String newId(String prefix) {
    // Web/JS 下 `1 << 32` 会溢出成 0，导致 nextInt(0) 抛 RangeError。
    // 这里改用跨平台安全的随机范围。
    final r = Random().nextInt(1 << 31);
    final now = DateTime.now().microsecondsSinceEpoch;
    final id = '${prefix}_${now}_$r';
    _debugLog('[AppState] newId prefix=$prefix');
    return id;
  }

  /// Best-effort augmentation of the food repository with foods projected
  /// from CDSS observations. Educational simulation only; failures are
  /// swallowed because the persisted catalog already provides a working
  /// baseline. The projection adds items via id-keyed merge (seed/persisted
  /// items win for duplicate ids; projection-only items are appended).
  Future<void> _augmentFoodRepoFromProjection() async {
    try {
      final projected =
          await services.cdssCatalogProjectionService.projectFoods();
      if (projected.isEmpty) return;
      final existing = services.foodRepository.allFoods;
      final byId = <String, FoodItem>{
        for (final f in existing) f.id: f,
      };
      for (final p in projected) {
        byId.putIfAbsent(p.id, () => p);
      }
      services.foodRepository.replaceAll(byId.values.toList(growable: false));
    } catch (_) {
      // Projection unavailable on this device (e.g. CDSS DB empty);
      // existing seed/persisted catalog remains active.
    }
  }

  /// Pull every row from the `locale_resource_bundle` table and install it
  /// into `AppI18n` as a runtime override. Robust against missing tables
  /// (e.g. fresh DB on first boot) so we never block bootstrap on i18n.
  Future<void> _refreshLocaleResourceOverrides() async {
    try {
      final rows =
          await services.cdssDatabase.queryTable('locale_resource_bundle');
      AppI18n.installRuntimeOverrides(
        rows.map(
          (row) => (
            localeTag: '${row['locale_tag'] ?? ''}',
            namespace: '${row['namespace'] ?? ''}',
            key: '${row['key'] ?? ''}',
            text: '${row['text'] ?? ''}',
          ),
        ),
      );
    } catch (error) {
      _debugLog(
        '[AppState] locale_resource_bundle load skipped: ${error.runtimeType}',
      );
    }
  }

  /// Compute a *fresh* next-meal recommendation for a user-supplied target
  /// time. Distinct from `_refreshRecommendations()` (which is implicit,
  /// dashboard-driven, "now" based): this one is the explicit entry-point
  /// used by the new "Next-meal recommendation" page. The conflict engine
  /// stays primary; local AI is opt-in per call to polish wording.
  ///
  /// Returns the full result so the page can render explanations, gate
  /// reasons, AI badge, etc. Does NOT mutate the dashboard-cached
  /// `_recommendations` snapshot — those two views are independent.
  Future<NextMealRecommendationResult> requestNextMealRecommendation({
    required DateTime nextMealAt,
    required bool useLocalAi,
    Duration? windowDuration,
  }) async {
    // We pass `nextMealAt` as the orchestrator's `now` so its window-based
    // scoring evaluates against the *target* time, not wall-clock. That
    // matches what users mean when they say "I plan to eat at 19:00".
    final mode = useLocalAi
        ? RecommendationMode.hybridLocalLlm
        : RecommendationMode.conservativeOnly;
    // When the user supplies a window duration, build a user-defined window
    // [nextMealAt, nextMealAt + duration] so mechanistic-primary scoring can
    // activate. The engine never picks the window; the user does.
    UserDefinedMealWindow? window;
    if (windowDuration != null && windowDuration.inMinutes > 0) {
      final startMin = dateTimeToMinute(nextMealAt);
      window = UserDefinedMealWindow(
        window: TimelineWindow(
          startMinute: startMin,
          endMinute: startMin + windowDuration.inMinutes,
        ),
        source: 'user_input',
      );
    }
    return services.nextMealRecommendationOrchestrator.recommend(
      request: NextMealRecommendationRequest(
        userProfile: _userProfile,
        history: _meals,
        activeDrugs: activeDrugs,
        intakes: _intakes,
        now: nextMealAt,
        mode: mode,
        userConsentedToAi: useLocalAi && _userProfile.localAiConsentEnabled,
        userDefinedWindow: window,
      ),
      candidateFoods: services.foodRepository.allFoods,
    );
  }

  Future<void> _refreshRecommendations() async {
    final result = await services.nextMealRecommendationOrchestrator.recommend(
      request: NextMealRecommendationRequest(
        userProfile: _userProfile,
        history: _meals,
        activeDrugs: activeDrugs,
        intakes: _intakes,
        now: DateTime.now(),
        mode: RecommendationMode.auto,
        userConsentedToAi: _userProfile.localAiConsentEnabled,
      ),
      candidateFoods: services.foodRepository.allFoods,
    );
    _recommendations = result.recommendations;
    _recommendationDecisionPath = result.decisionPath;
    _recommendationExplanations = result.explanations;
    _recommendationGateReasons = result.gateReasons;
    _recommendationAiUsed = result.aiUsed;
    _recommendationTemplateCountryCode = result.templateCountryCode;
    _recommendationTemplateMealSlot = result.templateMealSlot;
    _recommendationTemplateTextureLevel = result.templateTextureLevel;
    _localAiAvailability = result.aiProvider == null
        ? _localAiAvailability
        : LocalAiAvailability(
            available: result.aiUsed,
            provider: result.aiProvider!,
            endpoint: result.aiEndpoint ?? '',
            model: result.aiModel ?? '',
            message: result.aiRerankUsed
                ? 'Local AI reranking succeeded.'
                : result.aiUsed
                    ? 'Local AI copy polish succeeded.'
                    : 'Recommendation stayed on the conservative path.',
          );
    if (!FirebaseBackend.enabled) {
      final activeSnapshot = await services.clinicalDecisionSupportService
          .latestPromotedSnapshot();
      await services.clinicalDecisionSupportService.writeRecommendationAudit(
        userProfile: UserProfileRuntimeContext(
          patientId: _userProfile.patientId,
          registrationRegion: _userProfile.registrationRegion,
          displayLocale: _userProfile.displayLocale,
          contentJurisdictionOverride: _userProfile.contentJurisdictionOverride,
          dietProfileRegion: _userProfile.dietProfileRegion,
          timezone: _userProfile.timezone,
        ),
        mealSlot: 'dashboard',
        factsVersion: activeSnapshot?.factsVersion ?? 'regional_master_data_v1',
        rulesVersion: 'baseline_cdss_rules_v1',
        recommendations: _recommendations,
      );
    } else {
      await services.userClinicalAuditService.recordRecommendationRefresh(
        userProfile: _userProfile,
        activeDrugIds: _activeDrugIds,
        intakes: _intakes,
        meals: _meals,
        recommendations: _recommendations,
        decisionPath: _recommendationDecisionPath,
        explanations: _recommendationExplanations,
        gateReasons: _recommendationGateReasons,
        aiUsed: _recommendationAiUsed,
      );
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> importP0FromLocalPaths({
    String? ciqualPath,
    String? fdcPath,
    String? dailyMedPath,
    String? dpdPath,
  }) async {
    _isImportingP0 = true;
    notifyListeners();
    final locator = createLocalP0ImportLocator();
    _lastImportRequest = {
      'ciqual': ciqualPath ?? '',
      'fdc': fdcPath ?? '',
      'dailymed': dailyMedPath ?? '',
      'dpd': dpdPath ?? '',
    };
    try {
      final selection = await locator.resolve(
        ciqualPath: ciqualPath,
        fdcPath: fdcPath,
        dailyMedPath: dailyMedPath,
        dpdPath: dpdPath,
      );
      final stepReports =
          await services.p0IngestionOrchestrator.importOfflinePackagesDetailed(
        ciqualArchiveBytes: selection.ciqualArchiveBytes,
        fdcZipBytes: selection.fdcZipBytes,
        dailyMedZipBytes: selection.dailyMedZipBytes,
        dpdZipBytes: selection.dpdZipBytes,
      );
      if (stepReports.any((item) => item.succeeded)) {
        await bootstrap();
      }
      final steps = stepReports
          .map(
            (report) async => ImportStepResult(
              sourceKey: report.sourceKey,
              sourceLabel: report.sourceLabel,
              succeeded: report.succeeded,
              sourceFamily: report.report?.sourceFamily ?? report.sourceLabel,
              runId: report.report?.runId,
              promotedSnapshotId: report.report?.promotedSnapshotId,
              sourceDocumentCount: report.report?.sourceDocumentCount,
              foodCount: report.report?.foodCount,
              drugCount: report.report?.drugCount,
              observationCount: report.report?.observationCount,
              errorMessage: report.errorMessage,
              attempts: report.attempts,
              checkpoint: report.checkpoint,
              resumeToken: report.resumeToken,
              runs: await _loadImportRunsFor(
                runId: report.report?.runId,
              ),
              sourceDocuments: await _loadImportSourceDocumentsForBundle(
                report.bundle ?? const P0ImportBundle(),
              ),
              completedAt: report.report?.completedAt ?? DateTime.now(),
            ),
          )
          .toList(growable: false);
      final resolvedSteps = await Future.wait(steps);
      final successCount = resolvedSteps.where((item) => item.succeeded).length;
      final failureCount = resolvedSteps.length - successCount;
      _latestImportTask = ImportTaskResult(
        succeeded: failureCount == 0 && resolvedSteps.isNotEmpty,
        summary: failureCount == 0
            ? 'Imported $successCount source package(s) into staging/promoted CDSS snapshots.'
            : 'Imported $successCount source package(s), $failureCount failed. See per-source details below.',
        resolvedPaths: selection.resolvedPaths,
        steps: resolvedSteps,
        completedAt: DateTime.now(),
      );
    } catch (error) {
      _latestImportTask = ImportTaskResult(
        succeeded: false,
        summary: 'Import failed: $error',
        resolvedPaths: const <String, String>{},
        steps: const <ImportStepResult>[],
        completedAt: DateTime.now(),
      );
    } finally {
      _isImportingP0 = false;
      notifyListeners();
    }
  }

  Future<void> retryLastImportTask() async {
    await importP0FromLocalPaths(
      ciqualPath: _lastImportRequest['ciqual'],
      fdcPath: _lastImportRequest['fdc'],
      dailyMedPath: _lastImportRequest['dailymed'],
      dpdPath: _lastImportRequest['dpd'],
    );
  }

  Future<void> retryImportSource(String sourceKey) async {
    if (sourceKey == 'ema_medicines' ||
        sourceKey == 'ema_post_authorisation' ||
        sourceKey == 'china_official_foods') {
      await runRemoteImportTask(sourceKey);
      return;
    }
    final sourcePath = _lastImportRequest[sourceKey];
    if (sourcePath == null || sourcePath.trim().isEmpty) return;
    await importP0FromLocalPaths(
      ciqualPath: sourceKey == 'ciqual' ? sourcePath : null,
      fdcPath: sourceKey == 'fdc' ? sourcePath : null,
      dailyMedPath: sourceKey == 'dailymed' ? sourcePath : null,
      dpdPath: sourceKey == 'dpd' ? sourcePath : null,
    );
  }

  Future<void> resumeImportTask(String resumeToken) async {
    if (resumeToken.trim().isEmpty) return;
    _isImportingP0 = true;
    notifyListeners();
    try {
      final report =
          await services.p0IngestionOrchestrator.resumeImportTask(resumeToken);
      if (report.succeeded) {
        await bootstrap();
      }
      final step = await _toImportStepResult(report);
      _latestImportTask = ImportTaskResult(
        succeeded: report.succeeded,
        summary: report.succeeded
            ? 'Resumed import task ${report.sourceLabel}.'
            : 'Resume failed for ${report.sourceLabel}: ${report.errorMessage}',
        resolvedPaths: const <String, String>{},
        steps: [step],
        completedAt: DateTime.now(),
      );
    } catch (error) {
      _latestImportTask = ImportTaskResult(
        succeeded: false,
        summary: 'Resume failed: $error',
        resolvedPaths: const <String, String>{},
        steps: const <ImportStepResult>[],
        completedAt: DateTime.now(),
      );
    } finally {
      _isImportingP0 = false;
      notifyListeners();
    }
  }

  Future<void> runRemoteImportTask(String sourceKey) async {
    _isImportingP0 = true;
    notifyListeners();
    try {
      late final ImportStepResult step;
      switch (sourceKey) {
        case 'ema_medicines':
          step = await _runSingleRemoteImport(
            sourceKey: sourceKey,
            sourceLabel: 'EMA medicines',
            buildReport: () => services.p0IngestionOrchestrator
                .importEmaMedicinesMetadataDetailed(),
          );
          break;
        case 'ema_post_authorisation':
          step = await _runSingleRemoteImport(
            sourceKey: sourceKey,
            sourceLabel: 'EMA post-authorisation',
            buildReport: () => services.p0IngestionOrchestrator
                .importEmaPostAuthorisationMetadataDetailed(),
          );
          break;
        case 'china_official_foods':
          step = await _runSingleRemoteImport(
            sourceKey: sourceKey,
            sourceLabel: 'China official foods',
            buildReport: () => services.p0IngestionOrchestrator
                .importChinaSelectedFoodsDetailed(),
          );
          break;
        default:
          throw StateError('Unsupported remote import source: $sourceKey');
      }
      if (step.succeeded) {
        await bootstrap();
      }
      _latestImportTask = ImportTaskResult(
        succeeded: step.succeeded,
        summary: step.succeeded
            ? 'Imported ${step.sourceLabel} into staging/promoted CDSS snapshots.'
            : 'Import failed for ${step.sourceLabel}: ${step.errorMessage}',
        resolvedPaths: const <String, String>{},
        steps: [step],
        completedAt: DateTime.now(),
      );
    } catch (error) {
      _latestImportTask = ImportTaskResult(
        succeeded: false,
        summary: 'Remote import failed: $error',
        resolvedPaths: const <String, String>{},
        steps: const <ImportStepResult>[],
        completedAt: DateTime.now(),
      );
    } finally {
      _isImportingP0 = false;
      notifyListeners();
    }
  }

  Future<ImportStepResult> _runSingleRemoteImport({
    required String sourceKey,
    required String sourceLabel,
    required Future<P0OfflineImportStepReport> Function() buildReport,
  }) async {
    try {
      final report = await buildReport();
      return _toImportStepResult(
        report,
        sourceKeyOverride: sourceKey,
        sourceLabelOverride: sourceLabel,
      );
    } catch (error) {
      return ImportStepResult(
        sourceKey: sourceKey,
        sourceLabel: sourceLabel,
        succeeded: false,
        sourceFamily: sourceLabel,
        errorMessage: '$error',
        completedAt: DateTime.now(),
      );
    }
  }

  Future<ImportStepResult> _toImportStepResult(
    P0OfflineImportStepReport report, {
    String? sourceKeyOverride,
    String? sourceLabelOverride,
  }) async {
    final bundle = report.bundle ?? const P0ImportBundle();
    final sourceFamily = report.report?.sourceFamily ??
        sourceLabelOverride ??
        report.sourceLabel;
    return ImportStepResult(
      sourceKey: sourceKeyOverride ?? report.sourceKey,
      sourceLabel: sourceLabelOverride ?? report.sourceLabel,
      succeeded: report.succeeded,
      sourceFamily: sourceFamily,
      runId: report.report?.runId,
      promotedSnapshotId: report.report?.promotedSnapshotId,
      sourceDocumentCount:
          report.report?.sourceDocumentCount ?? bundle.sourceDocuments.length,
      foodCount: report.report?.foodCount ?? bundle.foodVariants.length,
      drugCount: report.report?.drugCount ?? bundle.drugProductVariants.length,
      observationCount:
          report.report?.observationCount ?? bundle.observations.length,
      errorMessage: report.errorMessage,
      attempts: report.attempts,
      checkpoint: report.checkpoint,
      resumeToken: report.resumeToken,
      runs: report.report != null
          ? await _loadImportRunsFor(runId: report.report!.runId)
          : await _loadRecentImportRunsBySourceFamily(sourceFamily),
      sourceDocuments: await _loadImportSourceDocumentsForBundle(bundle),
      completedAt: report.report?.completedAt ?? DateTime.now(),
    );
  }

  Future<List<ImportRunDrilldown>> _loadImportRunsFor({
    required String? runId,
  }) async {
    if (runId == null || runId.trim().isEmpty) return const [];
    final rows = await services.cdssDatabase.queryTable('ingestion_run');
    return rows
        .where((row) {
          final current = '${row['run_id'] ?? ''}';
          return current == runId || current == '${runId}_promote';
        })
        .map(_mapImportRunDrilldown)
        .toList(growable: false);
  }

  Future<List<ImportRunDrilldown>> _loadRecentImportRunsBySourceFamily(
    String sourceFamily,
  ) async {
    final rows = await services.cdssDatabase.queryTable('ingestion_run');
    final matched = rows
        .where((row) => '${row['source_family'] ?? ''}' == sourceFamily)
        .toList(growable: false)
      ..sort(
        (a, b) => ((b['created_at'] as num?)?.toInt() ?? 0)
            .compareTo((a['created_at'] as num?)?.toInt() ?? 0),
      );
    return matched.take(4).map(_mapImportRunDrilldown).toList(growable: false);
  }

  Future<List<ImportSourceDocumentDrilldown>>
      _loadImportSourceDocumentsForBundle(
    P0ImportBundle bundle,
  ) async {
    final docs = bundle.sourceDocuments
        .map(
          (item) => ImportSourceDocumentDrilldown(
            sourceDocId: item.sourceDocId,
            sourceFamily: item.sourceFamily,
            dataTier: item.dataTier,
            ingestionStrategy: item.ingestionStrategy,
            docType: item.docType,
            title: item.title,
            originUrl: item.originUrl,
            sourceStatus: item.sourceStatus,
          ),
        )
        .toList(growable: false);
    return docs;
  }

  ImportRunDrilldown _mapImportRunDrilldown(Map<String, Object?> row) {
    final notes = _safeDecodeRunNotes('${row['notes_json'] ?? ''}');
    return ImportRunDrilldown(
      runId: '${row['run_id'] ?? ''}',
      stage: '${row['stage'] ?? ''}',
      status: '${row['status'] ?? ''}',
      snapshotId: '${row['snapshot_id'] ?? ''}',
      parentSnapshotId: row['parent_snapshot_id']?.toString(),
      notesJson: '${row['notes_json'] ?? ''}',
      sourceDocumentCount: (notes['source_document_count'] as num?)?.toInt(),
      observationCount: (notes['observation_count'] as num?)?.toInt(),
      resolvedFactCount: (notes['resolved_fact_count'] as num?)?.toInt(),
      errorMessage: notes['error_message']?.toString(),
      retryAttempt: (notes['attempt'] as num?)?.toInt() ??
          ((notes['retry'] is Map)
              ? ((notes['retry'] as Map)['attempt'] as num?)?.toInt()
              : null),
      maxAttempts: (notes['max_attempts'] as num?)?.toInt() ??
          ((notes['retry'] is Map)
              ? ((notes['retry'] as Map)['max_attempts'] as num?)?.toInt()
              : null),
      checkpoint: notes['checkpoint'] is Map
          ? ((notes['checkpoint'] as Map)['phase']?.toString())
          : notes['checkpoint']?.toString(),
      resumeToken: notes['resume_token']?.toString() ??
          ((notes['checkpoint'] is Map)
              ? ((notes['checkpoint'] as Map)['resume_run_id']?.toString())
              : null),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num?)?.toInt() ?? 0,
      ),
      completedAt: row['completed_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (row['completed_at'] as num).toInt(),
            ),
    );
  }

  Map<String, dynamic> _safeDecodeRunNotes(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      // 历史 ingestion_run 可能不是 JSON；解析失败时仅保留原始 notesJson。
    }
    return const <String, dynamic>{};
  }

  Future<void> runRecommendationReplayBenchmark() async {
    // 直接复用已接好的 runner，避免 UI 层重复拼装 deterministic / hybrid 请求。
    _isRunningReplayBenchmark = true;
    _latestReplayBenchmarkError = null;
    notifyListeners();
    try {
      final report = await services.recommendationReplayRunner.run();
      _latestReplayBenchmarkReport = report;
    } catch (error) {
      _latestReplayBenchmarkError = '$error';
    } finally {
      _isRunningReplayBenchmark = false;
      notifyListeners();
    }
  }

  Future<void> refreshCdssOpsOverview() async {
    _snapshotSummaries =
        await services.knowledgeBaseReleaseService.listSnapshotSummaries();
    _importMonitorSummaries =
        await services.knowledgeBaseReleaseService.listImportSummaries();
    _snapshotDistributions =
        await services.knowledgeBaseReleaseService.listSnapshotDistributions();
    _reviewTickets =
        await services.knowledgeBaseReleaseService.listReviewTickets();
    notifyListeners();
  }

  Future<void> publishSnapshotToChannel({
    required String snapshotId,
    String channel = 'local_stable',
    String? overrideReason,
  }) async {
    _isRunningSnapshotOperation = true;
    _lastSnapshotOperationMessage = null;
    notifyListeners();
    try {
      final record = await services.knowledgeBaseReleaseService.publishSnapshot(
        snapshotId: snapshotId,
        channel: channel,
        overrideReason: overrideReason,
      );
      _lastSnapshotOperationMessage =
          'Published snapshot ${record.snapshotId} to ${record.channel}.';
      await refreshCdssOpsOverview();
    } catch (error) {
      _lastSnapshotOperationMessage = 'Snapshot publish failed: $error';
    } finally {
      _isRunningSnapshotOperation = false;
      notifyListeners();
    }
  }

  Future<void> updateReviewTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    _isRunningSnapshotOperation = true;
    _lastSnapshotOperationMessage = null;
    notifyListeners();
    try {
      final record =
          await services.knowledgeBaseReleaseService.updateReviewTicketStatus(
        ticketId: ticketId,
        status: status,
      );
      _lastSnapshotOperationMessage =
          'Review ticket ${record.ticketId} marked ${record.status}.';
      await refreshCdssOpsOverview();
    } catch (error) {
      _lastSnapshotOperationMessage = 'Review ticket update failed: $error';
    } finally {
      _isRunningSnapshotOperation = false;
      notifyListeners();
    }
  }

  Future<void> exportSnapshotBundle({
    required String snapshotId,
    String channel = 'backend_export',
  }) async {
    _isRunningSnapshotOperation = true;
    _lastSnapshotOperationMessage = null;
    notifyListeners();
    try {
      final record =
          await services.knowledgeBaseReleaseService.exportSnapshotBundle(
        snapshotId: snapshotId,
        channel: channel,
      );
      _lastSnapshotOperationMessage = record.artifactPath == null
          ? 'Snapshot export finished.'
          : 'Snapshot export finished: ${record.artifactPath}';
      await refreshCdssOpsOverview();
    } catch (error) {
      _lastSnapshotOperationMessage = 'Snapshot export failed: $error';
    } finally {
      _isRunningSnapshotOperation = false;
      notifyListeners();
    }
  }

  Future<void> importSnapshotBundle({
    required String filePath,
    String channel = 'bundle_import',
  }) async {
    _isRunningSnapshotOperation = true;
    _lastSnapshotOperationMessage = null;
    notifyListeners();
    try {
      final record =
          await services.knowledgeBaseReleaseService.importSnapshotBundle(
        filePath: filePath,
        channel: channel,
      );
      _lastSnapshotOperationMessage =
          'Snapshot bundle imported: ${record.snapshotId}.';
      await bootstrap();
    } catch (error) {
      _lastSnapshotOperationMessage = 'Snapshot bundle import failed: $error';
    } finally {
      _isRunningSnapshotOperation = false;
      notifyListeners();
    }
  }

  Future<void> rollbackSnapshot({
    required String snapshotId,
    String reason = 'manual_rollback_from_ui',
    String channel = 'local_stable',
  }) async {
    _isRunningSnapshotOperation = true;
    _lastSnapshotOperationMessage = null;
    notifyListeners();
    try {
      final rollbackSnapshotId =
          await services.knowledgeBaseReleaseService.rollbackAndRepublish(
        snapshotId: snapshotId,
        reason: reason,
        channel: channel,
      );
      _lastSnapshotOperationMessage =
          'Rollback created and published snapshot $rollbackSnapshotId.';
      await bootstrap();
    } catch (error) {
      _lastSnapshotOperationMessage = 'Snapshot rollback failed: $error';
    } finally {
      _isRunningSnapshotOperation = false;
      notifyListeners();
    }
  }

  Future<void> _refreshMealChecks() async {
    final next = <String, InteractionResult>{};
    for (final meal in _meals) {
      next[meal.id] = await services.databaseBackedMealCheckUseCase(
        meal: meal,
        activeDrugs: _drugsForMealCheck(),
        intakes: _intakes,
        userProfile: _userProfile,
      );
    }
    _mealCheckCache = next;
  }
}
