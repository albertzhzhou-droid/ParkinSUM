import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/entities/catalog_resolution.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_resolution_engine.dart';
import 'package:parkinsum_companion/domain/usecases/medication_entry_validator.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P2 — CatalogResolutionEngine. Deterministic resolution over small synthetic
/// catalogs. NOT a recommendation engine; no advice, no dose inference, no
/// silent guessing. No PHI / patient / subject / encounter semantics.
void main() {
  const engine = CatalogResolutionEngine();

  FoodItem food(
    String id,
    String name, {
    List<String> aliases = const [],
    FoodCategory category = FoodCategory.beverage,
    String sourceSystem = 'CIQUAL',
    String? sourceFoodCode = 'F-CODE',
    String jurisdiction = 'GLOBAL',
    String? basisType = 'per_100g',
  }) =>
      FoodItem(
        id: id,
        name: name,
        category: category,
        aliases: aliases,
        sourceSystem: sourceSystem,
        sourceFoodCode: sourceFoodCode,
        jurisdiction: jurisdiction,
        basisType: basisType,
        proteinG: 1,
        carbsG: 10,
        fatG: 1,
        fiberG: 0,
        sodiumMg: 5,
      );

  DrugDefinition drug(
    String id,
    String generic, {
    List<String> brands = const [],
    List<String> aliases = const [],
    String releaseType = 'immediate',
    String? code = 'SPL-CODE',
    String jurisdiction = 'US',
    String sourceSystem = 'DAILYMED',
  }) =>
      DrugDefinition(
        id: id,
        genericName: generic,
        brandNames: brands,
        aliases: aliases,
        tags: const [DrugTag.levodopaLike],
        notes: '',
        sourceSystem: sourceSystem,
        sourceProductCode: code,
        jurisdiction: jurisdiction,
        route: 'oral',
        dosageForm: 'tablet',
        releaseType: releaseType,
      );

  // Standard synthetic catalogs.
  final milkTea =
      food('f-milktea', 'Milk Tea', aliases: const ['bubble tea', '奶茶']);
  final greenTea = food('f-green', 'Green Tea');
  final blackTea = food('f-black', 'Black Tea');
  final proteinShake =
      food('f-shake', 'Protein Shake', category: FoodCategory.protein);
  final foods = [milkTea, greenTea, blackTea, proteinShake];

  final levodopaMono = drug('d-ldopa', 'levodopa', code: 'SPL-001');
  final sinemetIR = drug('d-sinemet-ir', 'carbidopa/levodopa',
      brands: const ['Sinemet'], releaseType: 'immediate', code: 'SPL-002');
  final sinemetCR = drug('d-sinemet-cr', 'carbidopa/levodopa',
      brands: const ['Sinemet CR'], releaseType: 'controlled', code: 'SPL-003');
  final drugs = [levodopaMono, sinemetIR, sinemetCR];

  CatalogResolutionResult resolve(String q,
          {List<FoodItem>? f,
          List<DrugDefinition>? d,
          String jurisdiction = '',
          String locale = ''}) =>
      engine.resolve(
        query: q,
        foods: f ?? foods,
        drugs: d ?? drugs,
        jurisdiction: jurisdiction,
        locale: locale,
      );

  // 1 — exact food name → high confidence.
  test('exact food name resolves with high confidence', () {
    final r = resolve('milk tea', d: const []);
    expect(r.status, CatalogResolutionStatus.resolved);
    expect(r.bestCandidate!.matchType, CatalogResolutionMatchType.exactName);
    expect(
        r.bestCandidate!.confidenceBand, CatalogResolutionConfidenceBand.high);
    expect(r.domain, CatalogResolutionDomain.food);
  });

  // 2 — localized food name resolves, no advice.
  test('localized food name resolves without advice', () {
    final r = resolve('奶茶', d: const []);
    expect(r.bestCandidate!.foodItemId, 'f-milktea');
    expect(
        r.bestCandidate!.matchType, CatalogResolutionMatchType.localizedName);
    final json = encodeCatalogResolution(r).toLowerCase();
    expect(json.contains('eat this'), isFalse);
    expect(json.contains('recommended'), isFalse);
  });

  // 3 — synonym food name resolves as a synonym match.
  test('synonym food name resolves as synonym match', () {
    final r = resolve('bubble tea', d: const []);
    expect(r.bestCandidate!.foodItemId, 'f-milktea');
    expect(r.bestCandidate!.matchType, CatalogResolutionMatchType.synonym);
  });

  // 4 — ambiguous food query → ambiguous (not overconfident resolved).
  test('ambiguous food query is ambiguous, not resolved', () {
    final r = resolve('tea', d: const []);
    expect(r.status, CatalogResolutionStatus.ambiguous);
    expect(r.candidates.length, greaterThanOrEqualTo(2));
  });

  // 5 — unknown food → unresolved with reasons.
  test('unknown food is unresolved with reasons', () {
    final r = resolve('dragonfruit_xyz_unknownthing', d: const []);
    expect(r.status, CatalogResolutionStatus.unresolved);
    expect(r.issues.any((i) => i.issueType == 'no_catalog_match'), isTrue);
  });

  // 6 — exact drug name → high confidence.
  test('exact drug name resolves with high confidence', () {
    final r = resolve('levodopa', f: const []);
    expect(r.status, CatalogResolutionStatus.resolved);
    expect(r.bestCandidate!.drugProductId, 'd-ldopa');
    expect(r.bestCandidate!.matchType, CatalogResolutionMatchType.exactName);
    expect(
        r.bestCandidate!.confidenceBand, CatalogResolutionConfidenceBand.high);
  });

  // 7 — brand drug name → source-backed product candidate.
  test('brand drug name resolves to source-backed candidate', () {
    final r = resolve('Sinemet', f: const []);
    expect(r.bestCandidate!.matchType, CatalogResolutionMatchType.brandName);
    expect(r.bestCandidate!.drugProductId, 'd-sinemet-ir');
    expect(r.bestCandidate!.sourceRefs, isNotEmpty);
  });

  // 8 — generic active ingredient with non-specific variant → partial/ambiguous.
  test('generic ingredient with non-specific variants is partial/ambiguous',
      () {
    final r = resolve('levodopa', f: const [], d: [sinemetIR, sinemetCR]);
    expect(
        [CatalogResolutionStatus.partial, CatalogResolutionStatus.ambiguous]
            .contains(r.status),
        isTrue);
  });

  // 9 — combination product query preserves components.
  test('combination product query preserves components', () {
    final r = resolve('carbidopa levodopa 25/100', f: const []);
    expect(r.bestCandidate!.matchType,
        CatalogResolutionMatchType.combinationProduct);
    expect(r.bestCandidate!.combinationComponents,
        containsAll(<String>['carbidopa', 'levodopa']));
  });

  // 10 — release type hint distinguishes IR vs CR candidate.
  test('release type hint distinguishes IR vs CR', () {
    final r = resolve('levodopa cr', f: const [], d: [sinemetIR, sinemetCR]);
    final cr =
        r.candidates.firstWhere((c) => c.drugProductId == 'd-sinemet-cr');
    final ir =
        r.candidates.firstWhere((c) => c.drugProductId == 'd-sinemet-ir');
    expect(cr.confidence, greaterThan(ir.confidence));
    expect(cr.releaseTypeSource, contains('match'));
  });

  // 11 — dose-like 25/100 preserved as evidence, not converted to a user dose.
  test('dose-like string preserved as evidence, not a user dose', () {
    final r = resolve('carbidopa levodopa 25/100', f: const []);
    expect(r.normalizedQuery.contains('25/100'), isTrue);
    expect(r.bestCandidate!.strengths, isEmpty);
  });

  // 12 — jurisdiction mismatch lowers confidence.
  test('jurisdiction mismatch lowers confidence', () {
    final base = resolve('levodopa', f: const []);
    final jp = resolve('levodopa', f: const [], jurisdiction: 'JP');
    final baseConf = base.candidates
        .firstWhere((c) => c.drugProductId == 'd-ldopa')
        .confidence;
    final jpCand =
        jp.candidates.firstWhere((c) => c.drugProductId == 'd-ldopa');
    expect(jpCand.confidence, lessThan(baseConf));
    expect(jpCand.ambiguityWarnings.contains('jurisdiction_mismatch'), isTrue);
  });

  // 13 — missing sourceRefs lowers confidence.
  test('missing sourceRefs lowers confidence', () {
    final withSrc = resolve('levodopa', f: const [], d: [levodopaMono]);
    final noSrc = resolve('levodopa',
        f: const [], d: [drug('d-nosrc', 'levodopa', code: null)]);
    final a = withSrc.bestCandidate!.confidence;
    final b = noSrc.bestCandidate!;
    expect(b.confidence, lessThan(a));
    expect(b.unresolvedReasons.contains('missing_source_refs'), isTrue);
  });

  // 14 — fuzzy token-only match does not become high confidence.
  test('fuzzy token-only match is not high confidence', () {
    final r = resolve('tea matcha latte', d: const []);
    if (r.bestCandidate != null) {
      expect(r.bestCandidate!.confidenceBand,
          isNot(CatalogResolutionConfidenceBand.high));
    }
  });

  // 15 — multiple close candidates → ambiguous.
  test('multiple close candidates produce ambiguous status', () {
    final r =
        resolve('carbidopa levodopa', f: const [], d: [sinemetIR, sinemetCR]);
    expect(r.status, CatalogResolutionStatus.ambiguous);
  });

  // 16 — result JSON deterministic.
  test('result JSON is deterministic', () {
    final a = encodeCatalogResolution(resolve('milk tea'));
    final b = encodeCatalogResolution(resolve('milk tea'));
    expect(a, equals(b));
    final decoded = jsonDecode(a) as Map<String, dynamic>;
    expect(decoded['report_type'], 'catalog_resolution');
    expect(decoded['no_dose_inference'], isTrue);
    expect(decoded['not_clinically_calibrated'], isTrue);
  });

  // 17 — no advice phrases emitted.
  test('no advice phrases emitted', () {
    final banned = RegExp(
        r'choose this food|eat this|take this medication|switch to this '
        r'medication|use this dose|recommended dose|recommended timing|'
        r'adjust your dose|safe for you|confirmed safe|clinically validated',
        caseSensitive: false);
    for (final q in [
      'milk tea',
      '奶茶',
      'levodopa',
      'Sinemet',
      'carbidopa levodopa 25/100',
      'levodopa cr',
      'unknown_xyz'
    ]) {
      expect(banned.hasMatch(encodeCatalogResolution(resolve(q))), isFalse,
          reason: 'advice phrase leaked for "$q"');
    }
  });

  // 18 — no PHI / patient / subject / encounter keys emitted.
  test('no PHI/patient/subject/encounter keys emitted', () {
    final decoded = jsonDecode(
            encodeCatalogResolution(resolve('carbidopa levodopa 25/100')))
        as Map<String, dynamic>;
    scanNoPhiKeys(decoded);
  });

  // 19 — candidate sourceRefs preserved.
  test('candidate sourceRefs preserved from catalog', () {
    final r = resolve('levodopa', f: const [], d: [levodopaMono]);
    expect(r.bestCandidate!.sourceRefs, contains('DAILYMED:SPL-001'));
  });

  // 20 — empty query → invalid.
  test('empty query is invalid', () {
    final r = resolve('   ');
    expect(r.status, CatalogResolutionStatus.invalid);
    expect(r.bestCandidate, isNull);
  });

  // 21 — mixed food/drug query handled safely.
  test('mixed food/drug query is mixed/ambiguous', () {
    final weird = drug('d-weird', 'placeholder generic',
        aliases: const ['protein shake'], code: 'SPL-W');
    final r = resolve('protein shake', d: [weird]);
    expect(r.domain, CatalogResolutionDomain.mixed);
    expect(r.status, CatalogResolutionStatus.ambiguous);
  });

  // 22 — locale mismatch does not fabricate a translation.
  test('locale mismatch does not fabricate translation', () {
    // Catalog has NO zh alias for the item; a zh query must not be invented.
    final noZh = [food('f-plain', 'Milk Tea')];
    final r = resolve('奶茶', f: noZh, d: const [], locale: 'fr');
    expect(r.status, CatalogResolutionStatus.unresolved);
  });

  // 23 — synthetic seed source is not treated as official.
  test('synthetic seed source is not treated as official', () {
    final seed = food('f-seed', 'Seed Snack',
        sourceSystem: 'LOCAL_SEED', sourceFoodCode: 'S-1');
    final official = food('f-off', 'Official Snack',
        sourceSystem: 'USDA_FDC', sourceFoodCode: 'U-1');
    final seedR = resolve('seed snack', f: [seed], d: const []);
    final offR = resolve('official snack', f: [official], d: const []);
    final seedAuth = seedR.bestCandidate!.sourceAuthorityScore!;
    final offAuth = offR.bestCandidate!.sourceAuthorityScore!;
    expect(seedAuth, lessThan(offAuth));
    expect(seedAuth, lessThan(0.5));
  });

  // 24 — resolved candidate → existing validator, no hidden dose created.
  test('resolved candidate passes to validator without hidden dose', () {
    final r = resolve('Sinemet', f: const []);
    final c = r.bestCandidate!;
    expect(c.strengths, isEmpty);
    // Build a medication entry from the resolved candidate WITHOUT a dose;
    // resolution never invents a strength, so the validator must mark it
    // insufficient rather than fabricate a dose.
    final entry = RawMedicationEntry(
      activeIngredient: c.activeIngredients.isNotEmpty
          ? c.activeIngredients.first
          : 'levodopa',
      drugProductVariant: c.displayName,
      form: c.doseForm,
      route: c.route,
      releaseType: c.releaseType,
      jurisdiction: 'US',
      sourceDocId: c.sourceRefs.isNotEmpty ? c.sourceRefs.first : null,
      // strength + unit intentionally omitted (no dose inferred).
    );
    final validation = MedicationEntryValidator().validate(entry);
    expect(validation.eligibleForRuleEvaluation, isFalse);
    expect(validation.issues.any((i) => i.code == 'MISSING_STRENGTH'), isTrue);
  });
}
