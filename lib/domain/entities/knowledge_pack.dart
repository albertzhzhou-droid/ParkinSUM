import 'dart:convert';

import 'rule_test_case.dart';

const knowledgePackSchemaVersion = 1;
const knowledgePackMaxBytes = 2 * 1024 * 1024;

enum KnowledgeCaseCategory {
  positive,
  negative,
  missingInput,
  boundary,
  conflict,
}

enum KnowledgeRuleMatch { matched, notMatched, unknown }

/// A pinned source excerpt and its provenance, not a verified clinical claim.
final class KnowledgeSource {
  final String sourceId;
  final String title;
  final String uri;
  final String revision;
  final String excerpt;

  KnowledgeSource({
    required this.sourceId,
    required this.title,
    required this.uri,
    required this.revision,
    required this.excerpt,
  }) {
    for (final value in [sourceId, title, uri, revision, excerpt]) {
      knowledgeText(value, 'source field', max: 4096);
    }
    final parsed = Uri.tryParse(uri);
    if (parsed == null ||
        parsed.scheme != 'https' ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty) {
      throw const FormatException(
        'Source URI must be an absolute HTTPS reference.',
      );
    }
  }

  late final String digest = ruleTestJsonDigest(
    'knowledge-source-v1',
    toJson(),
  );
  Map<String, dynamic> toJson() => {
    'source_id': sourceId,
    'title': title,
    'uri': uri,
    'revision': revision,
    'excerpt': excerpt,
  };

  factory KnowledgeSource.fromJson(Map<String, dynamic> json) {
    knowledgeKeys(json, {'source_id', 'title', 'uri', 'revision', 'excerpt'});
    return KnowledgeSource(
      sourceId: knowledgeText(json['source_id'], 'source_id'),
      title: knowledgeText(json['title'], 'title', max: 4096),
      uri: knowledgeText(json['uri'], 'uri', max: 4096),
      revision: knowledgeText(json['revision'], 'revision'),
      excerpt: knowledgeText(json['excerpt'], 'excerpt', max: 4096),
    );
  }
}

/// Authored expectation for one rule, independently of the final target winner.
final class KnowledgeTestCase {
  final KnowledgeCaseCategory category;
  final String targetRuleId;
  final KnowledgeRuleMatch expectedMatch;
  final String rationale;
  final RuleTestCase testCase;

  KnowledgeTestCase({
    required this.category,
    required this.targetRuleId,
    required this.expectedMatch,
    required this.rationale,
    required this.testCase,
  }) {
    knowledgeText(targetRuleId, 'target_rule_id');
    knowledgeText(rationale, 'case rationale', max: 4096);
    if (!testCase.binding.ruleVersions.containsKey(targetRuleId)) {
      throw const FormatException('Case target must be a bound rule.');
    }
    if ((category == KnowledgeCaseCategory.positive &&
            expectedMatch != KnowledgeRuleMatch.matched) ||
        (category == KnowledgeCaseCategory.negative &&
            expectedMatch != KnowledgeRuleMatch.notMatched) ||
        (category == KnowledgeCaseCategory.missingInput &&
            expectedMatch != KnowledgeRuleMatch.unknown) ||
        (category == KnowledgeCaseCategory.boundary &&
            expectedMatch == KnowledgeRuleMatch.unknown)) {
      throw const FormatException(
        'Case category and rule-match expectation disagree.',
      );
    }
  }

  Map<String, dynamic> toJson() => {
    'category': category.name,
    'target_rule_id': targetRuleId,
    'expected_match': expectedMatch.name,
    'rationale': rationale,
    'case': testCase.toJson(),
  };

