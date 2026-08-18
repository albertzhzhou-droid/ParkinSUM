import '../entities/meal_composition.dart';
import '../entities/mechanistic_event_ledger.dart';
import '../entities/time_axis_events.dart';

/// Projects an already-validated production context into an immutable,
/// unit-aware audit ledger. The ledger is read-only and never creates,
/// reschedules, or recommends a medication event.
final class MechanisticEventLedgerBuilder {
  const MechanisticEventLedgerBuilder();

  MechanisticEventLedger build({
    required String ledgerId,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    required String configurationDigest,
    required DateTime createdAtUtc,
    required String sourceId,
    required String revisionId,
    required bool synthetic,
  }) {
    if (!createdAtUtc.isUtc) {
      throw ArgumentError('Ledger creation time must be UTC.');
    }
    final drafts = <_LedgerEventDraft>[];

    for (final medication in context.medicationEvents) {
      final strength = medication.context.strength;
      final unit = medication.context.unit;
      final canonical = MechanisticUnitConverter.convert(
        value: strength,
        fromUnit: unit,
        toUnit: 'mg',
        dimension: MechanisticLedgerDimension.mass,
      );
      drafts.add(
        _LedgerEventDraft(
          id: medication.id,
          kind: MechanisticLedgerEventKind.dose,
          occurredAtUtc: minuteToDateTime(medication.minute),
          sourceId: medication.context.sourceDocId,
          revisionId: revisionId,
          synthetic: synthetic,
          measurements: [
            MechanisticLedgerMeasurement(
              id: 'dose_strength',
              state: MechanisticLedgerValueState.known,
              dimension: MechanisticLedgerDimension.mass,
              origin: synthetic
                  ? MechanisticLedgerValueOrigin.syntheticFixture
                  : MechanisticLedgerValueOrigin.observedOriginal,
              originalValue: strength,
              originalUnit: unit,
              canonicalValue: canonical,
              canonicalUnit: 'mg',
            ),
          ],
          attributes: <String, String>{
            'active_ingredients': medication.context.activeIngredients.join(
              '+',
            ),
            'drug_product_variant': medication.context.drugProductVariant,
            'jurisdiction': medication.context.jurisdiction,
            'release_type': medication.context.releaseType,
          },
          formulation: medication.context.form,
          route: medication.context.route,
          compartment: 'gastrointestinal_input',
        ),
      );
    }

    for (final meal in context.mealEvents) {
      final composition = mealCompositionsById[meal.compositionId];
      if (composition == null || composition.id != meal.compositionId) {
        throw StateError('Meal composition is missing or identity-mismatched.');
      }
      drafts.add(
        _LedgerEventDraft(
          id: meal.id,
          kind: MechanisticLedgerEventKind.meal,
          occurredAtUtc: minuteToDateTime(meal.minute),
          sourceId: sourceId,
          revisionId: revisionId,
          synthetic: synthetic,
          measurements: <MechanisticLedgerMeasurement>[
            _projected(
              id: 'energy',
              value: composition.totalCalories,
              unit: 'kcal',
              dimension: MechanisticLedgerDimension.energy,
              synthetic: synthetic,
            ),
            _projected(
              id: 'protein',
              value: composition.proteinGrams,
              unit: 'g',
              canonicalUnit: 'mg',
              dimension: MechanisticLedgerDimension.mass,
              synthetic: synthetic,
            ),
            _projected(
              id: 'fat',
              value: composition.fatGrams,
              unit: 'g',
              canonicalUnit: 'mg',
              dimension: MechanisticLedgerDimension.mass,
              synthetic: synthetic,
            ),
            _projected(
              id: 'fiber',
              value: composition.fiberGrams,
              unit: 'g',
              canonicalUnit: 'mg',
              dimension: MechanisticLedgerDimension.mass,
              synthetic: synthetic,
            ),
            _projected(
              id: 'carbohydrate',
              value: composition.carbohydrateGrams,
              unit: 'g',
              canonicalUnit: 'mg',
              dimension: MechanisticLedgerDimension.mass,
              synthetic: synthetic,
            ),
            _projected(
              id: 'liquid_fraction',
              value: composition.liquidFraction,
              unit: 'fraction',
              dimension: MechanisticLedgerDimension.fraction,
              synthetic: synthetic,
            ),
            _projected(
              id: 'composition_completeness',
              value: composition.compositionCompleteness,
              unit: 'fraction',
              dimension: MechanisticLedgerDimension.fraction,
              synthetic: synthetic,
            ),
            _projected(
              id: 'meal_duration',
              value: meal.durationMinutes.toDouble(),
              unit: 'min',
              dimension: MechanisticLedgerDimension.duration,
              synthetic: synthetic,
            ),
          ],
          attributes: <String, String>{
            'composition_id': composition.id,
            'physical_form': meal.physicalForm.name,
            'component_count': '${composition.foodComponents.length}',
            if (composition.missingFields.isNotEmpty)
              'missing_fields': _sortedJoin(composition.missingFields),
          },
        ),
      );
    }

    final window = context.userDefinedWindow;
    drafts.add(
      _LedgerEventDraft(
        id: '${ledgerId}_context',
        kind: MechanisticLedgerEventKind.context,
        occurredAtUtc: minuteToDateTime(context.referenceMinute),
        sourceId: sourceId,
        revisionId: revisionId,
        synthetic: synthetic,
        measurements: [
          if (window != null)
            _projected(
              id: 'user_window_duration',
              value: window.window.durationMinutes.toDouble(),
              unit: 'min',
              dimension: MechanisticLedgerDimension.duration,
              synthetic: synthetic,
            ),
        ],
        attributes: <String, String>{
          'configuration_digest': configurationDigest,
          if (window != null) 'window_source': window.source,
          if (context.missingFields.isNotEmpty)
            'missing_fields': _sortedJoin(context.missingFields),
        },
      ),
    );

    drafts.sort((left, right) {
      final byTime = left.occurredAtUtc.compareTo(right.occurredAtUtc);
      if (byTime != 0) return byTime;
      final byKind = left.kind.index.compareTo(right.kind.index);
      return byKind != 0 ? byKind : left.id.compareTo(right.id);
    });
    final orderByTimestamp = <int, int>{};
    final events = <MechanisticLedgerEvent>[];
    for (final draft in drafts) {
      final timestamp = draft.occurredAtUtc.microsecondsSinceEpoch;
      final order = orderByTimestamp[timestamp] ?? 0;
      orderByTimestamp[timestamp] = order + 1;
      events.add(draft.build(orderAtTimestamp: order));
    }

    return MechanisticEventLedger(
      ledgerId: ledgerId,
      createdAtUtc: createdAtUtc,
      configurationDigest: configurationDigest,
      boundary:
          'Read-only replay evidence. The ledger never creates, infers, '
          'recommends, or reschedules a medication dose and is not a clinical '
          'record or calibrated pharmacokinetic dataset.',
      events: events,
    );
  }
}

