import '../../../core/db/cdss_database.dart';
import '../../../domain/entities/cdss_records.dart';

class CdssLocalDataSource {
  final CdssDatabase database;

  CdssLocalDataSource({required this.database});

  Future<void> initialize() => database.initialize();

  Future<void> writeSourceDocument(SourceDocumentRecord record) =>
      database.insertSourceDocument(record);

  Future<void> writeFoodConcept(FoodConceptRecord record) =>
      database.insertFoodConcept(record);

  Future<void> writeFoodVariant(FoodVariantRecord record) =>
      database.insertFoodVariant(record);

  Future<void> writeDrugConcept(DrugConceptRecord record) =>
      database.insertDrugConcept(record);

  Future<void> writeDrugProductVariant(DrugProductVariantRecord record) =>
      database.insertDrugProductVariant(record);

  Future<void> writeObservation(ObservationRecord record) =>
      database.insertObservation(record);

  Future<void> writeVariantScope(VariantScopeRecord record) =>
      database.insertVariantScope(record);

  Future<void> writeRegionJurisdictionMap(RegionJurisdictionMapRecord record) =>
      database.insertRegionJurisdictionMap(record);

  Future<void> writeLocaleResourceBundle(LocaleResourceBundleRecord record) =>
      database.insertLocaleResourceBundle(record);

  Future<void> writeCountryDietProfile(CountryDietProfileRecord record) =>
      database.insertCountryDietProfile(record);

  Future<void> writeMealTemplate(MealTemplateRecord record) =>
      database.insertMealTemplate(record);

  Future<void> writeResolvedFact(ResolvedFactRecord record) =>
      database.insertResolvedFact(record);

  Future<void> writeRuleRegistry(Map<String, dynamic> row) =>
      database.insertRuleRegistry(row);

  Future<void> writeEngineSnapshot(EngineSnapshotRecord record) =>
      database.insertEngineSnapshot(record);

  Future<void> writeRuntimeEvent(RuntimeEventRecord record) =>
      database.insertRuntimeEvent(record);

  Future<void> writeConflictAuditLog(ConflictAuditLogRecord record) =>
      database.insertConflictAuditLog(record);

  Future<void> writeRecommendationAuditLog(
          RecommendationAuditLogRecord record) =>
      database.insertRecommendationAuditLog(record);

  Future<List<Map<String, Object?>>> queryTable(String table) =>
      database.queryTable(table);
}
