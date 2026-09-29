import 'dart:convert';
import 'dart:typed_data';

import '../../core/constants/baseline_cdss_rules.dart';
import '../../core/security/cdss_identifier_factory.dart';
import '../usecases/rule_registry_compiler.dart';
import 'cdss_runtime.dart';
import 'runtime_context.dart';

const ruleTestSyntheticPatientId = 'synthetic_test_case';
const ruleTestCaseSchemaVersion = 1;
const ruleTestRuleSetSchemaVersion = 1;
const ruleTestMaxJsonBytes = 262144;
const ruleTestMaxJsonDepth = 24;
const ruleTestCanonicalizationProfile = 'synthetic-json-binary64-v1';

/// A content binding, not a claim that a rule package has been approved.
final class RuleTestRuleBinding {
  final String source;
  final String bundleVersion;
  final String contentDigest;
  final Map<String, String> ruleVersions;
  String get canonicalizationProfile => ruleTestCanonicalizationProfile;

  factory RuleTestRuleBinding({
    required String source,
    required String bundleVersion,
    required String contentDigest,
    required Map<String, String> ruleVersions,
  }) => RuleTestRuleBinding.fromJson({
    'source': source,
    'bundle_version': bundleVersion,
    'content_digest': contentDigest,
    'rule_versions': ruleVersions,
    'canonicalization_profile': ruleTestCanonicalizationProfile,
  });

  RuleTestRuleBinding._(
    this.source,
    this.bundleVersion,
    this.contentDigest,
    this.ruleVersions,
  );

  factory RuleTestRuleBinding.fromJson(Map<String, dynamic> json) {
    _bounded(json);
    _keys(json, {
      'source',
      'bundle_version',
      'content_digest',
      'rule_versions',
      'canonicalization_profile',
    });
    if (json['canonicalization_profile'] != ruleTestCanonicalizationProfile) {
      throw const FormatException('Unsupported canonicalization profile.');
    }
    final digest = _text(json['content_digest'], 'content_digest');
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)) {
      throw const FormatException('content_digest must be a SHA-256 digest.');
    }
    final versions = _map(json['rule_versions'], 'rule_versions');
    if (versions.length > 128) throw const FormatException('Too many rules.');
    return RuleTestRuleBinding._(
      _text(json['source'], 'source'),
      _text(json['bundle_version'], 'bundle_version'),
      digest,
      Map.unmodifiable({
        for (final entry in versions.entries)
          _text(entry.key, 'rule_id'): _text(entry.value, 'rule_version'),
      }),
    );
  }

  bool matches(RuleTestRuleBinding other) =>
      source == other.source &&
      bundleVersion == other.bundleVersion &&
      contentDigest == other.contentDigest &&
      ruleVersions.length == other.ruleVersions.length &&
      ruleVersions.entries.every((e) => other.ruleVersions[e.key] == e.value);

  Map<String, dynamic> toJson() => {
    'source': source,
    'bundle_version': bundleVersion,
    'content_digest': contentDigest,
    'rule_versions': Map<String, String>.from(ruleVersions),
    'canonicalization_profile': ruleTestCanonicalizationProfile,
  };
}

/// Immutable rules explicitly selected for isolated simulation. All included
/// statuses are preserved. The runner's explicit execution mode decides which
/// are simulated. Import never installs rules in a patient service.
final class RuleTestRuleSet {
  final RuleTestRuleBinding binding;
  final List<Map<String, dynamic>> rawRules;

  String get source => binding.source;
  String get bundleVersion => binding.bundleVersion;
  String get contentDigest => binding.contentDigest;
  Map<String, String> get ruleVersions => binding.ruleVersions;

  RuleTestRuleSet._(this.binding, this.rawRules);

  factory RuleTestRuleSet({
    required String source,
    required String bundleVersion,
    required List<Map<String, dynamic>> rawRules,
  }) {
    _bounded(rawRules);
    if (rawRules.length > 128) throw const FormatException('Too many rules.');
    final versions = <String, String>{};
    for (final rule in rawRules) {
      _validateRule(rule);
      final id = rule['rule_id'] as String;
      if (versions.containsKey(id)) {
        throw FormatException('Duplicate rule_id: $id');
      }
      versions[id] = rule['version'] as String;
    }
    final frozen = List<Map<String, dynamic>>.unmodifiable(
      rawRules.map((rule) => _freeze(rule) as Map<String, dynamic>),
    );
    final result = RuleTestRuleSet._(
      RuleTestRuleBinding(
        source: source,
        bundleVersion: bundleVersion,
        contentDigest: ruleTestJsonDigest('synthetic-rule-set-v1', frozen),
        ruleVersions: versions,
      ),
      frozen,
    );
    _bounded(result.toJson());
    return result;
  }

