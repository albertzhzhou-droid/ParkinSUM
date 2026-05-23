import '../../../domain/entities/cdss_records.dart';

/// Tier classification for *secondary* official sources.
///
/// Tier semantics (importer-local; consumed via `source_document.data_tier`
/// using `KnowledgeDataTier` constants):
///
/// - P1: Directly relevant to Parkinson's pharmacology or food safety, but
///   the importer cannot promote upstream body content into structured facts
///   today. Landing-page metadata is registered so downstream consumers can
///   link out without the importer pretending to parse the content.
/// - P2: Supportive nutrition / drug-classification reference. Useful for
///   cross-jurisdiction normalization or consumer-grade labels but not
///   primary clinical truth.
/// - P3: Regional or legacy reference compositions. Kept for completeness
///   so that audits show we recorded the source exists, even though the
///   importer does not parse it.
class SecondarySourceDeclaration {
  /// One of `KnowledgeDataTier.p1` / `p2` / `p3`.
  final String dataTier;

  /// Stable internal key. Becomes the `sourceFamily` and feeds
  /// `sourceDocumentId(sourceSystem, externalKey)`.
  final String sourceFamily;
  final String organization;
  final String jurisdiction;
  final String landingUrl;
  final String docType;
  final String language;
  final String licenseNote;
  final String tierRationale;

  const SecondarySourceDeclaration({
    required this.dataTier,
    required this.sourceFamily,
    required this.organization,
    required this.jurisdiction,
    required this.landingUrl,
    required this.docType,
    required this.language,
    required this.licenseNote,
    required this.tierRationale,
  });
}

