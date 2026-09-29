import 'dart:convert';

import '../entities/portable_schema_migration.dart';

/// Frozen, executable registry for the portable package versions that this
/// build can read. It runs in addition to the full package semantic validator:
/// the registry owns historical envelope/version meaning, while the existing
/// validator continues to enforce every nested clinical-data boundary.
abstract final class PortableSchemaMigrationRegistry {
  static const String format = 'parkinsum_user_portable_data_package';
  static const String canonicalization = 'sorted-key-json-v1';
  static const int currentVersion = 4;

  static const List<String> _filePaths = <String>[
    'profile.json',
    'preferences.json',
    'medication_selections.json',
    'intakes.json',
    'meals.json',
    'reminders.json',
    'audit_links.json',
  ];
  static const List<String> _v4FilePaths = <String>[
    ..._filePaths,
    'observations.json',
  ];
  static const List<String> _v4ObservationContainerFields = <String>[
    'availability',
    'records',
  ];
  static const List<String> _v4ObservationRecordFields = <String>[
    'schemaVersion',
    'id',
    'kind',
    'occurredAt',
    'recordedAt',
    'originalTimezone',
    'source',
    'recorderRole',
    'status',
    'symptomLabel',
    'severity',
    'notes',
    'motorState',
    'systolic',
    'diastolic',
    'unit',
    'posture',
  ];

  static const List<String> _rootFields = <String>[
    'files',
    'format',
    'manifest',
    'schemaVersion',
  ];
  static const List<String> _manifestFields = <String>[
    'createdAt',
    'files',
    'integrity',
    'ownerScope',
    'packageId',
    'privacyBoundary',
    'producer',
  ];
  static const List<String> _ownerFields = <String>[
    'bindingAlgorithm',
    'bindingDomain',
    'bindingSha256',
    'kind',
    'rawIdentifierIncluded',
  ];
  static const List<String> _integrityFields = <String>[
    'algorithm',
    'canonicalization',
    'contentSha256',
    'signatureStatus',
  ];
  static const List<String> _privacyFields = <String>[
    'containsSensitiveUserData',
    'encryption',
    'excluded',
    'identityLinkability',
    'notAClaim',
    'scope',
  ];
  static const List<String> _manifestFileFields = <String>[
    'path',
    'recordCount',
    'sha256',
  ];
  static const List<String> _v2ReminderFields = <String>[
    'activationTokenStatus',
    'deliveryBoundary',
    'enabled',
    'id',
    'kind',
    'label',
    'minuteOfDay',
    'weekdays',
  ];
  static const List<String> _v3ReminderFields = <String>[
    'activationTokenStatus',
    'deliveryBoundary',
    'enabled',
    'id',
    'kind',
    'label',
    'minuteOfDay',
    'notificationLocaleCode',
    'notificationLocaleDecisionCode',
    'notificationPrivacyMode',
    'presentationIdentityStatus',
    'sourcePresentationSchema',
    'sourcePresentationSha256',
    'targetSchedulingConsentStatus',
    'weekdays',
  ];

  static const String _identityLinkabilityBoundary =
      'Raw account identifiers are excluded, but current dose receipts and medication assertions retain stable unsalted owner-scope digests for integrity verification. Those pseudonymous digests can link artifacts from the same scope and can be dictionary-matched when the source scope, such as a local email-derived identifier, has low entropy.';
  static const String _scopeBoundary =
      'Current loaded profile, selections, intakes, meals, this-device reminders, and relationship audit links.';
  static const String _v4ScopeBoundary =
      'Current loaded profile, selections, intakes, meals, this-device reminders, owner-entered personal observations, and relationship audit links.';
  static const String _notAClaimBoundary =
      'Not an encrypted backup, anonymous or unlinkable dataset, account deletion receipt, complete cloud export, clinical record, or legal-compliance certification.';
  static const String _reminderBoundary =
      'User-authored logging prompt only; not a prescribed medication time and not proof of operating-system delivery.';
  static const String _targetConsent =
      'required_before_target_permission_or_scheduling';
  static const String _presentationStatus =
      'source_digest_only_recompute_on_target';
  static const String _presentationSchema =
      'parkinsum.reminder-notification-presentation/1';
  static const String _frozenMinimalEnglishPresentationSha256 =
      '29b86c90c1d3756bda93cf198c558863283924eb6a073fa278f7db9d6761cf23';

  static const Map<String, Object?> _commonStructure = <String, Object?>{
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    'format': format,
    'canonicalization': canonicalization,
    'rootFields': _rootFields,
    'manifestFields': _manifestFields,
    'ownerFields': _ownerFields,
    'integrityFields': _integrityFields,
    'privacyFields': _privacyFields,
    'manifestFileFields': _manifestFileFields,
    'additionalEnvelopeProperties': false,
  };

