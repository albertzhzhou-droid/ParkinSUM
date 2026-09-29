import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/knowledge_governance_state.dart';
import 'package:parkinsum_companion/domain/entities/knowledge_pack.dart';

import 'knowledge_pack_test.dart' show createKnowledgeTestPack;

void main() {
  KnowledgeGovernanceEvent draft({
    int sequence = 1,
    String? previous,
    DateTime? occurred,
  }) {
    final pack = createKnowledgeTestPack(version: '$sequence');
    return KnowledgeGovernanceEvent(
      sequence: sequence,
      previousDigest: previous,
      kind: KnowledgeGovernanceEventKind.draftSaved,
      actorId: pack.authorId,
      occurredAtUtc: occurred ?? DateTime.utc(2026, 9, 22),
      payload: {'pack': pack.toJson()},
    );
  }

  test('journal replay structure round trips and deep freezes payload', () {
    final first = draft();
    final second = draft(sequence: 2, previous: first.digest);
    final journal = KnowledgeGovernanceJournal([first, second]);
    final restored = KnowledgeGovernanceJournal.decode(journal.encode());
    expect(restored.headDigest, journal.headDigest);
    expect(
      restored.events.map((e) => e.digest),
      journal.events.map((e) => e.digest),
    );
    expect(() => journal.events.clear(), throwsUnsupportedError);
    expect(
      () => first.payload['pack']['sources'].clear(),
      throwsUnsupportedError,
    );
    final exported = journal.toJson();
    exported['events'][0]['payload']['pack']['author_id'] = 'different-author';
    expect(first.payload['pack']['author_id'], 'subject-author');
    expect(
      () => KnowledgeGovernanceJournal.decode(jsonEncode(exported)),
      throwsFormatException,
    );
  });

  test('missing, repeated, reordered and backwards-time events reject', () {
    final first = draft();
    final valid = draft(sequence: 2, previous: first.digest);
    expect(() => KnowledgeGovernanceJournal([valid]), throwsFormatException);
    expect(
      () => KnowledgeGovernanceJournal([first, first]),
      throwsFormatException,
    );
    expect(
      () => KnowledgeGovernanceJournal([valid, first]),
      throwsFormatException,
    );
    expect(
      () => KnowledgeGovernanceJournal([
        first,
        draft(sequence: 2, previous: '0' * 64),
      ]),
      throwsFormatException,
    );
    expect(
      () => KnowledgeGovernanceJournal([
        first,
        draft(
          sequence: 2,
          previous: first.digest,
          occurred: DateTime.utc(2026, 9, 21),
        ),
      ]),
      throwsFormatException,
    );
  });

  test('journal schema, event digest and unknown fields fail closed', () {
    final journal = KnowledgeGovernanceJournal([draft()]);
    for (final schema in [0, 1.0, '1', null]) {
      final json = journal.toJson()..['schema_version'] = schema;
      expect(
        () => KnowledgeGovernanceJournal.decode(jsonEncode(json)),
        throwsFormatException,
      );
    }
    final wrongDigest = journal.toJson();
    wrongDigest['events'][0]['digest'] = '0' * 64;
    expect(
      () => KnowledgeGovernanceJournal.decode(jsonEncode(wrongDigest)),
      throwsFormatException,
    );
    final unknown = journal.toJson();
    unknown['events'][0]['ignored'] = false;
    expect(
      () => KnowledgeGovernanceJournal.decode(jsonEncode(unknown)),
      throwsFormatException,
    );
  });

  test(
    'duplicate JSON members reject including escaped names and array objects',
    () {
      for (final raw in [
        '{"schema_version":0,"schema_version":1,"events":[]}',
        r'{"schema_version":1,"schema_\u0076ersion":1,"events":[]}',
        '{"events":[{"approval":{"subject":"forged","subject":"signed"}}]}',
        '{"values":[{"x":1,"x":1}]}',
      ]) {
        expect(
          () => knowledgeDecode(raw, maxBytes: 4096),
          throwsFormatException,
        );
      }
      expect(
        knowledgeDecode('{"x":["a","b",{"x":1}],"y":{"x":2}}', maxBytes: 4096),
        {
          'x': [
            'a',
            'b',
            {'x': 1},
          ],
          'y': {'x': 2},
        },
      );
    },
  );

  test('oversized and malformed journal text is rejected before replay', () {
    expect(
      () => KnowledgeGovernanceJournal.decode(
        ' ' * (knowledgeGovernanceMaxBytes + 1),
      ),
      throwsFormatException,
    );
    for (final raw in [
      '[}',
      '{]',
      '{"x":"unterminated',
      '${'[' * 41}0${']' * 41}',
    ]) {
      expect(
        () => KnowledgeGovernanceJournal.decode(raw),
        throwsFormatException,
      );
    }
  });
}
