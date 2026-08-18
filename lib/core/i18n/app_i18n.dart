import 'app_i18n_full_translations.dart';

/// Lightweight in-app localization layer.
///
/// 这里先用项目内字典把现有页面全部接到 `displayLocale`，
/// 避免在当前阶段为了修复语言切换而引入更重的生成式 i18n 管线。
/// 后续如果页面继续扩大，可以再迁移到 Flutter gen-l10n。
class AppI18n {
  final String localeTag;

  const AppI18n._(this.localeTag);

  factory AppI18n.fromLocaleTag(String localeTag) {
    return AppI18n._(localeTag);
  }

  String get languageFamily {
    if (localeTag.startsWith('zh')) return 'zh';
    if (localeTag.startsWith('fr')) return 'fr';
    if (localeTag.startsWith('ja')) return 'ja';
    if (localeTag.startsWith('ko')) return 'ko';
    if (localeTag.startsWith('hi')) return 'hi';
    if (localeTag.startsWith('es')) return 'es';
    if (localeTag.startsWith('vi')) return 'vi';
    if (localeTag.startsWith('th')) return 'th';
    if (localeTag.startsWith('id')) return 'id';
    if (localeTag.startsWith('ru')) return 'ru';
    if (localeTag.startsWith('pl')) return 'pl';
    if (localeTag.startsWith('ar')) return 'ar';
    return 'en';
  }

  String tr(String key, [Map<String, String> params = const {}]) {
    // Lookup priority (each step falls through if it returns null):
    // 1. Runtime DB snapshot keyed by exact `localeTag` (e.g. `'ko-KR'`).
    //    This is populated at bootstrap from `locale_resource_bundle`, so
    //    importer-side seeds (and any future locale rollout) win without
    //    redeploying the app binary.
    // 2. Runtime DB snapshot keyed by language family (`'ko'`).
    // 3. Hardcoded `_strings[languageFamily]` (existing behaviour).
    // 4. Hardcoded `_strings['en']` ultimate fallback.
    // 5. Raw key (developer-visible).
    String? value = _runtimeOverride[localeTag]?[key];
    value ??= _runtimeOverride[languageFamily]?[key];
    value ??= (_strings[languageFamily] ?? _strings['en']!)[key];
    value ??= _strings['en']![key];
    var resolved = value ?? key;
    params.forEach((placeholder, replacement) {
      resolved = resolved.replaceAll('{$placeholder}', replacement);
    });
    return _stripUnresolvedPlaceholders(resolved);
  }

  /// Live-loaded translations from the database `locale_resource_bundle`
  /// table. Populated by `AppState.bootstrap()` and used by `tr()` *before*
  /// the hardcoded `_strings` map. Existing zh / en / ja / fr translations
  /// remain unaffected because the hardcoded entries take over whenever a
  /// runtime override is missing for a particular key.
  ///
  /// Schema: `localeTag → namespace.key → text`. Both exact tags
  /// (`ko-KR`) and bare family tags (`ko`) are accepted.
  static final Map<String, Map<String, String>> _runtimeOverride =
      <String, Map<String, String>>{};

  /// Replace the runtime translation snapshot. Called once at bootstrap.
  /// Each row's flattened key is `'$namespace.$key'` so DB-driven entries
  /// don't collide with the hardcoded `tr('nav.home')`-style keys unless
  /// the DB explicitly declares that namespace.
  static void installRuntimeOverrides(
    Iterable<({String localeTag, String namespace, String key, String text})>
    rows,
  ) {
    _runtimeOverride.clear();
    for (final row in rows) {
      final flatKey = '${row.namespace}.${row.key}';
      (_runtimeOverride[row.localeTag] ??= <String, String>{})[flatKey] =
          row.text;
      // Also index by language family so `'ko-KR'` rows match a user whose
      // saved tag is `'ko'` (and vice-versa).
      final family = row.localeTag.contains('-')
          ? row.localeTag.split('-').first
          : row.localeTag;
      if (family != row.localeTag) {
        (_runtimeOverride[family] ??= <String, String>{}).putIfAbsent(
          flatKey,
          () => row.text,
        );
      }
    }
  }

  /// Test / debugging helper: reset the runtime override map.
  static void resetRuntimeOverrides() {
    _runtimeOverride.clear();
  }

