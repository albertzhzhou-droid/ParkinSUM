import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/care_portable_data_service.dart';
import 'package:parkinsum_companion/core/services/care_workspace_service.dart';
import 'package:parkinsum_companion/core/services/care_workspace_store.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_entry.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_outcome.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_list_review.dart';
import 'package:parkinsum_companion/domain/entities/decision_support_followup.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/user_portable_data_package_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _owner = 'SYNTHETIC_PRIVATE_OWNER';
final _at = DateTime.utc(2026, 10, 1, 12);
const _service = CarePortableDataService();

CareWorkspaceSnapshot _snapshot() {
  final prompt = DecisionSupportPrompt.create(
    ownerScope: _owner,
    ruleId: 'synthetic_review',
    ruleVersion: '1',
    sourceRecordId: 'meal-1',
    candidateId: 'candidate-1',
    inputSnapshot: {
      'dose': null,
      'nested': {'literal': 'recorderId'},
    },
    title: 'Review input',
    explanation: 'A field is missing.',
    sourceRefs: ['rule:synthetic:1'],
    missingInputs: ['dose'],
    createdAt: _at,
  );
  final feedback = DecisionSupportFeedback.create(
    promptId: prompt.id,
    status: DecisionSupportFollowupStatus.needsReview,
    actorId: _owner,
    actorRole: DecisionSupportFollowupActorRole.user,
    occurredAt: _at,
  );
  return CareWorkspaceSnapshot(
    ownerScope: _owner,
    followups: DecisionSupportFollowupLedger.create(
      ownerScope: _owner,
      prompts: [prompt],
      feedback: [feedback],
    ),
    observations: [
      PersonalObservation.create(
        id: 'observation-1',
        kind: PersonalObservationKind.symptom,
        occurredAt: _at,
        recordedAt: _at,
        originalTimezone: 'UTC',
        source: PersonalObservationSource.selfReported,
        recorderId: _owner,
        status: PersonalObservationStatus.unknown,
        symptomLabel: 'Synthetic stiffness',
        notes: 'UNKNOWN is not zero',
      ),
    ],
    notes: [_note('note-1')],
    medicationDiscussionEntries: [
      CareMedicationDiscussionEntry(
        id: 'medication-1',
        name: 'Synthetic vitamin',
        category: CareMedicationDiscussionCategory.vitamin,
        reportedUse: CareMedicationReportedUse.uncertain,
        ingredientLabel: 'unverified label',
        doseAndScheduleText: null,
        question: 'Bring bottle',
        recordedAt: _at,
        recorderId: _owner,
      ),
    ],
    medicationDiscussionOutcomes: [
      CareMedicationDiscussionOutcome(
        id: 'outcome-1',
        entryId: 'medication-1',
        status: CareMedicationDiscussionOutcomeStatus.followUpNeeded,
        note: 'ask again',
        recordedAt: _at,
        recorderId: _owner,
      ),
    ],
    medicationListReviews: [
      CareMedicationListReview(
        section: CareMedicationListReviewSection.currentSelection,
        recordedAt: _at,
        recorderId: _owner,
      ),
    ],
  );
}

CareDiscussionNote _note(String id, {String text = 'Explicit user question'}) =>
    CareDiscussionNote(id: id, text: text, recordedAt: _at, recorderId: _owner);

String _resign(Map root) {
  Object? sorted(Object? x) {
    if (x is Map) {
      final keys = x.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: sorted(x[k])};
    }
    if (x is List) return x.map(sorted).toList();
    return x;
  }

  root.remove('contentSha256');
  root['contentSha256'] = sha256
      .convert(utf8.encode(jsonEncode(sorted(root))))
      .toString();
  return jsonEncode(root);
}

final class _Store implements CareWorkspaceStore {
  String? value;
  int writes = 0;
  bool rejectBeforeWrite = false;
  bool loseAcknowledgement = false;
  @override
  Future<String?> read(String ownerScope) async => value;
  @override
  Future<void> write(
    String ownerScope,
    String document, {
    required bool Function() authorize,
  }) async {
    if (!authorize()) throw StateError('expired');
    if (rejectBeforeWrite) throw StateError('quota');
    value = document;
    writes += 1;
    if (loseAcknowledgement) throw StateError('ack lost');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'complete same-owner Care roundtrip preserves entire original JSON, IDs and unknowns',
    () {
      final source = _snapshot();
      final artifact = _service.create(snapshot: source, createdAt: _at);
      expect(artifact.json, isNot(contains(_owner)));
      expect(artifact.counts, {
        'observations': 1,
        'notes': 1,
        'medicationDiscussionEntries': 1,
        'medicationDiscussionOutcomes': 1,
        'medicationListReviews': 1,
        'prompts': 1,
        'feedback': 1,
      });
      final target = CareWorkspaceSnapshot.empty(_owner);
      final preview = _service.prepare(
        packageJson: artifact.json,
        current: target,
        sessionEpoch: 7,
      );
      expect(preview.after.toJson(), source.toJson());
      expect(preview.before.toJson(), target.toJson());
      expect(
        preview.after.observations.single.status,
        PersonalObservationStatus.unknown,
      );
      expect(
        preview.after.medicationDiscussionEntries.single.doseAndScheduleText,
        isNull,
      );
      expect(
        preview.after.followups.feedback.single.id,
        source.followups.feedback.single.id,
      );
      if (const bool.fromEnvironment('PARKINSUM_RECORD_CARE_ROUNDTRIP')) {
        // Synthetic observation for the independent host-side review. Normal
        // test runs print no package or health payload.
        debugPrintSynchronously(
          'CARE_ROUNDTRIP_OBSERVATION:${jsonEncode({'original': source.toJson(), 'artifact': jsonDecode(artifact.json), 'restored': preview.after.toJson(), 'before': target.toJson()})}',
        );
      }
    },
  );

