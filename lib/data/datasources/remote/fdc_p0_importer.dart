import 'dart:convert';

import 'package:crypto/crypto.dart';
import '../../../core/models/food_item.dart';
import '../../../core/utils/texture_support.dart';
import '../../../core/utils/qualified_value_parser.dart';
import '../../../domain/entities/cdss_records.dart';
import 'amino_acid_extractor.dart';
import 'archive_import_support.dart';
import 'crosswalk_builders.dart';
import 'fdc_nutrient_identity.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';
import 'p0_source_urls.dart';
import 'source_fetch_client.dart';

/// USDA FoodData Central / Foundation Foods 导入器。
///
/// 当前实现支持两条真实链路：
/// 1. 已拿到 `/food/{fdcId}` JSON；
/// 2. 已拿到 Foundation bulk JSON 中的 food object 列表。
///
/// JSON and CSV portions retain their source weights as evidence; no serving
/// is selected automatically. Foundation composition uses the explicit preview
/// service, which checks food, document, basis and unit identity.
class FdcP0Importer {
  final SourceFetchClient fetchClient;

  const FdcP0Importer({required this.fetchClient});

  Future<P0ImportBundle> fetchFoodDetail({
    required String apiKey,
    required int fdcId,
  }) async {
    // The key is sent as an X-Api-Key header (supported by api.data.gov /
    // FDC) instead of a query parameter, so it can never leak through URLs in
    // error messages, logs, or cache-metadata keys.
    final url = '${P0SourceUrls.fdcFoodDetail}/$fdcId';
    final json = await fetchClient.getJsonMap(
      url,
      headers: {'X-Api-Key': apiKey},
    );
    return importFoods([json], sourceLabel: 'fdc_api_food_detail');
  }

  /// 直接导入 FDC 官方 ZIP。
  ///
  /// 当前支持两类常见包：
  /// 1. Foundation / bulk JSON ZIP；
  /// 2. CSV ZIP（最小支持 `food`, `food_nutrient`, `nutrient`, `food_category`）。
  P0ImportBundle importZipBytes(
    List<int> zipBytes, {
    required String sourceLabel,
  }) {
    final files = ArchiveImportSupport.unzipTextFiles(zipBytes);
    final jsonEntry = files.entries.firstWhere(
      (entry) => entry.key.toLowerCase().endsWith('.json'),
      orElse: () => const MapEntry('', ''),
    );
    if (jsonEntry.key.isNotEmpty) {
      final decoded = jsonDecode(jsonEntry.value);
      final rawFoods = decoded is List
          ? decoded
          : decoded is Map
          ? decoded['FoundationFoods'] ?? decoded['foods'] ?? const []
          : null;
      if (rawFoods is! List) {
        throw const FormatException('FDC JSON food collection must be a list.');
      }
      final foods = <Map<String, dynamic>>[];
      final nullSlots = <int>[];
      for (var index = 0; index < rawFoods.length; index++) {
        final food = rawFoods[index];
        if (food == null) {
          nullSlots.add(index);
        } else if (food is Map<String, dynamic>) {
          foods.add(food);
        } else {
          throw FormatException('FDC JSON food slot $index is not an object.');
        }
      }
      return importFoods(
        foods,
        sourceLabel: sourceLabel,
        sourceArchiveMetadata: {
          'archive_sha256': sha256.convert(zipBytes).toString(),
          'member_path': jsonEntry.key,
          'member_utf8_sha256': sha256
              .convert(utf8.encode(jsonEntry.value))
              .toString(),
          'raw_food_array_slot_count': rawFoods.length,
          'food_object_count': foods.length,
          'null_food_slot_indexes': nullSlots,
          'null_slot_policy':
              'retained_as_source_null_positions_not_food_records',
        },
      );
    }
    return importCsvArchive(files, sourceLabel: sourceLabel);
  }

