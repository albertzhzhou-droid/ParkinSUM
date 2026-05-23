import '../../core/utils/qualified_value_parser.dart';

/// 数据层级：
/// - P0: 当前直接驱动核心 fact/variant 的官方基础源；
/// - P1: 官方但非核心 bulk/API、或受控/辅源/饮食指南层；
/// - P2: 论文证据卡 / 规则解释增强层；
/// - P3/P4: 预留给未来更弱或更实验性的来源层。
class KnowledgeDataTier {
  static const String p0 = 'P0';
  static const String p1 = 'P1';
  static const String p2 = 'P2';
  static const String p3 = 'P3';
  static const String p4 = 'P4';
}

/// 来源接入策略：
/// - authoritative_direct: 官方数据库/API/下载包直接抓取；
/// - official_reference: 官方页面/参考页面，仅作元数据或解释源；
/// - controlled_export: 官方或准官方，但需要登录/授权导出；
/// - clinical_evidence_card: 论文元数据卡，不进入主事实层；
/// - future_planned: 已确认值得接入，但当前尚无稳定出口。
class SourceIngestionStrategy {
  static const String authoritativeDirect = 'authoritative_direct';
  static const String officialReference = 'official_reference';
  static const String controlledExport = 'controlled_export';
  static const String clinicalEvidenceCard = 'clinical_evidence_card';
  static const String futurePlanned = 'future_planned';
}

class SourceDocumentRecord {
  final String sourceDocId;
  final String sourceFamily;
  final String dataTier;
  final String ingestionStrategy;
  final String organization;
  final String jurisdiction;
  final String docType;
  final String title;
  final String originUrl;
  final DateTime? publishedAt;
  final DateTime? effectiveAt;
  final String language;
  final String licenseNote;
  final String checksum;
  final String sourceStatus;
  final String rawPayload;

  const SourceDocumentRecord({
    required this.sourceDocId,
    required this.sourceFamily,
    this.dataTier = KnowledgeDataTier.p0,
    this.ingestionStrategy = SourceIngestionStrategy.authoritativeDirect,
    required this.organization,
    required this.jurisdiction,
    required this.docType,
    required this.title,
    required this.originUrl,
    required this.publishedAt,
    required this.effectiveAt,
    required this.language,
    required this.licenseNote,
    required this.checksum,
    required this.sourceStatus,
    required this.rawPayload,
  });
}

class FoodConceptRecord {
  final String foodConceptId;
  final String canonicalNameEn;
  final String canonicalNameZh;
  final String foodGroup;

  const FoodConceptRecord({
    required this.foodConceptId,
    required this.canonicalNameEn,
    required this.canonicalNameZh,
    required this.foodGroup,
  });
}

class FoodVariantRecord {
  final String foodVariantId;
  final String foodConceptId;
  final String jurisdiction;
  final String sourceFamily;
  final String? sourceFoodCode;
  final String displayNameLocal;
  final bool isAuthoritativeForRegion;
  final bool isAuthoritativeFallback;
  final String status;
  final String fallbackChainJson;

  const FoodVariantRecord({
    required this.foodVariantId,
    required this.foodConceptId,
    required this.jurisdiction,
    required this.sourceFamily,
    required this.sourceFoodCode,
    required this.displayNameLocal,
    required this.isAuthoritativeForRegion,
    required this.isAuthoritativeFallback,
    required this.status,
    required this.fallbackChainJson,
  });
}

class DrugConceptRecord {
  final String drugConceptId;
  final String genericName;
  final String atcLikeCode;

  const DrugConceptRecord({
    required this.drugConceptId,
    required this.genericName,
    required this.atcLikeCode,
  });
}

class DrugProductVariantRecord {
  final String drugProductVariantId;
  final String drugConceptId;
  final String jurisdiction;
  final String regulator;
  final String externalProductCode;
  final String route;
  final String dosageForm;
  final String releaseType;
  final String labelVersion;
  final String sourceStatus;

