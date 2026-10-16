import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../domain/entities/personal_log_view.dart';
import '../../domain/entities/timeline_event.dart';
import '../../domain/usecases/personal_log_date_window_resolver.dart';

/// New view keys have bilingual fallbacks until the shared dictionary is
/// integrated. Runtime dictionary entries continue to take precedence.
String logViewText(
  AppI18n i18n,
  String key, [
  Map<String, String> values = const {},
]) {
  final translated = i18n.tr(key, values);
  if (translated != key) return translated;
  final pair = logViewFallbacks[key];
  var value = pair == null ? key : pair[i18n.languageFamily == 'zh' ? 0 : 1];
  values.forEach(
    (key, replacement) => value = value.replaceAll('{$key}', replacement),
  );
  return value;
}

const logViewFallbacks = <String, List<String>>{
  'timeline.conflict_pending': [
    '冲突复核：尚未完成检查',
    'Conflict review: check not yet completed',
  ],
  'insights.protein_coverage': [
    '{start} — {end}（{zone}，按进食时间）：{included} 餐计入蛋白质点与平均值；{excluded} 餐因蛋白质未知或无效未计入。未知 {unknown}；无效 {invalid}；已报告零 {zero}。',
    '{start} — {end} ({zone}, meal occurrence time): {included} meals included in protein points and mean; {excluded} meals excluded because protein is unknown or invalid. Unknown {unknown}; invalid {invalid}; reported zero {zero}.',
  ],
  'log_view.selection_changed': [
    '会话或声明时区已更改，请重新打开原记录列表。',
    'The session or declared zone changed. Reopen the record list.',
  ],
  'log_view.no_matches': ['当前筛选没有匹配的记录。', 'No records match the current view.'],
  'insights.no_known_protein': [
    '该日期内没有完整已知的蛋白质餐点。',
    'No complete known protein meal values in these dates.',
  ],
  'log_view.dates': ['自选日期', 'Choose dates'],
  'log_view.all_dates': ['全部日期', 'All dates'],
  'log_view.date_basis': [
    '日期与时段按声明时区 {zone} 显示。',
    'Dates and dayparts use the declared zone {zone}.',
  ],
  'log_view.zone_hold': [
    '声明时区不可用，日期汇总暂停；未改用设备时区。',
    'The declared zone is unavailable. Date summaries are on hold.',
  ],
  'log_view.filters': ['显示筛选', 'View filters'],
  'log_view.name': ['记录或食物名称', 'Record or food name'],
  'log_view.all_types': ['全部记录类型', 'All record types'],
  'log_view.all_sources': ['全部来源', 'All sources'],
  'log_view.source_basis': [
    '食物与药品筛选使用当前目录来源；观察使用记录中的来源。未保存的历史目录来源无法核实。筛选只改变显示，不改变导出选择。',
    'Food and medication filters use current catalogue sources; observations use recorded sources. Historical catalogue sources are unconfirmed. Filters change the view only; export selections are unchanged.',
  ],
  'log_view.source_unconfirmed': ['来源无法核实', 'Source unconfirmed'],
  'log_view.current_catalog': ['当前目录：{source}', 'Current catalogue: {source}'],
  'log_view.recorded_source': ['记录来源：{source}', 'Recorded source: {source}'],
  'log_view.focused': ['正在定位所选原记录', 'Showing the selected original record'],
  'log_view.clear_focus': ['返回筛选结果', 'Return to filtered results'],
  'log_view.clear_filters': ['清除筛选', 'Clear filters'],
  'log_view.unavailable': [
    '所选记录已删除或不可用。',
    'The selected record was deleted or is unavailable.',
  ],
  'log_view.ambiguous': [
    '所选记录标识不唯一，无法定位。',
    'The selected record identity is ambiguous.',
  ],
  'log_view.hidden': [
    '所选记录仍存在，但当前筛选将其隐藏。',
    'The selected record exists but is hidden by the current filters.',
  ],
  'log_view.expired': [
    '会话已更改，旧记录定位与筛选已撤回。',
    'The session changed. The old record focus and filters were cleared.',
  ],
  'log_view.count': [
    '筛选匹配 {matched} / 共 {total} 条；当前显示 {shown} 条。',
    '{matched} of {total} records match; {shown} currently shown.',
  ],
  'log_view.previous_records': ['上一页记录', 'Previous records'],
  'log_view.next_records': ['下一页记录', 'Next records'],
  'log_view.page': [
    '第 {page} / {pages} 页 · 第 {start}–{end} 条记录',
    'Page {page} of {pages} · records {start}–{end}',
  ],
  'log_view.start': ['开始日期（YYYY-MM-DD）', 'Start date (YYYY-MM-DD)'],
  'log_view.end': ['结束日期，含当日（YYYY-MM-DD）', 'End date, inclusive (YYYY-MM-DD)'],
  'log_view.invalid_dates': [
    '请输入有效的起止日期，结束日期不可早于开始日期。',
    'Enter valid dates with the end on or after the start.',
  ],
  'log_view.range_limit': [
    '图表日期范围最多 366 天。',
    'Chart date ranges are limited to 366 days.',
  ],
  'log_view.apply': ['应用日期', 'Apply dates'],
  'log_view.records': ['查看原记录', 'View original records'],
  'log_view.unknown': ['未知', 'Unknown'],
  'log_view.invalid': ['无效数值', 'Invalid value'],
  'log_view.future': ['未来时间记录', 'Future-dated record'],
  'insights.future_count': [
    '所选日期另有 {count} 条未来时间记录，单独列出，不计入历史汇总。',
    '{count} future-dated records in the selected dates are listed separately and excluded from historical summaries.',
  ],
  'insights.chart_scope': [
    '图中显示最近 {shown} / 共 {total} 个已知餐点；平均值使用全部已知餐。',
    'Chart shows the latest {shown} of {total} known meal points; the mean uses all known meals.',
  ],
};