  P0ImportBundle importCsvArchive(
    Map<String, String> files, {
    required String sourceLabel,
  }) {
    final foodRows = _loadCsvRows(files, 'food');
    final nutrientRows = _loadCsvRows(files, 'nutrient');
    final foodNutrientRows = _loadCsvRows(files, 'food_nutrient');
    final categoryRows = _loadCsvRows(files, 'food_category');
    final derivationRows = _loadCsvRows(files, 'food_nutrient_derivation');
    final nutrientSourceRows = _loadCsvRows(files, 'food_nutrient_source');
    final conversionRows = _loadCsvRows(
      files,
      'food_nutrient_conversion_factor',
    );
    final calorieFactorRows = _loadCsvRows(
      files,
      'food_calorie_conversion_factor',
    );
    final proteinFactorRows = _loadCsvRows(
      files,
      'food_protein_conversion_factor',
    );
    final fatFactorRows = _loadCsvRows(files, 'food_fat_conversion_factor');
    final portionRows = _loadCsvRows(files, 'food_portion');
    final measureUnitRows = _loadCsvRows(files, 'measure_unit');
    final measureUnitById = {
      for (final row in measureUnitRows) (row['id'] ?? ''): row,
    };
    final portionsByFood = <String, List<Map<String, dynamic>>>{};
    for (final row in portionRows) {
      final foodId = (row['fdc_id'] ?? '').trim();
      if (foodId.isEmpty) continue;
      final measure = measureUnitById[row['measure_unit_id']];
      portionsByFood.putIfAbsent(foodId, () => []).add({
        'id': row['id'],
        'amount': _nullableDouble(row['amount']),
        'gramWeight': _nullableDouble(row['gram_weight']),
        'modifier': row['modifier'],
        'portionDescription': row['portion_description'],
        'sequenceNumber': _nullableInt(row['seq_num']),
        'dataPoints': _nullableInt(row['data_points']),
        'footnote': row['footnote'],
        'minYearAcquired': _nullableInt(row['min_year_acquired']),
        if (measure != null)
          'measureUnit': {
            'id': _nullableInt(measure['id']),
            'name': measure['name'],
            'abbreviation': measure['abbreviation'],
          },
      });
    }

    final nutrientById = {
      for (final row in nutrientRows)
        (row['id'] ?? row['nutrient_id'] ?? '').toString(): row,
    };
    final categoryById = {
      for (final row in categoryRows)
        (row['id'] ?? row['food_category_id'] ?? '').toString():
            (row['description'] ?? row['food_category_description'] ?? '')
                .toString(),
    };
    final derivationById = {
      for (final row in derivationRows)
        (row['id'] ?? row['derivation_id'] ?? '').toString(): row,
    };
    final nutrientSourceById = {
      for (final row in nutrientSourceRows)
        (row['id'] ?? row['food_nutrient_source_id'] ?? '').toString(): row,
    };
    final nutrientRowsByFood = <String, List<Map<String, String>>>{};
    for (final row in foodNutrientRows) {
      final foodId = (row['fdc_id'] ?? row['food_id'] ?? '').toString();
      if (foodId.isEmpty) continue;
      nutrientRowsByFood
          .putIfAbsent(foodId, () => <Map<String, String>>[])
          .add(row);
    }

    final foods = foodRows
        .map((row) {
          final fdcId = (row['fdc_id'] ?? row['id'] ?? '').toString();
          final categoryId = (row['food_category_id'] ?? '').toString();
          final nutrients =
              (nutrientRowsByFood[fdcId] ?? const <Map<String, String>>[])
                  .map((item) {
                    final nutrientId = (item['nutrient_id'] ?? item['id'] ?? '')
                        .toString();
                    final nutrient =
                        nutrientById[nutrientId] ?? const <String, String>{};
                    final derivationId = (item['derivation_id'] ?? '').trim();
                    final derivation =
                        derivationById[derivationId] ??
                        const <String, String>{};
                    final sourceId =
                        (item['food_nutrient_source_id'] ??
                                derivation['source_id'] ??
                                '')
                            .trim();
                    final nutrientSource =
                        nutrientSourceById[sourceId] ??
                        const <String, String>{};
                    return <String, dynamic>{
                      'id': item['id'],
                      'amount': item['amount'],
                      'loq': item['loq'],
                      'dataPoints': item['data_points'],
                      'min': item['min'],
                      'max': item['max'],
                      'median': item['median'],
                      'standardError': item['standard_error'],
                      'footnote': item['footnote'],
                      'minYearAcquired': item['min_year_acquired'],
                      if (derivation.isNotEmpty)
                        'foodNutrientDerivation': {
                          'code': derivation['code'],
                          'description': derivation['description'],
                          'reference_id': derivationId,
                        },
                      if (nutrientSource.isNotEmpty)
                        'foodNutrientSource': {
                          'code': nutrientSource['code'],
                          'description': nutrientSource['description'],
                          'reference_id': sourceId,
                        },
                      'nutrient': {
                        'id': nutrientId,
                        'number': (nutrient['number'] ?? '').toString(),
                        'name': (nutrient['name'] ?? '').toString(),
                        'unitName':
                            (nutrient['unit_name'] ??
                                    nutrient['unitName'] ??
                                    '')
                                .toString(),
                      },
                    };
                  })
                  .toList(growable: false);
          return <String, dynamic>{
            'fdcId': fdcId,
            'description': (row['description'] ?? '').toString(),
            'dataType': (row['data_type'] ?? row['dataType'] ?? 'FDC')
                .toString(),
            'foodCategory':
                categoryById[categoryId] ??
                (row['food_class'] ?? 'other').toString(),
            'foodNutrients': nutrients,
            'foodPortions': portionsByFood[fdcId] ?? const [],
            if (row.containsKey('publication_date'))
              'publicationDate': row['publication_date'],
            if (conversionRows.isNotEmpty)
              'nutrientConversionFactors': _csvConversionFactors(
                fdcId,
                conversionRows,
                calorieFactorRows,
                proteinFactorRows,
                fatFactorRows,
              ),
          };
        })
        .where((row) => row['fdcId'].toString().isNotEmpty)
        .toList(growable: false);

    return importFoods(foods, sourceLabel: sourceLabel);
  }

