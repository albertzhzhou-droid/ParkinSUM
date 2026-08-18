import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/theme/liquid_glass_theme.dart';
import 'package:parkinsum_companion/features/algorithm_observatory/algorithm_observatory_page.dart';
import 'package:parkinsum_companion/features/main_shell/main_shell.dart';
import 'package:parkinsum_companion/features/settings/settings_capability_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('phone uses bottom navigation and reports stable tab id', (
    tester,
  ) async {
    String? selectedId;
    await pumpFeaturePage(
      tester,
      MainShell(onTabSelected: (id) => selectedId = id),
    );

    expect(find.byType(GlassNavBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    await tester.tap(find.byIcon(Icons.restaurant_outlined).last);
    await tester.pump();
    expect(selectedId, 'timeline');

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(SettingsCapabilityPage), findsOneWidget);
    expect(find.text('Settings & capability center'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);

    final observatory = find.text('Algorithm Observatory');
    final settingsScrollable = find
        .descendant(
          of: find.byType(SettingsCapabilityPage),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      observatory,
      400,
      scrollable: settingsScrollable,
    );
    await tester.tap(observatory);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlgorithmObservatoryPage), findsOneWidget);
  });

  testWidgets('desktop uses navigation rail and restores selected tab', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const MainShell(selectedTabId: 'analytics'),
      surfaceSize: const Size(1440, 900),
      devicePixelRatio: 1,
    );

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(GlassNavBar), findsNothing);
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex,
      3,
    );
    expectNoWidgetErrors(reason: 'desktop main shell failed to build cleanly');
  });
}
