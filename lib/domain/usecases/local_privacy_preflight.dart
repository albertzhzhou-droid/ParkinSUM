/// P8 — LocalPrivacyPreflight scanner.
///
/// Educational/research prototype only. Pure, deterministic repo-hygiene /
/// privacy-risk scanner over injectable scan targets (file I/O lives in the tool
/// wrapper). Complements `npm run public:preflight`. NOT a HIPAA/GDPR/PIPEDA
/// compliance check, NOT a legal certification, NOT clinical validation, and does
/// NOT prove the app is secure — it reduces the risk of accidentally publishing
/// sensitive data or secrets. Synthetic/demo data only.
library;

import 'dart:convert';

import '../entities/local_privacy_preflight.dart';
import '../entities/rule_explanation.dart';

class LocalPrivacyPreflight {
  const LocalPrivacyPreflight();

  static const List<String> _limitations = [
    'Repo-hygiene / privacy-risk scanning only; not HIPAA/GDPR/PIPEDA compliance.',
    'Not a legal certification, not clinical validation, and does not prove the app is secure.',
    'Pattern-based and conservative; may miss novel secrets or PHI shapes (no false sense of safety).',
    'Reduces the risk of accidentally publishing sensitive data or secrets.',
  ];

  // --- Detector patterns (value/filename-shaped to avoid matching benign code) -
  static final RegExp _privateKey = RegExp(r'PRIVATE KEY-----');
  static final RegExp _serviceAccountEmail = RegExp(r'"client_email"\s*:');
  static final RegExp _serviceAccountKeyId = RegExp(r'"private_key_id"\s*:');
  static final RegExp _bearer =
      RegExp(r'bearer\s+[A-Za-z0-9._\-]{20,}', caseSensitive: false);
  static final RegExp _oauth = RegExp(
      r'oauth[_-]?token["' "'" r'\s:=]{1,4}[A-Za-z0-9._\-]{20,}',
      caseSensitive: false);
  static final RegExp _googleApiKey = RegExp(r'AIza[0-9A-Za-z_\-]{35}');
  static final RegExp _dbUrlCreds =
      RegExp(r'[a-z][a-z0-9+.\-]+://[^/\s:@"]+:[^/\s:@"]+@');
  static final RegExp _passwordAssign = RegExp(
      r'''password["'\s]*[:=]\s*["']([^"'\s]{6,})["']''',
      caseSensitive: false);
  static final RegExp _genericSecretAssign = RegExp(
      r'''(?:api[_-]?key|secret|access[_-]?token)["'\s]*[:=]\s*["']([A-Za-z0-9_\-]{16,})["']''',
      caseSensitive: false);

  // Strong PHI keys (concrete value → BLOCKER). NOTE: `patientId`/`patient_id`
  // are intentionally excluded — the app's domain model uses a *synthetic, local*
  // patient identifier pervasively (e.g. `patientId: 'patient_demo'`), which is
  // not committed real PHI.
  static const List<String> _strongPhiKeys = [
    'patient_name',
    'patientname',
    'mrn',
    'dateofbirth',
    'date_of_birth',
    'symptomlog',
    'symptom_log',
    'medicationschedule',
    'medication_schedule',
    'cliniciannote',
    'clinician_note',
    'doctornote',
    'doctor_note',
    'medicalrecord',
    'medical_record',
  ];
  static const List<String> _weakPhiKeys = [
    'subject',
    'encounter',
    'diagnosis',
    'treatment',
    'dob',
    'phone',
    'email',
    'address',
  ];

  /// Filename tokens indicating a raw private export/dump.
  static final RegExp _rawExportFilename = RegExp(
      r'(?:raw|private|user|patient|firebase|firestore|admin|production)[_-](?:export|dump)|operator_log|_export\.(?:json|csv|ndjson)$',
      caseSensitive: false);

  /// Real-health-story / patient-narrative phrases.
  static const List<String> _narrativePhrases = [
    'my patient',
    'real patient',
    'case report',
    'symptoms started',
    'diagnosed with',
    'doctor prescribed',
    'took medication at',
    'experienced dyskinesia',
    'real medication schedule',
  ];

  /// Local machine path forms (anchored — not bare words).
  static final List<RegExp> _localPaths = [
    RegExp(r'/Users/[A-Za-z0-9._\-]+/'),
    RegExp(r'/home/[A-Za-z0-9._\-]+/'),
    RegExp(r'C:\\Users\\', caseSensitive: false),
    RegExp(r'[/\\](?:Desktop|Downloads|Documents)[/\\]'),
  ];

