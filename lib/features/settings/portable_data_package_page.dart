import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/services/firebase_backend.dart';
import '../../core/services/portable_data_export_sink.dart';
import '../../core/services/portable_data_owner_scope_service.dart';
import '../../core/services/user_logging_reminder_service.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/usecases/user_portable_data_package_service.dart';

abstract interface class PortableDataClipboard {
  Future<String?> readText();

  Future<void> writeText(String text, {required bool Function() authorize});
}

class SystemPortableDataClipboard implements PortableDataClipboard {
  const SystemPortableDataClipboard();

  @override
  Future<String?> readText() async =>
      (await Clipboard.getData(Clipboard.kTextPlain))?.text;

  @override
  Future<void> writeText(
    String text, {
    required bool Function() authorize,
  }) async {
    if (!authorize()) {
      throw StateError('Portable data copy authorization expired.');
    }
    await Clipboard.setData(ClipboardData(text: text));
  }
}

class _PortableOperationLease {
  const _PortableOperationLease({
    required this.rawScope,
    required this.scopeKind,
    required this.epoch,
  });

  final String rawScope;
  final String scopeKind;
  final int epoch;
}

class _PortableExistingStateSnapshot {
  const _PortableExistingStateSnapshot({
    required this.recordIds,
    required this.recordIdDigest,
    required this.reminderProcessRevision,
    required this.reminderIds,
  });

  final Map<String, Set<String>> recordIds;
  final String recordIdDigest;
  final String reminderProcessRevision;
  final Set<String> reminderIds;
}

class PortableDataPackagePage extends StatefulWidget {
  const PortableDataPackagePage({
    super.key,
    this.packageService = const UserPortableDataPackageService(),
    this.reminderRepository,
    this.exportSink,
    this.ownerScopeResolver,
    this.clipboard,
    this.inputByteBudget,
    this.now,
  }) : assert(inputByteBudget == null || inputByteBudget > 0);

  final UserPortableDataPackageService packageService;
  final UserLoggingReminderRepository? reminderRepository;
  final PortableDataExportSink? exportSink;
  final PortableDataOwnerScopeResolver? ownerScopeResolver;
  final PortableDataClipboard? clipboard;
  final int? inputByteBudget;
  final DateTime Function()? now;

  @override
  State<PortableDataPackagePage> createState() =>
      _PortableDataPackagePageState();
}

class _PortableDataPackagePageState extends State<PortableDataPackagePage> {
  late final TextEditingController _importController;
  late final PortableDataOwnerScopeResolver _resolvedOwnerScopeResolver;
  UserPortableDataPackageArtifact? _artifact;
  UserPortableDataImportPreview? _preview;
  String? _artifactOwnerRawScope;
  String? _artifactOwnerEffectiveScope;
  String? _artifactScopeKind;
  String? _artifactOwnerProtectionClass;
  int? _artifactOwnerRevision;
  bool _artifactOwnerMigratedFromLegacy = false;
  int? _artifactScopeEpoch;
  String? _previewInputSha256;
  int? _previewScopeEpoch;
  String? _previewExistingRecordIdDigest;
  String? _previewReminderProcessRevision;
  Set<String>? _previewReminderIds;
  bool _previewInvalidationScheduled = false;
  bool _hasObservedScope = false;
  String? _observedScope;
  int _scopeEpoch = 0;
  bool _busy = false;
  String? _error;

  UserLoggingReminderRepository get _reminderRepository =>
      widget.reminderRepository ?? UserLoggingReminderRepository();

  PortableDataExportSink get _exportSink =>
      widget.exportSink ?? const PortableDataExportSink();

  PortableDataOwnerScopeResolver get _ownerScopeResolver =>
      _resolvedOwnerScopeResolver;

  PortableDataOwnerScopeManager? get _ownerScopeManager {
    final resolver = _resolvedOwnerScopeResolver;
    return resolver is PortableDataOwnerScopeManager ? resolver : null;
  }

  PortableDataClipboard get _clipboard =>
      widget.clipboard ?? const SystemPortableDataClipboard();

  DateTime get _now => (widget.now ?? DateTime.now)();

  int get _inputByteBudget =>
      widget.inputByteBudget ?? widget.packageService.maxPackageBytes;

