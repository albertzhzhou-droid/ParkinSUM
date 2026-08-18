import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/i18n/app_i18n.dart';
import '../../core/security/account_password_policy.dart';
import '../../core/services/auth_service.dart';

class ChangePasswordDialog extends StatefulWidget {
  const ChangePasswordDialog({
    super.key,
    required this.i18n,
    required this.onChangePassword,
  });

  final AppI18n i18n;
  final Future<void> Function(String currentPassword, String newPassword)
  onChangePassword;

  @override
  State<ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<ChangePasswordDialog> {
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmationController = TextEditingController();
  Set<AccountPasswordIssue> _issues = const <AccountPasswordIssue>{};
  String? _serviceError;
  bool _obscure = true;
  bool _submitting = false;

  AppI18n get i18n => widget.i18n;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const ValueKey('change-password-dialog'),
      title: Text(i18n.tr('settings.change_password_title')),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: AutofillGroup(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(i18n.tr('settings.password_requirement')),
                const SizedBox(height: 16),
                _passwordField(
                  key: const ValueKey('current-password-field'),
                  controller: _currentController,
                  label: i18n.tr('settings.current_password'),
                  autofillHints: const <String>[AutofillHints.password],
                  textInputAction: TextInputAction.next,
                  errorText:
                      _issues.contains(
                        AccountPasswordIssue.currentPasswordRequired,
                      )
                      ? i18n.tr('settings.password_current_required')
                      : null,
                ),
                const SizedBox(height: 12),
                _passwordField(
                  key: const ValueKey('new-password-field'),
                  controller: _newController,
                  label: i18n.tr('settings.new_password'),
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.next,
                  errorText: _newPasswordError(),
                ),
                const SizedBox(height: 12),
                _passwordField(
                  key: const ValueKey('confirm-password-field'),
                  controller: _confirmationController,
                  label: i18n.tr('settings.confirm_password'),
                  autofillHints: const <String>[AutofillHints.newPassword],
                  textInputAction: TextInputAction.done,
                  errorText:
                      _issues.contains(
                        AccountPasswordIssue.confirmationMismatch,
                      )
                      ? i18n.tr('settings.password_confirmation_mismatch')
                      : null,
                  onSubmitted: _submitting ? null : (_) => _submit(),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  key: const ValueKey('toggle-password-visibility'),
                  onPressed: _submitting
                      ? null
                      : () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure ? Icons.visibility_outlined : Icons.visibility_off,
                  ),
                  label: Text(
                    i18n.tr(
                      _obscure
                          ? 'settings.show_passwords'
                          : 'settings.hide_passwords',
                    ),
                  ),
                ),
                if (_serviceError case final error?) ...[
                  const SizedBox(height: 8),
                  Semantics(
                    liveRegion: true,
                    child: Material(
                      color: Theme.of(
                        context,
                      ).colorScheme.errorContainer.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          error,
                          key: const ValueKey('change-password-service-error'),
                          style: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: Text(i18n.tr('common.cancel')),
        ),
        FilledButton.icon(
          key: const ValueKey('change-password-submit'),
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_reset_outlined),
          label: Text(i18n.tr('settings.change_password')),
        ),
      ],
    );
  }

  Widget _passwordField({
    required Key key,
    required TextEditingController controller,
    required String label,
    required Iterable<String> autofillHints,
    required TextInputAction textInputAction,
    String? errorText,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextField(
      key: key,
      controller: controller,
      obscureText: _obscure,
      enableSuggestions: false,
      autocorrect: false,
      autofillHints: autofillHints,
      textInputAction: textInputAction,
      onChanged: (_) {
        if (_issues.isEmpty && _serviceError == null) return;
        setState(() {
          _issues = const <AccountPasswordIssue>{};
          _serviceError = null;
        });
      },
      onSubmitted: onSubmitted,
      decoration: InputDecoration(labelText: label, errorText: errorText),
    );
  }

  String? _newPasswordError() {
    if (_issues.contains(AccountPasswordIssue.newPasswordTooShort)) {
      return i18n.tr('settings.password_too_short', {
        'minimum': '${AccountPasswordPolicy.minimumLength}',
      });
    }
    if (_issues.contains(AccountPasswordIssue.newPasswordMustDiffer)) {
      return i18n.tr('settings.password_must_differ');
    }
    return null;
  }

  Future<void> _submit() async {
    final issues = AccountPasswordPolicy.validateChange(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
      confirmation: _confirmationController.text,
    );
    if (issues.isNotEmpty) {
      setState(() {
        _issues = issues.toSet();
        _serviceError = null;
      });
      return;
    }
    setState(() {
      _submitting = true;
      _serviceError = null;
    });
    try {
      await widget.onChangePassword(
        _currentController.text,
        _newController.text,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext();
      Navigator.of(context).pop(true);
    } on AccountSecurityException catch (error) {
      if (!mounted) return;
      setState(() => _serviceError = _failureMessage(error.failure));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _serviceError = i18n.tr('settings.password_error_unknown'),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _failureMessage(AccountSecurityFailure failure) {
    final key = switch (failure) {
      AccountSecurityFailure.wrongCurrentPassword =>
        'settings.password_error_wrong_current',
      AccountSecurityFailure.weakNewPassword => 'settings.password_error_weak',
      AccountSecurityFailure.tooManyAttempts =>
        'settings.password_error_too_many',
      AccountSecurityFailure.recentLoginExpired =>
        'settings.password_error_recent_login',
      AccountSecurityFailure.serviceUnavailable =>
        'settings.password_error_service',
      AccountSecurityFailure.passwordProviderUnavailable =>
        'settings.password_provider_unavailable',
      AccountSecurityFailure.notSignedIn =>
        'settings.password_error_not_signed_in',
      AccountSecurityFailure.unknown => 'settings.password_error_unknown',
    };
    return i18n.tr(key);
  }
}
