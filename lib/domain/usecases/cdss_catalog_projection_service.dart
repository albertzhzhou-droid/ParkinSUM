import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/utils/qualified_value_parser.dart';
import '../../core/utils/texture_support.dart';
import '../../core/db/cdss_database.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

Map<String, Object?> _queryTableAudit(
  String table,
  String identityField,
  List<Map<String, Object?>> rows,
) {
  String? contentSha256;
  var contentDigestStatus = 'captured';
  try {
    contentSha256 = sha256
        .convert(utf8.encode(_canonicalProjectionAuditJson(rows)))
        .toString();
  } on FormatException {
    contentDigestStatus = 'omitted_unrepresentable_runtime_value';
  }
  final orderedIds = rows
      .map((row) => row[identityField]?.toString())
      .toList(growable: false);
  return <String, Object?>{
    'table': table,
    'operation': 'queryTable($table)',
    'where_predicate': 'none',
    'order_by': 'none',
    'adapter_returned_row_order_preserved': true,
    'identity_field': identityField,
    'row_count': rows.length,
    'ordered_record_ids': orderedIds,
    'unidentified_record_indexes': <int>[
      for (var index = 0; index < orderedIds.length; index++)
        if (orderedIds[index] == null || orderedIds[index]!.isEmpty) index,
    ],
    'rows_sha256': contentSha256,
    'rows_sha256_status': contentDigestStatus,
  };
}

String _canonicalProjectionAuditJson(Object? value) =>
    jsonEncode(_normalizeProjectionAuditValue(value));

Object? _normalizeProjectionAuditValue(Object? value) {
  if (value == null || value is String || value is bool) return value;
  if (value is num) {
    if (!value.isFinite) {
      throw const FormatException(
        'Projection query audit cannot hash a non-finite number.',
      );
    }
    return value;
  }
  if (value is Map) {
    final keys = value.keys.toList(growable: false);
    if (keys.any((key) => key is! String)) {
      throw const FormatException(
        'Projection query audit requires string object keys.',
      );
    }
    final stringKeys = keys.cast<String>()..sort();
    return <String, Object?>{
      for (final key in stringKeys)
        if (key != '_synced_at')
          key: _normalizeProjectionAuditValue(value[key]),
    };
  }
  if (value is Iterable) {
    return value.map(_normalizeProjectionAuditValue).toList(growable: false);
  }
  throw FormatException(
    'Projection query audit cannot hash ${value.runtimeType}.',
  );
}

class CdssFoodProjectionResult {
  final List<FoodItem> foods;
  final Map<String, Object?> queryAudit;

  CdssFoodProjectionResult({
    required List<FoodItem> foods,
    required Map<String, Object?> queryAudit,
  }) : foods = List<FoodItem>.unmodifiable(foods),
       queryAudit = Map<String, Object?>.unmodifiable(queryAudit);
}

/// 把 CDSS 事实库投影回 App 可消费目录。
///
/// 价值：
/// - 下一餐推荐与目录搜索不再只能依赖内置 seed；
/// - 后续 ETL 完成后，可以优先消费真实 variant / observation。
///
/// 未完成：
/// - 当前只做基础营养与剂型投影；
/// - crosswalk 已优先用于 app id 投影；per-jurisdiction 最优 variant 仍由 resolver/runtime 路径处理。
class CdssCatalogProjectionService {
  final CdssDatabase database;

  const CdssCatalogProjectionService({required this.database});

  Future<List<FoodItem>> projectFoods() async =>
      (await projectFoodsWithAudit()).foods;

