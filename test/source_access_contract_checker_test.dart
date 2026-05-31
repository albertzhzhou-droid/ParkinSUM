import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/source_access_contract.dart';
import 'package:parkinsum_companion/domain/usecases/source_access_contract_checker.dart';

void main() {
  const checker = SourceAccessContractChecker();

  SourceAccessRecord record({
    String id = 'src.example',
    String family = 'food_composition',
    String access = 'open_download',
    String status = 'implemented_fixture_tested',
    bool apiKey = false,
    bool account = false,
    bool license = false,
    bool legal = false,
    bool fixture = true,
    bool live = false,
    bool production = false,
    bool mechanism = true,
    bool identity = true,
    bool sourceQuality = true,
  }) =>
      SourceAccessRecord(
        sourceId: id,
        displayName: id,
        owner: 'Example owner',
        jurisdiction: 'GLOBAL',
        sourceFamily: family,
        dataDomain: 'mixed',
        accessMethod: access,
        requiresApiKey: apiKey,
        requiresAccount: account,
        licenseReviewNeeded: license,
        legalReviewNeeded: legal,
        implementationStatus: status,
        allowedForFixture: fixture,
        allowedForLiveSmoke: live,
        allowedForProduction: production,
        canSupportMechanismEvidenceAlone: mechanism,
        canSupportIdentityOrCoding: identity,
        canSupportSourceQualityScoring: sourceQuality,
      );

  SourceAccessContract contract(SourceAccessRecord source) =>
      SourceAccessContract(records: {source.sourceId: source});

  ObservedSourceRef ref(
    String sourceId, {
    String file = 'lib/example.dart',
    String usage = SourceUsageType.unknown,
  }) =>
      ObservedSourceRef(sourceId: sourceId, file: file, usageType: usage);

  SourceAccessContractReport run(
    SourceAccessRecord source, {
    List<ObservedSourceRef>? refs,
    bool strict = false,
  }) =>
      checker.check(
        contract: contract(source),
        references: refs ?? [ref(source.sourceId)],
        strictMode: strict,
      );

  test('registry parses and serializes deterministically', () {
    final parsed = SourceAccessContract.fromJson({
      'registry_type': 'source_access_registry',
      'version': '1',
      'sources': [
        record(id: 'src.z').toJson(),
        record(id: 'src.a').toJson(),
      ],
    });
    final encoded = jsonEncode(parsed.toJson());
    expect(encoded.indexOf('src.a'), lessThan(encoded.indexOf('src.z')));
    expect(jsonEncode(parsed.toJson()), encoded);
  });

  test('known source ID passes without findings', () {
    expect(run(record()).findings, isEmpty);
  });

  test('unknown source ID in code context is blocker', () {
    final report = checker.check(
      contract: SourceAccessContract(records: {'src.example': record()}),
      references: [ref('src.missing')],
    );
    expect(report.blockerCount, 1);
    expect(report.findings.single.findingType, 'unknown_source_id');
  });

  test('unknown source ID in docs context is warning', () {
    final report = checker.check(
      contract: SourceAccessContract(records: {'src.example': record()}),
      references: [ref('src.missing', file: 'docs/example.md')],
    );
    expect(report.blockerCount, 0);
    expect(report.findings.single.severity, SourceAccessSeverity.warn);
  });

  test('fixture-only source cannot be production-ready', () {
    final report = run(record(production: true), refs: const []);
    expect(
        report.findings.single.findingType, 'fixture_only_marked_production');
  });

  test('API-key-required source carries access warning', () {
    expect(
      run(record(apiKey: true)).findings.map((f) => f.findingType),
      contains('api_key_required'),
    );
  });

  test('account-required source carries access warning', () {
    expect(
      run(record(account: true)).findings.map((f) => f.findingType),
      contains('account_required'),
    );
  });

  test('license-review-needed source carries warning', () {
    expect(
      run(record(license: true)).findings.map((f) => f.findingType),
      contains('license_or_legal_review_needed'),
    );
  });

  test('synthetic source cannot be mechanism evidence alone', () {
    final report = run(
      record(family: 'synthetic_demo', mechanism: false),
      refs: [ref('src.example', usage: SourceUsageType.mechanismEvidence)],
    );
    expect(
      report.findings.single.findingType,
      'unsupported_mechanism_evidence_role',
    );
  });

  test('identity source cannot be mechanism evidence alone', () {
    final report = run(
      record(family: 'drug_identity', mechanism: false),
      refs: [ref('src.example', usage: SourceUsageType.mechanismEvidence)],
    );
    expect(
      report.findings.single.findingType,
      'unsupported_mechanism_evidence_role',
    );
  });

  test('source-quality usage allowed when record supports it', () {
    expect(
      run(
        record(sourceQuality: true),
        refs: [ref('src.example', usage: SourceUsageType.sourceQuality)],
      ).findings,
      isEmpty,
    );
  });

  test('deprecated source produces finding', () {
    expect(
      run(record(status: 'deprecated')).findings.single.findingType,
      'deprecated_source',
    );
  });

  test('strict mode escalates unknown access method', () {
    final report = run(record(access: 'unknown'), strict: true);
    expect(report.blockerCount, 1);
    expect(report.findings.single.findingType, 'unknown_access_status');
  });

  test('generated artifact sourceRefs are checked', () {
    final report = checker.check(
      contract: contract(record()),
      references: [
        ref('src.missing', file: 'build/evidence_graph/latest.json'),
      ],
    );
    expect(report.blockerCount, 1);
  });

  test('report JSON is deterministic', () {
    final report = run(record(license: true));
    expect(encodeSourceAccessReport(report), encodeSourceAccessReport(report));
    expect(report.generatedAt, '1970-01-01T00:00:00.000Z');
  });

  test('markdown report includes counts and limitations', () {
    final markdown = renderSourceAccessMarkdown(run(record()));
    expect(markdown, contains('Findings: blocker=0'));
    expect(markdown, contains('## Limitations'));
  });

  test('report emits no PHI-like keys', () {
    final json = encodeSourceAccessReport(run(record()));
    expect(json, isNot(contains('"patient"')));
    expect(json, isNot(contains('"subject"')));
    expect(json, isNot(contains('"encounter"')));
  });

  test('registry includes required major source families', () {
    final registry = _loadRegistry();
    final ids = registry.records.keys;
    expect(ids, contains('src.usda.fdc.api'));
    expect(ids, contains('src.dailymed.spl.webservices.v2'));
    expect(ids, contains('src.healthcanada.dpd'));
    expect(ids, contains('src.ema.epi.fhir'));
    expect(ids, contains('src.pmda.package_insert'));
    expect(ids, contains('src.nmpa.database'));
    expect(ids, contains('src.nhs.dmd.trud'));
    expect(ids, contains('src.ciqual'));
    expect(ids, contains('src.chinacdc.food'));
    expect(ids, contains('src.internal.prototype.heuristic'));
  });

  test('current model-assumption source refs resolve', () {
    final registry = _loadRegistry();
    final source = File('lib/domain/usecases/model_assumption_registry.dart')
        .readAsStringSync();
    final ids = RegExp(r'''["'](src\.[A-Za-z0-9_]+(?:\.[A-Za-z0-9_]+)*)["']''')
        .allMatches(source)
        .map((match) => match.group(1)!)
        .toSet();
    expect(ids, isNotEmpty);
    expect(ids.where((id) => !registry.contains(id)), isEmpty);
  });

  test('current importer source-system refs resolve or stay mapped', () {
    final registry = _loadRegistry();
    for (final id in [
      'src.dailymed.spl.webservices.v2',
      'src.healthcanada.dpd',
      'src.ema.epi.fhir',
      'src.ema.national_registers',
      'src.nhs.dmd',
      'src.pmda.package_insert',
      'src.nmpa.database',
      'src.usda.fdc.api',
      'src.ciqual',
      'src.chinacdc.food',
      'src.internal.prototype.heuristic',
    ]) {
      expect(registry.contains(id), isTrue, reason: id);
    }
  });
}

SourceAccessContract _loadRegistry() {
  final json =
      jsonDecode(File('config/source_access_registry.json').readAsStringSync())
          as Map<String, dynamic>;
  return SourceAccessContract.fromJson(json);
}
