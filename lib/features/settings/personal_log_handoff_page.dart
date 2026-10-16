import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/services/personal_log_handoff_document_service.dart';
import '../../core/services/personal_log_handoff_text_pdf_renderer.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/usecases/personal_log_handoff_summary_service.dart';

abstract interface class PersonalLogHandoffClipboard {
  Future<void> writeText(String text, {required bool Function() authorize});
}

final class SystemPersonalLogHandoffClipboard
    implements PersonalLogHandoffClipboard {
  const SystemPersonalLogHandoffClipboard();

  @override
  Future<void> writeText(
    String text, {
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('handoff_authorization_expired');
    await Clipboard.setData(ClipboardData(text: text));
  }
}

final class _HandoffLease {
  const _HandoffLease({
    required this.ownerScope,
    required this.epoch,
    required this.sessionEpoch,
  });

  final String ownerScope;
  final int epoch;
  final int sessionEpoch;
}

class PersonalLogHandoffPage extends StatefulWidget {
  const PersonalLogHandoffPage({
    super.key,
    this.summaryService = const PersonalLogHandoffSummaryService(),
    this.renderer = const SystemPersonalLogHandoffTextPdfRenderer(),
    this.htmlSerializer = const PersonalLogHandoffHtmlSerializer(),
    this.delivery = const SystemPersonalLogHandoffDelivery(),
    this.clipboard = const SystemPersonalLogHandoffClipboard(),
    this.now,
  });

  final PersonalLogHandoffSummaryService summaryService;
  final PersonalLogHandoffRenderer renderer;
  final PersonalLogHandoffHtmlSerializer htmlSerializer;
  final PersonalLogHandoffDelivery delivery;
  final PersonalLogHandoffClipboard clipboard;
  final DateTime Function()? now;

  @override
  State<PersonalLogHandoffPage> createState() => _PersonalLogHandoffPageState();
}

class _PersonalLogHandoffPageState extends State<PersonalLogHandoffPage> {
  late DateTime _startDate;
  late DateTime _endDate;
  final Set<PersonalLogHandoffSection> _sections = PersonalLogHandoffSection
      .values
      .where(
        (section) => section != PersonalLogHandoffSection.personalObservations,
      )
      .toSet();
  PersonalLogHandoffRedaction _redaction = PersonalLogHandoffRedaction.standard;
  PersonalLogHandoffArtifact? _artifact;
  Uint8List? _pdfBytes;
  int? _artifactEpoch;
  int? _artifactSessionEpoch;
  int _previewPage = 0;
  bool _busy = false;
  String? _errorCode;
  bool _hasObservedScope = false;
  String? _observedScope;
  int? _observedSessionEpoch;
  int _scopeEpoch = 0;

  DateTime get _now => (widget.now ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    final now = _now;
    _endDate = DateTime(now.year, now.month, now.day);
    _startDate = _endDate.subtract(const Duration(days: 29));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.read<AppState>();
    final scope = state.currentUserId;
    final sessionEpoch = state.mealDraftSessionEpoch;
    if (!_hasObservedScope) {
      _hasObservedScope = true;
      _observedScope = scope;
      _observedSessionEpoch = sessionEpoch;
      return;
    }
    if (_observedScope != scope || _observedSessionEpoch != sessionEpoch) {
      _observedScope = scope;
      _observedSessionEpoch = sessionEpoch;
      _scopeEpoch += 1;
      _clearArtifact();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n.fromLocaleTag(state.userProfile.displayLocale);
    final artifact = _currentArtifact(state);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: PaperAppBar(title: Text(i18n.tr('handoff.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 40),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _boundaryCard(context, i18n),
                    const SizedBox(height: 16),
                    _configurationCard(context, state, i18n),
                    if (_errorCode != null) ...[
                      const SizedBox(height: 12),
                      _errorCard(i18n),
                    ],
                    if (artifact != null) ...[
                      const SizedBox(height: 16),
                      _previewCard(context, state, artifact, i18n),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boundaryCard(BuildContext context, AppI18n i18n) => PaperCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.assignment_outlined, color: Colors.orange),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                i18n.tr('handoff.boundary_title'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(i18n.tr('handoff.boundary_body')),
        const SizedBox(height: 8),
        Text(
          i18n.tr('handoff.text_limit'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Text(
          i18n.tr('handoff.html_boundary'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _configurationCard(
    BuildContext context,
    AppState state,
    AppI18n i18n,
  ) => PaperCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          i18n.tr('handoff.configure'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('handoff-start-date'),
              onPressed: _busy ? null : () => _pickDate(start: true),
              icon: const Icon(Icons.first_page_outlined),
              label: Text(
                i18n.tr('handoff.start_date', {'date': _date(_startDate)}),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('handoff-end-date'),
              onPressed: _busy ? null : () => _pickDate(start: false),
              icon: const Icon(Icons.last_page_outlined),
              label: Text(
                i18n.tr('handoff.end_date', {'date': _date(_endDate)}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PersonalLogHandoffRedaction>(
          key: const ValueKey('handoff-redaction'),
          initialValue: _redaction,
          decoration: InputDecoration(labelText: i18n.tr('handoff.redaction')),
          items: [
            for (final level in PersonalLogHandoffRedaction.values)
              DropdownMenuItem(
                value: level,
                child: Text(i18n.tr('handoff.redaction.${level.name}')),
              ),
          ],
          onChanged: _busy
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _redaction = value;
                    _clearArtifact();
                  });
                },
        ),
        const SizedBox(height: 12),
        Text(
          i18n.tr('handoff.sections'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        for (final section in PersonalLogHandoffSection.values)
          CheckboxListTile(
            key: ValueKey('handoff-section-${section.name}'),
            contentPadding: EdgeInsets.zero,
            dense: true,
            value: _sections.contains(section),
            title: Text(i18n.tr('handoff.section.${section.name}')),
            onChanged: _busy
                ? null
                : (selected) => setState(() {
                    if (selected == true) {
                      _sections.add(section);
                    } else {
                      _sections.remove(section);
                    }
                    _clearArtifact();
                  }),
          ),
        const SizedBox(height: 12),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: FilledButton.icon(
            key: const ValueKey('handoff-generate'),
            onPressed: _busy || state.currentUserId == null || _sections.isEmpty
                ? null
                : () => _generate(state),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.preview_outlined),
            label: Text(i18n.tr('handoff.generate')),
          ),
        ),
      ],
    ),
  );

  Widget _previewCard(
    BuildContext context,
    AppState state,
    PersonalLogHandoffArtifact artifact,
    AppI18n i18n,
  ) {
    final page =
        artifact.pages[_previewPage.clamp(0, artifact.pages.length - 1)];
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.tr('handoff.exact_preview'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            i18n.tr('handoff.preview_meta', {
              'pages': '${artifact.pages.length}',
              'digest': '${artifact.contentSha256.substring(0, 16)}…',
            }),
            key: const ValueKey('handoff-preview-meta'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          ExpansionTile(
            key: const ValueKey('handoff-reading-preview'),
            tilePadding: EdgeInsets.zero,
            title: Text(i18n.tr('handoff.reading_preview')),
            subtitle: Text(i18n.tr('handoff.reading_preview_note')),
            children: [
              SelectionArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final block in artifact.documentBlocks)
                      _semanticBlock(context, block, i18n),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            label: i18n.tr('handoff.exact_preview'),
            child: AspectRatio(
              aspectRatio:
                  PersonalLogHandoffPageCanvas.pageWidth /
                  PersonalLogHandoffPageCanvas.pageHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black26),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8),
                  ],
                ),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: PersonalLogHandoffPageCanvas(
                    key: ValueKey('handoff-preview-page-${page.number}'),
                    page: page,
                    totalPages: artifact.pages.length,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                key: const ValueKey('handoff-preview-previous'),
                tooltip: i18n.tr('common.previous'),
                onPressed: _previewPage > 0
                    ? () => setState(() => _previewPage -= 1)
                    : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Text('${page.number}/${artifact.pages.length}'),
              IconButton(
                key: const ValueKey('handoff-preview-next'),
                tooltip: i18n.tr('common.next'),
                onPressed: _previewPage + 1 < artifact.pages.length
                    ? () => setState(() => _previewPage += 1)
                    : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('handoff-copy'),
                onPressed: _busy ? null : () => _copy(state, artifact),
                icon: const Icon(Icons.copy_all_outlined),
                label: Text(i18n.tr('handoff.copy')),
              ),
              Builder(
                builder: (shareContext) {
                  final renderObject = shareContext.findRenderObject();
                  final sharePositionOrigin =
                      renderObject is RenderBox && renderObject.hasSize
                      ? renderObject.localToGlobal(Offset.zero) &
                            renderObject.size
                      : null;
                  return OutlinedButton.icon(
                    key: const ValueKey('handoff-share-html'),
                    onPressed: _busy
                        ? null
                        : () =>
                              _shareHtml(state, artifact, sharePositionOrigin),
                    icon: const Icon(Icons.article_outlined),
                    label: Text(i18n.tr('handoff.share_html')),
                  );
                },
              ),
              OutlinedButton.icon(
                key: const ValueKey('handoff-print'),
                onPressed: _busy || _pdfBytes == null
                    ? null
                    : () => _print(state, artifact),
                icon: const Icon(Icons.print_outlined),
                label: Text(i18n.tr('handoff.print')),
              ),
              FilledButton.icon(
                key: const ValueKey('handoff-save-share'),
                onPressed: _busy || _pdfBytes == null
                    ? null
                    : () => _saveOrShare(state, artifact),
                icon: const Icon(Icons.save_alt_outlined),
                label: Text(i18n.tr('handoff.save_share')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorCard(AppI18n i18n) => PaperCard(
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Colors.redAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            i18n.tr('handoff.error', {'code': _errorCode ?? 'unknown'}),
            key: const ValueKey('handoff-error'),
          ),
        ),
      ],
    ),
  );

  Widget _semanticBlock(
    BuildContext context,
    PersonalLogHandoffDocumentBlock block,
    AppI18n i18n,
  ) => switch (block) {
    PersonalLogHandoffHeadingBlock(:final level, :final text) => Padding(
      padding: EdgeInsets.only(top: level == 1 ? 4 : 18, bottom: 6),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: level == 1
              ? Theme.of(context).textTheme.headlineSmall
              : Theme.of(context).textTheme.titleMedium,
        ),
      ),
    ),
    PersonalLogHandoffParagraphBlock(:final text, :final warning) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        label: warning
            ? '${i18n.tr('handoff.important_boundary')} $text'
            : text,
        child: ExcludeSemantics(
          excluding: warning,
          child: Text(
            text,
            style: warning
                ? TextStyle(color: Theme.of(context).colorScheme.error)
                : null,
          ),
        ),
      ),
    ),
    PersonalLogHandoffListBlock(:final items) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        container: true,
        label: i18n.tr('handoff.list'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: 16, bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                      child: Text([item.text, ...item.details].join('\n')),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    ),
  };

  Future<void> _pickDate({required bool start}) async {
    final initial = start ? _startDate : _endDate;
    final value = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(_now.year + 1, 12, 31),
    );
    if (!mounted || value == null) return;
    setState(() {
      if (start) {
        _startDate = value;
      } else {
        _endDate = value;
      }
      _clearArtifact();
    });
  }

  Future<void> _generate(AppState state) async {
    final lease = _captureLease(state);
    if (lease == null) return;
    setState(() {
      _busy = true;
      _errorCode = null;
      _clearArtifact();
    });
    var stage = PersonalLogHandoffFailureStage.snapshot;
    try {
      final options = _options();
      final snapshot = _snapshot(state, lease.ownerScope);
      stage = PersonalLogHandoffFailureStage.summary;
      final artifact = widget.summaryService.create(
        snapshot: snapshot,
        options: options,
        generatedAt: _now,
      );
      stage = PersonalLogHandoffFailureStage.renderPdf;
      Uint8List? pdf;
      String? fontError;
      try {
        pdf = await widget.renderer.render(
          context: context,
          artifact: artifact,
        );
      } on FormatException catch (error, stackTrace) {
        if (!const {
          'handoff_pdf_font_unavailable',
          'handoff_pdf_glyph_unavailable',
        }.contains(error.message)) {
          rethrow;
        }
        _logFailure(stage, error, stackTrace);
        fontError = error.message;
      }
      if (!mounted || !_isLeaseCurrent(lease)) return;
      stage = PersonalLogHandoffFailureStage.validateRevision;
      final currentDigest = widget.summaryService.sourceRevisionDigest(
        snapshot: _snapshot(context.read<AppState>(), lease.ownerScope),
        options: options,
      );
      if (currentDigest != artifact.sourceRevisionSha256) {
        throw StateError('source_revision_changed');
      }
      setState(() {
        _artifact = artifact;
        _pdfBytes = pdf;
        _artifactEpoch = lease.epoch;
        _artifactSessionEpoch = lease.sessionEpoch;
        _previewPage = 0;
        _errorCode = fontError;
      });
      _debug('generated', artifact);
    } catch (error, stackTrace) {
      _logFailure(stage, error, stackTrace);
      if (!mounted) return;
      setState(() {
        _clearArtifact();
        _errorCode = _safeErrorCode(error);
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(
    AppState state,
    PersonalLogHandoffArtifact artifact,
  ) async {
    final lease = _validatedLease(state, artifact);
    if (lease == null) return;
    await _runDelivery(
      artifact,
      () => widget.clipboard.writeText(
        artifact.plainText,
        authorize: () => _artifactIsCurrent(lease, artifact),
      ),
      'copied',
    );
  }

  Future<void> _print(
    AppState state,
    PersonalLogHandoffArtifact artifact,
  ) async {
    final lease = _validatedLease(state, artifact);
    final bytes = _pdfBytes;
    if (lease == null || bytes == null) return;
    await _runDelivery(
      artifact,
      () => widget.delivery.printPdf(
        bytes: bytes,
        fileName: artifact.fileName,
        authorize: () => _artifactIsCurrent(lease, artifact),
      ),
      'print_requested',
    );
  }

  Future<void> _saveOrShare(
    AppState state,
    PersonalLogHandoffArtifact artifact,
  ) async {
    final lease = _validatedLease(state, artifact);
    final bytes = _pdfBytes;
    if (lease == null || bytes == null) return;
    await _runDelivery(
      artifact,
      () => widget.delivery.saveOrSharePdf(
        bytes: bytes,
        fileName: artifact.fileName,
        authorize: () => _artifactIsCurrent(lease, artifact),
      ),
      'save_share_requested',
    );
  }

  Future<void> _shareHtml(
    AppState state,
    PersonalLogHandoffArtifact artifact,
    Rect? sharePositionOrigin,
  ) async {
    final lease = _validatedLease(state, artifact);
    if (lease == null) return;
    await _runDelivery(
      artifact,
      () => widget.delivery.shareHtml(
        bytes: widget.htmlSerializer.render(artifact),
        fileName: artifact.htmlFileName,
        sharePositionOrigin: sharePositionOrigin,
        authorize: () => _artifactIsCurrent(lease, artifact),
      ),
      'html_share_requested',
    );
  }

  Future<void> _runDelivery(
    PersonalLogHandoffArtifact artifact,
    Future<Object?> Function() action,
    String successCode,
  ) async {
    setState(() {
      _busy = true;
      _errorCode = null;
    });
    try {
      final result = await action();
      if (!mounted) return;
      final i18n = AppI18n.fromLocaleTag(
        context.read<AppState>().userProfile.displayLocale,
      );
      if (result == PersonalLogHandoffDeliveryStatus.cancelled) {
        _debug('delivery_cancelled', artifact);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.tr('handoff.delivery.cancelled'))),
        );
        return;
      }
      if (result == PersonalLogHandoffDeliveryStatus.downloadRequested) {
        _debug('html_download_requested', artifact);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.tr('portable.download_requested'))),
        );
        return;
      }
      if (result == PersonalLogHandoffDeliveryStatus.unavailable) {
        _debug('delivery_unavailable', artifact);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.tr('handoff.delivery.unavailable'))),
        );
        return;
      }
      _debug(successCode, artifact);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.tr('handoff.delivery.$successCode'))),
      );
    } catch (error, stackTrace) {
      _logFailure(PersonalLogHandoffFailureStage.delivery, error, stackTrace);
      if (!mounted) return;
      setState(() => _errorCode = _safeErrorCode(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  PersonalLogHandoffArtifact? _currentArtifact(AppState state) {
    final artifact = _artifact;
    final scope = state.currentUserId;
    if (artifact == null ||
        scope == null ||
        _artifactEpoch != _scopeEpoch ||
        _artifactSessionEpoch != state.mealDraftSessionEpoch ||
        scope != _observedScope) {
      return null;
    }
    try {
      final digest = widget.summaryService.sourceRevisionDigest(
        snapshot: _snapshot(state, scope),
        options: _options(),
      );
      if (digest == artifact.sourceRevisionSha256) return artifact;
    } catch (_) {
      // Any newly invalid source state must hide the shareable artifact.
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(_artifact, artifact)) {
        setState(() => _clearArtifact(errorCode: 'source_revision_changed'));
      }
    });
    return null;
  }

  _HandoffLease? _validatedLease(
    AppState state,
    PersonalLogHandoffArtifact artifact,
  ) {
    final lease = _captureLease(state);
    if (lease == null || !identical(_currentArtifact(state), artifact)) {
      setState(() => _clearArtifact(errorCode: 'source_revision_changed'));
      return null;
    }
    return lease;
  }

  _HandoffLease? _captureLease(AppState state) {
    final scope = state.currentUserId;
    if (scope == null ||
        scope.trim().isEmpty ||
        !_hasObservedScope ||
        scope != _observedScope ||
        state.mealDraftSessionEpoch != _observedSessionEpoch ||
        state.isAuthBusy) {
      return null;
    }
    return _HandoffLease(
      ownerScope: scope,
      epoch: _scopeEpoch,
      sessionEpoch: state.mealDraftSessionEpoch,
    );
  }

  bool _isLeaseCurrent(_HandoffLease lease) =>
      mounted &&
      lease.epoch == _scopeEpoch &&
      lease.ownerScope == _observedScope &&
      lease.sessionEpoch == context.read<AppState>().mealDraftSessionEpoch &&
      !context.read<AppState>().isAuthBusy &&
      context.read<AppState>().currentUserId == lease.ownerScope;

  bool _artifactIsCurrent(
    _HandoffLease lease,
    PersonalLogHandoffArtifact artifact,
  ) {
    if (!_isLeaseCurrent(lease) ||
        _artifactSessionEpoch != lease.sessionEpoch ||
        !identical(_artifact, artifact)) {
      return false;
    }
    try {
      return widget.summaryService.sourceRevisionDigest(
            snapshot: _snapshot(context.read<AppState>(), lease.ownerScope),
            options: _options(),
          ) ==
          artifact.sourceRevisionSha256;
    } catch (_) {
      return false;
    }
  }

  PersonalLogHandoffSnapshot _snapshot(AppState state, String ownerScope) =>
      PersonalLogHandoffSnapshot(
        ownerScope: ownerScope,
        profile: state.userProfile,
        activeDrugIds: state.activeDrugIds,
        intakes: state.intakes,
        meals: state.meals,
        observations: state.observations,
        medicationCatalog: state.medRepo.allDrugs,
        foodCatalog: state.foodRepo.allFoods,
      );

  PersonalLogHandoffOptions _options() => PersonalLogHandoffOptions(
    startDate: _startDate,
    endDateInclusive: _endDate,
    sections: Set<PersonalLogHandoffSection>.unmodifiable(_sections),
    redaction: _redaction,
  );

  void _clearArtifact({String? errorCode}) {
    _artifact = null;
    _pdfBytes = null;
    _artifactEpoch = null;
    _artifactSessionEpoch = null;
    _previewPage = 0;
    if (errorCode != null) _errorCode = errorCode;
  }

  String _safeErrorCode(Object error) {
    if (error is PersonalLogHandoffRenderException) {
      return 'handoff_pdf_render_failed';
    }
    if (error is FormatException) {
      final code = error.message.split(':').first;
      const codes = <String>{
        'handoff_document_blocks_missing',
        'handoff_html_byte_budget_exceeded',
        'handoff_pdf_pixel_ratio_invalid',
        'handoff_pdf_context_disposed',
        'handoff_pdf_render_timeout',
        'handoff_pdf_byte_budget_exceeded',
        'handoff_pdf_font_unavailable',
        'handoff_pdf_glyph_unavailable',
        'handoff_pdf_text_page_budget_exceeded',
        'handoff_document_language_invalid',
        'handoff_plain_text_budget_exceeded',
        'handoff_owner_missing',
        'handoff_sections_empty',
        'handoff_range_reversed',
        'handoff_range_budget_exceeded',
        'handoff_duplicate_medication_id',
        'handoff_duplicate_food_id',
        'handoff_duplicate_intake_id',
        'handoff_duplicate_meal_id',
        'handoff_duplicate_observation_id',
        'handoff_record_budget_exceeded',
        'handoff_page_budget_exceeded',
        'handoff_invalid_identifier',
        'handoff_invalid_text',
        'handoff_invalid_dose',
        'handoff_invalid_meal_number',
        'handoff_invalid_food_number',
        'handoff_nonfinite',
        'handoff_nonfinite_json',
      };
      return codes.contains(code) ? code : 'format_failed';
    }
    if (error is PersonalLogHandoffDeliveryException) {
      const codes = <String>{
        'authorization_expired',
        'print_failed',
        'save_share_failed',
        'html_share_failed',
        'html_download_failed',
        'html_download_unavailable',
        'invalid_file_name',
        'invalid_pdf_bytes',
        'invalid_html_bytes',
      };
      return codes.contains(error.code) ? error.code : 'operation_failed';
    }
    if (error is StateError && error.message == 'source_revision_changed') {
      return 'source_revision_changed';
    }
    return 'operation_failed';
  }

  void _logFailure(
    PersonalLogHandoffFailureStage stage,
    Object error,
    StackTrace stackTrace,
  ) {
    final diagnostic = error is PersonalLogHandoffRenderException
        ? error.diagnostic
        : PersonalLogHandoffFailureDiagnostic.capture(
            stage: stage,
            error: error,
            stackTrace: stackTrace,
          );
    debugPrint(diagnostic.logLine);
  }

  void _debug(String operation, PersonalLogHandoffArtifact artifact) {
    debugPrint(
      '[PersonalLogHandoff] $operation pages=${artifact.pages.length} '
      'content=${artifact.contentSha256.substring(0, 12)}',
    );
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
