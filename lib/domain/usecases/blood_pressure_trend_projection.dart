import '../entities/personal_observation.dart';

/// A bounded, chronological view of explicitly recorded blood-pressure
/// observations. It does not interpolate missing values or derive a judgment.
final class BloodPressureTrendProjection {
  static const int maximumVisibleObservations = 12;

  final List<PersonalObservation> observations;
  final int omittedObservationCount;

  const BloodPressureTrendProjection._({
    required this.observations,
    required this.omittedObservationCount,
  });

  factory BloodPressureTrendProjection.fromObservations(
    Iterable<PersonalObservation> source,
  ) {
    final ordered =
        source
            .where((item) => item.kind == PersonalObservationKind.bloodPressure)
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
    return BloodPressureTrendProjection._(
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

  List<PersonalObservation> get recordedObservations =>
      List<PersonalObservation>.unmodifiable(
        observations.where(
          (item) => item.status == PersonalObservationStatus.recorded,
        ),
      );
}
