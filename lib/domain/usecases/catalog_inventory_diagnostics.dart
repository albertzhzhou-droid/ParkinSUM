/// Deterministic inventory of everything the prototype actually ships.
///
/// The catalog UI shows rich per-item provenance, and the docs carry prose
/// roll-ups, but nothing computed the aggregate: how many foods, drugs, source
/// documents, rules, templates, scenarios, and model assumptions ship, and how
/// they break down by source family, jurisdiction, licence, and status. The one
/// aggregate number on screen was the *search-result* count, rendered under a
/// "how much ships" intent.
///
/// This is the single source of truth for those counts, following the
/// deliberate precedent of `explanation_copy_diagnostics.dart` and
/// `localization_lint_diagnostics.dart`: the CLI and the in-app diagnostics
/// view call the same function, so they cannot report different numbers.
///
/// Pure and deterministic — no I/O, no clock, no network, no timestamps — so
/// the report diffs cleanly and can be goldened.
///
/// Educational prototype only; synthetic/demo data only; not calibrated for
/// real care. Counting what ships is a transparency statement, never a claim
/// about coverage adequacy or clinical fitness.
library;

import 'dart:convert';

import '../../core/analysis/medication_repository.dart';
import '../../core/constants/baseline_cdss_rules.dart';
import '../../core/constants/clinical_evidence_source_seed.dart';
import '../../core/constants/mechanistic_replay_scenarios.dart';
import '../../core/constants/p0_food_source_seed.dart';
import '../entities/cdss_records.dart';
import '../entities/rule_explanation.dart';
import 'model_assumption_registry.dart';
import 'safe_copy_template_registry.dart';

/// Source-document statuses that mean "declared but not carrying live data".
///
/// Enumerated as a **denylist** rather than an allowlist of live statuses, and
/// the reason is a bug this very report caught: an allowlist of
/// `{active, active_reference}` silently classified all 22 `active_evidence`
/// documents as non-live, reporting 28 of 43 stale when the real figure is 6.
/// An unknown status must not be assumed dead any more than it should be
/// assumed alive — so `kAllKnownSourceStatuses` pins the full vocabulary and
/// `catalog_inventory_test.dart` fails on anything unclassified.
const Set<String> kNonLiveSourceStatuses = <String>{
  'access_controlled',
  'planned',
  'pending_structured_endpoint',
  'reference_only',
};

/// Statuses that carry live data.
const Set<String> kLiveSourceStatuses = <String>{
  'active',
  'active_evidence',
  'active_reference',
};

/// The complete known status vocabulary. A status outside this set is a
/// classification gap, not a silently-defaulted value.
Set<String> get kAllKnownSourceStatuses => {
  ...kLiveSourceStatuses,
  ...kNonLiveSourceStatuses,
};

/// A counted breakdown of one dimension (e.g. jurisdiction → count).
///
/// Entries are sorted by descending count then by key, so the rendering is
/// stable regardless of map iteration order.
class InventoryBreakdown {
  final String dimension;
  final Map<String, int> counts;

  const InventoryBreakdown({required this.dimension, required this.counts});

  List<MapEntry<String, int>> get sortedEntries {
    final entries = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    return entries;
  }

  int get total => counts.values.fold(0, (sum, value) => sum + value);

  Map<String, dynamic> toJson() => {
    'dimension': dimension,
    'distinct_values': counts.length,
    'total': total,
    'counts': {for (final e in sortedEntries) e.key: e.value},
  };
}

class CatalogInventoryReport {
  static const String kReportType = 'parkinsum_catalog_inventory';

  final int foodCount;
  final int drugCount;
  final int sourceDocumentCount;
  final int ruleCount;
  final int copyTemplateCount;
  final int replayScenarioCount;
  final int modelAssumptionCount;

  final List<InventoryBreakdown> breakdowns;

  /// Source documents whose status means they are declared but not actually
  /// carrying live data. Counting these separately keeps the headline number
  /// from implying more coverage than exists.
  final int nonLiveSourceDocumentCount;

  /// Catalog entries whose external primary key is still a placeholder
  /// (`UNSPECIFIED_*`). Surfaced rather than hidden, matching the
  /// `missing_artifact` convention used by the report generators.
  final int unspecifiedSourceCodeCount;

  const CatalogInventoryReport({
    required this.foodCount,
    required this.drugCount,
    required this.sourceDocumentCount,
    required this.ruleCount,
    required this.copyTemplateCount,
    required this.replayScenarioCount,
    required this.modelAssumptionCount,
    required this.breakdowns,
    required this.nonLiveSourceDocumentCount,
    required this.unspecifiedSourceCodeCount,
  });

  Map<String, dynamic> toJson() => {
    'report_type': kReportType,
    'counts': {
      'foods': foodCount,
      'drugs': drugCount,
      'source_documents': sourceDocumentCount,
      'rules': ruleCount,
      'copy_templates': copyTemplateCount,
      'replay_scenarios': replayScenarioCount,
      'model_assumptions': modelAssumptionCount,
    },
    'source_documents_not_live': nonLiveSourceDocumentCount,
    'catalog_entries_with_placeholder_source_code': unspecifiedSourceCodeCount,
    'breakdowns': breakdowns.map((b) => b.toJson()).toList(growable: false),
    'not_clinically_calibrated': true,
    'synthetic_demo_data_only': true,
    'no_medical_advice': true,
    'safety_boundary': RuleExplanation.defaultSafetyBoundary,
    'not_advice_text': RuleExplanation.defaultNotAdvice,
  };