  /// Projects foods and returns the exact table reads and projection filters
  /// used for this run. Query rows are represented by ordered IDs and digests;
  /// raw payload text is never copied into the audit.
  Future<CdssFoodProjectionResult> projectFoodsWithAudit() async {
    final variants = await database.queryTable('food_variant');
    final concepts = await database.queryTable('food_concept');
    final observations = await database.queryTable('observation');
    final crosswalks = await database.queryTable('concept_variant_crosswalk');
    final sourceDocuments = await database.queryTable('source_document');
    final variantScopes = await database.queryTable('variant_scope');

    final conceptById = {
      for (final row in concepts) '${row['food_concept_id']}': row,
    };
    final nutrientByVariant = <String, Map<String, double>>{};
    final legacyProjectionRowIndexByVariantAndAttribute =
        <String, Map<String, int>>{};
    final appIdByVariant = <String, String>{};
    final selectedCrosswalkIndexByVariant = <String, int>{};
    final foodCrosswalks = <Map<String, Object?>>[];
    for (var index = 0; index < crosswalks.length; index++) {
      final row = crosswalks[index];
      if (row['domain'] != 'food') continue;
      foodCrosswalks.add(row);
      final variantId = '${row['variant_id'] ?? ''}';
      final appId = '${row['app_entity_id'] ?? ''}';
      if (variantId.isNotEmpty && appId.isNotEmpty) {
        appIdByVariant[variantId] = appId;
        selectedCrosswalkIndexByVariant[variantId] = index;
      }
    }

    for (var index = 0; index < observations.length; index++) {
      final row = observations[index];
      final entityKey = '${row['entity_key'] ?? ''}';
      if (entityKey.isEmpty) continue;
      final qualifierKind = '${row['qualifier_kind'] ?? ''}';
      if (qualifierKind != QualifierKind.exact.wireValue) continue;
      final attributeCode = '${row['attribute_code'] ?? ''}';
      final valueNum = row['value_num'];
      if (attributeCode.isEmpty || valueNum is! num) continue;
      nutrientByVariant.putIfAbsent(
        entityKey,
        () => <String, double>{},
      )[attributeCode] = valueNum
          .toDouble();
      legacyProjectionRowIndexByVariantAndAttribute.putIfAbsent(
        entityKey,
        () => <String, int>{},
      )[attributeCode] = index;
    }

    final variantIds = variants
        .map((row) => '${row['food_variant_id'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet();
    final sourceFoodIdByVariant = <String, String>{
      for (final row in variants)
        if ('${row['food_variant_id'] ?? ''}'.isNotEmpty &&
            '${row['source_food_code'] ?? ''}'.trim().isNotEmpty)
          '${row['food_variant_id']}': '${row['source_food_code']}'.trim(),
    };
    final nutrientEvidenceByVariant =
        <String, List<NutrientObservationEvidence>>{};
    final sourceDocIdsByVariant = <String, Set<String>>{};
    final scopeHashesByVariant = <String, Set<String>>{};
    for (var index = 0; index < observations.length; index++) {
      final row = observations[index];
      final entityKey = '${row['entity_key'] ?? ''}';
      if (!variantIds.contains(entityKey)) continue;
      final sourceDocId = '${row['source_doc_id'] ?? ''}';
      if (sourceDocId.isNotEmpty) {
        sourceDocIdsByVariant
            .putIfAbsent(entityKey, () => <String>{})
            .add(sourceDocId);
      }
      final scopeHash = '${row['scope_hash'] ?? ''}';
      if (scopeHash.isNotEmpty) {
        scopeHashesByVariant
            .putIfAbsent(entityKey, () => <String>{})
            .add(scopeHash);
      }
      final attributeCode = '${row['attribute_code'] ?? ''}';
      final evidenceRow = <String, dynamic>{
        for (final entry in row.entries) entry.key: entry.value,
        'selected_for_legacy_point_projection':
            legacyProjectionRowIndexByVariantAndAttribute[entityKey]?[attributeCode] ==
            index,
      };
      nutrientEvidenceByVariant
          .putIfAbsent(entityKey, () => <NutrientObservationEvidence>[])
          .add(NutrientObservationEvidence.fromJson(evidenceRow));
    }
    for (final row in foodCrosswalks) {
      final variantId = '${row['variant_id'] ?? ''}';
      final sourceDocId = '${row['source_doc_id'] ?? ''}';
      if (variantIds.contains(variantId) && sourceDocId.isNotEmpty) {
        sourceDocIdsByVariant
            .putIfAbsent(variantId, () => <String>{})
            .add(sourceDocId);
      }
    }
    for (final evidence in nutrientEvidenceByVariant.values) {
      evidence.sort(
        (left, right) =>
            jsonEncode(left.toJson()).compareTo(jsonEncode(right.toJson())),
      );
    }

    final sourceDocumentById = {
      for (final row in sourceDocuments)
        if ('${row['source_doc_id'] ?? ''}'.isNotEmpty)
          '${row['source_doc_id']}': row,
    };
    final variantScopeByHash = {
      for (final row in variantScopes)
        if ('${row['scope_hash'] ?? ''}'.isNotEmpty)
          '${row['scope_hash']}': row,
    };
    final catalogEvidenceByVariant = <String, FoodCatalogProvenanceEvidence>{};
    final foodPortionEvidenceByVariant = <String, List<FoodPortionEvidence>>{};
    for (final variantId in variantIds) {
      final linkedSourceIds =
          sourceDocIdsByVariant[variantId] ?? const <String>{};
      final linkedScopeHashes =
          scopeHashesByVariant[variantId] ?? const <String>{};
      final linkedCrosswalks = <FoodConceptVariantMatchEvidence>[];
      for (var index = 0; index < crosswalks.length; index++) {
        final row = crosswalks[index];
        if (row['domain'] != 'food' ||
            '${row['variant_id'] ?? ''}' != variantId) {
          continue;
        }
        linkedCrosswalks.add(
          FoodConceptVariantMatchEvidence.fromJson(<String, dynamic>{
            ...row,
            'selected_for_projected_food_id':
                selectedCrosswalkIndexByVariant[variantId] == index,
          }),
        );
      }
      final linkedSourceDocuments =
          linkedSourceIds.map((sourceDocId) {
            final row = sourceDocumentById[sourceDocId];
            if (row == null) {
              return FoodSourceDocumentEvidence.fromJson(<String, dynamic>{
                'source_doc_id': sourceDocId,
                'resolution_status': 'missing_source_document_row',
                'stored_payload_present': false,
              });
            }
            final rawPayload = row['raw_payload'];
            return FoodSourceDocumentEvidence.fromJson(<String, dynamic>{
              ...row,
              'source_registry_checksum': row['checksum'],
              'payload_sha256': rawPayload is String
                  ? sha256.convert(utf8.encode(rawPayload)).toString()
                  : null,
              'stored_payload_present': rawPayload is String,
            });
          }).toList()..sort(
            (left, right) => left.sourceDocId.compareTo(right.sourceDocId),
          );
      final linkedScopes =
          linkedScopeHashes.map((scopeHash) {
              final row = variantScopeByHash[scopeHash];
              if (row == null) {
                return FoodVariantScopeEvidence.fromJson(<String, dynamic>{
                  'scope_hash': scopeHash,
                  'resolution_status': 'missing_variant_scope_row',
                });
              }
              return FoodVariantScopeEvidence.fromJson(row);
            }).toList()
            ..sort((left, right) => left.scopeHash.compareTo(right.scopeHash));
      linkedCrosswalks.sort(
        (left, right) => left.crosswalkId.compareTo(right.crosswalkId),
      );
      final sourceFoodId = sourceFoodIdByVariant[variantId] ?? '';
      if (sourceFoodId.isNotEmpty) {
        final portions = <FoodPortionEvidence>[];
        for (final sourceDocId in linkedSourceIds) {
          final rawPayload = sourceDocumentById[sourceDocId]?['raw_payload'];
          if (rawPayload is! String) continue;
          Object? decodedPayload;
          try {
            decodedPayload = jsonDecode(rawPayload);
          } on FormatException {
            continue;
          }
          if (decodedPayload is! Map) continue;
          final audits = decodedPayload['food_portions_audit'];
          if (audits is! List) continue;
          for (final audit in audits) {
            if (audit is! Map ||
                '${audit['fdc_id'] ?? ''}'.trim() != sourceFoodId) {
              continue;
            }
            final parsedPortions = audit['parsed_portions'];
            if (parsedPortions is! List) continue;
            for (final rawPortion in parsedPortions) {
              if (rawPortion is! Map) continue;
              final portionJson = <String, dynamic>{
                for (final entry in rawPortion.entries)
                  if (entry.key is String) entry.key as String: entry.value,
                'source_doc_id': sourceDocId,
                'source_food_id': sourceFoodId,
              };
              portions.add(FoodPortionEvidence.fromJson(portionJson));
            }
          }
        }
        portions.sort((left, right) {
          final byDocument = (left.sourceDocId ?? '').compareTo(
            right.sourceDocId ?? '',
          );
          if (byDocument != 0) return byDocument;
          final byLocator = (left.recordLocator ?? '').compareTo(
            right.recordLocator ?? '',
          );
          if (byLocator != 0) return byLocator;
          return jsonEncode(
            left.toJson(),
          ).compareTo(jsonEncode(right.toJson()));
        });
        if (portions.isNotEmpty) {
          foodPortionEvidenceByVariant[variantId] = portions;
        }
      }
      if (linkedSourceDocuments.isNotEmpty ||
          linkedScopes.isNotEmpty ||
          linkedCrosswalks.isNotEmpty) {
        catalogEvidenceByVariant[variantId] = FoodCatalogProvenanceEvidence(
          sourceDocuments: linkedSourceDocuments,
          variantScopes: linkedScopes,
          conceptVariantMatches: linkedCrosswalks,
        );
      }
    }

    final projectedFoods = variants
        .map((row) {
          final variantId = '${row['food_variant_id']}';
          final hasCrosswalk = appIdByVariant.containsKey(variantId);
          final projectedId =
              appIdByVariant[variantId] ??
              'food_projected_${variantId.toLowerCase()}';
          final concept = conceptById['${row['food_concept_id']}'];
          final nutrients =
              nutrientByVariant[variantId] ?? const <String, double>{};
          final description = _buildFoodProjectionDescription(
            sourceFamily: '${row['source_family'] ?? 'CDSS'}',
            jurisdiction: '${row['jurisdiction'] ?? 'GLOBAL'}',
            nutrients: nutrients,
            fallbackWarning: hasCrosswalk
                ? null
                : 'missing_concept_variant_crosswalk; legacy_variant_id_projection',
          );
          return FoodItem(
            id: projectedId,
            name:
                '${row['display_name_local'] ?? concept?['canonical_name_en'] ?? variantId}',
            category: _inferFoodCategory(
              '${concept?['food_group'] ?? 'other'}',
            ),
            aliases: [
              if (concept?['canonical_name_en'] != null)
                '${concept!['canonical_name_en']}',
              if (concept?['canonical_name_zh'] != null)
                '${concept!['canonical_name_zh']}',
            ],
            description: description,
            sourceSystem: '${row['source_family'] ?? 'CDSS'}',
            sourceFoodCode: row['source_food_code']?.toString(),
            jurisdiction: '${row['jurisdiction'] ?? 'GLOBAL'}',
            textureClass: inferTextureClassFromText(
              name:
                  '${row['display_name_local'] ?? concept?['canonical_name_en'] ?? variantId}',
              description: description,
              categoryName: '${concept?['food_group'] ?? 'other'}',
            ),
            iddsiLevel: inferIddsiLevelFromTextureClass(
              inferTextureClassFromText(
                name:
                    '${row['display_name_local'] ?? concept?['canonical_name_en'] ?? variantId}',
                description: description,
                categoryName: '${concept?['food_group'] ?? 'other'}',
              ),
            ),
            // Missing ≠ zero: record which nutrient attributes were actually
            // present in the projected observations. Absent attributes are carried
            // in `missingNutrientFields` so downstream passes null (unknown) rather
            // than a fabricated true 0 g. The non-nullable getters keep the legacy
            // 0 only for UI display; the missing-set is the source of truth for the
            // model layer.
            proteinG: nutrients['protein_g'] ?? 0,
            carbsG: nutrients['carbohydrate_g'] ?? 0,
            fatG: nutrients['fat_g'] ?? 0,
            fiberG: nutrients['fiber_g'] ?? 0,
            sodiumMg: nutrients['sodium_mg'] ?? 0,
            missingNutrientFields: <String>{
              if (!nutrients.containsKey('protein_g')) 'proteinG',
              if (!nutrients.containsKey('carbohydrate_g')) 'carbsG',
              if (!nutrients.containsKey('fat_g')) 'fatG',
              if (!nutrients.containsKey('fiber_g')) 'fiberG',
              if (!nutrients.containsKey('sodium_mg')) 'sodiumMg',
              if (!nutrients.containsKey('energy_kcal')) 'energyKcal',
              if (!nutrients.containsKey('water_g')) 'waterG',
            },
            // Carry energy/water only when actually projected (never fabricated).
            energyKcal: nutrients['energy_kcal'],
            waterG: nutrients['water_g'],
            nutrientObservationEvidence:
                nutrientEvidenceByVariant[variantId] ??
                const <NutrientObservationEvidence>[],
            foodPortionEvidence:
                foodPortionEvidenceByVariant[variantId] ??
                const <FoodPortionEvidence>[],
            catalogProvenanceEvidence: catalogEvidenceByVariant[variantId],
            basisType: row['basis_type']?.toString(),
            // Qualifier is observation-specific; do not label the whole food
            // as exact when individual nutrient records differ or are absent.
            qualifierKind: null,
          );
        })
        .toList(growable: false);
    final queryAudit = <String, Object?>{
      'schema_id': 'parkinsum.cdss-food-projection-query-audit/1',
      'contract_id': 'cdss_catalog_projection_service.projectFoods/1',
      'query_method': 'CdssDatabase.queryTable(tableName)',
      'read_consistency':
          'six sequential table reads; no transaction-scoped snapshot was requested or verified',
      'query_options': <String, Object?>{
        'where_predicate': 'none; every row in each named table is returned',
        'order_by': 'none; adapter-returned row order is preserved',
        'volatile_fields_excluded_from_row_digest': <String>['_synced_at'],
      },
      'table_reads': <Map<String, Object?>>[
        _queryTableAudit('food_variant', 'food_variant_id', variants),
        _queryTableAudit('food_concept', 'food_concept_id', concepts),
        _queryTableAudit('observation', 'observation_id', observations),
        _queryTableAudit(
          'concept_variant_crosswalk',
          'crosswalk_id',
          crosswalks,
        ),
        _queryTableAudit('source_document', 'source_doc_id', sourceDocuments),
        _queryTableAudit('variant_scope', 'scope_hash', variantScopes),
      ],
      'selection_contract': <String, Object?>{
        'food_variant_rows':
            'all returned rows become projected candidates; no status, jurisdiction, or applicability filter is applied; output order follows returned rows',
        'food_concepts':
            'lookup by food_concept_id; a later returned duplicate replaces an earlier map value',
        'food_crosswalk_filter': "domain == 'food'",
        'food_crosswalk_projected_id_eligibility':
            'variant_id and app_entity_id must both be non-empty',
        'food_crosswalk_projected_id_winner':
            'last eligible row for a variant in returned order; all food-domain links for projected variants remain provenance evidence',
        'numeric_nutrient_filter':
            "entity_key is non-empty, qualifier_kind == 'exact', attribute_code is non-empty, and value_num is numeric",
        'numeric_nutrient_winner':
            'last qualifying row per entity_key and attribute_code in returned order',
        'nutrient_evidence_filter':
            'all observation rows whose entity_key matches a returned food_variant ID; evidence rows are sorted by serialized content after the legacy selected-row flag is attached',
        'source_and_scope_links':
            'source document IDs and scope hashes are the unions linked from retained food observations and food crosswalk rows; unresolved links remain evidence',
        'caller_query_and_filters':
            'not supplied to this projection API; candidate IDs, record contents, and caller order are separately captured by the candidate snapshot',
      },
    };
    return CdssFoodProjectionResult(
      foods: projectedFoods,
      queryAudit: queryAudit,
    );
  }

  Future<List<DrugDefinition>> projectDrugs() async {
    final concepts = await database.queryTable('drug_concept');
    final variants = await database.queryTable('drug_product_variant');
    final sections = await database.queryTable('drug_label_section');
    final media = await database.queryTable('drug_product_media');
    final crosswalks = await database.queryTable('concept_variant_crosswalk');
    final conceptById = {
      for (final row in concepts) '${row['drug_concept_id']}': row,
    };
    final sectionsByVariant = <String, List<Map<String, Object?>>>{};
    for (final row in sections) {
      final variantId = '${row['drug_product_variant_id'] ?? ''}';
      if (variantId.isEmpty) continue;
      sectionsByVariant
          .putIfAbsent(variantId, () => <Map<String, Object?>>[])
          .add(row);
    }
    final mediaCountByVariant = <String, int>{};
    final appIdByVariant = <String, String>{};
    for (final row in crosswalks.where((row) => row['domain'] == 'drug')) {
      final variantId = '${row['variant_id'] ?? ''}';
      final appId = '${row['app_entity_id'] ?? ''}';
      if (variantId.isNotEmpty && appId.isNotEmpty) {
        appIdByVariant[variantId] = appId;
      }
    }
    for (final row in media) {
      final variantId = '${row['drug_product_variant_id'] ?? ''}';
      if (variantId.isEmpty) continue;
      mediaCountByVariant.update(
        variantId,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return variants
        .map((row) {
          final concept = conceptById['${row['drug_concept_id']}'];
          final genericName =
              '${concept?['generic_name'] ?? row['external_product_code'] ?? 'Unknown drug'}';
          final tag = inferDrugTag(genericName);
          final variantId = '${row['drug_product_variant_id']}';
          final hasCrosswalk = appIdByVariant.containsKey(variantId);
          final projectedId =
              appIdByVariant[variantId] ??
              'drug_projected_${variantId.toLowerCase()}';
          final variantSections = sectionsByVariant[variantId] ?? const [];
          final sectionSummary = variantSections
              .take(3)
              .map((item) => '${item['section_key']}: ${item['section_text']}')
              .join(' ');
          final mediaCount = mediaCountByVariant[variantId] ?? 0;
          return DrugDefinition(
            id: projectedId,
            genericName: genericName,
            brandNames: ['${row['external_product_code'] ?? genericName}'],
            aliases: ['${row['external_product_code'] ?? ''}'],
            tags: [?tag],
            notes: sectionSummary.isEmpty
                ? 'Projected from CDSS drug_product_variant${hasCrosswalk ? '' : ' (warning: missing_concept_variant_crosswalk; legacy_variant_id_projection)'}'
                : '$sectionSummary${hasCrosswalk ? '' : ' Warning: missing_concept_variant_crosswalk; legacy_variant_id_projection.'}',
            interactionSummary: mediaCount > 0
                ? 'Projected from imported label/product data with $mediaCount linked media resources.'
                : 'Projected from imported label/product data.',
            sourceSystem: '${row['regulator'] ?? 'CDSS'}',
            sourceProductCode: row['external_product_code']?.toString(),
            jurisdiction: '${row['jurisdiction'] ?? 'GLOBAL'}',
            route: '${row['route'] ?? 'unspecified'}',
            dosageForm: '${row['dosage_form'] ?? 'unspecified'}',
            releaseType: '${row['release_type'] ?? 'unspecified'}',
          );
        })
        .toList(growable: false);
  }

  /// 食品详情投影：
  /// - 直接从 CDSS variant / observation / source_document 读取真实导入值；
  /// - 用于“添加一餐”的信息弹层和目录详情页。
  Future<ProjectedFoodDetail?> projectFoodDetail(FoodItem food) async {
    final variants = await database.queryTable('food_variant');
    final observations = await database.queryTable('observation');
    final sourceDocuments = await database.queryTable('source_document');

    final matchingVariants = variants
        .where((row) {
          final sameCode =
              food.sourceFoodCode != null &&
              '${row['source_food_code'] ?? ''}' == food.sourceFoodCode;
          final sameJurisdiction =
              '${row['jurisdiction'] ?? 'GLOBAL'}' == food.jurisdiction;
          return sameCode && sameJurisdiction;
        })
        .toList(growable: false);
    if (matchingVariants.isEmpty) return null;

    final variantIds = matchingVariants
        .map((row) => '${row['food_variant_id']}')
        .toSet();
    final sourceDocById = {
      for (final row in sourceDocuments) '${row['source_doc_id']}': row,
    };
    final nutrientLines = observations
        .where((row) => variantIds.contains('${row['entity_key'] ?? ''}'))
        .map(
          (row) => ProjectedNutrientLine(
            attributeCode: '${row['attribute_code'] ?? ''}',
            displayLabel: _attributeLabel('${row['attribute_code'] ?? ''}'),
            rawValueText: '${row['raw_value_text'] ?? ''}',
            unit: '${row['unit'] ?? ''}',
            qualifierKind: '${row['qualifier_kind'] ?? ''}',
            methodCode: row['method_code']?.toString(),
            sourceDocTitle:
                sourceDocById['${row['source_doc_id'] ?? ''}']?['title']
                    ?.toString(),
          ),
        )
        .toList(growable: false);

    return ProjectedFoodDetail(
      food: food,
      variantIds: variantIds.toList(growable: false),
      nutrientLines: nutrientLines,
      sourceTitles: matchingVariants
          .map((row) => row['source_family']?.toString() ?? 'CDSS')
          .toSet()
          .toList(growable: false),
    );
  }

  /// 药品详情投影：
  /// - 把标签 section / packaging / media 从真实导入数据读出来；
  /// - 给药品页和目录页展示更细的监管来源信息。
  Future<ProjectedDrugDetail?> projectDrugDetail(DrugDefinition drug) async {
    final variants = await database.queryTable('drug_product_variant');
    final sections = await database.queryTable('drug_label_section');
    final packagings = await database.queryTable('drug_product_packaging');
    final medias = await database.queryTable('drug_product_media');
    final sourceDocuments = await database.queryTable('source_document');

    final matchingVariants = variants
        .where((row) {
          final sameCode =
              drug.sourceProductCode != null &&
              '${row['external_product_code'] ?? ''}' == drug.sourceProductCode;
          final sameJurisdiction =
              '${row['jurisdiction'] ?? 'GLOBAL'}' == drug.jurisdiction;
          return sameCode && sameJurisdiction;
        })
        .toList(growable: false);
    if (matchingVariants.isEmpty) return null;

    final variantIds = matchingVariants
        .map((row) => '${row['drug_product_variant_id']}')
        .toSet();
    final sourceDocById = {
      for (final row in sourceDocuments) '${row['source_doc_id']}': row,
    };

    return ProjectedDrugDetail(
      drug: drug,
      variantIds: variantIds.toList(growable: false),
      sections: sections
          .where(
            (row) =>
                variantIds.contains('${row['drug_product_variant_id'] ?? ''}'),
          )
          .map(
            (row) => ProjectedDrugSection(
              sectionKey: '${row['section_key'] ?? ''}',
              sectionTitle: '${row['section_title'] ?? ''}',
              sectionText: '${row['section_text'] ?? ''}',
              sourceDocTitle:
                  sourceDocById['${row['source_doc_id'] ?? ''}']?['title']
                      ?.toString(),
            ),
          )
          .toList(growable: false),
      packagingDescriptions: packagings
          .where(
            (row) =>
                variantIds.contains('${row['drug_product_variant_id'] ?? ''}'),
          )
          .map((row) => '${row['description'] ?? ''}')
          .where((text) => text.trim().isNotEmpty)
          .toList(growable: false),
      mediaLinks: medias
          .where(
            (row) =>
                variantIds.contains('${row['drug_product_variant_id'] ?? ''}'),
          )
          .map((row) => '${row['media_url'] ?? ''}')
          .where((url) => url.trim().isNotEmpty)
          .toList(growable: false),
      labelFacts: _extractProjectedLabelFacts(
        sections: sections,
        variantIds: variantIds,
        sourceDocById: sourceDocById,
      ),
    );
  }

  List<ProjectedDrugLabelFact> _extractProjectedLabelFacts({
    required List<Map<String, Object?>> sections,
    required Set<String> variantIds,
    required Map<String, Map<String, Object?>> sourceDocById,
  }) {
    final sourceDocIds = sections
        .where(
          (row) =>
              variantIds.contains('${row['drug_product_variant_id'] ?? ''}'),
        )
        .map((row) => '${row['source_doc_id'] ?? ''}')
        .where((id) => id.isNotEmpty)
        .toSet();
    final facts = <ProjectedDrugLabelFact>[];
    for (final sourceDocId in sourceDocIds) {
      final sourceDoc = sourceDocById[sourceDocId];
      if (sourceDoc == null) continue;
      final rawPayload = '${sourceDoc['raw_payload'] ?? ''}';
      if (rawPayload.trim().isEmpty) continue;
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is! Map) continue;
        final labelFacts = decoded['label_facts'];
        if (labelFacts is! List) continue;
        for (final item in labelFacts.whereType<Map>()) {
          facts.add(
            ProjectedDrugLabelFact(
              factType: '${item['fact_type'] ?? ''}',
              label: '${item['label'] ?? ''}',
              valueText: item['value_text']?.toString(),
              sourceSectionKey: item['source_section_key']?.toString(),
              sourceSectionTitle: item['source_section_title']?.toString(),
              sourceExcerpt: item['source_excerpt']?.toString(),
              sourceDocTitle: sourceDoc['title']?.toString(),
            ),
          );
        }
      } catch (_) {
        // raw_payload 允许同时承载不同来源的原始 JSON；
        // 如果某条来源没有 label_facts，就在详情投影里安全忽略。
      }
    }
    return facts;
  }

  FoodCategory _inferFoodCategory(String foodGroup) {
    final lower = foodGroup.toLowerCase();
    if (lower.contains('fruit')) return FoodCategory.fruit;
    if (lower.contains('vegetable')) return FoodCategory.vegetable;
    if (lower.contains('dairy')) return FoodCategory.dairy;
    if (lower.contains('oil') || lower.contains('fat')) return FoodCategory.fat;
    if (lower.contains('beverage')) return FoodCategory.beverage;
    if (lower.contains('protein') ||
        lower.contains('meat') ||
        lower.contains('fish') ||
        lower.contains('legume')) {
      return FoodCategory.protein;
    }
    if (lower.contains('grain') ||
        lower.contains('cereal') ||
        lower.contains('starch') ||
        lower.contains('carb')) {
      return FoodCategory.carbs;
    }
    return FoodCategory.other;
  }

  String _buildFoodProjectionDescription({
    required String sourceFamily,
    required String jurisdiction,
    required Map<String, double> nutrients,
    String? fallbackWarning,
  }) {
    final details = <String>[
      '$sourceFamily/$jurisdiction',
      if (nutrients.containsKey('fiber_g'))
        'fiber ${nutrients['fiber_g']!.toStringAsFixed(1)} g',
      if (nutrients.containsKey('fat_g'))
        'fat ${nutrients['fat_g']!.toStringAsFixed(1)} g',
      if (nutrients.containsKey('sodium_mg'))
        'sodium ${nutrients['sodium_mg']!.toStringAsFixed(0)} mg',
      if (fallbackWarning != null) 'warning $fallbackWarning',
    ];
    return 'Projected from CDSS food_variant + observation (${details.join(', ')}).';
  }

  String _attributeLabel(String attributeCode) {
    switch (attributeCode) {
      case 'protein_g':
        return 'Protein';
      case 'carbohydrate_g':
        return 'Carbohydrate';
      case 'carbohydrate_by_difference_g':
        return 'Carbohydrate, by difference (includes fibre)';
      case 'fat_g':
        return 'Fat';
      case 'fiber_g':
        return 'Fiber';
      case 'sugars_total_g':
        return 'Sugars';
      case 'iron_mg':
        return 'Iron';
      case 'sodium_mg':
        return 'Sodium';
      default:
        return attributeCode;
    }
  }
}

class ProjectedFoodDetail {
  final FoodItem food;
  final List<String> variantIds;
  final List<ProjectedNutrientLine> nutrientLines;
  final List<String> sourceTitles;