  static const Map<String, Object?> _commonSemanticPolicy = <String, Object?>{
    'ownerBinding': 'parkinsum-portable-owner-v1 + SHA-256',
    'integrity': 'SHA-256 over sorted-key-json-v1 decoded values',
    'signatureStatus': 'unsigned',
    'nullVersusZero': 'distinct and preserved',
    'doseTruth':
        'canonical quantity remains held unless receipt, row, parser, product, assertion and as-of result gate agree',
    'missingNutrients':
        'source missing is never reinterpreted as measured zero',
    'rawIdentifiers': 'excluded; stable nested pseudonyms remain linkable',
    'durableImport': 'not authorized by validation or migration preview',
    'jsonSchemaBoundary':
        'structure only; ParkinSUM cross-field semantics remain executable policy',
    'canonicalizationBoundary': 'sorted-key-json-v1 is not RFC 8785/JCS',
  };

  static const PortableSchemaValidatorDescriptor v2 =
      PortableSchemaValidatorDescriptor(
        version: 2,
        schemaUri: 'urn:parkinsum:schema:user-portable-data-package:2',
        validatorVersion: 1,
        structuralContract: <String, Object?>{
          ..._commonStructure,
          r'$id': 'urn:parkinsum:schema:user-portable-data-package:2',
          'schemaVersion': 2,
          'filePaths': _filePaths,
          'reminderFields': _v2ReminderFields,
        },
        semanticPolicy: <String, Object?>{
          ..._commonSemanticPolicy,
          'schemaVersion': 2,
          'reminderPresentation':
              'absent; preview may add frozen minimal English intent only',
        },
      );

  static const PortableSchemaValidatorDescriptor
  v3 = PortableSchemaValidatorDescriptor(
    version: 3,
    schemaUri: 'urn:parkinsum:schema:user-portable-data-package:3',
    validatorVersion: 1,
    structuralContract: <String, Object?>{
      ..._commonStructure,
      r'$id': 'urn:parkinsum:schema:user-portable-data-package:3',
      'schemaVersion': 3,
      'filePaths': _filePaths,
      'reminderFields': _v3ReminderFields,
    },
    semanticPolicy: <String, Object?>{
      ..._commonSemanticPolicy,
      'schemaVersion': 3,
      'reminderPresentation':
          'privacy mode, language, source copy identity and target consent are explicit',
      'activationCapabilities': 'excluded',
    },
  );

  static const PortableSchemaValidatorDescriptor
  v4 = PortableSchemaValidatorDescriptor(
    version: 4,
    schemaUri: 'urn:parkinsum:schema:user-portable-data-package:4',
    validatorVersion: 1,
    structuralContract: <String, Object?>{
      ..._commonStructure,
      r'$id': 'urn:parkinsum:schema:user-portable-data-package:4',
      'schemaVersion': 4,
      'filePaths': _v4FilePaths,
      'reminderFields': _v3ReminderFields,
      'observationContainerFields': _v4ObservationContainerFields,
      'observationRecordFields': _v4ObservationRecordFields,
      'observationAvailabilityValues': <String>[
        'captured_current_local_snapshot',
        'unavailable_in_source_schema',
      ],
    },
    semanticPolicy: <String, Object?>{
      ..._commonSemanticPolicy,
      'schemaVersion': 4,
      'scope': _v4ScopeBoundary,
      'reminderPresentation':
          'privacy mode, language, source copy identity and target consent are explicit',
      'activationCapabilities': 'excluded',
      'personalObservations':
          'all local symptom, self-reported motor-state and blood-pressure records are preserved; unknown is not measured and absent is not zero; recorder ID is replaced by the package-owner role; older schemas explicitly mark observations unavailable',
    },
  );

