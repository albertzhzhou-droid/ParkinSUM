import '../i18n/app_i18n.dart';
import '../models/interaction_result.dart';

/// Optional seam for a future local-AI wording optimizer.
///
/// Safety decisions, scores, rule hits, and evidence references must already be
/// produced before this interface is called. A local model may only rewrite the
/// wording of `draftText`; it must not add new medical facts or change actions.
abstract class LocalResponsePolisher {
  Future<String?> polishResponseCopy(ResponseCopyRequest request);
}

class ResponseCopyRequest {
  final String localeTag;
  final String context;
  final String draftText;
  final List<String> protectedFacts;

  const ResponseCopyRequest({
    required this.localeTag,
    required this.context,
    required this.draftText,
    this.protectedFacts = const <String>[],
  });
}

/// Converts engine/runtime wording into product-facing copy.
///
/// This layer intentionally sits above CDSS and recommendation logic. The
/// engines can keep stable machine codes, while UI pages call this service to
/// avoid exposing implementation terms such as `conservative_safety_gate` or
/// raw English fallback strings to patients.
class ResponseCopyService {
  final AppI18n i18n;
  final LocalResponsePolisher? localPolisher;

  const ResponseCopyService({
    required this.i18n,
    this.localPolisher,
  });

  String recommendationPath(String path) {
    return i18n.recommendationPathLabel(path);
  }

  String recommendationMessage(String message) {
    return _humanize(i18n.recommendationRuntimeMessage(message));
  }

  String interactionText(String text) {
    return _humanize(text);
  }

  String interactionSummary(InteractionResult result) {
    if (result.status == InteractionStatus.ok || result.score == 0) {
      return interactionText(result.summary);
    }
    if (_hasMissingCriticalInputs(result)) {
      return i18n.tr(
        'copy.interaction_summary_missing_inputs',
        {
          'score': '${result.score}',
          'missing': _joinLabels(_missingInputLabels(result)),
        },
      );
    }
    if (result.score >= 70) {
      return i18n.tr(
        'copy.interaction_summary_high',
        {'score': '${result.score}'},
      );
    }
    return interactionText(result.summary);
  }

  String interactionAnalysis(InteractionResult result) {
    if (result.status == InteractionStatus.ok || result.score == 0) {
      return interactionText(result.analysisText);
    }
    final protein = _extractProtein(result.analysisText);
    final parts = <String>[];
    if (_hasMissingCriticalInputs(result)) {
      parts.add(
        i18n.tr(
          'copy.interaction_analysis_missing_inputs',
          {
            'missing': _joinLabels(_missingInputLabels(result)),
          },
        ),
      );
    }
    if (protein != null) {
      parts.add(
        i18n.tr(
          'copy.interaction_analysis_protein',
          {'protein': protein},
        ),
      );
    }
    if (_mentionsFallback(result)) {
      parts.add(i18n.tr('copy.interaction_analysis_fallback'));
    }
    if (_mentionsDatabaseFacts(result)) {
      parts.add(i18n.tr('copy.interaction_analysis_database'));
    }
    parts.add(i18n.tr('copy.interaction_analysis_not_diagnosis'));
    return parts.join(' ');
  }

  String keyFinding(String text) {
    if (_containsMissingCriticalInputs(text)) {
      return i18n.tr(
        'copy.key_finding_missing_inputs',
        {'missing': _joinLabels(_missingInputLabelsFromText(text))},
      );
    }
    return interactionText(text);
  }

  String nextAction(String text) {
    if (_containsManualReview(text) || _containsMissingCriticalInputs(text)) {
      return i18n.tr('copy.next_action_complete_med_timing');
    }
    return interactionText(text);
  }

  String dataNote(String text) {
    final lower = text.toLowerCase();
    if (lower.startsWith('cdss_warning:') ||
        lower.contains('fallback_variant_resolution')) {
      return i18n.tr('copy.data_note_fallback');
    }
    if (lower.contains('fallback chain') ||
        lower.contains('fallback 链') ||
        lower.contains('回退链')) {
      return i18n.tr('copy.data_note_fallback');
    }
    if (lower.contains('database food variants') ||
        lower.contains('database nutrient facts') ||
        lower.contains('真实食物营养') ||
        lower.contains('数据库中的真实')) {
      return i18n.tr('copy.data_note_database');
    }
    if (lower.contains('missing critical input') || lower.contains('缺少关键')) {
      return i18n.tr(
        'copy.data_note_missing_input',
        {'missing': _joinLabels(_missingInputLabelsFromText(text))},
      );
    }
    return interactionText(text);
  }

