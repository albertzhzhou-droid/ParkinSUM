import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_support.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/knowledge_base_release_service.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_artifact_store_stub.dart';

import 'held_import_complete_resources_test.dart' show completeHeldBundle;
import 'held_import_review_evidence_test.dart' show serviceFor;
import 'import_conflict_review_decision_test.dart' show heldCandidate, review;
import 'fact_conflict_complete_cluster_test.dart' show evidence;

P0ImportBundle activationBundle({
  String status = 'active',
  DateTime? publishedAt,
  bool missingAlternativeSource = false,
  bool danglingConcept = false,
}) {
  final original = completeHeldBundle();
  return P0ImportBundle(
    sourceDocuments: [
      buildSourceDocumentRecord(
        sourceDocId: 'source',
        sourceFamily: 'source-test',
        organization: 'Source organization',
        jurisdiction: 'US',
        docType: 'source quantities',
        title: 'Original source title',
        originUrl: 'https://example.invalid/synthetic-source',
        licenseNote: 'Synthetic software fixture',
        rawPayload: '{"original":"source text with 中文"}',
        sourceStatus: status,
        publishedAt: publishedAt,
      ),
    ],
    observations: missingAlternativeSource
        ? [evidence('a', '1', source: 'absent'), evidence('b', '10')]
        : original.observations,
    countryDietProfiles: original.countryDietProfiles,
    foodConcepts: original.foodConcepts,
    drugConcepts: original.drugConcepts,
    drugLabelSections: original.drugLabelSections,
    drugProductCodes: original.drugProductCodes,
    drugProductPackagings: original.drugProductPackagings,
    drugProductMedias: original.drugProductMedias,
    foodVariants: [
      FoodVariantRecord(
        foodVariantId: 'same-food',
        foodConceptId: danglingConcept ? 'absent-concept' : 'food',
        jurisdiction: 'US',
        sourceFamily: 'source-test',
        sourceFoodCode: 'original-food-code',
        displayNameLocal: 'Original food',
        isAuthoritativeForRegion: false,
        isAuthoritativeFallback: false,
        status: 'active',
        fallbackChainJson: '[]',
      ),
    ],
    drugProductVariants: const [
      DrugProductVariantRecord(
        drugProductVariantId: 'drug-v',
        drugConceptId: 'drug',
        jurisdiction: 'US',
        regulator: 'source-test',
        externalProductCode: 'original-drug-code',
        route: 'oral',
        dosageForm: 'original-form',
        releaseType: 'unspecified',
        labelVersion: 'original-label',
        sourceStatus: 'active',
      ),
    ],
    variantScopes: const [
      VariantScopeRecord(
        scopeHash: 'same-scope',
        jurisdiction: 'US',
        brand: null,
        dosageForm: null,
        releaseType: null,
        saltForm: null,
        route: null,
        preparationState: null,
        cookingState: null,
        plantPart: null,
        cultivar: null,
        samplingFrame: null,
      ),
    ],
    resolvedFacts: [
      resolvedFactFromObservation(
        observation: original.observations.first,
        policyId: 'original-policy',
        snapshotId: 'original',
      ),
    ],
    ruleRegistryRows: const [
      {
        'rule_id': 'original-rule',
        'rule_version': 'original-rules',
        'status': 'inactive',
        'rule_type': 'safety',
        'priority_band': 1,
        'specificity_band': 1,
        'jurisdiction_json': '["US"]',
        'applies_to_json': '{}',
        'predicate_json': '{}',
        'effect_json': '{}',
        'provenance_json': '{}',
        'override_json': null,
        'compiled_hash': 'original-hash',
        'updated_at': 123,
      },
    ],
    runtimeEvents: [
      RuntimeEventRecord(
        eventId: 'original-event',
        patientId: 'synthetic',
        eventType: 'original-type',
        snapshotId: 'original',
        contextJson: '{"preserved":"context"}',
        machineReadableJson: '{}',
        humanReadableMarkdown: 'Original 中文',
        jurisdiction: 'US',
        timezone: 'UTC',
        createdAt: DateTime.fromMillisecondsSinceEpoch(123),
      ),
    ],
    projectedFoods: [
      FoodItem(
        id: 'food-app',
        name: 'Original food',
        category: FoodCategory.other,
        proteinG: 1,
        carbsG: 2,
        fatG: 3,
        fiberG: 4,
        sodiumMg: 5,
      ),
    ],
    projectedDrugs: [
      DrugDefinition(
        id: 'drug-app',
        genericName: 'Original drug',
        brandNames: const ['Original'],
        tags: const [DrugTag.unknown],
        notes: 'Original note',
      ),
    ],
  );
}

