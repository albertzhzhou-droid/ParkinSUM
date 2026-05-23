import 'dart:convert';

import 'package:xml/xml.dart';

import '../../../core/models/drug_definition.dart';
import '../../../domain/entities/cdss_records.dart';
import 'archive_import_support.dart';
import 'crosswalk_builders.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';
import 'p0_source_urls.dart';
import 'source_fetch_client.dart';

/// DailyMed SPL 导入器。
///
/// 说明：
/// - 当前主要抽取 drug concept / product variant / source document / app 目录摘要；
/// - rule 级知识仍应来自标签解析与手工审校后的 registry，而不是直接把自由文本塞进规则。
///
/// 当前增强：
/// - 仍然会额外提取 P0 规则最关心的 food / iron / tyramine / thickener / enteral 段落；
/// - 同时把可解析到的 SPL section 全量落成 `drug_label_section`，让药品详情页和后续正文索引
///   可以直接消费更完整的官方标签文本。
class DailyMedP0Importer {
  final SourceFetchClient fetchClient;

  const DailyMedP0Importer({required this.fetchClient});

  Future<P0ImportBundle> fetchBySetIds(List<String> setIds) async {
    P0ImportBundle bundle = const P0ImportBundle();
    for (final setId in setIds) {
      final xml = await fetchClient
          .getText('${P0SourceUrls.dailymedSplXmlBase}/$setId.xml');
      final ndcs = await _safeFetchJsonList(
        '${P0SourceUrls.dailymedSplXmlBase}/$setId/ndcs.json',
      );
      final packaging = await _safeFetchJsonList(
        '${P0SourceUrls.dailymedSplXmlBase}/$setId/packaging.json',
      );
      final media = await _safeFetchJsonList(
        '${P0SourceUrls.dailymedSplXmlBase}/$setId/media.json',
      );
      bundle = bundle.merge(
        importSplXml(
          xml,
          ndcs: ndcs.cast<Map<String, dynamic>>(),
          packaging: packaging.cast<Map<String, dynamic>>(),
          media: media.cast<Map<String, dynamic>>(),
        ),
      );
    }
    return bundle;
  }

  /// 直接导入 DailyMed bulk ZIP。
  P0ImportBundle importZipBytes(List<int> zipBytes) {
    var bundle = const P0ImportBundle();
    final files = ArchiveImportSupport.unzipTextFiles(zipBytes);
    final xmlFiles = files.entries
        .where((entry) => entry.key.toLowerCase().endsWith('.xml'))
        .toList(growable: false);
    for (final entry in xmlFiles) {
      bundle = bundle.merge(importSplXml(entry.value));
    }
    return bundle;
  }

