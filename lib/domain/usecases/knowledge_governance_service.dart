import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../algorithm_sdk/algorithm_configuration_identity.dart';
import '../entities/knowledge_approval_envelope.dart';
import '../entities/knowledge_governance_state.dart';
import '../entities/knowledge_pack.dart';
import '../entities/rule_registry_models.dart';
import '../entities/rule_test_case.dart';
import 'knowledge_approval_verifier.dart';
import 'rule_registry_compiler.dart';
import 'synthetic_rule_test_runner.dart';

const knowledgeGovernanceDocumentKey =
    'parkinsum.knowledge_governance.v1.document';
const knowledgeGovernanceAnchorKey = 'parkinsum.knowledge_governance.v1.anchor';
const knowledgePrototypeBaselineDigest =
    '9593e5557ac4f2fcaa532e32d1a52edd7a24c4c8654c4e94e610dfd9e9995efb';

typedef _KnowledgeSnapshot = ({
  KnowledgeGovernanceState state,
  String? document,
  String? anchor,
});

/// Separate anchor is written first. A torn write therefore holds resolution;
/// it never restores the prototype exception. No API clears this anchor.
abstract interface class KnowledgeGovernanceStore {
  String get mutationScope;
  Future<String?> read();
  Future<String?> readAnchor();
  Future<void> writeExact({
    required String document,
    required String anchor,
    required String? expectedAnchor,
    required bool Function() authorize,
  });
}

final class LocalKnowledgeGovernanceStore implements KnowledgeGovernanceStore {
  @override
  String get mutationScope => knowledgeGovernanceDocumentKey;
  @override
  Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(knowledgeGovernanceDocumentKey);
  }

  @override
  Future<String?> readAnchor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return prefs.getString(knowledgeGovernanceAnchorKey);
  }

  @override
  Future<void> writeExact({
    required String document,
    required String anchor,
    required String? expectedAnchor,
    required bool Function() authorize,
  }) async {
    _requireAuthorized(authorize);
    if (utf8.encode(document).length > knowledgeGovernanceMaxBytes) {
      throw StateError('knowledge_capacity_reached');
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    if (prefs.getString(knowledgeGovernanceAnchorKey) != expectedAnchor) {
      throw StateError('knowledge_concurrent_change');
    }
    _requireAuthorized(authorize);
    if (!await prefs.setString(knowledgeGovernanceAnchorKey, anchor)) {
      throw StateError('knowledge_anchor_write_failed');
    }
    _requireAuthorized(authorize);
    if (!await prefs.setString(knowledgeGovernanceDocumentKey, document)) {
      throw StateError('knowledge_document_write_failed');
    }
    await prefs.reload();
    if (prefs.getString(knowledgeGovernanceAnchorKey) != anchor ||
        prefs.getString(knowledgeGovernanceDocumentKey) != document) {
      throw StateError('knowledge_readback_mismatch');
    }
    _requireAuthorized(authorize);
  }
}

class MemoryKnowledgeGovernanceStore implements KnowledgeGovernanceStore {
  static int _nextScope = 0;
  MemoryKnowledgeGovernanceStore({String? scope, this.document, this.anchor})
    : mutationScope = scope ?? 'memory-knowledge-${_nextScope++}';
  String? document;
  String? anchor;
  @override
  final String mutationScope;
  @override
  Future<String?> read() async => document;
  @override
  Future<String?> readAnchor() async => anchor;
  @override
  Future<void> writeExact({
    required String document,
    required String anchor,
    required String? expectedAnchor,
    required bool Function() authorize,
  }) async {
    _requireAuthorized(authorize);
    if (this.anchor != expectedAnchor) {
      throw StateError('knowledge_concurrent_change');
    }
    if (utf8.encode(document).length > knowledgeGovernanceMaxBytes) {
      throw StateError('knowledge_capacity_reached');
    }
    this.anchor = anchor;
    _requireAuthorized(authorize);
    this.document = document;
    _requireAuthorized(authorize);
  }
}

