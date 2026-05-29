/// Centralized next-meal candidate scoring weights with provenance metadata.
///
/// The mechanistic next-meal scorer composes a deterministic linear score from
/// modeled conflict overlap, protein redistribution, nutrition adequacy, and
/// data provenance/metadata, minus an uncertainty penalty. Previously these
/// weights were hard-coded inline; centralizing them here makes each weight
/// inspectable and traceable (sourceRefs / evidence level / limitation) and
/// surfaceable in replay reports.
///
/// Educational prototype only. Weight magnitudes are `prototype_heuristic`;
/// only the *ordering invariant* (modeled conflict + uncertainty dominate, and
/// provenance/metadata can never overpower a high modeled conflict overlap) is
/// asserted.
library;

import 'model_assumption_registry.dart' show ModelEvidenceLevel;

class ScoringWeight {
  final String id;
  final String label;
  final double value;
  final List<String> sourceRefs;
  final ModelEvidenceLevel evidenceLevel;
  final String limitation;

  const ScoringWeight({
    required this.id,
    required this.label,
    required this.value,
    required this.sourceRefs,
    required this.evidenceLevel,
    required this.limitation,
  });

  bool get isPrototypeHeuristic =>
      evidenceLevel == ModelEvidenceLevel.prototypeHeuristic;

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'value': value,
        'source_refs': sourceRefs,
        'evidence_level': evidenceLevel.name,
        'limitation': limitation,
        'prototype_heuristic': isPrototypeHeuristic,
      };
}

class NextMealScoringParameterSet {
  /// Stable id/version so reports can record which weight set was active.
  final String id;
  final ScoringWeight conflictOverlap;
  final ScoringWeight proteinRedistribution;
  final ScoringWeight nutritionAdequacy;
  final ScoringWeight metadataCompleteness;
  final ScoringWeight sourceAuthority;
  final ScoringWeight jurisdictionMatch;
  final ScoringWeight provenanceQuality;
  final ScoringWeight uncertaintyPenalty;

  const NextMealScoringParameterSet({
    required this.id,
    required this.conflictOverlap,
    required this.proteinRedistribution,
    required this.nutritionAdequacy,
    required this.metadataCompleteness,
    required this.sourceAuthority,
    required this.jurisdictionMatch,
    required this.provenanceQuality,
    required this.uncertaintyPenalty,
  });

