import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/personal_log_handoff_document_service.dart';
import '../../core/services/personal_log_handoff_text_pdf_renderer.dart';
import '../../core/state/app_state.dart';
import '../../domain/entities/personal_log_view.dart';
import '../../domain/entities/visit_report_selection.dart';
import '../../domain/usecases/personal_log_date_window_resolver.dart';
import '../../domain/usecases/personal_log_handoff_summary_service.dart';
import '../shared/personal_log_view_controls.dart';
import 'care_workspace_page.dart';

/// Explicit report inputs; selecting or exporting never edits a stored record.
class VisitReportSelectionPage extends StatefulWidget {
  const VisitReportSelectionPage({
    super.key,
    this.renderer = const SystemPersonalLogHandoffTextPdfRenderer(),
    this.delivery = const SystemPersonalLogHandoffDelivery(),
    this.now,
  });
  final PersonalLogHandoffRenderer renderer;
  final PersonalLogHandoffDelivery delivery;
  final DateTime Function()? now;
  @override
  State<VisitReportSelectionPage> createState() =>
      _VisitReportSelectionPageState();
}

class _VisitReportSelectionPageState extends State<VisitReportSelectionPage> {
  VisitPreparationSourceLease? _lease;
  PersonalLogDateWindow? _window;
  DateTime? _asOf;
  bool _initialized = false;
  String? _error;
  final _chosen = <String, Set<String>>{
    'intake': {},
    'observation': {},
    'question': {},
    'medication': {},
    'followup': {},
  };
  bool _currentMedications = true;
  bool _recordNotes = false;
  bool _discussionUpdates = false;
  bool _sourceAssertions = false;

