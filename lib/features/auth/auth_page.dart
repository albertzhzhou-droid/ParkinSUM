import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/i18n/app_i18n_context.dart';
import '../../core/security/account_password_policy.dart';
import '../../core/state/app_state.dart';
import '../legal/privacy_disclaimer_page.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegisterMode = false;
  bool _isSendingReset = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = context.read<AppState>();
    if (_isRegisterMode) {
      await state.registerWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    } else {
      await state.signInWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
      );
    }
    if (mounted && context.read<AppState>().authError == null) {
      TextInput.finishAutofillContext(shouldSave: true);
    }
  }

  Future<void> _sendPasswordReset() async {
    final email = _emailController.text.trim();
    if (!email.contains('@') || _isSendingReset) return;
    setState(() => _isSendingReset = true);
    try {
      await context.read<AppState>().sendPasswordResetEmail(email);
    } catch (_) {
      // Deliberately use the same response for existing and unknown accounts.
    } finally {
      if (mounted) setState(() => _isSendingReset = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.appI18n.tr('auth.reset_neutral'))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final i18n = context.appI18n;
    return Scaffold(
      appBar: AppBar(title: Text(i18n.tr('auth.account_title'))),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: AutofillGroup(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            i18n.tr(
                              _isRegisterMode
                                  ? 'auth.create_account'
                                  : 'auth.sign_in',
                            ),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            key: const ValueKey('auth-email'),
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [
                              AutofillHints.username,
                              AutofillHints.email,
                            ],
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: i18n.tr('auth.email'),
                              prefixIcon: const Icon(Icons.mail_outline),
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (!email.contains('@')) {
                                return i18n.tr('auth.invalid_email');
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            key: const ValueKey('auth-password'),
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            enableSuggestions: false,
                            autocorrect: false,
                            autofillHints: [
                              _isRegisterMode
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: i18n.tr('auth.password'),
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                key: const ValueKey('auth-password-visibility'),
                                tooltip: i18n.tr(
                                  _obscurePassword
                                      ? 'auth.show_password'
                                      : 'auth.hide_password',
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final password = value ?? '';
                              if (password.isEmpty) {
                                return i18n.tr('auth.password_required');
                              }
                              if (_isRegisterMode &&
                                  password.runes.length <
                                      AccountPasswordPolicy.minimumLength) {
                                return i18n.tr(
                                  'auth.password_registration_requirement',
                                  {
                                    'minimum':
                                        '${AccountPasswordPolicy.minimumLength}',
                                  },
                                );
                              }
                              return null;
                            },
                            onFieldSubmitted: (_) => _submit(),
                          ),
                          if (state.authError case final error?) ...[
                            const SizedBox(height: 12),
                            Semantics(
                              liveRegion: true,
                              child: Text(
                                error,
                                key: const ValueKey('auth-error'),
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            key: const ValueKey('auth-submit'),
                            onPressed: state.isAuthBusy ? null : _submit,
                            icon: state.isAuthBusy
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _isRegisterMode
                                        ? Icons.person_add_alt
                                        : Icons.login,
                                  ),
                            label: Text(
                              i18n.tr(
                                _isRegisterMode
                                    ? 'auth.register'
                                    : 'auth.sign_in',
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            key: const ValueKey('auth-mode-toggle'),
                            onPressed: state.isAuthBusy
                                ? null
                                : () => setState(() {
                                    _isRegisterMode = !_isRegisterMode;
                                  }),
                            child: Text(
                              i18n.tr(
                                _isRegisterMode
                                    ? 'auth.have_account'
                                    : 'auth.need_account',
                              ),
                            ),
                          ),
                          if (!_isRegisterMode)
                            TextButton.icon(
                              onPressed: state.isAuthBusy || _isSendingReset
                                  ? null
                                  : _sendPasswordReset,
                              icon: _isSendingReset
                                  ? const SizedBox.square(
                                      dimension: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.mark_email_read_outlined),
                              label: Text(i18n.tr('auth.forgot_password')),
                            ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const PrivacyDisclaimerPage(),
                              ),
                            ),
                            icon: const Icon(Icons.privacy_tip_outlined),
                            label: Text(i18n.tr('auth.privacy')),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
