import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/clinical_evidence_source_seed.dart';
import 'package:parkinsum_companion/core/constants/p0_food_source_seed.dart';
import 'package:parkinsum_companion/domain/entities/cdss_records.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/usecases/catalog_inventory_diagnostics.dart';

import 'helpers/no_phi_json_assertions.dart';

/// W4 — Catalog inventory.
///
/// Aggregate coverage was invisible: the only shipped-scale number on screen
/// was the current *search-result* count. This report computes the real one,
/// and these tests keep it honest.
///
/// Educational prototype only; synthetic/demo data only. Counting coverage is
/// never a claim that the coverage is adequate.
void main() {
  test('every source status is classified as live or not-live', () {
    // This is the regression guard for a real bug in the first version of the
    // report: an allowlist of {active, active_reference} silently treated all
    // 22 `active_evidence` documents as stale, reporting 28 of 43 non-live
    // when the true figure is 6. An unclassified status must fail loudly
    // rather than default to either answer.
    final statuses = <SourceDocumentRecord>[
      ...p0SourceDocumentSeed,
      ...clinicalEvidenceSourceDocuments,
    ].map((doc) => doc.sourceStatus).toSet();

    final unclassified = statuses.difference(kAllKnownSourceStatuses);
    expect(
      unclassified,
      isEmpty,
      reason:
          'Unclassified source status(es): ${unclassified.join(", ")}. Add '
          'each to kLiveSourceStatuses or kNonLiveSourceStatuses — do not let '
          'it default.',
    );
    expect(
      kLiveSourceStatuses.intersection(kNonLiveSourceStatuses),
      isEmpty,
      reason: 'A status cannot be both live and not live.',
    );
  });

  test('counts are non-zero and internally consistent', () {
    final report = buildCatalogInventory();
    expect(report.foodCount, greaterThan(0));
    expect(report.drugCount, greaterThan(0));
    expect(report.sourceDocumentCount, greaterThan(0));
    expect(report.ruleCount, greaterThan(0));
    expect(report.replayScenarioCount, greaterThan(0));
    expect(report.modelAssumptionCount, greaterThan(0));

    expect(
      report.nonLiveSourceDocumentCount,
      lessThanOrEqualTo(report.sourceDocumentCount),
    );
    // Every document-dimension breakdown must account for every document; a
    // short total means values were dropped rather than bucketed.
    for (final breakdown in report.breakdowns.where(
      (b) => b.dimension.contains('(documents)'),
    )) {
      expect(
        breakdown.total,
        report.sourceDocumentCount,
        reason:
            '${breakdown.dimension} totals ${breakdown.total} but '
            '${report.sourceDocumentCount} documents ship.',
      );
    }
  });

  test('report is deterministic', () {
    final a = encodeCatalogInventory(buildCatalogInventory());
    final b = encodeCatalogInventory(buildCatalogInventory());
    expect(a, b, reason: 'Inventory drifted between identical runs.');
    expect(
      buildCatalogInventory().toMarkdown(),
      buildCatalogInventory().toMarkdown(),
    );
    // No wall-clock leakage.
    expect(a, isNot(contains(RegExp(r'20\d{2}-\d{2}-\d{2}T'))));
  });

  test('markdown tables survive free-text values', () {
    // Licence notes and organization names are free text; an unescaped pipe
    // silently corrupts the whole table.
    final markdown = buildCatalogInventory().toMarkdown();
    for (final line in markdown.split('\n')) {
      if (!line.startsWith('| ')) continue;
      expect(
        '|'.allMatches(line).length,
        3,
        reason: 'Malformed table row (stray pipe): $line',
      );
    }
  });

  test('carries the safety boundary and no banned copy or PHI keys', () {
    final report = buildCatalogInventory();
    final json = report.toJson();
    expect(json['safety_boundary'], RuleExplanation.defaultSafetyBoundary);
    expect(json['not_advice_text'], RuleExplanation.defaultNotAdvice);
    expect(json['no_medical_advice'], isTrue);
    expect(findBannedSubstrings(jsonEncode(json)), isEmpty);
    expect(findBannedSubstrings(report.toMarkdown()), isEmpty);
    scanNoPhiKeys(json);
  });

  test('known gaps are reported rather than hidden', () {
    final report = buildCatalogInventory();
    final markdown = report.toMarkdown();
    expect(markdown, contains('Known gaps'));
    expect(markdown, contains('not carrying live data'));
    expect(markdown, contains('placeholder external code'));
    // Placeholder source codes exist today; if that ever reaches zero the
    // catalog genuinely improved, so this only guards against the count
    // silently disappearing from the report.
    expect(
      report.toJson().containsKey(
        'catalog_entries_with_placeholder_source_code',
      ),
      isTrue,
    );
  });
}
