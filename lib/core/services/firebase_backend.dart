import 'package:firebase_core/firebase_core.dart';

import '../../firebase_options.dart';

class FirebaseBackend {
  static const backendMode = String.fromEnvironment(
    'PARKINSUM_BACKEND',
    defaultValue: 'local',
  );
  static const environment = String.fromEnvironment(
    'PARKINSUM_ENV',
    defaultValue: 'prod',
  );
  static const projectIdOverride = String.fromEnvironment(
    'PARKINSUM_FIREBASE_PROJECT_ID',
    defaultValue: '',
  );

  static bool get enabled => backendMode == 'firebase';

  static String get projectId {
    if (projectIdOverride.trim().isNotEmpty) {
      return projectIdOverride.trim();
    }
    return DefaultFirebaseOptions.projectIdForEnvironment(environment);
  }

  static Future<void> ensureInitialized() async {
    if (!enabled || Firebase.apps.isNotEmpty) return;
    final options = DefaultFirebaseOptions.currentPlatformForEnvironment(
      environment,
    );
    if (projectIdOverride.trim().isNotEmpty &&
        projectIdOverride.trim() != options.projectId) {
      throw UnsupportedError(
        'PARKINSUM_FIREBASE_PROJECT_ID=${projectIdOverride.trim()} does not '
        'match generated Firebase options projectId=${options.projectId}. '
        'Generate matching Firebase options before running this environment.',
      );
    }
    await Firebase.initializeApp(
      options: options,
    );
  }
}
