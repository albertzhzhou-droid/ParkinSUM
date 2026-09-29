import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/constants/clinical_evidence_source_seed.dart';
import '../../core/constants/p0_food_source_seed.dart';
import '../../core/i18n/care_workspace_copy.dart';
import '../../core/state/app_state.dart';
import '../../domain/entities/care_medication_discussion_entry.dart';
import '../../domain/entities/care_medication_discussion_outcome.dart';
import '../../domain/entities/care_medication_list_review.dart';
import '../../domain/entities/cdss_records.dart';
import '../../domain/entities/decision_support_followup.dart';
import '../../domain/entities/visit_preparation.dart';
import '../../domain/usecases/fhir_r4_medication_statement_collection_mapper.dart';
import '../../domain/usecases/source_reference_projection.dart';
import '../timeline/medication_assertion_reconciliation_page.dart';

final List<SourceDocumentRecord> _careWorkspaceSourceDocuments =
    List<SourceDocumentRecord>.unmodifiable([
      ...p0SourceDocumentSeed,
      ...clinicalEvidenceSourceDocuments,
    ]);

/// Local agenda and explicit user feedback. Viewing never records acceptance.
class CareWorkspacePage extends StatefulWidget {
  const CareWorkspacePage({super.key});

  @override
  State<CareWorkspacePage> createState() => _CareWorkspacePageState();
}

