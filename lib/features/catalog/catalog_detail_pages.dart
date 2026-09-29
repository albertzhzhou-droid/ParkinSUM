import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../domain/usecases/cdss_catalog_projection_service.dart';

bool _isLessThanNutrientObservation(NutrientObservationEvidence observation) {
  final qualifier = observation.qualifierKind?.trim().toLowerCase() ?? '';
  final raw = observation.rawValueText?.trim() ?? '';
  return const <String>{
        'lt',
        'lte',
        'less_than',
        'less_than_or_equal',
      }.contains(qualifier) ||
      raw.startsWith('<');
}

/// 食品详情页：
/// - 优先展示已经导入到 CDSS 的真实 nutrient/variant 明细；
/// - 若当前条目没有 CDSS 细节，则回退到目录层的基本信息。
class FoodDetailPage extends StatelessWidget {
  final FoodItem food;
  final Future<ProjectedFoodDetail?> future;

  const FoodDetailPage({super.key, required this.food, required this.future});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    return Scaffold(
      appBar: AppBar(title: Text(i18n.foodName(food.id, food.name))),
      body: FutureBuilder<ProjectedFoodDetail?>(
        future: future,
        builder: (context, snapshot) {
          final detail = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i18n.foodName(food.id, food.name),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(food.description),
                      const SizedBox(height: 8),
                      Text(
                        i18n.tr('detail.macro_summary', {
                          'protein': '${food.proteinG.toStringAsFixed(1)} g',
                          'carbs': '${food.carbsG.toStringAsFixed(1)} g',
                          'fat': '${food.fatG.toStringAsFixed(1)} g',
                          'fiber': '${food.fiberG.toStringAsFixed(1)} g',
                          'sodium': '${food.sodiumMg.toStringAsFixed(0)} mg',
                        }),
                      ),
                      Text(
                        '${food.sourceSystem} · ${food.jurisdiction}${food.sourceFoodCode == null ? '' : ' · ${food.sourceFoodCode}'}',
                      ),
                      if (food.textureClass != null || food.iddsiLevel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            [
                              if (food.textureClass != null)
                                'Texture: ${food.textureClass}',
                              if (food.iddsiLevel != null)
                                'IDDSI: ${food.iddsiLevel}',
                            ].join(' · '),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              _FoodCatalogProvenanceCard(food: food),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (detail != null) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.tr('detail.variant_source'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        for (final source in detail.sourceTitles) Text(source),
                        const SizedBox(height: 8),
                        for (final variantId in detail.variantIds.take(3))
                          Text(variantId),
                      ],
                    ),
                  ),
                ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.tr('detail.imported_nutrients'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (detail.nutrientLines.isEmpty)
                          Text(i18n.tr('detail.no_imported_nutrients')),
                        for (final line in detail.nutrientLines.take(20))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '${line.displayLabel}: ${line.rawValueText}${line.unit.isEmpty ? '' : ' ${line.unit}'}'
                              '${line.methodCode == null ? '' : ' · ${i18n.tr('detail.method_label')} ${line.methodCode}'}'
                              '${line.sourceDocTitle == null ? '' : ' · ${i18n.tr('detail.source_label')} ${line.sourceDocTitle}'}',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _FoodCatalogProvenanceCard extends StatelessWidget {
  final FoodItem food;

  const _FoodCatalogProvenanceCard({required this.food});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final evidence = food.catalogProvenanceEvidence;
    final observations = food.nutrientObservationEvidence;
    final hasCatalogEvidence =
        evidence != null &&
        (evidence.sourceDocuments.isNotEmpty ||
            evidence.variantScopes.isNotEmpty ||
            evidence.conceptVariantMatches.isNotEmpty);
    final hasAnyEvidence = hasCatalogEvidence || observations.isNotEmpty;
    String value(String? input) =>
        input == null || input.trim().isEmpty ? '—' : input;
    String date(int? epochMs) {
      if (epochMs == null) return '—';
      return DateTime.fromMillisecondsSinceEpoch(
        epochMs,
        isUtc: true,
      ).toIso8601String().split('T').first;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              i18n.tr('detail.food_catalog_provenance_title'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (!hasAnyEvidence)
              Text(i18n.tr('detail.food_catalog_provenance_unavailable')),
            if (evidence != null && evidence.sourceDocuments.isNotEmpty) ...[
              Text(
                i18n.tr('detail.food_catalog_source_documents'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final document in evidence.sourceDocuments) ...[
                const SizedBox(height: 6),
                if (document.resolutionStatus != 'resolved')
                  Text(
                    i18n.tr('detail.food_catalog_unresolved', {
                      'id': document.sourceDocId,
                    }),
                  )
                else ...[
                  Text(
                    i18n.tr('detail.food_catalog_document_summary', {
                      'id': document.sourceDocId,
                      'title': value(document.title),
                      'organization': value(document.organization),
                      'family': value(document.sourceFamily),
                      'type': value(document.docType),
                      'tier': value(document.dataTier),
                      'jurisdiction': value(document.jurisdiction),
                      'status': value(document.sourceStatus),
                    }),
                  ),
                  Text(
                    i18n.tr('detail.food_catalog_source_dates', {
                      'published': date(document.publishedAtEpochMs),
                      'effective': date(document.effectiveAtEpochMs),
                    }),
                  ),
                  if (document.licenseNote?.trim().isNotEmpty == true)
                    Text(
                      i18n.tr('detail.food_catalog_license', {
                        'value': document.licenseNote!,
                      }),
                    ),
                  if (document.originUrl?.trim().isNotEmpty == true)
                    SelectableText(
                      i18n.tr('detail.food_catalog_source_url', {
                        'value': document.originUrl!,
                      }),
                    ),
                  if (document.sourceRegistryChecksum?.trim().isNotEmpty ==
                      true)
                    Text(
                      i18n.tr('detail.food_catalog_registered_checksum', {
                        'value': document.sourceRegistryChecksum!,
                      }),
                    ),
                  if (document.payloadSha256 != null)
                    SelectableText(
                      i18n.tr('detail.food_catalog_payload_digest', {
                        'digest': document.payloadSha256!,
                      }),
                    )
                  else
                    Text(i18n.tr('detail.food_catalog_payload_unavailable')),
                ],
              ],
            ],
            if (evidence != null && evidence.variantScopes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                i18n.tr('detail.food_catalog_scopes'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final scope in evidence.variantScopes) ...[
                const SizedBox(height: 6),
                if (scope.resolutionStatus != 'resolved')
                  Text(
                    i18n.tr('detail.food_catalog_unresolved', {
                      'id': scope.scopeHash,
                    }),
                  )
                else
                  Text(
                    i18n.tr('detail.food_catalog_scope_summary', {
                      'hash': scope.scopeHash,
                      'jurisdiction': value(scope.jurisdiction),
                      'brand': value(scope.brand),
                      'preparation': value(scope.preparationState),
                      'cooking': value(scope.cookingState),
                      'plant': value(scope.plantPart),
                      'cultivar': value(scope.cultivar),
                      'sampling': value(scope.samplingFrame),
                    }),
                  ),
              ],
            ],
            if (evidence != null &&
                evidence.conceptVariantMatches.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                i18n.tr('detail.food_catalog_mappings'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final mapping in evidence.conceptVariantMatches) ...[
                const SizedBox(height: 6),
                Text(
                  i18n.tr('detail.food_catalog_mapping_summary', {
                    'system': value(mapping.externalIdSystem),
                    'externalId': value(mapping.externalIdValue),
                    'appId': value(mapping.appEntityId),
                    'confidence': mapping.recordedConfidence?.toString() ?? '—',
                    'status': value(mapping.status),
                    'selection': i18n.tr(
                      mapping.selectedForProjectedFoodId
                          ? 'detail.food_catalog_mapping_selected'
                          : 'detail.food_catalog_mapping_not_selected',
                    ),
                  }),
                ),
                if (mapping.mappingPayloadJson.trim().isNotEmpty)
                  SelectableText(
                    i18n.tr('detail.food_catalog_mapping_payload', {
                      'value': mapping.mappingPayloadJson,
                    }),
                  ),
              ],
            ],
            if (food.missingNutrientFields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  i18n.tr('detail.food_missing_nutrient_fields', {
                    'fields': (food.missingNutrientFields.toList()..sort())
                        .join(', '),
                  }),
                ),
              ),
            if (observations.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                i18n.tr('detail.food_nutrient_observation_evidence'),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              for (final observation in observations)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i18n.tr(
                          observation.selectedForLegacyPointProjection
                              ? 'detail.food_nutrient_projection_selected'
                              : 'detail.food_nutrient_projection_evidence_only',
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: observation.selectedForLegacyPointProjection
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        i18n.tr('detail.food_nutrient_observation_line', {
                          'attribute': value(observation.attributeCode),
                          'raw': value(observation.rawValueText),
                          'qualifier': value(observation.qualifierKind),
                          'unit': value(observation.unit),
                          'basis': value(observation.basisType),
                          'low': observation.low?.toString() ?? '—',
                          'high': observation.high?.toString() ?? '—',
                          'method': value(observation.methodCode),
                          'source': value(observation.sourceDocId),
                        }),
                      ),
                      if (_isLessThanNutrientObservation(observation))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            i18n.tr('detail.food_nutrient_less_than_boundary', {
                              'attribute': value(observation.attributeCode),
                              'raw': value(observation.rawValueText),
                              'qualifier': value(observation.qualifierKind),
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 8),
            Text(
              i18n.tr('detail.food_catalog_provenance_boundary'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

/// 药品详情页：
/// - 展示导入后的标签 section、包装信息、媒体/PDF 链接；
/// - 让药品页不再只停留在一行 notes。
class DrugDetailPage extends StatelessWidget {
  final DrugDefinition drug;
  final Future<ProjectedDrugDetail?> future;

  const DrugDetailPage({super.key, required this.drug, required this.future});

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.medicationName(drug.id, drug.displayName)),
      ),
      body: FutureBuilder<ProjectedDrugDetail?>(
        future: future,
        builder: (context, snapshot) {
          final detail = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        i18n.medicationName(drug.id, drug.displayName),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${i18n.sourceSystemLabel(drug.sourceSystem)} · ${i18n.regionLabel(drug.jurisdiction)} · ${i18n.routeLabel(drug.route)} · ${i18n.dosageFormLabel(drug.dosageForm)} · ${i18n.releaseTypeLabel(drug.releaseType)}',
                      ),
                      if (drug.sourceProductCode != null)
                        Text(
                          '${i18n.tr('detail.product_code')}: ${drug.sourceProductCode}',
                        ),
                      const SizedBox(height: 8),
                      Text(i18n.medicationNote(drug.id, drug.notes)),
                      if (drug.interactionSummary.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          i18n.medicationInteractionSummary(
                            drug.id,
                            drug.interactionSummary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (snapshot.connectionState == ConnectionState.waiting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (detail != null) ...[
                if (detail.labelFacts.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i18n.tr('detail.imported_label_facts'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          for (final fact in detail.labelFacts.take(10))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fact.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if ((fact.valueText ?? '').trim().isNotEmpty)
                                    Text(fact.valueText!),
                                  if ((fact.sourceDocTitle ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      fact.sourceDocTitle!,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  if ((fact.sourceSectionTitle ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      '${i18n.tr('detail.source_label')}: ${fact.sourceSectionTitle}',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                  if ((fact.sourceExcerpt ?? '')
                                      .trim()
                                      .isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(fact.sourceExcerpt!),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (detail.packagingDescriptions.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i18n.tr('detail.packaging'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          for (final item in detail.packagingDescriptions.take(
                            10,
                          ))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(item),
                            ),
                        ],
                      ),
                    ),
                  ),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          i18n.tr('detail.imported_label_sections'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (detail.sections.isEmpty)
                          Text(i18n.tr('detail.no_imported_label_sections')),
                        for (final section in detail.sections.take(10))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  section.sectionTitle.isEmpty
                                      ? section.sectionKey
                                      : section.sectionTitle,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if ((section.sourceDocTitle ?? '')
                                    .trim()
                                    .isNotEmpty)
                                  Text(
                                    section.sourceDocTitle!,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                const SizedBox(height: 4),
                                Text(section.sectionText),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (detail.mediaLinks.isNotEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            i18n.tr('detail.media_links'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          for (final link in detail.mediaLinks.take(10))
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: SelectableText(link),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}
