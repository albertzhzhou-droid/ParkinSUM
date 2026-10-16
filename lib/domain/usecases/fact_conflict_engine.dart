import 'dart:convert';

import '../../core/utils/qualified_value_parser.dart';
import '../entities/cdss_records.dart';
import '../entities/cdss_runtime.dart';

/// Source-scoped ingest conflict classification and complete cluster comparison.
///
/// 当前状态说明：
/// Every eligible observation pair is inspected: overlap with a broad ranked
/// candidate cannot conceal a contradiction between narrower alternatives.
/// Source identity alone does not establish duplicate evidence. Measurement
/// methods and variant scopes remain separate; ranking is not source validation.
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
    Map<String, ObservationRecord> existingObservationsById = const {},
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
    final observationIds = observations
        .map((item) => item.observationId)
        .toSet();
    if (observationIds.length != observations.length ||
        observationIds.any((id) => id.trim().isEmpty)) {
      return const ClusterFactResolution(
        status: 'invalid_observation_identity',
        chosenObservation: null,
        rejectedRationales: [],
        explanation: 'Cluster observation IDs must be non-empty and unique.',
        needsManualReview: true,
      );
    }
    // A resolved scalar alone cannot establish its measurement basis, method
    // or source identity. Recover the original observation before comparison.
    final historyIssues = <Map<String, dynamic>>[];
    final combined = {for (final row in observations) row.observationId: row};
    final incumbentManualIds = <String>{};
    final first = observations.first;
    for (final fact in existingFacts.where(
      (fact) =>
          fact.entityKey == first.entityKey &&
          fact.attributeCode == first.attributeCode,
    )) {
      final original = existingObservationsById[fact.chosenObservationId];
      if (original == null ||
          original.entityKey != fact.entityKey ||
          original.attributeCode != fact.attributeCode ||
          original.scopeHash != fact.scopeHash ||
          original.unit != fact.resolvedUnit ||
          jsonEncode(original.value.toJson()) !=
              jsonEncode(fact.resolvedValue.toJson())) {
        historyIssues.add({
          'fact_id': fact.factId,
          'observation_id': fact.chosenObservationId,
          'rationale': 'historical_observation_missing_or_inconsistent',
        });
        continue;
      }
      final incoming = combined[original.observationId];
      if (incoming != null && !_sameObservationPayload(incoming, original)) {
        historyIssues.add({
          'fact_id': fact.factId,
          'observation_id': original.observationId,
          'rationale': 'historical_observation_identity_collision',
        });
        continue;
      }
      combined[original.observationId] = original;
      if (fact.manualOverride) incumbentManualIds.add(original.observationId);
    }
    if (historyIssues.isNotEmpty) {
      historyIssues.sort(
        (a, b) => '${a['fact_id']}'.compareTo('${b['fact_id']}'),
      );
      return ClusterFactResolution(
        status: 'historical_evidence_required',
        chosenObservation: null,
        rejectedRationales: historyIssues,
        explanation:
            'Original incumbent observations must be recovered without guessing basis, method or source.',
        needsManualReview: true,
      );
    }
    observations = combined.values.toList(growable: false);
    // Numeric facts are comparable only within the same entity, attribute,
    // unit and measurement basis. Authority does not license a unit/basis
    // conversion, nor replacing a different food or medicine.
    final comparisonKeys = observations.map(_comparisonKey).toSet();
    if (comparisonKeys.length != 1) {
      return ClusterFactResolution(
        status: 'incompatible_cluster',
        chosenObservation: null,
        rejectedRationales: [
          for (final observation in observations)
            {
              'observation_id': observation.observationId,
              'rationale': 'incomparable_entity_attribute_unit_or_basis',
            },
        ],
        explanation: 'Cluster mixes identities, units or measurement bases.',
        needsManualReview: true,
      );
    }
    final unusable =
        observations
            .where((observation) => !_hasUsableInterval(observation.value))
            .toList(growable: false)
          ..sort(
            (left, right) => left.observationId.compareTo(right.observationId),
          );
    final eligible = observations
        .where((observation) => _hasUsableInterval(observation.value))
        .toList(growable: false);
    if (eligible.isEmpty) {
      return ClusterFactResolution(
        status: 'insufficient_values',
        chosenObservation: null,
        rejectedRationales: [
          for (final observation in unusable)
            {
              'observation_id': observation.observationId,
              'rationale': 'missing_uncertain_or_invalid_interval',
            },
        ],
        explanation: 'No finite ordered numeric interval is available.',
        needsManualReview: true,
      );
    }
    final candidates =
        eligible
            .map((observation) {
              final source = sourceDocumentsById[observation.sourceDocId];
              return _RankedObservation(
                observation: observation,
                scope: scopesByHash[observation.scopeHash],
                authorityScore: _authorityScore(source),
                freshnessScore:
                    source?.effectiveAt?.millisecondsSinceEpoch ??
                    source?.publishedAt?.millisecondsSinceEpoch ??
                    0,
                confidenceScore: observation.extractionConfidence,
                scopeKey: _scopeKey(observation),
              );
            })
            .toList(growable: false)
          ..sort(
            (left, right) => left.observation.observationId.compareTo(
              right.observation.observationId,
            ),
          );
    final manualObservationId = manualOverrides['observation_id'];
    if (manualObservationId != null &&
        !eligible.any((item) => item.observationId == manualObservationId)) {
      return ClusterFactResolution(
        status: 'invalid_manual_override',
        chosenObservation: null,
        rejectedRationales: [
          {
            'observation_id': manualObservationId,
            'rationale': 'manual_override_target_not_eligible',
          },
        ],
        explanation: 'Manual override target is absent or has no usable value.',
        needsManualReview: true,
      );
    }
    final retainedManualId = incumbentManualIds.length == 1
        ? incumbentManualIds.single
        : null;
    final selectedId = manualObservationId ?? retainedManualId;
    final chosen = selectedId == null
        ? ([...candidates]..sort(_compareRankedObservation)).first
        : candidates.firstWhere(
            (item) => item.observation.observationId == selectedId,
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
      'incumbent_manual_choice_retained':
          retainedManualId != null && manualObservationId == null,
      'manual_override_reason': manualObservationId == null
          ? null
          : (manualOverrides['reason'] ?? 'manual_override_requested'),
      'source_authority': chosen.authorityScore,
      'freshness': chosen.freshnessScore,
      'extraction_confidence': chosen.confidenceScore,
    };
    final rejected = <Map<String, dynamic>>[
      for (final observation in unusable)
        {
          'observation_id': observation.observationId,
          'source_doc_id': observation.sourceDocId,
          'rationale': 'missing_uncertain_or_invalid_interval',
          'cross_source_contradiction': false,
          'numeric_comparable': false,
        },
    ];
    final comparisons = <Map<String, dynamic>>[];
    for (var leftIndex = 0; leftIndex < candidates.length; leftIndex++) {
      for (
        var rightIndex = leftIndex + 1;
        rightIndex < candidates.length;
        rightIndex++
      ) {
        final left = candidates[leftIndex];
        final right = candidates[rightIndex];
        final scope = _scopeComparison(left, right);
        final comparable = scope['scope_match'] == true;
        final overlaps = _intervalsOverlap(
          left.observation.value,
          right.observation.value,
        );
        final duplicate = _sameProvenSourceEvidence(
          left.observation,
          right.observation,
        );
        final sameSource =
            left.observation.sourceDocId == right.observation.sourceDocId;
        comparisons.add({
          'left_observation_id': left.observation.observationId,
          'right_observation_id': right.observation.observationId,
          'left_source_doc_id': left.observation.sourceDocId,
          'right_source_doc_id': right.observation.sourceDocId,
          'relation': !comparable
              ? (scope['mismatch_dimensions'] as List).contains('method_code')
                    ? 'coexisting_method'
                    : 'coexisting_scope'
              : !overlaps
              ? 'contradiction'
              : duplicate
              ? 'proven_source_duplicate'
              : 'overlapping_evidence',
          'numeric_comparable': comparable,
          'numeric_overlap': comparable ? overlaps : null,
          'same_source_document': sameSource,
          'proven_source_duplicate': duplicate,
          'scope_match_details': scope,
          'left_interval': _valueIntervalJson(left.observation.value),
          'right_interval': _valueIntervalJson(right.observation.value),
        });
      }
    }
    final hasContradiction = comparisons.any(
      (edge) => edge['relation'] == 'contradiction',
    );
    final requiresReview = hasContradiction || incumbentManualIds.isNotEmpty;
    for (final candidate in candidates) {
      if (candidate.observation.observationId ==
          chosen.observation.observationId) {
        continue;
      }
      final sameSource =
          candidate.observation.sourceDocId == chosen.observation.sourceDocId;
      final overlaps = _intervalsOverlap(
        candidate.observation.value,
        chosen.observation.value,
      );
      final tolerance = _numericTolerance(
        candidate.observation.value,
        chosen.observation.value,
      );
      final scopeComparison = _scopeComparison(candidate, chosen);
      final comparable = scopeComparison['scope_match'] == true;
      final contradiction = comparable && !sameSource && !overlaps;
      final sameSourceContradiction = comparable && sameSource && !overlaps;
      final provenDuplicate = _sameProvenSourceEvidence(
        candidate.observation,
        chosen.observation,
      );
      final rationale = _rejectionReason(
        sameSource: sameSource,
        provenDuplicate: provenDuplicate,
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
        'same_source_duplicate': provenDuplicate,
        'same_source_document': sameSource,
        'same_source_contradiction': sameSourceContradiction,
        'cross_source_contradiction': contradiction,
        'numeric_comparable': comparable,
        'value_overlap': overlaps,
      });
    }
    acceptedRationale['selection_role'] =
        requiresReview && manualObservationId == null
        ? 'ranked_candidate_pending_conflict_review'
        : 'ranked_or_manually_selected_candidate';
    return ClusterFactResolution(
      status: manualObservationId != null
          ? 'manual_override'
          : requiresReview
          ? 'review_required'
          : 'auto_resolved',
      chosenObservation: chosen.observation,
      acceptedRationale: acceptedRationale,
      rejectedRationales: rejected,
      comparisonEdges: List.unmodifiable(comparisons),
      explanation: manualObservationId != null
          ? 'Manual selection retained alongside the complete comparison evidence.'
          : requiresReview
          ? (hasContradiction
                ? 'Comparable evidence contradicts within the cluster; the ranked candidate requires review.'
                : 'An incumbent manual selection is retained and requires explicit review before replacement.')
          : 'Cluster ranked by authority, extraction confidence and freshness with scoped method comparisons.',
      needsManualReview: requiresReview && manualObservationId == null,
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

    if (!_hasUsableInterval(observation.value)) {
      return const FactConflictResult(
        type: FactConflictType.parsingUncertainty,
        reason: 'Observation has a non-finite or reversed numeric interval.',
        needsManualReview: true,
      );
    }

    final relevantFacts = existingFacts
        .where(
          (fact) =>
              fact.entityKey == observation.entityKey &&
              fact.attributeCode == observation.attributeCode,
        )
        .toList(growable: false);
    if (relevantFacts.isEmpty) {
      return const FactConflictResult(
        type: FactConflictType.variation,
        reason:
            'No existing facts for this key; treat as first candidate fact.',
        rejectedRationaleJson: '[]',
        autoResolved: true,
      );
    }

    final sameScopeFacts = relevantFacts
        .where((fact) => fact.scopeHash == observation.scopeHash)
        .toList(growable: false);
    if (sameScopeFacts.isEmpty) {
      return const FactConflictResult(
        type: FactConflictType.coexistVariant,
        reason:
            'Observation belongs to a different comparable scope and should co-exist as a variant.',
        rejectedRationaleJson:
            '[{"rationale":"different_scope_coexists","scope_dimensions":["jurisdiction","dosage_form","release_type","route","preparation_state"]}]',
        autoResolved: true,
      );
    }

    final comparableFacts = sameScopeFacts
        .where((fact) => fact.resolvedUnit == observation.unit)
        .toList(growable: false);
    if (comparableFacts.isEmpty) {
      return const FactConflictResult(
        type: FactConflictType.parsingUncertainty,
        reason:
            'Same-scope facts use a different unit; conversion is required.',
        rejectedRationaleJson:
            '[{"rationale":"unit_mismatch_requires_explicit_conversion"}]',
        needsManualReview: true,
      );
    }
    final rationale = <Map<String, dynamic>>[];
    var hasContradiction = false;
    var hasUsableFact = false;
    var hasManualOverride = false;
    final orderedFacts = [...comparableFacts]
      ..sort((a, b) => a.factId.compareTo(b.factId));
    for (final fact in orderedFacts) {
      // 手工覆盖优先于自动解析；后续完整版本应把覆盖链与审计原因写得更细。
      if (fact.manualOverride) {
        hasManualOverride = true;
        rationale.add({
          'rationale': 'manual_override_preserved',
          'fact_id': fact.factId,
        });
      }

      if (!_hasUsableInterval(fact.resolvedValue)) {
        rationale.add({
          'rationale': 'incumbent_value_unusable',
          'fact_id': fact.factId,
        });
        continue;
      }
      hasUsableFact = true;

      // 单条 classify 只做轻量判断；cluster 排序负责更完整的 provenance/tolerance rationale。
      if (_intervalsOverlap(observation.value, fact.resolvedValue)) {
        rationale.add({
          'rationale': 'overlapping_interval_variation',
          'fact_id': fact.factId,
        });
      } else {
        hasContradiction = true;
        rationale.add({
          'rationale': 'same_scope_non_overlapping_contradiction',
          'fact_id': fact.factId,
          'needs_human_review': true,
        });
      }
    }

    if (!hasUsableFact) {
      return const FactConflictResult(
        type: FactConflictType.incompleteInput,
        reason: 'Comparable existing facts have no usable numeric value.',
        needsManualReview: true,
      );
    }

    // 同实体、同属性、同 scope 的既有事实均不重叠，保守保留矛盾。
    return FactConflictResult(
      type: hasManualOverride
          ? FactConflictType.override
          : hasContradiction
          ? FactConflictType.contradiction
          : FactConflictType.variation,
      reason: hasManualOverride
          ? 'Existing manual selections are preserved; all incumbent intervals were inspected.'
          : hasContradiction
          ? 'At least one comparable incumbent contradicts the observation.'
          : 'All usable comparable incumbent intervals overlap.',
      rejectedRationaleJson: jsonEncode(rationale),
      autoResolved: !hasContradiction,
      needsManualReview: hasContradiction,
    );
  }

  int _compareRankedObservation(
    _RankedObservation left,
    _RankedObservation right,
  ) {
    final authority = right.authorityScore.compareTo(left.authorityScore);
    if (authority != 0) return authority;
    final confidence = right.confidenceScore.compareTo(left.confidenceScore);
    if (confidence != 0) return confidence;
    final freshness = right.freshnessScore.compareTo(left.freshnessScore);
    if (freshness != 0) return freshness;
    return left.observation.observationId.compareTo(
      right.observation.observationId,
    );
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
    required bool provenDuplicate,
    required bool overlaps,
    required Map<String, dynamic> tolerance,
    required Map<String, dynamic> scopeComparison,
    required _RankedObservation rejected,
    required _RankedObservation accepted,
  }) {
    if ((scopeComparison['mismatch_dimensions'] as List?)?.contains(
          'method_code',
        ) ==
        true) {
      return 'method_mismatch';
    }
    if (scopeComparison['scope_match'] == false) return 'scope_mismatch';
    if (!overlaps && tolerance['out_of_tolerance'] == true) {
      return 'out_of_tolerance';
    }
    if (provenDuplicate) return 'same_source_duplicate_lower_rank';
    if (sameSource && !overlaps) return 'same_source_contradiction_lower_rank';
    if (sameSource) return 'same_source_overlapping_evidence_lower_rank';
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
    final denominator = acceptedValue.abs() < 0.000001
        ? 1.0
        : acceptedValue.abs().toDouble();
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
    _RankedObservation rejectedCandidate,
    _RankedObservation acceptedCandidate,
  ) {
    final rejected = rejectedCandidate.scope;
    final accepted = acceptedCandidate.scope;
    final methodMismatch =
        rejectedCandidate.observation.methodCode !=
        acceptedCandidate.observation.methodCode;
    if (rejected == null || accepted == null) {
      final sameHash =
          rejectedCandidate.observation.scopeHash.isNotEmpty &&
          rejectedCandidate.observation.scopeHash ==
              acceptedCandidate.observation.scopeHash;
      return {
        'scope_match': sameHash && !methodMismatch,
        'mismatch_dimensions': [
          if (!sameHash) 'scope_hash',
          if (methodMismatch) 'method_code',
        ],
        'measurement_method_identity_verified':
            !methodMismatch &&
            acceptedCandidate.observation.methodCode?.trim().isNotEmpty == true,
      };
    }
    final mismatches = <String>[];
    if (methodMismatch) mismatches.add('method_code');
    void compare(String dimension, Object? left, Object? right) {
      final l = left?.toString() ?? '';
      final r = right?.toString() ?? '';
      if (l != r) mismatches.add(dimension);
    }

    compare('jurisdiction', rejected.jurisdiction, accepted.jurisdiction);
    compare('brand', rejected.brand, accepted.brand);
    compare('dosage_form', rejected.dosageForm, accepted.dosageForm);
    compare('release_type', rejected.releaseType, accepted.releaseType);
    compare('route', rejected.route, accepted.route);
    compare('salt_form', rejected.saltForm, accepted.saltForm);
    compare(
      'preparation_state',
      rejected.preparationState,
      accepted.preparationState,
    );
    compare('cooking_state', rejected.cookingState, accepted.cookingState);
    compare('plant_part', rejected.plantPart, accepted.plantPart);
    compare('cultivar', rejected.cultivar, accepted.cultivar);
    compare('sampling_frame', rejected.samplingFrame, accepted.samplingFrame);
    return {
      'scope_match': mismatches.isEmpty,
      'mismatch_dimensions': mismatches,
      'measurement_method_identity_verified':
          !methodMismatch &&
          acceptedCandidate.observation.methodCode?.trim().isNotEmpty == true,
    };
  }

  bool _sameProvenSourceEvidence(
    ObservationRecord left,
    ObservationRecord right,
  ) {
    return left.sourceDocId.trim().isNotEmpty &&
        left.recordLocator.trim().isNotEmpty &&
        left.methodCode?.trim().isNotEmpty == true &&
        left.sourceDocId == right.sourceDocId &&
        left.recordLocator == right.recordLocator &&
        left.methodCode == right.methodCode &&
        left.scopeHash == right.scopeHash &&
        _comparisonKey(left) == _comparisonKey(right) &&
        left.value.qualifierKind == right.value.qualifierKind &&
        left.value.low == right.value.low &&
        left.value.high == right.value.high &&
        left.value.valueNum == right.value.valueNum &&
        left.value.rawValueText == right.value.rawValueText;
  }

  bool _sameObservationPayload(
    ObservationRecord left,
    ObservationRecord right,
  ) =>
      _comparisonKey(left) == _comparisonKey(right) &&
      left.scopeHash == right.scopeHash &&
      left.sourceDocId == right.sourceDocId &&
      left.recordLocator == right.recordLocator &&
      left.methodCode == right.methodCode &&
      left.extractionConfidence == right.extractionConfidence &&
      jsonEncode(left.value.toJson()) == jsonEncode(right.value.toJson());

  bool _hasUsableInterval(QualifiedValue value) {
    if (value.qualifierKind == QualifierKind.missing ||
        value.qualifierKind == QualifierKind.parsingUncertainty) {
      return false;
    }
    final low = value.low;
    final high = value.high;
    return low != null &&
        high != null &&
        low.isFinite &&
        high.isFinite &&
        low <= high &&
        (value.valueNum == null || value.valueNum!.isFinite);
  }

  bool _intervalsOverlap(QualifiedValue left, QualifiedValue right) {
    if (!_hasUsableInterval(left) || !_hasUsableInterval(right)) return false;
    if (!intervalsOverlap(left, right)) return false;
    // '< x' excludes x; '<= x', ranges and exact values include their ends.
    if (left.high == right.low &&
        left.qualifierKind == QualifierKind.lessThan) {
      return false;
    }
    if (right.high == left.low &&
        right.qualifierKind == QualifierKind.lessThan) {
      return false;
    }
    return true;
  }

  String _comparisonKey(ObservationRecord observation) => [
    observation.domain,
    observation.entityType,
    observation.entityKey,
    observation.attributeCode,
    observation.valueType,
    observation.unit,
    observation.basisType,
    observation.basisAmount,
  ].join('|');

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

  /// Stable unordered-pair evidence, including disagreements not involving the
  /// ranked candidate. A manual choice does not remove this source evidence.
  final List<Map<String, dynamic>> comparisonEdges;
  final String explanation;
  final bool needsManualReview;

  const ClusterFactResolution({
    required this.status,
    required this.chosenObservation,
    this.acceptedRationale = const <String, dynamic>{},
    required this.rejectedRationales,
    this.comparisonEdges = const [],
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
