@Timeout(Duration(minutes: 5))
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n_diary_strip_translations.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/personal_diary_strip.dart';
import 'package:parkinsum_companion/domain/entities/personal_log_view.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/visit_report_selection.dart';
import 'package:parkinsum_companion/domain/usecases/localization_safety_lint.dart';
import 'package:parkinsum_companion/domain/usecases/personal_diary_strip_projector.dart';
import 'package:parkinsum_companion/domain/usecases/personal_log_handoff_summary_service.dart';
import 'package:parkinsum_companion/features/analytics/analytics_page.dart';
import 'package:parkinsum_companion/features/analytics/diary_strip_view.dart';
import 'package:parkinsum_companion/features/care_workspace/care_workspace_page.dart';
import 'package:parkinsum_companion/features/care_workspace/visit_report_selection_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Synthetic records only. One day (2026-10-20, Etc/UTC) with a known-protein
/// breakfast, a lunch whose protein is missing, a low-protein snack, two
/// intakes with entered dose text and one without, five motor-state entries,
/// one motor entry saved as unknown, and a meal the evening before.
final _asOf = DateTime.utc(2026, 10, 20, 21);
const _drug = 'drug_levodopa_carbidopa';

FoodItem _food(String id, double protein, {Set<String> missing = const {}}) =>
    FoodItem(
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

Meal _meal(String id, FoodItem food, DateTime at) => Meal(
  id: id,
  title: id,
  eatenAt: at,
  items: [MealItem.fromFood(food: food, quantityFactor: 1)],
);

PersonalObservation _motor(
  String id,
  DateTime at,
  String owner, {
  SelfReportedMotorState? state,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.selfReportedMotorState,
  occurredAt: at,
  recordedAt: at,
  originalTimezone: 'UTC',
  source: PersonalObservationSource.selfReported,
  recorderId: owner,
  status: state == null
      ? PersonalObservationStatus.unknown
      : PersonalObservationStatus.recorded,
  motorState: state,
);

Future<AppState> _fixture({String locale = 'en-US'}) async {
  final services = Services.createEphemeral();
  await services.ready;
  await services.userDataService.saveOnboarded(true);
  final state = AppState(services: services);
  await state.bootstrap();
  await state.saveUserProfile(
    state.userProfile.copyWith(timezone: 'Etc/UTC', displayLocale: locale),
  );
  final high = _food('syn-high', 25);
  final low = _food('syn-low', 5);
  final unknown = _food('syn-unknown', 999, missing: {'proteinG'});
  state.foodRepo.replaceAll([high, low, unknown]);
  for (final meal in [
    _meal('late-supper', high, DateTime.utc(2026, 10, 19, 22, 30)),
    _meal('breakfast', high, DateTime.utc(2026, 10, 20, 8)),
    _meal('lunch', unknown, DateTime.utc(2026, 10, 20, 12, 30)),
    _meal('snack', low, DateTime.utc(2026, 10, 20, 16)),
    _meal('future-meal', high, DateTime.utc(2026, 10, 20, 22)),
  ]) {
    await state.addMeal(meal);
  }
  for (final (id, hour, note) in [
    ('dose-1', 7, '1 tablet'),
    ('dose-2', 13, '1 tablet'),
    ('dose-3', 18, ''),
  ]) {
    await state.addIntake(
      Intake(
        id: id,
        drugId: _drug,
        takenAt: DateTime.utc(2026, 10, 20, hour),
        dosageNote: note,
      ),
    );
  }
  final owner = state.currentUserId!;
  for (final observation in [
    _motor(
      'm-0030',
      DateTime.utc(2026, 10, 20, 0, 30),
      owner,
      state: SelfReportedMotorState.off,
    ),
    _motor(
      'm-0930',
      DateTime.utc(2026, 10, 20, 9, 30),
      owner,
      state: SelfReportedMotorState.off,
    ),
    _motor(
      'm-1000',
      DateTime.utc(2026, 10, 20, 10),
      owner,
      state: SelfReportedMotorState.on,
    ),
    _motor(
      'm-1400',
      DateTime.utc(2026, 10, 20, 14),
      owner,
      state: SelfReportedMotorState.off,
    ),
    _motor(
      'm-1700',
      DateTime.utc(2026, 10, 20, 17),
      owner,
      state: SelfReportedMotorState.uncertain,
    ),
    _motor(
      'm-2030',
      DateTime.utc(2026, 10, 20, 20, 30),
      owner,
      state: SelfReportedMotorState.off,
    ),
    _motor('m-unknown', DateTime.utc(2026, 10, 20, 11), owner),
  ]) {
    expect(await state.saveObservation(observation), isTrue);
  }
  return state;
}

DiaryStripProjection _project(AppState state, {int filter = 15}) =>
    const PersonalDiaryStripProjector().project(
      endDay: LogCivilDate(2026, 10, 20),
      dayCount: 7,
      zoneId: 'Etc/UTC',
      asOf: _asOf,
      meals: state.meals,
      intakes: state.intakes,
      observations: state.observations,
      foods: state.foodRepo.allFoods,
      medications: state.medRepo.allDrugs,
      proteinFilterG: filter,
    );

Widget _host(AppState state, Widget child, {ThemeData? theme}) =>
    ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(theme: theme, home: child),
    );

Future<void> _setWidth(WidgetTester tester, double width) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 4200);
  addTearDown(tester.view.reset);
}

