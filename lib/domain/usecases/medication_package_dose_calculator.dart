import '../../core/models/medication_product_pack.dart';

class ConfirmedPackageDose {
  final String ingredientName;
  final double amount;
  final String unit;
  final double packageUnitQuantity;
  final String packageUnitLabel;
  final MedicationPackageDoseDerivation derivation;

  const ConfirmedPackageDose({
    required this.ingredientName,
    required this.amount,
    required this.unit,
    required this.packageUnitQuantity,
    required this.packageUnitLabel,
    required this.derivation,
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
    final productDoseUnit = _discreteDoseUnit(
      product.dosageForm,
      dosageForm: true,
    );
    if (productDoseUnit == null ||
        product.sourceSystem.trim().isEmpty ||
        product.sourceUrl.trim().isEmpty ||
        product.identifiers.isEmpty) {
      return null;
    }
    final analyzable = product.ingredients
        .where(
          (item) =>
              item.ingredientName.trim().isNotEmpty &&
              item.numeratorValue != null &&
              item.numeratorValue!.isFinite &&
              item.numeratorValue! > 0 &&
              item.numeratorUnit != null &&
              item.numeratorUnit!.trim().isNotEmpty &&
              item.rawStrength.trim().isNotEmpty &&
              _hasOneDiscreteUnitDenominator(item, productDoseUnit),
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
    final amount = ingredient.numeratorValue! * quantity;
    if (!amount.isFinite || amount <= 0) return null;
    final denominatorDisposition =
        ingredient.denominatorValue == null &&
            ingredient.denominatorUnit == null
        ? 'assumed_one_discrete_dosage_unit'
        : ingredient.denominatorUnit == null
        ? 'source_numeric_one'
        : 'source_one_matching_dosage_unit';
    final unit = ingredient.numeratorUnit!.trim();
    final packageUnitLabel = product.dosageForm.trim();
    final derivation = MedicationPackageDoseDerivation(
      ingredientName: ingredient.ingredientName.trim(),
      sourceRawStrength: ingredient.rawStrength.trim(),
      numeratorValue: ingredient.numeratorValue!,
      numeratorUnit: unit,
      denominatorValue: ingredient.denominatorValue,
      denominatorUnit: ingredient.denominatorUnit?.trim(),
      denominatorDisposition: denominatorDisposition,
      packageUnitQuantity: quantity,
      packageUnitLabel: packageUnitLabel,
      resultValue: amount,
      resultUnit: unit,
    );
    return ConfirmedPackageDose(
      ingredientName: ingredient.ingredientName.trim(),
      amount: amount,
      unit: unit,
      packageUnitQuantity: quantity,
      packageUnitLabel: packageUnitLabel,
      derivation: derivation,
    );
  }

  bool _hasOneDiscreteUnitDenominator(
    MedicationIngredientStrength ingredient,
    String productDoseUnit,
  ) {
    final denominator = ingredient.denominatorValue;
    if (denominator == null) {
      return ingredient.denominatorUnit == null;
    }
    if (!denominator.isFinite || denominator != 1) return false;
    final denominatorUnit = ingredient.denominatorUnit;
    return denominatorUnit == null ||
        _discreteDoseUnit(denominatorUnit) == productDoseUnit;
  }

  /// Only discrete oral unit forms have a safely inferable one-unit basis in
  /// this bounded calculator. Solution and concentration expressions remain
  /// held until a governed volume denominator is implemented.
  String? _discreteDoseUnit(String raw, {bool dosageForm = false}) {
    final normalized = raw.toLowerCase().replaceAll('_', ' ').trim();
    if (!dosageForm) {
      return switch (normalized) {
        'tablet' || 'tablets' => 'tablet',
        'capsule' || 'capsules' => 'capsule',
        'caplet' || 'caplets' => 'caplet',
        _ => null,
      };
    }
    if (RegExp(
      r'\b(solution|suspension|liquid|injection|cream|gel)\b',
    ).hasMatch(normalized)) {
      return null;
    }
    final match = RegExp(
      r'^\s*(tablet|tablets|capsule|capsules|caplet|caplets)\b',
    ).firstMatch(normalized);
    return switch (match?.group(1)) {
      'tablet' || 'tablets' => 'tablet',
      'capsule' || 'capsules' => 'capsule',
      'caplet' || 'caplets' => 'caplet',
      _ => null,
    };
  }
}
