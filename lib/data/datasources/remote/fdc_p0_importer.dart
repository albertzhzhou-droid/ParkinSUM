import 'dart:convert';

import '../../../core/models/food_item.dart';
import '../../../core/utils/texture_support.dart';
import '../../../core/utils/qualified_value_parser.dart';
import '../../../domain/entities/cdss_records.dart';
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
    final url = '${P0SourceUrls.fdcFoodDetail}/$fdcId?api_key=$apiKey';
    final json = await fetchClient.getJsonMap(url);
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
            final nutrientId =
                (item['nutrient_id'] ?? item['id'] ?? '').toString();
            final nutrient =
                nutrientById[nutrientId] ?? const <String, String>{};
            return <String, dynamic>{
              'amount': item['amount'],
              'nutrient': {
                'number': (nutrient['number'] ?? '').toString(),
                'name': (nutrient['name'] ?? '').toString(),
                'unitName':
                    (nutrient['unit_name'] ?? nutrient['unitName'] ?? '')
                        .toString(),
              },
            };
          }).toList(growable: false);
          return <String, dynamic>{
            'fdcId': fdcId,
            'description': (row['description'] ?? '').toString(),
            'dataType':
                (row['data_type'] ?? row['dataType'] ?? 'FDC').toString(),
            'foodCategory': categoryById[categoryId] ??
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
        nutrientMap[attributeCode] = rawValue;
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
          methodCode: null,
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
      }

      final foodPortions = food['foodPortions'];
      if (foodPortions is List && foodPortions.isNotEmpty) {
        final summarized = <Map<String, dynamic>>[];
        final fieldNamesObserved = <String>{};
        var unparsed = 0;
        for (final raw in foodPortions) {
          if (raw is! Map) {
            unparsed += 1;
            continue;
          }
          for (final key in raw.keys) {
            fieldNamesObserved.add(key.toString());
          }
          final amount = raw['amount'];
          final modifier = raw['modifier'] ??
              raw['portionDescription'] ??
              raw['description'];
          final gramWeight = raw['gramWeight'];
          if (amount == null && modifier == null && gramWeight == null) {
            unparsed += 1;
            continue;
          }
          summarized.add({
            if (amount != null) 'amount': amount,
            if (modifier != null) 'modifier': modifier.toString(),
            if (gramWeight != null) 'gram_weight': gramWeight,
            if (raw['measureUnit'] is Map &&
                (raw['measureUnit'] as Map)['name'] != null)
              'measure_unit': (raw['measureUnit'] as Map)['name'],
          });
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
                'foodPortions kept in raw_payload only; no structured portion table is implemented downstream.',
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
      Map<String, String> files, String stem) {
    final match = files.entries.firstWhere(
      (entry) {
        final lower = entry.key.toLowerCase();
        return lower.endsWith('/$stem.csv') ||
            lower.endsWith('\\$stem.csv') ||
            lower.endsWith('$stem.csv') ||
            lower.endsWith('/$stem.txt') ||
            lower.endsWith('\\$stem.txt') ||
            lower.endsWith('$stem.txt');
      },
      orElse: () => const MapEntry('', ''),
    );
    if (match.key.isEmpty) return const <Map<String, String>>[];
    return ArchiveImportSupport.parseDelimitedRows(match.value);
  }

  String? _attributeCodeFromFdcNutrient({
    required String nutrientNumber,
    required String nutrientName,
  }) {
    final number = nutrientNumber.trim();
    final lower = nutrientName.toLowerCase();
    if (number == '203' || lower == 'protein') return 'protein_g';
    if (number == '205' || lower.contains('carbohydrate')) {
      return 'carbohydrate_g';
    }
    if (number == '204' || lower == 'total lipid (fat)') return 'fat_g';
    if (number == '291' || lower.contains('fiber')) return 'fiber_g';
    if (number == '307' || lower == 'sodium, na') return 'sodium_mg';
    if (number == '303' || lower == 'iron, fe') return 'iron_mg';
    if (number == '306' || lower == 'potassium, k') return 'potassium_mg';
    return null;
  }
}
