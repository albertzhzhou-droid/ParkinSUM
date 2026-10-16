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
import '../../core/db/portable_data_restore_store.dart';
import '../../core/models/portable_data_restore.dart';
import '../../core/services/portable_data_restore_coordinator.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/portable_schema_migration.dart';
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
    required this.authSessionEpoch,
  });

  final String rawScope;
  final String scopeKind;
  final int epoch;
  final int authSessionEpoch;
}

class _PortableExistingStateSnapshot {
  const _PortableExistingStateSnapshot({
    required this.recordIds,
    required this.recordIdDigest,
    required this.reminderProcessRevision,
    required this.reminderIds,
    required this.reminderContentDigest,
  });

  final Map<String, Set<String>> recordIds;
  final String recordIdDigest;
  final String reminderProcessRevision;
  final Set<String> reminderIds;
  final String reminderContentDigest;
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
  PortableDataRestoreRequest? _restoreRequest;
  PortableDataRestoreReceipt? _restoreReceipt;
  String? _restoreHeldReason;
  int? _restoreOwnerRevision;
  String? _restoreOwnerProtectionClass;
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
  String? _previewReminderContentDigest;
  bool _previewInvalidationScheduled = false;
  bool _hasObservedScope = false;
  String? _observedScope;
  int? _observedAuthSessionEpoch;
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

  PortableDataRestoreCoordinator? _restoreCoordinator(AppState state) {
    final database = state.services.appDatabase;
    return !FirebaseBackend.enabled && database is PortableDataRestoreStore
        ? PortableDataRestoreCoordinator(
            store: database as PortableDataRestoreStore,
            packageService: widget.packageService,
          )
        : null;
  }

  String _restoreText(AppState state, String english, String chinese) =>
      state.userProfile.displayLocale.startsWith('zh') ? chinese : english;

