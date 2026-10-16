import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_artifact_store_stub.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/knowledge_base_release_service.dart';

import 'held_import_review_evidence_test.dart'
    show serviceFor, conflictingBundle, sourceFields, sourceDocument;
import 'fact_conflict_complete_cluster_test.dart' show evidence;
import 'fact_conflict_incumbent_activation_test.dart' show incumbent;

typedef HeldCandidate = ({
  WebCdssDatabase database,
  ClinicalDecisionSupportService cdss,
  KnowledgeBaseReleaseService release,
  Map<String, Object?> audit,
  String ticketId,
  Map<String, dynamic> evidence,
});

Future<HeldCandidate> heldCandidate({P0ImportBundle? bundle}) async {
  final database = WebCdssDatabase();
  final cdss = serviceFor(database);
  await expectLater(
    cdss.importBundle(bundle ?? conflictingBundle()),
    throwsA(isA<CdssImportHeldException>()),
  );
  final audit = (await database.queryTable('conflict_audit_log')).single;
  final release = KnowledgeBaseReleaseService(
    database: database,
    cdssService: cdss,
    artifactStore: InlineCdssArtifactStore(),
  );
  await release.validateReleaseCandidate('${audit['snapshot_id']}');
  final ticket = (await release.listReviewTickets(
    snapshotId: '${audit['snapshot_id']}',
  )).singleWhere((row) => row.reasonCode == 'unresolved_conflict');
  final packet = await serviceFor(
    WebCdssDatabase(),
  ).loadHeldImportReviewEvidence(snapshotId: ticket.snapshotId);
  return (
    database: database,
    cdss: cdss,
    release: release,
    audit: audit,
    ticketId: ticket.ticketId,
    evidence: packet,
  );
}

