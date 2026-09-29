import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/versioned_dose_unit_mapping.dart';
import 'package:parkinsum_companion/domain/usecases/dosage_note_parser.dart';

void main() {
  final checkedAt = DateTime.utc(2026, 9, 23, 12);

  test(
    'local dose mapping preserves identities, review, and license state',
    () {
      final mapping = VersionedDoseUnitMapping.forLocalToken(
        'grams',
        sourceRevision: DosageNoteParser.grammarDigest,
      )!;

      expect(mapping.sourceSystemUri, VersionedDoseUnitMapping.tokenSystemUri);
      expect(mapping.sourceCode, 'grams');
      expect(mapping.sourceDisplay, 'grams');
      expect(mapping.sourceTerminologyVersion, '2');
      expect(mapping.canonicalSystemUri, DosageNoteParser.localUnitSystem);
      expect(mapping.canonicalCode, 'g');
      expect(mapping.canonicalDisplay, 'gram');
      expect(mapping.canonicalTerminologyVersion, '2');
      expect(mapping.baseUnitCode, 'mg');
      expect(mapping.sourceRevision, DosageNoteParser.grammarDigest);
      expect(mapping.mappingType, DoseUnitMappingType.exactAliasAndConversion);
      expect(
        mapping.jurisdiction,
        'not_applicable_user_entered_local_vocabulary',
      );
      expect(mapping.reviewDate, '2026-09-23');
      expect(mapping.licenseState, 'local_authored_no_external_asset');
      expect(mapping.conversionNumerator, 1000);
      expect(mapping.conversionDenominator, 1);
      expect(
        mapping.validationErrors(
          expectedSourceRevision: DosageNoteParser.grammarDigest,
          evaluatedAt: checkedAt,
        ),
        isEmpty,
      );
      expect(
        VersionedDoseUnitMapping.tryFromJson(mapping.toJson())?.toJson(),
        mapping.toJson(),
      );
    },
  );

  test('exact rational conversions remain finite and dimension specific', () {
    final parser = DosageNoteParser();
    final gram = parser.inspect('0.25 g', evaluatedAt: checkedAt).expression!;
    final microgram = parser
        .inspect('250 mcg', evaluatedAt: checkedAt)
        .expression!;
    final volume = parser.inspect('2 mL', evaluatedAt: checkedAt).expression!;

    expect(
      gram.unit.mappingEvidence.convertToBaseUnit(
        gram.value,
        expectedSourceRevision: DosageNoteParser.grammarDigest,
        evaluatedAt: checkedAt,
      ),
      250,
    );
    expect(
      microgram.unit.mappingEvidence.convertToBaseUnit(
        microgram.value,
        expectedSourceRevision: DosageNoteParser.grammarDigest,
        evaluatedAt: checkedAt,
      ),
      0.25,
    );
    expect(volume.unit.mappingEvidence.baseUnitCode, 'mL');
    expect(
      volume.unit.mappingEvidence.convertToBaseUnit(
        volume.value,
        expectedSourceRevision: DosageNoteParser.grammarDigest,
        evaluatedAt: checkedAt,
      ),
      2,
    );
    expect(
      VersionedDoseUnitMapping.forLocalToken(
        'teaspoon',
        sourceRevision: DosageNoteParser.grammarDigest,
      ),
      isNull,
    );
    final caseFolded = VersionedDoseUnitMapping.forLocalToken(
      'MG',
      sourceRevision: DosageNoteParser.grammarDigest,
    )!;
    expect(caseFolded.sourceCode, 'mg');
    expect(caseFolded.sourceDisplay, 'MG');
    expect(caseFolded.mappingType, DoseUnitMappingType.exactAlias);
    expect(
      gram.unit.mappingEvidence.convertToBaseUnit(
        double.maxFinite,
        expectedSourceRevision: DosageNoteParser.grammarDigest,
        evaluatedAt: checkedAt,
      ),
      isNull,
    );
  });

  test(
    'unknown, approximate, unlicensed, stale, and invalid mappings fail',
    () {
      final exact = VersionedDoseUnitMapping.forLocalToken(
        'g',
        sourceRevision: DosageNoteParser.grammarDigest,
      )!;

      final unlicensed = VersionedDoseUnitMapping.tryFromJson(
        exact.toJson()..['licenseState'] = 'unknown',
      )!;
      expect(
        unlicensed.validationErrors(
          expectedSourceRevision: DosageNoteParser.grammarDigest,
          evaluatedAt: checkedAt,
        ),
        contains('dose.unit_mapping_license_not_cleared'),
      );

      final approximate = VersionedDoseUnitMapping.tryFromJson(
        exact.toJson()..['mappingType'] = 'approximate',
      )!;
      expect(
        approximate.validationErrors(
          expectedSourceRevision: DosageNoteParser.grammarDigest,
          evaluatedAt: checkedAt,
        ),
        contains('dose.unit_mapping_not_exact'),
      );

      final wrongDimension = VersionedDoseUnitMapping.tryFromJson(
        exact.toJson()..['targetDimension'] = 'volume',
      )!;
      expect(
        wrongDimension.validationErrors(
          expectedSourceRevision: DosageNoteParser.grammarDigest,
          evaluatedAt: checkedAt,
        ),
        contains('dose.unit_mapping_dimension_mismatch'),
      );

      final stale = exact.validationErrors(
        expectedSourceRevision: DosageNoteParser.grammarDigest,
        evaluatedAt: DateTime.utc(2027, 9, 24),
      );
      expect(stale, contains('dose.unit_mapping_review_stale'));

      final future = exact.validationErrors(
        expectedSourceRevision: DosageNoteParser.grammarDigest,
        evaluatedAt: DateTime.utc(2026, 9, 22),
      );
      expect(future, contains('dose.unit_mapping_review_not_yet_effective'));
    },
  );
}
