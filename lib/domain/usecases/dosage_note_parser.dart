/// Parses a user-entered free-text dosage note into an explicit
/// (value, unit) pair — and ONLY when both are unambiguously present.
///
/// Hard rule: the algorithm must use the dose the user actually entered. This
/// parser never infers, substitutes, or defaults a strength. A bare number,
/// a name+number with no unit ("levodopa 100"), or a slashed combo with no
/// unit ("25/100") is NOT explicit and yields `explicit == false` with null
/// value/unit, so the medication context downstream is marked insufficient
/// for dose-dependent interpretation.
library;

class ParsedDose {
  final double? value;
  final String? unit;
  final bool explicit;

  const ParsedDose({this.value, this.unit, this.explicit = false});

  static const ParsedDose none = ParsedDose();
}

class DosageNoteParser {
  static const Set<String> _allowedUnits = {
    'mg',
    'milligram',
    'milligrams',
    'g',
    'gram',
    'grams',
    'mcg',
    'ug',
    'µg',
    'μg',
    'microgram',
    'micrograms',
    'ml',
    'milliliter',
    'milliliters',
  };

  // A single "<number> <unit>" token where the unit immediately follows the
  // number (optionally with a space). Requires BOTH a number and a unit.
  static final RegExp _valueUnit = RegExp(
    r'(?<![0-9./-])([0-9]+(?:\.[0-9]+)?)\s*'
    r'(mg|milligrams?|g|grams?|mcg|ug|µg|μg|micrograms?|ml|milliliters?)\b',
    caseSensitive: false,
  );

  /// Parse the note. Returns an explicit dose only when exactly one
  /// unambiguous value+unit token is present. Slashed combos like
  /// "25 mg / 100 mg" are treated as non-explicit for a single analyzable
  /// strength (they describe a combination product, not one strength).
  ParsedDose parse(String? dosageNote) {
    final note = (dosageNote ?? '').trim();
    if (note.isEmpty) return ParsedDose.none;

    // Reject slashed/combination strengths for single-strength purposes.
    if (RegExp(r'[0-9]\s*[\/]\s*[0-9]').hasMatch(note)) {
      return ParsedDose.none;
    }

    final matches = _valueUnit.allMatches(note).toList();
    if (matches.length != 1) {
      // Zero matches → no explicit unit; multiple → ambiguous.
      return ParsedDose.none;
    }
    final m = matches.first;
    final value = double.tryParse(m.group(1) ?? '');
    final unitRaw = (m.group(2) ?? '').toLowerCase();
    if (value == null || value <= 0) return ParsedDose.none;
    if (!_allowedUnits.contains(unitRaw)) return ParsedDose.none;
    return ParsedDose(value: value, unit: unitRaw, explicit: true);
  }
}
