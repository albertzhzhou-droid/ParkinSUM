import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models/medication_product_pack.dart';
import '../../core/services/medication_product_catalog.dart';
import '../../core/theme/paper_theme.dart';
import '../../domain/entities/fhir_r5_medication_product_preview.dart';
import '../../domain/entities/openfda_strength_expression_source_manifest.dart';
import '../../domain/usecases/fhir_r5_medication_product_preview_service.dart';
import '../../domain/usecases/openfda_strength_expression_source_manifest_builder.dart';

/// Read-only, offline inspection of the bounded FHIR R5 Medication projection.
///
/// This page reads only the bundled product snapshot. It does not accept care
/// records, save or send data, run a validator, or feed an algorithm.
class FhirR5MedicationProductPreviewPage extends StatefulWidget {
  const FhirR5MedicationProductPreviewPage({
    super.key,
    required this.localeTag,
    this.snapshotBytesLoader,
  });

  static const snapshotAsset =
      'assets/data/common_medication_products_openfda.json';

  final String localeTag;
  final Future<List<int>> Function()? snapshotBytesLoader;

  @override
  State<FhirR5MedicationProductPreviewPage> createState() =>
      _FhirR5MedicationProductPreviewPageState();
}

class _FhirR5MedicationProductPreviewPageState
    extends State<FhirR5MedicationProductPreviewPage> {
  final _search = TextEditingController();
  final _service = const FhirR5MedicationProductPreviewService();
  MedicationProductCatalog? _catalog;
  OpenFdaStrengthExpressionSourceManifest? _sourceManifest;
  FhirR5MedicationProductPreview? _preview;
  String? _selectedProductId;
  String? _loadError;
  String _query = '';
  bool _loading = true;

  bool get _isChinese => widget.localeTag.toLowerCase().startsWith('zh');

  String _text(String english, String chinese) =>
      _isChinese ? chinese : english;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    try {
      final bytes =
          await (widget.snapshotBytesLoader ?? _loadBundledSnapshotBytes)();
      final sourceManifest =
          const OpenFdaStrengthExpressionSourceManifestBuilder().buildFromBytes(
            bytes,
          );
      final catalog = MedicationProductCatalog.fromOpenFdaSnapshot(
        utf8.decode(bytes),
      );
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _sourceManifest = sourceManifest;
        _loading = false;
        _select(catalog.products.isEmpty ? null : catalog.products.first.id);
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = _text(
          'The bundled product snapshot could not be opened.',
          '无法读取内置产品快照。',
        );
      });
    }
  }

  Future<List<int>> _loadBundledSnapshotBytes() async {
    final data = await rootBundle.load(
      FhirR5MedicationProductPreviewPage.snapshotAsset,
    );
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  List<MedicationProductPack> get _visibleProducts =>
      _catalog?.search(_query, limit: 100) ?? const <MedicationProductPack>[];

  MedicationProductPack? get _selectedProduct {
    final id = _selectedProductId;
    if (id == null) return null;
    for (final product
        in _catalog?.products ?? const <MedicationProductPack>[]) {
      if (product.id == id) return product;
    }
    return null;
  }

  void _select(String? id) {
    _selectedProductId = id;
    final product = _selectedProduct;
    _preview = product == null
        ? null
        : _service.projectProductPack(
            product,
            observedAt: DateTime.now(),
            sourceManifest: _sourceManifest,
          );
  }

  void _updateQuery(String value) {
    setState(() {
      _query = value;
      final visible = _visibleProducts;
      if (!visible.any((product) => product.id == _selectedProductId)) {
        _select(visible.isEmpty ? null : visible.first.id);
      }
    });
  }

  String _productLabel(MedicationProductPack product) {
    final form = product.dosageForm.trim();
    final strength = product.strengthDisplay;
    final detail = <String>[
      if (form.isNotEmpty) form,
      if (strength.isNotEmpty) strength,
    ].join(' · ');
    return detail.isEmpty
        ? product.primaryDisplayName
        : '${product.primaryDisplayName} · $detail';
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedProduct;
    final preview = _preview;
    final visible = _visibleProducts;
    final json = preview == null
        ? null
        : const JsonEncoder.withIndent('  ').convert(preview.toJson());
    final projectedStrengths =
        preview?.productStrengthEvidence
            .where(
              (evidence) => evidence['fhir_strength_path_projected'] == true,
            )
            .length ??
        0;
    final strengthCount = preview?.productStrengthEvidence.length ?? 0;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: PaperAppBar(
        title: Text(
          _text('FHIR R5 medication product preview', 'FHIR R5 药品产品预览'),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                PaperCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _text('Offline development preview', '离线开发预览'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _text(
                          'Reads the bundled openFDA product snapshot only. Its records are dated research fixtures and are not independently verified here. Product strength is not an administration dose. This fragment is not validated, saved, exchanged, or used by an algorithm.',
                          '仅读取应用内置的 openFDA 产品快照。这里的记录是带日期的研究样本，尚未独立核验。产品强度不等于实际给药剂量。该片段未经验证，不会保存、交换或进入算法。',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_loadError != null)
                  PaperCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(_loadError!),
                    ),
                  )
                else if (_catalog == null || _catalog!.products.isEmpty)
                  PaperCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _text(
                          'No product rows are available in this snapshot.',
                          '此快照中没有可用的产品记录。',
                        ),
                      ),
                    ),
                  )
                else ...[
                  PaperCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          key: const Key('fhir-r5-product-search'),
                          controller: _search,
                          onChanged: _updateQuery,
                          decoration: InputDecoration(
                            labelText: _text('Search snapshot', '搜索快照'),
                            hintText: _text(
                              'Product name or identifier',
                              '产品名称或标识符',
                            ),
                            prefixIcon: const Icon(Icons.search),
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 14),
                        DropdownButtonFormField<String>(
                          key: const Key('fhir-r5-product-selector'),
                          initialValue:
                              visible.any(
                                (product) => product.id == _selectedProductId,
                              )
                              ? _selectedProductId
                              : null,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: _text('Source product', '来源产品'),
                            border: const OutlineInputBorder(),
                          ),
                          items: [
                            for (final product in visible)
                              DropdownMenuItem<String>(
                                value: product.id,
                                child: Text(
                                  _productLabel(product),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: visible.isEmpty
                              ? null
                              : (id) => setState(() => _select(id)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _text(
                            '${_catalog!.products.length} imported product rows · showing ${visible.length} matches',
                            '已导入 ${_catalog!.products.length} 条产品记录 · 当前显示 ${visible.length} 条匹配项',
                          ),
                        ),
                        if (visible.isEmpty) ...[
                          const SizedBox(height: 10),
                          Text(_text('No matches.', '没有匹配项。')),
                        ],
                      ],
                    ),
                  ),
                  if (selected != null) ...[
                    const SizedBox(height: 12),
                    PaperCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text('Source record details', '来源记录详情'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            'Source: ${selected.sourceSystem} · ${selected.jurisdiction}',
                          ),
                          SelectableText('URL: ${selected.sourceUrl}'),
                          SelectableText('Product ID: ${selected.id}'),
                          if (_sourceManifest != null &&
                              selected.sourceSystem ==
                                  OpenFdaStrengthExpressionSourceManifest
                                      .sourceSystem) ...[
                            SelectableText(
                              'Snapshot SHA-256: ${_sourceManifest!.sourceAssetSha256}',
                            ),
                            SelectableText(
                              'Source manifest SHA-256: ${_sourceManifest!.sha256}',
                            ),
                          ],
                          SelectableText(
                            'Retrieved at: ${selected.retrievedAt?.toUtc().toIso8601String() ?? 'not supplied'}',
                          ),
                          for (final ingredient in selected.ingredients)
                            SelectableText(
                              '${ingredient.ingredientName}: ${ingredient.rawStrength.isEmpty ? 'strength not supplied' : ingredient.rawStrength}',
                            ),
                        ],
                      ),
                    ),
                  ],
                  if (preview != null && json != null) ...[
                    const SizedBox(height: 12),
                    PaperCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            preview.status ==
                                    FhirR5MedicationProductPreviewStatus
                                        .projected
                                ? _text(
                                    'Metadata fragment projected',
                                    '已投影元数据片段',
                                  )
                                : _text('Projection held', '投影已暂停'),
                            key: const Key('fhir-r5-preview-status'),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _text(
                              '$projectedStrengths of $strengthCount ingredient strengthQuantity paths projected; all remain algorithm-ineligible.',
                              '$strengthCount 个成分中有 $projectedStrengths 个 strengthQuantity 路径被投影；所有结果均不可供算法使用。',
                            ),
                          ),
                          const SizedBox(height: 12),
                          SelectableText(
                            json,
                            key: const Key('fhir-r5-preview-json'),
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
