import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/food_item.dart';
import '../../core/state/app_state.dart';
import '../../core/state/app_state_slices.dart';
import '../../core/theme/liquid_glass_theme.dart';
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
    final catalogState = context.select<AppState, CatalogStateSlice>(
      CatalogStateSlice.fromState,
    );
    final state = context.read<AppState>();
    final i18n = context.appI18n;
    final engine = state.catalogEngine;

    final keyword = _controller.text;
    final foods = engine.searchFoods(keyword);
    final drugs = engine.searchDrugs(keyword);

    return Scaffold(
      appBar: AppBar(title: Text(i18n.tr('catalog.title'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _CatalogShowcaseCard(
              foodCount: foods.length,
              drugCount: drugs.length,
              totalFoodCount: engine.foodRepo.allFoods.length,
              totalDrugCount: engine.medRepo.allDrugs.length,
              showingFoods: _showFoods,
            ),
          ),
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
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final food = foods[i];
                      final textureLine = _foodTextureLine(i18n, food);
                      return ListTile(
                        title: Text(i18n.foodName(food.id, food.name)),
                        subtitle: Text(
                          '${i18n.tr('catalog.food_subtitle', {'category': food.category.name, 'protein': '${food.proteinG}', 'carbs': '${food.carbsG}', 'fat': '${food.fatG}'})}\n${food.sourceSystem} · ${food.jurisdiction}${food.sourceFoodCode == null ? '' : ' · ${food.sourceFoodCode}'}${textureLine == null ? '' : '\n$textureLine'}\n${food.description}',
                        ),
                        isThreeLine: true,
                        trailing: Icon(
                          Icons.chevron_right,
                          semanticLabel: i18n.tr('catalog.view_detail'),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => FoodDetailPage(
                              food: food,
                              future: state
                                  .services
                                  .cdssCatalogProjectionService
                                  .projectFoodDetail(food),
                            ),
                          ),
                        ),
                      );
                    },
                  )
                : ListView.separated(
                    itemCount: drugs.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final drug = drugs[i];
                      final active = catalogState.activeDrugIds.contains(
                        drug.id,
                      );
                      return ListTile(
                        title: Text(
                          i18n.medicationName(drug.id, drug.displayName),
                        ),
                        subtitle: Text(
                          '${i18n.tr('catalog.drug_subtitle', {'tags': drug.tags.map((e) => e.name).join(', ')})}\n${i18n.sourceSystemLabel(drug.sourceSystem)} · ${i18n.regionLabel(drug.jurisdiction)} · ${i18n.routeLabel(drug.route)} · ${i18n.dosageFormLabel(drug.dosageForm)}\n${i18n.medicationNote(drug.id, drug.notes)}',
                        ),
                        trailing: active
                            ? Icon(
                                Icons.check_circle,
                                semanticLabel: i18n.tr(
                                  'catalog.selected_active',
                                ),
                              )
                            : Icon(
                                Icons.chevron_right,
                                semanticLabel: i18n.tr('catalog.view_detail'),
                              ),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DrugDetailPage(
                              drug: drug,
                              future: state
                                  .services
                                  .cdssCatalogProjectionService
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

class _CatalogShowcaseCard extends StatelessWidget {
  /// Entries matching the current search — NOT the shipped catalog size.
  final int foodCount;
  final int drugCount;

  /// Entries actually shipped. Rendered alongside the match count because
  /// showing only the filtered number under a "Foods indexed" label read as a
  /// claim about catalog size, and shrank as the user typed.
  final int totalFoodCount;
  final int totalDrugCount;

  final bool showingFoods;

  const _CatalogShowcaseCard({
    required this.foodCount,
    required this.drugCount,
    required this.totalFoodCount,
    required this.totalDrugCount,
    required this.showingFoods,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleCount = showingFoods ? foodCount : drugCount;
    final totalCount = showingFoods ? totalFoodCount : totalDrugCount;
    final visibleLabel = showingFoods ? 'Foods' : 'Medication records';
    // "N of M shipped" — the match count alone was labelled as the catalog
    // size and silently disagreed with it whenever a search was active.
    final countSummary = visibleCount == totalCount
        ? '$visibleCount shipped'
        : '$visibleCount of $totalCount shipped';

    return GlassSurface(
      borderRadius: 8,
      blurSigma: LiquidGlass.blurSm,
      padding: EdgeInsets.zero,
      border: Border.all(color: LiquidGlass.stroke),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 148,
            color: Colors.white.withValues(alpha: 0.74),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Image.asset(
              'assets/brand/parkinsum-wordmark.png',
              fit: BoxFit.contain,
              semanticLabel: 'ParkinSUM food medication interaction logo',
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: LiquidGlass.stroke)),
            ),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        'assets/brand/parkinsum-icon.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        semanticLabel: 'ParkinSUM app icon',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ParkinSUM / Companion',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: LiquidGlass.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Search synthetic food and medication catalogs',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: LiquidGlass.onSurfaceMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.10,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.22,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              showingFoods
                                  ? Icons.restaurant_menu_rounded
                                  : Icons.medication_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$visibleCount',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  'Local-first educational prototype for deterministic food-medication interaction review.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: LiquidGlass.onSurfaceMuted,
                  ),
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _CatalogShowcaseChip(
                      label: 'flutter',
                      color: Color(0xFF0EA5E9),
                    ),
                    _CatalogShowcaseChip(
                      label: 'food-medication',
                      color: Color(0xFF14B8A6),
                    ),
                    _CatalogShowcaseChip(
                      label: 'local-first',
                      color: Color(0xFF2563EB),
                    ),
                    _CatalogShowcaseChip(
                      label: 'synthetic-data',
                      color: Color(0xFF64748B),
                    ),
                    _CatalogShowcaseChip(
                      label: 'evidence-linked',
                      color: Color(0xFF0891B2),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      Icons.update_rounded,
                      size: 18,
                      color: LiquidGlass.onSurfaceMuted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '$visibleLabel: $countSummary',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: LiquidGlass.onSurfaceMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      width: 10,
                      height: 10,
                      decoration: const BoxDecoration(
                        color: Color(0xFF14B8A6),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Dart',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: LiquidGlass.onSurfaceMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatalogShowcaseChip extends StatelessWidget {
  final String label;
  final Color color;

  const _CatalogShowcaseChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