  factory RuleTestRuleSet.baseline() => RuleTestRuleSet(
    source: 'bundled_baseline',
    bundleVersion: 'baseline_cdss_rules_v1',
    rawRules: baselineCdssRules,
  );

  factory RuleTestRuleSet.fromJson(Map<String, dynamic> json) {
    _bounded(json);
    _keys(json, {'schema_version', 'synthetic_only', 'binding', 'rules'});
    _schema(json);
    final advertised = RuleTestRuleBinding.fromJson(
      _map(json['binding'], 'binding'),
    );
    final actual = RuleTestRuleSet(
      source: advertised.source,
      bundleVersion: advertised.bundleVersion,
      rawRules: _list(
        json['rules'],
        'rules',
      ).map((r) => _map(r, 'rule')).toList(),
    );
    if (!advertised.matches(actual.binding)) {
      throw const FormatException(
        'Rule package content does not match its binding.',
      );
    }
    return actual;
  }

  factory RuleTestRuleSet.decode(String source) =>
      RuleTestRuleSet.fromJson(_decode(source));

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'synthetic_only': true,
    'binding': binding.toJson(),
    'rules': _copy(rawRules),
  };

  String encode() => jsonEncode(toJson());
}

final class RuleTestTargetExpectation {
  final String target;
  final RuntimeDecisionType decision;
  final List<String> winningRuleIds;

  RuleTestTargetExpectation({
    required String target,
    required this.decision,
    required List<String> winningRuleIds,
  }) : target = _text(target, 'target'),
       winningRuleIds = List.unmodifiable(
         _strings(winningRuleIds, 'winning_rule_ids'),
       );

  factory RuleTestTargetExpectation.fromJson(Map<String, dynamic> json) {
    _keys(json, {'target', 'decision', 'winning_rule_ids'});
    return RuleTestTargetExpectation(
      target: _text(json['target'], 'target'),
      decision: _decision(json['decision']),
      winningRuleIds: _strings(json['winning_rule_ids'], 'winning_rule_ids'),
    );
  }

  Map<String, dynamic> toJson() => {
    'target': target,
    'decision': decision.wireValue,
    'winning_rule_ids': List<String>.from(winningRuleIds),
  };
}

/// Null targets means no target assertion. An empty list deliberately asserts
/// that the output contains no targets; it is a real negative test.
final class RuleTestExpectations {
  final List<RuleTestTargetExpectation>? targets;
  final Map<String, List<String>> missingFieldsByRule;

  RuleTestExpectations({
    List<RuleTestTargetExpectation>? targets,
    Map<String, List<String>> missingFieldsByRule = const {},
  }) : targets = targets == null ? null : List.unmodifiable(targets),
       missingFieldsByRule = Map.unmodifiable({
         for (final e in missingFieldsByRule.entries)
           _text(e.key, 'rule_id'): List<String>.unmodifiable(
             _strings(e.value, 'missing_fields'),
           ),
       }) {
    if (targets != null &&
        targets.map((t) => t.target).toSet().length != targets.length) {
      throw const FormatException('Duplicate expected target.');
    }
    const fields = {
      'dose',
      'administration_dose',
      'formulation',
      'time',
      'meal_time',
      'coevent_time',
      'thickener_type',
      'enteral_feed_protein',
    };
    if (this.missingFieldsByRule.values
        .expand((f) => f)
        .any((f) => !fields.contains(f))) {
      throw const FormatException('Unknown missing-input field code.');
    }
    _bounded(toJson());
  }

  factory RuleTestExpectations.fromJson(Map<String, dynamic> json) {
    _keys(json, {'targets', 'missing_fields_by_rule'});
    final missing = _map(
      json['missing_fields_by_rule'],
      'missing_fields_by_rule',
    );
    return RuleTestExpectations(
      targets: json['targets'] == null
          ? null
          : _list(json['targets'], 'targets')
                .map(
                  (t) => RuleTestTargetExpectation.fromJson(_map(t, 'target')),
                )
                .toList(),
      missingFieldsByRule: {
        for (final e in missing.entries)
          e.key: _strings(e.value, 'missing_fields'),
      },
    );
  }

