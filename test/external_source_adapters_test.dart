import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/data/datasources/remote/dmd_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/eu_national_register_importer.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_adapter_registry.dart';
import 'package:parkinsum_companion/data/datasources/remote/source_fetch_client.dart';
import 'package:parkinsum_companion/domain/entities/rule_explanation.dart';
import 'package:parkinsum_companion/domain/entities/source_metadata.dart';
import 'package:parkinsum_companion/domain/usecases/metadata_completeness_gate.dart';
import 'package:parkinsum_companion/domain/usecases/source_authority_scorer.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/importers/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  group('NHS dm+d importer', () {
    final importer = DmdImporter();
    test('parses identity + code, GB/en, drugDictionary authority', () {
      final r = importer.parse(_fixture('nhs_dmd_levodopa.json'));
      expect(r.document.sourceSystem, 'NHS_DMD');
      expect(r.document.jurisdiction, 'GB');
      expect(r.document.language, 'en');
      expect(r.document.authorityTier, SourceAuthorityTier.drugDictionary);
      expect(r.variant.productIdentifier, isNotNull);
      expect(
          r.variant.activeIngredients, containsAll(['carbidopa', 'levodopa']));
      expect(r.variant.sourceRefs, contains('src.nhs.dmd'));
    });
    test('identity-only cannot supply mechanism evidence alone; limitation set',
        () {
      final r = importer.parse(_fixture('nhs_dmd_levodopa.json'));
      expect(r.supportsMechanismEvidenceAlone, isFalse);
      expect(r.normalizationNotes,
          contains('no_food_effect_label_section:identity_only'));
      expect(
          r.document.limitationText.toLowerCase(), contains('not a complete'));
      expect(findBannedSubstrings(r.document.limitationText), isEmpty);
    });
  });

  group('EU national-register importer', () {
    final importer = EuNationalRegisterImporter();
    test('parses member-state identity + register id; no SmPC → limitation',
        () {
      final r = importer.parse(_fixture('eu_national_register_levodopa.json'));
      expect(r.document.sourceSystem, 'EU_National_Register');
      expect(r.memberState, 'DE');
      expect(r.variant.productIdentifier, 'DE-REG-000000');
      expect(r.supportsMechanismEvidenceAlone, isFalse);
      expect(r.normalizationNotes, contains('no_smpc_text:identity_only'));
      expect(r.document.authorityTier,
          SourceAuthorityTier.officialDatabaseInJurisdiction);
      expect(r.marketingAuthorizationHolder, isNotNull);
    });
    test('authority handled differently from EMA centralized label', () {
      final scorer = SourceAuthorityScorer();
      final r = importer.parse(_fixture('eu_national_register_levodopa.json'));
      // National-register identity (database tier) scores below an official
      // in-jurisdiction *label* for the same jurisdiction chain.
      const emaLabel = SourceDocumentMetadata(
        sourceDocId: 'ema:label',
        sourceSystem: 'EMA',
        jurisdiction: 'DE',
        language: 'en',
        sourceOwner: 'EMA',
        docType: 'smpc',
        authorityTier: SourceAuthorityTier.officialLabelInJurisdiction,
        translationStatus: ReferenceTranslationStatus.notTranslation,
        publishedAt: null,
        effectiveAt: null,
        lastUpdated: null,
        licenseOrUseLimitations: '',
        sourceRefs: ['src.ema.epi.fhir'],
        limitationText: 'x',
      );
      final chain = ['DE', 'EU', 'GLOBAL'];
      expect(scorer.score(r.document, userJurisdictionChain: chain),
          lessThan(scorer.score(emaLabel, userJurisdictionChain: chain)));
    });
  });

  group('registry implemented flags', () {
    test('dm+d, EU national register, NMPA all implemented now', () {
      expect(
          SourceAdapterRegistry.bySourceSystem('NHS_DMD')!.implemented, isTrue);
      expect(
          SourceAdapterRegistry.bySourceSystem('EU_National_Register')!
              .implemented,
          isTrue);
      expect(SourceAdapterRegistry.bySourceSystem('NMPA')!.implemented, isTrue);
    });
    test('NMPA is honestly downgraded (low parser confidence, prototype note)',
        () {
      final nmpa = SourceAdapterRegistry.bySourceSystem('NMPA')!;
      expect(nmpa.parserConfidence, lessThanOrEqualTo(0.35));
      expect(nmpa.knownLimitations.join(' ').toUpperCase(),
          contains('FIXTURE-VALIDATED'));
    });
  });

  group('FixtureSourceFetchClient', () {
    final client = FixtureSourceFetchClient(
      sourceSystem: 'NHS_DMD',
      payloadsById: {'id1': '{"ok":true}'},
    );
    test('returns payload for known id', () {
      final r = client.fetch('id1');
      expect(r.ok, isTrue);
      expect(r.status, 200);
      expect(r.rawPayload, contains('ok'));
      expect(r.error, isNull);
    });
    test('missing id → explicit failure, no payload, no fake fact', () {
      final r = client.fetch('missing');
      expect(r.ok, isFalse);
      expect(r.status, 404);
      expect(r.rawPayload, isNull);
      expect(r.error, contains('fixture_not_found'));
    });
  });

  group('completeness gate on parsed external metadata', () {
    final gate = MetadataCompletenessGate();
    test('dm+d identity (no release type) does not score complete', () {
      final r = DmdImporter().parse(_fixture('nhs_dmd_levodopa.json'));
      final score = gate.scoreMedicationContext(r.variant);
      // release_type unknown + no strength → not "complete".
      expect(score, isNot(MetadataCompletenessScore.complete));
    });
  });
}
