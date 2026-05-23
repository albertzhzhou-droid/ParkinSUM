import '../../domain/entities/cdss_records.dart';

abstract class CdssDatabase {
  Future<void> initialize();

  Future<void> insertSourceDocument(SourceDocumentRecord record);
  Future<void> insertFoodConcept(FoodConceptRecord record);
  Future<void> insertFoodVariant(FoodVariantRecord record);
  Future<void> insertDrugConcept(DrugConceptRecord record);
  Future<void> insertDrugProductVariant(DrugProductVariantRecord record);
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record);
  Future<void> insertDrugProductCode(DrugProductCodeRecord record);
  Future<void> insertDrugProductPackaging(DrugProductPackagingRecord record);
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record);
  Future<void> insertObservation(ObservationRecord record);
  Future<void> insertVariantScope(VariantScopeRecord record);
  Future<void> insertRegionJurisdictionMap(RegionJurisdictionMapRecord record);
  Future<void> insertLocaleResourceBundle(LocaleResourceBundleRecord record);
  Future<void> insertCountryDietProfile(CountryDietProfileRecord record);
  Future<void> insertMealTemplate(MealTemplateRecord record);
  Future<void> insertResolvedFact(ResolvedFactRecord record);
  Future<void> insertRuleRegistry(Map<String, dynamic> row);
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record);
  Future<void> insertRuntimeEvent(RuntimeEventRecord record);
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record);
  Future<void> insertRecommendationAuditLog(
      RecommendationAuditLogRecord record);
  Future<void> insertIngestionRun(IngestionRunRecord record);
  Future<void> insertSnapshotDistribution(SnapshotDistributionRecord record);
  Future<void> insertStagingRow(String table, Map<String, Object?> row);
  Future<void> clearStagingRun(String runId);

  Future<List<Map<String, Object?>>> queryTable(String table);
}
