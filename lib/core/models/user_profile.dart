import 'purpose_bound_consent.dart';

class UserProfile {
  final String patientId;
  final String registrationRegion;
  final String displayLocale;
  final List<String> contentJurisdictionOverride;
  final String? dietProfileRegion;
  final String timezone;
  // 结构化吞咽/质地偏好：
  // - 当前只支持三档保守模式，优先服务 recommendation 过滤/降权；
  // - 不是临床吞咽评估，也不替代 SLP 个体化分级。
  final String swallowingTextureMode;
  // 本地 AI 增强属于显式 opt-in 能力，默认关闭。
  final bool localAiConsentEnabled;
  final List<PurposeBoundConsentReceipt> consentReceipts;
  final bool consentReceiptLedgerBlocked;
  final bool legacyLocalAiConsentRequested;
  // 本地 AI 仅支持 localhost 范围内的 provider。
  // `auto` 会优先探测 Ollama，再回退到 OpenAI-compatible llama.cpp server。
  final String localAiProviderPreference;
  final String localAiModel;
  final String localAiMedicalModel;
  final String localAiOllamaEndpoint;
  final String localAiOpenAiCompatEndpoint;
  final int localAiTimeoutMs;

  UserProfile({
    required this.patientId,
    required this.registrationRegion,
    required this.displayLocale,
    required this.contentJurisdictionOverride,
    required this.dietProfileRegion,
    required this.timezone,
    required this.swallowingTextureMode,
    required this.localAiConsentEnabled,
    List<PurposeBoundConsentReceipt> consentReceipts =
        const <PurposeBoundConsentReceipt>[],
    this.consentReceiptLedgerBlocked = false,
    this.legacyLocalAiConsentRequested = false,
    required this.localAiProviderPreference,
    required this.localAiModel,
    required this.localAiMedicalModel,
    required this.localAiOllamaEndpoint,
    required this.localAiOpenAiCompatEndpoint,
    required this.localAiTimeoutMs,
  }) : consentReceipts = List<PurposeBoundConsentReceipt>.unmodifiable(
         consentReceipts,
       );

  factory UserProfile.defaults() {
    return UserProfile(
      patientId: 'local_user',
      registrationRegion: 'US',
      displayLocale: 'en-US',
      contentJurisdictionOverride: <String>[],
      dietProfileRegion: 'US',
      timezone: 'America/Toronto',
      swallowingTextureMode: 'unrestricted',
      localAiConsentEnabled: false,
      consentReceipts: const <PurposeBoundConsentReceipt>[],
      localAiProviderPreference: 'auto',
      localAiModel: 'gemma3n:e2b',
      localAiMedicalModel: 'hf.co/unsloth/medgemma-1.5-4b-it-GGUF:Q4_K_M',
      localAiOllamaEndpoint: 'http://127.0.0.1:11434/api/chat',
      localAiOpenAiCompatEndpoint: 'http://127.0.0.1:8080/v1/chat/completions',
      localAiTimeoutMs: 12000,
    );
  }

  PurposeBoundConsentEvaluation get localAiConsentEvaluation =>
      evaluateLocalAiConsent(
        consentReceipts,
        ledgerBlocked: consentReceiptLedgerBlocked,
      );

  bool get hasCurrentLocalAiConsent => localAiConsentEvaluation.granted;

  UserProfile withLocalAiConsentDecision({
    required bool enabled,
    required DateTime recordedAt,
    required String source,
  }) {
    final current = localAiConsentEvaluation;
    if (enabled &&
        current.status == PurposeBoundConsentStatus.blockedIntegrity) {
      throw StateError(
        'Consent ledger integrity must be repaired by revoking.',
      );
    }
    if (current.latestReceipt != null &&
        current.granted == enabled &&
        current.status != PurposeBoundConsentStatus.staleNotice) {
      return this;
    }
    final existing =
        current.status == PurposeBoundConsentStatus.blockedIntegrity
        ? <PurposeBoundConsentReceipt>[]
        : consentReceipts
              .where(
                (receipt) => receipt.featureId == localAiRerankingFeatureId,
              )
              .toList(growable: false);
    final next = PurposeBoundConsentReceipt.localAi(
      decision: enabled
          ? PurposeBoundConsentDecision.grant
          : PurposeBoundConsentDecision.revoke,
      sequence: existing.length + 1,
      recordedAt: recordedAt,
      source: source,
    );
    return copyWith(
      localAiConsentEnabled: enabled,
      consentReceipts: <PurposeBoundConsentReceipt>[
        for (final receipt in consentReceipts)
          if (receipt.featureId != localAiRerankingFeatureId) receipt,
        ...existing,
        next,
      ],
      consentReceiptLedgerBlocked: false,
      legacyLocalAiConsentRequested: false,
    );
  }

