import 'dart:collection';
import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../entities/meal_composition.dart';
import '../entities/mechanistic_event_ledger.dart';
import '../entities/time_axis_events.dart';

const String mechanisticLedgerAuthorizationSchema =
    'parkinsum.mechanistic-ledger-authorization/1';
const int mechanisticLedgerAuthorizationSchemaVersion = 1;

enum MechanisticLedgerAuthorizationStatus { authorized, blockedIntegrity }

final class MechanisticLedgerAuthorizationAssessment {
  MechanisticLedgerAuthorizationAssessment({
    required this.ledger,
    required this.expectedConfigurationSha256,
    required this.recomputedInputBindingSha256,
    required this.inputMedicationEventCount,
    required this.inputMealEventCount,
    required this.inputFoodComponentEventCount,
    required this.boundCompositionCount,
    required List<String> findings,
  }) : findings = List<String>.unmodifiable(findings);

  final MechanisticEventLedger ledger;
  final String expectedConfigurationSha256;
  final String recomputedInputBindingSha256;
  final int inputMedicationEventCount;
  final int inputMealEventCount;
  final int inputFoodComponentEventCount;
  final int boundCompositionCount;
  final List<String> findings;

  MechanisticLedgerAuthorizationStatus get status => findings.isEmpty
      ? MechanisticLedgerAuthorizationStatus.authorized
      : MechanisticLedgerAuthorizationStatus.blockedIntegrity;

  bool get authorized =>
      status == MechanisticLedgerAuthorizationStatus.authorized;

  Map<String, Object?> _bodyJson() => <String, Object?>{
    'schema': mechanisticLedgerAuthorizationSchema,
    'schema_version': mechanisticLedgerAuthorizationSchemaVersion,
    'status': status.name,
    'authorized': authorized,
    'ledger_schema': mechanisticEventLedgerSchema,
    'ledger_schema_version': mechanisticEventLedgerSchemaVersion,
    'ledger_sha256': ledger.sha256Digest,
    'canonical_replay_sha256': ledger.canonicalReplayDigest,
    'expected_configuration_sha256': expectedConfigurationSha256,
    'ledger_configuration_sha256': ledger.configurationDigest,
    'ledger_input_binding_sha256': ledger.inputBindingSha256,
    'recomputed_input_binding_sha256': recomputedInputBindingSha256,
    'input_medication_event_count': inputMedicationEventCount,
    'input_meal_event_count': inputMealEventCount,
    'input_food_component_event_count': inputFoodComponentEventCount,
    'readable_ledger_event_count': ledger.events.length,
    'bound_composition_count': boundCompositionCount,
    'opaque_but_digest_bound_fields': const <String>[
      'medication_extended_metadata',
      'meal_food_components',
      'food_component_timeline_events',
    ],
    'findings': findings,
    'boundary':
        'Authorization proves that the exact engine-facing input was bound to '
        'this immutable ledger and configuration before evaluation. The '
        'readable projection is not yet a lossless replay schema. Passing does '
        'not establish biological truth, clinical calibration, benefit, '
        'safety, regulatory qualification, or medical advice.',
  };

  late final String reportSha256 = sha256
      .convert(utf8.encode(_canonicalJson(_bodyJson())))
      .toString();

  Map<String, Object?> toJson() => <String, Object?>{
    ..._bodyJson(),
    'report_sha256': reportSha256,
  };
}

/// An exact, short-lived authorization lease over the same immutable objects
/// that were content-bound into [ledger]. Every getter rechecks the binding so
/// mutable caller-owned nested lists cannot be changed after authorization and
/// silently reach the engine.
final class MechanisticLedgerAuthorizedView {
  MechanisticLedgerAuthorizedView._({
    required this.ledger,
    required this.assessment,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
  }) : _context = context,
       _mealCompositionsById = Map<String, MealComposition>.unmodifiable(
         mealCompositionsById,
       );

  final MechanisticEventLedger ledger;
  final MechanisticLedgerAuthorizationAssessment assessment;
  final TimeAxisConflictContext _context;
  final Map<String, MealComposition> _mealCompositionsById;

  void _assertBindingCurrent() {
    final current = MechanisticLedgerInputBinding.compute(
      context: _context,
      mealCompositionsById: _mealCompositionsById,
    );
    if (current != ledger.inputBindingSha256 ||
        current != assessment.recomputedInputBindingSha256) {
      throw StateError(
        'Mechanistic ledger authorization expired after input drift.',
      );
    }
  }

  TimeAxisConflictContext get context {
    _assertBindingCurrent();
    return _context;
  }

  Map<String, MealComposition> get mealCompositionsById {
    _assertBindingCurrent();
    return UnmodifiableMapView<String, MealComposition>(_mealCompositionsById);
  }
}

final class MechanisticLedgerAuthorizationDecision {
  const MechanisticLedgerAuthorizationDecision({
    required this.assessment,
    required this.view,
  });

  final MechanisticLedgerAuthorizationAssessment assessment;
  final MechanisticLedgerAuthorizedView? view;

  bool get authorized => assessment.authorized && view != null;
}

abstract interface class MechanisticLedgerAuthorizer {
  MechanisticLedgerAuthorizationDecision authorize({
    required MechanisticEventLedger ledger,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    required String expectedConfigurationSha256,
  });
}

