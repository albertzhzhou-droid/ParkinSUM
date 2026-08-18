import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/security/account_password_policy.dart';

void main() {
  test('accepts long passphrases without composition rules', () {
    final issues = AccountPasswordPolicy.validateChange(
      currentPassword: 'previous value',
      newPassword: 'a gentle long phrase',
      confirmation: 'a gentle long phrase',
    );

    expect(issues, isEmpty);
  });

  test('counts Unicode code points rather than UTF-16 code units', () {
    final password = List<String>.filled(15, '界').join();

    expect(
      AccountPasswordPolicy.validateChange(
        currentPassword: 'previous value',
        newPassword: password,
        confirmation: password,
      ),
      isEmpty,
    );
  });

  test('reports every actionable change issue', () {
    final issues = AccountPasswordPolicy.validateChange(
      currentPassword: '',
      newPassword: 'short',
      confirmation: 'different',
    );

    expect(
      issues,
      containsAll(<AccountPasswordIssue>[
        AccountPasswordIssue.currentPasswordRequired,
        AccountPasswordIssue.newPasswordTooShort,
        AccountPasswordIssue.confirmationMismatch,
      ]),
    );
  });

  test('rejects reusing the current password', () {
    const password = 'same password phrase';

    expect(
      AccountPasswordPolicy.validateChange(
        currentPassword: password,
        newPassword: password,
        confirmation: password,
      ),
      contains(AccountPasswordIssue.newPasswordMustDiffer),
    );
  });
}
