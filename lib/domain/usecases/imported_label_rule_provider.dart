import 'dart:convert';

import '../../core/db/cdss_database.dart';
import 'rule_registry_compiler.dart';
import '../entities/rule_registry_models.dart';

/// ImportedLabelRuleProvider：
/// - 读取 `source_document.raw_payload.label_facts` 与 `drug_label_section` 的关联；
/// - 只把可直接核验的官方标签事实合成为补充规则；
/// - 不在这里引入任何“看起来合理”的经验阈值。
class ImportedLabelRuleProvider {
  final CdssDatabase database;
  final RuleRegistryCompiler compiler;

  const ImportedLabelRuleProvider({
    required this.database,
    required this.compiler,
  });

  Future<List<RuleRegistryEntry>> loadRules({
    String rulesVersion = 'imported_label_rules_v1',
  }) async {
    await database.initialize();
    final sourceDocuments = await database.queryTable('source_document');
    final labelSections = await database.queryTable('drug_label_section');

    final variantIdsBySourceDoc = <String, Set<String>>{};
    for (final row in labelSections) {
      final sourceDocId = '${row['source_doc_id'] ?? ''}';
      final variantId = '${row['drug_product_variant_id'] ?? ''}';
      if (sourceDocId.isEmpty || variantId.isEmpty) continue;
      variantIdsBySourceDoc
          .putIfAbsent(sourceDocId, () => <String>{})
          .add(variantId);
    }

    final dynamicRules = <Map<String, dynamic>>[];
    final emittedRuleIds = <String>{};

    for (final sourceDoc in sourceDocuments) {
      final sourceDocId = '${sourceDoc['source_doc_id'] ?? ''}';
      final rawPayload = '${sourceDoc['raw_payload'] ?? ''}';
      if (sourceDocId.isEmpty || rawPayload.trim().isEmpty) continue;
      final variantIds =
          variantIdsBySourceDoc[sourceDocId]?.toList(growable: false) ??
              const <String>[];
      if (variantIds.isEmpty) continue;

      Map<String, dynamic> payload;
      try {
        final decoded = jsonDecode(rawPayload);
        if (decoded is! Map) continue;
        payload = Map<String, dynamic>.from(decoded);
      } catch (_) {
        continue;
      }

      final labelFacts = payload['label_facts'];
      if (labelFacts is! List) continue;

      for (final variantId in variantIds) {
        for (final rawFact in labelFacts.whereType<Map>()) {
          final fact = Map<String, dynamic>.from(rawFact);
          final synthesized = _synthesizeRule(
            sourceDocId: sourceDocId,
            variantId: variantId,
            fact: fact,
          );
          if (synthesized == null) continue;
          final ruleId = '${synthesized['rule_id'] ?? ''}';
          if (ruleId.isEmpty || !emittedRuleIds.add(ruleId)) continue;
          dynamicRules.add(synthesized);
        }
      }
    }

    if (dynamicRules.isEmpty) {
      return const <RuleRegistryEntry>[];
    }
    return compiler.compileJsonList(dynamicRules, rulesVersion: rulesVersion);
  }

  Map<String, dynamic>? _synthesizeRule({
    required String sourceDocId,
    required String variantId,
    required Map<String, dynamic> fact,
  }) {
    final factType = '${fact['fact_type'] ?? ''}';
    switch (factType) {
      case 'meal_window_before_after':
        return _mealWindowRule(sourceDocId, variantId, fact);
      case 'with_or_without_food':
        return _withOrWithoutFoodRule(sourceDocId, variantId, fact);
      case 'high_fat_delay':
        return _highFatDelayRule(sourceDocId, variantId, fact);
      case 'iron_interaction_warning':
        return _ironInteractionRule(sourceDocId, variantId, fact);
      case 'tyramine_threshold':
        return _tyramineThresholdRule(sourceDocId, variantId, fact);
      case 'starch_thickener_incompatibility':
        return _starchThickenerRule(sourceDocId, variantId, fact);
      case 'enteral_feed_review':
        return _enteralFeedReviewRule(sourceDocId, variantId, fact);
      default:
        return null;
    }
  }

