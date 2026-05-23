import 'baseline_cdss_rule_translations.dart';

/// Public entry point. Each raw rule below carries the canonical zh
/// (and where authored, en) text. We compose the rules with the
/// `kBaselineCdssRuleTranslations` overlay at module-load time so the rule
/// JSON the rest of the app sees already contains
/// `messages.localized = { ko-KR: ..., es-MX: ..., ... }` for every locale
/// we ship.
List<Map<String, dynamic>> get baselineCdssRules =>
    _baselineCdssRulesRaw.map(_withLocalizedMessages).toList(growable: false);

Map<String, dynamic> _withLocalizedMessages(Map<String, dynamic> rule) {
  final ruleId = rule['rule_id'] as String?;
  final overlay = ruleId == null ? null : kBaselineCdssRuleTranslations[ruleId];
  if (overlay == null || overlay.isEmpty) return rule;
  // Deep-clone the rule so we never mutate the const source maps.
  final clone = Map<String, dynamic>.from(rule);
  final thenClause = Map<String, dynamic>.from(clone['then'] as Map);
  final messages = Map<String, dynamic>.from(thenClause['messages'] as Map);
  final existing =
      Map<String, dynamic>.from((messages['localized'] as Map?) ?? const {});
  // Existing entries in `localized` win over the overlay so a rule can
  // override a global translation per-rule if needed.
  for (final entry in overlay.entries) {
    existing.putIfAbsent(entry.key, () => entry.value);
  }
  messages['localized'] = existing;
  thenClause['messages'] = messages;
  clone['then'] = thenClause;
  return clone;
}

