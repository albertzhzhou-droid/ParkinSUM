import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/copy/response_copy_service.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/analysis/interaction_engine.dart';
import 'package:parkinsum_companion/core/db/cdss_database.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/core/models/meal.dart';
import 'package:parkinsum_companion/domain/usecases/database_backed_meal_check_usecase.dart';
import 'package:parkinsum_companion/domain/usecases/imported_label_rule_provider.dart';
import 'package:parkinsum_companion/domain/usecases/rule_registry_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';

/// Safety-copy integrity for the meal check and the next-meal page.
///
/// CLAUDE.md forbids medication-timing and dietary instructions. Rule actions
/// keep their machine parameters (minutes before or after meals) for audit,
/// but nothing the app shows may turn them into a minute-based instruction,
/// rule messages must exist in English, and next-meal reasons must describe
/// rather than steer. Educational prototype only; synthetic data only.

/// A minute quantity: a number or placeholder followed by a minute unit.
final _minuteQuantity = RegExp(
  r'(\d+|\{[A-Za-z_]+\})\s*('
  r'minutes?|mins?\b|minutos?|minuti|phút|นาที|menit|minut\w*|минут\w*|'
  r'دقيق\w*|मिनट|분|分钟|分(?![析数類类])'
  r')',
  caseSensitive: false,
);

/// Words that address the reader with something to do. Combined with a minute
/// quantity they form a timing instruction.
final _directive = RegExp(
  r'\b(consider|should|take|taking|move|moving|separate|separating|wait|'
  r'schedule|space|try|aim|delay|envisagez|prenez|devez|attendez|separer|'
  r'considere|tome|separe|espere|debe)\b|'
  r'建议|应当|应该|错开|提前|検討|してください|あけ|nên|hãy|ควร|sebaiknya|'
  r'следует|принимайте|należy|przyjmuj|يجب|يُنصح|चाहिए|하세요|권장',
  caseSensitive: false,
);

/// Scheduling advice without a minute quantity, in the languages the legacy
/// engine and the imported-label rules ship.
final _scheduling = RegExp(
  r'consider scheduling|away from dosing|requires separation|'
  r'programmer les repas|loin de la prise|離して|错峰|错开',
  caseSensitive: false,
);

bool _isMinuteInstruction(String text) =>
    _minuteQuantity.hasMatch(text) && _directive.hasMatch(text);

/// Dietary steering in next-meal reasons: preference or prioritisation.
final _steering = RegExp(
  r'prefer|priorit|recommend|suggest|caution|优先|建议|推荐|谨慎|優先|おすすめ|'
  r'privilegi|prefere|우선|추천|주의하세요|प्राथमिकता|सावधान|prefiere|priorizar|'
  r'precaución|ưu tiên|thận trọng|ควรเลือก|ระมัดระวัง|disukai|memprioritaskan|'
  r'hati-hati|предпочтител|приоритет|осторожны|preferowan|priorytet|ostrożność|'
  r'يفضّل|الأولوية|احذر',
  caseSensitive: false,
);

const _locales = [
  'en-US',
  'zh-CN',
  'fr-FR',
  'ja-JP',
  'ko-KR',
  'hi-IN',
  'es-MX',
  'es-ES',
  'vi-VN',
  'th-TH',
  'id-ID',
  'ru-RU',
  'pl-PL',
  'ar-SA',
];

Iterable<Map<String, dynamic>> _ruleActions() sync* {
  for (final rule in baselineCdssRules) {
    final then = rule['then'] as Map;
    for (final action in (then['actions'] as List).cast<Map>()) {
      yield Map<String, dynamic>.from(action);
    }
  }
  // Imported label rules emit the same action types with label-derived
  // minutes; they are built from stored label facts at runtime.
  yield {
    'type': 'suggest_reschedule',
    'params': {'preferred_before_meal_min': 30, 'preferred_after_meal_min': 90},
  };
  yield {
    'type': 'suggest_reschedule',
    'params': {'preferred_before_meal_min': 60},
  };
  yield {'type': 'suggest_reschedule', 'params': <String, dynamic>{}};
  yield {
    'type': 'separate_by_time',
    'params': {'min_separation_minutes': 120},
  };
}

