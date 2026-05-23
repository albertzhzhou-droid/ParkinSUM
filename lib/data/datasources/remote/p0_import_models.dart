import '../../../core/models/drug_definition.dart';
import '../../../core/models/food_item.dart';
import '../../../domain/entities/cdss_records.dart';

/// ETL 结果容器：
/// - 统一承接官方源抓取后的结构化记录；
/// - 既能写入 CDSS 数据库，也能投影成 App 目录。
///
class P0ImportBundle {
  final List<SourceDocumentRecord> sourceDocuments;
  final List<CountryDietProfileRecord> countryDietProfiles;
  final List<FoodConceptRecord> foodConcepts;
  final List<FoodVariantRecord> foodVariants;
  final List<DrugConceptRecord> drugConcepts;
  final List<DrugProductVariantRecord> drugProductVariants;
  final List<DrugLabelSectionRecord> drugLabelSections;
  final List<DrugProductCodeRecord> drugProductCodes;
  final List<DrugProductPackagingRecord> drugProductPackagings;
  final List<DrugProductMediaRecord> drugProductMedias;
  final List<ConceptVariantCrosswalkRecord> conceptVariantCrosswalks;
  final List<VariantScopeRecord> variantScopes;
  final List<ObservationRecord> observations;
  final List<ResolvedFactRecord> resolvedFacts;
  final List<Map<String, dynamic>> ruleRegistryRows;
  final List<RuntimeEventRecord> runtimeEvents;
  final List<FoodItem> projectedFoods;
  final List<DrugDefinition> projectedDrugs;

  const P0ImportBundle({
    this.sourceDocuments = const <SourceDocumentRecord>[],
    this.countryDietProfiles = const <CountryDietProfileRecord>[],
    this.foodConcepts = const <FoodConceptRecord>[],
    this.foodVariants = const <FoodVariantRecord>[],
    this.drugConcepts = const <DrugConceptRecord>[],
    this.drugProductVariants = const <DrugProductVariantRecord>[],
    this.drugLabelSections = const <DrugLabelSectionRecord>[],
    this.drugProductCodes = const <DrugProductCodeRecord>[],
    this.drugProductPackagings = const <DrugProductPackagingRecord>[],
    this.drugProductMedias = const <DrugProductMediaRecord>[],
    this.conceptVariantCrosswalks = const <ConceptVariantCrosswalkRecord>[],
    this.variantScopes = const <VariantScopeRecord>[],
    this.observations = const <ObservationRecord>[],
    this.resolvedFacts = const <ResolvedFactRecord>[],
    this.ruleRegistryRows = const <Map<String, dynamic>>[],
    this.runtimeEvents = const <RuntimeEventRecord>[],
    this.projectedFoods = const <FoodItem>[],
    this.projectedDrugs = const <DrugDefinition>[],
  });

  bool get isEmpty =>
      sourceDocuments.isEmpty &&
      countryDietProfiles.isEmpty &&
      foodConcepts.isEmpty &&
      foodVariants.isEmpty &&
      drugConcepts.isEmpty &&
      drugProductVariants.isEmpty &&
      drugLabelSections.isEmpty &&
      drugProductCodes.isEmpty &&
      drugProductPackagings.isEmpty &&
      drugProductMedias.isEmpty &&
      conceptVariantCrosswalks.isEmpty &&
      variantScopes.isEmpty &&
      observations.isEmpty &&
      resolvedFacts.isEmpty &&
      ruleRegistryRows.isEmpty &&
      runtimeEvents.isEmpty &&
      projectedFoods.isEmpty &&
      projectedDrugs.isEmpty;

  P0ImportBundle merge(P0ImportBundle other) {
    return P0ImportBundle(
      sourceDocuments: [...sourceDocuments, ...other.sourceDocuments],
      countryDietProfiles: [
        ...countryDietProfiles,
        ...other.countryDietProfiles
      ],
      foodConcepts: [...foodConcepts, ...other.foodConcepts],
      foodVariants: [...foodVariants, ...other.foodVariants],
      drugConcepts: [...drugConcepts, ...other.drugConcepts],
      drugProductVariants: [
        ...drugProductVariants,
        ...other.drugProductVariants
      ],
      drugLabelSections: [...drugLabelSections, ...other.drugLabelSections],
      drugProductCodes: [...drugProductCodes, ...other.drugProductCodes],
      drugProductPackagings: [
        ...drugProductPackagings,
        ...other.drugProductPackagings
      ],
      drugProductMedias: [...drugProductMedias, ...other.drugProductMedias],
      conceptVariantCrosswalks: [
        ...conceptVariantCrosswalks,
        ...other.conceptVariantCrosswalks
      ],
      variantScopes: [...variantScopes, ...other.variantScopes],
      observations: [...observations, ...other.observations],
      resolvedFacts: [...resolvedFacts, ...other.resolvedFacts],
      ruleRegistryRows: [...ruleRegistryRows, ...other.ruleRegistryRows],
      runtimeEvents: [...runtimeEvents, ...other.runtimeEvents],
      projectedFoods: [...projectedFoods, ...other.projectedFoods],
      projectedDrugs: [...projectedDrugs, ...other.projectedDrugs],
    );
  }
}
