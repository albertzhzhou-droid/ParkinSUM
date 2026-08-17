import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/models/medication_product_pack.dart';
import '../../core/services/medication_product_catalog.dart';

Future<MedicationProductPack?> showMedicationProductPicker(
  BuildContext context, {
  String initialQuery = '',
}) {
  return Navigator.of(context).push<MedicationProductPack>(
    MaterialPageRoute<MedicationProductPack>(
      fullscreenDialog: true,
      builder: (_) => MedicationProductPickerPage(initialQuery: initialQuery),
    ),
  );
}

class MedicationProductPickerPage extends StatefulWidget {
  final String initialQuery;

  const MedicationProductPickerPage({super.key, this.initialQuery = ''});

  @override
  State<MedicationProductPickerPage> createState() =>
      _MedicationProductPickerPageState();
}

class _MedicationProductPickerPageState
    extends State<MedicationProductPickerPage> {
  late final TextEditingController _searchController;
  Future<MedicationProductCatalog>? _catalogFuture;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _catalogFuture ??= DefaultAssetBundle.of(context)
        .loadString('assets/data/common_medication_products_openfda.json')
        .then(MedicationProductCatalog.fromOpenFdaSnapshot);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    return Scaffold(
      appBar: AppBar(title: Text(i18n.tr('catalog.title'))),
      body: FutureBuilder<MedicationProductCatalog>(
        future: _catalogFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text(i18n.tr('common.error')));
          }
          final catalog = snapshot.data;
          if (catalog == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: TextField(
                  key: const ValueKey<String>('medication-product-search'),
                  controller: _searchController,
                  autofocus: widget.initialQuery.isEmpty,
                  decoration: InputDecoration(
                    labelText: i18n.tr('catalog.search'),
                    prefixIcon: const Icon(Icons.qr_code_scanner),
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final products = catalog.search(_searchController.text);
                    if (products.isEmpty) {
                      return Center(
                        child: Text(i18n.tr('common.not_available')),
                      );
                    }
                    return ListView.separated(
                      itemCount: products.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final product = products[index];
                        String? packageId;
                        for (final identifier in product.identifiers) {
                          if (identifier.system ==
                              MedicationIdentifierSystem.ndcPackage) {
                            packageId = identifier.value;
                            break;
                          }
                        }
                        return ListTile(
                          key: ValueKey<String>(product.id),
                          title: Text(product.primaryDisplayName),
                          subtitle: Text(
                            <String>[
                                  product.strengthDisplay,
                                  if (product.labelerName != null)
                                    product.labelerName!,
                                  if (packageId != null) 'NDC $packageId',
                                  product.packageDescription,
                                ]
                                .where((item) => item.trim().isNotEmpty)
                                .join('\n'),
                          ),
                          isThreeLine: true,
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).pop(product),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
