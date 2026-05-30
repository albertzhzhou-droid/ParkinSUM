/// P5 — SyntheticScenarioFuzzer (deterministic generator + real-code evaluator).
///
/// Educational/research prototype only. Synthetic data only. Deterministic
/// regression/stress testing — NOT a clinical simulator, NOT patient generation,
/// NOT clinical validation, NOT clinically calibrated, NOT medical advice. No
/// PHI. It generates boundary-case inputs that vary one or two conditions at a
/// time and checks that ParkinSUM's existing gates respond stably and
/// non-prescriptively. Every generated case is evaluated with **real existing
/// code**; nothing fabricates success.
library;

import 'dart:convert';

import '../entities/gastric_emptying_profile.dart' show UncertaintyBand;
import '../entities/meal_composition.dart';
import '../entities/nutrient_derivation.dart' show NutrientConfidenceTier;
import '../entities/rule_explanation.dart';
import '../entities/source_metadata.dart';
import '../entities/synthetic_scenario_fuzzer.dart';
import '../entities/time_axis_events.dart';
import '../entities/medication_entry_validation.dart'
    show MedicationContextValidity;
import 'levodopa_absorption_opportunity_model.dart';
import 'meal_composition_normalizer.dart';
import 'mechanistic_next_meal_scorer.dart';
import 'medication_entry_validator.dart';
import 'metadata_completeness_gate.dart';
import 'next_meal_scoring_parameters.dart';
import 'source_authority_scorer.dart';
import 'time_axis_builder.dart';

/// Forbidden patient-linkage / clinical-care KEYS (key-level recursive scan).
/// Values such as `no_patient_no_subject_no_encounter` are allowed; only emitted
/// KEYS are banned.
const Set<String> _forbiddenPhiKeys = {
  'patient',
  'subject',
  'encounter',
  'practitioner',
  'careteam',
  'care_team',
  'diagnosis',
  'treatment',
  'medicationrequest',
  'medication_request',
  'medicationadministration',
  'medication_administration',
  'dosageinstruction',
  'dosage_instruction',
  'timing',
  'recommendation',
  'prescription',
};

class SyntheticScenarioFuzzer {
  SyntheticScenarioFuzzer({
    MedicationEntryValidator? validator,
    MealCompositionNormalizer? normalizer,
    MetadataCompletenessGate? completenessGate,
    SourceAuthorityScorer? authorityScorer,
    LevodopaAbsorptionOpportunityModel? absorptionModel,
    MechanisticNextMealScorer? scorer,
    TimeAxisBuilder? timeAxisBuilder,
  })  : _validator = validator ?? MedicationEntryValidator(),
        _normalizer = normalizer ?? MealCompositionNormalizer(),
        _gate = completenessGate ?? MetadataCompletenessGate(),
        _authority = authorityScorer ?? SourceAuthorityScorer(),
        _absorption = absorptionModel ?? LevodopaAbsorptionOpportunityModel(),
        _scorer = scorer ?? MechanisticNextMealScorer(),
        _builder = timeAxisBuilder ?? TimeAxisBuilder();

  final MedicationEntryValidator _validator;
  final MealCompositionNormalizer _normalizer;
  final MetadataCompletenessGate _gate;
  final SourceAuthorityScorer _authority;
  final LevodopaAbsorptionOpportunityModel _absorption;
  final MechanisticNextMealScorer _scorer;
  final TimeAxisBuilder _builder;

  static const List<String> _limitations = [
    'Synthetic regression/stress testing only; not a clinical simulator.',
    'Not clinical validation; the model is not clinically calibrated.',
    'No real patient data, medication schedules, or clinical prediction.',
    'Deterministic for a given seed; not exhaustive boundary coverage.',
  ];

  /// Generates the deterministic, seed-ordered case list (no evaluation).
  List<SyntheticScenarioCase> generate(SyntheticScenarioFuzzerConfig config) {
    final catalog = <SyntheticScenarioCase>[
      for (final family in SyntheticScenarioFamily.values)
        if (config.enabledFamilies.contains(family)) ..._familyCases(family),
    ];
    final ordered = _seededOrder(catalog, config.seed);
    final count = config.caseCount.clamp(0, ordered.length);
    return List.unmodifiable(ordered.take(count));
  }

