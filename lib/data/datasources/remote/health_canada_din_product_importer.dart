import 'dart:convert';

import '../../../core/models/medication_product_pack.dart';
import 'p0_import_support.dart';
import 'source_fetch_client.dart';

class HealthCanadaDinProductImporter {
  static const sourceUrl = 'https://health-products.canada.ca/api/drug/';
  final SourceFetchClient fetchClient;

  const HealthCanadaDinProductImporter({required this.fetchClient});

  Future<List<MedicationProductPack>> fetchByDin(String input) async {
    final din = input.replaceAll(RegExp(r'\D'), '');
    if (din.length != 8) {
      throw ArgumentError.value(input, 'input', 'DIN must contain 8 digits');
    }
    final productPayload = jsonDecode(
      await fetchClient.getText(
        _url('drugproduct', <String, String>{'din': din}),
      ),
    );
    final output = <MedicationProductPack>[];
    for (final product in _maps(productPayload)) {
      final drugCode = _string(product['drug_code']);
      if (drugCode == null) continue;
      final payloads = await Future.wait(<Future<String>>[
        fetchClient.getText(_url('activeingredient', {'id': drugCode})),
        fetchClient.getText(_url('packaging', {'id': drugCode})),
        fetchClient.getText(_url('form', {'id': drugCode})),
        fetchClient.getText(_url('route', {'id': drugCode})),
        fetchClient.getText(_url('status', {'id': drugCode})),
      ]);
      output.addAll(
        importPayloads(
          product: product,
          activeIngredients: _maps(jsonDecode(payloads[0])),
          packaging: _maps(jsonDecode(payloads[1])),
          forms: _maps(jsonDecode(payloads[2])),
          routes: _maps(jsonDecode(payloads[3])),
          statuses: _maps(jsonDecode(payloads[4])),
        ),
      );
    }
    return output;
  }

  List<MedicationProductPack> importPayloads({
    required Map<String, dynamic> product,
    required List<Map<String, dynamic>> activeIngredients,
    required List<Map<String, dynamic>> packaging,
    required List<Map<String, dynamic>> forms,
    required List<Map<String, dynamic>> routes,
    required List<Map<String, dynamic>> statuses,
    DateTime? retrievedAt,
  }) {
    final din = _string(product['drug_identification_number']);
    final drugCode = _string(product['drug_code']);
    final brandName = _string(product['brand_name']);
    if (din == null || drugCode == null || brandName == null) return const [];
    final ingredients = activeIngredients
        .map((row) {
          final name = _string(row['ingredient_name']) ?? '';
          final value = double.tryParse(_string(row['strength']) ?? '');
          final unit = _string(row['strength_unit']);
          final denominatorValue = double.tryParse(
            _string(row['dosage_value']) ?? '',
          );
          final denominatorUnit = _string(row['dosage_unit']);
          return MedicationIngredientStrength(
            ingredientName: name,
            numeratorValue: value,
            numeratorUnit: unit,
            denominatorValue: denominatorValue,
            denominatorUnit: denominatorUnit,
            rawStrength: <String>[
              if (value != null) _formatNumber(value),
              ?unit,
              if (denominatorValue != null || denominatorUnit != null) '/',
              if (denominatorValue != null) _formatNumber(denominatorValue),
              ?denominatorUnit,
            ].join(' '),
          );
        })
        .where((item) => item.ingredientName.isNotEmpty)
        .toList(growable: false);
    if (ingredients.isEmpty) return const [];
    final commonIdentifiers = <MedicationProductIdentifier>[
      MedicationProductIdentifier(
        system: MedicationIdentifierSystem.din,
        level: MedicationIdentifierLevel.product,
        value: din,
      ),
      MedicationProductIdentifier(
        system: MedicationIdentifierSystem.dpdDrugCode,
        level: MedicationIdentifierLevel.product,
        value: drugCode,
      ),
    ];
    final packageRows = packaging.isEmpty
        ? <Map<String, dynamic>>[const <String, dynamic>{}]
        : packaging;
    return packageRows
        .map((package) {
          final upc = _string(package['upc']);
          final packageDescription = <String>[
            _string(package['product_information']) ?? '',
            <String>[
              _string(package['package_size']) ?? '',
              _string(package['package_size_unit']) ?? '',
              _string(package['package_type']) ?? '',
            ].where((item) => item.isNotEmpty).join(' '),
          ].where((item) => item.isNotEmpty).join(' · ');
          return MedicationProductPack(
            id: 'health_canada_din_${stableSlug(upc ?? din)}',
            genericName: ingredients
                .map((item) => item.ingredientName)
                .join('/'),
            brandName: brandName,
            labelerName: _string(product['company_name']),
            jurisdiction: 'CA',
            identifiers: <MedicationProductIdentifier>[
              ...commonIdentifiers,
              if (upc != null)
                MedicationProductIdentifier(
                  system: MedicationIdentifierSystem.gtin,
                  level: MedicationIdentifierLevel.package,
                  value: upc,
                ),
            ],
            ingredients: ingredients,
            dosageForm:
                _firstString(forms, 'pharmaceutical_form_name') ??
                'unspecified',
            routes: routes
                .map((row) => _string(row['route_of_administration_name']))
                .whereType<String>()
                .toList(growable: false),
            packageDescription: packageDescription,
            marketingStartDate: _firstString(statuses, 'original_market_date'),
            marketingEndDate: _firstString(statuses, 'expiration_date'),
            marketingStatus: _firstString(statuses, 'status'),
            sourceSystem: 'HEALTH_CANADA_DPD',
            sourceUrl: sourceUrl,
            retrievedAt: retrievedAt,
          );
        })
        .toList(growable: false);
  }

  String _url(String endpoint, Map<String, String> query) {
    return Uri.https(
      'health-products.canada.ca',
      '/api/drug/$endpoint/',
      <String, String>{
        ...query,
        if (endpoint != 'packaging') 'lang': 'en',
        'type': 'json',
      },
    ).toString();
  }

  List<Map<String, dynamic>> _maps(Object? raw) {
    if (raw is Map<String, dynamic>) return <Map<String, dynamic>>[raw];
    if (raw is List) {
      return raw.whereType<Map<String, dynamic>>().toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  String? _firstString(List<Map<String, dynamic>> rows, String key) {
    for (final row in rows) {
      final value = _string(row[key]);
      if (value != null) return value;
    }
    return null;
  }

  String? _string(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String _formatNumber(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();
}