/// Declared catalog of additional authoritative sources we register at
/// landing-page-metadata level only. All entries are intentionally
/// non-parsed; the importer only writes one `source_document` row per entry.
const List<SecondarySourceDeclaration> kSecondarySources = [
  // ---------- P1: Parkinson's-relevant clinical / regulatory references ----
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p1,
    sourceFamily: 'WHO_ATC_DDD',
    organization: 'WHO Collaborating Centre for Drug Statistics Methodology',
    jurisdiction: 'GLOBAL',
    landingUrl: 'https://www.whocc.no/atc_ddd_index/',
    docType: 'atc_ddd_index_landing',
    language: 'en',
    licenseNote:
        'WHO ATC/DDD index is freely accessible for non-commercial reference use; '
        'commercial redistribution requires a separate license.',
    tierRationale:
        'Authoritative ATC classification used to normalize drug concepts '
        'across DailyMed / EMA / PMDA / DPD jurisdictions.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p1,
    sourceFamily: 'NICE_NG71',
    organization: 'National Institute for Health and Care Excellence',
    jurisdiction: 'UK',
    landingUrl: 'https://www.nice.org.uk/guidance/ng71',
    docType: 'clinical_guideline_landing',
    language: 'en',
    licenseNote:
        'NICE guidance is Crown copyright; reuse must comply with NICE terms.',
    tierRationale:
        "NICE NG71 covers Parkinson's disease in adults; importer registers "
        'the landing page only and does not parse the guideline body.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p1,
    sourceFamily: 'MEDLINEPLUS_DRUGS',
    organization: 'U.S. National Library of Medicine',
    jurisdiction: 'US',
    landingUrl: 'https://medlineplus.gov/druginformation.html',
    docType: 'consumer_drug_information_landing',
    language: 'en',
    licenseNote:
        'MedlinePlus content is in the public domain except where noted; '
        'attribution required.',
    tierRationale:
        'Consumer-level drug information used as a cross-reference target. '
        'Authoritative SPL content still comes from DailyMed.',
  ),

  // ---------- P2: supportive nutrition / cross-walk references ------------
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p2,
    sourceFamily: 'OPEN_FOOD_FACTS',
    organization: 'Open Food Facts',
    jurisdiction: 'GLOBAL',
    landingUrl: 'https://world.openfoodfacts.org/data',
    docType: 'community_food_database_landing',
    language: 'en',
    licenseNote:
        'Open Food Facts data is licensed under ODbL 1.0; product images may '
        'have separate licenses. Treat as community-curated, not authoritative.',
    tierRationale:
        'Useful for branded/packaged-product crosswalks. Treated as supportive '
        'reference; not promoted into authoritative food facts.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p2,
    sourceFamily: 'USDA_DGA',
    organization: 'U.S. Departments of Agriculture and Health & Human Services',
    jurisdiction: 'US',
    landingUrl: 'https://www.dietaryguidelines.gov/',
    docType: 'dietary_guidelines_landing',
    language: 'en',
    licenseNote: 'U.S. Government work in the public domain.',
    tierRationale:
        'Supportive nutritional reference for US recommendations; importer '
        'registers the landing page only, no body parsing.',
  ),

  // ---------- P1/P2: regional authoritative databases (KR/IN/ES/MX/SEA/EE/RU/MENA) -

  // Korea
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p1,
    sourceFamily: 'KR_MFDS',
    organization: 'Ministry of Food and Drug Safety (Korea)',
    jurisdiction: 'KR',
    landingUrl: 'https://www.mfds.go.kr/eng/',
    docType: 'drug_food_regulator_landing',
    language: 'en',
    licenseNote:
        'Korean MFDS regulator landing; redistribution per MFDS terms.',
    tierRationale:
        'Korean drug + food authority; landing-page-only entry until a stable '
        'export endpoint is added.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p2,
    sourceFamily: 'KR_RDA_FOOD_COMPOSITION',
    organization: 'Rural Development Administration / National Institute of '
        'Agricultural Sciences (Korea)',
    jurisdiction: 'KR',
    landingUrl: 'https://koreanfood.rda.go.kr/',
    docType: 'food_composition_landing',
    language: 'ko',
    licenseNote: 'RDA-NIAS portal; reuse per RDA terms.',
    tierRationale:
        'Authoritative Korean food composition portal; importer registers '
        'landing only, no body parsing.',
  ),

  // South Asia (India)
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p1,
    sourceFamily: 'IN_CDSCO',
    organization: 'Central Drugs Standard Control Organisation (India)',
    jurisdiction: 'IN',
    landingUrl: 'https://cdsco.gov.in/opencms/opencms/en/Home/',
    docType: 'drug_regulator_landing',
    language: 'en',
    licenseNote: 'Government of India open data; reuse per CDSCO terms.',
    tierRationale:
        'Indian drug regulator; landing-page-only entry, no structured '
        'parsing yet.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p2,
    sourceFamily: 'IN_IFCT_NIN',
    organization: 'National Institute of Nutrition / Indian Council of Medical '
        'Research (Indian Food Composition Tables)',
    jurisdiction: 'IN',
    landingUrl: 'https://www.nin.res.in/',
    docType: 'food_composition_landing',
    language: 'en',
    licenseNote: 'IFCT data; reuse per NIN-ICMR terms.',
    tierRationale:
        'Indian food composition reference (IFCT). Registered as P2 reference '
        'until structured import is added.',
  ),

  // Mediterranean / Spain
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p1,
    sourceFamily: 'ES_AEMPS',
    organization: 'Agencia Española de Medicamentos y Productos Sanitarios',
    jurisdiction: 'ES',
    landingUrl: 'https://www.aemps.gob.es/',
    docType: 'drug_regulator_landing',
    language: 'es',
    licenseNote: 'Spanish public agency; reuse per AEMPS terms.',
    tierRationale: 'Spanish drug regulator; landing-page-only entry. EMA still '
        'authoritative for centralised products.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p2,
    sourceFamily: 'ES_BEDCA',
    organization: 'Base de Datos Española de Composición de Alimentos (BEDCA)',
    jurisdiction: 'ES',
    landingUrl: 'https://www.bedca.net/',
    docType: 'food_composition_landing',
    language: 'es',
    licenseNote: 'BEDCA portal; reuse per BEDCA terms.',
    tierRationale:
        'Spanish food composition reference covering the Mediterranean diet '
        'pattern. Registered as a P2 reference.',
  ),

  // Latin America (Mexico)
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p1,
    sourceFamily: 'MX_COFEPRIS',
    organization:
        'Comisión Federal para la Protección contra Riesgos Sanitarios',
    jurisdiction: 'MX',
    landingUrl: 'https://www.gob.mx/cofepris',
    docType: 'drug_regulator_landing',
    language: 'es',
    licenseNote: 'Mexican government open data; reuse per COFEPRIS terms.',
    tierRationale: 'Mexican drug + food regulator; landing-page-only entry.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p2,
    sourceFamily: 'LATAM_INCAP',
    organization: 'Instituto de Nutrición de Centro América y Panamá (INCAP)',
    jurisdiction: 'LATAM',
    landingUrl: 'https://www.incap.int/',
    docType: 'food_composition_landing',
    language: 'es',
    licenseNote: 'INCAP portal; reuse per INCAP terms.',
    tierRationale:
        'Latin American (Central America + Panama) regional food composition '
        'reference. Registered as P2.',
  ),

  // Southeast Asia
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p2,
    sourceFamily: 'ASEAN_FCDB',
    organization: 'ASEAN Food Composition Database (Mahidol Univ., INMU)',
    jurisdiction: 'SEA',
    landingUrl: 'https://inmu2.mahidol.ac.th/aseanfoods/',
    docType: 'food_composition_landing',
    language: 'en',
    licenseNote: 'ASEAN regional reference; reuse per INMU terms.',
    tierRationale:
        'Regional Southeast Asia food composition database; registered as '
        'P2 reference.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p1,
    sourceFamily: 'TH_FDA',
    organization: 'Thai Food and Drug Administration (Thai FDA)',
    jurisdiction: 'TH',
    landingUrl: 'https://www.fda.moph.go.th/sites/oss/SitePages/Home.aspx',
    docType: 'drug_regulator_landing',
    language: 'th',
    licenseNote: 'Thai government public site; reuse per Thai FDA terms.',
    tierRationale:
        'Representative SEA national drug regulator; landing-page-only '
        'entry. Indonesia BPOM / Vietnam DAV / Singapore HSA are intentionally '
        'left for future rounds rather than fabricated.',
  ),

  // Eastern Europe / Russia
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p1,
    sourceFamily: 'RU_ROSZDRAVNADZOR',
    organization: 'Roszdravnadzor (Federal Service for Surveillance in '
        'Healthcare, Russia)',
    jurisdiction: 'RU',
    landingUrl: 'https://roszdravnadzor.gov.ru/',
    docType: 'drug_regulator_landing',
    language: 'ru',
    licenseNote: 'Russian government public site; reuse per agency terms.',
    tierRationale: 'Russian drug regulator; landing-page-only entry.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p2,
    sourceFamily: 'RU_FRC_NUTRITION',
    organization:
        'Federal Research Centre of Nutrition, Biotechnology and Food Safety '
        '(Russia)',
    jurisdiction: 'RU',
    landingUrl: 'https://ion.ru/',
    docType: 'food_composition_landing',
    language: 'ru',
    licenseNote: 'Russian public research portal; reuse per FRCN terms.',
    tierRationale:
        'Authoritative Russian food composition reference (Skurikhin tables '
        'tradition). Registered as P2.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p2,
    sourceFamily: 'PL_NIZP_PZH',
    organization: 'Narodowy Instytut Zdrowia Publicznego — PZH (Poland)',
    jurisdiction: 'PL',
    landingUrl: 'https://www.pzh.gov.pl/',
    docType: 'food_composition_landing',
    language: 'pl',
    licenseNote: 'Polish public health institute; reuse per NIZP-PZH terms.',
    tierRationale:
        'Eastern European / Polish food + nutrition reference; registered as '
        'P2.',
  ),

  // MENA
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p1,
    sourceFamily: 'SA_SFDA',
    organization: 'Saudi Food and Drug Authority',
    jurisdiction: 'SA',
    landingUrl: 'https://www.sfda.gov.sa/en',
    docType: 'drug_regulator_landing',
    language: 'en',
    licenseNote: 'Saudi government public site; reuse per SFDA terms.',
    tierRationale:
        'Saudi Arabian drug + food regulator covering the Gulf region; '
        'landing-page-only entry.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p2,
    sourceFamily: 'EG_NRC_FOOD_COMPOSITION',
    organization: 'National Research Centre, Food Composition Tables (Egypt)',
    jurisdiction: 'EG',
    landingUrl: 'https://www.nrc.sci.eg/',
    docType: 'food_composition_landing',
    language: 'ar',
    licenseNote: 'Egyptian public research portal; reuse per NRC terms.',
    tierRationale:
        'North African / Egyptian food composition reference; registered as '
        'P2.',
  ),

  // ---------- P3: regional / legacy composition tables --------------------
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p3,
    sourceFamily: 'AUSNUT_2011_13',
    organization: 'Food Standards Australia New Zealand',
    jurisdiction: 'AU',
    landingUrl:
        'https://www.foodstandards.gov.au/science-data/monitoringnutrients/ausnut',
    docType: 'food_composition_landing',
    language: 'en',
    licenseNote: 'AUSNUT data redistribution under FSANZ terms.',
    tierRationale:
        'Regional Australia/New Zealand composition reference; legacy 2011-13 '
        'release. Registered as P3 reference only.',
  ),
  SecondarySourceDeclaration(
    dataTier: KnowledgeDataTier.p3,
    sourceFamily: 'MEXT_FOOD_COMPOSITION',
    organization:
        'Ministry of Education, Culture, Sports, Science and Technology (Japan)',
    jurisdiction: 'JP',
    landingUrl: 'https://www.mext.go.jp/a_menu/syokuhinseibun/',
    docType: 'food_composition_landing',
    language: 'ja',
    licenseNote:
        'Japanese government work; redistribution permitted under MEXT terms.',
    tierRationale:
        'Japan Standard Tables of Food Composition. Registered as P3 reference; '
        'PMDA remains the authoritative drug source for JP.',
  ),
];
