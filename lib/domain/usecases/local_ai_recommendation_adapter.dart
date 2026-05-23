import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/copy/response_copy_service.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/intake.dart';
import '../../core/models/interaction_result.dart';
import '../../core/models/meal.dart';
import '../../core/models/user_profile.dart';
import '../entities/food_recommendation.dart';

/// 本地 AI provider 常量。
/// 这里只允许 localhost 上的服务，不允许把健康/饮食数据发到云端模型。
class LocalAiProviders {
  static const auto = 'auto';
  static const ollama = 'ollama';
  static const openAiCompat = 'openai_compat';

  static const supported = <String>{
    auto,
    ollama,
    openAiCompat,
  };
}

class LocalAiRecommendedModels {
  static const gemmaText = 'gemma3n:e2b';
  static const medGemmaText = 'hf.co/unsloth/medgemma-1.5-4b-it-GGUF:Q4_K_M';
}

/// 本地 AI 探测结果。
/// UI 和推荐编排器都用同一份状态，避免“页面显示可用、引擎实际不可用”的分叉。
class LocalAiAvailability {
  final bool available;
  final String provider;
  final String endpoint;
  final String model;
  final String medicalModel;
  final bool medicalAvailable;
  final String message;

  const LocalAiAvailability({
    required this.available,
    required this.provider,
    required this.endpoint,
    required this.model,
    this.medicalModel = '',
    this.medicalAvailable = false,
    required this.message,
  });
}

/// 本地 AI 重排结果。
/// 只允许返回白名单候选 id 顺序，不允许新增食物或修改硬规则。
class LocalAiRerankResult {
  final List<String> candidateIds;
  final String summary;
  final List<String> safetyChecks;
  final List<String> rankingRationale;
  final Map<String, String> candidateNotes;
  final String provider;
  final String endpoint;
  final String model;

  const LocalAiRerankResult({
    required this.candidateIds,
    required this.summary,
    required this.safetyChecks,
    required this.rankingRationale,
    this.candidateNotes = const <String, String>{},
    required this.provider,
    required this.endpoint,
    required this.model,
  });
}

/// 本地 AI 文案润色结果。
/// 不携带排序、不携带新候选，只能为已有候选 id 追加更自然的展示理由。
class LocalAiRecommendationPolishResult {
  final String summary;
  final Map<String, String> candidateNotes;
  final String provider;
  final String endpoint;
  final String model;

  const LocalAiRecommendationPolishResult({
    required this.summary,
    required this.candidateNotes,
    required this.provider,
    required this.endpoint,
    required this.model,
  });

  bool get hasNotes => candidateNotes.isNotEmpty;
}

/// 本地 AI 重排适配器：
/// - 只接受已经通过保守路径过滤的候选；
/// - 只允许返回候选 ID 重排序，不允许引入新食物；
/// - 优先尝试用户指定 provider；若为 auto，则先 Ollama、再 llama.cpp/OpenAI-compatible。
///
/// 说明：
/// - 这是“受限增强器”，不是事实来源，也不能覆盖硬规则；
/// - 任意网络/JSON/契约失败都必须回退到 deterministic 结果。
class LocalAiRecommendationAdapter implements LocalResponsePolisher {
  final http.Client _client;

