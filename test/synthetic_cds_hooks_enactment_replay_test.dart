import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_cds_hooks_enactment_replay.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_cds_hooks_service_registry.dart';

void main() {
  test(
    'protocol definitions and hook enactments remain separate and ordered',
    () {
      for (final hook in SyntheticCdsHooksHook.values) {
        final enactment = SyntheticCdsHooksEnactmentReplay.createForHook(hook);
        final services = SyntheticCdsHooksServiceRegistry.servicesForHook(hook);

        expect(enactment.protocol.hook, hook);
        expect(enactment.protocol.version, 1);
        expect(
          enactment.protocol.id,
          'parkinsum.synthetic-cds-hooks.${hook.wireValue}',
        );
        expect(enactment.id, 'preview-${hook.wireValue}-v1');
        expect(enactment.events, hasLength(services.length * 4));
        expect(
          enactment.events.map((event) => event.sequence),
          List<int>.generate(enactment.events.length, (index) => index + 1),
        );

        for (
          var serviceIndex = 0;
          serviceIndex < services.length;
          serviceIndex++
        ) {
          final serviceEvents = enactment.events
              .skip(serviceIndex * 4)
              .take(4)
              .toList();
          expect(
            serviceEvents.map((event) => event.serviceId),
            everyElement(services[serviceIndex].id),
          );
          expect(
            serviceEvents.map((event) => event.stage),
            <SyntheticCdsHooksProtocolStage>[
              SyntheticCdsHooksProtocolStage.serviceMatched,
              SyntheticCdsHooksProtocolStage.prefetchPlanned,
              SyntheticCdsHooksProtocolStage.requestPreviewed,
              SyntheticCdsHooksProtocolStage.responsePreviewed,
            ],
          );
          expect(
            serviceEvents[1].details['prefetchKeys'],
            services[serviceIndex].prefetchTemplates
                .map((template) => template.key)
                .toList(),
          );
          expect(serviceEvents[2].details['sent'], isFalse);
          expect(serviceEvents[3].details['invoked'], isFalse);
        }
      }
    },
  );

  test('replay rebuilds an immutable prefix and exposes the next event', () {
    final enactment = SyntheticCdsHooksEnactmentReplay.createForHook(
      SyntheticCdsHooksHook.patientView,
    );
    final initial = SyntheticCdsHooksEnactmentReplay.replayThrough(
      enactment,
      completedEventCount: 0,
    );
    final partial = SyntheticCdsHooksEnactmentReplay.replayThrough(
      enactment,
      completedEventCount: 3,
    );
    final complete = SyntheticCdsHooksEnactmentReplay.replayThrough(
      enactment,
      completedEventCount: enactment.events.length,
    );

    expect(initial.completedEvents, isEmpty);
    expect(initial.nextEvent?.sequence, 1);
    expect(partial.completedEvents.map((event) => event.sequence), <int>[
      1,
      2,
      3,
    ]);
    expect(partial.nextEvent?.sequence, 4);
    expect(
      partial.nextEvent?.stage,
      SyntheticCdsHooksProtocolStage.responsePreviewed,
    );
    expect(complete.completedEventCount, enactment.events.length);
    expect(complete.isComplete, isTrue);
    expect(complete.nextEvent, isNull);
    expect(enactment.events, hasLength(8));
    expect(() => partial.completedEvents.clear(), throwsUnsupportedError);
    expect(
      () => partial.completedEvents.first.details['hook'] = 'foreign-hook',
      throwsUnsupportedError,
    );
    expect(
      () => (enactment.events[1].details['prefetchKeys'] as List<Object?>).add(
        'foreign-key',
      ),
      throwsUnsupportedError,
    );
    expect(
      partial.toJson().toString(),
      isNot(contains(SyntheticCdsHooksServiceRegistry.fixedSyntheticPatientId)),
    );
  });

  test('replay rejects a position outside the enactment event range', () {
    final enactment = SyntheticCdsHooksEnactmentReplay.createForHook(
      SyntheticCdsHooksHook.orderSelect,
    );
    for (final completedEventCount in <int>[-1, enactment.events.length + 1]) {
      expect(
        () => SyntheticCdsHooksEnactmentReplay.replayThrough(
          enactment,
          completedEventCount: completedEventCount,
        ),
        throwsRangeError,
      );
    }
  });
}