class PersonalLogDateButton extends StatelessWidget {
  const PersonalLogDateButton({
    super.key,
    required this.zoneId,
    required this.selection,
    required this.onChanged,
    this.maxDays,
    this.enabled = true,
  });
  final String zoneId;
  final PersonalLogDateWindow? selection;
  final ValueChanged<PersonalLogDateWindow> onChanged;
  final int? maxDays;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    return OutlinedButton.icon(
      onPressed: enabled ? () => _choose(context) : null,
      icon: const Icon(Icons.date_range),
      label: Text(
        selection == null
            ? logViewText(i18n, 'log_view.dates')
            : '${selection!.start} — ${selection!.endInclusive}',
      ),
    );
  }

  Future<void> _choose(BuildContext context) async {
    final today = PersonalLogDateWindowResolver().dateAt(
      DateTime.now(),
      zoneId,
    );
    final result = await showDialog<PersonalLogDateWindow>(
      context: context,
      builder: (_) => _PersonalLogDateDialog(
        i18n: context.appI18n,
        zoneId: zoneId,
        maxDays: maxDays,
        start: selection?.start ?? today,
        end: selection?.endInclusive ?? today,
      ),
    );
    if (context.mounted && result != null) onChanged(result);
  }
}

class _PersonalLogDateDialog extends StatefulWidget {
  const _PersonalLogDateDialog({
    required this.i18n,
    required this.zoneId,
    required this.start,
    required this.end,
    required this.maxDays,
  });
  final AppI18n i18n;
  final String zoneId;
  final LogCivilDate start;
  final LogCivilDate end;
  final int? maxDays;
  @override
  State<_PersonalLogDateDialog> createState() => _PersonalLogDateDialogState();
}

