import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_competition.dart';
import 'package:parkinsum_companion/domain/entities/amino_acid_profile.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/protein_source.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_competition_model.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

/// Guards #4: LNAA competition exposes absolute competing grams, a dose-relative
/// ratio ONLY when an explicit user dose is present, distinguishes partial
/// amino-acid data (widening uncertainty), and falls back to the protein-source
/// proxy when no actual amino-acid fields exist.
void main() {
  final normalizer = MealCompositionNormalizer();
  final emptying = GastricEmptyingModel();
  final absorption = LevodopaAbsorptionOpportunityModel();
  final competition = AminoAcidCompetitionModel();
  final validator = MedicationEntryValidator();

  MedicationTimelineEvent levodopa() {
    final v = validator.validate(
      const RawMedicationEntry(
        activeIngredients: ['carbidopa', 'levodopa'],
        drugProductVariant: 'synthetic:demo',
        strength: 100,
        unit: 'mg',
        form: 'tablet',
        route: 'oral',
        releaseType: 'immediate',
        jurisdiction: 'US',
        sourceDocId: 'synthetic:demo',
      ),
    );
    return MedicationTimelineEvent(id: 'm', minute: 30, context: v.normalized!);
  }

  CompetitionLnaaSummary summaryFor(
    FoodComponent component, {
    double? levodopaDoseMg,
  }) {
    final comp = normalizer.normalize(mealId: 'c', components: [component]);
    final profile = emptying.build(
      mealId: 'c',
      mealStartMinute: 0,
      composition: comp,
    );
    final window = absorption.build(
      medication: levodopa(),
      overlappingMealProfile: profile,
    );
    final timeline = competition.build(
      mealComposition: comp,
      mealEmptyingProfile: profile,
      absorptionWindow: window,
      mealStartMinute: 0,
      levodopaDoseMg: levodopaDoseMg,
    );
    return timeline.lnaaSummary!;
  }

  FoodComponent withProfile(
    AminoAcidProfile? aa, {
    ProteinSourceType source = ProteinSourceType.meat,
  }) => FoodComponent(
    id: 'food',
    name: 'food',
    physicalForm: MealPhysicalForm.solid,
    proteinGrams: 26,
    fatGrams: 5,
    fiberGrams: 0,
    carbohydrateGrams: 0,
    calories: 200,
    portionGrams: 150,
    sourceDocId: 'fdc',
    proteinSource: source,
    aminoAcidProfile: aa,
  );

  test('full amino-acid profile → actual mode + absolute competing grams', () {
    final s = summaryFor(
      withProfile(
        const AminoAcidProfile(
          leucine: 2.1,
          isoleucine: 1.2,
          valine: 1.3,
          phenylalanine: 1.0,
          tyrosine: 0.9,
          tryptophan: 0.3,
          basis: 'per_serving',
        ),
      ),
    );
    expect(s.dataMode, AminoAcidDataMode.actualAminoAcidFields);
    expect(
      s.competingLnaaGrams,
      closeTo(2.1 + 1.2 + 1.3 + 1.0 + 0.9 + 0.3, 1e-9),
    );
    expect(s.competingLnaaGramsPerServing, isNotNull); // portion known
    expect(s.partialAminoAcidData, isFalse);
  });

  test(
    'partial profile falls back to proxy and remains explicitly partial',
    () {
      final s = summaryFor(
        withProfile(
          // Only 3 of the 6 LNAA present → partial.
          const AminoAcidProfile(leucine: 2.1, valine: 1.3, tryptophan: 0.3),
        ),
      );
      expect(s.dataMode, AminoAcidDataMode.proteinSourceProxy);
      expect(s.partialAminoAcidData, isTrue);
      expect(s.uncertaintyWidened, isTrue); // NOT treated as fully narrow
      expect(s.actualAminoAcidProteinCoverageFraction, 0);
      expect(s.competingLnaaGrams, isNull);
    },
  );

  test('no amino-acid fields → protein-source proxy fallback', () {
    final s = summaryFor(withProfile(null));
    expect(s.dataMode, AminoAcidDataMode.proteinSourceProxy);
    expect(s.competingLnaaGrams, isNull); // proxy does not measure grams
    expect(s.doseRelativeAvailable, isFalse);
  });

  test('explicit dose → dose-relative ratio populated', () {
    final s = summaryFor(
      withProfile(
        const AminoAcidProfile(
          leucine: 2.0,
          isoleucine: 1.0,
          valine: 1.0,
          phenylalanine: 1.0,
          tyrosine: 0.5,
          tryptophan: 0.5,
          basis: 'per_serving',
        ),
      ),
      levodopaDoseMg: 100,
    );
    expect(s.doseRelativeAvailable, isTrue);
    // 6.0 g LNAA / (100 mg / 100) = 6.0 g per 100 mg levodopa.
    expect(s.doseRelativeLnaaRatio, closeTo(6.0, 1e-9));
  });

  test(
    'non-analytical FDC provenance widens uncertainty + surfaces tier (B1)',
    () {
      // Full LNAA set, all imputed → aggregate tier imputedOrAssumed → widen.
      const imputed = NutrientDerivation(derivationDescription: 'Imputed');
      final s = summaryFor(
        withProfile(
          const AminoAcidProfile(
            leucine: 2.0,
            isoleucine: 1.0,
            valine: 1.0,
            phenylalanine: 1.0,
            tyrosine: 0.5,
            tryptophan: 0.5,
            basis: 'per_serving',
            derivations: {
              'leucine': imputed,
              'isoleucine': imputed,
              'valine': imputed,
              'phenylalanine': imputed,
              'tyrosine': imputed,
              'tryptophan': imputed,
            },
          ),
        ),
      );
      expect(s.dataMode, AminoAcidDataMode.actualAminoAcidFields);
      expect(s.aminoAcidConfidenceTier, 'imputedOrAssumed');
      expect(s.uncertaintyWidened, isTrue);
      // The FDC provenance source ref is attached when a tier is present.
      expect(s.sourceRefs, contains('src.usda.fdc.foundation_docs'));
    },
  );

  test('analytical FDC provenance does NOT widen uncertainty (B1)', () {
    const analytical = NutrientDerivation(derivationCode: 'A');
    final s = summaryFor(
      withProfile(
        const AminoAcidProfile(
          leucine: 2.0,
          isoleucine: 1.0,
          valine: 1.0,
          phenylalanine: 1.0,
          tyrosine: 0.5,
          tryptophan: 0.5,
          basis: 'per_serving',
          derivations: {
            'leucine': analytical,
            'isoleucine': analytical,
            'valine': analytical,
            'phenylalanine': analytical,
            'tyrosine': analytical,
            'tryptophan': analytical,
          },
        ),
      ),
    );
    expect(s.aminoAcidConfidenceTier, 'analytical');
    expect(s.uncertaintyWidened, isFalse);
  });

  test('missing/non-explicit dose → dose-relative ratio unavailable', () {
    final s = summaryFor(
      withProfile(
        const AminoAcidProfile(
          leucine: 2.0,
          isoleucine: 1.0,
          valine: 1.0,
          phenylalanine: 1.0,
          tyrosine: 0.5,
          tryptophan: 0.5,
          basis: 'per_serving',
        ),
      ),
      levodopaDoseMg: null, // no explicit dose
    );
    expect(s.doseRelativeAvailable, isFalse);
    expect(s.doseRelativeLnaaRatio, isNull); // never invented
  });

  group('trace detail', () {
    CompetitionLnaaSummary mealSummary(
      List<FoodComponent> components, {
      double? levodopaDoseMg,
    }) {
      final comp = normalizer.normalize(mealId: 'c', components: components);
      final profile = emptying.build(
        mealId: 'c',
        mealStartMinute: 0,
        composition: comp,
      );
      return competition
          .build(
            mealComposition: comp,
            mealEmptyingProfile: profile,
            absorptionWindow: absorption.build(
              medication: levodopa(),
              overlappingMealProfile: profile,
            ),
            mealStartMinute: 0,
            levodopaDoseMg: levodopaDoseMg,
          )
          .lnaaSummary!;
    }

    FoodComponent component(
      String id,
      AminoAcidProfile? aa, {
      double protein = 20,
    }) => FoodComponent(
      id: id,
      name: id,
      physicalForm: MealPhysicalForm.solid,
      proteinGrams: protein,
      fatGrams: 5,
      fiberGrams: 0,
      carbohydrateGrams: 0,
      calories: 200,
      portionGrams: 150,
      sourceDocId: 'synthetic',
      proteinSource: ProteinSourceType.meat,
      aminoAcidProfile: aa,
    );

    // 2+1+1+1+0.5+0.5 = 6 g; methionine 0.6 + histidine 0.7.
    const first = AminoAcidProfile(
      leucine: 2.0,
      isoleucine: 1.0,
      valine: 1.0,
      phenylalanine: 1.0,
      tyrosine: 0.5,
      tryptophan: 0.5,
      methionine: 0.6,
      histidine: 0.7,
      basis: 'per_serving',
    );
    // 1+0.5+0.5+0.5+0.25+0.25 = 3 g; no methionine or histidine.
    const second = AminoAcidProfile(
      leucine: 1.0,
      isoleucine: 0.5,
      valine: 0.5,
      phenylalanine: 0.5,
      tyrosine: 0.25,
      tryptophan: 0.25,
      basis: 'per_serving',
    );

    test('actual mode lists per-component contributions that add up', () {
      final s = mealSummary([
        component('a', first),
        component('b', second, protein: 12),
      ]);
      expect(s.dataMode, AminoAcidDataMode.actualAminoAcidFields);
      expect(
        s.componentContributions.map((c) => c.componentId),
        containsAll(['a', 'b']),
      );
      final byId = {for (final c in s.componentContributions) c.componentId: c};
      expect(byId['a']!.competingLnaaGrams, closeTo(6, 1e-9));
      expect(byId['a']!.shareOfMealLnaa, closeTo(6 / 9, 1e-9));
      expect(byId['b']!.shareOfMealLnaa, closeTo(3 / 9, 1e-9));
      // One profile lacks methionine and histidine: no extended view.
      expect(s.extendedLnaaGrams, isNull);
      expect(s.molarLnaaToLevodopaRatio, isNull);
      expect(s.structuralIntegrityReasons, isEmpty);
      final json = s.toJson();
      expect(json['component_contributions'], hasLength(2));
      expect(json.containsKey('extended_lnaa_grams'), isFalse);
    });

    test('molar ratio uses molecular weights and needs an explicit dose', () {
      final s = mealSummary([component('a', first)], levodopaDoseMg: 100);
      final millimoles =
          2.0 * 1000 / 131.17 +
          1.0 * 1000 / 131.17 +
          1.0 * 1000 / 117.15 +
          1.0 * 1000 / 165.19 +
          0.5 * 1000 / 181.19 +
          0.5 * 1000 / 204.23;
      expect(
        s.molarLnaaToLevodopaRatio,
        closeTo(millimoles / (100 / 197.19), 1e-9),
      );
      expect(s.extendedLnaaGrams, closeTo(6 + 0.6 + 0.7, 1e-9));
      expect(s.structuralIntegrityReasons, isEmpty);
      final noDose = mealSummary([component('a', first)]);
      expect(noDose.molarLnaaToLevodopaRatio, isNull);
      expect(
        noDose.toJson().containsKey('molar_lnaa_to_levodopa_ratio'),
        isFalse,
      );
    });

    test('hybrid and proxy modes carry no per-component detail', () {
      final hybrid = mealSummary([
        component('a', first),
        component('b', null, protein: 12),
      ]);
      expect(
        hybrid.dataMode,
        AminoAcidDataMode.hybridActualAndProteinSourceProxy,
      );
      expect(hybrid.componentContributions, isEmpty);
      expect(hybrid.extendedLnaaGrams, isNull);
      final proxy = mealSummary([component('b', null)]);
      expect(proxy.componentContributions, isEmpty);
      expect(proxy.toJson().containsKey('component_contributions'), isFalse);
    });

    test('incoherent detail is an integrity failure', () {
      const base = CompetitionLnaaSummary(
        effectiveLoadFactor: 1,
        sourcesPresent: [],
        isPrototypeHeuristic: true,
        uncertaintyWidened: false,
        sourceRefs: [],
        dataMode: AminoAcidDataMode.actualAminoAcidFields,
        competingLnaaGrams: 6,
        actualAminoAcidProteinCoverageFraction: 1,
        componentContributions: [
          LnaaComponentContribution(
            componentId: 'a',
            competingLnaaGrams: 5,
            shareOfMealLnaa: 1,
          ),
        ],
        extendedLnaaGrams: 4,
        molarLnaaToLevodopaRatio: 3,
      );
      expect(
        base.structuralIntegrityReasons,
        containsAll([
          'competition.profile_lnaa_contributions_incoherent',
          'competition.profile_lnaa_extended_below_competing',
          'competition.profile_lnaa_molar_ratio_without_dose',
        ]),
      );
    });
  });
}
