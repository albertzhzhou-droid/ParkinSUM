import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_artifact_store.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_artifact_store_stub.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

import 'fact_conflict_complete_cluster_test.dart' show evidence;

const sourceFields = <String, Object?>{
  'source_doc_id': 'source',
  'source_family': 'source-test',
  'data_tier': 'p1',
  'ingestion_strategy': 'official_reference',
  'organization': 'Source organization',
  'jurisdiction': 'US',
  'doc_type': 'source quantities',
  'title': 'Unmodified source title',
  'origin_url': 'https://example.invalid/source',
  'published_at': 1000,
  'effective_at': 2000,
  'language': 'en',
  'license_note': 'Original source terms',
  'checksum': 'source-checksum',
  'source_status': 'active',
  'raw_payload': '{"original":"source text with 中文"}',
};

SourceDocumentRecord sourceDocument() => SourceDocumentRecord(
  sourceDocId: 'source',
  sourceFamily: 'source-test',
  dataTier: 'p1',
  ingestionStrategy: 'official_reference',
  organization: 'Source organization',
  jurisdiction: 'US',
  docType: 'source quantities',
  title: 'Unmodified source title',
  originUrl: 'https://example.invalid/source',
  publishedAt: DateTime.fromMillisecondsSinceEpoch(1000),
  effectiveAt: DateTime.fromMillisecondsSinceEpoch(2000),
  language: 'en',
  licenseNote: 'Original source terms',
  checksum: 'source-checksum',
  sourceStatus: 'active',
  rawPayload: '{"original":"source text with 中文"}',
);

ClinicalDecisionSupportService serviceFor(
  WebCdssDatabase database, {
  CdssArtifactStore? artifactStore,
}) => ClinicalDecisionSupportService(
  database: database,
  factConflictEngine: FactConflictEngine(),
  runtimeRuleEngine: RuntimeRuleEngine(),
  artifactStore: artifactStore ?? InlineCdssArtifactStore(),
);

P0ImportBundle conflictingBundle() => P0ImportBundle(
  sourceDocuments: [sourceDocument()],
  observations: [evidence('a', '1'), evidence('b', '10')],
);

class FailingArtifactStore extends InlineCdssArtifactStore {
  @override
  Future<CdssArtifactWriteResult> writeArtifactSet({
    required String artifactId,
    required Map<String, String> files,
    required Map<String, dynamic> manifest,
  }) async => throw StateError('test sidecar write failure');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'held source evidence is stored on the backend with every source field',
    () async {
      final database = WebCdssDatabase();
      await expectLater(
        serviceFor(database).importBundle(conflictingBundle()),
        throwsA(isA<CdssImportHeldException>()),
      );
      final reopened = WebCdssDatabase();
      await reopened.initialize();
      final row = (await reopened.queryTable(
        'ingestion_run',
      )).singleWhere((row) => row['status'] == 'held_for_conflict_review');
      final notes = jsonDecode(row['notes_json'] as String) as Map;
      expect(notes['review_evidence'], isA<Map>());
      final packet = notes['review_evidence'] as Map;
      final payload = packet['payload'] as Map;
      expect((payload['source_documents'] as List).single, sourceFields);
      expect(await reopened.queryTable('source_document'), isEmpty);
      expect(await serviceFor(reopened).latestPromotedSnapshot(), isNull);
      expect(
        await InlineCdssArtifactStore().readArtifactSet(
          'held_import_${payload['run_id']}',
        ),
        isNull,
      );
    },
  );

  test(
    'a sidecar failure retains source evidence and the typed conflict hold',
    () async {
      final database = WebCdssDatabase();
      await expectLater(
        serviceFor(
          database,
          artifactStore: FailingArtifactStore(),
        ).importBundle(conflictingBundle()),
        throwsA(isA<CdssImportHeldException>()),
      );
      final row = (await database.queryTable(
        'ingestion_run',
      )).singleWhere((row) => row['status'] == 'held_for_conflict_review');
      final notes = jsonDecode(row['notes_json'] as String) as Map;
      expect(notes['review_evidence'], isA<Map>());
      expect(notes['artifact_warning'], 'sidecar_write_failed');
      expect(await database.queryTable('staging_observation'), hasLength(2));
      expect(await serviceFor(database).latestPromotedSnapshot(), isNull);
    },
  );
}
