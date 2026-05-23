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
    'next_meal.title': '다음 식사 추천',
    'next_meal.subtitle':
        '다음 식사 시간을 먼저 정하면, 충돌 엔진이 그 시간 창 · 현재 복용 약 · 최근 식사 컨텍스트에 맞춰 5개의 후보를 재정렬합니다. 로컬 AI는 선택 사항이며 문구를 다듬는 데만 사용됩니다.',
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
  },

  // ===========================================================================
  // hi (Hindi)
  // ===========================================================================
  'hi': {
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
    'next_meal.title': 'अगले भोजन की सिफारिश',
    'next_meal.subtitle':
        'पहले अगले भोजन का अनुमानित समय चुनें; संघर्ष इंजन उस समय विंडो, सक्रिय दवाओं और हाल के संदर्भ के अनुसार 5 उम्मीदवारों को पुनर्क्रमित करेगा। स्थानीय AI वैकल्पिक है और केवल शब्दों को निखारता है।',
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
  },

  // ===========================================================================
  // es (Spanish — covers es-ES + es-MX)
  // ===========================================================================
  'es': {
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
    'next_meal.title': 'Recomendación de la próxima comida',
    'next_meal.subtitle':
        'Elija primero la hora prevista de la próxima comida; el motor de conflictos reordena 5 candidatos según esa ventana, sus medicamentos activos y el contexto reciente. La IA local es opcional y solo pule el texto.',
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
  },

  // ===========================================================================
  // vi (Vietnamese)
  // ===========================================================================
  'vi': {
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
    'next_meal.title': 'Đề xuất bữa kế tiếp',
    'next_meal.subtitle':
        'Hãy chọn giờ dự kiến cho bữa kế tiếp; bộ máy xung đột sẽ xếp lại 5 ứng viên theo khung giờ đó, thuốc đang dùng và ngữ cảnh gần đây. AI cục bộ là tùy chọn và chỉ làm mượt văn bản.',
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
    'next_meal.title': 'คำแนะนำมื้อถัดไป',
    'next_meal.subtitle':
        'เลือกเวลาที่คาดว่าจะรับประทานมื้อถัดไปก่อน เครื่องยนต์ความขัดแย้งจะจัดอันดับใหม่ 5 ตัวเลือกตามช่วงเวลานั้น ยาที่ใช้อยู่ และบริบทล่าสุด AI ในเครื่องเป็นทางเลือกและใช้เพื่อปรับสำนวนเท่านั้น',
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
  },

  // ===========================================================================
  // id (Indonesian)
  // ===========================================================================
  'id': {
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
    'next_meal.title': 'Rekomendasi makan berikutnya',
    'next_meal.subtitle':
        'Pilih dulu perkiraan waktu makan berikutnya; mesin konflik akan menyusun ulang 5 kandidat berdasarkan jendela waktu itu, obat aktif, dan konteks makan terbaru. AI lokal bersifat opsional dan hanya memoles kata-kata.',
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
  },

  // ===========================================================================
  // ru (Russian)
  // ===========================================================================
  'ru': {
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
    'next_meal.title': 'Рекомендация на следующий приём пищи',
    'next_meal.subtitle':
        'Сначала укажите предполагаемое время следующего приёма пищи; конфликт-движок переранжирует 5 кандидатов с учётом этого окна, активных лекарств и недавнего контекста. Локальный ИИ опционален и только полирует формулировки.',
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
  },

  // ===========================================================================
  // pl (Polish)
  // ===========================================================================
  'pl': {
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
    'next_meal.title': 'Rekomendacja następnego posiłku',
    'next_meal.subtitle':
        'Najpierw wybierz przewidywaną godzinę następnego posiłku; silnik konfliktów ponownie uszereguje 5 kandydatów względem tego okna, aktywnych leków i niedawnego kontekstu. Lokalna AI jest opcjonalna i tylko poleruje słownictwo.',
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
  },

  // ===========================================================================
  // ar (Arabic)
  // ===========================================================================
  'ar': {
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
    'next_meal.title': 'توصية الوجبة التالية',
    'next_meal.subtitle':
        'حدد أولاً الوقت المتوقع للوجبة التالية؛ سيعيد محرّك التعارض ترتيب 5 مرشحات وفق تلك النافذة الزمنية والأدوية النشطة والسياق الأخير. الذكاء الاصطناعي المحلي اختياري ولا يقوم إلا بتلميع الصياغة.',
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
  },
};
