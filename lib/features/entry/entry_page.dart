import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/models/food_item.dart';
import '../../core/models/meal.dart';
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

  const EntryPage({
    super.key,
    this.initialMeal,
  });

  bool get isEditing => initialMeal != null;

  @override
  State<EntryPage> createState() => _EntryPageState();
}

class _EntryPageState extends State<EntryPage> {
  late final TextEditingController _titleCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
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
    final initialMeal = widget.initialMeal;
    // 初始标题跟随当前默认文案；后续 UI 会按 locale 实时翻译其它固定文本。
    _titleCtrl = TextEditingController(text: initialMeal?.title ?? '');
    _items = initialMeal == null
        ? <MealItem>[]
        : List<MealItem>.from(initialMeal.items);
    _actualMealTime = initialMeal?.occurredAt ??
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
    _enteralFeedFormulaCtrl =
        TextEditingController(text: initialMeal?.enteralFeedFormula ?? '');
    _enteralFeedProteinCtrl = TextEditingController(
      text: initialMeal?.enteralFeedProteinGPerDay?.toStringAsFixed(0) ?? '',
    );
    _entryDebugLog(
      '[EntryPage] init mode=${widget.isEditing ? 'edit' : 'create'} items=${_items.length}',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _searchCtrl.dispose();
    _enteralFeedFormulaCtrl.dispose();
    _enteralFeedProteinCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 初次进入创建页时，把默认标题同步成当前语言。
    if (!_didLocalizeDefaultTitle && widget.initialMeal == null) {
      _titleCtrl.text = context.appI18n.tr('entry.default_meal_title');
      _didLocalizeDefaultTitle = true;
    }
  }

