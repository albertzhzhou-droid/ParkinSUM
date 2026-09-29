import 'package:flutter/material.dart';

import '../../core/i18n/app_i18n.dart';
import '../../domain/usecases/administration_dose_confirmation_coordinator.dart';
import '../../domain/usecases/dosage_note_parser.dart';

class AdministrationDoseConfirmationPanel extends StatelessWidget {
  const AdministrationDoseConfirmationPanel({
    super.key,
    required this.rawText,
    required this.confirmationRequested,
    required this.onChanged,
    this.currentEvaluation,
  });

  final String rawText;
  final bool confirmationRequested;
  final ValueChanged<bool> onChanged;
  final AdministrationDoseEvaluation? currentEvaluation;

  @override
  Widget build(BuildContext context) {
    final parserResult = DosageNoteParser().inspect(rawText);
    final enabled = parserResult.accepted;
    final i18n = AppI18n.fromLocaleTag(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final copy = _ConfirmationCopy.forFamily(i18n.languageFamily);
    final evaluation = currentEvaluation;
    final color = confirmationRequested && enabled
        ? const Color(0xff287d6b)
        : const Color(0xff6b7280);
    return Semantics(
      key: const Key('dose-confirmation-panel'),
      container: true,
      label: confirmationRequested && enabled
          ? copy.requestedStatus
          : copy.unconfirmedStatus,
      child: Card(
        color: color.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color.withValues(alpha: 0.3)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CheckboxListTile(
                key: const Key('dose-confirmation-checkbox'),
                contentPadding: EdgeInsets.zero,
                value: confirmationRequested && enabled,
                onChanged: enabled
                    ? (value) => onChanged(value ?? false)
                    : null,
                title: Text(copy.confirmAction),
                subtitle: Text(enabled ? copy.confirmHelp : copy.heldHelp),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (evaluation != null) ...[
                const Divider(height: 12),
                Row(
                  children: [
                    Icon(
                      evaluation.confirmed
                          ? Icons.verified_user_outlined
                          : Icons.rule_folder_outlined,
                      size: 18,
                      color: evaluation.confirmed
                          ? const Color(0xff287d6b)
                          : const Color(0xff9a6700),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        evaluation.confirmed
                            ? copy.existingConfirmed
                            : copy.existingNeedsReview,
                        key: const Key('dose-confirmation-current-status'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 5),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  copy.boundary,
                  key: const Key('dose-confirmation-boundary'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdministrationDoseConfirmationBadge extends StatelessWidget {
  const AdministrationDoseConfirmationBadge({
    super.key,
    required this.evaluation,
  });

  final AdministrationDoseEvaluation evaluation;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.fromLocaleTag(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final copy = _ConfirmationCopy.forFamily(i18n.languageFamily);
    final confirmed = evaluation.confirmed;
    final color = confirmed ? const Color(0xff287d6b) : const Color(0xff9a6700);
    return Semantics(
      label: confirmed ? copy.existingConfirmed : copy.existingNeedsReview,
      child: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              confirmed
                  ? Icons.verified_user_outlined
                  : Icons.pause_circle_outline,
              size: 16,
              color: color,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                confirmed ? copy.existingConfirmed : copy.existingNeedsReview,
                key: Key(
                  confirmed
                      ? 'dose-confirmation-badge-confirmed'
                      : 'dose-confirmation-badge-review',
                ),
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _ConfirmationCopy {
  const _ConfirmationCopy({
    required this.confirmAction,
    required this.confirmHelp,
    required this.heldHelp,
    required this.requestedStatus,
    required this.unconfirmedStatus,
    required this.existingConfirmed,
    required this.existingNeedsReview,
    required this.boundary,
  });

  final String confirmAction;
  final String confirmHelp;
  final String heldHelp;
  final String requestedStatus;
  final String unconfirmedStatus;
  final String existingConfirmed;
  final String existingNeedsReview;
  final String boundary;

  factory _ConfirmationCopy.forFamily(String family) => switch (family) {
    'zh' => const _ConfirmationCopy(
      confirmAction: '我确认这是我想记录的单次用药剂量',
      confirmHelp: '保存时会把药物、剂量、时间、产品和当前记录版本绑定为本地收据。',
      heldHelp: '先输入一个可明确识别的单次剂量，才能确认。',
      requestedStatus: '剂量确认已选择',
      unconfirmedStatus: '剂量尚未确认',
      existingConfirmed: '剂量收据有效',
      existingNeedsReview: '剂量未确认或收据需要重审',
      boundary: '仅记录你的确认；不核验处方、剂量是否合适，也不证明实际服药。',
    ),
    'fr' => const _ConfirmationCopy(
      confirmAction: 'Je confirme la dose unique que je veux consigner',
      confirmHelp:
          'Lie localement médicament, dose, heure, produit et révision.',
      heldHelp: 'Saisissez une dose unique reconnue avant de confirmer.',
      requestedStatus: 'Confirmation de dose sélectionnée',
      unconfirmedStatus: 'Dose non confirmée',
      existingConfirmed: 'Reçu de dose valide',
      existingNeedsReview: 'Dose non confirmée ou reçu à revoir',
      boundary: 'Ne valide ni ordonnance, ni pertinence, ni prise réelle.',
    ),
    'ja' => const _ConfirmationCopy(
      confirmAction: '記録する1回分の用量であることを確認します',
      confirmHelp: '薬、用量、時刻、製品、記録版をローカル受領証に結びます。',
      heldHelp: '確認前に認識可能な1回分の用量を入力してください。',
      requestedStatus: '用量確認を選択済み',
      unconfirmedStatus: '用量未確認',
      existingConfirmed: '用量受領証は有効です',
      existingNeedsReview: '用量未確認または再確認が必要です',
      boundary: '処方、適切性、実際の服用を証明しません。',
    ),
    'ko' => const _ConfirmationCopy(
      confirmAction: '기록할 1회 복용량임을 확인합니다',
      confirmHelp: '약, 용량, 시간, 제품, 기록 버전을 로컬 영수증에 묶습니다.',
      heldHelp: '확인 전에 인식 가능한 1회 용량을 입력하세요.',
      requestedStatus: '용량 확인 선택됨',
      unconfirmedStatus: '용량 미확인',
      existingConfirmed: '용량 영수증 유효',
      existingNeedsReview: '용량 미확인 또는 재검토 필요',
      boundary: '처방, 적절성 또는 실제 복용을 증명하지 않습니다.',
    ),
    'hi' => const _ConfirmationCopy(
      confirmAction: 'मैं दर्ज की जाने वाली एकल खुराक की पुष्टि करता/करती हूँ',
      confirmHelp:
          'दवा, खुराक, समय, उत्पाद और रिकॉर्ड संस्करण को स्थानीय रसीद से जोड़ता है।',
      heldHelp: 'पुष्टि से पहले एक स्पष्ट एकल खुराक दर्ज करें।',
      requestedStatus: 'खुराक पुष्टि चुनी गई',
      unconfirmedStatus: 'खुराक अपुष्ट',
      existingConfirmed: 'खुराक रसीद मान्य',
      existingNeedsReview: 'खुराक अपुष्ट या पुनः समीक्षा आवश्यक',
      boundary: 'यह पर्चे, उपयुक्तता या वास्तविक सेवन का प्रमाण नहीं है।',
    ),
    'es' => const _ConfirmationCopy(
      confirmAction: 'Confirmo la dosis única que quiero registrar',
      confirmHelp:
          'Vincula medicamento, dosis, hora, producto y revisión local.',
      heldHelp: 'Introduce una dosis única reconocible antes de confirmar.',
      requestedStatus: 'Confirmación de dosis seleccionada',
      unconfirmedStatus: 'Dosis sin confirmar',
      existingConfirmed: 'Recibo de dosis válido',
      existingNeedsReview: 'Dosis sin confirmar o recibo por revisar',
      boundary: 'No valida receta, idoneidad ni administración real.',
    ),
    'vi' => const _ConfirmationCopy(
      confirmAction: 'Tôi xác nhận liều đơn muốn ghi lại',
      confirmHelp:
          'Liên kết thuốc, liều, thời gian, sản phẩm và phiên bản bản ghi cục bộ.',
      heldHelp: 'Nhập một liều đơn nhận dạng được trước khi xác nhận.',
      requestedStatus: 'Đã chọn xác nhận liều',
      unconfirmedStatus: 'Liều chưa xác nhận',
      existingConfirmed: 'Biên nhận liều hợp lệ',
      existingNeedsReview: 'Liều chưa xác nhận hoặc cần xem lại',
      boundary: 'Không xác minh đơn thuốc, độ phù hợp hay việc đã dùng thuốc.',
    ),
    'th' => const _ConfirmationCopy(
      confirmAction: 'ฉันยืนยันขนาดยาครั้งเดียวที่ต้องการบันทึก',
      confirmHelp:
          'ผูกยา ขนาด เวลา ผลิตภัณฑ์ และรุ่นระเบียนไว้ในใบรับรองภายในเครื่อง',
      heldHelp: 'กรอกขนาดยาครั้งเดียวที่ระบุได้ก่อนยืนยัน',
      requestedStatus: 'เลือกยืนยันขนาดยาแล้ว',
      unconfirmedStatus: 'ยังไม่ยืนยันขนาดยา',
      existingConfirmed: 'ใบรับรองขนาดยาถูกต้อง',
      existingNeedsReview: 'ยังไม่ยืนยันหรือจำเป็นต้องทบทวน',
      boundary: 'ไม่ยืนยันใบสั่งยา ความเหมาะสม หรือการรับประทานจริง',
    ),
    'id' => const _ConfirmationCopy(
      confirmAction: 'Saya mengonfirmasi dosis tunggal yang ingin dicatat',
      confirmHelp:
          'Mengikat obat, dosis, waktu, produk, dan revisi secara lokal.',
      heldHelp: 'Masukkan satu dosis yang dapat dikenali sebelum konfirmasi.',
      requestedStatus: 'Konfirmasi dosis dipilih',
      unconfirmedStatus: 'Dosis belum dikonfirmasi',
      existingConfirmed: 'Tanda terima dosis valid',
      existingNeedsReview: 'Dosis belum dikonfirmasi atau perlu ditinjau',
      boundary: 'Bukan validasi resep, kelayakan, atau bukti konsumsi.',
    ),
    'ru' => const _ConfirmationCopy(
      confirmAction: 'Подтверждаю разовую дозу, которую хочу записать',
      confirmHelp:
          'Локально связывает препарат, дозу, время, продукт и версию записи.',
      heldHelp: 'Сначала введите однозначную разовую дозу.',
      requestedStatus: 'Подтверждение дозы выбрано',
      unconfirmedStatus: 'Доза не подтверждена',
      existingConfirmed: 'Квитанция дозы действительна',
      existingNeedsReview: 'Доза не подтверждена или нужна проверка',
      boundary: 'Не подтверждает рецепт, уместность или фактический прием.',
    ),
    'pl' => const _ConfirmationCopy(
      confirmAction: 'Potwierdzam pojedynczą dawkę, którą chcę zapisać',
      confirmHelp: 'Lokalnie wiąże lek, dawkę, czas, produkt i wersję rekordu.',
      heldHelp: 'Najpierw wpisz jednoznaczną pojedynczą dawkę.',
      requestedStatus: 'Wybrano potwierdzenie dawki',
      unconfirmedStatus: 'Dawka niepotwierdzona',
      existingConfirmed: 'Potwierdzenie dawki jest ważne',
      existingNeedsReview: 'Dawka niepotwierdzona lub wymaga przeglądu',
      boundary:
          'Nie potwierdza recepty, stosowności ani faktycznego przyjęcia.',
    ),
    'ar' => const _ConfirmationCopy(
      confirmAction: 'أؤكد الجرعة المفردة التي أريد تسجيلها',
      confirmHelp: 'يربط الدواء والجرعة والوقت والمنتج وإصدار السجل محلياً.',
      heldHelp: 'أدخل جرعة مفردة واضحة قبل التأكيد.',
      requestedStatus: 'تم اختيار تأكيد الجرعة',
      unconfirmedStatus: 'الجرعة غير مؤكدة',
      existingConfirmed: 'إيصال الجرعة صالح',
      existingNeedsReview: 'الجرعة غير مؤكدة أو تحتاج إلى مراجعة',
      boundary: 'لا يثبت الوصفة أو الملاءمة أو تناول الجرعة فعلياً.',
    ),
    _ => const _ConfirmationCopy(
      confirmAction: 'I confirm this is the single dose I want to record',
      confirmHelp:
          'Binds medication, dose, time, product, and record revision in a local receipt.',
      heldHelp:
          'Enter one clearly recognized administration dose before confirming.',
      requestedStatus: 'Dose confirmation selected',
      unconfirmedStatus: 'Dose not confirmed',
      existingConfirmed: 'Dose receipt valid',
      existingNeedsReview: 'Dose unconfirmed or receipt needs review',
      boundary:
          'Records your assertion only; it does not validate a prescription, appropriateness, or actual administration.',
    ),
  };
}
