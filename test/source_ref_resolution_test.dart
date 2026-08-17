import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/usecases/model_assumption_registry.dart';
import 'package:parkinsum_companion/features/shared/mechanistic_trace_view.dart';

/// W4 — Source references resolve to citations and limitations.
///
/// `ModelAssumptionRegistry` carries 17 assumptions, each with a title, a
/// citation, and a plain-language `limitation` saying what the source does
/// *not* establish. It had **zero** references in `lib/features/` — the trace
/// rendered bare ids and a count ("Sources (3) available in model trace"),
/// telling the reader provenance existed while showing none of it.
///
/// Educational prototype only; synthetic/demo data only.
void main() {
  test('a known source ref resolves to its title and limitation', () {
    const knownId = 'src.dailymed.sinemet.label';
    final assumption = ModelAssumptionRegistry.byId(knownId);
    expect(
      assumption,
      isNotNull,
      reason: 'Fixture id is no longer in the registry; pick another.',
    );

    final resolved = ResolvedSourceRef.resolve(knownId);
    expect(resolved.resolved, isTrue);
    expect(resolved.title, assumption!.title);
    expect(resolved.limitation, assumption.limitation);
    expect(resolved.limitation, isNotEmpty);
    expect(resolved.evidenceLevel, assumption.evidenceLevel.name);
  });

  test('an unknown ref is preserved, never silently dropped', () {
    // An unresolvable reference is information about the trace. Hiding it
    // would make a broken provenance link look like no link at all.
    final resolved = ResolvedSourceRef.resolve('src.does.not.exist');
    expect(resolved.resolved, isFalse);
    expect(resolved.title, 'src.does.not.exist');
    expect(resolved.limitation, isEmpty);
    expect(resolved.evidenceLevel, 'unresolved');
  });

  test('the view model resolves every emitted ref in order', () {
    final view = MechanisticTraceViewModel.fromJson(const {
      'interaction_score': 0.4,
      'severity_band': 'moderate',
      'confidence_band': 'moderate',
      'source_refs': [
        'src.dailymed.sinemet.label',
        'src.does.not.exist',
        'src.apda.levodopa.food',
      ],
    });

    expect(view.resolvedSources, hasLength(3));
    expect(
      view.resolvedSources.map((s) => s.sourceRef).toList(),
      const [
        'src.dailymed.sinemet.label',
        'src.does.not.exist',
        'src.apda.levodopa.food',
      ],
      reason: 'Order must follow the emitted refs so display is deterministic.',
    );
    expect(view.resolvedSources[0].resolved, isTrue);
    expect(view.resolvedSources[1].resolved, isFalse);
    expect(view.resolvedSources[2].resolved, isTrue);
    // The label now reports the unresolved count instead of implying all refs
    // are good.
    expect(view.sourceRefsLabel, contains('1 unresolved'));
  });

  test('no refs means no fabricated provenance', () {
    final view = MechanisticTraceViewModel.fromJson(const {
      'interaction_score': 0.0,
      'source_refs': <String>[],
    });
    expect(view.resolvedSources, isEmpty);
    expect(view.sourceRefsLabel, 'Sources: none recorded.');
  });

  test('every registry assumption can be surfaced safely', () {
    // Anything reachable by the UI must carry the limitation copy that makes
    // it safe to show.
    for (final assumption in ModelAssumptionRegistry.all) {
      final resolved = ResolvedSourceRef.resolve(assumption.sourceId);
      expect(resolved.resolved, isTrue);
      expect(
        resolved.limitation.trim(),
        isNotEmpty,
        reason: '${assumption.sourceId} would render with no limitation text.',
      );
      expect(resolved.title.trim(), isNotEmpty);
    }
  });
}
