import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/dish_catalog.dart';
import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/food_item.dart';
import '../../core/state/app_state.dart';
import '../../core/state/dish_plate_handoff.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/dish_recipe.dart';
import '../../domain/usecases/dish_nutrition_view.dart';
import '../catalog/catalog_detail_pages.dart';
import 'advanced_dishes_widgets.dart';

/// Next meal → Advanced: simple preparation examples for common dishes,
/// with ingredients and per-serving nutrition computed from the food
/// catalog. Reached at `/app/next-meal/advanced`, from the sidebar and the
/// command palette.
class AdvancedDishesPage extends StatelessWidget {
  const AdvancedDishesPage({super.key, this.onBack, this.onAddToPlate});

  /// `MainTabRoute` id of this page inside the main shell.
  static const String routeId = 'next-meal/advanced';
  static const String routePath = '/app/next-meal/advanced';

  /// Leaves the page inside the shell. Null when the page was pushed; the
  /// back button then pops.
  final VoidCallback? onBack;

  /// Receives "Add ingredients to plate". Defaults to offering the request
  /// on [DishPlateHandoff.instance] for the Next-meal plate builder.
  final ValueChanged<DishPlateRequest>? onAddToPlate;

  @override
  Widget build(BuildContext context) {
    context.select<AppState, String>((s) => s.userProfile.displayLocale);
    final region = context.select<AppState, String>(
      (s) => s.userProfile.registrationRegion,
    );
    final revision = context.select<AppState, int>((s) => s.foodRepo.revision);
    final state = context.read<AppState>();
    final i18n = context.appI18n;
    return AppI18nScope(
      i18n: i18n,
      child: AdvancedDishesView(
        userRegion: region,
        lookup: state.foodRepo.getById,
        catalogRevision: revision,
        onBack: onBack,
        onAddToPlate: onAddToPlate ?? DishPlateHandoff.instance.offer,
        onOpenFood: (food) => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => FoodDetailPage(
              food: food,
              future: state.services.cdssCatalogProjectionService
                  .projectFoodDetail(food),
            ),
          ),
        ),
      ),
    );
  }
}

/// Region filter: the user's region, every region, or one chosen region.
sealed class DishRegionFilter {
  const DishRegionFilter();
}

final class DishRegionMine extends DishRegionFilter {
  const DishRegionMine();
}

final class DishRegionAll extends DishRegionFilter {
  const DishRegionAll();
}

final class DishRegionOne extends DishRegionFilter {
  const DishRegionOne(this.code);
  final String code;
}

/// The page body, independent of [AppState] so it can be pumped with
/// synthetic catalogs. Needs an [AppI18nScope] above it.
class AdvancedDishesView extends StatefulWidget {
  const AdvancedDishesView({
    super.key,
    required this.userRegion,
    required this.lookup,
    required this.onAddToPlate,
    this.catalogRevision = 0,
    this.dishes,
    this.onBack,
    this.onOpenFood,
  });

  final String userRegion;
  final FoodItem? Function(String foodId) lookup;
  final int catalogRevision;

  /// Defaults to [kDishCatalog].
  final List<DishRecipe>? dishes;
  final VoidCallback? onBack;
  final ValueChanged<DishPlateRequest> onAddToPlate;
  final ValueChanged<FoodItem>? onOpenFood;

  /// Width from which the list and the selected dish sit side by side.
  static const double splitBreakpoint = 1000;

  @override
  State<AdvancedDishesView> createState() => _AdvancedDishesViewState();
}

class _AdvancedDishesViewState extends State<AdvancedDishesView> {
  static const _view = DishNutritionView();
  final _search = TextEditingController();
  DishRegionFilter _region = const DishRegionMine();
  DishTexture? _texture;
  String? _selectedId;
  late Map<String, DishNutrition> _nutrition;

  List<DishRecipe> get _dishes => widget.dishes ?? kDishCatalog;

