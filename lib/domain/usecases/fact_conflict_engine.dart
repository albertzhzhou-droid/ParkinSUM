import '../../core/utils/qualified_value_parser.dart';
import '../entities/cdss_records.dart';
import '../entities/cdss_runtime.dart';

/// First-pass ingest conflict classifier.
///
/// 当前状态说明：
/// - 这是一个“能用的最小版”，已经可以区分 missing / parsing uncertainty /
///   override / coexist variant / variation / contradiction。
/// - cluster 解析会输出 accepted/rejected rationale、来源权威性、新鲜度、
///   extraction confidence、scope/tolerance 解释；人工工单流仍由上层治理承接。
class FactConflictResult {
  final FactConflictType type;
  final String reason;
  final String rejectedRationaleJson;
  final bool autoResolved;
  final bool needsManualReview;

  const FactConflictResult({
    required this.type,
    required this.reason,
    this.rejectedRationaleJson = '[]',
    this.autoResolved = false,
    this.needsManualReview = false,
  });
}

class FactConflictEngine {
  ClusterFactResolution resolveCluster({
    required List<ObservationRecord> observations,
    required List<ResolvedFactRecord> existingFacts,
    required Map<String, SourceDocumentRecord> sourceDocumentsById,
    Map<String, VariantScopeRecord> scopesByHash =
        const <String, VariantScopeRecord>{},
    Map<String, String> manualOverrides = const <String, String>{},
  }) {
    if (observations.isEmpty) {
      return const ClusterFactResolution(
        status: 'empty_cluster',
        chosenObservation: null,
        rejectedRationales: <Map<String, dynamic>>[],
        explanation: 'No observations were available for this cluster.',
        needsManualReview: true,
      );
    }
    final candidates = observations.map((observation) {
      final source = sourceDocumentsById[observation.sourceDocId];
      return _RankedObservation(
        observation: observation,
        scope: scopesByHash[observation.scopeHash],
        authorityScore: _authorityScore(source),
        freshnessScore: source?.effectiveAt?.millisecondsSinceEpoch ??
            source?.publishedAt?.millisecondsSinceEpoch ??
            0,
        confidenceScore: observation.extractionConfidence,
        scopeKey: _scopeKey(observation),
      );
    }).toList(growable: false);
    final manualObservationId = manualOverrides['observation_id'];
    final chosen = manualObservationId == null
        ? ([...candidates]..sort(_compareRankedObservation)).first
        : candidates.firstWhere(
            (item) => item.observation.observationId == manualObservationId,
            orElse: () =>
                ([...candidates]..sort(_compareRankedObservation)).first,
          );
    final acceptedRationale = {
      'observation_id': chosen.observation.observationId,
      'source_doc_id': chosen.observation.sourceDocId,
      'rationale': manualObservationId == null
          ? 'accepted_highest_ranked_candidate'
          : 'accepted_manual_override',
      'ranking': chosen.toRankingJson(),
      'ranking_explanation': _rankingExplanation(chosen),
      'manual_override': manualObservationId != null,
      'manual_override_reason': manualObservationId == null
          ? null
          : (manualOverrides['reason'] ?? 'manual_override_requested'),
      'source_authority': chosen.authorityScore,
      'freshness': chosen.freshnessScore,
      'extraction_confidence': chosen.confidenceScore,
    };
    final rejected = <Map<String, dynamic>>[];
    var hasContradiction = false;
    for (final candidate in candidates) {
      if (candidate.observation.observationId ==
          chosen.observation.observationId) {
        continue;
      }
      final sameSource =
          candidate.observation.sourceDocId == chosen.observation.sourceDocId;
      final overlaps = intervalsOverlap(
          candidate.observation.value, chosen.observation.value);
      final tolerance = _numericTolerance(
        candidate.observation.value,
        chosen.observation.value,
      );
      final scopeComparison = _scopeComparison(candidate.scope, chosen.scope);
      hasContradiction = hasContradiction || (!sameSource && !overlaps);
      final rationale = _rejectionReason(
        sameSource: sameSource,
        overlaps: overlaps,
        tolerance: tolerance,
        scopeComparison: scopeComparison,
        rejected: candidate,
        accepted: chosen,
      );
      rejected.add({
        'observation_id': candidate.observation.observationId,
        'source_doc_id': candidate.observation.sourceDocId,
        'rationale': rationale,
        'ranking': candidate.toRankingJson(),
        'accepted_ranking': chosen.toRankingJson(),
        'scope_match': scopeComparison['scope_match'],
        'scope_match_details': scopeComparison,
        'scope_mismatch_dimensions': scopeComparison['mismatch_dimensions'],
        'numeric_overlap': overlaps,
        'numeric_overlap_result': {
          'overlaps': overlaps,
          'accepted': _valueIntervalJson(chosen.observation.value),
          'rejected': _valueIntervalJson(candidate.observation.value),
        },
        'tolerance': tolerance,
        'tolerance_result': tolerance,
        'source_authority': candidate.authorityScore,
        'freshness': candidate.freshnessScore,
        'extraction_confidence': candidate.confidenceScore,
        'manual_override': manualObservationId != null,
        'manual_override_reason': manualObservationId == null
            ? null
            : (manualOverrides['reason'] ?? 'manual_override_requested'),
        'ranking_explanation': _rejectionExplanation(
          rejected: candidate,
          accepted: chosen,
          rationale: rationale,
          scopeComparison: scopeComparison,
          tolerance: tolerance,
        ),
        'same_source_duplicate': sameSource,
        'cross_source_contradiction': !sameSource && !overlaps,
        'value_overlap': overlaps,
      });
    }
    return ClusterFactResolution(
      status: manualObservationId == null ? 'auto_resolved' : 'manual_override',
      chosenObservation: chosen.observation,
      acceptedRationale: acceptedRationale,
      rejectedRationales: rejected,
      explanation: manualObservationId == null
          ? 'Cluster resolved by authority, freshness, extraction confidence, and scoped comparability.'
          : 'Cluster resolved by manual override.',
      needsManualReview: hasContradiction && manualObservationId == null,
    );
  }

