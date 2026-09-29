import 'dart:io';

import 'package:integration_test/integration_test_driver.dart';

import '../tool/android_reminder_integration_report_support.dart';

Future<void> main() async {
  late final String runId;
  try {
    runId = requireValidAndroidReminderRunId(
      Platform.environment[androidReminderRunIdEnvironmentName],
    );
  } on FormatException catch (error) {
    stderr.writeln(error.message);
    exitCode = 64;
    return;
  }

  await integrationDriver(
    responseDataCallback: (data) async {
      if (data != null) {
        if (data['schema_uri'] != androidReminderIntegrationReportSchemaUri ||
            data['schema_version'] !=
                androidReminderIntegrationReportSchemaVersion) {
          throw StateError(
            'Android reminder integration response used an unsupported schema.',
          );
        }
        if (data['run_id'] != runId) {
          throw StateError(
            'Android reminder integration response run_id did not match the '
            'host run id.',
          );
        }
      }

      await writeResponseData(
        data,
        testOutputFilename: 'report_data',
        destinationDirectory: 'build/android_reminder_attestation/$runId',
      );
    },
    writeResponseOnFailure: true,
  );
}
