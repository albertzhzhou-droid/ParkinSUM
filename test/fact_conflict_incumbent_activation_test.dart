import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';

import 'fact_conflict_complete_cluster_test.dart' show evidence;

ResolvedFactRecord incumbent(
  ObservationRecord observation, {
  bool manual = false,
}) => ResolvedFactRecord(
  factId: 'fact-${observation.observationId}',
  entityKey: observation.entityKey,
  attributeCode: observation.attributeCode,
  scopeHash: observation.scopeHash,
  resolutionStatus: 'resolved',
  chosenObservationId: observation.observationId,
  resolvedValue: observation.value,
  resolvedUnit: observation.unit,
  resolutionPolicyId: 'source-evidence',
  snapshotId: 'historical-snapshot',
  factVersion: 'historical-snapshot',
  manualOverride: manual,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final engine = FactConflictEngine();

  test(
    'a dangling candidate fact cannot be activated without its observation',
    () async {
      final database = WebCdssDatabase();
      final service = ClinicalDecisionSupportService(
        database: database,
        factConflictEngine: engine,
        runtimeRuleEngine: RuntimeRuleEngine(),
      );
      await expectLater(
        service.importBundle(
          P0ImportBundle(resolvedFacts: [incumbent(evidence('missing', '10'))]),
        ),
        throwsA(isA<CdssImportHeldException>()),
      );
      expect(await database.queryTable('resolved_fact'), isEmpty);
      expect(await service.latestPromotedSnapshot(), isNull);
      expect(
        (await database.queryTable('conflict_audit_log')).single['decision'],
        'candidate_fact_evidence_mismatch',
      );
    },
  );

  test(
    'changed scope dimensions cannot overwrite an existing scope hash',
    () async {
      final database = WebCdssDatabase();
      final service = ClinicalDecisionSupportService(
        database: database,
        factConflictEngine: engine,
        runtimeRuleEngine: RuntimeRuleEngine(),
      );
      await service.importBundle(
        const P0ImportBundle(
          variantScopes: [
            VariantScopeRecord(
              scopeHash: 'same',
              jurisdiction: 'US',
              brand: null,
              dosageForm: null,
              releaseType: null,
              saltForm: null,
              route: null,
              cookingState: null,
              plantPart: null,
              cultivar: null,
              samplingFrame: null,
              preparationState: 'raw',
            ),
          ],
        ),
      );
      final before = await database.queryTable('variant_scope');
      await expectLater(
        service.importBundle(
          const P0ImportBundle(
            variantScopes: [
              VariantScopeRecord(
                scopeHash: 'same',
                jurisdiction: 'US',
                brand: null,
                dosageForm: null,
                releaseType: null,
                saltForm: null,
                route: null,
                cookingState: null,
                plantPart: null,
                cultivar: null,
                samplingFrame: null,
                preparationState: 'cooked',
              ),
            ],
          ),
        ),
        throwsA(isA<CdssImportHeldException>()),
      );
      expect(await database.queryTable('variant_scope'), before);
      expect(
        (await database.queryTable('conflict_audit_log')).single['decision'],
        'scope_identity_collision',
      );
    },
  );

  test('the same unit with a different historical basis is withheld', () {
    final old = evidence('old', '1', basisType: 'per_serving', basisAmount: 30);
    final result = engine.resolveCluster(
      observations: [evidence('new', '10')],
      existingFacts: [incumbent(old)],
      existingObservationsById: {'old': old},
      sourceDocumentsById: {},
    );
    expect(result.status, 'incompatible_cluster');
    expect(result.needsManualReview, isTrue);
  });

  test(
    'an incumbent manual choice cannot be replaced by an overlapping automatic fact',
    () {
      final old = evidence('z-manual', '1');
      final result = engine.resolveCluster(
        observations: [evidence('a-new', '1')],
        existingFacts: [incumbent(old, manual: true)],
        existingObservationsById: {'z-manual': old},
        sourceDocumentsById: {},
      );
      expect(result.chosenObservation!.observationId, 'z-manual');
      expect(
        result.acceptedRationale['incumbent_manual_choice_retained'],
        isTrue,
      );
      expect(result.status, 'review_required');
      expect(result.comparisonEdges.single['relation'], 'overlapping_evidence');
    },
  );

  test('blank measurement method is never marked as verified identity', () {
    final result = engine.resolveCluster(
      observations: [
        evidence('a', '1', method: ''),
        evidence('b', '1', method: ''),
      ],
      existingFacts: [],
      sourceDocumentsById: {},
    );
    expect(
      (result.comparisonEdges.single['scope_match_details']
          as Map)['measurement_method_identity_verified'],
      isFalse,
    );
    expect(result.comparisonEdges.single['proven_source_duplicate'], isFalse);
  });

  test('original incumbent participates in the complete comparison graph', () {
    final old = evidence('old', '1');
    final result = engine.resolveCluster(
      observations: [evidence('new', '10')],
      existingFacts: [incumbent(old)],
      existingObservationsById: {'old': old},
      sourceDocumentsById: {},
    );
    expect(result.status, 'review_required');
    expect(result.comparisonEdges.single['relation'], 'contradiction');
    expect(result.comparisonEdges.single['right_observation_id'], 'old');
  });

  test('historical method and basis are recovered rather than guessed', () {
    final old = evidence('old', '1', method: 'imputed');
    final result = engine.resolveCluster(
      observations: [evidence('new', '10')],
      existingFacts: [incumbent(old)],
      existingObservationsById: {'old': old},
      sourceDocumentsById: {},
    );
    expect(result.needsManualReview, isFalse);
    expect(result.comparisonEdges.single['relation'], 'coexisting_method');
  });

  test(
    'a changed payload cannot reuse the historical observation identity',
    () {
      final old = evidence('same-id', '1');
      final result = engine.resolveCluster(
        observations: [evidence('same-id', '10')],
        existingFacts: [incumbent(old)],
        existingObservationsById: {'same-id': old},
        sourceDocumentsById: {},
      );
      expect(result.status, 'historical_evidence_required');
      expect(
        result.rejectedRationales.single['rationale'],
        'historical_observation_identity_collision',
      );
    },
  );

  test(
    'two imports compare stored original evidence and retain the old activation',
    () async {
      final database = WebCdssDatabase();
      final service = ClinicalDecisionSupportService(
        database: database,
        factConflictEngine: engine,
        runtimeRuleEngine: RuntimeRuleEngine(),
      );
      final old = evidence('old', '1', source: 'previous');
      final first = await service.importBundle(
        P0ImportBundle(observations: [old], resolvedFacts: [incumbent(old)]),
      );
      final beforeFacts = await database.queryTable('resolved_fact');
      await expectLater(
        service.importBundle(
          P0ImportBundle(
            observations: [evidence('new', '10', source: 'incoming')],
            resolvedFacts: [
              incumbent(evidence('new', '10', source: 'incoming')),
            ],
          ),
        ),
        throwsA(isA<CdssImportHeldException>()),
      );
      final freshService = ClinicalDecisionSupportService(
        database: WebCdssDatabase(),
        factConflictEngine: engine,
        runtimeRuleEngine: RuntimeRuleEngine(),
      );
      expect(
        (await freshService.latestPromotedSnapshot())!.snapshotId,
        first.promotedSnapshotId,
      );
      expect(await database.queryTable('resolved_fact'), beforeFacts);
      expect(
        (await database.queryTable('observation')).single['observation_id'],
        'old',
      );
      final audit = (await database.queryTable('conflict_audit_log')).last;
      final payload = jsonDecode(audit['decision_reason'] as String) as Map;
      expect(
        (payload['comparison_edges'] as List).single['relation'],
        'contradiction',
      );
      expect(jsonDecode(audit['source_doc_refs_json'] as String), [
        'incoming',
        'previous',
      ]);
    },
  );

  test(
    'changed source content cannot overwrite the document under the same ID',
    () async {
      final database = WebCdssDatabase();
      final service = ClinicalDecisionSupportService(
        database: database,
        factConflictEngine: engine,
        runtimeRuleEngine: RuntimeRuleEngine(),
      );
      SourceDocumentRecord doc(String hash) => SourceDocumentRecord(
        sourceDocId: 'same-source',
        sourceFamily: 'synthetic',
        organization: 'test',
        jurisdiction: 'US',
        docType: 'label',
        title: 'source',
        originUrl: 'https://example.test',
        publishedAt: null,
        effectiveAt: null,
        language: 'en',
        licenseNote: 'synthetic',
        checksum: hash,
        sourceStatus: 'active',
        rawPayload: jsonEncode({'revision': hash}),
      );
      await service.importBundle(P0ImportBundle(sourceDocuments: [doc('old')]));
      final before = await database.queryTable('source_document');
      await expectLater(
        service.importBundle(P0ImportBundle(sourceDocuments: [doc('new')])),
        throwsA(isA<CdssImportHeldException>()),
      );
      expect(await database.queryTable('source_document'), before);
      expect(
        (await database.queryTable('conflict_audit_log')).single['decision'],
        'source_identity_collision',
      );
    },
  );

  test('one overlapping incumbent cannot hide another contradictory fact', () {
    final facts = [
      incumbent(evidence('old-a', '10')),
      incumbent(evidence('old-b', '1')),
    ];
    for (final ordered in [facts, facts.reversed.toList()]) {
      final result = engine.classify(
        observation: evidence('new', '10'),
        existingFacts: ordered,
      );
      expect(result.type, FactConflictType.contradiction);
      expect(result.needsManualReview, isTrue);
    }
  });

  test(
    'cluster must not silently ignore a fact with unavailable observation history',
    () {
      final result = engine.resolveCluster(
        observations: [evidence('new', '10')],
        existingFacts: [incumbent(evidence('old', '1'))],
        sourceDocumentsById: {},
      );
      expect(result.needsManualReview, isTrue);
      expect(result.status, 'historical_evidence_required');
    },
  );

  test(
    'unresolved import retains staging without creating an activation marker',
    () async {
      final database = WebCdssDatabase();
      final service = ClinicalDecisionSupportService(
        database: database,
        factConflictEngine: engine,
        runtimeRuleEngine: RuntimeRuleEngine(),
      );
      await expectLater(
        service.importBundle(
          P0ImportBundle(
            observations: [
              evidence('a', '1-10', source: 'wide'),
              evidence('b', '1-2', source: 'left'),
              evidence('c', '8-9', source: 'right'),
            ],
          ),
        ),
        throwsA(anything),
      );
      expect(await service.latestPromotedSnapshot(), isNull);
      expect(await database.queryTable('observation'), isEmpty);
      expect(await database.queryTable('staging_observation'), hasLength(3));
      final audit = (await database.queryTable('conflict_audit_log')).single;
      expect(
        (jsonDecode(audit['decision_reason'] as String)
            as Map)['comparison_edges'],
        hasLength(3),
      );
    },
  );
}
