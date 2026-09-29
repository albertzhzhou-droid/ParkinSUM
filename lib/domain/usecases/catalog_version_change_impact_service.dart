import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import '../entities/catalog_version_change_diff.dart';

/// Aggregate-only inventory of exact old catalog-code tokens in local state.
///
/// Intake records do not bind a catalog release, so a match is a potential
/// reference rather than a confirmed affected record. This projection keeps
/// record identifiers, names, and dose details out of its output.
final class CatalogVersionChangeImpactPreview {
  CatalogVersionChangeImpactPreview({
    required this.activeMedicationIdCount,
    required this.activeMedicationsWithComparableSourceIdentity,
    required this.activeMedicationsWithPotentialChangedCodeMatch,
    required Map<CatalogVersionChangeKind, int> activePotentialMatchesByKind,
    required this.intakeRowCount,
    required this.rowsWithComparableSourceIdentity,
    required this.rowsWithPotentialChangedCodeMatch,
    required this.rowsWithMultipleChangedCodeMatches,
    required Map<CatalogVersionChangeKind, int> potentialMatchesByKind,
  }) : activePotentialMatchesByKind =
           Map<CatalogVersionChangeKind, int>.unmodifiable(
             activePotentialMatchesByKind,
           ),
       potentialMatchesByKind = Map<CatalogVersionChangeKind, int>.unmodifiable(
         potentialMatchesByKind,
       );

  final int activeMedicationIdCount;
  final int activeMedicationsWithComparableSourceIdentity;
  final int activeMedicationsWithPotentialChangedCodeMatch;
  final Map<CatalogVersionChangeKind, int> activePotentialMatchesByKind;
  final int intakeRowCount;
  final int rowsWithComparableSourceIdentity;
  final int rowsWithPotentialChangedCodeMatch;
  final int rowsWithMultipleChangedCodeMatches;
  final Map<CatalogVersionChangeKind, int> potentialMatchesByKind;

  int get rowsWithoutComparableSourceIdentity =>
      intakeRowCount - rowsWithComparableSourceIdentity;

  int get activeMedicationsWithoutComparableSourceIdentity =>
      activeMedicationIdCount - activeMedicationsWithComparableSourceIdentity;

  int get activeMedicationsWithComparableIdentityAndNoChangedCodeMatch =>
      activeMedicationsWithComparableSourceIdentity -
      activeMedicationsWithPotentialChangedCodeMatch;

  int get comparableRowsWithoutChangedCodeMatch =>
      rowsWithComparableSourceIdentity -
      rowsWithPotentialChangedCodeMatch -
      rowsWithMultipleChangedCodeMatches;

  /// The current intake schema stores no catalog release identity.
  bool get sourceReleaseBindingAvailable => false;
}

/// Counts exact source-code tokens without exposing or modifying local rows.
final class CatalogVersionChangeImpactService {
  const CatalogVersionChangeImpactService();

  static const int maxIntakeRows = 100000;
  static const int maxActiveMedicationIds = 100000;
  static const int maxMedicationDefinitions = 100000;