  bool get hasAssertions => targets != null || missingFieldsByRule.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'targets': targets?.map((t) => t.toJson()).toList(),
    'missing_fields_by_rule': {
      for (final e in missingFieldsByRule.entries)
        e.key: List<String>.from(e.value),
    },
  };
}

final class RuleTestCase {
  final String caseId;
  final String title;
  final RuleTestRuleBinding binding;
  final UnifiedRuntimeContext context;
  final RuleTestExpectations expected;

  RuleTestCase._(
    this.caseId,
    this.title,
    this.binding,
    this.context,
    this.expected,
  );

  factory RuleTestCase({
    required String caseId,
    required String title,
    required RuleTestRuleBinding binding,
    required UnifiedRuntimeContext context,
    RuleTestExpectations? expected,
  }) => RuleTestCase.fromJson({
    'schema_version': 1,
    'synthetic_only': true,
    'case_id': caseId,
    'title': title,
    'binding': binding.toJson(),
    'context': context.toJson(),
    'expected': (expected ?? RuleTestExpectations()).toJson(),
  });

  factory RuleTestCase.fromJson(Map<String, dynamic> json) {
    _bounded(json);
    _keys(json, {
      'schema_version',
      'synthetic_only',
      'case_id',
      'title',
      'binding',
      'context',
      'expected',
    });
    _schema(json);
    final binding = RuleTestRuleBinding.fromJson(
      _map(json['binding'], 'binding'),
    );
    final expected = RuleTestExpectations.fromJson(
      _map(json['expected'], 'expected'),
    );
    final referenced = <String>{
      ...?expected.targets?.expand((target) => target.winningRuleIds),
      ...expected.missingFieldsByRule.keys,
    };
    if (referenced.any((id) => !binding.ruleVersions.containsKey(id))) {
      throw const FormatException(
        'Expected rule IDs must exist in the bound package.',
      );
    }
    final result = RuleTestCase._(
      _text(json['case_id'], 'case_id'),
      _text(json['title'], 'title'),
      binding,
      _context(_map(json['context'], 'context')),
      expected,
    );
    _bounded(result.toJson());
    return result;
  }

  factory RuleTestCase.decode(String source) =>
      RuleTestCase.fromJson(_decode(source));

  factory RuleTestCase.seed({required RuleTestRuleSet ruleSet}) => RuleTestCase(
    caseId: 'synthetic-protein-001',
    title: 'Synthetic protein rule case',
    binding: ruleSet.binding,
    context: UnifiedRuntimeContext(
      userProfile: const UserProfileRuntimeContext(
        patientId: ruleTestSyntheticPatientId,
        registrationRegion: 'US',
        displayLocale: 'en-US',
        contentJurisdictionOverride: [],
        dietProfileRegion: 'US',
        timezone: 'UTC',
      ),
      drug: const DrugRuntimeContext(
        id: 'synthetic_drug',
        genericName: 'carbidopa/levodopa',
        brandName: 'Sinemet',
        activeIngredients: ['carbidopa', 'levodopa'],
        substanceTags: ['levodopa'],
        formulation: 'tablet',
        dosageForm: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        dailyDoseMg: null,
        jurisdiction: 'US',
      ),
      meal: const MealRuntimeContext(
        id: 'synthetic_meal',
        totalProteinG: 25,
        tyramineMgEstimate: 0,
        highFatHighCalorie: false,
        itemIds: ['synthetic_food'],
      ),
      coevent: null,
      enteralFeed: null,
      timestamps: TimestampRuntimeContext(
        drugTime: DateTime.utc(2026, 1, 1, 8),
        mealTime: DateTime.utc(2026, 1, 1, 9),
        coeventTime: null,
      ),
    ),
  );

  RuleTestCase copyWith({
    String? caseId,
    String? title,
    RuleTestRuleBinding? binding,
    UnifiedRuntimeContext? context,
    RuleTestExpectations? expected,
  }) => RuleTestCase(
    caseId: caseId ?? this.caseId,
    title: title ?? this.title,
    binding: binding ?? this.binding,
    context: context ?? this.context,
    expected: expected ?? this.expected,
  );

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'synthetic_only': true,
    'case_id': caseId,
    'title': title,
    'binding': binding.toJson(),
    'context': _copy(context.toJson()),
    'expected': expected.toJson(),
  };

  String encode() => jsonEncode(toJson());
  String get caseDigest =>
      ruleTestJsonDigest('synthetic-rule-case-v1', toJson());
  String get inputDigest =>
      ruleTestJsonDigest('synthetic-rule-input-v1', context.toJson());
}

