import 'package:flutter/material.dart';

import '../../core/constants/baseline_cdss_rules.dart';
import '../../core/constants/clinical_evidence_source_seed.dart';
import '../../core/db/cdss_database_memory.dart';
import '../../core/theme/liquid_glass_theme.dart';
import '../../domain/entities/cdss_records.dart';
import '../../domain/entities/rule_explanation.dart';
import '../../domain/entities/runtime_context.dart';
import '../../domain/usecases/clinical_decision_support_service.dart';
import '../../domain/usecases/fact_conflict_engine.dart';
import '../../domain/usecases/rule_registry_compiler.dart';
import '../../domain/usecases/runtime_rule_engine.dart';

/// One evaluation's audit trail: the projected rows plus how many audit
/// records the run actually persisted.
class RuleAuditTrailData {
  final List<Map<String, dynamic>> rows;
  final int persistedAuditRecordCount;

  const RuleAuditTrailData({
    required this.rows,
    required this.persistedAuditRecordCount,
  });
}

/// Read-only view of the rule audit trail.
///
/// The app could show *why a rule fired* live, but nothing could show why one
/// **did not** — and the documented audit contract (`RuleExplanation`) was
/// never produced anywhere, so there was nothing to render even in principle.
///
/// This page runs one fixed synthetic evaluation through the real engine and
/// lists every rule in the registry with its outcome: fired, not matched,
/// superseded by a more specific rule, or out of jurisdiction — each with the
/// inputs it used, the inputs it lacked, and its provenance.
///
/// It changes nothing. The evaluation uses the in-memory backend and a
/// hardcoded synthetic context, touches no user data, and its output is a
/// read-only projection of what the engine already computed.
///
/// Educational prototype only; synthetic/demo data only; not calibrated for
/// real care. Nothing here is health guidance — it is a record of
/// deterministic rule bookkeeping.
class RuleAuditTrailPage extends StatefulWidget {
  /// Supplies the trail. Defaults to [runSyntheticRuleAuditTrail].
  ///
  /// Injectable because the real evaluation awaits artifact-store I/O, which
  /// does not resolve inside `testWidgets`' fake-async zone — and because a
  /// page should not hard-code where its data comes from.
  final Future<RuleAuditTrailData> Function()? loader;

  const RuleAuditTrailPage({super.key, this.loader});

  @override
  State<RuleAuditTrailPage> createState() => _RuleAuditTrailPageState();
}

/// Runs one fixed synthetic evaluation and projects its audit trail.
///
/// Lives outside the widget so tests, tooling, and the page share one
/// definition of "the demo evaluation".
Future<RuleAuditTrailData> runSyntheticRuleAuditTrail() async {
  final database = InMemoryCdssDatabase();
  final service = ClinicalDecisionSupportService(
    database: database,
    factConflictEngine: FactConflictEngine(),
    runtimeRuleEngine: RuntimeRuleEngine(),
  );
  await service.initializeKnowledgeBase(
    sourceDocuments: clinicalEvidenceSourceDocuments,
    variantScopes: const <VariantScopeRecord>[],
    observations: const <ObservationRecord>[],
    resolvedFacts: const <ResolvedFactRecord>[],
  );
  final output = await service.run(
    context: syntheticAuditTrailContext(),
    rules: RuleRegistryCompiler().compileJsonList(
      baselineCdssRules,
      rulesVersion: 'audit_trail_view',
    ),
    factsVersion: 'facts_v1',
    rulesVersion: 'rules_v1',
  );
  return RuleAuditTrailData(
    rows: output.ruleExplanationsJson,
    // Proves the write actually landed: these inserts used to be discarded.
    persistedAuditRecordCount: database.conflictAuditLog.length,
  );
}

