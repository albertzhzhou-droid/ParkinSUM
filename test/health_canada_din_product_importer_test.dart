import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/data/datasources/remote/health_canada_din_product_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';

void main() {
  Map<String, dynamic> product() => <String, dynamic>{
    'drug_code': 107108,
    'drug_identification_number': '02568799',
    'brand_name': 'PRO-LEVOCARB',
    'company_name': 'PRO DOC LIMITEE',
  };

  test('maps DIN product, company, strengths, form, route and UPC package', () {
    const importer = HealthCanadaDinProductImporter(
      fetchClient: FakeSourceFetchClient(textByUrl: <String, String>{}),
    );
    final packs = importer.importPayloads(
      product: product(),
      activeIngredients: const <Map<String, dynamic>>[
        <String, dynamic>{
          'ingredient_name': 'CARBIDOPA',
          'strength': '25',
          'strength_unit': 'MG',
          'dosage_value': '',
          'dosage_unit': '',
        },
        <String, dynamic>{
          'ingredient_name': 'LEVODOPA',
          'strength': '100',
          'strength_unit': 'MG',
          'dosage_value': '',
          'dosage_unit': '',
        },
      ],
      packaging: const <Map<String, dynamic>>[
        <String, dynamic>{
          'upc': '123456789012',
          'package_size': '100',
          'package_size_unit': 'TABLET',
          'package_type': 'BOTTLE',
          'product_information': '',
        },
      ],
      forms: const <Map<String, dynamic>>[
        <String, dynamic>{'pharmaceutical_form_name': 'Tablet'},
      ],
      routes: const <Map<String, dynamic>>[
        <String, dynamic>{'route_of_administration_name': 'Oral'},
      ],
      statuses: const <Map<String, dynamic>>[
        <String, dynamic>{
          'status': 'Marketed',
          'original_market_date': '2026-06-08',
        },
      ],
      retrievedAt: DateTime.utc(2026, 8, 17),
    );

    expect(packs, hasLength(1));
    final pack = packs.single;
    expect(pack.jurisdiction, 'CA');
    expect(pack.labelerName, 'PRO DOC LIMITEE');
    expect(pack.strengthDisplay, 'CARBIDOPA 25 MG + LEVODOPA 100 MG');
    expect(pack.packageDescription, '100 TABLET BOTTLE');
    expect(pack.marketingStatus, 'Marketed');
    expect(pack.matchesIdentifier('DIN:02568799'), isTrue);
    expect(
      pack.identifiers.map((item) => item.system),
      containsAll(<MedicationIdentifierSystem>[
        MedicationIdentifierSystem.din,
        MedicationIdentifierSystem.dpdDrugCode,
        MedicationIdentifierSystem.gtin,
      ]),
    );
  });

  test('exact DIN lookup uses documented per-product endpoints', () async {
    String url(String endpoint, Map<String, String> query) => Uri.https(
      'health-products.canada.ca',
      '/api/drug/$endpoint/',
      <String, String>{
        ...query,
        if (endpoint != 'packaging') 'lang': 'en',
        'type': 'json',
      },
    ).toString();

    final payloads = <String, String>{
      url('drugproduct', {'din': '02568799'}): jsonEncode(product()),
      url('activeingredient', {'id': '107108'}): jsonEncode(<Object>[
        <String, Object>{
          'ingredient_name': 'LEVODOPA',
          'strength': '100',
          'strength_unit': 'MG',
        },
      ]),
      url('packaging', {'id': '107108'}): '[]',
      url('form', {'id': '107108'}): jsonEncode(<Object>[
        <String, Object>{'pharmaceutical_form_name': 'Tablet'},
      ]),
      url('route', {'id': '107108'}): jsonEncode(<Object>[
        <String, Object>{'route_of_administration_name': 'Oral'},
      ]),
      url('status', {'id': '107108'}): jsonEncode(<Object>[
        <String, Object>{'status': 'Approved'},
      ]),
    };
    final packs = await HealthCanadaDinProductImporter(
      fetchClient: FakeSourceFetchClient(textByUrl: payloads),
    ).fetchByDin('DIN 02568799');
    expect(packs.single.matchesIdentifier('02568799'), isTrue);
    expect(packs.single.marketingStatus, 'Approved');
  });

  test('rejects malformed DIN before network access', () async {
    const importer = HealthCanadaDinProductImporter(
      fetchClient: FakeSourceFetchClient(textByUrl: <String, String>{}),
    );
    await expectLater(importer.fetchByDin('123'), throwsArgumentError);
  });
}