  factory KnowledgeTestCase.fromJson(Map<String, dynamic> json) {
    knowledgeKeys(json, {
      'category',
      'target_rule_id',
      'expected_match',
      'rationale',
      'case',
    });
    return KnowledgeTestCase(
      category: knowledgeEnum(KnowledgeCaseCategory.values, json['category']),
      targetRuleId: knowledgeText(json['target_rule_id'], 'target_rule_id'),
      expectedMatch: knowledgeEnum(
        KnowledgeRuleMatch.values,
        json['expected_match'],
      ),
      rationale: knowledgeText(json['rationale'], 'rationale', max: 4096),
      testCase: RuleTestCase.fromJson(knowledgeMap(json['case'])),
    );
  }
}

/// A complete immutable candidate. Draft refers to governance state: no rule
/// in this object becomes active merely because its authored status is active.
final class KnowledgePack {
  final String packId;
  final String version;
  final String authorId;
  final String engineDigest;
  final RuleTestRuleSet ruleSet;
  final List<KnowledgeSource> sources;
  final List<KnowledgeTestCase> cases;

  KnowledgePack({
    required this.packId,
    required this.version,
    required this.authorId,
    required this.engineDigest,
    required this.ruleSet,
    required List<KnowledgeSource> sources,
    required List<KnowledgeTestCase> cases,
  }) : sources = List.unmodifiable(sources),
       cases = List.unmodifiable(cases) {
    for (final value in [packId, version, authorId]) {
      knowledgeText(value, 'pack identity');
    }
    knowledgeDigest(engineDigest);
    if (version != ruleSet.bundleVersion ||
        ruleSet.rawRules.isEmpty ||
        ruleSet.rawRules.length > 32 ||
        sources.length > 128 ||
        cases.length > 128) {
      throw const FormatException(
        'Invalid complete package version or capacity.',
      );
    }
    if (sources.map((s) => s.sourceId).toSet().length != sources.length ||
        cases.map((c) => c.testCase.caseId).toSet().length != cases.length) {
      throw const FormatException('Duplicate source or case identifier.');
    }
    final refs = sources.map((s) => s.sourceId).toSet();
    for (final rule in ruleSet.rawRules) {
      final sourceRefs = (rule['provenance'] as Map)['source_refs'] as List;
      if (rule['status'] != 'active' ||
          sourceRefs.isEmpty ||
          sourceRefs.any((ref) => !refs.contains(ref))) {
        throw const FormatException(
          'Every candidate rule requires active authored status and pinned source provenance.',
        );
      }
    }
    if (cases.any((c) => !c.testCase.binding.matches(ruleSet.binding))) {
      throw const FormatException(
        'All cases must bind the exact complete rule package.',
      );
    }
    knowledgeCheckJson(toJson(), maxBytes: knowledgePackMaxBytes);
  }

  /// Child digests bind complete validated content while keeping the manifest
  /// bounded. Order is preserved and category/target expectations are included.
  late final String suiteDigest = ruleTestJsonDigest('knowledge-suite-v1', [
    for (final c in cases)
      {
        'category': c.category.name,
        'target_rule_id': c.targetRuleId,
        'expected_match': c.expectedMatch.name,
        'rationale': c.rationale,
        'case_digest': c.testCase.caseDigest,
      },
  ]);
  late final String digest = ruleTestJsonDigest('knowledge-pack-v1', {
    'pack_id': packId,
    'version': version,
    'author_id': authorId,
    'engine_digest': engineDigest,
    'rule_binding': ruleSet.binding.toJson(),
    'sources': [
      for (final s in sources) {'source_id': s.sourceId, 'digest': s.digest},
    ],
    'suite_digest': suiteDigest,
  });

