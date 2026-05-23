import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/entities/timeline_event.dart';
import '../entry/entry_page.dart';
import '../shared/interaction_result_view.dart';

class TimelinePage extends StatelessWidget {
  const TimelinePage({super.key});

  Meal? _mealForEvent(AppState state, TimelineEvent event) {
    for (final meal in state.meals) {
      if (meal.id == event.recordId) return meal;
    }
    return null;
  }

  Intake? _intakeForEvent(AppState state, TimelineEvent event) {
    for (final intake in state.intakes) {
      if (intake.id == event.recordId) return intake;
    }
    return null;
  }

  DrugDefinition? _drugForIntake(AppState state, Intake intake) {
    return state.medRepo.getById(intake.drugId);
  }

  Meal? _nearestMeal(AppState state, DateTime time) {
    Meal? nearest;
    var nearestDistance = const Duration(days: 100000);
    for (final meal in state.meals) {
      final distance = meal.effectiveOccurredAt.difference(time).abs();
      if (distance < nearestDistance) {
        nearest = meal;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  Intake? _nearestIntake(AppState state, DateTime time) {
    Intake? nearest;
    var nearestDistance = const Duration(days: 100000);
    for (final intake in state.intakes) {
      final distance = intake.takenAt.difference(time).abs();
      if (distance < nearestDistance) {
        nearest = intake;
        nearestDistance = distance;
      }
    }
    return nearest;
  }

  String _formatDateTime(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  String _formatDate(DateTime value) {
    final yyyy = value.year.toString().padLeft(4, '0');
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    return '$yyyy-$mm-$dd';
  }

  String _formatTimeDistance(AppI18n i18n, DateTime left, DateTime right) {
    final minutes = left.difference(right).inMinutes;
    final absMinutes = minutes.abs();
    final hours = absMinutes ~/ 60;
    final remainder = absMinutes % 60;
    final value = hours == 0 ? '${remainder}m' : '${hours}h ${remainder}m';
    return minutes >= 0
        ? i18n.tr('timeline.after', {'value': value})
        : i18n.tr('timeline.before', {'value': value});
  }

  String _mealContextSummary(AppI18n i18n, Meal meal) {
    final parts = <String>[];
    if (meal.coeventSubstanceTags.contains('iron_salt')) {
      parts.add(i18n.tr('dashboard.meal_context_iron_supplement'));
    }
    if (meal.coeventSubstanceTags.contains('multivitamin_with_iron')) {
      parts.add(i18n.tr('dashboard.meal_context_iron_multivitamin'));
    }
    if (meal.thickenerType == 'starch_based') {
      parts.add(i18n.tr('dashboard.meal_context_starch_thickener'));
    } else if (meal.thickenerType == 'xanthan_based') {
      parts.add(i18n.tr('dashboard.meal_context_xanthan_thickener'));
    }
    if (meal.enteralFeedMode == 'continuous') {
      parts.add(i18n.tr(
        'dashboard.meal_context_enteral_feed_continuous',
        {
          'protein': meal.enteralFeedProteinGPerDay?.toStringAsFixed(0) ??
              i18n.tr('common.not_available'),
        },
      ));
    } else if (meal.enteralFeedMode == 'bolus') {
      parts.add(i18n.tr('dashboard.meal_context_enteral_feed_bolus'));
    }
    return parts.isEmpty
        ? i18n.tr('timeline.no_context_flags')
        : parts.join(' · ');
  }

  String _mealSubtitle(AppState state, AppI18n i18n, Meal meal) {
    final totals = meal.computeTotals();
    final result = state.cachedMealCheck(meal);
    final nearestIntake = _nearestIntake(state, meal.effectiveOccurredAt);
    final parts = <String>[
      i18n.tr(
        'timeline.meal_macro_line',
        {
          'protein': totals.totalProteinG.toStringAsFixed(1),
          'carbs': totals.totalCarbsG.toStringAsFixed(1),
          'fat': totals.totalFatG.toStringAsFixed(1),
        },
      ),
      i18n.tr(
        'timeline.conflict_line',
        {
          'severity': i18n.severityLabel(result.overallSeverity.name),
          'score': '${result.score}',
        },
      ),
      _mealContextSummary(i18n, meal),
      if (meal.timePrecision == 'interval' &&
          meal.occurredRangeStart != null &&
          meal.occurredRangeEnd != null)
        i18n.tr(
          'timeline.meal_window_line',
          {
            'start': _formatDateTime(meal.occurredRangeStart!),
            'end': _formatDateTime(meal.occurredRangeEnd!),
          },
        ),
      if (meal.nextMealWindowStart != null && meal.nextMealWindowEnd != null)
        i18n.tr(
          'timeline.next_meal_window_line',
          {
            'start': _formatDateTime(meal.nextMealWindowStart!),
            'end': _formatDateTime(meal.nextMealWindowEnd!),
          },
        ),
      if (nearestIntake != null)
        i18n.tr(
          'timeline.nearest_medication_line',
          {
            'name': i18n.medicationName(
              nearestIntake.drugId,
              state.medRepo.getById(nearestIntake.drugId)?.displayName ??
                  nearestIntake.drugId,
            ),
            'distance': _formatTimeDistance(
              i18n,
              nearestIntake.takenAt,
              meal.effectiveOccurredAt,
            ),
          },
        ),
    ];
    return parts.join('\n');
  }

  String _intakeSubtitle(AppState state, AppI18n i18n, Intake intake) {
    final drug = _drugForIntake(state, intake);
    final nearestMeal = _nearestMeal(state, intake.takenAt);
    final details = <String>[
      i18n.tr(
        'timeline.dosage_line',
        {
          'value': intake.dosageNote.trim().isEmpty
              ? i18n.tr('common.not_available')
              : intake.dosageNote.trim(),
        },
      ),
      if (drug != null)
        '${i18n.sourceSystemLabel(drug.sourceSystem)} · ${i18n.regionLabel(drug.jurisdiction)} · ${i18n.routeLabel(drug.route)} · ${i18n.dosageFormLabel(drug.dosageForm)}',
      if (nearestMeal != null)
        i18n.tr(
          'timeline.nearest_meal_line',
          {
            'title': nearestMeal.title,
            'distance': _formatTimeDistance(
              i18n,
              intake.takenAt,
              nearestMeal.effectiveOccurredAt,
            ),
          },
        ),
    ];
    return details.join('\n');
  }

  Future<void> _showMealCheckDialog(BuildContext context, Meal meal) async {
    final result = await context.read<AppState>().checkMeal(meal);
    if (!context.mounted) return;
    final i18n = context.appI18n;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n.tr('meal.check_title', {'title': meal.title})),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: InteractionSummaryCard(result: result),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(i18n.tr('common.close')),
          ),
        ],
      ),
    );
  }

  Future<void> _openIntakeEditor(
    BuildContext context, {
    Intake? initialIntake,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _IntakeEditorPage(initialIntake: initialIntake),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final events = state.timeline;

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.tr('timeline.title')),
        actions: [
          IconButton(
            tooltip: i18n.tr('timeline.add_intake'),
            icon: const Icon(Icons.medication_outlined),
            onPressed: () => _openIntakeEditor(context),
          ),
          IconButton(
            tooltip: i18n.tr('timeline.add_meal'),
            icon: const Icon(Icons.restaurant_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EntryPage()),
            ),
          ),
        ],
      ),
      body: events.isEmpty
          ? Center(child: Text(i18n.tr('timeline.empty')))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              itemCount: events.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final event = events[index];
                final previous =
                    index == 0 ? null : _formatDate(events[index - 1].time);
                final current = _formatDate(event.time);
                final showHeader = previous != current;
                final meal = event.type == TimelineEventType.meal
                    ? _mealForEvent(state, event)
                    : null;
                final intake = event.type == TimelineEventType.medication
                    ? _intakeForEvent(state, event)
                    : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showHeader) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 4),
                        child: Text(
                          current,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                    Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _timelineColor(event.type)
                              .withValues(alpha: 0.12),
                          foregroundColor: _timelineColor(event.type),
                          child: Icon(_timelineIcon(event.type)),
                        ),
                        title: Text(
                          event.type == TimelineEventType.medication &&
                                  event.entityId != null
                              ? i18n.medicationName(
                                  event.entityId!, event.title)
                              : event.title,
                        ),
                        subtitle: Text(
                          [
                            _formatDateTime(event.time),
                            if (meal != null) _mealSubtitle(state, i18n, meal),
                            if (intake != null)
                              _intakeSubtitle(state, i18n, intake),
                          ].join('\n'),
                        ),
                        isThreeLine: true,
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            IconButton(
                              tooltip: i18n.tr('dashboard.edit'),
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: meal != null
                                  ? () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              EntryPage(initialMeal: meal),
                                        ),
                                      )
                                  : intake != null
                                      ? () => _openIntakeEditor(
                                            context,
                                            initialIntake: intake,
                                          )
                                      : null,
                            ),
                            IconButton(
                              tooltip: i18n.tr('dashboard.delete'),
                              icon: const Icon(Icons.delete_outline),
                              onPressed: meal != null
                                  ? () => context
                                      .read<AppState>()
                                      .deleteMeal(meal.id)
                                  : intake != null
                                      ? () => context
                                          .read<AppState>()
                                          .deleteIntake(intake.id)
                                      : null,
                            ),
                          ],
                        ),
                        onTap: meal == null
                            ? null
                            : () => _showMealCheckDialog(context, meal),
                      ),
                    ),
                  ],
                );
              },
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // 添加餐次（与“记录服药”并列，避免顶栏图标按钮被忽略）
          FloatingActionButton.extended(
            heroTag: 'timeline_add_meal_fab',
            icon: const Icon(Icons.restaurant_rounded),
            label: Text(i18n.tr('timeline.add_meal')),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const EntryPage()),
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            heroTag: 'timeline_add_intake_fab',
            icon: const Icon(Icons.add),
            label: Text(i18n.tr('timeline.add_intake')),
            onPressed: () => _openIntakeEditor(context),
          ),
        ],
      ),
    );
  }

  Color _timelineColor(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.meal:
        return Colors.teal;
      case TimelineEventType.medication:
        return Colors.indigo;
    }
  }

  IconData _timelineIcon(TimelineEventType type) {
    switch (type) {
      case TimelineEventType.meal:
        return Icons.restaurant_outlined;
      case TimelineEventType.medication:
        return Icons.medication_outlined;
    }
  }
}