  /// Default weight set. Magnitudes are illustrative prototype heuristics; the
  /// direction (conflict overlap dominant; provenance refines but never
  /// dominates) follows the cited levodopa-protein interaction literature.
  factory NextMealScoringParameterSet.literatureInformedDefault() {
    return const NextMealScoringParameterSet(
      id: 'next_meal_scoring.v1',
      conflictOverlap: ScoringWeight(
        id: 'score.conflict_overlap',
        label: 'Weight on (1 - modeled levodopa absorption-window overlap)',
        value: 0.45,
        sourceRefs: [
          'src.nutt.lnaa.1989',
          'src.npj.peripheral.resistance.2022',
          'src.contin.levodopa.pk.2010',
        ],
        evidenceLevel: ModelEvidenceLevel.mechanism,
        limitation:
            'Conflict overlap is the dominant term by design; magnitude is an '
            'illustrative prototype heuristic, not a fitted coefficient.',
      ),
      proteinRedistribution: ScoringWeight(
        id: 'score.protein_redistribution',
        label: 'Weight on the protein-redistribution score',
        value: 0.20,
        sourceRefs: [
          'src.cereda.protein.2017',
          'src.pare.protein.redistribution.1992',
          'src.virmani.protein.2023',
        ],
        evidenceLevel: ModelEvidenceLevel.mechanism,
        limitation:
            'Protein redistribution is a researched dietary strategy requiring '
            'professional supervision; weight is illustrative, not advice.',
      ),
      nutritionAdequacy: ScoringWeight(
        id: 'score.nutrition_adequacy',
        label: 'Weight on the nutrition-adequacy contribution',
        value: 0.10,
        sourceRefs: ['src.internal.prototype.heuristic'],
        evidenceLevel: ModelEvidenceLevel.prototypeHeuristic,
        limitation: 'Adequacy proxy and weight are illustrative.',
      ),
      metadataCompleteness: ScoringWeight(
        id: 'score.metadata_completeness',
        label: 'Weight on candidate metadata completeness',
        value: 0.10,
        sourceRefs: ['src.internal.prototype.heuristic'],
        evidenceLevel: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Data-quality refinement only; cannot overpower modeled conflict.',
      ),
      sourceAuthority: ScoringWeight(
        id: 'score.source_authority',
        label: 'Weight on source-authority score',
        value: 0.05,
        sourceRefs: ['src.internal.prototype.heuristic'],
        evidenceLevel: ModelEvidenceLevel.prototypeHeuristic,
        limitation: 'Provenance refinement only; small by design.',
      ),
      jurisdictionMatch: ScoringWeight(
        id: 'score.jurisdiction_match',
        label: 'Weight on jurisdiction-match score',
        value: 0.05,
        sourceRefs: ['src.internal.prototype.heuristic'],
        evidenceLevel: ModelEvidenceLevel.prototypeHeuristic,
        limitation: 'Provenance refinement only; small by design.',
      ),
      provenanceQuality: ScoringWeight(
        id: 'score.provenance_quality',
        label: 'Weight on provenance-quality score',
        value: 0.05,
        sourceRefs: ['src.internal.prototype.heuristic'],
        evidenceLevel: ModelEvidenceLevel.prototypeHeuristic,
        limitation: 'Provenance refinement only; small by design.',
      ),
      uncertaintyPenalty: ScoringWeight(
        id: 'score.uncertainty_penalty',
        label: 'Weight subtracted for modeled uncertainty',
        value: 0.10,
        sourceRefs: ['src.internal.prototype.heuristic'],
        evidenceLevel: ModelEvidenceLevel.prototypeHeuristic,
        limitation:
            'Uncertainty must reduce confidence; magnitude is illustrative.',
      ),
    );
  }

  List<ScoringWeight> get all => [
        conflictOverlap,
        proteinRedistribution,
        nutritionAdequacy,
        metadataCompleteness,
        sourceAuthority,
        jurisdictionMatch,
        provenanceQuality,
        uncertaintyPenalty,
      ];

  /// Sum of the provenance/metadata refinement weights. Must stay below the
  /// conflict-overlap weight so provenance can never outrank a high modeled
  /// conflict overlap.
  double get provenanceWeightSum =>
      metadataCompleteness.value +
      sourceAuthority.value +
      jurisdictionMatch.value +
      provenanceQuality.value;

  /// Invariant guard: modeled conflict overlap stays the dominant single term
  /// and the combined provenance/metadata weight cannot exceed it.
  bool get conflictRemainsDominant =>
      conflictOverlap.value >= proteinRedistribution.value &&
      conflictOverlap.value >= provenanceWeightSum &&
      conflictOverlap.value >= metadataCompleteness.value &&
      conflictOverlap.value >= sourceAuthority.value &&
      conflictOverlap.value >= jurisdictionMatch.value &&
      conflictOverlap.value >= provenanceQuality.value;

  Map<String, dynamic> toJson() => {
        'id': id,
        'conflict_overlap': conflictOverlap.toJson(),
        'protein_redistribution': proteinRedistribution.toJson(),
        'nutrition_adequacy': nutritionAdequacy.toJson(),
        'metadata_completeness': metadataCompleteness.toJson(),
        'source_authority': sourceAuthority.toJson(),
        'jurisdiction_match': jurisdictionMatch.toJson(),
        'provenance_quality': provenanceQuality.toJson(),
        'uncertainty_penalty': uncertaintyPenalty.toJson(),
      };
}