  DateTime get _now => (widget.now ?? DateTime.now)();
  String _t(String zh, String en) =>
      context.read<AppState>().userProfile.displayLocale.startsWith('zh')
      ? zh
      : en;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _reload(context.read<AppState>(), selectShown: true);
    }
  }

  void _reload(AppState state, {required bool selectShown}) {
    try {
      _lease = state.captureVisitPreparationLease();
      _asOf = _now;
      final resolver = PersonalLogDateWindowResolver();
      final today = resolver.dateAt(_asOf!, state.userProfile.timezone);
      if (_window == null || _window!.zoneId != state.userProfile.timezone) {
        _window = PersonalLogDateWindow(
          start: today.addDays(-29),
          endInclusive: today,
          zoneId: state.userProfile.timezone,
        );
      }
      final rows = _rows(state);
      for (final entry in _chosen.entries) {
        entry.value.clear();
        if (selectShown) {
          entry.value.addAll(rows[entry.key]!.map((row) => row.id));
        }
      }
      _error = null;
    } catch (_) {
      _lease = null;
      _error = _t(
        '日期或记录暂不可用，请返回后重试。',
        'The dates or records are unavailable. Return and retry.',
      );
    }
  }

  Map<String, List<_ReportRow>> _rows(AppState state) {
    final resolved = PersonalLogDateWindowResolver().resolve(
      _window!,
      asOf: _asOf!,
    );
    List<_ReportRow> bounded(Iterable<_ReportRow> source, int cap) {
      final rows =
          source
              .where(
                (row) =>
                    resolved.contains(row.time) && !resolved.isFuture(row.time),
              )
              .toList()
            ..sort((left, right) {
              final order = right.time.compareTo(left.time);
              return order != 0 ? order : left.id.compareTo(right.id);
            });
      return rows.take(cap).toList(growable: false);
    }

    return {
      'intake': bounded(
        state.intakes.map(
          (item) => _ReportRow(
            item.id,
            state.medRepo.getById(item.drugId)?.genericName ?? item.drugId,
            item.takenAt,
          ),
        ),
        200,
      ),
      'observation': bounded(
        state.observations.map(
          (item) => _ReportRow(
            item.id,
            item.summary(
              chinese: state.userProfile.displayLocale.startsWith('zh'),
            ),
            item.occurredAt,
          ),
        ),
        128,
      ),
      'question': bounded(
        state.discussionNotes.map(
          (item) => _ReportRow(item.id, item.text, item.recordedAt),
        ),
        60,
      ),
      'medication': bounded(
        state.medicationDiscussionEntries.map(
          (item) => _ReportRow(
            item.id,
            '${item.name}${item.question == null ? '' : ' · ${item.question}'}',
            item.recordedAt,
          ),
        ),
        128,
      ),
      'followup': bounded(
        state
            .followups(now: _asOf)
            .where((item) => !item.isClosed)
            .map(
              (item) => _ReportRow(
                item.prompt.id,
                item.prompt.explanation,
                item.latestFeedback?.occurredAt ?? item.prompt.createdAt,
              ),
            ),
        128,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final lease = _lease;
    final current =
        lease != null && state.isVisitPreparationLeaseCurrent(lease);
    return Scaffold(
      appBar: AppBar(
        title: Text(_t('选择访前报告内容', 'Choose visit report contents')),
      ),
      body: !current
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _error ??
                          _t(
                            '记录或会话已变化，请重新检查所选内容。',
                            'The records or session changed. Review the selection again.',
                          ),
                    ),
                    if (lease != null &&
                        state.currentUserId == lease.owner &&
                        state.preferenceMutationSessionEpoch ==
                            lease.sessionEpoch)
                      TextButton(
                        key: const ValueKey('visit-selection-reload'),
                        onPressed: () =>
                            setState(() => _reload(state, selectShown: false)),
                        child: Text(
                          _t(
                            '重新加载，不自动选入新记录',
                            'Reload with no records selected',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            )
          : _contents(state),
    );
  }

  Widget _contents(AppState state) {
    final rows = _rows(state);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _t(
            '只导出你选择的记录与问题。未选记录保留在本地；报告不作诊断或用药建议。',
            'Export only the records and questions you choose. Unselected records remain local; this report provides no diagnosis or medication advice.',
          ),
        ),
        const SizedBox(height: 12),
        PersonalLogDateButton(
          key: const ValueKey('visit-report-date-window'),
          zoneId: state.userProfile.timezone,
          selection: _window,
          maxDays: 366,
          onChanged: (value) => setState(() {
            _window = value;
            _asOf = _now;
            for (final ids in _chosen.values) {
              ids.clear();
            }
          }),
        ),
        Text(
          '${_t('声明时区', 'Declared timezone')}: ${state.userProfile.timezone}',
        ),
        Text(
          _t(
            '日期变化后需重新选择记录。摄入证据最多显示最近200条，观察/药品事项/提示128条，问题60条。',
            'Changing dates clears the selection. Shown limits: latest 200 intake records, 128 observations, medicine items or prompts, and 60 questions.',
          ),
        ),
        SwitchListTile(
          key: const ValueKey('visit-include-current'),
          value: _currentMedications,
          title: Text(
            _t(
              '选入当前药品选择与本人自查状态',
              'Include current medicine selections and owner self-checks',
            ),
          ),
          onChanged: (value) => setState(() => _currentMedications = value),
        ),
        SwitchListTile(
          key: const ValueKey('visit-include-notes'),
          value: _recordNotes,
          title: Text(
            _t(
              '选入记录附注与原样剂量文字',
              'Include attached notes and entered dose details',
            ),
          ),
          subtitle: Text(
            _t('明确选入的问题始终保留。', 'Explicitly selected questions are retained.'),
          ),
          onChanged: (value) => setState(() => _recordNotes = value),
        ),
        SwitchListTile(
          key: const ValueKey('visit-include-updates'),
          value: _discussionUpdates,
          title: Text(
            _t(
              '选入所选药品事项在该日期内的讨论后更新',
              'Include updates in this date range for selected medicine items',
            ),
          ),
          onChanged: (value) => setState(() => _discussionUpdates = value),
        ),
        SwitchListTile(
          key: const ValueKey('visit-include-assertions'),
          value: _sourceAssertions,
          title: Text(
            _t(
              '选入所选摄入记录的来源差异',
              'Include source differences for selected intake records',
            ),
          ),
          onChanged: (value) => setState(() => _sourceAssertions = value),
        ),
        for (final entry in rows.entries) _group(entry.key, entry.value),
        const SizedBox(height: 16),
        FilledButton.icon(
          key: const ValueKey('visit-selected-preview'),
          onPressed: _preview,
          icon: const Icon(Icons.description_outlined),
          label: Text(_t('预览所选报告', 'Preview selected report')),
        ),
      ],
    );
  }

  Widget _group(String kind, List<_ReportRow> rows) {
    final title = switch (kind) {
      'intake' => _t(
        '摄入证据（每种药品取最近所选记录）',
        'Intake evidence (latest selected record per medicine)',
      ),
      'observation' => _t('观察记录', 'Observations'),
      'question' => _t('本人问题', 'Owner questions'),
      'medication' => _t(
        '药品讨论事项及问题',
        'Medicine discussion items and questions',
      ),
      _ => _t('待讨论提示', 'Open discussion prompts'),
    };
    final chosen = _chosen[kind]!;
    return ExpansionTile(
      key: ValueKey('visit-selection-$kind'),
      title: Text(title),
      subtitle: Text('${chosen.length}/${rows.length} ${_t('已选', 'selected')}'),
      children: [
        Wrap(
          children: [
            TextButton(
              key: ValueKey('visit-select-all-$kind'),
              onPressed: () =>
                  setState(() => chosen.addAll(rows.map((row) => row.id))),
              child: Text(_t('选择显示的记录', 'Select shown records')),
            ),
            TextButton(
              key: ValueKey('visit-select-none-$kind'),
              onPressed: () => setState(chosen.clear),
              child: Text(_t('全不选', 'Select none')),
            ),
          ],
        ),
        for (final row in rows)
          CheckboxListTile(
            key: ValueKey('visit-select-$kind-${row.id}'),
            value: chosen.contains(row.id),
            title: Text(
              row.label,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              PersonalLogDateWindowResolver()
                  .displayTime(row.time, _window!.zoneId)
                  .toString(),
            ),
            onChanged: (value) => setState(() {
              value == true ? chosen.add(row.id) : chosen.remove(row.id);
            }),
          ),
      ],
    );
  }

  void _preview() {
    final state = context.read<AppState>();
    try {
      final lease = _lease!;
      if (!state.isVisitPreparationLeaseCurrent(lease)) return;
      final selection = VisitReportSelection(
        window: _window!,
        intakeIds: _chosen['intake']!,
        observationIds: _chosen['observation']!,
        questionNoteIds: _chosen['question']!,
        medicationEntryIds: _chosen['medication']!,
        followupPromptIds: _chosen['followup']!,
        includeCurrentMedications: _currentMedications,
        includeRecordNotes: _recordNotes,
        includeDiscussionUpdates: _discussionUpdates,
        includeSourceAssertions: _sourceAssertions,
      );
      final report = state.prepareVisit(now: _now, selection: selection);
      final artifact = const PersonalLogHandoffSummaryService()
          .createVisitPreparation(
            report: report,
            selection: selection,
            sourceLease: lease,
            localeTag: state.userProfile.displayLocale,
          );
      debugPrint('[CareWorkspace] selected_visit_preview:ready');
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VisitPreparationPreview(
            report: report,
            owner: lease.owner,
            localeTag: state.userProfile.displayLocale,
            sourceLease: lease,
            handoffArtifact: artifact,
            renderer: widget.renderer,
            delivery: widget.delivery,
          ),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              '无法生成报告，请检查日期与所选记录。',
              'Could not prepare the report. Check the dates and selected records.',
            ),
          ),
        ),
      );
    }
  }
}

final class _ReportRow {
  const _ReportRow(this.id, this.label, this.time);
  final String id;
  final String label;
  final DateTime time;
}