  static const List<String> _syntheticMarkers = [
    'synthetic',
    'demo',
    'example',
    'sample',
    'fake',
    'placeholder',
    'omitted',
    'redacted',
    'changeme',
    'your_',
    'xxxx',
    '<',
    'null',
    'none',
    'no_patient',
    'not_clinically',
    'test',
    'dummy',
  ];

  bool _looksSourceOrConfig(String path) => RegExp(
          r'\.(dart|json|ya?ml|gradle|plist|xml|properties|kts|gradle\.kts|sh|mjs|js|ts)$')
      .hasMatch(path);

  bool _isDoc(String path) => path.endsWith('.md') || path.startsWith('docs/');

  /// Docs + contributor-guidance surfaces (issue/PR templates) that legitimately
  /// *mention* health-narrative phrases while warning against committing them.
  bool _isDocOrGuidance(String path) =>
      _isDoc(path) ||
      path.startsWith('.github/') ||
      path.endsWith('.yml') ||
      path.endsWith('.yaml');

  bool _isFixtureLike(String path) =>
      RegExp(r'(fixture|sample|seed|demo_data|mock)', caseSensitive: false)
          .hasMatch(path);

  bool _underGenerated(String path, LocalPrivacyPreflightConfig c) =>
      c.allowedGeneratedDirs
          .any((d) => path.startsWith(d) || path.contains('/$d'));

  bool _isFirebaseConfig(String path, LocalPrivacyPreflightConfig c) =>
      c.knownPublicFirebaseConfigPaths.contains(path);

  bool _isSafePolicyValue(String value, LocalPrivacyPreflightConfig c) {
    final v = value.toLowerCase();
    if (c.allowedSafetyPolicyValues.any((p) => v.contains(p.toLowerCase()))) {
      return true;
    }
    return _syntheticMarkers.any((m) => v.contains(m));
  }

  bool _negatedNarrative(String lineLower, String phrase) {
    final idx = lineLower.indexOf(phrase);
    if (idx <= 0) return false;
    final prefix = lineLower.substring((idx - 10).clamp(0, idx), idx);
    return prefix.contains('no ') ||
        prefix.contains('not ') ||
        prefix.contains('never ') ||
        prefix.contains('without ') ||
        prefix.contains('no-') ||
        prefix.contains('not-');
  }

  LocalPrivacyPreflightReport scan(
    List<LocalPrivacyScanTarget> targets,
    LocalPrivacyPreflightConfig config,
  ) {
    final findings = <LocalPrivacyFinding>[];
    var scanned = 0;
    var skipped = 0;

    for (final t in targets) {
      if (!t.included || t.kind != 'file') {
        skipped++;
        if (t.kind == 'directory' &&
            config.allowedGeneratedDirs
                .any((d) => t.path == d || t.path == d.replaceAll('/', ''))) {
          findings.add(LocalPrivacyFinding(
            severity: LocalPrivacySeverity.warn,
            findingType: 'generated_or_local_dir_present',
            file: t.path,
            line: 0,
            message:
                'Generated/local directory present; should not be published.',
            category: LocalPrivacyCategory.generatedDir,
            safetyBoundary: RuleExplanation.defaultSafetyBoundary,
          ));
        }
        continue;
      }
      scanned++;
      findings.addAll(_scanFile(t, config));
    }

    var counts = <String, int>{'info': 0, 'warn': 0, 'blocker': 0};
    for (final f in findings) {
      counts[f.severity] = (counts[f.severity] ?? 0) + 1;
    }

    return LocalPrivacyPreflightReport(
      generatedAt: config.deterministicTimestamp,
      root: config.rootPath,
      scannedFiles: scanned,
      skippedFiles: skipped,
      counts: counts,
      pass: (counts['blocker'] ?? 0) == 0,
      findings: findings,
      safetyBoundary: RuleExplanation.defaultSafetyBoundary,
      notAdviceText: RuleExplanation.defaultNotAdvice,
      notClinicallyCalibrated: true,
      limitations: _limitations,
    );
  }

