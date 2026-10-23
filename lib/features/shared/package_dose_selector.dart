import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/models/drug_definition.dart';
import '../../core/models/medication_product_pack.dart';
import '../../core/services/medication_product_catalog.dart';
import '../../domain/usecases/medication_package_dose_calculator.dart';
import '../medications/medication_product_picker.dart';

/// Unit counts offered once a product with a discrete dose form is chosen.
/// None is preselected; the dose exists only after the person taps one.
const List<double> packageDoseQuantities = <double>[0.5, 1, 1.5, 2, 2.5, 3];

const _calculator = MedicationPackageDoseCalculator();

/// Ingredient words of a catalog medication name, for example
/// "Levodopa/Carbidopa" -> ["levodopa", "carbidopa"].
List<String> medicationIngredientTokens(DrugDefinition drug) => drug.genericName
    .toLowerCase()
    .split(RegExp(r'\s*(?:/|\+|,|\band\b)\s*'))
    .map((token) => token.trim())
    .where((token) => token.isNotEmpty)
    .toList(growable: false);

/// Catalog products whose ingredients are exactly the medication's
/// ingredients and whose strength the package-dose calculator can use, one
/// per distinct dosage form and strength, plain forms first, then by form and
/// strength.
List<MedicationProductPack> packageStrengthOptions(
  MedicationProductCatalog catalog,
  DrugDefinition drug,
) {
  final tokens = medicationIngredientTokens(drug);
  if (tokens.isEmpty) return const <MedicationProductPack>[];
  final byStrength = <String, MedicationProductPack>{};
  for (final product in catalog.products) {
    final names = product.ingredients
        .map((item) => item.ingredientName.toLowerCase())
        .toList(growable: false);
    if (names.length != tokens.length ||
        !tokens.every((token) => names.any((name) => name.contains(token))) ||
        _calculator.preferredIngredient(product) == null) {
      continue;
    }
    final key = _strengthKey(product);
    final current = byStrength[key];
    if (current == null || _preferredRepresentative(product, current)) {
      byStrength[key] = product;
    }
  }
  final options = byStrength.values.toList();
  options.sort(_compareStrength);
  return options;
}

/// A compact strength label, for example "carbidopa/levodopa 25/100 mg ·
/// tablet".
String packageStrengthLabel(MedicationProductPack product) {
  final ingredients = product.ingredients;
  final names = ingredients
      .map((item) => item.ingredientName.trim().toLowerCase())
      .join('/');
  final units = ingredients.map((item) => item.numeratorUnit?.trim()).toSet();
  final amounts =
      units.length == 1 &&
          units.single != null &&
          ingredients.every((item) => item.numeratorValue != null)
      ? '${ingredients.map((item) => _formatNumber(item.numeratorValue!)).join('/')} ${units.single}'
      : ingredients.map((item) => item.displayText).join(' + ');
  return '$names $amounts · ${product.dosageForm.trim().toLowerCase()}';
}

/// The product selection recorded for a confirmed unit count.
MedicationProductSelection packageDoseSelection(
  MedicationProductPack product,
  ConfirmedPackageDose dose,
) => MedicationProductSelection.fromPack(product).withConfirmedQuantity(
  doseBasisIngredient: dose.ingredientName,
  unitQuantity: dose.packageUnitQuantity,
  unitLabel: dose.packageUnitLabel,
  doseDerivation: dose.derivation,
);

String _strengthKey(MedicationProductPack product) => [
  product.dosageForm.trim().toLowerCase(),
  for (final item in product.ingredients)
    '${item.numeratorValue}${item.numeratorUnit}',
].join('|');

bool _preferredRepresentative(
  MedicationProductPack candidate,
  MedicationProductPack current,
) {
  int nameLength(MedicationProductPack product) => product.ingredients.fold(
    0,
    (sum, item) => sum + item.ingredientName.length,
  );
  final byName = nameLength(candidate).compareTo(nameLength(current));
  if (byName != 0) return byName < 0;
  return candidate.id.compareTo(current.id) < 0;
}

int _compareStrength(MedicationProductPack a, MedicationProductPack b) {
  // Plain forms ("TABLET") before qualified ones ("TABLET, EXTENDED RELEASE").
  final qualified = (a.dosageForm.contains(',') ? 1 : 0).compareTo(
    b.dosageForm.contains(',') ? 1 : 0,
  );
  if (qualified != 0) return qualified;
  final form = a.dosageForm.toLowerCase().compareTo(b.dosageForm.toLowerCase());
  if (form != 0) return form;
  for (var i = 0; i < a.ingredients.length; i++) {
    final left = a.ingredients[i].numeratorValue ?? 0;
    final right = b.ingredients[i].numeratorValue ?? 0;
    if (left != right) return left.compareTo(right);
  }
  return a.id.compareTo(b.id);
}

String _formatNumber(double value) =>
    value % 1 == 0 ? value.toInt().toString() : value.toString();

String _quantityLabel(double value) {
  final whole = value.truncate();
  if (value - whole == 0.5) return whole == 0 ? '½' : '$whole½';
  return _formatNumber(value);
}

