import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
import '../../core/models/meal_draft.dart';
import '../../domain/entities/food_serving_reference.dart';
import '../../domain/usecases/entry_food_portion_preview_service.dart';
import '../../domain/usecases/food_serving_reference_resolver.dart';
import 'food_portion_preview_dialog.dart';
import '../../core/state/app_state.dart';
import '../catalog/catalog_detail_pages.dart';
import '../shared/interaction_result_view.dart';

void _entryDebugLog(String message) {
  if (kDebugMode) {
    debugPrint(message);
  }
}

class EntryPage extends StatefulWidget {
  final Meal? initialMeal;
  final Meal? reuseMeal;

  const EntryPage({super.key, this.initialMeal, this.reuseMeal})
    : assert(initialMeal == null || reuseMeal == null);

  bool get isEditing => initialMeal != null;

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  MealDraft? _draft;
  AppState? _appState;
  String? _draftOwner;
  int? _draftSessionEpoch;
  bool _ownerInvalidated = false;
  int? _draftEditorEpoch;
  bool _editorSuperseded = false;
  bool _loadingDraft = true;
  bool _draftCompleted = false;
  bool _restoredDraft = false;
  String? _draftError;
  Timer? _checkpointTimer;
  bool get _isEditing => _draft?.editingMealId != null || widget.isEditing;
  late final TextEditingController _titleCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  static const int _searchResultPreviewLimit = 20;
  bool _showAllSearchResults = false;
  late List<MealItem> _items;
  bool _isSaving = false;
  bool _didLocalizeDefaultTitle = false;
  late DateTime _actualMealTime;
  bool _useApproximateWindow = false;
  DateTime? _mealWindowStart;
  DateTime? _mealWindowEnd;
  DateTime? _nextMealWindowStart;
  DateTime? _nextMealWindowEnd;
  DateTime? _coeventTime;
  bool _withIronSupplement = false;
  bool _withIronMultivitamin = false;
  String? _thickenerType;
  String? _enteralFeedMode;
  late final TextEditingController _enteralFeedFormulaCtrl;
  late final TextEditingController _enteralFeedProteinCtrl;

  @override
  void initState() {
    super.initState();
    final initialMeal = widget.initialMeal ?? widget.reuseMeal;
    // 初始标题跟随当前默认文案；后续 UI 会按 locale 实时翻译其它固定文本。
    _titleCtrl = TextEditingController(text: initialMeal?.title ?? '');
    _items = initialMeal == null
        ? <MealItem>[]
        : List<MealItem>.from(initialMeal.items);
    _actualMealTime =
        initialMeal?.occurredAt ??
        initialMeal?.effectiveOccurredAt ??
        DateTime.now();
    _useApproximateWindow = initialMeal?.timePrecision == 'interval';
    _mealWindowStart = initialMeal?.occurredRangeStart;
    _mealWindowEnd = initialMeal?.occurredRangeEnd;
    _nextMealWindowStart = initialMeal?.nextMealWindowStart;
    _nextMealWindowEnd = initialMeal?.nextMealWindowEnd;
    _coeventTime = initialMeal?.coeventTime;
    _withIronSupplement =
        initialMeal?.coeventSubstanceTags.contains('iron_salt') ?? false;
    _withIronMultivitamin =
        initialMeal?.coeventSubstanceTags.contains('multivitamin_with_iron') ??
        false;
    _thickenerType = initialMeal?.thickenerType;
    _enteralFeedMode = initialMeal?.enteralFeedMode;
    _enteralFeedFormulaCtrl = TextEditingController(
      text: initialMeal?.enteralFeedFormula ?? '',
    );
    _enteralFeedProteinCtrl = TextEditingController(
      text: initialMeal?.enteralFeedProteinGPerDay?.toStringAsFixed(0) ?? '',
    );
    _entryDebugLog(
      '[EntryPage] init mode=${widget.isEditing ? 'edit' : 'create'} items=${_items.length}',
    );
  }

