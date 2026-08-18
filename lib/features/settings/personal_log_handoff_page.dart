import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/services/personal_log_handoff_document_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
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
  const _HandoffLease({required this.ownerScope, required this.epoch});

  final String ownerScope;
  final int epoch;
}

class PersonalLogHandoffPage extends StatefulWidget {
  const PersonalLogHandoffPage({
    super.key,
    this.summaryService = const PersonalLogHandoffSummaryService(),
    this.renderer = const SystemPersonalLogHandoffPdfRenderer(),
    this.delivery = const SystemPersonalLogHandoffDelivery(),
    this.clipboard = const SystemPersonalLogHandoffClipboard(),
    this.now,
  });

  final PersonalLogHandoffSummaryService summaryService;
  final PersonalLogHandoffRenderer renderer;
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
      .toSet();
  PersonalLogHandoffRedaction _redaction = PersonalLogHandoffRedaction.standard;
  PersonalLogHandoffArtifact? _artifact;
  Uint8List? _pdfBytes;
  int? _artifactEpoch;
  int _previewPage = 0;
  bool _busy = false;
  String? _errorCode;
  bool _hasObservedScope = false;
  String? _observedScope;
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
    final scope = context.read<AppState>().currentUserId;
    if (!_hasObservedScope) {
      _hasObservedScope = true;
      _observedScope = scope;
      return;
    }
    if (_observedScope != scope) {
      _observedScope = scope;
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
      appBar: GlassAppBar(title: Text(i18n.tr('handoff.title'))),
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
                    if (artifact != null && _pdfBytes != null) ...[
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

  Widget _boundaryCard(BuildContext context, AppI18n i18n) => GlassCard(
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
          i18n.tr('handoff.raster_limit'),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _configurationCard(
    BuildContext context,
    AppState state,
    AppI18n i18n,
  ) => GlassCard(
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
    return GlassCard(
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
              OutlinedButton.icon(
                key: const ValueKey('handoff-print'),
                onPressed: _busy ? null : () => _print(state, artifact),
                icon: const Icon(Icons.print_outlined),
                label: Text(i18n.tr('handoff.print')),
              ),
              FilledButton.icon(
                key: const ValueKey('handoff-save-share'),
                onPressed: _busy ? null : () => _saveOrShare(state, artifact),
                icon: const Icon(Icons.save_alt_outlined),
                label: Text(i18n.tr('handoff.save_share')),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _errorCard(AppI18n i18n) => GlassCard(
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
    try {
      final options = _options();
      final snapshot = _snapshot(state, lease.ownerScope);
      final artifact = widget.summaryService.create(
        snapshot: snapshot,
        options: options,
        generatedAt: _now,
      );
      final pdf = await widget.renderer.render(
        context: context,
        artifact: artifact,
      );
      if (!mounted || !_isLeaseCurrent(lease)) return;
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
        _previewPage = 0;
      });
      _debug('generated', artifact);
    } catch (error) {
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
      _debug(successCode, artifact);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.tr('handoff.delivery.$successCode'))),
      );
    } catch (error) {
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
        _pdfBytes == null ||
        scope == null ||
        _artifactEpoch != _scopeEpoch ||
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
        state.isAuthBusy) {
      return null;
    }
    return _HandoffLease(ownerScope: scope, epoch: _scopeEpoch);
  }

  bool _isLeaseCurrent(_HandoffLease lease) =>
      mounted &&
      lease.epoch == _scopeEpoch &&
      lease.ownerScope == _observedScope &&
      !context.read<AppState>().isAuthBusy &&
      context.read<AppState>().currentUserId == lease.ownerScope;

  bool _artifactIsCurrent(
    _HandoffLease lease,
    PersonalLogHandoffArtifact artifact,
  ) {
    if (!_isLeaseCurrent(lease) || !identical(_artifact, artifact)) {
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
    _previewPage = 0;
    if (errorCode != null) _errorCode = errorCode;
  }

  String _safeErrorCode(Object error) {
    if (error is FormatException) {
      final message = error.message.toString();
      return RegExp(r'^[a-z0-9_:.-]{1,96}$').hasMatch(message)
          ? message
          : 'format_failed';
    }
    if (error is PersonalLogHandoffDeliveryException) return error.code;
    if (error is StateError && '$error'.contains('source_revision_changed')) {
      return 'source_revision_changed';
    }
    return 'operation_failed';
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