  FactConflictResult classify({
    required ObservationRecord observation,
    required List<ResolvedFactRecord> existingFacts,
  }) {
    // 缺值不进入自动事实解析；这里直接标记为输入不完整。
    if (observation.value.qualifierKind == QualifierKind.missing) {
      return const FactConflictResult(
        type: FactConflictType.incompleteInput,
        reason: 'Observation is missing required value payload.',
        rejectedRationaleJson:
            '[{"rationale":"missing_required_value","needs_human_review":true}]',
        needsManualReview: true,
      );
    }
    // 如果限定语解析本身就不确定，先保留不确定性，而不是强行归并到数值冲突。
    if (observation.value.qualifierKind == QualifierKind.parsingUncertainty) {
      return const FactConflictResult(
        type: FactConflictType.parsingUncertainty,
        reason: 'Observation value could not be normalized confidently.',
        rejectedRationaleJson:
            '[{"rationale":"parsing_uncertainty","needs_human_review":true}]',
        needsManualReview: true,
      );
    }

    for (final fact in existingFacts) {
      // 手工覆盖优先于自动解析；后续完整版本应把覆盖链与审计原因写得更细。
      if (fact.manualOverride) {
        return FactConflictResult(
          type: FactConflictType.override,
          reason:
              'Existing resolved fact ${fact.factId} is marked as manual override.',
          rejectedRationaleJson:
              '[{"rationale":"manual_override_preserved","fact_id":"${fact.factId}"}]',
          autoResolved: true,
        );
      }

      // scope 不同先按“可并存变体”处理，避免把跨辖区/跨加工态差异误判成冲突。
      if (fact.scopeHash != observation.scopeHash) {
        return const FactConflictResult(
          type: FactConflictType.coexistVariant,
          reason:
              'Observation belongs to a different comparable scope and should co-exist as a variant.',
          rejectedRationaleJson:
              '[{"rationale":"different_scope_coexists","scope_dimensions":["jurisdiction","dosage_form","release_type","route","preparation_state"]}]',
          autoResolved: true,
        );
      }

      // 单条 classify 只做轻量判断；cluster 排序负责更完整的 provenance/tolerance rationale。
      if (intervalsOverlap(observation.value, fact.resolvedValue)) {
        return FactConflictResult(
          type: FactConflictType.variation,
          reason:
              'Observation overlaps existing fact interval for ${fact.attributeCode}.',
          rejectedRationaleJson:
              '[{"rationale":"overlapping_interval_variation","fact_id":"${fact.factId}"}]',
          autoResolved: true,
        );
      }
    }

    if (existingFacts.isNotEmpty) {
      // 这里的 contradiction 仍是保守的一刀切判定。
      // 未来应改为 cluster 级别分析，再决定是否 auto-resolve 或 escalate。
      return const FactConflictResult(
        type: FactConflictType.contradiction,
        reason: 'Observation does not overlap any co-existing resolved fact.',
        rejectedRationaleJson:
            '[{"rationale":"cross_source_or_cross_scope_contradiction","needs_human_review":true}]',
        needsManualReview: true,
      );
    }

    return const FactConflictResult(
      type: FactConflictType.variation,
      reason: 'No existing facts for this key; treat as first candidate fact.',
      rejectedRationaleJson: '[]',
      autoResolved: true,
    );
  }