  String toMarkdown() {
    final buffer = StringBuffer()
      ..writeln('# Catalog inventory')
      ..writeln()
      ..writeln(
        'What this prototype actually ships. Counting coverage is not a claim '
        'that the coverage is adequate — this is an educational prototype and '
        'is not calibrated for real care.',
      )
      ..writeln()
      ..writeln('| Item | Count |')
      ..writeln('| --- | --- |')
      ..writeln('| Foods | $foodCount |')
      ..writeln('| Medications | $drugCount |')
      ..writeln('| Source documents | $sourceDocumentCount |')
      ..writeln('| CDSS rules | $ruleCount |')
      ..writeln('| Safe-copy templates | $copyTemplateCount |')
      ..writeln('| Replay scenarios | $replayScenarioCount |')
      ..writeln('| Model assumptions | $modelAssumptionCount |')
      ..writeln()
      ..writeln('## Known gaps')
      ..writeln()
      ..writeln(
        '- Source documents not carrying live data: '
        '$nonLiveSourceDocumentCount of $sourceDocumentCount',
      )
      ..writeln(
        '- Catalog entries with a placeholder external code: '
        '$unspecifiedSourceCodeCount',
      )
      ..writeln();

    for (final breakdown in breakdowns) {
      buffer
        ..writeln('## By ${breakdown.dimension}')
        ..writeln()
        ..writeln('| Value | Count |')
        ..writeln('| --- | --- |');
      for (final entry in breakdown.sortedEntries) {
        buffer.writeln('| ${_sanitizeCell(entry.key)} | ${entry.value} |');
      }
      buffer.writeln();
    }

    buffer
      ..writeln('## Safety boundary')
      ..writeln()
      ..writeln(RuleExplanation.defaultSafetyBoundary)
      ..writeln()
      ..writeln(RuleExplanation.defaultNotAdvice);
    return buffer.toString();
  }
}

/// Strips characters that would break a Markdown table cell.
///
/// Licence notes and organization names are free text; an unescaped pipe
/// silently corrupts the whole table. Mirrors the sanitizing already done by
/// `EvidenceGraphMermaidRenderer`.
String _sanitizeCell(String value) => value
    .replaceAll(RegExp(r'[|\r\n]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

/// Builds the inventory from the shipped seeds and registries.
CatalogInventoryReport buildCatalogInventory() {
  final foods = buildP0FoodCatalog();
  final drugs = MedicationRepository.createDefault().allDrugs;
  final sourceDocuments = <SourceDocumentRecord>[
    ...p0SourceDocumentSeed,
    ...clinicalEvidenceSourceDocuments,
  ];

  Map<String, int> tally(Iterable<String> values) {
    final counts = <String, int>{};
    for (final value in values) {
      final key = value.trim().isEmpty ? 'unspecified' : value.trim();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  return CatalogInventoryReport(
    foodCount: foods.length,
    drugCount: drugs.length,
    sourceDocumentCount: sourceDocuments.length,
    ruleCount: baselineCdssRules.length,
    copyTemplateCount: const SafeCopyTemplateRegistry().templates.length,
    replayScenarioCount: mechanisticReplayScenarios.length,
    modelAssumptionCount: ModelAssumptionRegistry.all.length,
    nonLiveSourceDocumentCount: sourceDocuments
        .where((doc) => kNonLiveSourceStatuses.contains(doc.sourceStatus))
        .length,
    unspecifiedSourceCodeCount:
        foods
            .where((f) => (f.sourceFoodCode ?? '').startsWith('UNSPECIFIED'))
            .length +
        drugs
            .where((d) => (d.sourceProductCode ?? '').startsWith('UNSPECIFIED'))
            .length,
    breakdowns: [
      InventoryBreakdown(
        dimension: 'source family (documents)',
        counts: tally(sourceDocuments.map((d) => d.sourceFamily)),
      ),
      InventoryBreakdown(
        dimension: 'jurisdiction (documents)',
        counts: tally(sourceDocuments.map((d) => d.jurisdiction)),
      ),
      InventoryBreakdown(
        dimension: 'licence note (documents)',
        counts: tally(sourceDocuments.map((d) => d.licenseNote)),
      ),
      InventoryBreakdown(
        dimension: 'status (documents)',
        counts: tally(sourceDocuments.map((d) => d.sourceStatus)),
      ),
      InventoryBreakdown(
        dimension: 'source system (foods)',
        counts: tally(foods.map((f) => f.sourceSystem)),
      ),
      InventoryBreakdown(
        dimension: 'jurisdiction (foods)',
        counts: tally(foods.map((f) => f.jurisdiction)),
      ),
      InventoryBreakdown(
        dimension: 'source system (medications)',
        counts: tally(drugs.map((d) => d.sourceSystem)),
      ),
      InventoryBreakdown(
        dimension: 'jurisdiction (medications)',
        counts: tally(drugs.map((d) => d.jurisdiction)),
      ),
      InventoryBreakdown(
        dimension: 'evidence level (model assumptions)',
        counts: tally(
          ModelAssumptionRegistry.all.map((a) => a.evidenceLevel.name),
        ),
      ),
    ],
  );
}

String encodeCatalogInventory(CatalogInventoryReport report) =>
    const JsonEncoder.withIndent('  ').convert(report.toJson());
