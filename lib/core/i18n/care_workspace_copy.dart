import '../../domain/entities/decision_support_followup.dart';

/// Reviewed UI copy for the local follow-up workflow. User-entered notes and
/// rule explanations are deliberately not rewritten here.
const Map<String, Map<String, String>> kCareWorkspaceFollowupCopy = {
  'en': {
    'status.unread': 'Unread',
    'status.read': 'Read',
    'status.needsReview': 'To review',
    'status.snoozed': 'Snoozed',
    'status.dismissed': 'Dismissed',
    'status.resolved': 'Resolved',
    'status.notApplicable': 'Not applicable',
    'status.declined': 'Declined',
    'feedback.boundary':
        'Recording feedback is a workflow choice only. It does not confirm clinical correctness or applicability, that a recommendation was accepted or followed, or that medication changed.',
    'reason.title': 'Add a reason for this response',
    'reason.hint':
        'A brief reason is required and is saved as your note; it is not independently verified.',
    'action.cancel': 'Cancel',
    'action.saveReason': 'Save reason',
    'reason.categoryPrompt':
        'Choose the closest description. This is your report, not a verification.',
    'reason.category.informationMayBeIncorrect': 'Information may be incorrect',
    'reason.category.contextMismatch': 'Does not fit my situation',
    'reason.category.explanationUnclear': 'Explanation is unclear',
    'reason.category.duplicateOrAlreadyAddressed':
        'Duplicate or already addressed',
    'reason.category.other': 'Other',
    'history.reasonCategoryUnclassified':
        'Reason category not recorded for this earlier response',
    'view.open': 'Open',
    'view.needsReview': 'Unread / review',
    'view.snoozed': 'Snoozed',
    'view.all': 'All prompts',
    'empty.open':
        'No open prompts. Save a meal check to see sourced prompts here.',
    'empty.needsReview': 'No unread or review-needed prompts in these records.',
    'empty.snoozed': 'No snoozed prompts in these records.',
    'empty.all':
        'No saved prompts. Save a meal check to see sourced prompts here.',
    'section.title': 'Prompt feedback',
    'section.boundary':
        'Filters use your recorded workflow status and creation time; they do not show clinical priority or urgency.',
    'history.title': 'Sources & feedback history',
    'history.recordedByYou': 'Recorded by you',
    'source.boundary':
        'Local registry metadata only. Nothing is fetched, and this does not verify rule support or personal applicability.',
    'action.reopen': 'Reopen for review',
    'action.read': 'Mark as read',
    'action.snooze': 'Snooze one day',
    'save.success': 'Saved on this device.',
    'save.failure': 'Could not save. The record was not updated. Please retry.',
  },
  'zh': {
    'status.unread': '未读',
    'status.read': '已读',
    'status.needsReview': '待核实',
    'status.snoozed': '已延后',
    'status.dismissed': '已忽略',
    'status.resolved': '已处理',
    'status.notApplicable': '标记为不适用',
    'status.declined': '选择不采纳',
    'feedback.boundary': '此处反馈仅记录工作流选择；不证明内容在临床上正确或适用于本人，也不表示已接受或遵循建议，或已更改药物。',
    'reason.title': '为此反馈填写原因',
    'reason.hint': '请填写简短原因。原因会作为本人备注保存，未经独立核实。',
    'action.cancel': '取消',
    'action.saveReason': '保存原因',
    'reason.categoryPrompt': '请选择最接近的描述。这是本人反馈，不代表核实结论。',
    'reason.category.informationMayBeIncorrect': '信息可能有误',
    'reason.category.contextMismatch': '与我的情况不符',
    'reason.category.explanationUnclear': '解释不清楚',
    'reason.category.duplicateOrAlreadyAddressed': '重复或已处理',
    'reason.category.other': '其他',
    'history.reasonCategoryUnclassified': '此条较早反馈未记录原因类别',
    'view.open': '待处理',
    'view.needsReview': '未读 / 待核实',
    'view.snoozed': '已延后',
    'view.all': '全部提示',
    'empty.open': '当前没有待处理提示。保存餐食检查后，具有来源的提示会显示在这里。',
    'empty.needsReview': '当前记录中没有未读或待核实提示。',
    'empty.snoozed': '当前记录中没有已延后的提示。',
    'empty.all': '尚未保存提示。保存餐食检查后，具有来源的提示会显示在这里。',
    'section.title': '提示反馈',
    'section.boundary': '筛选依据是本人记录的工作流状态和创建时间；不表示临床优先级或紧急程度。',
    'history.title': '来源与反馈历史',
    'history.recordedByYou': '本人记录',
    'source.boundary': '仅显示本机目录元数据；不会联网获取，也不证明规则支持或适用于个人。',
    'action.reopen': '重新标为待核实',
    'action.read': '标为已读',
    'action.snooze': '延后一天',
    'save.success': '已保存到此设备。',
    'save.failure': '保存失败，记录未更新。请重试。',
  },
  'fr': {
    'status.unread': 'Non lu',
    'status.read': 'Lu',
    'status.needsReview': 'À vérifier',
    'status.snoozed': 'Reporté',
    'status.dismissed': 'Ignoré',
    'status.resolved': 'Résolu',
    'status.notApplicable': 'Non applicable',
    'status.declined': 'Refusé',
    'feedback.boundary':
        'Ce retour décrit uniquement un choix de suivi. Il ne confirme ni la justesse clinique ou l’applicabilité, ni l’acceptation ou le suivi d’une recommandation, ni une modification de traitement.',
    'reason.title': 'Ajouter le motif de cette réponse',
    'reason.hint':
        'Un bref motif est requis et sera enregistré comme votre note ; il ne sera pas vérifié indépendamment.',
    'action.cancel': 'Annuler',
    'action.saveReason': 'Enregistrer le motif',
    'reason.categoryPrompt':
        'Choisissez la description la plus proche. Il s’agit de votre retour, pas d’une vérification.',
    'reason.category.informationMayBeIncorrect':
        'Les informations peuvent être inexactes',
    'reason.category.contextMismatch': 'Ne correspond pas à ma situation',
    'reason.category.explanationUnclear': 'Explication peu claire',
    'reason.category.duplicateOrAlreadyAddressed': 'Doublon ou déjà traité',
    'reason.category.other': 'Autre',
    'history.reasonCategoryUnclassified':
        'La catégorie de cette ancienne réponse n’a pas été enregistrée',
    'view.open': 'À traiter',
    'view.needsReview': 'Non lu / à vérifier',
    'view.snoozed': 'Reporté',
    'view.all': 'Tous les rappels',
    'empty.open':
        'Aucun rappel ouvert. Enregistrez une vérification de repas pour afficher ici les rappels avec leurs sources.',
    'empty.needsReview': 'Aucun rappel non lu ou à vérifier dans ces données.',
    'empty.snoozed': 'Aucun rappel reporté dans ces données.',
    'empty.all':
        'Aucun rappel enregistré. Enregistrez une vérification de repas pour afficher ici les rappels avec leurs sources.',
    'section.title': 'Suivi des rappels',
    'section.boundary':
        'Les filtres utilisent le statut de suivi que vous avez noté et la date de création ; ils n’indiquent ni priorité clinique ni urgence.',
    'history.title': 'Sources et historique du suivi',
    'history.recordedByYou': 'Noté par vous',
    'source.boundary':
        'Métadonnées du registre local uniquement. Aucune donnée n’est récupérée ; cela ne vérifie ni la prise en charge par une règle ni son applicabilité personnelle.',
    'action.reopen': 'Rouvrir pour vérification',
    'action.read': 'Marquer comme lu',
    'action.snooze': 'Reporter d’un jour',
    'save.success': 'Enregistré sur cet appareil.',
    'save.failure':
        'Échec de l’enregistrement. La fiche n’a pas été modifiée. Réessayez.',
  },
  'ja': {
    'status.unread': '未読',
    'status.read': '既読',
    'status.needsReview': '要確認',
    'status.snoozed': '延期',
    'status.dismissed': '非表示',
    'status.resolved': '対応済み',
    'status.notApplicable': '該当しないと記録',
    'status.declined': '採用しないと記録',
    'feedback.boundary':
        'ここでのフィードバックは作業上の選択を記録するだけです。臨床的な正しさや個人への適用性、推奨の受け入れや実行、薬の変更を確認するものではありません。',
    'reason.title': 'この回答の理由を記録',
    'reason.hint': '短い理由を入力してください。本人のメモとして保存され、独立した確認は行われません。',
    'action.cancel': 'キャンセル',
    'action.saveReason': '理由を保存',
    'reason.categoryPrompt': '最も近い内容を選んでください。本人の申告であり、事実確認ではありません。',
    'reason.category.informationMayBeIncorrect': '記録情報に誤りがある可能性',
    'reason.category.contextMismatch': '自分の状況に合わない',
    'reason.category.explanationUnclear': '説明が分かりにくい',
    'reason.category.duplicateOrAlreadyAddressed': '重複または対応済み',
    'reason.category.other': 'その他',
    'history.reasonCategoryUnclassified': 'この以前の回答では理由の分類は記録されていません',
    'view.open': '未対応',
    'view.needsReview': '未読 / 要確認',
    'view.snoozed': '延期',
    'view.all': 'すべての提示',
    'empty.open': '未対応の提示はありません。食事チェックを保存すると、出典付きの提示がここに表示されます。',
    'empty.needsReview': 'この記録に未読または確認が必要な提示はありません。',
    'empty.snoozed': 'この記録に延期された提示はありません。',
    'empty.all': '保存された提示はありません。食事チェックを保存すると、出典付きの提示がここに表示されます。',
    'section.title': '提示へのフィードバック',
    'section.boundary': 'フィルターは本人が記録した作業状態と作成日時に基づき、臨床上の優先度や緊急度を示すものではありません。',
    'history.title': '出典とフィードバック履歴',
    'history.recordedByYou': '本人の記録',
    'source.boundary':
        'この端末のレジストリメタデータのみを表示します。外部から取得せず、規則による裏付けや個人への適用性を確認するものではありません。',
    'action.reopen': '確認対象に戻す',
    'action.read': '既読にする',
    'action.snooze': '1日延期',
    'save.success': 'この端末に保存しました。',
    'save.failure': '保存できませんでした。記録は更新されていません。もう一度お試しください。',
  },
  'ko': {
    'status.unread': '읽지 않음',
    'status.read': '읽음',
    'status.needsReview': '검토 필요',
    'status.snoozed': '미룸',
    'status.dismissed': '숨김',
    'status.resolved': '처리됨',
    'status.notApplicable': '해당 없음으로 기록',
    'status.declined': '따르지 않기로 기록',
    'feedback.boundary':
        '이 피드백은 작업 흐름에서 선택한 내용만 기록합니다. 임상적 정확성이나 개인 적용 가능성, 권고 수락 또는 이행, 약물 변경을 확인하지 않습니다.',
    'reason.title': '이 응답의 이유 기록',
    'reason.hint': '간단한 이유를 입력하세요. 본인의 메모로 저장되며 독립적으로 검증되지 않습니다.',
    'action.cancel': '취소',
    'action.saveReason': '이유 저장',
    'reason.categoryPrompt': '가장 가까운 설명을 선택하세요. 본인의 의견이며 사실 확인은 아닙니다.',
    'reason.category.informationMayBeIncorrect': '기록 정보가 잘못되었을 수 있음',
    'reason.category.contextMismatch': '내 상황에 맞지 않음',
    'reason.category.explanationUnclear': '설명이 명확하지 않음',
    'reason.category.duplicateOrAlreadyAddressed': '중복되었거나 이미 처리됨',
    'reason.category.other': '기타',
    'history.reasonCategoryUnclassified': '이전 응답에는 이유 범주가 기록되지 않았습니다',
    'view.open': '미처리',
    'view.needsReview': '읽지 않음 / 검토 필요',
    'view.snoozed': '미룸',
    'view.all': '모든 안내',
    'empty.open': '열린 안내가 없습니다. 식사 확인을 저장하면 출처가 표시된 안내가 여기에 나타납니다.',
    'empty.needsReview': '현재 기록에 읽지 않았거나 검토할 안내가 없습니다.',
    'empty.snoozed': '현재 기록에 미뤄 둔 안내가 없습니다.',
    'empty.all': '저장된 안내가 없습니다. 식사 확인을 저장하면 출처가 표시된 안내가 여기에 나타납니다.',
    'section.title': '안내 피드백',
    'section.boundary':
        '필터는 직접 기록한 작업 상태와 생성 시간을 사용하며 임상적 우선순위나 긴급성을 나타내지 않습니다.',
    'history.title': '출처 및 피드백 기록',
    'history.recordedByYou': '직접 기록함',
    'source.boundary':
        '이 기기의 레지스트리 메타데이터만 표시합니다. 외부에서 가져오지 않으며 규칙의 근거나 개인 적용 가능성을 확인하지 않습니다.',
    'action.reopen': '검토 대상으로 다시 열기',
    'action.read': '읽음으로 표시',
    'action.snooze': '하루 미루기',
    'save.success': '이 기기에 저장했습니다.',
    'save.failure': '저장하지 못했습니다. 기록은 변경되지 않았습니다. 다시 시도하세요.',
  },
  'hi': {
    'status.unread': 'अपठित',
    'status.read': 'पढ़ा गया',
    'status.needsReview': 'समीक्षा करें',
    'status.snoozed': 'स्थगित',
    'status.dismissed': 'छिपाया गया',
    'status.resolved': 'पूरा किया गया',
    'status.notApplicable': 'लागू नहीं के रूप में दर्ज',
    'status.declined': 'अस्वीकार के रूप में दर्ज',
    'feedback.boundary':
        'यह प्रतिक्रिया केवल कार्य-प्रवाह में चुने गए विकल्प को दर्ज करती है। यह चिकित्सकीय शुद्धता या व्यक्तिगत उपयुक्तता, सुझाव स्वीकार करने या अपनाने, अथवा दवा में बदलाव की पुष्टि नहीं करती।',
    'reason.title': 'इस प्रतिक्रिया का कारण लिखें',
    'reason.hint':
        'संक्षिप्त कारण आवश्यक है। यह आपके नोट के रूप में सहेजा जाएगा और स्वतंत्र रूप से सत्यापित नहीं होगा।',
    'action.cancel': 'रद्द करें',
    'action.saveReason': 'कारण सहेजें',
    'reason.categoryPrompt':
        'सबसे मिलते-जुलते विवरण को चुनें। यह आपकी प्रतिक्रिया है, सत्यापन नहीं।',
    'reason.category.informationMayBeIncorrect': 'दर्ज जानकारी गलत हो सकती है',
    'reason.category.contextMismatch': 'मेरी स्थिति से मेल नहीं खाता',
    'reason.category.explanationUnclear': 'व्याख्या स्पष्ट नहीं है',
    'reason.category.duplicateOrAlreadyAddressed':
        'दोहराव या पहले ही चर्चा हुई',
    'reason.category.other': 'अन्य',
    'history.reasonCategoryUnclassified':
        'इस पुराने उत्तर के लिए कारण श्रेणी दर्ज नहीं की गई',
    'view.open': 'खुले',
    'view.needsReview': 'अपठित / समीक्षा',
    'view.snoozed': 'स्थगित',
    'view.all': 'सभी संकेत',
    'empty.open':
        'कोई खुला संकेत नहीं है। भोजन जाँच सहेजने पर स्रोत सहित संकेत यहाँ दिखेंगे।',
    'empty.needsReview':
        'इन रिकॉर्ड में कोई अपठित या समीक्षा योग्य संकेत नहीं है।',
    'empty.snoozed': 'इन रिकॉर्ड में कोई स्थगित संकेत नहीं है।',
    'empty.all':
        'कोई संकेत सहेजा नहीं गया है। भोजन जाँच सहेजने पर स्रोत सहित संकेत यहाँ दिखेंगे।',
    'section.title': 'संकेत प्रतिक्रिया',
    'section.boundary':
        'फ़िल्टर आपके दर्ज किए कार्य-प्रवाह की स्थिति और बनाए जाने के समय पर आधारित हैं; ये चिकित्सकीय प्राथमिकता या तात्कालिकता नहीं दर्शाते।',
    'history.title': 'स्रोत और प्रतिक्रिया इतिहास',
    'history.recordedByYou': 'आपके द्वारा दर्ज',
    'source.boundary':
        'केवल इस डिवाइस की रजिस्ट्री का मेटाडेटा। कुछ भी ऑनलाइन प्राप्त नहीं किया जाता, और इससे नियम का समर्थन या व्यक्तिगत लागू होना सत्यापित नहीं होता।',
    'action.reopen': 'समीक्षा के लिए फिर खोलें',
    'action.read': 'पढ़ा हुआ चिह्नित करें',
    'action.snooze': 'एक दिन के लिए स्थगित करें',
    'save.success': 'इस डिवाइस पर सहेजा गया।',
    'save.failure':
        'सहेजा नहीं जा सका। रिकॉर्ड अपडेट नहीं हुआ। कृपया फिर प्रयास करें।',
  },
  'es': {
    'status.unread': 'Sin leer',
    'status.read': 'Leído',
    'status.needsReview': 'Por revisar',
    'status.snoozed': 'Pospuesto',
    'status.dismissed': 'Descartado',
    'status.resolved': 'Resuelto',
    'status.notApplicable': 'Marcado como no aplicable',
    'status.declined': 'Marcado como rechazado',
    'feedback.boundary':
        'Esta respuesta solo registra una elección del flujo de trabajo. No confirma la exactitud clínica ni la aplicabilidad personal, la aceptación o el seguimiento de una recomendación, ni un cambio de medicación.',
    'reason.title': 'Añade un motivo para esta respuesta',
    'reason.hint':
        'Se requiere un motivo breve y se guarda como nota tuya; no se verifica de forma independiente.',
    'action.cancel': 'Cancelar',
    'action.saveReason': 'Guardar motivo',
    'reason.categoryPrompt':
        'Elige la descripción más cercana. Es tu comentario, no una verificación.',
    'reason.category.informationMayBeIncorrect':
        'La información podría ser incorrecta',
    'reason.category.contextMismatch': 'No encaja con mi situación',
    'reason.category.explanationUnclear': 'La explicación no está clara',
    'reason.category.duplicateOrAlreadyAddressed': 'Duplicado o ya tratado',
    'reason.category.other': 'Otro',
    'history.reasonCategoryUnclassified':
        'No se registró la categoría del motivo de esta respuesta anterior',
    'view.open': 'Pendientes',
    'view.needsReview': 'Sin leer / por revisar',
    'view.snoozed': 'Pospuestos',
    'view.all': 'Todos los avisos',
    'empty.open':
        'No hay avisos pendientes. Guarda una revisión de comida para ver aquí avisos con sus fuentes.',
    'empty.needsReview':
        'No hay avisos sin leer o pendientes de revisión en estos registros.',
    'empty.snoozed': 'No hay avisos pospuestos en estos registros.',
    'empty.all':
        'No hay avisos guardados. Guarda una revisión de comida para ver aquí avisos con sus fuentes.',
    'section.title': 'Comentarios sobre los avisos',
    'section.boundary':
        'Los filtros usan el estado de flujo de trabajo que registraste y la fecha de creación; no indican prioridad clínica ni urgencia.',
    'history.title': 'Fuentes e historial de comentarios',
    'history.recordedByYou': 'Registrado por ti',
    'source.boundary':
        'Solo metadatos del registro local. No se consulta nada en línea y esto no verifica el respaldo de una regla ni su aplicabilidad personal.',
    'action.reopen': 'Reabrir para revisar',
    'action.read': 'Marcar como leído',
    'action.snooze': 'Posponer un día',
    'save.success': 'Guardado en este dispositivo.',
    'save.failure':
        'No se pudo guardar. El registro no se actualizó. Inténtalo de nuevo.',
  },
  'vi': {
    'status.unread': 'Chưa đọc',
    'status.read': 'Đã đọc',
    'status.needsReview': 'Cần xem lại',
    'status.snoozed': 'Đã hoãn',
    'status.dismissed': 'Đã ẩn',
    'status.resolved': 'Đã xử lý',
    'status.notApplicable': 'Ghi nhận là không phù hợp',
    'status.declined': 'Ghi nhận là từ chối',
    'feedback.boundary':
        'Phản hồi này chỉ ghi lại lựa chọn trong quy trình. Nó không xác nhận tính đúng đắn lâm sàng hay mức độ phù hợp cá nhân, việc chấp nhận hoặc làm theo khuyến nghị, hoặc thay đổi thuốc.',
    'reason.title': 'Ghi lý do cho phản hồi này',
    'reason.hint':
        'Cần có lý do ngắn. Lý do được lưu như ghi chú của bạn và không được xác minh độc lập.',
    'action.cancel': 'Hủy',
    'action.saveReason': 'Lưu lý do',
    'reason.categoryPrompt':
        'Chọn mô tả phù hợp nhất. Đây là ý kiến của bạn, không phải xác minh.',
    'reason.category.informationMayBeIncorrect':
        'Thông tin có thể không chính xác',
    'reason.category.contextMismatch': 'Không phù hợp với tình huống của tôi',
    'reason.category.explanationUnclear': 'Giải thích chưa rõ',
    'reason.category.duplicateOrAlreadyAddressed':
        'Trùng lặp hoặc đã được xử lý',
    'reason.category.other': 'Khác',
    'history.reasonCategoryUnclassified':
        'Phản hồi trước đây này chưa ghi nhận nhóm lý do',
    'view.open': 'Đang mở',
    'view.needsReview': 'Chưa đọc / cần xem lại',
    'view.snoozed': 'Đã hoãn',
    'view.all': 'Tất cả nhắc nhở',
    'empty.open':
        'Không có nhắc nhở đang mở. Hãy lưu lần kiểm tra bữa ăn để xem nhắc nhở kèm nguồn tại đây.',
    'empty.needsReview':
        'Không có nhắc nhở chưa đọc hoặc cần xem lại trong các bản ghi này.',
    'empty.snoozed': 'Không có nhắc nhở đã hoãn trong các bản ghi này.',
    'empty.all':
        'Chưa có nhắc nhở nào được lưu. Hãy lưu lần kiểm tra bữa ăn để xem nhắc nhở kèm nguồn tại đây.',
    'section.title': 'Phản hồi về nhắc nhở',
    'section.boundary':
        'Bộ lọc dựa trên trạng thái quy trình do bạn ghi lại và thời điểm tạo; chúng không thể hiện mức độ ưu tiên hoặc khẩn cấp lâm sàng.',
    'history.title': 'Nguồn và lịch sử phản hồi',
    'history.recordedByYou': 'Bạn đã ghi lại',
    'source.boundary':
        'Chỉ có siêu dữ liệu từ danh mục trên thiết bị. Không truy xuất dữ liệu bên ngoài; thông tin này không xác minh căn cứ của quy tắc hoặc mức độ phù hợp với cá nhân.',
    'action.reopen': 'Mở lại để xem xét',
    'action.read': 'Đánh dấu đã đọc',
    'action.snooze': 'Hoãn một ngày',
    'save.success': 'Đã lưu trên thiết bị này.',
    'save.failure':
        'Không thể lưu. Bản ghi chưa được cập nhật. Vui lòng thử lại.',
  },
  'th': {
    'status.unread': 'ยังไม่อ่าน',
    'status.read': 'อ่านแล้ว',
    'status.needsReview': 'รอตรวจสอบ',
    'status.snoozed': 'เลื่อนไว้',
    'status.dismissed': 'ซ่อนแล้ว',
    'status.resolved': 'จัดการแล้ว',
    'status.notApplicable': 'บันทึกว่าไม่เกี่ยวข้อง',
    'status.declined': 'บันทึกว่าปฏิเสธ',
    'feedback.boundary':
        'ความคิดเห็นนี้บันทึกเฉพาะตัวเลือกในขั้นตอนการทำงาน ไม่ได้ยืนยันความถูกต้องทางคลินิกหรือความเหมาะสมกับบุคคล การยอมรับหรือนำคำแนะนำไปใช้ หรือการเปลี่ยนยา',
    'reason.title': 'ระบุเหตุผลของคำตอบนี้',
    'reason.hint':
        'ต้องระบุเหตุผลสั้น ๆ และจะบันทึกเป็นหมายเหตุของคุณโดยไม่มีการตรวจสอบอิสระ',
    'action.cancel': 'ยกเลิก',
    'action.saveReason': 'บันทึกเหตุผล',
    'reason.categoryPrompt':
        'เลือกคำอธิบายที่ใกล้เคียงที่สุด นี่เป็นความคิดเห็นของคุณ ไม่ใช่การตรวจสอบข้อเท็จจริง',
    'reason.category.informationMayBeIncorrect': 'ข้อมูลอาจไม่ถูกต้อง',
    'reason.category.contextMismatch': 'ไม่ตรงกับสถานการณ์ของฉัน',
    'reason.category.explanationUnclear': 'คำอธิบายไม่ชัดเจน',
    'reason.category.duplicateOrAlreadyAddressed': 'ซ้ำหรือจัดการแล้ว',
    'reason.category.other': 'อื่น ๆ',
    'history.reasonCategoryUnclassified':
        'คำตอบก่อนหน้านี้ไม่ได้บันทึกหมวดหมู่เหตุผล',
    'view.open': 'ที่ยังเปิดอยู่',
    'view.needsReview': 'ยังไม่อ่าน / รอตรวจสอบ',
    'view.snoozed': 'เลื่อนไว้',
    'view.all': 'คำแนะนำทั้งหมด',
    'empty.open':
        'ไม่มีคำแนะนำที่ยังเปิดอยู่ บันทึกการตรวจสอบมื้ออาหารเพื่อดูคำแนะนำพร้อมแหล่งที่มาที่นี่',
    'empty.needsReview':
        'ไม่มีคำแนะนำที่ยังไม่อ่านหรือรอตรวจสอบในบันทึกเหล่านี้',
    'empty.snoozed': 'ไม่มีคำแนะนำที่เลื่อนไว้ในบันทึกเหล่านี้',
    'empty.all':
        'ยังไม่มีคำแนะนำที่บันทึกไว้ บันทึกการตรวจสอบมื้ออาหารเพื่อดูคำแนะนำพร้อมแหล่งที่มาที่นี่',
    'section.title': 'ความคิดเห็นต่อคำแนะนำ',
    'section.boundary':
        'ตัวกรองใช้สถานะการทำงานและเวลาที่สร้างซึ่งคุณบันทึกไว้ ไม่ได้แสดงลำดับความสำคัญหรือความเร่งด่วนทางคลินิก',
    'history.title': 'แหล่งที่มาและประวัติความคิดเห็น',
    'history.recordedByYou': 'บันทึกโดยคุณ',
    'source.boundary':
        'แสดงเฉพาะข้อมูลเมตาในทะเบียนบนอุปกรณ์ ไม่มีการดึงข้อมูลจากภายนอก และไม่ได้ยืนยันว่ากฎมีหลักฐานรองรับหรือใช้ได้กับบุคคลนี้',
    'action.reopen': 'เปิดอีกครั้งเพื่อตรวจสอบ',
    'action.read': 'ทำเครื่องหมายว่าอ่านแล้ว',
    'action.snooze': 'เลื่อนหนึ่งวัน',
    'save.success': 'บันทึกไว้ในอุปกรณ์นี้แล้ว',
    'save.failure': 'บันทึกไม่สำเร็จ รายการไม่ได้รับการอัปเดต โปรดลองอีกครั้ง',
  },
  'id': {
    'status.unread': 'Belum dibaca',
    'status.read': 'Sudah dibaca',
    'status.needsReview': 'Perlu ditinjau',
    'status.snoozed': 'Ditunda',
    'status.dismissed': 'Disembunyikan',
    'status.resolved': 'Selesai',
    'status.notApplicable': 'Dicatat tidak berlaku',
    'status.declined': 'Dicatat ditolak',
    'feedback.boundary':
        'Umpan balik ini hanya mencatat pilihan alur kerja. Ini tidak mengonfirmasi kebenaran klinis atau kesesuaian pribadi, penerimaan atau pelaksanaan rekomendasi, maupun perubahan obat.',
    'reason.title': 'Tambahkan alasan untuk respons ini',
    'reason.hint':
        'Alasan singkat wajib diisi dan disimpan sebagai catatan Anda; alasan ini tidak diverifikasi secara independen.',
    'action.cancel': 'Batal',
    'action.saveReason': 'Simpan alasan',
    'reason.categoryPrompt':
        'Pilih deskripsi yang paling sesuai. Ini adalah tanggapan Anda, bukan verifikasi.',
    'reason.category.informationMayBeIncorrect':
        'Informasi mungkin tidak benar',
    'reason.category.contextMismatch': 'Tidak sesuai dengan situasi saya',
    'reason.category.explanationUnclear': 'Penjelasan tidak jelas',
    'reason.category.duplicateOrAlreadyAddressed':
        'Duplikat atau sudah dibahas',
    'reason.category.other': 'Lainnya',
    'history.reasonCategoryUnclassified':
        'Kategori alasan tidak tercatat untuk tanggapan sebelumnya ini',
    'view.open': 'Terbuka',
    'view.needsReview': 'Belum dibaca / perlu ditinjau',
    'view.snoozed': 'Ditunda',
    'view.all': 'Semua pengingat',
    'empty.open':
        'Tidak ada pengingat terbuka. Simpan pemeriksaan makanan untuk melihat pengingat beserta sumbernya di sini.',
    'empty.needsReview':
        'Tidak ada pengingat yang belum dibaca atau perlu ditinjau dalam catatan ini.',
    'empty.snoozed': 'Tidak ada pengingat yang ditunda dalam catatan ini.',
    'empty.all':
        'Belum ada pengingat tersimpan. Simpan pemeriksaan makanan untuk melihat pengingat beserta sumbernya di sini.',
    'section.title': 'Umpan balik pengingat',
    'section.boundary':
        'Filter menggunakan status alur kerja yang Anda catat dan waktu pembuatan; filter ini tidak menunjukkan prioritas atau urgensi klinis.',
    'history.title': 'Sumber dan riwayat umpan balik',
    'history.recordedByYou': 'Dicatat oleh Anda',
    'source.boundary':
        'Hanya metadata registri lokal. Tidak ada data yang diambil dari jaringan, dan informasi ini tidak memverifikasi dukungan aturan atau kesesuaiannya bagi seseorang.',
    'action.reopen': 'Buka kembali untuk ditinjau',
    'action.read': 'Tandai sudah dibaca',
    'action.snooze': 'Tunda satu hari',
    'save.success': 'Tersimpan di perangkat ini.',
    'save.failure':
        'Gagal menyimpan. Catatan tidak diperbarui. Silakan coba lagi.',
  },
  'ru': {
    'status.unread': 'Не прочитано',
    'status.read': 'Прочитано',
    'status.needsReview': 'Требует проверки',
    'status.snoozed': 'Отложено',
    'status.dismissed': 'Скрыто',
    'status.resolved': 'Обработано',
    'status.notApplicable': 'Отмечено как неприменимое',
    'status.declined': 'Отмечено как отклонённое',
    'feedback.boundary':
        'Этот отзыв фиксирует только выбор в рабочем процессе. Он не подтверждает клиническую корректность или применимость, принятие или выполнение рекомендации либо изменение лекарства.',
    'reason.title': 'Укажите причину ответа',
    'reason.hint':
        'Нужно кратко указать причину. Она сохранится как ваша заметка и не будет независимо проверена.',
    'action.cancel': 'Отмена',
    'action.saveReason': 'Сохранить причину',
    'reason.categoryPrompt':
        'Выберите наиболее подходящее описание. Это ваш отзыв, а не проверка.',
    'reason.category.informationMayBeIncorrect':
        'В сведениях может быть ошибка',
    'reason.category.contextMismatch': 'Не подходит к моей ситуации',
    'reason.category.explanationUnclear': 'Объяснение неясно',
    'reason.category.duplicateOrAlreadyAddressed': 'Повтор или уже рассмотрено',
    'reason.category.other': 'Другое',
    'history.reasonCategoryUnclassified':
        'Для этого прежнего ответа категория причины не записана',
    'view.open': 'Открытые',
    'view.needsReview': 'Не прочитано / проверить',
    'view.snoozed': 'Отложенные',
    'view.all': 'Все напоминания',
    'empty.open':
        'Открытых напоминаний нет. Сохраните проверку приёма пищи, чтобы увидеть здесь напоминания с источниками.',
    'empty.needsReview':
        'В этих записях нет непрочитанных напоминаний или напоминаний, требующих проверки.',
    'empty.snoozed': 'В этих записях нет отложенных напоминаний.',
    'empty.all':
        'Сохранённых напоминаний пока нет. Сохраните проверку приёма пищи, чтобы увидеть здесь напоминания с источниками.',
    'section.title': 'Обратная связь по напоминаниям',
    'section.boundary':
        'Фильтры используют записанный вами рабочий статус и время создания; они не указывают клинический приоритет или срочность.',
    'history.title': 'Источники и история обратной связи',
    'history.recordedByYou': 'Записано вами',
    'source.boundary':
        'Только метаданные локального реестра. Данные не загружаются из сети; это не подтверждает обоснованность правила или его применимость к человеку.',
    'action.reopen': 'Снова открыть для проверки',
    'action.read': 'Отметить как прочитанное',
    'action.snooze': 'Отложить на один день',
    'save.success': 'Сохранено на этом устройстве.',
    'save.failure':
        'Не удалось сохранить. Запись не изменена. Повторите попытку.',
  },
  'pl': {
    'status.unread': 'Nieprzeczytane',
    'status.read': 'Przeczytane',
    'status.needsReview': 'Do sprawdzenia',
    'status.snoozed': 'Odłożone',
    'status.dismissed': 'Ukryte',
    'status.resolved': 'Załatwione',
    'status.notApplicable': 'Oznaczono jako nie dotyczy',
    'status.declined': 'Oznaczono jako odrzucone',
    'feedback.boundary':
        'Ta informacja zwrotna zapisuje wyłącznie wybór w przepływie pracy. Nie potwierdza poprawności klinicznej ani zastosowania do danej osoby, przyjęcia lub zastosowania zalecenia ani zmiany leku.',
    'reason.title': 'Podaj powód tej odpowiedzi',
    'reason.hint':
        'Wymagany jest krótki powód. Zostanie zapisany jako Twoja notatka i nie będzie niezależnie weryfikowany.',
    'action.cancel': 'Anuluj',
    'action.saveReason': 'Zapisz powód',
    'reason.categoryPrompt':
        'Wybierz najbliższy opis. To Twoja opinia, a nie weryfikacja.',
    'reason.category.informationMayBeIncorrect':
        'Informacje mogą być nieprawidłowe',
    'reason.category.contextMismatch': 'Nie pasuje do mojej sytuacji',
    'reason.category.explanationUnclear': 'Wyjaśnienie jest niejasne',
    'reason.category.duplicateOrAlreadyAddressed': 'Duplikat lub już omówiono',
    'reason.category.other': 'Inne',
    'history.reasonCategoryUnclassified':
        'Dla tej wcześniejszej odpowiedzi nie zapisano kategorii powodu',
    'view.open': 'Otwarte',
    'view.needsReview': 'Nieprzeczytane / do sprawdzenia',
    'view.snoozed': 'Odłożone',
    'view.all': 'Wszystkie przypomnienia',
    'empty.open':
        'Brak otwartych przypomnień. Zapisz kontrolę posiłku, aby zobaczyć tu przypomnienia ze źródłami.',
    'empty.needsReview':
        'W tych zapisach nie ma nieprzeczytanych przypomnień ani wymagających sprawdzenia.',
    'empty.snoozed': 'W tych zapisach nie ma odłożonych przypomnień.',
    'empty.all':
        'Nie zapisano jeszcze przypomnień. Zapisz kontrolę posiłku, aby zobaczyć tu przypomnienia ze źródłami.',
    'section.title': 'Informacje zwrotne o przypomnieniach',
    'section.boundary':
        'Filtry używają zapisanego przez Ciebie statusu pracy i czasu utworzenia; nie wskazują priorytetu klinicznego ani pilności.',
    'history.title': 'Źródła i historia informacji zwrotnych',
    'history.recordedByYou': 'Zapisane przez Ciebie',
    'source.boundary':
        'Tylko metadane lokalnego rejestru. Nic nie jest pobierane z sieci; nie potwierdza to podstaw reguły ani jej zastosowania do konkretnej osoby.',
    'action.reopen': 'Otwórz ponownie do sprawdzenia',
    'action.read': 'Oznacz jako przeczytane',
    'action.snooze': 'Odłóż o jeden dzień',
    'save.success': 'Zapisano na tym urządzeniu.',
    'save.failure':
        'Nie udało się zapisać. Rekord nie został zmieniony. Spróbuj ponownie.',
  },
  'ar': {
    'status.unread': 'غير مقروء',
    'status.read': 'مقروء',
    'status.needsReview': 'بحاجة إلى مراجعة',
    'status.snoozed': 'مؤجل',
    'status.dismissed': 'مخفي',
    'status.resolved': 'تمت المعالجة',
    'status.notApplicable': 'مُسجّل على أنه غير منطبق',
    'status.declined': 'مُسجّل على أنه مرفوض',
    'feedback.boundary':
        'تسجل هذه الملاحظات اختيارًا ضمن سير العمل فقط. ولا تؤكد الصحة السريرية أو الملاءمة الشخصية، أو قبول التوصية أو اتباعها، أو تغيير الدواء.',
    'reason.title': 'أضف سببًا لهذا الرد',
    'reason.hint':
        'يلزم إدخال سبب مختصر. سيُحفظ كملاحظة منك ولن يُتحقق منه بشكل مستقل.',
    'action.cancel': 'إلغاء',
    'action.saveReason': 'حفظ السبب',
    'reason.categoryPrompt':
        'اختر الوصف الأقرب. هذا رأيك ولا يُعد تحققًا من المعلومات.',
    'reason.category.informationMayBeIncorrect': 'قد تكون المعلومات غير صحيحة',
    'reason.category.contextMismatch': 'لا يناسب حالتي',
    'reason.category.explanationUnclear': 'الشرح غير واضح',
    'reason.category.duplicateOrAlreadyAddressed': 'مكرر أو تمت مناقشته سابقًا',
    'reason.category.other': 'أخرى',
    'history.reasonCategoryUnclassified': 'لم تُسجل فئة السبب لهذا الرد السابق',
    'view.open': 'مفتوح',
    'view.needsReview': 'غير مقروء / للمراجعة',
    'view.snoozed': 'مؤجل',
    'view.all': 'كل التنبيهات',
    'empty.open':
        'لا توجد تنبيهات مفتوحة. احفظ فحصًا للوجبة لعرض التنبيهات ذات المصادر هنا.',
    'empty.needsReview':
        'لا توجد تنبيهات غير مقروءة أو بحاجة إلى مراجعة في هذه السجلات.',
    'empty.snoozed': 'لا توجد تنبيهات مؤجلة في هذه السجلات.',
    'empty.all':
        'لم تُحفظ أي تنبيهات بعد. احفظ فحصًا للوجبة لعرض التنبيهات ذات المصادر هنا.',
    'section.title': 'ملاحظات على التنبيهات',
    'section.boundary':
        'تستخدم عوامل التصفية حالة سير العمل التي سجلتها ووقت الإنشاء؛ ولا تشير إلى أولوية سريرية أو حالة طارئة.',
    'history.title': 'المصادر وسجل الملاحظات',
    'history.recordedByYou': 'سجلته أنت',
    'source.boundary':
        'بيانات وصفية من السجل المحلي فقط. لا يتم جلب بيانات من الشبكة، ولا يؤكد ذلك دعم القاعدة أو انطباقها على شخص بعينه.',
    'action.reopen': 'إعادة الفتح للمراجعة',
    'action.read': 'وضع علامة مقروء',
    'action.snooze': 'تأجيل ليوم واحد',
    'save.success': 'تم الحفظ على هذا الجهاز.',
    'save.failure': 'تعذر الحفظ. لم يتم تحديث السجل. يُرجى المحاولة مرة أخرى.',
  },
};