  int _compareRankedObservation(
      _RankedObservation left, _RankedObservation right) {
    final authority = right.authorityScore.compareTo(left.authorityScore);
    if (authority != 0) return authority;
    final confidence = right.confidenceScore.compareTo(left.confidenceScore);
    if (confidence != 0) return confidence;
    final freshness = right.freshnessScore.compareTo(left.freshnessScore);
    if (freshness != 0) return freshness;
    return left.observation.observationId
        .compareTo(right.observation.observationId);
  }

  String _rankingExplanation(_RankedObservation accepted) {
    return 'Accepted by source authority ${accepted.authorityScore}, '
        'extraction confidence ${accepted.confidenceScore}, '
        'freshness ${accepted.freshnessScore}, and scope ${accepted.scopeKey}.';
  }

  String _rejectionExplanation({
    required _RankedObservation rejected,
    required _RankedObservation accepted,
    required String rationale,
    required Map<String, dynamic> scopeComparison,
    required Map<String, dynamic> tolerance,
  }) {
    final reasons = <String>[rationale];
    if (rejected.authorityScore != accepted.authorityScore) {
      reasons.add(
        'authority ${rejected.authorityScore} < ${accepted.authorityScore}',
      );
    }
    if (rejected.confidenceScore != accepted.confidenceScore) {
      reasons.add(
        'extraction_confidence ${rejected.confidenceScore} < ${accepted.confidenceScore}',
      );
    }
    if (rejected.freshnessScore != accepted.freshnessScore) {
      reasons.add(
        'freshness ${rejected.freshnessScore} < ${accepted.freshnessScore}',
      );
    }
    if (rejected.scopeKey != accepted.scopeKey) {
      reasons.add('scope differs from accepted candidate');
    }
    if (scopeComparison['scope_match'] == false) {
      reasons.add('scope_mismatch ${scopeComparison['mismatch_dimensions']}');
    }
    if (tolerance['out_of_tolerance'] == true) {
      reasons.add('out_of_tolerance delta ${tolerance['delta']}');
    }
    return reasons.join('; ');
  }

  String _rejectionReason({
    required bool sameSource,
    required bool overlaps,
    required Map<String, dynamic> tolerance,
    required Map<String, dynamic> scopeComparison,
    required _RankedObservation rejected,
    required _RankedObservation accepted,
  }) {
    if (scopeComparison['scope_match'] == false) return 'scope_mismatch';
    if (!overlaps && tolerance['out_of_tolerance'] == true) {
      return 'out_of_tolerance';
    }
    if (sameSource) return 'same_source_duplicate_lower_rank';
    if (!overlaps) return 'cross_source_contradiction_lower_rank';
    if (rejected.authorityScore < accepted.authorityScore) {
      return 'lower_authority';
    }
    if (rejected.freshnessScore < accepted.freshnessScore) {
      return 'older_source';
    }
    if (rejected.confidenceScore < accepted.confidenceScore) {
      return 'lower_extraction_confidence';
    }
    return 'cross_source_variation_lower_rank';
  }