/// Product strength and unit-count choice shared by the timeline intake editor
/// and onboarding. It only reports what the person taps: choosing a strength
/// selects a product, and only tapping a unit count produces a dose.
class PackageDoseSelector extends StatefulWidget {
  const PackageDoseSelector({
    super.key,
    required this.i18n,
    required this.drug,
    required this.product,
    required this.selection,
    required this.onProductSelected,
    required this.onDoseSelected,
  });

  final AppI18n i18n;
  final DrugDefinition? drug;

  /// The catalog product in hand; null when only a saved selection exists.
  final MedicationProductPack? product;
  final MedicationProductSelection? selection;
  final ValueChanged<MedicationProductPack> onProductSelected;
  final void Function(MedicationProductPack product, ConfirmedPackageDose dose)
  onDoseSelected;

  @override
  State<PackageDoseSelector> createState() => _PackageDoseSelectorState();
}

class _PackageDoseSelectorState extends State<PackageDoseSelector> {
  Future<MedicationProductCatalog>? _catalogFuture;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalogFuture ??= loadBundledMedicationProductCatalog(context);
  }

  Future<void> _searchCatalog() async {
    final drug = widget.drug;
    final product = await showMedicationProductPicker(
      context,
      initialQuery: drug == null
          ? ''
          : medicationIngredientTokens(drug).join(' '),
    );
    if (product == null || !mounted) return;
    widget.onProductSelected(product);
  }

  void _selectQuantity(MedicationProductPack product, double quantity) {
    final dose = _calculator.fromConfirmedQuantity(product, quantity);
    if (dose == null) return;
    widget.onDoseSelected(product, dose);
  }

  @override
  Widget build(BuildContext context) {
    final i18n = widget.i18n;
    final selection = widget.selection;
    final product = widget.product;
    final derivation = selection?.doseDerivation;
    final small = Theme.of(context).textTheme.bodySmall;
    final drug = widget.drug;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (drug != null)
          FutureBuilder<MedicationProductCatalog>(
            future: _catalogFuture,
            builder: (context, snapshot) {
              final catalog = snapshot.data;
              final options = catalog == null
                  ? const <MedicationProductPack>[]
                  : packageStrengthOptions(catalog, drug);
              if (options.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      i18n.tr('package_dose.strength_title'),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(i18n.tr('package_dose.strength_help'), style: small),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final option in options)
                          ChoiceChip(
                            key: ValueKey<String>(
                              'package-strength-${option.id}',
                            ),
                            label: Text(packageStrengthLabel(option)),
                            selected: selection?.packId == option.id,
                            onSelected: (_) => widget.onProductSelected(option),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        OutlinedButton.icon(
          key: const ValueKey<String>('select-medication-product'),
          onPressed: _searchCatalog,
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(i18n.tr('catalog.title')),
        ),
        if (selection != null) ...[
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selection.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    <String>[
                      selection.strengthDisplay,
                      selection.labelerName ?? '',
                      selection.identifierValue,
                      selection.packageDescription,
                    ].where((item) => item.trim().isNotEmpty).join('\n'),
                  ),
                  if (selection.sourceSystem != null &&
                      selection.sourceUrl != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      i18n.tr('timeline.package_dose_source', {
                        'source': selection.sourceSystem!,
                        'url': selection.sourceUrl!,
                        'retrieved':
                            selection.sourceRetrievedAtUtc ??
                            i18n.tr('timeline.package_dose_retrieval_unknown'),
                      }),
                      style: small,
                    ),
                  ],
                  if (product != null &&
                      product.id == selection.packId &&
                      _calculator.preferredIngredient(product) != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      i18n.tr('package_dose.quantity_title', {
                        'unit': product.dosageForm.trim().toLowerCase(),
                      }),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        for (final quantity in packageDoseQuantities)
                          ChoiceChip(
                            key: ValueKey<String>(
                              'package-quantity-${_formatNumber(quantity)}',
                            ),
                            label: Text(_quantityLabel(quantity)),
                            selected:
                                derivation?.packageUnitQuantity == quantity,
                            onSelected: (_) =>
                                _selectQuantity(product, quantity),
                          ),
                      ],
                    ),
                  ],
                  if (derivation != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      i18n.tr('package_dose.result', {
                        'amount': _formatNumber(derivation.resultValue),
                        'unit': derivation.resultUnit,
                        'ingredient': derivation.ingredientName.toLowerCase(),
                      }),
                      key: const ValueKey<String>('package-dose-result'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      i18n.tr('timeline.package_dose_derivation', {
                        'strength': derivation.sourceRawStrength,
                        'quantity': _formatNumber(
                          derivation.packageUnitQuantity,
                        ),
                        'unit': derivation.packageUnitLabel,
                        'amount': _formatNumber(derivation.resultValue),
                        'resultUnit': derivation.resultUnit,
                      }),
                      style: small,
                    ),
                    if (derivation.denominatorDisposition ==
                        'assumed_one_discrete_dosage_unit') ...[
                      const SizedBox(height: 4),
                      Text(
                        i18n.tr('timeline.package_dose_assumed_denominator', {
                          'unit': derivation.packageUnitLabel,
                        }),
                        style: small,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
