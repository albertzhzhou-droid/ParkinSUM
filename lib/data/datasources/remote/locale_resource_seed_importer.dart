import '../../../domain/entities/cdss_records.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'p0_import_support.dart';

/// Locale resource seed importer.
///
/// Goal: extend the App's `locale_resource_bundle` table beyond the
/// project's original four built-in locales (`zh-CN`, `en`, `ja`, `fr`)
/// to the regions whose authoritative databases we now register through
/// `secondary_source_registry.dart`:
///   `ko-KR`, `hi-IN`, `es-ES`, `es-MX`, `vi-VN`, `th-TH`, `id-ID`,
///   `ru-RU`, `pl-PL`, `ar-SA`.
///
/// What this seed covers (intentionally narrow):
/// - `food_categories` namespace: the eight `FoodCategory` enum values
///   translated for each new locale.
/// - `meal_slots` namespace: breakfast / lunch / dinner / snack labels.
/// - `texture_classes` namespace: liquid / soft / regular labels (used by
///   the conservative recommendation engine).
///
/// What this seed deliberately does NOT cover:
/// - The full UI string catalog. This seed only covers a small set of
///   app-level labels needed by the newly registered locales.
/// - Pluralization rules — every row is recorded with `pluralRule = null`
///   because plural rules are a UI concern.
/// - Authoritative regulatory or food-safety wording — locale rows are
///   user-facing labels for app categories, not authoritative guidance text.
///
/// Conservative boundaries:
/// - Importer-side helper only; reviewers are expected to QA translations.
///   An `audit_gaps.translation_quality_review` entry is emitted on the
///   accompanying `SourceDocumentRecord` to make this explicit.
/// - Each row carries `LOCALE_SEED_v1` as a stable seed identifier so a
///   future revision can replace these strings idempotently.
class LocaleResourceSeedImporter {
  const LocaleResourceSeedImporter();

  /// Build the full set of locale resource bundle rows.
  ///
  /// Namespaces emitted (in order):
  /// - `food_categories` — eight FoodCategory enum values
  /// - `meal_slots` — breakfast / lunch / dinner / snack
  /// - `texture_classes` — liquid / soft / regular
  /// - `nav` — bottom-navigation labels (`home`, `analytics`, `meals`,
  ///   `timeline`, `meds`, `catalog`)
  /// - `common` — shared UI verbs (`cancel`, `save`, `delete`, `edit`,
  ///   `confirm`, `close`, `sign_out`, `apply`, `done`, `error`)
  /// - `recommend.path` — recommendation engine path labels
  ///   (`hybrid_local_ai`, `conservative_safety_gate`,
  ///   `conservative_gate_block`, `fallback_invalid_ai`,
  ///   `conservative_cdss`)
  ///
  /// Flat keys are namespace-prefixed at insert time so the runtime
  /// `AppI18n.tr('nav.home')` lookup hits these rows directly.
  List<LocaleResourceBundleRecord> buildLocaleSeedBundles() {
    final rows = <LocaleResourceBundleRecord>[];
    void emit(String localeTag, String namespace, Map<String, String> map) {
      for (final entry in map.entries) {
        rows.add(LocaleResourceBundleRecord(
          localeTag: localeTag,
          namespace: namespace,
          key: entry.key,
          text: entry.value,
          pluralRule: null,
        ));
      }
    }

    for (final locale in _localeSeeds) {
      emit(locale.localeTag, 'food_categories', locale.foodCategories);
      emit(locale.localeTag, 'meal_slots', locale.mealSlots);
      emit(locale.localeTag, 'texture_classes', locale.textureClasses);
      emit(locale.localeTag, 'nav', locale.nav);
      emit(locale.localeTag, 'common', locale.common);
      // The recommendation-path label keys already contain a dot
      // (e.g. `'hybrid_local_ai'` lives under the `recommend.path` namespace
      // so the flat lookup key becomes `recommend.path.hybrid_local_ai`).
      emit(locale.localeTag, 'recommend.path', locale.recommendPath);
      // Region labels for the onboarding picker (`AppI18n.regionLabel(...)`
      // routes through `tr('region.<CODE>')` and so picks these up).
      emit(locale.localeTag, 'region', locale.regions);
    }
    return rows;
  }

