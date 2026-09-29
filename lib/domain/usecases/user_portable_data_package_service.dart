import 'dart:convert';
import 'dart:developer' as developer;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show compute;

import '../../core/models/drug_definition.dart';
import '../../core/models/administration_dose_confirmation.dart';
import '../../core/models/food_item.dart';
import '../../core/models/intake.dart';
import '../../core/models/meal.dart';
import '../../core/models/medication_product_pack.dart';
import '../../core/models/user_profile.dart';
import '../../core/constants/profile_options.dart';
import '../../core/services/reminder_notification_privacy_policy.dart';
import '../entities/dose_expression.dart';
import '../entities/medication_assertion_reconciliation.dart';
import '../entities/nutrient_derivation.dart';
import '../entities/personal_observation.dart';
import '../entities/portable_schema_migration.dart';
import '../entities/versioned_dose_unit_mapping.dart';
import '../entities/user_logging_reminder.dart';
import 'administration_dose_confirmation_coordinator.dart';
import 'dosage_note_parser.dart';
import 'portable_schema_migration_registry.dart';

const userPortableDataPackageFormat = 'parkinsum_user_portable_data_package';
const userPortableDataPackageSchemaVersion = 4;
const userPortableDataLegacyReadableVersion = 2;
const Set<int> userPortableDataLegacyReadableVersions = <int>{2, 3};
const userPortableDataCanonicalization = 'sorted-key-json-v1';
const userPortableDataMaxPackageBytes = 32 * 1024 * 1024;
const userPortableDataMaxJsonDepth = 24;
const userPortableDataMaxStringBytes = 64 * 1024;
const userPortableDataMaxKeyBytes = 256;
const userPortableDataMaxNumberTokenChars = 128;
const userPortableDataMaxMapFields = 128;
const userPortableDataMaxJsonNodes = 500000;
const userPortableDataMaxTotalRecords = 185000;

const Set<String> _userPortableDataScopeKinds = <String>{
  'firebase_authenticated_account',
  'local_device_account',
};
const List<String> _userPortableDataLegacyExcludedValues = <String>[
  'raw_account_uid',
  'raw_email',
  'raw_dose_owner_scope',
  'profile.patientId',
  'credentials',
  'reminder.activationToken',
  'local_ai_endpoints',
  'cloud_only_clinical_audit_documents',
];
const String _userPortableDataScopeDescription =
    'Current loaded profile, selections, intakes, meals, this-device reminders, and relationship audit links.';
const String _userPortableDataV4ScopeDescription =
    'Current loaded profile, selections, intakes, meals, this-device reminders, owner-entered personal observations, and relationship audit links.';
const List<String> _userPortableDataV4ExcludedValues = <String>[
  ..._userPortableDataLegacyExcludedValues,
  'personalObservation.recorderId',
];
const String _userPortableDataObservationRecorderRole = 'package_owner';
const String _userPortableDataNotAClaim =
    'Not an encrypted backup, anonymous or unlinkable dataset, account deletion receipt, complete cloud export, clinical record, or legal-compliance certification.';
const String _userPortableDataIdentityLinkabilityBoundary =
    'Raw account identifiers are excluded, but current dose receipts and medication assertions retain stable unsalted owner-scope digests for integrity verification. Those pseudonymous digests can link artifacts from the same scope and can be dictionary-matched when the source scope, such as a local email-derived identifier, has low entropy.';
const String _userPortableDataReminderBoundary =
    'User-authored logging prompt only; not a prescribed medication time and not proof of operating-system delivery.';
const String _userPortableReminderTargetConsentStatus =
    'required_before_target_permission_or_scheduling';
const String _userPortableReminderPresentationIdentityStatus =
    'source_digest_only_recompute_on_target';
const String _userPortableDataDoseConfirmationBoundary =
    'ParkinSUM local user-assertion receipt with a stable pseudonymous owner-scope digest; not anonymous or unlinkable; not FHIR conformance, a prescription, clinician verification, digital signature, or proof of administration.';
const String _userPortableDataReconciliationBoundary =
    'Immutable source assertions and append-only review decisions are retained as evidence; they are not proof of administration, adherence, or clinical reconciliation.';
const String _userPortableDataReconciliationEnvelopeBoundary =
    'Source-conflict history only; not proof of administration, adherence, or clinical reconciliation.';
const String _userPortableDataDoseTruthBoundary =
    'Raw and parseable dose evidence is preserved without becoming a result. Canonical quantity requires a row-bound owner-scoped confirmation, a conflict-free assertion graph, and evidence available by the export observation time.';
const String _userPortableDataAuditReason =
    'The current cross-backend repository does not expose a complete, consistent user clinical-audit read contract.';
const String _userPortableDataProductMeaningBoundary =
    'Product metadata is not evidence of the amount consumed.';
const String _userPortableDataComputedTotalsStatus =
    'not_exported_because_unknown_nutrients_must_not_be_summed_as_zero';

typedef UserPortableDataJsonDecode = Object? Function(String source);

const Map<String, int> userPortableDataRecordLimits = <String, int>{
  'profile.json': 1,
  'preferences.json': 1,
  'medication_selections.json': 512,
  'intakes.json': 50000,
  'meals.json': 25000,
  'reminders.json': 512,
  'audit_links.json': 100000,
  'observations.json': 5000,
};

const List<String> userPortableDataFilePaths = <String>[
  'profile.json',
  'preferences.json',
  'medication_selections.json',
  'intakes.json',
  'meals.json',
  'reminders.json',
  'audit_links.json',
  'observations.json',
];

/// Immutable, already-account-scoped state captured from the visible app.
///
/// [userScope] is the effective package-owner capability used to derive the
/// manifest binding. [doseOwnerScope] is the distinct raw authenticated scope
/// already bound into dose receipts and assertions. The latter is used only
/// for in-memory verification and is never serialized. This keeps a Firebase
/// uid, local email-derived id, and the legacy `patientId` field out of the
/// portable artifact.
class UserPortableDataSnapshot {
  const UserPortableDataSnapshot({
    required this.userScope,
    required this.doseOwnerScope,
    required this.scopeKind,
    required this.profile,
    required this.activeDrugIds,
    required this.intakes,
    required this.meals,
    required this.medicationCatalog,
    required this.foodCatalog,
    required this.reminders,
    this.observations = const <PersonalObservation>[],
  });

  final String userScope;

  /// Raw authenticated owner used only to re-evaluate dose evidence in memory.
  ///
  /// This value is deliberately separate from [userScope], which can be a
  /// protected opaque export capability. It is never serialized into the
  /// portable package.
  final String doseOwnerScope;
  final String scopeKind;
  final UserProfile profile;
  final Iterable<String> activeDrugIds;
  final Iterable<Intake> intakes;
  final Iterable<Meal> meals;
  final Iterable<DrugDefinition> medicationCatalog;
  final Iterable<FoodItem> foodCatalog;
  final Iterable<UserLoggingReminder> reminders;
  final Iterable<PersonalObservation> observations;
}

class UserPortableDataFileSummary {
  const UserPortableDataFileSummary({
    required this.path,
    required this.sha256,
    required this.recordCount,
  });

  final String path;
  final String sha256;
  final int recordCount;
}

class UserPortableDataPackageArtifact {
  const UserPortableDataPackageArtifact({
    required this.document,
    required this.canonicalJson,
    required this.prettyJson,
    required this.fileName,
    required this.packageId,
    required this.contentSha256,
    required this.ownerScopeSha256,
    required this.files,
  });

  final Map<String, Object?> document;
  final String canonicalJson;
  final String prettyJson;
  final String fileName;
  final String packageId;
  final String contentSha256;
  final String ownerScopeSha256;
  final List<UserPortableDataFileSummary> files;
}

enum UserPortableDataPreviewStatus {
  ready,
  wrongOwner,
  unsupportedSchema,
  corrupt,
}

class UserPortableDataImportPreview {
  const UserPortableDataImportPreview({
    required this.status,
    required this.schemaVersion,
    required this.packageId,
    required this.recordCounts,
    required this.conflicts,
    required this.unsupportedFields,
    required this.proposedMigrations,
    required this.findings,
    required this.reminderPresentation,
    required this.schemaMigrationReceipt,
  });

  final UserPortableDataPreviewStatus status;
  final int? schemaVersion;
  final String? packageId;
  final Map<String, int> recordCounts;
  final Map<String, List<String>> conflicts;
  final List<String> unsupportedFields;
  final List<String> proposedMigrations;
  final List<String> findings;
  final UserPortableReminderPresentationSummary reminderPresentation;
  final PortableSchemaMigrationReceipt? schemaMigrationReceipt;

  bool get mayProceedToFutureImport =>
      status == UserPortableDataPreviewStatus.ready;

  int get conflictCount =>
      conflicts.values.fold<int>(0, (sum, ids) => sum + ids.length);
}

class UserPortableReminderPresentationSummary {
  const UserPortableReminderPresentationSummary({
    required this.totalCount,
    required this.enabledIntentCount,
    required this.targetConsentRequiredCount,
    required this.legacyDefaultCount,
    required this.currentPolicyMatchCount,
    required this.currentPolicyDriftCount,
    required this.localeDecisionMismatchCount,
    required this.privacyModes,
    required this.scheduledLanguageCodes,
  });

  static const empty = UserPortableReminderPresentationSummary(
    totalCount: 0,
    enabledIntentCount: 0,
    targetConsentRequiredCount: 0,
    legacyDefaultCount: 0,
    currentPolicyMatchCount: 0,
    currentPolicyDriftCount: 0,
    localeDecisionMismatchCount: 0,
    privacyModes: <String>[],
    scheduledLanguageCodes: <String>[],
  );

  final int totalCount;
  final int enabledIntentCount;
  final int targetConsentRequiredCount;
  final int legacyDefaultCount;
  final int currentPolicyMatchCount;
  final int currentPolicyDriftCount;
  final int localeDecisionMismatchCount;
  final List<String> privacyModes;
  final List<String> scheduledLanguageCodes;

  Map<String, Object?> toJson() => <String, Object?>{
    'totalCount': totalCount,
    'enabledIntentCount': enabledIntentCount,
    'targetConsentRequiredCount': targetConsentRequiredCount,
    'legacyDefaultCount': legacyDefaultCount,
    'currentPolicyMatchCount': currentPolicyMatchCount,
    'currentPolicyDriftCount': currentPolicyDriftCount,
    'localeDecisionMismatchCount': localeDecisionMismatchCount,
    'privacyModes': privacyModes,
    'scheduledLanguageCodes': scheduledLanguageCodes,
  };
}

/// Builds and inspects a single-file, JSON user-data package.
///
/// This is intentionally export + dry-run only. It performs no persistence,
/// account deletion, cloud audit enumeration, or clinical interpretation.
class UserPortableDataPackageService {
  const UserPortableDataPackageService({
    this.maxPackageBytes = userPortableDataMaxPackageBytes,
    this.decodeJson = jsonDecode,
  });

  final int maxPackageBytes;
  final UserPortableDataJsonDecode decodeJson;

  UserPortableDataPackageArtifact create({
    required UserPortableDataSnapshot snapshot,
    required DateTime generatedAt,
  }) {
    if (maxPackageBytes <= 0) {
      throw StateError('Portable package byte budget must be positive.');
    }
    final rawScope = snapshot.userScope.trim();
    if (rawScope.isEmpty) {
      throw ArgumentError.value(
        snapshot.userScope,
        'snapshot.userScope',
        'An account/device scope is required.',
      );
    }
    final doseOwnerScope = snapshot.doseOwnerScope.trim();
    if (doseOwnerScope.isEmpty) {
      throw ArgumentError.value(
        snapshot.doseOwnerScope,
        'snapshot.doseOwnerScope',
        'The authenticated dose-owner scope is required.',
      );
    }
    final scopeKind = snapshot.scopeKind.trim();
    if (!_userPortableDataScopeKinds.contains(scopeKind)) {
      throw ArgumentError.value(
        snapshot.scopeKind,
        'snapshot.scopeKind',
        'The scope kind is unsupported.',
      );
    }
    final ownerScopeSha256 = _scopeDigest(rawScope, scopeKind);
    final foods = <String, FoodItem>{
      for (final food in snapshot.foodCatalog) food.id: food,
    };
    final medications = <String, DrugDefinition>{
      for (final medication in snapshot.medicationCatalog)
        medication.id: medication,
    };

    final activeDrugIds =
        snapshot.activeDrugIds
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toList()
          ..sort();
    final intakes = snapshot.intakes.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final activeDrugIdSet = activeDrugIds.toSet();
    if (activeDrugIdSet.length != activeDrugIds.length) {
      throw const FormatException('Duplicate active medication id.');
    }
    final exportedMedicationIds = <String>{
      ...activeDrugIdSet,
      ...intakes.map((intake) => intake.drugId.trim()),
    }.toList()..sort();
    final meals = snapshot.meals.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final reminders = snapshot.reminders.toList()
      ..sort((left, right) => left.id.compareTo(right.id));
    final observations = snapshot.observations.toList()
      ..sort((left, right) {
        final occurred = left.occurredAt.compareTo(right.occurredAt);
        if (occurred != 0) return occurred;
        final recorded = left.recordedAt.compareTo(right.recordedAt);
        return recorded == 0 ? left.id.compareTo(right.id) : recorded;
      });
    final generatedUtc = generatedAt.toUtc();
    final doseParser = DosageNoteParser();
    final doseCoordinator = AdministrationDoseConfirmationCoordinator(
      parser: doseParser,
    );

    final files = <String, Object?>{
      'profile.json': _profile(snapshot.profile),
      'preferences.json': _preferences(snapshot.profile),
      'medication_selections.json': <Object?>[
        for (final id in exportedMedicationIds)
          _medicationSelection(
            id,
            medications[id],
            activeAtExport: activeDrugIdSet.contains(id),
          ),
      ],
      'intakes.json': <Object?>[
        for (final intake in intakes)
          _intake(
            intake,
            medications[intake.drugId],
            doseOwnerScope: doseOwnerScope,
            observedAt: generatedUtc,
            parser: doseParser,
            coordinator: doseCoordinator,
          ),
      ],
      'meals.json': <Object?>[for (final meal in meals) _meal(meal, foods)],
      'reminders.json': <Object?>[
        for (final reminder in reminders) _reminder(reminder),
      ],
      'observations.json': <String, Object?>{
        'availability': 'captured_current_local_snapshot',
        'records': <Object?>[
          for (final observation in observations)
            _portableObservation(observation),
        ],
      },
      'audit_links.json': _auditLinks(
        intakes: intakes,
        meals: meals,
        reminders: reminders,
      ),
    };
    _validateJsonValue(files, r'$files');
    _requireRecordBudgets(files);
    _requireKnownIdentifiers(files);
    final schemaFindings = <String>[];
    final unsupportedFields = <String>[];
    _validateKnownFileShapes(
      files,
      schemaFindings,
      unsupportedFields,
      schemaVersion: userPortableDataPackageSchemaVersion,
    );
    if (schemaFindings.isNotEmpty || unsupportedFields.isNotEmpty) {
      throw FormatException(
        schemaFindings.isNotEmpty
            ? schemaFindings.first
            : 'Generated package contains an unsupported schema field.',
      );
    }

    final fileSummaries = <UserPortableDataFileSummary>[
      for (final path in userPortableDataFilePaths)
        UserPortableDataFileSummary(
          path: path,
          sha256: _sha256(_canonicalJson(files[path])),
          recordCount: _recordCount(files[path]),
        ),
    ];
    final contentSha256 = _sha256(_canonicalJson(files));
    final packageId = _sha256(
      'parkinsum-portable-package-v$userPortableDataPackageSchemaVersion|'
      '$ownerScopeSha256|$contentSha256',
    );
    final manifest = <String, Object?>{
      'packageId': packageId,
      'createdAt': generatedUtc.toIso8601String(),
      'producer': 'parkinsum_companion',
      'ownerScope': <String, Object?>{
        'kind': scopeKind,
        'bindingAlgorithm': 'SHA-256',
        'bindingDomain': 'parkinsum-portable-owner-v1',
        'bindingSha256': ownerScopeSha256,
        'rawIdentifierIncluded': false,
      },
      'integrity': <String, Object?>{
        'algorithm': 'SHA-256',
        'canonicalization': userPortableDataCanonicalization,
        'contentSha256': contentSha256,
        'signatureStatus': 'unsigned',
      },
      'files': <Object?>[
        for (final file in fileSummaries)
          <String, Object?>{
            'path': file.path,
            'sha256': file.sha256,
            'recordCount': file.recordCount,
          },
      ],
      'privacyBoundary': <String, Object?>{
        'encryption': 'none',
        'containsSensitiveUserData': true,
        'excluded': _userPortableDataV4ExcludedValues,
        'identityLinkability': _userPortableDataIdentityLinkabilityBoundary,
        'scope': _userPortableDataV4ScopeDescription,
        'notAClaim': _userPortableDataNotAClaim,
      },
    };
    final document = <String, Object?>{
      'format': userPortableDataPackageFormat,
      'schemaVersion': userPortableDataPackageSchemaVersion,
      'manifest': manifest,
      'files': files,
    };
    _validateJsonValue(document, r'$');
    final outputBudgetFinding = _decodedBudgetFinding(document);
    if (outputBudgetFinding != null) {
      throw FormatException(outputBudgetFinding);
    }
    final sortedDocument = _sortJson(document) as Map<String, Object?>;
    final canonicalJson = jsonEncode(sortedDocument);
    final prettyJson = const JsonEncoder.withIndent(
      '  ',
    ).convert(sortedDocument);
    if (utf8.encode(prettyJson).length > maxPackageBytes) {
      throw FormatException(
        'Portable package exceeds the $maxPackageBytes-byte export budget.',
      );
    }
    final stamp = generatedUtc
        .toIso8601String()
        .replaceAll(RegExp(r'[-:]'), '')
        .replaceAll(RegExp(r'\..*$'), '')
        .replaceAll('T', '-');
    return UserPortableDataPackageArtifact(
      document: Map<String, Object?>.unmodifiable(sortedDocument),
      canonicalJson: canonicalJson,
      prettyJson: prettyJson,
      fileName:
          'parkinsum-user-data-$stamp-${packageId.substring(0, 12)}.parkinsum.json',
      packageId: packageId,
      contentSha256: contentSha256,
      ownerScopeSha256: ownerScopeSha256,
      files: List<UserPortableDataFileSummary>.unmodifiable(fileSummaries),
    );
  }

