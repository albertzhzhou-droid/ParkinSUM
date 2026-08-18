import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/recoverable_user_event.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/usecases/recoverable_event_restore_impact_service.dart';

class RecoverableEventHistoryPage extends StatefulWidget {
  const RecoverableEventHistoryPage({super.key});

  @override
  State<RecoverableEventHistoryPage> createState() =>
      _RecoverableEventHistoryPageState();
}

class _RecoverableEventHistoryPageState
    extends State<RecoverableEventHistoryPage> {
  RecoverableUserEventType? _filter;
  String? _restoringHistoryId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final revisions = state.recoverableEventHistory
        .where((entry) => _filter == null || entry.eventType == _filter)
        .toList(growable: false);
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: GlassAppBar(title: Text(i18n.tr('history.title'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            i18n.tr('history.subtitle'),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            i18n.tr('history.conflict_help'),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              FilterChip(
                                key: const ValueKey('history-filter-all'),
                                label: Text(i18n.tr('history.filter_all')),
                                selected: _filter == null,
                                onSelected: (_) =>
                                    setState(() => _filter = null),
                              ),
                              FilterChip(
                                key: const ValueKey('history-filter-meal'),
                                label: Text(i18n.tr('history.meal')),
                                selected:
                                    _filter == RecoverableUserEventType.meal,
                                onSelected: (_) => setState(
                                  () => _filter = RecoverableUserEventType.meal,
                                ),
                              ),
                              FilterChip(
                                key: const ValueKey('history-filter-intake'),
                                label: Text(i18n.tr('history.intake')),
                                selected:
                                    _filter == RecoverableUserEventType.intake,
                                onSelected: (_) => setState(
                                  () =>
                                      _filter = RecoverableUserEventType.intake,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (revisions.isEmpty)
                      GlassCard(child: Text(i18n.tr('history.empty')))
                    else
                      for (final revision in revisions) ...[
                        _RevisionCard(
                          revision: revision,
                          canRestore: state.canRestoreRecoverableEvent(
                            revision.historyId,
                          ),
                          isRestoring:
                              _restoringHistoryId == revision.historyId,
                          onRestore: () => _restore(revision),
                        ),
                        const SizedBox(height: 12),
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

  Future<void> _restore(RecoverableUserEventRevision revision) async {
    if (_restoringHistoryId != null) return;
    final state = context.read<AppState>();
    final preview = state.previewRecoverableEventRestore(revision.historyId);
    if (preview == null) {
      _showResult('history.restore_conflict');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _RestoreImpactDialog(preview: preview),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _restoringHistoryId = revision.historyId);
    final result = await state.confirmRecoverableEventRestore(preview);
    if (!mounted) return;
    setState(() => _restoringHistoryId = null);
    final key = switch (result.status) {
      RecoverableEventRestoreConfirmationStatus.committed => 'history.restored',
      RecoverableEventRestoreConfirmationStatus.committedWithRefreshFailure =>
        'history.restored_refresh_incomplete',
      RecoverableEventRestoreConfirmationStatus.blocked =>
        'history.restore_blocked',
      RecoverableEventRestoreConfirmationStatus.stalePreview ||
      RecoverableEventRestoreConfirmationStatus.busy ||
      RecoverableEventRestoreConfirmationStatus.persistenceFailed =>
        'history.restore_conflict',
    };
    _showResult(key);
  }

  void _showResult(String key) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.appI18n.tr(key))));
  }
}

class _RestoreImpactDialog extends StatelessWidget {
  const _RestoreImpactDialog({required this.preview});

  final RecoverableEventRestoreImpactPreview preview;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final targetKey =
        preview.targetAction ==
            RecoverableEventRestoreTargetAction.restorePriorState
        ? 'history.preview_target_restore'
        : 'history.preview_target_remove';
    final statusKey = switch (preview.status) {
      RecoverableEventRestoreImpactStatus.ready =>
        'history.preview_status_ready',
      RecoverableEventRestoreImpactStatus.staleRecord =>
        'history.preview_status_stale',
      RecoverableEventRestoreImpactStatus.blockedAccount =>
        'history.preview_status_account',
      RecoverableEventRestoreImpactStatus.blockedRelationships =>
        'history.preview_status_relationships',
      RecoverableEventRestoreImpactStatus.blockedIntegrity =>
        'history.preview_status_integrity',
    };
    return AlertDialog(
      key: const ValueKey('history-impact-dialog'),
      title: Text(i18n.tr('history.preview_title')),
      content: Semantics(
        container: true,
        liveRegion: true,
        label: i18n.tr('history.preview_semantics'),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              _ImpactRow(
                icon: Icons.restore_page_outlined,
                title: i18n.tr('history.preview_exact_write'),
                body: i18n.tr(targetKey),
              ),
              _ImpactRow(
                icon: Icons.account_tree_outlined,
                title: i18n.tr('history.preview_relationships_title'),
                body: i18n
                    .tr('history.preview_relationships_body', <String, String>{
                      'count': '${preview.restoredRelationships.length}',
                      'added': '${preview.addedRelationships.length}',
                      'removed': '${preview.removedRelationships.length}',
                    }),
              ),
              _ImpactRow(
                icon: Icons.auto_graph_outlined,
                title: i18n.tr('history.preview_derived_title'),
                body: i18n.tr('history.preview_derived_body'),
              ),
              _ImpactRow(
                icon: Icons.lock_clock_outlined,
                title: i18n.tr('history.preview_evidence_title'),
                body: i18n.tr('history.preview_evidence_body'),
              ),
              _ImpactRow(
                icon: Icons.fingerprint_outlined,
                title: i18n.tr('history.preview_identity_title'),
                body: i18n.tr('history.preview_identity_body', <String, String>{
                  'algorithm': _shortDigest(
                    preview.algorithmConfigurationDigest,
                  ),
                  'graph': _shortDigest(preview.relationshipGraphDigest),
                }),
              ),
              if (preview.missingRelationships.isNotEmpty)
                _ImpactRow(
                  icon: Icons.link_off_outlined,
                  title: i18n.tr('history.preview_missing_title'),
                  body: i18n.tr(
                    'history.preview_missing_body',
                    <String, String>{
                      'ids': preview.missingRelationships.join(', '),
                    },
                  ),
                  warning: true,
                ),
              const SizedBox(height: 8),
              Semantics(
                key: const ValueKey('history-impact-status'),
                label: i18n.tr(statusKey),
                child: Text(
                  i18n.tr(statusKey),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: preview.isConfirmable
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('history-impact-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(i18n.tr('history.preview_cancel')),
        ),
        FilledButton.icon(
          key: const ValueKey('history-impact-confirm'),
          onPressed: preview.isConfirmable
              ? () => Navigator.of(context).pop(true)
              : null,
          icon: const Icon(Icons.restore_outlined),
          label: Text(i18n.tr('history.preview_confirm')),
        ),
      ],
    );
  }

  static String _shortDigest(String value) =>
      value.length < 12 ? value : '${value.substring(0, 12)}…';
}

class _ImpactRow extends StatelessWidget {
  const _ImpactRow({
    required this.icon,
    required this.title,
    required this.body,
    this.warning = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? Theme.of(context).colorScheme.error
        : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RevisionCard extends StatelessWidget {
  const _RevisionCard({
    required this.revision,
    required this.canRestore,
    required this.isRestoring,
    required this.onRestore,
  });

  final RecoverableUserEventRevision revision;
  final bool canRestore;
  final bool isRestoring;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final payload = revision.afterPayload ?? revision.beforePayload;
    final title = revision.eventType == RecoverableUserEventType.meal
        ? (payload?['title'] as String?)?.trim()
        : (payload?['drugId'] as String?)?.trim();
    final eventLabel = i18n.tr(
      revision.eventType == RecoverableUserEventType.meal
          ? 'history.meal'
          : 'history.intake',
    );
    final mutationLabel = i18n.tr(
      'history.event_${revision.mutationType.name}',
    );
    return GlassCard(
      child: Semantics(
        container: true,
        label: '$eventLabel, $mutationLabel, ${title ?? revision.recordId}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                revision.eventType == RecoverableUserEventType.meal
                    ? Icons.restaurant_outlined
                    : Icons.medication_outlined,
              ),
              title: Text(title?.isNotEmpty == true ? title! : eventLabel),
              subtitle: Text(
                '$mutationLabel · ${_formatTimestamp(revision.recordedAtUtc)}\n'
                '${revision.recordId}',
              ),
              isThreeLine: true,
            ),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton.tonalIcon(
                key: ValueKey('history-restore-${revision.historyId}'),
                onPressed: canRestore && !isRestoring ? onRestore : null,
                icon: isRestoring
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.restore_outlined),
                label: Text(
                  i18n.tr(
                    canRestore
                        ? 'history.restore'
                        : 'history.restore_unavailable',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime value) => value.toLocal().toIso8601String();
}
