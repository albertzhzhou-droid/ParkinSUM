import '../../../core/models/drug_definition.dart';
import '../../../domain/entities/cdss_records.dart';
import 'archive_import_support.dart';
import 'crosswalk_builders.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';
import 'p0_source_urls.dart';
import 'source_fetch_client.dart';

/// Health Canada DPD 导入器。
///
/// 当前实现：
/// - 支持 `drugproduct / activeingredient / form / route / status` 的 API 组合导入；
/// - 优先构造可用于目录与 cross-jurisdiction variant 的最小结构化视图。
///
/// 当前增强：
/// - 详情页不再只生成一个 `product_info_summary`，而是按标题块拆成多个 section；
/// - 仍然保留“这不是完整 product monograph parser”的边界，不对未稳定结构化的正文过度承诺。
class HealthCanadaDpdP0Importer {
  final SourceFetchClient fetchClient;

  const HealthCanadaDpdP0Importer({required this.fetchClient});

  Future<P0ImportBundle> fetchAndImport() async {
    final drugProducts =
        await fetchClient.getJsonList(P0SourceUrls.dpdDrugProduct);
    final activeIngredients =
        await fetchClient.getJsonList(P0SourceUrls.dpdActiveIngredient);
    final forms = await fetchClient.getJsonList(P0SourceUrls.dpdForm);
    final packaging = await fetchClient.getJsonList(P0SourceUrls.dpdPackaging);
    final routes = await fetchClient.getJsonList(P0SourceUrls.dpdRoute);
    final statuses = await fetchClient.getJsonList(P0SourceUrls.dpdStatus);

    final baseBundle = importFromPayloads(
      drugProducts: drugProducts.cast<Map<String, dynamic>>(),
      activeIngredients: activeIngredients.cast<Map<String, dynamic>>(),
      forms: forms.cast<Map<String, dynamic>>(),
      packaging: packaging.cast<Map<String, dynamic>>(),
      routes: routes.cast<Map<String, dynamic>>(),
      statuses: statuses.cast<Map<String, dynamic>>(),
    );
    return await enrichWithProductDetails(baseBundle);
  }

  /// 兼容 `allfiles*.zip` 这类 DPD 批量包。
  Future<P0ImportBundle> importZipBytes(List<int> zipBytes) async {
    final files = ArchiveImportSupport.unzipTextFiles(zipBytes);
    final drugRows = _loadRows(files, 'drug');
    final ingredientRows = _loadRows(files, 'ingred');
    final formRows = _loadRows(files, 'form');
    final routeRows = _loadRows(files, 'route');
    final statusRows = _loadRows(files, 'status');
    final packageRows = _loadRows(files, 'package');
    final bundle = importFromPayloads(
      drugProducts: drugRows,
      activeIngredients: ingredientRows,
      forms: formRows,
      packaging: packageRows,
      routes: routeRows,
      statuses: statusRows,
    );
    return enrichWithProductDetails(bundle);
  }

