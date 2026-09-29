import 'synthetic_cds_hooks_service_registry.dart';

enum SyntheticCdsHooksProtocolStage {
  serviceMatched('service_matched'),
  prefetchPlanned('prefetch_planned'),
  requestPreviewed('request_previewed'),
  responsePreviewed('response_previewed');

  const SyntheticCdsHooksProtocolStage(this.wireValue);

  final String wireValue;
}

/// Versioned, code-owned protocol metadata, separate from any enactment.
final class SyntheticCdsHooksProtocolDefinition {
  SyntheticCdsHooksProtocolDefinition._({
    required this.id,
    required this.version,
    required this.hook,
    required List<SyntheticCdsHooksProtocolStage> stages,
  }) : stages = List<SyntheticCdsHooksProtocolStage>.unmodifiable(stages);

  final String id;
  final int version;
  final SyntheticCdsHooksHook hook;
  final List<SyntheticCdsHooksProtocolStage> stages;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'version': version,
    'hook': hook.wireValue,
    'stages': stages.map((stage) => stage.wireValue).toList(),
  };
}

/// One immutable event in a fixed local enactment preview.
final class SyntheticCdsHooksEnactmentEvent {
  SyntheticCdsHooksEnactmentEvent._({
    required this.sequence,
    required this.serviceId,
    required this.stage,
    required Map<String, Object?> details,
  }) : details = _freezeMap(details);

  final int sequence;
  final String serviceId;
  final SyntheticCdsHooksProtocolStage stage;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => <String, Object?>{
    'sequence': sequence,
    'serviceId': serviceId,
    'stage': stage.wireValue,
    'details': details,
  };
}

/// One deterministic preview instance bound to a versioned protocol.
final class SyntheticCdsHooksEnactmentPreview {
  SyntheticCdsHooksEnactmentPreview._({
    required this.protocol,
    required this.id,
    required List<SyntheticCdsHooksEnactmentEvent> events,
  }) : events = List<SyntheticCdsHooksEnactmentEvent>.unmodifiable(events);

  final SyntheticCdsHooksProtocolDefinition protocol;
  final String id;
  final List<SyntheticCdsHooksEnactmentEvent> events;

  Map<String, Object?> toJson() => <String, Object?>{
    'protocol': protocol.toJson(),
    'enactmentId': id,
    'events': events.map((event) => event.toJson()).toList(),
  };
}

/// Reconstructed prefix of an enactment and the next event available to replay.
final class SyntheticCdsHooksEnactmentReplayState {
  SyntheticCdsHooksEnactmentReplayState._({
    required this.protocol,
    required this.enactmentId,
    required this.completedEventCount,
    required List<SyntheticCdsHooksEnactmentEvent> completedEvents,
    required this.nextEvent,
  }) : completedEvents = List<SyntheticCdsHooksEnactmentEvent>.unmodifiable(
         completedEvents,
       );

  final SyntheticCdsHooksProtocolDefinition protocol;
  final String enactmentId;
  final int completedEventCount;
  final List<SyntheticCdsHooksEnactmentEvent> completedEvents;
  final SyntheticCdsHooksEnactmentEvent? nextEvent;

  bool get isComplete => nextEvent == null;

  Map<String, Object?> toJson() => <String, Object?>{
    'protocol': protocol.toJson(),
    'enactmentId': enactmentId,
    'completedEventCount': completedEventCount,
    'completedEvents': completedEvents.map((event) => event.toJson()).toList(),
    'nextEvent': nextEvent?.toJson(),
  };
}

/// Builds and replays deterministic, fixed-fixture service previews only.
/// No endpoint, patient record, rule engine, or persistence is used.
abstract final class SyntheticCdsHooksEnactmentReplay {
  static const int protocolVersion = 1;
  static const List<SyntheticCdsHooksProtocolStage> _stages =
      <SyntheticCdsHooksProtocolStage>[
        SyntheticCdsHooksProtocolStage.serviceMatched,
        SyntheticCdsHooksProtocolStage.prefetchPlanned,
        SyntheticCdsHooksProtocolStage.requestPreviewed,
        SyntheticCdsHooksProtocolStage.responsePreviewed,
      ];