UnifiedRuntimeContext _context(Map<String, dynamic> json) {
  _keys(json, {
    'user_profile',
    'drug',
    'meal',
    'coevent',
    'enteral_feed',
    'timestamps',
  });
  final user = _map(json['user_profile'], 'user_profile');
  _keys(user, {
    'patient_id',
    'registration_region',
    'display_locale',
    'content_jurisdiction_override',
    'diet_profile_region',
    'timezone',
  });
  if (user['patient_id'] != ruleTestSyntheticPatientId) {
    throw const FormatException(
      'Only the fixed synthetic patient identifier is allowed.',
    );
  }
  final drug = _map(json['drug'], 'drug');
  _keys(
    drug,
    {
      'id',
      'generic_name',
      'brand_name',
      'active_ingredients',
      'substance_tags',
      'formulation',
      'dosage_form',
      'route',
      'release_type',
      'daily_dose_mg',
      'jurisdiction',
    },
    optional: {'administration_dose_value', 'administration_dose_unit'},
  );
  final doseUnit = _nullableText(
    drug['administration_dose_unit'],
    'administration_dose_unit',
  );
  if (doseUnit != null && !_massUnits.contains(doseUnit)) {
    throw const FormatException('Unsupported administration dose unit.');
  }
  MealRuntimeContext? meal;
  if (json['meal'] != null) {
    final m = _map(json['meal'], 'meal');
    _keys(m, {
      'id',
      'protein_g',
      'tyramine_mg_est',
      'high_fat_high_calorie',
      'item_ids',
    });
    meal = MealRuntimeContext(
      id: _text(m['id'], 'meal.id'),
      totalProteinG: _number(m['protein_g'], 'protein_g'),
      tyramineMgEstimate: _number(m['tyramine_mg_est'], 'tyramine_mg_est'),
      highFatHighCalorie: _boolean(
        m['high_fat_high_calorie'],
        'high_fat_high_calorie',
      ),
      itemIds: List.unmodifiable(_strings(m['item_ids'], 'item_ids')),
    );
  }
  CoeventRuntimeContext? coevent;
  if (json['coevent'] != null) {
    final c = _map(json['coevent'], 'coevent');
    _keys(c, {'substance_tags', 'supplements', 'thickener_type'});
    coevent = CoeventRuntimeContext(
      substanceTags: List.unmodifiable(
        _strings(c['substance_tags'], 'substance_tags'),
      ),
      supplements:
          _freeze(_map(c['supplements'], 'supplements'))
              as Map<String, dynamic>,
      thickenerType: _nullableText(c['thickener_type'], 'thickener_type'),
    );
  }
  EnteralFeedRuntimeContext? feed;
  if (json['enteral_feed'] != null) {
    final f = _map(json['enteral_feed'], 'enteral_feed');
    _keys(f, {'mode', 'formula', 'protein_g_per_day'});
    feed = EnteralFeedRuntimeContext(
      mode: _text(f['mode'], 'mode'),
      formula: _nullableText(f['formula'], 'formula'),
      proteinGPerDay: _nullableNumber(
        f['protein_g_per_day'],
        'protein_g_per_day',
      ),
    );
  }
  final times = _map(json['timestamps'], 'timestamps');
  _keys(times, {'drug_time', 'meal_time', 'coevent_time'});
  return UnifiedRuntimeContext(
    userProfile: UserProfileRuntimeContext(
      patientId: ruleTestSyntheticPatientId,
      registrationRegion: _text(
        user['registration_region'],
        'registration_region',
      ),
      displayLocale: _text(user['display_locale'], 'display_locale'),
      contentJurisdictionOverride: List.unmodifiable(
        _strings(
          user['content_jurisdiction_override'],
          'content_jurisdiction_override',
        ),
      ),
      dietProfileRegion: _nullableText(
        user['diet_profile_region'],
        'diet_profile_region',
      ),
      timezone: _text(user['timezone'], 'timezone'),
    ),
    drug: DrugRuntimeContext(
      id: _text(drug['id'], 'drug.id'),
      genericName: _text(drug['generic_name'], 'generic_name'),
      brandName: _nullableText(drug['brand_name'], 'brand_name'),
      activeIngredients: List.unmodifiable(
        _strings(drug['active_ingredients'], 'active_ingredients'),
      ),
      substanceTags: List.unmodifiable(
        _strings(drug['substance_tags'], 'substance_tags'),
      ),
      formulation: _text(drug['formulation'], 'formulation', empty: true),
      dosageForm: _text(drug['dosage_form'], 'dosage_form', empty: true),
      route: _text(drug['route'], 'route', empty: true),
      releaseType: _text(drug['release_type'], 'release_type', empty: true),
      administrationDoseValue: _nullableNumber(
        drug['administration_dose_value'],
        'administration_dose_value',
      ),
      administrationDoseUnit: doseUnit,
      dailyDoseMg: _nullableNumber(drug['daily_dose_mg'], 'daily_dose_mg'),
      jurisdiction: _nullableText(drug['jurisdiction'], 'jurisdiction'),
    ),
    meal: meal,
    coevent: coevent,
    enteralFeed: feed,
    timestamps: TimestampRuntimeContext(
      drugTime: _timestamp(times['drug_time']),
      mealTime: _timestamp(times['meal_time']),
      coeventTime: _timestamp(times['coevent_time']),
    ),
  );
}

