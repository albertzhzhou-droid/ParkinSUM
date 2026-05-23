class ResolvedFoodVariant {
  final String foodId;
  final String selectedVariantId;
  final String conceptId;
  final String jurisdiction;
  final String sourceFamily;
  final bool fallbackUsed;
  final bool authoritativeForRegion;

  const ResolvedFoodVariant({
    required this.foodId,
    required this.selectedVariantId,
    required this.conceptId,
    required this.jurisdiction,
    required this.sourceFamily,
    required this.fallbackUsed,
    required this.authoritativeForRegion,
  });
}

class ResolvedDrugVariant {
  final String drugId;
  final String selectedVariantId;
  final String conceptId;
  final String jurisdiction;
  final String regulator;
  final String route;
  final String dosageForm;
  final String releaseType;
  final bool fallbackUsed;

  const ResolvedDrugVariant({
    required this.drugId,
    required this.selectedVariantId,
    required this.conceptId,
    required this.jurisdiction,
    required this.regulator,
    required this.route,
    required this.dosageForm,
    required this.releaseType,
    required this.fallbackUsed,
  });
}
