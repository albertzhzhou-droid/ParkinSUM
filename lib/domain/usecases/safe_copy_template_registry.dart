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
        SafeCopyTemplate(
          templateId: 'onboarding_safety_education_body',
          outputType: 'boundary',
          defaultLocale: 'en',
          localizedText: {
            'en': 'ParkinSUM gives conservative prompts from medication, meal, '
                'and regional rules. Medication changes, stopping therapy, or '
                'clinical diet decisions still need a physician or pharmacist.',
          },
          requiredSafetyTerms: ['physician or pharmacist'],
          notes: 'Onboarding safety-education body; mirrors i18n key '
              '`onboarding.safety_education_body` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'onboarding_account_scope_title',
          outputType: 'boundary',
          defaultLocale: 'en',
          localizedText: {'en': 'Account data stays user-scoped'},
          notes: 'Onboarding account-scope title; mirrors i18n key '
              '`onboarding.account_scope_title` (en). Data-scope disclaimer; no '
              'medical safety term required.',
        ),
        SafeCopyTemplate(
          templateId: 'onboarding_account_scope_body',
          outputType: 'boundary',
          defaultLocale: 'en',
          localizedText: {
            'en': 'After onboarding, profile, medications, intakes, and later '
                'audit records are saved under the current account user space.',
          },
          notes: 'Onboarding account-scope body; mirrors i18n key '
              '`onboarding.account_scope_body` (en). Data-scope disclaimer.',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_analysis',
          outputType: 'boundary',
          defaultLocale: 'en',
          localizedText: {
            'en': 'Built-in rules checked this meal against {drugCount} '
                'medication(s), producing a heuristic screening score of '
                '{score}/100.',
          },
          requiredPlaceholders: ['drugCount', 'score'],
          allowedPlaceholders: ['drugCount', 'score'],
          requiredSafetyTerms: ['built-in rules', 'heuristic'],
          notes: 'Legacy analysis framing; mirrors i18n key `legacy.analysis` '
              '(en). Frames the result as a built-in heuristic screen.',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_analysis_followup',
          outputType: 'boundary',
          defaultLocale: 'en',
          localizedText: {
            'en': 'Treat this as a lightweight screening result and confirm '
                'exact medication timing when you need more specific guidance.',
          },
          requiredSafetyTerms: ['screening result'],
          notes: 'Legacy analysis follow-up disclaimer; mirrors i18n key '
              '`legacy.analysis_followup` (en).',
        ),
        // --- Migrated legacy rule-finding lines (informational outputs) -------
        // These are the rule engine's finding/summary lines (not safety-boundary
        // disclaimers), so outputType is `informational` with no required safety
        // terms; placeholder + banned-phrase validation still applies. en text
        // mirrors app_i18n byte-identical (locale-strict; non-en keeps tr()).
        // Excluded by design: `legacy.severity.{high,moderate,low}` (one/two-word
        // enum labels — no governance value).
        SafeCopyTemplate(
          templateId: 'legacy_high_protein_strong',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'High protein timing may strongly affect levodopa absorption',
          },
          requiredSafetyTerms: [],
          notes: 'Legacy rule finding title; mirrors i18n key '
              '`legacy.high_protein_strong` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_high_protein_strong_detail',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'This meal contains about {protein} g of protein, which is '
                'in a higher-risk range. Taking it close to {drug} may compete '
                'more strongly for absorption.',
          },
          requiredPlaceholders: ['protein', 'drug'],
          allowedPlaceholders: ['protein', 'drug'],
          requiredSafetyTerms: [],
          notes: 'Legacy rule finding detail; mirrors i18n key '
              '`legacy.high_protein_strong_detail` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_high_protein',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'Protein may affect medication absorption',
          },
          requiredSafetyTerms: [],
          notes: 'Legacy rule finding title; mirrors i18n key '
              '`legacy.high_protein` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_high_protein_detail',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'This meal contains about {protein} g of protein and may '
                'compete with {drug} during absorption. Consider scheduling '
                'higher-protein meals away from dosing time.',
          },
          requiredPlaceholders: ['protein', 'drug'],
          allowedPlaceholders: ['protein', 'drug'],
          requiredSafetyTerms: [],
          notes: 'Legacy rule finding detail; mirrors i18n key '
              '`legacy.high_protein_detail` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_tyramine',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'Possible high-tyramine food risk',
          },
          requiredSafetyTerms: [],
          notes: 'Legacy rule finding title; mirrors i18n key '
              '`legacy.tyramine` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_tyramine_detail',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'This meal includes foods marked as high tyramine. Combined '
                'with {drug}, it may increase adverse-effect risk.',
          },
          requiredPlaceholders: ['drug'],
          allowedPlaceholders: ['drug'],
          requiredSafetyTerms: [],
          notes: 'Legacy rule finding detail; mirrors i18n key '
              '`legacy.tyramine_detail` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_mineral',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'Meal timing note for mineral supplements',
          },
          requiredSafetyTerms: [],
          notes: 'Legacy rule finding title; mirrors i18n key '
              '`legacy.mineral` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_mineral_detail',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'This meal includes dairy and may suggest higher calcium '
                'content. Some mineral supplements can have different '
                'absorption or GI tolerance when taken with food.',
          },
          requiredSafetyTerms: [],
          notes: 'Legacy rule finding detail; mirrors i18n key '
              '`legacy.mineral_detail` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_summary',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'Overall score {score}/100 ({severity}), with {count} '
                'possible food-drug or nutrition-related alerts.',
          },
          requiredPlaceholders: ['score', 'severity', 'count'],
          allowedPlaceholders: ['score', 'severity', 'count'],
          requiredSafetyTerms: [],
          notes: 'Legacy result summary line; mirrors i18n key '
              '`legacy.summary` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_analysis_protein',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'The current meal estimate contains about {protein} g of '
                'protein.',
          },
          requiredPlaceholders: ['protein'],
          allowedPlaceholders: ['protein'],
          requiredSafetyTerms: [],
          notes: 'Legacy analysis protein segment; mirrors i18n key '
              '`legacy.analysis_protein` (en).',
        ),
        SafeCopyTemplate(
          templateId: 'legacy_analysis_tyramine',
          outputType: 'informational',
          defaultLocale: 'en',
          localizedText: {
            'en': 'This meal also contains foods tagged as higher tyramine '
                'risk in the built-in catalog.',
          },
          requiredSafetyTerms: [],
          notes: 'Legacy analysis tyramine segment; mirrors i18n key '
              '`legacy.analysis_tyramine` (en).',
        ),
      ];

  SafeCopyTemplate? byId(String id) {
    for (final t in templates) {
      if (t.templateId == id) return t;
    }
    return null;
  }
}
