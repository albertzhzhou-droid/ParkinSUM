@Timeout(Duration(minutes: 5))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/administration_dose_confirmation.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/next_meal_plan.dart';
import 'package:parkinsum_companion/features/entry/entry_page.dart';
import 'package:parkinsum_companion/features/next_meal/next_meal_page.dart';
import 'package:provider/provider.dart';

/// Synthetic day only (Etc/UTC, 2026-10-20): a confirmed oral
/// immediate-release levodopa dose at 08:00 and another logged for 13:00, a
/// breakfast of tofu at 08:15. The clock reads 11:30.
final _now = DateTime.utc(2026, 10, 20, 11, 30);
const _drug = 'drug_levodopa_carbidopa';

Future<AppState> _fixture({bool withDoses = true}) async {
  final services = Services.createEphemeral();
  await services.ready;
  await services.userDataService.saveOnboarded(true);
  final state = AppState(services: services);
  await state.bootstrap();
  await state.saveUserProfile(
    state.userProfile.copyWith(timezone: 'Etc/UTC', displayLocale: 'en-US'),
  );
  final tofu = state.foodRepo.allFoods.firstWhere((f) => f.id == 'food_tofu');
  await state.addMeal(
    Meal(
      id: 'synthetic-breakfast',
      title: 'Breakfast',
      eatenAt: DateTime.utc(2026, 10, 20, 8, 15),
      items: [MealItem.fromFood(food: tofu, quantityFactor: 1.5)],
    ),
  );
  if (withDoses) {
    await state.setActiveDrugIds([_drug]);
    for (final (id, hour) in [('dose-08', 8), ('dose-13', 13)]) {
      final saved = await state.saveIntakeWithDoseConfirmation(
        draft: Intake(
          id: id,
          drugId: _drug,
          takenAt: DateTime.utc(2026, 10, 20, hour),
          dosageNote: '100 mg',
          doseAmount: 100,
          doseUnit: 'mg',
          route: 'oral',
          dosageForm: 'tablet',
          releaseType: 'immediate',
        ),
        isUpdate: false,
        expectedRecordRevisionDigest:
            administrationDoseConfirmationAbsentRevisionDigest,
        confirmationRequested: true,
        assertionSource: AdministrationDoseAssertionSource.typed,
        confirmationAction: 'test.explicit_confirmation',
        uiContractVersion: 'next-meal-planner-test:1',
      );
      expect(saved.mutation, isNotNull);
    }
  }
  return state;
}

Widget _host(AppState state, {ThemeData? theme, DateTime? plannedAt}) =>
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        theme: theme,
        home: NextMealPage(clock: () => _now, initialPlannedAt: plannedAt),
      ),
    );

