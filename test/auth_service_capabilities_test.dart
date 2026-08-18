import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/services/auth_service.dart';

void main() {
  test(
    'local mode declares verified identity without pretending email flows',
    () async {
      final auth = LocalAuthService();
      final uid = await auth.ensureUser();

      expect(uid, 'local_user');
      expect(auth.currentUserEmailVerified, isTrue);
      expect(auth.currentUserProviderIds, const <String>['local']);
      final user = await auth.reloadCurrentUser();
      expect(user?.emailVerified, isTrue);
      expect(user?.providerIds, const <String>['local']);
      await expectLater(
        auth.sendPasswordResetEmail(
          email: 'person@example.com',
          languageCode: 'en-US',
        ),
        throwsUnsupportedError,
      );
      await expectLater(
        auth.sendEmailVerification(languageCode: 'en-US'),
        throwsUnsupportedError,
      );
      await expectLater(
        auth.reauthenticateAndChangePassword(
          currentPassword: 'old password',
          newPassword: 'new password',
        ),
        throwsUnsupportedError,
      );
    },
  );
}
