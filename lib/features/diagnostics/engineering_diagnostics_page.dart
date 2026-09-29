import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/state/app_state.dart';
import '../../core/theme/paper_theme.dart';
import 'replay_benchmark_card.dart';
import '../../domain/entities/rule_explanation.dart';
import '../../domain/usecases/catalog_inventory_diagnostics.dart';
import '../../domain/usecases/explanation_copy_diagnostics.dart';
import '../../domain/usecases/localization_lint_diagnostics.dart';
import '../../domain/usecases/mechanistic_replay_runner.dart';
import '../../domain/usecases/safe_copy_template_registry.dart';
import 'rule_audit_trail_page.dart';
import 'rule_test_workbench_page.dart';
import 'knowledge_lifecycle_workbench_page.dart';
import 'synthetic_cds_hooks_sandbox_page.dart';
import 'fhir_r4_observation_preview_page.dart';
import 'fhir_r4_medication_statement_import_page.dart';
import 'fhir_r4_medication_request_import_page.dart';
import 'fhir_r4_allergy_intolerance_import_page.dart';
import 'fhir_r4_condition_import_page.dart';
import 'fhir_r4_encounter_import_page.dart';
import 'fhir_r4_medication_administration_import_page.dart';
import 'fhir_r4_medication_dispense_import_page.dart';
import 'fhir_r5_medication_product_preview_page.dart';
import 'openfda_label_mention_search_page.dart';
import 'evidence_source_metadata_search_page.dart';

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
/// Educational prototype only. Engineering checks use synthetic/demo data;
/// the separate FDA label-text view requires explicit per-session consent.
/// Nothing on this page is medical advice or calibrated for real care.
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
      results.add(
        _Check(
          title: 'Explanation copy compiler',
          summary:
              '${report.compiledCount}/${report.templateCount} templates '
              'compiled',
          detail:
              'Validates placeholders, required safety terms and banned '
              'prescriptive phrasing across the safe-copy registry.',
          blockers: report.blockerCount,
        ),
      );
    } catch (e) {
      results.add(_Check.error('Explanation copy compiler', e));
    }

    // 2 — Localization safety lint (P7), registry + full app dictionary.
    try {
      final report = lintAllLocalizationSurfaces();
      results.add(
        _Check(
          title: 'Localization safety lint',
          summary: '${report.surfaceCount} surfaces scanned',
          detail:
              'Every shipped string across all language families is checked '
              'for prescriptive or over-assertive phrasing.',
          blockers: report.blockerCount,
        ),
      );
    } catch (e) {
      results.add(_Check.error('Localization safety lint', e));
    }

    // 3 — Deterministic mechanistic replay.
    try {
      final report = MechanisticReplayRunner().run();
      results.add(
        _Check(
          title: 'Mechanistic replay',
          summary:
              '${report.passedCount}/${report.totalCount} synthetic '
              'scenarios passed',
          detail:
              'Fixed synthetic scenarios replayed through the deterministic '
              'engine; output is compared against recorded expectations.',
          blockers: report.totalCount - report.passedCount,
        ),
      );
    } catch (e) {
      results.add(_Check.error('Mechanistic replay', e));
    }

    // 4 — Registry inventory (no pass/fail; context for the checks above).
    const registry = SafeCopyTemplateRegistry();
    results.add(
      _Check(
        title: 'Safe-copy template registry',
        summary: '${registry.templates.length} governed templates',
        detail:
            'Boundary and rule-finding copy resolved through the compiler '
            'rather than hard-coded at each call site.',
        blockers: 0,
      ),
    );
    try {
      // Inventory-only, like the registry card above: what the prototype
      // actually ships. Computed by the same domain function the
      // `catalog:inventory` CLI calls, so the two cannot disagree.
      final inventory = buildCatalogInventory();
      results.add(
        _Check(
          title: 'Catalog inventory',
          summary:
              '${inventory.foodCount} foods · ${inventory.drugCount} '
              'medications · ${inventory.sourceDocumentCount} source documents '
              '· ${inventory.ruleCount} rules',
          detail:
              '${inventory.modelAssumptionCount} model assumptions and '
              '${inventory.replayScenarioCount} replay scenarios ship. '
              '${inventory.nonLiveSourceDocumentCount} source documents are '
              'declared but not carrying live data, and '
              '${inventory.unspecifiedSourceCodeCount} catalog entries still '
              'use a placeholder external code. Counting coverage is not a '
              'claim that the coverage is adequate.',
          blockers: 0,
        ),
      );
    } catch (e) {
      results.add(_Check.error('Catalog inventory', e));
    }

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
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: PaperAppBar(
        title: Text(i18n.tr('diagnostics.title')),
        actions: [
          IconButton(
            tooltip: 'Rule audit trail',
            icon: const Icon(Icons.fact_check_outlined, size: 20),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const RuleAuditTrailPage(),
              ),
            ),
          ),
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
                PaperCard(
                  child: ListTile(
                    key: const Key('open-rule-test-workbench'),
                    leading: const Icon(Icons.science_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '规则测试工作台'
                          : 'Rule test workbench',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '编辑合成病例，比较规则版本并检查预期结果。'
                          : 'Edit synthetic cases, compare rule packs and check expected outcomes.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            RuleTestWorkbenchPage(localeTag: i18n.localeTag),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-knowledge-lifecycle-workbench'),
                    leading: const Icon(Icons.verified_user_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '知识规则包治理'
                          : 'Knowledge pack governance',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '查看授权状态、导入草稿，并记录外部签名的审阅、激活或撤回。'
                          : 'Inspect authority state, import drafts, and record externally signed review, activation, or withdrawal.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => KnowledgeLifecycleWorkbenchPage(
                          services: Provider.of<AppState>(
                            context,
                            listen: false,
                          ).services,
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-synthetic-cds-hooks-sandbox'),
                    leading: const Icon(Icons.account_tree_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '合成 CDS Hooks 沙盒'
                          : 'Synthetic CDS Hooks sandbox',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '用固定合成场景本地演练信息卡片契约。'
                          : 'Exercise the information-card contract with fixed synthetic scenarios, locally.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => SyntheticCdsHooksSandboxPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-openfda-label-mention-search'),
                    leading: const Icon(Icons.manage_search_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? 'OpenFDA 标签文字检索'
                          : 'OpenFDA label text search',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '手动输入两个通用名；单独确认后才向 FDA 发送查询。只做标签文字匹配，不判断相互作用。'
                          : 'Manually enter two generic names. FDA requests require separate consent; this is label-text matching, not an interaction decision.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OpenFdaLabelMentionSearchPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-evidence-source-metadata-search'),
                    leading: const Icon(Icons.manage_search_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '本地证据来源检索'
                          : 'Local evidence source search',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '只按已登记来源元数据排序；不检索原始载荷或判断证据。'
                          : 'Ranks registered source metadata only; it does not search payloads or judge evidence.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => EvidenceSourceMetadataSearchPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-fhir-r4-observation-preview'),
                    leading: const Icon(Icons.monitor_heart_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? 'FHIR R4 血压观察预览'
                          : 'FHIR R4 blood-pressure preview',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '在本机内存中检查合成或去标识化的单条 Observation；不会保存或发送。'
                          : 'Inspect one synthetic or de-identified Observation in memory; nothing is saved or sent.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FhirR4ObservationPreviewPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-fhir-r4-medication-statement-import'),
                    leading: const Icon(Icons.medication_liquid_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? 'FHIR R4 用药陈述导入预览'
                          : 'FHIR R4 MedicationStatement import preview',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '只在内存中检查单条陈述或 collection；状态与剂量文字仍是未核实的来源声明。'
                          : 'Preview one statement or a collection in memory; status and dosage text remain unverified source claims.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FhirR4MedicationStatementImportPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-fhir-r4-medication-request-preview'),
                    leading: const Icon(Icons.medication_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? 'FHIR R4 MedicationRequest 请求预览'
                          : 'FHIR R4 MedicationRequest preview',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '仅在内存中检查请求状态与意图；不代表已调配、给药或服用。'
                          : 'Inspect request status and intent in memory; this does not show dispensing, administration, or use.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FhirR4MedicationRequestImportPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-fhir-r4-allergy-intolerance-preview'),
                    leading: const Icon(Icons.health_and_safety_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? 'FHIR R4 AllergyIntolerance 来源字段预览'
                          : 'FHIR R4 AllergyIntolerance preview',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '仅在内存中查看分开的状态与来源术语；不作过敏判断或临床解释。'
                          : 'Inspect separate source statuses and terms in memory; no allergy conclusion or clinical interpretation.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FhirR4AllergyIntoleranceImportPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-fhir-r4-condition-preview'),
                    leading: const Icon(Icons.assignment_late_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? 'FHIR R4 Condition 来源字段预览'
                          : 'FHIR R4 Condition preview',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '保留诊断代码、临床状态与核实状态；不作诊断判断或规则评估。'
                          : 'Inspect source codes and separate clinical/verification statuses; no diagnosis or rule evaluation.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FhirR4ConditionImportPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-fhir-r4-encounter-preview'),
                    leading: const Icon(Icons.event_note_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? 'FHIR R4 Encounter 就诊上下文预览'
                          : 'FHIR R4 Encounter context preview',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '仅在内存中检查来源状态、类别代码、Patient 匹配和时间段；不解释临床场景。'
                          : 'Inspect source status, class code, Patient match, and period in memory; no clinical interpretation.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FhirR4EncounterImportPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key(
                      'open-fhir-r4-medication-administration-preview',
                    ),
                    leading: const Icon(Icons.medical_services_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? 'FHIR R4 MedicationAdministration 来源预览'
                          : 'FHIR R4 MedicationAdministration preview',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '保留来源状态、药品编码与时间；不证明实际给药或服药，也不进入规则。'
                          : 'Inspect source status, medication coding, and time; no proof of administration or rule use.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            FhirR4MedicationAdministrationImportPage(
                              localeTag: i18n.localeTag,
                            ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-fhir-r4-medication-dispense-preview'),
                    leading: const Icon(Icons.local_pharmacy_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? 'FHIR R4 MedicationDispense 来源预览'
                          : 'FHIR R4 MedicationDispense preview',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '保留来源发药状态、数量与时间；不能证明取药或服用，也不进入规则。'
                          : 'Inspect source dispensing status, quantity, and time; no proof of pickup or use, and no rule input.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FhirR4MedicationDispenseImportPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                PaperCard(
                  child: ListTile(
                    key: const Key('open-fhir-r5-medication-product-preview'),
                    leading: const Icon(Icons.medication_outlined),
                    title: Text(
                      i18n.localeTag.startsWith('zh')
                          ? 'FHIR R5 药品产品预览'
                          : 'FHIR R5 medication product preview',
                    ),
                    subtitle: Text(
                      i18n.localeTag.startsWith('zh')
                          ? '检查内置离线产品快照的来源字段与有限强度投影；不会保存、联网或进入算法。'
                          : 'Inspect source fields and bounded strength projection from the bundled offline catalog; nothing is saved, sent, or used by an algorithm.',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => FhirR5MedicationProductPreviewPage(
                          localeTag: i18n.localeTag,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                for (final c in checks) ...[
                  _CheckCard(check: c),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 6),
                Text(
                  i18n.tr('diagnostics.elapsed', {'ms': '$_elapsedMs'}),
                  style: const TextStyle(fontSize: 11, color: Paper.inkMuted),
                ),
                const SizedBox(height: 16),
                const ReplayBenchmarkCard(),
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
    return PaperCard(
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
                    color: Paper.ink,
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
              color: Paper.inkMuted,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            RuleExplanation.defaultNotAdvice,
            style: TextStyle(fontSize: 12, height: 1.45, color: Paper.inkMuted),
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

    return PaperCard(
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
                    color: Paper.ink,
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
                        ? Paper.inkMuted
                        : Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            check.summary,
            style: const TextStyle(fontSize: 13, color: Paper.ink),
          ),
          const SizedBox(height: 4),
          Text(
            check.detail,
            style: const TextStyle(
              fontSize: 12,
              height: 1.4,
              color: Paper.inkMuted,
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
