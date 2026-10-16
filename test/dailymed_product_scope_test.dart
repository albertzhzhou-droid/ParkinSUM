import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/data/datasources/remote/dailymed_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/data/datasources/remote/p0_import_models.dart';
import 'package:parkinsum_companion/domain/usecases/cdss_catalog_projection_service.dart';

const importer = DailyMedP0Importer(
  fetchClient: FakeSourceFetchClient(textByUrl: {}),
);
Map payload(P0ImportBundle bundle) =>
    jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
String product(
  String code,
  String name,
  String route,
  String ingredient,
  String amount, {
  String section = '',
}) =>
    '''
<subject><manufacturedProduct><manufacturedProduct>
<code code="$code" codeSystem="2.16.840.1.113883.6.69"/><name>$name</name><formCode displayName="TABLET"/>
<ingredient classCode="ACTIB"><quantity><numerator value="$amount" unit="mg"/><denominator value="1" unit="1"/></quantity><ingredientSubstance><name>$ingredient</name></ingredientSubstance></ingredient>
</manufacturedProduct><consumedIn><substanceAdministration><routeCode displayName="$route"/></substanceAdministration></consumedIn>
$section</manufacturedProduct></subject>''';
String spl(String products, {String shared = ''}) =>
    '''<document xmlns="urn:hl7-org:v3"><id root="synthetic-doc"/><setId root="synthetic-set"/><versionNumber value="7"/><title>Synthetic product scoping</title>
<component><structuredBody><component><section><code code="48780-1" codeSystem="2.16.840.1.113883.6.1"/>$products</section></component>$shared</structuredBody></component></document>''';
String section(String text) =>
    '<component><section><code code="34073-7"/><title>Drug interactions</title><text>$text</text></section></component>';

