import '../../../domain/entities/source_metadata.dart';

/// Access method for a source.
enum SourceAccessMethod { api, download, webPage, manualImport, future }

/// Metadata spec for an import source. This is the source-agnostic
/// description the app uses to reason about *which* source a fact came from,
/// its authority, language, and limitations — independent of the concrete
/// parser. The 8 existing importers are wrapped by adapters that carry one
/// of these specs; source families with no importer yet still have a spec.
class SourceAdapterSpec {
  final String sourceSystem;
  final String jurisdiction;
  final String countryOrRegion;
  final String language;
  final String sourceOwner;
  final SourceAuthorityTier authorityTier;
  final SourceAccessMethod accessMethod;
  final List<String> supportedDocumentTypes;
  final String updateCadence;
  final String licenseOrUseLimitations;
  final String lastChecked;
  final double parserConfidence; // 0..1
  final ReferenceTranslationStatus translationStatus;
  final bool isMedicationSource;
  final bool isFoodSource;
  final bool implemented; // true if a concrete parser exists today
  final List<String> knownLimitations;
  final List<String> sourceRefs;

  const SourceAdapterSpec({
    required this.sourceSystem,
    required this.jurisdiction,
    required this.countryOrRegion,
    required this.language,
    required this.sourceOwner,
    required this.authorityTier,
    required this.accessMethod,
    required this.supportedDocumentTypes,
    required this.updateCadence,
    required this.licenseOrUseLimitations,
    required this.lastChecked,
    required this.parserConfidence,
    required this.translationStatus,
    required this.isMedicationSource,
    required this.isFoodSource,
    required this.implemented,
    required this.knownLimitations,
    required this.sourceRefs,
  });

  Map<String, dynamic> toJson() => {
        'source_system': sourceSystem,
        'jurisdiction': jurisdiction,
        'country_or_region': countryOrRegion,
        'language': language,
        'source_owner': sourceOwner,
        'authority_tier': authorityTier.name,
        'access_method': accessMethod.name,
        'supported_document_types': supportedDocumentTypes,
        'update_cadence': updateCadence,
        'license_or_use_limitations': licenseOrUseLimitations,
        'last_checked': lastChecked,
        'parser_confidence': parserConfidence,
        'translation_status': translationStatus.name,
        'is_medication_source': isMedicationSource,
        'is_food_source': isFoodSource,
        'implemented': implemented,
        'known_limitations': knownLimitations,
        'source_refs': sourceRefs,
      };
}