  @override
  void initState() {
    super.initState();
    _nutrition = _compute();
    _search.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(AdvancedDishesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.catalogRevision != widget.catalogRevision ||
        oldWidget.dishes != widget.dishes ||
        oldWidget.lookup != widget.lookup) {
      _nutrition = _compute();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Map<String, DishNutrition> _compute() => {
    for (final dish in _dishes) dish.id: _view.compute(dish, widget.lookup),
  };

  bool get _mineHasDishes =>
      _dishes.any((d) => d.regions.contains(widget.userRegion));

  /// The region filter actually applied: "mine" falls back to every region
  /// when no dish is tagged for the user's region.
  DishRegionFilter get _effectiveRegion =>
      _region is DishRegionMine && !_mineHasDishes
      ? const DishRegionAll()
      : _region;

  List<String> get _otherRegions {
    final codes = <String>{for (final d in _dishes) ...d.regions}
      ..remove(widget.userRegion);
    return codes.toList()..sort();
  }

  List<DishRecipe> _visible(AppI18n i18n) {
    final query = _search.text.trim().toLowerCase();
    final region = _effectiveRegion;
    return [
      for (final dish in _dishes)
        if (switch (region) {
              DishRegionMine() => dish.regions.contains(widget.userRegion),
              DishRegionAll() => true,
              DishRegionOne(:final code) => dish.regions.contains(code),
            } &&
            (_texture == null || dish.offersTexture(_texture!)) &&
            (query.isEmpty || _matches(dish, query)))
          dish,
    ];
  }

  static bool _matches(DishRecipe dish, String query) {
    final texts = [
      dish.name.en,
      dish.name.zh,
      for (final i in dish.ingredients) ...[i.name.en, i.name.zh],
    ];
    return texts.any((t) => t.toLowerCase().contains(query));
  }

  bool get _hasFilters =>
      _region is! DishRegionMine ||
      _texture != null ||
      _search.text.trim().isNotEmpty;

  void _clearFilters() => setState(() {
    _region = const DishRegionMine();
    _texture = null;
    _search.clear();
  });

  void _back() {
    final navigator = Navigator.of(context);
    if (widget.onBack == null && navigator.canPop()) {
      navigator.pop();
    } else {
      widget.onBack?.call();
    }
  }

  void _open(DishRecipe dish, bool split) {
    if (split) {
      setState(() => _selectedId = dish.id);
      return;
    }
    final i18n = AppI18nScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        settings: RouteSettings(
          name: '${AdvancedDishesPage.routePath}/${dish.id}',
        ),
        builder: (_) => AppI18nScope(
          i18n: i18n,
          child: _DishDetailPage(
            nutrition: _nutrition[dish.id]!,
            onAddToPlate: widget.onAddToPlate,
            onOpenFood: widget.onOpenFood,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18nScope.of(context);
    final canPop = Navigator.of(context).canPop();
    final showBack = widget.onBack != null || canPop;
    return Scaffold(
      key: const ValueKey('advanced-dishes-page'),
      backgroundColor: DishesPalette.of(context).dark
          ? null
          : Colors.transparent,
      appBar: PaperAppBar(
        title: Text(i18n.tr('dishes.title')),
        chapterTabs: PaperShellScope.showsChapters(context),
        leading: showBack
            ? IconButton(
                key: const ValueKey('dishes-back'),
                tooltip: i18n.tr('dishes.back'),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _back,
              )
            : null,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final split =
              constraints.maxWidth >= AdvancedDishesView.splitBreakpoint;
          final visible = _visible(i18n);
          final list = _listChildren(i18n, visible, split);
          if (!split) {
            return ListView(
              key: const ValueKey('dishes-list'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
              children: list,
            );
          }
          final selected = visible
              .where((d) => d.id == _selectedId)
              .followedBy(visible)
              .firstOrNull;
          final palette = DishesPalette.of(context);
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 460,
                child: ListView(
                  key: const ValueKey('dishes-list'),
                  padding: const EdgeInsets.fromLTRB(28, 8, 20, 40),
                  children: list,
                ),
              ),
              VerticalDivider(width: 1, color: palette.border),
              Expanded(
                child: selected == null
                    ? const SizedBox.shrink()
                    : ListView(
                        key: ValueKey('dish-detail-${selected.id}'),
                        padding: const EdgeInsets.fromLTRB(24, 8, 28, 40),
                        children: [
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 860),
                            child: DishDetailBody(
                              nutrition: _nutrition[selected.id]!,
                              onAddToPlate: widget.onAddToPlate,
                              onOpenFood: widget.onOpenFood,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _listChildren(
    AppI18n i18n,
    List<DishRecipe> visible,
    bool split,
  ) {
    final p = DishesPalette.of(context);
    final mineLabel = i18n.tr('dishes.region_mine', {
      'region': dishRegionLabel(i18n, widget.userRegion),
    });
    final effective = _effectiveRegion;
    final selectedId = split
        ? (visible.any((d) => d.id == _selectedId)
              ? _selectedId
              : visible.firstOrNull?.id)
        : null;
    return [
      Text(
        i18n.tr('dishes.subtitle'),
        style: TextStyle(fontSize: 14, height: 1.45, color: p.muted),
      ),
      const SizedBox(height: 12),
      DishesNote(
        key: const ValueKey('dishes-framing'),
        text: i18n.tr('dishes.framing'),
        tone: DishTagTone.info,
      ),
      const SizedBox(height: 16),
      TextField(
        key: const ValueKey('dishes-search'),
        controller: _search,
        decoration: InputDecoration(
          labelText: i18n.tr('dishes.search_label'),
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _search.text.isEmpty
              ? null
              : IconButton(
                  tooltip: i18n.tr('dishes.search_clear'),
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _search.clear,
                ),
        ),
      ),
      const SizedBox(height: 16),
      DishesHeading(i18n.tr('dishes.region_title')),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          DishesChoice(
            key: const ValueKey('dishes-region-mine'),
            label: mineLabel,
            selected: _region is DishRegionMine,
            onSelected: () => setState(() => _region = const DishRegionMine()),
          ),
          DishesChoice(
            key: const ValueKey('dishes-region-all'),
            label: i18n.tr('dishes.region_all'),
            selected: _region is DishRegionAll,
            onSelected: () => setState(() => _region = const DishRegionAll()),
          ),
          _OtherRegionsButton(
            regions: _otherRegions,
            selected: switch (_region) {
              DishRegionOne(:final code) => code,
              _ => null,
            },
            onSelected: (code) => setState(() => _region = DishRegionOne(code)),
          ),
        ],
      ),
      if (_region is DishRegionMine && !_mineHasDishes) ...[
        const SizedBox(height: 8),
        DishesNote(
          key: const ValueKey('dishes-region-fallback'),
          text: i18n.tr('dishes.region_none_for_mine', {
            'region': dishRegionLabel(i18n, widget.userRegion),
          }),
        ),
      ],
      const SizedBox(height: 16),
      DishesHeading(i18n.tr('dishes.texture_title')),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          DishesChoice(
            key: const ValueKey('dishes-texture-any'),
            label: i18n.tr('dishes.texture_any'),
            selected: _texture == null,
            onSelected: () => setState(() => _texture = null),
          ),
          for (final texture in DishTexture.values.skip(1))
            DishesChoice(
              key: ValueKey('dishes-texture-${texture.name}'),
              label: dishTextureLabel(i18n, texture),
              selected: _texture == texture,
              onSelected: () => setState(() => _texture = texture),
            ),
        ],
      ),
      const SizedBox(height: 6),
      Text(
        i18n.tr('dishes.texture_filter_note'),
        style: TextStyle(fontSize: 12.5, height: 1.4, color: p.muted),
      ),
      const SizedBox(height: 16),
      Row(
        children: [
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                i18n.tr('dishes.result_count', {'count': '${visible.length}'}),
                key: const ValueKey('dishes-result-count'),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          if (_hasFilters)
            TextButton(
              key: const ValueKey('dishes-clear-filters'),
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              onPressed: _clearFilters,
              child: Text(i18n.tr('dishes.clear_filters')),
            ),
        ],
      ),
      const SizedBox(height: 8),
      if (visible.isEmpty)
        DishesNote(
          key: const ValueKey('dishes-empty'),
          text: i18n.tr('dishes.empty'),
        ),
      for (final dish in visible) ...[
        _DishCard(
          nutrition: _nutrition[dish.id]!,
          selected: dish.id == selectedId,
          showRegions: effective is! DishRegionMine,
          onOpen: () => _open(dish, split),
        ),
        const SizedBox(height: 10),
      ],
      const SizedBox(height: 8),
      DishesNote(
        key: const ValueKey('dishes-texture-boundary'),
        text: i18n.tr('dishes.texture_boundary'),
      ),
      const SizedBox(height: 8),
      Text(
        i18n.tr('dishes.provenance_version', {'version': kDishCatalogVersion}),
        style: TextStyle(fontSize: 11.5, color: p.muted),
      ),
    ];
  }
}

/// "Other regions": a menu button listing the remaining region tags.
class _OtherRegionsButton extends StatelessWidget {
  const _OtherRegionsButton({
    required this.regions,
    required this.selected,
    required this.onSelected,
  });

  final List<String> regions;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18nScope.of(context);
    final code = selected;
    final label = code == null
        ? i18n.tr('dishes.region_others')
        : dishRegionLabel(i18n, code);
    return MenuAnchor(
      menuChildren: [
        for (final region in regions)
          MenuItemButton(
            key: ValueKey('dishes-region-$region'),
            style: MenuItemButton.styleFrom(minimumSize: const Size(160, 48)),
            onPressed: () => onSelected(region),
            child: Text(dishRegionLabel(i18n, region)),
          ),
      ],
      builder: (context, controller, _) => DishesChoice(
        key: const ValueKey('dishes-region-others'),
        label: label,
        menu: true,
        selected: code != null,
        onSelected: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _DishCard extends StatelessWidget {
  const _DishCard({
    required this.nutrition,
    required this.selected,
    required this.showRegions,
    required this.onOpen,
  });

  final DishNutrition nutrition;
  final bool selected;
  final bool showRegions;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18nScope.of(context);
    final p = DishesPalette.of(context);
    final dish = nutrition.dish;
    final family = i18n.languageFamily;
    final name = dish.name.forFamily(family);
    // Only Chinese pages carry the English name as a secondary line; other
    // languages show the one name rather than a second script.
    final otherName = family == 'zh' ? dish.name.en : null;
    final protein = nutrition.total(DishNutrient.protein);
    final energy = nutrition.total(DishNutrient.energy);
    final minutes = i18n.tr('dishes.minutes', {
      'minutes': '${dish.totalMinutes}',
    });
    final texture = dishTextureLabel(i18n, dish.texture);
    final option = dish.textureOption;
    final semantics = [
      name,
      if (showRegions)
        dish.regions.map((r) => dishRegionLabel(i18n, r)).join(', '),
      minutes,
      texture,
      if (option != null)
        i18n.tr('dishes.texture_option', {
          'texture': dishTextureLabel(i18n, option.texture),
        }),
      '${dishNutrientLabel(i18n, DishNutrient.protein)}: ${dishNutrientValueText(i18n, protein)}',
      dishCoverageText(i18n, nutrition),
    ].join('. ');
    return Semantics(
      button: true,
      selected: selected,
      label: semantics,
      excludeSemantics: true,
      child: DishesCard(
        key: ValueKey('dish-card-${dish.id}'),
        selected: selected,
        padding: EdgeInsets.zero,
        child: InkWell(
          onTap: onOpen,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontFamily: Paper.serif,
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            color: p.ink,
                          ),
                        ),
                        if (otherName != null && otherName != name)
                          Text(
                            otherName,
                            style: TextStyle(fontSize: 12.5, color: p.muted),
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (showRegions)
                              for (final region in dish.regions)
                                DishTag(label: dishRegionLabel(i18n, region)),
                            DishTag(
                              label: minutes,
                              icon: Icons.schedule_rounded,
                            ),
                            DishTag(label: texture, tone: DishTagTone.info),
                            if (option != null)
                              DishTag(
                                label: i18n.tr('dishes.texture_option', {
                                  'texture': dishTextureLabel(
                                    i18n,
                                    option.texture,
                                  ),
                                }),
                                tone: DishTagTone.info,
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${dishNutrientLabel(i18n, DishNutrient.protein)} '
                          '${dishNutrientValueText(i18n, protein)} · '
                          '${dishNutrientLabel(i18n, DishNutrient.energy)} '
                          '${dishNutrientValueText(i18n, energy)}',
                          style: TextStyle(fontSize: 13, color: p.ink),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dishCoverageText(i18n, nutrition),
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                nutrition.resolvedCount ==
                                    nutrition.ingredientCount
                                ? p.muted
                                : p.warn,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: p.muted),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The dish shown on its own on narrow screens.
class _DishDetailPage extends StatelessWidget {
  const _DishDetailPage({
    required this.nutrition,
    required this.onAddToPlate,
    this.onOpenFood,
  });

  final DishNutrition nutrition;
  final ValueChanged<DishPlateRequest> onAddToPlate;
  final ValueChanged<FoodItem>? onOpenFood;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18nScope.of(context);
    return Scaffold(
      key: ValueKey('dish-detail-page-${nutrition.dish.id}'),
      backgroundColor: DishesPalette.of(context).dark ? null : Paper.canvas,
      appBar: PaperAppBar(
        title: Text(nutrition.dish.name.forFamily(i18n.languageFamily)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          DishDetailBody(
            nutrition: nutrition,
            onAddToPlate: onAddToPlate,
            onOpenFood: onOpenFood,
            showTitle: false,
          ),
        ],
      ),
    );
  }
}

/// Ingredients, steps, time, texture and the per-serving nutrition panel of
/// one dish.
class DishDetailBody extends StatelessWidget {
  const DishDetailBody({
    super.key,
    required this.nutrition,
    required this.onAddToPlate,
    this.onOpenFood,
    this.showTitle = true,
  });

  final DishNutrition nutrition;
  final ValueChanged<DishPlateRequest> onAddToPlate;
  final ValueChanged<FoodItem>? onOpenFood;
  final bool showTitle;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18nScope.of(context);
    final p = DishesPalette.of(context);
    final dish = nutrition.dish;
    final family = i18n.languageFamily;
    final name = dish.name.forFamily(family);
    // Only Chinese pages carry the English name as a secondary line; other
    // languages show the one name rather than a second script.
    final otherName = family == 'zh' ? dish.name.en : null;
    final option = dish.textureOption;
    final muted = TextStyle(fontSize: 13, height: 1.45, color: p.muted);
    return Column(
      key: ValueKey('dish-detail-body-${dish.id}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTitle) ...[
          Semantics(
            header: true,
            child: Text(
              name,
              style: TextStyle(
                fontFamily: Paper.serif,
                fontSize: 26,
                fontWeight: FontWeight.w600,
                height: 1.2,
                color: p.ink,
              ),
            ),
          ),
        ],
        if (otherName != null && otherName != name)
          Text(otherName, style: TextStyle(fontSize: 14, color: p.muted)),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final region in dish.regions)
              DishTag(label: dishRegionLabel(i18n, region)),
            DishTag(
              icon: Icons.schedule_rounded,
              label: i18n.tr('dishes.time_detail', {
                'prep': '${dish.prepMinutes}',
                'cook': '${dish.cookMinutes}',
              }),
            ),
            DishTag(
              icon: Icons.restaurant_rounded,
              label: i18n.tr('dishes.servings', {'count': '${dish.servings}'}),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DishesNote(text: i18n.tr('dishes.framing'), tone: DishTagTone.info),
        const SizedBox(height: 14),
        _NutritionPanel(nutrition: nutrition),
        const SizedBox(height: 14),
        DishesCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DishesHeading(i18n.tr('dishes.ingredients_title')),
              const SizedBox(height: 6),
              for (final row in nutrition.ingredients)
                _IngredientRow(row: row, onOpenFood: onOpenFood),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  key: const ValueKey('dish-add-to-plate'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    backgroundColor: p.accent,
                    foregroundColor: p.dark ? const Color(0xff1b1815) : null,
                  ),
                  onPressed: () => _addToPlate(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(i18n.tr('dishes.add_to_plate')),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                i18n.tr('dishes.add_to_plate_note', {
                  'count': '${nutrition.resolvedCount}',
                }),
                style: muted,
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DishesCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DishesHeading(i18n.tr('dishes.equipment_title')),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final item in dish.equipment)
                    DishTag(label: i18n.tr('dishes.equipment.${item.name}')),
                ],
              ),
              const SizedBox(height: 16),
              DishesHeading(i18n.tr('dishes.steps_title')),
              const SizedBox(height: 4),
              for (final (index, step) in dish.steps.indexed)
                Semantics(
                  key: ValueKey('dish-step-${index + 1}'),
                  container: true,
                  label: i18n.tr('dishes.step_label', {
                    'step': i18n.tr('dishes.step_n', {'n': '${index + 1}'}),
                    'text': step.forFamily(family),
                  }),
                  excludeSemantics: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 26,
                          height: 26,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.accentSoft,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: p.accentInk,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            step.forFamily(family),
                            style: TextStyle(
                              fontSize: 14.5,
                              height: 1.5,
                              color: p.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        DishesCard(
          child: Column(
            key: const ValueKey('dish-texture'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DishesHeading(i18n.tr('dishes.texture_section')),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: DishTag(
                  label: dishTextureTag(i18n, dish.texture),
                  tone: DishTagTone.info,
                ),
              ),
              if (option != null) ...[
                const SizedBox(height: 10),
                Text(
                  i18n.tr('dishes.texture_option', {
                    'texture': dishTextureTag(i18n, option.texture),
                  }),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  option.note.forFamily(family),
                  style: TextStyle(fontSize: 14, height: 1.5, color: p.ink),
                ),
              ],
              const SizedBox(height: 10),
              DishesNote(text: i18n.tr('dishes.texture_boundary')),
            ],
          ),
        ),
      ],
    );
  }

  void _addToPlate(BuildContext context) {
    final i18n = AppI18nScope.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final request = DishPlateRequest.fromNutrition(
      nutrition,
      catalogVersion: kDishCatalogVersion,
    );
    if (request.items.isEmpty) {
      messenger?.showSnackBar(
        SnackBar(content: Text(i18n.tr('dishes.add_to_plate_unavailable'))),
      );
      return;
    }
    debugPrint(
      '[AdvancedDishes] add_to_plate dish=${request.dishId} '
      'items=${request.items.length}',
    );
    onAddToPlate(request);
    final navigate = PaperShellScope.maybeOf(context)?.navigate;
    messenger?.showSnackBar(
      SnackBar(
        action: navigate == null
            ? null
            : SnackBarAction(
                label: i18n.tr('dishes.open_next_meal'),
                onPressed: () => navigate('next-meal'),
              ),
        content: Text(
          i18n.tr('dishes.added_to_plate', {
            'count': '${request.items.length}',
            'skipped': '${request.skippedIngredientNames.length}',
          }),
        ),
      ),
    );
  }
}

class _IngredientRow extends StatelessWidget {
  const _IngredientRow({required this.row, this.onOpenFood});

  final DishIngredientNutrition row;
  final ValueChanged<FoodItem>? onOpenFood;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18nScope.of(context);
    final p = DishesPalette.of(context);
    final family = i18n.languageFamily;
    final name = row.ingredient.name.forFamily(family);
    final grams = i18n.tr('dishes.grams', {
      'grams': dishGramsText(row.ingredient.gramsPerServing),
    });
    final food = row.food;
    final status = dishIngredientStatusText(i18n, row.status);
    final open = onOpenFood;
    return Semantics(
      key: ValueKey('dish-ingredient-${row.ingredient.foodId ?? name}'),
      container: true,
      label: [name, grams, if (!row.resolved) status].join(', '),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Row(
          children: [
            Expanded(
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: TextStyle(fontSize: 14.5, color: p.ink)),
                    if (!row.resolved)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: DishTag(label: status, tone: DishTagTone.warn),
                      ),
                  ],
                ),
              ),
            ),
            ExcludeSemantics(
              child: Text(
                grams,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: p.ink,
                ),
              ),
            ),
            if (food != null && open != null)
              IconButton(
                key: ValueKey('dish-open-food-${food.id}'),
                tooltip: i18n.tr('dishes.open_catalog', {
                  'name': i18n.foodName(food.id, food.name),
                }),
                icon: Icon(Icons.menu_book_outlined, size: 20, color: p.accent),
                onPressed: () => open(food),
              )
            else
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

class _NutritionPanel extends StatelessWidget {
  const _NutritionPanel({required this.nutrition});

  final DishNutrition nutrition;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18nScope.of(context);
    final p = DishesPalette.of(context);
    final muted = TextStyle(fontSize: 12.5, height: 1.45, color: p.muted);
    return DishesCard(
      key: const ValueKey('dish-nutrition'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DishesHeading(i18n.tr('dishes.nutrition_title')),
          const SizedBox(height: 4),
          Text(
            dishCoverageText(i18n, nutrition),
            key: const ValueKey('dish-coverage'),
            style: TextStyle(
              fontSize: 13,
              color: nutrition.resolvedCount == nutrition.ingredientCount
                  ? p.muted
                  : p.warn,
            ),
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 560 ? 3 : 2;
              final width =
                  (constraints.maxWidth - 8 * (columns - 1)) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final nutrient in DishNutrient.values)
                    SizedBox(
                      width: width,
                      child: DishNutrientTile(total: nutrition.total(nutrient)),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            nutrition.complete
                ? i18n.tr('dishes.complete_all')
                : i18n.tr('dishes.incomplete_note'),
            key: const ValueKey('dish-completeness-note'),
            style: muted,
          ),
          const SizedBox(height: 4),
          Text(i18n.tr('dishes.nutrition_note'), style: muted),
          const SizedBox(height: 4),
          Text(i18n.tr('dishes.lnaa_note'), style: muted),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const ValueKey('dish-provenance'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: p.accentInk,
                side: BorderSide(color: p.border),
              ),
              onPressed: () => showDishProvenanceSheet(context, nutrition),
              icon: const Icon(Icons.source_outlined, size: 18),
              label: Text(i18n.tr('dishes.provenance_button')),
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the per-ingredient sources and values of [nutrition].
Future<void> showDishProvenanceSheet(
  BuildContext context,
  DishNutrition nutrition,
) {
  final i18n = AppI18nScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: DishesPalette.of(context).surface,
    constraints: const BoxConstraints(maxWidth: 760),
    builder: (sheetContext) => AppI18nScope(
      i18n: i18n,
      child: FractionallySizedBox(
        heightFactor: 0.88,
        child: _ProvenanceSheet(nutrition: nutrition),
      ),
    ),
  );
}

class _ProvenanceSheet extends StatelessWidget {
  const _ProvenanceSheet({required this.nutrition});

  final DishNutrition nutrition;

  static const _fieldNutrients = {
    'proteinG': DishNutrient.protein,
    'energyKcal': DishNutrient.energy,
    'fatG': DishNutrient.fat,
    'carbsG': DishNutrient.carbohydrate,
    'fiberG': DishNutrient.fiber,
  };

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18nScope.of(context);
    final p = DishesPalette.of(context);
    final family = i18n.languageFamily;
    final small = TextStyle(fontSize: 12.5, height: 1.45, color: p.muted);
    return Column(
      key: const ValueKey('dish-provenance-sheet'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
          child: Row(
            children: [
              Expanded(
                child: DishesHeading(i18n.tr('dishes.provenance_title')),
              ),
              TextButton(
                key: const ValueKey('dish-provenance-close'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: () => Navigator.of(context).pop(),
                child: Text(i18n.tr('dishes.close')),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [
              Text(i18n.tr('dishes.provenance_intro'), style: small),
              const SizedBox(height: 8),
              for (final row in nutrition.ingredients) ...[
                Divider(color: p.border, height: 20),
                Semantics(
                  key: ValueKey(
                    'dish-provenance-${row.ingredient.foodId ?? row.ingredient.name.en}',
                  ),
                  container: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${row.ingredient.name.forFamily(family)} · '
                        '${i18n.tr('dishes.grams', {'grams': dishGramsText(row.ingredient.gramsPerServing)})}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: p.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (row.food case final food?) ...[
                        Text(
                          i18n.tr('dishes.provenance_catalog_food', {
                            'name': i18n.foodName(food.id, food.name),
                          }),
                          style: TextStyle(fontSize: 13, color: p.ink),
                        ),
                        Text(
                          i18n.tr('dishes.provenance_source', {
                            'system': food.sourceSystem,
                            'code': food.sourceFoodCode ?? food.id,
                          }),
                          style: small,
                        ),
                        if (food.description.isNotEmpty)
                          Text(food.description, style: small),
                      ],
                      if (!row.resolved)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: DishTag(
                            label: dishIngredientStatusText(i18n, row.status),
                            tone: DishTagTone.warn,
                          ),
                        )
                      else ...[
                        if (_missing(row).isNotEmpty)
                          Text(
                            i18n.tr('dishes.provenance_missing', {
                              'fields': _missing(row)
                                  .map((n) => dishNutrientLabel(i18n, n))
                                  .join(', '),
                            }),
                            style: TextStyle(fontSize: 12.5, color: p.warn),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            for (final nutrient in DishNutrient.values)
                              '${dishNutrientLabel(i18n, nutrient)} '
                                  '${dishIngredientValueText(i18n, row, nutrient)}',
                          ].join(' · '),
                          style: TextStyle(fontSize: 12.5, color: p.ink),
                        ),
                        Text(switch (row.lnaaBasis) {
                          DishLnaaBasis.measuredProfile => i18n.tr(
                            'dishes.provenance_lnaa_measured',
                          ),
                          DishLnaaBasis.zeroProtein => i18n.tr(
                            'dishes.provenance_lnaa_zero',
                          ),
                          DishLnaaBasis.unknown => i18n.tr(
                            'dishes.provenance_lnaa_unknown',
                          ),
                        }, style: small),
                      ],
                    ],
                  ),
                ),
              ],
              Divider(color: p.border, height: 24),
              Text(i18n.tr('dishes.nutrition_note'), style: small),
              Text(
                i18n.tr('dishes.provenance_version', {
                  'version': kDishCatalogVersion,
                }),
                style: small,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static List<DishNutrient> _missing(DishIngredientNutrition row) => [
    for (final entry in _fieldNutrients.entries)
      if (row.food!.isNutrientMissing(entry.key)) entry.value,
  ];
}