class _Database implements CdssDatabase {
  _Database(P0ImportBundle bundle)
    : tables = {
        'drug_product_variant': [
          for (final v in bundle.drugProductVariants)
            {
              'drug_product_variant_id': v.drugProductVariantId,
              'external_product_code': v.externalProductCode,
              'jurisdiction': v.jurisdiction,
              'regulator': v.regulator,
            },
        ],
        'source_document': [
          for (final v in bundle.sourceDocuments)
            {
              'source_doc_id': v.sourceDocId,
              'raw_payload': v.rawPayload,
              'origin_url': v.originUrl,
              'title': v.title,
            },
        ],
        'drug_label_section': [
          for (final v in bundle.drugLabelSections)
            {
              'drug_product_variant_id': v.drugProductVariantId,
              'source_doc_id': v.sourceDocId,
              'section_key': v.sectionKey,
              'section_title': v.sectionTitle,
              'section_text': v.sectionText,
            },
        ],
        'drug_product_packaging': [
          for (final v in bundle.drugProductPackagings)
            {
              'drug_product_variant_id': v.drugProductVariantId,
              'description': v.description,
            },
        ],
        'drug_product_media': [
          for (final v in bundle.drugProductMedias)
            {
              'drug_product_variant_id': v.drugProductVariantId,
              'media_url': v.mediaUrl,
            },
        ],
      };
  final Map<String, List<Map<String, Object?>>> tables;
  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      tables[table] ?? [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'a declared product section with a foreign code system cannot use the legacy path',
    () {
      final malformed =
          spl(
            product('12345-111', 'A', 'ORAL', 'LEVODOPA', '100'),
          ).replaceFirst(
            'code="48780-1" codeSystem="2.16.840.1.113883.6.1"',
            'code="48780-1" codeSystem="synthetic-foreign"',
          );
      final bundle = importer.importSplXml(malformed);
      expect(bundle.projectedDrugs, isEmpty);
      expect(bundle.drugProductVariants, isEmpty);
      expect(payload(bundle)['identity_status'], 'hold_no_resolved_products');
    },
  );
  test(
    'multiple structured products without the governed section cannot collapse into one drug',
    () {
      final malformed =
          spl(
            product('12345-111', 'A', 'ORAL', 'LEVODOPA', '100') +
                product('12345-222', 'B', 'INTRAVENOUS', 'OTHER', '2'),
          ).replaceFirst(
            '<code code="48780-1" codeSystem="2.16.840.1.113883.6.1"/>',
            '',
          );
      final bundle = importer.importSplXml(malformed);
      expect(bundle.projectedDrugs, isEmpty);
      expect(bundle.drugProductVariants, isEmpty);
      expect(payload(bundle)['identity_status'], 'hold_no_resolved_products');
    },
  );
  test(
    'missing route and ingredient identity never borrow another product or document title',
    () {
      final missingRoute = product(
        '12345-111',
        'A',
        'ORAL',
        'LEVODOPA',
        '100',
      ).replaceFirst('<routeCode displayName="ORAL"/>', '');
      final missingIngredient = product(
        '12345-222',
        'B',
        'INTRAVENOUS',
        'OTHER',
        '2',
      ).replaceFirst('<name>OTHER</name>', '<name/>');
      final bundle = importer.importSplXml(
        spl(missingRoute + missingIngredient),
      );
      expect(bundle.projectedDrugs.first.route, 'unspecified');
      expect(bundle.projectedDrugs.last.route, 'unspecified');
      expect(bundle.projectedDrugs.last.tags, isEmpty);
      final scopes = payload(bundle)['product_scopes'] as Map;
      expect(
        (scopes.values.last as Map)['hold_reasons'],
        contains('active_ingredient_identity_missing'),
      );
    },
  );
  test(
    'unknown product-scope schema never falls back to document-wide facts or strengths',
    () async {
      final bundle = importer.importSplXml(
        spl(
          product(
            '12345-111',
            'A',
            'ORAL',
            'LEVODOPA',
            '100',
            section: section('High protein meals may affect absorption.'),
          ),
        ),
      );
      final db = _Database(bundle);
      final row = db.tables['source_document']!.single;
      final raw = jsonDecode(row['raw_payload'] as String) as Map;
      raw['product_scope_schema'] = 'spl-product-scope/999';
      raw['active_ingredient_details'] = [
        {'name': 'UNRELATED'},
      ];
      raw['label_facts'] = [
        {'fact_type': 'wrong_document_fact'},
      ];
      row['raw_payload'] = jsonEncode(raw);
      final detail = (await CdssCatalogProjectionService(
        database: db,
      ).projectDrugDetail(bundle.projectedDrugs.single))!;
      expect(detail.sourceDocuments.single.activeIngredientDetails, isEmpty);
      expect(
        detail.sourceDocuments.single.productScopeStatus,
        'hold_product_identity',
      );
      expect(detail.labelFacts, isEmpty);
      expect(
        detail.sections.single.applicabilityScope,
        'hold_product_identity',
      );
    },
  );
  final oracle =
      jsonDecode(
            File(
              'test/fixtures/spl_product_scope/independent_expectations.json',
            ).readAsStringSync(),
          )
          as Map;
  for (final c in oracle['cases'] as List) {
    test(
      '${c['label']}: four independent source products and exact strength ratios',
      () async {
        final raw = File(c['fixture_path'] as String).readAsStringSync();
        expect(
          sha256.convert(utf8.encode(raw)).toString(),
          c['fixture_excerpt_sha256'],
        );
        expect(c['fixture_excerpt_sha256'], isNot(c['full_response_sha256']));
        final bundle = importer.importSplXml(raw);
        expect(bundle.sourceDocuments, hasLength(1));
        expect(bundle.drugProductVariants, hasLength(4));
        expect(bundle.projectedDrugs, hasLength(4));
        expect(payload(bundle)['spl_xml_sha256'], c['fixture_excerpt_sha256']);
        expect(payload(bundle)['active_ingredient_details'], isEmpty);
        final projection = CdssCatalogProjectionService(
          database: _Database(bundle),
        );
        for (final expected in c['expected_products'] as List) {
          final variant = bundle.drugProductVariants.singleWhere(
            (v) => v.externalProductCode == expected['product_ndc'],
          );
          expect(variant.route, expected['route']);
          expect(variant.dosageForm, expected['form']);
          final drug = bundle.projectedDrugs.singleWhere(
            (v) => v.sourceProductCode == expected['product_ndc'],
          );
          final detail = (await projection.projectDrugDetail(drug))!;
          // No narrative sections exist: source evidence must still be discoverable.
          final source = detail.sourceDocuments.single;
          expect(source.productScopeStatus, 'resolved_product_scope');
          expect(source.activeIngredientDetails, hasLength(2));
          expect(detail.labelFacts, isEmpty);
          for (final strength in expected['strengths'] as List) {
            final actual = source.activeIngredientDetails.singleWhere(
              (v) => v['name'] == strength['name'],
            );
            expect(actual['numerator_value'], strength['numerator']);
            expect(actual['numerator_unit'], strength['unit']);
            expect(actual['denominator_value'], strength['denominator']);
            expect(actual['denominator_unit'], strength['denominator_unit']);
            expect(actual['promotion_status'], 'source_strength_evidence_only');
          }
          expect(drug.toJson().containsKey('administeredDose'), isFalse);
        }
      },
    );
  }
  test(
    'mixed routes, ingredients and same-title sections never cross products; shared facts stay unassigned',
    () async {
      final a = product(
        '12345-111',
        'A',
        'ORAL',
        'LEVODOPA',
        '100',
        section: section('High protein meals may affect absorption.'),
      );
      final b = product(
        '12345-222',
        'B',
        'INTRAVENOUS',
        'OTHER',
        '2',
        section: section('Iron salts may interfere with absorption.'),
      );
      final raw = spl(
        '$a$b',
        shared: section(
          'Take at least 1 hour before and at least 2 hours after meals.',
        ),
      );
      final bundle = importer.importSplXml(raw);
      final db = _Database(bundle);
      final service = CdssCatalogProjectionService(database: db);
      final first = (await service.projectDrugDetail(
        bundle.projectedDrugs[0],
      ))!;
      final second = (await service.projectDrugDetail(
        bundle.projectedDrugs[1],
      ))!;
      expect(bundle.projectedDrugs[0].route, 'ORAL');
      expect(bundle.projectedDrugs[1].route, 'INTRAVENOUS');
      expect(
        first.sourceDocuments.single.activeIngredientDetails.single['name'],
        'LEVODOPA',
      );
      expect(
        second.sourceDocuments.single.activeIngredientDetails.single['name'],
        'OTHER',
      );
      expect(
        first.sections.any((s) => s.sectionText.contains('Iron salts')),
        isFalse,
      );
      expect(
        second.sections.any((s) => s.sectionText.contains('High protein')),
        isFalse,
      );
      expect(
        first.sections.map((s) => s.applicabilityScope),
        containsAll(['product_explicit', 'document_shared_unverified']),
      );
      expect(
        first.labelFacts.map((f) => f.factType),
        contains('high_protein_effect'),
      );
      expect(
        second.labelFacts.map((f) => f.factType),
        contains('iron_interaction_warning'),
      );
      expect(
        [
          ...first.labelFacts,
          ...second.labelFacts,
        ].any((f) => f.factType == 'meal_window_before_after'),
        isFalse,
      );
      expect(
        (payload(bundle)['document_shared_label_facts'] as List).any(
          (f) => f['fact_type'] == 'meal_window_before_after',
        ),
        isTrue,
      );
      final reversed = importer.importSplXml(spl('$b$a'));
      expect(
        reversed.drugProductVariants.map((v) => v.drugProductVariantId).toSet(),
        bundle.drugProductVariants.map((v) => v.drugProductVariantId).toSet(),
      );
      expect(
        bundle.drugLabelSections.map((s) => s.sectionId).toSet().length,
        bundle.drugLabelSections.length,
      );
    },
  );
  test(
    'external packaging/media are attached only by an exact product identifier',
    () {
      final bundle = importer.importSplXml(
        spl(
          product('12345-111', 'A', 'ORAL', 'LEVODOPA', '100') +
              product('12345-222', 'B', 'ORAL', 'OTHER', '2'),
        ),
        packaging: [
          {'package_ndc': '12345-111-01', 'description': 'A only'},
          {'description': 'Unscoped'},
        ],
        media: [
          {'product_ndc': '12345-222', 'url': 'https://example.test/b'},
          {'url': 'https://example.test/shared'},
        ],
      );
      expect(
        bundle.drugProductPackagings.single.drugProductVariantId,
        bundle.drugProductVariants.first.drugProductVariantId,
      );
      expect(
        bundle.drugProductMedias.single.drugProductVariantId,
        bundle.drugProductVariants.last.drugProductVariantId,
      );
      final unassigned = payload(bundle)['unassigned_external_metadata'] as Map;
      expect(unassigned['packaging'], hasLength(1));
      expect(unassigned['media'], hasLength(1));
    },
  );
  test(
    'missing or duplicate product codes withhold applicability rather than choosing a first product',
    () {
      for (final content in [
        product('bad', 'A', 'ORAL', 'LEVODOPA', '100'),
        product('12345-111', 'A', 'ORAL', 'LEVODOPA', '100') +
            product('12345-111', 'B', 'INTRAVENOUS', 'OTHER', '2'),
      ]) {
        final bundle = importer.importSplXml(spl(content));
        expect(
          bundle.drugProductVariants.every(
            (v) =>
                v.sourceStatus == 'hold_product_identity' &&
                v.route == 'unspecified' &&
                v.dosageForm == 'unspecified',
          ),
          isTrue,
        );
        expect(
          bundle.drugProductVariants
              .map((v) => v.drugProductVariantId)
              .toSet()
              .length,
          bundle.drugProductVariants.length,
        );
        expect(bundle.drugProductCodes, isEmpty);
      }
      expect(importer.importSplXml(spl('')).projectedDrugs, isEmpty);
    },
  );
  test(
    'same jurisdiction/code from another regulator is excluded from drug detail',
    () async {
      final bundle = importer.importSplXml(
        spl(product('12345-111', 'A', 'ORAL', 'LEVODOPA', '100')),
      );
      final db = _Database(bundle);
      db.tables['drug_product_variant']!.add({
        'drug_product_variant_id': 'foreign',
        'external_product_code': '12345-111',
        'jurisdiction': 'US',
        'regulator': 'OTHER',
      });
      final detail = (await CdssCatalogProjectionService(
        database: db,
      ).projectDrugDetail(bundle.projectedDrugs.single))!;
      expect(
        detail.variantIds,
        bundle.drugProductVariants.map((v) => v.drugProductVariantId).toList(),
      );
    },
  );
}