  void requireCompleteSuite() {
    for (final ruleId in ruleSet.ruleVersions.keys) {
      final relevant = cases.where((c) => c.targetRuleId == ruleId).toList();
      for (final category in [
        KnowledgeCaseCategory.positive,
        KnowledgeCaseCategory.negative,
        KnowledgeCaseCategory.missingInput,
        KnowledgeCaseCategory.boundary,
      ]) {
        if (!relevant.any((c) => c.category == category)) {
          throw FormatException(
            'Rule $ruleId lacks ${category.name} coverage.',
          );
        }
      }
      if (relevant.map((c) => c.testCase.inputDigest).toSet().length < 4 ||
          relevant.any(
            (c) =>
                c.testCase.expected.targets == null ||
                (c.category == KnowledgeCaseCategory.missingInput &&
                    (c.testCase.expected.missingFieldsByRule[ruleId]?.isEmpty ??
                        true)),
          )) {
        throw FormatException(
          'Rule $ruleId needs four distinct synthetic inputs with authored assertions.',
        );
      }
    }
  }

  Map<String, dynamic> toJson() => {
    'schema_version': knowledgePackSchemaVersion,
    'pack_id': packId,
    'version': version,
    'author_id': authorId,
    'engine_digest': engineDigest,
    'rule_set': ruleSet.toJson(),
    'sources': sources.map((s) => s.toJson()).toList(),
    'cases': cases.map((c) => c.toJson()).toList(),
    'suite_digest': suiteDigest,
    'digest': digest,
  };
  String encode() => jsonEncode(toJson());
  factory KnowledgePack.decode(String raw) => KnowledgePack.fromJson(
    knowledgeDecode(raw, maxBytes: knowledgePackMaxBytes),
  );
  factory KnowledgePack.fromJson(Map<String, dynamic> json) {
    knowledgeCheckJson(json, maxBytes: knowledgePackMaxBytes);
    knowledgeKeys(json, {
      'schema_version',
      'pack_id',
      'version',
      'author_id',
      'engine_digest',
      'rule_set',
      'sources',
      'cases',
      'suite_digest',
      'digest',
    });
    if (json['schema_version'] != knowledgePackSchemaVersion ||
        json['schema_version'] is! int) {
      throw const FormatException('Unsupported knowledge package schema.');
    }
    final result = KnowledgePack(
      packId: knowledgeText(json['pack_id'], 'pack_id'),
      version: knowledgeText(json['version'], 'version'),
      authorId: knowledgeText(json['author_id'], 'author_id'),
      engineDigest: knowledgeDigest(json['engine_digest']),
      ruleSet: RuleTestRuleSet.fromJson(knowledgeMap(json['rule_set'])),
      sources: knowledgeList(
        json['sources'],
      ).map((s) => KnowledgeSource.fromJson(knowledgeMap(s))).toList(),
      cases: knowledgeList(
        json['cases'],
      ).map((c) => KnowledgeTestCase.fromJson(knowledgeMap(c))).toList(),
    );
    if (result.digest != json['digest'] ||
        result.suiteDigest != json['suite_digest']) {
      throw const FormatException(
        'Knowledge package content binding mismatch.',
      );
    }
    return result;
  }
}

T knowledgeEnum<T extends Enum>(List<T> values, Object? raw) =>
    values.firstWhere(
      (v) => v.name == raw,
      orElse: () => throw const FormatException('Unknown enum value.'),
    );
Map<String, dynamic> knowledgeMap(Object? raw) {
  if (raw is! Map || raw.keys.any((k) => k is! String)) {
    throw const FormatException('Expected JSON object.');
  }
  return Map<String, dynamic>.from(raw);
}

List<dynamic> knowledgeList(Object? raw) {
  if (raw is! List) throw const FormatException('Expected JSON array.');
  return raw;
}

void knowledgeKeys(Map<String, dynamic> json, Set<String> required) {
  if (json.length != required.length || !required.every(json.containsKey)) {
    throw const FormatException('Unknown or missing governance fields.');
  }
}

String knowledgeText(Object? raw, String field, {int max = 512}) {
  if (raw is! String || raw.trim().isEmpty || raw.length > max) {
    throw FormatException('Invalid $field.');
  }
  for (var i = 0; i < raw.length; i++) {
    final unit = raw.codeUnitAt(i);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (++i >= raw.length ||
          raw.codeUnitAt(i) < 0xdc00 ||
          raw.codeUnitAt(i) > 0xdfff) {
        throw FormatException('Invalid Unicode in $field.');
      }
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      throw FormatException('Invalid Unicode in $field.');
    }
  }
  return raw;
}

