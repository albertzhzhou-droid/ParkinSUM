import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/analysis/catalog_engine.dart';
import 'package:parkinsum_companion/core/analysis/catalog_search_index.dart';
import 'package:parkinsum_companion/core/analysis/food_repository.dart';
import 'package:parkinsum_companion/core/analysis/interaction_engine.dart';
import 'package:parkinsum_companion/core/analysis/medication_repository.dart';
import 'package:parkinsum_companion/core/analysis/nutrition_classifier.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';

void main() {
  // Manually frozen before the actual old-index probe or production change.
  const texts = {
    'first': 'Café au lait',
    'second': 'Decaf cafe',
    'third': 'Green tea',
    'apple': 'Apple 苹果',
    'medicine': '薬品 medicine',
  };
  const cases = <(String, int?, List<String>)>[
    ('c', null, ['first', 'second', 'medicine']),
    ('ca', null, ['first', 'second']),
    ('fe', null, ['first', 'second']),
    ('苹', null, ['apple']),
    ('苹果', null, ['apple']),
    ('薬', null, ['medicine']),
    ('薬品', null, ['medicine']),
    ('CAFE', null, ['first', 'second']),
    ('een t', null, ['third']),
    ('absent', null, []),
    ('', null, ['first', 'second', 'third', 'apple', 'medicine']),
    ('cafe', 0, []),
  ];
  for (final (query, limit, expected) in cases) {
    test('independent substring expectation $query limit=$limit', () {
      final index = CatalogSearchIndex<String>(
        items: texts.keys,
        searchableText: (id) => texts[id]!,
      );
      expect(index.search(query, limit: limit), expected);
    });
  }

  test('short queries retain source order, limits and immutable snapshots', () {
    final items = ['z', 'a', 'b'];
    final index = CatalogSearchIndex<String>(
      items: items,
      searchableText: (_) => 'Café cafe repeated cafe',
    );
    items.clear();
    expect(index.search('ca'), ['z', 'a', 'b']);
    expect(index.search('ca', limit: 1), ['z']);
    expect(index.search('ca', limit: 2), ['z', 'a']);
    expect(index.search('ca', limit: 0), isEmpty);
    expect(index.search('', limit: 0), isEmpty);
    expect(() => index.search('ca').add('extra'), throwsUnsupportedError);
    expect(
      () => index.search('', limit: 0).add('extra'),
      throwsUnsupportedError,
    );
  });

  test(
    'negative limits reject consistently for empty and nonempty queries',
    () {
      final index = CatalogSearchIndex<String>(
        items: const ['Café'],
        searchableText: (value) => value,
      );
      for (final query in ['', 'cafe']) {
        expect(() => index.search(query, limit: -1), throwsRangeError);
      }
    },
  );

  test('one and two rune queries include supplementary Unicode characters', () {
    final index = CatalogSearchIndex<String>(
      items: const ['Brain 🧠 tracker', 'Other record'],
      searchableText: (value) => value,
    );
    expect(index.search('🧠'), ['Brain 🧠 tracker']);
    expect(index.search('🧠 t'), ['Brain 🧠 tracker']);
    expect(index.search('record missing'), isEmpty);
  });

  test('index supports substring, accent folding, and stable source order', () {
    final index = CatalogSearchIndex<String>(
      items: const ['first', 'second', 'third'],
      searchableText: (item) => switch (item) {
        'first' => 'Café au lait',
        'second' => 'Decaf cafe',
        _ => 'Green tea',
      },
    );

    expect(index.search('CAFE'), ['first', 'second']);
    expect(index.search('fé au'), ['first']);
    expect(index.search('een t'), ['third']);
  });

  test(
    'catalog engine rebuilds the index only when repository revision changes',
    () {
      final foods = FoodRepository.createDefault();
      final medications = MedicationRepository.createDefault();
      final engine = CatalogEngine(
        foodRepo: foods,
        medRepo: medications,
        interactionEngine: InteractionEngine(),
        nutritionClassifier: NutritionClassifier(),
      );
      final initialRevision = foods.revision;
      expect(engine.searchFoods('new indexed food'), isEmpty);

      foods.replaceAll([
        FoodItem(
          id: 'food_new_indexed',
          name: 'New Indexed Food',
          category: FoodCategory.other,
          proteinG: 0,
          carbsG: 0,
          fatG: 0,
          fiberG: 0,
          sodiumMg: 0,
        ),
      ]);

      expect(foods.revision, initialRevision + 1);
      expect(engine.searchFoods('indexed').single.id, 'food_new_indexed');
    },
  );

  test(
    'food and drug metadata search follows independent revision changes',
    () {
      final foods = FoodRepository.createDefault();
      final drugs = MedicationRepository.createDefault();
      final engine = CatalogEngine(
        foodRepo: foods,
        medRepo: drugs,
        interactionEngine: InteractionEngine(),
        nutritionClassifier: NutritionClassifier(),
      );
      foods.replaceAll([
        _food('synthetic_apple', 'Fruit', '苹', 'CIQUAL', 'FR'),
      ]);
      drugs.replaceAll([
        DrugDefinition(
          id: 'synthetic_drug',
          genericName: 'Synthetic medicine',
          brandNames: const ['BrandFixture'],
          aliases: const ['薬品'],
          tags: const [DrugTag.unknown],
          notes: 'Synthetic metadata only',
          sourceSystem: 'DAILYMED',
          jurisdiction: 'JP',
          route: 'oral',
          dosageForm: 'capsule',
          releaseType: 'unspecified',
          sourceProductCode: 'fixture-product',
        ),
      ]);
      for (final query in ['苹', 'ciqual', 'FR']) {
        expect(engine.searchFoods(query).single.id, 'synthetic_apple');
      }
      for (final query in [
        '薬',
        '薬品',
        'brandfixture',
        'dailymed',
        'JP',
        'oral',
        'capsule',
        'fixture-product',
      ]) {
        expect(engine.searchDrugs(query).single.id, 'synthetic_drug');
      }
      final foodRevision = foods.revision;
      final drugRevision = drugs.revision;
      foods.replaceAll([
        _food('synthetic_tea', 'Tea', '茶', 'LOCAL_SEED', 'CA'),
      ]);
      expect(foods.revision, foodRevision + 1);
      expect(engine.searchFoods('苹'), isEmpty);
      expect(engine.searchFoods('茶').single.id, 'synthetic_tea');
      expect(engine.searchDrugs('薬').single.id, 'synthetic_drug');
      drugs.replaceAll([
        DrugDefinition(
          id: 'synthetic_replacement',
          genericName: 'Replacement',
          brandNames: const [],
          aliases: const ['新'],
          tags: const [DrugTag.unknown],
          notes: 'Synthetic replacement only',
        ),
      ]);
      expect(drugs.revision, drugRevision + 1);
      expect(engine.searchDrugs('薬'), isEmpty);
      expect(engine.searchDrugs('新').single.id, 'synthetic_replacement');
      expect(engine.searchFoods('茶').single.id, 'synthetic_tea');
    },
  );
}

FoodItem _food(
  String id,
  String name,
  String alias,
  String source,
  String jurisdiction,
) => FoodItem(
  id: id,
  name: name,
  category: FoodCategory.other,
  aliases: [alias],
  sourceSystem: source,
  jurisdiction: jurisdiction,
  proteinG: 0,
  carbsG: 0,
  fatG: 0,
  fiberG: 0,
  sodiumMg: 0,
);
