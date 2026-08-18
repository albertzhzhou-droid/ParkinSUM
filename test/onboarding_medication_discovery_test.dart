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
}
