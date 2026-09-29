import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/decision_support_followup.dart';
import 'package:parkinsum_companion/domain/usecases/decision_support_followup_service.dart';

void main() {
  const owner = 'followup-owner';
  const service = DecisionSupportFollowupService();
  final createdAt = DateTime.utc(2026, 9, 22, 12);
  final actionAt = createdAt.add(const Duration(minutes: 5));

  DecisionSupportPrompt prompt({
    String ownerScope = owner,
    String ruleVersion = '1',
    String sourceRecordId = 'meal-1',
    String candidateId = 'candidate-1',
    String explanation = 'Review the recorded information with your clinician.',
    Map<String, Object?>? inputs,
    List<String> sourceRefs = const ['label:revision-2', 'rule:review-1'],
    List<String> missingInputs = const ['recorded dose'],
    DateTime? time,
  }) => DecisionSupportPrompt.create(
    ownerScope: ownerScope,
    ruleId: 'review-record',
    ruleVersion: ruleVersion,
    sourceRecordId: sourceRecordId,
    candidateId: candidateId,
    inputSnapshot: inputs ?? {'mealId': 'meal-1', 'dose': null},
    title: 'Information to review',
    explanation: explanation,
    sourceRefs: sourceRefs,
    missingInputs: missingInputs,
    createdAt: time ?? createdAt,
  );

  DecisionSupportFollowupLedger registered([DecisionSupportPrompt? item]) =>
      service.register(
        ledger: DecisionSupportFollowupLedger.empty(owner),
        ownerScope: owner,
        prompts: [item ?? prompt()],
      );

  DecisionSupportFollowupLedger act(
    DecisionSupportFollowupLedger ledger,
    DecisionSupportFollowupStatus status, {
    String actorId = 'local-person',
    DateTime? at,
    String? reason,
    DecisionSupportFeedbackReasonCategory? reasonCategory,
    DateTime? until,
  }) => service.recordFeedback(
    ledger: ledger,
    ownerScope: owner,
    promptId: ledger.prompts.first.id,
    status: status,
    actorId: actorId,
    actorRole: DecisionSupportFollowupActorRole.user,
    occurredAt: at ?? actionAt,
    reason: reason,
    reasonCategory: reasonCategory,
    snoozedUntil: until,
  );

  DecisionSupportFollowupItem projection(
    DecisionSupportFollowupLedger ledger, {
    DateTime? now,
  }) => service
      .project(ledger: ledger, ownerScope: owner, now: now ?? actionAt)
      .single;

  Map<String, dynamic> encoded(DecisionSupportFollowupLedger ledger) =>
      jsonDecode(jsonEncode(ledger.toJson())) as Map<String, dynamic>;

  Map<String, dynamic> asLegacyLedger(
    DecisionSupportFollowupLedger ledger,
    int version,
  ) {
    final json = encoded(ledger)..['schemaVersion'] = version;
    String canonical(Object? value) {
      if (value is Map) {
        final keys = value.keys.cast<String>().toList()..sort();
        return '{${keys.map((key) => '${jsonEncode(key)}:${canonical(value[key])}').join(',')}}';
      }
      if (value is List) return '[${value.map(canonical).join(',')}]';
      return jsonEncode(value);
    }

    for (final row in json['feedback'] as List) {
      final event = row as Map<String, dynamic>;
      event.remove('reasonCategory');
      final fields = Map<String, dynamic>.from(event)..remove('id');
      event['id'] =
          'feedback_${sha256.convert(utf8.encode(canonical(fields)))}';
    }
    return json;
  }

  test(
    'identity canonicalizes map keys and provenance order, not evaluation time',
    () {
      final first = prompt(
        inputs: {
          'record': {'dose': null, 'protein': 12},
          'mealId': 'meal-1',
        },
      );
      final repeated = prompt(
        inputs: {
          'mealId': 'meal-1',
          'record': {'protein': 12, 'dose': null},
        },
        sourceRefs: ['rule:review-1', 'label:revision-2'],
        time: actionAt,
      );
      expect(repeated.id, first.id);
      expect(repeated.inputSnapshotDigest, first.inputSnapshotDigest);
    },
  );

  test(
    'changed inputs, rule version, source, candidate, and owner stay distinct',
    () {
      final variants = [
        prompt(),
        prompt(inputs: {'mealId': 'meal-1', 'dose': 100}),
        prompt(ruleVersion: '2'),
        prompt(sourceRecordId: 'meal-2'),
        prompt(candidateId: 'candidate-2'),
        prompt(ownerScope: 'another-owner'),
        prompt(
          explanation: 'The wording of this source explanation was revised.',
        ),
        prompt(sourceRefs: ['label:revision-3']),
        prompt(missingInputs: ['route']),
      ];
      expect(
        variants.map((item) => item.id).toSet(),
        hasLength(variants.length),
      );
    },
  );

  test('same evaluation preserves the original snapshot and user history', () {
    final first = registered();
    final read = act(first, DecisionSupportFollowupStatus.read);
    final again = service.register(
      ledger: read,
      ownerScope: owner,
      prompts: [prompt(time: actionAt)],
    );
    expect(identical(again, read), isTrue);
    expect(again.prompts, hasLength(1));
    expect(again.prompts.single.createdAt, createdAt);
    expect(projection(again).status, DecisionSupportFollowupStatus.read);
    expect(first.feedback, isEmpty);
  });

  test('revised context starts unread without borrowing old feedback', () {
    final dismissed = act(
      registered(),
      DecisionSupportFollowupStatus.dismissed,
      reason: 'This record has already been corrected.',
      reasonCategory:
          DecisionSupportFeedbackReasonCategory.informationMayBeIncorrect,
    );
    final changed = prompt(ruleVersion: '2', time: actionAt);
    final combined = service.register(
      ledger: dismissed,
      ownerScope: owner,
      prompts: [changed],
    );
    final items = service.project(
      ledger: combined,
      ownerScope: owner,
      now: actionAt,
    );
    expect(items, hasLength(2));
    expect(items.first.prompt.id, changed.id);
    expect(items.first.status, DecisionSupportFollowupStatus.unread);
    expect(items.first.history, isEmpty);
    expect(items.last.status, DecisionSupportFollowupStatus.dismissed);
  });

  test('inputs and history are deeply immutable snapshots', () {
    final list = <Object?>['typed'];
    final details = <String, Object?>{'sources': list};
    final item = prompt(inputs: {'details': details});
    list.add('later');
    details['dose'] = 200;
    final nested = item.inputSnapshot['details']! as Map<String, Object?>;
    expect(nested, {
      'sources': ['typed'],
    });
    expect(() => nested['dose'] = 100, throwsUnsupportedError);
    expect(
      () => (nested['sources']! as List).add('changed'),
      throwsUnsupportedError,
    );
    expect(() => item.sourceRefs.add('changed'), throwsUnsupportedError);
    final ledger = registered(item);
    expect(() => ledger.prompts.clear(), throwsUnsupportedError);
    expect(() => projection(ledger).history.clear(), throwsUnsupportedError);
  });

  test('engine-selected choices never create user feedback or acceptance', () {
    final ledger = registered(
      prompt(
        inputs: {
          'acceptedChoicesJson': '["engine-candidate-1"]',
          'selectedByEngine': true,
        },
      ),
    );
    final view = projection(ledger);
    expect(view.status, DecisionSupportFollowupStatus.unread);
    expect(view.hasUserFeedback, isFalse);
    expect(view.isSuppressed, isFalse);
    expect(ledger.feedback, isEmpty);
    expect(view.prompt.missingInputs, ['recorded dose']);
    expect(view.prompt.sourceRefs, ['label:revision-2', 'rule:review-1']);
  });

  test(
    'schema 3 JSON roundtrip preserves reasons, actor and the exact explanation',
    () {
      final ledger = act(
        registered(),
        DecisionSupportFollowupStatus.dismissed,
        reason: 'Reviewed with my caregiver; entered twice.',
        reasonCategory:
            DecisionSupportFeedbackReasonCategory.duplicateOrAlreadyAddressed,
      );
      final json = encoded(ledger);
      expect(json['schemaVersion'], 3);
      final restored = DecisionSupportFollowupLedger.fromJson(
        json,
        ownerScope: owner,
      );
      expect(restored.toJson(), ledger.toJson());
      expect(restored.feedback.single.actorId, 'local-person');
      expect(
        restored.feedback.single.reasonCategory,
        DecisionSupportFeedbackReasonCategory.duplicateOrAlreadyAddressed,
      );
      expect(
        restored.feedback.single.actorRole,
        DecisionSupportFollowupActorRole.user,
      );
      expect(
        projection(restored).status,
        DecisionSupportFollowupStatus.dismissed,
      );
    },
  );

  test('schemas 1 and 2 migrate old reason categories as unclassified', () {
    final legacyV1 = asLegacyLedger(
      act(
        registered(),
        DecisionSupportFollowupStatus.dismissed,
        reason: 'Already reviewed.',
        reasonCategory: DecisionSupportFeedbackReasonCategory.other,
      ),
      1,
    );
    final migratedV1 = DecisionSupportFollowupLedger.fromJson(
      legacyV1,
      ownerScope: owner,
    );
    expect(migratedV1.toJson()['schemaVersion'], 3);
    expect(
      migratedV1.feedback.single.status,
      DecisionSupportFollowupStatus.dismissed,
    );
    expect(migratedV1.feedback.single.reason, 'Already reviewed.');
    expect(migratedV1.feedback.single.reasonCategory, isNull);

    final legacyV2 = asLegacyLedger(
      act(
        registered(),
        DecisionSupportFollowupStatus.notApplicable,
        reason: 'This does not fit my situation.',
        reasonCategory: DecisionSupportFeedbackReasonCategory.contextMismatch,
      ),
      2,
    );
    final migratedV2 = DecisionSupportFollowupLedger.fromJson(
      legacyV2,
      ownerScope: owner,
    );
    expect(migratedV2.toJson()['schemaVersion'], 3);
    expect(
      migratedV2.feedback.single.status,
      DecisionSupportFollowupStatus.notApplicable,
    );
    expect(migratedV2.feedback.single.reasonCategory, isNull);

    final invalidV1 = asLegacyLedger(
      act(
        registered(),
        DecisionSupportFollowupStatus.notApplicable,
        reason: 'This does not fit my situation.',
        reasonCategory: DecisionSupportFeedbackReasonCategory.contextMismatch,
      ),
      1,
    );
    expect(
      () =>
          DecisionSupportFollowupLedger.fromJson(invalidV1, ownerScope: owner),
      throwsFormatException,
    );
  });

  test('not-applicable and declined are reasoned closed workflow states', () {
    for (final status in [
      DecisionSupportFollowupStatus.notApplicable,
      DecisionSupportFollowupStatus.declined,
    ]) {
      for (final reason in <String?>[null, '', '   ']) {
        expect(
          () => act(
            registered(),
            status,
            reason: reason,
            reasonCategory: DecisionSupportFeedbackReasonCategory.other,
          ),
          throwsFormatException,
          reason: '${status.name} requires a non-empty reason',
        );
      }
      expect(
        () => act(registered(), status, reason: 'A reason without a category.'),
        throwsFormatException,
        reason: '${status.name} requires a category',
      );
      final closed = act(
        registered(),
        status,
        reason: 'Recorded as my choice only.',
        reasonCategory: DecisionSupportFeedbackReasonCategory.contextMismatch,
      );
      expect(projection(closed).isClosed, isTrue);
      expect(projection(closed).isSuppressed, isTrue);
      expect(
        () => act(closed, DecisionSupportFollowupStatus.read),
        throwsFormatException,
      );
      final reopened = act(
        closed,
        DecisionSupportFollowupStatus.needsReview,
        at: actionAt.add(const Duration(minutes: 1)),
      );
      expect(projection(reopened).isClosed, isFalse);
      expect(reopened.feedback.first.reason, 'Recorded as my choice only.');
      expect(
        reopened.feedback.first.reasonCategory,
        DecisionSupportFeedbackReasonCategory.contextMismatch,
      );
    }
  });

  test('new closed feedback cannot bypass its owner-selected category', () {
    final promptId = registered().prompts.single.id;
    for (final status in [
      DecisionSupportFollowupStatus.dismissed,
      DecisionSupportFollowupStatus.notApplicable,
      DecisionSupportFollowupStatus.declined,
    ]) {
      expect(
        () => DecisionSupportFeedback.create(
          promptId: promptId,
          status: status,
          actorId: 'local-person',
          actorRole: DecisionSupportFollowupActorRole.user,
          occurredAt: actionAt,
          reason: 'Recorded as an explicit workflow choice.',
        ),
        throwsFormatException,
      );
    }
  });

  test('reason category affects feedback identity and restores exactly', () {
    final contextMismatch = act(
      registered(),
      DecisionSupportFollowupStatus.notApplicable,
      reason: 'This does not fit my situation.',
      reasonCategory: DecisionSupportFeedbackReasonCategory.contextMismatch,
    );
    final informationIssue = act(
      registered(),
      DecisionSupportFollowupStatus.notApplicable,
      reason: 'This does not fit my situation.',
      reasonCategory:
          DecisionSupportFeedbackReasonCategory.informationMayBeIncorrect,
    );
    expect(
      contextMismatch.feedback.single.id,
      isNot(informationIssue.feedback.single.id),
    );
    final restored = DecisionSupportFollowupLedger.fromJson(
      encoded(contextMismatch),
      ownerScope: owner,
    );
    expect(
      restored.feedback.single.reasonCategory,
      DecisionSupportFeedbackReasonCategory.contextMismatch,
    );
  });

  test(
    'snooze suppresses until its deadline then returns for review without an event',
    () {
      final until = actionAt.add(const Duration(days: 1));
      final ledger = act(
        registered(),
        DecisionSupportFollowupStatus.snoozed,
        until: until,
      );
      final sleeping = projection(
        ledger,
        now: until.subtract(const Duration(seconds: 1)),
      );
      expect(sleeping.status, DecisionSupportFollowupStatus.snoozed);
      expect(sleeping.isSnoozed, isTrue);
      expect(sleeping.isSuppressed, isTrue);
      final expired = projection(ledger, now: until);
      expect(expired.status, DecisionSupportFollowupStatus.needsReview);
      expect(expired.recordedStatus, DecisionSupportFollowupStatus.snoozed);
      expect(expired.isSuppressed, isFalse);
      expect(ledger.feedback, hasLength(1));
    },
  );

  test(
    'person-selected views filter statuses and preserve chronological order',
    () {
      final unread = prompt(time: createdAt);
      final needsReview = prompt(sourceRecordId: 'meal-review', time: actionAt);
      final snoozed = prompt(
        sourceRecordId: 'meal-snoozed',
        time: actionAt.add(const Duration(minutes: 1)),
      );
      final read = prompt(
        sourceRecordId: 'meal-read',
        time: actionAt.add(const Duration(minutes: 2)),
      );
      final prior = prompt(
        sourceRecordId: 'older-source',
        time: actionAt.add(const Duration(minutes: 3)),
      );
      final feedbackAt = actionAt.add(const Duration(minutes: 5));
      var ledger = service.register(
        ledger: DecisionSupportFollowupLedger.empty(owner),
        ownerScope: owner,
        prompts: [unread, needsReview, snoozed, read, prior],
      );
      for (final (item, status, until) in [
        (needsReview, DecisionSupportFollowupStatus.needsReview, null),
        (
          snoozed,
          DecisionSupportFollowupStatus.snoozed,
          feedbackAt.add(const Duration(days: 1)),
        ),
        (read, DecisionSupportFollowupStatus.read, null),
      ]) {
        ledger = service.recordFeedback(
          ledger: ledger,
          ownerScope: owner,
          promptId: item.id,
          status: status,
          actorId: 'local-person',
          actorRole: DecisionSupportFollowupActorRole.user,
          occurredAt: feedbackAt,
          snoozedUntil: until,
        );
      }
      final projected = service.project(
        ledger: ledger,
        ownerScope: owner,
        now: feedbackAt,
      );
      final currentIds = {unread.id, needsReview.id, snoozed.id, read.id};
      List<String> ids(DecisionSupportFollowupView view) => service
          .filterForView(
            items: projected,
            currentPromptIds: currentIds,
            view: view,
          )
          .map((item) => item.prompt.id)
          .toList();

      expect(ids(DecisionSupportFollowupView.open), [
        needsReview.id,
        unread.id,
      ]);
      expect(ids(DecisionSupportFollowupView.needsReview), [
        needsReview.id,
        unread.id,
      ]);
      expect(ids(DecisionSupportFollowupView.snoozed), [snoozed.id]);
      expect(ids(DecisionSupportFollowupView.all), [
        prior.id,
        read.id,
        snoozed.id,
        needsReview.id,
        unread.id,
      ]);
      final afterSnoozeExpiry = service.project(
        ledger: ledger,
        ownerScope: owner,
        now: feedbackAt.add(const Duration(days: 1)),
      );
      final expiredInReviewView = service.filterForView(
        items: afterSnoozeExpiry,
        currentPromptIds: currentIds,
        view: DecisionSupportFollowupView.needsReview,
      );
      expect(expiredInReviewView.map((item) => item.prompt.id), [
        snoozed.id,
        needsReview.id,
        unread.id,
      ]);
    },
  );

  test('snooze can be extended while retaining both explicit events', () {
    final ledger = act(
      registered(),
      DecisionSupportFollowupStatus.snoozed,
      until: actionAt.add(const Duration(hours: 1)),
    );
    final extended = act(
      ledger,
      DecisionSupportFollowupStatus.snoozed,
      at: actionAt.add(const Duration(minutes: 1)),
      until: actionAt.add(const Duration(days: 1)),
    );
    expect(extended.feedback, hasLength(2));
    expect(ledger.feedback, hasLength(1));
    expect(
      projection(extended).snoozedUntil,
      actionAt.add(const Duration(days: 1)),
    );
  });

  test(
    'closing can be reopened for review and preserves the closing reason',
    () {
      final closed = act(
        registered(),
        DecisionSupportFollowupStatus.dismissed,
        reason: 'Duplicate',
        reasonCategory:
            DecisionSupportFeedbackReasonCategory.duplicateOrAlreadyAddressed,
      );
      final reopened = act(
        closed,
        DecisionSupportFollowupStatus.needsReview,
        at: actionAt.add(const Duration(minutes: 1)),
      );
      expect(
        projection(reopened).status,
        DecisionSupportFollowupStatus.needsReview,
      );
      expect(projection(reopened).isSuppressed, isFalse);
      expect(reopened.feedback.first.reason, 'Duplicate');
      expect(
        () => act(closed, DecisionSupportFollowupStatus.read),
        throwsFormatException,
      );
    },
  );

  test(
    'dismissal requires a real nonempty reason and feedback requires actor',
    () {
      for (final reason in <String?>[null, '', '   ']) {
        expect(
          () => act(
            registered(),
            DecisionSupportFollowupStatus.dismissed,
            reason: reason,
            reasonCategory: DecisionSupportFeedbackReasonCategory.other,
          ),
          throwsFormatException,
        );
      }
      expect(
        () =>
            act(registered(), DecisionSupportFollowupStatus.read, actorId: ' '),
        throwsFormatException,
      );
    },
  );

  test(
    'snooze requires a future time and other statuses cannot carry a deadline',
    () {
      for (final until in [null, actionAt, createdAt]) {
        expect(
          () => act(
            registered(),
            DecisionSupportFollowupStatus.snoozed,
            until: until,
          ),
          throwsFormatException,
        );
      }
      expect(
        () => act(
          registered(),
          DecisionSupportFollowupStatus.read,
          until: actionAt.add(const Duration(hours: 1)),
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'backdated, unread, repeated, and unknown-prompt feedback is rejected',
    () {
      final base = registered();
      expect(
        () => act(
          base,
          DecisionSupportFollowupStatus.read,
          at: createdAt.subtract(const Duration(seconds: 1)),
        ),
        throwsFormatException,
      );
      expect(
        () => act(base, DecisionSupportFollowupStatus.unread),
        throwsFormatException,
      );
      final read = act(base, DecisionSupportFollowupStatus.read);
      expect(
        () => act(
          read,
          DecisionSupportFollowupStatus.needsReview,
          at: actionAt.subtract(const Duration(seconds: 1)),
        ),
        throwsFormatException,
      );
      expect(
        () => act(
          read,
          DecisionSupportFollowupStatus.read,
          at: actionAt.add(const Duration(seconds: 1)),
        ),
        throwsFormatException,
      );
      expect(
        () => service.recordFeedback(
          ledger: base,
          ownerScope: owner,
          promptId: prompt(candidateId: 'absent').id,
          status: DecisionSupportFollowupStatus.read,
          actorId: 'person',
          actorRole: DecisionSupportFollowupActorRole.user,
          occurredAt: actionAt,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'owner isolation applies to load, register, feedback and projection',
    () {
      final ledger = registered();
      expect(
        () => DecisionSupportFollowupLedger.fromJson(
          encoded(ledger),
          ownerScope: 'other',
        ),
        throwsFormatException,
      );
      expect(
        () => service.register(
          ledger: ledger,
          ownerScope: owner,
          prompts: [prompt(ownerScope: 'other')],
        ),
        throwsFormatException,
      );
      expect(
        () =>
            service.register(ledger: ledger, ownerScope: 'other', prompts: []),
        throwsFormatException,
      );
      expect(
        () =>
            service.project(ledger: ledger, ownerScope: 'other', now: actionAt),
        throwsFormatException,
      );
      expect(
        () => service.recordFeedback(
          ledger: ledger,
          ownerScope: 'other',
          promptId: ledger.prompts.first.id,
          status: DecisionSupportFollowupStatus.read,
          actorId: 'person',
          actorRole: DecisionSupportFollowupActorRole.user,
          occurredAt: actionAt,
        ),
        throwsFormatException,
      );
    },
  );

  test(
    'strict restore rejects tampered inputs, schemas, enum values and extra fields',
    () {
      final ledger = act(registered(), DecisionSupportFollowupStatus.read);
      final edits = <void Function(Map<String, dynamic>)>[
        (json) => json['schemaVersion'] = 4,
        (json) => json['schemaVersion'] = 1.0,
        (json) => json['accepted'] = true,
        (json) => json['prompts'][0]['inputSnapshot']['dose'] = 100,
        (json) => json['prompts'][0]['sourceRefs'] = ['invented source'],
        (json) => json['prompts'][0]['id'] = 'forged',
        (json) => json['prompts'][0]['createdAt'] = '2026-09-22T12:00:00',
        (json) => json['feedback'][0]['actorRole'] = 'engine',
        (json) => json['feedback'][0]['status'] = 'accepted',
        (json) => json['feedback'][0]['reason'] = 'changed after recording',
        (json) => json['feedback'][0].remove('reasonCategory'),
        (json) => json['feedback'][0]['reasonCategory'] = 'verifiedCorrect',
        (json) => json['feedback'][0]['occurredAt'] = true,
        (json) => json['prompts'] = 'not a list',
      ];
      for (final edit in edits) {
        final json = encoded(ledger);
        edit(json);
        expect(
          () => DecisionSupportFollowupLedger.fromJson(json, ownerScope: owner),
          throwsFormatException,
        );
      }
    },
  );

  test('restore rejects duplicate events and duplicate prompts', () {
    final ledger = act(registered(), DecisionSupportFollowupStatus.read);
    for (final key in ['prompts', 'feedback']) {
      final json = encoded(ledger);
      (json[key] as List).add((json[key] as List).first);
      expect(
        () => DecisionSupportFollowupLedger.fromJson(json, ownerScope: owner),
        throwsFormatException,
      );
    }
  });

  test(
    'bounded input parsing rejects non-JSON, deeply nested and nonfinite values',
    () {
      expect(() => prompt(inputs: {'dose': double.nan}), throwsFormatException);
      expect(
        () => prompt(inputs: {'value': DateTime.now()}),
        throwsFormatException,
      );
      expect(
        () => prompt(inputs: {'value': 'a' * 8001}),
        throwsFormatException,
      );
      Object? nested;
      for (var i = 0; i < 20; i++) {
        nested = [nested];
      }
      expect(() => prompt(inputs: {'value': nested}), throwsFormatException);
      expect(
        () => prompt(sourceRefs: List.generate(129, (index) => 'ref-$index')),
        throwsFormatException,
      );
      final json = encoded(registered());
      json['prompts'] = List.filled(
        DecisionSupportFollowupLedger.maxPrompts + 1,
        (json['prompts'] as List).first,
      );
      expect(
        () => DecisionSupportFollowupLedger.fromJson(json, ownerScope: owner),
        throwsFormatException,
      );
    },
  );

  test('projection ordering is deterministic for simultaneous prompts', () {
    final a = prompt(candidateId: 'A');
    final b = prompt(candidateId: 'B');
    final ledger = service.register(
      ledger: DecisionSupportFollowupLedger.empty(owner),
      ownerScope: owner,
      prompts: [b, a],
    );
    final ids = service
        .project(ledger: ledger, ownerScope: owner, now: actionAt)
        .map((item) => item.prompt.id)
        .toList();
    expect(ids, [a.id, b.id]..sort());
  });

  test(
    'text restore checks payload size and object shape before parsing records',
    () {
      final ledger = registered();
      expect(
        DecisionSupportFollowupLedger.decode(
          jsonEncode(ledger.toJson()),
          ownerScope: owner,
        ).toJson(),
        ledger.toJson(),
      );
      expect(
        () => DecisionSupportFollowupLedger.decode('[]', ownerScope: owner),
        throwsFormatException,
      );
      expect(
        () => DecisionSupportFollowupLedger.decode(
          ' ' * (DecisionSupportFollowupLedger.maxJsonLength + 1),
          ownerScope: owner,
        ),
        throwsFormatException,
      );
    },
  );
}