  Map<String, dynamic>? _mealWindowRule(
    String sourceDocId,
    String variantId,
    Map<String, dynamic> fact,
  ) {
    final payload = _coerceMap(fact['payload']);
    final before = (payload['before_minutes'] as num?)?.toInt();
    final after = (payload['after_minutes'] as num?)?.toInt();
    if (before == null || after == null || before <= 0 || after <= 0) {
      return null;
    }
    return {
      'rule_id': 'imported.label.${_slug(variantId)}.meal_window.$before'
          '_$after',
      'version': '1.0.0',
      'status': 'active',
      'rule_type': 'temporal_rule',
      'priority_band': 79,
      'specificity_band': 98,
      'jurisdiction': ['*'],
      'applies_to': {
        'subject_types': ['drug_admin', 'meal'],
        'target_selector': {'target': 'drug-meal'},
      },
      'when': {
        'all': [
          {
            'cmp': {
              'path': 'drug.id',
              'op': 'eq',
              'value': variantId,
            },
          },
          {
            'between': {
              'left_path': 'timestamps.drug_time',
              'right_path': 'timestamps.meal_time',
              'unit': 'minutes',
              'low': -before,
              'high': after.toDouble(),
            },
          },
        ],
      },
      'then': {
        'decision': 'WARN',
        'severity': 'high',
        'messages': {
          'zh': '该官方标签要求与进餐错峰：至少餐前 $before 分钟、餐后 $after 分钟。',
          'en':
              'The official label requires separation from meals by at least $before minutes before and $after minutes after.',
        },
        'actions': [
          {
            'type': 'suggest_reschedule',
            'params': {
              'preferred_before_meal_min': before,
              'preferred_after_meal_min': after,
              'source': 'imported_official_label_fact',
            },
          },
        ],
        'output_tags': ['imported_label_meal_window'],
      },
      'provenance': {
        'evidence_level': 'official_label',
        'source_refs': [sourceDocId],
      },
    };
  }

  Map<String, dynamic> _withOrWithoutFoodRule(
    String sourceDocId,
    String variantId,
    Map<String, dynamic> fact,
  ) {
    return {
      'rule_id': 'imported.label.${_slug(variantId)}.with_or_without_food',
      'version': '1.0.0',
      'status': 'active',
      'rule_type': 'soft_rule',
      'priority_band': 25,
      'specificity_band': 98,
      'jurisdiction': ['*'],
      'applies_to': {
        'subject_types': ['drug_admin', 'meal'],
        'target_selector': {'target': 'drug-meal'},
      },
      'when': {
        'all': [
          {
            'cmp': {
              'path': 'drug.id',
              'op': 'eq',
              'value': variantId,
            },
          },
          {
            'exists': {
              'path': 'meal.id',
            },
          },
        ],
      },
      'then': {
        'decision': 'INFO',
        'severity': 'low',
        'messages': {
          'zh': '该官方标签说明本品可与食物同服或空腹服用。',
          'en':
              'The official label indicates this product may be taken with or without food.',
        },
        'actions': const [],
        'output_tags': ['imported_label_with_or_without_food'],
      },
      'provenance': {
        'evidence_level': 'official_label',
        'source_refs': [sourceDocId],
      },
    };
  }

