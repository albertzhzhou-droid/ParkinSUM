import '../../../core/models/drug_definition.dart';
import '../../../core/models/food_item.dart';
import '../../../domain/entities/cdss_records.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';

/// Importer-side reconciliation between the App food/drug catalog and the
/// interaction-engine `DrugTag` enum.
///
/// What this audit does:
///
/// 1. **Tag completeness check**: for every drug in the catalog, compute
///    what `inferDrugTag()` (the importer-side, name-based heuristic that
///    the FDC / DailyMed / DPD / EMA / PMDA importers use) would assign.
///    If `inferDrugTag` would have produced a tag and the catalog row does
///    NOT carry that tag, it is reported as a `missing_tag` gap so the
///    interaction engine cannot silently miss it.
///
/// 2. **Schema coverage gap surfacing**: there are PD-relevant drug-food /
///    drug-drug interactions that the *current* `DrugTag` enum cannot
///    express (e.g. PPIs reducing levodopa absorption, SSRIs ↔ MAOI-B
///    serotonin risk, multivalent-cation antacids, serotonergic opioids).
///    The audit lists these as `schema_coverage_gap` rows tagged with the
///    matching drug IDs, so reviewers can see exactly which catalog
///    entries the rule registry cannot currently fire on.
///
/// 3. **Iron-containing supplement double-check**: confirms anything with
///    "iron" / "ferrous" / "ferric" in the generic name carries the
///    `mineralSupplement` tag (the DailyMed / DPD iron interaction rules
///    fire off this tag).
///
/// What this audit deliberately does NOT do:
/// - It does not invent new `DrugTag` values; that would be a core enum
///   change owned by the interaction-engine team.
/// - It does not promote any food into a structured "iron-rich" or
///   "high-tyramine" facts table; the meal-context tags
///   (`coeventSubstanceTags`) remain user-supplied at meal-log time.
class CatalogInteractionAudit {
  const CatalogInteractionAudit._();

  /// Patterns describing PD-relevant interactions that the current DrugTag
  /// enum cannot express. Each entry: a substring of the generic name (lower
  /// case) → the human-readable interaction concern.
  static const Map<String, String> _schemaCoverageGapPatterns =
      <String, String>{
    // PPIs / H2 blockers — pH-dependent levodopa absorption.
    'omeprazole': 'PPI: alters gastric pH; may reduce levodopa absorption.',
    'pantoprazole': 'PPI: alters gastric pH; may reduce levodopa absorption.',
    'esomeprazole': 'PPI: alters gastric pH; may reduce levodopa absorption.',
    'famotidine': 'H2 blocker: may alter gastric pH affecting levodopa.',
    // Multivalent-cation antacids — chelation of levodopa.
    'calcium carbonate':
        'Multivalent cation antacid: may chelate levodopa and reduce absorption.',
    'magnesium hydroxide':
        'Multivalent cation antacid: may chelate levodopa and reduce absorption.',
    // SSRI / SNRI / atypical antidepressants ↔ MAOI-B.
    'sertraline':
        'SSRI: theoretical serotonin syndrome risk with MAOI-B (rasagiline / selegiline / safinamide).',
    'fluoxetine': 'SSRI: theoretical serotonin syndrome risk with MAOI-B.',
    'paroxetine': 'SSRI: theoretical serotonin syndrome risk with MAOI-B.',
    'citalopram': 'SSRI: theoretical serotonin syndrome risk with MAOI-B.',
    'escitalopram': 'SSRI: theoretical serotonin syndrome risk with MAOI-B.',
    'venlafaxine': 'SNRI: theoretical serotonin syndrome risk with MAOI-B.',
    'duloxetine': 'SNRI: theoretical serotonin syndrome risk with MAOI-B.',
    'mirtazapine': 'Atypical antidepressant: serotonergic; review with MAOI-B.',
    'trazodone': 'Atypical antidepressant: serotonergic; review with MAOI-B.',
    // Serotonergic opioids ↔ MAOI-B.
    'tramadol':
        'Opioid + SNRI activity: contraindicated/cautioned with MAOI-B; seizure and serotonin syndrome risk.',
    'meperidine':
        'Opioid: contraindicated with MAOI-B (severe serotonin syndrome risk).',
    'pethidine':
        'Opioid: contraindicated with MAOI-B (severe serotonin syndrome risk).',
    // Antipsychotics / dopamine antagonists — worsen Parkinsonism.
    'haloperidol':
        'Typical antipsychotic: D2 antagonism may worsen Parkinsonism.',
    'risperidone':
        'Atypical antipsychotic: D2 antagonism may worsen Parkinsonism.',
    'olanzapine': 'Atypical antipsychotic: may worsen Parkinsonism.',
    'metoclopramide': 'Central D2 antagonist: may worsen Parkinsonism (avoid).',
    'prochlorperazine': 'Phenothiazine: D2 antagonism may worsen Parkinsonism.',
    // Note: domperidone is intentionally NOT in this list because it is a
    // *peripheral* D2 antagonist used to counter dopamine-agonist nausea.
  };

