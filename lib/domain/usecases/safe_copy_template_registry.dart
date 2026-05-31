/// P6 (skeleton) — SafeCopyTemplateRegistry.
///
/// Educational/research prototype only. A minimal, representative registry of
/// non-prescriptive safety/boundary copy templates. It is a foundation for a
/// future centralized copy layer + the localization lint; it does NOT migrate
/// every string and is NOT wired into the UI or scoring in this PR.
library;

import '../entities/rule_explanation.dart';
import '../entities/safe_copy_template.dart';

class SafeCopyTemplateRegistry {
  const SafeCopyTemplateRegistry();

  /// The initial representative templates (deterministic order).
  List<SafeCopyTemplate> get templates => const [
        SafeCopyTemplate(
          templateId: 'mechanistic_explanation_boundary',
          outputType: 'mechanistic_explanation',
          defaultLocale: 'en',
          localizedText: {
            'en': 'This educational prototype shows a modeled, source-linked '
                'overlap estimate of {overlap_percent}%. It is not medical '
                'advice and is not clinically calibrated.',
            'zh': '本教育原型展示一个建模的、可溯源的重叠估计（{overlap_percent}%）。'
                '这不是医疗建议，也未经临床校准。',
          },
          requiredPlaceholders: ['overlap_percent'],
          allowedPlaceholders: ['overlap_percent'],
          requiredSafetyTerms: [
            'educational',
            'not medical advice',
            'not clinically calibrated'
          ],
          requiredEvidenceTerms: ['modeled', 'source-linked'],
          requiresSourceRefs: true,
          requiresLimitationText: true,
          requiresNotAdviceText: true,
          notes: 'Boundary copy for a mechanistic overlap explanation.',
        ),
        SafeCopyTemplate(
          templateId: 'source_quality_boundary',
          outputType: 'boundary',
          defaultLocale: 'en',
          localizedText: {
            'en':
                'Source-quality signals describe how a value was sourced, not '
                    'its clinical accuracy. Educational only; not clinically '
                    'calibrated.',
          },
          requiredSafetyTerms: ['educational', 'not clinically calibrated'],
          requiredEvidenceTerms: ['source-quality'],
          requiresLimitationText: true,
          notes: 'Boundary copy for source-quality signals.',
        ),
        SafeCopyTemplate(
          templateId: 'missing_context_boundary',
          outputType: 'boundary',
          defaultLocale: 'en',
          localizedText: {
            'en': 'The source coverage is incomplete, so this result is shown '
                'with reduced confidence and is not medical advice.',
          },
          requiredSafetyTerms: ['not medical advice'],
          requiredEvidenceTerms: ['source coverage', 'incomplete'],
          requiresLimitationText: true,
          requiresNotAdviceText: true,
          notes: 'Boundary copy when context/metadata is incomplete.',
        ),
        SafeCopyTemplate(
          templateId: 'evidence_trace_boundary',
          outputType: 'boundary',
          defaultLocale: 'en',
          localizedText: {
            'en': 'This is a local educational evidence trace. It is not a '
                'patient record and is not clinical validation.',
          },
          requiredSafetyTerms: ['educational', 'not clinical validation'],
          requiredEvidenceTerms: ['evidence trace'],
          notes: 'Boundary copy for the local evidence trace/graph artifacts.',
        ),
        SafeCopyTemplate(
          templateId: 'not_advice_default',
          outputType: 'policy',
          defaultLocale: 'en',
          localizedText: {'en': RuleExplanation.defaultNotAdvice},
          requiredSafetyTerms: ['not medical advice'],
          requiresNotAdviceText: true,
          notes: 'Shared default not-advice text.',
        ),
        SafeCopyTemplate(
          templateId: 'not_clinically_calibrated_default',
          outputType: 'policy',
          defaultLocale: 'en',
          localizedText: {
            'en': 'This prototype is not clinically calibrated and carries no '
                'clinical-validation claim.',
          },
          requiredSafetyTerms: ['not clinically calibrated'],
          notes: 'Shared default not-clinically-calibrated text.',
        ),
        SafeCopyTemplate(
          templateId: 'safety_boundary_default',
          outputType: 'policy',
          defaultLocale: 'en',
          localizedText: {'en': RuleExplanation.defaultSafetyBoundary},
          requiredSafetyTerms: ['qualified clinician'],
          notes: 'Shared default safety-boundary text (consumed at runtime by '
              'ExplanationCopyService).',
        ),
        // --- Migrated i18n boundary surfaces (en text mirrors app_i18n) -------
        SafeCopyTemplate(
          templateId: 'onboarding_safety_education_title',
          outputType: 'boundary',
          defaultLocale: 'en',
          localizedText: {'en': 'Rule guidance is not medical advice'},
          requiredSafetyTerms: ['not medical advice'],
          requiresNotAdviceText: true,
          notes: 'Onboarding safety-education title; mirrors i18n key '
              '`onboarding.safety_education_title` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_no_conflict',
          outputType: 'boundary',
          defaultLocale: 'en',
          localizedText: {
            'en': 'No significant rule conflicts were detected (based only on '
                'built-in rules; not medical advice).',
          },
          requiredSafetyTerms: ['not medical advice'],
          requiresNotAdviceText: true,
          notes: 'Legacy "no conflict" educational result; mirrors i18n key '
              '`legacy.no_conflict` (en).',
        ),
      ];

  SafeCopyTemplate? byId(String id) {
    for (final t in templates) {
      if (t.templateId == id) return t;
    }
    return null;
  }
}
