import 'package:xml/xml.dart';

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

/// Ciqual XML 导入器。
///
/// 设计原则：
/// - 优先走官方 XML 链，而不是依赖 XLSX；
/// - 保留原始限定符 `<x` / `trace` / missing；
/// - 对 XML 字段名采用“宽松匹配”，减少因 Ciqual 列名小改导致的整体失效。
///
/// 已知边界：
/// - 当前未解析所有 Ciqual 组件细项；
/// - `sources.xml` 已汇总为 provenance 摘要串，但还没有拆成独立方法学子表。
class CiqualP0Importer {
  final SourceFetchClient fetchClient;

  const CiqualP0Importer({required this.fetchClient});

  Future<P0ImportBundle> fetchAndImport() async {
    final compoXml = await fetchClient.getText(P0SourceUrls.ciqualCompoXml);
    final alimXml = await fetchClient.getText(P0SourceUrls.ciqualAlimXml);
    final alimGrpXml = await fetchClient.getText(P0SourceUrls.ciqualAlimGrpXml);
    final constXml = await fetchClient.getText(P0SourceUrls.ciqualConstXml);
    final sourcesXml = await fetchClient.getText(P0SourceUrls.ciqualSourcesXml);

    return importFromXmlStrings(
      compoXml: compoXml,
      alimXml: alimXml,
      alimGrpXml: alimGrpXml,
      constXml: constXml,
      sourcesXml: sourcesXml,
    );
  }

  /// 兼容用户手工下载并打包的 Ciqual ZIP。
  ///
  /// 说明：
  /// - 官方数据集级 ZIP 文件名当前未明确，因此这里支持“本地打包后的 XML 集合”；
  /// - 只要 archive 中包含 `compo/alim/alim_grp/const/sources` 五个 XML 即可导入。
  P0ImportBundle importArchiveBytes(List<int> zipBytes) {
    final files = ArchiveImportSupport.unzipTextFiles(zipBytes);
    String pick(List<String> stems) {
      final match = files.entries.firstWhere(
        (entry) {
          final lower = entry.key.toLowerCase();
          return stems.any(lower.contains);
        },
        orElse: () => const MapEntry('', ''),
      );
      if (match.key.isEmpty) {
        throw StateError(
            'Ciqual archive missing file for ${stems.join(" / ")}.');
      }
      return match.value;
    }

    return importFromXmlStrings(
      compoXml: pick(const ['compo_']),
      alimXml: pick(const ['/alim_', '\\alim_', 'alim_202', 'alim.xml']),
      alimGrpXml: pick(const ['alim_grp']),
      constXml: pick(const ['const_']),
      sourcesXml: pick(const ['sources_']),
    );
  }

