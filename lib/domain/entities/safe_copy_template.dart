/// P6 (skeleton) — SafeCopyTemplate entity.
///
/// Educational/research prototype only. A small, explicit foundation for future
/// centralized user-facing copy. Templates are **non-prescriptive**: no
/// medication-timing, dose, or diet advice; no safety/clinical-calibration claim.
/// This skeleton does NOT wire copy into the UI or scoring — it is a
/// registry/lint foundation only.
library;

class SafeCopyTemplate {
  final String templateId;

  /// Coarse output type, e.g. `mechanistic_explanation` / `boundary` / `policy`.
  final String outputType;

  /// Default locale for `localizedText` (always present).
  final String defaultLocale;

  /// locale → text. Must contain [defaultLocale].
  final Map<String, String> localizedText;

  /// Placeholders that MUST appear (e.g. `overlap_percent`).
  final List<String> requiredPlaceholders;

  /// Placeholders that MAY appear (superset of required).
  final List<String> allowedPlaceholders;

  /// Safety-boundary terms the text must contain (scanner-safe wording).
  final List<String> requiredSafetyTerms;

  /// Evidence/provenance terms the text should contain when applicable.
  final List<String> requiredEvidenceTerms;

  /// Banned-phrase families this template must never match.
  final List<String> bannedPhraseFamilies;

  final bool requiresSourceRefs;
  final bool requiresLimitationText;
  final bool requiresNotAdviceText;
  final String notes;

  const SafeCopyTemplate({
    required this.templateId,
    required this.outputType,
    required this.defaultLocale,
    required this.localizedText,
    this.requiredPlaceholders = const [],
    this.allowedPlaceholders = const [],
    this.requiredSafetyTerms = const [],
    this.requiredEvidenceTerms = const [],
    this.bannedPhraseFamilies = const ['en', 'zh', 'fr', 'ja'],
    this.requiresSourceRefs = false,
    this.requiresLimitationText = false,
    this.requiresNotAdviceText = false,
    this.notes = '',
  });

  String get defaultText => localizedText[defaultLocale] ?? '';

  Map<String, dynamic> toJson() => {
        'template_id': templateId,
        'output_type': outputType,
        'default_locale': defaultLocale,
        'localized_text': localizedText,
        'required_placeholders': requiredPlaceholders,
        'allowed_placeholders': allowedPlaceholders,
        'required_safety_terms': requiredSafetyTerms,
        'required_evidence_terms': requiredEvidenceTerms,
        'banned_phrase_families': bannedPhraseFamilies,
        'requires_source_refs': requiresSourceRefs,
        'requires_limitation_text': requiresLimitationText,
        'requires_not_advice_text': requiresNotAdviceText,
        'notes': notes,
      };
}
