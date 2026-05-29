import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/absorption_opportunity.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/amino_acid_competition_model.dart';
import 'package:parkinsum_companion/domain/usecases/gastric_emptying_model.dart';
import 'package:parkinsum_companion/domain/usecases/levodopa_absorption_opportunity_model.dart';
import 'package:parkinsum_companion/domain/usecases/meal_composition_normalizer.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

/// Guards #3: levodopa absorption is a sampled openness curve (not only a flat
/// window). IR is sharper/shorter, ER/controlled is flatter/longer; candidate
/// competition overlap is openness-weighted. Educational only — not blood
/// concentration, not PK/PD calibration.
void main() {
  final validator = MedicationEntryValidator();
  final absorption = LevodopaAbsorptionOpportunityModel();
  final normalizer = MealCompositionNormalizer();
  final emptying = GastricEmptyingModel();
  final competition = AminoAcidCompetitionModel();

  MedicationTimelineEvent medEvent(String releaseType) {
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
    return MedicationTimelineEvent(id: 'm', minute: 60, context: v.normalized!);
  }

  test('IR and ER both emit a non-empty openness profile (in toJson)', () {
    final ir = absorption.build(medication: medEvent('immediate'));
    expect(ir.opennessProfile, isNotEmpty);
    expect(ir.toJson()['openness_profile'], isNotEmpty);
    expect(ir.toJson().containsKey('peak_openness'), isTrue);
  });

  test('ER/controlled profile is flatter and longer than IR', () {
    final ir = absorption.build(medication: medEvent('immediate'));
    final er = absorption.build(medication: medEvent('extended'));

    final irLen = ir.window.endMinute - ir.window.startMinute;
    final erLen = er.window.endMinute - er.window.startMinute;
    expect(erLen, greaterThan(irLen)); // longer

    // Flatter: ER sustains a higher tail openness at the window end than IR.
    expect(er.opennessProfile.last.openness,
        greaterThan(ir.opennessProfile.last.openness));
    // Sharper IR: its peak openness exceeds ER's peak openness.
    expect(ir.peakOpenness, greaterThan(er.peakOpenness));
  });

  test('openness-weighted overlap differs from a flat in-window average', () {
    // High-protein solid meal starting at minute 0; dose at +30 min.
    final comp = normalizer.normalize(
      mealId: 'c',
      components: const [
        FoodComponent(
          id: 'p',
          name: 'protein',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 30,
          fatGrams: 5,
          fiberGrams: 0,
          carbohydrateGrams: 0,
          calories: 200,
          portionGrams: 180,
          sourceDocId: 'synthetic',
        ),
      ],
    );
    final profile =
        emptying.build(mealId: 'c', mealStartMinute: 0, composition: comp);
    final med = MedicationTimelineEvent(
        id: 'm', minute: 30, context: medEvent('immediate').context);
    final window =
        absorption.build(medication: med, overlappingMealProfile: profile);
    expect(window.opennessProfile, isNotEmpty);

    final weighted = competition.build(
      mealComposition: comp,
      mealEmptyingProfile: profile,
      absorptionWindow: window,
      mealStartMinute: 0,
    );

    // Same inputs, but strip the openness profile → forces the flat-average
    // fallback path. The two overlaps should differ (weighting is active).
    final flatWindow = AbsorptionOpportunityWindow(
      medicationEventId: window.medicationEventId,
      window: window.window,
      peakMinute: window.peakMinute,
      delayedArrivalLikelihood: window.delayedArrivalLikelihood,
      uncertaintyBand: window.uncertaintyBand,
      assumptions: window.assumptions,
      missingInputs: window.missingInputs,
      sourceRefs: window.sourceRefs,
      // opennessProfile defaults to empty → flat membership average.
    );
    final flat = competition.build(
      mealComposition: comp,
      mealEmptyingProfile: profile,
      absorptionWindow: flatWindow,
      mealStartMinute: 0,
    );

    expect(weighted.overlapWithAbsorptionWindow,
        isNot(closeTo(flat.overlapWithAbsorptionWindow, 1e-6)));
    expect(
      weighted.assumptions.any((a) => a.contains('openness_weighted_overlap')),
      isTrue,
    );
  });
}
