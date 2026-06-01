import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/domain/usecases/explanation_copy_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';

/// P6 — i18n parity drift guard.
///
/// The copy-migration's safety promise is: a migrated template's compiled **en**
/// output is byte-identical to its `app_i18n` source string. This test pins every
/// migrated template to its live i18n key so any future divergence (an edit to one
/// side but not the other) fails CI instead of silently changing user-facing copy.
///
/// Only templates that intentionally mirror an `app_i18n` key are listed. Registry
/// templates that are NOT i18n mirrors (e.g. `mechanistic_explanation_boundary`,
/// `source_quality_boundary`, the shared policy defaults) are out of scope here.
///
/// Educational prototype only. Pure, deterministic, in-memory. No medical advice,
/// no clinical-calibration claim, not wired into UI/scoring. No PHI.
void main() {
  const registry = SafeCopyTemplateRegistry();
  const compiler = ExplanationCopyCompiler();
  final i18n = AppI18n.fromLocaleTag('en-US');

  // template id -> (app_i18n key, sample bindings/params). Bindings must match on
  // both sides: `tr(key)` with no params strips `{...}` placeholders, so a
  // placeholder template MUST pass identical params to both the compiler and tr().
  const parity = <String, ({String key, Map<String, String> params})>{
    // Onboarding boundary surfaces (PR #67).
    'onboarding_safety_education_title': (
      key: 'onboarding.safety_education_title',
      params: {},
    ),
    'onboarding_safety_education_body': (
      key: 'onboarding.safety_education_body',
      params: {},
    ),
    'onboarding_account_scope_title': (
      key: 'onboarding.account_scope_title',
      params: {},
    ),
    'onboarding_account_scope_body': (
      key: 'onboarding.account_scope_body',
      params: {},
    ),
    // Legacy result-framing lines (PR #70).
    'legacy_no_conflict': (key: 'legacy.no_conflict', params: {}),
    'legacy_analysis': (
      key: 'legacy.analysis',
      params: {'drugCount': '1', 'score': '42'},
    ),
    'legacy_analysis_followup': (
      key: 'legacy.analysis_followup',
      params: {},
    ),
    // Legacy rule-finding lines (this PR series).
    'legacy_high_protein_strong': (
      key: 'legacy.high_protein_strong',
      params: {},
    ),
    'legacy_high_protein_strong_detail': (
      key: 'legacy.high_protein_strong_detail',
      params: {'protein': '40.0', 'drug': 'Levodopa'},
    ),
    'legacy_high_protein': (key: 'legacy.high_protein', params: {}),
    'legacy_high_protein_detail': (
      key: 'legacy.high_protein_detail',
      params: {'protein': '25.0', 'drug': 'Levodopa'},
    ),
    'legacy_tyramine': (key: 'legacy.tyramine', params: {}),
    'legacy_tyramine_detail': (
      key: 'legacy.tyramine_detail',
      params: {'drug': 'Selegiline'},
    ),
    'legacy_mineral': (key: 'legacy.mineral', params: {}),
    'legacy_mineral_detail': (key: 'legacy.mineral_detail', params: {}),
    'legacy_summary': (
      key: 'legacy.summary',
      params: {'score': '42', 'severity': 'Moderate', 'count': '2'},
    ),
    'legacy_analysis_protein': (
      key: 'legacy.analysis_protein',
      params: {'protein': '25.0'},
    ),
    'legacy_analysis_tyramine': (
      key: 'legacy.analysis_tyramine',
      params: {},
    ),
  };

  for (final entry in parity.entries) {
    final templateId = entry.key;
    final spec = entry.value;

    test('compiled en for $templateId matches app_i18n `${spec.key}`', () {
      final template = registry.byId(templateId);
      expect(template, isNotNull,
          reason: 'Registry is missing migrated template $templateId.');

      // Compile the template's en text with the sample bindings.
      final result = compiler.compile(
        template!,
        bindings: spec.params,
        locale: 'en',
      );
      expect(result.valid, isTrue,
          reason: 'Template $templateId did not compile cleanly.');
      final compiledEn = result.compiled!.text;

      // The live i18n source for the same key + identical params.
      final i18nEn = i18n.tr(spec.key, spec.params);

      expect(compiledEn, i18nEn,
          reason:
              'Drift: registry template "$templateId" en text diverged from '
              'app_i18n key "${spec.key}". Update both sides together.');
    });
  }

  // Sanity: the parity table covers every legacy_* / onboarding_* template the
  // registry carries (so a newly migrated template can't silently skip the guard).
  test('parity table covers all i18n-mirrored templates', () {
    final mirrored = registry.templates
        .map((t) => t.templateId)
        .where((id) => id.startsWith('legacy_') || id.startsWith('onboarding_'))
        .toSet();
    final covered = parity.keys.toSet();
    expect(mirrored.difference(covered), isEmpty,
        reason: 'These i18n-mirrored templates are not pinned by the parity '
            'guard: ${mirrored.difference(covered)}');
  });
}
