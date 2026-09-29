import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/theme/paper_theme.dart';
import 'package:parkinsum_companion/features/algorithm_observatory/algorithm_observatory_page.dart';
import 'package:parkinsum_companion/features/entry/entry_page.dart';
import 'package:parkinsum_companion/features/main_shell/main_shell.dart';
import 'package:parkinsum_companion/features/reminders/reminder_center_page.dart';
import 'package:parkinsum_companion/features/settings/settings_capability_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('phone uses chapter tabs and reports stable tab id', (
    tester,
  ) async {
    String? selectedId;
    await pumpFeaturePage(
      tester,
      MainShell(onTabSelected: (id) => selectedId = id),
    );

    // No bottom dock: chapter tabs sit under the page title.
    expect(find.byType(PaperChapterTabs), findsOneWidget);
    expect(find.byType(PaperSidebar), findsNothing);
    await tester.tap(find.byKey(const ValueKey('main-tab-timeline')));
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

  testWidgets('desktop uses sidebar and restores selected tab', (tester) async {
    await pumpFeaturePage(
      tester,
      const MainShell(selectedTabId: 'analytics'),
      surfaceSize: const Size(1440, 900),
      devicePixelRatio: 1,
    );

    expect(find.byType(PaperSidebar), findsOneWidget);
    expect(find.byType(PaperChapterTabs), findsNothing);
    expect(
      tester.widget<PaperSidebar>(find.byType(PaperSidebar)).selectedIndex,
      3,
    );
    // Global actions live in the sidebar, so the page header must not
    // repeat them (one header, no duplicated settings button).
    expect(find.byKey(const ValueKey('main-settings')), findsOneWidget);
    expectNoWidgetErrors(reason: 'desktop main shell failed to build cleanly');
  });

  testWidgets('desktop "New entry" menu opens the meal editor in one step', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const MainShell(),
      surfaceSize: const Size(1440, 900),
      devicePixelRatio: 1,
    );

    await tester.tap(find.byKey(const ValueKey('main-new-entry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('quick-intake')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-observation')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-meal')));
    // MenuItemButton runs onPressed after the frame that closes the menu.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.byType(EntryPage), findsOneWidget);
  });

  testWidgets('search palette filters every tool and opens it with Enter', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const MainShell(),
      surfaceSize: const Size(1440, 900),
      devicePixelRatio: 1,
    );

    await tester.tap(find.byKey(const ValueKey('main-search')));
    await tester.pumpAndSettle();
    final query = find.byKey(const ValueKey('command-palette-query'));
    expect(query, findsOneWidget);

    await tester.enterText(query, 'reminder');
    await tester.pump();
    expect(
      find.byKey(const ValueKey('command-tool-reminders')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('command-tab-home')), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.go);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ReminderCenterPage), findsOneWidget);
  });

  testWidgets('phone drawer exposes grouped tools behind one menu button', (
    tester,
  ) async {
    await pumpFeaturePage(tester, const MainShell());

    await tester.tap(find.byKey(const ValueKey('main-menu')));
    await tester.pumpAndSettle();
    expect(find.byType(PaperSidebar), findsOneWidget);
    expect(find.byKey(const ValueKey('tool-reminders')), findsNothing);

    await tester.ensureVisible(find.text('YOUR DATA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('YOUR DATA'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('tool-reminders')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tool-reminders')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(ReminderCenterPage), findsOneWidget);
    expectNoWidgetErrors(reason: 'drawer navigation failed to build cleanly');
  });
}
