/// In-memory report of a bounded source-range stress test for the heuristic
/// food order. It is not a confidence interval, probability, or stability
/// guarantee; unmodelled inputs remain explicit.
class FoodRankSensitivityAssessment {
  static const String schemaId = 'parkinsum.food-rank-sensitivity-assessment/1';

  final String candidateSetSha256;
  final int supportedRangeFeatureCount;
  final int scenariosEvaluated;
  final Map<String, int> unresolvedReasonCounts;
  final List<String> changedCandidateIds;
  final List<String> topKMembershipChangedIds;
  final List<FoodRankCandidateSwap> possibleOrderSwaps;

  FoodRankSensitivityAssessment({
    required this.candidateSetSha256,
    required this.supportedRangeFeatureCount,
    required this.scenariosEvaluated,
    required Map<String, int> unresolvedReasonCounts,
    required List<String> changedCandidateIds,
    required List<String> topKMembershipChangedIds,
    required List<FoodRankCandidateSwap> possibleOrderSwaps,
  }) : unresolvedReasonCounts = Map<String, int>.unmodifiable(
         Map<String, int>.fromEntries(
           unresolvedReasonCounts.entries.toList()
             ..sort((left, right) => left.key.compareTo(right.key)),
         ),
       ),
       changedCandidateIds = List<String>.unmodifiable(
         changedCandidateIds.toSet().toList()..sort(),
       ),
       topKMembershipChangedIds = List<String>.unmodifiable(
         topKMembershipChangedIds.toSet().toList()..sort(),
       ),
       possibleOrderSwaps = List<FoodRankCandidateSwap>.unmodifiable(
         possibleOrderSwaps.toSet().toList()
           ..sort((left, right) => left.key.compareTo(right.key)),
       );

  bool get hasBoundedScenarios => scenariosEvaluated > 0;

  bool get fullRankStabilityAssessed => false;

  bool get orderChangeObserved =>
      possibleOrderSwaps.isNotEmpty || topKMembershipChangedIds.isNotEmpty;

  bool orderMayChangeFor(String candidateId) => possibleOrderSwaps.any(
    (swap) =>
        swap.firstCandidateId == candidateId ||
        swap.secondCandidateId == candidateId,
  );

  bool displayMembershipMayChangeFor(String candidateId) =>
      topKMembershipChangedIds.contains(candidateId);
}

class FoodRankCandidateSwap {
  final String firstCandidateId;
  final String firstCandidateName;
  final String secondCandidateId;
  final String secondCandidateName;

  const FoodRankCandidateSwap({
    required this.firstCandidateId,
    required this.firstCandidateName,
    required this.secondCandidateId,
    required this.secondCandidateName,
  });

  String get key => '$firstCandidateId\u0000$secondCandidateId';

  String get displayText => '$firstCandidateName ↔ $secondCandidateName';

  @override
  bool operator ==(Object other) =>
      other is FoodRankCandidateSwap && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// Whether score-ordered food results may be shown for one exact candidate
/// snapshot. Missing or stale evidence and observed pair/display-set changes
/// fail closed. A matching no-change report still does not prove full ranking
/// stability; the UI must retain its existing uncertainty boundary.
bool shouldWithholdRankedFoodPresentation({
  required String candidateSetSha256,
  required FoodRankSensitivityAssessment? assessment,
}) {
  if (assessment == null ||
      assessment.candidateSetSha256 != candidateSetSha256) {
    return true;
  }
  return assessment.orderChangeObserved;
}