  /// Generates + evaluates with real code, returning the full report.
  SyntheticScenarioFuzzerReport run(SyntheticScenarioFuzzerConfig config) {
    final cases = generate(config);
    final results = cases
        .map((c) => SyntheticScenarioResult(c, _evaluate(c)))
        .toList(growable: false);
    final passed = results.where((r) => r.evaluation.passed).length;
    return SyntheticScenarioFuzzerReport(
      seed: config.seed,
      caseCount: results.length,
      passed: passed,
      failed: results.length - passed,
      families: (config.enabledFamilies.map((f) => f.id).toList()..sort()),
      cases: results,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      notClinicallyCalibrated: true,
      limitations: _limitations,
    );
  }

  // --- Deterministic seed ordering (LCG; stable per seed) ------------------
  List<SyntheticScenarioCase> _seededOrder(
      List<SyntheticScenarioCase> cases, int seed) {
    final out = [...cases];
    var state = (seed & 0x7fffffff) == 0 ? 0x2545F491 : (seed & 0x7fffffff);
    int next() {
      state = (1103515245 * state + 12345) & 0x7fffffff;
      return state;
    }

    for (var i = out.length - 1; i > 0; i--) {
      final j = next() % (i + 1);
      final tmp = out[i];
      out[i] = out[j];
      out[j] = tmp;
    }
    return out;
  }

  // --- Case catalog per family ---------------------------------------------
  List<SyntheticScenarioCase> _familyCases(SyntheticScenarioFamily family) {
    switch (family) {
      case SyntheticScenarioFamily.medicationDosage:
        return _dosageCases();
      case SyntheticScenarioFamily.mealMissingness:
        return _missingnessCases();
      case SyntheticScenarioFamily.releaseTimeline:
        return _releaseCases();
      case SyntheticScenarioFamily.sourceQuality:
        return _sourceQualityCases();
      case SyntheticScenarioFamily.windowRanking:
        return _windowCases();
      case SyntheticScenarioFamily.safetyCopyNoPhi:
        return _safetyCases();
    }
  }

  SyntheticScenarioExpectedInvariant _inv(String id, String desc,
          {String failure = 'invariant failed'}) =>
      SyntheticScenarioExpectedInvariant(
        invariantId: id,
        description: desc,
        severity: 'must',
        mustPass: true,
        failureMessage: failure,
      );

  SyntheticScenarioCase _case(
    SyntheticScenarioFamily family,
    String idSuffix,
    String description,
    Map<String, dynamic> probe,
    List<SyntheticScenarioExpectedInvariant> invariants,
  ) =>
      SyntheticScenarioCase(
        scenarioId: '${family.id}__$idSuffix',
        family: family.id,
        description: description,
        mutations: const [],
        inputSummary: probe,
        expectedInvariants: invariants,
        safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      );

  List<SyntheticScenarioCase> _dosageCases() {
    const fam = SyntheticScenarioFamily.medicationDosage;
    final notValid = [
      _inv('dose_not_valid', 'Boundary dose must not validate as complete'),
      _inv('no_fabricated_dose', 'No normalized dose fabricated when invalid'),
    ];
    return [
      _case(fam, 'unitless', 'unitless free-text dose',
          {'probe': 'dosage', 'free_text': 'levodopa 100'}, notValid),
      _case(fam, 'missing_dose', 'no strength/unit/free-text',
          {'probe': 'dosage'}, notValid),
      _case(fam, 'slash_no_unit', 'slash format without explicit unit',
          {'probe': 'dosage', 'free_text': '25/100'}, notValid),
      _case(
          fam,
          'strength_meta_unitless',
          'product strength attached but user dose unitless',
          {'probe': 'dosage', 'free_text': 'levodopa 100', 'with_meta': true},
          notValid),
      _case(fam, 'valid_explicit', 'valid explicit dose with unit', {
        'probe': 'dosage',
        'strength': 100,
        'unit': 'mg',
      }, [
        _inv('valid_dose', 'Explicit value+unit validates as valid'),
        _inv('no_fabricated_dose', 'Validated dose comes from explicit input'),
      ]),
    ];
  }

