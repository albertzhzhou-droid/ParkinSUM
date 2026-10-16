import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/intake.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/core/theme/paper_theme.dart';
import 'package:parkinsum_companion/features/timeline/timeline_page.dart';
import 'package:provider/provider.dart';

const _unknown = 'synthetic-medication-not-in-catalogue';
const _blankPicker = ValueKey<String>('reminder-intake-medication-selection');
const _save = ValueKey<String>('intake-save');

Intake _record(String drugId) => Intake(
  id: 'synthetic-preserved-medication-editor',
  drugId: drugId,
  takenAt: DateTime.utc(2026, 9, 30, 12),
  dosageNote: '100 mg',
);

Future<AppState> _state(WidgetTester tester, {String locale = 'en-US'}) async {
  final result = await tester.runAsync(() async {
    final services = Services.createEphemeral();
    await services.ready;
    final state = AppState(services: services);
    await state.bootstrap();
    await state.saveUserProfile(
      state.userProfile.copyWith(displayLocale: locale),
    );
    return state;
  });
  addTearDown(result!.dispose);
  return result;
}

Future<void> _editor(
  WidgetTester tester,
  AppState state, {
  Intake? initial,
  bool narrow = false,
}) async {
  tester.view.physicalSize = narrow
      ? const Size(390, 844)
      : const Size(900, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: Paper.themeData(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(narrow ? 2 : 1)),
          child: child!,
        ),
        home: IntakeEditorPage(initialIntake: initial),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pressSave(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(_save),
    300,
    scrollable: find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.ensureVisible(find.byKey(_save));
  await tester.tap(find.byKey(_save));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'four identity expectations remain the independent prechange fixture',
    () {
      final bytes = File(
        'test/fixtures/unresolved_medication_editor_expectations.json',
      ).readAsBytesSync();
      expect(
        sha256.convert(bytes).toString(),
        'b775deb712614feaddb20df75e503dc2a5e8322b5e8e3497276b9830becfc347',
      );
      final fixture = jsonDecode(utf8.decode(bytes)) as Map;
      expect(fixture['before_production_edit'], true);
      expect(fixture['cases'], hasLength(4));
    },
  );

  for (final locale in ['en-US', 'zh-CN']) {
    testWidgets(
      '$locale unavailable existing reference is never preselected or overwritten',
      (tester) async {
        final state = await _state(tester, locale: locale);
        final original = _record(_unknown);
        expect((await state.addIntake(original)).wasCommitted, true);
        final before = state.intakes.single.toJson();
        await _editor(
          tester,
          state,
          initial: state.intakes.single,
          narrow: true,
        );
        expect(find.byKey(_blankPicker), findsOneWidget);
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(find.byKey(_blankPicker))
              .initialValue,
          isNull,
        );
        final explanation = find.textContaining(
          locale == 'zh-CN'
              ? '原记录中的药品在当前目录中不可用'
              : 'The recorded medication is unavailable',
        );
        expect(explanation, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(explanation).didExceedMaxLines,
          isFalse,
        );
        await _pressSave(tester);
        expect(state.intakes.single.toJson(), before);
        final persisted = await tester.runAsync(
          () => state.services.userDataService.loadIntakes(),
        );
        expect(persisted!.single.toJson(), before);
        expect(
          find.text(locale == 'zh-CN' ? '请先选择药品' : 'Select a medication first'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'catalogue loss while editing blocks a changed note without changing the saved record',
    (tester) async {
      final state = await _state(tester);
      final original = _record('drug_levodopa_carbidopa');
      expect((await state.addIntake(original)).wasCommitted, true);
      final before = state.intakes.single.toJson();
      await _editor(tester, state, initial: state.intakes.single);
      expect(
        tester
            .widget<PaperSelectField<String>>(
              find.byType(PaperSelectField<String>),
            )
            .value,
        original.drugId,
      );
      state.medRepo.replaceAll([state.medRepo.getById('drug_entacapone')!]);
      await tester.enterText(
        find.byKey(const ValueKey<String>('intake-dose-note')),
        '150 mg',
      );
      await tester.pumpAndSettle();
      expect(find.byKey(_blankPicker), findsOneWidget);
      await _pressSave(tester);
      expect(state.intakes.single.toJson(), before);
      final persisted = await tester.runAsync(
        () => state.services.userDataService.loadIntakes(),
      );
      expect(persisted!.single.toJson(), before);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a known existing reference keeps its exact nonfirst selection', (
    tester,
  ) async {
    final state = await _state(tester);
    final original = _record('drug_entacapone');
    expect(state.medRepo.allDrugs.first.id, isNot(original.drugId));
    expect((await state.addIntake(original)).wasCommitted, true);
    await _editor(tester, state, initial: state.intakes.single);
    expect(find.byKey(_blankPicker), findsNothing);
    expect(
      tester
          .widget<PaperSelectField<String>>(
            find.byType(PaperSelectField<String>),
          )
          .value,
      original.drugId,
    );
    await _pressSave(tester);
    final persisted = await tester.runAsync(
      () => state.services.userDataService.loadIntakes(),
    );
    expect(persisted!.single.drugId, original.drugId);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an unavailable reference changes only after an explicit picker selection',
    (tester) async {
      final state = await _state(tester);
      expect((await state.addIntake(_record(_unknown))).wasCommitted, true);
      await _editor(tester, state, initial: state.intakes.single);
      await tester.tap(find.byKey(_blankPicker));
      await tester.pumpAndSettle();
      final chosen = find.byWidgetPredicate(
        (widget) =>
            widget is DropdownMenuItem<String> &&
            widget.value == 'drug_entacapone',
      );
      expect(chosen, findsOneWidget);
      await tester.tap(
        find.descendant(of: chosen, matching: find.byType(Text)).hitTestable(),
      );
      await tester.pumpAndSettle();
      await _pressSave(tester);
      final persisted = await tester.runAsync(
        () => state.services.userDataService.loadIntakes(),
      );
      expect(persisted!.single.drugId, 'drug_entacapone');
      expect(persisted.single.doseConfirmation, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the existing generic new-entry default remains visible and unchanged',
    (tester) async {
      final state = await _state(tester);
      await _editor(tester, state);
      expect(find.byKey(_blankPicker), findsNothing);
      expect(
        tester
            .widget<PaperSelectField<String>>(
              find.byType(PaperSelectField<String>),
            )
            .value,
        state.medRepo.allDrugs.first.id,
      );
      expect(state.intakes, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
