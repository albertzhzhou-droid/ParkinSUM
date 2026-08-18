import '../../core/models/medication_product_pack.dart';

class ConfirmedPackageDose {
  final String ingredientName;
  final double amount;
  final String unit;
  final double packageUnitQuantity;
  final String packageUnitLabel;

  const ConfirmedPackageDose({
    required this.ingredientName,
    required this.amount,
    required this.unit,
    required this.packageUnitQuantity,
    required this.packageUnitLabel,
  });

  String get dosageNote {
    final amountText = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toString();
    return '$amountText $unit';
  }
}

/// Converts an explicitly confirmed package-unit quantity into one analyzable
/// ingredient dose. It does not select a quantity or infer an intake event.
class MedicationPackageDoseCalculator {
  const MedicationPackageDoseCalculator();

  MedicationIngredientStrength? preferredIngredient(
    MedicationProductPack product,
  ) {
    final analyzable = product.ingredients
        .where(
          (item) =>
              item.numeratorValue != null &&
              item.numeratorUnit != null &&
              (item.denominatorValue == null || item.denominatorValue == 1) &&
              item.denominatorUnit == null,
        )
        .toList(growable: false);
    for (final ingredient in analyzable) {
      if (ingredient.ingredientName.toLowerCase().contains('levodopa')) {
        return ingredient;
      }
    }
    return analyzable.length == 1 ? analyzable.single : null;
  }

  ConfirmedPackageDose? fromConfirmedQuantity(
    MedicationProductPack product,
    double quantity,
  ) {
    if (!quantity.isFinite || quantity <= 0 || quantity > 10) return null;
    final ingredient = preferredIngredient(product);
    if (ingredient == null) return null;
    return ConfirmedPackageDose(
      ingredientName: ingredient.ingredientName,
      amount: ingredient.numeratorValue! * quantity,
      unit: ingredient.numeratorUnit!,
      packageUnitQuantity: quantity,
      packageUnitLabel: product.dosageForm,
    );
  }
}
