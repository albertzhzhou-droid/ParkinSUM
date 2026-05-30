import 'dart:convert';

import '../entities/amino_acid_profile.dart';
import '../entities/meal_composition.dart';
import '../entities/rule_explanation.dart';
import '../entities/time_axis_events.dart';
import 'mechanistic_next_meal_scorer.dart';
import 'medication_entry_validator.dart';
import 'time_axis_builder.dart';

/// One row of the source-quality perturbation report: the deterministic
/// candidate-scoring outcome when **only** a source/provenance-quality input was
/// changed, holding the meal / conflict / model input constant.
///
/// Educational/research prototype only. This is a transparency/analysis artifact;
/// it carries no medical advice and is not clinically calibrated.
class SourceQualityPerturbationRow {
  final String caseId;
  final String inputChanged;
  final String sourceSystem;
  final double jurisdictionMatch;
  final double sourceAuthorityScore;
  final double metadataCompleteness;
  final String aminoAcidConfidenceTier;
  final double nutrientCompleteness;
  final double finalCandidateScore;
  final double conflictOverlapScore;
  final double uncertaintyPenalty;

  /// Modeled amino-acid competition uncertainty band (genuinely widens with a
  /// weaker-than-analytical provenance tier).
  final String competitionUncertaintyBand;

  /// True when the LNAA competition uncertainty was widened (non-analytical
  /// provenance tier, partial fields, or missing source data).
  final bool lnaaUncertaintyWidened;

  final String rankerUsed;
  final String explanation;
  final String safetyBoundary;
  final bool notClinicallyCalibrated;

  const SourceQualityPerturbationRow({
    required this.caseId,
    required this.inputChanged,
    required this.sourceSystem,
    required this.jurisdictionMatch,
    required this.sourceAuthorityScore,
    required this.metadataCompleteness,
    required this.aminoAcidConfidenceTier,
    required this.nutrientCompleteness,
    required this.finalCandidateScore,
    required this.conflictOverlapScore,
    required this.uncertaintyPenalty,
    required this.competitionUncertaintyBand,
    required this.lnaaUncertaintyWidened,
    required this.rankerUsed,
    required this.explanation,
    required this.safetyBoundary,
    required this.notClinicallyCalibrated,
  });

  Map<String, dynamic> toJson() => {
        'case_id': caseId,
        'input_changed': inputChanged,
        'source_system': sourceSystem,
        'jurisdiction_match': jurisdictionMatch,
        'source_authority_score': sourceAuthorityScore,
        'metadata_completeness': metadataCompleteness,
        'amino_acid_confidence_tier': aminoAcidConfidenceTier,
        'nutrient_completeness': nutrientCompleteness,
        'final_candidate_score': finalCandidateScore,
        'conflict_overlap_score': conflictOverlapScore,
        'uncertainty_penalty': uncertaintyPenalty,
        'competition_uncertainty_band': competitionUncertaintyBand,
        'lnaa_uncertainty_widened': lnaaUncertaintyWidened,
        'ranker_used': rankerUsed,
        'explanation': explanation,
        'safety_boundary': safetyBoundary,
        'not_clinically_calibrated': notClinicallyCalibrated,
      };
}

/// The full deterministic report.
class SourceQualityPerturbationReportResult {
  final List<SourceQualityPerturbationRow> rows;

  const SourceQualityPerturbationReportResult(this.rows);

  SourceQualityPerturbationRow byCase(String caseId) =>
      rows.firstWhere((r) => r.caseId == caseId);

  Map<String, dynamic> toJson() => {
        'report_type': 'source_quality_perturbation',
        'not_clinically_calibrated': true,
        'not_advice_text': RuleExplanation.defaultNotAdvice,
        'safety_boundary': RuleExplanation.defaultSafetyBoundary,
        'description':
            'Deterministic educational analysis: how candidate scoring moves '
                'when ONLY source/provenance quality changes, holding the '
                'meal/conflict/model input constant. Conflict overlap remains '
                'the dominant scoring term by construction. Not a clinical '
                'dashboard; no user-facing advice.',
        'rows': rows.map((r) => r.toJson()).toList(growable: false),
      };

