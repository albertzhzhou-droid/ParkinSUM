import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/medication_product_pack.dart';
import 'package:parkinsum_companion/domain/entities/catalog_version_change_diff.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_version_change_diff_service.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_version_change_impact_service.dart';

void main() {
  test(
    'counts exact old source codes and keeps release identity unresolved',
    () {
      final diff = _diff();
      final definitions = <DrugDefinition>[
        _definition('base-match', sourceProductCode: 'OLD_A'),
        _definition(
          'product-match',
          sourceSystem: 'LOCAL_SEED',
          sourceProductCode: null,
        ),
        _definition(
          'wrong-source',
          sourceSystem: 'OTHER',
          sourceProductCode: 'OLD_A',
        ),
        _definition(
          'wrong-jurisdiction',
          jurisdiction: 'CA',
          sourceProductCode: 'OLD_A',
        ),
        _definition(
          'placeholder',
          sourceProductCode: 'UNSPECIFIED_TEST_CATALOG_CODE',
        ),
        _definition('no-match', sourceProductCode: 'SAME'),
        _definition('ambiguous', sourceProductCode: 'OLD_B'),
      ];
      final intakes = <Intake>[
        _intake('intake-base', 'base-match'),
        _intake('intake-product', 'product-match', _selection('OLD_B')),
        _intake('intake-wrong-source', 'wrong-source'),
        _intake('intake-wrong-jurisdiction', 'wrong-jurisdiction'),
        _intake('intake-placeholder', 'placeholder'),
        _intake('intake-no-match', 'no-match'),
        _intake('intake-ambiguous', 'ambiguous', _selection('OLD_A')),
        _intake('intake-orphan', 'not-in-catalog'),
      ];

      final preview = const CatalogVersionChangeImpactService().preview(
        diff: diff,
        activeMedicationIds: <String>{
          'base-match',
          'no-match',
          'wrong-source',
          'missing-active',
        },
        intakes: intakes,
        medications: definitions,
      );

      expect(preview.activeMedicationIdCount, 4);
      expect(preview.activeMedicationsWithComparableSourceIdentity, 2);
      expect(preview.activeMedicationsWithPotentialChangedCodeMatch, 1);
      expect(preview.activeMedicationsWithoutComparableSourceIdentity, 2);
      expect(
        preview.activeMedicationsWithComparableIdentityAndNoChangedCodeMatch,
        1,
      );
      expect(
        preview.activePotentialMatchesByKind[CatalogVersionChangeKind
            .unresolved],
        1,
      );
      expect(preview.intakeRowCount, 8);
      expect(preview.rowsWithComparableSourceIdentity, 4);
      expect(preview.rowsWithPotentialChangedCodeMatch, 2);
      expect(preview.rowsWithMultipleChangedCodeMatches, 1);
      expect(preview.rowsWithoutComparableSourceIdentity, 4);
      expect(preview.comparableRowsWithoutChangedCodeMatch, 1);
      expect(
        preview.potentialMatchesByKind[CatalogVersionChangeKind.unresolved],
        2,
      );
      expect(preview.sourceReleaseBindingAvailable, isFalse);
    },
  );

  test('duplicate catalog IDs are held out of exact-code matching', () {
    final definition = _definition('duplicate', sourceProductCode: 'OLD_A');
    final preview = const CatalogVersionChangeImpactService().preview(
      diff: _diff(),
      activeMedicationIds: const <String>{'duplicate'},
      intakes: <Intake>[_intake('intake-duplicate', 'duplicate')],
      medications: <DrugDefinition>[
        definition,
        _definition('duplicate', sourceProductCode: 'OLD_B'),
      ],
    );

    expect(preview.activeMedicationIdCount, 1);
    expect(preview.activeMedicationsWithComparableSourceIdentity, 0);
    expect(preview.activeMedicationsWithPotentialChangedCodeMatch, 0);
    expect(preview.intakeRowCount, 1);
    expect(preview.rowsWithComparableSourceIdentity, 0);
    expect(preview.rowsWithPotentialChangedCodeMatch, 0);
    expect(preview.rowsWithoutComparableSourceIdentity, 1);
  });
}

CatalogVersionChangeDiff _diff() {
  final previous = CatalogReleaseSnapshot(
    catalogId: 'fixture_catalog',
    sourceSystem: 'TEST_CATALOG',
    jurisdiction: 'US',
    releaseId: 'old',
    releaseSequence: 1,
    concepts: <CatalogConceptIdentity>[
      _concept('old', 'OLD_A'),
      _concept('old', 'OLD_B'),
      _concept('old', 'SAME'),
    ],
  );
  final current = CatalogReleaseSnapshot(
    catalogId: 'fixture_catalog',
    sourceSystem: 'TEST_CATALOG',
    jurisdiction: 'US',
    releaseId: 'new',
    releaseSequence: 2,
    concepts: <CatalogConceptIdentity>[
      _concept('new', 'NEW_A'),
      _concept('new', 'NEW_B'),
      _concept('new', 'SAME'),
    ],
  );
  return const CatalogVersionChangeDiffService().compare(
    previous: previous,
    current: current,
    mappingEvidence: <CatalogMappingEvidence>[],
  );
}

CatalogConceptIdentity _concept(String release, String code) =>
    CatalogConceptIdentity(
      sourceSystem: 'TEST_CATALOG',
      jurisdiction: 'US',
      releaseId: release,
      code: code,
      display: '$code display',
    );

DrugDefinition _definition(
  String id, {
  String sourceSystem = 'TEST_CATALOG',
  String jurisdiction = 'US',
  String? sourceProductCode,
}) => DrugDefinition(
  id: id,
  genericName: 'Synthetic medication',
  brandNames: const <String>[],
  tags: const <DrugTag>[],
  notes: '',
  sourceSystem: sourceSystem,
  sourceProductCode: sourceProductCode,
  jurisdiction: jurisdiction,
);

Intake _intake(
  String id,
  String drugId, [
  MedicationProductSelection? productSelection,
]) => Intake(
  id: id,
  drugId: drugId,
  takenAt: DateTime.utc(2026),
  dosageNote: '',
  productSelection: productSelection,
);

MedicationProductSelection _selection(String identifierValue) =>
    MedicationProductSelection(
      packId: 'synthetic-pack',
      identifierSystem: 'synthetic',
      identifierValue: identifierValue,
      displayName: 'Synthetic package',
      labelerName: null,
      strengthDisplay: '',
      packageDescription: '',
      sourceSystem: 'TEST_CATALOG',
      sourceUrl: null,
      sourceRetrievedAtUtc: null,
    );
