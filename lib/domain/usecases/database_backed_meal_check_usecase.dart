import '../../core/analysis/nutrition_rules.dart';
import '../../core/analysis/food_repository.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import '../../core/models/interaction_result.dart';
import '../../core/models/meal.dart';
import '../../core/models/user_profile.dart';
import '../../core/i18n/app_i18n.dart';
import '../entities/cdss_runtime.dart';
import '../entities/meal_composition.dart';
import '../entities/resolved_variant.dart';
import '../entities/rule_registry_models.dart';
import '../entities/runtime_context.dart';
import 'clinical_decision_support_service.dart';
import 'catalog_food_to_candidate.dart';
import 'dosage_note_parser.dart';
import 'imported_label_rule_provider.dart';
import 'meal_composition_normalizer.dart';
import 'mechanistic_conflict_engine.dart';
import 'medication_entry_validator.dart';
import 'time_axis_builder.dart';
import 'variant_resolver.dart';

/// Adapts the legacy meal-entry flow to the newer database-backed CDSS pipeline.
///
/// 当前状态说明：
/// - EntryPage 仍然传入的是旧 Meal / DrugDefinition / Intake 模型。
/// - 这个 use case 负责把旧模型桥接到统一 runtime context。
/// - 当前已接最小高风险子集：铁剂/含铁复合维生素、增稠剂类型、肠内营养模式/蛋白量。
/// - 更完整 supplement / enteral feed 结构化病程输入仍可继续扩，但不再是“完全未接线”状态。
class DatabaseBackedMealCheckUseCase {
  final VariantResolver variantResolver;
  final ClinicalDecisionSupportService clinicalDecisionSupportService;
  final List<RuleRegistryEntry> compiledRules;
  final ImportedLabelRuleProvider? importedLabelRuleProvider;
  final FoodRepository foodRepository;

  /// Deterministic mechanistic time-axis simulation layer. The hard-rule
  /// engine (via `clinicalDecisionSupportService`) remains the source of
  /// truth for categorical decisions; this layer adds an inspectable
  /// time-axis trace alongside.
  final MechanisticConflictEngine mechanisticEngine;
  final MealCompositionNormalizer mealCompositionNormalizer;
  final MedicationEntryValidator medicationEntryValidator;
  final TimeAxisBuilder timeAxisBuilder;
  final DosageNoteParser _dosageNoteParser;

  DatabaseBackedMealCheckUseCase({
    required this.variantResolver,
    required this.clinicalDecisionSupportService,
    required this.compiledRules,
    this.importedLabelRuleProvider,
    FoodRepository? foodRepository,
    MechanisticConflictEngine? mechanisticEngine,
    MealCompositionNormalizer? mealCompositionNormalizer,
    MedicationEntryValidator? medicationEntryValidator,
    TimeAxisBuilder? timeAxisBuilder,
    DosageNoteParser? dosageNoteParser,
  })  : foodRepository = foodRepository ?? FoodRepository.createDefault(),
        mechanisticEngine = mechanisticEngine ?? MechanisticConflictEngine(),
        mealCompositionNormalizer =
            mealCompositionNormalizer ?? MealCompositionNormalizer(),
        medicationEntryValidator =
            medicationEntryValidator ?? MedicationEntryValidator(),
        timeAxisBuilder = timeAxisBuilder ?? TimeAxisBuilder(),
        _dosageNoteParser = dosageNoteParser ?? DosageNoteParser();

  Future<InteractionResult> call({
    required Meal meal,
    required List<DrugDefinition> activeDrugs,
    required List<Intake> intakes,
    required UserProfile userProfile,
    DateTime? now,
  }) async {
    final base = await _callCore(
      meal: meal,
      activeDrugs: activeDrugs,
      intakes: intakes,
      userProfile: userProfile,
      now: now,
    );
    final traceJson = _computeMechanisticTraceJson(
      meal: meal,
      activeDrugs: activeDrugs,
      intakes: intakes,
      referenceTime: now ?? meal.recordedAt,
    );
    if (traceJson == null) return base;
    return base.copyWith(mechanisticTraceJson: traceJson);
  }

