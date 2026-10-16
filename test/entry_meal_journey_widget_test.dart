import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/synthetic_meal_journey.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/entry/entry_page.dart';
import 'package:parkinsum_companion/features/entry/synthetic_meal_journey_page.dart';
import 'package:parkinsum_companion/features/meals/meal_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> readyState(String locale) async {
  final state = AppState(services: Services.createEphemeral());
  await state.services.ready;
  await state.bootstrap();
  await state.saveUserProfile(
    state.userProfile.copyWith(displayLocale: locale),
  );
  final foods = syntheticMealJourneyFoods();
  state.services.foodRepository.replaceAll(foods);
  await state.addMeal(syntheticMealJourneyHistory(foods.first));
  return state;
}

Widget host(AppState state, {double textScale = 1, Widget? home}) =>
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: home ?? const MealPage(),
      ),
    );

Finder entryScrollable() => find
    .descendant(
      of: find.byKey(const Key('entry-form-list')),
      matching: find.byType(Scrollable),
    )
    .first;
Finder previewScrollable() => find
    .descendant(
      of: find.byKey(const Key('entry-portion-preview-scroll')),
      matching: find.byType(Scrollable),
    )
    .first;

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'reuse confirms a fresh input, source portion preview and one save',
    (tester) async {
      final state = await readyState('en');
      addTearDown(state.dispose);
      await tester.pumpWidget(host(state));
      await tester.tap(
        find.byKey(const ValueKey('reuse-meal-synthetic-history-meal')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('entry-save-meal')));
      await tester.pumpAndSettle();
      expect(state.meals, hasLength(1));
      expect(
        find.text('Confirm this meal time and each quantity before saving.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('entry-confirm-time')));
      await tester.tap(find.byKey(const Key('entry-confirm-quantities')));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('entry-portion-preview-0')),
        400,
        scrollable: entryScrollable(),
      );
      await tester.drag(entryScrollable(), const Offset(0, -250));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('entry-portion-preview-0')));
      await tester.pumpAndSettle();
      expect(find.text('Protein: 16.00 g'), findsOneWidget);
      expect(find.textContaining('Fiber: Unknown'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.byKey(const Key('entry-apply-source-portion')),
        200,
        scrollable: previewScrollable(),
      );
      state.services.foodRepository.replaceAll(syntheticMealJourneyFoods());
      await tester.tap(find.byKey(const Key('entry-apply-source-portion')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('entry-portion-preview-stale')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('entry-apply-source-portion')), findsNothing);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(
        (await state.loadMealDraft(
          owner: state.currentUserId!,
        ))!.meal.items.single.grams,
        100,
      );
      await tester.tap(find.byKey(const ValueKey('entry-portion-preview-0')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('entry-apply-source-portion')),
        200,
        scrollable: previewScrollable(),
      );
      await tester.tap(find.byKey(const Key('entry-apply-source-portion')));
      await tester.pumpAndSettle();
      // Changing quantity invalidates the previous quantity confirmation.
      await tester.scrollUntilVisible(
        find.byKey(const Key('entry-confirm-quantities')),
        -400,
        scrollable: entryScrollable(),
      );
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('entry-confirm-quantities')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const Key('entry-confirm-quantities')));
      await tester.tap(find.byKey(const Key('entry-save-meal')));
      await tester.pumpAndSettle();
      expect(state.meals, hasLength(2));
      expect(state.meals.first.items.single.grams, 160);
      expect(
        find.byKey(const Key('interaction-evidence-and-missing')),
        findsOneWidget,
      );
      expect(await state.loadMealDraft(owner: state.currentUserId!), isNull);
      expect(tester.takeException(), isNull);
    },
  );

  for (final locale in ['zh', 'en']) {
    testWidgets(
      '$locale narrow large-text draft restores after interruption and hides on sign-out',
      (tester) async {
        tester.view.physicalSize = const Size(360, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final state = await readyState(locale);
        addTearDown(state.dispose);
        await tester.pumpWidget(host(state, textScale: 2));
        await tester.tap(
          find.byKey(const ValueKey('reuse-meal-synthetic-history-meal')),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('entry-title-field')),
          250,
          scrollable: entryScrollable(),
        );
        final titleEditable = tester.widget<EditableText>(
          find.descendant(
            of: find.byKey(const ValueKey('entry-title-field')),
            matching: find.byType(EditableText),
          ),
        );
        FocusManager.instance.primaryFocus?.unfocus();
        for (
          var tab = 0;
          tab < 16 && !titleEditable.focusNode.hasFocus;
          tab++
        ) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
        }
        expect(titleEditable.focusNode.hasFocus, isTrue);
        await tester.enterText(
          find.byKey(const ValueKey('entry-title-field')),
          'Interrupted private draft',
        );
        // Pop before the debounce fires; dispose must preserve the latest input.
        Navigator.of(tester.element(find.byType(EntryPage))).pop();
        await tester.pumpAndSettle();
        expect(
          (await state.loadMealDraft(owner: state.currentUserId!))!.meal.title,
          'Interrupted private draft',
        );
        await tester.tap(find.byIcon(Icons.add).first);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('entry-title-field')),
          250,
          scrollable: entryScrollable(),
        );
        expect(
          tester
              .widget<TextField>(
                find.byKey(const ValueKey('entry-title-field')),
              )
              .controller!
              .text,
          'Interrupted private draft',
        );
        await state.signOut();
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('entry-title-field')), findsNothing);
        await state.bootstrap();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('entry-title-field')),
          findsNothing,
          reason:
              'Signing back into the same owner cannot revive a stale editor.',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('synthetic reset clears only its isolated state', (tester) async {
    final personal = await readyState('en');
    addTearDown(personal.dispose);
    await tester.pumpWidget(
      host(personal, home: const SyntheticMealJourneyPage()),
    );
    await tester.pumpAndSettle();
    final sandbox = Provider.of<AppState>(
      tester.element(find.byType(MealPage)),
      listen: false,
    );
    expect(identical(sandbox, personal), isFalse);
    final newMeal = sandbox.meals.single.copyWith(id: 'sandbox-extra');
    await sandbox.addMeal(newMeal);
    await tester.pumpAndSettle();
    expect(sandbox.meals, hasLength(2));
    await tester.tap(find.byKey(const Key('synthetic-meal-reset')));
    await tester.pumpAndSettle();
    final reset = Provider.of<AppState>(
      tester.element(find.byType(MealPage)),
      listen: false,
    );
    expect(reset.meals, hasLength(1));
    expect(personal.meals, hasLength(1));
    expect(personal.meals.single.id, 'synthetic-history-meal');
    expect(tester.takeException(), isNull);
  });
  testWidgets('synthetic reset can supersede an in-flight meal mutation', (
    tester,
  ) async {
    final personal = await readyState('en');
    addTearDown(personal.dispose);
    await tester.pumpWidget(
      host(personal, home: const SyntheticMealJourneyPage()),
    );
    await tester.pumpAndSettle();
    final sandbox = Provider.of<AppState>(
      tester.element(find.byType(MealPage)),
      listen: false,
    );
    final pending = sandbox.addMeal(
      sandbox.meals.single.copyWith(id: 'superseded-sandbox-meal'),
    );
    await tester.tap(find.byKey(const Key('synthetic-meal-reset')));
    await pending;
    await tester.pumpAndSettle();
    final reset = Provider.of<AppState>(
      tester.element(find.byType(MealPage)),
      listen: false,
    );
    expect(reset.meals, hasLength(1));
    expect(personal.meals, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a second editor resumes saved input and the older route cannot overwrite it',
    (tester) async {
      final state = await readyState('en');
      addTearDown(state.dispose);
      await tester.pumpWidget(host(state));
      await tester.tap(
        find.byKey(const ValueKey('reuse-meal-synthetic-history-meal')),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('entry-title-field')),
        'previous unfinished input',
      );
      await tester.pump(const Duration(milliseconds: 300));
      Navigator.of(tester.element(find.byType(EntryPage))).push(
        MaterialPageRoute(
          builder: (_) => EntryPage(reuseMeal: state.meals.single),
        ),
      );
      // The chooser intentionally keeps the loading page behind its modal.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('An unfinished draft is saved'), findsOneWidget);
      await tester.tap(find.byKey(const Key('entry-resume-existing-draft')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('entry-title-field')))
            .controller!
            .text,
        'previous unfinished input',
      );
      await tester.enterText(
        find.byKey(const ValueKey('entry-title-field')),
        'latest editor input',
      );
      await tester.pump(const Duration(milliseconds: 300));
      Navigator.of(tester.element(find.byType(EntryPage))).pop();
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Meal entry continued in another page. Reopen to restore the latest draft.',
        ),
        findsOneWidget,
      );
      expect(
        (await state.loadMealDraft(owner: state.currentUserId!))!.meal.title,
        'latest editor input',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
