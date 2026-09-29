import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/reminder_notification_run_attestation.dart';

const androidReminderAttestationPathEnvironmentName =
    'PARKINSUM_ANDROID_REMINDER_ATTESTATION_PATH';
const androidReminderAttestationValidationSentinel =
    'PARKINSUM_ANDROID_REMINDER_ATTESTATION_VALIDATION:';

void main() {
  test('strictly validates one Android reminder run attestation', () async {
    final attestationPath =
        Platform.environment[androidReminderAttestationPathEnvironmentName];
    if (attestationPath == null || attestationPath.trim().isEmpty) {
      throw StateError(
        '$androidReminderAttestationPathEnvironmentName is required',
      );
    }
    final decoded = jsonDecode(await File(attestationPath).readAsString());
    if (decoded is! Map) {
      throw const FormatException('attestation root must be a JSON object');
    }
    final attestation = ReminderNotificationRunAttestation.fromJson(
      Map<String, Object?>.from(decoded),
    );
    final executionIsolationBound =
        attestation.executionIsolation.resources.length == 2 &&
        attestation.executionIsolation.checkpoints.length ==
            ReminderNotificationRunExecutionIsolation
                .requiredCheckpoints
                .length &&
        attestation.executionIsolation.continuousOwnershipVerified &&
        attestation.executionIsolation.childrenDrainedBeforeDeviceCleanup &&
        attestation.executionIsolation.deviceCleanupCompletedWhileOwned;
    stdout.writeln(
      '$androidReminderAttestationValidationSentinel${jsonEncode({'pass': attestation.pass, 'run_id': attestation.runId, 'content_sha256': attestation.contentSha256, 'integration_report_data_sha256': attestation.integration.reportDataSha256, 'application_id': attestation.artifact.applicationId, 'certificate_sha256': attestation.artifact.signing.certificateSha256, 'signer_identity_assurance': attestation.artifact.signing.identityAssurance.name, 'execution_isolation_bound': executionIsolationBound, 'visible_delivery_verified': attestation.claims.visibleDeliveryVerified, 'release_eligible': attestation.releaseEligible})}',
    );
  });
}
