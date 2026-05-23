import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../../core/models/drug_definition.dart';
import '../../../domain/entities/cdss_records.dart';
import 'crosswalk_builders.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';
import 'p0_source_urls.dart';
import 'source_fetch_client.dart';

/// EMA P1 importer:
/// - 直接读取 EMA 官方 medicines JSON / XLSX；
/// - 当前落库的是产品元数据、来源文档、文档链接和目录投影；
/// - 不伪装成完整 SmPC/leaflet 结构化解析器。
class EmaP1Importer {
  final SourceFetchClient fetchClient;

  const EmaP1Importer({required this.fetchClient});

  /// 抓取 medicines 主表的 JSON + XLSX，两路都保留，便于后续对账。
  Future<P0ImportBundle> fetchAndImportMedicines() async {
    final medicinesJson =
        await fetchClient.getText(P0SourceUrls.emaMedicinesJson);
    final medicinesXlsx =
        await fetchClient.getBytes(P0SourceUrls.emaMedicinesXlsx);
    final medicinesBundle = importMedicinesJson(
      medicinesJson,
      sourceLabel: 'ema_medicines_json',
    );
    final medicinesXlsxBundle = importMedicinesXlsx(
      medicinesXlsx,
      sourceLabel: 'ema_medicines_xlsx',
    );
    return medicinesBundle.merge(medicinesXlsxBundle);
  }

  /// 抓取 post-authorisation 主表的 JSON + XLSX，并作为单独任务暴露给 UI。
  Future<P0ImportBundle> fetchAndImportPostAuthorisation() async {
    final postAuthJson =
        await fetchClient.getText(P0SourceUrls.emaPostAuthorisationJson);
    final postAuthXlsx =
        await fetchClient.getBytes(P0SourceUrls.emaPostAuthorisationXlsx);
    final postAuthBundle = importPostAuthorisationJson(
      postAuthJson,
      sourceLabel: 'ema_post_authorisation_json',
    );
    final postAuthXlsxBundle = importPostAuthorisationXlsx(
      postAuthXlsx,
      sourceLabel: 'ema_post_authorisation_xlsx',
    );
    return postAuthBundle.merge(postAuthXlsxBundle);
  }

  /// 保留综合入口，供以后需要“一次全量抓 EMA P1 元数据”时复用。
  Future<P0ImportBundle> fetchAndImport() async {
    final medicinesBundle = await fetchAndImportMedicines();
    final postAuthBundle = await fetchAndImportPostAuthorisation();
    return medicinesBundle.merge(postAuthBundle);
  }

  P0ImportBundle importMedicinesJson(
    String jsonText, {
    required String sourceLabel,
  }) {
    final decoded = jsonDecode(jsonText);
    final rows = _normalizeRows(decoded);
    return _importRows(
      rows,
      sourceLabel: sourceLabel,
      sourceUrl: P0SourceUrls.emaMedicinesJson,
      includeProjectedDrug: true,
    );
  }

  P0ImportBundle importPostAuthorisationJson(
    String jsonText, {
    required String sourceLabel,
  }) {
    final decoded = jsonDecode(jsonText);
    final rows = _normalizeRows(decoded);
    return _importRows(
      rows,
      sourceLabel: sourceLabel,
      sourceUrl: P0SourceUrls.emaPostAuthorisationJson,
      includeProjectedDrug: false,
    );
  }

  P0ImportBundle importMedicinesXlsx(
    List<int> xlsxBytes, {
    required String sourceLabel,
  }) {
    final rows = _xlsxRowsToMaps(xlsxBytes);
    return _importRows(
      rows,
      sourceLabel: sourceLabel,
      sourceUrl: P0SourceUrls.emaMedicinesXlsx,
      includeProjectedDrug: true,
    );
  }

  P0ImportBundle importPostAuthorisationXlsx(
    List<int> xlsxBytes, {
    required String sourceLabel,
  }) {
    final rows = _xlsxRowsToMaps(xlsxBytes);
    return _importRows(
      rows,
      sourceLabel: sourceLabel,
      sourceUrl: P0SourceUrls.emaPostAuthorisationXlsx,
      includeProjectedDrug: false,
    );
  }

