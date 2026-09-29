/// Full UI translations for the locales added alongside
/// `LocaleResourceSeedImporter` and `secondary_source_registry.dart`.
///
/// Schema: `languageFamily → flatKey → translatedString`. Merged into
/// `_strings` inside `app_i18n.dart` so `tr('nav.home')` etc. resolve
/// natively for every supported locale, mirroring the coverage zh / en
/// already enjoy.
///
/// All `{placeholder}` tokens are preserved verbatim.
const Map<String, Map<String, String>> kFullLocaleUiTranslations = {
  // ===========================================================================
  // ko (Korean)
  // ===========================================================================
  'ko': {
    'reminders.locale_reconciliation_title': '시스템 알림 언어가 다릅니다',
    'reminders.locale_reconciliation_body':
        '앱 언어가 변경되었습니다. 현재 시스템 알림 문구를 유지하거나 이 기기의 모든 알림을 원자적으로 업데이트할 수 있습니다. 어느 선택도 작성한 라벨을 표시하지 않습니다.',
    'reminders.locale_retain_action': '현재 알림 언어 유지',
    'reminders.locale_update_action': '모두 현재 언어로 업데이트',
    'reminders.locale_retained_confirmation': '현재 시스템 알림 언어를 유지했습니다.',
    'reminders.locale_updated_confirmation':
        '모든 시스템 알림을 현재 언어로 업데이트하도록 요청했습니다.',
    'diagnostics.title': '엔지니어링 진단',
    'diagnostics.rerun': '검사 다시 실행',
    'diagnostics.scope_title': '엔지니어링 검토 전용',
    'diagnostics.scope_body':
        '이는 결정론적 거버넌스 검사(문구 컴파일, 현지화 안전성 린트, 합성 시나리오 재생)입니다. 엔지니어링 상태만 보고하며, 점수·심각도·근거·규칙 결과를 변경하지 않고 건강 지침이 아닙니다. 합성/데모 데이터만 사용합니다.',
    'diagnostics.elapsed': '검사가 {ms} ms 만에 완료되었습니다.',
    'reminders.identity_attestation_title': '플러그인 대기 요청 식별 정보 확인',
    'reminders.identity_attestation_matched':
        '플러그인이 보고한 대기 식별 정보가 계획과 일치합니다({installed}/{planned}). 이는 운영체제 스케줄러 또는 실제 표시 전달을 독립적으로 검증한 결과가 아닙니다.',
    'reminders.identity_attestation_drift':
        '플러그인이 보고한 식별 정보가 계획과 다릅니다. 누락 {missing}개, 추가 {extra}개, 계획된 ID에서 교체 {replaced}개입니다. 다시 동기화될 때까지 시스템 알림에 의존하지 마세요.',
    'reminders.identity_attestation_uninspectable':
        '플러그인에서 대기 요청 식별 정보를 읽을 수 없습니다. 로컬 계획이 기준이지만 시스템 알림 상태는 확인되지 않았습니다.',
    'reminders.error_schedule_identity_unverified':
        '로컬 계획은 저장되었지만 플러그인이 보고한 대기 식별 정보를 계획과 대조할 수 없습니다. 시스템 알림에 의존하기 전에 다시 동기화하세요.',
    'reminders.readiness_title': '시스템 알림 전달 준비 상태',
    'reminders.readiness_contract': '{platform} 기능 계약 · {digest}',
    'reminders.readiness_boundary':
        '완료된 예약 요청이나 일치하는 플러그인 식별 정보만으로 화면, 잠금 화면 또는 백그라운드 전달이 입증되지는 않습니다.',
    'reminders.readiness_platform_android': 'Android',
    'reminders.readiness_platform_ios': 'iOS',
    'reminders.readiness_platform_macos': 'macOS',
    'reminders.readiness_platform_web': 'Web',
    'reminders.readiness_platform_windows': 'Windows',
    'reminders.readiness_platform_linux': 'Linux',
    'reminders.readiness_platform_unknown': '알 수 없는 플랫폼 또는 사용자 지정 게이트웨이',
    'reminders.readiness_local_plan': '로컬 계획',
    'reminders.readiness_adapter': '예약 어댑터',
    'reminders.readiness_schedule_request': '예약 요청',
    'reminders.readiness_permission_request': '권한 요청',
    'reminders.readiness_permission_inspection': '현재 권한 상태 확인',
    'reminders.readiness_registry': '플러그인 대기 레지스트리',
    'reminders.readiness_visible_delivery': '화면에 표시되는 전달',
    'reminders.readiness_body_tap': '알림 본문 탭',
    'reminders.readiness_cold_start': '알림으로 콜드 스타트',
    'reminders.readiness_background_action': '백그라운드 작업',
    'reminders.readiness_local_none': '구성된 로컬 계획 없음',
    'reminders.readiness_local_saved': '이 기기에 저장됨',
    'reminders.readiness_adapter_plan_only': '계획만 저장하며 시스템 알림 API를 호출하지 않음',
    'reminders.readiness_evidence_artifact_verified': '대상 플랫폼의 아티팩트 결합 증거로 검증됨',
    'reminders.readiness_evidence_implemented_unverified':
        '구현됨; 대상 기기의 아티팩트 결합 검증 없음',
    'reminders.readiness_evidence_unavailable': '사용할 수 없거나 구현되지 않음',
    'reminders.readiness_request_not_requested': '제출되지 않음',
    'reminders.readiness_request_applied': '플러그인 요청 완료; 전달은 입증되지 않음',
    'reminders.readiness_request_rolled_back':
        '새 예약 요청이 롤백되고 이전 계획이 복원됨; 전달은 입증되지 않음',
    'reminders.readiness_request_superseded': '더 최신 계정 또는 계획으로 대체됨',
    'reminders.readiness_request_unsupported': '이 계약은 계획 전용임',
    'reminders.readiness_request_failed': '요청 실패 또는 식별 정보 미검증',
    'reminders.readiness_request_recovery_required': '신뢰하기 전에 조정 필요',
    'reminders.readiness_permission_not_requested': '이번 세션에서 요청하지 않음',
    'reminders.readiness_permission_granted':
        '권한 요청 호출이 허용을 반환함; 현재 상태와 같다고 볼 수 없음',
    'reminders.readiness_permission_denied':
        '권한 요청 호출이 허용 안 됨을 반환함; 사용자의 명시적 거부를 뜻하지 않음',
    'reminders.readiness_permission_failed':
        '권한 요청 실패 또는 어댑터 사용 불가; 사용자가 거부했다는 뜻은 아님',
    'reminders.readiness_permission_unavailable': '이 기능 계약은 권한을 요청하지 않음',
    'reminders.readiness_inspection_not_inspected': '현재 권한 상태를 확인하지 않음',
    'reminders.readiness_inspection_enabled':
        '플러그인 현재 상태 확인 결과 활성화됨; 전달 증거는 아님',
    'reminders.readiness_inspection_disabled':
        '플러그인 현재 상태 확인 결과 비활성화됨; 원인이나 사용자 선택은 확인되지 않음',
    'reminders.readiness_inspection_unavailable':
        '현재 권한 상태를 확인할 수 없음; 사용자의 거부를 뜻하지 않음',
    'reminders.readiness_inspection_failed': '현재 권한 상태 확인 실패; 사용자의 거부를 뜻하지 않음',
    'reminders.readiness_registry_not_inspected': '확인하지 않음',
    'reminders.readiness_registry_matched':
        '플러그인 보고가 로컬 계획과 일치함; 운영체제 전달 증거는 아님',
    'reminders.readiness_registry_drift': '플러그인 보고가 로컬 계획과 다름',
    'reminders.readiness_registry_uninspectable': '플러그인 식별 정보를 읽을 수 없음',
    'reminders.readiness_registry_unsupported': '이 기능 계약은 네이티브 레지스트리를 확인하지 않음',
    'reminders.readiness_visible_unverified': '검증되지 않음',
    'reminders.readiness_visible_artifact_verified': '대상 플랫폼 아티팩트 증거로 검증됨',
    'app.welcome': '환영합니다',
    'app.loading': '불러오는 중...',
    'onboarding.title': 'ParkinSUM 동반자 (로컬 에디션)',
    'onboarding.description':
        '이 앱은 식사 기록과 규칙 기반 안내만 제공합니다. 의사나 약사의 조언을 대체하지 않습니다.',
    'onboarding.registration_region': '등록 지역',
    'onboarding.registration_region_help': '기본 관할 체인과 데이터 출처 우선순위를 결정합니다.',
    'onboarding.display_language': '표시 언어',
    'onboarding.display_language_help': '앱 언어, 날짜 및 숫자 형식을 제어합니다.',
    'onboarding.diet_profile_region': '식단 프로필 지역',
    'onboarding.diet_profile_region_help': '안전 규칙을 덮어쓰지 않고 기본 식사 템플릿에 사용됩니다.',
    'onboarding.swallowing_texture_mode': '삼킴 / 질감 안전 모드',
    'onboarding.swallowing_texture_mode_help':
        '임상 삼킴 평가가 아닌 보수적 추천 선호도로 사용됩니다.',
    'onboarding.content_override': '콘텐츠 관할 재정의 (선택)',
    'onboarding.content_override_help': '쉼표로 구분, 예: US,CA',
    'onboarding.local_ai_consent': '로컬 AI 재정렬 활성화 (선택)',
    'onboarding.local_ai_consent_help':
        '로컬 호스트의 Ollama/llama.cpp만 사용하며, 안전 게이트가 차단하면 보수 경로로 자동 전환됩니다.',
    'onboarding.start': '확인했습니다, 계속',
    'nav.home': '홈',
    'nav.analytics': '분석',
    'nav.meals': '식사',
    'nav.timeline': '타임라인',
    'nav.meds': '약물',
    'nav.catalog': '카탈로그',
    'nav.next_meal': '다음 식사',
    'shell.tagline': '동반 앱 · 연구용 프로토타입',
    'shell.workspace': '작업 공간',
    'shell.care_workspace': '진료 준비 및 확인 사항',
    'shell.boundary_note':
        '교육용 프로토타입이며 의료 조언이 아닙니다. 건강 관련 결정은 자격을 갖춘 임상의와 확인하세요.',
    'dashboard.greeting_morning': '좋은 아침입니다',
    'dashboard.greeting_afternoon': '좋은 오후입니다',
    'dashboard.greeting_evening': '좋은 저녁입니다',
    'dashboard.subtitle': '기록된 식사와 복약, 각 설명의 근거가 되는 규칙을 한눈에 봅니다.',
    'dashboard.stat_meals': '기록된 식사',
    'dashboard.stat_drugs': '복용 중인 약',
    'dashboard.stat_intakes': '기록된 복약',
    'shell.new_entry': '새 기록',
    'shell.search': '검색',
    'shell.search_hint': '페이지, 도구, 작업 검색',
    'shell.search_empty': '일치하는 페이지, 도구 또는 작업이 없습니다',
    'shell.menu': '메뉴',
    'shell.group.evidence': '근거와 규칙',
    'shell.group.data': '내 데이터',
    'shell.group.operations': '운영',
    'shell.group.pages': '페이지',
    'shell.action.observation': '관찰 기록',
    'dashboard.stat_protein': '식사당 평균 단백질',
    'dashboard.show_details': '세부 정보 보기',
    'dashboard.hide_details': '세부 정보 숨기기',
    'dashboard.quick_log': '빠른 기록',
    'dashboard.today': '최근 기록',
    'insights.title': '인사이트',
    'insights.subtitle': '내 기록만으로 보는 패턴입니다.',
    'insights.range_7': '7일',
    'insights.range_30': '30일',
    'insights.meals': '식사',
    'insights.intakes': '복약 기록',
    'insights.observations': '관찰',
    'insights.avg_protein': '식사당 평균 단백질',
    'insights.rhythm_title': '기록 리듬',
    'insights.rhythm_subtitle': '하루 기록 수',
    'insights.protein_title': '식사당 단백질',
    'insights.protein_subtitle': '기록된 식사별 그램(오래된 순)',
    'insights.daypart_title': '시간대',
    'insights.daypart_subtitle': '식사와 복약을 기록한 시간대',
    'insights.morning': '아침',
    'insights.midday': '점심',
    'insights.evening': '저녁',
    'insights.night': '밤',
    'insights.empty': '이 기간에는 아직 기록이 없습니다.',
    'insights.boundary':
        '이는 사용자 기록의 기술적 요약일 뿐 임상 측정, 목표 또는 조언이 아닙니다. 건강 관련 결정은 자격을 갖춘 임상의와 확인하세요.',
    'settings.local_ai_advanced': '고급 · 로컬 AI 연결',
    'nav.today': '오늘',
    'nav.library': '라이브러리',
    'dashboard.log_prompt': '무엇을 기록할까요?',
    'dashboard.log_meal_hint': '음식과 양, 교육용 규칙으로 확인',
    'dashboard.log_intake_hint': '복용한 약 1회분',
    'dashboard.log_observation_hint': '혈압, 증상 또는 운동 상태',
    'dashboard.open_timeline': '타임라인 열기',
    'dashboard.open_next_meal': '다음 식사 열기',
    'library.my_medications': '내 약',
    'library.catalog': '음식과 약',
    'next_meal.title': '다음 식사 추천',
    'next_meal.subtitle':
        '다음 식사 시간을 정하세요. 보수적 규칙 경로는 후보 순서를 유지하고, 기전 모델은 교육용 시간 중첩 추적만 추가하며 재정렬하지 않습니다. 로컬 AI는 별도의 선택적 안전 목록 재정렬 기능입니다.',
    'next_meal.input_time': '예상 다음 식사 시간',
    'next_meal.use_local_ai': '로컬 AI로 문구 다듬기 (선택)',
    'next_meal.use_local_ai_help':
        '엔진이 이미 통과시킨 후보에 대해서만 localhost의 Ollama/llama.cpp가 재정렬과 설명 다듬기를 수행합니다. 안전 게이트가 차단하면 자동으로 보수 경로로 돌아갑니다.',
    'next_meal.generate': '추천 생성',
    'next_meal.generating': '생성 중…',
    'next_meal.empty': '예상 시간을 설정한 뒤 "추천 생성"을 누르세요. 그 시간 창을 기준으로 다시 평가됩니다.',
    'next_meal.why_these': '이렇게 추천한 이유',
    'next_meal.ai_polished': '로컬 AI가 문구를 다듬음',
    'next_meal.conservative_engine': '충돌 엔진 보수 경로',
    'next_meal.recommendation_path': '추천 경로',
    'next_meal.gate_reasons': '안전 게이트 메모',
    'next_meal.candidates': '상위 후보',
    'next_meal.no_candidates':
        '현재 조건에 맞는 후보가 없습니다. 예상 시간을 조정하거나 음식 카탈로그를 확장하세요.',
    'next_meal.error': '생성 실패',
    'dashboard.title': '대시보드',
    'dashboard.status': '개요',
    'dashboard.logged_meals': '기록된 식사: {count}',
    'dashboard.active_drugs': '활성 약물: {count}',
    'dashboard.logged_intakes': '약물 복용 기록: {count}',
    'dashboard.recommendations': '추천',
    'dashboard.no_recommendations': '추천이 아직 없습니다',
    'dashboard.recommendation_path': '추천 경로',
    'dashboard.recommendation_template':
        '활성 템플릿: {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': '로컬 AI 보강 사용됨',
    'dashboard.ai_not_used': '보수 경로만 사용',
    'dashboard.recommendation_why': '이런 추천이 나온 이유',
    'dashboard.recommendation_gate': 'AI / 안전 게이트 상태',
    'dashboard.recommendation_macro_line':
        '100g당: 단백질 {protein} g · 탄수 {carbs} g · 지방 {fat} g',
    'dashboard.recommendation_score_line':
        '안전 {safety} · 일정 {schedule} · 사실 {facts} · 컨텍스트 페널티 {context} · 시간 페널티 {timing} · 삼킴 페널티 {swallowing} · 템플릿 일치 {template}',
    'dashboard.recent_meals': '최근 식사 (최근 5건)',
    'dashboard.no_meals': '아직 기록된 식사가 없습니다',
    'dashboard.items': '{count}개 항목',
    'dashboard.meal_context_iron_supplement': '철분 보충제 동반 이벤트',
    'dashboard.meal_context_iron_multivitamin': '철분 함유 종합비타민 동반 이벤트',
    'dashboard.meal_context_starch_thickener': '전분 기반 증점제',
    'dashboard.meal_context_xanthan_thickener': '잔탄검 기반 증점제',
    'dashboard.meal_context_enteral_feed_continuous':
        '지속적 경장영양 (단백질 {protein} g/일)',
    'dashboard.meal_context_enteral_feed_bolus': '볼루스/간헐적 경장영양',
    'dashboard.edit': '편집',
    'dashboard.delete': '삭제',
    'dashboard.protein_trend': '단백질 추세',
    'dashboard.average_protein': '평균 단백질: 식사당 {value} g',
    'dashboard.no_trend': '추세 데이터가 아직 없습니다',
    'dashboard.timeline': '타임라인',
    'dashboard.no_timeline': '아직 식사나 약물 이벤트가 없습니다',
    'dashboard.add_meal': '식사 추가',
    'dashboard.meal_check': '식사 점검 - {title}',
    'timeline.title': '식사 및 약물 타임라인',
    'timeline.empty': '아직 식사나 약물 복용 기록이 없습니다',
    'timeline.add_meal': '식사 추가',
    'timeline.add_intake': '약물 기록',
    'timeline.new_intake': '새 약물 복용',
    'timeline.edit_intake': '약물 복용 편집',
    'timeline.medication': '약물',
    'timeline.active_medication_option': '{name} (활성)',
    'timeline.dosage_note': '용량 메모',
    'timeline.package_dose_source': '출처: {source} · 조회: {retrieved} · {url}',
    'timeline.package_dose_derivation':
        '계산: {strength} × {quantity} {unit} = {amount} {resultUnit}',
    'timeline.package_dose_assumed_denominator':
        '출처에 분모가 없어 이산 제형 단위 1 {unit}을 가정합니다. 확인 전에 제품 라벨을 확인하세요.',
    'timeline.package_dose_retrieval_unknown': '기록되지 않음',
    'timeline.taken_at': '복용 시각',
    'timeline.edit_taken_at': '복용 시각 편집',
    'timeline.save_intake': '복용 저장',
    'timeline.no_medications': '사용 가능한 약물 카탈로그가 없습니다',
    'timeline.select_medication_first': '먼저 약물을 선택하세요',
    'timeline.save_intake_failed': '복용 저장 실패: {error}',
    'timeline.meal_macro_line':
        '합계: 단백질 {protein} g · 탄수 {carbs} g · 지방 {fat} g',
    'timeline.conflict_line': '충돌 검토: {severity} · 점수 {score}',
    'timeline.meal_window_line': '식사 시간 창: {start} - {end}',
    'timeline.next_meal_window_line': '다음 식사 창: {start} - {end}',
    'timeline.nearest_medication_line': '가장 가까운 약물: {name} ({distance})',
    'timeline.nearest_meal_line': '가장 가까운 식사: {title} ({distance})',
    'timeline.dosage_line': '용량: {value}',
    'timeline.before': '{value} 전',
    'timeline.after': '{value} 후',
    'timeline.no_context_flags': '보충제, 증점제, 경장영양 플래그 없음',
    'common.close': '닫기',
    'common.done': '완료',
    'common.cancel': '취소',
    'common.apply': '적용',
    'common.optional': '선택 사항',
    'analytics.local_ai_medical_model': '의료 검토 모델명',
    'common.delete': '삭제',
    'common.completed': '완료됨',
    'common.error': '오류',
    'common.search_results': '검색 결과',
    'common.no_matching_foods': '일치하는 음식이 없습니다',
    'common.texture': '질감',
    'common.not_available': '미입력',
    'common.save': '저장',
    'common.edit': '편집',
    'common.confirm': '확인',
    'common.sign_out': '로그아웃',
    'meal_slot.breakfast': '아침',
    'meal_slot.lunch': '점심',
    'meal_slot.dinner': '저녁',
    'meal_slot.snack': '간식',
    'meal.title': '식사',
    'meal.empty': '아직 기록된 식사가 없습니다',
    'meal.check_title': '식사 점검 - {title}',
    'medications.title': '약물',
    'catalog.title': '카탈로그',
    'catalog.search': '음식 또는 약물 검색',
    'catalog.foods': '음식',
    'catalog.drugs': '약물',
    'catalog.food_subtitle':
        '카테고리={category}  P/C/F={protein}/{carbs}/{fat} (100g당)',
    'catalog.drug_subtitle': '태그={tags}',
    'medications.view_detail': '약물 상세 보기',
    'decision.block': '차단',
    'decision.require_review': '검토 필요',
    'decision.discourage': '권장하지 않음',
    'decision.warn': '경고',
    'decision.info': '정보',
    'decision.allow': '허용',
    'decision.defer': '연기',
    'severity.low': '낮음',
    'severity.moderate': '중간',
    'severity.high': '높음',
    'severity.critical': '위급',
    'missing.dose': '용량',
    'missing.formulation': '제형',
    'missing.time': '약물 복용 시간',
    'missing.meal_time': '식사 시간',
    'missing.coevent_time': '동반 이벤트 시간',
    'missing.thickener_type': '증점제 종류',
    'recommend.low_protein': '저단백 우선',
    'recommend.protein_window_caution': '레보도파 시간 창 부근에서 고단백 섭취는 주의하세요',
    'recommend.history_low_protein': '최근 기록을 보면 저단백 옵션이 우선됩니다',
    'recommend.culture_match': '현재 지역 식단 템플릿과 일치합니다',
    'recommend.fallback_chain': '이 지역의 음식 지식은 폴백 체인을 사용 중입니다',
    'recommend.general_friendly': '일반적으로 적합한 옵션',
    'recommend.path.hybrid_local_ai': '로컬 AI 보조 재정렬',
    'recommend.path.conservative_safety_gate': '보수 경로 (안전 게이트가 AI 차단)',
    'recommend.path.conservative_gate_block': '보수 경로 (로컬 AI 사용 불가)',
    'recommend.path.fallback_invalid_ai': '보수 경로 (AI 출력 검증 실패)',
    'recommend.path.conservative_cdss': '보수 CDSS 경로',
    'recommend.runtime.local_ai_endpoint_unavailable':
        '로컬 호스트의 Ollama 또는 llama.cpp 서비스가 응답하지 않습니다. 로컬 모델 서비스를 시작하거나 로컬 AI 재정렬을 비활성화하세요.',
    'recommend.runtime.endpoint_must_be_localhost':
        '로컬 AI 엔드포인트는 localhost/127.0.0.1에 머물러야 하며 클라우드 엔드포인트를 가리킬 수 없습니다.',
    'recommend.runtime.safety_gate_conservative': '안전 게이트가 결과를 보수 경로에 유지했습니다.',
    'recommend.runtime.next_meal_window_missing':
        '예상 다음 식사 시간 창이 없습니다. 식사 추가/편집에서 가장 이른/늦은 다음 식사 시간을 추가하세요.',
    'recommend.runtime.no_prior_meal_history': '안전한 재정렬에 사용할 이전 식사 기록이 없습니다.',
    'recommend.runtime.legacy_meal_time':
        '최근 식사가 여전히 마이그레이션된 레거시 시간을 사용합니다. 실제 식사 시간으로 편집하세요.',
    'recommend.runtime.iron_conservative':
        '최근 식사에 철분 보충제가 기록되어 재정렬은 보수 모드를 유지합니다.',
    'recommend.runtime.iron_multivitamin_conservative':
        '최근 식사에 철분 함유 종합비타민이 기록되어 재정렬은 보수 모드를 유지합니다.',
    'recommend.runtime.starch_thickener_conservative':
        '최근 식사에 전분 기반 증점제가 기록되어 결정론적 안전 검토를 유지합니다.',
    'recommend.runtime.enteral_conservative':
        '지속적 경장영양 컨텍스트가 활성이라 결정론적 검토를 유지합니다.',
    'recommend.runtime.local_ai_not_consented':
        '로컬 AI 재정렬이 사용자에 의해 활성화되지 않았습니다.',
    'recommend.runtime.local_ai_unavailable': '로컬 AI 엔드포인트를 사용할 수 없습니다.',
    'recommend.runtime.returned_conservative': '대신 결정론적 보수 추천을 반환했습니다.',
    'recommend.runtime.ai_validation_failed':
        '로컬 AI 구조화 출력이 화이트리스트 검증에 실패했습니다.',
    'recommend.runtime.ai_invalid_whitelist':
        '로컬 AI가 화이트리스트만의 유효한 순서를 반환하지 않아 결과가 사용되지 않았습니다.',
    'recommend.runtime.cdss_conservative_observations':
        '보수 CDSS 경로는 가능한 경우 실제 변형 관찰을 사용했습니다.',
    'recommend.runtime.local_ai_success': '로컬 AI 재정렬 성공.',
    'recommend.runtime.local_ai_copy_polish_success': '로컬 AI가 문구를 다듬었습니다.',
    'recommend.runtime.medgemma_optional_unavailable':
        '로컬 AI 엔드포인트가 응답했지만 선택 사항인 MedGemma 모델은 사용할 수 없습니다.',
    'recommend.runtime.recommendation_conservative': '추천이 보수 경로에 유지되었습니다.',
    'recommend.runtime.levodopa_ai_sensitive': '레보도파 시간 창은 AI 재정렬에 너무 민감합니다.',
    'recommend.context_iron_supplement':
        '최근 식사에 철분 보충제가 기록되어 시간 안내가 보수 모드를 유지합니다.',
    'recommend.context_iron_multivitamin':
        '최근 식사에 철분 함유 종합비타민이 기록되어 시간 안내가 보수 모드를 유지합니다.',
    'recommend.context_starch_thickener': '전분 기반 증점제가 기록되어 삼킴 안전 우선순위가 높아집니다.',
    'recommend.context_xanthan_thickener': '최근 식사에 잔탄검 기반 증점제가 기록되었습니다.',
    'recommend.context_enteral_feed_continuous':
        '지속적 경장영양이 활성입니다 (단백질 {protein} g/일). 추천 표현을 보수적으로 유지합니다.',
    'recommend.context_enteral_feed_bolus': '최근 식사에 볼루스/간헐적 경장영양이 기록되었습니다.',
    'recommend.context_iron_penalty':
        '철분 관련 동반 이벤트가 있어 고단백 옵션의 순위가 보수적으로 낮춰집니다.',
    'recommend.context_enteral_penalty':
        '지속적 경장영양 컨텍스트가 있어 고단백 옵션의 순위가 보수적으로 낮춰집니다.',
    'recommend.context_texture_gap_penalty':
        '증점제가 기록되었지만 카탈로그에 구조화된 질감 호환성 데이터가 부족하므로 추가 보수 마진을 유지합니다.',
    'recommend.context_texture_supported':
        '증점제가 기록되었고 이 후보는 이미 구조화된 질감 메타데이터를 보유하므로 데이터 갭 페널티가 낮게 유지됩니다.',
    'recommend.texture_profile_missing':
        '질감 안전 모드가 활성이지만 이 후보에 구조화된 질감 메타데이터가 없어 순위가 더 보수적으로 유지됩니다.',
    'recommend.texture_profile_supported_soft_or_liquid':
        '이 후보는 현재의 부드러움/액체 질감 안전 모드와 일치합니다.',
    'recommend.texture_profile_supported_liquid_only':
        '이 후보는 현재의 액체 전용 질감 안전 모드와 일치합니다.',
    'recommend.texture_profile_incompatible':
        '이 후보는 현재 질감 안전 모드와 일치하지 않아 순위가 보수적으로 낮춰집니다.',
    'recommend.texture_template_supported': '이 후보는 현재 식사 템플릿의 질감 방향과 일치합니다.',
    'recommend.texture_template_mismatch': '이 후보는 현재 식사 템플릿의 질감 방향과 일치하지 않습니다.',
    'recommend.local_seed_metadata':
        '이 후보는 더 풍부한 데이터베이스 기반 관찰 대신 여전히 로컬 시드 메타데이터에 의존합니다.',
    'recommend.timing_window_incomplete':
        '시간 창이 불완전하여 보수적 순위가 추가 안전 마진을 유지합니다.',
    'recommend.next_meal_gap_close': '다음 식사 창이 이전 식사와 가까우므로 저단백 옵션이 선호됩니다.',
    'recommend.next_meal_window_fiber': '계획된 다음 식사 창에 적합하며 안정적인 섬유질 섭취가 선호됩니다.',
    'recommend.medication_timing_caution':
        '약물 복용 시간을 보면 이번 다음 식사 창에 추가 주의가 필요합니다.',
    'texture_mode.unrestricted': '제한 없음',
    'texture_mode.soft_or_liquid': '부드러움 또는 액체',
    'texture_mode.liquid_only': '액체 전용',
    'texture_class.liquid': '액체',
    'texture_class.soft': '부드러움',
    'texture_class.regular': '일반',
    'food.food_chicken_breast': '닭가슴살 (조리됨)',
    'food.food_tofu': '일반 두부',
    'food.food_brown_rice': '현미',
    'food.food_banana': '바나나',
    'food.food_spinach': '시금치',
    'food.food_milk': '저지방 우유',
    'food.food_beef': '살코기 소고기 (구운)',
    'food.food_apple': '사과 (껍질째)',
    'food.food_blueberry': '블루베리',
    'food.food_tomato': '토마토',
    'food.food_broccoli': '브로콜리',
    'food.food_oats': '롤드 오트',
    'food.food_salmon': '연어 (양식, 구운)',
    'food.food_fava_beans': '잠두콩 (생)',
    'food.food_potato_boiled': '감자 (삶은)',
    'food.food_walnuts': '호두',
    'food.food_olive_oil': '엑스트라 버진 올리브 오일',
    'food.food_cheddar_cheese': '체다 치즈',
    'food.food_egg_boiled': '계란 (삶은)',
    'food.food_coffee': '커피 (무가당, 추출)',
    'observatory.dependency_closure.title': '종속성 클로저 준비 상태',
    'observatory.dependency_closure.loading': '체크인된 루트 매니페스트 로드 중 · 클로저 HOLD',
    'observatory.dependency_closure.unavailable':
        'HOLD · 체크인된 루트 매니페스트를 사용할 수 없음',
    'observatory.dependency_closure.loading_semantics':
        '안정적인 알고리즘 결과 루트 매니페스트를 로드 중입니다. 종속성 클로저는 HOLD 상태입니다.',
    'observatory.dependency_closure.unavailable_semantics':
        '안정적인 알고리즘 결과 루트 매니페스트를 사용할 수 없습니다. 종속성 클로저는 HOLD 상태입니다.',
    'observatory.dependency_closure.semantics':
        '안정적으로 등록된 알고리즘 루트 {count}개입니다. Analyzer {analyzer}은 선언된 정확 버전 검토 대상입니다. 오프라인 호환성 근거는 이 화면에 번들되거나 실행되지 않습니다. 전이 종속성 클로저는 ParkinSUM 에지 생성기가 준비될 때까지 HOLD 상태입니다.',
    'observatory.dependency_closure.summary':
        '안정적인 루트 {count} / {total} · 선언된 Analyzer 대상 {analyzer} · 전이 클로저 HOLD',
    'observatory.dependency_closure.identity': '{schema} · {digest}… · {state}',
    'observatory.dependency_closure.registry_chip': 'Registry 매핑: 구조적으로 유효',
    'observatory.dependency_closure.edge_chip': '에지 생성기: HOLD',
    'observatory.dependency_closure.closure_chip': '순방향/역방향 클로저: HOLD',
    'observatory.dependency_closure.details': '접근 가능한 안정적 루트 표',
    'observatory.dependency_closure.details_subtitle':
        '기본 라이브러리 시드만 포함하며 생성된 종속성 에지는 없습니다.',
    'observatory.dependency_closure.table_semantics':
        '안정적인 알고리즘 루트 표입니다. 열은 알고리즘, 논리적 루트, 결과 싱크, 정규 패키지 URI입니다.',
    'observatory.dependency_closure.column_algorithm': '알고리즘',
    'observatory.dependency_closure.column_root': '논리적 루트',
    'observatory.dependency_closure.column_sink': '결과 싱크',
    'observatory.dependency_closure.column_uri': '패키지 URI',
    'observatory.dependency_closure.boundary':
        '이 화면은 체크인된 Registry-루트 구조 계약만 입증합니다. 오프라인 Analyzer 호환성 근거는 여기에 번들되거나 실행되지 않습니다. 호출 그래프, SCC, 순방향/역방향 클로저, 실행, 정확한 데이터 흐름, 과학적 또는 임상적 검증, 안전성, 이점 또는 의학적 조언을 표시하거나 주장하지 않습니다.',
  },

  // ===========================================================================
  // hi (Hindi)
  // ===========================================================================
  'hi': {
    'reminders.locale_reconciliation_title': 'सिस्टम रिमाइंडर की भाषा अलग है',
    'reminders.locale_reconciliation_body':
        'ऐप की भाषा बदल गई है। मौजूदा सिस्टम रिमाइंडर भाषा रखें या इस डिवाइस के सभी रिमाइंडर एक साथ अपडेट करें। किसी विकल्प में आपके लिखे लेबल नहीं दिखते।',
    'reminders.locale_retain_action': 'मौजूदा भाषा रखें',
    'reminders.locale_update_action': 'सभी को वर्तमान भाषा में करें',
    'reminders.locale_retained_confirmation':
        'मौजूदा सिस्टम रिमाइंडर भाषा रखी गई।',
    'reminders.locale_updated_confirmation':
        'सभी सिस्टम रिमाइंडर वर्तमान भाषा में अपडेट करने का अनुरोध किया गया।',
    'diagnostics.title': 'इंजीनियरिंग डायग्नोस्टिक्स',
    'diagnostics.rerun': 'जाँच फिर से चलाएँ',
    'diagnostics.scope_title': 'केवल इंजीनियरिंग समीक्षा',
    'diagnostics.scope_body':
        'ये नियतात्मक गवर्नेंस जाँचें हैं (कॉपी संकलन, स्थानीयकरण सुरक्षा लिंट, सिंथेटिक परिदृश्य रीप्ले)। ये केवल इंजीनियरिंग स्थिति बताती हैं: ये किसी स्कोर, गंभीरता, प्रमाण या नियम परिणाम को नहीं बदलतीं, और ये स्वास्थ्य मार्गदर्शन नहीं हैं। केवल सिंथेटिक/डेमो डेटा।',
    'diagnostics.elapsed': 'जाँचें {ms} ms में पूरी हुईं।',
    'reminders.identity_attestation_title':
        'प्लगइन द्वारा बताई गई लंबित पहचान की जाँच',
    'reminders.identity_attestation_matched':
        'प्लगइन द्वारा बताई गई लंबित पहचान योजना से मेल खाती हैं ({installed}/{planned})। यह ऑपरेटिंग सिस्टम शेड्यूलर या दिखाई देने वाली डिलीवरी का स्वतंत्र सत्यापन नहीं है।',
    'reminders.identity_attestation_drift':
        'प्लगइन की पहचान योजना से अलग है: {missing} गायब, {extra} अतिरिक्त और नियोजित ID पर {replaced} बदली हुई। दोबारा समन्वय सफल होने तक सिस्टम रिमाइंडर पर निर्भर न रहें।',
    'reminders.identity_attestation_uninspectable':
        'प्लगइन से लंबित अनुरोध की पहचान नहीं पढ़ी जा सकी। स्थानीय योजना प्रामाणिक है, लेकिन सिस्टम रिमाइंडर की स्थिति अप्रमाणित है।',
    'reminders.error_schedule_identity_unverified':
        'स्थानीय योजना सहेजी गई, लेकिन प्लगइन की लंबित पहचान उससे नहीं मिल सकी। सिस्टम रिमाइंडर पर निर्भर होने से पहले फिर समन्वय करें।',
    'reminders.readiness_title': 'सिस्टम रिमाइंडर डिलीवरी की तैयारी',
    'reminders.readiness_contract': '{platform} क्षमता अनुबंध · {digest}',
    'reminders.readiness_boundary':
        'पूरा हुआ शेड्यूल अनुरोध या मेल खाती प्लगइन पहचान दिखाई देने वाली, लॉक स्क्रीन या पृष्ठभूमि डिलीवरी को साबित नहीं करती।',
    'reminders.readiness_platform_android': 'Android',
    'reminders.readiness_platform_ios': 'iOS',
    'reminders.readiness_platform_macos': 'macOS',
    'reminders.readiness_platform_web': 'Web',
    'reminders.readiness_platform_windows': 'Windows',
    'reminders.readiness_platform_linux': 'Linux',
    'reminders.readiness_platform_unknown': 'अज्ञात प्लेटफ़ॉर्म या कस्टम गेटवे',
    'reminders.readiness_local_plan': 'स्थानीय योजना',
    'reminders.readiness_adapter': 'शेड्यूलिंग अडैप्टर',
    'reminders.readiness_schedule_request': 'शेड्यूल अनुरोध',
    'reminders.readiness_permission_request': 'अनुमति अनुरोध',
    'reminders.readiness_permission_inspection':
        'वर्तमान अनुमति स्थिति की जाँच',
    'reminders.readiness_registry': 'प्लगइन लंबित रजिस्ट्री',
    'reminders.readiness_visible_delivery': 'दिखाई देने वाली डिलीवरी',
    'reminders.readiness_body_tap': 'सूचना के मुख्य भाग पर टैप',
    'reminders.readiness_cold_start': 'सूचना से कोल्ड स्टार्ट',
    'reminders.readiness_background_action': 'पृष्ठभूमि कार्रवाई',
    'reminders.readiness_local_none': 'कोई स्थानीय योजना कॉन्फ़िगर नहीं है',
    'reminders.readiness_local_saved': 'इस डिवाइस पर सहेजी गई',
    'reminders.readiness_adapter_plan_only':
        'केवल योजना; सिस्टम सूचना API नहीं बुलाई जाती',
    'reminders.readiness_evidence_artifact_verified':
        'लक्ष्य प्लेटफ़ॉर्म से बंधे आर्टिफ़ैक्ट प्रमाण से सत्यापित',
    'reminders.readiness_evidence_implemented_unverified':
        'लागू; लक्ष्य डिवाइस पर आर्टिफ़ैक्ट से बंधा सत्यापन नहीं है',
    'reminders.readiness_evidence_unavailable': 'अनुपलब्ध या लागू नहीं',
    'reminders.readiness_request_not_requested': 'नहीं भेजा गया',
    'reminders.readiness_request_applied':
        'प्लगइन अनुरोध पूरा हुआ; डिलीवरी साबित नहीं हुई',
    'reminders.readiness_request_rolled_back':
        'नया शेड्यूल अनुरोध वापस लिया गया और पुरानी योजना बहाल हुई; डिलीवरी साबित नहीं हुई',
    'reminders.readiness_request_superseded':
        'नए खाते या योजना ने इसे प्रतिस्थापित किया',
    'reminders.readiness_request_unsupported': 'यह अनुबंध केवल योजना के लिए है',
    'reminders.readiness_request_failed': 'अनुरोध विफल या पहचान असत्यापित',
    'reminders.readiness_request_recovery_required':
        'निर्भर होने से पहले मिलान आवश्यक है',
    'reminders.readiness_permission_not_requested':
        'इस सत्र में अनुरोध नहीं किया गया',
    'reminders.readiness_permission_granted':
        'अनुमति अनुरोध कॉल ने अनुमति लौटाई; यह वर्तमान स्थिति के बराबर नहीं है',
    'reminders.readiness_permission_denied':
        'अनुमति अनुरोध कॉल ने अनुमति नहीं लौटाई; यह उपयोगकर्ता के स्पष्ट इनकार का प्रमाण नहीं है',
    'reminders.readiness_permission_failed':
        'अनुमति अनुरोध विफल या अडैप्टर अनुपलब्ध; इसका अर्थ उपयोगकर्ता का इनकार नहीं है',
    'reminders.readiness_permission_unavailable':
        'यह क्षमता अनुबंध अनुमति का अनुरोध नहीं करता',
    'reminders.readiness_inspection_not_inspected':
        'वर्तमान अनुमति स्थिति की जाँच नहीं हुई',
    'reminders.readiness_inspection_enabled':
        'प्लगइन की वर्तमान जाँच ने सक्षम बताया; यह डिलीवरी का प्रमाण नहीं है',
    'reminders.readiness_inspection_disabled':
        'प्लगइन की वर्तमान जाँच ने अक्षम बताया; कारण या उपयोगकर्ता की पसंद ज्ञात नहीं है',
    'reminders.readiness_inspection_unavailable':
        'वर्तमान अनुमति स्थिति की जाँच अनुपलब्ध; इसका अर्थ उपयोगकर्ता का इनकार नहीं है',
    'reminders.readiness_inspection_failed':
        'वर्तमान अनुमति स्थिति की जाँच विफल; इसका अर्थ उपयोगकर्ता का इनकार नहीं है',
    'reminders.readiness_registry_not_inspected': 'जाँच नहीं की गई',
    'reminders.readiness_registry_matched':
        'प्लगइन रिपोर्ट स्थानीय योजना से मेल खाती है; यह OS डिलीवरी का प्रमाण नहीं है',
    'reminders.readiness_registry_drift':
        'प्लगइन रिपोर्ट स्थानीय योजना से अलग है',
    'reminders.readiness_registry_uninspectable':
        'प्लगइन पहचान पढ़ी नहीं जा सकीं',
    'reminders.readiness_registry_unsupported':
        'यह क्षमता अनुबंध नेटिव रजिस्ट्री की जाँच नहीं करता',
    'reminders.readiness_visible_unverified': 'असत्यापित',
    'reminders.readiness_visible_artifact_verified':
        'लक्ष्य प्लेटफ़ॉर्म के आर्टिफ़ैक्ट प्रमाण से सत्यापित',
    'app.welcome': 'स्वागत है',
    'app.loading': 'लोड हो रहा है...',
    'onboarding.title': 'ParkinSUM साथी (स्थानीय संस्करण)',
    'onboarding.description':
        'यह ऐप केवल भोजन रिकॉर्डिंग और नियम-आधारित मार्गदर्शन के लिए है। यह आपके चिकित्सक या फार्मासिस्ट की सलाह की जगह नहीं ले सकता।',
    'onboarding.registration_region': 'पंजीकरण क्षेत्र',
    'onboarding.registration_region_help':
        'डिफ़ॉल्ट क्षेत्राधिकार श्रृंखला और स्रोत प्राथमिकता निर्धारित करता है।',
    'onboarding.display_language': 'प्रदर्शन भाषा',
    'onboarding.display_language_help':
        'ऐप भाषा, दिनांक और संख्या स्वरूपण को नियंत्रित करता है।',
    'onboarding.diet_profile_region': 'आहार प्रोफ़ाइल क्षेत्र',
    'onboarding.diet_profile_region_help':
        'सुरक्षा नियमों को बदले बिना डिफ़ॉल्ट भोजन टेम्पलेट के लिए उपयोग किया जाता है।',
    'onboarding.swallowing_texture_mode': 'निगलना / बनावट सुरक्षा मोड',
    'onboarding.swallowing_texture_mode_help':
        'नैदानिक निगलने के मूल्यांकन के बजाय एक रूढ़िवादी सिफारिश प्राथमिकता के रूप में उपयोग किया जाता है।',
    'onboarding.content_override': 'सामग्री क्षेत्राधिकार ओवरराइड (वैकल्पिक)',
    'onboarding.content_override_help': 'अल्पविराम से अलग, जैसे US,CA',
    'onboarding.local_ai_consent': 'स्थानीय AI पुनर्क्रम सक्षम करें (वैकल्पिक)',
    'onboarding.local_ai_consent_help':
        'केवल localhost Ollama/llama.cpp का उपयोग करता है और जब सुरक्षा गेट इसे रोकते हैं तो रूढ़िवादी पथ पर वापस गिर जाता है।',
    'onboarding.start': 'मैं समझ गया, जारी रखें',
    'nav.home': 'होम',
    'nav.analytics': 'विश्लेषण',
    'nav.meals': 'भोजन',
    'nav.timeline': 'समयरेखा',
    'nav.meds': 'दवाइयाँ',
    'nav.catalog': 'सूची',
    'nav.next_meal': 'अगला भोजन',
    'shell.tagline': 'साथी ऐप · शोध प्रोटोटाइप',
    'shell.workspace': 'कार्यक्षेत्र',
    'shell.care_workspace': 'मुलाक़ात की तैयारी और फ़ॉलो-अप',
    'shell.boundary_note':
        'शैक्षिक प्रोटोटाइप — यह चिकित्सा सलाह नहीं है। स्वास्थ्य संबंधी निर्णय किसी योग्य चिकित्सक से जाँचें।',
    'dashboard.greeting_morning': 'सुप्रभात',
    'dashboard.greeting_afternoon': 'नमस्कार',
    'dashboard.greeting_evening': 'शुभ संध्या',
    'dashboard.subtitle':
        'आपके दर्ज भोजन, दवा सेवन और हर व्याख्या के पीछे के नियमों का अवलोकन।',
    'dashboard.stat_meals': 'दर्ज भोजन',
    'dashboard.stat_drugs': 'सक्रिय दवाएँ',
    'dashboard.stat_intakes': 'दर्ज दवा सेवन',
    'shell.new_entry': 'नई प्रविष्टि',
    'shell.search': 'खोजें',
    'shell.search_hint': 'पेज, टूल और क्रियाएँ खोजें',
    'shell.search_empty': 'कोई मेल खाता पेज, टूल या क्रिया नहीं मिली',
    'shell.menu': 'मेनू',
    'shell.group.evidence': 'साक्ष्य और नियम',
    'shell.group.data': 'आपका डेटा',
    'shell.group.operations': 'संचालन',
    'shell.group.pages': 'पेज',
    'shell.action.observation': 'अवलोकन दर्ज करें',
    'dashboard.stat_protein': 'प्रति भोजन औसत प्रोटीन',
    'dashboard.show_details': 'विवरण दिखाएँ',
    'dashboard.hide_details': 'विवरण छिपाएँ',
    'dashboard.quick_log': 'त्वरित प्रविष्टि',
    'dashboard.today': 'हाल की गतिविधि',
    'insights.title': 'अंतर्दृष्टि',
    'insights.subtitle': 'केवल आपकी अपनी प्रविष्टियों से दिखने वाले पैटर्न।',
    'insights.range_7': '7 दिन',
    'insights.range_30': '30 दिन',
    'insights.meals': 'भोजन',
    'insights.intakes': 'दवा सेवन',
    'insights.observations': 'अवलोकन',
    'insights.avg_protein': 'प्रति भोजन औसत प्रोटीन',
    'insights.rhythm_title': 'प्रविष्टि की लय',
    'insights.rhythm_subtitle': 'प्रति दिन प्रविष्टियाँ',
    'insights.protein_title': 'प्रति भोजन प्रोटीन',
    'insights.protein_subtitle': 'दर्ज भोजन के ग्राम, पुराने से नए',
    'insights.daypart_title': 'दिन का समय',
    'insights.daypart_subtitle': 'भोजन और दवा सेवन कब दर्ज हुए',
    'insights.morning': 'सुबह',
    'insights.midday': 'दोपहर',
    'insights.evening': 'शाम',
    'insights.night': 'रात',
    'insights.empty': 'इस अवधि में अभी कुछ दर्ज नहीं है।',
    'insights.boundary':
        'ये आपकी अपनी प्रविष्टियों के वर्णनात्मक सारांश हैं। ये नैदानिक माप, लक्ष्य या सलाह नहीं हैं; स्वास्थ्य संबंधी निर्णय किसी योग्य चिकित्सक से जाँचें।',
    'settings.local_ai_advanced': 'उन्नत · स्थानीय AI कनेक्शन',
    'nav.today': 'आज',
    'nav.library': 'लाइब्रेरी',
    'dashboard.log_prompt': 'आप क्या दर्ज करना चाहेंगे?',
    'dashboard.log_meal_hint': 'खाद्य और मात्रा, शैक्षिक नियमों से जाँचे गए',
    'dashboard.log_intake_hint': 'ली गई दवा की एक खुराक',
    'dashboard.log_observation_hint': 'रक्तचाप, लक्षण या गति की स्थिति',
    'dashboard.open_timeline': 'टाइमलाइन खोलें',
    'dashboard.open_next_meal': 'अगला भोजन खोलें',
    'library.my_medications': 'मेरी दवाएँ',
    'library.catalog': 'खाद्य और दवाएँ',
    'next_meal.title': 'अगले भोजन की सिफारिश',
    'next_meal.subtitle':
        'अगले भोजन का समय चुनें। रूढ़िवादी नियम-पथ उम्मीदवारों का क्रम बनाए रखता है; यांत्रिक मॉडल केवल शैक्षिक समय-अतिव्यापन ट्रेस जोड़ता है और क्रम नहीं बदलता। स्थानीय AI अलग, वैकल्पिक सुरक्षित-सूची पुनर्क्रमण है।',
    'next_meal.input_time': 'अगले भोजन का अनुमानित समय',
    'next_meal.use_local_ai': 'स्थानीय AI से शब्द निखारें (वैकल्पिक)',
    'next_meal.use_local_ai_help':
        'केवल localhost पर Ollama/llama.cpp को बुलाता है ताकि इंजन द्वारा पहले से स्वीकृत उम्मीदवारों को पुनर्क्रमित और स्पष्टीकरण लिख सके; सुरक्षा गेट के अवरुद्ध होने पर रूढ़िवादी पथ पर लौटता है।',
    'next_meal.generate': 'सिफारिश बनाएँ',
    'next_meal.generating': 'बनाई जा रही है…',
    'next_meal.empty':
        'अनुमानित समय निर्धारित करें और "सिफारिश बनाएँ" टैप करें; इंजन उस विंडो के अनुसार पुनः मूल्यांकन करेगा।',
    'next_meal.why_these': 'ये क्यों चुने गए',
    'next_meal.ai_polished': 'स्थानीय AI ने शब्द निखारे',
    'next_meal.conservative_engine': 'संघर्ष इंजन का रूढ़िवादी पथ',
    'next_meal.recommendation_path': 'सिफारिश पथ',
    'next_meal.gate_reasons': 'सुरक्षा गेट नोट्स',
    'next_meal.candidates': 'शीर्ष उम्मीदवार',
    'next_meal.no_candidates':
        'वर्तमान बाधाओं में कोई उपयुक्त उम्मीदवार नहीं। अनुमानित समय बदलें या भोजन सूची विस्तृत करें।',
    'next_meal.error': 'निर्माण विफल',
    'dashboard.title': 'डैशबोर्ड',
    'dashboard.status': 'अवलोकन',
    'dashboard.logged_meals': 'दर्ज भोजन: {count}',
    'dashboard.active_drugs': 'सक्रिय दवाइयाँ: {count}',
    'dashboard.logged_intakes': 'दवा सेवन: {count}',
    'dashboard.recommendations': 'सिफारिशें',
    'dashboard.no_recommendations': 'अभी कोई सिफारिश नहीं',
    'dashboard.recommendation_path': 'सिफारिश पथ',
    'dashboard.recommendation_template':
        'सक्रिय टेम्पलेट: {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'स्थानीय AI सुधार उपयोग किया गया',
    'dashboard.ai_not_used': 'केवल रूढ़िवादी पथ',
    'dashboard.recommendation_why': 'ये सिफारिशें क्यों',
    'dashboard.recommendation_gate': 'AI / सुरक्षा गेट स्थिति',
    'dashboard.recommendation_macro_line':
        'प्रति 100g: P {protein} g · C {carbs} g · F {fat} g',
    'dashboard.recommendation_score_line':
        'सुरक्षा {safety} · समय {schedule} · तथ्य {facts} · संदर्भ दंड {context} · विंडो दंड {timing} · निगलना दंड {swallowing} · टेम्पलेट मेल {template}',
    'dashboard.recent_meals': 'हाल के भोजन (नवीनतम 5)',
    'dashboard.no_meals': 'अभी कोई भोजन दर्ज नहीं',
    'dashboard.items': '{count} आइटम',
    'dashboard.meal_context_iron_supplement': 'आयरन पूरक सह-घटना',
    'dashboard.meal_context_iron_multivitamin':
        'आयरन युक्त मल्टीविटामिन सह-घटना',
    'dashboard.meal_context_starch_thickener': 'स्टार्च-आधारित गाढ़ा करने वाला',
    'dashboard.meal_context_xanthan_thickener': 'ज़ैंथन-आधारित गाढ़ा करने वाला',
    'dashboard.meal_context_enteral_feed_continuous':
        'निरंतर एंटरल पोषण ({protein} g/दिन प्रोटीन)',
    'dashboard.meal_context_enteral_feed_bolus': 'बोलस / आंतरायिक एंटरल पोषण',
    'dashboard.edit': 'संपादित करें',
    'dashboard.delete': 'हटाएँ',
    'dashboard.protein_trend': 'प्रोटीन प्रवृत्ति',
    'dashboard.average_protein': 'औसत प्रोटीन: {value} g / भोजन',
    'dashboard.no_trend': 'अभी कोई प्रवृत्ति डेटा नहीं',
    'dashboard.timeline': 'समयरेखा',
    'dashboard.no_timeline': 'अभी तक कोई भोजन या दवा घटना नहीं',
    'dashboard.add_meal': 'भोजन जोड़ें',
    'dashboard.meal_check': 'भोजन जाँच - {title}',
    'timeline.title': 'भोजन और दवा समयरेखा',
    'timeline.empty': 'अभी तक कोई भोजन या दवा सेवन नहीं',
    'timeline.add_meal': 'भोजन जोड़ें',
    'timeline.add_intake': 'दवा दर्ज करें',
    'timeline.new_intake': 'नई दवा सेवन',
    'timeline.edit_intake': 'दवा सेवन संपादित करें',
    'timeline.medication': 'दवा',
    'timeline.active_medication_option': '{name} (सक्रिय)',
    'timeline.dosage_note': 'खुराक नोट',
    'timeline.package_dose_source':
        'स्रोत: {source} · प्राप्त: {retrieved} · {url}',
    'timeline.package_dose_derivation':
        'गणना: {strength} × {quantity} {unit} = {amount} {resultUnit}',
    'timeline.package_dose_assumed_denominator':
        'स्रोत में हर नहीं दिया गया; एक अलग खुराक इकाई ({unit}) मानकर गणना की गई है। पुष्टि से पहले उत्पाद लेबल जाँचें।',
    'timeline.package_dose_retrieval_unknown': 'दर्ज नहीं',
    'timeline.taken_at': 'लिया गया',
    'timeline.edit_taken_at': 'लिए जाने का समय संपादित करें',
    'timeline.save_intake': 'सेवन सहेजें',
    'timeline.no_medications': 'कोई दवा सूची उपलब्ध नहीं',
    'timeline.select_medication_first': 'पहले एक दवा चुनें',
    'timeline.save_intake_failed': 'सेवन सहेजने में विफल: {error}',
    'timeline.meal_macro_line':
        'कुल: प्रोटीन {protein} g · कार्ब्स {carbs} g · वसा {fat} g',
    'timeline.conflict_line': 'संघर्ष समीक्षा: {severity} · स्कोर {score}',
    'timeline.meal_window_line': 'भोजन विंडो: {start} - {end}',
    'timeline.next_meal_window_line': 'अगला भोजन विंडो: {start} - {end}',
    'timeline.nearest_medication_line': 'निकटतम दवा: {name} ({distance})',
    'timeline.nearest_meal_line': 'निकटतम भोजन: {title} ({distance})',
    'timeline.dosage_line': 'खुराक: {value}',
    'timeline.before': '{value} पहले',
    'timeline.after': '{value} बाद',
    'timeline.no_context_flags':
        'कोई पूरक, गाढ़ा करने वाला, या एंटरल पोषण फ्लैग नहीं',
    'common.close': 'बंद करें',
    'common.done': 'हो गया',
    'common.cancel': 'रद्द करें',
    'common.apply': 'लागू करें',
    'common.optional': 'वैकल्पिक',
    'analytics.local_ai_medical_model': 'चिकित्सा समीक्षा मॉडल नाम',
    'common.delete': 'हटाएँ',
    'common.completed': 'पूर्ण',
    'common.error': 'त्रुटि',
    'common.search_results': 'खोज परिणाम',
    'common.no_matching_foods': 'कोई मेल खाता भोजन नहीं मिला',
    'common.texture': 'बनावट',
    'common.not_available': 'दर्ज नहीं किया गया',
    'common.save': 'सहेजें',
    'common.edit': 'संपादित करें',
    'common.confirm': 'पुष्टि करें',
    'common.sign_out': 'साइन आउट',
    'meal_slot.breakfast': 'नाश्ता',
    'meal_slot.lunch': 'दोपहर का भोजन',
    'meal_slot.dinner': 'रात का भोजन',
    'meal_slot.snack': 'हल्का नाश्ता',
    'meal.title': 'भोजन',
    'meal.empty': 'अभी कोई भोजन दर्ज नहीं',
    'meal.check_title': 'भोजन जाँच - {title}',
    'medications.title': 'दवाइयाँ',
    'catalog.title': 'सूची',
    'catalog.search': 'भोजन या दवा खोजें',
    'catalog.foods': 'भोजन',
    'catalog.drugs': 'दवाइयाँ',
    'catalog.food_subtitle':
        'श्रेणी={category}  P/C/F={protein}/{carbs}/{fat} (प्रति 100g)',
    'catalog.drug_subtitle': 'टैग={tags}',
    'medications.view_detail': 'दवा विवरण देखें',
    'decision.block': 'अवरुद्ध करें',
    'decision.require_review': 'समीक्षा आवश्यक',
    'decision.discourage': 'हतोत्साहित करें',
    'decision.warn': 'चेतावनी',
    'decision.info': 'जानकारी',
    'decision.allow': 'अनुमति दें',
    'decision.defer': 'स्थगित करें',
    'severity.low': 'कम',
    'severity.moderate': 'मध्यम',
    'severity.high': 'उच्च',
    'severity.critical': 'गंभीर',
    'missing.dose': 'खुराक',
    'missing.formulation': 'सूत्रीकरण',
    'missing.time': 'दवा का समय',
    'missing.meal_time': 'भोजन का समय',
    'missing.coevent_time': 'सह-घटना का समय',
    'missing.thickener_type': 'गाढ़ा करने वाले का प्रकार',
    'recommend.low_protein': 'कम प्रोटीन को प्राथमिकता',
    'recommend.protein_window_caution':
        'लेवोडोपा विंडो के पास उच्च प्रोटीन से सावधान रहें',
    'recommend.history_low_protein':
        'हालिया इतिहास कम-प्रोटीन विकल्पों को प्राथमिकता देने का सुझाव देता है',
    'recommend.culture_match': 'वर्तमान क्षेत्रीय आहार टेम्पलेट से मेल खाता है',
    'recommend.fallback_chain':
        'इस क्षेत्र के लिए भोजन ज्ञान फॉलबैक श्रृंखला का उपयोग कर रहा है',
    'recommend.general_friendly': 'सामान्यतः उपयुक्त विकल्प',
    'recommend.path.hybrid_local_ai': 'स्थानीय AI सहायता पुनर्क्रम',
    'recommend.path.conservative_safety_gate':
        'रूढ़िवादी पथ (सुरक्षा गेट ने AI रोका)',
    'recommend.path.conservative_gate_block':
        'रूढ़िवादी पथ (स्थानीय AI अनुपलब्ध)',
    'recommend.path.fallback_invalid_ai':
        'रूढ़िवादी पथ (AI आउटपुट सत्यापन में विफल)',
    'recommend.path.conservative_cdss': 'रूढ़िवादी CDSS पथ',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'किसी localhost Ollama या llama.cpp सेवा ने प्रतिक्रिया नहीं दी। स्थानीय मॉडल सेवा शुरू करें, या स्थानीय AI पुनर्क्रम अक्षम करें।',
    'recommend.runtime.endpoint_must_be_localhost':
        'स्थानीय AI एंडपॉइंट localhost/127.0.0.1 पर ही रहना चाहिए और क्लाउड एंडपॉइंट की ओर इशारा नहीं कर सकता।',
    'recommend.runtime.safety_gate_conservative':
        'सुरक्षा गेट ने परिणाम को रूढ़िवादी पथ पर रखा।',
    'recommend.runtime.next_meal_window_missing':
        'अपेक्षित अगले भोजन समय विंडो गुम है। भोजन जोड़ें/संपादित करें में जल्द से जल्द और सबसे देर से अगले भोजन का समय जोड़ें।',
    'recommend.runtime.no_prior_meal_history':
        'सुरक्षित पुनर्क्रम के लिए कोई पूर्व भोजन इतिहास उपलब्ध नहीं है।',
    'recommend.runtime.legacy_meal_time':
        'नवीनतम भोजन अभी भी माइग्रेट किए गए लेगेसी समय का उपयोग करता है; इसे वास्तविक भोजन समय में संपादित करें।',
    'recommend.runtime.iron_conservative':
        'नवीनतम भोजन में आयरन पूरक दर्ज था, इसलिए पुनर्क्रम रूढ़िवादी रहता है।',
    'recommend.runtime.iron_multivitamin_conservative':
        'नवीनतम भोजन में आयरन युक्त मल्टीविटामिन दर्ज था, इसलिए पुनर्क्रम रूढ़िवादी रहता है।',
    'recommend.runtime.starch_thickener_conservative':
        'नवीनतम भोजन में स्टार्च-आधारित गाढ़ा करने वाला दर्ज था, इसलिए नियतात्मक सुरक्षा समीक्षा रखी जाती है।',
    'recommend.runtime.enteral_conservative':
        'निरंतर एंटरल पोषण संदर्भ सक्रिय है, इसलिए नियतात्मक समीक्षा रखी जाती है।',
    'recommend.runtime.local_ai_not_consented':
        'उपयोगकर्ता द्वारा स्थानीय AI पुनर्क्रम सक्षम नहीं किया गया है।',
    'recommend.runtime.local_ai_unavailable':
        'स्थानीय AI एंडपॉइंट वर्तमान में अनुपलब्ध है।',
    'recommend.runtime.returned_conservative':
        'इसके बजाय नियतात्मक रूढ़िवादी सिफारिशें लौटाईं।',
    'recommend.runtime.ai_validation_failed':
        'स्थानीय AI संरचित आउटपुट व्हाइटलिस्ट सत्यापन में विफल।',
    'recommend.runtime.ai_invalid_whitelist':
        'स्थानीय AI ने वैध केवल-व्हाइटलिस्ट क्रम नहीं लौटाया, इसलिए परिणाम का उपयोग नहीं किया गया।',
    'recommend.runtime.cdss_conservative_observations':
        'रूढ़िवादी CDSS पथ ने उपलब्ध होने पर वास्तविक प्रकार अवलोकनों का उपयोग किया।',
    'recommend.runtime.local_ai_success': 'स्थानीय AI पुनर्क्रम सफल।',
    'recommend.runtime.local_ai_copy_polish_success':
        'स्थानीय AI ने भाषा को सरल बनाया।',
    'recommend.runtime.medgemma_optional_unavailable':
        'स्थानीय AI एंडपॉइंट ने जवाब दिया; वैकल्पिक MedGemma मॉडल उपलब्ध नहीं है।',
    'recommend.runtime.recommendation_conservative':
        'सिफारिश रूढ़िवादी पथ पर बनी रही।',
    'recommend.runtime.levodopa_ai_sensitive':
        'लेवोडोपा समय विंडो AI पुनर्क्रम के लिए बहुत संवेदनशील है।',
    'recommend.context_iron_supplement':
        'नवीनतम भोजन में आयरन पूरक दर्ज था, इसलिए समय मार्गदर्शन रूढ़िवादी रहता है।',
    'recommend.context_iron_multivitamin':
        'नवीनतम भोजन में आयरन युक्त मल्टीविटामिन दर्ज था, इसलिए समय मार्गदर्शन रूढ़िवादी रहता है।',
    'recommend.context_starch_thickener':
        'स्टार्च-आधारित गाढ़ा करने वाला दर्ज है, जो निगलने की सुरक्षा प्राथमिकता बढ़ाता है।',
    'recommend.context_xanthan_thickener':
        'नवीनतम भोजन के लिए ज़ैंथन-आधारित गाढ़ा करने वाला दर्ज था।',
    'recommend.context_enteral_feed_continuous':
        'निरंतर एंटरल पोषण सक्रिय है ({protein} g/दिन प्रोटीन), इसलिए सिफारिश शब्दाडंबर रूढ़िवादी रहता है।',
    'recommend.context_enteral_feed_bolus':
        'नवीनतम भोजन के लिए बोलस/आंतरायिक एंटरल पोषण दर्ज था।',
    'recommend.context_iron_penalty':
        'आयरन से संबंधित सह-घटनाएँ मौजूद हैं, इसलिए उच्च प्रोटीन विकल्पों का रैंक रूढ़िवादी रूप से कम रहता है।',
    'recommend.context_enteral_penalty':
        'निरंतर एंटरल पोषण संदर्भ मौजूद है, इसलिए उच्च प्रोटीन विकल्पों का रैंक रूढ़िवादी रूप से कम रहता है।',
    'recommend.context_texture_gap_penalty':
        'गाढ़ा करने वाला दर्ज था, परंतु वर्तमान सूची में अभी संरचित बनावट संगतता डेटा नहीं है, इसलिए अतिरिक्त रूढ़िवादी मार्जिन रखी जाती है।',
    'recommend.context_texture_supported':
        'गाढ़ा करने वाला दर्ज था, और इस उम्मीदवार के पास पहले से संरचित बनावट मेटाडेटा है, इसलिए डेटा-अंतर दंड कम रहता है।',
    'recommend.texture_profile_missing':
        'बनावट सुरक्षा मोड सक्रिय है, परंतु इस उम्मीदवार के पास संरचित बनावट मेटाडेटा नहीं है, इसलिए रैंकिंग अधिक रूढ़िवादी रहती है।',
    'recommend.texture_profile_supported_soft_or_liquid':
        'यह उम्मीदवार वर्तमान मुलायम-या-तरल बनावट सुरक्षा मोड से मेल खाता है।',
    'recommend.texture_profile_supported_liquid_only':
        'यह उम्मीदवार वर्तमान केवल-तरल बनावट सुरक्षा मोड से मेल खाता है।',
    'recommend.texture_profile_incompatible':
        'यह उम्मीदवार वर्तमान बनावट सुरक्षा मोड से मेल नहीं खाता, इसलिए रूढ़िवादी रूप से रैंक कम है।',
    'recommend.texture_template_supported':
        'यह उम्मीदवार वर्तमान भोजन-टेम्पलेट बनावट दिशा से मेल खाता है।',
    'recommend.texture_template_mismatch':
        'यह उम्मीदवार वर्तमान भोजन-टेम्पलेट बनावट दिशा से मेल नहीं खाता।',
    'recommend.local_seed_metadata':
        'यह उम्मीदवार अभी भी समृद्ध डेटाबेस-समर्थित अवलोकनों के बजाय स्थानीय बीज मेटाडेटा पर निर्भर है।',
    'recommend.timing_window_incomplete':
        'समय विंडो अधूरी है, इसलिए रूढ़िवादी रैंकिंग अतिरिक्त सुरक्षा मार्जिन रखती है।',
    'recommend.next_meal_gap_close':
        'अगला भोजन विंडो अभी भी पिछले भोजन के निकट है; कम-प्रोटीन विकल्प को प्राथमिकता है।',
    'recommend.next_meal_window_fiber':
        'यह नियोजित अगले भोजन विंडो में फिट बैठता है और स्थिर फाइबर सेवन को बढ़ावा देता है।',
    'recommend.medication_timing_caution':
        'दवा का समय इस अगले भोजन विंडो के लिए अतिरिक्त सावधानी का सुझाव देता है।',
    'texture_mode.unrestricted': 'अप्रतिबंधित',
    'texture_mode.soft_or_liquid': 'मुलायम या तरल',
    'texture_mode.liquid_only': 'केवल तरल',
    'texture_class.liquid': 'तरल',
    'texture_class.soft': 'मुलायम',
    'texture_class.regular': 'सामान्य',
    'food.food_chicken_breast': 'चिकन ब्रेस्ट (पका)',
    'food.food_tofu': 'सादा टोफू',
    'food.food_brown_rice': 'भूरा चावल',
    'food.food_banana': 'केला',
    'food.food_spinach': 'पालक',
    'food.food_milk': 'सेमी-स्किम्ड दूध',
    'food.food_beef': 'दुबला बीफ़ (तला)',
    'food.food_apple': 'सेब (छिलके सहित)',
    'food.food_blueberry': 'ब्लूबेरी',
    'food.food_tomato': 'टमाटर',
    'food.food_broccoli': 'ब्रोकोली',
    'food.food_oats': 'रोल्ड ओट्स',
    'food.food_salmon': 'सैल्मन (फ़ार्म्ड, बेक्ड)',
    'food.food_fava_beans': 'फावा बीन्स (ताज़ा)',
    'food.food_potato_boiled': 'आलू (उबला)',
    'food.food_walnuts': 'अखरोट',
    'food.food_olive_oil': 'एक्स्ट्रा वर्जिन जैतून का तेल',
    'food.food_cheddar_cheese': 'चेडर चीज़',
    'food.food_egg_boiled': 'अंडा (उबला)',
    'food.food_coffee': 'कॉफी (बिना मीठा, ब्रू किया)',
    'observatory.dependency_closure.title': 'डिपेंडेंसी क्लोज़र की तैयारी',
    'observatory.dependency_closure.loading':
        'चेक-इन किया गया रूट मैनिफ़ेस्ट लोड हो रहा है · क्लोज़र HOLD',
    'observatory.dependency_closure.unavailable':
        'HOLD · चेक-इन किया गया रूट मैनिफ़ेस्ट उपलब्ध नहीं है',
    'observatory.dependency_closure.loading_semantics':
        'स्थिर एल्गोरिदम परिणाम-रूट मैनिफ़ेस्ट लोड हो रहा है। डिपेंडेंसी क्लोज़र HOLD पर है।',
    'observatory.dependency_closure.unavailable_semantics':
        'स्थिर एल्गोरिदम परिणाम-रूट मैनिफ़ेस्ट उपलब्ध नहीं है। डिपेंडेंसी क्लोज़र HOLD पर है।',
    'observatory.dependency_closure.semantics':
        '{count} स्थिर पंजीकृत एल्गोरिदम रूट। Analyzer {analyzer} घोषित सटीक-संस्करण समीक्षा लक्ष्य है। ऑफ़लाइन संगतता प्रमाण इस दृश्य में बंडल या निष्पादित नहीं किया जाता। ट्रांज़िटिव डिपेंडेंसी क्लोज़र ParkinSUM एज जनरेटर लंबित रहने तक HOLD पर है।',
    'observatory.dependency_closure.summary':
        '{count} / {total} स्थिर रूट · घोषित Analyzer लक्ष्य {analyzer} · ट्रांज़िटिव क्लोज़र HOLD',
    'observatory.dependency_closure.identity': '{schema} · {digest}… · {state}',
    'observatory.dependency_closure.registry_chip':
        'Registry मैपिंग: संरचनात्मक रूप से मान्य',
    'observatory.dependency_closure.edge_chip': 'एज जनरेटर: HOLD',
    'observatory.dependency_closure.closure_chip':
        'फ़ॉरवर्ड/रिवर्स क्लोज़र: HOLD',
    'observatory.dependency_closure.details': 'सुलभ स्थिर-रूट तालिका',
    'observatory.dependency_closure.details_subtitle':
        'केवल प्राथमिक-लाइब्रेरी सीड; कोई जनरेट की गई डिपेंडेंसी एज नहीं।',
    'observatory.dependency_closure.table_semantics':
        'स्थिर एल्गोरिदम रूट की तालिका। कॉलम हैं: एल्गोरिदम, लॉजिकल रूट, रिज़ल्ट सिंक और कैनोनिकल पैकेज URI।',
    'observatory.dependency_closure.column_algorithm': 'एल्गोरिदम',
    'observatory.dependency_closure.column_root': 'लॉजिकल रूट',
    'observatory.dependency_closure.column_sink': 'रिज़ल्ट सिंक',
    'observatory.dependency_closure.column_uri': 'पैकेज URI',
    'observatory.dependency_closure.boundary':
        'यह दृश्य केवल चेक-इन किए गए Registry-से-रूट संरचनात्मक अनुबंध को प्रमाणित करता है। ऑफ़लाइन Analyzer संगतता प्रमाण यहाँ बंडल या निष्पादित नहीं किया जाता। यह कॉल ग्राफ़, SCC, फ़ॉरवर्ड/रिवर्स क्लोज़र, निष्पादन, सटीक डेटा प्रवाह, वैज्ञानिक या नैदानिक सत्यापन, सुरक्षा, लाभ या चिकित्सकीय सलाह को न दिखाता है और न उनका दावा करता है।',
  },

  // ===========================================================================
  // es (Spanish — covers es-ES + es-MX)
  // ===========================================================================
  'es': {
    'reminders.locale_reconciliation_title':
        'El idioma de los recordatorios es distinto',
    'reminders.locale_reconciliation_body':
        'Cambió el idioma de la app. Conserva el texto actual o actualiza de forma atómica todos los recordatorios de este dispositivo. Ninguna opción muestra tus etiquetas.',
    'reminders.locale_retain_action': 'Conservar el idioma actual',
    'reminders.locale_update_action': 'Actualizar todos al idioma actual',
    'reminders.locale_retained_confirmation':
        'Se conservó el idioma actual de los recordatorios.',
    'reminders.locale_updated_confirmation':
        'Se solicitó actualizar todos los recordatorios al idioma actual.',
    'diagnostics.title': 'Diagnóstico de ingeniería',
    'diagnostics.rerun': 'Volver a ejecutar las comprobaciones',
    'diagnostics.scope_title': 'Solo revisión de ingeniería',
    'diagnostics.scope_body':
        'Estas son comprobaciones de gobernanza deterministas (compilación de textos, lint de seguridad de localización, repetición de escenarios sintéticos). Solo informan del estado de ingeniería: no cambian ninguna puntuación, gravedad, evidencia ni resultado de regla, y no son orientación de salud. Solo datos sintéticos o de demostración.',
    'diagnostics.elapsed': 'Comprobaciones completadas en {ms} ms.',
    'reminders.identity_attestation_title':
        'Comprobación de identidades pendientes informadas por el complemento',
    'reminders.identity_attestation_matched':
        'Las identidades pendientes informadas por el complemento coinciden con el plan ({installed}/{planned}). Esto no verifica de forma independiente el programador del sistema operativo ni la entrega visible.',
    'reminders.identity_attestation_drift':
        'Las identidades informadas difieren del plan: faltan {missing}, sobran {extra} y {replaced} fueron sustituidas bajo un ID previsto. No dependa de los avisos del sistema hasta completar la reconciliación.',
    'reminders.identity_attestation_uninspectable':
        'No se pudieron leer las identidades pendientes del complemento. El plan local sigue siendo la referencia, pero el estado de los avisos del sistema no está verificado.',
    'reminders.error_schedule_identity_unverified':
        'El plan local se guardó, pero las identidades pendientes del complemento no pudieron compararse con él. Vuelva a reconciliar antes de depender de los avisos del sistema.',
    'reminders.readiness_title':
        'Preparación para la entrega de recordatorios del sistema',
    'reminders.readiness_contract':
        'Contrato de capacidad de {platform} · {digest}',
    'reminders.readiness_boundary':
        'Una solicitud de programación completada o una identidad de complemento coincidente no demuestra la entrega visible, en la pantalla bloqueada ni en segundo plano.',
    'reminders.readiness_platform_android': 'Android',
    'reminders.readiness_platform_ios': 'iOS',
    'reminders.readiness_platform_macos': 'macOS',
    'reminders.readiness_platform_web': 'Web',
    'reminders.readiness_platform_windows': 'Windows',
    'reminders.readiness_platform_linux': 'Linux',
    'reminders.readiness_platform_unknown':
        'Plataforma desconocida o pasarela personalizada',
    'reminders.readiness_local_plan': 'Plan local',
    'reminders.readiness_adapter': 'Adaptador de programación',
    'reminders.readiness_schedule_request': 'Solicitud de programación',
    'reminders.readiness_permission_request': 'Solicitud de permiso',
    'reminders.readiness_permission_inspection':
        'Inspección del permiso actual',
    'reminders.readiness_registry': 'Registro de pendientes del complemento',
    'reminders.readiness_visible_delivery': 'Entrega visible',
    'reminders.readiness_body_tap': 'Toque en el cuerpo de la notificación',
    'reminders.readiness_cold_start': 'Inicio en frío desde la notificación',
    'reminders.readiness_background_action': 'Acción en segundo plano',
    'reminders.readiness_local_none': 'No hay un plan local configurado',
    'reminders.readiness_local_saved': 'Guardado en este dispositivo',
    'reminders.readiness_adapter_plan_only':
        'Solo plan; no se llama a la API de notificaciones del sistema',
    'reminders.readiness_evidence_artifact_verified':
        'Verificado con evidencia de la plataforma objetivo vinculada al artefacto',
    'reminders.readiness_evidence_implemented_unverified':
        'Implementado; sin verificación en el dispositivo objetivo vinculada al artefacto',
    'reminders.readiness_evidence_unavailable':
        'No disponible o no implementado',
    'reminders.readiness_request_not_requested': 'No enviado',
    'reminders.readiness_request_applied':
        'Solicitud del complemento completada; la entrega no está demostrada',
    'reminders.readiness_request_rolled_back':
        'La nueva solicitud de programación se revirtió y se restauró el plan anterior; la entrega no está demostrada',
    'reminders.readiness_request_superseded':
        'Sustituido por una cuenta o un plan más reciente',
    'reminders.readiness_request_unsupported':
        'Este contrato solo guarda el plan',
    'reminders.readiness_request_failed':
        'La solicitud falló o la identidad no está verificada',
    'reminders.readiness_request_recovery_required':
        'Se requiere reconciliación antes de poder depender de ello',
    'reminders.readiness_permission_not_requested':
        'No solicitado en esta sesión',
    'reminders.readiness_permission_granted':
        'La llamada para solicitar permiso devolvió permitido; no equivale al estado actual',
    'reminders.readiness_permission_denied':
        'La llamada para solicitar permiso devolvió no permitido; no demuestra una negativa explícita del usuario',
    'reminders.readiness_permission_failed':
        'La solicitud de permiso falló o el adaptador no está disponible; no significa que el usuario la haya rechazado',
    'reminders.readiness_permission_unavailable':
        'Este contrato de capacidad no solicita permiso',
    'reminders.readiness_inspection_not_inspected':
        'No se inspeccionó el estado actual del permiso',
    'reminders.readiness_inspection_enabled':
        'La inspección actual del complemento devolvió habilitado; no es prueba de entrega',
    'reminders.readiness_inspection_disabled':
        'La inspección actual del complemento devolvió deshabilitado; no identifica la causa ni una elección del usuario',
    'reminders.readiness_inspection_unavailable':
        'La inspección del permiso actual no está disponible; no significa que el usuario lo haya rechazado',
    'reminders.readiness_inspection_failed':
        'La inspección del permiso actual falló; no significa que el usuario lo haya rechazado',
    'reminders.readiness_registry_not_inspected': 'No inspeccionado',
    'reminders.readiness_registry_matched':
        'El informe del complemento coincide con el plan local; no es una prueba de entrega del sistema operativo',
    'reminders.readiness_registry_drift':
        'El informe del complemento difiere del plan local',
    'reminders.readiness_registry_uninspectable':
        'No se pudieron leer las identidades del complemento',
    'reminders.readiness_registry_unsupported':
        'Este contrato de capacidad no inspecciona un registro nativo',
    'reminders.readiness_visible_unverified': 'No verificada',
    'reminders.readiness_visible_artifact_verified':
        'Verificada por evidencia del artefacto de la plataforma objetivo',
    'app.welcome': 'Bienvenido',
    'app.loading': 'Cargando...',
    'onboarding.title': 'ParkinSUM Compañero (Edición Local)',
    'onboarding.description':
        'Esta aplicación es solo para registrar comidas y ofrecer orientación basada en reglas. No reemplaza el consejo de su médico o farmacéutico.',
    'onboarding.registration_region': 'Región de registro',
    'onboarding.registration_region_help':
        'Determina la cadena de jurisdicción predeterminada y la prioridad de fuentes.',
    'onboarding.display_language': 'Idioma de la interfaz',
    'onboarding.display_language_help':
        'Controla el idioma de la app y el formato de fechas y números.',
    'onboarding.diet_profile_region': 'Región del perfil alimentario',
    'onboarding.diet_profile_region_help':
        'Se usa para las plantillas de comidas predeterminadas sin anular las reglas de seguridad.',
    'onboarding.swallowing_texture_mode':
        'Modo de seguridad de deglución / textura',
    'onboarding.swallowing_texture_mode_help':
        'Se usa como preferencia de recomendación conservadora, no como evaluación clínica de deglución.',
    'onboarding.content_override':
        'Anulación de jurisdicción de contenido (opcional)',
    'onboarding.content_override_help': 'Separados por comas, p. ej. US,CA',
    'onboarding.local_ai_consent':
        'Habilitar reordenamiento por IA local (opcional)',
    'onboarding.local_ai_consent_help':
        'Solo usa Ollama/llama.cpp en localhost y vuelve a la ruta conservadora cuando las puertas de seguridad lo bloquean.',
    'onboarding.start': 'Lo entiendo, continuar',
    'nav.home': 'Inicio',
    'nav.analytics': 'Análisis',
    'nav.meals': 'Comidas',
    'nav.timeline': 'Cronología',
    'nav.meds': 'Medicación',
    'nav.catalog': 'Catálogo',
    'nav.next_meal': 'Próxima comida',
    'shell.tagline': 'Compañero · prototipo de investigación',
    'shell.workspace': 'Espacio de trabajo',
    'shell.care_workspace': 'Preparación de consulta y seguimiento',
    'shell.boundary_note':
        'Prototipo educativo: no es consejo médico. Revise las decisiones de salud con un profesional clínico cualificado.',
    'dashboard.greeting_morning': 'Buenos días',
    'dashboard.greeting_afternoon': 'Buenas tardes',
    'dashboard.greeting_evening': 'Buenas noches',
    'dashboard.subtitle':
        'Un resumen de sus comidas, tomas de medicación y las reglas detrás de cada explicación.',
    'dashboard.stat_meals': 'Comidas registradas',
    'dashboard.stat_drugs': 'Medicamentos activos',
    'dashboard.stat_intakes': 'Tomas registradas',
    'shell.new_entry': 'Nueva entrada',
    'shell.search': 'Buscar',
    'shell.search_hint': 'Buscar páginas, herramientas y acciones',
    'shell.search_empty':
        'No hay páginas, herramientas ni acciones que coincidan',
    'shell.menu': 'Menú',
    'shell.group.evidence': 'Evidencia y reglas',
    'shell.group.data': 'Sus datos',
    'shell.group.operations': 'Operaciones',
    'shell.group.pages': 'Páginas',
    'shell.action.observation': 'Registrar observación',
    'dashboard.stat_protein': 'Proteína media por comida',
    'dashboard.show_details': 'Mostrar detalles',
    'dashboard.hide_details': 'Ocultar detalles',
    'dashboard.quick_log': 'Registro rápido',
    'dashboard.today': 'Actividad reciente',
    'insights.title': 'Tendencias',
    'insights.subtitle':
        'Patrones de lo que ha registrado, a partir solo de sus propias entradas.',
    'insights.range_7': '7 días',
    'insights.range_30': '30 días',
    'insights.meals': 'Comidas',
    'insights.intakes': 'Tomas de medicación',
    'insights.observations': 'Observaciones',
    'insights.avg_protein': 'Proteína media por comida',
    'insights.rhythm_title': 'Ritmo de registro',
    'insights.rhythm_subtitle': 'Entradas por día',
    'insights.protein_title': 'Proteína por comida',
    'insights.protein_subtitle':
        'Gramos por comida registrada, de la más antigua a la más reciente',
    'insights.daypart_title': 'Momento del día',
    'insights.daypart_subtitle': 'Cuándo se registraron comidas y tomas',
    'insights.morning': 'Mañana',
    'insights.midday': 'Mediodía',
    'insights.evening': 'Tarde',
    'insights.night': 'Noche',
    'insights.empty': 'Aún no hay registros en este periodo.',
    'insights.boundary':
        'Son resúmenes descriptivos de sus propias entradas. No son mediciones clínicas, objetivos ni consejos; revise las decisiones de salud con un profesional clínico cualificado.',
    'settings.local_ai_advanced': 'Avanzado · Conexión de IA local',
    'nav.today': 'Hoy',
    'nav.library': 'Biblioteca',
    'dashboard.log_prompt': '¿Qué desea registrar?',
    'dashboard.log_meal_hint':
        'Alimentos y porciones, revisados con las reglas educativas',
    'dashboard.log_intake_hint': 'Una dosis de medicación que tomó',
    'dashboard.log_observation_hint':
        'Presión arterial, síntomas o estado motor',
    'dashboard.open_timeline': 'Abrir cronología',
    'dashboard.open_next_meal': 'Abrir próxima comida',
    'library.my_medications': 'Mis medicamentos',
    'library.catalog': 'Alimentos y medicamentos',
    'next_meal.title': 'Recomendación de la próxima comida',
    'next_meal.subtitle':
        'Elija la hora prevista de la próxima comida. La ruta conservadora mantiene el orden de candidatos; el modelo mecanístico solo añade una traza educativa de solapamiento temporal y no reordena. La IA local es un reordenador opcional y separado de lista segura.',
    'next_meal.input_time': 'Hora prevista de la próxima comida',
    'next_meal.use_local_ai': 'Pulir el texto con IA local (opcional)',
    'next_meal.use_local_ai_help':
        'Solo llama a Ollama/llama.cpp en localhost para reordenar y reescribir las explicaciones de los candidatos ya aprobados por el motor; vuelve al camino conservador si la puerta de seguridad lo bloquea.',
    'next_meal.generate': 'Generar recomendación',
    'next_meal.generating': 'Generando…',
    'next_meal.empty':
        'Defina la hora prevista y toque "Generar recomendación"; el motor reevaluará según esa ventana.',
    'next_meal.why_these': 'Por qué estas opciones',
    'next_meal.ai_polished': 'Pulido por IA local',
    'next_meal.conservative_engine':
        'Camino conservador del motor de conflictos',
    'next_meal.recommendation_path': 'Camino de recomendación',
    'next_meal.gate_reasons': 'Notas de la puerta de seguridad',
    'next_meal.candidates': 'Mejores candidatos',
    'next_meal.no_candidates':
        'No hay candidatos adecuados con las restricciones actuales. Ajuste la hora o amplíe el catálogo de alimentos.',
    'next_meal.error': 'Error al generar',
    'dashboard.title': 'Panel',
    'dashboard.status': 'Resumen',
    'dashboard.logged_meals': 'Comidas registradas: {count}',
    'dashboard.active_drugs': 'Medicamentos activos: {count}',
    'dashboard.logged_intakes': 'Tomas de medicamentos: {count}',
    'dashboard.recommendations': 'Recomendaciones',
    'dashboard.no_recommendations': 'Aún no hay recomendaciones',
    'dashboard.recommendation_path': 'Ruta de recomendación',
    'dashboard.recommendation_template':
        'Plantilla activa: {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'Mejora con IA local utilizada',
    'dashboard.ai_not_used': 'Solo ruta conservadora',
    'dashboard.recommendation_why': 'Por qué estas recomendaciones',
    'dashboard.recommendation_gate': 'Estado de la puerta IA / seguridad',
    'dashboard.recommendation_macro_line':
        'Por 100 g: P {protein} g · C {carbs} g · G {fat} g',
    'dashboard.recommendation_score_line':
        'Seguridad {safety} · Horario {schedule} · Hechos {facts} · Penalización contexto {context} · Penalización ventana {timing} · Penalización deglución {swallowing} · Coincidencia plantilla {template}',
    'dashboard.recent_meals': 'Comidas recientes (últimas 5)',
    'dashboard.no_meals': 'Aún no hay comidas registradas',
    'dashboard.items': '{count} elementos',
    'dashboard.meal_context_iron_supplement':
        'coevento con suplemento de hierro',
    'dashboard.meal_context_iron_multivitamin':
        'coevento con multivitamínico con hierro',
    'dashboard.meal_context_starch_thickener': 'espesante a base de almidón',
    'dashboard.meal_context_xanthan_thickener': 'espesante a base de xantano',
    'dashboard.meal_context_enteral_feed_continuous':
        'nutrición enteral continua ({protein} g/día de proteína)',
    'dashboard.meal_context_enteral_feed_bolus':
        'nutrición enteral en bolo / intermitente',
    'dashboard.edit': 'Editar',
    'dashboard.delete': 'Eliminar',
    'dashboard.protein_trend': 'Tendencia de proteínas',
    'dashboard.average_protein': 'Proteína promedio: {value} g / comida',
    'dashboard.no_trend': 'Aún no hay datos de tendencia',
    'dashboard.timeline': 'Cronología',
    'dashboard.no_timeline': 'Aún no hay comidas ni eventos de medicación',
    'dashboard.add_meal': 'Añadir comida',
    'dashboard.meal_check': 'Revisión de comida - {title}',
    'timeline.title': 'Cronología de comidas y medicación',
    'timeline.empty': 'Aún no hay comidas ni tomas de medicación',
    'timeline.add_meal': 'Añadir comida',
    'timeline.add_intake': 'Registrar medicación',
    'timeline.new_intake': 'Nueva toma de medicamento',
    'timeline.edit_intake': 'Editar toma de medicamento',
    'timeline.medication': 'Medicamento',
    'timeline.active_medication_option': '{name} (activo)',
    'timeline.dosage_note': 'Nota de dosificación',
    'timeline.package_dose_source':
        'Fuente: {source} · Consultado: {retrieved} · {url}',
    'timeline.package_dose_derivation':
        'Cálculo: {strength} × {quantity} {unit} = {amount} {resultUnit}',
    'timeline.package_dose_assumed_denominator':
        'La fuente no indicó denominador; se supone una unidad discreta ({unit}). Compruebe la etiqueta del producto antes de confirmar.',
    'timeline.package_dose_retrieval_unknown': 'No registrado',
    'timeline.taken_at': 'Tomado a las',
    'timeline.edit_taken_at': 'Editar hora de toma',
    'timeline.save_intake': 'Guardar toma',
    'timeline.no_medications': 'No hay catálogo de medicamentos disponible',
    'timeline.select_medication_first': 'Seleccione primero un medicamento',
    'timeline.save_intake_failed': 'Error al guardar la toma: {error}',
    'timeline.meal_macro_line':
        'Totales: proteína {protein} g · carbohidratos {carbs} g · grasa {fat} g',
    'timeline.conflict_line':
        'Revisión de conflicto: {severity} · puntuación {score}',
    'timeline.meal_window_line': 'Ventana de comida: {start} - {end}',
    'timeline.next_meal_window_line':
        'Próxima ventana de comida: {start} - {end}',
    'timeline.nearest_medication_line':
        'Medicamento más cercano: {name} ({distance})',
    'timeline.nearest_meal_line': 'Comida más cercana: {title} ({distance})',
    'timeline.dosage_line': 'Dosis: {value}',
    'timeline.before': '{value} antes',
    'timeline.after': '{value} después',
    'timeline.no_context_flags':
        'Sin marcadores de suplemento, espesante o nutrición enteral',
    'common.close': 'Cerrar',
    'common.done': 'Listo',
    'common.cancel': 'Cancelar',
    'common.apply': 'Aplicar',
    'common.optional': 'opcional',
    'analytics.local_ai_medical_model': 'Nombre del modelo de revision medica',
    'common.delete': 'Eliminar',
    'common.completed': 'Completado',
    'common.error': 'Error',
    'common.search_results': 'Resultados de búsqueda',
    'common.no_matching_foods': 'No se encontraron alimentos coincidentes',
    'common.texture': 'Textura',
    'common.not_available': 'No introducido',
    'common.save': 'Guardar',
    'common.edit': 'Editar',
    'common.confirm': 'Confirmar',
    'common.sign_out': 'Cerrar sesión',
    'meal_slot.breakfast': 'Desayuno',
    'meal_slot.lunch': 'Almuerzo',
    'meal_slot.dinner': 'Cena',
    'meal_slot.snack': 'Tentempié',
    'meal.title': 'Comidas',
    'meal.empty': 'Aún no hay comidas registradas',
    'meal.check_title': 'Revisión de comida - {title}',
    'medications.title': 'Medicamentos',
    'catalog.title': 'Catálogo',
    'catalog.search': 'Buscar alimentos o medicamentos',
    'catalog.foods': 'Alimentos',
    'catalog.drugs': 'Medicamentos',
    'catalog.food_subtitle':
        'Categoría={category}  P/C/G={protein}/{carbs}/{fat} (por 100 g)',
    'catalog.drug_subtitle': 'Etiquetas={tags}',
    'medications.view_detail': 'Ver detalles del medicamento',
    'decision.block': 'Bloquear',
    'decision.require_review': 'Requiere revisión',
    'decision.discourage': 'Desaconsejar',
    'decision.warn': 'Advertir',
    'decision.info': 'Información',
    'decision.allow': 'Permitir',
    'decision.defer': 'Aplazar',
    'severity.low': 'Baja',
    'severity.moderate': 'Moderada',
    'severity.high': 'Alta',
    'severity.critical': 'Crítica',
    'missing.dose': 'dosis',
    'missing.formulation': 'formulación',
    'missing.time': 'hora del medicamento',
    'missing.meal_time': 'hora de la comida',
    'missing.coevent_time': 'hora del coevento',
    'missing.thickener_type': 'tipo de espesante',
    'recommend.low_protein': 'Se prefiere menor proteína',
    'recommend.protein_window_caution':
        'Tenga precaución con mayor proteína cerca de la ventana de levodopa',
    'recommend.history_low_protein':
        'El historial reciente sugiere priorizar opciones con menor proteína',
    'recommend.culture_match':
        'Coincide con la plantilla dietética regional actual',
    'recommend.fallback_chain':
        'El conocimiento alimentario para esta región usa una cadena de respaldo',
    'recommend.general_friendly': 'Opción generalmente adecuada',
    'recommend.path.hybrid_local_ai': 'Reordenamiento asistido por IA local',
    'recommend.path.conservative_safety_gate':
        'Ruta conservadora (puerta de seguridad bloqueó la IA)',
    'recommend.path.conservative_gate_block':
        'Ruta conservadora (IA local no disponible)',
    'recommend.path.fallback_invalid_ai':
        'Ruta conservadora (la salida de la IA no superó la validación)',
    'recommend.path.conservative_cdss': 'Ruta CDSS conservadora',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'Ningún servicio Ollama o llama.cpp en localhost respondió. Inicie el servicio del modelo local o desactive el reordenamiento por IA local.',
    'recommend.runtime.endpoint_must_be_localhost':
        'El endpoint de IA local debe permanecer en localhost/127.0.0.1 y no puede apuntar a un endpoint en la nube.',
    'recommend.runtime.safety_gate_conservative':
        'La puerta de seguridad mantuvo el resultado en la ruta conservadora.',
    'recommend.runtime.next_meal_window_missing':
        'Falta la ventana de tiempo prevista para la próxima comida. Añada la hora más temprana y más tardía en Añadir/Editar comida.',
    'recommend.runtime.no_prior_meal_history':
        'No hay historial previo de comidas disponible para un reordenamiento seguro.',
    'recommend.runtime.legacy_meal_time':
        'La última comida todavía usa una hora migrada heredada; edítela a la hora real de ingesta.',
    'recommend.runtime.iron_conservative':
        'La última comida registró un suplemento de hierro, por lo que el reordenamiento se mantiene conservador.',
    'recommend.runtime.iron_multivitamin_conservative':
        'La última comida registró un multivitamínico con hierro, por lo que el reordenamiento se mantiene conservador.',
    'recommend.runtime.starch_thickener_conservative':
        'La última comida registró un espesante a base de almidón, por lo que se mantiene la revisión de seguridad determinista.',
    'recommend.runtime.enteral_conservative':
        'El contexto de nutrición enteral continua está activo, por lo que se mantiene la revisión determinista.',
    'recommend.runtime.local_ai_not_consented':
        'El usuario no ha habilitado el reordenamiento por IA local.',
    'recommend.runtime.local_ai_unavailable':
        'El endpoint de IA local no está disponible actualmente.',
    'recommend.runtime.returned_conservative':
        'Se devolvieron recomendaciones conservadoras deterministas en su lugar.',
    'recommend.runtime.ai_validation_failed':
        'La salida estructurada de la IA local no superó la validación de la lista blanca.',
    'recommend.runtime.ai_invalid_whitelist':
        'La IA local no devolvió un orden válido solo de lista blanca, por lo que el resultado no se utilizó.',
    'recommend.runtime.cdss_conservative_observations':
        'La ruta CDSS conservadora utilizó observaciones reales de variantes cuando fue posible.',
    'recommend.runtime.local_ai_success':
        'Reordenamiento por IA local exitoso.',
    'recommend.runtime.local_ai_copy_polish_success':
        'La IA local pulio el texto.',
    'recommend.runtime.medgemma_optional_unavailable':
        'El endpoint de IA local respondio; el modelo opcional MedGemma no esta disponible.',
    'recommend.runtime.recommendation_conservative':
        'La recomendación se mantuvo en la ruta conservadora.',
    'recommend.runtime.levodopa_ai_sensitive':
        'La ventana temporal de la levodopa es demasiado sensible para el reordenamiento por IA.',
    'recommend.context_iron_supplement':
        'Se registró un suplemento de hierro con la última comida, por lo que la guía de horarios se mantiene conservadora.',
    'recommend.context_iron_multivitamin':
        'Se registró un multivitamínico con hierro con la última comida, por lo que la guía de horarios se mantiene conservadora.',
    'recommend.context_starch_thickener':
        'Se registró un espesante a base de almidón, lo que aumenta la prioridad de seguridad de la deglución.',
    'recommend.context_xanthan_thickener':
        'Se registró un espesante a base de xantano para la última comida.',
    'recommend.context_enteral_feed_continuous':
        'La nutrición enteral continua está activa ({protein} g/día de proteína), por lo que la redacción de las recomendaciones se mantiene conservadora.',
    'recommend.context_enteral_feed_bolus':
        'Se registró nutrición enteral en bolo/intermitente para la última comida.',
    'recommend.context_iron_penalty':
        'Hay coeventos relacionados con hierro, por lo que las opciones con mayor proteína se mantienen conservadoramente con menor rango.',
    'recommend.context_enteral_penalty':
        'El contexto de nutrición enteral continua está presente, por lo que las opciones con mayor proteína se mantienen conservadoramente con menor rango.',
    'recommend.context_texture_gap_penalty':
        'Se registró un espesante, pero el catálogo actual aún carece de datos estructurados de compatibilidad de textura, por lo que se mantiene un margen conservador adicional.',
    'recommend.context_texture_supported':
        'Se registró un espesante y este candidato ya cuenta con metadatos estructurados de textura, por lo que la penalización por brecha de datos es menor.',
    'recommend.texture_profile_missing':
        'Hay un modo de seguridad de textura activo, pero este candidato carece de metadatos estructurados de textura, por lo que el ranking se mantiene más conservador.',
    'recommend.texture_profile_supported_soft_or_liquid':
        'Este candidato coincide con el modo de seguridad de textura blanda o líquida actual.',
    'recommend.texture_profile_supported_liquid_only':
        'Este candidato coincide con el modo de seguridad de textura solo líquida actual.',
    'recommend.texture_profile_incompatible':
        'Este candidato no coincide con el modo de seguridad de textura actual, por lo que se le asigna conservadoramente menor rango.',
    'recommend.texture_template_supported':
        'Este candidato coincide con la dirección de textura de la plantilla de comida actual.',
    'recommend.texture_template_mismatch':
        'Este candidato no coincide con la dirección de textura de la plantilla de comida actual.',
    'recommend.local_seed_metadata':
        'Este candidato aún depende de metadatos de semilla locales en lugar de observaciones más ricas respaldadas por la base de datos.',
    'recommend.timing_window_incomplete':
        'La ventana temporal está incompleta, por lo que el ranking conservador mantiene un margen de seguridad adicional.',
    'recommend.next_meal_gap_close':
        'La próxima ventana de comida sigue cerca de la comida anterior; se prefiere una opción con menor proteína.',
    'recommend.next_meal_window_fiber':
        'Esto encaja en la próxima ventana de comida planificada y favorece una ingesta de fibra más estable.',
    'recommend.medication_timing_caution':
        'Los horarios de medicación sugieren precaución adicional para esta próxima ventana de comida.',
    'texture_mode.unrestricted': 'Sin restricciones',
    'texture_mode.soft_or_liquid': 'Blando o líquido',
    'texture_mode.liquid_only': 'Solo líquido',
    'texture_class.liquid': 'Líquido',
    'texture_class.soft': 'Blando',
    'texture_class.regular': 'Normal',
    'food.food_chicken_breast': 'Pechuga de pollo (cocida)',
    'food.food_tofu': 'Tofu natural',
    'food.food_brown_rice': 'Arroz integral',
    'food.food_banana': 'Plátano',
    'food.food_spinach': 'Espinaca',
    'food.food_milk': 'Leche semidesnatada',
    'food.food_beef': 'Ternera magra (frita)',
    'food.food_apple': 'Manzana (con piel)',
    'food.food_blueberry': 'Arándano',
    'food.food_tomato': 'Tomate',
    'food.food_broccoli': 'Brócoli',
    'food.food_oats': 'Copos de avena',
    'food.food_salmon': 'Salmón (de cría, al horno)',
    'food.food_fava_beans': 'Habas (frescas)',
    'food.food_potato_boiled': 'Patata (hervida)',
    'food.food_walnuts': 'Nueces',
    'food.food_olive_oil': 'Aceite de oliva virgen extra',
    'food.food_cheddar_cheese': 'Queso cheddar',
    'food.food_egg_boiled': 'Huevo (cocido)',
    'food.food_coffee': 'Café (preparado, sin azúcar)',
    'observatory.dependency_closure.title':
        'Preparación del cierre de dependencias',
    'observatory.dependency_closure.loading':
        'Cargando el manifiesto de raíces registrado · cierre HOLD',
    'observatory.dependency_closure.unavailable':
        'HOLD · manifiesto de raíces registrado no disponible',
    'observatory.dependency_closure.loading_semantics':
        'Se está cargando el manifiesto estable de raíces de resultados algorítmicos. El cierre de dependencias permanece en HOLD.',
    'observatory.dependency_closure.unavailable_semantics':
        'El manifiesto estable de raíces de resultados algorítmicos no está disponible. El cierre de dependencias está en HOLD.',
    'observatory.dependency_closure.semantics':
        '{count} raíces de algoritmos estables y registradas. Analyzer {analyzer} es la versión exacta declarada como objetivo de revisión. La evidencia de compatibilidad sin conexión no está incluida ni se ejecuta en esta vista. El cierre transitivo de dependencias está en HOLD a la espera del generador de aristas de ParkinSUM.',
    'observatory.dependency_closure.summary':
        '{count} / {total} raíces estables · objetivo Analyzer declarado {analyzer} · cierre transitivo HOLD',
    'observatory.dependency_closure.identity': '{schema} · {digest}… · {state}',
    'observatory.dependency_closure.registry_chip':
        'mapeo de Registry: estructuralmente válido',
    'observatory.dependency_closure.edge_chip': 'generador de aristas: HOLD',
    'observatory.dependency_closure.closure_chip':
        'cierre directo/inverso: HOLD',
    'observatory.dependency_closure.details':
        'Tabla accesible de raíces estables',
    'observatory.dependency_closure.details_subtitle':
        'Solo semillas de bibliotecas primarias; sin aristas de dependencia generadas.',
    'observatory.dependency_closure.table_semantics':
        'Tabla de raíces estables de algoritmos. Las columnas son algoritmo, raíz lógica, destino del resultado y URI canónico del paquete.',
    'observatory.dependency_closure.column_algorithm': 'Algoritmo',
    'observatory.dependency_closure.column_root': 'Raíz lógica',
    'observatory.dependency_closure.column_sink': 'Destino del resultado',
    'observatory.dependency_closure.column_uri': 'URI del paquete',
    'observatory.dependency_closure.boundary':
        'Esta vista solo demuestra un contrato estructural Registry-raíz registrado en el repositorio. La evidencia de compatibilidad sin conexión de Analyzer no está incluida ni se ejecuta aquí. No muestra ni afirma un grafo de llamadas, SCC, cierre directo o inverso, ejecución, flujo de datos exacto, validación científica o clínica, seguridad, beneficio ni asesoramiento médico.',
  },

  // ===========================================================================
  // vi (Vietnamese)
  // ===========================================================================
  'vi': {
    'reminders.locale_reconciliation_title': 'Ngôn ngữ lời nhắc hệ thống khác',
    'reminders.locale_reconciliation_body':
        'Ngôn ngữ ứng dụng đã thay đổi. Giữ nội dung lời nhắc hiện tại hoặc cập nhật nguyên tử mọi lời nhắc trên thiết bị này. Cả hai lựa chọn đều không hiển thị nhãn bạn đã viết.',
    'reminders.locale_retain_action': 'Giữ ngôn ngữ hiện tại',
    'reminders.locale_update_action': 'Cập nhật tất cả sang ngôn ngữ hiện tại',
    'reminders.locale_retained_confirmation':
        'Đã giữ ngôn ngữ lời nhắc hệ thống hiện tại.',
    'reminders.locale_updated_confirmation':
        'Đã yêu cầu cập nhật mọi lời nhắc hệ thống sang ngôn ngữ hiện tại.',
    'diagnostics.title': 'Chẩn đoán kỹ thuật',
    'diagnostics.rerun': 'Chạy lại kiểm tra',
    'diagnostics.scope_title': 'Chỉ dành cho rà soát kỹ thuật',
    'diagnostics.scope_body':
        'Đây là các kiểm tra quản trị tất định (biên dịch nội dung, lint an toàn bản địa hóa, phát lại kịch bản tổng hợp). Chúng chỉ báo cáo trạng thái kỹ thuật: không thay đổi điểm số, mức độ nghiêm trọng, bằng chứng hay kết quả quy tắc, và không phải hướng dẫn sức khỏe. Chỉ dùng dữ liệu tổng hợp/demo.',
    'diagnostics.elapsed': 'Hoàn tất kiểm tra trong {ms} ms.',
    'reminders.identity_attestation_title':
        'Kiểm tra danh tính yêu cầu đang chờ do plugin báo cáo',
    'reminders.identity_attestation_matched':
        'Danh tính đang chờ do plugin báo cáo khớp với kế hoạch ({installed}/{planned}). Đây không phải là xác minh độc lập bộ lập lịch của hệ điều hành hoặc việc thông báo thực sự hiển thị.',
    'reminders.identity_attestation_drift':
        'Danh tính do plugin báo cáo khác kế hoạch: thiếu {missing}, thừa {extra}, và {replaced} bị thay thế dưới ID đã lên kế hoạch. Không dựa vào nhắc nhở hệ thống cho đến khi đồng bộ lại thành công.',
    'reminders.identity_attestation_uninspectable':
        'Không thể đọc danh tính yêu cầu đang chờ từ plugin. Kế hoạch cục bộ vẫn là nguồn chuẩn, nhưng trạng thái nhắc nhở hệ thống chưa được xác minh.',
    'reminders.error_schedule_identity_unverified':
        'Kế hoạch cục bộ đã được lưu, nhưng danh tính đang chờ do plugin báo cáo không thể khớp với kế hoạch. Hãy đồng bộ lại trước khi dựa vào nhắc nhở hệ thống.',
    'reminders.readiness_title': 'Mức sẵn sàng phân phối lời nhắc hệ thống',
    'reminders.readiness_contract': 'Hợp đồng năng lực {platform} · {digest}',
    'reminders.readiness_boundary':
        'Yêu cầu lập lịch đã hoàn tất hoặc danh tính trình cắm trùng khớp không chứng minh được việc phân phối hiển thị, trên màn hình khóa hoặc trong nền.',
    'reminders.readiness_platform_android': 'Android',
    'reminders.readiness_platform_ios': 'iOS',
    'reminders.readiness_platform_macos': 'macOS',
    'reminders.readiness_platform_web': 'Web',
    'reminders.readiness_platform_windows': 'Windows',
    'reminders.readiness_platform_linux': 'Linux',
    'reminders.readiness_platform_unknown':
        'Nền tảng không xác định hoặc cổng tùy chỉnh',
    'reminders.readiness_local_plan': 'Kế hoạch cục bộ',
    'reminders.readiness_adapter': 'Bộ điều hợp lập lịch',
    'reminders.readiness_schedule_request': 'Yêu cầu lập lịch',
    'reminders.readiness_permission_request': 'Yêu cầu quyền',
    'reminders.readiness_permission_inspection': 'Kiểm tra quyền hiện tại',
    'reminders.readiness_registry': 'Sổ đăng ký đang chờ của trình cắm',
    'reminders.readiness_visible_delivery': 'Phân phối hiển thị',
    'reminders.readiness_body_tap': 'Chạm vào nội dung thông báo',
    'reminders.readiness_cold_start': 'Khởi động nguội từ thông báo',
    'reminders.readiness_background_action': 'Hành động nền',
    'reminders.readiness_local_none': 'Chưa cấu hình kế hoạch cục bộ',
    'reminders.readiness_local_saved': 'Đã lưu trên thiết bị này',
    'reminders.readiness_adapter_plan_only':
        'Chỉ lưu kế hoạch; không gọi API thông báo hệ thống',
    'reminders.readiness_evidence_artifact_verified':
        'Đã xác minh bằng bằng chứng gắn với hiện vật của nền tảng đích',
    'reminders.readiness_evidence_implemented_unverified':
        'Đã triển khai; chưa có xác minh gắn với hiện vật trên thiết bị đích',
    'reminders.readiness_evidence_unavailable':
        'Không khả dụng hoặc chưa được triển khai',
    'reminders.readiness_request_not_requested': 'Chưa gửi',
    'reminders.readiness_request_applied':
        'Yêu cầu trình cắm đã hoàn tất; chưa chứng minh được việc phân phối',
    'reminders.readiness_request_rolled_back':
        'Yêu cầu lập lịch mới đã được hoàn tác và kế hoạch cũ được khôi phục; chưa chứng minh được việc phân phối',
    'reminders.readiness_request_superseded':
        'Đã bị thay thế bởi tài khoản hoặc kế hoạch mới hơn',
    'reminders.readiness_request_unsupported': 'Hợp đồng này chỉ lưu kế hoạch',
    'reminders.readiness_request_failed':
        'Yêu cầu thất bại hoặc danh tính chưa được xác minh',
    'reminders.readiness_request_recovery_required':
        'Cần đối soát trước khi có thể dựa vào',
    'reminders.readiness_permission_not_requested':
        'Chưa yêu cầu trong phiên này',
    'reminders.readiness_permission_granted':
        'Lệnh gọi yêu cầu quyền trả về cho phép; không tương đương với trạng thái hiện tại',
    'reminders.readiness_permission_denied':
        'Lệnh gọi yêu cầu quyền trả về không cho phép; không chứng minh người dùng đã chủ động từ chối',
    'reminders.readiness_permission_failed':
        'Yêu cầu quyền thất bại hoặc bộ điều hợp không khả dụng; điều này không có nghĩa là người dùng đã từ chối',
    'reminders.readiness_permission_unavailable':
        'Hợp đồng năng lực này không yêu cầu quyền',
    'reminders.readiness_inspection_not_inspected':
        'Chưa kiểm tra trạng thái quyền hiện tại',
    'reminders.readiness_inspection_enabled':
        'Kiểm tra hiện tại của trình cắm trả về đã bật; không phải bằng chứng phân phối',
    'reminders.readiness_inspection_disabled':
        'Kiểm tra hiện tại của trình cắm trả về đã tắt; chưa xác định nguyên nhân hay lựa chọn của người dùng',
    'reminders.readiness_inspection_unavailable':
        'Không thể kiểm tra trạng thái quyền hiện tại; không có nghĩa là người dùng đã từ chối',
    'reminders.readiness_inspection_failed':
        'Kiểm tra trạng thái quyền hiện tại thất bại; không có nghĩa là người dùng đã từ chối',
    'reminders.readiness_registry_not_inspected': 'Chưa kiểm tra',
    'reminders.readiness_registry_matched':
        'Báo cáo trình cắm khớp với kế hoạch cục bộ; không phải bằng chứng phân phối của hệ điều hành',
    'reminders.readiness_registry_drift':
        'Báo cáo trình cắm khác với kế hoạch cục bộ',
    'reminders.readiness_registry_uninspectable':
        'Không thể đọc danh tính của trình cắm',
    'reminders.readiness_registry_unsupported':
        'Hợp đồng năng lực này không kiểm tra sổ đăng ký gốc',
    'reminders.readiness_visible_unverified': 'Chưa xác minh',
    'reminders.readiness_visible_artifact_verified':
        'Đã xác minh bằng bằng chứng hiện vật của nền tảng đích',
    'app.welcome': 'Chào mừng',
    'app.loading': 'Đang tải...',
    'onboarding.title': 'ParkinSUM Đồng hành (Phiên bản cục bộ)',
    'onboarding.description':
        'Ứng dụng này chỉ dùng để ghi lại bữa ăn và đưa ra hướng dẫn dựa trên quy tắc. Nó không thay thế lời khuyên của bác sĩ hoặc dược sĩ.',
    'onboarding.registration_region': 'Khu vực đăng ký',
    'onboarding.registration_region_help':
        'Quyết định chuỗi quyền hạn mặc định và mức ưu tiên nguồn dữ liệu.',
    'onboarding.display_language': 'Ngôn ngữ hiển thị',
    'onboarding.display_language_help':
        'Điều khiển ngôn ngữ ứng dụng, định dạng ngày và số.',
    'onboarding.diet_profile_region': 'Khu vực hồ sơ chế độ ăn',
    'onboarding.diet_profile_region_help':
        'Dùng cho mẫu bữa ăn mặc định mà không ghi đè quy tắc an toàn.',
    'onboarding.swallowing_texture_mode': 'Chế độ an toàn nuốt / kết cấu',
    'onboarding.swallowing_texture_mode_help':
        'Dùng làm tùy chọn đề xuất thận trọng, không phải đánh giá nuốt lâm sàng.',
    'onboarding.content_override': 'Ghi đè quyền hạn nội dung (tùy chọn)',
    'onboarding.content_override_help': 'Phân tách bằng dấu phẩy, ví dụ US,CA',
    'onboarding.local_ai_consent': 'Bật sắp xếp lại bằng AI cục bộ (tùy chọn)',
    'onboarding.local_ai_consent_help':
        'Chỉ dùng Ollama/llama.cpp trên localhost và quay về đường dẫn thận trọng khi cổng an toàn chặn.',
    'onboarding.start': 'Tôi đã hiểu, tiếp tục',
    'nav.home': 'Trang chủ',
    'nav.analytics': 'Phân tích',
    'nav.meals': 'Bữa ăn',
    'nav.timeline': 'Dòng thời gian',
    'nav.meds': 'Thuốc',
    'nav.catalog': 'Danh mục',
    'nav.next_meal': 'Bữa kế tiếp',
    'shell.tagline': 'Ứng dụng đồng hành · nguyên mẫu nghiên cứu',
    'shell.workspace': 'Không gian làm việc',
    'shell.care_workspace': 'Chuẩn bị khám và theo dõi',
    'shell.boundary_note':
        'Nguyên mẫu giáo dục — không phải lời khuyên y tế. Hãy xem xét các quyết định sức khỏe với bác sĩ có chuyên môn.',
    'dashboard.greeting_morning': 'Chào buổi sáng',
    'dashboard.greeting_afternoon': 'Chào buổi chiều',
    'dashboard.greeting_evening': 'Chào buổi tối',
    'dashboard.subtitle':
        'Tổng quan về bữa ăn, lần dùng thuốc đã ghi và các quy tắc đằng sau mỗi giải thích.',
    'dashboard.stat_meals': 'Bữa ăn đã ghi',
    'dashboard.stat_drugs': 'Thuốc đang dùng',
    'dashboard.stat_intakes': 'Lần dùng thuốc đã ghi',
    'shell.new_entry': 'Mục mới',
    'shell.search': 'Tìm kiếm',
    'shell.search_hint': 'Tìm trang, công cụ và thao tác',
    'shell.search_empty': 'Không có trang, công cụ hoặc thao tác phù hợp',
    'shell.menu': 'Menu',
    'shell.group.evidence': 'Bằng chứng và quy tắc',
    'shell.group.data': 'Dữ liệu của bạn',
    'shell.group.operations': 'Vận hành',
    'shell.group.pages': 'Trang',
    'shell.action.observation': 'Ghi nhận quan sát',
    'dashboard.stat_protein': 'Protein trung bình mỗi bữa',
    'dashboard.show_details': 'Hiện chi tiết',
    'dashboard.hide_details': 'Ẩn chi tiết',
    'dashboard.quick_log': 'Ghi nhanh',
    'dashboard.today': 'Hoạt động gần đây',
    'insights.title': 'Thông tin tổng hợp',
    'insights.subtitle': 'Các mẫu hình từ chính những gì bạn đã ghi.',
    'insights.range_7': '7 ngày',
    'insights.range_30': '30 ngày',
    'insights.meals': 'Bữa ăn',
    'insights.intakes': 'Lần dùng thuốc',
    'insights.observations': 'Quan sát',
    'insights.avg_protein': 'Protein trung bình mỗi bữa',
    'insights.rhythm_title': 'Nhịp ghi chép',
    'insights.rhythm_subtitle': 'Số mục mỗi ngày',
    'insights.protein_title': 'Protein mỗi bữa',
    'insights.protein_subtitle': 'Số gam mỗi bữa đã ghi, từ cũ đến mới',
    'insights.daypart_title': 'Thời điểm trong ngày',
    'insights.daypart_subtitle': 'Thời điểm ghi bữa ăn và lần dùng thuốc',
    'insights.morning': 'Sáng',
    'insights.midday': 'Trưa',
    'insights.evening': 'Chiều tối',
    'insights.night': 'Đêm',
    'insights.empty': 'Chưa có ghi chép nào trong khoảng thời gian này.',
    'insights.boundary':
        'Đây là các bản tóm tắt mô tả từ chính ghi chép của bạn, không phải số đo lâm sàng, mục tiêu hay lời khuyên; hãy xem xét các quyết định sức khỏe với bác sĩ có chuyên môn.',
    'settings.local_ai_advanced': 'Nâng cao · Kết nối AI cục bộ',
    'nav.today': 'Hôm nay',
    'nav.library': 'Thư viện',
    'dashboard.log_prompt': 'Bạn muốn ghi gì?',
    'dashboard.log_meal_hint':
        'Thực phẩm và khẩu phần, được kiểm tra theo quy tắc giáo dục',
    'dashboard.log_intake_hint': 'Một liều thuốc bạn đã dùng',
    'dashboard.log_observation_hint':
        'Huyết áp, triệu chứng hoặc trạng thái vận động',
    'dashboard.open_timeline': 'Mở dòng thời gian',
    'dashboard.open_next_meal': 'Mở bữa kế tiếp',
    'library.my_medications': 'Thuốc của tôi',
    'library.catalog': 'Thực phẩm và thuốc',
    'next_meal.title': 'Đề xuất bữa kế tiếp',
    'next_meal.subtitle':
        'Hãy chọn giờ dự kiến cho bữa kế tiếp. Đường quy tắc thận trọng giữ nguyên thứ tự ứng viên; mô hình cơ chế chỉ thêm dấu vết chồng lấp thời gian mang tính giáo dục và không xếp lại. AI cục bộ là bộ xếp lại danh sách an toàn riêng, tùy chọn.',
    'next_meal.input_time': 'Giờ dự kiến bữa kế tiếp',
    'next_meal.use_local_ai': 'Dùng AI cục bộ làm mượt văn bản (tùy chọn)',
    'next_meal.use_local_ai_help':
        'Chỉ gọi Ollama/llama.cpp trên localhost để sắp xếp lại và viết lại giải thích cho các ứng viên đã được bộ máy phê duyệt; quay về đường dẫn thận trọng khi cổng an toàn chặn.',
    'next_meal.generate': 'Tạo đề xuất',
    'next_meal.generating': 'Đang tạo…',
    'next_meal.empty':
        'Đặt giờ dự kiến rồi chạm "Tạo đề xuất"; bộ máy sẽ đánh giá lại theo khung giờ đó.',
    'next_meal.why_these': 'Vì sao chọn những món này',
    'next_meal.ai_polished': 'AI cục bộ đã làm mượt văn bản',
    'next_meal.conservative_engine': 'Đường dẫn thận trọng của bộ máy xung đột',
    'next_meal.recommendation_path': 'Đường dẫn đề xuất',
    'next_meal.gate_reasons': 'Ghi chú cổng an toàn',
    'next_meal.candidates': 'Ứng viên hàng đầu',
    'next_meal.no_candidates':
        'Không có ứng viên phù hợp với ràng buộc hiện tại. Hãy điều chỉnh giờ dự kiến hoặc mở rộng danh mục thực phẩm.',
    'next_meal.error': 'Tạo thất bại',
    'dashboard.title': 'Bảng điều khiển',
    'dashboard.status': 'Tổng quan',
    'dashboard.logged_meals': 'Bữa ăn đã ghi: {count}',
    'dashboard.active_drugs': 'Thuốc đang dùng: {count}',
    'dashboard.logged_intakes': 'Số lần uống thuốc: {count}',
    'dashboard.recommendations': 'Gợi ý',
    'dashboard.no_recommendations': 'Chưa có gợi ý',
    'dashboard.recommendation_path': 'Đường dẫn gợi ý',
    'dashboard.recommendation_template':
        'Mẫu đang dùng: {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'Đã dùng tăng cường AI cục bộ',
    'dashboard.ai_not_used': 'Chỉ đường dẫn thận trọng',
    'dashboard.recommendation_why': 'Vì sao có những gợi ý này',
    'dashboard.recommendation_gate': 'Trạng thái cổng AI / an toàn',
    'dashboard.recommendation_macro_line':
        'Mỗi 100g: P {protein} g · C {carbs} g · F {fat} g',
    'dashboard.recommendation_score_line':
        'An toàn {safety} · Lịch {schedule} · Sự kiện {facts} · Phạt ngữ cảnh {context} · Phạt cửa sổ {timing} · Phạt nuốt {swallowing} · Khớp mẫu {template}',
    'dashboard.recent_meals': 'Bữa ăn gần đây (5 lần mới nhất)',
    'dashboard.no_meals': 'Chưa có bữa ăn nào được ghi',
    'dashboard.items': '{count} mục',
    'dashboard.meal_context_iron_supplement':
        'sự kiện đồng thời với bổ sung sắt',
    'dashboard.meal_context_iron_multivitamin':
        'sự kiện đồng thời với đa sinh tố có sắt',
    'dashboard.meal_context_starch_thickener': 'chất làm đặc gốc tinh bột',
    'dashboard.meal_context_xanthan_thickener': 'chất làm đặc gốc xanthan',
    'dashboard.meal_context_enteral_feed_continuous':
        'nuôi dưỡng qua đường ruột liên tục ({protein} g đạm/ngày)',
    'dashboard.meal_context_enteral_feed_bolus':
        'nuôi dưỡng qua đường ruột dạng bolus / ngắt quãng',
    'dashboard.edit': 'Sửa',
    'dashboard.delete': 'Xóa',
    'dashboard.protein_trend': 'Xu hướng đạm',
    'dashboard.average_protein': 'Đạm trung bình: {value} g / bữa',
    'dashboard.no_trend': 'Chưa có dữ liệu xu hướng',
    'dashboard.timeline': 'Dòng thời gian',
    'dashboard.no_timeline': 'Chưa có sự kiện bữa ăn hoặc thuốc',
    'dashboard.add_meal': 'Thêm bữa ăn',
    'dashboard.meal_check': 'Kiểm tra bữa ăn - {title}',
    'timeline.title': 'Dòng thời gian bữa ăn và thuốc',
    'timeline.empty': 'Chưa có bữa ăn hoặc lần uống thuốc',
    'timeline.add_meal': 'Thêm bữa ăn',
    'timeline.add_intake': 'Ghi uống thuốc',
    'timeline.new_intake': 'Lần uống thuốc mới',
    'timeline.edit_intake': 'Sửa lần uống thuốc',
    'timeline.medication': 'Thuốc',
    'timeline.active_medication_option': '{name} (đang dùng)',
    'timeline.dosage_note': 'Ghi chú liều',
    'timeline.package_dose_source':
        'Nguồn: {source} · Thời điểm truy xuất: {retrieved} · {url}',
    'timeline.package_dose_derivation':
        'Tính toán: {strength} × {quantity} {unit} = {amount} {resultUnit}',
    'timeline.package_dose_assumed_denominator':
        'Nguồn không nêu mẫu số; tạm giả định một đơn vị dạng thuốc rời ({unit}). Hãy kiểm tra nhãn sản phẩm trước khi xác nhận.',
    'timeline.package_dose_retrieval_unknown': 'Chưa ghi nhận',
    'timeline.taken_at': 'Uống lúc',
    'timeline.edit_taken_at': 'Sửa thời điểm uống',
    'timeline.save_intake': 'Lưu lần uống',
    'timeline.no_medications': 'Không có danh mục thuốc',
    'timeline.select_medication_first': 'Hãy chọn một thuốc trước',
    'timeline.save_intake_failed': 'Lưu lần uống thất bại: {error}',
    'timeline.meal_macro_line':
        'Tổng: đạm {protein} g · tinh bột {carbs} g · béo {fat} g',
    'timeline.conflict_line': 'Xem xét xung đột: {severity} · điểm {score}',
    'timeline.meal_window_line': 'Cửa sổ bữa ăn: {start} - {end}',
    'timeline.next_meal_window_line': 'Cửa sổ bữa ăn kế tiếp: {start} - {end}',
    'timeline.nearest_medication_line': 'Thuốc gần nhất: {name} ({distance})',
    'timeline.nearest_meal_line': 'Bữa ăn gần nhất: {title} ({distance})',
    'timeline.dosage_line': 'Liều: {value}',
    'timeline.before': '{value} trước',
    'timeline.after': '{value} sau',
    'timeline.no_context_flags':
        'Không có cờ bổ sung, chất làm đặc hay nuôi dưỡng qua đường ruột',
    'common.close': 'Đóng',
    'common.done': 'Xong',
    'common.cancel': 'Hủy',
    'common.apply': 'Áp dụng',
    'common.optional': 'tùy chọn',
    'analytics.local_ai_medical_model': 'Tên mô hình rà soát y khoa',
    'common.delete': 'Xóa',
    'common.completed': 'Đã hoàn thành',
    'common.error': 'Lỗi',
    'common.search_results': 'Kết quả tìm kiếm',
    'common.no_matching_foods': 'Không tìm thấy thực phẩm phù hợp',
    'common.texture': 'Kết cấu',
    'common.not_available': 'Chưa nhập',
    'common.save': 'Lưu',
    'common.edit': 'Sửa',
    'common.confirm': 'Xác nhận',
    'common.sign_out': 'Đăng xuất',
    'meal_slot.breakfast': 'Bữa sáng',
    'meal_slot.lunch': 'Bữa trưa',
    'meal_slot.dinner': 'Bữa tối',
    'meal_slot.snack': 'Ăn vặt',
    'meal.title': 'Bữa ăn',
    'meal.empty': 'Chưa có bữa ăn nào được ghi',
    'meal.check_title': 'Kiểm tra bữa ăn - {title}',
    'medications.title': 'Thuốc',
    'catalog.title': 'Danh mục',
    'catalog.search': 'Tìm thực phẩm hoặc thuốc',
    'catalog.foods': 'Thực phẩm',
    'catalog.drugs': 'Thuốc',
    'catalog.food_subtitle':
        'Loại={category}  P/C/F={protein}/{carbs}/{fat} (mỗi 100 g)',
    'catalog.drug_subtitle': 'Thẻ={tags}',
    'medications.view_detail': 'Xem chi tiết thuốc',
    'decision.block': 'Chặn',
    'decision.require_review': 'Cần xem xét',
    'decision.discourage': 'Không khuyến khích',
    'decision.warn': 'Cảnh báo',
    'decision.info': 'Thông tin',
    'decision.allow': 'Cho phép',
    'decision.defer': 'Hoãn lại',
    'severity.low': 'Thấp',
    'severity.moderate': 'Vừa',
    'severity.high': 'Cao',
    'severity.critical': 'Nghiêm trọng',
    'missing.dose': 'liều',
    'missing.formulation': 'dạng bào chế',
    'missing.time': 'thời điểm uống thuốc',
    'missing.meal_time': 'thời điểm ăn',
    'missing.coevent_time': 'thời điểm sự kiện đồng thời',
    'missing.thickener_type': 'loại chất làm đặc',
    'recommend.low_protein': 'Ưu tiên ít đạm hơn',
    'recommend.protein_window_caution':
        'Thận trọng với đạm cao gần cửa sổ levodopa',
    'recommend.history_low_protein':
        'Lịch sử gần đây gợi ý ưu tiên các lựa chọn ít đạm',
    'recommend.culture_match': 'Khớp với mẫu chế độ ăn vùng hiện tại',
    'recommend.fallback_chain':
        'Kiến thức thực phẩm cho khu vực này đang dùng chuỗi dự phòng',
    'recommend.general_friendly': 'Tùy chọn nhìn chung phù hợp',
    'recommend.path.hybrid_local_ai': 'AI cục bộ hỗ trợ sắp xếp lại',
    'recommend.path.conservative_safety_gate':
        'Đường dẫn thận trọng (cổng an toàn chặn AI)',
    'recommend.path.conservative_gate_block':
        'Đường dẫn thận trọng (AI cục bộ không khả dụng)',
    'recommend.path.fallback_invalid_ai':
        'Đường dẫn thận trọng (đầu ra AI không qua kiểm tra)',
    'recommend.path.conservative_cdss': 'Đường dẫn CDSS thận trọng',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'Không có dịch vụ Ollama hoặc llama.cpp trên localhost phản hồi. Hãy khởi động dịch vụ mô hình cục bộ hoặc tắt sắp xếp lại bằng AI cục bộ.',
    'recommend.runtime.endpoint_must_be_localhost':
        'Endpoint AI cục bộ phải nằm trên localhost/127.0.0.1 và không được trỏ tới endpoint trên đám mây.',
    'recommend.runtime.safety_gate_conservative':
        'Cổng an toàn đã giữ kết quả ở đường dẫn thận trọng.',
    'recommend.runtime.next_meal_window_missing':
        'Thiếu cửa sổ thời gian dự kiến cho bữa ăn kế tiếp. Hãy thêm thời gian sớm nhất và muộn nhất trong Thêm/Sửa bữa ăn.',
    'recommend.runtime.no_prior_meal_history':
        'Không có lịch sử bữa ăn trước đó để sắp xếp lại an toàn.',
    'recommend.runtime.legacy_meal_time':
        'Bữa ăn mới nhất vẫn dùng giờ cũ đã di chuyển; hãy sửa thành giờ ăn thực tế.',
    'recommend.runtime.iron_conservative':
        'Bữa ăn mới nhất đã ghi nhận bổ sung sắt, nên việc sắp xếp lại giữ thận trọng.',
    'recommend.runtime.iron_multivitamin_conservative':
        'Bữa ăn mới nhất đã ghi nhận đa sinh tố có sắt, nên việc sắp xếp lại giữ thận trọng.',
    'recommend.runtime.starch_thickener_conservative':
        'Bữa ăn mới nhất đã ghi nhận chất làm đặc gốc tinh bột, nên giữ kiểm tra an toàn xác định.',
    'recommend.runtime.enteral_conservative':
        'Đang có ngữ cảnh nuôi dưỡng qua đường ruột liên tục, nên giữ kiểm tra xác định.',
    'recommend.runtime.local_ai_not_consented':
        'Người dùng chưa bật sắp xếp lại bằng AI cục bộ.',
    'recommend.runtime.local_ai_unavailable':
        'Endpoint AI cục bộ hiện không khả dụng.',
    'recommend.runtime.returned_conservative':
        'Đã trả về các gợi ý thận trọng xác định thay thế.',
    'recommend.runtime.ai_validation_failed':
        'Đầu ra có cấu trúc của AI cục bộ không qua kiểm tra danh sách trắng.',
    'recommend.runtime.ai_invalid_whitelist':
        'AI cục bộ không trả về thứ tự hợp lệ chỉ thuộc danh sách trắng, nên kết quả không được dùng.',
    'recommend.runtime.cdss_conservative_observations':
        'Đường dẫn CDSS thận trọng đã dùng quan sát biến thể thực khi có.',
    'recommend.runtime.local_ai_success':
        'Sắp xếp lại bằng AI cục bộ thành công.',
    'recommend.runtime.local_ai_copy_polish_success':
        'AI cục bộ đã làm mượt cách diễn đạt.',
    'recommend.runtime.medgemma_optional_unavailable':
        'Endpoint AI cục bộ đã phản hồi; mô hình MedGemma tùy chọn chưa khả dụng.',
    'recommend.runtime.recommendation_conservative':
        'Gợi ý vẫn ở đường dẫn thận trọng.',
    'recommend.runtime.levodopa_ai_sensitive':
        'Cửa sổ thời gian levodopa quá nhạy cảm để dùng AI sắp xếp lại.',
    'recommend.context_iron_supplement':
        'Đã ghi nhận bổ sung sắt với bữa ăn mới nhất, nên hướng dẫn thời gian giữ thận trọng.',
    'recommend.context_iron_multivitamin':
        'Đã ghi nhận đa sinh tố có sắt với bữa ăn mới nhất, nên hướng dẫn thời gian giữ thận trọng.',
    'recommend.context_starch_thickener':
        'Đã ghi nhận chất làm đặc gốc tinh bột, làm tăng độ ưu tiên an toàn nuốt.',
    'recommend.context_xanthan_thickener':
        'Đã ghi nhận chất làm đặc gốc xanthan cho bữa ăn mới nhất.',
    'recommend.context_enteral_feed_continuous':
        'Đang nuôi dưỡng qua đường ruột liên tục ({protein} g đạm/ngày), nên cách diễn đạt gợi ý giữ thận trọng.',
    'recommend.context_enteral_feed_bolus':
        'Đã ghi nhận nuôi dưỡng đường ruột dạng bolus/ngắt quãng cho bữa ăn mới nhất.',
    'recommend.context_iron_penalty':
        'Có sự kiện đồng thời liên quan đến sắt, nên các tùy chọn nhiều đạm bị hạ thứ hạng thận trọng.',
    'recommend.context_enteral_penalty':
        'Có ngữ cảnh nuôi dưỡng đường ruột liên tục, nên các tùy chọn nhiều đạm bị hạ thứ hạng thận trọng.',
    'recommend.context_texture_gap_penalty':
        'Đã ghi nhận chất làm đặc, nhưng danh mục hiện chưa có dữ liệu kết cấu có cấu trúc, nên giữ biên thận trọng thêm.',
    'recommend.context_texture_supported':
        'Đã ghi nhận chất làm đặc, và ứng viên này đã có metadata kết cấu có cấu trúc, nên hình phạt khoảng trống dữ liệu được giữ thấp hơn.',
    'recommend.texture_profile_missing':
        'Chế độ an toàn kết cấu đang bật, nhưng ứng viên này thiếu metadata kết cấu có cấu trúc, nên xếp hạng giữ thận trọng hơn.',
    'recommend.texture_profile_supported_soft_or_liquid':
        'Ứng viên này khớp với chế độ an toàn kết cấu mềm-hoặc-lỏng hiện tại.',
    'recommend.texture_profile_supported_liquid_only':
        'Ứng viên này khớp với chế độ an toàn kết cấu chỉ lỏng hiện tại.',
    'recommend.texture_profile_incompatible':
        'Ứng viên này không khớp với chế độ an toàn kết cấu hiện tại, nên bị hạ thứ hạng thận trọng.',
    'recommend.texture_template_supported':
        'Ứng viên này khớp với hướng kết cấu của mẫu bữa ăn hiện tại.',
    'recommend.texture_template_mismatch':
        'Ứng viên này không khớp với hướng kết cấu của mẫu bữa ăn hiện tại.',
    'recommend.local_seed_metadata':
        'Ứng viên này vẫn dựa vào metadata seed cục bộ thay vì các quan sát phong phú hơn từ cơ sở dữ liệu.',
    'recommend.timing_window_incomplete':
        'Cửa sổ thời gian chưa đầy đủ, nên xếp hạng thận trọng giữ thêm biên an toàn.',
    'recommend.next_meal_gap_close':
        'Cửa sổ bữa ăn kế tiếp vẫn gần bữa trước; ưu tiên tùy chọn ít đạm hơn.',
    'recommend.next_meal_window_fiber':
        'Phù hợp với cửa sổ bữa ăn kế tiếp đã lên kế hoạch và ưu tiên lượng chất xơ ổn định hơn.',
    'recommend.medication_timing_caution':
        'Thời điểm dùng thuốc gợi ý cần thận trọng thêm cho cửa sổ bữa ăn kế tiếp này.',
    'texture_mode.unrestricted': 'Không hạn chế',
    'texture_mode.soft_or_liquid': 'Mềm hoặc lỏng',
    'texture_mode.liquid_only': 'Chỉ lỏng',
    'texture_class.liquid': 'Lỏng',
    'texture_class.soft': 'Mềm',
    'texture_class.regular': 'Thường',
    'food.food_chicken_breast': 'Ức gà (đã nấu)',
    'food.food_tofu': 'Đậu phụ thường',
    'food.food_brown_rice': 'Gạo lứt',
    'food.food_banana': 'Chuối',
    'food.food_spinach': 'Cải bó xôi',
    'food.food_milk': 'Sữa tách béo một phần',
    'food.food_beef': 'Thịt bò nạc (chiên)',
    'food.food_apple': 'Táo (cả vỏ)',
    'food.food_blueberry': 'Việt quất',
    'food.food_tomato': 'Cà chua',
    'food.food_broccoli': 'Bông cải xanh',
    'food.food_oats': 'Yến mạch cán',
    'food.food_salmon': 'Cá hồi (nuôi, nướng)',
    'food.food_fava_beans': 'Đậu tằm (tươi)',
    'food.food_potato_boiled': 'Khoai tây (luộc)',
    'food.food_walnuts': 'Quả óc chó',
    'food.food_olive_oil': 'Dầu ô liu nguyên chất',
    'food.food_cheddar_cheese': 'Phô mai cheddar',
    'food.food_egg_boiled': 'Trứng (luộc)',
    'food.food_coffee': 'Cà phê (pha, không đường)',
    'observatory.dependency_closure.title':
        'Mức sẵn sàng của bao đóng phụ thuộc',
    'observatory.dependency_closure.loading':
        'Đang tải bản kê khai gốc đã đưa vào kho mã · bao đóng HOLD',
    'observatory.dependency_closure.unavailable':
        'HOLD · không có bản kê khai gốc đã đưa vào kho mã',
    'observatory.dependency_closure.loading_semantics':
        'Đang tải bản kê khai ổn định về gốc kết quả thuật toán. Bao đóng phụ thuộc vẫn ở trạng thái HOLD.',
    'observatory.dependency_closure.unavailable_semantics':
        'Không có bản kê khai ổn định về gốc kết quả thuật toán. Bao đóng phụ thuộc đang ở trạng thái HOLD.',
    'observatory.dependency_closure.semantics':
        '{count} gốc thuật toán ổn định đã đăng ký. Analyzer {analyzer} là mục tiêu rà soát phiên bản chính xác đã khai báo. Bằng chứng tương thích ngoại tuyến không được đóng gói hoặc thực thi trong chế độ xem này. Bao đóng phụ thuộc bắc cầu ở trạng thái HOLD trong khi chờ trình tạo cạnh ParkinSUM.',
    'observatory.dependency_closure.summary':
        '{count} / {total} gốc ổn định · mục tiêu Analyzer đã khai báo {analyzer} · bao đóng bắc cầu HOLD',
    'observatory.dependency_closure.identity': '{schema} · {digest}… · {state}',
    'observatory.dependency_closure.registry_chip':
        'ánh xạ Registry: hợp lệ về cấu trúc',
    'observatory.dependency_closure.edge_chip': 'trình tạo cạnh: HOLD',
    'observatory.dependency_closure.closure_chip': 'bao đóng xuôi/ngược: HOLD',
    'observatory.dependency_closure.details':
        'Bảng gốc ổn định có thể truy cập',
    'observatory.dependency_closure.details_subtitle':
        'Chỉ dùng hạt giống thư viện chính; không có cạnh phụ thuộc được tạo.',
    'observatory.dependency_closure.table_semantics':
        'Bảng các gốc thuật toán ổn định. Các cột gồm thuật toán, gốc logic, đích kết quả và URI gói chuẩn.',
    'observatory.dependency_closure.column_algorithm': 'Thuật toán',
    'observatory.dependency_closure.column_root': 'Gốc logic',
    'observatory.dependency_closure.column_sink': 'Đích kết quả',
    'observatory.dependency_closure.column_uri': 'URI gói',
    'observatory.dependency_closure.boundary':
        'Chế độ xem này chỉ chứng minh hợp đồng cấu trúc Registry-đến-gốc đã được đưa vào kho mã. Bằng chứng tương thích Analyzer ngoại tuyến không được đóng gói hoặc thực thi tại đây. Nội dung này không hiển thị hoặc tuyên bố có đồ thị lời gọi, SCC, bao đóng xuôi/ngược, quá trình thực thi, luồng dữ liệu chính xác, xác thực khoa học hoặc lâm sàng, độ an toàn, lợi ích hay tư vấn y tế.',
  },
};

// =============================================================================
// Remaining locales (th / id / ru / pl / ar) — each is a complete map mirroring
// the en key set that the dashboard / timeline / catalog / onboarding actually
// render, so user-visible UI flips fully into the chosen language without
// English bleed-through.
// =============================================================================
const Map<String, Map<String, String>> kFullLocaleUiTranslationsExtra = {
  // ===========================================================================
  // th (Thai)
  // ===========================================================================
  'th': {
    'reminders.locale_reconciliation_title': 'ภาษาของการเตือนระบบแตกต่างกัน',
    'reminders.locale_reconciliation_body':
        'ภาษาของแอปเปลี่ยนแล้ว คุณสามารถเก็บข้อความการเตือนเดิมหรืออัปเดตการเตือนทั้งหมดบนอุปกรณ์นี้แบบอะตอม ทั้งสองตัวเลือกไม่แสดงป้ายที่คุณเขียน',
    'reminders.locale_retain_action': 'เก็บภาษาการเตือนปัจจุบัน',
    'reminders.locale_update_action': 'อัปเดตทั้งหมดเป็นภาษาปัจจุบัน',
    'reminders.locale_retained_confirmation':
        'เก็บภาษาการเตือนระบบปัจจุบันแล้ว',
    'reminders.locale_updated_confirmation':
        'ขออัปเดตการเตือนระบบทั้งหมดเป็นภาษาปัจจุบันแล้ว',
    'diagnostics.title': 'การวินิจฉัยเชิงวิศวกรรม',
    'diagnostics.rerun': 'เรียกใช้การตรวจสอบอีกครั้ง',
    'diagnostics.scope_title': 'สำหรับการตรวจสอบเชิงวิศวกรรมเท่านั้น',
    'diagnostics.scope_body':
        'นี่คือการตรวจสอบการกำกับดูแลแบบกำหนดผลแน่นอน (การคอมไพล์ข้อความ การตรวจความปลอดภัยของการแปล การเล่นซ้ำสถานการณ์สังเคราะห์) โดยรายงานเฉพาะสถานะทางวิศวกรรมเท่านั้น ไม่เปลี่ยนคะแนน ระดับความรุนแรง หลักฐาน หรือผลลัพธ์ของกฎ และไม่ใช่คำแนะนำด้านสุขภาพ ใช้ข้อมูลสังเคราะห์/สาธิตเท่านั้น',
    'diagnostics.elapsed': 'ตรวจสอบเสร็จสิ้นใน {ms} มิลลิวินาที',
    'reminders.identity_attestation_title':
        'ตรวจสอบข้อมูลประจำตัวคำขอที่รอดำเนินการจากปลั๊กอิน',
    'reminders.identity_attestation_matched':
        'ข้อมูลประจำตัวที่ปลั๊กอินรายงานตรงกับแผน ({installed}/{planned}) นี่ไม่ใช่การตรวจสอบตัวจัดกำหนดการของระบบปฏิบัติการหรือการแสดงการแจ้งเตือนอย่างอิสระ',
    'reminders.identity_attestation_drift':
        'ข้อมูลประจำตัวที่ปลั๊กอินรายงานไม่ตรงกับแผน: ขาด {missing} รายการ เกิน {extra} รายการ และถูกแทนที่ภายใต้ ID ที่วางแผนไว้ {replaced} รายการ อย่าพึ่งพาการแจ้งเตือนระบบจนกว่าจะซิงค์ใหม่สำเร็จ',
    'reminders.identity_attestation_uninspectable':
        'ไม่สามารถอ่านข้อมูลประจำตัวคำขอที่รอดำเนินการจากปลั๊กอินได้ แผนในเครื่องยังเป็นข้อมูลหลัก แต่สถานะการแจ้งเตือนระบบยังไม่ได้รับการยืนยัน',
    'reminders.error_schedule_identity_unverified':
        'บันทึกแผนในเครื่องแล้ว แต่ไม่สามารถจับคู่ข้อมูลประจำตัวที่ปลั๊กอินรายงานกับแผนได้ โปรดซิงค์ใหม่ก่อนพึ่งพาการแจ้งเตือนระบบ',
    'reminders.readiness_title': 'ความพร้อมในการส่งการแจ้งเตือนของระบบ',
    'reminders.readiness_contract': 'สัญญาความสามารถ {platform} · {digest}',
    'reminders.readiness_boundary':
        'คำขอกำหนดเวลาที่เสร็จสมบูรณ์หรือข้อมูลประจำตัวปลั๊กอินที่ตรงกันไม่ได้พิสูจน์การส่งที่มองเห็นได้ บนหน้าจอล็อก หรือในเบื้องหลัง',
    'reminders.readiness_platform_android': 'Android',
    'reminders.readiness_platform_ios': 'iOS',
    'reminders.readiness_platform_macos': 'macOS',
    'reminders.readiness_platform_web': 'Web',
    'reminders.readiness_platform_windows': 'Windows',
    'reminders.readiness_platform_linux': 'Linux',
    'reminders.readiness_platform_unknown':
        'แพลตฟอร์มที่ไม่รู้จักหรือเกตเวย์ที่กำหนดเอง',
    'reminders.readiness_local_plan': 'แผนในเครื่อง',
    'reminders.readiness_adapter': 'อะแดปเตอร์การกำหนดเวลา',
    'reminders.readiness_schedule_request': 'คำขอกำหนดเวลา',
    'reminders.readiness_permission_request': 'คำขอสิทธิ์',
    'reminders.readiness_permission_inspection': 'การตรวจสอบสิทธิ์ปัจจุบัน',
    'reminders.readiness_registry': 'รีจิสทรีรายการรอของปลั๊กอิน',
    'reminders.readiness_visible_delivery': 'การส่งที่มองเห็นได้',
    'reminders.readiness_body_tap': 'การแตะเนื้อหาการแจ้งเตือน',
    'reminders.readiness_cold_start': 'การเริ่มต้นแบบเย็นจากการแจ้งเตือน',
    'reminders.readiness_background_action': 'การทำงานเบื้องหลัง',
    'reminders.readiness_local_none': 'ยังไม่ได้กำหนดแผนในเครื่อง',
    'reminders.readiness_local_saved': 'บันทึกไว้ในอุปกรณ์นี้',
    'reminders.readiness_adapter_plan_only':
        'เก็บเฉพาะแผน; ไม่มีการเรียก API การแจ้งเตือนของระบบ',
    'reminders.readiness_evidence_artifact_verified':
        'ตรวจสอบแล้วด้วยหลักฐานที่ผูกกับอาร์ติแฟกต์ของแพลตฟอร์มเป้าหมาย',
    'reminders.readiness_evidence_implemented_unverified':
        'นำไปใช้แล้ว; ยังไม่มีการตรวจสอบบนอุปกรณ์เป้าหมายที่ผูกกับอาร์ติแฟกต์',
    'reminders.readiness_evidence_unavailable':
        'ไม่พร้อมใช้หรือยังไม่ได้ดำเนินการ',
    'reminders.readiness_request_not_requested': 'ยังไม่ได้ส่ง',
    'reminders.readiness_request_applied':
        'คำขอปลั๊กอินเสร็จสิ้น; ยังไม่พิสูจน์การส่ง',
    'reminders.readiness_request_rolled_back':
        'คำขอกำหนดเวลาใหม่ถูกย้อนกลับและกู้คืนแผนเดิมแล้ว; ไม่ได้พิสูจน์การส่ง',
    'reminders.readiness_request_superseded':
        'ถูกแทนที่ด้วยบัญชีหรือแผนที่ใหม่กว่า',
    'reminders.readiness_request_unsupported': 'สัญญานี้เก็บเฉพาะแผน',
    'reminders.readiness_request_failed':
        'คำขอล้มเหลวหรือยังไม่ได้ตรวจสอบข้อมูลประจำตัว',
    'reminders.readiness_request_recovery_required':
        'ต้องกระทบยอดก่อนจึงจะพึ่งพาได้',
    'reminders.readiness_permission_not_requested': 'ยังไม่ได้ขอในเซสชันนี้',
    'reminders.readiness_permission_granted':
        'การเรียกขอสิทธิ์ตอบกลับว่าอนุญาต; ไม่เท่ากับสถานะปัจจุบัน',
    'reminders.readiness_permission_denied':
        'การเรียกขอสิทธิ์ตอบกลับว่าไม่อนุญาต; ไม่ได้พิสูจน์ว่าผู้ใช้ปฏิเสธอย่างชัดเจน',
    'reminders.readiness_permission_failed':
        'คำขอสิทธิ์ล้มเหลวหรืออะแดปเตอร์ไม่พร้อมใช้งาน; ไม่ได้หมายความว่าผู้ใช้ปฏิเสธ',
    'reminders.readiness_permission_unavailable':
        'สัญญาความสามารถนี้ไม่ขอสิทธิ์',
    'reminders.readiness_inspection_not_inspected':
        'ยังไม่ได้ตรวจสอบสถานะสิทธิ์ปัจจุบัน',
    'reminders.readiness_inspection_enabled':
        'การตรวจสอบปัจจุบันของปลั๊กอินตอบกลับว่าเปิดใช้งาน; ไม่ใช่หลักฐานการส่ง',
    'reminders.readiness_inspection_disabled':
        'การตรวจสอบปัจจุบันของปลั๊กอินตอบกลับว่าปิดใช้งาน; ไม่ได้ระบุสาเหตุหรือการเลือกของผู้ใช้',
    'reminders.readiness_inspection_unavailable':
        'ไม่สามารถตรวจสอบสถานะสิทธิ์ปัจจุบันได้; ไม่ได้หมายความว่าผู้ใช้ปฏิเสธ',
    'reminders.readiness_inspection_failed':
        'การตรวจสอบสถานะสิทธิ์ปัจจุบันล้มเหลว; ไม่ได้หมายความว่าผู้ใช้ปฏิเสธ',
    'reminders.readiness_registry_not_inspected': 'ยังไม่ได้ตรวจสอบ',
    'reminders.readiness_registry_matched':
        'รายงานปลั๊กอินตรงกับแผนในเครื่อง; ไม่ใช่หลักฐานการส่งของระบบปฏิบัติการ',
    'reminders.readiness_registry_drift': 'รายงานปลั๊กอินต่างจากแผนในเครื่อง',
    'reminders.readiness_registry_uninspectable':
        'ไม่สามารถอ่านข้อมูลประจำตัวของปลั๊กอินได้',
    'reminders.readiness_registry_unsupported':
        'สัญญาความสามารถนี้ไม่ตรวจสอบรีจิสทรีเนทีฟ',
    'reminders.readiness_visible_unverified': 'ยังไม่ได้ตรวจสอบ',
    'reminders.readiness_visible_artifact_verified':
        'ตรวจสอบแล้วด้วยหลักฐานอาร์ติแฟกต์ของแพลตฟอร์มเป้าหมาย',
    'app.welcome': 'ยินดีต้อนรับ',
    'app.loading': 'กำลังโหลด...',
    'onboarding.title': 'ParkinSUM เพื่อนคู่ใจ (ฉบับในเครื่อง)',
    'onboarding.description':
        'แอปนี้ใช้สำหรับบันทึกมื้ออาหารและคำแนะนำตามกฎเท่านั้น ไม่ได้ทดแทนคำแนะนำจากแพทย์หรือเภสัชกรของคุณ',
    'onboarding.registration_region': 'ภูมิภาคการลงทะเบียน',
    'onboarding.registration_region_help':
        'กำหนดเชนเขตอำนาจเริ่มต้นและลำดับความสำคัญของแหล่งข้อมูล',
    'onboarding.display_language': 'ภาษาที่แสดง',
    'onboarding.display_language_help': 'ควบคุมภาษาแอป รูปแบบวันที่และตัวเลข',
    'onboarding.diet_profile_region': 'ภูมิภาคโปรไฟล์อาหาร',
    'onboarding.diet_profile_region_help':
        'ใช้สำหรับเทมเพลตมื้ออาหารเริ่มต้นโดยไม่ลบล้างกฎความปลอดภัย',
    'onboarding.swallowing_texture_mode':
        'โหมดความปลอดภัยการกลืน / เนื้อสัมผัส',
    'onboarding.swallowing_texture_mode_help':
        'ใช้เป็นตัวเลือกคำแนะนำเชิงอนุรักษ์นิยม ไม่ใช่การประเมินการกลืนทางคลินิก',
    'onboarding.content_override': 'การแทนที่เขตอำนาจเนื้อหา (ไม่บังคับ)',
    'onboarding.content_override_help': 'คั่นด้วยจุลภาค เช่น US,CA',
    'onboarding.local_ai_consent':
        'เปิดการจัดอันดับใหม่ด้วย AI ในเครื่อง (ไม่บังคับ)',
    'onboarding.local_ai_consent_help':
        'ใช้เฉพาะ Ollama/llama.cpp บน localhost และเปลี่ยนกลับไปยังเส้นทางอนุรักษ์เมื่อประตูความปลอดภัยปิดกั้น',
    'onboarding.start': 'รับทราบ ดำเนินการต่อ',
    'nav.home': 'หน้าแรก',
    'nav.analytics': 'การวิเคราะห์',
    'nav.meals': 'มื้ออาหาร',
    'nav.timeline': 'ไทม์ไลน์',
    'nav.meds': 'ยา',
    'nav.catalog': 'แค็ตตาล็อก',
    'nav.next_meal': 'มื้อถัดไป',
    'shell.tagline': 'แอปคู่หู · ต้นแบบเพื่อการวิจัย',
    'shell.workspace': 'พื้นที่ทำงาน',
    'shell.care_workspace': 'เตรียมพบแพทย์และติดตาม',
    'shell.boundary_note':
        'ต้นแบบเพื่อการศึกษา — ไม่ใช่คำแนะนำทางการแพทย์ โปรดทบทวนการตัดสินใจด้านสุขภาพกับแพทย์ผู้มีคุณสมบัติ',
    'dashboard.greeting_morning': 'สวัสดีตอนเช้า',
    'dashboard.greeting_afternoon': 'สวัสดีตอนบ่าย',
    'dashboard.greeting_evening': 'สวัสดีตอนเย็น',
    'dashboard.subtitle':
        'ภาพรวมของมื้ออาหาร การใช้ยาที่บันทึกไว้ และกฎเบื้องหลังคำอธิบายแต่ละข้อ',
    'dashboard.stat_meals': 'มื้อที่บันทึก',
    'dashboard.stat_drugs': 'ยาที่ใช้อยู่',
    'dashboard.stat_intakes': 'การใช้ยาที่บันทึก',
    'shell.new_entry': 'รายการใหม่',
    'shell.search': 'ค้นหา',
    'shell.search_hint': 'ค้นหาหน้า เครื่องมือ และการทำงาน',
    'shell.search_empty': 'ไม่พบหน้า เครื่องมือ หรือการทำงานที่ตรงกัน',
    'shell.menu': 'เมนู',
    'shell.group.evidence': 'หลักฐานและกฎ',
    'shell.group.data': 'ข้อมูลของคุณ',
    'shell.group.operations': 'การดำเนินงาน',
    'shell.group.pages': 'หน้า',
    'shell.action.observation': 'บันทึกการสังเกต',
    'dashboard.stat_protein': 'โปรตีนเฉลี่ยต่อมื้อ',
    'dashboard.show_details': 'แสดงรายละเอียด',
    'dashboard.hide_details': 'ซ่อนรายละเอียด',
    'dashboard.quick_log': 'บันทึกด่วน',
    'dashboard.today': 'กิจกรรมล่าสุด',
    'insights.title': 'ข้อมูลเชิงลึก',
    'insights.subtitle': 'รูปแบบจากสิ่งที่คุณบันทึกไว้เท่านั้น',
    'insights.range_7': '7 วัน',
    'insights.range_30': '30 วัน',
    'insights.meals': 'มื้ออาหาร',
    'insights.intakes': 'การใช้ยา',
    'insights.observations': 'การสังเกต',
    'insights.avg_protein': 'โปรตีนเฉลี่ยต่อมื้อ',
    'insights.rhythm_title': 'จังหวะการบันทึก',
    'insights.rhythm_subtitle': 'จำนวนรายการต่อวัน',
    'insights.protein_title': 'โปรตีนต่อมื้อ',
    'insights.protein_subtitle': 'กรัมต่อมื้อที่บันทึก จากเก่าไปใหม่',
    'insights.daypart_title': 'ช่วงเวลาของวัน',
    'insights.daypart_subtitle': 'ช่วงเวลาที่บันทึกมื้ออาหารและการใช้ยา',
    'insights.morning': 'เช้า',
    'insights.midday': 'กลางวัน',
    'insights.evening': 'เย็น',
    'insights.night': 'กลางคืน',
    'insights.empty': 'ยังไม่มีการบันทึกในช่วงเวลานี้',
    'insights.boundary':
        'นี่เป็นสรุปเชิงพรรณนาจากบันทึกของคุณเอง ไม่ใช่การวัดทางคลินิก เป้าหมาย หรือคำแนะนำ โปรดทบทวนการตัดสินใจด้านสุขภาพกับแพทย์ผู้มีคุณสมบัติ',
    'settings.local_ai_advanced': 'ขั้นสูง · การเชื่อมต่อ AI ในเครื่อง',
    'nav.today': 'วันนี้',
    'nav.library': 'คลังข้อมูล',
    'dashboard.log_prompt': 'ต้องการบันทึกอะไร?',
    'dashboard.log_meal_hint': 'อาหารและปริมาณ ตรวจตามกฎเพื่อการศึกษา',
    'dashboard.log_intake_hint': 'ยาหนึ่งครั้งที่คุณใช้',
    'dashboard.log_observation_hint':
        'ความดันโลหิต อาการ หรือสภาวะการเคลื่อนไหว',
    'dashboard.open_timeline': 'เปิดไทม์ไลน์',
    'dashboard.open_next_meal': 'เปิดมื้อถัดไป',
    'library.my_medications': 'ยาของฉัน',
    'library.catalog': 'อาหารและยา',
    'next_meal.title': 'คำแนะนำมื้อถัดไป',
    'next_meal.subtitle':
        'เลือกเวลามื้อถัดไป เส้นทางกฎแบบระมัดระวังคงลำดับตัวเลือกไว้ แบบจำลองเชิงกลเพิ่มเพียงร่องรอยการทับซ้อนตามเวลาเพื่อการศึกษาและไม่จัดอันดับใหม่ ส่วน AI ในเครื่องเป็นตัวเลือกแยกต่างหากที่จัดลำดับเฉพาะรายการปลอดภัย',
    'next_meal.input_time': 'เวลามื้อถัดไปที่คาดไว้',
    'next_meal.use_local_ai': 'ใช้ AI ในเครื่องปรับสำนวน (ทางเลือก)',
    'next_meal.use_local_ai_help':
        'เรียกเฉพาะ Ollama/llama.cpp บน localhost เพื่อจัดอันดับใหม่และเขียนคำอธิบายของตัวเลือกที่เครื่องยนต์อนุมัติแล้ว และจะกลับไปยังเส้นทางอนุรักษ์เมื่อประตูความปลอดภัยปิดกั้น',
    'next_meal.generate': 'สร้างคำแนะนำ',
    'next_meal.generating': 'กำลังสร้าง…',
    'next_meal.empty':
        'กำหนดเวลาแล้วแตะ "สร้างคำแนะนำ" เครื่องยนต์จะประเมินใหม่ตามช่วงเวลานั้น',
    'next_meal.why_these': 'ทำไมจึงเลือกสิ่งเหล่านี้',
    'next_meal.ai_polished': 'AI ในเครื่องปรับสำนวนแล้ว',
    'next_meal.conservative_engine': 'เส้นทางอนุรักษ์ของเครื่องยนต์ความขัดแย้ง',
    'next_meal.recommendation_path': 'เส้นทางคำแนะนำ',
    'next_meal.gate_reasons': 'หมายเหตุประตูความปลอดภัย',
    'next_meal.candidates': 'ตัวเลือกอันดับต้น',
    'next_meal.no_candidates':
        'ไม่มีตัวเลือกที่เหมาะสมภายใต้ข้อจำกัดปัจจุบัน โปรดปรับเวลาหรือขยายแค็ตตาล็อกอาหาร',
    'next_meal.error': 'การสร้างล้มเหลว',
    'dashboard.title': 'แดชบอร์ด',
    'dashboard.status': 'ภาพรวม',
    'dashboard.logged_meals': 'มื้ออาหารที่บันทึก: {count}',
    'dashboard.active_drugs': 'ยาที่ใช้อยู่: {count}',
    'dashboard.logged_intakes': 'การรับประทานยา: {count}',
    'dashboard.recommendations': 'คำแนะนำ',
    'dashboard.no_recommendations': 'ยังไม่มีคำแนะนำ',
    'dashboard.recommendation_path': 'เส้นทางคำแนะนำ',
    'dashboard.recommendation_template':
        'เทมเพลตที่ใช้: {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'ใช้การเสริมด้วย AI ในเครื่อง',
    'dashboard.ai_not_used': 'เส้นทางอนุรักษ์เท่านั้น',
    'dashboard.recommendation_why': 'เหตุผลของคำแนะนำเหล่านี้',
    'dashboard.recommendation_gate': 'สถานะประตู AI / ความปลอดภัย',
    'dashboard.recommendation_macro_line':
        'ต่อ 100 ก.: P {protein} ก. · C {carbs} ก. · F {fat} ก.',
    'dashboard.recommendation_score_line':
        'ปลอดภัย {safety} · ตาราง {schedule} · ข้อเท็จจริง {facts} · ลงโทษบริบท {context} · ลงโทษหน้าต่าง {timing} · ลงโทษการกลืน {swallowing} · เทียบเทมเพลต {template}',
    'dashboard.recent_meals': 'มื้ออาหารล่าสุด (5 รายการล่าสุด)',
    'dashboard.no_meals': 'ยังไม่มีการบันทึกมื้ออาหาร',
    'dashboard.items': '{count} รายการ',
    'dashboard.meal_context_iron_supplement':
        'เหตุการณ์ร่วมกับอาหารเสริมธาตุเหล็ก',
    'dashboard.meal_context_iron_multivitamin':
        'เหตุการณ์ร่วมกับวิตามินรวมที่มีธาตุเหล็ก',
    'dashboard.meal_context_starch_thickener': 'สารเพิ่มความข้นชนิดแป้ง',
    'dashboard.meal_context_xanthan_thickener': 'สารเพิ่มความข้นชนิดแซนแทน',
    'dashboard.meal_context_enteral_feed_continuous':
        'ให้สารอาหารทางลำไส้แบบต่อเนื่อง ({protein} ก./วัน โปรตีน)',
    'dashboard.meal_context_enteral_feed_bolus':
        'ให้สารอาหารทางลำไส้แบบโบลัส/เป็นช่วง',
    'dashboard.edit': 'แก้ไข',
    'dashboard.delete': 'ลบ',
    'dashboard.protein_trend': 'แนวโน้มโปรตีน',
    'dashboard.average_protein': 'โปรตีนเฉลี่ย: {value} ก./มื้อ',
    'dashboard.no_trend': 'ยังไม่มีข้อมูลแนวโน้ม',
    'dashboard.timeline': 'ไทม์ไลน์',
    'dashboard.no_timeline': 'ยังไม่มีเหตุการณ์มื้ออาหารหรือยา',
    'dashboard.add_meal': 'เพิ่มมื้ออาหาร',
    'dashboard.meal_check': 'ตรวจสอบมื้ออาหาร - {title}',
    'timeline.title': 'ไทม์ไลน์มื้ออาหารและยา',
    'timeline.empty': 'ยังไม่มีมื้ออาหารหรือการรับประทานยา',
    'timeline.add_meal': 'เพิ่มมื้ออาหาร',
    'timeline.add_intake': 'บันทึกการกินยา',
    'timeline.new_intake': 'การกินยาใหม่',
    'timeline.edit_intake': 'แก้ไขการกินยา',
    'timeline.medication': 'ยา',
    'timeline.active_medication_option': '{name} (ใช้อยู่)',
    'timeline.dosage_note': 'บันทึกขนาดยา',
    'timeline.package_dose_source':
        'แหล่งที่มา: {source} · เวลาที่ดึงข้อมูล: {retrieved} · {url}',
    'timeline.package_dose_derivation':
        'การคำนวณ: {strength} × {quantity} {unit} = {amount} {resultUnit}',
    'timeline.package_dose_assumed_denominator':
        'แหล่งข้อมูลไม่ได้ระบุตัวหาร จึงสมมติว่าเป็นหน่วยรูปแบบยาแยกหนึ่งหน่วย ({unit}) โปรดตรวจสอบฉลากผลิตภัณฑ์ก่อนยืนยัน',
    'timeline.package_dose_retrieval_unknown': 'ไม่ได้บันทึก',
    'timeline.taken_at': 'รับประทานเมื่อ',
    'timeline.edit_taken_at': 'แก้ไขเวลารับประทาน',
    'timeline.save_intake': 'บันทึกการรับประทาน',
    'timeline.no_medications': 'ไม่มีแค็ตตาล็อกยา',
    'timeline.select_medication_first': 'กรุณาเลือกยาก่อน',
    'timeline.save_intake_failed': 'บันทึกการรับประทานล้มเหลว: {error}',
    'timeline.meal_macro_line':
        'รวม: โปรตีน {protein} ก. · คาร์บ {carbs} ก. · ไขมัน {fat} ก.',
    'timeline.conflict_line': 'ตรวจสอบความขัดแย้ง: {severity} · คะแนน {score}',
    'timeline.meal_window_line': 'ช่วงมื้ออาหาร: {start} - {end}',
    'timeline.next_meal_window_line': 'ช่วงมื้อถัดไป: {start} - {end}',
    'timeline.nearest_medication_line': 'ยาใกล้สุด: {name} ({distance})',
    'timeline.nearest_meal_line': 'มื้อใกล้สุด: {title} ({distance})',
    'timeline.dosage_line': 'ขนาดยา: {value}',
    'timeline.before': 'ก่อน {value}',
    'timeline.after': 'หลัง {value}',
    'timeline.no_context_flags':
        'ไม่มีแฟล็กอาหารเสริม สารเพิ่มความข้น หรือการให้อาหารทางลำไส้',
    'common.close': 'ปิด',
    'common.done': 'เสร็จสิ้น',
    'common.cancel': 'ยกเลิก',
    'common.apply': 'นำไปใช้',
    'common.optional': 'ไม่บังคับ',
    'analytics.local_ai_medical_model': 'ชื่อโมเดลทบทวนทางการแพทย์',
    'common.delete': 'ลบ',
    'common.completed': 'เสร็จสมบูรณ์',
    'common.error': 'ข้อผิดพลาด',
    'common.search_results': 'ผลการค้นหา',
    'common.no_matching_foods': 'ไม่พบอาหารที่ตรงกัน',
    'common.texture': 'เนื้อสัมผัส',
    'common.not_available': 'ยังไม่ได้กรอก',
    'common.save': 'บันทึก',
    'common.edit': 'แก้ไข',
    'common.confirm': 'ยืนยัน',
    'common.sign_out': 'ออกจากระบบ',
    'meal_slot.breakfast': 'อาหารเช้า',
    'meal_slot.lunch': 'อาหารกลางวัน',
    'meal_slot.dinner': 'อาหารเย็น',
    'meal_slot.snack': 'ของว่าง',
    'meal.title': 'มื้ออาหาร',
    'meal.empty': 'ยังไม่มีการบันทึกมื้ออาหาร',
    'meal.check_title': 'ตรวจสอบมื้ออาหาร - {title}',
    'medications.title': 'ยา',
    'catalog.title': 'แค็ตตาล็อก',
    'catalog.search': 'ค้นหาอาหารหรือยา',
    'catalog.foods': 'อาหาร',
    'catalog.drugs': 'ยา',
    'catalog.food_subtitle':
        'หมวดหมู่={category}  P/C/F={protein}/{carbs}/{fat} (ต่อ 100 ก.)',
    'catalog.drug_subtitle': 'แท็ก={tags}',
    'medications.view_detail': 'ดูรายละเอียดยา',
    'decision.block': 'ปิดกั้น',
    'decision.require_review': 'ต้องตรวจสอบ',
    'decision.discourage': 'ไม่แนะนำ',
    'decision.warn': 'เตือน',
    'decision.info': 'ข้อมูล',
    'decision.allow': 'อนุญาต',
    'decision.defer': 'เลื่อน',
    'severity.low': 'ต่ำ',
    'severity.moderate': 'ปานกลาง',
    'severity.high': 'สูง',
    'severity.critical': 'รุนแรง',
    'missing.dose': 'ขนาดยา',
    'missing.formulation': 'รูปแบบยา',
    'missing.time': 'เวลารับประทานยา',
    'missing.meal_time': 'เวลามื้ออาหาร',
    'missing.coevent_time': 'เวลาเหตุการณ์ร่วม',
    'missing.thickener_type': 'ชนิดสารเพิ่มความข้น',
    'recommend.low_protein': 'ควรเลือกโปรตีนต่ำกว่า',
    'recommend.protein_window_caution':
        'ระมัดระวังโปรตีนสูงใกล้ช่วงเวลาเลโวโดปา',
    'recommend.history_low_protein':
        'ประวัติล่าสุดแนะนำให้เลือกตัวเลือกโปรตีนต่ำก่อน',
    'recommend.culture_match': 'เข้ากับเทมเพลตอาหารภูมิภาคปัจจุบัน',
    'recommend.fallback_chain': 'ความรู้อาหารของภูมิภาคนี้กำลังใช้เชนสำรอง',
    'recommend.general_friendly': 'ตัวเลือกที่เหมาะสมโดยทั่วไป',
    'recommend.path.hybrid_local_ai': 'AI ในเครื่องช่วยจัดอันดับใหม่',
    'recommend.path.conservative_safety_gate':
        'เส้นทางอนุรักษ์ (ประตูความปลอดภัยปิด AI)',
    'recommend.path.conservative_gate_block':
        'เส้นทางอนุรักษ์ (AI ในเครื่องใช้ไม่ได้)',
    'recommend.path.fallback_invalid_ai':
        'เส้นทางอนุรักษ์ (ผลลัพธ์ AI ไม่ผ่านการตรวจสอบ)',
    'recommend.path.conservative_cdss': 'เส้นทาง CDSS อนุรักษ์',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'ไม่มีบริการ Ollama หรือ llama.cpp บน localhost ตอบสนอง โปรดเริ่มบริการโมเดลในเครื่องหรือปิดการจัดอันดับใหม่ด้วย AI ในเครื่อง',
    'recommend.runtime.endpoint_must_be_localhost':
        'จุดปลายทาง AI ในเครื่องต้องอยู่ที่ localhost/127.0.0.1 และไม่สามารถชี้ไปยังจุดปลายทางคลาวด์',
    'recommend.runtime.safety_gate_conservative':
        'ประตูความปลอดภัยทำให้ผลลัพธ์อยู่ในเส้นทางอนุรักษ์',
    'recommend.runtime.next_meal_window_missing':
        'ไม่มีช่วงเวลามื้อถัดไปที่คาดไว้ กรุณาเพิ่มเวลาเร็วสุดและช้าสุดในเพิ่ม/แก้ไขมื้ออาหาร',
    'recommend.runtime.no_prior_meal_history':
        'ไม่มีประวัติมื้ออาหารก่อนหน้าสำหรับการจัดอันดับใหม่อย่างปลอดภัย',
    'recommend.runtime.legacy_meal_time':
        'มื้อล่าสุดยังใช้เวลาแบบเดิมที่ย้ายมา ให้แก้ไขเป็นเวลาที่ทานจริง',
    'recommend.runtime.iron_conservative':
        'มื้อล่าสุดบันทึกอาหารเสริมธาตุเหล็ก การจัดอันดับใหม่จึงคงความอนุรักษ์',
    'recommend.runtime.iron_multivitamin_conservative':
        'มื้อล่าสุดบันทึกวิตามินรวมที่มีธาตุเหล็ก การจัดอันดับใหม่จึงคงความอนุรักษ์',
    'recommend.runtime.starch_thickener_conservative':
        'มื้อล่าสุดบันทึกสารเพิ่มความข้นชนิดแป้ง จึงคงการตรวจสอบความปลอดภัยแบบกำหนดได้',
    'recommend.runtime.enteral_conservative':
        'บริบทการให้สารอาหารทางลำไส้แบบต่อเนื่องกำลังทำงาน จึงคงการตรวจสอบแบบกำหนดได้',
    'recommend.runtime.local_ai_not_consented':
        'ผู้ใช้ยังไม่ได้เปิดการจัดอันดับใหม่ด้วย AI ในเครื่อง',
    'recommend.runtime.local_ai_unavailable':
        'จุดปลายทาง AI ในเครื่องไม่สามารถใช้งานได้ในขณะนี้',
    'recommend.runtime.returned_conservative':
        'ส่งคืนคำแนะนำอนุรักษ์แบบกำหนดได้แทน',
    'recommend.runtime.ai_validation_failed':
        'ผลลัพธ์โครงสร้างของ AI ในเครื่องไม่ผ่านการตรวจสอบรายการอนุญาต',
    'recommend.runtime.ai_invalid_whitelist':
        'AI ในเครื่องไม่ส่งลำดับที่ถูกต้องตามรายการอนุญาตเท่านั้น ผลลัพธ์จึงไม่ถูกใช้',
    'recommend.runtime.cdss_conservative_observations':
        'เส้นทาง CDSS อนุรักษ์ใช้การสังเกตชนิดจริงเมื่อมี',
    'recommend.runtime.local_ai_success':
        'การจัดอันดับใหม่ด้วย AI ในเครื่องสำเร็จ',
    'recommend.runtime.local_ai_copy_polish_success':
        'AI ในเครื่องได้ปรับถ้อยคำให้อ่านง่ายขึ้น',
    'recommend.runtime.medgemma_optional_unavailable':
        'จุดปลายทาง AI ในเครื่องตอบสนองแล้ว แต่โมเดล MedGemma แบบไม่บังคับยังไม่พร้อมใช้งาน',
    'recommend.runtime.recommendation_conservative':
        'คำแนะนำคงอยู่บนเส้นทางอนุรักษ์',
    'recommend.runtime.levodopa_ai_sensitive':
        'ช่วงเวลาเลโวโดปาไวเกินกว่าจะใช้การจัดอันดับใหม่ด้วย AI',
    'recommend.context_iron_supplement':
        'บันทึกอาหารเสริมธาตุเหล็กกับมื้อล่าสุด คำแนะนำเรื่องเวลาจึงคงความอนุรักษ์',
    'recommend.context_iron_multivitamin':
        'บันทึกวิตามินรวมที่มีธาตุเหล็กกับมื้อล่าสุด คำแนะนำเรื่องเวลาจึงคงความอนุรักษ์',
    'recommend.context_starch_thickener':
        'บันทึกสารเพิ่มความข้นชนิดแป้ง ซึ่งเพิ่มความสำคัญของความปลอดภัยในการกลืน',
    'recommend.context_xanthan_thickener':
        'บันทึกสารเพิ่มความข้นชนิดแซนแทนสำหรับมื้อล่าสุด',
    'recommend.context_enteral_feed_continuous':
        'การให้สารอาหารทางลำไส้แบบต่อเนื่องกำลังทำงาน ({protein} ก./วัน โปรตีน) ถ้อยคำคำแนะนำจึงคงความอนุรักษ์',
    'recommend.context_enteral_feed_bolus':
        'บันทึกการให้สารอาหารทางลำไส้แบบโบลัส/เป็นช่วงสำหรับมื้อล่าสุด',
    'recommend.context_iron_penalty':
        'มีเหตุการณ์ร่วมเกี่ยวกับธาตุเหล็ก ตัวเลือกโปรตีนสูงจึงถูกลดอันดับอย่างอนุรักษ์',
    'recommend.context_enteral_penalty':
        'มีบริบทการให้สารอาหารทางลำไส้แบบต่อเนื่อง ตัวเลือกโปรตีนสูงจึงถูกลดอันดับอย่างอนุรักษ์',
    'recommend.context_texture_gap_penalty':
        'บันทึกสารเพิ่มความข้น แต่แค็ตตาล็อกยังขาดข้อมูลความเข้ากันได้ของเนื้อสัมผัสแบบมีโครงสร้าง จึงคงระยะปลอดภัยอนุรักษ์เพิ่ม',
    'recommend.context_texture_supported':
        'บันทึกสารเพิ่มความข้น และผู้สมัครนี้มีเมตาดาทาเนื้อสัมผัสแบบมีโครงสร้างอยู่แล้ว ค่าปรับช่องว่างข้อมูลจึงต่ำลง',
    'recommend.texture_profile_missing':
        'โหมดความปลอดภัยเนื้อสัมผัสกำลังทำงาน แต่ผู้สมัครนี้ขาดเมตาดาทาเนื้อสัมผัสแบบมีโครงสร้าง การจัดอันดับจึงอนุรักษ์ขึ้น',
    'recommend.texture_profile_supported_soft_or_liquid':
        'ผู้สมัครนี้ตรงกับโหมดความปลอดภัยเนื้อสัมผัสนุ่มหรือเหลวปัจจุบัน',
    'recommend.texture_profile_supported_liquid_only':
        'ผู้สมัครนี้ตรงกับโหมดความปลอดภัยเนื้อสัมผัสของเหลวเท่านั้นปัจจุบัน',
    'recommend.texture_profile_incompatible':
        'ผู้สมัครนี้ไม่ตรงกับโหมดความปลอดภัยเนื้อสัมผัสปัจจุบัน จึงถูกลดอันดับอย่างอนุรักษ์',
    'recommend.texture_template_supported':
        'ผู้สมัครนี้ตรงกับทิศทางเนื้อสัมผัสของเทมเพลตมื้ออาหารปัจจุบัน',
    'recommend.texture_template_mismatch':
        'ผู้สมัครนี้ไม่ตรงกับทิศทางเนื้อสัมผัสของเทมเพลตมื้ออาหารปัจจุบัน',
    'recommend.local_seed_metadata':
        'ผู้สมัครนี้ยังพึ่งพาเมตาดาทาเมล็ดพันธุ์ในเครื่องแทนที่จะใช้การสังเกตที่หนุนด้วยฐานข้อมูลที่หลากหลายกว่า',
    'recommend.timing_window_incomplete':
        'ช่วงเวลาไม่ครบถ้วน การจัดอันดับอนุรักษ์จึงคงระยะปลอดภัยเพิ่ม',
    'recommend.next_meal_gap_close':
        'ช่วงมื้อถัดไปยังใกล้กับมื้อก่อน ควรเลือกตัวเลือกโปรตีนต่ำกว่า',
    'recommend.next_meal_window_fiber':
        'พอดีกับช่วงมื้อถัดไปที่วางแผนไว้และเอื้อต่อการได้รับใยอาหารที่สม่ำเสมอ',
    'recommend.medication_timing_caution':
        'ช่วงเวลาของยาแนะนำให้ระมัดระวังเพิ่มสำหรับช่วงมื้อถัดไปนี้',
    'texture_mode.unrestricted': 'ไม่มีข้อจำกัด',
    'texture_mode.soft_or_liquid': 'นุ่มหรือเหลว',
    'texture_mode.liquid_only': 'ของเหลวเท่านั้น',
    'texture_class.liquid': 'ของเหลว',
    'texture_class.soft': 'นุ่ม',
    'texture_class.regular': 'ปกติ',
    'food.food_chicken_breast': 'อกไก่ (ปรุงสุก)',
    'food.food_tofu': 'เต้าหู้ธรรมดา',
    'food.food_brown_rice': 'ข้าวกล้อง',
    'food.food_banana': 'กล้วย',
    'food.food_spinach': 'ผักโขม',
    'food.food_milk': 'นมพร่องมันเนย',
    'food.food_beef': 'เนื้อวัวไม่ติดมัน (ทอด)',
    'food.food_apple': 'แอปเปิ้ล (ทั้งเปลือก)',
    'food.food_blueberry': 'บลูเบอร์รี่',
    'food.food_tomato': 'มะเขือเทศ',
    'food.food_broccoli': 'บร็อคโคลี่',
    'food.food_oats': 'ข้าวโอ๊ตอบ',
    'food.food_salmon': 'แซลมอน (เลี้ยง อบ)',
    'food.food_fava_beans': 'ถั่วฟาวา (สด)',
    'food.food_potato_boiled': 'มันฝรั่ง (ต้ม)',
    'food.food_walnuts': 'วอลนัท',
    'food.food_olive_oil': 'น้ำมันมะกอกบริสุทธิ์พิเศษ',
    'food.food_cheddar_cheese': 'ชีสเชดดาร์',
    'food.food_egg_boiled': 'ไข่ (ต้ม)',
    'food.food_coffee': 'กาแฟ (ชง ไม่หวาน)',
    'observatory.dependency_closure.title': 'ความพร้อมของการปิดการพึ่งพา',
    'observatory.dependency_closure.loading':
        'กำลังโหลดแมนิเฟสต์รากที่เช็กอินไว้ · การปิด HOLD',
    'observatory.dependency_closure.unavailable':
        'HOLD · ไม่มีแมนิเฟสต์รากที่เช็กอินไว้',
    'observatory.dependency_closure.loading_semantics':
        'กำลังโหลดแมนิเฟสต์รากผลลัพธ์อัลกอริทึมแบบคงที่ การปิดการพึ่งพายังคงอยู่ในสถานะ HOLD',
    'observatory.dependency_closure.unavailable_semantics':
        'ไม่มีแมนิเฟสต์รากผลลัพธ์อัลกอริทึมแบบคงที่ การปิดการพึ่งพาอยู่ในสถานะ HOLD',
    'observatory.dependency_closure.semantics':
        'มีรากอัลกอริทึมที่ลงทะเบียนและคงที่ {count} รายการ Analyzer {analyzer} คือเป้าหมายการตรวจสอบเวอร์ชันตรงรุ่นที่ประกาศไว้ หลักฐานความเข้ากันได้แบบออฟไลน์ไม่ได้รวมอยู่หรือทำงานในมุมมองนี้ การปิดการพึ่งพาแบบทรานซิทีฟอยู่ในสถานะ HOLD เพื่อรอตัวสร้างเอดจ์ของ ParkinSUM',
    'observatory.dependency_closure.summary':
        'รากคงที่ {count} / {total} · เป้าหมาย Analyzer ที่ประกาศ {analyzer} · การปิดทรานซิทีฟ HOLD',
    'observatory.dependency_closure.identity': '{schema} · {digest}… · {state}',
    'observatory.dependency_closure.registry_chip':
        'การแมป Registry: โครงสร้างถูกต้อง',
    'observatory.dependency_closure.edge_chip': 'ตัวสร้างเอดจ์: HOLD',
    'observatory.dependency_closure.closure_chip':
        'การปิดไปข้างหน้า/ย้อนกลับ: HOLD',
    'observatory.dependency_closure.details': 'ตารางรากคงที่ที่เข้าถึงได้',
    'observatory.dependency_closure.details_subtitle':
        'ใช้เฉพาะซีดของไลบรารีหลัก ไม่มีเอดจ์การพึ่งพาที่สร้างขึ้น',
    'observatory.dependency_closure.table_semantics':
        'ตารางรากอัลกอริทึมแบบคงที่ คอลัมน์ประกอบด้วยอัลกอริทึม รากเชิงตรรกะ ปลายทางผลลัพธ์ และ URI แพ็กเกจแบบมาตรฐาน',
    'observatory.dependency_closure.column_algorithm': 'อัลกอริทึม',
    'observatory.dependency_closure.column_root': 'รากเชิงตรรกะ',
    'observatory.dependency_closure.column_sink': 'ปลายทางผลลัพธ์',
    'observatory.dependency_closure.column_uri': 'URI แพ็กเกจ',
    'observatory.dependency_closure.boundary':
        'มุมมองนี้พิสูจน์เฉพาะสัญญาโครงสร้าง Registry-ถึง-รากที่เช็กอินไว้ หลักฐานความเข้ากันได้ของ Analyzer แบบออฟไลน์ไม่ได้รวมอยู่หรือทำงานที่นี่ และไม่ได้แสดงหรืออ้างว่ามีกราฟการเรียก, SCC, การปิดไปข้างหน้า/ย้อนกลับ, การทำงานจริง, การไหลของข้อมูลที่แม่นยำ, การตรวจสอบทางวิทยาศาสตร์หรือทางคลินิก, ความปลอดภัย, ประโยชน์ หรือคำแนะนำทางการแพทย์',
  },

  // ===========================================================================
  // id (Indonesian)
  // ===========================================================================
  'id': {
    'reminders.locale_reconciliation_title': 'Bahasa pengingat sistem berbeda',
    'reminders.locale_reconciliation_body':
        'Bahasa aplikasi telah berubah. Pertahankan teks pengingat saat ini atau perbarui semua pengingat di perangkat ini secara atomik. Kedua pilihan tidak menampilkan label buatan Anda.',
    'reminders.locale_retain_action': 'Pertahankan bahasa saat ini',
    'reminders.locale_update_action': 'Perbarui semua ke bahasa saat ini',
    'reminders.locale_retained_confirmation':
        'Bahasa pengingat sistem saat ini dipertahankan.',
    'reminders.locale_updated_confirmation':
        'Semua pengingat sistem diminta diperbarui ke bahasa saat ini.',
    'diagnostics.title': 'Diagnostik teknis',
    'diagnostics.rerun': 'Jalankan ulang pemeriksaan',
    'diagnostics.scope_title': 'Hanya untuk tinjauan teknis',
    'diagnostics.scope_body':
        'Ini adalah pemeriksaan tata kelola deterministik (kompilasi teks, lint keamanan pelokalan, pemutaran ulang skenario sintetis). Semuanya hanya melaporkan status teknis: tidak mengubah skor, tingkat keparahan, bukti, atau hasil aturan, dan bukan panduan kesehatan. Hanya data sintetis/demo.',
    'diagnostics.elapsed': 'Pemeriksaan selesai dalam {ms} ms.',
    'reminders.identity_attestation_title':
        'Pemeriksaan identitas tertunda yang dilaporkan plugin',
    'reminders.identity_attestation_matched':
        'Identitas tertunda yang dilaporkan plugin cocok dengan rencana ({installed}/{planned}). Ini bukan verifikasi independen atas penjadwal sistem operasi atau pengiriman yang terlihat.',
    'reminders.identity_attestation_drift':
        'Identitas yang dilaporkan berbeda dari rencana: {missing} hilang, {extra} berlebih, dan {replaced} diganti pada ID yang direncanakan. Jangan mengandalkan pengingat sistem sebelum rekonsiliasi berhasil.',
    'reminders.identity_attestation_uninspectable':
        'Identitas permintaan tertunda tidak dapat dibaca dari plugin. Rencana lokal tetap menjadi acuan, tetapi status pengingat sistem belum terverifikasi.',
    'reminders.error_schedule_identity_unverified':
        'Rencana lokal telah disimpan, tetapi identitas tertunda yang dilaporkan plugin tidak dapat dicocokkan dengannya. Rekonsiliasi ulang sebelum mengandalkan pengingat sistem.',
    'reminders.readiness_title': 'Kesiapan pengiriman pengingat sistem',
    'reminders.readiness_contract': 'Kontrak kapabilitas {platform} · {digest}',
    'reminders.readiness_boundary':
        'Permintaan jadwal yang selesai atau identitas plugin yang cocok tidak membuktikan pengiriman terlihat, pada layar kunci, atau di latar belakang.',
    'reminders.readiness_platform_android': 'Android',
    'reminders.readiness_platform_ios': 'iOS',
    'reminders.readiness_platform_macos': 'macOS',
    'reminders.readiness_platform_web': 'Web',
    'reminders.readiness_platform_windows': 'Windows',
    'reminders.readiness_platform_linux': 'Linux',
    'reminders.readiness_platform_unknown':
        'Platform tidak dikenal atau gateway khusus',
    'reminders.readiness_local_plan': 'Rencana lokal',
    'reminders.readiness_adapter': 'Adaptor penjadwalan',
    'reminders.readiness_schedule_request': 'Permintaan jadwal',
    'reminders.readiness_permission_request': 'Permintaan izin',
    'reminders.readiness_permission_inspection': 'Pemeriksaan izin saat ini',
    'reminders.readiness_registry': 'Registri tertunda plugin',
    'reminders.readiness_visible_delivery': 'Pengiriman terlihat',
    'reminders.readiness_body_tap': 'Ketuk isi notifikasi',
    'reminders.readiness_cold_start': 'Mulai dingin dari notifikasi',
    'reminders.readiness_background_action': 'Tindakan latar belakang',
    'reminders.readiness_local_none':
        'Belum ada rencana lokal yang dikonfigurasi',
    'reminders.readiness_local_saved': 'Disimpan di perangkat ini',
    'reminders.readiness_adapter_plan_only':
        'Hanya rencana; API notifikasi sistem tidak dipanggil',
    'reminders.readiness_evidence_artifact_verified':
        'Diverifikasi oleh bukti platform target yang terikat artefak',
    'reminders.readiness_evidence_implemented_unverified':
        'Diimplementasikan; belum ada verifikasi perangkat target yang terikat artefak',
    'reminders.readiness_evidence_unavailable':
        'Tidak tersedia atau belum diimplementasikan',
    'reminders.readiness_request_not_requested': 'Belum dikirim',
    'reminders.readiness_request_applied':
        'Permintaan plugin selesai; pengiriman belum terbukti',
    'reminders.readiness_request_rolled_back':
        'Permintaan jadwal baru di-rollback dan rencana lama dipulihkan; pengiriman belum terbukti',
    'reminders.readiness_request_superseded':
        'Digantikan oleh akun atau rencana yang lebih baru',
    'reminders.readiness_request_unsupported':
        'Kontrak ini hanya menyimpan rencana',
    'reminders.readiness_request_failed':
        'Permintaan gagal atau identitas belum diverifikasi',
    'reminders.readiness_request_recovery_required':
        'Rekonsiliasi diperlukan sebelum dapat diandalkan',
    'reminders.readiness_permission_not_requested':
        'Belum diminta dalam sesi ini',
    'reminders.readiness_permission_granted':
        'Panggilan permintaan izin menghasilkan diizinkan; tidak sama dengan keadaan saat ini',
    'reminders.readiness_permission_denied':
        'Panggilan permintaan izin menghasilkan tidak diizinkan; bukan bukti bahwa pengguna secara tegas menolak',
    'reminders.readiness_permission_failed':
        'Permintaan izin gagal atau adaptor tidak tersedia; ini tidak berarti pengguna menolak',
    'reminders.readiness_permission_unavailable':
        'Kontrak kapabilitas ini tidak meminta izin',
    'reminders.readiness_inspection_not_inspected':
        'Keadaan izin saat ini belum diperiksa',
    'reminders.readiness_inspection_enabled':
        'Pemeriksaan plugin saat ini menghasilkan aktif; bukan bukti pengiriman',
    'reminders.readiness_inspection_disabled':
        'Pemeriksaan plugin saat ini menghasilkan nonaktif; tidak menunjukkan penyebab atau pilihan pengguna',
    'reminders.readiness_inspection_unavailable':
        'Pemeriksaan keadaan izin saat ini tidak tersedia; bukan berarti pengguna menolak',
    'reminders.readiness_inspection_failed':
        'Pemeriksaan keadaan izin saat ini gagal; bukan berarti pengguna menolak',
    'reminders.readiness_registry_not_inspected': 'Belum diperiksa',
    'reminders.readiness_registry_matched':
        'Laporan plugin cocok dengan rencana lokal; bukan bukti pengiriman sistem operasi',
    'reminders.readiness_registry_drift':
        'Laporan plugin berbeda dari rencana lokal',
    'reminders.readiness_registry_uninspectable':
        'Identitas plugin tidak dapat dibaca',
    'reminders.readiness_registry_unsupported':
        'Kontrak kapabilitas ini tidak memeriksa registri native',
    'reminders.readiness_visible_unverified': 'Belum diverifikasi',
    'reminders.readiness_visible_artifact_verified':
        'Diverifikasi oleh bukti artefak platform target',
    'app.welcome': 'Selamat datang',
    'app.loading': 'Memuat...',
    'onboarding.title': 'ParkinSUM Pendamping (Edisi Lokal)',
    'onboarding.description':
        'Aplikasi ini hanya untuk pencatatan makanan dan panduan berbasis aturan. Tidak menggantikan saran dokter atau apoteker Anda.',
    'onboarding.registration_region': 'Wilayah pendaftaran',
    'onboarding.registration_region_help':
        'Menentukan rantai yurisdiksi default dan prioritas sumber.',
    'onboarding.display_language': 'Bahasa tampilan',
    'onboarding.display_language_help':
        'Mengontrol bahasa aplikasi, format tanggal, dan angka.',
    'onboarding.diet_profile_region': 'Wilayah profil diet',
    'onboarding.diet_profile_region_help':
        'Digunakan untuk template makanan default tanpa menimpa aturan keselamatan.',
    'onboarding.swallowing_texture_mode': 'Mode keselamatan menelan / tekstur',
    'onboarding.swallowing_texture_mode_help':
        'Digunakan sebagai preferensi rekomendasi konservatif, bukan penilaian menelan klinis.',
    'onboarding.content_override': 'Penggantian yurisdiksi konten (opsional)',
    'onboarding.content_override_help': 'Pisahkan dengan koma, mis. US,CA',
    'onboarding.local_ai_consent':
        'Aktifkan pengurutan ulang AI lokal (opsional)',
    'onboarding.local_ai_consent_help':
        'Hanya menggunakan Ollama/llama.cpp di localhost dan kembali ke jalur konservatif saat gerbang keselamatan memblokirnya.',
    'onboarding.start': 'Saya mengerti, lanjutkan',
    'nav.home': 'Beranda',
    'nav.analytics': 'Analitik',
    'nav.meals': 'Makanan',
    'nav.timeline': 'Linimasa',
    'nav.meds': 'Obat',
    'nav.catalog': 'Katalog',
    'nav.next_meal': 'Makan berikutnya',
    'shell.tagline': 'Pendamping · prototipe riset',
    'shell.workspace': 'Ruang kerja',
    'shell.care_workspace': 'Persiapan kunjungan & tindak lanjut',
    'shell.boundary_note':
        'Prototipe edukasi — bukan nasihat medis. Tinjau keputusan kesehatan bersama klinisi yang berkualifikasi.',
    'dashboard.greeting_morning': 'Selamat pagi',
    'dashboard.greeting_afternoon': 'Selamat siang',
    'dashboard.greeting_evening': 'Selamat malam',
    'dashboard.subtitle':
        'Ringkasan makanan, asupan obat yang dicatat, dan aturan di balik setiap penjelasan.',
    'dashboard.stat_meals': 'Makanan tercatat',
    'dashboard.stat_drugs': 'Obat aktif',
    'dashboard.stat_intakes': 'Asupan tercatat',
    'shell.new_entry': 'Entri baru',
    'shell.search': 'Cari',
    'shell.search_hint': 'Cari halaman, alat, dan tindakan',
    'shell.search_empty': 'Tidak ada halaman, alat, atau tindakan yang cocok',
    'shell.menu': 'Menu',
    'shell.group.evidence': 'Bukti & aturan',
    'shell.group.data': 'Data Anda',
    'shell.group.operations': 'Operasional',
    'shell.group.pages': 'Halaman',
    'shell.action.observation': 'Catat observasi',
    'dashboard.stat_protein': 'Rata-rata protein per makan',
    'dashboard.show_details': 'Tampilkan detail',
    'dashboard.hide_details': 'Sembunyikan detail',
    'dashboard.quick_log': 'Catat cepat',
    'dashboard.today': 'Aktivitas terbaru',
    'insights.title': 'Wawasan',
    'insights.subtitle':
        'Pola dari yang Anda catat, hanya dari entri Anda sendiri.',
    'insights.range_7': '7 hari',
    'insights.range_30': '30 hari',
    'insights.meals': 'Makanan',
    'insights.intakes': 'Asupan obat',
    'insights.observations': 'Observasi',
    'insights.avg_protein': 'Rata-rata protein per makan',
    'insights.rhythm_title': 'Ritme pencatatan',
    'insights.rhythm_subtitle': 'Entri per hari',
    'insights.protein_title': 'Protein per makan',
    'insights.protein_subtitle':
        'Gram per makan yang dicatat, dari terlama ke terbaru',
    'insights.daypart_title': 'Waktu dalam sehari',
    'insights.daypart_subtitle': 'Kapan makanan dan asupan obat dicatat',
    'insights.morning': 'Pagi',
    'insights.midday': 'Siang',
    'insights.evening': 'Sore',
    'insights.night': 'Malam',
    'insights.empty': 'Belum ada catatan pada periode ini.',
    'insights.boundary':
        'Ini adalah ringkasan deskriptif dari entri Anda sendiri, bukan pengukuran klinis, target, atau nasihat; tinjau keputusan kesehatan bersama klinisi yang berkualifikasi.',
    'settings.local_ai_advanced': 'Lanjutan · Koneksi AI lokal',
    'nav.today': 'Hari ini',
    'nav.library': 'Pustaka',
    'dashboard.log_prompt': 'Apa yang ingin Anda catat?',
    'dashboard.log_meal_hint':
        'Makanan dan porsi, diperiksa dengan aturan edukasi',
    'dashboard.log_intake_hint': 'Satu dosis obat yang Anda minum',
    'dashboard.log_observation_hint':
        'Tekanan darah, gejala, atau kondisi motorik',
    'dashboard.open_timeline': 'Buka linimasa',
    'dashboard.open_next_meal': 'Buka makan berikutnya',
    'library.my_medications': 'Obat saya',
    'library.catalog': 'Makanan & obat',
    'next_meal.title': 'Rekomendasi makan berikutnya',
    'next_meal.subtitle':
        'Pilih perkiraan waktu makan berikutnya. Jalur aturan konservatif mempertahankan urutan kandidat; model mekanistik hanya menambahkan jejak tumpang-tindih waktu edukatif dan tidak mengurutkan ulang. AI lokal adalah pengurut ulang daftar aman yang terpisah dan opsional.',
    'next_meal.input_time': 'Perkiraan waktu makan berikutnya',
    'next_meal.use_local_ai': 'Poles kata dengan AI lokal (opsional)',
    'next_meal.use_local_ai_help':
        'Hanya memanggil Ollama/llama.cpp di localhost untuk menyusun ulang dan menulis ulang penjelasan kandidat yang telah disetujui mesin; kembali ke jalur konservatif saat gerbang keselamatan memblokir.',
    'next_meal.generate': 'Buat rekomendasi',
    'next_meal.generating': 'Membuat…',
    'next_meal.empty':
        'Tetapkan waktu lalu ketuk "Buat rekomendasi"; mesin akan menilai ulang sesuai jendela waktu itu.',
    'next_meal.why_these': 'Mengapa pilihan ini',
    'next_meal.ai_polished': 'Dipoles oleh AI lokal',
    'next_meal.conservative_engine': 'Jalur konservatif mesin konflik',
    'next_meal.recommendation_path': 'Jalur rekomendasi',
    'next_meal.gate_reasons': 'Catatan gerbang keselamatan',
    'next_meal.candidates': 'Kandidat teratas',
    'next_meal.no_candidates':
        'Tidak ada kandidat yang sesuai dengan kendala saat ini. Sesuaikan waktu atau perluas katalog makanan.',
    'next_meal.error': 'Pembuatan gagal',
    'dashboard.title': 'Dasbor',
    'dashboard.status': 'Ringkasan',
    'dashboard.logged_meals': 'Makanan tercatat: {count}',
    'dashboard.active_drugs': 'Obat aktif: {count}',
    'dashboard.logged_intakes': 'Konsumsi obat: {count}',
    'dashboard.recommendations': 'Rekomendasi',
    'dashboard.no_recommendations': 'Belum ada rekomendasi',
    'dashboard.recommendation_path': 'Jalur rekomendasi',
    'dashboard.recommendation_template':
        'Template aktif: {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'Peningkatan AI lokal digunakan',
    'dashboard.ai_not_used': 'Hanya jalur konservatif',
    'dashboard.recommendation_why': 'Mengapa rekomendasi ini',
    'dashboard.recommendation_gate': 'Status gerbang AI / keselamatan',
    'dashboard.recommendation_macro_line':
        'Per 100 g: P {protein} g · C {carbs} g · L {fat} g',
    'dashboard.recommendation_score_line':
        'Keselamatan {safety} · Jadwal {schedule} · Fakta {facts} · Penalti konteks {context} · Penalti jendela {timing} · Penalti menelan {swallowing} · Kecocokan template {template}',
    'dashboard.recent_meals': 'Makanan terbaru (5 terakhir)',
    'dashboard.no_meals': 'Belum ada makanan tercatat',
    'dashboard.items': '{count} item',
    'dashboard.meal_context_iron_supplement':
        'koevent dengan suplemen zat besi',
    'dashboard.meal_context_iron_multivitamin':
        'koevent dengan multivitamin berisi zat besi',
    'dashboard.meal_context_starch_thickener': 'pengental berbasis pati',
    'dashboard.meal_context_xanthan_thickener': 'pengental berbasis xantan',
    'dashboard.meal_context_enteral_feed_continuous':
        'nutrisi enteral kontinu ({protein} g/hari protein)',
    'dashboard.meal_context_enteral_feed_bolus':
        'nutrisi enteral bolus / intermiten',
    'dashboard.edit': 'Sunting',
    'dashboard.delete': 'Hapus',
    'dashboard.protein_trend': 'Tren protein',
    'dashboard.average_protein': 'Protein rata-rata: {value} g / makan',
    'dashboard.no_trend': 'Belum ada data tren',
    'dashboard.timeline': 'Linimasa',
    'dashboard.no_timeline': 'Belum ada makanan atau peristiwa obat',
    'dashboard.add_meal': 'Tambah makanan',
    'dashboard.meal_check': 'Periksa makanan - {title}',
    'timeline.title': 'Linimasa makanan dan obat',
    'timeline.empty': 'Belum ada makanan atau konsumsi obat',
    'timeline.add_meal': 'Tambah makanan',
    'timeline.add_intake': 'Catat obat',
    'timeline.new_intake': 'Konsumsi obat baru',
    'timeline.edit_intake': 'Sunting konsumsi obat',
    'timeline.medication': 'Obat',
    'timeline.active_medication_option': '{name} (aktif)',
    'timeline.dosage_note': 'Catatan dosis',
    'timeline.package_dose_source':
        'Sumber: {source} · Diambil: {retrieved} · {url}',
    'timeline.package_dose_derivation':
        'Perhitungan: {strength} × {quantity} {unit} = {amount} {resultUnit}',
    'timeline.package_dose_assumed_denominator':
        'Sumber tidak mencantumkan penyebut; satu unit sediaan diskret ({unit}) diasumsikan. Periksa label produk sebelum mengonfirmasi.',
    'timeline.package_dose_retrieval_unknown': 'Tidak tercatat',
    'timeline.taken_at': 'Dikonsumsi pukul',
    'timeline.edit_taken_at': 'Sunting waktu konsumsi',
    'timeline.save_intake': 'Simpan konsumsi',
    'timeline.no_medications': 'Tidak ada katalog obat tersedia',
    'timeline.select_medication_first': 'Pilih obat terlebih dahulu',
    'timeline.save_intake_failed': 'Gagal menyimpan konsumsi: {error}',
    'timeline.meal_macro_line':
        'Total: protein {protein} g · karbo {carbs} g · lemak {fat} g',
    'timeline.conflict_line': 'Tinjauan konflik: {severity} · skor {score}',
    'timeline.meal_window_line': 'Jendela makan: {start} - {end}',
    'timeline.next_meal_window_line':
        'Jendela makan berikutnya: {start} - {end}',
    'timeline.nearest_medication_line': 'Obat terdekat: {name} ({distance})',
    'timeline.nearest_meal_line': 'Makan terdekat: {title} ({distance})',
    'timeline.dosage_line': 'Dosis: {value}',
    'timeline.before': '{value} sebelum',
    'timeline.after': '{value} sesudah',
    'timeline.no_context_flags':
        'Tidak ada bendera suplemen, pengental, atau nutrisi enteral',
    'common.close': 'Tutup',
    'common.done': 'Selesai',
    'common.cancel': 'Batal',
    'common.apply': 'Terapkan',
    'common.optional': 'opsional',
    'analytics.local_ai_medical_model': 'Nama model tinjauan medis',
    'common.delete': 'Hapus',
    'common.completed': 'Selesai',
    'common.error': 'Kesalahan',
    'common.search_results': 'Hasil pencarian',
    'common.no_matching_foods': 'Tidak ditemukan makanan yang cocok',
    'common.texture': 'Tekstur',
    'common.not_available': 'Belum diisi',
    'common.save': 'Simpan',
    'common.edit': 'Sunting',
    'common.confirm': 'Konfirmasi',
    'common.sign_out': 'Keluar',
    'meal_slot.breakfast': 'Sarapan',
    'meal_slot.lunch': 'Makan siang',
    'meal_slot.dinner': 'Makan malam',
    'meal_slot.snack': 'Camilan',
    'meal.title': 'Makanan',
    'meal.empty': 'Belum ada makanan tercatat',
    'meal.check_title': 'Periksa makanan - {title}',
    'medications.title': 'Obat',
    'catalog.title': 'Katalog',
    'catalog.search': 'Cari makanan atau obat',
    'catalog.foods': 'Makanan',
    'catalog.drugs': 'Obat',
    'catalog.food_subtitle':
        'Kategori={category}  P/C/L={protein}/{carbs}/{fat} (per 100 g)',
    'catalog.drug_subtitle': 'Tag={tags}',
    'medications.view_detail': 'Lihat detail obat',
    'decision.block': 'Blokir',
    'decision.require_review': 'Butuh tinjauan',
    'decision.discourage': 'Tidak disarankan',
    'decision.warn': 'Peringatan',
    'decision.info': 'Info',
    'decision.allow': 'Izinkan',
    'decision.defer': 'Tunda',
    'severity.low': 'Rendah',
    'severity.moderate': 'Sedang',
    'severity.high': 'Tinggi',
    'severity.critical': 'Kritis',
    'missing.dose': 'dosis',
    'missing.formulation': 'formulasi',
    'missing.time': 'waktu obat',
    'missing.meal_time': 'waktu makan',
    'missing.coevent_time': 'waktu koevent',
    'missing.thickener_type': 'jenis pengental',
    'recommend.low_protein': 'Lebih disukai protein lebih rendah',
    'recommend.protein_window_caution':
        'Hati-hati dengan protein tinggi di sekitar jendela levodopa',
    'recommend.history_low_protein':
        'Riwayat terbaru menyarankan memprioritaskan opsi rendah protein',
    'recommend.culture_match': 'Cocok dengan template diet regional saat ini',
    'recommend.fallback_chain':
        'Pengetahuan makanan untuk wilayah ini menggunakan rantai cadangan',
    'recommend.general_friendly': 'Pilihan yang umumnya cocok',
    'recommend.path.hybrid_local_ai': 'Pengurutan ulang dibantu AI lokal',
    'recommend.path.conservative_safety_gate':
        'Jalur konservatif (gerbang keselamatan memblokir AI)',
    'recommend.path.conservative_gate_block':
        'Jalur konservatif (AI lokal tidak tersedia)',
    'recommend.path.fallback_invalid_ai':
        'Jalur konservatif (output AI gagal validasi)',
    'recommend.path.conservative_cdss': 'Jalur CDSS konservatif',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'Tidak ada layanan Ollama atau llama.cpp di localhost yang merespons. Mulai layanan model lokal, atau matikan pengurutan ulang AI lokal.',
    'recommend.runtime.endpoint_must_be_localhost':
        'Endpoint AI lokal harus tetap di localhost/127.0.0.1 dan tidak boleh menunjuk ke endpoint cloud.',
    'recommend.runtime.safety_gate_conservative':
        'Gerbang keselamatan menjaga hasil pada jalur konservatif.',
    'recommend.runtime.next_meal_window_missing':
        'Jendela waktu makan berikutnya yang diharapkan tidak ada. Tambahkan waktu paling awal dan paling akhir di Tambah/Sunting Makanan.',
    'recommend.runtime.no_prior_meal_history':
        'Tidak ada riwayat makanan sebelumnya untuk pengurutan ulang yang aman.',
    'recommend.runtime.legacy_meal_time':
        'Makanan terbaru masih menggunakan waktu lama yang dimigrasikan; sunting menjadi waktu makan sebenarnya.',
    'recommend.runtime.iron_conservative':
        'Makanan terbaru mencatat suplemen zat besi, sehingga pengurutan ulang tetap konservatif.',
    'recommend.runtime.iron_multivitamin_conservative':
        'Makanan terbaru mencatat multivitamin dengan zat besi, sehingga pengurutan ulang tetap konservatif.',
    'recommend.runtime.starch_thickener_conservative':
        'Makanan terbaru mencatat pengental berbasis pati, sehingga tinjauan keselamatan deterministik dipertahankan.',
    'recommend.runtime.enteral_conservative':
        'Konteks nutrisi enteral kontinu aktif, sehingga tinjauan deterministik dipertahankan.',
    'recommend.runtime.local_ai_not_consented':
        'Pengurutan ulang AI lokal belum diaktifkan oleh pengguna.',
    'recommend.runtime.local_ai_unavailable':
        'Endpoint AI lokal saat ini tidak tersedia.',
    'recommend.runtime.returned_conservative':
        'Mengembalikan rekomendasi konservatif deterministik sebagai gantinya.',
    'recommend.runtime.ai_validation_failed':
        'Output terstruktur AI lokal gagal validasi daftar putih.',
    'recommend.runtime.ai_invalid_whitelist':
        'AI lokal tidak mengembalikan urutan yang sah hanya dari daftar putih, sehingga hasil tidak digunakan.',
    'recommend.runtime.cdss_conservative_observations':
        'Jalur CDSS konservatif menggunakan observasi varian asli bila tersedia.',
    'recommend.runtime.local_ai_success': 'Pengurutan ulang AI lokal berhasil.',
    'recommend.runtime.local_ai_copy_polish_success':
        'AI lokal memperhalus bahasa rekomendasi.',
    'recommend.runtime.medgemma_optional_unavailable':
        'Endpoint AI lokal merespons; model MedGemma opsional tidak tersedia.',
    'recommend.runtime.recommendation_conservative':
        'Rekomendasi tetap di jalur konservatif.',
    'recommend.runtime.levodopa_ai_sensitive':
        'Jendela waktu levodopa terlalu sensitif untuk pengurutan ulang AI.',
    'recommend.context_iron_supplement':
        'Suplemen zat besi tercatat dengan makanan terbaru, sehingga panduan waktu tetap konservatif.',
    'recommend.context_iron_multivitamin':
        'Multivitamin dengan zat besi tercatat dengan makanan terbaru, sehingga panduan waktu tetap konservatif.',
    'recommend.context_starch_thickener':
        'Pengental berbasis pati tercatat, yang menaikkan prioritas keselamatan menelan.',
    'recommend.context_xanthan_thickener':
        'Pengental berbasis xantan tercatat untuk makanan terbaru.',
    'recommend.context_enteral_feed_continuous':
        'Nutrisi enteral kontinu aktif ({protein} g/hari protein), sehingga kata-kata rekomendasi tetap konservatif.',
    'recommend.context_enteral_feed_bolus':
        'Nutrisi enteral bolus/intermiten tercatat untuk makanan terbaru.',
    'recommend.context_iron_penalty':
        'Koevent terkait zat besi hadir, sehingga opsi protein lebih tinggi diturunkan peringkatnya secara konservatif.',
    'recommend.context_enteral_penalty':
        'Konteks nutrisi enteral kontinu hadir, sehingga opsi protein lebih tinggi diturunkan peringkatnya secara konservatif.',
    'recommend.context_texture_gap_penalty':
        'Pengental tercatat, tetapi katalog saat ini masih kekurangan data kompatibilitas tekstur terstruktur, sehingga margin konservatif tambahan dipertahankan.',
    'recommend.context_texture_supported':
        'Pengental tercatat, dan kandidat ini sudah memiliki metadata tekstur terstruktur, sehingga penalti kesenjangan data lebih rendah.',
    'recommend.texture_profile_missing':
        'Mode keselamatan tekstur aktif, tetapi kandidat ini kurang metadata tekstur terstruktur, sehingga peringkat tetap lebih konservatif.',
    'recommend.texture_profile_supported_soft_or_liquid':
        'Kandidat ini cocok dengan mode keselamatan tekstur lembut-atau-cair saat ini.',
    'recommend.texture_profile_supported_liquid_only':
        'Kandidat ini cocok dengan mode keselamatan tekstur hanya cair saat ini.',
    'recommend.texture_profile_incompatible':
        'Kandidat ini tidak cocok dengan mode keselamatan tekstur saat ini, sehingga diturunkan peringkatnya secara konservatif.',
    'recommend.texture_template_supported':
        'Kandidat ini cocok dengan arah tekstur template makanan saat ini.',
    'recommend.texture_template_mismatch':
        'Kandidat ini tidak cocok dengan arah tekstur template makanan saat ini.',
    'recommend.local_seed_metadata':
        'Kandidat ini masih bergantung pada metadata seed lokal alih-alih observasi yang lebih kaya berbasis basis data.',
    'recommend.timing_window_incomplete':
        'Jendela waktu tidak lengkap, sehingga peringkat konservatif menjaga margin keselamatan tambahan.',
    'recommend.next_meal_gap_close':
        'Jendela makan berikutnya masih dekat dengan makan sebelumnya; opsi protein lebih rendah lebih disukai.',
    'recommend.next_meal_window_fiber':
        'Ini cocok dengan jendela makan berikutnya yang direncanakan dan menyukai asupan serat yang lebih stabil.',
    'recommend.medication_timing_caution':
        'Waktu pemberian obat menyarankan kehati-hatian ekstra untuk jendela makan berikutnya ini.',
    'texture_mode.unrestricted': 'Tanpa pembatasan',
    'texture_mode.soft_or_liquid': 'Lembut atau cair',
    'texture_mode.liquid_only': 'Hanya cair',
    'texture_class.liquid': 'Cair',
    'texture_class.soft': 'Lembut',
    'texture_class.regular': 'Biasa',
    'food.food_chicken_breast': 'Dada ayam (matang)',
    'food.food_tofu': 'Tahu polos',
    'food.food_brown_rice': 'Beras cokelat',
    'food.food_banana': 'Pisang',
    'food.food_spinach': 'Bayam',
    'food.food_milk': 'Susu rendah lemak',
    'food.food_beef': 'Daging sapi tanpa lemak (digoreng)',
    'food.food_apple': 'Apel (dengan kulit)',
    'food.food_blueberry': 'Bluberi',
    'food.food_tomato': 'Tomat',
    'food.food_broccoli': 'Brokoli',
    'food.food_oats': 'Oat gulung',
    'food.food_salmon': 'Salmon (budidaya, panggang)',
    'food.food_fava_beans': 'Kacang fava (segar)',
    'food.food_potato_boiled': 'Kentang (rebus)',
    'food.food_walnuts': 'Kenari',
    'food.food_olive_oil': 'Minyak zaitun extra virgin',
    'food.food_cheddar_cheese': 'Keju cheddar',
    'food.food_egg_boiled': 'Telur (rebus)',
    'food.food_coffee': 'Kopi (diseduh, tanpa pemanis)',
    'observatory.dependency_closure.title': 'Kesiapan closure dependensi',
    'observatory.dependency_closure.loading':
        'Memuat manifes root yang tercatat di repositori · closure HOLD',
    'observatory.dependency_closure.unavailable':
        'HOLD · manifes root yang tercatat di repositori tidak tersedia',
    'observatory.dependency_closure.loading_semantics':
        'Manifes root hasil algoritma yang stabil sedang dimuat. Closure dependensi tetap HOLD.',
    'observatory.dependency_closure.unavailable_semantics':
        'Manifes root hasil algoritma yang stabil tidak tersedia. Closure dependensi berada dalam status HOLD.',
    'observatory.dependency_closure.semantics':
        '{count} root algoritma stabil yang terdaftar. Analyzer {analyzer} adalah target peninjauan versi tepat yang dinyatakan. Bukti kompatibilitas luring tidak dibundel atau dijalankan dalam tampilan ini. Closure dependensi transitif berada dalam status HOLD sambil menunggu generator edge ParkinSUM.',
    'observatory.dependency_closure.summary':
        '{count} / {total} root stabil · target Analyzer yang dinyatakan {analyzer} · closure transitif HOLD',
    'observatory.dependency_closure.identity': '{schema} · {digest}… · {state}',
    'observatory.dependency_closure.registry_chip':
        'pemetaan Registry: valid secara struktural',
    'observatory.dependency_closure.edge_chip': 'generator edge: HOLD',
    'observatory.dependency_closure.closure_chip': 'closure maju/mundur: HOLD',
    'observatory.dependency_closure.details':
        'Tabel root stabil yang aksesibel',
    'observatory.dependency_closure.details_subtitle':
        'Hanya seed pustaka utama; tanpa edge dependensi yang dihasilkan.',
    'observatory.dependency_closure.table_semantics':
        'Tabel root algoritma stabil. Kolomnya adalah algoritma, root logis, sink hasil, dan URI paket kanonis.',
    'observatory.dependency_closure.column_algorithm': 'Algoritma',
    'observatory.dependency_closure.column_root': 'Root logis',
    'observatory.dependency_closure.column_sink': 'Sink hasil',
    'observatory.dependency_closure.column_uri': 'URI paket',
    'observatory.dependency_closure.boundary':
        'Tampilan ini hanya membuktikan kontrak struktural Registry-ke-root yang tercatat di repositori. Bukti kompatibilitas Analyzer luring tidak dibundel atau dijalankan di sini. Tampilan ini tidak menunjukkan atau mengklaim adanya grafik panggilan, SCC, closure maju/mundur, eksekusi, aliran data yang tepat, validasi ilmiah atau klinis, keamanan, manfaat, maupun nasihat medis.',
  },

  // ===========================================================================
  // ru (Russian)
  // ===========================================================================
  'ru': {
    'reminders.locale_reconciliation_title':
        'Язык системных напоминаний отличается',
    'reminders.locale_reconciliation_body':
        'Язык приложения изменился. Сохраните текущий текст или атомарно обновите все напоминания на этом устройстве. Ни один вариант не показывает созданные вами подписи.',
    'reminders.locale_retain_action': 'Сохранить текущий язык',
    'reminders.locale_update_action': 'Обновить все на текущий язык',
    'reminders.locale_retained_confirmation':
        'Текущий язык системных напоминаний сохранен.',
    'reminders.locale_updated_confirmation':
        'Запрошено обновление всех системных напоминаний на текущем языке.',
    'diagnostics.title': 'Техническая диагностика',
    'diagnostics.rerun': 'Запустить проверки заново',
    'diagnostics.scope_title': 'Только для технического анализа',
    'diagnostics.scope_body':
        'Это детерминированные проверки управления (компиляция текстов, проверка безопасности локализации, воспроизведение синтетических сценариев). Они сообщают только технический статус: не изменяют оценку, серьёзность, доказательства или результат правил и не являются медицинскими рекомендациями. Только синтетические/демонстрационные данные.',
    'diagnostics.elapsed': 'Проверки завершены за {ms} мс.',
    'reminders.identity_attestation_title':
        'Проверка ожидающих идентификаторов по данным плагина',
    'reminders.identity_attestation_matched':
        'Ожидающие идентификаторы по данным плагина совпадают с планом ({installed}/{planned}). Это не независимая проверка системного планировщика или фактического отображения уведомлений.',
    'reminders.identity_attestation_drift':
        'Идентификаторы по данным плагина отличаются от плана: отсутствуют {missing}, лишних {extra}, заменены под запланированным ID {replaced}. Не полагайтесь на системные напоминания до успешной синхронизации.',
    'reminders.identity_attestation_uninspectable':
        'Не удалось прочитать ожидающие идентификаторы из плагина. Локальный план остаётся источником истины, но состояние системных напоминаний не проверено.',
    'reminders.error_schedule_identity_unverified':
        'Локальный план сохранён, но ожидающие идентификаторы плагина не удалось сопоставить с ним. Повторите синхронизацию, прежде чем полагаться на системные напоминания.',
    'reminders.readiness_title': 'Готовность доставки системных напоминаний',
    'reminders.readiness_contract':
        'Контракт возможностей {platform} · {digest}',
    'reminders.readiness_boundary':
        'Завершённый запрос на планирование или совпавшая идентификация плагина не доказывают видимую доставку, доставку на экран блокировки или в фоновом режиме.',
    'reminders.readiness_platform_android': 'Android',
    'reminders.readiness_platform_ios': 'iOS',
    'reminders.readiness_platform_macos': 'macOS',
    'reminders.readiness_platform_web': 'Web',
    'reminders.readiness_platform_windows': 'Windows',
    'reminders.readiness_platform_linux': 'Linux',
    'reminders.readiness_platform_unknown':
        'Неизвестная платформа или пользовательский шлюз',
    'reminders.readiness_local_plan': 'Локальный план',
    'reminders.readiness_adapter': 'Адаптер планирования',
    'reminders.readiness_schedule_request': 'Запрос на планирование',
    'reminders.readiness_permission_request': 'Запрос разрешения',
    'reminders.readiness_permission_inspection': 'Проверка текущего разрешения',
    'reminders.readiness_registry': 'Реестр ожидающих запросов плагина',
    'reminders.readiness_visible_delivery': 'Видимая доставка',
    'reminders.readiness_body_tap': 'Нажатие на текст уведомления',
    'reminders.readiness_cold_start': 'Холодный запуск из уведомления',
    'reminders.readiness_background_action': 'Фоновое действие',
    'reminders.readiness_local_none': 'Локальный план не настроен',
    'reminders.readiness_local_saved': 'Сохранено на этом устройстве',
    'reminders.readiness_adapter_plan_only':
        'Только план; API системных уведомлений не вызывается',
    'reminders.readiness_evidence_artifact_verified':
        'Проверено доказательствами целевой платформы, привязанными к артефакту',
    'reminders.readiness_evidence_implemented_unverified':
        'Реализовано; нет проверки на целевом устройстве, привязанной к артефакту',
    'reminders.readiness_evidence_unavailable': 'Недоступно или не реализовано',
    'reminders.readiness_request_not_requested': 'Не отправлен',
    'reminders.readiness_request_applied':
        'Запрос плагина завершён; доставка не доказана',
    'reminders.readiness_request_rolled_back':
        'Новый запрос на планирование отменён, прежний план восстановлен; доставка не доказана',
    'reminders.readiness_request_superseded':
        'Заменён более новой учётной записью или планом',
    'reminders.readiness_request_unsupported':
        'Этот контракт предусматривает только план',
    'reminders.readiness_request_failed':
        'Запрос завершился ошибкой или идентификация не проверена',
    'reminders.readiness_request_recovery_required':
        'Перед использованием требуется сверка',
    'reminders.readiness_permission_not_requested':
        'В этом сеансе запрос не выполнялся',
    'reminders.readiness_permission_granted':
        'Вызов запроса разрешения вернул разрешено; это не равно текущему состоянию',
    'reminders.readiness_permission_denied':
        'Вызов запроса разрешения вернул не разрешено; это не доказывает явный отказ пользователя',
    'reminders.readiness_permission_failed':
        'Запрос разрешения завершился ошибкой или адаптер недоступен; это не означает отказ пользователя',
    'reminders.readiness_permission_unavailable':
        'Этот контракт возможностей не запрашивает разрешение',
    'reminders.readiness_inspection_not_inspected':
        'Текущее состояние разрешения не проверялось',
    'reminders.readiness_inspection_enabled':
        'Текущая проверка плагина вернула включено; это не доказательство доставки',
    'reminders.readiness_inspection_disabled':
        'Текущая проверка плагина вернула отключено; причина и выбор пользователя не установлены',
    'reminders.readiness_inspection_unavailable':
        'Проверка текущего разрешения недоступна; это не означает отказ пользователя',
    'reminders.readiness_inspection_failed':
        'Проверка текущего разрешения завершилась ошибкой; это не означает отказ пользователя',
    'reminders.readiness_registry_not_inspected': 'Не проверено',
    'reminders.readiness_registry_matched':
        'Отчёт плагина совпадает с локальным планом; это не доказательство доставки ОС',
    'reminders.readiness_registry_drift':
        'Отчёт плагина отличается от локального плана',
    'reminders.readiness_registry_uninspectable':
        'Не удалось прочитать идентификаторы плагина',
    'reminders.readiness_registry_unsupported':
        'Этот контракт возможностей не проверяет нативный реестр',
    'reminders.readiness_visible_unverified': 'Не проверено',
    'reminders.readiness_visible_artifact_verified':
        'Проверено доказательствами артефакта целевой платформы',
    'app.welcome': 'Добро пожаловать',
    'app.loading': 'Загрузка...',
    'onboarding.title': 'ParkinSUM Компаньон (Локальная версия)',
    'onboarding.description':
        'Это приложение предназначено только для записи приёмов пищи и рекомендаций на основе правил. Оно не заменяет советы врача или фармацевта.',
    'onboarding.registration_region': 'Регион регистрации',
    'onboarding.registration_region_help':
        'Определяет цепочку юрисдикций по умолчанию и приоритет источников.',
    'onboarding.display_language': 'Язык интерфейса',
    'onboarding.display_language_help':
        'Управляет языком приложения, форматами даты и чисел.',
    'onboarding.diet_profile_region': 'Регион профиля питания',
    'onboarding.diet_profile_region_help':
        'Используется для шаблонов приёмов пищи по умолчанию без переопределения правил безопасности.',
    'onboarding.swallowing_texture_mode':
        'Режим безопасности глотания / текстуры',
    'onboarding.swallowing_texture_mode_help':
        'Используется как консервативное предпочтение рекомендаций, не как клиническая оценка глотания.',
    'onboarding.content_override':
        'Переопределение юрисдикции содержимого (необязательно)',
    'onboarding.content_override_help': 'Через запятую, например US,CA',
    'onboarding.local_ai_consent':
        'Включить локальное переупорядочивание ИИ (необязательно)',
    'onboarding.local_ai_consent_help':
        'Использует только Ollama/llama.cpp на localhost и возвращается на консервативный путь, когда защитные шлюзы блокируют его.',
    'onboarding.start': 'Понятно, продолжить',
    'nav.home': 'Главная',
    'nav.analytics': 'Аналитика',
    'nav.meals': 'Питание',
    'nav.timeline': 'Хронология',
    'nav.meds': 'Лекарства',
    'nav.catalog': 'Каталог',
    'nav.next_meal': 'Следующий приём',
    'shell.tagline': 'Компаньон · исследовательский прототип',
    'shell.workspace': 'Рабочее пространство',
    'shell.care_workspace': 'Подготовка к визиту и уточнения',
    'shell.boundary_note':
        'Учебный прототип — не медицинская консультация. Обсуждайте решения о здоровье с квалифицированным врачом.',
    'dashboard.greeting_morning': 'Доброе утро',
    'dashboard.greeting_afternoon': 'Добрый день',
    'dashboard.greeting_evening': 'Добрый вечер',
    'dashboard.subtitle':
        'Обзор записанных приёмов пищи, лекарств и правил, стоящих за каждым пояснением.',
    'dashboard.stat_meals': 'Записано приёмов пищи',
    'dashboard.stat_drugs': 'Активные препараты',
    'dashboard.stat_intakes': 'Записано приёмов лекарств',
    'shell.new_entry': 'Новая запись',
    'shell.search': 'Поиск',
    'shell.search_hint': 'Поиск страниц, инструментов и действий',
    'shell.search_empty': 'Нет подходящих страниц, инструментов или действий',
    'shell.menu': 'Меню',
    'shell.group.evidence': 'Доказательства и правила',
    'shell.group.data': 'Ваши данные',
    'shell.group.operations': 'Эксплуатация',
    'shell.group.pages': 'Страницы',
    'shell.action.observation': 'Записать наблюдение',
    'dashboard.stat_protein': 'Средний белок на приём пищи',
    'dashboard.show_details': 'Показать подробности',
    'dashboard.hide_details': 'Скрыть подробности',
    'dashboard.quick_log': 'Быстрая запись',
    'dashboard.today': 'Недавние записи',
    'insights.title': 'Обзор',
    'insights.subtitle':
        'Закономерности в ваших записях — только по вашим собственным данным.',
    'insights.range_7': '7 дней',
    'insights.range_30': '30 дней',
    'insights.meals': 'Приёмы пищи',
    'insights.intakes': 'Приёмы лекарств',
    'insights.observations': 'Наблюдения',
    'insights.avg_protein': 'Средний белок на приём пищи',
    'insights.rhythm_title': 'Ритм записей',
    'insights.rhythm_subtitle': 'Записей в день',
    'insights.protein_title': 'Белок на приём пищи',
    'insights.protein_subtitle':
        'Граммы на записанный приём пищи, от старых к новым',
    'insights.daypart_title': 'Время суток',
    'insights.daypart_subtitle': 'Когда записывались приёмы пищи и лекарств',
    'insights.morning': 'Утро',
    'insights.midday': 'День',
    'insights.evening': 'Вечер',
    'insights.night': 'Ночь',
    'insights.empty': 'За этот период записей пока нет.',
    'insights.boundary':
        'Это описательные сводки ваших собственных записей, а не клинические измерения, цели или рекомендации; обсуждайте решения о здоровье с квалифицированным врачом.',
    'settings.local_ai_advanced': 'Дополнительно · Подключение локального ИИ',
    'nav.today': 'Сегодня',
    'nav.library': 'Справочник',
    'dashboard.log_prompt': 'Что вы хотите записать?',
    'dashboard.log_meal_hint':
        'Продукты и порции, проверка по учебным правилам',
    'dashboard.log_intake_hint': 'Принятая доза лекарства',
    'dashboard.log_observation_hint':
        'Давление, симптомы или двигательное состояние',
    'dashboard.open_timeline': 'Открыть хронологию',
    'dashboard.open_next_meal': 'Открыть следующий приём пищи',
    'library.my_medications': 'Мои лекарства',
    'library.catalog': 'Продукты и лекарства',
    'next_meal.title': 'Рекомендация на следующий приём пищи',
    'next_meal.subtitle':
        'Укажите предполагаемое время следующего приёма пищи. Консервативный путь правил сохраняет порядок кандидатов; механистическая модель лишь добавляет учебную трассу временного перекрытия и не ранжирует. Локальный ИИ — отдельный опциональный ранжировщик безопасного списка.',
    'next_meal.input_time': 'Планируемое время следующего приёма',
    'next_meal.use_local_ai': 'Полировка текста локальным ИИ (опционально)',
    'next_meal.use_local_ai_help':
        'Обращается только к Ollama/llama.cpp на localhost для переупорядочивания и переписывания объяснений для кандидатов, уже одобренных движком; возвращается на консервативный путь при блокировке защитным шлюзом.',
    'next_meal.generate': 'Сформировать рекомендацию',
    'next_meal.generating': 'Формируется…',
    'next_meal.empty':
        'Задайте время и нажмите «Сформировать рекомендацию»; движок пересчитает для этого окна.',
    'next_meal.why_these': 'Почему именно эти варианты',
    'next_meal.ai_polished': 'Отполировано локальным ИИ',
    'next_meal.conservative_engine': 'Консервативный путь конфликт-движка',
    'next_meal.recommendation_path': 'Путь рекомендации',
    'next_meal.gate_reasons': 'Заметки защитного шлюза',
    'next_meal.candidates': 'Лучшие кандидаты',
    'next_meal.no_candidates':
        'Нет подходящих кандидатов при текущих ограничениях. Скорректируйте время или расширьте каталог продуктов.',
    'next_meal.error': 'Сбой генерации',
    'dashboard.title': 'Панель',
    'dashboard.status': 'Обзор',
    'dashboard.logged_meals': 'Записано приёмов пищи: {count}',
    'dashboard.active_drugs': 'Активные лекарства: {count}',
    'dashboard.logged_intakes': 'Приёмы лекарств: {count}',
    'dashboard.recommendations': 'Рекомендации',
    'dashboard.no_recommendations': 'Пока нет рекомендаций',
    'dashboard.recommendation_path': 'Путь рекомендаций',
    'dashboard.recommendation_template':
        'Активный шаблон: {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'Использовано усиление локального ИИ',
    'dashboard.ai_not_used': 'Только консервативный путь',
    'dashboard.recommendation_why': 'Почему эти рекомендации',
    'dashboard.recommendation_gate': 'Состояние шлюза ИИ / безопасности',
    'dashboard.recommendation_macro_line':
        'На 100 г: Б {protein} г · У {carbs} г · Ж {fat} г',
    'dashboard.recommendation_score_line':
        'Безопасность {safety} · Расписание {schedule} · Факты {facts} · Штраф контекста {context} · Штраф окна {timing} · Штраф глотания {swallowing} · Совпадение шаблона {template}',
    'dashboard.recent_meals': 'Последние приёмы пищи (5 последних)',
    'dashboard.no_meals': 'Записей о приёмах пищи пока нет',
    'dashboard.items': '{count} элементов',
    'dashboard.meal_context_iron_supplement':
        'сопутствующее событие — добавка железа',
    'dashboard.meal_context_iron_multivitamin':
        'сопутствующее событие — поливитамины с железом',
    'dashboard.meal_context_starch_thickener': 'загуститель на основе крахмала',
    'dashboard.meal_context_xanthan_thickener':
        'загуститель на основе ксантана',
    'dashboard.meal_context_enteral_feed_continuous':
        'непрерывное энтеральное питание ({protein} г/день белка)',
    'dashboard.meal_context_enteral_feed_bolus':
        'болюсное / прерывистое энтеральное питание',
    'dashboard.edit': 'Изменить',
    'dashboard.delete': 'Удалить',
    'dashboard.protein_trend': 'Тенденция белка',
    'dashboard.average_protein': 'Средний белок: {value} г / приём',
    'dashboard.no_trend': 'Данных о тенденции пока нет',
    'dashboard.timeline': 'Хронология',
    'dashboard.no_timeline': 'Пока нет приёмов пищи или событий лекарств',
    'dashboard.add_meal': 'Добавить приём пищи',
    'dashboard.meal_check': 'Проверка приёма пищи - {title}',
    'timeline.title': 'Хронология приёмов пищи и лекарств',
    'timeline.empty': 'Пока нет приёмов пищи или приёмов лекарств',
    'timeline.add_meal': 'Добавить приём пищи',
    'timeline.add_intake': 'Записать приём лекарства',
    'timeline.new_intake': 'Новый приём лекарства',
    'timeline.edit_intake': 'Изменить приём лекарства',
    'timeline.medication': 'Лекарство',
    'timeline.active_medication_option': '{name} (активный)',
    'timeline.dosage_note': 'Заметка о дозе',
    'timeline.package_dose_source':
        'Источник: {source} · Получено: {retrieved} · {url}',
    'timeline.package_dose_derivation':
        'Расчёт: {strength} × {quantity} {unit} = {amount} {resultUnit}',
    'timeline.package_dose_assumed_denominator':
        'Источник не указал знаменатель; предполагается одна отдельная единица лекарственной формы ({unit}). Перед подтверждением проверьте маркировку препарата.',
    'timeline.package_dose_retrieval_unknown': 'Не записано',
    'timeline.taken_at': 'Принято в',
    'timeline.edit_taken_at': 'Изменить время приёма',
    'timeline.save_intake': 'Сохранить приём',
    'timeline.no_medications': 'Каталог лекарств недоступен',
    'timeline.select_medication_first': 'Сначала выберите лекарство',
    'timeline.save_intake_failed': 'Не удалось сохранить приём: {error}',
    'timeline.meal_macro_line':
        'Итого: белки {protein} г · углеводы {carbs} г · жиры {fat} г',
    'timeline.conflict_line': 'Проверка конфликта: {severity} · оценка {score}',
    'timeline.meal_window_line': 'Окно приёма пищи: {start} - {end}',
    'timeline.next_meal_window_line':
        'Окно следующего приёма пищи: {start} - {end}',
    'timeline.nearest_medication_line':
        'Ближайшее лекарство: {name} ({distance})',
    'timeline.nearest_meal_line': 'Ближайший приём пищи: {title} ({distance})',
    'timeline.dosage_line': 'Доза: {value}',
    'timeline.before': '{value} до',
    'timeline.after': '{value} после',
    'timeline.no_context_flags':
        'Нет флагов добавок, загустителей или энтерального питания',
    'common.close': 'Закрыть',
    'common.done': 'Готово',
    'common.cancel': 'Отмена',
    'common.apply': 'Применить',
    'common.optional': 'необязательно',
    'analytics.local_ai_medical_model': 'Название модели медицинской проверки',
    'common.delete': 'Удалить',
    'common.completed': 'Завершено',
    'common.error': 'Ошибка',
    'common.search_results': 'Результаты поиска',
    'common.no_matching_foods': 'Подходящие продукты не найдены',
    'common.texture': 'Текстура',
    'common.not_available': 'Не введено',
    'common.save': 'Сохранить',
    'common.edit': 'Изменить',
    'common.confirm': 'Подтвердить',
    'common.sign_out': 'Выйти',
    'meal_slot.breakfast': 'Завтрак',
    'meal_slot.lunch': 'Обед',
    'meal_slot.dinner': 'Ужин',
    'meal_slot.snack': 'Перекус',
    'meal.title': 'Питание',
    'meal.empty': 'Записей о приёмах пищи пока нет',
    'meal.check_title': 'Проверка приёма пищи - {title}',
    'medications.title': 'Лекарства',
    'catalog.title': 'Каталог',
    'catalog.search': 'Искать продукты или лекарства',
    'catalog.foods': 'Продукты',
    'catalog.drugs': 'Лекарства',
    'catalog.food_subtitle':
        'Категория={category}  Б/У/Ж={protein}/{carbs}/{fat} (на 100 г)',
    'catalog.drug_subtitle': 'Метки={tags}',
    'medications.view_detail': 'Подробности лекарства',
    'decision.block': 'Блокировать',
    'decision.require_review': 'Требуется проверка',
    'decision.discourage': 'Не рекомендуется',
    'decision.warn': 'Предупреждение',
    'decision.info': 'Информация',
    'decision.allow': 'Разрешить',
    'decision.defer': 'Отложить',
    'severity.low': 'Низкая',
    'severity.moderate': 'Средняя',
    'severity.high': 'Высокая',
    'severity.critical': 'Критическая',
    'missing.dose': 'доза',
    'missing.formulation': 'форма выпуска',
    'missing.time': 'время приёма лекарства',
    'missing.meal_time': 'время приёма пищи',
    'missing.coevent_time': 'время сопутствующего события',
    'missing.thickener_type': 'тип загустителя',
    'recommend.low_protein': 'Предпочтителен меньший белок',
    'recommend.protein_window_caution':
        'Будьте осторожны с высоким белком вблизи окна леводопы',
    'recommend.history_low_protein':
        'Недавняя история предполагает приоритет вариантов с меньшим содержанием белка',
    'recommend.culture_match':
        'Соответствует текущему региональному шаблону питания',
    'recommend.fallback_chain':
        'Знания о продуктах для этого региона используют резервную цепочку',
    'recommend.general_friendly': 'В целом подходящий вариант',
    'recommend.path.hybrid_local_ai':
        'Локальный ИИ переупорядочивает результаты',
    'recommend.path.conservative_safety_gate':
        'Консервативный путь (защитный шлюз заблокировал ИИ)',
    'recommend.path.conservative_gate_block':
        'Консервативный путь (локальный ИИ недоступен)',
    'recommend.path.fallback_invalid_ai':
        'Консервативный путь (вывод ИИ не прошёл проверку)',
    'recommend.path.conservative_cdss': 'Консервативный путь CDSS',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'Сервисы Ollama или llama.cpp на localhost не отвечают. Запустите локальный сервис модели или отключите локальное переупорядочивание ИИ.',
    'recommend.runtime.endpoint_must_be_localhost':
        'Конечная точка локального ИИ должна оставаться на localhost/127.0.0.1 и не может указывать на облачную конечную точку.',
    'recommend.runtime.safety_gate_conservative':
        'Защитный шлюз сохранил результат на консервативном пути.',
    'recommend.runtime.next_meal_window_missing':
        'Ожидаемое окно времени следующего приёма пищи отсутствует. Добавьте самое раннее и самое позднее время в Добавить/Изменить приём пищи.',
    'recommend.runtime.no_prior_meal_history':
        'Нет предыдущей истории приёмов пищи для безопасного переупорядочивания.',
    'recommend.runtime.legacy_meal_time':
        'Последний приём пищи всё ещё использует мигрированное устаревшее время; измените его на фактическое время еды.',
    'recommend.runtime.iron_conservative':
        'В последнем приёме пищи была записана добавка железа, поэтому переупорядочивание остаётся консервативным.',
    'recommend.runtime.iron_multivitamin_conservative':
        'В последнем приёме пищи были записаны поливитамины с железом, поэтому переупорядочивание остаётся консервативным.',
    'recommend.runtime.starch_thickener_conservative':
        'В последнем приёме пищи был записан загуститель на основе крахмала, поэтому сохраняется детерминированная проверка безопасности.',
    'recommend.runtime.enteral_conservative':
        'Контекст непрерывного энтерального питания активен, поэтому сохраняется детерминированная проверка.',
    'recommend.runtime.local_ai_not_consented':
        'Локальное переупорядочивание ИИ не было включено пользователем.',
    'recommend.runtime.local_ai_unavailable':
        'Конечная точка локального ИИ в настоящее время недоступна.',
    'recommend.runtime.returned_conservative':
        'Вместо этого возвращены детерминированные консервативные рекомендации.',
    'recommend.runtime.ai_validation_failed':
        'Структурированный вывод локального ИИ не прошёл проверку белого списка.',
    'recommend.runtime.ai_invalid_whitelist':
        'Локальный ИИ не вернул допустимое упорядочивание только из белого списка, поэтому результат не использовался.',
    'recommend.runtime.cdss_conservative_observations':
        'Консервативный путь CDSS использовал реальные наблюдения вариантов, когда они были доступны.',
    'recommend.runtime.local_ai_success':
        'Локальное переупорядочивание ИИ прошло успешно.',
    'recommend.runtime.local_ai_copy_polish_success':
        'Локальный ИИ улучшил формулировку текста.',
    'recommend.runtime.medgemma_optional_unavailable':
        'Конечная точка локального ИИ ответила; необязательная модель MedGemma недоступна.',
    'recommend.runtime.recommendation_conservative':
        'Рекомендация осталась на консервативном пути.',
    'recommend.runtime.levodopa_ai_sensitive':
        'Окно времени леводопы слишком чувствительно для переупорядочивания ИИ.',
    'recommend.context_iron_supplement':
        'С последним приёмом пищи была записана добавка железа, поэтому рекомендации по времени остаются консервативными.',
    'recommend.context_iron_multivitamin':
        'С последним приёмом пищи были записаны поливитамины с железом, поэтому рекомендации по времени остаются консервативными.',
    'recommend.context_starch_thickener':
        'Записан загуститель на основе крахмала, что повышает приоритет безопасности глотания.',
    'recommend.context_xanthan_thickener':
        'Для последнего приёма пищи записан загуститель на основе ксантана.',
    'recommend.context_enteral_feed_continuous':
        'Активно непрерывное энтеральное питание ({protein} г/день белка), поэтому формулировки рекомендаций остаются консервативными.',
    'recommend.context_enteral_feed_bolus':
        'Для последнего приёма пищи записано болюсное/прерывистое энтеральное питание.',
    'recommend.context_iron_penalty':
        'Присутствуют сопутствующие события, связанные с железом, поэтому варианты с более высоким содержанием белка консервативно понижены в рейтинге.',
    'recommend.context_enteral_penalty':
        'Присутствует контекст непрерывного энтерального питания, поэтому варианты с более высоким содержанием белка консервативно понижены в рейтинге.',
    'recommend.context_texture_gap_penalty':
        'Записан загуститель, но в текущем каталоге всё ещё отсутствуют структурированные данные совместимости текстуры, поэтому сохраняется дополнительный консервативный запас.',
    'recommend.context_texture_supported':
        'Записан загуститель, и этот кандидат уже содержит структурированные метаданные текстуры, поэтому штраф пробела данных остаётся ниже.',
    'recommend.texture_profile_missing':
        'Активен режим безопасности текстуры, но у этого кандидата отсутствуют структурированные метаданные текстуры, поэтому рейтинг остаётся более консервативным.',
    'recommend.texture_profile_supported_soft_or_liquid':
        'Этот кандидат соответствует текущему мягкому-или-жидкому режиму безопасности текстуры.',
    'recommend.texture_profile_supported_liquid_only':
        'Этот кандидат соответствует текущему режиму безопасности только-жидкая текстура.',
    'recommend.texture_profile_incompatible':
        'Этот кандидат не соответствует текущему режиму безопасности текстуры, поэтому консервативно понижен в рейтинге.',
    'recommend.texture_template_supported':
        'Этот кандидат соответствует направлению текстуры текущего шаблона приёма пищи.',
    'recommend.texture_template_mismatch':
        'Этот кандидат не соответствует направлению текстуры текущего шаблона приёма пищи.',
    'recommend.local_seed_metadata':
        'Этот кандидат всё ещё зависит от локальных метаданных-сидов вместо более богатых наблюдений из базы данных.',
    'recommend.timing_window_incomplete':
        'Окно времени неполное, поэтому консервативный рейтинг сохраняет дополнительный запас безопасности.',
    'recommend.next_meal_gap_close':
        'Окно следующего приёма пищи всё ещё близко к предыдущему приёму; предпочтителен вариант с меньшим содержанием белка.',
    'recommend.next_meal_window_fiber':
        'Это укладывается в запланированное окно следующего приёма пищи и способствует более стабильному потреблению клетчатки.',
    'recommend.medication_timing_caution':
        'Время приёма лекарств подсказывает дополнительную осторожность для этого окна следующего приёма пищи.',
    'texture_mode.unrestricted': 'Без ограничений',
    'texture_mode.soft_or_liquid': 'Мягкий или жидкий',
    'texture_mode.liquid_only': 'Только жидкий',
    'texture_class.liquid': 'Жидкий',
    'texture_class.soft': 'Мягкий',
    'texture_class.regular': 'Обычный',
    'food.food_chicken_breast': 'Куриная грудка (приготовленная)',
    'food.food_tofu': 'Обычный тофу',
    'food.food_brown_rice': 'Бурый рис',
    'food.food_banana': 'Банан',
    'food.food_spinach': 'Шпинат',
    'food.food_milk': 'Полуобезжиренное молоко',
    'food.food_beef': 'Постная говядина (жареная)',
    'food.food_apple': 'Яблоко (с кожурой)',
    'food.food_blueberry': 'Голубика',
    'food.food_tomato': 'Помидор',
    'food.food_broccoli': 'Брокколи',
    'food.food_oats': 'Овсяные хлопья',
    'food.food_salmon': 'Лосось (фермерский, запечённый)',
    'food.food_fava_beans': 'Конские бобы (свежие)',
    'food.food_potato_boiled': 'Картофель (варёный)',
    'food.food_walnuts': 'Грецкие орехи',
    'food.food_olive_oil': 'Оливковое масло Extra Virgin',
    'food.food_cheddar_cheese': 'Сыр чеддер',
    'food.food_egg_boiled': 'Яйцо (варёное)',
    'food.food_coffee': 'Кофе (заваренный, без сахара)',
    'observatory.dependency_closure.title': 'Готовность замыкания зависимостей',
    'observatory.dependency_closure.loading':
        'Загрузка зафиксированного манифеста корней · замыкание HOLD',
    'observatory.dependency_closure.unavailable':
        'HOLD · зафиксированный манифест корней недоступен',
    'observatory.dependency_closure.loading_semantics':
        'Загружается стабильный манифест корней результатов алгоритмов. Замыкание зависимостей остаётся в состоянии HOLD.',
    'observatory.dependency_closure.unavailable_semantics':
        'Стабильный манифест корней результатов алгоритмов недоступен. Замыкание зависимостей находится в состоянии HOLD.',
    'observatory.dependency_closure.semantics':
        '{count} стабильных зарегистрированных корней алгоритмов. Analyzer {analyzer} является заявленной точной версией для проверки. Офлайн-свидетельства совместимости не включены и не выполняются в этом представлении. Транзитивное замыкание зависимостей находится в состоянии HOLD до появления генератора рёбер ParkinSUM.',
    'observatory.dependency_closure.summary':
        '{count} / {total} стабильных корней · заявленная цель Analyzer {analyzer} · транзитивное замыкание HOLD',
    'observatory.dependency_closure.identity': '{schema} · {digest}… · {state}',
    'observatory.dependency_closure.registry_chip':
        'сопоставление Registry: структурно корректно',
    'observatory.dependency_closure.edge_chip': 'генератор рёбер: HOLD',
    'observatory.dependency_closure.closure_chip':
        'прямое/обратное замыкание: HOLD',
    'observatory.dependency_closure.details':
        'Доступная таблица стабильных корней',
    'observatory.dependency_closure.details_subtitle':
        'Только начальные узлы основных библиотек; сгенерированных рёбер зависимостей нет.',
    'observatory.dependency_closure.table_semantics':
        'Таблица стабильных корней алгоритмов. Столбцы: алгоритм, логический корень, приёмник результата и канонический URI пакета.',
    'observatory.dependency_closure.column_algorithm': 'Алгоритм',
    'observatory.dependency_closure.column_root': 'Логический корень',
    'observatory.dependency_closure.column_sink': 'Приёмник результата',
    'observatory.dependency_closure.column_uri': 'URI пакета',
    'observatory.dependency_closure.boundary':
        'Это представление подтверждает только зафиксированный структурный контракт Registry-корень. Офлайн-свидетельства совместимости Analyzer здесь не включены и не выполняются. Оно не показывает и не заявляет граф вызовов, SCC, прямое/обратное замыкание, выполнение, точный поток данных, научную или клиническую валидацию, безопасность, пользу либо медицинскую рекомендацию.',
  },

  // ===========================================================================
  // pl (Polish)
  // ===========================================================================
  'pl': {
    'reminders.locale_reconciliation_title':
        'Język przypomnień systemowych jest inny',
    'reminders.locale_reconciliation_body':
        'Język aplikacji się zmienił. Zachowaj obecny tekst albo atomowo zaktualizuj wszystkie przypomnienia na tym urządzeniu. Żadna opcja nie pokazuje utworzonych etykiet.',
    'reminders.locale_retain_action': 'Zachowaj obecny język',
    'reminders.locale_update_action': 'Zaktualizuj wszystkie',
    'reminders.locale_retained_confirmation':
        'Zachowano obecny język przypomnień systemowych.',
    'reminders.locale_updated_confirmation':
        'Zażądano aktualizacji wszystkich przypomnień do obecnego języka.',
    'diagnostics.title': 'Diagnostyka techniczna',
    'diagnostics.rerun': 'Uruchom kontrole ponownie',
    'diagnostics.scope_title': 'Wyłącznie przegląd techniczny',
    'diagnostics.scope_body':
        'To deterministyczne kontrole nadzoru (kompilacja tekstów, kontrola bezpieczeństwa lokalizacji, odtwarzanie syntetycznych scenariuszy). Raportują wyłącznie stan techniczny: nie zmieniają wyniku, istotności, dowodów ani rezultatu reguł i nie są poradą zdrowotną. Wyłącznie dane syntetyczne/demonstracyjne.',
    'diagnostics.elapsed': 'Kontrole zakończone w {ms} ms.',
    'reminders.identity_attestation_title':
        'Kontrola oczekujących identyfikatorów zgłoszonych przez wtyczkę',
    'reminders.identity_attestation_matched':
        'Oczekujące identyfikatory zgłoszone przez wtyczkę odpowiadają planowi ({installed}/{planned}). Nie jest to niezależna weryfikacja harmonogramu systemu operacyjnego ani widocznego dostarczenia.',
    'reminders.identity_attestation_drift':
        'Identyfikatory zgłoszone przez wtyczkę różnią się od planu: brakuje {missing}, dodatkowych jest {extra}, a {replaced} zastąpiono pod zaplanowanym ID. Nie polegaj na przypomnieniach systemowych do udanej synchronizacji.',
    'reminders.identity_attestation_uninspectable':
        'Nie można odczytać oczekujących identyfikatorów z wtyczki. Lokalny plan pozostaje źródłem prawdy, ale stan przypomnień systemowych nie jest zweryfikowany.',
    'reminders.error_schedule_identity_unverified':
        'Lokalny plan zapisano, ale oczekujących identyfikatorów wtyczki nie można było z nim porównać. Przed poleganiem na przypomnieniach systemowych ponów synchronizację.',
    'reminders.readiness_title':
        'Gotowość dostarczania przypomnień systemowych',
    'reminders.readiness_contract': 'Kontrakt możliwości {platform} · {digest}',
    'reminders.readiness_boundary':
        'Zakończone żądanie harmonogramu ani zgodna tożsamość wtyczki nie dowodzą widocznego dostarczenia, dostarczenia na ekran blokady ani w tle.',
    'reminders.readiness_platform_android': 'Android',
    'reminders.readiness_platform_ios': 'iOS',
    'reminders.readiness_platform_macos': 'macOS',
    'reminders.readiness_platform_web': 'Web',
    'reminders.readiness_platform_windows': 'Windows',
    'reminders.readiness_platform_linux': 'Linux',
    'reminders.readiness_platform_unknown':
        'Nieznana platforma lub niestandardowa brama',
    'reminders.readiness_local_plan': 'Plan lokalny',
    'reminders.readiness_adapter': 'Adapter harmonogramu',
    'reminders.readiness_schedule_request': 'Żądanie harmonogramu',
    'reminders.readiness_permission_request': 'Żądanie uprawnienia',
    'reminders.readiness_permission_inspection':
        'Sprawdzenie bieżącego uprawnienia',
    'reminders.readiness_registry': 'Rejestr oczekujących żądań wtyczki',
    'reminders.readiness_visible_delivery': 'Widoczne dostarczenie',
    'reminders.readiness_body_tap': 'Stuknięcie treści powiadomienia',
    'reminders.readiness_cold_start': 'Zimny start z powiadomienia',
    'reminders.readiness_background_action': 'Działanie w tle',
    'reminders.readiness_local_none': 'Nie skonfigurowano planu lokalnego',
    'reminders.readiness_local_saved': 'Zapisano na tym urządzeniu',
    'reminders.readiness_adapter_plan_only':
        'Tylko plan; API powiadomień systemowych nie jest wywoływane',
    'reminders.readiness_evidence_artifact_verified':
        'Zweryfikowano na podstawie dowodów platformy docelowej powiązanych z artefaktem',
    'reminders.readiness_evidence_implemented_unverified':
        'Zaimplementowano; brak weryfikacji na urządzeniu docelowym powiązanej z artefaktem',
    'reminders.readiness_evidence_unavailable':
        'Niedostępne lub niezaimplementowane',
    'reminders.readiness_request_not_requested': 'Nie wysłano',
    'reminders.readiness_request_applied':
        'Żądanie wtyczki zakończone; dostarczenie nie jest udowodnione',
    'reminders.readiness_request_rolled_back':
        'Nowe żądanie harmonogramu wycofano i przywrócono poprzedni plan; dostarczenie nie jest udowodnione',
    'reminders.readiness_request_superseded':
        'Zastąpiono przez nowsze konto lub plan',
    'reminders.readiness_request_unsupported':
        'Ten kontrakt obejmuje tylko plan',
    'reminders.readiness_request_failed':
        'Żądanie nie powiodło się lub tożsamość nie jest zweryfikowana',
    'reminders.readiness_request_recovery_required':
        'Przed poleganiem na funkcji wymagane jest uzgodnienie',
    'reminders.readiness_permission_not_requested': 'Nie zażądano w tej sesji',
    'reminders.readiness_permission_granted':
        'Wywołanie żądania uprawnienia zwróciło dozwolone; nie jest to bieżący stan',
    'reminders.readiness_permission_denied':
        'Wywołanie żądania uprawnienia zwróciło niedozwolone; nie dowodzi jawnej odmowy użytkownika',
    'reminders.readiness_permission_failed':
        'Żądanie uprawnienia nie powiodło się lub adapter jest niedostępny; nie oznacza to odmowy użytkownika',
    'reminders.readiness_permission_unavailable':
        'Ten kontrakt możliwości nie żąda uprawnienia',
    'reminders.readiness_inspection_not_inspected':
        'Nie sprawdzono bieżącego stanu uprawnienia',
    'reminders.readiness_inspection_enabled':
        'Bieżące sprawdzenie wtyczki zwróciło włączone; nie jest to dowód dostarczenia',
    'reminders.readiness_inspection_disabled':
        'Bieżące sprawdzenie wtyczki zwróciło wyłączone; nie ustala przyczyny ani wyboru użytkownika',
    'reminders.readiness_inspection_unavailable':
        'Sprawdzenie bieżącego uprawnienia jest niedostępne; nie oznacza to odmowy użytkownika',
    'reminders.readiness_inspection_failed':
        'Sprawdzenie bieżącego uprawnienia nie powiodło się; nie oznacza to odmowy użytkownika',
    'reminders.readiness_registry_not_inspected': 'Nie sprawdzono',
    'reminders.readiness_registry_matched':
        'Raport wtyczki jest zgodny z planem lokalnym; nie jest to dowód dostarczenia przez system operacyjny',
    'reminders.readiness_registry_drift':
        'Raport wtyczki różni się od planu lokalnego',
    'reminders.readiness_registry_uninspectable':
        'Nie można odczytać tożsamości wtyczki',
    'reminders.readiness_registry_unsupported':
        'Ten kontrakt możliwości nie sprawdza natywnego rejestru',
    'reminders.readiness_visible_unverified': 'Niezweryfikowane',
    'reminders.readiness_visible_artifact_verified':
        'Zweryfikowano na podstawie dowodów artefaktu platformy docelowej',
    'app.welcome': 'Witamy',
    'app.loading': 'Ładowanie...',
    'onboarding.title': 'ParkinSUM Towarzysz (Wersja Lokalna)',
    'onboarding.description':
        'Ta aplikacja służy wyłącznie do rejestrowania posiłków i wskazówek opartych na regułach. Nie zastępuje porady lekarza ani farmaceuty.',
    'onboarding.registration_region': 'Region rejestracji',
    'onboarding.registration_region_help':
        'Określa domyślny łańcuch jurysdykcji i priorytet źródeł.',
    'onboarding.display_language': 'Język interfejsu',
    'onboarding.display_language_help':
        'Kontroluje język aplikacji oraz formatowanie daty i liczb.',
    'onboarding.diet_profile_region': 'Region profilu diety',
    'onboarding.diet_profile_region_help':
        'Używany do domyślnych szablonów posiłków bez nadpisywania reguł bezpieczeństwa.',
    'onboarding.swallowing_texture_mode':
        'Tryb bezpieczeństwa połykania / tekstury',
    'onboarding.swallowing_texture_mode_help':
        'Używany jako zachowawcza preferencja rekomendacji, nie jako kliniczna ocena połykania.',
    'onboarding.content_override': 'Nadpisanie jurysdykcji treści (opcjonalne)',
    'onboarding.content_override_help': 'Oddzielone przecinkami, np. US,CA',
    'onboarding.local_ai_consent':
        'Włącz lokalne ponowne ranking AI (opcjonalne)',
    'onboarding.local_ai_consent_help':
        'Używa tylko Ollama/llama.cpp na localhost i wraca do ścieżki zachowawczej, gdy bramki bezpieczeństwa go blokują.',
    'onboarding.start': 'Rozumiem, kontynuuj',
    'nav.home': 'Start',
    'nav.analytics': 'Analiza',
    'nav.meals': 'Posiłki',
    'nav.timeline': 'Oś czasu',
    'nav.meds': 'Leki',
    'nav.catalog': 'Katalog',
    'nav.next_meal': 'Następny posiłek',
    'shell.tagline': 'Towarzysz · prototyp badawczy',
    'shell.workspace': 'Obszar roboczy',
    'shell.care_workspace': 'Przygotowanie do wizyty i sprawy do wyjaśnienia',
    'shell.boundary_note':
        'Prototyp edukacyjny — to nie jest porada medyczna. Decyzje zdrowotne omawiaj z wykwalifikowanym klinicystą.',
    'dashboard.greeting_morning': 'Dzień dobry',
    'dashboard.greeting_afternoon': 'Dzień dobry',
    'dashboard.greeting_evening': 'Dobry wieczór',
    'dashboard.subtitle':
        'Przegląd zapisanych posiłków, przyjęć leków i reguł stojących za każdym wyjaśnieniem.',
    'dashboard.stat_meals': 'Zapisane posiłki',
    'dashboard.stat_drugs': 'Aktywne leki',
    'dashboard.stat_intakes': 'Zapisane przyjęcia',
    'shell.new_entry': 'Nowy wpis',
    'shell.search': 'Szukaj',
    'shell.search_hint': 'Szukaj stron, narzędzi i działań',
    'shell.search_empty': 'Brak pasujących stron, narzędzi lub działań',
    'shell.menu': 'Menu',
    'shell.group.evidence': 'Dowody i reguły',
    'shell.group.data': 'Twoje dane',
    'shell.group.operations': 'Operacje',
    'shell.group.pages': 'Strony',
    'shell.action.observation': 'Zapisz obserwację',
    'dashboard.stat_protein': 'Średnie białko na posiłek',
    'dashboard.show_details': 'Pokaż szczegóły',
    'dashboard.hide_details': 'Ukryj szczegóły',
    'dashboard.quick_log': 'Szybki wpis',
    'dashboard.today': 'Ostatnia aktywność',
    'insights.title': 'Wglądy',
    'insights.subtitle':
        'Wzorce w tym, co zapisujesz — wyłącznie z Twoich wpisów.',
    'insights.range_7': '7 dni',
    'insights.range_30': '30 dni',
    'insights.meals': 'Posiłki',
    'insights.intakes': 'Przyjęcia leków',
    'insights.observations': 'Obserwacje',
    'insights.avg_protein': 'Średnie białko na posiłek',
    'insights.rhythm_title': 'Rytm zapisów',
    'insights.rhythm_subtitle': 'Wpisy dziennie',
    'insights.protein_title': 'Białko na posiłek',
    'insights.protein_subtitle': 'Gramy na zapisany posiłek, od najstarszego',
    'insights.daypart_title': 'Pora dnia',
    'insights.daypart_subtitle': 'Kiedy zapisywano posiłki i przyjęcia leków',
    'insights.morning': 'Rano',
    'insights.midday': 'Południe',
    'insights.evening': 'Wieczór',
    'insights.night': 'Noc',
    'insights.empty': 'Brak wpisów w tym okresie.',
    'insights.boundary':
        'To opisowe podsumowania Twoich własnych wpisów, a nie pomiary kliniczne, cele ani porady; decyzje zdrowotne omawiaj z wykwalifikowanym klinicystą.',
    'settings.local_ai_advanced': 'Zaawansowane · Połączenie z lokalną AI',
    'nav.today': 'Dziś',
    'nav.library': 'Biblioteka',
    'dashboard.log_prompt': 'Co chcesz zapisać?',
    'dashboard.log_meal_hint':
        'Produkty i porcje, sprawdzane regułami edukacyjnymi',
    'dashboard.log_intake_hint': 'Przyjęta dawka leku',
    'dashboard.log_observation_hint': 'Ciśnienie, objawy lub stan ruchowy',
    'dashboard.open_timeline': 'Otwórz oś czasu',
    'dashboard.open_next_meal': 'Otwórz następny posiłek',
    'library.my_medications': 'Moje leki',
    'library.catalog': 'Żywność i leki',
    'next_meal.title': 'Rekomendacja następnego posiłku',
    'next_meal.subtitle':
        'Wybierz przewidywaną godzinę następnego posiłku. Zachowawcza ścieżka reguł utrzymuje kolejność kandydatów; model mechanistyczny dodaje tylko edukacyjny ślad nakładania w czasie i nie zmienia kolejności. Lokalna AI to osobny, opcjonalny moduł listy bezpiecznej.',
    'next_meal.input_time': 'Planowana godzina następnego posiłku',
    'next_meal.use_local_ai': 'Poleruj tekst lokalną AI (opcjonalnie)',
    'next_meal.use_local_ai_help':
        'Wywołuje tylko Ollama/llama.cpp na localhost, aby ponownie uszeregować i przepisać wyjaśnienia kandydatów już zatwierdzonych przez silnik; wraca do ścieżki zachowawczej, gdy bramka bezpieczeństwa zablokuje.',
    'next_meal.generate': 'Wygeneruj rekomendację',
    'next_meal.generating': 'Generowanie…',
    'next_meal.empty':
        'Ustaw planowany czas i dotknij "Wygeneruj rekomendację"; silnik dokona ponownej oceny dla tego okna.',
    'next_meal.why_these': 'Dlaczego te propozycje',
    'next_meal.ai_polished': 'Wypolerowano przez lokalną AI',
    'next_meal.conservative_engine': 'Ścieżka zachowawcza silnika konfliktów',
    'next_meal.recommendation_path': 'Ścieżka rekomendacji',
    'next_meal.gate_reasons': 'Notatki bramki bezpieczeństwa',
    'next_meal.candidates': 'Najlepsi kandydaci',
    'next_meal.no_candidates':
        'Brak odpowiednich kandydatów przy bieżących ograniczeniach. Dostosuj czas lub rozszerz katalog żywności.',
    'next_meal.error': 'Generowanie nie powiodło się',
    'dashboard.title': 'Panel',
    'dashboard.status': 'Przegląd',
    'dashboard.logged_meals': 'Zarejestrowane posiłki: {count}',
    'dashboard.active_drugs': 'Aktywne leki: {count}',
    'dashboard.logged_intakes': 'Przyjęcia leków: {count}',
    'dashboard.recommendations': 'Rekomendacje',
    'dashboard.no_recommendations': 'Brak rekomendacji',
    'dashboard.recommendation_path': 'Ścieżka rekomendacji',
    'dashboard.recommendation_template':
        'Aktywny szablon: {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'Użyto wzmocnienia lokalnego AI',
    'dashboard.ai_not_used': 'Tylko ścieżka zachowawcza',
    'dashboard.recommendation_why': 'Dlaczego te rekomendacje',
    'dashboard.recommendation_gate': 'Stan bramki AI / bezpieczeństwa',
    'dashboard.recommendation_macro_line':
        'Na 100 g: B {protein} g · W {carbs} g · T {fat} g',
    'dashboard.recommendation_score_line':
        'Bezpieczeństwo {safety} · Harmonogram {schedule} · Fakty {facts} · Kara kontekstu {context} · Kara okna {timing} · Kara połykania {swallowing} · Dopasowanie szablonu {template}',
    'dashboard.recent_meals': 'Ostatnie posiłki (ostatnie 5)',
    'dashboard.no_meals': 'Brak zarejestrowanych posiłków',
    'dashboard.items': '{count} pozycji',
    'dashboard.meal_context_iron_supplement':
        'współzdarzenie z suplementem żelaza',
    'dashboard.meal_context_iron_multivitamin':
        'współzdarzenie z multiwitaminą z żelazem',
    'dashboard.meal_context_starch_thickener': 'zagęstnik skrobiowy',
    'dashboard.meal_context_xanthan_thickener': 'zagęstnik na bazie ksantanu',
    'dashboard.meal_context_enteral_feed_continuous':
        'ciągłe żywienie dojelitowe ({protein} g/dzień białka)',
    'dashboard.meal_context_enteral_feed_bolus':
        'żywienie dojelitowe w bolusie / przerywane',
    'dashboard.edit': 'Edytuj',
    'dashboard.delete': 'Usuń',
    'dashboard.protein_trend': 'Trend białka',
    'dashboard.average_protein': 'Średnie białko: {value} g / posiłek',
    'dashboard.no_trend': 'Brak danych o trendzie',
    'dashboard.timeline': 'Oś czasu',
    'dashboard.no_timeline': 'Brak posiłków lub zdarzeń lekowych',
    'dashboard.add_meal': 'Dodaj posiłek',
    'dashboard.meal_check': 'Kontrola posiłku - {title}',
    'timeline.title': 'Oś czasu posiłków i leków',
    'timeline.empty': 'Brak posiłków lub przyjęć leków',
    'timeline.add_meal': 'Dodaj posiłek',
    'timeline.add_intake': 'Zarejestruj lek',
    'timeline.new_intake': 'Nowe przyjęcie leku',
    'timeline.edit_intake': 'Edytuj przyjęcie leku',
    'timeline.medication': 'Lek',
    'timeline.active_medication_option': '{name} (aktywny)',
    'timeline.dosage_note': 'Notatka o dawce',
    'timeline.package_dose_source':
        'Źródło: {source} · Pobrano: {retrieved} · {url}',
    'timeline.package_dose_derivation':
        'Obliczenie: {strength} × {quantity} {unit} = {amount} {resultUnit}',
    'timeline.package_dose_assumed_denominator':
        'Źródło nie podało mianownika; przyjęto jedną dyskretną jednostkę postaci leku ({unit}). Przed potwierdzeniem sprawdź etykietę produktu.',
    'timeline.package_dose_retrieval_unknown': 'Nie zapisano',
    'timeline.taken_at': 'Przyjęto o',
    'timeline.edit_taken_at': 'Edytuj czas przyjęcia',
    'timeline.save_intake': 'Zapisz przyjęcie',
    'timeline.no_medications': 'Brak dostępnego katalogu leków',
    'timeline.select_medication_first': 'Najpierw wybierz lek',
    'timeline.save_intake_failed': 'Nie udało się zapisać przyjęcia: {error}',
    'timeline.meal_macro_line':
        'Razem: białko {protein} g · węglowodany {carbs} g · tłuszcz {fat} g',
    'timeline.conflict_line': 'Przegląd konfliktu: {severity} · wynik {score}',
    'timeline.meal_window_line': 'Okno posiłku: {start} - {end}',
    'timeline.next_meal_window_line':
        'Okno następnego posiłku: {start} - {end}',
    'timeline.nearest_medication_line': 'Najbliższy lek: {name} ({distance})',
    'timeline.nearest_meal_line': 'Najbliższy posiłek: {title} ({distance})',
    'timeline.dosage_line': 'Dawka: {value}',
    'timeline.before': '{value} przed',
    'timeline.after': '{value} po',
    'timeline.no_context_flags':
        'Brak flag suplementu, zagęstnika lub żywienia dojelitowego',
    'common.close': 'Zamknij',
    'common.done': 'Gotowe',
    'common.cancel': 'Anuluj',
    'common.apply': 'Zastosuj',
    'common.optional': 'opcjonalne',
    'analytics.local_ai_medical_model': 'Nazwa modelu przegladu medycznego',
    'common.delete': 'Usuń',
    'common.completed': 'Ukończone',
    'common.error': 'Błąd',
    'common.search_results': 'Wyniki wyszukiwania',
    'common.no_matching_foods': 'Nie znaleziono pasujących produktów',
    'common.texture': 'Tekstura',
    'common.not_available': 'Nie wprowadzono',
    'common.save': 'Zapisz',
    'common.edit': 'Edytuj',
    'common.confirm': 'Potwierdź',
    'common.sign_out': 'Wyloguj',
    'meal_slot.breakfast': 'Śniadanie',
    'meal_slot.lunch': 'Obiad',
    'meal_slot.dinner': 'Kolacja',
    'meal_slot.snack': 'Przekąska',
    'meal.title': 'Posiłki',
    'meal.empty': 'Brak zarejestrowanych posiłków',
    'meal.check_title': 'Kontrola posiłku - {title}',
    'medications.title': 'Leki',
    'catalog.title': 'Katalog',
    'catalog.search': 'Szukaj produktów lub leków',
    'catalog.foods': 'Produkty',
    'catalog.drugs': 'Leki',
    'catalog.food_subtitle':
        'Kategoria={category}  B/W/T={protein}/{carbs}/{fat} (na 100 g)',
    'catalog.drug_subtitle': 'Tagi={tags}',
    'medications.view_detail': 'Zobacz szczegóły leku',
    'decision.block': 'Zablokuj',
    'decision.require_review': 'Wymaga przeglądu',
    'decision.discourage': 'Niezalecane',
    'decision.warn': 'Ostrzeżenie',
    'decision.info': 'Informacja',
    'decision.allow': 'Zezwól',
    'decision.defer': 'Odłóż',
    'severity.low': 'Niska',
    'severity.moderate': 'Umiarkowana',
    'severity.high': 'Wysoka',
    'severity.critical': 'Krytyczna',
    'missing.dose': 'dawka',
    'missing.formulation': 'postać',
    'missing.time': 'czas leku',
    'missing.meal_time': 'czas posiłku',
    'missing.coevent_time': 'czas współzdarzenia',
    'missing.thickener_type': 'typ zagęstnika',
    'recommend.low_protein': 'Preferowana niższa zawartość białka',
    'recommend.protein_window_caution':
        'Zachowaj ostrożność z większą ilością białka w pobliżu okna lewodopy',
    'recommend.history_low_protein':
        'Niedawna historia sugeruje priorytet opcji z mniejszą zawartością białka',
    'recommend.culture_match':
        'Pasuje do bieżącego regionalnego szablonu diety',
    'recommend.fallback_chain':
        'Wiedza o produktach dla tego regionu używa łańcucha rezerwowego',
    'recommend.general_friendly': 'Ogólnie odpowiednia opcja',
    'recommend.path.hybrid_local_ai': 'Lokalna AI pomaga w przeszeregowaniu',
    'recommend.path.conservative_safety_gate':
        'Ścieżka zachowawcza (bramka bezpieczeństwa zablokowała AI)',
    'recommend.path.conservative_gate_block':
        'Ścieżka zachowawcza (lokalna AI niedostępna)',
    'recommend.path.fallback_invalid_ai':
        'Ścieżka zachowawcza (wyjście AI nie przeszło walidacji)',
    'recommend.path.conservative_cdss': 'Ścieżka zachowawcza CDSS',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'Żadna usługa Ollama ani llama.cpp na localhost nie odpowiedziała. Uruchom usługę modelu lokalnego lub wyłącz lokalne przeszeregowanie AI.',
    'recommend.runtime.endpoint_must_be_localhost':
        'Punkt końcowy lokalnej AI musi pozostać na localhost/127.0.0.1 i nie może wskazywać na punkt końcowy w chmurze.',
    'recommend.runtime.safety_gate_conservative':
        'Bramka bezpieczeństwa utrzymała wynik na ścieżce zachowawczej.',
    'recommend.runtime.next_meal_window_missing':
        'Brak oczekiwanego okna czasu następnego posiłku. Dodaj najwcześniejszy i najpóźniejszy czas w Dodaj/Edytuj posiłek.',
    'recommend.runtime.no_prior_meal_history':
        'Brak wcześniejszej historii posiłków do bezpiecznego przeszeregowania.',
    'recommend.runtime.legacy_meal_time':
        'Najnowszy posiłek nadal używa zmigrowanego starszego czasu; edytuj go na rzeczywisty czas spożycia.',
    'recommend.runtime.iron_conservative':
        'W ostatnim posiłku odnotowano suplement żelaza, więc przeszeregowanie pozostaje zachowawcze.',
    'recommend.runtime.iron_multivitamin_conservative':
        'W ostatnim posiłku odnotowano multiwitaminę z żelazem, więc przeszeregowanie pozostaje zachowawcze.',
    'recommend.runtime.starch_thickener_conservative':
        'W ostatnim posiłku odnotowano zagęstnik skrobiowy, więc utrzymana jest deterministyczna kontrola bezpieczeństwa.',
    'recommend.runtime.enteral_conservative':
        'Aktywny jest kontekst ciągłego żywienia dojelitowego, więc utrzymana jest deterministyczna kontrola.',
    'recommend.runtime.local_ai_not_consented':
        'Lokalne przeszeregowanie AI nie zostało włączone przez użytkownika.',
    'recommend.runtime.local_ai_unavailable':
        'Punkt końcowy lokalnej AI jest obecnie niedostępny.',
    'recommend.runtime.returned_conservative':
        'Zwrócono zamiast tego deterministyczne zachowawcze rekomendacje.',
    'recommend.runtime.ai_validation_failed':
        'Wyjście strukturalne lokalnej AI nie przeszło walidacji białej listy.',
    'recommend.runtime.ai_invalid_whitelist':
        'Lokalna AI nie zwróciła prawidłowego porządku tylko z białej listy, więc wynik nie został użyty.',
    'recommend.runtime.cdss_conservative_observations':
        'Ścieżka zachowawcza CDSS użyła rzeczywistych obserwacji wariantów, gdy były dostępne.',
    'recommend.runtime.local_ai_success':
        'Lokalne przeszeregowanie AI zakończyło się powodzeniem.',
    'recommend.runtime.local_ai_copy_polish_success':
        'Lokalna AI wygladzila tekst rekomendacji.',
    'recommend.runtime.medgemma_optional_unavailable':
        'Lokalny punkt koncowy AI odpowiedzial; opcjonalny model MedGemma jest niedostepny.',
    'recommend.runtime.recommendation_conservative':
        'Rekomendacja pozostała na ścieżce zachowawczej.',
    'recommend.runtime.levodopa_ai_sensitive':
        'Okno czasu lewodopy jest zbyt wrażliwe na przeszeregowanie AI.',
    'recommend.context_iron_supplement':
        'Suplement żelaza odnotowany przy ostatnim posiłku, więc wskazówki czasowe pozostają zachowawcze.',
    'recommend.context_iron_multivitamin':
        'Multiwitamina z żelazem odnotowana przy ostatnim posiłku, więc wskazówki czasowe pozostają zachowawcze.',
    'recommend.context_starch_thickener':
        'Odnotowano zagęstnik skrobiowy, co podnosi priorytet bezpieczeństwa połykania.',
    'recommend.context_xanthan_thickener':
        'Odnotowano zagęstnik na bazie ksantanu dla ostatniego posiłku.',
    'recommend.context_enteral_feed_continuous':
        'Aktywne ciągłe żywienie dojelitowe ({protein} g/dzień białka), więc sformułowanie rekomendacji pozostaje zachowawcze.',
    'recommend.context_enteral_feed_bolus':
        'Żywienie dojelitowe w bolusie/przerywane odnotowane dla ostatniego posiłku.',
    'recommend.context_iron_penalty':
        'Występują współzdarzenia związane z żelazem, więc opcje z większą zawartością białka są zachowawczo obniżane w rankingu.',
    'recommend.context_enteral_penalty':
        'Występuje kontekst ciągłego żywienia dojelitowego, więc opcje z większą zawartością białka są zachowawczo obniżane w rankingu.',
    'recommend.context_texture_gap_penalty':
        'Odnotowano zagęstnik, ale w aktualnym katalogu nadal brakuje strukturalnych danych zgodności tekstury, więc utrzymywana jest dodatkowa zachowawcza marża.',
    'recommend.context_texture_supported':
        'Odnotowano zagęstnik, a ten kandydat ma już strukturalne metadane tekstury, więc kara za lukę danych pozostaje niższa.',
    'recommend.texture_profile_missing':
        'Aktywny jest tryb bezpieczeństwa tekstury, ale ten kandydat nie ma strukturalnych metadanych tekstury, więc ranking pozostaje bardziej zachowawczy.',
    'recommend.texture_profile_supported_soft_or_liquid':
        'Ten kandydat pasuje do bieżącego trybu bezpieczeństwa tekstury miękkiej lub płynnej.',
    'recommend.texture_profile_supported_liquid_only':
        'Ten kandydat pasuje do bieżącego trybu bezpieczeństwa tekstury tylko-płynnej.',
    'recommend.texture_profile_incompatible':
        'Ten kandydat nie pasuje do bieżącego trybu bezpieczeństwa tekstury, więc jest zachowawczo obniżany w rankingu.',
    'recommend.texture_template_supported':
        'Ten kandydat pasuje do kierunku tekstury bieżącego szablonu posiłku.',
    'recommend.texture_template_mismatch':
        'Ten kandydat nie pasuje do kierunku tekstury bieżącego szablonu posiłku.',
    'recommend.local_seed_metadata':
        'Ten kandydat nadal opiera się na metadanych lokalnego seeda zamiast bogatszych obserwacji opartych na bazie danych.',
    'recommend.timing_window_incomplete':
        'Okno czasowe jest niekompletne, więc ranking zachowawczy utrzymuje dodatkowy margines bezpieczeństwa.',
    'recommend.next_meal_gap_close':
        'Okno następnego posiłku jest nadal blisko poprzedniego; preferowana jest opcja z mniejszą zawartością białka.',
    'recommend.next_meal_window_fiber':
        'To pasuje do zaplanowanego okna następnego posiłku i sprzyja stabilniejszemu spożyciu błonnika.',
    'recommend.medication_timing_caution':
        'Czasy leków sugerują dodatkową ostrożność dla tego okna następnego posiłku.',
    'texture_mode.unrestricted': 'Bez ograniczeń',
    'texture_mode.soft_or_liquid': 'Miękki lub płynny',
    'texture_mode.liquid_only': 'Tylko płynny',
    'texture_class.liquid': 'Płynny',
    'texture_class.soft': 'Miękki',
    'texture_class.regular': 'Zwykły',
    'food.food_chicken_breast': 'Pierś z kurczaka (gotowana)',
    'food.food_tofu': 'Tofu naturalne',
    'food.food_brown_rice': 'Ryż brązowy',
    'food.food_banana': 'Banan',
    'food.food_spinach': 'Szpinak',
    'food.food_milk': 'Mleko półtłuste',
    'food.food_beef': 'Chuda wołowina (smażona)',
    'food.food_apple': 'Jabłko (ze skórką)',
    'food.food_blueberry': 'Borówka',
    'food.food_tomato': 'Pomidor',
    'food.food_broccoli': 'Brokuł',
    'food.food_oats': 'Płatki owsiane',
    'food.food_salmon': 'Łosoś (hodowlany, pieczony)',
    'food.food_fava_beans': 'Bób (świeży)',
    'food.food_potato_boiled': 'Ziemniak (gotowany)',
    'food.food_walnuts': 'Orzechy włoskie',
    'food.food_olive_oil': 'Oliwa z oliwek extra virgin',
    'food.food_cheddar_cheese': 'Ser cheddar',
    'food.food_egg_boiled': 'Jajko (gotowane)',
    'food.food_coffee': 'Kawa (zaparzona, niesłodzona)',
    'observatory.dependency_closure.title': 'Gotowość domknięcia zależności',
    'observatory.dependency_closure.loading':
        'Wczytywanie manifestu korzeni zapisanego w repozytorium · domknięcie HOLD',
    'observatory.dependency_closure.unavailable':
        'HOLD · manifest korzeni zapisany w repozytorium jest niedostępny',
    'observatory.dependency_closure.loading_semantics':
        'Trwa wczytywanie stabilnego manifestu korzeni wyników algorytmów. Domknięcie zależności pozostaje w stanie HOLD.',
    'observatory.dependency_closure.unavailable_semantics':
        'Stabilny manifest korzeni wyników algorytmów jest niedostępny. Domknięcie zależności jest w stanie HOLD.',
    'observatory.dependency_closure.semantics':
        '{count} stabilnych zarejestrowanych korzeni algorytmów. Analyzer {analyzer} jest zadeklarowaną dokładną wersją docelową przeglądu. Dowody zgodności offline nie są dołączone ani wykonywane w tym widoku. Przechodnie domknięcie zależności jest w stanie HOLD do czasu udostępnienia generatora krawędzi ParkinSUM.',
    'observatory.dependency_closure.summary':
        '{count} / {total} stabilnych korzeni · zadeklarowany cel Analyzer {analyzer} · domknięcie przechodnie HOLD',
    'observatory.dependency_closure.identity': '{schema} · {digest}… · {state}',
    'observatory.dependency_closure.registry_chip':
        'mapowanie Registry: strukturalnie poprawne',
    'observatory.dependency_closure.edge_chip': 'generator krawędzi: HOLD',
    'observatory.dependency_closure.closure_chip':
        'domknięcie w przód/wstecz: HOLD',
    'observatory.dependency_closure.details':
        'Dostępna tabela stabilnych korzeni',
    'observatory.dependency_closure.details_subtitle':
        'Tylko ziarna bibliotek głównych; bez wygenerowanych krawędzi zależności.',
    'observatory.dependency_closure.table_semantics':
        'Tabela stabilnych korzeni algorytmów. Kolumny to algorytm, korzeń logiczny, ujście wyniku i kanoniczny URI pakietu.',
    'observatory.dependency_closure.column_algorithm': 'Algorytm',
    'observatory.dependency_closure.column_root': 'Korzeń logiczny',
    'observatory.dependency_closure.column_sink': 'Ujście wyniku',
    'observatory.dependency_closure.column_uri': 'URI pakietu',
    'observatory.dependency_closure.boundary':
        'Ten widok potwierdza wyłącznie zapisany w repozytorium kontrakt strukturalny Registry-korzeń. Dowody zgodności Analyzer offline nie są tutaj dołączone ani wykonywane. Widok nie przedstawia ani nie deklaruje grafu wywołań, SCC, domknięcia w przód/wstecz, wykonania, dokładnego przepływu danych, walidacji naukowej lub klinicznej, bezpieczeństwa, korzyści ani porady medycznej.',
  },

  // ===========================================================================
  // ar (Arabic)
  // ===========================================================================
  'ar': {
    'reminders.locale_reconciliation_title': 'لغة تذكيرات النظام مختلفة',
    'reminders.locale_reconciliation_body':
        'تغيّرت لغة التطبيق. يمكنك الاحتفاظ بنص التذكيرات الحالي أو تحديث كل تذكيرات هذا الجهاز بصورة ذرّية. لا يعرض أي خيار التسميات التي كتبتها.',
    'reminders.locale_retain_action': 'الاحتفاظ باللغة الحالية',
    'reminders.locale_update_action': 'تحديث الكل إلى اللغة الحالية',
    'reminders.locale_retained_confirmation':
        'تم الاحتفاظ بلغة تذكيرات النظام الحالية.',
    'reminders.locale_updated_confirmation':
        'طُلب تحديث كل تذكيرات النظام إلى اللغة الحالية.',
    'diagnostics.title': 'تشخيصات هندسية',
    'diagnostics.rerun': 'إعادة تشغيل الفحوصات',
    'diagnostics.scope_title': 'للمراجعة الهندسية فقط',
    'diagnostics.scope_body':
        'هذه فحوصات حوكمة حتمية (تجميع النصوص، فحص سلامة الترجمة، إعادة تشغيل سيناريوهات اصطناعية). تُبلّغ عن الحالة الهندسية فقط: فهي لا تغيّر أي درجة أو شدة أو دليل أو نتيجة قاعدة، وليست إرشادًا صحيًا. بيانات اصطناعية/تجريبية فقط.',
    'diagnostics.elapsed': 'اكتملت الفحوصات في {ms} مللي ثانية.',
    'reminders.identity_attestation_title':
        'فحص هويات الطلبات المعلقة التي أبلغت عنها الإضافة',
    'reminders.identity_attestation_matched':
        'تتطابق الهويات المعلقة التي أبلغت عنها الإضافة مع الخطة ({installed}/{planned}). هذا ليس تحققًا مستقلاً من مجدول نظام التشغيل أو من ظهور الإشعار فعليًا.',
    'reminders.identity_attestation_drift':
        'تختلف الهويات التي أبلغت عنها الإضافة عن الخطة: {missing} مفقودة و{extra} إضافية و{replaced} مستبدلة تحت معرّف مخطط. لا تعتمد على تذكيرات النظام حتى تنجح إعادة المزامنة.',
    'reminders.identity_attestation_uninspectable':
        'تعذر قراءة هويات الطلبات المعلقة من الإضافة. تظل الخطة المحلية هي المرجع، لكن حالة تذكيرات النظام غير متحقق منها.',
    'reminders.error_schedule_identity_unverified':
        'تم حفظ الخطة المحلية، لكن تعذر مطابقة الهويات المعلقة التي أبلغت عنها الإضافة معها. أعد المزامنة قبل الاعتماد على تذكيرات النظام.',
    'reminders.readiness_title': 'جاهزية تسليم تذكيرات النظام',
    'reminders.readiness_contract': 'عقد قدرات {platform} · {digest}',
    'reminders.readiness_boundary':
        'لا يثبت اكتمال طلب الجدولة أو تطابق هوية المكوّن الإضافي حدوث تسليم مرئي أو على شاشة القفل أو في الخلفية.',
    'reminders.readiness_platform_android': 'Android',
    'reminders.readiness_platform_ios': 'iOS',
    'reminders.readiness_platform_macos': 'macOS',
    'reminders.readiness_platform_web': 'Web',
    'reminders.readiness_platform_windows': 'Windows',
    'reminders.readiness_platform_linux': 'Linux',
    'reminders.readiness_platform_unknown': 'منصة غير معروفة أو بوابة مخصّصة',
    'reminders.readiness_local_plan': 'خطة محلية',
    'reminders.readiness_adapter': 'مهايئ الجدولة',
    'reminders.readiness_schedule_request': 'طلب الجدولة',
    'reminders.readiness_permission_request': 'طلب الإذن',
    'reminders.readiness_permission_inspection': 'فحص حالة الإذن الحالية',
    'reminders.readiness_registry': 'سجل الطلبات المعلقة للمكوّن الإضافي',
    'reminders.readiness_visible_delivery': 'التسليم المرئي',
    'reminders.readiness_body_tap': 'النقر على متن الإشعار',
    'reminders.readiness_cold_start': 'التشغيل البارد من الإشعار',
    'reminders.readiness_background_action': 'إجراء في الخلفية',
    'reminders.readiness_local_none': 'لم تُضبط خطة محلية',
    'reminders.readiness_local_saved': 'محفوظ على هذا الجهاز',
    'reminders.readiness_adapter_plan_only':
        'خطة فقط؛ لا يتم استدعاء واجهة API لإشعارات النظام',
    'reminders.readiness_evidence_artifact_verified':
        'تم التحقق بأدلة مرتبطة بأثر الإصدار للمنصة المستهدفة',
    'reminders.readiness_evidence_implemented_unverified':
        'تم التنفيذ؛ لا يوجد تحقق على الجهاز المستهدف مرتبط بأثر الإصدار',
    'reminders.readiness_evidence_unavailable': 'غير متاح أو لم يتم تنفيذه',
    'reminders.readiness_request_not_requested': 'لم يُرسل',
    'reminders.readiness_request_applied':
        'اكتمل طلب المكوّن الإضافي؛ لم يثبت التسليم',
    'reminders.readiness_request_rolled_back':
        'تم التراجع عن طلب الجدولة الجديد واستعادة الخطة السابقة؛ لم يثبت التسليم',
    'reminders.readiness_request_superseded': 'استُبدل بحساب أو خطة أحدث',
    'reminders.readiness_request_unsupported': 'هذا العقد مخصّص للخطة فقط',
    'reminders.readiness_request_failed':
        'فشل الطلب أو لم يتم التحقق من الهوية',
    'reminders.readiness_request_recovery_required':
        'يلزم التوفيق قبل الاعتماد عليه',
    'reminders.readiness_permission_not_requested': 'لم يُطلب في هذه الجلسة',
    'reminders.readiness_permission_granted':
        'أعادت مكالمة طلب الإذن حالة مسموح؛ ولا يعادل ذلك الحالة الحالية',
    'reminders.readiness_permission_denied':
        'أعادت مكالمة طلب الإذن حالة غير مسموح؛ ولا يثبت ذلك رفضاً صريحاً من المستخدم',
    'reminders.readiness_permission_failed':
        'فشل طلب الإذن أو كان المهايئ غير متاح؛ ولا يعني ذلك أن المستخدم رفضه',
    'reminders.readiness_permission_unavailable':
        'عقد القدرات هذا لا يطلب الإذن',
    'reminders.readiness_inspection_not_inspected':
        'لم تُفحص حالة الإذن الحالية',
    'reminders.readiness_inspection_enabled':
        'أعاد الفحص الحالي للمكوّن الإضافي حالة مفعّل؛ وليس ذلك دليلاً على التسليم',
    'reminders.readiness_inspection_disabled':
        'أعاد الفحص الحالي للمكوّن الإضافي حالة معطّل؛ ولا يحدد ذلك السبب أو اختيار المستخدم',
    'reminders.readiness_inspection_unavailable':
        'فحص حالة الإذن الحالية غير متاح؛ ولا يعني ذلك رفض المستخدم',
    'reminders.readiness_inspection_failed':
        'فشل فحص حالة الإذن الحالية؛ ولا يعني ذلك رفض المستخدم',
    'reminders.readiness_registry_not_inspected': 'لم يُفحص',
    'reminders.readiness_registry_matched':
        'يتطابق تقرير المكوّن الإضافي مع الخطة المحلية؛ وليس دليلاً على تسليم نظام التشغيل',
    'reminders.readiness_registry_drift':
        'يختلف تقرير المكوّن الإضافي عن الخطة المحلية',
    'reminders.readiness_registry_uninspectable':
        'تعذر قراءة هويات المكوّن الإضافي',
    'reminders.readiness_registry_unsupported':
        'عقد القدرات هذا لا يفحص سجلاً أصلياً',
    'reminders.readiness_visible_unverified': 'غير متحقق منه',
    'reminders.readiness_visible_artifact_verified':
        'تم التحقق بأدلة أثر الإصدار للمنصة المستهدفة',
    'app.welcome': 'مرحباً',
    'app.loading': 'جارٍ التحميل...',
    'onboarding.title': 'ParkinSUM رفيقك (الإصدار المحلي)',
    'onboarding.description':
        'هذا التطبيق مخصّص فقط لتسجيل الوجبات وتقديم إرشادات قائمة على القواعد. لا يحلّ محلّ نصيحة طبيبك أو الصيدلي.',
    'onboarding.registration_region': 'منطقة التسجيل',
    'onboarding.registration_region_help':
        'تحدّد سلسلة الاختصاص الافتراضية وأولوية المصادر.',
    'onboarding.display_language': 'لغة العرض',
    'onboarding.display_language_help':
        'تتحكم في لغة التطبيق وتنسيق التاريخ والأرقام.',
    'onboarding.diet_profile_region': 'منطقة الملف الغذائي',
    'onboarding.diet_profile_region_help':
        'تُستخدم لقوالب الوجبات الافتراضية دون تجاوز قواعد السلامة.',
    'onboarding.swallowing_texture_mode': 'وضع سلامة البلع / القوام',
    'onboarding.swallowing_texture_mode_help':
        'يُستخدم تفضيلًا تحفظيًا للتوصيات وليس تقييمًا سريريًا للبلع.',
    'onboarding.content_override': 'تجاوز اختصاص المحتوى (اختياري)',
    'onboarding.content_override_help': 'مفصول بفواصل، مثلاً US,CA',
    'onboarding.local_ai_consent':
        'تفعيل إعادة الترتيب بواسطة الذكاء الاصطناعي المحلي (اختياري)',
    'onboarding.local_ai_consent_help':
        'يستخدم فقط Ollama/llama.cpp على localhost ويعود إلى المسار المحافظ عندما تحجبه بوابات الأمان.',
    'onboarding.start': 'فهمت، تابع',
    'nav.home': 'الرئيسية',
    'nav.analytics': 'التحليلات',
    'nav.meals': 'الوجبات',
    'nav.timeline': 'المخطط الزمني',
    'nav.meds': 'الأدوية',
    'nav.catalog': 'الكتالوج',
    'nav.next_meal': 'الوجبة التالية',
    'shell.tagline': 'رفيق · نموذج أولي بحثي',
    'shell.workspace': 'مساحة العمل',
    'shell.care_workspace': 'التحضير للزيارة والمتابعة',
    'shell.boundary_note':
        'نموذج تعليمي أولي — ليس نصيحة طبية. راجع قرارات الصحة مع طبيب مؤهل.',
    'dashboard.greeting_morning': 'صباح الخير',
    'dashboard.greeting_afternoon': 'مساء الخير',
    'dashboard.greeting_evening': 'مساء الخير',
    'dashboard.subtitle':
        'نظرة عامة على وجباتك وجرعات الأدوية المسجلة والقواعد وراء كل تفسير.',
    'dashboard.stat_meals': 'الوجبات المسجلة',
    'dashboard.stat_drugs': 'الأدوية النشطة',
    'dashboard.stat_intakes': 'الجرعات المسجلة',
    'shell.new_entry': 'إدخال جديد',
    'shell.search': 'بحث',
    'shell.search_hint': 'ابحث في الصفحات والأدوات والإجراءات',
    'shell.search_empty': 'لا توجد صفحات أو أدوات أو إجراءات مطابقة',
    'shell.menu': 'القائمة',
    'shell.group.evidence': 'الأدلة والقواعد',
    'shell.group.data': 'بياناتك',
    'shell.group.operations': 'التشغيل',
    'shell.group.pages': 'الصفحات',
    'shell.action.observation': 'تسجيل ملاحظة',
    'dashboard.stat_protein': 'متوسط البروتين لكل وجبة',
    'dashboard.show_details': 'عرض التفاصيل',
    'dashboard.hide_details': 'إخفاء التفاصيل',
    'dashboard.quick_log': 'تسجيل سريع',
    'dashboard.today': 'النشاط الأخير',
    'insights.title': 'رؤى',
    'insights.subtitle': 'أنماط مما سجلته، مستمدة من إدخالاتك فقط.',
    'insights.range_7': '7 أيام',
    'insights.range_30': '30 يومًا',
    'insights.meals': 'الوجبات',
    'insights.intakes': 'جرعات الأدوية',
    'insights.observations': 'الملاحظات',
    'insights.avg_protein': 'متوسط البروتين لكل وجبة',
    'insights.rhythm_title': 'إيقاع التسجيل',
    'insights.rhythm_subtitle': 'الإدخالات يوميًا',
    'insights.protein_title': 'البروتين لكل وجبة',
    'insights.protein_subtitle':
        'الغرامات لكل وجبة مسجلة، من الأقدم إلى الأحدث',
    'insights.daypart_title': 'وقت اليوم',
    'insights.daypart_subtitle': 'متى سُجلت الوجبات وجرعات الأدوية',
    'insights.morning': 'الصباح',
    'insights.midday': 'الظهيرة',
    'insights.evening': 'المساء',
    'insights.night': 'الليل',
    'insights.empty': 'لا توجد تسجيلات في هذه الفترة بعد.',
    'insights.boundary':
        'هذه ملخصات وصفية لإدخالاتك فقط، وليست قياسات سريرية أو أهدافًا أو نصائح؛ راجع قرارات الصحة مع طبيب مؤهل.',
    'settings.local_ai_advanced': 'متقدم · اتصال الذكاء الاصطناعي المحلي',
    'nav.today': 'اليوم',
    'nav.library': 'المكتبة',
    'dashboard.log_prompt': 'ماذا تريد أن تسجل؟',
    'dashboard.log_meal_hint': 'الأطعمة والكميات، تُفحص وفق القواعد التعليمية',
    'dashboard.log_intake_hint': 'جرعة دواء تناولتها',
    'dashboard.log_observation_hint': 'ضغط الدم أو الأعراض أو الحالة الحركية',
    'dashboard.open_timeline': 'فتح الخط الزمني',
    'dashboard.open_next_meal': 'فتح الوجبة التالية',
    'library.my_medications': 'أدويتي',
    'library.catalog': 'الأطعمة والأدوية',
    'next_meal.title': 'توصية الوجبة التالية',
    'next_meal.subtitle':
        'حدد الوقت المتوقع للوجبة التالية. يحافظ مسار القواعد المحافظ على ترتيب المرشحات؛ ولا يضيف النموذج الآلي إلا أثرًا تعليميًا للتداخل الزمني ولا يعيد الترتيب. الذكاء الاصطناعي المحلي أداة منفصلة واختيارية لإعادة ترتيب القائمة الآمنة.',
    'next_meal.input_time': 'الوقت المتوقع للوجبة التالية',
    'next_meal.use_local_ai':
        'تلميع الصياغة بالذكاء الاصطناعي المحلي (اختياري)',
    'next_meal.use_local_ai_help':
        'يستدعي فقط Ollama/llama.cpp على localhost لإعادة الترتيب وإعادة كتابة شرح المرشحات التي اعتمدها المحرّك مسبقًا؛ ويعود إلى المسار المحافظ عندما تحجبه بوابة الأمان.',
    'next_meal.generate': 'إنشاء التوصية',
    'next_meal.generating': 'جارٍ الإنشاء…',
    'next_meal.empty':
        'حدد الوقت المتوقع واضغط «إنشاء التوصية»؛ سيعيد المحرّك التقييم لتلك النافذة.',
    'next_meal.why_these': 'لماذا هذه الخيارات',
    'next_meal.ai_polished': 'تم التلميع بواسطة الذكاء الاصطناعي المحلي',
    'next_meal.conservative_engine': 'المسار المحافظ لمحرّك التعارض',
    'next_meal.recommendation_path': 'مسار التوصية',
    'next_meal.gate_reasons': 'ملاحظات بوابة الأمان',
    'next_meal.candidates': 'أفضل المرشحات',
    'next_meal.no_candidates':
        'لا توجد مرشحة مناسبة ضمن القيود الحالية. عدّل الوقت أو وسّع كتالوج الأطعمة.',
    'next_meal.error': 'فشل الإنشاء',
    'dashboard.title': 'لوحة التحكم',
    'dashboard.status': 'نظرة عامة',
    'dashboard.logged_meals': 'الوجبات المسجلة: {count}',
    'dashboard.active_drugs': 'الأدوية النشطة: {count}',
    'dashboard.logged_intakes': 'جرعات الأدوية: {count}',
    'dashboard.recommendations': 'التوصيات',
    'dashboard.no_recommendations': 'لا توجد توصيات بعد',
    'dashboard.recommendation_path': 'مسار التوصية',
    'dashboard.recommendation_template':
        'القالب النشط: {region} · {mealSlot} · {texture}',
    'dashboard.ai_used': 'تم استخدام تعزيز الذكاء الاصطناعي المحلي',
    'dashboard.ai_not_used': 'المسار المحافظ فقط',
    'dashboard.recommendation_why': 'لماذا هذه التوصيات',
    'dashboard.recommendation_gate': 'حالة بوابة الذكاء الاصطناعي / السلامة',
    'dashboard.recommendation_macro_line':
        'لكل 100 جم: ب {protein} جم · ك {carbs} جم · د {fat} جم',
    'dashboard.recommendation_score_line':
        'السلامة {safety} · الجدول {schedule} · الحقائق {facts} · عقوبة السياق {context} · عقوبة النافذة {timing} · عقوبة البلع {swallowing} · مطابقة القالب {template}',
    'dashboard.recent_meals': 'الوجبات الأخيرة (آخر 5)',
    'dashboard.no_meals': 'لم يتم تسجيل وجبات بعد',
    'dashboard.items': '{count} عناصر',
    'dashboard.meal_context_iron_supplement': 'حدث مرافق مع مكمّل الحديد',
    'dashboard.meal_context_iron_multivitamin':
        'حدث مرافق مع فيتامين متعدد يحتوي على الحديد',
    'dashboard.meal_context_starch_thickener': 'مثخّن قائم على النشا',
    'dashboard.meal_context_xanthan_thickener': 'مثخّن قائم على الزانتان',
    'dashboard.meal_context_enteral_feed_continuous':
        'تغذية معوية مستمرة ({protein} جم/يوم بروتين)',
    'dashboard.meal_context_enteral_feed_bolus': 'تغذية معوية بجرعة / متقطعة',
    'dashboard.edit': 'تعديل',
    'dashboard.delete': 'حذف',
    'dashboard.protein_trend': 'اتجاه البروتين',
    'dashboard.average_protein': 'متوسط البروتين: {value} جم / وجبة',
    'dashboard.no_trend': 'لا توجد بيانات اتجاه بعد',
    'dashboard.timeline': 'المخطط الزمني',
    'dashboard.no_timeline': 'لا توجد وجبات أو أحداث دوائية بعد',
    'dashboard.add_meal': 'إضافة وجبة',
    'dashboard.meal_check': 'فحص الوجبة - {title}',
    'timeline.title': 'المخطط الزمني للوجبات والأدوية',
    'timeline.empty': 'لا توجد وجبات أو جرعات أدوية بعد',
    'timeline.add_meal': 'إضافة وجبة',
    'timeline.add_intake': 'تسجيل دواء',
    'timeline.new_intake': 'جرعة دواء جديدة',
    'timeline.edit_intake': 'تعديل جرعة دواء',
    'timeline.medication': 'دواء',
    'timeline.active_medication_option': '{name} (نشط)',
    'timeline.dosage_note': 'ملاحظة الجرعة',
    'timeline.package_dose_source':
        'المصدر: {source} · وقت الاسترجاع: {retrieved} · {url}',
    'timeline.package_dose_derivation':
        'الحساب: {strength} × {quantity} {unit} = {amount} {resultUnit}',
    'timeline.package_dose_assumed_denominator':
        'لم يذكر المصدر المقام؛ افترضنا وحدة جرعة منفصلة واحدة ({unit}). تحقّق من ملصق المنتج قبل التأكيد.',
    'timeline.package_dose_retrieval_unknown': 'غير مسجل',
    'timeline.taken_at': 'أُخذ في',
    'timeline.edit_taken_at': 'تعديل وقت الأخذ',
    'timeline.save_intake': 'حفظ الجرعة',
    'timeline.no_medications': 'لا يوجد كتالوج أدوية متاح',
    'timeline.select_medication_first': 'اختر دواءً أولاً',
    'timeline.save_intake_failed': 'فشل حفظ الجرعة: {error}',
    'timeline.meal_macro_line':
        'الإجمالي: بروتين {protein} جم · كربوهيدرات {carbs} جم · دهون {fat} جم',
    'timeline.conflict_line': 'مراجعة التعارض: {severity} · النتيجة {score}',
    'timeline.meal_window_line': 'نافذة الوجبة: {start} - {end}',
    'timeline.next_meal_window_line': 'نافذة الوجبة التالية: {start} - {end}',
    'timeline.nearest_medication_line': 'أقرب دواء: {name} ({distance})',
    'timeline.nearest_meal_line': 'أقرب وجبة: {title} ({distance})',
    'timeline.dosage_line': 'الجرعة: {value}',
    'timeline.before': 'قبل {value}',
    'timeline.after': 'بعد {value}',
    'timeline.no_context_flags': 'لا توجد علامات مكمّل أو مثخّن أو تغذية معوية',
    'common.close': 'إغلاق',
    'common.done': 'تم',
    'common.cancel': 'إلغاء',
    'common.apply': 'تطبيق',
    'common.optional': 'اختياري',
    'analytics.local_ai_medical_model': 'اسم نموذج المراجعة الطبية',
    'common.delete': 'حذف',
    'common.completed': 'مكتمل',
    'common.error': 'خطأ',
    'common.search_results': 'نتائج البحث',
    'common.no_matching_foods': 'لم يُعثر على أطعمة مطابقة',
    'common.texture': 'القوام',
    'common.not_available': 'لم يُدخل',
    'common.save': 'حفظ',
    'common.edit': 'تعديل',
    'common.confirm': 'تأكيد',
    'common.sign_out': 'تسجيل الخروج',
    'meal_slot.breakfast': 'الإفطار',
    'meal_slot.lunch': 'الغداء',
    'meal_slot.dinner': 'العشاء',
    'meal_slot.snack': 'وجبة خفيفة',
    'meal.title': 'الوجبات',
    'meal.empty': 'لم يتم تسجيل وجبات بعد',
    'meal.check_title': 'فحص الوجبة - {title}',
    'medications.title': 'الأدوية',
    'catalog.title': 'الكتالوج',
    'catalog.search': 'ابحث عن أطعمة أو أدوية',
    'catalog.foods': 'الأطعمة',
    'catalog.drugs': 'الأدوية',
    'catalog.food_subtitle':
        'الفئة={category}  ب/ك/د={protein}/{carbs}/{fat} (لكل 100 جم)',
    'catalog.drug_subtitle': 'الوسوم={tags}',
    'medications.view_detail': 'عرض تفاصيل الدواء',
    'decision.block': 'حظر',
    'decision.require_review': 'يتطلب المراجعة',
    'decision.discourage': 'غير مستحسن',
    'decision.warn': 'تحذير',
    'decision.info': 'معلومات',
    'decision.allow': 'سماح',
    'decision.defer': 'تأجيل',
    'severity.low': 'منخفض',
    'severity.moderate': 'متوسط',
    'severity.high': 'مرتفع',
    'severity.critical': 'حرج',
    'missing.dose': 'الجرعة',
    'missing.formulation': 'الشكل الدوائي',
    'missing.time': 'وقت الدواء',
    'missing.meal_time': 'وقت الوجبة',
    'missing.coevent_time': 'وقت الحدث المرافق',
    'missing.thickener_type': 'نوع المثخّن',
    'recommend.low_protein': 'يفضّل البروتين الأقل',
    'recommend.protein_window_caution':
        'احذر من البروتين العالي قرب نافذة الليفودوبا',
    'recommend.history_low_protein':
        'يقترح السجل الأخير إعطاء الأولوية لخيارات أقل بروتينًا',
    'recommend.culture_match': 'يتطابق مع قالب الحمية الإقليمي الحالي',
    'recommend.fallback_chain':
        'تستخدم معرفة الأطعمة لهذه المنطقة سلسلة احتياطية',
    'recommend.general_friendly': 'خيار مناسب بشكل عام',
    'recommend.path.hybrid_local_ai': 'الذكاء الاصطناعي المحلي يعيد الترتيب',
    'recommend.path.conservative_safety_gate':
        'مسار محافظ (بوابة الأمان حجبت الذكاء الاصطناعي)',
    'recommend.path.conservative_gate_block':
        'مسار محافظ (الذكاء الاصطناعي المحلي غير متاح)',
    'recommend.path.fallback_invalid_ai':
        'مسار محافظ (مخرج الذكاء الاصطناعي لم يجتز التحقق)',
    'recommend.path.conservative_cdss': 'مسار CDSS المحافظ',
    'recommend.runtime.local_ai_endpoint_unavailable':
        'لم يستجب أي خدمة Ollama أو llama.cpp على localhost. ابدأ خدمة النموذج المحلي أو عطّل إعادة الترتيب بالذكاء الاصطناعي المحلي.',
    'recommend.runtime.endpoint_must_be_localhost':
        'يجب أن يبقى نقطة نهاية الذكاء الاصطناعي المحلي على localhost/127.0.0.1 ولا يمكن أن تشير إلى نقطة نهاية سحابية.',
    'recommend.runtime.safety_gate_conservative':
        'حافظت بوابة الأمان على بقاء النتيجة على المسار المحافظ.',
    'recommend.runtime.next_meal_window_missing':
        'نافذة وقت الوجبة التالية المتوقعة مفقودة. أضف أبكر وأحدث وقت في إضافة/تعديل الوجبة.',
    'recommend.runtime.no_prior_meal_history':
        'لا يتوفر سجل وجبات سابقة لإعادة ترتيب آمنة.',
    'recommend.runtime.legacy_meal_time':
        'لا تزال أحدث وجبة تستخدم توقيتًا قديمًا مهاجَرًا؛ عدّله إلى وقت الأكل الحقيقي.',
    'recommend.runtime.iron_conservative':
        'سُجل مكمّل حديد في أحدث وجبة، لذا تبقى إعادة الترتيب محافظة.',
    'recommend.runtime.iron_multivitamin_conservative':
        'سُجل فيتامين متعدد يحتوي على الحديد في أحدث وجبة، لذا تبقى إعادة الترتيب محافظة.',
    'recommend.runtime.starch_thickener_conservative':
        'سُجل مثخّن قائم على النشا في أحدث وجبة، لذا تُحفظ مراجعة السلامة الحتمية.',
    'recommend.runtime.enteral_conservative':
        'سياق التغذية المعوية المستمرة نشط، لذا تُحفظ المراجعة الحتمية.',
    'recommend.runtime.local_ai_not_consented':
        'لم يفعّل المستخدم إعادة ترتيب الذكاء الاصطناعي المحلي.',
    'recommend.runtime.local_ai_unavailable':
        'نقطة نهاية الذكاء الاصطناعي المحلي غير متاحة حاليًا.',
    'recommend.runtime.returned_conservative':
        'أعادت توصيات محافظة حتمية بدلًا من ذلك.',
    'recommend.runtime.ai_validation_failed':
        'فشل المخرج المنظم للذكاء الاصطناعي المحلي في التحقق من القائمة البيضاء.',
    'recommend.runtime.ai_invalid_whitelist':
        'لم يُرجع الذكاء الاصطناعي المحلي ترتيبًا صحيحًا من القائمة البيضاء فقط، لذا لم تُستخدم النتيجة.',
    'recommend.runtime.cdss_conservative_observations':
        'استخدم مسار CDSS المحافظ ملاحظات المتغيرات الفعلية عند توفرها.',
    'recommend.runtime.local_ai_success':
        'نجحت إعادة ترتيب الذكاء الاصطناعي المحلي.',
    'recommend.runtime.local_ai_copy_polish_success':
        'حسّن الذكاء الاصطناعي المحلي صياغة النص.',
    'recommend.runtime.medgemma_optional_unavailable':
        'استجابت نقطة نهاية الذكاء الاصطناعي المحلي؛ نموذج MedGemma الاختياري غير متاح.',
    'recommend.runtime.recommendation_conservative':
        'بقيت التوصية على المسار المحافظ.',
    'recommend.runtime.levodopa_ai_sensitive':
        'نافذة توقيت الليفودوبا حساسة جدًا لإعادة الترتيب بالذكاء الاصطناعي.',
    'recommend.context_iron_supplement':
        'سُجل مكمّل حديد مع أحدث وجبة، لذا تبقى إرشادات التوقيت محافظة.',
    'recommend.context_iron_multivitamin':
        'سُجل فيتامين متعدد يحتوي على الحديد مع أحدث وجبة، لذا تبقى إرشادات التوقيت محافظة.',
    'recommend.context_starch_thickener':
        'سُجل مثخّن قائم على النشا، مما يرفع أولوية سلامة البلع.',
    'recommend.context_xanthan_thickener':
        'سُجل مثخّن قائم على الزانتان لأحدث وجبة.',
    'recommend.context_enteral_feed_continuous':
        'التغذية المعوية المستمرة نشطة ({protein} جم/يوم بروتين)، لذا تبقى صياغة التوصيات محافظة.',
    'recommend.context_enteral_feed_bolus':
        'سُجلت تغذية معوية بجرعة/متقطعة لأحدث وجبة.',
    'recommend.context_iron_penalty':
        'توجد أحداث مرافقة متعلقة بالحديد، لذا تبقى الخيارات الأعلى بروتينًا منخفضة الترتيب بشكل محافظ.',
    'recommend.context_enteral_penalty':
        'سياق التغذية المعوية المستمرة موجود، لذا تبقى الخيارات الأعلى بروتينًا منخفضة الترتيب بشكل محافظ.',
    'recommend.context_texture_gap_penalty':
        'سُجل مثخّن، لكن الكتالوج الحالي ما زال يفتقر إلى بيانات توافق قوام منظمة، لذا يُحفظ هامش محافظ إضافي.',
    'recommend.context_texture_supported':
        'سُجل مثخّن، وهذا المرشح يحمل بالفعل بيانات قوام منظمة، لذا تبقى عقوبة فجوة البيانات أقل.',
    'recommend.texture_profile_missing':
        'وضع سلامة القوام نشط، لكن هذا المرشح يفتقر إلى بيانات قوام منظمة، لذا يبقى الترتيب أكثر محافظة.',
    'recommend.texture_profile_supported_soft_or_liquid':
        'يتطابق هذا المرشح مع وضع سلامة القوام الناعم-أو-السائل الحالي.',
    'recommend.texture_profile_supported_liquid_only':
        'يتطابق هذا المرشح مع وضع سلامة القوام السائل فقط الحالي.',
    'recommend.texture_profile_incompatible':
        'لا يتطابق هذا المرشح مع وضع سلامة القوام الحالي، لذا يُخفض ترتيبه بشكل محافظ.',
    'recommend.texture_template_supported':
        'يتطابق هذا المرشح مع اتجاه قوام قالب الوجبة الحالي.',
    'recommend.texture_template_mismatch':
        'لا يتطابق هذا المرشح مع اتجاه قوام قالب الوجبة الحالي.',
    'recommend.local_seed_metadata':
        'لا يزال هذا المرشح يعتمد على بيانات seed محلية بدلًا من ملاحظات أغنى مدعومة بقاعدة بيانات.',
    'recommend.timing_window_incomplete':
        'نافذة التوقيت غير مكتملة، لذا يحفظ الترتيب المحافظ هامش أمان إضافيًا.',
    'recommend.next_meal_gap_close':
        'نافذة الوجبة التالية لا تزال قريبة من الوجبة السابقة؛ يفضل خيار أقل بروتينًا.',
    'recommend.next_meal_window_fiber':
        'يلائم نافذة الوجبة التالية المخططة ويعزّز استهلاكًا أكثر استقرارًا للألياف.',
    'recommend.medication_timing_caution':
        'يقترح توقيت الدواء مزيدًا من الحذر لنافذة الوجبة التالية هذه.',
    'texture_mode.unrestricted': 'بدون قيود',
    'texture_mode.soft_or_liquid': 'ناعم أو سائل',
    'texture_mode.liquid_only': 'سائل فقط',
    'texture_class.liquid': 'سائل',
    'texture_class.soft': 'ناعم',
    'texture_class.regular': 'عادي',
    'food.food_chicken_breast': 'صدر دجاج (مطهو)',
    'food.food_tofu': 'توفو سادة',
    'food.food_brown_rice': 'أرز بني',
    'food.food_banana': 'موز',
    'food.food_spinach': 'سبانخ',
    'food.food_milk': 'حليب نصف منزوع الدسم',
    'food.food_beef': 'لحم بقر قليل الدهن (مقلي)',
    'food.food_apple': 'تفاح (بالقشر)',
    'food.food_blueberry': 'توت أزرق',
    'food.food_tomato': 'طماطم',
    'food.food_broccoli': 'بروكلي',
    'food.food_oats': 'شوفان مدلفن',
    'food.food_salmon': 'سلمون (مزرعة، مشوي)',
    'food.food_fava_beans': 'فول (طازج)',
    'food.food_potato_boiled': 'بطاطا (مسلوقة)',
    'food.food_walnuts': 'جوز',
    'food.food_olive_oil': 'زيت زيتون بكر ممتاز',
    'food.food_cheddar_cheese': 'جبنة شيدر',
    'food.food_egg_boiled': 'بيض (مسلوق)',
    'food.food_coffee': 'قهوة (محضرة، بدون سكر)',
    'observatory.dependency_closure.title': 'جاهزية إغلاق التبعيات',
    'observatory.dependency_closure.loading':
        'جارٍ تحميل بيان الجذور المُثبت في المستودع · الإغلاق HOLD',
    'observatory.dependency_closure.unavailable':
        'HOLD · بيان الجذور المُثبت في المستودع غير متاح',
    'observatory.dependency_closure.loading_semantics':
        'جارٍ تحميل البيان المستقر لجذور نتائج الخوارزميات. يظل إغلاق التبعيات في حالة HOLD.',
    'observatory.dependency_closure.unavailable_semantics':
        'البيان المستقر لجذور نتائج الخوارزميات غير متاح. إغلاق التبعيات في حالة HOLD.',
    'observatory.dependency_closure.semantics':
        '{count} من جذور الخوارزميات المستقرة والمسجلة. يمثّل Analyzer {analyzer} الإصدار الدقيق المعلن هدفًا للمراجعة. لا تُضمّن أدلة التوافق دون اتصال ولا تُنفذ في هذا العرض. يظل الإغلاق الانتقالي للتبعيات في حالة HOLD بانتظار مولّد حواف ParkinSUM.',
    'observatory.dependency_closure.summary':
        '{count} / {total} جذور مستقرة · هدف Analyzer المعلن {analyzer} · الإغلاق الانتقالي HOLD',
    'observatory.dependency_closure.identity': '{schema} · {digest}… · {state}',
    'observatory.dependency_closure.registry_chip':
        'ربط Registry: صالح بنيويًا',
    'observatory.dependency_closure.edge_chip': 'مولّد الحواف: HOLD',
    'observatory.dependency_closure.closure_chip':
        'الإغلاق الأمامي/العكسي: HOLD',
    'observatory.dependency_closure.details': 'جدول جذور مستقرة قابل للوصول',
    'observatory.dependency_closure.details_subtitle':
        'بذور المكتبات الأساسية فقط؛ لا توجد حواف تبعية مولّدة.',
    'observatory.dependency_closure.table_semantics':
        'جدول جذور الخوارزميات المستقرة. الأعمدة هي الخوارزمية والجذر المنطقي ومصبّ النتيجة ومعرّف URI القياسي للحزمة.',
    'observatory.dependency_closure.column_algorithm': 'الخوارزمية',
    'observatory.dependency_closure.column_root': 'الجذر المنطقي',
    'observatory.dependency_closure.column_sink': 'مصبّ النتيجة',
    'observatory.dependency_closure.column_uri': 'URI الحزمة',
    'observatory.dependency_closure.boundary':
        'لا يثبت هذا العرض سوى عقد بنيوي مُثبت في المستودع يربط Registry بالجذور. ولا تُضمّن هنا أدلة توافق Analyzer دون اتصال ولا تُنفذ. كما لا يعرض أو يدّعي وجود رسم استدعاءات، أو SCC، أو إغلاق أمامي/عكسي، أو تنفيذ، أو تدفق بيانات دقيق، أو تحقق علمي أو سريري، أو سلامة، أو فائدة، أو مشورة طبية.',
  },
};

/// Food-catalog evidence copy shared into every shipped language family.
/// These strings describe recorded source metadata, not verified source truth.
const Map<String, Map<String, String>> kFoodCatalogProvenanceUiTranslations = {
  'zh': {
    'detail.food_catalog_provenance_title': '食品目录来源信息',
    'detail.food_missing_nutrient_fields': '没有来源值的营养项（未知，不是零值）：{fields}',
    'detail.food_nutrient_less_than_boundary':
        '来源使用“小于”限定值：{attribute} = {raw}（限定符 {qualifier}）；未推断为精确数值。',
    'detail.food_catalog_provenance_unavailable': '此食品目前没有关联的来源文档、范围或营养观测证据。',
    'detail.food_catalog_source_documents': '来源文档',
    'detail.food_catalog_document_summary':
        '文档 {id} · {title} · 机构 {organization} · 来源 {family} · 类型 {type} · 层级 {tier} · 辖区 {jurisdiction} · 状态 {status}',
    'detail.food_catalog_license': '许可说明（按来源记录）：{value}',
    'detail.food_catalog_source_dates': '发布 {published} · 生效 {effective}',
    'detail.food_catalog_source_url': '来源链接：{value}',
    'detail.food_catalog_payload_digest':
        '导入后保存的原始载荷文本 SHA-256（仅标识该文本，不代表完整目录版本）：{digest}',
    'detail.food_catalog_scopes': '食品范围',
    'detail.food_catalog_scope_summary':
        '范围 {hash} · 辖区 {jurisdiction} · 品牌 {brand} · 制备 {preparation} · 烹调 {cooking} · 部位 {plant} · 品种 {cultivar} · 抽样框架 {sampling}',
    'detail.food_catalog_mappings': '食品映射',
    'detail.food_catalog_mapping_summary':
        '外部标识 {system}:{externalId} → 食品 ID {appId} · 记录置信值 {confidence}（未验证映射准确率）· 状态 {status} · {selection}',
    'detail.food_catalog_mapping_selected': '用于当前投影食品 ID',
    'detail.food_catalog_mapping_not_selected': '未用于当前投影食品 ID',
    'detail.food_catalog_mapping_payload': '映射元数据：{value}',
    'detail.food_nutrient_projection_selected': '当前旧版点值投影所选',
    'detail.food_nutrient_projection_evidence_only': '仅作证据，未选入旧版点值投影',
    'detail.food_nutrient_observation_evidence': '营养观测证据',
    'detail.food_nutrient_observation_line':
        '{attribute}：原始值 {raw} · qualifier {qualifier} · 单位 {unit} · 基准 {basis} · 范围 {low}–{high} · 方法 {method} · 来源文档 {source}',
    'detail.food_catalog_unresolved': '本地未找到关联记录：{id}',
    'detail.food_catalog_provenance_boundary':
        '这里只显示本地已关联的来源信息，不代表完整上游目录快照；尚未固定上游目录版本或查询，也未评估排序稳定性。',
  },
  'en': {
    'detail.food_catalog_provenance_title': 'Food catalog provenance',
    'detail.food_missing_nutrient_fields':
        'Nutrients with no source value (unknown, not zero): {fields}',
    'detail.food_nutrient_less_than_boundary':
        'Source uses a less-than qualifier: {attribute} = {raw} ({qualifier}); no exact value is inferred.',
    'detail.food_catalog_provenance_unavailable':
        'No linked source-document, food-scope, or nutrient-observation evidence is available for this item.',
    'detail.food_catalog_source_documents': 'Source documents',
    'detail.food_catalog_document_summary':
        'Document {id} · {title} · {organization} · {family} · type {type} · tier {tier} · {jurisdiction} · status {status}',
    'detail.food_catalog_license': 'License note as recorded: {value}',
    'detail.food_catalog_source_dates':
        'Published {published} · effective {effective}',
    'detail.food_catalog_source_url': 'Source URL: {value}',
    'detail.food_catalog_payload_digest':
        'SHA-256 of persisted raw-payload text after ingestion only (not a full catalog release): {digest}',
    'detail.food_catalog_scopes': 'Food scope',
    'detail.food_catalog_scope_summary':
        'Scope {hash} · {jurisdiction} · brand {brand} · preparation {preparation} · cooking {cooking} · plant part {plant} · cultivar {cultivar} · sampling frame {sampling}',
    'detail.food_catalog_mappings': 'Food mappings',
    'detail.food_catalog_mapping_summary':
        'External {system}:{externalId} → food ID {appId} · recorded confidence {confidence} (not validated match accuracy) · status {status} · {selection}',
    'detail.food_catalog_mapping_selected':
        'selected for the current projected food ID',
    'detail.food_catalog_mapping_not_selected':
        'not selected for the current projected food ID',
    'detail.food_catalog_mapping_payload': 'Mapping metadata: {value}',
    'detail.food_nutrient_projection_selected':
        'Selected for the current legacy point-value projection',
    'detail.food_nutrient_projection_evidence_only':
        'Evidence only; not selected for the legacy point-value projection',
    'detail.food_nutrient_observation_evidence':
        'Nutrient observation evidence',
    'detail.food_nutrient_observation_line':
        '{attribute}: raw value {raw} · qualifier {qualifier} · unit {unit} · basis {basis} · range {low}–{high} · method {method} · source document {source}',
    'detail.food_catalog_unresolved': 'Linked record not found locally: {id}',
    'detail.food_catalog_provenance_boundary':
        'This is locally linked evidence, not a complete upstream catalog snapshot. The upstream release and query are not pinned, and rank stability has not been assessed.',
  },
  'fr': {
    'detail.food_catalog_provenance_title':
        'Provenance du catalogue alimentaire',
    'detail.food_missing_nutrient_fields':
        'Nutriments sans valeur source (inconnus, pas égaux à zéro) : {fields}',
    'detail.food_nutrient_less_than_boundary':
        'La source utilise un qualificatif « inférieur à » : {attribute} = {raw} ({qualifier}) ; aucune valeur exacte n’est déduite.',
    'detail.food_catalog_provenance_unavailable':
        'Aucune preuve liée à un document source, au périmètre alimentaire ou aux observations nutritionnelles n’est disponible pour cet aliment.',
    'detail.food_catalog_source_documents': 'Documents sources',
    'detail.food_catalog_document_summary':
        'Document {id} · {title} · {organization} · {family} · type {type} · niveau {tier} · {jurisdiction} · statut {status}',
    'detail.food_catalog_license': 'Note de licence enregistrée : {value}',
    'detail.food_catalog_source_dates':
        'Publié le {published} · en vigueur le {effective}',
    'detail.food_catalog_source_url': 'URL source : {value}',
    'detail.food_catalog_payload_digest':
        'SHA-256 du texte de charge utile conservé après import uniquement (pas une version complète du catalogue) : {digest}',
    'detail.food_catalog_scopes': 'Périmètre de l’aliment',
    'detail.food_catalog_scope_summary':
        'Périmètre {hash} · {jurisdiction} · marque {brand} · préparation {preparation} · cuisson {cooking} · partie {plant} · cultivar {cultivar} · échantillonnage {sampling}',
    'detail.food_catalog_mappings': 'Correspondances alimentaires',
    'detail.food_catalog_mapping_summary':
        'Identifiant externe {system}:{externalId} → ID aliment {appId} · confiance enregistrée {confidence} (précision non validée) · statut {status} · {selection}',
    'detail.food_catalog_mapping_selected': 'retenue pour l’ID aliment projeté',
    'detail.food_catalog_mapping_not_selected':
        'non retenue pour l’ID aliment projeté',
    'detail.food_catalog_mapping_payload':
        'Métadonnées de correspondance : {value}',
    'detail.food_nutrient_projection_selected':
        'Retenue pour la projection actuelle de la valeur ponctuelle héritée',
    'detail.food_nutrient_projection_evidence_only':
        'Élément de preuve uniquement ; non retenu pour la projection de la valeur ponctuelle héritée',
    'detail.food_nutrient_observation_evidence':
        'Preuves des observations nutritionnelles',
    'detail.food_nutrient_observation_line':
        '{attribute} : valeur brute {raw} · qualificatif {qualifier} · unité {unit} · base {basis} · intervalle {low}–{high} · méthode {method} · document source {source}',
    'detail.food_catalog_unresolved':
        'Enregistrement lié introuvable localement : {id}',
    'detail.food_catalog_provenance_boundary':
        'Ces éléments sont liés localement et ne constituent pas un instantané complet du catalogue amont. La version et la requête amont ne sont pas figées, et la stabilité du classement n’a pas été évaluée.',
  },
  'ja': {
    'detail.food_catalog_provenance_title': '食品カタログの出典情報',
    'detail.food_missing_nutrient_fields':
        '出典値のない栄養項目（不明であり、ゼロではありません）：{fields}',
    'detail.food_nutrient_less_than_boundary':
        '出典は「未満」の限定値を使用しています：{attribute} = {raw}（限定子 {qualifier}）。正確な値とは推定していません。',
    'detail.food_catalog_provenance_unavailable':
        'この食品には、出典文書、食品範囲、栄養観測の関連情報がありません。',
    'detail.food_catalog_source_documents': '出典文書',
    'detail.food_catalog_document_summary':
        '文書 {id} · {title} · {organization} · {family} · 種類 {type} · 層 {tier} · {jurisdiction} · 状態 {status}',
    'detail.food_catalog_license': '登録されたライセンス注記：{value}',
    'detail.food_catalog_source_dates': '公開 {published} · 有効 {effective}',
    'detail.food_catalog_source_url': '出典 URL：{value}',
    'detail.food_catalog_payload_digest':
        '取込後に保存されたペイロード本文のみの SHA-256（完全なカタログ版を示しません）：{digest}',
    'detail.food_catalog_scopes': '食品の範囲',
    'detail.food_catalog_scope_summary':
        '範囲 {hash} · {jurisdiction} · ブランド {brand} · 調理前の状態 {preparation} · 調理状態 {cooking} · 部位 {plant} · 品種 {cultivar} · サンプリング枠 {sampling}',
    'detail.food_catalog_mappings': '食品 ID の対応付け',
    'detail.food_catalog_mapping_summary':
        '外部 ID {system}:{externalId} → 食品 ID {appId} · 記録された信頼度 {confidence}（対応精度は未検証）· 状態 {status} · {selection}',
    'detail.food_catalog_mapping_selected': '現在の投影食品 ID に採用',
    'detail.food_catalog_mapping_not_selected': '現在の投影食品 ID には不採用',
    'detail.food_catalog_mapping_payload': '対応付けメタデータ：{value}',
    'detail.food_nutrient_projection_selected': '現在の旧版ポイント値投影に選択済み',
    'detail.food_nutrient_projection_evidence_only': '根拠のみ：旧版ポイント値投影には未選択',
    'detail.food_nutrient_observation_evidence': '栄養観測の根拠',
    'detail.food_nutrient_observation_line':
        '{attribute}：原文値 {raw} · 修飾子 {qualifier} · 単位 {unit} · 基準 {basis} · 範囲 {low}–{high} · 方法 {method} · 出典文書 {source}',
    'detail.food_catalog_unresolved': '関連レコードがローカルにありません：{id}',
    'detail.food_catalog_provenance_boundary':
        'これはローカルで関連付けられた根拠であり、上流カタログ全体のスナップショットではありません。上流の版と検索条件は固定されておらず、順位の安定性も評価されていません。',
  },
  'ko': {
    'detail.food_catalog_provenance_title': '식품 카탈로그 출처 정보',
    'detail.food_missing_nutrient_fields':
        '출처 값이 없는 영양소(알 수 없음, 0이 아님): {fields}',
    'detail.food_nutrient_less_than_boundary':
        '출처가 미만 한정값을 사용합니다: {attribute} = {raw} ({qualifier}); 정확한 값으로 추정하지 않습니다.',
    'detail.food_catalog_provenance_unavailable':
        '이 항목에는 연결된 출처 문서, 식품 범위 또는 영양 관찰 근거가 없습니다.',
    'detail.food_catalog_source_documents': '출처 문서',
    'detail.food_catalog_document_summary':
        '문서 {id} · {title} · {organization} · {family} · 유형 {type} · 등급 {tier} · {jurisdiction} · 상태 {status}',
    'detail.food_catalog_license': '등록된 라이선스 메모: {value}',
    'detail.food_catalog_source_dates': '게시 {published} · 적용 {effective}',
    'detail.food_catalog_source_url': '출처 URL: {value}',
    'detail.food_catalog_payload_digest':
        '수집 후 저장된 원본 페이로드 텍스트만의 SHA-256(전체 카탈로그 버전 아님): {digest}',
    'detail.food_catalog_scopes': '식품 범위',
    'detail.food_catalog_scope_summary':
        '범위 {hash} · {jurisdiction} · 브랜드 {brand} · 준비 상태 {preparation} · 조리 상태 {cooking} · 식물 부위 {plant} · 품종 {cultivar} · 표본 프레임 {sampling}',
    'detail.food_catalog_mappings': '식품 매핑',
    'detail.food_catalog_mapping_summary':
        '외부 ID {system}:{externalId} → 식품 ID {appId} · 기록된 신뢰도 {confidence}(매핑 정확도 검증 아님) · 상태 {status} · {selection}',
    'detail.food_catalog_mapping_selected': '현재 투영 식품 ID에 선택됨',
    'detail.food_catalog_mapping_not_selected': '현재 투영 식품 ID에 선택되지 않음',
    'detail.food_catalog_mapping_payload': '매핑 메타데이터: {value}',
    'detail.food_nutrient_projection_selected': '현재 레거시 점값 투영에 선택됨',
    'detail.food_nutrient_projection_evidence_only':
        '근거 전용: 레거시 점값 투영에는 선택되지 않음',
    'detail.food_nutrient_observation_evidence': '영양 관찰 근거',
    'detail.food_nutrient_observation_line':
        '{attribute}: 원문 값 {raw} · 한정자 {qualifier} · 단위 {unit} · 기준 {basis} · 범위 {low}–{high} · 방법 {method} · 출처 문서 {source}',
    'detail.food_catalog_unresolved': '연결된 레코드를 로컬에서 찾을 수 없음: {id}',
    'detail.food_catalog_provenance_boundary':
        '이 정보는 로컬에서 연결된 근거이며 전체 상위 카탈로그 스냅샷이 아닙니다. 상위 릴리스와 조회는 고정되지 않았고 순위 안정성도 평가되지 않았습니다.',
  },
  'hi': {
    'detail.food_catalog_provenance_title': 'खाद्य सूची का स्रोत विवरण',
    'detail.food_missing_nutrient_fields':
        'स्रोत मान के बिना पोषक तत्व (अज्ञात, शून्य नहीं): {fields}',
    'detail.food_nutrient_less_than_boundary':
        'स्रोत में “से कम” सीमा है: {attribute} = {raw} ({qualifier}); इसे सटीक मान नहीं माना गया है।',
    'detail.food_catalog_provenance_unavailable':
        'इस खाद्य पदार्थ के लिए कोई जुड़ा स्रोत दस्तावेज़, खाद्य दायरा या पोषक-अवलोकन प्रमाण उपलब्ध नहीं है।',
    'detail.food_catalog_source_documents': 'स्रोत दस्तावेज़',
    'detail.food_catalog_document_summary':
        'दस्तावेज़ {id} · {title} · {organization} · {family} · प्रकार {type} · स्तर {tier} · {jurisdiction} · स्थिति {status}',
    'detail.food_catalog_license': 'दर्ज लाइसेंस टिप्पणी: {value}',
    'detail.food_catalog_source_dates':
        'प्रकाशित {published} · प्रभावी {effective}',
    'detail.food_catalog_source_url': 'स्रोत URL: {value}',
    'detail.food_catalog_payload_digest':
        'आयात के बाद सहेजे गए पेलोड पाठ का SHA-256 मात्र (पूरी सूची का संस्करण नहीं): {digest}',
    'detail.food_catalog_scopes': 'खाद्य दायरा',
    'detail.food_catalog_scope_summary':
        'दायरा {hash} · {jurisdiction} · ब्रांड {brand} · तैयारी {preparation} · पकाने की अवस्था {cooking} · पौधे का भाग {plant} · किस्म {cultivar} · नमूना ढाँचा {sampling}',
    'detail.food_catalog_mappings': 'खाद्य मिलान',
    'detail.food_catalog_mapping_summary':
        'बाहरी ID {system}:{externalId} → खाद्य ID {appId} · दर्ज विश्वास {confidence} (मिलान की शुद्धता सत्यापित नहीं) · स्थिति {status} · {selection}',
    'detail.food_catalog_mapping_selected':
        'वर्तमान projected खाद्य ID के लिए चुना गया',
    'detail.food_catalog_mapping_not_selected':
        'वर्तमान projected खाद्य ID के लिए नहीं चुना गया',
    'detail.food_catalog_mapping_payload': 'मिलान मेटाडेटा: {value}',
    'detail.food_nutrient_projection_selected':
        'वर्तमान लीगेसी बिंदु-मूल्य प्रक्षेपण के लिए चयनित',
    'detail.food_nutrient_projection_evidence_only':
        'केवल साक्ष्य; लीगेसी बिंदु-मूल्य प्रक्षेपण के लिए चयनित नहीं',
    'detail.food_nutrient_observation_evidence': 'पोषक अवलोकन प्रमाण',
    'detail.food_nutrient_observation_line':
        '{attribute}: मूल मान {raw} · qualifier {qualifier} · इकाई {unit} · आधार {basis} · सीमा {low}–{high} · विधि {method} · स्रोत दस्तावेज़ {source}',
    'detail.food_catalog_unresolved':
        'जुड़ा रिकॉर्ड स्थानीय रूप से नहीं मिला: {id}',
    'detail.food_catalog_provenance_boundary':
        'यह स्थानीय रूप से जुड़ा प्रमाण है, पूरी upstream सूची का snapshot नहीं। Upstream release और query स्थिर नहीं हैं और rank stability का आकलन नहीं हुआ है।',
  },
  'es': {
    'detail.food_catalog_provenance_title':
        'Procedencia del catálogo de alimentos',
    'detail.food_missing_nutrient_fields':
        'Nutrientes sin valor de origen (desconocido, no es cero): {fields}',
    'detail.food_nutrient_less_than_boundary':
        'La fuente usa el calificador «menor que»: {attribute} = {raw} ({qualifier}); no se infiere un valor exacto.',
    'detail.food_catalog_provenance_unavailable':
        'Este alimento no tiene documentos fuente, alcance alimentario ni evidencia de observaciones nutricionales vinculados.',
    'detail.food_catalog_source_documents': 'Documentos fuente',
    'detail.food_catalog_document_summary':
        'Documento {id} · {title} · {organization} · {family} · tipo {type} · nivel {tier} · {jurisdiction} · estado {status}',
    'detail.food_catalog_license': 'Nota de licencia registrada: {value}',
    'detail.food_catalog_source_dates':
        'Publicado {published} · vigente {effective}',
    'detail.food_catalog_source_url': 'URL de origen: {value}',
    'detail.food_catalog_payload_digest':
        'SHA-256 solo del texto de carga guardado tras la importación (no es una versión completa del catálogo): {digest}',
    'detail.food_catalog_scopes': 'Alcance del alimento',
    'detail.food_catalog_scope_summary':
        'Alcance {hash} · {jurisdiction} · marca {brand} · preparación {preparation} · cocción {cooking} · parte {plant} · cultivar {cultivar} · marco de muestreo {sampling}',
    'detail.food_catalog_mappings': 'Correspondencias de alimentos',
    'detail.food_catalog_mapping_summary':
        'ID externo {system}:{externalId} → ID del alimento {appId} · confianza registrada {confidence} (precisión no validada) · estado {status} · {selection}',
    'detail.food_catalog_mapping_selected':
        'seleccionada para el ID proyectado actual',
    'detail.food_catalog_mapping_not_selected':
        'no seleccionada para el ID proyectado actual',
    'detail.food_catalog_mapping_payload':
        'Metadatos de correspondencia: {value}',
    'detail.food_nutrient_projection_selected':
        'Seleccionada para la proyección actual del valor puntual heredado',
    'detail.food_nutrient_projection_evidence_only':
        'Solo evidencia; no seleccionada para la proyección del valor puntual heredado',
    'detail.food_nutrient_observation_evidence':
        'Evidencia de observaciones nutricionales',
    'detail.food_nutrient_observation_line':
        '{attribute}: valor original {raw} · calificador {qualifier} · unidad {unit} · base {basis} · intervalo {low}–{high} · método {method} · documento fuente {source}',
    'detail.food_catalog_unresolved':
        'Registro vinculado no encontrado localmente: {id}',
    'detail.food_catalog_provenance_boundary':
        'Esta es evidencia vinculada localmente, no una instantánea completa del catálogo de origen. La versión y la consulta de origen no están fijadas, y no se ha evaluado la estabilidad del orden.',
  },
  'vi': {
    'detail.food_catalog_provenance_title': 'Nguồn gốc danh mục thực phẩm',
    'detail.food_missing_nutrient_fields':
        'Chất dinh dưỡng không có giá trị nguồn (chưa biết, không phải bằng không): {fields}',
    'detail.food_nutrient_less_than_boundary':
        'Nguồn dùng dấu giới hạn “nhỏ hơn”: {attribute} = {raw} ({qualifier}); không suy ra giá trị chính xác.',
    'detail.food_catalog_provenance_unavailable':
        'Mục này không có tài liệu nguồn, phạm vi thực phẩm hoặc bằng chứng quan sát dinh dưỡng được liên kết.',
    'detail.food_catalog_source_documents': 'Tài liệu nguồn',
    'detail.food_catalog_document_summary':
        'Tài liệu {id} · {title} · {organization} · {family} · loại {type} · cấp {tier} · {jurisdiction} · trạng thái {status}',
    'detail.food_catalog_license': 'Ghi chú giấy phép đã ghi nhận: {value}',
    'detail.food_catalog_source_dates':
        'Công bố {published} · có hiệu lực {effective}',
    'detail.food_catalog_source_url': 'URL nguồn: {value}',
    'detail.food_catalog_payload_digest':
        'SHA-256 chỉ của văn bản payload được lưu sau khi nhập (không phải phiên bản đầy đủ của danh mục): {digest}',
    'detail.food_catalog_scopes': 'Phạm vi thực phẩm',
    'detail.food_catalog_scope_summary':
        'Phạm vi {hash} · {jurisdiction} · nhãn hiệu {brand} · trạng thái chuẩn bị {preparation} · trạng thái nấu {cooking} · bộ phận {plant} · giống {cultivar} · khung lấy mẫu {sampling}',
    'detail.food_catalog_mappings': 'Ánh xạ thực phẩm',
    'detail.food_catalog_mapping_summary':
        'ID ngoài {system}:{externalId} → ID thực phẩm {appId} · độ tin cậy được ghi nhận {confidence} (độ chính xác chưa được xác thực) · trạng thái {status} · {selection}',
    'detail.food_catalog_mapping_selected':
        'được chọn cho ID thực phẩm đang chiếu',
    'detail.food_catalog_mapping_not_selected':
        'không được chọn cho ID thực phẩm đang chiếu',
    'detail.food_catalog_mapping_payload': 'Siêu dữ liệu ánh xạ: {value}',
    'detail.food_nutrient_projection_selected':
        'Được chọn cho phép chiếu giá trị điểm kế thừa hiện tại',
    'detail.food_nutrient_projection_evidence_only':
        'Chỉ là bằng chứng; không được chọn cho phép chiếu giá trị điểm kế thừa',
    'detail.food_nutrient_observation_evidence':
        'Bằng chứng quan sát dinh dưỡng',
    'detail.food_nutrient_observation_line':
        '{attribute}: giá trị gốc {raw} · qualifier {qualifier} · đơn vị {unit} · cơ sở {basis} · khoảng {low}–{high} · phương pháp {method} · tài liệu nguồn {source}',
    'detail.food_catalog_unresolved':
        'Không tìm thấy bản ghi liên kết trong dữ liệu cục bộ: {id}',
    'detail.food_catalog_provenance_boundary':
        'Đây là bằng chứng được liên kết cục bộ, không phải ảnh chụp đầy đủ của danh mục nguồn. Phiên bản và truy vấn nguồn chưa được cố định; độ ổn định thứ hạng chưa được đánh giá.',
  },
  'th': {
    'detail.food_catalog_provenance_title': 'ที่มาของรายการอาหาร',
    'detail.food_missing_nutrient_fields':
        'สารอาหารที่ไม่มีค่าจากแหล่งข้อมูล (ไม่ทราบค่า ไม่ใช่ศูนย์): {fields}',
    'detail.food_nutrient_less_than_boundary':
        'แหล่งข้อมูลระบุค่าด้วยเงื่อนไข “น้อยกว่า”: {attribute} = {raw} ({qualifier}); ไม่ได้อนุมานเป็นค่าที่แน่นอน',
    'detail.food_catalog_provenance_unavailable':
        'รายการนี้ไม่มีเอกสารต้นทาง ขอบเขตอาหาร หรือหลักฐานการสังเกตสารอาหารที่เชื่อมโยงไว้',
    'detail.food_catalog_source_documents': 'เอกสารต้นทาง',
    'detail.food_catalog_document_summary':
        'เอกสาร {id} · {title} · {organization} · {family} · ประเภท {type} · ระดับ {tier} · {jurisdiction} · สถานะ {status}',
    'detail.food_catalog_license': 'หมายเหตุใบอนุญาตตามที่บันทึก: {value}',
    'detail.food_catalog_source_dates':
        'เผยแพร่ {published} · มีผล {effective}',
    'detail.food_catalog_source_url': 'URL ต้นทาง: {value}',
    'detail.food_catalog_payload_digest':
        'SHA-256 ของข้อความ payload ที่บันทึกหลังนำเข้าเท่านั้น (ไม่ใช่รุ่นแค็ตตาล็อกทั้งหมด): {digest}',
    'detail.food_catalog_scopes': 'ขอบเขตอาหาร',
    'detail.food_catalog_scope_summary':
        'ขอบเขต {hash} · {jurisdiction} · แบรนด์ {brand} · การเตรียม {preparation} · การปรุง {cooking} · ส่วนพืช {plant} · สายพันธุ์ {cultivar} · กรอบตัวอย่าง {sampling}',
    'detail.food_catalog_mappings': 'การจับคู่รายการอาหาร',
    'detail.food_catalog_mapping_summary':
        'ID ภายนอก {system}:{externalId} → ID อาหาร {appId} · ความเชื่อมั่นที่บันทึก {confidence} (ยังไม่ยืนยันความแม่นยำ) · สถานะ {status} · {selection}',
    'detail.food_catalog_mapping_selected':
        'เลือกใช้กับ ID อาหารที่แสดงในปัจจุบัน',
    'detail.food_catalog_mapping_not_selected':
        'ไม่ได้เลือกใช้กับ ID อาหารที่แสดงในปัจจุบัน',
    'detail.food_catalog_mapping_payload': 'ข้อมูลเมตาการจับคู่: {value}',
    'detail.food_nutrient_projection_selected':
        'เลือกสำหรับการฉายค่าจุดแบบเดิมในปัจจุบัน',
    'detail.food_nutrient_projection_evidence_only':
        'เป็นหลักฐานเท่านั้น ไม่ได้เลือกสำหรับการฉายค่าจุดแบบเดิม',
    'detail.food_nutrient_observation_evidence': 'หลักฐานการสังเกตสารอาหาร',
    'detail.food_nutrient_observation_line':
        '{attribute}: ค่าดิบ {raw} · qualifier {qualifier} · หน่วย {unit} · ฐาน {basis} · ช่วง {low}–{high} · วิธี {method} · เอกสารต้นทาง {source}',
    'detail.food_catalog_unresolved':
        'ไม่พบระเบียนที่เชื่อมโยงในข้อมูลภายในเครื่อง: {id}',
    'detail.food_catalog_provenance_boundary':
        'ข้อมูลนี้เป็นหลักฐานที่เชื่อมโยงในเครื่อง ไม่ใช่ภาพรวมแค็ตตาล็อกต้นทางทั้งหมด ยังไม่ได้ตรึงรุ่นหรือคำค้นต้นทาง และยังไม่ได้ประเมินความเสถียรของอันดับ',
  },
  'id': {
    'detail.food_catalog_provenance_title': 'Asal-usul katalog makanan',
    'detail.food_missing_nutrient_fields':
        'Nutrien tanpa nilai sumber (tidak diketahui, bukan nol): {fields}',
    'detail.food_nutrient_less_than_boundary':
        'Sumber menggunakan penanda “kurang dari”: {attribute} = {raw} ({qualifier}); nilai tepat tidak disimpulkan.',
    'detail.food_catalog_provenance_unavailable':
        'Tidak ada dokumen sumber, cakupan makanan, atau bukti observasi nutrisi yang ditautkan ke item ini.',
    'detail.food_catalog_source_documents': 'Dokumen sumber',
    'detail.food_catalog_document_summary':
        'Dokumen {id} · {title} · {organization} · {family} · jenis {type} · tingkat {tier} · {jurisdiction} · status {status}',
    'detail.food_catalog_license': 'Catatan lisensi yang tercatat: {value}',
    'detail.food_catalog_source_dates':
        'Diterbitkan {published} · berlaku {effective}',
    'detail.food_catalog_source_url': 'URL sumber: {value}',
    'detail.food_catalog_payload_digest':
        'SHA-256 hanya untuk teks payload yang tersimpan setelah impor (bukan versi katalog lengkap): {digest}',
    'detail.food_catalog_scopes': 'Cakupan makanan',
    'detail.food_catalog_scope_summary':
        'Cakupan {hash} · {jurisdiction} · merek {brand} · persiapan {preparation} · pemasakan {cooking} · bagian tanaman {plant} · kultivar {cultivar} · kerangka sampel {sampling}',
    'detail.food_catalog_mappings': 'Pemetaan makanan',
    'detail.food_catalog_mapping_summary':
        'ID eksternal {system}:{externalId} → ID makanan {appId} · keyakinan tercatat {confidence} (akurasi belum divalidasi) · status {status} · {selection}',
    'detail.food_catalog_mapping_selected':
        'dipilih untuk ID makanan hasil proyeksi saat ini',
    'detail.food_catalog_mapping_not_selected':
        'tidak dipilih untuk ID makanan hasil proyeksi saat ini',
    'detail.food_catalog_mapping_payload': 'Metadata pemetaan: {value}',
    'detail.food_nutrient_projection_selected':
        'Dipilih untuk proyeksi nilai titik warisan saat ini',
    'detail.food_nutrient_projection_evidence_only':
        'Hanya bukti; tidak dipilih untuk proyeksi nilai titik warisan',
    'detail.food_nutrient_observation_evidence': 'Bukti observasi nutrisi',
    'detail.food_nutrient_observation_line':
        '{attribute}: nilai mentah {raw} · qualifier {qualifier} · satuan {unit} · dasar {basis} · rentang {low}–{high} · metode {method} · dokumen sumber {source}',
    'detail.food_catalog_unresolved':
        'Catatan tertaut tidak ditemukan secara lokal: {id}',
    'detail.food_catalog_provenance_boundary':
        'Ini adalah bukti yang ditautkan secara lokal, bukan snapshot katalog sumber yang lengkap. Rilis dan kueri sumber belum dipatok, dan kestabilan peringkat belum dinilai.',
  },
  'ru': {
    'detail.food_catalog_provenance_title': 'Происхождение пищевого каталога',
    'detail.food_missing_nutrient_fields':
        'Питательные вещества без исходного значения (неизвестно, не ноль): {fields}',
    'detail.food_nutrient_less_than_boundary':
        'Источник использует ограничение «меньше»: {attribute} = {raw} ({qualifier}); точное значение не выводится.',
    'detail.food_catalog_provenance_unavailable':
        'Для этого продукта нет связанных исходных документов, данных об области пищевого образца или наблюдениях о питательных веществах.',
    'detail.food_catalog_source_documents': 'Исходные документы',
    'detail.food_catalog_document_summary':
        'Документ {id} · {title} · {organization} · {family} · тип {type} · уровень {tier} · {jurisdiction} · статус {status}',
    'detail.food_catalog_license': 'Записанная заметка о лицензии: {value}',
    'detail.food_catalog_source_dates':
        'Опубликовано {published} · действует с {effective}',
    'detail.food_catalog_source_url': 'URL источника: {value}',
    'detail.food_catalog_payload_digest':
        'SHA-256 только сохранённого после импорта текста полезной нагрузки (не полный выпуск каталога): {digest}',
    'detail.food_catalog_scopes': 'Область пищевого образца',
    'detail.food_catalog_scope_summary':
        'Область {hash} · {jurisdiction} · бренд {brand} · подготовка {preparation} · приготовление {cooking} · часть растения {plant} · сорт {cultivar} · схема выборки {sampling}',
    'detail.food_catalog_mappings': 'Сопоставления продуктов',
    'detail.food_catalog_mapping_summary':
        'Внешний ID {system}:{externalId} → ID продукта {appId} · записанная уверенность {confidence} (точность сопоставления не проверена) · статус {status} · {selection}',
    'detail.food_catalog_mapping_selected': 'выбрано для текущего ID продукта',
    'detail.food_catalog_mapping_not_selected':
        'не выбрано для текущего ID продукта',
    'detail.food_catalog_mapping_payload': 'Метаданные сопоставления: {value}',
    'detail.food_nutrient_projection_selected':
        'Выбрано для текущей проекции точечного значения в прежнем формате',
    'detail.food_nutrient_projection_evidence_only':
        'Только свидетельство; не выбрано для проекции точечного значения в прежнем формате',
    'detail.food_nutrient_observation_evidence':
        'Данные наблюдений о питательных веществах',
    'detail.food_nutrient_observation_line':
        '{attribute}: исходное значение {raw} · уточнение {qualifier} · единица {unit} · основа {basis} · диапазон {low}–{high} · метод {method} · исходный документ {source}',
    'detail.food_catalog_unresolved':
        'Связанная запись не найдена локально: {id}',
    'detail.food_catalog_provenance_boundary':
        'Это локально связанные данные, а не полный снимок исходного каталога. Выпуск и запрос источника не закреплены; стабильность ранжирования не оценивалась.',
  },
  'pl': {
    'detail.food_catalog_provenance_title': 'Pochodzenie katalogu żywności',
    'detail.food_missing_nutrient_fields':
        'Składniki bez wartości źródłowej (nieznane, a nie zerowe): {fields}',
    'detail.food_nutrient_less_than_boundary':
        'Źródło używa kwalifikatora „mniej niż”: {attribute} = {raw} ({qualifier}); nie wywnioskowano dokładnej wartości.',
    'detail.food_catalog_provenance_unavailable':
        'Dla tego produktu nie ma powiązanego dokumentu źródłowego, zakresu ani dowodu obserwacji składników odżywczych.',
    'detail.food_catalog_source_documents': 'Dokumenty źródłowe',
    'detail.food_catalog_document_summary':
        'Dokument {id} · {title} · {organization} · {family} · typ {type} · poziom {tier} · {jurisdiction} · status {status}',
    'detail.food_catalog_license': 'Zapisana informacja o licencji: {value}',
    'detail.food_catalog_source_dates':
        'Opublikowano {published} · obowiązuje od {effective}',
    'detail.food_catalog_source_url': 'URL źródła: {value}',
    'detail.food_catalog_payload_digest':
        'SHA-256 wyłącznie zapisanego po imporcie tekstu payloadu (nie pełna wersja katalogu): {digest}',
    'detail.food_catalog_scopes': 'Zakres produktu spożywczego',
    'detail.food_catalog_scope_summary':
        'Zakres {hash} · {jurisdiction} · marka {brand} · przygotowanie {preparation} · gotowanie {cooking} · część rośliny {plant} · odmiana {cultivar} · schemat próbkowania {sampling}',
    'detail.food_catalog_mappings': 'Mapowania żywności',
    'detail.food_catalog_mapping_summary':
        'Zewnętrzny ID {system}:{externalId} → ID produktu {appId} · zapisana pewność {confidence} (dokładność mapowania niezweryfikowana) · status {status} · {selection}',
    'detail.food_catalog_mapping_selected': 'wybrane dla bieżącego ID produktu',
    'detail.food_catalog_mapping_not_selected':
        'niewybrane dla bieżącego ID produktu',
    'detail.food_catalog_mapping_payload': 'Metadane mapowania: {value}',
    'detail.food_nutrient_projection_selected':
        'Wybrano do bieżącej projekcji wartości punktowej w starszym formacie',
    'detail.food_nutrient_projection_evidence_only':
        'Tylko dowód; nie wybrano do projekcji wartości punktowej w starszym formacie',
    'detail.food_nutrient_observation_evidence':
        'Dowody obserwacji składników odżywczych',
    'detail.food_nutrient_observation_line':
        '{attribute}: wartość źródłowa {raw} · kwalifikator {qualifier} · jednostka {unit} · podstawa {basis} · zakres {low}–{high} · metoda {method} · dokument źródłowy {source}',
    'detail.food_catalog_unresolved':
        'Powiązanego rekordu nie znaleziono lokalnie: {id}',
    'detail.food_catalog_provenance_boundary':
        'Są to lokalnie powiązane dane, a nie pełny zrzut katalogu źródłowego. Wersja i zapytanie źródła nie są przypięte, a stabilność rankingu nie została oceniona.',
  },
  'ar': {
    'detail.food_catalog_provenance_title': 'مصدر بيانات كتالوج الطعام',
    'detail.food_missing_nutrient_fields':
        'عناصر غذائية بلا قيمة مصدرية (غير معروفة وليست صفراً): {fields}',
    'detail.food_nutrient_less_than_boundary':
        'يستخدم المصدر محدداً بمعنى «أقل من»: {attribute} = {raw} ({qualifier})؛ لم تُستنتج قيمة دقيقة.',
    'detail.food_catalog_provenance_unavailable':
        'لا توجد لهذا العنصر مستندات مصدر أو نطاق طعام أو أدلة ملاحظات غذائية مرتبطة.',
    'detail.food_catalog_source_documents': 'مستندات المصدر',
    'detail.food_catalog_document_summary':
        'المستند {id} · {title} · {organization} · {family} · النوع {type} · المستوى {tier} · {jurisdiction} · الحالة {status}',
    'detail.food_catalog_license': 'ملاحظة الترخيص المسجلة: {value}',
    'detail.food_catalog_source_dates':
        'نُشر {published} · ساري من {effective}',
    'detail.food_catalog_source_url': 'عنوان المصدر: {value}',
    'detail.food_catalog_payload_digest':
        'SHA-256 لنص الحمولة المحفوظة بعد الاستيراد فقط (ليس إصدارًا كاملًا للكتالوج): {digest}',
    'detail.food_catalog_scopes': 'نطاق الطعام',
    'detail.food_catalog_scope_summary':
        'النطاق {hash} · {jurisdiction} · العلامة {brand} · التحضير {preparation} · الطهي {cooking} · الجزء النباتي {plant} · الصنف {cultivar} · إطار أخذ العينات {sampling}',
    'detail.food_catalog_mappings': 'مطابقات الطعام',
    'detail.food_catalog_mapping_summary':
        'المعرّف الخارجي {system}:{externalId} ← معرّف الطعام {appId} · الثقة المسجلة {confidence} (دقة المطابقة غير متحقق منها) · الحالة {status} · {selection}',
    'detail.food_catalog_mapping_selected': 'محدد لمعرّف الطعام المعروض حاليًا',
    'detail.food_catalog_mapping_not_selected':
        'غير محدد لمعرّف الطعام المعروض حاليًا',
    'detail.food_catalog_mapping_payload': 'بيانات المطابقة الوصفية: {value}',
    'detail.food_nutrient_projection_selected':
        'مختار لإسقاط القيمة النقطية الحالي بالنظام القديم',
    'detail.food_nutrient_projection_evidence_only':
        'للاستدلال فقط؛ لم يُختر لإسقاط القيمة النقطية بالنظام القديم',
    'detail.food_nutrient_observation_evidence':
        'أدلة ملاحظات العناصر الغذائية',
    'detail.food_nutrient_observation_line':
        '{attribute}: القيمة الأصلية {raw} · المحدد {qualifier} · الوحدة {unit} · الأساس {basis} · النطاق {low}–{high} · الطريقة {method} · مستند المصدر {source}',
    'detail.food_catalog_unresolved': 'السجل المرتبط غير موجود محليًا: {id}',
    'detail.food_catalog_provenance_boundary':
        'هذه بيانات مرتبطة محليًا وليست لقطة كاملة للكتالوج المصدر. لم يُثبّت إصدار المصدر أو الاستعلام، ولم يُقيّم استقرار الترتيب.',
  },
};

/// Copy for the content-addressed candidate input snapshot shown with a
/// next-meal result. It describes the captured app inputs, not an upstream
/// catalog release or a validated ranking-stability result.
const Map<String, Map<String, String>> kFoodCandidateSnapshotUiTranslations = {
  'zh': {
    'next_meal.candidate_snapshot_title': '本次食品候选集快照',
    'next_meal.candidate_snapshot_meta': '结构 {schema} · {count} 个候选项',
    'next_meal.candidate_snapshot_digest': '内容 SHA-256：{digest}',
    'next_meal.candidate_snapshot_boundary':
        '此摘要绑定本次运行中应用组装的输入；它不固定上游目录版本或查询，也不代表排序稳定性已评估。',
    'next_meal.candidate_order_may_change': '此候选项在已测试情景中的顺序可能变化',
    'next_meal.candidate_membership_may_change': '此候选项可能在已测试情景中进入或离开显示列表',
    'next_meal.rank_display_withheld':
        '由于排名敏感性证据缺失、过期，或已测试情景发现顺序或显示范围变化，本次暂不显示分数排序候选项。',
    'next_meal.rank_stability_status': '排序稳定性：尚未评估',
    'next_meal.rank_stability_boundary':
        '当前顺序使用单点启发式分数。营养单位/份量换算与来源支持的不确定性传播尚未验证，因此尚未分析并列、名次变化或候选项互换。',
    'next_meal.rank_stability_bounded_change': '来源区间压力测试发现可能的排序变化',
    'next_meal.rank_stability_bounded_membership_change': '来源区间压力测试发现候选项进出显示范围',
    'next_meal.rank_stability_bounded_no_change': '已测来源区间情景中未发现顺序变化',
    'next_meal.rank_stability_swap_summary':
        '在 {scenarios} 个来源范围/评分阈值情景中发现可能互换：{pairs}{more}。仅覆盖严格匹配的蛋白质/纤维区间；其他测量、份量与匹配不确定性仍未评估。',
    'next_meal.rank_stability_membership_summary':
        '在 {scenarios} 个来源范围/评分阈值情景中，有 {count} 个候选项进出显示范围。仅覆盖严格匹配的蛋白质/纤维区间；其他不确定性仍未评估。',
    'next_meal.rank_stability_no_swap_summary':
        '在 {scenarios} 个来源范围/评分阈值情景中未观察到顺序变化；{changes} 个候选项的分数、决策、说明或特征发生变化。此结果不证明排序稳定；其他测量、份量与匹配不确定性仍未评估。',
  },
  'en': {
    'next_meal.candidate_snapshot_title': 'Food candidate-set snapshot',
    'next_meal.candidate_snapshot_meta': 'Schema {schema} · {count} candidates',
    'next_meal.candidate_snapshot_digest': 'Content SHA-256: {digest}',
    'next_meal.candidate_snapshot_boundary':
        'Binds the app-assembled inputs for this run; the upstream catalog release and query are not pinned, and ranking stability has not been assessed.',
    'next_meal.candidate_order_may_change':
        'This candidate’s position may change in tested scenarios',
    'next_meal.candidate_membership_may_change':
        'This candidate may enter or leave the displayed set in tested scenarios',
    'next_meal.rank_display_withheld':
        'Ranked candidates are withheld because sensitivity evidence is missing, stale, or showed an order or displayed-set change in tested scenarios.',
    'next_meal.rank_stability_status': 'Ranking stability: not assessed',
    'next_meal.rank_stability_boundary':
        'The displayed order uses point-valued heuristic scores. Nutrient unit/portion conversion and source-supported uncertainty propagation are not validated, so ties, rank changes, and candidate swaps have not been analyzed.',
    'next_meal.rank_stability_bounded_change':
        'Source-range stress test found possible order changes',
    'next_meal.rank_stability_bounded_membership_change':
        'Source-range stress test found candidates entering or leaving the displayed set',
    'next_meal.rank_stability_bounded_no_change':
        'No order changes observed in tested source-range scenarios',
    'next_meal.rank_stability_swap_summary':
        'Possible swaps in {scenarios} source-range/score-threshold scenarios: {pairs}{more}. Only strictly matched protein/fiber ranges are covered; other measurement, portion, and matching uncertainty remains unassessed.',
    'next_meal.rank_stability_membership_summary':
        '{count} candidates entered or left the displayed set across {scenarios} source-range/score-threshold scenarios. Only strictly matched protein/fiber ranges are covered; other uncertainty remains unassessed.',
    'next_meal.rank_stability_no_swap_summary':
        'No order changes were observed in {scenarios} source-range/score-threshold scenarios; {changes} candidates changed score, decision, explanation, or features. This does not establish ranking stability; other measurement, portion, and matching uncertainty remains unassessed.',
  },
  'fr': {
    'next_meal.candidate_snapshot_title': 'Instantané des aliments candidats',
    'next_meal.candidate_snapshot_meta': 'Schéma {schema} · {count} candidats',
    'next_meal.candidate_snapshot_digest': 'SHA-256 du contenu : {digest}',
    'next_meal.candidate_snapshot_boundary':
        'Lie les entrées assemblées par l’application pour cette exécution ; la version et la requête du catalogue amont ne sont pas figées, et la stabilité du classement n’a pas été évaluée.',
    'next_meal.candidate_order_may_change':
        'La position de cet aliment peut varier dans les scénarios testés',
    'next_meal.candidate_membership_may_change':
        'Cet aliment peut entrer dans la liste affichée ou en sortir dans les scénarios testés',
    'next_meal.rank_display_withheld':
        'Les candidats classés sont masqués, car les preuves de sensibilité sont absentes, périmées ou montrent un changement d’ordre ou de liste dans les scénarios testés.',
    'next_meal.rank_stability_status': 'Stabilité du classement : non évaluée',
    'next_meal.rank_stability_boundary':
        'L’ordre affiché utilise des scores heuristiques ponctuels. Les conversions d’unités/portions et la propagation d’incertitudes étayées par les sources ne sont pas validées ; les égalités, changements de rang et substitutions de candidats n’ont donc pas été analysés.',
    'next_meal.rank_stability_bounded_change':
        'Le test des plages sources détecte des changements possibles de classement',
    'next_meal.rank_stability_bounded_membership_change':
        'Le test des plages sources détecte des candidats entrant ou sortant de l’ensemble affiché',
    'next_meal.rank_stability_bounded_no_change':
        'Aucun changement d’ordre observé dans les scénarios de plages testés',
    'next_meal.rank_stability_swap_summary':
        'Échanges possibles dans {scenarios} scénarios de plages/seuils : {pairs}{more}. Seules les plages de protéines/fibres strictement rapprochées sont couvertes ; les autres incertitudes de mesure, portion et correspondance restent non évaluées.',
    'next_meal.rank_stability_membership_summary':
        '{count} candidats sont entrés dans l’ensemble affiché ou en sont sortis parmi {scenarios} scénarios de plages/seuils. Seules les plages de protéines/fibres strictement rapprochées sont couvertes ; les autres incertitudes restent non évaluées.',
    'next_meal.rank_stability_no_swap_summary':
        'Aucun changement d’ordre observé dans {scenarios} scénarios de plages/seuils ; {changes} candidats ont changé de score, décision, explication ou caractéristiques. Cela ne prouve pas la stabilité ; les autres incertitudes de mesure, portion et correspondance restent non évaluées.',
  },
  'ja': {
    'next_meal.candidate_snapshot_title': '今回の食品候補セットのスナップショット',
    'next_meal.candidate_snapshot_meta': 'スキーマ {schema} · 候補 {count} 件',
    'next_meal.candidate_snapshot_digest': '内容 SHA-256: {digest}',
    'next_meal.candidate_snapshot_boundary':
        'この実行でアプリが組み立てた入力を識別します。上流カタログの版やクエリは固定されず、順位の安定性も評価されていません。',
    'next_meal.candidate_order_may_change': 'テストしたシナリオでは、この候補の位置が変わる可能性があります',
    'next_meal.candidate_membership_may_change':
        'テストしたシナリオでは、この候補が表示対象に入る、または外れる可能性があります',
    'next_meal.rank_display_withheld':
        '感度評価がない、古い、またはテスト済みシナリオで順序や表示対象の変化が見つかったため、順位付き候補を表示しません。',
    'next_meal.rank_stability_status': '順位の安定性：未評価',
    'next_meal.rank_stability_boundary':
        '表示順は点推定のヒューリスティックスコアを使用しています。栄養素の単位・分量換算と出典に基づく不確実性伝播は未検証のため、同点、順位変動、候補の入れ替わりは分析していません。',
    'next_meal.rank_stability_bounded_change': '出典範囲のストレステストで順位変動の可能性を検出',
    'next_meal.rank_stability_bounded_membership_change':
        '出典範囲のストレステストで表示候補の出入りを検出',
    'next_meal.rank_stability_bounded_no_change': 'テストした出典範囲シナリオでは順位変動なし',
    'next_meal.rank_stability_swap_summary':
        '{scenarios} 件の出典範囲/スコア閾値シナリオで入れ替わりの可能性：{pairs}{more}。厳密に対応したタンパク質/食物繊維の範囲のみを対象とし、その他の測定・分量・照合の不確実性は未評価です。',
    'next_meal.rank_stability_membership_summary':
        '{scenarios} 件のシナリオで {count} 件の候補が表示対象に出入りしました。厳密に対応したタンパク質/食物繊維の範囲のみを対象とし、その他の不確実性は未評価です。',
    'next_meal.rank_stability_no_swap_summary':
        '{scenarios} 件のシナリオでは順位変動はありませんでしたが、{changes} 件の候補で点数、判断、説明、または特徴が変わりました。順位の安定性を証明するものではなく、その他の測定・分量・照合の不確実性は未評価です。',
  },
  'ko': {
    'next_meal.candidate_snapshot_title': '이번 식품 후보 집합 스냅샷',
    'next_meal.candidate_snapshot_meta': '스키마 {schema} · 후보 {count}개',
    'next_meal.candidate_snapshot_digest': '콘텐츠 SHA-256: {digest}',
    'next_meal.candidate_snapshot_boundary':
        '이번 실행에서 앱이 구성한 입력을 식별합니다. 상위 카탈로그 버전과 쿼리는 고정되지 않았으며 순위 안정성도 평가되지 않았습니다.',
    'next_meal.candidate_order_may_change': '테스트된 시나리오에서 이 후보의 순위가 달라질 수 있습니다',
    'next_meal.candidate_membership_may_change':
        '테스트된 시나리오에서 이 후보가 표시 목록에 들어오거나 제외될 수 있습니다',
    'next_meal.rank_display_withheld':
        '민감도 근거가 없거나 오래되었거나 테스트한 시나리오에서 순서 또는 표시 목록의 변화가 발견되어 순위 후보를 숨깁니다.',
    'next_meal.rank_stability_status': '순위 안정성: 평가되지 않음',
    'next_meal.rank_stability_boundary':
        '표시 순서는 점값 휴리스틱 점수를 사용합니다. 영양소 단위/분량 변환과 출처 기반 불확실성 전파가 검증되지 않아 동점, 순위 변화, 후보 교체를 분석하지 않았습니다.',
    'next_meal.rank_stability_bounded_change': '출처 범위 스트레스 테스트에서 순위 변화 가능성 발견',
    'next_meal.rank_stability_bounded_membership_change':
        '출처 범위 스트레스 테스트에서 표시 후보의 진입 또는 이탈 발견',
    'next_meal.rank_stability_bounded_no_change': '테스트한 출처 범위 시나리오에서 순서 변화 없음',
    'next_meal.rank_stability_swap_summary':
        '{scenarios}개 출처 범위/점수 임계값 시나리오에서 순위 교체 가능성: {pairs}{more}. 엄격히 일치하는 단백질/식이섬유 범위만 다루며, 다른 측정·분량·매칭 불확실성은 평가되지 않았습니다.',
    'next_meal.rank_stability_membership_summary':
        '{scenarios}개 시나리오에서 {count}개 후보가 표시 집합에 들어오거나 나갔습니다. 엄격히 일치하는 단백질/식이섬유 범위만 다루며, 다른 불확실성은 평가되지 않았습니다.',
    'next_meal.rank_stability_no_swap_summary':
        '{scenarios}개 시나리오에서 순서 변화는 없었지만 {changes}개 후보의 점수, 결정, 설명 또는 특성이 바뀌었습니다. 이는 순위 안정성의 증거가 아니며 다른 측정·분량·매칭 불확실성은 평가되지 않았습니다.',
  },
  'hi': {
    'next_meal.candidate_snapshot_title':
        'इस बार के भोजन उम्मीदवार सेट का स्नैपशॉट',
    'next_meal.candidate_snapshot_meta': 'स्कीमा {schema} · {count} उम्मीदवार',
    'next_meal.candidate_snapshot_digest': 'सामग्री SHA-256: {digest}',
    'next_meal.candidate_snapshot_boundary':
        'यह इस रन के लिए ऐप द्वारा जोड़े गए इनपुट को बाँधता है; अपस्ट्रीम कैटलॉग रिलीज़ और क्वेरी तय नहीं हैं, और रैंकिंग स्थिरता का आकलन नहीं हुआ है।',
    'next_meal.candidate_order_may_change':
        'जाँचे गए परिदृश्यों में इस उम्मीदवार का स्थान बदल सकता है',
    'next_meal.candidate_membership_may_change':
        'जाँचे गए परिदृश्यों में यह उम्मीदवार दिखाई गई सूची में आ या बाहर हो सकता है',
    'next_meal.rank_display_withheld':
        'संवेदनशीलता साक्ष्य अनुपस्थित या पुराना है, या जाँचे गए परिदृश्यों में क्रम अथवा प्रदर्शित समूह बदला है; इसलिए क्रमित उम्मीदवार छिपाए गए हैं।',
    'next_meal.rank_stability_status': 'रैंक स्थिरता: आकलन नहीं हुआ',
    'next_meal.rank_stability_boundary':
        'दिखाया गया क्रम बिंदु-आधारित अनुमानित स्कोर उपयोग करता है। पोषक तत्व इकाई/मात्रा रूपांतरण और स्रोत-समर्थित अनिश्चितता प्रसार सत्यापित नहीं हैं, इसलिए बराबरी, रैंक बदलाव और उम्मीदवारों की अदला-बदली का विश्लेषण नहीं हुआ है।',
    'next_meal.rank_stability_bounded_change':
        'स्रोत-सीमा तनाव परीक्षण में क्रम बदलने की संभावना मिली',
    'next_meal.rank_stability_bounded_membership_change':
        'स्रोत-सीमा तनाव परीक्षण में उम्मीदवारों का दिखाए गए सेट में आना या जाना मिला',
    'next_meal.rank_stability_bounded_no_change':
        'जाँचे गए स्रोत-सीमा परिदृश्यों में क्रम नहीं बदला',
    'next_meal.rank_stability_swap_summary':
        '{scenarios} स्रोत-सीमा/स्कोर-सीमा परिदृश्यों में संभावित अदला-बदली: {pairs}{more}। केवल कड़ाई से मेल खाते प्रोटीन/फाइबर अंतराल शामिल हैं; अन्य मापन, मात्रा और मिलान अनिश्चितता का आकलन नहीं हुआ है।',
    'next_meal.rank_stability_membership_summary':
        '{scenarios} परिदृश्यों में {count} उम्मीदवार दिखाए गए सेट में आए या उससे बाहर गए। केवल कड़ाई से मेल खाते प्रोटीन/फाइबर अंतराल शामिल हैं; अन्य अनिश्चितता का आकलन नहीं हुआ है।',
    'next_meal.rank_stability_no_swap_summary':
        '{scenarios} परिदृश्यों में क्रम नहीं बदला, लेकिन {changes} उम्मीदवारों के स्कोर, निर्णय, व्याख्या या विशेषताएँ बदलीं। यह रैंक स्थिरता सिद्ध नहीं करता; अन्य मापन, मात्रा और मिलान अनिश्चितता का आकलन नहीं हुआ है।',
  },
  'es': {
    'next_meal.candidate_snapshot_title':
        'Instantánea del conjunto de alimentos candidatos',
    'next_meal.candidate_snapshot_meta':
        'Esquema {schema} · {count} candidatos',
    'next_meal.candidate_snapshot_digest': 'SHA-256 del contenido: {digest}',
    'next_meal.candidate_snapshot_boundary':
        'Vincula las entradas ensambladas por la aplicación para esta ejecución; la versión y la consulta del catálogo de origen no están fijadas, y no se ha evaluado la estabilidad de la clasificación.',
    'next_meal.candidate_order_may_change':
        'La posición de este candidato puede cambiar en los escenarios probados',
    'next_meal.candidate_membership_may_change':
        'Este candidato puede entrar o salir de la lista mostrada en los escenarios probados',
    'next_meal.rank_display_withheld':
        'Se ocultan los candidatos ordenados porque faltan pruebas de sensibilidad, están obsoletas o los escenarios probados cambiaron el orden o el conjunto mostrado.',
    'next_meal.rank_stability_status': 'Estabilidad del ranking: no evaluada',
    'next_meal.rank_stability_boundary':
        'El orden mostrado usa puntuaciones heurísticas puntuales. No se han validado las conversiones de unidades/porciones ni la propagación de incertidumbre respaldada por fuentes; por eso no se analizaron empates, cambios de posición ni intercambios de candidatos.',
    'next_meal.rank_stability_bounded_change':
        'La prueba de rangos de origen detectó posibles cambios de orden',
    'next_meal.rank_stability_bounded_membership_change':
        'La prueba de rangos de origen detectó candidatos que entran o salen del conjunto mostrado',
    'next_meal.rank_stability_bounded_no_change':
        'No se observaron cambios de orden en los escenarios de rangos probados',
    'next_meal.rank_stability_swap_summary':
        'Posibles intercambios en {scenarios} escenarios de rangos/umbrales: {pairs}{more}. Solo se incluyen rangos de proteína/fibra con coincidencia estricta; las demás incertidumbres de medición, porción y correspondencia siguen sin evaluarse.',
    'next_meal.rank_stability_membership_summary':
        '{count} candidatos entraron o salieron del conjunto mostrado en {scenarios} escenarios. Solo se incluyen rangos de proteína/fibra con coincidencia estricta; las demás incertidumbres siguen sin evaluarse.',
    'next_meal.rank_stability_no_swap_summary':
        'No se observaron cambios de orden en {scenarios} escenarios; {changes} candidatos cambiaron puntuación, decisión, explicación o características. Esto no demuestra estabilidad; las demás incertidumbres siguen sin evaluarse.',
  },
  'vi': {
    'next_meal.candidate_snapshot_title':
        'Ảnh chụp tập thực phẩm ứng viên lần này',
    'next_meal.candidate_snapshot_meta': 'Lược đồ {schema} · {count} ứng viên',
    'next_meal.candidate_snapshot_digest': 'SHA-256 nội dung: {digest}',
    'next_meal.candidate_snapshot_boundary':
        'Liên kết các đầu vào do ứng dụng tập hợp cho lần chạy này; phiên bản và truy vấn danh mục nguồn chưa được cố định, và độ ổn định thứ hạng chưa được đánh giá.',
    'next_meal.candidate_order_may_change':
        'Vị trí của ứng viên này có thể thay đổi trong các tình huống đã kiểm tra',
    'next_meal.candidate_membership_may_change':
        'Ứng viên này có thể vào hoặc rời danh sách hiển thị trong các tình huống đã kiểm tra',
    'next_meal.rank_display_withheld':
        'Danh sách ứng viên theo thứ hạng được ẩn vì thiếu bằng chứng độ nhạy, bằng chứng đã cũ hoặc kịch bản đã thử làm thay đổi thứ tự hay tập hiển thị.',
    'next_meal.rank_stability_status': 'Độ ổn định thứ hạng: chưa đánh giá',
    'next_meal.rank_stability_boundary':
        'Thứ tự hiển thị dùng điểm heuristic dạng điểm đơn. Việc đổi đơn vị/khẩu phần dinh dưỡng và truyền độ bất định có nguồn hỗ trợ chưa được xác thực, nên chưa phân tích trường hợp bằng điểm, đổi thứ hạng hay hoán đổi ứng viên.',
    'next_meal.rank_stability_bounded_change':
        'Kiểm thử khoảng giá trị nguồn phát hiện khả năng đổi thứ hạng',
    'next_meal.rank_stability_bounded_membership_change':
        'Kiểm thử khoảng giá trị nguồn phát hiện ứng viên vào hoặc rời tập hiển thị',
    'next_meal.rank_stability_bounded_no_change':
        'Không thấy đổi thứ tự trong các kịch bản khoảng nguồn đã kiểm thử',
    'next_meal.rank_stability_swap_summary':
        'Có thể hoán đổi trong {scenarios} kịch bản khoảng nguồn/ngưỡng điểm: {pairs}{more}. Chỉ bao gồm khoảng protein/chất xơ khớp nghiêm ngặt; bất định đo lường, khẩu phần và đối sánh khác chưa được đánh giá.',
    'next_meal.rank_stability_membership_summary':
        '{count} ứng viên vào hoặc rời tập hiển thị trong {scenarios} kịch bản. Chỉ bao gồm khoảng protein/chất xơ khớp nghiêm ngặt; bất định khác chưa được đánh giá.',
    'next_meal.rank_stability_no_swap_summary':
        'Không thấy đổi thứ tự trong {scenarios} kịch bản; {changes} ứng viên đổi điểm, quyết định, giải thích hoặc đặc tính. Điều này không chứng minh thứ hạng ổn định; bất định khác chưa được đánh giá.',
  },
  'th': {
    'next_meal.candidate_snapshot_title':
        'ภาพรวมชุดอาหารตัวเลือกของการทำงานนี้',
    'next_meal.candidate_snapshot_meta':
        'สคีมา {schema} · ตัวเลือก {count} รายการ',
    'next_meal.candidate_snapshot_digest': 'SHA-256 ของเนื้อหา: {digest}',
    'next_meal.candidate_snapshot_boundary':
        'ผูกกับข้อมูลนำเข้าที่แอปรวบรวมสำหรับการทำงานนี้ แต่ไม่ได้ตรึงรุ่นหรือคำค้นของแค็ตตาล็อกต้นทาง และยังไม่ได้ประเมินความเสถียรของอันดับ',
    'next_meal.candidate_order_may_change':
        'ตำแหน่งของรายการนี้อาจเปลี่ยนไปในสถานการณ์ที่ทดสอบ',
    'next_meal.candidate_membership_may_change':
        'รายการนี้อาจเข้าหรือออกจากชุดที่แสดงในสถานการณ์ที่ทดสอบ',
    'next_meal.rank_display_withheld':
        'ซ่อนรายการผู้สมัครที่เรียงอันดับ เนื่องจากไม่มีหลักฐานความไว หลักฐานล้าสมัย หรือสถานการณ์ที่ทดสอบพบการเปลี่ยนลำดับหรือรายการที่แสดง',
    'next_meal.rank_stability_status': 'ความเสถียรของอันดับ: ยังไม่ได้ประเมิน',
    'next_meal.rank_stability_boundary':
        'ลำดับที่แสดงใช้คะแนนฮิวริสติกแบบค่าจุด การแปลงหน่วย/ปริมาณสารอาหารและการส่งผ่านความไม่แน่นอนที่มีแหล่งรองรับยังไม่ได้ตรวจสอบ จึงยังไม่ได้วิเคราะห์คะแนนเสมอ การเปลี่ยนอันดับ หรือการสลับผู้สมัคร',
    'next_meal.rank_stability_bounded_change':
        'การทดสอบช่วงค่าจากแหล่งข้อมูลพบความเป็นไปได้ที่ลำดับจะเปลี่ยน',
    'next_meal.rank_stability_bounded_membership_change':
        'การทดสอบช่วงค่าจากแหล่งข้อมูลพบผู้สมัครเข้าออกชุดที่แสดง',
    'next_meal.rank_stability_bounded_no_change':
        'ไม่พบการเปลี่ยนลำดับในสถานการณ์ช่วงค่าที่ทดสอบ',
    'next_meal.rank_stability_swap_summary':
        'อาจสลับลำดับใน {scenarios} สถานการณ์ช่วงค่า/เกณฑ์คะแนน: {pairs}{more} ครอบคลุมเฉพาะช่วงโปรตีน/ใยอาหารที่จับคู่กันอย่างเข้มงวด ความไม่แน่นอนด้านการวัด ปริมาณ และการจับคู่อื่นยังไม่ได้ประเมิน',
    'next_meal.rank_stability_membership_summary':
        'มีผู้สมัคร {count} รายเข้าออกชุดที่แสดงใน {scenarios} สถานการณ์ ครอบคลุมเฉพาะช่วงโปรตีน/ใยอาหารที่จับคู่กันอย่างเข้มงวด ความไม่แน่นอนอื่นยังไม่ได้ประเมิน',
    'next_meal.rank_stability_no_swap_summary':
        'ไม่พบการเปลี่ยนลำดับใน {scenarios} สถานการณ์ แต่ผู้สมัคร {changes} รายมีคะแนน การตัดสินใจ คำอธิบาย หรือลักษณะเปลี่ยนไป สิ่งนี้ไม่พิสูจน์ความเสถียรของอันดับ ความไม่แน่นอนอื่นยังไม่ได้ประเมิน',
  },
  'id': {
    'next_meal.candidate_snapshot_title':
        'Snapshot kumpulan kandidat makanan ini',
    'next_meal.candidate_snapshot_meta': 'Skema {schema} · {count} kandidat',
    'next_meal.candidate_snapshot_digest': 'SHA-256 konten: {digest}',
    'next_meal.candidate_snapshot_boundary':
        'Mengikat masukan yang dirangkai aplikasi untuk proses ini; rilis dan kueri katalog hulu belum ditetapkan, dan kestabilan peringkat belum dinilai.',
    'next_meal.candidate_order_may_change':
        'Posisi kandidat ini dapat berubah dalam skenario yang diuji',
    'next_meal.candidate_membership_may_change':
        'Kandidat ini dapat masuk atau keluar dari daftar yang ditampilkan dalam skenario yang diuji',
    'next_meal.rank_display_withheld':
        'Kandidat berperingkat disembunyikan karena bukti sensitivitas tidak ada, sudah usang, atau skenario yang diuji mengubah urutan maupun daftar tampilan.',
    'next_meal.rank_stability_status': 'Stabilitas peringkat: belum dinilai',
    'next_meal.rank_stability_boundary':
        'Urutan yang ditampilkan memakai skor heuristik bernilai titik. Konversi satuan/porsi nutrisi dan propagasi ketidakpastian yang didukung sumber belum divalidasi, sehingga seri, perubahan peringkat, dan pertukaran kandidat belum dianalisis.',
    'next_meal.rank_stability_bounded_change':
        'Uji rentang sumber menemukan kemungkinan perubahan urutan',
    'next_meal.rank_stability_bounded_membership_change':
        'Uji rentang sumber menemukan kandidat masuk atau keluar dari daftar tampil',
    'next_meal.rank_stability_bounded_no_change':
        'Tidak ada perubahan urutan pada skenario rentang sumber yang diuji',
    'next_meal.rank_stability_swap_summary':
        'Kemungkinan pertukaran pada {scenarios} skenario rentang sumber/ambang skor: {pairs}{more}. Hanya rentang protein/serat yang cocok ketat yang tercakup; ketidakpastian pengukuran, porsi, dan pencocokan lain belum dinilai.',
    'next_meal.rank_stability_membership_summary':
        '{count} kandidat masuk atau keluar dari daftar tampil pada {scenarios} skenario. Hanya rentang protein/serat yang cocok ketat yang tercakup; ketidakpastian lain belum dinilai.',
    'next_meal.rank_stability_no_swap_summary':
        'Tidak ada perubahan urutan pada {scenarios} skenario; {changes} kandidat berubah skor, keputusan, penjelasan, atau fiturnya. Ini tidak membuktikan stabilitas peringkat; ketidakpastian lain belum dinilai.',
  },
  'ru': {
    'next_meal.candidate_snapshot_title': 'Снимок набора вариантов еды',
    'next_meal.candidate_snapshot_meta': 'Схема {schema} · вариантов: {count}',
    'next_meal.candidate_snapshot_digest': 'SHA-256 содержимого: {digest}',
    'next_meal.candidate_snapshot_boundary':
        'Связывает входные данные, собранные приложением для этого запуска; версия и запрос к исходному каталогу не зафиксированы, устойчивость ранжирования не оценивалась.',
    'next_meal.candidate_order_may_change':
        'Позиция этого кандидата может измениться в проверенных сценариях',
    'next_meal.candidate_membership_may_change':
        'Этот кандидат может появиться в отображаемом списке или исчезнуть из него в проверенных сценариях',
    'next_meal.rank_display_withheld':
        'Список кандидатов по рейтингу скрыт: данные анализа чувствительности отсутствуют, устарели или выявили изменение порядка либо состава списка.',
    'next_meal.rank_stability_status':
        'Устойчивость ранжирования: не оценивалась',
    'next_meal.rank_stability_boundary':
        'Показанный порядок использует точечные эвристические баллы. Преобразование единиц/порций питательных веществ и распространение неопределённости на основе источников не проверены, поэтому ничьи, изменения мест и замены кандидатов не анализировались.',
    'next_meal.rank_stability_bounded_change':
        'Стресс-тест исходных диапазонов выявил возможные изменения порядка',
    'next_meal.rank_stability_bounded_membership_change':
        'Стресс-тест выявил вход или выход кандидатов из отображаемого набора',
    'next_meal.rank_stability_bounded_no_change':
        'В проверенных сценариях исходных диапазонов порядок не изменился',
    'next_meal.rank_stability_swap_summary':
        'Возможные перестановки в {scenarios} сценариях диапазонов/порогов: {pairs}{more}. Учтены только строго сопоставленные диапазоны белка/клетчатки; прочая неопределённость измерений, порций и сопоставления не оценена.',
    'next_meal.rank_stability_membership_summary':
        '{count} кандидатов вошли в отображаемый набор или вышли из него в {scenarios} сценариях. Учтены только строго сопоставленные диапазоны белка/клетчатки; прочая неопределённость не оценена.',
    'next_meal.rank_stability_no_swap_summary':
        'В {scenarios} сценариях порядок не изменился, но у {changes} кандидатов изменились балл, решение, объяснение или признаки. Это не доказывает устойчивость; прочая неопределённость не оценена.',
  },
  'pl': {
    'next_meal.candidate_snapshot_title':
        'Migawka zbioru kandydatów żywieniowych',
    'next_meal.candidate_snapshot_meta':
        'Schemat {schema} · kandydatów: {count}',
    'next_meal.candidate_snapshot_digest': 'SHA-256 treści: {digest}',
    'next_meal.candidate_snapshot_boundary':
        'Wiąże dane wejściowe zestawione przez aplikację dla tego uruchomienia; wersja i zapytanie do katalogu źródłowego nie są przypięte, a stabilność rankingu nie została oceniona.',
    'next_meal.candidate_order_may_change':
        'Pozycja tego kandydata może się zmienić w testowanych scenariuszach',
    'next_meal.candidate_membership_may_change':
        'Ten kandydat może pojawić się na wyświetlanej liście lub z niej zniknąć w testowanych scenariuszach',
    'next_meal.rank_display_withheld':
        'Lista kandydatów według rankingu jest ukryta, ponieważ brak dowodów analizy wrażliwości, są nieaktualne albo testowane scenariusze zmieniły kolejność lub zestaw.',
    'next_meal.rank_stability_status': 'Stabilność rankingu: nie oceniono',
    'next_meal.rank_stability_boundary':
        'Wyświetlana kolejność używa punktowych wyników heurystycznych. Konwersje jednostek/porcji składników i propagacja niepewności poparta źródłami nie zostały zweryfikowane, dlatego nie analizowano remisów, zmian pozycji ani zamian kandydatów.',
    'next_meal.rank_stability_bounded_change':
        'Test zakresów źródłowych wykrył możliwe zmiany kolejności',
    'next_meal.rank_stability_bounded_membership_change':
        'Test zakresów wykrył kandydatów wchodzących do zestawu lub z niego wypadających',
    'next_meal.rank_stability_bounded_no_change':
        'W testowanych scenariuszach zakresów nie zaobserwowano zmian kolejności',
    'next_meal.rank_stability_swap_summary':
        'Możliwe zamiany w {scenarios} scenariuszach zakresów/progów: {pairs}{more}. Uwzględniono tylko ściśle dopasowane zakresy białka/błonnika; pozostała niepewność pomiaru, porcji i dopasowania nie została oceniona.',
    'next_meal.rank_stability_membership_summary':
        '{count} kandydatów weszło do wyświetlanego zestawu lub z niego wypadło w {scenarios} scenariuszach. Uwzględniono tylko ściśle dopasowane zakresy białka/błonnika; pozostała niepewność nie została oceniona.',
    'next_meal.rank_stability_no_swap_summary':
        'W {scenarios} scenariuszach nie zmieniła się kolejność, ale {changes} kandydatów zmieniło wynik, decyzję, wyjaśnienie lub cechy. Nie dowodzi to stabilności rankingu; pozostała niepewność nie została oceniona.',
  },
  'ar': {
    'next_meal.candidate_snapshot_title':
        'لقطة مجموعة الأطعمة المرشحة لهذه العملية',
    'next_meal.candidate_snapshot_meta':
        'المخطط {schema} · عدد المرشحين {count}',
    'next_meal.candidate_snapshot_digest': 'بصمة المحتوى SHA-256: {digest}',
    'next_meal.candidate_snapshot_boundary':
        'تربط المدخلات التي جمّعها التطبيق لهذه العملية؛ لم يُثبّت إصدار الكتالوج المصدر أو استعلامه، ولم يُقيّم استقرار الترتيب.',
    'next_meal.candidate_order_may_change':
        'قد يتغير موضع هذا الخيار في السيناريوهات المختبرة',
    'next_meal.candidate_membership_may_change':
        'قد يظهر هذا الخيار في القائمة المعروضة أو يختفي منها في السيناريوهات المختبرة',
    'next_meal.rank_display_withheld':
        'أُخفيت العناصر المرتبة لأن أدلة الحساسية مفقودة أو قديمة، أو لأن السيناريوهات المختبرة غيّرت الترتيب أو مجموعة العرض.',
    'next_meal.rank_stability_status': 'استقرار الترتيب: لم يُقيّم',
    'next_meal.rank_stability_boundary':
        'يستخدم الترتيب المعروض درجات استدلالية نقطية. لم يتم التحقق من تحويل وحدات/حصص المغذيات أو نشر عدم اليقين المدعوم بالمصادر، لذا لم تُحلل حالات التعادل أو تغيّر الرتب أو تبديل المرشحين.',
    'next_meal.rank_stability_bounded_change':
        'اختبار نطاقات المصدر كشف احتمال تغيّر الترتيب',
    'next_meal.rank_stability_bounded_membership_change':
        'اختبار نطاقات المصدر كشف دخول مرشحين إلى المجموعة المعروضة أو خروجهم منها',
    'next_meal.rank_stability_bounded_no_change':
        'لم يُلاحظ تغيّر في الترتيب ضمن سيناريوهات النطاقات المختبرة',
    'next_meal.rank_stability_swap_summary':
        'تبديلات محتملة في {scenarios} من سيناريوهات نطاق المصدر/عتبة الدرجة: {pairs}{more}. تشمل فقط نطاقات البروتين/الألياف المتطابقة بدقة؛ ولم تُقيّم بقية أوجه عدم يقين القياس والحصة والمطابقة.',
    'next_meal.rank_stability_membership_summary':
        'دخل {count} من المرشحين المجموعة المعروضة أو خرجوا منها عبر {scenarios} سيناريوهات. تشمل فقط نطاقات البروتين/الألياف المتطابقة بدقة؛ ولم تُقيّم أوجه عدم اليقين الأخرى.',
    'next_meal.rank_stability_no_swap_summary':
        'لم يتغير الترتيب في {scenarios} سيناريوهات، لكن تغيّرت الدرجة أو القرار أو التفسير أو الخصائص لدى {changes} من المرشحين. هذا لا يثبت استقرار الترتيب؛ ولم تُقيّم أوجه عدم اليقين الأخرى.',
  },
};

/// Localized copy for the portable-data package settings page. The English
/// and Chinese base maps remain the source for those two families; these
/// eleven families are merged ahead of their existing dictionary so each
/// page key resolves natively instead of silently falling back to English.
const List<String> kPortableDataPackageTranslationKeys = [
  'portable.title',
  'portable.unencrypted_title',
  'portable.unencrypted_body',
  'portable.boundary',
  'portable.fuzz_title',
  'portable.fuzz_summary',
  'portable.fuzz_runtime',
  'portable.fuzz_unicode',
  'portable.fuzz_boundary',
  'portable.export_title',
  'portable.export_body',
  'portable.generate',
  'portable.integrity_ready',
  'portable.file_count',
  'portable.byte_count',
  'portable.owner_protection',
  'portable.owner_revision',
  'portable.owner_migrated',
  'portable.rotate_identity',
  'portable.rotate_title',
  'portable.rotate_body',
  'portable.rotate_confirm',
  'portable.rotate_success',
  'portable.rotate_error',
  'portable.copy',
  'portable.save',
  'portable.copied',
  'portable.preview_title',
  'portable.preview_body',
  'portable.package_json',
  'portable.paste',
  'portable.use_generated',
  'portable.inspect',
  'portable.status_ready',
  'portable.status_wrongOwner',
  'portable.status_unsupportedSchema',
  'portable.status_corrupt',
  'portable.preview_summary',
  'portable.migration_receipt_title',
  'portable.migration_receipt_summary',
  'portable.migration_receipt_identity',
  'portable.migration_receipt_boundary',
  'portable.reminder_presentation_title',
  'portable.reminder_presentation_summary',
  'portable.reminder_presentation_modes',
  'portable.reminder_presentation_policy',
  'portable.reminder_presentation_legacy',
  'portable.reminder_target_consent',
  'portable.unsupported_fields',
  'portable.no_write',
  'portable.error_scope',
  'portable.error_account_changed',
  'portable.error_generate',
  'portable.error_copy',
  'portable.error_save',
  'portable.error_empty',
  'portable.error_input_too_large',
  'portable.error_inspect',
  'portable.clipboard_empty',
  'portable.save_unsupported',
  'portable.save_fallback_copied',
  'portable.save_failed_copied',
  'portable.save_failed_residual_copied',
  'portable.error_save_residual',
  'portable.saved_visible',
  'portable.download_requested',
  'portable.saved_app_documents',
  'portable.downloads',
];

/// Values follow [kPortableDataPackageTranslationKeys] in order. Keeping a
/// single ordered key list lets tests verify every shipped language has the
/// same complete surface and the same interpolation contract.
const Map<String, List<String>> _portableDataPackageLocaleRows = {
  'fr': [
    "Mon paquet de données portable",
    "Ceci est une copie sensible non chiffrée",
    "Le paquet peut contenir des repas, des journaux de médicaments, des notes de dose et du texte de rappel. Enregistrez-le uniquement dans un emplacement que vous contrôlez. SHA-256 détecte les modifications, mais ne chiffre ni ne masque le contenu.",
    "Cette fonction crée un JSON lisible par l’utilisateur et un aperçu d’importation sans écriture. Elle ne supprime aucun compte, ne restaure pas les données et ne certifie pas la conformité légale. La liaison au compte local utilise un jeton aléatoire conservé sur cet appareil ; un autre appareil peut donc ne pas la valider.",
    "Limites du test différentiel du schéma portable",
    "Générateur v1 · {seeds} graines fixes · {partitions} partitions lexicales/sémantiques · {cases} cas synthétiques de régression soumis à une revue de confidentialité du corpus · {runtimes} environnements.",
    "Contrôle hors ligne configuré : {runtime}. Node ne s’exécute pas dans l’application.",
    "Le précontrôle de production rejette les membres en double, les substituts isolés, les non-caractères Unicode et les entrées qui dépassent les budgets de taille, nœuds, profondeur, largeur, jetons de chaîne source ou décodée, clés ou nombres. La campagne différentielle fixe couvre aussi la priorité des erreurs combinées, l’inventaire unique du manifeste et le contrat d’intégrité.",
    "Ceci décrit la portée compilée, pas un reçu d’exécution récent sur cet appareil. Le seuil de durée est vérifié seulement après le retour et ne peut pas arrêter un analyseur bloqué. La réduction des cas entre environnements, ainsi que les analyseurs des versions navigateur, Android, iOS et ordinateur, restent non vérifiés.",
    "Créer un instantané actuel des données",
    "Exporte le profil actuellement chargé, les préférences, les choix de médicaments, les prises, les repas, les rappels de cet appareil et les liens entre dossiers. UID, e-mail, jetons d’activation des rappels et points de terminaison d’IA locale sont exclus. La liaison du propriétaire, unidirectionnelle et séparée par domaine, est pseudonyme, pas anonyme.",
    "Générer et vérifier",
    "Vérification d’intégrité réussie",
    "{count} fichiers structurés",
    "{count} octets",
    "Protection de l’autorisation locale : {protection}",
    "Révision de l’autorisation : {revision}",
    "L’ancien jeton local a été vérifié, migré et supprimé",
    "Renouveler l’identité d’exportation locale",
    "Renouveler l’identité d’exportation locale ?",
    "Cela crée une nouvelle autorisation liée à l’appareil. Les paquets créés auparavant ne passeront plus la validation du propriétaire pour ce compte local. Le contenu des paquets n’est pas modifié et l’opération est irréversible.",
    "Renouveler et effacer le paquet actuel",
    "Identité d’exportation locale renouvelée. Le paquet et l’aperçu actuels ont été effacés.",
    "Impossible de renouveler l’identité locale en toute sécurité. L’identité existante reste utilisée.",
    "Copier le JSON",
    "Enregistrer le paquet",
    "JSON du paquet copié. Enregistrez-le dans un emplacement protégé.",
    "Aperçu d’importation (aucune écriture)",
    "Collez un paquet ParkinSUM pour vérifier le format, la version, la liaison au propriétaire, les sommes de contrôle, les comptes, les conflits et les champs non pris en charge. Cette version n’effectue pas d’importation.",
    "JSON du paquet",
    "Coller depuis le presse-papiers",
    "Utiliser le paquet généré",
    "Lancer l’aperçu sans écriture",
    "Prêt pour un futur processus d’importation contrôlé",
    "Le compte ou l’appareil ne correspond pas",
    "Schéma du paquet non pris en charge",
    "Paquet endommagé ou invalide",
    "{records} dossiers · {conflicts} conflits · {unsupported} champs non pris en charge",
    "Reçu de validation du schéma figé et de migration",
    "Source v{source} → cible v{target} · décision : {decision}",
    "Reçu {receipt}… · validateur source {validator}…",
    "Ce reçu prouve uniquement une validation ou un aperçu déterministe local. Il n’effectue aucune écriture, planification ou requête réseau et ne prouve ni l’identité de l’émetteur ni l’exactitude clinique.",
    "Aperçu de l’intention de présentation des rappels",
    "{total} plans de rappel · {enabled} activés sur la source · {consent} nécessitent un consentement explicite sur l’appareil cible avant la planification.",
    "Modes de confidentialité : {modes} · langues de notification enregistrées : {languages}",
    "{match} conformes à la politique de texte actuelle · {drift} à recalculer · {decisions} choix de langue différents du texte enregistré",
    "{count} ancien(s) rappel(s) de schéma v2 sont interprétés en mode minimal / anglais pour l’aperçu seulement.",
    "Cet aperçu ne demande aucune autorisation de notification et ne crée aucun rappel système. L’appareil cible doit revérifier ses capacités, sa langue et ses réglages de confidentialité avant votre accord explicite à la planification ; les jetons source et identifiants de notification ne sont jamais réutilisés.",
    "Champs non pris en charge",
    "Garantie de l’aperçu : cette opération n’a modifié aucune donnée durable.",
    "Le compte ou l’appareil actuel n’est pas disponible.",
    "Le compte a changé pendant l’opération. Le paquet, le texte et l’aperçu ont été effacés.",
    "Impossible de générer le paquet",
    "Impossible de copier le paquet. Aucun fichier n’a été enregistré.",
    "Impossible d’enregistrer le paquet",
    "Collez ou sélectionnez d’abord un paquet.",
    "L’entrée dépasse la taille maximale du paquet ; elle n’a pas été chargée ni analysée.",
    "Impossible d’inspecter le paquet en toute sécurité. Aucune donnée n’a été écrite.",
    "Le presse-papiers ne contient aucun texte utilisable.",
    "L’enregistrement direct n’est pas disponible sur cette plateforme. Utilisez plutôt Copier le JSON.",
    "L’enregistrement direct n’est pas disponible. Le JSON a été copié ; aucun fichier n’est déclaré enregistré.",
    "L’enregistrement direct a échoué. Le JSON a été copié ; l’enregistrement d’un nouveau fichier n’a pas été confirmé.",
    "L’enregistrement direct a échoué et le JSON a été copié. Le nettoyage du fichier temporaire n’a pas pu être confirmé ; vérifiez les téléchargements.",
    "L’enregistrement et la copie ont échoué. Le nettoyage du fichier temporaire n’a pas pu être confirmé ; vérifiez les téléchargements.",
    "Paquet enregistré dans {location}.",
    "Un téléchargement par le navigateur a été demandé. Vérifiez que le fichier apparaît dans vos téléchargements.",
    "Paquet enregistré dans les documents de l’application à {location}. Utilisez Copier le JSON pour en conserver aussi une copie externe.",
    "téléchargements du navigateur",
  ],
  'ja': [
    "持ち運び可能なデータパッケージ",
    "これは暗号化されていない機微なデータのコピーです",
    "このパッケージには、食事、服薬記録、用量メモ、リマインダーの文章が含まれる場合があります。自分で管理できる場所にのみ保存してください。SHA-256 は変更を検出しますが、内容を暗号化したり隠したりはしません。",
    "この機能は、ユーザーが読める JSON と書き込みを行わないインポートプレビューを作成します。アカウントの削除、データの復元、法令遵守の証明は行いません。ローカルアカウントとの結び付けにはこの端末に保存されたランダムトークンを使うため、別の端末では検証できない場合があります。",
    "持ち運び可能なスキーマの差分テスト範囲",
    "生成器 v1 · 固定シード {seeds} 件 · 字句/意味パーティション {partitions} 件 · コーパス単位のプライバシーレビュー対象となった合成回帰ケース {cases} 件 · ランタイム {runtimes} 種類。",
    "設定済みのオフラインゲート：{runtime}。Node はアプリ内では実行されません。",
    "本番前チェックは、重複メンバー、孤立サロゲート、Unicode の非文字、およびパッケージ、ノード、深さ、幅、元/復号後の文字列、キー、数値トークンの各上限を超える入力を拒否します。固定差分テストでは、複合エラーの優先順位、一意なマニフェスト一覧、整合性契約も確認します。",
    "これはコンパイル済みの範囲を示すもので、最近この端末で実行した証明ではありません。時間しきい値は処理の戻り後にのみ確認され、停止したパーサーを中断できません。ランタイム間の縮小再生と、ブラウザー、Android、iOS、デスクトップのリリース成果物に含まれるパーサーは未検証です。",
    "現在のデータスナップショットを作成",
    "現在読み込まれているプロフィール、設定、薬の選択、服薬記録、食事、この端末のリマインダー、関連リンクをエクスポートします。UID、メールアドレス、リマインダー有効化トークン、ローカル AI のエンドポイントは含みません。ドメイン分離された一方向の所有者結び付けは仮名化であり、匿名化ではありません。",
    "生成して自己チェック",
    "整合性の自己チェックに合格しました",
    "構造化ファイル {count} 件",
    "{count} バイト",
    "ローカル権限の保護 {protection}",
    "権限のリビジョン {revision}",
    "以前のローカルトークンを検証して移行し、削除しました",
    "ローカルエクスポート ID を更新",
    "ローカルエクスポート ID を更新しますか？",
    "新しい端末バインド権限を作成します。以前に作成したパッケージは、このローカルアカウントの所有者検証を通過しなくなります。パッケージ内容は変更されず、この操作は取り消せません。",
    "更新して現在のパッケージを消去",
    "ローカルエクスポート ID を更新しました。現在のパッケージとプレビューを消去しました。",
    "ローカルエクスポート ID を安全に更新できませんでした。既存の ID を引き続き使用します。",
    "JSON をコピー",
    "パッケージを保存",
    "パッケージの JSON をコピーしました。保護された場所に保存してください。",
    "インポートプレビュー（書き込みなし）",
    "ParkinSUM パッケージを貼り付けると、形式、バージョン、所有者との結び付け、チェックサム、件数、競合、未対応フィールドを確認できます。このバージョンではインポートを実行しません。",
    "パッケージ JSON",
    "クリップボードから貼り付け",
    "生成したパッケージを使用",
    "書き込みなしのプレビューを実行",
    "将来の管理されたインポート手順に備えています",
    "アカウントまたは端末の範囲が一致しません",
    "パッケージスキーマは未対応です",
    "パッケージが破損しているか無効です",
    "記録 {records} 件 · 競合 {conflicts} 件 · 未対応フィールド {unsupported} 件",
    "固定スキーマの検証と移行の証明",
    "元 v{source} → 先 v{target} · 判定：{decision}",
    "証明 {receipt}… · 元の検証器 {validator}…",
    "この証明が示すのは、決定論的なローカル検証/プレビューのみです。書き込み、スケジュール設定、ネットワーク通信は行わず、発行者の本人性や臨床的正確性も証明しません。",
    "リマインダー表示意図のプレビュー",
    "リマインダープラン {total} 件 · 元の端末で有効 {enabled} 件 · {consent} 件は移行先端末でのスケジュール前に明示的な同意が必要です。",
    "プライバシーモード：{modes} · 保存された通知言語：{languages}",
    "現在の文面ポリシーと一致 {match} 件 · 再計算が必要 {drift} 件 · 保存文面と言語選択が異なる {decisions} 件",
    "以前のスキーマ v2 のリマインダー {count} 件は、プレビューに限り最小モード / 英語として解釈されます。",
    "このプレビューは通知の許可を求めず、システムリマインダーも作成しません。移行先端末では、あなたが明示的にスケジュールを承認する前に、機能、言語、プライバシー設定を再確認する必要があります。元の端末のトークンと通知 ID は再利用しません。",
    "未対応フィールド",
    "プレビューの保証：この操作では永続データは変更されていません。",
    "現在のアカウントまたは端末の範囲を利用できません。",
    "操作中にアカウントが変更されました。パッケージ、テキスト、プレビューを消去しました。",
    "パッケージを生成できませんでした",
    "パッケージをコピーできませんでした。ファイルは保存されていません。",
    "パッケージを保存できませんでした",
    "先にパッケージを貼り付けるか選択してください。",
    "入力がパッケージのサイズ上限を超えています。読み込みも解析も行われませんでした。",
    "パッケージを安全に検査できませんでした。データは書き込まれていません。",
    "クリップボードに使用できるテキストがありません。",
    "このプラットフォームでは直接保存できません。代わりに JSON をコピーしてください。",
    "直接保存は利用できません。JSON をコピーしましたが、ファイルを保存したとは扱いません。",
    "直接保存に失敗しました。JSON をコピーしましたが、新しいファイルの保存は確認できていません。",
    "直接保存に失敗し、JSON をコピーしました。一時ファイルの削除を確認できません。ダウンロードを確認してください。",
    "保存とコピーの両方に失敗しました。一時ファイルの削除を確認できません。ダウンロードを確認してください。",
    "パッケージを {location} に保存しました。",
    "ブラウザーにダウンロードを要求しました。ダウンロード一覧にファイルが表示されたことを確認してください。",
    "パッケージをアプリのドキュメント {location} に保存しました。外部のコピーも必要な場合は JSON をコピーしてください。",
    "ブラウザーのダウンロード",
  ],
  'ko': [
    "내보낼 수 있는 데이터 패키지",
    "암호화되지 않은 민감 데이터 사본입니다",
    "패키지에는 식사, 복약 기록, 용량 메모, 알림 문구가 들어 있을 수 있습니다. 본인이 관리하는 위치에만 저장하세요. SHA-256은 변경을 감지하지만 내용을 암호화하거나 숨기지는 않습니다.",
    "이 기능은 사용자가 읽을 수 있는 JSON과 쓰기 없는 가져오기 미리보기만 만듭니다. 계정을 삭제하거나 데이터를 복원하거나 법률 준수를 인증하지 않습니다. 로컬 계정 연결에는 이 기기에 보관되는 무작위 토큰을 사용하므로 다른 기기에서는 검증되지 않을 수 있습니다.",
    "이동 가능한 스키마 차등 테스트 범위",
    "생성기 v1 · 고정 시드 {seeds}개 · 어휘/의미 파티션 {partitions}개 · 코퍼스 개인정보 검토 대상 합성 회귀 사례 {cases}개 · 런타임 {runtimes}개.",
    "설정된 오프라인 게이트: {runtime}. Node는 앱 안에서 실행되지 않습니다.",
    "프로덕션 사전 검사는 중복 항목, 고립 서로게이트, Unicode 비문자와 패키지·노드·깊이·너비·원본/디코딩 문자열·키·숫자 토큰 한도를 넘는 입력을 거부합니다. 고정 차등 테스트는 복합 오류 우선순위, 고유 매니페스트 목록, 무결성 계약도 다룹니다.",
    "이는 컴파일된 범위 설명이지 이 기기에서 최근 실행한 기록이 아닙니다. 소요 시간 한도는 파서가 반환한 뒤에만 확인하므로 멈춘 파서를 종료하지 못합니다. 런타임 간 축소 재생과 브라우저·Android·iOS·데스크톱 릴리스 산출물 파서는 검증되지 않았습니다.",
    "현재 데이터 스냅샷 만들기",
    "현재 로드된 프로필, 환경설정, 약 선택, 복약 기록, 식사, 이 기기의 알림 계획, 관계 링크를 내보냅니다. UID, 이메일, 알림 활성화 토큰, 로컬 AI 엔드포인트는 제외됩니다. 도메인 분리 단방향 소유자 연결은 가명 처리이며 익명화가 아닙니다.",
    "생성 후 자체 확인",
    "무결성 자체 확인 통과",
    "구조화된 파일 {count}개",
    "{count}바이트",
    "로컬 권한 보호 {protection}",
    "권한 리비전 {revision}",
    "이전 로컬 토큰을 검증하고 이전한 뒤 삭제했습니다",
    "로컬 내보내기 ID 바꾸기",
    "로컬 내보내기 ID를 바꿀까요?",
    "새 기기 바인딩 권한을 만듭니다. 이전에 만든 패키지는 이 로컬 계정의 소유자 검증을 통과하지 못합니다. 패키지 내용은 바뀌지 않으며 이 작업은 취소할 수 없습니다.",
    "바꾸고 현재 패키지 지우기",
    "로컬 내보내기 ID를 바꿨습니다. 현재 패키지와 미리보기를 지웠습니다.",
    "로컬 내보내기 ID를 안전하게 바꾸지 못했습니다. 기존 ID를 계속 사용합니다.",
    "JSON 복사",
    "패키지 저장",
    "패키지 JSON을 복사했습니다. 보호된 위치에 저장하세요.",
    "가져오기 미리보기 (저장하지 않음)",
    "ParkinSUM 패키지를 붙여넣어 형식, 버전, 소유자 연결, 체크섬, 개수, 충돌, 지원하지 않는 필드를 확인합니다. 현재 버전은 가져오기를 수행하지 않습니다.",
    "패키지 JSON",
    "클립보드에서 붙여넣기",
    "생성한 패키지 사용",
    "저장하지 않는 미리보기 실행",
    "향후 통제된 가져오기 절차를 위한 준비가 되었습니다",
    "계정 또는 기기 범위가 일치하지 않습니다",
    "지원하지 않는 패키지 스키마입니다",
    "패키지가 손상되었거나 유효하지 않습니다",
    "기록 {records}개 · 충돌 {conflicts}개 · 지원하지 않는 필드 {unsupported}개",
    "고정 스키마 검증 및 이전 증명서",
    "원본 v{source} → 대상 v{target} · 결정: {decision}",
    "증명서 {receipt}… · 원본 검증기 {validator}…",
    "이 증명은 결정적인 로컬 검증/미리보기만 입증합니다. 저장, 예약, 네트워크 작업은 하지 않으며 발행자 신원이나 임상적 정확성을 입증하지 않습니다.",
    "알림 표시 의도 미리보기",
    "알림 계획 {total}개 · 원본에서 활성화 {enabled}개 · {consent}개는 대상 기기에서 예약하기 전에 명시적 동의가 필요합니다.",
    "개인정보 보호 모드: {modes} · 저장된 알림 언어: {languages}",
    "현재 문구 정책과 일치 {match}개 · 다시 계산 필요 {drift}개 · 저장 문구와 언어 선택이 다른 항목 {decisions}개",
    "이전 스키마 v2 알림 {count}개는 미리보기에서만 최소 / 영어로 해석합니다.",
    "이 미리보기는 알림 권한을 요청하거나 시스템 알림을 만들지 않습니다. 대상 기기에서 기능, 언어, 개인정보 설정을 다시 확인한 뒤 사용자가 명시적으로 예약을 승인해야 합니다. 원본 토큰과 알림 ID는 재사용하지 않습니다.",
    "지원하지 않는 필드",
    "미리보기 보장: 이 작업은 영구 저장 데이터를 변경하지 않았습니다.",
    "현재 계정 또는 기기 범위를 사용할 수 없습니다.",
    "작업 중 계정이 바뀌었습니다. 패키지, 텍스트, 미리보기를 지웠습니다.",
    "패키지를 만들 수 없습니다",
    "패키지를 복사할 수 없습니다. 파일은 저장되지 않았습니다.",
    "패키지를 저장할 수 없습니다",
    "먼저 패키지를 붙여넣거나 선택하세요.",
    "입력이 패키지 크기 한도를 넘었습니다. 불러오거나 파싱하지 않았습니다.",
    "패키지를 안전하게 검사하지 못했습니다. 데이터는 저장되지 않았습니다.",
    "클립보드에 사용할 수 있는 텍스트가 없습니다.",
    "이 플랫폼에서는 직접 저장할 수 없습니다. 대신 JSON 복사를 사용하세요.",
    "직접 저장을 사용할 수 없습니다. JSON은 복사했으며 파일을 저장했다고 표시하지 않습니다.",
    "직접 저장에 실패했습니다. JSON은 복사했지만 새 파일 저장은 확인되지 않았습니다.",
    "직접 저장에 실패하고 JSON을 복사했습니다. 임시 파일 정리를 확인할 수 없습니다. 다운로드 폴더를 확인하세요.",
    "저장과 복사가 모두 실패했습니다. 임시 파일 정리를 확인할 수 없습니다. 다운로드 폴더를 확인하세요.",
    "패키지를 {location}에 저장했습니다.",
    "브라우저 다운로드를 요청했습니다. 다운로드 목록에 파일이 표시되는지 확인하세요.",
    "패키지를 앱 문서 {location}에 저장했습니다. 외부 사본도 필요하면 JSON을 복사하세요.",
    "브라우저 다운로드",
  ],
  'hi': [
    "पोर्टेबल डेटा पैकेज",
    "यह बिना एन्क्रिप्शन की संवेदनशील डेटा प्रति है",
    "पैकेज में भोजन, दवा-सेवन लॉग, खुराक नोट और रिमाइंडर का पाठ हो सकता है। इसे केवल ऐसी जगह सहेजें जिसे आप नियंत्रित करते हैं। SHA-256 बदलाव पहचानता है; यह सामग्री को एन्क्रिप्ट या छिपाता नहीं है।",
    "यह सुविधा उपयोगकर्ता-पठनीय JSON और बिना लिखे आयात पूर्वावलोकन बनाती है। यह खाता नहीं हटाती, डेटा पुनर्स्थापित नहीं करती और कानूनी अनुपालन प्रमाणित नहीं करती। स्थानीय खाते का बंधन इस डिवाइस पर रखे यादृच्छिक टोकन का उपयोग करता है, इसलिए दूसरा डिवाइस इसे सत्यापित न कर पाए।",
    "पोर्टेबल स्कीमा अंतर-परीक्षण सीमा",
    "जनरेटर v1 · {seeds} स्थिर बीज · {partitions} शब्द-रूप/अर्थ विभाजन · कॉर्पस-स्तरीय गोपनीयता समीक्षा वाले {cases} सिंथेटिक प्रतिगमन मामले · {runtimes} रनटाइम।",
    "कॉन्फ़िगर किया गया ऑफलाइन गेट: {runtime}। Node ऐप के भीतर नहीं चलता।",
    "प्रोडक्शन पूर्व-जाँच दोहराए गए सदस्य, अलग surrogate, Unicode noncharacter और पैकेज, नोड, गहराई, चौड़ाई, स्रोत/डिकोड की गई स्ट्रिंग, कुंजी या संख्या-टोकन की सीमा से बड़े इनपुट अस्वीकार करती है। स्थिर अंतर-परीक्षण संयुक्त त्रुटि प्राथमिकता, अद्वितीय manifest सूची और अखंडता अनुबंध भी जाँचता है।",
    "यह संकलित दायरे का विवरण है, इस डिवाइस पर हाल के निष्पादन की रसीद नहीं। समय-सीमा parser लौटने के बाद ही जाँची जाती है और अटके parser को रोक नहीं सकती। रनटाइम के बीच न्यूनतम पुनरावृत्ति तथा browser, Android, iOS और desktop रिलीज़ आर्टिफ़ैक्ट parser अभी सत्यापित नहीं हैं।",
    "वर्तमान डेटा स्नैपशॉट बनाएँ",
    "वर्तमान में लोड की गई प्रोफ़ाइल, प्राथमिकताएँ, दवा चयन, सेवन, भोजन, इस डिवाइस के रिमाइंडर और संबंध लिंक निर्यात करता है। UID, ईमेल, रिमाइंडर सक्रियण टोकन और स्थानीय AI endpoint शामिल नहीं होते। डोमेन-विभाजित एक-तरफ़ा स्वामी बंधन छद्मनाम है, गुमनाम नहीं।",
    "बनाएँ और स्वयं जाँचें",
    "अखंडता की स्वयं-जाँच सफल",
    "{count} संरचित फ़ाइलें",
    "{count} बाइट",
    "स्थानीय क्षमता सुरक्षा {protection}",
    "क्षमता संशोधन {revision}",
    "पुराना स्थानीय टोकन सत्यापित और स्थानांतरित करके हटाया गया",
    "स्थानीय निर्यात पहचान बदलें",
    "स्थानीय निर्यात पहचान बदलें?",
    "यह नई डिवाइस-बद्ध क्षमता बनाता है। पहले बनाए गए पैकेज इस स्थानीय खाते के स्वामी सत्यापन में सफल नहीं होंगे। इससे पैकेज की सामग्री नहीं बदलती और इसे वापस नहीं लिया जा सकता।",
    "बदलें और वर्तमान पैकेज साफ़ करें",
    "स्थानीय निर्यात पहचान बदली गई। वर्तमान पैकेज और पूर्वावलोकन साफ़ किए गए।",
    "स्थानीय निर्यात पहचान सुरक्षित रूप से नहीं बदली जा सकी। मौजूदा पहचान बनी रहेगी।",
    "JSON कॉपी करें",
    "पैकेज सहेजें",
    "पैकेज JSON कॉपी किया गया। इसे सुरक्षित स्थान पर सहेजें।",
    "आयात पूर्वावलोकन (कोई लेखन नहीं)",
    "ParkinSUM पैकेज चिपकाकर प्रारूप, संस्करण, स्वामी बंधन, checksum, गिनती, टकराव और असमर्थित फ़ील्ड जाँचें। यह संस्करण आयात नहीं करता।",
    "पैकेज JSON",
    "क्लिपबोर्ड से चिपकाएँ",
    "बनाया गया पैकेज उपयोग करें",
    "बिना लिखे पूर्वावलोकन चलाएँ",
    "भविष्य की नियंत्रित आयात प्रक्रिया के लिए तैयार",
    "खाता या डिवाइस दायरा मेल नहीं खाता",
    "पैकेज स्कीमा समर्थित नहीं है",
    "पैकेज क्षतिग्रस्त या अमान्य है",
    "{records} रिकॉर्ड · {conflicts} टकराव · {unsupported} असमर्थित फ़ील्ड",
    "स्थिर स्कीमा सत्यापन और माइग्रेशन रसीद",
    "स्रोत v{source} → लक्ष्य v{target} · निर्णय: {decision}",
    "रसीद {receipt}… · स्रोत validator {validator}…",
    "यह रसीद केवल निर्धारक स्थानीय सत्यापन/पूर्वावलोकन सिद्ध करती है। यह लिखती, शेड्यूल करती या नेटवर्क से जुड़ती नहीं, और जारीकर्ता की पहचान या नैदानिक शुद्धता सिद्ध नहीं करती।",
    "रिमाइंडर प्रस्तुति-इरादे का पूर्वावलोकन",
    "{total} रिमाइंडर योजनाएँ · स्रोत पर सक्षम {enabled} · {consent} के लिए लक्ष्य डिवाइस पर शेड्यूल करने से पहले स्पष्ट सहमति चाहिए।",
    "गोपनीयता मोड: {modes} · सहेजी गई सूचना भाषाएँ: {languages}",
    "वर्तमान कॉपी नीति से मेल {match} · पुनर्गणना चाहिए {drift} · सहेजी कॉपी से भाषा निर्णय अलग {decisions}",
    "पुराने स्कीमा v2 के {count} रिमाइंडर केवल पूर्वावलोकन में न्यूनतम / English माने जाते हैं।",
    "यह पूर्वावलोकन सूचना अनुमति नहीं माँगता और सिस्टम रिमाइंडर नहीं बनाता। लक्ष्य डिवाइस को शेड्यूलिंग के लिए आपकी स्पष्ट स्वीकृति से पहले क्षमता, भाषा और गोपनीयता फिर जाँचनी होगी; स्रोत टोकन और सूचना ID दोबारा उपयोग नहीं होते।",
    "असमर्थित फ़ील्ड",
    "पूर्वावलोकन आश्वासन: इस कार्रवाई ने कोई स्थायी डेटा नहीं बदला।",
    "वर्तमान खाता या डिवाइस दायरा उपलब्ध नहीं है।",
    "कार्रवाई के दौरान खाता बदल गया। पैकेज, पाठ और पूर्वावलोकन साफ़ कर दिए गए।",
    "पैकेज नहीं बनाया जा सका",
    "पैकेज कॉपी नहीं किया जा सका। कोई फ़ाइल सहेजी नहीं गई।",
    "पैकेज सहेजा नहीं जा सका",
    "पहले कोई पैकेज चिपकाएँ या चुनें।",
    "इनपुट पैकेज आकार सीमा से बड़ा है; इसे लोड या पार्स नहीं किया गया।",
    "पैकेज को सुरक्षित रूप से जाँचा नहीं जा सका। कोई डेटा नहीं लिखा गया।",
    "क्लिपबोर्ड में उपयोग योग्य पाठ नहीं है।",
    "इस प्लेटफ़ॉर्म पर सीधे सहेजना उपलब्ध नहीं है। इसके बजाय JSON कॉपी करें।",
    "सीधा सहेजना उपलब्ध नहीं है। JSON कॉपी किया गया; फ़ाइल सहेजी गई होने का दावा नहीं है।",
    "सीधा सहेजना विफल हुआ। JSON कॉपी किया गया; नई फ़ाइल का सहेजा जाना पुष्ट नहीं है।",
    "सीधा सहेजना विफल हुआ और JSON कॉपी किया गया। अस्थायी फ़ाइल की सफ़ाई पुष्ट नहीं हो सकी; Downloads जाँचें।",
    "सहेजना और कॉपी करना दोनों विफल हुए। अस्थायी फ़ाइल की सफ़ाई पुष्ट नहीं हो सकी; Downloads जाँचें।",
    "पैकेज {location} में सहेजा गया।",
    "ब्राउज़र डाउनलोड का अनुरोध किया गया। पुष्टि करें कि फ़ाइल डाउनलोड सूची में दिखती है।",
    "पैकेज ऐप दस्तावेज़ों में {location} पर सहेजा गया। बाहरी प्रति भी चाहिए तो JSON कॉपी करें।",
    "ब्राउज़र डाउनलोड",
  ],
  'es': [
    "Mi paquete de datos portátil",
    "Esta es una copia sensible sin cifrar",
    "El paquete puede incluir comidas, registros de medicación, notas de dosis y texto de recordatorios. Guárdelo únicamente en un lugar que usted controle. SHA-256 detecta cambios; no cifra ni oculta el contenido.",
    "Esta función crea JSON legible por el usuario y una vista previa de importación sin escrituras. No elimina cuentas, restaura datos ni certifica el cumplimiento legal. La vinculación a la cuenta local usa un token aleatorio guardado en este dispositivo, por lo que otro dispositivo quizá no pueda validarlo.",
    "Límite de la prueba diferencial del esquema portátil",
    "Generador v1 · {seeds} semillas fijas · {partitions} particiones léxicas/semánticas · {cases} casos sintéticos de regresión con revisión de privacidad del corpus · {runtimes} entornos de ejecución.",
    "Control sin conexión configurado: {runtime}. Node no se ejecuta dentro de la aplicación.",
    "La comprobación previa de producción rechaza miembros duplicados, sustitutos aislados, no caracteres Unicode y entradas que superen los límites de tamaño del paquete, nodos, profundidad, anchura, cadenas de origen/decodificadas, claves o tokens numéricos. La campaña diferencial fija también cubre la prioridad de errores combinados, el inventario único del manifiesto y el contrato de integridad.",
    "Esto describe el alcance compilado, no un comprobante de ejecución reciente en este dispositivo. El umbral de tiempo se comprueba solo al regresar y no puede detener un analizador bloqueado. La reducción de casos entre entornos y los analizadores de artefactos de navegador, Android, iOS y escritorio no se han verificado.",
    "Crear una instantánea de los datos actuales",
    "Exporta el perfil cargado actualmente, preferencias, selecciones de medicamentos, tomas, comidas, recordatorios de este dispositivo y vínculos entre registros. Excluye UID, correo, tokens de activación de recordatorios y endpoints de IA local. La vinculación unidireccional con separación por dominio es seudónima, no anónima.",
    "Generar y comprobar",
    "Comprobación de integridad superada",
    "{count} archivos estructurados",
    "{count} bytes",
    "Protección de capacidad local {protection}",
    "Revisión de capacidad {revision}",
    "El token local anterior se verificó, migró y eliminó",
    "Rotar la identidad de exportación local",
    "¿Rotar la identidad de exportación local?",
    "Esto crea una nueva capacidad vinculada al dispositivo. Los paquetes anteriores ya no superarán la validación de propietario para esta cuenta local. No cambia el contenido del paquete y no se puede deshacer.",
    "Rotar y borrar el paquete actual",
    "Identidad de exportación local rotada. Se borraron el paquete y la vista previa actuales.",
    "No se pudo rotar de forma segura la identidad local. Se conserva la identidad existente.",
    "Copiar JSON",
    "Guardar paquete",
    "Se copió el JSON del paquete. Guárdelo en una ubicación protegida.",
    "Vista previa de importación (sin escrituras)",
    "Pegue un paquete ParkinSUM para comprobar el formato, la versión, la vinculación del propietario, las sumas de comprobación, los recuentos, los conflictos y los campos no admitidos. Esta versión no realiza la importación.",
    "JSON del paquete",
    "Pegar desde el portapapeles",
    "Usar el paquete generado",
    "Ejecutar vista previa sin escrituras",
    "Preparado para un futuro proceso de importación controlada",
    "La cuenta o el dispositivo no coinciden",
    "El esquema del paquete no es compatible",
    "El paquete está dañado o no es válido",
    "{records} registros · {conflicts} conflictos · {unsupported} campos no admitidos",
    "Recibo de validación y migración de esquema congelado",
    "Origen v{source} → destino v{target} · decisión: {decision}",
    "Recibo {receipt}… · validador de origen {validator}…",
    "Este recibo demuestra únicamente validación/vista previa local determinista. No escribe, programa ni usa la red, y no demuestra la identidad del emisor ni la corrección clínica.",
    "Vista previa de la intención de presentación de recordatorios",
    "{total} planes de recordatorio · {enabled} habilitados en el origen · {consent} requieren consentimiento explícito en el dispositivo de destino antes de programarse.",
    "Modos de privacidad: {modes} · idiomas guardados de notificación: {languages}",
    "{match} coinciden con la política de texto actual · {drift} requieren recálculo · {decisions} decisiones de idioma difieren del texto guardado",
    "Los {count} recordatorios antiguos de esquema v2 se interpretan como mínimos / English solo para la vista previa.",
    "Esta vista previa no solicita permisos de notificación ni crea recordatorios del sistema. El dispositivo de destino debe volver a comprobar capacidad, idioma y privacidad antes de que usted autorice explícitamente la programación; nunca se reutilizan tokens ni ID de notificación del origen.",
    "Campos no admitidos",
    "Garantía de la vista previa: esta operación no modificó datos persistentes.",
    "La cuenta o el dispositivo actual no están disponibles.",
    "La cuenta cambió durante la operación. Se borraron el paquete, el texto y la vista previa.",
    "No se pudo generar el paquete",
    "No se pudo copiar el paquete. No se guardó ningún archivo.",
    "No se pudo guardar el paquete",
    "Pegue o seleccione primero un paquete.",
    "La entrada supera el límite de tamaño del paquete y no se cargó ni analizó.",
    "No se pudo inspeccionar el paquete de forma segura. No se escribió ningún dato.",
    "El portapapeles no contiene texto utilizable.",
    "El guardado directo no está disponible en esta plataforma. Use Copiar JSON.",
    "El guardado directo no está disponible. Se copió el JSON; no se afirma que se haya guardado un archivo.",
    "Falló el guardado directo. Se copió el JSON; no se confirmó que se guardara un archivo nuevo.",
    "Falló el guardado directo y se copió el JSON. No se pudo confirmar la limpieza del archivo temporal; revise Descargas.",
    "Fallaron tanto el guardado como la copia. No se pudo confirmar la limpieza del archivo temporal; revise Descargas.",
    "Paquete guardado en {location}.",
    "Se solicitó una descarga del navegador. Confirme que el archivo aparezca en sus descargas.",
    "Paquete guardado en los documentos de la aplicación en {location}. Use Copiar JSON si también necesita una copia externa.",
    "descargas del navegador",
  ],
  'vi': [
    "Gói dữ liệu di động của tôi",
    "Đây là bản sao dữ liệu nhạy cảm chưa được mã hóa",
    "Gói có thể chứa bữa ăn, nhật ký dùng thuốc, ghi chú liều và nội dung nhắc nhở. Chỉ lưu ở nơi bạn kiểm soát. SHA-256 phát hiện thay đổi; nó không mã hóa hay che giấu nội dung.",
    "Tính năng này tạo JSON người dùng có thể đọc và bản xem trước nhập không ghi dữ liệu. Tính năng không xóa tài khoản, khôi phục dữ liệu hay chứng nhận tuân thủ pháp luật. Liên kết với tài khoản cục bộ dùng mã thông báo ngẫu nhiên lưu trên thiết bị này, nên thiết bị khác có thể không xác minh được.",
    "Phạm vi kiểm thử khác biệt lược đồ di động",
    "Bộ tạo v1 · {seeds} hạt giống cố định · {partitions} phân vùng từ vựng/ngữ nghĩa · {cases} ca hồi quy tổng hợp được rà soát quyền riêng tư ở cấp bộ dữ liệu · {runtimes} môi trường chạy.",
    "Cổng ngoại tuyến đã cấu hình: {runtime}. Node không chạy bên trong ứng dụng.",
    "Kiểm tra trước khi chạy từ chối thành viên trùng lặp, surrogate đơn lẻ, ký tự Unicode phi ký tự và đầu vào vượt giới hạn kích thước gói, nút, độ sâu, độ rộng, chuỗi nguồn/đã giải mã, khóa hoặc token số. Bộ kiểm thử khác biệt cố định cũng bao phủ thứ tự ưu tiên lỗi kết hợp, danh mục manifest duy nhất và hợp đồng toàn vẹn.",
    "Đây là phạm vi đã biên dịch, không phải biên nhận chạy gần đây trên thiết bị này. Ngưỡng thời gian chỉ được kiểm tra sau khi parser trả về và không thể dừng parser bị treo. Việc thu nhỏ chạy lại giữa các môi trường và parser trong bản phát hành trình duyệt, Android, iOS, máy tính để bàn vẫn chưa được xác minh.",
    "Tạo ảnh chụp dữ liệu hiện tại",
    "Xuất hồ sơ đã tải, tùy chọn, lựa chọn thuốc, lần dùng thuốc, bữa ăn, nhắc nhở trên thiết bị này và liên kết quan hệ. Không bao gồm UID, email, token kích hoạt nhắc nhở hoặc endpoint AI cục bộ. Liên kết chủ sở hữu một chiều, tách miền là bí danh chứ không phải ẩn danh.",
    "Tạo và tự kiểm tra",
    "Kiểm tra toàn vẹn đạt",
    "{count} tệp có cấu trúc",
    "{count} byte",
    "Bảo vệ quyền cục bộ {protection}",
    "Bản sửa đổi quyền {revision}",
    "Token cục bộ cũ đã được xác minh, chuyển đổi và xóa",
    "Xoay vòng danh tính xuất cục bộ",
    "Xoay vòng danh tính xuất cục bộ?",
    "Thao tác này tạo quyền mới gắn với thiết bị. Gói đã tạo trước đây sẽ không vượt qua xác minh chủ sở hữu cho tài khoản cục bộ này. Nội dung gói không đổi và thao tác không thể hoàn tác.",
    "Xoay vòng và xóa gói hiện tại",
    "Đã xoay vòng danh tính xuất cục bộ. Gói và bản xem trước hiện tại đã bị xóa.",
    "Không thể xoay vòng danh tính cục bộ một cách an toàn. Danh tính hiện tại vẫn được dùng.",
    "Sao chép JSON",
    "Lưu gói",
    "Đã sao chép JSON của gói. Hãy lưu tại nơi được bảo vệ.",
    "Bản xem trước nhập (không ghi dữ liệu)",
    "Dán gói ParkinSUM để kiểm tra định dạng, phiên bản, liên kết chủ sở hữu, checksum, số lượng, xung đột và trường không hỗ trợ. Phiên bản này không thực hiện nhập dữ liệu.",
    "JSON của gói",
    "Dán từ bảng nhớ tạm",
    "Dùng gói đã tạo",
    "Chạy bản xem trước không ghi dữ liệu",
    "Sẵn sàng cho quy trình nhập có kiểm soát trong tương lai",
    "Phạm vi tài khoản hoặc thiết bị không khớp",
    "Lược đồ gói không được hỗ trợ",
    "Gói bị hỏng hoặc không hợp lệ",
    "{records} bản ghi · {conflicts} xung đột · {unsupported} trường không hỗ trợ",
    "Biên nhận xác thực và di chuyển lược đồ cố định",
    "Nguồn v{source} → đích v{target} · quyết định: {decision}",
    "Biên nhận {receipt}… · bộ xác thực nguồn {validator}…",
    "Biên nhận này chỉ chứng minh việc xác thực/xem trước cục bộ có tính xác định. Không ghi dữ liệu, lập lịch hay kết nối mạng, và không chứng minh danh tính bên phát hành hoặc tính chính xác lâm sàng.",
    "Bản xem trước ý định hiển thị nhắc nhở",
    "{total} kế hoạch nhắc nhở · {enabled} được bật ở nguồn · {consent} cần sự đồng ý rõ ràng trên thiết bị đích trước khi lập lịch.",
    "Chế độ riêng tư: {modes} · ngôn ngữ thông báo đã lưu: {languages}",
    "{match} khớp chính sách nội dung hiện tại · {drift} cần tính lại · {decisions} lựa chọn ngôn ngữ khác nội dung đã lưu",
    "{count} nhắc nhở lược đồ v2 cũ chỉ được diễn giải là tối thiểu / tiếng Anh trong bản xem trước.",
    "Bản xem trước này không yêu cầu quyền thông báo và không tạo nhắc nhở hệ thống. Thiết bị đích phải kiểm tra lại khả năng, ngôn ngữ và quyền riêng tư trước khi bạn đồng ý rõ ràng cho việc lập lịch; token nguồn và ID thông báo không bao giờ được dùng lại.",
    "Trường không hỗ trợ",
    "Cam kết của bản xem trước: thao tác này không thay đổi dữ liệu bền vững.",
    "Không có phạm vi tài khoản hoặc thiết bị hiện tại.",
    "Tài khoản đã thay đổi trong khi thao tác. Đã xóa gói, văn bản và bản xem trước.",
    "Không thể tạo gói",
    "Không thể sao chép gói. Không có tệp nào được lưu.",
    "Không thể lưu gói",
    "Trước tiên hãy dán hoặc chọn một gói.",
    "Đầu vào vượt giới hạn kích thước gói và chưa được tải hoặc phân tích.",
    "Không thể kiểm tra gói một cách an toàn. Không có dữ liệu nào được ghi.",
    "Bảng nhớ tạm không có văn bản có thể dùng.",
    "Nền tảng này không hỗ trợ lưu trực tiếp. Hãy dùng Sao chép JSON.",
    "Không thể lưu trực tiếp. JSON đã được sao chép; không khẳng định tệp đã được lưu.",
    "Lưu trực tiếp thất bại. JSON đã được sao chép; chưa xác nhận tệp mới đã lưu.",
    "Lưu trực tiếp thất bại và JSON đã được sao chép. Không xác nhận được việc dọn tệp tạm; hãy kiểm tra mục Tải xuống.",
    "Cả lưu lẫn sao chép đều thất bại. Không xác nhận được việc dọn tệp tạm; hãy kiểm tra mục Tải xuống.",
    "Đã lưu gói tại {location}.",
    "Đã yêu cầu trình duyệt tải xuống. Hãy xác nhận tệp xuất hiện trong danh sách tải xuống.",
    "Đã lưu gói trong tài liệu ứng dụng tại {location}. Dùng Sao chép JSON nếu bạn cũng cần bản sao bên ngoài.",
    "mục tải xuống của trình duyệt",
  ],
  'th': [
    "แพ็กเกจข้อมูลพกพาของฉัน",
    "นี่คือสำเนาข้อมูลอ่อนไหวที่ไม่ได้เข้ารหัส",
    "แพ็กเกจอาจมีข้อมูลมื้ออาหาร บันทึกการใช้ยา โน้ตขนาดยา และข้อความเตือนความจำ โปรดบันทึกไว้เฉพาะในตำแหน่งที่คุณควบคุมได้ SHA-256 ตรวจจับการเปลี่ยนแปลง แต่ไม่ได้เข้ารหัสหรือซ่อนเนื้อหา",
    "ฟีเจอร์นี้สร้าง JSON ที่ผู้ใช้อ่านได้และหน้าดูตัวอย่างก่อนนำเข้าซึ่งไม่เขียนข้อมูล ไม่ได้ลบบัญชี กู้คืนข้อมูล หรือรับรองการปฏิบัติตามกฎหมาย การผูกกับบัญชีในเครื่องใช้โทเค็นสุ่มที่เก็บไว้ในอุปกรณ์นี้ อุปกรณ์อื่นจึงอาจตรวจสอบไม่ได้",
    "ขอบเขตการทดสอบความแตกต่างของสคีมาพกพา",
    "ตัวสร้าง v1 · seed คงที่ {seeds} ค่า · พาร์ทิชันเชิงคำศัพท์/ความหมาย {partitions} ส่วน · กรณีถดถอยสังเคราะห์ {cases} กรณีที่ผ่านการทบทวนความเป็นส่วนตัวระดับชุดข้อมูล · runtime {runtimes} รายการ",
    "เกตออฟไลน์ที่กำหนดค่าไว้: {runtime} โดย Node ไม่ทำงานภายในแอป",
    "การตรวจสอบก่อนใช้งานจริงปฏิเสธสมาชิกซ้ำ surrogate ที่แยกเดี่ยว อักขระ Unicode ที่ไม่ใช่อักขระ และข้อมูลที่เกินขีดจำกัดขนาดแพ็กเกจ จำนวนโหนด ความลึก ความกว้าง สตริงต้นทาง/หลังถอดรหัส คีย์ หรือโทเค็นตัวเลข ชุดทดสอบความแตกต่างแบบคงที่ยังครอบคลุมลำดับความสำคัญของข้อผิดพลาดหลายรายการ รายการ manifest ที่ไม่ซ้ำ และสัญญาความถูกต้องครบถ้วน",
    "นี่คือขอบเขตที่คอมไพล์ไว้ ไม่ใช่หลักฐานการทำงานล่าสุดบนอุปกรณ์นี้ เกณฑ์เวลาได้รับการตรวจหลัง parser คืนค่าเท่านั้น จึงหยุด parser ที่ค้างไม่ได้ การย่อกรณีเพื่อเล่นซ้ำข้าม runtime และ parser ในอาร์ติแฟกต์เผยแพร่ของเบราว์เซอร์ Android iOS และเดสก์ท็อปยังไม่ได้รับการยืนยัน",
    "สร้างภาพรวมข้อมูลปัจจุบัน",
    "ส่งออกโปรไฟล์ที่โหลดอยู่ การตั้งค่า การเลือกยา รายการใช้ยา มื้ออาหาร การเตือนบนอุปกรณ์นี้ และลิงก์ความสัมพันธ์ โดยไม่รวม UID อีเมล โทเค็นเปิดใช้การเตือน และ endpoint ของ AI ในเครื่อง การผูกเจ้าของแบบทางเดียวที่แยกตามโดเมนเป็นนามแฝง ไม่ใช่ข้อมูลนิรนาม",
    "สร้างและตรวจสอบด้วยตนเอง",
    "ผ่านการตรวจสอบความถูกต้องครบถ้วนด้วยตนเอง",
    "ไฟล์แบบมีโครงสร้าง {count} ไฟล์",
    "{count} ไบต์",
    "การป้องกันสิทธิ์ในเครื่อง {protection}",
    "รุ่นของสิทธิ์ {revision}",
    "ตรวจสอบ ย้าย และลบโทเค็นในเครื่องรุ่นเก่าแล้ว",
    "หมุนเวียนตัวตนการส่งออกในเครื่อง",
    "หมุนเวียนตัวตนการส่งออกในเครื่องหรือไม่",
    "การดำเนินการนี้สร้างสิทธิ์ใหม่ที่ผูกกับอุปกรณ์ แพ็กเกจที่สร้างก่อนหน้านี้จะไม่ผ่านการตรวจสอบเจ้าของของบัญชีในเครื่องนี้ เนื้อหาแพ็กเกจไม่เปลี่ยนและยกเลิกการดำเนินการนี้ไม่ได้",
    "หมุนเวียนและล้างแพ็กเกจปัจจุบัน",
    "หมุนเวียนตัวตนการส่งออกในเครื่องแล้ว ล้างแพ็กเกจและตัวอย่างปัจจุบันแล้ว",
    "ไม่สามารถหมุนเวียนตัวตนในเครื่องอย่างปลอดภัยได้ ยังคงใช้ตัวตนเดิม",
    "คัดลอก JSON",
    "บันทึกแพ็กเกจ",
    "คัดลอก JSON ของแพ็กเกจแล้ว โปรดเก็บไว้ในตำแหน่งที่มีการป้องกัน",
    "ตัวอย่างนำเข้า (ไม่มีการเขียนข้อมูล)",
    "วางแพ็กเกจ ParkinSUM เพื่อตรวจรูปแบบ รุ่น การผูกเจ้าของ checksum จำนวนรายการ ข้อขัดแย้ง และฟิลด์ที่ไม่รองรับ รุ่นนี้จะไม่ดำเนินการนำเข้า",
    "JSON ของแพ็กเกจ",
    "วางจากคลิปบอร์ด",
    "ใช้แพ็กเกจที่สร้างแล้ว",
    "เรียกใช้ตัวอย่างโดยไม่เขียนข้อมูล",
    "พร้อมสำหรับกระบวนการนำเข้าที่มีการควบคุมในอนาคต",
    "ขอบเขตบัญชีหรืออุปกรณ์ไม่ตรงกัน",
    "ไม่รองรับสคีมาของแพ็กเกจ",
    "แพ็กเกจเสียหายหรือไม่ถูกต้อง",
    "ระเบียน {records} รายการ · ข้อขัดแย้ง {conflicts} รายการ · ฟิลด์ไม่รองรับ {unsupported} รายการ",
    "ใบรับรองการตรวจสอบสคีมาที่ตรึงไว้และการย้ายข้อมูล",
    "ต้นทาง v{source} → ปลายทาง v{target} · การตัดสินใจ: {decision}",
    "ใบรับรอง {receipt}… · ตัวตรวจสอบต้นทาง {validator}…",
    "บันทึกนี้ยืนยันเฉพาะการตรวจสอบ/ดูตัวอย่างในเครื่องแบบกำหนดแน่นอน ไม่มีการเขียนข้อมูล จัดตาราง หรือใช้เครือข่าย และไม่ได้ยืนยันตัวตนผู้ออกหรือความถูกต้องทางคลินิก",
    "ตัวอย่างเจตนาการแสดงการเตือน",
    "แผนเตือน {total} รายการ · เปิดใช้ที่ต้นทาง {enabled} รายการ · {consent} รายการต้องได้รับความยินยอมอย่างชัดเจนบนอุปกรณ์ปลายทางก่อนจัดตาราง",
    "โหมดความเป็นส่วนตัว: {modes} · ภาษาการแจ้งเตือนที่บันทึกไว้: {languages}",
    "ตรงกับนโยบายข้อความปัจจุบัน {match} รายการ · ต้องคำนวณใหม่ {drift} รายการ · การเลือกภาษาต่างจากข้อความที่บันทึกไว้ {decisions} รายการ",
    "การเตือนสคีมา v2 รุ่นเก่า {count} รายการจะตีความเป็นแบบขั้นต่ำ / ภาษาอังกฤษเฉพาะในตัวอย่างเท่านั้น",
    "ตัวอย่างนี้ไม่ขอสิทธิ์การแจ้งเตือนและไม่สร้างการเตือนของระบบ อุปกรณ์ปลายทางต้องตรวจสอบความสามารถ ภาษา และการตั้งค่าความเป็นส่วนตัวอีกครั้ง ก่อนที่คุณจะอนุมัติการจัดตารางอย่างชัดเจน จะไม่มีการใช้โทเค็นต้นทางหรือ ID การแจ้งเตือนซ้ำ",
    "ฟิลด์ที่ไม่รองรับ",
    "ขอบเขตของการดูตัวอย่าง: การดำเนินการนี้ไม่ได้เปลี่ยนข้อมูลถาวร",
    "ไม่สามารถใช้ขอบเขตบัญชีหรืออุปกรณ์ปัจจุบันได้",
    "บัญชีเปลี่ยนระหว่างดำเนินการ ล้างแพ็กเกจ ข้อความ และตัวอย่างแล้ว",
    "สร้างแพ็กเกจไม่ได้",
    "คัดลอกแพ็กเกจไม่ได้ ไม่มีการบันทึกไฟล์",
    "บันทึกแพ็กเกจไม่ได้",
    "โปรดวางหรือเลือกแพ็กเกจก่อน",
    "ข้อมูลนำเข้าเกินขีดจำกัดขนาดแพ็กเกจ จึงไม่ได้โหลดหรือแยกวิเคราะห์",
    "ตรวจสอบแพ็กเกจอย่างปลอดภัยไม่ได้ ไม่มีการเขียนข้อมูล",
    "ไม่มีข้อความที่ใช้ได้ในคลิปบอร์ด",
    "แพลตฟอร์มนี้ไม่รองรับการบันทึกโดยตรง โปรดใช้คัดลอก JSON",
    "ไม่รองรับการบันทึกโดยตรง คัดลอก JSON แล้ว แต่ไม่ได้ยืนยันว่าบันทึกไฟล์แล้ว",
    "บันทึกโดยตรงไม่สำเร็จ คัดลอก JSON แล้ว แต่ไม่ได้ยืนยันว่าไฟล์ใหม่ถูกบันทึก",
    "บันทึกโดยตรงไม่สำเร็จและคัดลอก JSON แล้ว ไม่สามารถยืนยันการล้างไฟล์ชั่วคราวได้ โปรดตรวจสอบโฟลเดอร์ดาวน์โหลด",
    "ทั้งการบันทึกและคัดลอกไม่สำเร็จ ไม่สามารถยืนยันการล้างไฟล์ชั่วคราวได้ โปรดตรวจสอบโฟลเดอร์ดาวน์โหลด",
    "บันทึกแพ็กเกจที่ {location} แล้ว",
    "ส่งคำขอดาวน์โหลดไปยังเบราว์เซอร์แล้ว โปรดยืนยันว่าไฟล์ปรากฏในรายการดาวน์โหลด",
    "บันทึกแพ็กเกจในเอกสารของแอปที่ {location} แล้ว หากต้องการสำเนาภายนอกด้วย ให้คัดลอก JSON",
    "รายการดาวน์โหลดของเบราว์เซอร์",
  ],
  'id': [
    "Paket data portabel saya",
    "Ini adalah salinan data sensitif yang tidak dienkripsi",
    "Paket ini dapat berisi makanan, catatan konsumsi obat, catatan dosis, dan teks pengingat. Simpan hanya di lokasi yang Anda kendalikan. SHA-256 mendeteksi perubahan; fitur ini tidak mengenkripsi atau menyembunyikan isi.",
    "Fitur ini membuat JSON yang dapat dibaca pengguna dan pratinjau impor tanpa penulisan. Fitur ini tidak menghapus akun, memulihkan data, atau menyatakan kepatuhan hukum. Pengikatan akun lokal memakai token acak yang disimpan di perangkat ini, sehingga perangkat lain mungkin tidak dapat memvalidasinya.",
    "Batas pengujian diferensial skema portabel",
    "Generator v1 · {seeds} seed tetap · {partitions} partisi leksikal/semantik · {cases} kasus regresi sintetis yang ditinjau privasinya pada tingkat korpus · {runtimes} runtime.",
    "Gerbang luring yang dikonfigurasi: {runtime}. Node tidak berjalan di dalam aplikasi.",
    "Pemeriksaan awal produksi menolak anggota duplikat, surrogate terisolasi, nonkarakter Unicode, dan masukan yang melampaui batas ukuran paket, node, kedalaman, lebar, string sumber/hasil dekode, kunci, atau token angka. Kampanye diferensial tetap juga mencakup prioritas kesalahan gabungan, inventaris manifes unik, dan kontrak integritas.",
    "Ini adalah cakupan yang dikompilasi, bukan bukti eksekusi terbaru pada perangkat ini. Ambang waktu diperiksa hanya setelah parser kembali dan tidak dapat menghentikan parser yang macet. Pemutaran ulang minimal lintas runtime serta parser pada artefak rilis browser, Android, iOS, dan desktop belum diverifikasi.",
    "Buat cuplikan data saat ini",
    "Mengekspor profil yang saat ini dimuat, preferensi, pilihan obat, konsumsi, makanan, pengingat perangkat ini, dan tautan relasi. UID, email, token aktivasi pengingat, dan endpoint AI lokal tidak disertakan. Pengikatan pemilik satu arah dengan pemisahan domain bersifat pseudonim, bukan anonim.",
    "Buat dan periksa sendiri",
    "Pemeriksaan integritas mandiri lulus",
    "{count} file terstruktur",
    "{count} byte",
    "Perlindungan kapabilitas lokal {protection}",
    "Revisi kapabilitas {revision}",
    "Token lokal lama telah diverifikasi, dimigrasikan, dan dihapus",
    "Rotasi identitas ekspor lokal",
    "Rotasi identitas ekspor lokal?",
    "Ini membuat kapabilitas baru yang terikat ke perangkat. Paket yang dibuat sebelumnya tidak akan lolos validasi pemilik untuk akun lokal ini. Isi paket tidak berubah dan tindakan ini tidak dapat dibatalkan.",
    "Rotasi dan hapus paket saat ini",
    "Identitas ekspor lokal dirotasi. Paket dan pratinjau saat ini telah dihapus.",
    "Identitas ekspor lokal tidak dapat dirotasi dengan aman. Identitas yang ada tetap digunakan.",
    "Salin JSON",
    "Simpan paket",
    "JSON paket disalin. Simpan di lokasi yang terlindungi.",
    "Pratinjau impor (tanpa penulisan)",
    "Tempel paket ParkinSUM untuk memeriksa format, versi, pengikatan pemilik, checksum, jumlah, konflik, dan bidang yang tidak didukung. Versi ini tidak melakukan impor.",
    "JSON paket",
    "Tempel dari papan klip",
    "Gunakan paket yang dibuat",
    "Jalankan pratinjau tanpa penulisan",
    "Siap untuk alur impor terkontrol di masa mendatang",
    "Cakupan akun atau perangkat tidak cocok",
    "Skema paket tidak didukung",
    "Paket rusak atau tidak valid",
    "{records} catatan · {conflicts} konflik · {unsupported} bidang tidak didukung",
    "Tanda terima validasi skema tetap dan migrasi",
    "Sumber v{source} → target v{target} · keputusan: {decision}",
    "Tanda terima {receipt}… · validator sumber {validator}…",
    "Tanda terima ini hanya membuktikan validasi/pratinjau lokal yang deterministik. Tidak ada penulisan, penjadwalan, atau jaringan; tanda terima ini tidak membuktikan identitas penerbit atau kebenaran klinis.",
    "Pratinjau maksud penyajian pengingat",
    "{total} rencana pengingat · {enabled} aktif pada sumber · {consent} memerlukan persetujuan eksplisit di perangkat tujuan sebelum dijadwalkan.",
    "Mode privasi: {modes} · bahasa notifikasi tersimpan: {languages}",
    "{match} cocok dengan kebijakan teks saat ini · {drift} perlu dihitung ulang · {decisions} keputusan bahasa berbeda dari teks tersimpan",
    "{count} pengingat skema v2 lama hanya ditafsirkan sebagai minimal / English untuk pratinjau.",
    "Pratinjau ini tidak meminta izin notifikasi dan tidak membuat pengingat sistem. Perangkat tujuan harus memeriksa ulang kapabilitas, bahasa, dan privasi sebelum Anda menyetujui penjadwalan secara eksplisit; token sumber dan ID notifikasi tidak pernah digunakan ulang.",
    "Bidang yang tidak didukung",
    "Jaminan pratinjau: operasi ini tidak mengubah data persisten.",
    "Cakupan akun atau perangkat saat ini tidak tersedia.",
    "Akun berubah selama operasi. Paket, teks, dan pratinjau telah dihapus.",
    "Paket tidak dapat dibuat",
    "Paket tidak dapat disalin. Tidak ada file yang disimpan.",
    "Paket tidak dapat disimpan",
    "Tempel atau pilih paket terlebih dahulu.",
    "Masukan melebihi batas ukuran paket dan tidak dimuat atau diurai.",
    "Paket tidak dapat diperiksa dengan aman. Tidak ada data yang ditulis.",
    "Papan klip tidak berisi teks yang dapat digunakan.",
    "Penyimpanan langsung tidak tersedia di platform ini. Gunakan Salin JSON.",
    "Penyimpanan langsung tidak tersedia. JSON disalin; tidak ada klaim bahwa file telah disimpan.",
    "Penyimpanan langsung gagal. JSON disalin; penyimpanan file baru belum dikonfirmasi.",
    "Penyimpanan langsung gagal dan JSON disalin. Pembersihan file sementara tidak dapat dikonfirmasi; periksa Unduhan.",
    "Penyimpanan dan penyalinan sama-sama gagal. Pembersihan file sementara tidak dapat dikonfirmasi; periksa Unduhan.",
    "Paket disimpan di {location}.",
    "Unduhan browser diminta. Pastikan file muncul di daftar unduhan Anda.",
    "Paket disimpan di dokumen aplikasi pada {location}. Gunakan Salin JSON jika Anda juga memerlukan salinan eksternal.",
    "unduhan browser",
  ],
  'ru': [
    "Мой переносимый пакет данных",
    "Это незашифрованная копия конфиденциальных данных",
    "Пакет может содержать сведения о приёмах пищи, записи о приёме лекарств, заметки о дозах и текст напоминаний. Сохраняйте его только в месте, которое контролируете вы. SHA-256 обнаруживает изменения, но не шифрует и не скрывает содержимое.",
    "Функция создаёт читаемый пользователем JSON и предварительный просмотр импорта без записи данных. Она не удаляет аккаунт, не восстанавливает данные и не подтверждает соответствие закону. Привязка к локальному аккаунту использует случайный токен на этом устройстве, поэтому другое устройство может не пройти проверку.",
    "Граница дифференциального теста переносимой схемы",
    "Генератор v1 · фиксированных начальных значений: {seeds} · лексических/семантических разделов: {partitions} · синтетических регрессионных случаев с проверкой конфиденциальности корпуса: {cases} · сред выполнения: {runtimes}.",
    "Настроенная автономная проверка: {runtime}. Node не запускается внутри приложения.",
    "Предварительная проверка рабочей версии отклоняет дублированные элементы, отдельные суррогаты, символы Unicode, не являющиеся знаками, и входные данные сверх лимитов размера пакета, узлов, глубины, ширины, исходных/декодированных строк, ключей или числовых токенов. Фиксированная дифференциальная кампания также охватывает приоритет составных ошибок, уникальный перечень манифеста и контракт целостности.",
    "Это описание скомпилированного объёма, а не подтверждение недавнего запуска на этом устройстве. Порог времени проверяется только после возврата парсера и не может остановить зависший парсер. Минимизация повторного воспроизведения между средами и парсеры в браузерных, Android, iOS и настольных релизных артефактах не проверены.",
    "Создать снимок текущих данных",
    "Экспортируются загруженный профиль, настройки, выбор лекарств, приёмы, питание, напоминания этого устройства и связи записей. UID, электронная почта, токены активации напоминаний и адреса локального ИИ не включаются. Односторонняя привязка владельца с разделением по доменам является псевдонимной, а не анонимной.",
    "Создать и проверить",
    "Проверка целостности пройдена",
    "Структурированных файлов: {count}",
    "Байт: {count}",
    "Защита локальных полномочий {protection}",
    "Версия полномочий {revision}",
    "Старый локальный токен проверен, перенесён и удалён",
    "Сменить локальный идентификатор экспорта",
    "Сменить локальный идентификатор экспорта?",
    "Будут созданы новые полномочия, привязанные к устройству. Ранее созданные пакеты больше не пройдут проверку владельца для этого локального аккаунта. Содержимое пакета не изменится; действие нельзя отменить.",
    "Сменить и очистить текущий пакет",
    "Локальный идентификатор экспорта сменён. Текущий пакет и предварительный просмотр очищены.",
    "Не удалось безопасно сменить локальный идентификатор. Существующий идентификатор остаётся активным.",
    "Копировать JSON",
    "Сохранить пакет",
    "JSON пакета скопирован. Сохраните его в защищённом месте.",
    "Предварительный просмотр импорта (без записи)",
    "Вставьте пакет ParkinSUM, чтобы проверить формат, версию, привязку владельца, контрольные суммы, количество записей, конфликты и неподдерживаемые поля. Эта версия не выполняет импорт.",
    "JSON пакета",
    "Вставить из буфера обмена",
    "Использовать созданный пакет",
    "Запустить просмотр без записи",
    "Готово к будущему контролируемому процессу импорта",
    "Аккаунт или устройство не совпадают",
    "Схема пакета не поддерживается",
    "Пакет повреждён или недействителен",
    "Записей: {records} · конфликтов: {conflicts} · неподдерживаемых полей: {unsupported}",
    "Квитанция проверки фиксированной схемы и миграции",
    "Источник v{source} → цель v{target} · решение: {decision}",
    "Квитанция {receipt}… · исходный проверяющий модуль {validator}…",
    "Квитанция подтверждает только детерминированную локальную проверку/предпросмотр. Запись, планирование и сетевые действия не выполняются; личность издателя и клиническая корректность не подтверждаются.",
    "Предпросмотр намерения отображения напоминаний",
    "Планов напоминаний: {total} · включено на источнике: {enabled} · для {consent} требуется явное согласие на целевом устройстве до планирования.",
    "Режимы конфиденциальности: {modes} · сохранённые языки уведомлений: {languages}",
    "Совпадают с текущей политикой текста: {match} · требуют пересчёта: {drift} · решения о языке отличаются от сохранённого текста: {decisions}",
    "Старые напоминания схемы v2 ({count}) интерпретируются как минимальные / английские только для предварительного просмотра.",
    "Этот просмотр не запрашивает разрешение на уведомления и не создаёт системные напоминания. Целевое устройство должно повторно проверить возможности, язык и конфиденциальность до вашего явного разрешения на планирование; исходные токены и ID уведомлений никогда не используются повторно.",
    "Неподдерживаемые поля",
    "Гарантия предпросмотра: операция не изменила постоянные данные.",
    "Текущий аккаунт или область устройства недоступны.",
    "Во время операции аккаунт изменился. Пакет, текст и предпросмотр очищены.",
    "Не удалось создать пакет",
    "Не удалось скопировать пакет. Файл не сохранён.",
    "Не удалось сохранить пакет",
    "Сначала вставьте или выберите пакет.",
    "Входные данные превышают лимит размера пакета; они не загружены и не разобраны.",
    "Не удалось безопасно проверить пакет. Данные не записаны.",
    "В буфере обмена нет пригодного текста.",
    "На этой платформе прямое сохранение недоступно. Используйте Копировать JSON.",
    "Прямое сохранение недоступно. JSON скопирован; сохранение файла не заявляется.",
    "Прямое сохранение не удалось. JSON скопирован; сохранение нового файла не подтверждено.",
    "Прямое сохранение не удалось, JSON скопирован. Очистку временного файла подтвердить не удалось; проверьте загрузки.",
    "Сохранение и копирование не удались. Очистку временного файла подтвердить не удалось; проверьте загрузки.",
    "Пакет сохранён в {location}.",
    "Запрошена загрузка в браузере. Убедитесь, что файл появился в списке загрузок.",
    "Пакет сохранён в документах приложения: {location}. Если нужна внешняя копия, используйте Копировать JSON.",
    "загрузки браузера",
  ],
  'pl': [
    "Mój przenośny pakiet danych",
    "To niezaszyfrowana kopia danych wrażliwych",
    "Pakiet może zawierać posiłki, rejestry przyjmowania leków, notatki o dawkach i treść przypomnień. Zapisuj go tylko w miejscu, nad którym masz kontrolę. SHA-256 wykrywa zmiany, ale nie szyfruje ani nie ukrywa zawartości.",
    "Ta funkcja tworzy czytelny dla użytkownika plik JSON i podgląd importu bez zapisu. Nie usuwa konta, nie przywraca danych ani nie poświadcza zgodności z prawem. Powiązanie z kontem lokalnym używa losowego tokenu przechowywanego na tym urządzeniu, więc inne urządzenie może go nie zweryfikować.",
    "Granica testu różnicowego przenośnego schematu",
    "Generator v1 · stałych ziaren: {seeds} · partycji leksykalnych/semantycznych: {partitions} · syntetycznych przypadków regresji z przeglądem prywatności korpusu: {cases} · środowisk uruchomieniowych: {runtimes}.",
    "Skonfigurowana bramka offline: {runtime}. Node nie działa wewnątrz aplikacji.",
    "Kontrola przedprodukcyjna odrzuca zduplikowane elementy, izolowane surogaty, znaki Unicode niebędące znakami oraz dane przekraczające limity rozmiaru pakietu, węzłów, głębokości, szerokości, ciągów źródłowych/po dekodowaniu, kluczy lub tokenów liczbowych. Stała kampania różnicowa obejmuje także priorytety błędów złożonych, unikalny wykaz manifestu i kontrakt integralności.",
    "To opis skompilowanego zakresu, a nie potwierdzenie niedawnego uruchomienia na tym urządzeniu. Próg czasu jest sprawdzany dopiero po powrocie parsera i nie może zatrzymać zawieszonego parsera. Minimalizacja powtórzeń między środowiskami oraz parsery w artefaktach przeglądarkowych, Android, iOS i desktop nie zostały zweryfikowane.",
    "Utwórz bieżący zrzut danych",
    "Eksportuje aktualnie załadowany profil, preferencje, wybory leków, przyjęcia, posiłki, przypomnienia z tego urządzenia i powiązania. UID, e-mail, tokeny aktywacji przypomnień i lokalne endpointy AI są wykluczone. Jednokierunkowe powiązanie właściciela z separacją domen jest pseudonimowe, a nie anonimowe.",
    "Utwórz i sprawdź",
    "Kontrola integralności zakończona powodzeniem",
    "Plików strukturalnych: {count}",
    "Bajtów: {count}",
    "Ochrona lokalnych uprawnień {protection}",
    "Wersja uprawnień {revision}",
    "Stary token lokalny zweryfikowano, przeniesiono i usunięto",
    "Zmień lokalną tożsamość eksportu",
    "Zmienić lokalną tożsamość eksportu?",
    "Tworzy to nowe uprawnienie powiązane z urządzeniem. Wcześniej utworzone pakiety nie przejdą już walidacji właściciela dla tego konta lokalnego. Zawartość pakietu nie ulegnie zmianie, a operacji nie można cofnąć.",
    "Zmień i wyczyść bieżący pakiet",
    "Zmieniono lokalną tożsamość eksportu. Bieżący pakiet i podgląd zostały wyczyszczone.",
    "Nie można bezpiecznie zmienić lokalnej tożsamości. Dotychczasowa tożsamość pozostaje aktywna.",
    "Kopiuj JSON",
    "Zapisz pakiet",
    "Skopiowano JSON pakietu. Zapisz go w chronionym miejscu.",
    "Podgląd importu (bez zapisu)",
    "Wklej pakiet ParkinSUM, aby sprawdzić format, wersję, powiązanie właściciela, sumy kontrolne, liczbę rekordów, konflikty i nieobsługiwane pola. Ta wersja nie wykonuje importu.",
    "JSON pakietu",
    "Wklej ze schowka",
    "Użyj utworzonego pakietu",
    "Uruchom podgląd bez zapisu",
    "Gotowe na przyszły kontrolowany proces importu",
    "Zakres konta lub urządzenia jest niezgodny",
    "Schemat pakietu nie jest obsługiwany",
    "Pakiet jest uszkodzony lub nieprawidłowy",
    "Rekordów: {records} · konfliktów: {conflicts} · nieobsługiwanych pól: {unsupported}",
    "Potwierdzenie walidacji zamrożonego schematu i migracji",
    "Źródło v{source} → cel v{target} · decyzja: {decision}",
    "Potwierdzenie {receipt}… · walidator źródła {validator}…",
    "Potwierdzenie dowodzi tylko deterministycznej lokalnej walidacji/podglądu. Nie zapisuje danych, nie planuje zdarzeń ani nie łączy się z siecią; nie potwierdza tożsamości wystawcy ani poprawności klinicznej.",
    "Podgląd zamiaru prezentacji przypomnień",
    "Planów przypomnień: {total} · aktywnych u źródła: {enabled} · {consent} wymaga wyraźnej zgody na urządzeniu docelowym przed zaplanowaniem.",
    "Tryby prywatności: {modes} · zapisane języki powiadomień: {languages}",
    "Zgodnych z obecną polityką tekstu: {match} · do ponownego obliczenia: {drift} · decyzji językowych różnych od zapisanego tekstu: {decisions}",
    "Starsze przypomnienia schematu v2 ({count}) są interpretowane jako minimalne / angielskie wyłącznie na potrzeby podglądu.",
    "Ten podgląd nie prosi o uprawnienia do powiadomień ani nie tworzy przypomnienia systemowego. Urządzenie docelowe musi ponownie sprawdzić możliwości, język i prywatność, zanim wyraźnie zatwierdzisz planowanie; tokeny źródłowe i identyfikatory powiadomień nigdy nie są ponownie używane.",
    "Nieobsługiwane pola",
    "Gwarancja podglądu: ta operacja nie zmieniła trwałych danych.",
    "Bieżący zakres konta lub urządzenia jest niedostępny.",
    "Konto zmieniło się podczas operacji. Pakiet, tekst i podgląd zostały wyczyszczone.",
    "Nie można utworzyć pakietu",
    "Nie można skopiować pakietu. Żaden plik nie został zapisany.",
    "Nie można zapisać pakietu",
    "Najpierw wklej lub wybierz pakiet.",
    "Dane wejściowe przekraczają limit rozmiaru pakietu i nie zostały wczytane ani przeanalizowane.",
    "Nie można bezpiecznie sprawdzić pakietu. Nie zapisano żadnych danych.",
    "Schowek nie zawiera użytecznego tekstu.",
    "Na tej platformie zapis bezpośredni jest niedostępny. Użyj opcji Kopiuj JSON.",
    "Zapis bezpośredni jest niedostępny. Skopiowano JSON; nie potwierdzono zapisu pliku.",
    "Zapis bezpośredni nie powiódł się. Skopiowano JSON; nie potwierdzono zapisania nowego pliku.",
    "Zapis bezpośredni nie powiódł się, a JSON skopiowano. Nie można potwierdzić usunięcia pliku tymczasowego; sprawdź Pobrane.",
    "Zapis i kopiowanie nie powiodły się. Nie można potwierdzić usunięcia pliku tymczasowego; sprawdź Pobrane.",
    "Pakiet zapisano w {location}.",
    "Zażądano pobrania w przeglądarce. Sprawdź, czy plik pojawił się na liście pobrań.",
    "Pakiet zapisano w dokumentach aplikacji: {location}. Użyj opcji Kopiuj JSON, jeśli potrzebujesz też kopii zewnętrznej.",
    "pobrane pliki przeglądarki",
  ],
  'ar': [
    "حزمة بياناتي القابلة للنقل",
    "هذه نسخة حساسة غير مشفّرة من البيانات",
    "قد تحتوي الحزمة على الوجبات وسجلات تناول الأدوية وملاحظات الجرعات ونصوص التذكير. احفظها فقط في مكان تتحكم فيه. تكشف SHA-256 التغييرات لكنها لا تشفّر المحتوى ولا تخفيه.",
    "تنشئ هذه الميزة ملف JSON مقروءًا للمستخدم ومعاينة استيراد بلا كتابة. لا تحذف حسابًا ولا تستعيد بيانات ولا تثبت الامتثال القانوني. يستخدم ربط الحساب المحلي رمزًا عشوائيًا محفوظًا على هذا الجهاز، لذلك قد لا يتمكن جهاز آخر من التحقق منه.",
    "حدود الاختبار التفاضلي للمخطط القابل للنقل",
    "المولّد v1 · بذور ثابتة {seeds} · أقسام معجمية/دلالية {partitions} · حالات تراجع اصطناعية {cases} خضعت لمراجعة الخصوصية على مستوى المجموعة · بيئات تشغيل {runtimes}.",
    "البوابة غير المتصلة المضبوطة: {runtime}. لا يعمل Node داخل التطبيق.",
    "يرفض الفحص المسبق للإنتاج الأعضاء المكررة والبدائل المعزولة ومحارف Unicode غير المحرفية والمدخلات التي تتجاوز حدود حجم الحزمة أو العقد أو العمق أو العرض أو السلاسل الأصلية/المفكوكة أو المفاتيح أو رموز الأرقام. وتشمل الحملة التفاضلية الثابتة أيضًا أولوية الأخطاء المركبة وفهرس البيان الفريد وعقد السلامة.",
    "هذا وصف للنطاق المترجم، وليس إيصالًا لتشغيل حديث على هذا الجهاز. لا يُفحص حد الزمن إلا بعد عودة المحلل ولا يمكنه إيقاف محلل عالق. لم يتم التحقق من تصغير إعادة التشغيل بين بيئات التشغيل ولا من المحللات في إصدارات المتصفح وAndroid وiOS وسطح المكتب.",
    "إنشاء لقطة للبيانات الحالية",
    "تُصدّر الملف الشخصي المحمّل حاليًا والتفضيلات واختيارات الأدوية والجرعات المسجلة والوجبات وتذكيرات هذا الجهاز وروابط العلاقات. لا تشمل UID أو البريد الإلكتروني أو رموز تفعيل التذكير أو نقاط نهاية الذكاء الاصطناعي المحلي. ربط المالك أحادي الاتجاه ومفصول النطاقات مستعار لا مجهول.",
    "إنشاء وفحص ذاتي",
    "اجتاز الفحص الذاتي للسلامة",
    "ملفات منظّمة: {count}",
    "بايت: {count}",
    "حماية الصلاحية المحلية {protection}",
    "مراجعة الصلاحية {revision}",
    "تم التحقق من الرمز المحلي القديم وترحيله وحذفه",
    "تدوير هوية التصدير المحلية",
    "هل تريد تدوير هوية التصدير المحلية؟",
    "ينشئ هذا صلاحية جديدة مرتبطة بالجهاز. لن تجتاز الحزم السابقة التحقق من المالك لهذا الحساب المحلي. لا يغيّر هذا محتوى الحزمة ولا يمكن التراجع عنه.",
    "تدوير ومسح الحزمة الحالية",
    "تم تدوير هوية التصدير المحلية. تم مسح الحزمة والمعاينة الحاليتين.",
    "تعذر تدوير الهوية المحلية بأمان. ستظل الهوية الحالية مستخدمة.",
    "نسخ JSON",
    "حفظ الحزمة",
    "تم نسخ JSON للحزمة. احفظه في موقع محمي.",
    "معاينة الاستيراد (بلا كتابة)",
    "الصق حزمة ParkinSUM لفحص التنسيق والإصدار وربط المالك والمجاميع الاختبارية والأعداد والتعارضات والحقول غير المدعومة. لا ينفذ هذا الإصدار عملية استيراد.",
    "JSON للحزمة",
    "لصق من الحافظة",
    "استخدام الحزمة المنشأة",
    "تشغيل معاينة بلا كتابة",
    "جاهز لسير عمل استيراد مضبوط مستقبلًا",
    "نطاق الحساب أو الجهاز غير متطابق",
    "مخطط الحزمة غير مدعوم",
    "الحزمة تالفة أو غير صالحة",
    "السجلات {records} · التعارضات {conflicts} · الحقول غير المدعومة {unsupported}",
    "إيصال التحقق من المخطط الثابت والترحيل",
    "المصدر v{source} → الهدف v{target} · القرار: {decision}",
    "الإيصال {receipt}… · مدقق المصدر {validator}…",
    "يثبت هذا الإيصال التحقق/المعاينة المحلية الحتمية فقط. لا يكتب بيانات ولا يجدول ولا يتصل بالشبكة، ولا يثبت هوية الجهة المصدرة أو الصحة السريرية.",
    "معاينة نية عرض التذكير",
    "خطط التذكير {total} · المفعّل في المصدر {enabled} · {consent} يتطلب موافقة صريحة على الجهاز الهدف قبل الجدولة.",
    "أوضاع الخصوصية: {modes} · لغات الإشعارات المحفوظة: {languages}",
    "مطابق لسياسة النص الحالية {match} · يحتاج إلى إعادة حساب {drift} · قرارات اللغة المختلفة عن النص المحفوظ {decisions}",
    "تُفسّر تذكيرات المخطط v2 القديمة ({count}) على أنها الحد الأدنى / الإنجليزية للمعاينة فقط.",
    "لا تطلب هذه المعاينة إذن الإشعارات ولا تنشئ تذكيرًا للنظام. يجب على الجهاز الهدف إعادة فحص الإمكانات واللغة والخصوصية قبل موافقتك الصريحة على الجدولة؛ ولا يُعاد استخدام رموز المصدر أو معرّفات الإشعارات مطلقًا.",
    "حقول غير مدعومة",
    "ضمان المعاينة: لم تغيّر هذه العملية أي بيانات دائمة.",
    "نطاق الحساب أو الجهاز الحالي غير متاح.",
    "تغيّر الحساب أثناء العملية. تم مسح الحزمة والنص والمعاينة.",
    "تعذر إنشاء الحزمة",
    "تعذر نسخ الحزمة. لم يُحفظ أي ملف.",
    "تعذر حفظ الحزمة",
    "الصق حزمة أو اخترها أولًا.",
    "يتجاوز الإدخال حد حجم الحزمة ولم يتم تحميله أو تحليله.",
    "تعذر فحص الحزمة بأمان. لم تُكتب أي بيانات.",
    "لا تحتوي الحافظة على نص قابل للاستخدام.",
    "الحفظ المباشر غير متاح على هذه المنصة. استخدم نسخ JSON.",
    "الحفظ المباشر غير متاح. تم نسخ JSON؛ ولا ندّعي حفظ ملف.",
    "فشل الحفظ المباشر. تم نسخ JSON؛ ولم يتم تأكيد حفظ ملف جديد.",
    "فشل الحفظ المباشر ونُسخ JSON. تعذر تأكيد تنظيف الملف المؤقت؛ تحقق من التنزيلات.",
    "فشل الحفظ والنسخ. تعذر تأكيد تنظيف الملف المؤقت؛ تحقق من التنزيلات.",
    "تم حفظ الحزمة في {location}.",
    "طُلب تنزيل من المتصفح. تحقق من ظهور الملف في قائمة التنزيلات.",
    "تم حفظ الحزمة في مستندات التطبيق في {location}. استخدم نسخ JSON إذا كنت تحتاج أيضًا إلى نسخة خارجية.",
    "تنزيلات المتصفح",
  ],
};

Map<String, String> _portableDataPackageLocaleMap(List<String> values) {
  if (values.length != kPortableDataPackageTranslationKeys.length) {
    throw StateError(
      'Portable data-package translation row has ${values.length} values; '
      'expected ${kPortableDataPackageTranslationKeys.length}.',
    );
  }
  return Map<String, String>.unmodifiable(
    Map<String, String>.fromIterables(
      kPortableDataPackageTranslationKeys,
      values,
    ),
  );
}

final Map<String, Map<String, String>> kPortableDataPackageUiTranslations =
    Map<String, Map<String, String>>.unmodifiable({
      for (final entry in _portableDataPackageLocaleRows.entries)
        entry.key: _portableDataPackageLocaleMap(entry.value),
    });
