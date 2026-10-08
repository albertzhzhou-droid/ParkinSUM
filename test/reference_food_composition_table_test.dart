import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/constants/p0_food_source_seed.dart';
import 'package:parkinsum_companion/core/constants/reference_food_catalog.dart';
import 'package:parkinsum_companion/core/constants/reference_food_composition_table.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/entities/reference_food_composition.dart';
import 'package:parkinsum_companion/domain/usecases/food_composition_interdependency_model.dart';

import '../tool/reference_food_composition_codegen.dart';

/// Accuracy guard for the USDA SR Legacy reference subset.
///
/// The generated Dart table must reproduce every published value in
/// tool/data/usda_sr_legacy_reference_subset_2018.csv exactly, and every
/// record must satisfy the definitional identities that tie its nutrients
/// together. Educational prototype; values describe foods, not people.
void main() {
  final csvRows = parseSubsetRows(
    File(referenceSubsetCsvPath).readAsStringSync(),
  );
  final curation =
      (jsonDecode(File(referenceCurationJsonPath).readAsStringSync())
              as Map<String, dynamic>)['foods']
          as Map<String, dynamic>;

  test('generated table reproduces every source value exactly', () {
    expect(referenceFoodCompositionRows, hasLength(csvRows.length));
    expect(csvRows, hasLength(224));
    for (var i = 0; i < csvRows.length; i++) {
      final source = csvRows[i];
      final row = referenceFoodCompositionRows[i];
      expect(row.fdcId, source.fdcId);
      expect(row.sourceDescription, source.description);
      final pairs = <String, double?>{
        'Energy': row.energyKcal,
        'Protein': row.proteinG,
        'Fat': row.fatG,
        'Carbohydrate': row.carbohydrateByDifferenceG,
        'Fiber': row.fiberG,
        'Calcium': row.calciumMg,
        'Phosphorus': row.phosphorusMg,
        'Iron': row.ironMg,
        'Sodium': row.sodiumMg,
        'Potassium': row.potassiumMg,
        'Copper': row.copperMg,
        'Zinc': row.zincMg,
        'Retinol': row.retinolUg,
        'Beta_Carotene': row.betaCaroteneUg,
        'Thiamine': row.thiaminMg,
        'Riboflavin': row.riboflavinMg,
        'Niacin': row.niacinMg,
        'Vitamin_C': row.vitaminCMg,
      };
      for (final entry in pairs.entries) {
        expect(
          entry.value,
          source.number(entry.key),
          reason: '${row.fdcId} ${entry.key} drifted from the source file',
        );
      }
      final meta = curation['${row.fdcId}'] as Map<String, dynamic>;
      expect(row.nameEn, meta['en']);
      expect(row.nameZh, meta['zh']);
      expect(row.preparationState, meta['state']);
      expect(row.textureClass, meta['texture']);
      expect(row.group, referenceFoodGroupFromWire(meta['group'] as String));
    }
  });

  test('generator output is stable for the committed inputs', () {
    final rendered = renderReferenceTable(
      csvText: File(referenceSubsetCsvPath).readAsStringSync(),
      curationJsonText: File(referenceCurationJsonPath).readAsStringSync(),
    );
    // Every fdc id and description in the committed table came from the
    // generator (formatting aside).
    for (final row in referenceFoodCompositionRows) {
      expect(rendered, contains('fdcId: ${row.fdcId},'));
    }
  });

  test('the subset covers every major food group', () {
    final groups = referenceFoodCompositionRows.map((r) => r.group).toSet();
    expect(groups, containsAll(ReferenceFoodGroup.values));
    final ids = referenceFoodCompositionRows.map((r) => r.fdcId).toList();
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('missing values stay null rather than becoming zero', () {
    // Tempeh has no reported fibre; shiitake has no reported vitamin C.
    final tempeh = referenceRowsByFdcId[174272]!;
    expect(tempeh.fiberG, isNull);
    expect(availableCarbohydrateOf(tempeh), isNull);
    final shiitake = referenceRowsByFdcId[169242]!;
    expect(shiitake.vitaminCMg, isNull);
  });

  test('every record satisfies the definitional nutrient identities', () {
    final failures = <String>[];
    for (final row in referenceFoodCompositionRows) {
      final audit = auditReferenceRow(row);
      if (!audit.isConsistent) {
        failures.add(
          '${row.fdcId} ${row.sourceDescription}: '
          '${audit.findings.map((f) => '${f.code} ${f.detail}').join('; ')}',
        );
      }
    }
    expect(failures, isEmpty, reason: failures.join('\n'));
  });

  test('energy residuals are explained by alcohol or organic acids', () {
    double alcohol(int fdcId) =>
        auditReferenceRow(referenceRowsByFdcId[fdcId]!).energy.impliedAlcoholG!;
    // Red table wine ≈ 13% v/v; regular beer ≈ 5% v/v; 80-proof spirits 40%.
    expect(alcohol(173190), closeTo(10.6, 0.2));
    expect(alcohol(168746), closeTo(3.9, 0.2));
    expect(alcohol(174815), closeTo(33.0, 0.2));
    final vinegar = auditReferenceRow(referenceRowsByFdcId[173469]!).energy;
    expect(vinegar.status, EnergyReconciliationStatus.explainedByOrganicAcids);
    expect(vinegar.impliedOrganicAcidG, closeTo(5.8, 0.2));
  });

  test('carbohydrate is harmonised to the available convention', () {
    final banana = referenceRowsByFdcId[173944]!;
    expect(banana.carbohydrateByDifferenceG, 22.84);
    expect(availableCarbohydrateOf(banana), closeTo(20.24, 1e-9));
    final oil = referenceRowsByFdcId[171413]!;
    expect(availableCarbohydrateOf(oil), 0.0);
  });

  test('catalog projection harmonises carbohydrate and keeps unknowns', () {
    final foods = {for (final f in buildReferenceFoodCatalog()) f.id: f};
    final banana = foods['food_ref_usda_173944']!;
    expect(banana.carbsG, closeTo(20.24, 1e-9));
    expect(banana.energyKcal, 89.0);
    expect(banana.sodiumMg, 1.0);
    expect(banana.sourceFoodCode, '173944');
    expect(banana.missingNutrientFields, {'waterG'});
    final tempeh = foods['food_ref_usda_174272']!;
    expect(tempeh.missingNutrientFields, containsAll(['fiberG', 'carbsG']));
    final milk = foods['food_ref_usda_171265']!;
    expect(milk.textureClass, 'liquid');
    expect(milk.category, FoodCategory.dairy);
  });

  test('default repository adds the reference subset without id clashes', () {
    final p0Ids = buildP0FoodCatalog().map((f) => f.id).toSet();
    final referenceIds = buildReferenceFoodCatalog().map((f) => f.id).toSet();
    expect(p0Ids.intersection(referenceIds), isEmpty);
    final all = FoodRepository.createDefault().allFoods;
    expect(all.length, p0Ids.length + referenceIds.length);
    expect(all.map((f) => f.id).toSet(), hasLength(all.length));
  });

  test('P0 seed marks fields it does not carry as unknown, not zero', () {
    for (final food in buildP0FoodCatalog()) {
      expect(
        food.missingNutrientFields,
        containsAll(['sodiumMg', 'energyKcal', 'waterG']),
        reason: food.id,
      );
    }
  });
}