  Map<String, dynamic>? _highFatDelayRule(
    String sourceDocId,
    String variantId,
    Map<String, dynamic> fact,
  ) {
    final payload = _coerceMap(fact['payload']);
    final delayHours = (payload['delay_hours'] as num?)?.toDouble();
    return {
      'rule_id': 'imported.label.${_slug(variantId)}.high_fat_delay',
      'version': '1.0.0',
      'status': 'active',
      'rule_type': 'temporal_rule',
      'priority_band': 78,
      'specificity_band': 98,
      'jurisdiction': ['*'],
      'applies_to': {
        'subject_types': ['drug_admin', 'meal'],
        'target_selector': {'target': 'drug-meal'},
      },
      'when': {
        'all': [
          {
            'cmp': {
              'path': 'drug.id',
              'op': 'eq',
              'value': variantId,
            },
          },
          {
            'cmp': {
              'path': 'meal.high_fat_high_calorie',
              'op': 'eq',
              'value': true,
            },
          },
          {
            'between': {
              'left_path': 'timestamps.drug_time',
              'right_path': 'timestamps.meal_time',
              'unit': 'minutes',
              'low': 0,
              'high': 120,
            },
          },
        ],
      },
      'then': {
        'decision': 'WARN',
        'severity': 'high',
        'messages': {
          'zh': delayHours == null
              ? '该官方标签提示高脂/高热量餐可能延迟吸收或起效。'
              : '该官方标签提示高脂/高热量餐可能延迟吸收或起效，延迟约 ${delayHours.toString()} 小时。',
          'en': delayHours == null
              ? 'The official label warns that a high-fat/high-calorie meal may delay absorption or onset.'
              : 'The official label warns that a high-fat/high-calorie meal may delay absorption or onset by about ${delayHours.toString()} hours.',
        },
        'actions': [
          {
            'type': 'suggest_reschedule',
            'params': {
              'preferred_before_meal_min': 60,
              'preferred_before_meal_max': 120,
              'source': 'imported_official_label_fact',
            },
          },
        ],
        'output_tags': ['imported_label_high_fat_delay'],
      },
      'provenance': {
        'evidence_level': 'official_label',
        'source_refs': [sourceDocId],
      },
    };
  }

  Map<String, dynamic>? _tyramineThresholdRule(
    String sourceDocId,
    String variantId,
    Map<String, dynamic> fact,
  ) {
    final payload = _coerceMap(fact['payload']);
    final thresholdMg = (payload['threshold_mg'] as num?)?.toDouble();
    if (thresholdMg == null || thresholdMg <= 0) return null;
    return {
      'rule_id': 'imported.label.${_slug(variantId)}.tyramine_threshold',
      'version': '1.0.0',
      'status': 'active',
      'rule_type': 'dose_dependent_rule',
      'priority_band': 84,
      'specificity_band': 98,
      'jurisdiction': ['*'],
      'applies_to': {
        'subject_types': ['drug_admin', 'meal'],
        'target_selector': {'target': 'drug-meal'},
      },
      'when': {
        'all': [
          {
            'cmp': {
              'path': 'drug.id',
              'op': 'eq',
              'value': variantId,
            },
          },
          {
            'cmp': {
              'path': 'meal.tyramine_mg_est',
              'op': 'gt',
              'value': thresholdMg,
            },
          },
        ],
      },
      'then': {
        'decision': 'WARN',
        'severity': 'critical',
        'messages': {
          'zh': '该官方标签提示极高酪胺摄入应避免（阈值约 $thresholdMg mg）。',
          'en':
              'The official label warns to avoid extremely high tyramine intake (threshold about $thresholdMg mg).',
        },
        'actions': [
          {
            'type': 'avoid_food',
            'params': {
              'reason_code': 'imported_label_tyramine_threshold',
              'threshold_mg': thresholdMg,
            },
          },
        ],
        'output_tags': ['imported_label_tyramine_threshold'],
      },
      'provenance': {
        'evidence_level': 'official_label',
        'source_refs': [sourceDocId],
      },
    };
  }