  List<SyntheticScenarioCase> _missingnessCases() {
    const fam = SyntheticScenarioFamily.mealMissingness;
    return [
      _case(
          fam,
          'complete',
          'complete nutrients (baseline)',
          {'probe': 'missingness', 'kind': 'complete'},
          [_inv('complete_baseline', 'Complete nutrients → top completeness')]),
      _case(fam, 'true_zero_protein', 'true 0 g protein (not missing)', {
        'probe': 'missingness',
        'kind': 'true_zero'
      }, [
        _inv('zero_not_missing',
            'True 0 g protein is NOT treated as missing (completeness == baseline)'),
      ]),
      _case(
          fam,
          'missing_protein',
          'missing protein',
          {'probe': 'missingness', 'kind': 'missing_protein'},
          [_inv('missing_lowers', 'Missing protein lowers completeness')]),
      _case(
          fam,
          'missing_calories',
          'missing calories',
          {'probe': 'missingness', 'kind': 'missing_calories'},
          [_inv('missing_lowers', 'Missing calories lowers completeness')]),
      _case(
          fam,
          'missing_portion',
          'missing portion grams',
          {'probe': 'missingness', 'kind': 'missing_portion'},
          [_inv('missing_lowers', 'Missing portion lowers completeness')]),
    ];
  }

  List<SyntheticScenarioCase> _releaseCases() {
    const fam = SyntheticScenarioFamily.releaseTimeline;
    return [
      _case(
          fam,
          'ir',
          'immediate-release baseline',
          {'probe': 'release', 'release_type': 'immediate'},
          [_inv('ir_window', 'IR produces a finite absorption window')]),
      _case(
          fam,
          'er_wider',
          'extended-release wider than IR',
          {'probe': 'release', 'release_type': 'extended'},
          [_inv('er_wider', 'ER window is wider than the IR baseline')]),
      _case(
          fam,
          'cr_wider',
          'controlled-release wider than IR',
          {'probe': 'release', 'release_type': 'controlled'},
          [_inv('cr_wider', 'CR window is wider than the IR baseline')]),
      _case(fam, 'unknown_widens', 'unknown release widens uncertainty', {
        'probe': 'release',
        'release_type': 'unknown'
      }, [
        _inv('unknown_uncertain',
            'Unknown release widens uncertainty + records limited interpretation'),
      ]),
      _case(fam, 'non_levodopa', 'non-levodopa event not contaminating', {
        'probe': 'release',
        'release_type': 'immediate',
        'non_levodopa': true
      }, [
        _inv('non_levodopa_isolated',
            'Non-levodopa event yields no levodopa absorption window'),
      ]),
    ];
  }

  List<SyntheticScenarioCase> _sourceQualityCases() {
    const fam = SyntheticScenarioFamily.sourceQuality;
    return [
      _case(
          fam, 'tier_ordering', 'analytical > calculated > imputed > unknown', {
        'probe': 'tier_ordering'
      }, [
        _inv('tier_ordering', 'Completeness weight respects tier ordering')
      ]),
      _case(
          fam, 'missing_source_refs', 'missing sourceRefs lowers provenance', {
        'probe': 'missing_source_refs'
      }, [
        _inv('refs_lower', 'Missing sourceRefs lowers candidate-food grade')
      ]),
      _case(fam, 'authority_official_vs_synthetic',
          'official in-jurisdiction ≥ synthetic', {
        'probe': 'authority'
      }, [
        _inv('authority_order',
            'Official in-jurisdiction authority ≥ synthetic, same chain'),
      ]),
    ];
  }

  List<SyntheticScenarioCase> _windowCases() {
    const fam = SyntheticScenarioFamily.windowRanking;
    return [
      _case(
          fam,
          'no_window',
          'no user-defined window → fallback',
          {'probe': 'no_window'},
          [_inv('no_window_fallback', 'No window → insufficient context')]),
      _case(
          fam,
          'valid_window',
          'valid window → scored',
          {'probe': 'valid_window'},
          [_inv('window_scored', 'Valid window + candidate is scored')]),
      _case(fam, 'provenance_tiebreak', 'provenance breaks a tie', {
        'probe': 'tiebreak'
      }, [
        _inv('tiebreak', 'Better provenance ranks ≥ worse on identical food'),
        _inv('conflict_dominant',
            'Provenance swing bounded below the conflict-overlap weight'),
      ]),
    ];
  }