  P0ImportBundle importSplXml(
    String xml, {
    List<Map<String, dynamic>> ndcs = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> packaging = const <Map<String, dynamic>>[],
    List<Map<String, dynamic>> media = const <Map<String, dynamic>>[],
  }) {
    final document = XmlDocument.parse(xml);
    final setId = _firstAttr(document, 'setId', 'root') ??
        _firstAttr(document, 'id', 'root') ??
        'UNSPECIFIED_SETID';
    final title = _firstText(document, 'title') ?? 'DailyMed SPL';
    final ingredientNames = _ingredientNames(document);
    final genericName =
        ingredientNames.isEmpty ? title : ingredientNames.join('/');
    final conceptId = buildDrugConceptId(genericName);
    final variantId = buildDrugVariantId(
      conceptId: conceptId,
      jurisdiction: 'US',
      sourceSystem: 'DAILYMED',
      externalProductCode: setId,
    );
    final route = _firstCodeDisplayName(document, 'routeCode') ?? 'oral';
    final dosageForm =
        _firstCodeDisplayName(document, 'formCode') ?? 'unspecified';
    final releaseType = _inferReleaseType(title);
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'DAILYMED',
      externalKey: setId,
    );
    final allSections = _extractAllSections(document);
    final sectionSummaries = _extractRelevantSections(allSections);
    final labelFacts = _extractStructuredLabelFacts(allSections);
    final summaryText = sectionSummaries.values
        .where((value) => value.trim().isNotEmpty)
        .join(' ');
    final labelSections = <DrugLabelSectionRecord>[];
    final labelSectionLocators = <String, _SplSectionEntry>{};
    for (final section in allSections) {
      if (section.text.trim().isEmpty) continue;
      final record = DrugLabelSectionRecord(
        sectionId: 'section_${stableHash('$variantId:${section.key}')}',
        drugProductVariantId: variantId,
        sourceDocId: sourceDocId,
        sectionKey: section.key,
        sectionTitle: section.title,
        sectionText: section.text,
      );
      labelSections.add(record);
      labelSectionLocators[record.sectionId] = section;
    }
    final productCodes = ndcs
        .map(
          (row) => DrugProductCodeRecord(
            productCodeId:
                'code_${stableHash('$variantId:${row['ndc'] ?? row['ndc11'] ?? row.toString()}')}',
            drugProductVariantId: variantId,
            sourceDocId: sourceDocId,
            codeSystem: 'NDC',
            codeValue:
                '${row['ndc'] ?? row['ndc11'] ?? row['package_ndc'] ?? ''}',
            displayText: row['package_description']?.toString(),
          ),
        )
        .where((row) => row.codeValue.isNotEmpty)
        .toList(growable: false);
    final packagingRows = packaging
        .map(
          (row) => DrugProductPackagingRecord(
            packagingId: 'pkg_${stableHash('$variantId:${row.toString()}')}',
            drugProductVariantId: variantId,
            sourceDocId: sourceDocId,
            packageCode:
                row['package_ndc']?.toString() ?? row['ndc']?.toString(),
            description:
                '${row['description'] ?? row['package_description'] ?? row['package_text'] ?? ''}',
            marketingStatus: row['marketing_status']?.toString(),
          ),
        )
        .where((row) => row.description.isNotEmpty)
        .toList(growable: false);
    final mediaRows = media
        .map(
          (row) => DrugProductMediaRecord(
            mediaId: 'media_${stableHash('$variantId:${row.toString()}')}',
            drugProductVariantId: variantId,
            sourceDocId: sourceDocId,
            mediaType: '${row['type'] ?? row['mime_type'] ?? 'media'}',
            mediaUrl: '${row['url'] ?? row['src'] ?? ''}',
            caption: row['name']?.toString() ?? row['caption']?.toString(),
          ),
        )
        .where((row) => row.mediaUrl.isNotEmpty)
        .toList(growable: false);

    final sourceDocument = buildSourceDocumentRecord(
      sourceDocId: sourceDocId,
      sourceFamily: 'DAILYMED',
      organization: 'National Library of Medicine',
      jurisdiction: 'US',
      docType: 'spl_xml',
      title: title,
      originUrl: '${P0SourceUrls.dailymedSplXmlBase}/$setId.xml',
      licenseNote: 'UNSPECIFIED',
      language: 'en',
      rawPayload: stringifyPayload({
        'setid': setId,
        'title': title,
        'ingredients': ingredientNames,
        'section_count': allSections.length,
        'section_titles': allSections.map((item) => item.title).toList(),
        'sections': sectionSummaries,
        'label_facts': labelFacts,
        'audit_gaps': <Map<String, Object?>>[
          ImporterAudit.auditGap(
            fieldName: 'package_description',
            reason:
                'Free-text package description not parsed into structured quantity/size fields.',
            observedCount: ndcs
                .where(
                    (row) => '${row['package_description'] ?? ''}'.isNotEmpty)
                .length,
          ),
          ImporterAudit.auditGap(
            fieldName: 'spl_section_text',
            reason:
                'SPL section bodies kept as drug_label_section text only; no schema-aware extraction beyond known fact patterns.',
            observedCount: allSections.length,
          ),
        ],
      }),
    );

