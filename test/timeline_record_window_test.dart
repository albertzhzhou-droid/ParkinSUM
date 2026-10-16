import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/interaction_result.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/core/theme/paper_theme.dart';
import 'package:parkinsum_companion/domain/entities/personal_log_view.dart';
import 'package:parkinsum_companion/domain/entities/timeline_event.dart';
import 'package:parkinsum_companion/engineering/personal_log_view_benchmark_fixture.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';

class _WindowState extends AppState {
  _WindowState(this.fixture) : super(services: Services.createEphemeral());
  final PersonalLogBenchmarkFixture fixture;
  int mealBuilders = 0;
  @override
  List<Meal> get meals => fixture.meals;
  @override
  List<Intake> get intakes => fixture.intakes;
  @override
  List<TimelineEvent> get timeline => services.getTimelineUseCase(
    meals: meals,
    intakes: intakes,
    medications: medRepo.allDrugs,
  );
  @override
  InteractionResult? cachedMealCheck(Meal meal) {
    mealBuilders++;
    return super.cachedMealCheck(meal);
  }
}

Future<_WindowState> _ready(String locale, int count) async {
  final state = _WindowState(PersonalLogBenchmarkFixture.generate(count));
  await state.services.ready;
  await state.bootstrap();
  await state.saveUserProfile(
    state.userProfile.copyWith(timezone: 'Etc/UTC', displayLocale: locale),
  );
  state.foodRepo.replaceAll(state.fixture.foods);
  state.medRepo.replaceAll(state.fixture.drugs);
  return state;
}

Widget _host(_WindowState state, TimelinePage page, {double scale = 1}) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: Paper.themeData(),
        locale: const Locale('en', 'US'),
        supportedLocales: const [Locale('en', 'US')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: page,
      ),
    );

String _text(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Finder _record(TimelineEvent event) => find.byKey(
  ValueKey('timeline-record-${TypedLogRecordRef.fromEvent(event).viewKey}'),
);

void main() {
  testWidgets(
    'cold tail seek stays bounded; page changes retain full source data',
    (tester) async {
      final state = (await tester.runAsync(
        () => _ready('en', 1000).timeout(const Duration(seconds: 30)),
      ))!;
      addTearDown(state.dispose);
      await tester.binding.setSurfaceSize(const Size(1280, 720));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final originalSha = state.fixture.inputSha256;
      final allEvents = state.timeline;
      await tester.pumpWidget(_host(state, const TimelinePage()));
      await tester.pumpAndSettle();
      expect(find.textContaining('check not yet completed'), findsWidgets);
      expect(find.textContaining('score 0'), findsNothing);
      expect(
        _text(tester, 'timeline-view-count'),
        '1200 of 1200 records match; 200 currently shown.',
      );
      expect(
        _text(tester, 'timeline-record-page'),
        'Page 1 of 6 · records 1–200',
      );
      expect(_record(allEvents.first), findsOneWidget);

      final listElements = find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .evaluate()
          .where(
            (element) =>
                element.findAncestorWidgetOfExactType<ListView>() != null,
          );
      expect(listElements.length, 1);
      final list =
          (listElements.single as StatefulElement).state as ScrollableState;
      final before = state.mealBuilders;
      list.position.jumpTo(list.position.maxScrollExtent);
      await tester.pumpAndSettle();
      // The old cold seek built all 997 remaining meals in a 1000-meal input.
      // Allow corrective relayouts, while rejecting work proportional to all rows.
      expect(
        state.mealBuilders - before,
        lessThan(TimelinePage.recordWindowSize * 3),
      );
      final attached = find
          .byWidgetPredicate(
            (widget) =>
                widget.key is ValueKey<String> &&
                (widget.key as ValueKey<String>).value.startsWith(
                  'timeline-record-',
                ),
          )
          .evaluate()
          .length;
      expect(attached, greaterThan(0));
      expect(attached, lessThan(50));

      await tester.ensureVisible(
        find.byKey(const ValueKey('timeline-next-records')),
      );
      await tester.tap(find.byKey(const ValueKey('timeline-next-records')));
      await tester.pumpAndSettle();
      expect(
        _text(tester, 'timeline-record-page'),
        'Page 2 of 6 · records 201–400',
      );
      expect(_record(allEvents[200]), findsOneWidget);
      expect(_record(allEvents.first), findsNothing);
      expect(state.fixture.inputSha256, originalSha);
      expect(state.timeline.length, 1200);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['en', 'zh']) {
    testWidgets(
      '$locale narrow 200% pages and search reach off-page originals',
      (tester) async {
        final state = (await tester.runAsync(
          () => _ready(locale, 1000).timeout(const Duration(seconds: 30)),
        ))!;
        addTearDown(state.dispose);
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_host(state, const TimelinePage(), scale: 2));
        await tester.pumpAndSettle();
        expect(
          find.textContaining(
            locale == 'zh' ? '尚未完成检查' : 'check not yet completed',
          ),
          findsWidgets,
        );
        final next = find.byKey(const ValueKey('timeline-next-records'));
        await tester.ensureVisible(next);
        FocusManager.instance.primaryFocus?.unfocus();
        // Keyboard reaches and activates the same real page control as touch.
        bool nextFocused() =>
            FocusManager.instance.primaryFocus?.context
                ?.findAncestorWidgetOfExactType<IconButton>()
                ?.key ==
            const ValueKey('timeline-next-records');
        for (var index = 0; index < 50 && !nextFocused(); index++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(nextFocused(), isTrue);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(
          _text(tester, 'timeline-record-page'),
          contains(locale == 'zh' ? '第 2 / 6 页' : 'Page 2 of 6'),
        );
        final filters = find.byKey(const ValueKey('timeline-view-filters'));
        await tester.ensureVisible(filters);
        await tester.pumpAndSettle();
        await tester.tap(filters);
        await tester.pumpAndSettle();
        final search = find.byKey(const ValueKey('timeline-filter-name'));
        await tester.ensureVisible(search);
        await tester.enterText(search, 'Synthetic benchmark meal 999');
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            const ValueKey('timeline-record-meal:synthetic-perf-row-999'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('timeline-record-page')),
          findsNothing,
        );
        expect(
          _text(tester, 'timeline-view-count'),
          contains(locale == 'zh' ? '匹配 1 / 共 1200' : '1 of 1200'),
        );
        expect(state.meals.length, 1000);
        expect(state.intakes.length, 200);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'typed focus reaches a 10k tail original without walking preceding pages',
    (tester) async {
      final state = (await tester.runAsync(
        () => _ready('en', 10000).timeout(const Duration(seconds: 30)),
      ))!;
      addTearDown(state.dispose);
      final originalSha = state.fixture.inputSha256;
      await tester.pumpWidget(
        _host(
          state,
          const TimelinePage(
            focus: TypedLogRecordRef(
              TimelineEventType.meal,
              'synthetic-perf-row-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('timeline-record-meal:synthetic-perf-row-1')),
        findsOneWidget,
      );
      expect(
        _text(tester, 'timeline-view-count'),
        '12000 of 12000 records match; 1 currently shown.',
      );
      expect(state.mealBuilders, lessThan(10));
      expect(state.fixture.inputSha256, originalSha);
      expect(tester.takeException(), isNull);
    },
  );
}
