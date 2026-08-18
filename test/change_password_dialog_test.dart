import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parkinsum_companion/core/i18n/app_i18n.dart';
import 'package:parkinsum_companion/core/services/auth_service.dart';
import 'package:parkinsum_companion/features/settings/change_password_dialog.dart';

void main() {
  testWidgets('blocks a short new password before calling the provider', (
    tester,
  ) async {
    var calls = 0;
    await _openDialog(tester, (_, _) async => calls += 1);

    await tester.enterText(
      find.byKey(const ValueKey('current-password-field')),
      'current password',
    );
    await tester.enterText(
      find.byKey(const ValueKey('new-password-field')),
      'short',
    );
    await tester.enterText(
      find.byKey(const ValueKey('confirm-password-field')),
      'short',
    );
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pump();

    expect(calls, 0);
    expect(
      find.text('The new password needs at least 15 characters.'),
      findsOne,
    );
  });

  testWidgets('submits a valid passphrase and closes after success', (
    tester,
  ) async {
    String? receivedCurrent;
    String? receivedNew;
    await _openDialog(tester, (current, next) async {
      receivedCurrent = current;
      receivedNew = next;
    });

    await _enterValidPasswords(tester);
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();

    expect(receivedCurrent, 'existing account password');
    expect(receivedNew, 'a new gentle passphrase');
    expect(find.byKey(const ValueKey('change-password-dialog')), findsNothing);
  });

  testWidgets('maps provider failures to safe actionable copy', (tester) async {
    await _openDialog(tester, (_, _) async {
      throw const AccountSecurityException(
        AccountSecurityFailure.wrongCurrentPassword,
      );
    });

    await _enterValidPasswords(tester);
    await tester.tap(find.byKey(const ValueKey('change-password-submit')));
    await tester.pumpAndSettle();

    expect(
      find.text('The current password is incorrect. Try again.'),
      findsOne,
    );
    expect(find.textContaining('invalid-credential'), findsNothing);
    expect(find.byKey(const ValueKey('change-password-dialog')), findsOne);
  });
}

Future<void> _openDialog(
  WidgetTester tester,
  Future<void> Function(String, String) onChange,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: FilledButton(
            onPressed: () => showDialog<bool>(
              context: context,
              builder: (_) => ChangePasswordDialog(
                i18n: AppI18n.fromLocaleTag('en-US'),
                onChangePassword: onChange,
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}

Future<void> _enterValidPasswords(WidgetTester tester) async {
  await tester.enterText(
    find.byKey(const ValueKey('current-password-field')),
    'existing account password',
  );
  await tester.enterText(
    find.byKey(const ValueKey('new-password-field')),
    'a new gentle passphrase',
  );
  await tester.enterText(
    find.byKey(const ValueKey('confirm-password-field')),
    'a new gentle passphrase',
  );
}
