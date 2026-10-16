import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_ingestion_orchestrator.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';
import 'package:parkinsum_companion/domain/usecases/fact_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/runtime_rule_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'an actual local import stops at conflict review without immediate retry or activation',
    () async {
      final bytes = utf8.encode(
        jsonEncode([
          {
            'fdcId': 90000001,
            'description': 'Synthetic conflicting evidence',
            'foodNutrients': [
              for (final amount in [1, 10])
                {
                  'nutrient': {
                    'id': 1003,
                    'number': '203',
                    'name': 'Protein',
                    'unitName': 'G',
                  },
                  'amount': amount,
                },
            ],
          },
        ]),
      );
      final archive = Archive()
        ..addFile(ArchiveFile('synthetic.json', bytes.length, bytes));
      final database = WebCdssDatabase();
      final service = ClinicalDecisionSupportService(
        database: database,
        factConflictEngine: FactConflictEngine(),
        runtimeRuleEngine: RuntimeRuleEngine(),
      );
      final orchestrator = P0IngestionOrchestrator(
        cdssService: service,
        fetchClient: const FakeSourceFetchClient(textByUrl: {}),
      );
      final reports = await orchestrator.importOfflinePackagesDetailed(
        fdcZipBytes: ZipEncoder().encode(archive),
      );
      final report = reports.single;
      expect(report.succeeded, isFalse);
      expect(report.attempts, 1);
      expect(report.checkpoint, P0IngestionCheckpoint.conflictReviewRequired);
      expect(report.bundle!.observations, hasLength(2));
      expect(report.resumeToken, isNotNull);
      expect(await service.latestPromotedSnapshot(), isNull);
      expect(await database.queryTable('food_variant'), isEmpty);
      expect(await database.queryTable('observation'), isEmpty);
      expect(await database.queryTable('staging_observation'), hasLength(2));
      final resumed = await orchestrator.resumeImportTask(report.resumeToken!);
      expect(resumed.succeeded, isFalse);
      expect(resumed.checkpoint, P0IngestionCheckpoint.conflictReviewRequired);
      expect(resumed.attempts, 1);
      expect(await service.latestPromotedSnapshot(), isNull);
    },
  );
}
