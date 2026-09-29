/// Versioned fail-closed parser for one user-entered administration-dose note.
///
/// The parser preserves the original text and produces a typed expression only
/// when exactly one positive finite value and one reviewed local unit token are
/// present. Ranges, rates, ratios, locale-ambiguous numbers, comparators,
/// scientific notation, additional numeric tokens, and unsupported units are
/// held from result-affecting algorithms instead of being partially matched.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../core/models/intake.dart';
import '../entities/dose_expression.dart';
import '../entities/versioned_dose_unit_mapping.dart';

/// Backward-compatible pair consumed by existing production call sites.
///
/// New UI and audit surfaces should use [DoseExpressionParseResult] from
/// [DosageNoteParser.inspect] so a held expression retains its reason codes.
class ParsedDose {
  final double? value;
  final String? unit;
  final bool explicit;
  final VersionedDoseUnitMapping? mappingEvidence;

  const ParsedDose({
    this.value,
    this.unit,
    this.explicit = false,
    this.mappingEvidence,
  });

  static const ParsedDose none = ParsedDose();
}

class DosageNoteParser {
  static const String grammarId = 'parkinsum.administration-dose-expression';
  static const int grammarVersion = 4;
  static const String localUnitSystem =
      VersionedDoseUnitMapping.localUnitSystemUri;
  static const String localUnitVersion =
      VersionedDoseUnitMapping.terminologyVersion;

  static const String _unitMappingContract =
      'parkinsum.versioned-dose-unit-mapping/1;'
      'tokens=mg,milligram,milligrams,g,gram,grams,mcg,ug,µg,μg,'
      'microgram,micrograms,ml,milliliter,milliliters;'
      'case-folded-token=exact_alias;'
      'base=mg:mg=1/1,g=1000/1,mcg=1/1000;mL:mL=1/1;'
      'jurisdiction=not_applicable_user_entered_local_vocabulary;'
      'license=local_authored_no_external_asset;review=2026-09-23;'
      'stale_after_days=365;unknown_approximate_unlicensed=held';

  static const String _grammarContract =
      'one-positive-finite-decimal;one-reviewed-local-unit;'
      'no-range;no-rate;no-ratio;no-comparator;no-scientific;'
      'no-locale-comma;no-leading-decimal;no-unicode-sign;'
      'no-extra-number;preserve-raw;fail-closed;'
      'versioned-exact-local-unit-mapping;'
      'unit-boundary=reject-unicode-letter-mark-other-adjacent;';

  static final String grammarDigest = sha256
      .convert(
        utf8.encode(
          '$grammarId\n$grammarVersion\n$localUnitSystem\n'
          '$localUnitVersion\n$_unitMappingContract\n$_grammarContract',
        ),
      )
      .toString();

  static Map<String, Object> get configurationIdentity =>
      Map<String, Object>.unmodifiable(<String, Object>{
        'id': grammarId,
        'version': grammarVersion,
        'sha256': grammarDigest,
        'unit_system': localUnitSystem,
        'unit_version': localUnitVersion,
      });

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

  static final RegExp _numberToken = RegExp(r'[0-9]+(?:\.[0-9]+)?');
  static final RegExp _valueUnit = RegExp(
    r'([0-9]+(?:\.[0-9]+)?)\s*'
    r'(milligrams?|micrograms?|milliliters?|mcg|mg|ug|µg|μg|grams?|g|ml)'
    r'(?![\p{L}\p{M}\p{C}])',
    caseSensitive: false,
    unicode: true,
  );
  static final RegExp _unitToken = RegExp(
    r'(?<![\p{L}\p{M}\p{C}])'
    r'(milligrams?|micrograms?|milliliters?|mcg|mg|ug|µg|μg|grams?|g|ml)'
    r'(?![\p{L}\p{M}\p{C}])',
    caseSensitive: false,
    unicode: true,
  );
  static final RegExp _diagnosticComparator = RegExp(
    r'^(<=|>=|<|>)\s*([0-9]+(?:\.[0-9]+)?)\s*'
    r'(milligrams?|micrograms?|milliliters?|mcg|mg|ug|µg|μg|grams?|g|ml)$',
    caseSensitive: false,
  );
  static final RegExp _diagnosticRange = RegExp(
    r'^([0-9]+(?:\.[0-9]+)?)\s*(?:-|–|—|\bto\b)\s*'
    r'([0-9]+(?:\.[0-9]+)?)\s*'
    r'(milligrams?|micrograms?|milliliters?|mcg|mg|ug|µg|μg|grams?|g|ml)$',
    caseSensitive: false,
  );
  static final RegExp _wordNumber = RegExp(
    r'\b(one|two|three|four|five|six|seven|eight|nine|ten|a|an)\b',
    caseSensitive: false,
  );

