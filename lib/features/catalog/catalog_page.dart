import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/models/food_item.dart';
import '../../core/state/app_state.dart';
import 'catalog_detail_pages.dart';

class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key});

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _controller = TextEditingController();
  bool _showFoods = true;

  String? _foodTextureLine(AppI18n i18n, FoodItem food) {
    if (food.textureClass == null && food.iddsiLevel == null) {
      return null;
    }
    return i18n.foodTextureSummary(
      textureClass: food.textureClass,
      iddsiLevel: food.iddsiLevel,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    final engine = state.catalogEngine;

    final keyword = _controller.text;
    final foods = engine.searchFoods(keyword);
    final drugs = engine.searchDrugs(keyword);

    return Scaffold(
      appBar: AppBar(
        title: Text(i18n.tr('catalog.title')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: i18n.tr('catalog.search'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(i18n.tr('catalog.foods')),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(i18n.tr('catalog.drugs')),
                ),
              ],
              selected: {_showFoods},
              onSelectionChanged: (s) => setState(() => _showFoods = s.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _showFoods
                ? ListView.separated(
                    itemCount: foods.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final food = foods[i];
                      final textureLine = _foodTextureLine(i18n, food);
                      return ListTile(
                        title: Text(i18n.foodName(food.id, food.name)),
                        subtitle: Text(
                          '${i18n.tr(
                            'catalog.food_subtitle',
                            {
                              'category': food.category.name,
                              'protein': '${food.proteinG}',
                              'carbs': '${food.carbsG}',
                              'fat': '${food.fatG}',
                            },
                          )}\n${food.sourceSystem} · ${food.jurisdiction}${food.sourceFoodCode == null ? '' : ' · ${food.sourceFoodCode}'}${textureLine == null ? '' : '\n$textureLine'}\n${food.description}',
                        ),
                        isThreeLine: true,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FoodDetailPage(
                              food: food,
                              future: state
                                  .services.cdssCatalogProjectionService
                                  .projectFoodDetail(food),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.separated(
                    itemCount: drugs.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final drug = drugs[i];
                      final active =
                          state.activeDrugs.any((item) => item.id == drug.id);
                      return ListTile(
                        title: Text(
                            i18n.medicationName(drug.id, drug.displayName)),
                        subtitle: Text(
                          '${i18n.tr(
                            'catalog.drug_subtitle',
                            {'tags': drug.tags.map((e) => e.name).join(', ')},
                          )}\n${i18n.sourceSystemLabel(drug.sourceSystem)} · ${i18n.regionLabel(drug.jurisdiction)} · ${i18n.routeLabel(drug.route)} · ${i18n.dosageFormLabel(drug.dosageForm)}\n${i18n.medicationNote(drug.id, drug.notes)}',
                        ),
                        trailing: active
                            ? const Icon(Icons.check_circle)
                            : const Icon(Icons.chevron_right),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DrugDetailPage(
                              drug: drug,
                              future: state
                                  .services.cdssCatalogProjectionService
                                  .projectDrugDetail(drug),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
