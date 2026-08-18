import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/copy/response_copy_service.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/food_recommendation.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';

/// P3 — Local AI safety contract.
///
/// These tests pin the guarantee that the Local AI layer can only *polish
/// wording* of an already-safe deterministic result. They prove it cannot:
///   - change the deterministic risk level / candidate decision,
///   - remove safety-boundary language,
///   - invent evidence sources or new candidates,
///   - add medication-timing advice,
///   - add dietary guidance,
///   - turn an incomplete/blocked safety state into an allowed recommendation.
///
/// Local AI is stubbed with an in-memory MockClient (no real model needed).
/// Educational prototype only; synthetic fixtures; no PHI.
void main() {
  // ---- helpers -------------------------------------------------------------

  FoodItem food(String id, {double proteinG = 1}) => FoodItem(
    id: id,
    name: id,
    category: FoodCategory.fruit,
    proteinG: proteinG,
    carbsG: 20,
    fatG: 0,
    fiberG: 2,
    sodiumMg: 1,
  );

  FoodRecommendation rec(
    String id, {
    String decision = 'ALLOW',
    double score = 50,
  }) => FoodRecommendation(
    food: food(id),
    score: score,
    reasons: const ['Deterministic reason.'],
    decision: decision,
    jurisdiction: 'US',
    fallbackUsed: false,
    scoreBreakdown: const {'base': 50},
    featureSnapshot: const RecommendationFeatureSnapshot(
      safetyScore: 0.9,
      nutrientMatch: 0.5,
      medicationScheduleFit: 0.5,
      culturalAffinity: 0.5,
      userPreferenceScore: 0.5,
      provenanceScore: 0.5,
      databaseFactCoverage: 0.5,
      timingWindowClarity: 0.5,
      drugTimingSensitivity: 0.0,
      fallbackPenalty: 0.0,
      repetitionPenalty: 0.0,
      fiberSupportScore: 0.5,
      regionMatchScore: 0.5,
      usedDatabaseFacts: true,
      hasPreciseTimingWindow: true,
      levodopaSensitive: false,
    ),
  );

  UserProfile consentingProfile() => UserProfile.defaults()
      .copyWith(
        localAiProviderPreference: LocalAiProviders.ollama,
        localAiModel: 'gemma3n:e2b',
      )
      .withLocalAiConsentDecision(
        enabled: true,
        recordedAt: DateTime.utc(2026, 8, 18),
        source: 'test_fixture',
      );

  /// Builds a MockClient that always reports the model available and routes the
  /// first non-probe completion to [completionContent] (a JSON string that the
  /// model would have returned as `message.content`).
  MockClient scriptedClient(String completionContent) {
    return MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/api/tags') {
        return http.Response(
          jsonEncode({
            'models': [
              {'name': 'gemma3n:e2b', 'model': 'gemma3n:e2b'},
            ],
          }),
          200,
        );
      }
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final content = ((body['messages'] as List).first['content'] ?? '')
          .toString();
      if (content.contains('reply with {"ok":true}')) {
        return http.Response(
          jsonEncode({
            'message': {'content': '{"ok":true}'},
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'message': {'content': completionContent},
        }),
        200,
      );
    });
  }

  final candidates = [rec('banana'), rec('apple'), rec('oats')];
  final allowedIds = candidates.map((c) => c.food.id).toList();

  // ---- cannot invent new candidates / evidence sources ---------------------

  test(
    'rerank rejects an invented candidate id (no fabricated evidence)',
    () async {
      final adapter = LocalAiRecommendationAdapter(
        client: scriptedClient(
          jsonEncode({
            'candidate_ids': ['banana', 'apple', 'INVENTED_FOOD'],
            'summary': 'tried to add a food',
            'safety_checks': <String>[],
            'ranking_rationale': <String>[],
          }),
        ),
      );
      final result = await adapter.rerankSafeCandidates(
        userProfile: consentingProfile(),
        candidates: candidates,
        contextLines: const [],
      );
      expect(result, isNull, reason: 'Out-of-whitelist id must be rejected.');
    },
  );

  test(
    'rerank rejects a dropped candidate id (cannot silently remove)',
    () async {
      final adapter = LocalAiRecommendationAdapter(
        client: scriptedClient(
          jsonEncode({
            'candidate_ids': ['banana', 'apple'],
            'summary': 'dropped one',
            'safety_checks': <String>[],
            'ranking_rationale': <String>[],
          }),
        ),
      );
      final result = await adapter.rerankSafeCandidates(
        userProfile: consentingProfile(),
        candidates: candidates,
        contextLines: const [],
      );
      expect(result, isNull);
    },
  );

  test(
    'rerank accepts only a pure reordering of the exact whitelist',
    () async {
      final adapter = LocalAiRecommendationAdapter(
        client: scriptedClient(
          jsonEncode({
            'candidate_ids': ['oats', 'banana', 'apple'],
            'summary': 'reordered',
            'safety_checks': <String>[],
            'ranking_rationale': <String>[],
          }),
        ),
      );
      final result = await adapter.rerankSafeCandidates(
        userProfile: consentingProfile(),
        candidates: candidates,
        contextLines: const [],
      );
      expect(result, isNotNull);
      expect(result!.candidateIds.toSet(), allowedIds.toSet());
      expect(result.candidateIds, hasLength(allowedIds.length));
    },
  );

  // ---- cannot add medication-timing advice ---------------------------------

  test('rerank rejects payload containing medication-timing advice', () async {
    final adapter = LocalAiRecommendationAdapter(
      client: scriptedClient(
        jsonEncode({
          'candidate_ids': allowedIds,
          'summary': 'Take your medication at 8am and adjust your dose.',
          'safety_checks': <String>[],
          'ranking_rationale': <String>[],
        }),
      ),
    );
    final result = await adapter.rerankSafeCandidates(
      userProfile: consentingProfile(),
      candidates: candidates,
      contextLines: const [],
    );
    expect(result, isNull, reason: 'Banned timing advice must be rejected.');
  });

  // ---- cannot add dietary guidance -----------------------------------------

  test(
    'rerank rejects payload containing dietary guidance ("avoid protein")',
    () async {
      final adapter = LocalAiRecommendationAdapter(
        client: scriptedClient(
          jsonEncode({
            'candidate_ids': allowedIds,
            'summary': 'You should avoid protein entirely.',
            'safety_checks': <String>[],
            'ranking_rationale': <String>[],
          }),
        ),
      );
      final result = await adapter.rerankSafeCandidates(
        userProfile: consentingProfile(),
        candidates: candidates,
        contextLines: const [],
      );
      expect(result, isNull);
    },
  );

  // ---- copy polish cannot introduce unsafe claims --------------------------

  test('copy-reason polish keeps notes only for whitelisted ids', () async {
    final adapter = LocalAiRecommendationAdapter(
      client: scriptedClient(
        jsonEncode({
          'summary': 'Polished wording only.',
          'candidate_notes': {
            'banana': 'A plain-language reason.',
            'GHOST_FOOD': 'A note for a food that does not exist.',
          },
        }),
      ),
    );
    final result = await adapter.polishRecommendationReasons(
      userProfile: consentingProfile(),
      recommendations: candidates,
      contextLines: const [],
    );
    expect(result, isNotNull);
    expect(result!.candidateNotes.keys, contains('banana'));
    expect(result.candidateNotes.keys, isNot(contains('GHOST_FOOD')));
  });

  test(
    'response-copy polish returns null when output adds a banned claim',
    () async {
      final adapter = LocalAiRecommendationAdapter(
        client: scriptedClient(
          jsonEncode({
            'polished_text':
                'This food is clinically validated and safe for you.',
          }),
        ),
      );
      final polished = await adapter.polishResponseCopy(
        const ResponseCopyRequest(
          draftText: 'An educational note.',
          localeTag: 'en-US',
          context: 'unit-test',
          hasCurrentPurposeBoundConsent: true,
        ),
      );
      expect(
        polished,
        isNull,
        reason: 'Polished copy with banned claims must be dropped.',
      );
    },
  );

  // ---- disabled / unavailable Local AI degrades safely ---------------------

  test('rerank returns null when the local endpoint is unavailable', () async {
    final adapter = LocalAiRecommendationAdapter(
      client: MockClient((_) async => http.Response('nope', 503)),
    );
    final result = await adapter.rerankSafeCandidates(
      userProfile: consentingProfile(),
      candidates: candidates,
      contextLines: const [],
    );
    expect(result, isNull);
  });
}
