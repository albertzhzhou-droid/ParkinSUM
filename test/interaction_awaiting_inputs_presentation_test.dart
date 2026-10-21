// Missing dose or medication time is presented as a neutral "can't assess
// yet" state instead of a red risk level. Presentation only: the stored score,
// severity and rule decisions are unchanged. Synthetic data; not medical
// advice.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/copy/response_copy_service.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/models/interaction_result.dart';
import 'package:parkinsum_companion/core/services/services.dart';
import 'package:parkinsum_companion/core/state/app_state.dart';
import 'package:parkinsum_companion/features/shared/interaction_result_view.dart';
import 'package:provider/provider.dart';

const _missingDetail =
    'Missing critical inputs: drug time, dose. Manual review is required.';

InteractionIssue _missingIssue() => InteractionIssue(
  severity: InteractionSeverity.high,
  title: 'Require review · Levodopa/Carbidopa',
  detail: _missingDetail,
  relatedDrugId: 'drug_levodopa_carbidopa',
);

InteractionResult _result({
  List<InteractionIssue>? issues,
  List<String> nextActions = const ['The safest next step is manual review.'],
  int score = 100,
}) {
  return InteractionResult(
    mealId: 'synthetic_meal',
    status: InteractionStatus.warning,
    summary: 'Database-backed checks found 1 advisory item.',
    analysisText: 'Estimated meal protein is about 31.0 g.',
    keyFindings: const ['Require review · Levodopa/Carbidopa: $_missingDetail'],
    nextActions: nextActions,
    dataNotes: const [
      'Missing critical input: dose',
      'Missing critical input: drug time',
    ],
    issues: issues ?? [_missingIssue()],
    generatedAt: DateTime.utc(2026, 10, 20),
    score: score,
    scoreFactors: const [
      InteractionScoreFactor(
        code: 'rule_decision_weight',
        label: 'Rule decision weight',
        points: 70,
      ),
    ],
  );
}

