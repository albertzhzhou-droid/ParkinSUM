import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/amino_acid_extractor.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_competition.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/medication_entry_validation.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_competition_model.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

void main() {
  final extractor = AminoAcidExtractor();
  final normalizer = MealCompositionNormalizer();
  final emptying = GastricEmptyingModel();
  final absorption = LevodopaAbsorptionOpportunityModel();
  final competition = AminoAcidCompetitionModel();
  final validator = MedicationEntryValidator();

  NormalizedMedicationContext levodopa() => validator
      .validate(const RawMedicationEntry(
        activeIngredients: ['carbidopa', 'levodopa'],
        drugProductVariant: 'synthetic:demo',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo',
      ))
      .normalized!;

  AminoAcidProfile loadProfile() {
    final payload = jsonDecode(
        File('test/fixtures/importers/usda_fdc_amino_acids.json')
            .readAsStringSync()) as Map<String, dynamic>;
    final p = extractor.extractFromFdcStyle(payload);
    expect(p, isNotNull);
    return p!;
  }

  test('FDC-style fixture with amino-acid fields creates AminoAcidProfile', () {
    final p = loadProfile();
    expect(p.leucine, 2.1);
    expect(p.valine, 1.3);
    expect(p.competingLnaaGrams, isNotNull);
    expect(p.nutrientIds, isNotEmpty);
    expect(p.sourceRefs, contains('src.fdc.api.amino_acid_fields'));
  });

  test('realistic FDC fixture with mg units normalizes to grams', () {
    final payload = jsonDecode(
        File('test/fixtures/importers/usda_fdc_amino_acids_realistic.json')
            .readAsStringSync()) as Map<String, dynamic>;
    final p = extractor.extractFromFdcStyle(payload);
    expect(p, isNotNull);
    // 2100 mg leucine → 2.1 g.
    expect(p!.leucine, closeTo(2.1, 1e-9));
    expect(p.valine, closeTo(1.3, 1e-9));
    expect(p.unit, 'g');
    expect(p.partial, isFalse);
  });

  test('missing unit marks the profile partial (not silently trusted)', () {
    final p = extractor.extractFromFdcStyle({
      'foodNutrients': [
        {
          'nutrient': {'number': '507', 'name': 'Leucine'},
          'amount': 2.1
        }
      ]
    });
    expect(p, isNotNull);
    expect(p!.partial, isTrue);
  });

  test('extract by name fallback when number is absent', () {
    final p = extractor.extractFromFdcStyle({
      'foodNutrients': [
        {
          'nutrient': {'name': 'Valine', 'unitName': 'G'},
          'amount': 1.3
        }
      ]
    });
    expect(p, isNotNull);
    expect(p!.valine, 1.3);
    expect(p.nutrientIds, contains('name:valine'));
  });

  test('payload without amino-acid fields returns null (→ proxy fallback)', () {
    final p = extractor.extractFromFdcStyle({
      'foodNutrients': [
        {
          'nutrient': {'number': '203', 'name': 'Protein', 'unitName': 'G'},
          'amount': 20.0
        }
      ]
    });
    expect(p, isNull);
  });

  CompetitionLnaaSummary summaryFor(FoodComponent component) {
    final comp = normalizer.normalize(
      mealId: 'm',
      components: [component],
      declaredPhysicalForm: MealPhysicalForm.solid,
    );
    final profile =
        emptying.build(mealId: 'm', mealStartMinute: 0, composition: comp);
    final med =
        MedicationTimelineEvent(id: 'x', minute: 15, context: levodopa());
    final window =
        absorption.build(medication: med, overlappingMealProfile: profile);
    final c = competition.build(
      mealComposition: comp,
      mealEmptyingProfile: profile,
      absorptionWindow: window,
      mealStartMinute: 0,
    );
    return c.lnaaSummary!;
  }

  test('LNAA layer uses actual amino-acid fields over protein-source proxy',
      () {
    final withAa = summaryFor(FoodComponent(
      id: 'aa',
      name: 'high-protein food',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: 26,
      fatGrams: 5,
      fiberGrams: 0,
      carbohydrateGrams: 0,
      calories: 200,
      portionGrams: 150,
      sourceDocId: 'fdc',
      proteinSource: ProteinSourceType.meat,
      aminoAcidProfile: loadProfile(),
    ));
    expect(withAa.dataMode, AminoAcidDataMode.actualAminoAcidFields);
    expect(withAa.aminoAcidNutrientIds, isNotEmpty);
    expect(withAa.uncertaintyWidened, isFalse);
  });

  test('missing amino-acid fields falls back to protein-source proxy', () {
    final proxy = summaryFor(const FoodComponent(
      id: 'noaa',
      name: 'meat no aa fields',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: 26,
      fatGrams: 5,
      fiberGrams: 0,
      carbohydrateGrams: 0,
      calories: 200,
      portionGrams: 150,
      sourceDocId: 'x',
      proteinSource: ProteinSourceType.meat,
    ));
    expect(proxy.dataMode, AminoAcidDataMode.proteinSourceProxy);
  });

  test('missing protein and amino acids → unknown mode', () {
    final unknown = summaryFor(const FoodComponent(
      id: 'unk',
      name: 'unknown',
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: null,
      fatGrams: null,
      fiberGrams: null,
      carbohydrateGrams: null,
      calories: null,
      portionGrams: null,
      sourceDocId: 'x',
      proteinSource: ProteinSourceType.unknown,
    ));
    expect(unknown.dataMode, AminoAcidDataMode.unknown);
  });
}
