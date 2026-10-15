import 'fdc_nutrient_definitions.dart';

export '../../../core/models/food_item.dart' show FdcFoodBasis;

/// Compatibility view of the authoritative current-release definitions.
/// Quantity names and nutrient identities have one owner; no second inventory
/// can assign a different meaning to carbohydrate, sugars or vitamin forms.
final fdcNutrientIdentities =
    List<(String, String, String, String)>.unmodifiable(
      fdcNutrientDefinitions.map(
        (definition) => (
          '${definition.id}',
          definition.number,
          definition.attributeCode,
          definition.name,
        ),
      ),
    );

String? fdcNutrientAttributeCode({
  Object? nutrientId,
  required String nutrientNumber,
  required String nutrientName,
}) {
  final id = int.tryParse('${nutrientId ?? ''}'.trim());
  final number = nutrientNumber.trim();
  if (id != null && number.isNotEmpty) {
    final byId = resolveFdcNutrient(id: id);
    if (byId.definition?.number == number) {
      return byId.definition?.attributeCode;
    }
    return resolveFdcNutrient(
      number: number,
      name: nutrientName,
    ).definition?.attributeCode;
  }
  return resolveFdcNutrient(
    id: id,
    number: number,
    name: nutrientName,
  ).definition?.attributeCode;
}

/// Spelling normalization only; this performs no quantity conversion.
String canonicalFdcNutrientUnit(String unit) =>
    switch (normalizeFdcUnit(unit)) {
      'KCAL' => 'kcal',
      'KJ' => 'kJ',
      'G' => 'g',
      'MG' => 'mg',
      'UG' => 'ug',
      final normalized => normalized ?? unit,
    };