String _sortedJoin(Iterable<String> values) {
  final sorted = values.toList()..sort();
  return sorted.join(',');
}

MechanisticLedgerMeasurement _projected({
  required String id,
  required double? value,
  required String unit,
  String? canonicalUnit,
  required MechanisticLedgerDimension dimension,
  required bool synthetic,
}) {
  final targetUnit = canonicalUnit ?? unit;
  if (value == null) {
    return MechanisticLedgerMeasurement(
      id: id,
      state: MechanisticLedgerValueState.unknown,
      dimension: dimension,
      origin: synthetic
          ? MechanisticLedgerValueOrigin.syntheticFixture
          : MechanisticLedgerValueOrigin.canonicalProjection,
      originalValue: null,
      originalUnit: unit,
      canonicalValue: null,
      canonicalUnit: targetUnit,
    );
  }
  return MechanisticLedgerMeasurement(
    id: id,
    state: MechanisticLedgerValueState.known,
    dimension: dimension,
    origin: synthetic
        ? MechanisticLedgerValueOrigin.syntheticFixture
        : MechanisticLedgerValueOrigin.canonicalProjection,
    originalValue: value,
    originalUnit: unit,
    canonicalValue: MechanisticUnitConverter.convert(
      value: value,
      fromUnit: unit,
      toUnit: targetUnit,
      dimension: dimension,
    ),
    canonicalUnit: targetUnit,
  );
}

final class _LedgerEventDraft {
  const _LedgerEventDraft({
    required this.id,
    required this.kind,
    required this.occurredAtUtc,
    required this.sourceId,
    required this.revisionId,
    required this.synthetic,
    required this.measurements,
    required this.attributes,
    this.formulation,
    this.route,
    this.compartment,
  });

  final String id;
  final MechanisticLedgerEventKind kind;
  final DateTime occurredAtUtc;
  final String sourceId;
  final String revisionId;
  final bool synthetic;
  final List<MechanisticLedgerMeasurement> measurements;
  final Map<String, String> attributes;
  final String? formulation;
  final String? route;
  final String? compartment;

  MechanisticLedgerEvent build({required int orderAtTimestamp}) =>
      MechanisticLedgerEvent(
        id: id,
        kind: kind,
        originalTimestamp: occurredAtUtc.toIso8601String(),
        occurredAtUtc: occurredAtUtc,
        timezoneOffsetMinutes: 0,
        orderAtTimestamp: orderAtTimestamp,
        sourceId: sourceId,
        revisionId: revisionId,
        synthetic: synthetic,
        measurements: measurements,
        attributes: attributes,
        formulation: formulation,
        route: route,
        compartment: compartment,
      );
}