  static const List<PortableSchemaSemanticDiff> _v2ToV3Diff =
      <PortableSchemaSemanticDiff>[
        PortableSchemaSemanticDiff(
          path: r'$.schemaVersion',
          operation: 'replace',
          sourceMeaning: 'historical portable package v2',
          targetMeaning:
              'portable package v3 with reminder presentation intent',
          lossClassification: 'lossless_version_advance',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.files.reminders.json[*].notificationPrivacyMode',
          operation: 'add_frozen_default',
          sourceMeaning: 'not represented',
          targetMeaning: 'minimal',
          lossClassification: 'explicit_legacy_default',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.files.reminders.json[*].notificationLocaleCode',
          operation: 'add_frozen_default',
          sourceMeaning: 'not represented',
          targetMeaning: 'en',
          lossClassification: 'explicit_legacy_default',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.files.reminders.json[*].notificationLocaleDecisionCode',
          operation: 'add_frozen_default',
          sourceMeaning: 'not represented',
          targetMeaning: 'en',
          lossClassification: 'explicit_legacy_default',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.files.reminders.json[*].sourcePresentationSchema',
          operation: 'add_frozen_default',
          sourceMeaning: 'not represented',
          targetMeaning: _presentationSchema,
          lossClassification: 'explicit_legacy_default',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.files.reminders.json[*].sourcePresentationSha256',
          operation: 'add_frozen_default',
          sourceMeaning: 'not represented',
          targetMeaning: _frozenMinimalEnglishPresentationSha256,
          lossClassification: 'explicit_legacy_default',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.files.reminders.json[*].presentationIdentityStatus',
          operation: 'add_frozen_default',
          sourceMeaning: 'not represented',
          targetMeaning: _presentationStatus,
          lossClassification: 'explicit_legacy_default',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.files.reminders.json[*].targetSchedulingConsentStatus',
          operation: 'add_hold',
          sourceMeaning: 'no portable scheduling authority',
          targetMeaning: _targetConsent,
          lossClassification: 'safety_hold',
        ),
      ];

  static const List<PortableSchemaSemanticDiff> _v3ToV4Diff =
      <PortableSchemaSemanticDiff>[
        PortableSchemaSemanticDiff(
          path: r'$.schemaVersion',
          operation: 'replace',
          sourceMeaning: 'historical portable package v3',
          targetMeaning:
              'portable package v4 with owner-entered personal observations',
          lossClassification: 'lossless_version_advance',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.files.observations.json.availability',
          operation: 'add_explicit_source_gap',
          sourceMeaning: 'observations were not represented by schema v3',
          targetMeaning: 'unavailable_in_source_schema',
          lossClassification: 'source_absence_preserved',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.files.observations.json.records',
          operation: 'add_empty_collection_with_availability_marker',
          sourceMeaning: 'no observation collection in source schema',
          targetMeaning:
              'empty because the source schema did not carry records',
          lossClassification: 'no_absence_inference',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.manifest.privacyBoundary.scope',
          operation: 'replace_with_versioned_scope',
          sourceMeaning: _scopeBoundary,
          targetMeaning: _v4ScopeBoundary,
          lossClassification: 'scope_description_update',
        ),
        PortableSchemaSemanticDiff(
          path: r'$.manifest.privacyBoundary.excluded',
          operation: 'add_excluded_value',
          sourceMeaning: 'recorder identifiers not represented in v3 export',
          targetMeaning: 'personalObservation.recorderId is excluded',
          lossClassification: 'raw_identifier_exclusion',
        ),
      ];
  static const List<PortableSchemaSemanticDiff> _v2ToV4Diff =
      <PortableSchemaSemanticDiff>[..._v2ToV3Diff, ..._v3ToV4Diff];

  static const PortableSchemaMigrationDescriptor
  v2ToV3 = PortableSchemaMigrationDescriptor(
    migrationId: 'portable_package_v2_to_v3_reminder_presentation',
    migrationVersion: 1,
    sourceVersion: 2,
    targetVersion: 3,
    semanticDiff: _v2ToV3Diff,
    invariants: <String>[
      'Every source value outside the seven added reminder fields is byte-value equivalent after decoded canonicalization.',
      'Null, zero, false, empty string and missing remain distinct.',
      'No notification permission, scheduling, persistence or network operation occurs.',
      'Owner binding, createdAt and all user record values are preserved.',
      'Integrity hashes and package id are regenerated for schema v3.',
    ],
  );

  static const PortableSchemaMigrationDescriptor
  v3ToV4 = PortableSchemaMigrationDescriptor(
    migrationId: 'portable_package_v3_to_v4_personal_observations',
    migrationVersion: 1,
    sourceVersion: 3,
    targetVersion: 4,
    semanticDiff: _v3ToV4Diff,
    invariants: <String>[
      'Every source file value is preserved exactly; only schemaVersion, the reviewed privacy-scope/exclusion fields, the new observation marker, and resealed integrity fields change.',
      'The new observation container states unavailable_in_source_schema; an empty record list never claims the user had no observations.',
      'No permission, scheduling, persistence, network or durable import operation occurs.',
      'Owner binding, createdAt and all user record values remain unchanged.',
      'Integrity hashes and package id are regenerated for schema v4.',
    ],
  );

