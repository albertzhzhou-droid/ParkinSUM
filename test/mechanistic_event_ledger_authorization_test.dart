import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/meal_composition.dart';
import 'package:parkinsum_companion/domain/entities/time_axis_events.dart';
import 'package:parkinsum_companion/domain/usecases/algorithm_observatory_service.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_event_ledger_authorization.dart';
import 'package:parkinsum_companion/domain/usecases/mechanistic_event_ledger_builder.dart';

void main() {
  const authorizer = MechanisticEventLedgerAuthorizationService();

  test(
    'production-derived observatory input is authorized before evaluation',
    () {
      final snapshot = AlgorithmObservatoryService().build(
        ObservatoryScenario.mixedReference,
      );

      expect(snapshot.ledgerAuthorization.authorized, isTrue);
      expect(snapshot.ledgerAuthorization.findings, isEmpty);
      expect(
        snapshot.ledgerAuthorization.recomputedInputBindingSha256,
        snapshot.eventLedger.inputBindingSha256,
      );
      expect(snapshot.conflict.hasModeledOutput, isTrue);
      expect(snapshot.ledgerAuthorization.toJson(), contains('report_sha256'));
    },
  );

  test('configuration, context, and composition drift fail closed', () {
    final snapshot = AlgorithmObservatoryService().build(
      ObservatoryScenario.mixedReference,
    );
    final changedContext = TimeAxisConflictContext(
      referenceMinute: snapshot.context.referenceMinute,
      medicationEvents: snapshot.context.medicationEvents,
      mealEvents: snapshot.context.mealEvents,
      foodComponentEvents: snapshot.context.foodComponentEvents,
      userDefinedWindow: snapshot.context.userDefinedWindow,
      missingFields: {...snapshot.context.missingFields, 'mutated_field'},
    );
    final contextDecision = authorizer.authorize(
      ledger: snapshot.eventLedger,
      context: changedContext,
      mealCompositionsById: {snapshot.composition.id: snapshot.composition},
      expectedConfigurationSha256: snapshot.configurationIdentity.sha256Digest,
    );
    expect(contextDecision.authorized, isFalse);
    expect(
      contextDecision.assessment.findings,
      contains('authorization.input_binding_mismatch'),
    );

    final configurationDecision = authorizer.authorize(
      ledger: snapshot.eventLedger,
      context: snapshot.context,
      mealCompositionsById: {snapshot.composition.id: snapshot.composition},
      expectedConfigurationSha256:
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    expect(configurationDecision.authorized, isFalse);
    expect(
      configurationDecision.assessment.findings,
      contains('authorization.configuration_identity_mismatch'),
    );

    final compositionDecision = authorizer.authorize(
      ledger: snapshot.eventLedger,
      context: snapshot.context,
      mealCompositionsById: {'wrong_key': snapshot.composition},
      expectedConfigurationSha256: snapshot.configurationIdentity.sha256Digest,
    );
    expect(compositionDecision.authorized, isFalse);
    expect(
      compositionDecision.assessment.findings,
      contains('authorization.composition_map_identity_mismatch:wrong_key'),
    );
    expect(
      compositionDecision.assessment.findings,
      contains('authorization.meal_composition_missing:observatory_meal_event'),
    );
  });

  test(
    'authorization lease rechecks nested input before every engine read',
    () {
      final snapshot = AlgorithmObservatoryService().build(
        ObservatoryScenario.mixedReference,
      );
      final mutableComponents = <FoodComponent>[
        ...snapshot.composition.foodComponents,
      ];
      final mutableComposition = _copyComposition(
        snapshot.composition,
        foodComponents: mutableComponents,
      );
      final compositions = <String, MealComposition>{
        mutableComposition.id: mutableComposition,
      };
      final ledger = const MechanisticEventLedgerBuilder().build(
        ledgerId: 'mutable_authorization_fixture',
        context: snapshot.context,
        mealCompositionsById: compositions,
        configurationDigest: snapshot.configurationIdentity.sha256Digest,
        createdAtUtc: DateTime.utc(2026, 1, 1, 8),
        sourceId: 'synthetic:test',
        revisionId: 'authorization_test_v1',
        synthetic: true,
      );
      final decision = authorizer.authorize(
        ledger: ledger,
        context: snapshot.context,
        mealCompositionsById: compositions,
        expectedConfigurationSha256:
            snapshot.configurationIdentity.sha256Digest,
      );
      expect(decision.authorized, isTrue);

      mutableComponents.add(
        const FoodComponent(
          id: 'late_mutation',
          name: 'Late mutation',
          physicalForm: MealPhysicalForm.solid,
          proteinGrams: 1,
          fatGrams: 1,
          fiberGrams: 1,
          carbohydrateGrams: 1,
          calories: 1,
          portionGrams: 1,
          sourceDocId: 'synthetic:test',
        ),
      );

      expect(() => decision.view!.context, throwsStateError);
      expect(() => decision.view!.mealCompositionsById, throwsStateError);
    },
  );
}

MealComposition _copyComposition(
  MealComposition source, {
  required List<FoodComponent> foodComponents,
}) => MealComposition(
  id: source.id,
  totalCalories: source.totalCalories,
  proteinGrams: source.proteinGrams,
  fatGrams: source.fatGrams,
  fiberGrams: source.fiberGrams,
  carbohydrateGrams: source.carbohydrateGrams,
  liquidFraction: source.liquidFraction,
  mealPhysicalForm: source.mealPhysicalForm,
  portionSizeBand: source.portionSizeBand,
  proteinAmountBand: source.proteinAmountBand,
  fatAmountBand: source.fatAmountBand,
  fiberAmountBand: source.fiberAmountBand,
  calorieBand: source.calorieBand,
  compositionCompleteness: source.compositionCompleteness,
  missingFields: source.missingFields,
  foodComponents: foodComponents,
);