final class MechanisticEventLedgerAuthorizationService
    implements MechanisticLedgerAuthorizer {
  const MechanisticEventLedgerAuthorizationService();

  @override
  MechanisticLedgerAuthorizationDecision authorize({
    required MechanisticEventLedger ledger,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    required String expectedConfigurationSha256,
  }) {
    final findings = <String>[];
    final recomputedBinding = MechanisticLedgerInputBinding.compute(
      context: context,
      mealCompositionsById: mealCompositionsById,
    );

    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(expectedConfigurationSha256)) {
      findings.add('authorization.expected_configuration_identity_invalid');
    }
    if (ledger.configurationDigest != expectedConfigurationSha256) {
      findings.add('authorization.configuration_identity_mismatch');
    }
    if (ledger.inputBindingSha256 != recomputedBinding) {
      findings.add('authorization.input_binding_mismatch');
    }

    for (final entry in mealCompositionsById.entries) {
      if (entry.key != entry.value.id) {
        findings.add(
          'authorization.composition_map_identity_mismatch:${entry.key}',
        );
      }
    }
    for (final event in context.mealEvents) {
      if (!mealCompositionsById.containsKey(event.compositionId)) {
        findings.add('authorization.meal_composition_missing:${event.id}');
      }
    }

    final expectedMedicationIds = context.medicationEvents
        .map((event) => event.id)
        .toSet();
    final projectedMedicationIds = ledger.events
        .where((event) => event.kind == MechanisticLedgerEventKind.dose)
        .map((event) => event.id)
        .toSet();
    if (!_sameStrings(expectedMedicationIds, projectedMedicationIds)) {
      findings.add('authorization.medication_event_projection_mismatch');
    }
    final expectedMealIds = context.mealEvents.map((event) => event.id).toSet();
    final projectedMealIds = ledger.events
        .where((event) => event.kind == MechanisticLedgerEventKind.meal)
        .map((event) => event.id)
        .toSet();
    if (!_sameStrings(expectedMealIds, projectedMealIds)) {
      findings.add('authorization.meal_event_projection_mismatch');
    }

    final contextEvents = ledger.events
        .where((event) => event.kind == MechanisticLedgerEventKind.context)
        .toList(growable: false);
    if (contextEvents.length != 1) {
      findings.add('authorization.context_event_cardinality_invalid');
    } else {
      final attributes = contextEvents.single.attributes;
      if (attributes['configuration_digest'] != expectedConfigurationSha256) {
        findings.add('authorization.context_configuration_mismatch');
      }
      if (attributes['reference_minute'] != '${context.referenceMinute}') {
        findings.add('authorization.reference_minute_mismatch');
      }
      final window = context.userDefinedWindow;
      if (window == null) {
        if (attributes.containsKey('window_start_minute') ||
            attributes.containsKey('window_end_minute') ||
            attributes.containsKey('window_source')) {
          findings.add('authorization.unexpected_window_projection');
        }
      } else if (attributes['window_start_minute'] !=
              '${window.window.startMinute}' ||
          attributes['window_end_minute'] != '${window.window.endMinute}' ||
          attributes['window_source'] != window.source) {
        findings.add('authorization.window_projection_mismatch');
      }
      if (attributes['food_component_event_count'] !=
          '${context.foodComponentEvents.length}') {
        findings.add('authorization.food_component_count_mismatch');
      }
    }

    try {
      final roundTrip = MechanisticEventLedger.fromJson(
        jsonDecode(jsonEncode(ledger.toJson())).cast<String, Object?>(),
      );
      if (roundTrip.sha256Digest != ledger.sha256Digest ||
          roundTrip.canonicalReplayDigest != ledger.canonicalReplayDigest) {
        findings.add('authorization.ledger_roundtrip_identity_mismatch');
      }
    } on Object {
      findings.add('authorization.ledger_roundtrip_invalid');
    }

    final uniqueFindings = findings.toSet().toList()..sort();
    final assessment = MechanisticLedgerAuthorizationAssessment(
      ledger: ledger,
      expectedConfigurationSha256: expectedConfigurationSha256,
      recomputedInputBindingSha256: recomputedBinding,
      inputMedicationEventCount: context.medicationEvents.length,
      inputMealEventCount: context.mealEvents.length,
      inputFoodComponentEventCount: context.foodComponentEvents.length,
      boundCompositionCount: mealCompositionsById.length,
      findings: uniqueFindings,
    );
    return MechanisticLedgerAuthorizationDecision(
      assessment: assessment,
      view: assessment.authorized
          ? MechanisticLedgerAuthorizedView._(
              ledger: ledger,
              assessment: assessment,
              context: context,
              mealCompositionsById: mealCompositionsById,
            )
          : null,
    );
  }
}

bool _sameStrings(Set<String> left, Set<String> right) =>
    left.length == right.length && left.containsAll(right);

String _canonicalJson(Object? value) {
  Object? canonicalize(Object? node) {
    if (node is Map) {
      final keys = node.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: canonicalize(node[key]),
      };
    }
    if (node is List) return node.map(canonicalize).toList(growable: false);
    if (node is Set) {
      final values = node.map(canonicalize).toList(growable: false)
        ..sort((left, right) => jsonEncode(left).compareTo(jsonEncode(right)));
      return values;
    }
    return node;
  }

  return jsonEncode(canonicalize(value));
}
