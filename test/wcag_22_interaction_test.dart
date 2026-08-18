import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/security/account_password_policy.dart';
import 'package:parkinsum_companion/core/services/data_service.dart';
import 'package:parkinsum_companion/core/services/user_logging_reminder_service.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/core/theme/liquid_glass_theme.dart';
import 'package:parkinsum_companion/domain/entities/user_logging_reminder.dart';
import 'package:parkinsum_companion/domain/entities/product_upgrade_queue.dart';
import 'package:parkinsum_companion/features/auth/auth_page.dart';
import 'package:parkinsum_companion/features/entry/entry_page.dart';
import 'package:parkinsum_companion/features/main_shell/main_shell.dart';
import 'package:parkinsum_companion/features/next_meal/next_meal_page.dart';
import 'package:parkinsum_companion/features/onboarding/onboarding_page.dart';
import 'package:parkinsum_companion/features/reminders/reminder_center_page.dart';
import 'package:parkinsum_companion/features/settings/settings_capability_page.dart';
import 'package:provider/provider.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('authentication reflows at 200% and supports password managers', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpA11yPage(
      tester,
      const AuthPage(),
      textScale: 2,
      logicalSize: const Size(320, 568),
    );

    expectNoWidgetErrors(reason: 'authentication clipped at 200% text');
    final passwordEditable = find.descendant(
      of: find.byKey(const ValueKey('auth-password')),
      matching: find.byType(EditableText),
    );
    final signInPassword = tester.widget<EditableText>(passwordEditable);
    expect(signInPassword.autofillHints, contains(AutofillHints.password));
    expect(signInPassword.obscureText, isTrue);

    await tester.tap(find.byKey(const ValueKey('auth-password-visibility')));
    await tester.pump();
    expect(tester.widget<EditableText>(passwordEditable).obscureText, isFalse);

    await tester.tap(find.byKey(const ValueKey('auth-mode-toggle')));
    await tester.pump();
    final registrationPassword = tester.widget<EditableText>(passwordEditable);
    expect(
      registrationPassword.autofillHints,
      contains(AutofillHints.newPassword),
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-email')),
      'demo@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('auth-password')),
      'short',
    );
    await tester.tap(find.byKey(const ValueKey('auth-submit')));
    await tester.pump();
    expect(
      find.text(
        'A new password needs at least '
        '${AccountPasswordPolicy.minimumLength} characters.',
      ),
      findsOneWidget,
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('primary navigation reflows without truncation at 200%', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    String? selected;
    await _pumpA11yPage(
      tester,
      MainShell(onTabSelected: (value) => selected = value),
      textScale: 2,
      logicalSize: const Size(320, 760),
    );

    expectNoWidgetErrors(reason: 'primary navigation broke at 200% text');
    for (final label in const [
      'Home',
      'Next meal',
      'Timeline',
      'Analytics',
      'Medications',
      'Catalog',
    ]) {
      expect(find.bySemanticsLabel(label), findsOneWidget);
      expect(find.text(label), findsOneWidget);
    }
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            const {
              'Home',
              'Next meal',
              'Timeline',
              'Analytics',
              'Medications',
              'Catalog',
            }.contains(widget.data) &&
            widget.maxLines == 2,
      ),
      findsNWidgets(6),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    final nextMealInk = find.ancestor(
      of: find.text('Next meal'),
      matching: find.byType(InkWell),
    );
    for (
      var i = 0;
      i < 20 && !_hasFocusedDescendant(tester, nextMealInk);
      i++
    ) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focus = FocusManager.instance.primaryFocus;
      if (focus?.context case final context?) {
        final renderObject = context.findRenderObject();
        if (renderObject is RenderBox && renderObject.hasSize) {
          final rect =
              renderObject.localToGlobal(Offset.zero) & renderObject.size;
          expect(
            (const Offset(0, 0) & const Size(320, 760)).overlaps(rect),
            isTrue,
            reason: 'keyboard focus moved fully outside the viewport',
          );
        }
      }
    }
    expect(
      _hasFocusedDescendant(tester, nextMealInk),
      isTrue,
      reason: 'Next meal was not reachable by keyboard traversal',
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, 'next-meal');
    semantics.dispose();
  });

  testWidgets('reminder center survives 200% text and keeps targets labeled', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final storage = _MemoryDataService();
    final repository = UserLoggingReminderRepository(storage: storage);
    await repository.save('wcag-user', [
      const UserLoggingReminder(
        id: 'evening-log',
        kind: UserLoggingReminderKind.intakeLog,
        label: 'Log evening intake',
        minuteOfDay: 21 * 60,
        weekdays: {1, 2, 3, 4, 5, 6, 7},
        enabled: true,
      ),
    ]);
    final controller = UserLoggingReminderController(
      userScope: 'wcag-user',
      repository: repository,
      gateway: const _NoDeliveryGateway(),
    );

    await _pumpA11yPage(
      tester,
      ReminderCenterPage(controller: controller),
      textScale: 2,
      logicalSize: const Size(320, 700),
    );
    await tester.pump();

    expectNoWidgetErrors(reason: 'reminder center broke at 200% text');
    expect(find.text('Log evening intake'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets(
    'registration profile and medication selection are keyboard-only',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpA11yPage(
        tester,
        const OnboardingPage(),
        textScale: 2,
        logicalSize: const Size(390, 844),
      );

      final nextButton = find.byKey(const ValueKey('onboarding-next'));
      await _tabUntilFocused(tester, nextButton);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('Registration region'), findsWidgets);

      final firstSelect = find.byType(GlassSelectField<String>).first;
      await _tabUntilFocused(tester, firstSelect);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Registration region'), findsWidgets);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump(const Duration(milliseconds: 300));

      await _tabUntilFocused(tester, nextButton);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      final medicationSearch = find.byKey(
        const ValueKey('onboarding-medication-search'),
      );
      await tester.scrollUntilVisible(
        medicationSearch,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(medicationSearch, findsOneWidget);
      expect(find.byType(CheckboxListTile), findsWidgets);
      final firstMedication = find.byType(CheckboxListTile).first;
      await tester.ensureVisible(firstMedication);
      await _tabUntilFocused(tester, firstMedication, maxTabs: 80);
      final before = tester.widget<CheckboxListTile>(firstMedication).value;
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(
        tester.widget<CheckboxListTile>(firstMedication).value,
        isNot(before),
      );
      expectNoWidgetErrors(reason: 'onboarding keyboard journey broke');
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );

  testWidgets('meal entry and recommendation controls reflow and take focus', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpA11yPage(
      tester,
      const EntryPage(),
      textScale: 2,
      logicalSize: const Size(320, 700),
    );
    expectNoWidgetErrors(reason: 'meal entry broke at 200% text');
    final foodSearch = find.byKey(const ValueKey('entry-food-search'));
    await _tabUntilFocused(tester, foodSearch, maxTabs: 40);
    expect(_hasFocusedDescendant(tester, foodSearch), isTrue);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

    await _pumpA11yPage(
      tester,
      const NextMealPage(),
      textScale: 2,
      logicalSize: const Size(320, 700),
    );
    expectNoWidgetErrors(reason: 'recommendation controls broke at 200% text');
    final timePicker = find.byKey(const ValueKey('next-meal-time-picker'));
    await tester.scrollUntilVisible(
      timePicker,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await _tabUntilFocused(tester, timePicker, maxTabs: 30);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 300));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets(
    'settings profile selectors expose value and keyboard activation',
    (tester) async {
      final semantics = tester.ensureSemantics();
      final queue = ProductUpgradeQueue.fromJsonText(
        File('config/complete_app_upgrade_queue.json').readAsStringSync(),
      );
      await _pumpA11yPage(
        tester,
        SettingsCapabilityPage(initialQueue: queue),
        textScale: 2,
        logicalSize: const Size(320, 700),
      );
      expectNoWidgetErrors(reason: 'settings broke at 200% text');
      final registrationRegion = find.byType(GlassSelectField<String>).first;
      await tester.ensureVisible(registrationRegion);
      await _tabUntilFocused(tester, registrationRegion, maxTabs: 60);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Registration region'), findsWidgets);
      expect(find.bySemanticsLabel('Registration region'), findsWidgets);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    },
  );

  testWidgets('decorative glass background does not animate indefinitely', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiquidGlassBackground(child: SizedBox.expand())),
    );

    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}

Future<AppState> _pumpA11yPage(
  WidgetTester tester,
  Widget page, {
  required double textScale,
  required Size logicalSize,
}) async {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final state = createTestAppState();
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: LiquidGlass.themeData(),
        home: LiquidGlassBackground(
          child: DefaultAssetBundle(bundle: StubAssetBundle(), child: page),
        ),
      ),
    ),
  );
  await tester.pump();
  return state;
}

