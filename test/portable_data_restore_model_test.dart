import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/portable_data_restore.dart';

void main() {
  test('frozen state keeps its original witness and reserved record IDs', () {
    const canonical =
        '{"activeDrugIds":["drug-active","drug-taken"],'
        '"eventHistory":[{"event_type":"meal","record_id":"meal-deleted"},'
        '{"event_type":"intake","record_id":"intake-deleted"},'
        '{"event_type":"intake","record_id":"intake-live"}],'
        '"intakes":[{"drugId":"drug-taken","id":"intake-live"}],'
        '"meals":[{"id":"meal-live","missing":true,"raw":999,"value":null,"zero":0}],'
        '"profile":{"patientId":"synthetic-owner"}}';
    final source = Map<String, Object?>.from(jsonDecode(canonical) as Map)
      ..['portableRestoreReceipt'] = {'operationId': 'excluded-metadata'};
    final state = PortableDataRestoreState(source);
    final originalDigest = portableRestoreDigest(jsonDecode(canonical));
    expect(state.canonicalJson, canonical);
    expect(
      state.digest,
      'b0cbd21ffba9044693507d4c02313d5682403954b687e18321b8ba0b84cb57d6',
    );
    expect(state.digest, originalDigest);
    expect(state.json.containsKey('portableRestoreReceipt'), isFalse);

    // Caller-owned maps, JSON views and returned ID sets must not mutate the
    // snapshot that binds prepare/commit, including deleted-history conflicts.
    (source['meals'] as List).clear();
    (source['activeDrugIds'] as List).clear();
    final view = state.json;
    ((view['meals'] as List).single as Map)['value'] = 0;
    (view['eventHistory'] as List).clear();
    final ids = state.recordIds;
    expect(ids, {
      'medication_selections.json': {'drug-active', 'drug-taken'},
      'intakes.json': {'intake-live', 'intake-deleted'},
      'meals.json': {'meal-live', 'meal-deleted'},
    });
    ids['meals.json']!.clear();
    expect(state.recordIds['meals.json'], {'meal-live', 'meal-deleted'});
    expect(state.canonicalJson, canonical);
    expect(state.digest, originalDigest);
    expect(((state.json['meals'] as List).single as Map)['value'], isNull);
    expect(((state.json['meals'] as List).single as Map)['raw'], 999);
  });

  test('canonical byte witness preserves the prior JSON round-trip digest', () {
    for (final value in [
      null,
      0,
      -0.0,
      1.0,
      0.0000001,
      1e20,
      'Synthetic 中文 \\ " \n 😀',
      {
        'z': [null, false, 0],
        'a': <String, Object?>{},
      },
    ]) {
      final state = PortableDataRestoreState({'syntheticValue': value});
      expect(state.digest, portableRestoreDigest(state.json));
    }
  });
}
