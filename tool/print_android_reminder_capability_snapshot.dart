import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/reminder_notification_capability_matrix.dart';

const androidReminderCapabilitySnapshotSentinel =
    'PARKINSUM_ANDROID_REMINDER_CAPABILITY_SNAPSHOT:';

void main() {
  test('prints the current Android reminder capability identity', () {
    final matrix = ReminderNotificationCapabilityMatrix.current;
    final profile = matrix.profileFor(ReminderNotificationPlatform.android);
    stdout.writeln(
      '$androidReminderCapabilitySnapshotSentinel${jsonEncode({'schema': ReminderNotificationCapabilityMatrix.schema, 'schema_version': ReminderNotificationCapabilityMatrix.schemaVersion, 'manifest_sha256': matrix.manifestSha256, 'profile_sha256': profile.contentSha256, 'platform': profile.platform.name, 'delivery_mode': profile.deliveryMode.name})}',
    );
  });
}