  static const PortableSchemaMigrationDescriptor
  v2ToV4 = PortableSchemaMigrationDescriptor(
    migrationId:
        'portable_package_v2_to_v4_observations_and_reminder_presentation',
    migrationVersion: 1,
    sourceVersion: 2,
    targetVersion: 4,
    semanticDiff: _v2ToV4Diff,
    invariants: <String>[
      'The frozen v2-to-v3 reminder presentation migration runs before v3-to-v4 observation availability is added.',
      'Every source value outside the reviewed version, privacy-scope/exclusion and observation fields is preserved exactly after decoded canonicalization.',
      'Older source versions explicitly say observations were unavailable in that schema; an empty collection never proves no observations existed.',
      'No permission, scheduling, persistence, network or durable import operation occurs.',
      'Owner binding, createdAt and all source user record values remain unchanged.',
      'Integrity hashes and package id are regenerated for schema v4.',
    ],
  );

  static List<PortableSchemaValidatorDescriptor> get validators =>
      const <PortableSchemaValidatorDescriptor>[v2, v3, v4];

  static List<PortableSchemaMigrationDescriptor> get migrations =>
      const <PortableSchemaMigrationDescriptor>[v2ToV3, v3ToV4, v2ToV4];

  static List<String> filePathsForVersion(int version) =>
      List<String>.unmodifiable(version >= 4 ? _v4FilePaths : _filePaths);

  static String scopeForVersion(int version) =>
      version >= 4 ? _v4ScopeBoundary : _scopeBoundary;

  static List<String> excludedValuesForVersion(int version) => version >= 4
      ? const <String>[
          'raw_account_uid',
          'raw_email',
          'raw_dose_owner_scope',
          'profile.patientId',
          'credentials',
          'reminder.activationToken',
          'local_ai_endpoints',
          'cloud_only_clinical_audit_documents',
          'personalObservation.recorderId',
        ]
      : const <String>[
          'raw_account_uid',
          'raw_email',
          'raw_dose_owner_scope',
          'profile.patientId',
          'credentials',
          'reminder.activationToken',
          'local_ai_endpoints',
          'cloud_only_clinical_audit_documents',
        ];

  static PortableSchemaValidatorDescriptor? descriptorForVersion(int version) {
    for (final descriptor in validators) {
      if (descriptor.version == version) return descriptor;
    }
    return null;
  }

  static String get registryDigest => portableCanonicalSha256(<String, Object?>{
    'schema': portableSchemaMigrationRegistrySchema,
    'validators': validators.map((entry) => entry.toJson()).toList(),
    'migrations': migrations.map((entry) => entry.toJson()).toList(),
  });

  static Map<String, Object?> registryDocument() => <String, Object?>{
    'schema': portableSchemaMigrationRegistrySchema,
    'currentVersion': currentVersion,
    'validators': validators.map((entry) => entry.toJson()).toList(),
    'migrations': migrations.map((entry) => entry.toJson()).toList(),
    'registryDigest': registryDigest,
    'boundary':
        'Deterministic local structure and semantic-policy evidence only; not issuer authenticity, encryption, durable import, FHIR conformance, clinical correctness, or medical advice.',
  };

