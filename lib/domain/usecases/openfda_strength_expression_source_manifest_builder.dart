import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import '../entities/openfda_strength_expression_source_manifest.dart';
import 'openfda_strength_expression_parser.dart';

/// Builds an identity-bound evidence manifest from exact openFDA asset bytes.
/// Invalid or duplicate row identities fail closed rather than disappearing.
final class OpenFdaStrengthExpressionSourceManifestBuilder {
  const OpenFdaStrengthExpressionSourceManifestBuilder({
    this.parser = const OpenFdaStrengthExpressionParser(),
  });

  final OpenFdaStrengthExpressionParser parser;

  OpenFdaStrengthExpressionSourceManifest buildFromBytes(
    List<int> sourceAssetBytes,
  ) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(sourceAssetBytes));
    } on FormatException {
      throw const FormatException('openFDA snapshot is not valid UTF-8 JSON.');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('openFDA snapshot must be a JSON object.');
    }
    if (decoded['source_system'] != 'OPENFDA_NDC') {
      throw const FormatException('openFDA snapshot source system mismatch.');
    }

    final sourceUrl = _requiredString(decoded['source_url'], 'source_url');
    final retrievedAt = _requiredString(
      decoded['retrieved_at'],
      'retrieved_at',
    );
    final rawRecords = decoded['records'];
    if (rawRecords is! List || rawRecords.isEmpty) {
      throw const FormatException('openFDA snapshot records are missing.');
    }
    final rawLimitations = decoded['limitations'];
    if (rawLimitations is! List || rawLimitations.isEmpty) {
      throw const FormatException('openFDA snapshot limitations are missing.');
    }
    final sourceLimitations = rawLimitations
        .map((value) => _requiredString(value, 'limitations[]'))
        .toList(growable: false);
    final sourceAssetSha256 = crypto.sha256
        .convert(sourceAssetBytes)
        .toString();
    final rows = <OpenFdaStrengthExpressionSourceRow>[];
    final identities = <String>{};

    for (final rawWrapper in rawRecords) {
      if (rawWrapper is! Map<String, dynamic>) {
        throw const FormatException(
          'openFDA snapshot record wrapper is invalid.',
        );
      }
      final record = rawWrapper['record'];
      if (record is! Map<String, dynamic>) {
        throw const FormatException('openFDA snapshot record is invalid.');
      }
      final productNdc = _requiredString(record['product_ndc'], 'product_ndc');
      final productId = _requiredString(record['product_id'], 'product_id');
      final splId = _requiredString(record['spl_id'], 'spl_id');
      final rawIngredients = record['active_ingredients'];
      if (rawIngredients is! List || rawIngredients.isEmpty) {
        throw const FormatException(
          'openFDA active_ingredients rows are missing.',
        );
      }

      for (
        var ingredientIndex = 0;
        ingredientIndex < rawIngredients.length;
        ingredientIndex++
      ) {
        final rawIngredient = rawIngredients[ingredientIndex];
        if (rawIngredient is! Map<String, dynamic>) {
          throw const FormatException(
            'openFDA active ingredient row is invalid.',
          );
        }
        final ingredientName = _requiredString(
          rawIngredient['name'],
          'active_ingredients[].name',
        );
        final rawStrength = rawIngredient['strength'];
        if (rawStrength != null && rawStrength is! String) {
          throw const FormatException(
            'openFDA active ingredient strength must be a string or null.',
          );
        }
        final identity = jsonEncode(<Object?>[
          productNdc,
          productId,
          splId,
          ingredientIndex,
        ]);
        if (!identities.add(identity)) {
          throw const FormatException(
            'openFDA active ingredient row identity is duplicated.',
          );
        }
        rows.add(
          OpenFdaStrengthExpressionSourceRow(
            sourceAssetSha256: sourceAssetSha256,
            productNdc: productNdc,
            productId: productId,
            splId: splId,
            ingredientIndex: ingredientIndex,
            ingredientName: ingredientName,
            parseResult: parser.parse(rawStrength as String?),
          ),
        );
      }
    }

    return OpenFdaStrengthExpressionSourceManifest.create(
      sourceAssetSha256: sourceAssetSha256,
      sourceUrl: sourceUrl,
      retrievedAt: retrievedAt,
      sourceRecordCount: rawRecords.length,
      sourceLimitations: sourceLimitations,
      rows: rows,
    );
  }

  String _requiredString(Object? value, String field) {
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('openFDA snapshot field $field is missing.');
    }
    return value;
  }
}