  @override
  void dispose() {
    _checkpointTimer?.cancel();
    if (!_draftCompleted && !_loadingDraft) {
      unawaited(_checkpoint());
    }
    _appState?.removeListener(_observeOwner);
    _titleCtrl.dispose();
    _searchCtrl.dispose();
    _enteralFeedFormulaCtrl.dispose();
    _enteralFeedProteinCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_appState == null) {
      _appState = context.read<AppState>();
      _draftOwner = _appState!.currentUserId;
      _draftSessionEpoch = _appState!.mealDraftSessionEpoch;
      _appState!.addListener(_observeOwner);
      unawaited(_initializeDraft());
    }
    // 初次进入创建页时，把默认标题同步成当前语言。
    if (!_didLocalizeDefaultTitle &&
        widget.initialMeal == null &&
        widget.reuseMeal == null) {
      _titleCtrl.text = context.appI18n.tr('entry.default_meal_title');
      _didLocalizeDefaultTitle = true;
    }
  }

  Future<void> _saveMeal() async {
    _entryDebugLog(
      '[EntryPage] save:pressed items=${_items.length} mounted=$mounted',
    );

    final i18n = context.appI18n;
    if (_isSaving) {
      _entryDebugLog('[EntryPage] save:ignored duplicate tap');
      return;
    }

    if (_items.isEmpty) {
      _entryDebugLog('[EntryPage] save:blocked empty-items');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(i18n.tr('entry.add_food_first'))));
      return;
    }

    final appState = context.read<AppState>();
    final owner = _draftOwner;
    if (_ownerInvalidated || owner == null || owner != appState.currentUserId) {
      return;
    }
    _checkpointTimer?.cancel();
    final meal = _captureMeal();
    final draft = _draft!.copyWith(meal: meal, updatedAt: DateTime.now());
    if (!draft.readyToSave) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.languageFamily == 'zh'
                ? '请确认本次进食时间与每项份量。'
                : 'Confirm this meal time and each quantity before saving.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      _entryDebugLog('[EntryPage] save:checking');
      final result = await appState.checkMeal(meal);
      _entryDebugLog(
        '[EntryPage] save:checkResult score=${result.score} severity=${result.overallSeverity?.name ?? 'unassessed'}',
      );

      final mutation = await appState.saveMealDraft(
        draft,
        owner: owner,
        editorEpoch: _draftEditorEpoch,
      );
      if (mutation.shouldReportSaveFailure) {
        _entryDebugLog(
          '[EntryPage] save:not_committed status=${mutation.status.name}',
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              i18n.tr('entry.save_failed', {'error': i18n.tr('common.error')}),
            ),
          ),
        );
        return;
      }
      if (_isEditing) {
        _entryDebugLog('[EntryPage] save:updateMeal start');
      } else {
        _entryDebugLog('[EntryPage] save:addMeal start');
      }
      _entryDebugLog(
        '[EntryPage] save:persisted status=${mutation.status.name}',
      );

      if (!mounted || _ownerInvalidated || _editorSuperseded) return;

      _draftCompleted = true;
      _entryDebugLog('[EntryPage] save:showDialog');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(
            _isEditing
                ? i18n.tr('entry.updated_title')
                : i18n.tr('entry.saved_title'),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: InteractionSummaryCard(result: result),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(i18n.tr('common.done')),
            ),
          ],
        ),
      );
      _entryDebugLog('[EntryPage] save:dialog closed');

      if (!mounted) return;
      Navigator.of(context).pop();
      _entryDebugLog('[EntryPage] save:navigate back');
    } catch (error, stackTrace) {
      _entryDebugLog('[EntryPage] save:error ${error.runtimeType}');
      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n.tr('entry.save_failed', {'error': i18n.tr('common.error')}),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _observeOwner() {
    if (!mounted || _ownerInvalidated || _editorSuperseded) return;
    if (_draftEditorEpoch != null &&
        _draftEditorEpoch != _appState?.mealDraftEditorEpoch) {
      _checkpointTimer?.cancel();
      _draftCompleted = true;
      setState(() => _editorSuperseded = true);
      return;
    }
    if (_draftOwner == _appState?.currentUserId &&
        _draftSessionEpoch == _appState?.mealDraftSessionEpoch) {
      return;
    }
    _checkpointTimer?.cancel();
    _draftCompleted = true;
    setState(() {
      _ownerInvalidated = true;
      _items = [];
    });
  }

  Future<void> _initializeDraft() async {
    final state = _appState!;
    final owner = _draftOwner;
    if (owner == null) {
      if (mounted) setState(() => _loadingDraft = false);
      return;
    }
    try {
      MealDraft draft;
      final saved = await state.loadMealDraft(owner: owner);
      if (!mounted || _ownerInvalidated || owner != state.currentUserId) return;
      var resumeSaved = widget.initialMeal == null && widget.reuseMeal == null;
      if (!resumeSaved && saved != null && saved.meal.items.isNotEmpty) {
        final zh = context.appI18n.languageFamily == 'zh';
        final choice = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(zh ? '已有未完成草稿' : 'An unfinished draft is saved'),
            content: Text(
              zh
                  ? '“${saved.meal.title}”尚未保存为餐食。请选择恢复草稿，或开始本次所选新草稿。'
                  : '“${saved.meal.title}” has not been saved as a meal. Resume it or start the newly selected draft.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop('cancel'),
                child: Text(context.appI18n.tr('common.cancel')),
              ),
              TextButton(
                key: const Key('entry-replace-existing-draft'),
                onPressed: () => Navigator.of(dialogContext).pop('replace'),
                child: Text(zh ? '开始所选新草稿' : 'Start selected draft'),
              ),
              FilledButton(
                key: const Key('entry-resume-existing-draft'),
                onPressed: () => Navigator.of(dialogContext).pop('resume'),
                child: Text(zh ? '恢复已有草稿' : 'Resume saved draft'),
              ),
            ],
          ),
        );
        if (!mounted || _ownerInvalidated || owner != state.currentUserId) {
          return;
        }
        if (choice == null || choice == 'cancel') {
          Navigator.of(context).pop();
          return;
        }
        resumeSaved = choice == 'resume';
      }
      _draftEditorEpoch = state.claimMealDraftEditor(owner: owner);
      if (resumeSaved && saved != null) {
        draft = saved;
        _restoredDraft = true;
      } else if (widget.reuseMeal != null) {
        draft = state.reuseMealAsDraft(widget.reuseMeal!);
      } else if (widget.initialMeal != null) {
        draft = MealDraft(
          draftId: state.newId('meal_draft'),
          meal: widget.initialMeal!,
          editingMealId: widget.initialMeal!.id,
          updatedAt: DateTime.now(),
        );
      } else {
        draft = MealDraft(
          draftId: state.newId('meal_draft'),
          meal: Meal(
            id: state.newId('meal'),
            title: _titleCtrl.text,
            eatenAt: _actualMealTime,
            recordedAt: DateTime.now(),
            occurredAt: _actualMealTime,
            items: [],
          ),
          updatedAt: DateTime.now(),
        );
      }
      if (!mounted || owner != state.currentUserId) return;
      setState(() {
        _draft = draft;
        _applyDraft(draft);
        _loadingDraft = false;
      });
      _titleCtrl.addListener(_queueDraftSave);
      _enteralFeedFormulaCtrl.addListener(_queueDraftSave);
      _enteralFeedProteinCtrl.addListener(_queueDraftSave);
      await _checkpoint();
    } catch (_) {
      if (mounted) {
        setState(() {
          _loadingDraft = false;
          _draftError = 'load';
        });
      }
    }
  }

  Future<void> _discardDraftAndStartNew() async {
    final state = _appState!;
    final owner = _draftOwner;
    if (owner == null || owner != state.currentUserId || _draft == null) return;
    _checkpointTimer?.cancel();
    try {
      await state.discardMealDraft(
        _draft!.draftId,
        owner: owner,
        editorEpoch: _draftEditorEpoch,
      );
      if (!mounted || owner != state.currentUserId) return;
      final now = DateTime.now();
      final next = MealDraft(
        draftId: state.newId('meal_draft'),
        updatedAt: now,
        meal: Meal(
          id: state.newId('meal'),
          title: context.appI18n.tr('entry.default_meal_title'),
          eatenAt: now,
          recordedAt: now,
          occurredAt: now,
          items: [],
        ),
      );
      setState(() {
        _draft = next;
        _applyDraft(next);
        _restoredDraft = false;
        _draftError = null;
      });
      await _checkpoint();
    } catch (_) {
      if (mounted) setState(() => _draftError = 'save');
    }
  }

  void _applyDraft(MealDraft draft) {
    final meal = draft.meal;
    _titleCtrl.text = meal.title;
    _items = List<MealItem>.of(meal.items);
    _actualMealTime = meal.effectiveOccurredAt;
    _useApproximateWindow = meal.timePrecision == 'interval';
    _mealWindowStart = meal.occurredRangeStart;
    _mealWindowEnd = meal.occurredRangeEnd;
    _nextMealWindowStart = meal.nextMealWindowStart;
    _nextMealWindowEnd = meal.nextMealWindowEnd;
    _coeventTime = meal.coeventTime;
    _withIronSupplement = meal.coeventSubstanceTags.contains('iron_salt');
    _withIronMultivitamin = meal.coeventSubstanceTags.contains(
      'multivitamin_with_iron',
    );
    _thickenerType = meal.thickenerType;
    _enteralFeedMode = meal.enteralFeedMode;
    _enteralFeedFormulaCtrl.text = meal.enteralFeedFormula ?? '';
    _enteralFeedProteinCtrl.text =
        meal.enteralFeedProteinGPerDay?.toString() ?? '';
  }

  Meal _captureMeal() {
    final i18n = AppI18n.fromLocaleTag(_appState!.userProfile.displayLocale);
    final title = _titleCtrl.text.trim().isEmpty
        ? i18n.tr('entry.default_meal_title')
        : _titleCtrl.text.trim();
    final now = DateTime.now();
    final normalizedMealWindowStart = _useApproximateWindow
        ? (_mealWindowStart ?? _actualMealTime)
        : null;
    final normalizedMealWindowEnd = _useApproximateWindow
        ? (_mealWindowEnd ??
              (_mealWindowStart ?? _actualMealTime).add(
                const Duration(minutes: 20),
              ))
        : null;
    final coeventSubstanceTags = <String>[
      if (_withIronSupplement) 'iron_salt',
      if (_withIronMultivitamin) 'multivitamin_with_iron',
    ];
    final effectiveOccurredAt = _useApproximateWindow
        ? normalizedMealWindowStart!
        : _actualMealTime;
    return Meal(
      id: _draft?.meal.id ?? widget.initialMeal!.id,
      title: title,
      // 向后兼容字段 eatenAt 仍写“实际发生时间的代表点”。
      eatenAt: effectiveOccurredAt,
      recordedAt:
          _draft?.meal.recordedAt ?? widget.initialMeal?.recordedAt ?? now,
      occurredAt: _useApproximateWindow ? null : _actualMealTime,
      occurredRangeStart: normalizedMealWindowStart,
      occurredRangeEnd: normalizedMealWindowEnd,
      timeSource: _useApproximateWindow ? 'user_interval' : 'user_exact',
      timePrecision: _useApproximateWindow ? 'interval' : 'exact',
      nextMealWindowStart: _nextMealWindowStart,
      nextMealWindowEnd: _nextMealWindowEnd,
      coeventTime: _hasCoeventContext
          ? (_coeventTime ?? effectiveOccurredAt)
          : null,
      coeventSubstanceTags: coeventSubstanceTags,
      thickenerType: _thickenerType,
      enteralFeedMode: _enteralFeedMode,
      enteralFeedFormula: _enteralFeedFormulaCtrl.text.trim().isEmpty
          ? null
          : _enteralFeedFormulaCtrl.text.trim(),
      enteralFeedProteinGPerDay: double.tryParse(
        _enteralFeedProteinCtrl.text.trim(),
      ),
      items: List<MealItem>.from(_items),
    );
  }

  void _queueDraftSave() {
    if (_draftCompleted || _loadingDraft || _draft == null) return;
    _checkpointTimer?.cancel();
    _checkpointTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_checkpoint()),
    );
  }

  Future<void> _checkpoint() async {
    final state = _appState;
    final owner = _draftOwner;
    if (_draftCompleted ||
        _draft == null ||
        state == null ||
        owner == null ||
        owner != state.currentUserId) {
      return;
    }
    final next = _draft!.copyWith(
      meal: _captureMeal(),
      updatedAt: DateTime.now(),
    );
    _draft = next;
    try {
      await state.persistMealDraft(
        next,
        owner: owner,
        editorEpoch: _draftEditorEpoch,
      );
      if (mounted && _draftError == 'save') {
        setState(() => _draftError = null);
      }
    } catch (_) {
      if (mounted) setState(() => _draftError = 'save');
    }
  }

  void _inputsChanged({bool quantity = false, bool time = false}) {
    if (_draft != null) {
      _draft = _draft!.copyWith(
        timeConfirmed: time ? false : null,
        quantitiesConfirmed: quantity ? false : null,
      );
    }
    _queueDraftSave();
  }

  Future<void> _showPortionPreview(int index) async {
    final state = context.read<AppState>();
    final inputRevision = state.derivedResultInputRevision;
    final sessionEpoch = state.mealDraftSessionEpoch;
    final editorEpoch = state.mealDraftEditorEpoch;
    final item = _items[index];
    bool current() =>
        mounted &&
        !_ownerInvalidated &&
        !_editorSuperseded &&
        _draftOwner == state.currentUserId &&
        sessionEpoch == state.mealDraftSessionEpoch &&
        editorEpoch == state.mealDraftEditorEpoch &&
        inputRevision == state.derivedResultInputRevision &&
        index < _items.length &&
        identical(item, _items[index]);
    final food = state.services.foodRepository.allFoods
        .where((food) => food.id == _items[index].foodId)
        .firstOrNull;
    if (food == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.appI18n.languageFamily == 'zh'
                ? '当前目录缺少此食物；份量预览不可用。'
                : 'This food is missing from the current catalogue; portion preview is unavailable.',
          ),
        ),
      );
      return;
    }
    final grams = await showDialog<double>(
      context: context,
      builder: (_) => FoodPortionPreviewDialog(
        sourceChanges: state,
        isCurrent: current,
        future:
            EntryFoodPortionPreviewService(
              projectionService: state.services.cdssCatalogProjectionService,
            ).load(
              food: food,
              registrationRegion: state.userProfile.registrationRegion,
            ),
      ),
    );
    if (!mounted || grams == null) return;
    if (!current()) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.appI18n.languageFamily == 'zh'
                ? '来源目录已变化；请重新打开份量预览。'
                : 'The source catalogue changed. Reopen the portion preview.',
          ),
        ),
      );
      return;
    }
    _updateItemQuantity(index, grams / 100);
  }

  /// Adds [food] at its reference serving (source portion, else category
  /// reference amount), or at 100 g when it has none. The amount stays
  /// editable on the added-food card.
  void _addCatalogFood(FoodItem food) {
    final serving = foodServingReferenceFor(food);
    _addFood(
      MealItem.fromFood(
        food: food,
        quantityFactor: serving.evaluatedGrams / 100,
      ),
      amount: serving.hasServing
          ? _servingAmount(context.appI18n, serving)
          : context.appI18n.tr('food_display.serving_grams', {'grams': '100'}),
    );
  }

  void _addFood(MealItem item, {required String amount}) {
    final i18n = context.appI18n;
    final localizedFoodName = i18n.foodName(item.foodId, item.foodName);
    setState(() {
      // 已存量数据仍可能保留旧语言 foodName；新加入条目在 UI 层先写入当前语言显示名。
      _items = [..._items, item.copyWith(foodName: localizedFoodName)];
    });
    _inputsChanged(quantity: true);
    _entryDebugLog(
      '[EntryPage] addFood items=${_items.length} grams=${item.grams.toStringAsFixed(1)}',
    );
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          key: const ValueKey('entry-food-added-feedback'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 110),
          content: Text(
            i18n.tr('food_display.added_feedback', {
              'name': localizedFoodName,
              'amount': amount,
            }),
          ),
          duration: const Duration(milliseconds: 2500),
        ),
      );
  }

  void _updateItemQuantity(int index, double nextFactor) {
    if (!nextFactor.isFinite) return;
    final clampedFactor = nextFactor < 0.01 ? 0.01 : nextFactor;
    setState(() {
      _items = [
        for (var i = 0; i < _items.length; i++)
          if (i == index)
            _items[i].copyWith(quantityFactor: clampedFactor)
          else
            _items[i],
      ];
    });
    _inputsChanged(quantity: true);
    _entryDebugLog(
      '[EntryPage] updateQuantity index=$index factor=${clampedFactor.toStringAsFixed(2)}',
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items = [..._items]..removeAt(index);
    });
    _inputsChanged(quantity: true);
    _entryDebugLog('[EntryPage] removeFood items=${_items.length}');
  }

  Future<void> _showQuantityEditor(int index) async {
    final current = _items[index];
    final i18n = context.appI18n;
    var grams = current.grams;
    final controller = TextEditingController(text: grams.toStringAsFixed(0));

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final factor = grams / 100;
            final protein = _itemNutrientValue(
              current,
              'proteinG',
              current.proteinPer100g * factor,
            );
            final carbs = _itemNutrientValue(
              current,
              'carbsG',
              current.carbsPer100g * factor,
            );

            void updateGrams(double value) {
              final safeValue = value < 1 ? 1.0 : value;
              setDialogState(() {
                grams = safeValue;
                controller.text = safeValue.toStringAsFixed(0);
              });
            }

            return AlertDialog(
              title: Text(
                i18n.tr('entry.adjust_quantity', {
                  'name': i18n.foodName(current.foodId, current.foodName),
                }),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: i18n.tr('entry.grams'),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        final parsed = double.tryParse(value);
                        if (parsed != null && parsed.isFinite && parsed > 0) {
                          setDialogState(() => grams = parsed);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    Text(
                      i18n.tr('entry.quantity_factor', {
                        'value': factor.toStringAsFixed(2),
                      }),
                    ),
                    Slider(
                      value: grams.clamp(25.0, 500.0).toDouble(),
                      min: 25,
                      max: 500,
                      divisions: 19,
                      label: '${grams.toStringAsFixed(0)}g',
                      onChanged: updateGrams,
                    ),
                    const SizedBox(height: 8),
                    Text(_nutrientText(i18n, 'food_display.protein', protein)),
                    Text(_nutrientText(i18n, 'food_display.carbs', carbs)),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(i18n.tr('common.cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    final parsed = double.tryParse(controller.text);
                    if (parsed == null || !parsed.isFinite || parsed <= 0) {
                      return;
                    }
                    _updateItemQuantity(index, parsed / 100);
                    Navigator.of(dialogContext).pop();
                  },
                  child: Text(i18n.tr('common.apply')),
                ),
              ],
            );
          },
        );
      },
    );

    controller.dispose();
  }

  String _formatTotals(AppI18n i18n) {
    final meal = Meal(
      id: 'preview',
      eatenAt: DateTime.now(),
      title: _titleCtrl.text,
      items: _items,
    );
    final totals = meal.computeTotals();
    return [
      _nutrientText(
        i18n,
        'food_display.protein',
        _totalValue('proteinG', totals.totalProteinG),
      ),
      _nutrientText(
        i18n,
        'food_display.carbs',
        _totalValue('carbsG', totals.totalCarbsG),
      ),
      _nutrientText(
        i18n,
        'food_display.fat',
        _totalValue('fatG', totals.totalFatG),
      ),
    ].join(' · ');
  }

  FoodItem? _catalogFood(String foodId) => _appState!
      .services
      .foodRepository
      .allFoods
      .where((food) => food.id == foodId)
      .firstOrNull;

  /// Meal total for [field], or null when any item lacks it.
  double? _totalValue(String field, double value) {
    final missing = _items.any((item) {
      final food = _catalogFood(item.foodId);
      return item.isNutrientMissing(field) ||
          food == null ||
          food.isNutrientMissing(field);
    });
    return missing ? null : value;
  }

  /// Item amount of [field], or null when the item or its catalogue food
  /// marks it missing.
  double? _itemNutrientValue(MealItem item, String field, double value) {
    final food = _catalogFood(item.foodId);
    return item.isNutrientMissing(field) ||
            food == null ||
            food.isNutrientMissing(field)
        ? null
        : value;
  }

  /// "Protein 3.2 g", or "Protein unknown" for a missing or invalid value.
  String _nutrientText(AppI18n i18n, String labelKey, double? value) {
    final nutrient = i18n.tr(labelKey);
    if (value == null || !value.isFinite || value < 0) {
      return i18n.tr('food_display.amount_unknown', {'nutrient': nutrient});
    }
    return i18n.tr('food_display.amount_grams', {
      'nutrient': nutrient,
      'value': value.toStringAsFixed(1),
    });
  }

  /// Per-100 g line of a catalogue food in search results.
  String _per100gLine(AppI18n i18n, FoodItem food) {
    double? value(String field, double raw) =>
        food.isNutrientMissing(field) ? null : raw;
    return i18n.tr('food_display.per_100g', {
      'values': [
        _nutrientText(
          i18n,
          'food_display.protein',
          value('proteinG', food.proteinG),
        ),
        _nutrientText(i18n, 'food_display.carbs', value('carbsG', food.carbsG)),
        _nutrientText(i18n, 'food_display.fat', value('fatG', food.fatG)),
        _nutrientText(i18n, 'food_display.fiber', value('fiberG', food.fiberG)),
      ].join(' · '),
    });
  }

  static String _formatGrams(double grams) => grams == grams.roundToDouble()
      ? grams.toStringAsFixed(0)
      : grams.toStringAsFixed(1);

  /// "1 cup, 244 g" for a source portion; "85 g" for a category amount.
  /// Source household measures are English text, so other languages show
  /// the grams only.
  String _servingAmount(AppI18n i18n, FoodServingReference serving) {
    final grams = _formatGrams(serving.evaluatedGrams);
    final portion = serving.portionLabel;
    if (i18n.languageFamily == 'en' &&
        serving.basis == FoodServingBasis.sourcePortion &&
        portion != null &&
        portion.trim().isNotEmpty) {
      return i18n.tr('food_display.serving_portion', {
        'portion': portion.trim(),
        'grams': grams,
      });
    }
    return i18n.tr('food_display.serving_grams', {'grams': grams});
  }

  String _servingBasisLabel(AppI18n i18n, FoodServingReference serving) =>
      i18n.tr(
        serving.basis == FoodServingBasis.sourcePortion
            ? 'serving.basis.source_portion'
            : 'serving.basis.category_default',
      );

  /// What a search result adds: its reference serving and basis, or 100 g.
  String _defaultAmountLine(AppI18n i18n, FoodItem food) {
    final serving = foodServingReferenceFor(food);
    if (!serving.hasServing) return i18n.tr('food_display.adds_per_100g');
    return i18n.tr('food_display.adds_serving', {
      'amount': _servingAmount(i18n, serving),
      'basis': _servingBasisLabel(i18n, serving),
    });
  }

  /// Amount line of an added food: its reference serving with the basis, the
  /// unlabelled 100 g default, or an amount the user set.
  String _itemAmountLine(AppI18n i18n, MealItem item) {
    final grams = item.grams;
    final food = _catalogFood(item.foodId);
    if (food != null) {
      final serving = foodServingReferenceFor(food);
      final servingGrams = serving.grams;
      if (servingGrams != null && (grams - servingGrams).abs() < 0.05) {
        return i18n.tr('food_display.item_serving', {
          'amount': _servingAmount(i18n, serving),
          'basis': _servingBasisLabel(i18n, serving),
        });
      }
      if (servingGrams == null && (grams - 100).abs() < 0.05) {
        return i18n.tr('food_display.item_per_100g');
      }
    }
    return i18n.tr('food_display.item_custom', {'grams': _formatGrams(grams)});
  }

  /// Readable source of a catalogue food, e.g. "USDA FoodData Central ·
  /// United States". Codes and provenance stay on the detail page.
  String _sourceLine(AppI18n i18n, FoodItem food) => [
    i18n.sourceSystemLabel(food.sourceSystem),
    if (food.jurisdiction.trim().isNotEmpty)
      i18n.regionLabel(food.jurisdiction),
  ].join(' · ');

  String _moreContextSummary(AppI18n i18n) {
    final set = [
      if (_withIronSupplement) i18n.tr('entry.with_iron_supplement'),
      if (_withIronMultivitamin) i18n.tr('entry.with_iron_multivitamin'),
      if (_thickenerType != null) i18n.tr('entry.thickener_$_thickenerType'),
      if (_enteralFeedMode != null)
        i18n.tr('entry.enteral_feed_$_enteralFeedMode'),
    ];
    return set.isEmpty
        ? i18n.tr('food_display.more_context_hint')
        : i18n.tr('food_display.more_context_set', {'items': set.join('; ')});
  }

  List<Widget> _foodSearchResults(AppI18n i18n, List<FoodItem> foods) {
    if (_searchCtrl.text.trim().isEmpty) {
      return [
        Text(
          i18n.tr('food_display.search_hint'),
          key: const ValueKey('entry-food-search-hint'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ];
    }
    if (foods.isEmpty) {
      return [
        Card(
          key: const ValueKey('entry-food-search-results'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(i18n.tr('common.no_matching_foods')),
          ),
        ),
      ];
    }
    final shown = _showAllSearchResults
        ? foods
        : foods.take(_searchResultPreviewLimit).toList(growable: false);
    final addedCounts = <String, int>{};
    for (final item in _items) {
      addedCounts[item.foodId] = (addedCounts[item.foodId] ?? 0) + 1;
    }
    return [
      Text(
        i18n.tr('food_display.results_count', {'count': '${foods.length}'}),
        key: const ValueKey('entry-food-search-results'),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      for (final food in shown)
        Card(
          key: ValueKey('entry-food-result-${food.id}'),
          child: Builder(
            builder: (context) {
              final textureLine = _foodTextureLine(i18n, food);
              final added = addedCounts[food.id] ?? 0;
              return ListTile(
                title: Text(i18n.foodName(food.id, food.name)),
                subtitle: Text(
                  [
                    _per100gLine(i18n, food),
                    _defaultAmountLine(i18n, food),
                    _sourceLine(i18n, food),
                    ?textureLine,
                  ].join('\n'),
                ),
                isThreeLine: true,
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    IconButton(
                      tooltip: i18n.tr('entry.view_food_detail'),
                      onPressed: () => _openFoodDetail(food),
                      icon: const Icon(Icons.info_outline),
                    ),
                    IconButton(
                      key: ValueKey('entry-add-food-${food.id}'),
                      tooltip: i18n.tr('entry.add_food'),
                      onPressed: () => _addCatalogFood(food),
                      icon: Badge(
                        isLabelVisible: added > 0,
                        label: Text('$added'),
                        child: Icon(
                          added > 0
                              ? Icons.check_circle
                              : Icons.add_circle_outline,
                          semanticLabel: added > 0
                              ? i18n.tr('food_display.added_badge', {
                                  'count': '$added',
                                })
                              : null,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      if (shown.length < foods.length)
        TextButton(
          key: const ValueKey('entry-food-search-show-more'),
          onPressed: () => setState(() => _showAllSearchResults = true),
          child: Text(
            i18n.tr('food_display.show_more_results', {
              'count': '${foods.length - shown.length}',
            }),
          ),
        ),
    ];
  }

  String? _foodTextureLine(AppI18n i18n, FoodItem food) {
    if (food.textureClass == null && food.iddsiLevel == null) {
      return null;
    }
    return i18n.foodTextureSummary(
      textureClass: food.textureClass,
      iddsiLevel: food.iddsiLevel,
    );
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return null;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (pickedTime == null) return null;
    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }

  Future<void> _editExactMealTime() async {
    final picked = await _pickDateTime(_actualMealTime);
    if (picked == null) return;
    setState(() {
      _actualMealTime = picked;
      if (!_useApproximateWindow) {
        _mealWindowStart = null;
        _mealWindowEnd = null;
      }
    });
    _inputsChanged(time: true);
  }

  Future<void> _editMealWindow() async {
    final start = await _pickDateTime(_mealWindowStart ?? _actualMealTime);
    if (start == null || !mounted) return;
    final end = await _pickDateTime(
      _mealWindowEnd != null && _mealWindowEnd!.isAfter(start)
          ? _mealWindowEnd!
          : start.add(const Duration(minutes: 20)),
    );
    if (end == null) return;
    final normalizedEnd = end.isBefore(start) ? start : end;
    setState(() {
      _mealWindowStart = start;
      _mealWindowEnd = normalizedEnd;
      _actualMealTime = start;
    });
    _inputsChanged(time: true);
  }

  Future<void> _editNextMealWindow() async {
    final base =
        _nextMealWindowStart ?? _actualMealTime.add(const Duration(hours: 5));
    final start = await _pickDateTime(base);
    if (start == null || !mounted) return;
    final end = await _pickDateTime(
      _nextMealWindowEnd != null && _nextMealWindowEnd!.isAfter(start)
          ? _nextMealWindowEnd!
          : start.add(const Duration(hours: 1)),
    );
    if (end == null) return;
    setState(() {
      _nextMealWindowStart = start;
      _nextMealWindowEnd = end.isBefore(start) ? start : end;
    });
    _inputsChanged();
  }

  bool get _hasCoeventContext =>
      _withIronSupplement || _withIronMultivitamin || _thickenerType != null;

  bool get _hasEnteralFeedContext => _enteralFeedMode != null;

  Future<void> _editCoeventTime() async {
    final picked = await _pickDateTime(_coeventTime ?? _actualMealTime);
    if (picked == null) return;
    setState(() {
      _coeventTime = picked;
    });
    _inputsChanged();
  }

  String _formatDateTime(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  Future<void> _openFoodDetail(FoodItem food) async {
    final state = context.read<AppState>();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FoodDetailPage(
          food: food,
          future: state.services.cdssCatalogProjectionService.projectFoodDetail(
            food,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final appState = context.read<AppState>();
    final foods = appState.catalogEngine.searchFoods(_searchCtrl.text);
    if (_editorSuperseded) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              i18n.languageFamily == 'zh'
                  ? '已在另一录入页面继续。请重新打开以恢复最新草稿。'
                  : 'Meal entry continued in another page. Reopen to restore the latest draft.',
            ),
          ),
        ),
      );
    }
    if (_ownerInvalidated ||
        _draftOwner != appState.currentUserId ||
        _draftOwner == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            i18n.languageFamily == 'zh'
                ? '账户已切换；请重新打开录入页面。'
                : 'The account changed. Reopen meal entry.',
          ),
        ),
      );
    }
    if (_loadingDraft) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_draft == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Text(
            i18n.languageFamily == 'zh'
                ? '草稿无法恢复；原草稿保持保留。'
                : 'The draft could not be restored. The stored draft is retained.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? i18n.tr('entry.edit_title') : i18n.tr('entry.new_title'),
        ),
        actions: [
          IconButton(
            key: const Key('entry-discard-draft'),
            tooltip: i18n.languageFamily == 'zh'
                ? '丢弃草稿并开始新餐'
                : 'Discard draft and start a new meal',
            icon: const Icon(Icons.restart_alt),
            onPressed: _isSaving ? null : _discardDraftAndStartNew,
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _isSaving,
        child: ListView(
          key: const Key('entry-form-list'),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
          children: [
            if (_restoredDraft || _draftError != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _draftError != null
                        ? (i18n.languageFamily == 'zh'
                              ? '草稿保存失败。请保留页面并重试。'
                              : 'Draft checkpoint failed. Keep this page open and retry.')
                        : (i18n.languageFamily == 'zh'
                              ? '已恢复本账户草稿；保存时按当前输入重新检查。'
                              : 'This account’s draft was restored. Saving checks the current inputs again.'),
                  ),
                ),
              ),
            if (_draft!.requiresConfirmation) ...[
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        i18n.languageFamily == 'zh'
                            ? '已从历史餐创建新草稿。请确认本次时间和每项份量；历史记录保持不变。'
                            : 'A new draft was created from history. Confirm the new meal time and each quantity; the historical record is retained.',
                      ),
                    ),
                    CheckboxListTile(
                      key: const Key('entry-confirm-time'),
                      title: Text(
                        i18n.languageFamily == 'zh'
                            ? '确认本次进食时间'
                            : 'Confirm this meal time',
                      ),
                      value: _draft!.timeConfirmed,
                      onChanged: (value) {
                        setState(
                          () => _draft = _draft!.copyWith(
                            timeConfirmed: value ?? false,
                          ),
                        );
                        _queueDraftSave();
                      },
                    ),
                    CheckboxListTile(
                      key: const Key('entry-confirm-quantities'),
                      title: Text(
                        i18n.languageFamily == 'zh'
                            ? '已核对每项食物的克数'
                            : 'I checked the grams for each food',
                      ),
                      value: _draft!.quantitiesConfirmed,
                      onChanged: (value) {
                        setState(
                          () => _draft = _draft!.copyWith(
                            quantitiesConfirmed: value ?? false,
                          ),
                        );
                        _queueDraftSave();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              key: const ValueKey('entry-title-field'),
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: i18n.tr('entry.meal_title'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('entry-food-search'),
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: i18n.tr('entry.search_food'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _showAllSearchResults = false),
            ),
            const SizedBox(height: 12),
            ..._foodSearchResults(i18n, foods),
            const SizedBox(height: 12),
            Text(
              i18n.tr('entry.added_foods'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              i18n.tr('food_display.serving_note'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            if (_items.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(i18n.tr('entry.add_food_prompt')),
                ),
              ),
            for (var i = 0; i < _items.length; i++)
              Card(
                key: ValueKey('entry-added-food-$i'),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              i18n.foodName(
                                _items[i].foodId,
                                _items[i].foodName,
                              ),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: i18n.tr('common.delete'),
                            onPressed: () => _removeItem(i),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      Text(
                        _itemAmountLine(i18n, _items[i]),
                        key: ValueKey('entry-added-food-amount-$i'),
                      ),
                      Text(
                        [
                          _nutrientText(
                            i18n,
                            'food_display.protein',
                            _itemNutrientValue(
                              _items[i],
                              'proteinG',
                              _items[i].proteinG,
                            ),
                          ),
                          _nutrientText(
                            i18n,
                            'food_display.carbs',
                            _itemNutrientValue(
                              _items[i],
                              'carbsG',
                              _items[i].carbsG,
                            ),
                          ),
                        ].join(' · '),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: [
                          IconButton(
                            tooltip: i18n.tr('food_display.decrease_25g'),
                            onPressed: () => _updateItemQuantity(
                              i,
                              _items[i].quantityFactor - 0.25,
                            ),
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text(
                            i18n.tr('food_display.serving_grams', {
                              'grams': _formatGrams(_items[i].grams),
                            }),
                          ),
                          IconButton(
                            tooltip: i18n.tr('food_display.increase_25g'),
                            onPressed: () => _updateItemQuantity(
                              i,
                              _items[i].quantityFactor + 0.25,
                            ),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                          const SizedBox(width: 8),
                          OutlinedButton(
                            onPressed: () => _showQuantityEditor(i),
                            child: Text(i18n.tr('entry.set_quantity')),
                          ),
                          OutlinedButton(
                            key: ValueKey('entry-portion-preview-$i'),
                            onPressed: () => _showPortionPreview(i),
                            child: Text(
                              i18n.languageFamily == 'zh'
                                  ? '来源份量与缺失信息'
                                  : 'Source portion and missing data',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.tr('entry.summary'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _items.isEmpty
                          ? i18n.tr('entry.no_foods_yet')
                          : _formatTotals(i18n),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.tr('entry.actual_meal_time'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      i18n.tr('entry.recorded_time_hint', {
                        'value': _formatDateTime(
                          widget.initialMeal?.recordedAt ?? DateTime.now(),
                        ),
                      }),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      i18n.tr('entry.actual_time_value', {
                        'value': _formatDateTime(_actualMealTime),
                      }),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _editExactMealTime,
                          child: Text(i18n.tr('entry.edit_actual_time')),
                        ),
                        FilterChip(
                          label: Text(i18n.tr('entry.time_uncertain')),
                          selected: _useApproximateWindow,
                          onSelected: (selected) {
                            setState(() {
                              _useApproximateWindow = selected;
                              if (!selected) {
                                _mealWindowStart = null;
                                _mealWindowEnd = null;
                              }
                            });
                            _inputsChanged(time: true);
                          },
                        ),
                      ],
                    ),
                    if (_useApproximateWindow) ...[
                      const SizedBox(height: 8),
                      Text(
                        i18n.tr('entry.actual_window_value', {
                          'start': _mealWindowStart == null
                              ? '--'
                              : _formatDateTime(_mealWindowStart!),
                          'end': _mealWindowEnd == null
                              ? '--'
                              : _formatDateTime(_mealWindowEnd!),
                        }),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _editMealWindow,
                        child: Text(i18n.tr('entry.edit_actual_window')),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.tr('entry.next_meal_window'),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _nextMealWindowStart == null || _nextMealWindowEnd == null
                          ? i18n.tr('entry.next_meal_window_empty')
                          : i18n.tr('entry.next_meal_window_value', {
                              'start': _formatDateTime(_nextMealWindowStart!),
                              'end': _formatDateTime(_nextMealWindowEnd!),
                            }),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed: _editNextMealWindow,
                          child: Text(i18n.tr('entry.edit_next_meal_window')),
                        ),
                        if (_nextMealWindowStart != null ||
                            _nextMealWindowEnd != null)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _nextMealWindowStart = null;
                                _nextMealWindowEnd = null;
                              });
                              _inputsChanged();
                            },
                            child: Text(
                              i18n.tr('entry.clear_next_meal_window'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Theme(
              data: Theme.of(
                context,
              ).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: const ValueKey('entry-more-context'),
                initiallyExpanded: _hasCoeventContext || _hasEnteralFeedContext,
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                childrenPadding: EdgeInsets.zero,
                title: Text(
                  i18n.tr('food_display.more_context'),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(_moreContextSummary(i18n)),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i18n.tr('entry.supplement_context'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(i18n.tr('entry.with_iron_supplement')),
                            value: _withIronSupplement,
                            onChanged: (value) {
                              setState(() {
                                _withIronSupplement = value ?? false;
                              });
                              _inputsChanged();
                            },
                          ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              i18n.tr('entry.with_iron_multivitamin'),
                            ),
                            value: _withIronMultivitamin,
                            onChanged: (value) {
                              setState(() {
                                _withIronMultivitamin = value ?? false;
                              });
                              _inputsChanged();
                            },
                          ),
                          const SizedBox(height: 8),
                          Text(
                            i18n.tr('entry.thickener_type'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final type in <String?>[
                                null,
                                'starch_based',
                                'xanthan_based',
                              ])
                                ChoiceChip(
                                  label: Text(
                                    type == null
                                        ? i18n.tr('entry.none')
                                        : i18n.tr('entry.thickener_$type'),
                                  ),
                                  selected: _thickenerType == type,
                                  onSelected: (_) {
                                    setState(() => _thickenerType = type);
                                    _inputsChanged();
                                  },
                                ),
                            ],
                          ),
                          if (_hasCoeventContext) ...[
                            const SizedBox(height: 12),
                            Text(
                              _coeventTime == null
                                  ? i18n.tr('entry.coevent_time_empty')
                                  : i18n.tr('entry.coevent_time_value', {
                                      'value': _formatDateTime(_coeventTime!),
                                    }),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: _editCoeventTime,
                              child: Text(i18n.tr('entry.edit_coevent_time')),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i18n.tr('entry.enteral_feed_context'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final mode in <String?>[
                                null,
                                'continuous',
                                'bolus',
                              ])
                                ChoiceChip(
                                  label: Text(
                                    mode == null
                                        ? i18n.tr('entry.none')
                                        : i18n.tr('entry.enteral_feed_$mode'),
                                  ),
                                  selected: _enteralFeedMode == mode,
                                  onSelected: (_) {
                                    setState(() => _enteralFeedMode = mode);
                                    _inputsChanged();
                                  },
                                ),
                            ],
                          ),
                          if (_hasEnteralFeedContext) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _enteralFeedFormulaCtrl,
                              decoration: InputDecoration(
                                labelText: i18n.tr(
                                  'entry.enteral_feed_formula',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _enteralFeedProteinCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: i18n.tr(
                                  'entry.enteral_feed_protein_g_per_day',
                                ),
                                border: const OutlineInputBorder(),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('entry-save-meal'),
              onPressed: _isSaving ? null : _saveMeal,
              child: Text(
                _isSaving
                    ? i18n.tr('entry.saving')
                    : _isEditing
                    ? i18n.tr('entry.save_edit')
                    : i18n.tr('entry.save_new'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