  LocalAiRecommendationAdapter({
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<LocalAiAvailability> probe({
    required UserProfile userProfile,
  }) async {
    final model = _textModel(userProfile);
    final medicalModel = _medicalModel(userProfile);
    final timeout = _timeout(userProfile);

    for (final target in _providerTargets(userProfile)) {
      final response = await _probeTarget(
        provider: target.provider,
        endpoint: target.endpoint,
        model: model,
        medicalModel: medicalModel,
        timeout: timeout,
      );
      if (response.available) {
        return response;
      }
    }

    final preferred =
        _normalizedProvider(userProfile.localAiProviderPreference);
    return LocalAiAvailability(
      available: false,
      provider: preferred,
      endpoint: preferred == LocalAiProviders.openAiCompat
          ? userProfile.localAiOpenAiCompatEndpoint
          : userProfile.localAiOllamaEndpoint,
      model: model,
      medicalModel: medicalModel,
      message: 'No localhost Ollama/llama.cpp endpoint responded.',
    );
  }

  @override
  Future<String?> polishResponseCopy(ResponseCopyRequest request) async {
    final userProfile = UserProfile.defaults().copyWith(
      displayLocale: request.localeTag,
      localAiConsentEnabled: true,
    );
    final availability = await probe(userProfile: userProfile);
    if (!availability.available) return null;
    final schema = {
      'type': 'object',
      'properties': {
        'polished_text': {'type': 'string'}
      },
      'required': ['polished_text'],
    };
    final prompt = [
      'Rewrite this ParkinSUM copy in plain patient-friendly language.',
      'Locale: ${request.localeTag}.',
      'Context: ${request.context}.',
      'Do not add medical facts. Do not change numbers, scores, names, source IDs, model names, or safety meaning.',
      if (request.protectedFacts.isNotEmpty)
        'Protected facts: ${jsonEncode(request.protectedFacts)}',
      'Return JSON only.',
      'Draft:',
      request.draftText,
    ].join('\n');
    final payload = await _completeStructured(
      availability: availability,
      model: availability.model,
      prompt: prompt,
      schema: schema,
      schemaName: 'copy_polish',
      timeout: const Duration(milliseconds: 12000),
    );
    final polished = payload?['polished_text']?.toString().trim();
    if (polished == null || polished.isEmpty) return null;
    return polished;
  }

  Future<InteractionResult> polishInteractionResult({
    required UserProfile userProfile,
    required Meal meal,
    required InteractionResult result,
    required List<DrugDefinition> activeDrugs,
    required List<Intake> intakes,
  }) async {
    if (!userProfile.localAiConsentEnabled) return result;
    final availability = await probe(userProfile: userProfile);
    if (!availability.available) return result;
    final model = availability.medicalAvailable
        ? availability.medicalModel
        : availability.model;
    final schema = {
      'type': 'object',
      'properties': {
        'summary': {'type': 'string'},
        'analysis_text': {'type': 'string'},
        'key_findings': {
          'type': 'array',
          'items': {'type': 'string'}
        },
        'next_actions': {
          'type': 'array',
          'items': {'type': 'string'}
        },
        'data_notes': {
          'type': 'array',
          'items': {'type': 'string'}
        },
        'issue_details': {
          'type': 'array',
          'items': {'type': 'string'}
        },
        'safety_alignment': {'type': 'string'},
      },
      'required': [
        'summary',
        'analysis_text',
        'key_findings',
        'next_actions',
        'data_notes',
        'issue_details',
        'safety_alignment',
      ],
    };
    final prompt = [
      'You are polishing ParkinSUM meal-drug conflict text for a patient.',
      'Use plain language in ${userProfile.displayLocale}.',
      'The CDSS already decided the score, severity, evidence, and actions. Keep them unchanged.',
      'Do not invent diagnosis, dosing instructions, foods, drugs, or evidence.',
      'Risk gradient: score ${result.score}, severity ${result.overallSeverity.name}.',
      'Meal JSON: ${jsonEncode(meal.toJson())}',
      'Active drugs: ${jsonEncode(activeDrugs.map((drug) => {
            'id': drug.id,
            'generic_name': drug.genericName
          }).toList(growable: false))}',
      'Intakes: ${jsonEncode(intakes.map((item) => item.toJson()).toList(growable: false))}',
      'Current result JSON: ${jsonEncode(result.toJson())}',
      'Return JSON only. issue_details must have exactly ${result.issues.length} items in the same order.',
    ].join('\n');
    final payload = await _completeStructured(
      availability: availability,
      model: model,
      prompt: prompt,
      schema: schema,
      schemaName: 'meal_conflict_polish',
      timeout: _timeout(userProfile),
    );
    if (payload == null) return result;
    final issueDetails =
        (payload['issue_details'] as List<dynamic>? ?? const <dynamic>[])
            .map((item) => item.toString().trim())
            .toList(growable: false);
    final polishedIssues = issueDetails.length == result.issues.length
        ? [
            for (var i = 0; i < result.issues.length; i++)
              issueDetails[i].isEmpty
                  ? result.issues[i]
                  : result.issues[i].copyWith(detail: issueDetails[i]),
          ]
        : result.issues;
    return result.copyWith(
      summary: _payloadText(payload, 'summary', result.summary),
      analysisText: _payloadText(payload, 'analysis_text', result.analysisText),
      keyFindings: _payloadStringList(
        payload,
        'key_findings',
        result.keyFindings,
      ),
      nextActions: _payloadStringList(
        payload,
        'next_actions',
        result.nextActions,
      ),
      dataNotes: [
        ..._payloadStringList(payload, 'data_notes', result.dataNotes),
        'AI copy polish: ${availability.provider} / $model',
        'Safety alignment: ${payload['safety_alignment'] ?? 'not_reported'}',
      ],
      issues: polishedIssues,
    );
  }

  Future<LocalAiRerankResult?> rerankSafeCandidates({
    required UserProfile userProfile,
    required List<FoodRecommendation> candidates,
    required List<String> contextLines,
    LocalAiAvailability? availability,
  }) async {
    if (candidates.isEmpty) {
      return const LocalAiRerankResult(
        candidateIds: <String>[],
        summary: 'No candidates required reranking.',
        safetyChecks: <String>['No candidates required reranking.'],
        rankingRationale: <String>['No ranking change required.'],
        provider: LocalAiProviders.auto,
        endpoint: '',
        model: '',
      );
    }

    final resolvedAvailability =
        availability ?? await probe(userProfile: userProfile);
    if (!resolvedAvailability.available) {
      return null;
    }

    final candidatePayload = candidates
        .map(
          (item) => {
            'food_id': item.food.id,
            'food_name': item.food.name,
            'score': item.score,
            'decision': item.decision,
            'reasons': item.reasons,
            'score_breakdown': item.scoreBreakdown,
            'feature_snapshot': item.featureSnapshot.toJson(),
            'source_system': item.food.sourceSystem,
            'jurisdiction': item.food.jurisdiction,
          },
        )
        .toList(growable: false);
    final allowedIds = candidates
        .map((candidate) => candidate.food.id)
        .toList(growable: false);

    final prompt = [
      'You are reranking already-safe next-meal candidates for ParkinSUM.',
      'Rules, timing windows, and database facts are authoritative.',
      'You may only reorder the provided whitelist of candidate ids.',
      'Allowed candidate_ids JSON: ${jsonEncode(allowedIds)}',
      'Every candidate_id in the response must be copied exactly from the allowed list.',
      'Do not invent foods, do not drop ids, do not add ids, and do not change safety decisions.',
      'Prefer clearer timing windows, stronger database-backed observations, and lower levodopa/protein timing risk.',
      'If timing/data quality is weak, stay close to the deterministic order.',
      'Also return candidate_notes as a map from each food_id to one short plain-language reason in the user locale. Do not add facts beyond the candidate JSON.',
      ...contextLines,
      'Candidates JSON:',
      jsonEncode(candidatePayload),
    ].join('\n');

    final schema = {
      'type': 'object',
      'properties': {
        'candidate_ids': {
          'type': 'array',
          'items': {
            'type': 'string',
            'enum': allowedIds,
          }
        },
        'summary': {'type': 'string'},
        'safety_checks': {
          'type': 'array',
          'items': {'type': 'string'}
        },
        'ranking_rationale': {
          'type': 'array',
          'items': {'type': 'string'}
        },
        'candidate_notes': {
          'type': 'object',
        },
      },
      'required': [
        'candidate_ids',
        'summary',
        'safety_checks',
        'ranking_rationale',
      ]
    };

    final payload = await _completeStructured(
      availability: resolvedAvailability,
      model: resolvedAvailability.model,
      prompt: prompt,
      schema: schema,
      schemaName: 'safe_rerank',
      timeout: _timeout(userProfile),
    );
    if (payload == null) return null;

    return _safeResult(
      payload: payload,
      candidates: candidates,
      availability: resolvedAvailability,
    );
  }

  Future<LocalAiRecommendationPolishResult?> polishRecommendationReasons({
    required UserProfile userProfile,
    required List<FoodRecommendation> recommendations,
    required List<String> contextLines,
    LocalAiAvailability? availability,
  }) async {
    if (recommendations.isEmpty) return null;

    final resolvedAvailability =
        availability ?? await probe(userProfile: userProfile);
    if (!resolvedAvailability.available) return null;

    final allowedIds = recommendations
        .map((recommendation) => recommendation.food.id)
        .toList(growable: false);
    final recommendationPayload = recommendations
        .map(
          (item) => {
            'food_id': item.food.id,
            'food_name': item.food.name,
            'score': item.score,
            'decision': item.decision,
            'reasons': item.reasons,
            'score_breakdown': item.scoreBreakdown,
            'feature_snapshot': item.featureSnapshot.toJson(),
            'source_system': item.food.sourceSystem,
            'jurisdiction': item.food.jurisdiction,
          },
        )
        .toList(growable: false);
    final schema = {
      'type': 'object',
      'properties': {
        'summary': {'type': 'string'},
        'candidate_notes': {
          'type': 'object',
        },
      },
      'required': ['summary', 'candidate_notes'],
    };
    final prompt = [
      'You are polishing ParkinSUM next-meal recommendation text.',
      'This is copy polish only. Do not reorder candidates.',
      'Rules, scores, decisions, timing windows, and database facts are authoritative.',
      'Allowed food_id keys JSON: ${jsonEncode(allowedIds)}',
      'candidate_notes must be a map keyed only by those exact food_id values.',
      'Do not invent foods, scores, drugs, diagnoses, dosing instructions, or evidence.',
      'Use plain language in ${userProfile.displayLocale}.',
      ...contextLines,
      'Recommendation JSON:',
      jsonEncode(recommendationPayload),
    ].join('\n');

    final payload = await _completeStructured(
      availability: resolvedAvailability,
      model: resolvedAvailability.model,
      prompt: prompt,
      schema: schema,
      schemaName: 'recommendation_copy_polish',
      timeout: _timeout(userProfile),
    );
    if (payload == null) return null;
    final notes = _safeCandidateNotes(payload, allowedIds.toSet());
    if (notes.isEmpty) return null;
    return LocalAiRecommendationPolishResult(
      summary: _payloadText(
        payload,
        'summary',
        'Local AI polished the recommendation wording without changing order.',
      ),
      candidateNotes: notes,
      provider: resolvedAvailability.provider,
      endpoint: resolvedAvailability.endpoint,
      model: resolvedAvailability.model,
    );
  }

  Duration _timeout(UserProfile userProfile) {
    final raw = userProfile.localAiTimeoutMs;
    final safe = raw < 1000 ? 1000 : raw;
    return Duration(milliseconds: safe);
  }

  String _textModel(UserProfile userProfile) {
    final value = userProfile.localAiModel.trim();
    return value.isEmpty ? LocalAiRecommendedModels.gemmaText : value;
  }

  String _medicalModel(UserProfile userProfile) {
    final value = userProfile.localAiMedicalModel.trim();
    return value.isEmpty ? LocalAiRecommendedModels.medGemmaText : value;
  }

  String _normalizedProvider(String raw) {
    final value = raw.trim().toLowerCase();
    if (LocalAiProviders.supported.contains(value)) {
      return value;
    }
    return LocalAiProviders.auto;
  }

  List<_ProviderTarget> _providerTargets(UserProfile userProfile) {
    final provider = _normalizedProvider(userProfile.localAiProviderPreference);
    final ollama = _ProviderTarget(
      provider: LocalAiProviders.ollama,
      endpoint: userProfile.localAiOllamaEndpoint.trim(),
    );
    final openAiCompat = _ProviderTarget(
      provider: LocalAiProviders.openAiCompat,
      endpoint: userProfile.localAiOpenAiCompatEndpoint.trim(),
    );
    return switch (provider) {
      LocalAiProviders.ollama => [ollama],
      LocalAiProviders.openAiCompat => [openAiCompat],
      _ => [ollama, openAiCompat],
    };
  }

  Future<LocalAiAvailability> _probeTarget({
    required String provider,
    required String endpoint,
    required String model,
    required String medicalModel,
    required Duration timeout,
  }) async {
    if (!_isLocalhostEndpoint(endpoint)) {
      return LocalAiAvailability(
        available: false,
        provider: provider,
        endpoint: endpoint,
        model: model,
        medicalModel: medicalModel,
        message: 'Endpoint must stay on localhost.',
      );
    }

    try {
      final modelAvailable = await _probeModelAvailable(
        provider: provider,
        endpoint: endpoint,
        model: model,
        timeout: timeout,
      );

      if (modelAvailable) {
        var medicalAvailable = model == medicalModel;
        if (!medicalAvailable && medicalModel.trim().isNotEmpty) {
          medicalAvailable = await _probeModelAvailable(
            provider: provider,
            endpoint: endpoint,
            model: medicalModel,
            timeout: timeout,
          );
        }
        return LocalAiAvailability(
          available: true,
          provider: provider,
          endpoint: endpoint,
          model: model,
          medicalModel: medicalModel,
          medicalAvailable: medicalAvailable,
          message: medicalAvailable
              ? 'Local AI endpoint responded.'
              : 'Local AI endpoint responded; MedGemma model is optional and not available.',
        );
      }

      return LocalAiAvailability(
        available: false,
        provider: provider,
        endpoint: endpoint,
        model: model,
        medicalModel: medicalModel,
        message: provider == LocalAiProviders.ollama
            ? 'Ollama endpoint responded but the configured model was not found.'
            : 'Endpoint responded but the configured model was not available.',
      );
    } on TimeoutException {
      return LocalAiAvailability(
        available: false,
        provider: provider,
        endpoint: endpoint,
        model: model,
        medicalModel: medicalModel,
        message: 'Local AI probe timed out.',
      );
    } catch (_) {
      return LocalAiAvailability(
        available: false,
        provider: provider,
        endpoint: endpoint,
        model: model,
        medicalModel: medicalModel,
        message: 'Local AI probe failed.',
      );
    }
  }

  Future<bool> _probeModelAvailable({
    required String provider,
    required String endpoint,
    required String model,
    required Duration timeout,
  }) async {
    if (provider == LocalAiProviders.ollama) {
      final response = await _client.get(
        _ollamaTagsUri(endpoint),
        headers: {'Accept': 'application/json'},
      ).timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      final models = payload['models'] as List<dynamic>? ?? const <dynamic>[];
      return models.whereType<Map<String, dynamic>>().any((item) {
        final name = item['name']?.toString() ?? '';
        final listedModel = item['model']?.toString() ?? '';
        return _ollamaModelMatches(model, name) ||
            _ollamaModelMatches(model, listedModel);
      });
    }

    final response = await _probeModel(
      provider: provider,
      endpoint: endpoint,
      model: model,
      timeout: timeout,
    );
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  Future<http.Response> _probeModel({
    required String provider,
    required String endpoint,
    required String model,
    required Duration timeout,
  }) {
    final uri = Uri.parse(endpoint);
    return switch (provider) {
      LocalAiProviders.ollama => _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'stream': false,
              'messages': const [
                {'role': 'user', 'content': 'reply with {"ok":true}'}
              ],
              'format': {
                'type': 'object',
                'properties': {
                  'ok': {'type': 'boolean'}
                },
                'required': ['ok']
              },
            }),
          )
          .timeout(timeout),
      LocalAiProviders.openAiCompat => _client
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'messages': const [
                {'role': 'user', 'content': 'reply with {"ok":true}'}
              ],
              'response_format': {
                'type': 'json_schema',
                'json_schema': {
                  'name': 'availability_probe',
                  'schema': {
                    'type': 'object',
                    'properties': {
                      'ok': {'type': 'boolean'}
                    },
                    'required': ['ok']
                  }
                }
              }
            }),
          )
          .timeout(timeout),
      _ => throw UnsupportedError('Unsupported provider'),
    };
  }

  Uri _ollamaTagsUri(String endpoint) {
    final uri = Uri.parse(endpoint);
    return uri.replace(
      pathSegments: const ['api', 'tags'],
      query: null,
      fragment: null,
    );
  }

  bool _ollamaModelMatches(String configured, String listed) {
    final expected = configured.trim();
    final actual = listed.trim();
    if (expected.isEmpty || actual.isEmpty) return false;
    if (expected == actual) return true;
    if (!expected.contains(':') && actual == '$expected:latest') return true;
    if (expected.endsWith(':latest') &&
        actual == expected.substring(0, expected.length - ':latest'.length)) {
      return true;
    }
    return false;
  }

  bool _isLocalhostEndpoint(String endpoint) {
    try {
      final uri = Uri.parse(endpoint);
      final host = uri.host.toLowerCase();
      return host == '127.0.0.1' || host == 'localhost';
    } catch (_) {
      return false;
    }
  }

  Future<Map<String, dynamic>?> _tryOllama({
    required String endpoint,
    required String model,
    required String prompt,
    required Map<String, dynamic> schema,
    required Duration timeout,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'stream': false,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
              'format': schema,
            }),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content =
          ((json['message'] as Map<String, dynamic>?)?['content'] ?? '{}')
              .toString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _completeStructured({
    required LocalAiAvailability availability,
    required String model,
    required String prompt,
    required Map<String, dynamic> schema,
    required String schemaName,
    required Duration timeout,
  }) {
    return switch (availability.provider) {
      LocalAiProviders.ollama => _tryOllama(
          endpoint: availability.endpoint,
          model: model,
          prompt: prompt,
          schema: schema,
          timeout: timeout,
        ),
      LocalAiProviders.openAiCompat => _tryOpenAiCompat(
          endpoint: availability.endpoint,
          model: model,
          prompt: prompt,
          schema: schema,
          schemaName: schemaName,
          timeout: timeout,
        ),
      _ => Future.value(null),
    };
  }

  Future<Map<String, dynamic>?> _tryOpenAiCompat({
    required String endpoint,
    required String model,
    required String prompt,
    required Map<String, dynamic> schema,
    String schemaName = 'safe_rerank',
    required Duration timeout,
  }) async {
    try {
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': model,
              'messages': [
                {'role': 'user', 'content': prompt}
              ],
              'response_format': {
                'type': 'json_schema',
                'json_schema': {
                  'name': schemaName,
                  'schema': schema,
                }
              }
            }),
          )
          .timeout(timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = json['choices'] as List<dynamic>? ?? const [];
      if (choices.isEmpty) return null;
      final content = (((choices.first as Map<String, dynamic>)['message']
                  as Map<String, dynamic>?)?['content'] ??
              '{}')
          .toString();
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  LocalAiRerankResult? _safeResult({
    required Map<String, dynamic> payload,
    required List<FoodRecommendation> candidates,
    required LocalAiAvailability availability,
  }) {
    final requestedIds =
        (payload['candidate_ids'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false);
    final whitelist = candidates.map((item) => item.food.id).toSet();
    if (requestedIds.isEmpty) return null;
    if (requestedIds.length != whitelist.length) {
      return null;
    }
    if (requestedIds.any((id) => !whitelist.contains(id))) {
      return null;
    }
    if (requestedIds.toSet().length != requestedIds.length) {
      return null;
    }
    return LocalAiRerankResult(
      candidateIds: requestedIds,
      summary: (payload['summary']?.toString().trim().isEmpty ?? true)
          ? 'Local AI reranked only the safe candidate whitelist.'
          : payload['summary'].toString().trim(),
      safetyChecks:
          (payload['safety_checks'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .where((value) => value.trim().isNotEmpty)
              .toList(growable: false),
      rankingRationale:
          (payload['ranking_rationale'] as List<dynamic>? ?? const <dynamic>[])
              .map((value) => value.toString())
              .where((value) => value.trim().isNotEmpty)
              .toList(growable: false),
      candidateNotes: _safeCandidateNotes(payload, whitelist),
      provider: availability.provider,
      endpoint: availability.endpoint,
      model: availability.model,
    );
  }

  String _payloadText(
    Map<String, dynamic> payload,
    String key,
    String fallback,
  ) {
    final value = payload[key]?.toString().trim();
    return value == null || value.isEmpty ? fallback : value;
  }

  Map<String, String> _safeCandidateNotes(
    Map<String, dynamic> payload,
    Set<String> whitelist,
  ) {
    final raw = payload['candidate_notes'];
    if (raw is! Map<String, dynamic>) return const <String, String>{};
    final notes = <String, String>{};
    for (final entry in raw.entries) {
      if (!whitelist.contains(entry.key)) continue;
      final value = entry.value.toString().trim();
      if (value.isNotEmpty) notes[entry.key] = value;
    }
    return notes;
  }

  List<String> _payloadStringList(
    Map<String, dynamic> payload,
    String key,
    List<String> fallback,
  ) {
    final values = (payload[key] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? fallback : values;
  }
}

class _ProviderTarget {
  final String provider;
  final String endpoint;

  const _ProviderTarget({
    required this.provider,
    required this.endpoint,
  });
}
