import 'dart:convert';

import 'package:crypto/crypto.dart';

const portableSchemaMigrationRegistrySchema =
    'parkinsum.portable-schema-migration-registry/1';
const portableSchemaMigrationRegistrySchemaVersion = 1;
const portableSchemaMigrationReceiptSchema =
    'parkinsum.portable-schema-migration-receipt/1';
const portableSchemaMigrationCrossRuntimeVectorsSchema =
    'parkinsum.portable-schema-migration-cross-runtime-vectors/1';
const portableSchemaMigrationCrossRuntimeVectorsSchemaVersion = 1;
const portableSchemaMigrationCrossRuntimeConformanceSchema =
    'parkinsum.portable-schema-migration-cross-runtime-conformance/1';
const portableSchemaMigrationCrossRuntimeConformanceSchemaVersion = 1;
const portableSchemaDifferentialFuzzPlanSchema =
    'parkinsum.portable-schema-differential-fuzz-plan/1';
const portableSchemaDifferentialFuzzPlanSchemaVersion = 1;
const portableSchemaFuzzRegressionCorpusSchema =
    'parkinsum.portable-schema-fuzz-regression-corpus/1';
const portableSchemaFuzzRegressionCorpusSchemaVersion = 1;
const portableSchemaDifferentialFuzzReportSchema =
    'parkinsum.portable-schema-differential-fuzz-report/1';
const portableSchemaDifferentialFuzzReportSchemaVersion = 1;
const portableSchemaDifferentialFuzzConformanceSchema =
    'parkinsum.portable-schema-differential-fuzz-conformance/1';
const portableSchemaDifferentialFuzzConformanceSchemaVersion = 1;

/// User-visible, non-personal summary of the frozen local fuzz campaign.
///
/// The tracked plan and corpus are independently checked by the Dart/Node
/// gate. These constants intentionally expose scope and limits in the app;
/// they are not a runtime claim that a campaign has just executed.
class PortableSchemaFuzzCampaignSummary {
  const PortableSchemaFuzzCampaignSummary._();

  static const generatorVersion = 1;
  static const fixedSeedCount = 3;
  static const lexicalAndSemanticPartitionCount = 14;
  static const retainedSyntheticCaseCount = 31;
  static const independentRuntimeCount = 2;
  static const runtimeLabel = 'Dart production preview + independent Node';
  static const boundary =
      'Frozen synthetic regression scope only; browser, Android, iOS and '
      'desktop release-artifact parsers, coverage guidance, exploratory '
      'campaigns and durable import remain unverified.';
}

/// A frozen identity for one readable portable-package schema.
///
/// [structuralContract] is the exact envelope and version-specific field
/// projection enforced before the larger package semantic validator runs.
/// [semanticPolicy] names the cross-field rules whose meaning is intentionally
/// pinned for this historical version. Neither document is advertised as a
/// complete JSON Schema implementation.
class PortableSchemaValidatorDescriptor {
  const PortableSchemaValidatorDescriptor({
    required this.version,
    required this.schemaUri,
    required this.validatorVersion,
    required this.structuralContract,
    required this.semanticPolicy,
  });

  final int version;
  final String schemaUri;
  final int validatorVersion;
  final Map<String, Object?> structuralContract;
  final Map<String, Object?> semanticPolicy;

  String get structuralContractSha256 =>
      portableCanonicalSha256(structuralContract);

  String get semanticPolicySha256 => portableCanonicalSha256(semanticPolicy);

  String get validatorIdentity => portableSha256(
    'parkinsum-portable-validator-v1|$version|$schemaUri|$validatorVersion|'
    '$structuralContractSha256|$semanticPolicySha256',
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'schemaUri': schemaUri,
    'validatorVersion': validatorVersion,
    'structuralContractSha256': structuralContractSha256,
    'semanticPolicySha256': semanticPolicySha256,
    'validatorIdentity': validatorIdentity,
  };
}

class PortableSchemaSemanticDiff {
  const PortableSchemaSemanticDiff({
    required this.path,
    required this.operation,
    required this.sourceMeaning,
    required this.targetMeaning,
    required this.lossClassification,
  });

  final String path;
  final String operation;
  final String sourceMeaning;
  final String targetMeaning;
  final String lossClassification;

  Map<String, Object?> toJson() => <String, Object?>{
    'path': path,
    'operation': operation,
    'sourceMeaning': sourceMeaning,
    'targetMeaning': targetMeaning,
    'lossClassification': lossClassification,
  };
}

class PortableSchemaMigrationDescriptor {
  const PortableSchemaMigrationDescriptor({
    required this.migrationId,
    required this.migrationVersion,
    required this.sourceVersion,
    required this.targetVersion,
    required this.semanticDiff,
    required this.invariants,
  });

  final String migrationId;
  final int migrationVersion;
  final int sourceVersion;
  final int targetVersion;
  final List<PortableSchemaSemanticDiff> semanticDiff;
  final List<String> invariants;

  String get semanticDiffSha256 => portableCanonicalSha256(<String, Object?>{
    'semanticDiff': semanticDiff.map((entry) => entry.toJson()).toList(),
    'invariants': invariants,
  });