void _validateRule(Map<String, dynamic> rule) {
  _keys(
    rule,
    {
      'rule_id',
      'version',
      'status',
      'rule_type',
      'priority_band',
      'jurisdiction',
      'when',
      'then',
      'provenance',
    },
    optional: {'specificity_band', 'applies_to', 'override'},
  );
  for (final key in ['rule_id', 'version', 'status', 'rule_type']) {
    _text(rule[key], key);
  }
  if (rule['priority_band'] is! int ||
      (rule.containsKey('specificity_band') &&
          rule['specificity_band'] is! int)) {
    throw const FormatException(
      'Rule priority and specificity must be integers.',
    );
  }
  _strings(rule['jurisdiction'], 'jurisdiction');
  final applies = rule['applies_to'];
  if (applies != null) {
    final a = _map(applies, 'applies_to');
    _keys(a, {}, optional: {'subject_types', 'target_selector'});
    if (a.containsKey('subject_types')) {
      _strings(a['subject_types'], 'subject_types');
    }
    if (a.containsKey('target_selector')) {
      final selector = _map(a['target_selector'], 'target_selector');
      _keys(selector, {'target'});
      _text(selector['target'], 'target');
    }
  } else if (rule.containsKey('applies_to')) {
    throw const FormatException('applies_to must be an object.');
  }
  _condition(_map(rule['when'], 'when'));
  final effect = _map(rule['then'], 'then');
  _keys(
    effect,
    {'decision', 'severity', 'messages'},
    optional: {'actions', 'output_tags'},
  );
  _decision(effect['decision']);
  _text(effect['severity'], 'severity');
  final messages = _map(effect['messages'], 'messages');
  if (!messages.containsKey('zh')) {
    throw const FormatException('messages.zh is required.');
  }
  final locale = RegExp(r'^[a-z]{2,3}(?:-[A-Za-z0-9]{2,8})*$');
  for (final e in messages.entries) {
    if (e.key == 'localized') {
      for (final item in _map(e.value, 'localized').entries) {
        if (!locale.hasMatch(item.key)) {
          throw const FormatException('Invalid message locale.');
        }
        _text(item.value, 'message', empty: true);
      }
    } else {
      if (!locale.hasMatch(e.key)) {
        throw const FormatException('Unknown message key.');
      }
      _text(e.value, 'message', empty: true);
    }
  }
  if (effect.containsKey('output_tags')) {
    _strings(effect['output_tags'], 'output_tags');
  }
  if (effect.containsKey('actions')) {
    for (final value in _list(effect['actions'], 'actions')) {
      final action = _map(value, 'action');
      _keys(action, {'type'}, optional: {'params'});
      _text(action['type'], 'action.type');
      if (action.containsKey('params')) _map(action['params'], 'action.params');
    }
  }
  final provenance = _map(rule['provenance'], 'provenance');
  _keys(
    provenance,
    {'evidence_level', 'source_refs'},
    optional: {'effective_from', 'effective_to'},
  );
  _text(provenance['evidence_level'], 'evidence_level');
  _strings(provenance['source_refs'], 'source_refs');
  for (final key in ['effective_from', 'effective_to']) {
    final value = provenance[key];
    if (value != null) {
      final text = _text(value, key);
      _timestamp(
        RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)
            ? '${text}T00:00:00Z'
            : text,
      );
    }
  }
  if (rule.containsKey('override')) {
    final override = _map(rule['override'], 'override');
    _keys(override, {}, optional: {'override_scope', 'manual_override'});
    if (override.containsKey('override_scope')) {
      _text(override['override_scope'], 'override_scope');
    }
    if (override.containsKey('manual_override')) {
      _boolean(override['manual_override'], 'manual_override');
    }
  }
  try {
    RuleRegistryCompiler().compileJson(
      rule,
      rulesVersion: rule['version'] as String,
    );
  } catch (error) {
    throw FormatException('Invalid rule: $error');
  }
}