  static PortableSchemaMigrationAssessment assess({
    required String sourceJson,
    required Map<String, Object?> sourceDocument,
  }) {
    final rawVersion = sourceDocument['schemaVersion'];
    final source = rawVersion is int ? descriptorForVersion(rawVersion) : null;
    if (source == null) {
      return PortableSchemaMigrationAssessment(
        accepted: false,
        findings: const <String>['No frozen validator accepts this schema.'],
        sourceValidator: null,
        targetValidator: null,
        migration: null,
        outputDocument: null,
        receipt: null,
      );
    }
    final findings = _validateEnvelope(sourceDocument, source);
    if (findings.isNotEmpty) {
      return PortableSchemaMigrationAssessment(
        accepted: false,
        findings: List<String>.unmodifiable(findings),
        sourceValidator: source,
        targetValidator: null,
        migration: null,
        outputDocument: null,
        receipt: null,
      );
    }

    if (source.version == currentVersion) {
      final output = _cloneMap(sourceDocument);
      final receipt = _receipt(
        sourceJson: sourceJson,
        sourceDocument: sourceDocument,
        outputDocument: output,
        source: source,
        target: source,
        migrationIdentity: portableSha256(
          'parkinsum-portable-no-migration-required-v1',
        ),
        semanticDiffSha256: portableCanonicalSha256(const <Object?>[]),
        decision: 'not_required_current_schema',
        warnings: const <String>[],
        heldFields: const <String>['durable_import'],
      );
      return PortableSchemaMigrationAssessment(
        accepted: true,
        findings: const <String>[],
        sourceValidator: source,
        targetValidator: source,
        migration: null,
        outputDocument: output,
        receipt: receipt,
      );
    }

    if (source.version != v2ToV3.sourceVersion &&
        source.version != v3ToV4.sourceVersion) {
      return PortableSchemaMigrationAssessment(
        accepted: false,
        findings: const <String>[
          'No directed migration reaches the current schema.',
        ],
        sourceValidator: source,
        targetValidator: null,
        migration: null,
        outputDocument: null,
        receipt: null,
      );
    }
    final intermediate = source.version == v2ToV3.sourceVersion
        ? _migrateV2ToV3(sourceDocument)
        : _cloneMap(sourceDocument);
    final intermediateFindings = _validateEnvelope(intermediate, v3);
    if (source.version == v2ToV3.sourceVersion) {
      intermediateFindings.addAll(
        _preservationFindings(sourceDocument, intermediate),
      );
    }
    if (intermediateFindings.isNotEmpty) {
      return PortableSchemaMigrationAssessment(
        accepted: false,
        findings: List<String>.unmodifiable(intermediateFindings),
        sourceValidator: source,
        targetValidator: v3,
        migration: source.version == v2ToV3.sourceVersion ? v2ToV3 : null,
        outputDocument: null,
        receipt: null,
      );
    }

    final output = _migrateV3ToV4(intermediate);
    final targetFindings = _validateEnvelope(output, v4);
    targetFindings.addAll(_v3ToV4PreservationFindings(intermediate, output));
    if (targetFindings.isNotEmpty) {
      return PortableSchemaMigrationAssessment(
        accepted: false,
        findings: List<String>.unmodifiable(targetFindings),
        sourceValidator: source,
        targetValidator: v4,
        migration: source.version == 2 ? v2ToV4 : v3ToV4,
        outputDocument: null,
        receipt: null,
      );
    }
    final migration = source.version == 2 ? v2ToV4 : v3ToV4;
    final reminderCount = source.version == 2
        ? (Map<String, Object?>.from(
                    sourceDocument['files'] as Map,
                  )['reminders.json']
                  as List)
              .length
        : 0;
    final receipt = _receipt(
      sourceJson: sourceJson,
      sourceDocument: sourceDocument,
      outputDocument: output,
      source: source,
      target: v4,
      migrationIdentity: migration.migrationIdentity,
      semanticDiffSha256: migration.semanticDiffSha256,
      decision: 'preview_only_no_write',
      warnings: <String>[
        if (reminderCount > 0)
          '$reminderCount legacy reminder presentation intent row(s) received frozen minimal English defaults.',
        'Source schema ${source.version} did not contain personal observations; the migrated preview marks them unavailable instead of inferring an empty history.',
      ],
      heldFields: const <String>[
        r'$.files.reminders.json[*].targetSchedulingConsentStatus',
        r'$.files.observations.json.records',
        'durable_import',
      ],
    );
    return PortableSchemaMigrationAssessment(
      accepted: true,
      findings: const <String>[],
      sourceValidator: source,
      targetValidator: v4,
      migration: migration,
      outputDocument: output,
      receipt: receipt,
    );
  }

  static PortableSchemaMigrationReceipt _receipt({
    required String sourceJson,
    required Map<String, Object?> sourceDocument,
    required Map<String, Object?> outputDocument,
    required PortableSchemaValidatorDescriptor source,
    required PortableSchemaValidatorDescriptor target,
    required String migrationIdentity,
    required String semanticDiffSha256,
    required String decision,
    required List<String> warnings,
    required List<String> heldFields,
  }) {
    final withoutDigest = PortableSchemaMigrationReceipt(
      sourceVersion: source.version,
      targetVersion: target.version,
      sourceBytesSha256: portableSha256(sourceJson),
      sourceCanonicalSha256: portableCanonicalSha256(sourceDocument),
      outputCanonicalSha256: portableCanonicalSha256(outputDocument),
      sourceValidatorIdentity: source.validatorIdentity,
      targetValidatorIdentity: target.validatorIdentity,
      migrationIdentity: migrationIdentity,
      semanticDiffSha256: semanticDiffSha256,
      decision: decision,
      warnings: List<String>.unmodifiable(warnings),
      heldFields: List<String>.unmodifiable(heldFields),
      receiptSha256: '',
    );
    return PortableSchemaMigrationReceipt(
      sourceVersion: withoutDigest.sourceVersion,
      targetVersion: withoutDigest.targetVersion,
      sourceBytesSha256: withoutDigest.sourceBytesSha256,
      sourceCanonicalSha256: withoutDigest.sourceCanonicalSha256,
      outputCanonicalSha256: withoutDigest.outputCanonicalSha256,
      sourceValidatorIdentity: withoutDigest.sourceValidatorIdentity,
      targetValidatorIdentity: withoutDigest.targetValidatorIdentity,
      migrationIdentity: withoutDigest.migrationIdentity,
      semanticDiffSha256: withoutDigest.semanticDiffSha256,
      decision: withoutDigest.decision,
      warnings: withoutDigest.warnings,
      heldFields: withoutDigest.heldFields,
      receiptSha256: portableCanonicalSha256(
        withoutDigest.toJson(includeDigest: false),
      ),
    );
  }