  P0ImportBundle importFoods(
    List<Map<String, dynamic>> foods, {
    required String sourceLabel,
    Map<String, dynamic>? sourceArchiveMetadata,
  }) {
    final foodBases = [for (final food in foods) FdcFoodBasis.inspect(food)];
    final qualifiedBasisEvidence = [
      for (final basis in foodBases)
        if (basis.requiresQualifiedIdentity) basis.toJson(),
    ];
    final brandedProductDetails = [
      for (final food in foods)
        if (const {
          'branded',
          'branded_food',
        }.contains('${food['dataType'] ?? ''}'.trim().toLowerCase()))
          {
            'fdc_id': food['fdcId'],
            'source_fields': food,
            'evidence_scope': 'complete_original_branded_food_object',
            'parser_contract': 'fdc_branded_product_detail_v1',
            'source_currency_inferred': false,
            'ingredient_quantity_inferred': false,
            'product_reformulation_inferred': false,
          },
    ];
    final parserIdentity =
        '${qualifiedBasisEvidence.isEmpty ? '' : ':fdc_source_basis_v1'}${brandedProductDetails.isEmpty ? '' : ':fdc_branded_product_detail_v1'}';
    final contentSha256 = sha256
        .convert(utf8.encode(jsonEncode(foods)))
        .toString();
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'FDC',
      externalKey: sourceArchiveMetadata == null
          ? '$sourceLabel:$contentSha256$parserIdentity'
          : '$sourceLabel:$contentSha256:${sha256.convert(utf8.encode(jsonEncode(sourceArchiveMetadata)))}$parserIdentity',
    );

    final foodConcepts = <FoodConceptRecord>[];
    final foodVariants = <FoodVariantRecord>[];
    final variantScopes = <VariantScopeRecord>[];
    final observations = <ObservationRecord>[];
    final resolvedFacts = <ResolvedFactRecord>[];
    final projectedFoods = <FoodItem>[];
    final crosswalks = <ConceptVariantCrosswalkRecord>[];
    final conceptIds = <String>{};
    final portionAuditGaps = <Map<String, dynamic>>[];
    final nutrientStatisticsAudit = <Map<String, dynamic>>[];
    final nutrientValueAudit = <Map<String, dynamic>>[];
    final sourceNutrientSummaries = <Map<String, dynamic>>[];
    final aminoAcidExtractor = AminoAcidExtractor();