  CatalogVersionChangeImpactPreview preview({
    required CatalogVersionChangeDiff diff,
    Set<String> activeMedicationIds = const <String>{},
    required List<Intake> intakes,
    required List<DrugDefinition> medications,
  }) {
    if (intakes.length > maxIntakeRows ||
        activeMedicationIds.length > maxActiveMedicationIds ||
        medications.length > maxMedicationDefinitions) {
      throw ArgumentError('Catalog impact input exceeds its bounded size.');
    }

    final definitionsById = <String, DrugDefinition>{};
    final duplicateDefinitionIds = <String>{};
    for (final medication in medications) {
      if (definitionsById.containsKey(medication.id)) {
        duplicateDefinitionIds.add(medication.id);
      } else {
        definitionsById[medication.id] = medication;
      }
    }
    for (final id in duplicateDefinitionIds) {
      definitionsById.remove(id);
    }

    final sourceSystem = _sourceKey(diff.previousSnapshot.sourceSystem);
    final jurisdiction = _sourceKey(diff.previousSnapshot.jurisdiction);
    final changedKindsByCode = <String, CatalogVersionChangeKind>{
      for (final entry in diff.entries)
        if (entry.previousConcept != null &&
            entry.kind != CatalogVersionChangeKind.unchanged)
          entry.previousConcept!.code: entry.kind,
    };
    final matchesByKind = <CatalogVersionChangeKind, int>{
      for (final kind in CatalogVersionChangeKind.values) kind: 0,
    };
    final activeMatchesByKind = <CatalogVersionChangeKind, int>{
      for (final kind in CatalogVersionChangeKind.values) kind: 0,
    };
    var comparableActiveMedications = 0;
    var matchedActiveMedications = 0;
    var comparableRows = 0;
    var matchedRows = 0;
    var multipleMatchRows = 0;

    for (final medicationId in activeMedicationIds) {
      final definition = duplicateDefinitionIds.contains(medicationId)
          ? null
          : definitionsById[medicationId];
      if (definition == null ||
          _sourceKey(definition.jurisdiction) != jurisdiction ||
          _sourceKey(definition.sourceSystem) != sourceSystem ||
          !_isUsableSourceCode(definition.sourceProductCode)) {
        continue;
      }
      comparableActiveMedications++;
      final kind = changedKindsByCode[definition.sourceProductCode];
      if (kind != null) {
        matchedActiveMedications++;
        activeMatchesByKind[kind] = activeMatchesByKind[kind]! + 1;
      }
    }

    for (final intake in intakes) {
      final definition = duplicateDefinitionIds.contains(intake.drugId)
          ? null
          : definitionsById[intake.drugId];
      if (definition == null ||
          _sourceKey(definition.jurisdiction) != jurisdiction) {
        continue;
      }

      final sourceCodes = <String>{};
      if (_sourceKey(definition.sourceSystem) == sourceSystem &&
          _isUsableSourceCode(definition.sourceProductCode)) {
        sourceCodes.add(definition.sourceProductCode!);
      }
      final selectedProduct = intake.productSelection;
      if (selectedProduct != null &&
          _sourceKey(selectedProduct.sourceSystem ?? '') == sourceSystem &&
          _isUsableSourceCode(selectedProduct.identifierValue)) {
        sourceCodes.add(selectedProduct.identifierValue);
      }

      if (sourceCodes.isEmpty) continue;
      comparableRows++;
      final matchedCodes = sourceCodes
          .where(changedKindsByCode.containsKey)
          .toSet();
      if (matchedCodes.length > 1) {
        multipleMatchRows++;
      } else if (matchedCodes.length == 1) {
        matchedRows++;
        final kind = changedKindsByCode[matchedCodes.single]!;
        matchesByKind[kind] = matchesByKind[kind]! + 1;
      }
    }

    return CatalogVersionChangeImpactPreview(
      activeMedicationIdCount: activeMedicationIds.length,
      activeMedicationsWithComparableSourceIdentity:
          comparableActiveMedications,
      activeMedicationsWithPotentialChangedCodeMatch: matchedActiveMedications,
      activePotentialMatchesByKind: activeMatchesByKind,
      intakeRowCount: intakes.length,
      rowsWithComparableSourceIdentity: comparableRows,
      rowsWithPotentialChangedCodeMatch: matchedRows,
      rowsWithMultipleChangedCodeMatches: multipleMatchRows,
      potentialMatchesByKind: matchesByKind,
    );
  }

  String _sourceKey(String value) => value.trim().toUpperCase();

  bool _isUsableSourceCode(String? value) =>
      value != null &&
      value.isNotEmpty &&
      value.trim() == value &&
      !value.toUpperCase().startsWith('UNSPECIFIED_');
}