  static SyntheticCdsHooksEnactmentPreview createForHook(
    SyntheticCdsHooksHook hook,
  ) {
    final protocol = SyntheticCdsHooksProtocolDefinition._(
      id: 'parkinsum.synthetic-cds-hooks.${hook.wireValue}',
      version: protocolVersion,
      hook: hook,
      stages: _stages,
    );
    final services = SyntheticCdsHooksServiceRegistry.servicesForHook(hook);
    final requestByService = <String, SyntheticCdsHooksServiceRequestEnvelopePlan>{
      for (final plan
          in SyntheticCdsHooksServiceRegistry.serviceRequestEnvelopePreviewsForHook(
            hook,
          ))
        plan.serviceId: plan,
    };
    final responseByService = <String, SyntheticCdsHooksServiceResponsePreview>{
      for (final preview
          in SyntheticCdsHooksServiceRegistry.serviceResponsePreviewsForHook(
            hook,
          ))
        preview.serviceId: preview,
    };
    final events = <SyntheticCdsHooksEnactmentEvent>[];

    void addEvent(
      SyntheticCdsHooksServiceDefinition service,
      SyntheticCdsHooksProtocolStage stage,
      Map<String, Object?> details,
    ) {
      events.add(
        SyntheticCdsHooksEnactmentEvent._(
          sequence: events.length + 1,
          serviceId: service.id,
          stage: stage,
          details: details,
        ),
      );
    }

    for (final service in services) {
      final request = requestByService[service.id];
      final response = responseByService[service.id];
      if (request == null || response == null || request.hook != hook) {
        throw StateError('A fixed service has incomplete preview metadata.');
      }
      addEvent(service, _stages[0], <String, Object?>{'hook': hook.wireValue});
      addEvent(service, _stages[1], <String, Object?>{
        'prefetchKeys': service.prefetchTemplates
            .map((template) => template.key)
            .toList(),
      });
      addEvent(service, _stages[2], <String, Object?>{
        'requestFields': request.requestBody.keys.toList(),
        'sent': false,
      });
      addEvent(service, _stages[3], <String, Object?>{
        'state': response.state.wireValue,
        'cardCount': response.cardCount,
        'invoked': false,
      });
    }

    return SyntheticCdsHooksEnactmentPreview._(
      protocol: protocol,
      id: 'preview-${hook.wireValue}-v$protocolVersion',
      events: events,
    );
  }

  /// Rebuilds a selected prefix without mutating the source enactment.
  static SyntheticCdsHooksEnactmentReplayState replayThrough(
    SyntheticCdsHooksEnactmentPreview enactment, {
    required int completedEventCount,
  }) {
    if (completedEventCount < 0 ||
        completedEventCount > enactment.events.length) {
      throw RangeError.range(
        completedEventCount,
        0,
        enactment.events.length,
        'completedEventCount',
      );
    }
    for (var index = 0; index < enactment.events.length; index++) {
      final event = enactment.events[index];
      final expectedStage = _stages[index % _stages.length];
      if (event.sequence != index + 1 || event.stage != expectedStage) {
        throw StateError('The fixed enactment event sequence is inconsistent.');
      }
    }
    return SyntheticCdsHooksEnactmentReplayState._(
      protocol: enactment.protocol,
      enactmentId: enactment.id,
      completedEventCount: completedEventCount,
      completedEvents: enactment.events.take(completedEventCount).toList(),
      nextEvent: completedEventCount == enactment.events.length
          ? null
          : enactment.events[completedEventCount],
    );
  }
}

Map<String, Object?> _freezeMap(Map<String, Object?> source) =>
    Map<String, Object?>.unmodifiable({
      for (final entry in source.entries) entry.key: _freezeValue(entry.value),
    });

Object? _freezeValue(Object? value) => switch (value) {
  Map<String, Object?> map => _freezeMap(map),
  List<dynamic> list => List<Object?>.unmodifiable(list.map(_freezeValue)),
  _ => value,
};