  String issueTitle(String title) {
    return _humanize(title);
  }

  String issueDetail(InteractionIssue issue) {
    if (_containsMissingCriticalInputs(issue.detail)) {
      return i18n.tr(
        'copy.issue_missing_inputs',
        {'missing': _joinLabels(_missingInputLabelsFromText(issue.detail))},
      );
    }
    return interactionText(issue.detail);
  }

  Future<String> polishWithLocalAi({
    required String context,
    required String draftText,
    List<String> protectedFacts = const <String>[],
  }) async {
    final polisher = localPolisher;
    if (polisher == null) return draftText;
    final polished = await polisher.polishResponseCopy(
      ResponseCopyRequest(
        localeTag: i18n.localeTag,
        context: context,
        draftText: draftText,
        protectedFacts: protectedFacts,
      ),
    );
    final value = polished?.trim();
    return value == null || value.isEmpty ? draftText : value;
  }

  String _humanize(String text) {
    var value = text.trim();
    if (value.isEmpty) return value;

    value = _replaceKnownMachineCodes(value);
    if (i18n.languageFamily == 'zh') {
      value = _replaceChineseReadableFragments(value);
    }
    return value;
  }

  String _replaceKnownMachineCodes(String text) {
    return text
        .replaceAll(
          'Candidate still depends on local seed metadata instead of richer database-backed observations.',
          i18n.tr('recommend.local_seed_metadata'),
        )
        .replaceAll(
          'Timing window is incomplete, so the conservative rank keeps extra safety margin.',
          i18n.tr('recommend.timing_window_incomplete'),
        )
        .replaceAll(
          'Next meal window is still close to the previous meal; lower-protein option preferred.',
          i18n.tr('recommend.next_meal_gap_close'),
        )
        .replaceAll(
          'Fits the planned next-meal window and favors steadier fiber intake.',
          i18n.tr('recommend.next_meal_window_fiber'),
        )
        .replaceAll(
          'Medication timing suggests extra caution for this next-meal window.',
          i18n.tr('recommend.medication_timing_caution'),
        )
        .replaceAll(
          'CDSS-backed conservative path used real variant observations when available.',
          i18n.tr('recommend.runtime.cdss_conservative_observations'),
        )
        .replaceAll(
          'Local AI did not return a valid whitelist-only ordering.',
          i18n.tr('recommend.runtime.ai_invalid_whitelist'),
        )
        .replaceAll(
          'Levodopa timing window is too sensitive for AI reranking.',
          i18n.tr('recommend.runtime.levodopa_ai_sensitive'),
        )
        .replaceAll('conservative_safety_gate',
            i18n.recommendationPathLabel('conservative_safety_gate'))
        .replaceAll('conservative_gate_block',
            i18n.recommendationPathLabel('conservative_gate_block'))
        .replaceAll('fallback_invalid_ai',
            i18n.recommendationPathLabel('fallback_invalid_ai'))
        .replaceAll('conservative_cdss',
            i18n.recommendationPathLabel('conservative_cdss'))
        .replaceAll(
            'hybrid_local_ai', i18n.recommendationPathLabel('hybrid_local_ai'))
        .replaceAll('deterministic', i18n.tr('copy.deterministic_path'))
        .replaceAll('rerank', i18n.tr('copy.rerank'))
        .replaceAll('CDSS', i18n.tr('copy.cdss'));
  }

