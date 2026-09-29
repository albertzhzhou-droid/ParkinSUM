import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n.dart';
import '../../domain/entities/dose_expression.dart';
import '../../domain/usecases/dosage_note_parser.dart';

/// Human-visible projection of the exact production dose-expression parser.
///
/// The card never validates a prescription or suggests a dose. It only makes
/// the result-affecting parse/hold boundary visible at the point of entry.
class DoseExpressionStatusCard extends StatelessWidget {
  const DoseExpressionStatusCard({
    super.key,
    required this.rawText,
    this.parser,
    this.showGrammarIdentity = false,
  });

  final String rawText;
  final DosageNoteParser? parser;
  final bool showGrammarIdentity;

  @override
  Widget build(BuildContext context) {
    if (rawText.trim().isEmpty) return const SizedBox.shrink();
    final activeParser = parser ?? DosageNoteParser();
    final result = activeParser.inspect(rawText);
    final i18n = AppI18n.fromLocaleTag(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final copy = _DoseExpressionCopy.forFamily(i18n.languageFamily);
    final accepted = result.accepted;
    final color = accepted ? const Color(0xff287d6b) : const Color(0xff9a6700);
    final expression = result.expression;

    return Semantics(
      key: const Key('dose-expression-status'),
      container: true,
      liveRegion: true,
      label: accepted ? copy.acceptedTitle : copy.heldTitle,
      child: Card(
        color: color.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    accepted
                        ? Icons.check_circle_outline
                        : Icons.pause_circle_outline,
                    key: Key(
                      accepted
                          ? 'dose-expression-accepted'
                          : 'dose-expression-held',
                    ),
                    color: color,
                    size: 21,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      accepted ? copy.acceptedTitle : copy.heldTitle,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (accepted && expression != null)
                Text(
                  '${_formatValue(expression.value)} ${expression.unit.code} · '
                  '${copy.dimension(expression.unit.dimension)} · '
                  '${copy.localVocabulary} ${expression.unit.version}',
                  key: const Key('dose-expression-accepted-summary'),
                )
              else
                Text(
                  copy.reason(result.primaryReasonCode),
                  key: const Key('dose-expression-held-reason'),
                ),
              if (!accepted && result.diagnosticStructure != null)
                Semantics(
                  label: result.diagnosticStructure!.displayText,
                  child: Text(
                    result.diagnosticStructure!.displayText,
                    key: const Key('dose-expression-held-structure'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              const SizedBox(height: 5),
              Text(
                accepted ? copy.acceptedBoundary : copy.heldBoundary,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (showGrammarIdentity) ...[
                const SizedBox(height: 6),
                SelectableText(
                  '${result.grammarId}/v${result.grammarVersion} · '
                  '${result.grammarDigest.substring(0, 12)}…',
                  key: const Key('dose-expression-grammar-identity'),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static String _formatValue(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toString();
}

final class _DoseExpressionCopy {
  const _DoseExpressionCopy({
    required this.family,
    required this.acceptedTitle,
    required this.heldTitle,
    required this.acceptedBoundary,
    required this.heldBoundary,
    required this.localVocabulary,
  });

  final String family;
  final String acceptedTitle;
  final String heldTitle;
  final String acceptedBoundary;
  final String heldBoundary;
  final String localVocabulary;

  factory _DoseExpressionCopy.forFamily(String family) => switch (family) {
    'zh' => const _DoseExpressionCopy(
      family: 'zh',
      acceptedTitle: '剂量格式已识别',
      heldTitle: '剂量数值已暂停进入算法',
      acceptedBoundary: '仅确认输入格式；不验证处方、剂量是否合适或实际服药。',
      heldBoundary: '原备注仍会保存，但其中的数字不会进入结果算法。',
      localVocabulary: '本地单位表 v',
    ),
    'fr' => const _DoseExpressionCopy(
      family: 'fr',
      acceptedTitle: 'Format de dose reconnu',
      heldTitle: 'Valeur de dose suspendue des algorithmes',
      acceptedBoundary:
          'Format uniquement; aucune validation de prescription ou de pertinence.',
      heldBoundary:
          'La note est conservée, mais aucun nombre ne passe aux algorithmes.',
      localVocabulary: 'vocabulaire local v',
    ),
    'ja' => const _DoseExpressionCopy(
      family: 'ja',
      acceptedTitle: '用量形式を認識しました',
      heldTitle: '用量数値のアルゴリズム利用を保留',
      acceptedBoundary: '入力形式のみを確認し、処方や用量の適切性は検証しません。',
      heldBoundary: 'メモは保存されますが、数値は結果アルゴリズムに渡されません。',
      localVocabulary: 'ローカル単位表 v',
    ),
    'ko' => const _DoseExpressionCopy(
      family: 'ko',
      acceptedTitle: '용량 형식 인식됨',
      heldTitle: '용량 수치의 알고리즘 사용 보류',
      acceptedBoundary: '입력 형식만 확인하며 처방이나 용량 적절성을 검증하지 않습니다.',
      heldBoundary: '메모는 저장되지만 숫자는 결과 알고리즘에 전달되지 않습니다.',
      localVocabulary: '로컬 단위표 v',
    ),
    'hi' => const _DoseExpressionCopy(
      family: 'hi',
      acceptedTitle: 'खुराक प्रारूप पहचाना गया',
      heldTitle: 'खुराक संख्या एल्गोरिदम से रोकी गई',
      acceptedBoundary:
          'केवल इनपुट प्रारूप; पर्चे या खुराक की उपयुक्तता की पुष्टि नहीं।',
      heldBoundary:
          'नोट सहेजा जाएगा, लेकिन संख्या परिणाम एल्गोरिदम में नहीं जाएगी।',
      localVocabulary: 'स्थानीय इकाई सूची v',
    ),
    'es' => const _DoseExpressionCopy(
      family: 'es',
      acceptedTitle: 'Formato de dosis reconocido',
      heldTitle: 'Valor de dosis retenido de los algoritmos',
      acceptedBoundary:
          'Solo formato; no valida la receta ni la idoneidad de la dosis.',
      heldBoundary:
          'La nota se guarda, pero ningún número pasa a los algoritmos.',
      localVocabulary: 'vocabulario local v',
    ),
    'vi' => const _DoseExpressionCopy(
      family: 'vi',
      acceptedTitle: 'Đã nhận dạng định dạng liều',
      heldTitle: 'Đã giữ số liều khỏi thuật toán',
      acceptedBoundary:
          'Chỉ xác nhận định dạng; không xác minh đơn thuốc hay liều phù hợp.',
      heldBoundary:
          'Ghi chú vẫn được lưu, nhưng số không đi vào thuật toán kết quả.',
      localVocabulary: 'bảng đơn vị cục bộ v',
    ),
    'th' => const _DoseExpressionCopy(
      family: 'th',
      acceptedTitle: 'รู้จักรูปแบบขนาดยาแล้ว',
      heldTitle: 'ระงับตัวเลขขนาดยาจากอัลกอริทึม',
      acceptedBoundary:
          'ตรวจเฉพาะรูปแบบ ไม่ยืนยันใบสั่งยาหรือความเหมาะสมของขนาดยา',
      heldBoundary: 'บันทึกข้อความไว้ แต่ตัวเลขจะไม่เข้าสู่อัลกอริทึมผลลัพธ์',
      localVocabulary: 'รายการหน่วยภายใน v',
    ),
    'id' => const _DoseExpressionCopy(
      family: 'id',
      acceptedTitle: 'Format dosis dikenali',
      heldTitle: 'Angka dosis ditahan dari algoritme',
      acceptedBoundary:
          'Hanya format; tidak memvalidasi resep atau kesesuaian dosis.',
      heldBoundary:
          'Catatan disimpan, tetapi angkanya tidak masuk ke algoritme hasil.',
      localVocabulary: 'daftar unit lokal v',
    ),
    'ru' => const _DoseExpressionCopy(
      family: 'ru',
      acceptedTitle: 'Формат дозы распознан',
      heldTitle: 'Число дозы не допущено к алгоритмам',
      acceptedBoundary:
          'Только формат; рецепт и уместность дозы не проверяются.',
      heldBoundary:
          'Заметка сохранится, но число не попадет в алгоритмы результата.',
      localVocabulary: 'локальный список единиц v',
    ),
    'pl' => const _DoseExpressionCopy(
      family: 'pl',
      acceptedTitle: 'Rozpoznano format dawki',
      heldTitle: 'Wartość dawki wstrzymana przed algorytmami',
      acceptedBoundary:
          'Tylko format; bez weryfikacji recepty ani odpowiedniości dawki.',
      heldBoundary:
          'Notatka zostanie zapisana, ale liczba nie trafi do algorytmów.',
      localVocabulary: 'lokalny słownik jednostek v',
    ),
    'ar' => const _DoseExpressionCopy(
      family: 'ar',
      acceptedTitle: 'تم التعرف على صيغة الجرعة',
      heldTitle: 'تم حجب رقم الجرعة عن الخوارزميات',
      acceptedBoundary: 'للصيغة فقط؛ لا يتحقق من الوصفة أو ملاءمة الجرعة.',
      heldBoundary: 'ستُحفظ الملاحظة، لكن الرقم لن يدخل خوارزميات النتائج.',
      localVocabulary: 'قاموس الوحدات المحلي v',
    ),
    _ => const _DoseExpressionCopy(
      family: 'en',
      acceptedTitle: 'Dose format recognized',
      heldTitle: 'Dose value held from algorithms',
      acceptedBoundary:
          'Input format only; this does not validate a prescription or dose appropriateness.',
      heldBoundary:
          'The note is still saved, but no number from it enters result algorithms.',
      localVocabulary: 'local unit vocabulary v',
    ),
  };

  String dimension(DoseExpressionDimension dimension) => switch (dimension) {
    DoseExpressionDimension.mass => family == 'zh' ? '质量' : 'mass',
    DoseExpressionDimension.volume => family == 'zh' ? '体积' : 'volume',
  };

  String reason(String? code) {
    final zh = <String, String>{
      'dose.empty': '尚未输入剂量。',
      'dose.too_long': '输入过长，无法安全解析。',
      'dose.control_character': '输入含不可见控制字符。',
      'dose.nonfinite_literal': '输入含非有限数值。',
      'dose.scientific_notation': '暂不接受科学计数法。',
      'dose.locale_decimal_ambiguous': '小数逗号可能因地区格式产生歧义。',
      'dose.non_exact_comparator': '暂不接受约数或比较符。',
      'dose.signed_value': '暂不接受带正负号的剂量。',
      'dose.range_not_supported': '剂量范围需要人工确认。',
      'dose.rate_not_supported': '给药速率不属于单次剂量格式。',
      'dose.combination_or_ratio': '组合强度、比例或浓度不能当作单次服药剂量。',
      'dose.word_number_ambiguous': '文字数字可能产生歧义。',
      'dose.numeric_token_missing': '没有找到明确的阿拉伯数字剂量。',
      'dose.multiple_numeric_tokens': '检测到多个数字，无法确定哪一个是单次剂量。',
      'dose.unit_unsupported': '单位不在当前已审核的本地单位表中。',
      'dose.unit_mapping_unrecognized': '单位映射未登记，不能用于计算。',
      'dose.unit_mapping_contract_mismatch': '单位映射与当前版本不一致。',
      'dose.unit_mapping_source_revision_mismatch': '单位映射来源版本已变化。',
      'dose.unit_mapping_not_exact': '单位映射不是精确等价关系。',
      'dose.unit_mapping_license_not_cleared': '单位映射的许可状态未获审核。',
      'dose.unit_mapping_jurisdiction_unknown': '单位映射的适用范围不明确。',
      'dose.unit_mapping_dimension_mismatch': '单位维度不一致，已阻止换算。',
      'dose.unit_mapping_conversion_invalid': '单位换算因子无效。',
      'dose.unit_mapping_review_date_invalid': '单位映射的复核日期无效。',
      'dose.unit_mapping_review_not_yet_effective': '单位映射尚未到复核生效日期。',
      'dose.unit_mapping_review_stale': '单位映射复核已过期。',
      'dose.unit_missing': '剂量缺少单位。',
      'dose.partial_match_blocked': '只识别到部分输入，已阻止局部匹配。',
      'dose.value_invalid': '剂量必须是大于零的有限数值。',
    };
    if (family == 'zh') return zh[code] ?? '此剂量表达式需要人工确认。';
    return switch (code) {
      'dose.too_long' => 'The entry is too long to parse safely.',
      'dose.control_character' =>
        'The entry contains an invisible control character.',
      'dose.nonfinite_literal' => 'A non-finite value is not a dose.',
      'dose.scientific_notation' => 'Scientific notation is not accepted.',
      'dose.locale_decimal_ambiguous' =>
        'The decimal comma is ambiguous across locale formats.',
      'dose.non_exact_comparator' =>
        'Approximate values and comparators are not accepted.',
      'dose.signed_value' => 'Signed dose values are not accepted.',
      'dose.range_not_supported' => 'Dose ranges require manual confirmation.',
      'dose.rate_not_supported' =>
        'An administration rate is not a single-dose expression.',
      'dose.combination_or_ratio' =>
        'A combination strength, ratio, or concentration is not a single administration dose.',
      'dose.word_number_ambiguous' => 'A written number is ambiguous.',
      'dose.numeric_token_missing' => 'No explicit numeric dose was found.',
      'dose.multiple_numeric_tokens' =>
        'More than one number was found, so the administration dose is unclear.',
      'dose.unit_unsupported' =>
        'The unit is outside the reviewed local unit vocabulary.',
      'dose.unit_mapping_unrecognized' =>
        'The unit mapping is not registered for calculation.',
      'dose.unit_mapping_contract_mismatch' =>
        'The unit mapping does not match the current contract.',
      'dose.unit_mapping_source_revision_mismatch' =>
        'The unit mapping source revision has changed.',
      'dose.unit_mapping_not_exact' =>
        'The unit mapping is not an exact equivalence.',
      'dose.unit_mapping_license_not_cleared' =>
        'The unit mapping license state has not been cleared.',
      'dose.unit_mapping_jurisdiction_unknown' =>
        'The unit mapping scope is not identified.',
      'dose.unit_mapping_dimension_mismatch' =>
        'The unit dimensions differ, so conversion was blocked.',
      'dose.unit_mapping_conversion_invalid' =>
        'The unit conversion factor is invalid.',
      'dose.unit_mapping_review_date_invalid' =>
        'The unit mapping review date is invalid.',
      'dose.unit_mapping_review_not_yet_effective' =>
        'The unit mapping has not reached its review date.',
      'dose.unit_mapping_review_stale' =>
        'The unit mapping review is out of date.',
      'dose.unit_missing' => 'The dose is missing a unit.',
      'dose.partial_match_blocked' =>
        'Only part of the entry matched, so partial parsing was blocked.',
      'dose.value_invalid' =>
        'The dose must be a finite value greater than zero.',
      _ => 'This dose expression needs manual confirmation.',
    };
  }
}
