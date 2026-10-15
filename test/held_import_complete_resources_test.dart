import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:parkinsum_companion/core/db/cdss_database_web.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/usecases/clinical_decision_support_service.dart';

import 'held_import_review_evidence_test.dart'
    show serviceFor, conflictingBundle, FailingArtifactStore;

P0ImportBundle completeHeldBundle() => conflictingBundle().merge(
  const P0ImportBundle(
    countryDietProfiles: [
      CountryDietProfileRecord(
        countryCode: 'US',
        guidelineSource: 'original',
        mealPatternJson: '{"source":"pattern"}',
        stapleFoodsJson: '["rice"]',
        preferredProteinSourcesJson: '["beans"]',
        avoidanceNotesJson: '[]',
      ),
    ],
    foodConcepts: [
      FoodConceptRecord(
        foodConceptId: 'food',
        canonicalNameEn: 'Original food',
        canonicalNameZh: '原始食物',
        foodGroup: 'other',
      ),
    ],
    drugConcepts: [
      DrugConceptRecord(
        drugConceptId: 'drug',
        genericName: 'Original drug',
        atcLikeCode: 'source-code',
      ),
    ],
    drugLabelSections: [
      DrugLabelSectionRecord(
        sectionId: 'section',
        drugProductVariantId: 'drug-v',
        sourceDocId: 'source',
        sectionKey: 'original-key',
        sectionTitle: '原始标题',
        sectionText: 'Unchanged source text',
      ),
    ],
    drugProductCodes: [
      DrugProductCodeRecord(
        productCodeId: 'code',
        drugProductVariantId: 'drug-v',
        sourceDocId: 'source',
        codeSystem: 'source-system',
        codeValue: '123',
        displayText: null,
      ),
    ],
    drugProductPackagings: [
      DrugProductPackagingRecord(
        packagingId: 'pack',
        drugProductVariantId: 'drug-v',
        sourceDocId: 'source',
        packageCode: 'package-code',
        description: 'Original package',
        marketingStatus: 'original-status',
      ),
    ],
    drugProductMedias: [
      DrugProductMediaRecord(
        mediaId: 'media',
        drugProductVariantId: 'drug-v',
        sourceDocId: 'source',
        mediaType: 'pdf',
        mediaUrl: 'https://example.invalid/original.pdf',
        caption: null,
      ),
    ],
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
    'retained label content is bound to the original packet digest',
    () async {
      final database = WebCdssDatabase();
      await expectLater(
        serviceFor(database).importBundle(completeHeldBundle()),
        throwsA(isA<CdssImportHeldException>()),
      );
      final run = (await database.queryTable(
        'ingestion_run',
      )).singleWhere((row) => row['status'] == 'held_for_conflict_review');
      final notes = jsonDecode(run['notes_json'] as String) as Map;
      final packet = notes['review_evidence'] as Map;
      final rows = (packet['payload'] as Map)['retained_catalog_rows'] as Map;
      ((rows['drug_label_section'] as List).single as Map)['section_text'] =
          'Changed';
      await database.insertStagingRow('ingestion_run', {
        ...run,
        'notes_json': jsonEncode(notes),
      });
      await expectLater(
        serviceFor(
          WebCdssDatabase(),
        ).loadHeldImportReviewEvidence(snapshotId: '${run['snapshot_id']}'),
        throwsStateError,
      );
      expect(await database.queryTable('drug_label_section'), isEmpty);
    },
  );
  for (final sidecarFailure in [false, true]) {
    test(
      'held resources recover from fresh backend; sidecarFailure=$sidecarFailure',
      () async {
        final database = WebCdssDatabase();
        await expectLater(
          serviceFor(
            database,
            artifactStore: sidecarFailure ? FailingArtifactStore() : null,
          ).importBundle(completeHeldBundle()),
          throwsA(isA<CdssImportHeldException>()),
        );
        final run = (await database.queryTable(
          'ingestion_run',
        )).singleWhere((row) => row['status'] == 'held_for_conflict_review');
        final packet = await serviceFor(
          WebCdssDatabase(),
        ).loadHeldImportReviewEvidence(snapshotId: '${run['snapshot_id']}');
        final payload = packet['payload'] as Map;
        final rows = payload['retained_catalog_rows'] as Map;
        expect((rows['food_concept'] as List).single, {
          'food_concept_id': 'food',
          'canonical_name_en': 'Original food',
          'canonical_name_zh': '原始食物',
          'food_group': 'other',
        });
        expect((rows['drug_label_section'] as List).single, {
          'section_id': 'section',
          'drug_product_variant_id': 'drug-v',
          'source_doc_id': 'source',
          'section_key': 'original-key',
          'section_title': '原始标题',
          'section_text': 'Unchanged source text',
        });
        expect((rows['drug_product_code'] as List).single['code_value'], '123');
        expect(
          (rows['drug_product_packaging'] as List).single['description'],
          'Original package',
        );
        expect((rows['drug_product_media'] as List).single['caption'], isNull);
        expect(
          (rows['country_diet_profile'] as List).single['meal_pattern_json'],
          '{"source":"pattern"}',
        );
        expect(
          (rows['drug_concept'] as List).single['atc_like_code'],
          'source-code',
        );
        expect(rows['projected_foods'], isEmpty);
        expect(rows['projected_drugs'], isEmpty);
        for (final table in rows.keys.where(
          (key) => !'$key'.startsWith('projected_'),
        )) {
          expect(await database.queryTable('$table'), isEmpty);
        }
        expect(await serviceFor(database).latestPromotedSnapshot(), isNull);
      },
    );
  }
}
