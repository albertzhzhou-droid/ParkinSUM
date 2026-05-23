import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/utils/qualified_value_parser.dart';
import '../../core/db/cdss_database.dart';
import '../../data/datasources/remote/p0_import_support.dart';
import '../entities/cdss_records.dart';
import 'cdss_artifact_store.dart';
import 'clinical_decision_support_service.dart';

/// 快照运营摘要：
/// - 供导入/发布后台直接显示当前 snapshot 的事实规模、发布时间和回滚来源；
/// - 保持只读聚合，不把 UI 统计逻辑散落到页面层。
class SnapshotOperationalSummary {
  final EngineSnapshotRecord snapshot;
  final int factCount;
  final ReleaseReadinessReport releaseReadiness;
  final int versionHistoryCount;

  const SnapshotOperationalSummary({
    required this.snapshot,
    required this.factCount,
    required this.releaseReadiness,
    this.versionHistoryCount = 0,
  });
}

/// 发布前质量门：
/// - 阻止空 snapshot、无来源、无规则、事实不可追溯这类上线前硬问题；
/// - 把正文级标签覆盖和后端 bundle 完整性暴露给 UI 与 manifest。
class ReleaseReadinessReport {
  final String readinessProfile;
  final String snapshotId;
  final bool isReady;
  final List<String> blockingIssues;
  final List<String> warnings;
  final int sourceDocumentCount;
  final int observationCount;
  final int resolvedFactCount;
  final int ruleCount;
  final int drugVariantCount;
  final int drugLabelSectionCount;
  final int orphanResolvedFactCount;
  final int crosswalkCount;
  final int artifactCount;
  final int unresolvedConflictCount;
  final int invalidRuleCount;
  final int missingCrosswalkCount;
  final int nonDurableArtifactCount;
  final int failedImportCount;
  final int resumableImportCount;
  final int staleRuleVersionCount;
  final int fallbackVariantResolutionWarningCount;
  final int openReviewTicketCount;
  final int highSeverityReviewTicketCount;
  final String blockingReasonSummary;
  final String warningSummary;
  final String artifactDurabilityStatus;
  final String? rollbackTarget;
  final List<String> missingCrosswalkSampleIds;
  final List<String> sampleReviewTicketIds;
  final List<String> backendCapabilityWarnings;
  final List<Map<String, dynamic>> reviewTicketSummaries;
  final Map<String, int> issueCounts;

  const ReleaseReadinessReport({
    this.readinessProfile = 'production_candidate',
    required this.snapshotId,
    required this.isReady,
    required this.blockingIssues,
    required this.warnings,
    required this.sourceDocumentCount,
    required this.observationCount,
    required this.resolvedFactCount,
    required this.ruleCount,
    required this.drugVariantCount,
    required this.drugLabelSectionCount,
    required this.orphanResolvedFactCount,
    required this.crosswalkCount,
    required this.artifactCount,
    required this.unresolvedConflictCount,
    this.invalidRuleCount = 0,
    this.missingCrosswalkCount = 0,
    this.nonDurableArtifactCount = 0,
    this.failedImportCount = 0,
    this.resumableImportCount = 0,
    this.staleRuleVersionCount = 0,
    this.fallbackVariantResolutionWarningCount = 0,
    this.openReviewTicketCount = 0,
    this.highSeverityReviewTicketCount = 0,
    this.blockingReasonSummary = '',
    this.warningSummary = '',
    this.artifactDurabilityStatus = 'unknown',
    this.rollbackTarget,
    this.missingCrosswalkSampleIds = const <String>[],
    this.sampleReviewTicketIds = const <String>[],
    this.backendCapabilityWarnings = const <String>[],
    this.reviewTicketSummaries = const <Map<String, dynamic>>[],
    this.issueCounts = const <String, int>{},
  });

  Map<String, dynamic> toJson() => {
        'readiness_profile': readinessProfile,
        'snapshot_id': snapshotId,
        'is_ready': isReady,
        'blocking_issues': blockingIssues,
        'warnings': warnings,
        'source_document_count': sourceDocumentCount,
        'observation_count': observationCount,
        'resolved_fact_count': resolvedFactCount,
        'rule_count': ruleCount,
        'drug_variant_count': drugVariantCount,
        'drug_label_section_count': drugLabelSectionCount,
        'orphan_resolved_fact_count': orphanResolvedFactCount,
        'crosswalk_count': crosswalkCount,
        'artifact_count': artifactCount,
        'unresolved_conflict_count': unresolvedConflictCount,
        'invalid_rule_count': invalidRuleCount,
        'missing_crosswalk_count': missingCrosswalkCount,
        'non_durable_artifact_count': nonDurableArtifactCount,
        'failed_import_count': failedImportCount,
        'resumable_import_count': resumableImportCount,
        'stale_rule_version_count': staleRuleVersionCount,
        'fallback_variant_resolution_warning_count':
            fallbackVariantResolutionWarningCount,
        'open_review_ticket_count': openReviewTicketCount,
        'high_severity_review_ticket_count': highSeverityReviewTicketCount,
        'blocking_reason_summary': blockingReasonSummary,
        'warning_summary': warningSummary,
        'artifact_durability_status': artifactDurabilityStatus,
        'rollback_target': rollbackTarget,
        'missing_crosswalk_sample_ids': missingCrosswalkSampleIds,
        'sample_review_ticket_ids': sampleReviewTicketIds,
        'backend_capability_warnings': backendCapabilityWarnings,
        'review_ticket_summaries': reviewTicketSummaries,
        'issue_counts': issueCounts,
      };
}

/// Repeatable dry-run checklist for release drills.
///
/// This is intentionally read-only: it verifies the production candidate gate
/// and reports what publish would do, while tests cover the real override
/// publish path separately.
class ReleaseReadinessDrillReport {
  final String snapshotId;
  final bool productionCandidateReady;
  final bool publishWouldBeBlocked;
  final bool overrideWouldAllowPublish;
  final String? overrideReason;
  final int openReviewTicketCount;
  final int openHighSeverityReviewTicketCount;
  final int warningCount;
  final String blockingReasonSummary;
  final String warningSummary;
  final String artifactDurabilityStatus;
  final String? rollbackTarget;
  final List<String> blockingIssues;
  final List<String> warnings;
  final List<String> sampleReviewTicketIds;
  final Map<String, int> issueCounts;
  final String humanReadableSummary;

  const ReleaseReadinessDrillReport({
    required this.snapshotId,
    required this.productionCandidateReady,
    required this.publishWouldBeBlocked,
    required this.overrideWouldAllowPublish,
    this.overrideReason,
    required this.openReviewTicketCount,
    required this.openHighSeverityReviewTicketCount,
    required this.warningCount,
    required this.blockingReasonSummary,
    required this.warningSummary,
    required this.artifactDurabilityStatus,
    this.rollbackTarget,
    required this.blockingIssues,
    required this.warnings,
    required this.sampleReviewTicketIds,
    required this.issueCounts,
    required this.humanReadableSummary,
  });

  Map<String, dynamic> toJson() => {
        'snapshot_id': snapshotId,
        'production_candidate_ready': productionCandidateReady,
        'publish_would_be_blocked': publishWouldBeBlocked,
        'override_would_allow_publish': overrideWouldAllowPublish,
        'override_reason': overrideReason,
        'open_review_ticket_count': openReviewTicketCount,
        'open_high_severity_review_ticket_count':
            openHighSeverityReviewTicketCount,
        'warning_count': warningCount,
        'blocking_reason_summary': blockingReasonSummary,
        'warning_summary': warningSummary,
        'artifact_durability_status': artifactDurabilityStatus,
        'rollback_target': rollbackTarget,
        'blocking_issues': blockingIssues,
        'warnings': warnings,
        'sample_review_ticket_ids': sampleReviewTicketIds,
        'issue_counts': issueCounts,
        'human_readable_summary': humanReadableSummary,
      };
}

/// 后端快照 bundle 导入前校验：
/// - 防止把缺 manifest、缺核心表、计数不一致或事实不可追溯的包写入本地库；
/// - 与 ReleaseReadinessReport 分开，是因为这里校验的是“传输包完整性”，
///   release readiness 校验的是“当前库中某个 snapshot 是否可发布”。
class SnapshotBundleValidationReport {
  final String snapshotId;
  final bool isValid;
  final List<String> blockingIssues;
  final List<String> warnings;
  final Map<String, int> tableCounts;

  const SnapshotBundleValidationReport({
    required this.snapshotId,
    required this.isValid,
    required this.blockingIssues,
    required this.warnings,
    required this.tableCounts,
  });

  Map<String, dynamic> toJson() => {
        'snapshot_id': snapshotId,
        'is_valid': isValid,
        'blocking_issues': blockingIssues,
        'warnings': warnings,
        'table_counts': tableCounts,
      };
}

/// 导入监控摘要：
/// - 聚合 source family 最近运行状态；
/// - 给“导入监控”卡片提供直接可用的数据。
class ImportOperationalSummary {
  final String sourceFamily;
  final int totalRuns;
  final String lastStage;
  final String lastStatus;
  final String lastSnapshotId;
  final DateTime? lastCompletedAt;
  final int lastSourceDocumentCount;
  final int lastObservationCount;

  const ImportOperationalSummary({
    required this.sourceFamily,
    required this.totalRuns,
    required this.lastStage,
    required this.lastStatus,
    required this.lastSnapshotId,
    required this.lastCompletedAt,
    required this.lastSourceDocumentCount,
    required this.lastObservationCount,
  });
}

/// KnowledgeBaseReleaseService：
/// - 把 snapshot 发布、导出、回滚后的分发记录集中到一个模块；
/// - 当前先实现本地可运维链路，为后续中心化后端分发保留稳定接口。
class KnowledgeBaseReleaseService {
  final CdssDatabase database;
  final ClinicalDecisionSupportService cdssService;
  final CdssArtifactStore artifactStore;

  KnowledgeBaseReleaseService({
    required this.database,
    required this.cdssService,
    CdssArtifactStore? artifactStore,
  }) : artifactStore = artifactStore ?? createCdssArtifactStore();