  const ProjectedFoodDetail({
    required this.food,
    required this.variantIds,
    required this.nutrientLines,
    required this.sourceTitles,
  });
}

class ProjectedNutrientLine {
  final String attributeCode;
  final String displayLabel;
  final String rawValueText;
  final String unit;
  final String qualifierKind;
  final String? methodCode;
  final String? sourceDocTitle;

  const ProjectedNutrientLine({
    required this.attributeCode,
    required this.displayLabel,
    required this.rawValueText,
    required this.unit,
    required this.qualifierKind,
    this.methodCode,
    this.sourceDocTitle,
  });
}

class ProjectedDrugDetail {
  final DrugDefinition drug;
  final List<String> variantIds;
  final List<ProjectedDrugSection> sections;
  final List<String> packagingDescriptions;
  final List<String> mediaLinks;
  final List<ProjectedDrugLabelFact> labelFacts;

  const ProjectedDrugDetail({
    required this.drug,
    required this.variantIds,
    required this.sections,
    required this.packagingDescriptions,
    required this.mediaLinks,
    required this.labelFacts,
  });
}

class ProjectedDrugSection {
  final String sectionKey;
  final String sectionTitle;
  final String sectionText;
  final String? sourceDocTitle;

  const ProjectedDrugSection({
    required this.sectionKey,
    required this.sectionTitle,
    required this.sectionText,
    this.sourceDocTitle,
  });
}

class ProjectedDrugLabelFact {
  final String factType;
  final String label;
  final String? valueText;
  final String? sourceSectionKey;
  final String? sourceSectionTitle;
  final String? sourceExcerpt;
  final String? sourceDocTitle;

