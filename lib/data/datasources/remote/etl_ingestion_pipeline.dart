import 'dart:convert';

import '../../../core/utils/qualified_value_parser.dart';
import '../../../domain/entities/cdss_records.dart';

class EtlObservationInput {
  final String sourceFamily;
  final String organization;
  final String documentType;
  final String title;
  final String jurisdiction;
  final String originUrl;
  final String entityType;
  final String entityKey;
  final String attributeCode;
  final String rawValue;
  final String unit;
  final String scopeHash;
  final String dataTier;
  final String ingestionStrategy;

  const EtlObservationInput({
    required this.sourceFamily,
    required this.organization,
    required this.documentType,
    required this.title,
    required this.jurisdiction,
    required this.originUrl,
    required this.entityType,
    required this.entityKey,
    required this.attributeCode,
    required this.rawValue,
    required this.unit,
    required this.scopeHash,
    this.dataTier = KnowledgeDataTier.p0,
    this.ingestionStrategy = SourceIngestionStrategy.authoritativeDirect,
  });
}

class EtlIngestionPipeline {
  List<Object> ingestFoodDatabase({
    required List<EtlObservationInput> rows,
    required String sourcePrefix,
  }) {
    return _ingest(rows: rows, sourcePrefix: sourcePrefix);
  }

  List<Object> ingestDrugLabels({
    required List<EtlObservationInput> rows,
    required String sourcePrefix,
  }) {
    return _ingest(rows: rows, sourcePrefix: sourcePrefix);
  }

  List<Object> _ingest({
    required List<EtlObservationInput> rows,
    required String sourcePrefix,
  }) {
    final output = <Object>[];

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final sourceId = '${sourcePrefix}_doc_$index';
      final observationId = '${sourcePrefix}_obs_$index';

      output.add(
        SourceDocumentRecord(
          sourceDocId: sourceId,
          sourceFamily: row.sourceFamily,
          dataTier: row.dataTier,
          ingestionStrategy: row.ingestionStrategy,
          organization: row.organization,
          docType: row.documentType,
          title: row.title,
          jurisdiction: row.jurisdiction,
          originUrl: row.originUrl,
          publishedAt: DateTime.now(),
          effectiveAt: DateTime.now(),
          language: 'und',
          licenseNote: 'source_managed',
          checksum: '$sourceId:${row.entityKey}:${row.attributeCode}',
          sourceStatus: 'active',
          rawPayload: jsonEncode({
            'entity_type': row.entityType,
            'entity_key': row.entityKey,
            'attribute_code': row.attributeCode,
            'raw_value': row.rawValue,
            'unit': row.unit,
          }),
        ),
      );

      output.add(
        ObservationRecord(
          observationId: observationId,
          domain: 'etl',
          entityType: row.entityType,
          entityKey: row.entityKey,
          attributeCode: row.attributeCode,
          valueType: 'numeric_interval',
          value: parseQualifiedValue(row.rawValue),
          unit: row.unit,
          basisType: 'per_100g_edible_part',
          basisAmount: 100,
          scopeHash: row.scopeHash,
          sourceDocId: sourceId,
          recordLocator: '${row.entityKey}:${row.attributeCode}',
          methodCode: null,
          extractionConfidence: 1,
        ),
      );
    }

    return output;
  }
}
