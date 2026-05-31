/// P6 — ExplanationCopyService (runtime accessor for compiled boundary copy).
///
/// Educational/research prototype only. A thin, deterministic runtime accessor
/// that resolves non-prescriptive boundary/safety copy from the
/// `SafeCopyTemplateRegistry` THROUGH the `ExplanationCopyCompiler` (so the copy
/// the app shows is the validated copy). It always degrades to a supplied
/// fallback when a template is absent or fails validation, so it can never
/// surface unvalidated or empty text.
///
/// It adds no medical advice, no dose/timing/diet guidance, and no
/// clinical-calibration claim. It does not change scoring. No PHI / patient /
/// subject / encounter semantics.
library;

import '../entities/explanation_copy.dart';
import '../entities/rule_explanation.dart';
import 'explanation_copy_compiler.dart';
import 'safe_copy_template_registry.dart';

class ExplanationCopyService {
  final SafeCopyTemplateRegistry _registry;
  final ExplanationCopyCompiler _compiler;

  const ExplanationCopyService({
    SafeCopyTemplateRegistry registry = const SafeCopyTemplateRegistry(),
    ExplanationCopyCompiler compiler = const ExplanationCopyCompiler(),
  })  : _registry = registry,
        _compiler = compiler;

  /// Resolve a template to its compiler-validated text, or [fallback] when the
  /// template is missing or does not pass validation. Never returns empty.
  String resolve(
    String templateId, {
    required String fallback,
    Map<String, String> bindings = const {},
    String locale = '',
    CopyCompileContext context = const CopyCompileContext(),
  }) {
    final template = _registry.byId(templateId);
    if (template == null) return fallback;
    final result = _compiler.compile(
      template,
      bindings: bindings,
      locale: locale,
      context: context,
    );
    final text = result.compiled?.text;
    if (result.valid && text != null && text.trim().isNotEmpty) return text;
    return fallback;
  }

  /// Locale-strict resolve: returns the compiler-validated text **only** when
  /// the template actually carries [locale] (so a non-localized template never
  /// substitutes English for a localized string); otherwise returns [fallback].
  /// This is the safe seam for migrating localized i18n boundary keys: pass the
  /// current locale and the existing localized `tr()` value as the fallback.
  String resolveForLocale(
    String templateId, {
    required String locale,
    required String fallback,
  }) {
    final template = _registry.byId(templateId);
    if (template == null || !template.localizedText.containsKey(locale)) {
      return fallback;
    }
    return resolve(templateId, locale: locale, fallback: fallback);
  }

  /// Shared not-advice boundary copy (compiler-validated; falls back to the
  /// canonical default text).
  String notAdvice({String locale = ''}) => resolve(
        'not_advice_default',
        locale: locale,
        fallback: RuleExplanation.defaultNotAdvice,
      );

  /// Shared safety-boundary copy (compiler-validated; falls back to the
  /// canonical default text).
  String safetyBoundary({String locale = ''}) => resolve(
        'safety_boundary_default',
        locale: locale,
        fallback: RuleExplanation.defaultSafetyBoundary,
      );
}