  Future<InteractionResult> _callCore({
    required Meal meal,
    required List<DrugDefinition> activeDrugs,
    required List<Intake> intakes,
    required UserProfile userProfile,
    DateTime? now,
  }) async {
    final i18n = AppI18n.fromLocaleTag(userProfile.displayLocale);
    // 默认以记录时间作为“本次检查发生时刻”：
    // - 正常实时录餐：recordedAt 与 occurredAt 接近，仍会完整检查；
    // - 用户补录/回改历史餐时：recordedAt 晚于 occurredAt，过期餐次不会制造当前高风险；
    // - 测试或批处理如需按真实当前时间重算，可显式传入 now。
    final referenceTime = now ?? meal.recordedAt;
    if (activeDrugs.isEmpty) {
      return InteractionResult.ok(
        mealId: meal.id,
        message: i18n.tr('mealcheck.no_active_drugs'),
      );
    }

    final profileContext = UserProfileRuntimeContext(
      patientId: userProfile.patientId,
      registrationRegion: userProfile.registrationRegion,
      displayLocale: userProfile.displayLocale,
      contentJurisdictionOverride: userProfile.contentJurisdictionOverride,
      dietProfileRegion: userProfile.dietProfileRegion,
      timezone: userProfile.timezone,
    );

    final resolvedFoods = await Future.wait(
      meal.items.map(
        (item) => variantResolver.resolveFoodVariant(
          foodId: item.foodId,
          userProfile: profileContext,
        ),
      ),
    );
    final mealMetrics = await _buildMealMetrics(
      meal: meal,
      resolvedFoods: resolvedFoods,
    );
    final temporalState = _estimateMealTemporalState(
      meal: meal,
      mealMetrics: mealMetrics,
      referenceTime: referenceTime,
    );

    if (temporalState.isOutsideCurrentRiskWindow) {
      final summary = i18n.tr(
        'mealcheck.historical_no_current_risk',
        {'hours': temporalState.age.inHours.toString()},
      );
      final analysisText = i18n.tr(
        'mealcheck.historical_analysis',
        {
          'hours': temporalState.age.inHours.toString(),
          'window': temporalState.activeWindow.inHours.toString(),
        },
      );
      return InteractionResult(
        mealId: meal.id,
        status: InteractionStatus.ok,
        summary: summary,
        analysisText: analysisText,
        keyFindings: [summary],
        dataNotes: [
          i18n.tr(
            'mealcheck.historical_note',
            {'window': temporalState.activeWindow.inHours.toString()},
          ),
          ..._buildMealContextNotes(i18n, meal),
        ],
        issues: const <InteractionIssue>[],
        generatedAt: referenceTime,
        score: 0,
      );
    }

    final issues = <InteractionIssue>[];
    final keyFindings = <String>{};
    final nextActions = <String>{};
    final dataNotes = <String>{};
    dataNotes.addAll(_buildMealContextNotes(i18n, meal));
    final scoring = _MealConflictScoringModel(i18n: i18n);
    final scoreInputs = <_DrugMealScoreInput>[];
    final supplementalRules = await importedLabelRuleProvider?.loadRules() ??
        const <RuleRegistryEntry>[];
    final effectiveRules = [
      ...compiledRules,
      ...supplementalRules,
    ];

    for (final drug in activeDrugs) {
      final resolvedDrug = await variantResolver.resolveDrugVariant(
        drugId: drug.id,
        userProfile: profileContext,
      );
      final intake = _nearestIntakeForDrug(
        drug.id,
        intakes,
        meal.effectiveOccurredAt,
      );
      final coeventContext = _buildCoeventContext(meal);
      final enteralFeedContext = _buildEnteralFeedContext(meal);

      // 这里把旧应用层模型压平成统一的运行时上下文，交给真正的规则引擎执行。
      final output = await clinicalDecisionSupportService.run(
        context: UnifiedRuntimeContext(
          userProfile: profileContext,
          drug: DrugRuntimeContext(
            id: resolvedDrug.selectedVariantId,
            genericName: drug.genericName.toLowerCase(),
            brandName: drug.brandNames.isEmpty ? null : drug.brandNames.first,
            activeIngredients: _activeIngredientsForDrug(drug),
            substanceTags: _substanceTagsForDrug(drug),
            formulation: resolvedDrug.dosageForm,
            dosageForm: resolvedDrug.dosageForm,
            route: resolvedDrug.route,
            releaseType: resolvedDrug.releaseType,
            dailyDoseMg: _parseDoseMg(intake?.dosageNote),
            jurisdiction: resolvedDrug.jurisdiction,
          ),
          meal: MealRuntimeContext(
            id: meal.id,
            totalProteinG: mealMetrics.totalProteinG,
            tyramineMgEstimate: _estimateTyramine(meal),
            highFatHighCalorie: mealMetrics.highFatHighCalorie,
            itemIds: resolvedFoods
                .map((variant) => variant.selectedVariantId)
                .toList(growable: false),
          ),
          coevent: coeventContext,
          enteralFeed: enteralFeedContext,
          timestamps: TimestampRuntimeContext(
            drugTime: intake?.takenAt,
            // 当前运行时规则至少先读 corrected meal time，避免把补录时刻误当成真正进食时刻。
            mealTime: meal.effectiveOccurredAt,
            coeventTime: coeventContext == null
                ? null
                : (meal.coeventTime ?? meal.effectiveOccurredAt),
          ),
        ),
        rules: effectiveRules,
        factsVersion: 'regional_master_data_v1',
        rulesVersion: 'baseline_cdss_rules_v1',
      );
      scoreInputs.add(
        _DrugMealScoreInput(
          drug: drug,
          intake: intake,
          meal: meal,
          mealMetrics: mealMetrics,
          resolvedDrug: resolvedDrug,
          output: output,
        ),
      );

      for (final alert in output.alerts) {
        final severity = _mapSeverity(alert.decision.wireValue);
        final detailBuffer = StringBuffer(alert.explanation);
        final evidenceTitles = alert.evidenceRecords
            .map((item) => item.title.trim())
            .where((title) => title.isNotEmpty)
            .toSet()
            .toList(growable: false);
        if (resolvedDrug.fallbackUsed) {
          detailBuffer.write(i18n.tr('mealcheck.drug_fallback'));
          dataNotes.add(i18n.tr('mealcheck.drug_fallback').trim());
        }
        if (resolvedFoods.any((variant) => variant.fallbackUsed)) {
          detailBuffer.write(i18n.tr('mealcheck.food_fallback'));
          dataNotes.add(i18n.tr('mealcheck.food_fallback').trim());
        }
        if (mealMetrics.usedDatabaseFacts) {
          detailBuffer.write(i18n.tr('mealcheck.db_facts'));
          dataNotes.add(i18n.tr('mealcheck.db_facts').trim());
        }
        keyFindings.add(
          '${i18n.decisionLabel(alert.decision.wireValue)} · ${i18n.medicationName(drug.id, drug.displayName)}: ${alert.explanation}',
        );
        nextActions.addAll(
          alert.actions
              .map((action) => _describeMachineAction(i18n, action))
              .where((text) => text.trim().isNotEmpty),
        );
        dataNotes.addAll(_extractMissingInputNotes(i18n, alert.explanation));
        if (evidenceTitles.isNotEmpty) {
          final evidenceLine = i18n.tr(
            'mealcheck.official_source',
            {'title': evidenceTitles.first},
          );
          keyFindings.add(evidenceLine);
          dataNotes.add(evidenceLine);
          detailBuffer.write(' $evidenceLine');
        }

        issues.add(
          InteractionIssue(
            severity: severity,
            title:
                '${i18n.decisionLabel(alert.decision.wireValue)} · ${i18n.medicationName(drug.id, drug.displayName)}',
            detail: detailBuffer.toString(),
            relatedDrugId: drug.id,
            evidence: alert.evidenceRecords
                .map(
                  (item) => InteractionEvidence(
                    sourceRef: item.sourceRef,
                    title: item.title,
                    pmid: item.pmid,
                    doi: item.doi,
                    sourceUrl: item.sourceUrl,
                    publication: item.publication,
                    evidenceKind: item.evidenceKind,
                    sourceFamily: item.sourceFamily,
                  ),
                )
                .toList(growable: false),
          ),
        );
      }
    }

    if (issues.isEmpty) {
      return InteractionResult.ok(
        mealId: meal.id,
        message: i18n.tr('mealcheck.no_conflict'),
      );
    }
    final scoreResult = scoring.score(scoreInputs);

    return InteractionResult(
      mealId: meal.id,
      status: InteractionStatus.warning,
      summary: i18n.tr('mealcheck.summary', {'count': '${issues.length}'}),
      analysisText: _buildAnalysisText(
        i18n: i18n,
        issues: issues,
        score: scoreResult.score,
        activeDrugCount: activeDrugs.length,
        mealMetrics: mealMetrics,
        resolvedFoods: resolvedFoods,
        scoreFactors: scoreResult.factors,
      ),
      keyFindings: keyFindings.toList(growable: false),
      nextActions: nextActions.toList(growable: false),
      dataNotes: dataNotes.toList(growable: false),
      issues: issues,
      generatedAt: DateTime.now(),
      score: scoreResult.score,
      scoreFactors: scoreResult.factors,
    );
  }