  static Map<String, Object?> _migrateV2ToV3(Map<String, Object?> source) {
    final output = _cloneMap(source)..['schemaVersion'] = 3;
    final files = Map<String, Object?>.from(output['files'] as Map);
    final reminders = <Object?>[];
    for (final raw in files['reminders.json'] as List) {
      final row = Map<String, Object?>.from(raw as Map)
        ..['notificationPrivacyMode'] = 'minimal'
        ..['notificationLocaleCode'] = 'en'
        ..['notificationLocaleDecisionCode'] = 'en'
        ..['sourcePresentationSchema'] = _presentationSchema
        ..['sourcePresentationSha256'] = _frozenMinimalEnglishPresentationSha256
        ..['presentationIdentityStatus'] = _presentationStatus
        ..['targetSchedulingConsentStatus'] = _targetConsent;
      reminders.add(row);
    }
    files['reminders.json'] = reminders;
    output['files'] = files;
    _reseal(output);
    return output;
  }

  static Map<String, Object?> _migrateV3ToV4(Map<String, Object?> source) {
    final output = _cloneMap(source)..['schemaVersion'] = 4;
    final files = Map<String, Object?>.from(output['files'] as Map)
      ..['observations.json'] = <String, Object?>{
        'availability': 'unavailable_in_source_schema',
        'records': <Object?>[],
      };
    output['files'] = files;
    final manifest = Map<String, Object?>.from(output['manifest'] as Map);
    final privacy =
        Map<String, Object?>.from(manifest['privacyBoundary'] as Map)
          ..['scope'] = _v4ScopeBoundary
          ..['excluded'] = excludedValuesForVersion(4);
    manifest['privacyBoundary'] = privacy;
    output['manifest'] = manifest;
    _reseal(output);
    return output;
  }

  static List<String> _v3ToV4PreservationFindings(
    Map<String, Object?> source,
    Map<String, Object?> output,
  ) {
    final stripped = _cloneMap(output)..['schemaVersion'] = 3;
    final files = Map<String, Object?>.from(stripped['files'] as Map)
      ..remove('observations.json');
    stripped['files'] = files;
    final manifest = Map<String, Object?>.from(stripped['manifest'] as Map);
    final privacy =
        Map<String, Object?>.from(manifest['privacyBoundary'] as Map)
          ..['scope'] = _scopeBoundary
          ..['excluded'] = excludedValuesForVersion(3);
    manifest['privacyBoundary'] = privacy;
    stripped['manifest'] = manifest;
    _reseal(stripped);
    return portableCanonicalJson(source) == portableCanonicalJson(stripped)
        ? const <String>[]
        : const <String>[
            'The v3-to-v4 migration changed a source value outside the new observation availability marker.',
          ];
  }

  static List<String> _preservationFindings(
    Map<String, Object?> source,
    Map<String, Object?> output,
  ) {
    final stripped = _cloneMap(output)..['schemaVersion'] = 2;
    final strippedFiles = Map<String, Object?>.from(stripped['files'] as Map);
    final reminders = <Object?>[];
    for (final raw in strippedFiles['reminders.json'] as List) {
      final row = Map<String, Object?>.from(raw as Map);
      for (final field in _v3ReminderFields) {
        if (!_v2ReminderFields.contains(field)) row.remove(field);
      }
      reminders.add(row);
    }
    strippedFiles['reminders.json'] = reminders;
    stripped['files'] = strippedFiles;
    // Integrity metadata is expected to change. Compare the complete user-data
    // payload separately so null, zero, false, empty and missing remain exact.
    final sourceFiles = Map<String, Object?>.from(source['files'] as Map);
    if (portableCanonicalJson(sourceFiles) !=
        portableCanonicalJson(strippedFiles)) {
      return const <String>[
        'The migration changed a source value outside the reviewed semantic diff.',
      ];
    }
    return const <String>[];
  }

