import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/interaction_result.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/core/models/user_profile.dart';
import 'package:parkinsum_companion/domain/entities/food_recommendation.dart';
import 'package:parkinsum_companion/domain/usecases/local_ai_recommendation_adapter.dart';

void main() {
  UserProfile buildProfile({
    String provider = LocalAiProviders.auto,
    String ollamaEndpoint = 'http://127.0.0.1:11434/api/chat',
    String openAiEndpoint = 'http://127.0.0.1:8080/v1/chat/completions',
  }) {
    return UserProfile.defaults().copyWith(
      localAiConsentEnabled: true,
      localAiProviderPreference: provider,
      localAiModel: 'llama3.2',
      localAiOllamaEndpoint: ollamaEndpoint,
      localAiOpenAiCompatEndpoint: openAiEndpoint,
      localAiTimeoutMs: 3000,
    );
  }

  FoodRecommendation buildCandidate(String id) {
    return FoodRecommendation(
      food: FoodItem(
        id: id,
        name: id,
        category: FoodCategory.carbs,
        proteinG: 2,
        carbsG: 10,
        fatG: 1,
        fiberG: 1,
        sodiumMg: 5,
      ),
      score: 80,
      reasons: const ['safe'],
      decision: 'ALLOW',
      jurisdiction: 'US',
      fallbackUsed: false,
      scoreBreakdown: const {'base': 80},
      featureSnapshot: const RecommendationFeatureSnapshot(
        safetyScore: 0.9,
        nutrientMatch: 0.8,
        medicationScheduleFit: 0.85,
        culturalAffinity: 0.7,
        userPreferenceScore: 0.6,
        provenanceScore: 0.95,
        databaseFactCoverage: 1.0,
        timingWindowClarity: 1.0,
        drugTimingSensitivity: 0.2,
        fallbackPenalty: 0.0,
        repetitionPenalty: 0.0,
        fiberSupportScore: 0.4,
        regionMatchScore: 1.0,
        usedDatabaseFacts: true,
        hasPreciseTimingWindow: true,
        levodopaSensitive: true,
        riskTags: <String>['levodopa_sensitive'],
      ),
    );
  }

  test('probe prefers Ollama in auto mode when Ollama responds', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'http://127.0.0.1:11434/api/tags');
      return http.Response(
        jsonEncode({
          'models': [
            {'name': 'llama3.2:latest', 'model': 'llama3.2:latest'}
          ]
        }),
        200,
      );
    });
    final adapter = LocalAiRecommendationAdapter(client: client);

    final result = await adapter.probe(userProfile: buildProfile());

    expect(result.available, isTrue);
    expect(result.provider, LocalAiProviders.ollama);
  });

  test('probe rejects non-localhost endpoints', () async {
    final client = MockClient((request) async {
      fail('network should not be called for non-localhost endpoints');
    });
    final adapter = LocalAiRecommendationAdapter(client: client);

    final result = await adapter.probe(
      userProfile: buildProfile(
        provider: LocalAiProviders.ollama,
        ollamaEndpoint: 'https://example.com/api/chat',
      ),
    );

    expect(result.available, isFalse);
    expect(result.message, contains('localhost'));
  });

  test('probe rejects localhost endpoints with unsafe URL components',
      () async {
    final client = MockClient((request) async {
      fail('network should not be called for unsafe localhost endpoints');
    });
    final adapter = LocalAiRecommendationAdapter(client: client);
    const endpoints = [
      'ftp://localhost:11434/api/chat',
      'http://user:pass@localhost:11434/api/chat',
      'http://localhost:11434/api/chat?redirect=https://example.com',
      'http://localhost:11434/api/chat#fragment',
      'http://0.0.0.0:11434/api/chat',
    ];

    for (final endpoint in endpoints) {
      final result = await adapter.probe(
        userProfile: buildProfile(
          provider: LocalAiProviders.ollama,
          ollamaEndpoint: endpoint,
        ),
      );
      expect(result.available, isFalse, reason: endpoint);
      expect(result.message, contains('localhost'), reason: endpoint);
    }
  });

  test('probe accepts IPv6 loopback endpoint', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.toString(), 'http://[::1]:11434/api/tags');
      return http.Response(
        jsonEncode({
          'models': [
            {'name': 'llama3.2:latest', 'model': 'llama3.2:latest'}
          ]
        }),
        200,
      );
    });
    final adapter = LocalAiRecommendationAdapter(client: client);

    final result = await adapter.probe(
      userProfile: buildProfile(
        provider: LocalAiProviders.ollama,
        ollamaEndpoint: 'http://[::1]:11434/api/chat',
      ),
    );

    expect(result.available, isTrue);
    expect(result.provider, LocalAiProviders.ollama);
  });

  test('rerank rejects ids outside the safe whitelist', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/tags') {
        return http.Response(
          jsonEncode({
            'models': [
              {'name': 'llama3.2:latest', 'model': 'llama3.2:latest'}
            ]
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'message': {
            'content': '{"candidate_ids":["food_a","food_x"],"summary":"bad"}'
          }
        }),
        200,
      );
    });
    final adapter = LocalAiRecommendationAdapter(client: client);

    final result = await adapter.rerankSafeCandidates(
      userProfile: buildProfile(provider: LocalAiProviders.ollama),
      candidates: [
        buildCandidate('food_a'),
        buildCandidate('food_b'),
      ],
      contextLines: const ['safe'],
    );

    expect(result, isNull);
  });

  test('rerank rejects incomplete ordering even when ids are valid', () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/tags') {
        return http.Response(
          jsonEncode({
            'models': [
              {'name': 'llama3.2:latest', 'model': 'llama3.2:latest'}
            ]
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'message': {
            'content':
                '{"candidate_ids":["food_b"],"summary":"partial","safety_checks":["kept safe"],"ranking_rationale":["partial order"]}'
          }
        }),
        200,
      );
    });
    final adapter = LocalAiRecommendationAdapter(client: client);

    final result = await adapter.rerankSafeCandidates(
      userProfile: buildProfile(provider: LocalAiProviders.ollama),
      candidates: [
        buildCandidate('food_a'),
        buildCandidate('food_b'),
      ],
      contextLines: const ['safe'],
    );

    expect(result, isNull);
  });

  test('meal conflict polish changes wording without changing risk score',
      () async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/tags') {
        return http.Response(
          jsonEncode({
            'models': [
              {'name': 'llama3.2:latest', 'model': 'llama3.2:latest'},
              {
                'name': LocalAiRecommendedModels.medGemmaText,
                'model': LocalAiRecommendedModels.medGemmaText,
              }
            ]
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'message': {
            'content': jsonEncode({
              'summary': 'Keep this meal separate from levodopa timing.',
              'analysis_text':
                  'The existing score stays high because the meal timing and protein context need caution.',
              'key_findings': ['Protein timing is the main concern.'],
              'next_actions': ['Confirm the medication and meal timing.'],
              'data_notes': ['AI only rewrote the wording.'],
              'issue_details': ['This issue was rewritten in plain language.'],
              'safety_alignment': 'aligned',
            }),
          }
        }),
        200,
      );
    });
    final adapter = LocalAiRecommendationAdapter(client: client);
    final original = InteractionResult(
      mealId: 'meal_1',
      status: InteractionStatus.warning,
      summary: 'raw summary',
      analysisText: 'raw analysis',
      issues: [
        InteractionIssue(
          severity: InteractionSeverity.high,
          title: 'High protein conflict',
          detail: 'raw issue detail',
          relatedDrugId: 'levodopa',
        ),
      ],
      generatedAt: DateTime(2026, 5, 12),
      score: 81,
      scoreFactors: const [
        InteractionScoreFactor(
          code: 'protein_timing_penalty',
          label: 'Protein timing',
          points: 50,
        ),
      ],
    );

    final polished = await adapter.polishInteractionResult(
      userProfile: buildProfile(provider: LocalAiProviders.ollama),
      meal: Meal(
        id: 'meal_1',
        title: 'Dinner',
        eatenAt: DateTime(2026, 5, 12, 18),
        items: const [],
      ),
      result: original,
      activeDrugs: const [],
      intakes: const [],
    );

    expect(polished.score, original.score);
    expect(polished.overallSeverity, original.overallSeverity);
    expect(polished.scoreFactors.single.code, 'protein_timing_penalty');
    expect(polished.summary, contains('levodopa'));
    expect(polished.issues.single.detail, contains('plain language'));
  });
}