  String _stripUnresolvedPlaceholders(String value) {
    return value
        .replaceAll(RegExp(r'\s*[（(][^）)]*\{[A-Za-z0-9_]+\}[^）)]*[）)]'), '')
        .replaceAll(RegExp(r'\s*\{[A-Za-z0-9_]+\}'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// 把推荐引擎内部路径码转成人类可读文案。
  /// UI 不应直接暴露 `conservative_safety_gate` 这类实现细节。
  String recommendationPathLabel(String path) {
    switch (path) {
      case 'hybrid_local_ai':
        return tr('recommend.path.hybrid_local_ai');
      case 'conservative_safety_gate':
        return tr('recommend.path.conservative_safety_gate');
      case 'conservative_gate_block':
        return tr('recommend.path.conservative_gate_block');
      case 'fallback_invalid_ai':
        return tr('recommend.path.fallback_invalid_ai');
      case 'conservative_cdss':
        return tr('recommend.path.conservative_cdss');
      default:
        return path;
    }
  }

  /// 翻译推荐编排器和本地 AI adapter 产生的固定运行时说明。
  /// 这些字符串来自安全门和本地 AI 探测，不是医学事实本身。
  String recommendationRuntimeMessage(String message) {
    final normalized = message.trim();
    switch (normalized) {
      case 'No localhost Ollama/llama.cpp endpoint responded.':
        return tr('recommend.runtime.local_ai_endpoint_unavailable');
      case 'Endpoint must stay on localhost.':
        return tr('recommend.runtime.endpoint_must_be_localhost');
      case 'Safety gate kept the result on the conservative path.':
        return tr('recommend.runtime.safety_gate_conservative');
      case 'Next-meal time window is missing.':
        return tr('recommend.runtime.next_meal_window_missing');
      case 'No prior meal history is available for safe AI reranking.':
        return tr('recommend.runtime.no_prior_meal_history');
      case 'Latest meal time still comes from legacy migrated timing.':
        return tr('recommend.runtime.legacy_meal_time');
      case 'Latest meal includes an iron supplement; keep reranking conservative.':
        return tr('recommend.runtime.iron_conservative');
      case 'Latest meal includes a multivitamin with iron; keep reranking conservative.':
        return tr('recommend.runtime.iron_multivitamin_conservative');
      case 'Latest meal uses a starch-based thickener; keep deterministic safety review.':
        return tr('recommend.runtime.starch_thickener_conservative');
      case 'Continuous enteral feeding context is active; keep deterministic review.':
        return tr('recommend.runtime.enteral_conservative');
      case 'Local AI path not enabled by user consent.':
        return tr('recommend.runtime.local_ai_not_consented');
      case 'Local AI endpoint unavailable.':
        return tr('recommend.runtime.local_ai_unavailable');
      case 'Returned deterministic conservative recommendations instead.':
        return tr('recommend.runtime.returned_conservative');
      case 'Structured local AI output failed validation.':
        return tr('recommend.runtime.ai_validation_failed');
      case 'Local AI did not return a valid whitelist-only ordering.':
        return tr('recommend.runtime.ai_invalid_whitelist');
      case 'CDSS-backed conservative path used real variant observations when available.':
        return tr('recommend.runtime.cdss_conservative_observations');
      case 'Local AI reranking succeeded.':
        return tr('recommend.runtime.local_ai_success');
      case 'Local AI copy polish succeeded.':
        return tr('recommend.runtime.local_ai_copy_polish_success');
      case 'Local AI endpoint responded; MedGemma model is optional and not available.':
        return tr('recommend.runtime.medgemma_optional_unavailable');
      case 'Recommendation stayed on the conservative path.':
        return tr('recommend.runtime.recommendation_conservative');
      case 'Levodopa timing window is too sensitive for AI reranking.':
        return tr('recommend.runtime.levodopa_ai_sensitive');
      default:
        return normalized;
    }
  }

  String localeLabel(String locale) {
    switch (locale) {
      case 'zh-CN':
        return '中文（中国）';
      case 'en-US':
        return 'English (United States)';
      case 'en-CA':
        return 'English (Canada)';
      case 'fr-CA':
        return 'Francais (Canada)';
      case 'fr-FR':
        return 'Francais (France)';
      case 'ja-JP':
        return '日本語（日本）';
      // Locales rolled out alongside `LocaleResourceSeedImporter` and
      // `secondary_source_registry.dart`. Each label is shown in its own
      // script so the picker reads natively in every language.
      case 'ko-KR':
        return '한국어 (대한민국)';
      case 'hi-IN':
        return 'हिन्दी (भारत)';
      case 'es-ES':
        return 'Español (España)';
      case 'es-MX':
        return 'Español (México)';
      case 'vi-VN':
        return 'Tiếng Việt (Việt Nam)';
      case 'th-TH':
        return 'ไทย (ประเทศไทย)';
      case 'id-ID':
        return 'Bahasa Indonesia (Indonesia)';
      case 'ru-RU':
        return 'Русский (Россия)';
      case 'pl-PL':
        return 'Polski (Polska)';
      case 'ar-SA':
        return 'العربية (المملكة العربية السعودية)';
      default:
        return locale;
    }
  }

  String regionLabel(String regionCode) {
    // Routes through `tr()` so the runtime DB override (populated by
    // `LocaleResourceSeedImporter` → `regions` namespace) wins over the
    // hardcoded `_strings` map. Falls back to the uppercase region code if
    // no translation exists in either source.
    final key = 'region.${regionCode.toUpperCase()}';
    final translated = tr(key);
    if (translated == key) return regionCode.toUpperCase();
    return translated;
  }

  String textureModeLabel(String mode) {
    switch (mode) {
      case 'soft_or_liquid':
        return tr('texture_mode.soft_or_liquid');
      case 'liquid_only':
        return tr('texture_mode.liquid_only');
      default:
        return tr('texture_mode.unrestricted');
    }
  }

  String textureClassLabel(String? textureClass) {
    switch (textureClass) {
      case 'liquid':
        return tr('texture_class.liquid');
      case 'soft':
        return tr('texture_class.soft');
      case 'regular':
        return tr('texture_class.regular');
      default:
        return textureClass ?? tr('common.not_available');
    }
  }

  String mealSlotLabel(String mealSlot) {
    switch (mealSlot) {
      case 'breakfast':
        return tr('meal_slot.breakfast');
      case 'lunch':
        return tr('meal_slot.lunch');
      case 'dinner':
        return tr('meal_slot.dinner');
      case 'snack':
        return tr('meal_slot.snack');
      default:
        return mealSlot;
    }
  }

  String foodTextureSummary({
    required String? textureClass,
    required int? iddsiLevel,
  }) {
    if (textureClass == null && iddsiLevel == null) {
      return tr('common.not_available');
    }
    final parts = <String>[
      if (textureClass != null)
        '${tr('common.texture')}: ${textureClassLabel(textureClass)}',
      if (iddsiLevel != null) 'IDDSI $iddsiLevel',
    ];
    return parts.join(' · ');
  }

  String decisionLabel(String decision) {
    switch (decision) {
      case 'BLOCK':
        return tr('decision.block');
      case 'REQUIRE_REVIEW':
        return tr('decision.require_review');
      case 'DISCOURAGE':
        return tr('decision.discourage');
      case 'WARN':
        return tr('decision.warn');
      case 'INFO':
        return tr('decision.info');
      case 'ALLOW':
        return tr('decision.allow');
      case 'DEFER':
        return tr('decision.defer');
      default:
        return decision;
    }
  }

  String severityLabel(String severity) {
    switch (severity) {
      case 'low':
        return tr('severity.low');
      case 'moderate':
        return tr('severity.moderate');
      case 'high':
        return tr('severity.high');
      case 'critical':
        return tr('severity.critical');
      default:
        return severity;
    }
  }

  String missingFieldLabel(String field) {
    switch (field) {
      case 'dose':
        return tr('missing.dose');
      case 'formulation':
        return tr('missing.formulation');
      case 'time':
        return tr('missing.time');
      case 'meal_time':
        return tr('missing.meal_time');
      case 'coevent_time':
        return tr('missing.coevent_time');
      case 'thickener_type':
        return tr('missing.thickener_type');
      default:
        return field;
    }
  }

  String foodName(String foodId, String fallback) {
    final key = 'food.$foodId';
    final familyMap = _strings[languageFamily] ?? _strings['en']!;
    return familyMap[key] ?? fallback;
  }

  String medicationNote(String drugId, String fallback) {
    final key = 'medication_note.$drugId';
    final familyMap = _strings[languageFamily] ?? _strings['en']!;
    final direct = familyMap[key];
    if (direct != null && direct.trim().isNotEmpty) {
      return direct;
    }
    if (languageFamily == 'zh') {
      final translated =
          _zhMedicationNoteByGeneric[_normalizeMedicationLookup(fallback)];
      if (translated != null && translated.trim().isNotEmpty) {
        return translated;
      }
    }
    return fallback;
  }

  String medicationInteractionSummary(String drugId, String fallback) {
    final key = 'medication_summary.$drugId';
    final familyMap = _strings[languageFamily] ?? _strings['en']!;
    final direct = familyMap[key];
    if (direct != null && direct.trim().isNotEmpty) {
      return direct;
    }
    if (languageFamily == 'zh') {
      final translated =
          _zhMedicationSummaryByGeneric[_normalizeMedicationLookup(fallback)];
      if (translated != null && translated.trim().isNotEmpty) {
        return translated;
      }
    }
    return fallback;
  }

  String medicationName(String drugId, String fallback) {
    final key = 'medication.$drugId';
    final familyMap = _strings[languageFamily] ?? _strings['en']!;
    final direct = familyMap[key];
    if (direct != null && direct.trim().isNotEmpty) {
      return direct;
    }

    // 对导入得到的真实药品记录，id 往往是动态生成的，
    // 因此中文环境下再按通用名做一层保守映射，避免只翻译了种子药物。
    if (languageFamily == 'zh') {
      final translated =
          _zhMedicationNameByGeneric[_normalizeMedicationLookup(fallback)];
      if (translated != null && translated.trim().isNotEmpty) {
        return translated;
      }
    }

    return fallback;
  }

  String _normalizeMedicationLookup(String value) {
    return value
        .toLowerCase()
        .replaceAll(' ', '')
        .replaceAll('-', '')
        .replaceAll('_', '')
        .replaceAll('/', '')
        .replaceAll(',', '')
        .replaceAll('(', '')
        .replaceAll(')', '');
  }

  String sourceSystemLabel(String value) {
    final normalized = value.toUpperCase();
    final key = 'source_system.$normalized';
    final familyMap = _strings[languageFamily] ?? _strings['en']!;
    return familyMap[key] ?? value;
  }

  String routeLabel(String value) {
    final key = 'route.${value.toLowerCase()}';
    final familyMap = _strings[languageFamily] ?? _strings['en']!;
    return familyMap[key] ?? value;
  }

  String dosageFormLabel(String value) {
    final key = 'dosage_form.${value.toLowerCase()}';
    final familyMap = _strings[languageFamily] ?? _strings['en']!;
    return familyMap[key] ?? value;
  }

  String releaseTypeLabel(String value) {
    final key = 'release_type.${value.toLowerCase()}';
    final familyMap = _strings[languageFamily] ?? _strings['en']!;
    return familyMap[key] ?? value;
  }

  /// Read-only view of the full translation dictionary, keyed by language
  /// family then flat key.
  ///
  /// Exposed so pure-Dart governance tooling (the localization safety lint)
  /// can audit **every** shipped string rather than only the representative
  /// SafeCopyTemplateRegistry surfaces. Callers must not mutate it; the maps
  /// are wrapped unmodifiable.
  static Map<String, Map<String, String>> get translationDictionary =>
      Map.unmodifiable({
        for (final entry in _strings.entries)
          entry.key: Map<String, String>.unmodifiable(entry.value),
      });

  /// Language families carried by [translationDictionary] (sorted).
  static List<String> get translationFamilies =>
      _strings.keys.toList(growable: false)..sort();
}

/// Family → flatKey → translatedString.
///
/// `zh` / `en` / `fr` / `ja` are inlined here (long history). The 9 newer
/// language families (`ko`, `hi`, `es`, `vi`, `th`, `id`, `ru`, `pl`, `ar`)
/// were promoted to **full** translation coverage by spreading
/// `kFullLocaleUiTranslations` + `kFullLocaleUiTranslationsExtra` at the end
/// of this map, so picking any of them flips the whole UI into that
/// language instead of showing English fallbacks. Switched from `const` to
/// `final` so the spread can compose at startup.
final Map<String, Map<String, String>> _strings = {
  'zh': {
    'app.welcome': '欢迎',
    'app.loading': '加载中...',
    'onboarding.title': 'ParkinSUM 伙伴版（本地版）',
    'onboarding.description': '本应用仅提供饮食记录与基于规则的提示，不能替代医生或药师的专业建议。',
    'onboarding.registration_region': '注册地区',
    'onboarding.registration_region_help': '用于决定默认司法辖区链和数据源优先级。',
    'onboarding.display_language': '显示语言',
    'onboarding.display_language_help': '控制应用界面语言、日期和数字格式。',
    'onboarding.diet_profile_region': '饮食模板地区',
    'onboarding.diet_profile_region_help': '用于默认餐食模板，不覆盖安全规则。',
    'onboarding.swallowing_texture_mode': '吞咽/质地安全偏好',
    'onboarding.swallowing_texture_mode_help': '用于推荐排序中的保守过滤，不替代临床吞咽评估。',
    'onboarding.content_override': '内容司法辖区覆盖（可选）',
    'onboarding.content_override_help': '用逗号分隔，例如 US,CA,CN',
    'onboarding.local_ai_consent': '启用本地 AI 重排（可选）',
    'onboarding.local_ai_consent_help':
        '仅使用 localhost 上的 Ollama/llama.cpp；如果安全门阻断，会自动回退到保守路径。',
    'onboarding.start': '我已了解，继续',
    'onboarding.appbar': '初始设置',
    'onboarding.step_safety': '使用边界',
    'onboarding.step_safety_subtitle': '确认教育用途与账号数据范围',
    'onboarding.safety_education_title': '规则提示不是医疗建议',
    'onboarding.safety_education_body':
        'ParkinSUM 会基于药品、餐食和地区规则给出保守提示；任何换药、停药或饮食治疗决定仍需医生或药师确认。',
    'onboarding.account_scope_title': '账号数据会按当前用户隔离',
    'onboarding.account_scope_body':
        '完成 onboarding 后，profile、用药、服药记录和后续审计会写入当前账号自己的用户空间。',
    'onboarding.step_profile': '地区与语言',
    'onboarding.step_profile_subtitle': '设置监管地区、显示语言和本地化路径',
    'onboarding.step_medications': '初始用药',
    'onboarding.step_medications_subtitle': '选择参与食药冲突检查的药物',
    'onboarding.active_medications_help':
        '请选择正在使用、需要参与餐食冲突检查的药物。也可以先跳过，之后在药品页补充。',
    'onboarding.record_initial_intake': '记录最近一次服药',
    'onboarding.record_initial_intake_help': '如果刚刚或今天已经服药，记录时间可以让下一餐推荐立即考虑时间窗。',
    'onboarding.initial_intake_drug': '服药药物',
    'onboarding.initial_intake_drug_help': '只列出本步骤已选择的激活药物。',
    'onboarding.initial_intake_time': '服药时间',
    'onboarding.change_time': '更改时间',
    'onboarding.initial_intake_note': '剂量备注',
    'onboarding.initial_intake_note_help': '例如 100/25 mg，或留空。',
    'onboarding.no_medications_available': '当前药品目录为空。',
    'onboarding.step_preferences': '饮食与安全偏好',
    'onboarding.step_preferences_subtitle': '设置饮食地区、质地安全和内容覆盖',
    'onboarding.step_review': '确认并开始',
    'onboarding.step_review_subtitle': '保存 profile、用药和首次记录',
    'onboarding.summary_region': '注册地区',
    'onboarding.summary_language': '显示语言',
    'onboarding.summary_active_meds': '激活药物',
    'onboarding.summary_initial_intake': '首次服药记录',
    'onboarding.summary_texture': '质地偏好',
    'onboarding.next': '下一步',
    'onboarding.back': '返回',
    'onboarding.finish': '完成设置',
    'onboarding.finish_failed': '完成 onboarding 失败：{error}',
    'region.CN': '中国',
    'region.US': '美国',
    'region.CA': '加拿大',
    'region.FR': '法国',
    'region.JP': '日本',
    'region.KR': '韩国',
    'region.IN': '印度',
    'region.ES': '西班牙',
    'region.MX': '墨西哥',
    'region.VN': '越南',
    'region.TH': '泰国',
    'region.ID': '印度尼西亚',
    'region.RU': '俄罗斯',
    'region.PL': '波兰',
    'region.SA': '沙特阿拉伯',
    'nav.home': '首页',
    'nav.analytics': '分析',
    'nav.meals': '餐食',
    'nav.timeline': '时间线',
    'nav.meds': '药品',
    'nav.catalog': '目录',
    'nav.next_meal': '下餐推荐',
    'observatory.title': '算法观测台',
    'observatory.boundary.title': '{count} 个算法 · 一份可审计 UI 契约',
    'observatory.boundary.body':
        '图表直接使用固定、非个人化场景运行生产模型所得的轨迹。曲线仅表示教学性敏感度，不是胃排空检查、吸收剂量、血药浓度、症状预测或医疗建议。',
    'observatory.scenario.title': '回放敏感度场景',
    'observatory.scenario.mixed': '混合参考餐',
    'observatory.scenario.high_fat_protein': '高脂肪 + 高蛋白',
    'observatory.scenario.missing': '数据缺失',
    'observatory.comparison.title': '场景敏感度对比',
    'observatory.comparison.body':
        '三个固定、非个人化场景都运行同一套生产模型，以显示输入完整度和餐食组成如何改变模型输出。差异不是患者预测。',
    'observatory.comparison.semantics': '三个固定场景的模型敏感度比较表',
    'observatory.comparison.scenario': '场景',
    'observatory.comparison.completeness': '完整度',
    'observatory.comparison.lag': '汇总延迟',
    'observatory.comparison.overlap': '冲突重叠',
    'observatory.comparison.bands': '严重度 / 置信度',
    'observatory.coverage.title': '影响结果的算法覆盖',
    'observatory.coverage.body': '所有可改变分类、评分、排序、安全门、回退、身份解析或解释的算法，都必须在下方有可见表示。',
    'observatory.atlas.count': '显示 {visible} / {total} 个算法',
    'observatory.atlas.search': '搜索算法图谱',
    'observatory.atlas.search_hint': '名称、输入、输出、影响或源文件',
    'observatory.atlas.clear': '清除筛选',
    'observatory.atlas.clear_search': '清除算法搜索',
    'observatory.atlas.live_trace': '仅实时轨迹',
    'observatory.atlas.empty': '没有算法符合当前搜索与筛选条件。',
    'observatory.atlas.stage.normalize': '归一化',
    'observatory.atlas.stage.model': '建模',
    'observatory.atlas.stage.decide': '决策',
    'observatory.atlas.stage.resolve': '解析',
    'observatory.atlas.stage.explain': '解释',
    'observatory.gastric.title': '1 · 胃排空模型',
    'observatory.absorption.title': '2 · 左旋多巴吸收机会 + LNAA 竞争',
    'observatory.conflict.title': '3 · 冲突引擎合成',
    'observatory.conflict.body': '跨剂次采用最大重叠值保留最敏感事件；置信度与严重度分别展示。',
    'observatory.tree.title': '4 · 可展开解释树',
    'observatory.candidate.title': '5 · 候选评分拆解',
    'observatory.candidate.body': '最差采样重叠保持主导；蛋白分布和来源质量只能有限修正，不能覆盖它。',
    'observatory.parameters.title': '6 · 版本化参数证据',
    'observatory.oracle.title': '7 · 独立数值真值闸',
    'observatory.oracle.body': '独立写出的解析向量与生产算法输出逐项比较；任何缺失、额外、非有限或超差结果都会阻断验证。',
    'observatory.oracle.summary': '{passed} / {total} 个向量通过',
    'observatory.oracle.algorithms_summary': '{verified} / {total} 个算法已核对',
    'observatory.oracle.not_covered_count': '{count} 个算法尚未覆盖',
    'observatory.oracle.manifest': '真值清单 SHA-256：{digest}',
    'observatory.oracle.configuration': '生产配置 SHA-256：{digest}',
    'observatory.oracle.boundary': '这只证明固定工程向量的独立实现与计算核对，不证明生物学、临床准确性或个体预测。',
    'observatory.oracle.verified': '独立数值向量已核对',
    'observatory.oracle.mismatch': '数值向量不一致',
    'observatory.oracle.not_covered': '尚无独立数值向量',
    'observatory.oracle.blocked': '数值验证已阻断',
    'observatory.ledger.title': '8 · 单位感知的不可变事件账本',
    'observatory.ledger.body':
        '把同一生产场景中的餐食、剂量与上下文投影为有原始值、canonical 单位、时区偏移、同刻顺序、来源和修订身份的只读事件。',
    'observatory.ledger.event_count': '{count} 个有序事件',
    'observatory.ledger.synthetic_count': '{count} 个合成事件',
    'observatory.ledger.digest': '账本 SHA-256：{digest}',
    'observatory.ledger.replay_digest': '规范化回放 SHA-256：{digest}',
    'observatory.ledger.configuration': '绑定配置 SHA-256：{digest}',
    'observatory.minutes_after_meal': '餐后分钟数',
    'observatory.minutes_in_window': '模型时间窗内分钟数',
    'observatory.chart.data_table': '查看图表数据表',
    'observatory.chart.data_table_help': '提供与曲线相同的逐点数值，供键盘和辅助技术读取。',
    'observatory.chart.data_table_semantics': '图表的等价逐点数据表',
    'observatory.chart.events': '事件',
    'observatory.stage.normalize': '1 · 归一化与验证',
    'observatory.stage.model': '2 · 机制建模',
    'observatory.stage.decide': '3 · 决策、安全门与排序',
    'observatory.stage.resolve': '4 · 身份与证据解析',
    'observatory.stage.explain': '5 · 基于来源进行解释',
    'next_meal.title': '下餐推荐',
    'next_meal.subtitle':
        '先选好预计下一餐的时间；保守规则路径给出并保持候选顺序，机制模型只附加教育性时间重叠轨迹，不参与重排。本地 AI 为单独的可选安全白名单重排。',
    'next_meal.input_time': '预计下一餐时间',
    'next_meal.use_local_ai': '启用本地 AI 润色（可选）',
    'next_meal.use_local_ai_help':
        '只调用 localhost 上的 Ollama/llama.cpp 对冲突引擎已筛过的白名单做重排和文字润色；安全门阻断时自动回退到保守路径。',
    'next_meal.generate': '生成推荐',
    'next_meal.window_title': '你提供的进餐时间窗（分钟）',
    'next_meal.window_help': '时间窗由你设置，只用于生成教育性机制轨迹；模型不会替你决定进餐时间，也不会改变保守推荐顺序。',
    'next_meal.window_none': '无',
    'next_meal.window_minutes': '{minutes} 分钟',
    'next_meal.generating': '生成中…',
    'next_meal.empty': '设置好下一餐时间后点击「生成推荐」，引擎会按那个时间窗重新评估。',
    'next_meal.why_these': '为什么是这几样',
    'next_meal.ai_polished': '本地 AI 已润色',
    'next_meal.conservative_engine': '冲突引擎保守路径',
    'next_meal.recommendation_path': '推荐路径',
    'next_meal.gate_reasons': '安全门说明',
    'next_meal.candidates': '候选食物',
    'next_meal.no_candidates': '当前条件下没有合适的候选食物，请调整时间或检查食物目录。',
    'next_meal.error': '生成失败',
    'dashboard.title': '概览',
    'dashboard.status': '状态总览',
    'dashboard.logged_meals': '已记录餐次：{count}',
    'dashboard.active_drugs': '已激活药品：{count}',
    'dashboard.logged_intakes': '已记录服药：{count}',
    'dashboard.recommendations': '推荐',
    'dashboard.no_recommendations': '暂无推荐',
    'dashboard.recommendation_path': '推荐路径',
    'dashboard.recommendation_template':
        '当前模板：{region} · {mealSlot} · {texture}',
    'dashboard.ai_used': '已使用本地 AI 增强',
    'dashboard.ai_not_used': '仅使用保守路径',
    'dashboard.recommendation_why': '为什么推荐',
    'dashboard.recommendation_gate': 'AI / 安全门状态',
    'dashboard.recommendation_macro_line':
        '每 100g：蛋白 {protein} g · 碳水 {carbs} g · 脂肪 {fat} g',
    'dashboard.recommendation_score_line':
        '安全 {safety} · 时序 {schedule} · 数据 {facts} · 上下文惩罚 {context} · 时间窗惩罚 {timing} · 吞咽惩罚 {swallowing} · 模板匹配 {template}',
    'dashboard.recent_meals': '最近餐次（最新 5 条）',
    'dashboard.no_meals': '还没有记录餐次',
    'dashboard.items': '{count} 个条目',
    'dashboard.meal_context_iron_supplement': '含铁剂共事件',
    'dashboard.meal_context_iron_multivitamin': '含铁复合维生素共事件',
    'dashboard.meal_context_starch_thickener': '淀粉型增稠剂',
    'dashboard.meal_context_xanthan_thickener': '黄原胶型增稠剂',
    'dashboard.meal_context_enteral_feed_continuous':
        '连续肠内营养（蛋白 {protein} g/日）',
    'dashboard.meal_context_enteral_feed_bolus': '间断/推注肠内营养',
    'dashboard.edit': '编辑',
    'dashboard.delete': '删除',
    'dashboard.protein_trend': '蛋白质趋势',
    'dashboard.average_protein': '平均蛋白质：{value} g / 餐',
    'dashboard.no_trend': '暂无趋势数据',
    'dashboard.timeline': '时间线',
    'dashboard.no_timeline': '暂无餐次或服药事件',
    'dashboard.add_meal': '添加一餐',
    'dashboard.meal_check': '餐次检查 - {title}',
    'timeline.title': '餐食与服药时间线',
    'timeline.empty': '暂无餐次或服药事件',
    'timeline.add_meal': '添加餐次',
    'timeline.add_intake': '记录服药',
    'timeline.new_intake': '新增服药记录',
    'timeline.edit_intake': '编辑服药记录',
    'timeline.medication': '药品',
    'timeline.active_medication_option': '{name}（已激活）',
    'timeline.dosage_note': '剂量说明',
    'timeline.taken_at': '服用时间',
    'timeline.edit_taken_at': '编辑服用时间',
    'timeline.save_intake': '保存服药记录',
    'timeline.no_medications': '暂无药品目录',
    'timeline.select_medication_first': '请先选择药品',
    'timeline.save_intake_failed': '保存服药记录失败：{error}',
    'timeline.meal_macro_line': '合计：蛋白 {protein} g · 碳水 {carbs} g · 脂肪 {fat} g',
    'timeline.conflict_line': '冲突复核：{severity} · 分数 {score}',
    'timeline.meal_window_line': '进食时间窗：{start} - {end}',
    'timeline.next_meal_window_line': '下一餐时间窗：{start} - {end}',
    'timeline.nearest_medication_line': '最近服药：{name}（{distance}）',
    'timeline.nearest_meal_line': '最近餐次：{title}（{distance}）',
    'timeline.dosage_line': '剂量：{value}',
    'timeline.before': '提前 {value}',
    'timeline.after': '之后 {value}',
    'timeline.no_context_flags': '无补充剂、增稠剂或肠内营养标记',
    'common.close': '关闭',
    'common.done': '完成',
    'common.cancel': '取消',
    'common.apply': '应用',
    'common.optional': '可选',
    'common.delete': '删除',
    'common.edit': '编辑',
    'auth.account_title': 'ParkinSUM 账户',
    'auth.create_account': '创建账户',
    'auth.sign_in': '登录',
    'auth.email': '电子邮箱',
    'auth.password': '密码',
    'auth.invalid_email': '请输入有效的电子邮箱。',
    'auth.password_required': '请输入密码。',
    'auth.password_registration_requirement': '新密码至少需要 {minimum} 个字符。',
    'auth.register': '注册',
    'auth.have_account': '已有账户？登录',
    'auth.need_account': '需要账户？注册',
    'auth.forgot_password': '忘记密码？',
    'auth.privacy': '隐私与免责声明',
    'auth.reset_neutral': '如果该邮箱对应账户，密码重置邮件已发送。',
    'auth.show_password': '显示密码',
    'auth.hide_password': '隐藏密码',
    'reminders.title': '记录提醒',
    'reminders.add': '添加提醒',
    'reminders.edit': '编辑提醒',
    'reminders.resynchronize': '重新提交提醒计划',
    'reminders.synchronized': '提醒计划请求已完成',
    'reminders.last_sync': '最近请求完成：{time}',
    'reminders.schedule_capacity_title': 'ParkinSUM 调度安全预算',
    'reminders.schedule_capacity_body':
        'ParkinSUM 计划请求 {projected}/{limit}，应用安全余量 {headroom}。这是保守产品上限，不是设备剩余系统容量；每个启用的星期几占用一个请求。',
    'reminders.schedule_capacity_invalid':
        '此计划无法提交（{projected}/{limit}）：超过 ParkinSUM 安全预算、标识冲突或计划格式无效。现有计划未更改。',
    'reminders.identity_attestation_title': '插件待处理请求身份核对',
    'reminders.identity_attestation_matched':
        '插件报告的待处理请求身份与计划一致（{installed}/{planned}）。这不是对系统调度器或可见送达的独立验证。',
    'reminders.identity_attestation_drift':
        '插件报告的身份与计划不一致：缺失 {missing}、多余 {extra}、同标识被替换 {replaced}。在重新核对前请勿依赖系统提醒。',
    'reminders.identity_attestation_uninspectable':
        '无法读取插件的待处理请求身份；本地计划仍为准，但系统提醒状态未经核对。',
    'reminders.delete_title': '删除这个提醒？',
    'reminders.delete_body': '“{label}”将从本设备移除，并取消对应的系统提醒。',
    'reminders.boundary_title': '仅用于提醒记录',
    'reminders.boundary_body':
        '时间和文字均由你设置。ParkinSUM 不会计算、推荐或规定服药时间；请按临床医生和药品标签的指导用药。',
    'reminders.web_title': '此平台不支持周期性系统通知',
    'reminders.web_body':
        '你的提醒计划仍会保存在本设备，但 Web、Windows 和 Linux 版本目前不会在应用关闭时发送周期性提醒。',
    'reminders.empty_title': '尚无记录提醒',
    'reminders.empty_body': '可以添加由你自定时间的进餐记录或服药记录提示。',
    'reminders.kind': '记录类型',
    'reminders.kind_mealLog': '进餐记录',
    'reminders.kind_intakeLog': '服药记录',
    'reminders.label': '提醒文字',
    'reminders.label_help': '请写记录提示，不要把它当作剂量或处方指令。',
    'reminders.privacy': '通知隐私',
    'reminders.privacy_help': '仅控制系统可见副本；你写的提醒文字只在 ParkinSUM 内显示。',
    'reminders.privacy_minimal': '最小化（默认）',
    'reminders.privacy_generic': '通用记录提示',
    'reminders.privacy_preview': '系统通知预览',
    'reminders.privacy_minimal_boundary':
        'Android 会请求安全锁屏不显示通知内容；Apple 平台仍遵循用户的系统通知预览设置。',
    'reminders.privacy_generic_boundary':
        'Android 会请求锁屏仅显示基本信息；Apple 平台仍遵循用户的系统通知预览设置。',
    'reminders.days': '重复日期',
    'reminders.next': '下次',
    'reminders.validation': '请输入提醒文字并至少选择一天。',
    'reminders.error_load_failed': '无法读取本设备保存的提醒。',
    'reminders.error_permission_denied': '系统通知权限未开启，提醒未启用。',
    'reminders.error_schedule_failed': '系统提醒同步失败。本地已有计划仍为准，并会在下次启动或恢复时重试。',
    'reminders.error_recovery_required':
        '设备中的提醒计划状态无法确认。本地已有计划仍为准；请重新提交计划并确认后再依赖系统提醒。',
    'reminders.error_schedule_invalid': '新计划未保存：超过 ParkinSUM 安全预算、标识冲突或计划格式无效。',
    'reminders.error_schedule_identity_unverified':
        '本地计划已保存，但插件报告的待处理请求身份未能与计划一致核对；请重新提交后再依赖系统提醒。',
    'reminders.error_save_failed': '提醒未保存，请重试。',
    'reminders.explicit_medication_selection': '请明确选择实际服用的药物；打开此页面不代表已经服药。',
    'reminders.response_unavailable': '此提醒已失效或不属于当前账户，未创建任何记录。',
    'reminders.response_replayed': '已忽略重复的提醒操作，未创建任何记录。',
    'reminders.day_1': '周一',
    'reminders.day_2': '周二',
    'reminders.day_3': '周三',
    'reminders.day_4': '周四',
    'reminders.day_5': '周五',
    'reminders.day_6': '周六',
    'reminders.day_7': '周日',
    'common.completed': '完成时间',
    'common.error': '错误',
    'common.yes': '是',
    'common.no': '否',
    'common.search_results': '搜索结果',
    'common.no_matching_foods': '没有找到匹配的食物',
    'common.texture': '质地',
    'common.not_available': '未填写',
    'meal_slot.breakfast': '早餐',
    'meal_slot.lunch': '午餐',
    'meal_slot.dinner': '晚餐',
    'meal_slot.snack': '加餐',
    'entry.new_title': '新增餐次',
    'entry.edit_title': '编辑餐次',
    'entry.default_meal_title': '我的一餐',
    'entry.meal_title': '餐次标题',
    'entry.search_food': '搜索要添加的食物',
    'entry.view_food_detail': '查看食物详情',
    'entry.add_food': '添加食物',
    'entry.actual_meal_time': '实际进食时间',
    'entry.recorded_time_hint': '记录时间：{value}',
    'entry.actual_time_value': '发生时间：{value}',
    'entry.edit_actual_time': '编辑餐时',
    'entry.time_uncertain': '时间不确定',
    'entry.actual_window_value': '可能的进食时间窗：{start} - {end}',
    'entry.edit_actual_window': '编辑进食时间窗',
    'entry.next_meal_window': '预计下一餐时间窗',
    'entry.next_meal_window_empty': '尚未填写下一餐时间窗',
    'entry.next_meal_window_value': '下一餐时间窗：{start} - {end}',
    'entry.edit_next_meal_window': '编辑下一餐时间窗',
    'entry.clear_next_meal_window': '清除下一餐时间窗',
    'entry.supplement_context': '补充剂 / 共事件上下文',
    'entry.with_iron_supplement': '同餐服用铁剂',
    'entry.with_iron_multivitamin': '同餐服用含铁复合维生素',
    'entry.thickener_type': '增稠剂类型',
    'entry.thickener_starch_based': '淀粉型',
    'entry.thickener_xanthan_based': '黄原胶型',
    'entry.coevent_time_empty': '尚未填写共事件时间；默认按本餐发生时间计算。',
    'entry.coevent_time_value': '共事件时间：{value}',
    'entry.edit_coevent_time': '编辑共事件时间',
    'entry.enteral_feed_context': '肠内营养上下文',
    'entry.enteral_feed_continuous': '连续喂养',
    'entry.enteral_feed_bolus': '间断 / 推注',
    'entry.enteral_feed_formula': '肠内营养配方说明',
    'entry.enteral_feed_protein_g_per_day': '肠内营养蛋白（g/日）',
    'entry.none': '无',
    'entry.summary': '当前餐食摘要',
    'entry.no_foods_yet': '还没有添加食物',
    'entry.per_100g': '每 100g：蛋白 {protein}g · 碳水 {carbs}g',
    'entry.added_foods': '已添加食物',
    'entry.add_food_prompt': '请先从上方搜索结果中添加食物',
    'entry.grams': '克数',
    'entry.protein': '蛋白质',
    'entry.carbs': '碳水',
    'entry.quantity_factor': '份量系数：{value} × 100g',
    'entry.set_quantity': '设置份量',
    'entry.saving': '保存中...',
    'entry.save_new': '保存并运行冲突检查',
    'entry.save_edit': '保存修改并运行冲突检查',
    'entry.add_food_first': '请先至少添加一种食物',
    'entry.food_added': '已添加 {name}',
    'entry.saved_title': '餐次已保存并完成检查',
    'entry.updated_title': '餐次已更新并完成检查',
    'entry.save_failed': '保存失败：{error}',
    'entry.adjust_quantity': '调整份量 - {name}',
    'meal.title': '餐次',
    'meal.empty': '还没有记录餐次',
    'meal.check_title': '餐次检查 - {title}',
    'medications.title': '药品',
    'analytics.title': '分析',
    'analytics.localization': '本地化状态',
    'analytics.localization_language': '当前显示语言：{value}',
    'analytics.localization_region': '当前注册地区：{value}',
    'analytics.localization_timezone': '当前时区：{value}',
    'analytics.localization_override': '内容司法辖区覆盖：{value}',
    'analytics.localization_override_none': '未设置',
    'analytics.localization_texture_mode': '当前质地安全偏好：{value}',
    'analytics.localization_help':
        '如果你在注册页切换语言或地区，这里会显示当前生效设置；应用会按该 locale 重新构建后续页面。',
    'analytics.local_ai': '本地 AI',
    'analytics.local_ai_enable': '启用本地 AI 重排',
    'analytics.local_ai_help': 'AI 只会对已通过安全过滤的候选进行重排，可能被安全门自动禁用。',
    'analytics.local_ai_provider': '本地 AI provider',
    'analytics.local_ai_provider_auto': '自动（优先 Ollama）',
    'analytics.local_ai_provider_ollama': 'Ollama',
    'analytics.local_ai_provider_openai': 'llama.cpp / OpenAI 兼容',
    'analytics.local_ai_model': '模型名',
    'analytics.local_ai_medical_model': '医疗复核模型名',
    'analytics.local_ai_ollama_endpoint': 'Ollama endpoint',
    'analytics.local_ai_openai_endpoint': 'OpenAI 兼容 endpoint',
    'analytics.local_ai_timeout_ms': '超时（毫秒）',
    'analytics.local_ai_check': '检查本地 AI',
    'analytics.local_ai_status_available': '本地 AI 可用',
    'analytics.local_ai_status_unavailable': '本地 AI 不可用',
    'analytics.recommendation_path': '当前推荐路径',
    'analytics.recommendation_explanations': '当前推荐解释',
    'analytics.recommendation_gate_reasons': '当前安全门原因',
    'analytics.import_tools': 'P0 导入工具',
    'analytics.import_tools_help':
        '把本地磁盘上的官方 ZIP/XML 包导入 staging / promoted CDSS 快照。',
    'analytics.open_import_tools': '打开导入工具',
    'analytics.replay_benchmark': '推荐回放基准',
    'analytics.replay_benchmark_help':
        '运行 deterministic 与 AI rerank 的同场景回放，直接输出 gate 原因和排序差异报告。',
    'analytics.replay_run': '运行 replay benchmark',
    'analytics.replay_running': '正在运行 replay benchmark',
    'analytics.replay_last_report': '最近一次 replay 报告',
    'analytics.replay_cases': '场景数：{count}',
    'analytics.replay_report_error': 'Replay 运行失败：{error}',
    'analytics.protein_trend': '蛋白质趋势',
    'analytics.average_protein': '每餐平均蛋白质：{value} g',
    'analytics.no_trend': '暂无趋势数据',
    'import.title': '本地 P0 导入',
    'import.description': '请为每个官方来源填写 ZIP 文件路径或目录路径。Ciqual 可直接使用包含 XML 文件的目录。',
    'import.remote_tasks': '远程官方导入任务',
    'import.ema_medicines': 'EMA medicines 元数据',
    'import.ema_post_authorisation': 'EMA post-authorisation 元数据',
    'import.china_official_foods': '中国官方食品受控页面集',
    'import.run': '运行导入任务',
    'import.retry': '重试上次任务',
    'import.retry_source': '仅重试该来源',
    'import.last_result': '最近一次导入结果',
    'import.step_status_ok': '成功',
    'import.step_status_failed': '失败',
    'import.run_id': '运行 ID',
    'import.snapshot': '快照',
    'import.source_documents': '来源文档',
    'import.food_variants': '食物变体',
    'import.drug_variants': '药品变体',
    'import.observations': '观测值',
    'import.drilldown_runs': '运行记录',
    'import.drilldown_source_docs': '来源文档明细',
    'import.stage': '阶段',
    'import.status': '状态',
    'import.doc_type': '文档类型',
    'import.data_tier': '数据层级',
    'import.ingestion_strategy': '导入策略',
    'import.source_status': '来源状态',
    'import.origin_url': '来源链接',
    'import.ciqual_path': 'Ciqual XML 目录 / ZIP',
    'import.fdc_path': 'FDC ZIP / 目录',
    'import.dailymed_path': 'DailyMed ZIP / 目录',
    'import.dpd_path': 'Health Canada DPD ZIP / 目录',
    'import.running': '导入任务正在运行。大型 ZIP 包可能需要较长时间。',
    'import.ops_title': 'CDSS 发布与分发',
    'import.ops_help': '把 snapshot 发布到本地稳定通道、导出给后端接入，并在这里查看回滚与分发历史。',
    'import.snapshot_registry': '快照注册表',
    'import.snapshot_status_staging': 'staging',
    'import.snapshot_status_promoted': 'promoted',
    'import.fact_count': '解析事实数',
    'import.rules_version': '规则版本',
    'import.release_readiness': '发布就绪',
    'import.release_ready': '可发布',
    'import.release_blocked': '阻断',
    'import.label_sections': '标签正文段',
    'import.blocking_issues': '阻断问题',
    'import.warnings': '警告',
    'import.rollback_parent': '回滚来源',
    'import.publish': '发布',
    'import.export_bundle': '导出 bundle',
    'import.snapshot_bundle_path': 'snapshot bundle 路径',
    'import.import_bundle': '导入 bundle',
    'import.rollback': '回滚到此快照',
    'import.monitoring': '导入监控',
    'import.total_runs': '累计运行数',
    'import.distribution_history': '分发历史',
    'import.channel': '通道',
    'import.artifact_path': '产物路径',
    'catalog.title': '目录',
    'catalog.search': '搜索食物或药品',
    'catalog.foods': '食物',
    'catalog.drugs': '药品',
    'catalog.food_subtitle':
        '类别={category}  蛋白/碳水/脂肪={protein}/{carbs}/{fat}（每 100g）',
    'catalog.drug_subtitle': '标签={tags}',
    'catalog.view_detail': '查看详情',
    'settings.title': '设置与功能中心',
    'settings.profile': '注册资料与安全偏好',
    'settings.capabilities': '全部功能入口',
    'settings.queue': '完全体升级队列',
    'settings.queue_help': '此队列区分已交付、研究中及依赖外部验证的工作；不表示已完成面向患者的效度研究或取得监管许可。',
    'settings.saved': '资料已保存。',
    'settings.saved_refresh_pending': '资料已保存，但派生推荐刷新失败；请稍后重试。',
    'settings.save_failed': '保存失败，仍保留上一次成功保存的资料：{error}',
    'settings.account': '账户与数据边界',
    'settings.local_mode': '本地模式：数据保存在此设备的本地应用存储中。',
    'settings.open': '打开',
    'settings.reviewed': '研究复核日期：{date}',
    'settings.score': '优先级得分 {score}',
    'settings.email_verified': '邮箱已验证',
    'settings.email_unverified': '邮箱尚未验证',
    'settings.send_verification': '发送验证邮件',
    'settings.refresh_verification': '刷新验证状态',
    'settings.verification_sent': '验证邮件已发送，请在邮箱中完成验证。',
    'settings.verification_refreshed': '验证状态已刷新。',
    'settings.auth_action_failed': '账户操作失败：{error}',
    'settings.change_password': '修改密码',
    'settings.change_password_title': '重新验证并修改密码',
    'settings.current_password': '当前密码',
    'settings.new_password': '新密码',
    'settings.confirm_password': '再次输入新密码',
    'settings.password_requirement':
        '请使用至少 15 个字符的密码短语。可以使用空格和 Unicode 字符；无需刻意混合大小写、数字或符号。',
    'settings.password_current_required': '请输入当前密码。',
    'settings.password_too_short': '新密码至少需要 {minimum} 个字符。',
    'settings.password_must_differ': '新密码必须与当前密码不同。',
    'settings.password_confirmation_mismatch': '两次输入的新密码不一致。',
    'settings.show_passwords': '显示密码',
    'settings.hide_passwords': '隐藏密码',
    'settings.password_changed': '密码已更新。',
    'settings.password_error_wrong_current': '当前密码不正确，请重新输入。',
    'settings.password_error_weak': '身份服务未接受此新密码，请换用更长且不常见的密码短语。',
    'settings.password_error_too_many': '尝试次数过多，请稍后再试。',
    'settings.password_error_recent_login': '登录验证已过期，请重新登录后再试。',
    'settings.password_error_service': '账户服务暂时不可用，请稍后再试。',
    'settings.password_provider_unavailable': '此账户未连接密码登录，无法在这里修改密码。',
    'settings.password_error_not_signed_in': '当前未登录，请重新登录后再试。',
    'settings.password_error_unknown': '未能修改密码。密码未更改，请稍后再试。',
    'settings.data_integrity': '数据完整性',
    'settings.data_import': '数据导入',
    'common.previous': '上一页',
    'common.next': '下一页',
    'handoff.title': '个人日志交接摘要',
    'handoff.boundary_title': '由你选择和确认的个人日志副本',
    'handoff.boundary_body':
        '此摘要仅整理你记录的用药与进餐信息，未经临床核验，不是病历、诊断、治疗计划或建议。未知值不会被补成 0。',
    'handoff.raster_limit':
        'PDF 使用与本页相同的离线字体回退进行图像化渲染；内容与预览一致，但 PDF 文字目前不可搜索，也不是带标签的无障碍 PDF。',
    'handoff.configure': '选择范围、章节与脱敏级别',
    'handoff.start_date': '开始：{date}',
    'handoff.end_date': '结束：{date}',
    'handoff.redaction': '脱敏级别',
    'handoff.redaction.detailed': '详细（含来源代码与用户剂量说明）',
    'handoff.redaction.standard': '标准（结构化内容与来源）',
    'handoff.redaction.countsOnly': '仅计数与质量边界',
    'handoff.sections': '包含章节',
    'handoff.section.currentMedications': '当前用药选择',
    'handoff.section.historicalMedications': '本范围内仅历史引用的药物',
    'handoff.section.intakeLog': '服药记录',
    'handoff.section.mealLog': '进餐记录',
    'handoff.section.dataQualityAndProvenance': '缺失、单位与来源说明',
    'handoff.generate': '生成冻结预览',
    'handoff.exact_preview': '将要复制、打印或保存的精确页面',
    'handoff.preview_meta': '{pages} 页 · 内容 SHA-256 {digest}',
    'handoff.copy': '复制精确文本',
    'handoff.print': '打印',
    'handoff.save_share': '保存 / 分享 PDF',
    'handoff.delivery.copied': '已复制当前已验证摘要。',
    'handoff.delivery.print_requested': '打印流程已完成。',
    'handoff.delivery.save_share_requested': '系统保存 / 分享流程已完成。',
    'handoff.delivery.cancelled': '操作已取消；未宣称已保存或打印。',
    'handoff.error': '未生成或交付任何新摘要（{code}）。',
    'support.title': '隐私安全支持包',
    'support.boundary_title': '只包含你确认的技术信息',
    'support.boundary_body':
        '支持包使用固定字段白名单，只包含版本、平台能力、稳定检查代码和整数计数。不会包含健康记录、UID、邮箱、令牌、端点、文件路径、原始异常或日志。',
    'support.local_only': '默认仅在本机生成；不会自动上传、复制、保存或附加到消息。',
    'support.sections_title': '选择支持包章节',
    'support.sections_body': '生成后请检查精确 JSON，再决定是否复制或保存。取消选择的章节不会进入文件。',
    'support.section_build': '应用与算法构建身份',
    'support.section_platform': '平台能力声明',
    'support.section_diagnostics': '稳定诊断状态代码',
    'support.section_governance': '治理与目录计数',
    'support.generate': '生成并运行隐私检查',
    'support.preview_title': '将要复制或保存的精确支持包',
    'support.preview_meta': '{bytes} 字节 · 工件 SHA-256 {sha}…',
    'support.copy': '复制精确 JSON',
    'support.save': '保存 / 下载',
    'support.copied': '已复制当前已验证支持包。',
    'support.save_fallback_copied': '此平台无法安全创建新文件；已复制精确 JSON，未宣称文件已保存。',
    'support.download_requested': '浏览器下载请求已发出；请在浏览器中确认文件。',
    'support.existing_verified': '下载目录中已有字节完全一致的文件；未覆盖任何文件。',
    'support.error_scope': '账户状态正在变化，未生成或交付支持包。',
    'support.error_generation': '支持包未通过收集、预算或隐私检查，因此没有生成工件。',
    'support.error_source_changed': '诊断或构建状态已变化；旧预览已清除，请重新生成。',
    'support.error_copy': '未能安全复制支持包；没有自动重试或上传。',
    'support.error_save': '未能安全保存支持包；没有覆盖或删除现有文件。',
    'consent.title': '可选功能同意中心',
    'consent.local_ai_title': '本地 AI 重排与文案润色',
    'consent.local_ai_purpose':
        '可选地把已通过安全规则的候选标识和已生成文案发送到本机回环地址模型；模型不能改变用药、安全、评分、规则或证据结论。',
    'consent.status_granted': '当前告知版本已授权',
    'consent.status_denied': '未授权；不会发起新的本地 AI 请求',
    'consent.status_stale': '告知内容已变化，需要重新确认',
    'consent.status_blocked': '收据完整性异常；保持关闭，可通过撤回修复',
    'consent.notice_identity': '告知版本 {version} · SHA-256 {digest}…',
    'consent.legacy_requires_review': '旧版布尔开关不再视为可审计授权；请重新查看并明确选择。',
    'consent.grant': '同意当前用途',
    'consent.revoke': '撤回 / 保持关闭',
    'consent.saved': '同意选择及版本化收据已保存。',
    'consent.save_failed': '未能持久保存选择；本会话已停止本地 AI，请重试撤回。',
    'consent.history': '本账户的收据历史',
    'consent.history_empty': '尚无版本化收据。',
    'consent.event_granted': '已授予',
    'consent.event_revoked': '已撤回',
    'history.title': '可恢复记录历史',
    'history.subtitle': '进餐与服药的新增、编辑、删除和恢复会作为不可变修订与当前记录原子保存。',
    'history.conflict_help': '只有当前记录仍与该修订的结果完全一致时才能恢复；较新的修改绝不会被静默覆盖。',
    'history.filter_all': '全部',
    'history.meal': '进餐',
    'history.intake': '服药记录',
    'history.empty': '尚无可恢复修订。之后的新增、编辑和删除会显示在这里。',
    'history.event_create': '已新增',
    'history.event_update': '已编辑',
    'history.event_delete': '已删除',
    'history.event_restore': '已恢复',
    'history.restore': '恢复此前状态',
    'history.restore_unavailable': '已有更新，不能覆盖',
    'history.restored': '此前状态已作为新的修订恢复。',
    'history.restore_conflict': '当前记录已经变化；为保护新数据，没有执行恢复。',
    'history.restored_refresh_incomplete': '此前状态已持久恢复，但部分派生视图未能刷新；记录本身不会回滚。',
    'history.restore_blocked': '关系或完整性检查未通过，没有执行恢复。',
    'history.preview_title': '恢复影响预览',
    'history.preview_semantics': '恢复前的只读影响预览与确认',
    'history.preview_exact_write': '精确记录变更',
    'history.preview_target_restore': '把此记录恢复为所选修订之前的字节等价状态。',
    'history.preview_target_remove': '所选修订之前不存在此记录；确认后将删除当前记录。',
    'history.preview_relationships_title': '目录关系变化',
    'history.preview_relationships_body':
        '恢复后保留 {count} 个关系；新增 {added} 个，移除 {removed} 个。',
    'history.preview_derived_title': '派生结果重新生成',
    'history.preview_derived_body':
        '进餐检查、推荐解释、机制轨迹、交接摘要与可携带包关系将失效，并按当前算法重新计算；旧算法结果不会当作当前结果。',
    'history.preview_evidence_title': '历史证据保持不可变',
    'history.preview_evidence_body': '原修订不会被改写；本次恢复会追加为新的修订。',
    'history.preview_identity_title': '已绑定的计算身份',
    'history.preview_identity_body': '算法 {algorithm} · 关系图 {graph}',
    'history.preview_missing_title': '关系无法解析',
    'history.preview_missing_body': '当前目录缺少 {ids}。为避免不完整派生结果，恢复保持禁用。',
    'history.preview_status_ready': '检查通过，可以确认恢复。',
    'history.preview_status_stale': '记录已变化；请关闭并重新生成预览。',
    'history.preview_status_account': '账户状态不可用；恢复保持禁用。',
    'history.preview_status_relationships': '存在无法解析的目录关系；恢复保持禁用。',
    'history.preview_status_integrity': '预览完整性检查失败；恢复保持禁用。',
    'history.preview_cancel': '取消',
    'history.preview_confirm': '确认并恢复',
    'history.deleted_undo': '记录已删除。',
    'history.undo': '撤销',
    'portable.title': '我的可携带数据包',
    'portable.unencrypted_title': '这是未加密的敏感数据副本',
    'portable.unencrypted_body':
        '数据包可能包含进餐、用药、剂量说明和提醒文字。请只保存到你控制的位置；SHA-256 可以发现内容变化，但不能加密或隐藏内容。',
    'portable.boundary':
        '此功能只生成用户可读 JSON 和无写入导入预检，不会删除账户、恢复数据或证明法规合规。本地账户绑定使用保存在本设备的随机令牌，因此换设备后可能无法验证。',
    'portable.export_title': '生成当前数据快照',
    'portable.export_body':
        '导出当前已加载的资料、偏好、用药选择、服药、进餐、本设备提醒和关系链接。UID、邮箱、提醒激活令牌与本地 AI endpoint 不会写入；所有者绑定是带域分隔的单向假名绑定，不代表匿名。',
    'portable.generate': '生成并自检',
    'portable.integrity_ready': '完整性自检通过',
    'portable.file_count': '{count} 个结构化文件',
    'portable.byte_count': '{count} 字节',
    'portable.owner_protection': '本地能力保护  {protection}',
    'portable.owner_revision': '能力修订  {revision}',
    'portable.owner_migrated': '旧版本地令牌已验证迁移并清除',
    'portable.rotate_identity': '轮换本地导出身份',
    'portable.rotate_title': '轮换本地导出身份？',
    'portable.rotate_body':
        '这会生成新的设备绑定能力。此前生成的数据包将无法再通过此本地账户的所有者校验；此操作不会修改数据包内容，也无法撤销。',
    'portable.rotate_confirm': '轮换并清除当前数据包',
    'portable.rotate_success': '本地导出身份已轮换；当前数据包与预检状态已清除。',
    'portable.rotate_error': '无法安全轮换本地导出身份；现有身份保持不变。',
    'portable.copy': '复制 JSON',
    'portable.save': '保存数据包',
    'portable.copied': '数据包 JSON 已复制。请将其保存到受保护的位置。',
    'portable.preview_title': '导入预检（不会写入）',
    'portable.preview_body':
        '粘贴 ParkinSUM 数据包后检查格式、版本、账户绑定、校验和、记录数、冲突和不支持字段。当前版本不会执行导入。',
    'portable.package_json': '数据包 JSON',
    'portable.paste': '从剪贴板粘贴',
    'portable.use_generated': '使用刚生成的数据包',
    'portable.inspect': '运行无写入预检',
    'portable.status_ready': '可以进入未来的受控导入流程',
    'portable.status_wrongOwner': '账户或设备范围不匹配',
    'portable.status_unsupportedSchema': '数据包版本不受支持',
    'portable.status_corrupt': '数据包损坏或格式无效',
    'portable.preview_summary':
        '记录 {records} · 冲突 {conflicts} · 不支持字段 {unsupported}',
    'portable.unsupported_fields': '不支持字段',
    'portable.no_write': '预检保证：本次操作没有修改任何持久化数据。',
    'portable.error_scope': '当前账户或设备范围不可用。',
    'portable.error_account_changed': '操作期间账户已变化；已清除数据包、文本和预检结果。',
    'portable.error_generate': '无法生成数据包',
    'portable.error_copy': '无法复制数据包；没有文件被保存。',
    'portable.error_save': '无法保存数据包',
    'portable.error_empty': '请先粘贴或选择一个数据包。',
    'portable.error_input_too_large': '输入超过数据包大小上限，未载入或解析。',
    'portable.error_inspect': '无法安全预检该数据包。没有写入任何数据。',
    'portable.clipboard_empty': '剪贴板中没有可用文字。',
    'portable.save_unsupported': '此平台暂不支持直接保存；请使用“复制 JSON”。',
    'portable.save_fallback_copied': '此平台无法直接保存；JSON 已复制，但没有声称文件已保存。',
    'portable.save_failed_copied': '直接保存失败；JSON 已复制，但没有确认新文件已保存。',
    'portable.save_failed_residual_copied':
        '直接保存失败；JSON 已复制。清理临时文件无法确认，请检查“下载”目录。',
    'portable.error_save_residual': '保存和复制均失败；清理临时文件无法确认，请检查“下载”目录。',
    'portable.saved_visible': '数据包已保存到 {location}。',
    'portable.download_requested': '已向浏览器请求下载；请确认下载列表中出现该文件。',
    'portable.saved_app_documents':
        '数据包已保存到应用文档目录 {location}；如需外部副本，也可使用“复制 JSON”。',
    'portable.downloads': '浏览器下载',
    'privacy.title': '隐私与免责声明',
    'diagnostics.title': '工程自检',
    'diagnostics.rerun': '重新运行检查',
    'diagnostics.scope_title': '仅供工程审阅',
    'diagnostics.scope_body':
        '这些是确定性的治理检查（文案编译、本地化安全检查、合成场景回放）。它们只反映工程状态，不改变任何评分、严重度、证据或规则结果，也不是健康建议。数据均为合成/演示数据。',
    'diagnostics.elapsed': '本次检查耗时 {ms} 毫秒。',
    'catalog.selected_active': '已选为当前用药',
    'medications.view_detail': '查看药品详情',
    'detail.variant_source': '变体 / 来源',
    'detail.imported_nutrients': '已导入营养值',
    'detail.no_imported_nutrients': '未找到已导入的营养行。',
    'detail.product_code': '产品代码',
    'detail.packaging': '包装信息',
    'detail.imported_label_facts': '已导入标签事实',
    'detail.imported_label_sections': '已导入标签分段',
    'detail.no_imported_label_sections': '未找到已导入标签分段。',
    'detail.media_links': '媒体 / PDF 链接',
    'detail.macro_summary':
        '每 100g：蛋白 {protein} · 碳水 {carbs} · 脂肪 {fat} · 纤维 {fiber} · 钠 {sodium}',
    'detail.method_label': '方法',
    'detail.source_label': '来源',
    'interaction.low': '低风险',
    'interaction.moderate': '中风险',
    'interaction.high': '高风险',
    'interaction.score': '分数 {value}',
    'interaction.analysis_title': '分析',
    'interaction.key_findings': '关键判断',
    'interaction.next_actions': '下一步建议',
    'interaction.data_notes': '数据与边界说明',
    'interaction.missing_input': '缺少关键输入',
    'interaction.evidence_count': '证据 {count} 条',
    'interaction.evidence_pmid': 'PMID',
    'interaction.evidence_publication': '期刊/来源',
    'interaction.evidence_kind': '证据类型',
    'interaction.evidence_source_family': '来源家族',
    'interaction.evidence_doi': 'DOI',
    'interaction.evidence_link': '来源链接',
    'interaction.action_reschedule_full':
        '建议把用药与进餐错开：餐前 {before} 分钟、餐后 {after} 分钟再考虑进食。',
    'interaction.action_reschedule_before': '建议把用药提前至少 {before} 分钟后再进餐。',
    'interaction.action_reschedule_generic': '建议重新调整给药与进餐时序。',
    'interaction.action_separate_by_time': '建议至少错开 {minutes} 分钟。',
    'interaction.action_avoid_food': '建议避免当前高风险食物或食物组合。',
    'interaction.action_avoid_combination': '建议不要把当前药品与该组合共同使用。',
    'interaction.action_switch_thickener': '建议改用更合适的增稠剂或先做人工确认。',
    'interaction.action_manual_review': '当前最安全的下一步是人工复核。',
    'decision.block': '阻断',
    'decision.require_review': '需人工复核',
    'decision.discourage': '不建议',
    'decision.warn': '警示',
    'decision.info': '信息',
    'decision.allow': '允许',
    'decision.defer': '延后判断',
    'severity.low': '低',
    'severity.moderate': '中',
    'severity.high': '高',
    'severity.critical': '严重',
    'missing.dose': '剂量',
    'missing.formulation': '剂型',
    'missing.time': '用药时间',
    'missing.meal_time': '进食时间',
    'missing.coevent_time': '共事件时间',
    'missing.thickener_type': '增稠剂类型',
    'runtime.same_band_conflict': '同优先级规则给出了冲突决定，因此需要人工复核。',
    'runtime.no_rules': '没有命中已注册规则。',
    'runtime.validation_source': '运行时上下文校验',
    'mealcheck.no_active_drugs': '当前没有选择激活药品，因此未触发食药规则。',
    'mealcheck.no_conflict': '数据库变体解析已完成，未触发已注册的食药冲突规则。',
    'mealcheck.historical_no_current_risk':
        '这是一条约 {hours} 小时前的历史餐次，已超出当前食药冲突活跃窗口。',
    'mealcheck.historical_analysis':
        '引擎没有把这顿历史餐继续当作“当前正在消化的风险”。本餐距现在约 {hours} 小时，当前工程活跃窗口为 {window} 小时；因此不再因旧餐次生成当前高风险。',
    'mealcheck.historical_note': '历史餐次保护：超过 {window} 小时的非连续肠内营养餐次不会触发当前时序风险。',
    'mealcheck.summary': '数据库支持的食物与药品变体检查共发现 {count} 项提示。',
    'mealcheck.analysis':
        '引擎已将本餐与 {drugCount} 个激活药品进行检查。最高评估严重度为 {severity}，加权分数为 {score}/100。',
    'mealcheck.analysis_protein': '当前食物列表估算的本餐蛋白约为 {protein} g。',
    'mealcheck.analysis_highfat': '当前运行时启发式还将这顿饭判定为相对高脂/高热量。',
    'mealcheck.analysis_scoring': '本次分数由加权因素组成：{factors}。',
    'mealcheck.analysis_dbfacts':
        '当数据库中存在精确导入观测值时，引擎优先使用数据库真实营养值，而不是只依赖内置 seed。',
    'mealcheck.analysis_context_used': '本次判定还纳入了补充剂、增稠剂或肠内营养等额外上下文。',
    'mealcheck.analysis_evidence': '本次判定直接引用了官方标签或已注册证据来源。',
    'mealcheck.analysis_fallback':
        '部分食物变体通过区域 fallback 链解析，说明当前中国区域的权威覆盖仍未完全补齐。',
    'mealcheck.analysis_manual_review':
        '由于本次会话中仍缺少关键运行时输入，当前最安全的下一步是人工复核，而不是直接依赖时序建议。',
    'mealcheck.analysis_followup': '如果你想得到更具体的时序建议，请先补全药物时间和剂量后再运行检查。',
    'mealcheck.score_factor_rule_decision': '规则决定权重',
    'mealcheck.score_factor_levodopa_interference': '左旋多巴干扰权重',
    'mealcheck.score_factor_protein_timing': '蛋白时序惩罚',
    'mealcheck.score_factor_high_fat': '高脂餐修正',
    'mealcheck.score_factor_iron_levodopa': '铁剂-左旋多巴修正',
    'mealcheck.score_factor_enteral_feed': '连续肠内营养修正',
    'mealcheck.score_factor_evidence': '证据支持修正',
    'mealcheck.drug_fallback': ' 选中的药品变体来自司法辖区 fallback 链。',
    'mealcheck.food_fallback': ' 部分食物变体来自司法辖区 fallback 链。',
    'mealcheck.db_facts': ' 若可用，已优先使用数据库中的真实食物营养事实。',
    'mealcheck.official_source': '官方来源：{title}',
    'mealcheck.context_iron_supplement': '本餐记录了铁剂共事件。',
    'mealcheck.context_iron_multivitamin': '本餐记录了含铁复合维生素共事件。',
    'mealcheck.context_starch_thickener': '本餐记录了淀粉型增稠剂。',
    'mealcheck.context_xanthan_thickener': '本餐记录了黄原胶型增稠剂。',
    'mealcheck.context_enteral_feed_continuous':
        '本餐记录了连续肠内营养（蛋白 {protein} g/日）。',
    'mealcheck.context_enteral_feed_bolus': '本餐记录了间断/推注肠内营养。',
    'legacy.no_conflict': '基于内置规则未检测到显著冲突（仅供参考，不构成医疗建议）。',
    'legacy.high_protein_strong': '高蛋白时间窗可能强烈影响左旋多巴吸收',
    'legacy.high_protein': '蛋白质可能影响药物吸收',
    'legacy.tyramine': '可能存在高酪胺食物风险',
    'legacy.mineral': '矿物质补充剂与餐时提醒',
    'legacy.mineral_detail': '该餐包含乳制品，提示钙含量可能偏高。部分矿物质补充剂与食物同服时，吸收或胃肠耐受性可能发生变化。',
    'legacy.summary':
        '综合分数 {score}/100（{severity}），共发现 {count} 条可能与食物、药物或营养相关的提醒。',
    'legacy.severity.high': '高风险',
    'legacy.severity.moderate': '中风险',
    'legacy.severity.low': '低风险',
    'legacy.analysis_followup': '请将其视为轻量级筛查结果；如果需要更具体的建议，请确认精确用药时间。',
    'legacy.analysis_tyramine': '这顿饭还包含在内置目录中被标记为较高酪胺风险的食物。',
    'recommend.low_protein': '优先选择较低蛋白',
    'recommend.protein_window_caution': '左旋多巴时间窗附近需谨慎选择高蛋白食物',
    'recommend.history_low_protein': '结合近期记录，建议优先低蛋白选项',
    'recommend.culture_match': '符合当前地区饮食模板',
    'recommend.fallback_chain': '当前地区食物知识正在使用 fallback 链',
    'recommend.general_friendly': '整体上较适合的选择',
    'recommend.path.hybrid_local_ai': '本地 AI 辅助重排',
    'recommend.path.conservative_safety_gate': '保守路径（安全门阻断 AI）',
    'recommend.path.conservative_gate_block': '保守路径（本地 AI 不可用）',
    'recommend.path.fallback_invalid_ai': '保守路径（AI 输出未通过校验）',
    'recommend.path.conservative_cdss': '保守 CDSS 路径',
    'recommend.runtime.local_ai_endpoint_unavailable':
        '没有检测到 localhost 上可响应的 Ollama 或 llama.cpp 服务。请先启动本地模型服务，或关闭本地 AI 重排。',
    'recommend.runtime.endpoint_must_be_localhost':
        '本地 AI endpoint 必须是 localhost/127.0.0.1，不能指向外部云端。',
    'recommend.runtime.safety_gate_conservative': '安全门已将结果保持在保守推荐路径。',
    'recommend.runtime.next_meal_window_missing':
        '缺少下一餐预期时间窗。请在“添加一餐/编辑餐次”里填写下一餐最早和最晚时间。',
    'recommend.runtime.no_prior_meal_history': '没有可用于安全重排的上一餐记录。',
    'recommend.runtime.legacy_meal_time': '最近一餐仍使用旧迁移时间，建议编辑为真实进食时间。',
    'recommend.runtime.iron_conservative': '最近一餐记录了铁剂，因此保持保守重排。',
    'recommend.runtime.iron_multivitamin_conservative':
        '最近一餐记录了含铁复合维生素，因此保持保守重排。',
    'recommend.runtime.starch_thickener_conservative':
        '最近一餐记录了淀粉型增稠剂，因此保持确定性安全审核。',
    'recommend.runtime.enteral_conservative': '当前存在连续肠内营养背景，因此保持确定性审核。',
    'recommend.runtime.local_ai_not_consented': '用户尚未启用本地 AI 重排。',
    'recommend.runtime.local_ai_unavailable': '本地 AI endpoint 当前不可用。',
    'recommend.runtime.returned_conservative': '已返回确定性的保守推荐结果。',
    'recommend.runtime.ai_validation_failed': '本地 AI 的结构化输出未通过白名单校验。',
    'recommend.runtime.ai_invalid_whitelist': '本地 AI 没有返回有效的白名单候选排序，因此不能使用该结果。',
    'recommend.runtime.cdss_conservative_observations':
        '保守 CDSS 路径会在可用时使用真实变体观测值。',
    'recommend.runtime.local_ai_success': '本地 AI 重排已完成。',
    'recommend.runtime.local_ai_copy_polish_success': '本地 AI 已完成文案润色。',
    'recommend.runtime.medgemma_optional_unavailable':
        '本地 AI 可用；MedGemma 复核模型当前不可用，已按可选能力回退。',
    'recommend.runtime.recommendation_conservative': '推荐已保持在保守路径。',
    'recommend.runtime.levodopa_ai_sensitive': '左旋多巴相关时间窗过于敏感，因此不使用 AI 重排。',
    'copy.deterministic_path': '规则路径',
    'copy.rerank': '重新排序',
    'copy.cdss': '临床决策支持',
    'copy.official_label_meal_separation': '官方标签要求与进餐错开',
    'copy.database_food_variants': '数据库食物变体',
    'copy.database_nutrient_facts': '数据库营养事实',
    'copy.missing_input_unknown': '关键信息',
    'copy.interaction_summary_missing_inputs':
        '当前暂时标为高风险（{score}/100），主要原因是缺少{missing}，系统无法判断这顿饭和用药是否需要错开。',
    'copy.interaction_summary_high': '当前检查结果偏高风险（{score}/100），请先查看原因和下一步操作。',
    'copy.interaction_analysis_missing_inputs':
        '这不是在说这顿饭本身一定危险，而是因为缺少{missing}，无法安全计算食物与药物的时间关系。',
    'copy.interaction_analysis_protein':
        '本餐估算蛋白约 {protein} g，若正在使用左旋多巴，蛋白量会影响时序判断。',
    'copy.interaction_analysis_fallback': '部分食物使用了区域备用数据，说明本地权威数据仍有缺口。',
    'copy.interaction_analysis_database': '可用时已优先使用导入数据库中的营养事实。',
    'copy.interaction_analysis_not_diagnosis': '请把这个结果视为需要补全信息的安全提醒，不是诊断结论。',
    'copy.key_finding_missing_inputs': '无法完成时序判断：缺少{missing}。',
    'copy.next_action_complete_med_timing': '请先补充本次用药时间和剂量；补全后再重新运行检查。',
    'copy.data_note_fallback': '部分食物暂时使用备用地区数据，后续可用更本地的权威来源替换。',
    'copy.data_note_database': '本次已尽量使用数据库中的真实营养数据，而不是只用内置示例值。',
    'copy.data_note_missing_input': '缺少{missing}会让时序规则更保守。',
    'copy.issue_missing_inputs': '缺少{missing}，因此系统不能安全判断这顿饭与该药物是否需要错开。',
    'recommend.context_iron_supplement': '当前餐次同时记录了铁剂，推荐解释会保持更保守的时序语气。',
    'recommend.context_iron_multivitamin': '当前餐次同时记录了含铁复合维生素，推荐解释会保持更保守的时序语气。',
    'recommend.context_starch_thickener': '当前餐次记录了淀粉型增稠剂，这会抬高吞咽相关安全优先级。',
    'recommend.context_xanthan_thickener': '当前餐次记录了黄原胶型增稠剂。',
    'recommend.context_enteral_feed_continuous':
        '当前餐次处于连续肠内营养场景（蛋白 {protein} g/日），推荐会优先保守解释。',
    'recommend.context_enteral_feed_bolus': '当前餐次记录了间断/推注肠内营养。',
    'recommend.context_iron_penalty': '当前存在铁相关共事件，推荐排序会对较高蛋白候选保持更保守。',
    'recommend.context_enteral_penalty': '当前存在连续肠内营养背景，推荐排序会对较高蛋白候选保持更保守。',
    'recommend.context_texture_gap_penalty':
        '当前记录了增稠剂，但目录里仍缺少结构化质地匹配数据，因此保留额外保守边际。',
    'recommend.context_texture_supported': '当前记录了增稠剂，且该候选已有结构化质地信息，因此数据缺口惩罚较低。',
    'recommend.texture_profile_missing': '当前质地安全偏好已启用，但该候选缺少结构化质地信息，因此排序更保守。',
    'recommend.texture_profile_supported_soft_or_liquid':
        '该候选符合当前“软食或液体”质地安全偏好。',
    'recommend.texture_profile_supported_liquid_only': '该候选符合当前“仅液体”质地安全偏好。',
    'recommend.texture_profile_incompatible': '该候选与当前质地安全偏好不匹配，因此被保守降权。',
    'recommend.texture_template_supported': '该候选与当前餐次模板的质地方向一致。',
    'recommend.texture_template_mismatch': '该候选与当前餐次模板的质地方向不一致。',
    'recommend.local_seed_metadata': '该候选仍依赖本地种子元数据，缺少更完整的数据库观测支持。',
    'recommend.timing_window_incomplete': '时间窗信息不完整，因此排序会保留额外安全边际。',
    'recommend.next_meal_gap_close': '下一餐时间窗离上一餐较近，优先选择较低蛋白选项。',
    'recommend.next_meal_window_fiber': '符合计划中的下一餐时间窗，并有助于保持更平稳的纤维摄入。',
    'recommend.medication_timing_caution': '当前用药时间提示此下一餐时间窗需要额外谨慎。',
    'texture_mode.unrestricted': '不限制',
    'texture_mode.soft_or_liquid': '软食或液体',
    'texture_mode.liquid_only': '仅液体',
    'texture_class.liquid': '液体',
    'texture_class.soft': '软食',
    'texture_class.regular': '常规',
    'medication.drug_levodopa_carbidopa': '左旋多巴/卡比多巴',
    'medication.drug_entacapone': '恩他卡朋',
    'medication.drug_opicapone': '奥匹卡朋',
    'medication.drug_tolcapone': '托卡朋',
    'medication.drug_rasagiline': '雷沙吉兰',
    'medication.drug_safinamide': '沙芬酰胺',
    'medication.drug_selegiline': '司来吉兰',
    'medication.drug_iron': '铁剂补充剂',
    'medication.drug_pramipexole': '普拉克索',
    'medication.drug_ropinirole': '罗匹尼罗',
    'medication.drug_rotigotine': '罗替高汀',
    'medication.drug_apomorphine': '阿扑吗啡',
    'medication.drug_amantadine': '金刚烷胺',
    // 当前代码库尚未接入可公开核验的官方中文药品标准名源；
    // 对未稳定确认中文通用名的药物继续保留英文，避免盲猜。
    'medication.drug_istradefylline': 'Istradefylline',
    'medication.drug_pimavanserin': '匹莫范色林',
    'medication.drug_rivastigmine': '利斯的明',
    'medication.drug_droxidopa': '屈昔多巴',
    'medication.drug_midodrine': '米多君',
    'medication.drug_peg_3350': '聚乙二醇 3350',
    'medication.drug_levodopa_entacapone': '卡比多巴/左旋多巴/恩他卡朋',
    'medication.drug_levodopa_benserazide': '左旋多巴/苄丝肼',
    'medication_note.drug_levodopa_carbidopa':
        '帕金森病核心口服左旋多巴复方。高蛋白餐可能延迟或减弱反应，铁盐也可能降低生物利用度。',
    'medication_note.drug_entacapone': '外周 COMT 抑制剂，常与左旋多巴联用以减少疗效波动。',
    'medication_note.drug_tolcapone': 'COMT 抑制剂，使用时需要关注肝毒性监测，通常保留给特定患者。',
    'medication_note.drug_opicapone':
        '每日一次的 COMT 抑制剂，用于 OFF 发作患者的左旋多巴/卡比多巴辅助治疗。',
    'medication_note.drug_selegiline': '用于帕金森病的 MAO-B 抑制剂。高酪胺规则在此仍为基线占位实现。',
    'medication_note.drug_rasagiline':
        '选择性 MAO-B 抑制剂。酪胺摄入是该药物类别已记录的相互作用主题。饮食相关问题请咨询有资质的临床医生。',
    'medication_note.drug_safinamide':
        '与左旋多巴/卡比多巴联用的 MAO-B 抑制剂，主要用于伴 OFF 波动的患者。',
    'medication_note.drug_iron': '铁剂本身不是 PD 治疗药，但临床上重要，因为它可能与左旋多巴/卡比多巴螯合并降低吸收。',
    'medication_note.drug_pramipexole': '多巴胺受体激动剂，可用于单药或辅助治疗。',
    'medication_note.drug_ropinirole': '多巴胺受体激动剂，可用于早期或辅助治疗。',
    'medication_note.drug_rotigotine': '经皮多巴胺受体激动剂，适合口服时序或胃排空较难管理的场景。',
    'medication_note.drug_apomorphine': '速效多巴胺受体激动剂，按制剂不同可用于急救或进展期 OFF 管理。',
    'medication_note.drug_amantadine': '不同制剂下可用于帕金森症状或异动症管理。',
    'medication_note.drug_istradefylline':
        '腺苷 A2A 受体拮抗剂，用作左旋多巴/卡比多巴的辅助治疗以改善 OFF。',
    'medication_note.drug_pimavanserin': '5-HT2A 反向激动/拮抗药，用于帕金森病相关精神病。',
    'medication_note.drug_rivastigmine':
        '胆碱酯酶抑制剂，用于帕金森病痴呆。口服制剂常随餐以改善耐受性，贴剂则绕开胃肠道。',
    'medication_note.drug_droxidopa': '去甲肾上腺素前体，用于神经源性直立性低血压。',
    'medication_note.drug_midodrine': 'α1 激动剂，用于症状性直立性低血压。',
    'medication_note.drug_peg_3350': '渗透性泻剂，常用于 PD 相关便秘管理。',
    'medication_note.drug_levodopa_entacapone':
        '固定剂量复方，同时继承左旋多巴的餐时注意点与 COMT 辅助治疗背景。',
    'medication_note.drug_levodopa_benserazide': '美国以外常用的左旋多巴复方，对跨辖区 PD 管理很重要。',
    'medication_summary.drug_levodopa_carbidopa': '主要饮食相关关注点是蛋白时间窗和铁剂螯合。',
    'medication_summary.drug_entacapone': '通常与左旋多巴时序一起评估，而不是单独作为食物冲突药物。',
    'medication_summary.drug_tolcapone': '食物冲突不是首要问题，监测与左旋多巴联合治疗背景更重要。',
    'medication_summary.drug_opicapone': '通常按左旋多巴时序来解释，不是直接的食物阻断药物。',
    'medication_summary.drug_selegiline': '主要饮食注意点仍是极高酪胺食物，尤其在剂量或制剂变化时。',
    'medication_summary.drug_rasagiline': '应注意极高酪胺负荷，约 150 mg 及以上时更需谨慎。',
    'medication_summary.drug_safinamide': '酪胺摄入是该药物类别已记录的相互作用主题；请与有资质的临床医生讨论。',
    'medication_summary.drug_iron': '如有可能，应与含左旋多巴治疗错开。',
    'medication_summary.drug_pramipexole': '当前引擎中食物冲突较少，临床上更应关注嗜睡、冲动控制和体位性低血压。',
    'medication_summary.drug_ropinirole': '当前引擎没有针对其设置主要食物硬规则，更应关注耐受性和滴定背景。',
    'medication_summary.drug_rotigotine': '由于绕开胃肠道，食物时间的重要性较低。',
    'medication_summary.drug_apomorphine': '食物相互作用不是主要问题，给药途径和急救使用背景更关键。',
    'medication_summary.drug_amantadine': '当前引擎中的食物触发规则有限，肾功能和制剂背景更关键。',
    'medication_summary.drug_istradefylline':
        '当前引擎未设置专门的食物硬阻断，主要作为 OFF 辅助治疗数据存在。',
    'medication_summary.drug_pimavanserin': '当前引擎并不把它作为食物冲突重点药物，但它对 PD 照护高度相关。',
    'medication_summary.drug_rivastigmine': '口服制剂的餐时可能影响耐受性，而贴剂会改变胃肠道背景。',
    'medication_summary.drug_droxidopa': '与进食的“始终同状态”一致性在临床上可能重要。',
    'medication_summary.drug_midodrine': '当前引擎没有直接食物规则；白天给药与仰卧高血压背景更重要。',
    'medication_summary.drug_peg_3350': '当前硬规则主要聚焦于吞咽场景下与淀粉型增稠剂的不相容。',
    'medication_summary.drug_levodopa_entacapone': '应沿用其他含左旋多巴治疗的蛋白时间窗与铁剂错峰注意。',
    'medication_summary.drug_levodopa_benserazide': '应沿用其他含左旋多巴制剂的高蛋白与铁剂错峰注意。',
    'source_system.DAILYMED': 'DailyMed（美国结构化标签）',
    'source_system.HEALTH_CANADA_DPD': '加拿大 DPD',
    'source_system.FDA': '美国 FDA',
    'source_system.FDA/NLM': 'FDA/NLM',
    'source_system.CDSS': '本地 CDSS',
    'source_system.LOCAL_SEED': '本地种子数据',
    'route.oral': '口服',
    'route.transdermal': '透皮',
    'route.sublingual_or_subcutaneous': '舌下或皮下',
    'route.oral_or_transdermal': '口服或透皮',
    'dosage_form.tablet': '片剂',
    'dosage_form.capsule': '胶囊',
    'dosage_form.tablet_or_odt': '片剂或口崩片',
    'dosage_form.tablet_or_capsule': '片剂或胶囊',
    'dosage_form.capsule_or_tablet': '胶囊或片剂',
    'dosage_form.patch': '贴剂',
    'dosage_form.film_or_injection': '口膜或注射剂',
    'dosage_form.powder_for_solution': '冲调粉剂',
    'dosage_form.capsule_or_patch': '胶囊或贴剂',
    'release_type.immediate_release': '即释',
    'release_type.extended_release': '缓释',
    'release_type.immediate_or_extended_release': '即释或缓释',
    'release_type.immediate_or_continuous': '即释或持续释放',
    'release_type.continuous': '持续释放',
    'release_type.rescue': '急救用',
    'release_type.unspecified': '未注明',
  },
  'en': {
    'app.welcome': 'Welcome',
    'app.loading': 'Loading...',
    'onboarding.title': 'ParkinSUM Companion (Local Edition)',
    'onboarding.description':
        'This app is for meal logging and rule-based guidance only. It does not replace advice from your physician or pharmacist.',
    'onboarding.registration_region': 'Registration region',
    'onboarding.registration_region_help':
        'Determines the default jurisdiction chain and source priority.',
    'onboarding.display_language': 'Display language',
    'onboarding.display_language_help':
        'Controls app language, date, and number formatting.',
    'onboarding.diet_profile_region': 'Diet profile region',
    'onboarding.diet_profile_region_help':
        'Used for default meal templates without overriding safety rules.',
    'onboarding.swallowing_texture_mode': 'Swallowing / texture safety mode',
    'onboarding.swallowing_texture_mode_help':
        'Used as a conservative recommendation preference, not a clinical swallowing assessment.',
    'onboarding.content_override': 'Content jurisdiction override (optional)',
    'onboarding.content_override_help': 'Comma separated, e.g. US,CA',
    'onboarding.local_ai_consent': 'Enable local AI reranking (optional)',
    'onboarding.local_ai_consent_help':
        'Only uses localhost Ollama/llama.cpp and falls back to the conservative path when safety gates block it.',
    'onboarding.start': 'I understand, continue',
    'onboarding.appbar': 'Initial setup',
    'onboarding.step_safety': 'Safety boundary',
    'onboarding.step_safety_subtitle':
        'Confirm education-only use and account data scope',
    'onboarding.safety_education_title': 'Rule guidance is not medical advice',
    'onboarding.safety_education_body':
        'ParkinSUM gives conservative prompts from medication, meal, and regional rules. Medication changes, stopping therapy, or clinical diet decisions still need a physician or pharmacist.',
    'onboarding.account_scope_title': 'Account data stays user-scoped',
    'onboarding.account_scope_body':
        'After onboarding, profile, medications, intakes, and later audit records are saved under the current account user space.',
    'onboarding.step_profile': 'Region and language',
    'onboarding.step_profile_subtitle':
        'Set regulatory region, display language, and localization path',
    'onboarding.step_medications': 'Initial medications',
    'onboarding.step_medications_subtitle':
        'Choose medications used in meal-conflict checks',
    'onboarding.active_medications_help':
        'Select medications that should participate in meal-conflict checks. You can skip this and add them later from the medication page.',
    'onboarding.record_initial_intake': 'Record most recent intake',
    'onboarding.record_initial_intake_help':
        'If a dose was taken recently or today, its time lets next-meal recommendations consider the timing window immediately.',
    'onboarding.initial_intake_drug': 'Intake medication',
    'onboarding.initial_intake_drug_help':
        'Only medications selected above are listed.',
    'onboarding.initial_intake_time': 'Intake time',
    'onboarding.change_time': 'Change time',
    'onboarding.initial_intake_note': 'Dose note',
    'onboarding.initial_intake_note_help': 'For example 100/25 mg, or blank.',
    'onboarding.no_medications_available':
        'No medications are available in the catalog.',
    'onboarding.step_preferences': 'Diet and safety preferences',
    'onboarding.step_preferences_subtitle':
        'Set diet region, texture safety, and content overrides',
    'onboarding.step_review': 'Review and start',
    'onboarding.step_review_subtitle':
        'Save profile, medications, and first intake record',
    'onboarding.summary_region': 'Registration region',
    'onboarding.summary_language': 'Display language',
    'onboarding.summary_active_meds': 'Active medications',
    'onboarding.summary_initial_intake': 'Initial intake record',
    'onboarding.summary_texture': 'Texture preference',
    'onboarding.next': 'Next',
    'onboarding.back': 'Back',
    'onboarding.finish': 'Finish setup',
    'onboarding.finish_failed': 'Onboarding failed: {error}',
    'region.CN': 'China',
    'region.US': 'United States',
    'region.CA': 'Canada',
    'region.FR': 'France',
    'region.JP': 'Japan',
    'region.KR': 'South Korea',
    'region.IN': 'India',
    'region.ES': 'Spain',
    'region.MX': 'Mexico',
    'region.VN': 'Vietnam',
    'region.TH': 'Thailand',
    'region.ID': 'Indonesia',
    'region.RU': 'Russia',
    'region.PL': 'Poland',
    'region.SA': 'Saudi Arabia',
    'nav.home': 'Home',
    'nav.analytics': 'Analytics',
    'nav.meals': 'Meals',
    'nav.timeline': 'Timeline',
    'nav.meds': 'Medications',
    'nav.catalog': 'Catalog',
    'nav.next_meal': 'Next meal',
    'observatory.title': 'Algorithm Observatory',
    'observatory.boundary.title':
        '{count} algorithms · one auditable UI contract',
    'observatory.boundary.body':
        'Charts use production-model traces from a fixed, non-personal fixture. Curves are educational sensitivity signals—not a gastric-emptying test, absorbed dose, plasma concentration, predicted symptoms, or medical advice.',
    'observatory.scenario.title': 'Replay a sensitivity scenario',
    'observatory.scenario.mixed': 'Mixed reference',
    'observatory.scenario.high_fat_protein': 'High fat + protein',
    'observatory.scenario.missing': 'Missing data',
    'observatory.comparison.title': 'Scenario sensitivity comparison',
    'observatory.comparison.body':
        'All three fixed, non-personal scenarios run the same production models to show how input completeness and meal composition change modeled outputs. Differences are not patient predictions.',
    'observatory.comparison.semantics':
        'Model sensitivity comparison table for three fixed scenarios',
    'observatory.comparison.scenario': 'Scenario',
    'observatory.comparison.completeness': 'Completeness',
    'observatory.comparison.lag': 'Aggregate lag',
    'observatory.comparison.overlap': 'Conflict overlap',
    'observatory.comparison.bands': 'Severity / confidence',
    'observatory.coverage.title': 'Result-affecting algorithm coverage',
    'observatory.coverage.body':
        'Every algorithm that can change a classification, score, rank, gate, fallback, identity, or explanation has a visible representation below.',
    'observatory.atlas.count': 'Showing {visible} of {total} algorithms',
    'observatory.atlas.search': 'Search the algorithm atlas',
    'observatory.atlas.search_hint':
        'Name, input, output, impact, or source file',
    'observatory.atlas.clear': 'Clear filters',
    'observatory.atlas.clear_search': 'Clear algorithm search',
    'observatory.atlas.live_trace': 'Live trace only',
    'observatory.atlas.empty':
        'No algorithm matches the current search and filters.',
    'observatory.atlas.stage.normalize': 'Normalize',
    'observatory.atlas.stage.model': 'Model',
    'observatory.atlas.stage.decide': 'Decide',
    'observatory.atlas.stage.resolve': 'Resolve',
    'observatory.atlas.stage.explain': 'Explain',
    'observatory.gastric.title': '1 · Gastric emptying model',
    'observatory.absorption.title':
        '2 · Absorption opportunity + LNAA competition',
    'observatory.conflict.title': '3 · Conflict engine composition',
    'observatory.conflict.body':
        'MAX-overlap across doses preserves the most sensitive modeled event; confidence is reported separately from severity.',
    'observatory.tree.title': '4 · Expandable explanation tree',
    'observatory.candidate.title': '5 · Candidate scorer decomposition',
    'observatory.candidate.body':
        'Worst sampled overlap remains dominant; protein distribution and provenance can refine but cannot overpower it.',
    'observatory.parameters.title': '6 · Versioned parameter evidence',
    'observatory.oracle.title': '7 · Independent numerical truth gate',
    'observatory.oracle.body':
        'Separately authored analytic vectors are compared with production outputs; missing, extra, non-finite, or out-of-tolerance results fail closed.',
    'observatory.oracle.summary': '{passed} / {total} vectors passed',
    'observatory.oracle.algorithms_summary':
        '{verified} / {total} algorithms verified',
    'observatory.oracle.not_covered_count': '{count} algorithms not covered',
    'observatory.oracle.manifest': 'Truth manifest SHA-256: {digest}',
    'observatory.oracle.configuration':
        'Production configuration SHA-256: {digest}',
    'observatory.oracle.boundary':
        'This verifies independent implementation and calculation for fixed engineering vectors only—not biology, clinical accuracy, or a patient prediction.',
    'observatory.oracle.verified': 'Independent numerical vectors verified',
    'observatory.oracle.mismatch': 'Numerical vector mismatch',
    'observatory.oracle.not_covered': 'No independent numerical vector yet',
    'observatory.oracle.blocked': 'Numerical verification blocked',
    'observatory.ledger.title': '8 · Unit-aware immutable event ledger',
    'observatory.ledger.body':
        'Projects meals, doses, and context from the same production scenario into read-only events with original and canonical units, timezone offset, equal-time order, source, and revision identity.',
    'observatory.ledger.event_count': '{count} ordered events',
    'observatory.ledger.synthetic_count': '{count} synthetic events',
    'observatory.ledger.digest': 'Ledger SHA-256: {digest}',
    'observatory.ledger.replay_digest': 'Canonical replay SHA-256: {digest}',
    'observatory.ledger.configuration': 'Bound configuration SHA-256: {digest}',
    'observatory.minutes_after_meal': 'minutes after meal',
    'observatory.minutes_in_window': 'minutes across modeled window',
    'observatory.chart.data_table': 'View chart data table',
    'observatory.chart.data_table_help':
        'The same point-by-point values as the curve, available to keyboard and assistive technology users.',
    'observatory.chart.data_table_semantics':
        'Equivalent point-by-point data table for this chart',
    'observatory.chart.events': 'Events',
    'observatory.stage.normalize': '1 · Normalize and validate',
    'observatory.stage.model': '2 · Model mechanisms',
    'observatory.stage.decide': '3 · Decide, gate, and rank',
    'observatory.stage.resolve': '4 · Resolve identity and evidence',
    'observatory.stage.explain': '5 · Explain with provenance',
    'next_meal.title': 'Next-meal recommendation',
    'next_meal.subtitle':
        'Pick when you plan to eat next. The conservative rule path keeps the candidate order; the mechanistic model adds an educational timing-overlap trace and never reranks it. Local AI is a separate, optional safe-whitelist reranker.',
    'next_meal.input_time': 'Planned next-meal time',
    'next_meal.use_local_ai': 'Polish wording with local AI (optional)',
    'next_meal.use_local_ai_help':
        'Only calls localhost Ollama/llama.cpp to rerank and rewrite explanations for candidates the conflict engine already approved; falls back to the conservative path when the safety gate blocks it.',
    'next_meal.generate': 'Generate recommendation',
    'next_meal.window_title': 'Meal-time window you provide (minutes)',
    'next_meal.window_help':
        'You set the window. It enables an educational mechanistic trace; the model neither chooses your meal time nor changes the conservative recommendation order.',
    'next_meal.window_none': 'None',
    'next_meal.window_minutes': '{minutes} min',
    'next_meal.generating': 'Generating…',
    'next_meal.empty':
        'Set a planned time and tap "Generate recommendation"; the engine will re-evaluate against that window.',
    'next_meal.why_these': 'Why these picks',
    'next_meal.ai_polished': 'Polished by local AI',
    'next_meal.conservative_engine': 'Conflict-engine conservative path',
    'next_meal.recommendation_path': 'Recommendation path',
    'next_meal.gate_reasons': 'Safety-gate notes',
    'next_meal.candidates': 'Top candidates',
    'next_meal.no_candidates':
        'No suitable candidate under the current constraints. Adjust the planned time or expand the food catalog.',
    'next_meal.error': 'Generation failed',
    'dashboard.title': 'Dashboard',
    'dashboard.status': 'Overview',
    'dashboard.logged_meals': 'Logged meals: {count}',
    'dashboard.active_drugs': 'Active medications: {count}',
    'dashboard.logged_intakes': 'Medication intakes: {count}',
    'dashboard.recommendations': 'Recommendations',
    'dashboard.no_recommendations': 'No recommendations yet',
    'dashboard.recommendation_path': 'Recommendation path',
    'dashboard.recommendation_template':
        'Active template: {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'Local AI enhancement used',
    'dashboard.ai_not_used': 'Conservative path only',
    'dashboard.recommendation_why': 'Why these recommendations',
    'dashboard.recommendation_gate': 'AI / safety gate status',
    'dashboard.recommendation_macro_line':
        'Per 100g: P {protein} g · C {carbs} g · F {fat} g',
    'dashboard.recommendation_score_line':
        'Safety {safety} · Schedule {schedule} · Facts {facts} · Context penalty {context} · Window penalty {timing} · Swallowing penalty {swallowing} · Template match {template}',
    'dashboard.recent_meals': 'Recent meals (latest 5)',
    'dashboard.no_meals': 'No meals recorded yet',
    'dashboard.items': '{count} items',
    'dashboard.meal_context_iron_supplement': 'iron supplement coevent',
    'dashboard.meal_context_iron_multivitamin':
        'multivitamin-with-iron coevent',
    'dashboard.meal_context_starch_thickener': 'starch-based thickener',
    'dashboard.meal_context_xanthan_thickener': 'xanthan-based thickener',
    'dashboard.meal_context_enteral_feed_continuous':
        'continuous enteral feeding ({protein} g/day protein)',
    'dashboard.meal_context_enteral_feed_bolus':
        'bolus/intermittent enteral feeding',
    'dashboard.edit': 'Edit',
    'dashboard.delete': 'Delete',
    'dashboard.protein_trend': 'Protein trend',
    'dashboard.average_protein': 'Average protein: {value} g / meal',
    'dashboard.no_trend': 'No trend data yet',
    'dashboard.timeline': 'Timeline',
    'dashboard.no_timeline': 'No meals or medication events yet',
    'dashboard.add_meal': 'Add meal',
    'dashboard.meal_check': 'Meal check - {title}',
    'timeline.title': 'Meal and medication timeline',
    'timeline.empty': 'No meals or medication intakes yet',
    'timeline.add_meal': 'Add meal',
    'timeline.add_intake': 'Log medication',
    'timeline.new_intake': 'New medication intake',
    'timeline.edit_intake': 'Edit medication intake',
    'timeline.medication': 'Medication',
    'timeline.active_medication_option': '{name} (active)',
    'timeline.dosage_note': 'Dosage note',
    'timeline.taken_at': 'Taken at',
    'timeline.edit_taken_at': 'Edit taken time',
    'timeline.save_intake': 'Save intake',
    'timeline.no_medications': 'No medication catalog is available',
    'timeline.select_medication_first': 'Select a medication first',
    'timeline.save_intake_failed': 'Failed to save intake: {error}',
    'timeline.meal_macro_line':
        'Totals: protein {protein} g · carbs {carbs} g · fat {fat} g',
    'timeline.conflict_line': 'Conflict review: {severity} · score {score}',
    'timeline.meal_window_line': 'Meal window: {start} - {end}',
    'timeline.next_meal_window_line': 'Next meal window: {start} - {end}',
    'timeline.nearest_medication_line':
        'Nearest medication: {name} ({distance})',
    'timeline.nearest_meal_line': 'Nearest meal: {title} ({distance})',
    'timeline.dosage_line': 'Dose: {value}',
    'timeline.before': '{value} before',
    'timeline.after': '{value} after',
    'timeline.no_context_flags':
        'No supplement, thickener, or enteral feed flags',
    'common.close': 'Close',
    'common.done': 'Done',
    'common.cancel': 'Cancel',
    'common.apply': 'Apply',
    'common.optional': 'optional',
    'common.delete': 'Delete',
    'auth.account_title': 'ParkinSUM account',
    'auth.create_account': 'Create account',
    'auth.sign_in': 'Sign in',
    'auth.email': 'Email',
    'auth.password': 'Password',
    'auth.invalid_email': 'Enter a valid email.',
    'auth.password_required': 'Enter your password.',
    'auth.password_registration_requirement':
        'A new password needs at least {minimum} characters.',
    'auth.register': 'Register',
    'auth.have_account': 'Already have an account? Sign in',
    'auth.need_account': 'Need an account? Register',
    'auth.forgot_password': 'Forgot password?',
    'auth.privacy': 'Privacy & disclaimer',
    'auth.reset_neutral':
        'If an account matches that email, a password-reset message has been sent.',
    'auth.show_password': 'Show password',
    'auth.hide_password': 'Hide password',
    'reminders.title': 'Logging reminders',
    'reminders.add': 'Add reminder',
    'reminders.edit': 'Edit reminder',
    'reminders.resynchronize': 'Retry schedule request',
    'reminders.synchronized': 'Schedule request completed',
    'reminders.last_sync': 'Last request completed: {time}',
    'reminders.schedule_capacity_title': 'ParkinSUM scheduling safety budget',
    'reminders.schedule_capacity_body':
        'ParkinSUM-planned requests: {projected}/{limit}; app safety headroom: {headroom}. This is a conservative product limit, not the device\'s free system capacity. Each enabled weekday uses one request.',
    'reminders.schedule_capacity_invalid':
        'This plan cannot be submitted ({projected}/{limit}): the ParkinSUM safety budget, identity, or plan contract failed. The existing plan was not changed.',
    'reminders.identity_attestation_title':
        'Plugin-reported pending identity check',
    'reminders.identity_attestation_matched':
        'Plugin-reported pending identities match the plan ({installed}/{planned}). This is not an independent operating-system scheduler or visible-delivery verification.',
    'reminders.identity_attestation_drift':
        'Plugin-reported identities differ from the plan: {missing} missing, {extra} extra, and {replaced} replaced under a planned id. Do not rely on system reminders until reconciliation succeeds.',
    'reminders.identity_attestation_uninspectable':
        'Pending request identities could not be read from the plugin. The local plan remains authoritative, but system reminder state is unverified.',
    'reminders.delete_title': 'Delete this reminder?',
    'reminders.delete_body':
        '“{label}” will be removed from this device and its system reminder will be cancelled.',
    'reminders.boundary_title': 'Logging prompt only',
    'reminders.boundary_body':
        'You choose the time and wording. ParkinSUM does not calculate, recommend, or prescribe a dose time; follow your clinician and medicine label.',
    'reminders.web_title': 'Recurring system delivery is unavailable here',
    'reminders.web_body':
        'Your reminder plan remains saved on this device, but the Web, Windows, and Linux builds do not currently deliver recurring alerts while the app is closed.',
    'reminders.empty_title': 'No logging reminders yet',
    'reminders.empty_body':
        'Add your own prompt to log a meal or medication intake.',
    'reminders.kind': 'Log type',
    'reminders.kind_mealLog': 'Meal log',
    'reminders.kind_intakeLog': 'Medication intake log',
    'reminders.label': 'Reminder text',
    'reminders.label_help':
        'Write a logging prompt, not a dose or prescription instruction.',
    'reminders.privacy': 'Notification privacy',
    'reminders.privacy_help':
        'This controls only system-visible copy. Your reminder text stays inside ParkinSUM.',
    'reminders.privacy_minimal': 'Minimal (default)',
    'reminders.privacy_generic': 'Generic logging prompt',
    'reminders.privacy_preview': 'System notification preview',
    'reminders.privacy_minimal_boundary':
        'Android requests no notification content on a secure lock screen. Apple platforms still follow the user’s system preview setting.',
    'reminders.privacy_generic_boundary':
        'Android requests basic-only lock-screen visibility. Apple platforms still follow the user’s system preview setting.',
    'reminders.days': 'Repeat on',
    'reminders.next': 'Next',
    'reminders.validation': 'Enter reminder text and select at least one day.',
    'reminders.error_load_failed': 'Saved reminders could not be read.',
    'reminders.error_permission_denied':
        'Notification permission is off, so the reminder was not enabled.',
    'reminders.error_schedule_failed':
        'System reminder reconciliation failed. The existing local plan remains authoritative and will be retried on launch or resume.',
    'reminders.error_recovery_required':
        'The device reminder state could not be verified. The existing local plan remains authoritative; retry the schedule request and confirm it before relying on system reminders.',
    'reminders.error_schedule_invalid':
        'The new plan was not saved because its ParkinSUM safety budget, identity, or plan contract failed.',
    'reminders.error_schedule_identity_unverified':
        'The local plan was saved, but plugin-reported pending identities could not be matched to it. Reconcile again before relying on system reminders.',
    'reminders.error_save_failed': 'The reminder was not saved. Try again.',
    'reminders.explicit_medication_selection':
        'Select the medication actually taken. Opening this draft does not confirm an intake.',
    'reminders.response_unavailable':
        'This reminder is unavailable or does not belong to this account. No record was created.',
    'reminders.response_replayed':
        'A repeated reminder action was ignored. No record was created.',
    'reminders.day_1': 'Mon',
    'reminders.day_2': 'Tue',
    'reminders.day_3': 'Wed',
    'reminders.day_4': 'Thu',
    'reminders.day_5': 'Fri',
    'reminders.day_6': 'Sat',
    'reminders.day_7': 'Sun',
    'common.completed': 'Completed',
    'common.error': 'Error',
    'common.yes': 'Yes',
    'common.no': 'No',
    'common.search_results': 'Search results',
    'common.no_matching_foods': 'No matching foods found',
    'common.texture': 'Texture',
    'common.not_available': 'Not entered',
    'common.save': 'Save',
    'common.edit': 'Edit',
    'common.confirm': 'Confirm',
    'common.sign_out': 'Sign out',
    'meal_slot.breakfast': 'Breakfast',
    'meal_slot.lunch': 'Lunch',
    'meal_slot.dinner': 'Dinner',
    'meal_slot.snack': 'Snack',
    'entry.new_title': 'New meal entry',
    'entry.edit_title': 'Edit meal',
    'entry.default_meal_title': 'My Meal',
    'entry.meal_title': 'Meal title',
    'entry.search_food': 'Search foods to add',
    'entry.view_food_detail': 'View food details',
    'entry.add_food': 'Add food',
    'entry.actual_meal_time': 'Actual meal time',
    'entry.recorded_time_hint': 'Recorded time: {value}',
    'entry.actual_time_value': 'Occurred at: {value}',
    'entry.edit_actual_time': 'Edit meal time',
    'entry.time_uncertain': 'Time is approximate',
    'entry.actual_window_value': 'Possible meal window: {start} - {end}',
    'entry.edit_actual_window': 'Edit meal window',
    'entry.next_meal_window': 'Expected next-meal window',
    'entry.next_meal_window_empty': 'No next-meal window entered yet',
    'entry.next_meal_window_value': 'Next meal window: {start} - {end}',
    'entry.edit_next_meal_window': 'Edit next-meal window',
    'entry.clear_next_meal_window': 'Clear next-meal window',
    'entry.supplement_context': 'Supplement and coevent context',
    'entry.with_iron_supplement': 'Iron supplement taken with this meal',
    'entry.with_iron_multivitamin':
        'Multivitamin with iron taken with this meal',
    'entry.thickener_type': 'Thickener type',
    'entry.thickener_starch_based': 'Starch-based',
    'entry.thickener_xanthan_based': 'Xanthan-based',
    'entry.coevent_time_empty':
        'No coevent time entered yet; the meal time will be used by default.',
    'entry.coevent_time_value': 'Coevent time: {value}',
    'entry.edit_coevent_time': 'Edit coevent time',
    'entry.enteral_feed_context': 'Enteral feeding context',
    'entry.enteral_feed_continuous': 'Continuous',
    'entry.enteral_feed_bolus': 'Bolus / intermittent',
    'entry.enteral_feed_formula': 'Enteral formula note',
    'entry.enteral_feed_protein_g_per_day': 'Enteral feed protein (g/day)',
    'entry.none': 'None',
    'entry.summary': 'Current meal summary',
    'entry.no_foods_yet': 'No foods added yet',
    'entry.per_100g': 'Per 100g: P {protein}g - C {carbs}g',
    'entry.added_foods': 'Added foods',
    'entry.add_food_prompt': 'Add foods from the search results above first',
    'entry.grams': 'Grams',
    'entry.protein': 'Protein',
    'entry.carbs': 'Carbs',
    'entry.quantity_factor': 'Portion factor: {value} x 100g',
    'entry.set_quantity': 'Set portion',
    'entry.saving': 'Saving...',
    'entry.save_new': 'Save meal and run conflict check',
    'entry.save_edit': 'Save changes and run conflict check',
    'entry.add_food_first': 'Please add at least one food first',
    'entry.food_added': '{name} added',
    'entry.saved_title': 'Meal saved and checked',
    'entry.updated_title': 'Meal updated and checked',
    'entry.save_failed': 'Save failed: {error}',
    'entry.adjust_quantity': 'Adjust portion - {name}',
    'meal.title': 'Meals',
    'meal.empty': 'No meals recorded yet',
    'meal.check_title': 'Meal check - {title}',
    'medications.title': 'Medications',
    'analytics.title': 'Analytics',
    'analytics.localization': 'Localization status',
    'analytics.localization_language': 'Current display language: {value}',
    'analytics.localization_region': 'Current registration region: {value}',
    'analytics.localization_timezone': 'Current time zone: {value}',
    'analytics.localization_override': 'Content jurisdiction override: {value}',
    'analytics.localization_override_none': 'Not set',
    'analytics.localization_texture_mode':
        'Current texture safety mode: {value}',
    'analytics.localization_help':
        'When language or region changes during onboarding, the app rebuilds against the active locale and shows the effective setting here.',
    'analytics.local_ai': 'Local AI',
    'analytics.local_ai_enable': 'Enable local AI reranking',
    'analytics.local_ai_help':
        'AI only reranks already-safe candidates and may be disabled by safety gates.',
    'analytics.local_ai_provider': 'Local AI provider',
    'analytics.local_ai_provider_auto': 'Auto (prefer Ollama)',
    'analytics.local_ai_provider_ollama': 'Ollama',
    'analytics.local_ai_provider_openai': 'llama.cpp / OpenAI-compatible',
    'analytics.local_ai_model': 'Model name',
    'analytics.local_ai_medical_model': 'Medical review model name',
    'analytics.local_ai_ollama_endpoint': 'Ollama endpoint',
    'analytics.local_ai_openai_endpoint': 'OpenAI-compatible endpoint',
    'analytics.local_ai_timeout_ms': 'Timeout (ms)',
    'analytics.local_ai_check': 'Check local AI',
    'analytics.local_ai_status_available': 'Local AI available',
    'analytics.local_ai_status_unavailable': 'Local AI unavailable',
    'analytics.recommendation_path': 'Current recommendation path',
    'analytics.recommendation_explanations':
        'Current recommendation explanations',
    'analytics.recommendation_gate_reasons': 'Current safety gate reasons',
    'analytics.import_tools': 'P0 import tools',
    'analytics.import_tools_help':
        'Import official ZIP/XML packages from local disk into staging and promoted CDSS snapshots.',
    'analytics.open_import_tools': 'Open import tools',
    'analytics.replay_benchmark': 'Recommendation replay benchmark',
    'analytics.replay_benchmark_help':
        'Run the same scenarios through deterministic ranking and AI rerank, then show gate reasons and ranking diffs.',
    'analytics.replay_run': 'Run replay benchmark',
    'analytics.replay_running': 'Running replay benchmark',
    'analytics.replay_last_report': 'Latest replay report',
    'analytics.replay_cases': 'Cases: {count}',
    'analytics.replay_report_error': 'Replay run failed: {error}',
    'import.title': 'Local P0 Import',
    'import.description':
        'Paste a ZIP file path or a directory path for each official source. Ciqual can use a directory containing its XML files.',
    'import.remote_tasks': 'Remote official import tasks',
    'import.ema_medicines': 'EMA medicines metadata',
    'import.ema_post_authorisation': 'EMA post-authorisation metadata',
    'import.china_official_foods': 'China official food pages',
    'import.run': 'Run import task',
    'import.retry': 'Retry last task',
    'import.retry_source': 'Retry this source',
    'import.last_result': 'Last import result',
    'import.step_status_ok': 'OK',
    'import.step_status_failed': 'FAILED',
    'import.run_id': 'Run ID',
    'import.snapshot': 'Snapshot',
    'import.source_documents': 'Source documents',
    'import.food_variants': 'Food variants',
    'import.drug_variants': 'Drug variants',
    'import.observations': 'Observations',
    'import.drilldown_runs': 'Run drill-down',
    'import.drilldown_source_docs': 'Source document drill-down',
    'import.stage': 'Stage',
    'import.status': 'Status',
    'import.doc_type': 'Document type',
    'import.data_tier': 'Data tier',
    'import.ingestion_strategy': 'Ingestion strategy',
    'import.source_status': 'Source status',
    'import.origin_url': 'Origin URL',
    'import.ciqual_path': 'Ciqual XML directory / ZIP',
    'import.fdc_path': 'FDC ZIP / directory',
    'import.dailymed_path': 'DailyMed ZIP / directory',
    'import.dpd_path': 'Health Canada DPD ZIP / directory',
    'import.running':
        'Import task is running. This may take a while for large ZIP packages.',
    'import.ops_title': 'CDSS release and distribution',
    'import.ops_help':
        'Publish snapshots to the local stable channel, export backend-ready bundles, and inspect rollback / distribution history here.',
    'import.snapshot_registry': 'Snapshot registry',
    'import.snapshot_status_staging': 'staging',
    'import.snapshot_status_promoted': 'promoted',
    'import.fact_count': 'Resolved facts',
    'import.rules_version': 'Rules version',
    'import.release_readiness': 'Release readiness',
    'import.release_ready': 'Ready',
    'import.release_blocked': 'Blocked',
    'import.label_sections': 'Label sections',
    'import.blocking_issues': 'Blocking issues',
    'import.warnings': 'Warnings',
    'import.rollback_parent': 'Rollback parent',
    'import.publish': 'Publish',
    'import.export_bundle': 'Export bundle',
    'import.snapshot_bundle_path': 'Snapshot bundle path',
    'import.import_bundle': 'Import bundle',
    'import.rollback': 'Rollback to this snapshot',
    'import.monitoring': 'Import monitoring',
    'import.total_runs': 'Total runs',
    'import.distribution_history': 'Distribution history',
    'import.channel': 'Channel',
    'import.artifact_path': 'Artifact path',
    'analytics.protein_trend': 'Protein trend',
    'analytics.average_protein': 'Average protein per meal: {value} g',
    'analytics.no_trend': 'No trend data yet',
    'catalog.title': 'Catalog',
    'catalog.search': 'Search foods or medications',
    'catalog.foods': 'Foods',
    'catalog.drugs': 'Medications',
    'catalog.food_subtitle':
        'Category={category}  P/C/F={protein}/{carbs}/{fat} (per 100g)',
    'catalog.drug_subtitle': 'Tags={tags}',
    'catalog.view_detail': 'View details',
    'settings.title': 'Settings & capability center',
    'settings.profile': 'Registration profile & safety preferences',
    'settings.capabilities': 'All capability entry points',
    'settings.queue': 'Complete-app upgrade queue',
    'settings.queue_help':
        'This queue separates shipped engineering work from research and external validation. It does not imply clinical validation or regulatory clearance.',
    'settings.saved': 'Profile saved.',
    'settings.saved_refresh_pending':
        'Profile saved, but derived recommendations did not refresh. Retry later.',
    'settings.save_failed':
        'Save failed. The last successfully stored profile remains active: {error}',
    'settings.account': 'Account & data boundary',
    'settings.local_mode':
        'Local mode: data remains in this device’s local app storage.',
    'settings.open': 'Open',
    'settings.reviewed': 'Research reviewed {date}',
    'settings.score': 'Priority score {score}',
    'settings.email_verified': 'Email verified',
    'settings.email_unverified': 'Email not yet verified',
    'settings.send_verification': 'Send verification email',
    'settings.refresh_verification': 'Refresh verification status',
    'settings.verification_sent':
        'Verification email sent. Complete verification from your inbox.',
    'settings.verification_refreshed': 'Verification status refreshed.',
    'settings.auth_action_failed': 'Account action failed: {error}',
    'settings.change_password': 'Change password',
    'settings.change_password_title': 'Reauthenticate and change password',
    'settings.current_password': 'Current password',
    'settings.new_password': 'New password',
    'settings.confirm_password': 'Confirm new password',
    'settings.password_requirement':
        'Use a passphrase of at least 15 characters. Spaces and Unicode are welcome; no forced mix of capitals, numbers, or symbols.',
    'settings.password_current_required': 'Enter your current password.',
    'settings.password_too_short':
        'The new password needs at least {minimum} characters.',
    'settings.password_must_differ':
        'The new password must differ from the current password.',
    'settings.password_confirmation_mismatch':
        'The new password entries do not match.',
    'settings.show_passwords': 'Show passwords',
    'settings.hide_passwords': 'Hide passwords',
    'settings.password_changed': 'Password updated.',
    'settings.password_error_wrong_current':
        'The current password is incorrect. Try again.',
    'settings.password_error_weak':
        'The identity service did not accept this password. Use a longer, uncommon passphrase.',
    'settings.password_error_too_many':
        'Too many attempts. Wait before trying again.',
    'settings.password_error_recent_login':
        'Your sign-in proof expired. Sign in again, then retry.',
    'settings.password_error_service':
        'The account service is temporarily unavailable. Try again later.',
    'settings.password_provider_unavailable':
        'This account is not linked to password sign-in, so its password cannot be changed here.',
    'settings.password_error_not_signed_in':
        'You are signed out. Sign in again, then retry.',
    'settings.password_error_unknown':
        'The password could not be changed. Nothing was updated; try again later.',
    'settings.data_integrity': 'Data integrity',
    'settings.data_import': 'Data import',
    'common.previous': 'Previous page',
    'common.next': 'Next page',
    'handoff.title': 'Personal log handoff summary',
    'handoff.boundary_title': 'A personal-log copy you select and review',
    'handoff.boundary_body':
        'This summary only organizes medication and meal information you recorded. It is not clinically verified and is not a medical record, diagnosis, treatment plan, or recommendation. Unknown values are never filled with zero.',
    'handoff.raster_limit':
        'The PDF uses the same offline font fallback and rasterized pages shown here. Content matches the preview, but PDF text is not yet searchable and this is not a tagged accessible PDF.',
    'handoff.configure': 'Choose range, sections, and redaction',
    'handoff.start_date': 'Start: {date}',
    'handoff.end_date': 'End: {date}',
    'handoff.redaction': 'Redaction level',
    'handoff.redaction.detailed': 'Detailed (source codes and dose notes)',
    'handoff.redaction.standard': 'Standard (structured content and source)',
    'handoff.redaction.countsOnly': 'Counts and data-quality boundaries only',
    'handoff.sections': 'Include sections',
    'handoff.section.currentMedications': 'Current medication selections',
    'handoff.section.historicalMedications':
        'Historical-only medications in this range',
    'handoff.section.intakeLog': 'Medication intake log',
    'handoff.section.mealLog': 'Meal log',
    'handoff.section.dataQualityAndProvenance':
        'Missingness, units, and provenance',
    'handoff.generate': 'Generate frozen preview',
    'handoff.exact_preview': 'Exact pages to copy, print, or save',
    'handoff.preview_meta': '{pages} pages · content SHA-256 {digest}',
    'handoff.copy': 'Copy exact text',
    'handoff.print': 'Print',
    'handoff.save_share': 'Save / share PDF',
    'handoff.delivery.copied': 'The current verified summary was copied.',
    'handoff.delivery.print_requested': 'The print flow completed.',
    'handoff.delivery.save_share_requested':
        'The system save / share flow completed.',
    'handoff.delivery.cancelled':
        'The action was cancelled; no save or print is claimed.',
    'handoff.error': 'No new summary was generated or delivered ({code}).',
    'support.title': 'Privacy-safe support bundle',
    'support.boundary_title': 'Only technical information you review',
    'support.boundary_body':
        'The bundle uses a fixed field allowlist containing only versions, platform capabilities, stable check codes, and integer counts. It excludes health records, UID, email, tokens, endpoints, file paths, raw exceptions, and logs.',
    'support.local_only':
        'Generated locally by default. It is never uploaded, copied, saved, or attached automatically.',
    'support.sections_title': 'Choose support-bundle sections',
    'support.sections_body':
        'Review the exact JSON before deciding to copy or save it. Deselected sections are not materialized.',
    'support.section_build': 'App and algorithm build identity',
    'support.section_platform': 'Platform capability statements',
    'support.section_diagnostics': 'Stable diagnostic status codes',
    'support.section_governance': 'Governance and catalog counts',
    'support.generate': 'Generate and run privacy checks',
    'support.preview_title': 'Exact support bundle to copy or save',
    'support.preview_meta': '{bytes} bytes · artifact SHA-256 {sha}…',
    'support.copy': 'Copy exact JSON',
    'support.save': 'Save / download',
    'support.copied': 'The current verified support bundle was copied.',
    'support.save_fallback_copied':
        'This platform cannot safely create a new file. Exact JSON was copied; no saved file is claimed.',
    'support.download_requested':
        'A browser download was requested. Confirm the file in your browser.',
    'support.existing_verified':
        'A byte-identical file already exists in Downloads. No file was overwritten.',
    'support.error_scope':
        'Account state is changing. No support bundle was generated or delivered.',
    'support.error_generation':
        'Collection, budget, or privacy checks failed, so no artifact was created.',
    'support.error_source_changed':
        'Diagnostics or build state changed. The old preview was cleared; generate it again.',
    'support.error_copy':
        'The support bundle could not be copied safely. Nothing was uploaded or retried automatically.',
    'support.error_save':
        'The support bundle could not be saved safely. No existing file was overwritten or deleted.',
    'consent.title': 'Optional-feature consent center',
    'consent.local_ai_title': 'Local AI reranking and copy polish',
    'consent.local_ai_purpose':
        'Optionally sends identifiers from an already-safe candidate whitelist and already-produced copy to a loopback model. The model cannot change medication, safety, score, rule, or evidence decisions.',
    'consent.status_granted': 'Granted for the current notice version',
    'consent.status_denied':
        'Not granted; no new Local AI request will be started',
    'consent.status_stale': 'The notice changed and needs fresh confirmation',
    'consent.status_blocked':
        'Receipt integrity is blocked. The feature stays off; revoke to repair.',
    'consent.notice_identity': 'Notice version {version} · SHA-256 {digest}…',
    'consent.legacy_requires_review':
        'A legacy boolean switch is not treated as an auditable grant. Review and choose again.',
    'consent.grant': 'Grant this purpose',
    'consent.revoke': 'Withdraw / keep off',
    'consent.saved': 'The consent choice and versioned receipt were saved.',
    'consent.save_failed':
        'The choice could not be saved durably. Local AI is stopped for this session; retry withdrawal.',
    'consent.history': 'Receipt history for this account',
    'consent.history_empty': 'No versioned receipt has been recorded.',
    'consent.event_granted': 'Granted',
    'consent.event_revoked': 'Withdrawn',
    'history.title': 'Recoverable record history',
    'history.subtitle':
        'Meal and intake creates, edits, deletes, and restores are saved atomically with an immutable revision.',
    'history.conflict_help':
        'A revision can be restored only while the current record still exactly matches its result. Newer work is never overwritten silently.',
    'history.filter_all': 'All',
    'history.meal': 'Meal',
    'history.intake': 'Intake',
    'history.empty':
        'No recoverable revisions yet. Future creates, edits, and deletes will appear here.',
    'history.event_create': 'Created',
    'history.event_update': 'Edited',
    'history.event_delete': 'Deleted',
    'history.event_restore': 'Restored',
    'history.restore': 'Restore prior state',
    'history.restore_unavailable': 'Newer change; cannot overwrite',
    'history.restored': 'The prior state was restored as a new revision.',
    'history.restore_conflict':
        'The current record changed. Nothing was restored, protecting the newer data.',
    'history.restored_refresh_incomplete':
        'The prior state was restored durably, but some derived views did not refresh. The record was not rolled back.',
    'history.restore_blocked':
        'Relationship or integrity checks did not pass. Nothing was restored.',
    'history.preview_title': 'Restore impact preview',
    'history.preview_semantics':
        'Read-only restore impact preview and confirmation',
    'history.preview_exact_write': 'Exact record change',
    'history.preview_target_restore':
        'Restore this record to the byte-equivalent state before the selected revision.',
    'history.preview_target_remove':
        'The record did not exist before the selected revision. Confirmation removes the current record.',
    'history.preview_relationships_title': 'Catalog relationship changes',
    'history.preview_relationships_body':
        '{count} relationships remain after restore; {added} added and {removed} removed.',
    'history.preview_derived_title': 'Derived results will be regenerated',
    'history.preview_derived_body':
        'Meal checks, recommendation explanations, mechanistic traces, handoff summaries, and portable-package relationships are invalidated and recomputed under the current algorithms. Old algorithm output is never treated as current.',
    'history.preview_evidence_title': 'Historical evidence stays immutable',
    'history.preview_evidence_body':
        'The selected revision is never rewritten. This restore is appended as a new revision.',
    'history.preview_identity_title': 'Bound computation identity',
    'history.preview_identity_body':
        'Algorithm {algorithm} · relationship graph {graph}',
    'history.preview_missing_title': 'Unresolved relationship',
    'history.preview_missing_body':
        'The current catalog does not contain {ids}. Restore stays disabled to avoid incomplete derived results.',
    'history.preview_status_ready': 'Checks passed. Restore can be confirmed.',
    'history.preview_status_stale':
        'The record changed. Close this preview and generate a new one.',
    'history.preview_status_account':
        'The account scope is unavailable. Restore stays disabled.',
    'history.preview_status_relationships':
        'A catalog relationship is unresolved. Restore stays disabled.',
    'history.preview_status_integrity':
        'Preview integrity checks failed. Restore stays disabled.',
    'history.preview_cancel': 'Cancel',
    'history.preview_confirm': 'Confirm and restore',
    'history.deleted_undo': 'Record deleted.',
    'history.undo': 'Undo',
    'portable.title': 'My portable data package',
    'portable.unencrypted_title': 'This is an unencrypted sensitive-data copy',
    'portable.unencrypted_body':
        'The package may contain meals, medication logs, dose notes, and reminder text. Save it only somewhere you control. SHA-256 detects changes; it does not encrypt or hide the content.',
    'portable.boundary':
        'This feature creates user-readable JSON and a no-write import preview. It does not delete an account, restore data, or certify legal compliance. Local-account binding uses a random token kept on this device, so another device may not validate it.',
    'portable.export_title': 'Create a current data snapshot',
    'portable.export_body':
        'Exports the currently loaded profile, preferences, medication selections, intakes, meals, this-device reminders, and relationship links. UID, email, reminder activation tokens, and local-AI endpoints are excluded. The domain-separated one-way owner binding is pseudonymous, not anonymous.',
    'portable.generate': 'Generate and self-check',
    'portable.integrity_ready': 'Integrity self-check passed',
    'portable.file_count': '{count} structured files',
    'portable.byte_count': '{count} bytes',
    'portable.owner_protection': 'Local capability protection  {protection}',
    'portable.owner_revision': 'Capability revision  {revision}',
    'portable.owner_migrated':
        'Legacy local token was verified, migrated, and removed',
    'portable.rotate_identity': 'Rotate local export identity',
    'portable.rotate_title': 'Rotate local export identity?',
    'portable.rotate_body':
        'This creates a new device-bound capability. Packages generated earlier will no longer pass owner validation for this local account. It does not change package contents and cannot be undone.',
    'portable.rotate_confirm': 'Rotate and clear current package',
    'portable.rotate_success':
        'Local export identity rotated. The current package and preview were cleared.',
    'portable.rotate_error':
        'The local export identity could not be rotated safely. The existing identity remains in use.',
    'portable.copy': 'Copy JSON',
    'portable.save': 'Save package',
    'portable.copied': 'Package JSON copied. Store it in a protected location.',
    'portable.preview_title': 'Import preview (no writes)',
    'portable.preview_body':
        'Paste a ParkinSUM package to check format, version, owner binding, checksums, counts, conflicts, and unsupported fields. This version does not perform an import.',
    'portable.package_json': 'Package JSON',
    'portable.paste': 'Paste from clipboard',
    'portable.use_generated': 'Use generated package',
    'portable.inspect': 'Run no-write preview',
    'portable.status_ready': 'Ready for a future controlled import flow',
    'portable.status_wrongOwner': 'Account or device scope does not match',
    'portable.status_unsupportedSchema': 'Package schema is unsupported',
    'portable.status_corrupt': 'Package is corrupt or invalid',
    'portable.preview_summary':
        '{records} records · {conflicts} conflicts · {unsupported} unsupported fields',
    'portable.unsupported_fields': 'Unsupported fields',
    'portable.no_write':
        'Preview guarantee: this operation changed no durable data.',
    'portable.error_scope':
        'The current account or device scope is unavailable.',
    'portable.error_account_changed':
        'The account changed during the operation. Package, text, and preview were cleared.',
    'portable.error_generate': 'Could not generate package',
    'portable.error_copy': 'Could not copy the package. No file was saved.',
    'portable.error_save': 'Could not save package',
    'portable.error_empty': 'Paste or select a package first.',
    'portable.error_input_too_large':
        'The input exceeds the package-size limit and was not loaded or parsed.',
    'portable.error_inspect':
        'The package could not be inspected safely. No data was written.',
    'portable.clipboard_empty': 'The clipboard has no usable text.',
    'portable.save_unsupported':
        'Direct save is unavailable on this platform. Use Copy JSON instead.',
    'portable.save_fallback_copied':
        'Direct save is unavailable. JSON was copied; no file is claimed as saved.',
    'portable.save_failed_copied':
        'Direct save failed. JSON was copied; no new file was confirmed saved.',
    'portable.save_failed_residual_copied':
        'Direct save failed and JSON was copied. Temporary-file cleanup could not be confirmed; check Downloads.',
    'portable.error_save_residual':
        'Save and copy both failed. Temporary-file cleanup could not be confirmed; check Downloads.',
    'portable.saved_visible': 'Package saved to {location}.',
    'portable.download_requested':
        'A browser download was requested. Confirm that the file appears in your downloads.',
    'portable.saved_app_documents':
        'Package saved in app documents at {location}. Use Copy JSON if you also need an external copy.',
    'portable.downloads': 'browser downloads',
    'privacy.title': 'Privacy & disclaimer',
    'diagnostics.title': 'Engineering diagnostics',
    'diagnostics.rerun': 'Re-run checks',
    'diagnostics.scope_title': 'Engineering review only',
    'diagnostics.scope_body':
        'These are deterministic governance checks (copy compilation, localization safety lint, synthetic scenario replay). They report engineering status only: they change no score, severity, evidence, or rule outcome, and they are not health guidance. Synthetic/demo data only.',
    'diagnostics.elapsed': 'Checks completed in {ms} ms.',
    'catalog.selected_active': 'Selected as active medication',
    'medications.view_detail': 'View medication details',
    'detail.variant_source': 'Variant / source',
    'detail.imported_nutrients': 'Imported nutrients',
    'detail.no_imported_nutrients': 'No imported nutrient lines found.',
    'detail.product_code': 'Product code',
    'detail.packaging': 'Packaging',
    'detail.imported_label_facts': 'Imported label facts',
    'detail.imported_label_sections': 'Imported label sections',
    'detail.no_imported_label_sections': 'No imported label sections found.',
    'detail.media_links': 'Media / PDF links',
    'detail.macro_summary':
        'Per 100g: P {protein} · C {carbs} · F {fat} · Fiber {fiber} · Na {sodium}',
    'detail.method_label': 'Method',
    'detail.source_label': 'Source',
    'interaction.low': 'Low risk',
    'interaction.moderate': 'Moderate risk',
    'interaction.high': 'High risk',
    'interaction.score': 'Score {value}',
    'interaction.analysis_title': 'Analysis',
    'interaction.key_findings': 'Key findings',
    'interaction.next_actions': 'Next actions',
    'interaction.data_notes': 'Data notes and boundaries',
    'interaction.missing_input': 'Missing critical input',
    'interaction.evidence_count': 'Evidence ({count})',
    'interaction.evidence_pmid': 'PMID',
    'interaction.evidence_publication': 'Publication',
    'interaction.evidence_kind': 'Evidence type',
    'interaction.evidence_source_family': 'Source family',
    'interaction.evidence_doi': 'DOI',
    'interaction.evidence_link': 'Source link',
    'interaction.action_reschedule_full':
        'Consider separating medication and meals by about {before} minutes before meals and {after} minutes after meals.',
    'interaction.action_reschedule_before':
        'Consider moving medication at least {before} minutes before eating.',
    'interaction.action_reschedule_generic':
        'Consider adjusting medication and meal timing.',
    'interaction.action_separate_by_time':
        'Consider separating the two events by at least {minutes} minutes.',
    'interaction.action_avoid_food':
        'Consider avoiding the current high-risk food or food combination.',
    'interaction.action_avoid_combination':
        'Consider avoiding this medication-food combination.',
    'interaction.action_switch_thickener':
        'Consider switching to a safer thickener or confirming manually first.',
    'interaction.action_manual_review':
        'The safest next step is manual review.',
    'decision.block': 'Block',
    'decision.require_review': 'Require review',
    'decision.discourage': 'Discourage',
    'decision.warn': 'Warn',
    'decision.info': 'Info',
    'decision.allow': 'Allow',
    'decision.defer': 'Defer',
    'severity.low': 'Low',
    'severity.moderate': 'Moderate',
    'severity.high': 'High',
    'severity.critical': 'Critical',
    'missing.dose': 'dose',
    'missing.formulation': 'formulation',
    'missing.time': 'medication time',
    'missing.meal_time': 'meal time',
    'missing.coevent_time': 'co-event time',
    'missing.thickener_type': 'thickener type',
    'runtime.same_band_conflict':
        'Rules with the same priority produced conflicting decisions, so manual review is required.',
    'runtime.missing_fields':
        'Missing critical inputs: {fields}. Manual review is required.',
    'runtime.no_rules': 'No registered rules were triggered.',
    'runtime.validation_source': 'runtime context validation',
    'mealcheck.no_active_drugs':
        'No active medications are selected, so no food-drug rules were triggered.',
    'mealcheck.no_conflict':
        'Database-backed variant resolution completed. No registered food-drug conflict rules were triggered.',
    'mealcheck.historical_no_current_risk':
        'This meal is about {hours} hours old and is outside the current food-drug conflict activity window.',
    'mealcheck.historical_analysis':
        'The engine did not treat this historical meal as an active current digestion risk. The meal is about {hours} hours old, while the current operational activity window is {window} hours, so it no longer produces a current high-risk alert.',
    'mealcheck.historical_note':
        'Historical-meal guard: non-continuous-enteral meals older than {window} hours do not trigger current timing risk.',
    'mealcheck.summary':
        'Database-backed food and drug variant checks found {count} advisory items.',
    'mealcheck.analysis':
        'The engine checked this meal against {drugCount} active medication(s). The highest evaluated severity was {severity}, with a score of {score}/100.',
    'mealcheck.analysis_protein':
        'Estimated meal protein from the current item list was about {protein} g.',
    'mealcheck.analysis_highfat':
        'The current operational heuristic also flagged this meal as relatively high fat/high calorie.',
    'mealcheck.analysis_scoring':
        'The score is weighted from these factors: {factors}.',
    'mealcheck.analysis_dbfacts':
        'When exact imported observations were available, the engine used database nutrient facts instead of only in-app seed values.',
    'mealcheck.analysis_context_used':
        'This decision also used extra context such as supplements, thickener type, or enteral feeding.',
    'mealcheck.analysis_evidence':
        'This decision directly cited an official label or a registered evidence source.',
    'mealcheck.analysis_fallback':
        'Some food variants were resolved through a regional fallback chain, so local authoritative coverage is still incomplete for part of this check.',
    'mealcheck.analysis_manual_review':
        'Because key runtime inputs are still incomplete in this session, the safest next step is manual review before relying on timing guidance.',
    'mealcheck.analysis_followup':
        'If you want a more specific timing recommendation, complete the medication time and dose fields before running the check again.',
    'mealcheck.score_factor_rule_decision': 'Rule decision weight',
    'mealcheck.score_factor_levodopa_interference':
        'Levodopa interference weight',
    'mealcheck.score_factor_protein_timing': 'Protein timing penalty',
    'mealcheck.score_factor_high_fat': 'High-fat meal modifier',
    'mealcheck.score_factor_iron_levodopa': 'Iron-levodopa modifier',
    'mealcheck.score_factor_enteral_feed': 'Continuous enteral feed modifier',
    'mealcheck.score_factor_evidence': 'Evidence support modifier',
    'mealcheck.drug_fallback':
        ' The selected drug variant came from a jurisdiction fallback chain.',
    'mealcheck.food_fallback':
        ' Some food variants came from a jurisdiction fallback chain.',
    'mealcheck.db_facts':
        ' Real nutrient facts from database food variants were used when available.',
    'mealcheck.official_source': 'Official source: {title}',
    'mealcheck.context_iron_supplement':
        'This meal included an iron-supplement coevent.',
    'mealcheck.context_iron_multivitamin':
        'This meal included a multivitamin-with-iron coevent.',
    'mealcheck.context_starch_thickener':
        'This meal included a starch-based thickener.',
    'mealcheck.context_xanthan_thickener':
        'This meal included a xanthan-based thickener.',
    'mealcheck.context_enteral_feed_continuous':
        'This meal included continuous enteral feeding ({protein} g/day protein).',
    'mealcheck.context_enteral_feed_bolus':
        'This meal included bolus/intermittent enteral feeding.',
    'legacy.no_conflict':
        'No significant rule conflicts were detected (based only on built-in rules; not medical advice).',
    'legacy.high_protein_strong':
        'High protein timing may strongly affect levodopa absorption',
    'legacy.high_protein_strong_detail':
        'This meal contains about {protein} g of protein, which is in a higher-risk range. Taking it close to {drug} may compete more strongly for absorption.',
    'legacy.high_protein': 'Protein may affect medication absorption',
    'legacy.high_protein_detail':
        'This meal contains about {protein} g of protein and may compete with {drug} during absorption. Consider scheduling higher-protein meals away from dosing time.',
    'legacy.tyramine': 'Possible high-tyramine food risk',
    'legacy.tyramine_detail':
        'This meal includes foods marked as high tyramine. Combined with {drug}, it may increase adverse-effect risk.',
    'legacy.mineral': 'Meal timing note for mineral supplements',
    'legacy.mineral_detail':
        'This meal includes dairy and may suggest higher calcium content. Some mineral supplements can have different absorption or GI tolerance when taken with food.',
    'legacy.summary':
        'Overall score {score}/100 ({severity}), with {count} possible food-drug or nutrition-related alerts.',
    'legacy.analysis':
        'Built-in rules checked this meal against {drugCount} medication(s), producing a heuristic screening score of {score}/100.',
    'legacy.analysis_protein':
        'The current meal estimate contains about {protein} g of protein.',
    'legacy.analysis_tyramine':
        'This meal also contains foods tagged as higher tyramine risk in the built-in catalog.',
    'legacy.analysis_followup':
        'Treat this as a lightweight screening result and confirm exact medication timing when you need more specific guidance.',
    'legacy.severity.high': 'High risk',
    'legacy.severity.moderate': 'Moderate risk',
    'legacy.severity.low': 'Low risk',
    'recommend.low_protein': 'Lower protein preferred',
    'recommend.protein_window_caution':
        'Use caution with higher protein near the levodopa window',
    'recommend.history_low_protein':
        'Recent history suggests prioritizing lower-protein options',
    'recommend.culture_match': 'Matches the current regional diet template',
    'recommend.fallback_chain':
        'Food knowledge for this region is using a fallback chain',
    'recommend.general_friendly': 'Generally suitable option',
    'recommend.path.hybrid_local_ai': 'Local AI assisted rerank',
    'recommend.path.conservative_safety_gate':
        'Conservative path (AI blocked by safety gate)',
    'recommend.path.conservative_gate_block':
        'Conservative path (local AI unavailable)',
    'recommend.path.fallback_invalid_ai':
        'Conservative path (AI output failed validation)',
    'recommend.path.conservative_cdss': 'Conservative CDSS path',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'No localhost Ollama or llama.cpp service responded. Start the local model service, or disable local AI reranking.',
    'recommend.runtime.endpoint_must_be_localhost':
        'The local AI endpoint must stay on localhost/127.0.0.1 and cannot point to a cloud endpoint.',
    'recommend.runtime.safety_gate_conservative':
        'The safety gate kept the result on the conservative path.',
    'recommend.runtime.next_meal_window_missing':
        'The expected next-meal time window is missing. Add the earliest and latest next-meal time in Add/Edit Meal.',
    'recommend.runtime.no_prior_meal_history':
        'No prior meal history is available for safe reranking.',
    'recommend.runtime.legacy_meal_time':
        'The latest meal still uses migrated legacy timing; edit it to the real eating time.',
    'recommend.runtime.iron_conservative':
        'The latest meal recorded an iron supplement, so reranking stays conservative.',
    'recommend.runtime.iron_multivitamin_conservative':
        'The latest meal recorded a multivitamin with iron, so reranking stays conservative.',
    'recommend.runtime.starch_thickener_conservative':
        'The latest meal recorded a starch-based thickener, so deterministic safety review is kept.',
    'recommend.runtime.enteral_conservative':
        'Continuous enteral feeding context is active, so deterministic review is kept.',
    'recommend.runtime.local_ai_not_consented':
        'Local AI reranking has not been enabled by the user.',
    'recommend.runtime.local_ai_unavailable':
        'The local AI endpoint is currently unavailable.',
    'recommend.runtime.returned_conservative':
        'Returned deterministic conservative recommendations instead.',
    'recommend.runtime.ai_validation_failed':
        'The local AI structured output failed whitelist validation.',
    'recommend.runtime.ai_invalid_whitelist':
        'Local AI did not return a valid whitelist-only ordering, so the result was not used.',
    'recommend.runtime.cdss_conservative_observations':
        'The conservative CDSS path used real variant observations when available.',
    'recommend.runtime.local_ai_success': 'Local AI reranking succeeded.',
    'recommend.runtime.local_ai_copy_polish_success':
        'Local AI copy polish succeeded.',
    'recommend.runtime.medgemma_optional_unavailable':
        'Local AI is available; the optional MedGemma review model is unavailable, so the app fell back safely.',
    'recommend.runtime.recommendation_conservative':
        'Recommendation stayed on the conservative path.',
    'recommend.runtime.levodopa_ai_sensitive':
        'The levodopa timing window is too sensitive for AI reranking.',
    'copy.deterministic_path': 'rule-based path',
    'copy.rerank': 'rerank',
    'copy.cdss': 'clinical decision support',
    'copy.official_label_meal_separation':
        'the official label requires separation from meals',
    'copy.database_food_variants': 'database food variants',
    'copy.database_nutrient_facts': 'database nutrient facts',
    'copy.missing_input_unknown': 'key information',
    'copy.interaction_summary_missing_inputs':
        'This is temporarily marked high risk ({score}/100) because required medication information is missing: {missing}. The app cannot judge meal-medication timing safely until this is completed.',
    'copy.interaction_summary_high':
        'This check is currently high risk ({score}/100). Review the reason and next step before relying on timing guidance.',
    'copy.interaction_analysis_missing_inputs':
        'This does not mean the meal itself is definitely dangerous. It means required medication information is missing: {missing}. The timing relationship with the medication cannot be evaluated safely until this is completed.',
    'copy.interaction_analysis_protein':
        'Estimated protein for this meal is about {protein} g. If levodopa is active, protein amount matters for timing checks.',
    'copy.interaction_analysis_fallback':
        'Some foods used regional fallback data, so local authoritative coverage is still incomplete.',
    'copy.interaction_analysis_database':
        'When available, imported database nutrient facts were used.',
    'copy.interaction_analysis_not_diagnosis':
        'Treat this as a conservative safety reminder to complete missing information, not as a diagnosis.',
    'copy.key_finding_missing_inputs':
        'Timing check cannot be completed because required medication information is missing: {missing}.',
    'copy.next_action_complete_med_timing':
        'Add the medication time and dose first, then run the check again.',
    'copy.data_note_fallback':
        'Some foods are temporarily using regional fallback data until a more local authoritative source is available.',
    'copy.data_note_database':
        'The check used real database nutrient data where available, not only built-in sample values.',
    'copy.data_note_missing_input':
        'Missing {missing} makes timing rules more conservative.',
    'copy.issue_missing_inputs':
        'Missing {missing}, so the app cannot safely judge whether this meal should be separated from this medication.',
    'recommend.context_iron_supplement':
        'An iron supplement was recorded with the latest meal, so timing guidance stays conservative.',
    'recommend.context_iron_multivitamin':
        'A multivitamin with iron was recorded with the latest meal, so timing guidance stays conservative.',
    'recommend.context_starch_thickener':
        'A starch-based thickener was recorded, which raises swallowing-safety priority.',
    'recommend.context_xanthan_thickener':
        'A xanthan-based thickener was recorded for the latest meal.',
    'recommend.context_enteral_feed_continuous':
        'Continuous enteral feeding is active ({protein} g/day protein), so recommendation wording stays conservative.',
    'recommend.context_enteral_feed_bolus':
        'Bolus/intermittent enteral feeding was recorded for the latest meal.',
    'recommend.context_iron_penalty':
        'Iron-related coevents are present, so higher-protein options stay conservatively down-ranked.',
    'recommend.context_enteral_penalty':
        'Continuous enteral feeding context is present, so higher-protein options stay conservatively down-ranked.',
    'recommend.context_texture_gap_penalty':
        'A thickener was recorded, but the current catalog still lacks structured texture compatibility data, so extra conservative margin is kept.',
    'recommend.context_texture_supported':
        'A thickener was recorded, and this candidate already carries structured texture metadata, so the data-gap penalty stays lower.',
    'recommend.texture_profile_missing':
        'A texture safety mode is active, but this candidate lacks structured texture metadata, so ranking stays more conservative.',
    'recommend.texture_profile_supported_soft_or_liquid':
        'This candidate matches the current soft-or-liquid texture safety mode.',
    'recommend.texture_profile_supported_liquid_only':
        'This candidate matches the current liquid-only texture safety mode.',
    'recommend.texture_profile_incompatible':
        'This candidate does not match the current texture safety mode, so it is conservatively down-ranked.',
    'recommend.texture_template_supported':
        'This candidate matches the current meal-template texture direction.',
    'recommend.texture_template_mismatch':
        'This candidate does not match the current meal-template texture direction.',
    'recommend.local_seed_metadata':
        'This candidate still depends on local seed metadata instead of richer database-backed observations.',
    'recommend.timing_window_incomplete':
        'The timing window is incomplete, so the conservative ranking keeps extra safety margin.',
    'recommend.next_meal_gap_close':
        'The next-meal window is still close to the previous meal; a lower-protein option is preferred.',
    'recommend.next_meal_window_fiber':
        'This fits the planned next-meal window and favors steadier fiber intake.',
    'recommend.medication_timing_caution':
        'Medication timing suggests extra caution for this next-meal window.',
    'texture_mode.unrestricted': 'Unrestricted',
    'texture_mode.soft_or_liquid': 'Soft or liquid',
    'texture_mode.liquid_only': 'Liquid only',
    'texture_class.liquid': 'Liquid',
    'texture_class.soft': 'Soft',
    'texture_class.regular': 'Regular',
    'food.food_chicken_breast': 'Chicken breast (cooked)',
    'food.food_tofu': 'Plain tofu',
    'food.food_brown_rice': 'Brown rice',
    'food.food_banana': 'Banana',
    'food.food_spinach': 'Spinach',
    'food.food_milk': 'Semi-skimmed milk',
    'food.food_beef': 'Lean beef (fried)',
    'food.food_apple': 'Apple (with skin)',
    'food.food_blueberry': 'Blueberry',
    'food.food_tomato': 'Tomato',
    'food.food_broccoli': 'Broccoli',
    'food.food_oats': 'Rolled oats',
    'food.food_salmon': 'Salmon (farmed, baked)',
    'food.food_fava_beans': 'Fava beans (fresh)',
    'food.food_potato_boiled': 'Potato (boiled)',
    'food.food_walnuts': 'Walnuts',
    'food.food_olive_oil': 'Extra virgin olive oil',
    'food.food_cheddar_cheese': 'Cheddar cheese',
    'food.food_egg_boiled': 'Egg (boiled)',
    'food.food_coffee': 'Coffee (brewed, unsweetened)',
    'medication_note.drug_levodopa_carbidopa':
        'Common Parkinson combination therapy. Some patients may notice fluctuations after high-protein meals.',
    'medication_note.drug_entacapone':
        'COMT inhibitor, often used together with levodopa.',
    'medication_note.drug_opicapone':
        'Once-daily COMT inhibitor used as adjunctive therapy with levodopa/carbidopa for OFF episodes.',
    'medication_note.drug_tolcapone':
        'COMT inhibitor with liver-monitoring context. Food timing is usually secondary to safety monitoring and levodopa co-therapy.',
    'medication_note.drug_rasagiline':
        'MAO-B inhibitor. Tyramine intake is a documented interaction topic for this drug class. Review any dietary questions with a qualified clinician.',
    'medication_note.drug_safinamide':
        'Adjunct MAO-B inhibitor used with levodopa/carbidopa. Very high tyramine exposure remains a caution point.',
    'medication_note.drug_selegiline':
        'MAO-B inhibitor. The high-tyramine rule is still a baseline placeholder here.',
    'medication_note.drug_iron':
        'Mineral supplement. Meal timing may matter for tolerance and absorption.',
    'medication_note.drug_pramipexole':
        'Dopamine agonist. Food conflicts are usually limited compared with sedation, orthostasis and impulse-control concerns.',
    'medication_note.drug_ropinirole':
        'Dopamine agonist used in early or adjunctive therapy. Current engine has no major food hard-stop for it.',
    'medication_note.drug_rotigotine':
        'Transdermal dopamine agonist. Food timing is less central because therapy bypasses the gastrointestinal route.',
    'medication_note.drug_apomorphine':
        'Rescue or advanced OFF therapy depending on formulation. Route-specific context matters more than meal timing.',
    'medication_note.drug_amantadine':
        'Used for Parkinson symptoms or dyskinesia depending on formulation. Food conflicts are not the main current rule target.',
    'medication_note.drug_istradefylline':
        'Adjunct OFF-episode therapy. Included as a PD-relevant medication even though current food rules are limited.',
    'medication_note.drug_pimavanserin':
        'Parkinson disease psychosis therapy. Included for PD care completeness rather than a direct food rule.',
    'medication_note.drug_rivastigmine':
        'Used in Parkinson disease dementia. Oral forms are often taken with food for tolerance; patch therapy changes the GI context.',
    'medication_note.drug_droxidopa':
        'Used for neurogenic orthostatic hypotension. Consistent fed-state timing can matter clinically.',
    'medication_note.drug_midodrine':
        'Used for orthostatic hypotension. Food timing is less central than daytime scheduling and blood-pressure monitoring.',
    'medication_note.drug_peg_3350':
        'Osmotic laxative. Current hard rule mainly concerns incompatibility with starch-based thickeners.',
    'medication_note.drug_levodopa_entacapone':
        'Fixed-dose levodopa combination. Apply the same high-protein and iron-separation caution used for other levodopa products.',
    'medication_note.drug_levodopa_benserazide':
        'Levodopa combination used outside the U.S. Apply the same protein-timing and iron-separation caution as other levodopa therapies.',
  },
  'fr': {
    'app.welcome': 'Bienvenue',
    'app.loading': 'Chargement...',
    'history.title': 'Historique récupérable des enregistrements',
    'history.subtitle':
        'Les créations, modifications, suppressions et restaurations de repas et de prises sont enregistrées atomiquement avec une révision immuable.',
    'history.conflict_help':
        'Une révision ne peut être restaurée que si l’enregistrement actuel correspond encore exactement à son résultat. Un travail plus récent n’est jamais écrasé silencieusement.',
    'history.filter_all': 'Tout',
    'history.meal': 'Repas',
    'history.intake': 'Prise',
    'history.empty':
        'Aucune révision récupérable. Les prochaines créations, modifications et suppressions apparaîtront ici.',
    'history.event_create': 'Créé',
    'history.event_update': 'Modifié',
    'history.event_delete': 'Supprimé',
    'history.event_restore': 'Restauré',
    'history.restore': 'Restaurer l’état antérieur',
    'history.restore_unavailable':
        'Modification plus récente ; écrasement interdit',
    'history.restored':
        'L’état antérieur a été restauré comme nouvelle révision.',
    'history.restore_conflict':
        'L’enregistrement actuel a changé. Aucune restauration n’a été effectuée afin de protéger les données récentes.',
    'history.deleted_undo': 'Enregistrement supprimé.',
    'history.undo': 'Annuler',
    'history.restored_refresh_incomplete':
        'L’état antérieur a été restauré durablement, mais certaines vues dérivées n’ont pas été actualisées. L’enregistrement n’a pas été annulé.',
    'history.restore_blocked':
        'Les contrôles de relation ou d’intégrité ont échoué. Aucune restauration n’a été effectuée.',
    'history.preview_title': 'Aperçu de l’impact de la restauration',
    'history.preview_semantics':
        'Aperçu en lecture seule et confirmation de la restauration',
    'history.preview_exact_write': 'Modification exacte de l’enregistrement',
    'history.preview_target_restore':
        'Rétablir cet enregistrement dans l’état équivalent octet par octet précédant la révision sélectionnée.',
    'history.preview_target_remove':
        'L’enregistrement n’existait pas avant la révision sélectionnée. La confirmation supprime l’enregistrement actuel.',
    'history.preview_relationships_title':
        'Modifications des relations du catalogue',
    'history.preview_relationships_body':
        '{count} relations subsistent après restauration ; {added} ajoutées et {removed} supprimées.',
    'history.preview_derived_title': 'Les résultats dérivés seront régénérés',
    'history.preview_derived_body':
        'Les contrôles de repas, explications, traces mécanistes, résumés de transmission et relations du paquet portable sont invalidés puis recalculés avec les algorithmes actuels. Un ancien résultat algorithmique n’est jamais traité comme actuel.',
    'history.preview_evidence_title': 'L’historique reste immuable',
    'history.preview_evidence_body':
        'La révision sélectionnée n’est jamais réécrite. Cette restauration est ajoutée comme nouvelle révision.',
    'history.preview_identity_title': 'Identité de calcul liée',
    'history.preview_identity_body':
        'Algorithme {algorithm} · graphe de relations {graph}',
    'history.preview_missing_title': 'Relation non résolue',
    'history.preview_missing_body':
        'Le catalogue actuel ne contient pas {ids}. La restauration reste désactivée pour éviter des résultats dérivés incomplets.',
    'history.preview_status_ready':
        'Contrôles réussis. La restauration peut être confirmée.',
    'history.preview_status_stale':
        'L’enregistrement a changé. Fermez cet aperçu et générez-en un nouveau.',
    'history.preview_status_account':
        'Le périmètre du compte est indisponible. La restauration reste désactivée.',
    'history.preview_status_relationships':
        'Une relation du catalogue n’est pas résolue. La restauration reste désactivée.',
    'history.preview_status_integrity':
        'Les contrôles d’intégrité de l’aperçu ont échoué. La restauration reste désactivée.',
    'history.preview_cancel': 'Annuler',
    'history.preview_confirm': 'Confirmer et restaurer',
    'onboarding.title': 'ParkinSUM Companion (edition locale)',
    'onboarding.description':
        'Cette application sert au suivi des repas et a des alertes basees sur des regles. Elle ne remplace pas les conseils de votre medecin ou pharmacien.',
    'onboarding.registration_region': "Region d'inscription",
    'onboarding.registration_region_help':
        'Determine la chaine de juridiction par defaut et la priorite des sources.',
    'onboarding.display_language': "Langue d'affichage",
    'onboarding.display_language_help':
        "Controle la langue de l'application, les dates et les formats numeriques.",
    'onboarding.diet_profile_region': 'Region du profil alimentaire',
    'onboarding.swallowing_texture_mode':
        'Preference de securite de deglutition / texture',
    'onboarding.swallowing_texture_mode_help':
        'Utilisee comme preference conservative dans les recommandations ; ne remplace pas une evaluation clinique de deglutition.',
    'onboarding.diet_profile_region_help':
        'Utilisee pour les modeles de repas sans remplacer les regles de securite.',
    'onboarding.content_override': 'Remplacement de juridiction (optionnel)',
    'onboarding.content_override_help':
        'Separez par des virgules, par ex. US,CA',
    'onboarding.local_ai_consent': 'Activer le rerank local par IA (optionnel)',
    'onboarding.local_ai_consent_help':
        'Utilise uniquement Ollama/llama.cpp en localhost et revient au chemin conservateur si la porte de securite le bloque.',
    'onboarding.start': "J'ai compris, continuer",
    'region.CN': 'Chine',
    'region.US': 'Etats-Unis',
    'region.CA': 'Canada',
    'region.FR': 'France',
    'region.JP': 'Japon',
    'region.KR': 'Coree du Sud',
    'region.IN': 'Inde',
    'region.ES': 'Espagne',
    'region.MX': 'Mexique',
    'region.VN': 'Vietnam',
    'region.TH': 'Thailande',
    'region.ID': 'Indonesie',
    'region.RU': 'Russie',
    'region.PL': 'Pologne',
    'region.SA': 'Arabie saoudite',
    'nav.home': 'Accueil',
    'nav.analytics': 'Analyses',
    'nav.meals': 'Repas',
    'nav.timeline': 'Chronologie',
    'nav.meds': 'Medicaments',
    'nav.catalog': 'Catalogue',
    'nav.next_meal': 'Repas suivant',
    'next_meal.title': 'Recommandation du prochain repas',
    'next_meal.subtitle':
        'Choisissez l\'heure prevue du prochain repas. Le chemin de regles conservateur garde l\'ordre des candidats ; le modele mecanistique ajoute seulement une trace temporelle educative et ne reclasse rien. L\'IA locale est un reclassement optionnel et separe sur liste sure.',
    'next_meal.input_time': 'Heure prevue du prochain repas',
    'next_meal.use_local_ai': 'Polir le texte avec l\'IA locale (optionnel)',
    'next_meal.use_local_ai_help':
        'Appelle uniquement Ollama/llama.cpp sur localhost pour reclasser et reformuler les explications des candidats deja approuves par le moteur ; retombe sur le chemin conservateur si la barriere de securite bloque.',
    'next_meal.generate': 'Generer la recommandation',
    'next_meal.window_title': 'Fenetre de repas que vous fournissez (minutes)',
    'next_meal.window_help':
        "Vous definissez la fenetre. Elle active une trace mecanistique educative ; le modele ne choisit pas l'heure du repas et ne change pas l'ordre conservateur des recommandations.",
    'next_meal.window_none': 'Aucune',
    'next_meal.window_minutes': '{minutes} min',
    'next_meal.generating': 'Generation en cours…',
    'next_meal.empty':
        'Definissez l\'heure prevue puis touchez « Generer la recommandation » ; le moteur reevaluera pour cette fenetre.',
    'next_meal.why_these': 'Pourquoi ces choix',
    'next_meal.ai_polished': 'Texte poli par l\'IA locale',
    'next_meal.conservative_engine': 'Chemin conservateur du moteur de conflit',
    'next_meal.recommendation_path': 'Chemin de recommandation',
    'next_meal.gate_reasons': 'Notes de la barriere de securite',
    'next_meal.candidates': 'Meilleurs candidats',
    'next_meal.no_candidates':
        'Aucun candidat approprie selon les contraintes actuelles. Ajustez l\'heure prevue ou enrichissez le catalogue.',
    'next_meal.error': 'Echec de la generation',
    'dashboard.title': 'Tableau de bord',
    'dashboard.status': "Vue d'ensemble",
    'dashboard.logged_meals': 'Repas enregistres : {count}',
    'dashboard.active_drugs': 'Medicaments actifs : {count}',
    'dashboard.logged_intakes': 'Prises de medicaments : {count}',
    'dashboard.recommendations': 'Recommandations',
    'dashboard.no_recommendations': 'Aucune recommandation pour le moment',
    'dashboard.recommendation_path': 'Chemin de recommandation',
    'dashboard.recommendation_template':
        'Modele actif : {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'Amelioration IA locale utilisee',
    'dashboard.ai_not_used': 'Chemin conservateur uniquement',
    'dashboard.recommendation_why': 'Pourquoi ces recommandations',
    'dashboard.recommendation_gate': 'Statut IA / gate de securite',
    'dashboard.recommendation_macro_line':
        'Pour 100 g : P {protein} g · G {carbs} g · L {fat} g',
    'dashboard.recommendation_score_line':
        'Securite {safety} · Horaire {schedule} · Donnees {facts} · Penalite contexte {context} · Penalite fenetre {timing} · Penalite deglutition {swallowing} · Adequation modele {template}',
    'dashboard.recent_meals': 'Repas recents (5 derniers)',
    'dashboard.no_meals': 'Aucun repas enregistre',
    'dashboard.items': '{count} elements',
    'dashboard.meal_context_iron_supplement': 'coevenement supplement en fer',
    'dashboard.meal_context_iron_multivitamin':
        'coevenement multivitamine avec fer',
    'dashboard.meal_context_starch_thickener': 'epaississant a base d amidon',
    'dashboard.meal_context_xanthan_thickener':
        'epaississant a base de xanthane',
    'dashboard.meal_context_enteral_feed_continuous':
        'nutrition enterale continue ({protein} g/jour de proteines)',
    'dashboard.meal_context_enteral_feed_bolus':
        'nutrition enterale bolus/intermittente',
    'dashboard.edit': 'Modifier',
    'dashboard.delete': 'Supprimer',
    'dashboard.protein_trend': 'Tendance proteique',
    'dashboard.average_protein': 'Proteines moyennes : {value} g / repas',
    'dashboard.no_trend': 'Aucune donnee de tendance',
    'dashboard.timeline': 'Chronologie',
    'dashboard.no_timeline': 'Aucun evenement repas ou medicament',
    'dashboard.add_meal': 'Ajouter un repas',
    'dashboard.meal_check': 'Verification du repas - {title}',
    'common.close': 'Fermer',
    'common.done': 'Terminer',
    'common.cancel': 'Annuler',
    'common.apply': 'Appliquer',
    'common.optional': 'facultatif',
    'common.delete': 'Supprimer',
    'common.edit': 'Modifier',
    'auth.account_title': 'Compte ParkinSUM',
    'auth.create_account': 'Creer un compte',
    'auth.sign_in': 'Se connecter',
    'auth.email': 'Courriel',
    'auth.password': 'Mot de passe',
    'auth.invalid_email': 'Saisissez un courriel valide.',
    'auth.password_required': 'Saisissez votre mot de passe.',
    'auth.password_registration_requirement':
        'Le nouveau mot de passe doit contenir au moins {minimum} caracteres.',
    'auth.register': "S'inscrire",
    'auth.have_account': 'Vous avez deja un compte ? Connectez-vous',
    'auth.need_account': "Besoin d'un compte ? Inscrivez-vous",
    'auth.forgot_password': 'Mot de passe oublie ?',
    'auth.privacy': 'Confidentialite et avertissement',
    'auth.reset_neutral':
        'Si un compte correspond a ce courriel, un message de reinitialisation a ete envoye.',
    'auth.show_password': 'Afficher le mot de passe',
    'auth.hide_password': 'Masquer le mot de passe',
    'reminders.title': 'Rappels de journalisation',
    'reminders.add': 'Ajouter un rappel',
    'reminders.edit': 'Modifier le rappel',
    'reminders.resynchronize': 'Relancer la demande de planification',
    'reminders.synchronized': 'Demande de planification terminee',
    'reminders.last_sync': 'Derniere demande terminee : {time}',
    'reminders.schedule_capacity_title':
        'Budget de securite de planification ParkinSUM',
    'reminders.schedule_capacity_body':
        "Requetes ParkinSUM prevues : {projected}/{limit}; marge de securite de l'application : {headroom}. Il s'agit d'une limite produit prudente, et non de la capacite systeme libre de l'appareil. Chaque jour active utilise une requete.",
    'reminders.schedule_capacity_invalid':
        "Ce plan ne peut pas etre soumis ({projected}/{limit}) : le budget de securite ParkinSUM, l'identite ou le contrat du plan a echoue. Le plan existant n'a pas change.",
    'reminders.identity_attestation_title':
        'Controle des identites en attente signalees par le plugin',
    'reminders.identity_attestation_matched':
        "Les identites en attente signalees par le plugin correspondent au plan ({installed}/{planned}). Ce n'est pas une verification independante du planificateur du systeme ni de la livraison visible.",
    'reminders.identity_attestation_drift':
        'Les identites signalees different du plan : {missing} manquantes, {extra} en trop et {replaced} remplacees sous un identifiant prevu. Ne comptez pas sur les rappels systeme avant une reconciliation reussie.',
    'reminders.identity_attestation_uninspectable':
        "Les identites en attente n'ont pas pu etre lues depuis le plugin. Le plan local reste la reference, mais l'etat des rappels systeme n'est pas verifie.",
    'reminders.delete_title': 'Supprimer ce rappel ?',
    'reminders.delete_body':
        '« {label} » sera retire de cet appareil et son rappel systeme sera annule.',
    'reminders.boundary_title': 'Invite de journalisation uniquement',
    'reminders.boundary_body':
        "Vous choisissez l'heure et le texte. ParkinSUM ne calcule, ne recommande ni ne prescrit une heure de dose; suivez votre clinicien et l'etiquette du medicament.",
    'reminders.web_title': 'Rappels systeme recurrents indisponibles ici',
    'reminders.web_body':
        "Le plan reste enregistre sur cet appareil, mais les versions Web, Windows et Linux n'envoient pas encore d'alertes recurrentes lorsque l'application est fermee.",
    'reminders.empty_title': 'Aucun rappel de journalisation',
    'reminders.empty_body':
        'Ajoutez votre propre invite pour consigner un repas ou une prise de medicament.',
    'reminders.kind': 'Type de journal',
    'reminders.kind_mealLog': 'Journal de repas',
    'reminders.kind_intakeLog': 'Journal de prise de medicament',
    'reminders.label': 'Texte du rappel',
    'reminders.label_help':
        'Ecrivez une invite de journalisation, pas une instruction de dose ou de prescription.',
    'reminders.privacy': 'Confidentialite de la notification',
    'reminders.privacy_help':
        'Ce reglage controle uniquement le texte visible par le systeme. Votre texte reste dans ParkinSUM.',
    'reminders.privacy_minimal': 'Minimal (par defaut)',
    'reminders.privacy_generic': 'Invite generique de journalisation',
    'reminders.privacy_preview': 'Apercu de la notification systeme',
    'reminders.privacy_minimal_boundary':
        "Android demande de ne montrer aucun contenu sur un ecran verrouille securise. Les plateformes Apple suivent toujours le reglage d'apercu de l'utilisateur.",
    'reminders.privacy_generic_boundary':
        "Android demande un affichage limite aux informations de base. Les plateformes Apple suivent toujours le reglage d'apercu de l'utilisateur.",
    'reminders.days': 'Repeter le',
    'reminders.next': 'Prochain',
    'reminders.validation':
        'Saisissez un texte et selectionnez au moins un jour.',
    'reminders.error_load_failed':
        "Impossible de lire les rappels enregistres.",
    'reminders.error_permission_denied':
        "L'autorisation de notification est desactivee; le rappel n'a pas ete active.",
    'reminders.error_schedule_failed':
        'La reconciliation systeme a echoue. Le plan local existant reste la reference et sera reessaye au lancement ou a la reprise.',
    'reminders.error_recovery_required':
        "L'etat des rappels sur l'appareil n'a pas pu etre verifie. Le plan local existant reste la reference; relancez la demande et confirmez-la avant de compter sur les rappels systeme.",
    'reminders.error_schedule_invalid':
        "Le nouveau plan n'a pas ete enregistre car son budget de securite ParkinSUM, son identite ou son contrat est invalide.",
    'reminders.error_schedule_identity_unverified':
        "Le plan local a ete enregistre, mais les identites en attente signalees par le plugin ne correspondent pas au plan. Relancez la reconciliation avant de compter sur les rappels systeme.",
    'reminders.error_save_failed':
        "Le rappel n'a pas ete enregistre. Reessayez.",
    'reminders.explicit_medication_selection':
        "Selectionnez explicitement le medicament pris. Ouvrir ce brouillon ne confirme aucune prise.",
    'reminders.response_unavailable':
        "Ce rappel est indisponible ou n'appartient pas a ce compte. Aucun enregistrement n'a ete cree.",
    'reminders.response_replayed':
        "Une action de rappel repetee a ete ignoree. Aucun enregistrement n'a ete cree.",
    'reminders.day_1': 'Lun',
    'reminders.day_2': 'Mar',
    'reminders.day_3': 'Mer',
    'reminders.day_4': 'Jeu',
    'reminders.day_5': 'Ven',
    'reminders.day_6': 'Sam',
    'reminders.day_7': 'Dim',
    'common.completed': 'Termine',
    'common.error': 'Erreur',
    'common.search_results': 'Resultats de recherche',
    'common.no_matching_foods': 'Aucun aliment correspondant',
    'common.texture': 'Texture',
    'meal_slot.breakfast': 'Petit-dejeuner',
    'meal_slot.lunch': 'Dejeuner',
    'meal_slot.dinner': 'Diner',
    'meal_slot.snack': 'Collation',
    'entry.new_title': 'Nouveau repas',
    'entry.edit_title': 'Modifier le repas',
    'entry.default_meal_title': 'Mon repas',
    'entry.meal_title': 'Titre du repas',
    'entry.search_food': 'Rechercher des aliments a ajouter',
    'entry.view_food_detail': 'Voir le detail de l aliment',
    'entry.add_food': 'Ajouter cet aliment',
    'entry.actual_meal_time': 'Heure reelle du repas',
    'entry.recorded_time_hint': "Heure d'enregistrement : {value}",
    'entry.actual_time_value': 'Pris a : {value}',
    'entry.edit_actual_time': "Modifier l'heure du repas",
    'entry.time_uncertain': 'Heure approximative',
    'entry.actual_window_value': 'Fenetre possible du repas : {start} - {end}',
    'entry.edit_actual_window': 'Modifier la fenetre du repas',
    'entry.next_meal_window': 'Fenetre attendue du prochain repas',
    'entry.next_meal_window_empty': 'Aucune fenetre de prochain repas definie',
    'entry.next_meal_window_value':
        'Fenetre du prochain repas : {start} - {end}',
    'entry.edit_next_meal_window': 'Modifier la fenetre du prochain repas',
    'entry.clear_next_meal_window': 'Effacer la fenetre suivante',
    'entry.supplement_context': 'Contexte supplement / coevenement',
    'entry.with_iron_supplement': 'Supplement en fer pris avec ce repas',
    'entry.with_iron_multivitamin':
        'Multivitamine avec fer prise avec ce repas',
    'entry.thickener_type': 'Type d epaississant',
    'entry.thickener_starch_based': 'A base d amidon',
    'entry.thickener_xanthan_based': 'A base de xanthane',
    'entry.coevent_time_empty':
        'Aucune heure de coevenement saisie ; l heure du repas sera utilisee par defaut.',
    'entry.coevent_time_value': 'Heure du coevenement : {value}',
    'entry.edit_coevent_time': 'Modifier l heure du coevenement',
    'entry.enteral_feed_context': 'Contexte de nutrition enterale',
    'entry.enteral_feed_continuous': 'Continue',
    'entry.enteral_feed_bolus': 'Bolus / intermittente',
    'entry.enteral_feed_formula': 'Note sur la formule enterale',
    'entry.enteral_feed_protein_g_per_day':
        'Proteines de nutrition enterale (g/jour)',
    'entry.none': 'Aucun',
    'entry.summary': 'Resume du repas',
    'entry.no_foods_yet': "Aucun aliment ajoute pour l'instant",
    'entry.per_100g': 'Par 100 g : P {protein}g - C {carbs}g',
    'entry.added_foods': 'Aliments ajoutes',
    'entry.add_food_prompt':
        'Ajoutez dabord des aliments depuis les resultats de recherche ci-dessus',
    'entry.grams': 'Grammes',
    'entry.protein': 'Proteines',
    'entry.carbs': 'Glucides',
    'entry.quantity_factor': 'Facteur de portion : {value} x 100g',
    'entry.set_quantity': 'Definir la portion',
    'entry.saving': 'Enregistrement...',
    'entry.save_new': 'Enregistrer le repas et verifier les conflits',
    'entry.save_edit': 'Enregistrer les modifications et verifier les conflits',
    'entry.add_food_first': 'Veuillez ajouter au moins un aliment',
    'entry.food_added': '{name} ajoute',
    'entry.saved_title': 'Repas enregistre et verifie',
    'entry.updated_title': 'Repas mis a jour et verifie',
    'entry.save_failed': "Echec de l'enregistrement : {error}",
    'entry.adjust_quantity': 'Ajuster la portion - {name}',
    'meal.title': 'Repas',
    'meal.empty': 'Aucun repas enregistre',
    'meal.check_title': 'Verification du repas - {title}',
    'medications.title': 'Medicaments',
    'analytics.title': 'Analyses',
    'analytics.localization': 'Etat de la localisation',
    'analytics.localization_language': 'Langue d affichage actuelle : {value}',
    'analytics.localization_region': 'Region d inscription actuelle : {value}',
    'analytics.localization_timezone': 'Fuseau horaire actuel : {value}',
    'analytics.localization_override':
        'Override de juridiction du contenu : {value}',
    'analytics.localization_override_none': 'Non defini',
    'analytics.localization_texture_mode':
        'Preference actuelle de texture de securite : {value}',
    'analytics.localization_help':
        'Quand la langue ou la region change pendant l inscription, l application reconstruit maintenant les ecrans avec la locale active et affiche ici le reglage effectif.',
    'analytics.local_ai': 'IA locale',
    'analytics.local_ai_enable': 'Activer le rerank IA local',
    'analytics.local_ai_help':
        'L IA ne rerank que des candidats deja juges surs et peut etre bloquee par les garde-fous.',
    'analytics.local_ai_provider': 'Provider IA locale',
    'analytics.local_ai_provider_auto': 'Auto (Ollama en priorite)',
    'analytics.local_ai_provider_ollama': 'Ollama',
    'analytics.local_ai_provider_openai': 'llama.cpp / compatible OpenAI',
    'analytics.local_ai_model': 'Nom du modele',
    'analytics.local_ai_medical_model': 'Modele de revue medicale',
    'analytics.local_ai_ollama_endpoint': 'Endpoint Ollama',
    'analytics.local_ai_openai_endpoint': 'Endpoint compatible OpenAI',
    'analytics.local_ai_timeout_ms': 'Delai (ms)',
    'analytics.local_ai_check': 'Verifier l IA locale',
    'analytics.local_ai_status_available': 'IA locale disponible',
    'analytics.local_ai_status_unavailable': 'IA locale indisponible',
    'analytics.recommendation_path': 'Chemin de recommandation actuel',
    'analytics.recommendation_explanations':
        'Explications de recommandation actuelles',
    'analytics.recommendation_gate_reasons':
        'Raisons actuelles du gate de securite',
    'analytics.import_tools': 'Outils d import P0',
    'analytics.import_tools_help':
        'Importer des paquets officiels ZIP/XML du disque local vers les snapshots CDSS de staging et de promotion.',
    'analytics.open_import_tools': 'Ouvrir les outils d import',
    'analytics.replay_benchmark': 'Benchmark de replay des recommandations',
    'analytics.replay_benchmark_help':
        'Execute les memes scenarios en mode deterministe et en rerank IA, puis affiche les raisons de gate et les ecarts de classement.',
    'analytics.replay_run': 'Lancer le replay benchmark',
    'analytics.replay_running': 'Replay benchmark en cours',
    'analytics.replay_last_report': 'Dernier rapport de replay',
    'analytics.replay_cases': 'Nombre de cas : {count}',
    'analytics.replay_report_error': 'Echec du replay : {error}',
    'import.title': 'Import P0 local',
    'import.description':
        'Collez un chemin de fichier ZIP ou un chemin de dossier pour chaque source officielle. Ciqual peut utiliser un dossier contenant ses fichiers XML.',
    'import.remote_tasks': 'Taches d import officielles distantes',
    'import.ema_medicines': 'Metadonnees EMA medicines',
    'import.ema_post_authorisation': 'Metadonnees EMA post-authorisation',
    'import.china_official_foods': 'Pages alimentaires officielles chinoises',
    'import.run': 'Lancer l import',
    'import.retry': 'Relancer la derniere tache',
    'import.retry_source': 'Relancer cette source',
    'import.last_result': 'Dernier resultat d import',
    'import.step_status_ok': 'OK',
    'import.step_status_failed': 'ECHEC',
    'import.run_id': 'ID de run',
    'import.snapshot': 'Snapshot',
    'import.source_documents': 'Documents source',
    'import.food_variants': 'Variantes alimentaires',
    'import.drug_variants': 'Variantes de medicaments',
    'import.observations': 'Observations',
    'import.drilldown_runs': 'Detail des runs',
    'import.drilldown_source_docs': 'Detail des documents source',
    'import.stage': 'Etape',
    'import.status': 'Statut',
    'import.doc_type': 'Type de document',
    'import.data_tier': 'Niveau de donnees',
    'import.ingestion_strategy': 'Strategie d import',
    'import.source_status': 'Statut de la source',
    'import.origin_url': 'URL source',
    'import.ciqual_path': 'Dossier XML / ZIP Ciqual',
    'import.fdc_path': 'ZIP / dossier FDC',
    'import.dailymed_path': 'ZIP / dossier DailyMed',
    'import.dpd_path': 'ZIP / dossier DPD Health Canada',
    'import.running':
        'La tache d import est en cours. Les grands paquets ZIP peuvent prendre du temps.',
    'import.ops_title': 'Publication et distribution CDSS',
    'import.ops_help':
        'Publiez les snapshots vers un canal local stable, exportez des bundles pour le backend et consultez ici l historique des rollbacks et distributions.',
    'import.snapshot_registry': 'Registre des snapshots',
    'import.snapshot_status_staging': 'staging',
    'import.snapshot_status_promoted': 'promoted',
    'import.fact_count': 'Faits resolus',
    'import.rules_version': 'Version des regles',
    'import.release_readiness': 'Pret pour publication',
    'import.release_ready': 'Pret',
    'import.release_blocked': 'Bloque',
    'import.label_sections': 'Sections de notice',
    'import.blocking_issues': 'Problemes bloquants',
    'import.warnings': 'Avertissements',
    'import.rollback_parent': 'Parent de rollback',
    'import.publish': 'Publier',
    'import.export_bundle': 'Exporter le bundle',
    'import.snapshot_bundle_path': 'Chemin du bundle snapshot',
    'import.import_bundle': 'Importer le bundle',
    'import.rollback': 'Rollback vers ce snapshot',
    'import.monitoring': 'Supervision des imports',
    'import.total_runs': 'Nombre total de runs',
    'import.distribution_history': 'Historique de distribution',
    'import.channel': 'Canal',
    'import.artifact_path': 'Chemin de l artefact',
    'analytics.protein_trend': 'Tendance proteique',
    'analytics.average_protein': 'Proteines moyennes par repas : {value} g',
    'analytics.no_trend': 'Aucune donnee de tendance',
    'catalog.title': 'Catalogue',
    'catalog.search': 'Rechercher des aliments ou des medicaments',
    'catalog.foods': 'Aliments',
    'catalog.drugs': 'Medicaments',
    'catalog.food_subtitle':
        'Categorie={category}  P/C/F={protein}/{carbs}/{fat} (par 100g)',
    'catalog.drug_subtitle': 'Etiquettes={tags}',
    'catalog.view_detail': 'Voir les details',
    'settings.title': 'Paramètres et centre des fonctions',
    'settings.profile': 'Profil d’inscription et préférences de sécurité',
    'settings.capabilities': 'Accès à toutes les fonctions',
    'settings.queue': 'File de mise à niveau complète',
    'settings.queue_help':
        'Cette file distingue le travail livré de la recherche et de la validation externe. Elle ne constitue ni validation clinique ni autorisation réglementaire.',
    'settings.saved': 'Profil enregistré.',
    'settings.saved_refresh_pending':
        'Profil enregistré, mais les recommandations dérivées n’ont pas été actualisées. Réessayez plus tard.',
    'settings.save_failed':
        'Échec de l’enregistrement. Le dernier profil enregistré reste actif : {error}',
    'settings.account': 'Compte et limites des données',
    'settings.local_mode':
        'Mode local : les données restent dans le stockage local de l’application sur cet appareil.',
    'settings.open': 'Ouvrir',
    'settings.reviewed': 'Recherche révisée le {date}',
    'settings.score': 'Score de priorité {score}',
    'settings.email_verified': 'Adresse courriel vérifiée',
    'settings.email_unverified': 'Adresse courriel non vérifiée',
    'settings.send_verification': 'Envoyer le courriel de vérification',
    'settings.refresh_verification': 'Actualiser l’état de vérification',
    'settings.verification_sent':
        'Courriel de vérification envoyé. Terminez la vérification depuis votre boîte de réception.',
    'settings.verification_refreshed': 'État de vérification actualisé.',
    'settings.auth_action_failed': 'Échec de l’action du compte : {error}',
    'settings.change_password': 'Modifier le mot de passe',
    'settings.change_password_title':
        'Se réauthentifier et modifier le mot de passe',
    'settings.current_password': 'Mot de passe actuel',
    'settings.new_password': 'Nouveau mot de passe',
    'settings.confirm_password': 'Confirmer le nouveau mot de passe',
    'settings.password_requirement':
        'Utilisez une phrase secrète d’au moins 15 caractères. Les espaces et caractères Unicode sont acceptés, sans mélange imposé de majuscules, chiffres ou symboles.',
    'settings.password_current_required':
        'Saisissez votre mot de passe actuel.',
    'settings.password_too_short':
        'Le nouveau mot de passe doit contenir au moins {minimum} caractères.',
    'settings.password_must_differ':
        'Le nouveau mot de passe doit être différent du mot de passe actuel.',
    'settings.password_confirmation_mismatch':
        'Les deux nouveaux mots de passe ne correspondent pas.',
    'settings.show_passwords': 'Afficher les mots de passe',
    'settings.hide_passwords': 'Masquer les mots de passe',
    'settings.password_changed': 'Mot de passe mis à jour.',
    'settings.password_error_wrong_current':
        'Le mot de passe actuel est incorrect. Réessayez.',
    'settings.password_error_weak':
        'Le service d’identité a refusé ce mot de passe. Utilisez une phrase secrète plus longue et peu courante.',
    'settings.password_error_too_many':
        'Trop de tentatives. Attendez avant de réessayer.',
    'settings.password_error_recent_login':
        'Votre preuve de connexion a expiré. Reconnectez-vous puis réessayez.',
    'settings.password_error_service':
        'Le service de compte est temporairement indisponible. Réessayez plus tard.',
    'settings.password_provider_unavailable':
        'Ce compte n’est pas associé à la connexion par mot de passe. Le mot de passe ne peut pas être modifié ici.',
    'settings.password_error_not_signed_in':
        'Vous êtes déconnecté. Reconnectez-vous puis réessayez.',
    'settings.password_error_unknown':
        'Le mot de passe n’a pas pu être modifié. Rien n’a changé; réessayez plus tard.',
    'settings.data_integrity': 'Intégrité des données',
    'settings.data_import': 'Importation de données',
    'privacy.title': 'Confidentialité et avertissement',
    'diagnostics.title': 'Diagnostics techniques',
    'diagnostics.rerun': 'Relancer les verifications',
    'diagnostics.scope_title': 'Revue technique uniquement',
    'diagnostics.scope_body':
        'Verifications de gouvernance deterministes (compilation des textes, controle de securite de localisation, rejeu de scenarios synthetiques). Elles indiquent uniquement un etat technique : elles ne modifient aucun score, gravite, preuve ou resultat de regle, et ne constituent pas un conseil de sante. Donnees synthetiques uniquement.',
    'diagnostics.elapsed': 'Verifications terminees en {ms} ms.',
    'catalog.selected_active': 'Selectionne comme medicament actif',
    'medications.view_detail': 'Voir le detail du medicament',
    'detail.variant_source': 'Variante / source',
    'detail.imported_nutrients': 'Nutriments importes',
    'detail.no_imported_nutrients':
        'Aucune ligne de nutriment importee na ete trouvee.',
    'detail.product_code': 'Code produit',
    'detail.packaging': 'Conditionnement',
    'detail.imported_label_facts': 'Faits de notice importes',
    'detail.imported_label_sections': 'Sections de notice importees',
    'detail.no_imported_label_sections':
        'Aucune section de notice importee na ete trouvee.',
    'detail.media_links': 'Liens media / PDF',
    'detail.macro_summary':
        'Pour 100 g : P {protein} · G {carbs} · L {fat} · Fibres {fiber} · Sodium {sodium}',
    'detail.method_label': 'Methode',
    'detail.source_label': 'Source',
    'interaction.low': 'Risque faible',
    'interaction.moderate': 'Risque modere',
    'interaction.high': 'Risque eleve',
    'interaction.score': 'Score {value}',
    'interaction.analysis_title': 'Analyse',
    'interaction.key_findings': 'Constats cles',
    'interaction.next_actions': 'Actions suivantes',
    'interaction.data_notes': 'Notes sur les donnees et limites',
    'interaction.missing_input': 'Entree critique manquante',
    'interaction.evidence_count': 'Preuves ({count})',
    'interaction.evidence_pmid': 'PMID',
    'interaction.evidence_publication': 'Publication',
    'interaction.evidence_kind': 'Type de preuve',
    'interaction.evidence_source_family': 'Famille de source',
    'interaction.evidence_doi': 'DOI',
    'interaction.evidence_link': 'Lien source',
    'interaction.action_reschedule_full':
        'Envisagez de separer la prise du medicament et le repas d environ {before} minutes avant le repas et {after} minutes apres.',
    'interaction.action_reschedule_before':
        'Envisagez de prendre le medicament au moins {before} minutes avant de manger.',
    'interaction.action_reschedule_generic':
        'Envisagez d ajuster l horaire du medicament et du repas.',
    'interaction.action_separate_by_time':
        'Envisagez un decalage d au moins {minutes} minutes.',
    'interaction.action_avoid_food':
        'Envisagez d eviter cet aliment ou cette combinaison a haut risque.',
    'interaction.action_avoid_combination':
        'Envisagez d eviter cette combinaison medicament-aliment.',
    'interaction.action_switch_thickener':
        'Envisagez de changer d epaississant ou de confirmer manuellement.',
    'interaction.action_manual_review':
        'L etape la plus sure est une revue manuelle.',
    'decision.block': 'Bloquer',
    'decision.require_review': 'Revue requise',
    'decision.discourage': 'Deconseille',
    'decision.warn': 'Avertissement',
    'decision.info': 'Info',
    'decision.allow': 'Autoriser',
    'decision.defer': 'Reporter',
    'severity.low': 'Faible',
    'severity.moderate': 'Modere',
    'severity.high': 'Eleve',
    'severity.critical': 'Critique',
    'missing.dose': 'dose',
    'missing.formulation': 'formulation',
    'missing.time': 'heure de prise',
    'missing.meal_time': 'heure du repas',
    'missing.coevent_time': "heure de l'evenement associe",
    'missing.thickener_type': 'type d epaississant',
    'runtime.same_band_conflict':
        'Des regles de meme priorite ont produit des decisions contradictoires; une revue manuelle est requise.',
    'runtime.missing_fields':
        'Des donnees critiques manquent : {fields}. Une revue manuelle est requise.',
    'runtime.no_rules': 'Aucune regle enregistree na ete declenchee.',
    'runtime.validation_source': 'validation du contexte runtime',
    'mealcheck.no_active_drugs':
        'Aucun medicament actif nest selectionne; aucune regle aliment-medicament na ete declenchee.',
    'mealcheck.no_conflict':
        'La resolution des variantes depuis la base est terminee. Aucune regle enregistree na ete declenchee.',
    'mealcheck.historical_no_current_risk':
        'Ce repas date denviron {hours} heures et se trouve hors de la fenetre active actuelle de conflit aliment-medicament.',
    'mealcheck.historical_analysis':
        'Le moteur ne traite pas ce repas historique comme un risque digestif encore actif. Le repas date denviron {hours} heures, alors que la fenetre operationnelle active actuelle est de {window} heures; il ne genere donc plus dalerte de risque eleve actuelle.',
    'mealcheck.historical_note':
        'Garde-fou repas historique : les repas hors nutrition enterale continue de plus de {window} heures ne declenchent pas de risque horaire actuel.',
    'mealcheck.summary':
        'La verification des variantes alimentaires et medicamenteuses a produit {count} alertes.',
    'mealcheck.analysis':
        'Le moteur a verifie ce repas par rapport a {drugCount} medicament(s) actif(s). Le niveau de severite le plus eleve evalue etait {severity}, avec un score de {score}/100.',
    'mealcheck.analysis_protein':
        'La quantite de proteines estimee a partir de la liste actuelle des aliments etait denviron {protein} g.',
    'mealcheck.analysis_highfat':
        'Lheuristique operationnelle actuelle a aussi classe ce repas comme relativement riche en lipides / calories.',
    'mealcheck.analysis_scoring':
        'Le score est pondere a partir de ces facteurs : {factors}.',
    'mealcheck.analysis_dbfacts':
        'Lorsque des observations importees exactes etaient disponibles, le moteur a utilise les valeurs nutritionnelles de la base au lieu de se limiter aux seeds internes.',
    'mealcheck.analysis_evidence':
        'Cette decision cite directement une notice officielle ou une source de preuve enregistree.',
    'mealcheck.analysis_fallback':
        'Certaines variantes alimentaires ont ete resolues via une chaine de secours regionale; la couverture faisant autorite reste donc partiellement incomplete pour ce controle.',
    'mealcheck.analysis_manual_review':
        'Comme des entrees runtime critiques restent incompletes dans cette session, letape la plus sure est une revue manuelle avant de se fier a une recommandation de synchronisation.',
    'mealcheck.analysis_followup':
        'Si vous voulez une recommandation horaire plus precise, renseignez dabord lheure et la dose du medicament puis relancez le controle.',
    'mealcheck.score_factor_rule_decision': 'Poids de la decision de regle',
    'mealcheck.score_factor_levodopa_interference':
        'Poids d interference levodopa',
    'mealcheck.score_factor_protein_timing': 'Penalite horaire proteines',
    'mealcheck.score_factor_high_fat': 'Modificateur repas riche en lipides',
    'mealcheck.score_factor_iron_levodopa': 'Modificateur fer-levodopa',
    'mealcheck.score_factor_enteral_feed':
        'Modificateur nutrition enterale continue',
    'mealcheck.score_factor_evidence': 'Modificateur preuves',
    'mealcheck.drug_fallback':
        ' La variante de medicament selectionnee provient dune chaine de secours de juridiction.',
    'mealcheck.food_fallback':
        ' Certaines variantes alimentaires proviennent dune chaine de secours de juridiction.',
    'mealcheck.db_facts':
        ' Les valeurs nutritionnelles reelles de la base ont ete utilisees quand elles etaient disponibles.',
    'mealcheck.official_source': 'Source officielle : {title}',
    'mealcheck.analysis_context_used':
        'Cette decision utilise aussi des contextes supplementaires comme les supplements, le type d epaississant ou la nutrition enterale.',
    'mealcheck.context_iron_supplement':
        'Ce repas comprend un coevenement supplement en fer.',
    'mealcheck.context_iron_multivitamin':
        'Ce repas comprend un coevenement multivitamine avec fer.',
    'mealcheck.context_starch_thickener':
        'Ce repas comprend un epaississant a base d amidon.',
    'mealcheck.context_xanthan_thickener':
        'Ce repas comprend un epaississant a base de xanthane.',
    'mealcheck.context_enteral_feed_continuous':
        'Ce repas comprend une nutrition enterale continue ({protein} g/jour de proteines).',
    'mealcheck.context_enteral_feed_bolus':
        'Ce repas comprend une nutrition enterale bolus/intermittente.',
    'legacy.no_conflict':
        'Aucun conflit significatif detecte (uniquement selon les regles integrees; pas un avis medical).',
    'legacy.high_protein_strong':
        'Une fenetre riche en proteines peut fortement affecter labsorption de la levodopa',
    'legacy.high_protein_strong_detail':
        'Ce repas contient environ {protein} g de proteines, soit une plage a risque plus eleve. Pris pres de {drug}, il peut davantage concurrencer labsorption.',
    'legacy.high_protein':
        'Les proteines peuvent affecter labsorption du medicament',
    'legacy.high_protein_detail':
        'Ce repas contient environ {protein} g de proteines et peut entrer en concurrence avec {drug} pendant labsorption. Envisagez de programmer les repas plus proteines loin de la prise.',
    'legacy.tyramine': 'Risque possible daliments riches en tyramine',
    'legacy.tyramine_detail':
        'Ce repas comprend des aliments marques comme riches en tyramine. Avec {drug}, cela peut augmenter le risque deffets indesirables.',
    'legacy.mineral': 'Note de synchronisation pour les complements mineraux',
    'legacy.mineral_detail':
        'Ce repas comprend des produits laitiers et peut suggerer une teneur plus elevee en calcium. Certains complements mineraux peuvent avoir une absorption ou une tolerance digestive differentes avec les aliments.',
    'legacy.summary':
        'Score global {score}/100 ({severity}), avec {count} alertes possibles liees a lalimentation, au medicament ou a la nutrition.',
    'legacy.analysis':
        'Les regles integrees ont verifie ce repas par rapport a {drugCount} medicament(s) et ont produit un score heuristique de depistage de {score}/100.',
    'legacy.analysis_protein':
        'Lestimation actuelle du repas contient environ {protein} g de proteines.',
    'legacy.analysis_tyramine':
        'Ce repas contient aussi des aliments marques comme plus risques pour la tyramine dans le catalogue integre.',
    'legacy.analysis_followup':
        'Traitez ce resultat comme un depistage simplifie et confirmez lhoraire exact du medicament si vous avez besoin dun conseil plus precis.',
    'legacy.severity.high': 'Risque eleve',
    'legacy.severity.moderate': 'Risque modere',
    'legacy.severity.low': 'Risque faible',
    'recommend.low_protein': 'Option plus faible en proteines',
    'recommend.protein_window_caution':
        'Attention aux aliments plus proteines pres de la fenetre levodopa',
    'recommend.history_low_protein':
        'Lhistorique recent suggere de privilegier des options plus faibles en proteines',
    'recommend.culture_match':
        'Correspond au modele alimentaire regional actuel',
    'recommend.fallback_chain':
        'La base alimentaire de cette region utilise une chaine de secours',
    'recommend.general_friendly': 'Option generalement adaptee',
    'recommend.path.hybrid_local_ai': 'Reclassement assiste par IA locale',
    'recommend.path.conservative_safety_gate':
        'Chemin conservateur (IA bloquee par la porte de securite)',
    'recommend.path.conservative_gate_block':
        'Chemin conservateur (IA locale indisponible)',
    'recommend.path.fallback_invalid_ai':
        'Chemin conservateur (sortie IA invalide)',
    'recommend.path.conservative_cdss': 'Chemin CDSS conservateur',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'Aucun service Ollama ou llama.cpp localhost ne repond. Demarrez le modele local ou desactivez le reclassement IA local.',
    'recommend.runtime.endpoint_must_be_localhost':
        'L endpoint IA local doit rester sur localhost/127.0.0.1 et ne doit pas pointer vers le cloud.',
    'recommend.runtime.safety_gate_conservative':
        'La porte de securite maintient le resultat sur le chemin conservateur.',
    'recommend.runtime.next_meal_window_missing':
        'La fenetre prevue du prochain repas est manquante. Ajoutez l heure la plus tot et la plus tardive dans Ajouter/Modifier un repas.',
    'recommend.runtime.no_prior_meal_history':
        'Aucun repas precedent nest disponible pour un reclassement sur.',
    'recommend.runtime.legacy_meal_time':
        'Le dernier repas utilise encore une heure migree ; modifiez-la avec l heure reelle du repas.',
    'recommend.runtime.iron_conservative':
        'Le dernier repas contient un supplement en fer ; le reclassement reste conservateur.',
    'recommend.runtime.iron_multivitamin_conservative':
        'Le dernier repas contient une multivitamine avec fer ; le reclassement reste conservateur.',
    'recommend.runtime.starch_thickener_conservative':
        'Le dernier repas contient un epaississant a base d amidon ; la revue deterministe est conservee.',
    'recommend.runtime.enteral_conservative':
        'Une nutrition enterale continue est active ; la revue deterministe est conservee.',
    'recommend.runtime.local_ai_not_consented':
        'Le reclassement IA local na pas ete active par l utilisateur.',
    'recommend.runtime.local_ai_unavailable':
        'L endpoint IA local est actuellement indisponible.',
    'recommend.runtime.returned_conservative':
        'Les recommandations deterministes conservatrices ont ete retournees.',
    'recommend.runtime.ai_validation_failed':
        'La sortie structuree de l IA locale a echoue a la validation de la liste blanche.',
    'recommend.runtime.ai_invalid_whitelist':
        'L IA locale na pas retourne un ordre valide limite a la liste blanche ; le resultat nest donc pas utilise.',
    'recommend.runtime.cdss_conservative_observations':
        'Le chemin CDSS conservateur utilise les observations de variantes reelles quand elles sont disponibles.',
    'recommend.runtime.local_ai_success':
        'Le reclassement par IA locale a reussi.',
    'recommend.runtime.local_ai_copy_polish_success':
        'La reformulation par IA locale a reussi.',
    'recommend.runtime.medgemma_optional_unavailable':
        'L IA locale est disponible; le modele MedGemma optionnel est indisponible, donc l app revient au mode sur.',
    'recommend.runtime.recommendation_conservative':
        'La recommandation est restee sur le chemin conservateur.',
    'recommend.runtime.levodopa_ai_sensitive':
        'La fenetre horaire liee a la levodopa est trop sensible pour un reclassement IA.',
    'copy.deterministic_path': 'chemin fonde sur des regles',
    'copy.rerank': 'reclassement',
    'copy.cdss': 'aide a la decision clinique',
    'copy.official_label_meal_separation':
        'la notice officielle demande de separer ce medicament des repas',
    'copy.database_food_variants': 'variantes alimentaires de la base',
    'copy.database_nutrient_facts': 'faits nutritionnels de la base',
    'copy.missing_input_unknown': 'informations cles',
    'copy.interaction_summary_missing_inputs':
        'Le resultat est marque a risque eleve ({score}/100) car {missing} manque; lapp ne peut pas evaluer surement le timing repas-medicament.',
    'copy.interaction_summary_high':
        'Ce controle indique actuellement un risque eleve ({score}/100). Verifiez la raison et letape suivante.',
    'copy.interaction_analysis_missing_inputs':
        'Cela ne signifie pas que le repas est forcement dangereux. {missing} manque, donc la relation temporelle avec le medicament ne peut pas etre evaluee surement.',
    'copy.interaction_analysis_protein':
        'Les proteines estimees pour ce repas sont denviron {protein} g. Avec la levodopa, cette valeur compte pour le controle horaire.',
    'copy.interaction_analysis_fallback':
        'Certains aliments utilisent des donnees regionales de secours; la couverture locale faisant autorite reste incomplete.',
    'copy.interaction_analysis_database':
        'Quand disponibles, les valeurs nutritionnelles importees de la base ont ete utilisees.',
    'copy.interaction_analysis_not_diagnosis':
        'Considerez ceci comme un rappel de securite conservateur, pas comme un diagnostic.',
    'copy.key_finding_missing_inputs':
        'Le controle horaire ne peut pas etre termine : {missing} manque.',
    'copy.next_action_complete_med_timing':
        'Ajoutez dabord lheure et la dose du medicament, puis relancez le controle.',
    'copy.data_note_fallback':
        'Certains aliments utilisent temporairement des donnees de secours regionales.',
    'copy.data_note_database':
        'Le controle a utilise les donnees nutritionnelles reelles disponibles dans la base.',
    'copy.data_note_missing_input':
        'Labsence de {missing} rend les regles horaires plus conservatrices.',
    'copy.issue_missing_inputs':
        '{missing} manque; lapp ne peut donc pas juger surement si ce repas doit etre separe du medicament.',
    'recommend.context_iron_supplement':
        'Un supplement en fer a ete enregistre avec le dernier repas ; le conseil temporel reste donc conservateur.',
    'recommend.context_iron_multivitamin':
        'Une multivitamine avec fer a ete enregistree avec le dernier repas ; le conseil temporel reste donc conservateur.',
    'recommend.context_starch_thickener':
        'Un epaississant a base d amidon a ete enregistre, ce qui augmente la priorite de securite de deglutition.',
    'recommend.context_xanthan_thickener':
        'Un epaississant a base de xanthane a ete enregistre pour le dernier repas.',
    'recommend.context_enteral_feed_continuous':
        'La nutrition enterale continue est active ({protein} g/jour de proteines) ; la recommandation reste donc conservative.',
    'recommend.context_enteral_feed_bolus':
        'Une nutrition enterale bolus/intermittente a ete enregistree pour le dernier repas.',
    'recommend.context_iron_penalty':
        'Un coevenement lie au fer est present, donc les options plus riches en proteines restent classees plus prudemment.',
    'recommend.context_enteral_penalty':
        'Une nutrition enterale continue est presente, donc les options plus riches en proteines restent classees plus prudemment.',
    'recommend.context_texture_gap_penalty':
        'Un epaississant est enregistre, mais le catalogue ne contient pas encore de donnees structurees de compatibilite de texture ; une marge conservative supplementaire est conservee.',
    'recommend.context_texture_supported':
        'Un epaississant est enregistre, et ce candidat possede deja des metadonnees structurees de texture ; la penalite de manque de donnees reste donc plus faible.',
    'recommend.texture_profile_missing':
        'Une preference de texture de securite est active, mais ce candidat ne dispose pas de metadonnees structurees de texture ; le classement reste donc plus conservateur.',
    'recommend.texture_profile_supported_soft_or_liquid':
        'Ce candidat correspond a la preference actuelle de texture douce ou liquide.',
    'recommend.texture_profile_supported_liquid_only':
        'Ce candidat correspond a la preference actuelle de texture liquide uniquement.',
    'recommend.texture_profile_incompatible':
        'Ce candidat ne correspond pas a la preference actuelle de texture de securite ; il est donc classe plus prudemment.',
    'recommend.texture_template_supported':
        'Ce candidat correspond a la direction de texture du modele de repas actuel.',
    'recommend.texture_template_mismatch':
        'Ce candidat ne correspond pas a la direction de texture du modele de repas actuel.',
    'recommend.local_seed_metadata':
        'Ce candidat depend encore des metadonnees locales de base plutot que dobservations plus completes en base.',
    'recommend.timing_window_incomplete':
        'La fenetre horaire est incomplete ; le classement conservateur garde donc une marge de securite supplementaire.',
    'recommend.next_meal_gap_close':
        'La fenetre du prochain repas reste proche du repas precedent ; une option plus faible en proteines est preferee.',
    'recommend.next_meal_window_fiber':
        'Ce candidat correspond a la fenetre prevue du prochain repas et favorise un apport en fibres plus regulier.',
    'recommend.medication_timing_caution':
        'Lhoraire du medicament suggere une prudence supplementaire pour cette fenetre de prochain repas.',
    'texture_mode.unrestricted': 'Sans restriction',
    'texture_mode.soft_or_liquid': 'Texture douce ou liquide',
    'texture_mode.liquid_only': 'Liquide uniquement',
    'texture_class.liquid': 'Liquide',
    'texture_class.soft': 'Douce',
    'texture_class.regular': 'Standard',
    'food.food_chicken_breast': 'Blanc de poulet (cuit)',
    'food.food_tofu': 'Tofu nature',
    'food.food_brown_rice': 'Riz complet',
    'food.food_banana': 'Banane',
    'food.food_spinach': 'Epinards',
    'food.food_milk': 'Lait demi-ecreme',
    'food.food_beef': 'Boeuf maigre (poele)',
    'food.food_apple': 'Pomme (avec peau)',
    'food.food_blueberry': 'Myrtille',
    'food.food_tomato': 'Tomate',
    'food.food_broccoli': 'Brocoli',
    'food.food_oats': 'Flocons d avoine',
    'food.food_salmon': 'Saumon (elevage, cuit au four)',
    'food.food_fava_beans': 'Feves fraiches',
    'food.food_potato_boiled': 'Pomme de terre (bouillie)',
    'food.food_walnuts': 'Noix',
    'food.food_olive_oil': "Huile d'olive vierge extra",
    'food.food_cheddar_cheese': 'Cheddar',
    'food.food_egg_boiled': 'Oeuf (bouilli)',
    'food.food_coffee': 'Cafe filtre sans sucre',
    'medication_note.drug_levodopa_carbidopa':
        'Association frequente pour la maladie de Parkinson. Certains patients remarquent des fluctuations apres un repas riche en proteines.',
    'medication_note.drug_entacapone':
        'Inhibiteur de la COMT, souvent utilise avec la levodopa.',
    'medication_note.drug_opicapone':
        'Inhibiteur de la COMT une fois par jour, utilise en adjonction a la levodopa/carbidopa pour les episodes OFF.',
    'medication_note.drug_tolcapone':
        'Inhibiteur de la COMT avec contexte de surveillance hepatique. Le moment du repas est souvent secondaire par rapport au suivi de securite.',
    'medication_note.drug_rasagiline':
        'Inhibiteur de la MAO-B. Une restriction generale en tyramine nest pas habituellement necessaire, mais les charges tres elevees en tyramine restent importantes.',
    'medication_note.drug_safinamide':
        'Inhibiteur MAO-B adjuvant utilise avec levodopa/carbidopa. Une charge tres elevee en tyramine reste un point de prudence.',
    'medication_note.drug_selegiline':
        'Inhibiteur de la MAO-B. La regle sur la tyramine elevee reste ici une base provisoire.',
    'medication_note.drug_iron':
        'Complement mineral. Le moment de prise avec le repas peut influencer la tolerance et labsorption.',
    'medication_note.drug_pramipexole':
        'Agoniste dopaminergique. Les conflits alimentaires sont en general moins importants que la sedation, lhypotension orthostatique et le controle des impulsions.',
    'medication_note.drug_ropinirole':
        'Agoniste dopaminergique utilise seul ou en adjonction. Le moteur actuel na pas de blocage alimentaire majeur pour ce medicament.',
    'medication_note.drug_rotigotine':
        'Agoniste dopaminergique transdermique. Le moment des repas est moins central car la voie digestive est contournee.',
    'medication_note.drug_apomorphine':
        'Traitement de secours ou de phases OFF avancees selon la formulation. Le contexte de voie dadministration compte plus que le repas.',
    'medication_note.drug_amantadine':
        'Utilisee selon la formulation pour les symptomes parkinsoniens ou les dyskinesies. Les conflits alimentaires ne sont pas la cible principale actuelle.',
    'medication_note.drug_istradefylline':
        'Traitement adjuvant des episodes OFF. Inclus pour sa pertinence PD meme si les regles alimentaires actuelles sont limitees.',
    'medication_note.drug_pimavanserin':
        'Traitement de la psychose de la maladie de Parkinson. Inclus pour la prise en charge globale plutot que pour une regle alimentaire directe.',
    'medication_note.drug_rivastigmine':
        'Utilisee dans la demence liee a la maladie de Parkinson. Les formes orales sont souvent prises avec les repas pour la tolerance; le patch change le contexte digestif.',
    'medication_note.drug_droxidopa':
        "Utilisee pour l'hypotension orthostatique neurogene. Une prise dans un etat alimentaire coherent peut compter cliniquement.",
    'medication_note.drug_midodrine':
        'Utilisee pour lhypotension orthostatique. Le moment du repas est moins central que lhoraire de jour et la surveillance tensionnelle.',
    'medication_note.drug_peg_3350':
        'Laxatif osmotique. La regle dure actuelle concerne surtout lincompatibilite avec certains epaississants a base damidon.',
    'medication_note.drug_levodopa_entacapone':
        'Association fixe contenant de la levodopa. Appliquer la meme prudence sur proteines elevees et separation du fer que pour les autres produits a base de levodopa.',
    'medication_note.drug_levodopa_benserazide':
        'Association a base de levodopa utilisee hors des Etats-Unis. Appliquer la meme prudence de timing proteique et de separation du fer.',
  },
  'ja': {
    'app.welcome': 'ようこそ',
    'app.loading': '読み込み中...',
    'history.title': '復元可能な記録履歴',
    'history.subtitle': '食事・服薬記録の作成、編集、削除、復元は、不変リビジョンとともに原子的に保存されます。',
    'history.conflict_help':
        '現在の記録がそのリビジョンの結果と完全に一致する場合にのみ復元できます。新しい変更を暗黙に上書きしません。',
    'history.filter_all': 'すべて',
    'history.meal': '食事',
    'history.intake': '服薬記録',
    'history.empty': '復元可能なリビジョンはまだありません。今後の作成、編集、削除がここに表示されます。',
    'history.event_create': '作成',
    'history.event_update': '編集',
    'history.event_delete': '削除',
    'history.event_restore': '復元',
    'history.restore': '以前の状態を復元',
    'history.restore_unavailable': '新しい変更があるため上書き不可',
    'history.restored': '以前の状態を新しいリビジョンとして復元しました。',
    'history.restore_conflict': '現在の記録が変更されています。新しいデータを保護するため復元しませんでした。',
    'history.deleted_undo': '記録を削除しました。',
    'history.undo': '元に戻す',
    'history.restored_refresh_incomplete':
        '以前の状態は永続的に復元されましたが、一部の派生ビューを更新できませんでした。記録自体はロールバックされていません。',
    'history.restore_blocked': '関係または整合性チェックに合格しなかったため、復元は実行されませんでした。',
    'history.preview_title': '復元影響プレビュー',
    'history.preview_semantics': '復元前の読み取り専用影響プレビューと確認',
    'history.preview_exact_write': '正確な記録変更',
    'history.preview_target_restore': '選択したリビジョンの直前とバイト等価な状態にこの記録を戻します。',
    'history.preview_target_remove':
        '選択したリビジョン以前にはこの記録が存在しません。確認すると現在の記録が削除されます。',
    'history.preview_relationships_title': 'カタログ関係の変更',
    'history.preview_relationships_body':
        '復元後は {count} 件の関係が残り、{added} 件が追加、{removed} 件が削除されます。',
    'history.preview_derived_title': '派生結果を再生成',
    'history.preview_derived_body':
        '食事チェック、推奨説明、機序トレース、引き継ぎ要約、ポータブルパッケージ関係を無効化し、現在のアルゴリズムで再計算します。古いアルゴリズム結果を現在の結果として扱いません。',
    'history.preview_evidence_title': '履歴証拠は不変のまま',
    'history.preview_evidence_body': '選択したリビジョンは書き換えません。この復元を新しいリビジョンとして追加します。',
    'history.preview_identity_title': '結び付けられた計算アイデンティティ',
    'history.preview_identity_body': 'アルゴリズム {algorithm} · 関係グラフ {graph}',
    'history.preview_missing_title': '未解決の関係',
    'history.preview_missing_body':
        '現在のカタログに {ids} がありません。不完全な派生結果を避けるため、復元は無効のままです。',
    'history.preview_status_ready': 'チェックに合格しました。復元を確認できます。',
    'history.preview_status_stale': '記録が変更されました。このプレビューを閉じて再生成してください。',
    'history.preview_status_account': 'アカウント範囲を利用できないため、復元は無効のままです。',
    'history.preview_status_relationships': '未解決のカタログ関係があるため、復元は無効のままです。',
    'history.preview_status_integrity': 'プレビューの整合性チェックに失敗したため、復元は無効のままです。',
    'history.preview_cancel': 'キャンセル',
    'history.preview_confirm': '確認して復元',
    'onboarding.title': 'ParkinSUM Companion（ローカル版）',
    'onboarding.description':
        'このアプリは食事記録とルールベースの注意表示のためのものです。医師や薬剤師の助言の代わりにはなりません。',
    'onboarding.registration_region': '登録地域',
    'onboarding.registration_region_help': '既定の管轄チェーンと参照元の優先順位を決めます。',
    'onboarding.display_language': '表示言語',
    'onboarding.display_language_help': 'アプリの言語、日付、数値表示に反映されます。',
    'onboarding.diet_profile_region': '食事プロファイル地域',
    'onboarding.diet_profile_region_help': '既定の食事テンプレートに使われますが、安全ルールは上書きしません。',
    'onboarding.swallowing_texture_mode': '嚥下/食形態の安全モード',
    'onboarding.swallowing_texture_mode_help':
        '推薦の保守的な並べ替えに使われます。臨床的な嚥下評価の代替ではありません。',
    'onboarding.content_override': '内容の管轄上書き（任意）',
    'onboarding.content_override_help': 'US,CA のようにカンマ区切りで入力します',
    'onboarding.local_ai_consent': 'ローカル AI 並べ替えを有効化（任意）',
    'onboarding.local_ai_consent_help':
        'localhost の Ollama/llama.cpp のみを使い、安全ゲートに止められた場合は保守経路へ戻ります。',
    'onboarding.start': '内容を理解して続行',
    'region.CN': '中国',
    'region.US': '米国',
    'region.CA': 'カナダ',
    'region.FR': 'フランス',
    'region.JP': '日本',
    'region.KR': '韓国',
    'region.IN': 'インド',
    'region.ES': 'スペイン',
    'region.MX': 'メキシコ',
    'region.VN': 'ベトナム',
    'region.TH': 'タイ',
    'region.ID': 'インドネシア',
    'region.RU': 'ロシア',
    'region.PL': 'ポーランド',
    'region.SA': 'サウジアラビア',
    'nav.home': 'ホーム',
    'nav.analytics': '分析',
    'nav.meals': '食事',
    'nav.timeline': 'タイムライン',
    'nav.meds': '薬',
    'nav.catalog': 'カタログ',
    'nav.next_meal': '次の食事',
    'next_meal.title': '次の食事のおすすめ',
    'next_meal.subtitle':
        '次に食べる予定時刻を選んでください。保守的なルール経路は候補順を維持し、機序モデルは教育用の時間重なりトレースだけを追加して並べ替えません。ローカル AI は別系統の任意の安全リスト内再ランクです。',
    'next_meal.input_time': '次の食事の予定時刻',
    'next_meal.use_local_ai': 'ローカル AI で表現を磨く（任意）',
    'next_meal.use_local_ai_help':
        'localhost の Ollama/llama.cpp だけを呼び出し、エンジンが既に通した候補の再並べ替えと説明文の書き直しを行います。安全ゲートがブロックした場合は保守経路に自動で戻ります。',
    'next_meal.generate': 'おすすめを生成',
    'next_meal.window_title': '利用者が指定する食事時間枠（分）',
    'next_meal.window_help':
        '時間枠は利用者が設定し、教育用の機序トレースにだけ使われます。モデルは食事時刻を決めず、保守的な推薦順も変更しません。',
    'next_meal.window_none': 'なし',
    'next_meal.window_minutes': '{minutes} 分',
    'next_meal.generating': '生成中…',
    'next_meal.empty': '予定時刻を設定して「おすすめを生成」をタップすると、その時間枠で再評価されます。',
    'next_meal.why_these': 'この選び方の理由',
    'next_meal.ai_polished': 'ローカル AI が文章を磨きました',
    'next_meal.conservative_engine': 'コンフリクトエンジンの保守経路',
    'next_meal.recommendation_path': '推奨経路',
    'next_meal.gate_reasons': '安全ゲートのメモ',
    'next_meal.candidates': '上位候補',
    'next_meal.no_candidates': '現在の条件では適切な候補がありません。予定時刻を調整するか、食事目録を見直してください。',
    'next_meal.error': '生成に失敗しました',
    'dashboard.title': 'ダッシュボード',
    'dashboard.status': '概要',
    'dashboard.logged_meals': '記録済み食事: {count}',
    'dashboard.active_drugs': '有効な薬: {count}',
    'dashboard.logged_intakes': '服薬記録: {count}',
    'dashboard.recommendations': '推奨',
    'dashboard.no_recommendations': 'まだ推奨はありません',
    'dashboard.recommendation_path': '推薦経路',
    'dashboard.recommendation_template':
        '現在のテンプレート：{region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'ローカル AI 強化を使用',
    'dashboard.ai_not_used': '保守経路のみ',
    'dashboard.recommendation_why': '推薦理由',
    'dashboard.recommendation_gate': 'AI / 安全ゲート状態',
    'dashboard.recommendation_macro_line':
        '100g当たり: たんぱく質 {protein} g · 炭水化物 {carbs} g · 脂質 {fat} g',
    'dashboard.recommendation_score_line':
        '安全 {safety} · 時系列 {schedule} · データ {facts} · 文脈ペナルティ {context} · 時間窓ペナルティ {timing} · 嚥下ペナルティ {swallowing} · テンプレート一致 {template}',
    'dashboard.recent_meals': '最近の食事（最新5件）',
    'dashboard.no_meals': '食事記録はまだありません',
    'dashboard.items': '{count} 件',
    'dashboard.meal_context_iron_supplement': '鉄剤の共イベント',
    'dashboard.meal_context_iron_multivitamin': '鉄入り複合ビタミンの共イベント',
    'dashboard.meal_context_starch_thickener': 'デンプン系増粘剤',
    'dashboard.meal_context_xanthan_thickener': 'キサンタン系増粘剤',
    'dashboard.meal_context_enteral_feed_continuous':
        '持続経腸栄養（タンパク質 {protein} g/日）',
    'dashboard.meal_context_enteral_feed_bolus': 'ボーラス/間欠経腸栄養',
    'dashboard.edit': '編集',
    'dashboard.delete': '削除',
    'dashboard.protein_trend': 'たんぱく質推移',
    'dashboard.average_protein': '平均たんぱく質: {value} g / 食事',
    'dashboard.no_trend': '推移データはまだありません',
    'dashboard.timeline': 'タイムライン',
    'dashboard.no_timeline': '食事または服薬イベントはまだありません',
    'dashboard.add_meal': '食事を追加',
    'dashboard.meal_check': '食事チェック - {title}',
    'common.close': '閉じる',
    'common.done': '完了',
    'common.cancel': 'キャンセル',
    'common.apply': '適用',
    'common.optional': '任意',
    'common.delete': '削除',
    'common.edit': '編集',
    'auth.account_title': 'ParkinSUM アカウント',
    'auth.create_account': 'アカウントを作成',
    'auth.sign_in': 'ログイン',
    'auth.email': 'メールアドレス',
    'auth.password': 'パスワード',
    'auth.invalid_email': '有効なメールアドレスを入力してください。',
    'auth.password_required': 'パスワードを入力してください。',
    'auth.password_registration_requirement': '新しいパスワードは {minimum} 文字以上必要です。',
    'auth.register': '登録',
    'auth.have_account': 'アカウントをお持ちですか？ログイン',
    'auth.need_account': 'アカウントが必要ですか？登録',
    'auth.forgot_password': 'パスワードをお忘れですか？',
    'auth.privacy': 'プライバシーと免責事項',
    'auth.reset_neutral': '該当するアカウントがある場合、パスワード再設定メールを送信しました。',
    'auth.show_password': 'パスワードを表示',
    'auth.hide_password': 'パスワードを隠す',
    'reminders.title': '記録リマインダー',
    'reminders.add': 'リマインダーを追加',
    'reminders.edit': 'リマインダーを編集',
    'reminders.resynchronize': '予定リクエストを再送信',
    'reminders.synchronized': '予定リクエストが完了しました',
    'reminders.last_sync': '最終リクエスト完了：{time}',
    'reminders.schedule_capacity_title': 'ParkinSUM の予定安全上限',
    'reminders.schedule_capacity_body':
        'ParkinSUM の予定要求：{projected}/{limit}、アプリ安全余量：{headroom}。これは保守的な製品上限で、端末の空きシステム容量ではありません。有効な曜日ごとに1件を使用します。',
    'reminders.schedule_capacity_invalid':
        'この予定は送信できません（{projected}/{limit}）。ParkinSUM の安全上限、識別子、または予定形式が無効です。既存の予定は変更されていません。',
    'reminders.identity_attestation_title': 'プラグインの保留中リクエスト識別情報の照合',
    'reminders.identity_attestation_matched':
        'プラグインが報告した保留中の識別情報は予定と一致しています（{installed}/{planned}）。これは OS スケジューラや画面に表示される配信を独立に検証したものではありません。',
    'reminders.identity_attestation_drift':
        'プラグインが報告した識別情報は予定と一致しません。不足 {missing} 件、余分 {extra} 件、予定済み識別子で置換 {replaced} 件です。再同期が成功するまでシステム通知に依存しないでください。',
    'reminders.identity_attestation_uninspectable':
        'プラグインから保留中リクエストの識別情報を読み取れませんでした。ローカル予定を正としますが、システム通知の状態は未確認です。',
    'reminders.delete_title': 'このリマインダーを削除しますか？',
    'reminders.delete_body': '「{label}」をこの端末から削除し、対応するシステム通知をキャンセルします。',
    'reminders.boundary_title': '記録の促しのみ',
    'reminders.boundary_body':
        '時刻と文面は利用者が設定します。ParkinSUM は服薬時刻を計算・推奨・処方しません。医療者と薬剤ラベルの指示に従ってください。',
    'reminders.web_title': 'この環境では定期システム通知を利用できません',
    'reminders.web_body':
        '予定はこの端末に保存されますが、Web 版、Windows 版、Linux 版ではアプリ終了中の定期通知を現在配信できません。',
    'reminders.empty_title': '記録リマインダーはまだありません',
    'reminders.empty_body': '食事または服薬の記録を促す文面と時刻を自分で設定できます。',
    'reminders.kind': '記録の種類',
    'reminders.kind_mealLog': '食事記録',
    'reminders.kind_intakeLog': '服薬記録',
    'reminders.label': 'リマインダー文',
    'reminders.label_help': '用量や処方の指示ではなく、記録を促す文面を入力してください。',
    'reminders.privacy': '通知のプライバシー',
    'reminders.privacy_help': 'システムに表示する文面だけを制御します。入力した文面は ParkinSUM 内に残ります。',
    'reminders.privacy_minimal': '最小限（既定）',
    'reminders.privacy_generic': '一般的な記録の促し',
    'reminders.privacy_preview': 'システム通知のプレビュー',
    'reminders.privacy_minimal_boundary':
        'Android では安全なロック画面に通知内容を表示しないよう要求します。Apple プラットフォームでは利用者のシステムプレビュー設定に従います。',
    'reminders.privacy_generic_boundary':
        'Android ではロック画面に基本情報だけを表示するよう要求します。Apple プラットフォームでは利用者のシステムプレビュー設定に従います。',
    'reminders.days': '繰り返す曜日',
    'reminders.next': '次回',
    'reminders.validation': '文面を入力し、曜日を1つ以上選択してください。',
    'reminders.error_load_failed': '保存済みのリマインダーを読み込めませんでした。',
    'reminders.error_permission_denied': '通知権限が無効なため、リマインダーを有効にできませんでした。',
    'reminders.error_schedule_failed':
        'システム通知の再同期に失敗しました。既存のローカル予定を正として、次回の起動または再開時に再試行します。',
    'reminders.error_recovery_required':
        '端末上のリマインダー状態を確認できませんでした。既存のローカル予定を正として、予定リクエストを再送信し、確認できるまではシステム通知に依存しないでください。',
    'reminders.error_schedule_invalid':
        'ParkinSUM の安全上限、識別子、または予定形式が無効なため、新しい予定は保存されませんでした。',
    'reminders.error_schedule_identity_unverified':
        'ローカル予定は保存されましたが、プラグインが報告した保留中の識別情報を予定と照合できませんでした。システム通知に依存する前に再同期してください。',
    'reminders.error_save_failed': 'リマインダーを保存できませんでした。もう一度お試しください。',
    'reminders.explicit_medication_selection':
        '実際に服用した薬を明示的に選択してください。この下書きを開くだけでは服薬記録は作成されません。',
    'reminders.response_unavailable':
        'このリマインダーは無効か、現在のアカウントのものではありません。記録は作成されませんでした。',
    'reminders.response_replayed': '重複したリマインダー操作を無視しました。記録は作成されませんでした。',
    'reminders.day_1': '月',
    'reminders.day_2': '火',
    'reminders.day_3': '水',
    'reminders.day_4': '木',
    'reminders.day_5': '金',
    'reminders.day_6': '土',
    'reminders.day_7': '日',
    'common.completed': '完了',
    'common.error': 'エラー',
    'common.search_results': '検索結果',
    'common.no_matching_foods': '一致する食品がありません',
    'common.texture': '食形態',
    'meal_slot.breakfast': '朝食',
    'meal_slot.lunch': '昼食',
    'meal_slot.dinner': '夕食',
    'meal_slot.snack': '間食',
    'entry.new_title': '新しい食事記録',
    'entry.edit_title': '食事を編集',
    'entry.default_meal_title': 'マイミール',
    'entry.meal_title': '食事タイトル',
    'entry.search_food': '追加する食品を検索',
    'entry.view_food_detail': '食品詳細を見る',
    'entry.add_food': '食品を追加',
    'entry.actual_meal_time': '実際の食事時刻',
    'entry.recorded_time_hint': '記録時刻: {value}',
    'entry.actual_time_value': '実際の摂食時刻: {value}',
    'entry.edit_actual_time': '食事時刻を編集',
    'entry.time_uncertain': '時刻があいまい',
    'entry.actual_window_value': '想定食事ウィンドウ: {start} - {end}',
    'entry.edit_actual_window': '食事ウィンドウを編集',
    'entry.next_meal_window': '次の食事予定ウィンドウ',
    'entry.next_meal_window_empty': '次の食事ウィンドウはまだ未入力です',
    'entry.next_meal_window_value': '次の食事ウィンドウ: {start} - {end}',
    'entry.edit_next_meal_window': '次の食事ウィンドウを編集',
    'entry.clear_next_meal_window': '次の食事ウィンドウを消去',
    'entry.supplement_context': 'サプリメント / 共イベント情報',
    'entry.with_iron_supplement': 'この食事と同時に鉄剤を服用',
    'entry.with_iron_multivitamin': 'この食事と同時に鉄入り複合ビタミンを服用',
    'entry.thickener_type': '増粘剤タイプ',
    'entry.thickener_starch_based': 'デンプン系',
    'entry.thickener_xanthan_based': 'キサンタン系',
    'entry.coevent_time_empty': '共イベント時刻は未入力です。既定ではこの食事時刻を使用します。',
    'entry.coevent_time_value': '共イベント時刻: {value}',
    'entry.edit_coevent_time': '共イベント時刻を編集',
    'entry.enteral_feed_context': '経腸栄養コンテキスト',
    'entry.enteral_feed_continuous': '持続投与',
    'entry.enteral_feed_bolus': 'ボーラス / 間欠投与',
    'entry.enteral_feed_formula': '経腸栄養の処方メモ',
    'entry.enteral_feed_protein_g_per_day': '経腸栄養タンパク質 (g/日)',
    'entry.none': 'なし',
    'entry.summary': '現在の食事サマリー',
    'entry.no_foods_yet': 'まだ食品が追加されていません',
    'entry.per_100g': '100gあたり: P {protein}g - C {carbs}g',
    'entry.added_foods': '追加済み食品',
    'entry.add_food_prompt': 'まず上の検索結果から食品を追加してください',
    'entry.grams': 'グラム数',
    'entry.protein': 'たんぱく質',
    'entry.carbs': '炭水化物',
    'entry.quantity_factor': '分量係数: {value} x 100g',
    'entry.set_quantity': '分量を設定',
    'entry.saving': '保存中...',
    'entry.save_new': '食事を保存して競合チェック',
    'entry.save_edit': '変更を保存して競合チェック',
    'entry.add_food_first': '先に食品を追加してください',
    'entry.food_added': '{name} を追加しました',
    'entry.saved_title': '食事を保存してチェックしました',
    'entry.updated_title': '食事を更新してチェックしました',
    'entry.save_failed': '保存に失敗しました: {error}',
    'entry.adjust_quantity': '分量を調整 - {name}',
    'meal.title': '食事',
    'meal.empty': '食事記録はまだありません',
    'meal.check_title': '食事チェック - {title}',
    'medications.title': '薬',
    'analytics.title': '分析',
    'analytics.localization': 'ローカライズ状態',
    'analytics.localization_language': '現在の表示言語: {value}',
    'analytics.localization_region': '現在の登録地域: {value}',
    'analytics.localization_timezone': '現在のタイムゾーン: {value}',
    'analytics.localization_override': 'コンテンツ管轄 override: {value}',
    'analytics.localization_override_none': '未設定',
    'analytics.localization_texture_mode': '現在の食形態安全モード: {value}',
    'analytics.localization_help':
        '登録時に言語や地域を切り替えると、アプリは有効な locale で画面を再構築し、その設定をここに表示します。',
    'analytics.local_ai': 'ローカル AI',
    'analytics.local_ai_enable': 'ローカル AI 並べ替えを有効化',
    'analytics.local_ai_help': 'AI は安全候補だけを並べ替え、安全ゲートにより無効化されることがあります。',
    'analytics.local_ai_provider': 'ローカル AI プロバイダー',
    'analytics.local_ai_provider_auto': '自動（Ollama 優先）',
    'analytics.local_ai_provider_ollama': 'Ollama',
    'analytics.local_ai_provider_openai': 'llama.cpp / OpenAI 互換',
    'analytics.local_ai_model': 'モデル名',
    'analytics.local_ai_medical_model': '医療レビュー用モデル名',
    'analytics.local_ai_ollama_endpoint': 'Ollama エンドポイント',
    'analytics.local_ai_openai_endpoint': 'OpenAI 互換エンドポイント',
    'analytics.local_ai_timeout_ms': 'タイムアウト（ms）',
    'analytics.local_ai_check': 'ローカル AI を確認',
    'analytics.local_ai_status_available': 'ローカル AI 利用可能',
    'analytics.local_ai_status_unavailable': 'ローカル AI 利用不可',
    'analytics.recommendation_path': '現在の推薦経路',
    'analytics.recommendation_explanations': '現在の推薦説明',
    'analytics.recommendation_gate_reasons': '現在の安全ゲート理由',
    'analytics.import_tools': 'P0 取込ツール',
    'analytics.import_tools_help':
        'ローカルディスク上の公式 ZIP/XML パッケージを staging/promoted CDSS スナップショットへ取り込みます。',
    'analytics.open_import_tools': '取込ツールを開く',
    'analytics.replay_benchmark': '推薦リプレイベンチマーク',
    'analytics.replay_benchmark_help':
        '同じシナリオを deterministic と AI rerank で実行し、ゲート理由と順位差分レポートを表示します。',
    'analytics.replay_run': 'リプレイベンチマークを実行',
    'analytics.replay_running': 'リプレイベンチマークを実行中',
    'analytics.replay_last_report': '最新のリプレイレポート',
    'analytics.replay_cases': 'ケース数: {count}',
    'analytics.replay_report_error': 'リプレイ実行失敗: {error}',
    'import.title': 'ローカル P0 取込',
    'import.description':
        '各公式ソースの ZIP ファイルパスまたはディレクトリパスを入力してください。Ciqual は XML 一式を含むディレクトリでも取り込めます。',
    'import.remote_tasks': 'リモート公式取込タスク',
    'import.ema_medicines': 'EMA medicines メタデータ',
    'import.ema_post_authorisation': 'EMA post-authorisation メタデータ',
    'import.china_official_foods': '中国公式食品ページ群',
    'import.run': '取込タスクを実行',
    'import.retry': '前回タスクを再実行',
    'import.retry_source': 'このソースを再実行',
    'import.last_result': '前回の取込結果',
    'import.step_status_ok': '成功',
    'import.step_status_failed': '失敗',
    'import.run_id': 'Run ID',
    'import.snapshot': 'スナップショット',
    'import.source_documents': 'ソース文書',
    'import.food_variants': '食品バリアント',
    'import.drug_variants': '薬品バリアント',
    'import.observations': '観測値',
    'import.drilldown_runs': 'Run 詳細',
    'import.drilldown_source_docs': 'ソース文書詳細',
    'import.stage': '段階',
    'import.status': '状態',
    'import.doc_type': '文書種別',
    'import.data_tier': 'データ階層',
    'import.ingestion_strategy': '取込戦略',
    'import.source_status': 'ソース状態',
    'import.origin_url': '元 URL',
    'import.ciqual_path': 'Ciqual XML ディレクトリ / ZIP',
    'import.fdc_path': 'FDC ZIP / ディレクトリ',
    'import.dailymed_path': 'DailyMed ZIP / ディレクトリ',
    'import.dpd_path': 'Health Canada DPD ZIP / ディレクトリ',
    'import.running': '取込タスクを実行中です。大きな ZIP パッケージでは時間がかかることがあります。',
    'import.ops_title': 'CDSS 公開と配布',
    'import.ops_help':
        'スナップショットをローカル安定チャネルへ公開し、バックエンド連携用 bundle を書き出し、ここで rollback / 配布履歴を確認します。',
    'import.snapshot_registry': 'スナップショット一覧',
    'import.snapshot_status_staging': 'staging',
    'import.snapshot_status_promoted': 'promoted',
    'import.fact_count': '解決済み fact 数',
    'import.rules_version': 'ルール版',
    'import.release_readiness': '公開準備状態',
    'import.release_ready': '公開可能',
    'import.release_blocked': 'ブロック',
    'import.label_sections': 'ラベル本文セクション',
    'import.blocking_issues': 'ブロック理由',
    'import.warnings': '警告',
    'import.rollback_parent': 'rollback 元',
    'import.publish': '公開',
    'import.export_bundle': 'bundle を書き出す',
    'import.snapshot_bundle_path': 'snapshot bundle のパス',
    'import.import_bundle': 'bundle を取り込む',
    'import.rollback': 'この snapshot に rollback',
    'import.monitoring': '取込監視',
    'import.total_runs': '累計 run 数',
    'import.distribution_history': '配布履歴',
    'import.channel': 'チャネル',
    'import.artifact_path': '成果物パス',
    'analytics.protein_trend': 'たんぱく質推移',
    'analytics.average_protein': '食事あたり平均たんぱく質: {value} g',
    'analytics.no_trend': '推移データはまだありません',
    'catalog.title': 'カタログ',
    'catalog.search': '食品または薬を検索',
    'catalog.foods': '食品',
    'catalog.drugs': '薬',
    'catalog.food_subtitle':
        'カテゴリ={category}  P/C/F={protein}/{carbs}/{fat}（100gあたり）',
    'catalog.drug_subtitle': 'タグ={tags}',
    'catalog.view_detail': '詳細を見る',
    'settings.title': '設定・機能センター',
    'settings.profile': '登録プロフィールと安全設定',
    'settings.capabilities': 'すべての機能への入口',
    'settings.queue': '完全版アップグレードキュー',
    'settings.queue_help': 'このキューは実装済み作業、研究、外部検証を区別します。臨床的妥当性や規制承認を意味しません。',
    'settings.saved': 'プロフィールを保存しました。',
    'settings.saved_refresh_pending':
        'プロフィールは保存されましたが、派生する推奨の更新に失敗しました。後でもう一度お試しください。',
    'settings.save_failed': '保存に失敗しました。最後に保存されたプロフィールを維持します：{error}',
    'settings.account': 'アカウントとデータ境界',
    'settings.local_mode': 'ローカルモード：データはこの端末のアプリ内ストレージに保存されます。',
    'settings.open': '開く',
    'settings.reviewed': '研究レビュー日：{date}',
    'settings.score': '優先度スコア {score}',
    'settings.email_verified': 'メール確認済み',
    'settings.email_unverified': 'メール未確認',
    'settings.send_verification': '確認メールを送信',
    'settings.refresh_verification': '確認状態を更新',
    'settings.verification_sent': '確認メールを送信しました。受信箱で確認を完了してください。',
    'settings.verification_refreshed': '確認状態を更新しました。',
    'settings.auth_action_failed': 'アカウント操作に失敗しました：{error}',
    'settings.change_password': 'パスワードを変更',
    'settings.change_password_title': '再認証してパスワードを変更',
    'settings.current_password': '現在のパスワード',
    'settings.new_password': '新しいパスワード',
    'settings.confirm_password': '新しいパスワードを再入力',
    'settings.password_requirement':
        '15文字以上のパスフレーズを使用してください。空白やUnicode文字を使用でき、大文字・数字・記号の組み合わせは強制しません。',
    'settings.password_current_required': '現在のパスワードを入力してください。',
    'settings.password_too_short': '新しいパスワードは {minimum} 文字以上必要です。',
    'settings.password_must_differ': '新しいパスワードは現在のものと異なる必要があります。',
    'settings.password_confirmation_mismatch': '新しいパスワードが一致しません。',
    'settings.show_passwords': 'パスワードを表示',
    'settings.hide_passwords': 'パスワードを隠す',
    'settings.password_changed': 'パスワードを更新しました。',
    'settings.password_error_wrong_current': '現在のパスワードが正しくありません。もう一度入力してください。',
    'settings.password_error_weak':
        '認証サービスがこのパスワードを受け付けませんでした。より長く一般的でないパスフレーズを使用してください。',
    'settings.password_error_too_many': '試行回数が多すぎます。時間を置いて再試行してください。',
    'settings.password_error_recent_login':
        'ログイン確認の期限が切れました。再度ログインしてからお試しください。',
    'settings.password_error_service': 'アカウントサービスを一時的に利用できません。後でもう一度お試しください。',
    'settings.password_provider_unavailable':
        'このアカウントはパスワードログインに連携されていないため、ここでは変更できません。',
    'settings.password_error_not_signed_in': 'ログアウトしています。再度ログインしてからお試しください。',
    'settings.password_error_unknown':
        'パスワードを変更できませんでした。変更は行われていません。後でもう一度お試しください。',
    'settings.data_integrity': 'データ完全性',
    'settings.data_import': 'データ取込',
    'privacy.title': 'プライバシーと免責事項',
    'diagnostics.title': 'エンジニアリング診断',
    'diagnostics.rerun': '再実行',
    'diagnostics.scope_title': 'エンジニアリング確認専用',
    'diagnostics.scope_body':
        'これらは決定論的なガバナンス検査（文言のコンパイル、ローカライズ安全検査、合成シナリオの再生）です。エンジニアリング上の状態のみを示し、スコア・重大度・根拠・ルール結果を変更しません。健康に関する助言でもありません。合成/デモデータのみを使用します。',
    'diagnostics.elapsed': '検査は {ms} ミリ秒で完了しました。',
    'catalog.selected_active': '服用中の薬として選択済み',
    'medications.view_detail': '薬の詳細を見る',
    'detail.variant_source': 'バリアント / ソース',
    'detail.imported_nutrients': '取込済み栄養値',
    'detail.no_imported_nutrients': '取込済み栄養行は見つかりませんでした。',
    'detail.product_code': '製品コード',
    'detail.packaging': '包装',
    'detail.imported_label_facts': '取込済みラベル事実',
    'detail.imported_label_sections': '取込済みラベルセクション',
    'detail.no_imported_label_sections': '取込済みラベルセクションは見つかりませんでした。',
    'detail.media_links': 'メディア / PDF リンク',
    'detail.macro_summary':
        '100g当たり: たんぱく質 {protein} · 炭水化物 {carbs} · 脂質 {fat} · 食物繊維 {fiber} · ナトリウム {sodium}',
    'detail.method_label': '方法',
    'detail.source_label': 'ソース',
    'interaction.low': '低リスク',
    'interaction.moderate': '中リスク',
    'interaction.high': '高リスク',
    'interaction.score': 'スコア {value}',
    'interaction.analysis_title': '分析',
    'interaction.key_findings': '主要判断',
    'interaction.next_actions': '次の対応',
    'interaction.data_notes': 'データと境界の注記',
    'interaction.missing_input': '重要入力が不足',
    'interaction.evidence_count': '証拠 {count} 件',
    'interaction.evidence_pmid': 'PMID',
    'interaction.evidence_publication': '掲載誌/出典',
    'interaction.evidence_kind': 'エビデンス種別',
    'interaction.evidence_source_family': 'ソース系統',
    'interaction.evidence_doi': 'DOI',
    'interaction.evidence_link': 'ソースリンク',
    'interaction.action_reschedule_full':
        '服薬と食事は、食前 {before} 分・食後 {after} 分程度あけることを検討してください。',
    'interaction.action_reschedule_before':
        '食事前に少なくとも {before} 分あけて服薬することを検討してください。',
    'interaction.action_reschedule_generic': '服薬と食事の時刻調整を検討してください。',
    'interaction.action_separate_by_time':
        '少なくとも {minutes} 分は間隔をあけることを検討してください。',
    'interaction.action_avoid_food': '現在の高リスク食品または食品組み合わせの回避を検討してください。',
    'interaction.action_avoid_combination': 'この薬と食品の組み合わせは避けることを検討してください。',
    'interaction.action_switch_thickener': 'より安全な増粘剤への切替え、または手動確認を検討してください。',
    'interaction.action_manual_review': '最も安全な次の一手は手動レビューです。',
    'decision.block': '禁止',
    'decision.require_review': '要確認',
    'decision.discourage': '非推奨',
    'decision.warn': '警告',
    'decision.info': '情報',
    'decision.allow': '許可',
    'decision.defer': '保留',
    'severity.low': '低',
    'severity.moderate': '中',
    'severity.high': '高',
    'severity.critical': '重大',
    'missing.dose': '用量',
    'missing.formulation': '製剤情報',
    'missing.time': '服薬時刻',
    'missing.meal_time': '食事時刻',
    'missing.coevent_time': '関連イベント時刻',
    'missing.thickener_type': '増粘剤タイプ',
    'runtime.same_band_conflict': '同じ優先度のルールで結論が衝突したため、手動レビューが必要です。',
    'runtime.missing_fields': '重要な入力が不足しています: {fields}。手動レビューが必要です。',
    'runtime.no_rules': '登録済みルールは発火しませんでした。',
    'runtime.validation_source': 'ランタイム入力検証',
    'mealcheck.no_active_drugs': '有効な薬が選択されていないため、食薬ルールは発火しませんでした。',
    'mealcheck.no_conflict': 'データベース由来のバリアント解決が完了し、登録済みの食薬競合ルールは発火しませんでした。',
    'mealcheck.historical_no_current_risk':
        'この食事は約 {hours} 時間前の履歴であり、現在の食薬競合アクティブ時間枠を超えています。',
    'mealcheck.historical_analysis':
        'エンジンは、この履歴食を現在も消化中のリスクとして扱いません。本食は現在から約 {hours} 時間前で、現在の運用上のアクティブ時間枠は {window} 時間です。そのため、古い食事だけでは現在の高リスク警告を出しません。',
    'mealcheck.historical_note':
        '履歴食ガード：連続経腸栄養ではない食事は、{window} 時間を超えると現在の時系列リスクを発火しません。',
    'mealcheck.summary': 'データベース由来の食品・薬バリアントチェックで {count} 件の注意が見つかりました。',
    'mealcheck.analysis':
        'この食事は {drugCount} 件の有効薬に対して評価されました。最も高い評価重症度は {severity} で、スコアは {score}/100 です。',
    'mealcheck.analysis_protein': '現在の食品一覧から推定された食事たんぱく質量は約 {protein} g でした。',
    'mealcheck.analysis_highfat':
        '現在の運用ヒューリスティックでは、この食事は比較的高脂肪・高カロリーでもあると判定されました。',
    'mealcheck.analysis_scoring': 'スコアは次の重み付き要因から構成されます：{factors}。',
    'mealcheck.analysis_dbfacts':
        '正確なインポート済み観測値がある場合、エンジンはアプリ内 seed だけでなくデータベース栄養値を使用しました。',
    'mealcheck.analysis_context_used':
        '今回の判定では、サプリメント、増粘剤タイプ、経腸栄養などの追加コンテキストも使用しました。',
    'mealcheck.analysis_evidence': '今回の判定は、公式ラベルまたは登録済みの根拠ソースを直接参照しています。',
    'mealcheck.analysis_fallback':
        '一部の食品バリアントは地域フォールバックチェーンで解決されており、この判定では地域の権威データがまだ一部不足しています。',
    'mealcheck.analysis_manual_review':
        'このセッションでは重要なランタイム入力がまだ不足しているため、時間調整の助言に依存する前に手動レビューを行うのが最も安全です。',
    'mealcheck.analysis_followup':
        'より具体的な時間アドバイスが必要な場合は、薬の時刻と用量を入力してから再度チェックしてください。',
    'mealcheck.score_factor_rule_decision': 'ルール判定の重み',
    'mealcheck.score_factor_levodopa_interference': 'レボドパ干渉重み',
    'mealcheck.score_factor_protein_timing': 'タンパク質タイミングペナルティ',
    'mealcheck.score_factor_high_fat': '高脂肪食補正',
    'mealcheck.score_factor_iron_levodopa': '鉄-レボドパ補正',
    'mealcheck.score_factor_enteral_feed': '連続経腸栄養補正',
    'mealcheck.score_factor_evidence': '根拠補正',
    'mealcheck.drug_fallback': ' 選択された薬バリアントは管轄フォールバックから取得されました。',
    'mealcheck.food_fallback': ' 一部の食品バリアントは管轄フォールバックから取得されました。',
    'mealcheck.db_facts': '利用可能な場合は、データベース内の実食品バリアント栄養値を優先使用しました。',
    'mealcheck.official_source': '公式ソース：{title}',
    'mealcheck.context_iron_supplement': 'この食事には鉄剤の共イベントが記録されています。',
    'mealcheck.context_iron_multivitamin': 'この食事には鉄入り複合ビタミンの共イベントが記録されています。',
    'mealcheck.context_starch_thickener': 'この食事にはデンプン系増粘剤が記録されています。',
    'mealcheck.context_xanthan_thickener': 'この食事にはキサンタン系増粘剤が記録されています。',
    'mealcheck.context_enteral_feed_continuous':
        'この食事には持続経腸栄養（タンパク質 {protein} g/日）が記録されています。',
    'mealcheck.context_enteral_feed_bolus': 'この食事にはボーラス/間欠経腸栄養が記録されています。',
    'legacy.no_conflict': '組み込みルールでは大きな競合は検出されませんでした（医療助言ではありません）。',
    'legacy.high_protein_strong': '高たんぱくの時間帯はレボドパ吸収に強く影響する可能性があります',
    'legacy.high_protein_strong_detail':
        'この食事には約 {protein} g のたんぱく質が含まれており、より高いリスク帯です。{drug} の近い時間帯では吸収競合が強まる可能性があります。',
    'legacy.high_protein': 'たんぱく質が薬の吸収に影響する可能性があります',
    'legacy.high_protein_detail':
        'この食事には約 {protein} g のたんぱく質が含まれており、{drug} の吸収と競合する可能性があります。高たんぱく食は服薬時間から離して検討してください。',
    'legacy.tyramine': '高チラミン食品のリスクの可能性',
    'legacy.tyramine_detail':
        'この食事には高チラミンとマークされた食品が含まれています。{drug} と併用すると副作用リスクが高まる可能性があります。',
    'legacy.mineral': 'ミネラル補充の時間に関する注意',
    'legacy.mineral_detail':
        'この食事には乳製品が含まれており、カルシウムが高い可能性があります。一部のミネラル補充剤は食事と一緒に摂ると吸収や消化耐性が変わることがあります。',
    'legacy.summary':
        '総合スコア {score}/100（{severity}）、食事・薬・栄養に関連する可能性のある注意が {count} 件あります。',
    'legacy.analysis':
        '組み込みルールはこの食事を {drugCount} 件の薬に対して評価し、ヒューリスティックなスクリーニングスコア {score}/100 を出しました。',
    'legacy.analysis_protein': '現在の食事推定には約 {protein} g のたんぱく質が含まれています。',
    'legacy.analysis_tyramine': 'この食事には、組み込みカタログで高チラミン寄りとしてタグ付けされた食品も含まれています。',
    'legacy.analysis_followup':
        'これは簡易スクリーニング結果として扱い、より具体的な助言が必要な場合は正確な服薬時刻を確認してください。',
    'legacy.severity.high': '高リスク',
    'legacy.severity.moderate': '中リスク',
    'legacy.severity.low': '低リスク',
    'recommend.low_protein': '低たんぱくを優先',
    'recommend.protein_window_caution': 'レボドパ時間帯では高たんぱくに注意',
    'recommend.history_low_protein': '最近の履歴に基づき、低たんぱくの選択肢を優先',
    'recommend.culture_match': '現在の地域食事テンプレートに一致',
    'recommend.fallback_chain': 'この地域の食品知識はフォールバックチェーンを使用中',
    'recommend.general_friendly': '一般的に選びやすい候補',
    'recommend.path.hybrid_local_ai': 'ローカルAIによる再順位付け',
    'recommend.path.conservative_safety_gate': '保守経路（安全ゲートがAIを停止）',
    'recommend.path.conservative_gate_block': '保守経路（ローカルAI利用不可）',
    'recommend.path.fallback_invalid_ai': '保守経路（AI出力の検証失敗）',
    'recommend.path.conservative_cdss': '保守CDSS経路',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'localhost の Ollama または llama.cpp サービスが応答していません。ローカルモデルを起動するか、ローカルAI再順位付けを無効にしてください。',
    'recommend.runtime.endpoint_must_be_localhost':
        'ローカルAI endpoint は localhost/127.0.0.1 に限定され、クラウドを指してはいけません。',
    'recommend.runtime.safety_gate_conservative': '安全ゲートにより結果は保守経路に維持されました。',
    'recommend.runtime.next_meal_window_missing':
        '次の食事の予定時間帯が未入力です。「食事を追加/編集」で最早時刻と最遅時刻を入力してください。',
    'recommend.runtime.no_prior_meal_history': '安全な再順位付けに使える前回の食事記録がありません。',
    'recommend.runtime.legacy_meal_time':
        '最新の食事は移行済みの旧時刻を使用しています。実際の食事時刻に編集してください。',
    'recommend.runtime.iron_conservative':
        '最新の食事に鉄剤が記録されているため、再順位付けは保守的に維持されます。',
    'recommend.runtime.iron_multivitamin_conservative':
        '最新の食事に鉄入り複合ビタミンが記録されているため、再順位付けは保守的に維持されます。',
    'recommend.runtime.starch_thickener_conservative':
        '最新の食事にデンプン系増粘剤が記録されているため、決定論的な安全確認を維持します。',
    'recommend.runtime.enteral_conservative': '持続経腸栄養の文脈があるため、決定論的な確認を維持します。',
    'recommend.runtime.local_ai_not_consented': 'ユーザーがローカルAI再順位付けを有効にしていません。',
    'recommend.runtime.local_ai_unavailable': 'ローカルAI endpoint は現在利用できません。',
    'recommend.runtime.returned_conservative': '決定論的な保守推薦を返しました。',
    'recommend.runtime.ai_validation_failed': 'ローカルAIの構造化出力がホワイトリスト検証に失敗しました。',
    'recommend.runtime.ai_invalid_whitelist':
        'ローカルAIが有効なホワイトリスト内の順位を返さなかったため、その結果は使用しません。',
    'recommend.runtime.cdss_conservative_observations':
        '保守CDSS経路では、利用可能な場合に実際のバリアント観測値を使用します。',
    'recommend.runtime.local_ai_success': 'ローカルAIによる再順位付けが完了しました。',
    'recommend.runtime.local_ai_copy_polish_success': 'ローカルAIによる文章調整が完了しました。',
    'recommend.runtime.medgemma_optional_unavailable':
        'ローカルAIは利用可能です。任意のMedGemmaレビュー用モデルは利用できないため、安全にフォールバックしました。',
    'recommend.runtime.recommendation_conservative': '推薦は保守経路に維持されました。',
    'recommend.runtime.levodopa_ai_sensitive':
        'レボドパ関連の時間帯が敏感すぎるため、AI再順位付けは使用しません。',
    'copy.deterministic_path': 'ルールベース経路',
    'copy.rerank': '再順位付け',
    'copy.cdss': '臨床意思決定支援',
    'copy.official_label_meal_separation': '公式ラベルは食事との間隔を求めています',
    'copy.database_food_variants': 'データベース食品バリアント',
    'copy.database_nutrient_facts': 'データベース栄養事実',
    'copy.missing_input_unknown': '重要情報',
    'copy.interaction_summary_missing_inputs':
        '{missing} が不足しているため、一時的に高リスク（{score}/100）として扱います。食事と薬の時間関係を安全に判断できません。',
    'copy.interaction_summary_high':
        '現在の確認結果は高リスク（{score}/100）です。理由と次の操作を確認してください。',
    'copy.interaction_analysis_missing_inputs':
        'これは食事そのものが必ず危険という意味ではありません。{missing} が不足しているため、薬との時間関係を安全に評価できないという意味です。',
    'copy.interaction_analysis_protein':
        'この食事の推定たんぱく質量は約 {protein} g です。レボドパ使用中は、たんぱく質量が時間調整の判断に関係します。',
    'copy.interaction_analysis_fallback':
        '一部の食品は地域フォールバックデータを使用しており、地域の権威データはまだ完全ではありません。',
    'copy.interaction_analysis_database': '利用可能な場合は、インポート済みデータベースの栄養事実を使用しました。',
    'copy.interaction_analysis_not_diagnosis':
        'これは不足情報を補うための保守的な安全リマインダーであり、診断ではありません。',
    'copy.key_finding_missing_inputs': '時間関係の確認を完了できません：{missing} が不足しています。',
    'copy.next_action_complete_med_timing': 'まず薬の時刻と用量を入力し、その後もう一度確認してください。',
    'copy.data_note_fallback': '一部の食品は、より地域に近い権威ソースが入るまで地域フォールバックデータを使用しています。',
    'copy.data_note_database': '利用可能な範囲で、内蔵サンプルではなく実データベースの栄養値を使用しました。',
    'copy.data_note_missing_input': '{missing} が不足しているため、時間ルールはより保守的になります。',
    'copy.issue_missing_inputs': '{missing} が不足しているため、この食事と薬を離すべきか安全に判断できません。',
    'recommend.context_iron_supplement': '最新の食事に鉄剤が記録されているため、時系列説明は保守的に維持されます。',
    'recommend.context_iron_multivitamin':
        '最新の食事に鉄入り複合ビタミンが記録されているため、時系列説明は保守的に維持されます。',
    'recommend.context_starch_thickener': 'デンプン系増粘剤が記録されており、嚥下安全性の優先度が上がります。',
    'recommend.context_xanthan_thickener': '最新の食事にキサンタン系増粘剤が記録されています。',
    'recommend.context_enteral_feed_continuous':
        '持続経腸栄養が有効です（タンパク質 {protein} g/日）。そのため推薦文は保守的になります。',
    'recommend.context_enteral_feed_bolus': '最新の食事にボーラス/間欠経腸栄養が記録されています。',
    'recommend.context_iron_penalty': '鉄関連の共イベントがあるため、高たんぱく候補は保守的に順位を下げます。',
    'recommend.context_enteral_penalty': '持続経腸栄養の文脈があるため、高たんぱく候補は保守的に順位を下げます。',
    'recommend.context_texture_gap_penalty':
        '増粘剤が記録されていますが、現在のカタログには構造化された食形態適合データが不足しているため、追加の保守余地を残します。',
    'recommend.context_texture_supported':
        '増粘剤が記録されていますが、この候補には構造化された食形態情報があるため、データ欠損ペナルティは低く抑えられます。',
    'recommend.texture_profile_missing':
        '食形態安全モードが有効ですが、この候補には構造化された食形態情報がないため、順位はより保守的になります。',
    'recommend.texture_profile_supported_soft_or_liquid':
        'この候補は現在の「軟らかい食事または液体」安全モードに適合します。',
    'recommend.texture_profile_supported_liquid_only':
        'この候補は現在の「液体のみ」安全モードに適合します。',
    'recommend.texture_profile_incompatible':
        'この候補は現在の食形態安全モードに適合しないため、保守的に順位を下げます。',
    'recommend.texture_template_supported': 'この候補は現在の食事テンプレートの食形態方向に一致します。',
    'recommend.texture_template_mismatch': 'この候補は現在の食事テンプレートの食形態方向に一致しません。',
    'recommend.local_seed_metadata':
        'この候補はまだローカル種データに依存しており、より完全なデータベース観測が不足しています。',
    'recommend.timing_window_incomplete': '時間帯情報が不完全なため、保守的な順位付けで追加の安全余地を残します。',
    'recommend.next_meal_gap_close': '次の食事時間帯が前回の食事に近いため、低たんぱくの選択肢を優先します。',
    'recommend.next_meal_window_fiber': '予定された次の食事時間帯に合い、より安定した食物繊維摂取につながります。',
    'recommend.medication_timing_caution': '服薬時刻から見て、この次の食事時間帯には追加の注意が必要です。',
    'texture_mode.unrestricted': '制限なし',
    'texture_mode.soft_or_liquid': '軟らかい食事または液体',
    'texture_mode.liquid_only': '液体のみ',
    'texture_class.liquid': '液体',
    'texture_class.soft': '軟食',
    'texture_class.regular': '通常',
    'food.food_chicken_breast': '鶏むね肉（調理済み）',
    'food.food_tofu': '豆腐',
    'food.food_brown_rice': '玄米',
    'food.food_banana': 'バナナ',
    'food.food_spinach': 'ほうれん草',
    'food.food_milk': '低脂肪牛乳',
    'food.food_beef': '赤身牛肉（焼き）',
    'food.food_apple': 'りんご（皮付き）',
    'food.food_blueberry': 'ブルーベリー',
    'food.food_tomato': 'トマト',
    'food.food_broccoli': 'ブロッコリー',
    'food.food_oats': 'オートミール',
    'food.food_salmon': 'サーモン（養殖・焼き）',
    'food.food_fava_beans': 'そら豆',
    'food.food_potato_boiled': 'じゃがいも（水煮）',
    'food.food_walnuts': 'くるみ',
    'food.food_olive_oil': 'エクストラバージンオリーブオイル',
    'food.food_cheddar_cheese': 'チェダーチーズ',
    'food.food_egg_boiled': 'ゆで卵',
    'food.food_coffee': 'コーヒー（無糖）',
    'medication_note.drug_levodopa_carbidopa':
        'パーキンソン病でよく使われる併用薬です。高たんぱく食の後に作用の変動を感じる患者もいます。',
    'medication_note.drug_entacapone': 'COMT阻害薬で、レボドパと併用されることが多いです。',
    'medication_note.drug_opicapone':
        '1日1回のCOMT阻害薬で、OFFエピソードに対してレボドパ/カルビドパへ追加されます。',
    'medication_note.drug_tolcapone':
        'COMT阻害薬で、肝機能モニタリングが重要です。食事タイミングより安全性管理とレボドパ併用文脈が中心です。',
    'medication_note.drug_rasagiline':
        'MAO-B阻害薬です。通常用量では一般的なチラミン制限は不要ですが、極端に高いチラミン負荷は注意が必要です。',
    'medication_note.drug_safinamide':
        'レボドパ/カルビドパ併用のMAO-B阻害薬です。非常に高いチラミン負荷は引き続き注意点です。',
    'medication_note.drug_selegiline': 'MAO-B阻害薬です。高チラミン食品ルールは現在ベースラインの暫定実装です。',
    'medication_note.drug_iron': 'ミネラル補充剤です。食事とのタイミングが耐容性や吸収に影響することがあります。',
    'medication_note.drug_pramipexole':
        'ドパミン作動薬です。食事競合よりも眠気、起立性低血圧、衝動制御の方が臨床的には重要です。',
    'medication_note.drug_ropinirole':
        '単独または追加治療で使われるドパミン作動薬です。現在のエンジンでは大きな食事ハードルールはありません。',
    'medication_note.drug_rotigotine':
        '経皮ドパミン作動薬です。消化管を通らないため、食事タイミングの重要性は比較的低いです。',
    'medication_note.drug_apomorphine':
        '製剤によってレスキューまたは進行期OFF治療で使われます。食事より投与経路の文脈が重要です。',
    'medication_note.drug_amantadine':
        '製剤に応じてパーキンソン症状やジスキネジアで用いられます。現時点で食事競合は主ターゲットではありません。',
    'medication_note.drug_istradefylline':
        'OFF時の追加治療薬です。現在の食事ルールは限定的ですが、PD関連薬として収載しています。',
    'medication_note.drug_pimavanserin':
        'パーキンソン病精神病に用いられます。直接の食事ルールより、PDケアの網羅性のために収載しています。',
    'medication_note.drug_rivastigmine':
        'パーキンソン病認知症で用いられます。内服は食事と一緒に使うことが多く、貼付剤では消化管文脈が変わります。',
    'medication_note.drug_droxidopa':
        '神経原性起立性低血圧で使われます。食後/空腹時の一貫性が臨床上重要になることがあります。',
    'medication_note.drug_midodrine': '起立性低血圧で使われます。食事より日中スケジュールと血圧管理の方が重要です。',
    'medication_note.drug_peg_3350':
        '浸透圧性下剤です。現在のハードルールは主にでんぷん系増粘剤との不適合に関するものです。',
    'medication_note.drug_levodopa_entacapone':
        '固定用量のレボドパ配合剤です。他のレボドパ製剤と同様に高たんぱく食と鉄剤分離の注意を適用します。',
    'medication_note.drug_levodopa_benserazide':
        '米国外で使われるレボドパ配合剤です。他のレボドパ治療と同様にたんぱく質タイミングと鉄剤分離の注意を適用します。',
  },
  // ko / hi / es / vi / th / id / ru / pl / ar are now sourced from
  // `app_i18n_full_translations.dart`. They cover every visible UI key the
  // dashboard / timeline / catalog / onboarding actually render, so picking
  // any of them yields a fully-translated UI instead of English fallbacks.
  // The 17-key stub maps that used to live here were removed.
  'ko': kFullLocaleUiTranslations['ko']!,
  'hi': kFullLocaleUiTranslations['hi']!,
  'es': kFullLocaleUiTranslations['es']!,
  'vi': kFullLocaleUiTranslations['vi']!,
  'th': kFullLocaleUiTranslationsExtra['th']!,
  'id': kFullLocaleUiTranslationsExtra['id']!,
  'ru': kFullLocaleUiTranslationsExtra['ru']!,
  'pl': kFullLocaleUiTranslationsExtra['pl']!,
  'ar': kFullLocaleUiTranslationsExtra['ar']!,
};

const Map<String, String> _zhMedicationNameByGeneric = {
  'levodopacarbidopa': '左旋多巴/卡比多巴',
  'carbidopalevodopa': '卡比多巴/左旋多巴',
  'carbidopalevodopaentacapone': '卡比多巴/左旋多巴/恩他卡朋',
  'levodopabenserazide': '左旋多巴/苄丝肼',
  'entacapone': '恩他卡朋',
  'opicapone': '奥匹卡朋',
  'tolcapone': '托卡朋',
  'rasagiline': '雷沙吉兰',
  'safinamide': '沙芬酰胺',
  'selegiline': '司来吉兰',
  'ironsupplement': '铁剂补充剂',
  'iron': '铁剂',
  'pramipexole': '普拉克索',
  'ropinirole': '罗匹尼罗',
  'rotigotine': '罗替高汀',
  'apomorphine': '阿扑吗啡',
  'amantadine': '金刚烷胺',
  'pimavanserin': '匹莫范色林',
  'rivastigmine': '利斯的明',
  'droxidopa': '屈昔多巴',
  'midodrine': '米多君',
  'peg3350': '聚乙二醇 3350',
};

const Map<String, String> _zhMedicationNoteByGeneric = {
  'levodopacarbidopa': '帕金森病核心口服左旋多巴复方。高蛋白餐可能延迟或减弱反应，铁盐也可能降低生物利用度。',
  'carbidopalevodopa': '帕金森病核心口服左旋多巴复方。高蛋白餐可能延迟或减弱反应，铁盐也可能降低生物利用度。',
  'entacapone': '外周 COMT 抑制剂，常与左旋多巴联用以减少疗效波动。',
  'tolcapone': 'COMT 抑制剂，使用时需要关注肝毒性监测，通常保留给特定患者。',
  'opicapone': '每日一次的 COMT 抑制剂，用于 OFF 发作患者的左旋多巴/卡比多巴辅助治疗。',
  'selegiline': '用于帕金森病的 MAO-B 抑制剂。推荐剂量下通常不需要常规限酪胺，但极高酪胺暴露仍需注意。',
  'rasagiline': '选择性 MAO-B 抑制剂。推荐剂量下一般不需常规限酪胺，但极高酪胺负荷应避免。',
  'safinamide': '与左旋多巴/卡比多巴联用的 MAO-B 抑制剂，主要用于伴 OFF 波动的患者。',
  'ironsupplement': '铁剂本身不是 PD 治疗药，但临床上重要，因为它可能与左旋多巴/卡比多巴螯合并降低吸收。',
  'iron': '铁剂本身不是 PD 治疗药，但临床上重要，因为它可能与左旋多巴/卡比多巴螯合并降低吸收。',
  'pramipexole': '多巴胺受体激动剂，可用于单药或辅助治疗。',
  'ropinirole': '多巴胺受体激动剂，可用于早期或辅助治疗。',
  'rotigotine': '经皮多巴胺受体激动剂，适合口服时序或胃排空较难管理的场景。',
  'apomorphine': '速效多巴胺受体激动剂，按制剂不同可用于急救或进展期 OFF 管理。',
  'amantadine': '不同制剂下可用于帕金森症状或异动症管理。',
  'istradefylline': '腺苷 A2A 受体拮抗剂，用作左旋多巴/卡比多巴的辅助治疗以改善 OFF。',
  'pimavanserin': '5-HT2A 反向激动/拮抗药，用于帕金森病相关精神病。',
  'rivastigmine': '胆碱酯酶抑制剂，用于帕金森病痴呆。口服制剂常随餐以改善耐受性，贴剂则绕开胃肠道。',
  'droxidopa': '去甲肾上腺素前体，用于神经源性直立性低血压。',
  'midodrine': 'α1 激动剂，用于症状性直立性低血压。',
  'peg3350': '渗透性泻剂，常用于 PD 相关便秘管理。',
  'carbidopalevodopaentacapone': '固定剂量复方，同时继承左旋多巴的餐时注意点与 COMT 辅助治疗背景。',
  'levodopabenserazide': '美国以外常用的左旋多巴复方，对跨辖区 PD 管理很重要。',
};

const Map<String, String> _zhMedicationSummaryByGeneric = {
  'levodopacarbidopa': '主要饮食相关关注点是蛋白时间窗和铁剂螯合。',
  'carbidopalevodopa': '主要饮食相关关注点是蛋白时间窗和铁剂螯合。',
  'entacapone': '通常与左旋多巴时序一起评估，而不是单独作为食物冲突药物。',
  'tolcapone': '食物冲突不是首要问题，监测与左旋多巴联合治疗背景更重要。',
  'opicapone': '通常按左旋多巴时序来解释，不是直接的食物阻断药物。',
  'selegiline': '主要饮食注意点仍是极高酪胺食物，尤其在剂量或制剂变化时。',
  'rasagiline': '应注意极高酪胺负荷，约 150 mg 及以上时更需谨慎。',
  'safinamide': '推荐剂量下通常不需常规限酪胺，但大量酪胺负荷仍相关。',
  'ironsupplement': '如有可能，应与含左旋多巴治疗错开。',
  'iron': '如有可能，应与含左旋多巴治疗错开。',
  'pramipexole': '当前引擎中食物冲突较少，临床上更应关注嗜睡、冲动控制和体位性低血压。',
  'ropinirole': '当前引擎没有针对其设置主要食物硬规则，更应关注耐受性和滴定背景。',
  'rotigotine': '由于绕开胃肠道，食物时间的重要性较低。',
  'apomorphine': '食物相互作用不是主要问题，给药途径和急救使用背景更关键。',
  'amantadine': '当前引擎中的食物触发规则有限，肾功能和制剂背景更关键。',
  'istradefylline': '当前引擎未设置专门的食物硬阻断，主要作为 OFF 辅助治疗数据存在。',
  'pimavanserin': '当前引擎并不把它作为食物冲突重点药物，但它对 PD 照护高度相关。',
  'rivastigmine': '口服制剂的餐时可能影响耐受性，而贴剂会改变胃肠道背景。',
  'droxidopa': '与进食的“始终同状态”一致性在临床上可能重要。',
  'midodrine': '当前引擎没有直接食物规则；白天给药与仰卧高血压背景更重要。',
  'peg3350': '当前硬规则主要聚焦于吞咽场景下与淀粉型增稠剂的不相容。',
  'carbidopalevodopaentacapone': '应沿用其他含左旋多巴治疗的蛋白时间窗与铁剂错峰注意。',
  'levodopabenserazide': '应沿用其他含左旋多巴制剂的高蛋白与铁剂错峰注意。',
};
