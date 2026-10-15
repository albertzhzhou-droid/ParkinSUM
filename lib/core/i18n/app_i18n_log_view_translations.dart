/// Chinese and English view copy. Other families use explicit English
/// fallback pending native-language review; key and placeholder parity is checked.
const kPersonalLogViewEnglish = <String, String>{
  'timeline.conflict_pending': 'Conflict review: check not yet completed',
  'insights.protein_coverage':
      '{start} — {end} ({zone}, meal occurrence time): {included} meals included in protein points and mean; {excluded} meals excluded because protein is unknown or invalid. Unknown {unknown}; invalid {invalid}; reported zero {zero}.',
  'log_view.selection_changed':
      'The session or declared zone changed. Reopen the record list.',
  'log_view.no_matches': 'No records match the current view.',
  'insights.no_known_protein':
      'No complete known protein meal values in these dates.',
  'log_view.dates': 'Choose dates',
  'log_view.all_dates': 'All dates',
  'log_view.date_basis': 'Dates and dayparts use the declared zone {zone}.',
  'log_view.zone_hold':
      'The declared zone is unavailable. Date summaries are on hold.',
  'log_view.filters': 'View filters',
  'log_view.name': 'Record or food name',
  'log_view.all_types': 'All record types',
  'log_view.all_sources': 'All sources',
  'log_view.source_basis':
      'Food and medication filters use current catalogue sources; observations use recorded sources. Historical catalogue sources are unconfirmed. Filters change the view only; export selections are unchanged.',
  'log_view.source_unconfirmed': 'Source unconfirmed',
  'log_view.current_catalog': 'Current catalogue: {source}',
  'log_view.recorded_source': 'Recorded source: {source}',
  'log_view.focused': 'Showing the selected original record',
  'log_view.clear_focus': 'Return to filtered results',
  'log_view.clear_filters': 'Clear filters',
  'log_view.unavailable': 'The selected record was deleted or is unavailable.',
  'log_view.ambiguous': 'The selected record identity is ambiguous.',
  'log_view.hidden':
      'The selected record exists but is hidden by the current filters.',
  'log_view.expired':
      'The session changed. The old record focus and filters were cleared.',
  'log_view.count':
      '{matched} of {total} records match; {shown} currently shown.',
  'log_view.previous_records': 'Previous records',
  'log_view.next_records': 'Next records',
  'log_view.page': 'Page {page} of {pages} · records {start}–{end}',
  'log_view.start': 'Start date (YYYY-MM-DD)',
  'log_view.end': 'End date, inclusive (YYYY-MM-DD)',
  'log_view.invalid_dates':
      'Enter valid dates with the end on or after the start.',
  'log_view.range_limit': 'Chart date ranges are limited to 366 days.',
  'log_view.apply': 'Apply dates',
  'log_view.records': 'View original records',
  'log_view.unknown': 'Unknown',
  'log_view.invalid': 'Invalid value',
  'log_view.future': 'Future-dated record',
  'insights.future_count':
      '{count} future-dated records in the selected dates are listed separately and excluded from historical summaries.',
  'insights.chart_scope':
      'Chart shows the latest {shown} of {total} known meal points; the mean uses all known meals.',
};
const kPersonalLogViewChinese = <String, String>{
  'timeline.conflict_pending': '冲突复核：尚未完成检查',
  'insights.protein_coverage':
      '{start} — {end}（{zone}，按进食时间）：{included} 餐计入蛋白质点与平均值；{excluded} 餐因蛋白质未知或无效未计入。未知 {unknown}；无效 {invalid}；已报告零 {zero}。',
  'log_view.selection_changed': '会话或声明时区已更改，请重新打开原记录列表。',
  'log_view.no_matches': '当前筛选没有匹配的记录。',
  'insights.no_known_protein': '该日期内没有完整已知的蛋白质餐点。',
  'log_view.dates': '自选日期',
  'log_view.all_dates': '全部日期',
  'log_view.date_basis': '日期与时段按声明时区 {zone} 显示。',
  'log_view.zone_hold': '声明时区不可用，日期汇总暂停；未改用设备时区。',
  'log_view.filters': '显示筛选',
  'log_view.name': '记录或食物名称',
  'log_view.all_types': '全部记录类型',
  'log_view.all_sources': '全部来源',
  'log_view.source_basis':
      '食物与药品筛选使用当前目录来源；观察使用记录中的来源。未保存的历史目录来源无法核实。筛选只改变显示，不改变导出选择。',
  'log_view.source_unconfirmed': '来源无法核实',
  'log_view.current_catalog': '当前目录：{source}',
  'log_view.recorded_source': '记录来源：{source}',
  'log_view.focused': '正在定位所选原记录',
  'log_view.clear_focus': '返回筛选结果',
  'log_view.clear_filters': '清除筛选',
  'log_view.unavailable': '所选记录已删除或不可用。',
  'log_view.ambiguous': '所选记录标识不唯一，无法定位。',
  'log_view.hidden': '所选记录仍存在，但当前筛选将其隐藏。',
  'log_view.expired': '会话已更改，旧记录定位与筛选已撤回。',
  'log_view.count': '筛选匹配 {matched} / 共 {total} 条；当前显示 {shown} 条。',
  'log_view.previous_records': '上一页记录',
  'log_view.next_records': '下一页记录',
  'log_view.page': '第 {page} / {pages} 页 · 第 {start}–{end} 条记录',
  'log_view.start': '开始日期（YYYY-MM-DD）',
  'log_view.end': '结束日期，含当日（YYYY-MM-DD）',
  'log_view.invalid_dates': '请输入有效的起止日期，结束日期不可早于开始日期。',
  'log_view.range_limit': '图表日期范围最多 366 天。',
  'log_view.apply': '应用日期',
  'log_view.records': '查看原记录',
  'log_view.unknown': '未知',
  'log_view.invalid': '无效数值',
  'log_view.future': '未来时间记录',
  'insights.future_count': '所选日期另有 {count} 条未来时间记录，单独列出，不计入历史汇总。',
  'insights.chart_scope': '图中显示最近 {shown} / 共 {total} 个已知餐点；平均值使用全部已知餐。',
};

/// Incomplete conflict checks have no severity or numeric score. Other
/// language families use this explicit English fallback pending review.
const kInteractionReviewEnglish = <String, String>{
  'interaction.unassessed': 'Review incomplete',
  'interaction.unresolved_medication':
      'Review incomplete: {count} medication identities could not be matched to the current catalogue. A score is unavailable.',
  'interaction.review_medication':
      'Review saved medication entries and active medications against the current catalogue, then check again.',
  'timeline.unresolved_medication_selection':
      'The recorded medication is unavailable in the current catalogue. Select a medication explicitly before saving. The original record has not been changed.',
};
const kInteractionReviewChinese = <String, String>{
  'interaction.unassessed': '评估未完成',
  'interaction.unresolved_medication':
      '评估未完成：有 {count} 个药品标识无法匹配当前目录，暂时无法给出分数。',
  'interaction.review_medication': '请核对已保存的服药记录和当前激活药品，再重新检查。',
  'timeline.unresolved_medication_selection':
      '原记录中的药品在当前目录中不可用。请明确选择药品后再保存；原记录尚未更改。',
};
