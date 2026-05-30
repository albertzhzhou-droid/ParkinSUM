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

  test('full FDC amino-acid block: captures lysine/cystine/arginine too (B2)',
      () {
    final payload = jsonDecode(
        File('test/fixtures/importers/usda_fdc_amino_acids_full.json')
            .readAsStringSync()) as Map<String, dynamic>;
    final p = extractor.extractFromFdcStyle(payload);
    expect(p, isNotNull);
    // Fuller coverage: the non-competing indispensable AAs are now captured
    // (mg → g), in addition to the six competing LNAAs.
    expect(p!.lysine, closeTo(2.2, 1e-9)); // 2200 mg
    expect(p.cystine, closeTo(0.35, 1e-9)); // 350 mg
    expect(p.arginine, closeTo(1.6, 1e-9)); // 1600 mg
    expect(p.histidine, closeTo(0.8, 1e-9));
    // Competing-LNAA math is unchanged: only the six BCAA+aromatic AAs count.
    const expectedCompeting =
        2.1 + 1.2 + 1.3 + 1.0 + 0.9 + 0.3; // leu+ile+val+phe+tyr+trp
    expect(p.competingLnaaGrams, closeTo(expectedCompeting, 1e-9));
    // Lysine/cystine/arginine are NOT folded into the competing total.
    expect(p.competingLnaaGrams, isNot(closeTo(expectedCompeting + 2.2, 1e-9)));
    // Provenance from the full fixture (analytical) flows through.
    expect(p.fdcDataType, 'Foundation');
    expect(p.aggregateConfidenceTier, NutrientConfidenceTier.analytical);
  });

  test('only non-competing AAs present → null (proxy fallback) (B2)', () {
    // Lysine/arginine present but no competing LNAA → no competition to model.
    final p = extractor.extractFromFdcStyle({
      'foodNutrients': [
        {
          'nutrient': {'number': '505', 'unitName': 'G'},
          'amount': 2.0
        },
        {
          'nutrient': {'number': '511', 'unitName': 'G'},
          'amount': 1.5
        },
      ]
    });
    expect(p, isNull); // no competing LNAA → caller uses protein-source proxy
  });

  test('missing unit marks the profile partial (not silently trusted)', () {
    final p = extractor.extractFromFdcStyle({
      'foodNutrients': [
        {
          // 504 = leucine (a competing LNAA) with NO unitName → accepted
          // provisionally and the profile is flagged partial.
          'nutrient': {'number': '504', 'name': 'Leucine'},
          'amount': 2.1
        }
      ]
    });
    expect(p, isNotNull);
    expect(p!.partial, isTrue);
  });

  test('correct FDC numbers map to the right amino acids', () {
    // 504 Leucine, 503 Isoleucine, 510 Valine, 502 Threonine, 506 Methionine.
    final p = extractor.extractFromFdcStyle({
      'foodNutrients': [
        {
          'nutrient': {'number': '504', 'unitName': 'G'},
          'amount': 2.0
        },
        {
          'nutrient': {'number': '503', 'unitName': 'G'},
          'amount': 1.0
        },
        {
          'nutrient': {'number': '510', 'unitName': 'G'},
          'amount': 1.5
        },
        {
          'nutrient': {'number': '502', 'unitName': 'G'},
          'amount': 0.9
        },
        {
          'nutrient': {'number': '506', 'unitName': 'G'},
          'amount': 0.6
        },
      ]
    });
    expect(p, isNotNull);
    expect(p!.leucine, 2.0);
    expect(p.isoleucine, 1.0);
    expect(p.valine, 1.5);
    expect(p.threonine, 0.9);
    expect(p.methionine, 0.6);
  });

  test('captures FDC per-nutrient derivation + dataPoints + dataType (B1)', () {
    final p = extractor.extractFromFdcStyle({
      'dataType': 'Foundation',
      'foodNutrients': [
        {
          'nutrient': {'number': '504', 'unitName': 'G'},
          'amount': 2.0,
          'dataPoints': 12,
          'foodNutrientDerivation': {
            'code': 'A',
            'description': 'Analytical',
            'foodNutrientSource': {'code': '1'}
          }
        },
      ]
    });
    expect(p, isNotNull);
    expect(p!.fdcDataType, 'Foundation');
    expect(p.derivations.containsKey('leucine'), isTrue);
    expect(p.derivations['leucine']!.dataPoints, 12);
    expect(p.aggregateConfidenceTier, NutrientConfidenceTier.analytical);
  });

  test('imputed derivation lowers the aggregate tier (weakest-wins)', () {
    final p = extractor.extractFromFdcStyle({
      'foodNutrients': [
        {
          'nutrient': {'number': '504', 'unitName': 'G'},
          'amount': 2.0,
          'foodNutrientDerivation': {'code': 'A', 'description': 'Analytical'}
        },
        {
          'nutrient': {'number': '510', 'unitName': 'G'},
          'amount': 1.3,
          'foodNutrientDerivation': {'description': 'Imputed from similar food'}
        },
      ]
    });
    expect(p, isNotNull);
    expect(p!.aggregateConfidenceTier,
        NutrientConfidenceTier.imputedOrAssumed); // weakest wins
  });

  test('absent derivation → no provenance (missing, never fabricated)', () {
    final p = extractor.extractFromFdcStyle({
      'foodNutrients': [
        {
          'nutrient': {'number': '504', 'unitName': 'G'},
          'amount': 2.0
        },
      ]
    });
    expect(p, isNotNull);
    expect(p!.derivations, isEmpty);
    expect(p.aggregateConfidenceTier, isNull); // missing ≠ confident
    expect(p.fdcDataType, isNull);
  });

  test('number mapping beats a conflicting name', () {
    // Number 504 = Leucine; the (deliberately wrong) name says Valine.
    // The verified number must win.
    final p = extractor.extractFromFdcStyle({
      'foodNutrients': [
        {
          'nutrient': {'number': '504', 'name': 'Valine', 'unitName': 'G'},
          'amount': 2.0
        },
      ]
    });
    expect(p, isNotNull);
    expect(p!.leucine, 2.0);
    expect(p.valine, isNull);
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
