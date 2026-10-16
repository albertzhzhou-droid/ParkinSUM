import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/domain/entities/personal_log_view.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/entities/timeline_event.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppState> _ready(String locale) async {
  final state = AppState(services: Services.createEphemeral());
  await state.services.ready;
  await state.bootstrap();
  await state.saveUserProfile(
    state.userProfile.copyWith(
      timezone: 'America/Toronto',
      displayLocale: locale,
    ),
  );
  final chinese = locale == 'zh';
  final title = chinese
      ? 'MEGA 合成餐食记录，标题与原始内容应当保持自然可读'
      : 'MEGA synthetic QA meal with a readable original record title';
  final drug = DrugDefinition(
    id: 'readable-drug',
    genericName: chinese
        ? '合成药品记录，保留完整名称及全部可用操作'
        : 'Synthetic medication with a readable complete original name',
    brandNames: [],
    tags: [DrugTag.unknown],
    notes: 'Synthetic display fixture',
    sourceSystem: 'SYNTHETIC',
  );
  final food = FoodItem(
    id: 'readable-food',
    name: 'Synthetic food',
    category: FoodCategory.other,
    sourceSystem: 'SYNTHETIC',
    proteinG: 10,
    carbsG: 5,
    fatG: 1,
    fiberG: 1,
    sodiumMg: 0,
  );
  state.foodRepo.replaceAll([food]);
  state.medRepo.replaceAll([drug]);
  await state.addMeal(
    Meal(
      id: 'readable-meal',
      title: title,
      eatenAt: DateTime.utc(2026, 9, 30, 6, 4),
      items: [MealItem.fromFood(food: food, quantityFactor: 1)],
    ),
  );
  await state.addIntake(
    Intake(
      id: 'readable-intake',
      drugId: drug.id,
      takenAt: DateTime.utc(2026, 9, 30, 7),
      dosageNote: 'Synthetic entry',
    ),
  );
  await state.saveObservation(
    PersonalObservation.create(
      id: 'readable-observation',
      kind: PersonalObservationKind.bloodPressure,
      occurredAt: DateTime.utc(2026, 9, 30, 8),
      recordedAt: DateTime.utc(2026, 9, 30, 8),
      originalTimezone: 'America/Toronto',
      source: PersonalObservationSource.caregiverReported,
      recorderId: state.currentUserId!,
      status: PersonalObservationStatus.recorded,
      systolic: 120,
      diastolic: 80,
      unit: PersonalObservation.bloodPressureUnit,
      posture: BloodPressurePosture.unknown,
      notes: chinese
          ? '长文字仍应获得完整的内容宽度，而不是被操作按钮挤压。'
          : 'Long original content retains readable width alongside every available action.',
    ),
  );
  return state;
}