  List<SyntheticScenarioCase> _safetyCases() {
    const fam = SyntheticScenarioFamily.safetyCopyNoPhi;
    return [
      _case(
          fam,
          'safe_copy',
          'shared safety copy is non-prescriptive',
          {'probe': 'safe_copy'},
          [_inv('no_banned', 'Shared safety copy has no banned phrases')]),
      _case(
          fam,
          'unsafe_probe',
          'detector catches an injected unsafe phrase',
          {'probe': 'unsafe_probe'},
          [_inv('detects_unsafe', 'Banned-phrase detector flags unsafe text')]),
      _case(fam, 'nophi_clean', 'safe sample has no forbidden PHI keys', {
        'probe': 'nophi_clean'
      }, [
        _inv('nophi_clean', 'Safety-policy values allowed; no forbidden keys')
      ]),
      _case(fam, 'nophi_catch', 'detector catches a forbidden PHI key', {
        'probe': 'nophi_catch'
      }, [
        _inv('detects_phi', 'Key-level scan flags a forbidden patient key')
      ]),
    ];
  }

  // --- Evaluation (real code) ----------------------------------------------
  SyntheticScenarioEvaluation _evaluate(SyntheticScenarioCase c) {
    final failed = <String>[];
    final signals = <String>[];
    final unsafeHits = <String>[];
    final phiHits = <String>[];
    var rankerSwitch = false;
    var missingnessReg = false;
    var dosageReg = false;
    var sourceQualityReg = false;

    void fail(String invariantId, String category) {
      failed.add(invariantId);
      switch (category) {
        case SyntheticScenarioFailureCategory.dosageRegression:
          dosageReg = true;
        case SyntheticScenarioFailureCategory.missingnessRegression:
          missingnessReg = true;
        case SyntheticScenarioFailureCategory.sourceQualityRegression:
          sourceQualityReg = true;
        case SyntheticScenarioFailureCategory.unexpectedRankerSwitch:
          rankerSwitch = true;
      }
    }

    try {
      final probe = c.inputSummary['probe'] as String?;
      switch (probe) {
        case 'dosage':
          _evalDosage(c, signals, fail);
        case 'missingness':
          _evalMissingness(c, signals, fail);
        case 'release':
          _evalRelease(c, signals, fail);
        case 'tier_ordering':
        case 'missing_source_refs':
        case 'authority':
          _evalSourceQuality(c, signals, fail);
        case 'no_window':
        case 'valid_window':
        case 'tiebreak':
          _evalWindow(c, signals, fail);
        case 'safe_copy':
        case 'unsafe_probe':
        case 'nophi_clean':
        case 'nophi_catch':
          _evalSafety(c, signals, unsafeHits, phiHits, fail);
        default:
          failed.add('missing_artifact');
          signals.add(SyntheticScenarioFailureCategory.missingArtifact);
      }
    } catch (e) {
      failed.add('unexpected_exception');
      signals
          .add('${SyntheticScenarioFailureCategory.unexpectedException}: $e');
    }

    return SyntheticScenarioEvaluation(
      scenarioId: c.scenarioId,
      passed: failed.isEmpty,
      failedInvariants: failed,
      observedSignals: signals,
      unsafePhraseHits: unsafeHits,
      phiKeyHits: phiHits,
      unexpectedRankerSwitch: rankerSwitch,
      missingnessRegression: missingnessReg,
      dosageRegression: dosageReg,
      sourceQualityRegression: sourceQualityReg,
    );
  }

  void _evalDosage(SyntheticScenarioCase c, List<String> signals,
      void Function(String, String) fail) {
    final p = c.inputSummary;
    final result = _validator.validate(RawMedicationEntry(
      freeText: p['free_text'] as String?,
      activeIngredients: const ['carbidopa', 'levodopa'],
      drugProductVariant: 'v1',
      strength: p['strength'] as num?,
      unit: p['unit'] as String?,
      form: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      jurisdiction: 'US',
      sourceDocId: 'spl:demo',
    ));
    final valid = result.validity == MedicationContextValidity.valid;
    signals.add('validity=${result.validity.name}');
    final expectValid = c.scenarioId.endsWith('valid_explicit');
    if (expectValid) {
      if (!valid) {
        fail('valid_dose', SyntheticScenarioFailureCategory.dosageRegression);
      }
    } else {
      if (valid) {
        fail('dose_not_valid',
            SyntheticScenarioFailureCategory.dosageRegression);
      }
      // No fabricated dose: when not valid, there is no normalized context.
      if (result.normalized != null) {
        fail('no_fabricated_dose',
            SyntheticScenarioFailureCategory.dosageRegression);
      }
    }
  }