  String toMarkdown() {
    final b = StringBuffer()
      ..writeln('# Source-Quality Perturbation Report')
      ..writeln()
      ..writeln('Educational simulation. Synthetic inputs only. Not medical '
          'advice. Not clinically calibrated.')
      ..writeln()
      ..writeln('Shows how candidate scoring moves when **only** '
          'source/provenance quality changes, holding the meal/conflict/model '
          'input constant. Conflict overlap remains the dominant term by '
          'construction.')
      ..writeln()
      ..writeln('| case | input changed | source | juris | authority | '
          'meta cmpl | aa tier | nutrient cmpl | final | overlap | uncert | '
          'comp band | widened |')
      ..writeln('| --- | --- | --- | --- | --- | --- | --- | --- | --- | '
          '--- | --- | --- | --- |');
    for (final r in rows) {
      b.writeln('| ${r.caseId} | ${r.inputChanged} | ${r.sourceSystem} | '
          '${r.jurisdictionMatch.toStringAsFixed(2)} | '
          '${r.sourceAuthorityScore.toStringAsFixed(2)} | '
          '${r.metadataCompleteness.toStringAsFixed(2)} | '
          '${r.aminoAcidConfidenceTier} | '
          '${r.nutrientCompleteness.toStringAsFixed(2)} | '
          '${r.finalCandidateScore.toStringAsFixed(4)} | '
          '${r.conflictOverlapScore.toStringAsFixed(4)} | '
          '${r.uncertaintyPenalty.toStringAsFixed(2)} | '
          '${r.competitionUncertaintyBand} | ${r.lnaaUncertaintyWidened} |');
    }
    return b.toString();
  }
}

/// Deterministic JSON encoder (stable key order via the model's `toJson`).
String encodeSourceQualityReport(
        SourceQualityPerturbationReportResult report) =>
    const JsonEncoder.withIndent('  ').convert(report.toJson());

/// Builds the report. Pure/deterministic: no I/O, no clock. Holds a fixed
/// synthetic base context + candidate composition and sweeps source/provenance
/// quality perturbations.
class SourceQualityPerturbationReportRunner {
  final MechanisticNextMealScorer scorer;
  final MedicationEntryValidator validator;
  final TimeAxisBuilder builder;

  SourceQualityPerturbationReportRunner({
    MechanisticNextMealScorer? scorer,
    MedicationEntryValidator? validator,
    TimeAxisBuilder? builder,
  })  : scorer = scorer ?? MechanisticNextMealScorer(),
        validator = validator ?? MedicationEntryValidator(),
        builder = builder ?? TimeAxisBuilder();

  // Fixed reference instant for deterministic timelines (UTC).
  static final DateTime _now = DateTime.utc(2026, 1, 1, 8);

  TimeAxisConflictContext _baseContext() {
    final v = validator.validate(const RawMedicationEntry(
      activeIngredients: ['carbidopa', 'levodopa'],
      drugProductVariant: 'synthetic:demo',
      strength: 100,
      unit: 'mg',
      form: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      jurisdiction: 'US',
      sourceDocId: 'synthetic:demo',
    ));
    return builder.build(
      now: _now,
      medicationInputs: [
        MedicationTimelineInput(
          id: 'm',
          takenAt: _now.add(const Duration(minutes: 30)),
          medicationContext: v,
        ),
      ],
      mealInputs: const [],
      userDefinedWindow: UserDefinedMealWindow(
        window: TimelineWindow(
          startMinute: dateTimeToMinute(_now) + 60,
          endMinute: dateTimeToMinute(_now) + 120,
        ),
        source: 'report',
      ),
    );
  }

  /// FDC derivation code per amino-acid confidence tier (used to build the
  /// candidate's amino-acid provenance for the tier sweep).
  static String _codeForTier(NutrientConfidenceTier tier) => switch (tier) {
        NutrientConfidenceTier.analytical => 'A',
        NutrientConfidenceTier.calculated => 'CAL',
        NutrientConfidenceTier.imputedOrAssumed => 'I',
        NutrientConfidenceTier.unknown => 'X',
      };

  AminoAcidProfile _aaProfile(NutrientConfidenceTier tier) => AminoAcidProfile(
        leucine: 1.8,
        isoleucine: 1.0,
        valine: 1.1,
        phenylalanine: 0.9,
        tyrosine: 0.7,
        tryptophan: 0.3,
        basis: 'per_serving',
        nutrientIds: const ['504', '503', '510', '508', '509', '501'],
        sourceRefs: const ['src.fdc.api.amino_acid_fields'],
        derivations: {
          'leucine': NutrientDerivation(derivationCode: _codeForTier(tier)),
        },
      );