String knowledgeCurrentEngineDigest(RuleTestRuleSet rules) {
  final identity = AlgorithmConfigurationIdentity.defaults(
    runtimeRules: rules.rawRules,
  );
  return ruleTestJsonDigest('knowledge-engine-binding-v1', {
    'id': identity.id,
    'version': identity.version,
    'configuration_digest': _engineConfigurationTreeDigest(
      identity.canonicalConfiguration,
    ),
    'registered_source_bundle_sha256':
        AlgorithmConfigurationIdentity.registeredAlgorithmSourceBundleSha256,
  });
}

// Configuration/provenance grows with every rule. Bind the full structure as
// a Merkle tree, keeping each portable digest payload below the workbench's
// 256 KiB limit without omitting coverage metadata or relying on native number
// spelling. Every node is tagged, list order is preserved, and maps sort keys.
String _engineConfigurationTreeDigest(Object? value) {
  final Object? node;
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    node = [
      'object',
      [
        for (final key in keys)
          [key, _engineConfigurationTreeDigest(value[key])],
      ],
    ];
  } else if (value is List) {
    node = ['array', value.map(_engineConfigurationTreeDigest).toList()];
  } else {
    node = ['scalar', value];
  }
  return ruleTestJsonDigest('knowledge-engine-config-merkle-v1', node);
}

/// No partial lists. Callers must hold the clinical path when allowed is false.
final class KnowledgeRuleResolution {
  final bool allowed;
  final String reason;
  final bool isPrototypeBaseline;
  final String? packageDigest;
  final String? rulesVersion;
  final String? stateHeadDigest;
  final List<RuleRegistryEntry> rules;
  final KnowledgePack? pack;
  KnowledgeRuleResolution._({
    required this.allowed,
    required this.reason,
    required this.isPrototypeBaseline,
    required this.packageDigest,
    required this.rulesVersion,
    required this.stateHeadDigest,
    required this.rules,
    this.pack,
  });
}

final class KnowledgeGovernanceService {
  KnowledgeGovernanceService({
    required this.store,
    required this.verifier,
    DateTime Function()? nowUtc,
    String Function(RuleTestRuleSet)? engineDigest,
  }) : _nowUtc = nowUtc ?? (() => DateTime.now().toUtc()),
       _engineDigest = engineDigest ?? knowledgeCurrentEngineDigest;
  final KnowledgeGovernanceStore store;
  final KnowledgeApprovalVerifier verifier;
  final DateTime Function() _nowUtc;
  final String Function(RuleTestRuleSet) _engineDigest;
  static final Map<String, Future<void>> _tails = {};

  /// Exact packaged prototype; database registry rows are never candidates.
  static RuleTestRuleSet prototypeBaseline() {
    final baseline = RuleTestRuleSet.baseline();
    if (baseline.contentDigest != knowledgePrototypeBaselineDigest) {
      throw StateError('prototype_baseline_digest_changed');
    }
    return baseline;
  }

  KnowledgeApprovalBinding bindingForNext(
    KnowledgeGovernanceState state,
    KnowledgePack pack, {
    String? ruleId,
  }) => KnowledgeApprovalBinding(
    packId: pack.packId,
    packVersion: pack.version,
    packDigest: pack.digest,
    engineDigest: pack.engineDigest,
    suiteDigest: pack.suiteDigest,
    sequence: state.approvalSequence + 1,
    previousEnvelopeDigest: state.lastEnvelopeDigest,
    ruleId: ruleId,
    ruleVersion: ruleId == null ? null : pack.ruleSet.ruleVersions[ruleId],
  );

  Future<KnowledgeGovernanceState> loadState() async =>
      (await _loadSnapshot()).state;