  P0ImportBundle importFromXmlStrings({
    required String compoXml,
    required String alimXml,
    required String alimGrpXml,
    required String constXml,
    required String sourcesXml,
  }) {
    final foods = _parseFoods(alimXml);
    final groups = _parseGroups(alimGrpXml);
    final nutrients = _parseNutrients(constXml);
    final sourceMethods = _parseSourceMethods(sourcesXml);
    final compositions = _parseCompositions(compoXml);

    final sourceDocId = sourceDocumentId(
      sourceSystem: 'CIQUAL',
      externalKey: 'doi_10_57745_RDMHWY',
    );
    final provenanceEntries = sourceMethods.entries
        .map((entry) => {
              'source_code': entry.key,
              'summary': entry.value,
            })
        .toList(growable: false);
    final firstSourceIds = provenanceEntries
        .take(5)
        .map((entry) => entry['source_code'])
        .toList(growable: false);
    final firstSourceTitles = provenanceEntries
        .take(5)
        .map((entry) => entry['summary'])
        .toList(growable: false);
    final sourceDocument = buildSourceDocumentRecord(
      sourceDocId: sourceDocId,
      sourceFamily: 'CIQUAL',
      organization: 'ANSES',
      jurisdiction: 'FR',
      docType: 'xml_dataset',
      title: 'Ciqual XML import bundle',
      originUrl: P0SourceUrls.ciqualDataset,
      licenseNote: 'Etalab Open License 2.0',
      language: 'fr',
      rawPayload: stringifyPayload({
        'compo_xml_length': compoXml.length,
        'alim_xml_length': alimXml.length,
        'alim_grp_xml_length': alimGrpXml.length,
        'const_xml_length': constXml.length,
        'sources_xml_length': sourcesXml.length,
        'provenance_summary': <String, Object?>{
          'source_count': provenanceEntries.length,
          'first_source_ids': firstSourceIds,
          'first_source_titles': firstSourceTitles,
          'entries': provenanceEntries,
          ...ImporterAudit.auditGap(
            fieldName: 'sources_xml_methodology',
            reason:
                'sources.xml summarized as a single provenance string per source_code; methodology subtables intentionally not modeled.',
            observedCount: provenanceEntries.length,
          ),
          'parser_limitation':
              'No stable methodology model is emitted from sources.xml; source titles and counts remain provenance summary metadata.',
        },
      }),
    );

    final foodConcepts = <FoodConceptRecord>[];
    final foodVariants = <FoodVariantRecord>[];
    final variantScopes = <VariantScopeRecord>[];
    final observations = <ObservationRecord>[];
    final resolvedFacts = <ResolvedFactRecord>[];
    final projectedFoods = <FoodItem>[];
    final crosswalks = <ConceptVariantCrosswalkRecord>[];
    final crosswalkSeen = <String>{};

    final conceptIds = <String>{};
    final variantIds = <String>{};

    for (final composition in compositions) {
      final food = foods[composition.foodCode];
      final nutrient = nutrients[composition.nutrientCode];
      if (food == null || nutrient == null) {
        continue;
      }

      final conceptId = buildFoodConceptId(food.nameEn ?? food.nameLocal);
      final variantId = buildFoodVariantId(
        conceptId: conceptId,
        jurisdiction: 'FR',
        sourceSystem: 'CIQUAL',
        sourceFoodCode: food.code,
      );
      final scopeHash = buildScopeHash('$variantId:ready_to_eat');
      final groupName = groups[food.groupCode] ?? 'other';
      final qualified = parseQualifiedValue(composition.rawValue);
      final methodCode = composition.sourceCode == null
          ? null
          : sourceMethods[composition.sourceCode!];

      if (conceptIds.add(conceptId)) {
        foodConcepts.add(
          FoodConceptRecord(
            foodConceptId: conceptId,
            canonicalNameEn: food.nameEn ?? food.nameLocal,
            canonicalNameZh: food.nameLocal,
            foodGroup: groupName,
          ),
        );
      }

      if (crosswalkSeen.add(variantId)) {
        crosswalks.add(
          buildCrosswalk(
            domain: 'food',
            conceptId: conceptId,
            variantId: variantId,
            externalIdSystem: 'Ciqual food code',
            externalIdValue: food.code,
            jurisdiction: 'FR',
            sourceDocId: sourceDocId,
            confidence: 1.0,
            mappingPayload: {
              'name_local': food.nameLocal,
              if (food.nameEn != null) 'name_en': food.nameEn,
              if (food.groupCode != null) 'group_code': food.groupCode,
              'group_name': groupName,
              ...ImporterAudit.confidenceReason(
                sourceIdentifierType:
                    ImporterAudit.sourceIdTypeAuthoritativeFoodCode,
                reason: 'Ciqual alim_code copied verbatim from alim XML.',
                promotedFields: const ['alim_code'],
                nonPromotedFields: const ['sources_xml_methodology'],
                parserLimitation:
                    'sources.xml is retained as source-document provenance summary, not a structured methodology table.',
              ),
            },
          ),
        );
      }

      if (variantIds.add(variantId)) {
        foodVariants.add(
          FoodVariantRecord(
            foodVariantId: variantId,
            foodConceptId: conceptId,
            jurisdiction: 'FR',
            sourceFamily: 'CIQUAL',
            sourceFoodCode: food.code,
            displayNameLocal: food.nameLocal,
            isAuthoritativeForRegion: true,
            isAuthoritativeFallback: false,
            status: 'imported_ciqual_xml',
            fallbackChainJson: '["FR","EU","GLOBAL"]',
          ),
        );
        variantScopes.add(
          VariantScopeRecord(
            scopeHash: scopeHash,
            jurisdiction: 'FR',
            brand: null,
            dosageForm: null,
            releaseType: null,
            saltForm: null,
            route: null,
            preparationState: food.edibleState,
            cookingState: food.cookingState,
            plantPart: null,
            cultivar: null,
            samplingFrame: 'ciqual_xml_import',
          ),
        );
      }

      final observation = ObservationRecord(
        observationId:
            'obs_${stableHash('$variantId:${nutrient.attributeCode}:${composition.rawValue}')}',
        domain: 'food',
        entityType: 'food_variant',
        entityKey: variantId,
        attributeCode: nutrient.attributeCode,
        valueType: 'numeric_interval',
        value: qualified,
        unit: nutrient.unit,
        basisType: 'per_100g_edible_part',
        basisAmount: 100,
        scopeHash: scopeHash,
        sourceDocId: sourceDocId,
        recordLocator: '${food.code}:${nutrient.code}',
        methodCode: methodCode,
        extractionConfidence: 1,
      );
      observations.add(observation);
      resolvedFacts.add(
        resolvedFactFromObservation(
          observation: observation,
          policyId: 'ciqual_xml_import_v1',
          snapshotId: 'facts_ciqual_xml_import_v1',
        ),
      );
    }

    final nutrientByVariant = <String, Map<String, String>>{};
    for (final composition in compositions) {
      final food = foods[composition.foodCode];
      final nutrient = nutrients[composition.nutrientCode];
      if (food == null || nutrient == null) continue;
      final conceptId = buildFoodConceptId(food.nameEn ?? food.nameLocal);
      final variantId = buildFoodVariantId(
        conceptId: conceptId,
        jurisdiction: 'FR',
        sourceSystem: 'CIQUAL',
        sourceFoodCode: food.code,
      );
      nutrientByVariant.putIfAbsent(
              variantId, () => <String, String>{})[nutrient.attributeCode] =
          composition.rawValue;
    }

    for (final food in foods.values) {
      final conceptId = buildFoodConceptId(food.nameEn ?? food.nameLocal);
      final variantId = buildFoodVariantId(
        conceptId: conceptId,
        jurisdiction: 'FR',
        sourceSystem: 'CIQUAL',
        sourceFoodCode: food.code,
      );
      final rawNutrients = nutrientByVariant[variantId];
      if (rawNutrients == null) continue;
      final textureClass = inferTextureClassFromText(
        name: food.nameLocal,
        description: food.nameEn ?? '',
        categoryName: groups[food.groupCode] ?? 'other',
      );
      projectedFoods.add(
        FoodItem(
          id: 'food_ciqual_${food.code}',
          name: food.nameLocal,
          category: inferFoodCategory(groups[food.groupCode] ?? 'other'),
          aliases: [
            if (food.nameEn != null) food.nameEn!,
            food.nameLocal,
          ],
          description: 'Ciqual imported food variant',
          sourceSystem: 'CIQUAL',
          sourceFoodCode: food.code,
          jurisdiction: 'FR',
          textureClass: textureClass,
          iddsiLevel: inferIddsiLevelFromTextureClass(textureClass),
          proteinG: displayValueFromRaw(rawNutrients['protein_g'] ?? '0'),
          carbsG: displayValueFromRaw(rawNutrients['carbohydrate_g'] ?? '0'),
          fatG: displayValueFromRaw(rawNutrients['fat_g'] ?? '0'),
          fiberG: displayValueFromRaw(rawNutrients['fiber_g'] ?? '0'),
          sodiumMg: displayValueFromRaw(rawNutrients['sodium_mg'] ?? '0'),
        ),
      );
    }

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

  Map<String, _CiqualFoodRow> _parseFoods(String xml) {
    final document = XmlDocument.parse(xml);
    final rows = _findRowMaps(document);
    final result = <String, _CiqualFoodRow>{};
    for (final row in rows) {
      final code = row['alim_code'];
      final nameFr = row['alim_nom_fr'] ?? row['alim_nom'];
      if (code == null || nameFr == null) continue;
      result[code] = _CiqualFoodRow(
        code: code,
        nameLocal: nameFr,
        nameEn: row['alim_nom_eng'],
        groupCode: row['alim_grp_code'],
        edibleState: row['alim_ssgrp_nom_fr'],
        cookingState: row['alim_ssssgrp_nom_fr'],
      );
    }
    return result;
  }

  Map<String, String> _parseGroups(String xml) {
    final document = XmlDocument.parse(xml);
    final rows = _findRowMaps(document);
    final result = <String, String>{};
    for (final row in rows) {
      final code = row['alim_grp_code'];
      final name = row['alim_grp_nom_fr'] ?? row['alim_grp_nom_eng'];
      if (code == null || name == null) continue;
      result[code] = name;
    }
    return result;
  }

  Map<String, _CiqualNutrientRow> _parseNutrients(String xml) {
    final document = XmlDocument.parse(xml);
    final rows = _findRowMaps(document);
    final result = <String, _CiqualNutrientRow>{};
    for (final row in rows) {
      final code = row['const_code'];
      final name =
          row['const_nom_eng'] ?? row['const_nom_fr'] ?? row['const_nom'];
      if (code == null || name == null) continue;
      final attributeCode = _attributeCodeForCiqualName(name);
      if (attributeCode == null) continue;
      result[code] = _CiqualNutrientRow(
        code: code,
        attributeCode: attributeCode,
        unit: row['unite'] ?? unitForAttributeCode(attributeCode),
      );
    }
    return result;
  }

  Map<String, String> _parseSourceMethods(String xml) {
    final document = XmlDocument.parse(xml);
    final rows = _findRowMaps(document);
    final result = <String, String>{};
    for (final row in rows) {
      final code = row['source_code'] ??
          row['sources_code'] ??
          row['code_source'] ??
          row['src_code'];
      final method = row['source_nom'] ??
          row['source_nom_fr'] ??
          row['source_nom_eng'] ??
          row['description'];
      if (code == null || method == null) continue;
      final summary = <String>[
        method,
        if ((row['bibliographie'] ?? row['reference'] ?? '').trim().isNotEmpty)
          'ref=${row['bibliographie'] ?? row['reference']}',
        if ((row['type_source'] ?? row['source_type'] ?? '').trim().isNotEmpty)
          'type=${row['type_source'] ?? row['source_type']}',
        if ((row['acquisition'] ?? row['mode_acquisition'] ?? '')
            .trim()
            .isNotEmpty)
          'acq=${row['acquisition'] ?? row['mode_acquisition']}',
      ].join(' | ');
      result[code] = summary;
    }
    return result;
  }

  List<_CiqualCompositionRow> _parseCompositions(String xml) {
    final document = XmlDocument.parse(xml);
    final rows = _findRowMaps(document);
    final result = <_CiqualCompositionRow>[];
    for (final row in rows) {
      final foodCode = row['alim_code'];
      final nutrientCode = row['const_code'];
      final rawValue = row['teneur'] ?? row['valeur'] ?? row['value'];
      if (foodCode == null || nutrientCode == null || rawValue == null) {
        continue;
      }
      result.add(
        _CiqualCompositionRow(
          foodCode: foodCode,
          nutrientCode: nutrientCode,
          rawValue: rawValue,
          sourceCode: row['source_code'] ??
              row['sources_code'] ??
              row['code_source'] ??
              row['src_code'],
        ),
      );
    }
    return result;
  }

  List<Map<String, String>> _findRowMaps(XmlDocument document) {
    final rows = <Map<String, String>>[];
    for (final element in document.descendants.whereType<XmlElement>()) {
      final childElements = element.children.whereType<XmlElement>().toList();
      if (childElements.length < 2) continue;
      final map = <String, String>{};
      for (final child in childElements) {
        final text = child.innerText.trim();
        if (text.isNotEmpty) {
          map[child.name.local.toLowerCase()] = text;
        }
      }
      if (map.isNotEmpty &&
          (map.containsKey('alim_code') ||
              map.containsKey('const_code') ||
              map.containsKey('alim_grp_code') ||
              map.containsKey('source_code') ||
              map.containsKey('sources_code') ||
              map.containsKey('code_source') ||
              map.containsKey('src_code'))) {
        rows.add(map);
      }
    }
    return rows;
  }

  String? _attributeCodeForCiqualName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('protein')) return 'protein_g';
    if (lower.contains('carbohydrate')) return 'carbohydrate_g';
    if (lower.contains('dietary fibre') || lower.contains('fiber')) {
      return 'fiber_g';
    }
    if (lower == 'fat' || lower.contains('lipid')) return 'fat_g';
    if (lower.contains('sodium')) return 'sodium_mg';
    if (lower.contains('iron')) return 'iron_mg';
    if (lower.contains('potassium')) return 'potassium_mg';
    return null;
  }
}

class _CiqualFoodRow {
  final String code;
  final String nameLocal;
  final String? nameEn;
  final String? groupCode;
  final String? edibleState;
  final String? cookingState;

  const _CiqualFoodRow({
    required this.code,
    required this.nameLocal,
    required this.nameEn,
    required this.groupCode,
    required this.edibleState,
    required this.cookingState,
  });
}

class _CiqualNutrientRow {
  final String code;
  final String attributeCode;
  final String unit;

  const _CiqualNutrientRow({
    required this.code,
    required this.attributeCode,
    required this.unit,
  });
}

class _CiqualCompositionRow {
  final String foodCode;
  final String nutrientCode;
  final String rawValue;
  final String? sourceCode;

  const _CiqualCompositionRow({
    required this.foodCode,
    required this.nutrientCode,
    required this.rawValue,
    required this.sourceCode,
  });
}