const List<Map<String, dynamic>> _baselineCdssRulesRaw = [
  {
    'rule_id': 'pd.ldopa.protein.window.v1',
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'temporal_rule',
    'priority_band': 70,
    'specificity_band': 60,
    'jurisdiction': ['*'],
    'applies_to': {
      'subject_types': ['drug_admin', 'meal'],
      'target_selector': {'target': 'drug-meal'},
    },
    'when': {
      'all': [
        {
          'in': {
            'path': 'drug.active_ingredients',
            'values': ['levodopa'],
          },
        },
        {
          'cmp': {
            'path': 'meal.protein_g',
            'op': 'gte',
            'value': 10,
          },
        },
        {
          'between': {
            'left_path': 'timestamps.drug_time',
            'right_path': 'timestamps.meal_time',
            'unit': 'minutes',
            'low': -60,
            'high': 120,
          },
        },
      ],
    },
    'then': {
      'decision': 'WARN',
      'severity': 'high',
      'messages': {
        'zh': '高蛋白餐可能降低左旋多巴吸收或临床反应，建议错峰。',
      },
      'actions': [
        {
          'type': 'suggest_reschedule',
          'params': {
            'preferred_before_meal_min': 60,
            'preferred_after_meal_min': 120,
            'note': 'operational_default_unspecified_by_label',
          },
        },
        {
          'type': 'emit_machine_tag',
          'params': {'tag': 'levodopa_protein_timing'},
        },
      ],
      'output_tags': ['levodopa_protein_timing'],
    },
    'provenance': {
      'evidence_level': 'official_label',
      'source_refs': ['fda-dhivy-high-protein'],
      'effective_from': '2024-01-01',
      'effective_to': null,
    },
  },
  {
    'rule_id': 'pd.ldopa.iron.v1',
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'temporal_rule',
    'priority_band': 80,
    'specificity_band': 80,
    'jurisdiction': ['US', 'EU', 'CA', '*'],
    'applies_to': {
      'subject_types': ['drug_admin', 'coevent'],
      'target_selector': {'target': 'drug-supplement'},
    },
    'when': {
      'all': [
        {
          'in': {
            'path': 'drug.active_ingredients',
            'values': ['levodopa'],
          },
        },
        {
          'in': {
            'path': 'coevent.substance_tags',
            'values': ['iron_salt', 'multivitamin_with_iron'],
          },
        },
        {
          'between': {
            'left_path': 'timestamps.drug_time',
            'right_path': 'timestamps.coevent_time',
            'unit': 'minutes',
            'low': -120,
            'high': 120,
          },
        },
      ],
    },
    'then': {
      'decision': 'WARN',
      'severity': 'high',
      'messages': {
        'zh': '铁盐或含铁复合维生素可能与左旋多巴/卡比多巴形成螯合并降低生物利用度，建议分开服用。',
      },
      'actions': [
        {
          'type': 'separate_by_time',
          'params': {'min_separation_minutes': 120},
        },
        {
          'type': 'emit_machine_tag',
          'params': {'tag': 'levodopa_iron_chelation'},
        },
      ],
      'output_tags': ['levodopa_iron_chelation'],
    },
    'provenance': {
      'evidence_level': 'official_label',
      'source_refs': ['dailymed-carbidopa-levodopa-iron'],
      'effective_from': '2024-01-01',
      'effective_to': null,
    },
  },
  {
    'rule_id': 'pd.rasagiline.tyramine.us.v1',
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'dose_dependent_rule',
    'priority_band': 85,
    'specificity_band': 90,
    'jurisdiction': ['US'],
    'applies_to': {
      'subject_types': ['drug_admin', 'meal'],
      'target_selector': {'target': 'drug-meal'},
    },
    'when': {
      'all': [
        {
          'cmp': {
            'path': 'drug.generic_name',
            'op': 'eq',
            'value': 'rasagiline',
          },
        },
        {
          'dose_band': {
            'path': 'drug.daily_dose_mg',
            'unit': 'mg/day',
            'op': 'lte',
            'threshold': 1.0,
          },
        },
        {
          'cmp': {
            'path': 'meal.tyramine_mg_est',
            'op': 'gt',
            'value': 150,
          },
        },
      ],
    },
    'then': {
      'decision': 'WARN',
      'severity': 'critical',
      'messages': {
        'zh': 'rasagiline 推荐剂量下通常无需普遍限酪胺，但极高酪胺摄入可能引起严重升压反应。',
      },
      'actions': [
        {
          'type': 'avoid_food',
          'params': {'reason_code': 'very_high_tyramine'},
        },
      ],
      'output_tags': ['maob_tyramine_high_threshold'],
    },
    'provenance': {
      'evidence_level': 'official_label',
      'source_refs': ['dailymed-azilect-tyramine'],
      'effective_from': '2024-01-01',
      'effective_to': null,
    },
  },
  {
    'rule_id': 'pd.safinamide.tyramine.us.v1',
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'dose_dependent_rule',
    'priority_band': 84,
    'specificity_band': 90,
    'jurisdiction': ['US'],
    'applies_to': {
      'subject_types': ['drug_admin', 'meal'],
      'target_selector': {'target': 'drug-meal'},
    },
    'when': {
      'all': [
        {
          'cmp': {
            'path': 'drug.generic_name',
            'op': 'eq',
            'value': 'safinamide',
          },
        },
        {
          'dose_band': {
            'path': 'drug.daily_dose_mg',
            'unit': 'mg/day',
            'op': 'lte',
            'threshold': 100,
          },
        },
        {
          'cmp': {
            'path': 'meal.tyramine_mg_est',
            'op': 'gt',
            'value': 150,
          },
        },
      ],
    },
    'then': {
      'decision': 'WARN',
      'severity': 'critical',
      'messages': {
        'zh': 'safinamide 推荐剂量下通常不需常规限酪胺，但极高酪胺摄入仍应避免。',
      },
      'actions': [
        {
          'type': 'avoid_food',
          'params': {'reason_code': 'very_high_tyramine'},
        },
      ],
      'output_tags': ['maob_tyramine_high_threshold'],
    },
    'provenance': {
      'evidence_level': 'official_label',
      'source_refs': ['dailymed-xadago-tyramine'],
      'effective_from': '2024-01-01',
      'effective_to': null,
    },
  },
  {
    'rule_id': 'pd.peg.starch_thickener.block.v1',
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'hard_constraint',
    'priority_band': 95,
    'specificity_band': 95,
    'jurisdiction': ['US', '*'],
    'applies_to': {
      'subject_types': ['drug_admin', 'coevent'],
      'target_selector': {'target': 'drug-thickener'},
    },
    'when': {
      'all': [
        {
          'in': {
            'path': 'drug.substance_tags',
            'values': ['peg_3350', 'peg_based_solution'],
          },
        },
        {
          'cmp': {
            'path': 'coevent.thickener_type',
            'op': 'eq',
            'value': 'starch_based',
          },
        },
      ],
    },
    'then': {
      'decision': 'BLOCK',
      'severity': 'critical',
      'messages': {
        'zh': 'PEG 制剂与淀粉型增稠剂共混可能降低黏度并增加误吸风险，不应混合。',
      },
      'actions': [
        {
          'type': 'avoid_combination',
          'params': {'reason_code': 'peg_starch_thickener_incompatibility'},
        },
        {
          'type': 'switch_thickener',
          'params': {'suggested': 'xanthan_based_or_review'},
        },
      ],
      'output_tags': ['peg_starch_thickener_incompatibility'],
    },
    'provenance': {
      'evidence_level': 'official_label',
      'source_refs': ['dailymed-peg-thickener'],
      'effective_from': '2024-01-01',
      'effective_to': null,
    },
  },
  {
    'rule_id': 'pd.ldopa.enteral.feed.review.v1',
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'escalation_rule',
    'priority_band': 90,
    'specificity_band': 85,
    'jurisdiction': ['*'],
    'applies_to': {
      'subject_types': ['drug_admin', 'enteral_feed'],
      'target_selector': {'target': 'drug-feed'},
    },
    'when': {
      'all': [
        {
          'in': {
            'path': 'drug.active_ingredients',
            'values': ['levodopa'],
          },
        },
        {
          'cmp': {
            'path': 'enteral_feed.mode',
            'op': 'eq',
            'value': 'continuous',
          },
        },
        {
          'exists': {'path': 'enteral_feed.protein_g_per_day'},
        },
      ],
    },
    'then': {
      'decision': 'REQUIRE_REVIEW',
      'severity': 'critical',
      'messages': {
        'zh': '连续肠内营养可能干扰左旋多巴反应，应由药师与营养团队按蛋白量和喂养窗口评估。',
      },
      'actions': [
        {
          'type': 'require_manual_review',
          'params': {'review_queue': 'pd_nutrition_pharmacy'},
        },
        {
          'type': 'emit_machine_tag',
          'params': {'tag': 'enteral_feed_levodopa_review'},
        },
      ],
      'output_tags': ['enteral_feed_levodopa_review'],
    },
    'provenance': {
      'evidence_level': 'primary_study',
      'source_refs': ['ann-pharmacother-enteral-levodopa'],
      'effective_from': '2024-01-01',
      'effective_to': null,
    },
  },
  {
    'rule_id': 'pd.pramipexole.food.info.v1',
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'soft_rule',
    'priority_band': 20,
    'specificity_band': 60,
    'jurisdiction': ['US', '*'],
    'applies_to': {
      'subject_types': ['drug_admin', 'meal'],
      'target_selector': {'target': 'drug-meal'},
    },
    'when': {
      'all': [
        {
          'cmp': {
            'path': 'drug.generic_name',
            'op': 'eq',
            'value': 'pramipexole',
          },
        },
        {
          'exists': {'path': 'meal.id'},
        },
      ],
    },
    'then': {
      'decision': 'INFO',
      'severity': 'low',
      'messages': {
        'zh': '普拉克索可随餐或空腹服用；若出现恶心，随餐服用可帮助减轻不适。',
        'en':
            'Pramipexole can be taken with or without food; taking it with food may reduce nausea.',
      },
      'actions': [
        {
          'type': 'emit_machine_tag',
          'params': {'tag': 'pramipexole_food_administration'},
        },
      ],
      'output_tags': ['pramipexole_food_administration'],
    },
    'provenance': {
      'evidence_level': 'official_label',
      'source_refs': ['dailymed-pramipexole-food'],
      'effective_from': '2025-10-01',
      'effective_to': null,
    },
  },
  {
    'rule_id': 'pd.ropinirole.food.info.v1',
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'soft_rule',
    'priority_band': 20,
    'specificity_band': 60,
    'jurisdiction': ['US', '*'],
    'applies_to': {
      'subject_types': ['drug_admin', 'meal'],
      'target_selector': {'target': 'drug-meal'},
    },
    'when': {
      'all': [
        {
          'cmp': {
            'path': 'drug.generic_name',
            'op': 'eq',
            'value': 'ropinirole',
          },
        },
        {
          'exists': {'path': 'meal.id'},
        },
      ],
    },
    'then': {
      'decision': 'INFO',
      'severity': 'low',
      'messages': {
        'zh': '罗匹尼罗可随餐或空腹服用；缓释剂型标签提示随餐可能减少恶心，但并非硬性限制。',
        'en':
            'Ropinirole can be taken with or without food; extended-release labeling notes food may reduce nausea, but this is not a hard restriction.',
      },
      'actions': [
        {
          'type': 'emit_machine_tag',
          'params': {'tag': 'ropinirole_food_administration'},
        },
      ],
      'output_tags': ['ropinirole_food_administration'],
    },
    'provenance': {
      'evidence_level': 'official_label',
      'source_refs': ['dailymed-ropinirole-food'],
      'effective_from': '2025-12-01',
      'effective_to': null,
    },
  },
  {
    'rule_id': 'pd.opicapone.meal.window.v1',
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'temporal_rule',
    'priority_band': 72,
    'specificity_band': 80,
    'jurisdiction': ['US', '*'],
    'applies_to': {
      'subject_types': ['drug_admin', 'meal'],
      'target_selector': {'target': 'drug-meal'},
    },
    'when': {
      'all': [
        {
          'cmp': {
            'path': 'drug.generic_name',
            'op': 'eq',
            'value': 'opicapone',
          },
        },
        {
          'exists': {'path': 'meal.id'},
        },
        {
          'between': {
            'left_path': 'timestamps.drug_time',
            'right_path': 'timestamps.meal_time',
            'unit': 'minutes',
            'low': -60,
            'high': 60,
          },
        },
      ],
    },
    'then': {
      'decision': 'WARN',
      'severity': 'high',
      'messages': {
        'zh': 'Opicapone 标签要求给药前 1 小时和给药后至少 1 小时避免进食；当前餐时与给药时间过近。',
        'en':
            'The opicapone label requires no food for 1 hour before and at least 1 hour after dosing; the current meal is too close to the dose.',
      },
      'actions': [
        {
          'type': 'suggest_reschedule',
          'params': {
            'preferred_before_meal_min': 60,
            'preferred_after_meal_min': 60,
          },
        },
        {
          'type': 'emit_machine_tag',
          'params': {'tag': 'opicapone_meal_window'},
        },
      ],
      'output_tags': ['opicapone_meal_window'],
    },
    'provenance': {
      'evidence_level': 'official_label',
      'source_refs': ['dailymed-opicapone-food'],
      'effective_from': null,
      'effective_to': null,
    },
  },
  {
    'rule_id': 'pd.rotigotine.food.independent.info.v1',
    'version': '1.0.0',
    'status': 'active',
    'rule_type': 'soft_rule',
    'priority_band': 18,
    'specificity_band': 60,
    'jurisdiction': ['US', '*'],
    'applies_to': {
      'subject_types': ['drug_admin', 'meal'],
      'target_selector': {'target': 'drug-meal'},
    },
    'when': {
      'all': [
        {
          'cmp': {
            'path': 'drug.generic_name',
            'op': 'eq',
            'value': 'rotigotine',
          },
        },
        {
          'exists': {'path': 'meal.id'},
        },
      ],
    },
    'then': {
      'decision': 'INFO',
      'severity': 'low',
      'messages': {
        'zh': 'Rotigotine 贴剂经皮给药；官方标签说明食物通常不影响吸收，可不按餐时调整。',
        'en':
            'Rotigotine is delivered transdermally; the official label states food is not expected to affect absorption, so meal timing usually does not matter.',
      },
      'actions': [
        {
          'type': 'emit_machine_tag',
          'params': {'tag': 'rotigotine_meal_independent'},
        },
      ],
      'output_tags': ['rotigotine_meal_independent'],
    },
    'provenance': {
      'evidence_level': 'official_label',
      'source_refs': ['dailymed-rotigotine-food'],
      'effective_from': null,
      'effective_to': null,
    },
  },
];
