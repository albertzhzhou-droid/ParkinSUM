import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../core/utils/texture_support.dart';
import '../../core/db/cdss_database.dart';
import '../../core/security/cdss_identifier_factory.dart';
import '../../data/datasources/remote/p0_import_support.dart' show stableHash;
import '../../core/db/cdss_catalog_snapshot_reader.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'qualified_nutrient_point_selection.dart';

bool _foodVariantAllowsArithmetic(
  Map<String, Object?>? variant,
  Map<String, Object?>? source,
) {
  if (variant == null || source == null) return false;
  final status = variant['status'];
  if (status == 'active') return true;
  // Existing importers record their ingestion route in this field. Recognize
  // only their exact marker and provider pairing; no wildcard or lifecycle
  // promotion is inferred from an arbitrary "imported" prefix.
  final family = variant['source_family'];
  final provider = source['source_family'];
  return switch (status) {
    'imported_fdc_json' =>
      family is String &&
          FdcFoodBasis.isFdcDataType(family) &&
          provider == 'FDC',
    'imported_ciqual_xml' ||
    'seeded_from_verified_report' => family == 'CIQUAL' && provider == 'CIQUAL',
    'imported_china_cdc_food_page' =>
      family == 'CHINA_CDC_FOOD_PLATFORM' &&
          provider == 'CHINA_CDC_FOOD_PLATFORM',
    _ => false,
  };
}

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
  final bool requireConsistentCatalog;

  const CdssCatalogProjectionService({
    required this.database,
    this.requireConsistentCatalog = false,
  });

  Future<List<FoodItem>> projectFoods() async =>
      (await projectFoodsWithAudit()).foods;

  /// Projects foods and returns the exact table reads and projection filters
  /// used for this run. Query rows are represented by ordered IDs and digests;
  /// raw payload text is never copied into the audit.
  Future<CdssFoodProjectionResult> projectFoodsWithAudit() async {
    CdssCatalogTableSnapshot? snapshot;
    if (requireConsistentCatalog || database is CdssCatalogSnapshotReader) {
      final reader = database;
      if (reader is! CdssCatalogSnapshotReader) {
        return _heldCatalog('atomic_catalog_reader_unavailable');
      }
      try {
        final captured = await (reader as CdssCatalogSnapshotReader)
            .readFoodCatalogSnapshot();
        captured.toAuditJson(); // Unrepresentable values fail closed, too.
        if (captured.holds.isNotEmpty) {
          return _heldCatalog('catalog_reference_or_promotion_hold', captured);
        } else {
          snapshot = captured;
        }
      } catch (_) {
        return _heldCatalog('catalog_snapshot_read_failed');
      }
    }
    Future<List<Map<String, Object?>>> read(String table) async =>
        snapshot?.rows[table] ?? await database.queryTable(table);
    final variants = await read('food_variant');
    final concepts = await read('food_concept');
    final observations = await read('observation');
    final crosswalks = await read('concept_variant_crosswalk');
    final sourceDocuments = await read('source_document');
    final variantScopes = await read('variant_scope');

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

    // Recover source basis even for an older stored observation that was
    // incorrectly labelled edible mass. Keep the original row unchanged.
    final sourcePayloads = <String, Map>{};
    for (final source in sourceDocuments) {
      try {
        final payload = jsonDecode('${source['raw_payload'] ?? ''}');
        if (payload is Map) {
          sourcePayloads['${source['source_doc_id']}'] = payload;
        }
      } on FormatException {
        // Unreadable source fields cannot prove a branded mass basis.
      }
    }
    final qualifiedBasisByVariant = <String, FdcFoodBasis>{};
    final basisAudit = <Map<String, Object?>>[];
    final basisSourceIdsByVariant = <String, Set<String>>{};
    for (final row in observations) {
      final entity = '${row['entity_key'] ?? ''}';
      final source = '${row['source_doc_id'] ?? ''}';
      if (entity.isNotEmpty && source.isNotEmpty) {
        (basisSourceIdsByVariant[entity] ??= <String>{}).add(source);
      }
    }
    for (final variant in variants) {
      final family = '${variant['source_family'] ?? ''}';
      if (!FdcFoodBasis.isFdcDataType(family)) continue;
      final variantId = '${variant['food_variant_id']}';
      final foodId = '${variant['source_food_code'] ?? ''}';
      final linkedSources = basisSourceIdsByVariant[variantId] ?? <String>{};
      final sourceBases = <FdcFoodBasis>[];
      for (final sourceId in linkedSources) {
        final audits = sourcePayloads[sourceId]?['food_basis_evidence'];
        if (audits is! List) continue;
        for (final audit in audits.whereType<Map>()) {
          if ('${audit['fdc_id'] ?? ''}' != foodId) continue;
          final fields = audit['source_fields'];
          if (fields is Map && '${fields['fdcId'] ?? ''}' == foodId) {
            sourceBases.add(FdcFoodBasis.inspect(fields));
          }
        }
      }
      final fallback = FdcFoodBasis.inspect({
        'fdcId': foodId,
        'dataType': family,
        'description': variant['display_name_local'],
      });
      final basis = sourceBases.isEmpty ? fallback : sourceBases.first;
      final ambiguous = sourceBases.any(
        (other) => other.basisType != basis.basisType,
      );
      final qualified = ambiguous
          ? FdcFoodBasis(
              basisType: 'source_basis_unqualified',
              reason: 'competing_source_bases',
              sourceFields: basis.sourceFields,
              requiresQualifiedIdentity: true,
            )
          : !fallback.supportsEdibleMassPoint &&
                fallback.reason == 'explicit_source_description_moisture_basis'
          ? fallback
          : basis;
      if (qualified.requiresQualifiedIdentity) {
        qualifiedBasisByVariant[variantId] = qualified;
        basisAudit.add({
          'variant_id': variantId,
          ...qualified.toJson(),
          'qualification_source': sourceBases.isEmpty
              ? 'retained_variant_source_description'
              : 'linked_source_fields',
        });
      }
    }
    final unavailableAttributes = <String, Set<String>>{};
    if (snapshot != null) {
      final currentSources = {
        for (final source in sourceDocuments) source['source_doc_id']: source,
      };
      final currentVariants = {
        for (final variant in variants) variant['food_variant_id']: variant,
      };
      for (final observation in observations.where(
        (r) => r['domain'] == 'food',
      )) {
        final source = currentSources[observation['source_doc_id']];
        final variant = currentVariants[observation['entity_key']];
        final unavailable =
            source == null ||
            source['source_status'] != 'active' ||
            !_foodVariantAllowsArithmetic(variant, source) ||
            ['published_at', 'effective_at'].any((key) {
              final date = source[key];
              return date != null &&
                  (date is! num ||
                      !date.isFinite ||
                      date > DateTime.now().millisecondsSinceEpoch);
            });
        if (unavailable) {
          (unavailableAttributes['${observation['entity_key']}'] ??= <String>{})
              .add('${observation['attribute_code']}');
        }
      }
    }
    final resolvedObservationIds = {
      for (final fact in snapshot?.rows['resolved_fact'] ?? const [])
        fact['chosen_observation_id'],
    };
    final fdcSourceIds = {
      for (final source in sourceDocuments)
        if (source['source_family'] == 'FDC') source['source_doc_id'],
    };
    // Current FDC imports retain label quantities as a separate per-serving
    // evidence stream. They neither supply a mass point nor contradict a
    // qualified per-100g observation. Mask only this explicit, unselected
    // sidecar in a complete snapshot, preserving original indexes and every
    // original row for the provenance view below. Other basis disagreements
    // and any label incorrectly selected by a resolved fact remain held.
    final pointEvidence = [
      for (final row in observations)
        if (snapshot != null &&
            row['domain'] == 'food' &&
            row['basis_type'] == 'per_serving_label' &&
            row['method_code'] == 'fdc:label_nutrients' &&
            fdcSourceIds.contains(row['source_doc_id']) &&
            !resolvedObservationIds.contains(row['observation_id']))
          const <String, Object?>{}
        else
          row,
    ];
    final originalSelection = selectQualifiedNutrientPoints(pointEvidence);
    final reviewedSelection = _reviewedFoodPoints(snapshot);
    final pointSelection = QualifiedNutrientPointSelection(
      points: {
        for (final entity in originalSelection.points.entries)
          entity.key: {
            for (final attribute in entity.value.entries)
              if (!(reviewedSelection.blocked[entity.key]?.contains(
                    attribute.key,
                  ) ??
                  false))
                attribute.key: attribute.value,
            ...?reviewedSelection.points[entity.key],
          },
        for (final entity in reviewedSelection.points.entries)
          if (!originalSelection.points.containsKey(entity.key))
            entity.key: entity.value,
      },
      observedAttributes: originalSelection.observedAttributes,
    );
    for (final entity in pointSelection.points.entries) {
      if (qualifiedBasisByVariant[entity.key]?.supportsEdibleMassPoint ==
          false) {
        continue;
      }
      nutrientByVariant[entity.key] = {
        for (final nutrient in entity.value.entries)
          if (!(unavailableAttributes[entity.key]?.contains(nutrient.key) ??
              false))
            nutrient.key: nutrient.value.value,
      };
      legacyProjectionRowIndexByVariantAndAttribute[entity.key] = {
        for (final nutrient in entity.value.entries)
          if (!(unavailableAttributes[entity.key]?.contains(nutrient.key) ??
              false))
            nutrient.key: nutrient.value.rowIndex,
      };
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
            const {
              'protein_g',
              'carbohydrate_g',
              'fat_g',
              'fiber_g',
              'sodium_mg',
              'energy_kcal',
              'water_g',
            }.contains(attributeCode) &&
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
    final productsByVariant = <String, List<FoodProductEvidence>>{};
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
      for (final sourceDocId in linkedSourceIds) {
        final products =
            sourcePayloads[sourceDocId]?['branded_product_details'];
        if (products is! List) continue;
        for (final product in products.whereType<Map>()) {
          final fields = product['source_fields'];
          if ('${product['fdc_id']}' == sourceFoodId &&
              fields is Map &&
              '${fields['fdcId']}' == sourceFoodId &&
              product['evidence_scope'] ==
                  'complete_original_branded_food_object') {
            (productsByVariant[variantId] ??= []).add(
              FoodProductEvidence(
                sourceDocId: sourceDocId,
                sourceFoodId: sourceFoodId,
                sourceFields: Map<String, Object?>.from(fields),
              ),
            );
          }
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
            foodProductEvidence: productsByVariant[variantId] ?? const [],
            catalogProvenanceEvidence: catalogEvidenceByVariant[variantId],
            basisType:
                qualifiedBasisByVariant[variantId]?.basisType ??
                row['basis_type']?.toString(),
            sourceBasisEvidence:
                qualifiedBasisByVariant[variantId]?.sourceFields,
            // Qualifier is observation-specific; do not label the whole food
            // as exact when individual nutrient records differ or are absent.
            qualifierKind: null,
          );
        })
        .toList(growable: false);
    final queryAudit = <String, Object?>{
      'schema_id': 'parkinsum.cdss-food-projection-query-audit/4',
      'reviewed_nutrient_selection': reviewedSelection.audit,
      'source_lifecycle_holds': {
        for (final entry in unavailableAttributes.entries)
          entry.key: (entry.value.toList()..sort()),
      },
      'contract_id': 'cdss_catalog_projection_service.projectFoods/1',
      'query_method': 'CdssDatabase.queryTable(tableName)',
      'read_consistency':
          snapshot?.consistency ?? 'legacy_unverified_sequential_reads',
      'catalog_snapshot': snapshot?.toAuditJson(),
      'strict_candidate_read_required': requireConsistentCatalog,
      'status': 'projected',
      'query_options': <String, Object?>{
        'where_predicate': 'none; every row in each named table is returned',
        'order_by': 'none; adapter-returned row order is preserved',
        'volatile_fields_excluded_from_row_digest': <String>['_synced_at'],
      },
      'table_reads': <Map<String, Object?>>[
        if (snapshot != null) ...[
          _queryTableAudit(
            'resolved_fact',
            'fact_id',
            snapshot.rows['resolved_fact']!,
          ),
          _queryTableAudit(
            'conflict_audit_log',
            'audit_id',
            snapshot.rows['conflict_audit_log']!,
          ),
        ],
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
        if (basisAudit.isNotEmpty) 'source_basis_qualification': basisAudit,
        'numeric_nutrient_unit_basis_contract':
            'Explicit unit must match the attribute and explicit basis must be per_100g or per_100g_edible_part with amount 100; omitted metadata is retained only for legacy point compatibility, not evidence of a measured basis.',
        'numeric_nutrient_competing_qualifier_contract':
            'Any competing primary qualifier withholds the point; only an explicitly attached :sample_range with matching source_min/source_max and bounds enclosing the point is retained as source statistics alongside one exact row.',
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
            "entity_key and attribute_code non-empty; qualifier_kind == 'exact'; finite non-negative value; one proven evidence group and one source-document identity for that nutrient",
        'numeric_nutrient_winner':
            'single qualifying evidence group; proven duplicates retain every occurrence; unproven duplicates and incompatible source revisions remain evidence only',
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

  CdssFoodProjectionResult _heldCatalog(
    String reason, [
    CdssCatalogTableSnapshot? snapshot,
  ]) => CdssFoodProjectionResult(
    foods: const [],
    queryAudit: <String, Object?>{
      'schema_id': 'parkinsum.cdss-food-projection-query-audit/4',
      'contract_id': 'cdss_catalog_projection_service.projectFoods/1',
      'status': 'HOLD',
      'reason': reason,
      'read_consistency': snapshot?.consistency ?? 'unavailable',
      'strict_candidate_read_required': true,
      'catalog_snapshot': snapshot?.toAuditJson(),
      'table_reads': const <Map<String, Object?>>[],
      'fallback_boundary':
          'No imported candidates are emitted. Caller or built-in inputs retain their separate identities; no imported snapshot is claimed.',
    },
  );

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
    CdssCatalogTableSnapshot? captured;
    final reader = database;
    if (reader is CdssCatalogSnapshotReader) {
      try {
        final candidate = await (reader as CdssCatalogSnapshotReader)
            .readFoodCatalogSnapshot();
        if (candidate.holds.isNotEmpty) return null;
        captured = candidate;
      } catch (_) {
        if (requireConsistentCatalog) return null;
      }
    } else if (requireConsistentCatalog) {
      return null;
    }
    Future<List<Map<String, Object?>>> read(String table) async =>
        captured?.rows[table] ?? await database.queryTable(table);
    final variants = await read('food_variant');
    final observations = await read('observation');
    final sourceDocuments = await read('source_document');

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
          final sameSource =
              '${row['regulator'] ?? ''}'.toUpperCase() ==
              drug.sourceSystem.toUpperCase();
          return sameCode && sameJurisdiction && sameSource;
        })
        .toList(growable: false);
    if (matchingVariants.isEmpty) return null;

    final variantIds = matchingVariants
        .map((row) => '${row['drug_product_variant_id']}')
        .toSet();
    final sourceDocById = {
      for (final row in sourceDocuments) '${row['source_doc_id']}': row,
    };
    final payloadById = {
      for (final row in sourceDocuments)
        '${row['source_doc_id']}': _drugDocumentPayload(row),
    };

    return ProjectedDrugDetail(
      drug: drug,
      variantIds: variantIds.toList(growable: false),
      sourceDocuments: [
        for (final row in sourceDocuments)
          if (_selectedProductScopes(
                payloadById['${row['source_doc_id']}'] ?? const {},
                variantIds,
              ).isNotEmpty ||
              sections.any(
                (section) =>
                    variantIds.contains(
                      '${section['drug_product_variant_id'] ?? ''}',
                    ) &&
                    section['source_doc_id'] == row['source_doc_id'],
              ))
            ProjectedDrugSourceDocument.fromRow(row, variantIds: variantIds),
      ],
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
              applicabilityScope: _drugSectionScope(
                payloadById['${row['source_doc_id']}'] ?? const {},
                '${row['drug_product_variant_id'] ?? ''}',
                '${row['section_key'] ?? ''}',
              ),
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
        final List<Object?> scopedFacts;
        if ((decoded.containsKey('product_scopes') ||
            decoded.containsKey('product_scope_schema'))) {
          scopedFacts = [
            for (final scope in _selectedProductScopes(decoded, variantIds))
              if (scope['identity_status'] == 'resolved_product_scope' &&
                  scope['label_facts'] is List)
                for (final fact in scope['label_facts'] as List)
                  if (fact is Map &&
                      scope['section_scopes'] is Map &&
                      (scope['section_scopes']
                              as Map)[fact['source_section_key']] ==
                          'product_explicit')
                    fact,
          ];
        } else {
          scopedFacts = decoded['label_facts'] is List
              ? List<Object?>.from(decoded['label_facts'] as List)
              : const [];
        }
        final labelFacts = scopedFacts;
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
      case 'energy_atwater_general_kcal':
        return 'Energy (Atwater General Factors)';
      case 'energy_atwater_specific_kcal':
        return 'Energy (Atwater Specific Factors)';
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
  final List<ProjectedDrugSourceDocument> sourceDocuments;

  const ProjectedDrugDetail({
    required this.drug,
    required this.variantIds,
    required this.sections,
    required this.packagingDescriptions,
    required this.mediaLinks,
    required this.labelFacts,
    this.sourceDocuments = const [],
  });
}

Map _drugDocumentPayload(Map<String, Object?> row) {
  try {
    final decoded = jsonDecode('${row['raw_payload'] ?? ''}');
    return decoded is Map ? decoded : const {};
  } on FormatException {
    return const {};
  }
}

List<Map> _selectedProductScopes(Map payload, Set<String> variantIds) {
  final scopes = payload['product_scopes'];
  if (payload['product_scope_schema'] != 'spl-product-scope/1' ||
      scopes is! Map) {
    return const [];
  }
  return [
    for (final id in variantIds)
      if (scopes[id] is Map) scopes[id] as Map,
  ];
}

String _drugSectionScope(Map payload, String variantId, String sectionKey) {
  if (!payload.containsKey('product_scopes') &&
      !payload.containsKey('product_scope_schema')) {
    return 'legacy_unspecified';
  }
  final selected = _selectedProductScopes(payload, {variantId});
  if (selected.length != 1 ||
      selected.single['identity_status'] != 'resolved_product_scope') {
    return 'hold_product_identity';
  }
  final scopes = selected.single['section_scopes'];
  return scopes is Map
      ? '${scopes[sectionKey] ?? 'hold_section_scope'}'
      : 'hold_section_scope';
}

class ProjectedDrugSourceDocument {
  const ProjectedDrugSourceDocument({
    required this.sourceDocId,
    required this.originUrl,
    required this.labelVersion,
    required this.effectiveTime,
    required this.contentSha256,
    required this.activeIngredientDetails,
    this.ingredientClassEvidence = const [],
    this.productScopeStatus = 'legacy_unspecified',
  });

  final String sourceDocId;
  final String originUrl;
  final String? labelVersion;
  final String? effectiveTime;
  final String? contentSha256;
  final List<Map<String, Object?>> activeIngredientDetails;
  final List<Map<String, Object?>> ingredientClassEvidence;

  /// Complete source classes, including IACT and unresolved records. Legacy
  /// documents retain their active-only view without inventing inactive rows.
  List<Map<String, Object?>> get displayedIngredientEvidence =>
      ingredientClassEvidence.isNotEmpty
      ? ingredientClassEvidence
      : activeIngredientDetails;
  final String productScopeStatus;

  factory ProjectedDrugSourceDocument.fromRow(
    Map<String, Object?> row, {
    Set<String> variantIds = const {},
  }) {
    final payload = _drugDocumentPayload(row);
    final selected = _selectedProductScopes(payload, variantIds);
    final structured =
        payload.containsKey('product_scopes') ||
        payload.containsKey('product_scope_schema');
    final ingredients = structured
        ? [
            for (final scope in selected)
              if (scope['active_ingredient_details'] is List)
                ...scope['active_ingredient_details'] as List,
          ]
        : payload['active_ingredient_details'];
    final classes = structured
        ? [
            for (final scope in selected)
              if (scope['ingredient_class_audit'] is List)
                ...scope['ingredient_class_audit'] as List,
          ]
        : payload['ingredient_class_audit'];
    return ProjectedDrugSourceDocument(
      sourceDocId: '${row['source_doc_id'] ?? ''}',
      originUrl: '${row['origin_url'] ?? ''}',
      labelVersion: payload['version_number']?.toString(),
      effectiveTime: payload['effective_time']?.toString(),
      contentSha256: payload['spl_xml_sha256']?.toString(),
      productScopeStatus: structured
          ? (selected.length == 1 &&
                    selected.single['identity_status'] ==
                        'resolved_product_scope'
                ? 'resolved_product_scope'
                : 'hold_product_identity')
          : 'legacy_unspecified',
      activeIngredientDetails: ingredients is List
          ? [
              for (final item in ingredients.whereType<Map>())
                {for (final entry in item.entries) '${entry.key}': entry.value},
            ]
          : const [],
      ingredientClassEvidence: classes is List
          ? [
              for (final item in classes.whereType<Map>())
                {for (final entry in item.entries) '${entry.key}': entry.value},
            ]
          : const [],
    );
  }
}

class ProjectedDrugSection {
  final String sectionKey;
  final String sectionTitle;
  final String sectionText;
  final String? sourceDocTitle;
  final String applicabilityScope;

  const ProjectedDrugSection({
    required this.sectionKey,
    required this.sectionTitle,
    required this.sectionText,
    this.sourceDocTitle,
    this.applicabilityScope = 'legacy_unspecified',
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

/// A review is usable only through the complete original packet and the
/// current participating catalogue capture. Typed names confer no authority.
({
  Map<String, Map<String, QualifiedNutrientPoint>> points,
  Map<String, Set<String>> blocked,
  List<Map<String, Object?>> audit,
})
_reviewedFoodPoints(CdssCatalogTableSnapshot? snapshot) {
  final points = <String, Map<String, QualifiedNutrientPoint>>{},
      blocked = <String, Set<String>>{},
      audit = <Map<String, Object?>>[];
  if (snapshot == null) return (points: points, blocked: blocked, audit: audit);
  final rows = snapshot.rows,
      observations = rows['observation']!,
      audits = rows['conflict_audit_log']!;
  final ids = CdssIdentifierFactory();
  Map<String, Object?> one(List<Map<String, Object?>> candidates) {
    if (candidates.length != 1) {
      throw const FormatException('Ambiguous reviewed evidence');
    }
    return candidates.single;
  }

  bool truth(Object? v) => v == true || v == 1;
  Map<String, Object?> tableRow(Map row) => {
    for (final entry in row.entries)
      if (entry.key != '_synced_at') '${entry.key}': entry.value,
  };
  String hash(String domain, Object? value) => ids.inputDigest(
    domain,
    domain.startsWith('current-') && value is Map ? tableRow(value) : value,
  );
  Map payload(Map row) => jsonDecode(row['decision_reason'] as String) as Map;
  final promoted =
      rows['engine_snapshot']!.where((r) => r['promoted_at'] is num).toList()
        ..sort(
          (a, b) =>
              (b['promoted_at'] as num).compareTo(a['promoted_at'] as num),
        );
  final explicit = rows['resolved_fact']!
      .where((f) => f['resolution_status'] == 'EXPLICIT_SOURCE_REVIEW')
      .toList();
  final groups = <String, List<Map<String, Object?>>>{};
  for (final f in explicit) {
    final entity = '${f['entity_key']}', attr = '${f['attribute_code']}';
    (blocked[entity] ??= <String>{}).add(attr);
    (groups['$entity|$attr'] ??= []).add(f);
  }
  for (final group in groups.values) {
    final entity = '${group.first['entity_key']}',
        attr = '${group.first['attribute_code']}';
    try {
      if (promoted.isEmpty ||
          (promoted.length > 1 &&
              promoted[0]['promoted_at'] == promoted[1]['promoted_at'])) {
        throw const FormatException(
          'Current snapshot unavailable or ambiguous',
        );
      }
      final active = promoted.first['snapshot_id'];
      final fact = one(group.where((f) => f['snapshot_id'] == active).toList());
      if (!truth(fact['manual_override']) || fact['fact_version'] != active) {
        throw const FormatException('Reviewed fact not current');
      }
      final decision = one(
        audits
            .where(
              (r) =>
                  r['audit_id'] == fact['resolution_policy_id'] &&
                  r['audit_type'] == 'IMPORT_CONFLICT_REVIEW_DECISION',
            )
            .toList(),
      );
      final d = payload(decision);
      if (d['action'] != 'choose_observation' ||
          d['activation_authorized'] != false ||
          d['clinical_approval'] != false ||
          hash('import-review-decision', d) != decision['input_hash']) {
        throw const FormatException('Decision integrity unavailable');
      }
      final receiptRow = one(
        audits
            .where(
              (r) =>
                  r['snapshot_id'] == active &&
                  r['audit_type'] == 'REVIEWED_IMPORT_ACTIVATION',
            )
            .toList(),
      );
      final receipt = payload(receiptRow);
      if (receipt['schema'] != 'parkinsum.reviewed-import-activation/1' ||
          hash('reviewed-import-activation', receipt) !=
              receiptRow['input_hash'] ||
          receipt['derived_snapshot_id'] != active ||
          receipt['derived_run_id'] != receiptRow['run_id'] ||
          receipt['original_held_snapshot_id'] != d['snapshot_id'] ||
          !(receipt['review_decision_ids'] as List).contains(
            decision['audit_id'],
          ) ||
          receipt['clinical_approval'] != false ||
          receipt['original_hold_released'] != false) {
        throw const FormatException('Activation receipt integrity unavailable');
      }
      final run = one(
        rows['ingestion_run']!
            .where(
              (r) =>
                  r['snapshot_id'] == d['snapshot_id'] &&
                  r['status'] == 'held_for_conflict_review' &&
                  r['run_id'] == '${d['run_id']}_promote',
            )
            .toList(),
      );
      final evidence =
              (jsonDecode(run['notes_json'] as String)
                      as Map)['review_evidence']
                  as Map,
          p = evidence['payload'] as Map;
      if (evidence['schema'] != 'parkinsum.held-import-review-evidence/2' ||
          hash('held-import-review-evidence', p) != evidence['input_sha256'] ||
          d['evidence_sha256'] != evidence['input_sha256'] ||
          receipt['original_evidence_sha256'] != evidence['input_sha256']) {
        throw const FormatException(
          'Original complete packet integrity unavailable',
        );
      }
      final originalAudit = one(
        (p['conflict_audits'] as List)
            .map((r) => Map<String, Object?>.from(r as Map))
            .where((r) => r['audit_id'] == d['conflict_audit_id'])
            .toList(),
      );
      if (hash('original-conflict-audit', originalAudit) !=
          d['original_audit_sha256']) {
        throw const FormatException('Original conflict integrity unavailable');
      }
      final derived = one(
        audits
            .where(
              (r) =>
                  r['audit_type'] == 'FACT_CLUSTER_RESOLUTION' &&
                  r['decision'] == 'explicit_source_review_choice' &&
                  r['run_id'] == receipt['derived_run_id'] &&
                  payload(r)['review_decision_id'] == decision['audit_id'],
            )
            .toList(),
      );
      final rationale = payload(derived), original = payload(originalAudit);
      if (derived['input_hash'] != stableHash(jsonEncode(rationale)) ||
          hash('original-rationale', rationale['original_rationale']) !=
              hash('original-rationale', original) ||
          rationale['original_conflict_audit_id'] !=
              originalAudit['audit_id'] ||
          rationale['needs_human_review'] != false ||
          rationale['clinical_approval'] != false) {
        throw const FormatException(
          'Original comparison graph integrity unavailable',
        );
      }
      final chosen = Map<String, Object?>.from(d['chosen_observation'] as Map),
          source = Map<String, Object?>.from(d['chosen_source'] as Map);
      if (hash('chosen-observation', chosen) !=
              d['chosen_observation_sha256'] ||
          hash('chosen-source', source) != d['chosen_source_sha256']) {
        throw const FormatException(
          'Selected original evidence integrity unavailable',
        );
      }
      final edges = (original['comparison_edges'] as List).cast<Map>();
      if (edges.isEmpty || edges.any((e) => e['numeric_comparable'] != true)) {
        throw const FormatException('Comparison scope unavailable');
      }
      final participants = <String>{
        for (final e in edges) ...[
          '${e['left_observation_id']}',
          '${e['right_observation_id']}',
        ],
      };
      if (!participants.contains(chosen['observation_id'])) {
        throw const FormatException('Chosen evidence not original participant');
      }
      final historic = p['incumbent_evidence'] as Map;
      final originalRows = <Map>[
        ...(p['observations'] as List).cast<Map>(),
        ...(historic['observation'] as List).cast<Map>(),
      ];
      final originalSources = <Map>[
        ...(p['source_documents'] as List).cast<Map>(),
        ...(historic['source_document'] as List).cast<Map>(),
      ];
      final originalScopes = <Map>[
        ...((p['staging_rows'] as Map)['staging_variant_scope'] as List).map(
          (r) => jsonDecode((r as Map)['payload_json'] as String) as Map,
        ),
        ...(historic['variant_scope'] as List).cast<Map>(),
      ];
      final live = observations
          .where(
            (r) =>
                r['domain'] == chosen['domain'] &&
                r['entity_type'] == chosen['entity_type'] &&
                r['entity_key'] == entity &&
                r['attribute_code'] == attr,
          )
          .toList();
      if (live.length != participants.length ||
          live.any((r) => !participants.contains(r['observation_id']))) {
        throw const FormatException('Current alternatives changed');
      }
      for (final row in live) {
        final originals = originalRows
            .where((r) => r['observation_id'] == row['observation_id'])
            .toList();
        if (originals.isEmpty ||
            originals.any(
              (r) =>
                  hash('current-observation', r) !=
                  hash('current-observation', row),
            )) {
          throw const FormatException('Original alternative changed');
        }
        final liveSource = one(
          rows['source_document']!
              .where((s) => s['source_doc_id'] == row['source_doc_id'])
              .toList(),
        );
        final originalsSource = originalSources
            .where((s) => s['source_doc_id'] == row['source_doc_id'])
            .toList();
        final raw = liveSource['raw_payload'];
        if (originalsSource.isEmpty ||
            originalsSource.any(
              (s) =>
                  hash('current-source', s) !=
                  hash('current-source', liveSource),
            ) ||
            liveSource['source_status'] != 'active' ||
            raw is! String ||
            raw.trim().isEmpty ||
            stableHash(raw) != liveSource['checksum'] ||
            '${liveSource['origin_url'] ?? ''}'.trim().isEmpty) {
          throw const FormatException('Original source changed or inactive');
        }
        for (final key in ['published_at', 'effective_at']) {
          final date = liveSource[key];
          if (date != null &&
              (date is! num ||
                  !date.isFinite ||
                  date > DateTime.now().millisecondsSinceEpoch)) {
            throw const FormatException('Source date unavailable');
          }
        }
        final liveScope = one(
          rows['variant_scope']!
              .where((s) => s['scope_hash'] == row['scope_hash'])
              .toList(),
        );
        final originalScope = originalScopes
            .where((s) => s['scope_hash'] == row['scope_hash'])
            .toList();
        if (originalScope.isEmpty ||
            originalScope.any(
              (s) =>
                  hash('current-scope', s) != hash('current-scope', liveScope),
            )) {
          throw const FormatException('Original scope changed');
        }
      }
      final currentChosen = one(
        live
            .where((r) => r['observation_id'] == chosen['observation_id'])
            .toList(),
      );
      if (hash('chosen-observation', tableRow(currentChosen)) !=
              d['chosen_observation_sha256'] ||
          chosen['qualifier_kind'] != 'exact' ||
          '${chosen['unit'] ?? ''}'.isEmpty ||
          '${chosen['basis_type'] ?? ''}'.isEmpty ||
          chosen['basis_amount'] != 100) {
        throw const FormatException(
          'Selected point is not eligible for arithmetic',
        );
      }
      for (final key in [
        'entity_key',
        'attribute_code',
        'scope_hash',
        'qualifier_kind',
        'value_num',
        'raw_value_text',
      ]) {
        if (fact[key] != chosen[key]) {
          throw const FormatException('Resolved quantity changed');
        }
      }
      if (fact['chosen_observation_id'] != chosen['observation_id'] ||
          fact['resolved_low'] != chosen['low'] ||
          fact['resolved_high'] != chosen['high'] ||
          fact['resolved_unit'] != chosen['unit']) {
        throw const FormatException('Resolved bounds or units changed');
      }
      final selected = selectQualifiedNutrientPoints([
        currentChosen,
      ]).points[entity]?[attr];
      if (selected == null) {
        throw const FormatException('Selected point basis unavailable');
      }
      final index = observations.indexOf(currentChosen);
      (points[entity] ??= {})[attr] = QualifiedNutrientPoint(
        value: selected.value,
        rowIndex: index,
        supportingRowIndexes: [index],
      );
      audit.add({
        'entity_key': entity,
        'attribute_code': attr,
        'status': 'explicit_original_source_choice',
        'fact_id': fact['fact_id'],
        'decision_id': decision['audit_id'],
        'snapshot_id': active,
        'observation_id': chosen['observation_id'],
        'clinical_approval': false,
        'source_currency_inferred': false,
      });
    } catch (e) {
      audit.add({
        'entity_key': entity,
        'attribute_code': attr,
        'status': 'HOLD',
        'reason': e is FormatException
            ? e.message
            : 'unreadable_reviewed_state',
        'clinical_approval': false,
      });
    }
  }
  return (points: points, blocked: blocked, audit: audit);
}
