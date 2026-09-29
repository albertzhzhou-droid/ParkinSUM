import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/care_workspace_service.dart';
import 'package:parkinsum_companion/core/services/care_workspace_store.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_entry.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_outcome.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_list_review.dart';
import 'package:parkinsum_companion/domain/entities/decision_support_followup.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/decision_support_followup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _owner = 'account-a';
const _other = 'account-b';
final _time = DateTime.utc(2026, 9, 22, 12);

CareDiscussionNote _note(String id, {String owner = _owner}) =>
    CareDiscussionNote(
      id: id,
      text: 'Discuss this recorded information.',
      recordedAt: _time,
      recorderId: owner,
    );

CareMedicationDiscussionEntry _medicationDiscussionEntry(
  String id, {
  String owner = _owner,
  String? ingredientLabel = 'Example ingredient',
}) => CareMedicationDiscussionEntry(
  id: id,
  name: 'Vitamin D',
  category: CareMedicationDiscussionCategory.supplement,
  reportedUse: CareMedicationReportedUse.uncertain,
  ingredientLabel: ingredientLabel,
  doseAndScheduleText: 'unknown',
  question: 'Check the bottle at the next visit.',
  recordedAt: _time,
  recorderId: owner,
);

CareMedicationDiscussionOutcome _medicationDiscussionOutcome(
  String id, {
  String entryId = 'medication-1',
  String owner = _owner,
}) => CareMedicationDiscussionOutcome(
  id: id,
  entryId: entryId,
  status: CareMedicationDiscussionOutcomeStatus.followUpNeeded,
  note: 'Ask again at the next visit.',
  recordedAt: _time.add(const Duration(minutes: 1)),
  recorderId: owner,
);

CareMedicationListReview _medicationListReview({String owner = _owner}) =>
    CareMedicationListReview(
      section: CareMedicationListReviewSection.overTheCounter,
      recordedAt: _time,
      recorderId: owner,
    );

