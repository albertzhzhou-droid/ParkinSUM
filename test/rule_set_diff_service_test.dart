import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/rule_set_diff.dart';
import 'package:parkinsum_companion/domain/usecases/rule_set_diff_service.dart';

Map<String, Object?> _rule(String id, {String version = '1'}) => {
  'rule_id': id,
  'version': version,
  'status': 'draft',
  'jurisdiction': ['GLOBAL'],
  'when': {'exists': 'meal.time'},
  'provenance': {
    'source_refs': ['source-a'],
    'evidence_level': 'prototype',
  },
};

void main() {
  const service = RuleSetDiffService();

  test(
    'reports complete provenance, lifecycle, jurisdiction and logic paths',
    () {
      final after = _rule('a', version: '2')
        ..['status'] = 'active'
        ..['jurisdiction'] = ['CA']
        ..['when'] = {'exists': 'meal.protein'}
        ..['provenance'] = {
          'source_refs': ['source-b'],
          'evidence_level': 'review',
        };
      final report = service.compare(
        beforeRules: [_rule('a')],
        afterRules: [after],
      );
      expect(report.toJson()['schema_version'], ruleSetDiffReportSchemaVersion);
      expect(report.changedRuleIds, ['a']);
      expect(report.changes.single.fields.map((field) => field.path), [
        '/jurisdiction/0',
        '/provenance/evidence_level',
        '/provenance/source_refs/0',
        '/status',
        '/version',
        '/when/exists',
      ]);
      expect(report.warnings, isEmpty);
      expect(report.changes.single.beforeVersion, '1');
      expect(report.changes.single.afterVersion, '2');
    },
  );

  test('added and removed rules retain complete snapshots and stable IDs', () {
    final report = service.compare(
      beforeRules: [_rule('kept'), _rule('removed')],
      afterRules: [_rule('added'), _rule('kept')],
    );
    expect(report.addedRuleIds, ['added']);
    expect(report.removedRuleIds, ['removed']);
    expect(report.changedRuleIds, isEmpty);
    expect(report.unchangedRuleIds, ['kept']);
    final added = report.changes.first.fields.single;
    expect(added.path, '');
    expect(added.beforePresent, isFalse);
    expect(added.beforeValue, isNull);
    expect(added.afterPresent, isTrue);
    expect(added.afterValue, _rule('added'));
    final removed = report.changes.last.fields.single;
    expect(removed.beforePresent, isTrue);
    expect(removed.afterPresent, isFalse);
    expect(report.ruleOrderChanged, isTrue);
    expect(report.beforeRuleOrder, ['kept', 'removed']);
  });

  test('null, missing and pointer escaping are never conflated', () {
    final before = _rule('a')
      ..['when'] = {
        'a/b': {'~marker': null},
        'removed': null,
      };
    final after = _rule('a')
      ..['when'] = {
        'a/b': {'~marker': false},
        'added': null,
      };
    final report = service.compare(beforeRules: [before], afterRules: [after]);
    final fields = {
      for (final field in report.changes.single.fields) field.path: field,
    };
    expect(fields.keys, [
      '/when/a~1b/~0marker',
      '/when/added',
      '/when/removed',
    ]);
    expect(fields['/when/added']!.beforePresent, isFalse);
    expect(fields['/when/added']!.afterPresent, isTrue);
    expect(fields['/when/added']!.afterValue, isNull);
    expect(fields['/when/removed']!.beforePresent, isTrue);
    expect(fields['/when/removed']!.afterPresent, isFalse);
    expect(fields['/when/removed']!.beforeValue, isNull);
    expect(report.warnings.single.code, 'same_version_different_content');
    expect(report.changes.single.sameVersionDifferentContent, isTrue);
  });

  test(
    'all arrays retain order including an otherwise unchanged rule array',
    () {
      final reordered = service.compare(
        beforeRules: [_rule('a'), _rule('b')],
        afterRules: [_rule('b'), _rule('a')],
      );
      expect(reordered.hasChanges, isTrue);
      expect(reordered.ruleOrderChanged, isTrue);
      expect(reordered.changes, isEmpty);
      expect(reordered.unchangedRuleIds, ['a', 'b']);
      final before = _rule('a')..['jurisdiction'] = ['GLOBAL', 'CA'];
      final after = _rule('a')..['jurisdiction'] = ['CA', 'GLOBAL', null];
      final nested = service.compare(
        beforeRules: [before],
        afterRules: [after],
      );
      expect(nested.changes.single.fields.map((field) => field.path), [
        '/jurisdiction/0',
        '/jurisdiction/1',
        '/jurisdiction/2',
      ]);
      expect(nested.changes.single.fields.last.beforePresent, isFalse);
      expect(nested.changes.single.fields.last.afterPresent, isTrue);
      expect(nested.changes.single.fields.last.afterValue, isNull);
    },
  );

  test(
    'object ordering is ignored while numeric JSON representations differ',
    () {
      final before = _rule('a')..['extra'] = {'x': 1, 'y': true};
      final same = Map<String, Object?>.fromEntries(
        before.entries.toList().reversed,
      )..['extra'] = {'y': true, 'x': 1};
      expect(
        service.compare(beforeRules: [before], afterRules: [same]).hasChanges,
        isFalse,
      );
      final after = _rule('a')..['extra'] = {'x': 1.0, 'y': true};
      final report = service.compare(
        beforeRules: [before],
        afterRules: [after],
      );
      expect(report.changes.single.fields.single.path, '/extra/x');
      expect(jsonEncode(report.changes.single.fields.single.beforeValue), '1');
      expect(jsonEncode(report.changes.single.fields.single.afterValue), '1.0');
      expect(report.warnings.single.code, 'same_version_different_content');
      final reorderedBefore = Map<String, Object?>.fromEntries(
        before.entries.toList().reversed,
      );
      expect(
        jsonEncode(
          service
              .compare(beforeRules: [reorderedBefore], afterRules: [after])
              .toJson(),
        ),
        jsonEncode(report.toJson()),
      );
    },
  );

  test(
    'missing versions are reported without inventing version continuity',
    () {
      final before = _rule('a')..remove('version');
      final after = _rule('a')
        ..remove('version')
        ..['status'] = 'active';
      final report = service.compare(
        beforeRules: [before],
        afterRules: [after],
      );
      expect(report.changes.single.sameVersionDifferentContent, isFalse);
      expect(
        report.warnings.single.code,
        'changed_rule_without_comparable_version',
      );
    },
  );

  test('report snapshots stay immutable after callers mutate input', () {
    final sources = <Object?>['source-original'];
    final after = _rule('a')..['provenance'] = {'source_refs': sources};
    final report = service.compare(beforeRules: [], afterRules: [after]);
    sources[0] = 'changed later';
    after['status'] = 'active';
    final snapshot = report.changes.single.afterRule!;
    expect(snapshot['status'], 'draft');
    final provenance = snapshot['provenance']! as Map<String, Object?>;
    expect(provenance['source_refs'], ['source-original']);
    expect(() => snapshot.clear(), throwsUnsupportedError);
    expect(
      () => (provenance['source_refs']! as List).clear(),
      throwsUnsupportedError,
    );
    expect(() => report.changes.clear(), throwsUnsupportedError);
    expect(() => report.addedRuleIds.clear(), throwsUnsupportedError);
    expect(() => report.changes.single.fields.clear(), throwsUnsupportedError);
  });

  test(
    'duplicate IDs, non-JSON types, non-string keys and cycles fail closed',
    () {
      expect(
        () => service.compare(
          beforeRules: [_rule('a'), _rule('a')],
          afterRules: [],
        ),
        throwsFormatException,
      );
      for (final invalid in [
        DateTime.utc(2026),
        double.nan,
        double.infinity,
        BigInt.one,
        {1: 'bad key'},
      ]) {
        expect(
          () => service.compare(
            beforeRules: [],
            afterRules: [_rule('a')..['value'] = invalid],
          ),
          throwsFormatException,
        );
      }
      for (final id in ['', ' ', 'bad\nidentifier']) {
        expect(
          () => service.compare(beforeRules: [_rule(id)], afterRules: []),
          throwsFormatException,
        );
      }
      final cycle = <String, Object?>{};
      cycle['self'] = cycle;
      expect(
        () => service.compare(
          beforeRules: [],
          afterRules: [_rule('a')..['cycle'] = cycle],
        ),
        throwsFormatException,
      );
    },
  );

  test('UTF-8 payload limit counts both complete arrays and JSON escaping', () {
    final before = <Map<String, Object?>>[
      {'rule_id': 'a', 'text': '中文\n"'},
    ];
    final after = <Map<String, Object?>>[
      {'rule_id': 'a', 'text': '中文\n"'},
    ];
    final exactBytes =
        utf8.encode(jsonEncode(before)).length +
        utf8.encode(jsonEncode(after)).length;
    expect(
      service
          .compare(
            beforeRules: before,
            afterRules: after,
            limits: RuleSetDiffLimits(maxPayloadBytes: exactBytes),
          )
          .hasChanges,
      isFalse,
    );
    expect(
      () => service.compare(
        beforeRules: before,
        afterRules: after,
        limits: RuleSetDiffLimits(maxPayloadBytes: exactBytes - 1),
      ),
      throwsFormatException,
    );
  });

  test(
    'rule, node, depth, string and output limits reject instead of truncate',
    () {
      final before = [_rule('a')];
      final changed = [
        _rule('a')
          ..['status'] = 'active'
          ..['version'] = '2',
      ];
      expect(
        () => service.compare(
          beforeRules: before,
          afterRules: [_rule('a'), _rule('b')],
          limits: const RuleSetDiffLimits(maxRules: 1),
        ),
        throwsFormatException,
      );
      for (final limits in [
        const RuleSetDiffLimits(maxNodes: 2),
        const RuleSetDiffLimits(maxDepth: 1),
        const RuleSetDiffLimits(maxStringLength: 1),
        const RuleSetDiffLimits(maxFieldChanges: 1),
      ]) {
        expect(
          () => service.compare(
            beforeRules: before,
            afterRules: changed,
            limits: limits,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => service.compare(
          beforeRules: [],
          afterRules: [],
          limits: const RuleSetDiffLimits(maxDepth: 65),
        ),
        throwsFormatException,
      );
      final empty = service.compare(beforeRules: [], afterRules: []);
      expect(empty.hasChanges, isFalse);
      expect(empty.warnings, isEmpty);
    },
  );
}
