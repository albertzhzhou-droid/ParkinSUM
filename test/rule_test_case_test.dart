import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/cdss_runtime.dart';
import 'package:parkinsum_companion/domain/entities/rule_test_case.dart';

void main() {
  late RuleTestRuleSet rules;
  late RuleTestCase seed;
  setUp(() {
    rules = RuleTestRuleSet.baseline();
    seed = RuleTestCase.seed(ruleSet: rules);
  });

  test(
    'baseline package and case round trip without inventing expectations',
    () {
      final restoredRules = RuleTestRuleSet.decode(rules.encode());
      final restored = RuleTestCase.decode(seed.encode());
      expect(restoredRules.toJson(), rules.toJson());
      expect(restored.toJson(), seed.toJson());
      expect(restored.caseDigest, seed.caseDigest);
      expect(restored.inputDigest, seed.inputDigest);
      expect(
        restored.context.userProfile.patientId,
        ruleTestSyntheticPatientId,
      );
      expect(restored.context.drug.dailyDoseMg, isNull);
      expect(restored.expected.hasAssertions, isFalse);
    },
  );

  test('same version with changed content has a different binding', () {
    final raw = _raw(rules);
    (raw.first['then'] as Map)['severity'] = 'changed-severity';
    final changed = RuleTestRuleSet(
      source: rules.source,
      bundleVersion: rules.bundleVersion,
      rawRules: raw,
    );
    expect(changed.ruleVersions, rules.ruleVersions);
    expect(changed.contentDigest, isNot(rules.contentDigest));
    expect(changed.binding.matches(seed.binding), isFalse);
    final tampered = rules.toJson();
    ((tampered['rules'] as List).first['then'] as Map)['severity'] =
        'changed-severity';
    expect(() => RuleTestRuleSet.fromJson(tampered), throwsFormatException);
    final forgedVersions = rules.toJson();
    ((forgedVersions['binding'] as Map)['rule_versions']
            as Map)[rules.ruleVersions.keys.first] =
        '0';
    expect(
      () => RuleTestRuleSet.fromJson(forgedVersions),
      throwsFormatException,
    );
  });

  test(
    'historical and draft packages use supplied content rather than baseline',
    () {
      final rule = _raw(rules).first;
      rule['rule_id'] = 'historical.example';
      rule['version'] = '0.4';
      rule['status'] = 'draft';
      final historical = RuleTestRuleSet(
        source: 'local_draft',
        bundleVersion: 'old-bundle',
        rawRules: [rule],
      );
      expect(RuleTestRuleSet.decode(historical.encode()).ruleVersions, {
        'historical.example': '0.4',
      });
      expect(historical.rawRules.single['status'], 'draft');
    },
  );

  test('models defensively freeze nested rules, input and expectations', () {
    final raw = _raw(rules);
    final imported = RuleTestRuleSet(
      source: 'draft',
      bundleVersion: '1',
      rawRules: raw,
    );
    final digest = imported.contentDigest;
    (raw.first['then'] as Map)['severity'] = 'outside mutation';
    expect(imported.contentDigest, digest);
    expect(
      imported.rawRules.first['then']['severity'],
      isNot('outside mutation'),
    );
    expect(
      () => imported.rawRules.first['then']['severity'] = 'x',
      throwsUnsupportedError,
    );
    expect(
      () => seed.context.drug.activeIngredients.add('x'),
      throwsUnsupportedError,
    );
    expect(
      () => seed.context.userProfile.contentJurisdictionOverride.add('x'),
      throwsUnsupportedError,
    );
    final e = RuleTestExpectations(
      missingFieldsByRule: {rules.ruleVersions.keys.first: []},
    );
    expect(
      () => e.missingFieldsByRule.values.first.add('dose'),
      throwsUnsupportedError,
    );
    final json = seed.toJson();
    json['context']['drug']['generic_name'] = 'external edit';
    expect(seed.context.drug.genericName, 'carbidopa/levodopa');
  });

  test('canonical digest ignores object key insertion order', () {
    final reversed = _raw(rules)
        .map(
          (r) => Map<String, dynamic>.fromEntries(r.entries.toList().reversed),
        )
        .toList();
    final second = RuleTestRuleSet(
      source: rules.source,
      bundleVersion: rules.bundleVersion,
      rawRules: reversed,
    );
    expect(second.contentDigest, rules.contentDigest);
  });

  test(
    'portable digests normalize numeric equality without node collisions',
    () {
      expect(ruleTestJsonDigest('test', 1), ruleTestJsonDigest('test', 1.0));
      expect(ruleTestJsonDigest('test', 0), ruleTestJsonDigest('test', -0.0));
      expect(
        ruleTestJsonDigest('test', {'a': 0.1, 'b': 1}),
        ruleTestJsonDigest('test', {'b': 1.0, 'a': 0.1}),
      );
      final shapes = <Object?>[
        null,
        true,
        'true',
        1,
        '1',
        ['number', '3ff0000000000000'],
        {'number': '3ff0000000000000'},
        [],
        {},
      ];
      expect(
        shapes.map((v) => ruleTestJsonDigest('test', v)).toSet().length,
        shapes.length,
      );
      for (final number in [
        double.nan,
        double.infinity,
        9007199254740992,
        -9007199254740992,
      ]) {
        expect(() => ruleTestJsonDigest('test', number), throwsFormatException);
      }
      expect(
        () => ruleTestJsonDigest('test', 9007199254740991),
        returnsNormally,
      );
      expect(
        ruleTestJsonDigest('test', 5e-324),
        isNot(ruleTestJsonDigest('test', 0)),
      );
      final raw = _raw(rules);
      raw.first['when']['all'][1]['cmp']['value'] = 10.0;
      final equal = RuleTestRuleSet(
        source: rules.source,
        bundleVersion: rules.bundleVersion,
        rawRules: raw,
      );
      expect(equal.contentDigest, rules.contentDigest);
      expect(
        equal.binding.canonicalizationProfile,
        ruleTestCanonicalizationProfile,
      );
    },
  );

  test('portable profile matches independently checked VM and web vectors', () {
    const domain = 'independent-portability-vector';
    expect(
      ruleTestJsonDigest(domain, 1),
      '11dd1ed7a2b1c23abec77554a4a29c5d340e97471cd9306a1965fc8bae29d7af',
    );
    expect(
      ruleTestJsonDigest(domain, {
        'a': 1,
        'b': [2, null, true],
      }),
      '489c01a52a2b61ab777374d56e59de4dcfddd752b946a953ac4e82f8322fd6c2',
    );
    expect(
      ruleTestJsonDigest(domain, jsonDecode('5e-324')),
      'd1812ab54dd824a981c9a4957e5e021c288da4ac08f03d5bb2003e3473247253',
    );
    expect(
      ruleTestJsonDigest(domain, '\u{1f600}'),
      '5d15138eda26f6df43c6a75aca90032f363a55d8f970c63ba212801e35aabb10',
    );
  });

  test(
    'malformed Unicode is rejected while supplementary pairs round trip',
    () {
      for (final malformed in [
        String.fromCharCode(0xd800),
        String.fromCharCode(0xdc00),
        '${String.fromCharCode(0xd800)}x',
      ]) {
        expect(() => seed.copyWith(title: malformed), throwsFormatException);
        expect(
          () => ruleTestJsonDigest('test', {malformed: 'value'}),
          throwsFormatException,
        );
      }
      final unicode = seed.copyWith(title: 'Synthetic \u{1f9ea}');
      expect(RuleTestCase.decode(unicode.encode()).title, unicode.title);
    },
  );

  test('full package envelope budget guarantees its own export can import', () {
    List<Map<String, dynamic>> manyRules(int idLength) => [
      for (var i = 0; i < 128; i++)
        {
          ..._raw(rules).first,
          'rule_id': 'r$i${'x' * idLength}',
          'when': {
            'exists': {'path': 'meal.id'},
          },
          'then': {
            'decision': 'INFO',
            'severity': 'low',
            'messages': {'zh': 'Synthetic'},
          },
          'provenance': {
            'evidence_level': 'synthetic',
            'source_refs': <String>[],
          },
        },
    ];
    final over = manyRules(1200);
    expect(
      utf8.encode(jsonEncode(over)).length,
      lessThan(ruleTestMaxJsonBytes),
    );
    expect(
      () =>
          RuleTestRuleSet(source: 'budget', bundleVersion: '1', rawRules: over),
      throwsFormatException,
    );
    final within = RuleTestRuleSet(
      source: 'budget',
      bundleVersion: '1',
      rawRules: manyRules(500),
    );
    expect(
      utf8.encode(within.encode()).length,
      lessThanOrEqualTo(ruleTestMaxJsonBytes),
    );
    expect(
      RuleTestRuleSet.decode(within.encode()).contentDigest,
      within.contentDigest,
    );
  });

  test('empty target assertion differs from no assertions', () {
    expect(RuleTestExpectations().hasAssertions, isFalse);
    expect(RuleTestExpectations(targets: []).hasAssertions, isTrue);
    final copy = seed.copyWith(expected: RuleTestExpectations(targets: []));
    expect(RuleTestCase.decode(copy.encode()).expected.targets, isEmpty);
    expect(copy.caseDigest, isNot(seed.caseDigest));
    expect(copy.inputDigest, seed.inputDigest);
  });

  test(
    'unknown bound rule references and duplicate target or rule IDs reject',
    () {
      expect(
        () => RuleTestRuleSet(
          source: 'x',
          bundleVersion: '1',
          rawRules: [_raw(rules).first, _raw(rules).first],
        ),
        throwsFormatException,
      );
      expect(
        () => seed.copyWith(
          expected: RuleTestExpectations(missingFieldsByRule: {'absent': []}),
        ),
        throwsFormatException,
      );
      expect(
        () => seed.copyWith(
          expected: RuleTestExpectations(
            targets: [
              RuleTestTargetExpectation(
                target: 'drug-meal',
                decision: RuntimeDecisionType.warn,
                winningRuleIds: ['absent'],
              ),
            ],
          ),
        ),
        throwsFormatException,
      );
      expect(
        () => RuleTestTargetExpectation(
          target: 't',
          decision: RuntimeDecisionType.warn,
          winningRuleIds: ['same', 'same'],
        ),
        throwsFormatException,
      );
      final target = RuleTestTargetExpectation(
        target: 'same',
        decision: RuntimeDecisionType.warn,
        winningRuleIds: [],
      );
      expect(
        () => RuleTestExpectations(targets: [target, target]),
        throwsFormatException,
      );
      expect(
        () => RuleTestExpectations(
          missingFieldsByRule: {
            'rule': ['dose', 'dose'],
          },
        ),
        throwsFormatException,
      );
      expect(
        () => RuleTestExpectations(
          missingFieldsByRule: {
            'rule': ['invented_field'],
          },
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'nulls and separate dose fields survive without inferring a daily regimen',
    () {
      final json = seed.toJson();
      json['context']['drug']['administration_dose_value'] = 0.25;
      json['context']['drug']['administration_dose_unit'] = 'g';
      json['context']['drug']['daily_dose_mg'] = null;
      json['context']['timestamps']['drug_time'] = null;
      json['context']['meal'] = null;
      final restored = RuleTestCase.fromJson(json);
      expect(restored.context.drug.administrationDoseValue, 0.25);
      expect(restored.context.drug.administrationDoseUnit, 'g');
      expect(restored.context.drug.dailyDoseMg, isNull);
      expect(restored.context.timestamps.drugTime, isNull);
      expect(restored.context.meal, isNull);
    },
  );

  test(
    'offset timestamps preserve their instant and reject calendar normalization',
    () {
      final json = seed.toJson();
      json['context']['timestamps']['drug_time'] = '2026-01-01T03:00:00-05:00';
      expect(
        RuleTestCase.fromJson(json).context.timestamps.drugTime,
        DateTime.utc(2026, 1, 1, 8),
      );
      for (final invalid in [
        '2026-01-01T08:00:00',
        '2026-02-30T08:00:00Z',
        '2026-01-01T24:00:00Z',
        '2026-01-01T08:00:00+14:30',
        '2026-01-01T08:00:60Z',
        '2026-01-01',
        '9999-12-31T23:59:59-14:00',
        '0001-01-01T00:00:00+14:00',
        '0000-01-01T00:00:00Z',
      ]) {
        json['context']['timestamps']['drug_time'] = invalid;
        expect(
          () => RuleTestCase.fromJson(json),
          throwsFormatException,
          reason: invalid,
        );
      }
    },
  );

  test('unknown keys, wrong types and a real patient identifier reject', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (j) => j['unknown'] = 1,
      (j) => j['schema_version'] = 1.0,
      (j) => j['synthetic_only'] = false,
      (j) => j['context']['user_profile']['patient_id'] = 'patient_42',
      (j) => j['context']['drug']['dose_units'] = 'mg',
      (j) => j['context']['drug']['administration_dose_unit'] = 'tablet',
      (j) => j['context']['drug']['daily_dose_mg'] = '250',
      (j) => j['context']['drug']['daily_dose_mg'] = double.infinity,
      (j) => j['context']['meal']['protein_g'] = -1,
      (j) => j['context']['meal']['high_fat_high_calorie'] = 0,
      (j) => j['expected']['unexpected'] = true,
    ];
    for (final mutation in mutations) {
      final json = seed.toJson();
      mutation(json);
      expect(() => RuleTestCase.fromJson(json), throwsFormatException);
    }
  });

  test(
    'package validation rejects permissive compiler traps before execution',
    () {
      final mutations = <void Function(Map<String, dynamic>)>[
        (r) => r['unknown'] = true,
        (r) => r['status'] = 'invented',
        (r) => r['priority_band'] = 1.5,
        (r) => r['then']['decision'] = 'INVENTED',
        (r) => r['when'] = {'any': 'bad'},
        (r) => r['when'] = {'always': true},
        (r) => r['when'] = {
          'cmp': {
            'path': 'meal.protein_g',
            'op': 'gte',
            'value': 10,
            'typo': 1,
          },
        },
        (r) => r['when'] = {
          'cmp': {'path': 'meal.protein_typo', 'op': 'gte', 'value': 10},
        },
        (r) => r['when'] = {
          'cmp': {'path': 'meal.protein_g', 'op': 'made_up', 'value': 10},
        },
        (r) => r['when'] = {
          'between': {
            'left_path': 'timestamps.drug_time',
            'right_path': 'timestamps.meal_time',
            'unit': 'seconds',
            'low': 0,
            'high': 1,
          },
        },
        (r) => r['when'] = {
          'dose_band': {
            'path': 'drug.daily_dose_mg',
            'unit': 'pills',
            'op': 'gte',
            'threshold': 1,
          },
        },
        (r) => r['then']['messages']['unknown_long_key'] = 'ignored',
        (r) => r['provenance']['effective_from'] = '2026-02-30',
      ];
      for (final mutation in mutations) {
        final rule = _raw(rules).first;
        mutation(rule);
        expect(
          () => RuleTestRuleSet(
            source: 'test',
            bundleVersion: '1',
            rawRules: [rule],
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'dose bands reject unsupported dimensions and ambiguous engine conversions',
    () {
      final bad = <Map<String, dynamic>>[
        {
          'path': 'drug.daily_dose_mg',
          'unit': 'g',
          'op': 'gte',
          'threshold': 0.2,
        },
        {
          'path': 'drug.daily_dose_mg',
          'unit': 'mg',
          'op': 'gte',
          'threshold': 50,
        },
        {
          'path': 'drug.administration_dose_value',
          'unit': 'g',
          'low': 0.09,
          'high': 0.11,
        },
        {
          'path': 'drug.administration_dose_value',
          'unit': 'mg',
          'value_unit': 'g',
          'op': 'gte',
          'threshold': 50,
        },
        {
          'path': 'coevent.supplements.dose',
          'unit': 'mg',
          'op': 'gte',
          'threshold': 50,
        },
      ];
      for (final config in bad) {
        final raw = _raw(rules).first..['when'] = {'dose_band': config};
        expect(
          () => RuleTestRuleSet(
            source: 'unit',
            bundleVersion: '1',
            rawRules: [raw],
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('payload size, depth and cyclic in-memory input are bounded', () {
    expect(
      () => RuleTestCase.decode(' ' * (ruleTestMaxJsonBytes + 1)),
      throwsFormatException,
    );
    expect(
      () => RuleTestRuleSet.decode('${'[' * 30}0${']' * 30}'),
      throwsFormatException,
    );
    final json = seed.toJson();
    final cycle = <String, dynamic>{};
    cycle['cycle'] = cycle;
    json['context']['coevent'] = cycle;
    expect(() => RuleTestCase.fromJson(json), throwsFormatException);
    final overlong = seed.toJson();
    overlong['title'] = 'x' * 4097;
    expect(() => RuleTestCase.fromJson(overlong), throwsFormatException);
    expect(
      () => RuleTestCase.decode(jsonEncode([seed.toJson()])),
      throwsFormatException,
    );
  });
}

List<Map<String, dynamic>> _raw(RuleTestRuleSet rules) =>
    (rules.toJson()['rules'] as List).cast<Map<String, dynamic>>();