const _massUnits = {'mg', 'g', 'mcg', 'ug', 'µg', 'μg'};
const _comparisonOps = {'eq', 'ne', 'gt', 'gte', 'lt', 'lte'};

void _condition(Map<String, dynamic> node) {
  if (node.length != 1) {
    throw const FormatException('A condition must have exactly one operator.');
  }
  final operator = node.keys.single;
  final value = node.values.single;
  if (operator == 'all' || operator == 'any') {
    for (final child in _list(value, operator)) {
      _condition(_map(child, 'condition'));
    }
    return;
  }
  if (operator == 'not') {
    _condition(_map(value, 'condition'));
    return;
  }
  final c = _map(value, 'condition.$operator');
  switch (operator) {
    case 'cmp':
      _keys(c, {'path', 'op', 'value'});
      _operator(c['op']);
      if (c['value'] is Map || c['value'] is List) {
        throw const FormatException('Comparison value must be scalar.');
      }
    case 'in':
      _keys(c, {'path', 'values'});
      final values = _list(c['values'], 'values');
      if (values.any((v) => v is Map || v is List)) {
        throw const FormatException('Membership values must be scalar.');
      }
    case 'exists':
      _keys(c, {'path'});
    case 'between':
      _keys(c, {'left_path', 'right_path', 'unit', 'low', 'high'});
      _path(c['left_path']);
      _path(c['right_path']);
      if (!(c['left_path'] as String).startsWith('timestamps.') ||
          !(c['right_path'] as String).startsWith('timestamps.')) {
        throw const FormatException(
          'Interval conditions require timestamp paths.',
        );
      }
      if (!{'minutes', 'hours'}.contains(c['unit'])) {
        throw const FormatException('Unsupported interval unit.');
      }
      _range(c);
    case 'dose_band':
      _keys(c, {'path', 'unit'}, optional: {'low', 'high', 'threshold', 'op'});
      final path = c['path'];
      final unit = c['unit'];
      // Current engine range bounds are mg and scalar conversion uses the
      // rule unit. Reject ambiguous dimensions instead of repairing its logic.
      if (!((path == 'drug.daily_dose_mg' && unit == 'mg/day') ||
          (path == 'drug.administration_dose_value' && unit == 'mg'))) {
        throw const FormatException(
          'Unsupported dose semantics: use daily_dose_mg with mg/day, '
          'or administration_dose_value with mg.',
        );
      }
      if (c.containsKey('low') || c.containsKey('high')) {
        if (c.containsKey('op') || c.containsKey('threshold')) {
          throw const FormatException('Ambiguous dose condition.');
        }
        _range(c, nullable: true);
      } else {
        _operator(c['op']);
        _number(c['threshold'], 'threshold');
      }
    default:
      throw FormatException('Unknown condition operator: $operator');
  }
  if (operator != 'between') _path(c['path']);
}

void _path(Object? value) {
  final path = _text(value, 'path');
  const paths = {
    'user_profile.patient_id',
    'user_profile.registration_region',
    'user_profile.display_locale',
    'user_profile.content_jurisdiction_override',
    'user_profile.diet_profile_region',
    'user_profile.timezone',
    'drug.id',
    'drug.generic_name',
    'drug.brand_name',
    'drug.active_ingredients',
    'drug.substance_tags',
    'drug.formulation',
    'drug.dosage_form',
    'drug.route',
    'drug.release_type',
    'drug.administration_dose_value',
    'drug.administration_dose_unit',
    'drug.daily_dose_mg',
    'drug.jurisdiction',
    'meal.id',
    'meal.protein_g',
    'meal.tyramine_mg_est',
    'meal.high_fat_high_calorie',
    'meal.item_ids',
    'coevent.substance_tags',
    'coevent.supplements',
    'coevent.thickener_type',
    'enteral_feed.mode',
    'enteral_feed.formula',
    'enteral_feed.protein_g_per_day',
    'timestamps.drug_time',
    'timestamps.meal_time',
    'timestamps.coevent_time',
  };
  if (!paths.contains(path) &&
      !RegExp(
        r'^coevent\.supplements\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*$',
      ).hasMatch(path)) {
    throw FormatException('Unsupported runtime path: $path');
  }
}