class _CareWorkspacePageState extends State<CareWorkspacePage> {
  final _note = TextEditingController();
  final _medicationName = TextEditingController();
  final _medicationIngredientLabel = TextEditingController();
  final _medicationDoseText = TextEditingController();
  final _medicationQuestion = TextEditingController();
  final _medicationOutcomeNote = TextEditingController();
  AppState? _state;
  String? _owner;
  bool _expired = false;
  bool _busy = false;
  DecisionSupportFollowupView _followupView = DecisionSupportFollowupView.open;
  bool _showMedicationDiscussionForm = false;
  Set<String>? _includedVisitObservationIds;
  String? _outcomeEntryId;
  CareMedicationDiscussionCategory _medicationCategory =
      CareMedicationDiscussionCategory.unspecified;
  CareMedicationReportedUse _medicationReportedUse =
      CareMedicationReportedUse.uncertain;
  CareMedicationDiscussionOutcomeStatus _medicationOutcomeStatus =
      CareMedicationDiscussionOutcomeStatus.notDiscussed;
  Timer? _clock;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state != null) return;
    _state = context.read<AppState>();
    _owner = _state!.currentUserId;
    _state!.addListener(_checkOwner);
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _checkOwner() {
    if (_state!.currentUserId != _owner) _expired = true;
  }

  bool get _authorized =>
      mounted &&
      !_expired &&
      _owner != null &&
      _state!.currentUserId == _owner &&
      !_state!.isAuthBusy;
  bool get _zh => _state!.userProfile.displayLocale.startsWith('zh');
  String get _localeTag => _state!.userProfile.displayLocale;
  String _t(String zh, String en) => _zh ? zh : en;

  @override
  void dispose() {
    _clock?.cancel();
    _state?.removeListener(_checkOwner);
    _note.dispose();
    _medicationName.dispose();
    _medicationIngredientLabel.dispose();
    _medicationDoseText.dispose();
    _medicationQuestion.dispose();
    _medicationOutcomeNote.dispose();
    super.dispose();
  }

  Future<void> _save(Future<bool> Function() operation) async {
    if (!_authorized || _busy) return;
    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await operation();
    } catch (_) {
      // Keep entered text and allow retry even if a service throws instead of
      // returning a failed mutation result. Never show private exception text.
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    if (!_authorized) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? careWorkspaceFollowupCopy('save.success', localeTag: _localeTag)
              : careWorkspaceFollowupCopy(
                  'save.failure',
                  localeTag: _localeTag,
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final current = state.followups();
    final currentIds = current.map((item) => item.prompt.id).toSet();
    final items = state.followupsForView(_followupView);
    final medicationEntries = state.medicationDiscussionEntries;
    final canExportMedicationEntries =
        !_busy &&
        state.isCareWorkspaceReady &&
        medicationEntries.isNotEmpty &&
        medicationEntries.length <=
            FhirR4MedicationStatementCollectionMapper.maximumEntries &&
        medicationEntries.every((entry) => entry.recorderId == _owner);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: AppBar(
        title: Text(_t('就诊准备与待核实事项', 'Visit preparation & follow-ups')),
      ),
      body: !_authorized
          ? Center(
              child: Text(
                _t('账号已更改，请重新打开。', 'Account changed. Please reopen this page.'),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      _t(
                        '整理记录，带着具体问题就诊',
                        'Bring your records and questions to your visit',
                      ),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        '反馈、观察与问题按账号保存在此设备，暂不包含在现有数据包备份中。状态由本人记录，不代表医生已核实或接受建议。',
                        'Feedback, observations and questions are stored by account on this device and are not yet included in data-package backups. These are your workflow notes, not clinician verification.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (state.careWorkspaceError != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _t(
                                  '本地记录读取或保存失败。已有数据保留，请重试。',
                                  'Local records could not be loaded or saved. Existing data is preserved; please retry.',
                                ),
                              ),
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : state.reloadCareWorkspace,
                                child: Text(_t('重新读取', 'Reload')),
                              ),
                            ],
                          ),
                        ),
                      ),
                    FilledButton.icon(
                      key: const ValueKey('care-prepare-visit'),
                      onPressed: _busy || !state.isCareWorkspaceReady
                          ? null
                          : _preview,
                      icon: const Icon(Icons.description_outlined),
                      label: Text(_t('预览就诊清单', 'Preview visit checklist')),
                    ),
                    const SizedBox(height: 16),
                    _visitObservationSelection(state),
                    const SizedBox(height: 16),
                    Text(
                      _t('用药清单自查', 'Medication list self-check'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _t(
                        '逐项查看你在应用中记录的内容。勾选只表示本人查看过，不证明清单完整、信息准确或已经临床核对。',
                        'Review each category recorded in the app. A check only records that you looked; it does not prove completeness, accuracy, or clinical reconciliation.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final section
                        in CareMedicationListReviewSection.values)
                      _medicationListReviewTile(state, section),
                    const SizedBox(height: 24),
                    Text(
                      _t(
                        '其他药品、非处方药与补充剂',
                        'Other medicines, OTC products & supplements',
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _t(
                        '手动记录只用于准备讨论。名称、所填状态和剂量未经核实，不会匹配目录或参与规则计算。',
                        'Manual entries only prepare discussion. Names, reported use and dose are unverified; they are not matched to a catalog or used by rule evaluation.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _t(
                        '可将最多 128 项复制为 FHIR R4 MedicationStatement。接收系统可能把所填状态理解为患者用药陈述；请先核对 Patient 引用和内容。',
                        'Up to 128 items can be copied as FHIR R4 MedicationStatement resources. A receiving system may treat the entered status as a medication-use statement about the Patient; check the Patient reference and content first.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('care-medication-fhir-export'),
                      onPressed: canExportMedicationEntries
                          ? _showMedicationFhirExportDialog
                          : null,
                      icon: const Icon(Icons.ios_share_outlined),
                      label: Text(
                        _t(
                          '预览 FHIR R4 用药陈述',
                          'Preview FHIR R4 medication statements',
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('care-add-medication-discussion'),
                      onPressed: _busy || !state.isCareWorkspaceReady
                          ? null
                          : () => setState(
                              () => _showMedicationDiscussionForm =
                                  !_showMedicationDiscussionForm,
                            ),
                      icon: const Icon(Icons.medication_outlined),
                      label: Text(_t('记录一项（待核实）', 'Record an item to verify')),
                    ),
                    if (_showMedicationDiscussionForm) ...[
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('care-medication-name'),
                        controller: _medicationName,
                        enabled: !_busy,
                        maxLength: 300,
                        decoration: InputDecoration(
                          labelText: _t(
                            '名称（按包装或记忆填写）',
                            'Name (as on package or remembered)',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        key: const ValueKey('care-medication-ingredient-label'),
                        controller: _medicationIngredientLabel,
                        enabled: !_busy,
                        maxLength: 300,
                        decoration: InputDecoration(
                          labelText: _t(
                            '成分标签（按包装填写，可留空；未经核实）',
                            'Ingredient label (as printed, optional; unverified)',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      DropdownButtonFormField<CareMedicationDiscussionCategory>(
                        key: const ValueKey('care-medication-category'),
                        initialValue: _medicationCategory,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _t('类别（所填）', 'Category (as entered)'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final value
                              in CareMedicationDiscussionCategory.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(_medicationCategoryLabel(value)),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                if (value != null) _medicationCategory = value;
                              }),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<CareMedicationReportedUse>(
                        key: const ValueKey('care-medication-reported-use'),
                        initialValue: _medicationReportedUse,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: _t('使用状态（所填）', 'Reported use status'),
                          border: const OutlineInputBorder(),
                        ),
                        items: [
                          for (final value in CareMedicationReportedUse.values)
                            DropdownMenuItem(
                              value: value,
                              child: Text(_medicationUseLabel(value)),
                            ),
                        ],
                        onChanged: _busy
                            ? null
                            : (value) => setState(() {
                                if (value != null) {
                                  _medicationReportedUse = value;
                                }
                              }),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        key: const ValueKey('care-medication-dose-text'),
                        controller: _medicationDoseText,
                        enabled: !_busy,
                        maxLength: 1000,
                        decoration: InputDecoration(
                          labelText: _t(
                            '剂量、频次或时间（原样文字，可留空）',
                            'Dose, frequency or timing (free text; optional)',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      TextField(
                        key: const ValueKey('care-medication-question'),
                        controller: _medicationQuestion,
                        enabled: !_busy,
                        maxLength: 1000,
                        minLines: 1,
                        maxLines: 3,
                        decoration: InputDecoration(
                          labelText: _t(
                            '想核实的问题（可留空）',
                            'Question to verify (optional)',
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilledButton.icon(
                            key: const ValueKey(
                              'care-save-medication-discussion',
                            ),
                            onPressed: _busy ? null : _saveMedicationDiscussion,
                            icon: const Icon(Icons.save_outlined),
                            label: Text(_t('保存待核实条目', 'Save item to verify')),
                          ),
                          TextButton(
                            key: const ValueKey(
                              'care-cancel-medication-discussion',
                            ),
                            onPressed: _busy
                                ? null
                                : () => setState(
                                    () => _showMedicationDiscussionForm = false,
                                  ),
                            child: Text(_t('收起', 'Cancel')),
                          ),
                        ],
                      ),
                    ],
                    for (final entry in state.medicationDiscussionEntries)
                      _medicationDiscussionCard(state, entry),
                    const SizedBox(height: 24),
                    Text(
                      _t('想讨论的问题', 'Questions to discuss'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      key: const ValueKey('care-note-input'),
                      controller: _note,
                      enabled: !_busy && state.isCareWorkspaceReady,
                      minLines: 2,
                      maxLines: 4,
                      maxLength: 2000,
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        hintText: _t(
                          '例如：补充剂、用药记录中的疑问，或想向医生确认的观察。',
                          'For example: supplements, a medication record to clarify, or an observation to discuss.',
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        key: const ValueKey('care-add-note'),
                        icon: const Icon(Icons.add),
                        onPressed: _busy || !state.isCareWorkspaceReady
                            ? null
                            : () => _save(() async {
                                if (_note.text.trim().isEmpty) return false;
                                final ok = await state.addDiscussionNote(
                                  _note.text.trim(),
                                );
                                if (ok && _authorized) _note.clear();
                                return ok;
                              }),
                        label: Text(_t('保存问题', 'Save question')),
                      ),
                    ),
                    for (final note in state.discussionNotes.reversed)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(note.text),
                        subtitle: Text(note.recordedAt.toLocal().toString()),
                        trailing: IconButton(
                          key: ValueKey('care-delete-note-${note.id}'),
                          tooltip: _t('删除问题', 'Delete question'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _busy
                              ? null
                              : () => _save(
                                  () => state.deleteDiscussionNote(note.id),
                                ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    Text(
                      careWorkspaceFollowupCopy(
                        'section.title',
                        localeTag: _localeTag,
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      careWorkspaceFollowupCopy(
                        'section.boundary',
                        localeTag: _localeTag,
                      ),
                    ),
                    Text(
                      careWorkspaceFollowupCopy(
                        'feedback.boundary',
                        localeTag: _localeTag,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final view in DecisionSupportFollowupView.values)
                          ChoiceChip(
                            key: ValueKey('care-followup-filter-${view.name}'),
                            label: Text(_followupViewLabel(view)),
                            selected: _followupView == view,
                            onSelected: (selected) {
                              if (selected) {
                                setState(() => _followupView = view);
                              }
                            },
                          ),
                      ],
                    ),
                    if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(_followupEmptyMessage(_followupView)),
                      ),
                    for (final item in items)
                      _prompt(
                        item,
                        current: currentIds.contains(item.prompt.id),
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  String _followupViewLabel(DecisionSupportFollowupView view) => switch (view) {
    DecisionSupportFollowupView.open => careWorkspaceFollowupCopy(
      'view.open',
      localeTag: _localeTag,
    ),
    DecisionSupportFollowupView.needsReview => careWorkspaceFollowupCopy(
      'view.needsReview',
      localeTag: _localeTag,
    ),
    DecisionSupportFollowupView.snoozed => careWorkspaceFollowupCopy(
      'view.snoozed',
      localeTag: _localeTag,
    ),
    DecisionSupportFollowupView.all => careWorkspaceFollowupCopy(
      'view.all',
      localeTag: _localeTag,
    ),
  };

  String _followupEmptyMessage(DecisionSupportFollowupView view) =>
      switch (view) {
        DecisionSupportFollowupView.open => careWorkspaceFollowupCopy(
          'empty.open',
          localeTag: _localeTag,
        ),
        DecisionSupportFollowupView.needsReview => careWorkspaceFollowupCopy(
          'empty.needsReview',
          localeTag: _localeTag,
        ),
        DecisionSupportFollowupView.snoozed => careWorkspaceFollowupCopy(
          'empty.snoozed',
          localeTag: _localeTag,
        ),
        DecisionSupportFollowupView.all => careWorkspaceFollowupCopy(
          'empty.all',
          localeTag: _localeTag,
        ),
      };

  Widget _prompt(DecisionSupportFollowupItem item, {required bool current}) {
    final prompt = item.prompt;
    final sourceReferences = SourceReferenceProjection.resolve(
      sourceRefs: prompt.sourceRefs,
      sourceDocuments: _careWorkspaceSourceDocuments,
    );
    final closed = item.isClosed;
    final actions = closed
        ? [DecisionSupportFollowupStatus.needsReview]
        : DecisionSupportFollowupStatus.values
              .where(
                (status) =>
                    status != DecisionSupportFollowupStatus.unread &&
                    (status != item.recordedStatus ||
                        status == DecisionSupportFollowupStatus.snoozed),
              )
              .toList();
    return Card(
      key: ValueKey('care-prompt-${prompt.id}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              followupStatusLabel(
                item.status,
                chinese: _zh,
                localeTag: _localeTag,
              ),
              style: Theme.of(context).textTheme.labelLarge,
            ),
            if (!current)
              Text(
                _t(
                  '历史计算结果；当前输入已更改或原记录已移除。',
                  'Historical result; inputs changed or the original record was removed.',
                ),
              ),
            const SizedBox(height: 8),
            SelectableText(prompt.explanation),
            if (item.isSnoozed)
              Text(
                _t(
                  '延后至 ${item.snoozedUntil!.toLocal()}；到期后打开应用查看，不发送通知。',
                  'Snoozed until ${item.snoozedUntil!.toLocal()}. Reappears when you open the app; no notification is sent.',
                ),
              ),
            if (prompt.missingInputs.isNotEmpty)
              Text(
                '${_t('待补充', 'Missing information')}: ${prompt.missingInputs.join(', ')}',
              ),
            ExpansionTile(
              key: ValueKey('care-history-${prompt.id}'),
              tilePadding: EdgeInsets.zero,
              title: Text(
                careWorkspaceFollowupCopy(
                  'history.title',
                  localeTag: _localeTag,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SelectableText(
                          '${_t('规则', 'Rule')}: ${prompt.ruleId} · ${prompt.ruleVersion}\n'
                          '${_t('原记录', 'Record')}: ${prompt.sourceRecordId}',
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${_t('来源', 'Sources')}: ${prompt.sourceRefs.isEmpty ? _t('未提供', 'Not supplied') : _t('${sourceReferences.length} 条；${sourceReferences.where((reference) => reference.isResolved).length} 条已在本地目录匹配', '${sourceReferences.length} references; ${sourceReferences.where((reference) => reference.isResolved).length} matched locally')}',
                        ),
                        if (sourceReferences.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            careWorkspaceFollowupCopy(
                              'source.boundary',
                              localeTag: _localeTag,
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          for (final reference in sourceReferences)
                            _sourceReferenceDetails(reference),
                        ],
                        for (final event in item.history)
                          SelectableText(
                            '${event.occurredAt.toLocal()} · ${followupStatusLabel(event.status, chinese: _zh, localeTag: _localeTag)}'
                            ' · ${careWorkspaceFollowupCopy('history.recordedByYou', localeTag: _localeTag)}'
                            '${event.reasonCategory == null && event.reason == null ? '' : ' · ${event.reasonCategory == null ? careWorkspaceFollowupCopy('history.reasonCategoryUnclassified', localeTag: _localeTag) : followupReasonCategoryLabel(event.reasonCategory!, localeTag: _localeTag)}'}'
                            '${event.reason == null ? '' : ' · ${event.reason}'}',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final action in actions)
                  TextButton(
                    key: ValueKey('care-feedback-${prompt.id}-${action.name}'),
                    onPressed: _busy ? null : () => _feedback(item, action),
                    child: Text(
                      closed
                          ? careWorkspaceFollowupCopy(
                              'action.reopen',
                              localeTag: _localeTag,
                            )
                          : action == DecisionSupportFollowupStatus.read
                          ? careWorkspaceFollowupCopy(
                              'action.read',
                              localeTag: _localeTag,
                            )
                          : action == DecisionSupportFollowupStatus.snoozed
                          ? careWorkspaceFollowupCopy(
                              'action.snooze',
                              localeTag: _localeTag,
                            )
                          : followupStatusLabel(
                              action,
                              chinese: _zh,
                              localeTag: _localeTag,
                            ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sourceReferenceDetails(SourceReferenceResolution reference) {
    final document = reference.document;
    if (document == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: SelectableText(
          '${_t('未匹配的来源编号', 'Unresolved source reference')}: ${reference.sourceRef}',
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(document.title, style: Theme.of(context).textTheme.titleSmall),
          _sourceDetail(_t('来源编号', 'Source reference'), reference.sourceRef),
          _sourceDetail(_t('机构', 'Organization'), document.organization),
          _sourceDetail(_t('来源类别', 'Source family'), document.sourceFamily),
          _sourceDetail(_t('文档类型', 'Document type'), document.docType),
          _sourceDetail(_t('适用辖区', 'Jurisdiction'), document.jurisdiction),
          _sourceDetail(_t('目录状态', 'Registry status'), document.sourceStatus),
          _sourceDetail(
            _t('发布日期', 'Published'),
            _sourceDate(document.publishedAt),
          ),
          _sourceDetail(
            _t('生效日期', 'Effective'),
            _sourceDate(document.effectiveAt),
          ),
          _sourceDetail(
            _t('来源地址', 'Source URL'),
            document.originUrl,
            selectable: true,
          ),
          _sourceDetail(_t('许可说明', 'License note'), document.licenseNote),
        ],
      ),
    );
  }

  Widget _sourceDetail(String label, String value, {bool selectable = false}) {
    final text = '$label: $value';
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: selectable
          ? SelectableText(text, style: style)
          : Text(text, style: style),
    );
  }

  String _sourceDate(DateTime? value) {
    if (value == null) return _t('未登记', 'Not recorded');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _feedback(
    DecisionSupportFollowupItem item,
    DecisionSupportFollowupStatus status,
  ) async {
    if (!_authorized) return;
    _FeedbackReasonSelection? selection;
    if (status == DecisionSupportFollowupStatus.dismissed ||
        status == DecisionSupportFollowupStatus.notApplicable ||
        status == DecisionSupportFollowupStatus.declined) {
      selection = await showDialog<_FeedbackReasonSelection>(
        context: context,
        builder: (_) => _DismissReasonDialog(localeTag: _localeTag),
      );
      if (selection == null || !_authorized) return;
    }
    await _save(
      () => _state!.recordFollowup(
        promptId: item.prompt.id,
        status: status,
        reason: selection?.reason,
        reasonCategory: selection?.category,
        snoozedUntil: status == DecisionSupportFollowupStatus.snoozed
            ? DateTime.now().toUtc().add(const Duration(days: 1))
            : null,
      ),
    );
  }

  String _medicationCategoryLabel(CareMedicationDiscussionCategory value) =>
      switch (value) {
        CareMedicationDiscussionCategory.prescription => _t(
          '处方药（所填）',
          'Prescription (as entered)',
        ),
        CareMedicationDiscussionCategory.overTheCounter => _t(
          '非处方药（所填）',
          'Over the counter (as entered)',
        ),
        CareMedicationDiscussionCategory.vitamin => _t(
          '维生素（所填）',
          'Vitamin (as entered)',
        ),
        CareMedicationDiscussionCategory.supplement => _t(
          '补充剂（所填）',
          'Supplement (as entered)',
        ),
        CareMedicationDiscussionCategory.other => _t('其他（所填）', 'Other'),
        CareMedicationDiscussionCategory.unspecified => _t(
          '未分类',
          'Unspecified',
        ),
      };

  String _medicationUseLabel(CareMedicationReportedUse value) =>
      switch (value) {
        CareMedicationReportedUse.reportedCurrent => _t(
          '所填：目前使用',
          'Reported current',
        ),
        CareMedicationReportedUse.reportedStopped => _t(
          '所填：已停止',
          'Reported stopped',
        ),
        CareMedicationReportedUse.uncertain => _t('不确定', 'Uncertain'),
      };

  String _medicationOutcomeStatusLabel(
    CareMedicationDiscussionOutcomeStatus value,
  ) => switch (value) {
    CareMedicationDiscussionOutcomeStatus.notDiscussed => _t(
      '本人记录：尚未讨论',
      'Owner reported: not discussed',
    ),
    CareMedicationDiscussionOutcomeStatus.discussed => _t(
      '本人记录：已讨论',
      'Owner reported: discussed',
    ),
    CareMedicationDiscussionOutcomeStatus.followUpNeeded => _t(
      '本人记录：需要跟进',
      'Owner reported: follow-up needed',
    ),
    CareMedicationDiscussionOutcomeStatus.followUpReportedComplete => _t(
      '本人报告：已完成后续联系',
      'Owner reported: follow-up completed',
    ),
  };

  Widget _medicationDiscussionCard(
    AppState state,
    CareMedicationDiscussionEntry entry,
  ) {
    final history =
        state.medicationDiscussionOutcomes
            .where((outcome) => outcome.entryId == entry.id)
            .toList()
          ..sort((a, b) {
            final timeOrder = a.recordedAt.compareTo(b.recordedAt);
            return timeOrder != 0 ? timeOrder : a.id.compareTo(b.id);
          });
    final latest = history.isEmpty ? null : history.last;
    return Card(
      key: ValueKey('care-medication-${entry.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            title: Text(entry.name),
            subtitle: Text(
              [
                _medicationCategoryLabel(entry.category),
                _medicationUseLabel(entry.reportedUse),
                if (entry.doseAndScheduleText != null)
                  '${_t('所填文字', 'Entered text')}: ${entry.doseAndScheduleText}',
                if (entry.ingredientLabel != null)
                  '${_t('所填成分标签（未经核实）', 'Ingredient label (unverified)')}: ${entry.ingredientLabel}',
                if (entry.question != null)
                  '${_t('待问', 'Question')}: ${entry.question}',
                _t('录入，未核实', 'Entered, not verified'),
                if (latest != null)
                  '${_t('讨论更新', 'Discussion update')}: ${_medicationOutcomeStatusLabel(latest.status)}',
              ].join(' · '),
            ),
            trailing: IconButton(
              key: ValueKey('care-delete-medication-${entry.id}'),
              tooltip: _t(
                '删除条目及其讨论记录',
                'Delete item and its discussion history',
              ),
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy
                  ? null
                  : () => _save(
                      () => state.deleteMedicationDiscussionEntry(entry.id),
                    ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: ValueKey('care-medication-outcome-${entry.id}'),
              onPressed: _busy
                  ? null
                  : () => setState(() {
                      if (_outcomeEntryId == entry.id) {
                        _outcomeEntryId = null;
                      } else {
                        _outcomeEntryId = entry.id;
                        _medicationOutcomeNote.clear();
                        _medicationOutcomeStatus =
                            CareMedicationDiscussionOutcomeStatus.notDiscussed;
                      }
                    }),
              icon: const Icon(Icons.history_edu_outlined),
              label: Text(_t('记录讨论后更新', 'Record visit update')),
            ),
          ),
          if (history.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: ValueKey('care-medication-outcome-history-${entry.id}'),
                onPressed: _busy
                    ? null
                    : () => _showMedicationDiscussionOutcomeHistory(
                        entry,
                        history,
                      ),
                icon: const Icon(Icons.receipt_long_outlined),
                label: Text(
                  _t(
                    '查看沟通记录（${history.length}）',
                    'View discussion history (${history.length})',
                  ),
                ),
              ),
            ),
          if (_outcomeEntryId == entry.id)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _t(
                      '这是本人记录的沟通状态，不是临床人员确认。每次保存都会追加历史。',
                      'This is an owner-reported communication status, not clinician verification. Each save appends to history.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<
                    CareMedicationDiscussionOutcomeStatus
                  >(
                    key: ValueKey('care-outcome-status-${entry.id}'),
                    initialValue: _medicationOutcomeStatus,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _t('本人记录的状态', 'Owner-reported status'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final value
                          in CareMedicationDiscussionOutcomeStatus.values)
                        DropdownMenuItem(
                          value: value,
                          child: Text(_medicationOutcomeStatusLabel(value)),
                        ),
                    ],
                    onChanged: _busy
                        ? null
                        : (value) => setState(() {
                            if (value != null) _medicationOutcomeStatus = value;
                          }),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    key: ValueKey('care-outcome-note-${entry.id}'),
                    controller: _medicationOutcomeNote,
                    enabled: !_busy,
                    maxLength: 1000,
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: _t('本人补充记录（可留空）', 'Owner note (optional)'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        key: ValueKey('care-save-outcome-${entry.id}'),
                        onPressed: _busy
                            ? null
                            : () => _saveMedicationDiscussionOutcome(entry.id),
                        icon: const Icon(Icons.save_outlined),
                        label: Text(_t('追加记录', 'Append update')),
                      ),
                      TextButton(
                        key: ValueKey('care-cancel-outcome-${entry.id}'),
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _outcomeEntryId = null;
                                _medicationOutcomeNote.clear();
                                _medicationOutcomeStatus =
                                    CareMedicationDiscussionOutcomeStatus
                                        .notDiscussed;
                              }),
                        child: Text(_t('取消', 'Cancel')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _medicationListReviewTile(
    AppState state,
    CareMedicationListReviewSection section,
  ) {
    final review = state.medicationListReviews
        .where((record) => record.section == section)
        .firstOrNull;
    return CheckboxListTile(
      key: ValueKey('care-medication-list-review-${section.name}'),
      contentPadding: EdgeInsets.zero,
      value: review != null,
      title: Text(switch (section) {
        CareMedicationListReviewSection.currentSelection => _t(
          '当前用药选择',
          'Current medication selections',
        ),
        CareMedicationListReviewSection.overTheCounter => _t(
          '非处方药',
          'Over-the-counter medicines',
        ),
        CareMedicationListReviewSection.vitaminsAndSupplements => _t(
          '维生素和补充剂',
          'Vitamins and supplements',
        ),
        CareMedicationListReviewSection.stoppedOrUncertain => _t(
          '已停用或状态不确定的药品',
          'Stopped or uncertain-use medicines',
        ),
      }),
      subtitle: review == null
          ? null
          : Text(
              '${_t('本人标记已查看：', 'Marked reviewed by account holder: ')}${review.recordedAt.toLocal()}',
            ),
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: _busy || !state.isCareWorkspaceReady
          ? null
          : (checked) => _save(
              () => state.setMedicationListReviewSection(
                section,
                reviewed: checked ?? false,
              ),
            ),
    );
  }

  Future<void> _showMedicationDiscussionOutcomeHistory(
    CareMedicationDiscussionEntry entry,
    List<CareMedicationDiscussionOutcome> history,
  ) async {
    if (!_authorized || history.isEmpty) return;
    final state = _state!;
    final owner = _owner!;
    final outcomes = List<CareMedicationDiscussionOutcome>.unmodifiable(
      history,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final listHeight = (MediaQuery.sizeOf(dialogContext).height * 0.48)
            .clamp(180.0, 420.0)
            .toDouble();
        return AlertDialog(
          title: Text(_t('沟通记录', 'Discussion history')),
          content: SizedBox(
            width: 480,
            height: listHeight,
            child: AnimatedBuilder(
              animation: state,
              builder: (context, _) {
                final allowed =
                    !_expired &&
                    state.currentUserId == owner &&
                    !state.isAuthBusy;
                if (!allowed) {
                  return Center(
                    child: Text(
                      _t('账号已更改，记录已隐藏。', 'Account changed. History is hidden.'),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      _t(
                        '“${entry.name}”的本人记录，未经临床人员核实。按设备记录时间（UTC）排序。',
                        'Owner-reported updates for “${entry.name}”; not clinician-verified. Sorted by device-recorded time (UTC).',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView.separated(
                        key: ValueKey('care-outcome-history-list-${entry.id}'),
                        itemCount: outcomes.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final outcome = outcomes[index];
                          return ListTile(
                            key: ValueKey(
                              'care-outcome-history-item-${outcome.id}',
                            ),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              _medicationOutcomeStatusLabel(outcome.status),
                            ),
                            subtitle: Text(
                              '${_t('设备记录时间（UTC）', 'Device-recorded time (UTC)')}: '
                              '${outcome.recordedAt.toUtc().toIso8601String()}\n'
                              '${_t('备注', 'Note')}: '
                              '${outcome.note ?? _t('未填写', 'Not entered')}',
                            ),
                            isThreeLine: true,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_t('关闭', 'Close')),
            ),
          ],
        );
      },
    );
  }

  String _medicationExportFingerprint(
    Iterable<CareMedicationDiscussionEntry> entries,
  ) {
    final rows = entries.map((entry) => jsonEncode(entry.toJson())).toList()
      ..sort();
    return jsonEncode(rows);
  }

  Future<void> _showMedicationFhirExportDialog() async {
    if (!_authorized) return;
    final state = _state!;
    final expectedOwner = _owner!;
    final entries = List<CareMedicationDiscussionEntry>.unmodifiable(
      state.medicationDiscussionEntries,
    );
    if (entries.isEmpty ||
        entries.length >
            FhirR4MedicationStatementCollectionMapper.maximumEntries ||
        entries.any((entry) => entry.recorderId != expectedOwner)) {
      return;
    }

    final expectedFingerprint = _medicationExportFingerprint(entries);
    var patientReferenceValue = '';
    String? previewJson;
    String? errorText;
    var exportExpired = false;
    var copyCompleted = false;
    StateSetter? rebuildDialog;

    bool isExportCurrent() =>
        !exportExpired &&
        _authorized &&
        state.currentUserId == expectedOwner &&
        !state.isAuthBusy &&
        _medicationExportFingerprint(state.medicationDiscussionEntries) ==
            expectedFingerprint;

    void expire(String message) {
      if (exportExpired) return;
      exportExpired = true;
      rebuildDialog?.call(() {
        previewJson = null;
        errorText = message;
      });
    }

    void observeState() {
      if (state.currentUserId != expectedOwner ||
          state.isAuthBusy ||
          !_authorized) {
        expire(
          _t(
            '账号已切换。为保护记录，本次导出已取消。',
            'The account changed. This export has been cancelled to protect the record.',
          ),
        );
      } else if (_medicationExportFingerprint(
            state.medicationDiscussionEntries,
          ) !=
          expectedFingerprint) {
        expire(
          _t(
            '记录已更改。请关闭后重新打开导出预览。',
            'The records changed. Close this dialog and reopen the export preview.',
          ),
        );
      }
    }

    state.addListener(observeState);
    try {
      final copied = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            rebuildDialog = setDialogState;
            final ownerIsCurrent = isExportCurrent();
            return AlertDialog(
              title: Text(
                _t('FHIR R4 用药陈述预览', 'FHIR R4 MedicationStatement preview'),
              ),
              content: SizedBox(
                width: 520,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        ownerIsCurrent
                            ? _t(
                                '这些是本账号录入、尚未核实的就诊讨论条目。所填“当前 / 已停止 / 不确定”会映射为 FHIR 状态 active / stopped / unknown；接收系统可能将其视为患者用药陈述。请逐项核对 Patient 引用和内容。这里只在本机预览；不会匹配 Patient、保存或上传。',
                                'These are account-entered, unverified visit-discussion items. The entered “current / stopped / uncertain” values map to FHIR statuses active / stopped / unknown; a receiving system may treat them as medication-use statements about the Patient. Check the Patient reference and content. This creates a local preview only; it does not resolve the Patient, save or upload anything.',
                              )
                            : errorText ??
                                  _t('导出已过期。', 'This export has expired.'),
                      ),
                      if (ownerIsCurrent) ...[
                        const SizedBox(height: 8),
                        Text(
                          _t(
                            '只包含所填名称、状态、录入时间和可选的剂量/频次原文；不包含成分标签、问题、类别、本地记录 ID 或录入者 ID，也不会添加药品编码。',
                            'Only the entered name, status, entry time and optional dose/frequency text are included. Ingredient labels, questions, categories, local record IDs, recorder IDs and medication codes are omitted.',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          key: const ValueKey(
                            'care-medication-fhir-patient-reference',
                          ),
                          initialValue: patientReferenceValue,
                          maxLength: 512,
                          autocorrect: false,
                          decoration: InputDecoration(
                            labelText: _t('Patient 引用', 'Patient reference'),
                            hintText: 'Patient/example',
                            border: const OutlineInputBorder(),
                          ),
                          onChanged: (value) => setDialogState(() {
                            patientReferenceValue = value;
                            previewJson = null;
                            errorText = null;
                          }),
                        ),
                      ],
                      if (errorText != null && ownerIsCurrent) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorText!,
                          key: const ValueKey(
                            'care-medication-fhir-export-error',
                          ),
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.error,
                          ),
                        ),
                      ],
                      if (previewJson != null && ownerIsCurrent) ...[
                        const SizedBox(height: 8),
                        Text(
                          _t('FHIR JSON 预览', 'FHIR JSON preview'),
                          style: Theme.of(dialogContext).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 260),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              previewJson!,
                              key: const ValueKey(
                                'care-medication-fhir-export-preview-json',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  key: const ValueKey('care-medication-fhir-export-cancel'),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: Text(_t('取消', 'Cancel')),
                ),
                OutlinedButton(
                  key: const ValueKey('care-medication-fhir-export-preview'),
                  onPressed: ownerIsCurrent
                      ? () {
                          if (!isExportCurrent()) {
                            observeState();
                            return;
                          }
                          try {
                            final bundle =
                                const FhirR4MedicationStatementCollectionMapper()
                                    .fromEntries(
                                      entries,
                                      patientReference: patientReferenceValue,
                                      ownerId: expectedOwner,
                                    );
                            setDialogState(() {
                              previewJson = const JsonEncoder.withIndent(
                                '  ',
                              ).convert(bundle);
                              errorText = null;
                            });
                            debugPrint(
                              '[CareWorkspace] FHIR R4 medication statement preview generated for ${entries.length} owner-entered items.',
                            );
                          } catch (error) {
                            setDialogState(() {
                              previewJson = null;
                              errorText = error is FormatException
                                  ? error.message
                                  : _t(
                                      '无法生成预览，请检查引用后重试。',
                                      'Could not build the preview. Check the reference and retry.',
                                    );
                            });
                          }
                        }
                      : null,
                  child: Text(_t('预览 JSON', 'Preview JSON')),
                ),
                FilledButton(
                  key: const ValueKey('care-medication-fhir-export-copy'),
                  onPressed: ownerIsCurrent && previewJson != null
                      ? () async {
                          if (!isExportCurrent()) {
                            observeState();
                            return;
                          }
                          try {
                            await Clipboard.setData(
                              ClipboardData(text: previewJson!),
                            );
                            copyCompleted = true;
                            debugPrint(
                              '[CareWorkspace] User explicitly copied the local FHIR R4 medication statement preview.',
                            );
                            if (dialogContext.mounted) {
                              Navigator.of(dialogContext).pop(true);
                            }
                          } catch (_) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              errorText = _t(
                                '复制失败。预览仍保留，请重试。',
                                'Copy failed. The preview is still available; please retry.',
                              );
                            });
                          }
                        }
                      : null,
                  child: Text(_t('复制到剪贴板', 'Copy to clipboard')),
                ),
              ],
            );
          },
        ),
      );
      if (copied == true &&
          copyCompleted &&
          mounted &&
          _authorized &&
          state.currentUserId == expectedOwner &&
          !state.isAuthBusy) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _t(
                'FHIR 用药陈述 JSON 已复制到剪贴板。',
                'FHIR medication statement JSON copied to the clipboard.',
              ),
            ),
          ),
        );
      }
    } finally {
      state.removeListener(observeState);
    }
  }

  Future<void> _saveMedicationDiscussion() async {
    if (!_authorized) return;
    final name = _medicationName.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_t('请填写名称。', 'Enter a name.'))));
      return;
    }
    final state = _state!;
    final entry = CareMedicationDiscussionEntry(
      id: state.newId('care_medication'),
      name: name,
      category: _medicationCategory,
      reportedUse: _medicationReportedUse,
      ingredientLabel: _medicationIngredientLabel.text,
      doseAndScheduleText: _medicationDoseText.text,
      question: _medicationQuestion.text,
      recordedAt: DateTime.now().toUtc(),
      recorderId: _owner!,
    );
    var saved = false;
    await _save(() async {
      saved = await state.saveMedicationDiscussionEntry(entry);
      if (saved && mounted) {
        _medicationName.clear();
        _medicationIngredientLabel.clear();
        _medicationDoseText.clear();
        _medicationQuestion.clear();
        setState(() {
          _medicationCategory = CareMedicationDiscussionCategory.unspecified;
          _medicationReportedUse = CareMedicationReportedUse.uncertain;
          _showMedicationDiscussionForm = false;
        });
      }
      return saved;
    });
  }

  Future<void> _saveMedicationDiscussionOutcome(String entryId) async {
    if (!_authorized) return;
    final state = _state!;
    final outcome = CareMedicationDiscussionOutcome(
      id: state.newId('care_medication_outcome'),
      entryId: entryId,
      status: _medicationOutcomeStatus,
      note: _medicationOutcomeNote.text,
      recordedAt: DateTime.now().toUtc(),
      recorderId: _owner!,
    );
    await _save(() async {
      final saved = await state.recordMedicationDiscussionOutcome(outcome);
      if (saved && mounted) {
        _medicationOutcomeNote.clear();
        setState(() {
          _outcomeEntryId = null;
          _medicationOutcomeStatus =
              CareMedicationDiscussionOutcomeStatus.notDiscussed;
        });
      }
      return saved;
    });
  }

  Widget _visitObservationSelection(AppState state) {
    final observations = state.observations.toList()
      ..sort((left, right) {
        final byTime = right.occurredAt.compareTo(left.occurredAt);
        return byTime != 0 ? byTime : left.id.compareTo(right.id);
      });
    final recent = observations
        .take(visitPreparationMaxItems)
        .toList(growable: false);
    final candidateIds = recent.map((item) => item.id).toSet();
    final selectedIds = _includedVisitObservationIds;
    final selectedCount = selectedIds == null
        ? recent.length
        : selectedIds.intersection(candidateIds).length;

    return ExpansionTile(
      key: const ValueKey('care-visit-observation-selection'),
      title: Text(_t('本次摘要中的观察记录', 'Observations in this report')),
      subtitle: Text(
        _t(
          '已选 $selectedCount / ${recent.length} 条',
          '$selectedCount of ${recent.length} selected',
        ),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            _t(
              '默认选入最近 128 条。选择只影响本次摘要，不删除本地记录，也不参与规则判断或临床解释。',
              'The latest 128 are selected by default. Selection only changes this report; it does not delete local records or affect rules or clinical interpretation.',
            ),
          ),
        ),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            TextButton(
              key: const ValueKey('care-visit-observation-select-all'),
              onPressed: () => setState(
                () =>
                    _includedVisitObservationIds = Set<String>.of(candidateIds),
              ),
              child: Text(_t('全选', 'Select all')),
            ),
            TextButton(
              key: const ValueKey('care-visit-observation-select-none'),
              onPressed: () =>
                  setState(() => _includedVisitObservationIds = <String>{}),
              child: Text(_t('全不选', 'Select none')),
            ),
          ],
        ),
        if (recent.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_t('暂无观察记录。', 'No observation records yet.')),
          ),
        for (final observation in recent)
          CheckboxListTile(
            key: ValueKey('care-visit-observation-${observation.id}'),
            value: selectedIds == null || selectedIds.contains(observation.id),
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(observation.summary(chinese: _zh)),
            subtitle: Text(
              [
                '${_t('发生时间', 'Occurred')}: ${observation.occurredAt.toIso8601String()}',
                if (observation.notes?.trim().isNotEmpty ?? false)
                  observation.notes!.trim(),
              ].join('\n'),
            ),
            onChanged: (include) {
              if (include == null) return;
              final next = selectedIds == null
                  ? Set<String>.of(candidateIds)
                  : Set<String>.of(selectedIds.intersection(candidateIds));
              if (include) {
                next.add(observation.id);
              } else {
                next.remove(observation.id);
              }
              setState(() => _includedVisitObservationIds = next);
            },
          ),
      ],
    );
  }

  void _preview() {
    if (!_authorized) return;
    try {
      debugPrint(
        'care_workspace.visit_preview observation_selection='
        '${_includedVisitObservationIds == null ? 'all' : _includedVisitObservationIds!.length}',
      );
      final report = _state!.prepareVisit(
        includedObservationIds: _includedVisitObservationIds,
      );
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => VisitPreparationPreview(
            report: report,
            owner: _owner!,
            localeTag: _localeTag,
          ),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _t(
              '无法生成清单，请检查本地记录后重试。',
              'Could not prepare the checklist. Check local records and retry.',
            ),
          ),
        ),
      );
    }
  }
}

final class _FeedbackReasonSelection {
  const _FeedbackReasonSelection({
    required this.category,
    required this.reason,
  });

  final DecisionSupportFeedbackReasonCategory category;
  final String reason;
}

class _DismissReasonDialog extends StatefulWidget {
  const _DismissReasonDialog({required this.localeTag});
  final String localeTag;
  @override
  State<_DismissReasonDialog> createState() => _DismissReasonDialogState();
}

class _DismissReasonDialogState extends State<_DismissReasonDialog> {
  final _text = TextEditingController();
  DecisionSupportFeedbackReasonCategory? _category;
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
    title: Text(
      careWorkspaceFollowupCopy('reason.title', localeTag: widget.localeTag),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          careWorkspaceFollowupCopy('reason.hint', localeTag: widget.localeTag),
        ),
        const SizedBox(height: 8),
        Text(
          careWorkspaceFollowupCopy(
            'reason.categoryPrompt',
            localeTag: widget.localeTag,
          ),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final category in DecisionSupportFeedbackReasonCategory.values)
              ChoiceChip(
                key: ValueKey('care-reason-category-${category.name}'),
                label: Text(
                  followupReasonCategoryLabel(
                    category,
                    localeTag: widget.localeTag,
                  ),
                ),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('care-dismiss-reason'),
          controller: _text,
          autofocus: true,
          maxLength: 2000,
          minLines: 2,
          maxLines: 4,
          onChanged: (_) => setState(() {}),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(
          careWorkspaceFollowupCopy(
            'action.cancel',
            localeTag: widget.localeTag,
          ),
        ),
      ),
      FilledButton(
        key: const ValueKey('care-save-dismiss-reason'),
        onPressed: _text.text.trim().isEmpty || _category == null
            ? null
            : () => Navigator.pop(
                context,
                _FeedbackReasonSelection(
                  category: _category!,
                  reason: _text.text.trim(),
                ),
              ),
        child: Text(
          careWorkspaceFollowupCopy(
            'action.saveReason',
            localeTag: widget.localeTag,
          ),
        ),
      ),
    ],
  );
}

class VisitPreparationPreview extends StatefulWidget {
  const VisitPreparationPreview({
    super.key,
    required this.report,
    required this.owner,
    required this.localeTag,
  });
  final VisitPreparationReport report;
  final String owner;
  final String localeTag;
  @override
  State<VisitPreparationPreview> createState() =>
      _VisitPreparationPreviewState();
}

class _VisitPreparationPreviewState extends State<VisitPreparationPreview> {
  AppState? _state;
  bool _expired = false;
  bool _copying = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_state != null) return;
    _state = context.read<AppState>();
    _state!.addListener(_checkOwner);
    _checkOwner();
  }

  void _checkOwner() {
    if (_state!.currentUserId != widget.owner) _expired = true;
  }

  @override
  void dispose() {
    _state?.removeListener(_checkOwner);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final allowed =
        !_expired && state.currentUserId == widget.owner && !state.isAuthBusy;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: AppBar(
        title: Text(
          careWorkspaceVisitCopy('preview.title', localeTag: widget.localeTag),
        ),
      ),
      body: !allowed
          ? Center(
              child: Text(
                careWorkspaceVisitCopy(
                  'preview.accountChanged',
                  localeTag: widget.localeTag,
                ),
              ),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 850),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text(
                      careWorkspaceVisitCopy(
                        'preview.privacy',
                        localeTag: widget.localeTag,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      careWorkspaceVisitCopy(
                        'preview.reportLanguage',
                        localeTag: widget.localeTag,
                      ),
                    ),
                    if (widget
                        .report
                        .medicationAssertionReviews
                        .isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        careWorkspaceVisitCopy(
                          'review.heading',
                          localeTag: widget.localeTag,
                          parameters: {
                            'count':
                                '${widget.report.medicationAssertionReviews.length}',
                          },
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        careWorkspaceVisitCopy(
                          'review.hint',
                          localeTag: widget.localeTag,
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final review
                          in widget.report.medicationAssertionReviews)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: OutlinedButton.icon(
                            key: ValueKey(
                              'visit-review-medication-${review.intakeId}',
                            ),
                            onPressed: () =>
                                _openCurrentMedicationReview(review.intakeId),
                            icon: const Icon(Icons.fact_check_outlined),
                            label: Text(
                              _medicationReviewLabel(state, review),
                              textAlign: TextAlign.start,
                            ),
                          ),
                        ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      careWorkspaceVisitCopy(
                        'agenda.heading',
                        localeTag: widget.localeTag,
                      ),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(widget.report.agendaText),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      key: const ValueKey('care-copy-agenda'),
                      onPressed: _copying ? null : _copyAgenda,
                      icon: const Icon(Icons.copy),
                      label: Text(
                        careWorkspaceVisitCopy(
                          'action.copyAgenda',
                          localeTag: widget.localeTag,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('care-copy-report'),
                      onPressed: _copying ? null : _copy,
                      icon: const Icon(Icons.description_outlined),
                      label: Text(
                        careWorkspaceVisitCopy(
                          'action.copy',
                          localeTag: widget.localeTag,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SelectableText(widget.report.plainText),
                  ],
                ),
              ),
            ),
    );
  }

  Future<void> _copy() =>
      _copyText(widget.report.plainText, successKey: 'copy.success');

  Future<void> _copyAgenda() =>
      _copyText(widget.report.agendaText, successKey: 'agenda.copy.success');

  Future<void> _copyText(String text, {required String successKey}) async {
    if (_expired ||
        _state!.currentUserId != widget.owner ||
        _state!.isAuthBusy) {
      return;
    }
    setState(() => _copying = true);
    var success = false;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      success = true;
    } catch (_) {
      /* Show a recoverable failure below. */
    }
    if (!mounted) return;
    setState(() => _copying = false);
    if (_expired || _state!.currentUserId != widget.owner) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          careWorkspaceVisitCopy(
            success ? successKey : 'copy.failure',
            localeTag: widget.localeTag,
          ),
        ),
      ),
    );
  }

  String _medicationReviewLabel(
    AppState state,
    VisitMedicationAssertionReview review,
  ) {
    final name =
        state.medRepo.getById(review.drugId)?.genericName ?? review.drugId;
    final blockingCount =
        review.blockingConflicts.length + review.omittedBlockingConflictCount;
    return careWorkspaceVisitCopy(
      'review.button',
      localeTag: widget.localeTag,
      parameters: {
        'name': name,
        'blocking': '$blockingCount',
        'findings': '${review.integrityFindings.length}',
      },
    );
  }

  void _openCurrentMedicationReview(String intakeId) {
    if (_expired ||
        _state!.currentUserId != widget.owner ||
        _state!.isAuthBusy) {
      return;
    }
    debugPrint('[CareWorkspace] visitPreparationReview:opened');
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: const RouteSettings(name: 'visit-preparation/source-review'),
        builder: (_) =>
            MedicationAssertionReconciliationPage(intakeId: intakeId),
      ),
    );
  }
}
