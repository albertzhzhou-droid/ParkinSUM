import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../domain/usecases/entry_food_portion_preview_service.dart';

class FoodPortionPreviewDialog extends StatefulWidget {
  const FoodPortionPreviewDialog({
    super.key,
    required this.future,
    required this.sourceChanges,
    required this.isCurrent,
  });
  final Future<EntryFoodPortionPreviewContext> future;
  final Listenable sourceChanges;
  final bool Function() isCurrent;
  @override
  State<FoodPortionPreviewDialog> createState() =>
      _FoodPortionPreviewDialogState();
}

class _FoodPortionPreviewDialogState extends State<FoodPortionPreviewDialog> {
  String? _locator;
  bool _invalidated = false;

  String _reason(String? reason, bool zh) => switch (reason) {
    'source_data_type_not_foundation' =>
      zh
          ? '此来源不是 FDC Foundation；不进行份量换算。'
          : 'This source is not FDC Foundation; conversion is withheld.',
    'portion_record_locator_not_unique' =>
      zh ? '缺少唯一来源份量记录。' : 'A unique source portion record is unavailable.',
    'exact_nutrient_evidence_not_unique' =>
      zh
          ? '缺少唯一的已测营养值；保留未知。'
          : 'A unique nutrient value is unavailable; it remains unknown.',
    'exact_nutrient_value_differs_from_candidate_projection' =>
      zh
          ? '营养值缺失或与当前来源不一致。'
          : 'The nutrient is missing or differs from the current source.',
    _ =>
      zh
          ? '来源、单位或证据绑定未通过核对；暂不换算。'
          : 'Source, unit or evidence binding could not be verified; conversion is withheld.',
  };

  @override
  Widget build(BuildContext context) {
    final zh = context.appI18n.languageFamily == 'zh';
    return AlertDialog(
      title: Text(zh ? '来源绑定份量预览' : 'Source-bound portion preview'),
      content: SizedBox(
        width: 520,
        child: AnimatedBuilder(
          animation: widget.sourceChanges,
          builder: (context, _) => FutureBuilder<EntryFoodPortionPreviewContext>(
            future: widget.future,
            builder: (context, snapshot) {
              if (_invalidated || !widget.isCurrent()) {
                return Text(
                  zh
                      ? '来源或编辑会话已变化；请关闭并重新打开份量预览。'
                      : 'The source or editing session changed. Close and reopen the portion preview.',
                  key: const Key('entry-portion-preview-stale'),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  zh
                      ? '来源读取失败；未应用份量。'
                      : 'Source could not be loaded; no portion was applied.',
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snapshot.data!;
              final portions = {
                for (final portion in data.food.foodPortionEvidence)
                  if (portion.recordLocator != null &&
                      portion.recordLocator!.isNotEmpty)
                    portion.recordLocator!: portion,
              }.values.toList(growable: false);
              final locator =
                  _locator ?? portions.firstOrNull?.recordLocator ?? '';
              final previews = {
                for (final nutrient in [
                  'protein_g',
                  'carbohydrate_g',
                  'fat_g',
                  'fiber_g',
                  'sodium_mg',
                  'energy_kcal',
                  'water_g',
                ])
                  nutrient: data.preview(locator, nutrient),
              };
              final available = previews.values
                  .where((result) => result.status == 'calculated_preview')
                  .firstOrNull;
              final labels = zh
                  ? ['蛋白质', '碳水化合物', '脂肪', '膳食纤维', '钠', '能量', '水']
                  : [
                      'Protein',
                      'Carbohydrate',
                      'Fat',
                      'Fiber',
                      'Sodium',
                      'Energy',
                      'Water',
                    ];
              return SingleChildScrollView(
                key: const Key('entry-portion-preview-scroll'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      zh
                          ? '来源份量是该文档的计量记录。请选择后再确认克数；预览不改变食物或规则。'
                          : 'A source portion is a measure from this document. Select it and confirm the grams; this preview does not change the food or rules.',
                    ),
                    const SizedBox(height: 12),
                    if (portions.isNotEmpty)
                      DropdownButtonFormField<String>(
                        key: const Key('entry-source-portion-selector'),
                        initialValue: locator,
                        isExpanded: true,
                        items: [
                          for (final portion in portions)
                            if (portion.recordLocator != null)
                              DropdownMenuItem(
                                value: portion.recordLocator,
                                child: Text(
                                  '${portion.amount ?? ''} ${portion.measureUnitName ?? portion.portionDescription ?? ''} · ${portion.gramWeight ?? '?'} g',
                                  maxLines: 2,
                                ),
                              ),
                        ],
                        onChanged: (value) => setState(() => _locator = value),
                      ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < previews.length; i++) ...[
                      Text(
                        '${labels[i]}: ${previews.values.elementAt(i).perPortionValue?.toStringAsFixed(2) ?? (zh ? '未知' : 'Unknown')} ${previews.values.elementAt(i).nutrientUnit}',
                      ),
                      if (previews.values.elementAt(i).holdReason != null)
                        Text(
                          _reason(previews.values.elementAt(i).holdReason, zh),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                    if (available != null) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        '${zh ? '来源食品' : 'Source food'}: ${available.sourceFoodId}\n${zh ? '来源文档' : 'Source document'}: ${available.sourceDocId}\n${zh ? '来源份量' : 'Portion record'}: ${available.portionRecordLocator}',
                      ),
                      Text(
                        zh
                            ? '计算：每100g营养值 × 来源克数 ÷ 100。来源没有量化份量重量的不确定性。'
                            : 'Calculation: per-100g nutrient × source grams ÷ 100. Portion weight uncertainty is not quantified by the source.',
                      ),
                      if (available.sourceSampleMinimumPerPortion != null)
                        Text(
                          zh
                              ? '样本范围为来源观测极值，不是置信区间。'
                              : 'Sample ranges are observed source extrema, not confidence intervals.',
                        ),
                      const SizedBox(height: 12),
                      FilledButton(
                        key: const Key('entry-apply-source-portion'),
                        onPressed: () {
                          if (!widget.isCurrent()) {
                            setState(() => _invalidated = true);
                            return;
                          }
                          Navigator.of(
                            context,
                          ).pop(available.portionGramWeight);
                        },
                        child: Text(
                          zh
                              ? '使用 ${available.portionGramWeight} g，并确认份量'
                              : 'Use ${available.portionGramWeight} g and confirm quantity',
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.appI18n.tr('common.close')),
        ),
      ],
    );
  }
}