  DoseExpressionParseResult inspect(
    String? dosageNote, {
    DateTime? evaluatedAt,
  }) {
    final raw = dosageNote ?? '';
    final normalized = raw.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return _result(
        raw: raw,
        normalized: normalized,
        status: DoseExpressionParseStatus.empty,
        reasons: const ['dose.empty'],
      );
    }
    if (raw.length > 256) {
      return _held(raw, normalized, 'dose.too_long');
    }
    if (RegExp(r'[\u0000-\u001f\u007f]').hasMatch(raw)) {
      return _held(raw, normalized, 'dose.control_character');
    }
    if (RegExp(
      r'\b(?:nan|inf|infinity)\b',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return _held(raw, normalized, 'dose.nonfinite_literal');
    }
    if (RegExp(r'[0-9](?:e|E)[+-]?[0-9]').hasMatch(normalized)) {
      return _held(raw, normalized, 'dose.scientific_notation');
    }
    if (RegExp(r'[0-9],[0-9]').hasMatch(normalized)) {
      return _held(raw, normalized, 'dose.locale_decimal_ambiguous');
    }
    if (RegExp(r'(?:^|[^0-9])[.,][0-9]').hasMatch(normalized)) {
      return _held(raw, normalized, 'dose.leading_decimal_not_supported');
    }
    if (RegExp(r'[<>=~≈]').hasMatch(normalized)) {
      return _held(
        raw,
        normalized,
        'dose.non_exact_comparator',
        evaluatedAt: evaluatedAt,
      );
    }
    if (RegExp(
      r'[0-9]\s*(?:-|–|—|\bto\b)\s*[0-9]',
      caseSensitive: false,
    ).hasMatch(normalized)) {
      return _held(
        raw,
        normalized,
        'dose.range_not_supported',
        evaluatedAt: evaluatedAt,
      );
    }
    if (RegExp(r'(?:^|[\s(])[+-]\s*[0-9]').hasMatch(normalized) ||
        RegExp(
          r'[\u2212\u2012\u2013\u2014\ufe63\uff0b\uff0d]\s*[0-9]',
        ).hasMatch(normalized)) {
      return _held(raw, normalized, 'dose.signed_value');
    }
    if (RegExp(
          r'(?:/|\bper\b)\s*(?:min|minute|h|hr|hour|day|kg|kilogram)\b',
          caseSensitive: false,
        ).hasMatch(normalized) ||
        RegExp(
          r'\b(?:min|minute|h|hr|hour|day|kg|kilogram)\s*(?:-1|⁻1)\b',
          caseSensitive: false,
        ).hasMatch(normalized)) {
      return _held(raw, normalized, 'dose.rate_not_supported');
    }
    if (normalized.contains('/')) {
      return _held(raw, normalized, 'dose.combination_or_ratio');
    }
    if (_wordNumber.hasMatch(normalized)) {
      return _held(raw, normalized, 'dose.word_number_ambiguous');
    }

    final numbers = _numberToken.allMatches(normalized).toList(growable: false);
    if (numbers.isEmpty) {
      return _held(raw, normalized, 'dose.numeric_token_missing');
    }
    if (numbers.length != 1) {
      return _held(raw, normalized, 'dose.multiple_numeric_tokens');
    }

    final quantityMatches = _valueUnit
        .allMatches(normalized)
        .toList(growable: false);
    final unitMatches = _unitToken
        .allMatches(normalized)
        .toList(growable: false);
    if (quantityMatches.length != 1 || unitMatches.length != 1) {
      final numberEnd = numbers.single.end;
      final trailing = normalized.substring(numberEnd).trimLeft();
      if (trailing.isNotEmpty && RegExp(r'^[A-Za-zµμ]').hasMatch(trailing)) {
        return _held(raw, normalized, 'dose.unit_unsupported');
      }
      return _held(raw, normalized, 'dose.unit_missing');
    }

    final match = quantityMatches.single;
    if (match.start != numbers.single.start) {
      return _held(raw, normalized, 'dose.partial_match_blocked');
    }
    final value = double.tryParse(match.group(1) ?? '');
    final unitDisplay = match.group(2) ?? '';
    final unitRaw = unitDisplay.toLowerCase();
    if (value == null || !value.isFinite || value <= 0) {
      return _held(raw, normalized, 'dose.value_invalid');
    }
    if (!_allowedUnits.contains(unitRaw)) {
      return _held(raw, normalized, 'dose.unit_unsupported');
    }
    final mappingEvidence = VersionedDoseUnitMapping.forLocalToken(
      unitDisplay,
      sourceRevision: grammarDigest,
    );
    if (mappingEvidence == null) {
      return _held(raw, normalized, 'dose.unit_mapping_unrecognized');
    }
    final mappingErrors = mappingEvidence.validationErrors(
      expectedSourceRevision: grammarDigest,
      evaluatedAt: (evaluatedAt ?? DateTime.now()).toUtc(),
    );
    if (mappingErrors.isNotEmpty) {
      return _result(
        raw: raw,
        normalized: normalized,
        status: DoseExpressionParseStatus.held,
        reasons: mappingErrors,
      );
    }
    final expression = DoseQuantityExpression(
      value: value,
      unit: DoseUnitIdentity(
        display: unitDisplay,
        system: localUnitSystem,
        code: mappingEvidence.canonicalCode,
        version: localUnitVersion,
        dimension:
            mappingEvidence.sourceDimension == DoseUnitMappingDimension.volume
            ? DoseExpressionDimension.volume
            : DoseExpressionDimension.mass,
        mappingEvidence: mappingEvidence,
      ),
      role: DoseExpressionRole.administrationDose,
      sourceStart: match.start,
      sourceEnd: match.end,
    );
    return _result(
      raw: raw,
      normalized: normalized,
      status: DoseExpressionParseStatus.accepted,
      reasons: const [],
      expression: expression,
    );
  }

