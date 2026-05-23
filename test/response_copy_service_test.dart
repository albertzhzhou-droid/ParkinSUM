import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/copy/response_copy_service.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/models/interaction_result.dart';

void main() {
  test('response copy hides machine recommendation path codes', () {
    final copy = ResponseCopyService(
      i18n: AppI18n.fromLocaleTag('zh-CN'),
    );

    expect(
      copy.recommendationPath('conservative_safety_gate'),
      '保守路径（安全门阻断 AI）',
    );
    expect(
      copy.recommendationMessage(
        'Safety gate kept the result on the conservative path.',
      ),
      '安全门已将结果保持在保守推荐路径。',
    );
  });

  test('response copy translates common raw interaction fragments', () {
    final copy = ResponseCopyService(
      i18n: AppI18n.fromLocaleTag('zh-CN'),
    );

    final text = copy.interactionText(
      'Imported label: official label requires separation from meals. '
      'Real database nutrient facts from database food variants were used.',
    );

    expect(text, contains('官方标签要求与进餐错开'));
    expect(text, contains('数据库营养事实'));
    expect(text, contains('数据库食物变体'));
  });

  test('response copy translates stale recommendation reason text', () {
    final copy = ResponseCopyService(
      i18n: AppI18n.fromLocaleTag('zh-CN'),
    );

    final text = copy.recommendationMessage(
      'Candidate still depends on local seed metadata instead of richer database-backed observations. '
      'Timing window is incomplete, so the conservative rank keeps extra safety margin.',
    );

    expect(text, contains('本地种子元数据'));
    expect(text, contains('时间窗信息不完整'));
    expect(text, isNot(contains('Candidate still')));
    expect(text, isNot(contains('Timing window is incomplete')));
  });

  test('i18n strips unresolved placeholders from runtime copy', () {
    final i18n = AppI18n.fromLocaleTag('zh-CN');

    expect(
      i18n.tr('recommend.context_enteral_feed_continuous'),
      '当前餐次处于连续肠内营养场景，推荐会优先保守解释。',
    );
  });

  test('response copy builds user-facing interaction explanation from result',
      () {
    final copy = ResponseCopyService(
      i18n: AppI18n.fromLocaleTag('zh-CN'),
    );
    final result = InteractionResult(
      mealId: 'meal_1',
      status: InteractionStatus.warning,
      summary:
          'Database-backed food and drug variant checks found 1 advisory items.',
      analysisText:
          'The engine checked this meal against 1 active medication(s). Estimated meal protein from the current item list was about 29.2 g. Some food variants were resolved through a regional fallback chain.',
      keyFindings: const [
        'Require review · Levodopa/Carbidopa: Missing critical inputs: drug time, dose. Manual review is required.',
      ],
      nextActions: const ['The safest next step is manual review.'],
      dataNotes: const [
        'Some food variants came from a jurisdiction fallback chain.',
        'Real nutrient facts from database food variants were used when available.',
        'Missing critical input: dose',
        'Missing critical input: drug time',
      ],
      issues: [
        InteractionIssue(
          severity: InteractionSeverity.high,
          title: 'Require review · Levodopa/Carbidopa',
          detail:
              'Missing critical inputs: drug time, dose. Manual review is required.',
          relatedDrugId: 'drug_levodopa_carbidopa',
        ),
      ],
      generatedAt: DateTime.utc(2026, 1, 1),
      score: 85,
    );

    expect(copy.interactionSummary(result), contains('缺少'));
    expect(copy.interactionSummary(result), contains('用药时间'));
    expect(copy.interactionSummary(result), contains('剂量'));
    expect(copy.interactionAnalysis(result), contains('不是在说这顿饭本身一定危险'));
    expect(copy.keyFinding(result.keyFindings.first), contains('无法完成时序判断'));
    expect(copy.nextAction(result.nextActions.first), contains('补充本次用药时间和剂量'));
    expect(copy.dataNote(result.dataNotes.first), contains('备用地区数据'));
    expect(copy.issueDetail(result.issues.first), contains('不能安全判断'));
  });

  test(
      'English response copy hides runtime warning ids and names missing inputs',
      () {
    final copy = ResponseCopyService(
      i18n: AppI18n.fromLocaleTag('en-US'),
    );
    final result = InteractionResult(
      mealId: 'meal_1',
      status: InteractionStatus.warning,
      summary: 'Database-backed checks found 1 advisory item.',
      analysisText: 'Estimated meal protein is about 45.3 g.',
      keyFindings: const [
        'Require review · Levodopa/Carbidopa: Missing critical inputs: drug time, dose. Manual review is required.',
      ],
      nextActions: const ['The safest next step is manual review.'],
      dataNotes: const [
        'cdss_warning: fallback_variant_resolution food=food_banana selected=FOOD_FOOD_BANANA#FR#CIQUAL#UNSPECIFIED_CIQUAL_BANANA',
        'Missing critical input: dose',
        'Missing critical input: drug time',
      ],
      issues: [
        InteractionIssue(
          severity: InteractionSeverity.high,
          title: 'Require review · Levodopa/Carbidopa',
          detail:
              'Missing critical inputs: drug time, dose. Manual review is required.',
          relatedDrugId: 'drug_levodopa_carbidopa',
        ),
      ],
      generatedAt: DateTime.utc(2026, 1, 1),
      score: 100,
    );

    expect(
        copy.interactionSummary(result),
        contains(
            'required medication information is missing: medication time and dose'));
    expect(copy.interactionSummary(result), isNot(contains('drug time')));
    expect(copy.keyFinding(result.keyFindings.first),
        'Timing check cannot be completed because required medication information is missing: medication time and dose.');
    expect(
        copy.dataNote(result.dataNotes.first), isNot(contains('cdss_warning')));
    expect(copy.dataNote(result.dataNotes.first), isNot(contains('selected=')));
  });
}