  /// 生成冲突引擎分析说明：
  /// - 不是再重复逐条 issue，而是给出这次判定的总体解释；
  /// - 便于用户在看到红/黄结果时，先理解“为什么会是这个等级”。
  String _buildAnalysisText({
    required AppI18n i18n,
    required List<InteractionIssue> issues,
    required int score,
    required int activeDrugCount,
    required _MealMetrics mealMetrics,
    required List<ResolvedFoodVariant> resolvedFoods,
    required List<InteractionScoreFactor> scoreFactors,
  }) {
    final highestSeverity = issues.fold<InteractionSeverity>(
      InteractionSeverity.low,
      (current, issue) =>
          issue.severity.index > current.index ? issue.severity : current,
    );
    final segments = <String>[
      i18n.tr(
        'mealcheck.analysis',
        {
          'drugCount': '$activeDrugCount',
          'severity': i18n.severityLabel(_severityWireValue(highestSeverity)),
          'score': '$score',
        },
      ),
      i18n.tr(
        'mealcheck.analysis_protein',
        {'protein': mealMetrics.totalProteinG.toStringAsFixed(1)},
      ),
    ];

    if (mealMetrics.highFatHighCalorie) {
      segments.add(i18n.tr('mealcheck.analysis_highfat'));
    }
    if (scoreFactors.isNotEmpty) {
      segments.add(
        i18n.tr(
          'mealcheck.analysis_scoring',
          {
            'factors': scoreFactors
                .take(3)
                .map((factor) => '${factor.label} +${factor.points}')
                .join(', '),
          },
        ),
      );
    }
    if (mealMetrics.usedDatabaseFacts) {
      segments.add(i18n.tr('mealcheck.analysis_dbfacts'));
    }
    if (issues.any((issue) =>
        issue.detail.contains('starch-based thickener') ||
        issue.detail.contains('淀粉型增稠剂') ||
        issue.detail.contains('enteral feeding') ||
        issue.detail.contains('肠内营养'))) {
      segments.add(i18n.tr('mealcheck.analysis_context_used'));
    }
    if (issues.any((issue) => issue.evidence.isNotEmpty)) {
      segments.add(i18n.tr('mealcheck.analysis_evidence'));
    }
    if (resolvedFoods.any((variant) => variant.fallbackUsed)) {
      segments.add(i18n.tr('mealcheck.analysis_fallback'));
    }
    if (score >= 85) {
      segments.add(i18n.tr('mealcheck.analysis_manual_review'));
    } else {
      segments.add(i18n.tr('mealcheck.analysis_followup'));
    }
    return segments.join(' ');
  }

