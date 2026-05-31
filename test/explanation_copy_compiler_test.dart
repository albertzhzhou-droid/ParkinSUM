import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/explanation_copy.dart';
import 'package:parkinsum_companion/domain/entities/safe_copy_template.dart';
import 'package:parkinsum_companion/domain/usecases/explanation_copy_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P6 — ExplanationCopyCompiler. Pure, deterministic copy compilation +
/// validation over SafeCopyTemplates. No medical advice, no clinical-calibration
/// claim, not wired into UI/scoring. No PHI / patient / subject / encounter.
void main() {
  const compiler = ExplanationCopyCompiler();
  const registry = SafeCopyTemplateRegistry();

  SafeCopyTemplate tpl({
    String id = 't',
    String outputType = 'boundary',
    Map<String, String> text = const {'en': 'educational; not medical advice.'},
    List<String> requiredPlaceholders = const [],
    List<String> allowedPlaceholders = const [],
    List<String> requiredSafetyTerms = const [],
    List<String> requiredEvidenceTerms = const [],
    bool requiresSourceRefs = false,
    bool requiresLimitationText = false,
    bool requiresNotAdviceText = false,
  }) =>
      SafeCopyTemplate(
        templateId: id,
        outputType: outputType,
        defaultLocale: 'en',
        localizedText: text,
        requiredPlaceholders: requiredPlaceholders,
        allowedPlaceholders: allowedPlaceholders,
        requiredSafetyTerms: requiredSafetyTerms,
        requiredEvidenceTerms: requiredEvidenceTerms,
        requiresSourceRefs: requiresSourceRefs,
        requiresLimitationText: requiresLimitationText,
        requiresNotAdviceText: requiresNotAdviceText,
      );

  bool hasType(CopyCompileResult r, String t) =>
      r.findings.any((f) => f.findingType == t);

  // 1 — a well-formed template compiles and renders.
  test('well-formed template compiles', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'An educational note; not medical advice.'},
      requiredSafetyTerms: const ['educational', 'not medical advice'],
    ));
    expect(r.valid, isTrue);
    expect(r.compiled!.text, contains('educational'));
  });

  // 2 — required placeholder bound and rendered.
  test('required placeholder is rendered', () {
    final r = compiler.compile(
      tpl(
        text: const {'en': 'Overlap {overlap_percent}% — not medical advice.'},
        requiredPlaceholders: const ['overlap_percent'],
        allowedPlaceholders: const ['overlap_percent'],
      ),
      bindings: const {'overlap_percent': '42'},
    );
    expect(r.valid, isTrue);
    expect(r.compiled!.text, contains('42%'));
  });

  // 3 — missing required placeholder → blocker.
  test('missing required placeholder is blocker', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'Overlap {overlap_percent}% — not medical advice.'},
      requiredPlaceholders: const ['overlap_percent'],
      allowedPlaceholders: const ['overlap_percent'],
    ));
    expect(
        hasType(r, CopyCompileFindingType.missingRequiredPlaceholder), isTrue);
    expect(r.valid, isFalse);
  });

  // 4 — unresolved placeholder after render → blocker.
  test('unresolved placeholder is blocker', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'Value {x} — not medical advice.'},
      allowedPlaceholders: const ['x'],
    ));
    expect(hasType(r, CopyCompileFindingType.unresolvedPlaceholder), isTrue);
    expect(r.valid, isFalse);
  });

  // 5 — unknown binding → warn (not blocker).
  test('unknown binding is a warn', () {
    final r = compiler.compile(
      tpl(text: const {'en': 'educational; not medical advice.'}),
      bindings: const {'rogue': 'x'},
    );
    expect(hasType(r, CopyCompileFindingType.unknownPlaceholder), isTrue);
    expect(r.valid, isTrue);
  });

  // 6 — missing required safety term → blocker.
  test('missing required safety term is blocker', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'A plain note.'},
      requiredSafetyTerms: const ['not medical advice'],
    ));
    expect(hasType(r, CopyCompileFindingType.missingSafetyTerm), isTrue);
    expect(r.valid, isFalse);
  });

  // 7 — missing evidence term → warn only.
  test('missing evidence term is warn', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'educational; not medical advice.'},
      requiredEvidenceTerms: const ['source-linked'],
    ));
    expect(hasType(r, CopyCompileFindingType.missingEvidenceTerm), isTrue);
    expect(r.valid, isTrue);
  });

  // 8 — banned prescriptive phrase → blocker.
  test('banned prescriptive phrase is blocker', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'You should adjust your dose now.'},
    ));
    expect(hasType(r, CopyCompileFindingType.bannedPhrase), isTrue);
    expect(r.valid, isFalse);
  });

  // 9 — safe negation is not flagged as a banned phrase.
  test('safe negation is not a banned phrase', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'This is educational and not clinically validated.'},
      requiredSafetyTerms: const ['educational'],
    ));
    expect(hasType(r, CopyCompileFindingType.bannedPhrase), isFalse);
    expect(r.valid, isTrue);
  });

  // 10 — requiresSourceRefs unsatisfied → blocker.
  test('missing sourceRefs requirement is blocker', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'educational; not medical advice.'},
      requiresSourceRefs: true,
    ));
    expect(hasType(r, CopyCompileFindingType.requiresSourceRefsUnsatisfied),
        isTrue);
    expect(r.valid, isFalse);
  });

  // 11 — requiresSourceRefs satisfied by context.
  test('sourceRefs requirement satisfied by context', () {
    final r = compiler.compile(
      tpl(
          text: const {'en': 'educational; not medical advice.'},
          requiresSourceRefs: true),
      context: const CopyCompileContext(sourceRefs: ['src.demo']),
    );
    expect(r.valid, isTrue);
  });

  // 12 — requiresLimitationText unsatisfied → blocker.
  test('missing limitation requirement is blocker', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'educational; not medical advice.'},
      requiresLimitationText: true,
    ));
    expect(hasType(r, CopyCompileFindingType.requiresLimitationUnsatisfied),
        isTrue);
  });

  // 13 — requiresNotAdviceText satisfied by the rendered text itself.
  test('not-advice requirement satisfied by rendered text', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'An educational note; not medical advice.'},
      requiredSafetyTerms: const ['not medical advice'],
      requiresNotAdviceText: true,
    ));
    expect(r.valid, isTrue);
  });

  // 14 — requiresNotAdviceText unsatisfied → blocker.
  test('not-advice requirement unsatisfied is blocker', () {
    final r = compiler.compile(tpl(
      text: const {'en': 'An educational note.'},
      requiresNotAdviceText: true,
    ));
    expect(hasType(r, CopyCompileFindingType.requiresNotAdviceUnsatisfied),
        isTrue);
  });

  // 15 — locale fallback to default emits an info finding, still compiles.
  test('locale fallback emits info and compiles', () {
    final r = compiler.compile(
      tpl(text: const {'en': 'educational; not medical advice.'}),
      locale: 'fr',
    );
    expect(hasType(r, CopyCompileFindingType.localeFallback), isTrue);
    expect(r.valid, isTrue);
    expect(r.compiled!.usedDefaultLocaleFallback, isTrue);
  });

  // 16 — the whole shipped registry compiles with sample bindings (0 blocker).
  test('registry compiles cleanly', () {
    final report = compiler.compileAll(
      registry,
      bindingsByTemplate: const {
        'mechanistic_explanation_boundary': {'overlap_percent': '42'},
      },
      contextByTemplate: {
        for (final t in registry.templates)
          t.templateId: const CopyCompileContext(
            sourceRefs: ['src.demo'],
            hasLimitationText: true,
            hasNotAdviceText: true,
          ),
      },
    );
    expect(report.pass, isTrue);
    expect(report.compiledCount, registry.templates.length);
  });

  // 17 — report JSON is deterministic + no PHI keys.
  test('report JSON deterministic and no-PHI', () {
    CopyCompileReport build() => compiler.compileAll(
          registry,
          bindingsByTemplate: const {
            'mechanistic_explanation_boundary': {'overlap_percent': '42'},
          },
          contextByTemplate: {
            for (final t in registry.templates)
              t.templateId: const CopyCompileContext(
                sourceRefs: ['src.demo'],
                hasLimitationText: true,
                hasNotAdviceText: true,
              ),
          },
        );
    final a = encodeCopyCompileReport(build());
    final b = encodeCopyCompileReport(build());
    expect(a, equals(b));
    final decoded = jsonDecode(a) as Map<String, dynamic>;
    expect(decoded['report_type'], 'explanation_copy_compile');
    expect(decoded['no_medical_advice'], isTrue);
    expect(decoded['not_wired_into_ui_or_scoring'], isTrue);
    scanNoPhiKeys(decoded);
  });

  // 18 — markdown includes compiled copy and limitations.
  test('markdown includes compiled copy and limitations', () {
    final md = renderCopyCompileMarkdown(compiler.compileAll(
      registry,
      bindingsByTemplate: const {
        'mechanistic_explanation_boundary': {'overlap_percent': '42'},
      },
      contextByTemplate: {
        for (final t in registry.templates)
          t.templateId: const CopyCompileContext(
            sourceRefs: ['src.demo'],
            hasLimitationText: true,
            hasNotAdviceText: true,
          ),
      },
    ));
    expect(md, contains('Explanation Copy Compiler'));
    expect(md, contains('## Compiled copy'));
    expect(md, contains('## Limitations'));
    expect(md, contains('not wired into the UI or scoring'));
  });
}
