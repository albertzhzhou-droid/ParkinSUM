import 'dart:convert';

import '../../../core/models/food_item.dart';
import '../../../core/utils/texture_support.dart';
import '../../../core/utils/qualified_value_parser.dart';
import '../../../domain/entities/cdss_records.dart';
import 'amino_acid_extractor.dart';
import 'archive_import_support.dart';
import 'crosswalk_builders.dart';
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
    final aminoAcidExtractor = AminoAcidExtractor();

    for (final food in foods) {
      final fdcId = '${food['fdcId'] ?? ''}'.trim();
      final description = '${food['description'] ?? ''}'.trim();
      if (fdcId.isEmpty || description.isEmpty) continue;
      final dataType = '${food['dataType'] ?? 'FDC'}';
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
        final attributeCode = _attributeCodeFromFdcNutrient(
          nutrientNumber: '${nutrient['number'] ?? ''}',
          nutrientName: '${nutrient['name'] ?? ''}',
        );
        if (attributeCode == null) {
          continue;
        }
        final amount = map['amount'];
        if (amount == null) {
          continue;
        }
        final rawValue = '$amount';
        if (attributeCode == 'fiber_g' && nutrientMap.containsKey('fiber_g')) {
          // Keep the first total-fibre method (291 precedes AOAC 2011.25).
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
          unit:
              '${nutrient['unitName'] ?? unitForAttributeCode(attributeCode)}',
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
              unit:
                  '${nutrient['unitName'] ?? unitForAttributeCode(attributeCode)}',
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
          proteinG: displayValueFromRaw(nutrientMap['protein_g'] ?? '0'),
          carbsG: displayValueFromRaw(nutrientMap['carbohydrate_g'] ?? '0'),
          fatG: displayValueFromRaw(nutrientMap['fat_g'] ?? '0'),
          fiberG: displayValueFromRaw(nutrientMap['fiber_g'] ?? '0'),
          sodiumMg: displayValueFromRaw(nutrientMap['sodium_mg'] ?? '0'),
          // Absent source fields are unknown, not zero.
          missingNutrientFields: {
            if (!nutrientMap.containsKey('protein_g')) 'proteinG',
            if (!nutrientMap.containsKey('carbohydrate_g')) 'carbsG',
            if (!nutrientMap.containsKey('fat_g')) 'fatG',
            if (!nutrientMap.containsKey('fiber_g')) 'fiberG',
            if (!nutrientMap.containsKey('sodium_mg')) 'sodiumMg',
            'energyKcal',
            'waterG',
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
      final lower = entry.key.toLowerCase();
      return lower.endsWith('/$stem.csv') ||
          lower.endsWith('\\$stem.csv') ||
          lower.endsWith('$stem.csv') ||
          lower.endsWith('/$stem.txt') ||
          lower.endsWith('\\$stem.txt') ||
          lower.endsWith('$stem.txt');
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

  String? _attributeCodeFromFdcNutrient({
    required String nutrientNumber,
    required String nutrientName,
  }) {
    final number = nutrientNumber.trim();
    final lower = nutrientName.toLowerCase();
    if (number == '203' || lower == 'protein') return 'protein_g';
    // Carbohydrate definitions differ. FDC 205/1005 "by difference" includes
    // dietary fibre; the local catalog's `carbohydrate_g` is available
    // carbohydrate (CIQUAL "Glucides"), matched by FDC 1050 "by summation".
    // Storing both under one code double-counts fibre across sources, so the
    // by-difference value keeps its own code and any other carbohydrate
    // definition stays unmapped rather than guessed.
    if (number == '205' ||
        number == '1005' ||
        lower == 'carbohydrate, by difference') {
      return 'carbohydrate_by_difference_g';
    }
    if (number == '1050' || lower == 'carbohydrate, by summation') {
      return 'carbohydrate_g';
    }
    if (lower.contains('carbohydrate')) return null;
    if (number == '204' || lower == 'total lipid (fat)') return 'fat_g';
    // Total dietary fibre only; soluble/insoluble fractions are not totals.
    if (number == '291' ||
        lower == 'fiber, total dietary' ||
        lower.startsWith('total dietary fiber')) {
      return 'fiber_g';
    }
    if (number == '307' || lower == 'sodium, na') return 'sodium_mg';
    if (number == '303' || lower == 'iron, fe') return 'iron_mg';
    if (number == '306' || lower == 'potassium, k') return 'potassium_mg';
    return null;
  }
}