  Map<String, dynamic> _numericTolerance(
    QualifiedValue rejected,
    QualifiedValue accepted,
  ) {
    final rejectedValue = rejected.valueNum ?? rejected.low ?? rejected.high;
    final acceptedValue = accepted.valueNum ?? accepted.low ?? accepted.high;
    if (rejectedValue == null || acceptedValue == null) {
      return const <String, dynamic>{
        'comparable': false,
        'out_of_tolerance': false,
      };
    }
    final delta = (rejectedValue - acceptedValue).abs();
    final denominator =
        acceptedValue.abs() < 0.000001 ? 1.0 : acceptedValue.abs().toDouble();
    final relativeDelta = delta / denominator;
    return {
      'comparable': true,
      'delta': delta,
      'relative_delta': relativeDelta,
      'threshold_relative': 0.05,
      'out_of_tolerance': relativeDelta > 0.05,
      'result': relativeDelta > 0.05 ? 'out_of_tolerance' : 'within_tolerance',
    };
  }

  Map<String, dynamic> _valueIntervalJson(QualifiedValue value) => {
        'low': value.low,
        'high': value.high,
        'value_num': value.valueNum,
        'qualifier_kind': value.qualifierKind.wireValue,
        'raw_value_text': value.rawValueText,
      };

  Map<String, dynamic> _scopeComparison(
    VariantScopeRecord? rejected,
    VariantScopeRecord? accepted,
  ) {
    if (rejected == null || accepted == null) {
      return {
        'scope_match': rejected?.scopeHash == accepted?.scopeHash,
        'mismatch_dimensions': rejected?.scopeHash == accepted?.scopeHash
            ? const <String>[]
            : const ['scope_hash'],
      };
    }
    final mismatches = <String>[];
    void compare(String dimension, Object? left, Object? right) {
      final l = left?.toString() ?? '';
      final r = right?.toString() ?? '';
      if (l != r) mismatches.add(dimension);
    }

    compare('jurisdiction', rejected.jurisdiction, accepted.jurisdiction);
    compare('dosage_form', rejected.dosageForm, accepted.dosageForm);
    compare('release_type', rejected.releaseType, accepted.releaseType);
    compare('route', rejected.route, accepted.route);
    compare('preparation_state', rejected.preparationState,
        accepted.preparationState);
    compare('cooking_state', rejected.cookingState, accepted.cookingState);
    compare('sampling_frame', rejected.samplingFrame, accepted.samplingFrame);
    return {
      'scope_match': mismatches.isEmpty,
      'mismatch_dimensions': mismatches,
    };
  }

  int _authorityScore(SourceDocumentRecord? source) {
    switch (source?.dataTier) {
      case KnowledgeDataTier.p0:
        return 100;
      case KnowledgeDataTier.p1:
        return 90;
      case KnowledgeDataTier.p2:
        return 70;
      default:
        return 40;
    }
  }

  String _scopeKey(ObservationRecord observation) {
    return [
      observation.domain,
      observation.entityType,
      observation.entityKey,
      observation.attributeCode,
      observation.scopeHash,
      observation.unit,
      observation.basisType,
    ].join('|');
  }
}

class ClusterFactResolution {
  final String status;
  final ObservationRecord? chosenObservation;
  final Map<String, dynamic> acceptedRationale;
  final List<Map<String, dynamic>> rejectedRationales;
  final String explanation;
  final bool needsManualReview;

  const ClusterFactResolution({
    required this.status,
    required this.chosenObservation,
    this.acceptedRationale = const <String, dynamic>{},
    required this.rejectedRationales,
    required this.explanation,
    required this.needsManualReview,
  });
}

class _RankedObservation {
  final ObservationRecord observation;
  final VariantScopeRecord? scope;
  final int authorityScore;
  final int freshnessScore;
  final double confidenceScore;
  final String scopeKey;

  const _RankedObservation({
    required this.observation,
    required this.scope,
    required this.authorityScore,
    required this.freshnessScore,
    required this.confidenceScore,
    required this.scopeKey,
  });

  Map<String, dynamic> toRankingJson() => {
        'authority': authorityScore,
        'freshness': freshnessScore,
        'extraction_confidence': confidenceScore,
        'scope_key': scopeKey,
        'scope': {
          'jurisdiction': scope?.jurisdiction,
          'dosage_form': scope?.dosageForm,
          'release_type': scope?.releaseType,
          'route': scope?.route,
          'preparation_state': scope?.preparationState,
          'cooking_state': scope?.cookingState,
          'sampling_frame': scope?.samplingFrame,
        },
      };
}