  static List<String> _validateEnvelope(
    Map<String, Object?> root,
    PortableSchemaValidatorDescriptor descriptor,
  ) {
    final findings = <String>[];
    final expectedPaths = filePathsForVersion(descriptor.version);
    _exactKeys(root, _rootFields, r'$', findings);
    if (root['format'] != format ||
        root['schemaVersion'] != descriptor.version) {
      findings.add(
        'Portable format or schema version does not match its validator.',
      );
    }
    final manifest = _asMap(root['manifest']);
    final files = _asMap(root['files']);
    if (manifest == null || files == null) {
      findings.add('Portable manifest or file map is missing.');
      return findings;
    }
    _exactKeys(manifest, _manifestFields, r'$.manifest', findings);
    _exactKeys(files, expectedPaths, r'$.files', findings);
    final owner = _asMap(manifest['ownerScope']);
    final integrity = _asMap(manifest['integrity']);
    final privacy = _asMap(manifest['privacyBoundary']);
    if (owner == null || integrity == null || privacy == null) {
      findings.add('Portable manifest policy objects are missing.');
      return findings;
    }
    _exactKeys(owner, _ownerFields, r'$.manifest.ownerScope', findings);
    _exactKeys(integrity, _integrityFields, r'$.manifest.integrity', findings);
    _exactKeys(
      privacy,
      _privacyFields,
      r'$.manifest.privacyBoundary',
      findings,
    );
    if (owner['bindingAlgorithm'] != 'SHA-256' ||
        owner['bindingDomain'] != 'parkinsum-portable-owner-v1' ||
        owner['rawIdentifierIncluded'] != false ||
        integrity['algorithm'] != 'SHA-256' ||
        integrity['canonicalization'] != canonicalization ||
        integrity['signatureStatus'] != 'unsigned' ||
        manifest['producer'] != 'parkinsum_companion' ||
        privacy['encryption'] != 'none' ||
        privacy['containsSensitiveUserData'] != true ||
        privacy['identityLinkability'] != _identityLinkabilityBoundary ||
        privacy['scope'] != scopeForVersion(descriptor.version) ||
        !_sameStringList(
          privacy['excluded'],
          excludedValuesForVersion(descriptor.version),
        ) ||
        privacy['notAClaim'] != _notAClaimBoundary) {
      findings.add(
        'Portable frozen owner, integrity, or privacy policy drifted.',
      );
    }
    final reminderRaw = files['reminders.json'];
    if (reminderRaw is! List) {
      findings.add('Portable reminder rows are not a list.');
    } else {
      final expected = descriptor.version == 2
          ? _v2ReminderFields
          : _v3ReminderFields;
      for (var index = 0; index < reminderRaw.length; index++) {
        final row = _asMap(reminderRaw[index]);
        if (row == null) {
          findings.add('Portable reminder row $index is not an object.');
          continue;
        }
        _exactKeys(
          row,
          expected,
          r'$.files.reminders.json['
          '$index]',
          findings,
        );
        if (row['activationTokenStatus'] != 'excluded_from_portable_package' ||
            row['deliveryBoundary'] != _reminderBoundary) {
          findings.add(
            'Portable reminder row $index crossed its safety boundary.',
          );
        }
        if (descriptor.version >= 3 &&
            (row['presentationIdentityStatus'] != _presentationStatus ||
                row['targetSchedulingConsentStatus'] != _targetConsent ||
                row['sourcePresentationSchema'] != _presentationSchema ||
                !_isSha256(row['sourcePresentationSha256']))) {
          findings.add(
            'Portable reminder row $index has invalid v3 presentation evidence.',
          );
        }
      }
    }

    if (descriptor.version >= 4) {
      final observations = _asMap(files['observations.json']);
      if (observations == null) {
        findings.add('Portable observations container is missing.');
      } else {
        _exactKeys(
          observations,
          _v4ObservationContainerFields,
          r'$.files.observations.json',
          findings,
        );
        final availability = observations['availability'];
        if (availability != 'captured_current_local_snapshot' &&
            availability != 'unavailable_in_source_schema') {
          findings.add('Portable observation availability is invalid.');
        }
        final records = observations['records'];
        if (records is! List) {
          findings.add('Portable observation records are not a list.');
        } else {
          for (var index = 0; index < records.length; index++) {
            final row = _asMap(records[index]);
            if (row == null) {
              findings.add('Portable observation row $index is invalid.');
              continue;
            }
            _exactKeys(
              row,
              _v4ObservationRecordFields,
              r'$.files.observations.json.records['
              '$index]',
              findings,
            );
            if (row['schemaVersion'] != 1 ||
                row['recorderRole'] != 'package_owner') {
              findings.add(
                'Portable observation row $index has unsupported version or recorder role.',
              );
            }
          }
        }
        if (availability == 'unavailable_in_source_schema' &&
            records is List &&
            records.isNotEmpty) {
          findings.add(
            'Unavailable source observations cannot contain fabricated rows.',
          );
        }
      }
    }

    final manifestRows = manifest['files'];
    if (manifestRows is! List) {
      findings.add('Portable manifest file inventory is missing.');
      return findings;
    }
    final byPath = <String, Map<String, Object?>>{};
    for (var index = 0; index < manifestRows.length; index++) {
      final row = _asMap(manifestRows[index]);
      if (row == null) {
        findings.add('Portable manifest file row $index is invalid.');
        continue;
      }
      _exactKeys(
        row,
        _manifestFileFields,
        r'$.manifest.files['
        '$index]',
        findings,
      );
      final path = row['path'];
      if (path is! String || byPath.containsKey(path)) {
        findings.add('Portable manifest file path is invalid or duplicated.');
      } else {
        byPath[path] = row;
      }
    }
    if (byPath.keys.toSet().difference(expectedPaths.toSet()).isNotEmpty ||
        expectedPaths.toSet().difference(byPath.keys.toSet()).isNotEmpty) {
      findings.add('Portable manifest file inventory drifted.');
    } else {
      for (final path in expectedPaths) {
        final row = byPath[path]!;
        if (row['sha256'] != portableCanonicalSha256(files[path]) ||
            row['recordCount'] != _recordCount(files[path])) {
          findings.add(
            'Portable manifest checksum or count drifted for $path.',
          );
        }
      }
    }
    final contentSha = portableCanonicalSha256(files);
    if (integrity['contentSha256'] != contentSha) {
      findings.add('Portable content digest drifted.');
    }
    final ownerDigest = owner['bindingSha256'];
    final expectedPackageId = portableSha256(
      'parkinsum-portable-package-v${descriptor.version}|$ownerDigest|$contentSha',
    );
    if (manifest['packageId'] != expectedPackageId) {
      findings.add('Portable package identity drifted.');
    }
    return findings;
  }

