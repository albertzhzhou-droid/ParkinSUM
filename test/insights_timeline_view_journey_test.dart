import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/personal_log_view.dart';
import 'package:parkinsum_companion/domain/entities/timeline_event.dart';
import 'package:parkinsum_companion/features/analytics/analytics_page.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final asOf = DateTime.utc(2026, 9, 30, 12);

FoodItem fixtureFood(
  String id,
  double protein, {
  Set<String> missing = const {},
}) => FoodItem(
  id: id,
  name: id,
  category: FoodCategory.other,
  sourceSystem: 'SYNTHETIC',
  proteinG: protein,
  carbsG: 0,
  fatG: 0,
  fiberG: 0,
  sodiumMg: 0,
  missingNutrientFields: missing,
);

Meal fixtureMeal(FoodItem food, String id, int hour) => Meal(
  id: id,
  title: id,
  eatenAt: DateTime.utc(2026, 9, 30, hour),
  items: [MealItem.fromFood(food: food, quantityFactor: 1)],
);

Future<AppState> ready(String locale) async {
  final state = AppState(services: Services.createEphemeral());
  await state.services.ready;
  await state.bootstrap();
  await state.saveUserProfile(
    state.userProfile.copyWith(timezone: 'Etc/UTC', displayLocale: locale),
  );
  final known = fixtureFood('known-food', 20);
  final zero = fixtureFood('zero-food', 0);
  final unknown = fixtureFood('unknown-food', 999, missing: {'proteinG'});
  state.foodRepo.replaceAll([known, zero, unknown]);
  for (final row in [
    fixtureMeal(known, 'known-meal', 10),
    fixtureMeal(zero, 'zero-meal', 11),
    fixtureMeal(unknown, 'unknown-meal', 9),
    fixtureMeal(known, 'future-meal', 15),
  ]) {
    await state.addMeal(row);
  }
  return state;
}

