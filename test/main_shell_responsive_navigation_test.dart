import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/theme/liquid_glass_theme.dart';
import 'package:parkinsum_companion/features/main_shell/main_shell.dart';

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
