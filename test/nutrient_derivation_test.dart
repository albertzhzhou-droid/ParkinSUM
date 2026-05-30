import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/nutrient_derivation.dart';

/// Unit tests for the FDC nutrient-provenance → confidence-tier mapping
/// (OPP-B1 / spike). The tier is an ordinal *provenance* signal only — not a
/// measurement-uncertainty or clinical-accuracy estimate. Conservative:
/// unknown/missing never raises confidence; weakest-wins aggregate.
void main() {
  test('analytical derivation codes/descriptions map to analytical tier', () {
    expect(const NutrientDerivation(derivationCode: 'A').tier,
        NutrientConfidenceTier.analytical);
    expect(
        const NutrientDerivation(
                derivationDescription: 'Analytical, directly measured')
            .tier,
        NutrientConfidenceTier.analytical);
  });

  test('calculated derivations map to calculated tier', () {
    expect(const NutrientDerivation(derivationCode: 'NC').tier,
        NutrientConfidenceTier.calculated);
    expect(
        const NutrientDerivation(
                derivationDescription: 'Calculated from recipe')
            .tier,
        NutrientConfidenceTier.calculated);
  });

  test('imputed/assumed derivations map to imputedOrAssumed tier', () {
    expect(
        const NutrientDerivation(
                derivationDescription: 'Imputed from a similar food')
            .tier,
        NutrientConfidenceTier.imputedOrAssumed);
  });

  test('missing/unrecognized derivation maps to unknown tier', () {
    expect(const NutrientDerivation().tier, NutrientConfidenceTier.unknown);
    expect(const NutrientDerivation(derivationCode: 'ZZZ').tier,
        NutrientConfidenceTier.unknown);
  });

  test('a missing dataPoints does not raise the tier', () {
    // No sample count + no derivation code → still unknown (never analytical).
    expect(const NutrientDerivation(dataPoints: null).tier,
        NutrientConfidenceTier.unknown);
  });

  test('weakest-wins aggregate over a set', () {
    final tier = weakestConfidenceTier(const [
      NutrientDerivation(derivationCode: 'A'), // analytical
      NutrientDerivation(derivationDescription: 'imputed'), // imputedOrAssumed
    ]);
    expect(tier, NutrientConfidenceTier.imputedOrAssumed);
    expect(weakestConfidenceTier(const []), isNull); // empty → null
  });

  test('tierWidensUncertainty: only analytical does NOT widen', () {
    expect(tierWidensUncertainty(NutrientConfidenceTier.analytical), isFalse);
    expect(tierWidensUncertainty(NutrientConfidenceTier.calculated), isTrue);
    expect(
        tierWidensUncertainty(NutrientConfidenceTier.imputedOrAssumed), isTrue);
    expect(tierWidensUncertainty(NutrientConfidenceTier.unknown), isTrue);
  });

  test('toJson/fromJson round-trip preserves fields + tier', () {
    const d = NutrientDerivation(
      derivationCode: 'A',
      derivationDescription: 'Analytical',
      sourceCode: 'src1',
      dataPoints: 12,
      min: 1.0,
      max: 3.0,
      median: 2.0,
    );
    final restored = NutrientDerivation.fromJson(d.toJson());
    expect(restored.derivationCode, 'A');
    expect(restored.dataPoints, 12);
    expect(restored.tier, NutrientConfidenceTier.analytical);
    expect(d.toJson()['tier'], 'analytical');
  });
}
