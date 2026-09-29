import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/algorithm_observatory/algorithm_observatory_page.dart';
import 'package:parkinsum_companion/features/main_shell/main_shell.dart';
import 'package:parkinsum_companion/features/settings/settings_capability_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets(
    'initialized user can open observatory and inspect a live conflict trace',
    (tester) async {
      final state = await pumpFeaturePage(tester, const MainShell());

      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(SettingsCapabilityPage), findsOneWidget);

      // Settings leads with the profile form; the tools index follows it.
      await tester.scrollUntilVisible(
        find.text('Algorithm Observatory'),
        400,
        scrollable: find
            .descendant(
              of: find.byType(SettingsCapabilityPage),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Algorithm Observatory'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AlgorithmObservatoryPage), findsOneWidget);
      final observatoryPage = tester.widget<AlgorithmObservatoryPage>(
        find.byType(AlgorithmObservatoryPage),
      );
      expect(
        identical(
          observatoryPage.service,
          state.services.algorithmObservatoryService,
        ),
        isTrue,
      );
      expect(
        identical(
          observatoryPage.service!.conflictEngine,
          state.services.nextMealRecommendationOrchestrator.mechanisticEngine,
        ),
        isTrue,
      );
      expect(
        observatoryPage
            .service!
            .configurationIdentity
            .canonicalConfiguration['gastric_emptying'],
        observatoryPage
            .service!
            .conflictEngine
            .gastricEmptyingModel
            .configuration,
        reason:
            'the production Observatory identity must describe the exact injected gastric model instance',
      );
      expect(
        observatoryPage
            .service!
            .configurationIdentity
            .configurationCoverageManifest
            .entryFor('gastric_emptying')
            .completenessWitness,
        isNotNull,
      );

      final observatoryScroll = find
          .descendant(
            of: find.byType(AlgorithmObservatoryPage),
            matching: find.byType(Scrollable),
          )
          .first;
      await tester.scrollUntilVisible(
        find.byKey(const Key('observatory-scenario-highFatProtein')),
        180,
        scrollable: observatoryScroll,
      );
      await tester.ensureVisible(
        find.byKey(const Key('observatory-scenario-highFatProtein')),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('observatory-scenario-highFatProtein')),
      );
      await tester.pump();
      expect(find.textContaining('High fat + protein'), findsWidgets);
      await tester.scrollUntilVisible(
        find.byKey(const Key('observatory-explanation-tree')),
        260,
        scrollable: observatoryScroll,
      );
      expect(
        find.byKey(const Key('trace-node-mechanistic_conflict')),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(const Key('observatory-parameter-evidence')),
        260,
        scrollable: observatoryScroll,
      );
      expect(
        find.byKey(const Key('parameter-ge.solid.lag_minutes')),
        findsOneWidget,
      );
      expectNoWidgetErrors(
        reason: 'initialized-user algorithm journey raised a widget error',
      );
    },
  );
}
