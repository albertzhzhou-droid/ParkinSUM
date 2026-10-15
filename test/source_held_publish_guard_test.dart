import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'import_conflict_review_decision_test.dart' show heldCandidate, review;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'generic override cannot publish or dry-run a source-held candidate',
    () async {
      final held = await heldCandidate();
      final snapshot = '${held.audit['snapshot_id']}';
      const reason = 'Synthetic local override counterexample';
      final readiness = await held.release.validateReleaseCandidate(snapshot);
      expect(
        readiness.blockingIssues,
        contains('source_import_held_for_review'),
      );
      final drill = await held.release.runReleaseReadinessDrill(
        snapshotId: snapshot,
        overrideReason: reason,
      );
      expect(drill.publishWouldBeBlocked, isTrue);
      expect(drill.overrideWouldAllowPublish, isFalse);
      expect(drill.humanReadableSummary, contains('Publish guard: blocked'));
      await expectLater(
        held.release.publishSnapshot(
          snapshotId: snapshot,
          overrideReason: reason,
        ),
        throwsStateError,
      );
      final distribution = (await held.release.listSnapshotDistributions())
          .singleWhere((row) => row.distributionType == 'publish');
      expect(distribution.status, 'failed');
      final guard =
          (jsonDecode(distribution.manifestJson) as Map)['publish_guard']
              as Map;
      expect(guard['override_used'], isFalse);
      expect(guard['attempted_override_reason'], reason);
      expect(await held.cdss.latestPromotedSnapshot(), isNull);
    },
  );

  test(
    'closing tickets and saving an advisory choice preserve the source hold',
    () async {
      final held = await heldCandidate();
      await review(held);
      await held.release.updateReviewTicketStatus(
        ticketId: held.ticketId,
        status: 'ignored',
      );
      await expectLater(
        held.release.publishSnapshot(
          snapshotId: '${held.audit['snapshot_id']}',
          overrideReason: 'Reviewed locally',
        ),
        throwsStateError,
      );
      expect(
        (await held.database.queryTable('conflict_audit_log')).first,
        held.audit,
      );
      expect(await held.database.queryTable('resolved_fact'), isEmpty);
    },
  );

  test(
    'the original hold blocks publication even if run status is changed',
    () async {
      final held = await heldCandidate();
      final run = (await held.database.queryTable(
        'ingestion_run',
      )).singleWhere((row) => row['status'] == 'held_for_conflict_review');
      await held.database.insertStagingRow('ingestion_run', {
        ...run,
        'status': 'completed',
      });
      final readiness = await held.release.validateReleaseCandidate(
        '${held.audit['snapshot_id']}',
      );
      expect(readiness.issueCounts['held_source_imports'], 0);
      expect(readiness.issueCounts['original_source_holds'], 1);
      await expectLater(
        held.release.publishSnapshot(
          snapshotId: '${held.audit['snapshot_id']}',
          overrideReason: 'Synthetic status drift',
        ),
        throwsStateError,
      );
    },
  );
}
