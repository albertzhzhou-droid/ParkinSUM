// Runs the CatalogResolutionEngine over fixed SYNTHETIC queries against a small
// synthetic catalog and writes a report under build/catalog_resolution/.
//
// Usage:
//   dart run tool/run_catalog_resolution_demo.dart
//
// Educational/research prototype. Catalog resolution returns candidates +
// uncertainty. It is NOT a recommendation engine, infers no user dose, and does
// not silently guess. Synthetic/demo data only; no network; deterministic.

import 'dart:convert';
import 'dart:io';

import 'package:parkinsum_companion/core/models/drug_definition.dart';
import 'package:parkinsum_companion/core/models/food_item.dart';
import 'package:parkinsum_companion/domain/entities/catalog_resolution.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_resolution_engine.dart';

const _engine = CatalogResolutionEngine();

FoodItem _food(String id, String name,
        {List<String> aliases = const [],
        FoodCategory category = FoodCategory.beverage,
        String? code = 'F-CODE'}) =>
    FoodItem(
      id: id,
      name: name,
      category: category,
      aliases: aliases,
      sourceSystem: 'CIQUAL',
      sourceFoodCode: code,
      jurisdiction: 'GLOBAL',
      basisType: 'per_100g',
      proteinG: 1,
      carbsG: 10,
      fatG: 1,
      fiberG: 0,
      sodiumMg: 5,
    );

DrugDefinition _drug(String id, String generic,
        {List<String> brands = const [],
        String releaseType = 'immediate',
        String code = 'SPL'}) =>
    DrugDefinition(
      id: id,
      genericName: generic,
      brandNames: brands,
      tags: const [DrugTag.levodopaLike],
      notes: '',
      sourceSystem: 'DAILYMED',
      sourceProductCode: code,
      jurisdiction: 'US',
      route: 'oral',
      dosageForm: 'tablet',
      releaseType: releaseType,
    );

void main() {
  final foods = [
    _food('f-milktea', 'Milk Tea', aliases: const ['bubble tea', '奶茶']),
    _food('f-green', 'Green Tea'),
    _food('f-shake', 'Protein Shake', category: FoodCategory.protein),
  ];
  final drugs = [
    _drug('d-ldopa', 'levodopa', code: 'SPL-001'),
    _drug('d-sinemet-ir', 'carbidopa/levodopa',
        brands: const ['Sinemet'], releaseType: 'immediate', code: 'SPL-002'),
    _drug('d-sinemet-cr', 'carbidopa/levodopa',
        brands: const ['Sinemet CR'],
        releaseType: 'controlled',
        code: 'SPL-003'),
  ];

  const queries = <String>[
    'milk tea',
    '奶茶',
    'levodopa',
    'Sinemet',
    'carbidopa levodopa 25/100',
    'levodopa CR',
    'dragonfruit_unknown_food',
    'unknown_drug_xyz',
  ];

  final results = <CatalogResolutionResult>[
    for (final q in queries)
      _engine.resolve(query: q, foods: foods, drugs: drugs),
  ];

  final jsonDoc = {
    'report_type': 'catalog_resolution_demo',
    'not_clinically_calibrated': true,
    'no_dose_inference': true,
    'generated_at': 'synthetic-demo',
    'case_count': results.length,
    'cases': [for (final r in results) r.toJson()],
  };

  final outDir = Directory('build/catalog_resolution');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File('${outDir.path}/latest.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(jsonDoc));
  File('${outDir.path}/latest.md').writeAsStringSync(_markdown(results));

  stdout
      .writeln('Catalog resolution demo: ${results.length} synthetic queries.');
  for (final r in results) {
    final best = r.bestCandidate;
    stdout.writeln('  - "${r.query}": ${r.status} / ${r.domain}'
        '${best == null ? '' : ' → ${best.displayName} '
            '(${best.matchType}, ${best.confidenceBand})'}');
  }
  stdout
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
}

String _markdown(List<CatalogResolutionResult> rs) {
  final b = StringBuffer()
    ..writeln('# ParkinSUM Catalog Resolution — synthetic demo')
    ..writeln()
    ..writeln('Educational/research prototype. Catalog resolution returns '
        '**candidates + uncertainty**, never a recommendation. It does not tell '
        'the user what to eat or take, infers no user dose, and does not '
        'silently guess. Synthetic data only; not clinically calibrated.')
    ..writeln()
    ..writeln('| query | domain | status | best candidate | match | band |')
    ..writeln('| --- | --- | --- | --- | --- | --- |');
  for (final r in rs) {
    final c = r.bestCandidate;
    b.writeln('| ${r.query} | ${r.domain} | ${r.status} | '
        '${c?.displayName ?? '—'} | ${c?.matchType ?? '—'} | '
        '${c?.confidenceBand ?? '—'} |');
  }
  b
    ..writeln()
    ..writeln('## Safety boundary')
    ..writeln()
    ..writeln(rs.first.safetyBoundary)
    ..writeln()
    ..writeln(rs.first.notAdviceText);
  return b.toString();
}
