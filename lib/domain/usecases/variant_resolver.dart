import 'dart:convert';

import '../../core/db/cdss_database.dart';
import '../entities/resolved_variant.dart';
import '../entities/runtime_context.dart';

/// Resolves the most appropriate food/drug variant from the local database.
///
/// 当前状态说明：
/// - 已经从数据库读取真实 variant，而不是只用目录里的固定种子。
/// - 但它仍是轻量级排序器，尚未完全实现设计书里的全量 provenance / recency /
///   product-specificity / uncertainty matrix。
class VariantResolver {
  final CdssDatabase database;

  VariantResolver({required this.database});

  Future<List<String>> resolveJurisdictionChain(
    UserProfileRuntimeContext userProfile,
  ) async {
    final regionRows = await database.queryTable('region_jurisdiction_map');
    final byRegion = <String, Map<String, Object?>>{
      for (final row in regionRows)
        (row['region_code']?.toString().toUpperCase() ?? ''): row,
    };

    final chain = <String>[];

    void append(List<String> values) {
      for (final value in values) {
        final normalized = value.trim().toUpperCase();
        if (normalized.isEmpty || chain.contains(normalized)) continue;
        chain.add(normalized);
      }
    }

    append(userProfile.contentJurisdictionOverride);
    // 地区与 locale 不能混成一个字段：先吃注册/覆盖辖区，再参考 locale 的地区子标签。
    append(_mappedChain(byRegion, userProfile.registrationRegion));

    final localeRegion = _regionFromLocale(userProfile.displayLocale);
    if (localeRegion != null) {
      append(_mappedChain(byRegion, localeRegion));
    }

    append(const ['GLOBAL']);
    return chain;
  }

  Future<ResolvedFoodVariant> resolveFoodVariant({
    required String foodId,
    required UserProfileRuntimeContext userProfile,
  }) async {
    final chain = await resolveJurisdictionChain(userProfile);
    final regionRows = await database.queryTable('region_jurisdiction_map');
    final rows = await database.queryTable('food_variant');
    final crosswalk = await _findBestCrosswalk(
      domain: 'food',
      appEntityId: foodId,
      chain: chain,
    );
    final conceptId =
        crosswalk?['concept_id']?.toString() ?? 'FOOD_${foodId.toUpperCase()}';
    // 先按 source_food_code 直连，兼容“UI 仍使用旧 foodId，但数据库已开始接官方外部编码”的过渡期。
    final crosswalkMatches = crosswalk == null
        ? const <Map<String, Object?>>[]
        : rows
            .where((row) =>
                row['food_variant_id']?.toString() ==
                crosswalk['variant_id']?.toString())
            .toList(growable: false);
    final directMatches = rows
        .where((row) => row['source_food_code']?.toString() == foodId)
        .toList(growable: false);
    final candidates = crosswalkMatches.isNotEmpty
        ? crosswalkMatches
        : directMatches.isNotEmpty
            ? directMatches
            : rows
                .where((row) => row['food_concept_id']?.toString() == conceptId)
                .toList(growable: false);

    if (candidates.isEmpty) {
      // 明确返回缺失态，方便上游把它标成 fallback，而不是伪装成已命中权威记录。
      return ResolvedFoodVariant(
        foodId: foodId,
        selectedVariantId:
            'FOOD_${foodId.toUpperCase()}#GLOBAL#MISSING#$foodId',
        conceptId: conceptId,
        jurisdiction: 'GLOBAL',
        sourceFamily: 'UNSPECIFIED',
        fallbackUsed: true,
        authoritativeForRegion: false,
      );
    }

    final ranked = [...candidates]..sort((left, right) => _compareFoodRows(
          left,
          right,
          chain: chain,
          sourcePriority: _sourcePriority(
            userProfile.registrationRegion,
            tableRows: regionRows,
            kind: 'food',
          ),
        ));
    final winner = ranked.first;
    final jurisdiction = winner['jurisdiction']?.toString() ?? 'GLOBAL';
    final authoritative = _toBool(winner['is_authoritative_for_region']);
    return ResolvedFoodVariant(
      foodId: foodId,
      selectedVariantId: winner['food_variant_id']?.toString() ?? foodId,
      conceptId: winner['food_concept_id']?.toString() ?? conceptId,
      jurisdiction: jurisdiction,
      sourceFamily: winner['source_family']?.toString() ?? 'UNSPECIFIED',
      fallbackUsed: !authoritative ||
          jurisdiction != chain.first &&
              !chain.contains(jurisdiction.toUpperCase()),
      authoritativeForRegion: authoritative,
    );
  }