Future<dynamic> review(
  HeldCandidate held, {
  String action = 'choose_observation',
  String? observation = 'b',
  String? hash,
}) => held.release.recordImportConflictReviewDecision(
  ticketId: held.ticketId,
  conflictAuditId: '${held.audit['audit_id']}',
  expectedEvidenceSha256: hash ?? '${held.evidence['input_sha256']}',
  action: action,
  chosenObservationId: observation,
  reviewerReference: 'test-local-reviewer',
  reason: 'Original source evidence reviewed for this software fixture.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'a fresh graph recovers every source field and the complete original graph',
    () async {
      final held = await heldCandidate();
      final payload = held.evidence['payload'] as Map;
      expect((payload['source_documents'] as List).single, sourceFields);
      expect(
        (payload['observations'] as List).map(
          (row) => (row as Map)['raw_value_text'],
        ),
        ['1', '10'],
      );
      expect(
        (payload['staging_rows'] as Map)['staging_observation'],
        hasLength(2),
      );
      expect(
        (payload['conflict_rationales'] as List).single['comparison_edges'],
        hasLength(1),
      );
      expect((payload['conflict_audits'] as List).single, held.audit);
    },
  );

  test(
    'an explicit quantity choice binds evidence while preserving the original hold',
    () async {
      final held = await heldCandidate();
      final decision = await review(held);
      final saved = jsonDecode(decision.decisionReason as String) as Map;
      expect(saved['chosen_source'], sourceFields);
      expect((saved['chosen_observation'] as Map)['raw_value_text'], '10');
      expect(saved['activation_authorized'], isFalse);
      expect(saved['clinical_approval'], isFalse);
      expect(
        await held.release.isImportConflictReviewDecisionCurrent(
          decision.auditId as String,
        ),
        isTrue,
      );
      expect(
        (await held.database.queryTable('conflict_audit_log')).first,
        held.audit,
      );
      expect(
        (await held.release.listReviewTickets())
            .singleWhere((row) => row.ticketId == held.ticketId)
            .status,
        'open',
      );
      expect(
        (await held.release.validateReleaseCandidate(
          '${held.audit['snapshot_id']}',
        )).unresolvedConflictCount,
        1,
      );
      expect(await held.cdss.latestPromotedSnapshot(), isNull);
      expect(await held.database.queryTable('observation'), isEmpty);
    },
  );

  test(
    'closing a ticket cannot resolve its original conflict or create a decision',
    () async {
      final held = await heldCandidate();
      await held.release.updateReviewTicketStatus(
        ticketId: held.ticketId,
        status: 'resolved',
      );
      expect(
        (await held.release.validateReleaseCandidate(
          '${held.audit['snapshot_id']}',
        )).unresolvedConflictCount,
        1,
      );
      await expectLater(
        review(held, action: 'defer', observation: null),
        throwsStateError,
      );
      expect(await held.cdss.latestPromotedSnapshot(), isNull);
    },
  );

  test(
    'staged content drift rejects evidence and invalidates an earlier decision',
    () async {
      final held = await heldCandidate();
      final decision = await review(held, action: 'defer', observation: null);
      final staged = (await held.database.queryTable(
        'staging_observation',
      )).first;
      final payload = jsonDecode(staged['payload_json'] as String) as Map;
      payload['raw_value_text'] = '100';
      await held.database.insertStagingRow('staging_observation', {
        ...staged,
        'payload_json': jsonEncode(payload),
      });
      await expectLater(
        serviceFor(WebCdssDatabase()).loadHeldImportReviewEvidence(
          snapshotId: '${held.audit['snapshot_id']}',
        ),
        throwsStateError,
      );
      expect(
        await held.release.isImportConflictReviewDecisionCurrent(
          decision.auditId as String,
        ),
        isFalse,
      );
      expect(await held.cdss.latestPromotedSnapshot(), isNull);
    },
  );

  test(
    'packet corruption, stale evidence hashes and unrelated choices are rejected',
    () async {
      final held = await heldCandidate();
      await expectLater(review(held, hash: 'stale'), throwsStateError);
      await expectLater(
        review(held, observation: 'unrelated'),
        throwsArgumentError,
      );
      final row = (await held.database.queryTable(
        'ingestion_run',
      )).singleWhere((row) => row['status'] == 'held_for_conflict_review');
      final notes = jsonDecode(row['notes_json'] as String) as Map;
      ((notes['review_evidence'] as Map)['payload']
              as Map)['source_documents'] =
          [];
      await held.database.insertStagingRow('ingestion_run', {
        ...row,
        'notes_json': jsonEncode(notes),
      });
      await expectLater(
        serviceFor(WebCdssDatabase()).loadHeldImportReviewEvidence(
          snapshotId: '${held.audit['snapshot_id']}',
        ),
        throwsStateError,
      );
      expect(await held.database.queryTable('resolved_fact'), isEmpty);
    },
  );

  test(
    'incumbent source changes invalidate a previously frozen packet',
    () async {
      final held = await heldCandidate();
      await held.database.insertSourceDocument(sourceDocument());
      await expectLater(
        held.cdss.loadHeldImportReviewEvidence(
          snapshotId: '${held.audit['snapshot_id']}',
        ),
        throwsStateError,
      );
    },
  );

  test('original audit changes invalidate the packet', () async {
    final held = await heldCandidate();
    await held.database.insertStagingRow('conflict_audit_log', {
      ...held.audit,
      'decision_reason': '{}',
    });
    await expectLater(
      held.cdss.loadHeldImportReviewEvidence(
        snapshotId: '${held.audit['snapshot_id']}',
      ),
      throwsStateError,
    );
  });

  test(
    'identity or missing-evidence holds cannot be repaired by a numeric choice',
    () async {
      final held = await heldCandidate(
        bundle: P0ImportBundle(
          resolvedFacts: [incumbent(evidence('missing', '1'))],
        ),
      );
      await expectLater(review(held, observation: 'missing'), throwsStateError);
      final decision = await review(
        held,
        action: 'request_corrected_evidence',
        observation: null,
      );
      expect(
        await held.release.isImportConflictReviewDecisionCurrent(
          decision.auditId as String,
        ),
        isTrue,
      );
      expect(await held.database.queryTable('resolved_fact'), isEmpty);
    },
  );

  test(
    'a ticket for another target cannot authorize this conflict decision',
    () async {
      final held = await heldCandidate();
      final ticket = (await held.database.queryTable(
        'human_review_ticket',
      )).singleWhere((row) => row['ticket_id'] == held.ticketId);
      await held.database.insertStagingRow('human_review_ticket', {
        ...ticket,
        'target_id': 'foreign-target',
      });
      await expectLater(review(held), throwsStateError);
      expect(
        (await held.database.queryTable('conflict_audit_log')),
        hasLength(1),
      );
    },
  );

  test(
    'an unqualified method or absent source cannot supply a reviewed quantity',
    () async {
      final held = await heldCandidate(
        bundle: P0ImportBundle(
          sourceDocuments: [sourceDocument()],
          observations: [
            evidence('a', '1', method: null),
            evidence('b', '10', method: null),
          ],
        ),
      );
      await expectLater(review(held), throwsStateError);
    },
  );

  test('an absent original source requires corrected evidence', () async {
    final held = await heldCandidate(
      bundle: P0ImportBundle(
        observations: [evidence('a', '1'), evidence('b', '10')],
      ),
    );
    await expectLater(review(held), throwsStateError);
    await review(held, action: 'request_corrected_evidence', observation: null);
    expect(await held.cdss.latestPromotedSnapshot(), isNull);
  });

  test(
    'a closed ticket invalidates a decision even while its source stays exact',
    () async {
      final held = await heldCandidate();
      final decision = await review(held);
      await held.release.updateReviewTicketStatus(
        ticketId: held.ticketId,
        status: 'ignored',
      );
      expect(
        await held.release.isImportConflictReviewDecisionCurrent(
          decision.auditId as String,
        ),
        isFalse,
      );
      expect(
        (await held.release.validateReleaseCandidate(
          '${held.audit['snapshot_id']}',
        )).unresolvedConflictCount,
        1,
      );
    },
  );
}
