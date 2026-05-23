import 'package:flutter/material.dart';

import '../../core/theme/liquid_glass_theme.dart';

class PrivacyDisclaimerPage extends StatelessWidget {
  const PrivacyDisclaimerPage({super.key});

  static const supportContact = 'parkinsumservice@gmail.com';
  static const privacyContact = 'parkinsumservice@gmail.com';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: const GlassAppBar(
        title: Text('Privacy & Disclaimer'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          children: [
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Medical disclaimer',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'ParkinSUM Companion provides decision-support information '
                    'about medication, meal timing, food composition, and '
                    'related evidence sources. It does not diagnose disease, '
                    'prescribe treatment, replace professional medical '
                    'judgment, or provide emergency alerts. Review the evidence '
                    'basis shown in the app and consult a qualified healthcare '
                    'professional before making medication, dietary, or '
                    'treatment decisions.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy notice',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'In Firebase mode, user-specific records are intended to '
                    'stay under account-scoped Firestore paths tied to the '
                    'signed-in Firebase user id. These records may include '
                    'profile settings, meals, medication timing, active '
                    'medication ids, app metadata, and clinical decision '
                    'support audit records. Shared catalog and source records '
                    'should not contain user-private clinical records.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GlassCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User data rights',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Users may request export of their private app data, '
                    'deletion of private app data, and account deletion where '
                    'supported. Production operators must verify the Firebase '
                    'uid and execute the documented user-scoped export or '
                    'deletion workflow. Backups may retain deleted data for a '
                    'limited period, and restore procedures must account for '
                    'prior deletion requests.',
                  ),
                  const SizedBox(height: 14),
                  const _ContactRow(
                    label: 'Support',
                    value: supportContact,
                  ),
                  const SizedBox(height: 8),
                  const _ContactRow(
                    label: 'Privacy',
                    value: privacyContact,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  final String label;
  final String value;

  const _ContactRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 74,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }
}