  Iterable<String> _extractMissingInputNotes(
    AppI18n i18n,
    String explanation,
  ) sync* {
    final lower = explanation.toLowerCase();
    if (lower.contains('dose')) {
      yield '${i18n.tr('interaction.missing_input')}: ${i18n.tr('missing.dose')}';
    }
    if (lower.contains('drug time') || lower.contains('medication time')) {
      yield '${i18n.tr('interaction.missing_input')}: ${i18n.tr('missing.time')}';
    }
    if (lower.contains('meal time')) {
      yield '${i18n.tr('interaction.missing_input')}: ${i18n.tr('missing.meal_time')}';
    }
    if (lower.contains('thickener')) {
      yield '${i18n.tr('interaction.missing_input')}: ${i18n.tr('missing.thickener_type')}';
    }
  }

  String _describeMachineAction(
    AppI18n i18n,
    Map<String, dynamic> action,
  ) {
    final type = '${action['type'] ?? ''}';
    final params = action['params'] is Map<String, dynamic>
        ? action['params'] as Map<String, dynamic>
        : <String, dynamic>{};
    switch (type) {
      case 'suggest_reschedule':
        final before = params['preferred_before_meal_min'];
        final after = params['preferred_after_meal_min'];
        if (before != null && after != null) {
          return i18n.tr(
            'interaction.action_reschedule_full',
            {'before': '$before', 'after': '$after'},
          );
        }
        if (before != null) {
          return i18n.tr(
            'interaction.action_reschedule_before',
            {'before': '$before'},
          );
        }
        return i18n.tr('interaction.action_reschedule_generic');
      case 'separate_by_time':
        return i18n.tr(
          'interaction.action_separate_by_time',
          {'minutes': '${params['min_separation_minutes'] ?? 0}'},
        );
      case 'avoid_food':
        return i18n.tr('interaction.action_avoid_food');
      case 'avoid_combination':
        return i18n.tr('interaction.action_avoid_combination');
      case 'switch_thickener':
        return i18n.tr('interaction.action_switch_thickener');
      case 'require_manual_review':
        return i18n.tr('interaction.action_manual_review');
      default:
        return '';
    }
  }

  Intake? _nearestIntakeForDrug(
    String drugId,
    List<Intake> intakes,
    DateTime mealTime,
  ) {
    final matches = intakes
        .where((intake) => intake.drugId == drugId)
        .toList(growable: false);
    if (matches.isEmpty) return null;
    matches.sort((left, right) {
      final leftDistance = left.takenAt.difference(mealTime).abs();
      final rightDistance = right.takenAt.difference(mealTime).abs();
      final distanceComparison = leftDistance.compareTo(rightDistance);
      if (distanceComparison != 0) return distanceComparison;
      return right.takenAt.compareTo(left.takenAt);
    });
    return matches.first;
  }