    for (final food in foods) {
      final fdcId = '${food['fdcId'] ?? ''}'.trim();
      final description = '${food['description'] ?? ''}'.trim();
      if (fdcId.isEmpty || description.isEmpty) continue;
      final dataType = '${food['dataType'] ?? 'FDC'}';
      final sourceBasis = FdcFoodBasis.inspect(food);
      final conceptId = buildFoodConceptId(description);
      final variantId = buildFoodVariantId(
        conceptId: conceptId,
        jurisdiction: 'US',
        sourceSystem: dataType,
        sourceFoodCode: fdcId,
      );
      final scopeHash = buildScopeHash('$variantId:$dataType');

      if (conceptIds.add(conceptId)) {
        foodConcepts.add(
          FoodConceptRecord(
            foodConceptId: conceptId,
            canonicalNameEn: description,
            canonicalNameZh: description,
            foodGroup: '${food['foodCategory'] ?? 'other'}',
          ),
        );
      }

      foodVariants.add(
        FoodVariantRecord(
          foodVariantId: variantId,
          foodConceptId: conceptId,
          jurisdiction: 'US',
          sourceFamily: dataType,
          sourceFoodCode: fdcId,
          displayNameLocal: description,
          isAuthoritativeForRegion: true,
          isAuthoritativeFallback: false,
          status: 'imported_fdc_json',
          fallbackChainJson: '["US","NA","GLOBAL"]',
        ),
      );
      variantScopes.add(
        VariantScopeRecord(
          scopeHash: scopeHash,
          jurisdiction: 'US',
          brand: null,
          dosageForm: null,
          releaseType: null,
          saltForm: null,
          route: null,
          preparationState: '${food['foodClass'] ?? ''}'.trim().isEmpty
              ? null
              : '${food['foodClass']}',
          cookingState: null,
          plantPart: null,
          cultivar: null,
          samplingFrame: dataType,
        ),
      );

      final nutrientMap = <String, String>{};
      final nutrientRows = food['foodNutrients'] as List<dynamic>? ?? const [];
      final attributeCounts = <String, int>{};
      final provenRowsByAttribute = <String, List<Map>>{};
      for (final row in nutrientRows.whereType<Map>()) {
        final nutrient = row['nutrient'] is Map ? row['nutrient'] as Map : row;
        final attribute = _attributeCodeFromFdcNutrient(
          nutrientId: nutrient['id'],
          nutrientNumber: '${nutrient['number'] ?? ''}',
          nutrientName: '${nutrient['name'] ?? ''}',
        );
        if (attribute != null) {
          final previous = provenRowsByAttribute.putIfAbsent(
            attribute,
            () => [],
          );
          if (previous.any((other) => _sameSourceNutrientRow(row, other))) {
            continue;
          }
          previous.add(row);
          attributeCounts.update(
            attribute,
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }
      final resolvedAttributes = <String>{};
      for (
        var nutrientIndex = 0;
        nutrientIndex < nutrientRows.length;
        nutrientIndex++
      ) {
        final nutrientRow = nutrientRows[nutrientIndex];
        if (nutrientRow is! Map<String, dynamic>) continue;
        final map = nutrientRow;
        final nutrient = (map['nutrient'] as Map<String, dynamic>?) ?? map;
        final attributeCode = _attributeCodeFromFdcNutrient(
          nutrientId: nutrient['id'],
          nutrientNumber: '${nutrient['number'] ?? ''}',
          nutrientName: '${nutrient['name'] ?? ''}',
        );
        final sourceAmount = _nullableDouble(map['amount']);
        final sourceLoq = _nullableDouble(
          map['loq'] ?? map['limitOfQuantification'],
        );
        final summaryBelowLoq =
            sourceAmount != null &&
            sourceAmount > 0 &&
            sourceLoq != null &&
            sourceLoq > sourceAmount;
        final sampleDetails = map['nutrientAnalysisDetails'];
        sourceNutrientSummaries.add({
          'fdc_id': fdcId,
          'food_nutrient_id': map['id'],
          'nutrient_id': nutrient['id'],
          'nutrient_number': nutrient['number'],
          'nutrient_name': nutrient['name'],
          'derivation_fields': map['foodNutrientDerivation'],
          'nutrient_source_fields': map['foodNutrientSource'],
          if (_isAtwaterIdentity(nutrient))
            'energy_method_identity_status': attributeCode == null
                ? 'hold_conflicting_source_identifiers'
                : 'identified_by_source_nutrient_id_or_number',
          if (attributeCode == 'energy_atwater_general_kcal')
            'energy_method': 'atwater_general_factors',
          if (attributeCode == 'energy_atwater_specific_kcal')
            'energy_method': 'atwater_specific_factors',
          'unit': nutrient['unitName'],
          'value_scope': 'reported_food_summary',
          'reported_amount': map['amount'],
          'reported_loq': map['loq'] ?? map['limitOfQuantification'],
          'complete_sample_mean_verified': false,
          'quantification_status': summaryBelowLoq
              ? 'point_held_quantification_scope_unverified'
              : sourceAmount == 0 && (sourceLoq == null || sourceLoq == 0)
              ? 'reported_zero_precision_unverified'
              : 'source_reported',
          'sample_fields': sampleDetails is List
              ? [
                  for (final sample in sampleDetails.whereType<Map>())
                    {
                      for (final field in const [
                        'subSampleId',
                        'nutrientId',
                        'amount',
                        'loq',
                        'labMethodTechnique',
                        'labMethodDescription',
                      ])
                        if (sample.containsKey(field)) field: sample[field],
                    },
                ]
              : const [],
        });
        if (attributeCode == null) {
          nutrientValueAudit.add({
            'fdc_id': fdcId,
            'nutrient_id': nutrient['id'],
            'nutrient_number': nutrient['number'],
            'nutrient_name': nutrient['name'],
            'decision': 'retained_source_fields_only',
            'reason': 'unrecognized_or_inconsistent_nutrient_identity',
          });
          continue;
        }
        final amount = map['amount'];
        if (amount == null) {
          continue;
        }
        final loqRaw = map['loq'] ?? map['limitOfQuantification'];
        final loq = _nullableDouble(loqRaw);
        final numericAmount = _nullableDouble(amount);
        // USDA stores a below-quantification result as amount=0 plus a
        // positive LOQ. Retain censoring instead of manufacturing an exact 0.
        final censored = numericAmount == 0 && loq != null && loq > 0;
        final rawValue = censored ? '<$loq' : '$amount';
        final parsedValue = summaryBelowLoq
            ? QualifiedValue(
                qualifierKind: QualifierKind.missing,
                low: null,
                high: null,
                valueNum: null,
                rawValueText:
                    'source_amount=$amount; source_loq=$loq; '
                    'value_scope=reported_food_summary; '
                    'point_status=held_quantification_scope_unverified',
              )
            : parseQualifiedValue(rawValue);
        final unit = canonicalFdcNutrientUnit(
          '${nutrient['unitName'] ?? _expectedNutrientUnit(attributeCode)}',
        );
        final valueNumbers = [
          parsedValue.low,
          parsedValue.high,
          parsedValue.valueNum,
        ].whereType<double>();
        final invalidValue =
            (!summaryBelowLoq && !parsedValue.isComparable) ||
            valueNumbers.any((value) => !value.isFinite || value < 0) ||
            (parsedValue.low != null &&
                parsedValue.high != null &&
                parsedValue.low! > parsedValue.high!) ||
            (loqRaw != null &&
                '$loqRaw'.trim().isNotEmpty &&
                (loq == null || loq < 0));
        final unitMatches =
            (!const {
                  'energy_atwater_general_kcal',
                  'energy_atwater_specific_kcal',
                }.contains(attributeCode) ||
                _nonEmptyString(nutrient['unitName']) != null) &&
            unit.toLowerCase() ==
                _expectedNutrientUnit(attributeCode).toLowerCase();
        if (invalidValue || !unitMatches) {
          nutrientValueAudit.add({
            'fdc_id': fdcId,
            'attribute_code': attributeCode,
            'amount': amount,
            'loq': loqRaw,
            'unit': unit,
            'decision': 'withheld',
            'reason': invalidValue ? 'invalid_nutrient_value' : 'unit_mismatch',
          });
          continue;
        }
        if (summaryBelowLoq) {
          nutrientValueAudit.add({
            'fdc_id': fdcId,
            'attribute_code': attributeCode,
            'amount': amount,
            'loq': loq,
            'value_scope': 'reported_food_summary',
            'decision': 'withheld_from_point_projection',
            'reason': 'quantification_scope_unverified',
          });
        }
        if (censored) {
          nutrientValueAudit.add({
            'fdc_id': fdcId,
            'attribute_code': attributeCode,
            'amount': amount,
            'loq': loq,
            'decision': 'below_quantification_limit',
          });
        }
        final duplicateAttribute = attributeCounts[attributeCode]! > 1;
        if (!duplicateAttribute &&
            !summaryBelowLoq &&
            sourceBasis.supportsEdibleMassPoint) {
          nutrientMap[attributeCode] = rawValue;
        }
        if (duplicateAttribute) {
          nutrientValueAudit.add({
            'fdc_id': fdcId,
            'attribute_code': attributeCode,
            'decision': 'withheld_from_point_projection',
            'reason': 'duplicate_nutrient_attribute',
            'source_row_count': attributeCounts[attributeCode],
          });
        }
        final derivation = _nestedRecord(map['foodNutrientDerivation']);
        final nutrientSource =
            _nestedRecord(map['foodNutrientSource']) ??
            _nestedRecord(derivation?['foodNutrientSource']);
        final methodCode = _nonEmptyString(derivation?['code']);
        final sourceCode = _nonEmptyString(nutrientSource?['code']);
        final dataPoints = _nullableInt(
          map['dataPoints'] ?? map['data_points'],
        );
        final minimum = _nullableDouble(map['min']);
        final maximum = _nullableDouble(map['max']);
        final median = _nullableDouble(map['median']);
        final standardError = _nullableDouble(
          map['standardError'] ?? map['standard_error'],
        );
        final derivationDescription = _nonEmptyString(
          derivation?['description'],
        );
        final sourceStatisticsPresent =
            dataPoints != null ||
            minimum != null ||
            maximum != null ||
            median != null ||
            standardError != null ||
            derivation != null ||
            nutrientSource != null ||
            map['footnote'] != null ||
            map['minYearAcquired'] != null ||
            map['min_year_acquired'] != null;
        final hasSampleRange =
            minimum != null &&
            maximum != null &&
            (dataPoints == null || dataPoints > 0);
        final rangeRawValueText = hasSampleRange
            ? <String>[
                'source_min=$minimum',
                'source_max=$maximum',
                'data_points=${dataPoints ?? 'unknown'}',
                if (median != null) 'median=$median',
                if (standardError != null) 'standard_error=$standardError',
                if (methodCode != null) 'derivation_code=$methodCode',
                if (sourceCode != null) 'source_code=$sourceCode',
              ].join('; ')
            : null;
        final rangeObservationId = hasSampleRange
            ? 'obs_${stableHash('$sourceDocId:$variantId:$attributeCode:$nutrientIndex:fdc_source_range:$rangeRawValueText')}'
            : null;
        if (sourceStatisticsPresent) {
          nutrientStatisticsAudit.add({
            'fdc_id': fdcId,
            'attribute_code': attributeCode,
            'average_amount': amount,
            'data_points': dataPoints,
            'min': minimum,
            'max': maximum,
            'median': median,
            'standard_error': standardError,
            'derivation_code': methodCode,
            'derivation_description': derivationDescription,
            'nutrient_source_code': sourceCode,
            'footnote': map['footnote'],
            'min_year_acquired':
                map['minYearAcquired'] ?? map['min_year_acquired'],
            'range_observation_id': rangeObservationId,
          });
        }
        final observation = ObservationRecord(
          observationId:
              'obs_${stableHash('$sourceDocId:$variantId:$attributeCode:$nutrientIndex:$rawValue')}',
          domain: 'food',
          entityType: 'food_variant',
          entityKey: variantId,
          attributeCode: attributeCode,
          valueType: 'numeric_interval',
          value: parsedValue,
          unit: unit,
          basisType: sourceBasis.basisType,
          basisAmount: sourceBasis.basisType == 'source_basis_unqualified'
              ? null
              : 100,
          scopeHash: scopeHash,
          sourceDocId: sourceDocId,
          recordLocator: _sourceNutrientLocator(
            fdcId,
            attributeCode,
            map,
            sourceEvidenceUnique: !duplicateAttribute,
          ),
          methodCode: methodCode,
          extractionConfidence: 1,
        );
        observations.add(observation);
        if (!duplicateAttribute &&
            !summaryBelowLoq &&
            resolvedAttributes.add(attributeCode)) {
          resolvedFacts.add(
            resolvedFactFromObservation(
              observation: observation,
              policyId: 'fdc_import_v1',
              snapshotId: 'facts_fdc_import_v1',
            ),
          );
        }
        if (hasSampleRange) {
          observations.add(
            ObservationRecord(
              observationId: rangeObservationId!,
              domain: 'food',
              entityType: 'food_variant',
              entityKey: variantId,
              attributeCode: attributeCode,
              valueType: 'numeric_interval',
              value: QualifiedValue(
                qualifierKind: QualifierKind.range,
                low: minimum,
                high: maximum,
                valueNum: null,
                rawValueText: rangeRawValueText!,
              ),
              unit: unit,
              basisType: sourceBasis.basisType,
              basisAmount: sourceBasis.basisType == 'source_basis_unqualified'
                  ? null
                  : 100,
              scopeHash: scopeHash,
              sourceDocId: sourceDocId,
              recordLocator: '$fdcId:$attributeCode:sample_range',
              methodCode: methodCode,
              extractionConfidence: 1,
            ),
          );
        }
      }

      final foodPortions = food['foodPortions'];
      final foodPortionEvidence = <FoodPortionEvidence>[];
      if (foodPortions is List && foodPortions.isNotEmpty) {
        final summarized = <Map<String, dynamic>>[];
        final fieldNamesObserved = <String>{};
        var unparsed = 0;
        for (
          var portionIndex = 0;
          portionIndex < foodPortions.length;
          portionIndex++
        ) {
          final raw = foodPortions[portionIndex];
          if (raw is! Map) {
            unparsed += 1;
            continue;
          }
          for (final key in raw.keys) {
            fieldNamesObserved.add(key.toString());
          }
          final evidence = FoodPortionEvidence.fromFdc(
            sourceDocId: sourceDocId,
            sourceFoodId: fdcId,
            portionIndex: portionIndex,
            portion: raw,
          );
          foodPortionEvidence.add(evidence);
          final amount = raw['amount'];
          final modifier =
              raw['modifier'] ??
              raw['portionDescription'] ??
              raw['description'];
          final gramWeight = raw['gramWeight'];
          if (amount == null && modifier == null && gramWeight == null) {
            unparsed += 1;
          }
          summarized.add(evidence.toJson());
        }
        portionAuditGaps.add({
          'fdc_id': fdcId,
          'source_object_count': foodPortions.length,
          'parsed_portions': summarized,
          'unparsed_count': unparsed,
          'observed_field_names': fieldNamesObserved.toList()..sort(),
          ...ImporterAudit.auditGap(
            fieldName: 'foodPortions',
            reason:
                'Source-reported portion fields are retained as evidence only; no serving is selected and no nutrient conversion or rescaling is performed.',
            observedCount: foodPortions.length,
            observedKeys: fieldNamesObserved.toList()..sort(),
          ),
        });
      }

      final textureClass = inferTextureClassFromText(
        name: description,
        description: '${food['foodCategory'] ?? ''} $dataType',
        categoryName: '${food['foodCategory'] ?? 'other'}',
      );
      final aminoAcidProfile = aminoAcidExtractor.extractFromFdcStyle(food);
      crosswalks.add(
        buildCrosswalk(
          domain: 'food',
          conceptId: conceptId,
          variantId: variantId,
          externalIdSystem: 'FDC id',
          externalIdValue: fdcId,
          jurisdiction: 'US',
          sourceDocId: sourceDocId,
          confidence: 1.0,
          mappingPayload: {
            'data_type': dataType,
            'description': description,
            'food_category': '${food['foodCategory'] ?? 'other'}',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypeAuthoritativeFoodCode,
              reason:
                  'FDC id copied verbatim from FoodData Central food object.',
              promotedFields: const ['fdcId'],
              nonPromotedFields: const ['foodPortions'],
            ),
          },
        ),
      );
      crosswalks.add(
        buildCrosswalk(
          domain: 'food',
          conceptId: conceptId,
          variantId: variantId,
          externalIdSystem: 'FDC dataType',
          externalIdValue: dataType,
          jurisdiction: 'US',
          sourceDocId: sourceDocId,
          confidence: 0.7,
          mappingPayload: {
            'fdc_id': fdcId,
            'audit_note':
                'dataType (Foundation/SR Legacy/Survey/Branded) recorded as a metadata crosswalk; not a stable per-food code.',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType: ImporterAudit.sourceIdTypeMetadataAttribute,
              reason:
                  'dataType copied from FDC source object to preserve source-family semantics.',
              promotedFields: const ['dataType'],
              nonPromotedFields: const ['foodPortions'],
            ),
          },
        ),
      );
      final ndbNumber = '${food['ndbNumber'] ?? ''}'.trim();
      if (ndbNumber.isNotEmpty) {
        crosswalks.add(
          buildCrosswalk(
            domain: 'food',
            conceptId: conceptId,
            variantId: variantId,
            externalIdSystem: 'USDA NDB number',
            externalIdValue: ndbNumber,
            jurisdiction: 'US',
            sourceDocId: sourceDocId,
            confidence: 0.9,
            mappingPayload: {
              'fdc_id': fdcId,
              ...ImporterAudit.confidenceReason(
                sourceIdentifierType:
                    ImporterAudit.sourceIdTypeAuthoritativeFoodCode,
                reason: 'NDB number copied from FDC food object when present.',
                promotedFields: const ['ndbNumber'],
                nonPromotedFields: const ['foodPortions'],
              ),
            },
          ),
        );
      }
      final foodCode = '${food['foodCode'] ?? ''}'.trim();
      if (foodCode.isNotEmpty) {
        crosswalks.add(
          buildCrosswalk(
            domain: 'food',
            conceptId: conceptId,
            variantId: variantId,
            externalIdSystem: 'USDA Survey food code',
            externalIdValue: foodCode,
            jurisdiction: 'US',
            sourceDocId: sourceDocId,
            confidence: 0.9,
            mappingPayload: {
              'fdc_id': fdcId,
              ...ImporterAudit.confidenceReason(
                sourceIdentifierType:
                    ImporterAudit.sourceIdTypeAuthoritativeFoodCode,
                reason:
                    'Survey food code copied from FDC food object when present.',
                promotedFields: const ['foodCode'],
                nonPromotedFields: const ['foodPortions'],
              ),
            },
          ),
        );
      }

      projectedFoods.add(
        FoodItem(
          id: 'food_fdc_$fdcId',
          name: description,
          category: inferFoodCategory('${food['foodCategory'] ?? 'other'}'),
          aliases: [description],
          description: 'FDC imported food variant ($dataType)',
          sourceSystem: dataType,
          sourceFoodCode: fdcId,
          jurisdiction: 'US',
          textureClass: textureClass,
          iddsiLevel: inferIddsiLevelFromTextureClass(textureClass),
          proteinG: displayValueFromRaw(nutrientMap['protein_g'] ?? 'ND'),
          carbsG: displayValueFromRaw(nutrientMap['carbohydrate_g'] ?? 'ND'),
          fatG: displayValueFromRaw(nutrientMap['fat_g'] ?? 'ND'),
          fiberG: displayValueFromRaw(nutrientMap['fiber_g'] ?? 'ND'),
          sodiumMg: displayValueFromRaw(nutrientMap['sodium_mg'] ?? 'ND'),
          energyKcal: nutrientMap.containsKey('energy_kcal')
              ? displayValueFromRaw(nutrientMap['energy_kcal']!)
              : null,
          waterG: nutrientMap.containsKey('water_g')
              ? displayValueFromRaw(nutrientMap['water_g']!)
              : null,
          missingNutrientFields: {
            for (final field in const {
              'protein_g': 'proteinG',
              'carbohydrate_g': 'carbsG',
              'fat_g': 'fatG',
              'fiber_g': 'fiberG',
              'sodium_mg': 'sodiumMg',
              'energy_kcal': 'energyKcal',
              'water_g': 'waterG',
            }.entries)
              if (!nutrientMap.containsKey(field.key) ||
                  parseQualifiedValue(nutrientMap[field.key]).qualifierKind !=
                      QualifierKind.exact)
                field.value,
          },
          basisType: sourceBasis.basisType,
          aminoAcidProfile: sourceBasis.supportsEdibleMassPoint
              ? aminoAcidProfile
              : null,
          sourceBasisEvidence: sourceBasis.requiresQualifiedIdentity
              ? sourceBasis.sourceFields
              : null,
          foodPortionEvidence: foodPortionEvidence,
        ),
      );
    }