class _IntakeEditorPage extends StatefulWidget {
  final Intake? initialIntake;

  const _IntakeEditorPage({this.initialIntake});

  bool get isEditing => initialIntake != null;

  @override
  State<_IntakeEditorPage> createState() => _IntakeEditorPageState();
}

class _IntakeEditorPageState extends State<_IntakeEditorPage> {
  late DateTime _takenAt;
  String? _drugId;
  late final TextEditingController _dosageCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialIntake;
    _takenAt = initial?.takenAt ?? DateTime.now();
    _drugId = initial?.drugId;
    _dosageCtrl = TextEditingController(text: initial?.dosageNote ?? '');
  }

  @override
  void dispose() {
    _dosageCtrl.dispose();
    super.dispose();
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

  String _formatDateTime(DateTime value) {
    final mm = value.month.toString().padLeft(2, '0');
    final dd = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final min = value.minute.toString().padLeft(2, '0');
    return '$mm/$dd $hh:$min';
  }

  Future<void> _editTakenAt() async {
    final picked = await _pickDateTime(_takenAt);
    if (picked == null) return;
    setState(() {
      _takenAt = picked;
    });
  }

  Future<void> _save() async {
    final i18n = context.appI18n;
    final medications = context.read<AppState>().medRepo.allDrugs;
    final drugId = medications.any((drug) => drug.id == _drugId)
        ? _drugId
        : medications.isEmpty
            ? null
            : medications.first.id;
    if (_isSaving) return;
    if (drugId == null || drugId.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.tr('timeline.select_medication_first'))),
      );
      return;
    }
    setState(() {
      _isSaving = true;
    });
    final state = context.read<AppState>();
    final intake = Intake(
      id: widget.initialIntake?.id ?? state.newId('intake'),
      drugId: drugId,
      takenAt: _takenAt,
      dosageNote: _dosageCtrl.text.trim(),
    );
    try {
      if (widget.isEditing) {
        await state.updateIntake(intake);
      } else {
        await state.addIntake(intake);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(i18n.tr('timeline.save_intake_failed', {
            'error': '$error',
          })),
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

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final medications = state.medRepo.allDrugs;
    final activeIds = state.activeDrugs.map((drug) => drug.id).toSet();
    final selectedDrugId = medications.any((drug) => drug.id == _drugId)
        ? _drugId
        : medications.isEmpty
            ? null
            : medications.first.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? i18n.tr('timeline.edit_intake')
              : i18n.tr('timeline.new_intake'),
        ),
      ),
      body: medications.isEmpty
          ? Center(child: Text(i18n.tr('timeline.no_medications')))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                if (selectedDrugId != null)
                  GlassSelectField<String>(
                    label: i18n.tr('timeline.medication'),
                    value: selectedDrugId,
                    options: [
                      for (final drug in medications)
                        GlassSelectOption<String>(
                          value: drug.id,
                          label: activeIds.contains(drug.id)
                              ? i18n.tr(
                                  'timeline.active_medication_option',
                                  {
                                    'name': i18n.medicationName(
                                      drug.id,
                                      drug.displayName,
                                    ),
                                  },
                                )
                              : i18n.medicationName(drug.id, drug.displayName),
                          icon: activeIds.contains(drug.id)
                              ? Icons.medication_rounded
                              : Icons.medication_outlined,
                        ),
                    ],
                    onChanged: (value) => setState(() => _drugId = value),
                  ),
                const SizedBox(height: 12),
                TextField(
                  controller: _dosageCtrl,
                  decoration: InputDecoration(
                    labelText: i18n.tr('timeline.dosage_note'),
                    border: const OutlineInputBorder(),
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
                          i18n.tr('timeline.taken_at'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(_formatDateTime(_takenAt)),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _editTakenAt,
                          child: Text(i18n.tr('timeline.edit_taken_at')),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(
                      _isSaving
                          ? i18n.tr('entry.saving')
                          : i18n.tr('timeline.save_intake'),
                    ),
                    onPressed: _isSaving ? null : _save,
                  ),
                ),
              ],
            ),
    );
  }
}
