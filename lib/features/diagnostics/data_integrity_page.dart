import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/catalog_version_change_diff.dart';
import '../../domain/usecases/data_integrity_report.dart';
import '../../domain/usecases/catalog_version_change_diff_service.dart';
import '../../domain/usecases/catalog_version_change_impact_service.dart';
import '../../domain/usecases/food_catalog_version_change_impact_service.dart';

/// Read-only view of whether user events and catalog inputs are computable.
///
/// Counts and ratios describe data availability only. They are not a clinical
/// score and do not claim that the underlying evidence coverage is adequate.
class DataIntegrityPage extends StatelessWidget {
  const DataIntegrityPage({super.key});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final state = context.watch<AppState>();
    final report = DataIntegrityReport.assess(
      intakes: state.intakes,
      meals: state.meals,
      foods: state.foodRepo.allFoods,
      medications: state.medRepo.allDrugs,
      doseResultEligibility: (intake) =>
          state.evaluateDoseForResultUse(intake).eligible,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PaperAppBar(title: Text(i18n.tr('runtime.validation_source'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _ReviewCard(report: report),
          const SizedBox(height: 12),
          _IntegritySection(
            title: i18n.tr('timeline.title'),
            icon: Icons.timeline_outlined,
            coverage: [
              _CoverageDatum(
                label: i18n.tr('data_integrity.dose_result_eligible'),
                value: report.doseCoverage,
                count: report.intakesWithResultEligibleDose,
                total: report.intakeCount,
              ),
              _CoverageDatum(
                label: i18n.tr('data_integrity.dose_parseable'),
                value: report.parseableDoseCoverage,
                count: report.intakesWithParseableDose,
                total: report.intakeCount,
              ),
              _CoverageDatum(
                label: i18n.tr('missing.formulation'),
                value: report.formulationSnapshotCoverage,
                count: report.intakesWithFormulationSnapshot,
                total: report.intakeCount,
              ),
              _CoverageDatum(
                label: i18n.tr('missing.meal_time'),
                value: report.mealTimeCoverage,
                count: report.mealsWithExplicitTime,
                total: report.mealCount,
              ),
              _CoverageDatum(
                label: i18n.tr('catalog.foods'),
                value: report.mealItemResolutionCoverage,
                count: report.resolvedMealItemCount,
                total: report.mealItemCount,
              ),
            ],
            issues: [
              _IssueDatum(
                label: i18n.tr('timeline.medication'),
                count: report.orphanedIntakeCount,
              ),
              _IssueDatum(
                label: i18n.tr('catalog.foods'),
                count: report.unresolvedMealItemCount,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _IntegritySection(
            title: i18n.tr('detail.source_label'),
            icon: Icons.source_outlined,
            coverage: [
              _CoverageDatum(
                label: i18n.tr('catalog.foods'),
                value: report.foodTraceabilityCoverage,
                count: report.traceableFoodCount,
                total: report.foodCount,
              ),
              _CoverageDatum(
                label: i18n.tr('timeline.medication'),
                value: report.medicationTraceabilityCoverage,
                count: report.traceableMedicationCount,
                total: report.medicationCount,
              ),
            ],
            issues: [
              _IssueDatum(
                label: i18n.tr('interaction.missing_input'),
                count: report.foodsWithMissingCoreNutrients,
              ),
              _IssueDatum(
                label: i18n.tr('missing.formulation'),
                count: report.medicationsWithIncompleteFormulation,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CatalogVersionDiffPanel(
            intakes: state.intakes,
            medications: state.medRepo.allDrugs,
            meals: state.meals,
            foods: state.foodRepo.allFoods,
            activeMedicationIds: state.activeDrugIds,
            ownerScopeIdentity:
                state.currentUserId ?? state.userProfile.patientId,
          ),
        ],
      ),
    );
  }
}

/// Local-only preview for caller-supplied captures and an explicitly requested
/// aggregate scan of matching source-code tokens in active medications and
/// recorded intakes.
class _CatalogVersionDiffPanel extends StatefulWidget {
  const _CatalogVersionDiffPanel({
    required this.intakes,
    required this.medications,
    required this.meals,
    required this.foods,
    required this.activeMedicationIds,
    required this.ownerScopeIdentity,
  });

  final List<Intake> intakes;
  final List<DrugDefinition> medications;
  final List<Meal> meals;
  final List<FoodItem> foods;
  final Set<String> activeMedicationIds;
  final String ownerScopeIdentity;

  @override
  State<_CatalogVersionDiffPanel> createState() =>
      _CatalogVersionDiffPanelState();
}

class _CatalogVersionDiffPanelState extends State<_CatalogVersionDiffPanel> {
  final TextEditingController _previousController = TextEditingController();
  final TextEditingController _currentController = TextEditingController();
  final TextEditingController _evidenceController = TextEditingController(
    text: '[]',
  );
  CatalogVersionChangeDiff? _diff;
  CatalogVersionChangeImpactPreview? _impactPreview;
  FoodCatalogVersionChangeImpactPreview? _foodImpactPreview;
  bool _invalidInput = false;
  bool _impactUnavailable = false;
  bool _foodImpactUnavailable = false;

  @override
  void dispose() {
    _previousController.dispose();
    _currentController.dispose();
    _evidenceController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CatalogVersionDiffPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ownerChanged =
        oldWidget.ownerScopeIdentity != widget.ownerScopeIdentity;
    final medicationInputsChanged = !_sameImpactInputs(
      oldWidget.intakes,
      oldWidget.medications,
      oldWidget.activeMedicationIds,
      widget.intakes,
      widget.medications,
      widget.activeMedicationIds,
    );
    final foodInputsChanged = !_sameFoodImpactInputs(
      oldWidget.meals,
      oldWidget.foods,
      widget.meals,
      widget.foods,
    );
    if ((_impactPreview != null || _impactUnavailable) &&
            (ownerChanged || medicationInputsChanged) ||
        (_foodImpactPreview != null || _foodImpactUnavailable) &&
            (ownerChanged || foodInputsChanged)) {
      setState(() {
        if (ownerChanged || medicationInputsChanged) {
          _impactPreview = null;
          _impactUnavailable = false;
        }
        if (ownerChanged || foodInputsChanged) {
          _foodImpactPreview = null;
          _foodImpactUnavailable = false;
        }
      });
    }
  }

  void _invalidatePreview(String _) {
    if (_diff == null &&
        !_invalidInput &&
        _impactPreview == null &&
        !_impactUnavailable) {
      return;
    }
    setState(() {
      _diff = null;
      _impactPreview = null;
      _foodImpactPreview = null;
      _invalidInput = false;
      _impactUnavailable = false;
      _foodImpactUnavailable = false;
    });
  }

  void _compare() {
    try {
      final diff = const CatalogVersionChangeDiffService().compareJsonCaptures(
        previousCaptureJson: _previousController.text,
        currentCaptureJson: _currentController.text,
        mappingEvidenceJson: _evidenceController.text,
      );
      setState(() {
        _diff = diff;
        _impactPreview = null;
        _foodImpactPreview = null;
        _invalidInput = false;
        _impactUnavailable = false;
        _foodImpactUnavailable = false;
      });
    } on Object {
      setState(() {
        _diff = null;
        _impactPreview = null;
        _foodImpactPreview = null;
        _invalidInput = true;
        _impactUnavailable = false;
        _foodImpactUnavailable = false;
      });
    }
  }

  void _previewLocalFoodImpact() {
    final diff = _diff;
    if (diff == null) return;
    try {
      final preview = const FoodCatalogVersionChangeImpactService().preview(
        diff: diff,
        foods: widget.foods,
        meals: widget.meals,
      );
      setState(() {
        _foodImpactPreview = preview;
        _foodImpactUnavailable = false;
      });
    } on Object {
      setState(() {
        _foodImpactPreview = null;
        _foodImpactUnavailable = true;
      });
    }
  }

  void _previewLocalImpact() {
    final diff = _diff;
    if (diff == null) return;
    try {
      final preview = const CatalogVersionChangeImpactService().preview(
        diff: diff,
        activeMedicationIds: widget.activeMedicationIds,
        intakes: widget.intakes,
        medications: widget.medications,
      );
      setState(() {
        _impactPreview = preview;
        _impactUnavailable = false;
      });
    } on Object {
      setState(() {
        _impactPreview = null;
        _impactUnavailable = true;
      });
    }
  }

  bool _sameImpactInputs(
    List<Intake> oldIntakes,
    List<DrugDefinition> oldMedications,
    Set<String> oldActiveMedicationIds,
    List<Intake> newIntakes,
    List<DrugDefinition> newMedications,
    Set<String> newActiveMedicationIds,
  ) {
    if (oldIntakes.length != newIntakes.length ||
        oldMedications.length != newMedications.length ||
        oldActiveMedicationIds.length != newActiveMedicationIds.length ||
        !oldActiveMedicationIds.every(newActiveMedicationIds.contains)) {
      return false;
    }
    for (var index = 0; index < oldIntakes.length; index++) {
      final oldIntake = oldIntakes[index];
      final newIntake = newIntakes[index];
      final oldProduct = oldIntake.productSelection;
      final newProduct = newIntake.productSelection;
      if (oldIntake.id != newIntake.id ||
          oldIntake.drugId != newIntake.drugId ||
          oldProduct?.sourceSystem != newProduct?.sourceSystem ||
          oldProduct?.identifierValue != newProduct?.identifierValue) {
        return false;
      }
    }
    for (var index = 0; index < oldMedications.length; index++) {
      final oldMedication = oldMedications[index];
      final newMedication = newMedications[index];
      if (oldMedication.id != newMedication.id ||
          oldMedication.sourceSystem != newMedication.sourceSystem ||
          oldMedication.jurisdiction != newMedication.jurisdiction ||
          oldMedication.sourceProductCode != newMedication.sourceProductCode) {
        return false;
      }
    }
    return true;
  }

  bool _sameFoodImpactInputs(
    List<Meal> oldMeals,
    List<FoodItem> oldFoods,
    List<Meal> newMeals,
    List<FoodItem> newFoods,
  ) {
    if (oldMeals.length != newMeals.length ||
        oldFoods.length != newFoods.length) {
      return false;
    }
    for (var index = 0; index < oldFoods.length; index++) {
      final oldFood = oldFoods[index];
      final newFood = newFoods[index];
      if (oldFood.id != newFood.id ||
          oldFood.sourceSystem != newFood.sourceSystem ||
          oldFood.jurisdiction != newFood.jurisdiction ||
          oldFood.sourceFoodCode != newFood.sourceFoodCode) {
        return false;
      }
    }
    for (var index = 0; index < oldMeals.length; index++) {
      final oldMeal = oldMeals[index];
      final newMeal = newMeals[index];
      if (oldMeal.id != newMeal.id ||
          oldMeal.items.length != newMeal.items.length) {
        return false;
      }
      for (var itemIndex = 0; itemIndex < oldMeal.items.length; itemIndex++) {
        if (oldMeal.items[itemIndex].foodId !=
            newMeal.items[itemIndex].foodId) {
          return false;
        }
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final zh = context.appI18n.languageFamily == 'zh';
    String copy(String chinese, String english) => zh ? chinese : english;

    return PaperCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        key: const Key('catalog-version-diff-panel'),
        leading: const Icon(Icons.compare_arrows_outlined),
        title: Text(
          copy(
            '离线药物与食物目录版本比较',
            'Offline medication and food catalog version comparison',
          ),
        ),
        subtitle: Text(
          copy(
            '只读预览；不会修改记录或规则。',
            'Read-only preview; no record or rule changes.',
          ),
        ),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              copy(
                '粘贴两个由你提供的同一目录快照 JSON，以及可选的映射证据 JSON 数组。比较仅在本机进行；药物与食物代码引用需分别触发统计，只显示汇总数，不显示记录、名称或剂量。历史记录未绑定目录发行版，因此命中只是潜在关联。输入不会保存或联网。摘要哈希不验证发布者或目录完整性。',
                'Paste two caller-supplied captures for the same catalog and an optional mapping-evidence JSON array. Comparison stays local. Medication and food-code reference scans are separate actions and show counts only, without record IDs, names, or dose details. Historical rows are not bound to a catalog release, so matches are potential references. Inputs are not saved or sent. Hashes do not verify a publisher or catalog completeness.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          _captureField(
            key: const Key('catalog-version-diff-previous-capture'),
            controller: _previousController,
            label: copy('旧版目录快照 JSON', 'Previous catalog capture JSON'),
            hint: copy(
              '必须含 record_set_sha256。',
              'Must include record_set_sha256.',
            ),
            onChanged: _invalidatePreview,
          ),
          const SizedBox(height: 10),
          _captureField(
            key: const Key('catalog-version-diff-current-capture'),
            controller: _currentController,
            label: copy('新版目录快照 JSON', 'Current catalog capture JSON'),
            hint: copy(
              '目录、来源、辖区须与旧版一致，发布序号须更高。',
              'Catalog, source, and jurisdiction must match; release sequence must increase.',
            ),
            onChanged: _invalidatePreview,
          ),
          const SizedBox(height: 10),
          _captureField(
            key: const Key('catalog-version-diff-mapping-evidence'),
            controller: _evidenceController,
            label: copy('映射证据 JSON 数组', 'Mapping evidence JSON array'),
            hint: copy(
              '无证据时保留 []；不相似匹配名称。',
              'Keep [] when there is no evidence; names are never matched approximately.',
            ),
            onChanged: _invalidatePreview,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              key: const Key('catalog-version-diff-compare'),
              onPressed: _compare,
              icon: const Icon(Icons.search),
              label: Text(copy('比较快照', 'Compare captures')),
            ),
          ),
          if (_invalidInput) ...[
            const SizedBox(height: 10),
            Text(
              copy(
                '无法生成比较。请检查 JSON 字段、快照摘要、来源绑定和发布顺序。',
                'Comparison unavailable. Check JSON fields, capture digests, source bindings, and release order.',
              ),
              key: const Key('catalog-version-diff-input-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_diff case final diff?) ...[
            const SizedBox(height: 12),
            _CatalogVersionDiffResult(diff: diff, chinese: zh),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('catalog-version-diff-impact-scan'),
                onPressed: _previewLocalImpact,
                icon: const Icon(Icons.manage_search_outlined),
                label: Text(
                  copy(
                    '统计本机药物与摄入记录代码引用',
                    'Count local medication and intake references',
                  ),
                ),
              ),
            ),
            if (_impactUnavailable)
              Text(
                copy(
                  '本机记录统计暂不可用；快照比较结果未受影响。',
                  'The local count is unavailable; the catalog comparison remains unchanged.',
                ),
                key: const Key('catalog-version-diff-impact-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_impactPreview case final impact?)
              _CatalogVersionImpactResult(preview: impact, chinese: zh),
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                key: const Key('catalog-version-diff-food-impact-scan'),
                onPressed: _previewLocalFoodImpact,
                icon: const Icon(Icons.restaurant_outlined),
                label: Text(
                  copy(
                    '统计本机食物目录与餐次代码引用',
                    'Count local food-catalog and meal-line references',
                  ),
                ),
              ),
            ),
            if (_foodImpactUnavailable)
              Text(
                copy(
                  '本机食物目录统计暂不可用；快照比较结果未受影响。',
                  'The local food count is unavailable; the catalog comparison remains unchanged.',
                ),
                key: const Key('catalog-version-diff-food-impact-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_foodImpactPreview case final foodImpact?)
              _FoodCatalogVersionImpactResult(preview: foodImpact, chinese: zh),
          ],
        ],
      ),
    );
  }

  Widget _captureField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
  }) => TextField(
    key: key,
    controller: controller,
    minLines: 3,
    maxLines: 6,
    keyboardType: TextInputType.multiline,
    autocorrect: false,
    enableSuggestions: false,
    decoration: InputDecoration(
      border: const OutlineInputBorder(),
      labelText: label,
      helperText: hint,
      alignLabelWithHint: true,
    ),
    onChanged: onChanged,
  );
}

class _CatalogVersionImpactResult extends StatelessWidget {
  const _CatalogVersionImpactResult({
    required this.preview,
    required this.chinese,
  });

  final CatalogVersionChangeImpactPreview preview;
  final bool chinese;

  @override
  Widget build(BuildContext context) {
    String copy(String zh, String en) => chinese ? zh : en;
    final kinds = preview.potentialMatchesByKind.entries
        .where((entry) => entry.value > 0)
        .toList(growable: false);
    String kindLabel(CatalogVersionChangeKind kind) => switch (kind) {
      CatalogVersionChangeKind.unchanged => copy('未变化', 'unchanged'),
      CatalogVersionChangeKind.added => copy('新增', 'added'),
      CatalogVersionChangeKind.deprecated => copy('明确退役', 'deprecated'),
      CatalogVersionChangeKind.remapped => copy('显式重映射', 'remapped'),
      CatalogVersionChangeKind.split => copy('拆分', 'split'),
      CatalogVersionChangeKind.merged => copy('合并', 'merged'),
      CatalogVersionChangeKind.ambiguous => copy('有歧义', 'ambiguous'),
      CatalogVersionChangeKind.unresolved => copy('未解决', 'unresolved'),
    };

    return Container(
      key: const Key('catalog-version-diff-impact-result'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy(
              '本机当前用药与摄入记录引用统计',
              'Local medication and intake reference counts',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            copy(
              '当前选用药物：${preview.activeMedicationIdCount} 项；有可比较来源代码 ${preview.activeMedicationsWithComparableSourceIdentity} 项；命中变更代码 ${preview.activeMedicationsWithPotentialChangedCodeMatch} 项；无可比较来源身份 ${preview.activeMedicationsWithoutComparableSourceIdentity} 项。',
              'Active selections: ${preview.activeMedicationIdCount}; comparable source identities: ${preview.activeMedicationsWithComparableSourceIdentity}; potential changed-code references: ${preview.activeMedicationsWithPotentialChangedCodeMatch}; no comparable source identity: ${preview.activeMedicationsWithoutComparableSourceIdentity}.',
            ),
          ),
          Text(
            copy(
              '历史摄入记录：${preview.intakeRowCount} 条；有可比较来源代码 ${preview.rowsWithComparableSourceIdentity} 条；命中变更代码 ${preview.rowsWithPotentialChangedCodeMatch} 条；命中多个代码 ${preview.rowsWithMultipleChangedCodeMatches} 条；无可比较来源身份 ${preview.rowsWithoutComparableSourceIdentity} 条；有来源身份但未命中变更代码 ${preview.comparableRowsWithoutChangedCodeMatch} 条。',
              'Recorded intakes: ${preview.intakeRowCount}; comparable source identities: ${preview.rowsWithComparableSourceIdentity}; potential changed-code references: ${preview.rowsWithPotentialChangedCodeMatch}; multiple changed-code matches: ${preview.rowsWithMultipleChangedCodeMatches}; no comparable source identity: ${preview.rowsWithoutComparableSourceIdentity}; comparable identity with no changed-code match: ${preview.comparableRowsWithoutChangedCodeMatch}.',
            ),
          ),
          if (kinds.isNotEmpty ||
              preview.activePotentialMatchesByKind.values.any(
                (count) => count > 0,
              ))
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final entry
                    in preview.activePotentialMatchesByKind.entries)
                  if (entry.value > 0)
                    Text(
                      '${copy('当前用药', 'active')} ${kindLabel(entry.key)}: ${entry.value}',
                    ),
                for (final entry in kinds)
                  Text(
                    '${copy('摄入记录', 'intake')} ${kindLabel(entry.key)}: ${entry.value}',
                  ),
              ],
            ),
          Text(
            copy(
              '摄入记录未保存目录发行版，命中只是潜在关联，不是已确认受影响记录。统计仅在内存中运行且只显示数量；没有记录被修改。',
              'Intakes do not store a catalog release, so matches are potential references rather than confirmed affected records. This scan stays in memory, shows counts only, and changes no records.',
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodCatalogVersionImpactResult extends StatelessWidget {
  const _FoodCatalogVersionImpactResult({
    required this.preview,
    required this.chinese,
  });

  final FoodCatalogVersionChangeImpactPreview preview;
  final bool chinese;

  @override
  Widget build(BuildContext context) {
    String copy(String zh, String en) => chinese ? zh : en;
    final foodKinds = preview.foodMatchesByKind.entries
        .where((entry) => entry.value > 0)
        .toList(growable: false);
    final mealKinds = preview.mealLineMatchesByKind.entries
        .where((entry) => entry.value > 0)
        .toList(growable: false);
    String kindLabel(CatalogVersionChangeKind kind) => switch (kind) {
      CatalogVersionChangeKind.unchanged => copy('未变化', 'unchanged'),
      CatalogVersionChangeKind.added => copy('新增', 'added'),
      CatalogVersionChangeKind.deprecated => copy('明确退役', 'deprecated'),
      CatalogVersionChangeKind.remapped => copy('显式重映射', 'remapped'),
      CatalogVersionChangeKind.split => copy('拆分', 'split'),
      CatalogVersionChangeKind.merged => copy('合并', 'merged'),
      CatalogVersionChangeKind.ambiguous => copy('有歧义', 'ambiguous'),
      CatalogVersionChangeKind.unresolved => copy('未解决', 'unresolved'),
    };

    return Container(
      key: const Key('catalog-version-diff-food-impact-result'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy(
              '本机食物目录与餐次代码引用统计',
              'Local food-catalog and meal reference counts',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            copy(
              '食物目录条目：${preview.foodCatalogEntryCount} 项；来源系统与辖区可比较 ${preview.foodEntriesWithComparableSourceIdentity} 项；潜在变更代码引用 ${preview.foodEntriesWithPotentialChangedCodeMatch} 项；无可比较来源身份 ${preview.foodEntriesWithoutComparableSourceIdentity} 项。',
              'Food catalog entries: ${preview.foodCatalogEntryCount}; comparable source-system and jurisdiction identities: ${preview.foodEntriesWithComparableSourceIdentity}; potential changed-code references: ${preview.foodEntriesWithPotentialChangedCodeMatch}; no comparable source identity: ${preview.foodEntriesWithoutComparableSourceIdentity}.',
            ),
          ),
          Text(
            copy(
              '餐次：${preview.mealCount} 条；餐次食物行：${preview.mealLineCount} 条；来源身份可比较 ${preview.mealLinesWithComparableFoodIdentity} 条；潜在变更代码引用 ${preview.mealLinesWithPotentialChangedCodeMatch} 条，涉及 ${preview.mealsWithPotentialChangedCodeMatch} 条餐次；无可比较食物身份 ${preview.mealLinesWithoutComparableFoodIdentity} 条。',
              'Meals: ${preview.mealCount}; food lines: ${preview.mealLineCount}; comparable food identities: ${preview.mealLinesWithComparableFoodIdentity}; potential changed-code references: ${preview.mealLinesWithPotentialChangedCodeMatch} across ${preview.mealsWithPotentialChangedCodeMatch} meals; no comparable food identity: ${preview.mealLinesWithoutComparableFoodIdentity}.',
            ),
          ),
          if (foodKinds.isNotEmpty || mealKinds.isNotEmpty)
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                for (final entry in foodKinds)
                  Text(
                    '${copy('食物目录', 'food catalog')} ${kindLabel(entry.key)}: ${entry.value}',
                  ),
                for (final entry in mealKinds)
                  Text(
                    '${copy('餐次行', 'meal lines')} ${kindLabel(entry.key)}: ${entry.value}',
                  ),
              ],
            ),
          Text(
            copy(
              'FoodItem 与餐次行没有保存目录发行版；命中只是潜在关联，不是已确认受影响条目。统计仅使用精确来源代码并在内存中运行，只显示数量，不读取份量或修改记录。',
              'FoodItem and meal rows do not retain a catalog release; matches are potential references, not confirmed affected entries. This in-memory scan uses exact source codes, shows counts only, reads no serving quantities, and changes no records.',
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogVersionDiffResult extends StatelessWidget {
  const _CatalogVersionDiffResult({required this.diff, required this.chinese});

  final CatalogVersionChangeDiff diff;
  final bool chinese;

  @override
  Widget build(BuildContext context) {
    final changed = diff.entries
        .where((entry) => entry.kind != CatalogVersionChangeKind.unchanged)
        .toList(growable: false);
    final held = diff.entries.where((entry) => entry.holdBeforeApplying).length;
    final shown = changed.take(20).toList(growable: false);
    final counts = <CatalogVersionChangeKind, int>{
      for (final kind in CatalogVersionChangeKind.values)
        kind: diff.entries.where((entry) => entry.kind == kind).length,
    };
    String copy(String zh, String en) => chinese ? zh : en;
    String kindLabel(CatalogVersionChangeKind kind) => switch (kind) {
      CatalogVersionChangeKind.unchanged => copy('未变化', 'unchanged'),
      CatalogVersionChangeKind.added => copy('新增', 'added'),
      CatalogVersionChangeKind.deprecated => copy('明确退役', 'deprecated'),
      CatalogVersionChangeKind.remapped => copy('显式重映射', 'remapped'),
      CatalogVersionChangeKind.split => copy('拆分', 'split'),
      CatalogVersionChangeKind.merged => copy('合并', 'merged'),
      CatalogVersionChangeKind.ambiguous => copy('有歧义', 'ambiguous'),
      CatalogVersionChangeKind.unresolved => copy('未解决', 'unresolved'),
    };

    return Container(
      key: const Key('catalog-version-diff-result'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy(
              '${diff.entries.length} 条比较结果 · $held 条仍需持有人审阅',
              '${diff.entries.length} comparison entries · $held require owner review',
            ),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final kind in CatalogVersionChangeKind.values)
                if (counts[kind]! > 0)
                  Text('${kindLabel(kind)}: ${counts[kind]}'),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            copy('比较摘要哈希：', 'Diff content hash: ') + diff.sha256Digest,
          ),
          Text(
            copy(
              '未签名；只比较所提供的记录子集。新增项目和变更映射均不会自动应用。',
              'Unsigned; compares only supplied rows. Added entries and changed mappings are never applied automatically.',
            ),
          ),
          if (shown.isNotEmpty) ...[
            const Divider(height: 20),
            for (final entry in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(_entryLabel(entry, kindLabel, copy)),
              ),
            if (changed.length > shown.length)
              Text(
                copy(
                  '另有 ${changed.length - shown.length} 条变化未在此处展开。',
                  '${changed.length - shown.length} more changes are not expanded here.',
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _entryLabel(
    CatalogVersionChangeEntry entry,
    String Function(CatalogVersionChangeKind) kindLabel,
    String Function(String, String) copy,
  ) {
    final oldCode = entry.previousConcept?.code;
    final newCodes = entry.currentConcept == null
        ? entry.candidates.map((item) => item.code).toList(growable: false)
        : <String>[entry.currentConcept!.code];
    final identity = oldCode == null
        ? '+ ${newCodes.join(', ')}'
        : '$oldCode → ${newCodes.isEmpty ? '∅' : newCodes.join(', ')}';
    final held = entry.holdBeforeApplying
        ? copy(' · 暂停，需审阅', ' · held for review')
        : '';
    return '$identity · ${kindLabel(entry.kind)}$held';
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.report});

  final DataIntegrityReport report;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final requiresReview = report.requiresReview;
    final color = requiresReview
        ? Theme.of(context).colorScheme.tertiary
        : Theme.of(context).colorScheme.primary;
    return PaperCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            requiresReview ? Icons.rule_outlined : Icons.verified_outlined,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              i18n.tr(
                requiresReview ? 'decision.require_review' : 'common.done',
              ),
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntegritySection extends StatelessWidget {
  const _IntegritySection({
    required this.title,
    required this.icon,
    required this.coverage,
    required this.issues,
  });

  final String title;
  final IconData icon;
  final List<_CoverageDatum> coverage;
  final List<_IssueDatum> issues;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    return PaperCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (final datum in coverage) ...[
            Row(
              children: [
                Expanded(child: Text(datum.label)),
                Text(
                  datum.value == null
                      ? i18n.tr('common.not_available')
                      : '${datum.count}/${datum.total} '
                            '${(datum.value! * 100).round()}%',
                  style: const TextStyle(
                    fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: datum.value ?? 0,
              minHeight: 7,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: Paper.ink.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 14),
          ],
          const Divider(),
          for (final issue in issues)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                issue.count == 0
                    ? Icons.check_circle_outline
                    : Icons.info_outline,
                color: issue.count == 0
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.tertiary,
              ),
              title: Text(issue.label),
              trailing: Text('${issue.count}'),
            ),
        ],
      ),
    );
  }
}

class _CoverageDatum {
  const _CoverageDatum({
    required this.label,
    required this.value,
    required this.count,
    required this.total,
  });

  final String label;
  final double? value;
  final int count;
  final int total;
}

class _IssueDatum {
  const _IssueDatum({required this.label, required this.count});

  final String label;
  final int count;
}