  bool _stateWriteIdle(AppState state) =>
      !state.isUpdatingMeals &&
      !state.isUpdatingIntakes &&
      !state.isSavingUserProfile &&
      !state.isUpdatingActiveDrugIds &&
      !state.isBootstrapping &&
      !state.isAuthBusy;

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
    final state = context.read<AppState>();
    final currentScope = state.currentUserId;
    final currentSessionEpoch = state.mealDraftSessionEpoch;
    if (!_hasObservedScope) {
      _hasObservedScope = true;
      _observedScope = currentScope;
      _observedAuthSessionEpoch = currentSessionEpoch;
      _loadStoredRestoreReceipt();
      return;
    }
    if (_observedScope != currentScope ||
        _observedAuthSessionEpoch != currentSessionEpoch) {
      // Clear every account-owned transient, including import-only text and a
      // preview with no generated artifact, synchronously before the new
      // account's build can paint.
      _observedScope = currentScope;
      _observedAuthSessionEpoch = currentSessionEpoch;
      _scopeEpoch += 1;
      _clearScopedState();
      _loadStoredRestoreReceipt();
    }
  }

  void _loadStoredRestoreReceipt() {
    final state = context.read<AppState>();
    final lease = _captureLease(state);
    final coordinator = _restoreCoordinator(state);
    if (lease == null || coordinator == null) return;
    coordinator.store
        .loadPortableRestoreReceipt(ownerScope: lease.rawScope)
        .then(
          (receipt) {
            if (receipt == null || !_isLeaseCurrent(lease)) return;
            setState(() => _restoreReceipt = receipt);
          },
          onError: (Object _, StackTrace _) {
            // A malformed or stale receipt cannot authorize undo.
          },
        );
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
      appBar: PaperAppBar(title: Text(i18n.tr('portable.title'))),
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
                    _schemaFuzzCampaignCard(context, i18n),
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
    return PaperCard(
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

  Widget _schemaFuzzCampaignCard(BuildContext context, AppI18n i18n) {
    final theme = Theme.of(context);
    return PaperCard(
      key: const ValueKey('portable-schema-fuzz-campaign'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.science_outlined, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  i18n.tr('portable.fuzz_title'),
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            i18n.tr('portable.fuzz_summary', {
              'seeds': '${PortableSchemaFuzzCampaignSummary.fixedSeedCount}',
              'partitions':
                  '${PortableSchemaFuzzCampaignSummary.lexicalAndSemanticPartitionCount}',
              'cases':
                  '${PortableSchemaFuzzCampaignSummary.retainedSyntheticCaseCount}',
              'runtimes':
                  '${PortableSchemaFuzzCampaignSummary.independentRuntimeCount}',
            }),
          ),
          const SizedBox(height: 6),
          Text(
            i18n.tr('portable.fuzz_runtime', {
              'runtime': PortableSchemaFuzzCampaignSummary.runtimeLabel,
            }),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 6),
          Text(
            i18n.tr('portable.fuzz_unicode'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Text(
            i18n.tr('portable.fuzz_boundary'),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _exportCard(BuildContext context, AppState state, AppI18n i18n) {
    final artifact = _artifact;
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.tr('portable.export_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(i18n.tr('portable.export_body')),
          const SizedBox(height: 8),
          Text(
            _restoreText(
              state,
              'The v4 backup excludes care discussions, follow-up outcomes, self-checks, drafts, and replay or currency receipts.',
              'v4 备份不含照护讨论、会后结果、自查、草稿，以及 replay/currency 回执。',
            ),
            key: const ValueKey('portable-export-exclusions'),
          ),
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
    return PaperCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            i18n.tr('portable.preview_title'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(i18n.tr('portable.preview_body')),
          if (_restoreCoordinator(state) != null) ...[
            const SizedBox(height: 8),
            Text(
              _restoreText(
                state,
                'This browser window can merge a v4 package for the same owner: profile preferences, medication selections, intakes, and meals. Existing records and recovery history stay. Packages with reminders, observations, conflicts, or evidence that cannot be preserved are held. The v4 backup excludes care discussions, follow-up outcomes, self-checks, drafts, and replay or currency receipts. Notification permission and AI consent are never imported.',
                '此浏览器窗口可合并同一所有者的 v4 包：资料偏好、药品选择、服药记录与餐食。保留已有记录与恢复历史；含提醒、观察、冲突或无法保留的来源信息时拒绝恢复。v4 备份不含照护讨论、会后结果、自查、草稿，以及 replay/currency 回执。不会导入通知权限或 AI 同意。',
              ),
              key: const ValueKey('portable-restore-scope'),
            ),
          ],
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
                  if (preview.schemaMigrationReceipt != null) ...[
                    const SizedBox(height: 12),
                    _schemaMigrationReceiptPreview(
                      context,
                      i18n,
                      preview.schemaMigrationReceipt!,
                    ),
                  ],
                  if (preview.reminderPresentation.totalCount > 0) ...[
                    const SizedBox(height: 12),
                    _reminderPresentationPreview(
                      context,
                      i18n,
                      preview.reminderPresentation,
                    ),
                  ],
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
                  if (_restoreCoordinator(state) != null) ...[
                    const SizedBox(height: 12),
                    if (_restoreHeldReason != null)
                      Text(
                        _restoreHeldReason!,
                        key: const ValueKey('portable-restore-held'),
                      ),
                    FilledButton.icon(
                      key: const ValueKey('portable-restore'),
                      onPressed:
                          _busy ||
                              _restoreRequest == null ||
                              !_stateWriteIdle(state)
                          ? null
                          : () => _restore(state),
                      icon: const Icon(Icons.restore_outlined),
                      label: Text(
                        _restoreText(state, 'Review and restore', '确认并恢复'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (_restoreReceipt != null) ...[
            const SizedBox(height: 12),
            Text(
              _restoreText(
                state,
                'The scoped merge was saved. You can undo it while the stored state is unchanged.',
                '已保存本次合并。存储状态未发生新变化时可撤回。',
              ),
              key: const ValueKey('portable-restore-complete'),
            ),
            OutlinedButton.icon(
              key: const ValueKey('portable-restore-rollback'),
              onPressed: _busy || !_stateWriteIdle(state)
                  ? null
                  : () => _rollbackRestore(state),
              icon: const Icon(Icons.undo_outlined),
              label: Text(_restoreText(state, 'Undo this restore', '撤回本次恢复')),
            ),
          ],
        ],
      ),
    );
  }

  Widget _reminderPresentationPreview(
    BuildContext context,
    AppI18n i18n,
    UserPortableReminderPresentationSummary summary,
  ) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('portable-reminder-presentation-preview'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.notifications_none_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  i18n.tr('portable.reminder_presentation_title'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            i18n.tr('portable.reminder_presentation_summary', {
              'total': '${summary.totalCount}',
              'enabled': '${summary.enabledIntentCount}',
              'consent': '${summary.targetConsentRequiredCount}',
            }),
          ),
          const SizedBox(height: 4),
          Text(
            i18n.tr('portable.reminder_presentation_modes', {
              'modes': summary.privacyModes.join(', '),
              'languages': summary.scheduledLanguageCodes.join(', '),
            }),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            i18n.tr('portable.reminder_presentation_policy', {
              'match': '${summary.currentPolicyMatchCount}',
              'drift': '${summary.currentPolicyDriftCount}',
              'decisions': '${summary.localeDecisionMismatchCount}',
            }),
            style: theme.textTheme.bodySmall,
          ),
          if (summary.legacyDefaultCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              i18n.tr('portable.reminder_presentation_legacy', {
                'count': '${summary.legacyDefaultCount}',
              }),
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 8),
          Text(
            i18n.tr('portable.reminder_target_consent'),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _schemaMigrationReceiptPreview(
    BuildContext context,
    AppI18n i18n,
    PortableSchemaMigrationReceipt receipt,
  ) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('portable-schema-migration-receipt'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.account_tree_outlined, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  i18n.tr('portable.migration_receipt_title'),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            i18n.tr('portable.migration_receipt_summary', {
              'source': '${receipt.sourceVersion}',
              'target': '${receipt.targetVersion}',
              'decision': receipt.decision,
            }),
          ),
          const SizedBox(height: 4),
          SelectableText(
            i18n.tr('portable.migration_receipt_identity', {
              'receipt': receipt.receiptSha256.substring(0, 16),
              'validator': receipt.sourceValidatorIdentity.substring(0, 16),
            }),
            style: theme.textTheme.bodySmall,
          ),
          if (receipt.warnings.isNotEmpty) ...[
            const SizedBox(height: 4),
            for (final warning in receipt.warnings)
              Text('• $warning', style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 6),
          Text(
            i18n.tr('portable.migration_receipt_boundary'),
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
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
          doseOwnerScope: lease.rawScope,
          scopeKind: owner.scopeKind,
          profile: current.userProfile,
          activeDrugIds: current.activeDrugIds,
          intakes: current.intakes,
          meals: current.meals,
          medicationCatalog: current.medRepo.allDrugs,
          foodCatalog: current.foodRepo.allFoods,
          reminders: reminders,
          observations: current.observations,
        ),
        generatedAt: _now,
      );
      final selfCheck = await widget.packageService.inspectAsync(
        packageJson: artifact.canonicalJson,
        currentUserScope: owner.effectiveOpaqueScope,
        currentDoseOwnerScope: lease.rawScope,
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
        currentDoseOwnerScope: lease.rawScope,
        currentScopeKind: owner.scopeKind,
        existingRecordIds: beforeSnapshot.recordIds,
      );
      PortableDataRestoreRequest? restoreRequest;
      String? restoreHeldReason;
      final coordinator = _restoreCoordinator(state);
      if (coordinator != null &&
          preview.status == UserPortableDataPreviewStatus.ready) {
        try {
          if (!_stateWriteIdle(state)) {
            throw StateError('portable_restore_state_busy');
          }
          restoreRequest = await coordinator.prepare(
            packageJson: raw,
            ownerScope: lease.rawScope,
            effectiveOwnerScope: owner.effectiveOpaqueScope,
            scopeKind: owner.scopeKind,
            foodCatalog: state.foodRepo.allFoods,
            medicationCatalog: state.medRepo.allDrugs,
            authorize: () =>
                _isLeaseCurrent(lease) &&
                _inputSha256(_importController.text.trim()) == inputSha256 &&
                _stateWriteIdle(state),
          );
        } catch (_) {
          restoreHeldReason = _restoreText(
            state,
            'Restore is held: this package has a conflict, unsupported records, or a source projection that cannot be preserved exactly.',
            '暂停恢复：该包有冲突、不支持的记录，或无法逐项保留的来源信息。',
          );
        }
      }
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
        _restoreRequest = restoreRequest;
        _restoreHeldReason = restoreHeldReason;
        _restoreOwnerRevision = restoreRequest == null ? null : owner.revision;
        _restoreOwnerProtectionClass = restoreRequest == null
            ? null
            : owner.protectionClass;
        _previewInputSha256 = inputSha256;
        _previewScopeEpoch = lease.epoch;
        _previewExistingRecordIdDigest = afterSnapshot.recordIdDigest;
        _previewReminderProcessRevision = afterSnapshot.reminderProcessRevision;
        _previewReminderIds = afterSnapshot.reminderIds;
        _previewReminderContentDigest = afterSnapshot.reminderContentDigest;
      });
    } catch (_) {
      if (_isLeaseCurrent(lease)) {
        _setError(i18n.tr('portable.error_inspect'));
      }
    } finally {
      if (_isLeaseCurrent(lease)) setState(() => _busy = false);
    }
  }

  Future<void> _restore(AppState state) async {
    final lease = _captureLease(state);
    final request = _restoreRequest;
    final coordinator = _restoreCoordinator(state);
    if (lease == null ||
        request == null ||
        coordinator == null ||
        _currentBoundPreview(state) == null ||
        !_stateWriteIdle(state)) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_restoreText(state, 'Restore these records?', '恢复这些记录？')),
        content: Text(
          _restoreText(
            state,
            'Merge the inspected records and update the exported profile preferences in this browser. Existing record IDs will never be overwritten. Reminders, observations, notification permission, and AI consent are excluded. The previous state is kept locally for undo.',
            '将已预览记录合并到此浏览器，并更新包内资料偏好。不会覆盖已有记录 ID；提醒、观察、通知权限和 AI 同意不导入。原状态保留在本地供撤回。',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_restoreText(state, 'Cancel', '取消')),
          ),
          FilledButton(
            key: const ValueKey('portable-restore-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_restoreText(state, 'Restore', '恢复')),
          ),
        ],
      ),
    );
    if (confirmed != true ||
        !_isLeaseCurrent(lease) ||
        !identical(request, _restoreRequest) ||
        _currentBoundPreview(state) == null) {
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
      if (!_isLeaseCurrent(lease) ||
          owner.revision != _restoreOwnerRevision ||
          owner.protectionClass != _restoreOwnerProtectionClass) {
        throw StateError('portable_restore_owner_capability_changed');
      }
      final freshPreview = await widget.packageService.inspectAsync(
        packageJson: _importController.text.trim(),
        currentUserScope: owner.effectiveOpaqueScope,
        currentDoseOwnerScope: lease.rawScope,
        currentScopeKind: owner.scopeKind,
      );
      final freshSnapshot = await _captureExistingStateSnapshot(lease);
      if (freshPreview.status != UserPortableDataPreviewStatus.ready ||
          freshSnapshot?.recordIdDigest != _previewExistingRecordIdDigest ||
          freshSnapshot?.reminderProcessRevision !=
              _previewReminderProcessRevision) {
        throw StateError('portable_restore_owner_or_contents_changed');
      }
      final receipt = await coordinator.commit(
        request: request,
        currentPackageJson: _importController.text.trim(),
        explicitlyConfirmed: true,
        authorize: () =>
            _isLeaseCurrent(lease) &&
            identical(request, _restoreRequest) &&
            _currentBoundPreview(state) != null &&
            _stateWriteIdle(state),
      );
      if (!_isLeaseCurrent(lease)) return;
      setState(() {
        _restoreReceipt = receipt;
        _invalidatePreviewState();
      });
      await state.bootstrap();
    } catch (_) {
      if (_isLeaseCurrent(lease)) {
        _setError(
          _restoreText(
            state,
            'Restore was not confirmed. Inspect again before retrying.',
            '未确认恢复完成，请重新预览后重试。',
          ),
        );
      }
    } finally {
      if (_isLeaseCurrent(lease)) setState(() => _busy = false);
    }
  }

  Future<void> _rollbackRestore(AppState state) async {
    final lease = _captureLease(state);
    final receipt = _restoreReceipt;
    final coordinator = _restoreCoordinator(state);
    if (lease == null || receipt == null || coordinator == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await coordinator.store.rollbackPortableRestore(
        receipt,
        ownerScope: lease.rawScope,
        authorize: () => _isLeaseCurrent(lease) && _stateWriteIdle(state),
      );
      if (!_isLeaseCurrent(lease)) return;
      setState(() {
        _restoreReceipt = null;
        _invalidatePreviewState();
      });
      await state.bootstrap();
    } catch (_) {
      if (_isLeaseCurrent(lease)) {
        _setError(
          _restoreText(
            state,
            'Undo was held because the stored state or owner changed.',
            '存储状态或所有者已变化，已拒绝撤回。',
          ),
        );
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
      currentDoseOwnerScope: lease.rawScope,
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
        _observedAuthSessionEpoch != state.mealDraftSessionEpoch ||
        context.read<AppState>().currentUserId != rawScope) {
      return null;
    }
    return _PortableOperationLease(
      rawScope: rawScope,
      scopeKind: FirebaseBackend.enabled
          ? firebasePortableScopeKind
          : localPortableScopeKind,
      epoch: _scopeEpoch,
      authSessionEpoch: state.mealDraftSessionEpoch,
    );
  }

  bool _isLeaseCurrent(_PortableOperationLease lease) =>
      mounted &&
      _hasObservedScope &&
      lease.epoch == _scopeEpoch &&
      lease.rawScope == _observedScope &&
      lease.authSessionEpoch == _observedAuthSessionEpoch &&
      lease.authSessionEpoch ==
          context.read<AppState>().mealDraftSessionEpoch &&
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
      reminderContentDigest: portableRestoreDigest(
        reminders.map((item) => item.toJson()).toList(),
      ),
    );
  }

  _PortableExistingStateSnapshot _existingStateSnapshot(
    AppState state,
    Set<String> reminderIds,
    String reminderProcessRevision, {
    required String reminderContentDigest,
  }) {
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
      'profile': state.userProfile.toJson(),
      'meals': state.meals.map((item) => item.toJson()).toList(),
      'intakes': state.intakes.map((item) => item.toJson()).toList(),
      'history': state.recoverableEventHistory
          .map((item) => item.toJson())
          .toList(),
      'observations': state.observations.map((item) => item.toJson()).toList(),
      'discussionNotes': state.discussionNotes
          .map((item) => item.toJson())
          .toList(),
      'medicationDiscussionEntries': state.medicationDiscussionEntries
          .map((item) => item.toJson())
          .toList(),
      'medicationDiscussionOutcomes': state.medicationDiscussionOutcomes
          .map((item) => item.toJson())
          .toList(),
      'medicationListReviews': state.medicationListReviews
          .map((item) => item.toJson())
          .toList(),
      'foodCatalogRevision': state.foodRepo.revision,
      'medicationCatalogRevision': state.medRepo.revision,
      'reminderContentDigest': reminderContentDigest,
    };
    final digest = sha256
        .convert(
          utf8.encode(
            'parkinsum-portable-existing-state-content-v2|'
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
      reminderContentDigest: reminderContentDigest,
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
        _previewReminderContentDigest == null ||
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
      reminderContentDigest: _previewReminderContentDigest!,
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
    _restoreRequest = null;
    _restoreHeldReason = null;
    _restoreOwnerRevision = null;
    _restoreOwnerProtectionClass = null;
    _preview = null;
    _previewInputSha256 = null;
    _previewScopeEpoch = null;
    _previewExistingRecordIdDigest = null;
    _previewReminderProcessRevision = null;
    _previewReminderIds = null;
    _previewReminderContentDigest = null;
  }

  void _clearScopedState({String? error}) {
    _restoreReceipt = null;
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
