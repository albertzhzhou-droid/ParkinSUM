import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:parkinsum_companion/domain/entities/care_medication_discussion_entry.dart';
import 'package:parkinsum_companion/domain/entities/personal_observation.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_blood_pressure_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_blood_pressure_collection_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_personal_observation_collection_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_medication_statement_collection_mapper.dart';
import 'package:parkinsum_companion/domain/usecases/fhir_r4_symptom_motor_observation_mapper.dart';

const _validatorSha256 =
    '1106b9d58f9e363e47bea7c4fc065841e5fc91fe9d062775c3bfdd212bd653cc';

Future<void> main(List<String> arguments) async {
  final validatorPath =
      _argumentValue(arguments, '--validator=') ??
      Platform.environment['FHIR_VALIDATOR_JAR'];
  if (validatorPath == null || validatorPath.trim().isEmpty) {
    stderr.writeln(
      'Set FHIR_VALIDATOR_JAR to the verified HL7 validator_cli.jar (6.10.4).',
    );
    exitCode = 2;
    return;
  }
  final jar = File(validatorPath);
  if (!await jar.exists()) {
    stderr.writeln('FHIR validator jar was not found: $validatorPath');
    exitCode = 2;
    return;
  }
  final jarDigest = await sha256.bind(jar.openRead()).first;
  if (jarDigest.toString() != _validatorSha256) {
    stderr.writeln(
      'FHIR validator SHA-256 does not match the pinned official 6.10.4 release.',
    );
    exitCode = 2;
    return;
  }

  final outputDirectory = await Directory.systemTemp.createTemp(
    'parkinsum-fhir-r4-bp-',
  );
  try {
    final mapper = const FhirR4BloodPressureMapper();
    final fixtures = <String, PersonalObservation>{
      'recorded': _observation(
        id: 'bp-synthetic-recorded',
        status: PersonalObservationStatus.recorded,
        systolic: 120,
        diastolic: 80,
        posture: BloodPressurePosture.standing,
      ),
      'unknown': _observation(
        id: 'bp-synthetic-unknown',
        status: PersonalObservationStatus.unknown,
        posture: BloodPressurePosture.unknown,
      ),
      'not-measured': _observation(
        id: 'bp-synthetic-not-measured',
        status: PersonalObservationStatus.notMeasured,
        posture: BloodPressurePosture.unknown,
      ),
    };
    final paths = <String>[];
    for (final entry in fixtures.entries) {
      final path = '${outputDirectory.path}/${entry.key}.json';
      final resourceJson = const JsonEncoder.withIndent('  ').convert(
        mapper.fromObservation(
          entry.value,
          patientReference: 'Patient/synthetic-demo',
        ),
      );
      await File(path).writeAsString('$resourceJson\n');
      paths.add(path);
    }
    final collectionPath = '${outputDirectory.path}/collection.json';
    final collectionJson = const JsonEncoder.withIndent('  ').convert(
      const FhirR4BloodPressureCollectionMapper().fromObservations(
        fixtures.values,
        patientReference: 'Patient/synthetic-demo',
      ),
    );
    await File(collectionPath).writeAsString('$collectionJson\n');
    final corePaths = <String>[collectionPath];

    final java = Platform.environment['JAVA_BIN'] ?? 'java';
    final result = await Process.run(java, <String>[
      '-jar',
      jar.path,
      ...paths,
      '-version',
      FhirR4BloodPressureMapper.fhirVersion,
      '-profile',
      FhirR4BloodPressureMapper.bloodPressureProfile,
      '-tx',
      'n/a',
    ]);
    stdout.write(result.stdout);
    stderr.write(result.stderr);
    if (result.exitCode != 0) {
      stderr.writeln('HL7 FHIR validator exited with ${result.exitCode}.');
      exitCode = result.exitCode;
      return;
    }
    final output = '${result.stdout}\n${result.stderr}';
    final summaries = RegExp(r'Success: (\d+) errors').allMatches(output);
    if (summaries.length != fixtures.length ||
        summaries.any((match) => match.group(1) != '0')) {
      stderr.writeln(
        'Expected one zero-error FHIR R4 BP profile result for each of '
        '${fixtures.length} synthetic observations.',
      );
      exitCode = 1;
      return;
    }

    final personalMapper = const FhirR4SymptomMotorObservationMapper();
    final personalFixtures = <String, PersonalObservation>{
      'symptom-recorded': _symptomObservation(
        id: 'synthetic-symptom-recorded',
        status: PersonalObservationStatus.recorded,
        severity: 0,
      ),
      'symptom-unknown': _symptomObservation(
        id: 'synthetic-symptom-unknown',
        status: PersonalObservationStatus.unknown,
      ),
      'symptom-not-measured': _symptomObservation(
        id: 'synthetic-symptom-not-measured',
        status: PersonalObservationStatus.notMeasured,
      ),
      'motor-recorded': _motorObservation(
        id: 'synthetic-motor-recorded',
        status: PersonalObservationStatus.recorded,
        state: SelfReportedMotorState.off,
      ),
      'motor-unknown': _motorObservation(
        id: 'synthetic-motor-unknown',
        status: PersonalObservationStatus.unknown,
      ),
      'motor-not-measured': _motorObservation(
        id: 'synthetic-motor-not-measured',
        status: PersonalObservationStatus.notMeasured,
      ),
    };
    final personalPaths = <String>[];
    for (final entry in personalFixtures.entries) {
      final path = '${outputDirectory.path}/${entry.key}.json';
      final resourceJson = const JsonEncoder.withIndent('  ').convert(
        personalMapper.fromObservation(
          entry.value,
          patientReference: 'Patient/synthetic-demo',
        ),
      );
      await File(path).writeAsString('$resourceJson\n');
      personalPaths.add(path);
    }

    corePaths.addAll(personalPaths);

    final personalCollectionPath =
        '${outputDirectory.path}/personal-collection.json';
    final personalCollectionJson = const JsonEncoder.withIndent('  ').convert(
      const FhirR4SymptomMotorObservationCollectionMapper().fromObservations(
        personalFixtures.values,
        patientReference: 'Patient/synthetic-demo',
      ),
    );
    await File(
      personalCollectionPath,
    ).writeAsString('$personalCollectionJson\n');
    corePaths.add(personalCollectionPath);
    final combinedCollectionPath =
        '${outputDirectory.path}/combined-collection.json';
    final combinedCollectionJson = const JsonEncoder.withIndent('  ').convert(
      const FhirR4PersonalObservationCollectionMapper().fromObservations([
        ...fixtures.values,
        ...personalFixtures.values,
      ], patientReference: 'Patient/synthetic-demo'),
    );
    await File(
      combinedCollectionPath,
    ).writeAsString('$combinedCollectionJson\n');
    corePaths.add(combinedCollectionPath);

    final medicationEntry = CareMedicationDiscussionEntry(
      id: 'synthetic-medication-discussion-record',
      name: 'Synthetic medication discussion item',
      category: CareMedicationDiscussionCategory.supplement,
      reportedUse: CareMedicationReportedUse.uncertain,
      ingredientLabel: 'synthetic ingredient label',
      doseAndScheduleText: 'synthetic dose and schedule text',
      question: 'synthetic question',
      recordedAt: DateTime.utc(2026, 9, 23, 12),
      recorderId: 'synthetic-user',
    );
    const medicationMapper = FhirR4MedicationStatementCollectionMapper();
    final medicationJson = const JsonEncoder.withIndent('  ').convert(
      medicationMapper.fromEntries(
        [medicationEntry],
        patientReference: 'Patient/synthetic-demo',
        ownerId: 'synthetic-user',
      ),
    );
    final medicationPath = '${outputDirectory.path}/medication-statement.json';
    await File(medicationPath).writeAsString('$medicationJson\n');
    corePaths.add(medicationPath);

    final medicationCollectionJson = const JsonEncoder.withIndent('  ').convert(
      medicationMapper.fromEntries(
        [medicationEntry],
        patientReference: 'Patient/synthetic-demo',
        ownerId: 'synthetic-user',
      ),
    );
    final medicationCollectionPath =
        '${outputDirectory.path}/medication-collection.json';
    await File(
      medicationCollectionPath,
    ).writeAsString('$medicationCollectionJson\n');
    corePaths.add(medicationCollectionPath);

    // Validate the remaining fixed resources together so the CLI loads its
    // FHIR package set only once for all core R4 checks.
    final coreResult = await Process.run(java, <String>[
      '-jar',
      jar.path,
      ...corePaths,
      '-version',
      FhirR4SymptomMotorObservationMapper.fhirVersion,
      '-tx',
      'n/a',
    ]);
    stdout.write(coreResult.stdout);
    stderr.write(coreResult.stderr);
    if (coreResult.exitCode != 0) {
      stderr.writeln('HL7 FHIR validator failed for core R4 resources.');
      exitCode = coreResult.exitCode;
      return;
    }
    final coreOutput = '${coreResult.stdout}\n${coreResult.stderr}';
    final coreSummaries = RegExp(
      r'Success: (\d+) errors',
    ).allMatches(coreOutput);
    if (corePaths.length != 11 ||
        coreSummaries.length != corePaths.length ||
        coreSummaries.any((match) => match.group(1) != '0')) {
      stderr.writeln(
        'Expected eleven zero-error FHIR R4 core results for the BP collection, six symptom/motor observations, their collection, the combined collection, and the medication statement plus collection.',
      );
      exitCode = 1;
    }
  } finally {
    await outputDirectory.delete(recursive: true);
  }
}