  test(
    'legacy general packages are unavailable, distinct from captured empty Care',
    () {
      final legacy = jsonEncode({
        'format': 'parkinsum_user_portable_data_package',
        'schemaVersion': 4,
      });
      expect(_service.availability(legacy), 'unavailable_in_source_schema');
      expect(
        () => _service.prepare(
          packageJson: legacy,
          current: CareWorkspaceSnapshot.empty(_owner),
          sessionEpoch: 0,
        ),
        throwsStateError,
      );
      final empty = _service.create(
        snapshot: CareWorkspaceSnapshot.empty(_owner),
        createdAt: _at,
      );
      expect(
        _service.availability(empty.json),
        'captured_current_local_snapshot',
      );
      expect(empty.counts.values.every((x) => x == 0), isTrue);
    },
  );

  test(
    'wrong owner, future versions, duplicate members and malformed identities fail closed',
    () {
      final artifact = _service.create(snapshot: _snapshot(), createdAt: _at);
      expect(
        () => _service.prepare(
          packageJson: artifact.json,
          current: CareWorkspaceSnapshot.empty('another-owner'),
          sessionEpoch: 0,
        ),
        throwsFormatException,
      );
      final root = jsonDecode(artifact.json) as Map;
      root['schemaVersion'] = 2;
      expect(
        () => _service.prepare(
          packageJson: _resign(root),
          current: CareWorkspaceSnapshot.empty(_owner),
          sessionEpoch: 0,
        ),
        throwsFormatException,
      );
      for (final raw in [
        '{"schemaVersion":1,"schemaVersion":1}',
        '{"schemaVersion":1,"schema\\u0056ersion":1}',
      ]) {
        expect(() => decodeBoundedPortableJson(raw), throwsFormatException);
      }
      final changed = jsonDecode(artifact.json) as Map;
      (((changed['workspace'] as Map)['followups'] as Map)['feedback'] as List)
              .first['id'] =
          'feedback_${'0' * 64}';
      expect(
        () => _service.prepare(
          packageJson: _resign(changed),
          current: CareWorkspaceSnapshot.empty(_owner),
          sessionEpoch: 0,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'resigned payload still rejects duplicate records, unknown references, wrong roles and unknown fields',
    () {
      final raw = _service.create(snapshot: _snapshot(), createdAt: _at).json;
      for (final mutate in <void Function(Map)>[
        (root) {
          final rows = (root['workspace'] as Map)['notes'] as List;
          rows.add(rows.first);
        },
        (root) {
          ((root['workspace'] as Map)['medicationDiscussionOutcomes'] as List)
                  .first['entryId'] =
              'missing';
        },
        (root) {
          ((root['workspace'] as Map)['observations'] as List)
                  .first['recorderId'] =
              'other';
        },
        (root) {
          (root['workspace'] as Map)['unknown'] = true;
        },
      ]) {
        final root = jsonDecode(raw) as Map;
        mutate(root);
        expect(
          () => _service.prepare(
            packageJson: _resign(root),
            current: CareWorkspaceSnapshot.empty(_owner),
            sessionEpoch: 0,
          ),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'conflict preview writes nothing and preserves unrelated target records on valid merge',
    () {
      final artifact = _service.create(snapshot: _snapshot(), createdAt: _at);
      final current = CareWorkspaceSnapshot.empty(
        _owner,
      ).copyWith(notes: [_note('note-1', text: 'Different source content')]);
      final original = jsonEncode(current.toJson());
      expect(
        () => _service.prepare(
          packageJson: artifact.json,
          current: current,
          sessionEpoch: 0,
        ),
        throwsStateError,
      );
      expect(jsonEncode(current.toJson()), original);
      final other = CareWorkspaceSnapshot.empty(
        _owner,
      ).copyWith(notes: [_note('unrelated-note')]);
      final preview = _service.prepare(
        packageJson: artifact.json,
        current: other,
        sessionEpoch: 0,
      );
      expect(preview.after.notes.map((n) => n.id), [
        'unrelated-note',
        'note-1',
      ]);
    },
  );

  test(
    'one Care-key commit is idempotent for identical already-present records',
    () async {
      final store = _Store();
      final service = CareWorkspaceService(store: store);
      final artifact = _service.create(snapshot: _snapshot(), createdAt: _at);
      final preview = _service.prepare(
        packageJson: artifact.json,
        current: CareWorkspaceSnapshot.empty(_owner),
        sessionEpoch: 0,
      );
      await _service.commit(
        preview: preview,
        service: service,
        authorize: () => true,
        confirmed: true,
      );
      expect(store.writes, 1);
      expect((await service.load(_owner)).toJson(), _snapshot().toJson());
      final replay = _service.prepare(
        packageJson: artifact.json,
        current: await service.load(_owner),
        sessionEpoch: 0,
      );
      expect(replay.changesState, isFalse);
      await _service.commit(
        preview: replay,
        service: service,
        authorize: () => true,
        confirmed: true,
      );
      expect(store.writes, 1);
    },
  );

  test(
    'stale preview, absent confirmation, expired authorization and quota reject without writing',
    () async {
      final store = _Store();
      final service = CareWorkspaceService(store: store);
      final empty = CareWorkspaceSnapshot.empty(_owner);
      final preview = _service.prepare(
        packageJson: _service
            .create(snapshot: _snapshot(), createdAt: _at)
            .json,
        current: empty,
        sessionEpoch: 0,
      );
      await expectLater(
        _service.commit(
          preview: preview,
          service: service,
          authorize: () => true,
          confirmed: false,
        ),
        throwsStateError,
      );
      await expectLater(
        _service.commit(
          preview: preview,
          service: service,
          authorize: () => false,
          confirmed: true,
        ),
        throwsStateError,
      );
      store.rejectBeforeWrite = true;
      await expectLater(
        _service.commit(
          preview: preview,
          service: service,
          authorize: () => true,
          confirmed: true,
        ),
        throwsStateError,
      );
      expect(store.value, isNull);
      expect(store.writes, 0);
      store.rejectBeforeWrite = false;
      store.value = jsonEncode(
        empty.copyWith(notes: [_note('changed')]).toJson(),
      );
      final old = store.value;
      await expectLater(
        _service.commit(
          preview: preview,
          service: service,
          authorize: () => true,
          confirmed: true,
        ),
        throwsStateError,
      );
      expect(store.value, old);
      expect(store.writes, 0);
    },
  );

  test(
    'lost acknowledgement is not cancellation; reread verifies accepted single-document write',
    () async {
      final store = _Store()..loseAcknowledgement = true;
      final service = CareWorkspaceService(store: store);
      final preview = _service.prepare(
        packageJson: _service
            .create(snapshot: _snapshot(), createdAt: _at)
            .json,
        current: CareWorkspaceSnapshot.empty(_owner),
        sessionEpoch: 0,
      );
      await expectLater(
        _service.commit(
          preview: preview,
          service: service,
          authorize: () => true,
          confirmed: true,
        ),
        throwsStateError,
      );
      expect(store.writes, 1);
      expect((await service.load(_owner)).toJson(), _snapshot().toJson());
    },
  );

  test(
    'SharedPreferences adapter over mock storage survives a new service and retains other namespaces',
    () async {
      SharedPreferences.setMockInitialValues({
        'db.user_state.v1': 'untouched-user-state',
        'unrelated-reminder': 'inactive',
      });
      final service = CareWorkspaceService(store: LocalCareWorkspaceStore());
      final artifact = _service.create(snapshot: _snapshot(), createdAt: _at);
      final preview = _service.prepare(
        packageJson: artifact.json,
        current: await service.load(_owner),
        sessionEpoch: 0,
      );
      await _service.commit(
        preview: preview,
        service: service,
        authorize: () => true,
        confirmed: true,
      );
      final reloaded = await CareWorkspaceService(
        store: LocalCareWorkspaceStore(),
      ).load(_owner);
      expect(reloaded.toJson(), _snapshot().toJson());
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      expect(prefs.getString('db.user_state.v1'), 'untouched-user-state');
      expect(prefs.getString('unrelated-reminder'), 'inactive');
      expect(
        prefs.getKeys().difference({'db.user_state.v1', 'unrelated-reminder'}),
        {careWorkspaceStorageKey(_owner)},
      );
    },
  );

  test(
    'bounded reader rejects excessive depth and bytes before Care construction',
    () {
      expect(
        () => decodeBoundedPortableJson('x' * 33, maxBytes: 32),
        throwsFormatException,
      );
      expect(
        () => decodeBoundedPortableJson('${'[' * 25}0${']' * 25}'),
        throwsFormatException,
      );
    },
  );
}
