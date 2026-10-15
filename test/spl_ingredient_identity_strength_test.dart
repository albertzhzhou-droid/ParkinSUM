import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/dailymed_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';

void main() {
  const importer = DailyMedP0Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );
  final expected =
      jsonDecode(
            File(
              'test/fixtures/spl_product_scope/ingredient_identity_strength_expectations.json',
            ).readAsStringSync(),
          )
          as Map;
  Map detail(String ingredient) {
    final bundle = importer.importSplXml(
      '''<document xmlns="urn:hl7-org:v3" xmlns:x="urn:foreign">
      <id root="synthetic"/><setId root="synthetic"/><title>Synthetic drug fields</title>
      <component><structuredBody><component><section><code code="48780-1" codeSystem="2.16.840.1.113883.6.1"/>
      <subject><manufacturedProduct><manufacturedProduct><code code="12345-678" codeSystem="2.16.840.1.113883.6.69"/>
      <name>Source identity test</name><formCode displayName="TABLET"/>$ingredient</manufacturedProduct>
      <consumedIn><substanceAdministration><routeCode displayName="ORAL"/></substanceAdministration></consumedIn>
      </manufacturedProduct></subject></section></component></structuredBody></component></document>''',
    );
    final payload = jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
    return (((payload['product_scopes'] as Map).values.single
                    as Map)['active_ingredient_details']
                as List)
            .single
        as Map;
  }

  test(
    'ACTIR strength uses the explicit reference substance with its own denominator',
    () {
      final row = detail(
        '''<ingredient classCode="ACTIR"><quantity><numerator value="125" unit="mg"/>
      <denominator value="5" unit="mL"/></quantity><ingredientSubstance><code code="INGREDIENT" codeSystem="synthetic"/>
      <name>Ingredient</name><asEquivalentSubstance><definingSubstance><code code="REFERENCE" codeSystem="synthetic"/>
      <name>Reference ingredient</name></definingSubstance></asEquivalentSubstance></ingredientSubstance></ingredient>''',
      );
      expect(row['strength_basis'], 'reference_ingredient');
      expect(
        (row['strength_basis_substances'] as List).single['substance_code'],
        'REFERENCE',
      );
      expect(row['denominator_value'], '5');
      expect(row['denominator_unit'], 'mL');
      expect(row['promotion_status'], 'source_strength_evidence_only');
      expect(row.containsKey('administered_dose_mg'), isFalse);
    },
  );

  test(
    'missing ACTIM moiety and foreign descendants cannot repair the basis',
    () {
      final row = detail(
        '''<ingredient classCode="ACTIM"><ingredientSubstance><code code="INGREDIENT" codeSystem="synthetic"/>
      <name>Ingredient</name><x:activeMoiety><x:activeMoiety><x:code code="FAKE"/><x:name>Fake</x:name>
      </x:activeMoiety></x:activeMoiety></ingredientSubstance></ingredient>''',
      );
      expect(row['active_moieties'], isEmpty);
      expect(
        row['strength_basis_resolution_status'],
        'missing_or_ambiguous_source_reference',
      );
      expect(row['numerator_value'], isNull);
    },
  );

  test(
    'multiple basis substances and numerators remain uncollapsed evidence',
    () {
      final row = detail(
        '''<ingredient classCode="ACTIM"><quantity><numerator value="1" unit="mg"/>
      <numerator value="2" unit="mg"/><denominator value="1" unit="1"/></quantity><ingredientSubstance>
      <code code="INGREDIENT" codeSystem="synthetic"/><name>Ingredient</name>
      <activeMoiety><activeMoiety><code code="ONE" codeSystem="synthetic"/><name>One</name></activeMoiety></activeMoiety>
      <activeMoiety><activeMoiety><code code="TWO" codeSystem="synthetic"/><name>Two</name></activeMoiety></activeMoiety>
      </ingredientSubstance></ingredient>''',
      );
      expect(row['active_moieties'], hasLength(2));
      expect(
        row['strength_basis_resolution_status'],
        'missing_or_ambiguous_source_reference',
      );
      expect(row['numerator_value'], isNull);
      expect(
        ((row['quantity_evidence'] as List).single as Map)['numerators'],
        hasLength(2),
      );
    },
  );
  for (final source in expected['sources'] as List) {
    for (final product in source['products'] as List) {
      test(
        'source ingredient identities and ratios for ${product['product_code']['code']}',
        () {
          final bundle = importer.importSplXml(
            File(source['fixture_path'] as String).readAsStringSync(),
          );
          final payload =
              jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
          final scopes = (payload['product_scopes'] as Map).values
              .whereType<Map>();
          final scope = scopes.singleWhere(
            (row) => row['product_code'] == product['product_code']['code'],
          );
          final rows = scope['ingredient_class_audit'] as List;
          expect(rows, hasLength((product['ingredients'] as List).length));
          for (final original in product['ingredients'] as List) {
            final row = rows[original['ingredient_ordinal'] as int] as Map;
            expect(row['class_code'], original['class_code']);
            expect(row['name'], original['ingredient_name']);
            expect(row['substance_code'], original['ingredient_code']['code']);
            expect(
              row['code_system'],
              original['ingredient_code']['codeSystem'],
            );
            expect(row['numerator_value'], original['numerator']?['value']);
            expect(row['numerator_unit'], original['numerator']?['unit']);
            expect(row['denominator_value'], original['denominator']?['value']);
            expect(row['denominator_unit'], original['denominator']?['unit']);
            expect(row['active_moieties'], [
              for (final moiety in original['active_moieties'] as List)
                {
                  'name': moiety['name'],
                  'substance_code': moiety['code']['code'],
                  'code_system': moiety['code']['codeSystem'],
                },
            ]);
            if (original['class_code'] == 'ACTIM') {
              expect(row['strength_basis'], 'active_moiety');
              expect(row['strength_basis_substances'], row['active_moieties']);
            } else if (original['class_code'] == 'ACTIB') {
              expect(row['strength_basis'], 'active_ingredient');
            } else {
              expect(
                row['strength_basis'],
                'not_an_active_ingredient_strength',
              );
            }
          }
        },
      );
    }
  }
}
