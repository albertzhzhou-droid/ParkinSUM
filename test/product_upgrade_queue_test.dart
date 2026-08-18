import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/product_upgrade_queue.dart';

void main() {
  test('committed complete-app queue parses with scored active work', () {
    final queue = ProductUpgradeQueue.fromJsonText(
      File('config/complete_app_upgrade_queue.json').readAsStringSync(),
    );

    expect(queue.schemaVersion, 1);
    expect(queue.activeItems, isNotEmpty);
    expect(
      queue.items.where(
        (item) => item.status == ProductUpgradeStatus.researchRequired,
      ),
      isNotEmpty,
    );
    expect(
      queue.items.where(
        (item) => item.status == ProductUpgradeStatus.externalDependency,
      ),
      isNotEmpty,
    );
    for (final item in queue.items) {
      expect(item.score, (item.impact + item.risk) * (6 - item.effort));
    }
  });

  test('invalid status and score drift fail closed', () {
    const base = '''
{"schemaVersion":1,"reviewedAt":"2026-08-17","productMode":"test","scoringFormula":"x","boundary":"no clinical validation","items":[{"id":"one","title":"One","area":"test","status":"queued","priority":"P1","impact":5,"risk":4,"effort":3,"score":27,"currentGap":"gap","evidenceUrls":[],"dependencies":[],"acceptanceCriteria":["a","b"]}]}
''';
    expect(() => ProductUpgradeQueue.fromJsonText(base), returnsNormally);
    expect(
      () => ProductUpgradeQueue.fromJsonText(
        base.replaceFirst('"queued"', '"mystery"'),
      ),
      throwsFormatException,
    );
    expect(
      () => ProductUpgradeQueue.fromJsonText(
        base.replaceFirst('"score":27', '"score":26'),
      ),
      throwsFormatException,
    );
  });
}