  Iterable<String> _buildMealContextNotes(AppI18n i18n, Meal meal) sync* {
    if (meal.coeventSubstanceTags.contains('iron_salt')) {
      yield i18n.tr('mealcheck.context_iron_supplement');
    }
    if (meal.coeventSubstanceTags.contains('multivitamin_with_iron')) {
      yield i18n.tr('mealcheck.context_iron_multivitamin');
    }
    if (meal.thickenerType == 'starch_based') {
      yield i18n.tr('mealcheck.context_starch_thickener');
    } else if (meal.thickenerType == 'xanthan_based') {
      yield i18n.tr('mealcheck.context_xanthan_thickener');
    }
    if (meal.enteralFeedMode == 'continuous') {
      yield i18n.tr(
        'mealcheck.context_enteral_feed_continuous',
        {
          'protein': meal.enteralFeedProteinGPerDay?.toStringAsFixed(0) ??
              'unspecified',
        },
      );
    } else if (meal.enteralFeedMode == 'bolus') {
      yield i18n.tr('mealcheck.context_enteral_feed_bolus');
    }
  }

  CoeventRuntimeContext? _buildCoeventContext(Meal meal) {
    final substanceTags = meal.coeventSubstanceTags
        .where((tag) => tag.trim().isNotEmpty)
        .toList(growable: false);
    if (substanceTags.isEmpty && meal.thickenerType == null) {
      return null;
    }
    return CoeventRuntimeContext(
      substanceTags: substanceTags,
      supplements: {
        if (substanceTags.isNotEmpty) 'selected_tags': substanceTags,
      },
      thickenerType: meal.thickenerType,
    );
  }

  EnteralFeedRuntimeContext? _buildEnteralFeedContext(Meal meal) {
    if (meal.enteralFeedMode == null || meal.enteralFeedMode!.trim().isEmpty) {
      return null;
    }
    return EnteralFeedRuntimeContext(
      mode: meal.enteralFeedMode!,
      formula: meal.enteralFeedFormula,
      proteinGPerDay: meal.enteralFeedProteinGPerDay,
    );
  }

  List<String> _activeIngredientsForDrug(DrugDefinition drug) {
    final generic = drug.genericName.toLowerCase();
    if (generic.contains('levodopa') && generic.contains('carbidopa')) {
      return const ['carbidopa', 'levodopa'];
    }
    if (generic.contains('levodopa')) {
      return const ['levodopa'];
    }
    if (generic.contains('rasagiline')) {
      return const ['rasagiline'];
    }
    if (generic.contains('safinamide')) {
      return const ['safinamide'];
    }
    if (generic.contains('selegiline')) {
      return const ['selegiline'];
    }
    if (generic.contains('iron')) {
      return const ['iron'];
    }
    return [generic];
  }

  List<String> _substanceTagsForDrug(DrugDefinition drug) {
    final tags = <String>[];
    final generic = drug.genericName.toLowerCase();
    for (final tag in drug.tags) {
      switch (tag) {
        case DrugTag.levodopaLike:
          tags.add('levodopa');
          break;
        case DrugTag.comtInhibitor:
          tags.add('comt_inhibitor');
          break;
        case DrugTag.maoi:
          tags.add('maob_inhibitor');
          break;
        case DrugTag.mineralSupplement:
          tags.add('iron_salt');
          break;
        case DrugTag.dopamineAgonist:
          tags.add('dopamine_agonist');
          break;
        case DrugTag.adenosineA2aAntagonist:
          tags.add('adenosine_a2a_antagonist');
          break;
        case DrugTag.amantadineLike:
          tags.add('amantadine_like');
          break;
        case DrugTag.cholinesteraseInhibitor:
          tags.add('cholinesterase_inhibitor');
          break;
        case DrugTag.pressorAgent:
          tags.add('pressor_agent');
          break;
        case DrugTag.laxative:
          tags.add('laxative');
          break;
      }
    }
    // 对旧目录模型做最小语义增强：
    // - PEG 规则看的是 substance_tags，而不是目录 tag 本身；
    // - 因此前台如果只激活了“PEG 3350”这类药物，桥接层需要显式补出 peg 标签。
    if (generic.contains('peg 3350') ||
        generic.contains('peg3350') ||
        generic.contains('polyethylene glycol')) {
      tags.add('peg_3350');
      tags.add('peg_based_solution');
    }
    return tags;
  }

  double _estimateTyramine(Meal meal) {
    final hasHighTyramine =
        meal.items.any((item) => item.foodTags.contains('high_tyramine'));
    return hasHighTyramine ? 180 : 0;
  }

