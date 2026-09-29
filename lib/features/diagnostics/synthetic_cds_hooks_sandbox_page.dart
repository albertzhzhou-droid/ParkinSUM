import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/theme/paper_theme.dart';
import '../../domain/usecases/synthetic_cds_hooks_card_projector.dart';
import '../../domain/usecases/synthetic_cds_hooks_challenge_service.dart';
import '../../domain/usecases/synthetic_cds_hooks_enactment_replay.dart';
import '../../domain/usecases/synthetic_cds_hooks_sandbox_service.dart';
import '../../domain/usecases/synthetic_cds_hooks_service_registry.dart';

/// Local engineering panel for the fixed, code-owned synthetic CDS Hooks
/// examples. It cannot accept patient data or send a request to a service.
class SyntheticCdsHooksSandboxPage extends StatefulWidget {
  const SyntheticCdsHooksSandboxPage({super.key, required this.localeTag});

  final String localeTag;

  @override
  State<SyntheticCdsHooksSandboxPage> createState() =>
      _SyntheticCdsHooksSandboxPageState();
}

class _SyntheticCdsHooksSandboxPageState
    extends State<SyntheticCdsHooksSandboxPage> {
  final SyntheticCdsHooksSandboxService _service =
      SyntheticCdsHooksSandboxService();
  SyntheticCdsHooksScenario _scenario =
      SyntheticCdsHooksScenario.completeProteinMeal;
  SyntheticCdsHooksHook _hook = SyntheticCdsHooksHook.patientView;
  int? _replayPosition;
  SyntheticCdsHooksSandboxRun? _result;
  bool _loading = false;
  String? _error;

  bool get _isChinese => widget.localeTag.toLowerCase().startsWith('zh');

  String _text(String english, String chinese) =>
      _isChinese ? chinese : english;

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final result = await _service.run(_scenario);
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      debugPrint('Synthetic CDS Hooks sandbox failed: ${error.runtimeType}.');
      if (!mounted) return;
      setState(() {
        _result = null;
        _error = _text(
          'The fixed local scenario could not be evaluated.',
          '固定的本地合成场景未能完成计算。',
        );
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    final cards = (result?.response['cards'] as List? ?? const <Object?>[])
        .cast<Map<String, dynamic>>();
    final card = cards.isEmpty ? null : cards.single;
    final trace = card == null
        ? null
        : ((card['extension']
                  as Map<String, dynamic>)[cdsHooksRuleTraceExtensionName]
              as Map<String, dynamic>);
    final matchingServices = SyntheticCdsHooksServiceRegistry.servicesForHook(
      _hook,
    );
    final prefetchPlan = SyntheticCdsHooksServiceRegistry.prefetchPlanForHook(
      _hook,
    );
    final resolvedPrefetchPreview =
        SyntheticCdsHooksServiceRegistry.resolvedPrefetchPreviewForHook(_hook);
    final serviceScopedPrefetchBindings =
        SyntheticCdsHooksServiceRegistry.serviceScopedPrefetchBindingsForHook(
          _hook,
        );
    final servicePrefetchPayloadPlans =
        SyntheticCdsHooksServiceRegistry.serviceScopedPrefetchPayloadsForHook(
          _hook,
        );
    final servicePrefetchOutcomePreviews =
        SyntheticCdsHooksServiceRegistry.serviceScopedPrefetchOutcomePreviewsForHook(
          _hook,
        );
    final serviceRequestEnvelopePreviews =
        SyntheticCdsHooksServiceRegistry.serviceRequestEnvelopePreviewsForHook(
          _hook,
        );
    final serviceResponsePreviews =
        SyntheticCdsHooksServiceRegistry.serviceResponsePreviewsForHook(_hook);
    final enactment = SyntheticCdsHooksEnactmentReplay.createForHook(_hook);
    final replayPosition = _replayPosition ?? enactment.events.length;
    final replayState = SyntheticCdsHooksEnactmentReplay.replayThrough(
      enactment,
      completedEventCount: replayPosition,
    );
    final prefetchAssignmentCount = prefetchPlan.fold<int>(
      0,
      (count, group) => count + group.serviceAssignments.length,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface.withAlpha(255),
      appBar: PaperAppBar(
        title: Text(_text('Synthetic CDS Hooks sandbox', '合成 CDS Hooks 沙盒')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          PaperCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text('Local information-card projection', '本地信息卡片投影'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _text(
                      'Choose one fixed synthetic fixture and run the current rule engine in memory. This is a CDS Hooks v2-style contract exercise, not a CDS service or EHR connection.',
                      '选择固定的合成示例，在内存中运行当前规则引擎。这是 CDS Hooks v2 风格的契约演练，不是 CDS 服务或 EHR 连接。',
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<SyntheticCdsHooksScenario>(
                    key: const Key('synthetic-cds-hooks-scenario'),
                    initialValue: _scenario,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _text('Synthetic scenario', '合成场景'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final scenario in SyntheticCdsHooksScenario.values)
                        DropdownMenuItem(
                          value: scenario,
                          child: Text(_scenarioLabel(scenario)),
                        ),
                    ],
                    onChanged: _loading
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() {
                              _scenario = value;
                              _result = null;
                              _error = null;
                            });
                          },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      key: const Key('run-synthetic-cds-hooks-scenario'),
                      onPressed: _loading ? null : _run,
                      icon: _loading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(
                        _loading
                            ? _text('Running locally…', '正在本地运行…')
                            : _text('Run locally', '本地运行'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_error case final error?) ...[
            _MessageCard(
              icon: Icons.error_outline,
              title: _text('Run failed', '运行失败'),
              body: error,
            ),
            const SizedBox(height: 12),
          ],
          if (result != null) ...[
            _ResponseCard(
              card: card,
              trace: trace,
              result: result,
              text: _text,
            ),
            const SizedBox(height: 12),
          ],
          PaperCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _text(
                      'Synthetic multi-service hook preview',
                      '合成多服务 Hook 预览',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _text(
                      'Preview which fixed service metadata matches a hook. This is a local dispatch plan only; it does not resolve or invoke services.',
                      '预览固定服务元数据与 Hook 的匹配结果。这里只生成本地分发计划，不解析或调用服务。',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<SyntheticCdsHooksHook>(
                    key: const Key('synthetic-cds-hooks-hook'),
                    initialValue: _hook,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: _text('CDS Hook', 'CDS Hook'),
                      border: const OutlineInputBorder(),
                    ),
                    items: [
                      for (final hook in SyntheticCdsHooksHook.values)
                        DropdownMenuItem(
                          key: Key(
                            'synthetic-cds-hooks-hook-option-${hook.wireValue}',
                          ),
                          value: hook,
                          child: Text(hook.wireValue),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        _hook = value;
                        _replayPosition = null;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _text(
                      '${matchingServices.length} matching synthetic services',
                      '匹配到 ${matchingServices.length} 个合成服务',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  for (final service in matchingServices) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isChinese ? service.titleZh : service.title,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            service.id,
                            key: Key(
                              'synthetic-cds-hooks-service-id-${service.id}',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _text(
                              service.description,
                              '仅供测试的服务元数据；不存在临床内容或服务端点。',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _text(
                      'Prefetch request plan (not executed)',
                      '预取请求计划（未执行）',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _text(
                      '${prefetchPlan.length} exact query templates, $prefetchAssignmentCount service-key assignments. Identical templates may share a planned request; keys remain scoped to the requesting service. The next line substitutes only a fixed synthetic id; no request or resource payload is created.',
                      '${prefetchPlan.length} 个完全相同的查询模板组，$prefetchAssignmentCount 个服务键分配。相同模板可合并为一个计划请求，但键仍归属于各自服务。下方只用固定合成 ID 替换令牌，不发送请求或生成资源载荷。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var index = 0; index < prefetchPlan.length; index++) ...[
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SelectableText(
                            prefetchPlan[index].queryTemplate,
                            key: Key(
                              'synthetic-cds-hooks-prefetch-query-$index',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _text(
                              'Resolved relative path preview (fixed synthetic id, not sent)',
                              '解析后的相对路径预览（固定合成 ID，未发送）',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          SelectableText(
                            resolvedPrefetchPreview[index].relativeFhirRequest,
                            key: Key(
                              'synthetic-cds-hooks-prefetch-resolved-$index',
                            ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 6),
                          for (final assignment
                              in prefetchPlan[index].serviceAssignments)
                            Text(
                              '${assignment.serviceId}.${assignment.prefetchKey}',
                              key: Key(
                                'synthetic-cds-hooks-prefetch-assignment-${assignment.serviceId}-${assignment.prefetchKey}',
                              ),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    _text(
                      'Per-service prefetch-key mapping (path metadata only)',
                      '按服务展示的预取键映射（仅路径元数据）',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _text(
                      'Each service retains only its own keys. Paths are not resource values; the next section shows fixed synthetic result fixtures only.',
                      '每个服务仅保留自己的键。路径不是资源值；下一节只展示固定的合成结果夹具。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final servicePlan in serviceScopedPrefetchBindings) ...[
                    Text(
                      servicePlan.serviceId,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    for (final binding in servicePlan.bindings)
                      SelectableText(
                        '${binding.prefetchKey} → ${binding.relativeFhirRequest}',
                        key: Key(
                          'synthetic-cds-hooks-service-prefetch-binding-${servicePlan.serviceId}-${binding.prefetchKey}',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _text(
                      'Fixed synthetic prefetch payload preview (not sent)',
                      '固定合成预取载荷预览（未发送）',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _text(
                      'The Patient stub contains only its fixed synthetic id; the Condition result is an empty searchset fixture, not a clinical conclusion. Neither result is read from a record or passed to the local rule engine.',
                      'Patient 夹具仅包含固定合成 ID；Condition 结果是空搜索集夹具，不代表临床结论。两者都不读取病历，也不会传入本地规则引擎。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final servicePlan in servicePrefetchPayloadPlans) ...[
                    Text(
                      servicePlan.serviceId,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SelectableText(
                      const JsonEncoder.withIndent(
                        '  ',
                      ).convert(servicePlan.prefetchPayload),
                      key: Key(
                        'synthetic-cds-hooks-prefetch-payload-${servicePlan.serviceId}',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _text(
                      'Prefetch outcome semantics (fixed example, not sent)',
                      '预取结果状态语义（固定示例，未发送）',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _text(
                      'A resource or empty searchset is a supplied value; explicit_null keeps the key with JSON null; not_satisfied omits the key. An empty searchset means the query returned zero matches, not a clinical conclusion. These state labels are explanatory metadata and are not sent.',
                      'resource 或 empty_searchset 表示提供了结果值；explicit_null 表示保留键并赋 JSON null；not_satisfied 表示省略该键。空搜索集表示查询没有匹配项，不是临床结论。这些状态标签仅作解释，不会发送。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final plan in servicePrefetchOutcomePreviews) ...[
                    Text(
                      plan.serviceId,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    for (final entry in plan.keyOutcomes.entries)
                      Text(
                        '${entry.key}: ${entry.value.wireValue}; in prefetch: ${plan.prefetchPayload.containsKey(entry.key)}',
                        key: Key(
                          'synthetic-cds-hooks-prefetch-outcome-${plan.serviceId}-${entry.key}',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    SelectableText(
                      const JsonEncoder.withIndent(
                        '  ',
                      ).convert(plan.prefetchPayload),
                      key: Key(
                        'synthetic-cds-hooks-prefetch-outcome-payload-${plan.serviceId}',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _text(
                      'Synthetic CDS Hooks request envelope preview (not sent)',
                      '合成 CDS Hooks 请求信封预览（未发送）',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _text(
                      'These fixed examples include only the required hook context and that service’s own prefetch map. The UUID-shaped hookInstance values are fixed display placeholders, not fresh runtime identifiers. order-select contains one un-coded synthetic draft ServiceRequest, not a real order or recommendation. No request is sent.',
                      '这些固定示例只包含必需的 hook 上下文和该服务自己的预取映射。UUID 形状的 hookInstance 是固定展示占位值，不是运行时新生成的标识。order-select 含一个无编码的合成草稿 ServiceRequest，不是真实医嘱或建议。不会发送请求。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final plan in serviceRequestEnvelopePreviews) ...[
                    Text(
                      plan.serviceId,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SelectableText(
                      const JsonEncoder.withIndent(
                        '  ',
                      ).convert(plan.requestBody),
                      key: Key(
                        'synthetic-cds-hooks-request-envelope-${plan.serviceId}',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _text(
                      'Fixed per-service response previews (not invoked or merged)',
                      '固定的逐服务响应预览（未调用、未合并）',
                    ),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _text(
                      'Each registered service keeps its own synthetic response. One fixed fixture has a single information-only card; the other returns an empty cards array for no guidance. This is not a service result or a multi-service aggregate.',
                      '每个已登记服务保留独立的合成响应。一个固定示例含一张仅信息卡；另一个返回空 cards 数组，表示无指导内容。这不是实际服务结果，也不是多服务聚合结果。',
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final preview in serviceResponsePreviews) ...[
                    Text(
                      '${preview.serviceId} · ${preview.state.wireValue} · ${preview.cardCount} card(s)',
                      key: Key(
                        'synthetic-cds-hooks-service-response-label-${preview.serviceId}',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    SelectableText(
                      const JsonEncoder.withIndent(
                        '  ',
                      ).convert(preview.response),
                      key: Key(
                        'synthetic-cds-hooks-service-response-${preview.serviceId}',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _EnactmentReplayCard(
            state: replayState,
            eventCount: enactment.events.length,
            onPositionChanged: (position) =>
                setState(() => _replayPosition = position),
            text: _text,
            isChinese: _isChinese,
          ),
          const SizedBox(height: 12),
          _MessageCard(
            icon: Icons.lock_outline,
            key: const Key('synthetic-cds-hooks-scope-and-limits'),
            title: _text('Scope and limits', '范围与限制'),
            body: _text(
              'Only bundled synthetic fixtures are available. The path and per-service payload previews use a fixed code-owned Patient id and an empty Condition searchset; they are never sent or passed to the rule engine. No account, saved health record, free-text input, network request, suggestion, app link, or automatic action is used. The stable unsalted input digest is pseudonymous; this sandbox must not be used with real data. Results are engineering examples, not clinical conclusions or standards certification.',
              '仅提供内置合成夹具。路径和按服务展示的载荷预览只使用代码中固定的 Patient ID 和空 Condition 搜索集，不会发送，也不会传入规则引擎。不读取账户或已保存的健康记录，不接受自由文本，不发起网络请求，也不使用建议项、应用链接或自动操作。稳定且未加盐的输入摘要属于假名化数据；本沙盒不得用于真实数据。结果仅用于工程演示，不代表临床结论或标准认证。',
            ),
          ),
        ],
      ),
    );
  }

  String _scenarioLabel(SyntheticCdsHooksScenario scenario) =>
      switch (scenario) {
        SyntheticCdsHooksScenario.completeProteinMeal => _text(
          'Complete synthetic context',
          '完整的合成上下文',
        ),
        SyntheticCdsHooksScenario.missingMealContext => _text(
          'Missing synthetic meal context',
          '缺少合成餐食上下文',
        ),
        SyntheticCdsHooksScenario.lowProteinMeal => _text(
          'Synthetic no-match case',
          '合成无匹配场景',
        ),
      };
}

typedef _Localize = String Function(String english, String chinese);

class _EnactmentReplayCard extends StatelessWidget {
  const _EnactmentReplayCard({
    required this.state,
    required this.eventCount,
    required this.onPositionChanged,
    required this.text,
    required this.isChinese,
  });

  final SyntheticCdsHooksEnactmentReplayState state;
  final int eventCount;
  final ValueChanged<int> onPositionChanged;
  final String Function(String english, String chinese) text;
  final bool isChinese;

  @override
  Widget build(BuildContext context) => PaperCard(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text('Protocol / enactment replay', '协议 / 执行实例回放'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            text(
              'A versioned protocol definition stays separate from this fixed per-hook preview instance. Choose how many events to replay; the selected state is rebuilt from an immutable event prefix. No service is called and no result is persisted.',
              '带版本的协议定义与固定 Hook 预览实例分开。选择要回放的事件数，页面会从不可变事件前缀重建状态。不会调用服务，也不会保存结果。',
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            '${state.protocol.id} · v${state.protocol.version} · ${state.enactmentId}',
            key: const Key('synthetic-cds-hooks-replay-identity'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            key: const Key('synthetic-cds-hooks-replay-position'),
            initialValue: state.completedEventCount,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: text('Replay checkpoint', '回放检查点'),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (var count = 0; count <= eventCount; count++)
                DropdownMenuItem(
                  key: Key('synthetic-cds-hooks-replay-option-$count'),
                  value: count,
                  child: Text(
                    text(
                      '$count of $eventCount events',
                      '已回放 $count / $eventCount 个事件',
                    ),
                  ),
                ),
            ],
            onChanged: (value) {
              if (value != null) onPositionChanged(value);
            },
          ),
          const SizedBox(height: 8),
          Text(
            text(
              'Replay position: ${state.completedEventCount} / $eventCount events',
              '回放位置：${state.completedEventCount} / $eventCount 个事件',
            ),
            key: const Key('synthetic-cds-hooks-replay-position-label'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (state.nextEvent case final next?) ...[
            const SizedBox(height: 4),
            Text(
              text(
                'Next event: ${next.sequence}. ${_stageLabel(next.stage)}',
                '下一个事件：${next.sequence}. ${_stageLabel(next.stage, chinese: true)}',
              ),
              key: Key('synthetic-cds-hooks-replay-next-${next.sequence}'),
            ),
          ],
          const SizedBox(height: 8),
          for (final event in state.completedEvents)
            ListTile(
              key: Key('synthetic-cds-hooks-replay-event-${event.sequence}'),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${event.sequence}. ${_stageLabel(event.stage, chinese: isChinese)}',
              ),
              subtitle: Text(
                '${event.serviceId}\n${_eventDetails(event, text)}',
              ),
            ),
          if (state.isComplete)
            Text(
              text('All fixed preview events are replayed.', '已回放全部固定预览事件。'),
              key: const Key('synthetic-cds-hooks-replay-complete'),
            ),
        ],
      ),
    ),
  );

  static String _stageLabel(
    SyntheticCdsHooksProtocolStage stage, {
    bool chinese = false,
  }) => switch ((stage, chinese)) {
    (SyntheticCdsHooksProtocolStage.serviceMatched, false) => 'Service matched',
    (SyntheticCdsHooksProtocolStage.prefetchPlanned, false) =>
      'Prefetch planned',
    (SyntheticCdsHooksProtocolStage.requestPreviewed, false) =>
      'Request previewed',
    (SyntheticCdsHooksProtocolStage.responsePreviewed, false) =>
      'Response previewed',
    (SyntheticCdsHooksProtocolStage.serviceMatched, true) => '已匹配服务',
    (SyntheticCdsHooksProtocolStage.prefetchPlanned, true) => '已规划预取',
    (SyntheticCdsHooksProtocolStage.requestPreviewed, true) => '已预览请求',
    (SyntheticCdsHooksProtocolStage.responsePreviewed, true) => '已预览响应',
  };

  static String _eventDetails(
    SyntheticCdsHooksEnactmentEvent event,
    String Function(String english, String chinese) text,
  ) => switch (event.stage) {
    SyntheticCdsHooksProtocolStage.serviceMatched => text(
      'Hook ${event.details['hook']} matched in the fixed registry.',
      '在固定注册表中匹配到 Hook ${event.details['hook']}。',
    ),
    SyntheticCdsHooksProtocolStage.prefetchPlanned => text(
      'Keys: ${(event.details['prefetchKeys'] as List).join(', ')}',
      '键：${(event.details['prefetchKeys'] as List).join('、')}',
    ),
    SyntheticCdsHooksProtocolStage.requestPreviewed => text(
      '${(event.details['requestFields'] as List).length} fixed request fields; not sent.',
      '${(event.details['requestFields'] as List).length} 个固定请求字段；未发送。',
    ),
    SyntheticCdsHooksProtocolStage.responsePreviewed => text(
      '${event.details['state']}; ${event.details['cardCount']} card(s); not invoked.',
      '${event.details['state']}；${event.details['cardCount']} 张卡片；未调用服务。',
    ),
  };
}

class _ResponseCard extends StatelessWidget {
  const _ResponseCard({
    required this.card,
    required this.trace,
    required this.result,
    required this.text,
  });

  final Map<String, dynamic>? card;
  final Map<String, dynamic>? trace;
  final SyntheticCdsHooksSandboxRun result;
  final _Localize text;

  @override
  Widget build(BuildContext context) {
    if (card == null || trace == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MessageCard(
            icon: Icons.info_outline,
            title: text('No information card emitted', '未生成信息卡片'),
            body: text(
              'The fixed scenario produced an empty cards response. This means only that no card was emitted for this synthetic run; it is not a clinical conclusion.',
              '固定场景返回了空 cards 响应。这只表示本次合成运行没有生成卡片，不构成临床结论。',
            ),
          ),
          const SizedBox(height: 12),
          _ResponseEnvelope(response: result.response, text: text),
        ],
      );
    }

    final source = card!['source'] as Map<String, dynamic>;
    return PaperCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, color: Colors.blueGrey),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    card!['summary'] as String,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(card!['detail'] as String),
            const Divider(height: 24),
            _MetadataRow(
              label: text('Trace decision', '追踪决策'),
              value: trace!['traceDecision'] as String,
            ),
            _MetadataRow(
              label: text('Interpreted state', '解释状态'),
              value: trace!['resultState'] as String,
            ),
            _MetadataRow(
              label: text('Input completeness', '输入完整度'),
              value: trace!['inputCompleteness'] as String,
            ),
            _MetadataRow(
              label: text('Rule pack', '规则包'),
              value: result.rulePackVersion,
            ),
            _MetadataRow(
              label: text('Card source', '卡片来源'),
              value: source['label'] as String,
            ),
            if (result.missingInputs.isNotEmpty)
              _MetadataRow(
                label: text('Missing input codes', '缺失输入代码'),
                value: result.missingInputs.join(', '),
              ),
            const SizedBox(height: 8),
            Text(
              text('Synthetic input digest (pseudonymous)', '合成输入摘要（假名化）'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            SelectableText(
              result.inputDigest
                  .replaceAllMapped(RegExp(r'.{8}'), (match) => '${match[0]}\n')
                  .trim(),
              key: const Key('synthetic-cds-hooks-input-digest'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
            const SizedBox(height: 12),
            _SyntheticCdsHooksChallengePanel(
              key: ValueKey(
                'synthetic-challenge:${result.inputDigest}:${jsonEncode(card)}',
              ),
              run: result,
              text: text,
            ),
            const SizedBox(height: 12),
            _ResponseEnvelope(response: result.response, text: text),
          ],
        ),
      ),
    );
  }
}

class _SyntheticCdsHooksChallengePanel extends StatefulWidget {
  const _SyntheticCdsHooksChallengePanel({
    super.key,
    required this.run,
    required this.text,
  });

  final SyntheticCdsHooksSandboxRun run;
  final _Localize text;

  @override
  State<_SyntheticCdsHooksChallengePanel> createState() =>
      _SyntheticCdsHooksChallengePanelState();
}

class _SyntheticCdsHooksChallengePanelState
    extends State<_SyntheticCdsHooksChallengePanel> {
  final SyntheticCdsHooksChallengeService _service =
      const SyntheticCdsHooksChallengeService();
  final TextEditingController _rationale = TextEditingController();
  SyntheticCdsHooksChallengeReason? _reason;
  SyntheticCdsHooksChallengeNote? _note;
  String? _error;

  @override
  void dispose() {
    _rationale.dispose();
    super.dispose();
  }

  String _reasonLabel(SyntheticCdsHooksChallengeReason reason) =>
      switch (reason) {
        SyntheticCdsHooksChallengeReason.informationMayBeIncorrect =>
          widget.text('Information may be incorrect', '信息可能不正确'),
        SyntheticCdsHooksChallengeReason.contextMismatch => widget.text(
          'Context mismatch',
          '上下文不匹配',
        ),
        SyntheticCdsHooksChallengeReason.explanationUnclear => widget.text(
          'Explanation is unclear',
          '解释不清楚',
        ),
        SyntheticCdsHooksChallengeReason.duplicateOrAlreadyAddressed =>
          widget.text('Duplicate or already addressed', '重复或已处理'),
        SyntheticCdsHooksChallengeReason.other => widget.text(
          'Other reason',
          '其他原因',
        ),
      };

  void _createChallenge() {
    final reason = _reason;
    if (reason == null) return;
    try {
      final note = _service.create(
        run: widget.run,
        reason: reason,
        rationale: _rationale.text,
      );
      debugPrint(
        '[SyntheticCdsHooksChallenge] previewed reason=${reason.name} '
        'input=${widget.run.inputDigest.substring(0, 12)} '
        'card=${note.cardDigestSha256.substring(0, 12)} ephemeral=true',
      );
      setState(() {
        _note = note;
        _error = null;
      });
    } on FormatException {
      setState(() {
        _note = null;
        _error = widget.text(
          'Enter a short reason for this fixed synthetic example.',
          '请为此固定合成示例填写简短理由。',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => PaperCard(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.text('Challenge this synthetic explanation', '质疑此合成解释'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            widget.text(
              'For this fixed example only. Do not enter real health or personal data. The note stays in this page, is not saved or sent, and does not change the card or rule result.',
              '仅针对这个固定示例。请勿输入真实健康或个人信息。反馈只留在此页面，不会保存或发送，也不会更改卡片或规则结果。',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<SyntheticCdsHooksChallengeReason>(
            key: const Key('synthetic-cds-hooks-challenge-reason'),
            initialValue: _reason,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: widget.text('Reason', '理由'),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final reason in SyntheticCdsHooksChallengeReason.values)
                DropdownMenuItem(
                  value: reason,
                  child: Text(_reasonLabel(reason)),
                ),
            ],
            onChanged: (value) => setState(() {
              _reason = value;
              _note = null;
              _error = null;
            }),
          ),
          const SizedBox(height: 10),
          TextField(
            key: const Key('synthetic-cds-hooks-challenge-rationale'),
            controller: _rationale,
            minLines: 2,
            maxLines: 4,
            maxLength: 1000,
            decoration: InputDecoration(
              labelText: widget.text('Why should it be reviewed?', '为什么需要复核？'),
              border: const OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {
              _note = null;
              _error = null;
            }),
          ),
          if (_error case final error?) ...[
            const SizedBox(height: 4),
            Text(error, key: const Key('synthetic-cds-hooks-challenge-error')),
          ],
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const Key('synthetic-cds-hooks-challenge-submit'),
            onPressed: _reason == null || _rationale.text.trim().isEmpty
                ? null
                : _createChallenge,
            icon: const Icon(Icons.flag_outlined),
            label: Text(widget.text('Preview challenge note', '预览质疑说明')),
          ),
          if (_note case final note?) ...[
            const SizedBox(height: 10),
            Text(
              widget.text(
                'Local challenge preview · not saved or sent',
                '本地质疑预览 · 未保存或发送',
              ),
              key: const Key('synthetic-cds-hooks-challenge-boundary'),
              style: Theme.of(context).textTheme.labelMedium,
            ),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(note.toJson()),
              key: const Key('synthetic-cds-hooks-challenge-json'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}

class _ResponseEnvelope extends StatelessWidget {
  const _ResponseEnvelope({required this.response, required this.text});

  final Map<String, dynamic> response;
  final _Localize text;

  @override
  Widget build(BuildContext context) => PaperCard(
    child: ExpansionTile(
      key: const Key('synthetic-cds-hooks-response-expansion'),
      title: Text(text('Response envelope', '响应内容')),
      subtitle: Text(text('Read-only synthetic JSON', '只读合成 JSON')),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(response),
              key: const Key('synthetic-cds-hooks-response-json'),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
      ],
    ),
  );
}

class _MetadataRow extends StatelessWidget {
  const _MetadataRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 145,
          child: Text(label, style: Theme.of(context).textTheme.labelMedium),
        ),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => PaperCard(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(body),
        ],
      ),
    ),
  );
}
