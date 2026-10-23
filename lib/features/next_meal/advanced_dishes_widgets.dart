import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/dish_recipe.dart';
import '../../domain/usecases/dish_nutrition_view.dart';

// Presentation of Next meal → Advanced. Values come from DishNutritionView;
// these widgets format them and never order, score or recommend dishes.
// Every control is a button or text field at least 48 px tall.

/// Colours for the ambient brightness (Paper tokens in light mode).
final class DishesPalette {
  const DishesPalette._({
    required this.dark,
    required this.surface,
    required this.sunken,
    required this.border,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.accentInk,
    required this.accentSoft,
    required this.info,
    required this.infoSoft,
    required this.warn,
    required this.warnSoft,
  });

  final bool dark;
  final Color surface;
  final Color sunken;
  final Color border;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color accentInk;
  final Color accentSoft;
  final Color info;
  final Color infoSoft;
  final Color warn;
  final Color warnSoft;

  static DishesPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? _dark : _light;

  static const _light = DishesPalette._(
    dark: false,
    surface: Paper.surface,
    sunken: Paper.surfaceSunken,
    border: Paper.border,
    ink: Paper.ink,
    muted: Paper.inkMuted,
    accent: Paper.accent,
    accentInk: Paper.accentInk,
    accentSoft: Paper.accentSoft,
    info: Paper.info,
    infoSoft: Paper.infoSoft,
    warn: Paper.warning,
    warnSoft: Paper.warningSoft,
  );

  static const _dark = DishesPalette._(
    dark: true,
    surface: Color(0xff23201c),
    sunken: Color(0xff2c2823),
    border: Color(0xff3a342e),
    ink: Color(0xffece6de),
    muted: Color(0xffa59b90),
    accent: Color(0xfff08a5d),
    accentInk: Color(0xfff08a5d),
    accentSoft: Color(0xff3d2a20),
    info: Color(0xff9cbfe6),
    infoSoft: Color(0xff1f2a36),
    warn: Color(0xffe0b84a),
    warnSoft: Color(0xff3a2f1b),
  );
}

/// "150" or "0.5".
String dishGramsText(double grams) => grams == grams.roundToDouble()
    ? grams.toStringAsFixed(0)
    : grams.toStringAsFixed(1);

String dishNutrientLabel(AppI18n i18n, DishNutrient nutrient) =>
    i18n.tr('dishes.nutrient.${nutrient.name}');

String _amount(AppI18n i18n, DishNutrient nutrient, double value) =>
    nutrient == DishNutrient.energy
    ? '${value.toStringAsFixed(0)} kcal'
    : i18n.tr('dishes.grams', {'grams': value.toStringAsFixed(1)});

/// "12.3 g", "Unknown", or "8.1 g from 5 of 7 ingredients".
String dishNutrientValueText(AppI18n i18n, DishNutrientTotal total) {
  if (!total.anyKnown) return i18n.tr('dishes.value_unknown');
  final value = _amount(i18n, total.nutrient, total.knownSum);
  if (total.complete) return value;
  return i18n.tr('dishes.value_partial', {
    'value': value,
    'known': '${total.knownCount}',
    'total': '${total.ingredientCount}',
  });
}

/// One ingredient's amount, or "Unknown".
String dishIngredientValueText(
  AppI18n i18n,
  DishIngredientNutrition row,
  DishNutrient nutrient,
) {
  final value = row.valueOf(nutrient);
  return value == null
      ? i18n.tr('dishes.value_unknown')
      : _amount(i18n, nutrient, value);
}

String dishTextureLabel(AppI18n i18n, DishTexture texture) =>
    i18n.tr('dishes.texture.${texture.name}');

/// "Minced & moist (IDDSI 5 wording)".
String dishTextureTag(AppI18n i18n, DishTexture texture) =>
    i18n.tr('dishes.texture_tag', {
      'texture': dishTextureLabel(i18n, texture),
      'level': '${texture.iddsiLevel}',
    });

String dishRegionLabel(AppI18n i18n, String code) {
  final key = 'dishes.region.$code';
  final label = i18n.tr(key);
  return label == key ? code : label;
}

String dishIngredientStatusText(AppI18n i18n, DishIngredientStatus status) =>
    switch (status) {
      DishIngredientStatus.notInCatalog => i18n.tr('dishes.not_in_catalog'),
      DishIngredientStatus.catalogIdUnresolved => i18n.tr(
        'dishes.id_unresolved',
      ),
      DishIngredientStatus.noMassBasis => i18n.tr('dishes.no_mass_basis'),
      DishIngredientStatus.resolved => '',
    };

/// Coverage line: "Catalog coverage: 5 of 7 ingredients (93% of ingredient
/// weight)".
String dishCoverageText(AppI18n i18n, DishNutrition nutrition) {
  final total = nutrition.gramsPerServing;
  final percent = total <= 0
      ? 0
      : (nutrition.resolvedGramsPerServing / total * 100).floor();
  return i18n.tr('dishes.completeness', {
    'resolved': '${nutrition.resolvedCount}',
    'total': '${nutrition.ingredientCount}',
    'percent': '$percent',
  });
}