Widget _host(AppState state, TypedLogRecordRef ref, double scale) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: TimelinePage(key: ValueKey(ref.viewKey), focus: ref),
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final locale in ['en', 'zh']) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        '$locale ${scale * 100}% 390px record cards preserve readable text and every action',
        (tester) async {
          // The intake commit awaits real service work after bootstrap. Run the
          // entire fixture outside the widget clock instead of waiting on it
          // while fakeAsync timers cannot advance.
          final state = (await tester.runAsync(
            () => _ready(locale).timeout(const Duration(seconds: 30)),
          ))!;
          addTearDown(state.dispose);
          await tester.binding.setSurfaceSize(const Size(390, 844));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          for (final ref in const [
            TypedLogRecordRef(TimelineEventType.meal, 'readable-meal'),
            TypedLogRecordRef(TimelineEventType.medication, 'readable-intake'),
            TypedLogRecordRef(
              TimelineEventType.observation,
              'readable-observation',
            ),
          ]) {
            await tester.pumpWidget(_host(state, ref, scale));
            await tester.pumpAndSettle();
            final row = find.byKey(ValueKey('timeline-record-${ref.viewKey}'));
            expect(row, findsOneWidget);
            final title = ref.type == TimelineEventType.meal
                ? find.descendant(
                    of: row,
                    matching: find.text(state.meals.single.title),
                  )
                : ref.type == TimelineEventType.medication
                ? find.descendant(
                    of: row,
                    matching: find.text(
                      state.medRepo.allDrugs.single.genericName,
                    ),
                  )
                : find.descendant(
                    of: row,
                    matching: find.text(
                      state.observations.single.summary(
                        chinese: locale == 'zh',
                      ),
                    ),
                  );
            expect(title, findsOneWidget);
            // A missing RenderFlex overflow is insufficient: the previous layout
            // gave a long title only ~40px and made it wrap every few characters.
            expect(tester.getSize(title).width, greaterThanOrEqualTo(200));
            expect(tester.widget<Text>(title).maxLines, isNull);
            final paragraph = tester.renderObject<RenderParagraph>(title);
            final cramped = TextPainter(
              text: paragraph.text,
              textDirection: paragraph.textDirection,
              textScaler: paragraph.textScaler,
            )..layout(maxWidth: 40);
            // Compare like-for-like text metrics; Flutter's test font differs
            // from bundled release fonts, especially with 200% English text.
            expect(tester.getSize(title).height, lessThan(cramped.height / 2));
            cramped.dispose();
            if (ref.type == TimelineEventType.observation) {
              final notes = find.descendant(
                of: row,
                matching: find.text(state.observations.single.notes!),
              );
              expect(tester.getSize(notes).width, greaterThanOrEqualTo(280));
              for (final prefix in [
                'export-fhir-bp',
                'edit-observation',
                'delete-observation',
              ]) {
                final action = find.descendant(
                  of: row,
                  matching: find.byKey(ValueKey('$prefix-${ref.recordId}')),
                );
                expect(action, findsOneWidget);
                expect(tester.widget<TextButton>(action).onPressed, isNotNull);
                expect(
                  tester.getTopLeft(action).dy,
                  greaterThanOrEqualTo(tester.getBottomLeft(notes).dy),
                );
              }
            } else {
              final tile = find.descendant(
                of: row,
                matching: find.byType(ListTile),
              );
              expect(tester.widget<ListTile>(tile).trailing, isNull);
              final actions = find.descendant(
                of: row,
                matching: find.byKey(
                  ValueKey('timeline-row-actions-${ref.viewKey}'),
                ),
              );
              expect(actions, findsOneWidget);
              expect(
                tester.getTopLeft(actions).dy,
                greaterThanOrEqualTo(tester.getBottomLeft(tile).dy),
              );
              final buttons = find.descendant(
                of: actions,
                matching: find.byType(IconButton),
              );
              expect(
                buttons,
                findsNWidgets(ref.type == TimelineEventType.meal ? 4 : 5),
              );
              expect(
                tester
                    .widgetList<IconButton>(buttons)
                    .every(
                      (button) =>
                          button.onPressed != null &&
                          button.tooltip?.isNotEmpty == true,
                    ),
                isTrue,
              );
              final originalKeys = ref.type == TimelineEventType.meal
                  ? [
                      'fhir-r5-nutrition-intake-export-readable-meal',
                      'reuse-meal-readable-meal',
                    ]
                  : [
                      'fhir-r4-intake-export-readable-intake',
                      'fhir-r5-dose-preview-readable-intake',
                      'review-medication-assertions-readable-intake',
                    ];
              for (final key in originalKeys) {
                expect(
                  find.descendant(
                    of: actions,
                    matching: find.byKey(ValueKey(key)),
                  ),
                  findsOneWidget,
                );
              }
            }
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }

  testWidgets('wide record cards retain the existing trailing actions', (
    tester,
  ) async {
    final state = (await tester.runAsync(
      () => _ready('en').timeout(const Duration(seconds: 30)),
    ))!;
    addTearDown(state.dispose);
    await tester.binding.setSurfaceSize(const Size(900, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const ref = TypedLogRecordRef(TimelineEventType.meal, 'readable-meal');
    await tester.pumpWidget(_host(state, ref, 1));
    await tester.pumpAndSettle();
    final row = find.byKey(
      const ValueKey('timeline-record-meal:readable-meal'),
    );
    final tile = find.descendant(of: row, matching: find.byType(ListTile));
    expect(tester.widget<ListTile>(tile).trailing, isA<Wrap>());
    expect(
      find.descendant(of: tile, matching: find.byType(IconButton)),
      findsNWidgets(4),
    );
    expect(
      find.byKey(const ValueKey('timeline-row-actions-meal:readable-meal')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