  Future<_KnowledgeSnapshot> _loadSnapshot() async {
    final document = await store.read();
    final anchor = await store.readAnchor();
    if (document == null && anchor == null) {
      final snapshot = (
        state: await _replay(KnowledgeGovernanceJournal([])),
        document: document,
        anchor: anchor,
      );
      await _requireSnapshotCurrent(snapshot);
      return snapshot;
    }
    if (document == null || anchor == null) {
      throw StateError('knowledge_document_or_anchor_missing');
    }
    final journal = KnowledgeGovernanceJournal.decode(document);
    final a = knowledgeDecode(anchor, maxBytes: 4096);
    knowledgeKeys(a, {
      'schema_version',
      'head_digest',
      'event_count',
      'ever_managed',
    });
    final managed = journal.events.any(
      (e) =>
          e.kind == KnowledgeGovernanceEventKind.activated ||
          e.kind == KnowledgeGovernanceEventKind.withdrawn,
    );
    if (a['schema_version'] is! int ||
        a['schema_version'] != 1 ||
        a['event_count'] is! int ||
        a['event_count'] != journal.events.length ||
        a['head_digest'] != journal.headDigest ||
        a['ever_managed'] is! bool ||
        a['ever_managed'] != managed) {
      throw StateError('knowledge_anchor_mismatch');
    }
    final snapshot = (
      state: await _replay(journal),
      document: document,
      anchor: anchor,
    );
    await _requireSnapshotCurrent(snapshot);
    return snapshot;
  }

  Future<void> _requireSnapshotCurrent(_KnowledgeSnapshot snapshot) async {
    if (await store.read() != snapshot.document ||
        await store.readAnchor() != snapshot.anchor) {
      throw StateError('knowledge_concurrent_change');
    }
  }