  /// Check name substrings that indicate an iron supplement (and so should
  /// always carry `DrugTag.mineralSupplement`).
  static const List<String> _ironNamePatterns = <String>[
    'iron',
    'ferrous',
    'ferric',
    '硫酸亚铁',
  ];

  /// Run the reconciliation and return a structured report.
  static Map<String, Object?> audit({
    required List<DrugDefinition> drugs,
    List<FoodItem> foods = const <FoodItem>[],
  }) {
    final missingTagGaps = <Map<String, Object?>>[];
    final schemaCoverageGaps = <Map<String, Object?>>[];
    final ironCheck = <Map<String, Object?>>[];

    for (final drug in drugs) {
      final genericLower = drug.genericName.toLowerCase();
      final inferred = inferDrugTag(drug.genericName);

      // 1. Tag completeness.
      if (inferred != null && !drug.tags.contains(inferred)) {
        missingTagGaps.add({
          'drug_id': drug.id,
          'generic_name': drug.genericName,
          'expected_tag': inferred.name,
          'actual_tags': drug.tags.map((t) => t.name).toList(),
          'reason': 'Heuristic inferDrugTag() would assign ${inferred.name}; '
              'the interaction engine fires on this tag.',
        });
      }

      // 2. Schema coverage gaps.
      for (final entry in _schemaCoverageGapPatterns.entries) {
        if (genericLower.contains(entry.key)) {
          schemaCoverageGaps.add({
            'drug_id': drug.id,
            'generic_name': drug.genericName,
            'pattern': entry.key,
            'concern': entry.value,
            'reason':
                'Current DrugTag enum cannot represent this interaction class; '
                    'the interaction engine cannot fire automatically. Reviewers '
                    'must surface this through the rule registry or user-supplied '
                    'meal-context tags.',
          });
        }
      }

      // 3. Iron supplement double-check.
      final looksLikeIron = _ironNamePatterns.any(genericLower.contains);
      if (looksLikeIron) {
        ironCheck.add({
          'drug_id': drug.id,
          'generic_name': drug.genericName,
          'has_mineral_supplement_tag':
              drug.tags.contains(DrugTag.mineralSupplement),
        });
      }
    }

    return <String, Object?>{
      'drug_count_audited': drugs.length,
      'food_count_audited': foods.length,
      'missing_tag_count': missingTagGaps.length,
      'schema_coverage_gap_count': schemaCoverageGaps.length,
      'iron_supplement_check': ironCheck,
      'missing_tag_gaps': missingTagGaps,
      'schema_coverage_gaps': schemaCoverageGaps,
    };
  }

  /// Build a `P0ImportBundle` carrying one `SourceDocumentRecord` that
  /// embeds the reconciliation report. Conservative: emits no observations,
  /// no facts, no crosswalks — the catalog itself is unchanged.
  static P0ImportBundle buildAuditBundle({
    required List<DrugDefinition> drugs,
    List<FoodItem> foods = const <FoodItem>[],
  }) {
    final report = audit(drugs: drugs, foods: foods);
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'CATALOG_INTERACTION_AUDIT',
      externalKey: 'reconciliation_v1',
    );
    return P0ImportBundle(
      sourceDocuments: [
        buildSourceDocumentRecord(
          sourceDocId: sourceDocId,
          sourceFamily: 'CATALOG_INTERACTION_AUDIT',
          organization: 'ParkinSUM Companion (importer-side audit)',
          jurisdiction: 'GLOBAL',
          docType: 'catalog_interaction_audit_report',
          title: 'Catalog ↔ interaction-engine reconciliation '
              '(${drugs.length} drugs / ${foods.length} foods)',
          originUrl: 'app://catalog-interaction-audit/reconciliation_v1',
          licenseNote:
              'Importer-side audit summary. Does not modify the catalog or '
              'rule registry; surfaces gaps for reviewer attention.',
          language: 'en',
          dataTier: KnowledgeDataTier.p2,
          ingestionStrategy: SourceIngestionStrategy.controlledExport,
          rawPayload: stringifyPayload({
            ...report,
            'audit_gaps': <Map<String, Object?>>[
              ImporterAudit.auditGap(
                fieldName: 'missing_tag',
                reason: 'Catalog rows whose generic name implies a DrugTag but '
                    'the row is missing that tag. Each gap is a real gap the '
                    'reviewer should close by adding the tag.',
                observedCount: (report['missing_tag_count'] as int?) ?? 0,
              ),
              ImporterAudit.auditGap(
                fieldName: 'schema_coverage_gap',
                reason:
                    'PD-relevant interactions the current DrugTag enum cannot '
                    'express (PPI / multivalent-cation antacid / SSRI / SNRI / '
                    'serotonergic opioid / dopamine antagonist). Listed here '
                    'so reviewers can route them through the curated rule '
                    'registry or meal-context tags.',
                observedCount:
                    (report['schema_coverage_gap_count'] as int?) ?? 0,
              ),
            ],
            'parser_limitation':
                'Audit is a reconciliation report only. It does NOT add tags '
                    'to catalog rows, does NOT add rules to the rule registry, '
                    'and does NOT fabricate new DrugTag enum values.',
          }),
        ),
      ],
    );
  }
}
