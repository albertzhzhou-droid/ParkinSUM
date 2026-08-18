import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/mechanistic_event_ledger.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_event_ledger_builder.dart';

void main() {
  group('MechanisticUnitConverter', () {
    test('converts equivalent supported units without changing dimensions', () {
      expect(
        MechanisticUnitConverter.convert(
          value: 0.1,
          fromUnit: 'g',
          toUnit: 'mg',
          dimension: MechanisticLedgerDimension.mass,
        ),
        100,
      );
      expect(
        MechanisticUnitConverter.convert(
          value: 2,
          fromUnit: 'h',
          toUnit: 'min',
          dimension: MechanisticLedgerDimension.duration,
        ),
        120,
      );
      expect(
        MechanisticUnitConverter.convert(
          value: 25,
          fromUnit: '%',
          toUnit: 'fraction',
          dimension: MechanisticLedgerDimension.fraction,
        ),
        0.25,
      );
    });

    test('rejects nonfinite, ambiguous, and cross-dimension conversions', () {
      expect(
        () => MechanisticUnitConverter.convert(
          value: double.nan,
          fromUnit: 'mg',
          toUnit: 'g',
          dimension: MechanisticLedgerDimension.mass,
        ),
        throwsArgumentError,
      );
      expect(
        () => MechanisticUnitConverter.convert(
          value: 1,
          fromUnit: 'm',
          toUnit: 'min',
          dimension: MechanisticLedgerDimension.duration,
        ),
        throwsArgumentError,
      );
      expect(
        () => MechanisticUnitConverter.convert(
          value: 1,
          fromUnit: 'mg',
          toUnit: 'min',
          dimension: MechanisticLedgerDimension.mass,
        ),
        throwsArgumentError,
      );
    });
  });

  test('known zero, unknown, not collected, and BQL remain distinct', () {
    final zero = _measurement(
      id: 'zero',
      state: MechanisticLedgerValueState.known,
      value: 0,
    );
    final unknown = _measurement(
      id: 'unknown',
      state: MechanisticLedgerValueState.unknown,
    );
    final notCollected = _measurement(
      id: 'not_collected',
      state: MechanisticLedgerValueState.notCollected,
    );
    final bql = MechanisticLedgerMeasurement(
      id: 'bql',
      state: MechanisticLedgerValueState.belowQuantification,
      dimension: MechanisticLedgerDimension.mass,
      origin: MechanisticLedgerValueOrigin.observedOriginal,
      originalValue: null,
      originalUnit: 'mg',
      canonicalValue: null,
      canonicalUnit: 'mg',
      lowerQuantificationLimit: 0.05,
    );

    expect(zero.canonicalValue, 0);
    expect(unknown.canonicalValue, isNull);
    expect(notCollected.state, MechanisticLedgerValueState.notCollected);
    expect(bql.lowerQuantificationLimit, 0.05);
    expect(
      () => MechanisticLedgerMeasurement(
        id: 'bad_unknown',
        state: MechanisticLedgerValueState.unknown,
        dimension: MechanisticLedgerDimension.mass,
        origin: MechanisticLedgerValueOrigin.observedOriginal,
        originalValue: 0,
        originalUnit: 'mg',
        canonicalValue: 0,
        canonicalUnit: 'mg',
      ),
      throwsArgumentError,
    );
  });

  test(
    'offset timestamp is preserved and ambiguous local time is rejected',
    () {
      final event = MechanisticLedgerEvent(
        id: 'dose_a',
        kind: MechanisticLedgerEventKind.dose,
        originalTimestamp: '2026-01-01T03:00:00.000-05:00',
        occurredAtUtc: DateTime.utc(2026, 1, 1, 8),
        timezoneOffsetMinutes: -300,
        orderAtTimestamp: 0,
        sourceId: 'source:a',
        revisionId: 'revision:a',
        synthetic: false,
        measurements: [_measurement(id: 'dose', value: 100)],
      );
      expect(event.occurredAtUtc, DateTime.utc(2026, 1, 1, 8));
      expect(event.timezoneOffsetMinutes, -300);

      expect(
        () => MechanisticLedgerEvent(
          id: 'ambiguous',
          kind: MechanisticLedgerEventKind.observation,
          originalTimestamp: '2026-11-01T01:30:00.000',
          occurredAtUtc: DateTime.utc(2026, 11, 1, 1, 30),
          timezoneOffsetMinutes: 0,
          orderAtTimestamp: 0,
          sourceId: 'source:a',
          revisionId: 'revision:a',
          synthetic: false,
          measurements: const [],
        ),
        throwsFormatException,
      );
    },
  );

  test('production context projects to a deterministic synthetic ledger', () {
    final snapshot = AlgorithmObservatoryService().build(
      ObservatoryScenario.mixedReference,
    );
    final builder = const MechanisticEventLedgerBuilder();

    MechanisticEventLedger build() => builder.build(
      ledgerId: 'observatory_mixed_ledger',
      context: snapshot.context,
      mealCompositionsById: {snapshot.composition.id: snapshot.composition},
      configurationDigest: snapshot.configurationIdentity.sha256Digest,
      createdAtUtc: DateTime.utc(2026, 1, 1, 8),
      sourceId: 'synthetic:observatory',
      revisionId: 'observatory_fixture_v1',
      synthetic: true,
    );

    final first = build();
    final second = build();
    expect(first.sha256Digest, second.sha256Digest);
    expect(first.events, hasLength(3));
    expect(
      first.events.map((event) => event.kind),
      containsAll(<MechanisticLedgerEventKind>[
        MechanisticLedgerEventKind.meal,
        MechanisticLedgerEventKind.dose,
        MechanisticLedgerEventKind.context,
      ]),
    );
    expect(first.events.every((event) => event.synthetic), isTrue);
    final dose = first.events.singleWhere(
      (event) => event.kind == MechanisticLedgerEventKind.dose,
    );
    expect(dose.measurements.single.originalValue, 100);
    expect(dose.measurements.single.canonicalValue, 100);
    expect(dose.formulation, 'tablet');
    expect(dose.route, 'oral');
    final meal = first.events.singleWhere(
      (event) => event.kind == MechanisticLedgerEventKind.meal,
    );
    expect(
      meal.measurements
          .singleWhere((value) => value.id == 'protein')
          .canonicalValue,
      8000,
    );
    expect(
      first.events
          .where((event) => event.occurredAtUtc == DateTime.utc(2026, 1, 1, 8))
          .map((event) => event.orderAtTimestamp)
          .toSet(),
      {0, 1},
    );
  });

  test('canonical JSON round-trip preserves digest and rejects tampering', () {
    final snapshot = AlgorithmObservatoryService().build(
      ObservatoryScenario.mixedReference,
    );
    final ledger = const MechanisticEventLedgerBuilder().build(
      ledgerId: 'roundtrip_ledger',
      context: snapshot.context,
      mealCompositionsById: {snapshot.composition.id: snapshot.composition},
      configurationDigest: snapshot.configurationIdentity.sha256Digest,
      createdAtUtc: DateTime.utc(2026, 1, 1, 8),
      sourceId: 'synthetic:observatory',
      revisionId: 'observatory_fixture_v1',
      synthetic: true,
    );
    final decoded = jsonDecode(jsonEncode(ledger.toJson())) as Map;
    final roundTrip = MechanisticEventLedger.fromJson(
      decoded.cast<String, Object?>(),
    );
    expect(roundTrip.sha256Digest, ledger.sha256Digest);
    expect(roundTrip.canonicalReplayDigest, ledger.canonicalReplayDigest);
    expect(roundTrip.toJson(), ledger.toJson());

    final tampered = jsonDecode(jsonEncode(ledger.toJson())) as Map;
    final events = tampered['events'] as List;
    final event = events.first as Map;
    event['revision_id'] = 'tampered';
    expect(
      () => MechanisticEventLedger.fromJson(tampered.cast<String, Object?>()),
      throwsFormatException,
    );

    final extra = jsonDecode(jsonEncode(ledger.toJson())) as Map;
    extra['unsupported'] = true;
    expect(
      () => MechanisticEventLedger.fromJson(extra.cast<String, Object?>()),
      throwsFormatException,
    );
  });

  test(
    'canonical replay digest is stable across equivalent units and offsets',
    () {
      MechanisticEventLedger ledger({
        required String timestamp,
        required int offsetMinutes,
        required double originalValue,
        required String originalUnit,
      }) => MechanisticEventLedger(
        ledgerId: 'equivalent_replay',
        createdAtUtc: DateTime.utc(2026),
        configurationDigest: _digest,
        boundary: 'test boundary',
        events: [
          MechanisticLedgerEvent(
            id: 'dose_a',
            kind: MechanisticLedgerEventKind.dose,
            originalTimestamp: timestamp,
            occurredAtUtc: DateTime.utc(2026, 1, 1, 8),
            timezoneOffsetMinutes: offsetMinutes,
            orderAtTimestamp: 0,
            sourceId: 'source:a',
            revisionId: 'revision:a',
            synthetic: false,
            measurements: [
              MechanisticLedgerMeasurement(
                id: 'dose',
                state: MechanisticLedgerValueState.known,
                dimension: MechanisticLedgerDimension.mass,
                origin: MechanisticLedgerValueOrigin.observedOriginal,
                originalValue: originalValue,
                originalUnit: originalUnit,
                canonicalValue: 100,
                canonicalUnit: 'mg',
              ),
            ],
          ),
        ],
      );

      final milligrams = ledger(
        timestamp: '2026-01-01T03:00:00.000-05:00',
        offsetMinutes: -300,
        originalValue: 100,
        originalUnit: 'mg',
      );
      final gramsAtUtc = ledger(
        timestamp: '2026-01-01T08:00:00.000Z',
        offsetMinutes: 0,
        originalValue: 0.1,
        originalUnit: 'g',
      );

      expect(milligrams.sha256Digest, isNot(gramsAtUtc.sha256Digest));
      expect(
        milligrams.canonicalReplayDigest,
        gramsAtUtc.canonicalReplayDigest,
      );
    },
  );

  test(
    'duplicate identities and undefined equal-time ordering fail closed',
    () {
      final event = _event(id: 'event_a', order: 0);
      expect(
        () => MechanisticEventLedger(
          ledgerId: 'duplicate_id',
          createdAtUtc: DateTime.utc(2026),
          configurationDigest: _digest,
          boundary: 'test boundary',
          events: [event, event],
        ),
        throwsArgumentError,
      );
      expect(
        () => MechanisticEventLedger(
          ledgerId: 'duplicate_order',
          createdAtUtc: DateTime.utc(2026),
          configurationDigest: _digest,
          boundary: 'test boundary',
          events: [
            event,
            _event(id: 'event_b', order: 0),
          ],
        ),
        throwsArgumentError,
      );
    },
  );
}

const String _digest =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

MechanisticLedgerMeasurement _measurement({
  required String id,
  MechanisticLedgerValueState state = MechanisticLedgerValueState.known,
  double? value,
}) => MechanisticLedgerMeasurement(
  id: id,
  state: state,
  dimension: MechanisticLedgerDimension.mass,
  origin: MechanisticLedgerValueOrigin.observedOriginal,
  originalValue: state == MechanisticLedgerValueState.known ? value ?? 1 : null,
  originalUnit: 'mg',
  canonicalValue: state == MechanisticLedgerValueState.known
      ? value ?? 1
      : null,
  canonicalUnit: 'mg',
);

MechanisticLedgerEvent _event({required String id, required int order}) =>
    MechanisticLedgerEvent(
      id: id,
      kind: MechanisticLedgerEventKind.observation,
      originalTimestamp: '2026-01-01T00:00:00.000Z',
      occurredAtUtc: DateTime.utc(2026),
      timezoneOffsetMinutes: 0,
      orderAtTimestamp: order,
      sourceId: 'source:a',
      revisionId: 'revision:a',
      synthetic: false,
      measurements: [_measurement(id: 'measurement_$id')],
    );
