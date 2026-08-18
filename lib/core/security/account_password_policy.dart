/// Client-side password guidance for ParkinSUM's single-factor email account.
///
/// The identity provider remains authoritative. This policy intentionally uses
/// length rather than character-class composition rules, accepts whitespace and
/// Unicode, and counts Unicode code points instead of UTF-16 code units.
class AccountPasswordPolicy {
  const AccountPasswordPolicy._();

  static const int minimumLength = 15;

  static List<AccountPasswordIssue> validateChange({
    required String currentPassword,
    required String newPassword,
    required String confirmation,
  }) {
    final issues = <AccountPasswordIssue>[];
    if (currentPassword.isEmpty) {
      issues.add(AccountPasswordIssue.currentPasswordRequired);
    }
    if (newPassword.runes.length < minimumLength) {
      issues.add(AccountPasswordIssue.newPasswordTooShort);
    }
    if (newPassword == currentPassword && newPassword.isNotEmpty) {
      issues.add(AccountPasswordIssue.newPasswordMustDiffer);
    }
    if (newPassword != confirmation) {
      issues.add(AccountPasswordIssue.confirmationMismatch);
    }
    return List<AccountPasswordIssue>.unmodifiable(issues);
  }
}

enum AccountPasswordIssue {
  currentPasswordRequired,
  newPasswordTooShort,
  newPasswordMustDiffer,
  confirmationMismatch,
}