  double _completenessFor(MealComposition comp) => comp.compositionCompleteness;

  void _evalMissingness(SyntheticScenarioCase c, List<String> signals,
      void Function(String, String) fail) {
    final kind = c.inputSummary['kind'] as String;
    MealComposition build({
      double? protein = 12,
      double? calories = 180,
      double? portion = 150,
    }) =>
        _normalizer.normalize(
          mealId: 'fuzz_$kind',
          declaredPhysicalForm: MealPhysicalForm.solid,
          components: [
            FoodComponent(
              id: 'food.synth',
              name: 'demo food (synthetic)',
              physicalForm: MealPhysicalForm.solid,
              proteinGrams: protein,
              fatGrams: 5,
              fiberGrams: 2,
              carbohydrateGrams: 20,
              calories: calories,
              portionGrams: portion,
              sourceDocId: 'synthetic:demo_food',
            ),
          ],
        );

    final baseline = _completenessFor(build());
    switch (kind) {
      case 'complete':
        signals.add('completeness=$baseline');
        if (baseline < 0.99) {
          fail('complete_baseline',
              SyntheticScenarioFailureCategory.missingnessRegression);
        }
      case 'true_zero':
        final zero = _completenessFor(build(protein: 0));
        signals.add('true_zero_completeness=$zero baseline=$baseline');
        // True 0 g is present data → completeness equals the complete baseline.
        if (zero < baseline) {
          fail('zero_not_missing',
              SyntheticScenarioFailureCategory.missingnessRegression);
        }
      case 'missing_protein':
        final v = _completenessFor(build(protein: null));
        signals.add('missing_protein_completeness=$v baseline=$baseline');
        if (!(v < baseline)) {
          fail('missing_lowers',
              SyntheticScenarioFailureCategory.missingnessRegression);
        }
      case 'missing_calories':
        final v = _completenessFor(build(calories: null));
        signals.add('missing_calories_completeness=$v baseline=$baseline');
        if (!(v < baseline)) {
          fail('missing_lowers',
              SyntheticScenarioFailureCategory.missingnessRegression);
        }
      case 'missing_portion':
        final v = _completenessFor(build(portion: null));
        signals.add('missing_portion_completeness=$v baseline=$baseline');
        if (!(v < baseline)) {
          fail('missing_lowers',
              SyntheticScenarioFailureCategory.missingnessRegression);
        }
    }
  }

  MedicationTimelineEvent _medEvent(String releaseType,
      {required int minute, bool nonLevodopa = false}) {
    final v = _validator.validate(RawMedicationEntry(
      activeIngredients: nonLevodopa
          ? const ['ferrous sulfate']
          : const ['carbidopa', 'levodopa'],
      drugProductVariant: 'v1',
      strength: 100,
      unit: 'mg',
      form: 'tablet',
      route: 'oral',
      releaseType: releaseType,
      jurisdiction: 'US',
      sourceDocId: 'spl:demo',
    ));
    return MedicationTimelineEvent(
        id: 'm', minute: minute, context: v.normalized!);
  }

  void _evalRelease(SyntheticScenarioCase c, List<String> signals,
      void Function(String, String) fail) {
    final rt = c.inputSummary['release_type'] as String;
    final nonLevodopa = c.inputSummary['non_levodopa'] == true;
    final ir =
        _absorption.build(medication: _medEvent('immediate', minute: 60));
    final irWidth = ir.window.endMinute - ir.window.startMinute;

    if (nonLevodopa) {
      final ev = _absorption.build(
          medication: _medEvent('immediate', minute: 60, nonLevodopa: true));
      final width = ev.window.endMinute - ev.window.startMinute;
      final flaggedNonLevodopa = ev.missingInputs
              .contains('active_ingredient_is_levodopa') ||
          ev.assumptions.contains('ldopa.absorption.non_levodopa_passthrough');
      signals.add('non_levodopa width=$width flagged=$flaggedNonLevodopa');
      // A non-levodopa event must NOT receive a real levodopa absorption window:
      // the model returns a degenerate (zero-width) passthrough window flagged as
      // non-levodopa, so it cannot contaminate levodopa-specific scoring.
      if (!(width == 0 && flaggedNonLevodopa)) {
        fail('non_levodopa_isolated', 'unexpected_signal');
      }
      return;
    }

    final w = _absorption.build(medication: _medEvent(rt, minute: 60));
    final width = w.window.endMinute - w.window.startMinute;
    signals.add('release=$rt width=$width ir_width=$irWidth '
        'uncertainty=${w.uncertaintyBand.name}');
    switch (c.scenarioId.split('__').last) {
      case 'ir':
        if (irWidth <= 0) fail('ir_window', 'unexpected_signal');
      case 'er_wider':
        if (!(width > irWidth)) fail('er_wider', 'unexpected_signal');
      case 'cr_wider':
        if (!(width > irWidth)) fail('cr_wider', 'unexpected_signal');
      case 'unknown_widens':
        const order = [
          UncertaintyBand.narrow,
          UncertaintyBand.moderate,
          UncertaintyBand.wide,
          UncertaintyBand.veryWide,
        ];
        final wider = order.indexOf(w.uncertaintyBand) >
            order.indexOf(ir.uncertaintyBand);
        final limited = w.assumptions
            .contains('ldopa.absorption.release_type_unknown_limited');
        if (!wider && !limited) {
          fail('unknown_uncertain', 'unexpected_signal');
        }
    }
  }