String _semantics(WidgetTester tester, String key) =>
    tester.getSemantics(find.byKey(ValueKey(key))).label;

Future<void> _tap(WidgetTester tester, Finder target) async {
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      400,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('projection', () {
    test('lanes, unknown protein and descriptive counts', () async {
      final state = await _fixture();
      addTearDown(state.dispose);
      final diary = _project(state);
      expect(diary.days, hasLength(7));
      expect('${diary.start}', '2026-10-14');
      final day = diary.days.last;
      expect('${day.date}', '2026-10-20');
      expect(day.doses.map((d) => d.minuteOfDay), [420, 780, 1080]);
      expect(day.doses.first.doseText, '1 tablet');
      expect(day.doses.last.doseText, isNull);
      expect(day.meals.map((m) => m.recordId), ['breakfast', 'lunch', 'snack']);
      final lunch = day.meals[1];
      expect(lunch.proteinStatus, LoggedProteinStatus.unknown);
      expect(lunch.proteinG, isNull, reason: 'missing protein is never zero');
      expect(day.meals.first.proteinG, closeTo(25, 1e-9));
      expect(day.motor, hasLength(6));
      expect(day.motorWithoutState, 1);
      // The future meal is excluded and counted.
      expect(diary.futureRecordCount, 1);
      expect(diary.days[5].meals.single.recordId, 'late-supper');

      final off = diary.count(SelfReportedMotorState.off);
      expect(
        (off.total, off.afterFilteredMeal, off.unclassified),
        (4, 2, 1),
        reason:
            '00:30 follows the previous evening, 09:30 follows breakfast, '
            '14:00 follows only the unknown lunch, 20:30 follows nothing',
      );
      final on = diary.count(SelfReportedMotorState.on);
      expect((on.total, on.afterFilteredMeal, on.unclassified), (1, 1, 0));
      final uncertain = diary.count(SelfReportedMotorState.uncertain);
      expect(
        (uncertain.total, uncertain.afterFilteredMeal, uncertain.unclassified),
        (1, 0, 0),
      );

      final strict = _project(state, filter: 30);
      final strictOff = strict.count(SelfReportedMotorState.off);
      expect((strictOff.afterFilteredMeal, strictOff.unclassified), (0, 1));
      expect(
        () => _project(state, filter: 12),
        throwsArgumentError,
        reason: 'only the listed display filters exist',
      );
    });
  });

  group('copy', () {
    test('en and zh keys and placeholders match; others fall back', () {
      final en = kDiaryStripTranslations['en']!;
      final zh = kDiaryStripTranslations['zh']!;
      expect(zh.keys.toSet(), en.keys.toSet());
      final placeholder = RegExp(r'\{([a-z]+)\}');
      for (final key in en.keys) {
        Set<String> names(String text) =>
            placeholder.allMatches(text).map((m) => m[1]!).toSet();
        expect(names(zh[key]!), names(en[key]!), reason: key);
      }
      for (final tag in ['fr-FR', 'ja-JP', 'es-ES', 'ar-SA']) {
        final i18n = AppI18n.fromLocaleTag(tag);
        for (final key in en.keys) {
          expect(i18n.tr(key), isNot(key), reason: '$key for $tag');
        }
        expect(i18n.tr('diary.title'), en['diary.title']);
      }
    });

    test('no banned, causal or target wording', () {
      for (final entry in kDiaryStripTranslations.entries) {
        for (final MapEntry(key: key, value: text) in entry.value.entries) {
          expect(findBannedSubstrings(text), isEmpty, reason: text);
          for (final family in LocalizationSafetyLint.bannedFamilies.values) {
            for (final pattern in family) {
              expect(
                text.toLowerCase().contains(pattern.toLowerCase()),
                isFalse,
                reason: '$text contains $pattern',
              );
            }
          }
          // Only the boundary names causation, to deny it.
          if (key == 'diary.counts_boundary') continue;
          expect(
            RegExp(r'\bcause|trigger|导致|引起').hasMatch(text),
            isFalse,
            reason: text,
          );
        }
      }
      final boundary = kDiaryStripTranslations['en']!['diary.counts_boundary']!;
      expect(boundary, contains('own records'));
      expect(boundary, contains('not a clinical assessment'));
      expect(boundary, contains('not medical advice'));
      expect(
        kDiaryStripTranslations['en']!['diary.counts_filter_note'],
        contains('not a target'),
      );
    });
  });

  group('Insights strip', () {
    testWidgets('lanes read as text, unknown protein, counts and stepping', (
      tester,
    ) async {
      await _setWidth(tester, 375);
      final state = (await tester.runAsync(_fixture))!;
      addTearDown(state.dispose);
      await tester.pumpWidget(_host(state, AnalyticsPage(clock: () => _asOf)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow at 375 px');

      final meals = _semantics(tester, 'diary-lane-meals');
      expect(meals, contains('08:00 · breakfast · 25.0 g protein'));
      expect(meals, contains('12:30 · lunch · protein unknown'));
      expect(meals, isNot(contains('0.0 g')));
      final doses = _semantics(tester, 'diary-lane-medication');
      expect(doses, startsWith('Medication intakes: 07:00 · '));
      expect(doses, contains('1 tablet'));
      expect(doses, contains('18:00 · '));
      expect(doses, contains('dose not recorded'));
      final motor = _semantics(tester, 'diary-lane-motor');
      expect(
        motor,
        'Motor state (self-reported): 00:30 · OFF; 09:30 · OFF; '
        '10:00 · ON; 14:00 · OFF; 17:00 · Uncertain; 20:30 · OFF',
      );
      expect(find.text('protein unknown'), findsNothing);
      expect(find.text('12:30 · lunch · protein unknown'), findsOneWidget);

      expect(
        find.text(
          'OFF entries recorded within 3 h after a meal logged with at '
          'least 15 g protein: 2 of 4.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '1 more could not be counted either way because a meal in the 3 h '
          'before had unknown protein.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('diary-counts-boundary')), findsOne);

      for (final key in [
        'diary-prev-day',
        'diary-next-day',
        'diary-today',
        'diary-filter-30',
        'diary-week-row-2026-10-19',
      ]) {
        final size = tester.getSize(find.byKey(ValueKey(key)));
        expect(size.height, greaterThanOrEqualTo(44), reason: key);
        expect(size.width, greaterThanOrEqualTo(44), reason: key);
      }

      await _tap(tester, find.byKey(const ValueKey('diary-filter-30')));
      expect(
        find.text(
          'OFF entries recorded within 3 h after a meal logged with at '
          'least 30 g protein: 0 of 4.',
        ),
        findsOneWidget,
      );

      expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('diary-next-day')))
            .onPressed,
        isNull,
        reason: 'no stepping past today',
      );
      await _tap(tester, find.byKey(const ValueKey('diary-prev-day')));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('diary-showing-day')))
            .data,
        contains('October 19'),
      );
      expect(
        _semantics(tester, 'diary-lane-meals'),
        'Meals and logged protein: 22:30 · late-supper · 25.0 g protein',
      );
      expect(
        _semantics(tester, 'diary-lane-medication'),
        'Medication intakes: None recorded',
      );
      await _tap(tester, find.byKey(const ValueKey('diary-today')));
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('diary-showing-day')))
            .data,
        contains('October 20'),
      );

      // A week row is a button that shows its day; no drag is needed.
      final row = _semantics(tester, 'diary-week-row-2026-10-19');
      expect(row, contains('1 meals'));
      await _tap(
        tester,
        find.byKey(const ValueKey('diary-week-row-2026-10-19')),
      );
      expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('diary-showing-day')))
            .data,
        contains('October 19'),
      );
      for (var i = 0; i < 7; i++) {
        await _tap(tester, find.byKey(const ValueKey('diary-prev-day')));
      }
      expect(
        find.byKey(const ValueKey('diary-week-row-2026-10-12')),
        findsOneWidget,
        reason: 'stepping before the week moves the week',
      );
      expect(find.byKey(const ValueKey('diary-empty-day')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('zh copy and desktop width', (tester) async {
      await _setWidth(tester, 1280);
      final state = (await tester.runAsync(() => _fixture(locale: 'zh-CN')))!;
      addTearDown(state.dispose);
      await tester.pumpWidget(_host(state, AnalyticsPage(clock: () => _asOf)));
      await tester.pumpAndSettle();
      expect(find.text('日内记录条：用药、进餐与运动状态'), findsOneWidget);
      expect(
        _semantics(tester, 'diary-lane-meals'),
        contains('12:30 · lunch · 蛋白质未知'),
      );
      expect(
        find.textContaining('在记录蛋白质不少于 15 克的一餐之后 3 小时内记录的 OFF：4 条中有 2 条。'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% text at 375 px does not overflow', (tester) async {
      await _setWidth(tester, 375);
      final state = (await tester.runAsync(_fixture))!;
      addTearDown(state.dispose);
      final diary = _project(state);
      await tester.pumpWidget(
        _host(
          state,
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: DiaryStripPanel(
                    projection: diary,
                    shownDay: diary.end,
                    latest: diary.end,
                    onDayChanged: (_) {},
                    onFilterChanged: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders under a dark theme at 375 px', (tester) async {
      await _setWidth(tester, 375);
      final state = (await tester.runAsync(_fixture))!;
      addTearDown(state.dispose);
      final diary = _project(state);
      await tester.pumpWidget(
        _host(
          state,
          Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: DiaryStripPanel(
                projection: diary,
                shownDay: diary.end,
                latest: diary.end,
                onDayChanged: (_) {},
                onFilterChanged: (_) {},
              ),
            ),
          ),
          theme: ThemeData.dark(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final chip = tester.widget<Text>(
        find.text('12:30 · lunch · protein unknown'),
      );
      expect(
        chip.style!.color!.computeLuminance(),
        greaterThan(0.5),
        reason: 'light ink on the dark surface',
      );
    });
  });

  group('visit preparation', () {
    VisitReportSelection selection(
      AppState state, {
      bool diary = true,
      bool notes = false,
      int days = 7,
    }) => VisitReportSelection(
      window: PersonalLogDateWindow(
        start: LogCivilDate(2026, 10, 20).addDays(-days + 1),
        endInclusive: LogCivilDate(2026, 10, 20),
        zoneId: state.userProfile.timezone,
      ),
      intakeIds: const [],
      observationIds: const [],
      questionNoteIds: const [],
      medicationEntryIds: const [],
      followupPromptIds: const [],
      includeCurrentMedications: false,
      includeRecordNotes: notes,
      includeDiscussionUpdates: false,
      includeSourceAssertions: false,
      includeDiaryStrip: diary,
    );

    test('selected strip adds a descriptive section and counts', () async {
      final state = await _fixture();
      addTearDown(state.dispose);
      final chosen = selection(state);
      final report = state.prepareVisit(now: _asOf, selection: chosen);
      expect(report.diaryStrip, isNotNull);
      final text = report.plainText;
      expect(
        text,
        contains('Day strip: medication, meals and motor state (own records)'),
      );
      expect(text, contains("account holder's own entries"));
      expect(text, contains('not a clinical assessment'));
      expect(text, contains('do not show cause'));
      expect(text, contains('it is not a target'));
      expect(text, contains('- 2026-10-20'));
      expect(text, contains('12:30 protein unknown'));
      expect(text, contains('08:00 protein 25.0 g'));
      expect(text, isNot(contains('lunch')), reason: 'meal names not exported');
      expect(
        text,
        contains(
          'dose not shown: not recorded, or entered text omitted by this '
          'selection',
        ),
      );
      expect(text, isNot(contains('1 tablet')));
      expect(
        text,
        contains(
          'Motor state (self-reported): 00:30 OFF; 09:30 OFF; 10:00 ON; '
          '14:00 OFF; 17:00 Uncertain; 20:30 OFF; 1 more saved as unknown '
          'or not measured',
        ),
      );
      expect(text, contains('- 2026-10-18: no entries'));
      expect(
        text,
        contains(
          'OFF entries recorded within 3 h after a meal logged with at least '
          '15 g protein: 2 of 4. 1 more could not be counted either way',
        ),
      );
      expect(
        report.agendaText,
        contains('Day-strip counts (own records, 2026-10-14 — 2026-10-20)'),
      );
      expect(
        report.agendaText,
        contains('- ON entries recorded within 3 h after a meal'),
      );

      final artifact = const PersonalLogHandoffSummaryService()
          .createVisitPreparation(
            report: report,
            selection: chosen,
            sourceLease: state.captureVisitPreparationLease(),
            localeTag: 'en-US',
          );
      // The export wraps long lines; check the unwrapped document blocks.
      final blocks = artifact.semanticDocument.toString();
      expect(
        blocks,
        contains(
          'Day strip: included; the 15 g protein filter is for counts only, '
          'not a target',
        ),
      );
      expect(artifact.plainText, contains('Day strip: included'));
      expect(blocks, contains('12:30 protein unknown'));
      expect(
        (artifact.semanticDocument['selection'] as Map)['includeDiaryStrip'],
        isTrue,
      );
    });

    test('entered dose text follows the notes choice; 14-day cap', () async {
      final state = await _fixture();
      addTearDown(state.dispose);
      final withNotes = state.prepareVisit(
        now: _asOf,
        selection: selection(state, notes: true, days: 30),
      );
      expect(withNotes.plainText, contains('1 tablet'));
      expect(withNotes.plainText, contains('dose not recorded'));
      expect(withNotes.diaryStrip!.days, hasLength(14));
      expect('${withNotes.diaryStrip!.start}', '2026-10-07');

      final omitted = state.prepareVisit(
        now: _asOf,
        selection: selection(state, diary: false),
      );
      expect(omitted.diaryStrip, isNull);
      expect(omitted.plainText, isNot(contains('Day strip')));
      expect(omitted.agendaText, isNot(contains('Day-strip')));
      expect(
        () => VisitReportSelection(
          window: PersonalLogDateWindow(
            start: LogCivilDate(2026, 10, 20),
            endInclusive: LogCivilDate(2026, 10, 20),
            zoneId: 'Etc/UTC',
          ),
          intakeIds: const [],
          observationIds: const [],
          questionNoteIds: const [],
          medicationEntryIds: const [],
          followupPromptIds: const [],
          includeCurrentMedications: false,
          includeRecordNotes: false,
          includeDiscussionUpdates: false,
          includeSourceAssertions: false,
          includeDiaryStrip: true,
          diaryProteinFilterG: 12,
        ),
        throwsFormatException,
      );
    });

    testWidgets('selection switch and preview strip', (tester) async {
      await _setWidth(tester, 375);
      final state = (await tester.runAsync(_fixture))!;
      addTearDown(state.dispose);
      await tester.pumpWidget(
        _host(state, VisitReportSelectionPage(now: () => _asOf)),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('visit-diary-filter-20')), findsNothing);
      await _tap(tester, find.byKey(const ValueKey('visit-include-diary')));
      await _tap(tester, find.byKey(const ValueKey('visit-diary-filter-20')));
      await _tap(tester, find.byKey(const ValueKey('visit-selected-preview')));
      final preview = tester.widget<VisitPreparationPreview>(
        find.byType(VisitPreparationPreview),
      );
      expect(preview.report.diaryStrip!.proteinFilterG, 20);
      expect(preview.report.diaryStrip!.days, hasLength(14));
      expect(find.byKey(const ValueKey('visit-preview-diary')), findsOneWidget);
      expect(
        _semantics(tester, 'diary-lane-meals'),
        'Meals and logged protein: 08:00 · 25.0 g protein; '
        '12:30 · protein unknown; 16:00 · 5.0 g protein',
        reason: 'no meal names in the visit preview',
      );
      expect(find.byKey(const ValueKey('diary-today')), findsNothing);
      expect(find.byKey(const ValueKey('diary-filter-20')), findsNothing);
      expect(
        preview.handoffArtifact!.semanticDocument.toString(),
        contains('Day strip: included; the 20 g protein filter'),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