  _MealTemporalState _estimateMealTemporalState({
    required Meal meal,
    required _MealMetrics mealMetrics,
    required DateTime referenceTime,
  }) {
    final anchor = meal.occurredRangeEnd ?? meal.effectiveOccurredAt;
    final rawAge = referenceTime.difference(anchor);
    final age = rawAge.isNegative ? Duration.zero : rawAge;

    // 工程默认值，不伪装成医学标准：
    // 普通餐的运行时食药冲突活跃窗设为 4 小时；高蛋白、高脂/高热量或较大餐延长，
    // 但硬上限为 8 小时，防止“24 小时前的餐次仍导致当前高风险”这类过期告警。
    var activeWindow = const Duration(hours: 4);
    if (mealMetrics.totalProteinG >= 15) {
      activeWindow += const Duration(minutes: 90);
    }
    if (mealMetrics.highFatHighCalorie) {
      activeWindow += const Duration(hours: 2);
    }
    if (mealMetrics.totalCarbsG +
            mealMetrics.totalProteinG +
            mealMetrics.totalFatG >=
        70) {
      activeWindow += const Duration(minutes: 30);
    }
    if (activeWindow > const Duration(hours: 8)) {
      activeWindow = const Duration(hours: 8);
    }

    final hasOngoingEnteralFeed = meal.enteralFeedMode == 'continuous';
    return _MealTemporalState(
      age: age,
      activeWindow: activeWindow,
      isOutsideCurrentRiskWindow: !hasOngoingEnteralFeed && age > activeWindow,
    );
  }

  Future<_MealMetrics> _buildMealMetrics({
    required Meal meal,
    required List<ResolvedFoodVariant> resolvedFoods,
  }) async {
    // 当前只读取 qualifier=exact 的 observation 来重算餐级营养。
    // 未完成：还没有把 range / lt / trace 等区间值纳入餐级聚合逻辑。
    final rows =
        await clinicalDecisionSupportService.database.queryTable('observation');
    final exactByVariant = <String, Map<String, double>>{};

    for (final row in rows) {
      final entityKey = row['entity_key']?.toString();
      final attributeCode = row['attribute_code']?.toString();
      final qualifierKind = row['qualifier_kind']?.toString();
      final valueNum = row['value_num'];
      if (entityKey == null ||
          attributeCode == null ||
          qualifierKind != 'exact' ||
          valueNum is! num) {
        continue;
      }
      exactByVariant.putIfAbsent(
              entityKey, () => <String, double>{})[attributeCode] =
          valueNum.toDouble();
    }

    var totalProteinG = 0.0;
    var totalCarbsG = 0.0;
    var totalFatG = 0.0;
    var usedDatabaseFacts = false;

    for (var index = 0; index < meal.items.length; index++) {
      final item = meal.items[index];
      final variantId = resolvedFoods[index].selectedVariantId;
      final nutrients = exactByVariant[variantId];

      final proteinPer100g = nutrients?['protein_g'] ?? item.proteinPer100g;
      final carbsPer100g = nutrients?['carbohydrate_g'] ?? item.carbsPer100g;
      final fatPer100g = nutrients?['fat_g'] ?? item.fatPer100g;

      // 只要数据库里至少命中一个关键营养素，就认为该项已部分采用数据库真实值。
      if (nutrients != null &&
          (nutrients.containsKey('protein_g') ||
              nutrients.containsKey('carbohydrate_g') ||
              nutrients.containsKey('fat_g'))) {
        usedDatabaseFacts = true;
      }

      totalProteinG += proteinPer100g * item.quantityFactor;
      totalCarbsG += carbsPer100g * item.quantityFactor;
      totalFatG += fatPer100g * item.quantityFactor;
    }

    return _MealMetrics(
      totalProteinG: totalProteinG,
      totalCarbsG: totalCarbsG,
      totalFatG: totalFatG,
      highFatHighCalorie:
          totalFatG >= 20 && (totalCarbsG + totalProteinG + totalFatG) >= 40,
      usedDatabaseFacts: usedDatabaseFacts,
    );
  }

  /// Daily dose in mg derived ONLY from an explicit user-entered dosage note
  /// (value + recognized mass unit) via `DosageNoteParser`. Never infers a
  /// number from free text: "levodopa 100", bare "100", or a slashed combo
  /// yield null so the rule engine treats the dose as unknown instead of
  /// fabricating 100 mg.
  double? _parseDoseMg(String? dosageNote) =>
      _dosageNoteParser.milligrams(dosageNote);

  InteractionSeverity _mapSeverity(String decision) {
    switch (decision) {
      case 'BLOCK':
      case 'REQUIRE_REVIEW':
        return InteractionSeverity.high;
      case 'WARN':
      case 'DISCOURAGE':
        return InteractionSeverity.moderate;
      default:
        return InteractionSeverity.low;
    }
  }

