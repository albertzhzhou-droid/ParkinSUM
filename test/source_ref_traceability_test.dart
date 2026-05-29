import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/gastric_emptying_parameters.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_conflict_engine.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';
import 'package:parkinsum_companion/domain/usecases/model_assumption_registry.dart';
import 'package:parkinsum_companion/domain/usecases/next_meal_scoring_parameters.dart';
import 'package:parkinsum_companion/domain/usecases/time_axis_builder.dart';

/// FAIR "Reusable/Interoperable" guard (OPP-F3 / scorecard S9): every evidence
/// `sourceRef` emitted by the deterministic **mechanism layer** must resolve to
/// a `ModelAssumptionRegistry` entry that carries citation text. This locks the
/// evidence-linkage invariant — the engine cannot emit an unresolvable
/// reference, and adding a new mechanism sourceRef without registering it fails
/// here. Importer/source-authority identity refs (e.g. `src.ciqual`,
/// `src.nhs.dmd`) are a separate namespace and are intentionally out of scope.
void main() {
  final validator = MedicationEntryValidator();
  final builder = TimeAxisBuilder();
  final engine = MechanisticConflictEngine();
  final normalizer = MealCompositionNormalizer();

  bool resolves(String ref) => ModelAssumptionRegistry.byId(ref) != null;

  MedicationTimelineEvent levodopa(String releaseType) {
    final v = validator.validate(RawMedicationEntry(
      activeIngredients: const ['carbidopa', 'levodopa'],
      drugProductVariant: 'synthetic:demo',
      strength: 100,
      unit: 'mg',
      form: 'tablet',
      route: 'oral',
      releaseType: releaseType,
      jurisdiction: 'US',
      sourceDocId: 'synthetic:demo',
    ));
    return MedicationTimelineEvent(id: 'm', minute: 30, context: v.normalized!);
  }

  // Collect every sourceRef the mechanism layer emits across representative
  // evaluations (IR + ER) and both data paths (actual amino-acid fields +
  // protein-source proxy), plus the two literature-informed parameter sets.
  Set<String> collectMechanismRefs() {
    final refs = <String>{};

    // Parameter sets (provenance-tagged weights).
    refs.addAll(GastricEmptyingParameterSet.literatureInformedDefault()
        .unionSourceRefs);
    for (final w
        in NextMealScoringParameterSet.literatureInformedDefault().all) {
      refs.addAll(w.sourceRefs);
    }

    FoodComponent food(
            {AminoAcidProfile? aa, required ProteinSourceType src}) =>
        FoodComponent(
          id: 'f',
          name: 'f',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 26,
          fatGrams: 6,
          fiberGrams: 1,
          carbohydrateGrams: 5,
          calories: 220,
          portionGrams: 160,
          sourceDocId: 'synthetic',
          proteinSource: src,
          aminoAcidProfile: aa,
        );

    void runEval(MedicationTimelineEvent med, FoodComponent component) {
      final composition =
          normalizer.normalize(mealId: 'c', components: [component]);
      final ctx = builder.build(
        now: DateTime.utc(2026, 1, 1, 8),
        medicationInputs: [
          MedicationTimelineInput(
            id: med.id,
            takenAt: DateTime.utc(2026, 1, 1, 8, 0)
                .add(Duration(minutes: med.minute)),
            medicationContext: validator.validate(const RawMedicationEntry(
              activeIngredients: ['carbidopa', 'levodopa'],
              drugProductVariant: 'synthetic:demo',
              strength: 100,
              unit: 'mg',
              form: 'tablet',
              route: 'oral',
              releaseType: 'immediate',
              jurisdiction: 'US',
              sourceDocId: 'synthetic:demo',
            )),
          ),
        ],
        mealInputs: [
          MealTimelineInput(
            id: 'meal',
            startedAt: DateTime.utc(2026, 1, 1, 8),
            compositionId: composition.id,
            physicalForm: MealPhysicalForm.solid,
          ),
        ],
      );
      final r = engine.evaluate(
          context: ctx, mealCompositionsById: {composition.id: composition});
      refs.addAll(r.sourceRefs);
      refs.addAll(r.primaryEmptyingProfile?.sourceRefs ?? const []);
      refs.addAll(r.absorptionOpportunityWindow?.sourceRefs ?? const []);
      final comp = r.competitionTimeline;
      if (comp != null) {
        refs.addAll(comp.sourceRefs);
        refs.addAll(comp.lnaaSummary?.sourceRefs ?? const []);
      }
    }

    // Actual amino-acid fields path (IR).
    runEval(
      levodopa('immediate'),
      food(
        src: ProteinSourceType.meat,
        aa: const AminoAcidProfile(
          leucine: 2.1,
          isoleucine: 1.2,
          valine: 1.3,
          phenylalanine: 1.0,
          tyrosine: 0.9,
          tryptophan: 0.3,
          basis: 'per_serving',
          sourceRefs: ['src.fdc.api.amino_acid_fields'],
        ),
      ),
    );
    // Protein-source proxy path (ER) — exercises protein_source registry refs.
    runEval(levodopa('extended'), food(src: ProteinSourceType.meat));

    return refs;
  }

  test('every mechanism-layer sourceRef resolves in ModelAssumptionRegistry',
      () {
    final refs = collectMechanismRefs();
    expect(refs, isNotEmpty);
    final unresolved = refs.where((r) => !resolves(r)).toList()..sort();
    expect(unresolved, isEmpty,
        reason: 'Unregistered mechanism sourceRef(s): $unresolved. Add a '
            'ModelAssumption to model_assumption_registry.dart (and a row in '
            'Bibliographies.md) for each.');
  });

  test('registry entries are well-formed (id, citation, review date)', () {
    expect(ModelAssumptionRegistry.all, isNotEmpty);
    for (final a in ModelAssumptionRegistry.all) {
      expect(a.sourceId, startsWith('src.'),
          reason: 'sourceId must be namespaced: ${a.sourceId}');
      expect(a.citationText.trim(), isNotEmpty,
          reason: '${a.sourceId} missing citation text');
      expect(a.lastReviewed, isNotEmpty,
          reason: '${a.sourceId} missing lastReviewed');
      // byId must round-trip every entry.
      expect(ModelAssumptionRegistry.byId(a.sourceId), isNotNull);
    }
  });

  test('sourceIds are unique', () {
    final ids = ModelAssumptionRegistry.all.map((a) => a.sourceId).toList();
    expect(ids.toSet().length, ids.length,
        reason: 'duplicate sourceId present');
  });
}
