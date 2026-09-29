import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_candidate_projection_invariant_probe.dart';

void main() {
  test('production projection probe is deterministic and finite', () {
    final first = CatalogCandidateProjectionInvariantProbe.capture();
    final second = CatalogCandidateProjectionInvariantProbe.capture();

    expect(first.observations, second.observations);
    expect(first.observations['probe.version'], 1);
    expect(first.observations['probe.invocation_count'], 14);
    expect(first.observations['catalog.missing.energy_null'], isTrue);
    expect(first.observations['catalog.zero.energy_kcal'], 0);
    expect(first.observations['portion.half.leucine_g'], 1);
    expect(first.observations['portion.zero.leucine_g'], 0);
    expect(first.observations['catalog.meal_missing.energy_null'], isTrue);
    expect(first.observations['basis.per_serving.held'], isTrue);
    expect(first.observations['unit.unknown.held'], isTrue);
    expect(first.observations['portion.nan.held'], isTrue);
    expect(first.observations['source.nan.held'], isTrue);
    expect(first.observations['source.infinity.held'], isTrue);
    expect(jsonEncode(first.observations), isNot(contains('NaN')));
    expect(jsonEncode(first.observations), isNot(contains('Infinity')));
  });

  test('mutation helpers do not alter the captured baseline', () {
    final baseline = CatalogCandidateProjectionInvariantProbe.capture();
    final changed = baseline.withObservation('portion.half.leucine_g', 2);
    final missing = baseline.withoutObservation('portion.half.leucine_g');

    expect(baseline.observations['portion.half.leucine_g'], 1);
    expect(changed.observations['portion.half.leucine_g'], 2);
    expect(missing.observations, isNot(contains('portion.half.leucine_g')));
  });
}
