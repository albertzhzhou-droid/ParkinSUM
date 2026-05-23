import '../../domain/entities/cdss_records.dart';
import 'cdss_database.dart';

class StubCdssDatabase implements CdssDatabase {
  @override
  Future<void> initialize() async {}

  @override
  Future<void> insertCountryDietProfile(
      CountryDietProfileRecord record) async {}

  @override
  Future<void> insertConflictAuditLog(ConflictAuditLogRecord record) async {}

  Future<void> insertHumanReviewTicket(HumanReviewTicketRecord record) async {}

  @override
  Future<void> insertEngineSnapshot(EngineSnapshotRecord record) async {}

  @override
  Future<void> insertFoodConcept(FoodConceptRecord record) async {}

  @override
  Future<void> insertFoodVariant(FoodVariantRecord record) async {}

  @override
  Future<void> insertDrugConcept(DrugConceptRecord record) async {}

  @override
  Future<void> insertDrugProductVariant(
      DrugProductVariantRecord record) async {}

  @override
  Future<void> insertDrugLabelSection(DrugLabelSectionRecord record) async {}

  @override
  Future<void> insertDrugProductCode(DrugProductCodeRecord record) async {}

  @override
  Future<void> insertDrugProductPackaging(
      DrugProductPackagingRecord record) async {}

  @override
  Future<void> insertDrugProductMedia(DrugProductMediaRecord record) async {}

  @override
  Future<void> insertLocaleResourceBundle(
      LocaleResourceBundleRecord record) async {}

  @override
  Future<void> insertMealTemplate(MealTemplateRecord record) async {}

  @override
  Future<void> insertObservation(ObservationRecord record) async {}

  @override
  Future<void> insertRecommendationAuditLog(
      RecommendationAuditLogRecord record) async {}

  @override
  Future<void> insertIngestionRun(IngestionRunRecord record) async {}

  @override
  Future<void> insertSnapshotDistribution(
      SnapshotDistributionRecord record) async {}

  @override
  Future<void> insertStagingRow(String table, Map<String, Object?> row) async {}

  @override
  Future<void> clearStagingRun(String runId) async {}

  @override
  Future<void> insertResolvedFact(ResolvedFactRecord record) async {}

  @override
  Future<void> insertRegionJurisdictionMap(
      RegionJurisdictionMapRecord record) async {}

  @override
  Future<void> insertRuleRegistry(Map<String, dynamic> row) async {}

  @override
  Future<void> insertRuntimeEvent(RuntimeEventRecord record) async {}

  @override
  Future<void> insertSourceDocument(SourceDocumentRecord record) async {}

  @override
  Future<void> insertVariantScope(VariantScopeRecord record) async {}

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async => const [];
}

CdssDatabase createCdssDatabaseImpl() => StubCdssDatabase();