  Map<String, dynamic> _ironInteractionRule(
    String sourceDocId,
    String variantId,
    Map<String, dynamic> fact,
  ) {
    return {
      'rule_id': 'imported.label.${_slug(variantId)}.iron_interaction',
      'version': '1.0.0',
      'status': 'active',
      'rule_type': 'soft_rule',
      'priority_band': 80,
      'specificity_band': 98,
      'jurisdiction': ['*'],
      'applies_to': {
        'subject_types': ['drug_admin', 'coevent'],
        'target_selector': {'target': 'drug-coevent'},
      },
      'when': {
        'all': [
          {
            'cmp': {
              'path': 'drug.id',
              'op': 'eq',
              'value': variantId,
            },
          },
          {
            'in': {
              'path': 'coevent.substance_tags',
              'values': ['iron_salt', 'multivitamin_with_iron'],
            },
          },
        ],
      },
      'then': {
        'decision': 'WARN',
        'severity': 'high',
        'messages': {
          'zh': '该官方标签提示铁剂或含铁复合维生素可能影响本品吸收或生物利用度。',
          'en':
              'The official label warns that iron salts or multivitamins with iron may affect absorption or bioavailability.',
        },
        'actions': [
          {
            'type': 'emit_machine_tag',
            'params': {
              'tag': 'imported_label_iron_interaction',
              'source': 'imported_official_label_fact',
            },
          },
        ],
        'output_tags': ['imported_label_iron_interaction'],
      },
      'provenance': {
        'evidence_level': 'official_label',
        'source_refs': [sourceDocId],
      },
    };
  }

  Map<String, dynamic> _starchThickenerRule(
    String sourceDocId,
    String variantId,
    Map<String, dynamic> fact,
  ) {
    return {
      'rule_id':
          'imported.label.${_slug(variantId)}.starch_thickener_incompatibility',
      'version': '1.0.0',
      'status': 'active',
      'rule_type': 'hard_constraint',
      'priority_band': 95,
      'specificity_band': 98,
      'jurisdiction': ['*'],
      'applies_to': {
        'subject_types': ['drug_admin', 'coevent'],
        'target_selector': {'target': 'drug-coevent'},
      },
      'when': {
        'all': [
          {
            'cmp': {
              'path': 'drug.id',
              'op': 'eq',
              'value': variantId,
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
          'zh': '该官方标签提示不得与淀粉型增稠剂混用。',
          'en':
              'The official label indicates this product should not be mixed with a starch-based thickener.',
        },
        'actions': [
          {
            'type': 'avoid_combination',
            'params': {
              'reason_code': 'imported_label_starch_thickener_incompatibility',
            },
          },
          {
            'type': 'switch_thickener',
            'params': {
              'suggested': 'xanthan_based_or_review',
            },
          },
        ],
        'output_tags': ['imported_label_starch_thickener_incompatibility'],
      },
      'provenance': {
        'evidence_level': 'official_label',
        'source_refs': [sourceDocId],
      },
    };
  }

  Map<String, dynamic> _enteralFeedReviewRule(
    String sourceDocId,
    String variantId,
    Map<String, dynamic> fact,
  ) {
    return {
      'rule_id': 'imported.label.${_slug(variantId)}.enteral_feed_review',
      'version': '1.0.0',
      'status': 'active',
      'rule_type': 'escalation_rule',
      'priority_band': 90,
      'specificity_band': 98,
      'jurisdiction': ['*'],
      'applies_to': {
        'subject_types': ['drug_admin', 'enteral_feed'],
        'target_selector': {'target': 'drug-enteral-feed'},
      },
      'when': {
        'all': [
          {
            'cmp': {
              'path': 'drug.id',
              'op': 'eq',
              'value': variantId,
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
            'exists': {
              'path': 'enteral_feed.protein_g_per_day',
            },
          },
        ],
      },
      'then': {
        'decision': 'REQUIRE_REVIEW',
        'severity': 'critical',
        'messages': {
          'zh': '该官方标签提示肠内营养场景需要人工评估。',
          'en':
              'The official label indicates enteral feeding should be reviewed manually.',
        },
        'actions': [
          {
            'type': 'require_manual_review',
            'params': {
              'review_queue': 'pd_nutrition_pharmacy',
            },
          },
        ],
        'output_tags': ['imported_label_enteral_feed_review'],
      },
      'provenance': {
        'evidence_level': 'official_label',
        'source_refs': [sourceDocId],
      },
    };
  }

  Map<String, dynamic> _coerceMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return <String, dynamic>{};
  }

  String _slug(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}
