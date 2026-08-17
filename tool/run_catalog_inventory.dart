// Generates a deterministic inventory of everything the prototype ships —
// foods, medications, source documents, rules, copy templates, replay
// scenarios, and model assumptions — with breakdowns by source family,
// jurisdiction, licence, and status.
//
// Usage:
//   dart run tool/run_catalog_inventory.dart   (or: npm run catalog:inventory)
//
// Reads only in-repo seeds and registries. No network, no clock, no
// timestamps, so regenerated reports diff cleanly. The counts come from
// `buildCatalogInventory()` in the domain layer — the same function the in-app
// diagnostics view calls — so the CLI and the UI cannot report different
// numbers.
//
// Always exits 0: this is a transparency report, not a gate. Counting what
// ships is not a claim that the coverage is adequate.
//
// Educational/research prototype. Synthetic data only. Not medical advice.

import 'dart:io';

import 'package:parkinsum_companion/domain/usecases/catalog_inventory_diagnostics.dart';

void main() {
  final report = buildCatalogInventory();

  final outDir = Directory('build/catalog_inventory');
  if (!outDir.existsSync()) outDir.createSync(recursive: true);
  File(
    '${outDir.path}/latest.json',
  ).writeAsStringSync(encodeCatalogInventory(report));
  File('${outDir.path}/latest.md').writeAsStringSync(report.toMarkdown());

  stdout
    ..writeln(
      'Catalog inventory: ${report.foodCount} foods, '
      '${report.drugCount} medications, '
      '${report.sourceDocumentCount} source documents '
      '(${report.nonLiveSourceDocumentCount} not live), '
      '${report.ruleCount} rules, '
      '${report.replayScenarioCount} replay scenarios, '
      '${report.modelAssumptionCount} model assumptions.',
    )
    ..writeln('Report: ${outDir.path}/latest.json')
    ..writeln('Report: ${outDir.path}/latest.md');
  exit(0);
}