/// A card surface that follows the ambient brightness.
class DishesCard extends StatelessWidget {
  const DishesCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.selected = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final p = DishesPalette.of(context);
    return Material(
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Paper.radiusLg),
        side: BorderSide(
          color: selected ? p.accent : p.border,
          width: selected ? 2 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: DefaultTextStyle.merge(
        style: TextStyle(color: p.ink),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

enum DishTagTone { neutral, accent, info, warn }

/// Compact, non-interactive label.
class DishTag extends StatelessWidget {
  const DishTag({
    super.key,
    required this.label,
    this.tone = DishTagTone.neutral,
    this.icon,
  });

  final String label;
  final DishTagTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final p = DishesPalette.of(context);
    final (bg, fg) = switch (tone) {
      DishTagTone.neutral => (p.sunken, p.ink),
      DishTagTone.accent => (p.accentSoft, p.accentInk),
      DishTagTone.info => (p.infoSoft, p.info),
      DishTagTone.warn => (p.warnSoft, p.dark ? p.warn : Paper.warning),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Paper.radiusXs),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quiet callout for framing and caveats.
class DishesNote extends StatelessWidget {
  const DishesNote({
    super.key,
    required this.text,
    this.icon = Icons.info_outline_rounded,
    this.tone = DishTagTone.neutral,
  });

  final String text;
  final IconData icon;
  final DishTagTone tone;

  @override
  Widget build(BuildContext context) {
    final p = DishesPalette.of(context);
    final (bg, fg) = switch (tone) {
      DishTagTone.info => (p.infoSoft, p.info),
      DishTagTone.warn => (p.warnSoft, p.dark ? p.warn : Paper.warning),
      DishTagTone.accent => (p.accentSoft, p.accentInk),
      DishTagTone.neutral => (p.sunken, p.muted),
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Paper.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 16, color: fg),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: p.dark ? p.ink : Paper.inkSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Section heading inside a card.
class DishesHeading extends StatelessWidget {
  const DishesHeading(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(
      text,
      style: TextStyle(
        fontFamily: Paper.serif,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: DishesPalette.of(context).ink,
      ),
    ),
  );
}

/// A filter choice: a selectable button, at least 48 px tall.
class DishesChoice extends StatelessWidget {
  const DishesChoice({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    this.menu = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  /// Shows a trailing arrow: the button opens a menu.
  final bool menu;

  @override
  Widget build(BuildContext context) {
    final p = DishesPalette.of(context);
    return Semantics(
      selected: selected,
      button: true,
      excludeSemantics: true,
      label: label,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: OutlinedButton.icon(
          onPressed: onSelected,
          icon: selected
              ? Icon(Icons.check_rounded, size: 16, color: p.accentInk)
              : const SizedBox.shrink(),
          label: menu
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(label)),
                    const SizedBox(width: 2),
                    const Icon(Icons.expand_more_rounded, size: 18),
                  ],
                )
              : Text(label),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.fromLTRB(selected ? 10 : 4, 8, 14, 8),
            foregroundColor: selected ? p.accentInk : p.ink,
            backgroundColor: selected ? p.accentSoft : p.surface,
            side: BorderSide(color: selected ? p.accent : p.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(Paper.radiusSm),
            ),
            textStyle: const TextStyle(
              fontFamily: Paper.sans,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// One per-serving nutrient figure.
class DishNutrientTile extends StatelessWidget {
  const DishNutrientTile({super.key, required this.total});

  final DishNutrientTotal total;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18nScope.of(context);
    final p = DishesPalette.of(context);
    final label = dishNutrientLabel(i18n, total.nutrient);
    final known = total.anyKnown;
    final value = known
        ? _amount(i18n, total.nutrient, total.knownSum)
        : i18n.tr('dishes.value_unknown');
    final caption = total.complete || !known
        ? null
        : i18n.tr('dishes.value_partial_caption', {
            'known': '${total.knownCount}',
            'total': '${total.ingredientCount}',
          });
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: '$label: ${dishNutrientValueText(i18n, total)}',
      child: DecoratedBox(
        key: ValueKey('dish-nutrient-${total.nutrient.name}'),
        decoration: BoxDecoration(
          color: p.sunken,
          borderRadius: BorderRadius.circular(Paper.radiusMd),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12.5, color: p.muted, height: 1.3),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontFamily: Paper.serif,
                  fontSize: 22,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                  color: known ? p.ink : p.muted,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  caption,
                  style: TextStyle(fontSize: 12, height: 1.3, color: p.warn),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets the page widgets read the i18n instance they were built with, so
/// they can be pumped in tests without the whole app.
class AppI18nScope extends InheritedWidget {
  const AppI18nScope({super.key, required this.i18n, required super.child});

  final AppI18n i18n;

  static AppI18n of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppI18nScope>()!.i18n;

  @override
  bool updateShouldNotify(AppI18nScope oldWidget) =>
      oldWidget.i18n.localeTag != i18n.localeTag;
}
