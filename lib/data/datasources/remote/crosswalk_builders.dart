import 'dart:convert';

import '../../../domain/entities/cdss_records.dart';
import 'importer_audit.dart';
import 'p0_import_support.dart';

/// Importer-side crosswalk builders.
///
/// Each importer converts authoritative external identifiers (NDC, DIN, EMA
/// product number, PMDA code, FDC id, Ciqual code, China page code, FAO
/// country) into [ConceptVariantCrosswalkRecord] rows so that the CDSS layer
/// does not have to re-derive them from variant rows.
///
/// Notes:
/// - When a regulator publishes both authoritative and reference-only ids,
///   the caller passes [confidence] and `status` accordingly (the PMDA
///   English index, for example, is recorded with status `reference_only`).
/// - When the source identifier is uncertain we DO NOT emit a crosswalk row;
///   the raw value should remain inside `source_document.raw_payload` as an
///   audit gap.
ConceptVariantCrosswalkRecord buildCrosswalk({
  required String domain,
  required String conceptId,
  required String variantId,
  required String externalIdSystem,
  required String externalIdValue,
  required String jurisdiction,
  required String sourceDocId,
  String? appEntityId,
  double confidence = 1.0,
  String status = 'active',
  Map<String, Object?> mappingPayload = const <String, Object?>{},
  DateTime? createdAt,
}) {
  final stamp =
      createdAt ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  return ConceptVariantCrosswalkRecord(
    crosswalkId:
        'xwalk_${stableHash('$domain:$variantId:$externalIdSystem:$externalIdValue')}',
    domain: domain,
    appEntityId: appEntityId ?? externalIdValue,
    conceptId: conceptId,
    variantId: variantId,
    externalIdSystem: externalIdSystem,
    externalIdValue: externalIdValue,
    jurisdiction: jurisdiction,
    sourceDocId: sourceDocId,
    importRunId: null,
    confidence: confidence,
    status: status,
    mappingPayloadJson: jsonEncode(
      ImporterAudit.crosswalkPayload(
        externalIdSystem: externalIdSystem,
        payload: mappingPayload,
      ),
    ),
    createdAt: stamp,
  );
}