void main() {
  test('the minute-instruction detector flags the wording it replaces', () {
    expect(
      _isMinuteInstruction(
        'Consider separating medication and meals by about 60 minutes '
        'before meals and 120 minutes after meals.',
      ),
      isTrue,
    );
    expect(_isMinuteInstruction('建议把用药提前至少 {before} 分钟后再进餐。'), isTrue);
    expect(
      _isMinuteInstruction('少なくとも {minutes} 分は間隔をあけることを検討してください。'),
      isTrue,
    );
    expect(_isMinuteInstruction('Planned next-meal time'), isFalse);
    expect(_isMinuteInstruction('冲突复核：{severity} · 规则分 {score}'), isFalse);
  });

  test('no shipped string in any language is a minute-based timing '
      'instruction', () {
    final offenders = <String>[];
    AppI18n.translationDictionary.forEach((family, strings) {
      strings.forEach((key, value) {
        if (_isMinuteInstruction(value)) offenders.add('$family/$key: $value');
      });
    });
    expect(offenders, isEmpty);
  });

  test('no rule message in any language is a minute-based timing '
      'instruction', () {
    final offenders = <String>[];
    for (final rule in baselineCdssRules) {
      final messages = (rule['then'] as Map)['messages'] as Map;
      final all = <String, String>{
        for (final entry in messages.entries)
          if (entry.value is String) '${entry.key}': entry.value as String,
        ...Map<String, String>.from((messages['localized'] as Map?) ?? {}),
      };
      all.forEach((locale, text) {
        if (_isMinuteInstruction(text)) {
          offenders.add('${rule['rule_id']}/$locale: $text');
        }
      });
    }
    expect(offenders, isEmpty);
  });

  test('every rendered rule action, in every language, carries no minutes '
      'and points to clinician review', () {
    for (final localeTag in _locales) {
      final i18n = AppI18n.fromLocaleTag(localeTag);
      for (final action in _ruleActions()) {
        final text = DatabaseBackedMealCheckUseCase.describeMachineAction(
          i18n,
          action,
        );
        if (action['type'] == 'emit_machine_tag' ||
            action['type'] == 'withhold_rule_evaluation') {
          expect(text, isEmpty, reason: '$localeTag ${action['type']}');
          continue;
        }
        expect(text, isNotEmpty, reason: '$localeTag ${action['type']}');
        expect(
          RegExp(r'\d').hasMatch(text),
          isFalse,
          reason: '$localeTag ${action['type']} rendered a number: $text',
        );
        expect(_isMinuteInstruction(text), isFalse, reason: text);
      }
    }
    final en = AppI18n.fromLocaleTag('en-US');
    for (final type in [
      'suggest_reschedule',
      'separate_by_time',
      'avoid_food',
      'avoid_combination',
      'switch_thickener',
      'require_manual_review',
    ]) {
      expect(
        DatabaseBackedMealCheckUseCase.describeMachineAction(en, {
          'type': type,
        }),
        contains('qualified clinician'),
        reason: type,
      );
    }
  });

  test('timing instructions saved by earlier versions are shown with the '
      'current wording', () {
    final legacy = <String, List<String>>{
      'en-US': [
        'Consider separating medication and meals by about 60 minutes '
            'before meals and 120 minutes after meals.',
        'Consider moving medication at least 60 minutes before eating.',
        'Consider separating the two events by at least 120 minutes.',
      ],
      'zh-CN': [
        '建议把用药与进餐错开：餐前 60 分钟、餐后 120 分钟再考虑进食。',
        '建议把用药提前至少 60 分钟后再进餐。',
        '建议至少错开 120 分钟。',
      ],
      'fr-FR': [
        'Envisagez de separer la prise du medicament et le repas d environ '
            '60 minutes avant le repas et 120 minutes apres.',
        'Envisagez un decalage d au moins 120 minutes.',
      ],
      'ja-JP': [
        '服薬と食事は、食前 60 分・食後 120 分程度あけることを検討してください。',
        '少なくとも 120 分は間隔をあけることを検討してください。',
      ],
    };
    legacy.forEach((localeTag, texts) {
      final copy = ResponseCopyService(i18n: AppI18n.fromLocaleTag(localeTag));
      for (final text in texts) {
        final shown = copy.nextAction(text);
        expect(shown, isNot(text));
        expect(_isMinuteInstruction(shown), isFalse, reason: shown);
        expect(RegExp(r'\d').hasMatch(shown), isFalse, reason: shown);
      }
    });
  });

  test('every baseline rule has an English message', () {
    final cjk = RegExp(r'[぀-ヿ㐀-鿿]');
    for (final rule in baselineCdssRules) {
      final messages = (rule['then'] as Map)['messages'] as Map;
      final en = messages['en'];
      expect(en, isA<String>(), reason: '${rule['rule_id']} has no en');
      expect((en as String).trim(), isNotEmpty, reason: '${rule['rule_id']}');
      expect(cjk.hasMatch(en), isFalse, reason: '${rule['rule_id']}: $en');
    }
  });

  test('English users see English rule messages', () {
    // RuleMessageSet.forLocale falls back exact tag → family → en → zh, so a
    // missing en showed Chinese to English users.
    for (final rule in baselineCdssRules) {
      final messages = (rule['then'] as Map)['messages'] as Map;
      final localized = Map<String, String>.from(
        (messages['localized'] as Map?) ?? const {},
      );
      expect(localized.containsKey('en-US'), isFalse);
      expect(localized.containsKey('en'), isFalse);
    }
  });

  test('the PEG and starch-thickener block keeps its aspiration caution', () {
    final rule = baselineCdssRules.firstWhere(
      (rule) => rule['rule_id'] == 'pd.peg.starch_thickener.block.v1',
    );
    final then = rule['then'] as Map;
    expect(then['decision'], 'BLOCK');
    final messages = then['messages'] as Map;
    expect(messages['en'], contains('aspiration'));
    expect(messages['en'], contains('starch-based thickener'));
    expect(messages['zh'], contains('误吸'));
    expect(messages['zh'], contains('淀粉型增稠剂'));
  });

  test('next-meal reasons describe and compare; they do not steer', () {
    const reasonKeys = [
      'recommend.low_protein',
      'recommend.history_low_protein',
      'recommend.protein_window_caution',
    ];
    AppI18n.translationDictionary.forEach((family, strings) {
      for (final key in reasonKeys) {
        final value = strings[key];
        if (value == null) continue;
        expect(
          _steering.hasMatch(value),
          isFalse,
          reason: '$family/$key steers: $value',
        );
      }
    });
    for (final localeTag in ['en-US', 'zh-CN']) {
      final i18n = AppI18n.fromLocaleTag(localeTag);
      for (final key in [
        'next_meal.title',
        'next_meal.generate',
        // Today's example-food card uses the same comparison wording.
        'dashboard.recommendations',
        'dashboard.no_recommendations',
      ]) {
        expect(
          i18n.tr(key),
          isNot(matches(RegExp('ecommend|推荐'))),
          reason: '$localeTag/$key',
        );
      }
      expect(i18n.tr('dashboard.recommendations'), i18n.tr('next_meal.title'));
    }
  });

  test('no safe-copy template states a timing instruction', () {
    for (final template in const SafeCopyTemplateRegistry().templates) {
      for (final entry in template.localizedText.entries) {
        final where = '${template.templateId}/${entry.key}';
        expect(_isMinuteInstruction(entry.value), isFalse, reason: where);
        expect(_scheduling.hasMatch(entry.value), isFalse, reason: where);
      }
    }
  });

  test('the legacy engine describes protein without scheduling advice', () {
    final meal = Meal(
      id: 'synthetic_high_protein',
      eatenAt: DateTime.utc(2026, 1, 1, 12),
      title: 'Synthetic meal',
      items: [
        MealItem(
          foodId: 'food_synthetic_protein',
          foodName: 'Synthetic protein food',
          foodCategory: FoodCategory.protein,
          quantityFactor: 2,
          foodTags: const [],
          proteinPer100g: 20,
          carbsPer100g: 0,
          fatPer100g: 2,
          fiberPer100g: 0,
          sodiumPer100g: 50,
        ),
      ],
    );
    final drug = DrugDefinition(
      id: 'drug_synthetic_levodopa',
      genericName: 'carbidopa/levodopa',
      brandNames: const [],
      tags: const [DrugTag.levodopaLike],
      notes: '',
    );
    for (final locale in ['en-US', 'zh-CN', 'fr-FR', 'ja-JP']) {
      final result = InteractionEngine().evaluateMealWithDrugs(
        meal: meal,
        drugs: [drug],
        localeTag: locale,
      );
      expect(result.issues, isNotEmpty, reason: locale);
      for (final issue in result.issues) {
        for (final text in [issue.title, issue.detail]) {
          expect(_scheduling.hasMatch(text), isFalse, reason: '$locale: $text');
          expect(_isMinuteInstruction(text), isFalse, reason: '$locale: $text');
        }
      }
    }
  });

  test('imported label meal-window rules carry no timing statement', () async {
    final db = _TablesDatabase({
      'drug_label_section': [
        {
          'section_id': 'section_synthetic',
          'drug_product_variant_id': 'DRUG_SYNTHETIC#US#DAILYMED#drug_x',
          'source_doc_id': 'doc_synthetic',
          'section_key': 'administration',
          'section_title': 'Administration',
          'section_text': 'Synthetic label text.',
        },
      ],
      'source_document': [
        {
          'source_doc_id': 'doc_synthetic',
          'title': 'Synthetic label fact',
          'origin_url': 'https://example.test/synthetic',
          'source_family': 'DAILYMED',
          'raw_payload':
              '{"label_facts":[{"fact_type":"meal_window_before_after",'
              '"label":"Meal timing window","value_text":"synthetic",'
              '"payload":{"before_minutes":60,"after_minutes":120}}]}',
        },
      ],
    });
    final rules = await ImportedLabelRuleProvider(
      database: db,
      compiler: RuleRegistryCompiler(),
    ).loadRules();
    expect(rules, isNotEmpty);
    for (final rule in rules) {
      for (final entry in rule.thenClause.messages.asLocaleMap().entries) {
        final where = '${rule.ruleId}/${entry.key}';
        expect(_isMinuteInstruction(entry.value), isFalse, reason: where);
        expect(_scheduling.hasMatch(entry.value), isFalse, reason: where);
        expect(entry.value, isNot(contains('60')), reason: where);
      }
    }
  });
}

/// Read-only tables for the imported-label rule provider; it only reads.
class _TablesDatabase implements CdssDatabase {
  _TablesDatabase(this.tables);

  final Map<String, List<Map<String, Object?>>> tables;

  @override
  Future<void> initialize() async {}

  @override
  Future<List<Map<String, Object?>>> queryTable(String table) async =>
      tables[table] ?? const [];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName} is not used here');
}