String _languageFamily(String localeTag) {
  final normalized = localeTag.trim().toLowerCase();
  final separator = normalized.indexOf(RegExp('[-_]'));
  return separator < 0 ? normalized : normalized.substring(0, separator);
}

String careWorkspaceFollowupCopy(String key, {required String localeTag}) {
  final family = _languageFamily(localeTag);
  return kCareWorkspaceFollowupCopy[family]?[key] ??
      kCareWorkspaceFollowupCopy['en']![key] ??
      key;
}

/// Draft visit-preview shell copy for the shipped language families. Coverage
/// tests do not replace independent native-speaker semantic review.
const Map<String, Map<String, String>> kCareWorkspaceVisitCopy = {
  'en': {
    'preview.title': 'Visit checklist preview',
    'preview.privacy':
        'Contains personal health records. Review the content before deciding who to share it with.',
    'preview.reportLanguage':
        'Report text is generated in Chinese or English. User-entered text is kept as entered.',
    'preview.accountChanged':
        'Account changed. Please generate a new checklist.',
    'review.heading': 'Medication source records to review ({count})',
    'review.hint':
        'Opens the current source review. If records changed after this report was generated, the page shows their current state.',
    'review.button':
        '{name} · {blocking} blocking relationships · {findings} integrity findings · Review sources',
    'agenda.heading': 'Concise visit discussion summary',
    'action.copyAgenda': 'Copy concise agenda',
    'agenda.copy.success': 'Concise agenda copied.',
    'action.copy': 'Copy checklist',
    'copy.success': 'Checklist copied.',
    'copy.failure': 'Could not copy. Please retry.',
  },
  'zh': {
    'preview.title': '就诊清单预览',
    'preview.privacy': '包含个人健康记录。请先检查内容，再决定是否分享以及分享对象。',
    'preview.reportLanguage': '清单正文使用中文或英文生成；本人输入的文字保持原样。',
    'preview.accountChanged': '账号已更改，请重新生成清单。',
    'review.heading': '待核对的药物来源记录（{count}）',
    'review.hint': '打开当前来源核对页面。如果报告生成后记录发生变化，页面会显示当前状态。',
    'review.button': '{name} · 阻断关系 {blocking} 条 · 完整性提示 {findings} 项 · 核对来源',
    'agenda.heading': '就诊沟通摘要（简版）',
    'action.copyAgenda': '复制简版摘要',
    'agenda.copy.success': '已复制简版摘要。',
    'action.copy': '复制清单',
    'copy.success': '已复制清单。',
    'copy.failure': '复制失败，请重试。',
  },
  'fr': {
    'preview.title': 'Aperçu de la liste pour la consultation',
    'preview.privacy':
        'Cette liste contient des données de santé personnelles. Vérifiez son contenu avant de décider avec qui la partager.',
    'preview.reportLanguage':
        'Le texte de la liste est généré en chinois ou en anglais. Le texte saisi est conservé tel quel.',
    'preview.accountChanged':
        'Le compte a changé. Veuillez générer une nouvelle liste.',
    'review.heading': 'Sources des médicaments à vérifier ({count})',
    'review.hint':
        'Ouvre la vérification actuelle des sources. Si les données ont changé depuis la génération de cette liste, la page affiche leur état actuel.',
    'review.button':
        '{name} · {blocking} relations bloquantes · {findings} problèmes d’intégrité · Vérifier les sources',
    'agenda.heading': 'Résumé succinct des sujets à aborder en consultation',
    'action.copyAgenda': 'Copier le résumé succinct',
    'agenda.copy.success': 'Résumé succinct copié.',
    'action.copy': 'Copier la liste',
    'copy.success': 'Liste copiée.',
    'copy.failure': 'Impossible de copier. Veuillez réessayer.',
  },
  'ja': {
    'preview.title': '受診用チェックリストのプレビュー',
    'preview.privacy': '個人の健康記録が含まれます。共有する相手を決める前に内容を確認してください。',
    'preview.reportLanguage': 'リスト本文は中国語または英語で生成されます。入力された文章はそのまま保持されます。',
    'preview.accountChanged': 'アカウントが変更されました。新しいリストを作成してください。',
    'review.heading': '確認が必要な薬剤の情報源（{count}件）',
    'review.hint': '現在の情報源確認画面を開きます。リスト作成後に記録が変更された場合、画面には現在の状態が表示されます。',
    'review.button':
        '{name} · ブロック関係 {blocking}件 · 整合性の指摘 {findings}件 · 情報源を確認',
    'agenda.heading': '受診時に話し合う項目の要約',
    'action.copyAgenda': '要約をコピー',
    'agenda.copy.success': '要約をコピーしました。',
    'action.copy': 'リストをコピー',
    'copy.success': 'リストをコピーしました。',
    'copy.failure': 'コピーできませんでした。もう一度お試しください。',
  },
  'ko': {
    'preview.title': '진료 준비 목록 미리보기',
    'preview.privacy': '개인 건강 기록이 포함되어 있습니다. 누구와 공유할지 결정하기 전에 내용을 확인하세요.',
    'preview.reportLanguage':
        '목록 본문은 중국어 또는 영어로 생성됩니다. 직접 입력한 문구는 입력된 그대로 유지됩니다.',
    'preview.accountChanged': '계정이 변경되었습니다. 새 목록을 생성하세요.',
    'review.heading': '검토할 약물 출처 기록 ({count}개)',
    'review.hint': '현재 출처 검토 화면을 엽니다. 목록 생성 후 기록이 바뀌었다면 현재 상태가 표시됩니다.',
    'review.button':
        '{name} · 차단 관계 {blocking}건 · 무결성 확인 사항 {findings}개 · 출처 검토',
    'agenda.heading': '진료 상담 요약',
    'action.copyAgenda': '간단 요약 복사',
    'agenda.copy.success': '간단 요약을 복사했습니다.',
    'action.copy': '목록 복사',
    'copy.success': '목록을 복사했습니다.',
    'copy.failure': '복사하지 못했습니다. 다시 시도하세요.',
  },
  'hi': {
    'preview.title': 'मुलाक़ात की सूची का पूर्वावलोकन',
    'preview.privacy':
        'इसमें आपके व्यक्तिगत स्वास्थ्य रिकॉर्ड हैं। किससे साझा करना है, यह तय करने से पहले सामग्री देखें।',
    'preview.reportLanguage':
        'सूची का पाठ चीनी या अंग्रेज़ी में बनाया जाता है। आपके द्वारा लिखा गया पाठ उसी रूप में रखा जाता है।',
    'preview.accountChanged': 'खाता बदल गया है। कृपया नई सूची बनाएँ।',
    'review.heading': 'जाँचने के लिए दवा-स्रोत रिकॉर्ड ({count})',
    'review.hint':
        'मौजूदा स्रोत-जाँच खोलें। सूची बनने के बाद रिकॉर्ड बदले हों, तो पृष्ठ उनकी मौजूदा स्थिति दिखाता है।',
    'review.button':
        '{name} · रोकने वाले संबंध {blocking} · अखंडता निष्कर्ष {findings} · स्रोत जाँचें',
    'agenda.heading': 'मुलाक़ात के लिए चर्चा का संक्षिप्त सार',
    'action.copyAgenda': 'संक्षिप्त सार कॉपी करें',
    'agenda.copy.success': 'संक्षिप्त सार कॉपी हो गया।',
    'action.copy': 'सूची कॉपी करें',
    'copy.success': 'सूची कॉपी हो गई।',
    'copy.failure': 'कॉपी नहीं हो सकी। कृपया फिर कोशिश करें।',
  },
  'es': {
    'preview.title': 'Vista previa de la lista para la consulta',
    'preview.privacy':
        'Incluye registros personales de salud. Revise el contenido antes de decidir con quién compartirlo.',
    'preview.reportLanguage':
        'El texto de la lista se genera en chino o inglés. El texto que usted escribió se conserva tal como se ingresó.',
    'preview.accountChanged': 'La cuenta cambió. Genere una lista nueva.',
    'review.heading':
        'Registros de origen de medicamentos por revisar ({count})',
    'review.hint':
        'Abre la revisión actual de las fuentes. Si los registros cambiaron después de generar esta lista, la página muestra su estado actual.',
    'review.button':
        '{name} · relaciones bloqueantes: {blocking} · hallazgos de integridad: {findings} · Revisar fuentes',
    'agenda.heading': 'Resumen breve de temas para conversar en la consulta',
    'action.copyAgenda': 'Copiar resumen breve',
    'agenda.copy.success': 'Se copió el resumen breve.',
    'action.copy': 'Copiar lista',
    'copy.success': 'Lista copiada.',
    'copy.failure': 'No se pudo copiar. Inténtelo de nuevo.',
  },
  'vi': {
    'preview.title': 'Xem trước danh sách chuẩn bị khám',
    'preview.privacy':
        'Danh sách có hồ sơ sức khỏe cá nhân. Hãy xem nội dung trước khi quyết định chia sẻ với ai.',
    'preview.reportLanguage':
        'Nội dung danh sách được tạo bằng tiếng Trung hoặc tiếng Anh. Văn bản bạn nhập được giữ nguyên.',
    'preview.accountChanged':
        'Tài khoản đã thay đổi. Vui lòng tạo danh sách mới.',
    'review.heading': 'Bản ghi nguồn thuốc cần kiểm tra ({count})',
    'review.hint':
        'Mở phần kiểm tra nguồn hiện tại. Nếu bản ghi thay đổi sau khi tạo danh sách, trang sẽ hiển thị trạng thái hiện tại.',
    'review.button':
        '{name} · quan hệ đang chặn: {blocking} · phát hiện về tính toàn vẹn: {findings} · Kiểm tra nguồn',
    'agenda.heading': 'Tóm tắt ngắn các nội dung cần trao đổi khi khám',
    'action.copyAgenda': 'Sao chép tóm tắt ngắn',
    'agenda.copy.success': 'Đã sao chép tóm tắt ngắn.',
    'action.copy': 'Sao chép danh sách',
    'copy.success': 'Đã sao chép danh sách.',
    'copy.failure': 'Không sao chép được. Vui lòng thử lại.',
  },
  'th': {
    'preview.title': 'ตัวอย่างรายการเตรียมพบแพทย์',
    'preview.privacy':
        'รายการนี้มีข้อมูลสุขภาพส่วนบุคคล โปรดตรวจสอบเนื้อหาก่อนตัดสินใจว่าจะแชร์กับใคร',
    'preview.reportLanguage':
        'เนื้อหารายการสร้างเป็นภาษาจีนหรือภาษาอังกฤษ ข้อความที่คุณกรอกจะคงไว้ตามเดิม',
    'preview.accountChanged': 'บัญชีเปลี่ยนแล้ว โปรดสร้างรายการใหม่',
    'review.heading': 'รายการแหล่งที่มาของยาที่ต้องตรวจสอบ ({count})',
    'review.hint':
        'เปิดหน้าตรวจสอบแหล่งที่มาปัจจุบัน หากข้อมูลเปลี่ยนหลังสร้างรายการ หน้านี้จะแสดงสถานะปัจจุบัน',
    'review.button':
        '{name} · ความสัมพันธ์ที่ขัดขวาง {blocking} รายการ · ข้อค้นพบด้านความครบถ้วน {findings} รายการ · ตรวจสอบแหล่งที่มา',
    'agenda.heading': 'สรุปสั้นสำหรับพูดคุยระหว่างการพบแพทย์',
    'action.copyAgenda': 'คัดลอกสรุปสั้น',
    'agenda.copy.success': 'คัดลอกสรุปสั้นแล้ว',
    'action.copy': 'คัดลอกรายการ',
    'copy.success': 'คัดลอกรายการแล้ว',
    'copy.failure': 'คัดลอกไม่ได้ โปรดลองอีกครั้ง',
  },
  'id': {
    'preview.title': 'Pratinjau daftar persiapan kunjungan',
    'preview.privacy':
        'Daftar ini berisi catatan kesehatan pribadi. Tinjau isinya sebelum memutuskan kepada siapa akan membagikannya.',
    'preview.reportLanguage':
        'Teks daftar dibuat dalam bahasa Mandarin atau Inggris. Teks yang Anda masukkan dipertahankan apa adanya.',
    'preview.accountChanged': 'Akun telah berubah. Buat daftar baru.',
    'review.heading': 'Catatan sumber obat yang perlu ditinjau ({count})',
    'review.hint':
        'Buka pemeriksaan sumber terkini. Jika catatan berubah setelah daftar dibuat, halaman menampilkan status saat ini.',
    'review.button':
        '{name} · hubungan yang memblokir {blocking} · temuan integritas {findings} · Tinjau sumber',
    'agenda.heading': 'Ringkasan singkat untuk dibahas saat kunjungan',
    'action.copyAgenda': 'Salin ringkasan singkat',
    'agenda.copy.success': 'Ringkasan singkat disalin.',
    'action.copy': 'Salin daftar',
    'copy.success': 'Daftar disalin.',
    'copy.failure': 'Tidak dapat menyalin. Silakan coba lagi.',
  },
  'ru': {
    'preview.title': 'Предварительный просмотр списка к визиту',
    'preview.privacy':
        'Список содержит личные медицинские записи. Проверьте его, прежде чем решать, кому его передавать.',
    'preview.reportLanguage':
        'Текст списка формируется на китайском или английском языке. Введённый вами текст сохраняется без изменений.',
    'preview.accountChanged': 'Аккаунт изменён. Создайте новый список.',
    'review.heading': 'Записи об источниках лекарств для проверки ({count})',
    'review.hint':
        'Открывает текущую проверку источников. Если записи изменились после создания списка, страница покажет их текущее состояние.',
    'review.button':
        '{name} · блокирующие связи: {blocking} · замечания целостности: {findings} · Проверить источники',
    'agenda.heading': 'Краткое содержание для обсуждения на приёме',
    'action.copyAgenda': 'Скопировать краткое содержание',
    'agenda.copy.success': 'Краткое содержание скопировано.',
    'action.copy': 'Скопировать список',
    'copy.success': 'Список скопирован.',
    'copy.failure': 'Не удалось скопировать. Повторите попытку.',
  },
  'pl': {
    'preview.title': 'Podgląd listy przygotowania do wizyty',
    'preview.privacy':
        'Lista zawiera prywatne dane dotyczące zdrowia. Sprawdź jej treść przed podjęciem decyzji, komu ją udostępnić.',
    'preview.reportLanguage':
        'Treść listy jest tworzona w języku chińskim lub angielskim. Wpisany tekst pozostaje bez zmian.',
    'preview.accountChanged': 'Konto zostało zmienione. Utwórz nową listę.',
    'review.heading': 'Źródła informacji o lekach do sprawdzenia ({count})',
    'review.hint':
        'Otwiera bieżący widok weryfikacji źródeł. Jeśli wpisy zmieniły się po utworzeniu listy, strona pokaże ich aktualny stan.',
    'review.button':
        '{name} · relacje blokujące: {blocking} · ustalenia dotyczące integralności: {findings} · Sprawdź źródła',
    'agenda.heading': 'Krótkie podsumowanie do omówienia podczas wizyty',
    'action.copyAgenda': 'Kopiuj krótkie podsumowanie',
    'agenda.copy.success': 'Skopiowano krótkie podsumowanie.',
    'action.copy': 'Kopiuj listę',
    'copy.success': 'Lista została skopiowana.',
    'copy.failure': 'Nie udało się skopiować. Spróbuj ponownie.',
  },
  'ar': {
    'preview.title': 'معاينة قائمة الاستعداد للزيارة',
    'preview.privacy':
        'تتضمن القائمة سجلات صحية شخصية. راجع المحتوى قبل أن تقرر مع من تشاركه.',
    'preview.reportLanguage':
        'يُنشأ نص القائمة بالصينية أو الإنجليزية. ويُحفظ النص الذي أدخلته كما هو.',
    'preview.accountChanged': 'تغيّر الحساب. يُرجى إنشاء قائمة جديدة.',
    'review.heading': 'سجلات مصادر الأدوية التي تحتاج إلى مراجعة ({count})',
    'review.hint':
        'يفتح مراجعة المصادر الحالية. إذا تغيّرت السجلات بعد إنشاء القائمة، فستعرض الصفحة حالتها الحالية.',
    'review.button':
        '{name} · علاقات مانعة {blocking} · ملاحظات سلامة البيانات {findings} · راجع المصادر',
    'agenda.heading': 'ملخص موجز لمناقشته أثناء الزيارة',
    'action.copyAgenda': 'انسخ الملخص الموجز',
    'agenda.copy.success': 'تم نسخ الملخص الموجز.',
    'action.copy': 'انسخ القائمة',
    'copy.success': 'تم نسخ القائمة.',
    'copy.failure': 'تعذر النسخ. يُرجى المحاولة مرة أخرى.',
  },
};

String careWorkspaceVisitCopy(
  String key, {
  required String localeTag,
  Map<String, String> parameters = const {},
}) {
  final family = _languageFamily(localeTag);
  var copy =
      kCareWorkspaceVisitCopy[family]?[key] ??
      kCareWorkspaceVisitCopy['en']![key] ??
      key;
  for (final entry in parameters.entries) {
    copy = copy.replaceAll('{${entry.key}}', entry.value);
  }
  return copy;
}

String followupStatusLabel(
  DecisionSupportFollowupStatus status, {
  required bool chinese,
  String? localeTag,
}) => careWorkspaceFollowupCopy(
  'status.${status.name}',
  localeTag: localeTag ?? (chinese ? 'zh' : 'en'),
);

String followupReasonCategoryLabel(
  DecisionSupportFeedbackReasonCategory category, {
  required String localeTag,
}) => careWorkspaceFollowupCopy(
  'reason.category.${category.name}',
  localeTag: localeTag,
);