    final sourceDocument = buildSourceDocumentRecord(
      sourceDocId: sourceDocId,
      sourceFamily: 'FDC',
      organization: 'USDA',
      jurisdiction: 'US',
      docType: 'json_api_or_bulk',
      title: 'FoodData Central import',
      originUrl: P0SourceUrls.fdcApiGuide,
      licenseNote: 'CC0 1.0',
      language: 'en',
      rawPayload: stringifyPayload({
        'source_label': sourceLabel,
        'source_food_objects_sha256': contentSha256,
        'source_archive_metadata': ?sourceArchiveMetadata,
        if (brandedProductDetails.isNotEmpty)
          'branded_product_details': brandedProductDetails,
        if (qualifiedBasisEvidence.isNotEmpty)
          'food_basis_evidence': qualifiedBasisEvidence,
        'food_publication_metadata': [
          for (final food in foods)
            {
              'fdc_id': food['fdcId'],
              'publication_date': food['publicationDate'],
              'data_type': food['dataType'],
              'publication_date_scope':
                  'source_reported_food_publication_string',
              'timezone_inferred': false,
              'effective_date_inferred': false,
              'archive_release_date_inferred': false,
            },
        ],
        'food_conversion_factor_evidence': [
          for (final food in foods)
            {
              'fdc_id': food['fdcId'],
              'source_field': 'nutrientConversionFactors',
              'source_field_present': food.containsKey(
                'nutrientConversionFactors',
              ),
              'source_fields': food['nutrientConversionFactors'],
              'evidence_scope': 'source_reported_conversion_factors',
              'calculation_applied': false,
              'runtime_factor_selection': null,
            },
        ],
        'energy_method_policy': {
          'policy_id': 'fdc_distinct_source_energy_methods_v1',
          'general_nutrient_id': 2047,
          'specific_nutrient_id': 2048,
          'generic_energy_method_selected': false,
          'new_energy_or_protein_calculation_applied': false,
        },
        'nutrient_identity_policy': {
          'policy_id': 'fdc_identifier_consensus_distinct_quantities_v2',
          'supported_source_quantities': fdcNutrientIdentities.length,
          'identifier_disagreement':
              'retain_source_fields_without_numeric_projection',
          'unit_spelling_normalization_only': true,
          'vitamin_equivalence_conversion_applied': false,
          'sugar_quantity_methods_merged': false,
          'new_clinical_thresholds': false,
        },
        'food_count': foods.length,
        'nutrient_statistics_audit': nutrientStatisticsAudit,
        'nutrient_value_audit': nutrientValueAudit,
        'source_nutrient_summaries': sourceNutrientSummaries,
        'food_portions_audit': portionAuditGaps,
      }),
    );

