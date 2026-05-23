import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/state/app_state.dart';

/// 本地 P0 导入页：
/// - 允许用户指定 ZIP 或目录路径；
/// - 支持重试上次任务；
/// - 展示最近一次导入结果，便于人工验收。
class ImportPage extends StatefulWidget {
  const ImportPage({super.key});

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  final _ciqualController = TextEditingController();
  final _fdcController = TextEditingController();
  final _dailyMedController = TextEditingController();
  final _dpdController = TextEditingController();
  final _snapshotBundleController = TextEditingController();

  @override
  void dispose() {
    _ciqualController.dispose();
    _fdcController.dispose();
    _dailyMedController.dispose();
    _dpdController.dispose();
    _snapshotBundleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final result = state.latestImportTask;
    final hasSnapshotBundlePath =
        _snapshotBundleController.text.trim().isNotEmpty;
    final localizedSummary = result == null
        ? ''
        : '${result.steps.where((item) => item.succeeded).length} ${i18n.tr('import.step_status_ok')} / '
            '${result.steps.where((item) => !item.succeeded).length} ${i18n.tr('import.step_status_failed')}';
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.tr('import.title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            i18n.tr('import.description'),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Text(
            i18n.tr('import.remote_tasks'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: state.isImportingP0
                    ? null
                    : () => context
                        .read<AppState>()
                        .runRemoteImportTask('ema_medicines'),
                icon: const Icon(Icons.public),
                label: Text(i18n.tr('import.ema_medicines')),
              ),
              FilledButton.tonalIcon(
                onPressed: state.isImportingP0
                    ? null
                    : () => context
                        .read<AppState>()
                        .runRemoteImportTask('ema_post_authorisation'),
                icon: const Icon(Icons.update),
                label: Text(i18n.tr('import.ema_post_authorisation')),
              ),
              FilledButton.tonalIcon(
                onPressed: state.isImportingP0
                    ? null
                    : () => context
                        .read<AppState>()
                        .runRemoteImportTask('china_official_foods'),
                icon: const Icon(Icons.ramen_dining_outlined),
                label: Text(i18n.tr('import.china_official_foods')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PathField(
            controller: _ciqualController,
            label: i18n.tr('import.ciqual_path'),
          ),
          _PathField(
            controller: _fdcController,
            label: i18n.tr('import.fdc_path'),
          ),
          _PathField(
            controller: _dailyMedController,
            label: i18n.tr('import.dailymed_path'),
          ),
          _PathField(
            controller: _dpdController,
            label: i18n.tr('import.dpd_path'),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: state.isImportingP0
                    ? null
                    : () => context.read<AppState>().importP0FromLocalPaths(
                          ciqualPath: _emptyToNull(_ciqualController.text),
                          fdcPath: _emptyToNull(_fdcController.text),
                          dailyMedPath: _emptyToNull(_dailyMedController.text),
                          dpdPath: _emptyToNull(_dpdController.text),
                        ),
                icon: const Icon(Icons.cloud_download_outlined),
                label: Text(i18n.tr('import.run')),
              ),
              OutlinedButton.icon(
                onPressed:
                    state.isImportingP0 ? null : state.retryLastImportTask,
                icon: const Icon(Icons.refresh),
                label: Text(i18n.tr('import.retry')),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (state.isImportingP0)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        i18n.tr('import.running'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (result != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.tr('import.last_result'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(localizedSummary.isEmpty
                        ? result.summary
                        : localizedSummary),
                    const SizedBox(height: 8),
                    Text(
                        '${i18n.tr('common.completed')}: ${result.completedAt.toIso8601String()}'),
                    Text(
                        '${i18n.tr('import.source_documents')}: ${result.sourceDocumentCount}'),
                    Text(
                        '${i18n.tr('import.food_variants')}: ${result.foodCount}'),
                    Text(
                        '${i18n.tr('import.drug_variants')}: ${result.drugCount}'),
                    Text(
                        '${i18n.tr('import.observations')}: ${result.observationCount}'),
                    if (result.resolvedPaths.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      for (final entry in result.resolvedPaths.entries)
                        Text('${entry.key}: ${entry.value}'),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final step in result.steps)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${_localizedSourceLabel(i18n, step.sourceKey, step.sourceLabel)} · ${step.succeeded ? i18n.tr('import.step_status_ok') : i18n.tr('import.step_status_failed')}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          OutlinedButton(
                            onPressed: state.isImportingP0
                                ? null
                                : () => context
                                    .read<AppState>()
                                    .retryImportSource(step.sourceKey),
                            child: Text(i18n.tr('import.retry_source')),
                          ),
                          if ((step.resumeToken ?? '').trim().isNotEmpty)
                            OutlinedButton(
                              onPressed: state.isImportingP0
                                  ? null
                                  : () => context
                                      .read<AppState>()
                                      .resumeImportTask(step.resumeToken!),
                              child: const Text('Resume'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (step.runId != null)
                        Text('${i18n.tr('import.run_id')}: ${step.runId}'),
                      if (step.promotedSnapshotId != null)
                        Text(
                            '${i18n.tr('import.snapshot')}: ${step.promotedSnapshotId}'),
                      Text(
                          '${i18n.tr('common.completed')}: ${step.completedAt.toIso8601String()}'),
                      if (step.sourceDocumentCount != null)
                        Text(
                            '${i18n.tr('import.source_documents')}: ${step.sourceDocumentCount}'),
                      if (step.foodCount != null)
                        Text(
                            '${i18n.tr('import.food_variants')}: ${step.foodCount}'),
                      if (step.drugCount != null)
                        Text(
                            '${i18n.tr('import.drug_variants')}: ${step.drugCount}'),
                      if (step.observationCount != null)
                        Text(
                            '${i18n.tr('import.observations')}: ${step.observationCount}'),
                      if ((step.errorMessage ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '${i18n.tr('common.error')}: ${step.errorMessage}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if ((step.checkpoint ?? '').trim().isNotEmpty ||
                          (step.resumeToken ?? '').trim().isNotEmpty ||
                          step.attempts > 0) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Retry/checkpoint: attempt ${step.attempts == 0 ? '-' : step.attempts} · '
                          'checkpoint ${step.checkpoint ?? '-'} · '
                          'resume ${step.resumeToken ?? '-'}',
                        ),
                      ],
                      if (step.runs.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Text(i18n.tr('import.drilldown_runs')),
                          children: [
                            for (final run in step.runs)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(run.runId),
                                subtitle: Text(
                                  '${i18n.tr('import.stage')}: ${run.stage}\n'
                                  '${i18n.tr('import.status')}: ${run.status}\n'
                                  '${i18n.tr('import.snapshot')}: ${run.snapshotId}'
                                  '${run.sourceDocumentCount == null ? '' : '\n${i18n.tr('import.source_documents')}: ${run.sourceDocumentCount}'}'
                                  '${run.observationCount == null ? '' : '\n${i18n.tr('import.observations')}: ${run.observationCount}'}'
                                  '${run.resolvedFactCount == null ? '' : '\n${i18n.tr('import.fact_count')}: ${run.resolvedFactCount}'}'
                                  '${run.retryAttempt == null ? '' : '\nRetry: ${run.retryAttempt}/${run.maxAttempts ?? '-'}'}'
                                  '${(run.checkpoint ?? '').trim().isEmpty ? '' : '\nCheckpoint: ${run.checkpoint}'}'
                                  '${(run.resumeToken ?? '').trim().isEmpty ? '' : '\nResume: ${run.resumeToken}'}'
                                  '${(run.errorMessage ?? '').trim().isEmpty ? '' : '\n${i18n.tr('common.error')}: ${run.errorMessage}'}',
                                ),
                                trailing: (run.resumeToken ?? '').trim().isEmpty
                                    ? Text(
                                        _compactTime(
                                            run.completedAt ?? run.createdAt),
                                      )
                                    : IconButton(
                                        tooltip: 'Resume',
                                        icon: const Icon(Icons.play_arrow),
                                        onPressed: state.isImportingP0
                                            ? null
                                            : () => context
                                                .read<AppState>()
                                                .resumeImportTask(
                                                    run.resumeToken!),
                                      ),
                              ),
                          ],
                        ),
                      ],
                      if (step.sourceDocuments.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: EdgeInsets.zero,
                          title: Text(i18n.tr('import.drilldown_source_docs')),
                          children: [
                            for (final doc in step.sourceDocuments)
                              ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                title: Text(doc.title),
                                subtitle: Text(
                                  '${i18n.tr('import.doc_type')}: ${doc.docType}\n'
                                  '${i18n.tr('import.data_tier')}: ${doc.dataTier}\n'
                                  '${i18n.tr('import.ingestion_strategy')}: ${doc.ingestionStrategy}\n'
                                  '${i18n.tr('import.source_status')}: ${doc.sourceStatus}\n'
                                  '${i18n.tr('import.origin_url')}: ${doc.originUrl}',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    i18n.tr('import.ops_title'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(i18n.tr('import.ops_help')),
                  if ((state.lastSnapshotOperationMessage ?? '')
                      .trim()
                      .isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(state.lastSnapshotOperationMessage!),
                  ],
                  const SizedBox(height: 12),
                  _PathField(
                    controller: _snapshotBundleController,
                    label: i18n.tr('import.snapshot_bundle_path'),
                    onChanged: (_) => setState(() {}),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: state.isRunningSnapshotOperation ||
                                !hasSnapshotBundlePath
                            ? null
                            : () =>
                                context.read<AppState>().importSnapshotBundle(
                                      filePath:
                                          _snapshotBundleController.text.trim(),
                                    ),
                        icon: const Icon(Icons.upload_file_outlined),
                        label: Text(i18n.tr('import.import_bundle')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (state.snapshotSummaries.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.tr('import.snapshot_registry'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final summary in state.snapshotSummaries.take(8))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.03),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.snapshot.snapshotId,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${i18n.tr('import.status')}: '
                                '${summary.snapshot.promotedAt == null ? i18n.tr('import.snapshot_status_staging') : i18n.tr('import.snapshot_status_promoted')}',
                              ),
                              Text(
                                '${i18n.tr('import.fact_count')}: ${summary.factCount}',
                              ),
                              Text(
                                '${i18n.tr('import.rules_version')}: ${summary.snapshot.rulesVersion}',
                              ),
                              Text(
                                '${i18n.tr('import.release_readiness')}: '
                                '${summary.releaseReadiness.isReady ? i18n.tr('import.release_ready') : i18n.tr('import.release_blocked')}',
                              ),
                              Text(
                                'Latest readiness: ${summary.releaseReadiness.readinessProfile} · '
                                'blocking issues ${summary.releaseReadiness.blockingIssues.length} · '
                                'warnings ${summary.releaseReadiness.warnings.length} · '
                                'open tickets ${summary.releaseReadiness.openReviewTicketCount} · '
                                'high severity ${summary.releaseReadiness.highSeverityReviewTicketCount}',
                              ),
                              Text(
                                '${i18n.tr('import.label_sections')}: '
                                '${summary.releaseReadiness.drugLabelSectionCount}',
                              ),
                              Text(
                                'Crosswalks: ${summary.releaseReadiness.crosswalkCount} · '
                                'Artifacts: ${summary.releaseReadiness.artifactCount} · '
                                'Unresolved conflicts: ${summary.releaseReadiness.unresolvedConflictCount}',
                              ),
                              Text(
                                'Open review tickets: ${summary.releaseReadiness.openReviewTicketCount} · '
                                'High severity: ${summary.releaseReadiness.issueCounts['open_high_severity_review_tickets'] ?? 0}',
                              ),
                              if (summary.releaseReadiness.sampleReviewTicketIds
                                  .isNotEmpty)
                                Text(
                                  'Sample tickets: ${summary.releaseReadiness.sampleReviewTicketIds.join(', ')}',
                                ),
                              if (summary
                                  .releaseReadiness.issueCounts.isNotEmpty)
                                Text(
                                  'Issue counts: ${summary.releaseReadiness.issueCounts.entries.map((entry) => '${entry.key}=${entry.value}').join(', ')}',
                                ),
                              if (summary.releaseReadiness
                                  .missingCrosswalkSampleIds.isNotEmpty)
                                Text(
                                  'Missing crosswalk samples: ${summary.releaseReadiness.missingCrosswalkSampleIds.join(', ')}',
                                ),
                              if (summary.releaseReadiness
                                  .backendCapabilityWarnings.isNotEmpty)
                                Text(
                                  'Backend warnings: ${summary.releaseReadiness.backendCapabilityWarnings.join(', ')}',
                                ),
                              if (summary.releaseReadiness.reviewTicketSummaries
                                  .isNotEmpty)
                                Text(
                                  'Review ticket summaries: ${summary.releaseReadiness.reviewTicketSummaries.map((item) => '${item['ticket_id']}:${item['reason_code']}').join(', ')}',
                                ),
                              Text(
                                'Artifact durability: ${summary.releaseReadiness.artifactDurabilityStatus}',
                              ),
                              Text(
                                'Rollback target: ${summary.releaseReadiness.rollbackTarget ?? '-'}',
                              ),
                              Text(
                                'Version history: ${summary.versionHistoryCount}',
                              ),
                              if (summary
                                  .releaseReadiness.blockingIssues.isNotEmpty)
                                Text(
                                  '${i18n.tr('import.blocking_issues')}: '
                                  '${summary.releaseReadiness.blockingIssues.join(', ')}',
                                ),
                              if (summary.releaseReadiness.warnings.isNotEmpty)
                                Text(
                                  '${i18n.tr('import.warnings')}: '
                                  '${summary.releaseReadiness.warnings.join(', ')}',
                                ),
                              if ((summary.snapshot.rollbackParent ?? '')
                                  .trim()
                                  .isNotEmpty)
                                Text(
                                  '${i18n.tr('import.rollback_parent')}: ${summary.snapshot.rollbackParent}',
                                ),
                              Text(
                                '${i18n.tr('common.completed')}: ${_compactTime(summary.snapshot.promotedAt ?? summary.snapshot.createdAt)}',
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  FilledButton.tonal(
                                    onPressed: state.isRunningSnapshotOperation
                                        ? null
                                        : () => context
                                            .read<AppState>()
                                            .publishSnapshotToChannel(
                                              snapshotId:
                                                  summary.snapshot.snapshotId,
                                            ),
                                    child: Text(i18n.tr('import.publish')),
                                  ),
                                  if (!summary.releaseReadiness.isReady)
                                    OutlinedButton(
                                      onPressed: state
                                              .isRunningSnapshotOperation
                                          ? null
                                          : () => context
                                              .read<AppState>()
                                              .publishSnapshotToChannel(
                                                snapshotId:
                                                    summary.snapshot.snapshotId,
                                                overrideReason:
                                                    'ops_ui_manual_override',
                                              ),
                                      child: const Text('Publish override'),
                                    ),
                                  OutlinedButton(
                                    onPressed: state.isRunningSnapshotOperation
                                        ? null
                                        : () => context
                                            .read<AppState>()
                                            .exportSnapshotBundle(
                                              snapshotId:
                                                  summary.snapshot.snapshotId,
                                            ),
                                    child:
                                        Text(i18n.tr('import.export_bundle')),
                                  ),
                                  OutlinedButton(
                                    onPressed: state.isRunningSnapshotOperation
                                        ? null
                                        : () => context
                                            .read<AppState>()
                                            .rollbackSnapshot(
                                              snapshotId:
                                                  summary.snapshot.snapshotId,
                                            ),
                                    child: Text(i18n.tr('import.rollback')),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (state.reviewTickets.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Human review tickets',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final ticket in state.reviewTickets.take(20))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${ticket.ticketId} · ${ticket.reasonCode} · ${ticket.severity}',
                        ),
                        subtitle: Text(
                          'Target: ${ticket.targetType}/${ticket.targetId}\n'
                          'Snapshot: ${ticket.snapshotId}${ticket.runId == null ? '' : ' · Run: ${ticket.runId}'}\n'
                          'Status: ${ticket.status}\n'
                          'Action: ${ticket.suggestedAction}\n'
                          'Created: ${_compactTime(ticket.createdAt)}'
                          '${ticket.resolvedAt == null ? '' : '\nResolved: ${_compactTime(ticket.resolvedAt!)}'}',
                        ),
                        trailing: ticket.status == 'open'
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  TextButton(
                                    onPressed: state.isRunningSnapshotOperation
                                        ? null
                                        : () => context
                                            .read<AppState>()
                                            .updateReviewTicketStatus(
                                              ticketId: ticket.ticketId,
                                              status: 'ignored',
                                            ),
                                    child: const Text('Ignore'),
                                  ),
                                  TextButton(
                                    onPressed: state.isRunningSnapshotOperation
                                        ? null
                                        : () => context
                                            .read<AppState>()
                                            .updateReviewTicketStatus(
                                              ticketId: ticket.ticketId,
                                              status: 'resolved',
                                            ),
                                    child: const Text('Resolve'),
                                  ),
                                ],
                              )
                            : Text(ticket.status),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (state.importMonitorSummaries.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.tr('import.monitoring'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final item in state.importMonitorSummaries)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.sourceFamily),
                        subtitle: Text(
                          '${i18n.tr('import.total_runs')}: ${item.totalRuns}\n'
                          '${i18n.tr('import.stage')}: ${item.lastStage} · ${i18n.tr('import.status')}: ${item.lastStatus}\n'
                          '${i18n.tr('import.snapshot')}: ${item.lastSnapshotId}\n'
                          '${i18n.tr('import.source_documents')}: ${item.lastSourceDocumentCount} · ${i18n.tr('import.observations')}: ${item.lastObservationCount}',
                        ),
                        trailing: Text(
                          item.lastCompletedAt == null
                              ? '-'
                              : _compactTime(item.lastCompletedAt!),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (state.snapshotDistributions.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.tr('import.distribution_history'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final distribution
                        in state.snapshotDistributions.take(10))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${distribution.snapshotId} · ${distribution.distributionType}',
                        ),
                        subtitle: Text(
                          '${i18n.tr('import.channel')}: ${distribution.channel}\n'
                          '${i18n.tr('import.status')}: ${distribution.status}\n'
                          '${distribution.artifactPath == null ? '' : '${i18n.tr('import.artifact_path')}: ${distribution.artifactPath}\n'}'
                          '${distribution.errorMessage == null ? '' : '${i18n.tr('common.error')}: ${distribution.errorMessage}'}',
                        ),
                        trailing: Text(
                          _compactTime(
                            distribution.completedAt ?? distribution.createdAt,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _localizedSourceLabel(
      AppI18n i18n, String sourceKey, String fallback) {
    switch (sourceKey) {
      case 'ema_medicines':
        return i18n.tr('import.ema_medicines');
      case 'ema_post_authorisation':
        return i18n.tr('import.ema_post_authorisation');
      case 'china_official_foods':
        return i18n.tr('import.china_official_foods');
      default:
        return fallback;
    }
  }

  String _compactTime(DateTime value) {
    return value.toIso8601String().replaceFirst('T', ' ').split('.').first;
  }
}

class _PathField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final ValueChanged<String>? onChanged;

  const _PathField({
    required this.controller,
    required this.label,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
