import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/app/bootstrap_attempt_controller.dart';

void main() {
  test('concurrent runs share one bootstrap operation', () async {
    final completion = Completer<void>();
    var operationCount = 0;
    final controller = BootstrapAttemptController(
      bootstrap: () {
        operationCount += 1;
        return completion.future;
      },
    );

    final first = controller.run();
    final second = controller.run();

    expect(identical(first, second), isTrue);
    expect(operationCount, 1);
    expect(controller.phase, BootstrapAttemptPhase.running);

    completion.complete();
    expect(await first, BootstrapAttemptPhase.succeeded);
    expect(controller.phase, BootstrapAttemptPhase.succeeded);

    expect(await controller.run(), BootstrapAttemptPhase.succeeded);
    expect(operationCount, 1);
  });

  test('failed operation can be retried without exposing its error', () async {
    var operationCount = 0;
    final controller = BootstrapAttemptController(
      bootstrap: () async {
        operationCount += 1;
        if (operationCount == 1) {
          throw StateError('private bootstrap detail');
        }
      },
    );

    expect(await controller.run(), BootstrapAttemptPhase.failed);
    expect(controller.phase, BootstrapAttemptPhase.failed);

    expect(await controller.run(), BootstrapAttemptPhase.succeeded);
    expect(controller.phase, BootstrapAttemptPhase.succeeded);
    expect(operationCount, 2);
  });
}
