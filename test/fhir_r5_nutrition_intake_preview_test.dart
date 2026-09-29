import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/timeline_event.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r5_nutrition_intake_mapper.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';
import 'package:provider/provider.dart';

Meal _meal({
  String id = 'private-meal-id',
  String title = 'private meal title',
  DateTime? occurredAt,
  DateTime? occurredRangeStart,
  DateTime? occurredRangeEnd,
  String timeSource = 'user_exact',
  String timePrecision = 'exact',
  List<MealItem>? items,
}) => Meal(
  id: id,
  title: title,
  eatenAt: occurredAt ?? DateTime(2026, 9, 26, 9, 15),
  recordedAt: DateTime(2026, 9, 26, 9, 20),
  occurredAt: occurredAt ?? DateTime(2026, 9, 26, 9, 15),
  occurredRangeStart: occurredRangeStart,
  occurredRangeEnd: occurredRangeEnd,
  timeSource: timeSource,
  timePrecision: timePrecision,
  items: items ?? <MealItem>[_item()],
);

MealItem _item({
  String foodId = 'private-food-id',
  String foodName = 'Green tea',
  FoodCategory category = FoodCategory.beverage,
  double quantityFactor = 1.25,
}) => MealItem(
  foodId: foodId,
  foodName: foodName,
  foodCategory: category,
  quantityFactor: quantityFactor,
  foodTags: const <String>['private-tag'],
  proteinPer100g: 1.2,
  carbsPer100g: 2.3,
  fatPer100g: 3.4,
  fiberPer100g: 4.5,
  sodiumPer100g: 6.7,
);

