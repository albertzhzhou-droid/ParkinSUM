import 'dart:convert';

import '../../../core/models/food_item.dart';
import '../../../core/utils/texture_support.dart';
import '../../../core/utils/qualified_value_parser.dart';
import '../../../domain/entities/cdss_records.dart';
import '../../../domain/usecases/food_composition_interdependency_model.dart';
import 'amino_acid_extractor.dart';
import 'archive_import_support.dart';
import 'crosswalk_builders.dart';
import 'fdc_nutrient_definitions.dart';
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
/// Current FDC releases (checked against the 2025-04-24 full download):
/// - Nutrients are resolved by FDC nutrient id, then legacy number, then
///   exact name, and only when the unit matches ([fdcNutrientDefinitions]).
/// - Foundation Foods energy (2047/2048), nitrogen-to-protein and
///   food-specific calorie conversion factors are retained, and every food's
///   definitional nutrient identities are audited
///   ([auditCompositionIdentities]). Findings are recorded, never "fixed".
/// - Branded Foods keep their GTIN/UPC, brand owner, ingredient statement and
///   per-serving label nutrients (as label evidence, never as per-100 g
///   facts). Ingredient statements are scanned for food-borne L-dopa sources.
/// - Survey (FNDDS) foods keep their WWEIA food category.
/// - Laboratory sample, sub-sample, acquisition and experimental records are
///   not foods and are excluded with an audit entry.
///
/// 未完成：
/// - 还没有处理 `foodPortions` 到独立 portion 表。
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
      final foods = decoded is List<dynamic>
          ? decoded.cast<Map<String, dynamic>>()
          : (decoded['FoundationFoods'] as List<dynamic>? ??
                    decoded['foods'] as List<dynamic>? ??
                    const <dynamic>[])
                .cast<Map<String, dynamic>>();
      return importFoods(foods, sourceLabel: sourceLabel);
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
    final conversionFactorRows = _loadCsvRows(
      files,
      'food_nutrient_conversion_factor',
    );
    final proteinFactorRows = _loadCsvRows(
      files,
      'food_protein_conversion_factor',
    );
    final calorieFactorRows = _loadCsvRows(
      files,
      'food_calorie_conversion_factor',
    );
    final brandedRows = _loadCsvRows(files, 'branded_food');
    final surveyRows = _loadCsvRows(files, 'survey_fndds_food');
    final wweiaRows = _loadCsvRows(files, 'wweia_food_category');
    final ndbRows = [
      ..._loadCsvRows(files, 'foundation_food'),
      ..._loadCsvRows(files, 'sr_legacy_food'),
    ];

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

    // Conversion factors: food_nutrient_conversion_factor maps a factor id to
    // an fdc_id; the protein and calorie tables carry the values.
    final factorFoodById = {
      for (final row in conversionFactorRows)
        (row['id'] ?? '').trim(): (row['fdc_id'] ?? '').trim(),
    };
    final conversionFactorsByFood = <String, List<Map<String, Object?>>>{};
    for (final row in proteinFactorRows) {
      final fdcId =
          factorFoodById[(row['food_nutrient_conversion_factor_id'] ?? '')
              .trim()];
      if (fdcId == null || fdcId.isEmpty) continue;
      conversionFactorsByFood.putIfAbsent(fdcId, () => []).add({
        'type': '.ProteinConversionFactor',
        'value': row['value'],
      });
    }
    for (final row in calorieFactorRows) {
      final fdcId =
          factorFoodById[(row['food_nutrient_conversion_factor_id'] ?? '')
              .trim()];
      if (fdcId == null || fdcId.isEmpty) continue;
      conversionFactorsByFood.putIfAbsent(fdcId, () => []).add({
        'type': '.CalorieConversionFactor',
        'proteinValue': row['protein_value'],
        'fatValue': row['fat_value'],
        'carbohydrateValue': row['carbohydrate_value'],
      });
    }

    final brandedByFood = {
      for (final row in brandedRows) (row['fdc_id'] ?? '').trim(): row,
    };
    final wweiaDescriptionByCode = {
      for (final row in wweiaRows)
        (row['wweia_food_category'] ?? '').trim():
            (row['wweia_food_category_description'] ?? '').trim(),
    };
    final surveyByFood = {
      for (final row in surveyRows) (row['fdc_id'] ?? '').trim(): row,
    };
    final ndbByFood = {
      for (final row in ndbRows)
        (row['fdc_id'] ?? '').trim(): (row['NDB_number'] ?? row['ndb_number'])
            ?.trim(),
    };

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
                    final sourceId = (item['food_nutrient_source_id'] ?? '')
                        .trim();
                    final nutrientSource =
                        nutrientSourceById[sourceId] ??
                        const <String, String>{};
                    return <String, dynamic>{
                      'amount': item['amount'],
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
                        // The official nutrient.csv names this column
                        // `nutrient_nbr`; older extracts use `number`.
                        'number':
                            (nutrient['nutrient_nbr'] ??
                                    nutrient['number'] ??
                                    '')
                                .toString(),
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
          final branded = brandedByFood[fdcId];
          final survey = surveyByFood[fdcId];
          final wweiaCode = (survey?['wweia_category_code'] ?? '').trim();
          final ndbNumber = ndbByFood[fdcId];
          return <String, dynamic>{
            'fdcId': fdcId,
            'description': (row['description'] ?? '').toString(),
            'dataType': (row['data_type'] ?? row['dataType'] ?? 'FDC')
                .toString(),
            // Branded rows carry the category text itself in
            // food_category_id.
            'foodCategory':
                categoryById[categoryId] ??
                (branded?['branded_food_category']?.trim().isNotEmpty == true
                    ? branded!['branded_food_category']!.trim()
                    : null) ??
                (categoryId.isNotEmpty && int.tryParse(categoryId) == null
                    ? categoryId
                    : null) ??
                (row['food_class'] ?? 'other').toString(),
            'foodNutrients': nutrients,
            'nutrientConversionFactors': ?conversionFactorsByFood[fdcId],
            if (ndbNumber != null && ndbNumber.isNotEmpty)
              'ndbNumber': ndbNumber,
            if (branded != null) ...{
              'brandOwner': branded['brand_owner'],
              'brandName': branded['brand_name'],
              'gtinUpc': branded['gtin_upc'],
              'ingredients': branded['ingredients'],
              'servingSize': branded['serving_size'],
              'servingSizeUnit': branded['serving_size_unit'],
              'householdServingFullText': branded['household_serving_fulltext'],
              'brandedFoodCategory': branded['branded_food_category'],
              'marketCountry': branded['market_country'],
              'discontinuedDate': branded['discontinued_date'],
            },
            if (survey != null) ...{
              'foodCode': survey['food_code'],
              if (wweiaCode.isNotEmpty)
                'wweiaFoodCategory': {
                  'wweiaFoodCategoryCode': wweiaCode,
                  'wweiaFoodCategoryDescription':
                      wweiaDescriptionByCode[wweiaCode],
                },
            },
          };
        })
        .where((row) => row['fdcId'].toString().isNotEmpty)
        .toList(growable: false);

    return importFoods(foods, sourceLabel: sourceLabel);
  }

  P0ImportBundle importFoods(
    List<Map<String, dynamic>> foods, {
    required String sourceLabel,
  }) {
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'FDC',
      externalKey: sourceLabel,
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
    final unitMismatchAudit = <Map<String, Object?>>[];
    final duplicateNutrientAudit = <Map<String, Object?>>[];
    final unmappedNutrientCounts = <String, int>{};
    final excludedRecords = <Map<String, Object?>>[];
    final conversionFactorAudit = <Map<String, Object?>>[];
    final compositionIdentityAudit = <Map<String, Object?>>[];
    final labelNutrientAudit = <Map<String, Object?>>[];
    final intrinsicLevodopaIngredientAudit = <Map<String, Object?>>[];
    final aminoAcidExtractor = AminoAcidExtractor();

    for (final food in foods) {
      final fdcId = '${food['fdcId'] ?? ''}'.trim();
      final description = '${food['description'] ?? ''}'.trim();
      if (fdcId.isEmpty || description.isEmpty) continue;
      final rawDataType = '${food['dataType'] ?? 'FDC'}'.trim();
      if (nonFoodDataTypes.contains(rawDataType.toLowerCase())) {
        excludedRecords.add({
          'fdc_id': fdcId,
          'data_type': rawDataType,
          'reason':
              'Laboratory sample, acquisition or experimental record; not a '
              'consumable food.',
        });
        continue;
      }
      final dataType =
          _canonicalDataTypes[rawDataType.toLowerCase()] ?? rawDataType;
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
      for (final nutrientRow
          in (food['foodNutrients'] as List<dynamic>? ?? const [])) {
        final map = nutrientRow as Map<String, dynamic>;
        final nutrient = (map['nutrient'] as Map<String, dynamic>?) ?? map;
        final resolution = _resolveNutrient(nutrient, map);
        if (!resolution.isMapped) {
          if (resolution.status == FdcNutrientResolutionStatus.unitMismatch) {
            unitMismatchAudit.add({
              'fdc_id': fdcId,
              'nutrient_id': resolution.definition!.id,
              'expected_unit': resolution.definition!.unitName,
              'observed_unit': resolution.observedUnit,
            });
          } else {
            final key =
                _nonEmptyString(nutrient['id'] ?? map['nutrientId']) ??
                _nonEmptyString(nutrient['number'] ?? map['nutrientNumber']) ??
                'name:${nutrient['name'] ?? map['nutrientName'] ?? ''}';
            unmappedNutrientCounts[key] =
                (unmappedNutrientCounts[key] ?? 0) + 1;
          }
          continue;
        }
        final definition = resolution.definition!;
        final attributeCode = definition.attributeCode;
        final amount = map['amount'] ?? map['value'];
        if (amount == null) {
          continue;
        }
        final rawValue = '$amount';
        if (nutrientMap.containsKey(attributeCode)) {
          // The same FDC nutrient twice: keep the first value, record the
          // second, and never let a later row silently replace it.
          duplicateNutrientAudit.add({
            'fdc_id': fdcId,
            'attribute_code': attributeCode,
            'kept': nutrientMap[attributeCode],
            'ignored': rawValue,
          });
          continue;
        }
        nutrientMap[attributeCode] = rawValue;
        final derivation = _nestedRecord(map['foodNutrientDerivation']);
        final nutrientSource = _nestedRecord(map['foodNutrientSource']);
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
            ? 'obs_${stableHash('$variantId:$attributeCode:fdc_source_range:$rangeRawValueText')}'
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
              'obs_${stableHash('$variantId:$attributeCode:$rawValue')}',
          domain: 'food',
          entityType: 'food_variant',
          entityKey: variantId,
          attributeCode: attributeCode,
          valueType: 'numeric_interval',
          value: parseQualifiedValue(rawValue),
          unit: definition.canonicalUnit,
          basisType: 'per_100g_edible_part',
          basisAmount: 100,
          scopeHash: scopeHash,
          sourceDocId: sourceDocId,
          recordLocator: '$fdcId:$attributeCode',
          methodCode: methodCode,
          extractionConfidence: 1,
        );
        observations.add(observation);
        resolvedFacts.add(
          resolvedFactFromObservation(
            observation: observation,
            policyId: 'fdc_import_v1',
            snapshotId: 'facts_fdc_import_v1',
          ),
        );
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
              unit: definition.canonicalUnit,
              basisType: 'per_100g_edible_part',
              basisAmount: 100,
              scopeHash: scopeHash,
              sourceDocId: sourceDocId,
              recordLocator: '$fdcId:$attributeCode:sample_range',
              methodCode: methodCode,
              extractionConfidence: 1,
            ),
          );
        }
      }

      // Values exactly as the source reported them, before any derivation.
      final sourceNutrientMap = Map<String, String>.unmodifiable(nutrientMap);

      void addDerivedObservation({
        required String attributeCode,
        required String rawValue,
        required String unit,
        required String methodCode,
      }) {
        nutrientMap[attributeCode] = rawValue;
        final derived = ObservationRecord(
          observationId:
              'obs_${stableHash('$variantId:$attributeCode:derived:$rawValue')}',
          domain: 'food',
          entityType: 'food_variant',
          entityKey: variantId,
          attributeCode: attributeCode,
          valueType: 'numeric_interval',
          value: parseQualifiedValue(rawValue),
          unit: unit,
          basisType: 'per_100g_edible_part',
          basisAmount: 100,
          scopeHash: scopeHash,
          sourceDocId: sourceDocId,
          recordLocator: '$fdcId:$attributeCode:derived',
          methodCode: methodCode,
          extractionConfidence: 1,
        );
        observations.add(derived);
        resolvedFacts.add(
          resolvedFactFromObservation(
            observation: derived,
            policyId: 'fdc_import_v1',
            snapshotId: 'facts_fdc_import_v1',
          ),
        );
      }

      // Foundation Foods report energy as 2048 (food-specific Atwater
      // factors) and 2047 (general factors) instead of 1008. The catalog's
      // energy field takes 2048, else 2047, with the choice method-coded.
      if (!nutrientMap.containsKey('energy_kcal')) {
        for (final (code, method) in const [
          ('energy_atwater_specific_kcal', derivedEnergyFromSpecificMethodCode),
          ('energy_atwater_general_kcal', derivedEnergyFromGeneralMethodCode),
        ]) {
          final raw = nutrientMap[code];
          final value = parseQualifiedValue(raw ?? '');
          if (raw != null && value.qualifierKind == QualifierKind.exact) {
            addDerivedObservation(
              attributeCode: 'energy_kcal',
              rawValue: raw,
              unit: 'kcal',
              methodCode: method,
            );
            break;
          }
        }
      }
      // Total dietary fibre by AOAC 2011.25 stands in for the catalog's
      // fibre field only when no AOAC 985.29-family total is reported.
      if (!nutrientMap.containsKey('fiber_g')) {
        final raw = nutrientMap['fiber_aoac_2011_25_g'];
        if (raw != null &&
            parseQualifiedValue(raw).qualifierKind == QualifierKind.exact) {
          addDerivedObservation(
            attributeCode: 'fiber_g',
            rawValue: raw,
            unit: 'g',
            methodCode: derivedFiberFromAoac201125MethodCode,
          );
        }
      }

      // Derive available carbohydrate (by difference − total fibre) only when
      // the source gave no by-summation value and both terms are exact
      // numbers. The derivation is recorded as such; missing fibre is never
      // assumed to be zero.
      if (!nutrientMap.containsKey('carbohydrate_g')) {
        final byDifference = parseQualifiedValue(
          nutrientMap['carbohydrate_by_difference_g'] ?? '',
        );
        final fiber = parseQualifiedValue(nutrientMap['fiber_g'] ?? '');
        final carbValue = byDifference.valueNum;
        final fiberValue = fiber.valueNum;
        if (byDifference.qualifierKind == QualifierKind.exact &&
            fiber.qualifierKind == QualifierKind.exact &&
            carbValue != null &&
            fiberValue != null &&
            carbValue.isFinite &&
            fiberValue.isFinite &&
            carbValue >= 0 &&
            fiberValue >= 0 &&
            carbValue - fiberValue >= -0.05) {
          final available = carbValue - fiberValue < 0
              ? 0.0
              : carbValue - fiberValue;
          final rawValue = _roundedDecimal(available);
          nutrientMap['carbohydrate_g'] = rawValue;
          final derived = ObservationRecord(
            observationId:
                'obs_${stableHash('$variantId:carbohydrate_g:derived:$rawValue')}',
            domain: 'food',
            entityType: 'food_variant',
            entityKey: variantId,
            attributeCode: 'carbohydrate_g',
            valueType: 'numeric_interval',
            value: parseQualifiedValue(rawValue),
            unit: 'g',
            basisType: 'per_100g_edible_part',
            basisAmount: 100,
            scopeHash: scopeHash,
            sourceDocId: sourceDocId,
            recordLocator: '$fdcId:carbohydrate_g:derived',
            methodCode: derivedAvailableCarbohydrateMethodCode,
            extractionConfidence: 1,
          );
          observations.add(derived);
          resolvedFacts.add(
            resolvedFactFromObservation(
              observation: derived,
              policyId: 'fdc_import_v1',
              snapshotId: 'facts_fdc_import_v1',
            ),
          );
        }
      }

      // Nitrogen-to-protein and food-specific calorie conversion factors.
      final factors = _conversionFactors(food['nutrientConversionFactors']);
      for (final invalid in factors.invalid) {
        conversionFactorAudit.add({'fdc_id': fdcId, ...invalid});
      }
      void addFactorObservation(String code, double value, String unit) {
        observations.add(
          ObservationRecord(
            observationId: 'obs_${stableHash('$variantId:$code:$value')}',
            domain: 'food',
            entityType: 'food_variant',
            entityKey: variantId,
            attributeCode: code,
            valueType: 'numeric_interval',
            value: parseQualifiedValue('$value'),
            unit: unit,
            basisType: 'food_specific_conversion_factor',
            basisAmount: null,
            scopeHash: scopeHash,
            sourceDocId: sourceDocId,
            recordLocator: '$fdcId:$code',
            methodCode: 'fdc:nutrient_conversion_factor',
            extractionConfidence: 1,
          ),
        );
      }

      final proteinFactor = factors.nitrogenToProtein;
      if (proteinFactor != null) {
        addFactorObservation(
          'nitrogen_to_protein_factor',
          proteinFactor,
          'g protein/g N',
        );
      }
      final calorieFactors = factors.calorie;
      if (calorieFactors != null) {
        for (final (code, value) in [
          ('calorie_factor_protein_kcal_per_g', calorieFactors.proteinKcalPerG),
          ('calorie_factor_fat_kcal_per_g', calorieFactors.fatKcalPerG),
          (
            'calorie_factor_carbohydrate_kcal_per_g',
            calorieFactors.carbohydrateKcalPerG,
          ),
        ]) {
          if (value != null) addFactorObservation(code, value, 'kcal/g');
        }
      }

      // Definitional identities among the source-reported values.
      final exactSourceValues = <String, double>{};
      for (final entry in sourceNutrientMap.entries) {
        final value = parseQualifiedValue(entry.value);
        final number = value.valueNum;
        if (value.qualifierKind == QualifierKind.exact &&
            number != null &&
            number.isFinite &&
            number >= 0) {
          exactSourceValues[entry.key] = number;
        }
      }
      final identityAudit = auditCompositionIdentities(
        FoodCompositionIdentityInput(
          recordId: fdcId,
          description: description,
          values: exactSourceValues,
          nitrogenToProteinFactor: proteinFactor,
          calorieFactors: calorieFactors,
        ),
      );
      if (identityAudit.checksRun.isNotEmpty) {
        compositionIdentityAudit.add({
          'fdc_id': fdcId,
          'data_type': dataType,
          'checks_run': identityAudit.checksRun,
          'findings': [
            for (final finding in identityAudit.findings) finding.toJson(),
          ],
        });
      }

      // Branded Foods: label evidence, product code and ingredients.
      final gtinUpc = _nonEmptyString(food['gtinUpc']);
      final brandOwner = _nonEmptyString(food['brandOwner']);
      final brandName = _nonEmptyString(food['brandName']);
      final ingredients = _nonEmptyString(food['ingredients']);
      final labelNutrients = food['labelNutrients'];
      if (labelNutrients is Map) {
        final servingSize = _nullableDouble(food['servingSize']);
        final servingUnit = _nonEmptyString(food['servingSizeUnit']);
        final comparisons = <Map<String, Object?>>[];
        for (final entry in labelNutrients.entries) {
          final mapping = _labelNutrientCodes[entry.key.toString()];
          final rawNode = entry.value;
          final labelValue = _nullableDouble(
            rawNode is Map ? rawNode['value'] : rawNode,
          );
          if (mapping == null || labelValue == null) continue;
          final (code, unit) = mapping;
          // Per-serving label values are evidence only: no resolved fact,
          // so they can never be read as per-100 g composition.
          observations.add(
            ObservationRecord(
              observationId:
                  'obs_${stableHash('$variantId:$code:label:$labelValue')}',
              domain: 'food',
              entityType: 'food_variant',
              entityKey: variantId,
              attributeCode: code,
              valueType: 'numeric_interval',
              value: parseQualifiedValue('$labelValue'),
              unit: unit,
              basisType: 'per_serving_label',
              basisAmount: servingSize,
              scopeHash: scopeHash,
              sourceDocId: sourceDocId,
              recordLocator: '$fdcId:label:${entry.key}',
              methodCode: 'fdc:label_nutrients',
              extractionConfidence: 1,
            ),
          );
          final per100 = exactSourceValues[code];
          if (per100 != null &&
              servingSize != null &&
              servingSize > 0 &&
              (servingUnit?.toLowerCase() == 'g' ||
                  servingUnit?.toLowerCase() == 'grm')) {
            comparisons.add({
              'attribute_code': code,
              'label_per_serving': labelValue,
              'per_100g_scaled_to_serving': per100 * servingSize / 100.0,
            });
          }
        }
        labelNutrientAudit.add({
          'fdc_id': fdcId,
          'serving_size': servingSize,
          'serving_size_unit': servingUnit,
          'household_serving': _nonEmptyString(
            food['householdServingFullText'],
          ),
          'label_vs_per_100g': comparisons,
          'note':
              'Label values follow FDA rounding rules, so small differences '
              'from scaled per-100 g values are expected and are not errors.',
        });
      }
      if (ingredients != null) {
        final matched = <String>{};
        for (final part in ingredients.split(RegExp(r'[,;()\[\]]'))) {
          final match = matchIntrinsicLevodopaSource(name: part.trim());
          if (match != null) matched.add(match.source.id);
        }
        if (matched.isNotEmpty) {
          intrinsicLevodopaIngredientAudit.add({
            'fdc_id': fdcId,
            'intrinsic_levodopa_source_ids': matched.toList()..sort(),
            'note':
                'The ingredient statement names a plant that contains '
                'L-dopa. The amount per serving is not known from the label.',
          });
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

      if (gtinUpc != null) {
        crosswalks.add(
          buildCrosswalk(
            domain: 'food',
            conceptId: conceptId,
            variantId: variantId,
            externalIdSystem: 'GTIN/UPC',
            externalIdValue: gtinUpc,
            jurisdiction: 'US',
            sourceDocId: sourceDocId,
            confidence: 1.0,
            mappingPayload: {
              'fdc_id': fdcId,
              'brand_owner': brandOwner,
              'brand_name': brandName,
              'branded_food_category': _nonEmptyString(
                food['brandedFoodCategory'],
              ),
              'market_country': _nonEmptyString(food['marketCountry']),
              'discontinued_date': _nonEmptyString(food['discontinuedDate']),
              'ingredients': ingredients,
              ...ImporterAudit.confidenceReason(
                sourceIdentifierType:
                    ImporterAudit.sourceIdTypeAuthoritativeProductCode,
                reason:
                    'GTIN/UPC copied verbatim from the FDC Branded Foods record.',
                promotedFields: const ['gtinUpc'],
                nonPromotedFields: const ['labelNutrients', 'ingredients'],
              ),
            },
          ),
        );
      }
      final wweia = food['wweiaFoodCategory'];
      if (wweia is Map) {
        final code = _nonEmptyString(
          wweia['wweiaFoodCategoryCode'] ?? wweia['wweiaFoodCategory'],
        );
        if (code != null) {
          crosswalks.add(
            buildCrosswalk(
              domain: 'food',
              conceptId: conceptId,
              variantId: variantId,
              externalIdSystem: 'USDA WWEIA food category',
              externalIdValue: code,
              jurisdiction: 'US',
              sourceDocId: sourceDocId,
              confidence: 0.9,
              mappingPayload: {
                'fdc_id': fdcId,
                'description': _nonEmptyString(
                  wweia['wweiaFoodCategoryDescription'],
                ),
                ...ImporterAudit.confidenceReason(
                  sourceIdentifierType:
                      ImporterAudit.sourceIdTypeMetadataAttribute,
                  reason:
                      'WWEIA category copied from the FDC Survey (FNDDS) record.',
                  promotedFields: const ['wweiaFoodCategory'],
                  nonPromotedFields: const ['inputFoods'],
                ),
              },
            ),
          );
        }
      }

      final energyRaw = nutrientMap['energy_kcal'];
      final waterRaw = nutrientMap['water_g'];
      projectedFoods.add(
        FoodItem(
          id: 'food_fdc_$fdcId',
          name: description,
          category: inferFoodCategory('${food['foodCategory'] ?? 'other'}'),
          aliases: [description, ?brandName, ?brandOwner],
          description: 'FDC imported food variant ($dataType)',
          sourceSystem: dataType,
          sourceFoodCode: fdcId,
          jurisdiction: 'US',
          textureClass: textureClass,
          iddsiLevel: inferIddsiLevelFromTextureClass(textureClass),
          proteinG: displayValueFromRaw(nutrientMap['protein_g'] ?? '0'),
          carbsG: displayValueFromRaw(nutrientMap['carbohydrate_g'] ?? '0'),
          fatG: displayValueFromRaw(nutrientMap['fat_g'] ?? '0'),
          fiberG: displayValueFromRaw(nutrientMap['fiber_g'] ?? '0'),
          sodiumMg: displayValueFromRaw(nutrientMap['sodium_mg'] ?? '0'),
          energyKcal: energyRaw == null ? null : displayValueFromRaw(energyRaw),
          waterG: waterRaw == null ? null : displayValueFromRaw(waterRaw),
          // Absent source fields are unknown, not zero.
          missingNutrientFields: {
            if (!nutrientMap.containsKey('protein_g')) 'proteinG',
            if (!nutrientMap.containsKey('carbohydrate_g')) 'carbsG',
            if (!nutrientMap.containsKey('fat_g')) 'fatG',
            if (!nutrientMap.containsKey('fiber_g')) 'fiberG',
            if (!nutrientMap.containsKey('sodium_mg')) 'sodiumMg',
            if (energyRaw == null) 'energyKcal',
            if (waterRaw == null) 'waterG',
          },
          aminoAcidProfile: aminoAcidProfile,
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
        'food_count': foods.length,
        'nutrient_statistics_audit': nutrientStatisticsAudit,
        'food_portions_audit': portionAuditGaps,
        'nutrient_definitions_release': fdcNutrientDefinitionsRelease,
        'unit_mismatch_audit': unitMismatchAudit,
        'duplicate_nutrient_audit': duplicateNutrientAudit,
        'unmapped_nutrient_counts': unmappedNutrientCounts,
        'excluded_non_food_records': excludedRecords,
        'conversion_factor_audit': conversionFactorAudit,
        'composition_identity_audit': compositionIdentityAudit,
        'label_nutrient_audit': labelNutrientAudit,
        'intrinsic_levodopa_ingredient_audit': intrinsicLevodopaIngredientAudit,
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
    // Match the exact file name: `food.csv` must not match
    // `branded_food.csv`, nor `nutrient.csv` match `food_nutrient.csv`.
    final match = files.entries.firstWhere((entry) {
      final baseName = entry.key.toLowerCase().split(RegExp(r'[\\/]')).last;
      return baseName == '$stem.csv' || baseName == '$stem.txt';
    }, orElse: () => const MapEntry('', ''));
    if (match.key.isEmpty) return const <Map<String, String>>[];
    return ArchiveImportSupport.parseDelimitedRows(match.value);
  }

  /// Method code for available carbohydrate derived from by-difference
  /// carbohydrate minus total dietary fibre.
  static const String derivedAvailableCarbohydrateMethodCode =
      'derived:carbohydrate_by_difference_minus_total_fiber';

  String _roundedDecimal(double value) {
    final rounded = (value * 10000).roundToDouble() / 10000;
    return rounded.toString();
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

  /// Method code for energy taken from FDC 2048 (food-specific factors).
  static const String derivedEnergyFromSpecificMethodCode =
      'derived:energy_kcal_from_fdc_2048_atwater_specific';

  /// Method code for energy taken from FDC 2047 (general factors).
  static const String derivedEnergyFromGeneralMethodCode =
      'derived:energy_kcal_from_fdc_2047_atwater_general';

  /// Method code for total fibre taken from FDC 2033 (AOAC 2011.25).
  static const String derivedFiberFromAoac201125MethodCode =
      'derived:fiber_g_from_fdc_2033_aoac_2011_25';

  /// FDC data types that are laboratory inputs, not consumable foods.
  static const Set<String> nonFoodDataTypes = {
    'sample_food',
    'sub_sample_food',
    'agricultural_acquisition',
    'market_acquisition',
    'experimental_food',
  };

  static const Map<String, String> _canonicalDataTypes = {
    'foundation': 'Foundation',
    'foundation_food': 'Foundation',
    'sr legacy': 'SR Legacy',
    'sr_legacy_food': 'SR Legacy',
    'survey (fndds)': 'Survey (FNDDS)',
    'survey_fndds_food': 'Survey (FNDDS)',
    'branded': 'Branded',
    'branded_food': 'Branded',
  };

  /// FDC `labelNutrients` keys and their per-serving label units.
  static const Map<String, (String, String)> _labelNutrientCodes = {
    'calories': ('energy_kcal', 'kcal'),
    'protein': ('protein_g', 'g'),
    'fat': ('fat_g', 'g'),
    'saturatedFat': ('fatty_acids_saturated_g', 'g'),
    'transFat': ('fatty_acids_trans_g', 'g'),
    'cholesterol': ('cholesterol_mg', 'mg'),
    'sodium': ('sodium_mg', 'mg'),
    // US label "Total Carbohydrate" includes dietary fibre.
    'carbohydrates': ('carbohydrate_by_difference_g', 'g'),
    'fiber': ('fiber_g', 'g'),
    'sugars': ('sugars_total_g', 'g'),
    'addedSugar': ('sugars_added_g', 'g'),
    'calcium': ('calcium_mg', 'mg'),
    'iron': ('iron_mg', 'mg'),
    'potassium': ('potassium_mg', 'mg'),
  };

  FdcNutrientResolution _resolveNutrient(
    Map<String, dynamic> nutrient,
    Map<String, dynamic> row,
  ) {
    final id = _nullableInt(
      nutrient['id'] ?? row['nutrientId'] ?? row['nutrient_id'],
    );
    final number = _nonEmptyString(nutrient['number'] ?? row['nutrientNumber']);
    final name = _nonEmptyString(nutrient['name'] ?? row['nutrientName']);
    final unit = _nonEmptyString(nutrient['unitName'] ?? row['unitName']);
    if (id != null && number != null) {
      final byId = resolveFdcNutrient(id: id, unitName: unit);
      final idDefinition = byId.definition;
      // A local extract may number its nutrient table independently; when
      // the id points at a different nutrient than the number, the number
      // (which is printed on every FDC record) decides.
      if (idDefinition != null && idDefinition.number == number) return byId;
      return resolveFdcNutrient(number: number, name: name, unitName: unit);
    }
    return resolveFdcNutrient(
      id: id,
      number: number,
      name: name,
      unitName: unit,
    );
  }

  ({
    double? nitrogenToProtein,
    FoodSpecificCalorieFactors? calorie,
    List<Map<String, Object?>> invalid,
  })
  _conversionFactors(Object? raw) {
    double? protein;
    FoodSpecificCalorieFactors? calorie;
    final invalid = <Map<String, Object?>>[];
    if (raw is! List) {
      return (nitrogenToProtein: null, calorie: null, invalid: invalid);
    }
    bool plausible(double? value, double low, double high) =>
        value != null && value >= low && value <= high;
    for (final entry in raw) {
      if (entry is! Map) continue;
      final type = '${entry['type'] ?? ''}';
      if (type.contains('ProteinConversionFactor')) {
        final value = _nullableDouble(entry['value']);
        // Published nitrogen-to-protein factors span about 5.18 to 6.38;
        // 0.0 and other out-of-range values are placeholders.
        if (plausible(value, 4.0, 7.0)) {
          protein = value;
        } else {
          invalid.add({'factor': 'nitrogen_to_protein', 'value': value});
        }
      } else if (type.contains('CalorieConversionFactor')) {
        final p = _nullableDouble(entry['proteinValue']);
        final f = _nullableDouble(entry['fatValue']);
        final c = _nullableDouble(entry['carbohydrateValue']);
        final usable =
            (p == null || plausible(p, 1.0, 5.0)) &&
            (f == null || plausible(f, 7.0, 9.5)) &&
            (c == null || plausible(c, 1.0, 4.5));
        if (usable && (p != null || f != null || c != null)) {
          calorie = FoodSpecificCalorieFactors(
            proteinKcalPerG: p,
            fatKcalPerG: f,
            carbohydrateKcalPerG: c,
          );
        } else {
          invalid.add({
            'factor': 'calorie',
            'protein': p,
            'fat': f,
            'carbohydrate': c,
          });
        }
      }
    }
    return (nitrogenToProtein: protein, calorie: calorie, invalid: invalid);
  }
}