  P0ImportBundle _importRows(
    List<Map<String, dynamic>> rows, {
    required String sourceLabel,
    required String sourceUrl,
    required bool includeProjectedDrug,
  }) {
    final sourceDocuments = <SourceDocumentRecord>[
      buildSourceDocumentRecord(
        sourceDocId: sourceDocumentId(
          sourceSystem: 'EMA',
          externalKey: sourceLabel,
        ),
        sourceFamily: 'EMA',
        organization: 'European Medicines Agency',
        jurisdiction: 'EU',
        docType:
            sourceUrl.endsWith('.json') ? 'json_snapshot' : 'xlsx_snapshot',
        title: 'EMA import $sourceLabel',
        originUrl: sourceUrl,
        licenseNote: 'UNSPECIFIED',
        language: 'en',
        dataTier: KnowledgeDataTier.p1,
        ingestionStrategy: SourceIngestionStrategy.authoritativeDirect,
        rawPayload: stringifyPayload({
          'row_count': rows.length,
          'source_label': sourceLabel,
        }),
      ),
    ];
    final drugConcepts = <DrugConceptRecord>[];
    final drugVariants = <DrugProductVariantRecord>[];
    final projectedDrugs = <DrugDefinition>[];
    final mediaRecords = <DrugProductMediaRecord>[];
    final labelSections = <DrugLabelSectionRecord>[];
    final crosswalks = <ConceptVariantCrosswalkRecord>[];
    final seenConcepts = <String>{};
    final seenVariants = <String>{};
    final seenCrosswalks = <String>{};

    for (final row in rows) {
      final productNumber = _firstNonEmpty(row, const [
        'ema_product_number',
        'product_number',
        'medicine number',
        'medicine_number',
      ]);
      final medicineName = _firstNonEmpty(row, const [
        'medicine_name',
        'name',
        'medicine',
      ]);
      if (productNumber.isEmpty || medicineName.isEmpty) continue;

      final activeSubstance = _firstNonEmpty(row, const [
        'active_substance',
        'international_non_proprietary_name_common_name',
        'inn_common_name',
      ]);
      final genericName =
          activeSubstance.isEmpty ? medicineName : activeSubstance;
      final conceptId = buildDrugConceptId(genericName);
      final variantId = buildDrugVariantId(
        conceptId: conceptId,
        jurisdiction: 'EU',
        sourceSystem: 'EMA',
        externalProductCode: productNumber,
      );
      final holder = _firstNonEmpty(row, const [
        'marketing_authorisation_developer_applicant_holder',
        'marketing_authorisation_holder',
        'applicant_holder',
      ]);
      final medicineUrl = _firstNonEmpty(row, const [
        'medicine_url',
        'url',
        'medicine_page_url',
      ]);
      final atcCode = _firstNonEmpty(row, const [
        'atc_code_human',
        'atc_code',
      ]);
      final route = _inferRoute(row);
      final dosageForm = _inferDosageForm(row);
      final releaseType = _inferReleaseType(medicineName, dosageForm);
      final productSourceDocId = sourceDocumentId(
        sourceSystem: 'EMA',
        externalKey: productNumber,
      );

      final procedureType = _firstNonEmpty(row, const [
        'procedure_type',
        'authorisation_procedure',
      ]);
      final indicationText = _firstNonEmpty(row, const [
        'condition_indication',
        'condition',
        'therapeutic_indication',
        'indication',
      ]);
      final longTextNote = <String, Object?>{
        'preserved_row': row,
        'long_text_audit': <Map<String, Object?>>[
          ImporterAudit.auditGap(
            fieldName: 'condition_indication',
            reason:
                'Indication / condition narrative kept as raw_payload only; not normalized into structured facts.',
            observedCount: indicationText.isEmpty ? 0 : 1,
          ),
          ImporterAudit.auditGap(
            fieldName: 'procedure_type',
            reason:
                'Procedure type captured verbatim; not promoted into a regulatory-action table.',
            observedCount: procedureType.isEmpty ? 0 : 1,
          ),
        ],
        if (procedureType.isNotEmpty) 'procedure_type': procedureType,
        if (indicationText.isNotEmpty) 'condition_indication': indicationText,
      };
      sourceDocuments.add(
        buildSourceDocumentRecord(
          sourceDocId: productSourceDocId,
          sourceFamily: 'EMA',
          organization: 'European Medicines Agency',
          jurisdiction: 'EU',
          docType: 'medicine_page',
          title: medicineName,
          originUrl: medicineUrl.isEmpty ? sourceUrl : medicineUrl,
          licenseNote: 'UNSPECIFIED',
          language: 'en',
          dataTier: KnowledgeDataTier.p1,
          ingestionStrategy: SourceIngestionStrategy.authoritativeDirect,
          rawPayload: stringifyPayload(longTextNote),
        ),
      );

      if (seenConcepts.add(conceptId)) {
        drugConcepts.add(
          DrugConceptRecord(
            drugConceptId: conceptId,
            genericName: genericName,
            atcLikeCode: atcCode.isEmpty ? 'unclassified' : atcCode,
          ),
        );
      }

      if (seenVariants.add(variantId)) {
        drugVariants.add(
          DrugProductVariantRecord(
            drugProductVariantId: variantId,
            drugConceptId: conceptId,
            jurisdiction: 'EU',
            regulator: 'EMA',
            externalProductCode: productNumber,
            route: route,
            dosageForm: dosageForm,
            releaseType: releaseType,
            labelVersion: sourceLabel,
            sourceStatus: 'imported_ema_metadata',
          ),
        );
      }

      final summary = <String>[
        if (holder.isNotEmpty) 'MAH: $holder',
        if (atcCode.isNotEmpty) 'ATC: $atcCode',
        if (medicineUrl.isNotEmpty) 'Page: $medicineUrl',
      ].join(' | ');
      if (summary.isNotEmpty) {
        labelSections.add(
          DrugLabelSectionRecord(
            sectionId: 'section_${stableHash('$variantId:ema_summary')}',
            drugProductVariantId: variantId,
            sourceDocId: productSourceDocId,
            sectionKey: 'ema_medicine_summary',
            sectionTitle: 'EMA medicine summary',
            sectionText: summary,
          ),
        );
      }

      void addCrosswalk({
        required String system,
        required String value,
        double confidence = 1.0,
        String status = 'active',
        Map<String, Object?> extra = const <String, Object?>{},
      }) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        final key = '$variantId|$system|$trimmed';
        if (!seenCrosswalks.add(key)) return;
        crosswalks.add(
          buildCrosswalk(
            domain: 'drug',
            conceptId: conceptId,
            variantId: variantId,
            externalIdSystem: system,
            externalIdValue: trimmed,
            jurisdiction: 'EU',
            sourceDocId: productSourceDocId,
            confidence: confidence,
            status: status,
            mappingPayload: {
              'regulator': 'EMA',
              'medicine_name': medicineName,
              if (atcCode.isNotEmpty) 'atc_code': atcCode,
              if (holder.isNotEmpty) 'mah': holder,
              ...extra,
            },
          ),
        );
      }

      addCrosswalk(
        system: 'EMA product number',
        value: productNumber,
        confidence: 1.0,
        extra: {
          'source_label': sourceLabel,
          ...ImporterAudit.confidenceReason(
            sourceIdentifierType:
                ImporterAudit.sourceIdTypeAuthoritativeProductCode,
            reason: 'EMA product number copied verbatim from medicines row.',
            promotedFields: const ['ema_product_number'],
            nonPromotedFields: const [
              'procedure_type',
              'condition_indication',
            ],
          ),
        },
      );
      if (atcCode.isNotEmpty) {
        addCrosswalk(
          system: 'EMA ATC code',
          value: atcCode,
          confidence: 0.9,
          extra: ImporterAudit.confidenceReason(
            sourceIdentifierType: ImporterAudit.sourceIdTypeMetadataAttribute,
            reason: 'ATC code copied verbatim from EMA medicines row.',
            promotedFields: const ['atc_code'],
            nonPromotedFields: const ['condition_indication'],
          ),
        );
      }
      if (medicineUrl.isNotEmpty) {
        addCrosswalk(
          system: 'EMA medicine URL',
          value: medicineUrl,
          confidence: 0.85,
          extra: {
            'metadata_kind': 'epar_landing',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypeRegulatorMetadataUrl,
              reason: 'Medicine URL copied verbatim from EMA medicines row.',
              promotedFields: const ['medicine_url'],
              nonPromotedFields: const ['condition_indication'],
            ),
          },
        );
      }
      final eparUrl = _firstNonEmpty(row, const [
        'epar_url',
        'european_public_assessment_report_url',
        'assessment_report_url',
      ]);
      if (eparUrl.isNotEmpty) {
        addCrosswalk(
          system: 'EMA EPAR URL',
          value: eparUrl,
          confidence: 0.88,
          extra: {
            'metadata_kind': 'european_public_assessment_report',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypeRegulatorDocumentUrl,
              reason: 'EPAR URL copied verbatim from EMA medicines row.',
              promotedFields: const ['epar_url'],
              nonPromotedFields: const ['epar_pdf_body'],
              parserLimitation:
                  'EPAR document body is not downloaded or structured by this metadata importer.',
            ),
          },
        );
      }
      final documentUrl = _firstNonEmpty(row, const [
        'document_url',
        'product_information_document_url',
      ]);
      if (documentUrl.isNotEmpty) {
        addCrosswalk(
          system: 'EMA SmPC URL',
          value: documentUrl,
          confidence: 0.85,
          extra: {
            'metadata_kind': 'product_information',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypeRegulatorDocumentUrl,
              reason: 'SmPC/product information URL copied from EMA row.',
              promotedFields: const ['document_url'],
              nonPromotedFields: const ['smpc_pdf_body'],
              parserLimitation:
                  'SmPC body is retained as a linked document only, not parsed into normalized facts.',
            ),
          },
        );
      }
      final translationsUrl = _firstNonEmpty(row, const [
        'translations_url',
        'leaflet_url',
      ]);
      if (translationsUrl.isNotEmpty) {
        addCrosswalk(
          system: 'EMA leaflet URL',
          value: translationsUrl,
          confidence: 0.8,
          extra: {
            'metadata_kind': 'leaflet',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypeReferenceTranslationUrl,
              reason: 'Leaflet URL copied from EMA row.',
              promotedFields: const ['translations_url'],
              nonPromotedFields: const ['leaflet_pdf_body'],
              parserLimitation:
                  'Leaflet body is retained as a linked document only, not parsed into normalized facts.',
            ),
          },
        );
      }

      for (final link in _extractLinks(row)) {
        mediaRecords.add(
          DrugProductMediaRecord(
            mediaId:
                'media_${stableHash('$variantId:${link.url}:${link.type}')}',
            drugProductVariantId: variantId,
            sourceDocId: productSourceDocId,
            mediaType: link.type,
            mediaUrl: link.url,
            caption: link.caption,
          ),
        );
      }

      if (includeProjectedDrug) {
        final tag = inferDrugTag(genericName);
        projectedDrugs.add(
          DrugDefinition(
            id: 'drug_ema_${stableSlug(genericName.toLowerCase())}_$productNumber',
            genericName: genericName,
            brandNames: [medicineName],
            aliases: [
              if (activeSubstance.isNotEmpty && activeSubstance != medicineName)
                activeSubstance,
              if (productNumber.isNotEmpty) productNumber,
            ],
            tags: [if (tag != null) tag],
            notes: holder.isEmpty
                ? 'Imported from EMA medicines metadata.'
                : 'Imported from EMA medicines metadata ($holder).',
            interactionSummary:
                'EU product metadata imported from EMA medicines data table/JSON.',
            sourceSystem: 'EMA',
            sourceProductCode: productNumber,
            jurisdiction: 'EU',
            route: route,
            dosageForm: dosageForm,
            releaseType: releaseType,
          ),
        );
      }
    }

    return P0ImportBundle(
      sourceDocuments: sourceDocuments,
      drugConcepts: drugConcepts,
      drugProductVariants: drugVariants,
      drugLabelSections: labelSections,
      drugProductMedias: mediaRecords,
      conceptVariantCrosswalks: crosswalks,
      projectedDrugs: projectedDrugs,
    );
  }

  List<Map<String, dynamic>> _normalizeRows(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false);
    }
    if (decoded is Map<String, dynamic>) {
      for (final key in const ['data', 'rows', 'items', 'results']) {
        final value = decoded[key];
        if (value is List) {
          return value
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);
        }
      }
    }
    return const <Map<String, dynamic>>[];
  }

  List<Map<String, dynamic>> _xlsxRowsToMaps(List<int> xlsxBytes) {
    final archive = ZipDecoder().decodeBytes(xlsxBytes);
    final sharedStrings = _loadSharedStrings(archive);
    final worksheetFile = archive.files
        .where((file) => file.name.startsWith('xl/worksheets/sheet'))
        .toList(growable: false)
      ..sort((a, b) => a.name.compareTo(b.name));
    if (worksheetFile.isEmpty) return const <Map<String, dynamic>>[];
    final sheetXml = utf8.decode(worksheetFile.first.content as List<int>);
    final sheetDoc = XmlDocument.parse(sheetXml);
    final rowNodes = sheetDoc.findAllElements('row').toList(growable: false);
    if (rowNodes.isEmpty) return const <Map<String, dynamic>>[];

    final grid =
        rowNodes.map((row) => _extractRowValues(row, sharedStrings)).toList();
    if (grid.isEmpty) return const <Map<String, dynamic>>[];
    final headers =
        grid.first.map((value) => value.trim()).toList(growable: false);
    final rows = <Map<String, dynamic>>[];
    for (final row in grid.skip(1)) {
      final mapped = <String, dynamic>{};
      for (var index = 0; index < headers.length; index++) {
        final header = headers[index];
        if (header.isEmpty) continue;
        mapped[_normalizeHeader(header)] =
            index < row.length ? row[index].trim() : '';
      }
      if (mapped.values.any((value) => value.toString().trim().isNotEmpty)) {
        rows.add(mapped);
      }
    }
    return rows;
  }

  List<String> _loadSharedStrings(Archive archive) {
    // 有些 EMA xlsx 快照没有 sharedStrings.xml，或者 archive 包版本
    // 对 `orElse` 的占位 ArchiveFile 支持不稳定，因此这里显式走 nullable 查找。
    final matches = archive.files
        .where((item) => item.name == 'xl/sharedStrings.xml')
        .toList(growable: false);
    if (matches.isEmpty) return const <String>[];
    final file = matches.first;
    final text = utf8.decode(file.content as List<int>);
    final doc = XmlDocument.parse(text);
    return doc
        .findAllElements('si')
        .map((node) => node.descendants
            .whereType<XmlText>()
            .map((part) => part.value)
            .join())
        .toList(growable: false);
  }

  List<String> _extractRowValues(XmlElement row, List<String> sharedStrings) {
    final values = <String>[];
    for (final cell in row.findElements('c')) {
      final raw = cell.getElement('v')?.innerText ?? '';
      final type = cell.getAttribute('t');
      if (type == 's') {
        final index = int.tryParse(raw);
        values.add(
          (index != null && index >= 0 && index < sharedStrings.length)
              ? sharedStrings[index]
              : '',
        );
      } else {
        values.add(raw);
      }
    }
    return values;
  }

  String _normalizeHeader(String header) {
    return header
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  String _firstNonEmpty(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }
    return '';
  }

  String _inferRoute(Map<String, dynamic> row) {
    final text = _firstNonEmpty(row, const [
      'route',
      'administration_route',
      'pharmaceutical_form',
      'dosage_form',
    ]).toLowerCase();
    if (text.contains('transdermal') || text.contains('patch')) {
      return 'transdermal';
    }
    if (text.contains('injection') || text.contains('inject')) {
      return 'injection';
    }
    if (text.contains('nasal')) return 'nasal';
    return 'oral';
  }

  String _inferDosageForm(Map<String, dynamic> row) {
    final text = _firstNonEmpty(row, const [
      'pharmaceutical_form',
      'dosage_form',
      'form',
    ]);
    return text.isEmpty ? 'unspecified' : text;
  }

  String _inferReleaseType(String medicineName, String dosageForm) {
    final text = '$medicineName $dosageForm'.toLowerCase();
    if (text.contains('prolonged') ||
        text.contains('extended') ||
        text.contains('modified release')) {
      return 'extended_release';
    }
    if (text.contains('patch')) return 'continuous';
    return 'unspecified';
  }

  List<_EmaLink> _extractLinks(Map<String, dynamic> row) {
    final links = <_EmaLink>[];
    for (final key in row.keys) {
      final value = row[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (!text.startsWith('http')) continue;
      final lowerKey = key.toLowerCase();
      final type = lowerKey.contains('translation')
          ? 'translation_link'
          : lowerKey.contains('document') || lowerKey.contains('leaflet')
              ? 'document_link'
              : 'url';
      links.add(_EmaLink(url: text, type: type, caption: key));
    }
    return links;
  }
}

class _EmaLink {
  final String url;
  final String type;
  final String caption;

  const _EmaLink({
    required this.url,
    required this.type,
    required this.caption,
  });
}
