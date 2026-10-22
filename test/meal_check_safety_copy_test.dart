import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/core/copy/response_copy_service.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/domain/usecases/database_backed_meal_check_usecase.dart';

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
      for (final key in ['next_meal.title', 'next_meal.generate']) {
        expect(
          i18n.tr(key),
          isNot(matches(RegExp('ecommend|推荐'))),
          reason: '$localeTag/$key',
        );
      }
    }
  });
}