  /// Compatibility view: only an accepted typed administration dose becomes
  /// an explicit legacy pair.
  ParsedDose parse(String? dosageNote) {
    final result = inspect(dosageNote);
    final expression = result.expression;
    if (!result.accepted || expression == null) return ParsedDose.none;
    return ParsedDose(
      value: expression.value,
      unit: expression.unit.code,
      explicit: true,
      mappingEvidence: expression.unit.mappingEvidence,
    );
  }

  /// Prefer a previously validated structured dose, then parse a legacy note.
  ///
  /// This preserves existing stored records. A future confirmation-provenance
  /// migration will bind the structured fields to the exact grammar result and
  /// history revision; this method does not manufacture that evidence.
  ParsedDose parseIntake(Intake intake) {
    final value = intake.doseAmount;
    final unitDisplay = intake.doseUnit?.trim();
    final unitRaw = unitDisplay?.toLowerCase();
    if (value != null &&
        value.isFinite &&
        value > 0 &&
        unitRaw != null &&
        _allowedUnits.contains(unitRaw)) {
      final mappingEvidence = VersionedDoseUnitMapping.forLocalToken(
        unitDisplay!,
        sourceRevision: grammarDigest,
      );
      if (mappingEvidence == null ||
          mappingEvidence
              .validationErrors(
                expectedSourceRevision: grammarDigest,
                evaluatedAt: DateTime.now().toUtc(),
              )
              .isNotEmpty) {
        return parse(intake.dosageNote);
      }
      return ParsedDose(
        value: value,
        unit: mappingEvidence.canonicalCode,
        explicit: true,
        mappingEvidence: mappingEvidence,
      );
    }
    return parse(intake.dosageNote);
  }

  double? milligrams(String? dosageNote) => _milligrams(parse(dosageNote));

  double? milligramsForIntake(Intake intake) =>
      _milligrams(parseIntake(intake));

  double? _milligrams(ParsedDose dose) {
    if (!dose.explicit || dose.value == null) return null;
    final mapping = dose.mappingEvidence;
    if (mapping == null || mapping.baseUnitCode != 'mg') return null;
    return mapping.convertToBaseUnit(
      dose.value!,
      expectedSourceRevision: grammarDigest,
      evaluatedAt: DateTime.now().toUtc(),
    );
  }

  DoseExpressionParseResult _held(
    String raw,
    String normalized,
    String reason, {
    DateTime? evaluatedAt,
  }) {
    final diagnosticStructure = switch (reason) {
      'dose.non_exact_comparator' => _comparatorDiagnostic(
        normalized,
        evaluatedAt ?? DateTime.now().toUtc(),
      ),
      'dose.range_not_supported' => _rangeDiagnostic(
        normalized,
        evaluatedAt ?? DateTime.now().toUtc(),
      ),
      _ => null,
    };
    return _result(
      raw: raw,
      normalized: normalized,
      status: DoseExpressionParseStatus.held,
      reasons: <String>[reason],
      diagnosticStructure: diagnosticStructure,
    );
  }