class ReceiptFailureDatabase extends WebCdssDatabase {
  bool rejectReceipt = false;
  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) {
    if (rejectReceipt && record.auditType == 'REVIEWED_IMPORT_ACTIVATION') {
      throw StateError('Synthetic activation receipt failure');
    }
    return super.insertConflictAuditLog(record);
  }
}

Future<
  ({
    ClinicalDecisionSupportService cdss,
    KnowledgeBaseReleaseService release,
    String snapshotId,
    String decisionId,
  })
>
prepareOn(CdssDatabase db, ClinicalDecisionSupportService cdss) async {
  await expectLater(
    cdss.importBundle(activationBundle()),
    throwsA(isA<CdssImportHeldException>()),
  );
  final audit = (await db.queryTable('conflict_audit_log')).single;
  final snapshotId = audit['snapshot_id'] as String;
  final release = KnowledgeBaseReleaseService(
    database: db,
    cdssService: cdss,
    artifactStore: InlineCdssArtifactStore(),
  );
  await release.validateReleaseCandidate(snapshotId);
  final ticket = (await release.listReviewTickets(
    snapshotId: snapshotId,
  )).singleWhere((t) => t.reasonCode == 'unresolved_conflict');
  final packet = await cdss.loadHeldImportReviewEvidence(
    snapshotId: snapshotId,
  );
  final decision = await release.recordImportConflictReviewDecision(
    ticketId: ticket.ticketId,
    conflictAuditId: audit['audit_id'] as String,
    expectedEvidenceSha256: packet['input_sha256'] as String,
    action: 'choose_observation',
    reviewerReference: 'synthetic-local-review',
    reason: 'Explicit source fixture review',
    chosenObservationId: 'b',
  );
  return (
    cdss: cdss,
    release: release,
    snapshotId: snapshotId,
    decisionId: decision.auditId,
  );
}

