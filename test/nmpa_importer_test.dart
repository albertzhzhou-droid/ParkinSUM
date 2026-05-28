import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/nmpa_importer.dart';
import 'package:parkinsum_companion/domain/entities/source_metadata.dart';
import 'package:parkinsum_companion/domain/usecases/metadata_completeness_gate.dart';

Map<String, dynamic> _loadFixture() {
  final file = File('test/fixtures/importers/nmpa_levodopa_stub.json');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final importer = NmpaImporter();
  final gate = MetadataCompletenessGate();

  test('parses synthetic NMPA fixture into canonical metadata (no network)',
      () {
    final result = importer.parse(_loadFixture());
    expect(result.document.sourceSystem, 'NMPA');
    expect(result.document.jurisdiction, 'CN');
    expect(result.document.language, 'zh');
    expect(result.document.authorityTier,
        SourceAuthorityTier.officialLabelInJurisdiction);
    expect(result.variant.activeIngredients,
        containsAll(['carbidopa', 'levodopa']));
    expect(result.variant.strengthValue, 100);
    expect(result.variant.strengthUnit, 'mg');
    expect(result.variant.releaseType, 'immediate');
    expect(result.variant.productIdentifier, isNotNull);
    expect(result.extractionMethod, contains('nmpa'));
  });

  test('preserves reference-only translation status + sourceRefs', () {
    final result = importer.parse(_loadFixture());
    expect(result.variant.translationStatus,
        ReferenceTranslationStatus.referenceOnlyTranslation);
    expect(result.document.translationStatus,
        ReferenceTranslationStatus.referenceOnlyTranslation);
    expect(result.variant.sourceRefs, contains('src.nmpa.database'));
    expect(result.variant.limitationText.toLowerCase(), contains('reference'));
  });

  test('complete fixture passes the medication completeness gate', () {
    final result = importer.parse(_loadFixture());
    final score = gate.scoreMedicationContext(result.variant);
    expect(
      [
        MetadataCompletenessScore.complete,
        MetadataCompletenessScore.sufficient
      ],
      contains(score),
    );
  });

  test('missing active ingredient → recorded note + invalid gate', () {
    final payload = _loadFixture()..remove('active_ingredients');
    final result = importer.parse(payload);
    expect(result.normalizationNotes, contains('missing:active_ingredients'));
    expect(gate.scoreMedicationContext(result.variant),
        MetadataCompletenessScore.invalid);
  });

  test('missing release type lowers confidence and is noted', () {
    final payload = _loadFixture()..remove('release_type');
    final result = importer.parse(payload);
    expect(result.variant.releaseType, 'unknown');
    expect(result.normalizationNotes, contains('missing:release_type'));
    final full = importer.parse(_loadFixture());
    expect(result.variant.extractionConfidence!,
        lessThanOrEqualTo(full.variant.extractionConfidence!));
  });
}