  List<LocalPrivacyFinding> _scanFile(
      LocalPrivacyScanTarget t, LocalPrivacyPreflightConfig config) {
    final out = <LocalPrivacyFinding>[];
    final path = t.path;
    final isDoc = _isDoc(path);
    final underGen = _underGenerated(path, config);

    LocalPrivacyFinding f(String sev, String type, int line, String msg,
            {String matched = '',
            String category = '',
            String fix = '',
            String allow = ''}) =>
        LocalPrivacyFinding(
          severity: config.strictMode && sev == LocalPrivacySeverity.warn
              ? LocalPrivacySeverity.blocker
              : sev,
          findingType: type,
          file: path,
          line: line,
          message: msg,
          matchedText: matched,
          category: category,
          suggestedFix: fix,
          allowlistReason: allow,
          safetyBoundary: RuleExplanation.defaultSafetyBoundary,
        );

    // Rule D — raw private export by FILENAME (BLOCKER; docs → INFO).
    if (_rawExportFilename.hasMatch(path)) {
      out.add(f(
        isDoc ? LocalPrivacySeverity.info : LocalPrivacySeverity.blocker,
        'raw_private_export_file',
        0,
        'Filename suggests a raw/private data export or dump.',
        matched: path,
        category: LocalPrivacyCategory.rawExport,
        fix: 'Remove the export from the repo; never commit raw data dumps.',
        allow: isDoc ? 'doc_reference' : '',
      ));
    }

    final lines = const LineSplitter().convert(t.content);
    for (var i = 0; i < lines.length; i++) {
      final raw = lines[i];
      final lower = raw.toLowerCase();
      final ln = i + 1;

      // Rule A — secrets.
      if (_privateKey.hasMatch(raw)) {
        out.add(f(LocalPrivacySeverity.blocker, 'secret_private_key', ln,
            'Private key material detected.',
            matched: 'PRIVATE KEY-----',
            category: LocalPrivacyCategory.secret));
      }
      if (_serviceAccountEmail.hasMatch(raw) ||
          _serviceAccountKeyId.hasMatch(raw)) {
        out.add(f(LocalPrivacySeverity.blocker, 'secret_service_account', ln,
            'Service-account credential field detected.',
            matched: 'client_email/private_key_id',
            category: LocalPrivacyCategory.secret));
      }
      if (_bearer.hasMatch(raw) || _oauth.hasMatch(raw)) {
        out.add(f(LocalPrivacySeverity.blocker, 'secret_bearer_or_oauth', ln,
            'Bearer/OAuth token detected.',
            category: LocalPrivacyCategory.secret));
      }
      if (_dbUrlCreds.hasMatch(raw)) {
        // A localhost/example endpoint or a placeholder userinfo (e.g.
        // `user:pass@localhost`) is a fixture, not a real credential.
        final fixtureLike = lower.contains('localhost') ||
            lower.contains('127.0.0.1') ||
            lower.contains('example') ||
            lower.contains('user:pass@') ||
            lower.contains('username:password@');
        out.add(f(
            fixtureLike
                ? LocalPrivacySeverity.info
                : LocalPrivacySeverity.blocker,
            'secret_db_url_credentials',
            ln,
            'URL with embedded credentials detected.',
            category: LocalPrivacyCategory.secret,
            allow: fixtureLike ? 'localhost_or_placeholder' : ''));
      }
      final pw = _passwordAssign.firstMatch(raw);
      if (pw != null && !_isSafePolicyValue(pw.group(1) ?? '', config)) {
        out.add(f(LocalPrivacySeverity.blocker, 'secret_password_assignment',
            ln, 'Password-like assignment with a concrete value.',
            category: LocalPrivacyCategory.secret,
            fix:
                'Use a placeholder or environment variable, never a real secret.'));
      }
      final gs = _genericSecretAssign.firstMatch(raw);
      if (gs != null && !_isSafePolicyValue(gs.group(1) ?? '', config)) {
        // Google API keys handled separately below; avoid double-count here.
        if (!_googleApiKey.hasMatch(raw)) {
          out.add(f(LocalPrivacySeverity.blocker, 'secret_api_key_assignment',
              ln, 'API-key/secret/token assignment with a concrete value.',
              category: LocalPrivacyCategory.secret));
        }
      }
      if (_googleApiKey.hasMatch(raw)) {
        if (_isFirebaseConfig(path, config)) {
          out.add(f(LocalPrivacySeverity.warn, 'firebase_web_api_key_present',
              ln, 'Firebase Web API key in a public client config (expected).',
              category: LocalPrivacyCategory.secret,
              allow: 'known_public_firebase_client_config'));
        } else if (underGen) {
          out.add(f(LocalPrivacySeverity.warn, 'generated_api_key_like_value',
              ln, 'API-key-like value in generated/local output.',
              category: LocalPrivacyCategory.secret, allow: 'generated_dir'));
        } else {
          out.add(f(LocalPrivacySeverity.blocker, 'api_key_like_secret', ln,
              'API-key-like value outside known Firebase client config.',
              category: LocalPrivacyCategory.secret));
        }
      }

      // Rule B — PHI-like fields with a concrete value.
      for (final key in _strongPhiKeys) {
        final m = RegExp(
                '["\'\\s]?${RegExp.escape(key)}["\']?\\s*[:=]\\s*["\']([^"\']{2,})["\']',
                caseSensitive: false)
            .firstMatch(raw);
        if (m != null) {
          final value = m.group(1) ?? '';
          final safe = _isSafePolicyValue(value, config);
          out.add(f(
            safe ? LocalPrivacySeverity.warn : LocalPrivacySeverity.blocker,
            'phi_like_data',
            ln,
            'Patient/PHI-like field "$key" with a concrete value.',
            matched: key,
            category: LocalPrivacyCategory.phiLikeField,
            fix: 'Use synthetic/demo data only; never commit patient data.',
            allow: safe ? 'synthetic_or_policy_value' : '',
          ));
        }
      }
      for (final key in _weakPhiKeys) {
        final m = RegExp(
                '["\']${RegExp.escape(key)}["\']\\s*[:=]\\s*["\']([^"\']{2,})["\']',
                caseSensitive: false)
            .firstMatch(raw);
        if (m != null) {
          final value = m.group(1) ?? '';
          if (_isSafePolicyValue(value, config)) continue;
          out.add(f(LocalPrivacySeverity.warn, 'phi_like_weak_field', ln,
              'Possible PHI-like field "$key" with a concrete value.',
              matched: key, category: LocalPrivacyCategory.phiLikeField));
        }
      }

      // Rule C — local machine paths.
      for (final rx in _localPaths) {
        final m = rx.firstMatch(raw);
        if (m != null) {
          final sev = isDoc
              ? LocalPrivacySeverity.info
              : underGen
                  ? LocalPrivacySeverity.warn
                  : _looksSourceOrConfig(path)
                      ? LocalPrivacySeverity.blocker
                      : LocalPrivacySeverity.warn;
          out.add(f(
              sev, 'local_machine_path', ln, 'Local machine path detected.',
              matched: m.group(0) ?? '',
              category: LocalPrivacyCategory.localPath,
              fix: 'Use relative paths; never commit absolute local paths.',
              allow: isDoc ? 'doc_example' : ''));
          break;
        }
      }

      // Rule E — real-health-story / patient narrative.
      for (final phrase in _narrativePhrases) {
        if (lower.contains(phrase) && !_negatedNarrative(lower, phrase)) {
          // Fixtures/sample data → BLOCKER; docs/guidance that *warn against*
          // such data → INFO; other source → WARN.
          final sev = _isFixtureLike(path)
              ? LocalPrivacySeverity.blocker
              : _isDocOrGuidance(path)
                  ? LocalPrivacySeverity.info
                  : LocalPrivacySeverity.warn;
          out.add(f(sev, 'real_health_narrative', ln,
              'Phrase resembling a real patient narrative.',
              matched: phrase,
              category: LocalPrivacyCategory.healthNarrative,
              fix: 'Use clearly synthetic/demo scenarios only.',
              allow: _isDocOrGuidance(path) ? 'doc_or_guidance' : ''));
          break;
        }
      }
    }
    return out;
  }
}