class _MemoryDataService extends DataService {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> remove(String key) async {
    values.remove(key);
  }

  @override
  Future<void> setString(String key, String value) async {
    values[key] = value;
  }
}

class _NoDeliveryGateway implements ReminderNotificationGateway {
  const _NoDeliveryGateway();

  @override
  bool get supportsScheduledDelivery => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> synchronize(
    List<UserLoggingReminder> reminders, {
    required String userScope,
  }) async {}
}

bool _hasFocusedDescendant(WidgetTester tester, Finder ancestorFinder) {
  if (ancestorFinder.evaluate().isEmpty) return false;
  final focusedContext = FocusManager.instance.primaryFocus?.context;
  if (focusedContext is! Element) return false;
  final ancestor = tester.element(ancestorFinder.first);
  if (identical(ancestor, focusedContext)) return true;
  var found = false;
  focusedContext.visitAncestorElements((element) {
    if (identical(element, ancestor)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

Future<void> _tabUntilFocused(
  WidgetTester tester,
  Finder target, {
  int maxTabs = 40,
}) async {
  for (var i = 0; i < maxTabs && !_hasFocusedDescendant(tester, target); i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(
    _hasFocusedDescendant(tester, target),
    isTrue,
    reason: 'target was not reachable after $maxTabs Tab presses',
  );
}
