/// Shared sample inputs for compiling the whole SafeCopyTemplateRegistry.
///
/// Templates that declare placeholders cannot compile without bindings, and
/// templates that declare structural requirements (sourceRefs / limitation /
/// not-advice) cannot compile without a context. Every caller that compiles the
/// **entire** registry therefore needs the same sample inputs.
///
/// Those inputs used to be copy-pasted into the CLI and three separate test
/// maps, so adding a placeholder-bearing template broke callers one at a time.
/// This is the single source of truth.
///
/// Educational prototype only. Deterministic; synthetic sample values; adds no
/// medical advice and is not wired into scoring.
library;

import '../entities/explanation_copy.dart';
import 'explanation_copy_compiler.dart';
import 'safe_copy_template_registry.dart';

/// Deterministic sample bindings, for templates that declare placeholders.
const Map<String, Map<String, String>> kExplanationCopySampleBindings = {
  'mechanistic_explanation_boundary': {'overlap_percent': '42'},
  'legacy_analysis': {'drugCount': '1', 'score': '42'},
  'legacy_high_protein_strong_detail': {'protein': '40.0', 'drug': 'Sample'},
  'legacy_high_protein_detail': {'protein': '25.0', 'drug': 'Sample'},
  'legacy_tyramine_detail': {'drug': 'Sample'},
  'legacy_summary': {'score': '42', 'severity': 'Moderate', 'count': '2'},
  'legacy_analysis_protein': {'protein': '25.0'},
};

/// Sample context supplying the structural requirements a template may declare.
const CopyCompileContext kExplanationCopySampleContext = CopyCompileContext(
  sourceRefs: ['src.demo'],
  hasLimitationText: true,
  hasNotAdviceText: true,
);

/// Compiles every registry template with the shared sample inputs.
///
/// This is the same computation the `copy:compile` CLI performs, so an in-app
/// diagnostics view and the CI gate cannot report different numbers.
CopyCompileReport compileRegistryWithSamples({
  SafeCopyTemplateRegistry registry = const SafeCopyTemplateRegistry(),
  ExplanationCopyCompiler compiler = const ExplanationCopyCompiler(),
}) {
  return compiler.compileAll(
    registry,
    bindingsByTemplate: kExplanationCopySampleBindings,
    contextByTemplate: {
      for (final t in registry.templates)
        t.templateId: kExplanationCopySampleContext,
    },
  );
}