  /// Revalidate just before committing a clinical result. This is a local
  /// snapshot gate, not an atomic transaction with an external patient store.
  Future<bool> isResolutionCurrent(KnowledgeRuleResolution resolution) async {
    if (!resolution.allowed) return false;
    try {
      final state = await loadState();
      if (state.headDigest != resolution.stateHeadDigest) return false;
      if (resolution.isPrototypeBaseline) {
        return !state.everManaged && state.activePack == null;
      }
      final active = state.activePack;
      if (active == null || active.pack.digest != resolution.packageDigest) {
        return false;
      }
      _requireEngine(active.pack);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<KnowledgeGovernanceState> saveDraft(
    KnowledgePack pack, {
    required String actorId,
    required bool Function() authorize,
  }) => _mutate(authorize, (state) async {
    if (actorId != pack.authorId) throw StateError('knowledge_author_mismatch');
    return _event(state, KnowledgeGovernanceEventKind.draftSaved, actorId, {
      'pack': pack.toJson(),
    });
  });

  Future<KnowledgeGovernanceState> submit(
    String packDigest, {
    required KnowledgeApprovalEnvelope authorApproval,
    required bool Function() authorize,
  }) => _mutate(authorize, (state) async {
    final record = _record(state, packDigest);
    if (record.status != KnowledgePackStatus.draft) {
      throw StateError('knowledge_submit_requires_draft');
    }
    _requireEngine(record.pack);
    final suite = await _evaluateSuite(record.pack);
    if (suite['passed'] != true) throw StateError('knowledge_suite_failed');
    return _event(
      state,
      KnowledgeGovernanceEventKind.submitted,
      authorApproval.statement.subjectId,
      {
        'pack_digest': packDigest,
        'approval': authorApproval.toJson(),
        'suite_result': suite,
      },
    );
  });

  Future<KnowledgeGovernanceState> acceptReview(
    String packDigest, {
    required KnowledgeApprovalEnvelope review,
    required bool Function() authorize,
  }) => _mutate(
    authorize,
    (state) async => _event(
      state,
      KnowledgeGovernanceEventKind.reviewAccepted,
      review.statement.subjectId,
      {'pack_digest': packDigest, 'approval': review.toJson()},
    ),
  );

  Future<KnowledgeGovernanceState> activate(
    String packDigest, {
    required KnowledgeApprovalEnvelope publisherApproval,
    required bool Function() authorize,
  }) => _mutate(
    authorize,
    (state) async => _event(
      state,
      KnowledgeGovernanceEventKind.activated,
      publisherApproval.statement.subjectId,
      {'pack_digest': packDigest, 'approval': publisherApproval.toJson()},
    ),
  );

  Future<KnowledgeGovernanceState> withdraw(
    String packDigest, {
    required KnowledgeApprovalEnvelope publisherApproval,
    required bool Function() authorize,
  }) => _mutate(
    authorize,
    (state) async => _event(
      state,
      KnowledgeGovernanceEventKind.withdrawn,
      publisherApproval.statement.subjectId,
      {'pack_digest': packDigest, 'approval': publisherApproval.toJson()},
    ),
  );

  Future<KnowledgeRuleResolution> resolveAuthorizedRules({
    RuleTestRuleSet? baselineCandidate,
  }) async {
    try {
      final snapshot = await _loadSnapshot();
      final state = snapshot.state;
      final active = state.activePack;
      if (active != null) {
        _requireEngine(active.pack);
        if ((await _evaluateSuite(active.pack))['passed'] != true) {
          throw StateError('knowledge_current_suite_failed');
        }
        await _requireSnapshotCurrent(snapshot);
        return KnowledgeRuleResolution._(
          allowed: true,
          reason: 'managed_package_authorized',
          isPrototypeBaseline: false,
          packageDigest: active.pack.digest,
          rulesVersion: active.pack.version,
          stateHeadDigest: state.headDigest,
          rules: _immutableRules(active.pack.ruleSet),
          pack: active.pack,
        );
      }
      if (!state.everManaged) {
        final baseline = prototypeBaseline();
        if (baselineCandidate != null &&
            !baseline.binding.matches(baselineCandidate.binding)) {
          throw StateError('prototype_baseline_binding_mismatch');
        }
        await _requireSnapshotCurrent(snapshot);
        return KnowledgeRuleResolution._(
          allowed: true,
          reason: 'exact_prototype_baseline_exception',
          isPrototypeBaseline: true,
          packageDigest: null,
          rulesVersion: baseline.bundleVersion,
          stateHeadDigest: state.headDigest,
          rules: _immutableRules(baseline),
        );
      }
      return _held('managed_package_inactive', state.headDigest);
    } catch (error) {
      return _held('knowledge_governance_held:${error.runtimeType}', null);
    }
  }

  Future<KnowledgeGovernanceState> _mutate(
    bool Function() authorize,
    Future<KnowledgeGovernanceEvent> Function(KnowledgeGovernanceState) build,
  ) async {
    final scope = store.mutationScope;
    final prior = _tails[scope] ?? Future<void>.value();
    final release = Completer<void>();
    final tail = prior.then((_) => release.future);
    _tails[scope] = tail;
    await prior;
    try {
      _requireAuthorized(authorize);
      final snapshot = await _loadSnapshot();
      final expectedAnchor = snapshot.anchor;
      final state = snapshot.state;
      final event = await build(state);
      _requireAuthorized(authorize);
      final next = await _replay(
        KnowledgeGovernanceJournal([...state.journal.events, event]),
      );
      _requireAuthorized(authorize);
      final document = next.journal.encode();
      final anchor = jsonEncode({
        'schema_version': 1,
        'head_digest': next.headDigest,
        'event_count': next.journal.events.length,
        'ever_managed': next.everManaged,
      });
      await _requireSnapshotCurrent(snapshot);
      await store.writeExact(
        document: document,
        anchor: anchor,
        expectedAnchor: expectedAnchor,
        authorize: authorize,
      );
      _requireAuthorized(authorize);
      if (await store.read() != document ||
          await store.readAnchor() != anchor) {
        throw StateError('knowledge_readback_mismatch');
      }
      _requireAuthorized(authorize);
      return next;
    } finally {
      release.complete();
      if (identical(_tails[scope], tail)) _tails.remove(scope);
    }
  }

  KnowledgeGovernanceEvent _event(
    KnowledgeGovernanceState state,
    KnowledgeGovernanceEventKind kind,
    String actorId,
    Map<String, dynamic> payload,
  ) => KnowledgeGovernanceEvent(
    sequence: state.journal.events.length + 1,
    previousDigest: state.headDigest,
    kind: kind,
    actorId: actorId,
    occurredAtUtc: _nowUtc(),
    payload: payload,
  );

  Future<KnowledgeGovernanceState> _replay(
    KnowledgeGovernanceJournal journal,
  ) async {
    final packages = <String, KnowledgePackRecord>{};
    String? active;
    var everManaged = false;
    var approvalSequence = 0;
    String? lastEnvelope;
    final approvalIds = <String>{};
    final seenVersions = <String>{};
    KnowledgeGovernanceState current() => KnowledgeGovernanceState.replayed(
      journal: journal,
      packages: packages,
      activePackDigest: active,
      everManaged: everManaged,
      approvalSequence: approvalSequence,
      lastEnvelopeDigest: lastEnvelope,
    );
    for (final event in journal.events) {
      if (event.kind == KnowledgeGovernanceEventKind.draftSaved) {
        knowledgeKeys(event.payload, {'pack'});
        final pack = KnowledgePack.fromJson(
          knowledgeMap(event.payload['pack']),
        );
        if (event.actorId != pack.authorId ||
            !seenVersions.add('${pack.packId}\u0000${pack.version}')) {
          throw StateError('knowledge_duplicate_version_or_wrong_author');
        }
        packages[pack.digest] = KnowledgePackRecord(
          pack: pack,
          status: KnowledgePackStatus.draft,
        );
        continue;
      }
      knowledgeKeys(
        event.payload,
        event.kind == KnowledgeGovernanceEventKind.submitted
            ? {'pack_digest', 'approval', 'suite_result'}
            : {'pack_digest', 'approval'},
      );
      final packDigest = knowledgeDigest(event.payload['pack_digest']);
      final record = packages[packDigest];
      if (record == null) throw StateError('knowledge_unknown_package');
      final pack = record.pack;
      final envelope = KnowledgeApprovalEnvelope.parseJson(
        jsonEncode(event.payload['approval']),
      );
      final statement = envelope.statement;
      if (statement.authorSubjectId != pack.authorId ||
          event.actorId != statement.subjectId ||
          !approvalIds.add(statement.approvalId)) {
        throw StateError('knowledge_approval_identity_or_replay');
      }
      final role = switch (event.kind) {
        KnowledgeGovernanceEventKind.submitted => KnowledgeApprovalRole.author,
        KnowledgeGovernanceEventKind.reviewAccepted =>
          KnowledgeApprovalRole.reviewer,
        _ => KnowledgeApprovalRole.publisher,
      };
      final decision = switch (event.kind) {
        KnowledgeGovernanceEventKind.submitted =>
          KnowledgeApprovalDecision.authored,
        KnowledgeGovernanceEventKind.activated =>
          KnowledgeApprovalDecision.published,
        KnowledgeGovernanceEventKind.withdrawn =>
          KnowledgeApprovalDecision.withdrawn,
        KnowledgeGovernanceEventKind.reviewAccepted => statement.decision,
        _ => throw StateError('Unsupported signed event'),
      };
      if (event.kind == KnowledgeGovernanceEventKind.reviewAccepted &&
          decision != KnowledgeApprovalDecision.approved &&
          decision != KnowledgeApprovalDecision.rejected) {
        throw StateError('knowledge_invalid_review_decision');
      }
      final ruleId = event.kind == KnowledgeGovernanceEventKind.reviewAccepted
          ? statement.binding.ruleId
          : null;
      if (event.kind == KnowledgeGovernanceEventKind.reviewAccepted &&
          (ruleId == null || !pack.ruleSet.ruleVersions.containsKey(ruleId))) {
        throw StateError('knowledge_review_requires_exact_rule');
      }
      final checked = await verifier.verify(
        envelope,
        expectedBinding: bindingForNext(current(), pack, ruleId: ruleId),
        expectedRole: role,
        expectedDecision: decision,
        nowUtc: _nowUtc(),
        authorEnvelope: event.kind == KnowledgeGovernanceEventKind.submitted
            ? null
            : record.authorApproval,
      );
      if (!checked.isVerified) {
        throw StateError('knowledge_signature_rejected:${checked.reason}');
      }
      switch (event.kind) {
        case KnowledgeGovernanceEventKind.submitted:
          if (record.status != KnowledgePackStatus.draft ||
              checked.subjectId != pack.authorId) {
            throw StateError('knowledge_invalid_submission');
          }
          final savedSuite = knowledgeMap(event.payload['suite_result']);
          final actualSuite = await _evaluateSuite(pack);
          if (actualSuite['passed'] != true ||
              ruleTestJsonDigest('knowledge-suite-result-v1', savedSuite) !=
                  ruleTestJsonDigest(
                    'knowledge-suite-result-v1',
                    actualSuite,
                  )) {
            throw StateError('knowledge_suite_evidence_mismatch');
          }
          packages[packDigest] = record.copyWith(
            status: KnowledgePackStatus.submitted,
            authorApproval: envelope,
            suiteResult: actualSuite,
          );
        case KnowledgeGovernanceEventKind.reviewAccepted:
          if (record.status != KnowledgePackStatus.submitted ||
              record.reviews.containsKey(ruleId)) {
            throw StateError('knowledge_review_wrong_state');
          }
          final reviews = {...record.reviews, ruleId!: envelope};
          packages[packDigest] = record.copyWith(
            reviews: reviews,
            status: decision == KnowledgeApprovalDecision.rejected
                ? KnowledgePackStatus.rejected
                : reviews.length == pack.ruleSet.rawRules.length
                ? KnowledgePackStatus.reviewed
                : KnowledgePackStatus.submitted,
          );
        case KnowledgeGovernanceEventKind.activated:
          if (record.status != KnowledgePackStatus.reviewed ||
              record.reviews.length != pack.ruleSet.rawRules.length) {
            throw StateError('knowledge_activation_requires_complete_review');
          }
          _requireEngine(pack);
          if ((await _evaluateSuite(pack))['passed'] != true) {
            throw StateError('knowledge_activation_suite_failed');
          }
          if (active != null) {
            packages[active] = packages[active]!.copyWith(
              status: KnowledgePackStatus.superseded,
            );
          }
          packages[packDigest] = record.copyWith(
            status: KnowledgePackStatus.active,
          );
          active = packDigest;
          everManaged = true;
        case KnowledgeGovernanceEventKind.withdrawn:
          if (record.status != KnowledgePackStatus.active ||
              active != packDigest ||
              statement.reason == null ||
              statement.reason!.trim().isEmpty) {
            throw StateError(
              'knowledge_withdraw_requires_active_package_and_reason',
            );
          }
          packages[packDigest] = record.copyWith(
            status: KnowledgePackStatus.withdrawn,
          );
          active = null;
          everManaged = true;
        case KnowledgeGovernanceEventKind.draftSaved:
          throw StateError('Unexpected draft transition');
      }
      approvalSequence++;
      lastEnvelope = envelope.sha256;
    }
    return current();
  }

  void _requireEngine(KnowledgePack pack) {
    if (_engineDigest(pack.ruleSet) != pack.engineDigest) {
      throw StateError('knowledge_engine_binding_mismatch');
    }
  }

  Future<Map<String, dynamic>> _evaluateSuite(KnowledgePack pack) async {
    _requireEngine(pack);
    pack.requireCompleteSuite();
    final results = <Map<String, dynamic>>[];
    for (final test in pack.cases) {
      final report = await const SyntheticRuleTestRunner().run(
        testCase: test.testCase,
        ruleSet: pack.ruleSet,
      );
      final trace = (report.output?.alertsJson['rule_hit_trace'] as List? ?? [])
          .whereType<Map>()
          .where((row) => row['rule_id'] == test.targetRuleId)
          .toList();
      KnowledgeRuleMatch? actual;
      if (trace.length == 1) {
        actual = (trace.single['missing_fields'] as List).isNotEmpty
            ? KnowledgeRuleMatch.unknown
            : trace.single['matched'] == true
            ? KnowledgeRuleMatch.matched
            : KnowledgeRuleMatch.notMatched;
      }
      results.add({
        'case_id': test.testCase.caseId,
        'case_digest': test.testCase.caseDigest,
        'target_rule_id': test.targetRuleId,
        'category': test.category.name,
        'expected_match': test.expectedMatch.name,
        'actual_match': actual?.name,
        'passed':
            report.status == RuleTestRunStatus.passed &&
            actual == test.expectedMatch,
      });
    }
    return {
      'schema_version': 1,
      'suite_digest': pack.suiteDigest,
      'engine_digest': pack.engineDigest,
      'passed': results.isNotEmpty && results.every((r) => r['passed'] == true),
      'clinical_validation': false,
      'cases': results,
    };
  }
}

KnowledgePackRecord _record(KnowledgeGovernanceState state, String digest) =>
    state.packages[digest] ?? (throw StateError('knowledge_unknown_package'));
void _requireAuthorized(bool Function() authorize) {
  if (!authorize()) throw StateError('knowledge_session_changed');
}

KnowledgeRuleResolution _held(String reason, String? head) =>
    KnowledgeRuleResolution._(
      allowed: false,
      reason: reason,
      isPrototypeBaseline: false,
      packageDigest: null,
      rulesVersion: null,
      stateHeadDigest: head,
      rules: const [],
    );
List<RuleRegistryEntry> _immutableRules(RuleTestRuleSet set) =>
    List.unmodifiable(
      RuleRegistryCompiler()
          .compileJsonList(set.rawRules, rulesVersion: set.bundleVersion)
          .map(
            (r) => RuleRegistryEntry(
              ruleId: r.ruleId,
              version: r.version,
              status: r.status,
              ruleType: r.ruleType,
              priorityBand: r.priorityBand,
              specificityBand: r.specificityBand,
              jurisdictions: List.unmodifiable(r.jurisdictions),
              appliesTo: knowledgeFreeze(r.appliesTo) as Map<String, dynamic>,
              conditions: knowledgeFreeze(r.conditions) as Map<String, dynamic>,
              thenClause: RuleThenClause(
                decision: r.thenClause.decision,
                severity: r.thenClause.severity,
                messages: RuleMessageSet(
                  zh: r.thenClause.messages.zh,
                  en: r.thenClause.messages.en,
                  localized: Map.unmodifiable(r.thenClause.messages.localized),
                ),
                actions: List.unmodifiable(
                  r.thenClause.actions.map(
                    (a) => knowledgeFreeze(a) as Map<String, dynamic>,
                  ),
                ),
                outputTags: List.unmodifiable(r.thenClause.outputTags),
              ),
              provenance: RuleProvenance(
                evidenceLevel: r.provenance.evidenceLevel,
                sourceRefs: List.unmodifiable(r.provenance.sourceRefs),
                effectiveFrom: r.provenance.effectiveFrom,
                effectiveTo: r.provenance.effectiveTo,
              ),
              override: r.override == null
                  ? null
                  : knowledgeFreeze(r.override) as Map<String, dynamic>,
            ),
          ),
    );
