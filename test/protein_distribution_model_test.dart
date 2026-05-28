import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/protein_distribution.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/protein_distribution_model.dart';

void main() {
  final model = ProteinDistributionModel();

  test('missing medication context → unknown role, optimization off', () {
    final s = model.evaluate(const ProteinDistributionContext(
      modeledOverlap: 0.0,
      localHourHint: 20,
      medicationContextValid: false,
      candidateProteinGrams: 25,
    ));
    expect(s.windowRole, ProteinWindowRole.unknownWindowRole);
    expect(s.optimizationActive, isFalse);
  });

  test('high overlap → sensitive window, protein penalized', () {
    final s = model.evaluate(const ProteinDistributionContext(
      modeledOverlap: 0.4,
      localHourHint: 8,
      medicationContextValid: true,
      candidateProteinGrams: 25,
    ));
    expect(s.windowRole, ProteinWindowRole.sensitiveLevodopaOverlapWindow);
    expect(s.overlapProteinPenalty, greaterThan(0.0));
  });

  test('low overlap in the evening → redistribution candidate', () {
    final s = model.evaluate(const ProteinDistributionContext(
      modeledOverlap: 0.02,
      localHourHint: 20,
      medicationContextValid: true,
      candidateProteinGrams: 25,
    ));
    expect(
        s.windowRole, ProteinWindowRole.eveningRedistributionCandidateWindow);
    expect(s.redistributionScore, greaterThan(0.4));
  });

  test(
      'NOT global minimization: protein in low-overlap window scores higher '
      'than the same protein in a high-overlap window', () {
    final lowOverlap = model.evaluate(const ProteinDistributionContext(
      modeledOverlap: 0.02,
      localHourHint: 20,
      medicationContextValid: true,
      candidateProteinGrams: 25,
    ));
    final highOverlap = model.evaluate(const ProteinDistributionContext(
      modeledOverlap: 0.4,
      localHourHint: 8,
      medicationContextValid: true,
      candidateProteinGrams: 25,
    ));
    expect(lowOverlap.redistributionScore,
        greaterThan(highOverlap.redistributionScore));
  });

  test('evening clock with ACTIVE overlap is NOT auto-redistribution', () {
    final s = model.evaluate(const ProteinDistributionContext(
      modeledOverlap: 0.4, // active overlap despite evening hour
      localHourHint: 20,
      medicationContextValid: true,
      candidateProteinGrams: 25,
    ));
    expect(s.windowRole, ProteinWindowRole.sensitiveLevodopaOverlapWindow);
  });

  test(
      'zero-protein does not automatically win: adequacy contribution is '
      'higher for a protein-containing meal in a low-overlap window', () {
    final zero = model.evaluate(const ProteinDistributionContext(
      modeledOverlap: 0.02,
      localHourHint: 20,
      medicationContextValid: true,
      candidateProteinGrams: 0,
    ));
    final moderate = model.evaluate(const ProteinDistributionContext(
      modeledOverlap: 0.02,
      localHourHint: 20,
      medicationContextValid: true,
      candidateProteinGrams: 15,
    ));
    expect(moderate.adequacy.contribution,
        greaterThan(zero.adequacy.contribution));
    expect(moderate.redistributionScore, greaterThan(zero.redistributionScore));
  });

  test('trace + assumptions contain no banned advice phrases', () {
    final s = model.evaluate(const ProteinDistributionContext(
      modeledOverlap: 0.4,
      localHourHint: 8,
      medicationContextValid: true,
      candidateProteinGrams: 25,
    ));
    final trace = model.toTrace(s);
    final blob = [
      trace.objectiveDescription,
      ...s.assumptions,
    ].join(' ');
    expect(findBannedSubstrings(blob), isEmpty);
  });
}
