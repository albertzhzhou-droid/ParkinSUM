/// P2 — Catalog query normalization + tokenization.
///
/// Educational/research prototype only. Deterministic, side-effect-free
/// normalization of a raw user-facing food/drug query string. It does NOT do
/// medical inference, does NOT convert dose-like text into a usable dose, and
/// does NOT recommend anything. Synthetic/demo data only.
library;

/// Light, conservative domain hint inferred from a query (the engine makes the
/// final domain decision from the catalogs that actually match).
class CatalogDomainHint {
  static const String food = 'food';
  static const String drug = 'drug';
  static const String mixed = 'mixed';
  static const String unknown = 'unknown';
}

class NormalizedCatalogQuery {
  /// The original, untouched query.
  final String original;

  /// Lowercased, whitespace-collapsed, punctuation- and width-normalized form.
  final String normalized;

  /// Whitespace-split tokens of [normalized].
  final List<String> tokens;

  /// Dose-like tokens preserved as QUERY EVIDENCE only (e.g. `25/100`, `100mg`).
  /// These are never converted into a user intake dose.
  final List<String> doseLikeTokens;

  /// A release-type hint parsed from the query (immediate/extended/controlled),
  /// or empty when none is present.
  final String releaseTypeHint;

  /// A conservative domain hint (food/drug/mixed/unknown).
  final String domainHint;

  const NormalizedCatalogQuery({
    required this.original,
    required this.normalized,
    required this.tokens,
    required this.doseLikeTokens,
    required this.releaseTypeHint,
    required this.domainHint,
  });

  bool get isEmpty => normalized.isEmpty;

  Map<String, dynamic> toJson() => {
        'original': original,
        'normalized': normalized,
        'tokens': tokens,
        'dose_like_tokens': doseLikeTokens,
        'release_type_hint': releaseTypeHint,
        'domain_hint': domainHint,
      };
}

class CatalogQueryNormalizer {
  const CatalogQueryNormalizer();

  static final RegExp _ws = RegExp(r'\s+');
  static final RegExp _doseSlash = RegExp(r'\d+\s*/\s*\d+');
  static final RegExp _doseUnit =
      RegExp(r'\d+(?:\.\d+)?\s*(?:mg|mcg|µg|g|ml)\b', caseSensitive: false);

  // Conservative keyword hints (NOT medical inference — only routing hints).
  static const List<String> _drugHintTokens = [
    'levodopa',
    'carbidopa',
    'sinemet',
    'madopar',
    'rytary',
    'stalevo',
    'dopa',
    'entacapone',
    'benserazide',
  ];
  static const List<String> _foodHintTokens = [
    'tea',
    'milk',
    'shake',
    'juice',
    'rice',
    'bread',
    'coffee',
    'soup',
    'egg',
    'tofu',
    'noodle',
  ];

  /// Canonicalize a single string (query OR a catalog name/alias) the same way,
  /// so comparisons are apples-to-apples. Lowercases, folds full-width ASCII,
  /// normalizes punctuation, and collapses whitespace. CJK is preserved.
  String canonicalize(String input) {
    var s = _foldWidth(input);
    s = s
        .replaceAll('–', '-') // en dash
        .replaceAll('—', '-') // em dash
        .replaceAll('⁄', '/') // fraction slash
        .replaceAll('／', '/'); // full-width slash (after fold, defensive)
    return s.toLowerCase().trim().replaceAll(_ws, ' ');
  }

  NormalizedCatalogQuery normalize(String query) {
    final original = query;
    final s = canonicalize(query);

    final tokens = s.isEmpty
        ? const <String>[]
        : s.split(' ').where((t) => t.isNotEmpty).toList();

    final doseLike = <String>[
      ..._doseSlash.allMatches(s).map((m) => m.group(0)!.replaceAll(' ', '')),
      ..._doseUnit.allMatches(s).map((m) => m.group(0)!.replaceAll(' ', '')),
    ];

    final releaseTypeHint = _releaseHint(s);
    final domainHint = _domainHint(s, doseLike, releaseTypeHint);

    return NormalizedCatalogQuery(
      original: original,
      normalized: s,
      tokens: tokens,
      doseLikeTokens: doseLike,
      releaseTypeHint: releaseTypeHint,
      domainHint: domainHint,
    );
  }

  String _releaseHint(String s) {
    if (RegExp(r'\b(cr|controlled[ -]?release)\b').hasMatch(s)) {
      return 'controlled';
    }
    if (RegExp(r'\b(er|xr|sr|extended[ -]?release|sustained[ -]?release)\b')
        .hasMatch(s)) {
      return 'extended';
    }
    if (RegExp(r'\b(ir|immediate[ -]?release)\b').hasMatch(s)) {
      return 'immediate';
    }
    return '';
  }

  String _domainHint(String s, List<String> doseLike, String releaseHint) {
    final drugLike = doseLike.isNotEmpty ||
        releaseHint.isNotEmpty ||
        _drugHintTokens.any((t) => s.contains(t));
    final foodLike = _foodHintTokens.any((t) => s.contains(t));
    if (drugLike && foodLike) return CatalogDomainHint.mixed;
    if (drugLike) return CatalogDomainHint.drug;
    if (foodLike) return CatalogDomainHint.food;
    return CatalogDomainHint.unknown;
  }

  /// Fold full-width ASCII variants (U+FF01–FF5E) to half-width and the
  /// full-width space (U+3000) to a normal space. CJK characters are untouched.
  String _foldWidth(String input) {
    final buf = StringBuffer();
    for (final rune in input.runes) {
      if (rune == 0x3000) {
        buf.writeCharCode(0x20);
      } else if (rune >= 0xFF01 && rune <= 0xFF5E) {
        buf.writeCharCode(rune - 0xFEE0);
      } else {
        buf.writeCharCode(rune);
      }
    }
    return buf.toString();
  }
}
