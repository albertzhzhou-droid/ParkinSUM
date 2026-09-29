import '../../domain/entities/amino_acid_profile.dart';

/// 食物类别：用于 UI 和规则判断（可扩展）
enum FoodCategory {
  protein,
  carbs,
  vegetable,
  fruit,
  dairy,
  fat,
  beverage,
  other,
}

/// FoodItem：
/// 统一的食物目录条目（可来自内置目录/用户自建/云端）
class FoodItem {
  final String id;
  final String name;
  final FoodCategory category;
  final List<String> aliases;
  final String description;
  final String sourceSystem;
  final String? sourceFoodCode;
  final String jurisdiction;
  // 结构化质地字段：
  // - 只在来源文本足够明确时填值；
  // - 当前用于 recommendation / catalog 的保守吞咽上下文支持；
  // - 不是 authoritative clinical swallowing classification。
  final String? textureClass;
  final int? iddsiLevel;

  // 这里用“每 100g 估算”，用于粗略规则分析（不是营养医学建议）
  //
  // 这些 getter 仍是 non-nullable double（UI 兼容）。但“缺失 ≠ 0”：
  // 当某个营养字段实际上没有来源数据时，它的名字会出现在
  // [missingNutrientFields]，下游（candidate → MealComposition）据此向模型
  // 传 null 而不是 0，从而避免把“未知”伪装成“真实的 0 g”。
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double fiberG;
  final double sodiumMg;

  /// Names of nutrient fields that were NOT present in the source data and are
  /// therefore unknown (NOT a true zero). Recognized values mirror the field
  /// names: 'proteinG', 'carbsG', 'fatG', 'fiberG', 'sodiumMg', 'energyKcal',
  /// 'waterG'. Additive and default-empty so existing call sites are unaffected.
  final Set<String> missingNutrientFields;

  /// Optional model-ready fields, carried only when the source actually
  /// provides them (never fabricated). Absent → null, and the corresponding
  /// name should appear in [missingNutrientFields] when relevant.
  final double? energyKcal;
  final double? waterG;

  /// Actual amino-acid profile (e.g. from USDA FDC amino-acid fields), carried
  /// for the LNAA competition layer. Null → the proxy fallback is used.
  final AminoAcidProfile? aminoAcidProfile;

  /// Source observations retained for each nutrient when the item is projected
  /// from the local CDSS database. These are provenance/context records, not
  /// probability distributions or measurement-uncertainty estimates.
  final List<NutrientObservationEvidence> nutrientObservationEvidence;

  /// Source-reported portion descriptions and gram weights, retained as
  /// evidence only. These records are not selected servings and are not used
  /// to rescale nutrient values or ranking inputs.
  final List<FoodPortionEvidence> foodPortionEvidence;

  /// Linked source documents, concept/variant mappings and scope metadata for
  /// database-projected foods. Caller-provided items may have no such record.
  final FoodCatalogProvenanceEvidence? catalogProvenanceEvidence;

  /// Optional provenance/measurement-context strings preserved when available.
  /// e.g. basisType 'per_100g'; preparationState 'cooked'/'raw';
  /// qualifierKind 'analytical'/'calculated'/'assumed'.
  final String? basisType;
  final String? preparationState;
  final String? qualifierKind;

  FoodItem({
    required this.id,
    required this.name,
    required this.category,
    this.aliases = const <String>[],
    this.description = '',
    this.sourceSystem = 'LOCAL_SEED',
    this.sourceFoodCode,
    this.jurisdiction = 'GLOBAL',
    this.textureClass,
    this.iddsiLevel,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.fiberG,
    required this.sodiumMg,
    this.missingNutrientFields = const <String>{},
    this.energyKcal,
    this.waterG,
    this.aminoAcidProfile,
    this.nutrientObservationEvidence = const <NutrientObservationEvidence>[],
    this.foodPortionEvidence = const <FoodPortionEvidence>[],
    this.catalogProvenanceEvidence,
    this.basisType,
    this.preparationState,
    this.qualifierKind,
  });