Widget host(AppState state, Widget child, {double scale = 1}) =>
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: child,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in ['en', 'zh']) {
    testWidgets(
      '$locale descriptive projection opens the exact record and refreshes after mutations',
      (tester) async {
        final state = await ready(locale);
        addTearDown(state.dispose);
        await tester.binding.setSurfaceSize(const Size(900, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(host(state, AnalyticsPage(clock: () => asOf)));
        await tester.pumpAndSettle();
        expect(find.text('10.0 g'), findsOneWidget);
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('insights-future-count')))
              .data,
          contains(locale == 'zh' ? '1 条未来' : '1 future-dated'),
        );
        final point = find.byKey(
          const ValueKey('insights-point-meal:known-meal'),
        );
        await tester.ensureVisible(point);
        await tester.tap(point);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('timeline-record-meal:known-meal')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('timeline-record-meal:zero-meal')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('timeline-focus-status')),
          findsOneWidget,
        );
        final original = state.meals.singleWhere((m) => m.id == 'known-meal');
        await state.updateMeal(
          original.copyWith(
            items: [original.items.single.copyWith(quantityFactor: 2)],
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining(locale == 'zh' ? '蛋白 40.0' : 'protein 40.0'),
          findsOneWidget,
        );
        await state.deleteMeal('known-meal');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('timeline-record-meal:known-meal')),
          findsNothing,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('timeline-focus-status')))
              .data,
          contains(locale == 'zh' ? '已删除或不可用' : 'deleted or is unavailable'),
        );
        final revision = state.latestRecoverableRevisionFor(
          eventType: RecoverableUserEventType.meal,
          recordId: 'known-meal',
        )!;
        expect(await state.restoreRecoverableEvent(revision.historyId), isTrue);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('timeline-record-meal:known-meal')),
          findsOneWidget,
        );
        Navigator.of(tester.element(find.byType(TimelinePage))).pop();
        await tester.pumpAndSettle();
        // The KPI row sits above the charts; the longer page can leave it
        // outside the lazily built range after scrolling to the point.
        await tester.scrollUntilVisible(
          find.text('20.0 g'),
          -300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('20.0 g'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'custom dates and future records use separate original-record lists',
    (tester) async {
      final state = await ready('en');
      addTearDown(state.dispose);
      await tester.binding.setSurfaceSize(const Size(900, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(host(state, AnalyticsPage(clock: () => asOf)));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('insights-future-records')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('insights-record-meal:future-meal')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('insights-record-meal:known-meal')),
        findsNothing,
      );
      await tester.tap(
        find.byKey(const ValueKey('insights-record-meal:future-meal')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('timeline-record-meal:future-meal')),
        findsOneWidget,
      );
      await state.updateMeal(
        state.meals
            .singleWhere((m) => m.id == 'future-meal')
            .copyWith(title: 'Edited future record'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edited future record'), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(TimelinePage))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('insights-custom-dates')),
      );
      await tester.tap(find.byKey(const ValueKey('insights-custom-dates')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('log-date-start')),
        '2026-09-29',
      );
      await tester.enterText(
        find.byKey(const ValueKey('log-date-end')),
        '2026-09-29',
      );
      await tester.tap(find.byKey(const ValueKey('log-date-apply')));
      await tester.pumpAndSettle();
      expect(find.text('10.0 g'), findsNothing);
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('insights-future-count')))
            .data,
        startsWith('0 future-dated'),
      );
      await state.saveUserProfile(
        state.userProfile.copyWith(timezone: 'Unknown/Zone'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('insights-zone-hold')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('insights-protein-coverage')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['en', 'zh']) {
    testWidgets(
      '$locale 200% narrow filters and date dialog preserve keyboard access',
      (tester) async {
        final state = await ready(locale);
        addTearDown(state.dispose);
        await tester.binding.setSurfaceSize(const Size(360, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(host(state, const TimelinePage(), scale: 2));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('timeline-view-filters')));
        await tester.pumpAndSettle();
        final search = find.byKey(const ValueKey('timeline-filter-name'));
        await tester.ensureVisible(search);
        FocusManager.instance.primaryFocus?.unfocus();
        final editable = tester.widget<EditableText>(
          find.descendant(of: search, matching: find.byType(EditableText)),
        );
        for (var i = 0; i < 30 && !editable.focusNode.hasFocus; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(editable.focusNode.hasFocus, isTrue);
        await tester.enterText(search, 'zero-food');
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('timeline-record-meal:zero-meal')),
          findsOneWidget,
        );
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('timeline-view-count')))
              .data,
          contains(locale == 'zh' ? '匹配 1 / 共 4' : '1 of 4'),
        );
        final dates = find.byKey(const ValueKey('timeline-custom-dates'));
        await tester.ensureVisible(dates);
        await tester.tap(dates);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('log-date-start')),
          '2026-09-30',
        );
        await tester.enterText(
          find.byKey(const ValueKey('log-date-end')),
          '2026-09-29',
        );
        await tester.ensureVisible(
          find.byKey(const ValueKey('log-date-apply')),
        );
        await tester.tap(find.byKey(const ValueKey('log-date-apply')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('log-date-error')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final locale in ['en', 'zh']) {
    testWidgets(
      '$locale 200% narrow insights keeps a keyboard route to a real-zero record',
      (tester) async {
        final state = await ready(locale);
        addTearDown(state.dispose);
        await tester.binding.setSurfaceSize(const Size(360, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          host(state, AnalyticsPage(clock: () => asOf), scale: 2),
        );
        await tester.pumpAndSettle();
        final point = find.byKey(
          const ValueKey('insights-point-meal:zero-meal'),
        );
        await tester.scrollUntilVisible(
          point,
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        FocusManager.instance.primaryFocus?.unfocus();
        bool focused() =>
            FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<InkWell>()
                ?.key ==
            const ValueKey('insights-point-meal:zero-meal');
        for (var index = 0; index < 50 && !focused(); index++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(focused(), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('timeline-record-meal:zero-meal')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('same-owner new session cancels old typed focus', (tester) async {
    final state = await ready('en');
    addTearDown(state.dispose);
    await tester.pumpWidget(
      host(
        state,
        const TimelinePage(
          focus: TypedLogRecordRef(TimelineEventType.meal, 'known-meal'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('timeline-focus-status')), findsOneWidget);
    final owner = state.currentUserId;
    await state.signOut();
    await state.bootstrap();
    expect(state.currentUserId, owner);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('timeline-focus-status')), findsNothing);
    expect(
      find.byKey(const ValueKey('timeline-focus-expired')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '10k records locate a typed tail row without constructing the whole list',
    (tester) async {
      final state = _LongTimelineState();
      addTearDown(state.dispose);
      await state.services.ready;
      await state.bootstrap();
      await state.saveUserProfile(
        state.userProfile.copyWith(timezone: 'Etc/UTC'),
      );
      await tester.pumpWidget(
        host(
          state,
          const TimelinePage(
            focus: TypedLogRecordRef(TimelineEventType.meal, 'tail-0'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('timeline-record-meal:tail-0')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('timeline-view-count')))
            .data,
        contains('10000 of 10000 records match; 1 currently shown'),
      );
      await tester.tap(find.byKey(const ValueKey('timeline-clear-focus')));
      await tester.pumpAndSettle();
      expect(find.byType(ListTile).evaluate().length, lessThan(50));
      expect(
        find.byKey(const ValueKey('timeline-record-meal:tail-0')),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _LongTimelineState extends AppState {
  _LongTimelineState() : super(services: Services.createEphemeral());
  final rows = List<Meal>.generate(
    10000,
    (index) => Meal(
      id: 'tail-$index',
      title: 'Synthetic tail $index',
      eatenAt: DateTime.utc(2026, 1, 1).add(Duration(minutes: index)),
      items: [],
    ),
  );
  @override
  List<Meal> get meals => rows;
  @override
  List<Intake> get intakes => const [];
  @override
  List<TimelineEvent> get timeline =>
      services.getTimelineUseCase(meals: rows, intakes: [], medications: []);
}