  FoodVariantMetadata _foodMeta(
          {List<String> sourceRefs = const ['src.usda.fdc.foundation_docs']}) =>
      FoodVariantMetadata(
        foodVariantId: 'f1',
        sourceSystem: 'usda_fdc',
        jurisdiction: 'US',
        language: 'und',
        foodName: 'demo food (synthetic)',
        basisType: 'per_100g',
        servingUnit: 'g',
        preparationState: 'raw',
        aminoAcidFieldsPresent: true,
        extractionConfidence: null,
        sourceRefs: sourceRefs,
        limitationText: 'educational',
      );

  void _evalSourceQuality(SyntheticScenarioCase c, List<String> signals,
      void Function(String, String) fail) {
    final probe = c.inputSummary['probe'] as String;
    if (probe == 'tier_ordering') {
      double w(NutrientConfidenceTier t) =>
          _gate.toWeight(_gate.scoreCandidateFood(_foodMeta(),
              nutrientCompleteness: 1.0, nutrientConfidenceTier: t));
      final a = w(NutrientConfidenceTier.analytical);
      final ca = w(NutrientConfidenceTier.calculated);
      final im = w(NutrientConfidenceTier.imputedOrAssumed);
      final un = w(NutrientConfidenceTier.unknown);
      signals.add('weights a=$a c=$ca i=$im u=$un');
      if (!(a >= ca && ca >= im && im >= un && a > un)) {
        fail('tier_ordering',
            SyntheticScenarioFailureCategory.sourceQualityRegression);
      }
    } else if (probe == 'missing_source_refs') {
      final withRefs = _gate.toWeight(_gate.scoreCandidateFood(_foodMeta(),
          nutrientCompleteness: 1.0,
          nutrientConfidenceTier: NutrientConfidenceTier.analytical));
      final noRefs = _gate.toWeight(_gate.scoreCandidateFood(
          _foodMeta(sourceRefs: const []),
          nutrientCompleteness: 1.0,
          nutrientConfidenceTier: NutrientConfidenceTier.analytical));
      signals.add('with_refs=$withRefs no_refs=$noRefs');
      if (!(noRefs < withRefs)) {
        fail('refs_lower',
            SyntheticScenarioFailureCategory.sourceQualityRegression);
      }
    } else {
      // authority: official in-jurisdiction ≥ synthetic, same jurisdiction chain.
      SourceDocumentMetadata doc(SourceAuthorityTier tier) =>
          SourceDocumentMetadata(
            sourceDocId: 'src.${tier.name}',
            sourceSystem: tier.name,
            jurisdiction: 'US',
            language: 'en',
            sourceOwner: 'demo',
            docType: 'food_composition',
            authorityTier: tier,
            translationStatus: ReferenceTranslationStatus.notTranslation,
            publishedAt: null,
            effectiveAt: null,
            lastUpdated: null,
            licenseOrUseLimitations: 'educational_prototype',
            sourceRefs: const ['src.demo'],
            limitationText: 'educational',
          );
      final official = _authority.score(
          doc(SourceAuthorityTier.officialDatabaseInJurisdiction),
          userJurisdictionChain: const ['US']);
      final synthetic = _authority.score(doc(SourceAuthorityTier.syntheticDemo),
          userJurisdictionChain: const ['US']);
      signals.add('official=$official synthetic=$synthetic');
      if (!(official >= synthetic)) {
        fail('authority_order',
            SyntheticScenarioFailureCategory.sourceQualityRegression);
      }
    }
  }