  CandidateFood _candidate(
    String id, {
    required double protein,
    AminoAcidProfile? aa,
    double? portionGrams = 150,
    double? calories = 150,
    String sourceSystem = 'synthetic',
  }) =>
      CandidateFood(
        id: id,
        name: id,
        regionalFoodLibraryRef: sourceSystem,
        declaredPhysicalForm: MealPhysicalForm.solid,
        components: [
          FoodComponent(
            id: id,
            name: id,
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: protein,
            fatGrams: 2,
            fiberGrams: 1,
            carbohydrateGrams: 20,
            calories: calories,
            portionGrams: portionGrams,
            sourceDocId: sourceSystem,
            aminoAcidProfile: aa,
          ),
        ],
      );

  CandidateMetadata _meta({
    required double authority,
    required double jurisdictionMatch,
    required double provenance,
    required double completeness,
  }) =>
      CandidateMetadata(
        completeness: completeness,
        authorityScore: authority,
        jurisdictionMatchScore: jurisdictionMatch,
        provenanceQuality: provenance,
        jurisdiction: 'US',
      );

  SourceQualityPerturbationRow _row({
    required String caseId,
    required String inputChanged,
    required CandidateFood candidate,
    required CandidateMetadata metadata,
    required NutrientConfidenceTier aaTier,
  }) {
    final scores = scorer.score(
      baseContext: _baseContext(),
      baseMealCompositionsById: const {},
      candidates: [candidate],
      candidateMetadata: {candidate.id: metadata},
    );
    final s = scores.firstWhere((e) => e.candidateFoodId == candidate.id);
    final competition = s.upstreamResult?.competitionTimeline;
    return SourceQualityPerturbationRow(
      caseId: caseId,
      inputChanged: inputChanged,
      sourceSystem: candidate.regionalFoodLibraryRef,
      jurisdictionMatch: s.jurisdictionMatchScore,
      sourceAuthorityScore: s.sourceAuthorityScore,
      metadataCompleteness: s.metadataCompletenessScore,
      aminoAcidConfidenceTier: aaTier.name,
      nutrientCompleteness: s.nutritionDataCompleteness,
      finalCandidateScore: s.finalCandidateScore,
      conflictOverlapScore: s.conflictOverlapScore,
      uncertaintyPenalty: s.uncertaintyPenalty,
      competitionUncertaintyBand: competition?.uncertaintyBand.name ?? 'none',
      lnaaUncertaintyWidened:
          competition?.lnaaSummary?.uncertaintyWidened ?? false,
      rankerUsed: s.insufficientContext
          ? 'legacy_fallback'
          : 'mechanistic_primary_window_sampled',
      explanation:
          'Holding the meal/conflict/model input constant, only "$inputChanged" '
          'changed. Conflict overlap remains the dominant scoring term; '
          'provenance/metadata refine within a bounded weight.',
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notClinicallyCalibrated: true,
    );
  }

