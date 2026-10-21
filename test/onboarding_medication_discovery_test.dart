import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/onboarding/onboarding_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('onboarding medication choices are searchable and bounded', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const OnboardingPage(),
      surfaceSize: const Size(1200, 1800),
      devicePixelRatio: 1,
    );

    final medicationStep = find.text('Initial medications');
    await tester.ensureVisible(medicationStep);
    await tester.pump();
    await tester.tap(medicationStep);
    await tester.pump(const Duration(milliseconds: 300));

    final search = find.byKey(const ValueKey('onboarding-medication-search'));
    await tester.ensureVisible(search);
    await tester.pump();
    expect(search, findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-medication-picker')),
      findsOneWidget,
    );

    await tester.enterText(search, 'pimavanserin');
    await tester.pump();
    expect(find.text('Pimavanserin'), findsOneWidget);
    expect(find.text('Entacapone'), findsNothing);
    expectNoWidgetErrors(reason: 'searchable onboarding medication picker');
  });

  regionAwareMedicationSearch();
}

Future<Finder> _openMedicationSearch(WidgetTester tester) async {
  await pumpFeaturePage(
    tester,
    const OnboardingPage(),
    surfaceSize: const Size(1200, 1800),
    devicePixelRatio: 1,
  );
  final medicationStep = find.text('Initial medications');
  await tester.ensureVisible(medicationStep);
  await tester.pump();
  await tester.tap(medicationStep);
  await tester.pump(const Duration(milliseconds: 300));
  final search = find.byKey(const ValueKey('onboarding-medication-search'));
  await tester.ensureVisible(search);
  await tester.pump();
  return search;
}

void regionAwareMedicationSearch() {
  testWidgets('a brand listed only for another region names those regions', (
    tester,
  ) async {
    final search = await _openMedicationSearch(tester);
    expect(
      find.descendant(of: search, matching: find.text('Search medications')),
      findsOneWidget,
    );
    expect(find.text('Search foods or medications'), findsNothing);

    // Readable source, route and dose form; no catalogue codes.
    expect(
      find.text(
        'RxNorm (US National Library of Medicine) · United States · oral · tablet',
      ),
      findsWidgets,
    );
    expect(
      find.textContaining('tablet or orally disintegrating tablet'),
      findsOneWidget,
    );
    expect(find.textContaining('RXNORM'), findsNothing);
    expect(find.textContaining('DAILYMED'), findsNothing);
    expect(find.textContaining('tablet_or_odt'), findsNothing);

    await tester.enterText(search, 'Madopar');
    await tester.pump();
    expect(
      find.text(
        '“Madopar” is not in this prototype’s United States catalog. '
        'The catalog lists it for: Canada.',
      ),
      findsOneWidget,
    );
    expect(find.text('Listed for other regions'), findsOneWidget);
    expect(find.text('Levodopa/Benserazide'), findsOneWidget);
    expect(
      find.text('No medications are available in the catalog.'),
      findsNothing,
    );

    await tester.enterText(search, 'zzzz-not-a-medication');
    await tester.pump();
    expect(
      find.text(
        'No medication in the catalog matches “zzzz-not-a-medication”.',
      ),
      findsOneWidget,
    );
    expectNoWidgetErrors(reason: 'region-aware onboarding medication search');
  });

  testWidgets('drugs of the registration region are listed first', (
    tester,
  ) async {
    await _openMedicationSearch(tester);
    final tiles = tester
        .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
        .map((tile) => (tile.title! as Text).data)
        .toList();
    expect(tiles.first, 'Levodopa/Carbidopa');
    expect(tiles, isNot(contains('Levodopa/Benserazide')));
    final benserazide = find.text('Levodopa/Benserazide');
    final pickerScroll = tester.state<ScrollableState>(
      find
          .descendant(
            of: find.byKey(const ValueKey('onboarding-medication-picker')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // The lazy list refines its extent as it builds; jump until the end.
    for (var i = 0; i < 6 && benserazide.evaluate().isEmpty; i++) {
      pickerScroll.position.jumpTo(pickerScroll.position.maxScrollExtent);
      await tester.pump();
    }
    expect(benserazide, findsOneWidget);
    final heading = find.byKey(
      const ValueKey('onboarding-medication-other-regions'),
    );
    expect(
      tester.getTopLeft(benserazide).dy,
      greaterThan(tester.getTopLeft(heading).dy),
    );
    expect(
      find.text(
        'Health Canada Drug Product Database · Canada · oral · capsule or tablet',
      ),
      findsOneWidget,
    );
    expectNoWidgetErrors(reason: 'onboarding medication region ordering');
  });
}
