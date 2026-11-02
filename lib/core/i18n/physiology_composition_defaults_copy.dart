import '../../domain/usecases/physiology_reference_trace_provider.dart';
import 'app_i18n.dart';

/// The sentence naming the stated defaults the physiology reference model
/// used for a meal, or null when it used none. Shared by the meal check and
/// the Next-meal planner.
String? physiologyCompositionDefaultsText(
  AppI18n i18n,
  PhysiologyCompositionDefaults defaults,
) {
  if (!defaults.anyUsed) return null;
  String item(String key, int count) => i18n.tr(
    'mealcheck.physiology_default_$key',
    {'count': '$count', 'total': '${defaults.foods}'},
  );
  return i18n.tr('mealcheck.physiology_defaults', {
    'items': [
      if (defaults.carbohydrate > 0)
        item('carbohydrate', defaults.carbohydrate),
      if (defaults.proteinType > 0) item('protein_type', defaults.proteinType),
      if (defaults.aminoAcids > 0) item('amino_acids', defaults.aminoAcids),
    ].join(', '),
  });
}
