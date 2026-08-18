import '../../domain/entities/cdss_records.dart';
import 'cdss_database.dart';

/// An empty [CdssDatabase] for deterministic offline use (replay tools, demos,
/// and tests). Reads return empty tables and catalog writes are discarded, so
/// anything wired to it falls back to built-in synthetic seeds. It performs no
/// I/O and reaches no network.
///
/// **Audit writes are the exception.** They are retained in process memory and
/// exposed via [conflictAuditLog] / [recommendationAuditLog]. This is the
/// backend the public demo and the replay tooling run on, so discarding audit
/// records here would mean the app's audit trail does not exist precisely
/// where reviewers look for it. Retention is deliberately non-durable: the
/// records live for the lifetime of this instance and no longer.
///
/// Educational prototype only; no PHI; not a storage backend for real data.
class InMemoryCdssDatabase implements CdssDatabase {
  InMemoryCdssDatabase();

  final List<ConflictAuditLogRecord> _conflictAuditLog =
      <ConflictAuditLogRecord>[];
  final List<RecommendationAuditLogRecord> _recommendationAuditLog =
      <RecommendationAuditLogRecord>[];

  /// Conflict audit records written to this instance, in write order.
  List<ConflictAuditLogRecord> get conflictAuditLog =>
      List<ConflictAuditLogRecord>.unmodifiable(_conflictAuditLog);

  /// Recommendation audit records written to this instance, in write order.
  List<RecommendationAuditLogRecord> get recommendationAuditLog =>
      List<RecommendationAuditLogRecord>.unmodifiable(_recommendationAuditLog);

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      const <Map<String, Object?>>[];

  @override
  Future<void> initialize() async {}

  @override
  Future<void> clearStagingRun(String runId) async {}

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {}

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {}

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {}

  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {}

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {}

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) async {}

  @override
  Future<void> insertDrugProductVariant(
    DrugProductVariantRecord record,
  ) async {}

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) async {}

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) async {}

  @override
  Future<void> insertDrugProductPackaging(
    DrugProductPackagingRecord record,
  ) async {}

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) async {}

  @override
  Future<void> insertObservation(ObservationRecord record) async {}

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {}

  @override
  Future<void> insertRegionJurisdictionMap(
    RegionJurisdictionMapRecord record,
  ) async {}

  @override
  Future<void> insertLocaleResourceBundle(
    LocaleResourceBundleRecord record,
  ) async {}

  @override
  Future<void> insertCountryDietProfile(
    CountryDietProfileRecord record,
  ) async {}

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) async {}

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {}

  @override
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) async {}

  @override
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) async {}

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) async {
    _conflictAuditLog.add(record);
  }

  @override
  Future<void> insertRecommendationAuditLog(
    RecommendationAuditLogRecord record,
  ) async {
    _recommendationAuditLog.add(record);
  }

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) async {}

  @override
  Future<void> insertSnapshotDistribution(
    SnapshotDistributionRecord record,
  ) async {}
}
