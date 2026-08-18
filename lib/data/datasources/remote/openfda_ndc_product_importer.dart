import 'dart:convert';

import '../../../core/models/medication_product_pack.dart';
import 'p0_import_support.dart';
import 'source_fetch_client.dart';

class OpenFdaNdcProductImporter {
  static const sourceUrl = 'https://api.fda.gov/drug/ndc.json';
  final SourceFetchClient fetchClient;

  const OpenFdaNdcProductImporter({required this.fetchClient});

  Future<List<MedicationProductPack>> fetchByGenericName(
    String genericName, {
    int limit = 25,
  }) async {
    if (limit < 1 || limit > 100) {
      throw ArgumentError.value(limit, 'limit', 'must be between 1 and 100');
    }
    final uri = Uri.https('api.fda.gov', '/drug/ndc.json', <String, String>{
      'search': 'generic_name:"${genericName.trim()}"',
      'limit': '$limit',
    });
    final payload = await fetchClient.getJsonMap(uri.toString());
    return importPayload(payload);
  }

  List<MedicationProductPack> importJson(String json) {
    return importPayload(jsonDecode(json) as Map<String, dynamic>);
  }

  List<MedicationProductPack> importPayload(Map<String, dynamic> payload) {
    final retrievedAt = DateTime.tryParse('${payload['retrieved_at'] ?? ''}');
    final rawRecords = <Map<String, dynamic>>[];
    for (final raw in (payload['results'] as List<dynamic>? ?? const [])) {
      if (raw is Map<String, dynamic>) rawRecords.add(raw);
    }
    for (final wrapper in (payload['records'] as List<dynamic>? ?? const [])) {
      if (wrapper is! Map<String, dynamic>) continue;
      final record = wrapper['record'];
      if (record is Map<String, dynamic>) rawRecords.add(record);
    }
    return rawRecords
        .expand((record) => _parseRecord(record, retrievedAt: retrievedAt))
        .toList(growable: false);
  }

  Iterable<MedicationProductPack> _parseRecord(
    Map<String, dynamic> record, {
    required DateTime? retrievedAt,
  }) {
    if (record['finished'] == false ||
        (record['product_type'] != null &&
            record['product_type'] != 'HUMAN PRESCRIPTION DRUG')) {
      return const [];
    }
    final genericName = _string(record['generic_name']);
    final productNdc = _string(record['product_ndc']);
    if (genericName == null || productNdc == null) return const [];
    final commonIdentifiers = <MedicationProductIdentifier>[
      MedicationProductIdentifier(
        system: MedicationIdentifierSystem.ndcProduct,
        level: MedicationIdentifierLevel.product,
        value: productNdc,
      ),
      ..._openFdaIdentifiers(record['openfda']),
    ];
    final ingredients = _ingredients(record['active_ingredients']);
    if (ingredients.isEmpty) return const [];
    final packaging = (record['packaging'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    final rows = packaging.isEmpty
        ? <Map<String, dynamic>>[const <String, dynamic>{}]
        : packaging;
    return rows.map((package) {
      final packageNdc = _string(package['package_ndc']);
      final identifiers = <MedicationProductIdentifier>[
        ...commonIdentifiers,
        if (packageNdc != null)
          MedicationProductIdentifier(
            system: MedicationIdentifierSystem.ndcPackage,
            level: MedicationIdentifierLevel.package,
            value: packageNdc,
          ),
      ];
      final externalKey = packageNdc ?? productNdc;
      return MedicationProductPack(
        id: 'openfda_ndc_${stableSlug(externalKey)}',
        genericName: genericName,
        brandName:
            _string(record['brand_name']) ?? _string(record['brand_name_base']),
        labelerName: _string(record['labeler_name']),
        jurisdiction: 'US',
        identifiers: identifiers,
        ingredients: ingredients,
        dosageForm: _string(record['dosage_form']) ?? 'unspecified',
        routes: _strings(record['route']),
        packageDescription: _string(package['description']) ?? '',
        marketingStartDate:
            _string(package['marketing_start_date']) ??
            _string(record['marketing_start_date']),
        marketingEndDate:
            _string(package['marketing_end_date']) ??
            _string(record['marketing_end_date']),
        marketingStatus: _string(record['marketing_category']),
        sourceSystem: 'OPENFDA_NDC',
        sourceUrl: sourceUrl,
        retrievedAt: retrievedAt,
      );
    });
  }

  List<MedicationIngredientStrength> _ingredients(Object? raw) {
    return (raw as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((row) {
          final rawStrength = _string(row['strength']) ?? '';
          final parsed = _parseStrength(rawStrength);
          return MedicationIngredientStrength(
            ingredientName: _string(row['name']) ?? '',
            numeratorValue: parsed.$1,
            numeratorUnit: parsed.$2,
            denominatorValue: parsed.$3,
            denominatorUnit: parsed.$4,
            rawStrength: rawStrength,
          );
        })
        .where((item) => item.ingredientName.isNotEmpty)
        .toList(growable: false);
  }

  (double?, String?, double?, String?) _parseStrength(String raw) {
    final parts = raw.split('/');
    final numerator = _numberAndUnit(parts.first);
    final denominator = parts.length > 1
        ? _numberAndUnit(parts.sublist(1).join('/'))
        : (null, null);
    return (numerator.$1, numerator.$2, denominator.$1, denominator.$2);
  }

  (double?, String?) _numberAndUnit(String raw) {
    final match = RegExp(
      r'^\s*([0-9]+(?:\.[0-9]+)?)\s*(.*?)\s*$',
    ).firstMatch(raw);
    if (match == null) return (null, null);
    final unit = match.group(2)?.trim();
    return (
      double.tryParse(match.group(1)!),
      unit == null || unit.isEmpty ? null : unit,
    );
  }

  Iterable<MedicationProductIdentifier> _openFdaIdentifiers(Object? raw) sync* {
    if (raw is! Map<String, dynamic>) return;
    for (final value in _strings(raw['rxcui'])) {
      yield MedicationProductIdentifier(
        system: MedicationIdentifierSystem.rxcui,
        level: MedicationIdentifierLevel.concept,
        value: value,
      );
    }
    for (final value in _strings(raw['spl_set_id'])) {
      yield MedicationProductIdentifier(
        system: MedicationIdentifierSystem.dailymedSetId,
        level: MedicationIdentifierLevel.product,
        value: value,
      );
    }
    for (final value in _strings(raw['upc'])) {
      yield MedicationProductIdentifier(
        system: MedicationIdentifierSystem.gtin,
        level: MedicationIdentifierLevel.package,
        value: value,
      );
    }
  }

  String? _string(Object? raw) {
    final value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  List<String> _strings(Object? raw) {
    if (raw is List) {
      return raw.map(_string).whereType<String>().toList(growable: false);
    }
    final value = _string(raw);
    return value == null ? const <String>[] : <String>[value];
  }
}