  /// Parses and validates a package without changing any durable state.
  UserPortableDataImportPreview inspect({
    required String packageJson,
    required String currentUserScope,
    required String currentDoseOwnerScope,
    required String currentScopeKind,
    Map<String, Set<String>> existingRecordIds = const <String, Set<String>>{},
  }) {
    final findings = <String>[];
    final unsupportedFields = <String>[];
    final recordCounts = <String, int>{};
    final conflicts = <String, List<String>>{};
    var reminderPresentation = UserPortableReminderPresentationSummary.empty;
    PortableSchemaMigrationReceipt? schemaMigrationReceipt;
    int? schemaVersion;
    String? packageId;

    UserPortableDataImportPreview result(
      UserPortableDataPreviewStatus status, {
      List<String> proposedMigrations = const <String>[],
    }) => UserPortableDataImportPreview(
      status: status,
      schemaVersion: schemaVersion,
      packageId: packageId,
      recordCounts: Map<String, int>.unmodifiable(recordCounts),
      conflicts: Map<String, List<String>>.unmodifiable(conflicts),
      unsupportedFields: List<String>.unmodifiable(unsupportedFields),
      proposedMigrations: List<String>.unmodifiable(proposedMigrations),
      findings: List<String>.unmodifiable(findings),
      reminderPresentation: reminderPresentation,
      schemaMigrationReceipt: schemaMigrationReceipt,
    );

    try {
      // UTF-8 cannot use fewer bytes than the source's UTF-16 code-unit
      // length. Reject obvious oversize input before allocating another full
      // byte buffer for the exact UTF-8 measurement.
      if (packageJson.length > maxPackageBytes) {
        findings.add(
          'The package exceeds the $maxPackageBytes-byte input budget.',
        );
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final packageBytes = utf8.encode(packageJson).length;
      if (packageBytes > maxPackageBytes) {
        findings.add(
          'The package exceeds the $maxPackageBytes-byte input budget.',
        );
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final lexicalBudgetFinding = _jsonLexicalBudgetFinding(packageJson);
      if (lexicalBudgetFinding != null) {
        findings.add(lexicalBudgetFinding);
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final decoded = decodeJson(packageJson);
      if (decoded is! Map) {
        findings.add('The package root is not a JSON object.');
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final decodedBudgetFinding = _decodedBudgetFinding(decoded);
      if (decodedBudgetFinding != null) {
        findings.add(decodedBudgetFinding);
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final root = Map<String, Object?>.from(decoded);
      _collectUnsupportedKeys(
        root,
        const <String>{'format', 'schemaVersion', 'manifest', 'files'},
        r'$',
        unsupportedFields,
      );
      if (root['format'] != userPortableDataPackageFormat) {
        findings.add('The package format identifier is not supported.');
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final rawVersion = root['schemaVersion'];
      schemaVersion = rawVersion is int ? rawVersion : null;
      if (schemaVersion == null ||
          schemaVersion != userPortableDataPackageSchemaVersion &&
              !userPortableDataLegacyReadableVersions.contains(schemaVersion)) {
        findings.add(
          schemaVersion == null
              ? 'The package schemaVersion is missing or invalid.'
              : 'Schema version $schemaVersion is not supported by this app.',
        );
        return result(
          UserPortableDataPreviewStatus.unsupportedSchema,
          proposedMigrations:
              schemaVersion != null &&
                  schemaVersion < userPortableDataPackageSchemaVersion
              ? <String>[
                  'A reviewed migration from schema $schemaVersion to $userPortableDataPackageSchemaVersion is required.',
                ]
              : const <String>[],
        );
      }
      final manifestRaw = root['manifest'];
      final filesRaw = root['files'];
      if (manifestRaw is! Map || filesRaw is! Map) {
        findings.add('The manifest or embedded files object is missing.');
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final manifest = Map<String, Object?>.from(manifestRaw);
      final files = Map<String, Object?>.from(filesRaw);
      _collectUnsupportedKeys(
        manifest,
        const <String>{
          'packageId',
          'createdAt',
          'producer',
          'ownerScope',
          'integrity',
          'files',
          'privacyBoundary',
        },
        r'$.manifest',
        unsupportedFields,
      );
      final schemaPaths = PortableSchemaMigrationRegistry.filePathsForVersion(
        schemaVersion,
      );
      for (final key in files.keys) {
        if (!schemaPaths.contains(key)) {
          unsupportedFields.add(r'$.files.' + key);
        }
      }
      for (final path in schemaPaths) {
        if (!files.containsKey(path)) {
          findings.add('Required embedded file is missing: $path.');
        } else {
          recordCounts[path] = _recordCount(files[path]);
        }
      }
      final recordBudgetFinding = _recordBudgetFinding(files);
      if (recordBudgetFinding != null) findings.add(recordBudgetFinding);
      if (findings.isNotEmpty) {
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final rawPackageId = manifest['packageId'];
      packageId = rawPackageId is String ? rawPackageId : null;
      final ownerRaw = manifest['ownerScope'];
      final integrityRaw = manifest['integrity'];
      final fileManifestRaw = manifest['files'];
      if (packageId == null ||
          ownerRaw is! Map ||
          integrityRaw is! Map ||
          fileManifestRaw is! List) {
        findings.add('The manifest integrity fields are incomplete.');
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final owner = Map<String, Object?>.from(ownerRaw);
      final integrity = Map<String, Object?>.from(integrityRaw);
      _collectUnsupportedKeys(
        owner,
        const <String>{
          'kind',
          'bindingAlgorithm',
          'bindingDomain',
          'bindingSha256',
          'rawIdentifierIncluded',
        },
        r'$.manifest.ownerScope',
        unsupportedFields,
      );
      _collectUnsupportedKeys(
        integrity,
        const <String>{
          'algorithm',
          'canonicalization',
          'contentSha256',
          'signatureStatus',
        },
        r'$.manifest.integrity',
        unsupportedFields,
      );
      final privacyRaw = manifest['privacyBoundary'];
      if (privacyRaw is! Map) {
        findings.add('The package privacy boundary is missing or invalid.');
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final privacy = Map<String, Object?>.from(privacyRaw);
      _collectUnsupportedKeys(
        privacy,
        const <String>{
          'encryption',
          'containsSensitiveUserData',
          'excluded',
          'identityLinkability',
          'scope',
          'notAClaim',
        },
        r'$.manifest.privacyBoundary',
        unsupportedFields,
      );
      if (owner['bindingAlgorithm'] != 'SHA-256' ||
          owner['bindingDomain'] != 'parkinsum-portable-owner-v1' ||
          owner['rawIdentifierIncluded'] != false ||
          !_userPortableDataScopeKinds.contains(owner['kind']) ||
          integrity['algorithm'] != 'SHA-256' ||
          integrity['canonicalization'] != userPortableDataCanonicalization ||
          integrity['signatureStatus'] != 'unsigned' ||
          manifest['producer'] != 'parkinsum_companion' ||
          !_isCanonicalUtcTimestamp(manifest['createdAt']) ||
          privacy['encryption'] != 'none' ||
          privacy['containsSensitiveUserData'] != true ||
          !_sameStringList(
            privacy['excluded'],
            schemaVersion >= 4
                ? _userPortableDataV4ExcludedValues
                : _userPortableDataLegacyExcludedValues,
          ) ||
          privacy['identityLinkability'] !=
              _userPortableDataIdentityLinkabilityBoundary ||
          privacy['scope'] !=
              (schemaVersion >= 4
                  ? _userPortableDataV4ScopeDescription
                  : _userPortableDataScopeDescription) ||
          privacy['notAClaim'] != _userPortableDataNotAClaim) {
        findings.add('The owner or integrity contract is unsupported.');
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      if (!_hasRequiredKeys(manifest, const <String>{
            'packageId',
            'createdAt',
            'producer',
            'ownerScope',
            'integrity',
            'files',
            'privacyBoundary',
          }) ||
          !_hasRequiredKeys(owner, const <String>{
            'kind',
            'bindingAlgorithm',
            'bindingDomain',
            'bindingSha256',
            'rawIdentifierIncluded',
          }) ||
          !_hasRequiredKeys(integrity, const <String>{
            'algorithm',
            'canonicalization',
            'contentSha256',
            'signatureStatus',
          }) ||
          !_hasRequiredKeys(privacy, const <String>{
            'encryption',
            'containsSensitiveUserData',
            'excluded',
            'identityLinkability',
            'scope',
            'notAClaim',
          }) ||
          !_isSha256(packageId) ||
          !_isSha256(owner['bindingSha256']) ||
          !_isSha256(integrity['contentSha256'])) {
        findings.add('The manifest has a missing or invalid scalar field.');
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final expectedScope = currentUserScope.trim();
      final expectedDoseOwnerScope = currentDoseOwnerScope.trim();
      final expectedScopeKind = currentScopeKind.trim();
      if (expectedScope.isEmpty ||
          expectedDoseOwnerScope.isEmpty ||
          !_userPortableDataScopeKinds.contains(expectedScopeKind)) {
        findings.add('The current account/device scope is unavailable.');
        return result(UserPortableDataPreviewStatus.wrongOwner);
      }
      if (owner['kind'] != expectedScopeKind ||
          owner['bindingSha256'] !=
              _scopeDigest(expectedScope, expectedScopeKind)) {
        findings.add(
          'The package belongs to a different account/device scope. No import is proposed.',
        );
        return result(UserPortableDataPreviewStatus.wrongOwner);
      }
      final contentSha256 = _sha256(_canonicalJson(files));
      if (integrity['contentSha256'] != contentSha256) {
        findings.add('The package content checksum does not match.');
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      final expectedPackageId = _sha256(
        'parkinsum-portable-package-v$schemaVersion|'
        '${owner['bindingSha256']}|$contentSha256',
      );
      if (packageId != expectedPackageId) {
        findings.add('The package id does not match its owner and content.');
        return result(UserPortableDataPreviewStatus.corrupt);
      }

      final byPath = <String, Map<String, Object?>>{};
      for (final row in fileManifestRaw) {
        if (row is! Map) {
          findings.add('A manifest file row is invalid.');
          return result(UserPortableDataPreviewStatus.corrupt);
        }
        final mapped = Map<String, Object?>.from(row);
        _collectUnsupportedKeys(
          mapped,
          const <String>{'path', 'sha256', 'recordCount'},
          r'$.manifest.files',
          unsupportedFields,
        );
        final path = mapped['path'];
        if (!_hasRequiredKeys(mapped, const <String>{
              'path',
              'sha256',
              'recordCount',
            }) ||
            path is! String ||
            !_isSha256(mapped['sha256']) ||
            mapped['recordCount'] is! int ||
            (mapped['recordCount'] as int) < 0 ||
            byPath.containsKey(path)) {
          findings.add('Manifest file paths are invalid or duplicated.');
          return result(UserPortableDataPreviewStatus.corrupt);
        }
        byPath[path] = mapped;
      }
      if (byPath.keys.toSet().difference(schemaPaths.toSet()).isNotEmpty ||
          schemaPaths.toSet().difference(byPath.keys.toSet()).isNotEmpty) {
        findings.add(
          'Manifest file inventory does not match the package schema.',
        );
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      for (final path in schemaPaths) {
        final row = byPath[path]!;
        if (row['sha256'] != _sha256(_canonicalJson(files[path])) ||
            row['recordCount'] != _recordCount(files[path])) {
          findings.add('Checksum or record count mismatch for $path.');
          return result(UserPortableDataPreviewStatus.corrupt);
        }
      }

      _validateKnownFileShapes(
        files,
        findings,
        unsupportedFields,
        schemaVersion: schemaVersion,
        doseOwnerScope: expectedDoseOwnerScope,
        observedAt: DateTime.parse(manifest['createdAt'] as String),
      );
      _validateKnownIdentifiers(files, findings);
      if (findings.isNotEmpty) {
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      if (unsupportedFields.isNotEmpty) {
        findings.add(
          'Unsupported fields require a reviewed schema migration; no import is proposed.',
        );
        return result(UserPortableDataPreviewStatus.unsupportedSchema);
      }
      final migrationAssessment = PortableSchemaMigrationRegistry.assess(
        sourceJson: packageJson,
        sourceDocument: root,
      );
      if (!migrationAssessment.accepted ||
          migrationAssessment.receipt == null ||
          migrationAssessment.outputDocument == null) {
        findings.addAll(migrationAssessment.findings);
        findings.add(
          'The frozen portable-schema registry could not authorize this preview.',
        );
        return result(UserPortableDataPreviewStatus.corrupt);
      }
      if (migrationAssessment.receipt!.targetVersion != schemaVersion) {
        final migratedRoot = migrationAssessment.outputDocument!;
        final migratedFiles = Map<String, Object?>.from(
          migratedRoot['files'] as Map,
        );
        final migratedFindings = <String>[];
        final migratedUnsupported = <String>[];
        _validateKnownFileShapes(
          migratedFiles,
          migratedFindings,
          migratedUnsupported,
          schemaVersion: migrationAssessment.receipt!.targetVersion,
          doseOwnerScope: expectedDoseOwnerScope,
          observedAt: DateTime.parse(manifest['createdAt'] as String),
        );
        _validateKnownIdentifiers(migratedFiles, migratedFindings);
        if (migratedFindings.isNotEmpty || migratedUnsupported.isNotEmpty) {
          findings.add(
            'The deterministic migration output did not satisfy the target schema.',
          );
          return result(UserPortableDataPreviewStatus.corrupt);
        }
      }
      final migrationReceipt = migrationAssessment.receipt!;
      schemaMigrationReceipt = migrationReceipt;
      developer.log(
        'source=v${migrationReceipt.sourceVersion} '
        'target=v${migrationReceipt.targetVersion} '
        'decision=${migrationReceipt.decision} '
        'receipt=${migrationReceipt.receiptSha256.substring(0, 12)}',
        name: 'parkinsum.portable_schema_migration',
      );
      reminderPresentation = _reminderPresentationSummary(
        files['reminders.json'],
        schemaVersion: schemaVersion,
      );
      for (final entry in existingRecordIds.entries) {
        final incoming = _ids(files[entry.key]);
        final overlapping = incoming.intersection(entry.value).toList()..sort();
        if (overlapping.isNotEmpty) conflicts[entry.key] = overlapping;
      }
      findings.add(
        conflicts.isEmpty
            ? 'Integrity and account scope match. No current record-id conflicts were found.'
            : '${conflicts.values.fold<int>(0, (sum, value) => sum + value.length)} record-id conflict(s) found; this preview keeps durable data unchanged.',
      );
      findings.add(
        'Dry-run only: no record, preference, reminder, or account state was changed.',
      );
      return result(
        UserPortableDataPreviewStatus.ready,
        proposedMigrations: schemaVersion < userPortableDataPackageSchemaVersion
            ? <String>[
                if (schemaVersion == 2 && reminderPresentation.totalCount > 0)
                  'Schema 2 reminders have no portable presentation fields; preview defaults them to minimal English intent and still requires explicit target-device scheduling consent.',
                'Schema $schemaVersion does not contain personal observations; the preview marks them unavailable and preserves no claim that the source history was empty.',
              ]
            : const <String>[],
      );
    } on FormatException {
      findings.add(
        'The package is not valid JSON or exceeds a structural safety budget.',
      );
      return result(UserPortableDataPreviewStatus.corrupt);
    } on Object {
      // Do not reflect runtime exceptions, source paths, or malformed private
      // values into the user-facing preview. Detailed diagnostics belong in a
      // privacy-bounded engineering channel, not inside the package UI.
      findings.add(
        'The package could not be inspected because its structure is invalid.',
      );
      return result(UserPortableDataPreviewStatus.corrupt);
    }
  }

  /// Runs production package parsing away from the UI isolate on native
  /// Flutter targets. Flutter's [compute] uses its web-compatible scheduling
  /// fallback in browsers, where isolates are not available.
  ///
  /// A custom decoder is a synchronous fault-injection seam and deliberately
  /// stays in-process for deterministic tests.
  Future<UserPortableDataImportPreview> inspectAsync({
    required String packageJson,
    required String currentUserScope,
    required String currentDoseOwnerScope,
    required String currentScopeKind,
    Map<String, Set<String>> existingRecordIds = const <String, Set<String>>{},
  }) async {
    if (decodeJson != jsonDecode) {
      return inspect(
        packageJson: packageJson,
        currentUserScope: currentUserScope,
        currentDoseOwnerScope: currentDoseOwnerScope,
        currentScopeKind: currentScopeKind,
        existingRecordIds: existingRecordIds,
      );
    }
    final raw = await compute(_inspectPortablePackageWorker, <String, Object?>{
      'packageJson': packageJson,
      'currentUserScope': currentUserScope,
      'currentDoseOwnerScope': currentDoseOwnerScope,
      'currentScopeKind': currentScopeKind,
      'maxPackageBytes': maxPackageBytes,
      'existingRecordIds': <String, Object?>{
        for (final entry in existingRecordIds.entries)
          entry.key: entry.value.toList(growable: false),
      },
    });
    return _previewFromTransfer(raw);
  }

  static Map<String, Object?> _profile(UserProfile profile) =>
      <String, Object?>{
        'registrationRegion': profile.registrationRegion,
        'displayLocale': profile.displayLocale,
        'dietProfileRegion': profile.dietProfileRegion,
        'timezone': profile.timezone,
        'identityFieldStatus': <String, Object?>{
          'patientId': 'excluded_from_portable_package',
        },
      };

  static Map<String, Object?> _preferences(UserProfile profile) =>
      <String, Object?>{
        'contentJurisdictionOverride':
            (profile.contentJurisdictionOverride.toSet().toList()..sort()),
        'swallowingTextureMode': profile.swallowingTextureMode,
        'localAi': <String, Object?>{
          'consentEnabled': profile.hasCurrentLocalAiConsent,
          'providerPreference': profile.localAiProviderPreference,
          'generalModel': profile.localAiModel,
          'medicalReviewModel': profile.localAiMedicalModel,
          'timeoutMs': profile.localAiTimeoutMs,
          'endpointStatus': 'excluded_from_portable_package',
        },
      };

  static Map<String, Object?> _medicationSelection(
    String id,
    DrugDefinition? medication, {
    required bool activeAtExport,
  }) => <String, Object?>{
    'id': id,
    'activeAtExport': activeAtExport,
    'catalogStatus': medication == null ? 'unresolved' : 'resolved_at_export',
    'catalogReference': medication == null
        ? null
        : <String, Object?>{
            'genericName': medication.genericName,
            'brandNames': medication.brandNames,
            'aliases': medication.aliases,
            'tags': medication.tags.map((value) => value.name).toList()..sort(),
            'sourceSystem': medication.sourceSystem,
            'sourceProductCode': medication.sourceProductCode,
            'jurisdiction': medication.jurisdiction,
            'route': medication.route,
            'dosageForm': medication.dosageForm,
            'releaseType': medication.releaseType,
            'referenceSnapshotOnly': true,
          },
  };

  static Map<String, Object?> _intake(
    Intake intake,
    DrugDefinition? medication, {
    required String doseOwnerScope,
    required DateTime observedAt,
    required DosageNoteParser parser,
    required AdministrationDoseConfirmationCoordinator coordinator,
  }) {
    final product = intake.productSelection;
    final parseResult = parser.inspect(intake.dosageNote);
    final resultUse = coordinator.evaluateForResultUse(
      intake,
      ownerScope: doseOwnerScope,
      observedAt: observedAt,
    );
    return <String, Object?>{
      'id': intake.id,
      'drugId': intake.drugId,
      'takenAt': intake.takenAt.toUtc().toIso8601String(),
      'dosageNote': intake.dosageNote,
      'dose': <String, Object?>{
        // Keep these keys even when null. A true numeric zero therefore stays
        // distinguishable from an unknown/absent amount.
        'amount': intake.doseAmount,
        'unit': intake.doseUnit,
        'dosageForm': intake.dosageForm,
        'route': intake.route,
        'releaseType': intake.releaseType,
      },
      'productSelection': product == null
          ? null
          : <String, Object?>{
              'packId': product.packId,
              'identifierSystem': product.identifierSystem,
              'identifierValue': product.identifierValue,
              'displayName': product.displayName,
              'labelerName': product.labelerName,
              'strengthDisplay': product.strengthDisplay,
              'packageDescription': product.packageDescription,
              'doseBasisIngredient': product.doseBasisIngredient,
              'unitQuantity': product.unitQuantity,
              'unitLabel': product.unitLabel,
              'meaningBoundary': _userPortableDataProductMeaningBoundary,
            },
      'doseConfirmation': _doseConfirmationEvidence(intake),
      'medicationReconciliation': _medicationReconciliationEvidence(intake),
      'doseTruth': _doseTruth(
        parseResult: parseResult,
        resultUse: resultUse,
        observedAt: observedAt,
      ),
      'medicationCatalogProvenance': medication == null
          ? <String, Object?>{'status': 'unresolved_at_export'}
          : <String, Object?>{
              'status': 'resolved_at_export',
              'sourceSystem': medication.sourceSystem,
              'sourceProductCode': medication.sourceProductCode,
              'jurisdiction': medication.jurisdiction,
            },
    };
  }

  static Map<String, Object?> _doseConfirmationEvidence(Intake intake) {
    final receipt = intake.doseConfirmation;
    final invalidEvidence = intake.invalidDoseConfirmationEvidence;
    return <String, Object?>{
      'evidenceStatus': receipt != null
          ? 'receipt_present_unverified'
          : invalidEvidence != null
          ? 'invalid_evidence_quarantined'
          : 'absent',
      'receipt': receipt?.toJson(),
      'invalidEvidenceDigest': invalidEvidence == null
          ? null
          : AdministrationDoseConfirmationReceipt.digestSnapshot(
              invalidEvidence,
            ),
      'meaningBoundary': _userPortableDataDoseConfirmationBoundary,
    };
  }

  static Map<String, Object?> _medicationReconciliationEvidence(Intake intake) {
    final invalidEvidence = intake.invalidMedicationReconciliationEvidence;
    final serialized = intake.toJson()['medicationReconciliation'];
    final envelope = invalidEvidence == null && serialized is Map
        ? Map<String, Object?>.from(serialized)
        : null;
    return <String, Object?>{
      'evidenceStatus': invalidEvidence != null
          ? 'invalid_evidence_quarantined'
          : envelope != null
          ? 'envelope_present'
          : 'absent',
      'envelope': envelope,
      'invalidEvidenceDigest': invalidEvidence == null
          ? null
          : AdministrationDoseConfirmationReceipt.digestSnapshot(
              invalidEvidence,
            ),
      'meaningBoundary': _userPortableDataReconciliationBoundary,
    };
  }

  static Map<String, Object?> _doseTruth({
    required DoseExpressionParseResult parseResult,
    required AdministrationDoseResultUseEvaluation resultUse,
    required DateTime observedAt,
  }) {
    final expression = parseResult.expression;
    final canonicalValue = resultUse.milligrams ?? resultUse.value;
    final canonicalUnit = resultUse.milligrams != null ? 'mg' : resultUse.unit;
    final canonicalQuantity = resultUse.eligible
        ? <String, Object?>{
            'value': canonicalValue,
            'unit': canonicalUnit,
            'milligrams': resultUse.milligrams,
            'dimension': resultUse.milligrams != null
                ? DoseExpressionDimension.mass.name
                : expression?.unit.dimension.name,
            'unitSystem': expression?.unit.system,
            'unitSystemVersion': expression?.unit.version,
            'unitMappingEvidence': expression?.unit.mappingEvidence.toJson(),
          }
        : null;
    return <String, Object?>{
      'observedAtUtc': observedAt.toUtc().toIso8601String(),
      'rawEvidenceStatus': 'preserved_not_result_eligible_by_itself',
      'parseability': parseResult.toJson(),
      'confirmationVerification': <String, Object?>{
        'status': resultUse.confirmation.status.name,
        'reasonCode': resultUse.confirmation.reasonCode,
      },
      'reconciliationVerification': <String, Object?>{
        'graphDigest': resultUse.assertionGraph.graphDigest,
        'resultAffectingDoseEligible':
            resultUse.assertionGraph.resultAffectingDoseEligible,
        'resultGateReasons': resultUse.assertionGraph.resultGateReasons,
        'staleDecisionCount': resultUse.assertionGraph.staleDecisionCount,
      },
      'resultUse': <String, Object?>{
        'eligible': resultUse.eligible,
        'reasonCodes': resultUse.reasonCodes,
      },
      'canonicalQuantity': canonicalQuantity,
      'meaningBoundary': _userPortableDataDoseTruthBoundary,
    };
  }

  static Map<String, Object?> _meal(
    Meal meal,
    Map<String, FoodItem> foods,
  ) => <String, Object?>{
    'id': meal.id,
    'title': meal.title,
    'time': <String, Object?>{
      'eatenAt': meal.eatenAt.toUtc().toIso8601String(),
      'recordedAt': meal.recordedAt.toUtc().toIso8601String(),
      'occurredAt': meal.occurredAt?.toUtc().toIso8601String(),
      'occurredRangeStart': meal.occurredRangeStart?.toUtc().toIso8601String(),
      'occurredRangeEnd': meal.occurredRangeEnd?.toUtc().toIso8601String(),
      'source': meal.timeSource,
      'precision': meal.timePrecision,
      'nextMealWindowStart': meal.nextMealWindowStart
          ?.toUtc()
          .toIso8601String(),
      'nextMealWindowEnd': meal.nextMealWindowEnd?.toUtc().toIso8601String(),
    },
    'context': <String, Object?>{
      'coeventTime': meal.coeventTime?.toUtc().toIso8601String(),
      'coeventSubstanceTags': meal.coeventSubstanceTags.toSet().toList()
        ..sort(),
      'thickenerType': meal.thickenerType,
      'enteralFeedMode': meal.enteralFeedMode,
      'enteralFeedFormula': meal.enteralFeedFormula,
      'enteralFeedProteinGPerDay': meal.enteralFeedProteinGPerDay,
    },
    'items': <Object?>[
      for (final item in meal.items) _mealItem(item, foods[item.foodId]),
    ],
    'computedTotalsStatus': _userPortableDataComputedTotalsStatus,
  };

  static Map<String, Object?> _mealItem(MealItem item, FoodItem? food) {
    Map<String, Object?> nutrient(
      String field,
      double rawCompatibilityValue,
      String unit,
    ) {
      final explicitlyMissing = food?.isNutrientMissing(field);
      return <String, Object?>{
        'value': explicitlyMissing == true ? null : rawCompatibilityValue,
        'unit': unit,
        'missing': explicitlyMissing,
        'rawCompatibilityValue': rawCompatibilityValue,
        'status': food == null
            ? 'legacy_snapshot_missingness_unavailable'
            : explicitlyMissing == true
            ? 'source_missing_not_zero'
            : 'catalog_snapshot_value',
      };
    }

    return <String, Object?>{
      'foodId': item.foodId,
      'foodName': item.foodName,
      'foodCategory': item.foodCategory.name,
      'quantity': <String, Object?>{
        'factorPer100g': item.quantityFactor,
        'grams': item.grams,
      },
      'foodTags': item.foodTags.toSet().toList()..sort(),
      'nutrientsPer100g': <String, Object?>{
        'protein': nutrient('proteinG', item.proteinPer100g, 'g_per_100g'),
        'carbs': nutrient('carbsG', item.carbsPer100g, 'g_per_100g'),
        'fat': nutrient('fatG', item.fatPer100g, 'g_per_100g'),
        'fiber': nutrient('fiberG', item.fiberPer100g, 'g_per_100g'),
        'sodium': nutrient('sodiumMg', item.sodiumPer100g, 'mg_per_100g'),
      },
      'catalogProvenance': food == null
          ? <String, Object?>{'status': 'unresolved_at_export'}
          : <String, Object?>{
              'status': 'resolved_at_export',
              'sourceSystem': food.sourceSystem,
              'sourceFoodCode': food.sourceFoodCode,
              'jurisdiction': food.jurisdiction,
              'basisType': food.basisType,
              'preparationState': food.preparationState,
              'qualifierKind': food.qualifierKind,
              'missingNutrientFields': (food.missingNutrientFields.toList()
                ..sort()),
              'energyKcal': food.energyKcal,
              'waterG': food.waterG,
              'aminoAcidProfile': food.aminoAcidProfile?.toJson(),
              'referenceSnapshotOnly': true,
            },
    };
  }

  static Map<String, Object?> _reminder(UserLoggingReminder reminder) {
    final presentation = ReminderNotificationPrivacyPolicy.resolve(
      mode: reminder.notificationPrivacyMode,
      localeName: reminder.notificationLocaleCode,
    );
    return <String, Object?>{
      'id': reminder.id,
      'kind': reminder.kind.name,
      'label': reminder.label,
      'minuteOfDay': reminder.minuteOfDay,
      'weekdays': reminder.weekdays.toList()..sort(),
      'enabled': reminder.enabled,
      'notificationPrivacyMode': reminder.notificationPrivacyMode.name,
      'notificationLocaleCode': presentation.languageCode,
      'notificationLocaleDecisionCode': reminderNotificationLanguageCode(
        reminder.notificationLocaleDecisionCode,
      ),
      'sourcePresentationSchema':
          ReminderNotificationPrivacyPolicy.identitySchema,
      'sourcePresentationSha256': presentation.identitySha256,
      'presentationIdentityStatus':
          _userPortableReminderPresentationIdentityStatus,
      'targetSchedulingConsentStatus': _userPortableReminderTargetConsentStatus,
      'activationTokenStatus': 'excluded_from_portable_package',
      'deliveryBoundary': _userPortableDataReminderBoundary,
    };
  }

  static Map<String, Object?> _portableObservation(
    PersonalObservation observation,
  ) {
    final fields = Map<String, Object?>.from(observation.toJson())
      ..remove('recorderId')
      ..['recorderRole'] = _userPortableDataObservationRecorderRole;
    return fields;
  }

  static int _comparePortableObservations(
    PersonalObservation left,
    PersonalObservation right,
  ) {
    final occurred = left.occurredAt.compareTo(right.occurredAt);
    if (occurred != 0) return occurred;
    final recorded = left.recordedAt.compareTo(right.recordedAt);
    return recorded == 0 ? left.id.compareTo(right.id) : recorded;
  }

  static UserPortableReminderPresentationSummary _reminderPresentationSummary(
    Object? raw, {
    required int schemaVersion,
  }) {
    final rows = (raw as List).cast<Map>();
    var enabledIntentCount = 0;
    var currentPolicyMatchCount = 0;
    var currentPolicyDriftCount = 0;
    var localeDecisionMismatchCount = 0;
    final privacyModes = <String>{};
    final languageCodes = <String>{};
    for (final untyped in rows) {
      final row = Map<String, Object?>.from(untyped);
      final enabled = row['enabled'] as bool;
      if (enabled) enabledIntentCount += 1;
      final mode = schemaVersion >= 3
          ? ReminderNotificationPrivacyMode.values.byName(
              row['notificationPrivacyMode'] as String,
            )
          : ReminderNotificationPrivacyMode.minimal;
      final languageCode = schemaVersion >= 3
          ? row['notificationLocaleCode'] as String
          : 'en';
      final decisionCode = schemaVersion >= 3
          ? row['notificationLocaleDecisionCode'] as String
          : 'en';
      privacyModes.add(mode.name);
      languageCodes.add(languageCode);
      if (languageCode != decisionCode) localeDecisionMismatchCount += 1;
      if (schemaVersion >= 3) {
        final currentPresentation = ReminderNotificationPrivacyPolicy.resolve(
          mode: mode,
          localeName: languageCode,
        );
        if (row['sourcePresentationSha256'] ==
            currentPresentation.identitySha256) {
          currentPolicyMatchCount += 1;
        } else {
          currentPolicyDriftCount += 1;
        }
      }
    }
    final sortedModes = privacyModes.toList()..sort();
    final sortedLanguages = languageCodes.toList()..sort();
    return UserPortableReminderPresentationSummary(
      totalCount: rows.length,
      enabledIntentCount: enabledIntentCount,
      targetConsentRequiredCount: enabledIntentCount,
      legacyDefaultCount: schemaVersion == userPortableDataLegacyReadableVersion
          ? rows.length
          : 0,
      currentPolicyMatchCount: currentPolicyMatchCount,
      currentPolicyDriftCount: currentPolicyDriftCount,
      localeDecisionMismatchCount: localeDecisionMismatchCount,
      privacyModes: List<String>.unmodifiable(sortedModes),
      scheduledLanguageCodes: List<String>.unmodifiable(sortedLanguages),
    );
  }

  static Map<String, Object?> _auditLinks({
    required Iterable<Intake> intakes,
    required Iterable<Meal> meals,
    required Iterable<UserLoggingReminder> reminders,
  }) => <String, Object?>{
    'availability': 'relationship_links_only',
    'clinicalAuditRecordsIncluded': false,
    'reason': _userPortableDataAuditReason,
    'links': <Object?>[
      for (final intake in intakes)
        <String, Object?>{
          'recordType': 'intake',
          'recordId': intake.id,
          'relationship': 'references_medication_selection',
          'targetType': 'medication_selection',
          'targetId': intake.drugId,
        },
      for (final meal in meals)
        for (final item in meal.items)
          <String, Object?>{
            'recordType': 'meal',
            'recordId': meal.id,
            'relationship': 'contains_food',
            'targetType': 'food_catalog_reference',
            'targetId': item.foodId,
          },
      for (final reminder in reminders)
        <String, Object?>{
          'recordType': 'reminder',
          'recordId': reminder.id,
          'relationship': 'prompts_log_kind',
          'targetType': 'user_log_kind',
          'targetId': reminder.kind.name,
        },
    ],
  };

  static void _validateKnownFileShapes(
    Map<String, Object?> files,
    List<String> findings,
    List<String> unsupportedFields, {
    required int schemaVersion,
    String? doseOwnerScope,
    DateTime? observedAt,
  }) {
    if (files['profile.json'] is! Map ||
        files['preferences.json'] is! Map ||
        files['audit_links.json'] is! Map) {
      findings.add(
        'Profile, preference, or audit-link data has an invalid shape.',
      );
    }
    const listFiles = <String>[
      'medication_selections.json',
      'intakes.json',
      'meals.json',
      'reminders.json',
    ];
    for (final path in listFiles) {
      final rows = files[path];
      if (rows is! List || rows.any((row) => row is! Map)) {
        findings.add('$path is not a list of JSON objects.');
      }
    }
    final profileRaw = files['profile.json'];
    if (profileRaw is Map) {
      _collectUnsupportedKeys(
        Map<String, Object?>.from(profileRaw),
        const <String>{
          'registrationRegion',
          'displayLocale',
          'dietProfileRegion',
          'timezone',
          'identityFieldStatus',
        },
        r'$.files.profile.json',
        unsupportedFields,
      );
    }

    final preferences = _mapAt(
      files['preferences.json'],
      r'$.files.preferences.json',
      const <String>{
        'contentJurisdictionOverride',
        'swallowingTextureMode',
        'localAi',
      },
      unsupportedFields,
    );
    if (preferences != null) {
      _mapAt(
        preferences['localAi'],
        r'$.files.preferences.json.localAi',
        const <String>{
          'consentEnabled',
          'providerPreference',
          'generalModel',
          'medicalReviewModel',
          'timeoutMs',
          'endpointStatus',
        },
        unsupportedFields,
      );
    }

    _forEachMapRow(
      files['medication_selections.json'],
      r'$.files.medication_selections.json',
      const <String>{
        'id',
        'activeAtExport',
        'catalogStatus',
        'catalogReference',
      },
      unsupportedFields,
      (row, path) {
        _mapAt(
          row['catalogReference'],
          '$path.catalogReference',
          const <String>{
            'genericName',
            'brandNames',
            'aliases',
            'tags',
            'sourceSystem',
            'sourceProductCode',
            'jurisdiction',
            'route',
            'dosageForm',
            'releaseType',
            'referenceSnapshotOnly',
          },
          unsupportedFields,
        );
      },
    );

    _forEachMapRow(
      files['intakes.json'],
      r'$.files.intakes.json',
      const <String>{
        'id',
        'drugId',
        'takenAt',
        'dosageNote',
        'dose',
        'productSelection',
        'doseConfirmation',
        'medicationReconciliation',
        'doseTruth',
        'medicationCatalogProvenance',
      },
      unsupportedFields,
      (row, path) {
        _mapAt(row['dose'], '$path.dose', const <String>{
          'amount',
          'unit',
          'dosageForm',
          'route',
          'releaseType',
        }, unsupportedFields);
        _mapAt(
          row['productSelection'],
          '$path.productSelection',
          const <String>{
            'packId',
            'identifierSystem',
            'identifierValue',
            'displayName',
            'labelerName',
            'strengthDisplay',
            'packageDescription',
            'doseBasisIngredient',
            'unitQuantity',
            'unitLabel',
            'meaningBoundary',
          },
          unsupportedFields,
        );
        final confirmation = _mapAt(
          row['doseConfirmation'],
          '$path.doseConfirmation',
          const <String>{
            'evidenceStatus',
            'receipt',
            'invalidEvidenceDigest',
            'meaningBoundary',
          },
          unsupportedFields,
        );
        if (confirmation != null) {
          _mapAt(
            confirmation['receipt'],
            '$path.doseConfirmation.receipt',
            const <String>{
              'schema_version',
              'receipt_id',
              'receipt_digest',
              'operation_id',
              'owner_scope_digest',
              'intake_id',
              'expected_record_revision_digest',
              'record_binding_digest',
              'medication_id',
              'product_snapshot_digest',
              'raw_expression',
              'parsed_expression',
              'grammar_id',
              'grammar_version',
              'grammar_digest',
              'unit_system',
              'unit_system_version',
              'structured_value',
              'structured_unit',
              'administration_at_utc',
              'confirmed_at_utc',
              'assertion_source',
              'confirmation_action',
              'ui_contract_version',
              'meaning_boundary',
            },
            unsupportedFields,
          );
        }
        _collectMedicationReconciliationUnsupported(
          row['medicationReconciliation'],
          '$path.medicationReconciliation',
          unsupportedFields,
        );
        _collectDoseTruthUnsupported(
          row['doseTruth'],
          '$path.doseTruth',
          unsupportedFields,
        );
        _mapAt(
          row['medicationCatalogProvenance'],
          '$path.medicationCatalogProvenance',
          const <String>{
            'status',
            'sourceSystem',
            'sourceProductCode',
            'jurisdiction',
          },
          unsupportedFields,
        );
      },
    );

    _forEachMapRow(
      files['meals.json'],
      r'$.files.meals.json',
      const <String>{
        'id',
        'title',
        'time',
        'context',
        'items',
        'computedTotalsStatus',
      },
      unsupportedFields,
      (row, path) {
        _mapAt(row['time'], '$path.time', const <String>{
          'eatenAt',
          'recordedAt',
          'occurredAt',
          'occurredRangeStart',
          'occurredRangeEnd',
          'source',
          'precision',
          'nextMealWindowStart',
          'nextMealWindowEnd',
        }, unsupportedFields);
        _mapAt(row['context'], '$path.context', const <String>{
          'coeventTime',
          'coeventSubstanceTags',
          'thickenerType',
          'enteralFeedMode',
          'enteralFeedFormula',
          'enteralFeedProteinGPerDay',
        }, unsupportedFields);
        _forEachMapRow(
          row['items'],
          '$path.items',
          const <String>{
            'foodId',
            'foodName',
            'foodCategory',
            'quantity',
            'foodTags',
            'nutrientsPer100g',
            'catalogProvenance',
          },
          unsupportedFields,
          (item, itemPath) {
            _mapAt(item['quantity'], '$itemPath.quantity', const <String>{
              'factorPer100g',
              'grams',
            }, unsupportedFields);
            final nutrients = _mapAt(
              item['nutrientsPer100g'],
              '$itemPath.nutrientsPer100g',
              const <String>{'protein', 'carbs', 'fat', 'fiber', 'sodium'},
              unsupportedFields,
            );
            if (nutrients != null) {
              for (final name in const <String>[
                'protein',
                'carbs',
                'fat',
                'fiber',
                'sodium',
              ]) {
                _mapAt(
                  nutrients[name],
                  '$itemPath.nutrientsPer100g.$name',
                  const <String>{
                    'value',
                    'unit',
                    'missing',
                    'rawCompatibilityValue',
                    'status',
                  },
                  unsupportedFields,
                );
              }
            }
            final provenance = _mapAt(
              item['catalogProvenance'],
              '$itemPath.catalogProvenance',
              const <String>{
                'status',
                'sourceSystem',
                'sourceFoodCode',
                'jurisdiction',
                'basisType',
                'preparationState',
                'qualifierKind',
                'missingNutrientFields',
                'energyKcal',
                'waterG',
                'aminoAcidProfile',
                'referenceSnapshotOnly',
              },
              unsupportedFields,
            );
            if (provenance != null) {
              _validateAminoAcidProfile(
                provenance['aminoAcidProfile'],
                '$itemPath.catalogProvenance.aminoAcidProfile',
                unsupportedFields,
              );
            }
          },
        );
      },
    );

    _forEachMapRow(
      files['reminders.json'],
      r'$.files.reminders.json',
      <String>{
        'id',
        'kind',
        'label',
        'minuteOfDay',
        'weekdays',
        'enabled',
        if (schemaVersion >= 3) ...<String>{
          'notificationPrivacyMode',
          'notificationLocaleCode',
          'notificationLocaleDecisionCode',
          'sourcePresentationSchema',
          'sourcePresentationSha256',
          'presentationIdentityStatus',
          'targetSchedulingConsentStatus',
        },
        'activationTokenStatus',
        'deliveryBoundary',
      },
      unsupportedFields,
      (_, _) {},
    );

    if (schemaVersion >= 4) {
      final observations = _mapAt(
        files['observations.json'],
        r'$.files.observations.json',
        const <String>{'availability', 'records'},
        unsupportedFields,
      );
      if (observations == null) {
        findings.add('Portable observations container is invalid.');
      } else {
        final availability = observations['availability'];
        if (availability != 'captured_current_local_snapshot' &&
            availability != 'unavailable_in_source_schema') {
          findings.add('Portable observation availability is invalid.');
        }
        final records = observations['records'];
        if (records is! List) {
          findings.add('Portable observations are not a record list.');
        } else {
          if (availability == 'unavailable_in_source_schema' &&
              records.isNotEmpty) {
            findings.add(
              'Observations unavailable in the source schema cannot contain rows.',
            );
          }
          PersonalObservation? previous;
          for (var index = 0; index < records.length; index++) {
            final raw = records[index];
            if (raw is! Map) {
              findings.add('Portable observation row $index is not an object.');
              continue;
            }
            final row = Map<String, Object?>.from(raw);
            const observationFields = <String>{
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
            };
            _collectUnsupportedKeys(
              row,
              observationFields,
              r'$.files.observations.json.records['
              '$index]',
              unsupportedFields,
            );
            if (!_hasRequiredKeys(row, observationFields)) {
              findings.add('Portable observation row $index is incomplete.');
              continue;
            }
            if (row['recorderRole'] !=
                _userPortableDataObservationRecorderRole) {
              findings.add(
                'Portable observation row $index has an invalid recorder role.',
              );
              continue;
            }
            final modelFields = Map<String, Object?>.from(row)
              ..remove('recorderRole')
              ..['recorderId'] = 'portable-package-owner';
            try {
              final observation = PersonalObservation.fromJson(
                Map<String, dynamic>.from(modelFields),
              );
              if (observation.occurredAt.toIso8601String() !=
                      row['occurredAt'] ||
                  observation.recordedAt.toIso8601String() !=
                      row['recordedAt']) {
                findings.add(
                  'Portable observation row $index timestamps must use canonical UTC instants.',
                );
              }
              if (previous != null &&
                  _comparePortableObservations(previous, observation) > 0) {
                findings.add(
                  'Portable observations are not chronologically ordered.',
                );
              }
              previous = observation;
            } on Object {
              findings.add(
                'Portable observation row $index is semantically invalid.',
              );
            }
          }
        }
      }
    }

    final audit = _mapAt(
      files['audit_links.json'],
      r'$.files.audit_links.json',
      const <String>{
        'availability',
        'clinicalAuditRecordsIncluded',
        'reason',
        'links',
      },
      unsupportedFields,
    );
    if (audit != null) {
      _forEachMapRow(
        audit['links'],
        r'$.files.audit_links.json.links',
        const <String>{
          'recordType',
          'recordId',
          'relationship',
          'targetType',
          'targetId',
        },
        unsupportedFields,
        (_, _) {},
      );
    }
    _validateKnownFileScalars(
      files,
      findings,
      schemaVersion: schemaVersion,
      doseOwnerScope: doseOwnerScope,
      observedAt: observedAt,
    );
  }

  static void _collectMedicationReconciliationUnsupported(
    Object? raw,
    String path,
    List<String> unsupportedFields,
  ) {
    final reconciliation = _mapAt(raw, path, const <String>{
      'evidenceStatus',
      'envelope',
      'invalidEvidenceDigest',
      'meaningBoundary',
    }, unsupportedFields);
    if (reconciliation == null) return;
    final envelope = _mapAt(
      reconciliation['envelope'],
      '$path.envelope',
      const <String>{
        'schema',
        'schemaVersion',
        'assertions',
        'decisions',
        'meaningBoundary',
      },
      unsupportedFields,
    );
    if (envelope == null) return;
    _forEachMapRow(
      envelope['assertions'],
      '$path.envelope.assertions',
      const <String>{
        'schema',
        'schema_version',
        'assertion_id',
        'assertion_digest',
        'owner_scope_digest',
        'intake_id',
        'medication_id',
        'product_identity_digest',
        'dose_value',
        'dose_unit',
        'route',
        'dosage_form',
        'release_type',
        'evidence_class',
        'identity_schema_version',
        'source_display_label',
        'source_artifact_id',
        'source_artifact_digest',
        'source_revision_digest',
        'actor_identity_digest',
        'actor_role',
        'derived_from_assertion_ids',
        'supersedes_assertion_ids',
        'retracts_assertion_ids',
        'effective_start_utc',
        'effective_end_utc',
        'time_precision',
        'time_uncertainty_minutes',
        'timezone_offset_minutes',
        'timezone_source',
        'asserted_at_utc',
        'imported_at_utc',
        'recorded_at_utc',
        'status',
        'lifecycle',
        'local_confirmation_receipt_digest',
        'meaning_boundary',
      },
      unsupportedFields,
      (_, _) {},
    );
    _forEachMapRow(
      envelope['decisions'],
      '$path.envelope.decisions',
      const <String>{
        'schema',
        'schema_version',
        'decision_id',
        'decision_digest',
        'owner_scope_digest',
        'intake_id',
        'graph_digest',
        'acknowledged_assertion_ids',
        'acknowledged_blocking_edge_ids',
        'resolution',
        'reason_code',
        'decided_at_utc',
        'meaning_boundary',
      },
      unsupportedFields,
      (_, _) {},
    );
  }

  static void _collectDoseTruthUnsupported(
    Object? raw,
    String path,
    List<String> unsupportedFields,
  ) {
    final truth = _mapAt(raw, path, const <String>{
      'observedAtUtc',
      'rawEvidenceStatus',
      'parseability',
      'confirmationVerification',
      'reconciliationVerification',
      'resultUse',
      'canonicalQuantity',
      'meaningBoundary',
    }, unsupportedFields);
    if (truth == null) return;
    final parseability =
        _mapAt(truth['parseability'], '$path.parseability', const <String>{
          'schema',
          'raw_text',
          'normalized_text',
          'grammar_id',
          'grammar_version',
          'grammar_digest',
          'status',
          'reason_codes',
          'expression',
          'boundary',
        }, unsupportedFields);
    final expression = _mapAt(
      parseability?['expression'],
      '$path.parseability.expression',
      const <String>{'value', 'unit', 'role', 'source_span'},
      unsupportedFields,
    );
    final unit = _mapAt(
      expression?['unit'],
      '$path.parseability.expression.unit',
      const <String>{
        'display',
        'system',
        'code',
        'version',
        'dimension',
        'mappingEvidence',
      },
      unsupportedFields,
    );
    const doseUnitMappingFields = <String>{
      'schema',
      'sourceSystemUri',
      'sourceCode',
      'sourceDisplay',
      'sourceTerminologyVersion',
      'canonicalSystemUri',
      'canonicalCode',
      'canonicalDisplay',
      'canonicalTerminologyVersion',
      'baseUnitSystemUri',
      'baseUnitCode',
      'baseUnitDisplay',
      'baseUnitTerminologyVersion',
      'sourceRevision',
      'mappingType',
      'jurisdiction',
      'reviewDate',
      'licenseState',
      'sourceDimension',
      'targetDimension',
      'conversionNumerator',
      'conversionDenominator',
    };
    _mapAt(
      unit?['mappingEvidence'],
      '$path.parseability.expression.unit.mappingEvidence',
      doseUnitMappingFields,
      unsupportedFields,
    );
    _mapAt(
      expression?['source_span'],
      '$path.parseability.expression.source_span',
      const <String>{'start', 'end'},
      unsupportedFields,
    );
    _mapAt(
      truth['confirmationVerification'],
      '$path.confirmationVerification',
      const <String>{'status', 'reasonCode'},
      unsupportedFields,
    );
    _mapAt(
      truth['reconciliationVerification'],
      '$path.reconciliationVerification',
      const <String>{
        'graphDigest',
        'resultAffectingDoseEligible',
        'resultGateReasons',
        'staleDecisionCount',
      },
      unsupportedFields,
    );
    _mapAt(truth['resultUse'], '$path.resultUse', const <String>{
      'eligible',
      'reasonCodes',
    }, unsupportedFields);
    final canonical = _mapAt(
      truth['canonicalQuantity'],
      '$path.canonicalQuantity',
      const <String>{
        'value',
        'unit',
        'milligrams',
        'dimension',
        'unitSystem',
        'unitSystemVersion',
        'unitMappingEvidence',
      },
      unsupportedFields,
    );
    _mapAt(
      canonical?['unitMappingEvidence'],
      '$path.canonicalQuantity.unitMappingEvidence',
      doseUnitMappingFields,
      unsupportedFields,
    );
  }

  static Map<String, Object?>? _mapAt(
    Object? raw,
    String path,
    Set<String> supported,
    List<String> unsupportedFields,
  ) {
    if (raw == null) return null;
    if (raw is! Map) return null;
    final mapped = Map<String, Object?>.from(raw);
    _collectUnsupportedKeys(mapped, supported, path, unsupportedFields);
    return mapped;
  }

  static void _forEachMapRow(
    Object? raw,
    String path,
    Set<String> supported,
    List<String> unsupportedFields,
    void Function(Map<String, Object?> row, String path) nested,
  ) {
    if (raw is! List) return;
    for (var index = 0; index < raw.length; index++) {
      final value = raw[index];
      if (value is! Map) continue;
      final row = Map<String, Object?>.from(value);
      final rowPath = '$path[$index]';
      _collectUnsupportedKeys(row, supported, rowPath, unsupportedFields);
      nested(row, rowPath);
    }
  }

  static void _validateAminoAcidProfile(
    Object? raw,
    String path,
    List<String> unsupportedFields,
  ) {
    final profile = _mapAt(raw, path, const <String>{
      'leucine',
      'isoleucine',
      'valine',
      'phenylalanine',
      'tyrosine',
      'tryptophan',
      'histidine',
      'methionine',
      'threonine',
      'lysine',
      'cystine',
      'arginine',
      'unit',
      'basis',
      'nutrient_ids',
      'source_refs',
      'partial',
      'competing_lnaa_grams',
      'fdc_data_type',
      'aggregate_confidence_tier',
      'derivations',
    }, unsupportedFields);
    final derivations = profile?['derivations'];
    if (derivations is! Map) return;
    for (final entry in derivations.entries) {
      _mapAt(entry.value, '$path.derivations.${entry.key}', const <String>{
        'derivation_code',
        'derivation_description',
        'source_code',
        'data_points',
        'min',
        'max',
        'median',
        'tier',
      }, unsupportedFields);
    }
  }

  static void _validateKnownFileScalars(
    Map<String, Object?> files,
    List<String> findings, {
    required int schemaVersion,
    String? doseOwnerScope,
    DateTime? observedAt,
  }) {
    final profile = _schemaMap(
      files['profile.json'],
      r'$.files.profile.json',
      const <String>{
        'registrationRegion',
        'displayLocale',
        'dietProfileRegion',
        'timezone',
        'identityFieldStatus',
      },
      findings,
    );
    if (profile != null) {
      _checkString(
        profile['registrationRegion'],
        r'$.files.profile.json.registrationRegion',
        findings,
        allowed: kSupportedRegistrationRegions.toSet(),
      );
      _checkString(
        profile['displayLocale'],
        r'$.files.profile.json.displayLocale',
        findings,
        allowed: kSupportedDisplayLocales.toSet(),
      );
      _checkString(
        profile['dietProfileRegion'],
        r'$.files.profile.json.dietProfileRegion',
        findings,
        nullable: true,
        allowed: kSupportedRegistrationRegions.toSet(),
      );
      _checkString(
        profile['timezone'],
        r'$.files.profile.json.timezone',
        findings,
      );
      final identity = _schemaMap(
        profile['identityFieldStatus'],
        r'$.files.profile.json.identityFieldStatus',
        const <String>{'patientId'},
        findings,
      );
      if (identity != null &&
          identity['patientId'] != 'excluded_from_portable_package') {
        _invalid(
          findings,
          r'$.files.profile.json.identityFieldStatus.patientId',
        );
      }
    }

    final preferences = _schemaMap(
      files['preferences.json'],
      r'$.files.preferences.json',
      const <String>{
        'contentJurisdictionOverride',
        'swallowingTextureMode',
        'localAi',
      },
      findings,
    );
    if (preferences != null) {
      _checkStringList(
        preferences['contentJurisdictionOverride'],
        r'$.files.preferences.json.contentJurisdictionOverride',
        findings,
        allowed: kSupportedRegistrationRegions.toSet(),
        unique: true,
        sorted: true,
      );
      _checkString(
        preferences['swallowingTextureMode'],
        r'$.files.preferences.json.swallowingTextureMode',
        findings,
        allowed: kSupportedTextureModes.toSet(),
      );
      final localAi = _schemaMap(
        preferences['localAi'],
        r'$.files.preferences.json.localAi',
        const <String>{
          'consentEnabled',
          'providerPreference',
          'generalModel',
          'medicalReviewModel',
          'timeoutMs',
          'endpointStatus',
        },
        findings,
      );
      if (localAi != null) {
        _checkBool(
          localAi['consentEnabled'],
          r'$.files.preferences.json.localAi.consentEnabled',
          findings,
        );
        _checkString(
          localAi['providerPreference'],
          r'$.files.preferences.json.localAi.providerPreference',
          findings,
          allowed: const <String>{'auto', 'ollama', 'openai_compat'},
        );
        _checkString(
          localAi['generalModel'],
          r'$.files.preferences.json.localAi.generalModel',
          findings,
          allowEmpty: true,
        );
        _checkString(
          localAi['medicalReviewModel'],
          r'$.files.preferences.json.localAi.medicalReviewModel',
          findings,
          allowEmpty: true,
        );
        _checkInt(
          localAi['timeoutMs'],
          r'$.files.preferences.json.localAi.timeoutMs',
          findings,
          min: 1000,
          max: 120000,
        );
        if (localAi['endpointStatus'] != 'excluded_from_portable_package') {
          _invalid(
            findings,
            r'$.files.preferences.json.localAi.endpointStatus',
          );
        }
      }
    }

    final medicationRows = _schemaRows(
      files['medication_selections.json'],
      r'$.files.medication_selections.json',
      findings,
    );
    for (var index = 0; index < medicationRows.length; index++) {
      final path =
          r'$.files.medication_selections.json['
          '$index]';
      final row = medicationRows[index];
      _requireKeys(
        row,
        const <String>{
          'id',
          'activeAtExport',
          'catalogStatus',
          'catalogReference',
        },
        path,
        findings,
      );
      _checkBool(row['activeAtExport'], '$path.activeAtExport', findings);
      final status = row['catalogStatus'];
      _checkString(
        status,
        '$path.catalogStatus',
        findings,
        allowed: const <String>{'unresolved', 'resolved_at_export'},
      );
      if (status == 'unresolved') {
        if (row['catalogReference'] != null) {
          _invalid(findings, '$path.catalogReference');
        }
      } else if (status == 'resolved_at_export') {
        final reference = _schemaMap(
          row['catalogReference'],
          '$path.catalogReference',
          const <String>{
            'genericName',
            'brandNames',
            'aliases',
            'tags',
            'sourceSystem',
            'sourceProductCode',
            'jurisdiction',
            'route',
            'dosageForm',
            'releaseType',
            'referenceSnapshotOnly',
          },
          findings,
        );
        if (reference != null) {
          _checkString(
            reference['genericName'],
            '$path.catalogReference.genericName',
            findings,
          );
          _checkStringList(
            reference['brandNames'],
            '$path.catalogReference.brandNames',
            findings,
          );
          _checkStringList(
            reference['aliases'],
            '$path.catalogReference.aliases',
            findings,
          );
          _checkStringList(
            reference['tags'],
            '$path.catalogReference.tags',
            findings,
            allowed: DrugTag.values.map((value) => value.name).toSet(),
            unique: true,
            sorted: true,
          );
          _checkString(
            reference['sourceSystem'],
            '$path.catalogReference.sourceSystem',
            findings,
          );
          _checkString(
            reference['sourceProductCode'],
            '$path.catalogReference.sourceProductCode',
            findings,
            nullable: true,
          );
          _checkString(
            reference['jurisdiction'],
            '$path.catalogReference.jurisdiction',
            findings,
          );
          _checkString(
            reference['route'],
            '$path.catalogReference.route',
            findings,
          );
          _checkString(
            reference['dosageForm'],
            '$path.catalogReference.dosageForm',
            findings,
          );
          _checkString(
            reference['releaseType'],
            '$path.catalogReference.releaseType',
            findings,
          );
          if (reference['referenceSnapshotOnly'] != true) {
            _invalid(findings, '$path.catalogReference.referenceSnapshotOnly');
          }
        }
      }
    }

    final intakeRows = _schemaRows(
      files['intakes.json'],
      r'$.files.intakes.json',
      findings,
    );
    for (var index = 0; index < intakeRows.length; index++) {
      final path =
          r'$.files.intakes.json['
          '$index]';
      final row = intakeRows[index];
      _requireKeys(
        row,
        const <String>{
          'id',
          'drugId',
          'takenAt',
          'dosageNote',
          'dose',
          'productSelection',
          'doseConfirmation',
          'medicationReconciliation',
          'doseTruth',
          'medicationCatalogProvenance',
        },
        path,
        findings,
      );
      _checkTimestamp(row['takenAt'], '$path.takenAt', findings);
      _checkString(
        row['dosageNote'],
        '$path.dosageNote',
        findings,
        allowEmpty: true,
      );
      final dose = _schemaMap(row['dose'], '$path.dose', const <String>{
        'amount',
        'unit',
        'dosageForm',
        'route',
        'releaseType',
      }, findings);
      if (dose != null) {
        _checkNumber(
          dose['amount'],
          '$path.dose.amount',
          findings,
          nullable: true,
          min: 0,
        );
        for (final key in const <String>[
          'unit',
          'dosageForm',
          'route',
          'releaseType',
        ]) {
          _checkString(dose[key], '$path.dose.$key', findings, nullable: true);
        }
      }
      final productRaw = row['productSelection'];
      if (productRaw != null) {
        final product =
            _schemaMap(productRaw, '$path.productSelection', const <String>{
              'packId',
              'identifierSystem',
              'identifierValue',
              'displayName',
              'labelerName',
              'strengthDisplay',
              'packageDescription',
              'doseBasisIngredient',
              'unitQuantity',
              'unitLabel',
              'meaningBoundary',
            }, findings);
        if (product != null) {
          for (final key in const <String>[
            'packId',
            'identifierValue',
            'displayName',
          ]) {
            _checkString(product[key], '$path.productSelection.$key', findings);
          }
          _checkString(
            product['identifierSystem'],
            '$path.productSelection.identifierSystem',
            findings,
            allowed: MedicationIdentifierSystem.values
                .map((value) => value.name)
                .toSet(),
          );
          for (final key in const <String>[
            'labelerName',
            'doseBasisIngredient',
            'unitLabel',
          ]) {
            _checkString(
              product[key],
              '$path.productSelection.$key',
              findings,
              nullable: true,
            );
          }
          for (final key in const <String>[
            'strengthDisplay',
            'packageDescription',
          ]) {
            _checkString(
              product[key],
              '$path.productSelection.$key',
              findings,
              allowEmpty: true,
            );
          }
          _checkNumber(
            product['unitQuantity'],
            '$path.productSelection.unitQuantity',
            findings,
            nullable: true,
            minExclusive: 0,
          );
          if (product['meaningBoundary'] !=
              _userPortableDataProductMeaningBoundary) {
            _invalid(findings, '$path.productSelection.meaningBoundary');
          }
          final hasQuantity = product['unitQuantity'] != null;
          if (hasQuantity != (product['doseBasisIngredient'] != null) ||
              hasQuantity != (product['unitLabel'] != null)) {
            _invalid(findings, '$path.productSelection.confirmedQuantity');
          }
        }
      }
      final confirmation = _schemaMap(
        row['doseConfirmation'],
        '$path.doseConfirmation',
        const <String>{
          'evidenceStatus',
          'receipt',
          'invalidEvidenceDigest',
          'meaningBoundary',
        },
        findings,
      );
      if (confirmation != null) {
        final status = confirmation['evidenceStatus'];
        _checkString(
          status,
          '$path.doseConfirmation.evidenceStatus',
          findings,
          allowed: const <String>{
            'absent',
            'receipt_present_unverified',
            'invalid_evidence_quarantined',
          },
        );
        if (confirmation['meaningBoundary'] !=
            _userPortableDataDoseConfirmationBoundary) {
          _invalid(findings, '$path.doseConfirmation.meaningBoundary');
        }
        final receiptRaw = confirmation['receipt'];
        final invalidDigest = confirmation['invalidEvidenceDigest'];
        if (status == 'receipt_present_unverified') {
          if (receiptRaw is! Map || invalidDigest != null) {
            _invalid(findings, '$path.doseConfirmation.receipt');
          } else {
            try {
              AdministrationDoseConfirmationReceipt.fromJson(
                Map<String, dynamic>.from(receiptRaw),
              );
            } on Object {
              _invalid(findings, '$path.doseConfirmation.receipt');
            }
          }
        } else if (status == 'invalid_evidence_quarantined') {
          if (receiptRaw != null ||
              invalidDigest is! String ||
              !RegExp(r'^[a-f0-9]{64}$').hasMatch(invalidDigest)) {
            _invalid(findings, '$path.doseConfirmation.invalidEvidenceDigest');
          }
        } else if (receiptRaw != null || invalidDigest != null) {
          _invalid(findings, '$path.doseConfirmation.evidenceStatus');
        }
      }
      _validateMedicationReconciliationEvidence(
        row['medicationReconciliation'],
        '$path.medicationReconciliation',
        findings,
      );
      _validateDoseTruthScalars(row['doseTruth'], '$path.doseTruth', findings);
      if (doseOwnerScope != null && observedAt != null) {
        _validatePortableDoseTruthBinding(
          row,
          path,
          doseOwnerScope: doseOwnerScope,
          observedAt: observedAt,
          findings: findings,
        );
      }
      _validateCatalogProvenance(
        row['medicationCatalogProvenance'],
        '$path.medicationCatalogProvenance',
        findings,
        sourceCodeKey: 'sourceProductCode',
      );
    }

    final mealRows = _schemaRows(
      files['meals.json'],
      r'$.files.meals.json',
      findings,
    );
    for (var index = 0; index < mealRows.length; index++) {
      final path =
          r'$.files.meals.json['
          '$index]';
      final row = mealRows[index];
      _requireKeys(
        row,
        const <String>{
          'id',
          'title',
          'time',
          'context',
          'items',
          'computedTotalsStatus',
        },
        path,
        findings,
      );
      _checkString(row['title'], '$path.title', findings, allowEmpty: true);
      if (row['computedTotalsStatus'] !=
          _userPortableDataComputedTotalsStatus) {
        _invalid(findings, '$path.computedTotalsStatus');
      }
      final time = _schemaMap(row['time'], '$path.time', const <String>{
        'eatenAt',
        'recordedAt',
        'occurredAt',
        'occurredRangeStart',
        'occurredRangeEnd',
        'source',
        'precision',
        'nextMealWindowStart',
        'nextMealWindowEnd',
      }, findings);
      if (time != null) {
        _checkTimestamp(time['eatenAt'], '$path.time.eatenAt', findings);
        _checkTimestamp(time['recordedAt'], '$path.time.recordedAt', findings);
        for (final key in const <String>[
          'occurredAt',
          'occurredRangeStart',
          'occurredRangeEnd',
          'nextMealWindowStart',
          'nextMealWindowEnd',
        ]) {
          _checkTimestamp(
            time[key],
            '$path.time.$key',
            findings,
            nullable: true,
          );
        }
        _checkString(
          time['source'],
          '$path.time.source',
          findings,
          allowed: const <String>{
            'implicit_now',
            'migration_legacy',
            'user_exact',
            'user_interval',
            'user_entered',
          },
        );
        _checkString(
          time['precision'],
          '$path.time.precision',
          findings,
          allowed: const <String>{'exact', 'interval'},
        );
        _checkOrderedTimestamps(
          time['occurredRangeStart'],
          time['occurredRangeEnd'],
          '$path.time.occurredRange',
          findings,
          requirePair: time['precision'] == 'interval',
        );
        _checkOrderedTimestamps(
          time['nextMealWindowStart'],
          time['nextMealWindowEnd'],
          '$path.time.nextMealWindow',
          findings,
          requirePair: false,
        );
      }
      final context =
          _schemaMap(row['context'], '$path.context', const <String>{
            'coeventTime',
            'coeventSubstanceTags',
            'thickenerType',
            'enteralFeedMode',
            'enteralFeedFormula',
            'enteralFeedProteinGPerDay',
          }, findings);
      if (context != null) {
        _checkTimestamp(
          context['coeventTime'],
          '$path.context.coeventTime',
          findings,
          nullable: true,
        );
        _checkStringList(
          context['coeventSubstanceTags'],
          '$path.context.coeventSubstanceTags',
          findings,
          allowed: const <String>{'iron_salt', 'multivitamin_with_iron'},
          unique: true,
          sorted: true,
        );
        _checkString(
          context['thickenerType'],
          '$path.context.thickenerType',
          findings,
          nullable: true,
          allowed: const <String>{'starch_based', 'xanthan_based'},
        );
        _checkString(
          context['enteralFeedMode'],
          '$path.context.enteralFeedMode',
          findings,
          nullable: true,
          allowed: const <String>{'continuous', 'bolus'},
        );
        _checkString(
          context['enteralFeedFormula'],
          '$path.context.enteralFeedFormula',
          findings,
          nullable: true,
        );
        _checkNumber(
          context['enteralFeedProteinGPerDay'],
          '$path.context.enteralFeedProteinGPerDay',
          findings,
          nullable: true,
          min: 0,
        );
        if (context['enteralFeedMode'] == null &&
            (context['enteralFeedFormula'] != null ||
                context['enteralFeedProteinGPerDay'] != null)) {
          _invalid(findings, '$path.context.enteralFeedContext');
        }
      }
      final items = _schemaRows(row['items'], '$path.items', findings);
      for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
        _validateMealItem(
          items[itemIndex],
          '$path.items[$itemIndex]',
          findings,
        );
      }
    }

    final reminderRows = _schemaRows(
      files['reminders.json'],
      r'$.files.reminders.json',
      findings,
    );
    for (var index = 0; index < reminderRows.length; index++) {
      final path =
          r'$.files.reminders.json['
          '$index]';
      final row = reminderRows[index];
      _requireKeys(
        row,
        <String>{
          'id',
          'kind',
          'label',
          'minuteOfDay',
          'weekdays',
          'enabled',
          if (schemaVersion >= 3) ...<String>{
            'notificationPrivacyMode',
            'notificationLocaleCode',
            'notificationLocaleDecisionCode',
            'sourcePresentationSchema',
            'sourcePresentationSha256',
            'presentationIdentityStatus',
            'targetSchedulingConsentStatus',
          },
          'activationTokenStatus',
          'deliveryBoundary',
        },
        path,
        findings,
      );
      _checkString(
        row['kind'],
        '$path.kind',
        findings,
        allowed: UserLoggingReminderKind.values
            .map((value) => value.name)
            .toSet(),
      );
      final label = row['label'];
      _checkString(label, '$path.label', findings);
      if (label is String &&
          (label != label.trim() || label.runes.length > 80)) {
        _invalid(findings, '$path.label');
      }
      _checkInt(
        row['minuteOfDay'],
        '$path.minuteOfDay',
        findings,
        min: 0,
        max: 1439,
      );
      _checkIntList(
        row['weekdays'],
        '$path.weekdays',
        findings,
        min: 1,
        max: 7,
        nonEmpty: true,
        unique: true,
        sorted: true,
      );
      _checkBool(row['enabled'], '$path.enabled', findings);
      if (schemaVersion >= 3) {
        _checkString(
          row['notificationPrivacyMode'],
          '$path.notificationPrivacyMode',
          findings,
          allowed: ReminderNotificationPrivacyMode.values
              .map((value) => value.name)
              .toSet(),
        );
        final locale = row['notificationLocaleCode'];
        final decisionLocale = row['notificationLocaleDecisionCode'];
        _checkString(locale, '$path.notificationLocaleCode', findings);
        _checkString(
          decisionLocale,
          '$path.notificationLocaleDecisionCode',
          findings,
        );
        if (locale is String &&
            (!isReminderNotificationLocaleCodeValid(locale) ||
                reminderNotificationLanguageCode(locale) != locale ||
                ReminderNotificationPrivacyPolicy.supportedLanguageCode(
                      locale,
                    ) !=
                    locale)) {
          _invalid(findings, '$path.notificationLocaleCode');
        }
        if (decisionLocale is String &&
            (!isReminderNotificationLocaleCodeValid(decisionLocale) ||
                reminderNotificationLanguageCode(decisionLocale) !=
                    decisionLocale ||
                ReminderNotificationPrivacyPolicy.supportedLanguageCode(
                      decisionLocale,
                    ) !=
                    decisionLocale)) {
          _invalid(findings, '$path.notificationLocaleDecisionCode');
        }
        if (row['sourcePresentationSchema'] !=
            ReminderNotificationPrivacyPolicy.identitySchema) {
          _invalid(findings, '$path.sourcePresentationSchema');
        }
        if (!_isSha256(row['sourcePresentationSha256'])) {
          _invalid(findings, '$path.sourcePresentationSha256');
        }
        if (row['presentationIdentityStatus'] !=
            _userPortableReminderPresentationIdentityStatus) {
          _invalid(findings, '$path.presentationIdentityStatus');
        }
        if (row['targetSchedulingConsentStatus'] !=
            _userPortableReminderTargetConsentStatus) {
          _invalid(findings, '$path.targetSchedulingConsentStatus');
        }
      }
      if (row['activationTokenStatus'] != 'excluded_from_portable_package') {
        _invalid(findings, '$path.activationTokenStatus');
      }
      if (row['deliveryBoundary'] != _userPortableDataReminderBoundary) {
        _invalid(findings, '$path.deliveryBoundary');
      }
    }

    _validateAuditLinks(
      files: files,
      medicationRows: medicationRows,
      intakeRows: intakeRows,
      mealRows: mealRows,
      reminderRows: reminderRows,
      findings: findings,
    );
  }

  static void _validateMedicationReconciliationEvidence(
    Object? raw,
    String path,
    List<String> findings,
  ) {
    final reconciliation = _schemaMap(raw, path, const <String>{
      'evidenceStatus',
      'envelope',
      'invalidEvidenceDigest',
      'meaningBoundary',
    }, findings);
    if (reconciliation == null) return;
    final status = reconciliation['evidenceStatus'];
    _checkString(
      status,
      '$path.evidenceStatus',
      findings,
      allowed: const <String>{
        'absent',
        'envelope_present',
        'invalid_evidence_quarantined',
      },
    );
    if (reconciliation['meaningBoundary'] !=
        _userPortableDataReconciliationBoundary) {
      _invalid(findings, '$path.meaningBoundary');
    }
    final envelopeRaw = reconciliation['envelope'];
    final invalidDigest = reconciliation['invalidEvidenceDigest'];
    if (status == 'envelope_present') {
      if (envelopeRaw is! Map || invalidDigest != null) {
        _invalid(findings, '$path.envelope');
        return;
      }
      final envelope = _schemaMap(envelopeRaw, '$path.envelope', const <String>{
        'schema',
        'schemaVersion',
        'assertions',
        'decisions',
        'meaningBoundary',
      }, findings);
      if (envelope == null) return;
      if (envelope['schema'] !=
              'parkinsum.medication-reconciliation-envelope/1' ||
          envelope['schemaVersion'] != 1 ||
          envelope['meaningBoundary'] !=
              _userPortableDataReconciliationEnvelopeBoundary ||
          envelope['assertions'] is! List ||
          envelope['decisions'] is! List) {
        _invalid(findings, '$path.envelope');
        return;
      }
      final assertions = envelope['assertions'] as List;
      final decisions = envelope['decisions'] as List;
      if (assertions.length > 64 || decisions.length > 128) {
        _invalid(findings, '$path.envelope');
        return;
      }
      try {
        for (var index = 0; index < assertions.length; index++) {
          final item = assertions[index];
          if (item is! Map) throw const FormatException();
          final assertion = MedicationAssertionNode.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (item['schema_version'] == medicationAssertionSchemaVersion &&
              _canonicalJson(assertion.toJson()) != _canonicalJson(item)) {
            throw const FormatException();
          }
        }
        for (var index = 0; index < decisions.length; index++) {
          final item = decisions[index];
          if (item is! Map) throw const FormatException();
          final decision = MedicationReconciliationDecision.fromJson(
            Map<String, dynamic>.from(item),
          );
          if (_canonicalJson(decision.toJson()) != _canonicalJson(item)) {
            throw const FormatException();
          }
        }
      } on Object {
        _invalid(findings, '$path.envelope');
      }
    } else if (status == 'invalid_evidence_quarantined') {
      if (envelopeRaw != null || !_isSha256(invalidDigest)) {
        _invalid(findings, '$path.invalidEvidenceDigest');
      }
    } else if (envelopeRaw != null || invalidDigest != null) {
      _invalid(findings, '$path.evidenceStatus');
    }
  }

  static void _validateDoseTruthScalars(
    Object? raw,
    String path,
    List<String> findings,
  ) {
    final truth = _schemaMap(raw, path, const <String>{
      'observedAtUtc',
      'rawEvidenceStatus',
      'parseability',
      'confirmationVerification',
      'reconciliationVerification',
      'resultUse',
      'canonicalQuantity',
      'meaningBoundary',
    }, findings);
    if (truth == null) return;
    _checkTimestamp(truth['observedAtUtc'], '$path.observedAtUtc', findings);
    if (truth['rawEvidenceStatus'] !=
        'preserved_not_result_eligible_by_itself') {
      _invalid(findings, '$path.rawEvidenceStatus');
    }
    if (truth['meaningBoundary'] != _userPortableDataDoseTruthBoundary) {
      _invalid(findings, '$path.meaningBoundary');
    }
    final parseability =
        _schemaMap(truth['parseability'], '$path.parseability', const <String>{
          'schema',
          'raw_text',
          'normalized_text',
          'grammar_id',
          'grammar_version',
          'grammar_digest',
          'status',
          'reason_codes',
          'expression',
          'boundary',
        }, findings);
    Object? expressionRaw;
    VersionedDoseUnitMapping? doseUnitMappingEvidence;
    if (parseability != null) {
      _checkString(
        parseability['raw_text'],
        '$path.parseability.raw_text',
        findings,
        allowEmpty: true,
      );
      _checkString(
        parseability['normalized_text'],
        '$path.parseability.normalized_text',
        findings,
        allowEmpty: true,
      );
      if (parseability['schema'] !=
              'parkinsum.dose-expression-parse-result/2' ||
          parseability['grammar_id'] != DosageNoteParser.grammarId ||
          parseability['grammar_version'] != DosageNoteParser.grammarVersion ||
          parseability['grammar_digest'] != DosageNoteParser.grammarDigest) {
        _invalid(findings, '$path.parseability.grammar');
      }
      final parseStatus = parseability['status'];
      _checkString(
        parseStatus,
        '$path.parseability.status',
        findings,
        allowed: DoseExpressionParseStatus.values
            .map((value) => value.name)
            .toSet(),
      );
      final parseReasons = _checkStringList(
        parseability['reason_codes'],
        '$path.parseability.reason_codes',
        findings,
        unique: true,
        sorted: true,
      );
      expressionRaw = parseability['expression'];
      if (parseStatus == DoseExpressionParseStatus.accepted.name) {
        if (parseReasons?.isNotEmpty ?? true) {
          _invalid(findings, '$path.parseability.reason_codes');
        }
        final expression = _schemaMap(
          expressionRaw,
          '$path.parseability.expression',
          const <String>{'value', 'unit', 'role', 'source_span'},
          findings,
        );
        if (expression != null) {
          _checkNumber(
            expression['value'],
            '$path.parseability.expression.value',
            findings,
            minExclusive: 0,
          );
          if (expression['role'] !=
              DoseExpressionRole.administrationDose.name) {
            _invalid(findings, '$path.parseability.expression.role');
          }
          final unit = _schemaMap(
            expression['unit'],
            '$path.parseability.expression.unit',
            const <String>{
              'display',
              'system',
              'code',
              'version',
              'dimension',
              'mappingEvidence',
            },
            findings,
          );
          if (unit != null) {
            _checkString(
              unit['display'],
              '$path.parseability.expression.unit.display',
              findings,
            );
            if (unit['system'] != DosageNoteParser.localUnitSystem ||
                unit['version'] != DosageNoteParser.localUnitVersion) {
              _invalid(findings, '$path.parseability.expression.unit.system');
            }
            _checkString(
              unit['code'],
              '$path.parseability.expression.unit.code',
              findings,
              allowed: const <String>{'mg', 'g', 'mcg', 'mL'},
            );
            _checkString(
              unit['dimension'],
              '$path.parseability.expression.unit.dimension',
              findings,
              allowed: DoseExpressionDimension.values
                  .map((value) => value.name)
                  .toSet(),
            );
            doseUnitMappingEvidence = VersionedDoseUnitMapping.tryFromJson(
              unit['mappingEvidence'],
            );
            final mappingErrors = doseUnitMappingEvidence?.validationErrors(
              expectedSourceRevision: DosageNoteParser.grammarDigest,
              evaluatedAt: DateTime.now().toUtc(),
            );
            if (doseUnitMappingEvidence == null ||
                mappingErrors == null ||
                mappingErrors.isNotEmpty ||
                doseUnitMappingEvidence.canonicalCode != unit['code'] ||
                doseUnitMappingEvidence.sourceDisplay != unit['display'] ||
                doseUnitMappingEvidence.sourceDimension.name !=
                    unit['dimension']) {
              _invalid(
                findings,
                '$path.parseability.expression.unit.mappingEvidence',
              );
            }
          }
          final span = _schemaMap(
            expression['source_span'],
            '$path.parseability.expression.source_span',
            const <String>{'start', 'end'},
            findings,
          );
          if (span != null) {
            _checkInt(
              span['start'],
              '$path.parseability.expression.source_span.start',
              findings,
              min: 0,
            );
            _checkInt(
              span['end'],
              '$path.parseability.expression.source_span.end',
              findings,
              min: 1,
            );
            if (span['start'] is int &&
                span['end'] is int &&
                (span['end'] as int) <= (span['start'] as int)) {
              _invalid(findings, '$path.parseability.expression.source_span');
            }
          }
        }
      } else {
        if (expressionRaw != null || (parseReasons?.isEmpty ?? true)) {
          _invalid(findings, '$path.parseability.expression');
        }
      }
    }
    final confirmation = _schemaMap(
      truth['confirmationVerification'],
      '$path.confirmationVerification',
      const <String>{'status', 'reasonCode'},
      findings,
    );
    if (confirmation != null) {
      _checkString(
        confirmation['status'],
        '$path.confirmationVerification.status',
        findings,
        allowed: AdministrationDoseEvaluationStatus.values
            .map((value) => value.name)
            .toSet(),
      );
      _checkString(
        confirmation['reasonCode'],
        '$path.confirmationVerification.reasonCode',
        findings,
      );
    }
    final reconciliation = _schemaMap(
      truth['reconciliationVerification'],
      '$path.reconciliationVerification',
      const <String>{
        'graphDigest',
        'resultAffectingDoseEligible',
        'resultGateReasons',
        'staleDecisionCount',
      },
      findings,
    );
    if (reconciliation != null) {
      if (!_isSha256(reconciliation['graphDigest'])) {
        _invalid(findings, '$path.reconciliationVerification.graphDigest');
      }
      _checkBool(
        reconciliation['resultAffectingDoseEligible'],
        '$path.reconciliationVerification.resultAffectingDoseEligible',
        findings,
      );
      _checkStringList(
        reconciliation['resultGateReasons'],
        '$path.reconciliationVerification.resultGateReasons',
        findings,
        unique: true,
        sorted: true,
      );
      _checkInt(
        reconciliation['staleDecisionCount'],
        '$path.reconciliationVerification.staleDecisionCount',
        findings,
        min: 0,
      );
    }
    final resultUse = _schemaMap(
      truth['resultUse'],
      '$path.resultUse',
      const <String>{'eligible', 'reasonCodes'},
      findings,
    );
    bool? eligible;
    if (resultUse != null) {
      _checkBool(resultUse['eligible'], '$path.resultUse.eligible', findings);
      eligible = resultUse['eligible'] as bool?;
      final reasons = _checkStringList(
        resultUse['reasonCodes'],
        '$path.resultUse.reasonCodes',
        findings,
        unique: true,
        sorted: true,
      );
      if (eligible == true && (reasons?.isNotEmpty ?? true) ||
          eligible == false && (reasons?.isEmpty ?? true)) {
        _invalid(findings, '$path.resultUse.reasonCodes');
      }
    }
    final canonicalRaw = truth['canonicalQuantity'];
    if (eligible == true) {
      final canonical =
          _schemaMap(canonicalRaw, '$path.canonicalQuantity', const <String>{
            'value',
            'unit',
            'milligrams',
            'dimension',
            'unitSystem',
            'unitSystemVersion',
            'unitMappingEvidence',
          }, findings);
      if (canonical != null) {
        _checkNumber(
          canonical['value'],
          '$path.canonicalQuantity.value',
          findings,
          minExclusive: 0,
        );
        _checkString(
          canonical['unit'],
          '$path.canonicalQuantity.unit',
          findings,
          // Schema v2 has one canonical mass unit. The original typed unit is
          // retained in parseability and receipt evidence, while result-facing
          // mass is always normalized to milligrams. Volume remains mL and is
          // never silently converted to mass without concentration evidence.
          allowed: const <String>{'mg', 'mL'},
        );
        _checkNumber(
          canonical['milligrams'],
          '$path.canonicalQuantity.milligrams',
          findings,
          nullable: true,
          minExclusive: 0,
        );
        _checkString(
          canonical['dimension'],
          '$path.canonicalQuantity.dimension',
          findings,
          allowed: DoseExpressionDimension.values
              .map((value) => value.name)
              .toSet(),
        );
        if (canonical['unitSystem'] != DosageNoteParser.localUnitSystem ||
            canonical['unitSystemVersion'] !=
                DosageNoteParser.localUnitVersion) {
          _invalid(findings, '$path.canonicalQuantity.unitSystem');
        }
        final canonicalMappingRaw = canonical['unitMappingEvidence'];
        final canonicalMapping = VersionedDoseUnitMapping.tryFromJson(
          canonicalMappingRaw,
        );
        final canonicalMappingErrors = canonicalMapping?.validationErrors(
          expectedSourceRevision: DosageNoteParser.grammarDigest,
          evaluatedAt: DateTime.now().toUtc(),
        );
        if (canonicalMapping == null ||
            canonicalMappingErrors == null ||
            canonicalMappingErrors.isNotEmpty ||
            doseUnitMappingEvidence == null ||
            AdministrationDoseConfirmationReceipt.digestSnapshot(
                  canonicalMappingRaw,
                ) !=
                AdministrationDoseConfirmationReceipt.digestSnapshot(
                  doseUnitMappingEvidence.toJson(),
                ) ||
            canonicalMapping.baseUnitCode != canonical['unit'] ||
            canonicalMapping.targetDimension.name != canonical['dimension']) {
          _invalid(findings, '$path.canonicalQuantity.unitMappingEvidence');
        } else {
          final quantity = expressionRaw is Map ? expressionRaw['value'] : null;
          final converted = quantity is num
              ? canonicalMapping.convertToBaseUnit(
                  quantity.toDouble(),
                  expectedSourceRevision: DosageNoteParser.grammarDigest,
                  evaluatedAt: DateTime.now().toUtc(),
                )
              : null;
          if (converted == null ||
              !_sameNumber(converted, canonical['value'])) {
            _invalid(findings, '$path.canonicalQuantity.value');
          }
        }
        if (canonical['unit'] == 'mL') {
          if (canonical['dimension'] != DoseExpressionDimension.volume.name ||
              canonical['milligrams'] != null) {
            _invalid(findings, '$path.canonicalQuantity.dimension');
          }
        } else if (canonical['unit'] != 'mg' ||
            canonical['dimension'] != DoseExpressionDimension.mass.name ||
            canonical['milligrams'] == null ||
            !_sameNumber(canonical['value'], canonical['milligrams'])) {
          _invalid(findings, '$path.canonicalQuantity.dimension');
        }
      }
    } else if (canonicalRaw != null) {
      _invalid(findings, '$path.canonicalQuantity');
    }
  }

  static void _validatePortableDoseTruthBinding(
    Map<String, Object?> row,
    String path, {
    required String doseOwnerScope,
    required DateTime observedAt,
    required List<String> findings,
  }) {
    try {
      final intake = _portableIntakeFromRow(row);
      final parser = DosageNoteParser();
      final coordinator = AdministrationDoseConfirmationCoordinator(
        parser: parser,
      );
      final expectedTruth = _doseTruth(
        parseResult: parser.inspect(intake.dosageNote),
        resultUse: coordinator.evaluateForResultUse(
          intake,
          ownerScope: doseOwnerScope,
          observedAt: observedAt,
        ),
        observedAt: observedAt,
      );
      if (_canonicalJson(row['doseTruth']) != _canonicalJson(expectedTruth)) {
        _invalid(findings, '$path.doseTruth.binding');
      }

      final confirmation = Map<String, Object?>.from(
        row['doseConfirmation'] as Map,
      );
      if (confirmation['evidenceStatus'] != 'invalid_evidence_quarantined') {
        if (_canonicalJson(confirmation) !=
            _canonicalJson(_doseConfirmationEvidence(intake))) {
          _invalid(findings, '$path.doseConfirmation.binding');
        }
      }
      final reconciliation = Map<String, Object?>.from(
        row['medicationReconciliation'] as Map,
      );
      if (reconciliation['evidenceStatus'] != 'invalid_evidence_quarantined') {
        if (!_medicationReconciliationBindingMatches(reconciliation, intake)) {
          _invalid(findings, '$path.medicationReconciliation.binding');
        }
      }
    } on Object {
      _invalid(findings, '$path.doseTruth.binding');
    }
  }

  static bool _medicationReconciliationBindingMatches(
    Map<String, Object?> actual,
    Intake intake,
  ) {
    final expected = _medicationReconciliationEvidence(intake);
    if (_canonicalJson(actual) == _canonicalJson(expected)) return true;
    if (actual['evidenceStatus'] != 'envelope_present') return false;
    final actualEnvelopeRaw = actual['envelope'];
    final expectedEnvelopeRaw = expected['envelope'];
    if (actualEnvelopeRaw is! Map || expectedEnvelopeRaw is! Map) return false;
    final actualMetadata = Map<String, Object?>.from(actual)
      ..remove('envelope');
    final expectedMetadata = Map<String, Object?>.from(expected)
      ..remove('envelope');
    if (_canonicalJson(actualMetadata) != _canonicalJson(expectedMetadata)) {
      return false;
    }

    // Intake serialization migrates accepted v1 assertions to v2. Validate the
    // old node's exact shape and digest, then bind it by its preserved identity.
    final actualEnvelope = Map<String, Object?>.from(actualEnvelopeRaw);
    final expectedEnvelope = Map<String, Object?>.from(expectedEnvelopeRaw);
    final actualEnvelopeMetadata = Map<String, Object?>.from(actualEnvelope)
      ..remove('assertions');
    final expectedEnvelopeMetadata = Map<String, Object?>.from(expectedEnvelope)
      ..remove('assertions');
    if (_canonicalJson(actualEnvelopeMetadata) !=
        _canonicalJson(expectedEnvelopeMetadata)) {
      return false;
    }
    final rawAssertions = actualEnvelope['assertions'];
    final expectedAssertions = intake.medicationAssertions;
    if (rawAssertions is! List ||
        rawAssertions.length != expectedAssertions.length) {
      return false;
    }
    try {
      for (var index = 0; index < rawAssertions.length; index++) {
        final raw = rawAssertions[index];
        if (raw is! Map) return false;
        final parsed = MedicationAssertionNode.fromJson(
          Map<String, dynamic>.from(raw),
        );
        final expectedAssertion = expectedAssertions[index];
        if (parsed.assertionId != expectedAssertion.assertionId ||
            parsed.assertionDigest != expectedAssertion.assertionDigest ||
            parsed.identitySchemaVersion !=
                expectedAssertion.identitySchemaVersion ||
            parsed.sourceDisplayLabel != expectedAssertion.sourceDisplayLabel ||
            (raw['schema_version'] == medicationAssertionSchemaVersion &&
                _canonicalJson(parsed.toJson()) != _canonicalJson(raw))) {
          return false;
        }
      }
    } on Object {
      return false;
    }
    return true;
  }

  static Intake _portableIntakeFromRow(Map<String, Object?> row) {
    final dose = Map<String, Object?>.from(row['dose'] as Map);
    final confirmation = Map<String, Object?>.from(
      row['doseConfirmation'] as Map,
    );
    AdministrationDoseConfirmationReceipt? receipt;
    Map<String, Object?>? invalidConfirmation;
    if (confirmation['evidenceStatus'] == 'receipt_present_unverified') {
      receipt = AdministrationDoseConfirmationReceipt.fromJson(
        Map<String, dynamic>.from(confirmation['receipt'] as Map),
      );
    } else if (confirmation['evidenceStatus'] ==
        'invalid_evidence_quarantined') {
      invalidConfirmation = <String, Object?>{
        'portable_invalid_evidence_digest':
            confirmation['invalidEvidenceDigest'],
      };
    }

    final reconciliation = Map<String, Object?>.from(
      row['medicationReconciliation'] as Map,
    );
    var assertions = const <MedicationAssertionNode>[];
    var decisions = const <MedicationReconciliationDecision>[];
    Map<String, Object?>? invalidReconciliation;
    if (reconciliation['evidenceStatus'] == 'envelope_present') {
      final envelope = Map<String, Object?>.from(
        reconciliation['envelope'] as Map,
      );
      assertions = (envelope['assertions'] as List)
          .map(
            (item) => MedicationAssertionNode.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
      decisions = (envelope['decisions'] as List)
          .map(
            (item) => MedicationReconciliationDecision.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false);
    } else if (reconciliation['evidenceStatus'] ==
        'invalid_evidence_quarantined') {
      invalidReconciliation = <String, Object?>{
        'portable_invalid_evidence_digest':
            reconciliation['invalidEvidenceDigest'],
      };
    }

    MedicationProductSelection? product;
    final productRaw = row['productSelection'];
    if (productRaw is Map) {
      final productJson = Map<String, dynamic>.from(productRaw)
        ..remove('meaningBoundary');
      product = MedicationProductSelection.fromJson(productJson);
      if (product == null) throw const FormatException();
    }
    final rawAmount = dose['amount'];
    return Intake(
      id: row['id'] as String,
      drugId: row['drugId'] as String,
      takenAt: DateTime.parse(row['takenAt'] as String),
      dosageNote: row['dosageNote'] as String,
      // Preserve a literal zero in the raw export. Intake.fromJson deliberately
      // normalizes non-positive values to null and therefore cannot be used for
      // this verification reconstruction.
      doseAmount: rawAmount is num ? rawAmount.toDouble() : null,
      doseUnit: dose['unit'] as String?,
      dosageForm: dose['dosageForm'] as String?,
      route: dose['route'] as String?,
      releaseType: dose['releaseType'] as String?,
      productSelection: product,
      doseConfirmation: receipt,
      invalidDoseConfirmationEvidence: invalidConfirmation,
      medicationAssertions: assertions,
      medicationReconciliationDecisions: decisions,
      invalidMedicationReconciliationEvidence: invalidReconciliation,
    );
  }

  static void _validateMealItem(
    Map<String, Object?> item,
    String path,
    List<String> findings,
  ) {
    _requireKeys(
      item,
      const <String>{
        'foodId',
        'foodName',
        'foodCategory',
        'quantity',
        'foodTags',
        'nutrientsPer100g',
        'catalogProvenance',
      },
      path,
      findings,
    );
    _checkString(
      item['foodName'],
      '$path.foodName',
      findings,
      allowEmpty: true,
    );
    _checkString(
      item['foodCategory'],
      '$path.foodCategory',
      findings,
      allowed: FoodCategory.values.map((value) => value.name).toSet(),
    );
    _checkStringList(
      item['foodTags'],
      '$path.foodTags',
      findings,
      unique: true,
      sorted: true,
    );
    final quantity = _schemaMap(
      item['quantity'],
      '$path.quantity',
      const <String>{'factorPer100g', 'grams'},
      findings,
    );
    if (quantity != null) {
      _checkNumber(
        quantity['factorPer100g'],
        '$path.quantity.factorPer100g',
        findings,
        min: 0,
      );
      _checkNumber(quantity['grams'], '$path.quantity.grams', findings, min: 0);
      if (!_numbersClose(
        quantity['grams'],
        quantity['factorPer100g'],
        multiplier: 100,
      )) {
        _invalid(findings, '$path.quantity');
      }
    }
    final nutrients = _schemaMap(
      item['nutrientsPer100g'],
      '$path.nutrientsPer100g',
      const <String>{'protein', 'carbs', 'fat', 'fiber', 'sodium'},
      findings,
    );
    final nutrientMaps = <String, Map<String, Object?>?>{};
    if (nutrients != null) {
      for (final name in const <String>[
        'protein',
        'carbs',
        'fat',
        'fiber',
        'sodium',
      ]) {
        final nutrient = _schemaMap(
          nutrients[name],
          '$path.nutrientsPer100g.$name',
          const <String>{
            'value',
            'unit',
            'missing',
            'rawCompatibilityValue',
            'status',
          },
          findings,
        );
        nutrientMaps[name] = nutrient;
        if (nutrient != null) {
          _validateNutrient(
            nutrient,
            '$path.nutrientsPer100g.$name',
            findings,
            sodium: name == 'sodium',
          );
        }
      }
    }
    final provenance = _schemaMap(
      item['catalogProvenance'],
      '$path.catalogProvenance',
      const <String>{
        'status',
        'sourceSystem',
        'sourceFoodCode',
        'jurisdiction',
        'basisType',
        'preparationState',
        'qualifierKind',
        'missingNutrientFields',
        'energyKcal',
        'waterG',
        'aminoAcidProfile',
        'referenceSnapshotOnly',
      },
      findings,
      requiredKeys: const <String>{'status'},
    );
    if (provenance == null) return;
    final status = provenance['status'];
    _checkString(
      status,
      '$path.catalogProvenance.status',
      findings,
      allowed: const <String>{'unresolved_at_export', 'resolved_at_export'},
    );
    if (status == 'unresolved_at_export') {
      if (provenance.length != 1) {
        _invalid(findings, '$path.catalogProvenance');
      }
      for (final nutrient
          in nutrientMaps.values.whereType<Map<String, Object?>>()) {
        if (nutrient['status'] != 'legacy_snapshot_missingness_unavailable') {
          _invalid(findings, '$path.nutrientsPer100g');
          break;
        }
      }
      return;
    }
    if (status != 'resolved_at_export') return;
    _requireKeys(
      provenance,
      const <String>{
        'status',
        'sourceSystem',
        'sourceFoodCode',
        'jurisdiction',
        'basisType',
        'preparationState',
        'qualifierKind',
        'missingNutrientFields',
        'energyKcal',
        'waterG',
        'aminoAcidProfile',
        'referenceSnapshotOnly',
      },
      '$path.catalogProvenance',
      findings,
    );
    _checkString(
      provenance['sourceSystem'],
      '$path.catalogProvenance.sourceSystem',
      findings,
    );
    _checkString(
      provenance['sourceFoodCode'],
      '$path.catalogProvenance.sourceFoodCode',
      findings,
      nullable: true,
    );
    _checkString(
      provenance['jurisdiction'],
      '$path.catalogProvenance.jurisdiction',
      findings,
    );
    for (final key in const <String>[
      'basisType',
      'preparationState',
      'qualifierKind',
    ]) {
      _checkString(
        provenance[key],
        '$path.catalogProvenance.$key',
        findings,
        nullable: true,
      );
    }
    const missingNames = <String>{
      'proteinG',
      'carbsG',
      'fatG',
      'fiberG',
      'sodiumMg',
      'energyKcal',
      'waterG',
    };
    final missing = _checkStringList(
      provenance['missingNutrientFields'],
      '$path.catalogProvenance.missingNutrientFields',
      findings,
      allowed: missingNames,
      unique: true,
      sorted: true,
    );
    _checkNumber(
      provenance['energyKcal'],
      '$path.catalogProvenance.energyKcal',
      findings,
      nullable: true,
      min: 0,
    );
    _checkNumber(
      provenance['waterG'],
      '$path.catalogProvenance.waterG',
      findings,
      nullable: true,
      min: 0,
    );
    if (missing != null) {
      const fieldByNutrient = <String, String>{
        'protein': 'proteinG',
        'carbs': 'carbsG',
        'fat': 'fatG',
        'fiber': 'fiberG',
        'sodium': 'sodiumMg',
      };
      for (final entry in fieldByNutrient.entries) {
        final nutrient = nutrientMaps[entry.key];
        if (nutrient == null) continue;
        final shouldBeMissing = missing.contains(entry.value);
        if (shouldBeMissing != (nutrient['missing'] == true) ||
            (shouldBeMissing &&
                nutrient['status'] != 'source_missing_not_zero') ||
            (!shouldBeMissing &&
                nutrient['status'] != 'catalog_snapshot_value')) {
          _invalid(findings, '$path.nutrientsPer100g.${entry.key}.missing');
        }
      }
      if ((missing.contains('energyKcal') &&
              provenance['energyKcal'] != null) ||
          (missing.contains('waterG') && provenance['waterG'] != null)) {
        _invalid(findings, '$path.catalogProvenance.missingNutrientFields');
      }
    }
    if (provenance['referenceSnapshotOnly'] != true) {
      _invalid(findings, '$path.catalogProvenance.referenceSnapshotOnly');
    }
    _validateAminoAcidScalars(
      provenance['aminoAcidProfile'],
      '$path.catalogProvenance.aminoAcidProfile',
      findings,
    );
  }

  static void _validateNutrient(
    Map<String, Object?> nutrient,
    String path,
    List<String> findings, {
    required bool sodium,
  }) {
    _checkString(
      nutrient['unit'],
      '$path.unit',
      findings,
      allowed: <String>{sodium ? 'mg_per_100g' : 'g_per_100g'},
    );
    _checkNumber(
      nutrient['rawCompatibilityValue'],
      '$path.rawCompatibilityValue',
      findings,
      min: 0,
    );
    final status = nutrient['status'];
    _checkString(
      status,
      '$path.status',
      findings,
      allowed: const <String>{
        'legacy_snapshot_missingness_unavailable',
        'source_missing_not_zero',
        'catalog_snapshot_value',
      },
    );
    switch (status) {
      case 'source_missing_not_zero':
        if (nutrient['missing'] != true || nutrient['value'] != null) {
          _invalid(findings, path);
        }
      case 'catalog_snapshot_value':
        if (nutrient['missing'] != false ||
            !_sameNumber(
              nutrient['value'],
              nutrient['rawCompatibilityValue'],
            )) {
          _invalid(findings, path);
        }
      case 'legacy_snapshot_missingness_unavailable':
        if (nutrient['missing'] != null ||
            !_sameNumber(
              nutrient['value'],
              nutrient['rawCompatibilityValue'],
            )) {
          _invalid(findings, path);
        }
      default:
        break;
    }
    if (nutrient['value'] != null) {
      _checkNumber(nutrient['value'], '$path.value', findings, min: 0);
    }
  }

  static void _validateAminoAcidScalars(
    Object? raw,
    String path,
    List<String> findings,
  ) {
    if (raw == null) return;
    const aminoNames = <String>{
      'leucine',
      'isoleucine',
      'valine',
      'phenylalanine',
      'tyrosine',
      'tryptophan',
      'histidine',
      'methionine',
      'threonine',
      'lysine',
      'cystine',
      'arginine',
    };
    final profile = _schemaMap(raw, path, <String>{
      ...aminoNames,
      'unit',
      'basis',
      'nutrient_ids',
      'source_refs',
      'partial',
      'competing_lnaa_grams',
      'fdc_data_type',
      'aggregate_confidence_tier',
      'derivations',
    }, findings);
    if (profile == null) return;
    for (final name in aminoNames) {
      _checkNumber(
        profile[name],
        '$path.$name',
        findings,
        nullable: true,
        min: 0,
      );
    }
    _checkString(
      profile['unit'],
      '$path.unit',
      findings,
      allowed: const <String>{'g'},
    );
    _checkString(
      profile['basis'],
      '$path.basis',
      findings,
      allowed: const <String>{'per_100g', 'per_serving'},
    );
    _checkStringList(
      profile['nutrient_ids'],
      '$path.nutrient_ids',
      findings,
      unique: true,
    );
    _checkStringList(
      profile['source_refs'],
      '$path.source_refs',
      findings,
      unique: true,
    );
    _checkBool(profile['partial'], '$path.partial', findings);
    _checkNumber(
      profile['competing_lnaa_grams'],
      '$path.competing_lnaa_grams',
      findings,
      nullable: true,
      min: 0,
    );
    _checkString(
      profile['fdc_data_type'],
      '$path.fdc_data_type',
      findings,
      nullable: true,
    );
    final competingValues =
        const <String>{
              'leucine',
              'isoleucine',
              'valine',
              'phenylalanine',
              'tyrosine',
              'tryptophan',
            }
            .map((name) => profile[name])
            .whereType<num>()
            .map((value) => value.toDouble())
            .toList();
    final expectedCompeting = competingValues.isEmpty
        ? null
        : competingValues.fold<double>(0, (sum, value) => sum + value);
    if (expectedCompeting == null
        ? profile['competing_lnaa_grams'] != null
        : !_sameNumber(profile['competing_lnaa_grams'], expectedCompeting)) {
      _invalid(findings, '$path.competing_lnaa_grams');
    }
    final derivationsRaw = profile['derivations'];
    if (derivationsRaw is! Map) {
      _invalid(findings, '$path.derivations');
      return;
    }
    var weakestRank = -1;
    for (final entry in derivationsRaw.entries) {
      if (entry.key is! String || !aminoNames.contains(entry.key)) {
        _invalid(findings, '$path.derivations');
        continue;
      }
      final derivationPath = '$path.derivations.${entry.key}';
      final derivation = _schemaMap(entry.value, derivationPath, const <String>{
        'derivation_code',
        'derivation_description',
        'source_code',
        'data_points',
        'min',
        'max',
        'median',
        'tier',
      }, findings);
      if (derivation == null) continue;
      for (final key in const <String>[
        'derivation_code',
        'derivation_description',
        'source_code',
      ]) {
        _checkString(
          derivation[key],
          '$derivationPath.$key',
          findings,
          nullable: true,
        );
      }
      _checkInt(
        derivation['data_points'],
        '$derivationPath.data_points',
        findings,
        nullable: true,
        min: 0,
      );
      for (final key in const <String>['min', 'max', 'median']) {
        _checkNumber(
          derivation[key],
          '$derivationPath.$key',
          findings,
          nullable: true,
          min: 0,
        );
      }
      final tier = derivation['tier'];
      _checkString(
        tier,
        '$derivationPath.tier',
        findings,
        allowed: NutrientConfidenceTier.values
            .map((value) => value.name)
            .toSet(),
      );
      if (tier is String) {
        final expectedTier = NutrientDerivation.fromJson(
          Map<String, dynamic>.from(derivation),
        ).tier.name;
        if (tier != expectedTier) _invalid(findings, '$derivationPath.tier');
        final rank = NutrientConfidenceTier.values.indexWhere(
          (value) => value.name == tier,
        );
        if (rank > weakestRank) weakestRank = rank;
      }
      final min = derivation['min'];
      final max = derivation['max'];
      final median = derivation['median'];
      if (min is num && max is num && min > max ||
          median is num && min is num && median < min ||
          median is num && max is num && median > max) {
        _invalid(findings, derivationPath);
      }
    }
    final aggregate = profile['aggregate_confidence_tier'];
    if (derivationsRaw.isEmpty) {
      if (aggregate != null) {
        _invalid(findings, '$path.aggregate_confidence_tier');
      }
    } else {
      final expected = weakestRank < 0
          ? null
          : NutrientConfidenceTier.values[weakestRank].name;
      if (aggregate != expected) {
        _invalid(findings, '$path.aggregate_confidence_tier');
      }
    }
  }

  static void _validateCatalogProvenance(
    Object? raw,
    String path,
    List<String> findings, {
    required String sourceCodeKey,
  }) {
    final provenance = _schemaMap(
      raw,
      path,
      <String>{'status', 'sourceSystem', sourceCodeKey, 'jurisdiction'},
      findings,
      requiredKeys: const <String>{'status'},
    );
    if (provenance == null) return;
    final status = provenance['status'];
    _checkString(
      status,
      '$path.status',
      findings,
      allowed: const <String>{'unresolved_at_export', 'resolved_at_export'},
    );
    if (status == 'unresolved_at_export') {
      if (provenance.length != 1) _invalid(findings, path);
      return;
    }
    if (status != 'resolved_at_export') return;
    _requireKeys(
      provenance,
      <String>{'status', 'sourceSystem', sourceCodeKey, 'jurisdiction'},
      path,
      findings,
    );
    _checkString(provenance['sourceSystem'], '$path.sourceSystem', findings);
    _checkString(
      provenance[sourceCodeKey],
      '$path.$sourceCodeKey',
      findings,
      nullable: true,
    );
    _checkString(provenance['jurisdiction'], '$path.jurisdiction', findings);
  }

  static void _validateAuditLinks({
    required Map<String, Object?> files,
    required List<Map<String, Object?>> medicationRows,
    required List<Map<String, Object?>> intakeRows,
    required List<Map<String, Object?>> mealRows,
    required List<Map<String, Object?>> reminderRows,
    required List<String> findings,
  }) {
    final audit = _schemaMap(
      files['audit_links.json'],
      r'$.files.audit_links.json',
      const <String>{
        'availability',
        'clinicalAuditRecordsIncluded',
        'reason',
        'links',
      },
      findings,
    );
    if (audit == null) return;
    if (audit['availability'] != 'relationship_links_only' ||
        audit['clinicalAuditRecordsIncluded'] != false ||
        audit['reason'] != _userPortableDataAuditReason) {
      _invalid(findings, r'$.files.audit_links.json');
    }
    final links = _schemaRows(
      audit['links'],
      r'$.files.audit_links.json.links',
      findings,
    );
    final actual = <String, int>{};
    for (var index = 0; index < links.length; index++) {
      final path =
          r'$.files.audit_links.json.links['
          '$index]';
      final link = links[index];
      _requireKeys(
        link,
        const <String>{
          'recordType',
          'recordId',
          'relationship',
          'targetType',
          'targetId',
        },
        path,
        findings,
      );
      for (final key in const <String>[
        'recordType',
        'recordId',
        'relationship',
        'targetType',
        'targetId',
      ]) {
        _checkString(link[key], '$path.$key', findings);
      }
      final tuple = _auditTuple(link);
      if (tuple == null) {
        _invalid(findings, path);
      } else {
        actual[tuple] = (actual[tuple] ?? 0) + 1;
      }
    }
    final expected = <String, int>{};
    final medicationSelectionIds = medicationRows
        .map((row) => row['id'])
        .whereType<String>()
        .toSet();
    void addExpected(Map<String, Object?> row) {
      final tuple = _auditTuple(row);
      if (tuple != null) expected[tuple] = (expected[tuple] ?? 0) + 1;
    }

    for (final intake in intakeRows) {
      if (!medicationSelectionIds.contains(intake['drugId'])) {
        _invalid(findings, r'$.files.audit_links.json.links');
      }
      addExpected(<String, Object?>{
        'recordType': 'intake',
        'recordId': intake['id'],
        'relationship': 'references_medication_selection',
        'targetType': 'medication_selection',
        'targetId': intake['drugId'],
      });
    }
    for (final meal in mealRows) {
      final items = meal['items'];
      if (items is! List) continue;
      for (final rawItem in items.whereType<Map>()) {
        addExpected(<String, Object?>{
          'recordType': 'meal',
          'recordId': meal['id'],
          'relationship': 'contains_food',
          'targetType': 'food_catalog_reference',
          'targetId': rawItem['foodId'],
        });
      }
    }
    for (final reminder in reminderRows) {
      addExpected(<String, Object?>{
        'recordType': 'reminder',
        'recordId': reminder['id'],
        'relationship': 'prompts_log_kind',
        'targetType': 'user_log_kind',
        'targetId': reminder['kind'],
      });
    }
    if (!_sameCountMap(actual, expected)) {
      _invalid(findings, r'$.files.audit_links.json.links');
    }
  }

  static String? _auditTuple(Map<String, Object?> link) {
    final recordType = link['recordType'];
    final relationship = link['relationship'];
    final targetType = link['targetType'];
    final targetId = link['targetId'];
    final valid =
        recordType == 'intake' &&
            relationship == 'references_medication_selection' &&
            targetType == 'medication_selection' ||
        recordType == 'meal' &&
            relationship == 'contains_food' &&
            targetType == 'food_catalog_reference' ||
        recordType == 'reminder' &&
            relationship == 'prompts_log_kind' &&
            targetType == 'user_log_kind' &&
            UserLoggingReminderKind.values.any(
              (value) => value.name == targetId,
            );
    if (!valid ||
        link['recordId'] is! String ||
        targetId is! String ||
        !_isSafePortableId(link['recordId'] as String) ||
        !_isSafePortableId(targetId)) {
      return null;
    }
    return '$recordType\u0000${link['recordId']}\u0000$relationship\u0000$targetType\u0000$targetId';
  }

  static Map<String, Object?>? _schemaMap(
    Object? raw,
    String path,
    Set<String> allowedKeys,
    List<String> findings, {
    Set<String>? requiredKeys,
  }) {
    if (raw is! Map) {
      _invalid(findings, path);
      return null;
    }
    final mapped = Map<String, Object?>.from(raw);
    _requireKeys(mapped, requiredKeys ?? allowedKeys, path, findings);
    return mapped;
  }

  static List<Map<String, Object?>> _schemaRows(
    Object? raw,
    String path,
    List<String> findings,
  ) {
    if (raw is! List) {
      _invalid(findings, path);
      return const <Map<String, Object?>>[];
    }
    final output = <Map<String, Object?>>[];
    for (var index = 0; index < raw.length; index++) {
      final row = raw[index];
      if (row is! Map) {
        _invalid(findings, '$path[$index]');
      } else {
        output.add(Map<String, Object?>.from(row));
      }
    }
    return output;
  }

  static void _requireKeys(
    Map<String, Object?> value,
    Set<String> keys,
    String path,
    List<String> findings,
  ) {
    if (!_hasRequiredKeys(value, keys)) _invalid(findings, path);
  }

  static bool _hasRequiredKeys(Map<String, Object?> value, Set<String> keys) =>
      keys.every(value.containsKey);

  static bool _isSha256(Object? value) =>
      value is String && RegExp(r'^[a-f0-9]{64}$').hasMatch(value);

  static void _checkString(
    Object? value,
    String path,
    List<String> findings, {
    bool nullable = false,
    bool allowEmpty = false,
    Set<String>? allowed,
  }) {
    if (value == null && nullable) return;
    if (value is! String ||
        (!allowEmpty && value.trim().isEmpty) ||
        (allowed != null && !allowed.contains(value))) {
      _invalid(findings, path);
    }
  }

  static List<String>? _checkStringList(
    Object? value,
    String path,
    List<String> findings, {
    Set<String>? allowed,
    bool unique = false,
    bool sorted = false,
    bool nonEmpty = false,
  }) {
    if (value is! List || value.any((item) => item is! String)) {
      _invalid(findings, path);
      return null;
    }
    final strings = value.cast<String>();
    if ((nonEmpty && strings.isEmpty) ||
        strings.any((item) => item.trim().isEmpty) ||
        (allowed != null && strings.any((item) => !allowed.contains(item))) ||
        (unique && strings.toSet().length != strings.length) ||
        (sorted && !_isSortedStrings(strings))) {
      _invalid(findings, path);
    }
    return strings;
  }

  static void _checkIntList(
    Object? value,
    String path,
    List<String> findings, {
    required int min,
    required int max,
    bool nonEmpty = false,
    bool unique = false,
    bool sorted = false,
  }) {
    if (value is! List || value.any((item) => item is! int)) {
      _invalid(findings, path);
      return;
    }
    final values = value.cast<int>();
    if ((nonEmpty && values.isEmpty) ||
        values.any((item) => item < min || item > max) ||
        (unique && values.toSet().length != values.length) ||
        (sorted && !_isSortedInts(values))) {
      _invalid(findings, path);
    }
  }

  static void _checkBool(Object? value, String path, List<String> findings) {
    if (value is! bool) _invalid(findings, path);
  }

  static void _checkInt(
    Object? value,
    String path,
    List<String> findings, {
    bool nullable = false,
    int? min,
    int? max,
  }) {
    if (value == null && nullable) return;
    if (value is! int ||
        min != null && value < min ||
        max != null && value > max) {
      _invalid(findings, path);
    }
  }

  static void _checkNumber(
    Object? value,
    String path,
    List<String> findings, {
    bool nullable = false,
    double? min,
    double? minExclusive,
  }) {
    if (value == null && nullable) return;
    if (value is! num ||
        !value.isFinite ||
        min != null && value < min ||
        minExclusive != null && value <= minExclusive) {
      _invalid(findings, path);
    }
  }

  static void _checkTimestamp(
    Object? value,
    String path,
    List<String> findings, {
    bool nullable = false,
  }) {
    if (value == null && nullable) return;
    if (!_isCanonicalUtcTimestamp(value)) _invalid(findings, path);
  }

  static void _checkOrderedTimestamps(
    Object? start,
    Object? end,
    String path,
    List<String> findings, {
    required bool requirePair,
  }) {
    // Ranges are always complete pairs when present. Interval precision also
    // requires the occurrence range to be present rather than merely allowing
    // two null endpoints.
    if ((start == null) != (end == null) ||
        requirePair && (start == null || end == null)) {
      _invalid(findings, path);
      return;
    }
    if (start == null || end == null) return;
    if (!_isCanonicalUtcTimestamp(start) ||
        !_isCanonicalUtcTimestamp(end) ||
        DateTime.parse(
          start as String,
        ).isAfter(DateTime.parse(end as String))) {
      _invalid(findings, path);
    }
  }

  static bool _sameNumber(Object? left, Object? right) {
    if (left is! num || right is! num || !left.isFinite || !right.isFinite) {
      return false;
    }
    return (left.toDouble() - right.toDouble()).abs() <= 1e-9;
  }

  static bool _numbersClose(
    Object? left,
    Object? right, {
    required double multiplier,
  }) {
    if (left is! num || right is! num || !left.isFinite || !right.isFinite) {
      return false;
    }
    return (left.toDouble() - right.toDouble() * multiplier).abs() <= 1e-9;
  }

  static bool _isSortedStrings(List<String> values) {
    for (var index = 1; index < values.length; index++) {
      if (values[index - 1].compareTo(values[index]) > 0) return false;
    }
    return true;
  }

  static bool _isSortedInts(List<int> values) {
    for (var index = 1; index < values.length; index++) {
      if (values[index - 1] > values[index]) return false;
    }
    return true;
  }

  static bool _sameCountMap(Map<String, int> left, Map<String, int> right) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  static void _invalid(List<String> findings, String path) {
    final finding =
        '$path has a missing or invalid portable schema-v$userPortableDataPackageSchemaVersion value.';
    if (!findings.contains(finding)) findings.add(finding);
  }

  static void _requireRecordBudgets(Map<String, Object?> files) {
    final finding = _recordBudgetFinding(files);
    if (finding != null) throw FormatException(finding);
  }

  static String? _recordBudgetFinding(Map<String, Object?> files) {
    var total = 0;
    for (final entry in userPortableDataRecordLimits.entries) {
      final count = _recordCount(files[entry.key]);
      if (count > entry.value) {
        return '${entry.key} has $count records; limit is ${entry.value}.';
      }
      total += count;
    }
    if (total > userPortableDataMaxTotalRecords) {
      return 'The package has $total records; total limit is $userPortableDataMaxTotalRecords.';
    }
    return null;
  }

  static void _requireKnownIdentifiers(Map<String, Object?> files) {
    final findings = <String>[];
    _validateKnownIdentifiers(files, findings);
    if (findings.isNotEmpty) throw FormatException(findings.first);
  }

  static void _validateKnownIdentifiers(
    Map<String, Object?> files,
    List<String> findings,
  ) {
    const idFiles = <String>[
      'medication_selections.json',
      'intakes.json',
      'meals.json',
      'reminders.json',
      'observations.json',
    ];
    for (final path in idFiles) {
      final raw = files[path];
      final rows = path == 'observations.json' && raw is Map
          ? raw['records']
          : raw;
      if (rows is! List) continue;
      final seen = <String>{};
      for (var index = 0; index < rows.length; index++) {
        final row = rows[index];
        if (row is! Map) continue;
        final id = row['id'];
        if (id is! String || !_isSafePortableId(id)) {
          findings.add('$path[$index] has a missing or unsafe id.');
          continue;
        }
        if (!seen.add(id)) findings.add('$path contains duplicate id "$id".');
        if (path == 'intakes.json') {
          _validateReferenceId(row['drugId'], '$path[$index].drugId', findings);
        } else if (path == 'meals.json') {
          final items = row['items'];
          if (items is List) {
            for (var itemIndex = 0; itemIndex < items.length; itemIndex++) {
              final item = items[itemIndex];
              if (item is Map) {
                _validateReferenceId(
                  item['foodId'],
                  '$path[$index].items[$itemIndex].foodId',
                  findings,
                );
              }
            }
          }
        }
      }
    }
    final audit = files['audit_links.json'];
    final links = audit is Map ? audit['links'] : null;
    if (links is List) {
      for (var index = 0; index < links.length; index++) {
        final link = links[index];
        if (link is! Map) continue;
        _validateReferenceId(
          link['recordId'],
          'audit_links.json.links[$index].recordId',
          findings,
        );
        _validateReferenceId(
          link['targetId'],
          'audit_links.json.links[$index].targetId',
          findings,
        );
      }
    }
  }

  static void _validateReferenceId(
    Object? value,
    String path,
    List<String> findings,
  ) {
    if (value is! String || !_isSafePortableId(value)) {
      findings.add('$path is missing or unsafe.');
    }
  }

  static bool _isSafePortableId(String value) {
    final trimmed = value.trim();
    if (trimmed != value || utf8.encode(value).length > 256) return false;
    return RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:-]{0,255}$').hasMatch(value);
  }

  static bool _isCanonicalUtcTimestamp(Object? value) {
    if (value is! String || !value.endsWith('Z')) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.isUtc && parsed.toIso8601String() == value;
  }

  static bool _sameStringList(Object? value, List<String> expected) {
    if (value is! List || value.length != expected.length) return false;
    for (var index = 0; index < expected.length; index++) {
      if (value[index] != expected[index]) return false;
    }
    return true;
  }

  static String? _jsonLexicalBudgetFinding(String source) {
    return _PortableJsonPreflightParser(source).run();
  }

  static String? _decodedBudgetFinding(Object? root) {
    var nodes = 0;

    String? visit(Object? value, int depth, String path) {
      nodes += 1;
      if (nodes > userPortableDataMaxJsonNodes) {
        return 'The package exceeds the $userPortableDataMaxJsonNodes-node JSON budget.';
      }
      if (depth > userPortableDataMaxJsonDepth) {
        return 'The package exceeds the maximum JSON nesting depth of $userPortableDataMaxJsonDepth.';
      }
      if (value is String) {
        if (utf8.encode(value).length > userPortableDataMaxStringBytes) {
          return '$path exceeds the $userPortableDataMaxStringBytes-byte string limit.';
        }
        return null;
      }
      if (value is Map) {
        if (value.length > userPortableDataMaxMapFields) {
          return '$path has ${value.length} fields; limit is $userPortableDataMaxMapFields.';
        }
        for (final entry in value.entries) {
          if (entry.key is! String) return '$path contains a non-string key.';
          if (utf8.encode(entry.key as String).length >
              userPortableDataMaxKeyBytes) {
            return '$path contains a field name longer than '
                '$userPortableDataMaxKeyBytes bytes.';
          }
          final finding = visit(entry.value, depth + 1, '$path.${entry.key}');
          if (finding != null) return finding;
        }
        return null;
      }
      if (value is List) {
        for (var index = 0; index < value.length; index++) {
          final finding = visit(value[index], depth + 1, '$path[$index]');
          if (finding != null) return finding;
        }
      }
      return null;
    }

    return visit(root, 1, r'$');
  }

  static Set<String> _ids(Object? data) {
    final rows = data is List
        ? data
        : data is Map && data['records'] is List
        ? data['records'] as List
        : const <Object?>[];
    return rows
        .whereType<Map>()
        .map((row) => row['id'])
        .whereType<String>()
        .toSet();
  }

  static void _collectUnsupportedKeys(
    Map<String, Object?> value,
    Set<String> supported,
    String path,
    List<String> output,
  ) {
    for (final key in value.keys) {
      if (!supported.contains(key)) output.add('$path.$key');
    }
  }

  static int _recordCount(Object? value) {
    if (value is List) return value.length;
    if (value is Map) {
      final records = value['records'];
      if (records is List) return records.length;
      final links = value['links'];
      return links is List ? links.length : 1;
    }
    return 0;
  }

  static String _scopeDigest(String rawScope, String scopeKind) => _sha256(
    'parkinsum-portable-owner-v1|${scopeKind.trim()}|${rawScope.trim()}',
  );

  static String _sha256(String value) =>
      sha256.convert(utf8.encode(value)).toString();

  static String _canonicalJson(Object? value) => jsonEncode(_sortJson(value));

  static Object? _sortJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _sortJson(value[key]),
      };
    }
    if (value is Iterable) {
      return value.map<Object?>((item) => _sortJson(item)).toList();
    }
    return value;
  }

  static void _validateJsonValue(Object? value, String path) {
    if (value == null || value is String || value is bool) return;
    if (value is num) {
      if (!value.isFinite) {
        throw FormatException('Non-finite number at $path.');
      }
      return;
    }
    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.key is! String) {
          throw FormatException('Non-string JSON key at $path.');
        }
        _validateJsonValue(entry.value, '$path.${entry.key}');
      }
      return;
    }
    if (value is Iterable) {
      var index = 0;
      for (final item in value) {
        _validateJsonValue(item, '$path[$index]');
        index += 1;
      }
      return;
    }
    throw FormatException(
      'Unsupported JSON value at $path: ${value.runtimeType}.',
    );
  }
}

Map<String, Object?> _inspectPortablePackageWorker(
  Map<String, Object?> request,
) {
  final rawExisting = Map<String, Object?>.from(
    request['existingRecordIds'] as Map,
  );
  final preview =
      UserPortableDataPackageService(
        maxPackageBytes: request['maxPackageBytes'] as int,
      ).inspect(
        packageJson: request['packageJson'] as String,
        currentUserScope: request['currentUserScope'] as String,
        currentDoseOwnerScope: request['currentDoseOwnerScope'] as String,
        currentScopeKind: request['currentScopeKind'] as String,
        existingRecordIds: <String, Set<String>>{
          for (final entry in rawExisting.entries)
            entry.key: (entry.value as List).cast<String>().toSet(),
        },
      );
  return <String, Object?>{
    'status': preview.status.name,
    'schemaVersion': preview.schemaVersion,
    'packageId': preview.packageId,
    'recordCounts': preview.recordCounts,
    'conflicts': preview.conflicts,
    'unsupportedFields': preview.unsupportedFields,
    'proposedMigrations': preview.proposedMigrations,
    'findings': preview.findings,
    'reminderPresentation': preview.reminderPresentation.toJson(),
    'schemaMigrationReceipt': preview.schemaMigrationReceipt?.toJson(),
  };
}

UserPortableDataImportPreview _previewFromTransfer(Map<String, Object?> raw) {
  final reminder = Map<String, Object?>.from(
    raw['reminderPresentation'] as Map,
  );
  return UserPortableDataImportPreview(
    status: UserPortableDataPreviewStatus.values.byName(
      raw['status'] as String,
    ),
    schemaVersion: raw['schemaVersion'] as int?,
    packageId: raw['packageId'] as String?,
    recordCounts: Map<String, Object?>.from(
      raw['recordCounts'] as Map,
    ).map((key, value) => MapEntry(key, value as int)),
    conflicts: Map<String, Object?>.from(
      raw['conflicts'] as Map,
    ).map((key, value) => MapEntry(key, (value as List).cast<String>())),
    unsupportedFields: (raw['unsupportedFields'] as List).cast<String>(),
    proposedMigrations: (raw['proposedMigrations'] as List).cast<String>(),
    findings: (raw['findings'] as List).cast<String>(),
    reminderPresentation: UserPortableReminderPresentationSummary(
      totalCount: reminder['totalCount'] as int,
      enabledIntentCount: reminder['enabledIntentCount'] as int,
      targetConsentRequiredCount: reminder['targetConsentRequiredCount'] as int,
      legacyDefaultCount: reminder['legacyDefaultCount'] as int,
      currentPolicyMatchCount: reminder['currentPolicyMatchCount'] as int,
      currentPolicyDriftCount: reminder['currentPolicyDriftCount'] as int,
      localeDecisionMismatchCount:
          reminder['localeDecisionMismatchCount'] as int,
      privacyModes: (reminder['privacyModes'] as List).cast<String>(),
      scheduledLanguageCodes: (reminder['scheduledLanguageCodes'] as List)
          .cast<String>(),
    ),
    schemaMigrationReceipt: raw['schemaMigrationReceipt'] == null
        ? null
        : PortableSchemaMigrationReceipt.fromJson(
            Map<String, Object?>.from(raw['schemaMigrationReceipt'] as Map),
          ),
  );
}

/// A bounded recursive-descent JSON preflight that runs before [jsonDecode].
///
/// It intentionally validates enough lexical structure to count every JSON
/// value node without materializing the document, caps source-string size,
/// caps object width/depth, and rejects duplicate object keys (including keys
/// that differ only by JSON escaping). The decoded walk remains as a second
/// defence, but an adversarial shallow array cannot allocate millions of Dart
/// objects before the node budget is applied.
class _PortableJsonPreflightParser {
  _PortableJsonPreflightParser(this.source);

  final String source;
  int _index = 0;
  int _nodes = 0;

  String? run() {
    try {
      _skipWhitespace();
      _parseValue(1);
      _skipWhitespace();
      if (_index != source.length) _syntaxFailure();
      return null;
    } on _PortableJsonPreflightFailure catch (failure) {
      return failure.message;
    }
  }

  void _parseValue(int depth) {
    if (depth > userPortableDataMaxJsonDepth) {
      _fail(
        'The package exceeds the maximum JSON nesting depth of '
        '$userPortableDataMaxJsonDepth.',
      );
    }
    _skipWhitespace();
    if (_index >= source.length) _syntaxFailure();
    _nodes += 1;
    if (_nodes > userPortableDataMaxJsonNodes) {
      _fail(
        'The package exceeds the $userPortableDataMaxJsonNodes-node JSON budget.',
      );
    }
    final unit = source.codeUnitAt(_index);
    switch (unit) {
      case 0x7b: // {
        _parseObject(depth);
        return;
      case 0x5b: // [
        _parseArray(depth);
        return;
      case 0x22: // "
        _parseString(decode: false);
        return;
      case 0x74: // true
        _consumeLiteral('true');
        return;
      case 0x66: // false
        _consumeLiteral('false');
        return;
      case 0x6e: // null
        _consumeLiteral('null');
        return;
      default:
        if (unit == 0x2d || (unit >= 0x30 && unit <= 0x39)) {
          _parseNumber();
        } else {
          _syntaxFailure();
        }
    }
  }

  void _parseObject(int depth) {
    _index += 1;
    _skipWhitespace();
    if (_consumeIf(0x7d)) return;
    final keys = <String>{};
    var fields = 0;
    while (true) {
      _skipWhitespace();
      if (_index >= source.length || source.codeUnitAt(_index) != 0x22) {
        _syntaxFailure();
      }
      final key = _parseString(decode: true)!;
      fields += 1;
      if (fields > userPortableDataMaxMapFields) {
        _fail(
          'A JSON object has too many fields; limit is '
          '$userPortableDataMaxMapFields.',
        );
      }
      if (utf8.encode(key).length > userPortableDataMaxKeyBytes) {
        _fail(
          'A JSON field name exceeds the '
          '$userPortableDataMaxKeyBytes-byte limit.',
        );
      }
      if (!keys.add(key)) {
        _fail('Duplicate JSON object keys are not supported.');
      }
      _skipWhitespace();
      _expect(0x3a); // :
      _parseValue(depth + 1);
      _skipWhitespace();
      if (_consumeIf(0x7d)) return;
      _expect(0x2c); // ,
    }
  }

  void _parseArray(int depth) {
    _index += 1;
    _skipWhitespace();
    if (_consumeIf(0x5d)) return;
    while (true) {
      _parseValue(depth + 1);
      _skipWhitespace();
      if (_consumeIf(0x5d)) return;
      _expect(0x2c); // ,
    }
  }

  String? _parseString({required bool decode}) {
    final tokenStart = _index;
    _expect(0x22);
    var sourceBytes = 0;
    while (_index < source.length) {
      final unit = source.codeUnitAt(_index);
      if (unit == 0x22) {
        _index += 1;
        if (!decode) return null;
        try {
          final decoded = jsonDecode(source.substring(tokenStart, _index));
          if (decoded is! String) _syntaxFailure();
          return decoded;
        } on FormatException {
          _syntaxFailure();
        }
      }
      if (unit < 0x20) _syntaxFailure();
      if (unit == 0x5c) {
        sourceBytes += 1;
        _index += 1;
        if (_index >= source.length) _syntaxFailure();
        final escaped = source.codeUnitAt(_index);
        sourceBytes += 1;
        if (escaped == 0x75) {
          final first = _unicodeEscapeCodeUnit(_index + 1);
          sourceBytes += 4;
          _index += 5;
          int scalar;
          if (_isHighSurrogate(first)) {
            if (_index + 5 >= source.length ||
                source.codeUnitAt(_index) != 0x5c ||
                source.codeUnitAt(_index + 1) != 0x75) {
              _unicodeScalarFailure();
            }
            final second = _unicodeEscapeCodeUnit(_index + 2);
            if (!_isLowSurrogate(second)) _unicodeScalarFailure();
            scalar = 0x10000 + ((first - 0xd800) << 10) + (second - 0xdc00);
            sourceBytes += 6;
            _index += 6;
          } else {
            if (_isLowSurrogate(first)) _unicodeScalarFailure();
            scalar = first;
          }
          if (_isUnicodeNoncharacter(scalar)) _unicodeScalarFailure();
        } else {
          if (escaped != 0x22 &&
              escaped != 0x5c &&
              escaped != 0x2f &&
              escaped != 0x62 &&
              escaped != 0x66 &&
              escaped != 0x6e &&
              escaped != 0x72 &&
              escaped != 0x74) {
            _syntaxFailure();
          }
          _index += 1;
        }
      } else if (unit <= 0x7f) {
        sourceBytes += 1;
        _index += 1;
      } else if (unit <= 0x7ff) {
        sourceBytes += 2;
        _index += 1;
      } else if (unit >= 0xd800 &&
          unit <= 0xdbff &&
          _index + 1 < source.length &&
          source.codeUnitAt(_index + 1) >= 0xdc00 &&
          source.codeUnitAt(_index + 1) <= 0xdfff) {
        final low = source.codeUnitAt(_index + 1);
        final scalar = 0x10000 + ((unit - 0xd800) << 10) + (low - 0xdc00);
        if (_isUnicodeNoncharacter(scalar)) _unicodeScalarFailure();
        sourceBytes += 4;
        _index += 2;
      } else {
        if (_isHighSurrogate(unit) ||
            _isLowSurrogate(unit) ||
            _isUnicodeNoncharacter(unit)) {
          _unicodeScalarFailure();
        }
        sourceBytes += 3;
        _index += 1;
      }
      if (sourceBytes > userPortableDataMaxStringBytes) {
        _fail(
          'A JSON string exceeds the $userPortableDataMaxStringBytes-byte string limit.',
        );
      }
    }
    _syntaxFailure();
  }

  int _unicodeEscapeCodeUnit(int start) {
    if (start + 4 > source.length) _syntaxFailure();
    var value = 0;
    for (var offset = 0; offset < 4; offset++) {
      final unit = source.codeUnitAt(start + offset);
      if (!_isHex(unit)) _syntaxFailure();
      value = (value << 4) | _hexValue(unit);
    }
    return value;
  }

  static int _hexValue(int unit) {
    if (unit >= 0x30 && unit <= 0x39) return unit - 0x30;
    if (unit >= 0x41 && unit <= 0x46) return unit - 0x41 + 10;
    return unit - 0x61 + 10;
  }

  static bool _isHighSurrogate(int value) => value >= 0xd800 && value <= 0xdbff;

  static bool _isLowSurrogate(int value) => value >= 0xdc00 && value <= 0xdfff;

  static bool _isUnicodeNoncharacter(int scalar) =>
      (scalar >= 0xfdd0 && scalar <= 0xfdef) ||
      (scalar & 0xffff) == 0xfffe ||
      (scalar & 0xffff) == 0xffff;

  Never _unicodeScalarFailure() => _fail(
    'JSON strings must contain paired Unicode scalar values and no Unicode '
    'noncharacters.',
  );

  void _parseNumber() {
    final tokenStart = _index;
    if (_consumeIf(0x2d) && _index >= source.length) _syntaxFailure();
    _ensureNumberLength(tokenStart);
    if (_consumeIf(0x30)) {
      _ensureNumberLength(tokenStart);
      if (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
        _syntaxFailure();
      }
    } else {
      _consumeDigits(requireOne: true, tokenStart: tokenStart);
    }
    if (_consumeIf(0x2e)) {
      _ensureNumberLength(tokenStart);
      _consumeDigits(requireOne: true, tokenStart: tokenStart);
    }
    if (_index < source.length &&
        (source.codeUnitAt(_index) == 0x65 ||
            source.codeUnitAt(_index) == 0x45)) {
      _index += 1;
      _ensureNumberLength(tokenStart);
      if (_index < source.length &&
          (source.codeUnitAt(_index) == 0x2b ||
              source.codeUnitAt(_index) == 0x2d)) {
        _index += 1;
        _ensureNumberLength(tokenStart);
      }
      _consumeDigits(requireOne: true, tokenStart: tokenStart);
    }
  }

  void _consumeDigits({required bool requireOne, required int tokenStart}) {
    final start = _index;
    while (_index < source.length && _isDigit(source.codeUnitAt(_index))) {
      _index += 1;
      _ensureNumberLength(tokenStart);
    }
    if (requireOne && start == _index) _syntaxFailure();
  }

  void _ensureNumberLength(int tokenStart) {
    if (_index - tokenStart > userPortableDataMaxNumberTokenChars) {
      _fail(
        'A JSON number exceeds the '
        '$userPortableDataMaxNumberTokenChars-character token limit.',
      );
    }
  }

  void _consumeLiteral(String literal) {
    if (_index + literal.length > source.length ||
        source.substring(_index, _index + literal.length) != literal) {
      _syntaxFailure();
    }
    _index += literal.length;
  }

  void _skipWhitespace() {
    while (_index < source.length) {
      final unit = source.codeUnitAt(_index);
      if (unit != 0x20 && unit != 0x0a && unit != 0x0d && unit != 0x09) {
        return;
      }
      _index += 1;
    }
  }

  void _expect(int unit) {
    if (!_consumeIf(unit)) _syntaxFailure();
  }

  bool _consumeIf(int unit) {
    if (_index >= source.length || source.codeUnitAt(_index) != unit) {
      return false;
    }
    _index += 1;
    return true;
  }

  static bool _isDigit(int unit) => unit >= 0x30 && unit <= 0x39;

  static bool _isHex(int unit) =>
      (unit >= 0x30 && unit <= 0x39) ||
      (unit >= 0x41 && unit <= 0x46) ||
      (unit >= 0x61 && unit <= 0x66);

  Never _syntaxFailure() => _fail(
    'The package is not valid JSON or exceeds a structural safety budget.',
  );

  Never _fail(String message) => throw _PortableJsonPreflightFailure(message);
}

class _PortableJsonPreflightFailure implements Exception {
  const _PortableJsonPreflightFailure(this.message);

  final String message;
}