  String _severityWireValue(InteractionSeverity severity) {
    switch (severity) {
      case InteractionSeverity.low:
        return 'low';
      case InteractionSeverity.moderate:
        return 'moderate';
      case InteractionSeverity.high:
        return 'high';
    }
  }

  // ---------------------------------------------------------------------------
  // Mechanistic trace (additive, non-authoritative).
  // ---------------------------------------------------------------------------

  Map<String, dynamic>? _computeMechanisticTraceJson({
    required Meal meal,
    required List<DrugDefinition> activeDrugs,
    required List<Intake> intakes,
    required DateTime referenceTime,
  }) {
    if (activeDrugs.isEmpty || intakes.isEmpty) return null;

    final drugsById = {for (final d in activeDrugs) d.id: d};
    final medInputs = <MedicationTimelineInput>[];
    for (final intake in intakes) {
      final drug = drugsById[intake.drugId];
      if (drug == null) continue;
      final ingredients = <String>{
        drug.genericName.toLowerCase(),
        ...drug.tags.map((t) => t.name.toLowerCase()),
      }.where((s) => s.isNotEmpty).toList(growable: false);
      // Dose comes ONLY from the user-entered dosage note — never a private
      // default. Non-explicit notes leave strength/unit null → insufficient
      // dose context (no dose-dependent PK interpretation).
      final dose = _dosageNoteParser.parse(intake.dosageNote);
      final raw = RawMedicationEntry(
        activeIngredients: ingredients,
        drugProductVariant: 'synthetic:${drug.id}',
        strength: dose.explicit ? dose.value : null,
        unit: dose.explicit ? dose.unit : null,
        form: drug.dosageForm,
        route: drug.route,
        releaseType: drug.releaseType,
        jurisdiction: drug.jurisdiction,
        sourceDocId: 'synthetic:${drug.sourceSystem}',
      );
      final validation = medicationEntryValidator.validate(raw);
      medInputs.add(MedicationTimelineInput(
        id: 'intake_${intake.id}',
        takenAt: intake.takenAt,
        medicationContext: validation,
      ));
    }

    if (medInputs.isEmpty) return null;

    final components = <FoodComponent>[];
    for (var index = 0; index < meal.items.length; index++) {
      final item = meal.items[index];
      components.add(
        mealItemToFoodComponent(
          item,
          componentId: 'meal_${meal.id}_${index}_${item.foodId}',
          catalogMatch: foodRepository.getById(item.foodId),
        ),
      );
    }
    final composition = mealCompositionNormalizer.normalize(
      mealId: 'comp_${meal.id}',
      components: components,
    );

    final context = timeAxisBuilder.build(
      now: referenceTime,
      medicationInputs: medInputs,
      mealInputs: [
        MealTimelineInput(
          id: 'meal_${meal.id}',
          startedAt: meal.effectiveOccurredAt,
          compositionId: composition.id,
          physicalForm: composition.mealPhysicalForm,
        ),
      ],
    );

    final trace = mechanisticEngine.evaluate(
      context: context,
      mealCompositionsById: {composition.id: composition},
      resultId: 'mealcheck_${meal.id}',
    );
    return trace.toJson();
  }
}

class _MealMetrics {
  final double totalProteinG;
  final double totalCarbsG;
  final double totalFatG;
  final bool highFatHighCalorie;
  final bool usedDatabaseFacts;

  const _MealMetrics({
    required this.totalProteinG,
    required this.totalCarbsG,
    required this.totalFatG,
    required this.highFatHighCalorie,
    required this.usedDatabaseFacts,
  });
}

class _DrugMealScoreInput {
  final DrugDefinition drug;
  final Intake? intake;
  final Meal meal;
  final _MealMetrics mealMetrics;
  final ResolvedDrugVariant resolvedDrug;
  final EngineRunOutput output;

  const _DrugMealScoreInput({
    required this.drug,
    required this.intake,
    required this.meal,
    required this.mealMetrics,
    required this.resolvedDrug,
    required this.output,
  });
}

class _MealConflictScoreResult {
  final int score;
  final List<InteractionScoreFactor> factors;

  const _MealConflictScoreResult({
    required this.score,
    required this.factors,
  });
}

class _MealConflictScoringModel {
  final AppI18n i18n;

  const _MealConflictScoringModel({required this.i18n});

