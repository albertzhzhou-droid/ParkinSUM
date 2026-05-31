import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/domain/entities/local_privacy_preflight.dart';
import 'package:parkinsum_companion/domain/usecases/local_privacy_preflight.dart';

import 'helpers/no_phi_json_assertions.dart';

/// P8 — LocalPrivacyPreflight. Deterministic, pure repo-hygiene / privacy-risk
/// scanner over in-memory fixtures (no whole-repo scanning here). Complements
/// `npm run public:preflight`. NOT HIPAA/GDPR/PIPEDA compliance, NOT a legal
/// certification, NOT clinical validation, and does NOT prove the app is secure.
void main() {
  const scanner = LocalPrivacyPreflight();

  LocalPrivacyScanTarget file(String path, String content) =>
      LocalPrivacyScanTarget(
        path: path,
        kind: 'file',
        sizeBytes: content.length,
        included: true,
        content: content,
      );

  LocalPrivacyPreflightReport scan(
    List<LocalPrivacyScanTarget> targets, {
    bool strict = false,
  }) =>
      scanner.scan(
        targets,
        LocalPrivacyPreflightConfig(rootPath: '.', strictMode: strict),
      );

  bool hasType(LocalPrivacyPreflightReport r, String type) =>
      r.findings.any((f) => f.findingType == type);

  LocalPrivacyFinding? find(LocalPrivacyPreflightReport r, String type) {
    for (final f in r.findings) {
      if (f.findingType == type) return f;
    }
    return null;
  }

  // 1 — clean synthetic target passes with no findings.
  test('clean synthetic target passes', () {
    final r = scan([
      file('lib/foo.dart', 'final demoValue = "synthetic_demo_only";\n'),
    ]);
    expect(r.pass, isTrue);
    expect(r.findings, isEmpty);
    expect(r.blockerCount, 0);
    expect(r.scannedFiles, 1);
  });

  // 2 — private key material is a BLOCKER.
  test('private key material → BLOCKER', () {
    final r = scan([
      // Split across adjacent string literals so the test SOURCE does not match
      // the public preflight's literal pattern; Dart concatenates them at compile
      // time, so the runtime content still contains the full marker.
      file('config/key.txt', '-----BEGIN ' 'PRIVATE KEY-----\nMII...\n'),
    ]);
    expect(hasType(r, 'secret_private_key'), isTrue);
    expect(
        find(r, 'secret_private_key')!.severity, LocalPrivacySeverity.blocker);
    expect(r.pass, isFalse);
  });

  // 3 — service-account credential fields are a BLOCKER.
  test('service account fields → BLOCKER', () {
    final r = scan([
      file('sa.json', '{ "client_email": "x@y.iam.gserviceaccount.com" }\n'),
    ]);
    expect(find(r, 'secret_service_account')!.severity,
        LocalPrivacySeverity.blocker);
  });

  // 4 — bearer / oauth token is a BLOCKER.
  test('bearer/oauth token → BLOCKER', () {
    final r = scan([
      file('h.txt', 'Authorization: Bearer abcdefghijklmnopqrstuvwxyz0123\n'),
    ]);
    expect(find(r, 'secret_bearer_or_oauth')!.severity,
        LocalPrivacySeverity.blocker);
  });

  // 5 — Google API key inside a known Firebase client config → WARN (allowed).
  test('firebase web API key in known config path → WARN', () {
    final r = scan([
      file(
          'lib/firebase_options.dart',
          "  apiKey: '"
              'AIza'
              "SyA1234567890123456789012345678901234',\n"),
    ]);
    final f = find(r, 'firebase_web_api_key_present');
    expect(f, isNotNull);
    expect(f!.severity, LocalPrivacySeverity.warn);
    expect(f.allowlistReason, isNotEmpty);
    expect(r.pass, isTrue);
  });

  // 6 — Google API key OUTSIDE a known config path → BLOCKER.
  test('API-key-like value outside firebase config → BLOCKER', () {
    final r = scan([
      file(
          'lib/leak.dart',
          "  const k = '"
              'AIza'
              "SyA1234567890123456789012345678901234';\n"),
    ]);
    expect(
        find(r, 'api_key_like_secret')!.severity, LocalPrivacySeverity.blocker);
  });

  // 7 — concrete password / api-key assignment → BLOCKER.
  test('concrete secret assignment → BLOCKER', () {
    final r = scan([
      file('lib/a.dart', 'final password = "s3cretValue123";\n'),
      file('lib/b.dart', 'final api_key = "ABCDEF1234567890XYZ";\n'),
    ]);
    expect(hasType(r, 'secret_password_assignment'), isTrue);
    expect(hasType(r, 'secret_api_key_assignment'), isTrue);
    expect(r.pass, isFalse);
  });

  // 8 — DB URL with embedded credentials: real → BLOCKER, localhost → INFO.
  test('db url credentials: real BLOCKER, localhost INFO', () {
    final real = scan([
      file('lib/db.dart',
          "const u = 'postgres://admin:hunter2@db.prod.net/x';\n"),
    ]);
    expect(find(real, 'secret_db_url_credentials')!.severity,
        LocalPrivacySeverity.blocker);

    final local = scan([
      file('test/x.dart', "const u = 'http://user:pass@localhost:11434';\n"),
    ]);
    expect(find(local, 'secret_db_url_credentials')!.severity,
        LocalPrivacySeverity.info);
    expect(local.pass, isTrue);
  });

  // 9 — strong PHI-like field with a concrete value → BLOCKER.
  test('strong PHI field with concrete value → BLOCKER', () {
    final r = scan([
      file('data/x.json', '{ "patient_name": "Jane Q. Real" }\n'),
    ]);
    final f = find(r, 'phi_like_data');
    expect(f, isNotNull);
    expect(f!.severity, LocalPrivacySeverity.blocker);
    expect(r.pass, isFalse);
  });

  // 10 — strong PHI field whose value is clearly synthetic → WARN (allowed).
  test('strong PHI field with synthetic value → WARN', () {
    final r = scan([
      file('data/x.json', '{ "medical_record": "synthetic_demo_only" }\n'),
    ]);
    final f = find(r, 'phi_like_data');
    expect(f!.severity, LocalPrivacySeverity.warn);
    expect(f.allowlistReason, isNotEmpty);
    expect(r.pass, isTrue);
  });

  // 11 — weak PHI-like field → WARN (never BLOCKER on its own).
  test('weak PHI field → WARN', () {
    final r = scan([
      file('data/x.json', '{ "diagnosis": "G20 Parkinson real case" }\n'),
    ]);
    expect(find(r, 'phi_like_weak_field')!.severity, LocalPrivacySeverity.warn);
    expect(r.pass, isTrue);
  });

  // 12 — local machine path: source → BLOCKER, doc → INFO.
  test('local machine path: source BLOCKER, doc INFO', () {
    final src = scan([
      file('android/local.properties', 'flutter.sdk=/Users/realname/flutter\n'),
    ]);
    expect(find(src, 'local_machine_path')!.severity,
        LocalPrivacySeverity.blocker);

    final doc = scan([
      file('docs/SETUP.md', 'Example: `/Users/you/flutter` (replace).\n'),
    ]);
    expect(
        find(doc, 'local_machine_path')!.severity, LocalPrivacySeverity.info);
    expect(doc.pass, isTrue);
  });

  // 13 — raw private export filename: source → BLOCKER, doc → INFO.
  test('raw export filename: source BLOCKER, doc INFO', () {
    final exp = scan([
      file('data/firestore_export.json', '{}\n'),
    ]);
    expect(find(exp, 'raw_private_export_file')!.severity,
        LocalPrivacySeverity.blocker);

    final doc = scan([
      file('docs/patient_export.md', 'Never commit a patient_export.json\n'),
    ]);
    expect(find(doc, 'raw_private_export_file')!.severity,
        LocalPrivacySeverity.info);
  });

  // 14 — real health narrative: fixture → BLOCKER, doc/guidance → INFO.
  test('health narrative: fixture BLOCKER, doc INFO', () {
    final fix = scan([
      file('test/fixtures/story_sample.json',
          '{ "note": "my patient was diagnosed with PD" }\n'),
    ]);
    expect(find(fix, 'real_health_narrative')!.severity,
        LocalPrivacySeverity.blocker);

    final doc = scan([
      file('.github/ISSUE_TEMPLATE/bug.yml',
          'Do not paste your real medication schedule here.\n'),
    ]);
    expect(find(doc, 'real_health_narrative')!.severity,
        LocalPrivacySeverity.info);
    expect(doc.pass, isTrue);
  });

  // 15 — negated narrative ("no real patient data") is NOT flagged.
  test('negated narrative is not flagged', () {
    final r = scan([
      file('lib/note.dart', '// This repo stores no real patient data.\n'),
    ]);
    expect(hasType(r, 'real_health_narrative'), isFalse);
    expect(r.pass, isTrue);
  });

  // 16 — generated/local directory present → WARN (never blocks).
  test('generated/local dir present → WARN', () {
    final r = scan([
      const LocalPrivacyScanTarget(
        path: 'build/',
        kind: 'directory',
        sizeBytes: 0,
        included: false,
        skipReason: 'generated_or_local_dir',
      ),
    ]);
    expect(find(r, 'generated_or_local_dir_present')!.severity,
        LocalPrivacySeverity.warn);
    expect(r.pass, isTrue);
    expect(r.skippedFiles, 1);
  });

  // 17 — strict mode escalates WARN → BLOCKER.
  test('strict mode escalates WARN to BLOCKER', () {
    const content = '{ "diagnosis": "G20 Parkinson real case" }\n';
    final lenient = scan([file('data/x.json', content)]);
    expect(lenient.pass, isTrue);

    final strict = scan([file('data/x.json', content)], strict: true);
    expect(find(strict, 'phi_like_weak_field')!.severity,
        LocalPrivacySeverity.blocker);
    expect(strict.pass, isFalse);
  });

  // 18 — safety-policy allowlist values are NEVER a BLOCKER.
  test('safety-policy allowlist values never BLOCKER', () {
    const values = [
      'no_patient_no_subject_no_encounter',
      'subject_omitted_no_phi',
      'not_clinically_calibrated',
      'synthetic_demo_only',
    ];
    for (final v in values) {
      final r = scan([
        file('data/p.json',
            '{ "patient_name": "$v", "password": "$v", "api_key": "$v" }\n'),
      ]);
      expect(r.blockerCount, 0,
          reason: 'allowlist value "$v" must never produce a BLOCKER');
      expect(r.pass, isTrue);
    }
  });

  // 19 — report shape: deterministic JSON + no PHI keys + boundary fields.
  test('report JSON is deterministic, no-PHI-key, with safety boundary', () {
    final targets = [
      file('lib/foo.dart', 'final x = "synthetic_demo_only";\n')
    ];
    final r1 = scan(targets);
    final r2 = scan(targets);
    final j1 = encodeLocalPrivacyReport(r1);
    final j2 = encodeLocalPrivacyReport(r2);
    expect(j1, equals(j2), reason: 'encoding must be deterministic');

    final decoded = jsonDecode(j1) as Map<String, dynamic>;
    expect(decoded['report_type'], 'local_privacy_preflight');
    expect(decoded['not_clinically_calibrated'], isTrue);
    expect(decoded['synthetic_demo_data_only'], isTrue);
    expect(decoded['no_medical_advice'], isTrue);
    expect((decoded['safety_boundary'] as String), isNotEmpty);
    expect((decoded['not_advice_text'] as String), isNotEmpty);
    scanNoPhiKeys(decoded);

    final md = renderLocalPrivacyMarkdown(r1);
    expect(md, contains('Local Privacy Preflight'));
    expect(md, contains('does not prove the app is secure'));
  });
}
