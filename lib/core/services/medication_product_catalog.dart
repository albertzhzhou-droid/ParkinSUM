import '../models/medication_product_pack.dart';
import '../../data/datasources/remote/openfda_ndc_product_importer.dart';
import '../../data/datasources/remote/source_fetch_client.dart';

class MedicationProductCatalog {
  final List<MedicationProductPack> products;

  MedicationProductCatalog(Iterable<MedicationProductPack> products)
    : products = List<MedicationProductPack>.unmodifiable(products);

  factory MedicationProductCatalog.fromOpenFdaSnapshot(String json) {
    const importer = OpenFdaNdcProductImporter(
      fetchClient: FakeSourceFetchClient(textByUrl: <String, String>{}),
    );
    return MedicationProductCatalog(importer.importJson(json));
  }

  List<MedicationProductPack> search(String query, {int limit = 30}) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return products.take(limit).toList(growable: false);
    final normalized = normalizeMedicationIdentifier(trimmed);
    final terms = trimmed
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((term) => term.isNotEmpty)
        .toList(growable: false);
    final matches = products
        .where((product) {
          if (normalized.isNotEmpty && product.matchesIdentifier(trimmed)) {
            return true;
          }
          return terms.every(product.searchableText.contains);
        })
        .toList(growable: false);
    matches.sort((a, b) {
      final aExact = a.matchesIdentifier(trimmed) ? 0 : 1;
      final bExact = b.matchesIdentifier(trimmed) ? 0 : 1;
      if (aExact != bExact) return aExact.compareTo(bExact);
      final generic = a.genericName.compareTo(b.genericName);
      if (generic != 0) return generic;
      return a.id.compareTo(b.id);
    });
    return matches.take(limit).toList(growable: false);
  }
}
