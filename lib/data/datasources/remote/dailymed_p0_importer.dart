import 'dart:convert';

import 'package:crypto/crypto.dart';
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
  static const int maxSplXmlCharacters = 16 * 1024 * 1024;
  // FDA SPL active ingredient roles are an enumeration, not an ACTI prefix.
  static const _activeIngredientClasses = {'ACTIB', 'ACTIM', 'ACTIR'};
  final SourceFetchClient fetchClient;

  const DailyMedP0Importer({required this.fetchClient});

  Future<P0ImportBundle> fetchBySetIds(List<String> setIds) async {
    P0ImportBundle bundle = const P0ImportBundle();
    for (final rawSetId in setIds) {
      // Set ids come from config/upstream indexes; encode them so a malformed
      // value cannot alter the request path.
      final setId = Uri.encodeComponent(rawSetId);
      final xml = await fetchClient.getText(
        '${P0SourceUrls.dailymedSplXmlBase}/$setId.xml',
      );
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
    validateSplXmlLength(xml.length);
    final document = XmlDocument.parse(xml);
    final products = _structuredProducts(document);
    if (products.isNotEmpty) {
      return _importStructuredProducts(
        xml,
        document,
        products,
        ndcs: ndcs,
        packaging: packaging,
        media: media,
      );
    }
    if (_declaresUnresolvedProductStructure(document)) {
      // ignore: avoid_print
      print('[DailyMed] SPL unresolved product structure; promoted_products=0');
      final held = _importDocument(
        document,
        sourceXml: xml,
        identityHeld: true,
      );
      final source = held.sourceDocuments.single;
      final payload =
          Map<String, dynamic>.from(jsonDecode(source.rawPayload) as Map)
            ..addAll({
              'product_scope_schema': 'spl-product-scope/1',
              'product_count': 0,
              'product_scopes': <String, Object?>{},
              'identity_status': 'hold_no_resolved_products',
              'active_ingredient_details': <Object?>[],
              'label_facts': <Object?>[],
            });
      return P0ImportBundle(
        sourceDocuments: [
          buildSourceDocumentRecord(
            sourceDocId: source.sourceDocId,
            sourceFamily: source.sourceFamily,
            organization: source.organization,
            jurisdiction: source.jurisdiction,
            docType: source.docType,
            title: source.title,
            originUrl: source.originUrl,
            licenseNote: source.licenseNote,
            language: source.language,
            effectiveAt: source.effectiveAt,
            sourceStatus: 'hold_no_resolved_products',
            rawPayload: stringifyPayload(payload),
          ),
        ],
      );
    }
    return _importDocument(
      document,
      sourceXml: xml,
      ndcs: ndcs,
      packaging: packaging,
      media: media,
    );
  }

  P0ImportBundle _importDocument(
    XmlDocument document, {
    required String sourceXml,
    List<Map<String, dynamic>> ndcs = const [],
    List<Map<String, dynamic>> packaging = const [],
    List<Map<String, dynamic>> media = const [],
    String? productCode,
    String? productName,
    bool identityHeld = false,
    List<_SplSectionEntry>? scopedSections,
    List<_SplSectionEntry>? factSections,
  }) {
    final root = document.rootElement;
    String? documentAttribute(String name, String attribute) => root.children
        .whereType<XmlElement>()
        .where((element) => element.name.local == name)
        .firstOrNull
        ?.getAttribute(attribute);
    final documentId = documentAttribute('id', 'root');
    final versionNumber = documentAttribute('versionNumber', 'value');
    final effectiveTime = documentAttribute('effectiveTime', 'value');
    final contentSha256 = sha256.convert(utf8.encode(sourceXml)).toString();
    final setId =
        documentAttribute('setId', 'root') ?? documentId ?? 'UNSPECIFIED_SETID';
    final title = _firstText(document, 'title') ?? 'DailyMed SPL';
    final ingredientNames = _ingredientNames(document);
    final genericName = ingredientNames.isEmpty
        ? (productName ?? title)
        : ingredientNames.join('/');
    final conceptId = buildDrugConceptId(genericName);
    final externalProductCode = productCode ?? setId;
    final variantId = buildDrugVariantId(
      conceptId: conceptId,
      jurisdiction: 'US',
      sourceSystem: 'DAILYMED',
      externalProductCode: externalProductCode,
    );
    // A missing SPL route is not evidence of oral administration. Keep the
    // metadata unknown so the runtime applicability gate abstains instead of
    // authorizing an oral-only model from the product title alone.
    final routes = _uniqueCodeDisplayNames(document, 'routeCode');
    final dosageForms = _uniqueCodeDisplayNames(document, 'formCode');
    final route = !identityHeld && routes.length == 1
        ? routes.single
        : 'unspecified';
    final dosageForm = !identityHeld && dosageForms.length == 1
        ? dosageForms.single
        : 'unspecified';
    final releaseType = identityHeld
        ? 'unknown'
        : _inferReleaseType(
            productCode == null ? title : dosageForms.join(' '),
          );
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'DAILYMED',
      externalKey: '$setId:$contentSha256',
    );
    final allSections = scopedSections ?? _extractAllSections(document);
    final applicableSections = factSections ?? allSections;
    final sectionSummaries = _extractRelevantSections(applicableSections);
    final labelFacts = _extractStructuredLabelFacts(applicableSections);
    final summaryText = sectionSummaries.values
        .where((value) => value.trim().isNotEmpty)
        .join(' ');
    final labelSections = <DrugLabelSectionRecord>[];
    final labelSectionLocators = <String, _SplSectionEntry>{};
    for (final section in allSections) {
      if (section.text.trim().isEmpty) continue;
      final record = DrugLabelSectionRecord(
        sectionId:
            'section_${stableHash('$sourceDocId:$variantId:${section.key}')}',
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
      effectiveAt: _splEffectiveDate(effectiveTime),
      rawPayload: stringifyPayload({
        'setid': setId,
        'document_id': documentId,
        'version_number': versionNumber,
        'effective_time': effectiveTime,
        'spl_xml_sha256': contentSha256,
        'identity_status': documentAttribute('setId', 'root') == null
            ? 'set_id_missing_document_id_fallback'
            : 'set_id_present',
        'routes': routes,
        'dosage_forms': dosageForms,
        'active_ingredient_details': _activeIngredientDetails(document),
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
                  (row) => '${row['package_description'] ?? ''}'.isNotEmpty,
                )
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
      id: 'drug_dailymed_${stableSlug(genericName.toLowerCase())}_$externalProductCode',
      genericName: genericName,
      brandNames: [productName ?? title],
      aliases: ingredientNames,
      tags: [?tag],
      notes: summaryText.isEmpty ? title : summaryText,
      interactionSummary: _buildInteractionSummary(sectionSummaries),
      sourceSystem: 'DAILYMED',
      sourceProductCode: externalProductCode,
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
        appEntityId: externalProductCode,
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
              reason: productCode == code.codeValue
                  ? 'Product NDC taken verbatim from the direct SPL product code.'
                  : 'NDC value taken verbatim from matched DailyMed ndcs.json.',
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
          externalProductCode: externalProductCode,
          route: route,
          dosageForm: dosageForm,
          releaseType: releaseType,
          labelVersion: versionNumber == null
              ? 'spl_version_unknown'
              : 'spl_version_$versionNumber',
          sourceStatus: identityHeld ? 'hold_product_identity' : 'imported_spl',
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

  // FDA SPL product data (LOINC 48780-1) has direct subject/product wrappers.
  // Descendant manufacturedProduct/package nodes are not additional products.
  bool _declaresUnresolvedProductStructure(XmlDocument document) {
    // This is a rejection detector, not a permissive product parser. A foreign
    // namespace/code system must never bypass the strict parser into the
    // document-wide legacy path merely because it cannot be resolved.
    var productSubjects = 0;
    for (final element in document.descendants.whereType<XmlElement>()) {
      if (element.name.local == 'section' &&
          element.childElements.any(
            (child) =>
                child.name.local == 'code' &&
                child.getAttribute('code') == '48780-1',
          )) {
        return true;
      }
      if (element.name.local == 'subject' &&
          element.childElements.any(
            (wrapper) =>
                wrapper.name.local == 'manufacturedProduct' &&
                wrapper.childElements.any(
                  (core) => core.name.local == 'manufacturedProduct',
                ),
          )) {
        productSubjects++;
        if (productSubjects > 1) {
          return true;
        }
      }
    }
    return false;
  }

  bool _isProductDataSection(XmlElement section) {
    if (section.name.local != 'section' ||
        (section.namespaceUri != null &&
            section.namespaceUri != 'urn:hl7-org:v3')) {
      return false;
    }
    final code = _splChild(section, 'code');
    return code?.getAttribute('code') == '48780-1' &&
        code?.getAttribute('codeSystem') == '2.16.840.1.113883.6.1';
  }

  List<_SplProductScope> _structuredProducts(XmlDocument document) {
    final namespace = document.rootElement.namespaceUri;
    if (document.rootElement.name.local != 'document' ||
        (namespace != null && namespace != 'urn:hl7-org:v3')) {
      return const [];
    }
    final products = <_SplProductScope>[];
    for (final section in document.descendants.whereType<XmlElement>()) {
      if (section.name.local != 'section' ||
          section.namespaceUri != namespace) {
        continue;
      }
      if (!_isProductDataSection(section)) continue;
      for (final subject in _splChildren(section, 'subject')) {
        final wrapper = _splChild(subject, 'manufacturedProduct');
        final product = wrapper == null
            ? null
            : _splChild(wrapper, 'manufacturedProduct');
        if (wrapper == null || product == null) {
          products.add(
            _SplProductScope(
              wrapper: wrapper ?? subject,
              product: XmlElement(XmlName.parts('manufacturedProduct')),
              code: null,
              name: '',
            ),
          );
          continue;
        }
        final productCode = _splChild(product, 'code');
        final ndc = productCode?.getAttribute('code')?.trim();
        final codeSystem = productCode?.getAttribute('codeSystem');
        products.add(
          _SplProductScope(
            wrapper: wrapper,
            product: product,
            code:
                codeSystem == '2.16.840.1.113883.6.69' &&
                    ndc != null &&
                    RegExp(r'^\d{4,5}-\d{3,4}$').hasMatch(ndc)
                ? ndc
                : null,
            name: _splChild(product, 'name')?.innerText.trim() ?? '',
          ),
        );
      }
    }
    return products;
  }

  Iterable<XmlElement> _splChildren(XmlElement element, String name) =>
      element.children.whereType<XmlElement>().where(
        (child) =>
            child.name.local == name &&
            child.namespaceUri == element.namespaceUri,
      );

  XmlElement? _splChild(XmlElement element, String name) =>
      _splChildren(element, name).firstOrNull;

  XmlElement _localCopy(XmlElement element) => XmlElement(
    XmlName.parts(element.name.local),
    [
      for (final attribute in element.attributes)
        if (attribute.name.prefix == null && attribute.name.local != 'xmlns')
          XmlAttribute(XmlName.parts(attribute.name.local), attribute.value),
    ],
    [
      for (final child in element.children)
        if (child is XmlElement && child.namespaceUri == element.namespaceUri)
          _localCopy(child)
        else if (child is XmlText)
          XmlText(child.value),
    ],
  );

  P0ImportBundle _importStructuredProducts(
    String xml,
    XmlDocument document,
    List<_SplProductScope> products, {
    required List<Map<String, dynamic>> ndcs,
    required List<Map<String, dynamic>> packaging,
    required List<Map<String, dynamic>> media,
  }) {
    final setId =
        _splChild(document.rootElement, 'setId')?.getAttribute('root') ??
        _splChild(document.rootElement, 'id')?.getAttribute('root') ??
        'UNSPECIFIED_SETID';
    final entries = <_SplSectionEntry>[];
    final owners = <String, _SplProductScope?>{};
    var ordinal = 0;
    for (final node in document.descendants.whereType<XmlElement>()) {
      if (node.name.local != 'section' ||
          node.namespaceUri != document.rootElement.namespaceUri) {
        continue;
      }
      final text = _splChild(node, 'text')?.innerText.trim() ?? '';
      final title =
          _splChild(node, 'title')?.innerText.trim() ??
          'Section ${ordinal + 1}';
      final code =
          _splChild(node, 'code')?.getAttribute('code') ??
          node.getAttribute('ID');
      final entry = _SplSectionEntry(
        key:
            '${_buildSectionKey(title: title, index: ordinal, code: code)}_SPL_$ordinal',
        title: title,
        text: text,
        ordinal: ordinal++,
        rawCode: code,
      );
      // Never fold child sections into a parent's text.
      if (text.isEmpty) {
        continue;
      }
      _SplProductScope? owner;
      var parent = node.parent;
      while (parent != null) {
        owner = products
            .where((product) => identical(product.wrapper, parent))
            .firstOrNull;
        if (owner != null) break;
        parent = parent.parent;
      }
      entries.add(entry);
      owners[entry.key] = owner;
    }
    var merged = const P0ImportBundle();
    final scopes = <String, Object?>{};
    final usedNdcs = <Map<String, dynamic>>{};
    final usedPackaging = <Map<String, dynamic>>{};
    final usedMedia = <Map<String, dynamic>>{};
    final productDataSectionCount = document.descendants
        .whereType<XmlElement>()
        .where(_isProductDataSection)
        .length;
    for (var index = 0; index < products.length; index++) {
      final product = products[index];
      final ingredients = _splChildren(product.product, 'ingredient').toList();
      final activeIngredients = ingredients
          .where(
            (ingredient) => _activeIngredientClasses.contains(
              ingredient.getAttribute('classCode'),
            ),
          )
          .toList();
      final evidenceReasons = <String>[
        if (productDataSectionCount != 1)
          'ambiguous_product_data_section_count',
        if (product.code == null) 'product_ndc_missing_or_invalid',
        if (product.code != null &&
            products.where((peer) => peer.code == product.code).length != 1)
          'duplicate_product_ndc',
        if (product.name.isEmpty) 'product_name_missing',
        if (ingredients.any(
          (ingredient) =>
              !_activeIngredientClasses.contains(
                ingredient.getAttribute('classCode'),
              ) &&
              ingredient.getAttribute('classCode') != 'IACT',
        ))
          'ingredient_class_missing_or_unsupported',
        if (activeIngredients.isEmpty ||
            activeIngredients.any(
              (ingredient) =>
                  (_splChild(
                            _splChild(ingredient, 'ingredientSubstance') ??
                                ingredient,
                            'name',
                          )?.innerText.trim() ??
                          '')
                      .isEmpty,
            ))
          'active_ingredient_identity_missing',
      ];
      final held = evidenceReasons.isNotEmpty;
      final identity = held
          ? '$setId:unresolved_product_$index'
          : product.code!;
      bool matches(Map<String, dynamic> row) {
        if (held) return false;
        final value =
            '${row['product_ndc'] ?? row['product_code'] ?? row['ndc'] ?? row['ndc11'] ?? row['package_ndc'] ?? ''}';
        return value == product.code ||
            (RegExp(r'^\d{4,5}-\d{3,4}-\d{1,2}$').hasMatch(value) &&
                value.substring(0, value.lastIndexOf('-')) == product.code);
      }

      final productNdcs = <Map<String, dynamic>>[
        if (!held) {'ndc': product.code},
        ...ndcs
            .where(matches)
            .where(
              (row) =>
                  '${row['ndc'] ?? row['ndc11'] ?? row['package_ndc'] ?? ''}' !=
                  product.code,
            ),
      ];
      final productPackaging = packaging.where(matches).toList();
      final productMedia = media.where(matches).toList();
      usedNdcs.addAll(productNdcs);
      usedPackaging.addAll(productPackaging);
      usedMedia.addAll(productMedia);
      final localChildren = <XmlNode>[
        for (final child
            in document.rootElement.children.whereType<XmlElement>())
          if (const {
                'id',
                'setId',
                'versionNumber',
                'effectiveTime',
                'title',
              }.contains(child.name.local) &&
              child.namespaceUri == document.rootElement.namespaceUri)
            _localCopy(child),
        for (final child in product.product.children.whereType<XmlElement>())
          if (const {'ingredient', 'formCode'}.contains(child.name.local) &&
              child.namespaceUri == product.product.namespaceUri &&
              (child.name.local != 'ingredient' ||
                  _activeIngredientClasses.contains(
                    child.getAttribute('classCode'),
                  )))
            _localCopy(child),
        for (final consumed in _splChildren(product.wrapper, 'consumedIn'))
          for (final administration in _splChildren(
            consumed,
            'substanceAdministration',
          ))
            for (final route in _splChildren(administration, 'routeCode'))
              _localCopy(route),
      ];
      final selectedEntries = entries
          .where(
            (entry) =>
                owners[entry.key] == null ||
                identical(owners[entry.key], product),
          )
          .toList();
      final explicitEntries = held
          ? <_SplSectionEntry>[]
          : entries
                .where((entry) => identical(owners[entry.key], product))
                .toList();
      final bundle = _importDocument(
        XmlDocument([XmlElement(XmlName.parts('document'), [], localChildren)]),
        sourceXml: xml,
        productCode: identity,
        productName: product.name,
        identityHeld: held,
        scopedSections: selectedEntries,
        factSections: explicitEntries,
        ndcs: productNdcs,
        packaging: productPackaging,
        media: productMedia,
      );
      final variantId = bundle.drugProductVariants.single.drugProductVariantId;
      final payload =
          jsonDecode(bundle.sourceDocuments.single.rawPayload) as Map;
      scopes[variantId] = {
        'product_ordinal': index,
        'product_code': product.code,
        'product_code_system': '2.16.840.1.113883.6.69',
        'hold_reasons': evidenceReasons,
        'identity_status': held
            ? 'hold_product_identity'
            : 'resolved_product_scope',
        'product_name': product.name,
        'routes': payload['routes'],
        'dosage_forms': payload['dosage_forms'],
        'route_code_details': [
          for (final consumed in _splChildren(product.wrapper, 'consumedIn'))
            for (final administration in _splChildren(
              consumed,
              'substanceAdministration',
            ))
              for (final route in _splChildren(administration, 'routeCode'))
                {
                  for (final attribute in route.attributes)
                    attribute.name.local: attribute.value,
                },
        ],
        'dosage_form_code_details': [
          for (final form in _splChildren(product.product, 'formCode'))
            {
              for (final attribute in form.attributes)
                attribute.name.local: attribute.value,
            },
        ],
        'active_ingredient_details': activeIngredients
            .map(_ingredientDetail)
            .toList(growable: false),
        'ingredient_class_audit': [
          for (final ingredient in ingredients)
            {
              ..._ingredientDetail(ingredient),
              'classification':
                  _activeIngredientClasses.contains(
                    ingredient.getAttribute('classCode'),
                  )
                  ? 'active'
                  : ingredient.getAttribute('classCode') == 'IACT'
                  ? 'inactive'
                  : 'unresolved',
              'status': 'source_class_code_only',
            },
        ],
        'label_facts': payload['label_facts'],
        'section_scopes': {
          for (final entry in selectedEntries)
            entry.key: identical(owners[entry.key], product)
                ? 'product_explicit'
                : 'document_shared_unverified',
        },
        'strength_status': 'label_ratio_only_not_administered_dose',
      };
      merged = merged.merge(bundle);
    }
    final base = merged.sourceDocuments.first;
    final payload = Map<String, dynamic>.from(
      jsonDecode(base.rawPayload) as Map,
    );
    payload.addAll({
      'product_scope_schema': 'spl-product-scope/1',
      'product_count': products.length,
      'product_data_section_count': productDataSectionCount,
      'product_scopes': scopes,
      'active_ingredient_details': <Object?>[],
      'ingredients': <Object?>[],
      'routes': <Object?>[],
      'dosage_forms': <Object?>[],
      'label_facts': <Object?>[],
      'sections': <String, Object?>{},
      'section_count': entries.length,
      'section_titles': entries.map((entry) => entry.title).toList(),
      'document_shared_label_facts': _extractStructuredLabelFacts(
        entries.where((entry) => owners[entry.key] == null).toList(),
      ),
      'unassigned_external_metadata': {
        'ndcs': ndcs.where((row) => !usedNdcs.contains(row)).toList(),
        'packaging': packaging
            .where((row) => !usedPackaging.contains(row))
            .toList(),
        'media': media.where((row) => !usedMedia.contains(row)).toList(),
      },
    });
    final source = buildSourceDocumentRecord(
      sourceDocId: base.sourceDocId,
      sourceFamily: base.sourceFamily,
      organization: base.organization,
      jurisdiction: base.jurisdiction,
      docType: base.docType,
      title: base.title,
      originUrl: base.originUrl,
      licenseNote: base.licenseNote,
      language: base.language,
      effectiveAt: base.effectiveAt,
      rawPayload: stringifyPayload(payload),
    );
    final concepts = {
      for (final concept in merged.drugConcepts) concept.drugConceptId: concept,
    };
    // Counts only: public catalog diagnostics, never raw XML or personal data.
    // ignore: avoid_print
    print(
      '[DailyMed] SPL products=${products.length}; held=${merged.drugProductVariants.where((variant) => variant.sourceStatus.startsWith('hold_')).length}',
    );
    return P0ImportBundle(
      sourceDocuments: [source],
      drugConcepts: concepts.values.toList(),
      drugProductVariants: merged.drugProductVariants,
      drugLabelSections: merged.drugLabelSections,
      drugProductCodes: merged.drugProductCodes,
      drugProductPackagings: merged.drugProductPackagings,
      drugProductMedias: merged.drugProductMedias,
      conceptVariantCrosswalks: merged.conceptVariantCrosswalks,
      projectedDrugs: merged.projectedDrugs,
    );
  }

  static void validateSplXmlLength(
    int length, {
    int maxCharacters = maxSplXmlCharacters,
  }) {
    if (length > maxCharacters) {
      throw FormatException(
        'DailyMed SPL XML exceeds the $maxCharacters character limit.',
      );
    }
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

  List<String> _uniqueCodeDisplayNames(XmlDocument document, String tag) =>
      document
          .findAllElements(tag)
          .map((element) => element.getAttribute('displayName')?.trim() ?? '')
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

  DateTime? _splEffectiveDate(String? raw) {
    if (raw == null ||
        !RegExp(r'^\d{8}(?:\d{2}){0,3}(?:[+-]\d{4})?$').hasMatch(raw)) {
      return null;
    }
    final year = int.parse(raw.substring(0, 4));
    final month = int.parse(raw.substring(4, 6));
    final day = int.parse(raw.substring(6, 8));
    final date = DateTime.utc(year, month, day);
    return date.year == year && date.month == month && date.day == day
        ? date
        : null;
  }

  Iterable<XmlElement> _activeIngredients(XmlDocument document) =>
      document.findAllElements('ingredient').where((element) {
        final code = element.getAttribute('classCode');
        // Unclassified flat legacy fixtures retain their existing compatibility
        // path; structured products have the explicit completeness gate above.
        return code == null || _activeIngredientClasses.contains(code);
      });

  List<Map<String, Object?>> _activeIngredientDetails(XmlDocument document) =>
      _activeIngredients(
        document,
      ).map(_ingredientDetail).toList(growable: false);

  Map<String, Object?> _substanceIdentity(XmlElement substance) {
    final codes = _splChildren(substance, 'code').toList();
    final names = _splChildren(substance, 'name').toList();
    return {
      'name': names.length == 1 ? names.single.innerText.trim() : null,
      'substance_code': codes.length == 1
          ? codes.single.getAttribute('code')
          : null,
      'code_system': codes.length == 1
          ? codes.single.getAttribute('codeSystem')
          : null,
    };
  }

  Map<String, Object?> _ingredientDetail(XmlElement ingredient) {
    final substances = _splChildren(ingredient, 'ingredientSubstance').toList();
    final substance = substances.length == 1 ? substances.single : null;
    final identity = _substanceIdentity(substance ?? ingredient);
    final moieties = <Map<String, Object?>>[
      if (substance != null)
        for (final relation in _splChildren(substance, 'activeMoiety'))
          for (final moiety in _splChildren(relation, 'activeMoiety'))
            _substanceIdentity(moiety),
    ];
    final references = <Map<String, Object?>>[
      if (substance != null)
        for (final relation in _splChildren(substance, 'asEquivalentSubstance'))
          for (final reference in _splChildren(relation, 'definingSubstance'))
            _substanceIdentity(reference),
    ];
    Map<String, String> attributes(XmlElement node) => {
      for (final attribute in node.attributes)
        if (attribute.name.prefix == null)
          attribute.name.local: attribute.value,
    };
    final quantities = _splChildren(ingredient, 'quantity').toList();
    final quantity = quantities.length == 1 ? quantities.single : null;
    final numerators = quantity == null
        ? <XmlElement>[]
        : _splChildren(quantity, 'numerator').toList();
    final denominators = quantity == null
        ? <XmlElement>[]
        : _splChildren(quantity, 'denominator').toList();
    final numerator = numerators.length == 1 ? numerators.single : null;
    final denominator = denominators.length == 1 ? denominators.single : null;
    final classCode = ingredient.getAttribute('classCode');
    final basis = switch (classCode) {
      'ACTIB' => 'active_ingredient',
      'ACTIM' => 'active_moiety',
      'ACTIR' => 'reference_ingredient',
      'IACT' => 'not_an_active_ingredient_strength',
      _ => 'unknown_source_class',
    };
    final basisSubstances = switch (classCode) {
      'ACTIB' => [identity],
      'ACTIM' => moieties,
      'ACTIR' => references,
      _ => <Map<String, Object?>>[],
    };
    final codedBasis =
        basisSubstances.length == 1 &&
        '${basisSubstances.single['substance_code'] ?? ''}'.trim().isNotEmpty &&
        '${basisSubstances.single['code_system'] ?? ''}'.trim().isNotEmpty &&
        '${basisSubstances.single['name'] ?? ''}'.trim().isNotEmpty;
    return {
      'class_code': classCode, ...identity,
      'numerator_value': numerator?.getAttribute('value'),
      'numerator_unit': numerator?.getAttribute('unit'),
      'denominator_value': denominator?.getAttribute('value'),
      'denominator_unit': denominator?.getAttribute('unit'),
      'active_moieties': moieties, 'reference_ingredients': references,
      'strength_basis': basis, 'strength_basis_substances': basisSubstances,
      'strength_basis_resolution_status': classCode == 'IACT'
          ? 'not_applicable'
          : codedBasis
          ? 'unique_coded_source_reference'
          : 'missing_or_ambiguous_source_reference',
      'ingredient_substance_count': substances.length,
      'quantity_evidence': [
        for (final row in quantities)
          {
            'numerators': [
              for (final node in _splChildren(row, 'numerator'))
                attributes(node),
            ],
            'denominators': [
              for (final node in _splChildren(row, 'denominator'))
                attributes(node),
            ],
          },
      ],
      // A label ratio and its chemical basis are source evidence. This never
      // produces an administered dose, a mass conversion or an equivalence.
      'promotion_status': 'source_strength_evidence_only',
    };
  }

  List<String> _ingredientNames(XmlDocument document) {
    final names = <String>{};
    for (final node in _activeIngredients(document)) {
      final substance = _splChild(node, 'ingredientSubstance');
      final text = substance == null
          ? _directChildText(node, 'name')
          : _directChildText(substance, 'name');
      if (text != null && text.isNotEmpty) names.add(text);
    }
    return names.toList(growable: false);
  }

  List<_SplSectionEntry> _extractAllSections(XmlDocument document) {
    final sections = <_SplSectionEntry>[];
    var ordinal = 0;
    for (final section in document.findAllElements('section')) {
      final title =
          _directChildText(section, 'title') ?? 'Section ${ordinal + 1}';
      final sectionText =
          _directChildText(section, 'text') ??
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
          section.children
              .whereType<XmlElement>()
              .where((element) => element.name.local == 'code')
              .firstOrNull
              ?.getAttribute('code') ??
          section.getAttribute('ID') ??
          section.getAttribute('code');
      final key = _buildSectionKey(title: title, index: ordinal, code: rawCode);
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
    List<_SplSectionEntry> allSections,
  ) {
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
    if (RegExp(
      r'\b(extended|controlled|sustained|prolonged)[ -]?release\b|\b(er|xr|cr|sr)\b',
    ).hasMatch(lower)) {
      return 'extended_release';
    }
    if (RegExp(r'\bdelayed[ -]?release\b|\bdr\b').hasMatch(lower)) {
      return 'delayed_release';
    }
    if (lower.contains('patch') || lower.contains('continuous')) {
      return 'continuous';
    }
    if (RegExp(r'\bimmediate[ -]?release\b|\bir\b').hasMatch(lower)) {
      return 'immediate_release';
    }
    // A conventional-looking tablet title is not formulation evidence. In
    // particular, never turn absence of release metadata into IR and never use
    // an arbitrary "er" substring match. Unknown must reach the applicability
    // gate as unknown and make the mechanistic provider abstain.
    return 'unknown';
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
    List<_SplSectionEntry> allSections,
  ) {
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
          payload: {'delay_hours': ?hours},
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
          payload: {'threshold_mg': ?mg},
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

class _SplProductScope {
  const _SplProductScope({
    required this.wrapper,
    required this.product,
    required this.code,
    required this.name,
  });
  final XmlElement wrapper;
  final XmlElement product;
  final String? code;
  final String name;
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