String? _argumentValue(List<String> arguments, String prefix) {
  for (final argument in arguments) {
    if (argument.startsWith(prefix)) return argument.substring(prefix.length);
  }
  return null;
}

PersonalObservation _observation({
  required String id,
  required PersonalObservationStatus status,
  required BloodPressurePosture posture,
  double? systolic,
  double? diastolic,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.bloodPressure,
  occurredAt: DateTime.parse('2026-09-20T12:00:00-04:00'),
  recordedAt: DateTime.parse('2026-09-20T12:05:00-04:00'),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: 'synthetic-user',
  status: status,
  systolic: systolic,
  diastolic: diastolic,
  unit: PersonalObservation.bloodPressureUnit,
  posture: posture,
);

PersonalObservation _symptomObservation({
  required String id,
  required PersonalObservationStatus status,
  int? severity,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.symptom,
  occurredAt: DateTime.parse('2026-09-20T12:00:00-04:00'),
  recordedAt: DateTime.parse('2026-09-20T12:05:00-04:00'),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: 'synthetic-user',
  status: status,
  symptomLabel: 'Synthetic stiffness',
  severity: status == PersonalObservationStatus.recorded ? severity : null,
);

PersonalObservation _motorObservation({
  required String id,
  required PersonalObservationStatus status,
  SelfReportedMotorState state = SelfReportedMotorState.uncertain,
}) => PersonalObservation.create(
  id: id,
  kind: PersonalObservationKind.selfReportedMotorState,
  occurredAt: DateTime.parse('2026-09-20T12:00:00-04:00'),
  recordedAt: DateTime.parse('2026-09-20T12:05:00-04:00'),
  originalTimezone: 'America/Toronto',
  source: PersonalObservationSource.selfReported,
  recorderId: 'synthetic-user',
  status: status,
  motorState: status == PersonalObservationStatus.recorded ? state : null,
);