  /// Build a `P0ImportBundle` containing one `SourceDocumentRecord` that
  /// records the seed rollout. The actual `LocaleResourceBundleRecord`s are
  /// written directly to the database by the orchestrator (the core
  /// `cdssService.importBundle` channel does not iterate locale bundles).
  P0ImportBundle buildAuditSourceDocument({
    required int rowCount,
    required Set<String> localeTags,
    required Set<String> namespaces,
    String? seedChecksum,
  }) {
    final sourceDocId = sourceDocumentId(
      sourceSystem: 'LOCALE_RESOURCE_SEED',
      externalKey: 'locale_seed_v1',
    );
    return P0ImportBundle(sourceDocuments: [
      buildSourceDocumentRecord(
        sourceDocId: sourceDocId,
        sourceFamily: 'LOCALE_RESOURCE_SEED',
        organization: 'ParkinSUM Companion (importer-side locale seed)',
        jurisdiction: 'GLOBAL',
        docType: 'locale_resource_seed',
        title: 'Locale resource seed v1 (regional namespaces)',
        originUrl: 'app://locale-resource-seed/v1',
        licenseNote:
            'Built-in locale seed. App-level UI labels only; not authoritative '
            'medical, regulatory, or food-safety wording.',
        language: 'multi',
        dataTier: KnowledgeDataTier.p2,
        ingestionStrategy: SourceIngestionStrategy.controlledExport,
        rawPayload: stringifyPayload({
          'row_count': rowCount,
          'locale_tags': localeTags.toList()..sort(),
          'namespaces': namespaces.toList()..sort(),
          // Persisted checksum lets the orchestrator no-op on repeated
          // `seedLocaleResourceBundles()` calls when the seed payload has
          // not changed since the last successful write.
          if (seedChecksum != null) 'seed_checksum': seedChecksum,
          'audit_gaps': <Map<String, Object?>>[
            ImporterAudit.auditGap(
              fieldName: 'translation_quality_review',
              reason: 'Translations are seed values for UX labels only. Native '
                  'reviewers should QA every locale before public release. '
                  'No translation contract is implied.',
              observedCount: rowCount,
            ),
            ImporterAudit.auditGap(
              fieldName: 'plural_rules',
              reason:
                  'pluralRule is null on every seeded row; plural handling is '
                  'a UI concern owned by `lib/core/i18n/app_i18n.dart` and is '
                  'intentionally out of the importer write area.',
              observedCount: rowCount,
            ),
            ImporterAudit.auditGap(
              fieldName: 'ui_string_catalog_coverage',
              reason: 'This seed covers food_categories, meal_slots, '
                  'texture_classes, nav, common, and recommend.path '
                  'namespaces. The full UI string catalog is still not '
                  'covered by this importer seed.',
              observedCount: namespaces.length,
            ),
          ],
          'parser_limitation':
              'Locale seed is a database-backed UI enrichment for selected '
                  'namespaces only. It does not guarantee full app string '
                  'coverage for the locale.',
        }),
      ),
    ]);
  }
}

class _LocaleSeed {
  final String localeTag;
  final Map<String, String> foodCategories;
  final Map<String, String> mealSlots;
  final Map<String, String> textureClasses;
  final Map<String, String> nav;
  final Map<String, String> common;
  final Map<String, String> recommendPath;
  final Map<String, String> regions;

  const _LocaleSeed({
    required this.localeTag,
    required this.foodCategories,
    required this.mealSlots,
    required this.textureClasses,
    required this.nav,
    required this.common,
    required this.recommendPath,
    required this.regions,
  });
}

