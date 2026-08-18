import 'dart:io';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/core/services/medication_product_catalog.dart';
import 'package:parkinsum_companion/data/datasources/remote/openfda_ndc_product_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';

void main() {
  const payload = <String, dynamic>{
    'retrieved_at': '2026-08-17T00:00:00Z',
    'results': <Map<String, dynamic>>[
      <String, dynamic>{
        'finished': true,
        'product_type': 'HUMAN PRESCRIPTION DRUG',
        'product_ndc': '72865-362',
        'generic_name': 'CARBIDOPA AND LEVODOPA',
        'brand_name': 'Carbidopa and Levodopa',
        'labeler_name': 'XLCare Pharmaceuticals, Inc.',
        'dosage_form': 'TABLET',
        'route': <String>['ORAL'],
        'active_ingredients': <Map<String, dynamic>>[
          <String, dynamic>{'name': 'CARBIDOPA', 'strength': '25 mg/1'},
          <String, dynamic>{'name': 'LEVODOPA', 'strength': '100 mg/1'},
        ],
        'packaging': <Map<String, dynamic>>[
          <String, dynamic>{
            'package_ndc': '72865-362-01',
            'description': '100 TABLET in 1 BOTTLE',
            'marketing_start_date': '20200101',
          },
          <String, dynamic>{
            'package_ndc': '72865-362-10',
            'description': '1000 TABLET in 1 BOTTLE',
          },
        ],
        'openfda': <String, dynamic>{
          'rxcui': <String>['724606'],
          'spl_set_id': <String>['1234-abcd'],
          'upc': <String>['00372865362015'],
        },
      },
    ],
  };

  test('creates one selectable product per official package', () {
    const importer = OpenFdaNdcProductImporter(
      fetchClient: FakeSourceFetchClient(textByUrl: <String, String>{}),
    );
    final products = importer.importPayload(payload);

    expect(products, hasLength(2));
    expect(products.first.labelerName, 'XLCare Pharmaceuticals, Inc.');
    expect(products.first.packageDescription, '100 TABLET in 1 BOTTLE');
    expect(products.first.strengthDisplay, 'CARBIDOPA 25 mg + LEVODOPA 100 mg');
    expect(products.first.matchesIdentifier('7286536201'), isTrue);
    expect(
      MedicationProductSelection.fromPack(products.first).identifierValue,
      '72865-362-01',
    );
    expect(
      products.first.identifiers.map((item) => item.system),
      containsAll(<MedicationIdentifierSystem>[
        MedicationIdentifierSystem.ndcProduct,
        MedicationIdentifierSystem.ndcPackage,
        MedicationIdentifierSystem.rxcui,
        MedicationIdentifierSystem.dailymedSetId,
        MedicationIdentifierSystem.gtin,
      ]),
    );
  });

  test('catalog ranks an exact package identifier before text matches', () {
    final catalog = MedicationProductCatalog.fromOpenFdaSnapshot(
      jsonEncode(payload),
    );
    expect(
      catalog.search('72865-362-10').single.packageDescription,
      contains('1000'),
    );
    expect(catalog.search('levodopa XLCare'), hasLength(2));
  });

  test('identifier classifier preserves eight-digit ambiguity', () {
    expect(
      classifyMedicationIdentifier('12345678'),
      <MedicationIdentifierSystem>[
        MedicationIdentifierSystem.din,
        MedicationIdentifierSystem.gtin,
      ],
    );
    expect(
      classifyMedicationIdentifier('72865-362-01'),
      <MedicationIdentifierSystem>[MedicationIdentifierSystem.ndcPackage],
    );
    expect(
      classifyMedicationIdentifier('rxcui:724606'),
      <MedicationIdentifierSystem>[MedicationIdentifierSystem.rxcui],
    );
  });

  test('network query is encoded and bounded', () async {
    final uri = Uri.https('api.fda.gov', '/drug/ndc.json', <String, String>{
      'search': 'generic_name:"amantadine"',
      'limit': '2',
    }).toString();
    final client = FakeSourceFetchClient(
      textByUrl: <String, String>{uri: jsonEncode(payload)},
    );
    final products = await OpenFdaNdcProductImporter(
      fetchClient: client,
    ).fetchByGenericName('amantadine', limit: 2);
    expect(products, hasLength(2));
    expect(
      () => OpenFdaNdcProductImporter(
        fetchClient: client,
      ).fetchByGenericName('amantadine', limit: 101),
      throwsArgumentError,
    );
  });

  test('checked-in snapshot contains multiple current labelers', () {
    final snapshot =
        jsonDecode(
              File(
                'assets/data/common_medication_products_openfda.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final records = (snapshot['records'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    expect(records.length, greaterThan(100));
    expect(
      records.every(
        (wrapper) =>
            (wrapper['record'] as Map<String, dynamic>)['finished'] == true &&
            ((wrapper['record'] as Map<String, dynamic>)['active_ingredients']
                    as List<dynamic>)
                .isNotEmpty,
      ),
      isTrue,
    );
    final levodopaLabelers = records
        .where((wrapper) => wrapper['query'] == 'carbidopa and levodopa')
        .map(
          (wrapper) =>
              (wrapper['record'] as Map<String, dynamic>)['labeler_name'],
        )
        .whereType<String>()
        .toSet();
    expect(levodopaLabelers.length, greaterThanOrEqualTo(5));
    expect(snapshot['limitations'], isNotEmpty);
  });
}