void main() {
  const mapper = FhirR5NutritionIntakeMapper();

  group('FHIR R5 NutritionIntake preview mapper', () {
    test('projects one text-only meal without internal IDs or nutrients', () {
      final resource = mapper.fromMeal(
        _meal(),
        patientReference: 'Patient/patient-123',
      );
      final encoded = jsonEncode(resource);
      final item = (resource['consumedItem'] as List).single as Map;

      expect(resource['resourceType'], 'NutritionIntake');
      expect(resource['status'], 'unknown');
      expect(resource['subject'], {'reference': 'Patient/patient-123'});
      expect(resource['occurrenceDateTime'], '2026-09-26');
      expect(item['type'], {'text': 'beverage'});
      expect(item['nutritionProduct'], {
        'concept': {'text': 'Green tea'},
      });
      expect(item['amount'], {
        'value': 125.0,
        'unit': 'g',
        'system': 'http://unitsofmeasure.org',
        'code': 'g',
      });
      for (final omitted in [
        'private-meal-id',
        'private meal title',
        'private-food-id',
        'private-tag',
        'proteinPer100g',
        'sodiumPer100g',
        'ingredientLabel',
        'recorded',
      ]) {
        expect(encoded, isNot(contains(omitted)));
      }
      expect(item, isNot(contains('coding')));
      expect(resource['note'], hasLength(1));
      expect(
        ((resource['note'] as List).single as Map)['text'],
        contains('status is unknown'),
      );
    });

    test('preserves offset-bearing times and represents explicit ranges', () {
      final exact = mapper.fromMeal(
        _meal(occurredAt: DateTime.utc(2026, 9, 26, 13, 15)),
        patientReference: 'Patient/patient-123',
      );
      expect(exact['occurrenceDateTime'], '2026-09-26T13:15:00.000Z');

      final interval = mapper.fromMeal(
        _meal(
          occurredAt: null,
          timeSource: 'user_interval',
          timePrecision: 'interval',
          occurredRangeStart: DateTime(2026, 9, 26, 9),
          occurredRangeEnd: DateTime(2026, 9, 26, 10),
        ),
        patientReference: 'Patient/patient-123',
      );
      expect(interval['occurrencePeriod'], {
        'start': '2026-09-26',
        'end': '2026-09-26',
      });
      expect(interval, isNot(contains('occurrenceDateTime')));
    });

    test(
      'omits default and migrated times rather than asserting occurrence',
      () {
        final legacy = mapper.fromMeal(
          _meal(timeSource: 'migration_legacy'),
          patientReference: 'Patient/patient-123',
        );

        expect(legacy, isNot(contains('occurrenceDateTime')));
        expect(legacy, isNot(contains('occurrencePeriod')));
      },
    );

    test(
      'rejects invalid references, item names, serving values, and ranges',
      () {
        expect(
          () => mapper.fromMeal(
            _meal(),
            patientReference: 'http://ehr.example/Patient/patient-123',
          ),
          throwsFormatException,
        );
        expect(
          () => mapper.fromMeal(
            _meal(items: <MealItem>[_item(foodName: '  ')]),
            patientReference: 'Patient/patient-123',
          ),
          throwsFormatException,
        );
        expect(
          () => mapper.fromMeal(
            _meal(items: <MealItem>[_item(quantityFactor: double.infinity)]),
            patientReference: 'Patient/patient-123',
          ),
          throwsFormatException,
        );
        expect(
          () => mapper.fromMeal(
            _meal(
              occurredAt: null,
              timeSource: 'user_interval',
              timePrecision: 'interval',
              occurredRangeStart: DateTime(2026, 9, 27),
              occurredRangeEnd: DateTime(2026, 9, 26),
            ),
            patientReference: 'Patient/patient-123',
          ),
          throwsFormatException,
        );
        expect(
          () => mapper.fromMeal(
            _meal(items: const <MealItem>[]),
            patientReference: 'Patient/patient-123',
          ),
          throwsFormatException,
        );
      },
    );

    test('returns a deeply immutable resource', () {
      final resource = mapper.fromMeal(
        _meal(),
        patientReference: 'Patient/patient-123',
      );

      expect(() => resource['status'] = 'completed', throwsUnsupportedError);
      expect(
        () => (resource['subject'] as Map)['reference'] = 'Patient/other',
        throwsUnsupportedError,
      );
      expect(
        () => (resource['consumedItem'] as List).clear(),
        throwsUnsupportedError,
      );
      expect(
        () =>
            (((resource['consumedItem'] as List).single as Map)['amount']
                    as Map)['value'] =
                999,
        throwsUnsupportedError,
      );
    });
  });

  testWidgets('timeline previews locally and copies only after review', (
    tester,
  ) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = _MealTimelineState(services);
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TimelinePage()),
      ),
    );
    final meal = _meal();
    state.seed(meal);
    await tester.pumpAndSettle();

    String? clipboardText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _tap(tester, 'fhir-r5-nutrition-intake-export-${meal.id}');
    await tester.enterText(
      find.byKey(
        ValueKey('fhir-r5-nutrition-intake-patient-reference-${meal.id}'),
      ),
      'Patient/patient-123',
    );
    await _tap(tester, 'fhir-r5-nutrition-intake-export-preview');
    final previewText = tester
        .widget<SelectableText>(
          find.byKey(
            const ValueKey('fhir-r5-nutrition-intake-export-preview-json'),
          ),
        )
        .data!;
    final preview = jsonDecode(previewText) as Map<String, dynamic>;

    expect(preview['resourceType'], 'NutritionIntake');
    expect(preview['status'], 'unknown');
    expect(previewText, contains('Patient/patient-123'));
    expect(previewText, isNot(contains('private-meal-id')));
    expect(previewText, isNot(contains('private-food-id')));
    expect(clipboardText, isNull);
    expect(state.meals.single.toJson(), meal.toJson());

    await _tap(tester, 'fhir-r5-nutrition-intake-export-copy');
    expect(jsonDecode(clipboardText!)['resourceType'], 'NutritionIntake');
    expect(state.meals.single.toJson(), meal.toJson());
    expect(find.text('FHIR JSON copied to the clipboard.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing the meal expires its open NutritionIntake preview', (
    tester,
  ) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = _MealTimelineState(services);
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TimelinePage()),
      ),
    );
    final meal = _meal();
    state.seed(meal);
    await tester.pumpAndSettle();

    await _tap(tester, 'fhir-r5-nutrition-intake-export-${meal.id}');
    await tester.enterText(
      find.byKey(
        ValueKey('fhir-r5-nutrition-intake-patient-reference-${meal.id}'),
      ),
      'Patient/patient-123',
    );
    await _tap(tester, 'fhir-r5-nutrition-intake-export-preview');
    expect(
      find.byKey(
        const ValueKey('fhir-r5-nutrition-intake-export-preview-json'),
      ),
      findsOneWidget,
    );

    state.seed(meal.copyWith(title: 'updated title'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('fhir-r5-nutrition-intake-export-preview-json'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fhir-r5-nutrition-intake-export-copy')),
      findsNothing,
    );
    expect(find.textContaining('meal record changed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('account switch expires the NutritionIntake preview', (
    tester,
  ) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = _MealTimelineState(services);
    addTearDown(state.dispose);
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: TimelinePage()),
      ),
    );
    final meal = _meal();
    state.seed(meal);
    await tester.pumpAndSettle();

    await _tap(tester, 'fhir-r5-nutrition-intake-export-${meal.id}');
    await tester.enterText(
      find.byKey(
        ValueKey('fhir-r5-nutrition-intake-patient-reference-${meal.id}'),
      ),
      'Patient/patient-123',
    );
    await _tap(tester, 'fhir-r5-nutrition-intake-export-preview');
    expect(
      find.byKey(
        const ValueKey('fhir-r5-nutrition-intake-export-preview-json'),
      ),
      findsOneWidget,
    );

    state.switchOwner('owner-b');
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('fhir-r5-nutrition-intake-export-preview-json'),
      ),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('fhir-r5-nutrition-intake-export-copy')),
      findsNothing,
    );
    expect(find.textContaining('account changed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey(key)));
  await tester.pumpAndSettle();
}

class _MealTimelineState extends AppState {
  _MealTimelineState(Services services) : super(services: services);

  String _owner = 'owner-a';
  List<Meal> _records = const <Meal>[];

  @override
  String? get currentUserId => _owner;

  @override
  UserProfile get userProfile => UserProfile.defaults();

  @override
  List<Meal> get meals => List<Meal>.unmodifiable(_records);

  @override
  List<TimelineEvent> get timeline => [
    for (final meal in _records) TimelineEvent.fromMeal(meal),
  ];

  void seed(Meal meal) {
    _records = <Meal>[meal];
    notifyListeners();
  }

  void switchOwner(String owner) {
    _owner = owner;
    notifyListeners();
  }
}