Future<CdssImportReport> activate(
  ClinicalDecisionSupportService cdss,
  CdssReviewedImportPreview preview,
) => cdss.activateReviewedImport(
  preview: preview,
  confirmationReference: 'synthetic-local-confirmation',
  confirmationReason: 'Software fixture confirmation; no clinical approval.',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'preview is read-only and complete resources create a new derived snapshot',
    () async {
      final held = await heldCandidate(bundle: activationBundle());
      final decision = await review(held);
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(WebCdssDatabase.stateKey);
      final preview = await held.release.previewReviewedImport(
        heldSnapshotId: '${held.audit['snapshot_id']}',
        decisionIds: [decision.auditId],
      );
      await prefs.reload();
      expect(prefs.getString(WebCdssDatabase.stateKey), before);
      expect(preview.selectedObservations.single['raw_value_text'], '10');
      expect(() => preview.decisionIds.add('altered'), throwsUnsupportedError);
      expect(
        () => preview.selectedObservations.single['unit'] = 'altered',
        throwsUnsupportedError,
      );
      final originalTables = jsonDecode(before!)['tables'] as Map;
      final report = await activate(held.cdss, preview);
      final fresh = WebCdssDatabase();
      final archive = await serviceFor(
        fresh,
      ).loadHeldImportReviewArchive(snapshotId: preview.heldSnapshotId);
      expect(archive['evidence'], held.evidence);
      expect(archive['current_activation_eligible'], false);
      await expectLater(
        serviceFor(
          fresh,
        ).loadHeldImportReviewEvidence(snapshotId: preview.heldSnapshotId),
        throwsStateError,
      );
      expect(
        (await serviceFor(fresh).latestPromotedSnapshot())?.snapshotId,
        report.promotedSnapshotId,
      );
      final snapshots = await fresh.queryTable('engine_snapshot');
      expect(
        snapshots.singleWhere(
          (r) => r['snapshot_id'] == preview.heldSnapshotId,
        ),
        (originalTables['engine_snapshot'] as List).single,
      );
      expect(
        (await fresh.queryTable(
          'ingestion_run',
        )).where((r) => r['status'] == 'held_for_conflict_review'),
        hasLength(1),
      );
      expect(
        (await fresh.queryTable(
          'staging_observation',
        )).where((r) => r['run_id'] == held.audit['run_id']),
        hasLength(2),
      );
      expect((await fresh.queryTable('conflict_audit_log')).first, held.audit);
      expect(
        (await fresh.queryTable(
          'observation',
        )).map((r) => r['raw_value_text']).toSet(),
        {'1', '10'},
      );
      final fact = (await fresh.queryTable('resolved_fact')).single;
      expect(fact['chosen_observation_id'], 'b');
      expect(fact['value_num'], 10);
      expect(fact['resolution_policy_id'], decision.auditId);
      expect(fact['manual_override'], true);
      for (final table in [
        'country_diet_profile',
        'food_concept',
        'food_variant',
        'drug_concept',
        'drug_product_variant',
        'drug_label_section',
        'drug_product_code',
        'drug_product_packaging',
        'drug_product_media',
        'variant_scope',
        'runtime_event',
        'rule_registry',
      ]) {
        expect(await fresh.queryTable(table), hasLength(1), reason: table);
      }
      expect(
        (await fresh.queryTable('drug_label_section')).single['section_text'],
        'Unchanged source text',
      );
      expect(
        (await fresh.queryTable('runtime_event')).single['created_at'],
        123,
      );
      expect(
        (await fresh.queryTable('source_document')).single['raw_payload'],
        activationBundle().sourceDocuments.single.rawPayload,
      );
      final audits = await fresh.queryTable('conflict_audit_log');
      final derived = audits.singleWhere(
        (r) => r['decision'] == 'explicit_source_review_choice',
      );
      final rationale = jsonDecode(derived['decision_reason'] as String) as Map;
      expect(
        rationale['original_rationale'],
        jsonDecode(held.audit['decision_reason'] as String),
      );
      final receipt =
          jsonDecode(
                audits.singleWhere(
                      (r) => r['audit_type'] == 'REVIEWED_IMPORT_ACTIVATION',
                    )['decision_reason']
                    as String,
              )
              as Map;
      expect(receipt['clinical_approval'], isFalse);
      expect(receipt['original_hold_released'], isFalse);
      expect(receipt['confirmed_state_sha256'], preview.stateSha256);
      await expectLater(activate(held.cdss, preview), throwsStateError);
      await expectLater(
        held.release.publishSnapshot(
          snapshotId: preview.heldSnapshotId,
          overrideReason: 'test',
        ),
        throwsStateError,
      );
    },
  );

  for (final mutation in [
    'catalogue',
    'source',
    'decision',
    'ticket',
    'active_snapshot',
  ]) {
    test(
      'an intervening $mutation mutation invalidates the whole preview without activation',
      () async {
        final held = await heldCandidate(bundle: activationBundle());
        final decision = await review(held);
        final preview = await held.cdss.previewReviewedImport(
          heldSnapshotId: '${held.audit['snapshot_id']}',
          decisionIds: [decision.auditId],
        );
        if (mutation == 'catalogue') {
          await held.database.insertFoodConcept(
            const FoodConceptRecord(
              foodConceptId: 'later',
              canonicalNameEn: 'Later',
              canonicalNameZh: '后',
              foodGroup: 'other',
            ),
          );
        } else if (mutation == 'source') {
          await held.database.insertSourceDocument(
            activationBundle().sourceDocuments.single,
          );
        } else if (mutation == 'decision') {
          await held.database.insertStagingRow('conflict_audit_log', {
            'audit_id': decision.auditId,
            'decision_reason': '{}',
          });
        } else if (mutation == 'ticket') {
          await held.release.updateReviewTicketStatus(
            ticketId: held.ticketId,
            status: 'resolved',
          );
        } else {
          await held.database.insertEngineSnapshot(
            EngineSnapshotRecord(
              snapshotId: 'later',
              factsVersion: 'later',
              rulesVersion: 'later',
              createdAt: DateTime.fromMillisecondsSinceEpoch(100),
              promotedAt: DateTime.now(),
              rollbackParent: null,
              inputHash: 'later',
            ),
          );
        }
        final prefs = await SharedPreferences.getInstance();
        final changed = prefs.getString(WebCdssDatabase.stateKey);
        await expectLater(activate(held.cdss, preview), throwsStateError);
        await prefs.reload();
        expect(prefs.getString(WebCdssDatabase.stateKey), changed);
        expect(await held.database.queryTable('resolved_fact'), isEmpty);
      },
    );
  }

  test(
    'receipt failure after all catalogue and marker writes rolls back every byte',
    () async {
      final db = ReceiptFailureDatabase();
      final cdss = serviceFor(db);
      final h = await prepareOn(db, cdss);
      final preview = await cdss.previewReviewedImport(
        heldSnapshotId: h.snapshotId,
        decisionIds: [h.decisionId],
      );
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(WebCdssDatabase.stateKey);
      db.rejectReceipt = true;
      await expectLater(activate(cdss, preview), throwsStateError);
      await prefs.reload();
      expect(prefs.getString(WebCdssDatabase.stateKey), before);
      expect(
        await serviceFor(WebCdssDatabase()).latestPromotedSnapshot(),
        isNull,
      );
      db.rejectReceipt = false;
      expect(
        (await activate(cdss, preview)).promotedSnapshotId,
        startsWith('promoted_'),
      );
    },
  );

  test(
    'a rejected complete activation commit preserves the original held packet',
    () async {
      var reject = false;
      final db = WebCdssDatabase(
        stateWriter: (prefs, key, value) async =>
            reject ? false : prefs.setString(key, value),
      );
      final cdss = serviceFor(db);
      final h = await prepareOn(db, cdss);
      final preview = await cdss.previewReviewedImport(
        heldSnapshotId: h.snapshotId,
        decisionIds: [h.decisionId],
      );
      final prefs = await SharedPreferences.getInstance();
      final before = prefs.getString(WebCdssDatabase.stateKey);
      reject = true;
      await expectLater(activate(cdss, preview), throwsStateError);
      await prefs.reload();
      expect(prefs.getString(WebCdssDatabase.stateKey), before);
      expect(
        (await cdss.loadHeldImportReviewEvidence(
          snapshotId: h.snapshotId,
        ))['input_sha256'],
        preview.evidenceSha256,
      );
    },
  );

  test(
    'simultaneous confirmations serialize into one complete activation',
    () async {
      final db = WebCdssDatabase();
      final cdss = serviceFor(db);
      final held = await prepareOn(db, cdss);
      final preview = await cdss.previewReviewedImport(
        heldSnapshotId: held.snapshotId,
        decisionIds: [held.decisionId],
      );
      final results = await Future.wait([
        for (var i = 0; i < 2; i++)
          activate(
            cdss,
            preview,
          ).then<Object>((r) => r, onError: (Object e) => e),
      ]);
      expect(results.whereType<CdssImportReport>(), hasLength(1));
      expect(results.whereType<StateError>(), hasLength(1));
      expect(
        (await db.queryTable(
          'conflict_audit_log',
        )).where((r) => r['audit_type'] == 'REVIEWED_IMPORT_ACTIVATION'),
        hasLength(1),
      );
      expect(
        (await db.queryTable(
          'engine_snapshot',
        )).where((r) => r['promoted_at'] != null),
        hasLength(1),
      );
    },
  );

  for (final action in ['defer', 'request_corrected_evidence']) {
    test('$action remains held and cannot manufacture activation', () async {
      final held = await heldCandidate(bundle: activationBundle());
      final decision = await review(held, action: action, observation: null);
      await expectLater(
        held.cdss.previewReviewedImport(
          heldSnapshotId: '${held.audit['snapshot_id']}',
          decisionIds: [decision.auditId],
        ),
        throwsStateError,
      );
      expect(await held.cdss.latestPromotedSnapshot(), isNull);
    });
  }

  test(
    'empty, repeated and ambiguous multiple choices do not resolve a conflict',
    () async {
      final held = await heldCandidate(bundle: activationBundle());
      final a = await review(held);
      final b = await review(held, observation: 'a');
      for (final ids in <List<String>>[
        [],
        [a.auditId, a.auditId],
        [a.auditId, b.auditId],
      ]) {
        await expectLater(
          held.cdss.previewReviewedImport(
            heldSnapshotId: '${held.audit['snapshot_id']}',
            decisionIds: ids,
          ),
          throwsStateError,
        );
      }
    },
  );

  for (final sourceCase in ['retired', 'future']) {
    test(
      '$sourceCase source content cannot acquire activation by a numeric choice',
      () async {
        final held = await heldCandidate(
          bundle: activationBundle(
            status: sourceCase == 'retired' ? 'retired' : 'active',
            publishedAt: sourceCase == 'future' ? DateTime.utc(2099) : null,
          ),
        );
        final decision = await review(held);
        await expectLater(
          held.cdss.previewReviewedImport(
            heldSnapshotId: '${held.audit['snapshot_id']}',
            decisionIds: [decision.auditId],
          ),
          throwsStateError,
        );
      },
    );
  }

  for (final missing in ['alternative_source', 'concept']) {
    test(
      'a missing $missing reference cannot acquire activation through another valid choice',
      () async {
        final held = await heldCandidate(
          bundle: activationBundle(
            missingAlternativeSource: missing == 'alternative_source',
            danglingConcept: missing == 'concept',
          ),
        );
        final decision = await review(held);
        await expectLater(
          held.cdss.previewReviewedImport(
            heldSnapshotId: '${held.audit['snapshot_id']}',
            decisionIds: [decision.auditId],
          ),
          throwsStateError,
        );
        expect(await held.cdss.latestPromotedSnapshot(), isNull);
      },
    );
  }

  test(
    'original source checksum and quantity tampering cannot create a preview',
    () async {
      final held = await heldCandidate();
      final decision = await review(held);
      await expectLater(
        held.cdss.previewReviewedImport(
          heldSnapshotId: '${held.audit['snapshot_id']}',
          decisionIds: [decision.auditId],
        ),
        throwsStateError,
      );
    },
  );

  test(
    'a held identity collision still requires corrected source evidence',
    () async {
      final held = await heldCandidate(
        bundle: P0ImportBundle(
          resolvedFacts: [
            resolvedFactFromObservation(
              observation: evidence('missing', '1'),
              policyId: 'original',
              snapshotId: 'original',
            ),
          ],
        ),
      );
      final decision = await review(
        held,
        action: 'request_corrected_evidence',
        observation: null,
      );
      await expectLater(
        held.cdss.previewReviewedImport(
          heldSnapshotId: '${held.audit['snapshot_id']}',
          decisionIds: [decision.auditId],
        ),
        throwsStateError,
      );
    },
  );
}