  Future<ResolvedDrugVariant> resolveDrugVariant({
    required String drugId,
    required UserProfileRuntimeContext userProfile,
  }) async {
    final chain = await resolveJurisdictionChain(userProfile);
    final regionRows = await database.queryTable('region_jurisdiction_map');
    final rows = await database.queryTable('drug_product_variant');
    final crosswalk = await _findBestCrosswalk(
      domain: 'drug',
      appEntityId: drugId,
      chain: chain,
    );
    final crosswalkMatches = crosswalk == null
        ? const <Map<String, Object?>>[]
        : rows
            .where((row) =>
                row['drug_product_variant_id']?.toString() ==
                crosswalk['variant_id']?.toString())
            .toList(growable: false);
    final directMatches = rows
        .where((row) => row['external_product_code']?.toString() == drugId)
        .toList(growable: false);
    final candidates =
        crosswalkMatches.isNotEmpty ? crosswalkMatches : directMatches;

    if (candidates.isEmpty) {
      // 若官方 crosswalk 与 external_product_code 都没有命中，明确返回缺失态。
      return ResolvedDrugVariant(
        drugId: drugId,
        selectedVariantId:
            'DRUG_${drugId.toUpperCase()}#GLOBAL#MISSING#$drugId',
        conceptId: crosswalk?['concept_id']?.toString() ??
            'DRUG_${drugId.toUpperCase()}',
        jurisdiction: 'GLOBAL',
        regulator: 'UNSPECIFIED',
        route: 'oral',
        dosageForm: 'unspecified',
        releaseType: 'unspecified',
        fallbackUsed: true,
      );
    }

    final ranked = [...candidates]..sort((left, right) => _compareDrugRows(
          left,
          right,
          chain: chain,
          sourcePriority: _sourcePriority(
            userProfile.registrationRegion,
            tableRows: regionRows,
            kind: 'drug',
          ),
        ));
    final winner = ranked.first;
    final jurisdiction = winner['jurisdiction']?.toString() ?? 'GLOBAL';

    return ResolvedDrugVariant(
      drugId: drugId,
      selectedVariantId:
          winner['drug_product_variant_id']?.toString() ?? drugId,
      conceptId: winner['drug_concept_id']?.toString() ??
          crosswalk?['concept_id']?.toString() ??
          'DRUG_${drugId.toUpperCase()}',
      jurisdiction: jurisdiction,
      regulator: winner['regulator']?.toString() ?? 'UNSPECIFIED',
      route: winner['route']?.toString() ?? 'oral',
      dosageForm: winner['dosage_form']?.toString() ?? 'unspecified',
      releaseType: winner['release_type']?.toString() ?? 'unspecified',
      fallbackUsed: jurisdiction != chain.first,
    );
  }

  int _compareFoodRows(
    Map<String, Object?> left,
    Map<String, Object?> right, {
    required List<String> chain,
    required List<String> sourcePriority,
  }) {
    return _compareRows(
      left,
      right,
      chain: chain,
      sourcePriority: sourcePriority,
      variantIdKey: 'food_variant_id',
      sourceKey: 'source_family',
      authoritativeKey: 'is_authoritative_for_region',
    );
  }

  int _compareDrugRows(
    Map<String, Object?> left,
    Map<String, Object?> right, {
    required List<String> chain,
    required List<String> sourcePriority,
  }) {
    return _compareRows(
      left,
      right,
      chain: chain,
      sourcePriority: sourcePriority,
      variantIdKey: 'drug_product_variant_id',
      sourceKey: 'regulator',
      authoritativeKey: null,
    );
  }

