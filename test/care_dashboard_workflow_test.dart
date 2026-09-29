import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/core/services/care_workspace_store.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/features/entry/entry_page.dart';
import 'package:parkinsum_companion/features/main_shell/dashboard_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _pumpDashboard(
  WidgetTester tester, {
  bool chinese = false,
}) async {
  final state = await tester.runAsync(() async {
    final services = Services.createEphemeral(
      careWorkspaceStore: MemoryCareWorkspaceStore(),
    );
    await services.ready;
    await services.userDataService.saveUserProfile(
      UserProfile.defaults().copyWith(
        displayLocale: chinese ? 'zh-CN' : 'en-US',
      ),
    );
    await services.userDataService.saveActiveDrugIds([
      'drug_levodopa_carbidopa',
    ]);
    final value = AppState(services: services);
    await value.bootstrap();
    return value;
  });
  addTearDown(state!.dispose);
  await tester.binding.setSurfaceSize(const Size(900, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: DashboardPage()),
    ),
  );
  await tester.pumpAndSettle();
  return state;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    final scrollable = find
        .byWidgetPredicate(
          (widget) =>
              widget is Scrollable &&
              widget.axisDirection == AxisDirection.down,
        )
        .first;
    await tester.drag(scrollable, const Offset(0, 10000));
    await tester.pumpAndSettle();
    for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
      await tester.drag(scrollable, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
  }
  expect(target, findsWidgets);
  await tester.ensureVisible(target.first);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.runAsync(() async {
    await tester.tap(target.first);
    // Real ephemeral services enqueue transactions outside the widget clock.
    await Future<void>.delayed(Duration.zero);
  });
  await tester.pumpAndSettle();
}

Future<void> _waitForVisible(WidgetTester tester, Finder target) async {
  // Asset/engine work runs outside the fake frame clock. Wait for the actual
  // completion UI, with a bounded real-time budget rather than a fixed sleep.
  for (var i = 0; i < 250 && target.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
  expect(target, findsOneWidget);
}

PersonalObservation _bloodPressure(AppState state) {
  final now = DateTime.now().toUtc();
  return PersonalObservation.create(
    id: 'dashboard-blood-pressure',
    kind: PersonalObservationKind.bloodPressure,
    occurredAt: now.subtract(const Duration(minutes: 30)),
    recordedAt: now,
    originalTimezone: 'UTC',
    source: PersonalObservationSource.deviceManual,
    recorderId: state.currentUserId!,
    status: PersonalObservationStatus.recorded,
    systolic: 120,
    diastolic: 80,
    unit: PersonalObservation.bloodPressureUnit,
    posture: BloodPressurePosture.standing,
  );
}

/// The dashboard shows the logged-meal count as a stat tile (serif figure
/// over a caption) rather than a "Logged meals: N" sentence.
Finder _mealsStat(String count) => find.descendant(
  of: find.byKey(const ValueKey('dashboard-stat-meals')),
  matching: find.text(count),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'EntryPage saves a new meal and dashboard reflects persisted prompts and observation',
    (tester) async {
      final state = await _pumpDashboard(tester);
      expect(_mealsStat('0'), findsOneWidget);
      expect(state.followups(includeHistory: true), isEmpty);

      await _tap(tester, find.text('Add meal'));
      expect(find.byType(EntryPage), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('entry-title-field')),
        'Dashboard workflow meal',
      );
      await tester.enterText(
        find.byKey(const ValueKey('entry-food-search')),
        state.foodRepo.allFoods.first.id,
      );
      expect(
        state.catalogEngine.searchFoods(state.foodRepo.allFoods.first.id),
        isNotEmpty,
      );
      await tester.pumpAndSettle();
      await _tap(tester, find.byTooltip('Add food'));
      expect(
        state.meals,
        isEmpty,
        reason: 'Adding a draft food is not a save.',
      );
      expect(state.followups(includeHistory: true), isEmpty);

      await _tap(tester, find.text('Save meal and run conflict check'));
      await _waitForVisible(tester, find.text('Meal saved and checked'));
      final meal = state.meals.single;
      expect(meal.title, 'Dashboard workflow meal');
      expect(meal.items, hasLength(1));
      final cached = state.cachedMealCheck(meal);
      expect(cached.followupPrompts, isNotEmpty);
      expect(
        state.followups().map((item) => item.prompt.id).toSet(),
        cached.followupPrompts.map((prompt) => prompt.id).toSet(),
      );
      final savedMeals = await tester.runAsync(
        state.services.userDataService.loadMeals,
      );
      expect(savedMeals!.single.toJson(), meal.toJson());
      final savedWorkspace = await tester.runAsync(
        () => state.services.careWorkspaceService.load(state.currentUserId!),
      );
      expect(savedWorkspace!.followups.prompts, isNotEmpty);
      expect(
        savedWorkspace.followups.prompts.every(
          (prompt) => prompt.sourceRecordId == meal.id,
        ),
        isTrue,
      );

      await _tap(tester, find.text('Done'));
      expect(find.byType(EntryPage), findsNothing);
      expect(find.byType(DashboardPage), findsOneWidget);
      await _reveal(tester, _mealsStat('1'));
      expect(_mealsStat('1'), findsOneWidget);
      await _reveal(tester, find.text('Dashboard workflow meal'));
      expect(find.text('Dashboard workflow meal'), findsWidgets);

      // ObservationEditor has its own widget suite. This crossing verifies the
      // real persistence-to-Provider-to-dashboard path without replacing state.
      final observation = _bloodPressure(state);
      expect(
        await tester.runAsync(() => state.saveObservation(observation)),
        isTrue,
      );
      await tester.pumpAndSettle();
      final summary = find.textContaining(
        'Blood pressure · 120 / 80 mmHg · Standing',
      );
      await _reveal(tester, summary);
      expect(summary, findsOneWidget);
      expect(find.text('Personal observation'), findsOneWidget);
      final reloaded = await tester.runAsync(
        () => state.services.careWorkspaceService.load(state.currentUserId!),
      );
      expect(reloaded!.observations.single.toJson(), observation.toJson());
      expect(tester.takeException(), isNull);
    },
    timeout: const Timeout(Duration(seconds: 45)),
  );

  testWidgets('Chinese dashboard renders saved observation and posture', (
    tester,
  ) async {
    final state = await _pumpDashboard(tester, chinese: true);
    expect(
      await tester.runAsync(() => state.saveObservation(_bloodPressure(state))),
      isTrue,
    );
    await tester.pumpAndSettle();
    final summary = find.textContaining('血压 · 120 / 80 mmHg · 立位');
    await _reveal(tester, summary);
    expect(summary, findsOneWidget);
    expect(find.text('个人观察'), findsOneWidget);
    expect(find.textContaining('Blood pressure'), findsNothing);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 45)));
}