  Future<List<SnapshotOperationalSummary>> listSnapshotSummaries() async {
    await database.initialize();
    final snapshotRows = await database.queryTable('engine_snapshot');
    final factRows = await database.queryTable('resolved_fact');
    final sourceDocumentRows = await database.queryTable('source_document');
    final observationRows = await database.queryTable('observation');
    final ruleRows = await database.queryTable('rule_registry');
    final foodVariantRows = await database.queryTable('food_variant');
    final drugVariantRows = await database.queryTable('drug_product_variant');
    final drugLabelSectionRows =
        await database.queryTable('drug_label_section');
    final crosswalkRows =
        await database.queryTable('concept_variant_crosswalk');
    final distributionRows = await database.queryTable('snapshot_distribution');
    final conflictRows = await database.queryTable('conflict_audit_log');
    final ingestionRows = await database.queryTable('ingestion_run');
    final historyRows = await database.queryTable('cdss_record_history');
    final reviewTicketRows = await database.queryTable('human_review_ticket');
    final regionRows = await database.queryTable('region_jurisdiction_map');
    final factCountBySnapshot = <String, int>{};
    for (final row in factRows) {
      final snapshotId = '${row['snapshot_id'] ?? ''}';
      if (snapshotId.isEmpty) continue;
      factCountBySnapshot.update(snapshotId, (count) => count + 1,
          ifAbsent: () => 1);
    }

    final summaries = snapshotRows.map((row) {
      final snapshot = EngineSnapshotRecord(
        snapshotId: '${row['snapshot_id'] ?? ''}',
        factsVersion: '${row['facts_version'] ?? ''}',
        rulesVersion: '${row['rules_version'] ?? ''}',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
          (row['created_at'] as num?)?.toInt() ?? 0,
        ),
        promotedAt: row['promoted_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (row['promoted_at'] as num).toInt(),
              ),
        rollbackParent: row['rollback_parent']?.toString(),
        inputHash: '${row['input_hash'] ?? ''}',
      );
      return SnapshotOperationalSummary(
        snapshot: snapshot,
        factCount: factCountBySnapshot[snapshot.snapshotId] ?? 0,
        versionHistoryCount: historyRows
            .where(
                (row) => '${row['snapshot_id'] ?? ''}' == snapshot.snapshotId)
            .length,
        releaseReadiness: _buildReadinessReport(
          snapshotId: snapshot.snapshotId,
          snapshotRows: snapshotRows,
          sourceDocumentRows: sourceDocumentRows,
          observationRows: observationRows,
          resolvedFactRows: factRows,
          ruleRows: ruleRows,
          foodVariantRows: foodVariantRows,
          drugVariantRows: drugVariantRows,
          drugLabelSectionRows: drugLabelSectionRows,
          crosswalkRows: crosswalkRows,
          distributionRows: distributionRows,
          conflictRows: conflictRows,
          ingestionRows: ingestionRows,
          reviewTicketRows: reviewTicketRows,
          regionRows: regionRows,
        ),
      );
    }).toList(growable: false)
      ..sort(
        (left, right) {
          final rightTs = right.snapshot.promotedAt ?? right.snapshot.createdAt;
          final leftTs = left.snapshot.promotedAt ?? left.snapshot.createdAt;
          return rightTs.compareTo(leftTs);
        },
      );
    return summaries;
  }

  Future<List<ImportOperationalSummary>> listImportSummaries() async {
    await database.initialize();
    final runRows = await database.queryTable('ingestion_run');
    final grouped = <String, List<Map<String, Object?>>>{};
    for (final row in runRows) {
      final sourceFamily = '${row['source_family'] ?? ''}'.trim();
      if (sourceFamily.isEmpty) continue;
      grouped
          .putIfAbsent(sourceFamily, () => <Map<String, Object?>>[])
          .add(row);
    }

    final summaries = grouped.entries.map((entry) {
      final rows = entry.value.toList(growable: false)
        ..sort(
          (left, right) => ((right['created_at'] as num?)?.toInt() ?? 0)
              .compareTo((left['created_at'] as num?)?.toInt() ?? 0),
        );
      final latest = rows.first;
      final notes = _safeDecodeMap('${latest['notes_json'] ?? '{}'}');
      return ImportOperationalSummary(
        sourceFamily: entry.key,
        totalRuns: rows.length,
        lastStage: '${latest['stage'] ?? ''}',
        lastStatus: '${latest['status'] ?? ''}',
        lastSnapshotId: '${latest['snapshot_id'] ?? ''}',
        lastCompletedAt: latest['completed_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(
                (latest['completed_at'] as num).toInt(),
              ),
        lastSourceDocumentCount:
            (notes['source_document_count'] as num?)?.toInt() ?? 0,
        lastObservationCount:
            (notes['observation_count'] as num?)?.toInt() ?? 0,
      );
    }).toList(growable: false)
      ..sort(
        (left, right) {
          final rightTs =
              right.lastCompletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final leftTs =
              left.lastCompletedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return rightTs.compareTo(leftTs);
        },
      );
    return summaries;
  }

  Future<List<SnapshotDistributionRecord>> listSnapshotDistributions() async {
    await database.initialize();
    final rows = await database.queryTable('snapshot_distribution');
    final records = rows.map(_mapDistributionRecord).toList(growable: false)
      ..sort(
        (left, right) => right.createdAt.compareTo(left.createdAt),
      );
    return records;
  }

  Future<List<HumanReviewTicketRecord>> listReviewTickets({
    String? snapshotId,
    String? status,
  }) async {
    await database.initialize();
    final rows = await database.queryTable('human_review_ticket');
    final records = rows
        .where((row) =>
            snapshotId == null || '${row['snapshot_id'] ?? ''}' == snapshotId)
        .where((row) => status == null || '${row['status'] ?? ''}' == status)
        .map(_mapReviewTicketRecord)
        .toList(growable: false)
      ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
    return records;
  }

  Future<ReleaseReadinessDrillReport> runReleaseReadinessDrill({
    required String snapshotId,
    String? overrideReason,
  }) async {
    final readiness = await validateReleaseCandidate(
      snapshotId,
      readinessProfile: 'production_candidate',
    );
    final override = (overrideReason ?? '').trim();
    final humanReadableSummary = _buildReleaseDrillSummary(
      readiness: readiness,
      publishWouldBeBlocked: !readiness.isReady && override.isEmpty,
      overrideReason: override.isEmpty ? null : override,
    );
    return ReleaseReadinessDrillReport(
      snapshotId: snapshotId,
      productionCandidateReady: readiness.isReady,
      publishWouldBeBlocked: !readiness.isReady && override.isEmpty,
      overrideWouldAllowPublish: !readiness.isReady && override.isNotEmpty,
      overrideReason: override.isEmpty ? null : override,
      openReviewTicketCount: readiness.openReviewTicketCount,
      openHighSeverityReviewTicketCount:
          readiness.highSeverityReviewTicketCount,
      warningCount: readiness.warnings.length,
      blockingReasonSummary: readiness.blockingReasonSummary,
      warningSummary: readiness.warningSummary,
      artifactDurabilityStatus: readiness.artifactDurabilityStatus,
      rollbackTarget: readiness.rollbackTarget,
      blockingIssues: readiness.blockingIssues,
      warnings: readiness.warnings,
      sampleReviewTicketIds: readiness.sampleReviewTicketIds,
      issueCounts: readiness.issueCounts,
      humanReadableSummary: humanReadableSummary,
    );
  }

  Future<HumanReviewTicketRecord> updateReviewTicketStatus({
    required String ticketId,
    required String status,
    DateTime? resolvedAt,
  }) async {
    await database.initialize();
    const allowed = {'open', 'resolved', 'ignored'};
    if (!allowed.contains(status)) {
      throw ArgumentError('Unsupported review ticket status: $status');
    }
    final rows = await database.queryTable('human_review_ticket');
    final row = rows.firstWhere(
      (item) => '${item['ticket_id'] ?? ''}' == ticketId,
      orElse: () => throw StateError('Review ticket not found: $ticketId'),
    );
    final nextResolvedAt =
        status == 'open' ? null : (resolvedAt ?? DateTime.now());
    final record = HumanReviewTicketRecord(
      ticketId: '${row['ticket_id'] ?? ''}',
      reasonCode: '${row['reason_code'] ?? ''}',
      severity: '${row['severity'] ?? 'medium'}',
      targetType: '${row['target_type'] ?? ''}',
      targetId: '${row['target_id'] ?? ''}',
      snapshotId: '${row['snapshot_id'] ?? ''}',
      runId: row['run_id']?.toString(),
      sourceDocRefsJson: '${row['source_doc_refs_json'] ?? '[]'}',
      suggestedAction: '${row['suggested_action'] ?? ''}',
      status: status,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num?)?.toInt() ?? 0,
      ),
      resolvedAt: nextResolvedAt,
    );
    await database.insertStagingRow('human_review_ticket', {
      'ticket_id': record.ticketId,
      'reason_code': record.reasonCode,
      'severity': record.severity,
      'target_type': record.targetType,
      'target_id': record.targetId,
      'snapshot_id': record.snapshotId,
      'run_id': record.runId,
      'source_doc_refs_json': record.sourceDocRefsJson,
      'suggested_action': record.suggestedAction,
      'status': record.status,
      'created_at': record.createdAt.millisecondsSinceEpoch,
      'resolved_at': record.resolvedAt?.millisecondsSinceEpoch,
    });
    return record;
  }

  Future<SnapshotDistributionRecord> publishSnapshot({
    required String snapshotId,
    String channel = 'local_stable',
    String? overrideReason,
  }) async {
    await database.initialize();
    final readiness = await validateReleaseCandidate(snapshotId);
    final override = (overrideReason ?? '').trim();
    if (!readiness.isReady && override.isEmpty) {
      final now = DateTime.now();
      await database.insertSnapshotDistribution(
        SnapshotDistributionRecord(
          distributionId:
              'dist_publish_failed_${stableHash('$snapshotId:$channel:${now.microsecondsSinceEpoch}')}',
          snapshotId: snapshotId,
          channel: channel,
          distributionType: 'publish',
          status: 'failed',
          artifactPath: null,
          manifestJson: jsonEncode({
            'snapshot_id': snapshotId,
            'release_readiness': readiness.toJson(),
            'publish_guard': {
              'blocked': true,
              'override_used': false,
            },
          }),
          errorMessage: 'Snapshot $snapshotId is not release-ready: '
              '${readiness.blockingIssues.join('; ')}',
          createdAt: now,
          completedAt: now,
        ),
      );
      throw StateError(
        'Snapshot $snapshotId is not release-ready: '
        '${readiness.blockingIssues.join('; ')}',
      );
    }
    final manifest = await _buildSnapshotManifest(snapshotId);
    final conflictRows = await database.queryTable('conflict_audit_log');
    final ruleTrace = await _buildReleaseRuleTrace(snapshotId);
    final versionDiff = await _buildVersionDiff(snapshotId);
    final artifactResult = await artifactStore.writeArtifactSet(
      artifactId:
          'publish_${stableHash('$snapshotId:$channel:${DateTime.now().microsecondsSinceEpoch}')}',
      files: {
        'alerts.json': jsonEncode({
          'alerts': const <Map<String, dynamic>>[],
          'snapshot_id': snapshotId,
          'status': 'publish',
        }),
        'human_readable.md':
            '# Snapshot Publish\n\nSnapshot `$snapshotId` is ready for `$channel`.\n',
        'audit.jsonl': '${jsonEncode({
              'event': 'snapshot_publish',
              'snapshot_id': snapshotId,
              'channel': channel,
              'readiness': readiness.toJson(),
              if (override.isNotEmpty)
                'publish_override': {
                  'reason': override,
                  'used': true,
                },
            })}\n',
        'snapshot_manifest.json':
            const JsonEncoder.withIndent('  ').convert(manifest),
        'release_readiness.json':
            const JsonEncoder.withIndent('  ').convert(readiness.toJson()),
        'rule_trace.json':
            const JsonEncoder.withIndent('  ').convert(ruleTrace),
        'version_diff.json':
            const JsonEncoder.withIndent('  ').convert(versionDiff),
        'conflict_rationale.json': const JsonEncoder.withIndent('  ').convert(
          conflictRows
              .where((row) => '${row['snapshot_id'] ?? ''}' == snapshotId)
              .map(_conflictRationaleRow)
              .toList(growable: false),
        ),
      },
      manifest: {
        'kind': 'publish',
        'snapshot_id': snapshotId,
        'channel': channel,
        'durable': true,
        'version_diff': versionDiff,
        if (override.isNotEmpty)
          'publish_override': {
            'reason': override,
            'used': true,
          },
      },
    );
    final record = SnapshotDistributionRecord(
      distributionId:
          'dist_publish_${stableHash('$snapshotId:$channel:${DateTime.now().microsecondsSinceEpoch}')}',
      snapshotId: snapshotId,
      channel: channel,
      distributionType: 'publish',
      status:
          artifactResult.durable ? 'completed' : 'completed_inline_fallback',
      artifactPath: artifactResult.artifactPath,
      manifestJson: jsonEncode({
        ...manifest,
        'artifact_path': artifactResult.artifactPath,
        'artifact_files': artifactResult.files,
        'durable': artifactResult.durable,
        'publish_guard': {
          'blocked': false,
          'override_used': override.isNotEmpty,
          if (override.isNotEmpty) 'override_reason': override,
        },
      }),
      errorMessage: null,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
    await database.insertSnapshotDistribution(record);
    return record;
  }

  Future<SnapshotDistributionRecord> exportSnapshotBundle({
    required String snapshotId,
    String channel = 'backend_export',
  }) async {
    await database.initialize();
    final readiness = await validateReleaseCandidate(snapshotId);
    if (!readiness.isReady) {
      throw StateError(
        'Snapshot $snapshotId is not export-ready: '
        '${readiness.blockingIssues.join('; ')}',
      );
    }
    final payload = await _buildSnapshotBundle(snapshotId);
    final baseDir = Directory(
      p.join(await getDatabasesPath(), 'parkinsum_cdss_snapshot_exports'),
    );
    await baseDir.create(recursive: true);
    final filePath = p.join(baseDir.path, '$snapshotId.bundle.json');
    final file = File(filePath);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );

    final record = SnapshotDistributionRecord(
      distributionId:
          'dist_export_${stableHash('$snapshotId:$channel:${DateTime.now().microsecondsSinceEpoch}')}',
      snapshotId: snapshotId,
      channel: channel,
      distributionType: 'export_bundle',
      status: 'completed',
      artifactPath: filePath,
      manifestJson: jsonEncode(payload['manifest']),
      errorMessage: null,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
    await database.insertSnapshotDistribution(record);
    return record;
  }

  Future<SnapshotDistributionRecord> importSnapshotBundle({
    required String filePath,
    String channel = 'bundle_import',
  }) async {
    await database.initialize();
    final file = File(filePath);
    if (!await file.exists()) {
      throw ArgumentError('Snapshot bundle not found: $filePath');
    }

    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) {
      throw ArgumentError('Snapshot bundle payload is not a JSON object');
    }
    final bundle = Map<String, dynamic>.from(decoded);
    final manifest = _coerceMap(bundle['manifest']);
    final snapshotRow = _coerceMap(bundle['snapshot']);
    final snapshotId =
        '${manifest['snapshot_id'] ?? snapshotRow['snapshot_id'] ?? ''}';
    if (snapshotId.isEmpty) {
      await _recordBundleImportFailure(
        snapshotId: 'unknown_snapshot',
        channel: channel,
        filePath: filePath,
        errorMessage: 'Snapshot bundle missing snapshot_id',
      );
      throw ArgumentError('Snapshot bundle missing snapshot_id');
    }

    final validation = _validateSnapshotBundlePayload(bundle);
    if (!validation.isValid) {
      final message =
          'Snapshot bundle validation failed: ${validation.blockingIssues.join('; ')}';
      await _recordBundleImportFailure(
        snapshotId: snapshotId,
        channel: channel,
        filePath: filePath,
        errorMessage: message,
        validation: validation,
      );
      throw StateError(message);
    }

    if (snapshotRow.isNotEmpty) {
      await database.insertEngineSnapshot(_mapSnapshot(snapshotRow));
    }

    for (final row in _coerceRows(bundle['source_document'])) {
      await database.insertSourceDocument(_mapSourceDocument(row));
    }
    for (final row in _coerceRows(bundle['food_concept'])) {
      await database.insertFoodConcept(_mapFoodConcept(row));
    }
    for (final row in _coerceRows(bundle['food_variant'])) {
      await database.insertFoodVariant(_mapFoodVariant(row));
    }
    for (final row in _coerceRows(bundle['drug_concept'])) {
      await database.insertDrugConcept(_mapDrugConcept(row));
    }
    for (final row in _coerceRows(bundle['drug_product_variant'])) {
      await database.insertDrugProductVariant(_mapDrugProductVariant(row));
    }
    for (final row in _coerceRows(bundle['drug_label_section'])) {
      await database.insertDrugLabelSection(_mapDrugLabelSection(row));
    }
    for (final row in _coerceRows(bundle['drug_product_code'])) {
      await database.insertDrugProductCode(_mapDrugProductCode(row));
    }
    for (final row in _coerceRows(bundle['drug_product_packaging'])) {
      await database.insertDrugProductPackaging(_mapDrugProductPackaging(row));
    }
    for (final row in _coerceRows(bundle['drug_product_media'])) {
      await database.insertDrugProductMedia(_mapDrugProductMedia(row));
    }
    for (final row in _coerceRows(bundle['concept_variant_crosswalk'])) {
      await database.insertStagingRow('concept_variant_crosswalk', row);
    }
    for (final row in _coerceRows(bundle['variant_scope'])) {
      await database.insertVariantScope(_mapVariantScope(row));
    }
    for (final row in _coerceRows(bundle['observation'])) {
      await database.insertObservation(_mapObservation(row));
    }
    for (final row in _coerceRows(bundle['resolved_fact'])) {
      await database.insertResolvedFact(_mapResolvedFact(row));
    }
    for (final row in _coerceRows(bundle['rule_registry'])) {
      await database.insertRuleRegistry(row);
    }
    for (final row in _coerceRows(bundle['country_diet_profile'])) {
      await database.insertCountryDietProfile(_mapCountryDietProfile(row));
    }
    for (final row in _coerceRows(bundle['meal_template'])) {
      await database.insertMealTemplate(_mapMealTemplate(row));
    }

    await database.insertIngestionRun(
      IngestionRunRecord(
        runId: 'bundle_import_${stableHash('$snapshotId:$filePath')}',
        sourceFamily: 'snapshot_bundle',
        stage: 'bundle_import',
        status: 'completed',
        snapshotId: snapshotId,
        parentSnapshotId: null,
        notesJson: jsonEncode({
          'artifact_path': filePath,
          'bundle_validation': validation.toJson(),
          'source_document_count':
              _coerceRows(bundle['source_document']).length,
          'observation_count': _coerceRows(bundle['observation']).length,
          'resolved_fact_count': _coerceRows(bundle['resolved_fact']).length,
        }),
        createdAt: DateTime.now(),
        completedAt: DateTime.now(),
      ),
    );

    final record = SnapshotDistributionRecord(
      distributionId:
          'dist_import_${stableHash('$snapshotId:$channel:${DateTime.now().microsecondsSinceEpoch}')}',
      snapshotId: snapshotId,
      channel: channel,
      distributionType: 'import_bundle',
      status: 'completed',
      artifactPath: filePath,
      manifestJson: jsonEncode(manifest),
      errorMessage: null,
      createdAt: DateTime.now(),
      completedAt: DateTime.now(),
    );
    await database.insertSnapshotDistribution(record);
    return record;
  }

  Future<String> rollbackAndRepublish({
    required String snapshotId,
    String reason = 'manual_rollback',
    String channel = 'local_stable',
  }) async {
    final rollbackSnapshotId = await cdssService.rollbackToSnapshot(
      snapshotId: snapshotId,
      reason: reason,
    );
    await publishSnapshot(snapshotId: rollbackSnapshotId, channel: channel);
    return rollbackSnapshotId;
  }

  Future<ReleaseReadinessReport> validateReleaseCandidate(
    String snapshotId, {
    String readinessProfile = 'production_candidate',
  }) async {
    await database.initialize();
    final snapshotRows = await database.queryTable('engine_snapshot');
    final sourceDocumentRows = await database.queryTable('source_document');
    final observationRows = await database.queryTable('observation');
    final resolvedFactRows = await database.queryTable('resolved_fact');
    final ruleRows = await database.queryTable('rule_registry');
    final foodVariantRows = await database.queryTable('food_variant');
    final drugVariantRows = await database.queryTable('drug_product_variant');
    final drugLabelSectionRows =
        await database.queryTable('drug_label_section');
    final crosswalkRows =
        await database.queryTable('concept_variant_crosswalk');
    final distributionRows = await database.queryTable('snapshot_distribution');
    final conflictRows = await database.queryTable('conflict_audit_log');
    final ingestionRows = await database.queryTable('ingestion_run');
    final regionRows = await database.queryTable('region_jurisdiction_map');
    var reviewTicketRows = await database.queryTable('human_review_ticket');
    final preliminary = _buildReadinessReport(
      readinessProfile: readinessProfile,
      snapshotId: snapshotId,
      snapshotRows: snapshotRows,
      sourceDocumentRows: sourceDocumentRows,
      observationRows: observationRows,
      resolvedFactRows: resolvedFactRows,
      ruleRows: ruleRows,
      foodVariantRows: foodVariantRows,
      drugVariantRows: drugVariantRows,
      drugLabelSectionRows: drugLabelSectionRows,
      crosswalkRows: crosswalkRows,
      distributionRows: distributionRows,
      conflictRows: conflictRows,
      ingestionRows: ingestionRows,
      reviewTicketRows: reviewTicketRows,
      regionRows: regionRows,
    );
    if (readinessProfile == 'production_candidate') {
      await _ensureReviewTicketsForReadiness(
        report: preliminary,
        snapshotId: snapshotId,
        conflictRows: conflictRows,
        ruleRows: ruleRows,
      );
      reviewTicketRows = await database.queryTable('human_review_ticket');
    }
    return _buildReadinessReport(
      readinessProfile: readinessProfile,
      snapshotId: snapshotId,
      snapshotRows: snapshotRows,
      sourceDocumentRows: sourceDocumentRows,
      observationRows: observationRows,
      resolvedFactRows: resolvedFactRows,
      ruleRows: ruleRows,
      foodVariantRows: foodVariantRows,
      drugVariantRows: drugVariantRows,
      drugLabelSectionRows: drugLabelSectionRows,
      crosswalkRows: crosswalkRows,
      distributionRows: distributionRows,
      conflictRows: conflictRows,
      ingestionRows: ingestionRows,
      reviewTicketRows: reviewTicketRows,
      regionRows: regionRows,
    );
  }

  Future<Map<String, dynamic>> _buildSnapshotManifest(String snapshotId) async {
    final snapshotRows = await database.queryTable('engine_snapshot');
    final snapshot = snapshotRows.firstWhere(
      (row) => '${row['snapshot_id'] ?? ''}' == snapshotId,
      orElse: () => <String, Object?>{},
    );
    final factRows = await database.queryTable('resolved_fact');
    final sourceDocumentRows = await database.queryTable('source_document');
    final ruleRows = await database.queryTable('rule_registry');
    final crosswalkRows =
        await database.queryTable('concept_variant_crosswalk');
    final distributionRows = await database.queryTable('snapshot_distribution');
    final readiness = await validateReleaseCandidate(snapshotId);
    final versionDiff = await _buildVersionDiff(snapshotId);
    final facts = factRows
        .where((row) => '${row['snapshot_id'] ?? ''}' == snapshotId)
        .toList(growable: false);
    return <String, dynamic>{
      'snapshot_id': snapshotId,
      'bundle_schema_version': 1,
      'rules_version': '${snapshot['rules_version'] ?? ''}',
      'facts_version': '${snapshot['facts_version'] ?? ''}',
      'fact_count': facts.length,
      'source_document_count': sourceDocumentRows.length,
      'rule_count': ruleRows.length,
      'crosswalk_count': crosswalkRows.length,
      'artifact_count': distributionRows
          .where((row) =>
              '${row['snapshot_id'] ?? ''}' == snapshotId &&
              (row['artifact_path'] ?? '').toString().trim().isNotEmpty)
          .length,
      'release_readiness': readiness.toJson(),
      'version_diff': versionDiff,
      'backend_distribution': {
        'schema_version': 1,
        'required_tables': const [
          'engine_snapshot',
          'source_document',
          'observation',
          'resolved_fact',
          'rule_registry',
        ],
        'exported_at': DateTime.now().toUtc().toIso8601String(),
      },
      'rollback_parent': snapshot['rollback_parent']?.toString(),
      'created_at': snapshot['created_at'],
      'promoted_at': snapshot['promoted_at'],
    };
  }

  Future<Map<String, dynamic>> _buildSnapshotBundle(String snapshotId) async {
    final manifest = await _buildSnapshotManifest(snapshotId);
    final snapshotRows = await database.queryTable('engine_snapshot');
    final facts = await database.queryTable('resolved_fact');
    return <String, dynamic>{
      'manifest': manifest,
      'snapshot': snapshotRows.firstWhere(
        (row) => '${row['snapshot_id'] ?? ''}' == snapshotId,
        orElse: () => <String, Object?>{},
      ),
      // 这里导出“下游后端继续落地所需的核心表”，
      // 避免只导出 resolved_fact 而丢掉解释、目录和监管元数据。
      'source_document': await database.queryTable('source_document'),
      'food_concept': await database.queryTable('food_concept'),
      'food_variant': await database.queryTable('food_variant'),
      'drug_concept': await database.queryTable('drug_concept'),
      'drug_product_variant': await database.queryTable('drug_product_variant'),
      'drug_label_section': await database.queryTable('drug_label_section'),
      'drug_product_code': await database.queryTable('drug_product_code'),
      'drug_product_packaging':
          await database.queryTable('drug_product_packaging'),
      'drug_product_media': await database.queryTable('drug_product_media'),
      'concept_variant_crosswalk':
          await database.queryTable('concept_variant_crosswalk'),
      'variant_scope': await database.queryTable('variant_scope'),
      'observation': await database.queryTable('observation'),
      'resolved_fact': facts
          .where((row) => '${row['snapshot_id'] ?? ''}' == snapshotId)
          .toList(growable: false),
      'rule_registry': await database.queryTable('rule_registry'),
      'country_diet_profile': await database.queryTable('country_diet_profile'),
      'meal_template': await database.queryTable('meal_template'),
    };
  }

  Future<List<Map<String, dynamic>>> _buildReleaseRuleTrace(
      String snapshotId) async {
    final conflictRows = await database.queryTable('conflict_audit_log');
    return conflictRows
        .where((row) =>
            '${row['snapshot_id'] ?? ''}' == snapshotId &&
            '${row['audit_type'] ?? ''}' == 'RUNTIME_ALERT')
        .map((row) => {
              'audit_id': row['audit_id'],
              'target': row['target'],
              'decision': row['decision'],
              'winning_rule_ids':
                  _safeDecodeList('${row['winning_rule_ids_json'] ?? '[]'}'),
              'suppressed_rule_ids':
                  _safeDecodeList('${row['suppressed_rule_ids_json'] ?? '[]'}'),
              'source_refs':
                  _safeDecodeList('${row['source_doc_refs_json'] ?? '[]'}'),
              'decision_reason': row['decision_reason'],
              'needs_human_review': row['needs_human_review'],
            })
        .toList(growable: false);
  }

  Future<Map<String, dynamic>> _buildVersionDiff(String snapshotId) async {
    final snapshotRows = await database.queryTable('engine_snapshot');
    final targetSnapshot = snapshotRows.firstWhere(
      (row) => '${row['snapshot_id'] ?? ''}' == snapshotId,
      orElse: () => <String, Object?>{},
    );
    final explicitBase = '${targetSnapshot['rollback_parent'] ?? ''}'.trim();
    final baseSnapshotId = explicitBase.isNotEmpty
        ? explicitBase
        : _previousPromotedSnapshotId(snapshotRows, snapshotId);
    final historyRows = await database.queryTable('cdss_record_history');
    final targetRows = _historyRowsForSnapshot(historyRows, snapshotId);
    final baseRows = baseSnapshotId == null
        ? const <Map<String, Object?>>[]
        : _historyRowsForSnapshot(historyRows, baseSnapshotId);

    String keyFor(Map<String, Object?> row) =>
        '${row['table_name'] ?? ''}:${row['record_id'] ?? ''}';
    final targetByKey = {for (final row in targetRows) keyFor(row): row};
    final baseByKey = {for (final row in baseRows) keyFor(row): row};
    final added = <Map<String, dynamic>>[];
    final changed = <Map<String, dynamic>>[];
    final retired = <Map<String, dynamic>>[];
    final active = _historyRowsByStatus(targetRows, 'active')
        .map(_versionDiffRow)
        .toList(growable: false);
    for (final entry in targetByKey.entries) {
      final base = baseByKey[entry.key];
      final target = entry.value;
      if (base == null) {
        added.add(_versionDiffRow(target));
        continue;
      }
      if ('${base['version_id'] ?? ''}' != '${target['version_id'] ?? ''}' ||
          '${base['payload_json'] ?? ''}' !=
              '${target['payload_json'] ?? ''}') {
        changed.add({
          ..._versionDiffRow(target),
          'previous_version_id': base['version_id'],
        });
      }
    }
    for (final entry in baseByKey.entries) {
      if (!targetByKey.containsKey(entry.key)) {
        retired.add(_versionDiffRow(entry.value));
      }
    }
    return {
      'snapshot_id': snapshotId,
      'base_snapshot_id': baseSnapshotId,
      'rollback_parent': targetSnapshot['rollback_parent'],
      'added': added,
      'changed': changed,
      'retired': retired,
      'active': active,
      'rollback_summary': {
        'rollback_parent': targetSnapshot['rollback_parent'],
        'restored_fact_count':
            active.where((row) => row['table_name'] == 'resolved_fact').length,
        'restored_rule_count':
            active.where((row) => row['table_name'] == 'rule_registry').length,
        'restored_runtime_event_count':
            active.where((row) => row['table_name'] == 'runtime_event').length,
        'retired_record_count': retired.length,
        'active_record_count_after_rollback': active.length,
      },
      'by_table': _versionDiffByTable(
        added: added,
        changed: changed,
        retired: retired,
        active: active,
      ),
      'facts': _versionDiffForTable(
        tableName: 'resolved_fact',
        added: added,
        changed: changed,
        retired: retired,
        active: active,
      ),
      'rules': _versionDiffForTable(
        tableName: 'rule_registry',
        added: added,
        changed: changed,
        retired: retired,
        active: active,
      ),
      'runtime_events': _versionDiffForTable(
        tableName: 'runtime_event',
        added: added,
        changed: changed,
        retired: retired,
        active: active,
      ),
      'artifacts': _versionDiffForTable(
        tableName: 'snapshot_distribution',
        added: added,
        changed: changed,
        retired: retired,
        active: active,
      ),
      'history_status_counts': {
        'active': _historyRowsByStatus(targetRows, 'active').length,
        'superseded': _historyRowsByStatus(targetRows, 'superseded').length,
        'retired': _historyRowsByStatus(targetRows, 'retired').length,
      },
    };
  }

  List<Map<String, Object?>> _historyRowsForSnapshot(
    List<Map<String, Object?>> rows,
    String snapshotId, {
    String? status,
  }) {
    return rows.where((row) {
      if ('${row['snapshot_id'] ?? ''}' != snapshotId) return false;
      return status == null || _historyStatus(row) == status;
    }).toList(growable: false);
  }

  List<Map<String, Object?>> _historyRowsByStatus(
    List<Map<String, Object?>> rows,
    String status,
  ) {
    return rows
        .where((row) => _historyStatus(row) == status)
        .toList(growable: false);
  }

  Map<String, dynamic> _versionDiffRow(Map<String, Object?> row) => {
        'table_name': row['table_name'],
        'record_id': row['record_id'],
        'version_id': row['version_id'],
        'status': _historyStatus(row),
        'history_id': row['history_id'],
        'history_status': _historyStatus(row),
        'effective_at': row['effective_at'],
        'retired_at': row['retired_at'],
        'superseded_by': row['superseded_by'],
        'import_run_id': row['import_run_id'],
        'snapshot_id': row['snapshot_id'],
      };

  String _historyStatus(Map<String, Object?> row) {
    if (row['superseded_by'] != null) return 'superseded';
    if (row['retired_at'] != null) return 'retired';
    return 'active';
  }

  Map<String, int> _versionDiffByTable({
    required List<Map<String, dynamic>> added,
    required List<Map<String, dynamic>> changed,
    required List<Map<String, dynamic>> retired,
    required List<Map<String, dynamic>> active,
  }) {
    final counts = <String, int>{};
    for (final row in [...added, ...changed, ...retired, ...active]) {
      final tableName = '${row['table_name'] ?? ''}';
      if (tableName.isEmpty) continue;
      counts.update(tableName, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Map<String, List<Map<String, dynamic>>> _versionDiffForTable({
    required String tableName,
    required List<Map<String, dynamic>> added,
    required List<Map<String, dynamic>> changed,
    required List<Map<String, dynamic>> retired,
    required List<Map<String, dynamic>> active,
  }) =>
      {
        'added': added
            .where((row) => row['table_name'] == tableName)
            .toList(growable: false),
        'changed': changed
            .where((row) => row['table_name'] == tableName)
            .toList(growable: false),
        'retired': retired
            .where((row) => row['table_name'] == tableName)
            .toList(growable: false),
        'active': active
            .where((row) => row['table_name'] == tableName)
            .toList(growable: false),
      };

  String? _previousPromotedSnapshotId(
    List<Map<String, Object?>> snapshotRows,
    String snapshotId,
  ) {
    final promoted = snapshotRows
        .where((row) => row['promoted_at'] != null)
        .toList(growable: false)
      ..sort(
        (left, right) => ((left['promoted_at'] as num?)?.toInt() ?? 0)
            .compareTo((right['promoted_at'] as num?)?.toInt() ?? 0),
      );
    final targetIndex = promoted
        .indexWhere((row) => '${row['snapshot_id'] ?? ''}' == snapshotId);
    if (targetIndex <= 0) return null;
    return '${promoted[targetIndex - 1]['snapshot_id'] ?? ''}';
  }

  ReleaseReadinessReport _buildReadinessReport({
    String readinessProfile = 'production_candidate',
    required String snapshotId,
    required List<Map<String, Object?>> snapshotRows,
    required List<Map<String, Object?>> sourceDocumentRows,
    required List<Map<String, Object?>> observationRows,
    required List<Map<String, Object?>> resolvedFactRows,
    required List<Map<String, Object?>> ruleRows,
    required List<Map<String, Object?>> foodVariantRows,
    required List<Map<String, Object?>> drugVariantRows,
    required List<Map<String, Object?>> drugLabelSectionRows,
    required List<Map<String, Object?>> crosswalkRows,
    required List<Map<String, Object?>> distributionRows,
    required List<Map<String, Object?>> conflictRows,
    required List<Map<String, Object?>> ingestionRows,
    required List<Map<String, Object?>> reviewTicketRows,
    required List<Map<String, Object?>> regionRows,
  }) {
    final issues = <String>[];
    final warnings = <String>[];
    final snapshotExists =
        snapshotRows.any((row) => '${row['snapshot_id'] ?? ''}' == snapshotId);
    final snapshotRow = snapshotRows.firstWhere(
      (row) => '${row['snapshot_id'] ?? ''}' == snapshotId,
      orElse: () => const <String, Object?>{},
    );
    final snapshotRulesVersion = '${snapshotRow['rules_version'] ?? ''}';
    final facts = resolvedFactRows
        .where((row) => '${row['snapshot_id'] ?? ''}' == snapshotId)
        .toList(growable: false);
    final sourceDocIds = sourceDocumentRows
        .map((row) => '${row['source_doc_id'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet();
    final observationsById = <String, Map<String, Object?>>{};
    for (final row in observationRows) {
      final observationId = '${row['observation_id'] ?? ''}';
      if (observationId.isNotEmpty) {
        observationsById[observationId] = row;
      }
    }
    var orphanFacts = 0;
    for (final fact in facts) {
      final observationId = '${fact['chosen_observation_id'] ?? ''}';
      final observation = observationsById[observationId];
      final sourceDocId = '${observation?['source_doc_id'] ?? ''}';
      if (observation == null || !sourceDocIds.contains(sourceDocId)) {
        orphanFacts++;
      }
    }
    final artifactCount = distributionRows
        .where((row) =>
            '${row['snapshot_id'] ?? ''}' == snapshotId &&
            (row['artifact_path'] ?? '').toString().trim().isNotEmpty)
        .length;
    final unresolvedConflicts = conflictRows
        .where((row) =>
            '${row['snapshot_id'] ?? ''}' == snapshotId &&
            ((row['needs_human_review'] == 1) ||
                row['needs_human_review'] == true))
        .length;
    final invalidRuleCount = ruleRows.where(_isInvalidRuleRegistryRow).length;
    final crosswalkVariantIds = crosswalkRows
        .where((row) => '${row['status'] ?? 'active'}' == 'active')
        .map((row) => '${row['variant_id'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet();
    final activeFoodVariantIds = foodVariantRows
        .where((row) => '${row['status'] ?? 'active'}' == 'active')
        .map((row) => '${row['food_variant_id'] ?? ''}')
        .where((id) => id.isNotEmpty);
    final activeDrugVariantIds = drugVariantRows
        .where((row) => '${row['source_status'] ?? 'active'}' == 'active')
        .map((row) => '${row['drug_product_variant_id'] ?? ''}')
        .where((id) => id.isNotEmpty);
    final missingCrosswalkIds = [
      ...activeFoodVariantIds,
      ...activeDrugVariantIds,
    ].where((id) => !crosswalkVariantIds.contains(id)).toList(growable: false);
    final missingCrosswalkCount = missingCrosswalkIds.length;
    final nonDurableArtifactCount = distributionRows.where((row) {
      if ('${row['snapshot_id'] ?? ''}' != snapshotId) return false;
      final manifest = _coerceMap(row['manifest_json']);
      final durable = manifest['durable'];
      return durable == false ||
          '${row['status'] ?? ''}'.contains('inline_fallback');
    }).length;
    final backendCapabilityWarnings =
        _backendCapabilityWarnings(distributionRows, snapshotId);
    final failedImportCount = ingestionRows
        .where((row) =>
            '${row['snapshot_id'] ?? ''}' == snapshotId &&
            '${row['status'] ?? ''}' == 'failed')
        .length;
    final staleRuleVersionCount = ruleRows.where((row) {
      if ('${row['status'] ?? ''}' != 'active') return false;
      if (snapshotRulesVersion.trim().isEmpty) return false;
      final rowVersion = '${row['rule_version'] ?? ''}'.trim();
      return rowVersion.isNotEmpty && rowVersion != snapshotRulesVersion;
    }).length;
    final fallbackVariantResolutionWarningCount = missingCrosswalkCount;
    final fallbackRegionMapUsed = regionRows.isEmpty;
    final artifactDurabilityStatus = _artifactDurabilityStatus(
      distributionRows,
      snapshotId,
      nonDurableArtifactCount,
      artifactCount,
    );
    final openTickets = reviewTicketRows
        .where((row) =>
            '${row['snapshot_id'] ?? ''}' == snapshotId &&
            '${row['status'] ?? 'open'}' == 'open')
        .toList(growable: false)
      ..sort((left, right) => '${left['ticket_id'] ?? ''}'
          .compareTo('${right['ticket_id'] ?? ''}'));
    final openHighSeverityTicketCount =
        openTickets.where((row) => '${row['severity'] ?? ''}' == 'high').length;
    final resumableImportCount = ingestionRows.where((row) {
      if ('${row['snapshot_id'] ?? ''}' != snapshotId) return false;
      final notes = _coerceMap(row['notes_json']);
      final checkpoint = _coerceMap(notes['checkpoint']);
      final status = '${row['status'] ?? ''}';
      return status == 'retry_scheduled' ||
          status == 'running' ||
          checkpoint['resume_supported'] == true;
    }).length;

    if (!snapshotExists) {
      issues.add('snapshot_not_found');
    }
    if (sourceDocumentRows.isEmpty) {
      issues.add('missing_source_documents');
    }
    if (facts.isEmpty) {
      issues.add('missing_resolved_facts');
    }
    if (ruleRows.isEmpty) {
      issues.add('missing_rule_registry');
    }
    if (invalidRuleCount > 0) {
      issues.add('invalid_rule_registry_rows');
    }
    if (crosswalkRows.isEmpty) {
      issues.add('missing_concept_variant_crosswalk');
    }
    if (missingCrosswalkCount > 0) {
      issues.add('missing_crosswalk_for_active_variants');
      warnings.add('legacy_variant_string_fallback_required');
    }
    if (artifactCount == 0) {
      issues.add('missing_release_artifacts');
    }
    if (unresolvedConflicts > 0) {
      issues.add('unresolved_conflicts');
    }
    if (failedImportCount > 0) {
      issues.add('failed_imports_for_snapshot');
    }
    if (orphanFacts > 0) {
      issues.add('resolved_facts_without_source_document');
    }
    if (openHighSeverityTicketCount > 0) {
      issues.add('open_high_severity_review_tickets');
    }
    if (drugVariantRows.isNotEmpty && drugLabelSectionRows.isEmpty) {
      warnings.add('drug_variants_without_label_sections');
    }
    if (observationRows.isEmpty) {
      warnings.add('missing_observations');
    }
    if (nonDurableArtifactCount > 0) {
      warnings.add('non_durable_artifact_fallback');
    }
    if (resumableImportCount > 0) {
      warnings.add('resumable_imports_present');
    }
    if (staleRuleVersionCount > 0) {
      warnings.add('stale_rule_versions');
    }
    if (fallbackRegionMapUsed) {
      warnings.add('fallback_region_jurisdiction_map');
    }
    warnings.addAll(backendCapabilityWarnings);

    final issueCounts = <String, int>{
      'missing_artifacts': artifactCount == 0 ? 1 : 0,
      'invalid_rule_rows': invalidRuleCount,
      'missing_crosswalk_for_active_variants': missingCrosswalkCount,
      'unresolved_conflicts': unresolvedConflicts,
      'non_durable_artifact_fallback': nonDurableArtifactCount,
      'failed_imports': failedImportCount,
      'resumable_imports': resumableImportCount,
      'web_backend_capability_warnings': backendCapabilityWarnings.length,
      'orphan_facts_source_docs': orphanFacts,
      'stale_rule_versions': staleRuleVersionCount,
      'fallback_variant_resolution_warnings':
          fallbackVariantResolutionWarningCount,
      'open_review_tickets': openTickets.length,
      'open_high_severity_review_tickets': openHighSeverityTicketCount,
      'fallback_region_jurisdiction_map': fallbackRegionMapUsed ? 1 : 0,
    };

    return ReleaseReadinessReport(
      readinessProfile: readinessProfile,
      snapshotId: snapshotId,
      isReady: issues.isEmpty,
      blockingIssues: issues,
      warnings: warnings,
      sourceDocumentCount: sourceDocumentRows.length,
      observationCount: observationRows.length,
      resolvedFactCount: facts.length,
      ruleCount: ruleRows.length,
      drugVariantCount: drugVariantRows.length,
      drugLabelSectionCount: drugLabelSectionRows.length,
      orphanResolvedFactCount: orphanFacts,
      crosswalkCount: crosswalkRows.length,
      artifactCount: artifactCount,
      unresolvedConflictCount: unresolvedConflicts,
      invalidRuleCount: invalidRuleCount,
      missingCrosswalkCount: missingCrosswalkCount,
      nonDurableArtifactCount: nonDurableArtifactCount,
      failedImportCount: failedImportCount,
      resumableImportCount: resumableImportCount,
      staleRuleVersionCount: staleRuleVersionCount,
      fallbackVariantResolutionWarningCount:
          fallbackVariantResolutionWarningCount,
      openReviewTicketCount: openTickets.length,
      highSeverityReviewTicketCount: openHighSeverityTicketCount,
      blockingReasonSummary: issues.isEmpty ? 'none' : issues.join('; '),
      warningSummary: warnings.isEmpty ? 'none' : warnings.join('; '),
      artifactDurabilityStatus: artifactDurabilityStatus,
      rollbackTarget: snapshotRow['rollback_parent']?.toString(),
      missingCrosswalkSampleIds:
          missingCrosswalkIds.take(10).toList(growable: false),
      sampleReviewTicketIds: openTickets
          .map((row) => '${row['ticket_id'] ?? ''}')
          .where((id) => id.isNotEmpty)
          .take(10)
          .toList(growable: false),
      backendCapabilityWarnings: backendCapabilityWarnings,
      reviewTicketSummaries: openTickets
          .take(10)
          .map(_reviewTicketSummary)
          .toList(growable: false),
      issueCounts: issueCounts,
    );
  }

  String _artifactDurabilityStatus(
    List<Map<String, Object?>> distributionRows,
    String snapshotId,
    int nonDurableArtifactCount,
    int artifactCount,
  ) {
    if (artifactCount == 0) return 'missing';
    if (nonDurableArtifactCount > 0) return 'non_durable_fallback';
    final hasDurable = distributionRows.any((row) {
      if ('${row['snapshot_id'] ?? ''}' != snapshotId) return false;
      final manifest = _coerceMap(row['manifest_json']);
      return manifest['durable'] == true;
    });
    return hasDurable ? 'durable' : 'unknown';
  }

  String _buildReleaseDrillSummary({
    required ReleaseReadinessReport readiness,
    required bool publishWouldBeBlocked,
    String? overrideReason,
  }) {
    final lines = <String>[
      'Release readiness drill: ${readiness.snapshotId}',
      'Profile: ${readiness.readinessProfile}',
      'Latest readiness: ${readiness.isReady ? 'ready' : 'blocked'}',
      'Publish guard: ${publishWouldBeBlocked ? 'blocked' : 'can proceed'}',
      'Blocking reasons: ${readiness.blockingReasonSummary}',
      'Warnings: ${readiness.warningSummary}',
      'Review tickets: open ${readiness.openReviewTicketCount}, high ${readiness.highSeverityReviewTicketCount}',
      'Sample ticket ids: ${readiness.sampleReviewTicketIds.isEmpty ? 'none' : readiness.sampleReviewTicketIds.join(', ')}',
      'Artifact durability: ${readiness.artifactDurabilityStatus}',
      'Rollback target: ${readiness.rollbackTarget ?? 'none'}',
    ];
    if ((overrideReason ?? '').trim().isNotEmpty) {
      lines.add('Override reason: ${overrideReason!.trim()}');
    }
    return lines.join('\n');
  }

  List<String> _backendCapabilityWarnings(
    List<Map<String, Object?>> distributionRows,
    String snapshotId,
  ) {
    final warnings = <String>{};
    for (final row in distributionRows) {
      if ('${row['snapshot_id'] ?? ''}' != snapshotId) continue;
      final manifest = _coerceMap(row['manifest_json']);
      final capabilities = _coerceMap(manifest['backend_capabilities']);
      if (capabilities['transactional'] == false) {
        warnings.add('backend_non_transactional_history');
      }
      final backend = '${capabilities['backend'] ?? manifest['backend'] ?? ''}'
          .toLowerCase();
      if (backend.contains('shared_preferences') ||
          backend.contains('localstorage') ||
          backend.contains('web')) {
        warnings.add('backend_lightweight_web_storage');
      }
    }
    return warnings.toList(growable: false)..sort();
  }

  Future<void> _ensureReviewTicketsForReadiness({
    required ReleaseReadinessReport report,
    required String snapshotId,
    required List<Map<String, Object?>> conflictRows,
    required List<Map<String, Object?>> ruleRows,
  }) async {
    final existingRows = await database.queryTable('human_review_ticket');
    final existingIds = existingRows
        .map((row) => '${row['ticket_id'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet();
    final now = DateTime.now();

    Future<void> addTicket({
      required String reasonCode,
      required String severity,
      required String targetType,
      required String targetId,
      String? runId,
      List<String> sourceDocRefs = const <String>[],
      required String suggestedAction,
    }) async {
      final ticketId =
          'review_${stableHash('$snapshotId:$reasonCode:$targetType:$targetId')}';
      if (existingIds.contains(ticketId)) return;
      existingIds.add(ticketId);
      await database.insertStagingRow('human_review_ticket', {
        'ticket_id': ticketId,
        'reason_code': reasonCode,
        'severity': severity,
        'target_type': targetType,
        'target_id': targetId,
        'snapshot_id': snapshotId,
        'run_id': runId,
        'source_doc_refs_json': jsonEncode(sourceDocRefs),
        'suggested_action': suggestedAction,
        'status': 'open',
        'created_at': now.millisecondsSinceEpoch,
        'resolved_at': null,
      });
    }

    for (final row in conflictRows.where((row) =>
        '${row['snapshot_id'] ?? ''}' == snapshotId &&
        ((row['needs_human_review'] == 1) ||
            row['needs_human_review'] == true))) {
      await addTicket(
        reasonCode: 'unresolved_conflict',
        severity: 'high',
        targetType: '${row['audit_type'] ?? 'conflict'}',
        targetId: '${row['target'] ?? row['audit_id'] ?? ''}',
        runId: row['run_id']?.toString(),
        sourceDocRefs: _safeDecodeList('${row['source_doc_refs_json'] ?? '[]'}')
            .map((value) => value.toString())
            .toList(growable: false),
        suggestedAction:
            'Review accepted/rejected rationale and resolve or ignore the conflict before production promotion.',
      );
    }

    for (final row in ruleRows.where(_isInvalidRuleRegistryRow)) {
      await addTicket(
        reasonCode: 'invalid_rule_registry_row',
        severity: 'high',
        targetType: 'rule_registry',
        targetId: '${row['rule_id'] ?? row['compiled_hash'] ?? 'unknown_rule'}',
        sourceDocRefs: _sourceRefsFromRuleRow(row),
        suggestedAction:
            'Fix or retire the invalid rule row, then re-run rule registry validation.',
      );
    }

    for (final id in report.missingCrosswalkSampleIds) {
      await addTicket(
        reasonCode: 'missing_crosswalk_for_active_variant',
        severity: 'high',
        targetType: 'concept_variant_crosswalk',
        targetId: id,
        suggestedAction:
            'Create or import an active concept_variant_crosswalk row for this variant, or retire the variant.',
      );
    }
  }

  List<String> _sourceRefsFromRuleRow(Map<String, Object?> row) {
    final provenance = _coerceMap(row['provenance_json']);
    final refs = provenance['source_refs'];
    if (refs is List) {
      return refs.map((value) => value.toString()).toList(growable: false);
    }
    return const <String>[];
  }

  Map<String, dynamic> _reviewTicketSummary(Map<String, Object?> row) => {
        'ticket_id': row['ticket_id'],
        'reason_code': row['reason_code'],
        'severity': row['severity'],
        'target_type': row['target_type'],
        'target_id': row['target_id'],
        'status': row['status'],
        'suggested_action': row['suggested_action'],
      };

  SnapshotBundleValidationReport _validateSnapshotBundlePayload(
    Map<String, dynamic> bundle,
  ) {
    final issues = <String>[];
    final warnings = <String>[];
    final manifest = _coerceMap(bundle['manifest']);
    final snapshot = _coerceMap(bundle['snapshot']);
    final snapshotId =
        '${manifest['snapshot_id'] ?? snapshot['snapshot_id'] ?? ''}';

    final sourceDocuments = _coerceRows(bundle['source_document']);
    final observations = _coerceRows(bundle['observation']);
    final facts = _coerceRows(bundle['resolved_fact']);
    final rules = _coerceRows(bundle['rule_registry']);
    final crosswalks = _coerceRows(bundle['concept_variant_crosswalk']);
    final drugVariants = _coerceRows(bundle['drug_product_variant']);
    final drugLabelSections = _coerceRows(bundle['drug_label_section']);
    final tableCounts = <String, int>{
      'source_document': sourceDocuments.length,
      'observation': observations.length,
      'resolved_fact': facts.length,
      'rule_registry': rules.length,
      'concept_variant_crosswalk': crosswalks.length,
      'drug_product_variant': drugVariants.length,
      'drug_label_section': drugLabelSections.length,
    };

    if (manifest.isEmpty) issues.add('missing_manifest');
    if (snapshot.isEmpty) issues.add('missing_snapshot_row');
    if (snapshotId.isEmpty) issues.add('missing_snapshot_id');
    if (sourceDocuments.isEmpty) issues.add('missing_source_documents');
    if (facts.isEmpty) issues.add('missing_resolved_facts');
    if (rules.isEmpty) issues.add('missing_rule_registry');
    if (crosswalks.isEmpty) issues.add('missing_concept_variant_crosswalk');

    final releaseReadiness = _coerceMap(manifest['release_readiness']);
    if (releaseReadiness.isNotEmpty && releaseReadiness['is_ready'] == false) {
      issues.add('manifest_release_readiness_blocked');
    }

    final manifestFactCount = (manifest['fact_count'] as num?)?.toInt();
    if (manifestFactCount != null && manifestFactCount != facts.length) {
      issues.add('fact_count_mismatch');
    }
    final manifestSourceDocCount =
        (manifest['source_document_count'] as num?)?.toInt();
    if (manifestSourceDocCount != null &&
        manifestSourceDocCount != sourceDocuments.length) {
      issues.add('source_document_count_mismatch');
    }
    final manifestRuleCount = (manifest['rule_count'] as num?)?.toInt();
    if (manifestRuleCount != null && manifestRuleCount != rules.length) {
      issues.add('rule_count_mismatch');
    }

    final sourceDocIds = sourceDocuments
        .map((row) => '${row['source_doc_id'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet();
    final observationsById = <String, Map<String, dynamic>>{};
    for (final observation in observations) {
      final id = '${observation['observation_id'] ?? ''}';
      if (id.isNotEmpty) observationsById[id] = observation;
    }
    for (final fact in facts) {
      final factSnapshotId = '${fact['snapshot_id'] ?? ''}';
      if (snapshotId.isNotEmpty && factSnapshotId != snapshotId) {
        issues.add('resolved_fact_snapshot_mismatch');
        break;
      }
      final observationId = '${fact['chosen_observation_id'] ?? ''}';
      final observation = observationsById[observationId];
      final sourceDocId = '${observation?['source_doc_id'] ?? ''}';
      if (observation == null || !sourceDocIds.contains(sourceDocId)) {
        issues.add('resolved_fact_without_packaged_source_document');
        break;
      }
    }

    if (drugVariants.isNotEmpty && drugLabelSections.isEmpty) {
      warnings.add('drug_variants_without_label_sections');
    }
    if (observations.isEmpty) {
      warnings.add('missing_observations');
    }

    return SnapshotBundleValidationReport(
      snapshotId: snapshotId,
      isValid: issues.isEmpty,
      blockingIssues: issues,
      warnings: warnings,
      tableCounts: tableCounts,
    );
  }

  Future<void> _recordBundleImportFailure({
    required String snapshotId,
    required String channel,
    required String filePath,
    required String errorMessage,
    SnapshotBundleValidationReport? validation,
  }) async {
    final now = DateTime.now();
    await database.insertIngestionRun(
      IngestionRunRecord(
        runId:
            'bundle_import_failed_${stableHash('$snapshotId:$filePath:${now.microsecondsSinceEpoch}')}',
        sourceFamily: 'snapshot_bundle',
        stage: 'bundle_import',
        status: 'failed',
        snapshotId: snapshotId,
        parentSnapshotId: null,
        notesJson: jsonEncode({
          'artifact_path': filePath,
          'error_message': errorMessage,
          if (validation != null) 'bundle_validation': validation.toJson(),
        }),
        createdAt: now,
        completedAt: now,
      ),
    );
    await database.insertSnapshotDistribution(
      SnapshotDistributionRecord(
        distributionId:
            'dist_import_failed_${stableHash('$snapshotId:$channel:${now.microsecondsSinceEpoch}')}',
        snapshotId: snapshotId,
        channel: channel,
        distributionType: 'import_bundle',
        status: 'failed',
        artifactPath: filePath,
        manifestJson:
            validation == null ? '{}' : jsonEncode(validation.toJson()),
        errorMessage: errorMessage,
        createdAt: now,
        completedAt: now,
      ),
    );
  }

  SnapshotDistributionRecord _mapDistributionRecord(Map<String, Object?> row) {
    return SnapshotDistributionRecord(
      distributionId: '${row['distribution_id'] ?? ''}',
      snapshotId: '${row['snapshot_id'] ?? ''}',
      channel: '${row['channel'] ?? ''}',
      distributionType: '${row['distribution_type'] ?? ''}',
      status: '${row['status'] ?? ''}',
      artifactPath: row['artifact_path']?.toString(),
      manifestJson: '${row['manifest_json'] ?? ''}',
      errorMessage: row['error_message']?.toString(),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num?)?.toInt() ?? 0,
      ),
      completedAt: row['completed_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (row['completed_at'] as num).toInt(),
            ),
    );
  }

  HumanReviewTicketRecord _mapReviewTicketRecord(Map<String, Object?> row) {
    return HumanReviewTicketRecord(
      ticketId: '${row['ticket_id'] ?? ''}',
      reasonCode: '${row['reason_code'] ?? ''}',
      severity: '${row['severity'] ?? ''}',
      targetType: '${row['target_type'] ?? ''}',
      targetId: '${row['target_id'] ?? ''}',
      snapshotId: '${row['snapshot_id'] ?? ''}',
      runId: row['run_id']?.toString(),
      sourceDocRefsJson: '${row['source_doc_refs_json'] ?? '[]'}',
      suggestedAction: '${row['suggested_action'] ?? ''}',
      status: '${row['status'] ?? 'open'}',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (row['created_at'] as num?)?.toInt() ?? 0,
      ),
      resolvedAt: row['resolved_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
              (row['resolved_at'] as num).toInt(),
            ),
    );
  }

  Map<String, dynamic> _safeDecodeMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // notes_json 允许历史行保持旧格式，因此这里保守降级为空 map。
    }
    return <String, dynamic>{};
  }

  List<dynamic> _safeDecodeList(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
    } catch (_) {}
    return const <dynamic>[];
  }

  Map<String, dynamic> _coerceMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    if (raw is String) return _safeDecodeMap(raw);
    return <String, dynamic>{};
  }

  Map<String, dynamic> _conflictRationaleRow(Map<String, Object?> row) {
    final decodedReason = _coerceMap(row['decision_reason']);
    return {
      'audit_id': row['audit_id'],
      'audit_type': row['audit_type'],
      'target': row['target'],
      'decision': row['decision'],
      'decision_reason': row['decision_reason'],
      if (decodedReason.isNotEmpty) 'rationale': decodedReason,
      'needs_human_review': row['needs_human_review'],
    };
  }

  bool _isInvalidRuleRegistryRow(Map<String, Object?> row) {
    if ('${row['status'] ?? ''}' != 'active') return false;
    const requiredText = [
      'rule_id',
      'rule_version',
      'rule_type',
      'jurisdiction_json',
      'applies_to_json',
      'predicate_json',
      'effect_json',
      'provenance_json',
    ];
    for (final key in requiredText) {
      if ('${row[key] ?? ''}'.trim().isEmpty) return true;
    }
    if (row['priority_band'] is! num || row['specificity_band'] is! num) {
      return true;
    }
    final ruleType = '${row['rule_type'] ?? ''}';
    if (!const {
      'hard_constraint',
      'soft_rule',
      'temporal_rule',
      'dose_dependent_rule',
      'jurisdiction_override',
      'source_resolution_rule',
      'escalation_rule',
      'hardConstraint',
      'softRule',
      'temporalRule',
      'doseDependentRule',
      'jurisdictionOverride',
      'sourceResolutionRule',
      'escalationRule',
    }.contains(ruleType)) {
      return true;
    }
    try {
      jsonDecode('${row['jurisdiction_json']}');
      jsonDecode('${row['applies_to_json']}');
      jsonDecode('${row['predicate_json']}');
      jsonDecode('${row['effect_json']}');
      jsonDecode('${row['provenance_json']}');
    } catch (_) {
      return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _coerceRows(dynamic raw) {
    if (raw is! List) return const <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  SourceDocumentRecord _mapSourceDocument(Map<String, dynamic> row) {
    return SourceDocumentRecord(
      sourceDocId: '${row['source_doc_id'] ?? ''}',
      sourceFamily: '${row['source_family'] ?? ''}',
      dataTier: '${row['data_tier'] ?? KnowledgeDataTier.p0}',
      ingestionStrategy:
          '${row['ingestion_strategy'] ?? SourceIngestionStrategy.authoritativeDirect}',
      organization: '${row['organization'] ?? ''}',
      jurisdiction: '${row['jurisdiction'] ?? ''}',
      docType: '${row['doc_type'] ?? ''}',
      title: '${row['title'] ?? ''}',
      originUrl: '${row['origin_url'] ?? ''}',
      publishedAt: _epochToDateTime(row['published_at']),
      effectiveAt: _epochToDateTime(row['effective_at']),
      language: '${row['language'] ?? ''}',
      licenseNote: '${row['license_note'] ?? ''}',
      checksum: '${row['checksum'] ?? ''}',
      sourceStatus: '${row['source_status'] ?? ''}',
      rawPayload: '${row['raw_payload'] ?? ''}',
    );
  }

  FoodConceptRecord _mapFoodConcept(Map<String, dynamic> row) {
    return FoodConceptRecord(
      foodConceptId: '${row['food_concept_id'] ?? ''}',
      canonicalNameEn: '${row['canonical_name_en'] ?? ''}',
      canonicalNameZh: '${row['canonical_name_zh'] ?? ''}',
      foodGroup: '${row['food_group'] ?? ''}',
    );
  }

  FoodVariantRecord _mapFoodVariant(Map<String, dynamic> row) {
    return FoodVariantRecord(
      foodVariantId: '${row['food_variant_id'] ?? ''}',
      foodConceptId: '${row['food_concept_id'] ?? ''}',
      jurisdiction: '${row['jurisdiction'] ?? ''}',
      sourceFamily: '${row['source_family'] ?? ''}',
      sourceFoodCode: row['source_food_code']?.toString(),
      displayNameLocal: '${row['display_name_local'] ?? ''}',
      isAuthoritativeForRegion: _numToBool(row['is_authoritative_for_region']),
      isAuthoritativeFallback: _numToBool(row['is_authoritative_fallback']),
      status: '${row['status'] ?? ''}',
      fallbackChainJson: '${row['fallback_chain_json'] ?? '[]'}',
    );
  }

  DrugConceptRecord _mapDrugConcept(Map<String, dynamic> row) {
    return DrugConceptRecord(
      drugConceptId: '${row['drug_concept_id'] ?? ''}',
      genericName: '${row['generic_name'] ?? ''}',
      atcLikeCode: '${row['atc_like_code'] ?? ''}',
    );
  }

  DrugProductVariantRecord _mapDrugProductVariant(Map<String, dynamic> row) {
    return DrugProductVariantRecord(
      drugProductVariantId: '${row['drug_product_variant_id'] ?? ''}',
      drugConceptId: '${row['drug_concept_id'] ?? ''}',
      jurisdiction: '${row['jurisdiction'] ?? ''}',
      regulator: '${row['regulator'] ?? ''}',
      externalProductCode: '${row['external_product_code'] ?? ''}',
      route: '${row['route'] ?? ''}',
      dosageForm: '${row['dosage_form'] ?? ''}',
      releaseType: '${row['release_type'] ?? ''}',
      labelVersion: '${row['label_version'] ?? ''}',
      sourceStatus: '${row['source_status'] ?? ''}',
    );
  }

  DrugLabelSectionRecord _mapDrugLabelSection(Map<String, dynamic> row) {
    return DrugLabelSectionRecord(
      sectionId: '${row['section_id'] ?? ''}',
      drugProductVariantId: '${row['drug_product_variant_id'] ?? ''}',
      sourceDocId: '${row['source_doc_id'] ?? ''}',
      sectionKey: '${row['section_key'] ?? ''}',
      sectionTitle: '${row['section_title'] ?? ''}',
      sectionText: '${row['section_text'] ?? ''}',
    );
  }

  DrugProductCodeRecord _mapDrugProductCode(Map<String, dynamic> row) {
    return DrugProductCodeRecord(
      productCodeId: '${row['product_code_id'] ?? ''}',
      drugProductVariantId: '${row['drug_product_variant_id'] ?? ''}',
      sourceDocId: '${row['source_doc_id'] ?? ''}',
      codeSystem: '${row['code_system'] ?? ''}',
      codeValue: '${row['code_value'] ?? ''}',
      displayText: row['display_text']?.toString(),
    );
  }

  DrugProductPackagingRecord _mapDrugProductPackaging(
      Map<String, dynamic> row) {
    return DrugProductPackagingRecord(
      packagingId: '${row['packaging_id'] ?? ''}',
      drugProductVariantId: '${row['drug_product_variant_id'] ?? ''}',
      sourceDocId: '${row['source_doc_id'] ?? ''}',
      packageCode: row['package_code']?.toString(),
      description: '${row['description'] ?? ''}',
      marketingStatus: row['marketing_status']?.toString(),
    );
  }

  DrugProductMediaRecord _mapDrugProductMedia(Map<String, dynamic> row) {
    return DrugProductMediaRecord(
      mediaId: '${row['media_id'] ?? ''}',
      drugProductVariantId: '${row['drug_product_variant_id'] ?? ''}',
      sourceDocId: '${row['source_doc_id'] ?? ''}',
      mediaType: '${row['media_type'] ?? ''}',
      mediaUrl: '${row['media_url'] ?? ''}',
      caption: row['caption']?.toString(),
    );
  }

  VariantScopeRecord _mapVariantScope(Map<String, dynamic> row) {
    return VariantScopeRecord(
      scopeHash: '${row['scope_hash'] ?? ''}',
      jurisdiction: '${row['jurisdiction'] ?? ''}',
      brand: row['brand']?.toString(),
      dosageForm: row['dosage_form']?.toString(),
      releaseType: row['release_type']?.toString(),
      saltForm: row['salt_form']?.toString(),
      route: row['route']?.toString(),
      preparationState: row['preparation_state']?.toString(),
      cookingState: row['cooking_state']?.toString(),
      plantPart: row['plant_part']?.toString(),
      cultivar: row['cultivar']?.toString(),
      samplingFrame: row['sampling_frame']?.toString(),
    );
  }

  ObservationRecord _mapObservation(Map<String, dynamic> row) {
    return ObservationRecord(
      observationId: '${row['observation_id'] ?? ''}',
      domain: '${row['domain'] ?? ''}',
      entityType: '${row['entity_type'] ?? ''}',
      entityKey: '${row['entity_key'] ?? ''}',
      attributeCode: '${row['attribute_code'] ?? ''}',
      valueType: '${row['value_type'] ?? ''}',
      value: _mapQualifiedValue(row),
      unit: '${row['unit'] ?? ''}',
      basisType: '${row['basis_type'] ?? ''}',
      basisAmount: _toDouble(row['basis_amount']),
      scopeHash: '${row['scope_hash'] ?? ''}',
      sourceDocId: '${row['source_doc_id'] ?? ''}',
      recordLocator: '${row['record_locator'] ?? ''}',
      methodCode: row['method_code']?.toString(),
      extractionConfidence: _toDouble(row['extraction_confidence']) ?? 1,
    );
  }

  ResolvedFactRecord _mapResolvedFact(Map<String, dynamic> row) {
    return ResolvedFactRecord(
      factId: '${row['fact_id'] ?? ''}',
      entityKey: '${row['entity_key'] ?? ''}',
      attributeCode: '${row['attribute_code'] ?? ''}',
      scopeHash: '${row['scope_hash'] ?? ''}',
      resolutionStatus: '${row['resolution_status'] ?? ''}',
      chosenObservationId: '${row['chosen_observation_id'] ?? ''}',
      resolvedValue: _mapQualifiedValue(
        row,
        lowKey: 'resolved_low',
        highKey: 'resolved_high',
      ),
      resolvedUnit: '${row['resolved_unit'] ?? ''}',
      resolutionPolicyId: '${row['resolution_policy_id'] ?? ''}',
      snapshotId: '${row['snapshot_id'] ?? ''}',
      factVersion: '${row['fact_version'] ?? ''}',
      manualOverride: _numToBool(row['manual_override']),
    );
  }

  CountryDietProfileRecord _mapCountryDietProfile(Map<String, dynamic> row) {
    return CountryDietProfileRecord(
      countryCode: '${row['country_code'] ?? ''}',
      guidelineSource: '${row['guideline_source'] ?? ''}',
      mealPatternJson: '${row['meal_pattern_json'] ?? '{}'}',
      stapleFoodsJson: '${row['staple_foods_json'] ?? '[]'}',
      preferredProteinSourcesJson:
          '${row['preferred_protein_sources_json'] ?? '[]'}',
      avoidanceNotesJson: '${row['avoidance_notes_json'] ?? '[]'}',
    );
  }

  MealTemplateRecord _mapMealTemplate(Map<String, dynamic> row) {
    return MealTemplateRecord(
      mealTemplateId: '${row['meal_template_id'] ?? ''}',
      countryCode: '${row['country_code'] ?? ''}',
      mealSlot: '${row['meal_slot'] ?? ''}',
      templateJson: '${row['template_json'] ?? '{}'}',
      textureLevel: '${row['texture_level'] ?? ''}',
    );
  }

  EngineSnapshotRecord _mapSnapshot(Map<String, dynamic> row) {
    return EngineSnapshotRecord(
      snapshotId: '${row['snapshot_id'] ?? ''}',
      factsVersion: '${row['facts_version'] ?? ''}',
      rulesVersion: '${row['rules_version'] ?? ''}',
      createdAt: _epochToDateTime(row['created_at']) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      promotedAt: _epochToDateTime(row['promoted_at']),
      rollbackParent: row['rollback_parent']?.toString(),
      inputHash: '${row['input_hash'] ?? ''}',
    );
  }

  QualifiedValue _mapQualifiedValue(
    Map<String, dynamic> row, {
    String lowKey = 'low',
    String highKey = 'high',
  }) {
    return QualifiedValue(
      qualifierKind: _mapQualifierKind('${row['qualifier_kind'] ?? 'missing'}'),
      low: _toDouble(row[lowKey]),
      high: _toDouble(row[highKey]),
      valueNum: _toDouble(row['value_num']),
      rawValueText: '${row['raw_value_text'] ?? ''}',
    );
  }

  QualifierKind _mapQualifierKind(String raw) {
    switch (raw) {
      case 'exact':
        return QualifierKind.exact;
      case 'range':
        return QualifierKind.range;
      case 'lt':
        return QualifierKind.lessThan;
      case 'lte':
        return QualifierKind.lessThanOrEqual;
      case 'trace':
        return QualifierKind.trace;
      case 'parsing_uncertainty':
        return QualifierKind.parsingUncertainty;
      case 'missing':
      default:
        return QualifierKind.missing;
    }
  }

  DateTime? _epochToDateTime(dynamic value) {
    final epoch = (value as num?)?.toInt();
    if (epoch == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(epoch);
  }

  bool _numToBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return '${value ?? ''}' == '1' || '${value ?? ''}'.toLowerCase() == 'true';
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse('${value ?? ''}');
  }
}
