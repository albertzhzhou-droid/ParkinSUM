/// A conservative mapping result from a CDSS/SPL label-section key to a
/// **LOINC document-section code** (FDA "Section Headings (LOINC)").
///
/// Educational/research prototype only. This is **provenance/traceability**, not
/// clinical decision logic: a LOINC code here identifies *which labeled section*
/// a product attribute came from. A missing code (`unknown`) does **not**
/// invalidate the section provenance — the original CDSS section key is always
/// preserved and never overwritten. Codes are only emitted for well-known,
/// stable FDA SPL sections; anything ambiguous stays `unknown` (never guessed).
library;

/// Confidence of the section-key → LOINC mapping.
enum SectionCodeMappingConfidence {
  /// Matched a known, stable FDA SPL section heading.
  mapped,

  /// Not a recognized/stable section, or ambiguous — recorded as missing.
  unknown,
}

class LabelSectionCode {
  /// The original CDSS/SPL section key (always preserved).
  final String sourceSectionKey;

  /// The section title when available (used as a secondary match signal).
  final String? sectionTitle;

  /// LOINC document-section code, or null when unknown (never fabricated).
  final String? loincCode;

  /// LOINC display name, or null when unknown.
  final String? loincDisplay;

  final SectionCodeMappingConfidence mappingConfidence;
  final List<String> sourceRefs;
  final String limitationText;

  const LabelSectionCode({
    required this.sourceSectionKey,
    required this.sectionTitle,
    required this.loincCode,
    required this.loincDisplay,
    required this.mappingConfidence,
    required this.sourceRefs,
    required this.limitationText,
  });

  bool get isMapped => mappingConfidence == SectionCodeMappingConfidence.mapped;

  Map<String, dynamic> toJson() => {
        'source_section_key': sourceSectionKey,
        'section_title': sectionTitle,
        'loinc_code': loincCode,
        'loinc_display': loincDisplay,
        'mapping_confidence': mappingConfidence.name,
        'source_refs': sourceRefs,
        'limitation_text': limitationText,
      };
}
