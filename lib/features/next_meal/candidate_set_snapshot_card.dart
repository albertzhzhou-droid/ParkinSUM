import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/food_composition_candidate_set_snapshot.dart';
import '../../domain/entities/food_rank_sensitivity_assessment.dart';

/// Shows the identity of the app-assembled food inputs captured for a result.
/// This is not an upstream catalog-release identity or a rank-stability claim.
class CandidateSetSnapshotCard extends StatelessWidget {
  final FoodCompositionCandidateSetSnapshot snapshot;
  final FoodRankSensitivityAssessment? rankSensitivityAssessment;

  const CandidateSetSnapshotCard({
    super.key,
    required this.snapshot,
    this.rankSensitivityAssessment,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final sensitivity =
        rankSensitivityAssessment?.candidateSetSha256 == snapshot.sha256Digest
        ? rankSensitivityAssessment
        : null;
    final boundedScenarios = sensitivity?.hasBoundedScenarios ?? false;
    final swaps =
        sensitivity?.possibleOrderSwaps ?? const <FoodRankCandidateSwap>[];
    final status = !boundedScenarios
        ? i18n.tr('next_meal.rank_stability_status')
        : swaps.isNotEmpty
        ? i18n.tr('next_meal.rank_stability_bounded_change')
        : (sensitivity?.topKMembershipChangedIds.isNotEmpty ?? false)
        ? i18n.tr('next_meal.rank_stability_bounded_membership_change')
        : i18n.tr('next_meal.rank_stability_bounded_no_change');
    final boundedBoundary = !boundedScenarios
        ? i18n.tr('next_meal.rank_stability_boundary')
        : swaps.isNotEmpty
        ? i18n.tr('next_meal.rank_stability_swap_summary', {
            'scenarios': '${sensitivity!.scenariosEvaluated}',
            'pairs': swaps.take(3).map((swap) => swap.displayText).join('; '),
            'more': swaps.length > 3 ? '; +${swaps.length - 3}' : '',
          })
        : sensitivity!.topKMembershipChangedIds.isNotEmpty
        ? i18n.tr('next_meal.rank_stability_membership_summary', {
            'scenarios': '${sensitivity.scenariosEvaluated}',
            'count': '${sensitivity.topKMembershipChangedIds.length}',
          })
        : i18n.tr('next_meal.rank_stability_no_swap_summary', {
            'scenarios': '${sensitivity.scenariosEvaluated}',
            'changes': '${sensitivity.changedCandidateIds.length}',
            'memberships': '${sensitivity.topKMembershipChangedIds.length}',
          });
    return PaperCard(
      key: const ValueKey('next-meal-candidate-set-snapshot'),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            i18n.tr('next_meal.candidate_snapshot_title'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Paper.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            i18n.tr('next_meal.candidate_snapshot_meta', {
              'schema': FoodCompositionCandidateSetSnapshot.schemaId,
              'count': '${snapshot.mergedCandidateCount}',
            }),
            style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
          ),
          const SizedBox(height: 4),
          SelectableText(
            i18n.tr('next_meal.candidate_snapshot_digest', {
              'digest': snapshot.sha256Digest,
            }),
            key: const ValueKey('next-meal-candidate-set-snapshot-digest'),
            style: const TextStyle(
              fontSize: 11,
              color: Paper.inkMuted,
              fontFamily: 'monospace',
              height: 1.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            i18n.tr('next_meal.candidate_snapshot_boundary'),
            style: const TextStyle(
              fontSize: 11,
              color: Paper.inkMuted,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: Paper.inkMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      key: const ValueKey('next-meal-rank-stability-status'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Paper.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      boundedBoundary,
                      key: const ValueKey('next-meal-rank-stability-boundary'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Paper.inkMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class RankedFoodPresentationWithheldNotice extends StatelessWidget {
  const RankedFoodPresentationWithheldNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final message = context.appI18n.tr('next_meal.rank_display_withheld');
    return Semantics(
      key: const ValueKey('next-meal-ranked-food-presentation-withheld'),
      container: true,
      liveRegion: true,
      label: message,
      child: PaperCard(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.pause_circle_outline_rounded,
              size: 18,
              color: Paper.inkMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                key: const ValueKey('next-meal-ranked-food-presentation-copy'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Paper.inkMuted,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Marks only candidates whose status changed in the snapshot-bound scenarios.
/// It does not alter the recommendation order, score, or safety gate.
class CandidateRankUncertaintyBadge extends StatelessWidget {
  final String candidateId;
  final String candidateSetSha256;
  final FoodRankSensitivityAssessment? assessment;

  const CandidateRankUncertaintyBadge({
    super.key,
    required this.candidateId,
    required this.candidateSetSha256,
    required this.assessment,
  });

  @override
  Widget build(BuildContext context) {
    final sensitivity = assessment;
    if (sensitivity == null ||
        sensitivity.candidateSetSha256 != candidateSetSha256) {
      return const SizedBox.shrink();
    }
    final labelKey = sensitivity.displayMembershipMayChangeFor(candidateId)
        ? 'next_meal.candidate_membership_may_change'
        : sensitivity.orderMayChangeFor(candidateId)
        ? 'next_meal.candidate_order_may_change'
        : null;
    if (labelKey == null) return const SizedBox.shrink();

    final label = context.appI18n.tr(labelKey);
    return Semantics(
      key: ValueKey('next-meal-candidate-rank-uncertainty-$candidateId'),
      container: true,
      label: label,
      excludeSemantics: true,
      child: Container(
        margin: const EdgeInsets.only(top: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Paper.surfaceSunken,
          border: Border.all(color: Paper.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.swap_vert_rounded,
              size: 15,
              color: Paper.inkMuted,
            ),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Paper.inkMuted,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