/// A fixed synthetic context. Not a patient, not a scenario to imitate — just
/// enough input to exercise the registry deterministically.
UnifiedRuntimeContext syntheticAuditTrailContext() => UnifiedRuntimeContext(
  userProfile: const UserProfileRuntimeContext(
    patientId: 'synthetic_demo',
    registrationRegion: 'US',
    displayLocale: 'en-US',
    contentJurisdictionOverride: [],
    dietProfileRegion: 'US',
    timezone: 'UTC',
  ),
  drug: const DrugRuntimeContext(
    id: 'synthetic_drug',
    genericName: 'carbidopa/levodopa',
    brandName: 'Sinemet',
    activeIngredients: ['carbidopa', 'levodopa'],
    substanceTags: ['levodopa'],
    formulation: 'tablet',
    dosageForm: 'tablet',
    route: 'oral',
    releaseType: 'immediate',
    dailyDoseMg: null,
    jurisdiction: 'US',
  ),
  meal: const MealRuntimeContext(
    id: 'synthetic_meal',
    totalProteinG: 25,
    tyramineMgEstimate: 0,
    highFatHighCalorie: false,
    itemIds: ['synthetic_food'],
  ),
  coevent: null,
  enteralFeed: null,
  timestamps: TimestampRuntimeContext(
    drugTime: DateTime.utc(2026, 1, 1, 8),
    mealTime: DateTime.utc(2026, 1, 1, 9),
    coeventTime: null,
  ),
);

class _RuleAuditTrailPageState extends State<RuleAuditTrailPage> {
  List<Map<String, dynamic>>? _rows;
  int _auditRecordCount = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    try {
      final data = await (widget.loader ?? runSyntheticRuleAuditTrail)();
      if (!mounted) return;
      setState(() {
        _rows = data.rows;
        _auditRecordCount = data.persistedAuditRecordCount;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    final firedCount = rows?.where((r) => r['triggered'] == true).length ?? 0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: GlassAppBar(title: const Text('Rule audit trail')),
      body: _error != null
          ? Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Audit trail could not be produced: $_error'),
            )
          : rows == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _AuditBoundaryCard(
                  ruleCount: rows.length,
                  firedCount: firedCount,
                  auditRecordCount: _auditRecordCount,
                ),
                const SizedBox(height: 12),
                for (final row in rows) ...[
                  _RuleAuditCard(row: row),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _AuditBoundaryCard extends StatelessWidget {
  final int ruleCount;
  final int firedCount;
  final int auditRecordCount;

  const _AuditBoundaryCard({
    required this.ruleCount,
    required this.firedCount,
    required this.auditRecordCount,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'One synthetic evaluation, every rule accounted for',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            '$ruleCount rules evaluated · $firedCount fired · '
            '$auditRecordCount audit records persisted.',
            style: const TextStyle(
              fontSize: 12,
              color: LiquidGlass.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'A rule that did not fire is listed with the reason it did not. '
            'This is a record of deterministic rule bookkeeping on synthetic '
            'demo inputs — it is engineering evidence, not health guidance, '
            'and it describes no real person.',
            style: TextStyle(fontSize: 11, color: LiquidGlass.onSurfaceMuted),
          ),
          const SizedBox(height: 8),
          const Text(
            RuleExplanation.defaultNotAdvice,
            style: TextStyle(fontSize: 11, color: LiquidGlass.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _RuleAuditCard extends StatelessWidget {
  final Map<String, dynamic> row;
  const _RuleAuditCard({required this.row});

  List<String> _strings(Object? value) => value is List
      ? value.map((e) => e.toString()).toList(growable: false)
      : const <String>[];

  @override
  Widget build(BuildContext context) {
    final triggered = row['triggered'] == true;
    final missing = _strings(row['missing_or_uncertain_inputs']);
    final sourceRefs = _strings(row['source_refs']);

    return GlassCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                triggered
                    ? Icons.play_circle_outline
                    : Icons.remove_circle_outline,
                size: 18,
                semanticLabel: triggered ? 'fired' : 'did not fire',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${row['rule_id']}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _line('Outcome', '${row['user_facing_decision']}'),
          _line('Confidence', '${row['confidence_note']}'),
          _line('Provenance', '${row['provenance_summary']}'),
          if (sourceRefs.isNotEmpty)
            _line('Sources', sourceRefs.join(', '))
          else
            _line('Sources', 'none attached'),
          if (missing.isNotEmpty) _line('Missing inputs', missing.join(', ')),
          const SizedBox(height: 6),
          Text(
            '${row['limitation_text']}',
            style: const TextStyle(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              color: LiquidGlass.onSurfaceMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Text(
      '$label: $value',
      style: const TextStyle(fontSize: 11, color: LiquidGlass.onSurfaceMuted),
    ),
  );
}