  SourceQualityPerturbationReportResult run() {
    final rows = <SourceQualityPerturbationRow>[];

    // --- Family 1: provenance / source quality (meal held constant) ---------
    // Same candidate composition (protein 8, analytical AA, portion known);
    // only the CandidateMetadata changes.
    final refAa = _aaProfile(NutrientConfidenceTier.analytical);
    CandidateFood provCandidate(String src) =>
        _candidate('prov_$src', protein: 8, aa: refAa, sourceSystem: src);

    rows.add(_row(
      caseId: 'prov_official_in_jurisdiction',
      inputChanged: 'official_in_jurisdiction',
      candidate: provCandidate('official_in_jurisdiction'),
      metadata: _meta(
          authority: 1.0,
          jurisdictionMatch: 1.0,
          provenance: 1.0,
          completeness: 1.0),
      aaTier: NutrientConfidenceTier.analytical,
    ));
    rows.add(_row(
      caseId: 'prov_official_out_of_jurisdiction',
      inputChanged: 'official_out_of_jurisdiction',
      candidate: provCandidate('official_out_of_jurisdiction'),
      metadata: _meta(
          authority: 0.6,
          jurisdictionMatch: 0.2,
          provenance: 0.8,
          completeness: 1.0),
      aaTier: NutrientConfidenceTier.analytical,
    ));
    rows.add(_row(
      caseId: 'prov_synthetic_demo',
      inputChanged: 'synthetic_demo',
      candidate: provCandidate('synthetic_demo'),
      metadata: _meta(
          authority: 0.1,
          jurisdictionMatch: 0.1,
          provenance: 0.1,
          completeness: 0.3),
      aaTier: NutrientConfidenceTier.analytical,
    ));
    rows.add(_row(
      caseId: 'prov_missing_source_refs',
      inputChanged: 'missing_source_refs',
      candidate: provCandidate('official_in_jurisdiction'),
      // Same authority/jurisdiction as official, but missing sourceRefs drops
      // provenance quality + completeness (recorded missing, not fabricated).
      metadata: _meta(
          authority: 1.0,
          jurisdictionMatch: 1.0,
          provenance: 0.0,
          completeness: 0.5),
      aaTier: NutrientConfidenceTier.analytical,
    ));
    rows.add(_row(
      caseId: 'prov_complete_metadata',
      inputChanged: 'complete_metadata',
      candidate: provCandidate('official_in_jurisdiction'),
      metadata: _meta(
          authority: 0.7,
          jurisdictionMatch: 0.7,
          provenance: 0.7,
          completeness: 1.0),
      aaTier: NutrientConfidenceTier.analytical,
    ));
    rows.add(_row(
      caseId: 'prov_partial_metadata',
      inputChanged: 'partial_metadata',
      candidate: provCandidate('official_in_jurisdiction'),
      metadata: _meta(
          authority: 0.7,
          jurisdictionMatch: 0.7,
          provenance: 0.7,
          completeness: 0.4),
      aaTier: NutrientConfidenceTier.analytical,
    ));

    // --- Family 2: amino-acid confidence tier (metadata held neutral) -------
    const neutralMeta = CandidateMetadata(
      completeness: 0.6,
      authorityScore: 0.5,
      jurisdictionMatchScore: 0.5,
      provenanceQuality: 0.5,
      jurisdiction: 'US',
    );
    for (final tier in [
      NutrientConfidenceTier.analytical,
      NutrientConfidenceTier.calculated,
      NutrientConfidenceTier.imputedOrAssumed,
      NutrientConfidenceTier.unknown,
    ]) {
      rows.add(_row(
        caseId: 'aa_${tier.name}',
        inputChanged: 'amino_acid_tier_${tier.name}',
        candidate:
            _candidate('aa_${tier.name}', protein: 12, aa: _aaProfile(tier)),
        metadata: neutralMeta,
        aaTier: tier,
      ));
    }
    // Missing nutrient basis: no amino-acid profile + missing portion/calories.
    rows.add(_row(
      caseId: 'aa_missing_nutrient_basis',
      inputChanged: 'missing_nutrient_basis',
      candidate: _candidate('aa_missing_nutrient_basis',
          protein: 12, aa: null, portionGrams: null, calories: null),
      metadata: neutralMeta,
      aaTier: NutrientConfidenceTier.unknown,
    ));

    return SourceQualityPerturbationReportResult(List.unmodifiable(rows));
  }

  /// Scores two identical-composition candidates differing ONLY in provenance,
  /// returning (betterProvenanceScore, worseProvenanceScore). Used to show
  /// provenance breaks ties when conflict scores are equal.
  ({double better, double worse}) tieBreakByProvenance() {
    final aa = _aaProfile(NutrientConfidenceTier.analytical);
    final best = _candidate('tie_best', protein: 8, aa: aa);
    final worst = _candidate('tie_worst', protein: 8, aa: aa);
    final scores = scorer.score(
      baseContext: _baseContext(),
      baseMealCompositionsById: const {},
      candidates: [best, worst],
      candidateMetadata: {
        'tie_best': _meta(
            authority: 1.0,
            jurisdictionMatch: 1.0,
            provenance: 1.0,
            completeness: 1.0),
        'tie_worst': _meta(
            authority: 0.0,
            jurisdictionMatch: 0.0,
            provenance: 0.0,
            completeness: 0.0),
      },
    );
    return (
      better: scores
          .firstWhere((e) => e.candidateFoodId == 'tie_best')
          .finalCandidateScore,
      worse: scores
          .firstWhere((e) => e.candidateFoodId == 'tie_worst')
          .finalCandidateScore,
    );
  }
}