  int _compareRows(
    Map<String, Object?> left,
    Map<String, Object?> right, {
    required List<String> chain,
    required List<String> sourcePriority,
    required String variantIdKey,
    required String sourceKey,
    required String? authoritativeKey,
  }) {
    int rank(Map<String, Object?> row) {
      final jurisdiction = row['jurisdiction']?.toString().toUpperCase() ?? '';
      final chainIndex = chain.indexOf(jurisdiction);
      final source = row[sourceKey]?.toString().toUpperCase() ?? '';
      final sourceIndex = sourcePriority.indexOf(source);
      final authoritative = authoritativeKey == null
          ? 0
          : (_toBool(row[authoritativeKey]) ? 1 : 0);

      // 数值越小代表越优先：更靠前辖区、更靠前来源、更权威的记录。
      // 这是最小可用排序，不是最终版的完整 lexicographic provenance priority。
      return ((chainIndex == -1 ? 999 : chainIndex) * 1000) +
          ((sourceIndex == -1 ? 999 : sourceIndex) * 10) -
          authoritative;
    }

    final leftRank = rank(left);
    final rightRank = rank(right);
    if (leftRank != rightRank) {
      return leftRank.compareTo(rightRank);
    }
    return (left[variantIdKey]?.toString() ?? '')
        .compareTo(right[variantIdKey]?.toString() ?? '');
  }

  List<String> _mappedChain(
    Map<String, Map<String, Object?>> byRegion,
    String region,
  ) {
    final row = byRegion[region.toUpperCase()];
    if (row == null) {
      return region.trim().isEmpty ? const [] : [region.toUpperCase()];
    }
    return _decodeJsonList(row['jurisdiction_chain_json']);
  }

  List<String> _sourcePriority(
    String region, {
    required List<Map<String, Object?>> tableRows,
    required String kind,
  }) {
    // 先读数据库里的 region_jurisdiction_map。
    // 若数据库未初始化完整优先链，这里回空数组，由 jurisdiction chain 兜底。
    for (final row in tableRows) {
      final regionCode = row['region_code']?.toString().toUpperCase() ?? '';
      if (regionCode != region.toUpperCase()) continue;
      final key = kind == 'food'
          ? 'food_source_priority_json'
          : 'drug_source_priority_json';
      return _decodeJsonList(row[key]);
    }
    return const <String>[];
  }

  List<String> _decodeJsonList(Object? raw) {
    final text = raw?.toString();
    if (text == null || text.isEmpty) return const <String>[];
    final decoded = jsonDecode(text) as List<dynamic>;
    return decoded
        .map((value) => value.toString().toUpperCase())
        .toList(growable: false);
  }

  Future<Map<String, Object?>?> _findBestCrosswalk({
    required String domain,
    required String appEntityId,
    required List<String> chain,
  }) async {
    final rows = await database.queryTable('concept_variant_crosswalk');
    final candidates = rows
        .where((row) =>
            row['domain']?.toString() == domain &&
            row['status']?.toString() == 'active' &&
            (row['app_entity_id']?.toString() == appEntityId ||
                row['external_id_value']?.toString() == appEntityId))
        .toList(growable: false);
    if (candidates.isEmpty) return null;
    candidates.sort((left, right) {
      final leftJurisdiction =
          left['jurisdiction']?.toString().toUpperCase() ?? '';
      final rightJurisdiction =
          right['jurisdiction']?.toString().toUpperCase() ?? '';
      final leftRank = chain.indexOf(leftJurisdiction);
      final rightRank = chain.indexOf(rightJurisdiction);
      final jurisdictionCompare = (leftRank == -1 ? 999 : leftRank)
          .compareTo(rightRank == -1 ? 999 : rightRank);
      if (jurisdictionCompare != 0) return jurisdictionCompare;
      final confidenceCompare = ((right['confidence'] as num?)?.toDouble() ?? 0)
          .compareTo((left['confidence'] as num?)?.toDouble() ?? 0);
      if (confidenceCompare != 0) return confidenceCompare;
      return '${left['crosswalk_id']}'.compareTo('${right['crosswalk_id']}');
    });
    return candidates.first;
  }

  bool _toBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    return value?.toString() == 'true';
  }

  String? _regionFromLocale(String localeTag) {
    final parts = localeTag.split('-');
    if (parts.length < 2) return null;
    return parts[1].toUpperCase();
  }
}