  TimeAxisConflictContext _baseContext({required bool withWindow}) {
    final now = DateTime.utc(2026, 1, 1, 8);
    final v = _validator.validate(const RawMedicationEntry(
      activeIngredients: ['carbidopa', 'levodopa'],
      drugProductVariant: 'v1',
      strength: 100,
      unit: 'mg',
      form: 'tablet',
      route: 'oral',
      releaseType: 'immediate',
      jurisdiction: 'US',
      sourceDocId: 'spl:demo',
    ));
    return _builder.build(
      now: now,
      medicationInputs: [
        MedicationTimelineInput(
            id: 'm',
            takenAt: now.add(const Duration(minutes: 30)),
            medicationContext: v),
      ],
      mealInputs: const [],
      userDefinedWindow: withWindow
          ? UserDefinedMealWindow(
              window: TimelineWindow(
                  startMinute: dateTimeToMinute(now) + 60,
                  endMinute: dateTimeToMinute(now) + 120),
              source: 'fuzz')
          : null,
    );
  }

  CandidateFood _candidate(String id) => CandidateFood(
        id: id,
        name: id,
        regionalFoodLibraryRef: 'synthetic',
        declaredPhysicalForm: MealPhysicalForm.solid,
        components: [
          FoodComponent(
            id: id,
            name: id,
            physicalForm: MealPhysicalForm.solid,
            proteinGrams: 8,
            fatGrams: 2,
            fiberGrams: 1,
            carbohydrateGrams: 20,
            calories: 150,
            portionGrams: 150,
            sourceDocId: 'synthetic',
          ),
        ],
      );

  CandidateMetadata _candMeta(double q) => CandidateMetadata(
        completeness: q,
        authorityScore: q,
        jurisdictionMatchScore: q,
        provenanceQuality: q,
        jurisdiction: 'US',
      );

  void _evalWindow(SyntheticScenarioCase c, List<String> signals,
      void Function(String, String) fail) {
    final probe = c.inputSummary['probe'] as String;
    if (probe == 'no_window') {
      final scores = _scorer.score(
        baseContext: _baseContext(withWindow: false),
        baseMealCompositionsById: const {},
        candidates: [_candidate('a')],
      );
      signals.add('insufficient=${scores.first.insufficientContext}');
      if (!scores.first.insufficientContext) {
        fail('no_window_fallback',
            SyntheticScenarioFailureCategory.unexpectedRankerSwitch);
      }
    } else if (probe == 'valid_window') {
      final scores = _scorer.score(
        baseContext: _baseContext(withWindow: true),
        baseMealCompositionsById: const {},
        candidates: [_candidate('a')],
        candidateMetadata: {'a': _candMeta(0.6)},
      );
      signals.add('insufficient=${scores.first.insufficientContext}');
      if (scores.first.insufficientContext) {
        fail('window_scored',
            SyntheticScenarioFailureCategory.unexpectedRankerSwitch);
      }
    } else {
      // tiebreak: identical composition, differ only in provenance.
      final scores = _scorer.score(
        baseContext: _baseContext(withWindow: true),
        baseMealCompositionsById: const {},
        candidates: [_candidate('best'), _candidate('worst')],
        candidateMetadata: {'best': _candMeta(1.0), 'worst': _candMeta(0.0)},
      );
      double of(String id) =>
          scores.firstWhere((e) => e.candidateFoodId == id).finalCandidateScore;
      final gap = of('best') - of('worst');
      final params = NextMealScoringParameterSet.literatureInformedDefault();
      signals.add('gap=$gap provenanceWeightSum=${params.provenanceWeightSum} '
          'conflictWeight=${params.conflictOverlap.value}');
      if (gap < 0) {
        fail('tiebreak',
            SyntheticScenarioFailureCategory.sourceQualityRegression);
      }
      if (!(params.provenanceWeightSum < params.conflictOverlap.value)) {
        fail('conflict_dominant',
            SyntheticScenarioFailureCategory.sourceQualityRegression);
      }
    }
  }

