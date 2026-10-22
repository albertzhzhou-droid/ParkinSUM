import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/analysis/medication_repository.dart';
import 'package:parkinsum_companion/core/constants/reference_food_composition_table.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';

/// Food titles follow the display language, and catalogue codes (source
/// systems, routes, dose forms) are shown as readable labels.
void main() {
  final en = AppI18n.fromLocaleTag('en-US');
  final zh = AppI18n.fromLocaleTag('zh-CN');
  final fr = AppI18n.fromLocaleTag('fr-FR');
  final hanCharacters = RegExp(r'[一-鿿]');

  test('reference food titles follow the display language', () {
    const id = 'food_ref_usda_171265';
    const stored = '全脂牛奶（3.25%）';
    expect(en.foodName(id, stored), 'Milk, whole, 3.25% fat');
    expect(zh.foodName(id, stored), stored);
    // Without a translation the English source name is the fallback.
    expect(fr.foodName(id, stored), 'Milk, whole, 3.25% fat');
    expect(AppI18n.fromLocaleTag('ja').foodName(id, stored), isNot(stored));

    // Translated seed names and unknown foods are unchanged.
    expect(en.foodName('food_milk', '半脱脂牛奶'), 'Semi-skimmed milk');
    expect(zh.foodName('food_milk', '半脱脂牛奶'), '半脱脂牛奶');
    expect(en.foodName('imported_food_1', 'Imported name'), 'Imported name');
  });

  test('no catalogue food is titled in Chinese for an English profile', () {
    final foods = FoodRepository.createDefault().allFoods;
    expect(foods, hasLength(greaterThan(referenceFoodCompositionRows.length)));
    for (final food in foods) {
      final title = en.foodName(food.id, food.name);
      expect(title, isNot(matches(hanCharacters)), reason: food.id);
      expect(title.trim(), isNotEmpty, reason: food.id);
    }
    for (final row in referenceFoodCompositionRows) {
      expect(zh.foodName(row.appFoodId, 'x'), row.nameZh);
    }
  });

  test('catalogue codes have readable labels', () {
    expect(en.sourceSystemLabel('USDA_FDC'), 'USDA FoodData Central');
    expect(en.sourceSystemLabel('CIQUAL'), 'ANSES-Ciqual');
    expect(
      en.sourceSystemLabel('RXNORM'),
      'RxNorm (US National Library of Medicine)',
    );
    expect(
      en.dosageFormLabel('tablet_or_odt'),
      'tablet or orally disintegrating tablet',
    );
    expect(zh.dosageFormLabel('tablet_or_odt'), '片剂或口崩片');
    // A language without the key falls back to English, then to a code
    // read as words.
    expect(
      fr.dosageFormLabel('tablet_or_odt'),
      'tablet or orally disintegrating tablet',
    );
    expect(en.dosageFormLabel('some_new_form'), 'some new form');

    for (final i18n in [en, zh]) {
      for (final drug in MedicationRepository.createDefault().allDrugs) {
        for (final label in [
          i18n.sourceSystemLabel(drug.sourceSystem),
          i18n.routeLabel(drug.route),
          i18n.dosageFormLabel(drug.dosageForm),
          i18n.releaseTypeLabel(drug.releaseType),
        ]) {
          expect(label, isNot(contains('_')), reason: '${drug.id}: $label');
          expect(label, isNot(drug.sourceSystem), reason: drug.id);
        }
      }
      for (final food in FoodRepository.createDefault().allFoods) {
        final label = i18n.sourceSystemLabel(food.sourceSystem);
        expect(label, isNot(food.sourceSystem), reason: food.id);
      }
    }
  });

  test('the medications-only search field is not labelled for foods', () {
    for (final family in AppI18n.translationFamilies) {
      expect(
        AppI18n.translationDictionary[family],
        contains('onboarding.medication_search'),
        reason: family,
      );
      expect(
        AppI18n.translationDictionary[family]!['onboarding.medication_search'],
        isNot(AppI18n.translationDictionary[family]!['catalog.search']),
        reason: family,
      );
    }
    expect(en.tr('onboarding.medication_search'), 'Search medications');
  });
}