void _range(Map<String, dynamic> c, {bool nullable = false}) {
  final low = nullable
      ? _nullableNumber(c['low'], 'low', signed: true)
      : _number(c['low'], 'low', signed: true);
  final high = nullable
      ? _nullableNumber(c['high'], 'high', signed: true)
      : _number(c['high'], 'high', signed: true);
  if ((low == null && high == null) ||
      (low != null && high != null && low > high)) {
    throw const FormatException('Invalid condition range.');
  }
}

void _operator(Object? value) {
  if (!_comparisonOps.contains(value)) {
    throw const FormatException('Unknown comparison operator.');
  }
}

RuntimeDecisionType _decision(Object? value) =>
    RuntimeDecisionType.values.firstWhere(
      (d) => d.wireValue == value,
      orElse: () => throw const FormatException('Unknown decision.'),
    );

void _schema(Map<String, dynamic> json) {
  if (json['schema_version'] is! int ||
      json['schema_version'] != 1 ||
      json['synthetic_only'] != true) {
    throw const FormatException(
      'Only schema version 1 and synthetic_only=true are supported.',
    );
  }
}

void _keys(
  Map<String, dynamic> json,
  Set<String> required, {
  Set<String> optional = const {},
}) {
  if (!required.every(json.containsKey) ||
      json.keys.any((k) => !required.contains(k) && !optional.contains(k))) {
    throw FormatException(
      'Missing or unknown fields; expected ${required.join(', ')}.',
    );
  }
}

Map<String, dynamic> _map(Object? value, String name) {
  if (value is! Map || value.keys.any((k) => k is! String)) {
    throw FormatException('$name must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

List<dynamic> _list(Object? value, String name) {
  if (value is! List) throw FormatException('$name must be an array.');
  return value;
}

String _text(Object? value, String name, {bool empty = false}) {
  if (value is! String ||
      value.length > 4096 ||
      (!empty && value.trim().isEmpty)) {
    throw FormatException('$name must be a bounded string.');
  }
  for (var i = 0; i < value.length; i++) {
    final unit = value.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i == value.length ||
          value.codeUnitAt(i) < 0xdc00 ||
          value.codeUnitAt(i) > 0xdfff) {
        throw FormatException('$name contains an unpaired Unicode surrogate.');
      }
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw FormatException('$name contains an unpaired Unicode surrogate.');
    }
  }
  return value;
}

String? _nullableText(Object? value, String name) =>
    value == null ? null : _text(value, name);
List<String> _strings(Object? value, String name) {
  final list = _list(value, name).map((v) => _text(v, name)).toList();
  if (list.toSet().length != list.length) {
    throw FormatException('Duplicate $name.');
  }
  return list;
}

bool _boolean(Object? value, String name) {
  if (value is! bool) throw FormatException('$name must be boolean.');
  return value;
}

double _number(Object? value, String name, {bool signed = false}) {
  if (value is! num || !value.isFinite || (!signed && value < 0)) {
    throw FormatException(
      '$name must be a finite ${signed ? '' : 'nonnegative '}number.',
    );
  }
  return value.toDouble();
}

double? _nullableNumber(Object? value, String name, {bool signed = false}) =>
    value == null ? null : _number(value, name, signed: signed);

DateTime? _timestamp(Object? value) {
  if (value == null) return null;
  final text = _text(value, 'timestamp');
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,6}))?(Z|[+-]\d{2}:\d{2})$',
  ).firstMatch(text);
  if (match == null) {
    throw const FormatException('Timestamps require an explicit UTC offset.');
  }
  final parts = [for (var i = 1; i <= 6; i++) int.parse(match.group(i)!)];
  final date = DateTime.utc(parts[0], parts[1], parts[2]);
  if (date.year != parts[0] ||
      date.month != parts[1] ||
      date.day != parts[2] ||
      parts[3] > 23 ||
      parts[4] > 59 ||
      parts[5] > 59) {
    throw const FormatException('Invalid calendar timestamp.');
  }
  final offset = match.group(8)!;
  if (offset != 'Z') {
    final hour = int.parse(offset.substring(1, 3));
    final minute = int.parse(offset.substring(4, 6));
    if (hour > 14 || minute > 59 || (hour == 14 && minute != 0)) {
      throw const FormatException('Invalid UTC offset.');
    }
  }
  final parsed = DateTime.parse(text).toUtc();
  if (parsed.year < 1 || parsed.year > 9999 || parts[0] < 1) {
    throw const FormatException(
      'Timestamp is outside the supported UTC years.',
    );
  }
  return parsed;
}