  const DrugProductVariantRecord({
    required this.drugProductVariantId,
    required this.drugConceptId,
    required this.jurisdiction,
    required this.regulator,
    required this.externalProductCode,
    required this.route,
    required this.dosageForm,
    required this.releaseType,
    required this.labelVersion,
    required this.sourceStatus,
  });
}

/// 药品标签分段：
/// - 用于把 DailyMed / DPD / EMA / PMDA 的正文拆成可检索 section；
/// - 目前优先承接与食物/给药冲突高度相关的段落。
class DrugLabelSectionRecord {
  final String sectionId;
  final String drugProductVariantId;
  final String sourceDocId;
  final String sectionKey;
  final String sectionTitle;
  final String sectionText;

  const DrugLabelSectionRecord({
    required this.sectionId,
    required this.drugProductVariantId,
    required this.sourceDocId,
    required this.sectionKey,
    required this.sectionTitle,
    required this.sectionText,
  });
}

/// 药品附属编码：
/// - 当前主要用于 DailyMed NDC；
/// - 后续也可以扩展到 DIN / applNo 之外的其他外部编码。
class DrugProductCodeRecord {
  final String productCodeId;
  final String drugProductVariantId;
  final String sourceDocId;
  final String codeSystem;
  final String codeValue;
  final String? displayText;

  const DrugProductCodeRecord({
    required this.productCodeId,
    required this.drugProductVariantId,
    required this.sourceDocId,
    required this.codeSystem,
    required this.codeValue,
    required this.displayText,
  });
}

/// 药品包装信息：
/// - 主要承接 DailyMed packaging / DPD packaging 等子资源；
/// - 当前是最小结构化视图，先保证“可查、可审计、可回放”。
class DrugProductPackagingRecord {
  final String packagingId;
  final String drugProductVariantId;
  final String sourceDocId;
  final String? packageCode;
  final String description;
  final String? marketingStatus;

  const DrugProductPackagingRecord({
    required this.packagingId,
    required this.drugProductVariantId,
    required this.sourceDocId,
    required this.packageCode,
    required this.description,
    required this.marketingStatus,
  });
}

/// 药品媒体资源：
/// - 承接 DailyMed media、DPD 专论 PDF、HTML 页附属链接等；
/// - 这些资源本身不是规则，但能支撑审计与人工复核。
class DrugProductMediaRecord {
  final String mediaId;
  final String drugProductVariantId;
  final String sourceDocId;
  final String mediaType;
  final String mediaUrl;
  final String? caption;

  const DrugProductMediaRecord({
    required this.mediaId,
    required this.drugProductVariantId,
    required this.sourceDocId,
    required this.mediaType,
    required this.mediaUrl,
    required this.caption,
  });
}

/// Stable concept/variant mapping layer.
///
/// This avoids deriving concepts from display IDs such as FOOD_xxx and keeps
/// each external identifier traceable to its source document or import run.
class ConceptVariantCrosswalkRecord {
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
  final double confidence;
  final String status;
  final String mappingPayloadJson;
  final DateTime createdAt;

  const ConceptVariantCrosswalkRecord({
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
    required this.confidence,
    required this.status,
    required this.mappingPayloadJson,
    required this.createdAt,
  });
}

class ObservationRecord {
  final String observationId;
  final String domain;
  final String entityType;
  final String entityKey;
  final String attributeCode;
  final String valueType;
  final QualifiedValue value;
  final String unit;
  final String basisType;
  final double? basisAmount;
  final String scopeHash;
  final String sourceDocId;
  final String recordLocator;
  final String? methodCode;
  final double extractionConfidence;

  const ObservationRecord({
    required this.observationId,
    required this.domain,
    required this.entityType,
    required this.entityKey,
    required this.attributeCode,
    required this.valueType,
    required this.value,
    required this.unit,
    required this.basisType,
    required this.basisAmount,
    required this.scopeHash,
    required this.sourceDocId,
    required this.recordLocator,
    required this.methodCode,
    required this.extractionConfidence,
  });
}