  String _replaceChineseReadableFragments(String text) {
    return text
        .replaceAll(
          'Safety gate kept the result on the conservative path.',
          i18n.tr('recommend.runtime.safety_gate_conservative'),
        )
        .replaceAll(
          'Returned deterministic conservative recommendations instead.',
          i18n.tr('recommend.runtime.returned_conservative'),
        )
        .replaceAll(
          'Structured local AI output failed validation.',
          i18n.tr('recommend.runtime.ai_validation_failed'),
        )
        .replaceAll(
          'No localhost Ollama/llama.cpp endpoint responded.',
          i18n.tr('recommend.runtime.local_ai_endpoint_unavailable'),
        )
        .replaceAll(
          'Endpoint must stay on localhost.',
          i18n.tr('recommend.runtime.endpoint_must_be_localhost'),
        )
        .replaceAll(
          'Next-meal time window is missing.',
          i18n.tr('recommend.runtime.next_meal_window_missing'),
        )
        .replaceAll(
          'No registered rules were triggered.',
          i18n.tr('runtime.no_rules'),
        )
        .replaceAll(
          'official label requires separation from meals',
          i18n.tr('copy.official_label_meal_separation'),
        )
        .replaceAll(
          'database food variants',
          i18n.tr('copy.database_food_variants'),
        )
        .replaceAll(
          'database nutrient facts',
          i18n.tr('copy.database_nutrient_facts'),
        );
  }

  bool _hasMissingCriticalInputs(InteractionResult result) {
    return result.issues
            .any((issue) => _containsMissingCriticalInputs(issue.detail)) ||
        result.keyFindings.any(_containsMissingCriticalInputs) ||
        result.dataNotes.any(_containsMissingCriticalInputs);
  }

  bool _containsMissingCriticalInputs(String text) {
    final lower = text.toLowerCase();
    return lower.contains('missing critical input') ||
        lower.contains('missing critical inputs') ||
        lower.contains('缺少关键') ||
        lower.contains('重要な入力が不足') ||
        lower.contains('donnees critiques manquent');
  }

  bool _containsManualReview(String text) {
    final lower = text.toLowerCase();
    return lower.contains('manual review') ||
        lower.contains('人工复核') ||
        lower.contains('手動レビュー') ||
        lower.contains('revue manuelle');
  }

  bool _mentionsFallback(InteractionResult result) {
    final combined = [
      result.analysisText,
      ...result.keyFindings,
      ...result.dataNotes,
      ...result.issues.map((issue) => issue.detail),
    ].join(' ').toLowerCase();
    return combined.contains('fallback') ||
        combined.contains('回退链') ||
        combined.contains('フォールバック');
  }

  bool _mentionsDatabaseFacts(InteractionResult result) {
    final combined = [
      result.analysisText,
      ...result.keyFindings,
      ...result.dataNotes,
      ...result.issues.map((issue) => issue.detail),
    ].join(' ').toLowerCase();
    return combined.contains('database nutrient facts') ||
        combined.contains('database food variants') ||
        combined.contains('database-backed') ||
        combined.contains('数据库');
  }

  String? _extractProtein(String text) {
    final match = RegExp(
            r'about\s+([0-9]+(?:\.[0-9]+)?)\s*g|约\s*([0-9]+(?:\.[0-9]+)?)\s*g')
        .firstMatch(text);
    return match?.group(1) ?? match?.group(2);
  }

  List<String> _missingInputLabels(InteractionResult result) {
    final labels = <String>{};
    for (final text in [
      result.analysisText,
      ...result.keyFindings,
      ...result.dataNotes,
      ...result.issues.map((issue) => issue.detail),
    ]) {
      labels.addAll(_missingInputLabelsFromText(text));
    }
    if (labels.isEmpty) {
      labels.add(i18n.tr('copy.missing_input_unknown'));
    }
    return labels.toList(growable: false);
  }

  List<String> _missingInputLabelsFromText(String text) {
    final lower = text.toLowerCase();
    final labels = <String>{};
    if (lower.contains('drug time') ||
        lower.contains('medication time') ||
        lower.contains('用药时间')) {
      labels.add(i18n.tr('missing.time'));
    }
    if (lower.contains('dose') || lower.contains('剂量')) {
      labels.add(i18n.tr('missing.dose'));
    }
    if (lower.contains('meal time') || lower.contains('进食时间')) {
      labels.add(i18n.tr('missing.meal_time'));
    }
    if (labels.isEmpty && _containsMissingCriticalInputs(text)) {
      labels.add(i18n.tr('copy.missing_input_unknown'));
    }
    return labels.toList(growable: false);
  }

  String _joinLabels(List<String> labels) {
    if (i18n.languageFamily == 'zh' || i18n.languageFamily == 'ja') {
      return labels.join('、');
    }
    if (i18n.languageFamily == 'fr') {
      return labels.join(', ');
    }
    if (labels.length == 2) {
      return '${labels.first} and ${labels.last}';
    }
    return labels.join(', ');
  }
}
