import '../../../core/models/drug_definition.dart';
import '../../../domain/entities/cdss_records.dart';
import 'crosswalk_builders.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';
import 'p0_source_urls.dart';
import 'source_fetch_client.dart';

/// PMDA P1 importer:
/// - 先做日文主站与英文参考页的元数据导入；
/// - 英文译本统一标记 reference_only；
/// - 不把当前实现伪装成完整日文电子添文结构化导出。
class PmdaP1Importer {
  final SourceFetchClient fetchClient;

  const PmdaP1Importer({required this.fetchClient});

  Future<P0ImportBundle> fetchEnglishReferenceIndex() async {
    final html =
        await fetchClient.getText(P0SourceUrls.pmdaEnglishPackageInsertIndex);
    return importEnglishReferenceIndex(html);
  }

  Future<P0ImportBundle> fetchJapaneseSearchLanding() async {
    final html =
        await fetchClient.getText(P0SourceUrls.pmdaJapaneseMedicalSearch);
    return importJapaneseSearchLanding(html);
  }

  P0ImportBundle importEnglishReferenceIndex(String html) {
    final title = _extractTitle(html,
        fallback: 'PMDA English-translated package inserts');
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'PMDA',
      externalKey: 'english_reference_index',
    );
    final links = _extractLinks(html, baseUrl: 'https://www.pmda.go.jp');
    final referenceCrosswalks = <ConceptVariantCrosswalkRecord>[
      for (final link in links)
        buildCrosswalk(
          domain: 'drug',
          conceptId: 'DRUG_PMDA_REFERENCE_INDEX',
          variantId: 'pmda_reference_index',
          externalIdSystem: 'PMDA English package insert URL',
          externalIdValue: link.url,
          jurisdiction: 'JP',
          sourceDocId: sourceDocId,
          confidence: 0.5,
          status: 'reference_only',
          mappingPayload: {
            'caption': link.caption,
            'reason':
                'English translation indexed for cross-reference; Japanese original is authoritative.',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypeReferenceTranslationUrl,
              reason:
                  'English translated insert URL is official but reference-only; Japanese product detail remains authoritative.',
              promotedFields: const ['english_reference_url'],
              nonPromotedFields: const ['route', 'dosage_form'],
              promotionDecision: 'reference_only_no_structured_drug_variant',
            ),
          },
        ),
    ];

    return P0ImportBundle(
      sourceDocuments: [
        buildSourceDocumentRecord(
          sourceDocId: sourceDocId,
          sourceFamily: 'PMDA',
          organization: 'Pharmaceuticals and Medical Devices Agency',
          jurisdiction: 'JP',
          docType: 'english_reference_index',
          title: title,
          originUrl: P0SourceUrls.pmdaEnglishPackageInsertIndex,
          licenseNote:
              'English translation reference only; Japanese original prevails.',
          language: 'en',
          sourceStatus: 'reference_only',
          dataTier: KnowledgeDataTier.p1,
          ingestionStrategy: SourceIngestionStrategy.officialReference,
          rawPayload: html,
        ),
      ],
      drugProductMedias: links
          .map(
            (link) => DrugProductMediaRecord(
              mediaId: 'media_${stableHash('$sourceDocId:${link.url}')}',
              drugProductVariantId: 'pmda_reference_index',
              sourceDocId: sourceDocId,
              mediaType:
                  link.url.toLowerCase().endsWith('.pdf') ? 'pdf' : 'html',
              mediaUrl: link.url,
              caption: link.caption,
            ),
          )
          .toList(growable: false),
      conceptVariantCrosswalks: referenceCrosswalks,
    );
  }

  P0ImportBundle importJapaneseSearchLanding(String html) {
    final title = _extractTitle(html, fallback: 'PMDA 医療用医薬品 添付文書等情報検索');
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'PMDA',
      externalKey: 'japanese_search_landing',
    );
    return P0ImportBundle(
      sourceDocuments: [
        buildSourceDocumentRecord(
          sourceDocId: sourceDocId,
          sourceFamily: 'PMDA',
          organization: 'Pharmaceuticals and Medical Devices Agency',
          jurisdiction: 'JP',
          docType: 'japanese_search_landing',
          title: title,
          originUrl: P0SourceUrls.pmdaJapaneseMedicalSearch,
          licenseNote: 'Japanese original PMDA search landing metadata.',
          language: 'ja',
          sourceStatus: 'active',
          dataTier: KnowledgeDataTier.p1,
          ingestionStrategy: SourceIngestionStrategy.authoritativeDirect,
          rawPayload: html,
        ),
      ],
    );
  }

  P0ImportBundle importJapaneseProductDetail({
    required String detailUrl,
    required String html,
  }) {
    final title = _extractTitle(html, fallback: 'PMDA product detail');
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'PMDA',
      externalKey: stableSlug(detailUrl),
    );
    final links = _extractLinks(html, baseUrl: 'https://www.pmda.go.jp');
    final productCode = _extractProductCode(detailUrl, html);
    final genericName = _extractProductName(html, fallback: title);
    final conceptId = buildDrugConceptId(genericName);
    final variantId = buildDrugVariantId(
      conceptId: conceptId,
      jurisdiction: 'JP',
      sourceSystem: 'PMDA',
      externalProductCode: productCode,
    );
    final tag = inferDrugTag(genericName);

    return P0ImportBundle(
      sourceDocuments: [
        buildSourceDocumentRecord(
          sourceDocId: sourceDocId,
          sourceFamily: 'PMDA',
          organization: 'Pharmaceuticals and Medical Devices Agency',
          jurisdiction: 'JP',
          docType: 'japanese_product_detail',
          title: title,
          originUrl: detailUrl,
          licenseNote: 'Japanese original PMDA product detail metadata.',
          language: 'ja',
          sourceStatus: 'active',
          dataTier: KnowledgeDataTier.p1,
          ingestionStrategy: SourceIngestionStrategy.authoritativeDirect,
          rawPayload: html,
        ),
      ],
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
          jurisdiction: 'JP',
          regulator: 'PMDA',
          externalProductCode: productCode,
          route: 'unspecified',
          dosageForm: 'unspecified',
          releaseType: 'unspecified',
          labelVersion: 'pmda_metadata',
          sourceStatus: 'imported_pmda_metadata',
        ),
      ],
      drugLabelSections: [
        DrugLabelSectionRecord(
          sectionId: 'section_${stableHash('$variantId:pmda_metadata')}',
          drugProductVariantId: variantId,
          sourceDocId: sourceDocId,
          sectionKey: 'pmda_document_inventory',
          sectionTitle: 'PMDA document inventory',
          sectionText:
              links.map((item) => '${item.caption}: ${item.url}').join(' | '),
        ),
      ],
      drugProductMedias: links
          .map(
            (link) => DrugProductMediaRecord(
              mediaId: 'media_${stableHash('$variantId:${link.url}')}',
              drugProductVariantId: variantId,
              sourceDocId: sourceDocId,
              mediaType:
                  link.url.toLowerCase().endsWith('.pdf') ? 'pdf' : 'html',
              mediaUrl: link.url,
              caption: link.caption,
            ),
          )
          .toList(growable: false),
      conceptVariantCrosswalks: [
        buildCrosswalk(
          domain: 'drug',
          conceptId: conceptId,
          variantId: variantId,
          externalIdSystem: 'PMDA Japanese product code',
          externalIdValue: productCode,
          jurisdiction: 'JP',
          sourceDocId: sourceDocId,
          confidence: 1.0,
          mappingPayload: {
            'detail_url': detailUrl,
            'language': 'ja',
            'authoritative': true,
            'route': 'unspecified',
            'dosage_form': 'unspecified',
            'route_dosage_audit_note':
                'PMDA Japanese product detail landing does not expose machine-readable route/dosage_form; values left as "unspecified" rather than guessed.',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypeAuthoritativeProductCode,
              reason:
                  'Product code derived from /GeneralList/{code} URL segment; this is the authoritative identifier.',
              promotionDecision:
                  'authoritative_product_code_promoted_route_dosage_left_unspecified',
              parserLimitation:
                  'Importer does not OCR linked package-insert PDFs to recover route/dosage_form structurally.',
            ),
          },
        ),
        buildCrosswalk(
          domain: 'drug',
          conceptId: conceptId,
          variantId: variantId,
          externalIdSystem: 'PMDA detail URL',
          externalIdValue: detailUrl,
          jurisdiction: 'JP',
          sourceDocId: sourceDocId,
          confidence: 0.9,
          mappingPayload: {
            'language': 'ja',
            'kind': 'iyaku_detail_landing',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypeRegulatorMetadataUrl,
              reason:
                  'PMDA Japanese product detail URL is the authoritative landing page for this product code.',
              promotedFields: const ['detail_url'],
              nonPromotedFields: const ['route', 'dosage_form'],
              parserLimitation:
                  'Route and dosage form are left unspecified unless machine-readable fields are present.',
            ),
          },
        ),
        for (final link in links)
          buildCrosswalk(
            domain: link.url.toLowerCase().endsWith('.pdf')
                ? 'drug_monograph'
                : 'drug_media',
            conceptId: conceptId,
            variantId: variantId,
            externalIdSystem: 'PMDA Japanese document URL',
            externalIdValue: link.url,
            jurisdiction: 'JP',
            sourceDocId: sourceDocId,
            confidence: 0.85,
            mappingPayload: {
              'caption': link.caption,
              'language': 'ja',
              'authoritative': true,
              'kind': link.url.toLowerCase().endsWith('.pdf')
                  ? 'package_insert_or_supporting_pdf'
                  : 'related_html',
              ...ImporterAudit.confidenceReason(
                sourceIdentifierType:
                    ImporterAudit.sourceIdTypeRegulatorDocumentUrl,
                reason:
                    'Japanese document URL and caption extracted from PMDA detail HTML.',
                promotedFields: const ['document_url', 'caption'],
                nonPromotedFields: const ['document_body'],
                parserLimitation:
                    'Linked Japanese document bodies are not parsed in this metadata importer.',
              ),
            },
          ),
      ],
      projectedDrugs: [
        DrugDefinition(
          id: 'drug_pmda_${stableSlug(genericName.toLowerCase())}_$productCode',
          genericName: genericName,
          brandNames: [title],
          aliases: [productCode],
          tags: [if (tag != null) tag],
          notes: 'Imported from PMDA Japanese product metadata.',
          interactionSummary:
              'PMDA metadata imported. Japanese original source is primary; English translation remains reference-only.',
          sourceSystem: 'PMDA',
          sourceProductCode: productCode,
          jurisdiction: 'JP',
          route: 'unspecified',
          dosageForm: 'unspecified',
          releaseType: 'unspecified',
        ),
      ],
    );
  }

  String _extractTitle(String html, {required String fallback}) {
    final match =
        RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true)
            .firstMatch(html);
    final value = match?.group(1)?.replaceAll(RegExp(r'\s+'), ' ').trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  String _extractProductCode(String detailUrl, String html) {
    final fromUrl =
        RegExp(r'/GeneralList/([^/?#]+)').firstMatch(detailUrl)?.group(1);
    if (fromUrl != null && fromUrl.isNotEmpty) return fromUrl;
    // 使用普通字符串避免 raw string 下无法安全表达单引号字符类的问题。
    final fromHtml =
        RegExp('GeneralList/([^"\\\'<>\\s]+)').firstMatch(html)?.group(1);
    return (fromHtml != null && fromHtml.isNotEmpty)
        ? fromHtml
        : stableSlug(detailUrl);
  }

  String _extractProductName(String html, {required String fallback}) {
    final h1 =
        RegExp(r'<h1[^>]*>(.*?)</h1>', caseSensitive: false, dotAll: true)
            .firstMatch(html)
            ?.group(1)
            ?.replaceAll(RegExp(r'<[^>]+>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
    return (h1 == null || h1.isEmpty) ? fallback : h1;
  }

  List<_PmdaLink> _extractLinks(String html, {required String baseUrl}) {
    final links = <_PmdaLink>[];
    final exp = RegExp(
      r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in exp.allMatches(html)) {
      final href = match.group(1)?.trim() ?? '';
      final caption = (match.group(2) ?? '')
          .replaceAll(RegExp(r'<[^>]+>'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (href.isEmpty || caption.isEmpty) continue;
      if (!(caption.contains('添付文書') ||
          caption.contains('患者向医薬品ガイド') ||
          caption.contains('インタビューフォーム') ||
          caption.contains('RMP') ||
          caption.contains('審査報告書') ||
          caption.toLowerCase().contains('package insert') ||
          caption.toLowerCase().contains('translated'))) {
        continue;
      }
      final url = href.startsWith('http')
          ? href
          : href.startsWith('/')
              ? '$baseUrl$href'
              : '$baseUrl/$href';
      links.add(_PmdaLink(url: url, caption: caption));
    }
    return links;
  }
}

class _PmdaLink {
  final String url;
  final String caption;

  const _PmdaLink({
    required this.url,
    required this.caption,
  });
}