class _PersonalLogDateDialogState extends State<_PersonalLogDateDialog> {
  late final TextEditingController _start;
  late final TextEditingController _end;
  String? _error;
  @override
  void initState() {
    super.initState();
    _start = TextEditingController(text: widget.start.toString());
    _end = TextEditingController(text: widget.end.toString());
  }

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    super.dispose();
  }

  LogCivilDate _parse(String text) {
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) {
      throw const FormatException('Expected calendar date.');
    }
    final pieces = text.split('-').map(int.parse).toList();
    return LogCivilDate(pieces[0], pieces[1], pieces[2]);
  }

  void _apply() {
    try {
      final window = PersonalLogDateWindow(
        start: _parse(_start.text),
        endInclusive: _parse(_end.text),
        zoneId: widget.zoneId,
      );
      if (widget.maxDays != null && window.calendarDays > widget.maxDays!) {
        setState(
          () => _error = logViewText(widget.i18n, 'log_view.range_limit'),
        );
        return;
      }
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.of(context).pop(window);
    } on FormatException {
      setState(
        () => _error = logViewText(widget.i18n, 'log_view.invalid_dates'),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(logViewText(widget.i18n, 'log_view.dates')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.zoneId),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('log-date-start'),
            controller: _start,
            keyboardType: TextInputType.datetime,
            decoration: InputDecoration(
              labelText: logViewText(widget.i18n, 'log_view.start'),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const ValueKey('log-date-end'),
            controller: _end,
            keyboardType: TextInputType.datetime,
            onSubmitted: (_) => _apply(),
            decoration: InputDecoration(
              labelText: logViewText(widget.i18n, 'log_view.end'),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, key: const ValueKey('log-date-error')),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: Text(widget.i18n.tr('common.cancel')),
      ),
      FilledButton(
        key: const ValueKey('log-date-apply'),
        onPressed: _apply,
        child: Text(logViewText(widget.i18n, 'log_view.apply')),
      ),
    ],
  );
}

class TimelineViewControls extends StatelessWidget {
  const TimelineViewControls({
    super.key,
    required this.nameController,
    required this.type,
    required this.source,
    required this.sourceFacets,
    required this.onNameChanged,
    required this.onTypeChanged,
    required this.onSourceChanged,
    required this.dateButton,
    required this.onClear,
    required this.i18n,
  });
  final TextEditingController nameController;
  final TimelineEventType? type;
  final String? source;
  final List<TimelineSourceFacet> sourceFacets;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<TimelineEventType?> onTypeChanged;
  final ValueChanged<String?> onSourceChanged;
  final Widget dateButton;
  final VoidCallback onClear;
  final AppI18n i18n;

  @override
  Widget build(BuildContext context) => ExpansionTile(
    key: const ValueKey('timeline-view-filters'),
    title: Text(logViewText(i18n, 'log_view.filters')),
    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
    children: [
      TextField(
        key: const ValueKey('timeline-filter-name'),
        controller: nameController,
        onChanged: onNameChanged,
        decoration: InputDecoration(
          labelText: logViewText(i18n, 'log_view.name'),
          prefixIcon: const Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final width = math.min(320.0, constraints.maxWidth);
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: width,
                child: DropdownButtonFormField<TimelineEventType>(
                  key: ValueKey('timeline-filter-type-${type?.name ?? 'all'}'),
                  initialValue: type,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(logViewText(i18n, 'log_view.all_types')),
                    ),
                    for (final candidate in TimelineEventType.values)
                      DropdownMenuItem(
                        value: candidate,
                        child: Text(
                          i18n.tr(switch (candidate) {
                            TimelineEventType.meal => 'insights.meals',
                            TimelineEventType.medication => 'insights.intakes',
                            TimelineEventType.observation =>
                              'insights.observations',
                          }),
                        ),
                      ),
                  ],
                  onChanged: onTypeChanged,
                ),
              ),
              SizedBox(
                width: width,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('timeline-filter-source-${source ?? 'all'}'),
                  initialValue: source,
                  isExpanded: true,
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(logViewText(i18n, 'log_view.all_sources')),
                    ),
                    for (final facet in sourceFacets)
                      DropdownMenuItem(
                        value: facet.id,
                        child: Text(
                          facet.isUnconfirmed
                              ? logViewText(i18n, 'log_view.source_unconfirmed')
                              : logViewText(
                                  i18n,
                                  facet.isCurrentCatalog
                                      ? 'log_view.current_catalog'
                                      : 'log_view.recorded_source',
                                  {'source': facet.value},
                                ),
                        ),
                      ),
                  ],
                  onChanged: onSourceChanged,
                ),
              ),
              dateButton,
              TextButton(
                key: const ValueKey('timeline-clear-filters'),
                onPressed: onClear,
                child: Text(logViewText(i18n, 'log_view.clear_filters')),
              ),
            ],
          );
        },
      ),
      const SizedBox(height: 12),
      Text(logViewText(i18n, 'log_view.source_basis')),
    ],
  );
}