Map<String, dynamic> _decode(String source) {
  if (utf8.encode(source).length > ruleTestMaxJsonBytes) {
    throw const FormatException('JSON payload is too large.');
  }
  // Check nesting before jsonDecode so adversarial nesting cannot overflow it.
  var depth = 0;
  var quoted = false;
  var escaped = false;
  for (final code in source.codeUnits) {
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (code == 92) {
        escaped = true;
      } else if (code == 34) {
        quoted = false;
      }
    } else if (code == 34) {
      quoted = true;
    } else if (code == 123 || code == 91) {
      if (++depth > ruleTestMaxJsonDepth) {
        throw const FormatException('JSON is too deeply nested.');
      }
    } else if (code == 125 || code == 93) {
      depth--;
    }
  }
  final decoded = jsonDecode(source);
  _bounded(decoded);
  return _map(decoded, 'document');
}

void _bounded(Object? value) {
  var count = 0;
  void visit(Object? item, int depth) {
    if (depth > ruleTestMaxJsonDepth || ++count > 20000) {
      throw const FormatException('JSON payload exceeds structural limits.');
    }
    if (item is Map) {
      for (final entry in item.entries) {
        _text(entry.key, 'key');
        visit(entry.value, depth + 1);
      }
    } else if (item is List) {
      for (final child in item) {
        visit(child, depth + 1);
      }
    } else if (item is String) {
      _text(item, 'value', empty: true);
    } else if (item is num) {
      if (!item.isFinite ||
          item > 9007199254740991 ||
          item < -9007199254740991) {
        throw const FormatException(
          'JSON number exceeds the finite safe binary64 range.',
        );
      }
    } else if (item != null && item is! bool) {
      throw const FormatException('Non-JSON value.');
    }
  }

  visit(value, 0);
  if (utf8.encode(jsonEncode(value)).length > ruleTestMaxJsonBytes) {
    throw const FormatException('JSON payload is too large.');
  }
}

/// Portable content identity for this workbench only. Every JSON node is
/// tagged; maps sort UTF-16 keys and numbers use big-endian IEEE-754 binary64.
/// Numeric 1 and 1.0 are equivalent, and both signed zeros normalize to +0.
/// This does not replace the current engine's platform-native audit digest.
String ruleTestJsonDigest(String domain, Object? payload) {
  _text(domain, 'digest domain');
  _bounded(payload);
  Object canonical(Object? value) {
    if (value == null) return ['null'];
    if (value is bool) return ['bool', value];
    if (value is String) return ['string', value];
    if (value is num) {
      final bytes = ByteData(8)
        ..setFloat64(0, value == 0 ? 0 : value.toDouble(), Endian.big);
      final hex = bytes.buffer
          .asUint8List()
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();
      return ['number', hex];
    }
    if (value is List) return ['array', value.map(canonical).toList()];
    final map = value as Map;
    final keys = map.keys.cast<String>().toList()..sort();
    return [
      'object',
      [
        for (final key in keys) [key, canonical(map[key])],
      ],
    ];
  }

  return CdssIdentifierFactory().inputDigest(domain, {
    'canonicalization_profile': ruleTestCanonicalizationProfile,
    'value': canonical(payload),
  });
}

Object? _freeze(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable({
      for (final e in value.entries) e.key as String: _freeze(e.value),
    });
  }
  if (value is List) return List<dynamic>.unmodifiable(value.map(_freeze));
  return value;
}

Object? _copy(Object? value) {
  if (value is Map) {
    return <String, dynamic>{
      for (final e in value.entries) e.key as String: _copy(e.value),
    };
  }
  if (value is List) return value.map(_copy).toList();
  return value;
}