  Future<void> _saveMeal() async {
    _entryDebugLog(
        '[EntryPage] save:pressed items=${_items.length} mounted=$mounted');

    final i18n = context.appI18n;
    if (_isSaving) {
      _entryDebugLog('[EntryPage] save:ignored duplicate tap');
      return;
    }

    if (_items.isEmpty) {
      _entryDebugLog('[EntryPage] save:blocked empty-items');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.tr('entry.add_food_first'))),
      );
      return;
    }

    final appState = context.read<AppState>();
    final title = _titleCtrl.text.trim().isEmpty
        ? i18n.tr('entry.default_meal_title')
        : _titleCtrl.text.trim();
    final now = DateTime.now();
    final normalizedMealWindowStart =
        _useApproximateWindow ? (_mealWindowStart ?? _actualMealTime) : null;
    final normalizedMealWindowEnd = _useApproximateWindow
        ? (_mealWindowEnd ??
            (_mealWindowStart ?? _actualMealTime)
                .add(const Duration(minutes: 20)))
        : null;
    final coeventSubstanceTags = <String>[
      if (_withIronSupplement) 'iron_salt',
      if (_withIronMultivitamin) 'multivitamin_with_iron',
    ];
    final effectiveOccurredAt =
        _useApproximateWindow ? normalizedMealWindowStart! : _actualMealTime;
    final meal = Meal(
      id: widget.initialMeal?.id ?? appState.newId('meal'),
      title: title,
      // 向后兼容字段 eatenAt 仍写“实际发生时间的代表点”。
      eatenAt: effectiveOccurredAt,
      recordedAt: widget.initialMeal?.recordedAt ?? now,
      occurredAt: _useApproximateWindow ? null : _actualMealTime,
      occurredRangeStart: normalizedMealWindowStart,
      occurredRangeEnd: normalizedMealWindowEnd,
      timeSource: _useApproximateWindow ? 'user_interval' : 'user_exact',
      timePrecision: _useApproximateWindow ? 'interval' : 'exact',
      nextMealWindowStart: _nextMealWindowStart,
      nextMealWindowEnd: _nextMealWindowEnd,
      coeventTime:
          _hasCoeventContext ? (_coeventTime ?? effectiveOccurredAt) : null,
      coeventSubstanceTags: coeventSubstanceTags,
      thickenerType: _thickenerType,
      enteralFeedMode: _enteralFeedMode,
      enteralFeedFormula: _enteralFeedFormulaCtrl.text.trim().isEmpty
          ? null
          : _enteralFeedFormulaCtrl.text.trim(),
      enteralFeedProteinGPerDay:
          double.tryParse(_enteralFeedProteinCtrl.text.trim()),
      items: List<MealItem>.from(_items),
    );

    setState(() {
      _isSaving = true;
    });

    try {
      _entryDebugLog('[EntryPage] save:checking');
      final result = await appState.checkMeal(meal);
      _entryDebugLog(
        '[EntryPage] save:checkResult score=${result.score} severity=${result.overallSeverity.name}',
      );

      if (widget.isEditing) {
        _entryDebugLog('[EntryPage] save:updateMeal start');
        await appState.updateMeal(meal);
      } else {
        _entryDebugLog('[EntryPage] save:addMeal start');
        await appState.addMeal(meal);
      }
      _entryDebugLog('[EntryPage] save:persisted');

      if (!mounted) return;

      _entryDebugLog('[EntryPage] save:showDialog');
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(widget.isEditing
              ? i18n.tr('entry.updated_title')
              : i18n.tr('entry.saved_title')),
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
            content: Text(i18n.tr('entry.save_failed', {'error': '$error'}))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _addFood(MealItem item) {
    final i18n = context.appI18n;
    final localizedFoodName = i18n.foodName(item.foodId, item.foodName);
    setState(() {
      // 已存量数据仍可能保留旧语言 foodName；新加入条目在 UI 层先写入当前语言显示名。
      _items = [..._items, item.copyWith(foodName: localizedFoodName)];
    });
    _entryDebugLog('[EntryPage] addFood items=${_items.length}');
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 110),
          content:
              Text(i18n.tr('entry.food_added', {'name': localizedFoodName})),
          duration: const Duration(milliseconds: 1200),
        ),
      );
  }

  void _updateItemQuantity(int index, double nextFactor) {
    final clampedFactor = nextFactor < 0.25 ? 0.25 : nextFactor;
    setState(() {
      _items = [
        for (var i = 0; i < _items.length; i++)
          if (i == index)
            _items[i].copyWith(quantityFactor: clampedFactor)
          else
            _items[i],
      ];
    });
    _entryDebugLog(
      '[EntryPage] updateQuantity index=$index factor=${clampedFactor.toStringAsFixed(2)}',
    );
  }

  void _removeItem(int index) {
    setState(() {
      _items = [..._items]..removeAt(index);
    });
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
            final protein = current.proteinPer100g * factor;
            final carbs = current.carbsPer100g * factor;

            void updateGrams(double value) {
              final safeValue = value < 25 ? 25.0 : value;
              setDialogState(() {
                grams = safeValue;
                controller.text = safeValue.toStringAsFixed(0);
              });
            }

            return AlertDialog(
              title: Text(
                  i18n.tr('entry.adjust_quantity', {'name': current.foodName})),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: i18n.tr('entry.grams'),
                      border: const OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null) {
                        updateGrams(parsed);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(i18n.tr('entry.quantity_factor',
                      {'value': factor.toStringAsFixed(2)})),
                  Slider(
                    value: grams.clamp(25.0, 500.0).toDouble(),
                    min: 25,
                    max: 500,
                    divisions: 19,
                    label: '${grams.toStringAsFixed(0)}g',
                    onChanged: updateGrams,
                  ),
                  const SizedBox(height: 8),
                  Text(
                      '${i18n.tr('entry.protein')}：${protein.toStringAsFixed(1)} g'),
                  Text(
                      '${i18n.tr('entry.carbs')}：${carbs.toStringAsFixed(1)} g'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(i18n.tr('common.cancel')),
                ),
                FilledButton(
                  onPressed: () {
                    _updateItemQuantity(index, grams / 100);
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

  String _formatTotals() {
    final meal = Meal(
      id: 'preview',
      eatenAt: DateTime.now(),
      title: _titleCtrl.text,
      items: _items,
    );
    final totals = meal.computeTotals();
    return 'P ${totals.totalProteinG.toStringAsFixed(1)}g · C ${totals.totalCarbsG.toStringAsFixed(1)}g · F ${totals.totalFatG.toStringAsFixed(1)}g';
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing
            ? i18n.tr('entry.edit_title')
            : i18n.tr('entry.new_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 120),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: InputDecoration(
              labelText: i18n.tr('entry.meal_title'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            decoration: InputDecoration(
              labelText: i18n.tr('entry.search_food'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
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
                  Text(i18n.tr(
                    'entry.recorded_time_hint',
                    {
                      'value': _formatDateTime(
                          widget.initialMeal?.recordedAt ?? DateTime.now())
                    },
                  )),
                  const SizedBox(height: 8),
                  Text(i18n.tr(
                    'entry.actual_time_value',
                    {'value': _formatDateTime(_actualMealTime)},
                  )),
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
                        },
                      ),
                    ],
                  ),
                  if (_useApproximateWindow) ...[
                    const SizedBox(height: 8),
                    Text(
                      i18n.tr(
                        'entry.actual_window_value',
                        {
                          'start': _mealWindowStart == null
                              ? '--'
                              : _formatDateTime(_mealWindowStart!),
                          'end': _mealWindowEnd == null
                              ? '--'
                              : _formatDateTime(_mealWindowEnd!),
                        },
                      ),
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
                    },
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(i18n.tr('entry.with_iron_multivitamin')),
                    value: _withIronMultivitamin,
                    onChanged: (value) {
                      setState(() {
                        _withIronMultivitamin = value ?? false;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.tr('entry.thickener_type'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String?>(
                    segments: [
                      ButtonSegment<String?>(
                        value: null,
                        label: Text(i18n.tr('entry.none')),
                      ),
                      ButtonSegment<String?>(
                        value: 'starch_based',
                        label: Text(i18n.tr('entry.thickener_starch_based')),
                      ),
                      ButtonSegment<String?>(
                        value: 'xanthan_based',
                        label: Text(i18n.tr('entry.thickener_xanthan_based')),
                      ),
                    ],
                    selected: {_thickenerType},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _thickenerType =
                            selection.isEmpty ? null : selection.first;
                      });
                    },
                  ),
                  if (_hasCoeventContext) ...[
                    const SizedBox(height: 12),
                    Text(
                      _coeventTime == null
                          ? i18n.tr('entry.coevent_time_empty')
                          : i18n.tr(
                              'entry.coevent_time_value',
                              {'value': _formatDateTime(_coeventTime!)},
                            ),
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
                  SegmentedButton<String?>(
                    segments: [
                      ButtonSegment<String?>(
                        value: null,
                        label: Text(i18n.tr('entry.none')),
                      ),
                      ButtonSegment<String?>(
                        value: 'continuous',
                        label: Text(i18n.tr('entry.enteral_feed_continuous')),
                      ),
                      ButtonSegment<String?>(
                        value: 'bolus',
                        label: Text(i18n.tr('entry.enteral_feed_bolus')),
                      ),
                    ],
                    selected: {_enteralFeedMode},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _enteralFeedMode =
                            selection.isEmpty ? null : selection.first;
                      });
                    },
                  ),
                  if (_hasEnteralFeedContext) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _enteralFeedFormulaCtrl,
                      decoration: InputDecoration(
                        labelText: i18n.tr('entry.enteral_feed_formula'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _enteralFeedProteinCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText:
                            i18n.tr('entry.enteral_feed_protein_g_per_day'),
                        border: const OutlineInputBorder(),
                      ),
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
                        : i18n.tr(
                            'entry.next_meal_window_value',
                            {
                              'start': _formatDateTime(_nextMealWindowStart!),
                              'end': _formatDateTime(_nextMealWindowEnd!),
                            },
                          ),
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
                          },
                          child: Text(i18n.tr('entry.clear_next_meal_window')),
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
                  Text(_items.isEmpty
                      ? i18n.tr('entry.no_foods_yet')
                      : _formatTotals()),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            i18n.tr('common.search_results'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (foods.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(i18n.tr('common.no_matching_foods')),
              ),
            ),
          for (final food in foods)
            Card(
              child: Builder(
                builder: (context) {
                  final textureLine = _foodTextureLine(i18n, food);
                  return ListTile(
                    title: Text(i18n.foodName(food.id, food.name)),
                    subtitle: Text(
                      '${i18n.tr(
                        'entry.per_100g',
                        {
                          'protein': food.proteinG.toStringAsFixed(1),
                          'carbs': food.carbsG.toStringAsFixed(1),
                        },
                      )} · F ${food.fatG.toStringAsFixed(1)} · Fiber ${food.fiberG.toStringAsFixed(1)}'
                      '\n${food.sourceSystem} · ${food.jurisdiction}${food.sourceFoodCode == null ? '' : ' · ${food.sourceFoodCode}'}'
                      '${textureLine == null ? '' : '\n$textureLine'}'
                      '\n${food.description}',
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
                          tooltip: i18n.tr('entry.add_food'),
                          onPressed: () {
                            _addFood(
                              MealItem.fromFood(
                                food: food,
                                quantityFactor: 1.0,
                              ),
                            );
                          },
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            i18n.tr('entry.added_foods'),
            style: const TextStyle(fontWeight: FontWeight.bold),
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
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            i18n.foodName(_items[i].foodId, _items[i].foodName),
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                      '${_items[i].grams.toStringAsFixed(0)}g · ${i18n.tr('entry.protein')} ${_items[i].proteinG.toStringAsFixed(1)}g · ${i18n.tr('entry.carbs')} ${_items[i].carbsG.toStringAsFixed(1)}g',
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _updateItemQuantity(
                              i, _items[i].quantityFactor - 0.25),
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text(
                            '${_items[i].quantityFactor.toStringAsFixed(2)} x'),
                        IconButton(
                          onPressed: () => _updateItemQuantity(
                              i, _items[i].quantityFactor + 0.25),
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(
                          onPressed: () => _showQuantityEditor(i),
                          child: Text(i18n.tr('entry.set_quantity')),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(12),
        child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveMeal,
              child: Text(
                _isSaving
                    ? i18n.tr('entry.saving')
                    : widget.isEditing
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
