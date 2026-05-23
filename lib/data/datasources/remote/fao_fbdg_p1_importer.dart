import 'dart:convert';

import '../../../domain/entities/cdss_records.dart';
import 'crosswalk_builders.dart';
import 'importer_audit.dart';
import 'p0_import_models.dart';
import 'source_fetch_client.dart';

/// FAO FBDG P1 importer:
/// - 面向官方饮食指南页面，不进入主营养事实表；
/// - 输出 `source_document` + `country_diet_profile`；
/// - 当前按页面级 HTML 解析，不假装成稳定 bulk API。
class FaoFbdgP1Importer {
  final SourceFetchClient fetchClient;

  const FaoFbdgP1Importer({required this.fetchClient});

  Future<P0ImportBundle> fetchCountryPage({
    required String countryCode,
    required String url,
  }) async {
    final html = await fetchClient.getText(url);
    return importCountryPage(
      countryCode: countryCode,
      url: url,
      html: html,
    );
  }

  P0ImportBundle importCountryPage({
    required String countryCode,
    required String url,
    required String html,
  }) {
    final normalized = _normalizeText(html);
    final title = _extractTitle(normalized, countryCode);
    final messages = _extractMessages(normalized);
    final mealPattern = <String, dynamic>{
      'preferred_meal_slots': ['breakfast', 'lunch', 'dinner'],
      'regular_hours_emphasis': true,
    };

    final stapleFoods = <String>[
      if (_containsAny(messages, ['whole grains', 'grains'])) 'whole_grains',
      if (_containsAny(messages, ['cereals'])) 'cereals',
      if (_containsAny(messages, ['tubers'])) 'tubers',
      if (_containsAny(messages, ['rice'])) 'rice',
      if (_containsAny(messages, ['noodles'])) 'noodles',
    ];
    final proteinSources = <String>[
      if (_containsAny(messages, ['soybeans', 'beans'])) 'soybeans',
      if (_containsAny(messages, ['fish'])) 'fish',
      if (_containsAny(messages, ['poultry'])) 'poultry',
      if (_containsAny(messages, ['eggs'])) 'eggs',
      if (_containsAny(messages, ['lean meats', 'lean meat'])) 'lean_meat',
      if (_containsAny(messages, ['dairy', 'milk'])) 'dairy',
    ];
    final avoidanceNotes = <String>[
      if (_containsAny(messages, ['salt'])) 'reduce_salt',
      if (_containsAny(messages, ['sugar'])) 'limit_sugar',
      if (_containsAny(messages, ['oil'])) 'limit_oil',
      if (_containsAny(messages, ['water'])) 'adequate_water',
    ];

    final sourceDocId =
        'source_fao_fbdg_${countryCode.toLowerCase()}_${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';

    return P0ImportBundle(
      sourceDocuments: [
        SourceDocumentRecord(
          sourceDocId: sourceDocId,
          sourceFamily: 'FAO_FBDG',
          dataTier: KnowledgeDataTier.p1,
          ingestionStrategy: SourceIngestionStrategy.officialReference,
          organization: 'FAO',
          jurisdiction: countryCode.toUpperCase(),
          docType: 'html_country_page',
          title: title,
          originUrl: url,
          publishedAt: null,
          effectiveAt: null,
          language: 'en',
          licenseNote: 'UNSPECIFIED',
          checksum: sourceDocId,
          sourceStatus: 'active',
          rawPayload: jsonEncode({
            'messages': messages,
            'importer': 'fao_fbdg_p1_importer',
            'country_code': countryCode.toUpperCase(),
          }),
        ),
      ],
      conceptVariantCrosswalks: [
        buildCrosswalk(
          domain: 'country_diet_profile',
          conceptId: 'FBDG_${countryCode.toUpperCase()}',
          variantId: 'fbdg_${countryCode.toLowerCase()}',
          externalIdSystem: 'FAO FBDG country code',
          externalIdValue: countryCode.toUpperCase(),
          jurisdiction: countryCode.toUpperCase(),
          sourceDocId: sourceDocId,
          confidence: 1.0,
          mappingPayload: {
            'guideline_source': title,
            'origin_url': url,
            'message_count': messages.length,
            'region_or_city_identifier': null,
            'region_or_city_audit_note':
                'Country-level crosswalk only; FAO FBDG country pages do not expose stable region/city identifiers, so none were emitted.',
            ...ImporterAudit.confidenceReason(
              sourceIdentifierType:
                  ImporterAudit.sourceIdTypeCountryDietProfile,
              reason:
                  'Country code provided by caller and matches FAO country page slug.',
              promotionDecision: 'country_level_only_no_subnational_promotion',
              parserLimitation:
                  'No region/city identifier scheme detected; importer refuses to fabricate one.',
            ),
          },
        ),
      ],
      countryDietProfiles: [
        CountryDietProfileRecord(
          countryCode: countryCode.toUpperCase(),
          guidelineSource: title,
          mealPatternJson: jsonEncode(mealPattern),
          stapleFoodsJson: jsonEncode(stapleFoods),
          preferredProteinSourcesJson: jsonEncode(proteinSources),
          avoidanceNotesJson: jsonEncode(avoidanceNotes),
        ),
      ],
    );
  }

  String _extractTitle(String text, String countryCode) {
    final officialName = _firstMatch(
        text, RegExp(r'Official name\s+([^\n]+)', caseSensitive: false));
    if (officialName != null && officialName.trim().isNotEmpty) {
      return officialName.trim();
    }
    return 'FAO FBDG ${countryCode.toUpperCase()}';
  }

  List<String> _extractMessages(String text) {
    final sectionMatch = RegExp(
      r'Messages\s+([\s\S]+?)(?:Food guide|Country resources|Contact institution|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (sectionMatch == null) {
      return const <String>[];
    }
    final section = sectionMatch.group(1) ?? '';
    return section
        .split('\n')
        .map((line) => line.trim())
        .where((line) => RegExp(r'^\d+\.').hasMatch(line))
        .map((line) => line.replaceFirst(RegExp(r'^\d+\.\s*'), '').trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }

  bool _containsAny(List<String> messages, List<String> needles) {
    final haystack = messages.join(' ').toLowerCase();
    return needles.any((needle) => haystack.contains(needle.toLowerCase()));
  }

  String _normalizeText(String html) {
    return html
        .replaceAll(
            RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), ' ')
        .replaceAll(
            RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), '\n')
        .replaceAll('&nbsp;', ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n+'), '\n');
  }

  String? _firstMatch(String input, RegExp exp) =>
      exp.firstMatch(input)?.group(1);
}