String knowledgeDigest(Object? raw) {
  final text = knowledgeText(raw, 'digest');
  if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(text)) {
    throw const FormatException('Invalid digest.');
  }
  return text;
}

DateTime knowledgeUtc(Object? raw) {
  final text = knowledgeText(raw, 'UTC timestamp');
  final parsed = DateTime.tryParse(text);
  if (parsed == null ||
      !parsed.isUtc ||
      parsed.toIso8601String() != text ||
      parsed.year < 1 ||
      parsed.year > 9999) {
    throw const FormatException('Timestamp must be canonical UTC.');
  }
  return parsed;
}

void knowledgeCheckJson(Object? value, {required int maxBytes}) {
  var nodes = 0;
  void visit(Object? v, int depth) {
    if (depth > 40 || ++nodes > 200000) {
      throw const FormatException(
        'Governance document too deeply nested or large.',
      );
    }
    if (v is Map) {
      for (final e in v.entries) {
        knowledgeText(e.key, 'key');
        visit(e.value, depth + 1);
      }
    } else if (v is List) {
      for (final e in v) {
        visit(e, depth + 1);
      }
    } else if (v is String) {
      if (v.isNotEmpty) knowledgeText(v, 'string', max: 4096);
    } else if (v is num) {
      if (!v.isFinite || v > 9007199254740991 || v < -9007199254740991) {
        throw const FormatException('Invalid JSON number.');
      }
    } else if (v != null && v is! bool) {
      throw const FormatException('Non-JSON value.');
    }
  }

  visit(value, 0);
  if (utf8.encode(jsonEncode(value)).length > maxBytes) {
    throw const FormatException('Governance document exceeds capacity.');
  }
}

Map<String, dynamic> knowledgeDecode(String raw, {required int maxBytes}) {
  if (utf8.encode(raw).length > maxBytes) {
    throw const FormatException('Governance document exceeds capacity.');
  }
  final objectMembers = <Set<String>?>[];
  final expectingKey = <bool>[];
  for (var index = 0; index < raw.length; index++) {
    final c = raw.codeUnitAt(index);
    if (c == 34) {
      final start = index;
      var closed = false;
      while (++index < raw.length) {
        if (raw.codeUnitAt(index) == 92) {
          index++;
        } else if (raw.codeUnitAt(index) == 34) {
          closed = true;
          break;
        }
      }
      if (!closed) throw const FormatException('Unterminated JSON string.');
      if (objectMembers.isNotEmpty && expectingKey.last) {
        final key = jsonDecode(raw.substring(start, index + 1));
        if (key is! String || !objectMembers.last!.add(key)) {
          throw const FormatException('Duplicate governance JSON key.');
        }
        expectingKey[expectingKey.length - 1] = false;
      }
    } else if (c == 123 || c == 91) {
      objectMembers.add(c == 123 ? <String>{} : null);
      expectingKey.add(c == 123);
      if (objectMembers.length > 40) {
        throw const FormatException('Governance document too deeply nested.');
      }
    } else if (c == 125 || c == 93) {
      if (objectMembers.isEmpty || (c == 125) != (objectMembers.last != null)) {
        throw const FormatException('Invalid governance JSON container.');
      }
      objectMembers.removeLast();
      expectingKey.removeLast();
    } else if (c == 44 &&
        objectMembers.isNotEmpty &&
        objectMembers.last != null) {
      expectingKey[expectingKey.length - 1] = true;
    }
  }
  final value = jsonDecode(raw);
  knowledgeCheckJson(value, maxBytes: maxBytes);
  return knowledgeMap(value);
}