  /// True when the named nutrient field has no source data (unknown, not 0).
  bool isNutrientMissing(String field) => missingNutrientFields.contains(field);

  /// 搜索索引文本：
  /// - 这里服务于 UI 目录搜索，不替代数据库里的正式 crosswalk / concept-variant 解析。
  /// - 可以安全合并本地名称、别名、来源系统与简短描述，提升录餐搜索命中率。
  String get searchableText => [
    id,
    name,
    ...aliases,
    description,
    sourceSystem,
    jurisdiction,
    sourceFoodCode ?? '',
  ].join(' ').toLowerCase();

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.name,
    'aliases': aliases,
    'description': description,
    'sourceSystem': sourceSystem,
    'sourceFoodCode': sourceFoodCode,
    'jurisdiction': jurisdiction,
    'textureClass': textureClass,
    'iddsiLevel': iddsiLevel,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
    'fiberG': fiberG,
    'sodiumMg': sodiumMg,
    'missingNutrientFields': missingNutrientFields.toList(),
    'energyKcal': energyKcal,
    'waterG': waterG,
    'aminoAcidProfile': aminoAcidProfile?.toJson(),
    'nutrientObservationEvidence': nutrientObservationEvidence
        .map((evidence) => evidence.toJson())
        .toList(growable: false),
    'foodPortionEvidence': foodPortionEvidence
        .map((evidence) => evidence.toJson())
        .toList(growable: false),
    'catalogProvenanceEvidence': catalogProvenanceEvidence?.toJson(),
    'basisType': basisType,
    'preparationState': preparationState,
    'qualifierKind': qualifierKind,
  };

  static FoodItem fromJson(Map<String, dynamic> json) {
    final catName = (json['category'] as String?) ?? 'other';
    final cat = FoodCategory.values.firstWhere(
      (c) => c.name == catName,
      orElse: () => FoodCategory.other,
    );

    return FoodItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: cat,
      aliases: (json['aliases'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(growable: false),
      description: (json['description'] as String?) ?? '',
      sourceSystem: (json['sourceSystem'] as String?) ?? 'LOCAL_SEED',
      sourceFoodCode: json['sourceFoodCode'] as String?,
      jurisdiction: (json['jurisdiction'] as String?) ?? 'GLOBAL',
      textureClass: json['textureClass'] as String?,
      iddsiLevel: (json['iddsiLevel'] as num?)?.toInt(),
      proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
      carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
      fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
      fiberG: (json['fiberG'] as num?)?.toDouble() ?? 0,
      sodiumMg: (json['sodiumMg'] as num?)?.toDouble() ?? 0,
      missingNutrientFields:
          (json['missingNutrientFields'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toSet(),
      energyKcal: (json['energyKcal'] as num?)?.toDouble(),
      waterG: (json['waterG'] as num?)?.toDouble(),
      aminoAcidProfile: json['aminoAcidProfile'] is Map<String, dynamic>
          ? AminoAcidProfile.fromJson(
              json['aminoAcidProfile'] as Map<String, dynamic>,
            )
          : null,
      nutrientObservationEvidence:
          (json['nutrientObservationEvidence'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(NutrientObservationEvidence.fromJson)
              .toList(growable: false),
      foodPortionEvidence:
          (json['foodPortionEvidence'] as List<dynamic>? ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(FoodPortionEvidence.fromJson)
              .toList(growable: false),
      catalogProvenanceEvidence:
          json['catalogProvenanceEvidence'] is Map<String, dynamic>
          ? FoodCatalogProvenanceEvidence.fromJson(
              json['catalogProvenanceEvidence'] as Map<String, dynamic>,
            )
          : null,
      basisType: json['basisType'] as String?,
      preparationState: json['preparationState'] as String?,
      qualifierKind: json['qualifierKind'] as String?,
    );
  }
}

/// One source row supporting (or qualifying) a nutrient observation.
///
/// The local database may hold exact, interval, trace, missing or otherwise
/// uncertain values. All source fields are kept as supplied; only an exact
/// numeric row marked [selectedForLegacyPointProjection] currently feeds the
/// legacy point-valued FoodItem nutrient fields.
class NutrientObservationEvidence {
  final String? observationId;
  final String? domain;
  final String? entityType;
  final String? entityKey;
  final String? attributeCode;
  final String? valueType;
  final double? valueNum;
  final double? low;
  final double? high;
  final String? qualifierKind;
  final String? rawValueText;
  final String? unit;
  final String? basisType;
  final double? basisAmount;
  final String? scopeHash;
  final String? sourceDocId;
  final String? recordLocator;
  final String? methodCode;
  final double? extractionConfidence;
  final bool selectedForLegacyPointProjection;

  const NutrientObservationEvidence({
    required this.observationId,
    required this.domain,
    required this.entityType,
    required this.entityKey,
    required this.attributeCode,
    required this.valueType,
    required this.valueNum,
    required this.low,
    required this.high,
    required this.qualifierKind,
    required this.rawValueText,
    required this.unit,
    required this.basisType,
    required this.basisAmount,
    required this.scopeHash,
    required this.sourceDocId,
    required this.recordLocator,
    required this.methodCode,
    required this.extractionConfidence,
    required this.selectedForLegacyPointProjection,
  });

  factory NutrientObservationEvidence.fromJson(Map<String, dynamic> json) {
    String? asString(Object? value) => value?.toString();
    double? asDouble(Object? value) => value is num ? value.toDouble() : null;

    return NutrientObservationEvidence(
      observationId: asString(json['observation_id']),
      domain: asString(json['domain']),
      entityType: asString(json['entity_type']),
      entityKey: asString(json['entity_key']),
      attributeCode: asString(json['attribute_code']),
      valueType: asString(json['value_type']),
      valueNum: asDouble(json['value_num']),
      low: asDouble(json['low']),
      high: asDouble(json['high']),
      qualifierKind: asString(json['qualifier_kind']),
      rawValueText: asString(json['raw_value_text']),
      unit: asString(json['unit']),
      basisType: asString(json['basis_type']),
      basisAmount: asDouble(json['basis_amount']),
      scopeHash: asString(json['scope_hash']),
      sourceDocId: asString(json['source_doc_id']),
      recordLocator: asString(json['record_locator']),
      methodCode: asString(json['method_code']),
      extractionConfidence: asDouble(json['extraction_confidence']),
      selectedForLegacyPointProjection:
          json['selected_for_legacy_point_projection'] == true,
    );
  }

  Map<String, dynamic> toJson() => {
    'observation_id': observationId,
    'domain': domain,
    'entity_type': entityType,
    'entity_key': entityKey,
    'attribute_code': attributeCode,
    'value_type': valueType,
    'value_num': valueNum,
    'low': low,
    'high': high,
    'qualifier_kind': qualifierKind,
    'raw_value_text': rawValueText,
    'unit': unit,
    'basis_type': basisType,
    'basis_amount': basisAmount,
    'scope_hash': scopeHash,
    'source_doc_id': sourceDocId,
    'record_locator': recordLocator,
    'method_code': methodCode,
    'extraction_confidence': extractionConfidence,
    'selected_for_legacy_point_projection': selectedForLegacyPointProjection,
  };
}

/// One source-reported FDC food portion record.
///
/// The raw portion fields are retained for provenance. Parsed fields make the
/// source's amount, unit label and gram weight queryable, but do not establish
/// that a portion is appropriate for a user or permit nutrient conversion.
class FoodPortionEvidence {
  final String? sourceDocId;
  final String? sourceFoodId;
  final String? recordLocator;
  final int? sequenceNumber;
  final double? amount;
  final int? measureUnitId;
  final String? measureUnitName;
  final String? measureUnitAbbreviation;
  final String? portionDescription;
  final String? modifier;
  final double? gramWeight;
  final int? dataPoints;
  final String? footnote;
  final int? minYearAcquired;
  final Map<String, Object?> sourceFields;

  FoodPortionEvidence({
    required this.sourceDocId,
    required this.sourceFoodId,
    required this.recordLocator,
    required this.sequenceNumber,
    required this.amount,
    required this.measureUnitId,
    required this.measureUnitName,
    required this.measureUnitAbbreviation,
    required this.portionDescription,
    required this.modifier,
    required this.gramWeight,
    required this.dataPoints,
    required this.footnote,
    required this.minYearAcquired,
    required Map<String, Object?> sourceFields,
  }) : sourceFields = Map<String, Object?>.unmodifiable(sourceFields);

  factory FoodPortionEvidence.fromFdc({
    required String sourceDocId,
    required String sourceFoodId,
    required int portionIndex,
    required Map<dynamic, dynamic> portion,
  }) {
    final measureUnit = portion['measureUnit'];
    final measureUnitMap = measureUnit is Map ? measureUnit : const {};
    final sourceFields = <String, Object?>{
      for (final entry in portion.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    return FoodPortionEvidence(
      sourceDocId: sourceDocId,
      sourceFoodId: sourceFoodId,
      recordLocator: '$sourceFoodId:foodPortions:$portionIndex',
      sequenceNumber: _portionInt(portion['sequenceNumber']),
      amount: _portionDouble(portion['amount']),
      measureUnitId: _portionInt(measureUnitMap['id']),
      measureUnitName: _portionString(measureUnitMap['name']),
      measureUnitAbbreviation: _portionString(measureUnitMap['abbreviation']),
      portionDescription: _portionString(portion['portionDescription']),
      modifier: _portionString(portion['modifier']),
      gramWeight: _portionDouble(portion['gramWeight']),
      dataPoints: _portionInt(portion['dataPoints']),
      footnote: _portionString(portion['footnote']),
      minYearAcquired: _portionInt(portion['minYearAcquired']),
      sourceFields: sourceFields,
    );
  }

  factory FoodPortionEvidence.fromJson(Map<String, dynamic> json) {
    final rawSourceFields = json['source_fields'];
    return FoodPortionEvidence(
      sourceDocId: _portionString(json['source_doc_id']),
      sourceFoodId: _portionString(json['source_food_id']),
      recordLocator: _portionString(json['record_locator']),
      sequenceNumber: _portionInt(json['sequence_number']),
      amount: _portionDouble(json['amount']),
      measureUnitId: _portionInt(json['measure_unit_id']),
      measureUnitName: _portionString(json['measure_unit_name']),
      measureUnitAbbreviation: _portionString(
        json['measure_unit_abbreviation'],
      ),
      portionDescription: _portionString(json['portion_description']),
      modifier: _portionString(json['modifier']),
      gramWeight: _portionDouble(json['gram_weight']),
      dataPoints: _portionInt(json['data_points']),
      footnote: _portionString(json['footnote']),
      minYearAcquired: _portionInt(json['min_year_acquired']),
      sourceFields: rawSourceFields is Map
          ? <String, Object?>{
              for (final entry in rawSourceFields.entries)
                if (entry.key is String) entry.key as String: entry.value,
            }
          : const <String, Object?>{},
    );
  }

  Map<String, dynamic> toJson() => {
    'source_doc_id': sourceDocId,
    'source_food_id': sourceFoodId,
    'record_locator': recordLocator,
    'sequence_number': sequenceNumber,
    'amount': amount,
    'measure_unit_id': measureUnitId,
    'measure_unit_name': measureUnitName,
    'measure_unit_abbreviation': measureUnitAbbreviation,
    'portion_description': portionDescription,
    'modifier': modifier,
    'gram_weight': gramWeight,
    'data_points': dataPoints,
    'footnote': footnote,
    'min_year_acquired': minYearAcquired,
    'source_fields': sourceFields,
  };
}

String? _portionString(Object? value) => value is String ? value : null;

double? _portionDouble(Object? value) =>
    value is num && value.isFinite ? value.toDouble() : null;

int? _portionInt(Object? value) {
  if (value is! num || !value.isFinite) return null;
  final integer = value.toInt();
  return integer.toDouble() == value.toDouble() ? integer : null;
}

/// Catalog-level evidence linked to one projected food variant.
class FoodCatalogProvenanceEvidence {
  final List<FoodSourceDocumentEvidence> sourceDocuments;
  final List<FoodVariantScopeEvidence> variantScopes;
  final List<FoodConceptVariantMatchEvidence> conceptVariantMatches;

  const FoodCatalogProvenanceEvidence({
    this.sourceDocuments = const <FoodSourceDocumentEvidence>[],
    this.variantScopes = const <FoodVariantScopeEvidence>[],
    this.conceptVariantMatches = const <FoodConceptVariantMatchEvidence>[],
  });

  factory FoodCatalogProvenanceEvidence.fromJson(Map<String, dynamic> json) =>
      FoodCatalogProvenanceEvidence(
        sourceDocuments:
            (json['source_documents'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(FoodSourceDocumentEvidence.fromJson)
                .toList(growable: false),
        variantScopes: (json['variant_scopes'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(FoodVariantScopeEvidence.fromJson)
            .toList(growable: false),
        conceptVariantMatches:
            (json['concept_variant_matches'] as List<dynamic>? ?? const [])
                .whereType<Map<String, dynamic>>()
                .map(FoodConceptVariantMatchEvidence.fromJson)
                .toList(growable: false),
      );

  Map<String, dynamic> toJson() => {
    'source_documents': sourceDocuments
        .map((record) => record.toJson())
        .toList(growable: false),
    'variant_scopes': variantScopes
        .map((record) => record.toJson())
        .toList(growable: false),
    'concept_variant_matches': conceptVariantMatches
        .map((record) => record.toJson())
        .toList(growable: false),
  };
}

/// Metadata from `source_document`, joined by an observation or crosswalk ID.
/// The persisted raw payload is represented only by a fresh SHA-256 digest;
/// the payload and its proprietary or non-commercial content are not copied.
class FoodSourceDocumentEvidence {
  static const String payloadDigestAlgorithm = 'sha256';
  static const String payloadDigestScope =
      'persisted_raw_payload_utf8_text_after_ingestion';

  final String sourceDocId;
  final String resolutionStatus;
  final String? sourceFamily;
  final String? dataTier;
  final String? ingestionStrategy;
  final String? organization;
  final String? jurisdiction;
  final String? docType;
  final String? title;
  final String? originUrl;
  final int? publishedAtEpochMs;
  final int? effectiveAtEpochMs;
  final String? language;
  final String? licenseNote;
  final String? sourceRegistryChecksum;
  final String? payloadSha256;
  final bool storedPayloadPresent;
  final String? sourceStatus;

  const FoodSourceDocumentEvidence({
    required this.sourceDocId,
    required this.resolutionStatus,
    required this.sourceFamily,
    required this.dataTier,
    required this.ingestionStrategy,
    required this.organization,
    required this.jurisdiction,
    required this.docType,
    required this.title,
    required this.originUrl,
    required this.publishedAtEpochMs,
    required this.effectiveAtEpochMs,
    required this.language,
    required this.licenseNote,
    required this.sourceRegistryChecksum,
    required this.payloadSha256,
    required this.storedPayloadPresent,
    required this.sourceStatus,
  });

  factory FoodSourceDocumentEvidence.fromJson(
    Map<String, dynamic> json,
  ) => FoodSourceDocumentEvidence(
    sourceDocId: _evidenceString(json['source_doc_id']) ?? '',
    resolutionStatus: _evidenceString(json['resolution_status']) ?? 'resolved',
    sourceFamily: _evidenceString(json['source_family']),
    dataTier: _evidenceString(json['data_tier']),
    ingestionStrategy: _evidenceString(json['ingestion_strategy']),
    organization: _evidenceString(json['organization']),
    jurisdiction: _evidenceString(json['jurisdiction']),
    docType: _evidenceString(json['doc_type']),
    title: _evidenceString(json['title']),
    originUrl: _evidenceString(json['origin_url']),
    publishedAtEpochMs: _evidenceInt(json['published_at']),
    effectiveAtEpochMs: _evidenceInt(json['effective_at']),
    language: _evidenceString(json['language']),
    licenseNote: _evidenceString(json['license_note']),
    sourceRegistryChecksum: _evidenceString(json['source_registry_checksum']),
    payloadSha256: _evidenceString(json['payload_sha256']),
    storedPayloadPresent: json['stored_payload_present'] == true,
    sourceStatus: _evidenceString(json['source_status']),
  );

  Map<String, dynamic> toJson() => {
    'source_doc_id': sourceDocId,
    'resolution_status': resolutionStatus,
    'source_family': sourceFamily,
    'data_tier': dataTier,
    'ingestion_strategy': ingestionStrategy,
    'organization': organization,
    'jurisdiction': jurisdiction,
    'doc_type': docType,
    'title': title,
    'origin_url': originUrl,
    'published_at': publishedAtEpochMs,
    'effective_at': effectiveAtEpochMs,
    'language': language,
    'license_note': licenseNote,
    // Existing source_document.checksum is retained as supplied; this model
    // does not assume its algorithm or treat it as the payload digest.
    'source_registry_checksum': sourceRegistryChecksum,
    'payload_sha256': payloadSha256,
    'payload_digest_algorithm': payloadDigestAlgorithm,
    'payload_digest_scope': payloadDigestScope,
    'stored_payload_present': storedPayloadPresent,
    'source_status': sourceStatus,
  };
}

/// Source-specific preparation and sampling scope linked through scope_hash.
class FoodVariantScopeEvidence {
  final String scopeHash;
  final String resolutionStatus;
  final String? jurisdiction;
  final String? brand;
  final String? preparationState;
  final String? cookingState;
  final String? plantPart;
  final String? cultivar;
  final String? samplingFrame;
  final String? dosageForm;
  final String? releaseType;
  final String? saltForm;
  final String? route;

  const FoodVariantScopeEvidence({
    required this.scopeHash,
    required this.resolutionStatus,
    required this.jurisdiction,
    required this.brand,
    required this.preparationState,
    required this.cookingState,
    required this.plantPart,
    required this.cultivar,
    required this.samplingFrame,
    required this.dosageForm,
    required this.releaseType,
    required this.saltForm,
    required this.route,
  });

  factory FoodVariantScopeEvidence.fromJson(Map<String, dynamic> json) =>
      FoodVariantScopeEvidence(
        scopeHash: _evidenceString(json['scope_hash']) ?? '',
        resolutionStatus:
            _evidenceString(json['resolution_status']) ?? 'resolved',
        jurisdiction: _evidenceString(json['jurisdiction']),
        brand: _evidenceString(json['brand']),
        preparationState: _evidenceString(json['preparation_state']),
        cookingState: _evidenceString(json['cooking_state']),
        plantPart: _evidenceString(json['plant_part']),
        cultivar: _evidenceString(json['cultivar']),
        samplingFrame: _evidenceString(json['sampling_frame']),
        dosageForm: _evidenceString(json['dosage_form']),
        releaseType: _evidenceString(json['release_type']),
        saltForm: _evidenceString(json['salt_form']),
        route: _evidenceString(json['route']),
      );

  Map<String, dynamic> toJson() => {
    'scope_hash': scopeHash,
    'resolution_status': resolutionStatus,
    'jurisdiction': jurisdiction,
    'brand': brand,
    'preparation_state': preparationState,
    'cooking_state': cookingState,
    'plant_part': plantPart,
    'cultivar': cultivar,
    'sampling_frame': samplingFrame,
    'dosage_form': dosageForm,
    'release_type': releaseType,
    'salt_form': saltForm,
    'route': route,
  };
}

/// Recorded concept/variant crosswalk information. Its confidence is the
/// source record's mapping value, not a validated probability or match score.
class FoodConceptVariantMatchEvidence {
  final String crosswalkId;
  final String domain;
  final String appEntityId;
  final String conceptId;
  final String variantId;
  final String externalIdSystem;
  final String externalIdValue;
  final String jurisdiction;
  final String sourceDocId;
  final String? importRunId;
  final double? recordedConfidence;
  final String status;
  final String mappingPayloadJson;
  final int? createdAtEpochMs;
  final bool selectedForProjectedFoodId;

  const FoodConceptVariantMatchEvidence({
    required this.crosswalkId,
    required this.domain,
    required this.appEntityId,
    required this.conceptId,
    required this.variantId,
    required this.externalIdSystem,
    required this.externalIdValue,
    required this.jurisdiction,
    required this.sourceDocId,
    required this.importRunId,
    required this.recordedConfidence,
    required this.status,
    required this.mappingPayloadJson,
    required this.createdAtEpochMs,
    required this.selectedForProjectedFoodId,
  });

  factory FoodConceptVariantMatchEvidence.fromJson(Map<String, dynamic> json) =>
      FoodConceptVariantMatchEvidence(
        crosswalkId: _evidenceString(json['crosswalk_id']) ?? '',
        domain: _evidenceString(json['domain']) ?? '',
        appEntityId: _evidenceString(json['app_entity_id']) ?? '',
        conceptId: _evidenceString(json['concept_id']) ?? '',
        variantId: _evidenceString(json['variant_id']) ?? '',
        externalIdSystem: _evidenceString(json['external_id_system']) ?? '',
        externalIdValue: _evidenceString(json['external_id_value']) ?? '',
        jurisdiction: _evidenceString(json['jurisdiction']) ?? '',
        sourceDocId: _evidenceString(json['source_doc_id']) ?? '',
        importRunId: _evidenceString(json['import_run_id']),
        recordedConfidence: _evidenceDouble(
          json['recorded_confidence'] ?? json['confidence'],
        ),
        status: _evidenceString(json['status']) ?? '',
        mappingPayloadJson: _evidenceString(json['mapping_payload_json']) ?? '',
        createdAtEpochMs: _evidenceInt(json['created_at']),
        selectedForProjectedFoodId:
            json['selected_for_projected_food_id'] == true,
      );

  Map<String, dynamic> toJson() => {
    'crosswalk_id': crosswalkId,
    'domain': domain,
    'app_entity_id': appEntityId,
    'concept_id': conceptId,
    'variant_id': variantId,
    'external_id_system': externalIdSystem,
    'external_id_value': externalIdValue,
    'jurisdiction': jurisdiction,
    'source_doc_id': sourceDocId,
    'import_run_id': importRunId,
    'recorded_confidence': recordedConfidence,
    'status': status,
    'mapping_payload_json': mappingPayloadJson,
    'created_at': createdAtEpochMs,
    'selected_for_projected_food_id': selectedForProjectedFoodId,
  };
}

String? _evidenceString(Object? value) => value?.toString();

double? _evidenceDouble(Object? value) =>
    value is num ? value.toDouble() : null;

int? _evidenceInt(Object? value) {
  if (value is DateTime) return value.millisecondsSinceEpoch;
  return value is num ? value.toInt() : null;
}
