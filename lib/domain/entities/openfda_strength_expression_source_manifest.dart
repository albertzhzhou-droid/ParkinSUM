import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'openfda_strength_expression.dart';

/// One source-bound openFDA active-ingredient strength row.
final class OpenFdaStrengthExpressionSourceRow {
  const OpenFdaStrengthExpressionSourceRow({
    required this.sourceAssetSha256,
    required this.productNdc,
    required this.productId,
    required this.splId,
    required this.ingredientIndex,
    required this.ingredientName,
    required this.parseResult,
  });

  final String sourceAssetSha256;
  final String productNdc;
  final String productId;
  final String splId;
  final int ingredientIndex;
  final String ingredientName;
  final OpenFdaStrengthExpressionParseResult parseResult;

  String get sha256 => crypto.sha256
      .convert(
        utf8.encode(
          jsonEncode(<Object?>[
            OpenFdaStrengthExpressionSourceManifest.schemaUri,
            sourceAssetSha256,
            productNdc,
            productId,
            splId,
            ingredientIndex,
            ingredientName,
            parseResult.sha256,
          ]),
        ),
      )
      .toString();

  Map<String, Object?> toJson() =>
      Map<String, Object?>.unmodifiable(<String, Object?>{
        'product_ndc': productNdc,
        'product_id': productId,
        'spl_id': splId,
        'ingredient_index': ingredientIndex,
        'ingredient_name': ingredientName,
        'parser_result': parseResult.toJson(),
        'source_asset_sha256': sourceAssetSha256,
        'sha256': sha256,
      });
}

/// Content-addressed provenance manifest for a local openFDA NDC snapshot.
///
/// It binds each lexical parse result to the snapshot digest and the product,
/// SPL, and ingredient-row identities. The manifest is source evidence only;
/// it does not validate FDA data or confer clinical/algorithm eligibility.
final class OpenFdaStrengthExpressionSourceManifest {
  OpenFdaStrengthExpressionSourceManifest._({
    required this.sourceAssetSha256,
    required this.sourceUrl,
    required this.retrievedAt,
    required this.sourceRecordCount,
    required List<String> sourceLimitations,
    required List<OpenFdaStrengthExpressionSourceRow> rows,
  }) : sourceLimitations = List<String>.unmodifiable(sourceLimitations),
       rows = List<OpenFdaStrengthExpressionSourceRow>.unmodifiable(rows);

  static const String schemaUri =
      'parkinsum.openfda-strength-expression-source-manifest/1';
  static const String sourceSystem = 'OPENFDA_NDC';
  static const String sourceAssetPath =
      'assets/data/common_medication_products_openfda.json';

  final String sourceAssetSha256;
  final String sourceUrl;
  final String retrievedAt;
  final int sourceRecordCount;
  final List<String> sourceLimitations;
  final List<OpenFdaStrengthExpressionSourceRow> rows;

  String get sha256 => crypto.sha256
      .convert(
        utf8.encode(
          jsonEncode(<Object?>[
            schemaUri,
            OpenFdaStrengthExpressionParseResult.schemaUri,
            OpenFdaStrengthExpressionParseResult.parserVersion,
            sourceSystem,
            sourceAssetPath,
            sourceAssetSha256,
            sourceUrl,
            retrievedAt,
            sourceRecordCount,
            sourceLimitations,
            rows.map((row) => row.sha256).toList(growable: false),
            false,
            false,
          ]),
        ),
      )
      .toString();

  Map<String, Object?> toJson() => <String, Object?>{
    'schema_uri': schemaUri,
    'source_system': sourceSystem,
    'source_asset_path': sourceAssetPath,
    'source_asset_sha256': sourceAssetSha256,
    'source_url': sourceUrl,
    'source_retrieved_at': retrievedAt,
    'source_record_count': sourceRecordCount,
    'ingredient_strength_row_count': rows.length,
    'source_limitations': sourceLimitations,
    'strength_parser_schema_uri':
        OpenFdaStrengthExpressionParseResult.schemaUri,
    'strength_parser_version':
        OpenFdaStrengthExpressionParseResult.parserVersion,
    'rows': rows.map((row) => row.toJson()).toList(growable: false),
    'fda_data_verified': false,
    'clinical_or_algorithm_eligible': false,
    'sha256': sha256,
  };

  static OpenFdaStrengthExpressionSourceManifest create({
    required String sourceAssetSha256,
    required String sourceUrl,
    required String retrievedAt,
    required int sourceRecordCount,
    required List<String> sourceLimitations,
    required List<OpenFdaStrengthExpressionSourceRow> rows,
  }) => OpenFdaStrengthExpressionSourceManifest._(
    sourceAssetSha256: sourceAssetSha256,
    sourceUrl: sourceUrl,
    retrievedAt: retrievedAt,
    sourceRecordCount: sourceRecordCount,
    sourceLimitations: sourceLimitations,
    rows: rows,
  );
}
