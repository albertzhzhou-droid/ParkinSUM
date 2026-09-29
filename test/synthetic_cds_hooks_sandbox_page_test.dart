import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/features/diagnostics/engineering_diagnostics_page.dart';
import 'package:parkinsum_companion/features/diagnostics/synthetic_cds_hooks_sandbox_page.dart';

import 'helpers/page_test_harness.dart';

void main() {
  testWidgets('diagnostics opens the local synthetic CDS Hooks sandbox', (
    tester,
  ) async {
    await pumpFeaturePage(tester, const EngineeringDiagnosticsPage());
    await tester.pumpAndSettle();
    final entry = find.byKey(const Key('open-synthetic-cds-hooks-sandbox'));
    await tester.scrollUntilVisible(
      entry,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(entry);
    await tester.pumpAndSettle();

    expect(find.byType(SyntheticCdsHooksSandboxPage), findsOneWidget);
    expect(find.text('Synthetic CDS Hooks sandbox'), findsOneWidget);
    final scope = find.byKey(const Key('synthetic-cds-hooks-scope-and-limits'));
    await tester.scrollUntilVisible(
      scope,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(scope, findsOneWidget);
    expectNoWidgetErrors();
  });

  testWidgets('dispatch preview filters fixed services when the hook changes', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const SyntheticCdsHooksSandboxPage(localeTag: 'en'),
    );

    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-service-id-parkinsum-synthetic-patient-review-a',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-service-id-parkinsum-synthetic-order-selection-a',
        ),
      ),
      findsNothing,
    );
    expect(
      find.textContaining('does not resolve or invoke services'),
      findsOneWidget,
    );
    expect(
      find.textContaining('2 exact query templates, 4 service-key assignments'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-assignment-parkinsum-synthetic-patient-review-a-patient',
        ),
      ),
      findsOneWidget,
    );
    expect(find.text('Patient/{{context.patientId}}'), findsOneWidget);
    expect(
      find.byKey(const Key('synthetic-cds-hooks-prefetch-resolved-0')),
      findsOneWidget,
    );
    expect(find.text('Patient/synthetic-patient-001'), findsOneWidget);
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-service-prefetch-binding-parkinsum-synthetic-patient-review-a-patient',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.text(
        'conditions → Condition?patient=synthetic-patient-001&_count=2',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Fixed synthetic prefetch payload preview (not sent)'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-payload-parkinsum-synthetic-patient-review-a',
        ),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('"type": "searchset"'), findsWidgets);
    expect(
      find.textContaining('The Patient stub contains only'),
      findsOneWidget,
    );
    expect(
      find.text('Prefetch outcome semantics (fixed example, not sent)'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-outcome-parkinsum-synthetic-patient-review-a-conditions',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-outcome-parkinsum-synthetic-patient-review-b-subject',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-outcome-parkinsum-synthetic-patient-review-b-problem-list',
        ),
      ),
      findsOneWidget,
    );
    final patientBOutcomePayload = tester
        .widget<SelectableText>(
          find.byKey(
            const Key(
              'synthetic-cds-hooks-prefetch-outcome-payload-parkinsum-synthetic-patient-review-b',
            ),
          ),
        )
        .data!;
    expect(patientBOutcomePayload, contains('"subject": null'));
    expect(patientBOutcomePayload, isNot(contains('problem-list')));
    expect(
      find.text('Synthetic CDS Hooks request envelope preview (not sent)'),
      findsOneWidget,
    );
    expect(find.textContaining('fixed display placeholders'), findsOneWidget);
    final patientRequestJson = tester
        .widget<SelectableText>(
          find.byKey(
            const Key(
              'synthetic-cds-hooks-request-envelope-parkinsum-synthetic-patient-review-a',
            ),
          ),
        )
        .data!;
    expect(patientRequestJson, contains('"hook": "patient-view"'));
    expect(patientRequestJson, contains('"hookInstance"'));
    expect(
      patientRequestJson,
      contains('"patientId": "synthetic-patient-001"'),
    );
    expect(patientRequestJson, contains('"prefetch"'));
    expect(patientRequestJson, isNot(contains('fhirAuthorization')));

    final hookField = find.byKey(const Key('synthetic-cds-hooks-hook'));
    await _bringIntoView(tester, hookField);
    await tester.tap(hookField);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('synthetic-cds-hooks-hook-option-order-select')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-service-id-parkinsum-synthetic-order-selection-a',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-service-id-parkinsum-synthetic-patient-review-a',
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-assignment-parkinsum-synthetic-order-selection-a-patient',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-assignment-parkinsum-synthetic-patient-review-a-patient',
        ),
      ),
      findsNothing,
    );
    expect(
      find.text('Condition?patient=synthetic-patient-001&_count=2'),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-service-prefetch-binding-parkinsum-synthetic-order-selection-a-patient',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-service-prefetch-binding-parkinsum-synthetic-patient-review-a-patient',
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-payload-parkinsum-synthetic-order-selection-a',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-payload-parkinsum-synthetic-patient-review-a',
        ),
      ),
      findsNothing,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-request-envelope-parkinsum-synthetic-order-selection-a',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-request-envelope-parkinsum-synthetic-patient-review-a',
        ),
      ),
      findsNothing,
    );
    final orderRequestJson = tester
        .widget<SelectableText>(
          find.byKey(
            const Key(
              'synthetic-cds-hooks-request-envelope-parkinsum-synthetic-order-selection-a',
            ),
          ),
        )
        .data!;
    expect(orderRequestJson, contains('"hook": "order-select"'));
    expect(orderRequestJson, contains('"selections"'));
    expect(orderRequestJson, contains('"draftOrders"'));
    expect(orderRequestJson, contains('"resourceType": "ServiceRequest"'));
    expect(orderRequestJson, contains('"status": "draft"'));
    expect(orderRequestJson, contains('"intent": "order"'));
    expect(orderRequestJson, isNot(contains('"code"')));
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-outcome-parkinsum-synthetic-order-selection-a-conditions',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-prefetch-outcome-parkinsum-synthetic-patient-review-a-conditions',
        ),
      ),
      findsNothing,
    );
    expectNoWidgetErrors();
  });

  testWidgets('response previews retain each hook service outcome separately', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const SyntheticCdsHooksSandboxPage(localeTag: 'en'),
    );

    expect(
      find.text('Fixed per-service response previews (not invoked or merged)'),
      findsOneWidget,
    );
    final patientCard = tester
        .widget<SelectableText>(
          find.byKey(
            const Key(
              'synthetic-cds-hooks-service-response-parkinsum-synthetic-patient-review-a',
            ),
          ),
        )
        .data!;
    expect(
      patientCard,
      contains('Synthetic information-only response preview.'),
    );
    expect(patientCard, contains('"indicator": "info"'));
    final patientNoGuidance = tester
        .widget<SelectableText>(
          find.byKey(
            const Key(
              'synthetic-cds-hooks-service-response-parkinsum-synthetic-patient-review-b',
            ),
          ),
        )
        .data!;
    expect(patientNoGuidance, contains('"cards": []'));

    final hookField = find.byKey(const Key('synthetic-cds-hooks-hook'));
    await _bringIntoView(tester, hookField);
    await tester.tap(hookField);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('synthetic-cds-hooks-hook-option-order-select')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-service-response-parkinsum-synthetic-order-selection-a',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const Key(
          'synthetic-cds-hooks-service-response-parkinsum-synthetic-patient-review-a',
        ),
      ),
      findsNothing,
    );
    expectNoWidgetErrors();
  });

  testWidgets('protocol replay rebuilds a hook-scoped event prefix', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const SyntheticCdsHooksSandboxPage(localeTag: 'en'),
    );

    await tester.scrollUntilVisible(
      find.text('Protocol / enactment replay'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Protocol / enactment replay'), findsOneWidget);
    expect(find.text('Replay position: 8 / 8 events'), findsOneWidget);
    expect(
      find.byKey(const Key('synthetic-cds-hooks-replay-event-8')),
      findsOneWidget,
    );

    final position = find.byKey(
      const Key('synthetic-cds-hooks-replay-position'),
    );
    await _bringIntoView(tester, position);
    await tester.tap(position);
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('synthetic-cds-hooks-replay-option-3')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Replay position: 3 / 8 events'), findsOneWidget);
    expect(
      find.byKey(const Key('synthetic-cds-hooks-replay-event-3')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('synthetic-cds-hooks-replay-event-4')),
      findsNothing,
    );
    expect(
      find.byKey(const Key('synthetic-cds-hooks-replay-next-4')),
      findsOneWidget,
    );

    expectNoWidgetErrors();
  });

  testWidgets('protocol replay stage labels follow the page locale', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const SyntheticCdsHooksSandboxPage(localeTag: 'zh-Hans'),
    );

    await tester.scrollUntilVisible(
      find.text('协议 / 执行实例回放'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('协议 / 执行实例回放'), findsOneWidget);
    expect(find.text('回放位置：8 / 8 个事件'), findsOneWidget);
    expect(find.textContaining('1. 已匹配服务'), findsOneWidget);
    expectNoWidgetErrors();
  });

  testWidgets('challenge preview is local, bounded, and cleared on edits', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const SyntheticCdsHooksSandboxPage(localeTag: 'en'),
    );

    final runButton = find.byKey(const Key('run-synthetic-cds-hooks-scenario'));
    await _bringIntoView(tester, runButton);
    await tester.tap(runButton);
    await tester.pumpAndSettle();

    final reasonField = find.byKey(
      const Key('synthetic-cds-hooks-challenge-reason'),
    );
    final rationaleField = find.byKey(
      const Key('synthetic-cds-hooks-challenge-rationale'),
    );
    final submit = find.byKey(
      const Key('synthetic-cds-hooks-challenge-submit'),
    );
    await _bringIntoView(tester, submit);
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.tap(reasonField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Context mismatch').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      rationaleField,
      'The fixed synthetic example leaves out a context field.',
    );
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
    await _bringIntoView(tester, submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    final preview = find.byKey(const Key('synthetic-cds-hooks-challenge-json'));
    final challengeJson = tester.widget<SelectableText>(preview).data!;
    expect(challengeJson, contains('parkinsum_synthetic_cds_hooks_challenge'));
    expect(challengeJson, contains('"schemaVersion": 1'));
    expect(challengeJson, contains('"reason": "contextMismatch"'));
    expect(challengeJson, contains('"persisted": false'));
    expect(challengeJson, contains('"transmitted": false'));
    expect(challengeJson, contains('"ruleOutcomeChanged": false'));
    expect(challengeJson, contains('"cardDigestSha256":'));

    await _bringIntoView(tester, rationaleField);
    await tester.enterText(rationaleField, 'Edited synthetic rationale.');
    await tester.pump();
    expect(preview, findsNothing);

    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    final list = find.byType(ListView).first;
    final listScrollable = find
        .descendant(of: list, matching: find.byType(Scrollable))
        .first;
    tester.state<ScrollableState>(listScrollable).position.jumpTo(0);
    await tester.pumpAndSettle();
    final scenarioField = find.byKey(const Key('synthetic-cds-hooks-scenario'));
    await _bringIntoView(tester, scenarioField);
    await tester.tap(scenarioField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Synthetic no-match case').last);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('synthetic-cds-hooks-challenge-rationale')),
      findsNothing,
    );
    expectNoWidgetErrors();
  });

  testWidgets('challenge reason choices follow the Chinese locale', (
    tester,
  ) async {
    await pumpFeaturePage(
      tester,
      const SyntheticCdsHooksSandboxPage(localeTag: 'zh-Hans'),
    );
    final runButton = find.byKey(const Key('run-synthetic-cds-hooks-scenario'));
    await _bringIntoView(tester, runButton);
    await tester.tap(runButton);
    await tester.pumpAndSettle();

    final reasonField = find.byKey(
      const Key('synthetic-cds-hooks-challenge-reason'),
    );
    await _bringIntoView(tester, reasonField);
    await tester.tap(reasonField);
    await tester.pumpAndSettle();
    expect(find.text('上下文不匹配'), findsOneWidget);
    await tester.tap(find.text('上下文不匹配').last);
    await tester.pumpAndSettle();
    expectNoWidgetErrors();
  });

  testWidgets(
    'fixed scenarios render an info card or a bounded empty response',
    (tester) async {
      await pumpFeaturePage(
        tester,
        const SyntheticCdsHooksSandboxPage(localeTag: 'en'),
      );

      final runButton = find.byKey(
        const Key('run-synthetic-cds-hooks-scenario'),
      );
      await _bringIntoView(tester, runButton);
      await tester.tap(runButton);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(
          'Synthetic educational rule trace; inputs may be incomplete.',
        ),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.text(
          'Synthetic educational rule trace; inputs may be incomplete.',
        ),
        findsOneWidget,
      );
      expect(find.text('matched'), findsWidgets);
      expect(
        find.byKey(const Key('synthetic-cds-hooks-input-digest')),
        findsOneWidget,
      );
      expect(find.text('Card source'), findsOneWidget);
      final responsePanel = find.byKey(
        const Key('synthetic-cds-hooks-response-expansion'),
      );
      await _bringIntoView(tester, responsePanel);
      await tester.tap(responsePanel);
      await tester.pumpAndSettle();
      final matchedJson = tester
          .widget<SelectableText>(
            find.byKey(const Key('synthetic-cds-hooks-response-json')),
          )
          .data!;
      expect(matchedJson, contains('"indicator": "info"'));
      expect(matchedJson, contains('org.parkinsum.cdss-rule-trace'));
      expect(matchedJson, contains('ParkinSUM synthetic rule explanation'));
      expectNoWidgetErrors();

      await _scrollToTop(tester);
      final scenarioField = find.byKey(
        const Key('synthetic-cds-hooks-scenario'),
      );
      await _bringIntoView(tester, scenarioField);
      await tester.tap(scenarioField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Missing synthetic meal context').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('run-synthetic-cds-hooks-scenario')),
      );
      await tester.pumpAndSettle();
      expect(find.text('unknown'), findsOneWidget);
      expect(find.text('incomplete'), findsOneWidget);
      expectNoWidgetErrors();

      await _scrollToTop(tester);
      await _bringIntoView(tester, scenarioField);
      await tester.tap(scenarioField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Synthetic no-match case').last);
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('run-synthetic-cds-hooks-scenario')),
      );
      await tester.pumpAndSettle();
      expect(find.text('No information card emitted'), findsOneWidget);
      final emptyResponsePanel = find.byKey(
        const Key('synthetic-cds-hooks-response-expansion'),
      );
      await _bringIntoView(tester, emptyResponsePanel);
      await tester.tap(emptyResponsePanel);
      await tester.pumpAndSettle();
      final emptyJson = tester
          .widget<SelectableText>(
            find.byKey(const Key('synthetic-cds-hooks-response-json')),
          )
          .data!;
      expect(emptyJson, contains('"cards": []'));
      expectNoWidgetErrors();
    },
  );
}

Future<void> _bringIntoView(WidgetTester tester, Finder target) async {
  final list = find.byType(ListView).first;
  final viewport = tester.getRect(list);
  for (var attempt = 0; attempt < 10; attempt++) {
    final targetRect = tester.getRect(target);
    if (targetRect.top >= viewport.top &&
        targetRect.bottom <= viewport.bottom) {
      return;
    }
    await tester.drag(list, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  fail('Could not scroll ${target.toString()} into the sandbox viewport.');
}

Future<void> _scrollToTop(WidgetTester tester) async {
  final list = find.byType(ListView).first;
  final listScrollable = find
      .descendant(of: list, matching: find.byType(Scrollable))
      .first;
  for (var attempt = 0; attempt < 10; attempt++) {
    final position = tester.state<ScrollableState>(listScrollable).position;
    if (position.pixels <= position.minScrollExtent) return;
    await tester.drag(list, const Offset(0, 500));
    await tester.pumpAndSettle();
  }
}