  P0ImportBundle importFromPayloads({
    required List<Map<String, dynamic>> drugProducts,
    required List<Map<String, dynamic>> activeIngredients,
    required List<Map<String, dynamic>> forms,
    List<Map<String, dynamic>> packaging = const <Map<String, dynamic>>[],
    required List<Map<String, dynamic>> routes,
    required List<Map<String, dynamic>> statuses,
  }) {
    final formByCode = {
      for (final row in forms)
        '${row['pharmaceutical_form_code'] ?? row['form_code'] ?? ''}':
            '${row['pharmaceutical_form_name'] ?? row['form_name'] ?? ''}',
    };
    final routeByCode = {
      for (final row in routes)
        '${row['route_of_administration_code'] ?? row['route_code'] ?? ''}':
            '${row['route_of_administration_name'] ?? row['route_name'] ?? ''}',
    };
    final statusByCode = {
      for (final row in statuses)
        '${row['drug_status_code'] ?? row['status_code'] ?? ''}':
            '${row['status'] ?? row['drug_status'] ?? ''}',
    };
    final ingredientByDrugCode = <String, List<String>>{};
    for (final row in activeIngredients) {
      final drugCode = '${row['drug_code'] ?? ''}';
      final ingredient =
          '${row['ingredient_name'] ?? row['active_ingredient_name'] ?? ''}'
              .trim();
      if (drugCode.isEmpty || ingredient.isEmpty) continue;
      ingredientByDrugCode
          .putIfAbsent(drugCode, () => <String>[])
          .add(ingredient);
    }

    final sourceDocId = sourceDocumentId(
      sourceSystem: 'HEALTH_CANADA_DPD',
      externalKey: 'dpd_api_snapshot',
    );
    final sourceDocument = buildSourceDocumentRecord(
      sourceDocId: sourceDocId,
      sourceFamily: 'HEALTH_CANADA_DPD',
      organization: 'Health Canada',
      jurisdiction: 'CA',
      docType: 'json_api_snapshot',
      title: 'Health Canada DPD API import',
      originUrl: P0SourceUrls.dpdDrugProduct,
      licenseNote: 'UNSPECIFIED',
      language: 'en',
      rawPayload: stringifyPayload({
        'drug_products': drugProducts.length,
        'active_ingredients': activeIngredients.length,
        'forms': forms.length,
        'packaging': packaging.length,
        'routes': routes.length,
        'statuses': statuses.length,
      }),
    );

    final drugConcepts = <DrugConceptRecord>[];
    final drugVariants = <DrugProductVariantRecord>[];
    final projectedDrugs = <DrugDefinition>[];
    final packagingRecords = <DrugProductPackagingRecord>[];
    final crosswalks = <ConceptVariantCrosswalkRecord>[];
    final conceptIds = <String>{};
    final crosswalkSeen = <String>{};

    for (final row in drugProducts) {
      final drugCode = '${row['drug_code'] ?? ''}'.trim();
      final din =
          '${row['drug_identification_number'] ?? row['din'] ?? ''}'.trim();
      final brandName = '${row['brand_name'] ?? ''}'.trim();
      if (drugCode.isEmpty || brandName.isEmpty) continue;
      final ingredients = ingredientByDrugCode[drugCode] ?? const <String>[];
      final genericName =
          ingredients.isEmpty ? brandName : ingredients.join('/');
      final conceptId = buildDrugConceptId(genericName);
      final variantId = buildDrugVariantId(
        conceptId: conceptId,
        jurisdiction: 'CA',
        sourceSystem: 'HEALTH_CANADA_DPD',
        externalProductCode: din.isEmpty ? drugCode : '$din-$drugCode',
      );
      final formName = formByCode['${row['pharmaceutical_form_code'] ?? ''}'] ??
          'unspecified';
      final routeName =
          routeByCode['${row['route_of_administration_code'] ?? ''}'] ?? 'oral';
      final statusName = statusByCode['${row['drug_status_code'] ?? ''}'] ?? '';

      if (conceptIds.add(conceptId)) {
        final tag = inferDrugTag(genericName);
        drugConcepts.add(
          DrugConceptRecord(
            drugConceptId: conceptId,
            genericName: genericName,
            atcLikeCode: tag?.name ?? 'unclassified',
          ),
        );
      }

      drugVariants.add(
        DrugProductVariantRecord(
          drugProductVariantId: variantId,
          drugConceptId: conceptId,
          jurisdiction: 'CA',
          regulator: 'HEALTH_CANADA_DPD',
          externalProductCode: din.isEmpty ? drugCode : '$din-$drugCode',
          route: routeName,
          dosageForm: formName,
          releaseType: 'unspecified',
          labelVersion: statusName.isEmpty ? 'dpd_api' : 'dpd_api_$statusName',
          sourceStatus: 'imported_dpd_api',
        ),
      );

      final tag = inferDrugTag(genericName);
      projectedDrugs.add(
        DrugDefinition(
          id: 'drug_dpd_${stableSlug(genericName.toLowerCase())}_${din.isEmpty ? drugCode : din}',
          genericName: genericName,
          brandNames: [brandName],
          aliases: [if (din.isNotEmpty) din, if (drugCode.isNotEmpty) drugCode],
          tags: [if (tag != null) tag],
          notes: statusName.isEmpty
              ? 'Imported from Health Canada DPD'
              : 'Imported from Health Canada DPD ($statusName)',
          interactionSummary:
              'Cross-jurisdiction product variant imported from DPD.',
          sourceSystem: 'HEALTH_CANADA_DPD',
          sourceProductCode: din.isEmpty ? drugCode : '$din-$drugCode',
          jurisdiction: 'CA',
          route: routeName,
          dosageForm: formName,
          releaseType: 'unspecified',
        ),
      );

      void addCrosswalk({
        required String system,
        required String value,
        required String sourceIdentifierType,
        required String reason,
        List<String> promotedFields = const <String>[],
        List<String> nonPromotedFields = const <String>[],
        double confidence = 1.0,
        Map<String, Object?> extra = const <String, Object?>{},
      }) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return;
        final key = '$variantId|$system|$trimmed';
        if (!crosswalkSeen.add(key)) return;
        crosswalks.add(
          buildCrosswalk(
            domain: 'drug',
            conceptId: conceptId,
            variantId: variantId,
            externalIdSystem: system,
            externalIdValue: trimmed,
            jurisdiction: 'CA',
            sourceDocId: sourceDocId,
            confidence: confidence,
            mappingPayload: {
              'regulator': 'HEALTH_CANADA_DPD',
              'brand_name': brandName,
              'dosage_form': formName,
              'route': routeName,
              if (statusName.isNotEmpty) 'status': statusName,
              ...ImporterAudit.confidenceReason(
                sourceIdentifierType: sourceIdentifierType,
                reason: reason,
                promotedFields: promotedFields,
                nonPromotedFields: nonPromotedFields,
              ),
              ...extra,
            },
          ),
        );
      }

      if (din.isNotEmpty) {
        addCrosswalk(
          system: 'Health Canada DIN',
          value: din,
          sourceIdentifierType:
              ImporterAudit.sourceIdTypeAuthoritativeProductCode,
          reason: 'DIN copied verbatim from the DPD drug product row.',
          promotedFields: const ['din'],
        );
      }
      if (drugCode.isNotEmpty) {
        addCrosswalk(
          system: 'Health Canada DPD drug_code',
          value: drugCode,
          sourceIdentifierType:
              ImporterAudit.sourceIdTypeAuthoritativeProductCode,
          reason: 'drug_code copied verbatim from the DPD drug product row.',
          promotedFields: const ['drug_code'],
          confidence: 0.97,
        );
      }

      final packageRows = packaging.where((item) {
        final rowDrugCode = '${item['drug_code'] ?? ''}'.trim();
        final rowDin =
            '${item['drug_identification_number'] ?? item['din'] ?? ''}'.trim();
        return rowDrugCode == drugCode || (rowDin == din && din.isNotEmpty);
      });
      for (final packageRow in packageRows) {
        final description =
            '${packageRow['package'] ?? packageRow['package_description'] ?? packageRow['description'] ?? ''}'
                .trim();
        if (description.isEmpty) continue;
        packagingRecords.add(
          DrugProductPackagingRecord(
            packagingId:
                'pkg_${stableHash('$variantId:${packageRow.toString()}')}',
            drugProductVariantId: variantId,
            sourceDocId: sourceDocId,
            packageCode: packageRow['upc']?.toString() ??
                packageRow['package_code']?.toString(),
            description: description,
            marketingStatus: packageRow['status']?.toString(),
          ),
        );
        final upc = packageRow['upc']?.toString() ?? '';
        final packageCode = packageRow['package_code']?.toString() ?? '';
        if (upc.isNotEmpty) {
          addCrosswalk(
            system: 'Health Canada DPD UPC',
            value: upc,
            sourceIdentifierType:
                ImporterAudit.sourceIdTypePackageOrPortionCode,
            reason: 'UPC copied from the DPD packaging row.',
            promotedFields: const ['upc'],
            nonPromotedFields: const ['package_description'],
            confidence: 0.9,
            extra: {'package_description': description},
          );
        }
        if (packageCode.isNotEmpty && packageCode != upc) {
          addCrosswalk(
            system: 'Health Canada DPD package code',
            value: packageCode,
            sourceIdentifierType:
                ImporterAudit.sourceIdTypePackageOrPortionCode,
            reason: 'Package code copied from the DPD packaging row.',
            promotedFields: const ['package_code'],
            nonPromotedFields: const ['package_description'],
            confidence: 0.9,
            extra: {'package_description': description},
          );
        }
      }
    }