    final tag = inferDrugTag(genericName);
    final projectedDrug = DrugDefinition(
      id: 'drug_dailymed_${stableSlug(genericName.toLowerCase())}_$setId',
      genericName: genericName,
      brandNames: [title],
      aliases: ingredientNames,
      tags: [if (tag != null) tag],
      notes: summaryText.isEmpty ? title : summaryText,
      interactionSummary: _buildInteractionSummary(sectionSummaries),
      sourceSystem: 'DAILYMED',
      sourceProductCode: setId,
      jurisdiction: 'US',
      route: route,
      dosageForm: dosageForm,
      releaseType: releaseType,
    );

    final crosswalks = <ConceptVariantCrosswalkRecord>[
      buildCrosswalk(
        domain: 'drug',
        conceptId: conceptId,
        variantId: variantId,
        externalIdSystem: 'DailyMed setid',
        externalIdValue: setId,
        jurisdiction: 'US',
        sourceDocId: sourceDocId,
        appEntityId: setId,
        confidence: 1.0,
        mappingPayload: {
          'regulator': 'DAILYMED',
          'title': title,
          'ingredient_count': ingredientNames.length,
        },
      ),
    ];
    final seenNdc = <String>{};
    for (final code in productCodes) {
      if (code.codeValue.trim().isEmpty) continue;
      if (!seenNdc.add('${code.codeSystem}:${code.codeValue}')) continue;
      crosswalks.add(
        buildCrosswalk(
          domain: 'drug',
          conceptId: conceptId,
          variantId: variantId,
          externalIdSystem: code.codeSystem,
          externalIdValue: code.codeValue,
          jurisdiction: 'US',
          sourceDocId: sourceDocId,
          confidence: 0.98,
          mappingPayload: {
            'setid': setId,
            if (code.displayText != null)
              'package_description': code.displayText,
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypePackageOrPortionCode,
              reason: 'NDC value taken verbatim from DailyMed ndcs.json.',
              promotedFields: const ['ndc'],
              nonPromotedFields: const ['package_description'],
              promotionDecision: 'package_description_kept_as_free_text_only',
              parserLimitation:
                  'Importer does not parse package_description into quantity/size/unit fields.',
            ),
          },
        ),
      );
    }
    for (final section in labelSections) {
      final locator = labelSectionLocators[section.sectionId];
      crosswalks.add(
        buildCrosswalk(
          domain: 'drug_label_section',
          conceptId: conceptId,
          variantId: variantId,
          externalIdSystem: 'DailyMed SPL section key',
          externalIdValue: section.sectionKey,
          jurisdiction: 'US',
          sourceDocId: sourceDocId,
          confidence: 0.9,
          mappingPayload: {
            'setid': setId,
            'section_id': section.sectionId,
            'section_title': section.sectionTitle,
            if (locator != null) 'section_ordinal': locator.ordinal,
            if (locator?.rawCode != null) 'spl_section_code': locator!.rawCode,
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypeRegulatorDocumentUrl,
              reason:
                  'Section located by SPL XML <section> ordinal/title; raw SPL code preserved when present.',
              promotedFields: const [
                'section_key',
                'section_title',
                'section_ordinal',
                'spl_section_code',
              ],
              nonPromotedFields: const ['section_text_semantics'],
              promotionDecision: 'verbatim_text_in_drug_label_section_only',
              parserLimitation:
                  'No semantic structuring beyond title/text and known fact patterns.',
            ),
          },
        ),
      );
    }
    for (final mediaRow in mediaRows) {
      crosswalks.add(
        buildCrosswalk(
          domain: 'drug_media',
          conceptId: conceptId,
          variantId: variantId,
          externalIdSystem: 'DailyMed media URL',
          externalIdValue: mediaRow.mediaUrl,
          jurisdiction: 'US',
          sourceDocId: sourceDocId,
          confidence: 0.85,
          mappingPayload: {
            'setid': setId,
            'media_type': mediaRow.mediaType,
            if (mediaRow.caption != null) 'caption': mediaRow.caption,
          },
        ),
      );
    }
    final seenPackage = <String>{};
    for (final pack in packagingRows) {
      final code = (pack.packageCode ?? '').trim();
      if (code.isEmpty) continue;
      if (!seenPackage.add(code)) continue;
      crosswalks.add(
        buildCrosswalk(
          domain: 'drug',
          conceptId: conceptId,
          variantId: variantId,
          externalIdSystem: 'DailyMed package code',
          externalIdValue: code,
          jurisdiction: 'US',
          sourceDocId: sourceDocId,
          confidence: 0.92,
          mappingPayload: {
            'setid': setId,
            'description': pack.description,
            if (pack.marketingStatus != null)
              'marketing_status': pack.marketingStatus,
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypePackageOrPortionCode,
              reason:
                  'Package code copied from DailyMed packaging endpoint; package description is preserved as free text.',
              promotedFields: const ['package_code'],
              nonPromotedFields: const ['package_description_quantity_parse'],
              promotionDecision:
                  'package_code_promoted_description_unstructured',
              parserLimitation:
                  'No quantity/size/unit parser is applied to package descriptions.',
            ),
          },
        ),
      );
    }

    return P0ImportBundle(
      sourceDocuments: [sourceDocument],
      drugConcepts: [
        DrugConceptRecord(
          drugConceptId: conceptId,
          genericName: genericName,
          atcLikeCode: tag?.name ?? 'unclassified',
        ),
      ],
      drugProductVariants: [
        DrugProductVariantRecord(
          drugProductVariantId: variantId,
          drugConceptId: conceptId,
          jurisdiction: 'US',
          regulator: 'DAILYMED',
          externalProductCode: setId,
          route: route,
          dosageForm: dosageForm,
          releaseType: releaseType,
          labelVersion: 'spl_current',
          sourceStatus: 'imported_spl',
        ),
      ],
      drugLabelSections: labelSections,
      drugProductCodes: productCodes,
      drugProductPackagings: packagingRows,
      drugProductMedias: mediaRows,
      conceptVariantCrosswalks: crosswalks,
      projectedDrugs: [projectedDrug],
    );
  }

  Future<List<dynamic>> _safeFetchJsonList(String url) async {
    try {
      final text = await fetchClient.getText(url);
      final decoded = jsonDecode(text);
      if (decoded is List<dynamic>) return decoded;
      if (decoded is Map<String, dynamic>) {
        final data = decoded['data'];
        if (data is List<dynamic>) return data;
      }
      return const <dynamic>[];
    } catch (_) {
      // 某些 DailyMed 记录可能没有附属 ndcs / packaging / media；
      // 在 P0 导入里这不应该中断主标签导入。
      return const <dynamic>[];
    }
  }

  String? _firstText(XmlDocument document, String tag) {
    final node = document.findAllElements(tag).firstOrNull;
    return node?.innerText.trim().isEmpty == true
        ? null
        : node?.innerText.trim();
  }

  String? _firstAttr(XmlDocument document, String tag, String attr) {
    final node = document.findAllElements(tag).firstOrNull;
    return node?.getAttribute(attr);
  }

  String? _firstCodeDisplayName(XmlDocument document, String tag) {
    final node = document.findAllElements(tag).firstOrNull;
    return node?.getAttribute('displayName');
  }

  List<String> _ingredientNames(XmlDocument document) {
    final names = <String>{};
    for (final node in document.findAllElements('ingredient')) {
      for (final name in node.findAllElements('name')) {
        final text = name.innerText.trim();
        if (text.isNotEmpty) {
          names.add(text);
        }
      }
    }
    return names.toList(growable: false);
  }

  List<_SplSectionEntry> _extractAllSections(XmlDocument document) {
    final sections = <_SplSectionEntry>[];
    var ordinal = 0;
    for (final section in document.findAllElements('section')) {
      final title =
          _directChildText(section, 'title') ?? 'Section ${ordinal + 1}';
      final sectionText = _directChildText(section, 'text') ??
          section
              .findAllElements('text')
              .map((node) => node.innerText.trim())
              .where((item) => item.isNotEmpty)
              .join(' ')
              .trim();
      if (title.trim().isEmpty && sectionText.trim().isEmpty) {
        continue;
      }
      final rawCode =
          section.getAttribute('ID') ?? section.getAttribute('code');
      final key = _buildSectionKey(
        title: title,
        index: ordinal,
        code: rawCode,
      );
      sections.add(
        _SplSectionEntry(
          key: key,
          title: title.trim(),
          text: sectionText.trim(),
          ordinal: ordinal,
          rawCode: rawCode,
        ),
      );
      ordinal += 1;
    }
    return sections;
  }

  Map<String, String> _extractRelevantSections(
      List<_SplSectionEntry> allSections) {
    final sections = <String, String>{
      'food_effect': '',
      'iron': '',
      'tyramine': '',
      'thickener': '',
      'enteral_feed': '',
    };
    for (final section in allSections) {
      final title = section.title.toLowerCase();
      final text = section.text;
      final merged = '$title $text'.toLowerCase();
      if (merged.contains('protein') ||
          merged.contains('meal') ||
          merged.contains('high fat')) {
        sections['food_effect'] = '$title $text'.trim();
      }
      if (merged.contains('iron')) {
        sections['iron'] = '$title $text'.trim();
      }
      if (merged.contains('tyramine')) {
        sections['tyramine'] = '$title $text'.trim();
      }
      if (merged.contains('thickener')) {
        sections['thickener'] = '$title $text'.trim();
      }
      if (merged.contains('enteral') || merged.contains('tube feeding')) {
        sections['enteral_feed'] = '$title $text'.trim();
      }
    }
    return sections;
  }

  String _buildSectionKey({
    required String title,
    required int index,
    required String? code,
  }) {
    final normalizedTitle = stableSlug(title.toLowerCase());
    final normalizedCode = code == null || code.trim().isEmpty
        ? 'SEC_$index'
        : stableSlug(code.toLowerCase());
    return '${normalizedCode}_$normalizedTitle';
  }

  String? _directChildText(XmlElement element, String childName) {
    for (final child in element.children.whereType<XmlElement>()) {
      if (child.name.local != childName) continue;
      final text = child.innerText.trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  String _inferReleaseType(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('extended') || lower.contains('er')) {
      return 'extended_release';
    }
    if (lower.contains('patch')) return 'continuous';
    return 'immediate_release';
  }

  String _buildInteractionSummary(Map<String, String> sections) {
    final parts = <String>[];
    if ((sections['food_effect'] ?? '').isNotEmpty) {
      parts.add('food-effect section present');
    }
    if ((sections['iron'] ?? '').isNotEmpty) {
      parts.add('iron interaction text present');
    }
    if ((sections['tyramine'] ?? '').isNotEmpty) {
      parts.add('tyramine warning text present');
    }
    if ((sections['thickener'] ?? '').isNotEmpty) {
      parts.add('thickener compatibility text present');
    }
    if ((sections['enteral_feed'] ?? '').isNotEmpty) {
      parts.add('enteral feeding text present');
    }
    return parts.join('; ');
  }

  List<Map<String, dynamic>> _extractStructuredLabelFacts(
      List<_SplSectionEntry> allSections) {
    final facts = <Map<String, dynamic>>[];
    final seenTypes = <String>{};

    void addFact({
      required String factType,
      required String label,
      required _SplSectionEntry section,
      String? valueText,
      Map<String, dynamic> payload = const <String, dynamic>{},
    }) {
      if (!seenTypes.add(factType)) return;
      facts.add({
        'fact_type': factType,
        'label': label,
        'value_text': valueText,
        'source_section_key': section.key,
        'source_section_title': section.title,
        'source_excerpt': _shortExcerpt(section.text),
        'payload': payload,
      });
    }

    for (final section in allSections) {
      final lower = '${section.title} ${section.text}'.toLowerCase();

      if (lower.contains('with or without food')) {
        addFact(
          factType: 'with_or_without_food',
          label: 'May be taken with or without food',
          section: section,
        );
      }

      final beforeAfterMatch = RegExp(
        r'at least\s+(\d+)\s*(hour|hours|hr|hrs|minute|minutes|min|mins)\s+before.*?at least\s+(\d+)\s*(hour|hours|hr|hrs|minute|minutes|min|mins)\s+after',
        dotAll: true,
      ).firstMatch(lower);
      if (beforeAfterMatch != null) {
        final beforeAmount = int.tryParse(beforeAfterMatch.group(1) ?? '');
        final beforeUnit = beforeAfterMatch.group(2) ?? '';
        final afterAmount = int.tryParse(beforeAfterMatch.group(3) ?? '');
        final afterUnit = beforeAfterMatch.group(4) ?? '';
        final beforeMinutes = _normalizeToMinutes(beforeAmount, beforeUnit);
        final afterMinutes = _normalizeToMinutes(afterAmount, afterUnit);
        addFact(
          factType: 'meal_window_before_after',
          label: 'Meal timing window',
          section: section,
          valueText:
              '$beforeMinutes min before meal / $afterMinutes min after meal',
          payload: {
            'before_minutes': beforeMinutes,
            'after_minutes': afterMinutes,
          },
        );
      }

      if (lower.contains('high protein') &&
          (lower.contains('delay') ||
              lower.contains('decrease') ||
              lower.contains('reduce') ||
              lower.contains('absorption') ||
              lower.contains('response'))) {
        addFact(
          factType: 'high_protein_effect',
          label: 'High protein may affect absorption or response',
          section: section,
        );
      }

      final highFatDelayMatch = RegExp(
        r'high[\s-]fat.*?(delay|delays|delayed).*?(\d+(?:\.\d+)?)\s*(hour|hours|hr|hrs)',
        dotAll: true,
      ).firstMatch(lower);
      if (highFatDelayMatch != null) {
        final hours = double.tryParse(highFatDelayMatch.group(2) ?? '');
        addFact(
          factType: 'high_fat_delay',
          label: 'High-fat or high-calorie meal may delay onset/absorption',
          section: section,
          valueText: hours == null ? null : '${hours.toString()} hours delay',
          payload: {
            if (hours != null) 'delay_hours': hours,
          },
        );
      }

      if (lower.contains('iron') &&
          (lower.contains('chelat') ||
              lower.contains('bioavailability') ||
              lower.contains('absorption') ||
              lower.contains('multivitamin'))) {
        addFact(
          factType: 'iron_interaction_warning',
          label: 'Iron-containing products may interfere with absorption',
          section: section,
        );
      }

      final tyramineThresholdMatch = RegExp(
        r'(\d+)\s*mg[^.]{0,80}tyramine|tyramine[^.]{0,80}(\d+)\s*mg',
        dotAll: true,
      ).firstMatch(lower);
      if (tyramineThresholdMatch != null) {
        final mg = int.tryParse(
          tyramineThresholdMatch.group(1) ??
              tyramineThresholdMatch.group(2) ??
              '',
        );
        addFact(
          factType: 'tyramine_threshold',
          label: 'Very high tyramine threshold warning',
          section: section,
          valueText: mg == null ? null : '$mg mg tyramine threshold',
          payload: {
            if (mg != null) 'threshold_mg': mg,
          },
        );
      }

      if (lower.contains('starch-based thickener') ||
          (lower.contains('thickener') && lower.contains('starch based'))) {
        addFact(
          factType: 'starch_thickener_incompatibility',
          label: 'Do not mix with starch-based thickener',
          section: section,
        );
      }

      if ((lower.contains('enteral') || lower.contains('tube feeding')) &&
          (lower.contains('levodopa') ||
              lower.contains('protein') ||
              lower.contains('feeding'))) {
        addFact(
          factType: 'enteral_feed_review',
          label: 'Enteral feeding requires review',
          section: section,
        );
      }
    }
    return facts;
  }

  int _normalizeToMinutes(int? amount, String unit) {
    final safeAmount = amount ?? 0;
    final normalized = unit.toLowerCase();
    if (normalized.startsWith('hour') || normalized.startsWith('hr')) {
      return safeAmount * 60;
    }
    return safeAmount;
  }

  String _shortExcerpt(String text) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 220) return normalized;
    return '${normalized.substring(0, 220)}...';
  }
}

class _SplSectionEntry {
  final String key;
  final String title;
  final String text;
  final int ordinal;
  final String? rawCode;

  const _SplSectionEntry({
    required this.key,
    required this.title,
    required this.text,
    required this.ordinal,
    required this.rawCode,
  });
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