  const ProjectedDrugLabelFact({
    required this.factType,
    required this.label,
    this.valueText,
    this.sourceSectionKey,
    this.sourceSectionTitle,
    this.sourceExcerpt,
    this.sourceDocTitle,
  });
}

DrugTag? inferDrugTag(String genericName) {
  final lower = genericName.toLowerCase();
  if (lower.contains('levodopa')) return DrugTag.levodopaLike;
  if (lower.contains('entacapone') ||
      lower.contains('tolcapone') ||
      lower.contains('opicapone')) {
    return DrugTag.comtInhibitor;
  }
  if (lower.contains('rasagiline') ||
      lower.contains('selegiline') ||
      lower.contains('safinamide')) {
    return DrugTag.maoi;
  }
  if (lower.contains('pramipexole') ||
      lower.contains('ropinirole') ||
      lower.contains('rotigotine') ||
      lower.contains('apomorphine')) {
    return DrugTag.dopamineAgonist;
  }
  if (lower.contains('istradefylline')) return DrugTag.adenosineA2aAntagonist;
  if (lower.contains('amantadine')) return DrugTag.amantadineLike;
  if (lower.contains('rivastigmine')) return DrugTag.cholinesteraseInhibitor;
  if (lower.contains('droxidopa') || lower.contains('midodrine')) {
    return DrugTag.pressorAgent;
  }
  if (lower.contains('peg')) return DrugTag.laxative;
  if (lower.contains('iron')) return DrugTag.mineralSupplement;
  return null;
}
