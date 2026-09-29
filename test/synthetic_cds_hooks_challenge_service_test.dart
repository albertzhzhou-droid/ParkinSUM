import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_cds_hooks_challenge_service.dart';
import 'package:parkinsum_companion/domain/usecases/synthetic_cds_hooks_sandbox_service.dart';

void main() {
  const runService = SyntheticCdsHooksSandboxService();
  const challengeService = SyntheticCdsHooksChallengeService();

  test(
    'creates a bounded challenge bound to one synthetic info card',
    () async {
      final run = await runService.run(
        SyntheticCdsHooksScenario.completeProteinMeal,
      );
      final before = jsonEncode(run.response);
      final note = challengeService.create(
        run: run,
        reason: SyntheticCdsHooksChallengeReason.contextMismatch,
        rationale: 'The fixed example omits a context field.',
      );
      final json = note.toJson();

      expect(json['format'], 'parkinsum_synthetic_cds_hooks_challenge');
      expect(json['schemaVersion'], syntheticCdsHooksChallengeSchemaVersion);
      expect(json['disposition'], 'challenge');
      expect(json['inputDigestSha256'], run.inputDigest);
      expect(json['cardDigestSha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(json['reason'], 'contextMismatch');
      expect(json['rationale'], 'The fixed example omits a context field.');
      expect(json['persisted'], isFalse);
      expect(json['transmitted'], isFalse);
      expect(json['ruleOutcomeChanged'], isFalse);
      expect(json.keys, isNot(contains('actorId')));
      expect(json.keys, isNot(contains('createdAt')));
      expect(jsonEncode(run.response), before);
    },
  );

  test(
    'rejects blank, oversized, and invalidly bound challenge input',
    () async {
      final run = await runService.run(
        SyntheticCdsHooksScenario.completeProteinMeal,
      );
      expect(
        () => challengeService.create(
          run: run,
          reason: SyntheticCdsHooksChallengeReason.other,
          rationale: '  ',
        ),
        throwsFormatException,
      );
      expect(
        () => challengeService.create(
          run: run,
          reason: SyntheticCdsHooksChallengeReason.other,
          rationale: List<String>.filled(1001, 'x').join(),
        ),
        throwsFormatException,
      );
      final rebound = SyntheticCdsHooksSandboxRun(
        scenario: run.scenario,
        rulePackVersion: run.rulePackVersion,
        inputDigest: List<String>.filled(64, 'f').join(),
        response: run.response,
        traceDecision: run.traceDecision,
        resultState: run.resultState,
        missingInputs: run.missingInputs,
      );
      expect(
        () => challengeService.create(
          run: rebound,
          reason: SyntheticCdsHooksChallengeReason.explanationUnclear,
          rationale: 'This reason is bound to another input digest.',
        ),
        throwsFormatException,
      );
    },
  );

  test('no-card synthetic runs cannot create challenge notes', () async {
    final run = await runService.run(SyntheticCdsHooksScenario.lowProteinMeal);
    expect(
      () => challengeService.create(
        run: run,
        reason: SyntheticCdsHooksChallengeReason.other,
        rationale: 'There is no card in this response.',
      ),
      throwsFormatException,
    );
  });
}
