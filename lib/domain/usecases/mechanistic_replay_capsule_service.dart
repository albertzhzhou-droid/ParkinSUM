import 'dart:convert';

import '../entities/meal_composition.dart';
import '../entities/mechanistic_event_ledger.dart';
import '../entities/mechanistic_replay_capsule.dart';
import '../entities/time_axis_events.dart';

abstract interface class MechanisticReplayCapsuleRoundTripper {
  MechanisticReplayRoundTrip captureAndRestore({
    required String capsuleId,
    required DateTime generatedAtUtc,
    required MechanisticEventLedger ledger,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    required String expectedConfigurationSha256,
  });
}

final class MechanisticReplayRoundTrip {
  const MechanisticReplayRoundTrip({
    required this.capsule,
    required this.restored,
  });

  final MechanisticReplayCapsule capsule;
  final MechanisticReplayRestoredInput restored;
}

/// Forces the production input through the serialized capsule boundary before
/// numerical evaluation. Any serialization, digest, schema, reconstruction or
/// configuration failure throws and is converted by the caller into its typed
/// fail-closed integrity result.
final class MechanisticReplayCapsuleService
    implements MechanisticReplayCapsuleRoundTripper {
  const MechanisticReplayCapsuleService();

  @override
  MechanisticReplayRoundTrip captureAndRestore({
    required String capsuleId,
    required DateTime generatedAtUtc,
    required MechanisticEventLedger ledger,
    required TimeAxisConflictContext context,
    required Map<String, MealComposition> mealCompositionsById,
    required String expectedConfigurationSha256,
  }) {
    final captured = MechanisticReplayCapsule.capture(
      capsuleId: capsuleId,
      generatedAtUtc: generatedAtUtc,
      ledger: ledger,
      context: context,
      mealCompositionsById: mealCompositionsById,
    );
    final parsed = MechanisticReplayCapsule.fromJson(
      (jsonDecode(captured.canonicalJson) as Map<String, dynamic>)
          .cast<String, Object?>(),
    );
    final restored = parsed.restore(
      expectedConfigurationSha256: expectedConfigurationSha256,
    );
    return MechanisticReplayRoundTrip(capsule: parsed, restored: restored);
  }
}
