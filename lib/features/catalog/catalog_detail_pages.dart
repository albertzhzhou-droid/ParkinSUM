import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/food_item.dart';
import '../../domain/usecases/cdss_catalog_projection_service.dart';

/// 食品详情页：
/// - 优先展示已经导入到 CDSS 的真实 nutrient/variant 明细；
/// - 若当前条目没有 CDSS 细节，则回退到目录层的基本信息。
class FoodDetailPage extends StatelessWidget {
  final FoodItem food;
  final Future<ProjectedFoodDetail?> future;

  const FoodDetailPage({
    super.key,
    required this.food,
    required this.future,
  });

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
                        i18n.tr(
                          'detail.macro_summary',
                          {
                            'protein': '${food.proteinG.toStringAsFixed(1)} g',
                            'carbs': '${food.carbsG.toStringAsFixed(1)} g',
                            'fat': '${food.fatG.toStringAsFixed(1)} g',
                            'fiber': '${food.fiberG.toStringAsFixed(1)} g',
                            'sodium': '${food.sodiumMg.toStringAsFixed(0)} mg',
                          },
                        ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
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

/// 药品详情页：
/// - 展示导入后的标签 section、包装信息、媒体/PDF 链接；
/// - 让药品页不再只停留在一行 notes。
class DrugDetailPage extends StatelessWidget {
  final DrugDefinition drug;
  final Future<ProjectedDrugDetail?> future;

  const DrugDetailPage({
    super.key,
    required this.drug,
    required this.future,
  });

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    return Scaffold(
      appBar:
          AppBar(title: Text(i18n.medicationName(drug.id, drug.displayName))),
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
                            '${i18n.tr('detail.product_code')}: ${drug.sourceProductCode}'),
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
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
                                    ),
                                  if ((fact.sourceSectionTitle ?? '')
                                      .trim()
                                      .isNotEmpty)
                                    Text(
                                      '${i18n.tr('detail.source_label')}: ${fact.sourceSectionTitle}',
                                      style:
                                          Theme.of(context).textTheme.bodySmall,
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
                          for (final item
                              in detail.packagingDescriptions.take(10))
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
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
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
