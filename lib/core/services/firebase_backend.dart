import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

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
  static const appCheckEnabled = bool.fromEnvironment(
    'PARKINSUM_FIREBASE_APP_CHECK',
    defaultValue: false,
  );
  static const appCheckDebug = bool.fromEnvironment(
    'PARKINSUM_FIREBASE_APP_CHECK_DEBUG',
    defaultValue: false,
  );
  static const recaptchaSiteKey = String.fromEnvironment(
    'PARKINSUM_RECAPTCHA_SITE_KEY',
    defaultValue: '',
  );
  static const recaptchaEnterpriseSiteKey = String.fromEnvironment(
    'PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY',
    defaultValue: '',
  );

  static bool _appCheckActivated = false;

  static bool get enabled => backendMode == 'firebase';

  static String get projectId {
    if (projectIdOverride.trim().isNotEmpty) {
      return projectIdOverride.trim();
    }
    return DefaultFirebaseOptions.projectIdForEnvironment(environment);
  }

  static Future<void> ensureInitialized() async {
    if (!enabled) return;
    if (Firebase.apps.isEmpty) {
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
    await _ensureAppCheckActivated();
  }

  static Future<void> _ensureAppCheckActivated() async {
    if (!appCheckEnabled || _appCheckActivated) return;

    final webSiteKey = recaptchaSiteKey.trim();
    final enterpriseSiteKey = recaptchaEnterpriseSiteKey.trim();
    if (kIsWeb &&
        !appCheckDebug &&
        webSiteKey.isEmpty &&
        enterpriseSiteKey.isEmpty) {
      throw UnsupportedError(
        'PARKINSUM_FIREBASE_APP_CHECK=true on web requires '
        'PARKINSUM_RECAPTCHA_SITE_KEY or '
        'PARKINSUM_RECAPTCHA_ENTERPRISE_SITE_KEY.',
      );
    }

    await FirebaseAppCheck.instance.activate(
      providerWeb: kIsWeb
          ? appCheckDebug
              ? WebDebugProvider()
              : enterpriseSiteKey.isNotEmpty
                  ? ReCaptchaEnterpriseProvider(enterpriseSiteKey)
                  : ReCaptchaV3Provider(webSiteKey)
          : null,
      providerAndroid: appCheckDebug
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: appCheckDebug
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
    _appCheckActivated = true;
  }
}
