import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/app/bootstrap_attempt_controller.dart';
import 'package:parkinsum_companion/app/bootstrap_gate.dart';

void main() {
  testWidgets('failure can retry and route to success', (tester) async {
    final firstAttempt = Completer<void>();
    final retryAttempt = Completer<void>();
    var operationCount = 0;
    final controller = BootstrapAttemptController(
      bootstrap: () {
        operationCount += 1;
        return operationCount == 1 ? firstAttempt.future : retryAttempt.future;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BootstrapGate(
          controller: controller,
          loadingLabel: 'Loading',
          failureLabel: 'Startup unavailable',
          retryLabel: 'Retry',
          successBuilder: (_) => const Scaffold(body: Text('Ready')),
        ),
      ),
    );
    await tester.pump();

    expect(operationCount, 1);
    expect(find.byKey(BootstrapGate.loadingKey), findsOneWidget);

    firstAttempt.completeError(StateError('private bootstrap detail'));
    await tester.pump();

    expect(find.byKey(BootstrapGate.failureKey), findsOneWidget);
    expect(find.text('private bootstrap detail'), findsNothing);

    await tester.tap(find.byKey(BootstrapGate.retryButtonKey));
    await tester.pump();

    expect(operationCount, 2);
    expect(find.byKey(BootstrapGate.loadingKey), findsOneWidget);

    retryAttempt.complete();
    await tester.pump();

    expect(find.text('Ready'), findsOneWidget);
    expect(find.byKey(BootstrapGate.failureKey), findsNothing);
  });

  testWidgets('completion after dispose does not call setState', (
    tester,
  ) async {
    final completion = Completer<void>();
    final controller = BootstrapAttemptController(
      bootstrap: () => completion.future,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BootstrapGate(
          controller: controller,
          loadingLabel: 'Loading',
          failureLabel: 'Startup unavailable',
          retryLabel: 'Retry',
          successBuilder: (_) => const SizedBox.shrink(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    completion.complete();
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