  String get migrationIdentity => portableSha256(
    'parkinsum-portable-migration-v1|$migrationId|$migrationVersion|'
    '$sourceVersion|$targetVersion|$semanticDiffSha256',
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'migrationId': migrationId,
    'migrationVersion': migrationVersion,
    'sourceVersion': sourceVersion,
    'targetVersion': targetVersion,
    'semanticDiffSha256': semanticDiffSha256,
    'migrationIdentity': migrationIdentity,
    'semanticDiff': semanticDiff.map((entry) => entry.toJson()).toList(),
    'invariants': invariants,
  };
}

/// Privacy-bounded evidence for a validation or preview-only migration.
///
/// It contains digests and policy identities, never portable record values,
/// labels, account identifiers, package ids, or reminder copy.
class PortableSchemaMigrationReceipt {
  const PortableSchemaMigrationReceipt({
    required this.sourceVersion,
    required this.targetVersion,
    required this.sourceBytesSha256,
    required this.sourceCanonicalSha256,
    required this.outputCanonicalSha256,
    required this.sourceValidatorIdentity,
    required this.targetValidatorIdentity,
    required this.migrationIdentity,
    required this.semanticDiffSha256,
    required this.decision,
    required this.warnings,
    required this.heldFields,
    required this.receiptSha256,
  });

  final int sourceVersion;
  final int targetVersion;
  final String sourceBytesSha256;
  final String sourceCanonicalSha256;
  final String outputCanonicalSha256;
  final String sourceValidatorIdentity;
  final String targetValidatorIdentity;
  final String migrationIdentity;
  final String semanticDiffSha256;
  final String decision;
  final List<String> warnings;
  final List<String> heldFields;
  final String receiptSha256;

  Map<String, Object?> toJson({bool includeDigest = true}) => <String, Object?>{
    'schema': portableSchemaMigrationReceiptSchema,
    'sourceVersion': sourceVersion,
    'targetVersion': targetVersion,
    'sourceBytesSha256': sourceBytesSha256,
    'sourceCanonicalSha256': sourceCanonicalSha256,
    'outputCanonicalSha256': outputCanonicalSha256,
    'sourceValidatorIdentity': sourceValidatorIdentity,
    'targetValidatorIdentity': targetValidatorIdentity,
    'migrationIdentity': migrationIdentity,
    'semanticDiffSha256': semanticDiffSha256,
    'decision': decision,
    'warnings': warnings,
    'heldFields': heldFields,
    if (includeDigest) 'receiptSha256': receiptSha256,
  };

  factory PortableSchemaMigrationReceipt.fromJson(Map<String, Object?> json) {
    if (json['schema'] != portableSchemaMigrationReceiptSchema ||
        json['sourceVersion'] is! int ||
        json['targetVersion'] is! int ||
        json['sourceBytesSha256'] is! String ||
        json['sourceCanonicalSha256'] is! String ||
        json['outputCanonicalSha256'] is! String ||
        json['sourceValidatorIdentity'] is! String ||
        json['targetValidatorIdentity'] is! String ||
        json['migrationIdentity'] is! String ||
        json['semanticDiffSha256'] is! String ||
        json['decision'] is! String ||
        json['warnings'] is! List ||
        json['heldFields'] is! List ||
        json['receiptSha256'] is! String) {
      throw const FormatException('Portable migration receipt is malformed.');
    }
    final receipt = PortableSchemaMigrationReceipt(
      sourceVersion: json['sourceVersion'] as int,
      targetVersion: json['targetVersion'] as int,
      sourceBytesSha256: json['sourceBytesSha256'] as String,
      sourceCanonicalSha256: json['sourceCanonicalSha256'] as String,
      outputCanonicalSha256: json['outputCanonicalSha256'] as String,
      sourceValidatorIdentity: json['sourceValidatorIdentity'] as String,
      targetValidatorIdentity: json['targetValidatorIdentity'] as String,
      migrationIdentity: json['migrationIdentity'] as String,
      semanticDiffSha256: json['semanticDiffSha256'] as String,
      decision: json['decision'] as String,
      warnings: (json['warnings'] as List).cast<String>(),
      heldFields: (json['heldFields'] as List).cast<String>(),
      receiptSha256: json['receiptSha256'] as String,
    );
    if (portableCanonicalSha256(receipt.toJson(includeDigest: false)) !=
        receipt.receiptSha256) {
      throw const FormatException('Portable migration receipt digest drift.');
    }
    return receipt;
  }
}

class PortableSchemaMigrationAssessment {
  const PortableSchemaMigrationAssessment({
    required this.accepted,
    required this.findings,
    required this.sourceValidator,
    required this.targetValidator,
    required this.migration,
    required this.outputDocument,
    required this.receipt,
  });

  final bool accepted;
  final List<String> findings;
  final PortableSchemaValidatorDescriptor? sourceValidator;
  final PortableSchemaValidatorDescriptor? targetValidator;
  final PortableSchemaMigrationDescriptor? migration;
  final Map<String, Object?>? outputDocument;
  final PortableSchemaMigrationReceipt? receipt;
}

String portableSha256(String value) =>
    sha256.convert(utf8.encode(value)).toString();

String portableCanonicalJson(Object? value) =>
    jsonEncode(_portableSortJson(value));

String portableCanonicalSha256(Object? value) =>
    portableSha256(portableCanonicalJson(value));

Object? _portableSortJson(Object? value) {
  if (value is Map) {
    final keys = value.keys.cast<String>().toList()..sort();
    return <String, Object?>{
      for (final key in keys) key: _portableSortJson(value[key]),
    };
  }
  if (value is List) {
    return <Object?>[for (final item in value) _portableSortJson(item)];
  }
  return value;
}