class VariantScopeRecord {
  final String scopeHash;
  final String jurisdiction;
  final String? brand;
  final String? dosageForm;
  final String? releaseType;
  final String? saltForm;
  final String? route;
  final String? preparationState;
  final String? cookingState;
  final String? plantPart;
  final String? cultivar;
  final String? samplingFrame;

  const VariantScopeRecord({
    required this.scopeHash,
    required this.jurisdiction,
    required this.brand,
    required this.dosageForm,
    required this.releaseType,
    required this.saltForm,
    required this.route,
    required this.preparationState,
    required this.cookingState,
    required this.plantPart,
    required this.cultivar,
    required this.samplingFrame,
  });
}

class RegionJurisdictionMapRecord {
  final String regionCode;
  final String jurisdictionChainJson;
  final String foodSourcePriorityJson;
  final String drugSourcePriorityJson;
  final String dietGuidelineSource;

  const RegionJurisdictionMapRecord({
    required this.regionCode,
    required this.jurisdictionChainJson,
    required this.foodSourcePriorityJson,
    required this.drugSourcePriorityJson,
    required this.dietGuidelineSource,
  });
}

class LocaleResourceBundleRecord {
  final String localeTag;
  final String namespace;
  final String key;
  final String text;
  final String? pluralRule;

  const LocaleResourceBundleRecord({
    required this.localeTag,
    required this.namespace,
    required this.key,
    required this.text,
    required this.pluralRule,
  });
}

class CountryDietProfileRecord {
  final String countryCode;
  final String guidelineSource;
  final String mealPatternJson;
  final String stapleFoodsJson;
  final String preferredProteinSourcesJson;
  final String avoidanceNotesJson;

  const CountryDietProfileRecord({
    required this.countryCode,
    required this.guidelineSource,
    required this.mealPatternJson,
    required this.stapleFoodsJson,
    required this.preferredProteinSourcesJson,
    required this.avoidanceNotesJson,
  });
}

class MealTemplateRecord {
  final String mealTemplateId;
  final String countryCode;
  final String mealSlot;
  final String templateJson;
  final String textureLevel;

  const MealTemplateRecord({
    required this.mealTemplateId,
    required this.countryCode,
    required this.mealSlot,
    required this.templateJson,
    required this.textureLevel,
  });
}

class ResolvedFactRecord {
  final String factId;
  final String entityKey;
  final String attributeCode;
  final String scopeHash;
  final String resolutionStatus;
  final String chosenObservationId;
  final QualifiedValue resolvedValue;
  final String resolvedUnit;
  final String resolutionPolicyId;
  final String snapshotId;
  final String factVersion;
  final bool manualOverride;

  const ResolvedFactRecord({
    required this.factId,
    required this.entityKey,
    required this.attributeCode,
    required this.scopeHash,
    required this.resolutionStatus,
    required this.chosenObservationId,
    required this.resolvedValue,
    required this.resolvedUnit,
    required this.resolutionPolicyId,
    required this.snapshotId,
    required this.factVersion,
    required this.manualOverride,
  });
}

class EngineSnapshotRecord {
  final String snapshotId;
  final String factsVersion;
  final String rulesVersion;
  final DateTime createdAt;
  final DateTime? promotedAt;
  final String? rollbackParent;
  final String inputHash;

  const EngineSnapshotRecord({
    required this.snapshotId,
    required this.factsVersion,
    required this.rulesVersion,
    required this.createdAt,
    required this.promotedAt,
    required this.rollbackParent,
    required this.inputHash,
  });
}

/// 快照发布 / 导出 / 导入记录：
/// - 让“当前用了哪个 snapshot、发布到了哪个 channel、导出了哪个 bundle”
///   成为可查询、可审计的后台链路；
/// - 当前先实现本地 channel 与本地 bundle 分发，为后续中心化后端做接口收口。
class SnapshotDistributionRecord {
  final String distributionId;
  final String snapshotId;
  final String channel;
  final String distributionType;
  final String status;
  final String? artifactPath;
  final String manifestJson;
  final String? errorMessage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const SnapshotDistributionRecord({
    required this.distributionId,
    required this.snapshotId,
    required this.channel,
    required this.distributionType,
    required this.status,
    required this.artifactPath,
    required this.manifestJson,
    required this.errorMessage,
    required this.createdAt,
    required this.completedAt,
  });
}