PersonalObservation _observation(
  String id, {
  String owner = _owner,
  String? notes,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.symptom,
  occurredAt: _time,
  recordedAt: _time,
  originalTimezone: 'UTC',
  source: PersonalObservationSource.selfReported,
  recorderId: owner,
  status: PersonalObservationStatus.unknown,
  symptomLabel: 'Stiffness',
  notes: notes,
);

CareWorkspaceSnapshot _append(CareWorkspaceSnapshot current, String id) =>
    current.copyWith(
      notes: [
        ...current.notes,
        _note(id, owner: current.ownerScope),
      ],
    );

DecisionSupportFollowupLedger _followups({String actor = _owner}) {
  const service = DecisionSupportFollowupService();
  final prompt = DecisionSupportPrompt.create(
    ownerScope: _owner,
    ruleId: 'review',
    ruleVersion: '1',
    sourceRecordId: 'meal-1',
    candidateId: 'candidate-1',
    inputSnapshot: {'dose': null},
    title: 'Review input',
    explanation: 'A recorded field is missing.',
    sourceRefs: ['rule:review:1'],
    missingInputs: ['dose'],
    createdAt: _time,
  );
  final ledger = service.register(
    ledger: DecisionSupportFollowupLedger.empty(_owner),
    ownerScope: _owner,
    prompts: [prompt],
  );
  return service.recordFeedback(
    ledger: ledger,
    ownerScope: _owner,
    promptId: prompt.id,
    status: DecisionSupportFollowupStatus.needsReview,
    actorId: actor,
    actorRole: DecisionSupportFollowupActorRole.user,
    occurredAt: _time,
  );
}

class _ControlledStore implements CareWorkspaceStore {
  final documents = <String, String>{};
  Future<void> Function()? beforeRead;
  Future<void> Function()? beforeWrite;
  Future<void> Function()? afterCommit;
  bool failRead = false;
  bool failWrite = false;
  int reads = 0;
  int attempts = 0;
  int writes = 0;

  @override
  Future<String?> read(String ownerScope) async {
    reads++;
    await beforeRead?.call();
    if (failRead) throw StateError('read_failed');
    return documents[careWorkspaceStorageKey(ownerScope)];
  }

  @override
  Future<void> write(
    String ownerScope,
    String document, {
    required bool Function() authorize,
  }) async {
    attempts++;
    if (!authorize()) throw StateError('care_workspace_session_changed');
    await beforeWrite?.call();
    if (!authorize()) throw StateError('care_workspace_session_changed');
    if (failWrite) throw StateError('write_failed');
    documents[careWorkspaceStorageKey(ownerScope)] = document;
    writes++;
    await afterCommit?.call();
    // Deliberately omit the final authorization check in this test double:
    // the service must still reject success from an expired session.
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'complete schema 5 workspace roundtrips without inventing missing values',
    () {
      final original = CareWorkspaceSnapshot(
        ownerScope: _owner,
        followups: _followups(),
        observations: [_observation('observation-1')],
        notes: [_note('note-1')],
        medicationDiscussionEntries: [
          _medicationDiscussionEntry('medication-1'),
        ],
        medicationDiscussionOutcomes: [
          _medicationDiscussionOutcome('outcome-1'),
        ],
        medicationListReviews: [_medicationListReview()],
      );
      final restored = CareWorkspaceSnapshot.decode(
        jsonEncode(original.toJson()),
        ownerScope: _owner,
      );
      expect(restored.toJson(), original.toJson());
      expect(restored.observations.single.severity, isNull);
      expect(
        restored.observations.single.status,
        PersonalObservationStatus.unknown,
      );
      expect(() => restored.notes.clear(), throwsUnsupportedError);
      expect(() => restored.observations.clear(), throwsUnsupportedError);
      expect(
        restored.medicationDiscussionEntries.single.doseAndScheduleText,
        'unknown',
      );
      expect(
        restored.medicationDiscussionEntries.single.ingredientLabel,
        'Example ingredient',
      );
      expect(
        () => restored.medicationDiscussionEntries.clear(),
        throwsUnsupportedError,
      );
      expect(
        restored.medicationDiscussionOutcomes.single.note,
        'Ask again at the next visit.',
      );
      expect(
        () => restored.medicationDiscussionOutcomes.clear(),
        throwsUnsupportedError,
      );
      expect(
        restored.medicationListReviews.single.section,
        CareMedicationListReviewSection.overTheCounter,
      );
      expect(
        () => restored.medicationListReviews.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('schema 1 workspaces migrate on the next successful write', () async {
    final store = _ControlledStore();
    final service = CareWorkspaceService(store: store);
    final key = careWorkspaceStorageKey(_owner);
    final legacy =
        CareWorkspaceSnapshot(
            ownerScope: _owner,
            followups: _followups(),
            observations: [_observation('legacy-observation')],
            notes: [_note('legacy-note')],
          ).toJson()
          ..['schemaVersion'] = 1
          ..remove('medicationDiscussionEntries');
    legacy.remove('medicationDiscussionOutcomes');
    legacy.remove('medicationListReviews');
    final legacyFollowups = legacy['followups'] as Map<String, Object?>;
    legacyFollowups['schemaVersion'] = 1;
    for (final row in legacyFollowups['feedback'] as List<Object?>) {
      (row as Map<String, Object?>).remove('reasonCategory');
    }
    final rawLegacy = jsonEncode(legacy);
    store.documents[key] = rawLegacy;

    final loaded = await service.load(_owner);
    expect(loaded.observations.single.id, 'legacy-observation');
    expect(loaded.notes.single.id, 'legacy-note');
    expect(loaded.medicationDiscussionEntries, isEmpty);
    expect(loaded.toJson()['schemaVersion'], careWorkspaceSchemaVersion);
    expect(
      (loaded.toJson()['followups']! as Map<String, Object?>)['schemaVersion'],
      DecisionSupportFollowupLedger.schemaVersion,
    );
    expect(
      store.documents[key],
      rawLegacy,
      reason: 'load must remain read-only',
    );

    final migrated = await service.mutate(
      _owner,
      (current) => current.copyWith(notes: [...current.notes, _note('after')]),
      authorize: () => true,
    );
    final stored = jsonDecode(store.documents[key]!) as Map<String, dynamic>;
    expect(migrated.notes.map((note) => note.id), ['legacy-note', 'after']);
    expect(stored['schemaVersion'], careWorkspaceSchemaVersion);
    expect(stored['medicationDiscussionEntries'], isEmpty);
    expect(
      (stored['followups'] as Map<String, dynamic>)['schemaVersion'],
      DecisionSupportFollowupLedger.schemaVersion,
    );
  });

  test(
    'schema 2 workspaces read without writing and migrate entries to v5',
    () async {
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      final key = careWorkspaceStorageKey(_owner);
      final legacy =
          CareWorkspaceSnapshot(
              ownerScope: _owner,
              followups: _followups(),
              medicationDiscussionEntries: [
                _medicationDiscussionEntry('legacy-medication'),
              ],
            ).toJson()
            ..['schemaVersion'] = 2
            ..remove('medicationDiscussionOutcomes')
            ..remove('medicationListReviews')
            ..['medicationDiscussionEntries'] = [
              _medicationDiscussionEntry('legacy-medication').toJson()
                ..remove('ingredientLabel'),
            ];
      final rawLegacy = jsonEncode(legacy);
      store.documents[key] = rawLegacy;

      final loaded = await service.load(_owner);
      expect(loaded.medicationDiscussionEntries.single.id, 'legacy-medication');
      expect(loaded.medicationDiscussionEntries.single.ingredientLabel, isNull);
      expect(
        store.documents[key],
        rawLegacy,
        reason: 'load must remain read-only',
      );

      await service.mutate(
        _owner,
        (current) =>
            current.copyWith(notes: [...current.notes, _note('after')]),
        authorize: () => true,
      );
      final stored = jsonDecode(store.documents[key]!) as Map<String, dynamic>;
      expect(stored['schemaVersion'], 5);
      expect(
        (stored['medicationDiscussionEntries'] as List)
            .single['ingredientLabel'],
        isNull,
      );
    },
  );

  test(
    'schema 3 workspaces retain ingredient labels and migrate on write',
    () async {
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      final key = careWorkspaceStorageKey(_owner);
      final legacy =
          CareWorkspaceSnapshot(
              ownerScope: _owner,
              followups: _followups(),
              medicationDiscussionEntries: [
                _medicationDiscussionEntry('v3-medication'),
              ],
            ).toJson()
            ..['schemaVersion'] = 3
            ..remove('medicationDiscussionOutcomes')
            ..remove('medicationListReviews');
      final rawLegacy = jsonEncode(legacy);
      store.documents[key] = rawLegacy;

      final loaded = await service.load(_owner);
      expect(
        loaded.medicationDiscussionEntries.single.ingredientLabel,
        'Example ingredient',
      );
      expect(loaded.medicationDiscussionOutcomes, isEmpty);
      expect(store.documents[key], rawLegacy);

      await service.mutate(
        _owner,
        (current) =>
            current.copyWith(notes: [...current.notes, _note('after')]),
        authorize: () => true,
      );
      final stored = jsonDecode(store.documents[key]!) as Map<String, dynamic>;
      expect(stored['schemaVersion'], 5);
      expect(stored['medicationDiscussionOutcomes'], isEmpty);
    },
  );

  test(
    'schema 4 loads read-only and migrates on the next successful write',
    () async {
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      final key = careWorkspaceStorageKey(_owner);
      final legacy =
          CareWorkspaceSnapshot(
              ownerScope: _owner,
              followups: _followups(),
              medicationDiscussionEntries: [
                _medicationDiscussionEntry('v4-item'),
              ],
              medicationDiscussionOutcomes: [
                _medicationDiscussionOutcome('v4-outcome', entryId: 'v4-item'),
              ],
            ).toJson()
            ..['schemaVersion'] = 4
            ..remove('medicationListReviews');
      final rawLegacy = jsonEncode(legacy);
      store.documents[key] = rawLegacy;

      final loaded = await service.load(_owner);
      expect(loaded.medicationDiscussionEntries.single.id, 'v4-item');
      expect(loaded.medicationDiscussionOutcomes.single.id, 'v4-outcome');
      expect(loaded.medicationListReviews, isEmpty);
      expect(store.documents[key], rawLegacy);

      await service.mutate(
        _owner,
        (current) =>
            current.copyWith(medicationListReviews: [_medicationListReview()]),
        authorize: () => true,
      );
      final migrated = CareWorkspaceSnapshot.decode(
        store.documents[key]!,
        ownerScope: _owner,
      );
      expect(migrated.toJson()['schemaVersion'], 5);
      expect(
        migrated.medicationListReviews.single.section,
        CareMedicationListReviewSection.overTheCounter,
      );
    },
  );

  test('review marks remain owner-bound and unique by category', () {
    expect(
      () => CareWorkspaceSnapshot(
        ownerScope: _owner,
        followups: _followups(),
        medicationListReviews: [_medicationListReview(owner: _other)],
      ),
      throwsFormatException,
    );
    expect(
      () => CareWorkspaceSnapshot(
        ownerScope: _owner,
        followups: _followups(),
        medicationListReviews: [
          _medicationListReview(),
          _medicationListReview(),
        ],
      ),
      throwsFormatException,
    );
  });

  test(
    'storage keys isolate owners and contain no readable account identifier',
    () {
      final first = careWorkspaceStorageKey(_owner);
      expect(first, isNot(contains(_owner)));
      expect(first, isNot(careWorkspaceStorageKey(_other)));
      for (final invalid in ['', ' ', 'a\n', 'a' * 513]) {
        expect(() => careWorkspaceStorageKey(invalid), throwsArgumentError);
      }
    },
  );

  test(
    'notes reject missing timezone, invalid date overflow and unknown fields',
    () {
      final json = _note('note').toJson();
      for (final invalid in [
        '2026-09-22T12:00:00',
        '2026-02-30T12:00:00Z',
        '2026-13-22T12:00:00Z',
        '2026-09-22T25:00:00Z',
        '2026-09-22T12:00:00+14:01',
      ]) {
        expect(
          () => CareDiscussionNote.fromJson({...json, 'recordedAt': invalid}),
          throwsFormatException,
        );
      }
      expect(
        () => CareDiscussionNote.fromJson({...json, 'accepted': true}),
        throwsFormatException,
      );
      expect(
        () => CareDiscussionNote.fromJson({...json, 'text': 3}),
        throwsFormatException,
      );
      expect(
        () => CareDiscussionNote.fromJson({...json, 'text': 'bad\u0000text'}),
        throwsFormatException,
      );
      final valid = CareDiscussionNote.fromJson({
        ...json,
        'recordedAt': '2026-09-22T08:00:00-04:00',
      });
      expect(valid.recordedAt, _time);
      expect(valid.recordedAt.isUtc, isTrue);
    },
  );

  test(
    'snapshot rejects foreign recorders, feedback actors and duplicate IDs',
    () {
      final empty = CareWorkspaceSnapshot.empty(_owner);
      expect(
        () => empty.copyWith(notes: [_note('foreign', owner: _other)]),
        throwsFormatException,
      );
      expect(
        () => empty.copyWith(
          observations: [_observation('foreign', owner: _other)],
        ),
        throwsFormatException,
      );
      expect(
        () => empty.copyWith(followups: _followups(actor: _other)),
        throwsFormatException,
      );
      expect(
        () => empty.copyWith(
          medicationDiscussionEntries: [
            _medicationDiscussionEntry('foreign', owner: _other),
          ],
        ),
        throwsFormatException,
      );
      expect(
        () => empty.copyWith(notes: [_note('same'), _note('same')]),
        throwsFormatException,
      );
      expect(
        () => empty.copyWith(
          observations: [_observation('same'), _observation('same')],
        ),
        throwsFormatException,
      );
      expect(
        () => empty.copyWith(
          medicationDiscussionEntries: [
            _medicationDiscussionEntry('same'),
            _medicationDiscussionEntry('same'),
          ],
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'strict restore rejects malformed or incomplete envelopes and foreign owners',
    () {
      final original = CareWorkspaceSnapshot.empty(_owner).copyWith(
        observations: [_observation('observation')],
        notes: [_note('note')],
        medicationDiscussionEntries: [_medicationDiscussionEntry('medication')],
        medicationDiscussionOutcomes: [
          _medicationDiscussionOutcome('outcome', entryId: 'medication'),
        ],
      );
      final edits = <void Function(Map<String, dynamic>)>[
        (json) => json['schemaVersion'] = 1.0,
        (json) => json['schemaVersion'] = 6,
        (json) => json['ownerScope'] = _other,
        (json) => json['unknown'] = true,
        (json) => json.remove('notes'),
        (json) => json['notes'] = 'wrong type',
        (json) => json.remove('medicationDiscussionEntries'),
        (json) => json['medicationDiscussionEntries'] = 'wrong type',
        (json) => json['medicationDiscussionEntries'][0]['recorderId'] = _other,
        (json) => json['medicationDiscussionEntries'][0]['recordedAt'] =
            '2026-09-22T12:00:00',
        (json) => json['medicationDiscussionEntries'] = List.filled(
          129,
          json['medicationDiscussionEntries'][0],
        ),
        (json) => json.remove('medicationDiscussionOutcomes'),
        (json) => json['medicationDiscussionOutcomes'] = 'wrong type',
        (json) =>
            json['medicationDiscussionOutcomes'][0]['recorderId'] = _other,
        (json) => json['medicationDiscussionOutcomes'][0]['entryId'] = 'other',
        (json) => json['medicationDiscussionOutcomes'][0]['status'] =
            'clinicianApproved',
        (json) => json['medicationDiscussionOutcomes'] = List.filled(
          513,
          json['medicationDiscussionOutcomes'][0],
        ),
        (json) => json['notes'][0]['recorderId'] = _other,
        (json) => json['observations'][0]['recorderId'] = _other,
        (json) => json['observations'][0].remove('severity'),
        (json) =>
            json['observations'][0]['occurredAt'] = '2026-02-30T12:00:00Z',
        (json) => json['observations'][0]['recordedAt'] = '2026-09-22T12:00:00',
        (json) => json['notes'] = List.filled(201, json['notes'][0]),
        (json) =>
            json['observations'] = List.filled(5001, json['observations'][0]),
      ];
      for (final edit in edits) {
        final json =
            jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>;
        edit(json);
        expect(
          () => CareWorkspaceSnapshot.decode(
            jsonEncode(json),
            ownerScope: _owner,
          ),
          throwsFormatException,
        );
      }
      for (final raw in ['[]', 'null', 'true', '{']) {
        expect(
          () => CareWorkspaceSnapshot.decode(raw, ownerScope: _owner),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'corrupt or newer saved data is never treated as an empty workspace',
    () async {
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      final key = careWorkspaceStorageKey(_owner);
      final newer = CareWorkspaceSnapshot.empty(_owner).toJson()
        ..['schemaVersion'] = 99;
      for (final raw in ['broken document', jsonEncode(newer)]) {
        store.documents[key] = raw;
        var transformed = false;
        await expectLater(
          service.mutate(_owner, (current) {
            transformed = true;
            return _append(current, 'new');
          }, authorize: () => true),
          throwsFormatException,
        );
        expect(transformed, isFalse);
        expect(store.documents[key], raw);
        expect(store.writes, 0);
      }
      expect((await service.load(_other)).notes, isEmpty);
    },
  );

  test(
    'concurrent updates read the preceding commit and lose no notes',
    () async {
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      final entered = Completer<void>();
      final release = Completer<void>();
      store.beforeWrite = () async {
        if (!entered.isCompleted) entered.complete();
        await release.future;
      };
      final futures = List.generate(
        20,
        (index) => service.mutate(
          _owner,
          (current) => _append(current, 'note-$index'),
          authorize: () => true,
        ),
      );
      await entered.future;
      expect(store.reads, 1);
      release.complete();
      final results = await Future.wait(futures);
      expect(
        results.map((snapshot) => snapshot.notes.length).toList(),
        List.generate(20, (index) => index + 1),
      );
      expect(
        (await service.load(_owner)).notes.map((note) => note.id).toList(),
        List.generate(20, (index) => 'note-$index'),
      );
    },
  );

  test(
    'loads participate in the transaction queue and observe a coherent snapshot',
    () async {
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      final entered = Completer<void>();
      final release = Completer<void>();
      store.beforeRead = () async {
        if (store.reads == 1) {
          entered.complete();
          await release.future;
        }
      };
      final load = service.load(_owner);
      await entered.future;
      final write = service.mutate(
        _owner,
        (current) => _append(current, 'later'),
        authorize: () => true,
      );
      expect(store.reads, 1);
      release.complete();
      expect((await load).notes, isEmpty);
      expect((await write).notes.single.id, 'later');
    },
  );

  test(
    'read failures preserve storage and do not poison subsequent transactions',
    () async {
      final store = _ControlledStore()..failRead = true;
      final service = CareWorkspaceService(store: store);
      await expectLater(
        service.mutate(
          _owner,
          (current) => _append(current, 'lost'),
          authorize: () => true,
        ),
        throwsStateError,
      );
      expect(store.writes, 0);
      store.failRead = false;
      final recovered = await service.mutate(
        _owner,
        (current) => _append(current, 'saved'),
        authorize: () => true,
      );
      expect(recovered.notes.single.id, 'saved');
    },
  );

  test(
    'failed writes do not return new state or erase the preceding commit',
    () async {
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      await service.mutate(
        _owner,
        (current) => _append(current, 'existing'),
        authorize: () => true,
      );
      final before = Map.of(store.documents);
      store.failWrite = true;
      await expectLater(
        service.mutate(
          _owner,
          (current) => _append(current, 'failed'),
          authorize: () => true,
        ),
        throwsStateError,
      );
      expect(store.documents, before);
      expect((await service.load(_owner)).notes.single.id, 'existing');
      store.failWrite = false;
      final next = await service.mutate(
        _owner,
        (current) => _append(current, 'recovered'),
        authorize: () => true,
      );
      expect(next.notes.map((note) => note.id), ['existing', 'recovered']);
    },
  );

  test(
    'no-op updates avoid writes but cannot bypass authorization after transform',
    () async {
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      await service.mutate(_owner, (current) => current, authorize: () => true);
      expect(store.attempts, 0);
      var authorized = true;
      await expectLater(
        service.mutate(_owner, (current) {
          authorized = false;
          return current;
        }, authorize: () => authorized),
        throwsStateError,
      );
      expect(store.attempts, 0);
    },
  );

  test(
    'denied reads and writes never access storage or invoke a transform',
    () async {
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      var transformed = false;
      await expectLater(
        service.load(_owner, authorize: () => false),
        throwsStateError,
      );
      await expectLater(
        service.mutate(_owner, (current) {
          transformed = true;
          return current;
        }, authorize: () => false),
        throwsStateError,
      );
      expect(store.reads, 0);
      expect(store.writes, 0);
      expect(transformed, isFalse);
    },
  );

  test(
    'authorization revoked during read prevents both disclosure and mutation',
    () async {
      for (final mutate in [false, true]) {
        var authorized = true;
        var transformed = false;
        final store = _ControlledStore();
        final service = CareWorkspaceService(store: store);
        final entered = Completer<void>();
        final release = Completer<void>();
        store.beforeRead = () async {
          entered.complete();
          await release.future;
        };
        final operation = mutate
            ? service.mutate(_owner, (current) {
                transformed = true;
                return _append(current, 'forbidden');
              }, authorize: () => authorized)
            : service.load(_owner, authorize: () => authorized);
        final expectation = expectLater(operation, throwsStateError);
        await entered.future;
        authorized = false;
        release.complete();
        await expectation;
        expect(transformed, isFalse);
        expect(store.writes, 0);
      }
    },
  );

  test(
    'authorization is rechecked when a queued operation finally starts',
    () async {
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      final entered = Completer<void>();
      final release = Completer<void>();
      store.beforeWrite = () async {
        entered.complete();
        await release.future;
      };
      final first = service.mutate(
        _owner,
        (current) => _append(current, 'first'),
        authorize: () => true,
      );
      await entered.future;
      var authorized = true;
      final second = service.mutate(
        _owner,
        (current) => _append(current, 'denied'),
        authorize: () => authorized,
      );
      final rejected = expectLater(second, throwsStateError);
      authorized = false;
      release.complete();
      await first;
      await rejected;
      expect(store.reads, 1);
      expect(store.writes, 1);
    },
  );

  test('authorization revoked before commit prevents the write', () async {
    var authorized = true;
    final store = _ControlledStore();
    final service = CareWorkspaceService(store: store);
    final entered = Completer<void>();
    final release = Completer<void>();
    store.beforeWrite = () async {
      entered.complete();
      await release.future;
    };
    final operation = service.mutate(
      _owner,
      (current) => _append(current, 'denied'),
      authorize: () => authorized,
    );
    final expectation = expectLater(operation, throwsStateError);
    await entered.future;
    authorized = false;
    release.complete();
    await expectation;
    expect(store.documents, isEmpty);
  });

  test(
    'authorization revoked after commit never reports success or crosses account keys',
    () async {
      var authorized = true;
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      final entered = Completer<void>();
      final release = Completer<void>();
      store.afterCommit = () async {
        entered.complete();
        await release.future;
      };
      final operation = service.mutate(
        _owner,
        (current) => _append(current, 'submitted'),
        authorize: () => authorized,
      );
      final expectation = expectLater(operation, throwsStateError);
      await entered.future;
      authorized = false;
      release.complete();
      await expectation;
      expect(store.documents.keys, [careWorkspaceStorageKey(_owner)]);
      expect((await service.load(_other)).notes, isEmpty);
      expect((await service.load(_owner)).notes.single.id, 'submitted');
    },
  );

  test('a transform cannot replace the owner workspace', () async {
    final store = _ControlledStore();
    final service = CareWorkspaceService(store: store);
    await expectLater(
      service.mutate(
        _owner,
        (_) => CareWorkspaceSnapshot.empty(_other),
        authorize: () => true,
      ),
      throwsStateError,
    );
    expect(store.writes, 0);
  });

  test(
    'payload limits count UTF-8 bytes on restore and reject before writing',
    () async {
      final oversize = '界' * (careWorkspaceMaxBytes ~/ 3 + 1);
      expect(oversize.length, lessThan(careWorkspaceMaxBytes));
      expect(
        () => CareWorkspaceSnapshot.decode(oversize, ownerScope: _owner),
        throwsFormatException,
      );
      final store = _ControlledStore();
      final service = CareWorkspaceService(store: store);
      final observations = List.generate(
        750,
        (index) => _observation('observation-$index', notes: '界' * 4000),
      );
      await expectLater(
        service.mutate(
          _owner,
          (current) => current.copyWith(observations: observations),
          authorize: () => true,
        ),
        throwsStateError,
      );
      expect(store.attempts, 0);
      expect(store.documents, isEmpty);
    },
  );

  test(
    'memory store refuses unauthorized and oversized direct writes',
    () async {
      final store = MemoryCareWorkspaceStore();
      await expectLater(
        store.write(_owner, '{}', authorize: () => false),
        throwsStateError,
      );
      await expectLater(
        store.write(
          _owner,
          'x' * (careWorkspaceMaxBytes + 1),
          authorize: () => true,
        ),
        throwsStateError,
      );
      expect(store.documents, isEmpty);
    },
  );

  test(
    'local store persists separate owner keys and surfaces malformed stored types',
    () async {
      SharedPreferences.setMockInitialValues({});
      final store = LocalCareWorkspaceStore();
      final service = CareWorkspaceService(store: store);
      await service.mutate(
        _owner,
        (current) => _append(current, 'a'),
        authorize: () => true,
      );
      await service.mutate(
        _other,
        (current) => _append(current, 'b'),
        authorize: () => true,
      );
      expect((await service.load(_owner)).notes.single.id, 'a');
      expect((await service.load(_other)).notes.single.id, 'b');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys(), {
        careWorkspaceStorageKey(_owner),
        careWorkspaceStorageKey(_other),
      });
      await expectLater(
        store.write(_owner, '{}', authorize: () => false),
        throwsStateError,
      );
      await prefs.setInt(careWorkspaceStorageKey(_owner), 7);
      await expectLater(
        service.mutate(
          _owner,
          (current) => _append(current, 'never'),
          authorize: () => true,
        ),
        throwsA(isA<TypeError>()),
      );
      expect(prefs.getInt(careWorkspaceStorageKey(_owner)), 7);
    },
  );
}
