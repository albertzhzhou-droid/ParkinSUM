import '../entities/personal_observation.dart';

/// A bounded chronological projection of account-entered symptom and motor
/// state records. It preserves explicit missingness and makes no inference.
final class SymptomMotorObservationProjection {
  static const int maximumVisibleObservations = 12;

  final List<PersonalObservation> observations;
  final int omittedObservationCount;

  const SymptomMotorObservationProjection._({
    required this.observations,
    required this.omittedObservationCount,
  });

  factory SymptomMotorObservationProjection.fromObservations(
    Iterable<PersonalObservation> source,
  ) {
    final ordered =
        source
            .where(
              (item) =>
                  item.kind == PersonalObservationKind.symptom ||
                  item.kind == PersonalObservationKind.selfReportedMotorState,
            )
            .toList()
          ..sort((a, b) {
            final occurred = a.occurredAt.compareTo(b.occurredAt);
            if (occurred != 0) return occurred;
            final recorded = a.recordedAt.compareTo(b.recordedAt);
            return recorded == 0 ? a.id.compareTo(b.id) : recorded;
          });
    final omitted = ordered.length > maximumVisibleObservations
        ? ordered.length - maximumVisibleObservations
        : 0;
    return SymptomMotorObservationProjection._(
      observations: List<PersonalObservation>.unmodifiable(
        ordered.skip(omitted),
      ),
      omittedObservationCount: omitted,
    );
  }

  int get recordedCount => observations
      .where((item) => item.status == PersonalObservationStatus.recorded)
      .length;

  int get unknownCount => observations
      .where((item) => item.status == PersonalObservationStatus.unknown)
      .length;

  int get notMeasuredCount => observations
      .where((item) => item.status == PersonalObservationStatus.notMeasured)
      .length;
}
