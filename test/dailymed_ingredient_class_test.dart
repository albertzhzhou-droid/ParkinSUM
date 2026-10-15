import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/dailymed_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';

void main() {
  final fixture =
      jsonDecode(
            File(
              'test/fixtures/dailymed_ingredient_class_independent.json',
            ).readAsStringSync(),
          )
          as Map;
  const importer = DailyMedP0Importer(
    fetchClient: FakeSourceFetchClient(textByUrl: {}),
  );
  for (final row in (fixture['cases'] as List).cast<Map>()) {
    test('frozen SPL class evidence: ${row['id']}', () {
      final xml = row['xml'] as String;
      expect(sha256.convert(utf8.encode(xml)).toString(), row['sha256']);
      final bundle = importer.importSplXml(xml);
      final payload =
          jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      expect(payload['spl_xml_sha256'], row['sha256']);
      final scope = (payload['product_scopes'] as Map).values.single as Map;
      final eligible = scope['identity_status'] == 'resolved_product_scope';
      expect(eligible, row['expected_product_scope_eligible']);
      final details = (scope['active_ingredient_details'] as List).cast<Map>();
      expect(
        eligible ? details.map((r) => r['name']).toList() : [],
        row['expected_qualified_active_names'],
      );
      final audit = (scope['ingredient_class_audit'] as List).cast<Map>();
      expect(audit.map((r) => r['class_code']).toList(), row['class_codes']);
      expect(
        details.every(
          (r) => {'ACTIB', 'ACTIM', 'ACTIR'}.contains(r['class_code']),
        ),
        isTrue,
      );
      if (!eligible) {
        expect(
          scope['hold_reasons'],
          contains('ingredient_class_missing_or_unsupported'),
        );
        expect(bundle.projectedDrugs.single.route, 'unspecified');
        expect(bundle.projectedDrugs.single.releaseType, 'unknown');
      }
    });
  }
}