    return P0ImportBundle(
      sourceDocuments: [sourceDocument],
      drugConcepts: drugConcepts,
      drugProductVariants: drugVariants,
      drugProductPackagings: packagingRecords,
      conceptVariantCrosswalks: crosswalks,
      projectedDrugs: projectedDrugs,
    );
  }

  Future<P0ImportBundle> enrichWithProductDetails(P0ImportBundle bundle) async {
    P0ImportBundle current = bundle;
    for (final variant in bundle.drugProductVariants) {
      final productCode = variant.externalProductCode;
      final drugCode =
          productCode.contains('-') ? productCode.split('-').last : productCode;
      final infoUrl =
          'https://health-products.canada.ca/dpd-bdpp/info?code=$drugCode&lang=eng';
      try {
        final html = await fetchClient.getText(infoUrl);
        final summaryText = _summarizeHtmlDetail(html);
        final detailSections = _extractHtmlSections(html);
        final linkedResources = _extractLinkedResources(html);
        final labelFacts = _extractStructuredLabelFacts(
          summaryText: summaryText,
          detailSections: detailSections,
        );
        final detailSourceDocId = sourceDocumentId(
          sourceSystem: 'HEALTH_CANADA_DPD_INFO',
          externalKey: drugCode,
        );
        current = current.merge(
          P0ImportBundle(
            sourceDocuments: [
              buildSourceDocumentRecord(
                sourceDocId: detailSourceDocId,
                sourceFamily: 'HEALTH_CANADA_DPD',
                organization: 'Health Canada',
                jurisdiction: 'CA',
                docType: 'product_info_html',
                title: 'Health Canada DPD product detail $drugCode',
                originUrl: infoUrl,
                licenseNote: 'UNSPECIFIED',
                language: 'en',
                rawPayload: stringifyPayload({
                  'detail_url': infoUrl,
                  'html_excerpt': summaryText,
                  'section_count': detailSections.length,
                  'linked_resource_count': linkedResources.length,
                  'label_facts': labelFacts,
                  'audit_gaps': <Map<String, Object?>>[
                    ImporterAudit.auditGap(
                      fieldName: 'product_info_html_body',
                      reason:
                          'Body parsed conservatively into heading-delimited sections only; no schema-aware monograph parsing.',
                      observedCount: detailSections.length,
                    ),
                    ImporterAudit.auditGap(
                      fieldName: 'linked_resources',
                      reason:
                          'Anchors classified by URL suffix (.pdf vs other); resource bodies not fetched.',
                      observedCount: linkedResources.length,
                    ),
                  ],
                }),
              ),
            ],
            drugLabelSections: [
              if (summaryText.isNotEmpty)
                DrugLabelSectionRecord(
                  sectionId:
                      'section_${stableHash('${variant.drugProductVariantId}:dpd_info')}',
                  drugProductVariantId: variant.drugProductVariantId,
                  sourceDocId: detailSourceDocId,
                  sectionKey: 'product_info_summary',
                  sectionTitle: 'product_info_summary',
                  sectionText: summaryText,
                ),
              ...detailSections.map(
                (section) => DrugLabelSectionRecord(
                  sectionId:
                      'section_${stableHash('${variant.drugProductVariantId}:${section.key}')}',
                  drugProductVariantId: variant.drugProductVariantId,
                  sourceDocId: detailSourceDocId,
                  sectionKey: section.key,
                  sectionTitle: section.title,
                  sectionText: section.text,
                ),
              ),
            ],
            drugProductMedias: linkedResources
                .map(
                  (resource) => DrugProductMediaRecord(
                    mediaId:
                        'media_${stableHash('${variant.drugProductVariantId}:${resource.url}')}',
                    drugProductVariantId: variant.drugProductVariantId,
                    sourceDocId: detailSourceDocId,
                    mediaType: resource.type,
                    mediaUrl: resource.url,
                    caption: resource.caption,
                  ),
                )
                .toList(growable: false),
            conceptVariantCrosswalks: <ConceptVariantCrosswalkRecord>[
              buildCrosswalk(
                domain: 'drug',
                conceptId: variant.drugConceptId,
                variantId: variant.drugProductVariantId,
                externalIdSystem: 'Health Canada DPD info URL',
                externalIdValue: infoUrl,
                jurisdiction: 'CA',
                sourceDocId: detailSourceDocId,
                confidence: 0.9,
                mappingPayload: {
                  'drug_code': drugCode,
                  'kind': 'product_info_landing',
                  'section_count': detailSections.length,
                  ...ImporterAudit.confidenceReason(
                    sourceIdentifierType:
                        ImporterAudit.sourceIdTypeRegulatorMetadataUrl,
                    reason:
                        'Product info URL is generated from the DPD drug_code and used only as a landing-page locator.',
                    promotedFields: const ['info_url', 'drug_code'],
                    nonPromotedFields: const ['product_info_html_body'],
                    parserLimitation:
                        'HTML body is extracted conservatively into text sections, not a full monograph model.',
                  ),
                },
              ),
              for (final resource in linkedResources)
                buildCrosswalk(
                  domain:
                      resource.type == 'pdf' ? 'drug_monograph' : 'drug_media',
                  conceptId: variant.drugConceptId,
                  variantId: variant.drugProductVariantId,
                  externalIdSystem: resource.type == 'pdf'
                      ? 'Health Canada DPD monograph URL'
                      : 'Health Canada DPD linked resource',
                  externalIdValue: resource.url,
                  jurisdiction: 'CA',
                  sourceDocId: detailSourceDocId,
                  confidence: 0.8,
                  mappingPayload: {
                    'drug_code': drugCode,
                    'caption': resource.caption,
                    'media_type': resource.type,
                    ...ImporterAudit.confidenceReason(
                      sourceIdentifierType: resource.type == 'pdf'
                          ? ImporterAudit.sourceIdTypeRegulatorMonographUrl
                          : ImporterAudit.sourceIdTypeRegulatorDocumentUrl,
                      reason:
                          'Resource href + visible caption extracted from product info HTML <a> tags only.',
                      promotedFields: const [
                        'resource_type',
                        'caption',
                        'url',
                      ],
                      nonPromotedFields: const ['resource_body'],
                      promotionDecision:
                          'href_and_caption_only_no_body_extraction',
                      parserLimitation:
                          'Importer does not download or structure resource body; classifier is suffix-based (.pdf vs other).',
                    ),
                  },
                ),
            ],
          ),
        );
      } catch (_) {
        // 部分产品详情页可能暂时不可达；不影响主 API 导入。
      }
    }
    return current;
  }

  String _summarizeHtmlDetail(String html) {
    // 这里做“最小可复核摘要”：
    // - 去掉大部分标签；
    // - 只截前几段文本，避免把整页 HTML 直接塞进 UI 说明。
    final text = html
        .replaceAll(
            RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(
            RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (text.isEmpty) return '';
    return text.length <= 800 ? text : '${text.substring(0, 800)}...';
  }

  List<_DpdHtmlSection> _extractHtmlSections(String html) {
    final sections = <_DpdHtmlSection>[];
    final headingMatches = RegExp(
      r'<h([1-6])[^>]*>(.*?)</h\1>',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html).toList(growable: false);
    for (var index = 0; index < headingMatches.length; index++) {
      final current = headingMatches[index];
      final title = _stripHtml(current.group(2) ?? '');
      if (title.isEmpty) continue;
      final start = current.end;
      final end = index + 1 < headingMatches.length
          ? headingMatches[index + 1].start
          : html.length;
      final text = _stripHtml(html.substring(start, end));
      if (text.isEmpty) continue;
      sections.add(
        _DpdHtmlSection(
          key: 'dpd_${stableSlug(title.toLowerCase())}',
          title: title,
          text: text.length <= 1600 ? text : '${text.substring(0, 1600)}...',
        ),
      );
    }
    return sections;
  }

  List<_DpdLinkedResource> _extractLinkedResources(String html) {
    final resources = <_DpdLinkedResource>{};
    final matches = RegExp(
      r'''<a[^>]+href=["']([^"']+)["'][^>]*>(.*?)</a>''',
      caseSensitive: false,
      dotAll: true,
    ).allMatches(html);
    for (final match in matches) {
      final url = (match.group(1) ?? '').trim();
      if (!url.startsWith('http')) continue;
      final caption = _stripHtml(match.group(2) ?? '');
      resources.add(
        _DpdLinkedResource(
          type: url.toLowerCase().endsWith('.pdf') ? 'pdf' : 'html_link',
          url: url,
          caption: caption.isEmpty ? 'Health Canada linked resource' : caption,
        ),
      );
    }
    return resources.toList(growable: false);
  }

  List<Map<String, dynamic>> _extractStructuredLabelFacts({
    required String summaryText,
    required List<_DpdHtmlSection> detailSections,
  }) {
    final facts = <Map<String, dynamic>>[];
    final seenTypes = <String>{};
    final entries = <_DpdFactTextEntry>[
      if (summaryText.trim().isNotEmpty)
        _DpdFactTextEntry(
          key: 'product_info_summary',
          title: 'product_info_summary',
          text: summaryText,
        ),
      ...detailSections.map(
        (section) => _DpdFactTextEntry(
          key: section.key,
          title: section.title,
          text: section.text,
        ),
      ),
    ];

    void addFact({
      required String factType,
      required String label,
      required _DpdFactTextEntry entry,
      String? valueText,
      Map<String, dynamic> payload = const <String, dynamic>{},
    }) {
      if (!seenTypes.add(factType)) return;
      facts.add({
        'fact_type': factType,
        'label': label,
        'value_text': valueText,
        'source_section_key': entry.key,
        'source_section_title': entry.title,
        'source_excerpt': _shortExcerpt(entry.text),
        'payload': payload,
      });
    }

    for (final entry in entries) {
      final lower = '${entry.title} ${entry.text}'.toLowerCase();
      if (lower.contains('with or without food')) {
        addFact(
          factType: 'with_or_without_food',
          label: 'May be taken with or without food',
          entry: entry,
        );
      }

      final beforeAfterMatch = RegExp(
        r'at least\s+(\d+)\s*(hour|hours|hr|hrs|minute|minutes|min|mins)\s+before.*?at least\s+(\d+)\s*(hour|hours|hr|hrs|minute|minutes|min|mins)\s+after',
        dotAll: true,
      ).firstMatch(lower);
      if (beforeAfterMatch != null) {
        final beforeMinutes = _normalizeToMinutes(
          int.tryParse(beforeAfterMatch.group(1) ?? ''),
          beforeAfterMatch.group(2) ?? '',
        );
        final afterMinutes = _normalizeToMinutes(
          int.tryParse(beforeAfterMatch.group(3) ?? ''),
          beforeAfterMatch.group(4) ?? '',
        );
        addFact(
          factType: 'meal_window_before_after',
          label: 'Meal timing window',
          entry: entry,
          valueText:
              '$beforeMinutes min before meal / $afterMinutes min after meal',
          payload: {
            'before_minutes': beforeMinutes,
            'after_minutes': afterMinutes,
          },
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
          entry: entry,
          valueText: hours == null ? null : '$hours hours delay',
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
          entry: entry,
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
          entry: entry,
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
          entry: entry,
        );
      }

      if ((lower.contains('enteral') || lower.contains('tube feeding')) &&
          (lower.contains('levodopa') ||
              lower.contains('protein') ||
              lower.contains('feeding'))) {
        addFact(
          factType: 'enteral_feed_review',
          label: 'Enteral feeding requires review',
          entry: entry,
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

  String _stripHtml(String html) {
    return html
        .replaceAll(
            RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(
            RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  List<Map<String, String>> _loadRows(Map<String, String> files, String stem) {
    final entry = files.entries.firstWhere(
      (item) {
        final lower = item.key.toLowerCase();
        return lower.endsWith('/$stem.txt') ||
            lower.endsWith('\\$stem.txt') ||
            lower.endsWith('$stem.txt') ||
            lower.endsWith('/$stem.csv') ||
            lower.endsWith('\\$stem.csv') ||
            lower.endsWith('$stem.csv');
      },
      orElse: () => const MapEntry('', ''),
    );
    if (entry.key.isEmpty) return const <Map<String, String>>[];
    return ArchiveImportSupport.parseDelimitedRows(entry.value);
  }
}

class _DpdHtmlSection {
  final String key;
  final String title;
  final String text;

  const _DpdHtmlSection({
    required this.key,
    required this.title,
    required this.text,
  });
}

class _DpdFactTextEntry {
  final String key;
  final String title;
  final String text;

  const _DpdFactTextEntry({
    required this.key,
    required this.title,
    required this.text,
  });
}

class _DpdLinkedResource {
  final String type;
  final String url;
  final String caption;

  const _DpdLinkedResource({
    required this.type,
    required this.url,
    required this.caption,
  });

  @override
  bool operator ==(Object other) {
    return other is _DpdLinkedResource &&
        other.type == type &&
        other.url == url &&
        other.caption == caption;
  }

  @override
  int get hashCode => Object.hash(type, url, caption);
}