/// Deterministic JSON encoder.
String encodeLocalPrivacyReport(LocalPrivacyPreflightReport report) =>
    const JsonEncoder.withIndent('  ').convert(report.toJson());

/// Deterministic markdown report.
String renderLocalPrivacyMarkdown(LocalPrivacyPreflightReport report) {
  final b = StringBuffer()
    ..writeln('# ParkinSUM Local Privacy Preflight')
    ..writeln()
    ..writeln('Educational/research prototype. Repo-hygiene / privacy-risk '
        'scanning that **complements** `npm run public:preflight`. **Not '
        'HIPAA/GDPR/PIPEDA compliance, not a legal certification, not clinical '
        'validation, and does not prove the app is secure.**')
    ..writeln()
    ..writeln('- root: `${report.root}`')
    ..writeln('- scanned files: ${report.scannedFiles}')
    ..writeln('- skipped files: ${report.skippedFiles}')
    ..writeln('- info: ${report.counts['info'] ?? 0} · '
        'warn: ${report.counts['warn'] ?? 0} · '
        'blocker: ${report.blockerCount}')
    ..writeln('- pass (0 blocker): ${report.pass}')
    ..writeln()
    ..writeln('| severity | type | file | line | matched |')
    ..writeln('| --- | --- | --- | --- | --- |');
  for (final f in report.findings) {
    b.writeln('| ${f.severity} | ${f.findingType} | ${f.file} | ${f.line} | '
        '${f.matchedText} |');
  }
  b
    ..writeln()
    ..writeln('## Limitations')
    ..writeln();
  for (final l in report.limitations) {
    b.writeln('- $l');
  }
  b
    ..writeln()
    ..writeln('## Safety boundary')
    ..writeln()
    ..writeln(report.safetyBoundary)
    ..writeln()
    ..writeln(report.notAdviceText);
  return b.toString();
}