    return P0ImportBundle(
      sourceDocuments: [sourceDocument],
      foodConcepts: foodConcepts,
      foodVariants: foodVariants,
      variantScopes: variantScopes,
      observations: observations,
      resolvedFacts: resolvedFacts,
      conceptVariantCrosswalks: crosswalks,
      projectedFoods: projectedFoods,
    );
  }

  List<Map<String, String>> _loadCsvRows(
    Map<String, String> files,
    String stem,
  ) {
    final match = files.entries.firstWhere((entry) {
      final basename = entry.key
          .toLowerCase()
          .replaceAll('\\', '/')
          .split('/')
          .last;
      return basename == '$stem.csv' || basename == '$stem.txt';
    }, orElse: () => const MapEntry('', ''));
    if (match.key.isEmpty) return const <Map<String, String>>[];
    return ArchiveImportSupport.parseDelimitedRows(match.value);
  }

  String _sourceNutrientLocator(
    String foodId,
    String attribute,
    Map row, {
    required bool sourceEvidenceUnique,
  }) {
    final id = _nonEmptyString(row['id']);
    return id == null
        ? '$foodId:$attribute'
        : '$foodId:$attribute:${sourceEvidenceUnique ? 'summary' : 'unresolved'}:food_nutrient:$id';
  }

  bool _sameSourceNutrientRow(Map left, Map right) {
    final id = _nonEmptyString(left['id']);
    final method = _nestedRecord(left['foodNutrientDerivation']);
    if (id == null ||
        id != _nonEmptyString(right['id']) ||
        _nonEmptyString(method?['code']) == null) {
      return false;
    }
    return _sameSourceFields(left, right);
  }

  bool _sameSourceFields(Object? left, Object? right) {
    if (left is Map && right is Map) {
      return left.length == right.length &&
          left.keys.every(
            (key) =>
                right.containsKey(key) &&
                _sameSourceFields(left[key], right[key]),
          );
    }
    if (left is List && right is List) {
      return left.length == right.length &&
          List.generate(
            left.length,
            (i) => i,
          ).every((i) => _sameSourceFields(left[i], right[i]));
    }
    return left == right;
  }

  Map<String, Object?>? _nestedRecord(Object? value) {
    if (value is! Map) return null;
    return <String, Object?>{
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }

  String? _nonEmptyString(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  double? _nullableDouble(Object? value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse('${value ?? ''}'.trim());
    return number != null && number.isFinite ? number : null;
  }

  int? _nullableInt(Object? value) {
    if (value is int) return value;
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      return value.toInt();
    }
    return int.tryParse('${value ?? ''}'.trim());
  }

  String? _attributeCodeFromFdcNutrient({
    Object? nutrientId,
    required String nutrientNumber,
    required String nutrientName,
  }) => fdcNutrientAttributeCode(
    nutrientId: nutrientId,
    nutrientNumber: nutrientNumber,
    nutrientName: nutrientName,
  );

  bool _isAtwaterIdentity(Map nutrient) =>
      const {'2047', '2048'}.contains(_nonEmptyString(nutrient['id'])) ||
      const {'957', '958'}.contains('${nutrient['number'] ?? ''}'.trim());

  String _expectedNutrientUnit(String attribute) =>
      attribute.endsWith('_kcal') ? 'kcal' : unitForAttributeCode(attribute);

  List<Map<String, dynamic>> _csvConversionFactors(
    String foodId,
    List<Map<String, String>> parents,
    List<Map<String, String>> calorieRows,
    List<Map<String, String>> proteinRows,
    List<Map<String, String>> fatRows,
  ) {
    final result = <Map<String, dynamic>>[];
    for (final parent in parents.where((row) => row['fdc_id'] == foodId)) {
      final id = (parent['id'] ?? '').trim();
      final owners = parents
          .where((row) => row['id'] == id)
          .map((row) => row['fdc_id'])
          .toSet();
      for (final table in [
        ('.CalorieConversionFactor', calorieRows),
        ('.ProteinConversionFactor', proteinRows),
        ('.FatConversionFactor', fatRows),
      ]) {
        for (final factor in table.$2.where(
          (row) => row['food_nutrient_conversion_factor_id'] == id,
        )) {
          final held = id.isEmpty || owners.length != 1;
          result.add({
            'type': table.$1,
            'source_parent_fields': parent,
            'source_factor_fields': factor,
            'join_status': held ? 'hold_ambiguous_food_owner' : 'source_joined',
            if (!held) ...{
              if (table.$1 == '.CalorieConversionFactor') ...{
                'proteinValue': factor['protein_value'],
                'fatValue': factor['fat_value'],
                'carbohydrateValue': factor['carbohydrate_value'],
              },
              if (table.$1 == '.ProteinConversionFactor')
                'value': factor['value'],
              if (table.$1 == '.FatConversionFactor')
                'fatNleaValue': factor['fat_nlea_value'],
            },
          });
        }
      }
    }
    return result;
  }
}