  void _scanKeys(Object? node, void Function(String) onHit) {
    if (node is Map) {
      for (final entry in node.entries) {
        if (_forbiddenPhiKeys.contains(entry.key.toString().toLowerCase())) {
          onHit(entry.key.toString());
        }
        _scanKeys(entry.value, onHit);
      }
    } else if (node is List) {
      for (final e in node) {
        _scanKeys(e, onHit);
      }
    }
  }

  void _evalSafety(
      SyntheticScenarioCase c,
      List<String> signals,
      List<String> unsafeHits,
      List<String> phiHits,
      void Function(String, String) fail) {
    final probe = c.inputSummary['probe'] as String;
    switch (probe) {
      case 'safe_copy':
        const text = '${RuleExplanation.defaultNotAdvice} '
            '${RuleExplanation.defaultSafetyBoundary}';
        final hits = findBannedSubstrings(text);
        unsafeHits.addAll(hits);
        signals.add('banned_hits=${hits.length}');
        if (hits.isNotEmpty) {
          fail('no_banned', SyntheticScenarioFailureCategory.unsafePhraseHit);
        }
      case 'unsafe_probe':
        // A deliberately unsafe synthetic string; the detector MUST flag it.
        const probeText = 'You should adjust your dose and take your '
            'medication at a set time.';
        final hits = findBannedSubstrings(probeText);
        signals.add('detected_banned=${hits.length}');
        if (hits.isEmpty) {
          fail('detects_unsafe',
              SyntheticScenarioFailureCategory.unsafePhraseHit);
        }
      case 'nophi_clean':
        // Safety-policy VALUE names omission but uses no forbidden keys.
        final sample = {
          'phi_policy': 'no_patient_no_subject_no_encounter',
          'conformance_status': 'local_not_fhir_provenance_not_w3c_prov',
          'nodes': [
            {'id': 'safety_boundary', 'summary': 'educational boundary'}
          ],
        };
        final hits = <String>[];
        _scanKeys(sample, hits.add);
        signals.add('forbidden_keys=${hits.length}');
        if (hits.isNotEmpty) {
          phiHits.addAll(hits);
          fail('nophi_clean', SyntheticScenarioFailureCategory.phiKeyHit);
        }
      case 'nophi_catch':
        // A sample that DOES contain a forbidden key; the scan MUST detect it.
        final bad = {
          'patient': {'id': 'x'}
        };
        final hits = <String>[];
        _scanKeys(bad, hits.add);
        signals.add('detected_forbidden_keys=${hits.length}');
        if (hits.isEmpty) {
          fail('detects_phi', SyntheticScenarioFailureCategory.phiKeyHit);
        }
    }
  }
}

/// Deterministic JSON encoder.
String encodeSyntheticScenarioReport(SyntheticScenarioFuzzerReport report) =>
    const JsonEncoder.withIndent('  ').convert(report.toJson());

/// Deterministic markdown report.
String renderSyntheticScenarioMarkdown(SyntheticScenarioFuzzerReport report) {
  final b = StringBuffer()
    ..writeln('# ParkinSUM Synthetic Scenario Fuzzer')
    ..writeln()
    ..writeln('Educational/research prototype. Synthetic data only. **Not '
        'medical advice, not clinically calibrated, not patient simulation, and '
        'carries no clinical-validation claim.** Deterministic regression/stress '
        'testing of existing gates.')
    ..writeln()
    ..writeln('- seed: `${report.seed}`')
    ..writeln('- case count: ${report.caseCount}')
    ..writeln('- passed: ${report.passed}')
    ..writeln('- failed: ${report.failed}')
    ..writeln('- families: ${report.families.join(', ')}')
    ..writeln()
    ..writeln('| scenario | family | passed | failed invariants | signals |')
    ..writeln('| --- | --- | --- | --- | --- |');
  for (final r in report.cases) {
    final e = r.evaluation;
    b.writeln('| ${r.scenario.scenarioId} | ${r.scenario.family} | '
        '${e.passed ? 'yes' : 'NO'} | ${e.failedInvariants.join('; ')} | '
        '${e.observedSignals.join('; ')} |');
  }
  b
    ..writeln()
    ..writeln('## Limitations')
    ..writeln();
  for (final l in report.limitations) {
    b.writeln('- $l');
  }
  b
    ..writeln()
    ..writeln('## Safety boundary')
    ..writeln()
    ..writeln(report.safetyBoundary)
    ..writeln()
    ..writeln(report.notAdviceText);
  return b.toString();
}
