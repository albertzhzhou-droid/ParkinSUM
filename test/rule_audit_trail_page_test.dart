import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/constants/baseline_cdss_rules.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/features/diagnostics/rule_audit_trail_page.dart';

import 'helpers/page_test_harness.dart';

/// W5 — Post-hoc "why" view.
///
/// The live conflict trace could show why a rule *fired*; nothing could show
/// why one did not, because the documented audit contract was never produced.
/// This page renders the W1 projection: every rule in the registry with its
/// outcome and reason.
///
/// Educational prototype only; synthetic/demo data only.
void main() {
  // The real evaluation awaits artifact-store I/O, which never resolves inside
  // the fake-async zone `testWidgets` installs. Computing it once with
  // `runAsync` and injecting the result exercises the genuine engine output
  // rather than a fixture, while keeping the widget pumps synchronous.
  late RuleAuditTrailData trail;

  Future<void> pumpAuditTrail(WidgetTester tester) async {
    await tester.runAsync(() async {
      trail = await runSyntheticRuleAuditTrail();
    });
    await pumpFeaturePage(
      tester,
      RuleAuditTrailPage(loader: () async => trail),
    );
    await tester.pump();
  }

  testWidgets('renders every registry rule, fired and unfired', (tester) async {
    await pumpAuditTrail(tester);

    expectNoWidgetErrors(reason: 'audit trail page failed to build');
    expect(find.text('Rule audit trail'), findsOneWidget);

    // Completeness is a property of the trail, not of the viewport: a ListView
    // only builds the children near the visible area, so asserting every id is
    // on screen at once would test scroll position, not coverage.
    final renderedIds = trail.rows.map((r) => r['rule_id']).toSet();
    for (final rule in baselineCdssRules) {
      final ruleId = rule['rule_id'] as String;
      expect(
        renderedIds,
        contains(ruleId),
        reason: '$ruleId is absent from the audit trail.',
      );
    }

    // And the trail is actually rendered, not merely computed: the first rule
    // is on screen, and scrolling reaches the last one.
    final firstId = trail.rows.first['rule_id'] as String;
    expect(find.text(firstId), findsOneWidget);

    final lastId = trail.rows.last['rule_id'] as String;
    await tester.scrollUntilVisible(find.text(lastId), 300);
    expect(find.text(lastId), findsOneWidget);
  });

  testWidgets('states outcomes and keeps the not-advice boundary', (
    tester,
  ) async {
    await pumpAuditTrail(tester);

    expect(find.text(RuleExplanation.defaultNotAdvice), findsOneWidget);
    expect(
      find.textContaining('rules evaluated'),
      findsOneWidget,
      reason: 'The summary must state how many rules were accounted for.',
    );
    expect(
      find.textContaining('audit records persisted'),
      findsOneWidget,
      reason:
          'The count proves the audit write landed; these inserts used to be '
          'discarded on this backend.',
    );
    // At least one rule that did not fire must say so.
    expect(find.textContaining('Outcome:'), findsWidgets);
  });

  testWidgets('audit copy carries no banned prescriptive phrases', (
    tester,
  ) async {
    await pumpAuditTrail(tester);

    final texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((w) => w.data ?? '')
        .join('\n');
    expect(
      findBannedSubstrings(texts),
      isEmpty,
      reason: 'Audit trail copy drifted into prescriptive wording.',
    );
    // The banned vocabulary is asserted through findBannedSubstrings rather
    // than spelled out here: the contribution safety router scans by substring
    // (deliberately loose, because looseness is protective), so a literal in a
    // test reads to it as the copy itself.
  });

  testWidgets('survives a large text scale', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpAuditTrail(tester);
    expectNoWidgetErrors(reason: 'audit trail broke at 1.6x text scale');
  });
}
