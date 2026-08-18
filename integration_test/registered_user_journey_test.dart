import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:parkinsum_companion/app/app.dart';
import 'package:parkinsum_companion/core/services/services.dart';

const _testedCommit = String.fromEnvironment(
  'PARKINSUM_TEST_COMMIT',
  defaultValue: 'local-uncommitted',
);
const _testedTarget = String.fromEnvironment(
  'PARKINSUM_TEST_TARGET',
  defaultValue: 'local-device',
);

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'fresh local user completes onboarding, navigates, and survives restart',
    (tester) async {
      final services = Services.createEphemeral();
      binding.reportData = <String, dynamic>{
        'schema_version': 1,
        'product_version': '0.2.0+2',
        'commit': _testedCommit,
        'target': _testedTarget,
        'flutter_target_platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
        'storage_boundary': 'ephemeral-process-memory',
        'real_user_data_accessed': false,
        'journeys': <String>[
          'fresh-onboarding',
          'medication-selection',
          'next-meal-navigation',
          'next-meal-recommendation-generation',
          'settings-navigation',
          'persisted-restart',
        ],
      };

      await tester.pumpWidget(
        ParkinSUMApp(
          key: const ValueKey('integration-run-1'),
          services: services,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('onboarding-next')),
      );

      // Safety -> profile -> medication selection.
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('onboarding-next')),
      );
      expect(find.text('Registration region'), findsWidgets);
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('onboarding-next')),
      );
      final medicationSearch = find.byKey(
        const ValueKey('onboarding-medication-search'),
      );
      await tester.scrollUntilVisible(
        medicationSearch,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      expect(medicationSearch, findsOneWidget);
      final firstMedication = find.byType(CheckboxListTile).first;
      await tester.ensureVisible(firstMedication);
      await tester.tap(firstMedication);
      await tester.pumpAndSettle();
      expect(tester.widget<CheckboxListTile>(firstMedication).value, isTrue);

      // Preferences -> review -> finish.
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('onboarding-next')),
      );
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('onboarding-next')),
      );
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('onboarding-finish')),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('main-tab-next-meal')),
      );

      expect(await services.userDataService.loadOnboarded(), isTrue);
      expect(await services.userDataService.loadActiveDrugIds(), isNotEmpty);

      await tester.tap(find.byKey(const ValueKey('main-tab-next-meal')));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('next-meal-time-picker')),
      );
      expect(find.byKey(const ValueKey('next-meal-generate')), findsOneWidget);
      await _tapAndSettle(
        tester,
        find.byKey(const ValueKey('next-meal-generate')),
      );
      await _pumpUntilResultOrError(
        tester,
        find.byKey(const ValueKey('next-meal-result')),
      );

      await tester.tap(find.byKey(const ValueKey('main-settings')));
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('settings-save-profile')),
      );
      expect(find.text('Complete-app upgrade queue'), findsOneWidget);

      // A new app root with the same ephemeral service graph must reload the
      // durable-in-scope onboarding/profile selection instead of showing the
      // wizard again. The graph never touches an installed user's records.
      await tester.pumpWidget(
        ParkinSUMApp(
          key: const ValueKey('integration-run-2'),
          services: services,
        ),
      );
      await _pumpUntilFound(
        tester,
        find.byKey(const ValueKey('main-tab-next-meal')),
      );
      expect(find.byKey(const ValueKey('onboarding-next')), findsNothing);
      expect(find.byKey(const ValueKey('main-settings')), findsOneWidget);
    },
  );
}

Future<void> _tapAndSettle(WidgetTester tester, Finder finder) async {
  expect(finder, findsOneWidget, reason: 'Expected one target for $finder.');
  if (finder.hitTestable().evaluate().isEmpty) {
    final scrollable = Scrollable.maybeOf(tester.element(finder));
    expect(
      scrollable,
      isNotNull,
      reason: 'Off-screen target has no enclosing Scrollable: $finder.',
    );
    for (var attempt = 0; attempt < 12; attempt += 1) {
      if (finder.hitTestable().evaluate().isNotEmpty) break;
      final position = scrollable!.position;
      final next = (position.pixels + 180)
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (next == position.pixels) break;
      position.jumpTo(next);
      await tester.pump(const Duration(milliseconds: 50));
    }
  }
  final target = finder.hitTestable();
  expect(
    target,
    findsOneWidget,
    reason: 'Target remained off-screen: $finder.',
  );
  await tester.tap(target);
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

Future<void> _pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty && DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    finder,
    findsWidgets,
    reason: 'Timed out waiting for $finder after ${timeout.inSeconds}s.',
  );
}

Future<void> _pumpUntilResultOrError(
  WidgetTester tester,
  Finder result, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final resultState = find.byKey(const ValueKey('next-meal-state-result'));
  final errorState = find.byKey(const ValueKey('next-meal-state-error'));
  final error = find.byKey(const ValueKey('next-meal-error'));
  final deadline = DateTime.now().add(timeout);
  while (resultState.evaluate().isEmpty &&
      errorState.evaluate().isEmpty &&
      DateTime.now().isBefore(deadline)) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  final pageState = errorState.evaluate().isNotEmpty ? errorState : resultState;
  final pageScroll = find
      .descendant(of: pageState, matching: find.byType(Scrollable))
      .first;
  if (errorState.evaluate().isNotEmpty) {
    await tester.scrollUntilVisible(error, 240, scrollable: pageScroll);
    final messages = tester
        .widgetList<Text>(
          find.descendant(of: error, matching: find.byType(Text)),
        )
        .map((widget) => widget.data)
        .whereType<String>()
        .where((message) => message.trim().isNotEmpty)
        .join(' | ');
    fail('Next-meal generation failed: $messages');
  }
  expect(
    resultState,
    findsOneWidget,
    reason: 'Timed out waiting for a result state after ${timeout.inSeconds}s.',
  );
  await tester.scrollUntilVisible(result, 240, scrollable: pageScroll);
  expect(
    result,
    findsWidgets,
    reason: 'Timed out waiting for $result after ${timeout.inSeconds}s.',
  );
}
