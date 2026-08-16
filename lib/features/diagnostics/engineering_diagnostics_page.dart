import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/entities/rule_explanation.dart';
import '../../domain/usecases/explanation_copy_diagnostics.dart';
import '../../domain/usecases/localization_lint_diagnostics.dart';
import '../../domain/usecases/mechanistic_replay_runner.dart';
import '../../domain/usecases/safe_copy_template_registry.dart';

/// Read-only engineering diagnostics.
///
/// The peripheral governance layer (copy compiler, localization safety lint,
/// deterministic replay) was previously reachable only through command-line
/// tools, so nothing it verifies was visible to someone using the app. This
/// page runs the same pure, deterministic checks in-process and reports what
/// they found.
///
/// Deliberately **read-only and non-authoritative**:
///  * it changes no scores, severities, evidence, or rule outcomes;
///  * it is not part of any recommendation path;
///  * it shows engineering/governance status, never health guidance.
///
/// Educational prototype only. Synthetic/demo data only. Not medical advice
/// and not calibrated for real care.
class EngineeringDiagnosticsPage extends StatefulWidget {
  const EngineeringDiagnosticsPage({super.key});

  @override
  State<EngineeringDiagnosticsPage> createState() =>
      _EngineeringDiagnosticsPageState();
}

class _EngineeringDiagnosticsPageState
    extends State<EngineeringDiagnosticsPage> {
  List<_Check>? _checks;
  int _elapsedMs = 0;

  @override
  void initState() {
    super.initState();
    // Cheap enough to run inline (~120ms measured across all three); kept off
    // the first frame so the page paints immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  void _run() {
    final sw = Stopwatch()..start();
    final results = <_Check>[];

    // 1 — Explanation copy compiler (P6).
    try {
      final report = compileRegistryWithSamples();
      results.add(_Check(
        title: 'Explanation copy compiler',
        summary: '${report.compiledCount}/${report.templateCount} templates '
            'compiled',
        detail: 'Validates placeholders, required safety terms and banned '
            'prescriptive phrasing across the safe-copy registry.',
        blockers: report.blockerCount,
      ));
    } catch (e) {
      results.add(_Check.error('Explanation copy compiler', e));
    }

    // 2 — Localization safety lint (P7), registry + full app dictionary.
    try {
      final report = lintAllLocalizationSurfaces();
      results.add(_Check(
        title: 'Localization safety lint',
        summary: '${report.surfaceCount} surfaces scanned',
        detail: 'Every shipped string across all language families is checked '
            'for prescriptive or over-assertive phrasing.',
        blockers: report.blockerCount,
      ));
    } catch (e) {
      results.add(_Check.error('Localization safety lint', e));
    }

    // 3 — Deterministic mechanistic replay.
    try {
      final report = MechanisticReplayRunner().run();
      results.add(_Check(
        title: 'Mechanistic replay',
        summary: '${report.passedCount}/${report.totalCount} synthetic '
            'scenarios passed',
        detail: 'Fixed synthetic scenarios replayed through the deterministic '
            'engine; output is compared against recorded expectations.',
        blockers: report.totalCount - report.passedCount,
      ));
    } catch (e) {
      results.add(_Check.error('Mechanistic replay', e));
    }

    // 4 — Registry inventory (no pass/fail; context for the checks above).
    const registry = SafeCopyTemplateRegistry();
    results.add(_Check(
      title: 'Safe-copy template registry',
      summary: '${registry.templates.length} governed templates',
      detail: 'Boundary and rule-finding copy resolved through the compiler '
          'rather than hard-coded at each call site.',
      blockers: 0,
    ));

    sw.stop();
    if (!mounted) return;
    setState(() {
      _checks = results;
      _elapsedMs = sw.elapsedMilliseconds;
    });
  }

  @override
  Widget build(BuildContext context) {
    final i18n = context.appI18n;
    final checks = _checks;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(
        title: Text(i18n.tr('diagnostics.title')),
        actions: [
          IconButton(
            tooltip: i18n.tr('diagnostics.rerun'),
            icon: const Icon(Icons.refresh, size: 20),
            onPressed: () => setState(() {
              _checks = null;
              WidgetsBinding.instance.addPostFrameCallback((_) => _run());
            }),
          ),
        ],
      ),
      body: checks == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _BoundaryCard(i18n: i18n),
                const SizedBox(height: 12),
                for (final c in checks) ...[
                  _CheckCard(check: c),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                Text(
                  i18n.tr('diagnostics.elapsed', {'ms': '$_elapsedMs'}),
                  style: const TextStyle(
                    fontSize: 11,
                    color: LiquidGlass.onSurfaceMuted,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Non-negotiable framing shown above the results.
class _BoundaryCard extends StatelessWidget {
  final AppI18n i18n;
  const _BoundaryCard({required this.i18n});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.science_outlined, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  i18n.tr('diagnostics.scope_title'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: LiquidGlass.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            i18n.tr('diagnostics.scope_body'),
            style: const TextStyle(
              fontSize: 12,
              height: 1.45,
              color: LiquidGlass.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            RuleExplanation.defaultNotAdvice,
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: LiquidGlass.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckCard extends StatelessWidget {
  final _Check check;
  const _CheckCard({required this.check});

  @override
  Widget build(BuildContext context) {
    final ok = check.failed == false && check.blockers == 0;
    final label = check.failed
        ? 'error'
        : check.blockers == 0
            ? 'pass'
            : '${check.blockers} blocker${check.blockers == 1 ? '' : 's'}';

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ok ? Icons.check_circle_outline : Icons.error_outline,
                size: 18,
                semanticLabel: label,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  check.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: LiquidGlass.onSurface,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: ok
                        ? LiquidGlass.onSurfaceMuted
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            check.summary,
            style: const TextStyle(
              fontSize: 13,
              color: LiquidGlass.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            check.detail,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: LiquidGlass.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _Check {
  final String title;
  final String summary;
  final String detail;
  final int blockers;
  final bool failed;

  const _Check({
    required this.title,
    required this.summary,
    required this.detail,
    required this.blockers,
    this.failed = false,
  });

  factory _Check.error(String title, Object error) => _Check(
        title: title,
        summary: 'Check could not run',
        detail: '$error',
        blockers: 0,
        failed: true,
      );
}
