import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/explanation_copy.dart';
import 'package:parkinsum_companion/domain/entities/safe_copy_template.dart';
import 'package:parkinsum_companion/domain/usecases/explanation_copy_compiler.dart';
import 'package:parkinsum_companion/domain/usecases/explanation_copy_diagnostics.dart';
import 'package:parkinsum_companion/domain/usecases/safe_copy_template_registry.dart';

/// W3 — Source-reference coverage.
///
/// Two things were true and neither was visible:
///
///   1. **Coverage was never measured.** `source_ref_traceability_test.dart`
///      checks that emitted refs *resolve*; an output emitting zero refs passed
///      silently. Nothing computed "N of M claim-bearing surfaces carry a ref".
///   2. **The requirement could not fail.** `requiresSourceRefs` is set on 1 of
///      25 templates, and the shared sample context always supplies
///      `sourceRefs: ['src.demo']` — so the flag was never exercised against
///      the condition it exists to reject.
///
/// ## The measured gap
///
/// 11 of the 25 templates are claim-bearing (`informational`) legacy findings
/// rendered by `lib/core/analysis/interaction_engine.dart`. That engine is a
/// hardcoded-threshold heuristic with **no source refs in scope at all**, so
/// those templates genuinely have no provenance to declare.
///
/// Setting `requiresSourceRefs: true` on them was tried and reverted: the
/// compiler correctly blocks, `ExplanationCopyService.resolveForLocale`
/// (default `CopyCompileContext()`, no refs) then falls back, and the effect is
/// to silently switch those surfaces back to pre-migration copy — a fix in
/// appearance only. Closing the gap for real means giving the legacy engine
/// provenance, which is engine work, not a flag flip.
///
/// So these tests do the honest thing instead: prove the mechanism works where
/// it is declared, pin the gap so it cannot grow, and name it.
///
/// Educational prototype only; synthetic/demo data only.
void main() {
  const registry = SafeCopyTemplateRegistry();
  const compiler = ExplanationCopyCompiler();

  /// A context with no provenance — the condition the requirement rejects.
  const noRefsContext = CopyCompileContext(
    sourceRefs: <String>[],
    hasLimitationText: true,
    hasNotAdviceText: true,
  );

  /// Claim-bearing templates that legitimately cannot declare provenance,
  /// because their only call site has none to give.
  ///
  /// Every entry is a known gap, not an exemption on the merits. Removing an
  /// entry (by wiring real refs) is the goal; adding one requires a reason.
  const knownUnsourcedClaimTemplates = <String>{
    'legacy_high_protein_strong',
    'legacy_high_protein_strong_detail',
    'legacy_high_protein',
    'legacy_high_protein_detail',
    'legacy_tyramine',
    'legacy_tyramine_detail',
    'legacy_mineral',
    'legacy_mineral_detail',
    'legacy_summary',
    'legacy_analysis_protein',
    'legacy_analysis_tyramine',
  };

  List<SafeCopyTemplate> claimBearing() => registry.templates
      .where((t) => kClaimBearingCopyOutputTypes.contains(t.outputType))
      .toList(growable: false);

  test('the provenance requirement actually blocks where it is declared', () {
    // The load-bearing check. If a template declaring requiresSourceRefs
    // compiles clean against an empty-refs context, the flag is decorative.
    final declaring = registry.templates
        .where((t) => t.requiresSourceRefs)
        .toList(growable: false);
    expect(
      declaring,
      isNotEmpty,
      reason: 'No template declares requiresSourceRefs; the check is vacuous.',
    );

    final report = compiler.compileAll(
      registry,
      bindingsByTemplate: kExplanationCopySampleBindings,
      contextByTemplate: {
        for (final t in declaring) t.templateId: noRefsContext,
      },
    );
    final blockedIds = report.findings
        .where((f) => f.severity == CopyCompileSeverity.blocker)
        .map((f) => f.templateId)
        .toSet();
    for (final template in declaring) {
      expect(
        blockedIds,
        contains(template.templateId),
        reason:
            '${template.templateId} declares requiresSourceRefs but compiled '
            'without provenance.',
      );
    }
  });

  test('the unsourced-claim gap is exactly the known set', () {
    // Fails in both directions: a new unsourced claim surface appears, or a
    // known one gets provenance and the list is not updated.
    final gap = claimBearing()
        .where((t) => !t.requiresSourceRefs)
        .map((t) => t.templateId)
        .toSet();
    expect(
      gap,
      knownUnsourcedClaimTemplates,
      reason:
          'The set of claim-bearing templates without provenance changed. If '
          'a template gained source refs, remove it from '
          'knownUnsourcedClaimTemplates. If a new unsourced claim surface was '
          'added, wire provenance rather than extending the list.',
    );
  });

  test('coverage of claim-bearing templates does not regress', () {
    final claim = claimBearing();
    final covered = claim.where((t) => t.requiresSourceRefs).length;
    // Ratchet seeded at the observed value. Raising it is the goal; a drop
    // means provenance was removed from a surface that used to carry it.
    expect(
      covered,
      greaterThanOrEqualTo(1),
      reason:
          'Provenance coverage regressed: $covered of ${claim.length} '
          'claim-bearing templates require refs.',
    );
  });

  test('disclaimer-only templates stay exempt and classified', () {
    // Boundary/policy copy makes no claim to source, so requiring refs there
    // would be noise. An unrecognized output type is a classification bug.
    final exempt = registry.templates
        .where((t) => !kClaimBearingCopyOutputTypes.contains(t.outputType))
        .toList(growable: false);
    expect(exempt, isNotEmpty);
    for (final template in exempt) {
      expect(
        const <String>{'boundary', 'policy'},
        contains(template.outputType),
        reason:
            'Unclassified output type "${template.outputType}" on '
            '${template.templateId}: decide whether it carries claims.',
      );
    }
  });

  test('the standard sample compile still passes with refs present', () {
    // The requirement rejects missing provenance, not provenance itself.
    final report = compileRegistryWithSamples(
      registry: registry,
      compiler: compiler,
    );
    expect(report.pass, isTrue);
    expect(report.blockerCount, 0);
  });
}