  UserProfile copyWith({
    String? patientId,
    String? registrationRegion,
    String? displayLocale,
    List<String>? contentJurisdictionOverride,
    String? dietProfileRegion,
    String? timezone,
    String? swallowingTextureMode,
    bool? localAiConsentEnabled,
    List<PurposeBoundConsentReceipt>? consentReceipts,
    bool? consentReceiptLedgerBlocked,
    bool? legacyLocalAiConsentRequested,
    String? localAiProviderPreference,
    String? localAiModel,
    String? localAiMedicalModel,
    String? localAiOllamaEndpoint,
    String? localAiOpenAiCompatEndpoint,
    int? localAiTimeoutMs,
  }) {
    return UserProfile(
      patientId: patientId ?? this.patientId,
      registrationRegion: registrationRegion ?? this.registrationRegion,
      displayLocale: displayLocale ?? this.displayLocale,
      contentJurisdictionOverride:
          contentJurisdictionOverride ?? this.contentJurisdictionOverride,
      dietProfileRegion: dietProfileRegion ?? this.dietProfileRegion,
      timezone: timezone ?? this.timezone,
      swallowingTextureMode:
          swallowingTextureMode ?? this.swallowingTextureMode,
      localAiConsentEnabled:
          localAiConsentEnabled ?? this.localAiConsentEnabled,
      consentReceipts: consentReceipts ?? this.consentReceipts,
      consentReceiptLedgerBlocked:
          consentReceiptLedgerBlocked ?? this.consentReceiptLedgerBlocked,
      legacyLocalAiConsentRequested:
          legacyLocalAiConsentRequested ?? this.legacyLocalAiConsentRequested,
      localAiProviderPreference:
          localAiProviderPreference ?? this.localAiProviderPreference,
      localAiModel: localAiModel ?? this.localAiModel,
      localAiMedicalModel: localAiMedicalModel ?? this.localAiMedicalModel,
      localAiOllamaEndpoint:
          localAiOllamaEndpoint ?? this.localAiOllamaEndpoint,
      localAiOpenAiCompatEndpoint:
          localAiOpenAiCompatEndpoint ?? this.localAiOpenAiCompatEndpoint,
      localAiTimeoutMs: localAiTimeoutMs ?? this.localAiTimeoutMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'patientId': patientId,
    'registrationRegion': registrationRegion,
    'displayLocale': displayLocale,
    'contentJurisdictionOverride': contentJurisdictionOverride,
    'dietProfileRegion': dietProfileRegion,
    'timezone': timezone,
    'swallowingTextureMode': swallowingTextureMode,
    'localAiConsentEnabled': hasCurrentLocalAiConsent,
    'consentReceipts': consentReceipts
        .map((receipt) => receipt.toJson())
        .toList(growable: false),
    'consentReceiptLedgerBlocked': consentReceiptLedgerBlocked,
    'legacyLocalAiConsentRequested': legacyLocalAiConsentRequested,
    'localAiProviderPreference': localAiProviderPreference,
    'localAiModel': localAiModel,
    'localAiMedicalModel': localAiMedicalModel,
    'localAiOllamaEndpoint': localAiOllamaEndpoint,
    'localAiOpenAiCompatEndpoint': localAiOpenAiCompatEndpoint,
    'localAiTimeoutMs': localAiTimeoutMs,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    final rawReceipts = json['consentReceipts'];
    final parsedReceipts = <PurposeBoundConsentReceipt>[];
    var ledgerBlocked = json['consentReceiptLedgerBlocked'] == true;
    if (rawReceipts != null) {
      if (rawReceipts is! List<dynamic>) {
        ledgerBlocked = true;
      } else {
        for (final rawReceipt in rawReceipts) {
          try {
            if (rawReceipt is! Map) {
              ledgerBlocked = true;
              break;
            }
            parsedReceipts.add(
              PurposeBoundConsentReceipt.fromJson(
                Map<String, dynamic>.from(rawReceipt),
              ),
            );
          } catch (_) {
            ledgerBlocked = true;
            break;
          }
        }
      }
    }
    final evaluation = evaluateLocalAiConsent(
      parsedReceipts,
      ledgerBlocked: ledgerBlocked,
    );
    final legacyRequested =
        json['legacyLocalAiConsentRequested'] == true ||
        (rawReceipts == null && json['localAiConsentEnabled'] == true);
    return UserProfile(
      patientId: (json['patientId'] as String?) ?? 'local_user',
      registrationRegion: (json['registrationRegion'] as String?) ?? 'US',
      displayLocale: (json['displayLocale'] as String?) ?? 'en-US',
      contentJurisdictionOverride:
          (json['contentJurisdictionOverride'] as List<dynamic>? ?? const [])
              .map((value) => value.toString())
              .toList(growable: false),
      dietProfileRegion: json['dietProfileRegion'] as String?,
      timezone: (json['timezone'] as String?) ?? 'America/Toronto',
      swallowingTextureMode:
          (json['swallowingTextureMode'] as String?) ?? 'unrestricted',
      localAiConsentEnabled: evaluation.granted,
      consentReceipts: parsedReceipts,
      consentReceiptLedgerBlocked: ledgerBlocked,
      legacyLocalAiConsentRequested: legacyRequested,
      localAiProviderPreference:
          (json['localAiProviderPreference'] as String?) ?? 'auto',
      localAiModel: (json['localAiModel'] as String?) ?? 'gemma3n:e2b',
      localAiMedicalModel:
          (json['localAiMedicalModel'] as String?) ??
          'hf.co/unsloth/medgemma-1.5-4b-it-GGUF:Q4_K_M',
      localAiOllamaEndpoint:
          (json['localAiOllamaEndpoint'] as String?) ??
          'http://127.0.0.1:11434/api/chat',
      localAiOpenAiCompatEndpoint:
          (json['localAiOpenAiCompatEndpoint'] as String?) ??
          'http://127.0.0.1:8080/v1/chat/completions',
      localAiTimeoutMs: (json['localAiTimeoutMs'] as num?)?.toInt() ?? 12000,
    );
  }
}