  static void _reseal(Map<String, Object?> root) {
    final files = Map<String, Object?>.from(root['files'] as Map);
    final manifest = Map<String, Object?>.from(root['manifest'] as Map);
    final owner = Map<String, Object?>.from(manifest['ownerScope'] as Map);
    final integrity = Map<String, Object?>.from(manifest['integrity'] as Map);
    final contentSha = portableCanonicalSha256(files);
    integrity['contentSha256'] = contentSha;
    manifest['integrity'] = integrity;
    manifest['files'] = <Object?>[
      for (final path in filePathsForVersion(root['schemaVersion'] as int))
        <String, Object?>{
          'path': path,
          'sha256': portableCanonicalSha256(files[path]),
          'recordCount': _recordCount(files[path]),
        },
    ];
    manifest['packageId'] = portableSha256(
      'parkinsum-portable-package-v${root['schemaVersion']}|'
      '${owner['bindingSha256']}|$contentSha',
    );
    root['manifest'] = manifest;
  }

  static void _exactKeys(
    Map<String, Object?> value,
    List<String> expected,
    String path,
    List<String> findings,
  ) {
    final actual = value.keys.toSet();
    final expectedSet = expected.toSet();
    for (final key in expectedSet.difference(actual).toList()..sort()) {
      findings.add('$path.$key is missing from the frozen schema.');
    }
    for (final key in actual.difference(expectedSet).toList()..sort()) {
      findings.add('$path.$key is unknown to the frozen schema.');
    }
  }

  static Map<String, Object?>? _asMap(Object? value) =>
      value is Map ? Map<String, Object?>.from(value) : null;

  static Map<String, Object?> _cloneMap(Map<String, Object?> value) =>
      Map<String, Object?>.from(jsonDecode(jsonEncode(value)) as Map);

  static int _recordCount(Object? value) {
    if (value is List) return value.length;
    if (value is Map) {
      if (value['records'] is List) return (value['records'] as List).length;
      if (value['links'] is List) return (value['links'] as List).length;
    }
    return value is Map ? 1 : 0;
  }

  static bool _isSha256(Object? value) =>
      value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  static bool _sameStringList(Object? value, List<String> expected) {
    if (value is! List || value.length != expected.length) return false;
    for (var index = 0; index < expected.length; index++) {
      if (value[index] != expected[index]) return false;
    }
    return true;
  }
}