  @override
  void initState() {
    super.initState();
    _importController = TextEditingController();
    _resolvedOwnerScopeResolver =
        widget.ownerScopeResolver ?? PersistentPortableDataOwnerScopeResolver();
    UserLoggingReminderProcessRevision.changes.addListener(
      _handleReminderProcessRevisionChanged,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final currentScope = context.read<AppState>().currentUserId;
    if (!_hasObservedScope) {
      _hasObservedScope = true;
      _observedScope = currentScope;
      return;
    }
    if (_observedScope != currentScope) {
      // Clear every account-owned transient, including import-only text and a
      // preview with no generated artifact, synchronously before the new
      // account's build can paint.
      _observedScope = currentScope;
      _scopeEpoch += 1;
      _clearScopedState();
    }
  }

  @override
  void dispose() {
    UserLoggingReminderProcessRevision.changes.removeListener(
      _handleReminderProcessRevisionChanged,
    );
    _importController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = AppI18n.fromLocaleTag(state.userProfile.displayLocale);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(i18n.tr('portable.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 28, 16, 36),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _boundaryCard(context, i18n),
                    const SizedBox(height: 16),
                    _exportCard(context, state, i18n),
                    const SizedBox(height: 16),
                    _importPreviewCard(context, state, i18n),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boundaryCard(BuildContext context, AppI18n i18n) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.lock_open_outlined, color: Colors.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  i18n.tr('portable.unencrypted_title'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(i18n.tr('portable.unencrypted_body')),
          const SizedBox(height: 10),
          Text(
            i18n.tr('portable.boundary'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _exportCard(BuildContext context, AppState state, AppI18n i18n) {
    final artifact = _artifact;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.tr('portable.export_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(i18n.tr('portable.export_body')),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              key: const ValueKey('portable-generate'),
              onPressed: _busy || state.currentUserId == null
                  ? null
                  : () => _generate(state, i18n),
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.inventory_2_outlined),
              label: Text(i18n.tr('portable.generate')),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              key: const ValueKey('portable-error'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (artifact != null) ...[
            const Divider(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.verified_outlined, size: 18),
                  label: Text(i18n.tr('portable.integrity_ready')),
                ),
                Chip(
                  label: Text(
                    i18n.tr('portable.file_count', {
                      'count': '${artifact.files.length}',
                    }),
                  ),
                ),
                Chip(
                  label: Text(
                    i18n.tr('portable.byte_count', {
                      'count': '${utf8.encode(artifact.prettyJson).length}',
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              artifact.fileName,
              key: const ValueKey('portable-file-name'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SelectableText(
              key: const ValueKey('portable-owner-protection'),
              'Package ID  ${artifact.packageId}\n'
              'Content SHA-256  ${artifact.contentSha256}\n'
              'Owner binding  ${artifact.ownerScopeSha256}\n'
              '${i18n.tr('portable.owner_protection', {'protection': _artifactOwnerProtectionClass ?? 'unavailable'})}\n'
              '${i18n.tr('portable.owner_revision', {'revision': '${_artifactOwnerRevision ?? 0}'})}'
              '${_artifactOwnerMigratedFromLegacy ? '\n${i18n.tr('portable.owner_migrated')}' : ''}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 12),
            for (final file in artifact.files)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.description_outlined, size: 20),
                title: Text(file.path),
                subtitle: Text(
                  '${file.recordCount} record(s) · ${file.sha256.substring(0, 16)}…',
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('portable-copy'),
                  onPressed: _busy ? null : () => _copy(artifact, i18n),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(i18n.tr('portable.copy')),
                ),
                FilledButton.icon(
                  key: const ValueKey('portable-save'),
                  onPressed: _busy ? null : () => _save(artifact, i18n),
                  icon: const Icon(Icons.download_outlined),
                  label: Text(i18n.tr('portable.save')),
                ),
                if (_artifactScopeKind == localPortableScopeKind &&
                    _ownerScopeManager != null)
                  OutlinedButton.icon(
                    key: const ValueKey('portable-rotate-owner-secret'),
                    onPressed: _busy
                        ? null
                        : () => _rotateOwnerSecret(state, i18n),
                    icon: const Icon(Icons.key_outlined),
                    label: Text(i18n.tr('portable.rotate_identity')),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _importPreviewCard(
    BuildContext context,
    AppState state,
    AppI18n i18n,
  ) {
    final preview = _currentBoundPreview(state);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.tr('portable.preview_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(i18n.tr('portable.preview_body')),
          const SizedBox(height: 14),
          TextField(
            key: const ValueKey('portable-import-json'),
            controller: _importController,
            minLines: 4,
            maxLines: 10,
            autocorrect: false,
            enableSuggestions: false,
            inputFormatters: <TextInputFormatter>[
              _PortableJsonInputBudgetFormatter(_inputByteBudget),
            ],
            onChanged: (_) => _invalidatePreview(),
            decoration: InputDecoration(
              labelText: i18n.tr('portable.package_json'),
              alignLabelWithHint: true,
              prefixIcon: const Icon(Icons.code_outlined),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('portable-paste'),
                onPressed: _busy || state.currentUserId == null
                    ? null
                    : () => _paste(state, i18n),
                icon: const Icon(Icons.content_paste_outlined),
                label: Text(i18n.tr('portable.paste')),
              ),
              if (_artifact != null)
                OutlinedButton.icon(
                  key: const ValueKey('portable-use-generated'),
                  onPressed: _busy
                      ? null
                      : () => _useGeneratedPackage(_artifact!.prettyJson),
                  icon: const Icon(Icons.arrow_downward_outlined),
                  label: Text(i18n.tr('portable.use_generated')),
                ),
              FilledButton.icon(
                key: const ValueKey('portable-inspect'),
                onPressed: _busy || state.currentUserId == null
                    ? null
                    : () => _inspect(state, i18n),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(i18n.tr('portable.inspect')),
              ),
            ],
          ),
          if (preview != null)
            Semantics(
              liveRegion: true,
              container: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 28),
                  Row(
                    children: [
                      Icon(
                        _previewIcon(preview.status),
                        color: _previewColor(context, preview.status),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          i18n.tr('portable.status_${preview.status.name}'),
                          key: const ValueKey('portable-preview-status'),
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    i18n.tr('portable.preview_summary', {
                      'records':
                          '${preview.recordCounts.values.fold<int>(0, (sum, value) => sum + value)}',
                      'conflicts': '${preview.conflictCount}',
                      'unsupported': '${preview.unsupportedFields.length}',
                    }),
                  ),
                  if (preview.unsupportedFields.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '${i18n.tr('portable.unsupported_fields')}: '
                      '${preview.unsupportedFields.join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                  if (preview.proposedMigrations.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    for (final item in preview.proposedMigrations)
                      Text(
                        '• $item',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                  const SizedBox(height: 8),
                  for (final finding in preview.findings)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('• $finding'),
                    ),
                  const SizedBox(height: 8),
                  Text(
                    i18n.tr('portable.no_write'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _generate(AppState state, AppI18n i18n) async {
    final lease = _captureLease(state);
    if (lease == null) {
      _setError(i18n.tr('portable.error_scope'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final owner = await _ownerScopeResolver.resolve(
        rawScope: lease.rawScope,
        scopeKind: lease.scopeKind,
      );
      if (!_isLeaseCurrent(lease)) return;
      final reminders = await _reminderRepository.load(lease.rawScope);
      if (!mounted || !_isLeaseCurrent(lease)) return;
      final current = context.read<AppState>();
      final artifact = widget.packageService.create(
        snapshot: UserPortableDataSnapshot(
          userScope: owner.effectiveOpaqueScope,
          scopeKind: owner.scopeKind,
          profile: current.userProfile,
          activeDrugIds: current.activeDrugIds,
          intakes: current.intakes,
          meals: current.meals,
          medicationCatalog: current.medRepo.allDrugs,
          foodCatalog: current.foodRepo.allFoods,
          reminders: reminders,
        ),
        generatedAt: _now,
      );
      final selfCheck = await widget.packageService.inspectAsync(
        packageJson: artifact.canonicalJson,
        currentUserScope: owner.effectiveOpaqueScope,
        currentScopeKind: owner.scopeKind,
      );
      if (!_isLeaseCurrent(lease)) return;
      if (selfCheck.status != UserPortableDataPreviewStatus.ready) {
        throw StateError('Generated package did not pass its own dry-run.');
      }
      setState(() {
        _artifact = artifact;
        // A generation self-check is not an import conflict preview. Only an
        // explicit inspection of the current text can populate `_preview`.
        _invalidatePreviewState();
        _artifactOwnerRawScope = lease.rawScope;
        _artifactOwnerEffectiveScope = owner.effectiveOpaqueScope;
        _artifactScopeKind = owner.scopeKind;
        _artifactOwnerProtectionClass = owner.protectionClass;
        _artifactOwnerRevision = owner.revision;
        _artifactOwnerMigratedFromLegacy = owner.migratedFromLegacy;
        _artifactScopeEpoch = lease.epoch;
      });
    } catch (_) {
      if (_isLeaseCurrent(lease)) {
        _setError(i18n.tr('portable.error_generate'));
      }
    } finally {
      if (_isLeaseCurrent(lease)) setState(() => _busy = false);
    }
  }

  Future<void> _rotateOwnerSecret(AppState state, AppI18n i18n) async {
    final manager = _ownerScopeManager;
    final lease = _captureLease(state);
    if (manager == null ||
        lease == null ||
        lease.scopeKind != localPortableScopeKind) {
      _setError(i18n.tr('portable.error_scope'));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(i18n.tr('portable.rotate_title')),
        content: Text(i18n.tr('portable.rotate_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            key: const ValueKey('portable-rotate-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(i18n.tr('portable.rotate_confirm')),
          ),
        ],
      ),
    );
    if (confirmed != true || !_isLeaseCurrent(lease)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await manager.rotate(
        rawScope: lease.rawScope,
        scopeKind: lease.scopeKind,
      );
      if (!mounted || !_isLeaseCurrent(lease)) return;
      setState(_clearScopedState);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(i18n.tr('portable.rotate_success'))),
      );
    } catch (_) {
      if (_isLeaseCurrent(lease)) {
        _setError(i18n.tr('portable.rotate_error'));
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _copy(
    UserPortableDataPackageArtifact artifact,
    AppI18n i18n,
  ) async {
    final initialLease = _captureLease(context.read<AppState>());
    if (initialLease == null) {
      _discardArtifact(i18n.tr('portable.error_account_changed'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final lease = await _validatedArtifactLease(artifact, initialLease, i18n);
    if (lease == null) {
      if (_isLeaseCurrent(initialLease)) setState(() => _busy = false);
      return;
    }
    try {
      await _clipboard.writeText(
        artifact.prettyJson,
        authorize: () => _isLeaseCurrent(lease),
      );
    } catch (_) {
      if (_isLeaseCurrent(lease)) {
        _setError(i18n.tr('portable.error_copy'));
        setState(() => _busy = false);
      }
      return;
    }
    if (!mounted || !_isLeaseCurrent(lease)) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(i18n.tr('portable.copied'))));
  }

  Future<void> _save(
    UserPortableDataPackageArtifact artifact,
    AppI18n i18n,
  ) async {
    final initialLease = _captureLease(context.read<AppState>());
    if (initialLease == null) {
      _discardArtifact(i18n.tr('portable.error_account_changed'));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final lease = await _validatedArtifactLease(artifact, initialLease, i18n);
    if (lease == null) {
      if (_isLeaseCurrent(initialLease)) setState(() => _busy = false);
      return;
    }
    try {
      final result = await _exportSink.save(
        fileName: artifact.fileName,
        contents: artifact.prettyJson,
        authorize: () => _isLeaseCurrent(lease),
      );
      if (!_isLeaseCurrent(lease)) return;
      if (result.delivery == 'unsupported' ||
          result.delivery == 'existing_verified' ||
          !result.userVisible) {
        await _clipboard.writeText(
          artifact.prettyJson,
          authorize: () => _isLeaseCurrent(lease),
        );
        if (!mounted || !_isLeaseCurrent(lease)) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(i18n.tr('portable.save_fallback_copied'))),
        );
        return;
      }
      final message = result.delivery == 'browser_download'
          ? i18n.tr('portable.download_requested')
          : i18n.tr('portable.saved_visible', {
              'location': result.location ?? i18n.tr('portable.downloads'),
            });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!_isLeaseCurrent(lease)) return;
      final residualFilePossible =
          error is PortableDataExportException && error.residualFilePossible;
      try {
        await _clipboard.writeText(
          artifact.prettyJson,
          authorize: () => _isLeaseCurrent(lease),
        );
        if (!_isLeaseCurrent(lease)) return;
        _setError(
          i18n.tr(
            residualFilePossible
                ? 'portable.save_failed_residual_copied'
                : 'portable.save_failed_copied',
          ),
        );
      } catch (_) {
        if (_isLeaseCurrent(lease)) {
          _setError(
            i18n.tr(
              residualFilePossible
                  ? 'portable.error_save_residual'
                  : 'portable.error_save',
            ),
          );
        }
      }
    } finally {
      if (_isLeaseCurrent(lease)) setState(() => _busy = false);
    }
  }

  Future<void> _paste(AppState state, AppI18n i18n) async {
    final lease = _captureLease(state);
    if (lease == null) {
      _setError(i18n.tr('portable.error_scope'));
      return;
    }
    String? text;
    try {
      text = await _clipboard.readText();
    } catch (_) {
      if (_isLeaseCurrent(lease)) {
        _setError(i18n.tr('portable.clipboard_empty'));
      }
      return;
    }
    if (!_isLeaseCurrent(lease)) return;
    if (text == null || text.trim().isEmpty) {
      _setError(i18n.tr('portable.clipboard_empty'));
      return;
    }
    if (!_withinInputBudget(text)) {
      _setError(i18n.tr('portable.error_input_too_large'));
      return;
    }
    _setImportText(text);
  }

  Future<void> _inspect(AppState state, AppI18n i18n) async {
    final lease = _captureLease(state);
    if (lease == null) {
      _setError(i18n.tr('portable.error_scope'));
      return;
    }
    final raw = _importController.text.trim();
    if (raw.isEmpty) {
      _setError(i18n.tr('portable.error_empty'));
      return;
    }
    if (!_withinInputBudget(raw)) {
      _setError(i18n.tr('portable.error_input_too_large'));
      return;
    }
    final inputSha256 = _inputSha256(raw);
    setState(() {
      _busy = true;
      _error = null;
      _invalidatePreviewState();
    });
    try {
      final owner = await _ownerScopeResolver.resolve(
        rawScope: lease.rawScope,
        scopeKind: lease.scopeKind,
      );
      if (!_isLeaseCurrent(lease)) return;
      final beforeSnapshot = await _captureExistingStateSnapshot(lease);
      if (beforeSnapshot == null) {
        if (_isLeaseCurrent(lease)) {
          throw StateError('Existing state changed during capture.');
        }
        return;
      }
      final preview = await widget.packageService.inspectAsync(
        packageJson: raw,
        currentUserScope: owner.effectiveOpaqueScope,
        currentScopeKind: owner.scopeKind,
        existingRecordIds: beforeSnapshot.recordIds,
      );
      if (!_isLeaseCurrent(lease) ||
          _inputSha256(_importController.text.trim()) != inputSha256) {
        return;
      }
      final afterSnapshot = await _captureExistingStateSnapshot(lease);
      if (afterSnapshot == null ||
          beforeSnapshot.recordIdDigest != afterSnapshot.recordIdDigest ||
          beforeSnapshot.reminderProcessRevision !=
              afterSnapshot.reminderProcessRevision) {
        if (_isLeaseCurrent(lease)) {
          throw StateError('Existing state changed during inspection.');
        }
        return;
      }
      if (!_isLeaseCurrent(lease) ||
          _inputSha256(_importController.text.trim()) != inputSha256) {
        return;
      }
      setState(() {
        _error = null;
        _preview = preview;
        _previewInputSha256 = inputSha256;
        _previewScopeEpoch = lease.epoch;
        _previewExistingRecordIdDigest = afterSnapshot.recordIdDigest;
        _previewReminderProcessRevision = afterSnapshot.reminderProcessRevision;
        _previewReminderIds = afterSnapshot.reminderIds;
      });
    } catch (_) {
      if (_isLeaseCurrent(lease)) {
        _setError(i18n.tr('portable.error_inspect'));
      }
    } finally {
      if (_isLeaseCurrent(lease)) setState(() => _busy = false);
    }
  }

  void _setError(String message) {
    setState(() => _error = message);
  }

  Future<_PortableOperationLease?> _validatedArtifactLease(
    UserPortableDataPackageArtifact artifact,
    _PortableOperationLease lease,
    AppI18n i18n,
  ) async {
    if (!identical(artifact, _artifact) ||
        _artifactOwnerRawScope != lease.rawScope ||
        _artifactScopeKind != lease.scopeKind ||
        _artifactScopeEpoch != lease.epoch ||
        _artifactOwnerEffectiveScope == null ||
        _artifactOwnerProtectionClass == null ||
        _artifactOwnerRevision == null) {
      _discardArtifact(i18n.tr('portable.error_account_changed'));
      return null;
    }
    final owner = await _ownerScopeResolver.resolve(
      rawScope: lease.rawScope,
      scopeKind: lease.scopeKind,
    );
    if (!_isLeaseCurrent(lease)) return null;
    if (owner.scopeKind != _artifactScopeKind ||
        owner.effectiveOpaqueScope != _artifactOwnerEffectiveScope ||
        owner.protectionClass != _artifactOwnerProtectionClass ||
        owner.revision != _artifactOwnerRevision) {
      _discardArtifact(i18n.tr('portable.error_account_changed'));
      return null;
    }
    final preview = await widget.packageService.inspectAsync(
      packageJson: artifact.prettyJson,
      currentUserScope: owner.effectiveOpaqueScope,
      currentScopeKind: owner.scopeKind,
    );
    if (!_isLeaseCurrent(lease)) return null;
    if (preview.status != UserPortableDataPreviewStatus.ready) {
      _discardArtifact(i18n.tr('portable.error_account_changed'));
      return null;
    }
    return lease;
  }

  void _discardArtifact(String message) {
    if (!mounted) return;
    setState(() {
      _clearScopedState(error: message);
    });
  }

  _PortableOperationLease? _captureLease(AppState state) {
    final rawScope = state.currentUserId;
    if (rawScope == null || rawScope.trim().isEmpty) return null;
    if (!_hasObservedScope ||
        _observedScope != rawScope ||
        context.read<AppState>().currentUserId != rawScope) {
      return null;
    }
    return _PortableOperationLease(
      rawScope: rawScope,
      scopeKind: FirebaseBackend.enabled
          ? firebasePortableScopeKind
          : localPortableScopeKind,
      epoch: _scopeEpoch,
    );
  }

  bool _isLeaseCurrent(_PortableOperationLease lease) =>
      mounted &&
      _hasObservedScope &&
      lease.epoch == _scopeEpoch &&
      lease.rawScope == _observedScope &&
      lease.scopeKind ==
          (FirebaseBackend.enabled
              ? firebasePortableScopeKind
              : localPortableScopeKind) &&
      context.read<AppState>().currentUserId == lease.rawScope;

  Future<_PortableExistingStateSnapshot?> _captureExistingStateSnapshot(
    _PortableOperationLease lease,
  ) async {
    final revisionBefore = UserLoggingReminderProcessRevision.read(
      lease.rawScope,
    );
    final reminders = await _reminderRepository.load(lease.rawScope);
    if (!mounted || !_isLeaseCurrent(lease)) return null;
    final revisionAfter = UserLoggingReminderProcessRevision.read(
      lease.rawScope,
    );
    if (revisionBefore != revisionAfter) return null;
    return _existingStateSnapshot(
      context.read<AppState>(),
      reminders.map((item) => item.id).toSet(),
      revisionAfter,
    );
  }

  _PortableExistingStateSnapshot _existingStateSnapshot(
    AppState state,
    Set<String> reminderIds,
    String reminderProcessRevision,
  ) {
    final medicationSelectionIds = <String>{
      for (final id in state.activeDrugIds)
        if (id.trim().isNotEmpty) id.trim(),
      for (final intake in state.intakes)
        if (intake.drugId.trim().isNotEmpty) intake.drugId.trim(),
    };
    final recordIds = <String, Set<String>>{
      'medication_selections.json': medicationSelectionIds,
      'intakes.json': state.intakes.map((item) => item.id).toSet(),
      'meals.json': state.meals.map((item) => item.id).toSet(),
      'reminders.json': reminderIds,
    };
    final canonicalIds = <String, Object?>{
      for (final entry in recordIds.entries)
        entry.key: (entry.value.toList()..sort()),
    };
    final digest = sha256
        .convert(
          utf8.encode(
            'parkinsum-portable-existing-record-ids-v1|'
            '${jsonEncode(canonicalIds)}',
          ),
        )
        .toString();
    return _PortableExistingStateSnapshot(
      recordIds: Map<String, Set<String>>.unmodifiable(
        recordIds.map(
          (key, value) => MapEntry(key, Set<String>.unmodifiable(value)),
        ),
      ),
      recordIdDigest: digest,
      reminderProcessRevision: reminderProcessRevision,
      reminderIds: Set<String>.unmodifiable(reminderIds),
    );
  }

  UserPortableDataImportPreview? _currentBoundPreview(AppState state) {
    final preview = _preview;
    final expectedHash = _previewInputSha256;
    if (preview == null ||
        expectedHash == null ||
        _previewScopeEpoch != _scopeEpoch ||
        _previewExistingRecordIdDigest == null ||
        _previewReminderProcessRevision == null ||
        _previewReminderIds == null ||
        _observedScope == null) {
      return null;
    }
    final raw = _importController.text.trim();
    if (!_withinInputBudget(raw) || _inputSha256(raw) != expectedHash) {
      _schedulePreviewInvalidation(preview);
      return null;
    }
    final currentSnapshot = _existingStateSnapshot(
      state,
      _previewReminderIds!,
      UserLoggingReminderProcessRevision.read(_observedScope!),
    );
    if (currentSnapshot.recordIdDigest != _previewExistingRecordIdDigest ||
        currentSnapshot.reminderProcessRevision !=
            _previewReminderProcessRevision) {
      _schedulePreviewInvalidation(preview);
      return null;
    }
    return preview;
  }

  void _handleReminderProcessRevisionChanged() {
    final preview = _preview;
    final scope = _observedScope;
    if (!mounted || preview == null || scope == null) return;
    if (UserLoggingReminderProcessRevision.read(scope) ==
        _previewReminderProcessRevision) {
      return;
    }
    setState(_invalidatePreviewState);
  }

  void _schedulePreviewInvalidation(
    UserPortableDataImportPreview expectedPreview,
  ) {
    if (_previewInvalidationScheduled) return;
    _previewInvalidationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _previewInvalidationScheduled = false;
      if (!mounted || !identical(_preview, expectedPreview)) return;
      setState(_invalidatePreviewState);
    });
  }

  void _useGeneratedPackage(String text) => _setImportText(text);

  void _setImportText(String text) {
    setState(() {
      _error = null;
      _invalidatePreviewState();
      _importController.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    });
  }

  void _invalidatePreview() {
    if (_preview == null &&
        _previewInputSha256 == null &&
        _previewScopeEpoch == null &&
        _previewExistingRecordIdDigest == null &&
        _previewReminderProcessRevision == null &&
        _previewReminderIds == null) {
      return;
    }
    setState(_invalidatePreviewState);
  }

  void _invalidatePreviewState() {
    _preview = null;
    _previewInputSha256 = null;
    _previewScopeEpoch = null;
    _previewExistingRecordIdDigest = null;
    _previewReminderProcessRevision = null;
    _previewReminderIds = null;
  }

  void _clearScopedState({String? error}) {
    _artifact = null;
    _artifactOwnerRawScope = null;
    _artifactOwnerEffectiveScope = null;
    _artifactScopeKind = null;
    _artifactOwnerProtectionClass = null;
    _artifactOwnerRevision = null;
    _artifactOwnerMigratedFromLegacy = false;
    _artifactScopeEpoch = null;
    _invalidatePreviewState();
    _importController.clear();
    _busy = false;
    _error = error;
  }

  bool _withinInputBudget(String text) =>
      text.length <= _inputByteBudget &&
      utf8.encode(text).length <= _inputByteBudget;

  String _inputSha256(String text) =>
      sha256.convert(utf8.encode(text)).toString();

  IconData _previewIcon(UserPortableDataPreviewStatus status) =>
      switch (status) {
        UserPortableDataPreviewStatus.ready => Icons.verified_outlined,
        UserPortableDataPreviewStatus.wrongOwner => Icons.person_off_outlined,
        UserPortableDataPreviewStatus.unsupportedSchema =>
          Icons.system_update_alt_outlined,
        UserPortableDataPreviewStatus.corrupt => Icons.broken_image_outlined,
      };

  Color _previewColor(
    BuildContext context,
    UserPortableDataPreviewStatus status,
  ) => switch (status) {
    UserPortableDataPreviewStatus.ready => Colors.green,
    UserPortableDataPreviewStatus.wrongOwner => Colors.orange,
    UserPortableDataPreviewStatus.unsupportedSchema => Colors.orange,
    UserPortableDataPreviewStatus.corrupt => Theme.of(
      context,
    ).colorScheme.error,
  };
}

class _PortableJsonInputBudgetFormatter extends TextInputFormatter {
  const _PortableJsonInputBudgetFormatter(this.maxBytes);

  final int maxBytes;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.length > maxBytes || utf8.encode(text).length > maxBytes) {
      return oldValue;
    }
    return newValue;
  }
}