const List<_LocaleSeed> _localeSeeds = <_LocaleSeed>[
  _LocaleSeed(
    localeTag: 'ko-KR',
    foodCategories: {
      'protein': '단백질',
      'carbs': '탄수화물',
      'vegetable': '채소',
      'fruit': '과일',
      'dairy': '유제품',
      'fat': '지방',
      'beverage': '음료',
      'other': '기타',
    },
    mealSlots: {
      'breakfast': '아침',
      'lunch': '점심',
      'dinner': '저녁',
      'snack': '간식',
    },
    textureClasses: {
      'liquid': '액체',
      'soft': '부드러움',
      'regular': '일반',
    },
    nav: {
      'home': '홈',
      'analytics': '분석',
      'meals': '식사',
      'timeline': '타임라인',
      'meds': '약물',
      'catalog': '카탈로그',
    },
    common: {
      'cancel': '취소',
      'save': '저장',
      'delete': '삭제',
      'edit': '편집',
      'confirm': '확인',
      'close': '닫기',
      'sign_out': '로그아웃',
      'apply': '적용',
      'done': '완료',
      'error': '오류',
    },
    recommendPath: {
      'hybrid_local_ai': '로컬 AI 보조 재정렬',
      'conservative_safety_gate': '보수 경로 (안전 게이트가 AI 차단)',
      'conservative_gate_block': '보수 경로 (로컬 AI 사용 불가)',
      'fallback_invalid_ai': '보수 경로 (AI 출력 검증 실패)',
      'conservative_cdss': '보수 CDSS 경로',
    },
    regions: {
      'CN': '중국',
      'US': '미국',
      'CA': '캐나다',
      'FR': '프랑스',
      'JP': '일본',
      'KR': '대한민국',
      'IN': '인도',
      'ES': '스페인',
      'MX': '멕시코',
      'VN': '베트남',
      'TH': '태국',
      'ID': '인도네시아',
      'RU': '러시아',
      'PL': '폴란드',
      'SA': '사우디아라비아',
    },
  ),
  _LocaleSeed(
    localeTag: 'hi-IN',
    foodCategories: {
      'protein': 'प्रोटीन',
      'carbs': 'कार्बोहाइड्रेट',
      'vegetable': 'सब्ज़ी',
      'fruit': 'फल',
      'dairy': 'डेयरी',
      'fat': 'वसा',
      'beverage': 'पेय',
      'other': 'अन्य',
    },
    mealSlots: {
      'breakfast': 'नाश्ता',
      'lunch': 'दोपहर का भोजन',
      'dinner': 'रात का भोजन',
      'snack': 'हल्का नाश्ता',
    },
    textureClasses: {
      'liquid': 'तरल',
      'soft': 'मुलायम',
      'regular': 'सामान्य',
    },
    nav: {
      'home': 'होम',
      'analytics': 'विश्लेषण',
      'meals': 'भोजन',
      'timeline': 'समयरेखा',
      'meds': 'दवाइयाँ',
      'catalog': 'सूची',
    },
    common: {
      'cancel': 'रद्द करें',
      'save': 'सहेजें',
      'delete': 'हटाएँ',
      'edit': 'संपादित करें',
      'confirm': 'पुष्टि करें',
      'close': 'बंद करें',
      'sign_out': 'साइन आउट',
      'apply': 'लागू करें',
      'done': 'हो गया',
      'error': 'त्रुटि',
    },
    recommendPath: {
      'hybrid_local_ai': 'स्थानीय AI सहायता पुनर्क्रम',
      'conservative_safety_gate': 'रूढ़िवादी पथ (सुरक्षा गेट ने AI रोका)',
      'conservative_gate_block': 'रूढ़िवादी पथ (स्थानीय AI अनुपलब्ध)',
      'fallback_invalid_ai': 'रूढ़िवादी पथ (AI आउटपुट सत्यापित नहीं)',
      'conservative_cdss': 'रूढ़िवादी CDSS पथ',
    },
    regions: {
      'CN': 'चीन',
      'US': 'संयुक्त राज्य अमेरिका',
      'CA': 'कनाडा',
      'FR': 'फ्रांस',
      'JP': 'जापान',
      'KR': 'दक्षिण कोरिया',
      'IN': 'भारत',
      'ES': 'स्पेन',
      'MX': 'मेक्सिको',
      'VN': 'वियतनाम',
      'TH': 'थाईलैंड',
      'ID': 'इंडोनेशिया',
      'RU': 'रूस',
      'PL': 'पोलैंड',
      'SA': 'सऊदी अरब',
    },
  ),
  _LocaleSeed(
    localeTag: 'es-ES',
    foodCategories: {
      'protein': 'Proteína',
      'carbs': 'Carbohidratos',
      'vegetable': 'Verdura',
      'fruit': 'Fruta',
      'dairy': 'Lácteos',
      'fat': 'Grasa',
      'beverage': 'Bebida',
      'other': 'Otro',
    },
    mealSlots: {
      'breakfast': 'Desayuno',
      'lunch': 'Almuerzo',
      'dinner': 'Cena',
      'snack': 'Tentempié',
    },
    textureClasses: {
      'liquid': 'Líquido',
      'soft': 'Blando',
      'regular': 'Normal',
    },
    nav: {
      'home': 'Inicio',
      'analytics': 'Análisis',
      'meals': 'Comidas',
      'timeline': 'Cronología',
      'meds': 'Medicación',
      'catalog': 'Catálogo',
    },
    common: {
      'cancel': 'Cancelar',
      'save': 'Guardar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'confirm': 'Confirmar',
      'close': 'Cerrar',
      'sign_out': 'Cerrar sesión',
      'apply': 'Aplicar',
      'done': 'Listo',
      'error': 'Error',
    },
    recommendPath: {
      'hybrid_local_ai': 'IA local asiste el reordenamiento',
      'conservative_safety_gate':
          'Ruta conservadora (puerta de seguridad bloqueó la IA)',
      'conservative_gate_block': 'Ruta conservadora (IA local no disponible)',
      'fallback_invalid_ai':
          'Ruta conservadora (salida de IA no superó la validación)',
      'conservative_cdss': 'Ruta CDSS conservadora',
    },
    regions: {
      'CN': 'China',
      'US': 'Estados Unidos',
      'CA': 'Canadá',
      'FR': 'Francia',
      'JP': 'Japón',
      'KR': 'Corea del Sur',
      'IN': 'India',
      'ES': 'España',
      'MX': 'México',
      'VN': 'Vietnam',
      'TH': 'Tailandia',
      'ID': 'Indonesia',
      'RU': 'Rusia',
      'PL': 'Polonia',
      'SA': 'Arabia Saudí',
    },
  ),
  _LocaleSeed(
    localeTag: 'es-MX',
    foodCategories: {
      'protein': 'Proteína',
      'carbs': 'Carbohidratos',
      'vegetable': 'Verdura',
      'fruit': 'Fruta',
      'dairy': 'Lácteos',
      'fat': 'Grasa',
      'beverage': 'Bebida',
      'other': 'Otro',
    },
    mealSlots: {
      'breakfast': 'Desayuno',
      'lunch': 'Comida',
      'dinner': 'Cena',
      'snack': 'Botana',
    },
    textureClasses: {
      'liquid': 'Líquido',
      'soft': 'Blando',
      'regular': 'Normal',
    },
    nav: {
      'home': 'Inicio',
      'analytics': 'Análisis',
      'meals': 'Comidas',
      'timeline': 'Cronología',
      'meds': 'Medicación',
      'catalog': 'Catálogo',
    },
    common: {
      'cancel': 'Cancelar',
      'save': 'Guardar',
      'delete': 'Eliminar',
      'edit': 'Editar',
      'confirm': 'Confirmar',
      'close': 'Cerrar',
      'sign_out': 'Cerrar sesión',
      'apply': 'Aplicar',
      'done': 'Listo',
      'error': 'Error',
    },
    recommendPath: {
      'hybrid_local_ai': 'IA local asiste el reordenamiento',
      'conservative_safety_gate':
          'Ruta conservadora (la compuerta de seguridad bloqueó la IA)',
      'conservative_gate_block': 'Ruta conservadora (IA local no disponible)',
      'fallback_invalid_ai':
          'Ruta conservadora (la salida de la IA no pasó la validación)',
      'conservative_cdss': 'Ruta CDSS conservadora',
    },
    regions: {
      'CN': 'China',
      'US': 'Estados Unidos',
      'CA': 'Canadá',
      'FR': 'Francia',
      'JP': 'Japón',
      'KR': 'Corea del Sur',
      'IN': 'India',
      'ES': 'España',
      'MX': 'México',
      'VN': 'Vietnam',
      'TH': 'Tailandia',
      'ID': 'Indonesia',
      'RU': 'Rusia',
      'PL': 'Polonia',
      'SA': 'Arabia Saudita',
    },
  ),
  _LocaleSeed(
    localeTag: 'vi-VN',
    foodCategories: {
      'protein': 'Chất đạm',
      'carbs': 'Tinh bột',
      'vegetable': 'Rau',
      'fruit': 'Trái cây',
      'dairy': 'Sữa',
      'fat': 'Chất béo',
      'beverage': 'Đồ uống',
      'other': 'Khác',
    },
    mealSlots: {
      'breakfast': 'Bữa sáng',
      'lunch': 'Bữa trưa',
      'dinner': 'Bữa tối',
      'snack': 'Ăn vặt',
    },
    textureClasses: {
      'liquid': 'Lỏng',
      'soft': 'Mềm',
      'regular': 'Thường',
    },
    nav: {
      'home': 'Trang chủ',
      'analytics': 'Phân tích',
      'meals': 'Bữa ăn',
      'timeline': 'Dòng thời gian',
      'meds': 'Thuốc',
      'catalog': 'Danh mục',
    },
    common: {
      'cancel': 'Hủy',
      'save': 'Lưu',
      'delete': 'Xóa',
      'edit': 'Sửa',
      'confirm': 'Xác nhận',
      'close': 'Đóng',
      'sign_out': 'Đăng xuất',
      'apply': 'Áp dụng',
      'done': 'Xong',
      'error': 'Lỗi',
    },
    recommendPath: {
      'hybrid_local_ai': 'AI cục bộ hỗ trợ sắp xếp lại',
      'conservative_safety_gate': 'Đường dẫn thận trọng (cổng an toàn chặn AI)',
      'conservative_gate_block':
          'Đường dẫn thận trọng (AI cục bộ không khả dụng)',
      'fallback_invalid_ai':
          'Đường dẫn thận trọng (đầu ra AI không qua kiểm tra)',
      'conservative_cdss': 'Đường dẫn CDSS thận trọng',
    },
    regions: {
      'CN': 'Trung Quốc',
      'US': 'Hoa Kỳ',
      'CA': 'Canada',
      'FR': 'Pháp',
      'JP': 'Nhật Bản',
      'KR': 'Hàn Quốc',
      'IN': 'Ấn Độ',
      'ES': 'Tây Ban Nha',
      'MX': 'México',
      'VN': 'Việt Nam',
      'TH': 'Thái Lan',
      'ID': 'Indonesia',
      'RU': 'Nga',
      'PL': 'Ba Lan',
      'SA': 'Ả Rập Xê Út',
    },
  ),
  _LocaleSeed(
    localeTag: 'th-TH',
    foodCategories: {
      'protein': 'โปรตีน',
      'carbs': 'คาร์โบไฮเดรต',
      'vegetable': 'ผัก',
      'fruit': 'ผลไม้',
      'dairy': 'ผลิตภัณฑ์นม',
      'fat': 'ไขมัน',
      'beverage': 'เครื่องดื่ม',
      'other': 'อื่น ๆ',
    },
    mealSlots: {
      'breakfast': 'อาหารเช้า',
      'lunch': 'อาหารกลางวัน',
      'dinner': 'อาหารเย็น',
      'snack': 'ของว่าง',
    },
    textureClasses: {
      'liquid': 'ของเหลว',
      'soft': 'นุ่ม',
      'regular': 'ปกติ',
    },
    nav: {
      'home': 'หน้าแรก',
      'analytics': 'การวิเคราะห์',
      'meals': 'มื้ออาหาร',
      'timeline': 'ไทม์ไลน์',
      'meds': 'ยา',
      'catalog': 'แค็ตตาล็อก',
    },
    common: {
      'cancel': 'ยกเลิก',
      'save': 'บันทึก',
      'delete': 'ลบ',
      'edit': 'แก้ไข',
      'confirm': 'ยืนยัน',
      'close': 'ปิด',
      'sign_out': 'ออกจากระบบ',
      'apply': 'นำไปใช้',
      'done': 'เสร็จสิ้น',
      'error': 'ข้อผิดพลาด',
    },
    recommendPath: {
      'hybrid_local_ai': 'AI ในเครื่องช่วยจัดอันดับใหม่',
      'conservative_safety_gate':
          'เส้นทางอนุรักษ์นิยม (ประตูความปลอดภัยปิด AI)',
      'conservative_gate_block': 'เส้นทางอนุรักษ์นิยม (AI ในเครื่องใช้ไม่ได้)',
      'fallback_invalid_ai':
          'เส้นทางอนุรักษ์นิยม (ผลลัพธ์ AI ไม่ผ่านการตรวจสอบ)',
      'conservative_cdss': 'เส้นทาง CDSS อนุรักษ์นิยม',
    },
    regions: {
      'CN': 'จีน',
      'US': 'สหรัฐอเมริกา',
      'CA': 'แคนาดา',
      'FR': 'ฝรั่งเศส',
      'JP': 'ญี่ปุ่น',
      'KR': 'เกาหลีใต้',
      'IN': 'อินเดีย',
      'ES': 'สเปน',
      'MX': 'เม็กซิโก',
      'VN': 'เวียดนาม',
      'TH': 'ไทย',
      'ID': 'อินโดนีเซีย',
      'RU': 'รัสเซีย',
      'PL': 'โปแลนด์',
      'SA': 'ซาอุดีอาระเบีย',
    },
  ),
  _LocaleSeed(
    localeTag: 'id-ID',
    foodCategories: {
      'protein': 'Protein',
      'carbs': 'Karbohidrat',
      'vegetable': 'Sayuran',
      'fruit': 'Buah',
      'dairy': 'Produk susu',
      'fat': 'Lemak',
      'beverage': 'Minuman',
      'other': 'Lainnya',
    },
    mealSlots: {
      'breakfast': 'Sarapan',
      'lunch': 'Makan siang',
      'dinner': 'Makan malam',
      'snack': 'Camilan',
    },
    textureClasses: {
      'liquid': 'Cair',
      'soft': 'Lembut',
      'regular': 'Biasa',
    },
    nav: {
      'home': 'Beranda',
      'analytics': 'Analitik',
      'meals': 'Makanan',
      'timeline': 'Linimasa',
      'meds': 'Obat',
      'catalog': 'Katalog',
    },
    common: {
      'cancel': 'Batal',
      'save': 'Simpan',
      'delete': 'Hapus',
      'edit': 'Sunting',
      'confirm': 'Konfirmasi',
      'close': 'Tutup',
      'sign_out': 'Keluar',
      'apply': 'Terapkan',
      'done': 'Selesai',
      'error': 'Kesalahan',
    },
    recommendPath: {
      'hybrid_local_ai': 'AI lokal membantu pengurutan ulang',
      'conservative_safety_gate':
          'Jalur konservatif (gerbang keselamatan memblokir AI)',
      'conservative_gate_block': 'Jalur konservatif (AI lokal tidak tersedia)',
      'fallback_invalid_ai':
          'Jalur konservatif (output AI tidak lolos validasi)',
      'conservative_cdss': 'Jalur CDSS konservatif',
    },
    regions: {
      'CN': 'Tiongkok',
      'US': 'Amerika Serikat',
      'CA': 'Kanada',
      'FR': 'Prancis',
      'JP': 'Jepang',
      'KR': 'Korea Selatan',
      'IN': 'India',
      'ES': 'Spanyol',
      'MX': 'Meksiko',
      'VN': 'Vietnam',
      'TH': 'Thailand',
      'ID': 'Indonesia',
      'RU': 'Rusia',
      'PL': 'Polandia',
      'SA': 'Arab Saudi',
    },
  ),
  _LocaleSeed(
    localeTag: 'ru-RU',
    foodCategories: {
      'protein': 'Белок',
      'carbs': 'Углеводы',
      'vegetable': 'Овощи',
      'fruit': 'Фрукты',
      'dairy': 'Молочные продукты',
      'fat': 'Жиры',
      'beverage': 'Напиток',
      'other': 'Другое',
    },
    mealSlots: {
      'breakfast': 'Завтрак',
      'lunch': 'Обед',
      'dinner': 'Ужин',
      'snack': 'Перекус',
    },
    textureClasses: {
      'liquid': 'Жидкость',
      'soft': 'Мягкий',
      'regular': 'Обычный',
    },
    nav: {
      'home': 'Главная',
      'analytics': 'Аналитика',
      'meals': 'Питание',
      'timeline': 'Хронология',
      'meds': 'Лекарства',
      'catalog': 'Каталог',
    },
    common: {
      'cancel': 'Отмена',
      'save': 'Сохранить',
      'delete': 'Удалить',
      'edit': 'Изменить',
      'confirm': 'Подтвердить',
      'close': 'Закрыть',
      'sign_out': 'Выйти',
      'apply': 'Применить',
      'done': 'Готово',
      'error': 'Ошибка',
    },
    recommendPath: {
      'hybrid_local_ai': 'Локальный ИИ переупорядочивает результаты',
      'conservative_safety_gate':
          'Консервативный путь (защитный шлюз заблокировал ИИ)',
      'conservative_gate_block':
          'Консервативный путь (локальный ИИ недоступен)',
      'fallback_invalid_ai':
          'Консервативный путь (вывод ИИ не прошёл проверку)',
      'conservative_cdss': 'Консервативный путь CDSS',
    },
    regions: {
      'CN': 'Китай',
      'US': 'США',
      'CA': 'Канада',
      'FR': 'Франция',
      'JP': 'Япония',
      'KR': 'Южная Корея',
      'IN': 'Индия',
      'ES': 'Испания',
      'MX': 'Мексика',
      'VN': 'Вьетнам',
      'TH': 'Таиланд',
      'ID': 'Индонезия',
      'RU': 'Россия',
      'PL': 'Польша',
      'SA': 'Саудовская Аравия',
    },
  ),
  _LocaleSeed(
    localeTag: 'pl-PL',
    foodCategories: {
      'protein': 'Białko',
      'carbs': 'Węglowodany',
      'vegetable': 'Warzywa',
      'fruit': 'Owoce',
      'dairy': 'Nabiał',
      'fat': 'Tłuszcze',
      'beverage': 'Napój',
      'other': 'Inne',
    },
    mealSlots: {
      'breakfast': 'Śniadanie',
      'lunch': 'Obiad',
      'dinner': 'Kolacja',
      'snack': 'Przekąska',
    },
    textureClasses: {
      'liquid': 'Płyn',
      'soft': 'Miękki',
      'regular': 'Zwykły',
    },
    nav: {
      'home': 'Start',
      'analytics': 'Analiza',
      'meals': 'Posiłki',
      'timeline': 'Oś czasu',
      'meds': 'Leki',
      'catalog': 'Katalog',
    },
    common: {
      'cancel': 'Anuluj',
      'save': 'Zapisz',
      'delete': 'Usuń',
      'edit': 'Edytuj',
      'confirm': 'Potwierdź',
      'close': 'Zamknij',
      'sign_out': 'Wyloguj',
      'apply': 'Zastosuj',
      'done': 'Gotowe',
      'error': 'Błąd',
    },
    recommendPath: {
      'hybrid_local_ai': 'Lokalna AI pomaga w przeszeregowaniu',
      'conservative_safety_gate':
          'Ścieżka zachowawcza (bramka bezpieczeństwa zablokowała AI)',
      'conservative_gate_block': 'Ścieżka zachowawcza (lokalna AI niedostępna)',
      'fallback_invalid_ai':
          'Ścieżka zachowawcza (wyjście AI nie przeszło walidacji)',
      'conservative_cdss': 'Ścieżka zachowawcza CDSS',
    },
    regions: {
      'CN': 'Chiny',
      'US': 'Stany Zjednoczone',
      'CA': 'Kanada',
      'FR': 'Francja',
      'JP': 'Japonia',
      'KR': 'Korea Południowa',
      'IN': 'Indie',
      'ES': 'Hiszpania',
      'MX': 'Meksyk',
      'VN': 'Wietnam',
      'TH': 'Tajlandia',
      'ID': 'Indonezja',
      'RU': 'Rosja',
      'PL': 'Polska',
      'SA': 'Arabia Saudyjska',
    },
  ),
  _LocaleSeed(
    localeTag: 'ar-SA',
    foodCategories: {
      'protein': 'بروتين',
      'carbs': 'كربوهيدرات',
      'vegetable': 'خضروات',
      'fruit': 'فاكهة',
      'dairy': 'ألبان',
      'fat': 'دهون',
      'beverage': 'مشروب',
      'other': 'أخرى',
    },
    mealSlots: {
      'breakfast': 'الإفطار',
      'lunch': 'الغداء',
      'dinner': 'العشاء',
      'snack': 'وجبة خفيفة',
    },
    textureClasses: {
      'liquid': 'سائل',
      'soft': 'ناعم',
      'regular': 'عادي',
    },
    nav: {
      'home': 'الرئيسية',
      'analytics': 'التحليلات',
      'meals': 'الوجبات',
      'timeline': 'المخطط الزمني',
      'meds': 'الأدوية',
      'catalog': 'الكتالوج',
    },
    common: {
      'cancel': 'إلغاء',
      'save': 'حفظ',
      'delete': 'حذف',
      'edit': 'تعديل',
      'confirm': 'تأكيد',
      'close': 'إغلاق',
      'sign_out': 'تسجيل الخروج',
      'apply': 'تطبيق',
      'done': 'تم',
      'error': 'خطأ',
    },
    recommendPath: {
      'hybrid_local_ai': 'الذكاء الاصطناعي المحلي يعيد الترتيب',
      'conservative_safety_gate':
          'مسار محافظ (بوابة الأمان حجبت الذكاء الاصطناعي)',
      'conservative_gate_block':
          'مسار محافظ (الذكاء الاصطناعي المحلي غير متاح)',
      'fallback_invalid_ai':
          'مسار محافظ (مخرج الذكاء الاصطناعي لم يجتز التحقق)',
      'conservative_cdss': 'مسار CDSS المحافظ',
    },
    regions: {
      'CN': 'الصين',
      'US': 'الولايات المتحدة',
      'CA': 'كندا',
      'FR': 'فرنسا',
      'JP': 'اليابان',
      'KR': 'كوريا الجنوبية',
      'IN': 'الهند',
      'ES': 'إسبانيا',
      'MX': 'المكسيك',
      'VN': 'فيتنام',
      'TH': 'تايلاند',
      'ID': 'إندونيسيا',
      'RU': 'روسيا',
      'PL': 'بولندا',
      'SA': 'المملكة العربية السعودية',
    },
  ),
];