  DoseExpressionDiagnosticStructure? _comparatorDiagnostic(
    String normalized,
    DateTime evaluatedAt,
  ) {
    final match = _diagnosticComparator.firstMatch(normalized);
    if (match == null) return null;
    final comparator = switch (match.group(1)) {
      '<' => DoseExpressionComparatorToken.lessThan,
      '<=' => DoseExpressionComparatorToken.lessThanOrEqual,
      '>=' => DoseExpressionComparatorToken.greaterThanOrEqual,
      '>' => DoseExpressionComparatorToken.greaterThan,
      _ => null,
    };
    final valueText = match.group(2)!;
    final value = double.tryParse(valueText);
    final unitDisplay = match.group(3)!;
    final sourceText = match.group(0)!;
    final unit = _diagnosticUnitIdentity(unitDisplay, evaluatedAt);
    if (comparator == null ||
        value == null ||
        !value.isFinite ||
        value < 0 ||
        unit == null) {
      return null;
    }
    return DoseExpressionDiagnosticStructure(
      kind: DoseExpressionDiagnosticKind.comparatorQuantity,
      comparator: comparator,
      quantity: DoseExpressionDiagnosticQuantity(
        lexicalValue: valueText,
        value: value,
        unit: unit,
        valueStart: match.start + sourceText.indexOf(valueText),
        valueEnd:
            match.start + sourceText.indexOf(valueText) + valueText.length,
        unitStart: match.start + sourceText.length - unitDisplay.length,
        unitEnd: match.start + sourceText.length,
      ),
      sourceStart: match.start,
      sourceEnd: match.end,
    );
  }

  DoseExpressionDiagnosticStructure? _rangeDiagnostic(
    String normalized,
    DateTime evaluatedAt,
  ) {
    final match = _diagnosticRange.firstMatch(normalized);
    if (match == null) return null;
    final lowerText = match.group(1)!;
    final upperText = match.group(2)!;
    final lowerValue = double.tryParse(lowerText);
    final upperValue = double.tryParse(upperText);
    final unitDisplay = match.group(3)!;
    final sourceText = match.group(0)!;
    final lowerStart = sourceText.indexOf(lowerText);
    final upperStart = sourceText.indexOf(
      upperText,
      lowerStart + lowerText.length,
    );
    final unitStart = sourceText.length - unitDisplay.length;
    final unit = _diagnosticUnitIdentity(unitDisplay, evaluatedAt);
    if (lowerValue == null ||
        upperValue == null ||
        !lowerValue.isFinite ||
        !upperValue.isFinite ||
        lowerValue < 0 ||
        upperValue < lowerValue ||
        unit == null) {
      return null;
    }
    return DoseExpressionDiagnosticStructure(
      kind: DoseExpressionDiagnosticKind.closedRange,
      lowerBound: DoseExpressionDiagnosticQuantity(
        lexicalValue: lowerText,
        value: lowerValue,
        unit: unit,
        valueStart: match.start + lowerStart,
        valueEnd: match.start + lowerStart + lowerText.length,
        unitStart: match.start + unitStart,
        unitEnd: match.start + sourceText.length,
      ),
      upperBound: DoseExpressionDiagnosticQuantity(
        lexicalValue: upperText,
        value: upperValue,
        unit: unit,
        valueStart: match.start + upperStart,
        valueEnd: match.start + upperStart + upperText.length,
        unitStart: match.start + unitStart,
        unitEnd: match.start + sourceText.length,
      ),
      sourceStart: match.start,
      sourceEnd: match.end,
    );
  }

  DoseUnitIdentity? _diagnosticUnitIdentity(
    String display,
    DateTime evaluatedAt,
  ) {
    final mappingEvidence = VersionedDoseUnitMapping.forLocalToken(
      display,
      sourceRevision: grammarDigest,
    );
    if (mappingEvidence == null ||
        mappingEvidence
            .validationErrors(
              expectedSourceRevision: grammarDigest,
              evaluatedAt: evaluatedAt.toUtc(),
            )
            .isNotEmpty) {
      return null;
    }
    return DoseUnitIdentity(
      display: display,
      system: localUnitSystem,
      code: mappingEvidence.canonicalCode,
      version: localUnitVersion,
      dimension:
          mappingEvidence.sourceDimension == DoseUnitMappingDimension.volume
          ? DoseExpressionDimension.volume
          : DoseExpressionDimension.mass,
      mappingEvidence: mappingEvidence,
    );
  }

  DoseExpressionParseResult _result({
    required String raw,
    required String normalized,
    required DoseExpressionParseStatus status,
    required List<String> reasons,
    DoseQuantityExpression? expression,
    DoseExpressionDiagnosticStructure? diagnosticStructure,
  }) => DoseExpressionParseResult(
    rawText: raw,
    normalizedText: normalized,
    grammarId: grammarId,
    grammarVersion: grammarVersion,
    grammarDigest: grammarDigest,
    status: status,
    reasonCodes: reasons,
    expression: expression,
    diagnosticStructure: diagnosticStructure,
  );
}
