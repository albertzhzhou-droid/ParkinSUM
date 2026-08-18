import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/recoverable_user_event.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/meals/meal_page.dart';
import 'package:parkinsum_companion/features/settings/recoverable_event_history_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('meal delete offers immediate durable Undo', (tester) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = AppState(services: services);
    addTearDown(state.dispose);
    await state.bootstrap();
    final meal = Meal(
      id: 'meal_immediate_undo',
      eatenAt: DateTime.utc(2026, 8, 18, 8),
      title: 'Undo breakfast',
      items: const <MealItem>[],
    );
    await state.addMeal(meal);
    tester.view.physicalSize = const Size(900, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: MealPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.meals, isEmpty);
    expect(find.text('Record deleted.'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(state.meals.single.title, 'Undo breakfast');
    expect(
      state.recoverableEventHistory.first.mutationType,
      RecoverableUserEventMutationType.restore,
    );
  });

  testWidgets('history center restores deletion and disables stale revisions', (
    tester,
  ) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = AppState(services: services);
    addTearDown(state.dispose);
    await state.bootstrap();
    final meal = Meal(
      id: 'meal_history_ui',
      eatenAt: DateTime.utc(2026, 8, 18, 8),
      title: 'Breakfast',
      items: const <MealItem>[],
    );
    await state.addMeal(meal);
    await state.updateMeal(meal.copyWith(title: 'Edited breakfast'));
    await state.deleteMeal(meal.id);
    final deletion = state.latestRecoverableRevisionFor(
      eventType: RecoverableUserEventType.meal,
      recordId: meal.id,
    )!;

    tester.view.physicalSize = const Size(900, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: RecoverableEventHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recoverable record history'), findsOneWidget);
    expect(find.text('Edited breakfast'), findsWidgets);
    final restore = find.byKey(
      ValueKey<String>('history-restore-${deletion.historyId}'),
    );
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('history-impact-dialog')), findsOneWidget);
    expect(find.text('Restore impact preview'), findsOneWidget);
    expect(find.text('Derived results will be regenerated'), findsOneWidget);
    final semantics = tester.ensureSemantics();
    expect(
      find.bySemanticsLabel(
        'Read-only restore impact preview and confirmation',
      ),
      findsOneWidget,
    );
    semantics.dispose();
    expect(state.meals, isEmpty);
    await tester.tap(find.byKey(const ValueKey('history-impact-confirm')));
    await tester.pumpAndSettle();

    expect(state.meals.single.title, 'Edited breakfast');
    expect(
      state.recoverableEventHistory.first.mutationType,
      RecoverableUserEventMutationType.restore,
    );
    expect(
      find.text('The prior state was restored as a new revision.'),
      findsOneWidget,
    );
    final oldButton = tester.widget<FilledButton>(restore);
    expect(oldButton.onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('concurrent edit invalidates an open restore preview', (
    tester,
  ) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = AppState(services: services);
    addTearDown(state.dispose);
    await state.bootstrap();
    final meal = Meal(
      id: 'meal_stale_preview',
      eatenAt: DateTime.utc(2026, 8, 18, 8),
      title: 'Before deletion',
      items: const <MealItem>[],
    );
    await state.addMeal(meal);
    await state.deleteMeal(meal.id);
    final deletion = state.latestRecoverableRevisionFor(
      eventType: RecoverableUserEventType.meal,
      recordId: meal.id,
    )!;
    tester.view.physicalSize = const Size(900, 1700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: RecoverableEventHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();

    final restore = find.byKey(
      ValueKey<String>('history-restore-${deletion.historyId}'),
    );
    await tester.ensureVisible(restore);
    await tester.tap(restore);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('history-impact-dialog')), findsOneWidget);

    await state.addMeal(meal.copyWith(title: 'Concurrent newer record'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('history-impact-confirm')));
    await tester.pumpAndSettle();

    expect(state.meals.single.title, 'Concurrent newer record');
    expect(
      find.text(
        'The current record changed. Nothing was restored, protecting the newer data.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('filter exposes only the selected event family', (tester) async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = AppState(services: services);
    addTearDown(state.dispose);
    await state.bootstrap();
    await state.addMeal(
      Meal(
        id: 'meal_filter',
        eatenAt: DateTime.utc(2026, 8, 18, 8),
        title: 'Meal only',
        items: const <MealItem>[],
      ),
    );
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: RecoverableEventHistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('history-filter-intake')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'No recoverable revisions yet. Future creates, edits, and deletes will appear here.',
      ),
      findsOneWidget,
    );
  });
}
