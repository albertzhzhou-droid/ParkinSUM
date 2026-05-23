import '../../../domain/entities/cdss_records.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';
import 'secondary_source_registry.dart';

/// Importer for the secondary-source tier registry.
///
/// Conservative by design:
/// - Emits exactly one `SourceDocumentRecord` per declared source.
/// - Records the tier, organization, landing URL, license, and tier rationale
///   in `raw_payload`.
/// - Does **not** fetch or parse upstream body content. Each row is marked
///   `SourceIngestionStrategy.officialReference` and carries an explicit
///   `audit_gap` for the unparsed body so downstream consumers cannot
///   mistake a registry row for a structured fact.
class SecondarySourceRegistryImporter {
  const SecondarySourceRegistryImporter();

  /// Build a bundle that records every declared secondary source as a
  /// landing-page-metadata `source_document` row.
  ///
  /// [declarations] defaults to [kSecondarySources]; tests override it.
  P0ImportBundle importDeclaredCatalog({
    List<SecondarySourceDeclaration>? declarations,
  }) {
    final entries = declarations ?? kSecondarySources;
    final sourceDocuments = <SourceDocumentRecord>[];
    for (final entry in entries) {
      final sourceDocId = sourceDocumentId(
        sourceSystem: 'TIER_REGISTRY_${entry.sourceFamily}',
        externalKey: stableSlug(entry.landingUrl),
      );
      sourceDocuments.add(
        buildSourceDocumentRecord(
          sourceDocId: sourceDocId,
          sourceFamily: entry.sourceFamily,
          organization: entry.organization,
          jurisdiction: entry.jurisdiction,
          docType: entry.docType,
          title:
              '${entry.organization} (${entry.dataTier}) — ${entry.sourceFamily}',
          originUrl: entry.landingUrl,
          licenseNote: entry.licenseNote,
          language: entry.language,
          dataTier: entry.dataTier,
          ingestionStrategy: SourceIngestionStrategy.officialReference,
          rawPayload: stringifyPayload({
            'tier': entry.dataTier,
            'tier_rationale': entry.tierRationale,
            'landing_url': entry.landingUrl,
            'doc_type': entry.docType,
            'organization': entry.organization,
            'jurisdiction': entry.jurisdiction,
            'language': entry.language,
            'audit_gaps': <Map<String, Object?>>[
              ImporterAudit.auditGap(
                fieldName: 'upstream_body',
                reason: 'Secondary-source registry only records landing-page '
                    'metadata; upstream body is intentionally not fetched or '
                    'parsed by this importer.',
              ),
            ],
            'parser_limitation':
                'Registry-only entry; downstream consumers must treat this as '
                    'a pointer to the authoritative source, not as a parsed fact.',
          }),
        ),
      );
    }
    return P0ImportBundle(sourceDocuments: sourceDocuments);
  }
}