void main() {
  final en = ResponseCopyService(i18n: AppI18n.fromLocaleTag('en-US'));
  final zh = ResponseCopyService(i18n: AppI18n.fromLocaleTag('zh-CN'));

  test('missing dose and time alone read as "can\'t assess yet"', () {
    final result = _result();
    expect(result.overallSeverity, InteractionSeverity.high);
    expect(en.awaitingMissingInputs(result), isTrue);
    expect(
      en.awaitingInputsHeadline(result),
      "Can't assess yet — add medication time and dose",
    );
    final summary = en.interactionSummary(result);
    expect(summary, startsWith("Can't assess yet"));
    expect(summary, contains('not an all-clear'));
    expect(summary.toLowerCase(), isNot(contains('high risk')));
    expect(summary, isNot(contains('100')));

    final zhSummary = zh.interactionSummary(result);
    expect(zhSummary, startsWith('暂时无法评估'));
    expect(zhSummary, isNot(contains('高风险')));
    expect(zh.awaitingInputsHeadline(result), '暂时无法评估——请补充用药时间、剂量');
  });

  test('another elevated issue keeps the risk presentation', () {
    final result = _result(
      issues: [
        _missingIssue(),
        InteractionIssue(
          severity: InteractionSeverity.high,
          title: 'Block · Synthetic product',
          relatedDrugId: 'synthetic_product',
          detail:
              'The official label indicates this product should not be mixed with a starch-based thickener.',
        ),
      ],
    );
    expect(en.awaitingMissingInputs(result), isFalse);
    expect(en.interactionSummary(result), contains('high risk (100/100)'));
    final analysis = en.interactionAnalysis(result);
    expect(analysis, contains('also missing: medication time and dose'));
    expect(analysis, isNot(contains('does not mean the meal itself')));
  });

  test('rule advice that survived a review escalation keeps the risk '
      'presentation', () {
    // Missing inputs turn a matched rule's own decision into a review, but its
    // actions (avoid, separate, switch) remain. That rule is not hidden.
    final result = _result(
      nextActions: const [
        'The safest next step is manual review.',
        'Consider avoiding this medication-food combination.',
      ],
    );
    expect(en.awaitingMissingInputs(result), isFalse);
    expect(en.interactionSummary(result), contains('high risk'));
  });

  test('ok and unassessed results are not "awaiting inputs"', () {
    expect(
      en.awaitingMissingInputs(
        InteractionResult.ok(mealId: 'm', message: 'No rules triggered.'),
      ),
      isFalse,
    );
    expect(
      en.awaitingMissingInputs(
        InteractionResult(
          mealId: 'm',
          status: InteractionStatus.unassessed,
          summary: 'Unsupported medication context.',
          issues: [_missingIssue()],
          generatedAt: DateTime.utc(2026, 10, 20),
          score: null,
        ),
      ),
      isFalse,
    );
  });

  test('the ALLOW decision has neutral wording in every language family', () {
    const permissionWords = {
      'Allow',
      '允许',
      'Autoriser',
      '許可',
      '허용',
      'अनुमति दें',
      'Permitir',
      'Cho phép',
      'อนุญาต',
      'Izinkan',
      'Разрешить',
      'Zezwól',
      'سماح',
    };
    for (final family in AppI18n.translationFamilies) {
      final label = AppI18n.translationDictionary[family]!['decision.allow'];
      expect(label, isNotNull, reason: family);
      expect(permissionWords, isNot(contains(label)), reason: family);
    }
    expect(
      AppI18n.fromLocaleTag('en-US').decisionLabel('ALLOW'),
      'No rule flags',
    );
    expect(AppI18n.fromLocaleTag('zh-CN').decisionLabel('ALLOW'), '无规则提示');
  });

  Future<AppState> state(String locale) async {
    final services = Services.createEphemeral();
    await services.ready;
    final value = AppState(services: services);
    await value.bootstrap();
    await value.saveUserProfile(
      value.userProfile.copyWith(displayLocale: locale),
    );
    addTearDown(value.dispose);
    return value;
  }

  Future<void> pumpCard(
    WidgetTester tester,
    AppState app,
    InteractionResult r,
  ) {
    return tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: app,
        child: MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: InteractionSummaryCard(result: r),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('summary card shows a neutral state and keeps the score under '
      '"How was this computed?"', (tester) async {
    final app = (await tester.runAsync(() => state('en-US')))!;
    await pumpCard(tester, app, _result());

    final label = find.text("Can't assess yet — add medication time and dose");
    expect(label, findsOneWidget);
    expect(tester.widget<Text>(label).style?.color, Colors.blueGrey);
    expect(find.text('High risk'), findsNothing);
    expect(find.text('Score 100'), findsNothing);
    expect(
      find.textContaining("Can't assess yet · Require review"),
      findsOneWidget,
    );

    expect(find.text('Rule score: 100/100'), findsNothing);
    expect(find.text('Rule decision weight +70'), findsNothing);
    await tester.ensureVisible(find.text('How was this computed?'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How was this computed?'));
    await tester.pumpAndSettle();
    expect(find.text('Rule score: 100/100'), findsOneWidget);
    expect(find.text('Rule decision weight +70'), findsOneWidget);
    expect(
      find.textContaining('it is not shown above as a risk level'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary card keeps red risk styling for a real block', (
    tester,
  ) async {
    final app = (await tester.runAsync(() => state('en-US')))!;
    await pumpCard(
      tester,
      app,
      _result(
        score: 95,
        issues: [
          InteractionIssue(
            severity: InteractionSeverity.high,
            title: 'Block · Synthetic product',
            relatedDrugId: 'synthetic_product',
            detail:
                'The official label indicates this product should not be '
                'mixed with a starch-based thickener.',
          ),
        ],
        nextActions: const [
          'Consider avoiding this medication-food combination.',
        ],
      ),
    );
    final label = find.text('High risk');
    expect(label, findsWidgets);
    expect(tester.widget<Text>(label.first).style?.color, Colors.red);
    expect(find.text('Score 95'), findsOneWidget);
    expect(find.textContaining("Can't assess yet"), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