  _MealConflictScoreResult score(List<_DrugMealScoreInput> inputs) {
    final factors = <InteractionScoreFactor>[];
    var maxDecisionWeight = 0;

    for (final input in inputs) {
      for (final alert in input.output.alerts) {
        final weight = _decisionWeight(alert.decision.wireValue);
        if (weight > maxDecisionWeight) {
          maxDecisionWeight = weight;
        }
      }
    }
    _addFactor(
      factors,
      code: 'rule_decision_weight',
      label: i18n.tr('mealcheck.score_factor_rule_decision'),
      points: maxDecisionWeight,
    );

    for (final input in inputs) {
      if (!_isLevodopaLike(input)) {
        continue;
      }
      final protein = input.mealMetrics.totalProteinG;
      if (protein >= NutritionRules.proteinInterferenceThresholdG) {
        final excess = protein - NutritionRules.proteinInterferenceThresholdG;
        _addFactor(
          factors,
          code: 'levodopa_interference_weight',
          label: i18n.tr('mealcheck.score_factor_levodopa_interference'),
          points: 12 + excess.clamp(0, 15).round(),
        );
        _addFactor(
          factors,
          code: 'protein_timing_penalty',
          label: i18n.tr('mealcheck.score_factor_protein_timing'),
          points: _proteinTimingPenalty(input),
        );
      }
      if (input.mealMetrics.highFatHighCalorie) {
        _addFactor(
          factors,
          code: 'high_fat_meal_modifier',
          label: i18n.tr('mealcheck.score_factor_high_fat'),
          points: 6,
        );
      }
      if (input.meal.coeventSubstanceTags.any(
        (tag) => tag == 'iron_salt' || tag == 'multivitamin_with_iron',
      )) {
        _addFactor(
          factors,
          code: 'iron_levodopa_modifier',
          label: i18n.tr('mealcheck.score_factor_iron_levodopa'),
          points: 18,
        );
      }
      if (input.meal.enteralFeedMode == 'continuous') {
        final proteinPerDay = input.meal.enteralFeedProteinGPerDay ?? 0;
        _addFactor(
          factors,
          code: 'continuous_enteral_feed_modifier',
          label: i18n.tr('mealcheck.score_factor_enteral_feed'),
          points: proteinPerDay >= 60 ? 28 : 20,
        );
      }
    }

    final hasEvidence = inputs.any(
      (input) =>
          input.output.alerts.any((alert) => alert.evidenceRecords.isNotEmpty),
    );
    _addFactor(
      factors,
      code: 'evidence_support_modifier',
      label: i18n.tr('mealcheck.score_factor_evidence'),
      points: hasEvidence ? 5 : 0,
    );

    final sortedFactors = factors
        .where((factor) => factor.points > 0)
        .toList(growable: false)
      ..sort((left, right) => right.points.compareTo(left.points));
    final total = sortedFactors.fold<int>(
      0,
      (sum, factor) => sum + factor.points,
    );
    return _MealConflictScoreResult(
      score: total.clamp(0, 100).toInt(),
      factors: sortedFactors,
    );
  }

  bool _isLevodopaLike(_DrugMealScoreInput input) {
    final generic = input.drug.genericName.toLowerCase();
    return generic.contains('levodopa') ||
        input.drug.tags.contains(DrugTag.levodopaLike) ||
        input.resolvedDrug.selectedVariantId.toLowerCase().contains('ldopa');
  }

  int _proteinTimingPenalty(_DrugMealScoreInput input) {
    final intake = input.intake;
    if (intake == null) {
      return 10;
    }
    final minutes = input.meal.effectiveOccurredAt
        .difference(intake.takenAt)
        .inMinutes
        .abs();
    if (minutes <= 60) return 24;
    if (minutes <= 120) return 16;
    if (minutes <= 180) return 8;
    return 0;
  }

  int _decisionWeight(String decision) {
    switch (decision) {
      case 'BLOCK':
        return 90;
      case 'REQUIRE_REVIEW':
        return 70;
      case 'WARN':
        return 28;
      case 'DISCOURAGE':
        return 22;
      case 'DEFER':
        return 16;
      case 'INFO':
        return 8;
      default:
        return 0;
    }
  }

  void _addFactor(
    List<InteractionScoreFactor> factors, {
    required String code,
    required String label,
    required int points,
  }) {
    if (points <= 0) return;
    final existingIndex = factors.indexWhere((factor) => factor.code == code);
    if (existingIndex == -1) {
      factors.add(
        InteractionScoreFactor(code: code, label: label, points: points),
      );
      return;
    }
    if (points > factors[existingIndex].points) {
      factors[existingIndex] =
          InteractionScoreFactor(code: code, label: label, points: points);
    }
  }
}

class _MealTemporalState {
  final Duration age;
  final Duration activeWindow;
  final bool isOutsideCurrentRiskWindow;

  const _MealTemporalState({
    required this.age,
    required this.activeWindow,
    required this.isOutsideCurrentRiskWindow,
  });
}
