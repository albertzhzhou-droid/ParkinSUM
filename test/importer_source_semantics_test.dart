import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/utils/qualified_value_parser.dart';
import 'package:parkinsum_companion/data/datasources/remote/amino_acid_extractor.dart';
import 'package:parkinsum_companion/data/datasources/remote/dailymed_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/fdc_p0_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_food_to_candidate.dart';

void main() {
  const client = FakeSourceFetchClient(textByUrl: {});
  const fdc = FdcP0Importer(fetchClient: client);
  const dailyMed = DailyMedP0Importer(fetchClient: client);
  Map<String, dynamic> food(List<Map<String, dynamic>> nutrients) => {
    'fdcId': 123,
    'description': 'Synthetic source semantics fixture',
    'dataType': 'Foundation',
    'foodNutrients': nutrients,
  };
  Map<String, dynamic> nutrient(
    String number,
    Object amount,
    String unit, {
    Object? loq,
  }) => {
    'amount': amount,
    'loq': ?loq,
    'nutrient': {'number': number, 'unitName': unit},
  };

  test('USDA zero plus positive LOQ remains a censored interval', () {
    final bundle = fdc.importFoods([
      food([nutrient('203', 0, 'g', loq: 0.03)]),
    ], sourceLabel: 'synthetic_loq');
    final value = bundle.observations.single.value;
    expect(value.qualifierKind, QualifierKind.lessThan);
    expect(value.low, 0);
    expect(value.high, 0.03);
    expect(value.valueNum, isNull);
    // A point-only model must receive unknown, never 0 or the LOQ bound.
    final candidate = foodItemToCandidateFood(bundle.projectedFoods.single);
    expect(candidate.components.single.proteinGrams, isNull);
    final raw = jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
    expect(
      (raw['nutrient_value_audit'] as List).single['decision'],
      'below_quantification_limit',
    );
  });

  test(
    'a reported zero without LOQ keeps legacy zero while absent nutrients are unknown',
    () {
      final bundle = fdc.importFoods([
        food([nutrient('203', 0, 'g')]),
      ], sourceLabel: 'synthetic_zero');
      final candidate = foodItemToCandidateFood(bundle.projectedFoods.single);
      expect(candidate.components.single.proteinGrams, 0);
      expect(candidate.components.single.fatGrams, isNull);
      expect(candidate.components.single.carbohydrateGrams, isNull);
    },
  );

  test('a positive value at or above LOQ retains its measured point', () {
    for (final amount in [0.03, 2.0]) {
      final bundle = fdc.importFoods([
        food([nutrient('203', amount, 'g', loq: 0.03)]),
      ], sourceLabel: 'synthetic_positive_loq');
      expect(
        bundle.observations.single.value.qualifierKind,
        QualifierKind.exact,
      );
      expect(bundle.observations.single.value.valueNum, amount);
      expect(bundle.projectedFoods.single.proteinG, amount);
    }
  });

  test(
    'a positive source summary below LOQ is retained with point scope held',
    () {
      final bundle = fdc.importFoods([
        food([nutrient('203', 0.01, 'g', loq: 0.03)]),
      ], sourceLabel: 'synthetic_inconsistent_loq');
      expect(
        bundle.observations.single.value.qualifierKind,
        QualifierKind.missing,
      );
      expect(bundle.resolvedFacts, isEmpty);
      expect(
        bundle.projectedFoods.single.isNutrientMissing('proteinG'),
        isTrue,
      );
      final raw = jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      expect(
        (raw['nutrient_value_audit'] as List).single['reason'],
        'quantification_scope_unverified',
      );
      expect(
        (raw['source_nutrient_summaries'] as List).single['reported_amount'],
        0.01,
      );
    },
  );

  test('duplicate rows retain distinct source-statistics identities', () {
    final row = nutrient('203', 2, 'g')
      ..addAll({'min': 1, 'max': 3, 'dataPoints': 2});
    final bundle = fdc.importFoods([
      food([row, Map<String, dynamic>.from(row)]),
    ], sourceLabel: 'synthetic_duplicate_statistics');
    expect(bundle.observations, hasLength(4));
    expect(
      bundle.observations.map((row) => row.observationId).toSet(),
      hasLength(4),
    );
    expect(bundle.resolvedFacts, isEmpty);
    expect(bundle.projectedFoods.single.isNutrientMissing('proteinG'), isTrue);
  });

  test('wrong units, negatives and invalid LOQ are withheld with reasons', () {
    for (final row in [
      nutrient('203', 10, 'mg'),
      nutrient('203', -2, 'g'),
      nutrient('203', 'NaN', 'g'),
      nutrient('203', 0, 'g', loq: 'invalid'),
    ]) {
      final bundle = fdc.importFoods([
        food([row]),
      ], sourceLabel: 'synthetic_bad');
      expect(bundle.resolvedFacts, isEmpty);
      expect(bundle.observations, isEmpty);
      expect(
        bundle.projectedFoods.single.isNutrientMissing('proteinG'),
        isTrue,
      );
      final raw = jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      expect(
        (raw['nutrient_value_audit'] as List).single['decision'],
        'withheld',
      );
    }
  });

  test('CSV joins portions to the correct food and parses source weights', () {
    final bundle = fdc.importCsvArchive({
      // input_food deliberately comes first: suffix matching must not pick it.
      'bulk/input_food.csv': 'fdc_id,description\n999,Wrong table',
      'bulk/food.csv':
          'fdc_id,description,data_type\n123,Synthetic pear,Foundation',
      'bulk/nutrient.csv': 'id,number,name,unit_name\n1003,203,Protein,g',
      'bulk/food_nutrient.csv': 'fdc_id,nutrient_id,amount,loq\n123,1003,2,',
      'bulk/measure_unit.csv': 'id,name,abbreviation\n5,cup,cup',
      'bulk/food_portion.csv':
          'id,fdc_id,seq_num,amount,measure_unit_id,modifier,gram_weight\n'
          '7,123,1,1,5,sliced,150\n8,999,1,1,5,other,300',
    }, sourceLabel: 'synthetic_csv');
    final projected = bundle.projectedFoods.single;
    expect(projected.sourceFoodCode, '123');
    final portion = projected.foodPortionEvidence.single;
    expect(portion.amount, 1);
    expect(portion.gramWeight, 150);
    expect(portion.measureUnitName, 'cup');
    expect(portion.measureUnitId, 5);
    expect(portion.sourceDocId, bundle.sourceDocuments.single.sourceDocId);
    expect(portion.sourceFields['id'], '7');
    // Source remains 2 g/100 g. Independent expected preview: 2*150/100=3 g.
    expect(bundle.observations.single.value.valueNum, 2);
    expect(projected.proteinG, 2);
  });

  test('food snapshot and observation identity change with source content', () {
    final a = fdc.importFoods([
      food([nutrient('203', 2, 'g')]),
    ], sourceLabel: 'same_source_label');
    final b = fdc.importFoods([
      food([nutrient('203', 3, 'g')]),
    ], sourceLabel: 'same_source_label');
    expect(
      a.sourceDocuments.single.sourceDocId,
      isNot(b.sourceDocuments.single.sourceDocId),
    );
    expect(
      a.observations.single.observationId,
      isNot(b.observations.single.observationId),
    );
    expect(a.projectedFoods.single.id, b.projectedFoods.single.id);
  });

  test('FDC energy stays kcal and water stays grams', () {
    final bundle = fdc.importFoods([
      food([nutrient('208', 50, 'kcal'), nutrient('255', 80, 'g')]),
    ], sourceLabel: 'synthetic_energy');
    expect(bundle.projectedFoods.single.energyKcal, 50);
    expect(bundle.projectedFoods.single.waterG, 80);
    expect(bundle.observations.first.unit, 'kcal');
  });

  test(
    'duplicate nutrients retain both observations and withhold point projection',
    () {
      final bundle = fdc.importFoods([
        food([nutrient('203', 2, 'g'), nutrient('203', 2, 'g')]),
      ], sourceLabel: 'synthetic_duplicate');
      expect(bundle.observations, hasLength(2));
      expect(
        bundle.observations.map((row) => row.observationId).toSet(),
        hasLength(2),
      );
      expect(bundle.resolvedFacts, isEmpty);
      expect(
        bundle.projectedFoods.single.isNutrientMissing('proteinG'),
        isTrue,
      );
    },
  );

  test('censored LNAA never becomes an exact zero amino acid profile', () {
    final profile = AminoAcidExtractor().extractFromFdcStyle(
      food([nutrient('504', 0, 'g', loq: 0.03)]),
    );
    expect(profile, isNotNull);
    expect(profile!.partial, isTrue);
    expect(profile.leucine, isNull);
    expect(profile.competingLnaaGrams, isNull);
  });

  String spl({String version = '2', String route = 'ORAL'}) =>
      '''
<document xmlns="urn:hl7-org:v3">
 <id root="document-$version"/><setId root="synthetic-set"/>
 <versionNumber value="$version"/><effectiveTime value="20260929"/>
 <title>Synthetic carbidopa levodopa extended-release capsule</title>
 <ingredient classCode="ACTIB"><quantity>
  <numerator value="95" unit="mg"/><denominator value="1" unit="1"/>
 </quantity><ingredientSubstance><code code="UNII-SYNTHETIC" codeSystem="2.16.840.1.113883.4.9"/>
 <name>levodopa</name></ingredientSubstance></ingredient>
 <ingredient classCode="IACT"><ingredientSubstance><name>cellulose</name></ingredientSubstance></ingredient>
 <routeCode displayName="$route"/><formCode displayName="CAPSULE"/>
 <section><code code="34073-7"/><title>Drug interactions</title>
 <text>High protein meals may decrease absorption.</text></section>
</document>''';

  test(
    'SPL retains document version/date/active strength and section code',
    () {
      final bundle = dailyMed.importSplXml(spl());
      expect(bundle.drugConcepts.single.genericName, 'levodopa');
      expect(bundle.drugProductVariants.single.labelVersion, 'spl_version_2');
      expect(
        bundle.sourceDocuments.single.effectiveAt,
        DateTime.utc(2026, 9, 29),
      );
      final raw = jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      expect(raw['document_id'], 'document-2');
      expect(raw['version_number'], '2');
      expect(raw['spl_xml_sha256'], matches(RegExp(r'^[a-f0-9]{64}$')));
      final strength = (raw['active_ingredient_details'] as List).single;
      expect(strength['numerator_value'], '95');
      expect(strength['numerator_unit'], 'mg');
      expect(strength['promotion_status'], 'source_strength_evidence_only');
      expect(bundle.drugLabelSections.single.sectionKey, contains('34073'));
    },
  );

  test(
    'SPL version changes preserve product identity and separate evidence',
    () {
      final a = dailyMed.importSplXml(spl());
      final b = dailyMed.importSplXml(spl(version: '3'));
      expect(
        a.drugProductVariants.single.drugProductVariantId,
        b.drugProductVariants.single.drugProductVariantId,
      );
      expect(
        a.sourceDocuments.single.sourceDocId,
        isNot(b.sourceDocuments.single.sourceDocId),
      );
      expect(
        a.drugLabelSections.single.sectionId,
        isNot(b.drugLabelSections.single.sectionId),
      );
    },
  );

  test(
    'ambiguous routes remain unspecified instead of taking the first route',
    () {
      final xml = spl().replaceFirst(
        '</document>',
        '<routeCode displayName="INTRAVENOUS"/></document>',
      );
      expect(
        dailyMed.importSplXml(xml).projectedDrugs.single.route,
        'unspecified',
      );
    },
  );
}
