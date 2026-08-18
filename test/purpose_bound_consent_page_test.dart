import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/settings/purpose_bound_consent_page.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('user can grant, review, and withdraw a versioned receipt', (
    tester,
  ) async {
    final services = Services.createEphemeral();
    await services.ready;
    await services.userDataService.saveOnboarded(true);
    final state = AppState(services: services);
    addTearDown(state.dispose);
    await state.bootstrap();

    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(home: PurposeBoundConsentPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Not granted; no new Local AI request will be started'),
      findsOneWidget,
    );
    await _tap(tester, 'consent-grant-local-ai');
    expect(state.userProfile.hasCurrentLocalAiConsent, isTrue);
    expect(state.userProfile.consentReceipts, hasLength(1));
    expect(find.text('Granted for the current notice version'), findsOneWidget);
    expect(find.text('Granted'), findsOneWidget);

    await _tap(tester, 'consent-revoke-local-ai');
    expect(state.userProfile.hasCurrentLocalAiConsent, isFalse);
    expect(state.userProfile.consentReceipts, hasLength(2));
    expect(find.text('Withdrawn'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _tap(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey<String>(key));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