Future<void> _size(
  WidgetTester tester,
  double width, {
  double height = 6000,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, height);
  addTearDown(tester.view.reset);
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  final scrollable = find
      .descendant(
        of: find.byKey(const ValueKey('next-meal-browser-scroll')),
        matching: find.byType(Scrollable),
      )
      .first;
  // Look upward first, then downward; lists build lazily.
  for (final delta in [-300.0, 300.0]) {
    if (target.evaluate().isNotEmpty) break;
    try {
      await tester.scrollUntilVisible(
        target,
        delta,
        scrollable: scrollable,
        maxScrolls: 60,
      );
    } on StateError {
      // Not in this direction.
    }
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> _tap(
  WidgetTester tester,
  Finder target, {
  bool settle = true,
}) async {
  await _reveal(tester, target);
  await tester.tap(target);
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// Food card ids in the order the page shows them.
List<String> _shownIds(WidgetTester tester) => [
  for (final e
      in find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith(
                  'next-meal-food-',
                ),
          )
          .evaluate())
    (e.widget.key! as ValueKey<String>).value.substring(
      'next-meal-food-'.length,
    ),
];

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

void main() {
  testWidgets('food cards show serving, chips, source, data and a modeled '
      'effect for the planned time', (tester) async {
    await _size(tester, 1280);
    final state = (await tester.runAsync(_fixture))!;
    addTearDown(state.dispose);
    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    expect(_text(tester, 'next-meal-planned-time'), '11:30');
    // Nearest logged dose is 13:00: the meal is 90 min before it.
    expect(find.textContaining('meal 90 min before the dose'), findsOneWidget);
    final tofuCard = find.byKey(const ValueKey('next-meal-food-food_tofu'));
    expect(tofuCard, findsOneWidget);
    // Familiar foods come first in the neutral default order.
    final firstCard = find
        .byWidgetPredicate(
          (w) =>
              w.key is ValueKey<String> &&
              (w.key! as ValueKey<String>).value.startsWith('next-meal-food-'),
        )
        .first;
    expect(
      tester.widget(firstCard).key,
      const ValueKey('next-meal-food-food_tofu'),
    );
    for (final pattern in [
      'Logged before · 1×',
      'Protein ',
      'Energy ',
      'LNAA',
      'Soft',
      'Data ',
    ]) {
      expect(
        find.descendant(of: tofuCard, matching: find.textContaining(pattern)),
        findsWidgets,
        reason: pattern,
      );
    }
    expect(
      find.descendant(
        of: tofuCard,
        matching: find.textContaining(
          RegExp(r'Modeled brain entry ≈ \d+% of no meal \(band \d+–\d+%\)'),
        ),
      ),
      findsOneWidget,
    );
    // A food without a recorded form is bracketed solid to liquid.
    final unknownForm = state.nextMealCandidates.firstWhere(
      (c) =>
          c.food.textureClass == null &&
          c.proteinG != null &&
          c.energyKcal != null &&
          c.familiar == false,
    );
    expect(
      state.nextMealPlanner
          .candidateEffect(unknownForm, state.nextMealDoseContext(_now))
          .availability,
      NextMealModelAvailability.bracketed,
    );
    expect(find.textContaining('No food is ranked as better'), findsOneWidget);
    expect(
      find.textContaining(RegExp('recommend|best', caseSensitive: false)),
      findsNothing,
    );
  });

  testWidgets('without a levodopa dose every card says why it cannot model', (
    tester,
  ) async {
    await _size(tester, 1280);
    final state = (await tester.runAsync(() => _fixture(withDoses: false)))!;
    addTearDown(state.dispose);
    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();
    expect(
      find.textContaining("Can't model: no levodopa medicine is in your list"),
      findsWidgets,
    );
    expect(find.textContaining('Modeled brain entry ≈'), findsNothing);
    // Anchors need logged doses; they are disabled and say so.
    final last = tester.widget<OutlinedButton>(
      find.byKey(const ValueKey('next-meal-anchor-last')),
    );
    expect(last.onPressed, isNull);
    expect(
      find.textContaining('No dose is logged before now.'),
      findsOneWidget,
    );
  });

  testWidgets('plate builder: servings steppers, running totals and a live '
      'what-if chart', (tester) async {
    await _size(tester, 1280);
    final state = (await tester.runAsync(_fixture))!;
    addTearDown(state.dispose);
    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next-meal-plate-empty')), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('next-meal-add-food_tofu')));
    expect(
      find.byKey(const ValueKey('next-meal-plate-item-food_tofu')),
      findsOneWidget,
    );
    final protein1 = _totalProtein(tester);
    await _tap(tester, find.byKey(const ValueKey('next-meal-more-food_tofu')));
    expect(find.textContaining('1.5 × serving'), findsOneWidget);
    expect(_totalProtein(tester), closeTo(protein1 * 1.5, 0.11));

    final chart = find.byKey(const ValueKey('next-meal-chart-brain-entry'));
    expect(chart, findsOneWidget);
    final semantics = tester.getSemantics(chart).label;
    expect(semantics, contains('brain-entry index'));
    expect(semantics, contains('modeled brain delivery ≈'));
    final before = _text(tester, 'next-meal-plate-chart-summary');
    expect(before, contains('meal 90 min before the dose'));

    // Moving the planned time updates the chart: +15 min.
    await _tap(tester, find.byKey(const ValueKey('next-meal-time-plus')));
    expect(_text(tester, 'next-meal-planned-time'), '11:45');
    final after = _text(tester, 'next-meal-plate-chart-summary');
    expect(after, contains('meal 75 min before the dose'));
    expect(after, isNot(before));

    // The minimum is half a serving; the button disables there.
    await _tap(tester, find.byKey(const ValueKey('next-meal-less-food_tofu')));
    await _tap(tester, find.byKey(const ValueKey('next-meal-less-food_tofu')));
    expect(find.textContaining('0.5 × serving'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byKey(const ValueKey('next-meal-less-food_tofu')),
          )
          .onPressed,
      isNull,
    );
    await _tap(
      tester,
      find.byKey(const ValueKey('next-meal-remove-food_tofu')),
    );
    expect(find.byKey(const ValueKey('next-meal-plate-empty')), findsOneWidget);
  });

  testWidgets('typed time and dose anchors set the planned time', (
    tester,
  ) async {
    await _size(tester, 1280);
    final state = (await tester.runAsync(_fixture))!;
    addTearDown(state.dispose);
    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();
    await _tap(tester, find.byKey(const ValueKey('next-meal-time-type')));
    await tester.enterText(
      find.byKey(const ValueKey('next-meal-time-field')),
      '25:00',
    );
    await _tap(tester, find.byKey(const ValueKey('next-meal-time-apply')));
    expect(find.textContaining('Enter a time as HH:MM'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('next-meal-time-field')),
      '12:40',
    );
    await _tap(tester, find.byKey(const ValueKey('next-meal-time-apply')));
    expect(_text(tester, 'next-meal-planned-time'), '12:40');

    await _tap(
      tester,
      find.byKey(const ValueKey('next-meal-anchor-after-last')),
    );
    expect(_text(tester, 'next-meal-planned-time'), '08:30');
    expect(find.textContaining('meal 30 min after the dose'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('next-meal-anchor-next')));
    expect(_text(tester, 'next-meal-planned-time'), '13:00');
    expect(find.textContaining('meal at the dose time'), findsOneWidget);
  });

  testWidgets('compare holds up to three foods or plates on the same rows', (
    tester,
  ) async {
    await _size(tester, 1280);
    final state = (await tester.runAsync(_fixture))!;
    addTearDown(state.dispose);
    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();
    final ids = _shownIds(tester).take(3).toList();
    await _tap(tester, find.byKey(ValueKey('next-meal-pin-${ids[0]}')));
    await _tap(tester, find.byKey(ValueKey('next-meal-pin-${ids[1]}')));
    await _tap(tester, find.byKey(ValueKey('next-meal-add-${ids[0]}')));
    await _tap(tester, find.byKey(const ValueKey('next-meal-pin-plate')));
    final compare = find.byKey(const ValueKey('next-meal-compare'));
    await _reveal(tester, compare);
    expect(compare, findsOneWidget);
    for (final row in [
      'Protein',
      'Energy',
      'LNAA',
      'Modeled brain entry',
      'Plasma levodopa area',
      'Data',
    ]) {
      expect(
        find.descendant(of: compare, matching: find.text(row)),
        findsNWidgets(3),
        reason: row,
      );
    }
    expect(
      find.byKey(const ValueKey('next-meal-compare-plate-1')),
      findsOneWidget,
    );
    await _tap(tester, find.byKey(ValueKey('next-meal-pin-${ids[2]}')));
    expect(
      find.text('Compare holds 3 items; unpin one first.'),
      findsOneWidget,
    );
  });

  testWidgets('sort and filters are the user\'s choice', (tester) async {
    await _size(tester, 1280);
    final state = (await tester.runAsync(_fixture))!;
    addTearDown(state.dispose);
    await tester.pumpWidget(_host(state));
    await tester.pumpAndSettle();

    await _tap(tester, find.byKey(const ValueKey('next-meal-sort')));
    await tester.tap(find.text('Protein per serving').last);
    await tester.pumpAndSettle();
    final byProtein = [
      ...state.nextMealCandidates.where((c) => c.proteinG != null),
    ]..sort((a, b) => b.proteinG!.compareTo(a.proteinG!));
    expect(
      find.byKey(ValueKey('next-meal-food-${byProtein.first.id}')),
      findsOneWidget,
    );
    expect(find.text('High to low'), findsOneWidget);
    await _tap(tester, find.byKey(const ValueKey('next-meal-sort-reverse')));
    expect(find.text('Low to high'), findsOneWidget);

    await _tap(tester, find.byKey(const ValueKey('next-meal-filters')));
    await _tap(
      tester,
      find.byKey(const ValueKey('next-meal-filter-group-dairy')),
    );
    final dairy = state.nextMealCandidates
        .where((c) => c.food.category.name == 'dairy')
        .length;
    expect(
      _text(tester, 'next-meal-result-count'),
      '$dairy of $dairy foods shown',
    );
    await _tap(tester, find.byKey(const ValueKey('next-meal-filter-complete')));
    final complete = state.nextMealCandidates
        .where((c) => c.food.category.name == 'dairy' && c.completeData)
        .length;
    expect(
      _text(tester, 'next-meal-result-count'),
      '$complete of $complete foods shown',
    );
    await _tap(tester, find.byKey(const ValueKey('next-meal-filters-clear')));
    expect(
      _text(tester, 'next-meal-result-count'),
      '24 of ${state.nextMealCandidates.length} foods shown',
    );
    await tester.enterText(
      find.byKey(const ValueKey('next-meal-search')),
      'zzzz-no-food',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('next-meal-no-results')), findsOneWidget);
  });

  testWidgets(
    'saving the plate opens meal entry prefilled; nothing is logged',
    (tester) async {
      await _size(tester, 1280);
      final state = (await tester.runAsync(_fixture))!;
      addTearDown(state.dispose);
      final mealsBefore = state.meals.length;
      await tester.pumpWidget(_host(state));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('next-meal-add-food_tofu')));
      await _tap(
        tester,
        find.byKey(const ValueKey('next-meal-more-food_tofu')),
      );
      await _tap(
        tester,
        find.byKey(const ValueKey('next-meal-save-draft')),
        settle: false,
      );
      final entry = tester.widget<EntryPage>(find.byType(EntryPage));
      final draft = entry.reuseMeal!;
      expect(draft.items.single.foodId, 'food_tofu');
      final serving = state.nextMealCandidates
          .firstWhere((c) => c.id == 'food_tofu')
          .serving
          .evaluatedGrams;
      expect(draft.items.single.grams, closeTo(serving * 1.5, 1e-6));
      expect(draft.effectiveOccurredAt, _now);
      expect(state.meals.length, mealsBefore);
    },
  );

  for (final dark in [false, true]) {
    testWidgets('375 px layout builds without overflow (dark: $dark)', (
      tester,
    ) async {
      await _size(tester, 375, height: 9000);
      final state = (await tester.runAsync(_fixture))!;
      addTearDown(state.dispose);
      await tester.pumpWidget(
        _host(state, theme: dark ? ThemeData.dark() : null),
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('next-meal-add-food_tofu')));
      await _tap(tester, find.byKey(const ValueKey('next-meal-pin-food_tofu')));
      await _tap(tester, find.byKey(const ValueKey('next-meal-filters')));
      expect(tester.takeException(), isNull);
      await _reveal(
        tester,
        find.byKey(const ValueKey('next-meal-plate-chart')),
      );
      expect(
        find.byKey(const ValueKey('next-meal-plate-chart')),
        findsOneWidget,
      );
      // Every control is at least 44 px in both directions.
      for (final key in [
        'next-meal-time-minus',
        'next-meal-time-plus',
        'next-meal-time-type',
        'next-meal-anchor-last',
        'next-meal-more-food_tofu',
        'next-meal-save-draft',
        'next-meal-sort-reverse',
      ]) {
        await _reveal(tester, find.byKey(ValueKey(key)));
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
      }
    });
  }
}

double _totalProtein(WidgetTester tester) {
  final totals = find.byKey(const ValueKey('next-meal-plate-totals'));
  final texts = tester
      .widgetList<Text>(
        find.descendant(of: totals, matching: find.byType(Text)),
      )
      .map((t) => t.data ?? '')
      .toList();
  final index = texts.indexOf('Protein');
  return double.parse(
    RegExp(r'[\d.]+').firstMatch(texts[index + 1])!.group(0)!,
  );
}