/// 导入会话记录：
/// - 为 staging / promote / rollback 留下显式事件；
/// - 当前不替代更完整的作业系统，但已经能提供最小发布追踪。
class IngestionRunRecord {
  final String runId;
  final String sourceFamily;
  final String stage;
  final String status;
  final String snapshotId;
  final String? parentSnapshotId;
  final String notesJson;
  final DateTime createdAt;
  final DateTime? completedAt;

  const IngestionRunRecord({
    required this.runId,
    required this.sourceFamily,
    required this.stage,
    required this.status,
    required this.snapshotId,
    required this.parentSnapshotId,
    required this.notesJson,
    required this.createdAt,
    required this.completedAt,
  });
}

class RuntimeEventRecord {
  final String eventId;
  final String patientId;
  final String eventType;
  final String snapshotId;
  final String contextJson;
  final String machineReadableJson;
  final String humanReadableMarkdown;
  final String jurisdiction;
  final String timezone;
  final DateTime createdAt;

  const RuntimeEventRecord({
    required this.eventId,
    required this.patientId,
    required this.eventType,
    required this.snapshotId,
    required this.contextJson,
    required this.machineReadableJson,
    required this.humanReadableMarkdown,
    required this.jurisdiction,
    required this.timezone,
    required this.createdAt,
  });
}

class ConflictAuditLogRecord {
  final String auditId;
  final String snapshotId;
  final String runId;
  final String auditType;
  final String target;
  final String decision;
  final String winningRuleIdsJson;
  final String suppressedRuleIdsJson;
  final String sourceDocRefsJson;
  final String inputHash;
  final String decisionReason;
  final String machineActionsJson;
  final String humanMessage;
  final bool needsHumanReview;
  final DateTime createdAt;

  const ConflictAuditLogRecord({
    required this.auditId,
    required this.snapshotId,
    required this.runId,
    required this.auditType,
    required this.target,
    required this.decision,
    required this.winningRuleIdsJson,
    required this.suppressedRuleIdsJson,
    required this.sourceDocRefsJson,
    required this.inputHash,
    required this.decisionReason,
    required this.machineActionsJson,
    required this.humanMessage,
    required this.needsHumanReview,
    required this.createdAt,
  });
}

/// 轻量人工复核工单：
/// - 当前只承接 release/runtime governance 的核心阻断项；
/// - 仍是 backend-core 雏形，不包含 UI 分派、权限流或多人协作状态机。
class HumanReviewTicketRecord {
  final String ticketId;
  final String reasonCode;
  final String severity;
  final String targetType;
  final String targetId;
  final String snapshotId;
  final String? runId;
  final String sourceDocRefsJson;
  final String suggestedAction;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;

  const HumanReviewTicketRecord({
    required this.ticketId,
    required this.reasonCode,
    required this.severity,
    required this.targetType,
    required this.targetId,
    required this.snapshotId,
    required this.runId,
    required this.sourceDocRefsJson,
    required this.suggestedAction,
    required this.status,
    required this.createdAt,
    required this.resolvedAt,
  });
}

class RecommendationAuditLogRecord {
  final String recAuditId;
  final String userId;
  final String mealSlot;
  final String snapshotId;
  final String jurisdictionChainJson;
  final String mealCandidatesJson;
  final String rejectedByRulesJson;
  final String acceptedChoicesJson;
  final String scoreBreakdownJson;
  final bool fallbackUsed;
  final DateTime createdAt;

  const RecommendationAuditLogRecord({
    required this.recAuditId,
    required this.userId,
    required this.mealSlot,
    required this.snapshotId,
    required this.jurisdictionChainJson,
    required this.mealCandidatesJson,
    required this.rejectedByRulesJson,
    required this.acceptedChoicesJson,
    required this.scoreBreakdownJson,
    required this.fallbackUsed,
    required this.createdAt,
  });
}
